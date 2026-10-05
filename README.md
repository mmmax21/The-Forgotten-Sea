# 涌现 · 每日行动工作台

## 第 3 阶段：每日行动计划

在原 Godot 4 / GDScript 工程及五区主界面中完成行动配置、思想卡参数、连续行动槽与整份计划校验。没有新增基础行为、剧情公式、传播系统、经济系统或存档系统。

### 运行

用 Godot 4 导入 `project.godot`，按 F5。初始 1920×1080，最小 1280×720，无需 .NET、插件或外部美术。

**默认是正式资料模式**。工程尚没有正式相识、位置和思想获取记录，因此人物、卡牌列表为空，不会自动获得开发样例。

**体验全部计划交互：F3 → 勾选“开发预览（资料、日期、计划独立）” → 关闭 DEBUG。** Mac 部分键盘使用 fn + F3。也可运行：

```sh
godot --path /path/to/taptap -- --preview-targets
```

本机引擎：`/Users/maxlou/Downloads/Godot.app/Contents/MacOS/Godot`。

### 操作

1. 点击人物、地点或已知线索，右侧依次配置行为、规模、可选思想卡；查看说明和已知风险，再加入计划。长详情只在右栏滚动，底部固定。
2. 每天 3 AP；一般行动 1 AP。计划按行动一、二、三排列。底部“修改”进入替换，确认替换前保留原计划；“取消替换”放弃草稿。“删除”释放整项预算和思想占用，↑/↓调整整项顺序。
3. 开发样例中镇区到遗迹为 2 AP，占连续两格；遗迹返回镇区为 3 AP，占全部三格。任一占位格的删除、修改、排序都作用于整个移动。费用仅在预览配置中定义，不代表正式平衡规则。
4. 先安排前往遗迹，再安排与螺螺交谈，会显示移动依赖。将交谈移到移动之前后，整份计划失效并禁止提交；删除前置移动也会重新校验。
5. “海确实存在”“区域边界并非不可跨越”仅在已获得时显示。卡片分别显示当地信念与“可安排 / 已安排 / 今日已使用”，同卡不能重复安排。删除、替换解除计划占用，下一天重置每日限制。
6. AP 用完仍可编辑；未用完点“结束今日行动”会确认一次，取消、关闭、Esc 不提交。提交后整个计划锁定，不能逐项看结果后修改，重复点击不会再次执行。
7. 开发预览在整批测试回执到达后显示“进入下一天”；第 10 天夜间完成后才进入原结算界面。重新开始回第 1 天，重置预算、卡牌使用及预览位置。

计划位置不改变实际地图所在地、人物状态、当地卡牌信念，也不揭示新资料。调查仅对已发现线索开放。群体按独立组织条件解锁，默认禁用并说明已知原因；不按天数解锁。隐匿适用规则尚未配置，保持禁用；隐匿/移动配思想卡尚未定义，不能选择。

### 统一结算入口与范围边界

现有项目只有日期推进与最终结束界面，没有正式行动效果结算器。本阶段提供 `NightSettlement.submit(payload)`、`batch_requested` 与 `complete_batch(request_id, result)` 的整批接口，按请求 ID 防重复；正式提交保持锁定等待完整回执。没有把示例成功、发现、信念变化写成正式规则。

开发预览独立使用 `preview_settlement` 配置，整批模拟移动成功和用卡生命周期，仅在全部处理后更新预览位置；不模拟剧情、信念增量、NPC 合作变化或世界事件。空计划也交给同一入口。正式模式不会调用该模拟器。

回执需匹配 `preview_only`，可含 `consumed_ideas`、`final_location`、`message`。只有回执确认消耗的卡才标成“今日已使用”。调用方必须提供完整批次结果，不能逐条提交部分结果。成功回执只接受一次。

**待确认：移动失败后，后续依赖行动的 AP 处理。** 当前预览将 `movement_outcome` 改为 `failure` 可验证：显示待确认、保持锁定，不退款、不免费重排、不进入下一天。不能把它当作已制定的失败惩罚。正式成功率、思想效果、组织解锁条件、隐匿规则及世界夜间事件均未擅自补写。

正式/预览分别保留日期、计划与知识；已提交计划处理期间禁用模式切换。DEBUG 保留原“后一天”、时间节点与进度，存在计划或已经提交时禁用跳日，避免绕过锁定。正式数据没有持久化存档，本阶段不添加或更改存档文件。

### 文件与结构

主入口仍为 `project.godot` → `scenes/main.tscn`。主场景包含 TopBar、LawBar、Body（LeftPanel / CenterPanel / RightPanel）、BottomPanel，以及独立弹窗、最终 SettlementScreen 和 PlanningController。

| 文件 | 职责 |
| --- | --- |
| `scenes/main.tscn` | 原五区布局，新增规模/思想/说明配置、连续计划槽、确认及夜间面板 |
| `scripts/main.gd` | 日期显示、正式/预览日历隔离、统一夜间与原结算连接 |
| `scripts/game_state.gd` | 原 10 天 / 30 节点边界，增加进入夜间、整天完成入口 |
| `scripts/daily_plan.gd` | 统一计划状态、预算、用卡、替换/删除/排序、全量顺序校验、提交锁 |
| `scripts/night_settlement.gd` | 整批提交和回执去重、独立预览适配、失败规则待确认 |
| `scripts/target_knowledge.gd` | 已知事实过滤、实际/计划距离判定、结算后的已知位置更新 |
| `scripts/ui/workbench.gd` | 原人物/地点选择与资料显示，绑定计划距离，紧凑布局 |
| `scripts/ui/planning_controller.gd` | 配置控件、卡牌状态、计划槽与统一模型绑定 |
| `scripts/ui/plan_slot.gd` | 原子行动及连续占位展示、编辑/删除/排序按钮 |
| `data/ideas.json` | 两张思想的名称及允许搭配行为，没有虚构效果公式 |
| `data/initial_knowledge.json` | 正式空快照，增加已获思想、信念、群体入口与待确认规则字段 |
| `preview_data/workbench.json` | 隔离样例事实、位置、思想、路线成本及测试结算配置 |
| `tests/planning_tests.gd` | 第 3 阶段模型、整批交接及实际点击验收 |
| `tests/run_tests.gd`、`tests/target_tests.gd` | 原日历、知识过滤、人物语义、导航与布局回归 |
| `tests/stage3-validation.txt` | 验收结果记录 |
| `previews/stage3-*.png` | 两种尺寸的真实引擎截图 |

### 正式数据接入

`GameScreen.set_known_world(definitions, snapshot)` 更新正式资料，拒绝 `preview_only` 数据和锁定期间更新；选择行为只能使用当前已经知道的信息。目标 ID、`known_targets.fact_ids`、`known_location` 与 `known_routes` 继续沿用第 2 阶段格式。

新增快照字段：`acquired_ideas`（已获卡 ID）、`idea_beliefs`（按实际地点记录已知信念文字）、`group_access.unlocked / known_reason`（已满足组织条件及可公开原因）、路线 `ap_cost / from_ids`。`planning_rules.descriptions` 可按目标/行为/规模/思想配置说明，并通过 `required_fact_ids` 避免泄露未发现的内容。详情继续区分态度、对海看法、合作范围，不使用统一好感条。

### 验证

```sh
godot --path /path/to/taptap --script tests/planning_tests.gd -- --small
godot --path /path/to/taptap --script tests/planning_tests.gd
godot --path /path/to/taptap --script tests/run_tests.gd -- --small
godot --path /path/to/taptap --script tests/run_tests.gd
```

可增加 `--headless` 检查模型和场景。截图测试使用图形模式。Godot 4.7.2 / macOS / Compatibility 下，两种尺寸各通过 **85 项计划检查 + 328 项回归检查，0 失败**。覆盖超预算、重复用卡、替换和删除释放、连续槽、计划距离、顺序失效、整批锁、失败待确认、跨日卡牌重置、10 天结束、重开及鼠标交互。已查看实际布局截图。

尚未验证其他操作系统、其他 Godot 版本及未来正式结算器接入；无美术素材，仍使用色块、文字头像和场景占位。中文依赖系统中文字体。

### 版本回退

- `v0.1`：原基础回合界面，保留不变。
- `4290e8c`：第 1 阶段；`0045f1b`：第 2 阶段。
- 第 3 阶段在 `codex/daily-planning` 分支保存独立提交，项目包为 `taptap-stage3.zip`。
- 旧项目包 `taptap-v0.1.zip`、`taptap-stage1.zip`、`taptap-stage2.zip` 保留。
- 可以要求“恢复到第 2 阶段，并保留现在的版本”。不要直接覆盖唯一工程副本。
