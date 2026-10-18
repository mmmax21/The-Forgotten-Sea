extends SceneTree
const S := preload("res://scripts/story/forest_chapter_state.gd")
const Save := preload("res://scripts/story/forest_chapter_save.gd")
const Narrative := preload("res://scripts/story/forest_chapter_story.gd")
var checks:=0
var failures:=0
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
 check(s.to_data()==before,"Preview pure: "+id)
 check(p.allowed,"Allowed "+id+": "+p.text)
 check(s.execute(id,help),"Execute "+id)
func reject(s,id: String,help := false):
 var before: Dictionary=s.to_data()
 check(not s.execute(id,help),"Reject "+id)
 check(s.to_data()==before,"Atomic rejection "+id)
func route(days: Array,seed: Dictionary={}):
 var s=S.new();s.initialize(seed)
 for actions in days:
  for id in actions: act(s,id)
  check(s.end_day(),"End day")
 return s
func run():
 var start=[["roster","platform","verify_history"],["el_help","witnesses","prepare"]]
 var safe=route(start+[["first_trial"],["replicate"],[]])
 check(safe.success() and safe.spent==10 and safe.belief==0,"10 AP flight success is not automatic ocean belief")
 var public=route(start+[["first_trial","ban"],["replicate","trace_ban"],["public_demo","protect_el"]])
 check(public.success() and public.spent==15 and public.belief==10 and public.warnings.is_empty() and public.people.el.a==45,"15 AP protected public route")
 var tower=route(start+[["first_trial","ika_help"],["replicate","tower_permit"],["tower_observe","sea_share","protect_el"]])
 check(tower.success() and tower.belief==15 and tower.spent==15 and tower.has("signature"),"15 AP permitted tower route")
 var independent=route(start+[["first_trial","tower_locate"],["tower_enter","tower_observe"],["replicate","sea_share"]])
 check(independent.success() and independent.belief==15 and independent.people.ika.t==35,"Independent tower route does not require aristocrat")
 var lo=route([["roster","platform","verify_history"],["lo_help","witnesses","prepare"],["first_trial"],["replicate"],[]])
 check(lo.success() and lo.attempts[0].participant=="lo","Lorn can be the sole ordinary participant")
 var two=route(start+[["first_trial","lo_help"],["select_lo","replicate"],[]])
 check(two.snapshot.social_results.second_participant and two.attempts[0].participant=="el","Changing participant preserves original record")
 var early=route(start)
 act(early,"first_trial")
 check(not early.success(),"One attempt does not clear chapter")
 early.ap=3
 reject(early,"replicate")
 early.end_day();act(early,"replicate")
 reject(early,"first_trial")
 var noble=S.new();noble.initialize({})
 act(noble,"ika_help")
 reject(noble,"witnesses");reject(noble,"first_trial")
 check(noble.participant.is_empty(),"Aristocrat is never an ordinary participant")
 var no_prep=route([["roster","platform","verify_history"],["el_help","witnesses"]])
 reject(no_prep,"first_trial")
 var late=route([[],[],[],[]])
 reject(late,"first_trial")
 late.end_day();check(late.finished and not late.success(),"Partial route can leave")
 var missed_public=route(start+[[],["first_trial"]])
 act(missed_public,"replicate")
 reject(missed_public,"public_demo")
 var exposure=route(start+[["first_trial"],["replicate"],["public_demo"]])
 check(exposure.snapshot.warnings.el==21 and not exposure.people.el.closed and exposure.success(),"Final-day pressure is exported, never deletes flight")
 var closed=S.new();closed.initialize({});closed.people.el.a=65;closed.sync_risk()
 closed.end_day();closed.end_day()
 check(closed.people.el.closed,"Announced risk closes future cooperation on due day")
 var support_seed={"channels":{"independent_archive":true,"public_record":true},"findings":{"rescue_extra":true,"file_full":true},"next_turn":30}
 var helped=S.new();helped.initialize(support_seed)
 check(helped.entry_turn==30 and helped.has("tower_locate"),"Inherited notes locate entry without spending discount")
 act(helped,"roster",true);act(helped,"platform");act(helped,"verify_history");act(helped,"el_help")
 check(helped.ap==0 and helped.discount_used==1,"Player explicitly takes first discount")
 act(helped,"witnesses",true)
 check(helped.ap==0 and helped.discount_used==2,"Supported action can execute with zero AP")
 helped.end_day()
 reject(helped,"tower_enter",true)
 act(helped,"tower_enter")
 check(helped.ap==1 and helped.discount_used==2,"Third discount blocked but full-price action remains available")
 var optional=S.new();optional.initialize(support_seed)
 act(optional,"roster")
 check(optional.discount_used==0 and optional.ap==2,"Ignoring support preserves quota")
 var tower_help=S.new();tower_help.initialize(support_seed)
 act(tower_help,"tower_enter",true)
 check(tower_help.ap==2 and tower_help.discount_used==1,"Notes reduce independent entrance by one")
 act(tower_help,"tower_observe")
 reject(tower_help,"query_signature")
 var query=S.new();query.initialize(support_seed)
 act(query,"ban");reject(query,"signature_application");act(query,"query_signature")
 check(query.has("responsibility_query") and not query.has("tower_observation"),"Full receipt allows responsibility query, not water observation")
 var plain=S.new();plain.initialize({})
 act(plain,"ban");reject(plain,"query_signature");act(plain,"signature_application");act(plain,"query_signature")
 check(not plain.has("responsibility_query"),"Local application obtains same signature without inherited full claim")
 var carried={"evidence":{"museum":{"holder":"player"}},"warnings":{"mo":16,"er":17},"pending_penalty":true}
 var penalty=S.new();penalty.initialize(carried)
 check(penalty.ap==2 and penalty.prior_contacts.has("mo"),"Only explicit penalty costs AP; due scholar warning affects contact")
 penalty.end_day()
 check(penalty.ap==3 and penalty.prior_contacts.has("er"),"Personal warnings never become recurring AP penalty")
 penalty.end_day();check(penalty.events.is_empty(),"Contact notice settled once")
 var stronger=route([["roster","platform","verify_history"],["sea_share","cross_region"]],carried.duplicate(true).merged({"pending_penalty":false},true))
 check(stronger.belief==5,"New evidence not automatically delivered")
 act(stronger,"sea_supplement")
 check(stronger.belief==10 and stronger.deliveries.size()==1,"Supplement only pays difference")
 reject(stronger,"sea_supplement")
 var stored=S.new();stored.initialize({"origin":{"evidence":{"F":{"holder":"elder"}}}});stored.flags.verify_history=true
 reject(stored,"cross_region")
 for tier in 4:
  var sample=S.new();sample.initialize({})
  if tier&1: sample.add_doc("cross_region")
  if tier&2: sample.add_doc("tower_observation")
  check(sample.reward("small")==[5,10,15,20][tier] and sample.reward("public")==[10,20,25,30][tier],"Ocean reward tier "+str(tier))
  sample.deliver("small");sample.deliver("public")
  var earned: int=sample.belief
  sample.deliver("small");sample.deliver("public")
  check(sample.belief==earned,"No duplicate audience rewards")
 var path="/tmp/forest-state-%d.json" % OS.get_process_id()
 check(Save.save_to(path,safe)==OK,"Save complete chapter")
 var loaded=Save.load_from(path)
 check(loaded.ok and loaded.state.to_data()==safe.to_data(),"Exact save roundtrip")
 check(Save.save_to(path,public)==OK,"Keep valid backup")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken");file.close()
 loaded=Save.load_from(path)
 check(loaded.ok and loaded.get("backup",false) and loaded.state.belief==0,"Corrupt main recovers earlier chapter")
 var invalid: Dictionary=safe.to_data();invalid.attempts[1].day=invalid.attempts[0].day
 check(not S.new().restore(invalid),"Same-day fraudulent replication rejected")
 invalid=safe.to_data();invalid.attempts[0].participant="ika"
 check(not S.new().restore(invalid),"Aristocrat cannot satisfy ordinary flight via restore")
 var same=S.new();check(same.restore(helped.to_data()) and same.discount_used==2,"Discount consumption survives load")
 reject(same,"tower_enter",true)
 var before_story: Dictionary=safe.to_data()
 Narrative.opening(safe);Narrative.greeting(safe,"lo");Narrative.stage(safe)
 check(safe.to_data()==before_story,"Narrative never mutates facts")
 await ui_checks()
 print("FOREST: %d checks, %d failures" % [checks,failures])
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
 root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280,720)
 var academy_path="/tmp/forest-entry-%d.json" % OS.get_process_id()
 var academy=load("res://scenes/academy_chapter.tscn").instantiate()
 academy.save_path=academy_path;root.add_child(academy);await frames()
 academy.state.presentation={}
 for i in 5: academy.state.end_day()
 academy._refresh()
 await activate(button(academy.actions,"forest"))
 for node in root.get_children():
  if node is Control and node.get_script().resource_path.ends_with("forest_chapter.gd"): scene=node
 check(scene!=null,"Academy transitions to forest")
 if scene==null: return
 await finish_dialogue()
 check(scene.state.day==1 and scene.state.entry_turn==16,"Forest starts on academy next turn")
 await capture("opening")
 var saved_path: String=scene.save_path
 scene._on_character_selected(0,"","",null);await finish_dialogue()
 check(scene.state.selected=="el","Character card opens El")
 await capture("character")
 await activate(button(scene.actions,"el_help"))
 check(scene.state.ap==3,"Preview free")
 await activate(button(scene.overlay_actions,"execute"))
 check(scene.state.ap==2 and scene.busy(),"Action settles before saved dialogue")
 scene.queue_free();await frames()
 scene=load("res://scenes/forest_chapter.tscn").instantiate();scene.save_path=saved_path
 root.add_child(scene);await frames()
 check(scene.state.ap==2 and scene.busy(),"Resume dialogue without duplicate cost")
 await finish_dialogue()
 scene._toolbar("map");await frames()
 check(scene.map_modal.visible,"Original map opens")
 scene._map_place("feather_forest")
 await activate(button(scene.overlay_actions,"enter_forest"))
 check(scene.state.selected.is_empty() and scene.state.ap==2,"Map returns to free investigation")
 scene.state=S.new();scene.state.initialize({});scene._refresh()
 var days=[["roster","platform","verify_history"],["el_help","witnesses","prepare"],["first_trial","ban"],["replicate","trace_ban"],["public_demo","protect_el"]]
 for actions in days:
  for id in actions:
   scene._forest_preview(id)
   if id=="verify_history":
    var before: Dictionary=scene.state.to_data()
    await activate(button(scene.overlay_actions,"compare_retry"))
    check(before==scene.state.to_data(),"Wrong evidence answer free")
    await capture("comparison")
    await activate(button(scene.overlay_actions,"compare_correct"))
   if id=="public_demo": await capture("public-preview")
   await activate(button(scene.overlay_actions,"execute"))
   check(scene.state.completed(id),"UI executes "+id)
   await finish_dialogue()
  await activate(scene.end_button)
  await activate(button(scene.overlay_actions,"confirm_day"))
  await finish_dialogue()
 check(scene.state.success() and scene.state.finished and scene.state.belief==10,"Entire five-day UI public route")
 await activate(button(scene.actions,"report"));await capture("report")
 check(scene.overlay_actions.get_global_rect().end.y<=root.size.y,"Report controls fit viewport")
 var final: Dictionary=scene.state.to_data()
 scene._load();check(scene.state.to_data()==final,"Final load stable")
 scene.queue_free();await frames()
 var resume=load("res://scenes/academy_chapter.tscn").instantiate();resume.save_path=academy_path
 root.add_child(resume);await frames();resume.state.presentation={}
 for i in 5: resume.state.end_day()
 resume._refresh();resume._toolbar("map");await frames()
 resume._map_place("feather_forest")
 await activate(button(resume.overlay_actions,"enter_forest"))
 for node in root.get_children():
  if node is Control and node.get_script().resource_path.ends_with("forest_chapter.gd"): scene=node
 check(scene.save_path==saved_path and scene.state.to_data()==final,"Reentering academy result resumes exact forest save")
 # Explicit discount choice remains reachable even at zero AP.
 scene.overlay.hide();scene.state=S.new();scene.state.initialize({"channels":{"independent_archive":true}});scene.state.ap=0;scene._refresh()
 check(not button(scene.actions,"roster").disabled,"Supported zero-AP action is reachable")
 await activate(button(scene.actions,"roster"));await capture("support")
 check(button(scene.overlay_actions,"execute")==null,"No unaffordable ordinary confirmation")
 await activate(button(scene.overlay_actions,"execute_support"));await finish_dialogue()
 check(scene.state.has("roster") and scene.state.discount_used==1 and scene.state.ap==0,"Explicit support pays once in UI")
 scene.queue_free();await frames()
