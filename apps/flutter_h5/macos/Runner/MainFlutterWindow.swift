import Cocoa
import FlutterMacOS
import WebKit
import webview_flutter_wkwebview

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "planet/webview_safe_area", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak flutterViewController] call, result in
      guard call.method == "installDocumentStartScript" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let registry = flutterViewController,
        let arguments = call.arguments as? [String: Any],
        let identifier = arguments["webViewIdentifier"] as? NSNumber,
        let source = arguments["source"] as? String,
        let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
          forIdentifier: identifier.int64Value, withPluginRegistry: registry)
      else {
        result(FlutterError(code: "WEBVIEW_NOT_FOUND", message: "WebView not found", details: nil))
        return
      }
      webView.configuration.userContentController.addUserScript(
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true))
      result(nil)
    }

    super.awakeFromNib()
  }
}
