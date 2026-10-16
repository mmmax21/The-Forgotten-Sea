@tool
extends PanelContainer
signal dialogue_finished

var _lines: Array = []
var _line_index := -1
## 与顶栏共享木质雕花贴图。默认留空，文本可在检查器或通过数据接口设置。

@export_multiline var dialogue_text: String = "":
	set(value):
		dialogue_text = value
		if is_node_ready():
			%Text.text = value


func _ready() -> void:
	%Text.text = dialogue_text
	resized.connect(_resize_backdrop)
	_resize_backdrop()
	%Text.mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_dialogue_input)


func apply_engine(data: Dictionary) -> void:
	if data.has("lines"):
		show_lines(data.lines)
	else:
		show_text(str(data.get("text", "")))


## 直接喂一段文字。多用于开发预览：点选角色时显示该角色的台词。
func show_text(text: String) -> void:
	_lines.clear()
	_line_index = -1
	dialogue_text = text
	if is_node_ready():
		%Text.scroll_to_line(0)


## speaker 留空表示旁白；有名字时显示“名字：台词”。最后一段保留，再点击结束。
func show_lines(lines: Array) -> void:
	_lines = lines.duplicate(true)
	_line_index = -1
	advance()


func advance() -> void:
	if _lines.is_empty():
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_lines.clear()
		_line_index = -1
		dialogue_finished.emit()
		return
	var line: Dictionary = _lines[_line_index]
	var speaker := str(line.get("speaker", ""))
	dialogue_text = (speaker + "：" if not speaker.is_empty() else "") + str(line.get("text", ""))
	%Text.scroll_to_line(0)


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		accept_event()


func _resize_backdrop() -> void:
	$Backdrop/Fill.position = Vector2(108, 64)
	$Backdrop/Fill.size = Vector2(maxf(0, size.x - 216), maxf(0, size.y - 128))
