extends TestCase
## R2 §4.6 최소 검증 사례 다섯(03 M2 수용 기준, 06 §10.1 표 첫 다섯 줄).
## 함수 이름 접두사: test_r2_row_range_* · test_r2_bind_then_fizzle_* · test_r2_ailment_overwrite_* ·
## test_r2_fourth_buff_* · test_r2_kill_moment_drop_*

const Fx := preload("res://tests/fixtures.gd")

const ARM_LOCK := "skill.enemy.t_arm_lock"
const HEAD_LOCK := "skill.enemy.t_head_lock"
const TAP := "skill.enemy.t_tap"
const HEAD_HIT := "skill.enemy.t_head_hit"
const SLEEP := "skill.enemy.t_sleep"
const KILL := "skill.enemy.t_kill"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const HEAT := "skill.glyph_wizard.heat_glyph"
const OVERCLOCK := "skill.blade_duelist.overclock"


func _skills() -> Array:
	return [
		Fx.enemy_skill(ARM_LOCK, "damage", "enemy_one", {}, {"bind": {"part": "arm", "chance": 1000, "turns": 3}}),
		Fx.enemy_skill(HEAD_LOCK, "damage", "enemy_one", {}, {"bind": {"part": "head", "chance": 1000, "turns": 3}}),
		Fx.enemy_skill(TAP, "damage", "enemy_one"),
		Fx.enemy_skill(HEAD_HIT, "damage", "enemy_one", {"parts": ["head"]}),
		Fx.enemy_skill(SLEEP, "ailment", "enemy_one", {"sure_hit": true}, {"ailment": {"id": "sleep", "chance": 1000, "turns": 2}}),
		Fx.enemy_skill(KILL, "damage", "enemy_one", {}, {"power": 2000}),
	] + _effect_skills()


## 네 번째 강화 시험의 강화·약화. 모두 BattleDb.parse 를 거친 정의다(Lv n = 줄 n).
func _effect_skills() -> Array:
	var out := [
		Fx.effect_skill("skill.t.a", false, [["phys_atk", 1100, 3], ["phys_atk", 1200, 3], ["phys_atk", 1300, 3], ["phys_atk", 1200, 5], ["phys_atk", 1400, 2], ["phys_atk", 1100, 5]]),
		Fx.effect_skill("skill.t.b", false, [["phys_atk", 1200, 3], ["phys_atk", 1300, 3]]),
		Fx.effect_skill("skill.t.c", false, [["phys_atk", 1300, 3]]),
		Fx.effect_skill("skill.t.d", false, [["phys_atk", 1400, 3]]),
		Fx.effect_skill("skill.t.g", false, [["phys_def", 700, 3], ["phys_def", 800, 3]]),
		Fx.effect_skill("skill.t.short", false, [["phys_atk", 1100, 1]]),
		Fx.effect_skill("skill.enemy.t_w", true, [["phys_def", 1250, 3], ["phys_def", 1100, 3]]),
		Fx.effect_skill("skill.enemy.t_dshort", true, [["phys_atk", 900, 1]]),
		Fx.effect_skill("skill.enemy.t_d9", true, [["phys_atk", 800, 3]]),
	]
	for i in 3:
		out.append(Fx.effect_skill("skill.t.b%d" % i, false, [["phys_atk", 1100 + i, 3]]))
		out.append(Fx.effect_skill("skill.enemy.t_d%d" % i, true, [["phys_atk", 900 - i, 3]]))
	return out


func _enemies() -> Array:
	return [
		Fx.enemy("enemy.t_binder", 999, [10, 10, 10, 10, 999, 50], [[{}, [[ARM_LOCK, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_head_binder", 999, [10, 10, 10, 10, 999, 50], [[{}, [[HEAD_LOCK, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_switcher", 999, [10, 10, 10, 10, 1, 10], [[{}, [[HEAD_HIT, 1, "lowest_hp"], [TAP, 1, "lowest_hp"]]]], {"on_bound": "switch"}),
		Fx.enemy("enemy.t_failer", 999, [10, 10, 10, 10, 1, 10], [[{}, [[HEAD_HIT, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_sleeper", 999, [10, 10, 10, 10, 999, 50], [[{}, [[SLEEP, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_hitter", 999, [10, 10, 10, 10, 500, 10], [[{}, [[TAP, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_killer", 999, [999, 10, 10, 10, 999, 10], [[{}, [[KILL, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_lucky", 999, [10, 10, 10, 10, 1, 50], [[{}, [[Fx.MEND, 1]]]]),
		Fx.enemy("enemy.t_plated", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]],
			{"drops": [{"item": "item.beetle_plate", "chance": 500, "if": {"killed_while_bound": "arm"}}]}),
		Fx.enemy("enemy.t_plain", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]], {"drops": [{"item": "item.beetle_plate", "chance": 500}]}),
	]


func _defs(formations: Dictionary, rules: Dictionary = Fx.EXACT) -> GameDefs:
	return Fx.battle_defs(Fx.test_files(_skills(), _enemies(), formations), rules)


func _game(formations: Dictionary, name: String, seed_value: int = 1, rules: Dictionary = Fx.EXACT) -> ExplorationState:
	return Fx.battle(_defs(formations, rules), "formation.t." + name, seed_value)


func _calc_by(events: Array[Dictionary], party_slot: int) -> Dictionary:
	for e in events:
		if e["type"] == "damaged" and e["unit"]["side"] == "party" and e["unit"]["slot"] == party_slot:
			return e["calc"]
	return {}


func _types(events: Array[Dictionary]) -> Array[String]:
	return Fx.types(events)


# ---- 1. 전후열 사거리 ----

func test_r2_row_range_rear_melee_cannot_target_rear() -> void:
	var s := _game({"fb": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "fb")
	check_eq(BattleRules.valid_targets(s, 3, "attack"), [0] as Array[int], "후열 메딕 근접은 전열만")
	check_eq(BattleRules.valid_targets(s, 1, "attack"), [0, 1] as Array[int], "전열 근접은 둘 다")
	check_eq(BattleRules.valid_targets(s, 4, HEAT), [0, 1] as Array[int], "원거리는 둘 다")
	var h := Fx.battle_hash(s)
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(1)}))
	check_eq(ev, [{"type": "rejected", "reason": "invalid_target", "slot": 3}] as Array[Dictionary], "제출 거부")
	check_eq(Fx.battle_hash(s), h, "상태·난수 그대로")


func test_r2_row_range_melee_half_when_either_side_is_rear() -> void:
	# 같은 시드·같은 난수 상태(기본 규칙 상수)에서 대상만 다르게.
	var f := {"fb": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}
	var a := _game(f, "fb", 5, {})
	var b := _game(f, "fb", 5, {})
	var ca := _calc_by(BattleRules.submit(a, Fx.cmds(a, {1: Fx.atk(0)})), 1)
	var cb := _calc_by(BattleRules.submit(b, Fx.cmds(b, {1: Fx.atk(1)})), 1)
	check_eq(ca["roll"], cb["roll"], "같은 난수")
	check_eq(ca["base"], cb["base"], "같은 기본값")
	check_eq(ca["row"], ca["element"], "전열 → 전열 보정 없음")
	check_eq(cb["row"], BattleCalc.mul(cb["element"], 500), "전열 → 후열 ×500")
	# 손 계산(난수 없는 상수): 메딕(후열, A 15) → 전열 시험 적(VIT 10): 15²×100/(100×25) = 9 → ×500 = 4.
	var s := _game(f, "fb")
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(0), 4: Fx.use(HEAT, 1)}))
	var cm := _calc_by(ev, 3)
	check_eq([cm["base"], cm["row"], cm["final"]], [9, 4, 4], "후열 → 전열 ×500")
	var cw := _calc_by(ev, 4)
	check_eq([cw["base"], cw["row"]], [32, 32], "원거리 후열 → 후열 보정 없음")


func test_r2_row_range_enemy_rear_moves_up_after_front_falls() -> void:
	var s := _game({"fb": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "fb")
	s.battle.enemies[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	var shift := Fx.of_type(ev, "row_shift")
	check_eq(shift, [{"type": "row_shift", "side": "enemy", "promoted": true}] as Array[Dictionary], "row_shift")
	check_eq(s.battle.effective_row(s.battle.enemies[1]), "front", "후열이 실효 전열")
	check_eq(BattleRules.valid_targets(s, 3, "attack"), [1] as Array[int], "후열 메딕 근접이 닿음")
	var c := _calc_by(BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(1)})), 3)
	check_eq([c["base"], c["row"]], [9, 4], "공격자가 후열이라 ×500 은 남음")


func test_r2_row_range_party_front_falls_rear_loses_penalty() -> void:
	var s := _game({"k": [["enemy.t_killer", "front"], [Fx.DUMMY, "front"]]}, "k")
	s.party.members[0].hp = 0
	s.party.members[1].hp = 0
	s.party.members[2].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(1)}))
	var t := _types(ev)
	check(t.has("row_shift") and t.find("row_shift") < t.rfind("damaged"), "전열 전멸 → row_shift 가 메딕 공격보다 먼저: %s" % str(t))
	check_eq(Fx.of_type(ev, "row_shift")[0], {"type": "row_shift", "side": "party", "promoted": true}, "아군 row_shift")
	var c := _calc_by(ev, 3)
	check_eq([c["base"], c["row"]], [9, 9], "실효 전열이 된 메딕은 보정 없음")


# ---- 2. 봉인 후 불발 ----

func test_r2_bind_then_fizzle_chosen_skill_fails_and_keeps_tp() -> void:
	var s := _game({"b": [["enemy.t_binder", "front"]]}, "b")
	s.party.members[1].hp = 10
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(HIGH_SLASH, 0)}))
	check_eq(_types(ev), ["guarding", "guarding", "guarding", "guarding", "action", "damaged", "bound", "failed", "turn_end"] as Array[String], "이벤트 순서")
	check_eq(Fx.of_type(ev, "failed")[0], {"type": "failed", "unit": {"side": "party", "slot": 1}, "reason": "bound_arm", "skill": HIGH_SLASH}, "실행 때 bound_arm")
	check_eq(s.battle.party[1].tp, 32, "TP 그대로")
	check_eq(s.battle.enemies[0].hp, 999, "대상 HP 그대로")
	check_eq(BattleRules.skill_block_reason(s, 1, HIGH_SLASH), "bound_arm", "다음 턴에는 고를 수 없음")
	check_eq(BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(HIGH_SLASH, 0)}))[0]["reason"], "bound_arm", "제출 거부")
	var ev2 := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check(_calc_by(ev2, 1).has("final"), "같은 상태에서 일반 공격은 됨")


func test_r2_bind_then_fizzle_head_bound_wizard_glyph_fails() -> void:
	var s := _game({"h": [["enemy.t_head_binder", "front"]]}, "h")
	s.party.members[4].hp = 5
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
	check_eq(Fx.of_type(ev, "failed")[0]["reason"], "bound_head", "머리 봉인 위저드의 글리프 실패")
	check_eq(s.battle.party[4].tp, 60, "TP 그대로")
	check_eq(s.battle.enemies[0].hp, 999, "피해 없음")


func test_r2_bind_then_fizzle_enemy_switch_and_fail() -> void:
	var f := {"sw": [["enemy.t_switcher", "front"]], "fl": [["enemy.t_failer", "front"]]}
	var s := _game(f, "sw")
	s.battle.enemies[0].binds["head"] = 3
	var before := s.rng.get_state()
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var act := Fx.of_type(ev, "action")
	check_eq(act.size(), 1, "switch 는 행동함")
	check_eq(act[0]["skill"], TAP, "봉인된 스킬을 빼고 고름")
	check_eq(s.rng.get_state(), before, "후보 하나라 뽑지 않음(이 턴은 난수 없음)")
	s = _game(f, "fl")
	s.battle.enemies[0].binds["head"] = 3
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "failed"), [{"type": "failed", "unit": {"side": "enemy", "slot": 0}, "reason": "bound_head", "skill": HEAD_HIT}] as Array[Dictionary], "fail 은 골라서 실행 때 실패")


# ---- 3. 상태 덮어쓰기 ----

func test_r2_ailment_overwrite_priority_and_refresh() -> void:
	var s := _game({"l": [["enemy.t_lucky", "front"]]}, "l")
	var b := s.battle
	var r := s.defs.battle.rules
	var lucky := b.enemies[0]
	var u := b.party[1]
	var ev: Array[Dictionary] = []
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "poison", "chance": 1000, "turns": 3, "damage": 5}, ev)
	check_eq([u.ailment, u.ailment_turns, u.ailment_damage], ["poison", 3, 5], "독")
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "paralysis", "chance": 1000, "turns": 3}, ev)
	check_eq([u.ailment, u.ailment_damage], ["paralysis", 0], "독 → 마비(높음) 덮어씀")
	var before := s.rng.get_state()
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "poison", "chance": 500, "turns": 3, "damage": 5}, ev)
	check_eq(ev[-1], {"type": "ailment_blocked", "target": u.ref(), "id": "poison", "current": "paralysis"}, "마비 중 독은 막힘")
	check_eq(s.rng.get_state(), before, "막히면 난수를 뽑지 않음")
	check_eq(u.ailment, "paralysis", "그대로")
	u.ailment_turns = 1
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "paralysis", "chance": 1000, "turns": 3}, ev)
	check_eq(u.ailment_turns, 3, "마비 중 마비는 남은 턴 갱신")
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "sleep", "chance": 1000, "turns": 2}, ev)
	check_eq(u.ailment, "sleep", "수면(3) 이 마비(2) 를 덮어씀")
	before = s.rng.get_state()
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "paralysis", "chance": 500, "turns": 3}, ev)
	check_eq([ev[-1]["type"], u.ailment, s.rng.get_state()], ["ailment_blocked", "sleep", before], "수면 중 마비 막힘")


func test_r2_ailment_overwrite_sleep_breaks_on_direct_damage_and_skips_turn() -> void:
	var s := _game({"z": [["enemy.t_sleeper", "front"], ["enemy.t_hitter", "front"]]}, "z")
	s.party.members[4].hp = 5
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
	var t := _types(ev)
	var i_sleep := t.find("ailment")
	var i_woke := t.find("woke")
	var i_fail := t.find("failed")
	check(i_sleep >= 0 and i_sleep < i_woke and i_woke < i_fail, "잠듦 → 피해로 깸 → 차례에 failed: %s" % str(t))
	check_eq(ev[i_fail], {"type": "failed", "unit": {"side": "party", "slot": 4}, "reason": "asleep", "skill": HEAT}, "깨도 그 턴은 행동하지 않음")
	check_eq(s.battle.party[4].ailment, "", "피해로 풀림")
	check_eq(s.battle.party[4].hp, 4, "피해 1")
	check_eq(s.battle.party[4].tp, 60, "행동하지 않아 TP 그대로")
	check_eq(s.battle.enemies[0].hp, 999, "글리프 피해 없음")


func test_r2_ailment_overwrite_one_ailment_three_binds_cleared_on_down() -> void:
	var s := _game({"l": [["enemy.t_lucky", "front"]]}, "l")
	var b := s.battle
	var r := s.defs.battle.rules
	var lucky := b.enemies[0]
	var u := b.party[2]
	var ev: Array[Dictionary] = []
	BattleEffects.apply_ailment(b, r, s.rng, lucky, u, {"id": "poison", "chance": 1000, "turns": 3, "damage": 5}, ev)
	for part in ["head", "arm", "leg"]:
		BattleEffects.apply_bind(r, s.rng, lucky, u, {"part": part, "chance": 1000, "turns": 2}, ev)
	BattleEffects.apply_effect(b, r, u, s.defs.battle.skill(OVERCLOCK), 1, ev)
	BattleEffects.apply_effect(b, r, u, s.defs.battle.skill("skill.enemy.rending_howl"), 1, ev)
	check_eq([u.ailment, u.bind_list()], ["poison", ["head", "arm", "leg"] as Array[String]], "상태이상 하나 + 봉인 셋 동시")
	BattleRules.damage_unit(s, u, 999, lucky, "bash", TAP, ev, {})
	check_eq([u.hp, u.ailment, u.binds, u.buffs.size(), u.debuffs.size()], [0, "", {}, 0, 0], "전투 불능이 되면 모두 지워짐")


# ---- 4. 네 번째 강화 ----

func _fx_state() -> ExplorationState:
	return _game({"d": [[Fx.DUMMY, "front"]]}, "d")


func _apply(s: ExplorationState, u: BattleUnit, id: String, level: int = 1) -> Dictionary:
	return Fx.apply_effect(s, u, id, level)


func _ids(list: Array) -> Array:
	return list.map(func(e): return e["id"])


func test_r2_fourth_buff_evicts_oldest() -> void:
	var s := _fx_state()
	var u := s.battle.party[0]
	for id in ["skill.t.a", "skill.t.b", "skill.t.c"]:
		check_eq(_apply(s, u, id)["evicted"], null, "칸이 남음")
	check_eq(u.buffs.map(func(e): return [e["value"], e["seq"]]), [[1100, 1], [1200, 2], [1300, 3]], "정의의 값, seq 1·2·3")
	var ev := _apply(s, u, "skill.t.d")
	check_eq(ev["evicted"]["id"], "skill.t.a", "A 가 밀려남(evicted)")
	check_eq(_ids(u.buffs), ["skill.t.b", "skill.t.c", "skill.t.d"], "B·C·D")
	check_eq(BattleState.check_dict(s.battle.to_dict(), s.defs, s.party.members), "", "저장 검사 통과")


func test_r2_fourth_buff_reapplied_effect_counts_as_newest() -> void:
	var s := _fx_state()
	var u := s.battle.party[0]
	for id in ["skill.t.a", "skill.t.b", "skill.t.c"]:
		_apply(s, u, id)
	var re := _apply(s, u, "skill.t.a", 6)
	check(re["refreshed"] and re["evicted"] == null, "다시 걸기는 밀어내지 않음")
	check_eq(_ids(u.buffs), ["skill.t.b", "skill.t.c", "skill.t.a"], "A 가 최근으로")
	check_eq([u.buffs[2]["seq"], u.buffs[2]["turns"]], [4, 5], "seq 새로 받음, 남은 턴 새로")
	check_eq(_apply(s, u, "skill.t.d")["evicted"]["id"], "skill.t.b", "B 가 밀려남")
	check_eq(_ids(u.buffs), ["skill.t.c", "skill.t.a", "skill.t.d"], "C·A·D")
	check_eq(BattleState.check_dict(s.battle.to_dict(), s.defs, s.party.members), "", "저장 검사 통과")


func test_r2_fourth_buff_reapply_keeps_count_refreshes_turns_keeps_stronger() -> void:
	var s := _fx_state()
	var u := s.battle.party[0]
	_apply(s, u, "skill.t.a", 3)
	_apply(s, u, "skill.t.a", 4)
	check_eq([u.buffs.size(), u.buffs[0]["value"], u.buffs[0]["turns"]], [1, 1300, 5], "칸 수 그대로, 남은 턴 새로, 더 센 값 유지")
	_apply(s, u, "skill.t.a", 5)
	check_eq([u.buffs[0]["value"], u.buffs[0]["turns"]], [1400, 2], "더 센 값으로")
	_apply(s, u, "skill.enemy.t_w", 1)
	_apply(s, u, "skill.enemy.t_w", 2)
	check_eq(u.debuffs[0]["value"], 1250, "약화도 1000 에서 먼 값")
	_apply(s, u, "skill.t.g", 1)
	_apply(s, u, "skill.t.g", 2)
	check_eq(u.buffs[1]["value"], 700, "방어 강화는 작은 값이 셈")
	check_eq(BattleState.check_dict(s.battle.to_dict(), s.defs, s.party.members), "", "저장 검사 통과")


func test_r2_fourth_buff_debuff_slots_are_separate() -> void:
	var s := _fx_state()
	var u := s.battle.party[0]
	for i in 3:
		_apply(s, u, "skill.t.b%d" % i)
		_apply(s, u, "skill.enemy.t_d%d" % i)
	check_eq([u.buffs.size(), u.debuffs.size()], [3, 3], "강화 3 + 약화 3")
	check_eq(_apply(s, u, "skill.enemy.t_d9")["evicted"]["id"], "skill.enemy.t_d0", "약화끼리만 밀어냄")
	check_eq(_ids(u.buffs), ["skill.t.b0", "skill.t.b1", "skill.t.b2"], "강화 칸 그대로")
	check_eq(BattleState.check_dict(s.battle.to_dict(), s.defs, s.party.members), "", "저장 검사 통과")


func test_r2_fourth_buff_expiry_order() -> void:
	var s := _fx_state()
	var u := s.battle.party[1]
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(OVERCLOCK)}))
	check_eq(u.buffs[0]["turns"], 2, "걸린 턴 끝에 3 → 2")
	_apply(s, u, "skill.t.short")
	_apply(s, u, "skill.enemy.t_dshort")
	ev = BattleRules.submit(s, Fx.cmds(s))
	var exp := Fx.of_type(ev, "expired")
	check_eq(exp.map(func(e): return [e["what"], e["id"]]), [["buff", "skill.t.short"], ["debuff", "skill.enemy.t_dshort"]], "강화 → 약화 순으로 만료")
	check_eq(u.buffs[0]["turns"], 1, "오버클럭 1 남음")
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "expired").map(func(e): return e["id"]), [OVERCLOCK], "세 번째 턴 끝에 풀림")
	check(u.buffs.is_empty(), "칸 비움")


func test_r2_fourth_buff_multiply_order_is_fixed_and_survives_save() -> void:
	# 메딕(후열) → 전열 시험 적: base 9 → ×500 = 4. 공격 강화 1300·1200 은 value 오름차순(1200 → 1300)으로 4 → 4 → 5.
	# 1300 을 먼저 곱하면 4 → 5 → 6 이 되므로 어느 순서로 걸어도 5 여야 한다. 1300 = skill.t.b Lv2, 1200 = skill.t.a Lv2.
	var results := []
	for order in [[["skill.t.b", 2], ["skill.t.a", 2]], [["skill.t.a", 2], ["skill.t.b", 2]]]:
		var s := _fx_state()
		for x in order:
			_apply(s, s.battle.party[3], x[0], x[1])
		results.append(_calc_by(BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(0)})), 3)["atk_mul"])
	check_eq(results, [5, 5], "같은 효과 집합이면 같은 피해(곱 순서 고정)")
	# 검사 있는 저장 왕복(SaveCodec.encode → decode, BattleState.check_dict 를 거친다) 전후로 같은 피해·이벤트·해시.
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d", 3, {})
	_apply(s, s.battle.party[3], "skill.t.b", 2)
	_apply(s, s.battle.party[3], "skill.t.a", 2)
	var c := Fx.battle_clone(s)
	check(c != null, "검사 있는 저장 왕복을 통과")
	if c == null:
		return
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "왕복 뒤 같은 해시")
	var e1 := BattleRules.submit(s, Fx.cmds(s, {3: Fx.atk(0), 1: Fx.atk(0)}))
	var e2 := BattleRules.submit(c, Fx.cmds(c, {3: Fx.atk(0), 1: Fx.atk(0)}))
	check_eq(Fx.events_text(e2), Fx.events_text(e1), "같은 이벤트")
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "같은 다음 상태")


# ---- 5. 조건부 드롭의 처치 순간 상태 ----

const BEETLE := {"beetle": [["enemy.clamp_beetle", "front"]], "moth": [["enemy.cable_moth", "back"]]}


func _drops(events: Array[Dictionary]) -> Array:
	return Fx.of_type(events, "drop").map(func(e): return e["item"])


func test_r2_kill_moment_drop_arm_bound_beetle() -> void:
	var s := _game(BEETLE, "beetle")
	var beetle := s.battle.enemies[0]
	beetle.hp = 1
	beetle.binds["arm"] = 2
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "defeated")[0]["kill"], {"turn": 0, "element": "slash", "ailment": null, "binds": ["arm"], "by": "attack"}, "처치 기록")
	check_eq(beetle.binds, {}, "처치 뒤 유닛의 봉인은 비었음")
	check(_drops(ev).has("item.intact_pincer"), "온전한 집게 얻음: %s" % str(_drops(ev)))
	check_eq(s.materials.get("item.intact_pincer", 0), 1, "소재에 더함")
	check_eq(s.battle, null, "전투 끝")


func test_r2_kill_moment_drop_bind_expired_before_kill() -> void:
	var s := _game(BEETLE, "beetle")
	var beetle := s.battle.enemies[0]
	beetle.binds["arm"] = 1
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check(Fx.of_type(ev, "expired").any(func(e): return e["target"]["side"] == "enemy" and e["id"] == "arm"), "턴 끝에 팔 봉인 풀림")
	beetle.hp = 1
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "defeated")[0]["kill"]["binds"], [], "처치 순간 봉인 없음")
	check(not _drops(ev).has("item.intact_pincer"), "못 얻음")


func test_r2_kill_moment_drop_poison_kill_while_arm_bound() -> void:
	var s := _game(BEETLE, "beetle")
	var beetle := s.battle.enemies[0]
	beetle.hp = 3
	beetle.ailment = "poison"
	beetle.ailment_turns = 3
	beetle.ailment_damage = 6
	beetle.binds["arm"] = 3
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "defeated")[0]["kill"], {"turn": 0, "element": null, "ailment": "poison", "binds": ["arm"], "by": "poison"}, "독으로 처치한 기록")
	check(_drops(ev).has("item.intact_pincer"), "온전한 집게 얻음")


func test_r2_kill_moment_drop_moth_needs_element_kill() -> void:
	var s := _game(BEETLE, "moth")
	s.battle.enemies[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
	check_eq(Fx.of_type(ev, "defeated")[0]["kill"]["element"], "fire", "열로 처치")
	check(_drops(ev).has("item.glow_scale"), "발광 인분 얻음")
	s = _game(BEETLE, "moth")
	s.battle.enemies[0].hp = 1
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "defeated")[0]["kill"]["element"], "slash", "베기로 처치")
	check(not _drops(ev).has("item.glow_scale"), "베기로는 못 얻음")


func test_r2_kill_moment_drop_chance_500_depends_on_seed() -> void:
	# 갑충 장갑판(조건 없음, 500): 같은 처치라도 시드에 따라 얻거나 못 얻는다. 아래 두 시드는 이 규칙 코드로 고른 값이다.
	var got := {}
	for seed_value in [SEED_PLATE, SEED_NO_PLATE]:
		var s := _game(BEETLE, "beetle", seed_value)
		s.battle.enemies[0].hp = 1
		var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
		got[seed_value] = _drops(ev).has("item.beetle_plate")
	check_eq(got, {SEED_PLATE: true, SEED_NO_PLATE: false}, "두 시드로 둘 다")

const SEED_PLATE := 3
const SEED_NO_PLATE := 2


const DROP_FX := {"pa": [["enemy.t_plated", "front"]], "pl": [["enemy.t_plain", "front"]], "nd": [[Fx.DUMMY, "front"]]}


## 한 대로 처치한 뒤 [장갑판을 얻었나, 난수 상태].
func _kill_once(formation: String, seed_value: int, arm: bool) -> Array:
	var s := _game(DROP_FX, formation, seed_value)
	var e := s.battle.enemies[0]
	e.hp = 1
	if arm:
		e.binds["arm"] = 2
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	return [_drops(ev).has("item.beetle_plate"), s.rng.get_state()]


func test_r2_kill_moment_drop_conditional_500_rolls_only_when_met() -> void:
	# 조건(팔 봉인 중 처치)이 맞으면 조건 없는 500‰ 드롭과 같은 한 번의 판정, 안 맞으면 판정(난수) 없이 못 얻는다.
	var got := {}
	for seed_value in range(1, 13):
		var met: Array = _kill_once("pa", seed_value, true)
		check_eq(met, _kill_once("pl", seed_value, true), "조건이 맞으면 조건 없는 500‰ 와 같은 결과·난수 (시드 %d)" % seed_value)
		var unmet: Array = _kill_once("pa", seed_value, false)
		check_eq(unmet, [false, _kill_once("nd", seed_value, false)[1]], "조건이 안 맞으면 못 얻고 드롭 난수도 없음 (시드 %d)" % seed_value)
		got[met[0]] = true
	check_eq(got, {true: true, false: true}, "조건이 맞아도 500‰ 라 시드에 따라 얻거나 못 얻음")
