import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vaultvoice/features/licensing/data/licensing_providers.dart';
import 'package:vaultvoice/features/transcription/domain/stt_model_policy.dart';

part 'stt_model_providers.g.dart';

/// The STT plan gate backed by LIC-01's single entitlement authority
/// (`EntitlementService`). Model pickers and the engine factory resolve the
/// model with [resolveSttModel] / [sttModelAccess] through this gate, so a
/// plan change or expiry applies immediately.
@Riverpod(keepAlive: true)
SttPlanGate sttPlanGate(Ref ref) =>
    SttPlanGate.entitlements(ref.watch(entitlementServiceProvider));
