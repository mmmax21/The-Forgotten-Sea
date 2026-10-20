extends SceneTree
const S=preload("res://scripts/story/royal_chapter_state.gd")
const Save=preload("res://scripts/story/royal_chapter_save.gd")
var checks:=0
var failures:=0
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
 checks+=1
 if not ok: failures+=1;push_error(label)
func campaign_seed() -> Dictionary:
 return {"next_turn":21,"belief_local":20,"deliveries":{"small":{"gain":20}},"social_results":{"ordinary_flight_replicated":true},"origin":{"belief_local":20,"findings":{"trace":true},"evidence":{"versions":{"holder":"player"},"execution":{"holder":"player"},"rules":{"holder":"player"}},"channels":{"independent_archive":true,"official_receipt":true},"deliveries":{"distribute":{"gain":20}},"origin":{"belief_local":20,"deliveries":[{"channel":"private","topic":"censorship"}],"findings":{"contacts":true},"contacts_available":true,"origin":{"belief_local":20,"chapter_progress":{"verified":true},"public_event":{"kind":"material"},"neighbor_valid":true,"evidence":{"F":{"holder":"player"},"H":{"holder":"player"}}}}}}
func fresh(data: Dictionary={}):
 var s=S.new();s.initialize(data);return s
func act(s,id: String):
 var before=s.to_data();var p=s.preview(id)
 check(before==s.to_data(),"Preview pure "+id)
 check(p.allowed,"Allowed "+id+" "+p.text)
 check(s.execute(id),"Execute "+id)
 check(s.valid_data(s.to_data()),"Valid "+id)
 var loaded=S.new();check(loaded.restore(s.to_data()) and loaded.to_data()==s.to_data(),"Roundtrip "+id)
func reject(s,id: String):
 var before=s.to_data();check(not s.execute(id),"Reject "+id);check(before==s.to_data(),"Rejected unchanged "+id)
func prepared(data: Dictionary):
 var s=fresh(data);s.day=6;s.flags={"chain":true,"network":true,"bypass":true,"stay":true,"takeover":true};s.controls={"broadcast":false,"enforcement":false,"artifact":false};s.regions.royal=35;s.belief=35;return s
func run():
 var empty=fresh()
 check(empty.prior_reader_count()==0,"Empty origins have no audience")
 for id in ["relay_village","relay_market","relay_academy","relay_forest","restore_market","bypass","case","takeover"]: reject(empty,id)
 var fake=prepared({});reject(fake,"final_sea");reject(fake,"final_liberation");reject(fake,"final_new_king")
 check(fake.end_day() and fake.ending=="forgetting","Old flags do not bypass new foundations")
 var all=prepared(campaign_seed());check(all.blocked("final_sea").is_empty(),"All prerequisites allow sea")
 for kind in ["village","flight","readers"]:
  var data=campaign_seed()
  if kind=="village": data.origin.origin.origin.chapter_progress.verified=false
  if kind=="flight": data.social_results.ordinary_flight_replicated=false
  if kind=="readers":
   data.deliveries={};data.origin.deliveries={};data.origin.origin.deliveries=[];data.origin.origin.origin.public_event={};data.origin.origin.origin.neighbor_valid=false
  var s=prepared(data);reject(s,"final_sea")
  check(s.blocked("final_liberation").is_empty(),"Missing sea proof preserves freedom: "+kind)
 var held=campaign_seed();held.origin.origin.origin.evidence={"F":{"holder":"salt"}}
 check(not fresh(held).heritage.village_proof,"Inaccessible material does not qualify")
 held.origin.origin.origin.npc={"salt":{"t":70,"a":30,"reported":false}}
 check(fresh(held).heritage.village_proof,"Cooperative custodian can verify source")
 held.origin.origin.origin.warnings={"salt":7}
 check(not fresh(held).heritage.village_proof,"Expired threatened custodian not available")
 var no_chain=campaign_seed();no_chain.origin.findings={}
 var network_only=fresh(no_chain);network_only.flags={"chain":true,"network":true,"original":true}
 reject(network_only,"case");act(network_only,"bypass")
 var no_network=campaign_seed();no_network.origin.origin.findings={};no_network.origin.origin.contacts_available=false
 var formal=fresh(no_network);formal.flags={"chain":true,"network":true,"original":true}
 reject(formal,"bypass");reject(formal,"restore_market");act(formal,"case");act(formal,"stay")
 check(not formal.controls.enforcement,"Formal route without market organization")
 var no_delivery=campaign_seed();no_delivery.origin.origin.deliveries=[]
 check(not fresh(no_delivery).heritage.market_foundation,"Unused network without actual readers is insufficient")
 var closed=campaign_seed();closed.origin.origin.contacts_available=false
 var s=fresh(closed)
 check(s.heritage.market_foundation and not s.market_ready(),"Closed network retains organizational basis")
 act(s,"restore_market");check(s.market_ready(),"Restore existing network")
 reject(s,"restore_market")
 var old_readers=campaign_seed();old_readers.origin.origin.contacts_available=false;old_readers.origin.origin.findings={};old_readers.origin.origin.origin.neighbor_valid=false
 var relay=fresh(old_readers);relay.flags={"network":true,"publish":true}
 reject(relay,"relay_village");act(relay,"reconnect_village");act(relay,"relay_village")
 check(relay.regions.village==45 and relay.prior_reader_count()==4,"Supplement counts once and does not create audience")
 reject(relay,"relay_village");reject(relay,"reconnect_village")
 relay.end_day()
 # New targets receive their own reward, not the royal score.
 act(relay,"relay_academy");check(relay.regions.academy==45 and relay.belief==0,"Academy target only")
 relay.end_day();act(relay,"reconnect_market");act(relay,"relay_market")
 check(relay.regions.market==45,"Market target works")
 var none=campaign_seed();none.deliveries={}
 var no_forest=fresh(none);no_forest.flags={"network":true,"publish":true}
 reject(no_forest,"reconnect_forest");reject(no_forest,"relay_forest")
 var risk=campaign_seed();risk.deliveries={"public":{"gain":10}};risk.findings={"public_participant":"el"};risk.warnings={"el":21};risk.origin.origin.contacts_available=false;risk.origin.origin.findings={}
 var affected=fresh(risk);check(affected.reader_ready("forest") and not affected.link_ready("forest"),"Reader retained while named contact lost")
 act(affected,"reconnect_forest");check(affected.link_ready("forest"),"Alternative contact does not restore original NPC")
 affected.end_day();check(affected.prior_contacts.el.status=="suspended","Original warning still applies")
 var arrived=campaign_seed();arrived.origin.deliveries={};arrived.origin.inbound=[{"status":"dispatched","gain":10,"arrival_turn":22}]
 check(not fresh(arrived).reader_ready("academy"),"Future shipment is not a reader")
 arrived.origin.inbound[0].arrival_turn=21
 check(fresh(arrived).reader_ready("academy"),"Actual arrival qualifies")
 # Old saves derive foundations from origin, not cached arbitrary booleans.
 var saved=relay.to_data();saved.heritage={}
 var restored=S.new();check(restored.restore(saved),"Old unfinished save migrates")
 check(restored.has("reconnect_village") and restored.regions.village==45 and restored.spent==relay.spent,"Migration keeps paid actions and cognition")
 var finished=prepared(campaign_seed());act(finished,"final_sea")
 var historical=finished.to_data();historical.origin={};historical.heritage={}
 var prior=S.new();check(prior.restore(historical) and prior.ending=="sea","Historical completed ending preserved")
 var path="/tmp/royal-v2-%d.json" % OS.get_process_id()
 check(Save.save_to(path,relay)==OK,"Save")
 check(Save.save_to(path,relay)==OK,"Backup")
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("broken");file.close()
 var loaded=Save.load_from(path);check(loaded.ok and loaded.get("backup",false),"Backup restore")
 var invalid=relay.to_data();invalid.regions.market=-1
 check(not S.new().restore(invalid),"Invalid scores rejected")
 # Existing end-game distinctions remain intact.
 var freedom=prepared(campaign_seed());act(freedom,"final_liberation")
 var king=prepared(campaign_seed());act(king,"final_new_king")
 var possession=fresh(campaign_seed());possession.flags.handover=true
 check(not possession.finished,"Artifact possession is not an automatic ending")
 var contract=prepared(campaign_seed());contract.flags.deal=true
 reject(contract,"final_sea");reject(contract,"final_new_king");act(contract,"renounce")
 check(contract.blocked("final_sea").is_empty(),"Release binding deal")
 var zero=prepared(campaign_seed());zero.ap=0;reject(zero,"final_sea");act(zero,"final_liberation")
 var raid=fresh(campaign_seed());raid.flags.network=true;raid.controls.broadcast=false;raid.day=5;raid.belief=35;raid.regions.royal=35
 raid.end_day();check(raid.network_closed and raid.belief==35,"Raid does not retract public cognition")
 act(raid,"relocate");check(raid.active_network(),"Local relocation restores local channel")
 print("ROYAL V2: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
