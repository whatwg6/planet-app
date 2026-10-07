import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ClientManagementPage extends StatefulWidget {
  const ClientManagementPage({super.key});

  @override
  State<ClientManagementPage> createState() => _ClientManagementPageState();
}

class _ClientManagementPageState extends State<ClientManagementPage> {
  static const _backgroundColor = Color(0xFF141414);
  static const _textColor = Color(0xFFF5F5F5);
  static final _clientUrl = Uri.parse(
    'https://planet-h5.vercel.app/ops/client-next',
  );

  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;
  bool _handlingBack = false;

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
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final platformController = _controller.platform;
    if (kDebugMode && platformController is WebKitWebViewController) {
      try {
        await platformController.setInspectable(true);
      } on PlatformException catch (error) {
        // Older Apple OS versions enable inspection by default.
        if (error.code != 'FWFUnsupportedVersionError') rethrow;
      }
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
    _controller.loadRequest(_clientUrl);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: Theme.of(context).platform == TargetPlatform.iOS,
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
                        const Text(
                          '页面加载失败，请检查网络后重试',
                          style: TextStyle(color: _textColor),
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
