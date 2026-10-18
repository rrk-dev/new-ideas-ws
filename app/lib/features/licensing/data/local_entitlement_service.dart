import 'dart:async';

import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/feature_access.dart';
import 'package:vaultvoice/features/licensing/domain/feature_matrix.dart';

/// In-process [EntitlementService]: holds the latest entitlement and
/// re-resolves it when it expires (a timer fires at `expiresAt`) or when
/// [refresh] is called (e.g. on app resume, after the wall clock jumped).
///
/// Persistence of verified purchases is LIC-02's job; a fresh install
/// starts as [Plan.free].
class LocalEntitlementService implements EntitlementService {
  LocalEntitlementService({
    required this.clock,
    required this.mode,
    this.proTierEnforced = true,
    Entitlement? initial,
  }) : _entitlement = initial ?? Entitlement.free(clock.now()) {
    _access = _resolve();
    _schedule();
  }

  final Clock clock;
  final DistributionMode mode;

  /// The LIC-05 suppression switch: `false` opens the Pro column to everyone.
  final bool proTierEnforced;

  final _controller = StreamController<FeatureAccess>.broadcast();
  Entitlement _entitlement;
  late FeatureAccess _access;
  Timer? _timer;

  @override
  FeatureAccess get access => _access;

  @override
  Stream<FeatureAccess> get changes => _controller.stream;

  @override
  bool has(Feature feature) => _access.has(feature);

  @override
  void update(Entitlement entitlement) {
    _entitlement = entitlement;
    _publish();
  }

  @override
  void refresh() => _publish();

  FeatureAccess _resolve() => FeatureAccess.resolve(
    _entitlement,
    now: clock.now(),
    mode: mode,
    proTierEnforced: proTierEnforced,
  );

  void _publish() {
    final next = _resolve();
    final changed =
        !next.entitlement.sameAs(_access.entitlement) ||
        next.effectivePlan != _access.effectivePlan ||
        next.features.length != _access.features.length ||
        !next.features.containsAll(_access.features);
    _access = next;
    _schedule();
    if (changed && !_controller.isClosed) _controller.add(next);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final now = clock.now();
    final at = _entitlement.nextChangeAfter(now);
    if (at == null) return;
    // +1 ms so the check runs strictly after the expiry instant.
    _timer = Timer(at.difference(now) + const Duration(milliseconds: 1), () {
      _timer = null;
      _publish();
    });
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
