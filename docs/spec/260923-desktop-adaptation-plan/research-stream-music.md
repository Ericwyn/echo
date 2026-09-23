# 音流技术文章：对桌面适配的参考

[返回 spec](README.md) · [选型决策](decisions.md)

调研日期：2026-09-23。材料为用户提供的两篇开发笔记，并对照本项目代码与微软官方接口文档。以下建议属于 Echoes 的方案取舍，未实施或验证新的原生集成。

## 文章提供的经验

- [插件分享](https://music.aqzscn.cn/docs/notes/plugins/) 列出 media_kit/audio_service、窗口/托盘、平台 UI、网络等插件实践。
- [SMTC 适配](https://music.aqzscn.cn/docs/notes/adaptive/smtc/) 展示 Rust 桥接的 Windows 控制与本地封面；作者记录过插件封面和处理器架构兼容问题，并说明 Melos 不是接入 SMTC 的必要条件。这些历史问题应转为验证样本，不能据此断言当前版本仍有相同缺陷。

## 本项目已经具备的基础

本地代码核查：

1. `lib/main.dart` 已在 Linux/Windows 调用 `JustAudioMediaKit.ensureInitialized()`；锁定的桥接包将 just_audio API 交给 media_kit。因此首版可以保留 `just_audio → just_audio_media_kit → libmpv`。
2. `PlayerNotifier._init` 主动跳过桌面 AudioService，这解释了缺少系统媒体会话的直接原因；播放引擎可用并不会自动解决系统控制。
3. `_updateMediaItem` 在 `_audioHandler == null` 时提前返回，元数据构建与特定 handler 耦合。P1 应独立构建平台无关的当前媒体信息，再交给 Android/Linux/Windows 发布器。
4. 当前同时声明 `just_audio_windows` 与 media-kit 桥接。应记录最终注册的后端和初始化顺序；不能仅凭存在两个依赖就认定发生双重播放，也不能让一次依赖调整无意更换后端。

以上根据本仓库与本地锁定依赖源码核实，不是对音流完整源码架构的推断。

## 建议采用的路径

| 主题 | Echoes 的取舍 | 落点 |
| --- | --- | --- |
| 播放与系统控制分离 | 保留现有引擎与恢复算法，系统 adapter 发布元数据/状态、把事件送回公共命令 | P1/P4 |
| 本地封面 | 单独建立 artwork 解析边界，区分网络 URI、文件 URI、原生绝对路径和无封面 | P1/P4 |
| Windows 系统能力 | 比较现成包与薄原生实现，按同一验收集选择，不把整体替换 audio_service 当作默认方案 | P0-B |
| 跨端组件 | 共用 Echo tokens 与业务组件，按输入方式选择菜单/窗口行为 | P2/P3 |
| 工程组织 | 先在现有工程分离 adapter；原生代码确需独立发布/测试时再抽本地 package | P1/P4 |
| 系统体验 | 应用名、图标、媒体面板与音量混合器身份一致；窗口和托盘服务独立 | P0/P4/P5 |

## Windows 选型的补充

P0-B 对 `audio_service_win`、`smtc_windows` 和薄 C++/WinRT 插件使用相同的封面、事件、时间轴、退出和打包样本；Rust/FRB 保留为有明确必要性时的另一实现方式。已有 Flutter Windows runner 使用 C++，引入另一门原生语言需要有实际收益。

微软提供通过顶层窗口 HWND 获取 SMTC 的 `ISystemMediaTransportControlsInterop::GetForWindow`。这是我们评估薄原生插件的官方接入点，隐藏窗口后的表现仍需实测。[Win32 API](https://learn.microsoft.com/en-us/windows/win32/api/systemmediatransportcontrolsinterop/nf-systemmediatransportcontrolsinterop-isystemmediatransportcontrolsinterop-getforwindow)

如果选用持有原生 `MediaPlayer` 来取得 SMTC 的实现，应把它限定为系统会话宿主：不给它音源、不让它产生第二路音频，并关闭自动命令处理。这里“一个播放器”的约束指唯一实际解码/输出引擎，并不禁止无音源的原生会话对象。选择 HWND 路径时无需为此主动增加 MediaPlayer。[微软手动 SMTC 集成](https://learn.microsoft.com/en-us/windows/apps/develop/media-playback/system-media-transport-controls)

### 需要补充的工程规则

- 回调通过适配器的合法线程/异步通道进入 Dart；退订后到达的事件丢弃，错误可上报而不是导致进程崩溃。保存事件订阅标识并显式释放。
- 封面加载失败仍发布新曲目的文本信息；从有封面切到无封面必须清理旧封面。慢响应同时核对 library/entry/source generation。
- 桥接 API 明确参数类型：原生文件接口收到的是解码后的 Windows 绝对路径，不能把 `file:///...` 字符串当成本地路径。样本涵盖中文、空格、文件不存在及缓存更新。
- 时间轴按平台支持能力接入；验证进度更新和反向 seek，曲尾/空队列时按钮状态与业务一致。
- 优先验证 Windows x64 构建与实际运行；只有将 ARM64 列为发布目标时才补对应 native 产物和设备。32 位 x86 不因历史文章提及而自动进入范围。
- DLL/原生库架构必须匹配最终可执行文件；若引入 Rust，同时锁定 Cargo 依赖、bridge/codegen 配套版本与构建 target。

具体回调线程、能力开关和时间轴要求以微软接口为准；其中 ButtonPressed 不在 UI 线程，时间轴需提供范围并处理位置请求，官方建议播放中约每 5 秒及状态变化时同步。[SMTC 手动控制](https://learn.microsoft.com/en-us/windows/apps/develop/media-playback/system-media-transport-controls)

## 延后或按故障触发的工作

- `windows_taskbar` 可添加任务栏缩略图播放按钮，作为 Windows 增强项，复用 commands；它和托盘、SMTC 是三个独立入口，不作为 Ubuntu 或首版发布门槛。[插件接口](https://pub.dev/packages/windows_taskbar)
- 保留现有设计系统，首版不新增 fluent_ui/macos_ui 整套组件体系，也不加入透明/毛玻璃效果。
- Rust/FRB、Melos 和 HTTP 栈迁移不作为桌面适配的前置任务。需要原生 package 或发现可复现网络兼容缺口时分别评估，避免同时改变播放器、网络与工程结构。
- 增加分通路网络检查：API、封面、下载、实际音频直连/缓存分别验证鉴权、代理与错误处理。即使以后修改 Dio adapter，也不能假设 libmpv 或缓存代理同时获得相同网络行为。

## 对现有 phase 的具体影响

- P0-B：扩充 Windows 候选与统一比较样本，记录实际播放后端、应用身份、原生架构与封面支持。
- P1：元数据从 Android handler 解耦，统一 artwork 类型与异步更新规则，澄清系统会话宿主和音频引擎的边界。
- P4：实现线程/事件释放、无封面清理、原生路径转换与系统时间轴；可选任务栏功能复用同一命令。
- P5：验证 Windows 原生库架构、离线本地封面及不同网络通路；按实际发布目标记录支持范围。

这些结论完善实现细节，不改变 Ubuntu 优先、共用播放核心以及现有六个 phase 的顺序。
