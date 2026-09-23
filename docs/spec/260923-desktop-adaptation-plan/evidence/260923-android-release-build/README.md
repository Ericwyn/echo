# Android release APK build

日期：2026-09-23

范围：确认桌面适配后的共享 Flutter 工程仍可构建正式 Android APK，并交给用户在设备上做回归。此记录只证明构建与签名，不证明安装、启动或 Android 功能行为。

## 构建

- Checkout：`79310b27`（应用代码基线 `1cf593f6`）。
- Flutter：3.41.7；JDK：17；Android SDK/compile SDK：36。
- 命令：`flutter build apk --release --no-pub`。
- 使用本机 release keystore（alias `echo-release`）。签名密码从本机密码文件读入构建进程环境；密码、keystore 内容及可复用密钥材料未写入仓库、命令输出或本记录。
- 产物：`build/app/outputs/flutter-apk/app-release.apk`，75,134,279 bytes。
- APK SHA-256：`e43b04214fcd12e6e2a82cd20ac6a41bfc78a1294e867ad73e0808170ba8a4ee`。

## APK 校验

- Package：`com.az1n.echoes`；version name/code：`1.1.0` / `26`。
- min SDK：24；target SDK：36。
- ABI：`arm64-v8a`、`armeabi-v7a`、`x86_64`。
- `apksigner verify`：通过，1 个 signer，APK Signature Scheme v2。
- Signer certificate：`CN=Echoes Personal`，RSA 3072；SHA-256：`8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`。
- 构建输出有 SDK XML v4 版本提示，但 Gradle release 构建成功。

## 未完成验收

APK 未安装或启动，Flutter tests/analyze 未运行。Android 真机播放、通知栏/锁屏控制、歌词/队列、动态背景偏好和数据恢复仍待用户验证。

本机签名目录的说明指出该个人 keystore 不一定与原版 release 使用同一证书；若设备已有原版 app，系统可能拒绝将此 APK 作为更新。卸载现有 app 会清除其本地数据，安装前应确认更新签名或先备份数据。
