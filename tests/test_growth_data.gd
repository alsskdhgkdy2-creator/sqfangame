extends TestCase
## 성장 정의 읽기·검사(07 §7, §10.1 「데이터 검사」): 성장 규칙·레벨 표·트리·패시브·장비·시작 파티. 틀린 사례마다 파일·필드 경로가 오류에 있다.

const Fx := preload("res://tests/fixtures.gd")

const GR := "rules/growth.json"
const HK := "classes/holo_knight.json"
const HKS := "skills/holo_knight.json"
const BDS := "skills/blade_duelist.json"
const EQ := "items/equipment.json"


func _errors_after(mutate: Callable) -> Array[String]:
	var files := Fx.battle_files()
	mutate.call(files)
	return Fx.battle_db(files).errors


func _rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _errors_after(mutate)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _party_rejects(label: String, mutate: Callable, needle: String) -> void:
	var p := Fx.party_dict()
	mutate.call(p)
	var party := PartyData.parse_dict(JSON.parse_string(JSON.stringify(p)), "test_party.json")
	var errs := GameDefs.from_parts(Fx.floors(), party, Fx.battle_db(Fx.battle_files())).errors
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


## 파일의 목록에서 id 가 그것인 항목의 칸.
func _index(files: Dictionary, path: String, key: String, id: String) -> int:
	var list: Array = files[path][key]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


func _skill(f: Dictionary, path: String, id: String) -> Dictionary:
	return f[path]["skills"][_index(f, path, "skills", id)]


func _equip(f: Dictionary, id: String) -> Dictionary:
	return f[EQ]["equipment"][_index(f, EQ, "equipment", id)]


func test_real_growth_data() -> void:
	var db := BattleDb.load_dir(Fx.DATA_DIR)
	check(db.ok(), "오류 0: %s" % str(db.errors))
	check_eq(db.warnings, [] as Array[String], "경고 0")
	var g := db.growth
	check_eq([g.level_cap, g.initial_sp, g.sp_per_level, g.exp_next.size()], [30, 3, 1, 29], "성장 규칙")
	check_eq([2, 3, 4, 5, 6, 10, 15, 20, 25, 30].map(func(l): return g.cum(l)), [30, 115, 271, 511, 846, 3332, 9599, 20141, 35643, 56709], "누적 경험치 표(07 §3.2)")
	var hk: BattleDb.ClassDef = db.classes["class.holo_knight"]
	check_eq([hk.levels[2]["hp"], hk.levels[2]["tp"], hk.levels[2]["VIT"], hk.levels[11]["hp"], hk.levels[11]["VIT"]], [64, 31, 20, 101, 29], "홀로나이트 표본(07 §3.3)")
	var gw: BattleDb.ClassDef = db.classes["class.glyph_wizard"]
	check_eq(BattleLimits.STATS.map(func(k): return gw.levels[25][k]), [13, 46, 15, 36, 23, 29], "글리프 위저드 Lv25 표본")
	check_eq([gw.levels[25]["hp"], gw.levels[25]["tp"]], [114, 127], "글리프 위저드 Lv25 HP·TP")
	for cid in db.class_ids:
		var c: BattleDb.ClassDef = db.classes[cid]
		check_eq(c.levels.size(), 30, "%s 레벨 표 30줄" % cid)
		check(c.tree.size() >= 6 and c.tree.size() <= 8, "%s 트리 6~8개(D17, M3 A7 해커 8)" % cid)
		check_eq(c.skills, c.tree.map(func(e): return e["skill"]), "%s: ClassDef.skills = 트리 순서" % cid)
	check_eq(db.equipment_ids.size(), 31, "장비 31종(M3 A5 채집 소재로 푸는 넷, M3 A7 활·총·머리 여섯을 더함, 01 §9)")
	check_eq(db.skill_ids.filter(func(id): return db.skill(id).passive()).size(), 7, "패시브 일곱(M3 A7 레인저 둘·해커 하나)")
	check_eq(db.skill_ids.filter(func(id): return db.skill(id).user == "party" and not db.skill(id).passive()).size(), 33, "액티브 33(M2 13 + 새 8, M3 A7 레인저 다섯·해커 일곱)")
	for sid in db.skill_ids:
		var s := db.skill(sid)
		if s.user == "party":
			check_eq(s.max_level(), 10 if s.passive() else 5, "%s 최대 레벨" % sid)
	var ion := db.equip("equip.ion_saber")
	check_eq([ion.kind, ion.element, ion.gear["atk"], ion.weapon()], ["sword", "volt", 22, true], "이온 세이버")
	check_eq(db.equip("equip.tactical_baton").only_classes, ["class.nano_medic", "class.holo_knight"] as Array[String], "only_classes")
	var a := db.skill("skill.holo_knight.photon_wall")
	check_eq([a.effect, a.target, a.levels[0]["kind"], a.levels[4]["value"]], ["buff", "ally_all", "elem_def", 650], "포톤 월")


func test_growth_rule_file_checks() -> void:
	_rejects("성장 규칙 파일 없음", func(f): f.erase(GR), "%s: 파일이 없다" % GR)
	_rejects("exp_next 길이", func(f): f[GR]["exp_next"].pop_back(), "%s: exp_next: 길이가 level_cap - 1" % GR)
	_rejects("exp_next 0", func(f): f[GR]["exp_next"][0] = 0, "%s: exp_next[0]: 정수 1~999999" % GR)
	_rejects("level_cap 1", func(f): f[GR]["level_cap"] = 1, "%s: level_cap: 정수 2~99" % GR)
	_rejects("sp_per_level 10", func(f): f[GR]["sp_per_level"] = 10, "%s: sp_per_level: 정수 0~9" % GR)
	_rejects("모르는 키", func(f): f[GR]["exp_divisor"] = 5, "%s: exp_divisor: 모르는 필드" % GR)
	_rejects("규칙 파일 셋째", func(f): f["rules/extra.json"] = {}, "rules/extra.json: (맨 위): 규칙 파일은")


func test_class_level_table_checks() -> void:
	_rejects("빠진 레벨", func(f): f[HK]["levels"].erase("15"), "%s: levels: 레벨 15 이 없다" % HK)
	_rejects("상한 넘는 레벨", func(f): f[HK]["levels"]["31"] = f[HK]["levels"]["30"].duplicate(), "%s: levels.31: level_cap 30 을 넘는" % HK)
	_rejects("hp 감소", func(f): f[HK]["levels"]["5"]["hp"] = 1, "%s: levels.5.hp: 앞 레벨보다 작다" % HK)
	_rejects("tp 감소", func(f): f[HK]["levels"]["9"]["tp"] = 1, "%s: levels.9.tp: 앞 레벨보다 작다" % HK)
	check(not "\n".join(_errors_after(func(f): f[HK]["levels"]["9"]["STR"] = 1)).contains("앞 레벨"), "능력치 6종은 줄어도 받는다")
	_rejects("equip_kinds 무기 없음", func(f): f[HK]["equip_kinds"] = ["shield", "body"], "%s: equip_kinds: 무기 종류" % HK)
	_rejects("equip_kinds 모르는 종류", func(f): f[HK]["equip_kinds"] = ["sword", "cape"], "%s: equip_kinds:" % HK)
	_rejects("2판 직업 형식의 skills", func(f): f[HK]["skills"] = [], "%s: skills: 모르는 필드" % HK)


func test_tree_checks() -> void:
	_rejects("남의 직업 스킬", func(f): f[HK]["tree"][0]["skill"] = "skill.blade_duelist.high_slash", "%s: class.holo_knight.tree[0].skill: skill.blade_duelist.high_slash 는 이 직업" % HK)
	_rejects("두 트리에 같은 스킬", func(f): f[HK]["tree"][0]["skill"] = "skill.blade_duelist.high_slash", "가 class.blade_duelist 트리에도 있다")
	_rejects("뒤를 가리키는 선행", func(f): f[HK]["tree"][4]["requires"] = [{"skill": "skill.holo_knight.photon_wall", "level": 1}],
		"%s: class.holo_knight.tree[4].requires[0].skill: 선행 skill.holo_knight.photon_wall 는 트리에서 앞에 나온 스킬" % HK)
	_rejects("자기 자신을 선행으로", func(f): f[HK]["tree"][4]["requires"] = [{"skill": "skill.holo_knight.shield_bash", "level": 1}], "tree[4].requires[0].skill: 선행")
	_rejects("pos 중복", func(f): f[HK]["tree"][1]["pos"] = [0, 0], "%s: class.holo_knight.tree[1].pos: 칸 [0,0]" % HK)
	_rejects("pos 범위", func(f): f[HK]["tree"][1]["pos"] = [4, 0], "%s: tree[1].pos:" % HK)
	_rejects("선행 레벨 최대 초과", func(f): f[HK]["tree"][5]["requires"][0]["level"] = 6, "class.holo_knight.tree[5].requires[0].level: 선행 레벨 6 이 skill.holo_knight.defense_protocol 의 최대 레벨 5")
	_rejects("같은 선행 두 번", func(f): f[HK]["tree"][5]["requires"].append({"skill": "skill.holo_knight.defense_protocol", "level": 1}), "같은 선행 스킬 skill.holo_knight.defense_protocol 를 두 번")
	_rejects("트리 안 중복", func(f): f[HK]["tree"][1]["skill"] = "skill.holo_knight.front_guard", "트리에 skill.holo_knight.front_guard 가 두 번")
	_rejects("관문 상한 초과", func(f): f[HK]["tree"][5]["min_level"] = 31, "class.holo_knight.tree[5].min_level: 정수 1~level_cap(30)")
	_rejects("트리 16개", func(f): _grow_tree(f, 16), "%s: tree: 항목 1~15" % HK)
	_rejects("트리 항목 필드", func(f): f[HK]["tree"][0].erase("min_level"), "%s: tree[0].min_level: 필수 필드가 없다" % HK)
	_rejects("적 스킬", func(f): f[HK]["tree"][0]["skill"] = "skill.enemy.bite", "tree[0].skill: skill.enemy.bite 의 user 가 party 가 아니다")


func _grow_tree(f: Dictionary, n: int) -> void:
	var t: Array = f[HK]["tree"]
	while t.size() < n:
		t.append(t[0].duplicate(true))


func test_passive_and_skill_row_checks() -> void:
	_rejects("패시브에 tp", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["levels"][0]["tp"] = 1, "%s: skills[3].levels[0].tp: 모르는 필드" % HKS)
	_rejects("패시브에 target", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["target"] = "self", "%s: skills[3].target: 모르는 필드" % HKS)
	_rejects("줄어드는 bonus", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["levels"][3]["bonus"]["VIT"] = 0, "%s: skills[3].levels[3].bonus.VIT: 앞 레벨보다 작다" % HKS)
	_rejects("줄마다 다른 bonus 키", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["levels"][2]["bonus"].erase("max_hp"), "skills[3].levels[2].bonus: 모든 줄의 bonus 키가 같아야")
	_rejects("bonus 모르는 키", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["levels"][0]["bonus"]["atk"] = 1, "skills[3].levels[0].bonus.atk: 모르는 필드")
	_rejects("bonus 범위", func(f): _skill(f, HKS, "skill.holo_knight.shield_mastery")["levels"][9]["bonus"]["max_hp"] = 1000, "skills[3].levels[9].bonus.max_hp: 정수 0~999")
	_rejects("적 패시브", func(f): f["skills/enemy.json"]["skills"].append({"id": "skill.enemy.t_p", "name_key": "skill.enemy.t_p", "user": "enemy", "effect": "passive", "levels": [{"bonus": {"STR": 1}}]}),
		"user enemy 에는 effect passive 를 쓸 수 없다")
	_rejects("스킬 줄 11개", func(f): _eleven(_skill(f, BDS, "skill.blade_duelist.high_slash")), "%s: skills[0].levels: 줄이 하나 이상 10개 이하" % BDS)


func _eleven(s: Dictionary) -> void:
	while s["levels"].size() < 11:
		s["levels"].append(s["levels"][0].duplicate(true))


func test_equipment_checks() -> void:
	_rejects("무기에 element 없음", func(f): _equip(f, "equip.ion_saber").erase("element"), "%s: equipment[11].element: 필수 필드가 없다" % EQ)
	_rejects("방어구에 element", func(f): _equip(f, "equip.padded_coat")["element"] = "fire", "%s: equipment[5].element: 무기 종류" % EQ)
	_rejects("stats 에 max_hp", func(f): _equip(f, "equip.visor")["stats"]["max_hp"] = 5, "%s: equipment[16].stats.max_hp: 능력치 6종" % EQ)
	_rejects("stats 값 0", func(f): _equip(f, "equip.visor")["stats"]["LUC"] = 0, "equipment[16].stats.LUC: 0 은 적지 않는다")
	_rejects("stats 범위", func(f): _equip(f, "equip.visor")["stats"]["LUC"] = 100, "equipment[16].stats.LUC: 정수 -99~99")
	_rejects("배율 보정 범위", func(f): _equip(f, "equip.aegis_plate")["resist"]["fire"] = -3001, "equipment[14].resist.fire: 정수 -3000~3000")
	_rejects("배율 보정 키", func(f): _equip(f, "equip.aegis_plate")["resist"]["dark"] = 100, "equipment[14].resist.dark: 모르는 필드")
	_rejects("only_classes 모르는 직업", func(f): _equip(f, "equip.tactical_baton")["only_classes"][0] = "class.nope", "%s: equip.tactical_baton.only_classes[0]: 없는 직업 class.nope" % EQ)
	_rejects("only_classes 빈 배열", func(f): _equip(f, "equip.tactical_baton")["only_classes"] = [], "equipment[13].only_classes: 직업 ID 가 하나 이상")
	_rejects("gear 범위", func(f): _equip(f, "equip.ion_saber")["atk"] = 1000, "equipment[11].atk: 정수 0~999")
	_rejects("접두사", func(f): _equip(f, "equip.ion_saber")["id"] = "item.ion_saber", "equipment[11].id: equip. 로 시작")
	_rejects("종류", func(f): _equip(f, "equip.visor")["kind"] = "cape", "equipment[16].kind:")
	var files := Fx.battle_files()
	files[HK]["equip_kinds"].erase("shield")
	var w := "\n".join(Fx.battle_db(files).warnings)
	check(w.contains("equip.training_shield: 어느 직업도 낄 수 없는 장비") and w.contains("equip.aegis_plate: 어느 직업도"), "낄 직업 없는 장비는 경고: " + w)


func test_start_party_checks() -> void:
	_party_rejects("시작 배분 SP 초과", func(p): p["members"][4]["skills"]["skill.glyph_wizard.corrode_glyph"] = 1, "members[4].skills.skill.glyph_wizard.corrode_glyph: 선행")
	_party_rejects("SP 초과(선행 없음)", func(p): p["members"][4]["skills"]["skill.glyph_wizard.glyph_mastery"] = 1, "members[4].skills: 배운 스킬 레벨의 합 4 이 얻은 SP 3")
	_party_rejects("선행 미충족", func(p): p["members"][1]["skills"] = {"skill.blade_duelist.high_slash": 1, "skill.blade_duelist.leg_cutter": 1},
		"members[1].skills.skill.blade_duelist.leg_cutter: 선행(skill.blade_duelist.high_slash Lv2)을 채우지 않았다")
	_party_rejects("관문 미달", func(p): p["members"][1].merge({"level": 4, "skills": {"skill.blade_duelist.blade_mastery": 3, "skill.blade_duelist.overclock": 1, "skill.blade_duelist.quick_draw": 1}}, true),
		"members[1].skills.skill.blade_duelist.quick_draw: 대원 레벨 5 이상")
	_party_rejects("시작 장비 직업 위반", func(p): p["members"][4]["equip"][3] = "equip.grip_gloves", "members[4].equip[3]: equip.grip_gloves: 이 직업은 낄 수 없다")
	_party_rejects("칸 0 에 방어구", func(p): p["members"][0]["equip"][0] = "equip.padded_coat", "members[0].equip[0]: equip.padded_coat: 칸 0 은 무기")
	_party_rejects("방패 둘", func(p): p["members"][0]["equip"][3] = "equip.training_shield", "members[0].equip[1]: equip.training_shield: 같은 종류 제한")
	_party_rejects("장비 ID 형식", func(p): p["members"][0]["equip"][3] = 7, "members[0].equip[3]: null 또는 equip. 로 시작")
	_party_rejects("스킬 레벨 11", func(p): p["members"][0]["skills"]["skill.holo_knight.front_guard"] = 11, "members[0].skills.skill.holo_knight.front_guard: 스킬 레벨은 정수 1~10")
	var d := Fx.defs_from(Fx.with_growth(Fx.battle_files(), {"initial_sp": 4}), _with_corrode())
	check(d != null and d.members()[4].skills.get("skill.glyph_wizard.corrode_glyph") == 1, "SP 가 넉넉하면 선행을 채운 시작 배분은 받는다")


func _with_corrode() -> Dictionary:
	var p := Fx.party_dict()
	p["members"][4]["skills"] = {"skill.glyph_wizard.heat_glyph": 1, "skill.glyph_wizard.glyph_mastery": 1, "skill.glyph_wizard.corrode_glyph": 1, "skill.glyph_wizard.frost_glyph": 1}
	return p
