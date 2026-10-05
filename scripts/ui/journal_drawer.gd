extends Control
signal read_changed
var entries: Array = []
var seen: Dictionary = {}
var category := 0
var content: VBoxContainer
var list: VBoxContainer
var detail: Label
var help: Button
const CATEGORIES := ["玛瑞斯的痕迹", "已知线索", "人物记录", "往日回顾"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.55
	panel.offset_top = 65
	panel.offset_bottom = -16
	panel.offset_right = -16
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var label := Label.new()
	label.text = "手记 · 仅记录本局已知内容"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	header.add_child(label)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(hide)
	header.add_child(close)
	var tabs := GridContainer.new()
	tabs.columns = 2
	content.add_child(tabs)
	for i in range(4):
		var button := Button.new()
		button.text = CATEGORIES[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): category = i; render())
		tabs.add_child(button)
	help = Button.new()
	help.text = "重看操作说明"
	help.pressed.connect(func(): detail.text = "选择目标 → 选择行为 → 规模 → 可选思想卡 → 加入今日计划。\n\n每天 3 AP；计划可修改，夜间统一执行。查看资料和阅读剧情不扣 AP。\n\n调查仅对已开放线索可用；群体行动依组织条件解锁。\n\n危机通知不会替你执行保护行动。")
	content.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hide()

func refresh(values: Array) -> void:
	entries = values.duplicate(true)
	if visible: render()
	read_changed.emit()

func unread() -> bool:
	return entries.any(func(item): return seen.get(item.id, "") != item.text)

func open() -> void:
	show()
	render()

func render() -> void:
	if detail.get_parent() != null: detail.get_parent().remove_child(detail)
	for node in list.get_children():
		list.remove_child(node)
		node.queue_free()
	var count := 0
	for entry in entries:
		if int(entry.category) != category: continue
		count += 1
		var button := Button.new()
		button.text = ("• " if seen.get(entry.id, "") != entry.text else "") + entry.title
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_read.bind(entry))
		list.add_child(button)
	list.add_child(detail)
	detail.text = "选择一条记录阅读。" if count else "尚无已发现的记录。"

func _read(entry: Dictionary) -> void:
	seen[entry.id] = entry.text
	render()
	detail.text = entry.title + "\n\n" + entry.text
	read_changed.emit()

func _exit_tree() -> void:
	if is_instance_valid(detail) and detail.get_parent() == null: detail.free()
