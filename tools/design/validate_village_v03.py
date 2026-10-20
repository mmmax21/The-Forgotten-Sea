"""Independent rule checks, not the Godot runtime or exhaustive balance testing."""
from copy import deepcopy
from pathlib import Path

class Village:
    def __init__(self):
        self.day, self.ap, self.food, self.spent, self.b = 1, 3, 2, 0, 0
        self.npc = {"salt": [40, 50, False], "elder": [50, 40, False], "child": [35, 20, False]}
        self.flags, self.items, self.exposed, self.reported = set(), set(), set(), set()
        self.warn, self.penalty_pending, self.penalty_used = {}, False, False
        self.public, self.neighbor, self.departed = None, None, False
        self.neighbor_valid = False
        self.log = []
        self.support_offers = set()
        self.support_consumed = set()

    def change(self, who, t=0, a=0, known=False):
        n = self.npc[who]
        n[0], n[1], n[2] = max(0, min(100, n[0]+t)), max(0, min(100, n[1]+a)), n[2] or known

    def hazard(self, who):
        t, a, known = self.npc[who]
        return known and t < 60 and a >= 60

    def sync(self):
        for who in self.npc:
            if who in self.reported:
                self.warn.pop(who, None)
            elif not self.hazard(who):
                self.warn.pop(who, None)
            elif who not in self.warn:
                self.warn[who] = self.day + 1

    def available_sources(self):
        return {s for s in ('H', 'F') if s in self.items or s+'_r' in self.items}

    def cooperative(self, who):
        t, a, known = self.npc[who]
        return known and t >= 60 and a < 60 and who not in self.exposed and who not in self.reported

    def act(self, action, arg=None):
        before = deepcopy(self.__dict__)
        try:
            self._act(action, arg)
        except AssertionError:
            self.__dict__ = before
            raise

    def _act(self, action, arg):
        assert not self.departed
        key = action + (':'+str(arg) if arg is not None else '')
        assert key not in self.flags
        cost, food = 1, 0
        if action == 'feed':
            food = 1
        elif action == 'listen':
            assert 'feed' in self.flags
        elif action == 'family':
            assert 'listen' in self.flags and self.day <= 3
            cost, food = 2, 1
        elif action == 'heirloom':
            assert 'listen' in self.flags and self.npc['salt'][0] >= 60 and self.npc['salt'][1] < 60
        elif action == 'repair':
            pass
        elif action == 'hear':
            pass
        elif action == 'retrieve':
            assert 'hear' in self.flags
        elif action == 'survey':
            assert 'entrance' not in self.flags and self.day <= 4
        elif action == 'clear':
            assert 'entrance' in self.flags and self.day <= 4
        elif action == 'search':
            assert 'clear' in self.flags and self.day <= 4
        elif action == 'identify':
            assert 'fragment' in self.items and self.npc['elder'][0] >= 60 and self.npc['elder'][1] < 60
        elif action in ('tidy', 'caution'):
            assert self.npc['elder' if action == 'tidy' else 'child'][2]
        elif action == 'waterline':
            assert 'F' in self.available_sources() and 2 <= self.day <= 4
            cost = 2
        elif action in ('record', 'scribe'):
            assert arg in self.items and arg in ('H', 'F') and 'recorded_'+arg not in self.flags
            cost, food = (2, 0) if action == 'record' else (1, 1)
        elif action == 'show':
            assert self.available_sources() and arg in self.npc
        elif action == 'public':
            assert 4 <= self.day <= 5 and self.public is None and self.available_sources()
            if arg == 'material':
                cost = 2
            elif arg in ('anonymous', 'named_salt'):
                assert 'H' in self.available_sources() and 'listen' in self.flags
            else:
                assert arg == 'named_elder' and 'F' in self.available_sources()
        elif action == 'neighbor':
            assert self.cooperative('salt') and self.neighbor is None and arg in self.items and arg in ('H', 'F', 'H_r', 'F_r')
        elif action == 'apology':
            assert arg in self.exposed
        else:
            raise AssertionError('Unknown action: '+action)
        assert self.ap >= cost and self.food >= food
        self.ap -= cost
        self.food -= food
        self.spent += cost
        self.flags.add(key)
        if action == 'feed': self.change('salt', t=15)
        elif action == 'listen': self.change('salt', t=10, a=5)
        elif action == 'family': self.change('salt', a=-20)
        elif action == 'heirloom':
            self.items.add('H'); self.change('salt', a=10, known=True)
        elif action == 'repair': self.change('elder', t=15)
        elif action == 'hear': self.change('child', t=10)
        elif action == 'retrieve':
            self.change('child', t=15); self.flags.add('entrance')
        elif action == 'survey': self.flags.add('entrance')
        elif action == 'search': self.items.add('fragment')
        elif action == 'identify':
            self.items.remove('fragment'); self.items.add('F'); self.change('elder', a=10, known=True)
        elif action == 'tidy': self.change('elder', a=-10)
        elif action == 'caution': self.change('child', a=-10)
        elif action in ('record', 'scribe'):
            self.items.add(arg+'_r'); self.flags.add('recorded_'+arg)
        elif action == 'show': self.change(arg, t=10, a=15, known=True)
        elif action == 'public':
            if arg == 'material':
                self.b += 40 if len(self.available_sources()) == 2 else 20
                if 'F' in self.available_sources() and 'waterline' in self.flags: self.b += 20
            elif arg == 'anonymous':
                self.b += 40; self.change('salt', a=10, known=True)
            else:
                self.b += 60
                who = 'salt' if arg == 'named_salt' else 'elder'
                self.change(who, t=-20, a=20, known=True)
                self.exposed.add(who)
                if who == 'salt': self.return_neighbor()
            self.public = (arg, self.day)
        elif action == 'neighbor':
            self.neighbor = arg; self.items.remove(arg); self.change('salt', a=0 if 'family' in self.flags else 10)
        elif action == 'apology': self.change(arg, t=5, a=-10)
        self.b = min(100, self.b)
        self.sync()
        self.log.append((self.day, key, cost))

    def preview(self, action, arg=None):
        simulated = deepcopy(self)
        simulated.act(action, arg)
        new_warnings = set(simulated.warn) - set(self.warn)
        return {
            'cost': self.ap-simulated.ap,
            'belief_gain': simulated.b-self.b,
            'remaining_ap': simulated.ap,
            'new_warnings': sorted(new_warnings),
            'no_remote_remedy': self.day == 6 and bool(new_warnings),
            'lost_support': sorted(simulated.exposed-self.exposed),
        }

    def use_support(self, offer, event_type, base_cost, requires_original=False):
        # Future-region contract model; does not credit village AP or belief.
        assert self.departed and offer in self.support_offers and offer not in self.support_consumed
        assert base_cost >= 1
        if offer == 'salt_intro':
            assert event_type == 'introduction'
        else:
            assert event_type == 'origin_check' and 'F' in self.available_sources()
            if requires_original: assert 'F' in self.items
        self.support_consumed.add(offer)
        return base_cost-1

    def return_neighbor(self):
        if self.neighbor is not None:
            self.items.add(self.neighbor); self.neighbor = None

    def end(self):
        assert not self.departed
        self.sync()
        for who, due in list(self.warn.items()):
            if due <= self.day:
                self.reported.add(who)
                self.warn.pop(who)
                if not self.penalty_used:
                    self.penalty_used = True
                    self.penalty_pending = True
        if self.day == 6:
            self.neighbor_valid = self.neighbor is not None and self.cooperative('salt')
            if self.neighbor_valid: self.b = min(100, self.b+10)
            else: self.return_neighbor()
            if self.neighbor_valid: self.support_offers.add("salt_intro")
            if "identify" in self.flags and self.cooperative("elder"):
                self.support_offers.add("elder_origin")
            self.departed = True
            return
        self.day += 1
        self.ap = 2 if self.penalty_pending else 3
        self.penalty_pending = False
        if self.day == 3:
            for who, n in self.npc.items():
                if n[2]: self.change(who, a=10)
        self.sync()

    def resolve_next_region(self):
        assert self.departed
        self.day = 7
        self.sync()
        for who, due in list(self.warn.items()):
            if due <= 7:
                self.reported.add(who); self.warn.pop(who)
                if not self.penalty_used:
                    self.penalty_used = self.penalty_pending = True


def route(days):
    v = Village()
    for actions in days:
        for a in actions:
            v.act(*a) if isinstance(a, tuple) else v.act(a)
        v.end()
    return v

rows = []
def result(name, v, expected_b, expected_spent, note):
    assert v.departed and v.b == expected_b and v.spent == expected_spent
    rows.append((name, v.spent, v.b, str(v.npc['salt'][:2]), str(v.npc['elder'][:2]), note))

# Complete, protected anonymous route: two originals retained, record left with salt.
base = [['feed','listen','repair'], ['family','survey'], ['clear','search','identify']]
safe = route(base + [['heirloom','waterline'], [('public','material')], [('record','H'),('neighbor','H_r')]])
assert safe.neighbor_valid and safe.items == {'H','F'} and not safe.exposed and not safe.reported
result('匿名完整成果', safe, 70, 17, '家人安全；两份原物随身，盐嫂留记录；剩1 AP')

child_path = route([['feed','listen','hear'],['family','retrieve'],['clear','search','repair'],['identify','waterline'],['heirloom',('public','material')],[('record','H'),('neighbor','H_r')]])
assert child_path.neighbor_valid and child_path.npc['child'][0] == 60 and not child_path.reported
result('经螺螺的匿名完整成果', child_path, 70, 18, '三人关系均达60；主要成果兼得，但无剩余AP')

named = route(base + [['heirloom',('record','H')], [('public','named_salt')], []])
assert named.reported == {'salt'} and named.penalty_pending and not named.neighbor_valid
result('实名公开不补救', named, 60, 13, '盐嫂第6天告密，下一区域首回合少1 AP')

fixed = route(base + [['heirloom',('record','H')], [('public','named_salt')], [('apology','salt')]])
assert not fixed.reported and not fixed.warn and 'salt' in fixed.exposed and not fixed.cooperative('salt')
result('实名后缓解风险', fixed, 60, 14, '解除预警，但曝光与失去本区协助不可逆')

anonymous = route(base + [['heirloom',('record','H')], [('public','anonymous')], [('neighbor','H_r')]])
assert anonymous.neighbor_valid and 'H_r' not in anonymous.items and anonymous.npc['salt'][1] == 55
result('匿名经历与持续传播', anonymous, 50, 14, '家人已安置；盐嫂A55，邻里传播有效')

modest = route([['feed','listen'], ['family'], [], ['heirloom',('record','H')], [('public','anonymous'),('neighbor','H_r')], []])
assert modest.neighbor_valid and modest.items == {'H'}
result('盐嫂单线中间目标', modest, 50, 9, '保护家人，带走H，匿名传播，剩9 AP')
minimal = route([['survey','clear','search'],['repair','identify'],[],[],[],[]])
assert 'F' in minimal.items and not minimal.reported
result('单一证据保底', minimal, 0, 5, '带走F完成基本调查；无需公开、无需拿满关系')
early = route([['feed','listen','heirloom'], ['family'], [], [('public','anonymous')], [], []])
assert early.npc['salt'][1] == 65 and not early.reported and not early.neighbor_valid
result('早期知情仍有巡查压力', early, 40, 6, '盐嫂A65，暂停协助但不告密，家人安全不抹除旧风险')

elder = route([['survey','clear','search'],['repair','identify','tidy'],[],[('public','named_elder')],[],[]])
assert elder.reported == {'elder'}
result('实名点名哑伯', elder, 60, 7, '第5天告密；第6天可用2 AP；其他路线保留')

empty = route([[],[],[],[],[],[]])
result('无证据仍可离村', empty, 0, 0, '调查未完成，继续后续区域')

late = route([['survey','clear','search'],['repair','identify','tidy'],[],[],[],[('show','salt')]])
assert late.warn == {'salt':7} and not late.reported
result('最后一天新预警', late, 0, 7, '带走F，预警留待下一地区首回合处理')
no_help = deepcopy(late)
no_help.resolve_next_region()
assert no_help.reported == {'salt'} and no_help.penalty_pending

checks = []
def rejects(v, action, arg=None):
    before = deepcopy(v.__dict__)
    try:
        v.act(action,arg)
    except AssertionError:
        assert v.__dict__ == before
    else:
        raise AssertionError('Expected rejection: '+action)

# All failures must be transactional, with no spent AP or mutated flags.
v=Village(); rejects(v,'family'); rejects(v,'heirloom'); rejects(v,'public','material')
checks.append('前提不足与公开窗口外不扣费、不改变状态')
v=Village(); v.act('feed'); v.act('listen'); rejects(v,'family')
checks.append('剩1 AP不能执行2 AP安置，粮食不被吞掉')
v=Village(); v.act('survey'); rejects(v,'survey'); v.act('clear'); v.act('search'); rejects(v,'search')
checks.append('入口/遗迹奖励不可重复领取')
v=Village(); [v.end() for _ in range(4)]; rejects(v,'survey'); rejects(v,'family')
checks.append('第5天不能补做家人安置或遗迹调查')
v=route(base+[ ['heirloom','waterline'] ])
v.act('public','material'); rejects(v,'public','named_salt'); v.end(); rejects(v,'waterline')
checks.append('公开版本互斥；第6天不能补水线观察')
v=Village(); v.act('survey'); v.act('clear'); v.act('search'); v.end(); v.act('repair'); v.act('identify'); v.act('show','salt'); assert v.warn=={'salt':3}
v.end(); assert v.warn=={'salt':3}; v.act('feed'); assert not v.warn
checks.append('持续高危不刷新期限；提高T至60以上解除告密但不保证协助')
v=route(base+[ ['heirloom',('record','H')] ])
v.act('show','child'); rejects(v,'show','child')
checks.append('同一NPC不能通过换来源重复领取展示收益')
v=route(base+[ ['heirloom',('record','H')] ])
v.act('neighbor','H_r'); v.act('public','named_salt'); assert v.neighbor is None and 'H_r' in v.items
checks.append('实名曝光立即终止隐蔽协助，归还材料')
checks.append('第6天新预警不提前结算；无远程撤回，第7回合末仍高危则告密并排定处罚')
assert early.npc['salt'][0] >= 60 and early.npc['salt'][1] >= 60 and not early.reported
checks.append('高T高A只暂停协助，无自动告密')
v=Village(); rejects(v,'withdraw'); rejects(v,'cancel_neighbor')
assert not hasattr(v, 'messenger')
checks.append('主动撤回、取消传播和信使撤回已移除；无此类降警戒入口')

# Check newly introduced relief, previews and one-time future benefits.
assert safe.npc['salt'][1] == 45 and anonymous.npc['salt'][1] == 55
checks.append('家人安置后邻里传播不新增警戒；匿名经历后A55可继续传播')
v=route(base+[ ['heirloom','waterline'] ])
before=deepcopy(v.__dict__); quote=v.preview('public','material')
assert quote['belief_gain']==60 and quote['cost']==2 and v.__dict__==before
v.act('public','material'); assert v.b==quote['belief_gain']
checks.append('公开预览按独立来源与水线计算，无额外问答奖励，预览不扣费')
v=route([['survey','clear','search'],['repair','identify','tidy'],[],[],[]])
v.act('hear'); v.act('retrieve')
quote=v.preview('show','salt')
assert quote['remaining_ap']==0 and quote['no_remote_remedy'] and quote['new_warnings']==['salt']
v.act('show','salt'); assert v.warn=={'salt':7} and not v.reported
v.end(); assert not v.reported
v.resolve_next_region(); assert v.reported=={'salt'}
checks.append('最后1 AP触发风险时预览明确零补救行动；第7回合末才结算')
assert safe.support_offers=={'salt_intro','elder_origin'}
assert fixed.support_offers=={'elder_origin'} and not elder.support_offers
assert modest.support_offers=={'salt_intro'}
checks.append('有效渠道产生介绍，安全辨认者产生来源说明；实名只失去对应帮助')
u=deepcopy(safe)
assert u.use_support('salt_intro','introduction',1)==0
try: u.use_support('salt_intro','introduction',1)
except AssertionError: pass
else: raise AssertionError('Support used twice')
u.items.remove('F'); u.items.add('F_r')
try: u.use_support('elder_origin','origin_check',1,True)
except AssertionError: pass
else: raise AssertionError('Record substituted for original')
assert 'elder_origin' not in u.support_consumed
assert u.use_support('elder_origin','origin_check',1)==0
assert u.b==safe.b and u.ap==safe.ap
checks.append('跨区收益只抵对应事件1 AP且仅一次，不增加B或渔村AP、不绕过原物要求')

out = ['# 渔村六回合规则验证报告', '', '验证日期：2026-10-15。由独立规则脚本生成；不是Godot运行测试，也不是玩家体验或穷举平衡验证。', '', '## 代表路线', '', '|路线|实际AP|离场B|盐嫂T/A|哑伯T/A|结果|', '|---|---:|---:|---|---|---|']
out += ['|'+'|'.join(map(str,r))+'|' for r in rows]
out += ['', '## 边界检查', ''] + ['- 通过：'+c for c in checks]
out += ['', '## 判断与限制', '', '- 六回合18 AP能容纳自行勘察的匿名完整成果路线（17 AP）及经过螺螺的路线（18 AP），不只一种入口和行动顺序可行。剩余0—1 AP，容错偏小，值得重点试玩。', '- 同样持有两种来源和记录时，实名路线比匿名完整路线少4 AP；补救后仍少3 AP，但永久曝光、失去具名者本区协助。', '- 告密不是随机惩罚；盐嫂与哑伯的实名路线均能触发，给出完整后续回合处理。', '- 家人安置后，匿名经历与邻里传播可以兼得；早期知情的巡查风险仍保留。盐嫂单线9 AP完成中间目标，单份证据5 AP完成基本调查。', '- 未完成调查不阻塞离村；第6天新风险能传给任意下一区域。', '- 本脚本覆盖核心调查、公开说明、邻里材料归还和跨区预警；尚未模拟所有保管组合、保管取回/重新托管、多区域存档读写、UI提示与实际玩家理解。', '- 新增公开收益预览、末日零AP预警和一次性跨区协助契约检查；尚未实现实际对白、笔记UI或后续地区事件。', '- 当前验证不宣称所有路线成本等价，也不宣称18 AP是最终最优预算。', '']
labels = {'feed':'送粮','listen':'倾听','repair':'修整旧物','family':'安置家人','survey':'自行勘察','clear':'清障','search':'搜查','identify':'辨认','heirloom':'取得遗物','waterline':'核对水线','public:material':'匿名物证说明','record:H':'制作遗物记录','neighbor:H_r':'留下记录安排邻里传播','public:named_salt':'实名公开丈夫证词','apology:salt':'承认越界并停止引用','hear':'听螺螺见闻','retrieve':'取回遗落物品'}
out += ['## 可复核的逐日走法', '']
for title, state in [('自行勘察的匿名完整路线', safe), ('经过螺螺的匿名完整路线', child_path), ('实名公开后补救', fixed), ('盐嫂单线中间目标', modest)]:
    out += ['### '+title, '', '|天数|行动顺序|当日消耗|', '|---|---|---:|']
    for day in range(1,7):
        actions = [x for x in state.log if x[0]==day]
        out += [f"|第{day}天|"+' → '.join(labels.get(x[1],x[1]) for x in actions)+f"|{sum(x[2] for x in actions)} AP|"]
    out += ['']

path = Path(__file__).resolve().parents[2] / 'docs/design/渔村六回合验证报告_v0.3.md'
path.write_text('\n'.join(out), encoding='utf-8')
print(f'PASS: {len(rows)} routes; {len(checks)} boundary groups. Report: {path}')
