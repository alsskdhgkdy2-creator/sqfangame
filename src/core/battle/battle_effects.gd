## 상태이상·봉인·강화 칸·누적 내성·지속 감소(06 §3.11~§3.15). BattleRules 가 부른다.
## 모든 함수는 상태를 바꾸고 이벤트를 events 에 덧붙인다.
## 범위 계약(06 §11.4): 여기 들어오는 값(SkillDef·levels 줄·ailment·bind 사양)은 GameDefs 가 BattleLimits 로 검사한 정의에서만 온다.
## 계산 결과도 같은 범위에 머문다(누적 내성 ≤ resist_max, 남은 턴은 정의의 turns 에서 줄기만 한다, 레벨 사이 같은 kind,
## seq 다시 매기기, 턴 상한 TURN_MAX). 저장에서 들어오는 상태는 BattleState.check_dict 가 같은 BattleLimits 함수로 본다.
## 이 계약은 시험이 지킨다: 결정적 전투 묶음·시뮬레이션 표본의 매 턴 검사 있는 저장 왕복, 경계값 상태 불러오기 → 한 턴 → 저장.
class_name BattleEffects
extends RefCounted


## 상태이상 걸기(06 §3.11). 우선순위가 낮으면 판정 없이 막힌다(난수 없음).
static func apply_ailment(b: BattleState, rules: BattleDb.Rules, rng: GameRng, attacker: BattleUnit, t: BattleUnit, spec: Dictionary, events: Array[Dictionary]) -> void:
	if not t.alive():
		return
	var id: String = spec["id"]
	if not t.ailment.is_empty() and BattleLimits.AILMENT_PRIORITY[id] < BattleLimits.AILMENT_PRIORITY[t.ailment]:
		events.append({"type": "ailment_blocked", "target": t.ref(), "id": id, "current": t.ailment})
		return
	var p := BattleCalc.status_p(rules, spec["chance"], attacker.stats["LUC"], t.stats["LUC"], t.ailment_vuln[id], t.resist_acc.get(id, 0))
	if not BattleCalc.roll(rng, p):
		events.append({"type": "ailment_resisted", "target": t.ref(), "id": id, "p": p})
		return
	t.ailment = id
	t.ailment_turns = spec["turns"]
	t.ailment_damage = spec.get("damage", 0) if id == "poison" else 0
	_gain_resist(t, id, rules)
	events.append({"type": "ailment", "target": t.ref(), "id": id, "turns": t.ailment_turns, "p": p})
	if id == "sleep":
		on_sleep(b, t, events)


## 봉인 걸기(06 §3.12). 상태이상과 따로, 같은 부위면 남은 턴을 새 값으로.
static func apply_bind(rules: BattleDb.Rules, rng: GameRng, attacker: BattleUnit, t: BattleUnit, spec: Dictionary, events: Array[Dictionary]) -> void:
	if not t.alive():
		return
	var part: String = spec["part"]
	var p := BattleCalc.status_p(rules, spec["chance"], attacker.stats["LUC"], t.stats["LUC"], t.bind_vuln[part], t.resist_acc.get(part, 0))
	if not BattleCalc.roll(rng, p):
		events.append({"type": "bind_resisted", "target": t.ref(), "part": part, "p": p})
		return
	t.binds[part] = spec["turns"]
	_gain_resist(t, part, rules)
	events.append({"type": "bound", "target": t.ref(), "part": part, "turns": spec["turns"], "p": p})


static func _gain_resist(t: BattleUnit, key: String, rules: BattleDb.Rules) -> void:
	var v := mini(rules.resist_max, int(t.resist_acc.get(key, 0)) + rules.resist_gain)
	if v > 0:
		t.resist_acc[key] = v
	else:
		t.resist_acc.erase(key)


## 강화·약화 걸기(06 §3.14). 같은 id 는 다시 걸기(남은 턴 새로, 더 센 값, seq 새로 받아 끝으로),
## 칸이 차 있으면 seq 가 가장 작은 효과를 밀어낸다. 효과 id·kind·value·turns 는 정의된 buff/debuff 스킬(s)의 그 레벨 줄에서만 온다.
static func apply_effect(b: BattleState, rules: BattleDb.Rules, t: BattleUnit, s: BattleDb.SkillDef, level: int, events: Array[Dictionary]) -> void:
	if not t.alive():
		return
	var debuff := s.effect == "debuff"
	var row := s.level_row(level)
	var id := s.id
	var kind: String = row["kind"]
	var value: int = row["value"]
	var turns: int = row["turns"]
	var list: Array[Dictionary] = t.debuffs if debuff else t.buffs
	var slots := rules.debuff_slots if debuff else rules.buff_slots
	var evicted: Variant = null
	var refreshed := false
	var e: Dictionary
	var at := -1
	for i in list.size():
		if list[i]["id"] == id:
			at = i
	if at >= 0:
		e = list[at]
		list.remove_at(at)
		e["turns"] = turns
		if absi(value - 1000) > absi(int(e["value"]) - 1000):
			e["value"] = value
		refreshed = true
	else:
		if list.size() >= slots:
			evicted = list.pop_front()
		e = {"id": id, "kind": kind, "value": value, "turns": turns}
	if b.seq >= BattleLimits.SEQ_MAX:
		renumber_seq(b)
	e["seq"] = b.seq
	b.seq += 1
	list.append(e)
	events.append({"type": "buffed", "target": t.ref(), "list": "debuffs" if debuff else "buffs", "effect": e.duplicate(), "refreshed": refreshed, "evicted": evicted})


## seq 다시 매기기(06 §3.14): 전투의 모든 효과 seq 를 지금 순서(seq 오름차순)를 지켜 1부터 다시 매기고
## battle.seq = 효과 수 + 1. 순서만 쓰는 값이라 밀어내기·만료 결과는 같다.
static func renumber_seq(b: BattleState) -> void:
	var all: Array[Dictionary] = []
	for u in b.party + b.enemies:
		all.append_array(u.buffs)
		all.append_array(u.debuffs)
	all.sort_custom(func(x, y): return x["seq"] < y["seq"])
	for i in all.size():
		all[i]["seq"] = i + 1
	b.seq = all.size() + 1


## 해제(06 §3.10): 일반 상태이상과 세 봉인을 모두 지운다. 지운 것 목록.
static func cure(t: BattleUnit) -> Array[String]:
	var removed := cure_ailment(t)
	removed.append_array(cure_bind(t))
	return removed


## 상태 이상만 푼다(M3 A4 테리아카 A). 지운 것 [상태 이상 ID] 또는 빈 배열.
static func cure_ailment(t: BattleUnit) -> Array[String]:
	var removed: Array[String] = []
	if not t.ailment.is_empty():
		removed.append(t.ailment)
	t.ailment = ""
	t.ailment_turns = 0
	t.ailment_damage = 0
	return removed


## 잠금만 모두 푼다(M3 A4 테리아카 B). 지운 부위(bind_list 차례).
static func cure_bind(t: BattleUnit) -> Array[String]:
	var removed: Array[String] = t.bind_list()
	t.binds.clear()
	return removed


## 전투 불능이 되는 순간: 이번 턴 행동 취소, 준비 풀림, 상태 지움(06 §3.4·§3.11·§3.14·§3.16).
static func on_down(b: BattleState, u: BattleUnit, events: Array[Dictionary]) -> void:
	cancel_action(b, u, "down")
	if not u.charging.is_empty():
		events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": "down"})
	u.clear_on_down()


## 수면에 걸리는 순간: 이번 턴 행동 취소, 준비 풀림.
static func on_sleep(b: BattleState, u: BattleUnit, events: Array[Dictionary]) -> void:
	cancel_action(b, u, "asleep")
	if not u.charging.is_empty():
		events.append({"type": "charge_lost", "unit": u.ref(), "skill": u.charging, "reason": "asleep"})
		u.charging = ""


## 큐에서 아직 시작하지 않은 그 유닛의 행동을 취소한다(같은 턴에 깨거나 소생해도 되돌리지 않는다).
static func cancel_action(b: BattleState, u: BattleUnit, reason: String) -> void:
	for a in b.queue:
		if a["unit"] == u and not a["started"] and not a["cancelled"]:
			a["cancelled"] = true
			a["cancel_reason"] = reason


## 턴 끝 3단계: 일반 상태이상 → 봉인(머리·팔·다리) → 강화 → 약화 순으로 남은 턴을 하나 줄이고 0이면 푼다.
static func tick_durations(b: BattleState, events: Array[Dictionary]) -> void:
	var units: Array[BattleUnit] = []
	units.append_array(b.party)
	units.append_array(b.enemies)
	for u in units:
		if u.alive() and not u.ailment.is_empty():
			u.ailment_turns -= 1
			if u.ailment_turns <= 0:
				events.append({"type": "expired", "target": u.ref(), "what": "ailment", "id": u.ailment})
				u.ailment = ""
				u.ailment_turns = 0
				u.ailment_damage = 0
	for u in units:
		for part in BattleLimits.PARTS:
			if u.alive() and u.binds.has(part):
				u.binds[part] -= 1
				if u.binds[part] <= 0:
					u.binds.erase(part)
					events.append({"type": "expired", "target": u.ref(), "what": "bind", "id": part})
	for what in ["buff", "debuff"]:
		for u in units:
			var list: Array[Dictionary] = u.buffs if what == "buff" else u.debuffs
			var keep: Array[Dictionary] = []
			for e in list:
				e["turns"] -= 1
				if e["turns"] <= 0:
					events.append({"type": "expired", "target": u.ref(), "what": what, "id": e["id"]})
				else:
					keep.append(e)
			list.assign(keep)


## 턴 끝 4단계: 걸려 있지 않은 상태·부위의 누적 내성 −resist_decay(최소 0, 0이면 키를 지운다).
static func decay_resist(b: BattleState, rules: BattleDb.Rules) -> void:
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		for u in b.units_of(side):
			for k in BattleLimits.AILMENTS + BattleLimits.PARTS:
				if not u.resist_acc.has(k) or u.ailment == k or u.binds.has(k):
					continue
				var v: int = u.resist_acc[k] - rules.resist_decay
				if v > 0:
					u.resist_acc[k] = v
				else:
					u.resist_acc.erase(k)
