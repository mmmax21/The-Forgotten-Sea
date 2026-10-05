# 第 6 阶段：剧情事件、前三天引导与手记

打开根目录 `project.godot`，在 Godot 4 中按 F5。正常启动从第 1 天剧情开始；读完后选择老师安排交谈。第 2 天可调查残文和物件，第 3 天阅读老师的剧情。手记从右上角打开，重看说明不会重放剧情。

完整的修改文件、运行路线、数据接口与未实现边界见 [第 6 阶段说明](docs/events_journal.md)。正式开场目前仅接入老师交流及两个遗迹对象的调查，其他未定义的正式行动仍等待适配器；没有新增磁盘存档或思想卡解锁规则。

以下保留前阶段说明，其“无正式开场内容”描述已被上述有限开场适配器更新。

# 涌现 · 每日行动工作台

## 第 5 阶段：思想、法则与场景反馈

沿用 Godot 4 / GDScript 原工程、每日计划和八步夜间结算。本阶段把三张法则牌、思想卡纹样和分层石渠绑定到实际地区快照。没有新增数值阈值、基础行为、固定日期剧情或存档系统。

三条法则分别读取状态，以完整图案/裂纹及明确文字区分；思想卡以残缺、浮现、完整纹样表达当地信念，每日使用状态单独显示。石渠分为干涸、异常征兆、浅水、涨退，支持受压制后回退。变化提示点击只查看目标，不能免费调查。

### 第 5 阶段开发验收

F5 运行 → F3 打开 DEBUG → 勾选开发预览 → 选择测试状态 → 点击“应用测试快照” → 关闭 DEBUG。可依次查看普通、异常征兆、部分进展、较强共识、受压制回退。只有未排计划、未提交时可应用；测试执行一次独立结算，不推进日期、不花 AP、不写正式资料。

五个快照在 `preview_data/feedback_states.json`，只作开发测试。正式状态需要既有规则通过完整结算快照提供；未接入时显示未知，不把开发样例当成正式剧情。首次加载没有完整大海，涨退也仅表现为石渠内的水线。

通行仍以 `known_routes` 的许可和出发地区为准，裂纹不会打开路线。调查要求已发现线索且当前开放；背景出现异常不自动开放调查。回退后保留已知线索文字，但可关闭继续调查条件。

### 第 5 阶段文件

| 文件 | 改动 |
| --- | --- |
| `data/feedback_styles.json` | 离散状态到文字/图案的映射，不含玩法阈值 |
| `preview_data/workbench.json`、`preview_data/feedback_states.json` | 预览地区状态、石渠与独立测试快照 |
| `scripts/world_feedback.gd` | 当前地区的只读反馈投影与变化比较 |
| `scripts/ui/law_card.gd`、`idea_card.gd` | 独立法则裂纹、塔罗式思想纹样与文字状态 |
| `scripts/ui/canal_scene.gd`、`canal_layer.gd` | 可逆场景层、已开放线索标记、可定位提示 |
| `scripts/ui/feedback_controller.gd` | 结算提交监听、提示去重、隔离 DEBUG 测试入口 |
| `scripts/ui/workbench.gd`、`planning_controller.gd` | 状态同步、卡牌绑定与紧凑布局 |
| `scripts/target_knowledge.gd` | 提交信号、调查开放条件及实际出发地检查 |
| `scenes/main.tscn` | 沿用主场景，接入卡牌和场景组件、DEBUG 控件 |
| `tests/feedback_tests.gd`、`tests/stage5-validation.txt` | 本阶段验收与记录 |
| `tests/night_tests.gd` | 截图改为显式 `--capture`，避免覆盖旧版本截图 |

数据格式、去重与规则边界详见 [世界反馈接入说明](docs/world_feedback.md)。未加入声音或首次发现动画，反馈使用静态可逆图案和只触发一次的变化提示。

## 打开与运行

用 Godot 4 导入本目录的 `project.godot`，按 F5。初始 1920×1080，最小 1280×720，无需 .NET、插件或外部美术。中文依赖系统中文字体。

**默认使用正式资料**。工程尚无正式相识、发现、位置和思想获取记录，因此正式人物及卡牌列表为空，不自动获得演示数据。

**体验流程：F5 → F3 → 勾选开发预览 → 关闭 DEBUG。** Mac 部分键盘使用 fn + F3。

```sh
godot --path /path/to/taptap -- --preview-targets
```

本机引擎位于 `/Users/maxlou/Downloads/Godot.app/Contents/MacOS/Godot`。

## 计划与夜间操作

1. 点击已知人物、地点或线索，右侧选择行为、个人/群体规模、可选思想卡，阅读已知风险后加入计划。
2. 每日 3 AP；修改、删除、↑/↓排序后校验整个计划。多 AP 移动占连续槽，不能拆分。预览镇区到遗迹为 2 AP，返回为 3 AP；费用不作为正式规则。
3. 思想卡分别显示当地信念和“可安排 / 已安排 / 今日已使用”。同卡一天最多使用一次，提交前删除/替换会释放占用。群体默认未解锁；隐匿规则和隐匿/移动配思想尚未定义，入口明确禁用。
4. 结束今日行动时，AP 未用完会确认。取消、关闭、Esc 不提交。提交后锁定整份计划；快速连点只处理一次，不逐项揭晓后再允许改计划。
5. 整批结束后，中央显示“你的行动 / 人们的后续行动 / 世界的变化 / 王国的回应”。点击栏目、上一条/下一条或滚动只读取本次结果，不推进时间、不再结算。
6. “接口状态”列出固定八步的本次状态。未接入系统明确说明，不填入虚构反应。
7. 点击“进入第 X 天”才开始次日处理。必须事件完成后才更新日期并开放规划；缺少事件处理器时保持锁定。第 10 天结束后复用原最终结算，不出现第 11 天。
8. 点击手记可按天回看当前一局的历史，历史没有进入下一天按钮。收起后可通过底部“查看夜间结算”重新打开当前回顾。重开清空本局历史与计划，恢复本局初始世界。

参考验证路线：预览中先移动至遗迹，再安排与螺螺交谈。提交后移动只改变预览位置，交谈结果明确显示“尚未执行正式判定”。其他三个栏目没有实际公开结果时为空，不每天固定让 NPC 传播或联系别人。

## 已接入与未实现的边界

固定结算顺序：玩家行动 → 直接 NPC/群体更新 → NPC/群体/跨地区传播 → 思想和意识场 → 现实阈值/规则 → 不在场地区 → 王国反制/警戒 → 登记次日事件。

当前工程没有正式行动效果、NPC 自主、传播、意识场、现实阈值、异地更新、反制或次日事件规则。它们具有清楚的适配接口，但没有被本阶段擅自补成正式玩法。正式非空计划等待行动判定适配器；正式空计划仍走完八步接口，但不会凭空产生世界事件。

开发预览只沿用原有移动与用卡生命周期测试，始终标注来源。正式与预览分别保留知识、日期、计划、世界和历史。DEBUG 中的旧时间节点与跳日测试仍保留，有计划或已锁定时不能绕过限制。

所有状态先暂存，整批完成才应用。回顾内容来自结构化结果，只投影玩家已知字段；未知原因、隐藏分数、NPC 私有条件及后台事件不传给界面，也不写入公开历史。手记记录冻结副本，后续发现不会自动泄露到旧回顾。

**待确认：移动失败后，依赖行动的 AP 处理。** 预览配置 `movement_outcome: failure` 会挂起批次，不提交部分状态、不退款、不开放重排。次日必须事件未完成也不开放规划。补齐规则后的恢复不会重跑已完成步骤。

历史目前保存在内存，退出程序不持久保存。没有新增存档、完整地图、立绘、经济系统或复杂动画。

## 继续沿用的结算结构

| 文件 | 职责 |
| --- | --- |
| `scenes/main.tscn` | 原主场景；以中央 NightReview 替换旧夜间弹窗 |
| `scripts/main.gd` | 保留原日期、最终结算和重开；调整回顾期间导航 |
| `scripts/night_settlement.gd` | 八步流水线、整批去重、公开结果投影、历史、次日处理 |
| `scripts/settlement/preview_actions.gd` | 分离原开发预览移动/用卡逻辑，不提供正式判定 |
| `scripts/ui/night_review.gd` | 四栏目、逐条阅读、历史选天；不计算游戏状态 |
| `scripts/ui/planning_controller.gd` | 计划提交、完整快照应用、回顾和次日事件衔接 |
| `scripts/target_knowledge.gd` | 增加同来源完整结算快照的应用入口 |
| `scripts/ui/workbench.gd` | 手记历史入口、已知警戒显示 |
| `tests/night_tests.gd` | 夜间顺序、去重、隐私、历史、次日处理与 UI 验收；模拟效果仅在测试中注入 |
| `tests/planning_tests.gd` | 原计划验收，等待新的次日处理完成 |
| `tests/stage4-validation.txt` | 本阶段验收记录 |
| `previews/stage4-*.png` | 两种尺寸真实引擎截图；preview 是默认预览，review 使用独立测试规则 |

继续复用 `scripts/game_state.gd` 的 10 天边界、`scripts/daily_plan.gd` 的统一预算和卡牌状态，以及 `scripts/ui/plan_slot.gd` 的整项编辑。正式及预览数据配置沿用第 3 阶段。

具体接入字段与事务约束见 [结算适配协议](docs/night_settlement.md)。`GameScreen.set_known_world()` 仍接收正式目标目录与已知快照，拒绝预览数据与锁定期间的外部更新。人物态度、对海的看法和合作范围保持独立。

## 验证

```sh
godot --path /path/to/taptap --script tests/feedback_tests.gd -- --small
godot --path /path/to/taptap --script tests/feedback_tests.gd
godot --path /path/to/taptap --script tests/night_tests.gd -- --small
godot --path /path/to/taptap --script tests/night_tests.gd
godot --path /path/to/taptap --script tests/planning_tests.gd -- --small
godot --path /path/to/taptap --script tests/planning_tests.gd
godot --path /path/to/taptap --script tests/run_tests.gd -- --small
godot --path /path/to/taptap --script tests/run_tests.gd
```

可增加 `--headless` 做无图形检查。Godot 4.7.2 / macOS / Compatibility 下，两种尺寸各通过 60 项反馈检查、65 项夜间检查、85 项计划检查和 328 项原功能检查，0 失败。反馈图形测试生成 `previews/stage5-*.png`；旧夜间测试截图需显式添加 `--capture`。

覆盖固定执行顺序、空计划仍更新、重复点击、只读分页/历史、未知原因过滤、次日事件屏障、挂起恢复、正式/预览隔离，以及原来的预算、卡牌、移动依赖、10 天结束、重开、导航、缩放和跳日确认。

尚未验证其他操作系统、其他引擎版本、未来正式规则和存档系统接入。

## 版本

- `v0.1`：原基础回合界面。
- `4290e8c`：第 1 阶段；`0045f1b`：第 2 阶段；`3cb0dde`：第 3 阶段。
- 第 4 阶段为 `abf10aa`，项目包 `taptap-stage4.zip` 保留。第 5 阶段在 `codex/world-feedback` 分支，完整项目包为 `taptap-stage5.zip`。
- 前三阶段与 v0.1 的旧项目包保留，解压出来的旧工程不改动。
- 可以要求“恢复到第 3 阶段，同时保留当前版本”，避免覆盖唯一副本。
