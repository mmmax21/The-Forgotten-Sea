# 夜间结算适配协议（第 4 阶段）

主入口仍是 `PlanningController`。DailyPlan 在发出 submitted 前锁定预算与整份计划，复用 `GameState.begin_night()`；只有整个批次完成且次日事件完成后才调用原日期控制器的 `finish_day()`。不允许 UI 分页触发这些方法。

## 固定顺序

`NightSettlement.STEPS` 按如下 ID 顺序执行，不允许适配器重新排列：

1. `actions` 玩家已锁定行动。
2. `direct` 直接受影响 NPC/群体。
3. `spread` NPC、群体内部与跨地区传播。
4. `ideas` 思想状态/意识场。
5. `reality` 现实阈值与规则。
6. `offscreen` 玩家不在场地区。
7. `kingdom` 王国反制与警戒。
8. `tomorrow` 次日事件登记。

通过 `set_adapter(stage_id, callable, preview = false)` 注册现有系统适配器。正式/预览注册表分离，测试只在 tests/night_tests.gd 中注入，不在正常启动时注册虚构规则。

提交签名保持 `submit(payload, preview_config = {}, world = {})`。请求包含唯一 request_id、day、preview_only、entries、initial_location、budget。提交立即去重并登记，后续延迟执行；一条 request_id 一生只完成一次。正式行动无适配器时暂停；其他缺席系统为明确 unimplemented。空行动列表不短路世界更新。

## 适配器输入与返回

输入是深拷贝 `{ request, world, next_events }`。world 是本批的暂存快照，上一步的输出成为下一步输入，不是实时世界对象。

返回 Dictionary：

- `status`: `complete` / `unimplemented` / `pending`。
- `world`: 可选完整快照，必须保持 preview_only 来源；不能省略原已知资料。
- `records`: 结构化结果列表，仅在整批完成后投影到回顾。
- `consumed_ideas`: 确实主动使用的思想 ID，只能属于锁定计划，不能重复。
- `next_events`: 需要登记到下一天的后台事件，可包含私有条件，不公开给回顾。
- `message`: 挂起时可公开的接口说明，不能放入秘密、隐藏数值或尚未知晓的剧情原因。

适配器必须只计算并返回数据，不能直接改写 GameState、Knowledge、存档、UI 或外部系统。当前实现是单进程内的暂存提交，不提供进程崩溃恢复或外部写操作事务。仅用固定公式/硬编码故事来“填满回顾”违反此接口意图。

`unimplemented` 不能附带 world、records、next_events 或用卡效果。`pending` 不提交部分数据；已完成步骤保留在暂存区。规则补齐后显式调用 `resume(request_id)`，从挂起步骤继续；回顾页没有“重新计算”按钮。

外部已有整批控制器可调用 `complete_batch`，但必须提交固定八步的有序 steps（每项 id/status）、world、records、consumed_ideas、next_events、preview_only。旧式仅有 message 的演示回执不再视为完成。流水线运行中、已完成、来源不匹配的回执被拒绝。

## 回顾可见性

记录格式示例结构（字段含义，非运行剧情）：

```gdscript
{
    "category": "actions", # actions / people / world / kingdom
    "action_index": 0,     # actions 必须指向锁定计划中的索引
    "visibility": "known",
    "title": "已公开的目标与行为标题",
    "happened": {"text": "本次确实发生且玩家知道的事", "visibility": "known"},
    "reason": {
        "text": "玩家能够知道的原因",
        "visibility": "known",
        "requires": [{"target_id": "目标ID", "fact_id": "必须已发现的事实ID"}]
    },
    "direction": {"text": "这次确实新增或仍可采取的已知方向", "visibility": "known"}
}
```

默认可见性为 hidden。整条记录与 happened 都满足公开条件才显示；reason / direction 分别过滤，未知原因不能因为结果已知而提前公开。requires 对照本批最终已知事实快照；title 必须是适配器明确认定可公开的标题，不承载秘密。任意额外分数、NPC 私有条件、内部状态被白名单投影去掉。

你的行动按 action_index 排列，不按适配器记录的发出顺序排列；没有公开结果的已安排行动只显示“没有可公开记录，不能据此推断成败”。其他栏没有公开记录时显示空状态，不伪造“保持沉默”等自主反应。

`receipt()`、`history()` 返回公开冻结结果的深拷贝。`committed_world()` 是控制器专用状态接口，回顾视图不能调用。历史只在当前运行内保存，按 formal/preview 分开；重开清除当前模式历史并恢复该局首次提交前的世界快照。

## 次日事件

点击进入第 X 天后，`begin_next_day(request_id)` 登记一次，保持当前夜间计划锁定，调用通过 `set_morning_adapter(callable, preview)` 注册的处理器。

输入 `{ day, world, events, preview_only }`；day 已是目标新日。返回 `{ status: "complete", world: 完整处理后快照 }` 才能应用快照并开放新日。存在事件却没有处理器、或处理器未完成时，显示必须事件待处理，日期仍停在夜间，不能退款/重排。接好规则后通过 `resume_morning(request_id)` 恢复。

没有已登记事件且没有处理器时执行空转换，不虚构次日事件。第 10 天完成后复用最终结算，不进入第 11 天。未来由事件处理器把已经传达给玩家的报告/发现写入已知快照；不能直接把后台秘密事件列表显示为全知日志。
