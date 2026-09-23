# Linux 构建基线

日期：2026-09-23

范围：记录本机 Linux 构建工具链与最新 release 产物信息。此记录只证明环境信息和可编译/可打包，不证明应用已启动、安装、播放或通过 GNOME 交互验收。

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

`ld.lld` 不在系统 `PATH` 中。此前默认 release build 的 CMake cache 指向 `/tmp/echo-toolchain`；该缓存中的 Clang/LLVM wrapper 和 `ld.lld` shim 使之前的构建不能证明这些临时文件是否必需。后续已在新的 Flutter build-dir 中重新配置并完成完整 release 构建，确认系统 `/usr/bin/clang`、`/usr/bin/clang++`、`/usr/bin/llvm-ar-14` 和 GNU `/usr/bin/ld` 足够；新的 CMake build tree 没有引用 `/tmp/echo-toolchain` 或 `/tmp/echo-llvm-bin`。因此本机 Linux 编译不需要安装或伪装 `ld.lld`；CI 仍按 workflow 安装 LLVM 工具。

`gsettings` 的缩放读取在这个受限执行环境中产生 dconf 只读错误，因此没有把桌面缩放值记作已验证数据。直接运行 FVM 的 `flutter --version` 也尝试写入只读 Flutter cache 的 `engine.stamp`；Flutter 版本改由 cache metadata 读取。release build 使用已缓存的 Flutter tool snapshot，没有改系统配置。

## Release 产物

应用代码构建基线：`1cf593f6`（桌面工作区保持状态）；打包脚本更新：`c25e22aa`。

执行命令：

```bash
PATH=/tmp/echo-llvm-bin:$PATH \
FLUTTER_ROOT=/home/ericwyn/fvm/versions/3.41.7 \
/home/ericwyn/fvm/versions/3.41.7/bin/cache/dart-sdk/bin/dart \
/home/ericwyn/fvm/versions/3.41.7/bin/cache/flutter_tools.snapshot \
build linux --release --no-pub
bash scripts/package_linux_deb.sh
```

- Bundle ELF：x86-64, GNU/Linux, dynamically linked。
- Bundle: `build/linux/x64/release/bundle/echoes`。
- Debian package: `build/linux/packages/echoes_1.1.0+26_amd64.deb`。
- Package dependencies: `libgtk-3-0`, `libayatana-appindicator3-1`, `libmpv1`。
- Package includes the executable, `libapp.so`, desktop entry and 192×192 app icon.
- Bundle SHA-256: `ebfdbf494f65a50dfc97ba81286d933cbc818963a87529a0a905e76f974fdcac`。
- `.deb` SHA-256: `705722c43ff0d138670c1141a9b656e8c28eab16e6735374491745a79c68bddd`。

构建和 `.deb` 元数据检查成功。按用户要求，没有安装、启动应用或运行 Flutter tests/analyze。GNOME MPRIS seek、托盘宿主重启、退出恢复、工作区状态、不同窗口尺寸/DPI和干净系统安装仍需分别验证；其中桌面交互由用户手动执行。

## 全新构建目录（无临时 linker shim）

为避免复用旧 CMake cache，使用临时 Flutter 配置目录将构建输出放到独立的 `build/linux-noshim`。执行时没有将任何 `/tmp` LLVM shim 加入 `PATH`：

```bash
export FLUTTER_ROOT=/path/to/flutter
export HOME=/tmp/echo-flutter-clean-home
"$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" \
  "$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot" \
  config --build-dir=build/linux-noshim
"$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" \
  "$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot" \
  build linux --release --no-pub
ECHO_LINUX_BUNDLE_DIR="$PWD/build/linux-noshim/linux/x64/release/bundle" \
  bash scripts/package_linux_deb.sh build/linux-noshim/packages
```

- CMake 主工程：`/usr/bin/clang`、`/usr/bin/clang++`、`/usr/bin/ld`；mimalloc 子构建：`/usr/bin/cc`、`/usr/bin/c++`、`/usr/bin/ld`。扫描整个 build tree 未发现 `/tmp/echo-toolchain` 或 `/tmp/echo-llvm-bin` 引用。
- Fresh bundle: `build/linux-noshim/linux/x64/release/bundle/echoes`，ELF x86-64；executable SHA-256：`9d1d0fe4d9e5290c949f0cc758653ad4e1d506ec7e60edf80437bbdd5e7a04be`。
- Fresh `.deb`: `build/linux-noshim/packages/echoes_1.1.0+26_amd64.deb`；SHA-256：`f568c47d47841ad7d696391067a31ca6331c0dfd63fb269d4f0bb2755773c42d`。
- 包内 `libapp.so` SHA-256 与 fresh bundle 一致：`f8606e6132f4ee5603ea20004736753ace7e536c6c75318bdd61bdd57e02911f`。`dpkg-deb` 核对 amd64、GTK/AppIndicator/libmpv 依赖、可执行文件、桌面入口和 192×192 图标。
- `scripts/package_linux_deb.sh` 默认 bundle 行为不变；`ECHO_LINUX_BUNDLE_DIR` 支持将隔离构建目录直接打包，不覆盖默认 bundle。

这次只做 clean release build 和 package metadata/file checks，没有安装或启动应用，也没有运行 Flutter tests/analyze。
