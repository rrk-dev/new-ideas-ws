/// Runtime backend selection for whisper.cpp / llama.cpp (STT-02).
///
/// Decides which GPU module the native bridge may load (`vv_backends_load`
/// gpu mask) and whether a model context may use the GPU (`use_gpu`), with
/// CPU as the always-safe fallback. Rules (ADR-STT-02):
/// - background → CPU (iOS forbids GPU work in the background; Android
///   follows the same rule for thermal/battery);
/// - a GPU backend is only used when it was built into this binary, the
///   device's GPU matches an allowlist rule and no denylist rule, and it did
///   not crash a previous run (trial sentinel, see [GpuTrialStore]);
/// - the user's "force CPU" diagnostic switch wins.
library;

/// GPU backend families, matching `VV_GPU_*` in `native/bridge/vv_bridge.h`.
enum GpuBackend {
  metal(0x1),
  vulkan(0x2),
  opencl(0x4);

  GpuBackend(this.maskBit);

  /// Bit for `vv_backends_load(lib_dir, gpu_mask)`.
  final int maskBit;
}

/// Platforms the policy distinguishes.
enum DevicePlatform { ios, android, host }

/// GPU identity (hardware strings only — never user content).
class GpuInfo {
  const GpuInfo({required this.renderer, this.driver = ''});

  /// e.g. `Adreno (TM) 740`, `Mali-G715`, `Apple A15 GPU`.
  final String renderer;

  /// Driver/version string when known (Android `GL_VERSION` / Vulkan driver).
  final String driver;
}

/// One allow/deny entry: [backend] on GPUs whose renderer matches
/// [renderer] (and driver matches [driver] when given).
class GpuRule {
  const GpuRule({
    required this.backend,
    required this.renderer,
    required this.reason,
    this.driver,
  });

  final GpuBackend backend;
  final Pattern renderer;
  final Pattern? driver;

  /// Why (bench result / crash report reference) — shown in diagnostics.
  final String reason;

  bool matches(GpuBackend b, GpuInfo gpu) =>
      b == backend &&
      _hit(renderer, gpu.renderer) &&
      (driver == null || _hit(driver!, gpu.driver));

  static bool _hit(Pattern p, String s) =>
      p is RegExp ? p.hasMatch(s) : s.contains(p);
}

/// Allow- and denylist. Deny wins.
class GpuRules {
  const GpuRules({this.allow = const [], this.deny = const []});

  final List<GpuRule> allow;
  final List<GpuRule> deny;

  bool permits(GpuBackend b, GpuInfo gpu) =>
      allow.any((r) => r.matches(b, gpu)) &&
      !deny.any((r) => r.matches(b, gpu));
}

/// Shipped rules. Android GPU backends start **empty** (CPU everywhere):
/// Vulkan has known Adreno/Mali driver issues and neither Vulkan nor OpenCL
/// is benchmarked on a device yet — entries are added only with a device
/// result in `docs/test-plans/device/STT-02.md` (ADR-STT-02). Metal is
/// allowed on every iOS GPU (all supported iPhones are A12+).
const GpuRules kDefaultGpuRules = GpuRules(
  allow: [
    GpuRule(
      backend: GpuBackend.metal,
      renderer: '',
      reason: 'all iOS 16+ devices support Metal (ADR-STT-01)',
    ),
  ],
);

/// Inputs for one decision.
class BackendPolicyInput {
  const BackendPolicyInput({
    required this.platform,
    required this.foreground,
    required this.builtGpuBackends,
    this.gpu,
    this.crashedBackends = const {},
    this.forceCpu = false,
  });

  final DevicePlatform platform;
  final bool foreground;

  /// GPU modules present in this build (`vv_backends_describe` / build flags).
  final Set<GpuBackend> builtGpuBackends;

  /// Null when the GPU could not be identified → CPU.
  final GpuInfo? gpu;

  /// Backends whose previous trial never completed (crash/ANR/kill).
  final Set<GpuBackend> crashedBackends;

  /// Diagnostics switch "Use CPU only".
  final bool forceCpu;
}

/// The decision.
class BackendChoice {
  const BackendChoice.cpu(this.reason) : gpu = null;
  const BackendChoice.gpu(GpuBackend this.gpu, this.reason);

  /// GPU backend to load and use, or null for CPU only.
  final GpuBackend? gpu;

  /// Content-free explanation for logs/diagnostics.
  final String reason;

  bool get useGpu => gpu != null;

  /// Mask for `vv_backends_load`.
  int get gpuMask => gpu?.maskBit ?? 0;
}

/// Preference order when several GPU backends are allowed for a device.
const List<GpuBackend> _androidPreference = [
  GpuBackend.opencl,
  GpuBackend.vulkan,
];

/// Pure decision function (unit-tested; no I/O).
BackendChoice chooseBackend(
  BackendPolicyInput input, {
  GpuRules rules = kDefaultGpuRules,
}) {
  if (input.forceCpu) return const BackendChoice.cpu('forced by user');
  if (!input.foreground) return const BackendChoice.cpu('background');
  final gpu = input.gpu;
  if (gpu == null) return const BackendChoice.cpu('gpu unknown');
  final candidates = switch (input.platform) {
    DevicePlatform.ios => const [GpuBackend.metal],
    DevicePlatform.android => _androidPreference,
    DevicePlatform.host => const [GpuBackend.metal, ..._androidPreference],
  };
  for (final b in candidates) {
    if (!input.builtGpuBackends.contains(b)) continue;
    if (input.crashedBackends.contains(b)) continue;
    if (!rules.permits(b, gpu)) continue;
    return BackendChoice.gpu(b, '${b.name} allowed');
  }
  if (candidates.any(input.crashedBackends.contains)) {
    return const BackendChoice.cpu('gpu crashed in a previous run');
  }
  return const BackendChoice.cpu('no allowed gpu backend');
}

/// Persists "a GPU trial is running" so a native crash during the first GPU
/// use of a backend disables that backend on the next launch (the process
/// dies before any Dart error handling can run).
abstract interface class GpuTrialStore {
  Future<Set<GpuBackend>> crashed();
  Future<void> begin(GpuBackend backend);
  Future<void> succeeded(GpuBackend backend);
}

/// Records trials in memory or any key/value persistence via [read]/[write].
class GpuTrialGuard implements GpuTrialStore {
  GpuTrialGuard({required this.read, required this.write});

  /// Reads the stored value for a key (null when absent).
  final Future<String?> Function(String key) read;

  /// Writes (or deletes, with null) a key.
  final Future<void> Function(String key, String? value) write;

  static String _key(GpuBackend b) => 'gpu_trial.${b.name}';

  /// Backends whose trial was begun but never marked [succeeded], or that
  /// were marked crashed before.
  @override
  Future<Set<GpuBackend>> crashed() async {
    final out = <GpuBackend>{};
    for (final b in GpuBackend.values) {
      final v = await read(_key(b));
      if (v == 'running' || v == 'crashed') {
        out.add(b);
        if (v == 'running') await write(_key(b), 'crashed');
      }
    }
    return out;
  }

  @override
  Future<void> begin(GpuBackend backend) async {
    if (await read(_key(backend)) == 'ok') return;
    await write(_key(backend), 'running');
  }

  @override
  Future<void> succeeded(GpuBackend backend) => write(_key(backend), 'ok');
}

/// Default thread count: performance cores (`vv_cpu_perf_cores`), capped at
/// [cap] — more threads than big cores is slower on big.LITTLE (STT-02 host
/// sweep: 12 threads on a 6P+6E CPU was 5–7x slower than 4).
int defaultThreads(int perfCores, {int cap = 4}) =>
    perfCores < 1 ? 1 : (perfCores > cap ? cap : perfCores);
