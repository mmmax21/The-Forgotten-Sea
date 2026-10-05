extends Button
var pattern := "unknown"
func configure(index: int, view: Dictionary) -> void:
	pattern = view.pattern
	text = "%02d %s · %s" % [index+1,view.title,view.label]
	tooltip_text = view.description
	add_theme_font_size_override("font_size",16)
	queue_redraw()
func _draw() -> void:
	var c := Vector2(13,size.y/2)
	var color := Color(0.72,0.71,0.64)
	var rect := Rect2(c-Vector2(6,10),Vector2(12,20))
	if pattern=="unknown":
		draw_circle(c,2,color)
		return
	if pattern != "broken":
		draw_rect(rect,color,false,1)
	else:
		draw_line(c+Vector2(-6,-10),c+Vector2(-6,7),color,1)
		draw_line(c+Vector2(6,-6),c+Vector2(6,10),color,1)
	if pattern in ["hairline","split","broken"]:
		draw_polyline(PackedVector2Array([c+Vector2(1,-10),c+Vector2(-2,-2),c+Vector2(2,2),c+Vector2(-1,10 if pattern!="hairline" else 4)]),color,1.5 if pattern!="hairline" else 1,true)
