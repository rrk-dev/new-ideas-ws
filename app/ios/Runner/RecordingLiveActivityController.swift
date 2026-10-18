import ActivityKit
import Foundation

/// AUD-13: starts, updates and ends the recording Live Activity from the
/// `show` / `hide` calls of `vaultvoice/recording_indicator`. Those calls
/// only follow the in-app Record tap (RecordingIndicatorBinding). Only the
/// `liveActivity` map ({recording, timerStartMs}) is read; the Activity has
/// no buttons that start, resume or stop capture. No push token is requested.
final class RecordingLiveActivityController {
  private var current: Any?  // Activity<RecordingActivityAttributes> on iOS 16.2+

  func show(_ payload: [String: Any]?) {
    guard #available(iOS 16.2, *), let payload else { return }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let recording = payload["recording"] as? Bool ?? false
    var start: Date?
    if recording, let ms = (payload["timerStartMs"] as? NSNumber)?.doubleValue {
      start = Date(timeIntervalSince1970: ms / 1000)
    }
    let state = RecordingActivityAttributes.ContentState(recording: recording, timerStart: start)
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity = current as? Activity<RecordingActivityAttributes> {
      Task { await activity.update(content) }
      return
    }
    current = try? Activity.request(
      attributes: RecordingActivityAttributes(), content: content, pushType: nil)
  }

  func hide() {
    guard #available(iOS 16.2, *) else { return }
    let activity = current as? Activity<RecordingActivityAttributes>
    current = nil
    Task { await activity?.end(nil, dismissalPolicy: .immediate) }
    // Also end any activity left over from a previous process.
    Task {
      for leftover in Activity<RecordingActivityAttributes>.activities {
        await leftover.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}
