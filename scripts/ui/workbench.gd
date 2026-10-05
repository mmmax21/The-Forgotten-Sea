extends MarginContainer
## 选择与显示只消费已知资料投影，不执行移动、揭示事实或消耗 AP。

signal profile_changed(preview: bool)
var planning: Node
var visual_feedback: Node
var feedback = preload("res://scripts/world_feedback.gd").new()

const Knowledge = preload("res://scripts/target_knowledge.gd")
const LAWS: Array[String] = ["大海从不存在。", "未经允许禁止使用特定物品。", "未经允许禁止跨越区域。"]
const ACTION_NAMES := {"talk": "交谈", "investigate": "调查", "conceal": "隐匿", "move": "移动"}
var knowledge := Knowledge.new()
var selected_id: String = ""
var selected_behavior: String = ""
var _target_buttons: Array[Button] = []
var _action_buttons: Dictionary = {}


func _ready() -> void:
	%NotesButton.pressed.connect(_show_notes)
	%MenuButton.pressed.connect(_show_menu)
	for index in range(3):
		var button: Button = get_node("%Law" + str(index + 1))
		button.tooltip_text = LAWS[index]
		button.pressed.connect(_show_law.bind(index))
	_action_buttons = {"talk": %TalkAction, "investigate": %InvestigateAction, "conceal": %ConcealAction, "move": %MoveAction}
	for action in _action_buttons:
		var button: Button = _action_buttons[action]
		button.toggle_mode = true
		button.pressed.connect(_select_behavior.bind(action))
	%PreviewToggle.toggled.connect(set_development_preview)
	knowledge.set_preview("--preview-targets" in OS.get_cmdline_user_args())
	%PreviewToggle.set_pressed_no_signal(knowledge.preview_enabled)
	refresh_known_targets()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func set_development_preview(enabled: bool) -> void:
	if planning != null and not planning.can_switch_profile():
		%PreviewToggle.set_pressed_no_signal(knowledge.preview_enabled)
		return
	knowledge.set_preview(enabled)
	%PreviewToggle.set_pressed_no_signal(enabled)
	refresh_known_targets()
	profile_changed.emit(enabled)


func set_known_world(definitions: Array, snapshot: Dictionary) -> bool:
	if planning != null and planning.is_locked():
		return false
	if not knowledge.set_live_data(definitions, snapshot):
		return false
	refresh_known_targets()
	return true


func refresh_known_targets() -> void:
	# 全量重建已知列表，避免正式/预览切换时保留旧节点或隐藏目标选择。
	for host in [%PeopleList, %PlaceNodes, %MarkerNodes]:
		for child in host.get_children():
			host.remove_child(child)
			child.queue_free()
	_target_buttons.clear()
	%PreviewNotice.text = "开发预览 · 独立资料" if knowledge.preview_enabled else "正式资料 · 仅显示已知内容"
	%PeopleHint.text = "演示相识与位置，非正式记录" if knowledge.preview_enabled else "只显示已经认识的人物"
	%AlertLabel.text = "警戒：" + str(knowledge.get_snapshot().get("known_alert", "未接入"))
	%LocationLabel.text = "地区：" + knowledge.current_location_name()
	%LocationLabel.tooltip_text = "开发预览位置，不写入正式流程" if knowledge.preview_enabled else "来自正式资料的位置记录"
	%RegionTitle.text = knowledge.current_location_name() + (" · 开发预览" if knowledge.preview_enabled else " · 地区资料")
	%ObjectiveText.text = knowledge.objective()
	%SceneHint.text = "预览位置可替换；选择只查看，不移动。" if knowledge.preview_enabled else "选择只查看已知资料，不会移动或获得新情报。"
	var people: Array[Dictionary] = knowledge.visible_targets("person")
	for entry in people:
		_add_person_button(entry)
	if people.is_empty():
		_add_empty(%PeopleList, "尚无已接入的相识记录")
	var places: Array[Dictionary] = knowledge.visible_targets("place")
	for entry in places:
		_add_target_button(entry, %PlaceNodes, true)
	if places.is_empty():
		_add_empty(%PlaceNodes, "尚无已发现地点")
	for entry in knowledge.visible_targets():
		if entry.kind in ["object", "anomaly"] and (not entry.marker_requires_lead or entry.has_lead):
			_add_target_button(entry, %MarkerNodes)
	if %MarkerNodes.get_child_count() == 0:
		_add_empty(%MarkerNodes, "尚无已发现的物件或异常")
	reset_navigation()
	_apply_responsive_layout()
	if visual_feedback != null:
		visual_feedback.refresh()


func _add_empty(host: Container, message: String) -> void:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	host.add_child(label)


func _add_person_button(entry: Dictionary) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 106
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.tooltip_text = "%s\n%s\n位置：%s" % [entry.name, entry.latest_status, entry.location_label]
	button.set_meta("target_id", entry.id)
	button.pressed.connect(select_target.bind(entry.id))
	%PeopleList.add_child(button)
	# 文本与占位头像放在容器中，事件交给整个人物条目。
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	button.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var avatar := Label.new()
	avatar.text = entry.avatar
	avatar.custom_minimum_size.x = 32
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_theme_font_size_override("font_size", 26)
	avatar.add_theme_color_override("font_color", Color(0.57, 0.78, 0.73))
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var name_label := Label.new()
	name_label.text = entry.name
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)
	var status := Label.new()
	status.text = entry.latest_status
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(status)
	_target_buttons.append(button)


func _add_target_button(entry: Dictionary, host: Container, place: bool = false) -> void:
	var button := Button.new()
	button.text = entry.name
	if place:
		button.text += "\n" + entry.place_status.replace("已知 · ", "") + (" · 线索" if entry.has_lead else "")
	button.tooltip_text = "%s · %s" % [entry.kind_name, entry.location_label]
	if place:
		button.tooltip_text += "\n" + knowledge.known_route_reason(entry.id)
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 44
	button.set_meta("target_id", entry.id)
	button.pressed.connect(select_target.bind(entry.id))
	if place and entry.id == knowledge.current_location_id():
		button.add_theme_color_override("font_color", Color(0.57, 0.78, 0.73))
	host.add_child(button)
	_target_buttons.append(button)


func select_target(target_id: String) -> void:
	var entry: Dictionary = knowledge.target_view(target_id)
	if entry.is_empty():
		return
	if planning != null:
		planning.target_changed()
	selected_id = target_id
	selected_behavior = ""
	%DetailsScroll.scroll_vertical = 0
	%TargetKind.text = entry.kind_name + (" / 开发预览" if knowledge.preview_enabled else " / 已知资料")
	%TargetTitle.text = entry.name
	%TargetSummary.text = entry.identity
	%TargetDescription.text = entry.description
	%TargetDescription.visible = not entry.description.is_empty()
	%TargetPortrait.visible = entry.kind == "person"
	%PortraitText.text = "%s   立绘占位" % entry.avatar
	%RelationshipStatus.visible = entry.kind == "person"
	%AttitudeText.text = "对玩家的已知态度\n" + entry.attitude
	%BeliefText.text = "对“海”的已知看法\n" + entry.belief
	%CooperationText.text = "当前合作范围\n" + entry.cooperation
	var observations: Array = entry.issues + entry.clues
	%KnownIssues.text = "已发现的问题或线索\n" + ("\n".join(observations) if not observations.is_empty() else "暂无已记录的信息")
	%KnownIssues.show()
	%TargetLocation.text = "当前位置：" + entry.location_label
	%TargetLocation.show()
	%Reachability.visible = entry.kind == "place"
	%Reachability.text = entry.place_status
	if entry.kind == "place" and entry.id != knowledge.current_location_id():
		%Reachability.text += "\n" + knowledge.known_route_reason(entry.id)
	for button in _target_buttons:
		button.set_pressed_no_signal(button.get_meta("target_id") == target_id)
	_refresh_actions()


func _refresh_actions() -> void:
	if planning != null:
		planning.refresh_composer()
		return
	var options: Dictionary = knowledge.action_options(selected_id)
	var lines: Array[String] = []
	for action in _action_buttons:
		var button: Button = _action_buttons[action]
		button.disabled = not options[action].eligible
		button.set_pressed_no_signal(selected_behavior == action)
		button.tooltip_text = options[action].reason
		lines.append(ACTION_NAMES[action] + "：" + options[action].reason)
	%ActionAvailability.text = "\n".join(lines)
	%ActionHint.text = "选择行为仅配置意图，不执行。" if selected_behavior.is_empty() else "已选：%s · 未加入计划" % ACTION_NAMES[selected_behavior]
	var entry: Dictionary = knowledge.target_view(selected_id)
	if selected_behavior == "talk" and not entry.get("communication", "").is_empty():
		%ActionHint.text = "已选交流：" + entry.communication


func _select_behavior(action: String) -> void:
	if planning != null and planning.is_locked():
		return
	# 重新验证，阻止过期按钮事件在切换目标后保留不合法行为。
	var options: Dictionary = planning.behavior_options() if planning != null else knowledge.action_options(selected_id)
	if not options.has(action) or not options[action].eligible:
		return
	selected_behavior = action
	if planning != null:
		planning.behavior_changed()
	_refresh_actions()


func reset_navigation() -> void:
	selected_id = ""
	selected_behavior = ""
	%TargetKind.text = "目标详情"
	%TargetTitle.text = "尚未选择目标"
	%TargetSummary.text = "从人物列表或地区节点选择。"
	%TargetDescription.text = "查看仅复述已知资料，不会获得新情报。"
	%TargetDescription.show()
	for control in [%RelationshipStatus, %TargetPortrait, %KnownIssues, %TargetLocation, %Reachability]:
		control.hide()
	for button in _target_buttons:
		button.set_pressed_no_signal(false)
	%DetailsScroll.scroll_vertical = 0
	_refresh_actions()


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact: bool = size.x < 1500
	%PreviewNotice.visible = not compact
	%PeopleHint.visible = not compact
	%ObjectiveText.add_theme_font_size_override("font_size", 14 if compact else 20)
	%PeopleList.get_parent().add_theme_constant_override("separation", 4 if compact else 12)
	%ScenePlaceholder.get_parent().add_theme_constant_override("separation", 4 if compact else 12)
	%RegionTitle.add_theme_font_size_override("font_size", 18 if compact else 22)
	var panel: StyleBox = %CenterPanel.get_theme_stylebox("panel").duplicate()
	for side in ["left", "top", "right", "bottom"]:
		panel.set("content_margin_" + side, 8 if compact else 16)
	%CenterPanel.add_theme_stylebox_override("panel", panel)
	for host in [%PlaceNodes, %MarkerNodes]:
		for button in host.get_children():
			if button is Button:
				button.add_theme_font_size_override("font_size", 14 if compact else 20)
				button.custom_minimum_size.y = 36 if compact else 44
	%SceneHint.visible = not compact
	%MarkerTitle.visible = not compact
	get_parent().theme.default_font_size = 18 if compact else 20
	%LeftPanel.custom_minimum_size.x = 220 if compact else 240
	%RightPanel.custom_minimum_size.x = 320 if compact else 340
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 16 if compact else 24)


func _show_notes() -> void:
	if planning != null:
		planning.show_history()
		return
	%InfoDialog.title = "手记"
	%InfoDialog.dialog_text = "详细手记尚未开放。\n当前目标详情只显示已有的相识与发现记录。"
	%InfoDialog.popup_centered(Vector2i(680, 220))


func _show_menu() -> void:
	%InfoDialog.title = "菜单"
	%InfoDialog.dialog_text = "当前支持每日行动规划与整批提交。\n设置与存档功能尚未开放；开发预览与正式资料分离。"
	%InfoDialog.popup_centered(Vector2i(680, 220))


func _show_law(index: int) -> void:
	%InfoDialog.title = "王国法则 · %d" % (index + 1)
	%InfoDialog.dialog_text = get_node("%Law"+str(index+1)).tooltip_text
	%InfoDialog.popup_centered(Vector2i(680, 180))
