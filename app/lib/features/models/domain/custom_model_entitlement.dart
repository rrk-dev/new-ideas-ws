/// Whether this install may import unsigned "advanced: custom model" GGUFs.
///
/// PLACEHOLDER (MDL-04): LIC-01 (entitlements) is not merged yet. The
/// default implementation denies; LIC-01 must override
/// `customModelEntitlementProvider` with the real Pro check. Which tier
/// unlocks custom models is a product decision (vv-licensing-iap); the task
/// file says Pro.
abstract interface class CustomModelEntitlement {
  Future<bool> allowsCustomModels();
}

/// Denies until LIC-01 provides the real entitlement.
class DenyCustomModels implements CustomModelEntitlement {
  const DenyCustomModels();

  @override
  Future<bool> allowsCustomModels() async => false;
}
