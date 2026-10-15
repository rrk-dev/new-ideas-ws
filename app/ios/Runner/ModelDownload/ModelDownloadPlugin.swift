import Flutter
import Foundation
import Network
import UIKit

/// MDL-02 model downloads (iOS), see docs/adr/ADR-MDL-02-model-downloader.md.
///
/// Channel `vaultvoice/model_download` (same contract as Android):
/// - `freeBytes {path}` → Int64? (`volumeAvailableCapacityForImportantUsage`)
/// - `networkStatus` → {connected, unmetered (!expensive && !constrained),
///   lowPowerMode}
/// - `excludeFromBackup {path}` → Bool (`isExcludedFromBackup` on the dir)
/// - `keepAliveStart/Update/Stop` → `beginBackgroundTask` grace period
/// - `bgStart {key,url,headers,partialPath,offset,total,allowCellular,
///   allowedHosts}`, `bgPause {key}`, `bgCancel {key}`, `bgAck {key}` —
///   background `URLSession` transport for long downloads; outcomes arrive
///   as `bgEvent` calls to Dart.
///
/// The Dart `NetworkGateway` resolves and validates every redirect before
/// `bgStart`; background sessions follow redirects on their own, so the
/// session re-checks the current request host on every progress callback
/// and on completion and discards the bytes of an unlisted host.
/// Verified against the iOS 18 SDK documentation (URLSession, NWPathMonitor).
final class ModelDownloadPlugin: NSObject, FlutterPlugin {
  static let channelName = "vaultvoice/model_download"

  private let channel: FlutterMethodChannel
  private let monitor = NWPathMonitor()
  private var latestPath: NWPath?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async { self?.latestPath = path }
    }
    monitor.start(queue: DispatchQueue(label: "vv.model-download.path"))
  }

  deinit {
    monitor.cancel()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = ModelDownloadPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    ModelDownloadSession.shared.eventSink = { [weak instance] event in
      instance?.channel.invokeMethod("bgEvent", arguments: event)
    }
    // Reconnect to downloads that continued while the app was not running.
    ModelDownloadSession.shared.activate()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let session = ModelDownloadSession.shared
    switch call.method {
    case "freeBytes":
      guard let path = args["path"] as? String else { return result(nil) }
      let values = try? URL(fileURLWithPath: path).resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      if let free = values?.volumeAvailableCapacityForImportantUsage {
        result(NSNumber(value: free))
      } else {
        result(nil)
      }
    case "networkStatus":
      let path = latestPath ?? monitor.currentPath
      let connected = path.status == .satisfied
      result([
        "connected": connected,
        "unmetered": connected && !path.isExpensive && !path.isConstrained,
        "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      ])
    case "excludeFromBackup":
      guard let path = args["path"] as? String else { return result(false) }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(true)
      } catch {
        result(false)
      }
    case "keepAliveStart":
      if backgroundTask == .invalid {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "vv.model-download") {
          [weak self] in self?.endBackgroundTask()
        }
      }
      result(nil)
    case "keepAliveUpdate":
      result(nil)
    case "keepAliveStop":
      endBackgroundTask()
      result(nil)
    case "bgStart":
      session.start(args)
      result(nil)
    case "bgPause":
      session.stop(key: args["key"] as? String ?? "", keepResumeData: true)
      result(nil)
    case "bgCancel":
      session.stop(key: args["key"] as? String ?? "", keepResumeData: false)
      result(nil)
    case "bgAck":
      session.acknowledge(key: args["key"] as? String ?? "")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // FlutterApplicationLifeCycleDelegate: the system relaunched the app for
  // events of our background session.
  func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == ModelDownloadSession.identifier else { return false }
    ModelDownloadSession.shared.backgroundCompletionHandler = completionHandler
    ModelDownloadSession.shared.activate()
    return true
  }

  private func endBackgroundTask() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }
}

/// The app's single background `URLSession` for model files.
///
/// Per download (`key` = model id) it persists where the bytes go
/// (`partialPath`, `offset`) and the allowed hosts; the finished temp file is
/// appended to the partial (206) or replaces it (200) before the delegate
/// returns. Outcomes are persisted until Dart acknowledges them (`bgAck`), so
/// a download that finished while the app was dead is reported on the next
/// `bgStart`.
final class ModelDownloadSession: NSObject, URLSessionDownloadDelegate {
  static let shared = ModelDownloadSession()
  static let identifier = "com.vaultvoice.vaultvoice.model-download"

  var eventSink: (([String: Any]) -> Void)?
  var backgroundCompletionHandler: (() -> Void)?

  private struct Info: Codable {
    var partialPath: String
    var offset: Int64
    var total: Int64
    var allowedHosts: [String]
  }

  private let defaults = UserDefaults.standard
  private let infoKey = "vv.modelDownload.tasks"
  private let resultKey = "vv.modelDownload.results"
  private let lock = NSLock()
  private var lastProgress: [String: Date] = [:]

  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: Self.identifier)
    config.sessionSendsLaunchEvents = true
    config.isDiscretionary = false
    // Anonymous requests: no cookies, cache or credentials (vv-model-delivery).
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    config.httpCookieAcceptPolicy = .never
    config.urlCache = nil
    config.urlCredentialStorage = nil
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  func activate() {
    _ = session
  }

  // MARK: Dart commands

  func start(_ args: [String: Any]) {
    guard let key = args["key"] as? String,
      let urlString = args["url"] as? String, let url = URL(string: urlString),
      url.scheme == "https",
      let partialPath = args["partialPath"] as? String,
      let offset = (args["offset"] as? NSNumber)?.int64Value,
      let total = (args["total"] as? NSNumber)?.int64Value,
      let headers = args["headers"] as? [String: String],
      let hosts = args["allowedHosts"] as? [String]
    else { return }
    let allowCellular = args["allowCellular"] as? Bool ?? false

    if let pending = result(for: key) {
      emit(pending)
      return
    }
    session.getAllTasks { tasks in
      if tasks.contains(where: { $0.taskDescription == key && $0.state == .running }) {
        return  // Still running from before: events keep flowing.
      }
      self.setInfo(
        Info(partialPath: partialPath, offset: offset, total: total, allowedHosts: hosts),
        for: key)
      let resumeURL = URL(fileURLWithPath: partialPath + ".resume")
      let task: URLSessionDownloadTask
      if let data = try? Data(contentsOf: resumeURL) {
        try? FileManager.default.removeItem(at: resumeURL)
        task = self.session.downloadTask(withResumeData: data)
      } else {
        var request = URLRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        // CFNetwork would otherwise send the device locale.
        request.setValue("*", forHTTPHeaderField: "Accept-Language")
        request.httpShouldHandleCookies = false
        request.allowsCellularAccess = allowCellular
        request.allowsExpensiveNetworkAccess = allowCellular
        task = self.session.downloadTask(with: request)
      }
      task.taskDescription = key
      task.resume()
    }
  }

  func stop(key: String, keepResumeData: Bool) {
    session.getAllTasks { tasks in
      let matching = tasks.compactMap { $0 as? URLSessionDownloadTask }
        .filter { $0.taskDescription == key }
      guard !matching.isEmpty else {
        self.finish(key: key, ["result": "stopped"])
        return
      }
      for task in matching {
        if keepResumeData, let info = self.info(for: key) {
          task.cancel(byProducingResumeData: { data in
            if let data = data {
              try? data.write(to: URL(fileURLWithPath: info.partialPath + ".resume"))
            }
            self.finish(key: key, ["result": "stopped"])
          })
        } else {
          if let info = self.info(for: key) {
            try? FileManager.default.removeItem(atPath: info.partialPath + ".resume")
          }
          task.cancel()
          self.finish(key: key, ["result": "stopped"])
        }
      }
    }
  }

  func acknowledge(key: String) {
    lock.lock()
    var results = defaults.dictionary(forKey: resultKey) ?? [:]
    results.removeValue(forKey: key)
    defaults.set(results, forKey: resultKey)
    lock.unlock()
  }

  // MARK: URLSessionDownloadDelegate

  // Authorises every redirect before the request is sent: a disallowed host
  // is never contacted (returning nil completes the task with the 3xx).
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    guard let key = task.taskDescription, let info = info(for: key) else {
      completionHandler(nil)
      return
    }
    let url = request.url
    guard let host = url?.host, url?.scheme == "https", info.allowedHosts.contains(host) else {
      completionHandler(nil)
      task.cancel()
      finish(key: key, ["result": "redirectDenied", "host": url?.host ?? ""])
      return
    }
    completionHandler(request)
  }

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    guard let key = downloadTask.taskDescription, let info = info(for: key) else { return }
    if let host = downloadTask.currentRequest?.url?.host, !info.allowedHosts.contains(host) {
      downloadTask.cancel()
      finish(key: key, ["result": "redirectDenied", "host": host])
      return
    }
    let now = Date()
    lock.lock()
    let last = lastProgress[key]
    let due = last == nil || now.timeIntervalSince(last!) > 0.5
    if due { lastProgress[key] = now }
    lock.unlock()
    if due {
      emit(["key": key, "event": "progress", "length": NSNumber(value: info.offset + totalBytesWritten)])
    }
  }

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let key = downloadTask.taskDescription, let info = info(for: key) else { return }
    let fm = FileManager.default
    let partial = URL(fileURLWithPath: info.partialPath)
    let host = downloadTask.currentRequest?.url?.host ?? ""
    guard info.allowedHosts.contains(host) else {
      finish(key: key, ["result": "redirectDenied", "host": host])
      return
    }
    let http = downloadTask.response as? HTTPURLResponse
    let status = http?.statusCode ?? 0
    let etag = http?.value(forHTTPHeaderField: "ETag")
    do {
      switch status {
      case 206:
        let range = http?.value(forHTTPHeaderField: "Content-Range") ?? ""
        guard range.hasPrefix("bytes \(info.offset)-") else {
          finish(key: key, ["result": "http", "status": NSNumber(value: status)])
          return
        }
        if !fm.fileExists(atPath: partial.path) {
          fm.createFile(atPath: partial.path, contents: nil)
        }
        let out = try FileHandle(forWritingTo: partial)
        defer { try? out.close() }
        try out.truncate(atOffset: UInt64(info.offset))
        try out.seekToEnd()
        let input = try FileHandle(forReadingFrom: location)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
          try out.write(contentsOf: chunk)
        }
      case 200:
        if fm.fileExists(atPath: partial.path) { try fm.removeItem(at: partial) }
        try fm.moveItem(at: location, to: partial)
      case 416:
        finish(key: key, ["result": "rangeNotSatisfiable"])
        return
      default:
        finish(key: key, ["result": "http", "status": NSNumber(value: status)])
        return
      }
      var event: [String: Any] = ["result": "completed"]
      if let etag = etag { event["etag"] = etag }
      finish(key: key, event)
    } catch {
      finish(key: key, ["result": "io"])
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let key = task.taskDescription, let error = error as NSError? else { return }
    if let data = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data,
      let info = info(for: key)
    {
      try? data.write(to: URL(fileURLWithPath: info.partialPath + ".resume"))
    }
    if error.code == NSURLErrorCancelled && result(for: key) != nil { return }
    finish(key: key, ["result": "network", "code": NSNumber(value: error.code)])
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
      self.backgroundCompletionHandler?()
      self.backgroundCompletionHandler = nil
    }
  }

  // MARK: Persistence

  private func info(for key: String) -> Info? {
    lock.lock()
    defer { lock.unlock() }
    guard let all = defaults.dictionary(forKey: infoKey), let data = all[key] as? Data else {
      return nil
    }
    return try? JSONDecoder().decode(Info.self, from: data)
  }

  private func setInfo(_ info: Info, for key: String) {
    lock.lock()
    defer { lock.unlock() }
    var all = defaults.dictionary(forKey: infoKey) ?? [:]
    all[key] = try? JSONEncoder().encode(info)
    defaults.set(all, forKey: infoKey)
  }

  private func result(for key: String) -> [String: Any]? {
    lock.lock()
    defer { lock.unlock() }
    return (defaults.dictionary(forKey: resultKey)?[key]) as? [String: Any]
  }

  /// Persists the outcome (until `bgAck`) and reports it to Dart.
  private func finish(key: String, _ outcome: [String: Any]) {
    var event = outcome
    event["key"] = key
    event["event"] = "done"
    lock.lock()
    var results = defaults.dictionary(forKey: resultKey) ?? [:]
    if results[key] == nil { results[key] = event }
    defaults.set(results, forKey: resultKey)
    lock.unlock()
    emit(event)
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { self.eventSink?(event) }
  }
}
