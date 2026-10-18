import ActivityKit
import SwiftUI
import WidgetKit

/// AUD-13 recording Live Activity (Lock Screen + Dynamic Island). Static
/// words and a timer only; it reads no database or shared container, has no
/// buttons and no intent, and a tap just opens the Record screen through the
/// same validated link as the QCP-02 widget.
@available(iOS 16.2, *)
struct RecordingActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
      RecordingActivityLockView(state: context.state)
        .widgetURL(LumenWidgetContent.url)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(RecordingActivityText.title(context.state), systemImage: RecordingActivityText.symbol(context.state))
        }
        DynamicIslandExpandedRegion(.trailing) {
          RecordingTimerText(state: context.state)
        }
      } compactLeading: {
        Image(systemName: RecordingActivityText.symbol(context.state))
      } compactTrailing: {
        RecordingTimerText(state: context.state).frame(maxWidth: 48)
      } minimal: {
        Image(systemName: RecordingActivityText.symbol(context.state))
      }
      .widgetURL(LumenWidgetContent.url)
    }
  }
}

@available(iOS 16.2, *)
enum RecordingActivityText {
  static func title(_ state: RecordingActivityAttributes.ContentState) -> String {
    state.recording ? "Recording" : "Paused"
  }

  static func symbol(_ state: RecordingActivityAttributes.ContentState) -> String {
    state.recording ? "mic.fill" : "pause.fill"
  }
}

@available(iOS 16.2, *)
struct RecordingTimerText: View {
  let state: RecordingActivityAttributes.ContentState

  var body: some View {
    if state.recording, let start = state.timerStart {
      Text(start, style: .timer).monospacedDigit()
    } else {
      Text("Paused")
    }
  }
}

@available(iOS 16.2, *)
struct RecordingActivityLockView: View {
  let state: RecordingActivityAttributes.ContentState

  var body: some View {
    HStack {
      Label(RecordingActivityText.title(state), systemImage: RecordingActivityText.symbol(state))
      Spacer()
      Text("Lumen").font(.caption)
      RecordingTimerText(state: state)
    }
    .padding()
  }
}
