# P2：桌面浏览框架与完整播放条

[返回 spec](README.md) · [总体设计](desktop-adaptation-plan.md) · [验收](acceptance.md)

状态：首轮实现中。桌面侧栏按分组导航，不再显示离线任务状态页或账户/服务器信息块；品牌区与主面板工具栏共用高度，桌面播放栏贴合主面板边缘。线路选择与添加音乐库集中放在侧栏可达的设置页，音乐库切换/编辑也在那里提供。桌面现使用独立 Navigator：侧栏主目的地替换当前主页面，内容详情共享同一返回/前进栈，根页面为音乐流；Android 继续使用 `StatefulShellRoute`，窄屏抽屉保留远端离线任务状态入口。Linux 隐藏 GNOME GTK 标题栏和原生窗口框，由应用根部绘制覆盖登录与主界面的窗口栏及边缘缩放区；主应用页面在内容 shell 内显示返回/前进/搜索工具栏。窗口最小逻辑尺寸 840×560，避免落入 Android 风格布局。自动用例覆盖主目的地连续切换、详情逐层返回、前进恢复、重复返回箭头消除和窗口控制语义；`ce6a8ddd` 又增加真实 `VirtualWindowFrame` resize hit-zone 外层下点击最小化/最大化/关闭的回归用例，尚未运行。设置返回、顶栏高度对齐、无账户区、播放栏贴边、前进滚动、搜索、详情排序、收藏页签和歌手视图恢复等回归用例也未运行。用户实测反馈上一版窗口栏按钮不可点/闪烁、窗口缩放异常；已移除放在 Navigator Overlay 外的 Tooltip，启动时清除置顶并显式恢复缩放、最大化和最小化能力。前进通过保存的路由 builder 重建页面，并复用 route-local PageStorageBucket 恢复可滚动组件的位置；搜索页与 Explore 页恢复已提交查询和未完成输入，Explore 本地/远端结果列表位置也恢复；远端搜索 provider 已自动释放时，按保存的查询重新发起请求。专辑/歌单详情恢复排序选项，曲库歌曲/专辑/歌手列表使用独立 PageStorageKey；全部歌曲的字母索引和其他排序模式也隔离位置。收藏夹恢复页签并为歌曲/专辑/歌手标签页各自保存列表滚动，歌手详情恢复当前内容区和热门歌曲展开状态。`1de36904`、`685ea3db` 为设置页、搜索结果、下载管理、离线任务、专辑/歌单详情和编辑页补齐稳定滚动键，使桌面前进重建后能复用 route-local PageStorageBucket 中的位置。新增状态回归尚未运行。全部歌曲页滚动时重用稳定数据签名，不再在封面预加载窗口变化时遍历整个歌曲列表；1654/5000 首的 release/profile 性能与不同窗口/DPI仍待用户采样和验证。Windows 暂保留原生标题栏，之后单独验证。`a6ee5e65` 让设置页添加音乐库时登录成功返回原页面；编辑/删除库使用当前 Navigator 返回，保留桌面历史。

## 目标与边界

完成“一个资料库侧栏 + 浏览内容 + 常驻播放条”，让歌曲/专辑/艺术家、歌单、设置和下载都能在桌面连贯访问。复用数据 provider 与页面内容，新增桌面编排；保持登录/重新认证的独立路由。

## 实施步骤

1. 定义 layout policy：结构依据当前逻辑尺寸，输入方式决定鼠标/触控动作，平台能力决定媒体和托盘。保留现有 600/840 断点作为基础；为桌面 shell 使用独立组合策略，避免修改全局 tokens 使手机页面同时变形。
2. 手机路由继续由 `lib/app.dart` 的 `StatefulShellRoute` 管理独立 Tab 栈；桌面壳拥有根为音乐流的 Navigator。歌曲、专辑、艺术家、收藏、歌单详情、下载和设置复用已有页面，不切换到 Android 的 catalog/library branch 后再 push 子页。
3. 确保桌面常规子页使用统一 Navigator；认证留 root。桌面侧栏主目的地替换当前主页面，内容打开的详情正常入栈；Navigator observer 将当前目的地映射到侧栏选中项，pop 后还原父页面及所属入口。
4. 返回/前进基于一份桌面 Navigator 历史。Navigator observer 保存可重建的 `EchoPageRoute` builder 与目的地元数据；无可用历史时按钮禁用，新的侧栏目的地清理旧前进历史。前进会重建页面，列表滚动/筛选状态需由页面自身或稳定 state key 恢复并验证。
5. 宽屏解除桌面 `Scaffold.drawer`，移除侧栏账户/服务器身份底栏和离线任务状态入口。下载管理与设置由侧栏直达；线路切换、添加/切换/编辑音乐库集中到设置页。需要认证的添加音乐库流程仍走应用认证路由。手机继续使用原主导航与抽屉 presenter。
6. 歌单区域懒加载/独立滚动，支持后续置顶状态；首轮不为侧栏请求全部歌曲。无歌单、加载失败、离线和切库状态明确可见。
7. 首页复用最近播放与随心听数据，把宽横卡组合为有限尺寸封面网格/专辑架。超出范围使用明确翻页/查看全部；内容列数按 shell 内实际宽度计算，不只读整窗 MediaQuery。
8. 新增 DesktopPlayerBar，订阅 P1 快照与 commands。左侧歌曲，中间 transport 与进度，右侧 userVolume/mute、歌词和队列；空状态禁用不支持动作，暂停时保留控件。
9. 底栏置于稳定 shell 生命周期中，导航、页面滚动和普通模态变化不重建它。P3 完成前可继续打开原完整播放器/队列，明确是过渡版本；随后只替换入口与 presenter。
10. 键盘焦点、错误提示、长标题和大字体与界面一起完成。宽度不足优先折叠次要信息，低频操作进入更多菜单，不能把播放/切歌/进度藏到另一页。

## 路由与状态约束

| 状态 | 所属层 | 必须保持的行为 |
| --- | --- | --- |
| 当前库/鉴权 | 现有 auth/library providers | 桌面设置页管理切库/新增/编辑与线路；切库清理旧库导航选择，播放处理沿用既有策略 |
| destination/历史 cursor | 手机 StatefulShellRoute；桌面统一 Navigator/导航策略 | 返回/前进与侧栏高亮一致，刷新/重排不追加重复历史；前进重建后恢复对应页面状态 |
| 搜索、筛选、滚动 | 页面/分支 | 搜索草稿/已提交查询、音乐流随心听展开状态、曲库歌单排序、专辑/歌单详情排序、收藏页签及歌曲/专辑/歌手各自滚动位置、全部歌曲不同排序模式各自滚动位置、歌手内容区和滚动位置在桌面前进重建后恢复；其余页面局部状态继续逐页接入 |
| 当前曲目/队列/进度 | PlayerNotifier/P1 | 与可见页面生命周期无关 |
| 用户密度/音量 | 设置与 P1 | 不由临时窗口尺寸重设 |

## 主要文件

`lib/app.dart`、`lib/providers/navigation_provider.dart`、`lib/widgets/main_scaffold.dart`、`lib/widgets/echo_app_shell/echo_app_shell.dart`、`echo_shell_navigation.dart`、`lib/widgets/app_drawer.dart`、`lib/features/discover/pages/discover_page.dart`、`lib/features/library/pages/catalog_page.dart` 及其子页面。

复用 `EchoSongRow`、封面组件和设计 tokens；仅为桌面增加密度/组合参数，不复制网络请求和数据排序实现。

## 验证与完成条件

- A01：宽窗、图标栏与窗口连续缩放只出现一套主导航；桌面无账户/服务器底栏与离线任务状态页，设置/下载管理可直达。
- A18：桌面不展示账户操作区或重复功能菜单；线路选择与音乐库新增/切换/编辑可从设置页到达，添加流程退出后回到设置/桌面历史。
- R11：侧栏品牌区和全局工具栏实测矩形高度一致；底部桌面播放条与主面板左右/下边缘无额外间距。
- A02：从歌曲列表→专辑详情→设置→返回/前进，底栏和播放连续，页面状态正确恢复；不存在同一详情被无意 push 两次。
- A03/A04：底栏所有动作调用同一命令入口，加载/失败/无歌曲状态可理解，音量保持。
- A11：840×560、1280×720、1920×1080，以及 200% 字体/缩放组合无关键按钮遮挡；桌面窗口不能缩入 Android 紧凑布局。
- 复用并扩展 `test/widgets/echo_app_shell/echo_app_shell_test.dart`、`test/features/library/library_shell_obstruction_test.dart`，新增桌面导航历史和底栏行为测试；复查手机 drawer/MiniPlayer 和系统返回流程。
- 真实 Ubuntu release 中记录首页、资料库、设置与底栏截图。widget 通过不能代替桌面字体/DPI 检查。

## 实施记录

| 日期 / 提交 | 实际修改与检查 | 结果 / 遗留 |
| --- | --- | --- |
| 2026-09-23 / `f6100044` | 宽屏关闭 `Scaffold.drawer`；侧栏采用“发现/资料库/个人收藏/管理”分组，删除重复顶层音乐流/我的/曲库入口，统一字号并加大侧栏文字；账户 footer 与 96px 播放条共用高度 token；补充分组、无重复入口和高度对齐测试。全量 Flutter 431 项测试、项目级 analyze 和 Linux release 构建通过 | 用户此前确认基本桌面界面，最新侧栏/底栏尚需复验；还无全局前进历史按钮，窗口尺寸/DPI与账户入口需实机验证；阶段仍进行中 |
| 2026-09-23 / `224bb002` | 桌面改用独立 Navigator，音乐流为根；侧栏切换主目的地时替换页面，详情沿同一栈压入；Starred/歌曲/专辑从搜索或音乐流打开时沿用正确可见分支；“我的歌单”隐藏重复收藏区；设置编辑库页面改走所在导航层。新增主目的地切换、详情回退和音乐流根页面测试。全量 433 项 Flutter 测试、项目级 analyze 通过；Linux release bundle 编译通过（临时 PATH shim 提供系统 `ld`，未修改系统文件） | 桌面/手机路由已分开首轮落地；Ubuntu 实际滚动状态恢复与不同尺寸/DPI实机验证仍待完成；阶段仍进行中 |
| 2026-09-23 / `afc1a376` | `EchoPageRoute` 保存 builder 以支持前进重建；Navigator observer 维护前进栈，新的侧栏目的地会清空过期前进项；增加返回/前进/搜索工具栏。测试覆盖详情 pop 后 forward 恢复及点击音乐流清理前进历史。全量 433 项 Flutter 测试、项目级 analyze 通过；Linux release bundle 编译通过（临时 PATH shim 提供系统 `ld`，未修改系统文件） | 路由 builder 已恢复详情页面，但前进重建后的滚动/筛选状态、Ubuntu 实机工具栏与窗口/DPI表现仍待验证；阶段仍进行中 |
| 2026-09-23 / `7f4ae955` | Linux 在首帧前隐藏 GNOME GTK 标题栏和原生窗口框；根级 Echo 窗口栏提供拖动与窗口按钮；主应用仍有返回/前进/搜索工具栏；桌面最小逻辑尺寸 840×560；新增窗口栏语义和路由策略测试。上一轮全量 437 项、analyze、Linux release 曾通过，但后续 Tooltip/窗口状态修正未重新运行 | 用户报告按钮点击/闪烁、窗口缩放问题；代码修正后待用户运行验收。应用根层窗口操作、拖动/缩放、DPI/滚动状态及 Wayland 未验证；Android 窗口约束不变 |
| 2026-09-23 / `6c011cb9` | 修复 root `MaterialApp.builder` 中的 Tooltip Overlay 错误；Linux 启动时清除置顶，并显式恢复 resizable/maximizable/minimizable。增加 `MaterialApp.builder` Overlay 回归用例但未运行 | 依用户要求未重新运行 app、build 或 tests；窗口点击、拖动、resize由用户复验 |
| 2026-09-23 / `4015f879` | expanded 桌面仅保留全局搜索入口；隐藏搜索页局部返回按钮；显式关闭“我的歌单”页面的重复内容标题；窗口栏、历史工具栏、账户底栏、播放条边界使用浅色 `divider` token | 已编译进最新 Linux bundle，尚未启动；由用户检查桌面外观与手机布局未变化 |
| 2026-09-23 / `19c9fb4e` | 移除 expanded 账户底栏的弹窗入口并保留静态用户名/线路展示；把桌面专用的添加音乐库和切换线路入口放入设置页；线路选择 UI 抽到共享组件，手机抽屉继续使用它。账户入口语义测试更新；未运行测试 | Linux release bundle 与 `.deb` 已重新构建，未启动；用户复测账户区、设置入口、添加库后的返回历史与 Android 不重复显示 |
| 2026-09-23 / `88ecf672` | 桌面侧栏移除离线任务状态页及账户/服务器身份底栏；品牌区与主工具栏共用 53 逻辑像素高度；expanded 播放栏取消外侧和安全区留白；更新导航模型与 shell 几何回归用例。仅 Dart 格式化和 diff 空白检查，未运行测试或启动应用 | `4046eb32` Linux bundle 与 `.deb` 已构建但未启动；Android 窄屏抽屉仍保留远端离线任务页；Ubuntu 侧栏对齐、贴边显示和页面布局待用户验收 |
| 2026-09-23 / `27913d3f`，bundle `27913d3f` | `EchoPageRoute` 为每个路由持有独立 `PageStorageBucket`，桌面 forward 重建时复用同一 bucket；增加 detail scroll offset 回退/前进 widget 用例。仅格式化与 diff 空白检查，未运行测试；Linux release build 和 `.deb` 构建成功 | 可滚动页面的偏移现在可跨前进重建保留；搜索输入、页面筛选等 State 字段尚未系统接入同一路由快照，新增用例与 Ubuntu 实测待完成 |
| 2026-09-23 / `859745a6`，bundle `859745a6` | SearchPage 将已提交 query、草稿 query 写入路由 PageStorage；前进重建时恢复输入/结果，并继续未完成的防抖搜索。新增已提交查询与草稿恢复 widget 用例。仅格式化与 diff 空白检查，未运行测试；Linux release build 和 `.deb` 构建成功 | 搜索页历史状态已接入；专辑/歌单详情等其他页面的局部筛选仍需检查是否应该保留；新增用例及 Ubuntu 手动复测待完成 |
| 2026-09-23 / `eaa77d13`，bundle `eaa77d13` | 搜索状态改为输入/提交时即时写入 PageStorage，避免 dispose 阶段查找祖先；AlbumDetailPage 与 PlaylistDetailPage 保存/恢复 SongSortOption。新增两类页面的前进排序恢复 widget 用例。仅格式化与 diff 空白检查，未运行测试；Linux release build 和 `.deb` 构建成功 | 主列表滚动、搜索 query/draft、专辑/歌单歌曲排序已纳入桌面历史恢复；其他页面局部状态、回归用例执行及 Ubuntu 手动复测仍待完成 |
| 2026-09-23 / `52463122`，bundle `52463122` | StarredPage 的当前页签和 ArtistDetailPage 的内容区/热门歌曲展开状态写入 PageStorage；新增收藏夹/歌手页面前进恢复 widget 用例。仅格式化与 diff 空白检查，未运行测试；Linux release build 与 `.deb` 构建成功 | 搜索、详情排序、收藏和歌手页面状态已纳入前进恢复；未覆盖的其他页面状态、回归用例执行及 Ubuntu 手动复测仍待完成 |
| 2026-09-23 / `c9db7c96` | LibraryPage 的歌单排序选项写入/恢复 route-local PageStorage；新增 `desktop forward restores personal playlist sort` widget 回归用例。仅格式化和 diff 空白检查，未运行测试；当前 Linux release bundle 与 `.deb` 已包含该代码 | 曲库歌单排序现可跨桌面前进重建保留；仍待用户手动验收返回/前进及排序结果 |
| 2026-09-23 / `801f2bcc` | DiscoverPage 的随心听“更多歌曲”展开状态写入/恢复 route-local PageStorage；新增 `random song expansion restores after discover route rebuild` widget 用例。仅格式化、diff 检查和 Linux release build，未运行测试；当前 Linux bundle 已包含该代码 | 前进重建音乐流页面时不再把已展开的歌曲列表收回；Ubuntu 手动验收与回归用例运行仍待完成 |
| 2026-09-23 / `c2a9e159` | ExplorePage 将已提交查询、输入草稿写入 route-local PageStorage；远端请求 provider 已自动释放时根据历史 query 重新发起搜索；本地/远端结果列表各自使用稳定 PageStorageKey 恢复滚动位置。新增 query 恢复与远端重发 widget 用例；仅格式化、diff 检查和 Linux release build，未运行测试 | Explore 页前进重建时恢复查询、结果和滚动位置；新增回归与 Ubuntu 手动验收仍待完成 |
| 2026-09-23 / `a9cb6989` | StarredPage 的歌曲、专辑、歌手列表及空状态滚动组件由普通 ValueKey 改为按标签区分的 PageStorageKey，避免同一 route bucket 的多个 Scrollable 使用同一存储标识；扩展收藏夹 route-history widget 回归用例。仅格式化与 diff 空白检查，未运行测试；在全新 Linux build-dir 构建 release 和 `.deb`，并构建签名 Android arm64 APK | 收藏页签各自的滚动位置可跨切换及桌面前进重建保存；Widget 回归和 Ubuntu/Android 真机验收仍待用户执行 |
| 2026-09-23 / `f2828730` | 为 all-songs 的 A-Z `AzListView` 与其他排序模式 `ScrollablePositionedList` 分别设置 PageStorageKey，并为专辑/歌手集合列表设置 route-local keys，避免同一页面的不同 Scrollable 或排序模式共用位置项；更新 scroll-key 断言并扩展排序模式切换回归。仅格式化与 diff 空白检查，未运行测试；Linux/Android release build 成功 | 曲库集合和全部歌曲列表的滚动位置能按列表/排序模式隔离；新增回归及 Ubuntu/Android 实机验收仍待完成 |
| 2026-09-23 / `871f95ed` | SongListPage 在封面预加载范围变化触发局部重建时复用歌曲签名；只在 allSongsProvider 发布新快照或排序模式变化时重新哈希和重建排序。仅格式化与 diff 空白检查，未运行测试；全新 Linux release/.deb 与 Android arm64 APK 构建通过 | 单纯滚动更新只处理可见封面窗口；5000 首曲库的真实 release/profile 帧耗时和内存仍待用户采样 |
| 2026-09-24 / `ce6a8ddd` | 在 `VirtualWindowFrame` 实际 resize overlay 外层用 mock `window_manager` channel 点击最小化、最大化与关闭按钮，确保指针操作能到达自绘标题栏按钮。仅格式化和 diff 检查，未运行用例或启动应用 | 补上了此前只有语义节点、缺少窗口框真实点击路径的回归；用户仍需运行测试并在 Ubuntu 验证拖动、缩放与按钮实际行为 |
| 2026-09-24 / `a6ee5e65` | 将 add-library 模式传入 LoginPage，成功后弹出登录页以返回设置/抽屉发起页；音乐库编辑保存/删除改用最近 Navigator，直接打开且无前页时回音乐流。新增 nested Navigator 与无前页 fallback 回归用例；未运行。Linux `1.1.0+2051` `.deb` 与签名 Android arm64-only APK versionCode `2042` 构建通过 | 设置/抽屉发起的音乐库管理流程不再强制回到音乐流；用例、桌面设置返回、Android 添加库流程仍待手动验收 |
| 2026-09-24 / `d85868f1` | 删除非活动音乐库时保留原活动库，不再意外切换到列表第一项；删除活动库后若替代库激活失败则清理播放器并登出，避免认证指向已删除记录。Linux `1.1.0+2053` `.deb` 与 Android arm64-only versionCode `2044` release 编译通过；未运行测试/analyze 或启动应用 | 桌面和手机共享同一删除策略；删除非活动/活动库及失败恢复仍待用户手动确认 |
| 2026-09-24 / `cab6fe11` | 删除库后返回时清空桌面前进历史，防止前进按钮重建已删除库的编辑页；播放会话清理失败不会阻塞返回，删除/切换失败会显示提示并离开失效页面。Android 没有桌面历史 scope，继续使用原 Navigator 返回。桌面历史及手机 nested-Navigator fallback 回归用例已添加，未运行；Linux `1.1.0+2053` `.deb` 与签名 Android ARM64 versionCode `2051` 编译通过 | Ubuntu/Android 音乐库删除、异常恢复与提示仍待用户手动验收；Windows 暂缓 |
| 2026-09-24 / `1de36904`、`685ea3db` | 为路由前进重建补齐稳定 `PageStorageKey`：设置、搜索、下载、离线任务、专辑/歌单详情、音乐库编辑和歌曲元数据编辑页。Dart formatter 与 `git diff --check` 通过；未运行 Flutter 测试/analyze。随后 Linux `1.1.0+2053` `.deb` 和 Android arm64-only versionCode `2046` release 编译通过 | Android/Linux 共用的页面滚动恢复更新已编译；桌面和手机的返回/前进恢复由用户手动验证 |
| 2026-09-24 / `df403891` | 为桌面导航增加多层详情历史回归定义：连续打开两层详情后按 LIFO 返回，按原顺序前进恢复；从恢复页面发起新导航后检查旧前进项已清空。仅格式化与 `git diff --check`，未运行 Flutter 测试/分析或应用 | 覆盖用户提到的连续页面返回顺序及多级前进栈；回归结果和 Ubuntu 手动导航仍待用户验证 |
