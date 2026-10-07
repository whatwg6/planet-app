import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});

  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  static const _backgroundColor = Color(0xFF141414);
  static const _textColor = Color(0xFFF5F5F5);
  static const _safeAreaChannel = MethodChannel('planet/webview_safe_area');
  static final _clientUrl = Uri.parse(
    'https://planet-h5.vercel.app/ops/client-next',
  );

  late final WebViewController _controller;
  late final double _safeAreaTop;
  bool _initializationStarted = false;
  bool _documentStartScriptInstalled = false;
  int _progress = 0;
  bool _hasError = false;
  String _errorMessage = '页面加载失败，请检查网络后重试';
  bool _handlingBack = false;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _progress = 0;
              _hasError = false;
              _errorMessage = '页面加载失败，请检查网络后重试';
            });
          },
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() => _hasError = true);
          },
          onHttpError: (error) async {
            final currentUrl = await _controller.currentUrl();
            if (!mounted || error.request?.uri.toString() != currentUrl) {
              return;
            }
            setState(() => _hasError = true);
          },
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializationStarted) return;
    _initializationStarted = true;

    // Capture logical pixels before registering the document-start script.
    _safeAreaTop = MediaQuery.viewPaddingOf(context).top;
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      await _configureWebView();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = error.code == 'DOCUMENT_START_UNSUPPORTED'
            ? '请更新 Android System WebView 后重试'
            : '页面初始化失败，请返回后重试';
      });
      debugPrint('WebView initialization failed: $error');
    }
  }

  Future<void> _configureWebView() async {
    final platformController = _controller.platform;
    if (platformController is WebKitWebViewController) {
      await platformController.setAllowsBackForwardNavigationGestures(true);
      // Observe native history, including same-document SPA navigation.
      await platformController.setOnCanGoBackChange((canGoBack) {
        if (!mounted || _canGoBack == canGoBack) return;
        setState(() => _canGoBack = canGoBack);
      });
      if (kDebugMode) {
        try {
          await platformController.setInspectable(true);
        } on PlatformException catch (error) {
          // Older Apple OS versions enable inspection by default.
          if (error.code != 'FWFUnsupportedVersionError') rethrow;
        }
      }
    }
    if (!mounted) return;
    if (!_documentStartScriptInstalled) {
      // Register before loadRequest: page scripts must see the native value
      // on their first execution, rather than after onPageFinished.
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final int webViewIdentifier;
      if (platformController is WebKitWebViewController) {
        webViewIdentifier = platformController.webViewIdentifier;
      } else if (platformController is AndroidWebViewController) {
        webViewIdentifier = platformController.webViewIdentifier;
      } else {
        throw PlatformException(code: 'DOCUMENT_START_UNSUPPORTED');
      }
      final script = (await rootBundle.loadString('assets/js/safe_area.js'))
          .replaceAll('__PLANET_SAFE_TOP__', _safeAreaTop.toString());
      await _safeAreaChannel.invokeMethod<void>('installDocumentStartScript', {
        'webViewIdentifier': webViewIdentifier,
        'source': script,
      });
      _documentStartScriptInstalled = true;
    }
    if (!mounted) return;
    await _controller.loadRequest(_clientUrl);
  }

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final canGoBack = await _controller.canGoBack();
      if (!mounted) return;
      if (canGoBack) {
        await _controller.goBack();
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      _handlingBack = false;
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _progress = 0;
    });
    if (_documentStartScriptInstalled) {
      _controller.loadRequest(_clientUrl);
    } else {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // Let WebKit handle swipes while it has history; otherwise exit the route.
      canPop: Theme.of(context).platform == TargetPlatform.iOS && !_canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: _backgroundColor,
          body: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _controller),
              if (_hasError)
                ColoredBox(
                  color: _backgroundColor,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: _textColor),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: _textColor),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('重试'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('返回首页'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_progress < 100)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(value: _progress / 100),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
