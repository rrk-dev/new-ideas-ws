import SwiftUI
import WidgetKit

/// QCP-02 control (iOS 18+): a stateless button that opens Lumen on the
/// Record screen. Static label and icon only (ADR-QCP-01 content rule).
@available(iOS 18.0, *)
struct RecordControl: ControlWidget {
  static let kind = "LumenRecordControl"

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: Self.kind) {
      ControlWidgetButton(action: OpenRecordScreenIntent()) {
        Label(LumenWidgetContent.title, systemImage: LumenWidgetContent.symbol)
      }
    }
    .displayName("Record")
    .description("Opens Lumen on the Record screen.")
  }
}
