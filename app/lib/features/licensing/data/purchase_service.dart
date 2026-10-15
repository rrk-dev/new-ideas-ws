import 'dart:async';

import 'package:vaultvoice/core/errors/failure.dart';
import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/core/platform/clock.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';
import 'package:vaultvoice/features/licensing/domain/store_purchase.dart';
import 'package:vaultvoice/features/settings/domain/settings_ports.dart';

const purchaseCacheKey = 'licensing.verified_purchase.v1';

/// Serializes launch, restore, purchase and unsolicited store updates so an
/// older response cannot overwrite a newer refund. Settings uses encrypted DB.
class PurchaseService {
  PurchaseService({
    required this.store,
    required this.settings,
    required this.entitlements,
    required this.clock,
  });

  final PurchaseStore store;
  final SettingsStore settings;
  final EntitlementService entitlements;
  final Clock clock;
  VerifiedPurchase? _verified;
  Future<void> _tail = Future.value();
  StreamSubscription<void>? _subscription;
  bool _disposed = false;
  bool _started = false;

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> start() => _serial(() async {
    if (_started || _disposed) return;
    _started = true;
    _subscription = store.changes.listen((_) => unawaited(refresh()));
    try {
      final raw = await settings.watch(purchaseCacheKey).first;
      if (raw is Map<String, Object?>) {
        _verified = VerifiedPurchase.fromJson(raw);
        if (_verified!.source != store.source) _verified = null;
      }
    } on Object {
      _verified = null;
    }
    // An outage is not known yet: initially grant only the original period.
    _publish(unavailable: false);
    await _refresh();
  });

  Future<Result<void>> refresh() => _serial(_refresh);

  Future<Result<void>> _refresh() async {
    if (_disposed) return const Err(CancelledFailure());
    final result = await store.currentEntitlements();
    if (_disposed) return const Err(CancelledFailure());
    Failure? denial;
    switch (result) {
      case Ok(:final value):
        _verified = verifiedSnapshot(value, clock.now(), store.source);
      case Err(:final failure):
        if (failure is! NativeFailure || failure.code != 1) {
          _publish(unavailable: true);
          return Err(failure);
        }
        // Invalid verification is a definitive denial, never offline grace.
        denial = failure;
        _verified = verifiedSnapshot(const [], clock.now(), store.source);
    }
    _publish(unavailable: false);
    final saved = await settings.set(purchaseCacheKey, _verified!.toJson());
    return denial == null ? saved : Err(denial);
  }

  void _publish({required bool unavailable}) {
    if (!_disposed) {
      entitlements.update(
        _verified?.resolve(clock.now(), unavailable: unavailable) ??
            Entitlement.free(clock.now()),
      );
    }
  }

  Future<Result<PurchaseOutcome>> purchase(String id) => _serial(() async {
    if (_disposed || (id != annualProductId && id != lifetimeProductId)) {
      return const Err(UnsupportedFeatureFailure('store product'));
    }
    final result = await store.purchase(id);
    if (result case Ok(value: PurchaseOutcome.purchased)) {
      final verification = await _refresh();
      if (verification case Err(:final failure)) return Err(failure);
      if (_verified?.plan != Plan.proLifetime &&
          (id != annualProductId || _verified?.plan != Plan.proAnnual)) {
        return const Err(UnsupportedFeatureFailure('store ownership'));
      }
    } else if (result case Err(failure: NativeFailure(code: 1))) {
      _verified = verifiedSnapshot(const [], clock.now(), store.source);
      _publish(unavailable: false);
      await settings.set(purchaseCacheKey, _verified!.toJson());
    }
    return result;
  });

  Future<Result<void>> restore() => _serial(() async {
    final result = await store.restore();
    if (result case Err(:final failure)) {
      if (failure is NativeFailure && failure.code == 1) {
        _verified = verifiedSnapshot(const [], clock.now(), store.source);
        _publish(unavailable: false);
        await settings.set(purchaseCacheKey, _verified!.toJson());
      } else {
        _publish(unavailable: true);
      }
      return Err(failure);
    }
    return await _refresh();
  });

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await store.dispose();
  }
}
