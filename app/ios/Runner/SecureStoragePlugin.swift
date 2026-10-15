import Flutter
import Foundation
import Security

/// SEC-01 (ADR-SEC-01-file-encryption): data keys + file protection.
///
/// Keys are random 32-byte values stored as Keychain generic passwords
/// (service `com.vaultvoice.keys`, account = key name) with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: readable by background
/// recording/processing while the device is locked, never synced to iCloud
/// Keychain and never restored to another device. The Keychain itself is
/// protected by the Secure Enclave-held class keys.
///
/// `protectDirectory` sets `NSFileProtectionCompleteUntilFirstUserAuthentication`
/// on the `vv/` root (new files inherit the directory's class; `.complete`
/// would make chunk files unwritable while the device is locked and break
/// background recording) and `isExcludedFromBackup`.
///
/// Channel `vaultvoice/secure_storage`:
/// - `getOrCreateKey({name})` -> `{key: FlutterStandardTypedData(32), hardwareBacked: Bool}`
/// - `deleteKey({name})`, `deleteAllKeys()`
/// - `protectDirectory({path})` -> `{protectionClass, excludedFromBackup}`
/// Verified against the iOS 16 SDK Security / Foundation APIs.
final class SecureStoragePlugin: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/secure_storage"
  private static let service = "com.vaultvoice.keys"
  private static let keyBytes = 32
  private let queue = DispatchQueue(label: "com.vaultvoice.secure_storage")

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SecureStoragePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getOrCreateKey", "deleteKey":
      guard let name = args?["name"] as? String, Self.validName(name) else {
        result(FlutterError(code: "invalid_name", message: "invalid key name", details: nil))
        return
      }
      let create = call.method == "getOrCreateKey"
      queue.async {
        let reply: Any?
        if create {
          reply = Self.getOrCreate(name)
        } else {
          let status = SecItemDelete(Self.query(name) as CFDictionary)
          reply = (status == errSecSuccess || status == errSecItemNotFound)
            ? nil : Self.error(status)
        }
        DispatchQueue.main.async { result(reply) }
      }
    case "deleteAllKeys":
      queue.async {
        let query: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: Self.service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        let reply: Any? = (status == errSecSuccess || status == errSecItemNotFound)
          ? nil : Self.error(status)
        DispatchQueue.main.async { result(reply) }
      }
    case "protectDirectory":
      guard let path = args?["path"] as? String else {
        result(FlutterError(code: "invalid_path", message: "missing path", details: nil))
        return
      }
      result(Self.protect(path))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func validName(_ name: String) -> Bool {
    !name.isEmpty && name.count <= 64
      && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
  }

  private static func query(_ name: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: name,
    ]
  }

  private static func error(_ status: OSStatus) -> FlutterError {
    // OSStatus only: never key material.
    FlutterError(code: "keychain", message: "OSStatus \(status)", details: nil)
  }

  private static func getOrCreate(_ name: String) -> Any {
    var read = query(name)
    read[kSecReturnData as String] = true
    read[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(read as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data, data.count == keyBytes {
      return reply(data)
    }
    if status != errSecItemNotFound && status != errSecSuccess {
      return error(status)
    }
    var bytes = [UInt8](repeating: 0, count: keyBytes)
    let rnd = SecRandomCopyBytes(kSecRandomDefault, keyBytes, &bytes)
    guard rnd == errSecSuccess else { return error(rnd) }
    let data = Data(bytes)
    var add = query(name)
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    if status == errSecSuccess {
      // A malformed item (wrong length): replace it.
      SecItemDelete(query(name) as CFDictionary)
    }
    let added = SecItemAdd(add as CFDictionary, nil)
    guard added == errSecSuccess else { return error(added) }
    return reply(data)
  }

  private static func reply(_ data: Data) -> [String: Any] {
    // Keychain items are encrypted with Secure Enclave-protected class keys.
    ["key": FlutterStandardTypedData(bytes: data), "hardwareBacked": true]
  }

  private static func protect(_ path: String) -> Any {
    let fm = FileManager.default
    do {
      try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
      try fm.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: path)
      var url = URL(fileURLWithPath: path, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
      return [
        "protectionClass": "completeUntilFirstUserAuthentication",
        "excludedFromBackup": true,
      ] as [String: Any]
    } catch {
      return FlutterError(code: "protection", message: "setAttributes failed", details: nil)
    }
  }
}
