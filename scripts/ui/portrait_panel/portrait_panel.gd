extends Control
## 右侧立绘面板。收到 character_selected 后，把对应立绘从右滑入；立绘默认隐藏。
## 位置由调用方在 .tscn 里设置；高度跟画布适配。

const DefaultCharacters := preload("res://scripts/ui/character_card/default_characters.gd")

const SLIDE_DURATION := 0.32
## 滑入距离：比自身宽度再多 40px，确保完全收在屏幕外。
const SLIDE_OFFSET := 400.0

@onready var _image: TextureRect = %Image
@onready var _name_label: Label = %NameLabel
@onready var _quote_label: Label = %QuoteLabel
@onready var _tween: Tween = null

var _shown_index: int = -1
var _rest_x := 0.0


func _ready() -> void:
	# 初始时立在屏幕外右侧，调用 show_portrait() 时滑入。
	if _image == null or _name_label == null or _quote_label == null:
		return
	_image.modulate.a = 0.0
	_name_label.modulate.a = 0.0
	_quote_label.modulate.a = 0.0
	# 把面板默认放在屏幕外（如果当前 x=0，移到 x=400）
	_rest_x = position.x
	position.x = _rest_x + SLIDE_OFFSET
	visible = true
	# 面板本身不拦截鼠标，让空白处点击事件能冒泡到上层。
	# 但 _image 等子节点会自然吃事件（默认 mouse_filter=0），点立绘本身不会冒泡。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 当前是否在显示状态。
func is_visible_now() -> bool:
	return _shown_index >= 0


## 用调用方传来的立绘滑入。index 只用来取一句短台词。
func show_given(portrait: Texture2D, actor_name: String, index: int = 0) -> void:
	if _image == null or _name_label == null or _quote_label == null:
		return
	_shown_index = index
	_image.texture = portrait
	_name_label.text = actor_name
	_quote_label.text = _quote_for(index)
	_slide_in()


## 显示 index 号立绘，name/quote 填到标签。quote 留空就只显示立绘。
func show_portrait(index: int, name: String = "", quote: String = "") -> void:
	if index < 0 or index > 3:
		return
	if _image == null or _name_label == null or _quote_label == null:
		return
	_shown_index = index
	_image.texture = DefaultCharacters.wholebody(index)
	_name_label.text = name
	# 简易台词：原 summary 取前 30 字。
	if quote.is_empty() and not name.is_empty():
		quote = _quote_for(index)
	_quote_label.text = quote
	_slide_in()


## 收回立绘（可选，目前组件不主动调用，留给上层）。
func hide_portrait() -> void:
	_shown_index = -1
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:x", _rest_x + SLIDE_OFFSET, SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_image, "modulate:a", 0.0, SLIDE_DURATION)
	_tween.tween_property(_name_label, "modulate:a", 0.0, SLIDE_DURATION)
	_tween.tween_property(_quote_label, "modulate:a", 0.0, SLIDE_DURATION)


func _slide_in() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position:x", _rest_x, SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_image, "modulate:a", 1.0, SLIDE_DURATION)
	_tween.tween_property(_name_label, "modulate:a", 1.0, SLIDE_DURATION)
	_tween.tween_property(_quote_label, "modulate:a", 1.0, SLIDE_DURATION)


func _quote_for(index: int) -> String:
	match index:
		0: return "（点头，把木头推过来）"
		1: return "……你别问太多。"
		2: return "我捡到一枚贝壳，它会唱歌。"
		3: return "你来了。坐吧，我慢慢说。"
	return ""
