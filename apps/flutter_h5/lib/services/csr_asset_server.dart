import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serves the bundled Vite output with its original root paths and SPA routes.
class CsrAssetServer {
  CsrAssetServer({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _assetRoot = 'assets/dist/client';
  // Keep the origin stable across opens so localStorage retains login state.
  static const defaultPort = 18765;
  static const _apiHost = 'planet-h5.vercel.app';
  static const _proxyChannel = MethodChannel('planet/network_proxy');
  // An HTTP CONNECT proxy address, for example 127.0.0.1:7890.
  static const _proxyOverride = String.fromEnvironment('CSR_HTTP_PROXY');
  static const _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
  };
  final AssetBundle _bundle;
  HttpServer? _server;
  HttpClient? _apiClient;
  late Set<String> _assets;
  late List<int> _index;

  Future<Uri> start({int port = defaultPort}) async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    _assets = manifest
        .listAssets()
        .where((key) => key.startsWith('$_assetRoot/'))
        .toSet();
    var html = await _bundle.loadString('$_assetRoot/index.html');
    final bootstrap = await _bundle.loadString('assets/js/csr_bootstrap.js');
    // Telemetry must not add a remote, parser-blocking dependency to local CSR.
    html = html.replaceFirst('<head>', '<head><script>$bootstrap</script>');
    html = html.replaceAllMapped(
      RegExp(r'<script src="https://js\.sentry-cdn\.com/'),
      (match) => '<script async src="https://js.sentry-cdn.com/',
    );
    _index = utf8.encode(html);
    final proxy = await _resolveApiProxy();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    final client = HttpClient();
    // Forward compressed response bytes and their encoding unchanged.
    client.autoUncompress = false;
    client.findProxy = (_) => proxy;
    client.connectionTimeout = const Duration(seconds: 15);
    _apiClient = client;
    _logProxy('network route=$proxy');
    server.listen((request) => unawaited(_serve(request)));
    return Uri.parse('http://127.0.0.1:${server.port}/ops/client-next');
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      final path = request.uri.path;
      if (_isApiPath(path)) {
        await _proxyApi(request);
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        return;
      }
      final key = '$_assetRoot$path';
      final isPage =
          path == '/' ||
          path == '/index.html' ||
          path == '/ops/client-next' ||
          path.startsWith('/ops/client-next/') ||
          path == '/login/callback' ||
          path == '/not-found' ||
          path == '/_dev' ||
          path.startsWith('/_dev/');
      final List<int> bytes;
      if (isPage) {
        bytes = _index;
        response.headers.contentType = ContentType.html;
      } else if (_assets.contains(key)) {
        final data = await _bundle.load(key);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        response.headers.contentType = _contentType(path);
      } else {
        // Missing resources must never receive the HTML fallback.
        response.statusCode = HttpStatus.notFound;
        return;
      }
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      response.contentLength = bytes.length;
      if (request.method == 'GET') response.add(bytes);
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  static bool _isApiPath(String path) =>
      path == '/api' || path.startsWith('/api/');

  Future<String> _resolveApiProxy() async {
    if (_proxyOverride.isNotEmpty) {
      final proxy = Uri.parse(
        _proxyOverride.contains('://')
            ? _proxyOverride
            : 'http://$_proxyOverride',
      );
      if (proxy.scheme != 'http' ||
          proxy.host.isEmpty ||
          !proxy.hasPort ||
          proxy.port <= 0 ||
          proxy.port > 65535 ||
          proxy.userInfo.isNotEmpty ||
          (proxy.path.isNotEmpty && proxy.path != '/') ||
          proxy.hasQuery ||
          proxy.hasFragment) {
        throw ArgumentError('CSR_HTTP_PROXY must be an HTTP proxy host:port');
      }
      final host = proxy.host.contains(':') ? '[${proxy.host}]' : proxy.host;
      return 'PROXY $host:${proxy.port}';
    }
    final url = Uri.https(_apiHost, '/api');
    final environmentProxy = HttpClient.findProxyFromEnvironment(url);
    if (environmentProxy != 'DIRECT') return environmentProxy;
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        return await _proxyChannel.invokeMethod<String>('getProxyForUrl', {
              'url': url.toString(),
            }) ??
            'DIRECT';
      } on MissingPluginException {
        _logProxy('system proxy bridge unavailable; fully rebuild the app');
      } on PlatformException catch (error) {
        _logProxy(
          'system proxy lookup failed (${error.code}); '
          'use --dart-define=CSR_HTTP_PROXY=host:port if a proxy is required',
        );
      }
    }
    return 'DIRECT';
  }

  Future<void> _proxyApi(HttpRequest request) async {
    final response = request.response;
    HttpClientRequest? outgoing;
    var responseStarted = false;
    var stage = 'connect';
    try {
      // Always use the fixed upstream host, preserving the encoded path/query.
      final upstream = request.uri.replace(
        scheme: 'https',
        host: _apiHost,
        port: 443,
        userInfo: '',
        fragment: '',
      );
      _logProxy('${request.method} ${request.uri.path} -> $_apiHost');
      outgoing = await _apiClient!
          .openUrl(request.method, upstream)
          .timeout(const Duration(seconds: 30));
      stage = 'request_headers';
      outgoing.followRedirects = false;
      _copyHeaders(
        request.headers,
        outgoing.headers,
        excluded: {'host', 'origin', 'referer'},
      );
      stage = 'request_body';
      await outgoing.addStream(request);
      stage = 'upstream_response';
      final incoming = await outgoing.close().timeout(
        const Duration(seconds: 30),
      );
      _logProxy('upstream status=${incoming.statusCode} ${request.uri.path}');
      stage = 'response_headers';
      response.statusCode = incoming.statusCode;
      _copyHeaders(incoming.headers, response.headers);

      // Keep redirects within /api on the local origin as well.
      final location = incoming.headers.value(HttpHeaders.locationHeader);
      if (location != null) {
        final redirect = upstream.resolve(location);
        if (redirect.scheme == 'https' &&
            redirect.host == _apiHost &&
            redirect.port == 443 &&
            _isApiPath(redirect.path)) {
          response.headers.set(
            HttpHeaders.locationHeader,
            redirect.toString().substring(
              redirect.scheme.length + 3 + redirect.authority.length,
            ),
          );
        }
      }
      responseStarted = true;
      stage = 'response_body';
      await response.addStream(incoming);
    } catch (error) {
      _logProxy(
        'failed stage=$stage ${request.method} ${request.uri.path} '
        '${error.runtimeType}: ${_errorDescription(error)}',
      );
      outgoing?.abort();
      if (responseStarted) return;
      response.headers.clear();
      response.statusCode = error is TimeoutException
          ? HttpStatus.gatewayTimeout
          : HttpStatus.badGateway;
      response.headers.contentType = ContentType.json;
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      response.write(
        jsonEncode({
          'message': '接口代理失败，请检查网络后重试',
          'code': 'CSR_PROXY_ERROR',
          'stage': stage,
          'errorType': error.runtimeType.toString(),
        }),
      );
    }
  }

  static void _logProxy(String message) {
    if (kDebugMode) debugPrint('[CSR proxy] $message');
  }

  // Omit query strings, bodies and credentials from diagnostic logs.
  static String _errorDescription(Object error) {
    if (error is SocketException) {
      return '${error.message}; ${error.osError ?? ''}';
    }
    if (error is TlsException) {
      return '${error.message}; ${error.osError ?? ''}';
    }
    if (error is HttpException) return error.message;
    if (error is TimeoutException) return error.message ?? 'upstream timeout';
    return 'proxy forwarding failed';
  }

  static void _copyHeaders(
    HttpHeaders source,
    HttpHeaders destination, {
    Set<String> excluded = const {},
  }) {
    final skipped = {
      ..._hopByHopHeaders,
      ...excluded,
      // Connection can name additional headers that apply only to one hop.
      for (final value in source[HttpHeaders.connectionHeader] ?? <String>[])
        ...value.split(',').map((name) => name.trim().toLowerCase()),
    };
    source.forEach((name, values) {
      if (!skipped.contains(name.toLowerCase())) {
        destination.set(name, values);
      }
    });
  }

  static ContentType _contentType(String path) {
    if (path.endsWith('.js')) {
      return ContentType('application', 'javascript', charset: 'utf-8');
    }
    if (path.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
    return ContentType.binary;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    _apiClient?.close(force: true);
    _apiClient = null;
    await server?.close(force: true);
  }
}
