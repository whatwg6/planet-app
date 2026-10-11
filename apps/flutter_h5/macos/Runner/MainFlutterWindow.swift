import Cocoa
import FlutterMacOS
import CFNetwork
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
    let proxyChannel = FlutterMethodChannel(
      name: "planet/network_proxy", binaryMessenger: flutterViewController.engine.binaryMessenger)
    proxyChannel.setMethodCallHandler { call, result in
      guard call.method == "getProxyForUrl" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let urlString = arguments["url"] as? String,
        let url = URL(string: urlString),
        let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue()
      else {
        result("DIRECT")
        return
      }
      let proxies = CFNetworkCopyProxiesForURL(url as CFURL, settings)
        .takeRetainedValue() as NSArray
      guard let proxy = proxies.firstObject as? [String: Any],
        let type = proxy[kCFProxyTypeKey as String] as? String
      else {
        result("DIRECT")
        return
      }
      if type == kCFProxyTypeNone as String {
        result("DIRECT")
      } else if type == kCFProxyTypeHTTP as String || type == kCFProxyTypeHTTPS as String,
        let host = proxy[kCFProxyHostNameKey as String] as? String,
        let port = proxy[kCFProxyPortNumberKey as String] as? NSNumber
      {
        let address = host.contains(":") ? "[\(host)]" : host
        result("PROXY \(address):\(port.intValue)")
      } else {
        result(FlutterError(
          code: "SYSTEM_PROXY_UNSUPPORTED",
          message: "Configure an HTTP proxy with CSR_HTTP_PROXY for PAC or SOCKS settings",
          details: nil))
      }
    }
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
