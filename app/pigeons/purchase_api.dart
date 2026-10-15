import 'package:pigeon/pigeon.dart';

// Verified against Pigeon 29.0.8; StoreKit 2 / Play Billing 9.1.0.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/features/licensing/data/purchase_api.g.dart',
    swiftOut: 'ios/Runner/PurchaseApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'PurchasePigeonError'),
    kotlinOut: 'android/app/src/main/kotlin/com/vaultvoice/vaultvoice/billing/PurchaseApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.vaultvoice.vaultvoice.billing'),
    dartPackageName: 'vaultvoice',
  ),
)
class StoreProductMessage {
  StoreProductMessage({required this.id, required this.price});
  String id;
  String price;
}

class StoreEntitlementMessage {
  StoreEntitlementMessage({required this.productId, this.expiresAtMs});
  String productId;
  int? expiresAtMs;
}

enum StorePurchaseOutcome { purchased, pending, cancelled }

@HostApi()
abstract class PurchaseHostApi {
  @asyncCallback
  List<StoreProductMessage> products();
  @asyncCallback
  List<StoreEntitlementMessage> currentEntitlements();
  @asyncCallback
  StorePurchaseOutcome purchase(String productId);
  @asyncCallback
  void restore();
}

@FlutterApi()
abstract class PurchaseFlutterApi {
  @asyncCallback
  void changed();
}
