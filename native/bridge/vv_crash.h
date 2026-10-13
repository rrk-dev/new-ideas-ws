/*
 * VaultVoice native crash capture (REL-02, ADR-REL-02-crash-capture).
 *
 * Part of the vv_native bridge library. Kept in its own header/source so the
 * engine bridge (vv_bridge.h) can evolve independently; Dart binds it through
 * packages/vv_native/ffigen_crash.yaml.
 *
 * Privacy: the report contains only the signal, fault address, code
 * addresses (backtrace), module basenames + build ids, OS release and the app
 * build string passed to vv_crash_install(). No memory contents, no
 * registers beyond pc/lr/fp/sp, no file paths, no user content. It is written
 * to an app-private file and leaves the device only if the user shares it.
 *
 * Threading: call vv_crash_install()/vv_crash_uninstall() from one thread
 * (app startup). The signal handler itself is async-signal-safe: it only
 * uses write(2), fsync(2), sigaction(2), raise(3), clock_gettime(2) and
 * pre-computed static data.
 */
#ifndef VV_CRASH_H
#define VV_CRASH_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef VV_API
#if defined(_WIN32)
#define VV_API __declspec(dllexport)
#else
#define VV_API __attribute__((visibility("default")))
#endif
#endif

/* Format revision of the text report (first line "... report v<N>"). */
#define VV_CRASH_REPORT_VERSION 1

/* Return codes. Values match the bridge-wide codes planned for vv_error.h
 * (vv-ffi-bridge: INVALID_ARG -1, IO -5, BUSY -7, INTERNAL -8). */
#define VV_CRASH_OK 0
#define VV_CRASH_E_INVALID_ARG (-1)
#define VV_CRASH_E_IO (-5)
#define VV_CRASH_E_BUSY (-7)
#define VV_CRASH_E_INTERNAL (-8)

/* Kinds for vv_crash_force(). */
#define VV_CRASH_FORCE_SEGV 1  /* write through a null pointer -> SIGSEGV/SIGBUS */
#define VV_CRASH_FORCE_ABORT 2 /* abort() -> SIGABRT */
#define VV_CRASH_FORCE_TRAP 3  /* __builtin_trap() -> SIGTRAP or SIGILL */

/*
 * Opens (creates, truncates) `report_path` and keeps the descriptor open,
 * snapshots the loaded modules, then installs handlers for SIGSEGV, SIGBUS,
 * SIGILL, SIGFPE, SIGABRT and SIGTRAP. An empty file after a run means "no
 * native crash". Harvest a previous report BEFORE calling this (it truncates).
 *
 * `app_build` (borrowed, UTF-8, truncated to 127 bytes) identifies the build,
 * e.g. "0.1.0+42 prod"; it must not contain user content. May be NULL.
 *
 * Previous handlers are saved and chained: after the report is written the
 * previous disposition is restored and the signal re-delivered, so the OS /
 * platform crash reporter still sees the crash.
 *
 * Returns VV_CRASH_OK, VV_CRASH_E_INVALID_ARG (NULL/empty path),
 * VV_CRASH_E_IO (cannot open file), VV_CRASH_E_BUSY (already installed) or
 * VV_CRASH_E_INTERNAL (sigaction failed; nothing left installed).
 */
VV_API int32_t vv_crash_install(const char* report_path, const char* app_build);

/* Restores the previous handlers and closes the report file. Safe to call
 * when not installed (returns VV_CRASH_OK). */
VV_API int32_t vv_crash_uninstall(void);

/* 1 when handlers are installed, else 0. */
VV_API int32_t vv_crash_is_installed(void);

/* Number of modules captured by the last vv_crash_install() (diagnostics). */
VV_API int32_t vv_crash_module_count(void);

/*
 * Deliberately crashes the process (dev builds / tests only; the Dart side
 * exposes it only in the `dev` flavor). Does not return for valid kinds;
 * returns VV_CRASH_E_INVALID_ARG for an unknown kind.
 */
VV_API int32_t vv_crash_force(int32_t kind);

#ifdef __cplusplus
}
#endif

#endif /* VV_CRASH_H */
