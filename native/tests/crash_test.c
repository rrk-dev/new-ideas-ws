/*
 * [REL-02/AC1] Host test for the native crash handler (native/bridge/vv_crash.c).
 *
 *   vv_crash_test                       run the self-test suite (ctest)
 *   vv_crash_test crash <kind> <report> install, then crash through
 *                                       crash_test_level1 -> level2 -> vv_crash_force
 *                                       (used by tools/crash/tests to symbolize)
 *
 * Every forced crash runs in a forked child: the parent checks the child died
 * of the expected signal (the handler chained to the default action) and
 * that the pre-opened report file holds a complete, parseable report.
 */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include "vv_crash.h"

static int g_failures = 0;

#define CHECK(cond, what)                                   \
  do {                                                      \
    if (!(cond)) {                                          \
      fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, what); \
      g_failures++;                                         \
    }                                                       \
  } while (0)

__attribute__((noinline)) int crash_test_level2(int kind) {
  int rc = vv_crash_force(kind);
  __asm__ volatile("");
  return rc;
}

__attribute__((noinline)) int crash_test_level1(int kind) {
  int rc = crash_test_level2(kind);
  __asm__ volatile("");
  return rc + 1;
}

static int crash_mode(int kind, const char* report) {
  char build[64];
  snprintf(build, sizeof(build), "0.0.0+0 test kind=%d", kind);
  if (vv_crash_install(report, build) != VV_CRASH_OK) {
    fprintf(stderr, "install failed\n");
    return 3;
  }
  crash_test_level1(kind);
  fprintf(stderr, "did not crash\n");
  return 4;
}

static char* read_file(const char* path) {
  FILE* f = fopen(path, "rb");
  if (!f) return NULL;
  static char buf[64 * 1024];
  size_t n = fread(buf, 1, sizeof(buf) - 1, f);
  fclose(f);
  buf[n] = '\0';
  return buf;
}

static int count_frames(const char* report) {
  int n = 0;
  for (const char* p = strstr(report, "    #"); p; p = strstr(p + 1, "    #")) n++;
  return n;
}

/* Fork, crash with `kind`, return the report text (static buffer). */
static char* run_crash_child(const char* exe_name, int kind, const char* report, int* term_sig) {
  (void)exe_name;
  pid_t pid = fork();
  if (pid == 0) {
    /* Child: keep the default action for the re-raised signal (no core). */
    _exit(crash_mode(kind, report));
  }
  int status = 0;
  while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
  }
  *term_sig = WIFSIGNALED(status) ? WTERMSIG(status) : 0;
  return read_file(report);
}

static void test_forced_crash(const char* exe, int kind, int sig_a, int sig_b, const char* sig_name_a,
                              const char* sig_name_b, const char* report) {
  int term = 0;
  char* text = run_crash_child(exe, kind, report, &term);
  char what[160];
  snprintf(what, sizeof(what), "kind %d: child terminated by signal %d (want %d or %d)", kind, term,
           sig_a, sig_b);
  CHECK(term == sig_a || term == sig_b, what);
  CHECK(text != NULL, "report file readable");
  if (!text) return;
  CHECK(strncmp(text, "*** *** ***", 11) == 0, "tombstone banner first (ndk-stack)");
  CHECK(strstr(text, "VaultVoice native crash report v1\n") != NULL, "header");
  CHECK(strstr(text, "app: 0.0.0+0 test kind=") != NULL, "app build string");
  CHECK(strstr(text, "ABI: '") != NULL, "ABI line");
  CHECK(strstr(text, sig_name_a) != NULL || strstr(text, sig_name_b) != NULL, "signal name");
  CHECK(strstr(text, "    #00 pc ") != NULL, "frame #00");
  CHECK(count_frames(text) >= 3, "at least 3 frames (force -> level2 -> level1)");
  CHECK(strstr(text, exe) != NULL, "frames resolve to the test executable module");
  CHECK(strstr(text, "modules:\n    load 0x") != NULL, "module load addresses");
  CHECK(strstr(text, "end of report\n") != NULL, "report complete");
  CHECK(strstr(text, "/") == NULL || strstr(text, "/") > strstr(text, "end of report"),
        "no file paths in report (basenames only)");
  if (g_failures) fprintf(stderr, "---- report ----\n%s----\n", text);
}

static void test_api(const char* report) {
  CHECK(vv_crash_install(NULL, "x") == VV_CRASH_E_INVALID_ARG, "NULL path rejected");
  CHECK(vv_crash_install("", "x") == VV_CRASH_E_INVALID_ARG, "empty path rejected");
  CHECK(vv_crash_install("/nonexistent-dir/x/report", "x") == VV_CRASH_E_IO, "unwritable path -> IO");
  CHECK(vv_crash_is_installed() == 0, "not installed after failures");

  struct sigaction before, after;
  sigaction(SIGSEGV, NULL, &before);
  CHECK(vv_crash_install(report, "0.0.0 api") == VV_CRASH_OK, "install ok");
  CHECK(vv_crash_is_installed() == 1, "installed");
  CHECK(vv_crash_module_count() > 0, "modules snapshotted");
  CHECK(vv_crash_install(report, "again") == VV_CRASH_E_BUSY, "second install -> busy");
  CHECK(vv_crash_force(99) == VV_CRASH_E_INVALID_ARG, "unknown force kind rejected");
  CHECK(vv_crash_uninstall() == VV_CRASH_OK, "uninstall ok");
  CHECK(vv_crash_uninstall() == VV_CRASH_OK, "uninstall twice ok");
  sigaction(SIGSEGV, NULL, &after);
  CHECK(after.sa_handler == before.sa_handler, "previous SIGSEGV handler restored");

  struct stat st;
  CHECK(stat(report, &st) == 0 && st.st_size == 0, "no crash -> empty report file");
  CHECK((st.st_mode & 0077) == 0, "report file is private (0600)");
}

int main(int argc, char** argv) {
  if (argc == 4 && strcmp(argv[1], "crash") == 0) return crash_mode(atoi(argv[2]), argv[3]);

  const char* exe = strrchr(argv[0], '/');
  exe = exe ? exe + 1 : argv[0];
  char report[512];
  const char* tmp = getenv("TMPDIR");
  snprintf(report, sizeof(report), "%s/vv_crash_test_%d.vvcrash", tmp && *tmp ? tmp : "/tmp",
           (int)getpid());

  test_api(report);
  test_forced_crash(exe, VV_CRASH_FORCE_SEGV, SIGSEGV, SIGBUS, "(SIGSEGV)", "(SIGBUS)", report);
  test_forced_crash(exe, VV_CRASH_FORCE_ABORT, SIGABRT, SIGABRT, "(SIGABRT)", "(SIGABRT)", report);
  test_forced_crash(exe, VV_CRASH_FORCE_TRAP, SIGTRAP, SIGILL, "(SIGTRAP)", "(SIGILL)", report);
  unlink(report);

  if (g_failures) {
    fprintf(stderr, "%d failure(s)\n", g_failures);
    return 1;
  }
  printf("vv_crash_test: OK (segv, abort, trap; api)\n");
  return 0;
}
