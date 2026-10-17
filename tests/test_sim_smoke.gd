extends TestCase
## 시뮬레이션 연기 시험(06 §7.4 끝): 2칸 × 10판 + 파티마다 연전 하나로 형식·해시 재현·정책 계약을 본다. 밸런스는 판정하지 않는다.

const Fx := preload("res://tests/fixtures.gd")
const SimLib := preload("res://tests/sim/sim_lib.gd")

const LINE_B := "^B,\\d+,\\d+,\\d+,[0-4],\\d+,\\d+,\\d+(,\\d+){5}(,\\d+)+,-?\\d+$"
const LINE_C := "^C,P\\d,\\d+,\\d+,\\d+,-?\\d+,[0134],-?\\d+$"


func _lib() -> SimLib:
	var lib := SimLib.new()
	check(lib.load_all(), "설정·정의 읽기: %s" % str(lib.errors))
	return lib


func _plan(lib: SimLib) -> Dictionary:
	var plan := lib.plan_of("probe")
	plan["size"] = "smoke"
	plan["cells"] = [["P1", "formation.f1.beetle_rat", "default"], ["P2", "formation.f1.serpents_moth", "full"]]
	plan["games_per_cell"] = 10
	plan["chain_parties"] = ["P1", "P2"]
	plan["chains_per_party"] = 1
	plan["save_check_games"] = 3
	return plan


func test_smoke_run_format_and_hash_repeat() -> void:
	var lib := _lib()
	var plan := _plan(lib)
	var lines := PackedStringArray()
	var r1 := lib.run(plan, func(l): lines.append(l))
	check_eq([r1["games"], r1["chains_run"], r1["cells"].size()], [20, 2, 2], "계획 수 완료")
	for c in r1["cells"]:
		check_eq([c["outcomes"]["stalled"], c["outcomes"]["error"], c["games"]], [0, 0, 10], "교착·오류 없음 %s" % c["formation"])
	check_eq(r1["save_error_count"], 0, "표본 판 매 턴 저장 왕복")
	check_eq(lines.size(), 22, "원자료 줄: 판 20 + 연전 2")
	var rb := RegEx.create_from_string(LINE_B)
	var rc := RegEx.create_from_string(LINE_C)
	for i in lines.size():
		var l := lines[i]
		check(l.ends_with("\n") and not l.contains(" "), "줄 끝 LF·공백 없음: %s" % l)
		check((rb if i < 20 else rc).search(l.trim_suffix("\n")) != null, "줄 형식: %s" % l)
	check(lines[0].begins_with("B,0,0,%d," % (plan["base_seed"])), "첫 판 시드 = base_seed")
	check(lines[10].begins_with("B,1,0,%d," % (plan["base_seed"] + 1_000_000)), "칸 1 시드 = base_seed + 1,000,000")
	check(lines[20].begins_with("C,P1,0,0,%d," % (plan["base_seed"] + 900_000_000)), "연전 시드")
	check(lines[21].begins_with("C,P2,1,0,%d," % (plan["base_seed"] + 900_000_000 + 1_000_000)), "둘째 연전 파티 시드 = + 파티 번호 × 1,000,000")
	check_eq(r1["result_hash"], SimLib.hash16("".join(lines)), "결과 해시 = 원자료 글의 SHA-256 앞 16자")
	check_eq(r1["result_hash"].length(), 16, "16자")
	var lib2 := SimLib.new()
	lib2.load_all()
	var r2 := lib2.run(_plan(lib2))
	check_eq([r2["result_hash"], r2["config_hash"], r2["data_hash"]], [r1["result_hash"], r1["config_hash"], r1["data_hash"]], "같은 설정 → 같은 해시")
	var plan3 := _plan(lib2)
	plan3["save_check_games"] = 0
	check_eq(lib2.run(plan3)["result_hash"], r1["result_hash"], "저장 왕복 표본은 결과를 바꾸지 않음")
	plan3["base_seed"] = 1
	check(lib2.config_text(plan3) != lib2.config_text(_plan(lib2)), "설정이 다르면 config 글이 다름")


func test_p1_is_the_test_party() -> void:
	var lib := _lib()
	var p1: Dictionary = lib.party_dict("P1")
	var t: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/party/test_party.json"))
	check_eq(JSON.stringify(p1, "", true), JSON.stringify(t, "", true), "P1 = 시험 파티")
	var p2: Array = lib.party_dict("P2")["members"]
	check_eq(p2.map(func(m): return [m["id"], m["row"]]),
		[["holo_knight", "front"], ["blade_duelist", "front"], ["nano_medic", "back"], ["glyph_wizard", "back"], ["glyph_wizard_2", "back"]], "P2 구성")


func test_lower_median() -> void:
	check_eq(SimLib.lower_median([40, 0, 5, 2, 3]), 3, "[0, 2, 3, 5, 40] → 3")
	check_eq(SimLib.lower_median([4, 1, 3, 2]), 2, "짝수 개는 아래 중앙값")
	check_eq(SimLib.lower_median([0]), 0, "하나")


func test_policy_does_not_draw_or_change_state() -> void:
	var defs := Fx.defs()
	for f in ["formation.f1.beetle_rat", "formation.f1.mole_rat_bloom"]:
		var s := Fx.battle(defs, f, 7)
		for t in 4:
			if s.battle == null:
				break
			var before := [s.rng.get_state(), Fx.battle_hash(s), SaveCodec.state_hash(s)]
			for pol in BattlePolicy.NAMES:
				var cmds := BattlePolicy.choose(s, pol)
				check(BattleRules.check_commands(s, cmds).is_empty(), "%s %s 정책 명령은 제출 검사를 통과" % [f, pol])
			check_eq([s.rng.get_state(), Fx.battle_hash(s), SaveCodec.state_hash(s)], before, "정책은 난수·상태를 건드리지 않음")
			BattleRules.submit(s, BattlePolicy.choose(s, BattlePolicy.DEFAULT))


func test_expected_damage_matches_rules_without_randomness() -> void:
	var defs := Fx.battle_defs(Fx.test_files([], [], {"d": [[Fx.DUMMY, "front"], [Fx.DUMMY, "back"]]}), Fx.EXACT)
	var s := Fx.battle(defs, "formation.t.d", 1)
	var b := s.battle
	b.party[1].binds["arm"] = 2
	var cases := [[1, "attack", 0], [2, "skill.blade_duelist.high_slash", 1], [4, "skill.glyph_wizard.heat_glyph", 0], [3, "attack", 0]]
	var expect := {}
	var cmds := {}
	for c in cases:
		var sk := BattleRules.skill_of(s, c[0], c[1])
		expect[c[0]] = BattlePolicy.expected_damage(s, b.party[c[0]], sk, b.enemies[c[2]])
		cmds[c[0]] = Fx.atk(c[2]) if c[1] == "attack" else Fx.use(c[1], c[2])
	var ev := BattleRules.submit(s, Fx.cmds(s, cmds))
	for e in Fx.of_type(ev, "damaged"):
		if e["unit"]["side"] == "party":
			check_eq(e["amount"], expect[e["unit"]["slot"]], "기대 피해 = 실제 피해(난수 1000·크리 0·명중 확정), 대원 %d" % e["unit"]["slot"])
	check_eq(Fx.of_type(ev, "damaged").filter(func(e): return e["unit"]["side"] == "party").size(), 4, "네 대원 모두 맞힘")


func test_policy_ties_and_choices() -> void:
	var defs := Fx.battle_defs(Fx.test_files([], [], {"d": [[Fx.DUMMY, "front"], [Fx.DUMMY, "front"]]}), Fx.EXACT)
	var s := Fx.battle(defs, "formation.t.d", 1)
	var b := s.battle
	check_eq(BattlePolicy.attack_command(s, 1), {"kind": "attack", "target": 0}, "HP 같으면 칸 번호가 작은 적")
	b.enemies[0].hp = 500
	check_eq(BattlePolicy.attack_command(s, 1), {"kind": "attack", "target": 0}, "HP 가 낮은 적")
	# 메딕: 쓰러진 대원 → 리부트, 기본은 수면·마비·봉인 해제에 TP 절반 조건.
	s.party.members[0].hp = 0
	check_eq(BattlePolicy.choose_one(s, 3, "default"), {"kind": "skill", "skill": BattlePolicy.REBOOT, "target": 0}, "리부트")
	check_eq(BattlePolicy.choose_one(s, 3, "attack_only")["kind"], "attack", "공격만은 리부트 안 함")
	s.party.members[0].hp = 60
	b.party[2].binds["leg"] = 1
	s.party.members[3].tp = 26
	check_eq(BattlePolicy.choose_one(s, 3, "default")["kind"], "attack", "TP 절반 미만이면 기본은 해제 안 함")
	check_eq(BattlePolicy.choose_one(s, 3, "full"), {"kind": "skill", "skill": BattlePolicy.PATCH, "target": 2}, "전력은 TP 조건 없음")
	s.party.members[4].hp = 19
	check_eq(BattlePolicy.choose_one(s, 3, "attack_only"), {"kind": "skill", "skill": BattlePolicy.REPAIR, "target": 4}, "HP 50% 미만 → 리페어")


# ---- 설정·계획 검사 (3차 검토 Medium 1) ----

const CFG_PATH := Fx.SAVE_DIR + "/sim_config.json"


func _config_errors(mutate: Callable) -> Array[String]:
	var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SimLib.CONFIG_PATH))
	mutate.call(c)
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(c))
	f.close()
	var lib := SimLib.new()
	check(not lib.load_all(CFG_PATH), "잘못된 설정은 읽기 실패")
	return lib.errors


func _cfg_rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _config_errors(mutate)
	check(errs.any(func(e): return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func test_config_rejects_missing_axes_and_bad_values() -> void:
	Fx.clean_saves()
	_cfg_rejects("large 빈 파티·연전", func(c):
		c["sizes"]["large"]["parties"] = []
		c["sizes"]["large"]["chain_parties"] = [], "sizes.large.parties: 06 §7.2 의 파티 P1 가 없다")
	_cfg_rejects("large 연전 파티 빠짐", func(c): c["sizes"]["large"]["chain_parties"] = ["P1"], "sizes.large.chain_parties: 연전 파티 P2 가 없다")
	_cfg_rejects("정책 오타", func(c): c["sizes"]["large"]["policies"] = ["defualt", "attack_only", "full"], "sizes.large.policies: 모르는 정책 defualt")
	_cfg_rejects("정책 빠짐", func(c): c["sizes"]["small"]["policies"] = ["default"], "sizes.small.policies: 정책 full 가 없다")
	_cfg_rejects("편성 일부", func(c): c["sizes"]["small"]["formations"] = ["formation.f1.rats"], "sizes.small.formations: all 이어야 한다")
	_cfg_rejects("모르는 편성", func(c): c["sizes"]["probe"]["formations"] = ["formation.f1.nope"], "sizes.probe.formations: 출현 표에 없는 편성")
	_cfg_rejects("판 수 0", func(c): c["sizes"]["small"]["games_per_cell"] = 0, "sizes.small.games_per_cell: 1 이상 정수")
	_cfg_rejects("판 수 소수", func(c): c["sizes"]["large"]["games_per_cell"] = 2.5, "sizes.large.games_per_cell")
	_cfg_rejects("판 수 문자열", func(c): c["sizes"]["large"]["chains_per_party"] = "500", "sizes.large.chains_per_party")
	_cfg_rejects("연전 0", func(c): c["sizes"]["large"]["chains_per_party"] = 0, "sizes.large.chains_per_party: 1 이상")
	_cfg_rejects("모르는 파티", func(c): c["sizes"]["small"]["chain_parties"] = ["P1", "P2", "P9"], "sizes.small.chain_parties: 모르는 파티 P9")
	_cfg_rejects("크기 없음", func(c): c["sizes"].erase("large"), "sizes.large: 필수 크기가 없다")
	_cfg_rejects("모르는 크기 필드", func(c): c["sizes"]["small"]["games"] = 1, "sizes.small.games: 모르는 필드")
	_cfg_rejects("probe 축", func(c): c["sizes"]["probe"]["policies"] = ["full"], "sizes.probe: P1·첫 편성·기본 정책")
	_cfg_rejects("파티 직업", func(c): c["parties"]["P3"][2][0] = "class.nope", "parties.P3: 직업 class.nope")
	_cfg_rejects("파티 넷", func(c): c["parties"]["P2"].pop_back(), "parties.P2: [직업 ID, front|back] 5개")
	_cfg_rejects("수용 범위", func(c): c["acceptance"].erase("p1_chain_median"), "acceptance.p1_chain_median")
	_cfg_rejects("자료형", func(c): c["floor"] = 3, "floor: 비지 않은 문자열")
	_cfg_rejects("stall_limit 0", func(c): c["stall_limit"] = 0, "stall_limit: 1 이상 정수")
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	f.store_string("[1, 2]")
	f.close()
	var lib := SimLib.new()
	check(not lib.load_all(CFG_PATH) and lib.errors[0].contains("맨 위는 객체"), "배열 설정 거부")
	check(_lib().errors.is_empty(), "저장소의 설정은 통과")
	Fx.clean_saves()


func test_plan_check() -> void:
	var lib := _lib()
	check_eq(lib.check_plan(lib.plan_of("small")), [] as Array[String], "small 계획 통과")
	check_eq(lib.check_plan(lib.plan_of("large")), [] as Array[String], "large 계획 통과")
	check_eq(lib.check_plan(_plan(lib)), [] as Array[String], "일부만 도는 smoke 계획은 따로 통과")
	var p := lib.plan_of("large")
	p["cells"].pop_back()
	check(lib.check_plan(p).any(func(e): return e.contains("필요한 칸 P3·formation.f1.moles_bloom·full")), "large 에 칸이 빠지면 거부")
	p = lib.plan_of("small")
	p["chain_parties"] = []
	check(lib.check_plan(p).any(func(e): return e.contains("연전 파티 P1")), "small 연전 파티 빠짐 거부")
	p = _plan(lib)
	p["cells"][0][2] = "defualt"
	var bad := lib.check_plan(p)
	check(bad.any(func(e): return e.contains("잘못된 칸")), "정책 오타 칸 거부")
	check_eq(lib.run(p).get("plan_errors", []), bad, "run 도 돌리지 않고 계획 오류를 돌려줌")
	check_eq(SimLib.exit_code(lib.run(p)), 2, "계획 오류는 종료 코드 2")
	p = _plan(lib)
	p["games_per_cell"] = 0
	check(not lib.check_plan(p).is_empty(), "판 수 0 거부")
	check(BattlePolicy.choose(Fx.battle(Fx.defs(), "formation.f1.rats", 1), "defualt").is_empty(), "정책 모듈도 모르는 이름이면 빈 명령(제출 거부)")


# ---- 종료 코드와 보고서 쓰기 (3차 검토 Medium 2) ----

func test_exit_codes_and_report_write_failures() -> void:
	Fx.clean_saves()
	var lib := _lib()
	var plan := _plan(lib)
	plan["save_check_games"] = 0
	var r := lib.run(plan)
	check_eq(SimLib.exit_code(r), 0, "정상 smoke → 0")
	# 쓸 수 없는 출력: 폴더 자리에 파일이 있다.
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(Fx.SAVE_DIR + "/blocker_file", FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var werr := SimLib.write_report(r, ProjectSettings.globalize_path(Fx.SAVE_DIR + "/blocker_file/sub/report.json"))
	check(not werr.is_empty(), "폴더를 만들 수 없으면 이유를 돌려줌: %s" % werr)
	check_eq(SimLib.exit_code(r, werr), 2, "보고서 쓰기 실패 → 2")
	werr = SimLib.write_report(r, ProjectSettings.globalize_path(Fx.SAVE_DIR + "/blocker_file"))
	check(werr.is_empty(), "쓸 수 있는 경로는 성공(덮어씀): %s" % werr)
	check_eq(JSON.parse_string(FileAccess.get_file_as_string(Fx.SAVE_DIR + "/blocker_file"))["result_hash"], r["result_hash"], "쓴 보고서를 다시 읽음")
	# 저장 왕복 실패 → 실행 오류 2(밸런스 1 이 아니다).
	var bad := r.duplicate(true)
	bad["save_error_count"] = 1
	bad["checks"] = lib.checks(bad, plan)
	check_eq(SimLib.exit_code(bad), 2, "표본 저장 왕복 실패 → 2")
	# 교착 probe → 2(probe 는 0·2 만).
	lib.config["stall_limit"] = 1
	var probe := lib.plan_of("probe")
	probe["games_per_cell"] = 3
	probe["chains_per_party"] = 1
	var pr := lib.run(probe)
	check(pr["cells"][0]["outcomes"]["stalled"] == 3, "한 턴 상한이면 모두 교착")
	check_eq(SimLib.exit_code(pr), 2, "교착 probe → 2")
	check(pr["checks"].all(func(c): return c["kind"] == "exec"), "probe 에는 밸런스 판정이 없음")
	lib.config["stall_limit"] = 50
	# 밸런스 범위만 벗어나면 1, gate 가 아닌 참고 판정은 종료 코드에 쓰지 않음.
	var fake := {"checks": [SimLib._check("교착 0", 0, "0", true, "exec"), SimLib._check("가중 평균", 9.0, "3~5", false, "balance", true)]}
	check_eq(SimLib.exit_code(fake), 1, "밸런스 범위 밖 → 1")
	fake["checks"][1]["gate"] = false
	check_eq(SimLib.exit_code(fake), 0, "참고 판정은 종료 코드에 쓰지 않음")
	fake["checks"].append(SimLib._check("판정에 필요한 결과가 모두 있음", "없음: P2/default", "0", false, "exec"))
	check_eq(SimLib.exit_code(fake), 2, "필요한 결과가 없으면 → 2")
	Fx.clean_saves()


func test_missing_results_fail_instead_of_skipping() -> void:
	var lib := _lib()
	var plan := lib.plan_of("small")
	# 결과가 하나도 없는 보고(돌리지 않은 칸)로 판정만 만든다: 범위 판정이 빠지면 안 되고 실패로 남아야 한다.
	var report := {"cells": [], "chains": [], "games": 0, "chains_run": 0, "weighted": {}, "save_error_count": 0}
	var cs := lib.checks(report, plan)
	var need := cs.filter(func(c): return c["name"] == "판정에 필요한 결과가 모두 있음")
	check(need.size() == 1 and not need[0]["pass"], "필요한 결과 없음 → 실패")
	check(not cs.filter(func(c): return c["name"] == "모든 판 완료")[0]["pass"], "완료 판정 실패")
	report["checks"] = cs
	check_eq(SimLib.exit_code(report), 2, "종료 코드 2")


# ---- 기대 피해: 무효·약점·내성·강화·약화·방어·전열 방어 ----

func test_expected_damage_matches_rules_in_modifier_cases() -> void:
	var weak := Fx.enemy("enemy.t_weak_fire", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	weak["resist"]["fire"] = 1500
	var hard := Fx.enemy("enemy.t_hard_slash", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	hard["resist"]["slash"] = 500
	var ghost := Fx.enemy("enemy.t_no_bash", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]])
	ghost["resist"]["bash"] = 0
	var soft := Fx.effect_skill("skill.enemy.t_soften", true, [["phys_def", 1250, 3]])
	var defs := Fx.battle_defs(Fx.test_files([soft], [weak, hard, ghost],
		{"m": [["enemy.t_weak_fire", "front"], ["enemy.t_hard_slash", "front"], ["enemy.t_no_bash", "front"]]}), Fx.EXACT)
	var s := Fx.battle(defs, "formation.t.m", 1)
	var b := s.battle
	Fx.apply_effect(s, b.party[1], "skill.blade_duelist.overclock")  # 공격 강화 1300
	Fx.apply_effect(s, b.enemies[1], "skill.enemy.t_soften")          # 받는 피해 약화 1250
	b.enemies[0].guarding = true                                     # 방어(턴 끝까지 남는다)
	var cases := [[0, "attack", 0, "방어"], [1, "attack", 1, "내성·강화·약화"], [4, "skill.glyph_wizard.heat_glyph", 0, "약점·방어"], [3, "attack", 2, "무효"]]
	var expect := {}
	var cmds := {}
	for c in cases:
		expect[c[0]] = BattlePolicy.expected_damage(s, b.party[c[0]], BattleRules.skill_of(s, c[0], c[1]), b.enemies[c[2]])
		cmds[c[0]] = Fx.atk(c[2]) if c[1] == "attack" else Fx.use(c[1], c[2])
	check_eq(expect[3], 0, "무효는 0")
	var ev := BattleRules.submit(s, Fx.cmds(s, cmds))
	var got := {}
	for e in Fx.of_type(ev, "damaged"):
		if e["unit"]["side"] == "party":
			got[e["unit"]["slot"]] = e["amount"]
	for c in cases:
		check_eq(got.get(c[0], -1), expect[c[0]], "기대 피해 = 실제 피해: %s" % c[3])
	# 전열 방어·방어: 적이 프론트 가드 아래 방어 중인 전열 대원을 친다.
	var tap := Fx.enemy_skill("skill.enemy.t_hit100", "damage", "enemy_one", {}, {"power": 100})
	var brute := Fx.enemy("enemy.t_brute100", 999, [50, 10, 10, 10, 1, 10], [[{}, [["skill.enemy.t_hit100", 1, "lowest_hp"]]]])
	defs = Fx.battle_defs(Fx.test_files([tap], [brute], {"b": [["enemy.t_brute100", "front"]]}), Fx.EXACT)
	s = Fx.battle(defs, "formation.t.b", 1)
	b = s.battle
	s.party.members[1].hp = 30
	b.party[1].guarding = true
	b.front_guard["party"] = 600
	var exp_fg := BattlePolicy.expected_damage(s, b.enemies[0], defs.battle.skill("skill.enemy.t_hit100"), b.party[1])
	b.party[1].guarding = false
	b.front_guard.clear()
	ev = BattleRules.submit(s, Fx.cmds(s, {0: Fx.use("skill.holo_knight.front_guard", 0)}))
	var hits := Fx.of_type(ev, "damaged").filter(func(e): return e["unit"]["side"] == "enemy")
	check(hits.size() == 1 and hits[0]["target"]["slot"] == 1, "대원 1 이 맞음")
	if hits.size() == 1:
		check_eq(hits[0]["amount"], exp_fg, "기대 피해 = 실제 피해: 방어 × 전열 방어 600")
		check(hits[0]["calc"]["front_guard"] < hits[0]["calc"]["guard"] and hits[0]["calc"]["guard"] < hits[0]["calc"]["def_mul"], "두 보정이 실제로 줄임")
