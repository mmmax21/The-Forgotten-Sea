extends SceneTree
## Full consecutive campaigns: only legitimate actions; no injected rewards or flags.
const V=preload("res://scripts/story/village_state.gd")
const M=preload("res://scripts/story/market_chapter_state.gd")
const A=preload("res://scripts/story/academy_chapter_state.gd")
const F=preload("res://scripts/story/forest_chapter_state.gd")
const R=preload("res://scripts/story/royal_chapter_state.gd")
const STATES=[V,M,A,F,R]
const SAVES=[preload("res://scripts/story/village_save.gd"),preload("res://scripts/story/market_chapter_save.gd"),preload("res://scripts/story/academy_chapter_save.gd"),preload("res://scripts/story/forest_chapter_save.gd"),preload("res://scripts/story/royal_chapter_save.gd")]
const CHAPTERS=["渔村","集市","旧学城","羽之森","王城"]
const HIGH=[
 [["feed","listen","repair"],["family","survey"],["clear","search","identify"],["heirloom","waterline"],["public_material"],[["record",{"item":"H"}],["neighbor",{"item":"H_r"}]]],
 [["qian_help","cargo","seizure","goods_verify"],["sea_verify","dao_help","protect"],["small","xiang_help","contacts","private"],[]],
 [["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy","cross_region"],["distribute","resend"],[]],
 [["platform","roster","lead_compare","tower_locate"],["tower_enter","tower_search"],["verify_history","preserve","sea_basis"],["cross_region","sea_share"],[]]
]
const LOW=[
 [["feed","listen","repair"],["family","survey"],["clear","search","identify"],["heirloom"],[["neighbor",{"item":"H"}]],[]],
 [["qian_help","cargo","seizure"],["goods_verify","self_copy"],["manual"],[]],
 [["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","gao_help","command"],["file_full"],[]],
 [["platform","roster","lead_compare","tower_locate"],["tower_enter","tower_search"],["verify_history","preserve"],[],[]]
]
const PUBLIC=[
 [["feed","listen","repair"],["family","survey"],["clear","search","identify"],["heirloom",["record",{"item":"H"}]],["public_salt"],[]],
 [["dao_help","text"],["ban","text_verify"],["rush"],["answer"]],
 [["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","permit","mo_sign"],[],["challenge"]],
 [["platform","roster","lead_compare","el_help"],["tower_locate","tower_enter"],["tower_search","verify_history","preserve"],["sea_basis","witnesses","corroborate"],["public_demo"]]
]
const SEA=[["archive","network"],["sea_evidence","publish"],["war","relay_village"],["device","relay_forest"],["chain","bypass"],["disconnect","final_sea"]]
const FREE=[["archive","war","device"],["chain","network"],["bypass"],["disconnect"],[],["final_liberation"]]
const FORMAL=[["archive","war","device"],["chain","original"],["case","stay"],["network"],["disconnect"],["final_liberation"]]
const KING=[["archive","war","device"],["chain","memory"],["review_plan","plan"],["network","relocate"],["handover"],["takeover","final_new_king"]]
const DEAL=[["archive","war","device"],["chain"],[],["deal"],[],["final_forgetting"]]
var checks=0
var failures=0
var results: Array=[]
var scene
func _initialize(): call_deferred("run")
func check(ok: bool,message: String):
 checks+=1
 if not ok: failures+=1;push_error(message)
func entry_id(entry): return entry if entry is String else entry[0]
func do_action(s,chapter: int,entry) -> bool:
 var id: String=entry_id(entry)
 if chapter==0:
  s.travel("ruins" if V.ACTIONS[id].group=="ruins" else "fishing_village")
  return s.execute(id,{} if entry is String else entry[1])
 return s.execute(id)
func run_campaign(label: String,prefix: Array,final_days: Array,expected: String):
 var chapters: Array=prefix.duplicate(true);chapters.append(final_days)
 var seed: Dictionary={}
 var ledger: Array=[]
 var trace: Array=[]
 var terminal
 for chapter in 5:
  var s=STATES[chapter].new()
  if chapter>0: s.initialize(seed)
  check(s.entry_turn==[1,7,11,16,21][chapter],label+" absolute turn "+CHAPTERS[chapter])
  for actions in chapters[chapter]:
   var day_record: Dictionary={"chapter":CHAPTERS[chapter],"day":s.day,"actions":[]}
   for entry in actions:
    var id: String=entry_id(entry)
    var before: int=s.ap
    if chapter==4 and id=="final_liberation" and label.begins_with("满足海回归"):
     check(s.blocked("final_sea").is_empty(),"Sea available before choosing freedom")
    var ok:=do_action(s,chapter,entry)
    check(ok,label+" "+CHAPTERS[chapter]+" day%d "%s.day+id)
    if not ok:
     print("BLOCKED ",s.blocked(id));return
    day_record.actions.append({"id":id,"title":STATES[chapter].ACTIONS[id].title,"ap":before-s.ap})
   trace.append(day_record)
   if not s.finished: check(s.end_day(),label+" end day")
  check(s.finished,label+" finished "+CHAPTERS[chapter])
  var path: String="/tmp/campaign-%d-%d-%d.json" % [OS.get_process_id(),results.size(),chapter]
  check(SAVES[chapter].save_to(path,s)==OK,label+" chapter save")
  var loaded: Dictionary=SAVES[chapter].load_from(path)
  check(loaded.ok,label+" chapter load")
  if loaded.ok:
   check(loaded.state.to_data()==s.to_data(),label+" exact chapter roundtrip")
   s=loaded.state
  ledger.append({"chapter":CHAPTERS[chapter],"belief":s.belief,"spent":s.spent,"success":s.snapshot.get("chapter_progress",{}).get("success",false) if chapter==0 else s.snapshot.get("success",false) if chapter<4 else s.ending,"warnings":s.snapshot.get("warnings",{})})
  seed=s.snapshot.duplicate(true)
  if chapter==0: seed.market_entry_turn=s.entry_turn+6
  if chapter==4:
   terminal=s
   if label.begins_with("前四章跳过"): check(s.ending=="forgetting" and s.regions.village==0 and s.regions.forest==0,"Skipped regions cannot be manufactured by royal publication")
 check(terminal.ending==expected,label+" expected ending")
 var result={"route":label,"ending":terminal.ending,"regions":terminal.regions,"total":terminal.total_belief(),"ledger":ledger,"report":terminal.report(),"trace":trace}
 results.append(result)
 print(JSON.stringify(result.merged({"trace":[],"report":""},true)))
func run():
 run_campaign("保护来源、跨区传播→海回归",HIGH,SEA,"sea")
 var sea_but_free=SEA.duplicate(true)
 sea_but_free[5]=["disconnect","final_liberation"]
 run_campaign("满足海回归条件→主动选择解放",HIGH,sea_but_free,"liberation")
 run_campaign("低传播、正式追责→解放",LOW,FORMAL,"liberation")
 var organized=LOW.duplicate(true)
 organized[1]=[["dao_help","text","ban"],["text_verify","protect","small"],["xiang_help","contacts","private"],[]]
 run_campaign("保留集市组织、祭司交付→新的王",organized,KING,"new_king")
 run_campaign("保留集市组织、独立解除控制→解放",organized,FREE,"liberation")
 run_campaign("公开传播失联、恢复组织→海回归",PUBLIC,[["archive","network"],["sea_evidence","publish"],["war","restore_market"],["device","relay_forest"],["chain","bypass"],["disconnect","final_sea"]],"sea")
 run_campaign("有限改革交易→遗忘重临",LOW,DEAL,"forgetting")
 run_campaign("各章调查未完成→遗忘重临",[[[],[],[],[],[],[]],[[],[],[],[]],[[],[],[],[],[]],[[],[],[],[],[]]],[[],[],[],[],[],[]],"forgetting")
 run_campaign("前四章跳过、仅王城调查传播→不能海回归",[[[],[],[],[],[],[]],[[],[],[],[]],[[],[],[],[],[]],[[],[],[],[],[]]],[["archive","network"],["sea_evidence","publish"],["war","device","chain"],[],[],["final_forgetting"]],"forgetting")
 if failures==0: await ui_campaign()
 var file=FileAccess.open("/tmp/campaign-routes-results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"routes":results},"  "));file.close()
 print("CAMPAIGN: %d checks, %d failures, %d full routes" % [checks,failures,results.size()])
 quit(1 if failures else 0)
func frames(n:=2):
 for i in n: await process_frame
func dialogue():
 var count:=0
 while scene.busy() and count<120:
  var event=InputEventKey.new();event.keycode=KEY_ENTER;event.pressed=true
  root.push_input(event);await frames();count+=1
 check(not scene.busy(),"Campaign UI dialogue finished")
func ui_campaign():
 root.size=Vector2i(1280,720)
 scene=load("res://scenes/trial1.tscn").instantiate();scene.save_path="/tmp/campaign-ui-%d.json" % OS.get_process_id();root.add_child(scene);await frames();await dialogue()
 var days=HIGH.duplicate(true);days.append(SEA)
 var transitions=["_enter_market","_enter_academy","_enter_forest","_enter_royal"]
 var files=["market_chapter.gd","academy_chapter.gd","forest_chapter.gd","royal_chapter.gd"]
 for chapter in 5:
  for actions in days[chapter]:
   for entry in actions:
    var id: String=entry_id(entry)
    match chapter:
     0:
      scene._travel("ruins" if V.ACTIONS[id].group=="ruins" else "fishing_village");await dialogue()
      scene._execute(id,{} if entry is String else entry[1])
     1: scene._market_execute(id,"censorship")
     2: scene._academy_execute(id)
     3: scene._forest_execute(id)
     4: scene._royal_execute(id)
    await dialogue()
    check(not scene.overlay.visible,"UI action succeeded "+id)
   if not scene.state.finished: scene._end_day();await dialogue()
  check(scene.state.finished,"Full UI chapter complete "+CHAPTERS[chapter])
  if chapter<4:
   scene.call(transitions[chapter]);await frames()
   for node in root.get_children():
    if node is Control and node.get_script().resource_path.ends_with(files[chapter]): scene=node
   await dialogue()
   check(scene.state.entry_turn==[7,11,16,21][chapter],"UI transition exact turn")
 check(scene.state.ending=="sea","All five live scenes lead to sea")
 check(scene.state.regions==results[0].regions,"UI and rules ledger agree")
 scene._show_report()
 if OS.get_cmdline_user_args().has("--screenshot") and DisplayServer.get_name()!="headless":
  await create_timer(0.4).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("/tmp/campaign-full-report.png")
 scene.queue_free();await frames()
