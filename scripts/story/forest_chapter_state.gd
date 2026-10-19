extends RefCounted
const Narrative := preload("res://scripts/story/forest_chapter_story.gd")
const Er := preload("res://scripts/story/er_consequences.gd")
const RULESET := "forest_investigation_v2"
const NAMES := {"el":"艾尔","lo":"洛恩","ika":"伊卡恩"}
const DOCS := {"platform":"废弃的观测台与旧石牌","old_routes":"旧通行与登高记录","old_customs":"高墙修建前的生活回忆","wing_bones":"羽人的翅骨与测绘记录","wall_record":"高墙修建与删改历史记录","signature":"修建记录签署者：疯祭司","sea_record":"海岸与外部水域记载核验","cross_region":"渔村实证与海岸记载核对"}
const ACTIONS := {
 "er_prepare":{"title": "托人送出二笔与师姐的交接凭据", "group": "research", "ap": 1},
 "er_receive":{"title": "安排接应二笔并恢复安全联系", "group": "research", "ap": 1, "requires": ["er_prepare"]},
 "el_help":{"title": "听艾尔讲梦境，约定调查中的帮助", "group": "el", "ap": 1},
 "lo_help":{"title": "听洛恩讲家人与旧习俗", "group": "lo", "ap": 1},
 "lo_memory":{"title": "请洛恩回忆高墙修建前的生活", "group": "lo", "ap": 1, "cooperate": "lo", "requires": ["platform"], "doc": "old_customs"},
 "ika_help":{"title": "用调查线索重新核对伊卡恩的经历", "group": "ika", "ap": 1, "requires": ["platform"]},
 "protect_el":{"title": "安排艾尔家人的陪同与联系", "group": "el", "ap": 1, "requires": ["el_help"]},
 "protect_lo":{"title": "安排洛恩家人的陪同与联系", "group": "lo", "ap": 1, "requires": ["lo_help"]},
 "protect_ika":{"title": "安排伊卡恩回应长辈的追问", "group": "ika", "ap": 1, "requires": ["ika_help"]},
 "select_el":{"title": "请艾尔担任具名支持者", "group": "el", "ap": 0, "cooperate": "el"},
 "select_lo":{"title": "请洛恩担任具名支持者", "group": "lo", "ap": 0, "cooperate": "lo"},
 "select_ika":{"title": "请伊卡恩担任具名支持者", "group": "ika", "ap": 0, "cooperate": "ika"},
 "platform":{"title": "调查废弃观测台与旧石牌", "group": "research", "ap": 1, "doc": "platform"},
 "roster":{"title": "自行查找旧通行记录", "group": "research", "ap": 1, "requires": ["platform"], "doc": "old_routes"},
 "lead_compare":{"title": "整理观测台与旧生活的疑点", "group": "research", "ap": 0, "requires": ["platform"]},
 "tower_permit":{"title": "请伊卡恩利用通行资格带路", "group": "ika", "ap": 1, "cooperate": "ika", "requires": ["lead_compare"], "last": 4},
 "tower_locate":{"title": "按旧图寻找高塔废弃入口", "group": "research", "ap": 1, "requires": ["lead_compare"], "last": 4},
 "tower_enter":{"title": "从废弃入口进入高塔", "group": "research", "ap": 2, "requires": ["lead_compare", "tower_locate"], "last": 4},
 "tower_search":{"title": "调查封存区的翅骨与修建记录", "group": "research", "ap": 1, "requires": ["tower_open"], "last": 4},
 "verify_history":{"title": "核对身体痕迹、翅骨与修建记录", "group": "research", "ap": 1, "requires": ["wing_bones", "wall_record"]},
 "preserve":{"title": "保全证据与可供核查的副本", "group": "research", "ap": 1, "requires": ["verify_history"]},
 "corroborate":{"title": "用观测台与旧习俗补强证据", "group": "research", "ap": 1, "requires": ["verify_history", "lead_compare"], "last": 4},
 "witnesses":{"title": "提前联系愿意听证据的居民", "group": "research", "ap": 1, "requires": ["preserve"], "participant": true, "last": 4},
 "sea_basis":{"title": "核对旧记录中的海岸与外部水域", "group": "research", "ap": 1, "requires": ["verify_history"], "doc": "sea_record"},
 "cross_region":{"title": "用携带的渔村实证核对海岸记载", "group": "research", "ap": 1, "requires": ["verify_history"], "doc": "cross_region"},
 "discreet":{"title": "整理公开范围，避开巡视关注", "group": "research", "ap": 1},
 "sea_share":{"title": "向少数居民解释并留下证据", "group": "research", "ap": 1, "requires": ["preserve"]},
 "public_demo":{"title": "在安翼礼公开证据与质疑", "group": "research", "ap": 2, "requires": ["preserve", "witnesses"], "participant": true, "first": 5, "last": 5},
 "sea_supplement":{"title": "向原来的读者补充海洋依据", "group": "research", "ap": 1, "requires": ["preserve"]},
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
var official_alert := 10
var finished := false

func initialize(seed: Dictionary) -> void:
 origin=seed.duplicate(true)
 entry_turn=int(origin.get("next_turn",16))
 if origin.get("pending_penalty",false):
  ap=2
  events.append("前区查验占用首日1 AP，仅结算一次。")
 if origin.get("findings",{}).get("rescue_extra",false):
  flags["tower_locate"]=true
  events.append("二笔的札记标明废弃入口，省去定位；仍需先查观测台与另一项独立线索，再进入取证。")
 settle_prior_contacts()
func absolute_day() -> int: return entry_turn+day-1
func has(id: String) -> bool: return flags.has(id) or docs.has(id)
func cooperative(who: String) -> bool: return NAMES.has(who) and people[who].t>=60 and people[who].a<60 and not people[who].closed
func participant_ready() -> bool: return cooperative(participant)
func er_investigated() -> bool: return Er.investigated(origin,absolute_day())
func er_link_blocked() -> bool: return er_investigated() and not has("er_relieved") and Er.dependent_link(origin)
func support_available(id: String) -> bool:
 if discount_used>=2 or consumed.has(id): return false
 match id:
  "roster": return origin.get("channels",{}).get("independent_archive",false) and not er_link_blocked()
  "witnesses": return origin.get("channels",{}).get("public_record",false)
  "tower_enter": return origin.get("findings",{}).get("rescue_extra",false)
 return false
func cost(id: String,use_support := false) -> int:
 if not ACTIONS.has(id): return 0
 if id=="er_receive" and Er.market_help(origin): return 0
 return int(ACTIONS[id].ap)-(1 if use_support and support_available(id) else 0)
func evidence_tier() -> int: return (1 if has("sea_record") else 0)+(1 if has("cross_region") else 0)
func reward(channel: String) -> int:
 return int(([0,10,20] if channel=="small" else [0,20,30])[evidence_tier()])
func supplement_gain() -> int:
 var total:=0
 for channel in deliveries: total+=maxi(0,reward(channel)-int(deliveries[channel].gain))
 return total
func action_key(id: String) -> String: return id+":"+str(evidence_tier()) if id=="sea_supplement" else id
func completed(id: String) -> bool: return false if id.begins_with("select_") else flags.has(action_key(id))
func carried_evidence() -> bool:
 var cursor: Dictionary=origin
 for depth in 8:
  for id in cursor.get("evidence",{}):
   if id in ["museum","H","F","H_r","F_r"] and cursor.evidence[id].get("holder","")=="player": return true
  cursor=cursor.get("origin",{})
  if cursor.is_empty(): break
 return false
func success() -> bool: return has("verify_history") and has("wing_bones") and has("wall_record") and has("preserve")
func investigation_shared() -> bool: return success() and not deliveries.is_empty()
func lift_ready() -> bool: return has("corroborate") and has("witnesses") and participant_ready() and official_alert<60
func status(who: String) -> String:
 if people[who].closed: return "暂停新的协助；已有证据保留"
 if warnings.has(who): return "预警：全局第%d回合末到期，可先保护" % (entry_turn+int(warnings[who])-1)
 return "愿意合作" if cooperative(who) else "先了解想法并争取信任" if people[who].t<60 else "压力过高，需先保护"
func flight_text() -> String:
 return "调查：%s · 证据保全：%s\n飞行命题：%s · 飞行迹象：%s\n官方警戒：%d / 60（达到60阻止公开）\n具名支持者：%s" % ["已核实" if has("verify_history") else "未核实","完成" if has("preserve") else "未完成","公开" if has("public_demo") else "小范围" if has("sea_share") else "未传播","出现" if has("flight_sign") else "未出现",official_alert,NAMES.get(participant,"未选择")]
func blocked(id: String,use_support := false) -> Array:
 if not ACTIONS.has(id): return ["未知行动"]
 var a: Dictionary=ACTIONS[id]
 var reasons: Array=[]
 if finished: reasons.append("羽之森章节已结束")
 if not presentation.is_empty(): reasons.append("先读完当前对白")
 if completed(id): reasons.append("已经完成，不重复结算")
 if use_support and not support_available(id): reasons.append("前章帮助不可用，或两次额度已用完")
 if ap<cost(id,use_support): reasons.append("需要%d AP" % cost(id,use_support))
 if day<int(a.get("first",1)) or day>int(a.get("last",5)): reasons.append("开放日期：第%d—%d天；第四天末高塔封锁，之后不能进入或补取证据" % [a.get("first",1),a.get("last",5)])
 for req in a.get("requires",[]):
  if not has(req): reasons.append("需要："+str(DOCS.get(req,ACTIONS.get(req,{}).get("title","进入高塔"))))
 if a.get("participant",false) and not participant_ready(): reasons.append("需要一名愿意具名合作的支持者，可在人物卡免费选择")
 if a.has("cooperate") and not cooperative(a.cooperate): reasons.append("需要信任≥60、警戒<60且协助未暂停")
 if id in ["lead_compare","ika_help"] and not has("old_routes") and not has("old_customs"): reasons.append("先取得旧通行记录或洛恩的旧生活回忆，单次交谈不能代替调查")
 if id in ["tower_permit","tower_enter"] and has("tower_open"): reasons.append("已经进入，无需重复付费")
 if id in ["er_prepare","er_receive"] and not er_investigated(): reasons.append("二笔没有遭到停职追查，无需事后接应")
 if id.begins_with("select_") and participant==id.trim_prefix("select_"): reasons.append("已经是当前支持者")
 if id.begins_with("protect_") and people[a.group].closed: reasons.append("协助已经暂停，保护不能恢复已关闭渠道")
 if id=="cross_region" and not carried_evidence(): reasons.append("需要实际携带的渔村实证或馆藏核验底稿")
 if id=="public_demo" and official_alert>=60: reasons.append("官方警戒达到60，巡视阻止公开；可整理公开范围降低20，或转为小范围说明")
 if id=="sea_supplement" and supplement_gain()==0: reasons.append("原来的读者没有待补充的海洋依据")
 if id=="discreet" and official_alert==0: reasons.append("当前无需降低官方警戒")
 return reasons
func consequence(id: String) -> String:
 match id:
  "platform": return "记录观测台早于高墙的接缝与辨风向、识归途的石牌。接着查旧通行记录，或请洛恩补充旧习俗。"
  "roster","lo_memory": return "取得另一条独立线索，可以免费整理疑点；不会自动证明飞行恢复。"
  "lead_compare": return "确认观测设施早于高墙，旧生活与现有说法矛盾。开放高塔调查路线，不增加海洋认知。"
  "ika_help": return "信任+25。调查结果使他愿意重新看待坠落经历；贵族与普通人本来都能飞，身份只影响高塔权限。"
  "el_help","lo_help": return "信任+20；听取顾虑并约定帮助。若还没有具名支持者，优先选择此人。"
  "select_el","select_lo","select_ika": return "免费选择公开证据时的具名支持者，不把别人的经历改写为此人的经历。"
  "tower_permit": return "利用伊卡恩的通行资格步行进入，他的警戒+10。调查封存区另需1 AP，必须在第四天结束前完成。"
  "tower_locate": return "定位废弃入口，官方警戒+5；自行进入另需2 AP。二笔札记可免定位。"
  "tower_enter": return "自行进入，官方警戒+25；封存区取证另需1 AP。不能凭入口线索直接获得证据。"
  "tower_search": return "同时取得翅骨测绘与修建记录（签署者为疯祭司）。需要另1 AP核对，再1 AP保全，才完成基本目标。"
  "verify_history": return "核对身体痕迹、古老翼骨与限制外出和删改历史的记录。确认过去能力平等，不宣称现在人人恢复飞行。"
  "preserve": return "保存可核查的证据与副本，完成基本目标；不公开也可离林，不增加公众认知。"
  "corroborate": return "用塔外独立线索补强高塔证据。须第四天前完成，与提前组织、有效支持者及安全公开共同触发飞行迹象。"
  "witnesses": return "提前组织愿意听证据的居民，须第四天前完成。不增加认知；第五天可选择公开。"
  "sea_basis": return "核实修建档案中的海岸与外部水域条目，官方警戒+10；只有实际传播后才增加海洋认知。"
  "cross_region": return "携带的独立实证与海岸条目互相核对；只有传播或补充说明才增加海洋认知。"
  "discreet": return "整理公开范围、避开巡视，官方警戒−20；不抹去已有证据、传播和个人风险。只能安排一次。"
  "sea_share": return "向少数居民解释飞行历史并留下材料，不要求NPC具名。海洋认知+%d；没有核实海洋依据则为0，仍计有效飞行命题传播。" % reward("small")
  "public_demo": return "第五天公开证据，官方警戒+20，具名支持者警戒+35；达到60产生下一回合末预警。海洋认知+%d。%s 不以腾空作为基本通关或海回归的唯一条件。" % [reward("public"),"准备齐全，将出现短暂离地迹象。" if lift_ready() else "未完成额外补强，本次只传播证据，不出现腾空。"]
  "protect_el","protect_lo","protect_ika": return "安排记录、陪同回应与联系，此人警戒−20；可解除未到期预警，不能抹去公开身份或恢复已暂停协助。"
  "sea_supplement": return "向原读者补充海洋依据，只增加尚未获得的差额%d。" % supplement_gain()
  "er_prepare": return "送出交接凭据，澄清师姐未参与额外开箱；仍需接应，可以跨天完成。"
  "er_receive": return "接应后恢复安全联系，但二笔失去工作的损失保留。"+("可用集市渠道使本步免费。" if Er.market_help(origin) else "本步1 AP。")
 return "进展与来源将保存。"
func preview(id: String,use_support := false) -> Dictionary:
 var reasons:=blocked(id,use_support)
 var text: String="本次消耗%d AP。\n%s" % [cost(id,use_support),consequence(id)]
 if support_available(id): text+="\n可主动使用学城帮助减1 AP，剩余%d次。" % (2-discount_used)
 if ACTIONS.get(id,{}).get("participant",false): text+="\n当前具名支持者："+NAMES.get(participant,"未选择")
 if not reasons.is_empty(): text+="\n不能执行："+"；".join(reasons)
 return {"allowed":reasons.is_empty(),"text":text}
func add_doc(id: String) -> void: docs[id]={"source":"forest:"+id,"holder":"player"}
func execute(id: String,use_support := false) -> bool:
 if not blocked(id,use_support).is_empty(): return false
 var lift: bool=id=="public_demo" and lift_ready()
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
  "er_receive":
   flags["er_relieved"]=true
   prior_contacts["er"]="assisted"
  "el_help","lo_help","ika_help":
   people[a.group].t+=25 if id=="ika_help" else 20
   if participant.is_empty(): participant=a.group
  "select_el","select_lo","select_ika": participant=id.trim_prefix("select_")
  "protect_el","protect_lo","protect_ika": people[a.group].a=maxi(0,people[a.group].a-20)
  "tower_locate": official_alert+=5
  "tower_enter","tower_permit":
   flags["tower_open"]=true
   if id=="tower_permit": people.ika.a+=10
   else: official_alert+=25
  "tower_search":
   add_doc("wing_bones")
   add_doc("wall_record")
   add_doc("signature")
  "sea_basis": official_alert+=10
  "discreet": official_alert=maxi(0,official_alert-20)
  "public_demo":
   flags["public_participant"]=participant
   if lift: flags["flight_sign"]=true
   people[participant].a+=35
   official_alert+=20
   deliver("public")
  "sea_share": deliver("small")
  "sea_supplement":
   for channel in deliveries: deliver(channel)
 official_alert=clampi(official_alert,0,100)
 sync_risk()
 history.append({"day":day,"action":id,"title":a.title,"ap":ap,"belief":belief,"receipt":"消耗%d AP；%s" % [paid,("公开完成，出现短暂离地迹象" if lift else "公开完成，未出现飞行迹象") if id=="public_demo" else "进展已保存"]})
 return true
func deliver(channel: String) -> void:
 var prior: int=int(deliveries.get(channel,{}).get("gain",0))
 var gain:=maxi(prior,reward(channel))
 belief=mini(100,belief+gain-prior)
 deliveries[channel]={"day":day,"gain":gain,"tier":evidence_tier(),"topic":"flight_history","sea_explained":gain>0}
func sync_risk() -> void:
 for who in NAMES:
  if people[who].closed: continue
  if people[who].a>=60:
   if not warnings.has(who): warnings[who]=day+1
  else: warnings.erase(who)
func settle_prior_contacts() -> void:
 if er_investigated() and not prior_contacts.has("er"):
  prior_contacts["er"]="suspended"
  events.append("学城来信：二笔被停职盘问，师姐也接受核查。可在公共调查分两步送出凭据并接应，共2 AP，可跨日；可用集市渠道使接应免费，共1 AP。札记与已传播成果保留。")
  if er_link_blocked(): events.append("由二笔维系的抄写员联系受查，暂不能借该联系减免旧通行记录调查费用；你仍可自行调查。完成接应后恢复，高塔札记的帮助不受影响。")
 for who in origin.get("warnings",{}):
  if int(origin.warnings[who])<=absolute_day() and not prior_contacts.has(who):
   prior_contacts[who]="suspended"
   events.append("学城来信：%s的个人预警已到期，后续协助暂停。已交出的成果保留，不扣羽之森AP。" % {"mo":"墨先生","er":"二笔","gao":"高帽子"}.get(who,who))
func end_preview() -> String:
 var text: String="剩余%d AP不结转。第四天末高塔封锁，第五天只能处理已取得的材料与传播。" % ap
 if day==4:
  if not has("wall_record"): text+="\n尚未取齐高塔证据，结束今天将错过本章基本通关机会。"
  if not has("witnesses"): text+="\n未提前组织居民，明天只能保存或小范围说明，不能临时公开。"
 if day==5: text+="\n安翼礼结束后离林。\n"+result_text()
 for who in warnings: text+="\n"+NAMES[who]+"："+status(who)
 return text
func end_day() -> bool:
 if finished or not presentation.is_empty(): return false
 events=[]
 for who in warnings.keys():
  if int(warnings[who])<=day:
   people[who].closed=true
   warnings.erase(who)
   events.append(NAMES[who]+"受到追问，暂停新的协助；已取得材料与传播保留。")
 if day==4: events.append("安翼礼前戒严开始，高塔入口与封存区关闭；随身证据仍然保留。")
 if day==5:
  finished=true
  snapshot=make_snapshot()
 else:
  day+=1
  ap=3
  settle_prior_contacts()
 return true
func result_text() -> String:
 var result: String="调查未完成；保留已有发现。"
 if success(): result="查明真相：核实并保全翅骨与高墙修建记录。"
 if investigation_shared(): result="动摇旧说法：核实、保全证据，并完成有效传播。"
 if has("flight_sign"): result="出现飞行迹象：公开证据后，有羽人短暂离地；尚未恢复自由飞行。"
 return result+"\n海洋认知：%d\n%s" % [belief,flight_text()]
func report() -> String:
 var text:=result_text()+"\n\n随身材料："+"、".join(docs.keys().map(func(k): return DOCS[k]))
 for who in NAMES: text+="\n"+NAMES[who]+"："+status(who)
 text+="\n"+Narrative.family_text(make_snapshot())+"\n"+Er.epilogue(origin,flags,absolute_day())
 text+="\n学城帮助已使用%d/2次；累计消耗%d AP。" % [discount_used,spent]
 return text+"\n可继续进入王城。海回归需要核实并保全两项证据及有效传播，不要求腾空；海洋认知另按海洋依据计算。"
func make_snapshot() -> Dictionary:
 var exported: Dictionary={}
 for who in warnings: exported[who]=entry_turn+int(warnings[who])-1
 return {"ruleset":RULESET,"success":success(),"belief_local":belief,"findings":flags.duplicate(true),"evidence":docs.duplicate(true),"attempts":[],"deliveries":deliveries.duplicate(true),"people":people.duplicate(true),"warnings":exported,"prior_contacts":prior_contacts.duplicate(true),"origin":origin.duplicate(true),"next_turn":entry_turn+5,"pending_penalty":false,"discount_used":discount_used,"consumed":consumed.duplicate(),"official_alert":official_alert,"social_results":{"investigation_shared":investigation_shared(),"public_demonstration":has("public_demo"),"flight_sign":has("flight_sign")}}
func to_data() -> Dictionary:
 var data: Dictionary={}
 for key in ["day","entry_turn","ap","spent","belief","selected","location","participant","people","flags","docs","origin","deliveries","attempts","history","events","warnings","prior_contacts","consumed","discount_used","official_alert","presentation","snapshot","finished"]: data[key]=get(key)
 return data.duplicate(true)
func valid_data(data: Dictionary) -> bool:
 for key in to_data():
  if not data.has(key): return false
 for key in ["day","entry_turn","ap","spent","belief","discount_used","official_alert"]:
  if not data[key] is int: return false
 if data.day<1 or data.day>5 or data.entry_turn<1 or data.ap<0 or data.ap>3 or data.spent<0 or data.belief<0 or data.belief>100 or data.discount_used<0 or data.discount_used>2: return false
 for key in ["people","flags","docs","origin","deliveries","warnings","prior_contacts","presentation","snapshot"]:
  if not data[key] is Dictionary: return false
 for key in ["attempts","history","events","consumed"]:
  if not data[key] is Array: return false
 if not data.finished is bool or data.location!="feather_forest": return false
 if not data.selected is String or (data.selected!="" and not NAMES.has(data.selected)): return false
 for who in NAMES:
  if not data.people.get(who) is Dictionary: return false
  var p: Dictionary=data.people[who]
  if not p.get("t") is int or not p.get("a") is int or not p.get("closed") is bool: return false
  if p.t<0 or p.t>100 or p.a<0 or p.a>100: return false
 if data.official_alert<0 or data.official_alert>100: return false
 if not data.attempts.is_empty(): return false
 if data.participant not in ["","el","lo","ika"]: return false
 if data.flags.has("verify_history") and (not data.docs.has("wing_bones") or not data.docs.has("wall_record")): return false
 if data.flags.has("preserve") and not data.flags.has("verify_history"): return false
 if not data.deliveries.is_empty() and not data.flags.has("preserve"): return false
 if data.flags.has("flight_sign") and (not data.flags.has("public_demo") or not data.flags.has("corroborate")): return false
 if data.flags.has("public_demo") and (not data.flags.has("witnesses") or not data.deliveries.has("public") or data.flags.get("public_participant","") not in NAMES): return false
 if data.flags.has("sea_share") and not data.deliveries.has("small"): return false
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
