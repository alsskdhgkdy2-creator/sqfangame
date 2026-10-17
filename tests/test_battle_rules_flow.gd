extends TestCase
## 전투 흐름(06 §10.1 「그 밖의 규칙」 앞부분): 순서·취소, 비용·재지정, 피해, 명중, 상태이상·봉인 판정, 턴 끝, 아군 내성.

const Fx := preload("res://tests/fixtures.gd")

const TAP := "skill.enemy.t_tap"
const KILL := "skill.enemy.t_kill"
const KILL_FIRST := "skill.enemy.t_kill_first"
const SMACK := "skill.enemy.t_smack"
const FIRE := "skill.enemy.t_fire"
const ARM_LOCK := "skill.enemy.t_arm_lock"
const CRIT_SMACK := "skill.enemy.t_crit_smack"
const SLEEP_GLYPH := "skill.glyph_wizard.t_sleep_glyph"
const HEAT := "skill.glyph_wizard.heat_glyph"
const REBOOT := "skill.nano_medic.reboot"
const REPAIR := "skill.nano_medic.nano_repair"
const PATCH := "skill.nano_medic.refresh_patch"
const FRONT_GUARD := "skill.holo_knight.front_guard"
const COVER := "skill.holo_knight.aegis_cover"


func _skills() -> Array:
	return [
		Fx.enemy_skill(TAP, "damage", "enemy_one"),
		Fx.enemy_skill(KILL, "damage", "enemy_one", {}, {"power": 2000}),
		Fx.enemy_skill(KILL_FIRST, "damage", "enemy_one", {"priority": "first"}, {"power": 2000}),
		Fx.enemy_skill(SMACK, "damage", "enemy_one", {"range": "melee"}, {"power": 100}),
		Fx.enemy_skill(FIRE, "damage", "enemy_one", {"element": "fire"}, {"power": 100}),
		Fx.enemy_skill(ARM_LOCK, "damage", "enemy_one", {}, {"bind": {"part": "arm", "chance": 1000, "turns": 3}}),
		Fx.enemy_skill(CRIT_SMACK, "damage", "enemy_one", {"can_crit": true}, {"power": 100}),
		Fx.effect_skill("skill.t.b", false, [["phys_atk", 1100, 1]]),
		Fx.effect_skill("skill.enemy.t_d", true, [["phys_def", 1100, 1]]),
	]


func _enemies() -> Array:
	return [
		Fx.enemy("enemy.t_killer", 999, [999, 10, 10, 10, 999, 10], [[{}, [[KILL, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_killer_first", 999, [999, 10, 10, 10, 999, 10], [[{}, [[KILL_FIRST, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_brute", 999, [50, 10, 10, 10, 999, 10], [[{}, [[SMACK, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_burner", 999, [50, 10, 10, 10, 999, 50], [[{}, [[FIRE, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_binder", 999, [10, 10, 10, 10, 999, 50], [[{}, [[ARM_LOCK, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_critter", 999, [50, 10, 10, 10, 999, 10], [[{}, [[CRIT_SMACK, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_quick", 999, [10, 10, 10, 10, 999, 10], [[{}, [[Fx.MEND, 1]]]]),
		Fx.enemy("enemy.t_agile", 999, [10, 10, 10, 10, 999, 10], [[{}, [[Fx.MEND, 1]]]]),
	]


## 시험용 파일: 위저드에 수면 글리프(시험 전용)를 더한다.
func _files(formations: Dictionary, rules: Dictionary = Fx.EXACT) -> Dictionary:
	var files := Fx.battle_files(Fx.test_files(_skills(), _enemies(), formations), rules)
	files["skills/glyph_wizard.json"]["skills"].append({"id": SLEEP_GLYPH, "name_key": SLEEP_GLYPH, "user": "party", "effect": "ailment",
		"range": "ranged", "target": "enemy_one", "parts": [], "priority": "normal", "speed": 1000, "sure_hit": true,
		"levels": [{"tp": 1, "ailment": {"id": "sleep", "chance": 1000, "turns": 2}}]})
	files["classes/glyph_wizard.json"]["skills"].append(SLEEP_GLYPH)
	return files


func _party() -> Dictionary:
	var p := Fx.party_dict()
	p["members"][4]["skills"][SLEEP_GLYPH] = 1
	return p


func _game(formations: Dictionary, name: String, seed_value: int = 1, rules: Dictionary = Fx.EXACT, party: Dictionary = {}) -> ExplorationState:
	return Fx.battle(Fx.defs_from(_files(formations, rules), party if not party.is_empty() else _party()), "formation.t." + name, seed_value)


func _by_unit(events: Array[Dictionary], type: String, side: String, slot: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == type and e.has("unit") and e["unit"]["side"] == side and e["unit"]["slot"] == slot:
			out.append(e)
	return out


func _acting(events: Array[Dictionary]) -> Array:
	return Fx.of_type(events, "action").map(func(e): return [e["unit"]["side"], e["unit"]["slot"]])


# ---- 순서·취소 ----

func test_order_priority_speed_and_ties() -> void:
	var s := _game({"q": [["enemy.t_quick", "front"]]}, "q")
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.use(FRONT_GUARD), 1: Fx.atk(0), 2: Fx.atk(0), 3: Fx.atk(0)}))
	# 우선 first(나이트) → AGI 999 적 → 듀얼리스트 둘(AGI 18 동점은 칸 순) → 메딕(13).
	check_eq(_acting(ev), [["party", 0], ["enemy", 0], ["party", 1], ["party", 2], ["party", 3]], "순서")
	var order := Fx.of_type(ev, "action").map(func(e): return e["order"])
	check_eq(order, [11 * 1000 * 1000, 999 * 1000 * 1000, 18 * 1000 * 1000, 18 * 1000 * 1000, 13 * 1000 * 1000], "S = AGI × speed × roll")
	# 아군과 적이 같은 S 면 아군 먼저.
	var tie := Fx.enemy("enemy.t_tie", 999, [10, 10, 10, 10, 18, 10], [[{}, [[TAP, 1, "lowest_hp"]]]])
	var files := _files({"t": [["enemy.t_tie", "front"]]})
	files["enemies/test.json"]["enemies"].append(tie)
	s = Fx.battle(Fx.defs_from(files, _party()), "formation.t.t")
	ev = BattleRules.submit(s, Fx.cmds(s, {2: Fx.atk(0)}))
	check_eq(_acting(ev), [["party", 2], ["enemy", 0]], "동점은 아군 먼저")


func test_speed_rolls_drawn_party_then_enemies_skipping_guard_and_null() -> void:
	var s := _game({"q": [[Fx.DUMMY, "front"], ["enemy.t_quick", "front"]]}, "q", 7, {"hit_min": 1000, "crit_base": 0, "crit_luck": 0})
	s.party.members[2].hp = 0
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 3: Fx.atk(0)}))
	# 큐: 대원 1, 대원 3, 적 0, 적 1 순으로 뽑는다(대원 0·4 방어, 대원 2 null).
	var want := {}
	want["p1"] = 18 * 1000 * r.randi_range(900, 1100)
	want["p3"] = 13 * 1000 * r.randi_range(900, 1100)
	want["e0"] = 1 * 1000 * r.randi_range(900, 1100)
	want["e1"] = 999 * 1000 * r.randi_range(900, 1100)
	var got := {}
	for e in Fx.of_type(ev, "action"):
		got[("p" if e["unit"]["side"] == "party" else "e") + str(e["unit"]["slot"])] = e["order"]
	check_eq(got, want, "순서 난수를 뽑는 순서")


func test_revived_this_turn_does_not_act() -> void:
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d")
	s.party.members[2].hp = 0
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(REBOOT, 2)}))
	check_eq(Fx.of_type(ev, "revived")[0]["hp"], 13, "max(1, 52 × 250‰) = 13")
	check(_by_unit(ev, "action", "party", 2).is_empty(), "이번 턴 소생한 대원은 행동 안 함")
	check(BattleRules.can_command(s, 2), "다음 턴에는 명령을 받는다")


func test_down_before_turn_cancels_action_without_rng() -> void:
	var s := _game({"k": [["enemy.t_killer", "front"]]}, "k", 11, {})
	s.party.members[1].hp = 1
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check(_by_unit(ev, "action", "party", 1).is_empty() and _by_unit(ev, "failed", "party", 1).is_empty(), "쓰러진 대원은 이벤트 없이 취소")
	# 뽑기: 순서 난수(대원 1, 적) → 적 피해 난수. 취소된 행동은 명중·크리·피해 난수를 뽑지 않는다.
	r.randi_range(900, 1100)
	r.randi_range(900, 1100)
	r.randi_range(950, 1050)
	check_eq(s.rng.get_state(), r.get_state(), "취소된 행동은 난수를 뽑지 않음")


func test_charging_enemy_put_to_sleep_or_killed_loses_charge() -> void:
	var s := _game({"b": [["enemy.clamp_beetle", "front"]]}, "b")
	var beetle := s.battle.enemies[0]
	beetle.charging = "skill.enemy.crush"
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(SLEEP_GLYPH, 0)}))
	check_eq(Fx.of_type(ev, "charge_lost"), [{"type": "charge_lost", "unit": {"side": "enemy", "slot": 0}, "skill": "skill.enemy.crush", "reason": "asleep"}] as Array[Dictionary], "잠들면 준비 풀림")
	check(_by_unit(ev, "action", "enemy", 0).is_empty() and _by_unit(ev, "failed", "enemy", 0).size() == 1, "취소된 압쇄는 failed{asleep}")
	check_eq(beetle.charging, "", "준비 없음")
	var before := s.rng.get_state()
	ev = BattleRules.submit(s, Fx.cmds(s))
	check(_by_unit(ev, "idle", "enemy", 0).is_empty() and _by_unit(ev, "action", "enemy", 0).is_empty(), "수면 적은 고르지 않음")
	check_eq(s.rng.get_state(), before, "수면 적 선택은 난수 없음")
	s = _game({"b": [["enemy.clamp_beetle", "front"]]}, "b")
	s.battle.enemies[0].charging = "skill.enemy.crush"
	s.battle.enemies[0].hp = 1
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "charge_lost")[0]["reason"], "down", "쓰러지면 준비 풀림")


func test_strong_attack_failing_by_bind_or_paralysis_releases_charge() -> void:
	var s := _game({"b": [["enemy.clamp_beetle", "front"]]}, "b", 1, {"paralysis_fail": 1000, "damage_roll": [1000, 1000], "speed_roll": [1000, 1000], "hit_min": 1000})
	var beetle := s.battle.enemies[0]
	beetle.charging = "skill.enemy.crush"
	beetle.ailment = "paralysis"
	beetle.ailment_turns = 3
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(_by_unit(ev, "failed", "enemy", 0)[0]["reason"], "paralysis", "마비로 실패")
	check_eq(_by_unit(ev, "charge_lost", "enemy", 0)[0]["reason"], "paralysis", "준비 풀림")
	check_eq(beetle.charging, "", "준비 없음")
	s = _game({"b": [["enemy.clamp_beetle", "front"]]}, "b")
	beetle = s.battle.enemies[0]
	beetle.charging = "skill.enemy.crush"
	beetle.binds["arm"] = 2
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq(_by_unit(ev, "failed", "enemy", 0)[0]["reason"], "bound_arm", "팔 봉인으로 실패(on_bound fail)")
	check_eq(beetle.charging, "", "준비 풀림")


# ---- 비용·재지정 ----

func test_dead_target_retargets_same_row_smallest_slot() -> void:
	var s := _game({"r": [[Fx.DUMMY, "front"], [Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "r")
	s.battle.enemies[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: Fx.atk(0)}))
	check_eq(_by_unit(ev, "action", "party", 2)[0]["targets"], [{"side": "enemy", "slot": 1}], "같은 열의 작은 칸")
	s = _game({"r": [[Fx.DUMMY, "front"], [Fx.DUMMY, "front"], [Fx.DUMMY, "back"]], "r2": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "r2")
	s.battle.enemies[0].hp = 1
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: Fx.atk(0)}))
	check_eq(_by_unit(ev, "action", "party", 2)[0]["targets"], [{"side": "enemy", "slot": 1}], "같은 열이 없으면 남은 유효 대상")


func test_heal_retargets_lowest_ratio_when_target_falls() -> void:
	var s := _game({"k": [["enemy.t_killer", "front"]]}, "k")
	s.party.members[0].hp = 1
	s.party.members[2].hp = 26
	s.party.members[4].hp = 30
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(REPAIR, 0)}))
	var h := Fx.of_type(ev, "healed")
	check_eq(h[0]["target"], {"side": "party", "slot": 2}, "HP 비율이 가장 낮은 대원(26/52)")
	check_eq(h[0]["amount"], 26, "15 + 20 = 35 를 최대 HP 로 자름")
	check_eq(s.party.members[2].hp, 52, "가득")


func test_cure_target_fallen_is_no_target_and_keeps_tp() -> void:
	var s := _game({"k": [["enemy.t_killer_first", "front"]]}, "k")
	s.party.members[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(PATCH, 0)}))
	check_eq(_by_unit(ev, "failed", "party", 3)[0]["reason"], "no_target", "해제 대상이 쓰러졌으면 no_target")
	check_eq(s.battle.party[3].tp, 54, "TP 그대로")


func test_revive_target_alive_fails_without_retarget() -> void:
	var p := _party()
	p["members"][4] = {"id": "nano_medic_2", "name_key": "member.nano_medic", "class": "class.nano_medic", "level": 1, "row": "back",
		"skills": {REPAIR: 1, PATCH: 1, REBOOT: 1}, "gear": {"atk": 6, "matk": 6, "def": 5, "mdef": 5}}
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d", 1, Fx.EXACT, p)
	s.party.members[2].hp = 0
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(REBOOT, 2), 4: Fx.use(REBOOT, 2)}))
	check_eq(Fx.of_type(ev, "revived").size(), 1, "한 번만 살림")
	check_eq(_by_unit(ev, "failed", "party", 4)[0]["reason"], "no_target", "이미 살아 있으면 no_target")
	check_eq(s.battle.party[4].tp, 54, "실패하면 TP 안 냄")
	check_eq(s.battle.party[3].tp, 44, "성공한 쪽은 10")


# ---- 피해 ----

func test_immune_target_draws_nothing() -> void:
	var files := _files({"i": [["enemy.t_ghost", "front"]]}, {})
	var ghost := Fx.enemy("enemy.t_ghost", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	ghost["resist"]["slash"] = 0
	files["enemies/test.json"]["enemies"].append(ghost)
	var s := Fx.battle(Fx.defs_from(files, _party()), "formation.t.i", 4)
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	var d := Fx.of_type(ev, "damaged")[0]
	check_eq([d["amount"], d["lost"], d["immune"], d["calc"]], [0, 0, true, {}], "무효 0")
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["amount", "calc", "crit", "element", "hp", "immune", "lost", "skill", "target", "type", "unit", "weak"], "보통 피해 이벤트와 같은 키")
	r.randi_range(900, 1100)
	r.randi_range(900, 1100)
	check_eq(s.rng.get_state(), r.get_state(), "명중·크리·피해 난수를 뽑지 않음(순서 난수 둘만)")
	check_eq(s.battle.enemies[0].hp, 999, "HP 그대로")


func test_weak_and_resist_multipliers() -> void:
	var files := _files({"w": [["enemy.t_weak", "front"], ["enemy.t_hard", "front"]]})
	var weak := Fx.enemy("enemy.t_weak", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	weak["resist"]["fire"] = 1500
	var hard := Fx.enemy("enemy.t_hard", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	hard["resist"]["fire"] = 500
	files["enemies/test.json"]["enemies"].append_array([weak, hard])
	var s := Fx.battle(Fx.defs_from(files, _party()), "formation.t.w")
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
	var d := Fx.of_type(ev, "damaged")[0]
	check_eq([d["calc"]["base"], d["calc"]["element"], d["weak"]], [32, 48, true], "약점 ×1500")
	ev = BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 1)}))
	d = Fx.of_type(ev, "damaged")[0]
	check_eq([d["calc"]["element"], d["weak"]], [16, false], "내성 ×500")


func test_guard_halves_from_turn_start_even_against_faster_enemy() -> void:
	# 적 A = STR 50, 듀얼리스트 D = 13 + 6 = 19: 50²×100/(100×69) = 36 → 방어 18.
	var s := _game({"b": [["enemy.t_brute", "front"]]}, "b")
	s.party.members[1].hp = 40
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var c: Dictionary = Fx.of_type(ev, "damaged")[0]["calc"]
	check_eq([c["base"], c["def_mul"], c["guard"], c["final"]], [36, 36, 18, 18], "더 빠른 적에게도 방어")
	check_eq(s.party.members[1].hp, 22, "40 − 18")
	check(not s.battle.party[1].guarding, "턴 끝에 지움")


func test_front_guard_covers_effective_front_row_physical() -> void:
	var s := _game({"b": [["enemy.t_brute", "front"]]}, "b")
	s.party.members[1].hp = 40
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.use(FRONT_GUARD), 1: Fx.atk(0)}))
	var c: Dictionary = Fx.of_type(ev, "damaged").filter(func(e): return e["target"]["side"] == "party")[0]["calc"]
	check_eq([c["guard"], c["front_guard"]], [36, 21], "전열 물리 피해 ×600")
	check(s.battle.front_guard.is_empty(), "턴 끝에 지움")
	s = _game({"b": [["enemy.t_brute", "front"]]}, "b")
	s.party.members[4].hp = 30
	ev = BattleRules.submit(s, Fx.cmds(s, {0: Fx.use(FRONT_GUARD)}))
	c = Fx.of_type(ev, "damaged").filter(func(e): return e["target"]["side"] == "party")[0]["calc"]
	check_eq(c["front_guard"], c["guard"], "후열은 덮지 않음")


func test_aegis_cover_redirects_single_physical_attack() -> void:
	var s := _game({"b": [["enemy.t_brute", "front"]]}, "b")
	s.party.members[1].hp = 10
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.use(COVER, 1), 1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "covered"), [{"type": "covered", "unit": {"side": "party", "slot": 0}, "target": {"side": "party", "slot": 1}}] as Array[Dictionary], "커버")
	var d: Dictionary = Fx.of_type(ev, "damaged").filter(func(e): return e["target"]["side"] == "party")[0]
	check_eq(d["target"], {"side": "party", "slot": 0}, "나이트가 받음")
	check_eq(d["calc"]["D"], 29, "나이트 기준 방어(19 + 10)")
	check_eq(s.party.members[1].hp, 10, "보호받은 대원 HP 그대로")
	check_eq(s.party.members[0].hp, 60 - d["amount"], "나이트 HP")


const CROSS := "skill.blade_duelist.cross_sweep"
const ROWS3 := {"r3": [[Fx.DUMMY, "front"], [Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}


func _sweep_hits(ev: Array[Dictionary]) -> Array:
	return _by_unit(ev, "damaged", "party", 1).map(func(e): return e["target"]["slot"])


func test_row_skill_hits_the_whole_effective_row() -> void:
	var s := _game(ROWS3, "r3")
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(CROSS, 1)}))
	check_eq(_sweep_hits(ev), [0, 1], "고른 대상의 줄(전열) 전체, 칸 순")
	check_eq(s.battle.party[1].tp, 32 - 6, "비용은 한 번")
	check(_by_unit(ev, "damaged", "party", 1).all(func(e): return e["calc"]["row"] == e["calc"]["element"]), "전열 근접 → 전열 보정 없음")


func test_row_skill_retargets_when_row_changes() -> void:
	# 위저드(AGI 999)가 먼저 대상을 쓰러뜨린 뒤 듀얼리스트의 크로스 스윕이 실행된다.
	var s := _game(ROWS3, "r3")
	s.battle.party[4].stats["AGI"] = 999
	s.battle.enemies[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(CROSS, 0), 4: Fx.use(HEAT, 0)}))
	check_eq(_sweep_hits(ev), [1], "고른 대상이 쓰러져도 그 줄의 남은 적만")
	s = _game(ROWS3, "r3")
	s.battle.party[4].stats["AGI"] = 999
	s.battle.enemies[2].hp = 1
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(CROSS, 2), 4: Fx.use(HEAT, 2)}))
	check_eq(_sweep_hits(ev), [0, 1], "고른 줄(후열)이 비면 다른 줄")
	check(Fx.of_type(ev, "failed").is_empty(), "no_target 아님")


func test_crit_multiplies_after_guard() -> void:
	var exact := {"crit_base": 1000, "crit_max": 1000, "damage_roll": [1000, 1000], "speed_roll": [1000, 1000], "hit_min": 1000}
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d", 1, exact)
	var d := Fx.of_type(BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)})), "damaged")[0]
	check_eq([d["crit"], d["calc"]["guard"], d["calc"]["front_guard"], d["calc"]["crit"]], [true, 25, 25, 37], "방어 없음: 크리티컬 ×1500")
	# 모두 방어한 파티를 크리티컬이 확정인 적이 친다: 방어 ×500 다음에 크리티컬 ×1500.
	s = _game({"c": [["enemy.t_critter", "front"]]}, "c", 1, exact)
	var ev := BattleRules.submit(s, Fx.cmds(s))
	d = _by_unit(ev, "damaged", "enemy", 0)[0]
	var c: Dictionary = d["calc"]
	check_eq([Fx.of_type(ev, "guarding").size(), d["target"]["side"]], [5, "party"], "대원 다섯 모두 방어 중에 맞음")
	check_eq([d["crit"], c["guard"], c["front_guard"], c["crit"]],
		[true, BattleCalc.mul(c["def_mul"], 500), c["guard"], BattleCalc.mul(c["guard"], 1500)], "방어 → (전열 방어 없음) → 크리티컬 순")
	check(c["guard"] < c["def_mul"], "방어가 실제로 줄임: %s" % str(c))


# ---- 명중 ----

func test_sleeping_target_is_hit_without_draw() -> void:
	var s := _game({"a": [["enemy.t_agile", "front"]]}, "a", 9, {})
	s.battle.enemies[0].ailment = "sleep"
	s.battle.enemies[0].ailment_turns = 2
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	var d := Fx.of_type(ev, "damaged")[0]
	check(not d["calc"].has("hit_p"), "명중 판정 없음")
	check(Fx.of_type(ev, "woke").size() == 1, "피해로 깸")
	# 뽑기: 순서 난수(대원 1) → 크리티컬 → 피해 난수. 수면 적은 행동을 고르지 않는다.
	r.randi_range(900, 1100)
	r.randi_range(0, 999)
	r.randi_range(950, 1050)
	check_eq(s.rng.get_state(), r.get_state(), "명중 난수를 뽑지 않음")


func test_hit_roll_against_agile_target_and_leg_bind() -> void:
	var s := _game({"a": [["enemy.t_agile", "front"]]}, "a", 9, {})
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	var hit := Fx.of_type(ev, "damaged") + Fx.of_type(ev, "missed")
	var p: int = hit[0]["calc"]["hit_p"] if hit[0]["type"] == "damaged" else hit[0]["hit_p"]
	check_eq(p, 300, "AGI 18 → 999: 하한 300")
	s = _game({"a": [["enemy.t_agile", "front"]]}, "a", 9, {})
	s.battle.enemies[0].binds["leg"] = 3
	ev = BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	hit = Fx.of_type(ev, "damaged") + Fx.of_type(ev, "missed")
	p = hit[0]["calc"]["hit_p"] if hit[0]["type"] == "damaged" else hit[0]["hit_p"]
	check_eq(p, BattleCalc.hit_p(s.defs.battle.rules, 950, 18, 499), "다리 봉인: 회피 AGI 499")


# ---- 상태이상·봉인 판정 ----

func test_status_durations_and_release_timing() -> void:
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d")
	var u := s.battle.party[1]
	var ev: Array[Dictionary] = []
	var lucky := s.battle.enemies[0]
	lucky.stats = {"STR": 10, "INT": 10, "VIT": 10, "WIS": 10, "AGI": 1, "LUC": 99}
	BattleEffects.apply_ailment(s.battle, s.defs.battle.rules, s.rng, lucky, u, {"id": "paralysis", "chance": 1000, "turns": 3}, ev)
	BattleEffects.apply_bind(s.defs.battle.rules, s.rng, lucky, u, {"part": "leg", "chance": 1000, "turns": 2}, ev)
	var seen := []
	for t in 3:
		BattleRules.submit(s, Fx.cmds(s))
		seen.append([u.ailment, u.ailment_turns, u.binds.get("leg", 0)])
	check_eq(seen, [["paralysis", 2, 1], ["paralysis", 1, 0], ["", 0, 0]], "걸린 턴 끝 2 → 1 → 풀림, 봉인 2 → 1 → 풀림")


func test_resist_gain_cap_and_decay() -> void:
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d", 1, {"status_luck": 100, "status_luck_clamp": [500, 3000], "damage_roll": [1000, 1000], "speed_roll": [1000, 1000], "hit_min": 1000})
	var u := s.battle.party[1]
	var lucky := s.battle.enemies[0]
	lucky.stats = {"STR": 10, "INT": 10, "VIT": 10, "WIS": 10, "AGI": 1, "LUC": 99}
	var r := s.defs.battle.rules
	var ev: Array[Dictionary] = []
	var spec := {"id": "poison", "chance": 1000, "turns": 3, "damage": 1}
	BattleEffects.apply_ailment(s.battle, r, s.rng, lucky, u, spec, ev)
	check_eq(u.resist_acc.get("poison"), 300, "걸리면 +300")
	BattleEffects.apply_ailment(s.battle, r, s.rng, lucky, u, spec, ev)
	BattleEffects.apply_ailment(s.battle, r, s.rng, lucky, u, spec, ev)
	check_eq(u.resist_acc.get("poison"), 900, "최대 900")
	check_eq(ev[-1]["p"], 1000, "확률은 mul(3000, 400) = 1200 → 1000")
	var probe := BattleUnit.new()
	probe.resist_acc["sleep"] = 850
	BattleEffects._gain_resist(probe, "sleep", r)
	check_eq(probe.resist_acc["sleep"], 900, "850 + 300 → 900 에서 멈춤")
	u.resist_acc["arm"] = 150
	BattleRules.submit(s, Fx.cmds(s))
	check_eq([u.resist_acc.get("poison"), u.resist_acc.get("arm")], [900, 50], "걸려 있으면 그대로, 아니면 −100")
	BattleRules.submit(s, Fx.cmds(s))
	check(not u.resist_acc.has("arm"), "0 이 되면 키를 지움")


func test_zero_vulnerability_means_zero_chance_without_draw() -> void:
	var files := _files({"b": [["enemy.t_binder", "front"]]})
	files["classes/blade_duelist.json"]["bind_vuln"]["arm"] = 0
	files["classes/blade_duelist.json"]["ailment_vuln"]["poison"] = 0
	var s := Fx.battle(Fx.defs_from(files, _party()), "formation.t.b")
	s.party.members[1].hp = 10
	var before := s.rng.get_state()
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "bind_resisted")[0]["p"], 0, "취약도 0 → 0")
	check(s.battle.party[1].binds.is_empty(), "걸리지 않음")
	check_eq(s.rng.get_state(), before, "뽑지 않음")
	var e: Array[Dictionary] = []
	BattleEffects.apply_ailment(s.battle, s.defs.battle.rules, s.rng, s.battle.enemies[0], s.battle.party[1], {"id": "poison", "chance": 1000, "turns": 3, "damage": 1}, e)
	check_eq([e[0]["type"], e[0]["p"], s.rng.get_state()], ["ailment_resisted", 0, before], "아군 ailment_vuln 도 쓰임")


func test_ally_class_resist_scales_damage_taken() -> void:
	var files := _files({"f": [["enemy.t_burner", "front"]]})
	files["classes/blade_duelist.json"]["resist"]["fire"] = 1500
	var s := Fx.battle(Fx.defs_from(files, _party()), "formation.t.f")
	s.party.members[1].hp = 40
	var c: Dictionary = Fx.of_type(BattleRules.submit(s, Fx.cmds(s)), "damaged")[0]["calc"]
	# A 50, D = VIT 13 + def 6 = 19 → 36, 열 1500 → 54, 방어 → 27.
	check_eq([c["base"], c["element"], c["guard"]], [36, 54, 27], "직업 resist 가 아군이 받는 피해에")


# ---- 턴 끝 ----

func test_turn_end_order() -> void:
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d")
	var u := s.battle.party[1]
	u.ailment = "poison"
	u.ailment_turns = 1
	u.ailment_damage = 4
	u.binds["head"] = 1
	Fx.apply_effect(s, u, "skill.t.b")
	Fx.apply_effect(s, u, "skill.enemy.t_d")
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.use(FRONT_GUARD)}))
	var tail := ev.slice(Fx.types(ev).find("turn_end"))
	check_eq(tail.map(func(e): return e["type"] + ":" + str(e.get("what", ""))),
		["turn_end:", "poison_tick:", "expired:ailment", "expired:bind", "expired:buff", "expired:debuff"], "독 → 상태 → 봉인 → 강화 → 약화")
	check_eq(s.party.members[1].hp, 48, "독 4")
	check(s.battle.front_guard.is_empty() and not s.battle.party[1].guarding and not s.battle.party[2].guarding, "턴 한정 효과 지움")
	check_eq(s.battle.turn, 1, "turn + 1")


func test_poison_double_down_is_wipe() -> void:
	var s := _game({"d": [[Fx.DUMMY, "front"]]}, "d")
	for i in 4:
		s.party.members[i].hp = 0
	s.party.members[4].hp = 3
	for u in [s.battle.party[4], s.battle.enemies[0]]:
		u.ailment = "poison"
		u.ailment_turns = 3
		u.ailment_damage = 9999
	s.battle.enemies[0].hp = 5
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var end := Fx.of_type(ev, "battle_end")[0]
	check_eq([end["outcome"], end["enemy_hp"]], ["wiped", [0] as Array[int]], "양쪽이 같이 쓰러지면 전멸")
	check(s.wiped and s.battle == null and not s.encounter.pending and s.encounter.danger == 0, "전멸 처리")
