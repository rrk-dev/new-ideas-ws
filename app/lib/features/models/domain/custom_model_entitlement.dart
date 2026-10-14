import 'package:vaultvoice/features/licensing/domain/entitlement.dart';
import 'package:vaultvoice/features/licensing/domain/entitlement_service.dart';

/// Whether this install may import unsigned "advanced: custom model" GGUFs.
///
/// Backed by LIC-01's `Feature.sideloadCustomModel` (integration wave 2,
/// [EntitlementCustomModels]); the import additionally needs the user's
/// "advanced: custom models" setting. Which tier unlocks it is LIC-01's
/// feature matrix (PRODUCT-DECISION there: Pro / personal build).
abstract interface class CustomModelEntitlement {
  Future<bool> allowsCustomModels();
}

/// Always denies (tests, and the importer's default when no entitlement is
/// injected).
class DenyCustomModels implements CustomModelEntitlement {
  const DenyCustomModels();

  @override
  Future<bool> allowsCustomModels() async => false;
}

/// The LIC-01 entitlement check: `EntitlementService.has(sideloadCustomModel)`
/// at the moment of the import (follows plan changes and expiry).
class EntitlementCustomModels implements CustomModelEntitlement {
  const EntitlementCustomModels(this._entitlements);

  final EntitlementService _entitlements;

  @override
  Future<bool> allowsCustomModels() async =>
      _entitlements.has(Feature.sideloadCustomModel);
}
