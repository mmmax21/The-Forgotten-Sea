extends Button
## 纹样只来自当地信念映射；每日占用另用文字，不影响纹样亮度。
var pattern := "unknown"
func configure(idea_name: String, belief: Dictionary, usage: Dictionary) -> void:
	pattern = belief.pattern
	text = "%s\n当地信念：%s  |  %s" % [idea_name, belief.label, usage.label]
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_font_size_override("font_size", 14)
	var style: StyleBox = get_theme_stylebox("normal").duplicate()
	style.content_margin_left = 62
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, style)
	custom_minimum_size.y = 64
	tooltip_text = usage.reason + "\n牌面纹样：" + {"fragment":"残缺", "emerging":"纹样浮现", "complete":"完整", "unknown":"尚未知晓"}[pattern] + "；仅表示当地信念，与证据数量、每日使用无关。"
	queue_redraw()
func _draw() -> void:
	var color := Color(0.37,0.51,0.49) if pattern in ["fragment","unknown"] else Color(0.48,0.70,0.66) if pattern=="emerging" else Color(0.65,0.88,0.80)
	var rect := Rect2(10,5,38,size.y-10)
	draw_rect(rect,color,false,1)
	var c := rect.get_center()
	draw_line(Vector2(c.x,rect.position.y+3), Vector2(c.x+4,rect.position.y+8),color,1)
	draw_line(Vector2(c.x+4,rect.position.y+8), Vector2(c.x,rect.position.y+13),color,1)
	if pattern=="unknown":
		draw_circle(c,2,color)
		return
	var angle := PI*0.65 if pattern=="fragment" else PI*1.4 if pattern=="emerging" else TAU
	draw_arc(c,12,-PI/2,angle-PI/2,24,color,1.5,true)
	for index in range(2 if pattern=="fragment" else 5 if pattern=="emerging" else 8):
		var direction := Vector2.from_angle(float(index)*TAU/8)
		draw_line(c+direction*4,c+direction*10,color,1,true)
	if pattern=="complete":
		draw_arc(c,15,0,TAU,32,color,1,true)
