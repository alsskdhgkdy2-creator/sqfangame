## 적 행동 선택(06 §3.16). 명령 제출 직후, 순서 정하기 전에 적 칸 순으로 부른다.
## 조건은 그 시점(턴 시작) 상태로 본다. 난수는 후보가 둘 이상일 때의 가중치·대상 고르기에서만 뽑는다.
class_name EnemyAi
extends RefCounted


## 적마다 {skill: SkillDef, level: 1, target: 칸 번호(전체·자기 대상은 -1)} 또는 null(고르지 않음·idle).
## 혼란한 적(M3 A7 설계 §4.5)은 규칙을 보지 않고(난수 없음) {kind: "confused", skill: BattleDb.confused_attack(), level: 1, target: -1}.
static func choose_all(state: ExplorationState, events: Array[Dictionary]) -> Array:
	var out := []
	for u in state.battle.enemies:
		out.append(choose(state, u, events))
	return out


static func choose(state: ExplorationState, u: BattleUnit, events: Array[Dictionary]) -> Variant:
	if not u.alive() or u.asleep():
		return null
	if u.confused():
		var conf := {"kind": BattleRules.CONFUSED, "skill": BattleDb.confused_attack(), "level": 1, "target": -1}
		if not u.charging.is_empty():
			events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": "no_target"})
			u.charging = ""
		return conf
	var b := state.battle
	var db := state.defs.battle
	var e: BattleDb.EnemyDef = db.enemies[u.def_id]
	var chosen: Variant = null
	for rule in e.ai:
		if not matches(rule["if"], u, b):
			continue
		var cands: Array = []
		for c in rule["use"]:
			if not BattleRules.candidates(b, u, db.skill(c["skill"])).is_empty():
				cands.append(c)
		if cands.is_empty():
			continue
		if u.on_bound == "switch":
			var free: Array = cands.filter(func(c): return u.bound_part_of(db.skill(c["skill"])).is_empty())
			if not free.is_empty():
				cands = free
		var weights: Array[int] = []
		for c in cands:
			weights.append(c["weight"])
		var pick: Dictionary = cands[BattleCalc.pick_weighted(state.rng, weights)]
		var s := db.skill(pick["skill"])
		chosen = {"skill": s, "level": 1, "target": choose_target(state, u, s, pick["target"])}
		break
	if chosen == null:
		events.append({"type": "idle", "unit": u.ref()})
	if not u.charging.is_empty() and (chosen == null or chosen["skill"].id != u.charging):
		events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": "no_target"})
		u.charging = ""
	return chosen


static func matches(cond: Dictionary, u: BattleUnit, b: BattleState) -> bool:
	if cond.has("charging") and (not u.charging.is_empty()) != cond["charging"]:
		return false
	if cond.has("turn_mod") and b.turn % int(cond["turn_mod"][0]) != int(cond["turn_mod"][1]):
		return false
	if cond.has("hp_below") and not (u.hp * 1000 < int(cond["hp_below"]) * u.max_hp):
		return false
	return true


## 대상 정책(06 §3.16). 단일: 유효 대상 칸 오름차순에서 random = pick, lowest_hp = HP 최소(같으면 작은 칸).
## 줄: 유효 대상이 있는 실효 열을 전열 → 후열로 놓고 pick, 그 줄의 가장 작은 칸. 전체·자기: -1(뽑지 않음).
static func choose_target(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef, policy: String) -> int:
	var b := state.battle
	var cands := BattleRules.candidates(b, u, s)
	match s.target:
		"enemy_all", "ally_all", "self":
			return -1
		"enemy_row", "ally_row":
			var rows: Array[Array] = []
			for row in ["front", "back"]:
				var in_row := cands.filter(func(t): return b.effective_row(t) == row)
				if not in_row.is_empty():
					rows.append(in_row)
			return rows[BattleCalc.pick(state.rng, rows.size())][0].slot
	if policy == "lowest_hp":
		var best: BattleUnit = cands[0]
		for t in cands:
			if t.hp < best.hp:
				best = t
		return best.slot
	return cands[BattleCalc.pick(state.rng, cands.size())].slot
