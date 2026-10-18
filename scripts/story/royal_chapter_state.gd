extends RefCounted
## The terminal chapter keeps regional beliefs distinct; only delivered information counts.
const RULESET := "royal_six_days_v1"
const NAMES := {"priest":"疯祭司","inspector":"审查官","king":"国王"}
const REGIONS := {"village":"渔村","market":"集市","academy":"旧学城","forest":"羽之森","royal":"王城"}
const SEA_TOTAL := 80
const SEA_REGIONAL := 20
const ENDINGS := {"sea":"海回归","liberation":"王国获得解放","new_king":"新的王","forgetting":"遗忘重临"}
const DOCS := {"archive":"禁令总档案","war":"战争旧史与外部来信","device":"法器维护与运行记录","chain":"封闭政策责任链","sea_evidence":"海洋实证核验稿","original":"认证的王室命令","testimony":"祭司自愿署名证言"}
const ACTIONS := {
 "archive":{"title":"查阅禁令总档案","group":"research","ap":1},
 "war":{"title":"核对战争旧史与外部来信","group":"research","ap":1},
 "device":{"title":"调查法器维护记录","group":"research","ap":1},
 "chain":{"title":"串联禁令、战争与法器记录","group":"research","ap":1,"requires":["archive","war","device"]},
 "sea_evidence":{"title":"核验海洋实证与官方旧航线","group":"research","ap":1,"requires":["archive"]},
 "network":{"title":"建立分散保存与传播网络","group":"research","ap":2},
 "publish":{"title":"匿名公开可核验的海洋材料","group":"research","ap":2,"requires":["sea_evidence","network"]},
 "relay_village":{"title":"向渔村递送王城新证据并收取回应","group":"research","ap":2,"requires":["publish"]},
 "relay_forest":{"title":"向羽之森递送王城新证据并收取回应","group":"research","ap":2,"requires":["publish"]},
 "relay_market":{"title":"向集市原读者补充王城证据","group":"research","ap":2,"requires":["publish"]},
 "relay_academy":{"title":"向旧学城原读者补充王城证据","group":"research","ap":2,"requires":["publish"]},
 "reconnect_village":{"title":"寻找渔村替代联络人","group":"research","ap":1},
 "reconnect_market":{"title":"寻找集市替代联络人","group":"research","ap":1},
 "reconnect_academy":{"title":"寻找旧学城替代联络人","group":"research","ap":1},
 "reconnect_forest":{"title":"寻找羽之森替代联络人","group":"research","ap":1},
 "restore_market":{"title":"恢复集市跨区组织联络","group":"research","ap":1},
 "relocate":{"title":"转移传播节点与未发材料","group":"research","ap":1,"requires":["network"]},
 "protect_source":{"title":"安排具名证人与前区联系人的保护","group":"research","ap":1},
 "bypass":{"title":"组织各节点拒绝集中查封","group":"research","ap":2,"requires":["chain","network"]},
 "disconnect":{"title":"经维护入口中断王室法器连接","group":"research","ap":2,"requires":["device"]},
 "memory":{"title":"与祭司拼合战争和禁令记忆","group":"priest","ap":2,"requires":["chain"]},
 "review_plan":{"title":"邀请居民公开复核保护方案","group":"priest","ap":2,"requires":["memory"]},
 "plan":{"title":"约定共同监督与逐步开放方案","group":"priest","ap":1,"requires":["memory"]},
 "handover":{"title":"请祭司交付法器保管权","group":"priest","ap":2,"requires":["plan"]},
 "consent":{"title":"询问祭司是否愿意具名作证","group":"priest","ap":0,"requires":["memory"]},
 "testimony":{"title":"记录祭司自愿证言并核对责任","group":"priest","ap":1,"requires":["consent"]},
 "original":{"title":"调取认证的王室原始命令","group":"inspector","ap":2,"requires":["chain"]},
 "case":{"title":"提交责任材料并要求书面答复","group":"inspector","ap":2},
 "stay":{"title":"落实暂缓查封与停止搜捕命令","group":"inspector","ap":1,"requires":["case"]},
 "deal":{"title":"接受有限改革并核验释放名单","group":"king","ap":1,"first":4,"requires":["chain"]},
 "renounce":{"title":"公开解除交易中的停止传播承诺","group":"king","ap":1,"requires":["deal"]},
 "takeover":{"title":"准备接管法器与传播中枢","group":"king","ap":2,"requires":["handover","network"]},
 "final_sea":{"title":"解除压制，让海洋回归","group":"final","ap":1,"first":6,"last":6},
 "final_liberation":{"title":"解除独占，先建立自由交流秩序","group":"final","ap":0,"first":6,"last":6},
 "final_new_king":{"title":"接管体系，成为新的掌控者","group":"final","ap":1,"first":6,"last":6},
 "final_forgetting":{"title":"停止推进，接受大典后的现状","group":"final","ap":0,"first":6,"last":6},
}
var day := 1
var entry_turn := 21
var ap := 3
var spent := 0
var belief := 0
var selected := ""
var location := "royal_city"
var people := {"priest":{"t":30,"a":20,"closed":false},"inspector":{"t":30,"a":20,"closed":false},"king":{"t":20,"a":20,"closed":false}}
var origin: Dictionary = {}
var flags: Dictionary = {}
var docs: Dictionary = {}
var regions := {"village":0,"market":0,"academy":0,"forest":0,"royal":0}
var heritage: Dictionary = {}
var controls := {"broadcast":true,"enforcement":true,"artifact":true}
var deliveries: Dictionary = {}
var prior_contacts: Dictionary = {}
var history: Array = []
var events: Array = []
var presentation: Dictionary = {}
var snapshot: Dictionary = {}
var exposure := 10
var risk_due := 0
var network_closed := false
var source_due := 0
var source_closed := false
var ending := ""
var finished := false

func initialize(seed: Dictionary) -> void:
 origin=seed.duplicate(true)
 entry_turn=int(origin.get("next_turn",21))
 var forest: Dictionary=origin
 var academy: Dictionary=forest.get("origin",{})
 var market: Dictionary=academy.get("origin",{})
 var village: Dictionary=market.get("origin",{})
 for pair in [["forest",forest],["academy",academy],["market",market],["village",village]]:
  regions[pair[0]]=clampi(int(pair[1].get("belief_local",0)),0,100)
 # The academy's returned deliveries supersede, rather than add the old market total.
 regions.market=clampi(int(academy.get("market_belief_after",regions.market)),0,100)
 heritage["market_network"]=market.get("print_available",false) or market.get("contacts_available",false)
 heritage["receipt"]=academy.get("channels",{}).get("official_receipt",false)
 heritage["collective_proof"]=forest.get("social_results",{}).get("ordinary_flight_replicated",false) or academy.get("channels",{}).get("independent_archive",false)
 heritage["signature"]=forest.get("evidence",{}).has("signature")
 heritage["physical"]=false
 for section in [forest,academy,village]:
  for item in section.get("evidence",{}):
   if item in ["tower_observation","museum","H","F","H_r","F_r"] and section.evidence[item].get("holder","")=="player": heritage.physical=true
 # Settle only still-in-transit shipments. Arrived items are already in local scores.
 for delivery in academy.get("inbound",[]):
  if delivery.get("status","")=="dispatched" and int(delivery.get("arrival_turn",99999))<=entry_turn:
   regions.academy=mini(100,regions.academy+int(delivery.get("gain",0)))
 for delivery in academy.get("outbound",[]):
  if delivery.get("status","")=="in_transit" and int(delivery.get("arrival_turn",99999))<=entry_turn:
   regions.market=mini(100,regions.market+int(delivery.get("gain",10)))
 for section in [forest,academy]:
  for who in section.get("people",{}):
   if section.people[who].get("closed",false): prior_contacts[who]={"due":0,"status":"suspended"}
 for who in forest.get("warnings",{}): prior_contacts[who]={"due":int(forest.warnings[who]),"status":"pending"}
 for who in forest.get("prior_contacts",{}): prior_contacts[who]={"due":0,"status":"suspended"}
 # Academy warnings that elapsed while travelling still affect future contacts only.
 for who in academy.get("warnings",{}):
  if not prior_contacts.has(who): prior_contacts[who]={"due":int(academy.warnings[who]),"status":"pending"}
 if seed.get("pending_penalty",false):
  ap=2
  events.append("前区已确定的查验占用首日1 AP，仅结算一次。")
 derive_foundations()
 settle_contacts()
 events.append("各地认知已分别承接。寄存材料不计为随身实证，已发生的传播不会撤回。")

func derive_foundations() -> void:
 var forest: Dictionary=origin
 var academy: Dictionary=forest.get("origin",{})
 var market: Dictionary=academy.get("origin",{})
 var village: Dictionary=market.get("origin",{})
 var vf: Dictionary=village.get("chapter_progress",{})
 var accessible:=false
 for id in village.get("evidence",{}):
  if id not in ["H","H_r","F","F_r"]: continue
  var holder: String=village.evidence[id].get("holder","")
  if holder=="player": accessible=true
  elif village.get("npc",{}).has(holder):
   var person: Dictionary=village.npc[holder]
   if not person.get("reported",false) and int(person.get("a",100))<60 and int(person.get("t",0))>=60 and not village.get("warnings",{}).has(holder): accessible=true
 heritage["village_proof"]=vf.get("verified",false) and accessible
 heritage["flight_proof"]=forest.get("social_results",{}).get("ordinary_flight_replicated",false)
 heritage["academy_chain"]=academy.get("findings",{}).get("trace",false) and academy.get("evidence",{}).has("versions") and academy.get("evidence",{}).has("execution") and academy.get("evidence",{}).has("rules")
 var readers: Dictionary={"village":not village.get("public_event",{}).is_empty() or village.get("neighbor_valid",false),"market":not market.get("deliveries",[]).is_empty(),"academy":not academy.get("deliveries",{}).is_empty(),"forest":not forest.get("deliveries",{}).is_empty()}
 for delivery in academy.get("inbound",[]):
  if delivery.get("status","")=="arrived" or delivery.get("status","")=="dispatched" and int(delivery.get("arrival_turn",99999))<=entry_turn: readers.academy=true
 var mf: Dictionary=market.get("findings",{})
 var organized: bool=mf.get("contacts",false) or market.get("print_available",false) or market.get("contacts_available",false)
 for key in mf:
  if str(key).begins_with("small:") or str(key).begins_with("rush:"): organized=true
 heritage["market_foundation"]=readers.market and organized
 heritage["readers"]=readers
 heritage["links"]={"village":village.get("neighbor_valid",false),"market":market.get("print_available",false) or market.get("contacts_available",false),"academy":academy.get("channels",{}).get("independent_archive",false) or academy.get("channels",{}).get("public_record",false),"forest":readers.forest}
 # A named forest audience retains its knowledge but may lose its original contact.
 var person_id: String=forest.get("findings",{}).get("public_participant","")
 if person_id!="" and not forest.get("deliveries",{}).has("small") and (forest.get("people",{}).get(person_id,{}).get("closed",false) or forest.get("warnings",{}).has(person_id)):
  heritage.links.forest=false
 heritage["foundations_version"]=2
func market_ready() -> bool:
 return heritage.get("market_foundation",false) and (heritage.get("market_network",false) or has("restore_market"))
func reader_ready(region: String) -> bool:
 return heritage.get("readers",{}).get(region,false)
func link_ready(region: String) -> bool:
 return heritage.get("links",{}).get(region,false) or market_ready() or has("reconnect_"+region)
func prior_reader_count() -> int:
 return heritage.get("readers",{}).values().filter(func(v): return v==true).size()
func foundation_text() -> String:
 var text: String="海回归准备：\n渔村独立实证：%s\n羽之森跨日复核：%s\n前区实际传播：%d / 2\n正式追责：%s\n集市跨区组织：%s" % ["已具备" if heritage.get("village_proof",false) else "缺少有效核验或可核查材料","已完成" if heritage.get("flight_proof",false) else "未完成",prior_reader_count(),"学城责任链已保留" if heritage.get("academy_chain",false) else "缺少学城责任链","可用" if market_ready() else "需恢复联络" if heritage.get("market_foundation",false) else "未建立"]
 for region in ["village","market","academy","forest"]: text+="\n%s读者：%s" % [REGIONS[region],"未形成，不能回传" if not reader_ready(region) else "可补传" if link_ready(region) else "需寻找替代联络人"]
 return text

func has(id: String) -> bool: return flags.has(id) or docs.has(id)
func completed(id: String) -> bool: return flags.has(id)
func absolute_day() -> int: return entry_turn+day-1
func total_belief() -> int:
 var total:=0
 for value in regions.values(): total+=int(value)
 return total
func reached_regions() -> int:
 return regions.values().filter(func(v): return int(v)>=SEA_REGIONAL).size()
func cost(id: String) -> int:
 if id=="network" and heritage.get("market_network",false): return 1
 if id=="case" and heritage.get("receipt",false): return 1
 return int(ACTIONS.get(id,{}).get("ap",0))
func active_network() -> bool: return has("network") and not network_closed
func deal_binding() -> bool: return has("deal") and not has("renounce")
func status(who: String) -> String:
 match who:
  "priest": return "证言来源已受限；已交出的材料保留" if source_closed else "具名风险：第%d天末到期" % source_due if source_due>0 else "已交付法器，最终选择仍由你决定" if has("handover") else "已同意共同监督方案" if has("plan") else "记忆已梳理" if has("memory") else "先核对战争与禁令"
  "inspector": return "已停止查封" if has("stay") else "集中查封无法执行" if has("bypass") else "已收到责任材料" if has("case") else "仍在执行禁令"
  "king": return "有限改革已执行；停止传播承诺生效" if deal_binding() else "接管准备完成，尚未作最终选择" if has("takeover") else "第4天提出有限改革交易" if day<4 else "愿以有限改革换取停止传播"
 return ""
func controls_text() -> String:
 if ending=="new_king": return "传播体系：由你独占\n禁令执行：服从你的命令\n法器：由你独占"
 return "传播封锁：%s\n禁令执行：%s\n法器独占：%s" % ["仍在控制" if controls.broadcast else "已打破","仍在执行" if controls.enforcement else "已停止 / 无法集中执行","王室仍掌握" if controls.artifact else "王室连接已解除"]
func blocked(id: String) -> Array:
 if not ACTIONS.has(id): return ["未知行动"]
 var a: Dictionary=ACTIONS[id]
 var reasons: Array=[]
 if finished: reasons.append("故事已经结束")
 if not presentation.is_empty(): reasons.append("先读完当前对白")
 if completed(id) and id!="protect_source": reasons.append("已完成，不重复结算")
 if ap<cost(id): reasons.append("需要%d AP" % cost(id))
 if day<int(a.get("first",1)) or day>int(a.get("last",6)): reasons.append("开放日期：第%d—%d天" % [a.get("first",1),a.get("last",6)])
 for req in a.get("requires",[]):
  if not has(req): reasons.append("需要："+ACTIONS.get(req,{}).get("title",req))
 if id in ["publish","relay_village","relay_forest","relay_market","relay_academy","takeover"] and not active_network(): reasons.append("需要仍可使用的传播网络，可转移节点恢复")
 if id in ["publish","relay_village","relay_forest","relay_market","relay_academy","bypass","disconnect","takeover"] or id.begins_with("final_") and id!="final_forgetting":
  if deal_binding(): reasons.append("需先解除停止传播与维持独占的交易承诺")
 if id.begins_with("relay_") or id.begins_with("reconnect_"):
  var region:=id.trim_prefix("relay_").trim_prefix("reconnect_")
  if not reader_ready(region): reasons.append("当地尚未形成接收和讨论调查材料的群体")
  elif id.begins_with("relay_") and not link_ready(region): reasons.append("需先寻找该地区替代联络人，或恢复已有集市网络")
  elif id.begins_with("reconnect_") and link_ready(region): reasons.append("现有联系已经可用，无需重复寻找")
 if id=="restore_market":
  if not heritage.get("market_foundation",false): reasons.append("集市没有留下实际读者与传播组织，王城不能从零替代")
  elif market_ready(): reasons.append("跨区组织联系已经可用")
 if id in ["bypass","takeover","final_new_king"] and not market_ready(): reasons.append("需要集市真实传播组织；已有基础但失联时可先恢复联络")
 if id in ["case","stay"] and not heritage.get("academy_chain",false): reasons.append("需要学城已核实并保存的删改责任链；王室命令只补足授权环节")
 if id=="deal" and not controls.artifact: reasons.append("王室已失去法器独占，维持独占的交易不再成立")
 if id=="disconnect":
  if controls.enforcement: reasons.append("先暂缓执行，或组织节点拒绝集中查封")
  if not controls.artifact: reasons.append("王室连接已经解除")
 if id=="bypass" and not controls.enforcement: reasons.append("禁令已经停止执行")
 if id=="stay" and not controls.enforcement: reasons.append("集中执行已经停止")
 if id=="plan" and not heritage.get("collective_proof",false) and not has("review_plan"): reasons.append("需前区集体复核成果，或在本地公开复核保护方案")
 if id in ["consent","testimony","handover"] and source_closed: reasons.append("祭司的新协助已受限；现有材料和法器不收回")
 if id=="case" and not has("original") and not has("testimony"): reasons.append("需要认证命令，或祭司自愿具名证言")
 if id=="original" and has("testimony"): reasons.append("已有有效责任证言，无需重复付费核验")
 if id=="testimony" and has("original"): reasons.append("已有认证命令，无需重复付费核验")
 if id=="protect_source" and source_due==0 and not has_pending_contacts(): reasons.append("当前没有待处理的来源风险")
 if id=="final_sea":
  if not enforcement_supported(): reasons.append("需用学城责任链落实停令，或集市组织完成分散拒绝")
  if not heritage.get("village_proof",false): reasons.append("缺少渔村独立实证：需要交叉核验与可核查材料")
  if not heritage.get("flight_proof",false): reasons.append("缺少羽之森普通羽人跨日复核")
  if prior_reader_count()<2: reasons.append("需要至少两个前区已经发生有效海洋传播，王城补传不能替代")
  if not has("chain"): reasons.append("尚未查明封闭政策的责任与原理")
  if controls.artifact: reasons.append("尚未解除王室法器压制")
  if controls.broadcast or controls.enforcement: reasons.append("尚未打破传播封锁和禁令执行")
  if total_belief()<SEA_TOTAL: reasons.append("各地认知总和需要%d，当前%d" % [SEA_TOTAL,total_belief()])
  if reached_regions()<3: reasons.append("至少3个地区认知达到20，当前%d个" % reached_regions())
  if regions.royal<20: reasons.append("王城认知需要20，必须在当地实际说明")
 if id=="final_liberation":
  if not ((has("stay") and heritage.get("academy_chain",false)) or (has("bypass") and market_ready())): reasons.append("需以学城责任链落实停令，或依靠集市组织完成分散拒绝")
  if not has("chain"): reasons.append("需要查明责任链")
  if controls.values().has(true): reasons.append("需要打破三项控制：传播、执行与法器独占")
 if id=="final_forgetting" and liberated(): reasons.append("三项控制已解除，已有成果将保底结算为解放")
 if id=="final_new_king" and not has("takeover"): reasons.append("需祭司交付法器，并完成接管准备")
 return reasons
func enforcement_supported() -> bool:
 return (has("stay") and heritage.get("academy_chain",false)) or (has("bypass") and market_ready())
func liberated() -> bool:
 return has("chain") and not controls.values().has(true) and not deal_binding() and enforcement_supported()
func has_pending_contacts() -> bool:
 for p in prior_contacts.values():
  if p.status=="pending": return true
 return false
func consequence(id: String) -> String:
 if id.begins_with("reconnect_"): return "联系已经存在的读者，恢复本地区补传入口；不恢复原NPC协助，不增加认知。"
 if id=="restore_market": return "依靠集市留下的读者和组织恢复跨区联络，开放分散拒绝与接管准备；不增加认知。"
 match id:
  "archive": return "取得禁令目录，开放海洋实证核验；不直接增加公众认知。"
  "war": return "确认历史上的入侵与封闭起因。旧战争不等于今天必然再次入侵。"
  "device": return "确认法器强化共同信念，不能凭空创造现实；取得可步行进入的维护路线。"
  "chain": return "把保护动机、长期删改与王权独占串联起来，开放责任交涉。"
  "sea_evidence": return "取得可供公众核验的旧港实证与航线。"+("随身前区实证形成独立补强，王城公开收益为45。" if heritage.get("physical",false) else "本地实证足以支持说明，王城公开收益为35。")
  "network": return "建立王城本地保存节点，不替代集市跨区组织。第5天末统一查封；需转移、停止执行或拒绝集中查封。"+("既有集市渠道使本次少1 AP。" if cost(id)==1 else "")
  "publish": return "匿名发布并回应问题：王城认知+%d，暴露+25。来源身份不公开。" % (45 if heritage.get("physical",false) else 35)
  "relay_village","relay_forest","relay_market","relay_academy": return "把王城新证据送到目标地区并取得回应：该地区认知+25（上限100）。本次完成送达，不与旧章传播重复计奖；暴露+10。"
  "relocate": return "转移节点，恢复后续递送，暴露−30；避开第5天末查封。已经收到的消息不撤回。"
  "protect_source": return "解除尚未到期的具名与前区联系人风险。已经暂停的协助不会复活，事实仍保留。"
  "bypass": return "依靠集市已有组织，各节点分散保存并拒绝集中查封，禁令无法集中执行；暴露+25。不要求审查官合作。"
  "disconnect": return "中断王室与法器的连接，不等于摧毁海洋。最终开放与解放选择仍在第6天。"
  "memory": return "祭司信任+25。承认战争，也让他看见封闭的代价；不自动交出法器。"+("羽之森签署资料帮助他辨认自己曾下达的命令。" if heritage.get("signature",false) else "")
  "review_plan": return "居民公开检验档案保存、预警与开放方案，形成不依赖单一掌控者的可执行安排。可替代缺失的前区共同验证成果。"
  "plan": return "祭司信任+20。约定分散保存、多人监督与逐步开放；开放交付法器选项。"
  "handover": return "祭司自愿交付保管权，王室独占解除。不会自动成为新的王；你仍可选择开放或解放。"
  "consent": return "先说明具名作证的追查后果。祭司自愿同意；此时尚未公开姓名。"
  "testimony": return "形成有效责任证言；祭司警戒+40，预告下一天末限制新的协助。已有证言和已交付法器保留。"
  "original": return "取得认证命令，补足学城责任链中的王室授权环节；不需要暴露个人证人身份。"
  "case": return "审查官信任+20，书面受理责任材料。受理不等于停捕，仍需落实命令。"+("学城正式回执使本次少1 AP。" if cost(id)==1 else "")
  "stay": return "落实停止搜捕与暂缓查封，禁令执行解除；保护现存传播点。已关闭的点仍需转移恢复。"
  "deal": return "核验释放名单与有限研究许可；解除未到期来源风险，但王室不承诺交出仍掌握的权力。承诺生效期间不能推进开放或接管，需另1 AP解除承诺。已释放的人不会因解除承诺重新被捕。"
  "renounce": return "公开解除交易承诺，重新开放传播与改变体系的行动；暴露+20。已核验的释放成果保留。"
  "takeover": return "准备接管法器和传播中枢。仅开放隐藏结局选项，此时尚未独占体系。"
  "final_sea": return "不可逆终局：释放已经形成的海洋共识，让海进入现实。外部世界及其风险重新开放。"
  "final_liberation": return "不可逆终局：将法器与档案交由共同监督，允许自由交流；本次暂不集中启动海洋显现，即使认知已足够。"
  "final_new_king": return "不可逆终局：违背共同监督的承诺，独占法器和传播体系。你取代国王，继承他的权力逻辑。"
  "final_forgetting": return "不可逆终局：停止此次改变。若控制仍稳固，大典压制海洋传播；已留下的副本、释放成果和局部改变会记入尾声。"
 return ""
func preview(id: String) -> Dictionary:
 var reasons:=blocked(id)
 return {"allowed":reasons.is_empty(),"text":"本次消耗%d AP。\n%s%s" % [cost(id),consequence(id),"" if reasons.is_empty() else "\n尚不能执行："+"；".join(reasons)]}
func execute(id: String) -> bool:
 if not blocked(id).is_empty(): return false
 var paid:=cost(id)
 ap-=paid
 spent+=paid
 flags[id]=true
 if DOCS.has(id): docs[id]={"source":"royal:"+id,"holder":"player"}
 match id:
  "network": controls.broadcast=false
  "publish":
   deliver("royal",45 if heritage.get("physical",false) else 35,id)
   exposure+=25
  "relay_village","relay_forest","relay_market","relay_academy":
   deliver(id.trim_prefix("relay_"),25,id)
   exposure+=10
  "relocate":
   network_closed=false
   controls.broadcast=false
   exposure=maxi(0,exposure-30)
  "protect_source": protect_contacts()
  "bypass":
   controls.enforcement=false
   exposure+=25
  "disconnect": controls.artifact=false
  "memory": people.priest.t+=25
  "plan": people.priest.t+=20
  "handover": controls.artifact=false
  "testimony":
   people.priest.a+=40
   source_due=day+1
  "case": people.inspector.t+=20
  "stay":
   controls.enforcement=false
   risk_due=0
  "deal": protect_contacts()
  "renounce": exposure+=20
  "final_sea","final_liberation","final_new_king","final_forgetting":
   ending=id.trim_prefix("final_")
   finished=true
   if ending=="new_king": controls={"broadcast":true,"enforcement":true,"artifact":true}
 exposure=clampi(exposure,0,100)
 if exposure>=60 and risk_due==0 and controls.enforcement and not network_closed and not has("relocate"): risk_due=day+1
 if exposure<60 or not controls.enforcement or has("relocate"): risk_due=0
 history.append({"day":day,"action":id,"title":ACTIONS[id].title,"ap":ap,"belief":belief,"receipt":"消耗%d AP；%s" % [paid,consequence(id)]})
 if finished: snapshot=make_snapshot()
 return true
func deliver(region: String,gain: int,id: String) -> void:
 if deliveries.has(id): return
 var actual:=mini(gain,100-int(regions[region]))
 regions[region]+=actual
 belief=regions.royal
 deliveries[id]={"region":region,"gain":actual,"day":day,"status":"arrived"}
func protect_contacts() -> void:
 source_due=0
 for p in prior_contacts.values():
  if p.status=="pending": p.status="protected"
func settle_contacts() -> void:
 for who in prior_contacts:
  var p: Dictionary=prior_contacts[who]
  if p.status=="pending" and int(p.due)<absolute_day():
   p.status="suspended"
   events.append("前区联系人%s的预警已到期，未来协助暂停；已有材料、观察和传播保留。" % who)
func end_preview() -> String:
 var text: String="剩余%d AP不结转。第6天须保留1 AP给海回归或接管；确认已达成的解放不再扣AP。" % ap
 if day==5: text+="\n今晚统一查封："+("已转移或已解除集中执行，节点保留。" if has("relocate") or not controls.enforcement else "未保护的传播点将关闭，认知不回扣；可花1 AP转移。")
 if risk_due>0: text+="\n暴露追查：第%d天末影响未来递送，可转移节点或停止执行。" % risk_due
 if source_due>0: text+="\n具名证人：第%d天末将无法提供新的协助；保护行动可解除未到期风险。" % source_due
 for who in prior_contacts:
  if prior_contacts[who].status=="pending": text+="\n联系人%s：全局第%d回合末到期，可安排保护。" % [who,prior_contacts[who].due]
 if day==6: text+="\n结束大典将按已有成果结算为「%s」，不会自动触发海回归或新的王。" % ("王国获得解放" if liberated() else "遗忘重临")
 return text
func end_day() -> bool:
 if finished or not presentation.is_empty(): return false
 events=[]
 if source_due>0 and source_due<=day:
  source_closed=true
  source_due=0
  events.append("具名证人受到追查，新的协助受限；已经交出的证言与法器保留。")
 for p in prior_contacts.values():
  if p.status=="pending" and p.due<=absolute_day(): p.status="suspended"
 if controls.enforcement and has("network") and not has("relocate") and (day==5 or risk_due>0 and risk_due<=day):
  network_closed=true
  controls.broadcast=true
  risk_due=0
  events.append("审查官封锁旧传播点。未来递送暂停，可以转移恢复；已有认知与材料保留。")
 if day==6:
  ending="liberation" if liberated() else "forgetting"
  finished=true
  snapshot=make_snapshot()
 else:
  day+=1
  ap=3
 return true
func progress_text() -> String:
 return foundation_text()+"\n\n各地认知总和：%d / %d\n达到20的地区：%d / 3\n王城认知：%d / 20\n%s" % [total_belief(),SEA_TOTAL,reached_regions(),belief,controls_text()]
func result_text() -> String:
 if not finished: return progress_text()
 return ENDINGS[ending]+"\n"+{
  "sea":"地平线越过高墙，潮声重新抵达王国。人们第一次可以共同寻找外部世界；旧战争的恐惧并不能替他们决定未来。",
  "liberation":"法器与旧史交由多人共同监督。海洋尚未显现，人们可以自由保存、讨论与继续验证它。你没有指定所有人必须相信的答案。",
  "new_king":"祭司等待你兑现共同监督的承诺，你却收起了钥匙。王室换了主人，审查与法器重新围绕你的命令运转。",
  "forgetting":"大典结束，海洋未能回归。王室或其残余机构重新争夺解释权；你留下的材料与局部改变仍在，却未建立足以延续的自由秩序。"
 }[ending]
func report() -> String:
 var text:=result_text()+"\n\n各地海洋认知："
 for region in REGIONS: text+="\n%s：%d" % [REGIONS[region],regions[region]]
 text+="\n\n"+controls_text()+"\n实际使用%d AP。" % spent
 if has("deal"): text+="\n释放名单已核验，有限研究许可已经执行。"
 if has("handover"): text+="\n祭司交付法器；最终是否独占由玩家明确决定。"
 if source_due>0: text+="\n祭司具名风险尚未处理，将在全局第%d回合末限制未来协助。" % (entry_turn+source_due-1)
 if source_closed: text+="\n祭司受到具名追查，已交出的证言仍保存。"
 if has("network"): text+="\n已有分散副本留存，结局不会抹除曾经发生的传播。"
 for who in prior_contacts: text+="\n前区联系人%s：%s" % [who,{"pending":"待处理风险","protected":"已安排保护","suspended":"暂停未来协助"}.get(prior_contacts[who].status,"")]
 return text
func make_snapshot() -> Dictionary:
 return {"ending":ending,"regions":regions.duplicate(true),"controls":controls.duplicate(true),"findings":flags.duplicate(true),"evidence":docs.duplicate(true),"deliveries":deliveries.duplicate(true),"prior_contacts":prior_contacts.duplicate(true),"people":people.duplicate(true),"source_risk":{"due":entry_turn+source_due-1 if source_due>0 else 0,"closed":source_closed},"network_closed":network_closed,"exposure":exposure,"origin":origin.duplicate(true),"next_turn":absolute_day()+1}
func to_data() -> Dictionary:
 var data: Dictionary={}
 for key in ["day","entry_turn","ap","spent","belief","selected","location","people","origin","flags","docs","regions","heritage","controls","deliveries","prior_contacts","history","events","presentation","snapshot","exposure","risk_due","network_closed","source_due","source_closed","ending","finished"]: data[key]=get(key)
 return data.duplicate(true)
func valid_data(data: Dictionary) -> bool:
 for key in to_data():
  if not data.has(key): return false
 for key in ["day","entry_turn","ap","spent","belief","exposure","risk_due","source_due"]:
  if not data[key] is int: return false
 if data.day<1 or data.day>6 or data.entry_turn<1 or data.ap<0 or data.ap>3 or data.spent<0 or data.spent>18 or data.belief<0 or data.belief>100 or data.exposure<0 or data.exposure>100: return false
 if data.risk_due<0 or data.risk_due>7 or data.source_due<0 or data.source_due>7: return false
 for key in ["people","origin","flags","docs","regions","heritage","controls","deliveries","prior_contacts","presentation","snapshot"]:
  if not data[key] is Dictionary: return false
 for key in ["history","events"]:
  if not data[key] is Array: return false
 for key in ["network_closed","source_closed","finished"]:
  if not data[key] is bool: return false
 if data.location!="royal_city" or data.selected not in ["","priest","inspector","king"]: return false
 if data.ending not in ["","sea","liberation","new_king","forgetting"] or data.finished!=(data.ending!=""): return false
 if data.finished and data.day!=6: return false
 for region in REGIONS:
  if not data.regions.get(region) is int or data.regions[region]<0 or data.regions[region]>100: return false
 if data.belief!=data.regions.royal: return false
 for key in ["broadcast","enforcement","artifact"]:
  if not data.controls.get(key) is bool: return false
 for who in NAMES:
  var p=data.people.get(who)
  if not p is Dictionary: return false
  if not p.get("t") is int or not p.get("a") is int or not p.get("closed") is bool: return false
 for who in data.prior_contacts:
  var p=data.prior_contacts[who]
  if not p is Dictionary or not p.get("due") is int or p.get("status","") not in ["pending","protected","suspended"]: return false
 for id in data.flags:
  if not ACTIONS.has(id) or data.flags[id]!=true: return false
 for id in data.docs:
  if not DOCS.has(id) or not data.docs[id] is Dictionary or data.docs[id].get("holder","")!="player": return false
 for id in data.deliveries:
  var d=data.deliveries[id]
  if id not in ["publish","relay_village","relay_forest","relay_market","relay_academy"] or not d is Dictionary: return false
  if not REGIONS.has(d.get("region","")) or not d.get("gain") is int or d.gain<0 or d.gain>45 or d.get("status","")!="arrived": return false
 for h in data.history:
  if not h is Dictionary or not h.get("title") is String or not h.get("receipt") is String: return false
  for key in ["day","ap","belief"]:
   if not h.get(key) is int: return false
 if not data.presentation.is_empty():
  if not data.presentation.get("lines") is Array or not data.presentation.get("index") is int: return false
  if data.presentation.index<0 or data.presentation.index>=data.presentation.lines.size(): return false
  for line in data.presentation.lines:
   if not line is Dictionary or not line.get("text") is String or not line.get("speaker") is String: return false
 return true
func restore(data: Dictionary) -> bool:
 if not valid_data(data): return false
 for key in to_data(): set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
 derive_foundations()
 return true
