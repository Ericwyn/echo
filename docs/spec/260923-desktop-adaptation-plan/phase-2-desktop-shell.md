# P2：桌面浏览框架与完整播放条

[返回 spec](README.md) · [总体设计](desktop-adaptation-plan.md) · [验收](acceptance.md)

状态：首轮实现中。按用户指定分组的宽屏侧栏、统一字号、账户弹窗、与播放条等高的账户底栏、持久桌面播放条和保留浏览分支的播放器工作区已落代码。桌面现使用独立 Navigator：侧栏主目的地替换当前主页面，内容详情共享同一返回栈，根页面为音乐流；Android 继续使用 `StatefulShellRoute`。新增自动用例覆盖主目的地连续切换、详情逐层返回及根页面稳定。前进历史/可视化工具栏、Ubuntu 实际页面状态恢复、不同尺寸/DPI 尚待完成。前置：P1 共享接口已建立；Android 全量回归尚待 P5。后续：P3 在稳定 shell 内切换歌词/队列；P4 接入系统命令。

## 目标与边界

完成“一个资料库侧栏 + 浏览内容 + 常驻播放条”，让歌曲/专辑/艺术家、歌单、设置和下载都能在桌面连贯访问。复用数据 provider 与页面内容，新增桌面编排；保持登录/重新认证的独立路由。

## 实施步骤

1. 定义 layout policy：结构依据当前逻辑尺寸，输入方式决定鼠标/触控动作，平台能力决定媒体和托盘。保留现有 600/840 断点作为基础；为桌面 shell 使用独立组合策略，避免修改全局 tokens 使手机页面同时变形。
2. 手机路由继续由 `lib/app.dart` 的 `StatefulShellRoute` 管理独立 Tab 栈；桌面壳拥有根为音乐流的 Navigator。歌曲、专辑、艺术家、收藏、歌单详情、下载和设置复用已有页面，不切换到 Android 的 catalog/library branch 后再 push 子页。
3. 确保桌面常规子页使用统一 Navigator；认证留 root。桌面侧栏主目的地替换当前主页面，内容打开的详情正常入栈；Navigator observer 将当前目的地映射到侧栏选中项，pop 后还原父页面及所属入口。
4. 返回/前进基于一份目的地历史状态。若现有 GoRouter 栈不能直接表达前进，用统一的导航协调层保存 cursor 与 route state；页面不分别维护第二套互相矛盾的栈。无可用历史时按钮禁用，切库清理无效目标。
5. 宽屏整合账号、资料库导航与设置，解除桌面 `Scaffold.drawer`，菜单按钮只折叠主导航。账号/线路使用有锚点的菜单或弹窗；图标栏提供全部入口与 tooltip。手机继续使用原主导航与抽屉 presenter。
6. 歌单区域懒加载/独立滚动，支持后续置顶状态；首轮不为侧栏请求全部歌曲。无歌单、加载失败、离线和切库状态明确可见。
7. 首页复用最近播放与随心听数据，把宽横卡组合为有限尺寸封面网格/专辑架。超出范围使用明确翻页/查看全部；内容列数按 shell 内实际宽度计算，不只读整窗 MediaQuery。
8. 新增 DesktopPlayerBar，订阅 P1 快照与 commands。左侧歌曲，中间 transport 与进度，右侧 userVolume/mute、歌词和队列；空状态禁用不支持动作，暂停时保留控件。
9. 底栏置于稳定 shell 生命周期中，导航、页面滚动和普通模态变化不重建它。P3 完成前可继续打开原完整播放器/队列，明确是过渡版本；随后只替换入口与 presenter。
10. 键盘焦点、错误提示、长标题和大字体与界面一起完成。宽度不足优先折叠次要信息，低频操作进入更多菜单，不能把播放/切歌/进度藏到另一页。

## 路由与状态约束

| 状态 | 所属层 | 必须保持的行为 |
| --- | --- | --- |
| 当前库/鉴权 | 现有 auth/library providers | 切库清理旧库导航选择，播放处理沿用既有策略 |
| destination/历史 cursor | 手机 StatefulShellRoute；桌面统一 Navigator/导航策略 | 返回/前进与侧栏高亮一致，刷新/重排不追加重复历史 |
| 搜索、筛选、滚动 | 页面/分支 | 详情返回及展开/收起播放工作区后恢复 |
| 当前曲目/队列/进度 | PlayerNotifier/P1 | 与可见页面生命周期无关 |
| 用户密度/音量 | 设置与 P1 | 不由临时窗口尺寸重设 |

## 主要文件

`lib/app.dart`、`lib/providers/navigation_provider.dart`、`lib/widgets/main_scaffold.dart`、`lib/widgets/echo_app_shell/echo_app_shell.dart`、`echo_shell_navigation.dart`、`lib/widgets/app_drawer.dart`、`lib/features/discover/pages/discover_page.dart`、`lib/features/library/pages/catalog_page.dart` 及其子页面。

复用 `EchoSongRow`、封面组件和设计 tokens；仅为桌面增加密度/组合参数，不复制网络请求和数据排序实现。

## 验证与完成条件

- A01：宽窗、图标栏与窗口连续缩放只出现一套主导航；账号/设置/下载均可到达。
- A02：从歌曲列表→专辑详情→设置→返回/前进，底栏和播放连续，页面状态正确恢复；不存在同一详情被无意 push 两次。
- A03/A04：底栏所有动作调用同一命令入口，加载/失败/无歌曲状态可理解，音量保持。
- A11：800×600、1280×720、1920×1080，以及 200% 字体/缩放组合无关键按钮遮挡；窗口更窄时有可操作的回退。
- 复用并扩展 `test/widgets/echo_app_shell/echo_app_shell_test.dart`、`test/features/library/library_shell_obstruction_test.dart`，新增桌面导航历史和底栏行为测试；复查手机 drawer/MiniPlayer 和系统返回流程。
- 真实 Ubuntu release 中记录首页、资料库、设置与底栏截图。widget 通过不能代替桌面字体/DPI 检查。

## 实施记录

| 日期 / 提交 | 实际修改与检查 | 结果 / 遗留 |
| --- | --- | --- |
| 2026-09-23 / `f6100044` | 宽屏关闭 `Scaffold.drawer`；侧栏采用“发现/资料库/个人收藏/管理”分组，删除重复顶层音乐流/我的/曲库入口，统一字号并加大侧栏文字；账户 footer 与 96px 播放条共用高度 token；补充分组、无重复入口和高度对齐测试。全量 Flutter 431 项测试、项目级 analyze 和 Linux release 构建通过 | 用户此前确认基本桌面界面，最新侧栏/底栏尚需复验；还无全局前进历史按钮，窗口尺寸/DPI与账户入口需实机验证；阶段仍进行中 |
| 2026-09-23 / `224bb002` | 桌面改用独立 Navigator，音乐流为根；侧栏切换主目的地时替换页面，详情沿同一栈压入；Starred/歌曲/专辑从搜索或音乐流打开时沿用正确可见分支；“我的歌单”隐藏重复收藏区；设置编辑库页面改走所在导航层。新增主目的地切换、详情回退和音乐流根页面测试。全量 433 项 Flutter 测试、项目级 analyze 通过；Linux release bundle 编译通过（临时 PATH shim 提供系统 `ld`，未修改系统文件） | 桌面/手机路由已分开首轮落地；前进历史/工具栏、Ubuntu 实际滚动状态恢复与不同尺寸/DPI实机验证仍待完成；阶段仍进行中 |
