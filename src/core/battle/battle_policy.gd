## 자동 명령 정책(06 §7.2): 기본·공격만·전력. 시뮬레이션·디버그 자동 전투·시험이 쓴다.
## 난수를 쓰지 않고 상태를 바꾸지 않는다. 앞 조건이 안 되면(TP·봉인·대상) 다음 후보로 넘어간다.
## 동점은 칸 번호가 작은 유닛, 위저드 전력의 (적, 글리프) 동점은 적 칸 → 열 → 냉각 → 전격 순.
class_name BattlePolicy
extends RefCounted

const DEFAULT := "default"
const ATTACK_ONLY := "attack_only"
const FULL := "full"
const NAMES := [DEFAULT, ATTACK_ONLY, FULL]

const REBOOT := "skill.nano_medic.reboot"
const REPAIR := "skill.nano_medic.nano_repair"
const PATCH := "skill.nano_medic.refresh_patch"
const FRONT_GUARD := "skill.holo_knight.front_guard"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
## 열 → 냉각 → 전격 순(동점·첫 약점 순서).
const GLYPHS := [["skill.glyph_wizard.heat_glyph", "fire"], ["skill.glyph_wizard.frost_glyph", "ice"], ["skill.glyph_wizard.shock_glyph", "volt"]]


## 지금 턴의 명령 배열(길이 = 대원 수, 명령을 받지 않는 대원은 null).
## 모르는 정책 이름이면 빈 배열이다: 제출 검사가 length 로 거부하므로 조용히 기본처럼 돌지 않는다.
static func choose(state: ExplorationState, policy: String) -> Array:
	var out := []
	if not NAMES.has(policy):
		return out
	for i in state.battle.party.size():
		out.append(choose_one(state, i, policy) if BattleRules.can_command(state, i) else null)
	return out


static func choose_one(state: ExplorationState, i: int, policy: String) -> Dictionary:
	var c: Variant = null
	match state.defs.party.class_ids[i]:
		"class.nano_medic":
			c = _medic(state, i, policy)
		"class.holo_knight":
			c = _knight(state, i, policy)
		"class.glyph_wizard":
			c = _wizard(state, i, policy)
		"class.blade_duelist":
			c = _duelist(state, i, policy)
	return c if c != null else attack_command(state, i)


## 일반 공격: 유효 대상 가운데 HP 가 가장 낮은 적. 대상이 없으면 방어.
static func attack_command(state: ExplorationState, i: int) -> Dictionary:
	var best: BattleUnit = null
	for t in BattleRules.candidates(state.battle, state.battle.party[i], BattleRules.skill_of(state, i, "attack")):
		if best == null or t.hp < best.hp:
			best = t
	if best == null:
		return {"kind": "guard"}
	return {"kind": "attack", "target": best.slot}


static func _usable(state: ExplorationState, i: int, sid: String) -> bool:
	return BattleRules.skill_of(state, i, sid) != null and BattleRules.skill_block_reason(state, i, sid).is_empty()


static func _use(sid: String, target: int) -> Dictionary:
	return {"kind": "skill", "skill": sid, "target": target}


static func _half_tp(u: BattleUnit) -> bool:
	return u.tp * 2 >= u.max_tp


# ---- 직업별 ----

static func _medic(state: ExplorationState, i: int, policy: String) -> Variant:
	var b := state.battle
	var u := b.party[i]
	if policy != ATTACK_ONLY and _usable(state, i, REBOOT):
		var dead := BattleRules.valid_targets(state, i, REBOOT)
		if not dead.is_empty():
			return _use(REBOOT, dead[0])
	if _usable(state, i, REPAIR):
		var low: BattleUnit = null
		for t in b.party:
			if t.alive() and t.hp * 2 < t.max_hp and (low == null or t.hp * low.max_hp < low.hp * t.max_hp):
				low = t
		if low != null:
			return _use(REPAIR, low.slot)
	if policy != ATTACK_ONLY and (policy == FULL or _half_tp(u)) and _usable(state, i, PATCH):
		for t in b.party:
			if t.alive() and (t.ailment == "sleep" or t.ailment == "paralysis" or not t.binds.is_empty()):
				return _use(PATCH, t.slot)
	return null


static func _knight(state: ExplorationState, i: int, policy: String) -> Variant:
	if policy == ATTACK_ONLY or not _usable(state, i, FRONT_GUARD):
		return null
	for e in state.battle.enemies:
		if e.alive() and not e.charging.is_empty():
			return _use(FRONT_GUARD, i)
	return null


static func _wizard(state: ExplorationState, i: int, policy: String) -> Variant:
	if policy == ATTACK_ONLY:
		return null
	var b := state.battle
	var u := b.party[i]
	if policy == FULL:
		var best := -1
		var pick: Variant = null
		for e in b.enemies:
			if not e.alive():
				continue
			for g in GLYPHS:
				if not _usable(state, i, g[0]) or not BattleRules.valid_targets(state, i, g[0]).has(e.slot):
					continue
				var d := expected_damage(state, u, BattleRules.skill_of(state, i, g[0]), e)
				if d > best:
					best = d
					pick = _use(g[0], e.slot)
		return pick
	if not _half_tp(u):
		return null
	var target: BattleUnit = null
	var glyph := ""
	for e in b.enemies:
		if not e.alive() or (target != null and e.hp <= target.hp):
			continue
		for g in GLYPHS:
			if e.resist[g[1]] > 1000:
				target = e
				glyph = g[0]
				break
	if target == null or not _usable(state, i, glyph) or not BattleRules.valid_targets(state, i, glyph).has(target.slot):
		return null
	return _use(glyph, target.slot)


static func _duelist(state: ExplorationState, i: int, policy: String) -> Variant:
	if policy == ATTACK_ONLY or not _usable(state, i, HIGH_SLASH):
		return null
	var b := state.battle
	var u := b.party[i]
	if policy == DEFAULT and not _half_tp(u):
		return null
	var big: BattleUnit = null
	for t in BattleRules.candidates(b, u, BattleRules.skill_of(state, i, HIGH_SLASH)):
		if big == null or t.hp > big.hp:
			big = t
	if big == null:
		return null
	var d := expected_damage(state, u, BattleRules.skill_of(state, i, "attack"), big)
	if (policy == DEFAULT and big.hp > 2 * d) or (policy == FULL and big.hp > d):
		return _use(HIGH_SLASH, big.slot)
	return null


## 기대 피해(06 §7.2): 난수·크리티컬·명중 없이 §3.9 식 그대로. 입력은 규칙과 같은 BattleRules.damage_inputs 로 만들고
## 피해 난수 자리에 1000 을 넣는다. 속성 무효(0)는 0.
static func expected_damage(state: ExplorationState, u: BattleUnit, s: BattleDb.SkillDef, t: BattleUnit) -> int:
	if t.resist[s.element] == 0:
		return 0
	var rules := state.defs.battle.rules
	var row := s.level_row(u.skills.get(s.id, 1))
	return BattleCalc.damage(rules, BattleRules.damage_inputs(state.battle, rules, u, s, row, t, false, 1000))["final"]
