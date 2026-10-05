extends Control
const Layer = preload("res://scripts/ui/canal_layer.gd")
var layers: Dictionary = {}
var caption: Label
var marker: Button
var notices: HBoxContainer
signal target_selected(target: String)
var target := ""
var state := "unknown"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in ["masonry","dry","signs","water","tide"]:
		var canvas := Layer.new()
		canvas.layer = id
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(canvas)
		layers[id] = canvas
	caption = Label.new()
	caption.add_theme_font_size_override("font_size",14)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	marker=Button.new()
	marker.text="◇ 调查线索"
	marker.add_theme_font_size_override("font_size",13)
	marker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	marker.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	marker.pressed.connect(func(): target_selected.emit(target))
	add_child(marker)
	notices=HBoxContainer.new()
	notices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notices.grow_vertical=Control.GROW_DIRECTION_BEGIN
	add_child(notices)
func display(view: Dictionary, has_lead: bool) -> void:
	state=view.state
	target=view.target_id
	caption.text=view.label
	for id in layers:
		layers[id].visible=id in view.layers
	marker.visible=has_lead
func show_notices(items: Array) -> void:
	for child in notices.get_children():
		notices.remove_child(child)
		child.queue_free()
	var grouped: Dictionary = {}
	for item in items:
		if not grouped.has(item.target_id):
			grouped[item.target_id] = []
		grouped[item.target_id].append(item.text)
	for target_id in grouped:
		var texts: Array = grouped[target_id]
		var button:=Button.new()
		button.text=texts[0] + ("（另 %d 项）" % (texts.size()-1) if texts.size()>1 else "")
		button.tooltip_text="\n".join(texts)+"\n点击仅查看目标，不执行调查。"
		button.add_theme_font_size_override("font_size",12)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.clip_text=true
		button.pressed.connect(func():target_selected.emit(target_id))
		notices.add_child(button)
