import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../client_urls.dart';

/// Mount below an opaque foreground widget so the native view is actually
/// created and loads resources without appearing on screen.
class ClientNextPreload extends StatefulWidget {
  const ClientNextPreload({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<ClientNextPreload> createState() => ClientNextPreloadState();
}

class ClientNextPreloadState extends State<ClientNextPreload> {
  WebViewController? _controller;
  late final Future<void> _initialization;
  Future<void>? _cancellation;
  Timer? _timeout;
  Timer? _settleTimer;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 20), () {
      _finish('超时');
    });
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = WebViewController(
        onPermissionRequest: (request) {
          unawaited(request.deny().catchError((Object _) {}));
        },
      );
      _controller = controller;
      // Use the same default persistent cache as the foreground WebView.
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (_cancelled) return;
      await controller.setOnJavaScriptAlertDialog((_) async {});
      if (_cancelled) return;
      await controller.setOnJavaScriptConfirmDialog((_) async => false);
      if (_cancelled) return;
      await controller.setOnJavaScriptTextInputDialog((_) async => '');
      if (_cancelled) return;
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final scheme = Uri.tryParse(request.url)?.scheme;
            return !_cancelled && (scheme == 'https' || scheme == 'http')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (url) {
            if (_cancelled || Uri.tryParse(url)?.scheme == 'about') return;
            // Give immediately scheduled imports a short chance to warm cache.
            _settleTimer?.cancel();
            _settleTimer = Timer(const Duration(seconds: 1), () {
              _finish('完成');
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) _finish('主文档加载失败');
          },
          onHttpError: (error) async {
            if (_cancelled) return;
            try {
              final currentUrl = await controller.currentUrl();
              if (!_cancelled && error.request?.uri.toString() == currentUrl) {
                _finish('主文档 HTTP 错误');
              }
            } catch (error) {
              debugPrint('[H5 preload] HTTP 错误检查失败: $error');
            }
          },
        ),
      );
      if (_cancelled || !mounted) return;
      // Wait until the WebViewWidget has been laid out, including on Android.
      await WidgetsBinding.instance.endOfFrame;
      if (_cancelled || !mounted) return;
      debugPrint('[H5 preload] 开始 $clientNextUrl');
      await controller.loadRequest(Uri.parse(clientNextUrl));
    } catch (error) {
      debugPrint('[H5 preload] 初始化失败: $error');
      _finish('失败');
    }
  }

  void _finish(String reason) {
    if (_cancelled) return;
    debugPrint('[H5 preload] $reason');
    // Initialization can fail synchronously before its Future is assigned.
    scheduleMicrotask(() => unawaited(_finishAndRemove()));
  }

  Future<void> _finishAndRemove() async {
    await cancel();
    if (mounted) widget.onFinished();
  }

  /// Mark cancelled immediately so pending initialization cannot start loading
  /// after cleanup. Callers clearing cache await this before clearing it.
  Future<void> cancel() {
    if (_cancellation != null) return _cancellation!;
    _cancelled = true;
    debugPrint('[H5 preload] 取消并释放');
    _timeout?.cancel();
    _settleTimer?.cancel();
    return _cancellation = _stopAndRelease();
  }

  Future<void> _stopAndRelease() async {
    await _initialization.timeout(const Duration(seconds: 2), onTimeout: () {});
    final controller = _controller;
    if (controller == null) return;

    // webview_flutter exposes neither stopLoading nor controller.dispose.
    // Replace the document to stop network work and page scripts, detach the
    // callbacks, then release references so plugin finalizers can reclaim it.
    for (final operation in <Future<void> Function()>[
      () => controller.setJavaScriptMode(JavaScriptMode.disabled),
      () => controller.setNavigationDelegate(NavigationDelegate()),
      () => controller.loadRequest(Uri.parse('about:blank')),
    ]) {
      try {
        await operation().timeout(const Duration(seconds: 1));
      } catch (error) {
        debugPrint('[H5 preload] 清理失败: $error');
      }
    }
    _controller = null;
  }

  @override
  void dispose() {
    unawaited(cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: ExcludeFocus(
        child: IgnorePointer(child: WebViewWidget(controller: controller)),
      ),
    );
  }
}
