# 界面组件化清单

只列玩家能看见、适合抽成独立场景或控件的块。`game_state.gd`、`daily_plan.gd`、`event_state.gd`、`target_knowledge.gd`、`night_settlement.gd` 和 `data/` 里的 JSON 继续当数据层，不包成场景。

抽组件时保持现在的分工：场景负责外观，脚本对外只留 `configure` / `refresh` / `open` 和信号。拼条目、读存档、扣 AP 仍留在现在的控制器里。

## 清单

| 组件 | 现况 | 修改建议 |
| --- | --- | --- |
| 项目主题 | 按钮、面板、字体色都是 `scenes/main.tscn` 里的 `StyleBoxFlat`。弹窗各自再套同一份 Theme。 | 挪到 `theme/game_theme.tres`，在项目设置里设为默认主题。之后拆出的场景才能自动沿用深灰、米白、海青色。 |
| 手记抽屉 | 脚本 `scripts/ui/journal_drawer.gd`。运行时由 `scripts/ui/narrative_controller.gd` 创建，挂到 `Main/JournalDrawer`。编辑器里看不到。入口是 `Main/GameScreen/Layout/TopBar/NotesButton`。条目在 `refresh_journal()` 里从世界快照拼好再送进去。 | 做成 `scenes/ui/journal_drawer.tscn`。脚本留下 `refresh(entries)`、`open()`、`unread()`。叙事控制器改为实例化场景，不要让抽屉自己读 JSON。 |
| 确认弹窗 | 两份原生 `ConfirmationDialog`，都写在 `main.tscn`：`Main/SubmitConfirm`（结束今日行动，逻辑在 `planning_controller.gd`）、`DebugPanel/SkipDialog`（跳过当天，逻辑在 `main.gd`）。 | 收成一个 `scenes/ui/confirm_dialog.tscn`，提供 `ask(title, text)` 和 `confirmed`。两处调用改接这一个，文案仍由调用方传入。 |
| 信息弹窗 | `Main/InfoDialog`（`AcceptDialog`）同时被菜单、思想卡说明、法则说明、空手记、空历史复用。手记占位文案在 `workbench.gd` 的 `_show_notes()`，正式手记打开时不会走到这里。 | 单独做只读的 `scenes/ui/message_dialog.tscn`（标题 + 正文 + 返回）。和确认弹窗分开，避免一处改样式影响到全部提示。 |
| 事件浮层 | 脚本 `scripts/ui/event_overlay.gd`。运行时挂到 `Main/EventOverlay`，全屏遮罩、分页、末页选项都在 `_ready()` 里用代码生成。已留 `TextureRect`，`data/events.json` 里的立绘仍是文字占位。 | 做成 `scenes/ui/event_overlay.tscn`。脚本留下 `show_event(value)` 和 `chosen` 信号。换立绘只改场景里的 `TextureRect`，不改翻页逻辑。 |
| 主菜单 | `scripts/main.gd` 的 `_build_menu()` 在运行时生成 `Main/MainMenu`：标题和「开始新一局」「返回本局总结」。 | 做成 `scenes/ui/main_menu.tscn`。`main.gd` 只接两个按钮信号，继续负责重开和回到总结。 |
| 思想卡 | 脚本 `scripts/ui/idea_card.gd`（`Button` + `_draw` 纹样）。`planning_controller.gd` 按已获得的卡在底部动态生成，没有场景。 | 做成 `scenes/ui/idea_card.tscn`，保留 `configure(name, belief, usage)`。纹样以后可换成贴图，调用方不用改。 |
| 法则条 | `main.tscn` 里写死 `Law1`、`Law2`、`Law3` 三个按钮，脚本都是 `scripts/ui/law_card.gd`，纹样同样用 `_draw`。点开详情走 `InfoDialog`。 | 抽一个 `scenes/ui/law_card.tscn`，顶栏实例化三次。详情改走信息弹窗。 |
| 计划槽 | `ActionSlot1`–`ActionSlot3` 是 `main.tscn` 里的空 `PanelContainer`，脚本 `scripts/ui/plan_slot.gd` 在 `_ready()` 里再生成标题、摘要和修改/删除/排序按钮。 | 把槽内部布局放进 `scenes/ui/plan_slot.tscn`。三个槽改为该场景的实例。对外仍用 `display(...)` 和现有的 `edit_requested` / `remove_requested` / `reorder_requested`。 |
| 人物条目 | `workbench.gd` 的 `_add_person_button()` 每次用代码拼按钮、文字头像、名字和状态。头像来自 `data/targets.json` 的单字，不是图片。 | 做成 `scenes/ui/person_row.tscn`，提供 `configure(entry)` 和按下信号。左侧列表只负责清空再实例化。头像节点留成 `TextureRect`，现在仍可显示文字。 |
| 地点与调查标记 | 同一文件的 `_add_target_button()` 生成中央地点格和线索标记，结构和人物条目不同，但是另一套临时按钮。 | 做成较小的 `scenes/ui/target_chip.tscn`。和人物条目分开，避免一个控件同时扛头像和地块两种布局。 |
| 夜间回顾 | 节点 `GameScreen/.../CenterPanel/NightReview` 已在主场景里，脚本 `scripts/ui/night_review.gd`。栏目、翻页、历史下拉仍在 `_ready()` 里生成。它是只读视图，不写游戏状态。 | 把这些控件摆进 `NightReview` 节点下，或单独 `scenes/ui/night_review.tscn` 再嵌回中央面板。脚本只留 `show_report()` 和翻页。 |
| 十日总结 | `Main/SettlementScreen` 在场景里只有标题、说明和「重新开始」。分栏、正文滚动和底部按钮由 `scripts/ui/demo_summary_screen.gd` 运行时补上。正文数据在 `scripts/demo_summary.gd`。 | 把分栏和底栏补进该节点。`demo_summary.gd` 继续只产出只读快照，不并入手记抽屉。 |
| 中央场景 | `SceneCanvas` 挂 `scripts/ui/canal_scene.gd`，图层在 `scripts/ui/canal_layer.gd` 里绘制。没有正式背景图。 | 等有地砖或背景再抽 `scenes/ui/canal_scene.tscn`。在此之前保持脚本绘制，避免空场景来回搬。 |
| 教学提示 | `narrative_controller.gd` 在「加入今日计划」按钮旁动态插入一个 `Label`，只在前三天显示下一步。 | 在右侧面板里放一个固定 `HintLabel`，脚本只改 `text` 和 `visible`。不要再 `move_child` 插进按钮父节点。 |
| 顶栏 | `GameScreen/Layout/TopBar` 已在主场景：天数、阶段、地区、警戒、手记、菜单。天数由 `main.gd` 刷新，地区由工作台刷新。 | 先不动。主题和手记拆完之后，如果顶栏还要加图标，再收成 `status_bar.gd`，用一次快照刷新全部标签。 |
| 行动编排区 | 右侧整栏（目标详情、行为、规模、思想卡、费用、加入计划）都铺在 `main.tscn`，逻辑分在 `workbench.gd` 和 `planning_controller.gd`。 | 先拆思想卡、计划槽和确认弹窗。整栏先留在主场景，避免把选目标、校验和提交一起搬进一个大场景。 |
| 调试面板 | `Main/DebugPanel` 已在场景中，含预览开关、时间推进和 `SkipDialog`。只给开发用。 | 不做成玩家组件。跳过确认改接共用确认弹窗即可，面板本身留在主场景。 |

## 建议顺序

1. 主题资源。后面每个场景都靠它统一外观。
2. 信息弹窗和确认弹窗。先把 `InfoDialog` 的多种用途拆开。
3. 手记场景、事件浮层场景。这两块完全是运行时代码树，编辑器里无法直接改。
4. 人物条目、思想卡、法则卡、计划槽。都是重复实例，抽一次就能换头像和卡面。
5. 夜间回顾和十日总结。把已有节点里用代码补出来的布局摆回场景。
6. 主菜单、教学提示。改动面小，可以跟美术一起做。
7. 中央场景。有背景或地砖之后再抽。

手记、事件浮层、夜间回顾和总结都有「分类 + 滚动正文」，先各自成为场景。等四块的按钮和滚动区域真的长得一样，再考虑共用一个分页容器。现在合成一个通用阅读器，会把已读标记、末页选项和历史下拉缠在一起。
