import UIKit
import UniformTypeIdentifiers

/// AUD-06 share extension ("Share → VaultVoice" from Voice Memos, Files, …).
///
/// NOT yet part of the Xcode project: wiring the extension target into
/// `Runner.xcodeproj` (bundle id `<app id>.ShareExtension`, App Group
/// `group.<app id>` on both targets, embed in Runner) is follow-up AUD-10 —
/// it needs Xcode and signing. See docs/audio-import.md.
///
/// The extension never decodes or processes anything: it copies each shared
/// audio file into the App Group inbox `group.<app id>/Inbox/Audio`, then
/// asks the user to open VaultVoice, where the import (with the rights /
/// consent attestation, SEC-09) happens. Files are named by UUID; nothing is
/// logged.
final class ShareViewController: UIViewController {
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task { await self.handOver() }
  }

  private func handOver() async {
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }
    guard let inbox = Self.inbox() else {
      extensionContext?.cancelRequest(withError: NSError(domain: "vaultvoice", code: 1))
      return
    }
    try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    for provider in providers {
      await Self.copy(provider, into: inbox)
    }
    extensionContext?.completeRequest(returningItems: nil)
  }

  private static func copy(_ provider: NSItemProvider, into inbox: URL) async {
    await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
      provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { url, _ in
        // `url` is deleted when this handler returns: copy synchronously.
        if let url {
          let ext = url.pathExtension.lowercased()
          let dst = inbox.appendingPathComponent(
            UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
          try? FileManager.default.copyItem(at: url, to: dst)
        }
        done.resume()
      }
    }
  }

  /// The extension's bundle id is `<app id>.ShareExtension`.
  private static func inbox() -> URL? {
    guard let id = Bundle.main.bundleIdentifier,
      let appId = id.components(separatedBy: ".ShareExtension").first,
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.\(appId)")
    else { return nil }
    return container.appendingPathComponent("Inbox/Audio", isDirectory: true)
  }
}
