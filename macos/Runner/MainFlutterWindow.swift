import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(name: "sendit/clipboard", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "readAll" {
        let items = NSPasteboard.general.pasteboardItems ?? []
        var parts: [String] = []
        for item in items {
          if let s = item.string(forType: .string) {
            parts.append(s)
          } else if let rtf = item.data(forType: .rtf),
                    let attr = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            parts.append(attr.string)
          }
        }
        if parts.isEmpty, let s = NSPasteboard.general.string(forType: .string) { parts = [s] }
        result(parts.map { $0.trimmingCharacters(in: .newlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n"))
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
