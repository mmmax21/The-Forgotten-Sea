extends Control
var layer := "masonry"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var r := Rect2(size.x*0.16,size.y*0.32,size.x*0.68,maxf(12,size.y*0.30))
	var stone := Color(0.34,0.37,0.37)
	match layer:
		"masonry":
			draw_rect(r,Color(0.12,0.14,0.15))
			draw_line(r.position,r.position+Vector2(r.size.x,0),stone,3)
			draw_line(r.position+Vector2(0,r.size.y),r.end,stone,3)
			for index in range(9):
				var x := r.position.x+r.size.x*index/8
				draw_line(Vector2(x,r.position.y-6),Vector2(x,r.position.y+3),stone,1)
				draw_line(Vector2(x,r.end.y-3),Vector2(x,r.end.y+6),stone,1)
		"dry":
			for index in range(6):
				var c := r.position+Vector2(r.size.x*(index+0.5)/6,r.size.y*0.55)
				draw_polyline(PackedVector2Array([c-Vector2(8,3),c,c+Vector2(3,-5)]),Color(0.32,0.28,0.25),1,true)
		"signs":
			for index in range(4):
				var c := r.position+Vector2(r.size.x*(index+1)/5,r.size.y*0.5)
				draw_arc(c,4,0,PI,8,Color(0.42,0.65,0.59),1.5,true)
		"water":
			draw_rect(Rect2(r.position+Vector2(0,4),r.size-Vector2(0,8)),Color(0.19,0.36,0.36))
			for index in range(5):
				var c := r.position+Vector2(r.size.x*(index+0.4)/5,r.size.y*0.5)
				draw_line(c,c+Vector2(r.size.x/12,0),Color(0.45,0.66,0.65),1,true)
		"tide":
			for index in range(3):
				var y := r.position.y+r.size.y*(index+1)/4
				draw_dashed_line(Vector2(r.position.x-12,y),Vector2(r.end.x+12,y),Color(0.58,0.72,0.67),1,6)
			draw_line(Vector2(r.end.x+16,r.position.y),Vector2(r.end.x+16,r.end.y),Color(0.65,0.76,0.71),2)
