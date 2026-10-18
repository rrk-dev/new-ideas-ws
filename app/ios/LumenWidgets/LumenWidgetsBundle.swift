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
  }
}
