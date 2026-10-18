import SwiftUI
import WidgetKit

@main
struct LumenWidgetsBundle: WidgetBundle {
  @WidgetBundleBuilder
  var body: some Widget {
    RecordWidget()
    if #available(iOS 18.0, *) {
      RecordControl()
    }
    if #available(iOS 16.2, *) {
      RecordingActivityWidget()
    }
  }
}
