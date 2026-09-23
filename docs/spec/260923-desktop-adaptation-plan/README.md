# 桌面端适配

创建日期：2026-09-23。更新：2026-09-24。状态：**分阶段实施中，以 Ubuntu/Linux 为当前验证目标**。

目标：同一 Flutter 工程复用 Android/Linux/Windows 播放与数据核心，为桌面提供完整资料库导航、常驻播放条、封面与歌词/队列工作区、系统媒体控制、托盘以及可安装产物。当前优先验证用户的 Ubuntu 22.04 + GNOME 42 + X11；Windows CI 暂缓，相关代码和实机能力仍标记为未验证。

目前桌面侧栏、常驻播放条、歌词/队列工作区、Linux MPRIS 和托盘已有首轮实现。用户确认 Ubuntu 系统媒体卡片能控制播放并显示封面，托盘基础功能正常，音量条外观可接受。桌面与手机路由策略分开，目的地定义共享；桌面隐藏账户/服务器底栏和离线状态入口，品牌区/主工具栏对齐，播放栏贴齐主面板，手机窄屏抽屉保留移动入口。封面动态背景可持久化关闭；退出保存恢复快照，托盘 watcher 可处理宿主重启。路由前进复用 PageStorageBucket，搜索/筛选/滚动、收藏标签和曲库列表状态逐步接入。全部歌曲页滚动时复用数据签名，避免封面预加载窗口更新反复扫描整份曲库；长队列当前项定位记录已渲染行索引和队列 revision，并在滚动后清理离屏 `GlobalKey`；桌面队列标题栏新增“定位当前”入口，队列行按宽度显示序号、专辑和时长，窄空间隐藏专辑。P1 已抽出共享播放进度/transport widget、`SongActionFactory`、`PlaybackCommands`、`PlaybackSnapshot`、`AudioSpecFormatter` 和 `PlayerTrackIdentity`；播放按钮、队列、键盘快捷键、Linux 托盘与同步歌词 seek 使用统一命令入口；无效位深不再显示为 `0bit`。`87b994e3` 补上桌面队列双击播放；`9cbc98fa` 加入桌面全屏模式，Esc 优先退出全屏且正常窗口尺寸不会被全屏分辨率覆盖；Android 不显示原生全屏按钮。`23729951` 接入共享音质格式化，`14f39032` 统一迷你/完整播放页的歌名、副标题和 Hero 包装。Linux `1.1.0+2046` `.deb` 和签名 Android ARM64 APK（versionCode `2036`）已构建。产物未安装或启动；新增回归用例未运行。窗口/DPI、全屏桌面操作、MPRIS seek、托盘故障恢复、1654/5000 首 release/profile 性能、干净安装及 Android 真机回归仍待实测。按用户要求不启动应用或运行测试，手动交互由用户执行。

最近应用代码检查点：`14f39032`（迷你/完整播放页共用歌曲身份文本与 Hero 呈现）；Linux 版本 `1.1.0+2046`；Android 本机 ARM64 脚本产出 versionCode `2036`。Linux 自定义 bundle 打包支持提交：`c25e22aa`。本机签名脚本位于 Git 忽略的 `scripts/local/build_android_release_arm64.sh`，不纳入提交。

## 阅读入口

| 文档 | 回答的问题 |
| --- | --- |
| [总体设计](desktop-adaptation-plan.md) | 为什么改、界面如何组织、哪些代码复用、平台边界是什么 |
| [决策记录](decisions.md) | 哪些是用户要求，哪些只是推荐默认值，哪些需要技术验证 |
| [音流技术参考](research-stream-music.md) | 两篇开发笔记对播放分层、Windows SMTC、封面和打包验证的启发 |
| [P0：平台可行性](phase-0-platform-spike.md) | Linux 媒体会话、托盘和工具链的已验证部分及缺口；Windows 独立记录 |
| [P1：共享播放与组件边界](phase-1-shared-foundation.md) | 如何保持一个播放器和一套队列，解决音量与组件耦合 |
| [P2：桌面浏览框架](phase-2-desktop-shell.md) | 如何合并导航、接入子页面、构建首页和完整播放条 |
| [P3：播放工作区](phase-3-player-workspace.md) | 如何实现封面固定、歌词/队列切换、鼠标与键盘操作 |
| [P4：系统集成与生命周期](phase-4-system-integration.md) | 如何完成 MPRIS/SMTC、托盘、关窗、退出、单实例和恢复 |
| [P5：打包与跨端验收](phase-5-release-validation.md) | 如何交付 Ubuntu/Windows 包并证明 Android 没有退化 |
| [需求与验收矩阵](acceptance.md) | 什么算完成，各平台还缺哪些证据 |

## 阶段依赖与交付点

```mermaid
flowchart LR
    P0A["P0-A Linux 验证"] --> P1["P1 共享边界"]
    P1 --> P2["P2 浏览框架"]
    P2 --> P3["P3 播放工作区"]
    P1 --> P4["P4 系统与生命周期"]
    P0A --> P4
    P0B["P0-B Windows 验证"] --> P4W["P4 Windows 验收"]
    P4 --> P4W
    P3 --> P5["P5 发布验收"]
    P4 --> P5
    P4W --> P5
```

继续以 Linux 本机编译和测试推进。Windows CI 暂不作为当前门槛；Windows 原生桥接若保留在工作树中，仍需独立 Windows 编译与桌面会话验收后才能标记完成。阶段依赖表示代码/证据依赖，不是启动并行代理的要求。

| 阶段 | 当前状态 | 离开阶段的关键条件 |
| --- | --- | --- |
| P0 | Linux 部分通过 | Ubuntu 22.04/libmpv 0.34 兼容路径已验证；全新 CMake build-dir 构建需要 LLD 14，系统 LLVM 目录当前未安装。使用从 Ubuntu 包解压至 `/tmp` 的真实 LLD 14 后构建成功，未改系统。runner 已改为 GTK 单实例并复用现有窗口；二次启动、MPRIS seek、托盘恢复和干净环境交互证据仍待补 |
| P1 | 部分实现 | 单播放器、命令/快照、用户音量、封面缓存、共享 metadata 和导航模型已接入；`682907f3` 抽出跨桌面/手机消费的播放进度与控制 widget，`7e0c991b` 将歌曲操作抽象为 `SongAction`，`f8b026cb` 将动作构造移到 `SongActionFactory` 并让 presenter 统一负责关闭，避免重复 pop；`7eea69e9`、`8149800f` 让桌面/手机播放控件、队列、快捷键、托盘和歌词 seek 通过 `PlaybackCommands`，`76b964af` 让桌面播放条/transport 控件选择 `PlaybackSnapshot`，`23729951` 抽出共享音质格式化并忽略非正位深，`14f39032` 统一迷你/完整播放页的歌曲身份与 Hero 文本；Linux 与 Android arm64 release 编译通过。AudioService 兜底不重置用户音量；新增回归未运行；自动回归和 Android 最终实机回归仍待补 |
| P2 | 桌面统一返回/前进栈及主要浏览状态恢复已实现，等待用户复测 | 手机保留分支路由，桌面使用单 Navigator；无账户/服务器底栏与离线任务状态页；品牌区/主工具栏对齐、播放条贴边；前进复用 PageStorageBucket，搜索、音乐流展开、曲库列表、全部歌曲两种排序模式、详情排序、收藏页签和各自滚动位置、歌手内容区及 Explore 查询/草稿/滚动位置可恢复；新增回归未运行，窗口与页面状态仍待用户验证 |
| P3 | 首轮实现中 | 宽屏/紧凑工作区、歌词/队列切换与关闭重开后的状态保留、队列右键、可关闭的封面动态背景、拖动冲突提示、“定位当前”、桌面单击选中/双击播放及可选系统全屏已实现；Esc 先退出全屏，普通窗口尺寸不会被全屏分辨率覆盖，Android 不显示该系统窗口入口；相关用例未运行，Ubuntu 全屏操作、release/profile 性能采样和真实窗口验收待补 |
| P4 | Linux 基础可用 | 用户确认 MPRIS 控制/封面与托盘基础功能；单实例、关窗选择、下载退出提示及 SetPosition/Seeked/error 隔离已编译；Seeked 现依据成功 seek revision 发送，新增测试未运行；watcher 别名、查询竞态和重新注册已修正，宿主仍待验收 |
| P5 | 当前 Linux `1.1.0+2046` bundle/.deb 与 Android arm64 APK 均已构建 | Linux 使用系统 Clang 与从 Ubuntu 包解压至 `/tmp` 的真实 LLD 14，在全新 `build/linux-lldtmp-2047` 构建；Debian 包版本 `1.1.0+2046`、amd64，元数据已核对。Android arm64 APK 使用本机签名文件，version code `2036`，签名和包信息已校验。产物未安装或启动；Ubuntu/Android 实机验收和 Linux 性能采样待完成；Windows CI 与实机验收暂缓。最新产物见 [共享播放器身份构建证据](evidence/260924-player-identity-build/README.md) |

- **M1 可试用版**：P1、P2 加 P4 的基础 Linux 媒体会话；旧完整播放器可暂作过渡。托盘恢复尚未通过时，不开放关闭后隐藏窗口。
- **M2 Ubuntu 桌面候选版**：P3、P4-Linux 和 P5-Linux 完成，并通过共享代码的 Android 回归。
- **M3 双桌面正式范围**：补齐 P0-B、P4-Windows、P5-Windows，才宣称 Windows 同等支持。

## 实施时如何使用

1. 先读总体设计与决策，再读当前 phase；按前置条件选择工作，不需要将整份 spec 一次实现。
2. 一个 phase 可以拆成多个小提交；提交说明引用 phase 与验收用例编号。
3. 每次更新在对应 phase 的实施记录中填写提交、实际变更、检查结果、遗留项；验收状态统一更新到 `acceptance.md`。
4. 接口或产品行为发生变化时先更新对应设计/决策，再同步受影响 phase，避免各阶段自行定义不同规则。
5. 新增事实证据放 `evidence/<日期>-<平台>-<主题>/`，正文使用相对链接，不依赖临时目录、聊天附件路径或开发者私有目录。

相关约束：[既有队列语义](../260922-play-queue-redesign/play-queue-redesign.md)、[播放可靠性验证](../260918-playback-reliability-testing/playback-reliability-testing.md)、[UI 设计计划](../260715-echo-ui-overhaul-plan/echo-ui-overhaul-plan.md)。
