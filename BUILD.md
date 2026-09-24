# 构建 Echoes

以下命令均在仓库根目录执行。本指南覆盖 Android APK 与 Ubuntu/Linux x64；Windows、iOS 等平台不在此处的构建范围内。当前 CI 使用 Flutter **3.41.7**，`pubspec.yaml` 要求 Dart `^3.10.8`。

## 准备环境

1. 安装 Flutter 3.41.7，并确认 `flutter`、`dart` 在 `PATH` 中。运行 `flutter doctor -v` 检查工具链。
2. Android 构建需要 Android SDK、Build Tools、已接受的 SDK licenses，以及 JDK 17。首次配置可运行 `flutter doctor --android-licenses`。Linux 构建需要 C/C++、GTK 与打包工具；Ubuntu 22.04 可安装与 CI 相同的依赖：

   ```bash
   sudo apt-get update
   sudo apt-get install -y clang lld llvm cmake ninja-build pkg-config \
     libgtk-3-dev liblzma-dev libayatana-appindicator3-dev \
     desktop-file-utils zip
   ```

3. 拉取 Dart/Flutter 依赖：

   ```bash
   flutter pub get
   ```

仓库已包含生成的 Dart 文件。修改 Freezed、JSON、Drift 或 Riverpod 的生成器输入后，再运行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 版本号与 Android 签名

`pubspec.yaml` 中的 `version: 1.1.0+2061` 是当前示例：`1.1.0` 是 Android `versionName`，`2061` 是基础 `versionCode`，Linux 打包脚本使用完整的 `1.1.0+2061` 作为 DEB 版本。发布新版本前递增构建号；安装更新时，新 APK 的**实际** `versionCode` 必须大于设备上已有的包。

发布签名可放在被 Git 忽略的 `android/key.properties` 中：

```properties
storeFile=/absolute/path/to/release-keystore.jks
storePassword=<store-password>
keyAlias=<key-alias>
keyPassword=<key-password>
```

也可以改用 `ECHO_STORE_FILE`、`ECHO_STORE_PASSWORD`、`ECHO_KEY_ALIAS`、`ECHO_KEY_PASSWORD` 环境变量。`storeFile` 建议填写绝对路径；不要提交密钥、密码或 `key.properties`。当前 [`android/app/build.gradle.kts`](android/app/build.gradle.kts) 在没有完整发布签名配置时**会用调试密钥签署 release 构建**：这种 APK 不能直接覆盖用正式密钥安装的版本。分发前使用 Android SDK Build Tools 的 `apksigner verify --print-certs <APK 路径>` 核对证书。

### `versionCode` 与 ABI

Flutter 的 `--split-per-abi` 会为不同 ABI 的 APK 添加版本码偏移；当前 Flutter 的 ARM64 拆分包在基础构建号上加 **2000**。例如基础构建号 `2061` 对应的 ARM64 拆分 APK 实际版本码是 `4061`；不拆分的通用 APK 则使用基础构建号。**从拆分包切换到通用包**时，通用包需要选用高于已安装拆分包的构建号，否则 Android 会拒绝降级。可通过 `aapt dump badging <APK 路径>` 检查实际 `versionCode`，必要时在构建命令中使用 `--build-number=<更大的整数>`；之后仍应将 `pubspec.yaml` 的构建号同步提高，避免下一次构建倒退。

本机若保留了 Git 忽略的 `scripts/local/build_android_release_arm64.sh`，也可以用它生成并校验发布签名的 ARM64 单包。该脚本是这台机器的私有辅助工具，不属于仓库；它在 `build/` 之外记录上次 ARM64 版本码，清理 `build/` 后仍会递增。其他机器按下面的通用命令构建即可。

## Android APK

下面三种构建方式任选其一。命令里的 `--no-pub` 以已执行 `flutter pub get` 为前提；如果依赖刚改过，请先重新执行 `flutter pub get`。

| 目标 | 命令 | 产物 |
| --- | --- | --- |
| 按 ABI 拆分，生成 32 位 ARM、64 位 ARM、x86-64 三个 APK | `flutter build apk --release --no-pub --split-per-abi` | `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`、`app-arm64-v8a-release.apk`、`app-x86_64-release.apk` |
| 只生成 Android ARM64 APK | `flutter build apk --release --no-pub --split-per-abi --target-platform android-arm64` | `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |
| 生成一个包含所有目标 Android ABI 的通用 APK | `flutter build apk --release --no-pub` | `build/app/outputs/flutter-apk/app-release.apk` |

通用 APK 只是把**多个 Android CPU 架构**装进一个文件，不包含 Linux 桌面版；文件体积通常比单个 ABI 包大。独立分发时可选择通用包以减少用户选错架构的情况；已知设备都是 ARM64 时，单独的 ARM64 包更小。

构建后至少核对版本码、ABI 与签名。`aapt`、`apksigner` 随 Android SDK Build Tools 安装；如果命令不在 `PATH` 中，请使用该 Build Tools 目录下的绝对路径。

```bash
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
unzip -Z1 build/app/outputs/flutter-apk/app-release.apk | awk -F/ '/^lib\/[^/]+\// {print $2}' | sort -u
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

构建拆分包时将上面路径换成对应的 `app-arm64-v8a-release.apk` 等文件。APK 的包名应为 `com.az1n.echoes`；在已有正式版的设备上安装前，还需确认签名证书一致。

## Linux x64：bundle、DEB 与 ZIP

在 Ubuntu/Linux x64 主机上执行：

```bash
flutter build linux --release --no-pub
bash scripts/package_linux_deb.sh
```

产物位置：

| 类型 | 路径 | 用途 |
| --- | --- | --- |
| 原始 Flutter bundle | `build/linux/x64/release/bundle/` | 可执行文件 `echoes` 与必需的 `lib/`、`data/`；拷贝时必须保留整个目录 |
| Debian 安装包 | `build/linux/packages/echoes_<pubspec 版本>_amd64.deb` | 安装到 `/opt/echoes`，带应用菜单项和图标 |
| 便携 ZIP | `build/linux/packages/echoes_<pubspec 版本>_linux-x64-bundle.zip` | 包含完整原始 bundle |

打包脚本检查 Flutter 引擎、插件、manifest 和资源是否齐全。DEB 声明运行依赖 `libgtk-3-0`、`libayatana-appindicator3-1` 和 `libmpv1`。当前验证基线是 Ubuntu 22.04 x64；Ubuntu 24.04 / Wayland 等环境仍需实际安装和播放验证。

若通过 `flutter config --build-dir=<其他目录>` 改过 Flutter 构建目录，可用 `ECHO_LINUX_BUNDLE_DIR=/绝对路径/到/bundle bash scripts/package_linux_deb.sh <输出目录>` 指定 bundle 和包输出目录。

## 清理与常见问题

- `flutter clean` 会删除 Flutter 生成内容；之后重新运行 `flutter pub get` 再构建。仅清理旧产物时可以删除 `build/`，但它会同时删除此前的 Android APK 和 Linux 包。需要同时保留两端产物时，不要在两次构建之间清理。
- Linux 打包提示缺少文件时，先确认执行了 **release** 构建，且 `ECHO_LINUX_BUNDLE_DIR` 指向完整 bundle，不要只复制 `echoes` 可执行文件。
- Android APK 无法覆盖安装时，分别核对包名、签名证书以及实际 `versionCode`；尤其注意拆分包的 ABI 版本码偏移。

参考：[Flutter Android 发布文档](https://docs.flutter.dev/deployment/android)、[Flutter Linux 构建文档](https://docs.flutter.dev/platform-integration/linux/building)。
