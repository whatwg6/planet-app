# flutter_h5

首页的“客户管理 next”通过 WebView 加载
`https://planet-h5.yxc-next.cn/ops/client-next`，复用现有安全区、返回及错误重试逻辑。

## 客户管理 csr

首页的“客户管理 csr”加载随 App 打包的 `assets/dist/client`，入口为
`http://127.0.0.1:18765/ops/client-next`。打开页面时启动仅监听本机的 HTTP
服务，返回首页时关闭；固定端口让再次打开后的 localStorage 保持同一 origin。
原有“客户管理”继续打开线上页面。

本地服务保留产物的 `/js/`、`/css/`、`/svg/` 资源路径，并为客户列表、
详情页及其他已知前端路由返回 `index.html`，支持 history 路由刷新。
缺失资源返回 404，不回退成 HTML。两个入口共用文档起始
安全区脚本、WebView 返回和错误重试逻辑。

前端需使用同源的相对 API 地址，例如 `/api/ssr/client-list`，不要再使用
完整线上域名。本地 `/api` 和 `/api/...` 请求由 Dart 转发到
`https://planet-h5.vercel.app/api` 和对应子路径，例如：

```text
/api/ssr/client-list?page=1
→ https://planet-h5.vercel.app/api/ssr/client-list?page=1
```

代理保留 HTTP 方法、查询参数、请求体、Authorization 等业务请求头，
并透传上游状态码、响应头和响应体；Host 由上游地址生成，Origin、Referer
及逐跳头不转发。同一上游 `/api` 的重定向改成相对地址，继续走本地代理。
连接失败返回 502，等待上游响应超时返回 504。H5 的 API 请求与本地页面同源，
无需后端添加 CORS 配置。本地 origin 的 Cookie/localStorage 与线上入口独立，
登录态不会自动从线上页面继承。

Debug 模式在 Flutter 控制台输出 `[CSR proxy]` 请求路径、上游状态码及
失败阶段/具体网络异常，不记录查询参数、请求体或鉴权头。代理自身失败时，
JSON 返回 `code: CSR_PROXY_ERROR`、`stage` 和 `errorType`，可与上游返回的
502 区分。Flutter 网络面板中的线上 URL 是 Dart 发出的上游请求；H5 的
同源请求地址仍为 `http://127.0.0.1:18765/api/...`。

API 转发优先使用 `--dart-define=CSR_HTTP_PROXY=host:port` 指定的 HTTP
CONNECT 代理，其次读取进程的 HTTP(S) 代理环境变量；iOS/macOS 还会
读取系统针对上游 URL 的 HTTP(S) 代理设置。Debug 控制台的
`[CSR proxy] network route=...` 显示选用的代理，`DIRECT` 表示直连。
PAC/SOCKS 设置不由 Dart 客户端执行，可手动指定代理工具的 HTTP/混合端口：

```sh
flutter run --dart-define=CSR_HTTP_PROXY=127.0.0.1:7890
```

这里的 `7890` 仅为示例，需使用实际端口。iOS 模拟器可以使用 Mac 上的
本机 HTTP 代理；真机需使用设备能访问的代理地址。更改系统代理后重新进入
CSR 页面以刷新配置。新增的原生代理桥接需要完整重新编译运行。

产物同步依赖远程 Sentry SDK。本地服务在返回 HTML 时将 SDK 脚本改为异步，
并提前注入 `assets/js/csr_bootstrap.js`，避免 SDK 下载失败或离线时阻止
前端执行；SDK 可用时由真实实现接管。原始 dist 文件不做修改。

替换前端产物时覆盖 `assets/dist/client`；新增资源子目录需补充
`pubspec.yaml` 的 assets 声明。修改产物或平台配置后完整重新编译运行，
不能只做热重载。

## H5 安全区样式

客户管理 WebView 在 `loadRequest` 前注册文档起始脚本，每次加载新文档时，
在 H5 页面脚本执行前设置 `:root` 的 `--safe-top`，并向 `<head>` 注入以下样式。
值来自 `MediaQuery.viewPadding.top`（例如 `59.0`）：

```html
<style id="planet-native-safe-area">
  :root { --safe-top: 59.0px; }
</style>
```

重复注入时更新已有样式；刷新、跳转到新页面和失败重试后都会重新注入。
H5 可以在整个页面中使用 `var(--safe-top)`。
脚本先设置根元素的内联变量，确保 `<head>` 尚未创建时也能读取实际值；
再通过 `MutationObserver` 等待 `<head>` 并加入样式，不等待页面加载完成。
WebView 正常显示加载过程。

iOS/macOS 使用 `WKUserScript.atDocumentStart`，Android 使用
`WebViewCompat.addDocumentStartJavaScript`。不支持文档起始脚本的旧 Android
System WebView 会提示更新，不回退到会导致首屏跳动的加载完成后注入。
修改原生桥接代码后需要完整重新编译运行，不能仅热重载。

单位为 Flutter 逻辑像素；H5 使用 `width=device-width, initial-scale=1` 时，
可直接作为 CSS px，`0` 也是有效值。页面直接使用 `var(--safe-top)`，
无需接入 URL 参数、SSR 或客户端初始化逻辑。

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
