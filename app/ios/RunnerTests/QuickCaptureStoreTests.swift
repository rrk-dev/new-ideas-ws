import XCTest

@testable import Runner

/// QCP-02 native unit tests of the in-memory hand-off store (injected clock).
final class QuickCaptureStoreTests: XCTestCase {
  private var now: TimeInterval = 1000

  private func makeStore() -> QuickCaptureStore {
    QuickCaptureStore(uptime: { self.now })
  }

  func testConsumeReturnsRequestOnceThenNil() {
    let store = makeStore()
    store.submit(entry: .iosControl)
    let first = store.consume()
    XCTAssertEqual(first?.entry, .iosControl)
    XCTAssertNil(store.consume())
  }

  func testNothingPendingAtLaunchReturnsNil() {
    XCTAssertNil(makeStore().consume())
  }

  func testExpiredRequestIsDropped() {
    let store = makeStore()
    store.submit(entry: .iosWidget)
    now += QuickCaptureStore.ttl + 0.1
    XCTAssertNil(store.consume())
    XCTAssertNil(store.consume())
  }

  func testRemainingTimeIsAtMostTtl() {
    let store = makeStore()
    store.submit(entry: .iosWidget)
    now += 4
    let remaining = store.consume()?.remainingMs ?? 0
    XCTAssertGreaterThan(remaining, 0)
    XCTAssertLessThanOrEqual(remaining, 6000)
  }

  func testWidgetUrlCreatesRequestAndOtherUrlsAreIgnored() {
    let store = makeStore()
    XCTAssertFalse(store.submit(url: URL(string: "https://example.com/record")!))
    XCTAssertNil(store.consume())
    XCTAssertTrue(store.submit(url: URL(string: "lumen://record?entry=widget")!))
    XCTAssertEqual(store.consume()?.entry, .iosWidget)
  }

  func testUnknownEntryIsDroppedButClaimed() {
    let store = makeStore()
    XCTAssertTrue(store.submit(url: URL(string: "lumen://record?entry=start")!))
    XCTAssertNil(store.consume())
  }

  func testIdsAreUniqueUuids() {
    let store = makeStore()
    let a = store.submit(entry: .iosWidget)
    let b = store.submit(entry: .iosWidget)
    XCTAssertNotEqual(a, b)
    XCTAssertNotNil(UUID(uuidString: a))
  }
}
