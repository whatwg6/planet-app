# flutter_h5

## H5 安全区样式

客户管理 WebView 每次页面加载完成后，通过 JavaScript 向 HTML 的 `<head>`
注入以下样式，值来自 `MediaQuery.viewPadding.top`（例如 `59.0`）：

```html
<style id="planet-native-safe-area">
  :root { --safe-top: 59.0px; }
</style>
```

重复注入时更新已有样式；刷新、跳转到新页面和失败重试后都会重新注入。
H5 可以在整个页面中使用 `var(--safe-top)`。
此注入发生在页面加载完成后；如需首屏绘制前生效，H5 仍需接入下面的 URL 参数。

## H5 首屏安全区参数

客户管理页面在首次加载前读取 `MediaQuery.viewPadding.top`，通过 URL query
`safeAreaTop` 传给 H5，例如 `https://planet-h5.vercel.app/ops/client-next?safeAreaTop=59.0`。
失败重试沿用同一 URL。

参数单位为 Flutter 逻辑像素；H5 使用 `width=device-width, initial-scale=1` 时，
可直接作为 CSS px，`0` 也是有效值。
H5 必须在首屏绘制前使用该值替代 `env(safe-area-inset-top)`，不要叠加：
SSR 在服务端读取 query 并输出样式，客户端水合沿用同一值；
CSR 在应用挂载前同步初始化样式。参数缺失或无效时回退到 `env()`。
目标 H5 需要接入此参数，才能在加载完成后的样式注入之前预留安全区。

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
