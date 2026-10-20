extends RefCounted
const RULESET := "academy_five_days_v1"
const NAMES := {"mo":"墨先生","er":"二笔","gao":"高帽子"}
const DOCS := {"versions":"《海港篇》新旧书页与年代","execution":"这批旧书的交接与处理记录","rules":"要求改写海港与远航内容的通知","command":"与这批通知对应的正式命令副本","museum":"馆藏旧港器具核验记录"}
const ACTIONS := {
 "mo_help":{"title":"帮墨先生找到旧书的位置","group":"mo","ap":1},
 "mo_versions":{"title":"请墨先生拿出新旧两版书","group":"mo","ap":1,"cooperate":"mo","doc":"versions","last":3},
 "mo_protect":{"title":"保护墨先生的学生和私人记录","group":"mo","ap":1,"requires":["mo_help"]},
 "mo_sign":{"title":"请墨先生自愿说明自己的校对责任","group":"mo","ap":1,"cooperate":"mo","requires":["trace"]},
 "er_help":{"title":"和二笔查旧书的交接位置","group":"er","ap":1},
 "er_records":{"title":"请二笔找出这批书的换书记录","group":"er","ap":1,"cooperate":"er","doc":"execution","requires":["versions"],"last":3},
 "er_protect":{"title":"安排二笔与师姐避开追查","group":"er","ap":1,"requires":["er_help"]},
 "rescue_extra":{"title":"请二笔抢救指向羽之森的札记","group":"er","ap":2,"cooperate":"er","requires":["trace"],"first":4,"last":4},
 "gao_help":{"title":"向高帽子说明要查哪批书","group":"gao","ap":1},
 "command":{"title":"查看这批改书通知对应的正式命令","group":"gao","ap":1,"cooperate":"gao","requires":["trace"],"doc":"command"},
 "gao_protect":{"title":"说明公开范围，分清个人责任","group":"gao","ap":1,"requires":["gao_help"]},
 "file_limited":{"title":"正式登记这批书的改动问题","group":"gao","ap":2,"cooperate":"gao","requires":["trace","command"]},
 "file_full":{"title":"正式要求追查改书命令的来源","group":"gao","ap":3,"cooperate":"gao","requires":["trace","command"]},
 "locate_versions":{"title":"自己查新旧书的位置","group":"research","ap":1},
 "get_versions":{"title":"按目录取出新旧两版书","group":"research","ap":1,"requires":["locate_versions"],"doc":"versions","last":3},
 "verify":{"title":"比一比这本书改了哪些地方","group":"research","ap":1,"requires":["versions"]},
 "locate_execution":{"title":"自己查换书记录的位置","group":"research","ap":1,"requires":["versions"]},
 "get_execution":{"title":"查看旧书被收走和替换的记录","group":"research","ap":1,"requires":["locate_execution"],"doc":"execution","last":3},
 "rules":{"title":"找到要求改书的通知","group":"research","ap":1,"doc":"rules"},
 "trace":{"title":"把改书的三份证据连起来","group":"research","ap":1,"requires":["verify","execution","rules"]},
 "rescue_versions":{"title":"清理前按已知位置抢救旧书","group":"research","ap":2,"requires":["locate_versions"],"doc":"versions","first":4,"last":4},
 "rescue_execution":{"title":"清理前按已知位置抢救换书记录","group":"research","ap":2,"requires":["locate_execution"],"doc":"execution","first":4,"last":4},
 "museum":{"title":"检查馆里旧港口器具的用途","group":"research","ap":2,"requires":["verify"],"doc":"museum"},
 "cross_region":{"title":"用渔村材料核对旧书中的记载","group":"research","ap":1,"requires":["verify"]},
 "protect_copy":{"title":"整理不暴露无关人员的调查记录","group":"research","ap":1,"requires":["trace"]},
 "distribute":{"title":"把记录交给读者，讲清改书经过","group":"research","ap":2,"requires":["trace","protect_copy"]},
 "permit":{"title":"申请在新版审议会上发言","group":"research","ap":1,"requires":["verify"],"last":4},
 "challenge":{"title":"在新版审议会上当众提出证据","group":"research","ap":2,"requires":["trace","permit"],"first":5,"last":5},
 "supplement":{"title":"把新找到的实证讲给原来的读者","group":"research","ap":1,"requires":["trace"]},
 "resend":{"title":"把调查记录送回集市印刷渠道","group":"research","ap":1,"requires":["trace","distribute"],"last":4},
}
var day := 1
var entry_turn := 11
var ap := 3
var spent := 0
var belief := 0
var selected := ""
var location := "old_academy"
var people := {"mo":{"t":40,"a":35,"closed":false},"er":{"t":40,"a":30,"closed":false},"gao":{"t":40,"a":30,"closed":false}}
var flags: Dictionary = {}
var docs: Dictionary = {}
var origin: Dictionary = {}
var deliveries: Dictionary = {}
var inbound: Array = []
var outbound: Array = []
var history: Array = []
var events: Array = []
var warnings: Dictionary = {}
var consumed: Array = []
var presentation: Dictionary = {}
var snapshot: Dictionary = {}
var finished := false
var archive_closed := false
var imported_warning_used := false

func initialize(seed: Dictionary) -> void:
 origin = seed.duplicate(true)
 entry_turn = int(origin.get("next_turn",11))
 if origin.get("pending_penalty",false):
  ap=2
  events.append("集市留下的查验压力已到达：学城首日少1 AP。")
 for shipment in origin.get("shipments",[]):
  if shipment.get("status","")=="dispatched": inbound.append(shipment.duplicate(true))
 receive_shipments()

func absolute_day() -> int: return entry_turn+day-1
func has(id: String) -> bool: return flags.has(id) or docs.has(id)
func cooperative(who: String) -> bool: return people[who].t>=60 and people[who].a<60 and not people[who].closed
func support(id: String) -> bool:
 return origin.get("handoff_rewards",{}).get(id,{}).get("status","")=="ready" and not consumed.has(id)
func carried_evidence() -> bool:
 for id in origin.get("origin",{}).get("evidence",{}):
  if id in ["H","F","H_r","F_r"] and origin.origin.evidence[id].get("holder","")=="player": return true
 return false
func strengthened() -> bool: return has("cross_region") or has("museum")
func reward(channel: String) -> int: return (10 if channel=="distribute" else 25)+(10 if strengthened() else 0)
func success() -> bool: return has("trace") and (not deliveries.is_empty() or has("file_limited") or has("file_full"))
func action_key(id: String) -> String: return "supplement:"+str(strengthened()) if id=="supplement" else id
func cost(id: String) -> int:
 if id=="er_help" and support("inn_introduction"): return 0
 if id=="locate_versions" and support("reader_contact"): return 0
 if id=="permit" and support("public_record"): return 0
 if id=="mo_help" and flags.has("pre_read") and not consumed.has("pre_read"): return 0
 return ACTIONS[id].ap
func status(who: String) -> String:
 if people[who].closed: return "私人记录已销毁，暂停协助" if who=="mo" else "被停职盘问，师姐接受核查；原有联系受查" if who=="er" else "转为书面审查，暂停调阅"
 if warnings.has(who):
  if warnings[who]>5: return "离城后预警：全局第%d回合末到期" % (entry_turn+int(warnings[who])-1)
  return "预警：第%d天末暂停协助，可先保护来源" % warnings[who]
 return "愿意合作" if cooperative(who) else "需要先说明来意" if people[who].t<60 else "压力过高，需先处理风险"

func blocked(id: String) -> Array:
 if not ACTIONS.has(id): return ["未知行动"]
 var a: Dictionary = ACTIONS[id]
 var reasons: Array = []
 if finished: reasons.append("学城章节已结束")
 if not presentation.is_empty(): reasons.append("先读完当前对白")
 if flags.has(action_key(id)): reasons.append("已经完成")
 if ap<cost(id): reasons.append("AP不足，需要%d" % cost(id))
 if day<a.get("first",1) or day>a.get("last",5): reasons.append("开放日期：第%d—%d天" % [a.get("first",1),a.get("last",5)])
 for required in a.get("requires",[]):
  if not has(required): reasons.append("需要「%s」" % DOCS.get(required,ACTIONS.get(required,{}).get("title",required)))
 if a.has("doc") and docs.has(a.doc): reasons.append("这份材料已经取得，不重复收费")
 if a.has("cooperate") and not cooperative(a.cooperate): reasons.append("需要信任≥60、警戒<60且渠道开放")
 if id=="er_protect" and people.er.closed: reasons.append("已被停职调查，离城后需安排接应，不能再按提前保护处理")
 if id=="cross_region" and not carried_evidence(): reasons.append("需要实际携带渔村手记、构件或对应记录，寄存物不能远程取回")
 if id.begins_with("file_") and (has("file_full") or has("file_limited")): reasons.append("已经提交本章正式异议")
 if id=="supplement":
  var difference := 0
  for channel in deliveries: difference+=maxi(0,reward(channel)-int(deliveries[channel].gain))
  if difference==0: reasons.append("需要已传播且新增核验实证，只领取差额")
 if id=="resend" and not origin.get("print_available",false): reasons.append("集市印刷渠道未保留或已经暂停")
 return reasons

func consequence(id: String) -> String:
 match id:
  "trace": return "确认这批书被按统一通知改写；还不知道国王的全部动机。之后选一种方式留下成果：交给读者、会上公开，或正式登记。"
  "distribute": return "材料实际交给读者并完成讲读，公众海洋认知+%d。保存副本的接收记录，不暴露私人来源。" % reward("distribute")
  "challenge": return "第五天公开质证，公众海洋认知+%d；高帽子警戒+20。若墨先生署名，他警戒+20。保留质证记录，不自动撤销官方版本。" % reward("challenge")
  "file_limited": return "取得限于这一修订批次的官方回执，高帽子警戒+5。完整调查仍随身保留，未向公众传播，不加认知。"
  "file_full": return "登记完整责任异议与附件，高帽子警戒+20。回执证明收到过材料，不表示官方承认结论，也不增加公众认知。"
  "mo_sign": return "由墨先生自愿说明自己参与校对的过程，警戒+15。公开质证时留下具名证言，便于后续追责；不是额外海洋物证。"
  "rescue_extra": return "保全额外研究札记，含一条指向羽之森旧观测塔的目录线索。这份不在原调阅单里，会留下额外开箱记录；二笔警戒+30，可能触发下一天末的追查。若触发预警，最晚第五天末前花1 AP安排暂避；否则二笔会被停职盘问、师姐接受核查，经她维系的联系受限。入林后可分步花2 AP接应，有可用集市渠道则1 AP。札记保留，不替代主线证据。"
  "er_protect": return "保留交接凭据、澄清师姐未参与额外开箱，安排二笔暂避和替代联络。警戒−20，解除未到期预警；不是抹去开箱事实。"
  "mo_protect","gao_protect": return "此人警戒−20，可解除尚未到期的预警；已暂停的渠道不会自动恢复，已送达成果不撤销。"
  "cross_region","museum": return "核验与旧史相互独立的实证，后续讲读或公开质证各多10认知。已经听过的读者需补充说明才获得差额。"
  "supplement":
   var difference := 0
   for channel in deliveries: difference+=maxi(0,reward(channel)-int(deliveries[channel].gain))
   return "向已接触的读者补充实证，仅增加差额%d；不重复发放首次传播收益。" % difference
  "resend": return "通过保留的集市渠道回传研究，下一全局回合到达，集市认知增加10（不加在学城）。同一消息只结算一次。"
  "rescue_versions","rescue_execution": return "第四天清理前按编号保全材料，消耗2 AP。取得的记录不会因原件后来清理而消失。"
  "mo_help","er_help","gao_help": return "信任+20，明确合作范围。"+("使用上一地区留下的有效介绍或预读反馈，本次免费。" if cost(id)==0 else "")
  "mo_versions","er_records","command": return "取得带来源与编号的材料，对方警戒+5。" 
  "protect_copy": return "保留证据编号与对应关系，隐去私人姓名；为分散保存和讲读准备副本。"
  "permit": return "取得第五天审议发言资格，公开质证另需2 AP。"+("已有集市公众问答记录，本次免1 AP。" if cost(id)==0 else "")
 return "取得或核验档案，记录调查进展；调查不会自动增加公众认知。"

func preview(id: String) -> Dictionary:
 var reasons := blocked(id)
 var text := "本次消耗%d AP。\n%s" % [cost(id),consequence(id)]
 if not reasons.is_empty(): text+="\n不能执行："+"；".join(reasons)
 return {"allowed":reasons.is_empty(),"text":text}

func execute(id: String) -> bool:
 if not blocked(id).is_empty(): return false
 var paid := cost(id)
 ap-=paid
 spent+=paid
 flags[action_key(id)]=true
 var a: Dictionary = ACTIONS[id]
 if a.has("doc"): docs[a.doc]={"source":"academy:"+a.doc,"batch":"港史甲七","holder":"player"}
 match id:
  "mo_help","er_help","gao_help":
   people[a.group].t+=20
   if paid==0: consumed.append({"mo_help":"pre_read","er_help":"inn_introduction","gao_help":""}[id])
   if id=="mo_help": flags["locate_versions"]=true
   if id=="er_help": flags["locate_execution"]=true
  "locate_versions":
   if paid==0: consumed.append("reader_contact")
  "permit":
   if paid==0: consumed.append("public_record")
  "mo_versions","er_records","command": people[a.group].a+=5
  "mo_sign": people.mo.a+=15
  "rescue_extra": people.er.a+=30
  "mo_protect","er_protect","gao_protect": people[a.group].a=maxi(0,people[a.group].a-20)
  "distribute","challenge":
   var gain := reward(id)
   deliveries[id]={"day":day,"gain":gain,"strengthened":strengthened()}
   belief=mini(100,belief+gain)
   if id=="challenge":
    people.gao.a+=20
    if has("mo_sign"): people.mo.a+=20
  "file_limited": people.gao.a+=5
  "file_full": people.gao.a+=20
  "supplement":
   for channel in deliveries:
    var delta := maxi(0,reward(channel)-int(deliveries[channel].gain))
    belief=mini(100,belief+delta)
    deliveries[channel].gain+=delta
    deliveries[channel].strengthened=strengthened()
  "resend": outbound.append({"id":"academy-research","arrival_turn":absolute_day()+1,"status":"in_transit","gain":10,"target":"market"})
 sync_risk()
 history.append({"day":day,"action":id,"title":a.title,"ap":ap,"belief":belief,"receipt":"消耗%d AP；%s" % [paid,"已经完成实际传播" if id in ["distribute","challenge"] else "进展已记录"]})
 return true

func sync_risk() -> void:
 for who in NAMES:
  if people[who].closed: continue
  if people[who].a>=60:
   if not warnings.has(who): warnings[who]=day+1
  else: warnings.erase(who)

func receive_shipments() -> void:
 for shipment in inbound:
  if shipment.status=="dispatched" and shipment.arrival_turn<=absolute_day():
   shipment.status="arrived"
   flags["pre_read"]=true
   belief=mini(100,belief+int(shipment.get("gain",0)))
   events.append("集市商队材料已送到学城读者手中，海洋认知+%d；墨先生已预读，首次整理目录可免1 AP。" % int(shipment.get("gain",0)))
 for shipment in outbound:
  if shipment.status=="in_transit" and shipment.arrival_turn<=absolute_day():
   shipment.status="arrived"
   events.append("回传研究已送达集市读者：集市认知+10，记入跨地区成果，不计入学城认知。")

func end_preview() -> String:
 var text := "剩余%d AP不结转。第4天末清理旧版本与交接原件，第5天审议结束后离城。" % ap
 if day==4: text+="\n今晚清理未保全的旧稿；已持有的记录与副本不受影响。"
 if day==5: text+="\n本章即将结束。"+result_text()
 for who in warnings: text+="\n"+NAMES[who]+"："+status(who)
 return text

func end_day() -> bool:
 if finished or not presentation.is_empty(): return false
 events=[]
 for who in warnings.keys():
  if warnings[who]<=day:
   people[who].closed=true
   warnings.erase(who)
   events.append(NAMES[who]+"的压力已到期："+status(who)+"。玩家已有证据与已传播成果保留。")
 if day==4:
  archive_closed=true
  events.append("清理完成：未取得的《海港篇》旧稿与同批交接原件已移除，之后不能再调阅。随身记录保留。")
 var next_penalty := false
 if not imported_warning_used:
  for due in origin.get("warnings",{}).values():
   if int(due)<=absolute_day():
    imported_warning_used=true
    next_penalty=true
    events.append("集市未决预警带来查验，下一回合少1 AP；同一来源只处理一次。")
    break
 if day==5:
  finished=true
  snapshot=make_snapshot()
  snapshot["pending_penalty"]=next_penalty
 else:
  day+=1
  ap=2 if next_penalty else 3
  receive_shipments()
 return true

func result_text() -> String:
 var text := "学城调查成功：查明有意删改，并留下有效成果。" if success() else "部分调查已保留，尚未完成查明删改与有效成果两项要求。"
 text+="\n公众海洋认知：%d\n版本矛盾：%s；有意删改：%s" % [belief,"已核实" if has("verify") else "未核实","已证实" if has("trace") else "未证实"]
 text+="\n交给读者并讲清经过：%s\n会上公开证据：%s\n正式登记异议：%s" % ["完成" if has("distribute") else "未完成","完成，含具名证言" if has("challenge") and has("mo_sign") else "完成" if has("challenge") else "未完成","完整责任异议" if has("file_full") else "单批修订异议" if has("file_limited") else "未提交"]
 return text

func report() -> String:
 var text := result_text()+"\n\n保全材料："+"、".join(docs.keys().map(func(k): return DOCS[k]))
 for who in NAMES: text+="\n"+NAMES[who]+"："+status(who)
 for shipment in inbound: text+="\n集市来件："+("已到达并结算" if shipment.status=="arrived" else "在途，尚未兑现")
 for shipment in outbound: text+="\n回传集市："+("已到达，集市认知+10" if shipment.status=="arrived" else "在途，尚未兑现")
 text+="\n\n后续线索："+("旧观测塔目录与羽族相关旧稿已保全。" if has("rescue_extra") else "旧书中的普通羽人空中信使记录指向羽之森。" if has("trace") else "仍需查清历史缺失的原因。")
 return text+"\n可继续前往羽之森。羽之森结束后可进入王城。法器及国王的真实动机仍未揭晓。"

func make_snapshot() -> Dictionary:
 var exported_warnings := {}
 for who in warnings: exported_warnings[who]=entry_turn+int(warnings[who])-1
 return {"success":success(),"belief_local":belief,"findings":flags.duplicate(true),"evidence":docs.duplicate(true),"deliveries":deliveries.duplicate(true),"people":people.duplicate(true),"inbound":inbound.duplicate(true),"outbound":outbound.duplicate(true),"warnings":exported_warnings,"origin":origin.duplicate(true),"next_turn":entry_turn+5,"pending_penalty":false,"channels":{"independent_archive":has("distribute"),"public_record":has("challenge"),"official_receipt":has("file_limited") or has("file_full")},"market_belief_after":mini(100,int(origin.get("belief_local",0))+10*outbound.filter(func(s): return s.status=="arrived").size())}

func to_data() -> Dictionary:
 var result := {}
 for key in ["day","entry_turn","ap","spent","belief","selected","location","people","flags","docs","origin","deliveries","inbound","outbound","history","events","warnings","consumed","presentation","snapshot","finished","archive_closed","imported_warning_used"]: result[key]=get(key)
 return result.duplicate(true)

func valid_data(data: Dictionary) -> bool:
 for key in to_data():
  if not data.has(key): return false
 for key in ["day","entry_turn","ap","spent","belief"]:
  if not data[key] is int: return false
 if data.day<1 or data.day>5 or data.ap<0 or data.ap>3 or data.spent<0 or data.belief<0 or data.belief>100 or data.entry_turn<1: return false
 for key in ["people","flags","docs","origin","deliveries","warnings","presentation","snapshot"]:
  if not data[key] is Dictionary: return false
 for key in ["inbound","outbound","history","events","consumed"]:
  if not data[key] is Array: return false
 for key in ["finished","archive_closed","imported_warning_used"]:
  if not data[key] is bool: return false
 if not data.selected is String or (data.selected!="" and not NAMES.has(data.selected)) or data.location!="old_academy": return false
 for who in NAMES:
  if not data.people.get(who) is Dictionary: return false
  var p: Dictionary = data.people[who]
  if not p.get("t") is int or not p.get("a") is int or not p.get("closed") is bool: return false
  if p.t<0 or p.t>100 or p.a<0 or p.a>100: return false
 for doc in data.docs:
  if not DOCS.has(doc) or not data.docs[doc] is Dictionary or data.docs[doc].get("holder")!="player": return false
 for channel in data.deliveries:
  if channel not in ["distribute","challenge"] or not data.deliveries[channel] is Dictionary: return false
  if not data.deliveries[channel].get("gain") is int or data.deliveries[channel].gain<0: return false
 for shipment in data.inbound+data.outbound:
  if not shipment is Dictionary or not shipment.get("arrival_turn") is int: return false
  if shipment.get("status","") not in ["dispatched","arrived","in_transit"]: return false
  if shipment.has("gain") and (not shipment.gain is int or shipment.gain<0): return false
 for who in data.warnings:
  if not NAMES.has(who) or not data.warnings[who] is int: return false
 for item in data.history:
  if not item is Dictionary: return false
  for key in ["day","ap","belief"]:
   if not item.get(key) is int: return false
  if not item.get("title") is String: return false
 if not data.presentation.is_empty():
  if not data.presentation.get("lines") is Array or not data.presentation.get("index") is int: return false
  if data.presentation.index<0 or data.presentation.index>=data.presentation.lines.size(): return false
  for line in data.presentation.lines:
   if not line is Dictionary or not line.get("text") is String or not line.get("speaker") is String: return false
 return true

func restore(data: Dictionary) -> bool:
 if not valid_data(data): return false
 for key in to_data(): set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
 return true
