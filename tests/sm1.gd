extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var State = preload("res://scripts/story/study_city/state.gd")
	var s = State.new()
	print("StudyCity: day=", s.day, " ap=", s.ap)
	quit(0)
