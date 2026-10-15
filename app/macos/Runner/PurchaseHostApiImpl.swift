import FlutterMacOS
import Foundation

/// macOS has no store billing in this build (the Mac App Store listing is not
/// part of the plan). The host answers every `PurchaseHostApi` call with the
/// documented `unavailable` error, which Dart maps to
/// `UnsupportedFeatureFailure('store unavailable')` — a clean result instead
/// of a `MissingPluginException`. No StoreKit, no network.
final class PurchaseHostApiImpl: PurchaseHostApi {
  private func unavailable() -> PurchasePigeonError {
    PurchasePigeonError(code: "unavailable", message: "store unavailable on macOS", details: nil)
  }

  func products(completion: @escaping (Result<[StoreProductMessage], Error>) -> Void) {
    completion(.failure(unavailable()))
  }

  func currentEntitlements(
    completion: @escaping (Result<[StoreEntitlementMessage], Error>) -> Void
  ) {
    completion(.failure(unavailable()))
  }

  func purchase(
    productId: String, completion: @escaping (Result<StorePurchaseOutcome, Error>) -> Void
  ) {
    completion(.failure(unavailable()))
  }

  func restore(completion: @escaping (Result<Void, Error>) -> Void) {
    completion(.failure(unavailable()))
  }
}
