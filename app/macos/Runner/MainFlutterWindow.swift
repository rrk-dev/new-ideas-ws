import Cocoa
import FlutterMacOS

/// macOS runner window. Verified against the Flutter 3.47.7 macOS template.
///
/// Pointer use (FND-09): standard close, minimize, and zoom buttons, and a
/// minimum content size so the Record screen stays usable.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
    contentMinSize = NSSize(width: 800, height: 600)
    if let displayName = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleDisplayName"
    ) as? String, !displayName.isEmpty {
      title = displayName
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacAudioRouteObserver.register(
      with: flutterViewController.registrar(forPlugin: "MacAudioRouteObserver")
    )

    super.awakeFromNib()
  }
}
