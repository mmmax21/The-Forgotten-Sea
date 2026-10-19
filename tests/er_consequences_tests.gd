extends SceneTree
const A=preload("res://scripts/story/academy_chapter_state.gd")
const F=preload("res://scripts/story/forest_chapter_state.gd")
const R=preload("res://scripts/story/royal_chapter_state.gd")
var checks=0
var failures=0
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func academy(protect: bool):
 var a=A.new()
 a.initialize({})
 for day in [["mo_help","mo_versions","verify"],["er_help","er_records","rules"],["trace","protect_copy"],["rescue_extra"],["distribute"]]:
  for id in day: check(a.execute(id),"Academy action "+id)
  if protect and a.day==4: check(a.execute("er_protect"),"Protect before deadline")
  check(a.end_day(),"Academy day")
 return a
func _initialize():
 var unprotected=academy(false)
 var protected=academy(true)
 check(unprotected.people.er.closed and not protected.people.er.closed,"Protection changes personal outcome")
 var f=F.new();f.initialize(unprotected.snapshot)
 check(f.er_link_blocked() and not f.support_available("roster"),"Only affected archive contact unavailable")
 check(f.has("tower_locate") and f.support_available("tower_enter"),"Acquired notebook still useful")
 check(f.execute("er_prepare") and not f.has("er_relieved"),"Partial help not full recovery")
 var restored=F.new()
 check(restored.restore(f.to_data()),"Partial help persists")
 check(restored.end_day() and restored.execute("er_receive"),"Complete help on another day")
 check(restored.spent==2 and restored.support_available("roster"),"Two AP restores contact")
 check(not restored.execute("er_receive"),"Cannot repeat help")
 check(restored.report().contains("失去抄写工作的损失仍在"),"Consequence not erased")
 var p=F.new();p.initialize(protected.snapshot)
 check(not p.execute("er_prepare") and p.support_available("roster"),"Protected route needs no late help")
 var market_seed=unprotected.snapshot.duplicate(true)
 market_seed.origin={"contacts_available":true}
 var m=F.new();m.initialize(market_seed)
 check(m.execute("er_prepare"),"Market prepare")
 m.ap=0
 check(m.execute("er_receive") and m.spent==1,"Available market channel saves one AP even at zero AP")
 var public_seed=unprotected.snapshot.duplicate(true)
 public_seed.channels.public_record=true
 var public=F.new();public.initialize(public_seed)
 check(not public.er_link_blocked() and public.support_available("witnesses"),"Public channel unaffected")
 var r=R.new();r.initialize(f.make_snapshot())
 check(not r.link_ready("academy"),"Unresolved dependent contact reaches royal")
 check(r.report().contains("没有完成接应"),"Unresolved personal epilogue")
 var repaired=R.new();repaired.initialize(restored.make_snapshot())
 check(repaired.link_ready("academy") and repaired.report().contains("恢复安全联系"),"Repaired contact and personal outcome reach royal")
 var old=F.new();old.initialize({})
 check(not old.execute("er_prepare") and old.restore(old.to_data()),"Unrelated old saves unaffected")
 print("ER CONSEQUENCES: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
