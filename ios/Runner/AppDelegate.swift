import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // 新版模板走 UIScene 生命周期，此时 window 还不存在，必须通过插件注册表拿 messenger
    if let registrar = self.registrar(forPlugin: "SenditClipboard") {
      let channel = FlutterMethodChannel(name: "sendit/clipboard", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "readAll": result(ClipboardReader.readAll())
        default: result(FlutterMethodNotImplemented)
        }
      }
      NSLog("SENDIT clipboard channel registered")
    } else {
      NSLog("SENDIT clipboard channel NOT registered: registrar nil")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 每个条目按"纯文本 → RTF → HTML"的优先级取文本；不把未知二进制硬解成字符串。
/// 备忘录等应用会同时放网页存档，若按"最长优先"会取到带标签的 HTML。
enum ClipboardReader {
  static let plainTypes = ["public.utf8-plain-text", "public.plain-text", "public.text", "public.utf16-plain-text", "public.utf16-external-plain-text"]

  static func plain(_ value: Any) -> String? {
    if let s = value as? String { return s }
    if let d = value as? Data { return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .utf16) }
    return nil
  }

  static func rich(_ value: Any, type: String) -> String? {
    if let attr = value as? NSAttributedString { return attr.string }
    guard let data = value as? Data else { return nil }
    if type.lowercased().contains("rtf") {
      return (try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil))?.string
    }
    if type.lowercased().contains("html") {
      return (try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil))?.string
    }
    return nil
  }

  static func textOf(item: [String: Any]) -> String? {
    for t in plainTypes {
      if let v = item[t], let s = plain(v), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
    }
    for (t, v) in item where t.lowercased().contains("rtf") {
      if let s = rich(v, type: t), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
    }
    for (t, v) in item where t.lowercased().contains("html") {
      if let s = rich(v, type: t), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
    }
    return nil
  }

  static func readAll() -> String {
    let pb = UIPasteboard.general
    var parts: [String] = pb.items.compactMap { textOf(item: $0) }
    if let strings = pb.strings, strings.count > parts.count { parts = strings }
    if parts.isEmpty, let s = pb.string { parts = [s] }
    return parts.map { $0.trimmingCharacters(in: .newlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
  }
}
