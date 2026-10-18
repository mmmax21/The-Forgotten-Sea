extends SceneTree
const S := preload("res://scripts/story/academy_chapter_state.gd")
const Save := preload("res://scripts/story/academy_chapter_save.gd")
const Narrative := preload("res://scripts/story/academy_chapter_story.gd")
var checks := 0
var failures := 0
var scene
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func act(s,id: String):
 var before: Dictionary = s.to_data()
 var p: Dictionary = s.preview(id)
 check(s.to_data()==before,"Preview pure: "+id)
 check(p.allowed,"Allowed "+id+": "+p.text)
 check(s.execute(id),"Execute "+id)
func reject(s,id: String):
 var before: Dictionary=s.to_data()
 check(not s.execute(id),"Reject "+id)
 check(before==s.to_data(),"Rejected action atomic: "+id)
func route(days: Array, seed: Dictionary={}):
 var s=S.new(); s.initialize(seed)
 for actions in days:
  for id in actions: act(s,id)
  check(s.end_day(),"End day")
 return s
func run():
 var safe=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["distribute"],[]])
 check(safe.success() and safe.belief==10 and safe.spent==10,"10 AP complete anonymous route")
 check(safe.snapshot.channels.independent_archive and safe.snapshot.next_turn==16,"Export usable result and next turn")
 var independent=route([["locate_versions","get_versions","verify"],["locate_execution","get_execution","rules"],["trace","protect_copy"],["distribute"],[]])
 check(independent.success() and independent.spent==10 and independent.people.mo.t==40,"Independent route needs no NPC cooperation or previous chapter")
 var public=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","permit","mo_sign"],["mo_protect"],["challenge"]])
 check(public.success() and public.belief==25 and public.spent==12 and public.warnings.is_empty(),"Signed public route protects students and remains within fifteen AP")
 var limited=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","gao_help","command"],["file_limited"],[]])
 check(limited.success() and limited.belief==0 and limited.spent==11,"Formal limited receipt is success without public belief")
 var full=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","gao_help","command"],["file_full"],[]])
 check(full.success() and full.spent==12 and full.flags.has("file_full"),"Full responsibility receipt preserves broader claim")
 reject(full,"file_limited")
 var backup_route=route([["mo_help","mo_versions","verify"],["er_help","rules"],["permit"],["rescue_execution"],["trace","challenge"]])
 check(backup_route.success() and backup_route.docs.has("execution"),"Known index enables paid day-four rescue and final-day proof")
 var late=route([[],[],[],[]])
 reject(late,"get_versions"); reject(late,"rescue_versions")
 check(late.archive_closed and late.end_day() and not late.success(),"Incomplete chapter can leave after announced closure")
 var pressure=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["rescue_extra"],["distribute"]])
 check(pressure.people.er.closed and pressure.docs.has("execution") and pressure.success(),"Exposure closes future assistance, never erases acquired evidence or delivered findings")
 var rescued=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["rescue_extra"],["er_protect","distribute"]])
 check(not rescued.people.er.closed and rescued.warnings.is_empty(),"Announced next-day risk can be addressed before expiry")
 var signed=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","permit","mo_sign"],[],["challenge"]])
 check(signed.snapshot.warnings.mo==16 and not signed.people.mo.closed,"Last-day risk exported instead of early punishment")
 var strong=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["museum"],["distribute"]])
 check(strong.belief==20 and strong.success(),"Local museum is independent optional evidence without village prerequisite")
 var seed={"origin":{"evidence":{"F":{"holder":"player"}}}}
 var extra=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["distribute","cross_region"]],seed)
 check(extra.belief==10,"Later verification does not notify prior readers automatically")
 act(extra,"supplement")
 check(extra.belief==20 and extra.deliveries.size()==1,"Supplement only pays difference")
 reject(extra,"supplement")
 var stored=S.new(); stored.initialize({"origin":{"evidence":{"F":{"holder":"elder"}}}})
 stored.flags.verify=true
 reject(stored,"cross_region")
 var helped=S.new(); helped.initialize({"handoff_rewards":{"reader_contact":{"status":"ready"},"inn_introduction":{"status":"ready"},"public_record":{"status":"ready"}}})
 act(helped,"locate_versions"); act(helped,"er_help")
 check(helped.ap==3 and helped.consumed.size()==2,"Introductions yield actual bounded action discounts")
 act(helped,"get_versions"); act(helped,"verify"); act(helped,"permit")
 check(helped.ap==1 and helped.consumed.has("public_record"),"Public record grants seat, not proof or automatic public success")
 reject(helped,"permit")
 var pre_read=S.new(); pre_read.initialize({"next_turn":11,"shipments":[{"id":"old-sea","status":"dispatched","arrival_turn":12,"gain":25}]})
 check(pre_read.belief==0 and not pre_read.flags.has("pre_read"),"Future shipment not counted at entry")
 pre_read.end_day()
 check(pre_read.belief==25 and pre_read.inbound[0].status=="arrived","Arrival uses absolute turn")
 act(pre_read,"mo_help")
 check(pre_read.ap==3,"Actual pre-reading waives scholar introduction once")
 pre_read.end_day()
 check(pre_read.belief==25,"Arrival does not replay")
 var resend=route([["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["distribute","resend"],[]],{"print_available":true,"belief_local":25})
 check(resend.belief==10 and resend.outbound[0].status=="arrived" and resend.snapshot.market_belief_after==35,"Return dispatch affects market only upon arrival")
 var penalized=S.new(); penalized.initialize({"pending_penalty":true})
 check(penalized.ap==2,"Immediate market penalty inherited")
 penalized.end_day(); check(penalized.ap==3,"Immediate penalty only once")
 var warning=S.new(); warning.initialize({"warnings":{"qian":11}})
 warning.end_day(); check(warning.ap==2,"Unresolved absolute warning affects next day")
 warning.end_day(); check(warning.ap==3,"Warning not repeated")
 var narrative_before: Dictionary=extra.to_data()
 Narrative.opening(extra); Narrative.stage(extra); Narrative.greeting(extra,"mo")
 Narrative.departure(extra)
 check(extra.to_data()==narrative_before,"Narrative is read-only")
 check(not has_speaker(Narrative.action(independent,"verify"),"墨先生"),"Independent discovery does not invent scholar cooperation")
 check(not has_speaker(Narrative.action(independent,"challenge"),"墨先生"),"Unsigned public route does not invent personal testimony")
 check(has_speaker(Narrative.action(public,"challenge"),"墨先生"),"Signed available scholar can speak publicly")
 var closed_speaker=S.new()
 check(closed_speaker.restore(public.to_data()),"Prepare closed signed testimony branch")
 closed_speaker.people.mo.closed=true
 check(not has_speaker(Narrative.action(closed_speaker,"challenge"),"墨先生"),"Unavailable scholar contributes saved testimony without appearing")
 check(not str(Narrative.departure(late)).contains("普通羽人曾担任空中信使"),"Missing books do not invent discovered forest evidence")
 check(str(Narrative.departure(pressure)).contains("旧观测塔的位置") and not str(Narrative.departure(safe)).contains("旧观测塔的位置"),"Only rescued notebook supplies precise forest tower lead")
 var path="/tmp/academy-state-%d.json" % OS.get_process_id()
 check(Save.save_to(path,safe)==OK,"Save completed route")
 var loaded=Save.load_from(path)
 check(loaded.ok and loaded.state.to_data()==safe.to_data(),"Exact JSON roundtrip")
 check(Save.save_to(path,public)==OK,"Backup earlier result")
 var file=FileAccess.open(path,FileAccess.WRITE); file.store_string("broken"); file.close()
 loaded=Save.load_from(path)
 check(loaded.ok and loaded.get("backup",false) and loaded.state.to_data()==safe.to_data(),"Corruption falls back to valid backup")
 var broken: Dictionary=safe.to_data(); broken.day=6
 check(not S.new().restore(broken),"Invalid chapter bounds rejected")
 var transfer=S.new()
 check(transfer.restore(pre_read.to_data()) and transfer.belief==25,"Arrival state resumes without repeated settlement")
 transfer.end_day(); check(transfer.belief==25,"Restored shipment remains settled")
 await ui_checks()
 print("ACADEMY: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)

func has_speaker(lines: Array, speaker: String) -> bool:
 for line in lines:
  if line.speaker==speaker: return true
 return false

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
 while scene.busy() and limit<50:
  var event=InputEventKey.new(); event.keycode=KEY_ENTER; event.pressed=true
  root.push_input(event)
  await frames(2)
  limit+=1
 check(not scene.busy(),"Enter completes dialogue")
func capture(label: String):
 if not OS.get_cmdline_user_args().has("--screenshot") or DisplayServer.get_name()=="headless": return
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/academy-%s-%d.png" % [label,root.size.x])
func ui_checks():
 root.size=Vector2i(1920,1080) if OS.get_cmdline_user_args().has("--large") else Vector2i(1280,720)
 var market_path="/tmp/academy-entry-%d.json" % OS.get_process_id()
 var market=load("res://scenes/market_chapter.tscn").instantiate()
 market.save_path=market_path
 root.add_child(market); await frames()
 market.state.presentation={}
 for i in 4: market.state.end_day()
 market._refresh()
 check(button(market.actions,"academy")!=null,"Completed market exposes academy entry even after incomplete market route")
 await activate(button(market.actions,"academy"))
 for node in root.get_children():
  if node is Control and node.get_script().resource_path.ends_with("academy_chapter.gd"): scene=node
 check(scene!=null,"Market transitions into real academy scene")
 if scene==null: return
 await finish_dialogue()
 check(scene.state.day==1 and scene.state.ap==3 and scene.state.entry_turn==11,"Entry preserves chapter timeline")
 await capture("opening")
 var saved_path: String=scene.save_path
 scene._on_character_selected(0,"","",null)
 await finish_dialogue()
 check(scene.state.selected=="mo","Original character-card signal opens scholar")
 await capture("scholar")
 await activate(button(scene.actions,"mo_help"))
 check(scene.overlay.visible and scene.state.ap==3,"Preview does not spend")
 await activate(button(scene.overlay_actions,"execute"))
 check(scene.busy() and scene.state.ap==2,"Action saved before dialogue")
 scene.queue_free(); await frames()
 scene=load("res://scenes/academy_chapter.tscn").instantiate()
 scene.save_path=saved_path; root.add_child(scene); await frames()
 check(scene.state.ap==2 and scene.busy(),"Paid dialogue resumes without duplicate AP")
 await finish_dialogue()
 scene._toolbar("map"); await frames()
 check(scene.map_modal.visible,"Original map opens")
 scene._map_place("old_academy")
 await activate(button(scene.overlay_actions,"enter_archive"))
 check(scene.state.selected.is_empty() and scene.state.ap==2,"Map returns to free archive")
 # Complete an entire chapter through its real confirmation buttons.
 scene.state=S.new(); scene.state.initialize({}); scene._refresh()
 var days=[["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["distribute"],[]]
 for actions in days:
  for id in actions:
   scene._academy_preview(id)
   if id in ["verify","trace"]:
    var before: Dictionary=scene.state.to_data()
    await activate(button(scene.overlay_actions,"compare_retry"))
    check(scene.state.to_data()==before,"Incorrect comparison free")
    await capture("comparison")
    await activate(button(scene.overlay_actions,"compare_correct"))
    check(scene.state.to_data()==before,"Correct answer awaits paid confirmation")
   await activate(button(scene.overlay_actions,"execute"))
   check(scene.state.flags.has(scene.state.action_key(id)),"UI executes "+id)
   await finish_dialogue()
  await activate(scene.end_button)
  check(scene.overlay.visible,"End-day review")
  await activate(button(scene.overlay_actions,"confirm_day"))
  await finish_dialogue()
 check(scene.state.finished and scene.state.success() and scene.state.belief==10,"Five-day UI route completes")
 await activate(button(scene.actions,"report"))
 await capture("report")
 check(scene.overlay_actions.get_global_rect().end.y<=root.size.y,"Report controls within window")
 var old_state: Dictionary=scene.state.to_data()
 scene._load()
 check(scene.state.to_data()==old_state,"Finished chapter reload stable")
 scene.queue_free(); await frames()

 var resume_market=load("res://scenes/market_chapter.tscn").instantiate()
 resume_market.save_path=market_path
 root.add_child(resume_market); await frames()
 resume_market.state.presentation={}
 for i in 4: resume_market.state.end_day()
 resume_market._refresh()
 await activate(button(resume_market.actions,"academy"))
 for node in root.get_children():
  if node is Control and node.get_script().resource_path.ends_with("academy_chapter.gd"): scene=node
 check(scene.save_path==saved_path and scene.state.finished and scene.state.belief==10,"Reentering same market resumes exact academy save")
 scene.queue_free(); await frames()
