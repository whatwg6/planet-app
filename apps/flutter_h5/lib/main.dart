import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'pages/client_management_page.dart';

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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _backgroundColor = Color(0xFF141414);
  static const _textColor = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClientManagementPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
