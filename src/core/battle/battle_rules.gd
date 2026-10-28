## 전투 규칙 함수(06 §3). 노드·시간·엔진에 기대지 않는다. 상태를 바꾸고 화면 연출용 이벤트를 차례대로 돌려준다.
## 화면·자동 정책·시뮬레이션이 모두 이 함수들을 부른다(06 §4.2). 유닛은 배열 순서(칸 번호)로만 돈다.
##
## 명령(submit 의 commands[i], 대원 순서): 명령을 받는 대원(살아 있고 수면·혼란이 아님)만 사전, 나머지는 null.
## 혼란한 대원(M3 A7)은 명령 없이 그 턴에 kind "confused" 행동(일반 공격, 대상은 실행 때 양쪽에서 고름)을 한다.
## 실행 때 다시 본다: 큐를 만든 뒤 혼란에 걸린 유닛의 행동은 그 자리에서 혼란 공격으로 바뀌고, 혼란이 풀린 유닛의 혼란 행동은 failed recovered 로 없어진다.
## 방어는 큐 전에 이미 걸려 행동이 없으므로 그 턴에 혼란에 걸려도 방어는 그대로이고 혼란 공격도 없다.
##   {"kind": "attack", "target": 적 칸}
##   {"kind": "skill", "skill": 스킬 ID, "target": 칸}   대상 규칙이 전체·자기면 target 은 없어도 된다(무시)
##   {"kind": "guard"}
##   {"kind": "escape"}
##   {"kind": "item", "item": 소모품 ID, "target": 대원 칸}   (M3 A4) 모든 소모품은 단일 대상. 소모품은 실행 시점에 하나 줄어든다(01 §4.1).
## target 은 스킬 대상 쪽의 칸 번호다: enemy_* 는 적 칸, ally_* 는 대원 칸. 줄 대상은 그 줄의 아무 유효 대상.
##
## 이벤트는 {"type": …} 사전이다. 유닛은 {"side": "party"|"enemy", "slot": n}. 목록은 BattleRules.EVENT_TYPES.
class_name BattleRules
extends RefCounted

const PRIORITY_ORDER := {"first": 0, "normal": 1, "last": 2}
## 혼란한 유닛의 행동 종류(M3 A7). action 이벤트의 kind 도 이 값이다.
const CONFUSED := "confused"
const OUTCOMES := ["victory", "escaped", "wiped"]
const COMMAND_KINDS := ["attack", "skill", "guard", "escape", "item"]
## 명령 종류마다 받는 키. 다른 키가 있으면 unknown_command 로 거부한다(검사는 상태·난수를 건드리기 전에 끝난다).
const COMMAND_KEYS := {"attack": ["kind", "target"], "skill": ["kind", "skill", "target"], "guard": ["kind"], "escape": ["kind"],
	"item": ["kind", "item", "target"]}
## 규칙이 내는 이벤트 종류(화면·시험 참고용).
const EVENT_TYPES := [
	"rejected", "battle_start", "guarding", "idle", "action", "failed", "covered", "missed", "damaged", "defeated", "woke",
	"ailment", "ailment_resisted", "ailment_blocked", "bound", "bind_resisted", "buffed", "healed", "cured", "revived",
	"front_guard", "cover_set", "charging", "charge_lost", "row_shift", "escaped", "escape_failed",
	"turn_end", "poison_tick", "expired", "drop", "exp", "level_up", "battle_end", "item_used", "tp_healed",
	"foe_defeated", "foe_join", "foe_joined",
]


# ---- 전투 시작 (06 §8.3) ----

## 지금 층의 출현 표에서 편성 하나를 가중치로 뽑는다(항목 하나면 뽑지 않는다). 표가 없으면 "".
static func pick_formation(state: ExplorationState) -> String:
	var e: BattleDb.EncounterDef = state.defs.battle.encounters.get(state.floor_def.encounter_table)
	if e == null:
		return ""
	var weights: Array[int] = []
	for t in e.table:
		weights.append(t["weight"])
	return e.table[BattleCalc.pick_weighted(state.rng, weights)]["formation"]


## 전투를 연다: battle 을 만들고 pending 을 참으로 둔다. 실패하면 rejected 하나(상태 그대로).
## foe(M3 A6)가 있으면 그 FOE 와의 접촉 전투다: battle.foe 에 적고 그 FOE 를 battle 상태로 둔다.
static func start(state: ExplorationState, formation_id: String, foe: String = "") -> Array[Dictionary]:
	if state.defs == null or state.battle != null or state.wiped:
		return [{"type": "rejected", "reason": "cannot_start"}]
	var b := BattleState.create(state.defs, state.party.members, formation_id)
	if b == null:
		return [{"type": "rejected", "reason": "unknown_formation"}]
	state.battle = b
	state.encounter.pending = true
	if not foe.is_empty():
		b.foe = foe
		state.world.foes[foe].state = "battle"
	var ids: Array[String] = []
	for u in b.enemies:
		ids.append(u.def_id)
	return [{"type": "battle_start", "formation": formation_id, "enemies": ids}]


# ---- 읽기 도우미 (화면·정책·시험) ----

## 명령을 받는 대원인지(살아 있고 수면·혼란이 아님, 06 §3.3·M3 A7 설계 §4.5).
static func can_command(state: ExplorationState, member_index: int) -> bool:
	var u := state.battle.party[member_index]
	return u.alive() and not u.asleep() and not u.confused()


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


## 소모품(M3 A4): 이 턴 commands 가운데 before 칸보다 앞 칸들이 고른 그 소모품 수(예약). before 가 -1 이면 모든 칸.
static func items_reserved(commands: Array, item: String, before: int = -1) -> int:
	var n := 0
	for i in commands.size():
		if before >= 0 and i >= before:
			break
		var c: Variant = commands[i]
		if typeof(c) == TYPE_DICTIONARY and c.get("kind") == "item" and c.get("item") == item:
			n += 1
	return n


## 소모품(M3 A4)을 대원 member_index 가 지금 고를 수 없는 이유. 되면 "". (unknown_item·item_not_here·no_item·no_target)
## commands 는 이 턴에 이미 정한 명령(다른 대원의 예약을 뺀다, 그 대원 자기 칸은 세지 않는다).
static func item_block_reason(state: ExplorationState, member_index: int, item: String, commands: Array = []) -> String:
	var cd := state.defs.battle.consumable(item)
	if cd == null:
		return "unknown_item"
	if not cd.in_battle():
		return "item_not_here"
	var others := 0
	for i in commands.size():
		if i != member_index and typeof(commands[i]) == TYPE_DICTIONARY and commands[i].get("kind") == "item" and commands[i].get("item") == item:
			others += 1
	if int(state.consumables.get(item, 0)) - others < 1:
		return "no_item"
	if candidates(state.battle, state.battle.party[member_index], cd.skill).is_empty():
		return "no_target"
	return ""


## 그 소모품으로 지금 고를 수 있는 대상 칸 번호(칸 오름차순, M3 A4). 모르거나 전투에서 쓰지 않으면 빈 배열.
static func item_targets(state: ExplorationState, member_index: int, item: String) -> Array[int]:
	var out: Array[int] = []
	var sk := state.defs.battle.item_skill(item)
	if sk == null:
		return out
	for t in candidates(state.battle, state.battle.party[member_index], sk):
		out.append(t.slot)
	return out


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
		if c["kind"] == "item":
			s = state.defs.battle.item_skill(c["item"])
		elif c["kind"] != "escape":
			s = skill_of(state, i, "attack" if c["kind"] == "attack" else c["skill"])
		var target: int = c["target"] if c.has("target") else -1
		var level: int = u.skills.get(s.id, 1) if s != null and c["kind"] != "item" else 1
		var a := _action(u, c["kind"], s, level, target)
		if c["kind"] == "item":
			a["item"] = c["item"]  # 대리 스킬 id 와 같다(실행 때 소모품을 하나 뺀다)
		b.queue.append(a)
	# 혼란(M3 A7 설계 §4.5): 명령한 대원 뒤에, 살아 있는 혼란 대원마다 일반 공격 하나(레벨 1, 대상은 실행 때 고른다).
	for u in b.party:
		if u.alive() and u.confused():
			b.queue.append(_action(u, CONFUSED, u.attack, 1, -1))
	for j in b.enemies.size():
		var ch: Variant = enemy_choices[j]
		if ch != null:
			b.queue.append(_action(b.enemies[j], str(ch.get("kind", "skill")), ch["skill"], ch["level"], ch["target"]))
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
	var reserved := {}  # 소모품 ID → 앞 칸부터 센 수(M3 A4: 마지막 하나를 둘이 고를 수 없다)
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
			"item":
				var iid: Variant = c.get("item")
				var cd: BattleDb.ConsumableDef = state.defs.battle.consumable(iid) if typeof(iid) == TYPE_STRING else null
				if cd == null:
					return {"reason": "unknown_item", "slot": i}
				if not cd.in_battle():
					return {"reason": "item_not_here", "slot": i}
				reserved[iid] = int(reserved.get(iid, 0)) + 1
				if reserved[iid] > int(state.consumables.get(iid, 0)):
					return {"reason": "no_item", "slot": i}
				var cands := candidates(b, u, cd.skill)
				var t: Variant = c.get("target")
				if typeof(t) != TYPE_INT or cands.filter(func(x): return x.slot == t).is_empty():
					return {"reason": "invalid_target", "slot": i}
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
	if a["kind"] != CONFUSED and u.confused():
		# 혼란(M3 A7 seq=5): 큐를 만든 뒤 혼란에 걸린 유닛은 그 자리(순서 그대로, 속도 다시 굴리지 않음)에서 혼란 공격을 한다.
		# 원래 행동(스킬·아이템·도주)의 비용은 내지 않고 맡긴 아이템도 쓰지 않는다. 적의 준비는 혼란한 적의 길(EnemyAi.choose)처럼 풀린다.
		if not u.charging.is_empty():
			events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": "no_target"})
			u.charging = ""
		charged = false
		s = u.attack if u.is_party() else BattleDb.confused_attack()
		a["kind"] = CONFUSED
		a["skill"] = s
		a["level"] = 1
		a["target"] = -1
		a.erase("item")
	var reason := ""
	if u.asleep():
		reason = "asleep"
	elif u.ailment == "paralysis" and BattleCalc.roll(state.rng, rules.paralysis_fail):
		reason = "paralysis"
	elif a["kind"] == CONFUSED and not u.confused():
		# 혼란이 풀린(해제·덮어쓰기) 유닛의 혼란 행동은 없어진다: 공격·대상 뽑기 없음. 잠듦·마비는 위 관문이 먼저 정한다.
		reason = "recovered"
	elif s != null and not u.bound_part_of(s).is_empty():
		reason = "bound_" + u.bound_part_of(s)
	elif s == null and u.bound("leg"):
		reason = "bound_leg"
	elif s != null and u.tp < tp_cost(u, s):
		reason = "no_tp"
	var targets: Array[BattleUnit] = []
	if reason.is_empty() and a["kind"] == CONFUSED:
		var t := confused_target(state, u, s)
		if t == null:
			reason = "no_target"
		else:
			targets.append(t)
	elif reason.is_empty() and s != null:
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
	if a["kind"] == "item":
		# 소모품은 모든 관문을 지난 실행 시점에만 하나 줄어든다(01 §4.1: 취소·쓰러짐·마비·대상 없음·먼저 끝난 전투는 쓰지 않는다).
		var iid: String = a["item"]
		var left: int = int(state.consumables.get(iid, 0)) - 1
		if left > 0:
			state.consumables[iid] = left
		else:
			state.consumables.erase(iid)
		events.append({"type": "item_used", "unit": u.ref(), "item": iid, "left": maxi(left, 0)})
	var row: Dictionary = s.level_row(a["level"])
	if a["kind"] == CONFUSED:
		# 혼란: 고른 하나에 보통 피해 판정(아군이면 명중 판정 없음, 커버는 쓰지 않는다).
		_hit(state, u, s, row, targets[0], events)
		return
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
		"cure_ailment", "cure_bind":
			for t in targets:
				var removed := BattleEffects.cure_ailment(t) if s.effect == "cure_ailment" else BattleEffects.cure_bind(t)
				events.append({"type": "cured", "unit": u.ref(), "target": t.ref(), "removed": removed})
		"tp_heal":
			for t in targets:
				var amount := mini(int(row["amount"]), t.max_tp - t.tp)
				t.tp += amount
				events.append({"type": "tp_healed", "unit": u.ref(), "target": t.ref(), "amount": amount, "tp": t.tp})
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


## 혼란한 유닛의 대상(M3 A7 설계 §4.5): 쓰는 유닛을 뺀 양쪽의 살아 있고 닿는 유닛(대원 칸 차례 → 적 칸 차례).
## 0 이면 null, 하나면 그 유닛(뽑지 않음), 둘 이상이면 난수 하나 randi_range(0, n − 1).
static func confused_target(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef) -> BattleUnit:
	var b := state.battle
	var cands: Array[BattleUnit] = []
	for t in b.party + b.enemies:
		if t != u and t.alive() and reachable(b, u, s, t):
			cands.append(t)
	if cands.is_empty():
		return null
	if cands.size() == 1:
		return cands[0]
	return cands[state.rng.randi_range(0, cands.size() - 1)]


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


## 명중 판정(06 §3.8). 필중·수면 대상·아군 대상은 판정하지 않는다. 쓰는 쪽이 맹목이면 자른 명중률 × blind_hit_mult(M3 A7). 빗나가면 missed 이벤트.
static func _hits(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef, row: Dictionary, t: BattleUnit, events: Array[Dictionary], calc: Dictionary = {}) -> bool:
	if s.sure_hit or t.asleep() or t.side == u.side:
		return true
	var rules := state.defs.battle.rules
	var p := BattleCalc.hit_p(rules, row["accuracy"], u.stats["AGI"], t.evasion_agi(rules))
	if u.ailment == "blind":
		# 맹목(M3 A7 설계 §4.5): 자른 명중률에 blind_hit_mult 를 곱한다(판정하는 길에서만: 필중·수면·아군은 그대로).
		p = BattleCalc.mul(p, rules.blind_hit_mult)
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
	# FOE 합류(M3 A6b, 설계 §4.6): 합류 범위 안의 FOE 만 한 걸음 다가오거나 맞닿았으면 붙는다. 붙은 유닛은 다음 제출부터 움직인다.
	if FoeRules.battle_tick(state, events):
		_check_rows(b, events)


# ---- 전투 끝 (06 §3.17) ----

## 전투를 끝낸다. 거부하면 false 이고 상태·난수·events 를 바꾸지 않는다.
## 거부: battle 없음·pending 거짓·wiped 참·모르는 outcome, 그리고 끝 결과와 아군 전원 쓰러짐이 맞지 않을 때
## ((outcome == "wiped") != 아군 전원 HP 0: 살아 있는 아군 없는 승리·도주, 살아 있는 아군 있는 전멸, 07 §3.4). 그래서 받은 끝 상태는 늘 저장할 수 있다.
## 이벤트(drop…·exp·level_up…·battle_end)는 events 에 덧붙인다: submit 은 자기 이벤트 열을 넘기고, 시험·디버그는 필요하면 배열을 넘긴다.
## 승리 순서(07 §3.4): 드롭(난수) → 경험치·레벨업(대원 칸 순, 난수 없음) → 위험도 0·한계값(난수) → battle_end → battle = null.
## battle_end 는 battle 을 지우기 전에 결과(턴·적 HP·드롭, 승리면 성장 필드 07 §3.5)를 복사해 담는다. reason 이 있으면 battle_end.reason(턴 상한 "turn_cap").
static func finish(state: ExplorationState, outcome: String, events: Array[Dictionary] = [], reason: String = "") -> bool:
	var b := state.battle
	if b == null or not state.encounter.pending or state.wiped or not OUTCOMES.has(outcome):
		return false
	var all_down := b.all_down(BattleUnit.PARTY)
	if (outcome == "wiped") != all_down:
		return false
	var drops := []
	if outcome == "victory":
		for u in b.enemies:
			if u.kill.is_empty():
				continue
			for d in state.defs.battle.enemies[u.def_id].drops:
				if drop_condition_met(d["if"], u.kill) and BattleCalc.roll(state.rng, d["chance"]):
					var item: String = d["item"]
					# 난수는 위에서 먼저 뽑는다(가방이 차도 같은 난수열, 설계 §3.4). 공용 가방(D31)에 드는 만큼만 넣고 앞 드롭부터 채운다.
					var got := BagRules.add(state, item, 1)
					var drop := {"item": item, "amount": got, "capped": got < 1, "enemy": u.slot}
					drops.append(drop)
					var ev := drop.duplicate()
					ev["type"] = "drop"
					events.append(ev)
	var growth := {}
	if outcome == "victory":
		growth = GrowthRules.victory_exp(state, b, events)
	var enemy_hp: Array[int] = []
	for u in b.enemies:
		enemy_hp.append(u.hp)
	# FOE(M3 A6): 전투의 FOE 는 승리면 쓰러지고 도주면 쉰다(FoeRules.battle_over). battle 을 지우기 전에 부른다.
	var foe_from := events.size()
	FoeRules.battle_over(state, outcome, events)
	var foes_defeated: Array[String] = []
	for i in range(foe_from, events.size()):
		if events[i]["type"] == "foe_defeated":
			foes_defeated.append(str(events[i]["foe"]))
	state.encounter.danger = 0
	state.encounter.pending = false
	if outcome == "wiped":
		state.wiped = true
	else:
		state.encounter.roll_threshold(state.rng, state.floor_def.threshold_min, state.floor_def.threshold_max)
	var end := {"type": "battle_end", "outcome": outcome, "turn": b.turn, "enemy_hp": enemy_hp, "drops": drops}
	end.merge(growth)
	if not reason.is_empty():
		end["reason"] = reason
	if not foes_defeated.is_empty():
		end["foes_defeated"] = foes_defeated  # 쓰러뜨린 FOE(M3 A6 설계 §4.5, 의뢰 갈고리). 인카운트 전투의 battle_end 는 그대로다.
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
