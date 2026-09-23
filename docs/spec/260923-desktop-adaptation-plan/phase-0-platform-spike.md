# P0：平台可行性与工具链验证

[返回 spec](README.md) · [决策](decisions.md) · [验收](acceptance.md)

状态：Linux 路径部分通过；Windows 暂缓验证。前置：总体方案与阶段范围已阅读。Linux 工作继续推进 P1–P5；Windows 系统集成和发布仍保持未验收。

## 目标与边界

用最小实验确定系统媒体会话、托盘、窗口和打包依赖的可行路径。实验控制现有播放器，不新建另一套音频引擎。该阶段不改完整桌面布局，也不把实验分支的结果当作正式功能完成。

已知基线：本机 Ubuntu 22.04.5/GNOME 42.9/X11，AppIndicator 已列入启用配置；系统 libmpv 是 0.34.1。项目锁定 Flutter 3.41.7，PR Linux job 固定在 Ubuntu 22.04 并构建 release。已接入 `dbus` MPRIS 与 tray/window lifecycle；用户确认系统媒体卡片可控制播放并显示封面，托盘基础功能正常。完整关窗恢复、宿主故障与单实例还未验证。Windows CI 暂不作为当前门槛。

## 实施步骤

### P0-A：Linux

1. 记录当前提交、未提交变更、Flutter/Dart、clang/lld、GTK、libmpv、会话类型与系统缩放。保存现有 Linux 构建和真实播放基线，核实 `libmpv` 的实际加载来源。
2. 对 K1/K4 列出候选 SDK/包版本和最低要求。优先保留满足三端构建的现有 SDK；确需升级时单独记录原因和 Android/Windows 影响。依赖解析通过后锁定版本与 native 依赖，禁止用浮动 Git 分支充当最终选择。
3. Linux 媒体会话实验：让当前歌曲发布标题、歌手、状态、时长、位置；系统播放/暂停、下一首只调用现有 notifier。确认 GNOME 和实际音频状态同步，且一次按键只产生一次命令。
4. 扩展能力实验：逐项核对绝对定位、相对 seek、Seeked、可播放/可切歌/可定位、音量、身份和 DesktopEntry；对不支持项写清结果。若候选插件无法满足正式范围，记录固定版本补丁与薄 `dbus` 适配的成本，再选择一条路径。
5. 托盘实验：设置图标和“显示主窗口/播放暂停/退出”菜单；隐藏→显示、窗口已最小化、用户关闭和显式退出分别验证。注册成功不能当成图标实际可见的证据。
6. 检测 StatusNotifier 宿主是否存在以及 NameOwner 变化，验证宿主消失时的恢复策略。实验中只能在恢复入口已经证实时开放隐藏窗口。
7. runner 已移除 `G_APPLICATION_NON_UNIQUE` 并在 activate 时复用/呈现已有窗口；仍需用第二次启动确认只存在一个进程、窗口和播放器。记录 Wayland 下无法保证的定位/抢焦点操作。
8. 将保留的实验代码整理到平台适配边界；移除临时绕过、重复事件订阅和硬编码路径，记录 P4 接入所需接口。

### P0-B：Windows

1. 明确 Windows 构建环境与可交互的真实桌面会话。CI 构建与 SMTC/托盘实机验收分别记录。
2. 用同样的命令入口验证候选 SMTC 实现，至少覆盖元数据、播放/暂停、切歌、媒体键、时间轴更新和退出清理。
3. 验证插件额外工具链、封面文件 URI、非 ASCII 路径及单实例候选；回填 K3/K5。
4. 没有 Windows 桌面会话时填“未测：缺环境”，允许 P1–P3 和 Linux 集成继续；Windows 发布条件保持未满足。

### Windows 候选的共同验证样本

根据 [音流技术调研](research-stream-music.md)，将现成包与薄 C++/WinRT 实现纳入 K3 比较；Rust/FRB 以明确缺口作为引入依据，Melos 不作为实验前置条件。

- 核对实际注册的音频后端以及初始化顺序，确认更换系统媒体插件不会无意改变 just_audio 的后端；记录媒体面板和音量混合器的应用名。
- 封面样本：鉴权远程图转本地缓存、离线本地图、中文/空格路径、无封面、缓存文件丢失、有封面→无封面、快速切歌时旧请求晚到。
- 原生样本：先在 Windows x64 构建并实际运行，检查每个 DLL 的架构；ARM64 只在列入发布范围时增加，不能把文章的 x86/Arm 历史现象泛化为当前支持结论。
- 系统样本：控制能力随曲尾/空队列变化、播放状态、时间轴和 seek；重复初始化/销毁后无重复回调，窗口隐藏期间媒体控制仍可用。
- 若采用 HWND 接入，确认所属窗口与销毁顺序；若采用无音源 MediaPlayer 会话宿主，确认未开启第二路音频/自动控制。两条实现路径只保留最终选择的一条。
- 记录候选结果和维护成本，按验证结果选型；不整包引入其他应用的 audio_service fork 及其无关 Android 改动。

## 代码接入点

- `lib/main.dart`：desktop media-kit 初始化；避免重复初始化。
- `lib/providers/player_provider.dart`：桌面跳过 AudioService 的现状、命令回调、逻辑位置与曲目切换。
- `lib/core/services/audio_handler_service.dart`：媒体元数据、transport intent 与 handler 生命周期。
- `linux/runner/my_application.cc`、`windows/runner/`：窗口和实例生命周期。
- `pubspec.yaml`、`pubspec.lock`、`.github/workflows/build_linux.yml`、`build_windows.yml`：候选工具链与依赖。

## 验证与离开阶段条件

| 检查 | 通过条件 |
| --- | --- |
| 同一播放器 | 从系统暂停后声音停止且 UI 同步；连续切歌无重复音频/重复命令 |
| Linux 身份与发现 | GNOME/会话 D-Bus 可发现预期实例，不出现残留或重复媒体播放器 |
| 托盘可恢复 | 菜单能恢复窗口，宿主不可用时保留可见/可恢复窗口 |
| 依赖可重复 | 明确 SDK、包、native 版本；新环境按记录可构建，结束临时 linker shim 依赖 |
| Windows 边界 | 有独立结果，或明确缺环境、下一验证点和未满足的发布条件 |

可使用 `playerctl`（若已安装）或会话 D-Bus 验证；先列出实际 MPRIS 服务名，再针对该实例测试。不要写死示例名字后将“未找到实例”误判为功能故障。单测不足以代替 GNOME 桌面交互。

## 产出与实施记录

- `evidence/<日期>-linux-platform-spike/`：版本清单、命令/结果、精简日志、系统媒体卡片和托盘截图。
- 当前构建环境清单：[Linux build baseline](evidence/260923-linux-build-baseline/README.md)。该记录只证明工具链和产物元数据；不代表安装、应用运行或 GNOME 交互验收。
- Windows 对应独立证据目录；未实际产生的记录不创建占位成功截图。
- 更新 `decisions.md` 的 K1–K6，注明已确定项和仍待验证项；更新 `acceptance.md` 的 A08–A12 状态。

| 日期 / 提交 | 实际修改与检查 | 结果 / 遗留 |
| --- | --- | --- |
| 2026-09-23 / `f6100044` | 确认 Ubuntu 22.04 上系统 libmpv 0.34.1；选择薄 D-Bus MPRIS 与 `tray_manager`/`window_manager`；本机 HTTP 音频 smoke test 覆盖 MPRIS host adapter 之外的 MPV 初始化/网络加载，未再出现未知 `subs-fallback` 与 lavf cache-dir 错误；431 项 Flutter 测试、`flutter analyze`、Linux x64 release 构建通过 | 用户确认基本 MPRIS 控制、系统封面与托盘。仍需真实 MPRIS seek、关闭/恢复、StatusNotifier 宿主消失、单实例和干净安装实测；Windows 路径未测 |
| 2026-09-23 / `9582436c`，bundle `4015f879` | Linux runner 移除 `G_APPLICATION_NON_UNIQUE`；收到 activate 时若窗口已存在则 `gtk_window_present`，否则创建首个窗口 | 最新 release bundle 已编译这段 GTK 代码但未启动；二次启动、隐藏后恢复与进程数仍待 Ubuntu 手动验收；Windows 未测 |
| 2026-09-23 / `1cf593f6`，build baseline evidence | 记录 Ubuntu 22.04.5/GNOME/X11、Flutter 3.41.7/Dart 3.11.5、GTK 3.24.33、D-Bus 1.12.20、libmpv 0.34.1 与 appindicator 版本；检查 bundle ELF 和 `.deb` 的架构、桌面入口、图标、依赖与 SHA-256 | Linux release 编译和打包成功；未安装、未启动、未测试；dconf 缩放值未作证据，临时构建 shim 仍需消除/确认必要性；Windows 暂缓 |
