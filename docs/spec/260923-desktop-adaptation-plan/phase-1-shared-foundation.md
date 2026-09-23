# P1：共享播放与组件边界

[返回 spec](README.md) · [总体设计](desktop-adaptation-plan.md) · [验收](acceptance.md)

状态：部分实现。前置：Linux 媒体会话路径已可用；Windows 专项继续待验证。后续：P2/P3 使用共享内容，P4 通过同一命令与快照接入系统。

## 目标与边界

给现有 `PlayerNotifier` 和组件建立小而稳定的复用边界，保留现有缓存、重试、鉴权、转码 seek 和队列算法。优先抽取已确定被两个界面使用的责任，不把约 4200 行 notifier 的整体重写列为该阶段目标。

## 共享契约

| 契约 | 必须包含的行为 |
| --- | --- |
| `PlaybackCommands` | play/pause/toggle、next/previous、逻辑 seek、userVolume/mute、随机/循环、按 entry ID 选择/移除队列项 |
| `PlaybackSnapshot` | 当前 library/entry 身份、来源版本、元数据、逻辑 position/duration、显式 seek revision、播放意图/状态、错误/缓冲、userVolume/muted、可操作能力 |
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
| 2026-09-23 / `bcf9993e` | `PlaybackSnapshot` 增加 position seek revision，`PlayerNotifier` 在 seek 成功后递增；Linux MPRIS 用它区分用户 seek 与延迟进度快照。新增 D-Bus regression test 未运行；Linux 与 Android release 均编译成功，Android handler 不消费此 revision | 共享契约保持跨端可编译，MPRIS 不再因普通位置跳变误报 Seeked；真机绝对 seek、Android 通知栏/锁屏仍待用户验收 |
| 2026-09-23 / `1b597ed0` | 扩展 `player_recovery_test.dart` 的 user volume / mute crossfade 用例：在淡出期间调高 userVolume，检查 fadeGain 与新用户值相乘、淡出到静音、偏好保存及恢复后的音量。按用户要求未运行测试、analyze 或应用 | 补齐了“淡入淡出过程中调节 userVolume”的回归场景；真实快速切歌、seek/source replacement 与 Android 后台音量竞争仍待测试/验收 |
| 2026-09-24 / `682907f3`, `a79f7210` | 将 `ProgressBar`、`PlaybackControls` 和播放图标按钮移到 `widgets/playback_controls.dart`；桌面播放条不再从手机 `FullPlayerPage` 导入它们，手机完整播放器保留原有 Hero 与手势容器。新增 `SongAction`（稳定 ID、标签、可用状态、破坏性标记和回调），接入队列移除、歌单移除和试听离线下载；添加 unavailable action 用例。只做格式化、diff 检查和 release 编译；未运行测试、analyze 或应用。Linux `1.1.0+2038` `.deb`、Android arm64-only `1.1.0` versionCode `2027` 均已构建 | 桌面/手机共享控制边界已移出页面层；MiniPlayer/Hero 细节和内建歌曲操作的 presenter-neutral factory 仍未抽取。新用例、Android 手机行为和 Linux 交互需用户验证；P1 继续保持部分实现 |
| 2026-09-24 / `7e0c991b` | 将歌曲弹层内建的收藏/下载/下一首/歌手/专辑/元数据编辑操作也定义为 `SongAction`；该模型含稳定 ID、可用/选中状态、长按行为与业务回调，弹层统一把模型映射为行。格式化、diff 检查通过；Linux `1.1.0+2039` `.deb` 与签名 Android arm64-only APK 编译通过，APK versionCode `2028`。未运行测试、analyze 或启动应用 | 现有歌曲操作入口统一经过动作模型，桌面与手机共用同一动作定义；SongOptionsSheet 仍负责创建业务回调，尚未抽成独立 action factory。新增/既有回归和 Android 实机行为待验证 |
| 2026-09-24 / `7eea69e9` | 将 `cyclePlaybackMode` 与 `clearQueue` 纳入 `PlaybackCommands`，新增 `playbackCommandsProvider`；MiniPlayer、FullPlayer、桌面播放条/队列及共享 `PlaybackControls`/`ProgressBar` 的 transport、seek、音量、模式和队列命令经统一接口委托给同一 `PlayerNotifier`。Linux `1.1.0+2040` `.deb` 和 Android arm64-only APK versionCode `2029` 均编译通过；更新 MPRIS command fake。未运行测试、analyze 或启动应用 | UI 与系统 adapter 现在消费同一 command contract；新增接口用例、Android 后台行为和 Ubuntu 交互仍待用户验收，P1 保持部分实现 |
| 2026-09-24 / `8149800f` | 将桌面键盘播放快捷键、Linux 托盘播放/下一首和同步歌词 seek 也改为通过 `PlaybackCommands` 调用；退出专用的快照保存/停止路径保留。Linux `1.1.0+2041` `.deb` 与签名 Android arm64-only APK versionCode `2030` 编译通过；测试、analyze 和应用均未运行 | transport/seek 的主要 Flutter、系统与托盘入口共用一份命令接口；播放器所有权仍由 `PlayerNotifier` 独占，用户需验证 Android 后台行为和 GNOME 媒体控制 |
| 2026-09-24 / `76b964af` | 新增 `playbackSnapshotProvider`；桌面播放条按 snapshot 选择元数据/模式，transport 按 snapshot 选择播放/加载/切歌能力，音量按 snapshot 读取；位置条缓冲进度仍独立订阅，避免把播放队列带入高频布局。Linux `1.1.0+2042` `.deb` 与签名 Android arm64-only APK versionCode `2031` 编译通过；未运行测试、analyze 或启动应用 | P2 桌面播放条现在消费 P1 snapshot 与 commands；provider 的状态映射测试、真实桌面刷新/缓冲体验和 Android 回归待用户验收 |
| 2026-09-24 / `4b9cd9f2` | 新增 `playback_snapshot_test.dart`，覆盖活动队列条目/transport 能力/seek revision/音量映射、等待播放请求与停止状态的区分，以及加载和错误标记；仅格式化与 diff 检查，按用户要求未运行测试、analyze 或应用 | 为最近接入桌面 UI 的快照契约补上回归定义；结果需由用户运行测试确认，P1 仍部分实现 |
| 2026-09-24 / `f8b026cb` | 新增独立 `SongActionFactory` 构建内建歌曲操作，动作回调通过根 `ProviderContainer` 执行业务；sheet 仅负责关闭、动作列表和歌单选择器呈现。修正动作本身与 sheet 行同时 pop 的双重关闭路径，并新增宿主附加动作只展示一次的用例。Linux `1.1.0+2045` `.deb` 与签名 Android arm64-only APK versionCode `2034` 编译通过；未运行测试/analyze 或启动应用 | 同一稳定 `SongAction` 集合现可交由不同 presenter 呈现；动作 callback/单次关闭与 Android 手机队列回归待用户运行/验收 |
| 2026-09-24 / `23729951` | 将完整播放页的位深/采样率展示提取到共享 `AudioSpecFormatter`，非正位深和采样率都按缺失值处理；增加格式化器用例，仅执行 Dart 格式化、Linux/Android release 编译和包元数据校验，未运行测试/analyze 或启动应用。Linux `1.1.0+2045` `.deb`、签名 Android arm64-only APK versionCode `2035` 均构建成功 | P1 步骤 9 的共享音质格式化已实现；用例结果、Android 视觉及实机回归仍待确认。仅发现 Android split-per-ABI 的 arm64 versionCode 会在 Flutter build number 上加 2000；本机忽略脚本已据此自动递增并校验最终值 |
| 2026-09-24 / `14f39032` | 将 MiniPlayer 与 FullPlayerPage 的标题、副标题和 Hero 文本封装为 `PlayerTrackIdentity`；mini 相邻曲目可禁用 Hero，完整页保留独立滚动，样式/截断由调用方提供。新增 Hero/无 Hero 回归用例，未运行测试/analyze；Linux `1.1.0+2046` `.deb` 与签名 Android arm64-only APK versionCode `2036` 构建及元数据校验通过 | 两种播放表面共享歌曲身份文本，同时维持原 Hero 标签和移动布局；新增用例与 Android 真机行为待用户确认 |
| 2026-09-24 / `ba35b87d` | `PlaybackSnapshot` 补入 `libraryId`、单调递增的 `sourceGeneration` 和 `bufferedPosition`；播放会话保存 library ID，旧会话回退到当前活跃库。Linux MPRIS track object path 按 library + entry 区分，Linux MPRIS 与 Windows SMTC 的 artwork 结果按 library/source generation 丢弃过期响应；新增 snapshot、MPRIS、SMTC 回归用例但未运行。Linux `1.1.0+2049` `.deb` 与签名 Android arm64-only APK versionCode `2039` 编译及签名/ABI/元数据核验通过；产物未安装/启动 | 共享快照仍由唯一 `PlayerNotifier` 提供；测试、Android 后台真机回归、MPRIS seek 和 Windows 实机验证仍待完成，P1 保持部分实现 |
| 2026-09-24 / `6f0f80e6` | 播放会话改为按 music library ID 存储，避免切库恢复到另一库队列；切库前保存旧队列、停止音频并清除旧 MediaItem，AudioService handler 进程级复用并按当前 notifier 重绑命令，初始化失败可重试。新增存储隔离、迁移与命令重绑用例但未运行；Linux `1.1.0+2050` 与签名 Android arm64-only versionCode `2041` 构建成功 | 自动回归、切库失败恢复、Android 通知栏/锁屏后台行为仍待用户验证；P1 部分实现 |
| 2026-09-24 / `67f62407` | 添加音乐库认证流程在远端验证成功后、写入/激活新库前调用旧 PlayerNotifier 的准备回调；旧队列按原 library ID 保存并停止，激活失败恢复原播放器并清理未激活的新库记录；成功后 LoginPage 失效旧 notifier，新的 notifier 从新库作用域恢复会话。新增成功顺序、数据库失败回滚和激活失败清理用例；未运行。Linux `1.1.0+2052` 与签名 Android arm64-only versionCode `2043` 构建通过 | 登录添加库不会让旧音频/会话跨库残留；自动用例、切库真机行为和 Android 后台媒体验证待完成 |
