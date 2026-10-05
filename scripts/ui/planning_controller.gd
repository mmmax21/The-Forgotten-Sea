extends Node
## 将现有目标视图绑定到唯一计划模型；所有修改通过模型再次校验。
signal night_started
signal next_day_requested
const IdeaCard = preload("res://scripts/ui/idea_card.gd")
const Plan = preload("res://scripts/daily_plan.gd")
const Settlement = preload("res://scripts/night_settlement.gd")
var ui: MarginContainer
var plan: RefCounted
var settlement := Settlement.new()
var _profiles: Dictionary = {}
var selected_scale := "personal"
var selected_idea := ""
var editing_index := -1
var _last_receipt: Dictionary = {}
var _confirm_fingerprint := ""
var _day_handoff := false
var _applied_mornings: Dictionary = {}
var _run_initial_world: Dictionary = {}
var _morning_message := ""

func _ready() -> void:
	ui = get_node("%GameScreen")
	ui.planning = self
	for profile in ["formal", "preview"]:
		var model = Plan.new(ui.knowledge, profile)
		_profiles[profile] = model
		model.changed.connect(_on_plan_changed)
		model.submitted.connect(_on_submitted)
	plan = _profiles["preview" if ui.knowledge.preview_enabled else "formal"]
	ui.profile_changed.connect(_switch_profile)
	%PersonalScale.pressed.connect(_set_scale.bind("personal"))
	%GroupScale.pressed.connect(_set_scale.bind("group"))
	%CardChoice.item_selected.connect(_choose_idea)
	%QueueAction.pressed.connect(_queue)
	%CancelReplace.pressed.connect(_cancel_replace)
	%EndDayButton.pressed.connect(_end_day)
	%SubmitConfirm.confirmed.connect(_confirm_submit)
	%NightReview.advance_requested.connect(_next_day)
	%NightReview.history_selected.connect(_show_history_entry)
	settlement.morning_ready.connect(_on_morning)
	settlement.batch_ready.connect(_on_receipt)
	for slot in [%ActionSlot1, %ActionSlot2, %ActionSlot3]:
		slot.edit_requested.connect(_edit)
		slot.remove_requested.connect(_remove)
		slot.reorder_requested.connect(_reorder)
	_on_plan_changed()

func _switch_profile(preview: bool) -> void:
	%NightReview.close_review()
	_day_handoff = false
	plan = _profiles["preview" if preview else "formal"]
	editing_index = -1
	selected_idea = ""
	selected_scale = "personal"
	_last_receipt = settlement.receipt(plan.request_id())
	_on_plan_changed()

func can_switch_profile() -> bool:
	return plan == null or not plan.is_locked() and not plan.event_blocked

func can_debug_advance() -> bool:
	return plan != null and not plan.is_locked() and not plan.event_blocked and plan.entries().is_empty()

func is_locked() -> bool:
	return plan != null and plan.is_locked()

func sync_day(current_day: int) -> void:
	if current_day > plan.day:
		_day_handoff = false
		_morning_message = ""
		plan.start_day(current_day)
	_on_plan_changed()

func restart_plan() -> void:
	if ui.visual_feedback != null:
		ui.visual_feedback.clear_run()
	var profile: String = "preview" if ui.knowledge.preview_enabled else "formal"
	if _run_initial_world.has(profile):
		ui.knowledge.apply_settled_snapshot(_run_initial_world[profile])
		_run_initial_world.erase(profile)
	_morning_message = ""
	_last_receipt.clear()
	%NightReview.close_review()
	_day_handoff = false
	settlement.clear_history(ui.knowledge.preview_enabled)
	plan.start_day(1, true)
	_cancel_replace()

func planned_location() -> String:
	return plan.planned_location_before(editing_index)

func behavior_options() -> Dictionary:
	var options: Dictionary = ui.knowledge.action_options(ui.selected_id, planned_location())
	if options.move.eligible and plan.cost_for({"behavior": "move", "target_id": ui.selected_id}) == 0:
		options.move = {"eligible": false, "reason": "移动 AP 成本尚未配置，暂不可安排。"}
	return options

func target_changed() -> void:
	selected_scale = "personal"
	selected_idea = ""

func behavior_changed() -> void:
	if ui.selected_behavior in ["move", "conceal"]:
		selected_idea = ""

func draft() -> Dictionary:
	var target: Dictionary = ui.knowledge.target_view(ui.selected_id)
	return {"target_id": ui.selected_id, "target_name": target.get("name", "未知目标"), "behavior": ui.selected_behavior, "behavior_name": Plan.ACTION_NAMES.get(ui.selected_behavior, ""), "scale": selected_scale, "scale_name": Plan.SCALE_NAMES.get(selected_scale, ""), "idea_id": selected_idea, "idea_name": plan.idea_name(selected_idea)}

func refresh_composer() -> void:
	if plan == null:
		return
	var options := behavior_options()
	var locked: bool = plan.is_locked() or plan.event_blocked
	var reasons: Array[String] = []
	for action in ui._action_buttons:
		var button: Button = ui._action_buttons[action]
		button.disabled = locked or not options[action].eligible
		button.set_pressed_no_signal(ui.selected_behavior == action)
		button.tooltip_text = "今日计划已锁定" if locked else options[action].reason
		if not options[action].eligible:
			reasons.append(Plan.ACTION_NAMES[action] + "：" + options[action].reason)
	%ActionAvailability.text = "\n".join(reasons)
	%PersonalScale.disabled = locked or ui.selected_behavior.is_empty()
	%GroupScale.disabled = locked or ui.selected_behavior.is_empty() or not plan.group_access().get("unlocked", false)
	%PersonalScale.set_pressed_no_signal(selected_scale == "personal")
	%GroupScale.set_pressed_no_signal(selected_scale == "group")
	%ScaleHint.text = "群体已按组织条件解锁" if plan.group_access().get("unlocked", false) else plan.group_access().get("known_reason", "尚未得知组织条件。")
	%GroupScale.tooltip_text = %ScaleHint.text
	%CardChoice.clear()
	%CardChoice.add_item("不使用思想卡")
	%CardChoice.set_item_metadata(0, "")
	var chosen := 0
	for idea in plan.obtained_ideas():
		var status: Dictionary = plan.idea_status(idea.id, editing_index)
		%CardChoice.add_item(idea.name + " · " + status.label)
		var index: int = %CardChoice.item_count - 1
		%CardChoice.set_item_metadata(index, idea.id)
		%CardChoice.set_item_disabled(index, status.state != "available" or ui.selected_behavior not in idea.allowed_behaviors)
		%CardChoice.get_popup().set_item_tooltip(index, status.reason if status.state != "available" else "隐匿/移动与思想卡的组合尚未定义。" if ui.selected_behavior in ["move", "conceal"] else "可作为本次行动的可选参数。")
		if idea.id == selected_idea:
			chosen = index
	%CardChoice.select(chosen)
	%CardChoice.disabled = locked or ui.selected_behavior.is_empty()
	var entry := draft()
	var check: Dictionary = plan.candidate(entry, editing_index)
	%ActionDescription.text = plan.describe(entry)
	var cost: int = plan.cost_for(entry)
	%ActionCost.text = "预算占用：%d AP（不会立即执行）" % cost if cost > 0 else "移动费用尚未配置"
	%ActionHint.text = "今日计划已锁定，不能编辑。" if locked else "正在替换已有行动；原预算与用卡在替换成功前保留。" if editing_index >= 0 else "配置行动，不立即产生结果。"
	if not check.valid and not ui.selected_behavior.is_empty():
		%ActionHint.text = "\n".join(check.errors)
	if planned_location() != ui.knowledge.current_location_id() and not ui.selected_behavior.is_empty():
		%ActionDescription.text += "\n此行动依赖前面的移动成功。"
	%QueueAction.disabled = locked or not check.valid or ui.selected_behavior.is_empty()
	%QueueAction.text = "替换今日计划" if editing_index >= 0 else "加入今日计划"
	%CancelReplace.visible = editing_index >= 0
	%CancelReplace.disabled = locked
	if ui.narrative != null: ui.narrative.update_hint()

func _set_scale(scale: String) -> void:
	if plan.is_locked() or (scale == "group" and not plan.group_access().get("unlocked", false)):
		return
	selected_scale = scale
	refresh_composer()

func _choose_idea(index: int) -> void:
	if plan.is_locked() or %CardChoice.is_item_disabled(index):
		return
	selected_idea = %CardChoice.get_item_metadata(index)
	refresh_composer()

func _queue() -> void:
	if plan.is_locked():
		return
	var result: Dictionary = plan.put(draft(), editing_index)
	if result.valid:
		editing_index = -1
		ui.selected_behavior = ""
		selected_idea = ""
		_on_plan_changed()
	else:
		%ActionHint.text = "\n".join(result.errors)

func _edit(index: int) -> void:
	if plan.is_locked() or index < 0 or index >= plan.entries().size():
		return
	var entry: Dictionary = plan.entries()[index]
	editing_index = index
	ui.select_target(entry.target_id)
	ui.selected_behavior = entry.behavior
	selected_scale = entry.scale
	selected_idea = entry.idea_id
	refresh_composer()
	%DetailsScroll.ensure_control_visible(%QueueAction)

func _cancel_replace() -> void:
	editing_index = -1
	selected_idea = ""
	refresh_composer()

func _remove(index: int) -> void:
	if plan.remove(index):
		_cancel_replace()

func _reorder(index: int, offset: int) -> void:
	if plan.reorder(index, offset):
		_cancel_replace()

func _on_plan_changed() -> void:
	if plan == null:
		return
	refresh_composer()
	var validation: Dictionary = plan.validate()
	var entries: Array = plan.entries()
	var slots := [%ActionSlot1, %ActionSlot2, %ActionSlot3]
	for slot in range(3):
		var owner := {}
		var entry := {}
		for item in validation.items:
			if slot >= item.slot and slot < item.slot + item.cost:
				owner = item
				entry = entries[item.index]
				break
		slots[slot].display(slot, owner, entry, plan.is_locked() or plan.event_blocked, entries.size())
	%APLabel.text = "剩余 AP  %d / 3" % plan.remaining_ap()
	%PlanStatus.text = "夜间计划已锁定" if plan.is_locked() else "计划有效 · 可继续检查与修改" if validation.valid else "需修正：" + "；".join(validation.errors)
	%PlanStatus.tooltip_text = "\n".join(validation.errors)
	%EndDayButton.disabled = not validation.valid and not plan.is_locked()
	%EndDayButton.text = "查看夜间结算" if plan.is_locked() else "结束今日行动"
	%EndDayButton.tooltip_text = "整份计划一次提交；AP 未用完会提醒。"
	%PreviewToggle.disabled = plan.is_locked() or plan.event_blocked
	%EndDayButton.disabled = %EndDayButton.disabled or plan.event_blocked
	for child in %IdeasRow.get_children():
		%IdeasRow.remove_child(child)
		child.queue_free()
	for idea in plan.obtained_ideas():
		var button := IdeaCard.new()
		%IdeasRow.add_child(button)
		button.configure(idea.name, ui.feedback.idea(ui.knowledge.get_snapshot(),idea.id),plan.idea_status(idea.id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_inspect_idea.bind(idea.id))
	if ui.visual_feedback != null:
		ui.visual_feedback.refresh()
	%CardsEmpty.visible = plan.obtained_ideas().is_empty()
	if get_parent().is_node_ready():
		get_parent()._refresh_buttons()

func _inspect_idea(idea_id: String) -> void:
	%InfoDialog.title = plan.idea_name(idea_id)
	%InfoDialog.dialog_text = "当地信念：%s\n使用状态：%s\n%s" % [plan.local_belief(idea_id), plan.idea_status(idea_id).label, plan.idea_status(idea_id).reason]
	%InfoDialog.popup_centered(Vector2i(700, 220))

func _end_day() -> void:
	if plan.event_blocked: return
	if plan.is_locked():
		_show_night()
		return
	if not plan.validate().valid or %SubmitConfirm.visible:
		return
	if plan.remaining_ap() > 0:
		_confirm_fingerprint = JSON.stringify(plan.entries())
		%SubmitConfirm.dialog_text = "还有 %d AP 未安排。确定结束今日行动并锁定整份计划吗？\n没有主动行动，世界也仍会进入夜间处理。" % plan.remaining_ap()
		%SubmitConfirm.popup_centered(Vector2i(780, 220))
	else:
		plan.submit()

func _confirm_submit() -> void:
	if not %SubmitConfirm.visible:
		return
	%SubmitConfirm.hide()
	if JSON.stringify(plan.entries()) == _confirm_fingerprint:
		plan.submit()

func _on_submitted(payload: Dictionary) -> void:
	var profile: String = "preview" if payload.preview_only else "formal"
	if not _run_initial_world.has(profile):
		_run_initial_world[profile] = ui.knowledge.get_snapshot()
	_last_receipt.clear()
	night_started.emit()
	settlement.submit(payload, ui.knowledge.get_snapshot().get("preview_settlement", {}) if payload.preview_only else {}, ui.knowledge.get_snapshot())
	_show_night()

func _on_receipt(receipt: Dictionary) -> void:
	if receipt.request_id != plan.request_id():
		return
	_last_receipt = receipt
	if receipt.status == "complete":
		if plan.mark_resolved(receipt.request_id, receipt.get("consumed_ideas", [])):
			ui.knowledge.apply_settled_snapshot(settlement.committed_world(receipt.request_id), receipt.request_id)
			ui.refresh_known_targets()
			_on_plan_changed()
	_show_night()

func _show_night() -> void:
	var view := _last_receipt.duplicate(true)
	if view.is_empty():
		view = {"request_id": plan.request_id(), "day": plan.day, "preview_only": ui.knowledge.preview_enabled, "status": "pending", "message": "正在按固定顺序处理整份计划。"}
	if not _morning_message.is_empty():
		view.status = "needs_rule"
		view.message = _morning_message
	%NightReview.show_report(view, [], false, plan.is_resolved() and not _day_handoff)

func show_history() -> void:
	var entries: Array = settlement.history(ui.knowledge.preview_enabled)
	if entries.is_empty():
		%InfoDialog.title = "手记"
		%InfoDialog.dialog_text = "尚无已完成的夜间回顾。正式与开发预览记录分别保存。"
		%InfoDialog.popup_centered(Vector2i(680, 220))
		return
	%NightReview.show_report(entries.back(), entries, true)

func _show_history_entry(token: String) -> void:
	for entry in settlement.history(ui.knowledge.preview_enabled):
		if entry.request_id == token:
			%NightReview.show_report(entry, settlement.history(ui.knowledge.preview_enabled), true)
			return

func _next_day() -> void:
	if not plan.is_resolved() or _day_handoff or %NightReview.historical:
		return
	_day_handoff = true
	if plan.day == 10:
		%NightReview.close_review()
		next_day_requested.emit()
		return
	%NightReview.next_day.disabled = true
	settlement.begin_next_day(plan.request_id())

func _on_morning(receipt: Dictionary) -> void:
	if receipt.request_id != plan.request_id() or _applied_mornings.has(receipt.request_id):
		return
	if receipt.status != "complete":
		_morning_message = receipt.message
		var view := _last_receipt.duplicate(true)
		view.status = "needs_rule"
		view.message = receipt.message
		%NightReview.show_report(view)
		return
	_applied_mornings[receipt.request_id] = true
	ui.knowledge.apply_settled_snapshot(settlement.committed_world(receipt.request_id, true), "morning:" + receipt.request_id)
	ui.refresh_known_targets()
	%NightReview.close_review()
	if ui.narrative != null: ui.narrative.prepare_day(plan.day + 1)
	next_day_requested.emit()
