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

`ld.lld` 不在系统 `PATH` 中。Linux build 通过 Flutter tool snapshot 执行，并将 `/tmp/echo-llvm-bin` 放在 `PATH` 前部；该目录当时包含 Clang/LLVM 工具副本和指向系统 `ld` 的 shim。需在后续可复现构建工作中确认最小必需项，不能把临时环境准备写成系统依赖。

`gsettings` 的缩放读取在这个受限执行环境中产生 dconf 只读错误，因此没有把桌面缩放值记作已验证数据。直接运行 FVM 的 `flutter --version` 也尝试写入只读 Flutter cache 的 `engine.stamp`；Flutter 版本改由 cache metadata 读取。release build 使用已缓存的 Flutter tool snapshot，没有改系统配置。

## Release 产物

代码构建基线：`1cf593f6`（桌面工作区保持状态；后续仅有 spec 文档提交）。

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
