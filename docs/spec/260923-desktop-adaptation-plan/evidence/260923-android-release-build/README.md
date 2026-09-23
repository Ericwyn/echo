# Android ARM64 release APK build

日期：2026-09-23

范围：确认桌面适配后的共享 Flutter 工程仍可生成一个可供 arm64 Android 设备安装的正式 APK。此记录只证明构建与签名，不证明安装、启动或 Android 功能行为。

## 构建

- Flutter：3.41.7；JDK：17；Android SDK/compile SDK：36。
- `pubspec.yaml` 版本：`1.1.0+2030`。
- 命令：`flutter build apk --release --no-pub --split-per-abi --target-platform android-arm64`。
- 使用本机 release keystore（alias `echo-release`）。签名密码从本机密码文件读入构建进程环境；密码、keystore 内容及可复用密钥材料未写入仓库、命令输出或本记录。
- 产物：`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`，29,740,925 bytes。
- APK SHA-256：`f5d419ef2e8516f70d030651b8200ea1736ae5f5beb379c76649944755b4d79b`。

## APK 校验

- Package：`com.az1n.echoes`；version name：`1.1.0`；APK version code：`4030`。
- 本次构建实测 `1.1.0+2030` 对应 arm64 APK version code `4030`；高于此前交付的 `4029` 候选和用户设备上报告的 `2026`。
- min SDK：24；target SDK：36。
- APK 中仅有 `arm64-v8a` native libraries。
- `apksigner verify`：通过，1 个 signer，APK Signature Scheme v2。
- Signer certificate：`CN=Echoes Personal`，RSA 3072；SHA-256：`8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`。

本机快捷脚本 `scripts/local/build_android_release_arm64.sh` 仅用于该开发机，从本机签名配置构建并校验 arm64-only APK；该脚本保持 Git 未跟踪状态，不包含在提交中。此前 `1.1.0+26` 通用 APK 与 `1.1.0+2027/2028/2029` arm64 候选均已由当前 `1.1.0+2030` 取代。

## 未完成验收

APK 未安装或启动，Flutter tests/analyze 未运行。Android 真机播放、通知栏/锁屏控制、歌词/队列、动态背景偏好和数据恢复仍待用户验证。

本机签名目录的说明指出该个人 keystore 不一定与原版 release 使用同一证书；若设备已有原版 app，系统可能拒绝将此 APK 作为更新。卸载现有 app 会清除其本地数据，安装前应确认更新签名或先备份数据。
