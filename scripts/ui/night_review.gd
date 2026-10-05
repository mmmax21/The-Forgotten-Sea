extends PanelContainer
## 只读视图。翻页/切栏目/历史选择不触发结算或改写游戏状态。
signal advance_requested
signal history_selected(token: String)
const KEYS = ["actions", "people", "world", "kingdom"]
const TITLES = ["你的行动", "人们的后续行动", "世界的变化", "王国的回应"]
var report: Dictionary = {}
var historical := false
var category := 0
var page := 0
var status_page := false
var title_label: Label
var history_choice: OptionButton
var notice: Label
var content: VBoxContainer
var scroll: ScrollContainer
var tabs: Array[Button] = []
var previous: Button
var following: Button
var page_label: Label
var next_day: Button
var stage_button: Button

func _ready() -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 18)
	header.add_child(title_label)
	history_choice = OptionButton.new()
	history_choice.fit_to_longest_item = false
	history_choice.custom_minimum_size.x = 140
	history_choice.add_theme_font_size_override("font_size", 14)
	header.add_child(history_choice)
	history_choice.item_selected.connect(func(index): history_selected.emit(history_choice.get_item_metadata(index)))
	var close := _button("收起", header)
	close.pressed.connect(close_review)
	var row := HBoxContainer.new()
	layout.add_child(row)
	for index in range(KEYS.size()):
		var tab := _button(TITLES[index], row)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.pressed.connect(select_category.bind(index))
		tabs.append(tab)
	notice = Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", 13)
	notice.add_theme_color_override("font_color", Color(0.66, 0.76, 0.73))
	layout.add_child(notice)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 70
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	previous = _button("上一条", footer)
	previous.pressed.connect(change_page.bind(-1))
	page_label = Label.new()
	page_label.add_theme_font_size_override("font_size", 14)
	footer.add_child(page_label)
	following = _button("下一条", footer)
	following.pressed.connect(change_page.bind(1))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	stage_button = _button("接口状态", footer)
	stage_button.pressed.connect(func(): status_page = not status_page; _render())
	next_day = _button("进入下一天", footer)
	next_day.pressed.connect(func():
		if not historical and not next_day.disabled:
			advance_requested.emit())
	visibility_changed.connect(func(): get_parent().get_node("Content").visible = not visible)

func _button(text: String, host: Node) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
	button.custom_minimum_size.y = 36
	host.add_child(button)
	return button

func show_report(receipt: Dictionary, entries: Array = [], history_mode := false, can_advance := false) -> void:
	report = receipt.duplicate(true)
	historical = history_mode
	category = 0
	page = 0
	status_page = false
	title_label.text = "第 %d 天 · 夜间回顾%s" % [report.get("day", 1), "（历史）" if historical else ""]
	history_choice.clear()
	for entry in entries:
		history_choice.add_item("第 %d 天 · %s" % [entry.day, "预览" if entry.preview_only else "正式"])
		history_choice.set_item_metadata(history_choice.item_count - 1, entry.request_id)
		if entry.request_id == report.get("request_id", ""):
			history_choice.select(history_choice.item_count - 1)
	history_choice.visible = historical
	next_day.visible = not historical
	next_day.disabled = not can_advance
	next_day.text = "查看总结" if report.get("day", 1) == 10 else "进入第 %d 天" % (report.get("day", 1) + 1)
	show()
	_render()

func close_review() -> void:
	hide()

func select_category(index: int) -> void:
	category = clampi(index, 0, 3)
	page = 0
	status_page = false
	_render()

func change_page(offset: int) -> void:
	var records: Array = report.get("sections", {}).get(KEYS[category], [])
	page = clampi(page + offset, 0, maxi(0, records.size() - 1))
	_render()

func _text(text: String, heading := false) -> void:
	if text.is_empty():
		return
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18 if heading else 16)
	content.add_child(label)

func _render() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for index in range(tabs.size()):
		tabs[index].set_pressed_no_signal(index == category and not status_page)
	var missing: Array = report.get("steps", []).filter(func(step): return step.status == "unimplemented")
	var source := "开发预览 · 不代表正式效果" if report.get("preview_only", false) else "正式记录 · 仅含玩家已知内容"
	notice.text = source + (" · %d 项未接入，见接口状态" % missing.size() if not missing.is_empty() else "")
	var records: Array = report.get("sections", {}).get(KEYS[category], [])
	previous.disabled = status_page or page <= 0
	following.disabled = status_page or page >= records.size() - 1
	page_label.text = "%d / %d" % [page + 1, records.size()] if not records.is_empty() and not status_page else "—"
	stage_button.text = "返回结果" if status_page else "接口状态"
	if status_page:
		_text("固定顺序 · 本次执行状态", true)
		for index in range(report.get("steps", []).size()):
			var step: Dictionary = report.steps[index]
			_text("%d. %s：%s" % [index + 1, step.name, "未接入，未执行该系统" if step.status == "unimplemented" else "已处理"])
		_text(report.get("message", ""))
	elif report.get("status", "pending") != "complete":
		_text("计划已锁定 · 暂未揭晓结果", true)
		_text(report.get("message", "正在按固定顺序处理整份计划。"))
	elif records.is_empty():
		_text(TITLES[category], true)
		_text(["本日没有安排主动行动；夜间流程仍已运行。", "本次没有可公开的自主反应记录。", "本次没有可公开的世界变化记录。", "本次没有玩家已获知的王国回应记录。"][category])
		if not missing.is_empty():
			_text("未接入系统不会生成故事结果。空记录不表示后台人物必然沉默或世界没有变化。")
	else:
		var record: Dictionary = records[page]
		_text(record.title, true)
		_text(record.happened)
		_text("已知原因：" + record.reason if not record.reason.is_empty() else "")
		_text("行动方向：" + record.direction if not record.direction.is_empty() else "")
	scroll.scroll_vertical = 0
