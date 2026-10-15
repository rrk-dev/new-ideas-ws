import Flutter
import StoreKit
import Network

// StoreKit 2 APIs, verified against Apple documentation 2026-10-14.
// Listener begins at application launch, before Flutter attaches.
@MainActor
final class PurchaseHostApiImpl: PurchaseHostApi {
  private let ids: Set<String> = ["vv_pro_annual", "vv_pro_lifetime"]
  private var listener: Task<Void, Never>?
  var updates: PurchaseFlutterApi?
  private let monitor = NWPathMonitor()
  private var online = false

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in
        self?.online = path.status == .satisfied
        self?.updates?.changed { _ in }
      }
    }
    monitor.start(queue: DispatchQueue(label: "vaultvoice.store.reachability"))
    listener = Task { [weak self] in
      for await result in Transaction.updates {
        guard let self else { return }
        if case .verified(let transaction) = result, self.ids.contains(transaction.productID) {
          // The authoritative currentEntitlements query below handles revocation,
          // renewal, family sharing and downgrade before UI enables features.
          self.updates?.changed { _ in }
          await transaction.finish()
        } else if case .unverified = result {
          // Query will fail closed on an unverified current entitlement.
          self.updates?.changed { _ in }
        }
      }
    }
  }

  deinit { listener?.cancel(); monitor.cancel() }

  private func failure(_ code: String) -> PurchasePigeonError {
    PurchasePigeonError(code: code, message: "Store operation failed", details: nil)
  }

  private func validProduct(_ product: Product) -> Bool {
    if product.id == "vv_pro_lifetime" { return product.type == .nonConsumable }
    guard product.id == "vv_pro_annual", product.type == .autoRenewable,
      let period = product.subscription?.subscriptionPeriod else { return false }
    return period.unit == .year && period.value == 1
  }

  func products(completion: @escaping (Result<[StoreProductMessage], Error>) -> Void) {
    Task {
      do {
        let products = try await Product.products(for: ids)
        completion(.success(products.filter { validProduct($0) }.sorted { $0.id < $1.id }.map {
          StoreProductMessage(id: $0.id, price: $0.displayPrice)
        }))
      } catch { completion(.failure(failure("unavailable"))) }
    }
  }

  func currentEntitlements(completion: @escaping (Result<[StoreEntitlementMessage], Error>) -> Void) {
    guard online else { completion(.failure(failure("unavailable"))); return }
    Task {
      var owned: [StoreEntitlementMessage] = []
      for await result in Transaction.currentEntitlements {
        guard case .verified(let t) = result else {
          completion(.failure(failure("verification_failed")))
          return
        }
        guard ids.contains(t.productID), t.revocationDate == nil, !t.isUpgraded else { continue }
        if let expiry = t.expirationDate, expiry <= Date() { continue }
        owned.append(StoreEntitlementMessage(productId: t.productID,
          expiresAtMs: t.expirationDate.map { Int64($0.timeIntervalSince1970 * 1000) }))
      }
      completion(.success(owned))
    }
  }

  func purchase(productId: String, completion: @escaping (Result<StorePurchaseOutcome, Error>) -> Void) {
    guard ids.contains(productId) else { completion(.failure(failure("invalid_product"))); return }
    Task {
      do {
        guard let product = try await Product.products(for: [productId]).first, validProduct(product) else {
          completion(.failure(failure("unavailable"))); return
        }
        switch try await product.purchase() {
        case .success(let result):
          guard case .verified(let transaction) = result,
            transaction.productID == productId, transaction.revocationDate == nil else {
            completion(.failure(failure("verification_failed"))); return
          }
          await transaction.finish()
          updates?.changed { _ in }
          completion(.success(.purchased))
        case .pending: completion(.success(.pending))
        case .userCancelled: completion(.success(.cancelled))
        @unknown default: completion(.failure(failure("unavailable")))
        }
      } catch { completion(.failure(failure("unavailable"))) }
    }
  }

  func restore(completion: @escaping (Result<Void, Error>) -> Void) {
    Task {
      do {
        try await AppStore.sync()
        completion(.success(()))
      } catch { completion(.failure(failure("unavailable"))) }
    }
  }
}
