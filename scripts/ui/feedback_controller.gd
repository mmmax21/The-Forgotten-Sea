extends Node
## 正式反馈只消费结算快照；DEBUG 测试通过独立八步结算器注入预览快照。
const Service = preload("res://scripts/night_settlement.gd")
var ui: MarginContainer
var seen: Dictionary = {}
var notifications: Array = []
var notification_count := 0
var testing := false
var serial := 0
var test_service := Service.new()
var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://preview_data/feedback_states.json"))
var selected_profile: Dictionary = {}
func _ready() -> void:
	ui=%GameScreen
	ui.visual_feedback=self
	ui.knowledge.settled_changed.connect(_on_commit)
	ui.profile_changed.connect(func(_preview): notifications.clear(); refresh())
	%SceneCanvas.target_selected.connect(ui.select_target)
	for profile in fixture.profiles:
		%FeedbackPreset.add_item(profile.label)
	%ApplyFeedback.pressed.connect(func(): apply_preview(%FeedbackPreset.selected))
	test_service.set_adapter("reality",_preview_adapter,true)
	test_service.batch_ready.connect(_test_ready)
	refresh()
func refresh() -> void:
	var snapshot: Dictionary=ui.knowledge.get_snapshot()
	for index in range(3):
		get_node("%Law"+str(index+1)).configure(index,ui.feedback.law(snapshot,index))
	var view: Dictionary=ui.feedback.scene(snapshot)
	var target: Dictionary=ui.knowledge.target_view(view.target_id)
	%SceneCanvas.display(view,target.get("has_lead",false) and target.get("location_id","")==ui.knowledge.current_location_id())
	%SceneCanvas.show_notices(notifications)
	%FeedbackPreset.disabled=not ui.knowledge.preview_enabled or testing or not ui.planning.can_debug_advance()
	%ApplyFeedback.disabled=%FeedbackPreset.disabled
func _on_commit(before: Dictionary, after: Dictionary, id: String) -> void:
	var key:=str(after.get("preview_only",false))+":"+id
	if seen.has(key):
		return
	seen[key]=true
	var fresh: Array=ui.feedback.changes(before,after).filter(func(item): return ui.knowledge.is_known(item.target_id))
	if before.get("current_location_id", "") != after.get("current_location_id", ""):
		notifications.clear()
	if not fresh.is_empty():
		notifications=fresh
	notification_count+=fresh.size()
	refresh()
func clear_run() -> void:
	notifications.clear()
	refresh()
func apply_preview(index: int) -> bool:
	if testing or not ui.knowledge.preview_enabled or not ui.planning.can_debug_advance() or index<0 or index>=fixture.profiles.size():
		return false
	testing=true
	serial+=1
	selected_profile=fixture.profiles[index].duplicate(true)
	var snapshot: Dictionary=ui.knowledge.get_snapshot()
	var payload: Dictionary={"request_id":"feedback-test:%d"%serial,"day":ui.planning.plan.day,"preview_only":true,"entries":[],"initial_location":snapshot.current_location_id,"budget":3}
	test_service.submit(payload,{},snapshot)
	refresh()
	return true
func _preview_adapter(context: Dictionary) -> Dictionary:
	var world: Dictionary=context.world
	# 只替换配置中的镇区；不移动玩家、不改日期、不揭示任何正式资料。
	world.regional_feedback[fixture.region_id]=selected_profile.region.duplicate(true)
	world.idea_beliefs[fixture.region_id]=selected_profile.beliefs.duplicate(true)
	var known: Dictionary=world.known_targets[fixture.target_id]
	if selected_profile.investigation_open and fixture.clue_id not in known.fact_ids:
		known.fact_ids.append(fixture.clue_id)
	known.investigation_open=selected_profile.investigation_open
	world.known_routes.boundary=selected_profile.boundary_route.duplicate(true)
	return {"status":"complete","world":world}
func _test_ready(receipt: Dictionary) -> void:
	if receipt.status=="complete":
		ui.knowledge.apply_settled_snapshot(test_service.committed_world(receipt.request_id),receipt.request_id)
		ui.refresh_known_targets()
		ui.planning._on_plan_changed()
	testing=false
	refresh()
