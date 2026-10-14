/*
 * VaultVoice native crash capture (REL-02). See vv_crash.h and
 * docs/adr/ADR-REL-02-crash-capture.md.
 *
 * Everything reachable from crash_handler() must be async-signal-safe: no
 * malloc, no stdio, no locks, no dladdr/dl_iterate_phdr. All lookups use the
 * module table snapshotted by vv_crash_install(); output goes through
 * write(2) on the descriptor opened at install time.
 *
 * Report format (text, tombstone-like so `ndk-stack` parses the backtrace):
 *
 *   *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
 *   VaultVoice native crash report v1
 *   app: 0.1.0+42 prod
 *   os: Darwin 25.0.0 arm64
 *   ABI: 'arm64'
 *   time_unix: 1760000000
 *   signal 11 (SIGSEGV), code 2, fault addr 0x0000000000000000
 *   backtrace:
 *       #00 pc 0000000000001f40  libvv_native.so (BuildId: 9a1c...)
 *   modules:
 *       load 0x0000000102b40000 libvv_native.so 9a1c...
 *   end of report
 *
 * `pc` is relative to the module load address (ELF load bias / Mach-O header
 * address); frames > 0 are return addresses minus 1 so they resolve to the
 * call instruction. tools/crash/symbolize.py turns this into file:line with
 * atos (iOS/macOS) or llvm-symbolizer/addr2line (Android/Linux).
 */
#if !defined(__APPLE__) && !defined(_GNU_SOURCE)
#define _GNU_SOURCE 1
#endif

#include "vv_crash.h"

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <time.h>
#include <unistd.h>

#if defined(__APPLE__)
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <sys/ucontext.h>
#else
#include <elf.h>
#include <link.h>
#include <ucontext.h>
#endif

/* ---------------------------------------------------------------- state */

#define VV_MAX_MODULES 768
#define VV_NAME_MAX 96
#define VV_BUILD_ID_MAX 41 /* 20 bytes hex + NUL */
#define VV_MAX_FRAMES 64

typedef struct {
  uintptr_t start; /* executable range [start, end) */
  uintptr_t end;
  uintptr_t base; /* ELF load bias / Mach-O header address */
  char name[VV_NAME_MAX];
  char build_id[VV_BUILD_ID_MAX];
} vv_module;

static const int kSignals[] = {SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGABRT, SIGTRAP};
#define VV_NUM_SIGNALS ((int)(sizeof(kSignals) / sizeof(kSignals[0])))

static vv_module g_modules[VV_MAX_MODULES];
static int g_module_count = 0;
static struct sigaction g_previous[VV_NUM_SIGNALS];
static int g_fd = -1;
static int g_installed = 0;
static char g_app[128];
static char g_os[160];
static volatile sig_atomic_t g_handling = 0;
static volatile sig_atomic_t g_done = 0;

/* Alternate stack so a stack overflow on the installing thread can still be
 * reported (bionic gives every pthread its own; Darwin does not). */
static char g_altstack_mem[64 * 1024] __attribute__((aligned(16)));
static int g_altstack_ours = 0;

/* ------------------------------------------------- async-signal-safe I/O */

typedef struct {
  char buf[512];
  size_t len;
} vv_line;

static void line_flush(vv_line* l) {
  size_t off = 0;
  while (off < l->len && g_fd >= 0) {
    ssize_t n = write(g_fd, l->buf + off, l->len - off);
    if (n < 0) {
      if (errno == EINTR) continue;
      break;
    }
    off += (size_t)n;
  }
  l->len = 0;
}

static void put_str(vv_line* l, const char* s) {
  while (s && *s) {
    if (l->len == sizeof(l->buf)) line_flush(l);
    l->buf[l->len++] = *s++;
  }
}

static void put_hex(vv_line* l, uintptr_t v, int digits) {
  char tmp[2 * sizeof(uintptr_t) + 1];
  int n = 0;
  do {
    tmp[n++] = "0123456789abcdef"[v & 0xf];
    v >>= 4;
  } while (v != 0 && n < (int)sizeof(tmp));
  while (n < digits && n < (int)sizeof(tmp)) tmp[n++] = '0';
  char out[sizeof(tmp) + 1];
  for (int i = 0; i < n; i++) out[i] = tmp[n - 1 - i];
  out[n] = '\0';
  put_str(l, out);
}

static void put_dec(vv_line* l, long long v) {
  char tmp[24];
  int n = 0;
  unsigned long long u = v < 0 ? (unsigned long long)(-(v + 1)) + 1 : (unsigned long long)v;
  do {
    tmp[n++] = (char)('0' + (u % 10));
    u /= 10;
  } while (u != 0 && n < 22);
  if (v < 0) tmp[n++] = '-';
  char out[24];
  for (int i = 0; i < n; i++) out[i] = tmp[n - 1 - i];
  out[n] = '\0';
  put_str(l, out);
}

static const char* signal_name(int sig) {
  switch (sig) {
    case SIGSEGV: return "SIGSEGV";
    case SIGBUS: return "SIGBUS";
    case SIGILL: return "SIGILL";
    case SIGFPE: return "SIGFPE";
    case SIGABRT: return "SIGABRT";
    case SIGTRAP: return "SIGTRAP";
    default: return "SIG?";
  }
}

/* ------------------------------------------------------------- unwinding */

/* Strips pointer-authentication / top-byte tags from a code address.
 * `xpaclri` is HINT #7: a no-op on CPUs without PAC, so it is safe on every
 * arm64 device. */
static uintptr_t strip_code_ptr(uintptr_t a) {
#if defined(__aarch64__)
  register uintptr_t x30 __asm__("x30") = a;
  __asm__ volatile("hint #7" : "+r"(x30));
  return x30;
#else
  return a;
#endif
}

static const vv_module* find_module(uintptr_t pc) {
  for (int i = 0; i < g_module_count; i++) {
    if (pc >= g_modules[i].start && pc < g_modules[i].end) return &g_modules[i];
  }
  return NULL;
}

/* A frame pointer we are willing to dereference: aligned and inside the
 * stack region above the faulting sp. Bounds keep a corrupt chain from
 * wandering into unmapped memory (a fault here would just end the report). */
static int plausible_fp(uintptr_t fp, uintptr_t sp) {
  if (fp == 0 || (fp & (sizeof(uintptr_t) - 1)) != 0) return 0;
  if (fp < sp) return 0;
  if (fp - sp > (uintptr_t)64 * 1024 * 1024) return 0;
  return 1;
}

typedef struct {
  uintptr_t pcs[VV_MAX_FRAMES];
  int n;
} vv_trace;

static void trace_push(vv_trace* t, uintptr_t pc) {
  if (t->n < VV_MAX_FRAMES && pc != 0) t->pcs[t->n++] = pc;
}

static void collect_trace(void* ucv, vv_trace* t) {
  uintptr_t pc = 0, fp = 0, sp = 0, lr = 0;
  t->n = 0;
#if defined(__APPLE__)
  ucontext_t* uc = (ucontext_t*)ucv;
  if (!uc || !uc->uc_mcontext) return;
#if defined(__aarch64__)
  pc = (uintptr_t)__darwin_arm_thread_state64_get_pc(uc->uc_mcontext->__ss);
  fp = (uintptr_t)__darwin_arm_thread_state64_get_fp(uc->uc_mcontext->__ss);
  sp = (uintptr_t)__darwin_arm_thread_state64_get_sp(uc->uc_mcontext->__ss);
  lr = (uintptr_t)__darwin_arm_thread_state64_get_lr(uc->uc_mcontext->__ss);
#elif defined(__x86_64__)
  pc = (uintptr_t)uc->uc_mcontext->__ss.__rip;
  fp = (uintptr_t)uc->uc_mcontext->__ss.__rbp;
  sp = (uintptr_t)uc->uc_mcontext->__ss.__rsp;
#endif
#else
  ucontext_t* uc = (ucontext_t*)ucv;
  if (!uc) return;
#if defined(__aarch64__)
  pc = (uintptr_t)uc->uc_mcontext.pc;
  fp = (uintptr_t)uc->uc_mcontext.regs[29];
  lr = (uintptr_t)uc->uc_mcontext.regs[30];
  sp = (uintptr_t)uc->uc_mcontext.sp;
#elif defined(__x86_64__)
  pc = (uintptr_t)uc->uc_mcontext.gregs[REG_RIP];
  fp = (uintptr_t)uc->uc_mcontext.gregs[REG_RBP];
  sp = (uintptr_t)uc->uc_mcontext.gregs[REG_RSP];
#endif
#endif
  pc = strip_code_ptr(pc);
  trace_push(t, pc);
  /* The faulting function may be a leaf that has not pushed a frame record:
   * its caller is then only in lr. Add lr unless the first record has it. */
  if (lr != 0) {
    uintptr_t first_ret = 0;
    if (plausible_fp(fp, sp)) first_ret = strip_code_ptr(((uintptr_t*)fp)[1]);
    lr = strip_code_ptr(lr);
    if (lr != first_ret && find_module(lr) != NULL) trace_push(t, lr - 1);
  }
  while (t->n < VV_MAX_FRAMES && plausible_fp(fp, sp)) {
    uintptr_t next = ((uintptr_t*)fp)[0];
    uintptr_t ret = strip_code_ptr(((uintptr_t*)fp)[1]);
    if (ret == 0) break;
    trace_push(t, ret - 1);
    if (next <= fp || next - fp > (uintptr_t)8 * 1024 * 1024) break;
    fp = next;
  }
}

/* --------------------------------------------------------------- handler */

static void restore_previous(void) {
  for (int i = 0; i < VV_NUM_SIGNALS; i++) sigaction(kSignals[i], &g_previous[i], NULL);
}

static void write_report(int sig, siginfo_t* si, void* uc) {
  vv_line l;
  l.len = 0;
  put_str(&l, "*** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***\n");
  put_str(&l, "VaultVoice native crash report v");
  put_dec(&l, VV_CRASH_REPORT_VERSION);
  put_str(&l, "\napp: ");
  put_str(&l, g_app);
  put_str(&l, "\nos: ");
  put_str(&l, g_os);
  put_str(&l, "\nABI: '");
#if defined(__aarch64__)
  put_str(&l, "arm64");
#elif defined(__x86_64__)
  put_str(&l, "x86_64");
#else
  put_str(&l, "unknown");
#endif
  put_str(&l, "'\ntime_unix: ");
  struct timespec ts;
  if (clock_gettime(CLOCK_REALTIME, &ts) == 0) put_dec(&l, (long long)ts.tv_sec);
  put_str(&l, "\nsignal ");
  put_dec(&l, sig);
  put_str(&l, " (");
  put_str(&l, signal_name(sig));
  put_str(&l, "), code ");
  put_dec(&l, si ? si->si_code : 0);
  put_str(&l, ", fault addr 0x");
  put_hex(&l, si ? (uintptr_t)si->si_addr : 0, 16);
  put_str(&l, "\nbacktrace:\n");
  line_flush(&l);

  vv_trace t;
  collect_trace(uc, &t);
  const vv_module* used[VV_MAX_FRAMES];
  int n_used = 0;
  for (int i = 0; i < t.n; i++) {
    const vv_module* m = find_module(t.pcs[i]);
    put_str(&l, "    #");
    if (i < 10) put_str(&l, "0");
    put_dec(&l, i);
    put_str(&l, " pc ");
    put_hex(&l, m ? t.pcs[i] - m->base : t.pcs[i], 16);
    put_str(&l, "  ");
    if (m) {
      put_str(&l, m->name);
      if (m->build_id[0]) {
        put_str(&l, " (BuildId: ");
        put_str(&l, m->build_id);
        put_str(&l, ")");
      }
      int seen = 0;
      for (int k = 0; k < n_used; k++) seen |= used[k] == m;
      if (!seen) used[n_used++] = m;
    } else {
      put_str(&l, "<unknown>");
    }
    put_str(&l, "\n");
    line_flush(&l); /* one write per frame: a later fault keeps earlier lines */
  }
  put_str(&l, "modules:\n");
  for (int k = 0; k < n_used; k++) {
    put_str(&l, "    load 0x");
    put_hex(&l, used[k]->base, 16);
    put_str(&l, " ");
    put_str(&l, used[k]->name);
    put_str(&l, " ");
    put_str(&l, used[k]->build_id[0] ? used[k]->build_id : "-");
    put_str(&l, "\n");
    line_flush(&l);
  }
  put_str(&l, "end of report\n");
  line_flush(&l);
  if (g_fd >= 0) fsync(g_fd);
}

static void crash_handler(int sig, siginfo_t* si, void* uc) {
  int saved_errno = errno;
  if (__atomic_exchange_n(&g_handling, 1, __ATOMIC_SEQ_CST) != 0) {
    /* Another thread is writing the report: give it up to ~1 s. */
    for (int i = 0; i < 100 && !g_done; i++) {
      struct timespec d = {0, 10 * 1000 * 1000};
      nanosleep(&d, NULL);
    }
  } else {
    write_report(sig, si, uc);
    g_done = 1;
  }
  /* Chain: put back whatever was there (OS crash reporter, debuggerd, ART
   * sigchain, SIG_DFL) and let the signal be delivered to it. */
  restore_previous();
  if (si == NULL || si->si_code <= 0 || sig == SIGABRT) {
    /* Sent by kill/raise/abort: returning would not re-trigger it. */
    raise(sig);
  }
  errno = saved_errno;
  /* Hardware fault: returning re-executes the faulting instruction, which
   * now reaches the previous handler. */
}

/* ------------------------------------------------------- module snapshot */

static void copy_basename(char* dst, size_t cap, const char* path) {
  const char* base = path;
  for (const char* p = path; p && *p; p++) {
    if (*p == '/') base = p + 1;
  }
  size_t i = 0;
  for (; base && base[i] && i + 1 < cap; i++) dst[i] = base[i];
  dst[i] = '\0';
}

static void hex_bytes(char* dst, size_t cap, const uint8_t* b, size_t n) {
  size_t o = 0;
  for (size_t i = 0; i < n && o + 2 < cap; i++) {
    dst[o++] = "0123456789abcdef"[b[i] >> 4];
    dst[o++] = "0123456789abcdef"[b[i] & 0xf];
  }
  dst[o] = '\0';
}

#if defined(__APPLE__)
static void snapshot_modules(void) {
  g_module_count = 0;
  uint32_t count = _dyld_image_count();
  for (uint32_t i = 0; i < count && g_module_count < VV_MAX_MODULES; i++) {
    const struct mach_header* h = _dyld_get_image_header(i);
    const char* path = _dyld_get_image_name(i);
    intptr_t slide = _dyld_get_image_vmaddr_slide(i);
    if (h == NULL || h->magic != MH_MAGIC_64) continue;
    vv_module* m = &g_modules[g_module_count];
    memset(m, 0, sizeof(*m));
    const uint8_t* p = (const uint8_t*)h + sizeof(struct mach_header_64);
    for (uint32_t c = 0; c < h->ncmds; c++) {
      const struct load_command* lc = (const struct load_command*)p;
      if (lc->cmd == LC_SEGMENT_64) {
        const struct segment_command_64* seg = (const struct segment_command_64*)lc;
        if (strcmp(seg->segname, "__TEXT") == 0) {
          m->start = (uintptr_t)(seg->vmaddr + (uint64_t)slide);
          m->end = m->start + (uintptr_t)seg->vmsize;
        }
      } else if (lc->cmd == LC_UUID) {
        const struct uuid_command* u = (const struct uuid_command*)lc;
        hex_bytes(m->build_id, sizeof(m->build_id), u->uuid, sizeof(u->uuid));
      }
      p += lc->cmdsize;
    }
    if (m->end <= m->start) continue;
    m->base = (uintptr_t)h;
    copy_basename(m->name, sizeof(m->name), path ? path : "?");
    g_module_count++;
  }
}
#else
static int phdr_callback(struct dl_phdr_info* info, size_t size, void* data) {
  (void)size;
  (void)data;
  if (g_module_count >= VV_MAX_MODULES) return 1;
  vv_module* m = &g_modules[g_module_count];
  memset(m, 0, sizeof(*m));
  uintptr_t lo = UINTPTR_MAX, hi = 0;
  for (int i = 0; i < info->dlpi_phnum; i++) {
    const ElfW(Phdr)* ph = &info->dlpi_phdr[i];
    if (ph->p_type == PT_LOAD && (ph->p_flags & PF_X)) {
      uintptr_t s = (uintptr_t)(info->dlpi_addr + ph->p_vaddr);
      uintptr_t e = s + (uintptr_t)ph->p_memsz;
      if (s < lo) lo = s;
      if (e > hi) hi = e;
    } else if (ph->p_type == PT_NOTE && m->build_id[0] == '\0') {
      const uint8_t* p = (const uint8_t*)(info->dlpi_addr + ph->p_vaddr);
      const uint8_t* end = p + ph->p_memsz;
      while (p + sizeof(ElfW(Nhdr)) <= end) {
        const ElfW(Nhdr)* n = (const ElfW(Nhdr)*)p;
        const uint8_t* name = p + sizeof(*n);
        const uint8_t* desc = name + ((n->n_namesz + 3u) & ~3u);
        const uint8_t* next = desc + ((n->n_descsz + 3u) & ~3u);
        if (next > end) break;
        if (n->n_type == NT_GNU_BUILD_ID && n->n_namesz == 4 && memcmp(name, "GNU", 4) == 0) {
          hex_bytes(m->build_id, sizeof(m->build_id), desc, n->n_descsz > 20 ? 20 : n->n_descsz);
          break;
        }
        p = next;
      }
    }
  }
  if (hi <= lo) return 0;
  m->start = lo;
  m->end = hi;
  m->base = (uintptr_t)info->dlpi_addr;
  const char* path = info->dlpi_name;
  char exe[256];
  if (path == NULL || path[0] == '\0') {
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
    exe[n > 0 ? n : 0] = '\0';
    path = n > 0 ? exe : "app_process";
  }
  copy_basename(m->name, sizeof(m->name), path);
  g_module_count++;
  return 0;
}

static void snapshot_modules(void) {
  g_module_count = 0;
  dl_iterate_phdr(phdr_callback, NULL);
}
#endif

/* ---------------------------------------------------------------- public */

static void copy_bounded(char* dst, size_t cap, const char* src) {
  size_t i = 0;
  for (; src && src[i] && i + 1 < cap; i++) {
    char c = src[i];
    dst[i] = (c == '\n' || c == '\r') ? ' ' : c; /* keep the report line-based */
  }
  dst[i] = '\0';
}

int32_t vv_crash_install(const char* report_path, const char* app_build) {
  if (report_path == NULL || report_path[0] == '\0') return VV_CRASH_E_INVALID_ARG;
  if (g_installed) return VV_CRASH_E_BUSY;
  int fd = open(report_path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600);
  if (fd < 0) return VV_CRASH_E_IO;

  copy_bounded(g_app, sizeof(g_app), app_build ? app_build : "unknown");
  struct utsname u;
  if (uname(&u) == 0) {
    char os[sizeof(g_os)];
    size_t o = 0;
    const char* parts[3] = {u.sysname, u.release, u.machine};
    for (int i = 0; i < 3; i++) {
      for (const char* p = parts[i]; *p && o + 2 < sizeof(os); p++) os[o++] = *p;
      if (i < 2 && o + 2 < sizeof(os)) os[o++] = ' ';
    }
    os[o] = '\0';
    copy_bounded(g_os, sizeof(g_os), os);
  } else {
    copy_bounded(g_os, sizeof(g_os), "unknown");
  }
  snapshot_modules();

  stack_t cur;
  g_altstack_ours = 0;
  if (sigaltstack(NULL, &cur) == 0 && (cur.ss_flags & SS_DISABLE)) {
    stack_t ss;
    memset(&ss, 0, sizeof(ss));
    ss.ss_sp = g_altstack_mem;
    ss.ss_size = sizeof(g_altstack_mem);
    if (sigaltstack(&ss, NULL) == 0) g_altstack_ours = 1;
  }

  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_sigaction = crash_handler;
  sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
  sigemptyset(&sa.sa_mask);
  for (int i = 0; i < VV_NUM_SIGNALS; i++) {
    if (sigaction(kSignals[i], &sa, &g_previous[i]) != 0) {
      for (int k = 0; k < i; k++) sigaction(kSignals[k], &g_previous[k], NULL);
      close(fd);
      return VV_CRASH_E_INTERNAL;
    }
  }
  g_fd = fd;
  g_handling = 0;
  g_done = 0;
  g_installed = 1;
  return VV_CRASH_OK;
}

int32_t vv_crash_uninstall(void) {
  if (!g_installed) return VV_CRASH_OK;
  restore_previous();
  if (g_altstack_ours) {
    stack_t ss;
    memset(&ss, 0, sizeof(ss));
    ss.ss_flags = SS_DISABLE;
    sigaltstack(&ss, NULL);
    g_altstack_ours = 0;
  }
  close(g_fd);
  g_fd = -1;
  g_installed = 0;
  return VV_CRASH_OK;
}

int32_t vv_crash_is_installed(void) { return g_installed ? 1 : 0; }

int32_t vv_crash_module_count(void) { return g_module_count; }

/* noinline + an empty asm after each call keep these frames (no tail calls)
 * so the forced crash shows a recognisable backtrace. */
__attribute__((noinline)) static void vv_crash_force_segv(void) {
  volatile int* volatile p = NULL;
  *p = 42;
  __asm__ volatile("");
}

__attribute__((noinline)) static void vv_crash_force_abort(void) {
  abort();
}

__attribute__((noinline)) static void vv_crash_force_trap(void) {
  __builtin_trap();
}

int32_t vv_crash_force(int32_t kind) {
  switch (kind) {
    case VV_CRASH_FORCE_SEGV: vv_crash_force_segv(); break;
    case VV_CRASH_FORCE_ABORT: vv_crash_force_abort(); break;
    case VV_CRASH_FORCE_TRAP: vv_crash_force_trap(); break;
    default: return VV_CRASH_E_INVALID_ARG;
  }
  __asm__ volatile("");
  return VV_CRASH_E_INTERNAL; /* unreachable for valid kinds */
}
