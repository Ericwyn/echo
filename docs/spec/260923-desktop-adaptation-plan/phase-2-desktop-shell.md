# P2：桌面浏览框架与完整播放条

[返回 spec](README.md) · [总体设计](desktop-adaptation-plan.md) · [验收](acceptance.md)

状态：首轮实现中。按用户指定分组的宽屏侧栏、统一字号、账户弹窗、与播放条等高的账户底栏、持久桌面播放条和保留浏览分支的播放器工作区已落代码；用户还需复验最新侧栏截图。Ubuntu 不同尺寸、路线历史前进与完整 DPI 验收尚待验证。前置：P1 共享接口已建立；Android 全量回归尚待 P5。后续：P3 在稳定 shell 内切换歌词/队列；P4 接入系统命令。

## 目标与边界

完成“一个资料库侧栏 + 浏览内容 + 常驻播放条”，让歌曲/专辑/艺术家、歌单、设置和下载都能在桌面连贯访问。复用数据 provider 与页面内容，新增桌面编排；保持登录/重新认证的独立路由。

## 实施步骤

1. 定义 layout policy：结构依据当前逻辑尺寸，输入方式决定鼠标/触控动作，平台能力决定媒体和托盘。保留现有 600/840 断点作为基础；为桌面 shell 使用独立组合策略，避免修改全局 tokens 使手机页面同时变形。
2. 先整理 `lib/app.dart` 的路由目标：当前仅 home/explore/library/catalog 四个主分支，部分子页用直接 `Navigator.push`。为歌曲、专辑、艺术家、收藏、歌单详情、下载和设置补稳定 destination ID 与可定位状态，复用已有页面。
3. 确保桌面常规子页使用 shell 所在导航层；认证留 root。明确选中侧栏项与当前子路由的映射，浏览详情时所属资料库入口仍高亮，返回恢复原筛选和位置。
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
| destination/历史 cursor | 导航协调层 | 返回/前进与侧栏高亮一致，刷新/重排不追加重复历史 |
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
| 2026-09-23 / 桌面导航复核 | 宽屏关闭 `Scaffold.drawer`；侧栏采用“发现/资料库/个人收藏/管理”分组，删除重复顶层音乐流/我的/曲库入口，统一字号并加大侧栏文字；账户 footer 与 96px 播放条共用高度 token；补充分组、无重复入口和高度对齐测试。全量 Flutter 431 项测试、项目级 analyze 和 Linux release 构建通过 | 用户此前确认基本桌面界面，最新侧栏/底栏尚需复验；还无全局前进历史按钮，窗口尺寸/DPI与账户入口需实机验证；阶段仍进行中 |
