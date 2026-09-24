# Linux 单行顶栏与窗口边缘

## 修改

- Linux GTK runner 始终创建 client-side decoration；Flutter 首帧前隐藏 GTK HeaderBar，但不再调用 `setAsFrameless`。GTK decoration 负责窗口阴影和边缘缩放。
- 移除 `VirtualWindowFrame`。该组件把 Flutter 内容裁成 6px 圆角，在不透明黑色 Flutter view 上露出黑角，且其内部阴影无法延伸到原生窗口之外。GTK CSS 将窗口及 decoration 改为直角，并为非最大化窗口提供阴影。
- Linux 根级 Flutter 顶栏合并 Echo 标识、返回、前进、搜索及窗口操作。桌面主壳隐藏原侧栏品牌行和内容区工具栏；登录等非主界面只显示品牌与窗口操作。Windows 暂保留原布局，Android 不使用此顶栏。

## 构建与静态检查

- Flutter 3.41.7，Linux release bundle 编译通过；未启动应用或占用桌面会话。
- `pubspec.yaml`：`1.1.0+2059`。
- DEB：[echoes_1.1.0+2059_amd64.deb](../../../../../build/linux-lldtmp-2059/packages/echoes_1.1.0+2059_amd64.deb)，SHA-256 `7221b567f0d65232e2ca98317ef41730363396245e6a25044e73c32df22658bf`。
- 原始 bundle ZIP：[echoes_1.1.0+2059_linux-x64-bundle.zip](../../../../../build/linux-lldtmp-2059/packages/echoes_1.1.0+2059_linux-x64-bundle.zip)，SHA-256 `56adecfae3674efbe5a24a95531697fd72a020f9a5a6a5695f2f0c69546708ee`；`unzip -tq` 通过。
- `dpkg-deb --field` 确认 `echoes`、`1.1.0+2059`、`amd64` 与 GTK/Ayatana/libmpv 依赖；Dart formatter、`git diff --check` 通过。
- Flutter widget tests/analyze 未运行；本次没有构建或安装 Android APK。Linux 专用 GTK/window_manager 变更不会执行于 Android，共享 shell 的旧布局在没有 Linux 顶栏 scope 时保留。

## Ubuntu 手工验收待办

1. 普通窗口观察四边阴影与四角：应为直角、无黑块；最大化后阴影消失。
2. 在 Echo 标识和顶栏空白区拖动；在四边与角落缩放；检查最小化、最大化/还原、关闭及从托盘恢复。
3. 主界面只出现一行 Echo 标识、返回、前进、搜索、窗口按钮；登录页不显示无效的导航动作。
4. 搜索页、设置页和详情页的返回/前进按既有桌面历史工作；暗色主题、X11 和 Wayland 的窗口边缘另行观察。
