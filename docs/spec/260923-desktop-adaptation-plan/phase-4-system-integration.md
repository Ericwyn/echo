# P4：系统媒体、托盘与窗口生命周期

[返回 spec](README.md) · [决策](decisions.md) · [验收](acceptance.md)

状态：Linux 首轮已实现，部分实机通过。MPRIS SetPosition、Seeked、track ID 校验和远程 command error 隔离已落代码，新增测试尚未运行。前置：Linux P0 路径与 P1 命令/快照契约已建立；与 P2/P3 联调完成后才能认定桌面交互闭环。当前不运行 Windows CI，Windows 原生接入和实机仍未验证。

## 目标与拆分

- **P4-A 媒体会话**：Linux MPRIS、Windows SMTC，控制现有播放器；基础 Linux 版本可与 P2 组成 M1。
- **P4-B 托盘与窗口**：显示/隐藏、关闭/退出、单实例、窗口状态保存与恢复。
- **P4-C 联调和失败恢复**：切库、系统宿主变化、休眠/设备变化与资源清理。

P4-A 不依赖托盘存在；P4-B 的隐藏行为必须等托盘或其他恢复路径实际可用。用户已确认 Ubuntu 系统媒体控制、封面和托盘基础功能；关窗恢复和托盘宿主失效路径还未通过完整验收。Windows 没有真实桌面会话证据时只标注实现/编译状态，不标为已验收。

## P4-A：系统媒体会话

1. 采用 P0 选定并锁定的适配实现。系统 adapter 只持有 commands 与 snapshot 订阅，不创建 AudioPlayer；初始化失败返回能力状态并记录诊断，播放核心继续可用。
2. 发布 current entry、标题、歌手、专辑、时长、logical position、播放/缓冲/停止状态和准确能力。状态以应用播放意图和既有转码逻辑为准，不能从瞬时 decoder idle 推断用户已停止。
3. 系统 play/pause/next/previous/stop/seek 全部路由到 P1。同一媒体键只由一条链路处理；不同时注册额外全局热键处理相同事件。
4. Linux：唯一 MPRIS bus name，合法 object path；entry ID 映射 track ID，SetPosition 要核对目标是否仍是当前曲目。相对 seek、边界截断及不支持能力按规范处理。只有完成对应实现与测试才声明 CanSeek/CanRaise 等能力。
5. Linux 基础交付包含播放、暂停、切歌、元数据、状态。正式版本补齐对外声明的定位与 Seeked；TrackList/Playlists/OpenUri 不列首版必需范围，不能因应用内部有队列就谎报完整 MPRIS TrackList。
6. Windows：验证实际支持的 SMTC 时间轴与定位事件，发布可操作范围。系统未提供某个 UI 控件时按能力记录；应用内 seek 不受影响。
7. 位置同步在切歌、seek、状态变化时立即更新，运行中低频校正。UI 的高频进度流不逐帧广播系统消息；seek 成功后发正确位置与相应通知，seek 失败不伪造到达目标。
8. 鉴权封面由现有网络层取回并缓存成本地文件；对慢请求检查 library/entry/source generation，防止新歌曲显示旧封面。清理策略避免系统仍在读取时删文件；metadata 不包含鉴权 URL。
9. 切库重新绑定命令和快照；无当前曲目、显式停止、退出时同步清理或重置元数据，避免系统媒体卡片残留错误状态。

### Windows adapter 的实现要求

- 采用 P0 确认的 HWND 或无音源会话宿主路径；只有后一种路径需要管理宿主对象及其自动命令处理，避免同时维护两套 SMTC 实例。
- 保存并撤销原生事件订阅，正确跨线程传递到 Dart；退订后仍到达的回调安全丢弃。桥接错误返回诊断结果，不能通过未处理异常或 panic 终止整个播放器。
- 本地封面按接口转换为绝对文件路径，处理中文/空格与文件消失；切到无封面时明确清理旧 thumbnail，保持当前文本元数据。
- 设置真实的时间轴范围、播放位置及支持的定位事件。Windows 可从约 5 秒的周期校正起步，切歌/暂停/seek 立即同步；不要把该周期直接当作 Linux 的协议要求。
- 协议名称/图标与用户看见的应用名称一致；检查音量混合器是否显示插件默认名。若选定后端提供命名配置，在引擎初始化前设置并实测。
- 任务栏缩略图播放按钮留为可选增强；若实现，复用 commands，并与托盘/SMTC 分别释放。

依据和选型边界见 [音流技术调研](research-stream-music.md)；微软的 [手动 SMTC 接入文档](https://learn.microsoft.com/en-us/windows/apps/develop/media-playback/system-media-transport-controls) 用于确认线程、控制能力与时间轴接口。

## P4-B：托盘、实例与退出

1. 初始化窗口服务、可用托盘与恢复能力；成功注册图标仍需要确认存在宿主。托盘菜单提供显示主窗口、播放/暂停、上下首、退出，并随 snapshot 更新状态。
2. 全部关闭入口统一进入 lifecycle coordinator；区分 `requestClose`（窗口叉号）与 `requestQuit`（真正退出）。退出 guard 防止异步确认/窗口 destroy 再触发一轮关闭隐藏。
3. 采用下表行为，并让设置表达“关闭窗口后”的选择。首次隐藏告知恢复方式，后续不重复弹提示。

| 事件/能力 | 推荐行为 |
| --- | --- |
| 最小化 | 保持进程与播放，使用系统正常任务栏入口 |
| 关闭，用户选择退出 | 进入统一显式退出流程 |
| 关闭，选择后台播放，托盘/恢复可靠 | 隐藏窗口，播放/下载继续 |
| 关闭，选择后台播放，托盘不可用 | 优先正常最小化并保留任务栏；无法保证恢复时保持可见并说明 |
| 已隐藏，托盘宿主消失 | 恢复可见/任务栏窗口，停止继续使用不可恢复的隐藏状态 |
| 显示窗口/再次启动 | 恢复同一窗口，不创建第二个播放器；焦点行为尊重 compositor |
| 显式退出且有活跃本地下载 | 按 D6 提示取消退出或暂停下载并退出；不伪称下载会后台继续或支持断点续传 |

4. 显式退出先捕获会话恢复快照，再停止音频/任务，保存捕获的曲目与逻辑位置，解除 timer/订阅和系统会话、销毁托盘并结束进程。保存或释放异常有界处理并记录，不能无限挂起；stop 导致 position 清零后不能覆盖此前捕获的恢复位置。
5. Linux runner 已移除 `G_APPLICATION_NON_UNIQUE`，activate 回调在已有窗口时 present 现有窗口；仍需实机证明二次启动不会创建额外 GTK/Flutter 窗口或播放器。Windows 用 P0 确认的实例通信机制，在第二实例创建音频前转交激活并退出。
6. 保持 application ID、`.desktop` basename、MPRIS DesktopEntry 和图标一致；Windows 同样统一应用身份和安装后启动路径。
7. 保存正常窗口尺寸/最大化状态；显示器拔除时校正到可见区域。当前 Linux 实现只保存逻辑尺寸与最大化标记，不保存绝对坐标，因此不受 Wayland 拒绝 reposition 或旧屏坐标残留影响。Wayland 不支持的绝对定位/主动聚焦不反复强行重试，记录有效能力并提供正常恢复入口。

## P4-C：联调与异常

- 分别模拟系统媒体适配器失败、session bus 暂不可用、托盘无宿主和宿主重启；一项失败不连带禁用另一项或停止正常播放。
- 休眠唤醒、断网/恢复和音频输出设备切换沿用现有恢复入口；自动重试保持有界，用户暂停/停止后不擅自恢复出声。
- 快速切歌/切库/seek 同时有系统命令时，旧 generation 不能回写新状态；快速创建销毁 adapter 不留下重复订阅。
- 窗口隐藏时可停不可见 UI 动画，但维持播放控制、必要网络恢复与状态持久化。不要照搬 Android paused/detached 的处理来销毁桌面引擎。

## 验证与完成条件

- A08：GNOME 和 `playerctl`/D-Bus 实机验证公开能力、状态与逻辑 seek；系统动作在应用/声音端只生效一次。
- A09/A10：隐藏→托盘恢复→媒体键→再次启动→显式退出，只有一个播放器；无托盘和宿主消失均可找回窗口。
- A12：Windows 媒体卡片、硬件媒体键、托盘、单实例和退出留独立实机记录。
- A13：共享 handler/notifier 变化通过 Android 后台、锁屏、seek 和音量回归。
- 用 adapter fake 验证命令方向、generation 和资源释放；用真实桌面验证系统能力。两类证据分别记录。

## 实施记录

| 子阶段 | 日期 / 提交 | 结果 / 遗留 |
| --- | --- | --- |
| P4-A Linux | 2026-09-23 / `f6100044` | 自定义 MPRIS/D-Bus adapter 接入共用 playback commands/snapshot；封面使用本地缓存文件；Seek、SetPosition、Seeked 和 CanSeek 已实现，系统播放/暂停/切歌与封面已获用户确认；绝对 seek 和能力声明仍待用户实机验证 |
| P4-A Linux hardening | 2026-09-23 / `d7f6b359`，bundle `c5d2b512` | 远程 root/player 方法与属性设置异常映射为 D-Bus failure/invalid-args，避免 command rejection 冒泡；异步 Quit failure 记录日志；Dispose 尽力撤销 object、release bus name 并关闭连接。新增 `SetPosition` 校验当前 track ID、限幅和 `Seeked` 测试，以及命令失败后服务仍响应的测试；未运行测试，用户仍需验证 GNOME/playerctl 的绝对 seek 与失败恢复 |
| P4-B Linux lifecycle | 2026-09-23 / `f6100044` | tray_manager/window_manager 菜单及窗口显示/隐藏逻辑已接入，用户确认托盘基础功能正常；StatusNotifier 宿主消失、关窗后恢复、单实例和退出边界尚待验证 |
| P4-B Linux single instance | 2026-09-23 / `9582436c`，bundle `4015f879` | GtkApplication 使用默认唯一实例；再次启动向已有进程发送 activate，runner 复用并呈现现有窗口。已随最新 bundle 编译；二次启动与隐藏恢复待 Ubuntu 实测 |
| P4-B Linux window state | 2026-09-23 / `2bbe899e`，bundle `4015f879` | 新增启动首帧前恢复逻辑尺寸与最大化状态，并对窗口 resize/maximize/unmaximize 做去抖持久化；不保存绝对屏幕坐标。源码已编译，恢复窗口、最小尺寸约束和屏幕变化仍待 Ubuntu 实测 |
| P4-B Linux close/quit | 2026-09-23 / `19c9fb4e` | 设置页可选择关闭时退出或保持托盘/最小化；显式退出检测活跃本地下载，允许取消退出或暂停下载后退出；批量暂停保护队列并处理取消与初始状态写入竞争。Linux release bundle 已编译，窗口关闭、托盘退出、取消和恢复下载流程待用户实测 |
| P4-C Android/Linux 联调 | 2026-09-23 / 自动测试 | artwork 过期响应和 MPRIS 状态测试在私有 D-Bus 会话中通过；全量 Flutter 测试 431 项通过。睡眠/音频设备和多个异常宿主组合仍待实机测试 |
| Windows | 暂缓 | 暂不跑 Windows CI；任何 Windows Dart/native SMTC 代码均未获 Windows 编译或实机验证，不列入当前可交付范围 |
