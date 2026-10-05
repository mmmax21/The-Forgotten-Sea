extends PanelContainer
signal edit_requested(index: int)
signal remove_requested(index: int)
signal reorder_requested(index: int, offset: int)
var owner_index := -1
var title_label: Label
var summary_label: Label
var edit_button: Button
var remove_button: Button
var up_button: Button
var down_button: Button

func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 17)
	box.add_child(title_label)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_font_size_override("font_size", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 64
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	scroll.add_child(summary_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	box.add_child(buttons)
	var created: Array[Button] = []
	for caption in ["修改", "删除", "↑", "↓"]:
		var button := Button.new()
		button.text = caption
		button.add_theme_font_size_override("font_size", 14)
		button.custom_minimum_size.y = 36
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
		created.append(button)
	edit_button = created[0]
	remove_button = created[1]
	up_button = created[2]
	down_button = created[3]
	edit_button.pressed.connect(func(): edit_requested.emit(owner_index))
	remove_button.pressed.connect(func(): remove_requested.emit(owner_index))
	up_button.pressed.connect(func(): reorder_requested.emit(owner_index, -1))
	down_button.pressed.connect(func(): reorder_requested.emit(owner_index, 1))

func display(slot: int, item: Dictionary, entry: Dictionary, locked: bool, count: int) -> void:
	var title: String = ["行动一", "行动二", "行动三"][slot]
	owner_index = item.get("index", -1)
	if owner_index < 0:
		title_label.text = title + " · 空位"
		summary_label.text = "尚未安排\n可保留空余 AP"
		tooltip_text = ""
	else:
		var continuing: bool = slot != item.slot
		title_label.text = title + (" · 连续占用" if continuing else " · %d AP" % entry.ap_cost)
		if continuing:
			summary_label.text = "属于行动%s的移动\n%s\n整项 %d AP，不可拆分" % [["一", "二", "三"][item.slot], entry.target_name, entry.ap_cost]
		else:
			summary_label.text = "%s · %s · %s\n%s" % [entry.target_name, entry.behavior_name, entry.scale_name, entry.idea_name]
			if not item.errors.is_empty():
				summary_label.text += "\n需修正：查看提示"
			elif not item.dependency.is_empty():
				summary_label.text += "\n依赖前面的移动成功"
		tooltip_text = "\n".join(item.errors) + "\n" + item.dependency
		remove_button.tooltip_text = "删除整个行动（%d AP），包括连续占位。" % entry.ap_cost
	summary_label.tooltip_text = summary_label.text
	up_button.tooltip_text = "将完整行动前移一位"
	down_button.tooltip_text = "将完整行动后移一位"
	edit_button.disabled = locked or owner_index < 0
	remove_button.disabled = locked or owner_index < 0
	up_button.disabled = locked or owner_index <= 0
	down_button.disabled = locked or owner_index < 0 or owner_index >= count - 1
