extends Control
## 居中的通知弹窗。不读存档。
##
## 场景结构（scenes/ui/popup/notice.tscn）：
## - Shade：全屏遮罩，挡住底层点击，点遮罩不关闭。
## - Panel：640×840，与 notice_background.png 同大，锚在屏幕中心。
## - CloseButton：右上角，距右、距上各 16。图标是 Icons.png 第 3 行第 5 格。
## - Body：标题、图片、正文。四边内容边距 48，顶边从关闭按钮下沿再空 8px。
##
## 数据引擎只调用 apply_engine(data)。字段见 docs/data_formats.md 的「通知弹窗」。
## open() 负责显示。标题、图片路径、正文为空就不显示，不留空位。

signal closed

const PANEL_WIDTH := 640.0
const CONTENT_MARGIN := 48.0
const CONTENT_WIDTH := PANEL_WIDTH - CONTENT_MARGIN * 2.0
const IMAGE_MAX_HEIGHT := 420.0
const PLATE_MARGIN := 24
const PARCHMENT := Color(0.93, 0.88, 0.78, 1)
const EDGE := Color(0.28, 0.22, 0.16, 1)
const INK := Color(0.28, 0.16, 0.05, 1)
const ICON_SIZE := 48
const ICON_HOVER := Color(0.62, 0.62, 0.62, 1)

## 面板底图。没有图时用米色占位。有图时四边各 24px 不拉伸，盖住木边和撕边。
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_apply_background()

var _pending := {}
var _shown := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_background()
	_style_close()
	_apply_fonts()
	%BodyText.custom_minimum_size.x = CONTENT_WIDTH
	%TextScroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	%TextScroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	%CloseButton.pressed.connect(_close)
	if _pending.is_empty() and get_tree().current_scene == self:
		_pending = _preview_payload()
		_shown = true
	if not _pending.is_empty():
		_apply_pending()
	visible = _shown


## 数据引擎入口。title、image、text 缺省或空字符串都视为不显示。
## image 可以是资源路径，也可以直接给 Texture2D。路径载入失败当作没有图片。
func apply_engine(data: Dictionary) -> void:
	var image = data.get("image", "")
	if not image is Texture2D:
		image = _text_field(data, "image")
	_pending = {
		"title": _text_field(data, "title"),
		"image": image,
		"text": _text_field(data, "text"),
	}
	if is_node_ready():
		_apply_pending()


## 显示当前内容。还没有传入数据时，用预览字典。
func open() -> void:
	if _pending.is_empty():
		apply_engine(_preview_payload())
	_shown = true
	if is_node_ready():
		_apply_pending()
		show()


func _close() -> void:
	_shown = false
	hide()
	closed.emit()


func _apply_pending() -> void:
	_show_title(str(_pending.get("title", "")))
	_show_picture(_pending.get("image", ""))
	_show_text(str(_pending.get("text", "")))


func _show_title(title: String) -> void:
	%Title.visible = not title.is_empty()
	%Title.text = title


func _show_picture(image) -> void:
	var texture: Texture2D = image if image is Texture2D else _load_texture(str(image))
	%PictureSlot.visible = texture != null
	%Picture.texture = texture
	if texture == null:
		return
	var tex_size := texture.get_size()
	var width := CONTENT_WIDTH
	var height := IMAGE_MAX_HEIGHT
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		height = width * tex_size.y / tex_size.x
		if height > IMAGE_MAX_HEIGHT:
			height = IMAGE_MAX_HEIGHT
			width = height * tex_size.x / tex_size.y
	%Picture.custom_minimum_size = Vector2(width, height)


func _show_text(body: String) -> void:
	%TextScroll.visible = not body.is_empty()
	%BodyText.text = body
	%TextScroll.scroll_vertical = 0


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	if loaded is Texture2D:
		return loaded
	return null


func _apply_background() -> void:
	var panel: Panel = %Panel
	if background != null:
		var textured := StyleBoxTexture.new()
		textured.texture = background
		textured.texture_margin_left = PLATE_MARGIN
		textured.texture_margin_right = PLATE_MARGIN
		textured.texture_margin_top = PLATE_MARGIN
		textured.texture_margin_bottom = PLATE_MARGIN
		panel.add_theme_stylebox_override("panel", textured)
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = PARCHMENT
	flat.border_color = EDGE
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", flat)


func _style_close() -> void:
	var button: Button = %CloseButton
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.mouse_entered.connect(_paint_close)
	button.mouse_exited.connect(_paint_close)
	_paint_close()


func _paint_close() -> void:
	%CloseButton.modulate = ICON_HOVER if %CloseButton.is_hovered() else Color.WHITE


func _apply_fonts() -> void:
	var font := _font()
	%Title.add_theme_font_override("font", font)
	%Title.add_theme_font_size_override("font_size", 32)
	%Title.add_theme_color_override("font_color", INK)
	%BodyText.add_theme_font_override("font", font)
	%BodyText.add_theme_font_size_override("font_size", 22)
	%BodyText.add_theme_color_override("font_color", INK)


func _text_field(data: Dictionary, key: String) -> String:
	var value = data.get(key, "")
	if value == null:
		return ""
	return str(value).strip_edges()


## 单独用 F6 打开本场景时用。正式运行由数据引擎调用 apply_engine。
func _preview_payload() -> Dictionary:
	return {
		"title": "潮汐将至",
		"image": "res://assets/portraits/default_characters.png",
		"text": "北面的网已经收起。今天先不要出镇。",
	}


func _font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "Microsoft YaHei", "微软雅黑"])
	return font
