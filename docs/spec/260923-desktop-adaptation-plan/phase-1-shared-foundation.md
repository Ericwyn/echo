# P1：共享播放与组件边界

[返回 spec](README.md) · [总体设计](desktop-adaptation-plan.md) · [验收](acceptance.md)

状态：部分实现。前置：Linux 媒体会话路径已可用；Windows 专项继续待验证。后续：P2/P3 使用共享内容，P4 通过同一命令与快照接入系统。

## 目标与边界

给现有 `PlayerNotifier` 和组件建立小而稳定的复用边界，保留现有缓存、重试、鉴权、转码 seek 和队列算法。优先抽取已确定被两个界面使用的责任，不把约 4200 行 notifier 的整体重写列为该阶段目标。

## 共享契约

| 契约 | 必须包含的行为 |
| --- | --- |
| `PlaybackCommands` | play/pause/toggle、next/previous、逻辑 seek、userVolume/mute、随机/循环、按 entry ID 选择/移除队列项 |
| `PlaybackSnapshot` | 当前 library/entry 身份、来源版本、元数据、逻辑 position/duration、播放意图/状态、错误/缓冲、userVolume/muted、可操作能力 |
| `PlaybackQueueContent` | 渲染当前顺序与稳定条目，发出选择/播放/移除/排序意图；不知道自己在 Sheet 还是桌面容器 |
| `AppNavigationModel` | 稳定 destination ID、路由目标、分组、可见性、当前状态；宽侧栏和手机抽屉消费同一份定义 |
| `SongAction` | 操作标识、标签、是否可用、业务回调；不同 presenter 呈现相同动作 |

命名是接口建议，实施可调整。契约测试和调用方向必须保持明确；UI 选择项与真正 currentEntryId 是两个状态，不因单击选择自动改变播放状态。

## 实施步骤

1. 在现有 notifier 外提供命令入口和只读快照，第一步直接委托既有方法。按消费方需要使用 provider select/独立流，分离高频进度、曲目元数据与低频队列变化，避免每个 position tick 都复制队列。
2. 明确播放器所有权：当前 Android `initAudioService` 创建播放器，桌面 notifier 直接创建。首轮允许保留这两条原生初始化路径，但所有权各自唯一；adapter 不创建/销毁引擎。
3. 明确命令方向：系统 handler 的回调→commands→notifier→engine；notifier 发布 snapshot→handler。状态发布不反向触发相同命令。既有异步 `play()` 的完成语义不能被误当成“开始播放已完成”而阻塞后续流程。
4. 处理切库：旧订阅解绑、旧异步结果按 library/entry/source generation 丢弃、新 snapshot 重新绑定。若 audio_service 是进程级单例，复用会话并重新绑定命令，而非每次 notifier 重建都重新注册服务。
5. 抽取音量状态：userVolume 为 0–1，fadeGain 为 0–1，实际音量为 `muted ? 0 : userVolume * fadeGain`。保存 userVolume；首次无记录时使用当前默认值。采用 D5 时静音只存在当前进程。
6. 审查所有 `setVolume` 路径，至少包括 `_cancelFade`、`_fadeIn`、`_fadeOut`、`_fadeOutForPause`、stop、错误恢复及 `EchoAudioHandler` 回退。过期 timer 不能改新歌曲音量；取消淡入淡出只重置 fadeGain。fade 期间用户调音量仍立即生效。
7. 从 `PlayQueueSheet` 抽出内容绑定/纯列表；“播放后关闭 Sheet”由手机容器决定，桌面保持打开。保留 entry ID、revision、拖拽中发生修改的检查与当前项定位。
8. 从 MiniPlayer/FullPlayerPage 提取确实重复的歌曲信息、控制与进度部分，保留手机手势和 Hero 行为。队列/歌词展示不持有额外播放器。
9. 抽取导航与歌曲动作定义，桌面页面路由接入留给 P2。将音质非正位深处理为未知，确保各端使用同一格式化规则。

### 元数据与系统会话的补充边界

Android 的 `_updateMediaItem` 在 `_audioHandler == null` 时返回，但 Linux/Windows 媒体 adapter 通过 `PlaybackSnapshot.fromState` 独立取得当前元数据，不依赖 Android handler。`PlaybackMetadata.fromSong` 现作为平台无关的纯 metadata value，统一标题、缺失艺术家/专辑和有效时长规则；`audio_media_item_mapper.dart` 只负责转换到 AudioService `MediaItem`。新增 snapshot/MediaItem 一致性用例尚未运行，Android 最终实机回归仍待完成。

artwork 使用明确的“待解析网络 URI / 本地文件 URI或路径 / 无封面”状态，由 adapter 转成其原生接口要求的类型。元数据更新不等待封面下载，封面完成后按 library/entry/source generation 补发；无封面是清理旧图的事件，不是忽略更新。

唯一播放器约束指实际解码/输出引擎。SMTC 若需要无音源的原生会话宿主，由 Windows adapter 持有并释放；它不参与队列/恢复/音量算法，也不能自动播放。线程、原生能力和 bridge 错误留在 adapter 内部。[技术依据与取舍](research-stream-music.md)

## 主要文件

`lib/providers/player_provider.dart`、`lib/providers/player/player_state.dart`、`lib/providers/player/playback_queue_state.dart`、`lib/core/services/audio_handler_service.dart`、`lib/features/player/widgets/play_queue_sheet.dart`、`song_options_sheet.dart`、`mini_player.dart`、`lib/widgets/app_drawer.dart`、`lib/widgets/echo_app_shell/`。

新增文件以责任命名，不在平台无关组件中 import 托盘、window 或 D-Bus API。

## 回归与完成条件

- A04：20% 音量经切歌、暂停淡出、恢复、seek 换源、重试仍为 20%；静音不被 fade 取消。调节 userVolume 与过期 fade timer 竞争有测试。
- A05/A07：手机队列点击仍按既有规则关闭、排序与随机规则不变；同曲重复入队仍可选择正确 entry；`0bit` 不再出现。
- A08/A13：命令双向同步没有循环，每次系统动作只调用一次业务入口；切库解绑旧订阅，退出只释放播放器一次。
- 运行受影响的 `test/providers/player_recovery_test.dart`、`playback_queue_state_test.dart`、`test/core/services/audio_handler_service_test.dart` 和 MiniPlayer/queue/widget 导航测试。相关失败修复后再进入新 UI 阶段。
- 共享变更仍通过静态分析；只有修改实际生成器输入时才重跑对应代码生成，按仓库 PR 检查验证生成文件。

先以旧界面消费新契约并通过回归，再让桌面界面接入。阶段回退应只撤回新增边界/适配调用，不需要回滚数据库或队列会话格式。

## 实施记录

| 日期 / 提交 | 实际修改与检查 | 结果 / 遗留 |
| --- | --- | --- |
| 2026-09-23 / 首个实施里程碑 | 新增 `PlaybackCommands` 与 `PlaybackSnapshot`，`PlayerNotifier` 继续作为唯一引擎所有者；音量拆分为 userVolume 与 fadeGain，userVolume 本地保存；运行 `flutter test test/providers/player_recovery_test.dart`（31 项通过）和涉及文件的 `flutter analyze`（无问题） | 契约仍需接入系统 adapter 与桌面 UI；还需覆盖 seek/切源/恢复时音量竞争、metadata/artwork 独立构建、Android 专项回归及队列组件提取；P1 未完成 |
| 2026-09-23 / `f6100044` | 增加跨 Android/Linux 使用的 `ArtworkFileCache`，Android handler 与 Linux MPRIS 从本地缓存文件发布当前歌曲封面并丢弃过期响应；Linux 桌面直接创建 AudioPlayer，不再主动抛 UnsupportedError 触发 AudioService 误报；全量 431 项 Flutter 测试及项目级 `flutter analyze` 通过 | Android 需在设备上复验离线/切歌封面；metadata builder 仍有 Android handler 早退耦合；用户音量与 seek 换源竞争需持续手动观察 |
| 2026-09-23 / `21feeac1` | 抽出平台无关 `PlaybackMetadata` 和 AudioService `MediaItem` mapper；snapshot 与 Android 系统媒体映射共用标题/艺术家/专辑/时长默认规则。新增 metadata/snapshot/media item 一致性用例；仅格式化与 diff 空白检查，未运行测试、analyze、构建或应用 | 新模型的自动回归待运行；Android 通知栏/锁屏与 Linux MPRIS 仍需最终设备验收；音量竞争场景待补 |
| 2026-09-23 / `0f06bc0d` | 新增 `AppNavigationModel`，统一桌面侧栏项、手机主导航目的地与抽屉管理项的稳定 ID、分组、图标和页面目标；Explore 可见性只在模型里过滤；加入模型一致性测试。未运行测试或 analyze；release bundle 编译和 `.deb` 打包成功 | 用户需在桌面验证侧栏跳转/返回历史、设置与线路操作；手机 shell/抽屉回归测试仍待执行；P1 其余音量竞争和 Android 实机项未完成 |
| 2026-09-23 / `c5d2b512` | 移除 `EchoAudioHandler.play` 无回调兜底路径里强制 `setVolume(1)`，避免系统播放命令覆盖用户音量；新增 AudioService fallback 音量回归用例。未运行测试；Linux release build 与 `.deb` 构建通过 | Android 后台播放回归由用户执行；音量淡入淡出竞争用例仍待运行 |
