package com.example.flutter_h5

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(PlanetSafeAreaPlugin())
    }
}

private class PlanetSafeAreaPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "planet/webview_safe_area").also {
            it.setMethodCallHandler { call, result ->
                if (call.method != "installDocumentStartScript") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val identifier = call.argument<Number>("webViewIdentifier")?.toLong()
                val source = call.argument<String>("source")
                val webView = identifier?.let {
                    WebViewFlutterAndroidExternalApi.getWebView(binding, it)
                }
                if (webView == null || source == null) {
                    result.error("WEBVIEW_NOT_FOUND", "WebView not found", null)
                } else if (!WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                    result.error("DOCUMENT_START_UNSUPPORTED", "Update Android System WebView", null)
                } else {
                    WebViewCompat.addDocumentStartJavaScript(webView, source, setOf("*"))
                    result.success(null)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
