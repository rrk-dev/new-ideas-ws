import ActivityKit
import Foundation

/// AUD-13 Live Activity data, compiled into both the Runner and the
/// LumenWidgets extension. It carries state only: whether capture is running
/// and the instant the on-screen timer counts from. No transcript, title,
/// file name or other recording-derived text, and no push token (updates are
/// local, `pushType: nil`).
@available(iOS 16.1, *)
struct RecordingActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// True while capturing, false while paused.
    var recording: Bool
    /// Wall-clock instant the timer counts up from (recording only).
    var timerStart: Date?
  }
}
