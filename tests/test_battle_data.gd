extends TestCase
## 전투 정의 데이터 읽기·검사(06 §5, §10.1 「데이터 검사」).

const Fx := preload("res://tests/fixtures.gd")

const ES := "skills/enemy.json"
const EN := "enemies/stratum1.json"
const ENC := "encounters/f1_test.json"
const RULES := "rules/battle.json"
const DU := "classes/blade_duelist.json"


func _errors_after(mutate: Callable) -> Array[String]:
	var files := Fx.battle_files()
	mutate.call(files)
	return Fx.battle_db(files).errors


## 고친 정의가 거부되고, 오류에 파일·필드 경로(needle)가 들어 있는지.
func _rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _errors_after(mutate)
	var found := false
	for e in errs:
		if e.contains(needle):
			found = true
	check(found, "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _party_errors(mutate: Callable, text_db: TextDb = null) -> Array[String]:
	var p := Fx.party_dict()
	mutate.call(p)
	var party := PartyData.parse_dict(JSON.parse_string(JSON.stringify(p)), "test_party.json")
	return GameDefs.from_parts(Fx.floors(), party, Fx.battle_db(Fx.battle_files()), text_db).errors


func _has(errs: Array[String], needle: String, label: String) -> void:
	var found := false
	for e in errs:
		if e.contains(needle):
			found = true
	check(found, "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func test_real_data_loads_without_errors_or_warnings() -> void:
	var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, "res://data/party/test_party.json", "res://data", TextDb.load_path("res://data/text/ko.json"))
	check_eq(r.errors, [] as Array[String], "오류 0")
	check_eq(r.warnings, [] as Array[String], "경고 0")
	check(r.ok(), "defs 있음")
	var db := r.defs.battle
	check_eq(db.class_ids.size(), 6, "직업 여섯(M3 A7: 레일 레인저·헥스 해커)")
	check_eq(db.enemy_ids.size(), 9, "적 아홉(일반 여섯 + FOE 셋, M3 A6)")
	check_eq(db.table_formations("encounter.f1_test").size(), 6, "편성 여섯")
	check_eq(r.defs.first_floor().encounter_table, "encounter.f1_test", "층 출현 표")
	check_eq(r.defs.party.ids, ["holo_knight", "blade_duelist", "blade_duelist_2", "nano_medic", "glyph_wizard"] as Array[String], "D12 파티")
	var ms := r.defs.members()
	check_eq(ms.map(func(m): return m.max_hp), [60, 52, 52, 42, 40], "최대 HP 는 직업 레벨 표(시작 파티 Lv1)")
	check_eq(ms.map(func(m): return m.max_tp), [30, 32, 32, 54, 60], "최대 TP")
	var hs: BattleDb.SkillDef = db.skill("skill.blade_duelist.high_slash")
	check_eq([hs.effect, hs.range_kind, hs.target, hs.parts, hs.speed, hs.levels[0]["power"], hs.levels[0]["tp"]],
		["damage", "melee", "enemy_one", ["arm"] as Array[String], 1000, 150, 4], "하이 슬래시 정의")
	check_eq(db.rules.damage_roll, [950, 1050] as Array[int], "규칙 상수")
	check_eq(db.classes["class.nano_medic"].attack.element, "bash", "일반 공격 속성")


func test_members_are_new_objects_each_call() -> void:
	var defs := Fx.battle_defs()
	var a := defs.members()
	var b := defs.members()
	a[0].hp = 1
	a[0].tp = 0
	check_eq(b[0].hp, 60, "다른 목록은 그대로")
	check_eq(b[0].tp, 30, "TP 도 그대로")
	check_eq(defs.members()[0].hp, 60, "다시 불러도 가득")
	check(a[0] != b[0], "다른 객체")
	check_eq([defs.party.levels[0], defs.party.skills[0].size(), defs.party.equips[0][0]], [1, 3, "equip.training_sword"], "정의 그대로")


func test_party_max_values_come_from_class_table() -> void:
	var p := PartyData.read_path("res://data/party/test_party.json")
	check_eq(p.errors, [] as Array[String], "오류 없음")
	var r := GameDefs.from_parts(Fx.floors(), p, BattleDb.load_dir("res://data"))
	check(r.ok(), "정의 %s" % str(r.errors))
	var m := r.defs.members()
	check_eq(m.size(), 5, "다섯")
	check_eq([m[2].id, m[2].max_hp, m[2].hp, m[2].max_tp, m[2].tp], ["blade_duelist_2", 52, 52, 32, 32], "칸 2")


func test_floor_keeps_encounter_table_and_checks_format() -> void:
	var f := Fx.floor_of(Fx.row_grid("..", " "), {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5, "table": "encounter.x"}})
	check_eq(f.encounter_table, "encounter.x", "table 보존")
	check_eq(Fx.floor_of(Fx.row_grid("..", " ")).encounter_table, "", "없으면 빈 문자열")
	var r := Fx.parse(Fx.floor_dict(Fx.row_grid("..", " "), {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5, "table": 3}}))
	check(not r.ok(), "문자열이 아니면 거부")
	r = Fx.parse(Fx.floor_dict(Fx.row_grid("..", " "), {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5, "table": "formation.x"}}))
	check(not r.ok(), "encounter. 접두사가 아니면 거부")
	r = Fx.parse(Fx.floor_dict(Fx.row_grid("..", " "), {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5, "table": "encounter.x\n"}}))
	check(not r.ok(), "끝 줄바꿈은 ID 형식이 아니다")


func test_game_defs_checks_floor_table_reference() -> void:
	var db := Fx.battle_db(Fx.battle_files())
	var none := Fx.floor_of(Fx.row_grid("..", " "))
	var r := GameDefs.from_parts(Fx.set_of(none), PartyData.parse_dict(Fx.party_dict(), "p.json"), db)
	_has(r.errors, "encounter.table: 층에 출현 표가 없다", "게임용은 표 없는 층 거부")
	check(GameDefs.from_parts(Fx.set_of(none), PartyData.parse_dict(Fx.party_dict(), "p.json"), db, null, false).ok(), "시험용(require_table 거짓)은 받음")
	var bad := Fx.floor_of(Fx.row_grid("..", " "), {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5, "table": "encounter.nope"}})
	r = GameDefs.from_parts(Fx.set_of(bad), PartyData.parse_dict(Fx.party_dict(), "p.json"), db)
	_has(r.errors, "없는 출현 표 encounter.nope", "없는 표")


func test_name_keys_must_exist_in_text() -> void:
	var texts := TextDb.load_path("res://data/text/ko.json")
	check_eq(_party_errors(func(_p): pass, texts), [] as Array[String], "실제 문구는 모두 있음")
	_has(_party_errors(func(p): p["members"][0]["name_key"] = "member.nope", texts), "ko.json: member.nope", "대원 name_key")
	var files := Fx.battle_files()
	files[EN]["enemies"][0]["name_key"] = "enemy.nope"
	var r := GameDefs.from_parts(Fx.floors(), PartyData.parse_dict(Fx.party_dict(), "p.json"), Fx.battle_db(files), texts)
	_has(r.errors, "ko.json: enemy.nope", "적 name_key")


func test_type_checks() -> void:
	_rejects("소수", func(f): f[ES]["skills"][0]["levels"][0]["power"] = 1.5, "%s: skills[0].levels[0].power:" % ES)
	_rejects("불리언", func(f): f[EN]["enemies"][0]["max_hp"] = true, "%s: enemies[0].max_hp:" % EN)
	_rejects("문자열", func(f): f[DU]["levels"]["1"]["hp"] = "52", "%s: levels.1.hp:" % DU)
	_rejects("필수 필드", func(f): f[ES]["skills"][1].erase("speed"), "%s: skills[1].speed: 필수 필드가 없다" % ES)
	_rejects("모르는 필드", func(f): f[EN]["enemies"][2]["colour"] = "red", "%s: enemies[2].colour: 모르는 필드" % EN)
	_rejects("모르는 필드(줄)", func(f): f[ES]["skills"][0]["levels"][0]["powr"] = 3, "%s: skills[0].levels[0].powr: 모르는 필드" % ES)
	_rejects("모르는 필드(규칙)", func(f): f[RULES]["defence_k"] = 100, "%s: defence_k: 모르는 키" % RULES)
	_rejects("맨 위가 객체 아님", func(f): f["items/materials.json"] = [], "items/materials.json: (맨 위): 맨 위가 객체가 아니다")


func test_id_checks() -> void:
	_rejects("형식", func(f): f[ES]["skills"][0]["id"] = "skill.enemy.Bite", "%s: skills[0].id: ID 형식" % ES)
	_rejects("끝 줄바꿈", func(f): f[ES]["skills"][0]["id"] = "skill.enemy.bite\n", "%s: skills[0].id: ID 형식" % ES)
	_rejects("참조 끝 줄바꿈", func(f): f[ENC]["table"][0]["formation"] = "formation.f1.rats\n", "%s: table[0].formation:" % ENC)
	_has(_party_errors(func(p): p["members"][1]["id"] = "blade_duelist\n"), "members[1].id: 대원 ID 형식", "대원 ID 끝 줄바꿈")
	_rejects("접두사", func(f): f[DU]["id"] = "klass.blade_duelist", "%s: id: class. 로 시작" % DU)
	_rejects("적 스킬 접두사", func(f): f[ES]["skills"][0]["id"] = "skill.rat.bite", "%s: skills[0].id: 적 스킬 ID" % ES)
	_rejects("중복", func(f): f[EN]["enemies"][1]["id"] = "enemy.neon_rat", "%s: enemies[1].id: ID enemy.neon_rat 가 중복" % EN)
	_rejects("직업의 스킬 참조", func(f): f[DU]["tree"][0]["skill"] = "skill.blade_duelist.nope", "%s: class.blade_duelist.tree[0].skill: 없는 스킬" % DU)
	_rejects("적 AI 스킬 참조", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["skill"] = "skill.enemy.nope", "%s: enemy.neon_rat.ai[0].use[0].skill: 없는 스킬" % EN)
	_rejects("편성의 적 참조", func(f): f[ENC]["formations"][0]["enemies"][0]["enemy"] = "enemy.nope", "%s: formation.f1.rats.enemies[0].enemy: 없는 적" % ENC)
	_rejects("출현 표의 편성 참조", func(f): f[ENC]["table"][0]["formation"] = "formation.f1.nope", "%s: table[0].formation: formation.f1.nope 이 이 파일의 formations 에 없다" % ENC)
	_rejects("드롭 소재 참조", func(f): f[EN]["enemies"][0]["drops"][0]["item"] = "item.nope", "%s: enemy.neon_rat.drops[0].item: 없는 소재" % EN)
	_rejects("charges 참조", func(f): f[ES]["skills"][11]["charges"] = "skill.enemy.nope", "%s: skill.enemy.raise_pincers.charges: 없는 스킬" % ES)
	_has(_party_errors(func(p): p["members"][1]["class"] = "class.nope"), "test_party.json: members[1].class: 없는 직업", "파티 직업 참조")
	_has(_party_errors(func(p): p["members"][1]["skills"]["skill.holo_knight.front_guard"] = 1), "members[1].skills.skill.holo_knight.front_guard: class.blade_duelist 트리에 없는 스킬이다", "파티 스킬 참조")


func test_enum_checks() -> void:
	_rejects("능력치", func(f): f[ES]["skills"][0]["stat"] = "AGI", "%s: skills[0].stat:" % ES)
	_rejects("속성", func(f): f[ES]["skills"][0]["element"] = "dark", "%s: skills[0].element:" % ES)
	_rejects("상태이상", func(f): f[ES]["skills"][2]["levels"][0]["ailment"]["id"] = "petrify", "%s: skills[2].levels[0].ailment.id:" % ES)  # M3 A7: blind 는 이제 있는 상태다
	_rejects("부위", func(f): f[ES]["skills"][7]["levels"][0]["bind"]["part"] = "tail", "%s: skills[7].levels[0].bind.part:" % ES)
	_rejects("parts 부위", func(f): f[ES]["skills"][0]["parts"] = ["tail"], "%s: skills[0].parts:" % ES)
	_rejects("effect", func(f): f[ES]["skills"][0]["effect"] = "explode", "%s: skills[0].effect:" % ES)
	_rejects("target", func(f): f[ES]["skills"][0]["target"] = "everyone", "%s: skills[0].target:" % ES)
	_rejects("effect 와 target", func(f): f[ES]["skills"][0]["target"] = "ally_one", "%s: skills[0].target: effect damage 에는" % ES)
	_rejects("range", func(f): f[ES]["skills"][0]["range"] = "far", "%s: skills[0].range:" % ES)
	_rejects("priority", func(f): f[ES]["skills"][0]["priority"] = "fast", "%s: skills[0].priority:" % ES)
	_rejects("user", func(f): f[ES]["skills"][0]["user"] = "boss", "%s: skills[0].user:" % ES)
	_rejects("kind", func(f): f[ES]["skills"][1]["levels"][0]["kind"] = "speed", "%s: skills[1].levels[0].kind:" % ES)
	_rejects("on_bound", func(f): f[EN]["enemies"][0]["on_bound"] = "flee", "%s: enemies[0].on_bound:" % EN)
	_rejects("AI 조건 키", func(f): f[EN]["enemies"][5]["ai"][1]["if"] = {"turn_is": 2}, "%s: enemies[5].ai[1].if.turn_is: 모르는 조건" % EN)
	_rejects("드롭 조건 키", func(f): f[EN]["enemies"][1]["drops"][1]["if"] = {"killed_on_turn": 2}, "%s: enemies[1].drops[1].if.killed_on_turn: 모르는 조건" % EN)
	_rejects("AI 대상 정책", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["target"] = "highest_hp", "%s: enemies[0].ai[0].use[0].target:" % EN)
	_rejects("열", func(f): f[ENC]["formations"][0]["enemies"][0]["row"] = "middle", "%s: formations[0].enemies[0].row:" % ENC)


func test_common_range_checks() -> void:
	_rejects("최대 HP 0", func(f): f[EN]["enemies"][0]["max_hp"] = 0, "%s: enemies[0].max_hp: 정수 1~9999" % EN)
	_rejects("최대 HP 10000", func(f): f[DU]["levels"]["1"]["hp"] = 10000, "%s: levels.1.hp: 정수 1~9999" % DU)
	_rejects("TP 0", func(f): f[DU]["levels"]["1"]["tp"] = 0, "%s: levels.1.tp: 정수 1~9999" % DU)
	_rejects("능력치 1000", func(f): f[EN]["enemies"][0]["stats"]["STR"] = 1000, "%s: enemies[0].stats.STR: 정수 1~999" % EN)
	_rejects("능력치 0", func(f): f[DU]["levels"]["1"]["AGI"] = 0, "%s: levels.1.AGI: 정수 1~999" % DU)
	_rejects("속성 배율 3001", func(f): f[EN]["enemies"][0]["resist"]["fire"] = 3001, "%s: enemies[0].resist.fire: 정수 0~3000" % EN)
	_rejects("취약도 음수", func(f): f[DU]["bind_vuln"]["arm"] = -1, "%s: bind_vuln.arm: 정수 0~3000" % DU)
	_rejects("확률 1001", func(f): f[ES]["skills"][7]["levels"][0]["bind"]["chance"] = 1001, "%s: skills[7].levels[0].bind.chance: 정수 0~1000" % ES)
	_rejects("명중 1001", func(f): f[ES]["skills"][0]["levels"][0]["accuracy"] = 1001, "%s: skills[0].levels[0].accuracy: 정수 0~1000" % ES)
	_rejects("power 0", func(f): f[ES]["skills"][0]["levels"][0]["power"] = 0, "%s: skills[0].levels[0].power: 정수 1~2000" % ES)
	_rejects("power 2001", func(f): f[ES]["skills"][0]["levels"][0]["power"] = 2001, "%s: skills[0].levels[0].power: 정수 1~2000" % ES)
	_rejects("turns 0", func(f): f[ES]["skills"][2]["levels"][0]["ailment"]["turns"] = 0, "%s: skills[2].levels[0].ailment.turns: 정수 1~9" % ES)
	_rejects("turns 10", func(f): f[ES]["skills"][1]["levels"][0]["turns"] = 10, "%s: skills[1].levels[0].turns: 정수 1~9" % ES)
	_rejects("독 피해 0", func(f): f[ES]["skills"][2]["levels"][0]["ailment"]["damage"] = 0, "%s: skills[2].levels[0].ailment.damage: 정수 1~9999" % ES)
	_rejects("약화 방향", func(f): f[ES]["skills"][1]["levels"][0]["value"] = 900, "%s: skills[1].levels[0].value: debuff phys_def 는 정수 1001~3000" % ES)
	_rejects("강화 방향(def)", func(f): f["skills/holo_knight.json"]["skills"][2]["levels"][0]["value"] = 1000, "skills/holo_knight.json: skills[2].levels[0].value: buff phys_def 는 정수 1~999")
	_rejects("강화 방향(atk)", func(f): f["skills/blade_duelist.json"]["skills"][2]["levels"][0]["value"] = 999, "skills/blade_duelist.json: skills[2].levels[0].value: buff phys_atk 는 정수 1001~3000")
	_rejects("강화 값 3001", func(f): f["skills/blade_duelist.json"]["skills"][2]["levels"][0]["value"] = 3001, "skills/blade_duelist.json: skills[2].levels[0].value:")
	_rejects("프론트 가드 1001", func(f): f["skills/holo_knight.json"]["skills"][0]["levels"][0]["value"] = 1001, "skills/holo_knight.json: skills[0].levels[0].value: 정수 1~1000")
	_rejects("회복 base 1000", func(f): f["skills/nano_medic.json"]["skills"][0]["levels"][0]["base"] = 1000, "skills/nano_medic.json: skills[0].levels[0].base: 정수 0~999")
	_rejects("회복 wis_pct 1001", func(f): f["skills/nano_medic.json"]["skills"][0]["levels"][0]["wis_pct"] = 1001, "skills/nano_medic.json: skills[0].levels[0].wis_pct: 정수 0~1000")
	_rejects("소생 0", func(f): f["skills/nano_medic.json"]["skills"][2]["levels"][0]["hp_permille"] = 0, "skills/nano_medic.json: skills[2].levels[0].hp_permille: 정수 1~1000")
	_rejects("speed 99", func(f): f[ES]["skills"][0]["speed"] = 99, "%s: skills[0].speed: 정수 100~3000" % ES)
	_rejects("speed 3001", func(f): f[ES]["skills"][0]["speed"] = 3001, "%s: skills[0].speed: 정수 100~3000" % ES)
	_has(_party_errors(func(p): p["members"][0]["equip"].pop_back()), "members[0].equip: 길이 4 의 배열", "장비 칸 셋")
	_has(_party_errors(func(p): p["members"][0]["equip"][3] = "equip.nope"), "members[0].equip[3]: 없는 장비 equip.nope", "모르는 장비 ID")
	_has(_party_errors(func(p): p["members"][0]["gear"] = {"atk": 8, "matk": 0, "def": 10, "mdef": 4}), "members[0].gear: 모르는 필드", "2판 이전 파티 형식의 gear")


func test_other_range_checks() -> void:
	_rejects("가중치 0", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["weight"] = 0, "%s: enemies[0].ai[0].use[0].weight: 정수 1~1000" % EN)
	_rejects("가중치 1001", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["weight"] = 1001, "%s: enemies[0].ai[0].use[0].weight: 정수 1~1000" % EN)
	_rejects("후보 0개", func(f): f[EN]["enemies"][0]["ai"][0]["use"] = [], "%s: enemies[0].ai[0].use: 후보 1~8" % EN)
	var nine := func(f):
		var u: Array = f[EN]["enemies"][0]["ai"][0]["use"]
		for i in 7:
			u.append(u[0].duplicate())
	_rejects("후보 9개", nine, "%s: enemies[0].ai[0].use: 후보 1~8" % EN)
	_rejects("출현 표 0개", func(f): f[ENC]["table"] = [], "%s: table: 항목 1~32" % ENC)
	var many := func(f):
		var t: Array = f[ENC]["table"]
		while t.size() < 33:
			t.append(t[0].duplicate())
	_rejects("출현 표 33개", many, "%s: table: 항목 1~32" % ENC)
	_rejects("출현 가중치 0", func(f): f[ENC]["table"][0]["weight"] = 0, "%s: table[0].weight: 정수 1~1000" % ENC)
	_rejects("turn_mod n 0", func(f): f[EN]["enemies"][5]["ai"][1]["if"]["turn_mod"] = [0, 0], "%s: enemies[5].ai[1].if.turn_mod:" % EN)
	_rejects("turn_mod n 100", func(f): f[EN]["enemies"][5]["ai"][1]["if"]["turn_mod"] = [100, 2], "%s: enemies[5].ai[1].if.turn_mod:" % EN)
	_rejects("turn_mod r ≥ n", func(f): f[EN]["enemies"][5]["ai"][1]["if"]["turn_mod"] = [3, 3], "%s: enemies[5].ai[1].if.turn_mod:" % EN)
	_rejects("hp_below 0", func(f): f[EN]["enemies"][5]["ai"][1]["if"] = {"hp_below": 0}, "%s: enemies[5].ai[1].if.hp_below: 정수 1~1000" % EN)
	_rejects("hp_below 1001", func(f): f[EN]["enemies"][5]["ai"][1]["if"] = {"hp_below": 1001}, "%s: enemies[5].ai[1].if.hp_below: 정수 1~1000" % EN)


func test_rule_constant_checks() -> void:
	_rejects("defense_k 49", func(f): f[RULES]["defense_k"] = 49, "%s: defense_k: 정수 50~200" % RULES)
	_rejects("defense_k 201", func(f): f[RULES]["defense_k"] = 201, "%s: defense_k: 정수 50~200" % RULES)
	var flip := func(f):
		f[RULES]["hit_min"] = 900
		f[RULES]["hit_max"] = 800
	_rejects("hit_min > hit_max", flip, "%s: hit_min: hit_min <= hit_max" % RULES)
	_rejects("crit_mult 999", func(f): f[RULES]["crit_mult"] = 999, "%s: crit_mult:" % RULES)
	_rejects("damage_roll lo 499", func(f): f[RULES]["damage_roll"] = [499, 1050], "%s: damage_roll:" % RULES)
	_rejects("speed_roll hi 1501", func(f): f[RULES]["speed_roll"] = [900, 1501], "%s: speed_roll:" % RULES)
	_rejects("escape_clamp lo > hi", func(f): f[RULES]["escape_clamp"] = [900, 800], "%s: escape_clamp: lo <= hi" % RULES)
	_rejects("resist_max 1000", func(f): f[RULES]["resist_max"] = 1000, "%s: resist_max: 정수 0~999" % RULES)
	_rejects("칸 0", func(f): f[RULES]["buff_slots"] = 0, "%s: buff_slots: 정수 1~5" % RULES)
	_rejects("칸 6", func(f): f[RULES]["debuff_slots"] = 6, "%s: debuff_slots: 정수 1~5" % RULES)
	_rejects("줄이기 배율 1001", func(f): f[RULES]["guard_mult"] = 1001, "%s: guard_mult: 정수 0~1000" % RULES)
	_rejects("빠진 키", func(f): f[RULES].erase("escape_agi"), "%s: escape_agi: 필수 키가 없다" % RULES)
	_rejects("소수 상수", func(f): f[RULES]["status_luck"] = 2.5, "%s: status_luck:" % RULES)
	_rejects("구간 원소 수", func(f): f[RULES]["damage_roll"] = [950], "%s: damage_roll: 정수 두 개" % RULES)
	_rejects("규칙 파일 없음", func(f): f.erase(RULES), "%s: 파일이 없다" % RULES)
	# 기본값 밖이지만 허용 범위 안인 상수는 받는다(06 §11.4).
	var edge := {"defense_k": 200, "buff_slots": 5, "debuff_slots": 5, "damage_roll": [500, 1500], "speed_roll": [1000, 1000],
		"crit_mult": 3000, "hit_min": 0, "resist_max": 999, "escape_clamp": [0, 1000], "status_luck_clamp": [0, 3000]}
	var db := Fx.battle_db(Fx.battle_files({}, edge))
	check_eq(db.errors, [] as Array[String], "범위 끝 상수 받음")
	check_eq([db.rules.defense_k, db.rules.buff_slots, db.rules.damage_roll, db.rules.status_luck_clamp], [200, 5, [500, 1500] as Array[int], [0, 3000] as Array[int]], "읽은 값")
	check_eq(Fx.battle_db(Fx.battle_files({}, {"defense_k": 50})).errors, [] as Array[String], "defense_k 50")


func test_relation_checks() -> void:
	_rejects("levels 없음", func(f): f[ES]["skills"][0]["levels"] = [], "%s: skills[0].levels: 줄이 하나 이상" % ES)
	_rejects("직업 레벨 키", func(f): f[DU]["levels"] = {"01": f[DU]["levels"]["1"]}, "%s: levels.01: 레벨 키" % DU)
	var seven := func(f):
		var e: Array = f[ENC]["formations"][0]["enemies"]
		while e.size() < 7:
			e.append({"enemy": "enemy.neon_rat", "row": "back"})
	_rejects("편성 적 7", seven, "%s: formations[0].enemies: 적 1~6" % ENC)
	_rejects("한 줄 넷", func(f): f[ENC]["formations"][0]["enemies"].append({"enemy": "enemy.neon_rat", "row": "front"}), "%s: formations[0].enemies: front 줄의 적이 3" % ENC)
	_rejects("마지막 규칙 조건", func(f): f[EN]["enemies"][0]["ai"][0]["if"] = {"hp_below": 500}, "%s: enemies[0].ai[0].if: 마지막 규칙의 if 는 빈 객체" % EN)
	_rejects("마지막 아닌 규칙 조건 없음", func(f): f[EN]["enemies"][5]["ai"][1]["if"] = {}, "%s: enemies[5].ai[1].if: 마지막이 아닌 규칙은" % EN)
	_rejects("AI 후보 user", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["skill"] = "skill.blade_duelist.high_slash", "%s: enemy.neon_rat.ai[0].use[0].skill: skill.blade_duelist.high_slash 의 user 가 enemy 가 아니다" % EN)
	_rejects("AI 후보 필드", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0].erase("target"), "%s: enemies[0].ai[0].use[0].target: 필수 필드가 없다" % EN)
	_rejects("charging 규칙에 강공격 없음", func(f): f[EN]["enemies"][5]["ai"][0]["use"][0]["skill"] = "skill.enemy.claw", "%s: enemy.clamp_beetle.ai[0].if.charging:" % EN)
	_rejects("charging 규칙에 charge 스킬 없음", func(f): f[EN]["enemies"][5]["ai"][1]["use"][0]["skill"] = "skill.enemy.claw", "%s: enemy.clamp_beetle.ai[0].if.charging:" % EN)
	_rejects("직업 스킬 user", func(f): f[DU]["tree"][0]["skill"] = "skill.enemy.bite", "%s: class.blade_duelist.tree[0].skill: skill.enemy.bite 의 user 가 party 가 아니다" % DU)
	_rejects("파티 스킬 tp 0", func(f): f["skills/blade_duelist.json"]["skills"][0]["levels"][0]["tp"] = 0, "skills/blade_duelist.json: skills[0].levels[0].tp: 파티 스킬의 tp 는 1 이상")
	_rejects("적 스킬 tp 1", func(f): f[ES]["skills"][0]["levels"][0]["tp"] = 1, "%s: skills[0].levels[0].tp: 적 스킬의 tp 는 0" % ES)
	_rejects("effect 별 필드(heal 에 element)", func(f): f["skills/nano_medic.json"]["skills"][0]["element"] = "fire", "skills/nano_medic.json: skills[0].element: 모르는 필드")
	_rejects("effect 별 필드(buff 에 power)", func(f): f["skills/blade_duelist.json"]["skills"][2]["levels"][0]["power"] = 100, "skills/blade_duelist.json: skills[2].levels[0].power: 모르는 필드")
	_rejects("독이 아닌 상태에 damage", func(f): f[ES]["skills"][4]["levels"][0]["ailment"]["damage"] = 3, "%s: skills[4].levels[0].ailment.damage: 모르는 필드" % ES)
	_rejects("독에 damage 없음", func(f): f[ES]["skills"][2]["levels"][0]["ailment"].erase("damage"), "%s: skills[2].levels[0].ailment.damage: 필수 필드가 없다" % ES)
	_rejects("필중이 아닌 ailment 에 accuracy 없음", func(f): f[ES]["skills"][2]["sure_hit"] = false, "%s: skills[2].levels[0].accuracy: 필수 필드가 없다" % ES)
	# 쓰는 쪽과 effect 조합(USER_EFFECTS): M2 가 수명 주기를 정하지 않은 조합은 읽기에서 막는다.
	var revive := Fx.enemy_skill("skill.enemy.t_revive", "revive", "ally_dead", {}, {"hp_permille": 500})
	_rejects("적 revive", func(f): f[ES]["skills"].append(revive), "%s: skills[13].effect: user enemy 에는 effect revive 를 쓸 수 없다" % ES)
	var bd_next: int = Fx.data_files()["skills/blade_duelist.json"]["skills"].size()  # 듀얼리스트 파일에 덧붙인 스킬의 칸
	var charge: Dictionary = Fx.data_files()[ES]["skills"][11].duplicate(true)
	charge.merge({"id": "skill.blade_duelist.t_charge", "user": "party", "levels": [{"tp": 1}]}, true)
	_rejects("파티 charge", func(f): f["skills/blade_duelist.json"]["skills"].append(charge), "skills/blade_duelist.json: skills[%d].effect: user party 에는 effect charge 를 쓸 수 없다" % bd_next)
	# M3 A7: 파티 debuff(헥스 해커)는 받는다. 값은 적 debuff 와 같은 범위로 본다: 강화 쪽 값(방어 750)은 거부.
	_rejects("파티 debuff 에 강화 값", func(f): f["skills/blade_duelist.json"]["skills"].append(Fx.effect_skill("skill.blade_duelist.t_howl", false, [["phys_def", 750, 3]]).merged({"user": "party", "effect": "debuff", "target": "enemy_one"}, true)),
		"skills/blade_duelist.json: skills[%d].levels[0].value: debuff phys_def 는" % bd_next)
	_rejects("적 buff", func(f): f[ES]["skills"].append(Fx.effect_skill("skill.enemy.t_pump", true, [["phys_atk", 1300, 3]]).merged({"effect": "buff", "target": "self"}, true)),
		"%s: skills[13].effect: user enemy 에는 effect buff 를" % ES)
	for e in ["cure", "cover", "front_guard"]:
		var d: Dictionary = {}
		for sk in Fx.data_files()["skills/nano_medic.json"]["skills"] + Fx.data_files()["skills/holo_knight.json"]["skills"]:
			if sk["effect"] == e:
				d = sk.duplicate(true)
		d.merge({"id": "skill.enemy.t_" + e, "user": "enemy"}, true)
		for row in d["levels"]:
			row["tp"] = 0
		_rejects("적 " + e, func(f): f[ES]["skills"].append(d), "%s: skills[13].effect: user enemy 에는 effect %s 를" % [ES, e])
	# 강화·약화는 모든 줄의 kind 가 같아야 한다(06 §5.4).
	var mixed := Fx.effect_skill("skill.t.mixed", false, [["phys_atk", 1300, 3], ["phys_def", 500, 3]])
	_rejects("강화 줄마다 다른 kind", func(f): f["skills/blade_duelist.json"]["skills"].append(mixed), "skills/blade_duelist.json: skills[%d].levels[1].kind: buff 스킬은 모든 줄의 kind 가 같아야 한다" % bd_next)
	var mixed_d := Fx.effect_skill("skill.enemy.t_mixed", true, [["phys_def", 1300, 3], ["elem_def", 1300, 3], ["phys_def", 1200, 3]])
	_rejects("약화 줄마다 다른 kind", func(f): f[ES]["skills"].append(mixed_d), "%s: skills[13].levels[1].kind: debuff 스킬은" % ES)
	var same := Fx.effect_skill("skill.t.same", false, [["phys_atk", 1300, 3], ["phys_atk", 1100, 5]])
	check(not "\n".join(_errors_after(func(f): f["skills/blade_duelist.json"]["skills"].append(same))).contains("kind"), "같은 kind 여러 줄은 받음")
	_has(_party_errors(func(p): p["members"].pop_back()), "test_party.json: members: 대원은 5명", "파티 넷")
	_has(_party_errors(func(p): p["members"][3]["row"] = "front"), "test_party.json: members: front 줄이 3명을 넘는다", "한 줄 넷")
	_has(_party_errors(func(p): p["members"][2]["id"] = "blade_duelist"), "members[2].id: 대원 ID blade_duelist 가 중복", "대원 ID 중복")
	_has(_party_errors(func(p): p["members"][1]["skills"]["skill.blade_duelist.high_slash"] = 6), "members[1].skills.skill.blade_duelist.high_slash: 스킬 레벨 6 이 1~최대 레벨 5 이 아니다", "스킬 레벨 > 줄 수")
	_has(_party_errors(func(p): p["members"][1]["skills"]["skill.blade_duelist.high_slash"] = 2), "members[1].skills: 배운 스킬 레벨의 합 4 이 얻은 SP 3 을 넘는다", "시작 배분 SP 초과(Lv1 SP 3)")
	_has(_party_errors(func(p): p["members"][1]["level"] = 31), "members[1].level: 레벨 31 이 level_cap 30 을 넘는다", "레벨 상한 초과")
	_has(_party_errors(func(p): p["members"][1]["max_hp"] = 52), "members[1].max_hp: 모르는 필드", "M1 의 max_hp 는 없앰")


func test_unused_definitions_are_warnings_not_errors() -> void:
	var files := Fx.battle_files(Fx.test_files([], [], {"r": [["enemy.neon_rat", "front"]]}))
	files["encounters/extra.json"] = {"id": "encounter.extra", "formations": [{"id": "formation.x.lonely", "no_escape": false, "enemies": [{"enemy": "enemy.neon_rat", "row": "front"}]}],
		"table": [{"formation": "formation.x.lonely", "weight": 1}]}
	files["encounters/extra.json"]["formations"].append({"id": "formation.x.untabled", "no_escape": false, "enemies": [{"enemy": "enemy.neon_rat", "row": "front"}]})
	var db := Fx.battle_db(files)
	check_eq(db.errors, [] as Array[String], "오류 아님")
	var w := "\n".join(db.warnings)
	check(w.contains("formation.x.untabled: 어느 출현 표에도 없는 편성"), "표에 없는 편성 경고: " + w)
	check(w.contains("enemy.t_dummy: 어느 출현 표의 편성에도 없는 적"), "편성에 없는 적 경고: " + w)
	files[ES]["skills"].append(Fx.enemy_skill("skill.enemy.unused", "damage", "enemy_one"))
	check("\n".join(Fx.battle_db(files).warnings).contains("skill.enemy.unused: 어느 직업·적도 쓰지 않는 스킬"), "안 쓰는 스킬 경고")


func test_limit_helpers_boundaries() -> void:
	# 범위 도우미(BattleLimits) 자체의 경계값. 정의·저장이 같은 함수를 쓰는지는 test_battle_data 의 범위 검사와 test_battle_save 가 본다.
	check(BattleLimits.in_range("turns", 1) and BattleLimits.in_range("turns", 9) and not BattleLimits.in_range("turns", 10), "turns 1~9")
	check(not BattleLimits.in_range("turns", 1.0), "실수는 정수가 아니다")
	check(BattleLimits.effect_value_ok(false, "phys_def", 1) and not BattleLimits.effect_value_ok(false, "phys_def", 1000), "방어 강화 1~999")
	check(BattleLimits.effect_value_ok(false, "elem_atk", 3000) and not BattleLimits.effect_value_ok(false, "elem_atk", 1000), "공격 강화 1001~3000")
	check(BattleLimits.effect_value_ok(true, "phys_atk", 1) and BattleLimits.effect_value_ok(true, "phys_def", 3000), "약화는 반대")
	check(BattleLimits.resist_ok(900, 900) and not BattleLimits.resist_ok(0, 900) and not BattleLimits.resist_ok(901, 900), "누적 내성 1~resist_max")
	check_eq(BattleLimits.check_rules(_int_rules()), [] as Array[String], "M2 기본 상수는 통과")


func _int_rules() -> Dictionary:
	var d: Dictionary = Fx.data_files()[RULES]
	var out := {}
	for k in d:
		if typeof(d[k]) == TYPE_ARRAY:
			out[k] = [int(d[k][0]), int(d[k][1])]
		else:
			out[k] = int(d[k])
	return out
