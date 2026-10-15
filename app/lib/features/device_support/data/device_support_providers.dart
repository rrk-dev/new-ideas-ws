import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_support_providers.g.dart';

/// Whether this device meets the minimum CPU (see `isDeviceSupported`).
/// `bootstrap` overrides it with the launch probe over `vv_native`; the
/// default (tests, host tools) is supported.
@Riverpod(keepAlive: true)
bool deviceSupported(Ref ref) => true;
