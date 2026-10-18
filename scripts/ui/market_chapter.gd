extends "res://scripts/ui/trial1.gd"
## Uses the same scene components and input gestures, with independent chapter rules.
const Market := preload("res://scripts/story/market_chapter_state.gd")
const MarketStory := preload("res://scripts/story/market_chapter_story.gd")
const MarketSave := preload("res://scripts/story/market_chapter_save.gd")
var village_snapshot: Dictionary = {}

func _ready() -> void:
	if save_path=="user://trial1_village_v1.json": save_path = "user://trial1_market_v1.json"
	state = Market.new()
	_build_theme()
	_build_ui()
	for child in %Design.get_children():
		if child is Label and child.text=="渔村六日 · 调查与抉择": child.text = "集市四日 · 消息与代价"
	end_button = _button(%Design,"结束当天","end_day",_ask_end)
	end_button.position = Vector2(1450,690)
	end_button.size = Vector2(420,60)
	%Design.move_child(end_button,map_modal.get_index())
	resized.connect(_fit)
	_fit()
	%TopBar.action_pressed.connect(_toolbar)
	%CharacterRail.character_selected.connect(_on_character_selected)
	%DialogueBox.dialogue_finished.connect(_on_dialogue_finished)
	%DialogueBox.line_presented.connect(_on_line_presented)
	%MiniMap.action_pressed.connect(_minimap)
	var loaded := MarketSave.load_from(save_path)
	if loaded.ok:
		state = loaded.state
		if loaded.get("backup",false): save_error = "已从上一份有效备份恢复集市进度。"
	elif not loaded.get("missing",false):
		save_blocked = true
		save_error = "集市存档损坏，原文件保留。可在设置中重新开始临时进度。"
		state.initialize(village_snapshot)
	else:
		state.initialize(village_snapshot)
		state.presentation = {"lines":MarketStory.opening(state),"index":0,"kind":"opening","portrait":""}
	_refresh()

func _show_portrait(person: String) -> void:
	if person.is_empty(): %PortraitPanel.clear_character()
	else: %PortraitPanel.present(person,null)

func _refresh_people() -> void:
	var ids := ["qian","xiang","dao"]
	var people: Array = []
	for who in ids:
		var p: Dictionary = state.people[who]
		people.append({"name":Market.NAMES[who],"portrait":null,"summary":"信任%d / 警戒%d\n%s" % [p.t,p.a,state.status(who)],"disabled":busy() or state.finished,"visible":true})
	if rail_names!=ids:
		rail_names = ids
		%CharacterRail.configure(people)
	else:
		var cards := %CharacterRail.get_node("Cards").get_children()
		for i in people.size(): cards[i].configure(people[i].name,null,people[i].summary,people[i].disabled,true,i)
	var market_cards := %CharacterRail.get_node("Cards").get_children()
	for i in market_cards.size():
		if market_cards[i].has_node("RolePlaceholder"): continue
		var role := Label.new()
		role.name = "RolePlaceholder"
		role.text = ["古物商","客栈老板","印刷者"][i]
		role.position = Vector2(16,35)
		role.size = Vector2(112,60)
		role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role.add_theme_font_size_override("font_size",21)
		role.add_theme_color_override("font_color",Color("d5bb83"))
		role.mouse_filter = Control.MOUSE_FILTER_IGNORE
		market_cards[i].add_child(role)
	%CharacterRail.visible = not state.finished

func _refresh() -> void:
	%LocationBackground.texture = Art.BACKGROUNDS.market
	%TopBar.apply_engine({"stats":[{"label":"公众海洋认知","value":state.belief}],"buttons":[{"id":"journal","text":"调查"},{"id":"evidence","text":"材料"},{"id":"map","text":"地图"},{"id":"settings","text":"设置"}],"day":state.day,"total":4,"ap":state.ap,"ap_max":3})
	%TopBar.get_node("DayBadge/Caption").text = "%d / 4" % state.day
	for button in %TopBar.button_row().get_children(): button.disabled = busy()
	_refresh_people()
	_clear(side)
	_text(side,"集市第%d天 · 全局第%d回合" % [state.day,state.entry_turn+state.day-1],25,GOLD)
	var guidance: Dictionary = MarketStory.stage(state)
	_text(side,guidance.title+"\n"+guidance.question,23,GOLD)
	_text(side,"目标：查明针对性限制，并完成实际传播。\n调查：%s · 已送达%d次" % ["已验证" if state.verified("censorship") else "未验证",state.deliveries.size()],23)
	_text(side,"第3天末：搜查\n第2—3天：公开投放\n第4天末：商队出发并离市",22,MUTED)
	if not state.selected.is_empty(): _text(side,Market.NAMES[state.selected]+"："+state.status(state.selected),23)
	if state.exposed: _text(side,"印刷点："+("搜查后暴露，离市合作暂停" if state.late_print_risk() else "已关闭" if state.print_closed else "已转移" if state.moved else "已暴露，搜查前可转移"),22,GOLD)
	if not state.public_waiting.is_empty(): _text(side,"公开质疑待回应：还需2 AP",22,GOLD)
	if not state.history.is_empty(): _text(side,"最近："+state.history.back().title+"\n"+state.history.back().receipt,20,MUTED)
	end_button.visible = not state.finished
	end_button.disabled = busy()
	completed_button.disabled = busy()
	end_button.text = "离市交接与结算" if state.day==4 else "结束当天 · 剩%d AP" % state.ap
	subtitle.text = "集市四日 · 阅读与切换免费"
	heading.text = "集市调查" if state.selected.is_empty() else Market.NAMES[state.selected]
	_clear(actions)
	choice_scroll.visible = not busy()
	continue_hint.text = ""
	if busy():
		_show_portrait(state.presentation.get("portrait",""))
		%DialogueBox.show_from(state.presentation.lines,state.presentation.index)
	elif state.finished:
		_show_portrait("")
		%DialogueBox.show_text("集市调查成功。消息已经到达读者手中。" if state.success() else "你离开了集市。未完成的调查与传播会分别记入结果。")
		_button(actions,"前往 / 继续旧学城","academy",_enter_academy)
		_button(actions,"查看离市结果","report",_show_report)
		_button(actions,"重新开始集市…","restart",_restart_ask)
	else:
		_show_portrait(Market.NAMES.get(state.selected,""))
		%DialogueBox.show_text(guidance.next)
		_build_actions()
	choice_scroll.scroll_vertical = 0
	_save_caption()

func _build_actions() -> void:
	var group: String = "research" if state.selected.is_empty() else state.selected
	for id in Market.ACTIONS:
		if Market.ACTIONS[id].group!=group: continue
		if id in ["move","repair_dao"] and not state.exposed: continue
		if id.begins_with("supplement_") and state.credited(id.trim_prefix("supplement_"))==0: continue
		_market_action(id)

func _research() -> void:
	state.selected = ""
	_save()
	_refresh()

func _market_action(id: String, topic := "censorship") -> void:
	if state.flags.has(state.key_for(id,topic)): return
	var reasons: Array = state.blocked(id,topic)
	var label: String = Market.ACTIONS[id].title+(" · 本次2 AP" if id=="rush" else " · %d AP" % state.cost(id))
	if Market.ACTIONS[id].get("topic",false): label += "\n"+Market.TOPICS[topic]
	if not reasons.is_empty(): label += "\n"+str(reasons[0])
	_button(actions,label,id+":"+topic,_market_preview.bind(id,topic),not reasons.is_empty())

func _market_preview(id: String, topic: String, reviewed := false) -> void:
	if id in ["goods_verify","text_verify"] and not reviewed and state.preview(id,topic).allowed:
		_market_compare(id,topic)
		return
	_popup(Market.ACTIONS[id].title)
	var preview: Dictionary = state.preview(id,topic)
	_text(overlay_body,"为什么做这件事\n"+MarketStory.purpose(id),24,GOLD)
	_text(overlay_body,preview.text,24)
	if preview.allowed: _button(overlay_actions,"确认执行","execute",_market_execute.bind(id,topic))

func _market_compare(id: String, topic: String, retry := false) -> void:
	_popup("核对依据 · 阅读与作答免费")
	var goods := id=="goods_verify"
	_text(overlay_body,"原货单：相同货号原为远航部件。扣押登记：远航部件被扣，普通河运用品放行。" if goods else "旧文本：记有远方水域与离境航行。查禁清单：单列这些内容；送审文本恰好删去对应段落，其他内容保留。",24)
	_text(overlay_body,"这些材料支持哪一个判断？确认后才消耗1 AP完成核验。",24,GOLD)
	if retry: _text(overlay_body,"材料只支持有针对性的限制，不能推出所有旧货或所有文字都被禁止。可以重新核对，不扣AP。",24)
	_button(overlay_actions,"远航用途受到针对性限制" if goods else "与远方水域有关的内容被针对性删改","compare_correct",_market_preview.bind(id,topic,true))
	_button(overlay_actions,"所有旧货都不准流通" if goods else "所有文字都不准传播","compare_retry",_market_compare.bind(id,topic,true))

func _market_execute(id: String, topic: String) -> void:
	if not state.execute(id,topic):
		_market_preview(id,topic)
		return
	overlay.hide()
	_play(MarketStory.action(state,id,topic),"action",Market.NAMES.get(state.selected,""))

func _on_character_selected(index: int, _person: String, _summary: String, _texture: Texture2D) -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	state.selected = ["qian","xiang","dao"][index]
	_play(MarketStory.greeting(state,state.selected),"greeting",Market.NAMES[state.selected])

func _on_line_presented(index: int, speaker: String) -> void:
	if not busy(): return
	state.presentation.index = index
	if speaker in Market.NAMES.values(): _show_portrait(speaker)
	state.presentation.portrait = %PortraitPanel.character
	continue_hint.text = "点击文字框 / 回车继续　%d / %d ›" % [index+1,state.presentation.lines.size()]
	_save()
	_save_caption()

func _on_dialogue_finished() -> void:
	if not busy(): return
	state.presentation = {}
	_save()
	_refresh()

func _ask_end() -> void:
	if busy() or state.finished or overlay.visible or map_modal.visible: return
	_popup("离市交接" if state.day==4 else "结束当天？")
	_text(overlay_body,state.end_preview(),24)
	_button(overlay_actions,"确认离市" if state.day==4 else "确认结束当天","confirm_day",_end_day)

func _end_day() -> void:
	if not state.end_day(): return
	overlay.hide()
	if state.finished:
		var farewell: Array = state.events.duplicate()
		farewell.append("你走出集市。已查明信息限制，并让消息真正到达读者：集市调查成功。" if state.success() else "你走出集市。调查或实际传播尚未完成，离市结果会保留这些遗留问题。")
		farewell.append("实际传播%d次；集市公众海洋认知%d。读者的回应与渠道是否保留，会分别记入离市成果。" % [state.deliveries.size(),state.belief])
		for shipment in state.pending:
			farewell.append("商队已经出发，但材料尚未送达；预计全局第%d回合到达下一地区。" % shipment.arrival_turn if shipment.status=="dispatched" else "商队未能发出这份材料，副本已经归还给你。")
		if state.verified("censorship"): farewell.append("货物和文字的限制已经得到印证。接下来的疑问是：这些规定从何而来，旧档案又记着怎样的过去？旧学城或许保存着线索。")
		farewell.append(state.handoff_text())
		farewell.append("可以查看完整离市结果。可前往旧学城，交接成果与已发商队将按状态承接。")
		_play(Story.lines(farewell),"departure")
	else: _play(MarketStory.day_start(state),"day")

func _show_report() -> void:
	_popup("离市结果")
	_text(overlay_body,state.report(),24)

func _toolbar(id: String) -> void:
	if busy() or overlay.visible or map_modal.visible: return
	match id:
		"journal":
			_popup("集市调查 · 故事与当前进展")
			_text(overlay_body,MarketStory.overview(state),24)
			_text(overlay_body,"验证路径一：旧文本＋查禁清单→对照。\n验证路径二：古物货单＋扣押记录→核对。\n查明任一条针对性限制，再完成一次实际传播即可成功。\n自行抄写与印刷不算传播；商队抵达在离市后。\n集市公众海洋认知由实际传播增加：单线走访/定向/公开为5/10/20，双线为10/15/25，核验渔村证据后为15/25/35。调查本身不自动传播；补充说明花1 AP，仅补原读者的差额。",24)
			_text(overlay_body,"当前传播依据："+state.evidence_text(),24,GOLD)
			_text(overlay_body,"已留下的成果\n"+state.achievements_text(),23,GOLD)
			_text(overlay_body,"后续交接\n"+state.handoff_text(),23)
			_text(overlay_body,state.end_preview(),23)
			if not state.finished: _button(overlay_actions,"进入公共调查","research",_open_research)
		"evidence":
			_popup("材料与递送")
			for evidence_id in ["text","ban","cargo","seizure","text_verify","goods_verify","sea_verify"]:
				_text(overlay_body,Market.ACTIONS[evidence_id].title+"："+("已完成" if state.flags.has(evidence_id) else "尚未取得或验证"),23)
			for topic in state.packets: _text(overlay_body,Market.TOPICS[topic]+"：未用副本%d份" % state.packets[topic].count,23)
			for shipment in state.pending: _text(overlay_body,"商队："+Market.TOPICS[shipment.topic]+" · "+{"waiting":"待发，尚未送达","dispatched":"已出发，尚未送达","returned":"已退回"}[shipment.status],23)
			_text(overlay_body,"渔村原物只按离村持有人继承，不会自动取回寄存物。已印出的副本不算新证据来源。",23,MUTED)
			for key in state.origin.get("evidence",{}):
				_text(overlay_body,State.TITLES.get(key,key)+"："+("随身携带" if state.origin.evidence[key].holder=="player" else "留在渔村"),23)
		"map":
			var places: Array = []
			for place in Art.BACKGROUNDS: places.append({"id":place,"reachable":true})
			map_modal.configure({"show_ocean":false,"places":places})
			map_modal.open()
		"settings":
			_popup("集市设置")
			_text(overlay_body,"四天，每天3 AP。集市内部移动免费。\n钱伯会在高危时自保，阿香会关闭递送，刀郎的印刷点会被追查。已送达的消息不撤销。\n本章独立保存，继续渔村时可从离村界面重新进入。",24)
			_button(overlay_actions,"保存进度","save",_manual_save)
			_button(overlay_actions,"读取最近进度","load",_load_ask)
			_button(overlay_actions,"重新开始集市…","restart",_restart_ask)

func _open_research() -> void:
	overlay.hide()
	_research()

func _map_place(id: String) -> void:
	map_modal.hide()
	_popup(Art.PLACE_NAMES[id])
	var picture := TextureRect.new()
	picture.texture = Art.BACKGROUNDS[id]
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 350
	overlay_body.add_child(picture)
	if id=="old_academy" and state.finished: _button(overlay_actions,"前往 / 继续旧学城","enter_academy",_enter_academy_from_map)
	elif id=="market" and not state.finished: _button(overlay_actions,"回到集市公共调查 · 免费","enter_market",_open_research)
	else: _text(overlay_body,"地点预览。结束集市后可进入旧学城；当前不能回村补做行动，完成旧学城后可前往羽之森，羽之森结束后可进入王城。",24)

func _save() -> void:
	if save_blocked: return
	var error := MarketSave.save_to(save_path,state)
	save_error = "保存失败，当前行动已执行，可在设置中重试："+error_string(error) if error!=OK else ""

func _save_caption() -> void:
	save_label.text = save_error if not save_error.is_empty() else "集市进度自动保存到当前对白 · 第3天末搜查 · 第4天末离市"

func _load_ask() -> void:
	_popup("读取集市进度？")
	_button(overlay_actions,"确认读取","confirm_load",_load)

func _load() -> void:
	var loaded := MarketSave.load_from(save_path)
	if not loaded.ok:
		_popup("未能读取，原文件与当前进度保留")
		return
	state = loaded.state
	save_blocked = false
	overlay.hide()
	_refresh()

func _restart_ask() -> void:
	_popup("重新开始集市四天？")
	_text(overlay_body,"以同一份渔村离村结果重新开始集市；渔村存档不变。")
	_button(overlay_actions,"确认重新开始","confirm_restart",_restart)

func _restart() -> void:
	var seed: Dictionary = state.origin.duplicate(true)
	# Fresh replay restores one-use offers from the original entry snapshot.
	seed["support_consumed"] = village_snapshot.get("support_consumed",[]).duplicate()
	if save_blocked: save_path += ".recovered"
	save_blocked = false
	state = Market.new()
	state.initialize(seed)
	overlay.hide()
	_play(MarketStory.opening(state),"opening")

func _enter_academy() -> void:
	if not state.finished or busy() or overlay.visible or map_modal.visible: return
	var seed: Dictionary = state.snapshot.duplicate(true)
	var identity := JSON.stringify(seed).sha256_text().substr(0,16)
	var next = load("res://scenes/academy_chapter.tscn").instantiate()
	next.save_path=save_path+".academy-"+identity+".json"
	next.market_snapshot=seed
	get_parent().add_child(next)
	if get_tree().current_scene==self: get_tree().current_scene=next
	queue_free()

func _enter_academy_from_map() -> void:
	overlay.hide()
	_enter_academy()
