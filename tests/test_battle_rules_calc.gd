extends TestCase
## 전투 정수 계산(06 §3.1·§3.8·§3.9·§3.11·§3.17·§4). 기대값은 §3 식으로 손 계산한 정수다
## (산술 경계 값은 06 §3.1 표와 같은 일회용 파이썬 식으로도 확인했다).

const Fx := preload("res://tests/fixtures.gd")


func _rules(over: Dictionary = {}) -> BattleDb.Rules:
	return Fx.battle_db(Fx.battle_files({}, over)).rules


func test_mul_truncates_toward_zero() -> void:
	check_eq(BattleCalc.mul(4, 1300), 5, "4 × 1.3 = 5.2 → 5")
	check_eq(BattleCalc.mul(5, 1200), 6, "5 × 1.2 = 6")
	check_eq(BattleCalc.mul(4, 1200), 4, "4 × 1.2 = 4.8 → 4")
	check_eq(BattleCalc.mul(550, 1), 0, "버림으로 0")
	check_eq(BattleCalc.mul(0, 3000), 0, "0")


func test_roll_and_pick_do_not_draw_when_decided() -> void:
	var r := GameRng.new(99)
	var before := r.get_state()
	check(not BattleCalc.roll(r, 0), "roll(0) 거짓")
	check(not BattleCalc.roll(r, -5), "roll(음수) 거짓")
	check(BattleCalc.roll(r, 1000), "roll(1000) 참")
	check(BattleCalc.roll(r, 1500), "roll(1000 초과) 참")
	check_eq(BattleCalc.pick(r, 1), 0, "pick(1) = 0")
	check_eq(BattleCalc.pick_weighted(r, [7] as Array[int]), 0, "가중치 후보 하나")
	check_eq(r.randi_range(1000, 1000), 1000, "양 끝이 같은 구간")
	check_eq(r.get_state(), before, "모두 상태 불변")
	BattleCalc.roll(r, 500)
	check(r.get_state() != before, "그 밖에는 뽑는다")


func test_pick_weighted_uses_one_draw_and_cumulative_sum() -> void:
	# 가중치 [2, 3]: randi_range(0, 4) 가 0·1 이면 0번, 2·3·4 면 1번.
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var a := GameRng.new(seed_value)
		var b := GameRng.new(seed_value)
		var got := BattleCalc.pick_weighted(a, [2, 3] as Array[int])
		var raw := b.randi_range(0, 4)
		check_eq(got, 0 if raw < 2 else 1, "시드 %d" % seed_value)
		check_eq(a.get_state(), b.get_state(), "뽑기 한 번")


func test_isqrt_boundaries() -> void:
	var ns := [0, 1, 2, 3, 4, 8, 9, 10, 15, 16, 17, 999999, 1000000, 1000001, 998001, BattleCalc.ISQRT_MAX]
	for r in [2, 3, 1000, 12345, 31606]:
		ns.append_array([r * r - 1, r * r, r * r + 1])
	for n in ns:
		if n > BattleCalc.ISQRT_MAX:
			continue
		var r := BattleCalc.isqrt(n)
		check(r * r <= n and n < (r + 1) * (r + 1), "isqrt(%d) = %d" % [n, r])
	check_eq(BattleCalc.isqrt(BattleCalc.ISQRT_MAX), 31606, "입력 상한")
	check_eq(BattleCalc.isqrt(1000000), 1000, "1000²")


func test_arithmetic_bounds_m2_constants() -> void:
	# 06 §3.1 표: A 1998·D 1·power 2000·속성 3000·강화/약화 칸 3+3 가득 3000·크리 1500·난수 1050·k 100.
	var r := _rules()
	var calc := BattleCalc.damage(r, {"A": 1998, "D": 1, "power": 2000, "element": 3000, "row": false,
		"atk_muls": [3000, 3000, 3000], "def_muls": [3000, 3000, 3000], "guard": false, "front_guard": 0, "crit": true, "roll": 1050})
	check_eq(BattleCalc.damage_base(1998, 1, 2000, 100), 39940, "base(첫 분자 7,984,008,000)")
	check_eq([calc["base"], calc["element"], calc["atk_mul"], calc["def_mul"], calc["crit"], calc["final"]],
		[39940, 119820, 3235140, 87348780, 131023170, 137574328], "단계별 중간값")
	check_eq(calc["crit"] * 1050, 137574328500, "가장 큰 곱 137,574,328,500")
	check(calc["final"] > 0, "넘침·음수 없음")


func test_arithmetic_bounds_range_end_constants() -> void:
	# 허용 범위 끝: 칸 5+5, 크리 3000, 난수 1500, k 50.
	var r := _rules({"crit_mult": 3000, "defense_k": 50, "damage_roll": [500, 1500], "buff_slots": 5, "debuff_slots": 5})
	var calc := BattleCalc.damage(r, {"A": 1998, "D": 1, "power": 2000, "element": 3000, "row": false,
		"atk_muls": [3000, 3000, 3000, 3000, 3000], "def_muls": [3000, 3000, 3000, 3000, 3000], "guard": false, "front_guard": 0, "crit": true, "roll": 1500})
	check_eq([calc["base"], calc["def_mul"], calc["crit"], calc["final"]], [39960, 7078794120, 21236382360, 31854573540], "단계별 중간값")
	check_eq(calc["crit"] * 1500, 31854573540000, "가장 큰 곱 31,854,573,540,000")
	check_eq(BattleCalc.order_value(999, 3000, 1500), 4495500000, "순서 값 상한")
	check_eq(BattleCalc.order_value(999, 3000, 1100), 3296700000, "순서 값 M2")


func test_arithmetic_bounds_through_rules() -> void:
	# 같은 최대 조건을 실제 규칙 경로(submit)로: STR 999 + atk 999, 대상 VIT 1, 속성 3000, 칸 가득, 크리 확정.
	var t := Fx.enemy("enemy.t_wall", 9999, [1, 1, 1, 1, 1, 1], [[{}, [[Fx.MEND, 1]]]])
	t["resist"]["slash"] = 3000
	var fx := []
	for i in 3:
		fx.append(Fx.effect_skill("skill.t.a%d" % i, false, [["phys_atk", 3000, 3]]))
		fx.append(Fx.effect_skill("skill.enemy.t_d%d" % i, true, [["phys_def", 3000, 3]]))
	var files := Fx.battle_files(Fx.test_files(fx, [t], {"wall": [["enemy.t_wall", "front"]]}), {"crit_base": 1000, "crit_max": 1000, "hit_min": 1000})
	files["skills/blade_duelist.json"]["skills"][0]["levels"][0]["power"] = 2000  # 하이 슬래시를 power 상한으로
	var s := Fx.battle(Fx.defs_from(files), "formation.t.wall")
	var d := s.battle.party[1]
	d.stats["STR"] = 999
	d.gear["atk"] = 999
	var e := s.battle.enemies[0]
	for i in 3:
		Fx.apply_effect(s, d, "skill.t.a%d" % i)
		Fx.apply_effect(s, e, "skill.enemy.t_d%d" % i)
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use("skill.blade_duelist.high_slash", 0)}))
	var dmg := Fx.of_type(ev, "damaged")[0]
	var c: Dictionary = dmg["calc"]
	check_eq([c["A"], c["D"], c["base"], c["element"], c["atk_mul"], c["def_mul"], c["crit"]], [1998, 1, 39940, 119820, 3235140, 87348780, 131023170], "규칙 경로의 중간값")
	check_eq(c["final"], 131023170 * int(c["roll"]) / 1000, "마지막 곱")
	check_eq(dmg["lost"], 9999, "HP 는 남은 만큼만 준다")


func test_arm_bound_str_one_gives_a_of_one() -> void:
	var defs := Fx.battle_defs(Fx.test_files([], [], {"d": [[Fx.DUMMY, "front"]]}), Fx.EXACT)
	var s := Fx.battle(defs, "formation.t.d")
	var d := s.battle.party[1]
	d.stats["STR"] = 1
	d.gear["atk"] = 0
	d.binds["arm"] = 3
	var c: Dictionary = Fx.of_type(BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)})), "damaged")[0]["calc"]
	check_eq(c["A"], 1, "mul(1, 700) = 0 이지만 A 는 1")
	check_eq(c["base"], 0, "1×1×100 / (100 × (1 + 10)) = 0")
	check_eq(c["final"], 1, "최소 1")


func test_damage_pipeline_hand_values() -> void:
	# 듀얼리스트(A = 19 + 14 = 33) → 시험 적(VIT 10): base = 33²×100 / (100×(33+10)) = 108900/4300 = 25.
	var defs := Fx.battle_defs(Fx.test_files([], [], {"d": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}), Fx.EXACT)
	var s := Fx.battle(defs, "formation.t.d")
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: Fx.use("skill.blade_duelist.high_slash", 1), 4: Fx.use("skill.glyph_wizard.heat_glyph", 1)}))
	var dm := Fx.of_type(ev, "damaged")
	var by := {}
	for e in dm:
		if e["unit"]["side"] == "party":
			by[e["unit"]["slot"]] = e["calc"]
	check_eq([by[1]["A"], by[1]["D"], by[1]["base"], by[1]["row"], by[1]["final"]], [33, 10, 25, 25, 25], "전열 → 전열 일반 공격")
	# 하이 슬래시 power 150: 33²×150/4300 = 37, 근접이고 대상이 후열 → 18.
	check_eq([by[2]["base"], by[2]["element"], by[2]["row"], by[2]["final"]], [37, 37, 18, 18], "전열 → 후열 근접 ×500")
	# 열 글리프: A = INT 21 + matk 12 = 33, D = WIS 10, power 130 → 33²×130/4300 = 32. 원거리라 보정 없음.
	check_eq([by[4]["A"], by[4]["D"], by[4]["base"], by[4]["row"], by[4]["final"]], [33, 10, 32, 32, 32], "후열 → 후열 원거리")
	check_eq(s.battle.party[2].tp, 28, "하이 슬래시 TP 4")
	check_eq(s.battle.party[4].tp, 55, "글리프 TP 5")


func test_defense_k_outside_default() -> void:
	check_eq(BattleCalc.damage_base(33, 10, 100, 50), 28, "k 50: 108900 / (100 × 38)")
	check_eq(BattleCalc.damage_base(33, 10, 100, 200), 20, "k 200: 108900 / (100 × 53)")
	var defs := Fx.battle_defs(Fx.test_files([], [], {"d": [[Fx.DUMMY, "front"]]}), {"defense_k": 200, "damage_roll": [1000, 1000], "crit_base": 0, "crit_luck": 0, "hit_min": 1000})
	var s := Fx.battle(defs, "formation.t.d")
	var c: Dictionary = Fx.of_type(BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)})), "damaged")[0]["calc"]
	check_eq(c["base"], 20, "규칙 상수가 식에 쓰인다")


func test_hit_probability() -> void:
	var r := _rules()
	check_eq(BattleCalc.hit_p(r, 950, 18, 18), 950, "AGI 같음 → accuracy")
	check_eq(BattleCalc.hit_p(r, 950, 1, 999), 300, "하한 300(isqrt(1001) = 31 → 29)")
	check_eq(BattleCalc.hit_p(r, 950, 999, 1), 1000, "상한 1000")
	check_eq(BattleCalc.hit_p(r, 950, 9, 18), 671, "isqrt(500000) = 707 → 671")
	var u := BattleUnit.new()
	u.stats = {"AGI": 18}
	check_eq(u.evasion_agi(r), 18, "봉인 없음")
	u.binds["leg"] = 2
	check_eq(u.evasion_agi(r), 9, "다리 봉인 회피 AGI ×500")
	check_eq(BattleCalc.hit_p(r, 950, 9, u.evasion_agi(r)), 950, "다리 봉인 대상은 맞히기 쉽다")
	u.stats = {"AGI": 1}
	check_eq(u.evasion_agi(r), 1, "0 이 되지 않는다")
	check_eq(BattleCalc.hit_p(_rules({"hit_min": 0, "hit_max": 500}), 950, 18, 18), 500, "상수 hit_max 를 쓴다")


func test_crit_probability() -> void:
	var r := _rules()
	check_eq(BattleCalc.crit_p(r, 13, 10), 65, "50 + 3 × 5")
	check_eq(BattleCalc.crit_p(r, 200, 10), 200, "상한 200")
	check_eq(BattleCalc.crit_p(r, 1, 30), 0, "하한 0")


func test_status_probability() -> void:
	var r := _rules()
	check_eq(BattleCalc.status_p(r, 400, 10, 13, 1000, 0), 376, "행운 940")
	check_eq(BattleCalc.status_p(r, 400, 10, 13, 1000, 300), 263, "누적 내성 300 → ×700")
	check_eq(BattleCalc.status_p(r, 400, 999, 1, 1000, 0), 600, "행운 상한 1500")
	check_eq(BattleCalc.status_p(r, 400, 1, 999, 1000, 0), 200, "행운 하한 500")
	check_eq(BattleCalc.status_p(r, 400, 10, 10, 0, 0), 0, "취약도 0 → 0")
	check_eq(BattleCalc.status_p(r, 800, 10, 10, 1500, 0), 1000, "1000 으로 자름")
	check_eq(BattleCalc.status_p(r, 550, 10, 10, 1000, 999), 0, "정수 버림으로 0 이 될 수 있다(mul(550, 1))")


func test_escape_probability() -> void:
	var r := _rules()
	check_eq(BattleCalc.escape_p(r, 14, 10), 680, "600 + 4 × 20")
	check_eq(BattleCalc.escape_p(r, 1, 99), 200, "하한")
	check_eq(BattleCalc.escape_p(r, 99, 1), 950, "상한")


func test_effect_order_is_value_then_id() -> void:
	var a := [{"id": "skill.b", "value": 1300}, {"id": "skill.a", "value": 1200}]
	check_eq(BattleCalc.effect_order(a), [1200, 1300] as Array[int], "value 오름차순")
	a.reverse()
	check_eq(BattleCalc.effect_order(a), [1200, 1300] as Array[int], "건 순서와 상관없음")
	var same := [{"id": "skill.z", "value": 700}, {"id": "skill.a", "value": 700}, {"id": "skill.m", "value": 1100}]
	check_eq(BattleCalc.effect_order(same), [700, 700, 1100] as Array[int], "같은 값")
	check_eq(BattleCalc.effect_order(same)[0], 700, "원본은 그대로")
	check_eq(same[0]["id"], "skill.z", "원본 배열 순서 불변")


func test_fixed_rng_vector() -> void:
	# Godot 4.7.2-stable 에서 잰 값. Godot 판을 올리면 이 시험이 먼저 깨진다(06 §4.3) — 그때 기준을 새로 잡는다.
	var r := GameRng.new(20261017)
	var v := []
	for i in 5:
		v.append(r.randi_range(0, 999))
	check_eq(v, [488, 273, 900, 468, 401], "값 열")
	check_eq(r.get_state(), 6103955040787166622, "뒤의 상태")
	# 상태를 저장 표기(10진 문자열)로 왕복한 뒤에도 같은 값으로 이어 간다.
	var restored := GameRng.new(1)
	restored.set_state(SaveCodec.parse_int64(str(r.get_state())))
	var w := []
	for i in 3:
		w.append(restored.randi_range(900, 1100))
	check_eq(w, [910, 906, 994], "이어지는 순서 난수")
	check_eq(restored.get_state(), 2188078251986251647, "이어진 뒤 상태")
