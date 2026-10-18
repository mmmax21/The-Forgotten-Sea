extends RefCounted
## 渔村表现层：只读规则状态，不发放物品、不改变成本或结局。
const OPENING := "告示说海洋只是传说，你却想找到能核对的痕迹。\n盐嫂守着空粮袋，哑伯摩挲旧木板，螺螺望向遗迹。五天后，你将沿商路去集市。"
const ACTION_TEXT := {
	"press_relic": "盐嫂把布包推到你面前：拿走。别再当着孩子的面问这些。\n贝壳和潮汐手记落在桌上。她交出遗物，是想让你离开，并不是信任你。",
	"feed": "盐嫂接过粮袋，先分出孩子的一份。\n盐嫂：进来坐吧。你想问的那些旧事……等我把这锅饭煮上。",
	"listen": "盐嫂：他回来时，衣服湿透了，说见过望不到岸的水。后来再没人肯听他讲。\n她看向里屋：东西还在。可我若开口，家里这些人怎么办？",
	"protect": "运粮车沿土路离村，孩子从车尾向盐嫂挥手。\n盐嫂：亲戚会接他们住下。现在，我总算能把话说完了。",
	"relic": "盐嫂打开布包，里面是一枚磨损的贝壳和丈夫留下的潮汐手记。日期旁画着水线的涨落。\n盐嫂：别只说他做了一场梦。把这些带给能核对的人。",
	"repair": "你扶稳旧木板，让哑伯重新钉牢松开的接缝。他把工具向你这边推了推，示意你坐近些。\n那些磨平的刻痕，似乎仍有他认得的来历。",
	"identify": "哑伯把碎片翻过来，指给你看弧形接缝和嵌着填料的钉孔，又在纸上画出船身。\n他写下：船体构件。碎片的用途终于有了可以复核的解释。",
	"hide_old": "哑伯把散在桌上的旧物裹好，推入工具箱深处。门外有脚步经过，他没有再停下手里的活。\n他仍记得你们查过什么，只是不再把它摆在明处。",
	"rumor": "螺螺：遗迹正门堵死了，可我听过石墙后面的风声。那里一定还有个口子。\n她摸摸空口袋：上次跑得急，把我的小布包落在附近了。",
	"retrieve": "你把小布包交还给螺螺。她蹲下，在地上画出断墙和窄道的位置。\n螺螺：从这边进去。我就在村里等，你自己小心。",
	"clarify": "你和螺螺把能说的见闻、不能公开的调查分开记清。\n螺螺：我明白了。不把别人的名字挂在嘴边，也不装作什么都没见过。",
	"withdraw": "你收回托付的材料，告诉盐嫂不必再替你保管或传话。\n盐嫂：我记得你来过。只是往后的事，让我留在这里吧。",
	"survey": "你绕过遗迹外墙，顺着碎石间的风找到一条窄道。入口被旧梁和杂物掩住。\n只要清开这里，就能进去；不必再另找一条路。",
	"clear": "最后一根横木被拖开，石室里的冷风涌了出来。墙脚露出一道发白的旧水线。\n入口已经打通，里面还没有搜查。",
	"search": "碎石下压着一块弯曲的木片，边缘有成列钉孔，缝里嵌着深色填料。\n你把它包好：这是什么部件，仍需请懂旧工艺的人辨认。",
}

static func greeting(s, npc: String) -> String:
	var p: Dictionary = s.people[npc]
	if p.reported:
		return {"salt": "盐嫂把门掩上，没有再接你的话。她已经向巡查者说出了调查的事。", "mute": "哑伯把工具收进箱子，避开你的目光。调查已经被报给巡查者，他不再接受协助请求。", "luo": "螺螺站得很远。巡查者已经从她那里听到了调查的事。"}[npc]
	if p.warning_day > 0 and npc == "salt" and s.completed.has("press_relic"):
		return "盐嫂：你知道东西从哪来，也知道我们住在哪里。我怎么相信你不会把我们一起交出去？\n第%d天结束前，需要修复信任或降低她的担忧。" % p.warning_day
	if p.warning_day > 0:
		return "%s看了看门外。你的调查让对方不安，若不补救，第%d天结束时可能告密。" % [s.NAMES[npc], p.warning_day]
	if npc == "salt" and s.salt_assistance_revoked:
		return "盐嫂：东西都还给你了。我们说好的，我不再替你保管或传话。"
	if p.alert >= 60 and p.trust >= 60:
		return {"salt": "盐嫂：我信你，可现在不能再接新的托付。先让我把这份担心放下。", "mute": "哑伯在纸上写下：相信你。暂时别再拿新的东西来。他把纸折进掌心。", "luo": "螺螺：我知道你没有骗我，可巡查的人还在。让我缓一缓。"}[npc]
	match npc:
		"salt":
			if not s.spread.is_empty() and s.spread.status == "pending":
				return "盐嫂：你托我传的话，我收好了。等你离村时，若情势还允许，我会交给走商路的人。"
			if not s.storage.salt.is_empty():
				return "盐嫂：托我的东西还在夹层里。你要带走，先来取，别把一件东西算成两份。"
			if s.completed.has("relic") or s.completed.has("press_relic"):
				return "盐嫂：遗物已经交过了，去向记在你的材料册里。他见过的东西，不能只靠我一个人说。"
			if s.completed.has("protect"):
				return "盐嫂：家人已经安顿好，我放心些了。那包遗物还在，你想看的话，我们现在就谈。"
			if s.completed.has("listen"):
				return "盐嫂：旧事我说给你听了。遗物可以再看，家人的安置却得赶在第3天结束前。" if s.day <= 3 else "盐嫂：运粮车已经走了，家人的安置赶不上了。你想核对的遗物还在。"
			if s.completed.has("feed"):
				return "盐嫂：粮食收到了，谢谢你。坐吧，你不是只为送这袋粮来的。"
			return "盐嫂把空粮袋折起，压在碗底。她还不愿与陌生人谈起丈夫，只先问能否帮家里渡过眼下。"
		"mute":
			if not s.storage.mute.is_empty():
				return "哑伯拍了拍工具箱，示意托付的原物还收在暗格里。若要带走，记得先来取。"
			if s.completed.has("identify"):
				return "哑伯指着船身草图，又点点钉孔的位置。辨认已经完成；下一步可以记下特征，或安排保管。"
			if s.completed.has("repair"):
				return "哑伯让出工作台的一角。旧物已经修好了；若你带来不认识的构件，他愿意仔细看看。"
			return "哑伯正扶着一块松动的旧木板，腾不出手。他的工具磨得发亮，像是修过许多如今叫不出名字的东西。"
		"luo":
			if s.completed.has("retrieve"):
				return "螺螺：入口已经画给你了。我留在村里，你回来再说。" if not p.informed else "螺螺压低声音：你给我看的东西，我记得。我留在村里，不替你保管或传递它。"
			if s.completed.has("rumor"):
				return "螺螺：既然你已经找到入口，就不必再问路了。可我的布包还落在那里。" if s.entrance_known else "螺螺：布包找回来，我就把那条窄道画给你。也许你自己绕一圈，也能找到。"
			return "螺螺望着遗迹：正门堵了，不代表里面没有路。她说到这里，忽然摸了摸空口袋。"
	return ""

static func ruins(s) -> String:
	if s.day > 4:
		return "封条已经贴上遗迹入口。调查窗口结束了，已有碎片仍能带回村里辨认。返回渔村消耗1 AP。"
	if s.completed.has("search"):
		return "石室已经搜查过，碎片的去向记在材料册里。这里没有第二份可重复领取的物证。返回渔村消耗1 AP。"
	if s.completed.has("clear"):
		return "入口的杂物已经清开。石室里的水线与碎石还没有细查，可以继续搜查。"
	return "窄道的位置已经找到，还需清开杂物才能进去。遗迹将在第4天结束时封闭。" if s.entrance_known else "断墙间有风穿过，但你还不知道准确入口。先勘察外围；第4天结束时这里将封闭。"

static func action(s, id: String) -> String:
	if s.completed.has("press_relic") and id == "feed":
		return "你为先前的逼问道歉，把粮袋放在门边。\n盐嫂：粮食我收下，可你还没告诉我，我们会不会被牵连。"
	if s.completed.has("press_relic") and id == "listen":
		return "这一次，你没有打断她。盐嫂讲完孩子和家人的处境，你承认不该拿他们逼她开口。\n她仍然害怕，但终于愿意重新判断你的来意。"
	if id == "retrieve" and s.completed.has("survey"):
		return "螺螺抱紧找回的布包，认真向你道谢。她画出的窄道，正是你已经勘察到的入口。\n这次帮助加深了关系，没有增加新的入口。"
	return ACTION_TEXT.get(id, "行动已完成。")

static func material(kind: String, npc: String, s) -> String:
	match kind:
		"record_self": return "你把图样、刻痕和取得经过记进笔记。原物没有变多，但现在有了一份可供核对的记录。"
		"record_scribe": return "抄写摊主按你的描述描出图样，标明原物的来源。你收好记录；复制并不等于已经传播。"
		"show": return "你只向%s展示了这份材料，说明它的来历，然后收回。对方已经知情；村里其他人并不会因此自动知道。" % s.NAMES[npc]
		"store": return "%s收下原物，放进约定的暗格。材料已经交出，若要随身带走，需要先取回。" % s.NAMES[npc]
		"spread": return "盐嫂收下材料：等你离村时，若还能办，我会把消息送上商路。\n这是一次待执行的托付，暂时还不算传播完成。"
		"retrieve": return "你取回材料，取消了与它有关的托付。东西回到手中，对方却不会忘记已经知道的内容。"
	return "交接已完成。"

static func morning(s) -> String:
	match s.day:
		2: return "第2天清晨，村口传来巡查将至的消息。明天他们就会进村。\n运粮车还没走；安置家人需要同一天留出2 AP和1份粮食。" if not s.completed.has("protect") else "第2天清晨，巡查将至的消息传遍村口。明天他们就会进村。家人已安置，可以继续调查。"
		3: return "第3天清晨，巡查者沿村路挨户走过。有人停下交谈，有人合上门。\n今日是安置家人的最后机会；具体警戒变化见今日结算。" if not s.completed.has("protect") else "第3天清晨，巡查者沿村路挨户走过。运粮车上的家人已经离开。\n具体警戒变化见今日结算，遗迹还有今天和明天可以调查。"
		4: return "第4天清晨，封闭遗迹的告示贴上断墙。今晚之后，入口就不再开放。\n已经找到的碎片可以带回辨认，不必在遗迹内完成。"
		5: return "第5天清晨，遗迹已经封闭。离村前，你还有今天的时间整理记录、交接材料或补救关系。\n原物留给谁，什么带上路，都要在今晚定下来。"
	return OPENING

static func farewell(s) -> String:
	var lines := PackedStringArray()
	if s.people.salt.reported:
		lines.append("盐嫂的门关着。调查被报了出去，你没有再敲门。")
	elif s.completed.has("protect"):
		lines.append("盐嫂：家人已经安顿好。你替我们走了这一步，往后的路，小心些。")
	elif s.completed.has("press_relic") and not s.completed.has("feed"):
		lines.append("盐嫂没有送你。那次逼问留下的隔阂，没有随着你离村而消失。")
	elif s.completed.has("feed"):
		lines.append("盐嫂：那袋粮，我记得。家里还要过日子，我就送到这里。")
	else:
		lines.append("盐嫂仍在门边忙着。你们之间，还有许多话没能说出口。")
	if not s.spread.is_empty():
		lines.append("她已把约定的消息托上商路。" if s.spread.status == "completed" else "传播的托付没能兑现，材料去向已记入交接记录。")
	if s.people.mute.reported:
		lines.append("哑伯背过身收好工具，没有再与你交换纸条。")
	elif not s.storage.mute.is_empty():
		lines.append("哑伯拍了拍工具箱，示意托付的原物留在暗格中。")
	elif s.completed.has("identify"):
		lines.append("哑伯在船身草图旁补了一道线，示意你到了集市再找别的实物核对。")
	elif s.completed.has("repair"):
		lines.append("哑伯抬了抬修好的木板，向你点头道别。")
	else:
		lines.append("哑伯仍坐在工作台前。你还没有来得及了解他的旧手艺。")
	lines.append("你沿商路前往集市。那里有往来旅客和旧货，也许能找到渔村之外的独立线索。")
	return "\n\n".join(lines)
