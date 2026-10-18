import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // QCP-02: the widget's `lumen://record` URL (cold launch). Handled here and
  // not passed on, so Flutter's own deep-link routing never sees it.
  override func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    for context in connectionOptions.urlContexts {
      _ = QuickCaptureStore.shared.submit(url: context.url)
    }
  }

  // QCP-02: warm launch.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let rest = URLContexts.filter { !QuickCaptureStore.shared.submit(url: $0.url) }
    if !rest.isEmpty { super.scene(scene, openURLContexts: rest) }
  }
}
