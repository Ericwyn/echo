# Linux 窗口闪屏复测 — 2026-09-24

## 现象与复测

- 用户此前在 Ubuntu X11 上观察到：缩放窗口和最小化后恢复时，旧窗口画面可能短暂重影。窗口截图同时含有 `gdk_device_get_source: assertion 'GDK_IS_DEVICE (device)' failed`，但该日志与重影之间的因果关系尚未确认。
- 用户分别手测 Flutter 3.41.7 和 3.47.5 构建的 2061 Linux bundle：两者都会闪屏，3.47.5 略轻。
- 项目升级并固定 Flutter 3.47.5 后，2062 Linux bundle 增加 `ECHO_DISABLE_IMPELLER=1` 诊断开关。用户复测反馈：默认启动和关闭 Impeller 启动都未再观察到闪屏，效果差不多。

## 可验证的构建差异

- 2061 的 3.47.5 bundle 与 2062 bundle 的 `libflutter_linux_gtk.so` SHA-256 相同：`d57449a5c2ee39e77b9e3488f0703b165c67e0b3c554089f388db96484ae62f1`。
- 2062 默认启动不会触发新增的关闭 Impeller 分支。因此本轮复测不能证明 Flutter 升级、渲染器切换或诊断代码单独修复了闪屏。
- 2062 源码提交：`636b44a6`（FVM / SDK 版本）与 `83bc3620`（可选渲染器诊断）。Linux bundle、DEB 和 ZIP 已构建；Codex 没有启动 GUI，运行验证均由用户完成。

## 当前结论

当前 2062 包未复现闪屏；根因尚未确定。保留 `ECHO_DISABLE_IMPELLER=1` 仅供再次复现时在同一 bundle 上做对照。若以后重现，记录首次发生时的窗口操作、是否存在旧 Echoes 进程、停止操作后重影是否自行消失，以及默认和关闭 Impeller 两种模式的差异。
