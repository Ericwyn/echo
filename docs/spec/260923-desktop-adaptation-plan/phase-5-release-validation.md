# P5：打包与跨端验收

[返回 spec](README.md) · [验收矩阵](acceptance.md) · [决策](decisions.md)

状态：应用代码 `a9cb6989` 已在全新 `build/linux-lldtmp-2032` CMake 目录中构建，使用系统 Clang 与从 Ubuntu 包解压到 `/tmp` 的真实 LLD 14；`c25e22aa` 支持从该 bundle 生成 Ubuntu `.deb`。当前 checkout 另已构建并签名 Android arm64-only release APK，校验证书与 package metadata；Linux `.deb` 和 Android APK 均未安装或启动。前置：P0–P4 仍有完整系统操作、恢复和安装场景待验证。当前优先 Ubuntu/Linux；Windows CI 暂缓，不能据此宣称 Windows 发布支持。

## 目标与交付范围

Ubuntu 交付可安装 `.deb` 与完整 bundle 压缩包；Windows 交付 release bundle 和在 P0 确认方案下的安装包。安装包包含桌面身份、图标和明确的运行依赖，文档说明支持范围和关闭/退出行为。

首轮验收基线是 Ubuntu 22.04/GNOME/X11，扩展到 Ubuntu 24.04 与 Wayland。Ubuntu 22.04 系统 libmpv 0.34.1 由本地 `media_kit` 兼容补丁覆盖：关闭 MPV 临时磁盘缓存并跳过音频场景不用的 `subs-fallback`；封面缓存仍由共享 artwork cache 管理。未经测试的环境列为未验证，不扩大支持声明。Flatpak/Snap、自动更新服务和开机启动不列首版范围。

## 实施步骤

1. 使用 Ubuntu 22.04 构建环境和 Flutter 3.41.7；PR Linux job 固定 runner 并运行 Linux release build。当前不增加 Windows CI job。
2. 固定 pub 依赖锁文件和 native 依赖，补齐 clang/lld、GTK、CMake、Ninja 与选定托盘实现要求。构建过程不依赖开发者机器绝对路径、手工 symlink 或旧缓存。
3. Linux bundle 检查 `echoes`、`lib/`、`data/` 和插件资源完整；不能只分发可执行文件。扫描直接动态依赖，同时确认运行时动态加载的 libmpv 与编解码依赖。`scripts/package_linux_deb.sh` 默认读取 Flutter 标准 bundle；设置 `ECHO_LINUX_BUNDLE_DIR` 可直接打包非默认 build-dir 的 bundle。
4. `.deb` 与 bundle 仍需明确系统 libmpv 运行依赖；本地 smoke test 已在 Ubuntu 22.04/libmpv 0.34.1 上通过，但还需在干净环境验证包依赖、实际播放和 ABI。
5. 添加 `.desktop`、图标、分类、应用名称和身份；安装后从应用列表、Dock 和命令行启动指向同一应用，重复启动能恢复窗口。按实际设计申明 D-Bus 激活能力，不能只加 DesktopEntry 字段就当激活实现完成。当前 `scripts/package_linux_deb.sh` 将完整 bundle 安装到 `/opt/echoes`，安装 `.desktop` 与 hicolor 图标；明确 `DBusActivatable=false`，因为首版没有桌面文件 D-Bus 激活服务。
6. Windows 包与 SMTC 验证暂缓，不纳入当前 Linux 交付门槛。
7. 在没有 Flutter/开发 SDK、没有预装开发版 libmpv 的干净目标环境安装并真实播放：登录、浏览、直连/转码、seek、系统控制、托盘和退出。依赖由安装流程满足，禁止先在测试机手工补齐再宣称开箱可用。
8. 验证升级保留音乐库配置、用户音量和队列恢复信息；普通卸载的用户数据策略明确，不静默清理用户下载。不要为本次布局变化修改数据库或会话格式，确需变更时单独记录迁移测试。
9. 运行矩阵要求的尺寸/DPI、输入方式、长队列和生命周期场景，记录 commit、环境、步骤、结果和截图/日志。共享播放器变化执行相关 Android 自动测试与真机后台回归。
10. 完成仓库规定的静态分析、测试和生成文件检查；仅在生成器输入变化时更新产物。Linux/Windows 构建使用最终锁定提交，不能拿 earlier commit 的截图或实验包作为验收证据。
11. 更新 README 的下载、运行依赖、平台限制及新桌面截图；保留 Android 现有说明，避免把桌面关闭策略写成手机行为。

## 当前 Linux 打包实现记录

- `packaging/linux/echoes.desktop` 使用 `echoes` desktop-file basename，与 Linux MPRIS 的 `DesktopEntry=echoes` 对齐；图标安装到 hicolor `192x192/apps`。
- `scripts/package_linux_deb.sh` 从 `build/linux/x64/release/bundle` 组装 Debian 包，依赖声明面向当前 Ubuntu 22.04 基线：`libgtk-3-0`、`libayatana-appindicator3-1`、`libmpv1`。MPV 是运行时动态加载项，不会出现在主 ELF 的 `DT_NEEDED` 中，因此显式声明。
- `.github/workflows/build_linux.yml` 在 release bundle 外再上传 `.deb`；`.github/workflows/pr_checks.yml` 加入包组装步骤。Windows workflow 未改。
- 历史包 `build/linux/packages/echoes_1.1.0+26_amd64.deb` 与 `1.1.0+2027/2028/2029/2030/2031` 候选均已被替换。当前最新包为 `build/linux-lldtmp-2032/packages/echoes_1.1.0+2032_amd64.deb`，SHA-256 为 `c76747666544603d0acc6e1bab4f67a7bf630d57344bd11f505a601a4a544713`；`dpkg-deb` 检查通过，仍未安装验证。干净系统播放依赖仍待 CI/Ubuntu 实机记录。

### 原生分发与网络通路的补充检查

- Windows x64 安装包中的播放器库、SMTC 插件及其他 native DLL 架构一致；若后续交付 ARM64，提供其独立构建/运行证据。引入 Rust 时同步记录 Cargo 锁文件、bridge/codegen 配套版本与 target。
- 离线播放时，系统封面从已缓存本地文件加载；中文/空格目录、缺失封面、切歌时缓存更新都有正确回退，不要求系统自行读取鉴权地址。
- 对 API、封面、下载、实际音频直连与本地缓存代理分别验证网络行为；至少记录直连、配置代理和鉴权失败样本。一个通路成功不等于其他通路也继承相同代理/请求策略。
- 系统媒体面板、任务栏/Dock、托盘及 Windows 音量混合器应以 Echoes 身份呈现；缺失/能力差异按平台记录。

这些检查来自 [外部实践与本项目对照](research-stream-music.md)，用于发现实际兼容问题，不把网络栈迁移或新增 Rust 工程作为发布前置要求。

## 性能验证方式

- 用 release/profile 采样，记录机器、显示刷新率、数据量和运行模式。
- 操作样本固定为 1654/5000 首队列连续滚动、远距离定位、歌词/队列切换、窗口连续缩放；分别记录帧耗时、内存与隐藏窗口 CPU。
- 先采旧版同机基线，再设定和记录具体预算；以帧预算 `1000 / 实测刷新率` 毫秒观察卡顿，不能把固定 16.7ms 套给所有屏幕。
- 关键结构要求先通过：列表懒构建、没有每帧全队列重建、隐藏歌词动画停止、进度同步不持续高频跨进程广播。
- 若出现超预算，定位后修改并重跑受影响样本；不因“整体观感不错”跳过已发现的卡顿。

## 发布条件

| 发布层级 | 必需通过 |
| --- | --- |
| M1 内部试用 | P1/P2 + 基础 Linux 媒体会话；标明过渡播放器及尚未开放的隐藏行为 |
| M2 Ubuntu 候选版 | A01–A11、A13–A15 在指定 Ubuntu/Android 范围通过；Windows 状态如实列出 |
| M3 双桌面正式范围 | M2 + A12，以及 A14/A15 的 Windows 安装与性能证据 |

Ubuntu 24.04/Wayland 若仍未验收，只能先发布明确限定 22.04/X11 的候选范围。影响播放可靠性、退出/恢复、数据或 Android 后台行为的失败阻止对应范围发布；纯可选功能可列入已知限制，但不能把必需能力改名为可选来绕过验收。

## 产出与实施记录

- 安装包/bundle 的版本、目标平台、构建提交和校验摘要。
- `evidence/<日期>-<平台>-release-validation/` 中的实际结果及精简截图/日志。
- 更新 [验收矩阵](acceptance.md)、[决策](decisions.md) 中最终依赖与支持范围，以及用户可读运行说明。

| 平台 | 构建提交 / 产物 | 验收 / 遗留 |
| --- | --- | --- |
| Ubuntu 22.04 X11 | `f6100044` / 2026-09-23 本地 release bundle | 编译成功；本机 libmpv 0.34.1 HTTP 音频 smoke test 无 MPV 选项/cache-dir 错误；用户先前确认 MPRIS 封面/基本控制和托盘。干净安装、绝对 seek、关闭恢复与最终最新 bundle 人工复测未完成 |
| Ubuntu 22.04 X11 | `7f4ae955` / 2026-09-23 release bundle（最终窗口栏修正前） | 构建和 437 项 Flutter 测试曾通过；此后为修复顶栏点击/闪烁和重置置顶状态所做的变更没有重跑构建/测试。用户接手最终启动和窗口操作验收 |
| Ubuntu 22.04 X11 | `0f06bc0d` / 2026-09-23 release bundle 与 `.deb` | Linux release build 与包组装成功；包元数据依赖为 GTK、Ayatana AppIndicator、libmpv。未启动、未安装、未运行测试；由用户检查主导航、侧栏共享模型及添加库后的返回历史 |
| Ubuntu 22.04 X11 | `805cd9e4` / 2026-09-23 release bundle 与 `.deb` | 包含共享导航模型及 5000 首队列定位校正；Linux release build 与包组装成功。未启动、未安装、未运行 Flutter 测试；用户手动检查导航返回、长队列定位和常用交互 |
| Ubuntu 22.04 X11 | `d7f6b359` / 2026-09-23 release bundle 与 `.deb` | 包含 MPRIS remote-command error isolation 与 SetPosition/Seeked coverage；Linux release build 与包组装成功。未启动、未安装、未运行 Flutter 测试；用户手动复测 GNOME media controls 和 seek |
| Ubuntu 22.04 X11 | `c5d2b512` / 2026-09-23 release bundle 与 `.deb` | 另包含 AudioService 兜底音量修正；Linux release build 与包组装成功。未启动、未安装、未运行 Flutter 测试；用户手动复测播放/系统音量及媒体控制 |
| Ubuntu 22.04 X11 | `4046eb32` / 2026-09-23 release bundle 与 `.deb` | 包含侧栏/桌面壳调整、桌面队列右键菜单与封面动态背景开关；release build 和 `.deb` 组装成功；核对 x64 ELF、desktop entry、图标和 `libgtk-3-0`/`libayatana-appindicator3-1`/`libmpv1` 依赖。未启动、未安装、未运行 Flutter 测试，等用户手动验收 |
| Ubuntu 22.04 X11 | `5df8140e` / 2026-09-23 release bundle 与 `.deb` | 另包含逐项限时的桌面退出清理；Linux release build 和包组装成功。未启动、未安装、未运行 Flutter 测试；关窗、显式退出与恢复仍由用户实测 |
| Ubuntu 22.04 X11 | `c2496e94` / 2026-09-23 release bundle 与 `.deb` | 另包含退出前播放会话快照保存和防覆盖；release build 与 `.deb` 组装成功，核对 x64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；退出位置恢复由用户实测 |
| Ubuntu 22.04 X11 | `21cf973f` / 2026-09-23 release bundle 与 `.deb` | 另包含 StatusNotifier watcher 状态合并、初始查询竞态处理及宿主出现后图标/菜单刷新；release build 与 `.deb` 组装成功，核对 amd64、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；宿主重启恢复由用户实测 |
| Ubuntu 22.04 X11 | `27913d3f` / 2026-09-23 release bundle 与 `.deb` | 另包含桌面前进重建详情页时复用 PageStorageBucket 恢复可滚动内容位置；release build 与 `.deb` 组装成功，核对 amd64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；滚动恢复由用户实测 |
| Ubuntu 22.04 X11 | `859745a6` / 2026-09-23 release bundle 与 `.deb` | 另包含前进恢复 SearchPage 的查询/草稿状态；release build 与 `.deb` 组装成功，核对 amd64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；查询恢复由用户实测 |
| Ubuntu 22.04 X11 | `eaa77d13` / 2026-09-23 release bundle 与 `.deb` | 另包含 album/playlist detail 排序选择的 route-local 状态恢复，并将搜索状态保存改为输入时写入；release build 与 `.deb` 组装成功，核对 amd64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；详情筛选恢复由用户实测 |
| Ubuntu 22.04 X11 | `52463122` / 2026-09-23 release bundle 与 `.deb` | 另包含收藏夹 tab 与 artist detail 当前内容区的路由状态恢复；release build 与 `.deb` 组装成功，核对 amd64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；收藏/歌手页面恢复由用户实测 |
| Ubuntu 22.04 X11 | `1cf593f6` / 2026-09-23 release bundle 与 `.deb` | 另包含歌词/队列面板和整个播放工作区在切换/收起后保留状态；release build 与 `.deb` 组装成功，核对 amd64 ELF、desktop entry、图标和运行依赖。未启动、未安装、未运行 Flutter 测试；工作区恢复由用户实测 |
| Ubuntu 22.04 X11 | `1cf593f6` app + `c25e22aa` package script / `build/linux-noshim`（旧包） | 此旧目录对应 `1.1.0+26`，不能代表当前版本。标准系统 LLVM 缺 linker 的问题在之后的完整重建中确认，详见下一行与 Linux build baseline |
| Ubuntu 22.04 X11 | `c9db7c96` app + `31fa34c0` version + `c25e22aa` package script / `build/linux-lldtmp`（旧候选） | 全新 Flutter/CMake build-dir；从 Ubuntu `lld-14` 包解压真实 LLD 到 `/tmp` 后构建；生成 `1.1.0+2027` amd64 `.deb`。此候选已由 `1.1.0+2028` 更新 |
| Ubuntu 22.04 X11 | `bcf9993e` / `build/linux-lldtmp`（旧候选） | 用实际 LLD 14 构建 `1.1.0+2028` amd64 `.deb`；已由 `1.1.0+2029` 取代 |
| Ubuntu 22.04 X11 | `801f2bcc` / `build/linux-lldtmp` | 同一全新 CMake build-dir 用实际 LLD 14 构建当前代码并打包 `1.1.0+2029` amd64 `.deb`；核对依赖、ELF、desktop entry、图标和 SHA-256。未安装、未启动、未运行 Flutter 测试；实际桌面验收仍待用户执行 |
| Ubuntu 22.04 X11 | `c2a9e159` / `build/linux-lldtmp` | 更新 Explore 搜索状态恢复后，以实际 LLD 14 构建并打包 `1.1.0+2030` amd64 `.deb`；核对包元数据与 `libapp.so` 哈希。未安装、未启动、未运行 Flutter 测试；实际桌面验收仍待用户执行 |
| Ubuntu 22.04 X11 | `07821639` / `build/linux-lldtmp` | 队列拖动冲突提示变更后，实际 LLD 14 构建 Linux release 并打包 `1.1.0+2031` amd64 `.deb`；核对包元数据、ELF 与 `libapp.so` 哈希。未安装、未启动、未运行 Flutter 测试；实际桌面验收仍待用户执行 |
| Ubuntu 22.04 X11 | `a9cb6989` / `build/linux-lldtmp-2032` | 收藏夹滚动 key 隔离后在全新 CMake build-dir 使用实际 LLD 14 构建 `1.1.0+2032` amd64 `.deb`；核对包元数据、ELF 与 `libapp.so` 哈希。未安装、未启动、未运行 Flutter 测试；实际桌面验收仍待用户执行 |
| 初始 Android universal APK（已废弃） | `79310b27` checkout / `app-release.apk` | 初次打包错误沿用 `1.1.0+26` 和全 ABI 输出，不能作为用户现装 `2026` 的升级包；已由下方 arm64 APK 取代 |
| Android ARM64 APK | `1.1.0+2027` 候选（已替换） | version code `4027` 的 arm64-only APK 已签名校验，并由下方 `4028` 候选替换 |
| Android ARM64 APK | `1.1.0+2028` 候选（已替换） | version code `4028` 的 arm64-only APK 已签名校验，并由下方 `4029` 候选替换 |
| Android ARM64 APK | `801f2bcc` / `pubspec.yaml` `1.1.0+2029` / `app-arm64-v8a-release.apk` | `--split-per-abi --target-platform android-arm64` 构建；APK version name/code 为 `1.1.0` / `4029`（Flutter 的 arm64 ABI version offset），仅含 `arm64-v8a`；本机 `echo-release` 证书签名，`apksigner` v2 校验通过；核对 `com.az1n.echoes`、min SDK 24、target SDK 36。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `c2a9e159` / `pubspec.yaml` `1.1.0+2030` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4030`，仅含 `arm64-v8a`；本机 `echo-release` 证书签名校验通过；SHA-256 `f5d419ef2e8516f70d030651b8200ea1736ae5f5beb379c76649944755b4d79b`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `07821639` / `pubspec.yaml` `1.1.0+2031` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4031`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `7d574cc0108d0368ebb07a3b01e661e0af3d568de923e9d73b072d18b3f49930`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `a9cb6989` / `pubspec.yaml` `1.1.0+2032` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4032`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `c9e804155dc1f08ff811eb7765806f46d850fc6cb0b7a9f986e9daf8d07fe9f5`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Ubuntu 24.04 / Wayland | — | 待提供环境与结果 |
| Windows | — | Windows CI 暂缓；未编译/未实机验收 |
| Android 回归 | 本任务 Flutter 测试 431 项通过 | artwork/shared player 自动回归通过；最终 Android 真机锁屏/通知栏/封面验证待完成 |
