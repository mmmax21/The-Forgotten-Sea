extends SceneTree
const S=preload("res://scripts/story/forest_chapter_state.gd")
const Save=preload("res://scripts/story/forest_chapter_save.gd")
const Narrative=preload("res://scripts/story/forest_chapter_story.gd")
const Royal=preload("res://scripts/story/royal_chapter_state.gd")
const BASE=[["platform","roster","lead_compare","tower_locate"],["tower_enter","tower_search"],["verify_history","preserve"],[],[]]
const PUBLIC=[["platform","roster","lead_compare","el_help"],["tower_locate","tower_enter"],["tower_search","verify_history","preserve"],["sea_basis","witnesses","corroborate"],["public_demo","protect_el"]]
var checks=0
var failures=0
var scene
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func act(s,id: String,help := false):
 var before: Dictionary=s.to_data()
 var p: Dictionary=s.preview(id,help)
 check(before==s.to_data(),"Preview pure "+id)
 check(p.allowed,"Allowed "+id+": "+p.text)
 check(s.execute(id,help),"Execute "+id)
func reject(s,id: String,help := false):
 var before: Dictionary=s.to_data()
 check(not s.execute(id,help),"Reject "+id)
 check(before==s.to_data(),"Rejected atomic "+id)
func route(days: Array,seed: Dictionary={}):
 var s=S.new();s.initialize(seed)
 for actions in days:
  for id in actions: act(s,id)
  check(s.end_day(),"End day")
 return s
func run():
 var safe=route(BASE)
 check(safe.success() and safe.spent==8 and safe.belief==0 and safe.deliveries.is_empty(),"8 AP independent preservation")
 var small_days=BASE.duplicate(true);small_days[3]=["sea_share"]
 var small=route(small_days)
 check(small.investigation_shared() and small.belief==0 and not small.has("flight_sign"),"Flight-history readers do not automatically believe ocean")
 var r=Royal.new();r.initialize(small.snapshot)
 check(r.heritage.flight_proof and not r.reader_ready("forest"),"Royal foundation accepts evidence dissemination without lift, ocean readers distinct")
 var forged=small.snapshot.duplicate(true);forged.evidence.erase("wing_bones")
 var missing=Royal.new();missing.initialize(forged)
 check(not missing.heritage.flight_proof,"Royal checks actual evidence, not a success flag")
 var r_safe=Royal.new();r_safe.initialize(safe.snapshot)
 check(not r_safe.heritage.flight_proof,"Preservation alone cannot substitute for dissemination")
 var public=route(PUBLIC)
 check(public.success() and public.spent==15 and public.has("flight_sign") and public.belief==20 and public.warnings.is_empty(),"15 AP public sea explanation, lift and protection")
 var no_lift_days=PUBLIC.duplicate(true);no_lift_days[3]=["sea_basis","witnesses"]
 var no_lift=route(no_lift_days)
 check(no_lift.investigation_shared() and not no_lift.has("flight_sign"),"Public success without optional lift")
 var nobles=route([["platform","lo_help","lo_memory","lead_compare"],["ika_help","tower_permit","tower_search"],["verify_history","preserve","sea_basis"],["witnesses","corroborate","select_ika"],["public_demo","protect_ika"]])
 check(nobles.success() and nobles.has("flight_sign") and nobles.flags.public_participant=="ika","Noble access and optional public support do not imply special flight bloodline")
 var after=route([[],[],[],[]]);reject(after,"tower_locate");reject(after,"tower_search")
 var empty_tower=route([["platform","roster","lead_compare","tower_locate"],["tower_enter"],[],[]])
 reject(empty_tower,"tower_search")
 check(not empty_tower.success(),"Entering before closure does not grant late evidence")
 var late_verify=route([["platform","roster","lead_compare","tower_locate"],["tower_enter"],[],["tower_search"],["verify_history","preserve","sea_share"]])
 check(late_verify.success() and late_verify.investigation_shared(),"Held evidence may be verified after closure")
 var unready=S.new();unready.initialize({});reject(unready,"ika_help");reject(unready,"first_trial");reject(unready,"replicate")
 act(unready,"platform");reject(unready,"ika_help")
 var pressure=route(PUBLIC.slice(0,4));pressure.official_alert=60
 reject(pressure,"public_demo")
 act(pressure,"discreet");act(pressure,"public_demo")
 check(pressure.official_alert==60,"Visible pressure can be mitigated before public action")
 var fallback=route(PUBLIC.slice(0,4));fallback.official_alert=80
 act(fallback,"sea_share");check(fallback.belief==10,"Private alternative remains possible under patrol pressure")
 var no_seat=route(BASE.slice(0,4));reject(no_seat,"witnesses");reject(no_seat,"public_demo")
 var seed={"origin":{"origin":{"evidence":{"F":{"holder":"player"}}}}}
 var supplements=route(BASE.slice(0,3),seed)
 act(supplements,"sea_share");check(supplements.belief==0,"No ocean reward for flight evidence")
 act(supplements,"sea_basis");act(supplements,"sea_supplement");check(supplements.belief==10,"New coast evidence only reaches existing readers after supplement")
 supplements.end_day();act(supplements,"cross_region");act(supplements,"sea_supplement")
 check(supplements.belief==20,"Independent evidence pays only delta")
 reject(supplements,"sea_supplement")
 var stored=S.new();stored.initialize({"evidence":{"F":{"holder":"elder"}}});reject(stored,"cross_region")
 var supported=S.new();supported.initialize({"findings":{"rescue_extra":true},"channels":{"independent_archive":true,"public_record":true}})
 check(supported.has("tower_locate") and not supported.has("wing_bones"),"Notebook provides entrance, not evidence")
 act(supported,"platform");act(supported,"roster",true);act(supported,"lead_compare");act(supported,"tower_enter",true)
 check(supported.discount_used==2 and not supported.support_available("witnesses"),"Two explicit support discounts maximum")
 var before_story: Dictionary=public.to_data()
 Narrative.opening(public);Narrative.stage(public);Narrative.greeting(public,"ika");Narrative.action(public,"public_demo");Narrative.departure(public)
 check(before_story==public.to_data(),"Narrative pure")
 check(not str(Narrative.departure(after)).contains("疯祭司的签名"),"No invented signature")
 var path="/tmp/forest-v2-%d.json" % OS.get_process_id()
 check(Save.save_to(path,public)==OK,"Save")
 var loaded=Save.load_from(path)
 check(loaded.ok and loaded.state.to_data()==public.to_data(),"Exact roundtrip")
 check(Save.save_to(path,safe)==OK,"Backup")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken");file.close()
 loaded=Save.load_from(path);check(loaded.ok and loaded.backup and loaded.state.to_data()==public.to_data(),"Corruption backup")
 var broken: Dictionary=public.to_data();broken.docs.erase("wing_bones")
 check(not S.new().restore(broken),"Reject verified without evidence")
 await ui_checks()
 print("FOREST V2: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)

func frames(count:=5):
 for i in count: await process_frame
func button(parent: Node,id: String):
 for child in parent.get_children():
  if child is Button and child.get_meta("action_id","")==id: return child
 return null
func activate(node: Button):
 check(node!=null,"Button exists")
 if node==null: return
 await frames()
 check(not node.disabled,"Button enabled")
 if not node.disabled: node.pressed.emit()
 await frames()
func finish_dialogue():
 var limit:=0
 while scene.busy() and limit<60:
  var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=true
  root.push_input(event)
  await frames(2)
  limit+=1
 check(not scene.busy(),"Enter completes dialogue")
func capture(label: String):
 if not OS.get_cmdline_user_args().has("--screenshot") or DisplayServer.get_name()=="headless": return
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/forest-%s-%d.png" % [label,root.size.x])
func ui_checks():
 root.size=Vector2i(1280,720)
 var path="/tmp/forest-v2-ui-%d.json" % OS.get_process_id()
 scene=load("res://scenes/forest_chapter.tscn").instantiate();scene.save_path=path
 root.add_child(scene);await frames();await finish_dialogue();await capture("v2-opening")
 scene._on_character_selected(0,"","",null);await finish_dialogue()
 check(scene.state.selected=="el","Original card interaction")
 scene._research()
 for actions in PUBLIC:
  for id in actions:
   scene._forest_preview(id)
   if id=="verify_history":
    var before: Dictionary=scene.state.to_data()
    await activate(button(scene.overlay_actions,"compare_retry"))
    check(before==scene.state.to_data(),"Wrong answer free")
    await capture("v2-compare")
    await activate(button(scene.overlay_actions,"compare_correct"))
    check(before==scene.state.to_data(),"Correct answer needs confirmation")
   if id=="public_demo": await capture("v2-public")
   await activate(button(scene.overlay_actions,"execute"))
   if id=="tower_search":
    var paid: int=scene.state.ap
    scene.queue_free();await frames()
    scene=load("res://scenes/forest_chapter.tscn").instantiate();scene.save_path=path
    root.add_child(scene);await frames()
    check(scene.busy() and scene.state.ap==paid and scene.state.has("wing_bones"),"Dialogue reload does not pay or grant twice")
   await finish_dialogue()
  await activate(scene.end_button);await activate(button(scene.overlay_actions,"confirm_day"));await finish_dialogue()
 check(scene.state.success() and scene.state.has("flight_sign") and scene.state.spent==15,"Full real UI public route")
 await activate(button(scene.actions,"report"));await capture("v2-report")
 scene.overlay.hide()
 scene._toolbar("map");scene._map_place("royal_city")
 await activate(button(scene.overlay_actions,"enter_royal"));await frames()
 for node in root.get_children():
  if node is Control and node.get_script().resource_path.ends_with("royal_chapter.gd"): scene=node
 check(scene.state.heritage.flight_proof,"Real royal handoff accepts new foundation")
 scene.queue_free();await frames()
