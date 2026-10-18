import SwiftUI
import WidgetKit

/// QCP-02 Home Screen / Lock Screen widget. Static content only: a fixed
/// icon and the words "Record" and "Lumen". It reads no database, shared
/// container or recording state, has no microphone code and makes no network
/// request. A tap opens the app via `widgetURL` (iOS 14+), which the Runner
/// turns into a navigate-only hand-off.
struct RecordEntry: TimelineEntry {
  let date: Date
}

struct RecordProvider: TimelineProvider {
  func placeholder(in context: Context) -> RecordEntry { RecordEntry(date: Date(timeIntervalSince1970: 0)) }

  func getSnapshot(in context: Context, completion: @escaping (RecordEntry) -> Void) {
    completion(placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RecordEntry>) -> Void) {
    completion(Timeline(entries: [placeholder(in: context)], policy: .never))
  }
}

enum LumenWidgetContent {
  static let title = "Record"
  static let appName = "Lumen"
  static let symbol = "mic.fill"
  // Fixed URL; the app validates and only opens the Record screen.
  static let url = URL(string: "lumen://record?entry=widget")!
}

struct RecordWidgetView: View {
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      switch family {
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: LumenWidgetContent.symbol)
        }
      case .accessoryRectangular:
        VStack(alignment: .leading) {
          Label(LumenWidgetContent.title, systemImage: LumenWidgetContent.symbol)
          Text(LumenWidgetContent.appName)
        }
      default:
        VStack(spacing: 8) {
          Image(systemName: LumenWidgetContent.symbol).font(.largeTitle)
          Text(LumenWidgetContent.title).font(.headline)
          Text(LumenWidgetContent.appName).font(.caption)
        }
      }
    }
    .widgetURL(LumenWidgetContent.url)
    .modifier(WidgetBackground())
  }
}

// `containerBackground(for:)` is iOS 17+; the extension supports iOS 16.
struct WidgetBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(.fill.tertiary, for: .widget)
    } else {
      content.padding()
    }
  }
}

struct RecordWidget: Widget {
  let kind = "LumenRecordWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: RecordProvider()) { _ in
      RecordWidgetView()
    }
    .configurationDisplayName("Record")
    .description("Opens Lumen on the Record screen.")
    .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
  }
}
