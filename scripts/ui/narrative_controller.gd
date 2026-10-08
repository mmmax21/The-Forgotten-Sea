extends Node
const Events = preload("res://scripts/event_state.gd")
const Overlay = preload("res://scripts/ui/event_overlay.gd")
const JournalScene = preload("res://scenes/ui/journal_book.tscn")
var events := Events.new()
var overlay: Control
var journal: Control
var ui: Control
var planner: Node
var active: Dictionary = {}
var baseline: Dictionary = {}
var enabled := true
var seen_profiles: Dictionary = {}
var hint: Label

func _ready() -> void:
	ui = get_parent().get_node("%GameScreen")
	planner = ui.planning
	ui.narrative = self
	enabled = not get_tree().root.get_meta("skip_intro", false)
	baseline = ui.knowledge._live_snapshot.duplicate(true)
	overlay = Overlay.new()
	overlay.name = "EventOverlay"
	journal = JournalScene.instantiate()
	journal.name = "JournalBook"
	get_parent().add_child.call_deferred(journal)
	get_parent().add_child.call_deferred(overlay)
	overlay.chosen.connect(_choose)
	journal.read_changed.connect(_badge)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.6, 0.85, 0.8)
	var queue: Button = get_parent().get_node("%QueueAction")
	queue.get_parent().add_child(hint)
	queue.get_parent().move_child(hint, queue.get_index())
	ui.knowledge.settled_changed.connect(func(_a, _b, _id): refresh_journal(); check_events.call_deferred())
	ui.profile_changed.connect(_profile_changed)
	if enabled:
		planner.settlement.set_adapter("actions", preload("res://scripts/settlement/opening_actions.gd").run)
		planner.plan.event_blocked = not ui.knowledge.preview_enabled and not events.due(planner.plan.day, ui.knowledge.get_snapshot()).is_empty()
	_boot.call_deferred()

func _boot() -> void:
	for state in [get_parent().live_state, get_parent().preview_state]:
		state.changed.connect(func():
			refresh_journal()
			check_events())
	refresh_journal()
	check_events()

func _profile_changed(_preview: bool) -> void:
	journal.hide()
	journal.seen = seen_profiles.get("preview" if _preview else "formal", {})
	check_events()
	refresh_journal()

func check_events() -> void:
	if not is_instance_valid(overlay) or not overlay.is_inside_tree(): return
	if not enabled or ui.knowledge.preview_enabled or planner.plan.is_locked():
		update_hint()
		return
	active = events.due(planner.plan.day, ui.knowledge.get_snapshot())
	planner.plan.event_blocked = not active.is_empty()
	planner._on_plan_changed()
	if not active.is_empty():
		journal.hide()
		if not overlay.visible or overlay.event.get("id", "") != active.id:
			overlay.show_event(active)
	else:
		overlay.hide()
	update_hint()

func _choose(id: String, choice: String) -> void:
	if active.get("id", "") != id: return
	var world: Dictionary = events.resolve(active, choice, ui.knowledge.get_snapshot(), planner.plan.day)
	if world.is_empty(): return
	active = {}
	ui.knowledge.apply_settled_snapshot(world, "event:" + id)
	ui.refresh_known_targets()
	check_events()
	refresh_journal()

func restart() -> void:
	journal.hide()
	journal.seen.clear()
	seen_profiles.clear()
	overlay.hide()
	active.clear()
	planner.plan.event_blocked = false
	if enabled and not ui.knowledge.preview_enabled:
		ui.knowledge.apply_settled_snapshot(baseline)
	refresh_journal()

func prepare_day(day: int) -> void:
	# Set the barrier before emitting the calendar transition, not one frame later.
	if enabled and not ui.knowledge.preview_enabled:
		planner.plan.event_blocked = not events.due(day, ui.knowledge.get_snapshot()).is_empty()

func update_hint() -> void:
	if hint == null: return
	hint.visible = enabled and not ui.knowledge.preview_enabled and planner.plan.day <= 3
	if not hint.visible: return
	if planner.plan.event_blocked:
		hint.text = "先读完并确认今日事件，再开放行动规划。"
	elif planner.plan.is_locked():
		hint.text = "行动已经锁定。在夜间回顾读完结果后进入下一天。"
	elif not planner.plan.entries().is_empty():
		hint.text = "已加入计划。可继续修改，或点击底部「结束今日行动」。"
	elif planner.plan.day == 2:
		hint.text = "选中遗迹残文 → 调查 → 加入今日计划。夜间结果会记入右上角手记。"
	elif ui.selected_id.is_empty():
		hint.text = "先点击左侧人物，再在这里配置行动。"
	elif ui.selected_behavior.is_empty():
		hint.text = "选择可用行为，再选择个人规模；思想卡可以不使用。"
	else:
		hint.text = "检查说明，点击下方「加入今日计划」。此时不会产生结果。"

func open_journal() -> void:
	refresh_journal()
	journal.open()

func _badge() -> void:
	get_parent().get_node("%NotesButton").text = "手记 · 新" if journal.unread() else "手记"
	seen_profiles["preview" if ui.knowledge.preview_enabled else "formal"] = journal.seen

func refresh_journal() -> void:
	if not journal.is_inside_tree(): return
	var world: Dictionary = ui.knowledge.get_snapshot()
	var current := _current_day()
	var grouped := {}
	for day in range(1, current + 1):
		grouped[day] = []
	for item in world.get("journal_log", []):
		var logged_day := int(item.get("day", 0))
		if not grouped.has(logged_day):
			continue
		grouped[logged_day].append({"id": str(item.id), "title": str(item.title), "text": str(item.text)})
	for receipt in planner.settlement.history(ui.knowledge.preview_enabled):
		var night_day := int(receipt.get("day", 0))
		if not grouped.has(night_day):
			continue
		grouped[night_day].append({
			"id": "night:" + str(receipt.request_id),
			"title": "第 %d 天 · 夜间回顾" % night_day,
			"text": _night_text(receipt)
		})
	var pages: Array = []
	for day in range(1, current + 1):
		pages.append({"day": day, "entries": grouped[day]})
	journal.refresh(pages)


func _current_day() -> int:
	var host := get_parent()
	var state = host.preview_state if ui.knowledge.preview_enabled else host.live_state
	return state.get_day()


func _night_text(receipt: Dictionary) -> String:
	var lines: Array[String] = []
	for section in ["actions", "people", "world", "kingdom"]:
		lines.append({"actions": "你的行动", "people": "人们的后续行动", "world": "世界的变化", "kingdom": "王国的回应"}[section])
		for record in receipt.sections[section]:
			lines.append(record.title + "\n" + record.happened + "\n" + record.reason + "\n" + record.direction)
	return "\n\n".join(lines)
