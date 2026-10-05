# 第 6 阶段：事件、教学与手记

## 运行

Godot 4 打开项目根目录的 `project.godot`，按 F6 运行主场景或 F5 运行工程。正常启动进入第 1 天事件；阅读最后一页并确认后开放规划。不要打开 `taptap-stage2/` 或 `taptap-stage3/` 中的旧工程。

前三天检查路线：

1. 第 1 天读完事件，选择老师 → 交谈 → 个人 → 无卡 → 加入今日计划。结束今日行动并确认剩余 AP，夜间阅读结果后进入第 2 天。
2. 第 2 天读完事件，分别选择遗迹残文、不明物件，安排调查。夜间结果正式写入手记。点击右上角手记，查看玛瑞斯的痕迹、已知线索与往日回顾。
3. 第 3 天分页阅读老师的发现与遇害。此后老师不可交谈，尚未调查的已知对象仍可安排。也可留空计划结束一天。
4. 第 4 天没有日期解锁群体行动或自动赠卡；继续沿已开放内容规划。

开发预览仍通过 F3 面板切换，或使用 `-- --preview-targets` 启动。必读事件期间禁止 DEBUG 跳日。预览不会执行正式前三天剧情，其知识、日历、历史与已读记录独立。

## 文件与结构

- `data/events.json`：前三天时序事件与螺螺危机条件事件；简短正文、分页、选项与配置效果。
- `data/targets.json`：老师、遗迹残文、不明物件的正式定义；定义存在不代表玩家已经知道。
- `scripts/event_state.gd`：纯数据的到期判断、一次性事务和已处理事件账本。
- `scripts/ui/event_overlay.gd`：主窗口上的模态浮层。可配置 `image` 资源路径；未提供素材显示明确占位。分页、正文局部滚动、末页选择。
- `scripts/ui/journal_drawer.gd`：右侧手记抽屉，四分类、局部滚动、操作说明、逐项已读标记。
- `scripts/ui/narrative_controller.gd`：将事件、教学提示、手记绑定到原主场景。组件为运行时 Control/Container 子树，不是独立展示场景。
- `scripts/settlement/opening_actions.gd`：有限的开场交谈/调查适配器，接入原八步结算中的行动步骤。
- `scripts/daily_plan.gd`、`scripts/ui/planning_controller.gd`：必读事件规划屏障，覆盖直接模型提交、修改、按钮及次日交接。
- `scripts/target_knowledge.gd`：读取目标配置的行为限制，例如已遇害人物不可交谈。
- `scripts/main.gd`、`scripts/ui/workbench.gd`：挂载组件、手记导航、重开与 DEBUG 屏障。
- `tests/narrative_tests.gd`：本阶段流程与边界测试。原四个测试入口使用显式 `skip_intro` 测试元数据隔离既有测试夹具，手记断言更新为抽屉。

运行时结构：Main → 原 GameScreen / NarrativeController / JournalDrawer / EventOverlay。剧情浮层阻断主界面输入；手记关闭回到同一界面。引导提示放在右侧加入计划按钮附近，一次显示当前步骤。

## 数据接口与一次性处理

事件 `type=date` 按 `day` 到期；`type=condition` 消费已知的 `event_signals[signal]`，并要求指定人物已经认识。不会自行计算风险阈值。外部结算适配层通过完整世界快照提交信号，例如 `child_threat_reported=true`，才能显示危机。正式当前剧情不会凭空触发螺螺危机。

`resolve` 先验证选项与 `resolved_events[event_id]`，再在深拷贝上同时写入效果和事件账本。界面只有末页确认调用事务；翻页、阅读手记、重看操作说明均无效果。旧事件的重复信号、重复回调和重新打开窗口不会再次应用。同一日多个到期事件按配置顺序逐个处理，全部结束才解除规划屏障。

配置效果可以补充 `known_targets`、`journal_entries`，或设置完整世界字段。事件不调用计划扣 AP 接口。思想卡只能来自明确配置的 `acquired_ideas` 效果；目前没有已提供的解锁节点，所以开场不赠卡。群体解锁保持原组织条件。

手记从当前已知快照和结算的公开回顾投影生成，不读取未发现事实。已读标记独立于世界玩法状态，以记录 ID 和正文版本标识；同一正文重复刷新不会再标新。历史回顾不调用结算服务。仍沿用工程的内存状态：未新增磁盘存档，退出应用后不会自动续局。未来存档须同时保存世界中的 `resolved_events` 与手记，才能跨进程保留进度。

## 内容来源与明确边界

前三天仅采用用户给定的开场事实：祭司学徒与老师调查遗迹；玛瑞斯、残文、不明物件；老师发现共同认知影响现实，随后遇害。现有 NPC 文档没有完整开场对白、残文全文、物件用途、凶手、卡牌解锁节点。界面使用简短衔接文字，保留这些未知内容，不公开国王动机。

选择残文不直接得到玛瑞斯的名字；安排调查并完成夜间结算后才写入。物件调查仅记录发现，用途仍待策划定义。老师交谈没有虚构奖励。第 3 天按已给定时序发生，即使玩家前两天不行动也可继续，不强制花完 AP。

危机确认只记消息，不改变为已保护状态。正式隐匿、传播、NPC 自主、群体、反制、完整跨区行动等原未实现规则仍待接入。遇到本适配器范围外的正式行动，沿用挂起等待规则的入口，不用演示文案冒充真实效果。

## 验证

```
godot --headless --path . --script tests/narrative_tests.gd -- --small
godot --headless --path . --script tests/narrative_tests.gd
godot --path . --script tests/narrative_tests.gd -- --small --capture
```

原 `run_tests.gd`、`planning_tests.gd`、`night_tests.gd`、`feedback_tests.gd` 仍可运行。实际图形截图保存到 `previews/stage6-event.png` 与 `previews/stage6-journal.png`。测试奖励和危机信号只在测试内注入，不写入正式配置或存档。
