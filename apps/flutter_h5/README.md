# flutter_h5

## H5 安全区参数

客户管理页面在首次加载前读取 `MediaQuery.viewPadding.top`，通过 URL query
`safeAreaTop` 传给 H5，例如 `https://planet-h5.vercel.app/ops/client-next?safeAreaTop=59.0`。
失败重试沿用同一 URL。

参数单位为 Flutter 逻辑像素；H5 使用 `width=device-width, initial-scale=1` 时，
可直接作为 CSS px，`0` 也是有效值。
H5 必须在首屏绘制前使用该值替代 `env(safe-area-inset-top)`，不要叠加：
SSR 在服务端读取 query 并输出样式，客户端水合沿用同一值；
CSR 在应用挂载前同步初始化样式。参数缺失或无效时回退到 `env()`。
目标 H5 需要接入此参数，仅传递 query 不会自动改变 padding。

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
