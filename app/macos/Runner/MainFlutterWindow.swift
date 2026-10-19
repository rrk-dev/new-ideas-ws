import Cocoa
import FlutterMacOS

/// macOS runner window. Verified against the Flutter 3.47.7 macOS template.
///
/// Pointer use (FND-09): standard close, minimize, and zoom buttons, and a
/// minimum content size so the Record screen stays usable.
class MainFlutterWindow: NSWindow {
  // Pigeon host APIs must outlive registration (the messenger holds them weakly).
  private let bookmarkApi = BookmarkHostApiImpl()
  private let purchaseApi = PurchaseHostApiImpl()
  private let remindersApi = RemindersHostApiImpl()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    styleMask.formUnion([.titled, .closable, .miniaturizable, .resizable])
    contentMinSize = NSSize(width: 800, height: 600)
    // Open large enough to show a whole screen without scrolling.
    if let visible = (self.screen ?? NSScreen.main)?.visibleFrame {
      let size = NSSize(
        width: min(1100, visible.width * 0.9),
        height: min(820, visible.height * 0.92)
      )
      setContentSize(size)
      setFrameOrigin(
        NSPoint(
          x: visible.midX - frame.width / 2,
          y: visible.midY - frame.height / 2
        )
      )
    }
    if let displayName = Bundle.main.object(
      forInfoDictionaryKey: "CFBundleDisplayName"
    ) as? String, !displayName.isEmpty {
      title = displayName
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacAudioRouteObserver.register(
      with: flutterViewController.registrar(forPlugin: "MacAudioRouteObserver")
    )

    registerHostChannels(flutterViewController)

    super.awakeFromNib()
  }

  /// FND-09: every platform channel the Dart side calls on macOS. Each one
  /// answers (possibly with a documented "unsupported" value) so nothing
  /// throws `MissingPluginException`.
  private func registerHostChannels(_ controller: FlutterViewController) {
    func registrar(_ name: String) -> FlutterPluginRegistrar {
      controller.registrar(forPlugin: name)
    }
    MacHostChannels.register(with: registrar("MacHostChannels"))
    AppLockPlugin.register(with: registrar("AppLockPlugin"))
    SecureStoragePlugin.register(with: registrar("SecureStoragePlugin"))
    AudioImportPlugin.register(with: registrar("AudioImportPlugin"))
    ManagedConfigPlugin.register(with: registrar("ManagedConfigPlugin"))
    let messenger = registrar("VaultBookmarks").messenger
    BookmarkHostApiSetup.setUp(binaryMessenger: messenger, api: bookmarkApi)
    PurchaseHostApiSetup.setUp(binaryMessenger: messenger, api: purchaseApi)
    RemindersHostApiSetup.setUp(binaryMessenger: messenger, api: remindersApi)
  }
}
