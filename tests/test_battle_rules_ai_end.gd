extends TestCase
## 전투 흐름(06 §10.1 「그 밖의 규칙」 뒷부분): 적 AI, 도주, 끝·finish 계약, 제출 거부, 결정성.

const Fx := preload("res://tests/fixtures.gd")

const TAP := "skill.enemy.t_tap"
const HEAD_HIT := "skill.enemy.t_head_hit"
## 다른 아군 회복: 적 하나뿐인 편성에서는 유효 대상이 없다.
const MEND_OTHER := "skill.enemy.t_mend_other"
const SPORES := "skill.enemy.sleep_spores"
const HIGH_SLASH := "skill.blade_duelist.high_slash"


func _skills() -> Array:
	return [
		Fx.enemy_skill(TAP, "damage", "enemy_one"),
		Fx.enemy_skill(HEAD_HIT, "damage", "enemy_one", {"parts": ["head"]}),
		Fx.enemy_skill(MEND_OTHER, "heal", "ally_other", {}, {"base": 10, "wis_pct": 0}),
	]


func _enemies() -> Array:
	return [
		Fx.enemy("enemy.t_hp", 1000, [10, 10, 10, 10, 1, 10], [[{"hp_below": 500}, [[TAP, 1, "lowest_hp"]]], [{}, [[Fx.MEND, 1]]]]),
		Fx.enemy("enemy.t_weighted", 999, [10, 10, 10, 10, 1, 10], [[{}, [[TAP, 2, "lowest_hp"], [HEAD_HIT, 3, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_random", 999, [10, 10, 10, 10, 1, 10], [[{}, [[TAP, 1, "random"]]]]),
		Fx.enemy("enemy.t_fallback", 999, [10, 10, 10, 10, 1, 10], [[{"turn_mod": [1, 0]}, [[MEND_OTHER, 1]]], [{}, [[TAP, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_mender", 999, [10, 10, 10, 10, 1, 10], [[{}, [[MEND_OTHER, 1]]]]),
		Fx.enemy("enemy.t_tie", 999, [10, 10, 10, 10, 18, 10], [[{}, [[TAP, 1, "lowest_hp"]]]]),
		Fx.enemy("enemy.t_dropper", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]], {"drops": [{"item": "item.neon_rat_tail", "chance": 1000}]}),
	]


func _defs(formations: Dictionary, rules: Dictionary = Fx.EXACT) -> GameDefs:
	return Fx.battle_defs(Fx.test_files(_skills(), _enemies(), formations), rules)


func _game(formations: Dictionary, name: String, seed_value: int = 1, rules: Dictionary = Fx.EXACT) -> ExplorationState:
	return Fx.battle(_defs(formations, rules), "formation.t." + name, seed_value)


# ---- 적 AI ----

func test_ai_rule_order_and_turn_mod() -> void:
	var s := _game({"b": [["enemy.clamp_beetle", "front"]]}, "b")
	var beetle := s.battle.enemies[0]
	var ev: Array[Dictionary] = []
	s.battle.turn = 2
	var before := s.rng.get_state()
	var c: Variant = EnemyAi.choose(s, beetle, ev)
	check_eq(c["skill"].id, "skill.enemy.raise_pincers", "turn_mod [3, 2] 규칙")
	check_eq([c["target"], s.rng.get_state()], [-1, before], "후보 하나·자기 대상은 뽑지 않음")
	beetle.charging = "skill.enemy.crush"
	c = EnemyAi.choose(s, beetle, ev)
	check_eq(c["skill"].id, "skill.enemy.crush", "charging 규칙이 먼저")
	beetle.charging = ""
	s.battle.turn = 0
	c = EnemyAi.choose(s, beetle, ev)
	check(c["skill"].id in ["skill.enemy.pinch", "skill.enemy.claw"], "조건 없는 마지막 규칙")


func test_ai_hp_below() -> void:
	var s := _game({"h": [["enemy.t_hp", "front"]]}, "h")
	var u := s.battle.enemies[0]
	var ev: Array[Dictionary] = []
	check_eq(EnemyAi.choose(s, u, ev)["skill"].id, Fx.MEND, "HP 가득")
	u.hp = 500
	check_eq(EnemyAi.choose(s, u, ev)["skill"].id, Fx.MEND, "500‰ 은 미만이 아님")
	u.hp = 499
	check_eq(EnemyAi.choose(s, u, ev)["skill"].id, TAP, "499 × 1000 < 500 × 1000")


func test_ai_weighted_pick_uses_one_draw() -> void:
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var s := _game({"w": [["enemy.t_weighted", "front"]]}, "w", seed_value)
		var r := GameRng.new(1)
		r.set_state(s.rng.get_state())
		var raw := r.randi_range(0, 4)
		var ev: Array[Dictionary] = []
		var c: Variant = EnemyAi.choose(s, s.battle.enemies[0], ev)
		check_eq(c["skill"].id, TAP if raw < 2 else HEAD_HIT, "가중치 [2, 3] (시드 %d)" % seed_value)
		check_eq(s.rng.get_state(), r.get_state(), "가중치 한 번, lowest_hp 는 뽑지 않음")
		check_eq(c["target"], 4, "HP 가 가장 낮은 위저드(40)")


func test_ai_target_policies() -> void:
	var s := _game({"r": [["enemy.t_random", "front"]]}, "r", 8)
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev: Array[Dictionary] = []
	check_eq(EnemyAi.choose(s, s.battle.enemies[0], ev)["target"], r.randi_range(0, 4), "random: 칸 오름차순 후보에서 pick(5)")
	check_eq(s.rng.get_state(), r.get_state(), "뽑기 한 번")
	s.party.members[0].hp = 0
	s.party.members[1].hp = 0
	s.party.members[2].hp = 0
	s.party.members[3].hp = 0
	var before := s.rng.get_state()
	check_eq(EnemyAi.choose(s, s.battle.enemies[0], ev)["target"], 4, "대상 하나")
	check_eq(s.rng.get_state(), before, "대상 하나면 뽑지 않음")
	# 줄 대상(절전 포자): 후보 줄 [전열, 후열] 에서 pick(2), 그 줄의 가장 작은 칸.
	s = Fx.battle(Fx.battle_defs(), "formation.f1.mole_rat_bloom", 3)
	r.set_state(s.rng.get_state())
	var bloom := s.battle.enemies[2]
	var row := r.randi_range(0, 1)
	var c: Variant = null
	var skill := s.defs.battle.skill(SPORES)
	c = EnemyAi.choose_target(s, bloom, skill, "random")
	check_eq(c, 0 if row == 0 else 3, "줄 대상 후보 순서 전열 → 후열")
	check_eq(EnemyAi.choose_target(s, bloom, s.defs.battle.skill("skill.enemy.rending_howl"), "random"), -1, "전체 대상은 고르지 않음")


func test_ai_dead_or_sleeping_enemy_does_not_choose() -> void:
	var s := _game({"r": [["enemy.t_random", "front"], ["enemy.t_random", "front"]]}, "r", 8)
	s.battle.enemies[0].hp = 0
	s.battle.enemies[1].ailment = "sleep"
	s.battle.enemies[1].ailment_turns = 2
	var before := s.rng.get_state()
	var ev: Array[Dictionary] = []
	check_eq(EnemyAi.choose_all(s, ev), [null, null], "고르지 않음")
	check_eq([ev, s.rng.get_state()], [[] as Array[Dictionary], before], "이벤트·난수 없음")


func test_ai_skips_candidates_without_target_then_idles() -> void:
	var s := _game({"f": [["enemy.t_fallback", "front"]], "i": [["enemy.t_mender", "front"]]}, "f")
	var ev: Array[Dictionary] = []
	check_eq(EnemyAi.choose(s, s.battle.enemies[0], ev)["skill"].id, TAP, "유효 대상 없는 후보를 빼고 다음 규칙")
	s = _game({"f": [["enemy.t_fallback", "front"]], "i": [["enemy.t_mender", "front"]]}, "i")
	var before := s.rng.get_state()
	var out := BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(out, "idle"), [{"type": "idle", "unit": {"side": "enemy", "slot": 0}}] as Array[Dictionary], "모두 빠지면 idle")
	check(Fx.of_type(out, "action").is_empty(), "큐에 넣지 않음")
	check_eq(s.rng.get_state(), before, "idle 은 순서 난수도 뽑지 않음")


func test_ai_charge_then_strong_attack_next_turn() -> void:
	var s := _game({"b": [["enemy.clamp_beetle", "front"]]}, "b")
	s.battle.turn = 2
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "charging"), [{"type": "charging", "unit": {"side": "enemy", "slot": 0}, "skill": "skill.enemy.crush"}] as Array[Dictionary], "준비")
	check_eq(s.battle.enemies[0].charging, "skill.enemy.crush", "예고 상태")
	ev = BattleRules.submit(s, Fx.cmds(s))
	var act := Fx.of_type(ev, "action").filter(func(e): return e["unit"]["side"] == "enemy")
	check_eq(act[0]["skill"], "skill.enemy.crush", "다음 턴 강공격")
	check_eq(s.battle.enemies[0].charging, "", "실행하면 풀림")
	check(Fx.of_type(ev, "charge_lost").is_empty(), "실행은 charge_lost 가 아니다")


# ---- 도주 ----

func test_escape_rules() -> void:
	var f := {"r": [["enemy.neon_rat", "front"], ["enemy.neon_rat", "front"]], "t": [["enemy.t_tie", "front"]]}
	var s := _game(f, "r", 1, {"escape_clamp": [1000, 1000], "damage_roll": [1000, 1000], "speed_roll": [1000, 1000], "hit_min": 1000, "crit_base": 0, "crit_luck": 0})
	s.battle.enemies[0].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: {"kind": "escape"}}))
	var end := Fx.of_type(ev, "battle_end")[0]
	check_eq([end["outcome"], end["drops"]], ["escaped", []], "성공 시 드롭 없음(처치한 적이 있어도)")
	check(s.materials.is_empty() and s.encounter.danger == 0 and not s.encounter.pending and s.battle == null, "위험도 0, 전투 끝")
	# 순서: normal·속도 1000, AGI 가 같은 적의 일반 행동과 동점이면 아군 먼저 → 적은 행동하지 못한다.
	s = _game(f, "t", 1, {"escape_clamp": [1000, 1000], "speed_roll": [1000, 1000]})
	ev = BattleRules.submit(s, Fx.cmds(s, {1: {"kind": "escape"}}))
	check(Fx.of_type(ev, "action").filter(func(e): return e["unit"]["side"] == "enemy").is_empty(), "동점은 아군 먼저")
	# 실패: 그 대원의 행동만 끝난다.
	s = _game(f, "t", 1, {"escape_clamp": [0, 0], "speed_roll": [1000, 1000]})
	ev = BattleRules.submit(s, Fx.cmds(s, {1: {"kind": "escape"}}))
	check_eq(Fx.of_type(ev, "escape_failed")[0]["p"], 0, "실패")
	check(s.battle != null, "전투 계속")
	# 거부: 다리 봉인, no_escape.
	s.battle.party[1].binds["leg"] = 2
	check_eq(BattleRules.submit(s, Fx.cmds(s, {1: {"kind": "escape"}}))[0]["reason"], "bound_leg", "다리 봉인 거부")
	check_eq(BattleRules.escape_block_reason(s, 1), "bound_leg", "읽기 도우미")
	s.battle.no_escape = true
	check_eq(BattleRules.submit(s, Fx.cmds(s, {2: {"kind": "escape"}}))[0]["reason"], "no_escape", "no_escape 거부")


func test_escape_probability_uses_living_averages() -> void:
	var s := _game({"t": [["enemy.t_tie", "front"]]}, "t", 1, {"speed_roll": [1000, 1000]})
	# 아군 평균 AGI (11 + 18 + 18 + 13 + 12) / 5 = 14, 적 18 → 600 + (14 − 18) × 20 = 520.
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: {"kind": "escape"}}))
	var e := Fx.of_type(ev, "escaped") + Fx.of_type(ev, "escape_failed")
	check_eq(e[0]["p"], 520, "생존자 평균")


# ---- 끝 ----

func test_victory_discards_queue_and_keeps_hp_tp() -> void:
	var s := _game({"t": [["enemy.t_tie", "front"]]}, "t")
	s.battle.enemies[0].hp = 1
	s.party.members[3].hp = 20
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(HIGH_SLASH, 0)}))
	check(Fx.of_type(ev, "action").filter(func(e): return e["unit"]["side"] == "enemy").is_empty(), "승리 즉시 남은 큐 버림")
	check_eq(Fx.types(ev).slice(-1), ["battle_end"] as Array[String], "턴 끝 처리 없이 끝")
	var end := Fx.of_type(ev, "battle_end")[0]
	check_eq([end["outcome"], end["turn"], end["enemy_hp"]], ["victory", 0, [0] as Array[int]], "끝 이벤트(지우기 전 복사)")
	check_eq([s.party.members[1].tp, s.party.members[3].hp], [28, 20], "HP·TP 는 탐색 파티에 남음")
	check(s.battle == null and s.encounter.danger == 0 and not s.encounter.pending, "위험도 0, 전투 버림")
	check(s.encounter.threshold >= s.floor_def.threshold_min and s.encounter.threshold <= s.floor_def.threshold_max, "한계값 새로 뽑음")


func test_wipe_handling() -> void:
	var s := _game({"t": [["enemy.t_tie", "front"]]}, "t")
	for i in 5:
		s.party.members[i].hp = 1 if i == 4 else 0
	s.encounter.danger = 77
	var threshold := s.encounter.threshold
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(Fx.of_type(ev, "battle_end")[0]["outcome"], "wiped", "전멸")
	check(s.wiped and s.battle == null and not s.encounter.pending and s.encounter.danger == 0, "wiped·위험도 0·pending 거짓")
	check_eq([s.encounter.threshold, s.rng.get_state()], [threshold, r.get_state()], "한계값은 뽑지 않음(이 턴 난수 없음)")


func test_finish_contract() -> void:
	var s := _game({"t": [["enemy.t_tie", "front"]]}, "t")
	var h := Fx.battle_hash(s)
	for bad in ["draw", "", "VICTORY"]:
		check(not BattleRules.finish(s, bad), "모르는 outcome %s" % bad)
	check(not BattleRules.finish(s, "wiped"), "대원이 살아 있는데 wiped")
	s.encounter.pending = false
	check(not BattleRules.finish(s, "victory"), "pending 거짓")
	s.encounter.pending = true
	s.wiped = true
	check(not BattleRules.finish(s, "victory"), "wiped")
	s.wiped = false
	check_eq(Fx.battle_hash(s), h, "거부는 상태·난수 불변")
	# 강제 승리: 처치 기록이 없으면 드롭을 굴리지 않고 한계값 한 번만.
	var r := GameRng.new(1)
	r.set_state(s.rng.get_state())
	var ev: Array[Dictionary] = []
	check(BattleRules.finish(s, "victory", ev), "강제 승리")
	r.randi_range(s.floor_def.threshold_min, s.floor_def.threshold_max)
	check_eq(s.rng.get_state(), r.get_state(), "난수는 한계값 한 번")
	check_eq(Fx.types(ev), ["battle_end"] as Array[String], "이벤트 배열 인자로 끝 이벤트를 받는다")
	h = Fx.battle_hash(s)
	check(not BattleRules.finish(s, "victory"), "두 번째 finish 거부(전투 없음)")
	check_eq(Fx.battle_hash(s), h, "두 번째도 불변")
	check_eq(BattleRules.submit(s, []), [{"type": "rejected", "reason": "no_battle"}] as Array[Dictionary], "전투 없으면 submit 거부")


func test_material_cap_saturates() -> void:
	var s := _game({"d": [["enemy.t_dropper", "front"], ["enemy.t_dropper", "front"]]}, "d")
	s.materials["item.neon_rat_tail"] = 9998
	s.battle.enemies[0].hp = 1
	s.battle.enemies[1].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: Fx.atk(1)}))
	var d := Fx.of_type(ev, "drop")
	check_eq(d.map(func(e): return [e["amount"], e["capped"]]), [[1, false], [0, true]], "9998 → 9999, 넘친 수는 버리고 capped")
	check_eq(s.materials["item.neon_rat_tail"], 9999, "상한 9999")
	check_eq(Fx.of_type(ev, "battle_end")[0]["drops"].size(), 2, "끝 이벤트에도 드롭")


# ---- 제출 거부 ----

func test_submit_rejections_keep_state() -> void:
	var s := _game({"fb": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "fb")
	s.party.members[2].hp = 0
	var h := Fx.battle_hash(s)
	var ok := Fx.cmds(s)
	var cases := {
		"length": ok.slice(0, 4),
		"missing_command": _with(ok, 0, null),
		"not_commandable": _with(ok, 2, Fx.GUARD),
		"unknown_command": _with(ok, 0, {"kind": "dance"}),
		"unknown_skill": _with(ok, 0, Fx.use(HIGH_SLASH, 0)),
		"invalid_target": _with(ok, 3, Fx.atk(1)),
	}
	for reason in cases:
		var ev := BattleRules.submit(s, cases[reason])
		check_eq([ev.size(), ev[0]["type"], ev[0]["reason"]], [1, "rejected", reason], reason)
	check_eq(BattleRules.submit(s, _with(ok, 0, {"kind": "guard", "extra": 1}))[0]["reason"], "unknown_command", "모르는 키")
	check_eq(BattleRules.submit(s, _with(ok, 1, Fx.atk(7)))[0]["reason"], "invalid_target", "없는 칸")
	check_eq(BattleRules.submit(s, _with(ok, 1, {"kind": "skill", "skill": HIGH_SLASH}))[0]["reason"], "invalid_target", "단일 대상 빠짐")
	s.party.members[1].tp = 3
	check_eq(BattleRules.submit(s, _with(ok, 1, Fx.use(HIGH_SLASH, 0)))[0]["reason"], "no_tp", "TP 부족")
	check_eq(BattleRules.skill_block_reason(s, 1, HIGH_SLASH), "no_tp", "읽기 도우미")
	s.party.members[1].tp = 32
	s.battle.party[1].binds["arm"] = 1
	check_eq(BattleRules.submit(s, _with(ok, 1, Fx.use(HIGH_SLASH, 0)))[0]["reason"], "bound_arm", "봉인")
	s.battle.party[1].binds.clear()
	s.battle.party[0].ailment = "sleep"
	s.battle.party[0].ailment_turns = 1
	check_eq(BattleRules.submit(s, _with(ok, 0, Fx.GUARD))[0]["reason"], "not_commandable", "수면 대원은 null")
	s.battle.party[0].ailment = ""
	s.battle.party[0].ailment_turns = 0
	check_eq(Fx.battle_hash(s), h, "모든 거부에서 상태·난수 그대로")


## 거부 전후 비교용: 난수, 유닛마다 방어 표시, 큐(길이·유닛·대상), 전투 사전, 해시. 해시는 방어 표시·큐를 보지 않아 따로 본다.
func _snap(s: ExplorationState) -> Array:
	var b := s.battle
	return [s.rng.get_state(), (b.party + b.enemies).map(func(u): return u.guarding),
		b.queue.map(func(a): return [a["unit"].ref(), a["kind"], a["target"]]), JSON.stringify(b.to_dict(), "", true), Fx.battle_hash(s)]


func test_submit_rejects_bad_command_fields_before_any_change() -> void:
	var s := _game({"fb": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}, "fb")
	# 큐는 턴 끝에 비므로 표지 항목을 넣어 둔다: submit 이 검사 전에 큐를 비우거나 채우면 알아챈다.
	s.battle.queue.append({"unit": s.battle.party[0], "kind": "marker", "target": 9})
	var before := _snap(s)
	var ok := Fx.cmds(s)
	# 앞 칸(0)은 방어: 검사가 늦으면 방어 표시가 먼저 켜진다.
	var bad_targets := [{}, [], true, 1.5, "0", null]
	var cases := []
	for v in bad_targets:
		cases.append([1, {"kind": "escape", "target": v}, "unknown_command"])
		cases.append([1, {"kind": "guard", "target": v}, "unknown_command"])
		cases.append([1, {"kind": "attack", "target": v}, "invalid_target"])
		cases.append([1, {"kind": "skill", "skill": HIGH_SLASH, "target": v}, "invalid_target"])
		cases.append([1, {"kind": "skill", "skill": "skill.blade_duelist.overclock", "target": v}, "invalid_target"])
	cases.append([1, {"kind": "escape", "target": 0}, "unknown_command"])
	cases.append([1, {"kind": "guard", "skill": HIGH_SLASH}, "unknown_command"])
	cases.append([1, {"kind": "attack", "skill": HIGH_SLASH, "target": 0}, "unknown_command"])
	cases.append([1, {"kind": ["attack"], "target": 0}, "unknown_command"])
	cases.append([1, {"kind": {}}, "unknown_command"])
	cases.append([1, {"kind": "skill", "skill": {}, "target": 0}, "unknown_skill"])
	cases.append([4, {"kind": "escape", "target": {}}, "unknown_command"])
	for c in cases:
		var ev := BattleRules.submit(s, _with(ok, c[0], c[1]))
		check_eq([ev.size(), ev[0]["type"], ev[0]["reason"], ev[0]["slot"]], [1, "rejected", c[2], c[0]], "%s" % str(c[1]))
		check_eq(_snap(s), before, "난수·방어 표시·큐·전투 상태 그대로: %s" % str(c[1]))


func _with(cmds: Array, i: int, c: Variant) -> Array:
	var out := cmds.duplicate(true)
	out[i] = c
	return out


# ---- 결정성 ----

## 시험용 결정적 명령: 메딕은 쓰러진 대원 → 리부트, HP 50% 미만 → 리페어, 위저드는 약점 글리프, 나머지는 HP 가 가장 낮은 적을 일반 공격.
## 난수를 쓰지 않는다(시뮬레이션 정책은 A4 의 battle_policy.gd).
static func plan(s: ExplorationState) -> Array:
	var out := []
	var b := s.battle
	for i in b.party.size():
		if not BattleRules.can_command(s, i):
			out.append(null)
			continue
		var u := b.party[i]
		var c: Variant = null
		if u.def_id == "nano_medic":
			var dead := BattleRules.valid_targets(s, i, "skill.nano_medic.reboot")
			if not dead.is_empty() and BattleRules.skill_block_reason(s, i, "skill.nano_medic.reboot").is_empty():
				c = Fx.use("skill.nano_medic.reboot", dead[0])
			else:
				for t in b.party:
					if c == null and t.alive() and t.hp * 2 < t.max_hp and BattleRules.skill_block_reason(s, i, "skill.nano_medic.nano_repair").is_empty():
						c = Fx.use("skill.nano_medic.nano_repair", t.slot)
		if c == null and u.def_id == "glyph_wizard" and u.tp * 2 >= u.max_tp:
			for g in [["skill.glyph_wizard.heat_glyph", "fire"], ["skill.glyph_wizard.frost_glyph", "ice"], ["skill.glyph_wizard.shock_glyph", "volt"]]:
				for e in b.enemies:
					if c == null and e.alive() and e.resist[g[1]] > 1000 and BattleRules.skill_block_reason(s, i, g[0]).is_empty():
						c = Fx.use(g[0], e.slot)
		if c == null:
			var ts := BattleRules.valid_targets(s, i, "attack")
			if ts.is_empty():
				c = Fx.GUARD
			else:
				var best: int = ts[0]
				for t in ts:
					if b.enemies[t].hp < b.enemies[best].hp:
						best = t
				c = Fx.atk(best)
		out.append(c)
	return out


## 전투 하나를 끝까지(최대 50턴). [이벤트 글, 끝 해시, 정보]. 정보 = {outcome, turns, rejected, save_errors}.
## 매 턴 뒤 검사 있는 저장 왕복(SaveCodec.encode → decode)을 돌려, 규칙이 만든 상태가 저장 범위 검사(06 §11.4)를 늘 통과하는지 센다.
static func run_battle(defs: GameDefs, formation: String, seed_value: int) -> Array:
	var s := Fx.battle(defs, formation, seed_value)
	var text := ""
	var info := {"outcome": "", "turns": 0, "rejected": 0, "save_errors": []}
	for t in 50:
		if s.battle == null:
			break
		var ev := BattleRules.submit(s, plan(s))
		text += Fx.events_text(ev)
		info["turns"] += 1
		info["rejected"] += Fx.of_type(ev, "rejected").size()
		for e in Fx.of_type(ev, "battle_end"):
			info["outcome"] = e["outcome"]
		var err := SaveCodec.decode(SaveCodec.encode(s), defs).error
		if not err.is_empty():
			info["save_errors"].append("%s 시드 %d 턴 %d: %s" % [formation, seed_value, info["turns"], err])
	if s.battle != null:
		info["outcome"] = "unfinished"
	return [text, Fx.battle_hash(s), info]


func test_same_seed_same_commands_same_result_over_24_battles() -> void:
	timeout_sec = 120.0
	var defs := Fx.battle_defs()
	var first := []
	var second := []
	for f in defs.battle.table_formations("encounter.f1_test"):
		for seed_value in [11, 22, 33, 44]:
			first.append(run_battle(defs, f, seed_value))
	var defs2 := Fx.battle_defs()
	for f in defs2.battle.table_formations("encounter.f1_test"):
		for seed_value in [11, 22, 33, 44]:
			second.append(run_battle(defs2, f, seed_value))
	check_eq(first.size(), 24, "24 전투")
	# 결과(승패·끝난 턴 수, 50턴 안에 안 끝남 포함)가 무엇이든 같은 이벤트·끝 상태 해시·정보인지만 본다(D15: 승패에 기대지 않는다).
	check(first == second, "같은 시드 + 같은 명령열 → 같은 이벤트·해시")
	var rejected := []
	for x in first:
		var info: Dictionary = x[2]
		if info["rejected"] != 0:
			rejected.append(info)
		check_eq(info["save_errors"], [], "매 턴 상태가 저장 검사를 통과")
	check_eq(rejected, [], "명령열이 거부되지 않는다(규칙을 실제로 거친다)")


func test_plan_does_not_draw() -> void:
	var s := Fx.battle(Fx.battle_defs(), "formation.f1.serpents_moth", 5)
	var before := s.rng.get_state()
	plan(s)
	check_eq(s.rng.get_state(), before, "명령 만들기는 난수를 뽑지 않음")


func test_mid_battle_save_and_continue_gives_same_result() -> void:
	# 끝날 수 없는 구성(D15): 적 둘 다 아무것도 하지 않아 전멸이 없고, 벽은 모든 속성 무효라 쓰러지지 않아 승리도 없다. 규칙 상수는
	# 실제 값이라 순서 난수와(허수아비가 살아 있는 동안) 명중·크리티컬·피해 난수를 뽑는다 → 저장 왕복 뒤에도 같은 난수 흐름인지 본다.
	var wall := Fx.enemy("enemy.t_wall", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	for el in wall["resist"]:
		wall["resist"][el] = 0
	var s := Fx.battle(Fx.battle_defs(Fx.test_files(_skills(), _enemies() + [wall], {"m": [[Fx.DUMMY, "front"], ["enemy.t_wall", "front"]]})), "formation.t.m", 21)
	for t in 2:
		BattleRules.submit(s, plan(s))
	check(s.battle != null, "아직 전투 중")
	var c := Fx.battle_clone(s)
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "왕복 뒤 같은 해시")
	var rng_at_save := s.rng.get_state()
	var ta := ""
	var tb := ""
	for t in 50:
		if s.battle == null:
			break
		ta += Fx.events_text(BattleRules.submit(s, plan(s)))
		tb += Fx.events_text(BattleRules.submit(c, plan(c)))
	check_eq(tb, ta, "이어서 같은 이벤트")
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "같은 끝 해시")
	check(s.battle != null and s.rng.get_state() != rng_at_save, "구성대로 끝나지 않고, 이어서 난수를 뽑았다")


func test_definition_key_order_does_not_matter() -> void:
	var files := Fx.battle_files()
	var rev := {}
	var paths := files.keys()
	paths.reverse()
	for p in paths:
		rev[p] = _reverse_keys(files[p])
	var a := run_battle(Fx.battle_defs(), "formation.f1.mole_rat_bloom", 17)
	var b := run_battle(Fx.defs_from(rev), "formation.f1.mole_rat_bloom", 17)
	check_eq(b, a, "사전 키 순서·파일 순서가 달라도 같은 결과")


static func _reverse_keys(v: Variant) -> Variant:
	if typeof(v) == TYPE_DICTIONARY:
		var keys: Array = v.keys()
		keys.reverse()
		var out := {}
		for k in keys:
			out[k] = _reverse_keys(v[k])
		return out
	if typeof(v) == TYPE_ARRAY:
		return v.map(func(x): return _reverse_keys(x))
	return v
