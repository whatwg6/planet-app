import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'client_urls.dart';
import 'pages/client_management_page.dart';
import 'widgets/client_next_preload.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registerWebViewPlatform();
  runApp(const MyApp());
}

void _registerWebViewPlatform() {
  if (kIsWeb || WebViewPlatform.instance != null) return;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      AndroidWebViewPlatform.registerWith();
      break;
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      WebKitWebViewPlatform.registerWith();
      break;
    default:
      break;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _backgroundColor = Color(0xFF141414);
  static const _textColor = Color(0xFFF5F5F5);
  static const _entryCardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide(color: Color(0xFF666666)),
  );

  WebViewController? _cacheController;
  bool _clearingCache = false;
  final _preloadKey = GlobalKey<ClientNextPreloadState>();
  Timer? _preloadDelay;
  bool _showPreload = false;
  bool _openingClientNext = false;

  @override
  void initState() {
    super.initState();
    // Only schedule once for this app launch, after the home screen settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _clearingCache || _openingClientNext) return;
      if (kIsWeb || WebViewPlatform.instance == null) return;
      if (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS) {
        return;
      }
      _preloadDelay = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showPreload = true);
      });
    });
  }

  Future<void> _cancelClientNextPreload() async {
    _preloadDelay?.cancel();
    await _preloadKey.currentState?.cancel();
    if (mounted && _showPreload) setState(() => _showPreload = false);
  }

  Future<void> _openClientNext() async {
    if (_openingClientNext || _clearingCache) return;
    setState(() => _openingClientNext = true);
    final loadStopwatch = Stopwatch()..start();
    try {
      // An unresponsive background platform call must not block opening the page.
      await _cancelClientNextPreload().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          if (mounted) setState(() => _showPreload = false);
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClientManagementPage(
            loadStopwatch: loadStopwatch,
            url: clientNextUrl,
            entryName: '客户管理 next',
          ),
        ),
      );
    } finally {
      loadStopwatch.stop();
      if (mounted) setState(() => _openingClientNext = false);
    }
  }

  @override
  void dispose() {
    _preloadDelay?.cancel();
    unawaited(_preloadKey.currentState?.cancel());
    super.dispose();
  }

  Future<void> _clearWebViewCache() async {
    if (_clearingCache || _openingClientNext) return;
    setState(() => _clearingCache = true);

    var message = 'WebView 静态资源缓存已清理';
    try {
      // Stop preloading first so it cannot write resources back after clearing.
      await _cancelClientNextPreload();
      // All entry points share the default WebView cache. Do not clear
      // cookies or localStorage, which may contain login information.
      final controller = _cacheController ??= WebViewController();
      await controller.clearCache();
    } catch (error) {
      debugPrint('WebView cache clearing failed: $error');
      message = '缓存清理失败，请重试';
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final home = Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('首页'),
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: _backgroundColor,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '工作台',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: _textColor),
            ),
            const SizedBox(height: 8),
            Text(
              '选择功能，开始工作',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: _textColor),
            ),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              color: _backgroundColor,
              shape: _entryCardShape,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Icon(
                  Icons.people_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                title: const Text('客户管理', style: TextStyle(color: _textColor)),
                subtitle: const Text(
                  '查看与管理客户信息',
                  style: TextStyle(color: _textColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: _textColor),
                onTap: () {
                  final loadStopwatch = Stopwatch()..start();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ClientManagementPage(loadStopwatch: loadStopwatch),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: _backgroundColor,
              shape: _entryCardShape,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Icon(
                  Icons.people_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                title: const Text(
                  '客户管理 csr',
                  style: TextStyle(color: _textColor),
                ),
                subtitle: const Text(
                  '查看与管理客户信息',
                  style: TextStyle(color: _textColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: _textColor),
                onTap: () {
                  final loadStopwatch = Stopwatch()..start();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClientManagementPage.csr(
                        loadStopwatch: loadStopwatch,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: _backgroundColor,
              shape: _entryCardShape,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Icon(
                  Icons.people_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                title: const Text(
                  '客户管理 yxc.next',
                  style: TextStyle(color: _textColor),
                ),
                subtitle: const Text(
                  '查看与管理客户信息',
                  style: TextStyle(color: _textColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: _textColor),
                onTap: _clearingCache || _openingClientNext
                    ? null
                    : _openClientNext,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _clearingCache || _openingClientNext
                  ? null
                  : _clearWebViewCache,
              style: OutlinedButton.styleFrom(
                foregroundColor: _textColor,
                disabledForegroundColor: _textColor.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _clearingCache
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _textColor,
                      ),
                    )
                  : const Icon(Icons.cleaning_services_outlined),
              label: Text(_clearingCache ? '正在清理缓存…' : '清理 WebView 缓存'),
            ),
          ],
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_showPreload)
          ClientNextPreload(
            key: _preloadKey,
            onFinished: () {
              if (mounted) setState(() => _showPreload = false);
            },
          ),
        // Keep this opaque home above the real platform view to prevent flashes.
        home,
      ],
    );
  }
}
