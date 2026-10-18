extends RefCounted
const RULESET := "forest_five_days_v1"
const NAMES := {"el":"艾尔","lo":"洛恩","ika":"伊卡恩"}
const DOCS := {"roster":"普通羽人空运名册","platform":"旧训练场测绘记录","ban":"历次禁飞规定与讲义","signature":"禁令签署来源：疯祭司","tower_observation":"高塔方向与远方水面观察","cross_region":"前区独立实证比对记录"}
const ACTIONS := {
 "el_help":{"title":"与艾尔约定尝试边界","group":"el","ap":1},
 "select_el":{"title":"选择艾尔为下一次参与者 · 免费","group":"el","ap":0,"cooperate":"el"},
 "protect_el":{"title":"处理艾尔及家属的公开压力","group":"el","ap":1,"requires":["el_help"]},
 "lo_help":{"title":"回应洛恩的家庭顾虑","group":"lo","ap":1},
 "select_lo":{"title":"选择洛恩为下一次参与者 · 免费","group":"lo","ap":0,"cooperate":"lo","requires":["verify_history"]},
 "protect_lo":{"title":"处理洛恩及家属的公开压力","group":"lo","ap":1,"requires":["lo_help"]},
 "ika_help":{"title":"核对伊卡恩的童年经历","group":"ika","ap":1},
 "tower_permit":{"title":"请伊卡恩带领进入高塔","group":"ika","ap":1,"cooperate":"ika"},
 "roster":{"title":"查阅普通羽人空运名册","group":"research","ap":1,"doc":"roster"},
 "platform":{"title":"调查旧训练场","group":"research","ap":1,"doc":"platform"},
 "verify_history":{"title":"核对身份、任务与训练场","group":"research","ap":1,"requires":["roster","platform"]},
 "witnesses":{"title":"联系愿意见证的普通居民","group":"research","ap":1,"requires":["verify_history"],"participant":true},
 "prepare":{"title":"准备低台并约定尝试方式","group":"research","ap":1,"requires":["platform"],"participant":true},
 "first_trial":{"title":"首次有见证尝试 · 本次2 AP，隔日复核另2 AP","group":"research","ap":2,"requires":["verify_history","witnesses","prepare"],"participant":true,"last":4},
 "replicate":{"title":"隔日复核并整理观察","group":"research","ap":2,"requires":["first_trial"],"participant":true},
 "ban":{"title":"查阅历次禁飞规定与讲义","group":"research","ap":1,"doc":"ban"},
 "trace_ban":{"title":"核对禁令与观念变化时间线","group":"research","ap":1,"requires":["ban","verify_history"]},
 "public_demo":{"title":"安翼礼公开展示并解释海洋依据","group":"research","ap":2,"requires":["replicate"],"participant":true,"first":5,"last":5},
 "tower_locate":{"title":"根据旧图寻找废弃入口","group":"research","ap":1},
 "tower_enter":{"title":"从废弃入口步行进入高塔","group":"research","ap":2,"requires":["tower_locate"]},
 "tower_observe":{"title":"记录远方水面与禁令原件","group":"research","ap":1,"requires":["tower_open"]},
 "signature_application":{"title":"登记本地禁令查询申请","group":"research","ap":1,"requires":["ban"]},
 "query_signature":{"title":"正式查询禁令签署来源","group":"research","ap":1,"requires":["ban"],"doc":"signature"},
 "cross_region":{"title":"核验前区独立实证与本地航线","group":"research","ap":1,"requires":["verify_history"],"doc":"cross_region"},
 "sea_share":{"title":"向小范围居民说明海洋发现","group":"research","ap":1,"requires":["verify_history"]},
 "sea_supplement":{"title":"向已有读者补充新增依据","group":"research","ap":1,"requires":["verify_history"]},
}
var day := 1
var entry_turn := 16
var ap := 3
var spent := 0
var belief := 0
var selected := ""
var location := "feather_forest"
var participant := ""
var people := {"el":{"t":40,"a":30,"closed":false},"lo":{"t":40,"a":25,"closed":false},"ika":{"t":35,"a":30,"closed":false}}
var flags: Dictionary = {}
var docs: Dictionary = {}
var origin: Dictionary = {}
var deliveries: Dictionary = {}
var attempts: Array = []
var history: Array = []
var events: Array = []
var warnings: Dictionary = {}
var prior_contacts: Dictionary = {}
var consumed: Array = []
var discount_used := 0
var presentation: Dictionary = {}
var snapshot: Dictionary = {}
var finished := false

func initialize(seed: Dictionary) -> void:
 origin=seed.duplicate(true)
 entry_turn=int(origin.get("next_turn",16))
 if origin.get("pending_penalty",false):
  ap=2
  events.append("学城已确定的查验处罚到达：入林首日少1 AP，仅结算一次。")
 if origin.get("findings",{}).get("rescue_extra",false):
  flags["tower_locate"]=true
  events.append("学城保全的札记指出废弃入口，已记入地图调查，不需要再次定位。")
 settle_prior_contacts()

func absolute_day() -> int: return entry_turn+day-1
func has(id: String) -> bool: return flags.has(id) or docs.has(id)
func cooperative(who: String) -> bool: return NAMES.has(who) and people[who].t>=60 and people[who].a<60 and not people[who].closed
func participant_ready() -> bool: return participant in ["el","lo"] and cooperative(participant) and (participant!="lo" or has("verify_history"))
func formal_receipt() -> bool: return origin.get("findings",{}).get("file_limited",false) or origin.get("findings",{}).get("file_full",false)
func support_available(id: String) -> bool:
 if discount_used>=2 or consumed.has(id): return false
 match id:
  "roster": return origin.get("channels",{}).get("independent_archive",false)
  "witnesses": return origin.get("channels",{}).get("public_record",false)
  "tower_enter": return origin.get("findings",{}).get("rescue_extra",false)
 return false
func cost(id: String, use_support := false) -> int:
 return int(ACTIONS[id].ap)-(1 if use_support and support_available(id) else 0)
func evidence_tier() -> int:
 return (2 if has("tower_observation") else 0)+(1 if has("cross_region") else 0)
func reward(channel: String) -> int:
 return int(([5,10,15,20] if channel=="small" else [10,20,25,30])[evidence_tier()])
func supplement_gain() -> int:
 var total:=0
 for channel in deliveries: total+=maxi(0,reward(channel)-int(deliveries[channel].gain))
 return total
func action_key(id: String) -> String: return id+":"+str(evidence_tier()) if id=="sea_supplement" else id
func completed(id: String) -> bool: return false if id.begins_with("select_") else flags.has(action_key(id))
func carried_evidence() -> bool:
 var cursor: Dictionary=origin
 for depth in 8:
  var evidence: Dictionary=cursor.get("evidence",{})
  for id in evidence:
   if id in ["museum","H","F","H_r","F_r"] and evidence[id].get("holder","")=="player": return true
  cursor=cursor.get("origin",{})
  if cursor.is_empty(): break
 return false
func success() -> bool:
 return has("verify_history") and attempts.size()==2 and attempts[1].day>attempts[0].day
func status(who: String) -> String:
 if people[who].closed: return "暂停未来参与；已发生的观察保留"
 if warnings.has(who): return "预警：全局第%d回合末暂停协助" % (entry_turn+int(warnings[who])-1)
 return "愿意合作" if cooperative(who) else "先说明来意" if people[who].t<60 else "压力过高，先处理风险"
func flight_text() -> String:
 return "历史：%s · 共同支持：%s\n初次现象：%s · 跨日复核：%s\n下次参与者：%s" % ["已核实" if has("verify_history") else "未核实","已形成" if has("witnesses") else "未形成","已记录" if has("first_trial") else "未记录","已完成" if success() else "未完成",NAMES.get(participant,"尚未选择")]

func blocked(id: String, use_support := false) -> Array:
 if not ACTIONS.has(id): return ["未知行动"]
 var a: Dictionary=ACTIONS[id]
 var reasons: Array=[]
 if finished: reasons.append("羽之森章节已结束")
 if not presentation.is_empty(): reasons.append("先读完当前对白")
 if completed(id): reasons.append("已经完成")
 if use_support and not support_available(id): reasons.append("这项前章帮助不可用，或2 AP折扣额度已用完")
 if ap<cost(id,use_support): reasons.append("AP不足，需要%d" % cost(id,use_support))
 if day<a.get("first",1) or day>a.get("last",5): reasons.append("开放日期：第%d—%d天" % [a.get("first",1),a.get("last",5)])
 for req in a.get("requires",[]):
  if not has(req): reasons.append("需要「%s」" % DOCS.get(req,ACTIONS.get(req,{}).get("title","进入高塔")))
 if a.get("participant",false) and not participant_ready(): reasons.append("需要一位自愿合作的普通参与者：艾尔或洛恩")
 if a.has("cooperate") and not cooperative(a.cooperate): reasons.append("需要信任≥60、警戒<60且协助未暂停")
 if a.has("doc") and docs.has(a.doc): reasons.append("已持有同来源材料，不重复收费")
 if id.begins_with("select_") and participant==id.trim_prefix("select_"): reasons.append("已经是下次参与者")
 if id=="replicate" and (attempts.is_empty() or day<=attempts[0].day): reasons.append("必须在首次尝试之后的另一天复核")
 if id in ["tower_enter","tower_permit"] and has("tower_open"): reasons.append("已经进入高塔，无需重复付费")
 if id=="signature_application" and (formal_receipt() or has("signature")): reasons.append("已有有效回执或签署材料，无需申请")
 if id=="query_signature" and not formal_receipt() and not has("signature_application"): reasons.append("需先登记本地申请，或携带学城正式回执")
 if id=="cross_region" and not carried_evidence(): reasons.append("需要实际携带的渔村材料或馆藏实证核验底稿，寄存物和同源抄本不算")
 if id=="sea_supplement" and supplement_gain()==0: reasons.append("已有读者没有待补充的新证据收益")
 return reasons

func consequence(id: String) -> String:
 match id:
  "verify_history": return "核实普通羽人曾承担空中运输。不直接增加海洋认知，也不自动恢复飞行。"
  "el_help","lo_help": return "信任+20；约定自愿参与的边界。若尚无参与者，将优先选择此人；洛恩需先见到核实后的历史。"
  "ika_help": return "伊卡恩信任+25。贵族的个人反例不替代普通羽人的飞行观察。"
  "select_el","select_lo": return "免费选择下一次尝试或展示的普通参与者，不更改之前的观察记录。"
  "witnesses": return "向小范围普通居民解释已核实的历史，形成支持与见证；不直接增加海洋认知。"
  "prepare": return "准备低台，约定尝试和停止方式。首次尝试2 AP，之后另一天复核2 AP。"
  "first_trial": return "条件具备后记录短暂腾空，无隐藏随机失败。参与者警戒+5；尚未通关，另一天需2 AP复核。最晚第四天首次尝试。"
  "replicate": return "在另一天完成观察，参与者警戒+5。确认普通羽人的飞行现象，达成基本目标；不直接增加海洋认知。"
  "public_demo": return "第五天自愿公开展示，当前参与者警戒+25；达到60时预告下一回合末的压力。含公开解释已核实海洋依据，公众海洋认知+%d。不是因为飞起来就自动证明大海。" % reward("public")
  "protect_el","protect_lo": return "此人警戒−20，可解除未到期的预警；不撤回公开事实，不恢复已经暂停的协助。"
  "tower_permit": return "由伊卡恩带领步行进入高塔，他的警戒+10。观察需另1 AP；不要求恢复长距离飞行。"
  "tower_locate": return "定位废弃入口。之后进入需2 AP、观察需1 AP，不依赖伊卡恩。"
  "tower_enter": return "步行进入高塔，观察另需1 AP。已进入的地点不会因他人后来暂停协助而失效。"
  "tower_observe": return "取得有方向与见证的远方水面观察，以及疯祭司签署的禁令来源。后续传播收益提高，已接触读者需补充说明。"
  "trace_ban": return "核对‘不许飞’到‘不能飞’的时间线；先后关系不是法器原理的证明。"
  "query_signature": return "取得禁令签署来源，指向疯祭司。"+("完整责任异议还允许追问签署与执行责任，保存供王城使用。" if origin.get("findings",{}).get("file_full",false) else "不自动解除禁令，也不提供高塔观察。")
  "cross_region": return "核验独立实证，提升后续海洋说明收益。不会把同一证据的抄本重复加成。"
  "sea_share": return "居民读到并回应海洋依据，公众海洋认知+%d；同一渠道只领取一次完整收益。" % reward("small")
  "sea_supplement": return "向已接触的读者解释新增依据，只增加尚未领取的差额%d。" % supplement_gain()
 return "取得可回看的材料或程序入口，不自动增加公众认知。"
func preview(id: String, use_support := false) -> Dictionary:
 var reasons:=blocked(id,use_support)
 var text: String="本次消耗%d AP。\n%s" % [cost(id,use_support),consequence(id)]
 if support_available(id): text+="\n可主动使用学城帮助，节省1 AP；剩余折扣额度%d。" % (2-discount_used)
 if use_support: text+="\n本次已选择使用帮助，确认后消耗一次额度。"
 if ACTIONS[id].get("participant",false): text+="\n当前自愿参与者："+NAMES.get(participant,"尚未选择")
 if not reasons.is_empty(): text+="\n不能执行："+"；".join(reasons)
 return {"allowed":reasons.is_empty(),"text":text}

func add_doc(id: String) -> void: docs[id]={"source":"forest:"+id,"holder":"player"}
func execute(id: String, use_support := false) -> bool:
 if not blocked(id,use_support).is_empty(): return false
 var paid:=cost(id,use_support)
 ap-=paid
 spent+=paid
 if use_support:
  consumed.append(id)
  discount_used+=1
 if not id.begins_with("select_"): flags[action_key(id)]=true
 var a: Dictionary=ACTIONS[id]
 if a.has("doc"): add_doc(a.doc)
 match id:
  "el_help","lo_help","ika_help":
   people[a.group].t+=25 if id=="ika_help" else 20
   if participant.is_empty() and a.group in ["el","lo"]: participant=a.group
  "select_el","select_lo": participant=id.trim_prefix("select_")
  "protect_el","protect_lo": people[a.group].a=maxi(0,people[a.group].a-20)
  "first_trial","replicate":
   attempts.append({"day":day,"participant":participant,"kind":id,"witnessed":true,"phenomenon":"brief_lift"})
   people[participant].a+=5
  "public_demo":
   people[participant].a+=25
   flags["public_participant"]=participant
   deliver("public")
  "tower_enter","tower_permit":
   flags["tower_open"]=true
   if id=="tower_permit": people.ika.a+=10
  "tower_observe":
   add_doc("tower_observation")
   if not has("signature"): add_doc("signature")
  "query_signature":
   if origin.get("findings",{}).get("file_full",false): flags["responsibility_query"]=true
  "sea_share": deliver("small")
  "sea_supplement":
   for channel in deliveries: deliver(channel)
 sync_risk()
 history.append({"day":day,"action":id,"title":a.title,"ap":ap,"belief":belief,"receipt":"消耗%d AP%s；进展已保存" % [paid,"，已使用学城帮助" if use_support else ""]})
 return true
func deliver(channel: String) -> void:
 var prior: int=int(deliveries.get(channel,{}).get("gain",0))
 var delta:=maxi(0,reward(channel)-prior)
 belief=mini(100,belief+delta)
 deliveries[channel]={"day":day,"gain":prior+delta,"tier":evidence_tier()}
func sync_risk() -> void:
 for who in NAMES:
  if people[who].closed: continue
  if people[who].a>=60:
   if not warnings.has(who): warnings[who]=day+1
  else: warnings.erase(who)
func settle_prior_contacts() -> void:
 for who in origin.get("warnings",{}):
  if int(origin.warnings[who])<=absolute_day() and not prior_contacts.has(who):
   prior_contacts[who]="suspended"
   events.append("学城来信：%s的个人预警已到期，后续协助暂停。已交出的成果保留，不扣羽之森AP。" % {"mo":"墨先生","er":"二笔","gao":"高帽子"}.get(who,who))
func end_preview() -> String:
 var text: String="剩余%d AP不结转。首次尝试最晚第4天，复核必须隔日；安翼礼只在第5天。" % ap
 if day==4 and not has("first_trial"): text+="\n尚未首次尝试：今天结束后将无法在本章完成跨日复核。"
 if day==4 and not success(): text+="\n若第五天才复核，剩余1 AP不足以同时进行2 AP公开展示。"
 if day==5: text+="\n今天结束后离林。\n"+result_text()
 for who in warnings: text+="\n"+NAMES[who]+"："+status(who)
 return text
func end_day() -> bool:
 if finished or not presentation.is_empty(): return false
 events=[]
 for who in warnings.keys():
  if int(warnings[who])<=day:
   people[who].closed=true
   warnings.erase(who)
   events.append(NAMES[who]+"因压力暂停未来协助。飞行观察与实际传播仍保留。")
 if day==5:
  finished=true
  snapshot=make_snapshot()
 else:
  day+=1
  ap=3
  settle_prior_contacts()
 return true
func result_text() -> String:
 var text: String="羽之森基本目标完成：普通羽人的飞行现象已跨日复核。" if success() else "本章尚未完成跨日复核，已取得的发现仍然保留。"
 text+="\n公众海洋认知：%d\n%s" % [belief,flight_text()]
 text+="\n公开展示：%s；高塔观察：%s；签署来源：%s" % ["完成" if has("public_demo") else "未完成","已取得" if has("tower_observation") else "未取得","已取得" if has("signature") else "未取得"]
 return text
func report() -> String:
 var text:=result_text()+"\n\n随身材料："+"、".join(docs.keys().map(func(k): return DOCS[k]))
 for attempt in attempts: text+="\n第%d天，%s：%s，有普通居民见证。" % [attempt.day,NAMES[attempt.participant],"首次短暂腾空" if attempt.kind=="first_trial" else "再次确认腾空现象"]
 for who in NAMES: text+="\n"+NAMES[who]+"："+status(who)
 for channel in deliveries: text+="\n%s累计认知+%d" % ["小范围说明" if channel=="small" else "安翼礼公开说明",deliveries[channel].gain]
 text+="\n学城帮助已使用%d/2 AP。" % discount_used
 if has("responsibility_query"): text+="\n已保存签署与执行责任追问，可供王城交涉。"
 for who in prior_contacts: text+="\n学城联系人%s：后续协助暂停，已有成果保留。" % who
 return text+"\n\n可继续进入王城。海洋回归与最终结局由王城中的成果及最终选择决定。"
func make_snapshot() -> Dictionary:
 var exported: Dictionary={}
 for who in warnings: exported[who]=entry_turn+int(warnings[who])-1
 return {"success":success(),"belief_local":belief,"findings":flags.duplicate(true),"evidence":docs.duplicate(true),"attempts":attempts.duplicate(true),"deliveries":deliveries.duplicate(true),"people":people.duplicate(true),"warnings":exported,"prior_contacts":prior_contacts.duplicate(true),"origin":origin.duplicate(true),"next_turn":entry_turn+5,"pending_penalty":false,"discount_used":discount_used,"consumed":consumed.duplicate(),"social_results":{"ordinary_flight_replicated":success(),"public_demonstration":has("public_demo"),"second_participant":attempts.size()==2 and attempts[0].participant!=attempts[1].participant}}
func to_data() -> Dictionary:
 var data: Dictionary={}
 for key in ["day","entry_turn","ap","spent","belief","selected","location","participant","people","flags","docs","origin","deliveries","attempts","history","events","warnings","prior_contacts","consumed","discount_used","presentation","snapshot","finished"]: data[key]=get(key)
 return data.duplicate(true)
func valid_data(data: Dictionary) -> bool:
 for key in to_data():
  if not data.has(key): return false
 for key in ["day","entry_turn","ap","spent","belief","discount_used"]:
  if not data[key] is int: return false
 if data.day<1 or data.day>5 or data.entry_turn<1 or data.ap<0 or data.ap>3 or data.spent<0 or data.belief<0 or data.belief>100 or data.discount_used<0 or data.discount_used>2: return false
 for key in ["people","flags","docs","origin","deliveries","warnings","prior_contacts","presentation","snapshot"]:
  if not data[key] is Dictionary: return false
 for key in ["attempts","history","events","consumed"]:
  if not data[key] is Array: return false
 if not data.finished is bool or data.location!="feather_forest": return false
 if not data.selected is String or (data.selected!="" and not NAMES.has(data.selected)): return false
 if data.participant not in ["","el","lo"]: return false
 for who in NAMES:
  if not data.people.get(who) is Dictionary: return false
  var p: Dictionary=data.people[who]
  if not p.get("t") is int or not p.get("a") is int or not p.get("closed") is bool: return false
  if p.t<0 or p.t>100 or p.a<0 or p.a>100: return false
 if data.attempts.size()>2: return false
 for i in data.attempts.size():
  var a=data.attempts[i]
  if not a is Dictionary or not a.get("day") is int or a.get("participant","") not in ["el","lo"] or a.get("witnessed",false)!=true: return false
  if a.day<1 or a.day>data.day or a.get("kind","")!=("first_trial" if i==0 else "replicate"): return false
 if data.attempts.size()==2 and data.attempts[1].day<=data.attempts[0].day: return false
 if data.flags.has("first_trial")!=(data.attempts.size()>=1) or data.flags.has("replicate")!=(data.attempts.size()==2): return false
 for doc in data.docs:
  if not DOCS.has(doc) or not data.docs[doc] is Dictionary or data.docs[doc].get("holder","")!="player": return false
 for channel in data.deliveries:
  if channel not in ["small","public"] or not data.deliveries[channel] is Dictionary or not data.deliveries[channel].get("gain") is int: return false
  if data.deliveries[channel].gain<0: return false
 for who in data.warnings:
  if not NAMES.has(who) or not data.warnings[who] is int: return false
 if data.consumed.size()!=data.discount_used: return false
 for item in data.history:
  if not item is Dictionary or not item.get("title") is String: return false
  for key in ["day","ap","belief"]:
   if not item.get(key) is int: return false
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
