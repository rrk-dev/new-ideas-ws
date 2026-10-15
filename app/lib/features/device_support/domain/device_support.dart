import 'package:vaultvoice/core/platform/device_capabilities.dart';

/// Launch check for the minimum supported CPU (product owner decision
/// 2026-10-14): Android needs ARMv8.2-A with dotprod — no Cortex-A53/A35-only
/// phones (ADR-LLM-03, ADR-STT-02). The native bridge folds that minimum into
/// `vv_cpu_supported()`, so [DeviceCapabilities.cpuSupported] is the only
/// question to ask.
///
/// Fails open when the bridge cannot be asked ([caps] null, or the call
/// throws): a broken library already fails engine start with a clear error,
/// and a wrong "unsupported" verdict would lock a working device out.
bool isDeviceSupported(DeviceCapabilities? caps) {
  if (caps == null) return true;
  try {
    return caps.cpuSupported();
  } on Object {
    return true;
  }
}
