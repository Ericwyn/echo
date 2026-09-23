# P5：打包与跨端验收

[返回 spec](README.md) · [验收矩阵](acceptance.md) · [决策](decisions.md)

状态：应用代码 `9cbc98fa` 已在全新 `build/linux-lldtmp-2044` CMake 目录中构建，使用系统 Clang 与从 Ubuntu 包解压到 `/tmp` 的真实 LLD 14；`c25e22aa` 支持从该 bundle 生成 Ubuntu `.deb`。当前 checkout 另已构建并签名 Android arm64-only release APK，versionCode `2033`，签名与 package metadata 已校验；两端产物均未安装或启动。前置：P0–P4 仍有系统操作、恢复、性能和安装场景待验证。当前优先 Ubuntu/Linux；Windows CI 暂缓。

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
- 历史包 `build/linux/packages/echoes_1.1.0+26_amd64.deb` 与 `1.1.0+2027` 至 `+2043` 候选均已被后续构建替换。当前最新包为 `build/linux-lldtmp-2044/packages/echoes_1.1.0+2044_amd64.deb`，SHA-256 为 `a53fc7ae559a72f60908bfc64246e70b84065362e2e58f2afcefdecc7ca5492d`；`dpkg-deb` 元数据检查通过，仍未安装验证。干净系统播放依赖仍待 Ubuntu 实机记录。

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
| Ubuntu 22.04 X11 | `f2828730` / `build/linux-lldtmp-2033` | 曲库集合/全部歌曲滚动 key 隔离后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2033` amd64 `.deb`；核对包元数据、ELF 与 `libapp.so` 哈希。未安装、未启动、未运行 Flutter 测试；实际桌面验收仍待用户执行 |
| Ubuntu 22.04 X11 | `871f95ed` / `build/linux-lldtmp-2034` | SongListPage 滚动签名缓存后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2034` amd64 `.deb`；核对包元数据、ELF 与 `libapp.so` 哈希。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `cf131727` / `build/linux-lldtmp-2035` | 播放队列锚点缓存和定位索引优化后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2035` amd64 `.deb`；核对包元数据/依赖/入口/图标；bundle ELF x86-64，SHA-256 `f747f4fcba67322251ca996b79dece8e67b3da0621326410e398e310aec9c0cf`，`libapp.so` SHA-256 `8f0131eb2fe95445d1f82ba6a673823e5dcb49ccb68bdd5c1af85f209c7a440f`，`.deb` SHA-256 `3d328502812a9763d70c6f9f5afe3f34525c587640b2616bf3830622294a67c3`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `16add6b6` / `build/linux-lldtmp-2036` | 桌面队列增加“定位当前”后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2036` amd64 `.deb`；核对包元数据/依赖/入口/图标；bundle ELF x86-64，SHA-256 `4aeb84fef017c705de41d0ea706ac27345c5acc4e1d39a18fe402bb34055534f`，`libapp.so` SHA-256 `d2c2f6a1c40dfac7c516c2a3cadac2da4ef62eca3e5814a58f4376d5dcf74d30`，`.deb` SHA-256 `2fd3587139e6b22544cf19e370406d119d5699466ad83884d4cfb4d1f478397d`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `82edffab` / `build/linux-lldtmp-2037` | 桌面队列加入序号及按宽度展示专辑/时长后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2037` amd64 `.deb`；核对包元数据/依赖/入口/图标；bundle ELF x86-64，SHA-256 `af48c6ae345b197197afc6fa58f6050bc9f5904064912f33cfc78046f274ff95`，`libapp.so` SHA-256 `c637c4e9d4e81958ed64019580dbc1a0b0663a671f5740548f8d8f071ade413d`，`.deb` SHA-256 `2015a7e82345f197638e74ce298dd19c458df9d18f2f3c9fbc9c96c067d687e3`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `a79f7210` / `build/linux-lldtmp-2038` | 提取共享播放控件与 SongAction 后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2038` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `1efcd0e119a9133c6745f7d8cf63d5900da7e448348df568315cbf258ea91c1f`，`libapp.so` SHA-256 `c81c39ebc99439c1e501b5888001cd898e21ad4ed19b4de4a6287a5cad15eb2c`，`.deb` SHA-256 `90755d9d53581e76265040a7ff4b78c56abda3fd602e1f56f389ec47f5d1e59b`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `7e0c991b` / `build/linux-lldtmp-2039` | 歌曲弹层内建操作统一为 `SongAction` 后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2039` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `3bffc3fe06a5f547235ff83db85018a23f113764722d70aed61d7b53e6012e26`，`libapp.so` SHA-256 `e611c69d5d0dfb07bd54b164a0f93536634ffa36883d4dcd552c0ba3856777f4`，`.deb` SHA-256 `1bec76debeab85de7b82105fc96b63d5763ef3d0efd3c7410125cc84c47237a6`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `7eea69e9` / `build/linux-lldtmp-2040` | UI transport、seek、音量、模式与队列命令接入 `PlaybackCommands` 后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2040` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `c12266581f3526fa8d6f6a772bf134b9ef6204f2a42f321abb161beceaa4d450`，`libapp.so` SHA-256 `9fee06e3a1fcd3f83443699473041c5ac60d22dde67befa862080ef0ce4463f8`，`.deb` SHA-256 `8633a2fd199b9eccbe93dbfd0daba052023fd98306de8ce2461013e50ea89786`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `8149800f` / `build/linux-lldtmp-2041` | 进一步让键盘播放快捷键、Linux 托盘 transport 与同步歌词 seek 调用 `PlaybackCommands` 后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2041` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `54e40bcf90567b5f7da2b7bfedd5c3288dc1c5cc288a606fcd5ada92179f215d`，`libapp.so` SHA-256 `28f7aea71f66042533cfe1f7ae782562dfd037a08adb2e127f6016f69344f6a9`，`.deb` SHA-256 `78d4dc7ac8b27be530eada228fa7d18da4fafdc78600c9b3563d32bd35c1fe0d`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `76b964af` / `build/linux-lldtmp-2042` | 桌面播放条和共享 transport 改为选择 `PlaybackSnapshot` 后，以实际 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2042` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `f4ef507642f3a942a8a8755a7703ac7f225bd7d9b663ae4ec702a168d610593d`，`libapp.so` SHA-256 `67249fb9816c0ede6588d7cd8db10af09f8b77e06be4385552aa5e081d0a9a5b`，`.deb` SHA-256 `0a5a2053be47b9bdec8ed21111e260aee941b30977b703a38f35321464d90c2c`。未安装、未启动、未运行 Flutter 测试；release/profile 性能采样待用户执行 |
| Ubuntu 22.04 X11 | `87b994e3` / `build/linux-lldtmp-2043` | 桌面队列增加双击播放后，以系统 Clang 与真实 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2043` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `1010965e1e473f41e5d9101286dffc103892992a7a0f13962a023f56779a2922`，`libapp.so` SHA-256 `c80937cd6c3630c5e91481e13ddbc9197894254d57fb210e6e36175d35fd6741`，`.deb` SHA-256 `1b76e5509199a1b0b3de70c0aa53aa1bcafbf86180f430fcd6b1a9be6954db63`。未安装、未启动、未运行 Flutter 测试；桌面交互和 release/profile 性能待用户执行 |
| Ubuntu 22.04 X11 | `9cbc98fa` / `build/linux-lldtmp-2044` | 播放工作区加入系统全屏和尺寸持久化保护后，以系统 Clang 与真实 LLD 14 在全新 CMake build-dir 构建 `1.1.0+2044` amd64 `.deb`；核对包名、版本、架构、依赖；bundle executable SHA-256 `5bace48849f7779f3a200396b9b582213b74e0dff6c843b83adb168031651422`，`libapp.so` SHA-256 `44c6495d2fbfc8943e8508ffb41f0863eea5f145ad69a2d3269e4da597aecf46`，`.deb` SHA-256 `a53fc7ae559a72f60908bfc64246e70b84065362e2e58f2afcefdecc7ca5492d`。未安装、未启动、未运行 Flutter 测试；普通/全屏窗口几何及 release/profile 性能待用户执行 |
| 初始 Android universal APK（已废弃） | `79310b27` checkout / `app-release.apk` | 初次打包错误沿用 `1.1.0+26` 和全 ABI 输出，不能作为用户现装 `2026` 的升级包；已由下方 arm64 APK 取代 |
| Android ARM64 APK | `1.1.0+2027` 候选（已替换） | version code `4027` 的 arm64-only APK 已签名校验，并由下方 `4028` 候选替换 |
| Android ARM64 APK | `1.1.0+2028` 候选（已替换） | version code `4028` 的 arm64-only APK 已签名校验，并由下方 `4029` 候选替换 |
| Android ARM64 APK | `801f2bcc` / `pubspec.yaml` `1.1.0+2029` / `app-arm64-v8a-release.apk` | `--split-per-abi --target-platform android-arm64` 构建；APK version name/code 为 `1.1.0` / `4029`（Flutter 的 arm64 ABI version offset），仅含 `arm64-v8a`；本机 `echo-release` 证书签名，`apksigner` v2 校验通过；核对 `com.az1n.echoes`、min SDK 24、target SDK 36。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `c2a9e159` / `pubspec.yaml` `1.1.0+2030` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4030`，仅含 `arm64-v8a`；本机 `echo-release` 证书签名校验通过；SHA-256 `f5d419ef2e8516f70d030651b8200ea1736ae5f5beb379c76649944755b4d79b`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `07821639` / `pubspec.yaml` `1.1.0+2031` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4031`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `7d574cc0108d0368ebb07a3b01e661e0af3d568de923e9d73b072d18b3f49930`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `a9cb6989` / `pubspec.yaml` `1.1.0+2032` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4032`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `c9e804155dc1f08ff811eb7765806f46d850fc6cb0b7a9f986e9daf8d07fe9f5`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `f2828730` / `pubspec.yaml` `1.1.0+2033` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 构建脚本产物；APK version name/code 为 `1.1.0` / `4033`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `913093d33ad26f20d6697e97de5eb7b05ba4d1f3fb388cddc9f13c378434fb95`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `871f95ed` / `pubspec.yaml` `1.1.0+2034` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 脚本产物；APK version name/code 为 `1.1.0` / `4034`，仅含 `arm64-v8a`；本机 release 证书校验通过；SHA-256 `94565bb825dd7d307a3b8baddd936852124f9a7e8bcdeafcc5f7500f58b5a1e4`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `cf131727` / `pubspec.yaml` `1.1.0+2035` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 脚本产物；APK version name/code 为 `1.1.0` / `4035`，仅含 `arm64-v8a`；本机 release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `a6e98c83d52bf9516f53e212ca3a78c32da1a82bfcbb1f99558e9c58f896353c`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `16add6b6` / `pubspec.yaml` `1.1.0+2036` / `app-arm64-v8a-release.apk` | 本机专用 ARM64 脚本产物；APK version name/code 为 `1.1.0` / `4036`，仅含 `arm64-v8a`；本机 release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `17f5079e1785920c3ba71e678db6fe912dd23f7684e3d21fdaa28a862faae8a5`。未安装、未启动、未运行 Flutter 测试；设备回归见 [Android release build evidence](evidence/260923-android-release-build/README.md) |
| Android ARM64 APK | `82edffab` / `pubspec.yaml` `1.1.0+2037` / `app-arm64-v8a-release.apk`（已被替换） | 旧候选的 arm64-only versionCode 为 `4037`；后续按用户设备上报告的 `2026` 基线改成本机脚本显式传 build number 27，形成新的 versionCode `2027`，见下方最新项 |
| Android ARM64 APK | `a79f7210` / Android build number override `27` / `app-arm64-v8a-release.apk`（已被替换） | 旧候选 APK version code `2027`；当前本机脚本会从此前产物递增到下方 `2028`。|
| Android ARM64 APK | `7e0c991b` / Android build number override `28` / `app-arm64-v8a-release.apk`（已被替换） | 旧候选 APK version code `2028`，已由下方 `2029` 替换 |
| Android ARM64 APK | `7eea69e9` / Android build number override `29` / `app-arm64-v8a-release.apk` | 本机专用脚本产物；APK version name/code 为 `1.1.0` / `2029`，仅含 `arm64-v8a`；`apksigner` 验证通过，release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `6dd7ff15b501db779def63ed1b5aef10f30ebaa4ad8644c23600d3d24bf04970`。未安装、未启动、未运行 Flutter 测试；设备回归见 [共享播放器构建证据](evidence/260924-shared-player-layer-build/README.md) |
| Android ARM64 APK | `8149800f` / Android build number override `30` / `app-arm64-v8a-release.apk` | 本机专用脚本产物；APK version name/code 为 `1.1.0` / `2030`，仅含 `arm64-v8a`；`apksigner` 验证通过，release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `2ad4b2a4d8918cf734576017eb7d65d4858dd440bf5299208d02e38ecfed8a06`。未安装、未启动、未运行 Flutter 测试；设备回归见 [共享播放器构建证据](evidence/260924-shared-player-layer-build/README.md) |
| Android ARM64 APK | `76b964af` / Android build number override `31` / `app-arm64-v8a-release.apk` | 本机专用脚本产物；APK version name/code 为 `1.1.0` / `2031`，仅含 `arm64-v8a`；`apksigner` 验证通过，release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `0d11a2972907cd65c808a2e5281d44c9e0a65f5cb17e1324de57d90872744166`。未安装、未启动、未运行 Flutter 测试；设备回归见 [共享播放器构建证据](evidence/260924-shared-player-layer-build/README.md) |
| Android ARM64 APK | `87b994e3` / Android build number override `32` / `app-arm64-v8a-release.apk` | 本机专用脚本产物；APK version name/code 为 `1.1.0` / `2032`，仅含 `arm64-v8a`；`apksigner` 验证通过，release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `603e45d9efadc328aa7a4a4fb44cd999acb77ea55dd15cce155806f645749ef1`。未安装、未启动、未运行 Flutter 测试；双击的桌面交互不改变手机点击策略，通知栏/锁屏/共享播放器仍待真机回归 |
| Android ARM64 APK | `9cbc98fa` / Android build number override `33` / `app-arm64-v8a-release.apk` | 本机专用脚本产物；APK version name/code 为 `1.1.0` / `2033`，仅含 `arm64-v8a`；`apksigner` 验证通过，release 证书 SHA-256 `8604465c3ee1282b48a1b2759801f784ace32447d1188e0481fab0fe8ac74c94`；APK SHA-256 `a174cafa1a0c92ad5063c6c299df504541c1023c9d6210f94b49d4d1890c5d48`。未安装、未启动、未运行 Flutter 测试；宽屏 Android 不显示原生全屏操作，手机设备回归仍待执行 |
| Ubuntu 24.04 / Wayland | — | 待提供环境与结果 |
| Windows | — | Windows CI 暂缓；未编译/未实机验收 |
| Android 回归 | 先前检查点曾有 431 项 Flutter 测试通过；本次提交新增用例未运行 | 最新共享控件与歌曲操作改动的自动回归、Android 真机锁屏/通知栏/封面验证仍待完成 |
