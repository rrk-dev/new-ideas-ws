import 'package:vaultvoice/core/errors/result.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement.dart';

const annualProductId = 'vv_pro_annual';
const lifetimeProductId = 'vv_pro_lifetime';

class StoreProduct {
  const StoreProduct({required this.id, required this.price});
  final String id;
  final String price;
}

enum PurchaseOutcome { purchased, pending, cancelled }

/// Native implementations expose only verified, currently owned products.
abstract interface class PurchaseStore {
  EntitlementSource get source;
  Stream<void> get changes;
  Future<Result<List<StoreProduct>>> products();
  Future<Result<List<StoreOwnership>>> currentEntitlements();
  Future<Result<PurchaseOutcome>> purchase(String productId);
  Future<Result<void>> restore();
  Future<void> dispose();
}

class StoreOwnership {
  const StoreOwnership(this.productId, {this.expiresAt});
  final String productId;
  final DateTime? expiresAt;
}

/// Persist the successful snapshot, never the extended grace entitlement.
class VerifiedPurchase {
  const VerifiedPurchase({
    required this.plan,
    required this.source,
    required this.verifiedAt,
    this.expiresAt,
  });

  factory VerifiedPurchase.fromJson(Map<String, Object?> json) =>
      VerifiedPurchase(
        plan: Plan.values.byName(json['plan']! as String),
        source: EntitlementSource.values.byName(json['source']! as String),
        verifiedAt: DateTime.fromMillisecondsSinceEpoch(
          json['verifiedAt']! as int,
          isUtc: true,
        ),
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                json['expiresAt']! as int,
                isUtc: true,
              ),
      );

  final Plan plan;
  final EntitlementSource source;
  final DateTime verifiedAt;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
    'plan': plan.name,
    'source': source.name,
    'verifiedAt': verifiedAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt?.millisecondsSinceEpoch,
  };

  Entitlement resolve(DateTime now, {required bool unavailable}) {
    if (verifiedAt.isAfter(now) ||
        (plan != Plan.free &&
            plan != Plan.proAnnual &&
            plan != Plan.proLifetime) ||
        (source != EntitlementSource.appStore &&
            source != EntitlementSource.googlePlay)) {
      return Entitlement.free(now);
    }
    var expiry = expiresAt;
    if (unavailable && plan == Plan.proAnnual && expiry != null) {
      final expiryLimit = expiry.add(const Duration(days: 30));
      final verificationLimit = verifiedAt.add(const Duration(days: 30));
      expiry = expiryLimit.isBefore(verificationLimit)
          ? expiryLimit
          : verificationLimit;
    }
    return Entitlement(
      plan: plan,
      verifiedAt: verifiedAt,
      source: source,
      expiresAt: expiry,
    );
  }
}

VerifiedPurchase verifiedSnapshot(
  List<StoreOwnership> owned,
  DateTime now,
  EntitlementSource source,
) {
  final lifetime = owned.any((p) => p.productId == lifetimeProductId);
  DateTime? expiry;
  for (final p in owned.where((p) => p.productId == annualProductId)) {
    final at = p.expiresAt;
    if (at != null &&
        at.isAfter(now) &&
        (expiry == null || at.isAfter(expiry))) {
      expiry = at;
    }
  }
  return VerifiedPurchase(
    plan: lifetime
        ? Plan.proLifetime
        : expiry == null
        ? Plan.free
        : Plan.proAnnual,
    source: source,
    verifiedAt: now,
    expiresAt: lifetime ? null : expiry,
  );
}
