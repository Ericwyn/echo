# Linux 构建基线

日期：2026-09-23

范围：记录 Ubuntu 本机 release bundle 与 Debian 包构建。构建/包检查不代表已安装、启动、播放或通过 GNOME 交互验收；按用户要求，这里没有启动应用或运行 Flutter tests/analyze。

## 环境

| 项目 | 结果 | 来源 |
| --- | --- | --- |
| 操作系统 | Ubuntu 22.04.5 LTS (Jammy) | `/etc/os-release` |
| 会话 | GNOME，X11 (`XDG_CURRENT_DESKTOP=ubuntu:GNOME`, `XDG_SESSION_TYPE=x11`) | 当前进程环境 |
| 架构 | x86_64 | Linux release executable |
| Flutter | 3.41.7 stable，framework revision `cc0734ac716fbb8b90f3f9db8020958b1553afa7` | FVM 缓存的 `flutter.version.json` |
| Dart | 3.11.5 stable | FVM bundled Dart SDK |
| Clang | Ubuntu clang 14.0.0-1ubuntu1.1 | `clang --version` |
| GTK | 3.24.33 | `pkg-config --modversion gtk+-3.0` |
| D-Bus | 1.12.20 | `pkg-config --modversion dbus-1` |
| libmpv | 0.34.1-1ubuntu3 | dpkg package metadata |
| Ayatana AppIndicator | 0.5.90-7ubuntu2 | dpkg package metadata |

系统 `/usr/lib/llvm-14/bin` 缺少 `ld.lld` 和 `ld`。在标准系统 PATH 下重新做完整 Flutter Linux 构建时，`dart_build` 因找不到这两个 linker 而失败；先前 `build/linux-noshim` 的包仍是旧 `1.1.0+26`，不能作为当前版本构建证据。没有修改系统软件包。

## 当前 release bundle 与 `.deb`

应用代码与版本基线：`82edffab`；Debian 打包脚本：`c25e22aa`。`pubspec.yaml` 版本为 `1.1.0+2037`。桌面队列行增加序号，在可用宽度不少于 560 逻辑像素时显示专辑元信息；队列标题栏可手动定位当前曲目。PlaybackQueueContent 对已渲染行记录索引与队列 revision，定位采样避免逐 key 扫描整份队列，滚动后清理离屏锚点以限制 GlobalKey 保留量。SongListPage 在滚动更新封面预加载窗口时复用歌曲数据签名，避免重复遍历整个列表；队列拖动期间发生版本/随机模式变化时取消并提示。曲库列表与不同排序模式的滚动状态已分别使用 PageStorageKey。Explore 搜索草稿/查询和结果滚动可恢复；MPRIS `Seeked` 由成功 seek 显式触发，音乐流展开状态同样纳入路由恢复。

为了完成全新 Linux 构建，从 Ubuntu 22.04 官方仓库下载 `lld-14`，只解压至 `/tmp/echo-lld-root`，没有安装到系统。`/tmp/echo-toolchain/clang` 与 `clang++` 是调用系统 Clang 的临时 wrapper；同目录的 `ld.lld` 指向解压出的真实 Ubuntu LLD 二进制，不是伪造 linker shim。使用隔离 Flutter 配置和全新的 CMake build-dir `build/linux-lldtmp`：

```bash
export HOME=/tmp/echo-flutter-clean-home
export FLUTTER_ROOT=/home/ericwyn/fvm/versions/3.41.7
export PATH=/tmp/echo-toolchain:/usr/lib/llvm-14/bin:/usr/bin:$PATH
flutter config --build-dir=build/linux-lldtmp-2037
flutter build linux --release --no-pub
ECHO_LINUX_BUNDLE_DIR="$PWD/build/linux-lldtmp-2037/linux/x64/release/bundle" \
  scripts/package_linux_deb.sh build/linux-lldtmp-2037/packages
```

- CMake compiler entries point to the temporary wrappers; they delegate to `/usr/bin/clang` and `/usr/bin/clang++`. Linker is the actual Ubuntu LLD 14 binary extracted under `/tmp`.
- Bundle: `build/linux-lldtmp-2037/linux/x64/release/bundle/echoes`; ELF x86-64; SHA-256 `af48c6ae345b197197afc6fa58f6050bc9f5904064912f33cfc78046f274ff95`.
- `libapp.so` SHA-256: `c637c4e9d4e81958ed64019580dbc1a0b0663a671f5740548f8d8f071ade413d`.
- Flutter asset version: `1.1.0`, build number `2037`.
- Debian package: `build/linux-lldtmp-2037/packages/echoes_1.1.0+2037_amd64.deb`; Architecture `amd64`; SHA-256 `2015a7e82345f197638e74ce298dd19c458df9d18f2f3c9fbc9c96c067d687e3`.
- Package dependencies: `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`.
- `dpkg-deb` checks confirmed package metadata, bundle executable, desktop entry and 192×192 icon. `libmpv` remains a runtime-loaded dependency and is declared explicitly.

The current artifact compiles and packages successfully when a real LLD 14 binary is available. A clean machine using this system LLVM installation still needs the matching linker package; Windows CI remains outside this Linux build result. The `.deb` was not installed and the app was not launched; GNOME controls, tray recovery, clean installation and playback remain for the user's manual validation.
