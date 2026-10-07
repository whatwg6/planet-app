# flutter_h5

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
