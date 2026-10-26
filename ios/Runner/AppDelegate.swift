import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 文件选择器要等用户操作，结果回来之前先把代理和 Dart 侧回调存着
  private var pendingPicker: PickerDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LangobeiNative") {
      let messenger = registrar.messenger()
      registerExportChannel(messenger)
      registerBankChannel(messenger)
    }
  }

  // MARK: - langobei/export

  /// 对应 Android 侧的「写下载目录 / 拉起分享面板」。
  /// iOS 没有公共「下载」目录，改成把文件交给系统保存面板，用户自己选存到「文件」App 的哪里。
  private func registerExportChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "langobei/export", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      let args = call.arguments as? [String: Any]
      switch call.method {
      case "saveToDownloads":
        let name = args?["filename"] as? String ?? "langobei-export.json"
        let content = args?["content"] as? String ?? ""
        self?.exportFile(name: name, content: content, result: result)
      case "shareText":
        let subject = args?["subject"] as? String ?? "LangoBei 学习数据"
        let text = args?["text"] as? String ?? ""
        self?.shareText(subject: subject, text: text, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func exportFile(name: String, content: String, result: @escaping FlutterResult) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let url = dir.appendingPathComponent(name)
      try content.write(to: url, atomically: true, encoding: .utf8)
      DispatchQueue.main.async {
        guard let host = self.topViewController() else {
          result(FlutterError(code: "save_failed", message: "当前没有可以弹出保存面板的界面", details: nil))
          return
        }
        let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        host.present(picker, animated: true)
        result("「文件」App（\(name)）")
      }
    } catch {
      result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func shareText(subject: String, text: String, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let host = self.topViewController() else {
        result(FlutterError(code: "share_failed", message: "当前没有可以弹出分享面板的界面", details: nil))
        return
      }
      let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      controller.setValue(subject, forKey: "subject")
      // iPad 上必须给 popover 一个锚点，否则直接崩
      if let popover = controller.popoverPresentationController {
        popover.sourceView = host.view
        popover.sourceRect = CGRect(
          x: host.view.bounds.midX,
          y: host.view.bounds.midY,
          width: 0,
          height: 0
        )
      }
      host.present(controller, animated: true)
      result(nil)
    }
  }

  // MARK: - langobei/bank

  /// 词库文件放在 Application Support/banks/ 下：不需要任何权限，卸载即清除。
  private func registerBankChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "langobei/bank", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any]
      do {
        switch call.method {
        case "listBanks":
          result(try self.listBankIds())
        case "readBank":
          result(try self.readBank(args?["id"] as? String ?? ""))
        case "writeBank":
          try self.writeBank(args?["id"] as? String ?? "", args?["content"] as? String ?? "")
          result(nil)
        case "deleteBank":
          try self.deleteBank(args?["id"] as? String ?? "")
          result(nil)
        case "readIndex":
          result(try self.readIndex())
        case "writeIndex":
          try self.writeIndex(args?["content"] as? String ?? "")
          result(nil)
        case "pickBankFile":
          self.pickBankFile(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "bank_io", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func bankDir() throws -> URL {
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let dir = base.appendingPathComponent("banks", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    return dir
  }

  private func bankFile(_ id: String) throws -> URL? {
    let mapped = id.map { ch -> Character in
      if ch.isASCII && (ch.isLetter || ch.isNumber || ch == "-" || ch == "_") {
        return ch
      }
      return "_"
    }
    let safe = String(String(mapped).prefix(64))
    guard !safe.isEmpty else { return nil }
    return try bankDir().appendingPathComponent("\(safe).json")
  }

  private func listBankIds() throws -> [String] {
    let files = try FileManager.default.contentsOfDirectory(
      at: try bankDir(),
      includingPropertiesForKeys: nil
    )
    return files
      .filter { $0.pathExtension == "json" && $0.lastPathComponent != "_index.json" }
      .map { $0.deletingPathExtension().lastPathComponent }
      .sorted()
  }

  private func readBank(_ id: String) throws -> String? {
    guard let url = try bankFile(id), FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }
    return try String(contentsOf: url, encoding: .utf8)
  }

  private func writeBank(_ id: String, _ content: String) throws {
    guard let url = try bankFile(id) else {
      throw NSError(domain: "langobei", code: 1, userInfo: [NSLocalizedDescriptionKey: "词库 id 不合法"])
    }
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  private func deleteBank(_ id: String) throws {
    guard let url = try bankFile(id), FileManager.default.fileExists(atPath: url.path) else {
      return
    }
    try FileManager.default.removeItem(at: url)
  }

  private func readIndex() throws -> String? {
    let url = try bankDir().appendingPathComponent("_index.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try String(contentsOf: url, encoding: .utf8)
  }

  private func writeIndex(_ content: String) throws {
    let url = try bankDir().appendingPathComponent("_index.json")
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  /// 拉起系统「文件」选择器挑一个词库；取消返回 null。
  /// asCopy: true 会把选中的文件复制到 App 沙盒，省掉 security-scoped 授权的麻烦。
  private func pickBankFile(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.pendingPicker == nil else {
        result(FlutterError(code: "busy", message: "已经有一个文件选择在进行中", details: nil))
        return
      }
      guard let host = self.topViewController() else {
        result(FlutterError(code: "no_picker", message: "当前没有可以弹出选择器的界面", details: nil))
        return
      }
      let picker = UIDocumentPickerViewController(
        forOpeningContentTypes: [.json, .plainText, .data],
        asCopy: true
      )
      let delegate = PickerDelegate { [weak self] picked in
        self?.pendingPicker = nil
        guard let picked else {
          result(nil)
          return
        }
        do {
          let text = try String(contentsOf: picked, encoding: .utf8)
          result(["name": picked.lastPathComponent, "content": text])
        } catch {
          result(FlutterError(code: "read_failed", message: "读不了这个文件", details: nil))
        }
      }
      self.pendingPicker = delegate
      picker.delegate = delegate
      host.present(picker, animated: true)
    }
  }

  // MARK: - 工具

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

/// 「文件」选择器的回调只准来一次，取消和选中不能都触发。
private final class PickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let completion: (URL?) -> Void
  private var finished = false

  init(_ completion: @escaping (URL?) -> Void) {
    self.completion = completion
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard !finished else { return }
    finished = true
    completion(urls.first)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard !finished else { return }
    finished = true
    completion(nil)
  }
}
