## 전투 규칙 함수(06 §3). 노드·시간·엔진에 기대지 않는다. 상태를 바꾸고 화면 연출용 이벤트를 차례대로 돌려준다.
## 화면·자동 정책·시뮬레이션이 모두 이 함수들을 부른다(06 §4.2). 유닛은 배열 순서(칸 번호)로만 돈다.
##
## 명령(submit 의 commands[i], 대원 순서 5칸): 명령을 받는 대원(살아 있고 수면이 아님)만 사전, 나머지는 null.
##   {"kind": "attack", "target": 적 칸}
##   {"kind": "skill", "skill": 스킬 ID, "target": 칸}   대상 규칙이 전체·자기면 target 은 없어도 된다(무시)
##   {"kind": "guard"}
##   {"kind": "escape"}
## target 은 스킬 대상 쪽의 칸 번호다: enemy_* 는 적 칸, ally_* 는 대원 칸. 줄 대상은 그 줄의 아무 유효 대상.
##
## 이벤트는 {"type": …} 사전이다. 유닛은 {"side": "party"|"enemy", "slot": n}. 목록은 BattleRules.EVENT_TYPES.
class_name BattleRules
extends RefCounted

const PRIORITY_ORDER := {"first": 0, "normal": 1, "last": 2}
const OUTCOMES := ["victory", "escaped", "wiped"]
const COMMAND_KINDS := ["attack", "skill", "guard", "escape"]
## 명령 종류마다 받는 키. 다른 키가 있으면 unknown_command 로 거부한다(검사는 상태·난수를 건드리기 전에 끝난다).
const COMMAND_KEYS := {"attack": ["kind", "target"], "skill": ["kind", "skill", "target"], "guard": ["kind"], "escape": ["kind"]}
## 규칙이 내는 이벤트 종류(화면·시험 참고용).
const EVENT_TYPES := [
	"rejected", "battle_start", "guarding", "idle", "action", "failed", "covered", "missed", "damaged", "defeated", "woke",
	"ailment", "ailment_resisted", "ailment_blocked", "bound", "bind_resisted", "buffed", "healed", "cured", "revived",
	"front_guard", "cover_set", "charging", "charge_lost", "row_shift", "escaped", "escape_failed",
	"turn_end", "poison_tick", "expired", "drop", "battle_end",
]


# ---- 전투 시작 (06 §8.3) ----

## 층 출현 표에서 편성 하나를 가중치로 뽑는다(항목 하나면 뽑지 않는다). 표가 없으면 "".
static func pick_formation(state: ExplorationState) -> String:
	var e: BattleDb.EncounterDef = state.defs.battle.encounters.get(state.defs.floor_def.encounter_table)
	if e == null:
		return ""
	var weights: Array[int] = []
	for t in e.table:
		weights.append(t["weight"])
	return e.table[BattleCalc.pick_weighted(state.rng, weights)]["formation"]


## 전투를 연다: battle 을 만들고 pending 을 참으로 둔다. 실패하면 rejected 하나(상태 그대로).
static func start(state: ExplorationState, formation_id: String) -> Array[Dictionary]:
	if state.defs == null or state.battle != null or state.wiped:
		return [{"type": "rejected", "reason": "cannot_start"}]
	var b := BattleState.create(state.defs, state.party.members, formation_id)
	if b == null:
		return [{"type": "rejected", "reason": "unknown_formation"}]
	state.battle = b
	state.encounter.pending = true
	var ids: Array[String] = []
	for u in b.enemies:
		ids.append(u.def_id)
	return [{"type": "battle_start", "formation": formation_id, "enemies": ids}]


# ---- 읽기 도우미 (화면·정책·시험) ----

## 명령을 받는 대원인지(살아 있고 수면이 아님, 06 §3.3).
static func can_command(state: ExplorationState, member_index: int) -> bool:
	var u := state.battle.party[member_index]
	return u.alive() and not u.asleep()


## 대원이 쓸 스킬 정의. "attack" 이면 그 직업의 일반 공격. 모르면 null.
static func skill_of(state: ExplorationState, member_index: int, skill_id: String) -> BattleDb.SkillDef:
	var u := state.battle.party[member_index]
	if skill_id == "attack":
		return u.attack
	if not u.skills.has(skill_id):
		return null
	return state.defs.battle.skill(skill_id)


## 그 스킬을 지금 고를 수 없는 이유. 쓸 수 있으면 "". (unknown_skill·no_tp·bound_head|arm|leg·no_target)
static func skill_block_reason(state: ExplorationState, member_index: int, skill_id: String) -> String:
	var u := state.battle.party[member_index]
	var s := skill_of(state, member_index, skill_id)
	if s == null:
		return "unknown_skill"
	if u.tp < tp_cost(u, s):
		return "no_tp"
	var part := u.bound_part_of(s)
	if not part.is_empty():
		return "bound_" + part
	if candidates(state.battle, u, s).is_empty():
		return "no_target"
	return ""


## 도주를 고를 수 없는 이유(no_escape·bound_leg). 되면 "".
static func escape_block_reason(state: ExplorationState, member_index: int) -> String:
	if state.battle.no_escape:
		return "no_escape"
	if state.battle.party[member_index].bound("leg"):
		return "bound_leg"
	return ""


## 그 스킬로 지금 고를 수 있는 대상 칸 번호(칸 오름차순). 전체·자기 대상도 효과를 받을 칸을 돌려준다.
static func valid_targets(state: ExplorationState, member_index: int, skill_id: String) -> Array[int]:
	var out: Array[int] = []
	var s := skill_of(state, member_index, skill_id)
	if s == null:
		return out
	for t in candidates(state.battle, state.battle.party[member_index], s):
		out.append(t.slot)
	return out


## 대상 쪽("party"/"enemy")을 쓰는 유닛 기준으로.
static func target_side(u: BattleUnit, s: BattleDb.SkillDef) -> String:
	if s.targets_allies():
		return u.side
	return BattleUnit.ENEMY if u.side == BattleUnit.PARTY else BattleUnit.PARTY


static func tp_cost(u: BattleUnit, s: BattleDb.SkillDef) -> int:
	return s.level_row(u.skills.get(s.id, 1))["tp"]


## 근접이면 쓰는 쪽과 대상이 모두 실효 후열일 때 닿지 않는다(06 §3.5).
static func reachable(b: BattleState, u: BattleUnit, s: BattleDb.SkillDef, t: BattleUnit) -> bool:
	return s.range_kind != "melee" or b.effective_row(u) == "front" or b.effective_row(t) == "front"


## 지금 고를 수 있는 대상 유닛(칸 오름차순). 상대편은 살아 있고 닿는 유닛, 아군 대상은 대상 규칙대로.
static func candidates(b: BattleState, u: BattleUnit, s: BattleDb.SkillDef) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	match s.target:
		"self":
			if u.alive():
				out.append(u)
		"ally_dead":
			for t in b.allies_of(u):
				if not t.alive():
					out.append(t)
		"ally_one", "ally_all", "ally_row":
			for t in b.allies_of(u):
				if t.alive():
					out.append(t)
		"ally_other":
			for t in b.allies_of(u):
				if t.alive() and t != u:
					out.append(t)
		_:
			for t in b.opponents_of(u):
				if t.alive() and reachable(b, u, s, t):
					out.append(t)
	return out


# ---- 한 턴 (06 §3.2) ----

## 명령을 제출해 한 턴(다음 명령 입력 직전까지)을 처리한다. 검사에 실패하면 rejected 하나만 내고 상태·난수를 바꾸지 않는다.
## 전투가 끝나면 안에서 finish 를 부르고, 그 drop·battle_end 이벤트가 이 이벤트 열 끝에 붙는다(그 뒤 state.battle 은 null).
static func submit(state: ExplorationState, commands: Array) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var b := state.battle
	if b == null or state.wiped or not state.encounter.pending:
		events.append({"type": "rejected", "reason": "no_battle"})
		return events
	var bad := check_commands(state, commands)
	if not bad.is_empty():
		bad["type"] = "rejected"
		events.append(bad)
		return events
	var rules := state.defs.battle.rules
	for i in b.party.size():
		if commands[i] != null and commands[i]["kind"] == "guard":
			b.party[i].guarding = true
			events.append({"type": "guarding", "unit": b.party[i].ref()})
	var enemy_choices := EnemyAi.choose_all(state, events)
	b.queue.clear()
	for i in b.party.size():
		var c: Variant = commands[i]
		if c == null or c["kind"] == "guard":
			continue
		var u := b.party[i]
		var s: BattleDb.SkillDef = null
		if c["kind"] != "escape":
			s = skill_of(state, i, "attack" if c["kind"] == "attack" else c["skill"])
		var target: int = c["target"] if c.has("target") else -1
		b.queue.append(_action(u, c["kind"], s, u.skills.get(s.id, 1) if s != null else 1, target))
	for j in b.enemies.size():
		var ch: Variant = enemy_choices[j]
		if ch != null:
			b.queue.append(_action(b.enemies[j], "skill", ch["skill"], ch["level"], ch["target"]))
	for a in b.queue:
		var r := state.rng.randi_range(rules.speed_roll[0], rules.speed_roll[1])
		a["order"] = BattleCalc.order_value(a["unit"].stats["AGI"], a["speed"], r)
	b.queue.sort_custom(_before)
	for a in b.queue:
		_execute(state, a, events)
		if state.battle == null or _check_end(state, events):
			return events
	_turn_end(state, events)
	return events


static func _action(u: BattleUnit, kind: String, s: BattleDb.SkillDef, level: int, target: int) -> Dictionary:
	var prio := "normal"
	var speed := 1000
	if s != null:
		prio = s.priority
		speed = s.speed
	return {"unit": u, "kind": kind, "skill": s, "level": level, "target": target, "priority": PRIORITY_ORDER[prio], "speed": speed,
		"order": 0, "started": false, "cancelled": false, "cancel_reason": ""}


## 순서(06 §3.4): 우선 그룹 → S 내림차순 → 아군 먼저 → 칸 오름차순. 전순서다.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] < b["priority"]
	if a["order"] != b["order"]:
		return a["order"] > b["order"]
	var ap: bool = a["unit"].is_party()
	if ap != b["unit"].is_party():
		return ap
	return a["unit"].slot < b["unit"].slot


## 제출 검사(06 §3.3). 문제가 없으면 빈 사전, 있으면 {reason, slot}.
static func check_commands(state: ExplorationState, commands: Array) -> Dictionary:
	var b := state.battle
	if commands.size() != b.party.size():
		return {"reason": "length", "slot": -1}
	for i in b.party.size():
		var c: Variant = commands[i]
		var u := b.party[i]
		if not can_command(state, i):
			if c != null:
				return {"reason": "not_commandable", "slot": i}
			continue
		if c == null:
			return {"reason": "missing_command", "slot": i}
		if typeof(c) != TYPE_DICTIONARY or typeof(c.get("kind")) != TYPE_STRING or not COMMAND_KINDS.has(c["kind"]):
			return {"reason": "unknown_command", "slot": i}
		for k in c:
			if not COMMAND_KEYS[c["kind"]].has(k):
				return {"reason": "unknown_command", "slot": i}
		match c["kind"]:
			"guard":
				pass
			"escape":
				var why := escape_block_reason(state, i)
				if not why.is_empty():
					return {"reason": why, "slot": i}
			_:
				var sid: Variant = "attack" if c["kind"] == "attack" else c.get("skill")
				if typeof(sid) != TYPE_STRING or (c["kind"] == "skill" and sid == "attack"):
					return {"reason": "unknown_skill", "slot": i}
				var s := skill_of(state, i, sid)
				if s == null:
					return {"reason": "unknown_skill", "slot": i}
				if u.tp < tp_cost(u, s):
					return {"reason": "no_tp", "slot": i}
				var part := u.bound_part_of(s)
				if not part.is_empty():
					return {"reason": "bound_" + part, "slot": i}
				var cands := candidates(b, u, s)
				if cands.is_empty():
					return {"reason": "invalid_target", "slot": i}
				if not (s.target in ["self", "enemy_all", "ally_all"]):
					var t: Variant = c.get("target")
					if typeof(t) != TYPE_INT or cands.filter(func(x): return x.slot == t).is_empty():
						return {"reason": "invalid_target", "slot": i}
				elif c.has("target") and typeof(c["target"]) != TYPE_INT:
					return {"reason": "invalid_target", "slot": i}
	return {}


# ---- 행동 실행 (06 §3.7) ----

static func _execute(state: ExplorationState, a: Dictionary, events: Array[Dictionary]) -> void:
	var b := state.battle
	var rules := state.defs.battle.rules
	var u: BattleUnit = a["unit"]
	var s: BattleDb.SkillDef = a["skill"]
	a["started"] = true
	var charged := s != null and not u.charging.is_empty() and s.id == u.charging
	if a["cancelled"]:
		if a["cancel_reason"] == "asleep":
			events.append({"type": "failed", "unit": u.ref(), "reason": "asleep", "skill": s.id if s != null else "escape"})
		return
	if not u.alive():
		_release_charge(u, charged, "down", events)
		return
	var reason := ""
	if u.asleep():
		reason = "asleep"
	elif u.ailment == "paralysis" and BattleCalc.roll(state.rng, rules.paralysis_fail):
		reason = "paralysis"
	elif s != null and not u.bound_part_of(s).is_empty():
		reason = "bound_" + u.bound_part_of(s)
	elif s == null and u.bound("leg"):
		reason = "bound_leg"
	elif s != null and u.tp < tp_cost(u, s):
		reason = "no_tp"
	var targets: Array[BattleUnit] = []
	if reason.is_empty() and s != null:
		targets = _resolve_targets(b, u, s, a["target"])
		if targets.is_empty():
			reason = "no_target"
	if not reason.is_empty():
		events.append({"type": "failed", "unit": u.ref(), "reason": reason, "skill": s.id if s != null else "escape"})
		_release_charge(u, charged, reason, events)
		return
	if s == null:
		events.append({"type": "action", "unit": u.ref(), "kind": "escape", "skill": "escape", "tp": 0, "targets": [], "order": a["order"]})
		_escape(state, u, events)
		return
	var cost := tp_cost(u, s)
	if u.is_party():
		u.tp -= cost
	if charged:
		u.charging = ""
	var refs := []
	for t in targets:
		refs.append(t.ref())
	events.append({"type": "action", "unit": u.ref(), "kind": a["kind"], "skill": s.id, "tp": cost, "targets": refs, "order": a["order"]})
	var row: Dictionary = s.level_row(a["level"])
	match s.effect:
		"damage":
			for t in targets:
				_hit(state, u, s, row, _covered(b, u, s, t, events), events)
		"ailment":
			for t in targets:
				if _hits(state, u, s, row, t, events):
					BattleEffects.apply_ailment(b, rules, state.rng, u, t, row["ailment"], events)
		"heal":
			for t in targets:
				var amount := mini(int(row["base"]) + u.stats["WIS"] * int(row["wis_pct"]) / 100, t.max_hp - t.hp)
				t.hp += amount
				events.append({"type": "healed", "unit": u.ref(), "target": t.ref(), "amount": amount, "hp": t.hp})
		"cure":
			for t in targets:
				events.append({"type": "cured", "unit": u.ref(), "target": t.ref(), "removed": BattleEffects.cure(t)})
		"revive":
			for t in targets:
				t.hp = mini(t.max_hp, maxi(1, BattleCalc.mul(t.max_hp, row["hp_permille"])))
				events.append({"type": "revived", "unit": u.ref(), "target": t.ref(), "hp": t.hp})
				_check_rows(b, events)
		"buff", "debuff":
			for t in targets:
				BattleEffects.apply_effect(b, rules, t, s, a["level"], events)
		"front_guard":
			var v: int = row["value"]
			if b.front_guard.has(u.side):
				v = mini(v, b.front_guard[u.side])
			b.front_guard[u.side] = v
			events.append({"type": "front_guard", "unit": u.ref(), "value": v})
		"cover":
			b.cover[targets[0]] = u
			events.append({"type": "cover_set", "unit": u.ref(), "target": targets[0].ref()})
		"charge":
			u.charging = s.charges
			events.append({"type": "charging", "unit": u.ref(), "skill": s.charges})


static func _release_charge(u: BattleUnit, charged: bool, reason: String, events: Array[Dictionary]) -> void:
	if charged and not u.charging.is_empty():
		events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": reason})
		u.charging = ""


## 대상 다시 보기(06 §3.7 5단계). 빈 배열이면 no_target.
static func _resolve_targets(b: BattleState, u: BattleUnit, s: BattleDb.SkillDef, target: int) -> Array[BattleUnit]:
	var cands := candidates(b, u, s)
	var out: Array[BattleUnit] = []
	match s.target:
		"self", "ally_all", "enemy_all":
			return cands
		"ally_dead", "ally_other":
			var t := b.unit(u.side, target)
			if cands.has(t):
				out.append(t)
			return out
		"ally_one":
			var t := b.unit(u.side, target)
			if cands.has(t):
				out.append(t)
			elif s.effect == "heal" and not cands.is_empty():
				var best: BattleUnit = cands[0]
				for c in cands:
					if c.hp * best.max_hp < best.hp * c.max_hp:
						best = c
				out.append(best)
			return out
		"enemy_one":
			var t := b.unit(target_side(u, s), target)
			if cands.has(t):
				out.append(t)
				return out
			var row := b.effective_row(t) if t != null else "front"
			for c in cands:
				if b.effective_row(c) == row:
					out.append(c)
					return out
			if not cands.is_empty():
				out.append(cands[0])
			return out
	# 줄 대상: 고른 대상의 지금 실효 열 전체, 비었으면 다른 줄.
	var t := b.unit(target_side(u, s), target)
	var row := b.effective_row(t) if t != null else "front"
	for want in [row, "back" if row == "front" else "front"]:
		for c in cands:
			if b.effective_row(c) == want:
				out.append(c)
		if not out.is_empty():
			return out
	return out


## 커버(06 §6.2): 상대의 단일 대상 물리 공격이 보호받는 아군을 노리면, 살아 있고 수면이 아닌 커버 유닛이 대신 받는다.
static func _covered(b: BattleState, u: BattleUnit, s: BattleDb.SkillDef, t: BattleUnit, events: Array[Dictionary]) -> BattleUnit:
	if s.target != "enemy_one" or not s.physical() or not b.cover.has(t):
		return t
	var k: BattleUnit = b.cover[t]
	if not k.alive() or k.asleep() or k == t or k.side == u.side:
		return t
	events.append({"type": "covered", "unit": k.ref(), "target": t.ref()})
	return k


## 명중 판정(06 §3.8). 필중·수면 대상·아군 대상은 판정하지 않는다. 빗나가면 missed 이벤트.
static func _hits(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef, row: Dictionary, t: BattleUnit, events: Array[Dictionary], calc: Dictionary = {}) -> bool:
	if s.sure_hit or t.asleep() or t.side == u.side:
		return true
	var rules := state.defs.battle.rules
	var p := BattleCalc.hit_p(rules, row["accuracy"], u.stats["AGI"], t.evasion_agi(rules))
	calc["hit_p"] = p
	if p >= 1000:
		return true
	var r := state.rng.randi_range(0, 999) if p > 0 else 1000
	calc["hit_roll"] = r
	if r < p:
		return true
	events.append({"type": "missed", "unit": u.ref(), "target": t.ref(), "skill": s.id, "hit_p": p, "hit_roll": r})
	return false


## 피해식(06 §3.9)의 입력. _hit 와 자동 정책의 기대 피해(BattlePolicy.expected_damage)가 함께 쓴다.
## 속성 배율·대열·봉인(attack_stat)·장비·강화·약화·방어·전열 방어를 모두 여기서 모은다. crit·roll 은 부르는 쪽이 정한다.
static func damage_inputs(b: BattleState, rules: BattleDb.Rules, u: BattleUnit, s: BattleDb.SkillDef, row: Dictionary, t: BattleUnit, crit: bool, roll: int) -> Dictionary:
	var phys := s.physical()
	var fg := 0
	if phys and b.front_guard.has(t.side) and b.effective_row(t) == "front":
		fg = b.front_guard[t.side]
	return {
		"A": maxi(1, u.attack_stat(s.stat, rules) + int(u.gear["atk" if s.stat == "STR" else "matk"])),
		"D": t.stats["VIT" if s.stat == "STR" else "WIS"] + int(t.gear["def" if s.stat == "STR" else "mdef"]),
		"power": row["power"], "element": t.resist[s.element],
		"row": s.range_kind == "melee" and (b.effective_row(u) == "back" or b.effective_row(t) == "back"),
		"atk_muls": BattleCalc.effect_order(u.effects_of("phys_atk" if phys else "elem_atk")),
		"def_muls": BattleCalc.effect_order(t.effects_of("phys_def" if phys else "elem_def")),
		"guard": t.guarding, "front_guard": fg, "crit": crit, "roll": roll,
	}


## 피해 스킬 한 대상(06 §3.9 판정 순서): 명중 → 크리티컬 → 피해식 → HP → 처치 기록 → 수면 해제 → 부가 효과.
static func _hit(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef, row: Dictionary, t: BattleUnit, events: Array[Dictionary]) -> void:
	var b := state.battle
	var rules := state.defs.battle.rules
	var mult: int = t.resist[s.element]
	if mult == 0:
		events.append({"type": "damaged", "unit": u.ref(), "target": t.ref(), "skill": s.id, "element": s.element, "amount": 0, "lost": 0, "immune": true,
			"weak": false, "crit": false, "hp": t.hp, "calc": {}})
		return
	var hit_calc := {}
	if not _hits(state, u, s, row, t, events, hit_calc):
		return
	var crit := false
	if s.can_crit:
		crit = BattleCalc.roll(state.rng, BattleCalc.crit_p(rules, u.stats["LUC"], t.stats["LUC"]))
	var roll := state.rng.randi_range(rules.damage_roll[0], rules.damage_roll[1])
	var calc := BattleCalc.damage(rules, damage_inputs(b, rules, u, s, row, t, crit, roll))
	calc.merge(hit_calc)
	damage_unit(state, t, calc["final"], u, s.element, s.id, events, {"skill": s.id, "weak": mult > 1000, "crit": crit, "calc": calc})
	if t.alive():
		if row.has("ailment"):
			BattleEffects.apply_ailment(b, rules, state.rng, u, t, row["ailment"], events)
		if row.has("bind"):
			BattleEffects.apply_bind(rules, state.rng, u, t, row["bind"], events)


## HP를 줄이고 처치 기록·전투 불능·수면 해제를 처리한다. element 가 "" 이면 독(처치 기록의 element = null).
## extra 는 damaged 이벤트에 더할 값.
static func damage_unit(state: ExplorationState, t: BattleUnit, amount: int, by_unit: BattleUnit, element: String, by: String, events: Array[Dictionary], extra: Dictionary) -> void:
	var b := state.battle
	var lost := mini(t.hp, amount)
	t.hp -= lost
	var ev := {"type": "damaged" if by != "poison" else "poison_tick", "target": t.ref(), "amount": amount, "lost": lost, "hp": t.hp}
	if by_unit != null:
		ev["unit"] = by_unit.ref()
		ev["element"] = element
		ev["immune"] = false
	ev.merge(extra)
	events.append(ev)
	if t.hp == 0:
		if not t.is_party():
			t.kill = {"turn": b.turn, "element": element if not element.is_empty() else null,
				"ailment": t.ailment if not t.ailment.is_empty() else null, "binds": t.bind_list(), "by": by}
		events.append({"type": "defeated", "target": t.ref(), "kill": t.kill.duplicate(true) if not t.kill.is_empty() else null})
		BattleEffects.on_down(b, t, events)
		_check_rows(b, events)
	elif t.asleep() and lost >= 1:
		t.ailment = ""
		t.ailment_turns = 0
		events.append({"type": "woke", "target": t.ref()})


## 실효 열이 바뀌었으면 row_shift. 전멸한 편은 알리지 않는다(곧 끝 판정).
static func _check_rows(b: BattleState, events: Array[Dictionary]) -> void:
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		var now := b.front_empty(side)
		if now != b.promoted[side] and not b.all_down(side):
			b.promoted[side] = now
			events.append({"type": "row_shift", "side": side, "promoted": now})


## 도주(06 §3.17): 생존자 평균 AGI(정수 나눗셈) 차로 확률.
static func _escape(state: ExplorationState, u: BattleUnit, events: Array[Dictionary]) -> void:
	var b := state.battle
	var p := BattleCalc.escape_p(state.defs.battle.rules, _avg_agi(b.party), _avg_agi(b.enemies))
	if BattleCalc.roll(state.rng, p):
		events.append({"type": "escaped", "unit": u.ref(), "p": p})
		finish(state, "escaped", events)
	else:
		events.append({"type": "escape_failed", "unit": u.ref(), "p": p})


static func _avg_agi(units: Array[BattleUnit]) -> int:
	var total := 0
	var n := 0
	for u in units:
		if u.alive():
			total += u.stats["AGI"]
			n += 1
	return total / maxi(1, n)


## 끝 판정(06 §3.17): 아군 전멸을 먼저 본다. 끝났으면 finish 를 부르고 true.
static func _check_end(state: ExplorationState, events: Array[Dictionary]) -> bool:
	var b := state.battle
	if b.all_down(BattleUnit.PARTY):
		return finish(state, "wiped", events)
	if b.all_down(BattleUnit.ENEMY):
		return finish(state, "victory", events)
	return false


# ---- 턴 끝 (06 §3.15) ----

static func _turn_end(state: ExplorationState, events: Array[Dictionary]) -> void:
	var b := state.battle
	var rules := state.defs.battle.rules
	events.append({"type": "turn_end", "turn": b.turn})
	var units: Array[BattleUnit] = []
	units.append_array(b.party)
	units.append_array(b.enemies)
	for u in units:
		if u.alive() and u.ailment == "poison":
			damage_unit(state, u, u.ailment_damage, null, "", "poison", events, {})
	if _check_end(state, events):
		return
	BattleEffects.tick_durations(b, events)
	BattleEffects.decay_resist(b, rules)
	for u in units:
		u.guarding = false
	b.front_guard.clear()
	b.cover.clear()
	b.queue.clear()
	if b.turn >= BattleLimits.TURN_MAX:
		# 6단계 턴 상한(06 §3.15): 묶지 않고 도주로 끝낸다(드롭 없음).
		finish(state, "escaped", events, "turn_cap")
		return
	b.turn += 1


# ---- 전투 끝 (06 §3.17) ----

## 전투를 끝낸다. 거부하면 false 이고 상태·난수를 바꾸지 않는다.
## 이벤트(drop…·battle_end)는 events 에 덧붙인다: submit 은 자기 이벤트 열을 넘기고, 시험·디버그는 필요하면 배열을 넘긴다.
## battle_end 는 battle 을 지우기 전에 결과(턴·적 HP·드롭)를 복사해 담는다. reason 이 있으면 battle_end.reason(턴 상한 "turn_cap").
static func finish(state: ExplorationState, outcome: String, events: Array[Dictionary] = [], reason: String = "") -> bool:
	var b := state.battle
	if b == null or not state.encounter.pending or state.wiped or not OUTCOMES.has(outcome):
		return false
	if outcome == "wiped" and not b.all_down(BattleUnit.PARTY):
		return false
	var drops := []
	if outcome == "victory":
		for u in b.enemies:
			if u.kill.is_empty():
				continue
			for d in state.defs.battle.enemies[u.def_id].drops:
				if drop_condition_met(d["if"], u.kill) and BattleCalc.roll(state.rng, d["chance"]):
					var item: String = d["item"]
					var have: int = state.materials.get(item, 0)
					var now := mini(BattleLimits.MATERIAL_MAX, have + 1)
					state.materials[item] = now
					var drop := {"item": item, "amount": now - have, "capped": have + 1 > BattleLimits.MATERIAL_MAX, "enemy": u.slot}
					drops.append(drop)
					var ev := drop.duplicate()
					ev["type"] = "drop"
					events.append(ev)
	var enemy_hp: Array[int] = []
	for u in b.enemies:
		enemy_hp.append(u.hp)
	state.encounter.danger = 0
	state.encounter.pending = false
	if outcome == "wiped":
		state.wiped = true
	else:
		state.encounter.roll_threshold(state.rng, state.floor_def.threshold_min, state.floor_def.threshold_max)
	var end := {"type": "battle_end", "outcome": outcome, "turn": b.turn, "enemy_hp": enemy_hp, "drops": drops}
	if not reason.is_empty():
		end["reason"] = reason
	events.append(end)
	state.battle = null
	return true


## 드롭 조건(06 §3.17): 있는 조건이 모두 처치 기록과 맞는지.
static func drop_condition_met(cond: Dictionary, kill: Dictionary) -> bool:
	if cond.has("killed_by_element") and not cond["killed_by_element"].has(kill["element"]):
		return false
	if cond.has("killed_while_bound") and not kill["binds"].has(cond["killed_while_bound"]):
		return false
	if cond.has("killed_while_ailment") and kill["ailment"] != cond["killed_while_ailment"]:
		return false
	return true
