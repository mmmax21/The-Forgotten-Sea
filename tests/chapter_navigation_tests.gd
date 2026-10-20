extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for chapter in ["trial1","market_chapter","academy_chapter","forest_chapter","royal_chapter"]:
  var scene=load("res://scenes/"+chapter+".tscn").instantiate()
  scene.save_path="/tmp/navigation-%s-%d.json" % [chapter,OS.get_process_id()]
  root.add_child(scene)
  await process_frame
  scene.state.presentation={}
  scene._refresh()
  var titles: Array=[]
  for b in scene.get_node("Design/TopBar").button_row().get_children(): titles.append(b.text)
  check(titles==["进度","材料","人物","设置"],chapter+" unified toolbar")
  var before: Dictionary=scene.state.to_data().duplicate(true)
  for page in ["journal","evidence","people"]:
   scene._toolbar(page)
   check(scene.overlay.visible,chapter+" opens "+page)
   check(scene.overlay_body.get_child_count()>1,chapter+" page has content "+page)
   scene.overlay.hide()
  check(scene.state.to_data()==before,chapter+" browsing does not mutate gameplay")
  for action in scene.actions.get_children():
   if action is Button: check(not action.visible or not action.disabled,chapter+" no visible locked action")
  if chapter in ["forest_chapter","royal_chapter"]:
   scene.state.origin["people"]={"er":{"t":60,"a":65,"closed":true}}
   scene.state.prior_contacts["er"]="suspended" if chapter=="forest_chapter" else {"status":"protected","due":0}
   scene._toolbar("people")
   var content := ""
   for child in scene.overlay_body.get_children():
    if child is Label: content+=child.text
   check(content.contains("二笔") and content.contains("目前："),chapter+" inherited contact status")
   scene.overlay.hide()
  scene.state.ap=0
  scene._refresh()
  scene._toolbar("journal")
  check(scene.overlay.visible,chapter+" progress readable without AP")
  check(scene.state.ap==0,chapter+" AP hint simulation is read-only")
  scene.overlay.hide()
  scene._toolbar("map")
  check(scene.map_modal.visible,chapter+" map remains available")
  scene.queue_free()
  await process_frame
 print("NAVIGATION: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
