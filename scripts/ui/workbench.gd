extends MarginContainer
## 阶段一导航视图。预览数据只存在此 UI 中，不写入 GameState 或存档。

const PREVIEW_PATH := "res://preview_data/workbench.json"
const LAWS: Array[String] = [
	"大海从不存在。",
	"未经允许禁止使用特定物品。",
	"未经允许禁止跨越区域。",
]
var selected_id: String = ""
var _entries: Dictionary = {}
var _target_buttons: Array[Button] = []


func _ready() -> void:
	%NotesButton.pressed.connect(_show_notes)
	%MenuButton.pressed.connect(_show_menu)
	for index in range(3):
		var button: Button = get_node("%Law" + str(index + 1))
		button.tooltip_text = LAWS[index]
		button.pressed.connect(_show_law.bind(index))
	_load_navigation_preview()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _load_navigation_preview() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary or parsed.get("preview_only") != true:
		%RegionTitle.text = "地区场景 · 未载入"
		return
	%RegionTitle.text = parsed.get("region_title", "地区场景 · 未载入")
	%ObjectiveText.text = parsed.get("objective", "暂无目标")
	for section in ["people", "places", "markers"]:
		var host: Container = %PeopleList if section == "people" else (%PlaceNodes if section == "places" else %MarkerNodes)
		for entry in parsed.get(section, []):
			_entries[entry.id] = entry
			_add_target_button(entry, host)
	# 同一个人物标记与左侧条目绑定同一条预览数据。
	if _entries.has("fisher"):
		_add_target_button(_entries.fisher, %MarkerNodes)


func _add_target_button(entry: Dictionary, host: Container) -> void:
	var button := Button.new()
	button.text = entry.name
	button.tooltip_text = "%s · 导航预览，仅查看详情" % entry.kind
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 42
	button.set_meta("target_id", entry.id)
	button.pressed.connect(select_target.bind(entry.id))
	host.add_child(button)
	_target_buttons.append(button)


func select_target(target_id: String) -> void:
	if not _entries.has(target_id):
		return
	selected_id = target_id
	var entry: Dictionary = _entries[target_id]
	%TargetKind.text = "%s / 导航预览" % entry.kind
	%TargetTitle.text = entry.name
	%TargetSummary.text = entry.summary
	%TargetDescription.text = entry.description
	%RelationshipStatus.visible = entry.kind == "人物"
	for button in _target_buttons:
		button.set_pressed_no_signal(button.get_meta("target_id") == target_id)


func reset_navigation() -> void:
	selected_id = ""
	%TargetKind.text = "目标详情"
	%TargetTitle.text = "尚未选择目标"
	%TargetSummary.text = "从人物列表或地区节点选择。"
	%TargetDescription.text = "选择仅用于查看，不会执行行动。"
	%RelationshipStatus.hide()
	for button in _target_buttons:
		button.set_pressed_no_signal(false)


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return
	var compact: bool = size.x < 1500
	get_parent().theme.default_font_size = 18 if compact else 20
	%LeftPanel.custom_minimum_size.x = 220 if compact else 240
	%RightPanel.custom_minimum_size.x = 320 if compact else 340
	for side in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 16 if compact else 24)


func _show_notes() -> void:
	%InfoDialog.title = "手记"
	%InfoDialog.dialog_text = "尚无已接入的手记。\n调查记录、人物笔记与已发现线索将在此整理。"
	%InfoDialog.popup_centered(Vector2i(680, 220))


func _show_menu() -> void:
	%InfoDialog.title = "菜单"
	%InfoDialog.dialog_text = "当前为界面与导航阶段。\n设置与存档功能尚未开放。"
	%InfoDialog.popup_centered(Vector2i(680, 220))


func _show_law(index: int) -> void:
	%InfoDialog.title = "王国法则 · %d" % (index + 1)
	%InfoDialog.dialog_text = LAWS[index]
	%InfoDialog.popup_centered(Vector2i(680, 180))
