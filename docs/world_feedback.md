# 世界反馈接入（第 5 阶段）

表现层不制定阈值。正式规则应在 NightSettlement 的适配器中返回完整 world 快照，流水线完成后由 PlanningController 调用 Knowledge.apply_settled_snapshot(snapshot, receipt_id)。次日事件使用 morning:receipt_id。只有带唯一提交 ID 的真实提交触发变化提示；读取、切目标、翻页和历史回看不触发。

## 输入

- `current_location_id`：实际所在地区。所有反馈只读这个字段，不读计划位置。
- `idea_beliefs[region_id][idea_id]`：沿用已知信念文字。`data/feedback_styles.json` 中 belief_patterns 将“微弱/零散/渐强/共识较强/受压制”映射到残缺/浮现/完整图案。未知文字保持未知图案，不用证据数或隐藏分数推断。
- `regional_feedback[region_id].laws`：分别以 sea、items、travel 为键。每条记录 `{state, known, known_effects, target_id}`。known 为 false 时隐藏状态与影响；state 只允许 stable/questioned/wavering/ineffective，对应 UI 标签稳固/受到怀疑/明显动摇/失去效力。不是成功率或阈值公式。target_id 仅用于变化提示定位已知目标。
- `regional_feedback[region_id].scene`：`{kind: "canal", state, known, target_id}`。state 为 dry/signs/shallow/tidal；未知 kind/state 显示未接入。场景层为 masonry、dry、signs、water、tide，各次刷新完整设置可见性，没有永久解锁或日期条件。
- `regional_feedback[region_id].idea_targets`：可选，思想 ID 到已知目标 ID 的映射，用于思想变化提示定位。没有已知目标时不会凭空建立调查对象。
- `known_targets[target_id].investigation_open`：可选当前调查开放条件；未提供时兼容原有已知线索判定。false 不删除既有线索知识，但使 has_lead 为 false，调查和需线索标记关闭。
- 目标定义 `marker_requires_lead: true`：只有明确线索已知且当前开放时进入线索标记列表。预览石渠使用此字段。

每日“可安排/已安排/今日已使用”仍由 DailyPlan 管理，与 belief_patterns 完全独立。读同一思想、增加证据或安排移动都不会改纹样；整批结算确实到达新地区后才切换。

## 规则边界

法则状态和路线资格是独立输入。没有因为 travel 的视觉状态为 ineffective 就直接设 reachable=true。继续通过既有 known_routes.reachable、from_ids 和当前/计划位置检查移动；地图可达文字也按实际出发地区显示。第三法则何时满足通行条件，应由底层规则产生许可快照，本阶段不定义新的条件。

同理，石渠浅水并不自动产生线索。只有正式开放的已知线索才生成调查标记。收回调查开放条件后，水层和标记可以回退，但已经发现的文字记录保留。

## 变化提示

比较同一个实际地区在提交前后的状态，而不是把进入另一地区误判成世界突然变化。提示覆盖场景、法则、路线条件与有已知目标映射的思想信念。按来源及提交 ID 去重，同一目标的多项变化合并成按钮，悬停阅读全部文字；点击只调用统一选择目标接口。

没有变化的次日快照保留前一夜提示，不再触发一次；进入其他地区清理不属于当地的旧提示。重开及切换正式/预览时清理提示。没有增加短动画或音效，因此不会因重复绘制播放首次发现效果。

## 开发快照

`preview_data/feedback_states.json` 明确 preview_only，包含普通、征兆、部分进展、共识和回退。DEBUG 应用调用独立 NightSettlement 的 reality 适配器，处理完整测试批次后才应用到预览世界；不进入正式历史，不改日期/AP，也不移动玩家。

测试快照只改配置指定的镇区。若玩家实际在遗迹，卡牌仍显示遗迹状态。正常夜间流程不自动应用这些预设。通行开启样例显式同时提供底层测试路线许可；这不是“到某一天打开边界”或“卡裂了就能走”的规则。

正式初始资料没有地区状态，保持未知。正式行动效果、阈值公式、组织条件和反制系统仍沿用第 4 阶段的未接入接口，不用美术反馈代替它们。
