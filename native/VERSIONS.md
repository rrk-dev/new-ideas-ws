# Native dependency pins

| Component | Pin (tag → commit) | Pinned on | Reason |
|---|---|---|---|
| `native/whisper.cpp` | `v1.9.5` → `d1be6fde11ac6e0407606b4e42fe72d34add8037` | 2026-10-12 | latest release at FND-06 |
| `native/llama.cpp` | `v0.6.0` → `d81235049384534c167caea52b85a694f6103d14` | 2026-10-12 | latest release at FND-06 |
| ggml | llama.cpp's copy (`ggml_version()` 0.26.0) | 2026-10-12 | whisper.cpp's tree is **identical** at these pins (`diff -rq native/llama.cpp/ggml native/whisper.cpp/ggml` → only `.gitignore` differs) |
| Android NDK | `28.2.13676358` (r28c) | 2026-10-12 | r28+ = 16 KB page alignment by default; pinned in `app/android/app/build.gradle.kts` and `packages/vv_native/android/build.gradle` |
| CMake (Android) | `3.22.1` | 2026-10-12 | superproject needs ≥ 3.22 |
| iOS min OS (native) | `16.0` (`IOS_MIN_OS`) | 2026-10-12 | matches the app; llama.cpp's own script uses 16.4 — see ADR-FND-06 |

Both projects are MIT licensed. Submodules are shallow clones of the tags above; the commit in
`git submodule status` is authoritative.

## Upgrade procedure
1. `git -C native/<dep> fetch --depth 1 origin tag <new-tag> && git -C native/<dep> checkout <new-tag>`
2. Re-verify ggml parity: `diff -rq native/llama.cpp/ggml native/whisper.cpp/ggml` must be (nearly)
   empty. If the trees diverge, pick commits that match or write an ADR before bumping one alone.
3. Re-check the option names used in `native/CMakeLists.txt` against the new
   `CMakeLists.txt` / `ggml/CMakeLists.txt` (`GGML_*`, `LLAMA_BUILD_*`, `WHISPER_BUILD_*`,
   `if (NOT TARGET ggml …)`). Do not copy flags from memory.
4. `native/build.sh host` (runs the smoke and export tests), then `android` / `ios` where available.
5. Update this file (pins, sizes, reason) and run the on-device test
   (`app/integration_test/native_bridge_test.dart`) on one Android and one iOS device.
6. Commit the submodule bump and this file together: `chore(native): bump <dep> to <tag>`.

## Binary sizes (input to REL-03)
| Target | Artifact | Size | Measured |
|---|---|---|---|
| macOS host (arm64, Metal + Accelerate, Release, unstripped) | `libvv_native.dylib` | 6,507,968 B (6.2 MiB) | 2026-10-12, Apple clang 21, CMake 4.4.4 — informational only |
| Android arm64-v8a (Release, stripped) | `libvv_native.so` | ⏳ not measured | needs NDK r28+ (`native/build.sh android` prints it) |
| iOS device slice | `vv_native.framework/vv_native` | ⏳ not measured | needs Xcode (`native/build.sh ios` prints it) |
| iOS simulator slice | `vv_native.framework/vv_native` | ⏳ not measured | needs Xcode |
