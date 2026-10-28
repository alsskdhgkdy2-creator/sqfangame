## 새 직업(M3 A7b, 설계 §2.1~§2.4·§4.3·§4.4): 레일 레인저·헥스 해커의 정의 값, 활·총의 원거리 일반 공격, 파티 약화(debuff),
## 채집 보조(포리지 센스 gather_rare → GatherRules.skill_bonus). 값은 설계 노트의 글자 그대로 적는다(상수와 견주지 않는다).
## 시험마다 이름 붙은 변이(설계 노트 §7 A7b, M-C…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const TG := preload("res://tests/test_gather.gd")
const RR := "skill.rail_ranger."
const HH := "skill.hex_hacker."
const FORAGE := "skill.rail_ranger.forage_sense"
const WEAK := "skill.hex_hacker.weak_hex"

static var _real: GameDefs


func _defs() -> GameDefs:
	if _real == null:
		var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", TextDb.load_path("res://data/text/ko.json"))
		check(r.ok(), "실제 묶음 읽기 %s" % str(r.errors))
		if not r.ok():
			return null
		_real = r.defs
	return _real


## 마을에서 등록해 편성한 파티. recruits = [[직업 꼬리, 이름], …] 를 r1, r2 … 로 등록하고 front·back(ID 목록)으로 짠다.
func _town_party(recruits: Array, front: Array, back: Array) -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), 9, "full", true)
	for x in recruits:
		var ev := GuildRules.register(s, "class." + str(x[0]), 0, str(x[1]))
		check_eq(ev[0]["type"], "registered", "준비: %s 등록" % x[1])
	var fv := GuildRules.form(s, front, back)
	check_eq(fv[0]["type"], "formed", "준비: 편성 %s / %s" % [str(front), str(back)])
	return s


func _member(s: ExplorationState, id: String) -> PartyState.Member:
	return GuildRules.find(s, id)


func _slot(s: ExplorationState, id: String) -> int:
	for i in s.party.members.size():
		if s.party.members[i].id == id:
			return i
	return -1


## C1 (M-C1 레인저 start_equip 칸 2 가 null): 두 직업의 레벨 표 30줄과 Lv1·Lv30 값, 트리(칸·선행·관문), 시작 장비,
## 새 장비 여섯의 값과 진열 풀림, 스킬 값(설계 §4.3·§4.4 표).
func test_class_data() -> void:
	if _defs() == null:
		return
	var db := _defs().battle
	var ranger: BattleDb.ClassDef = db.classes.get("class.rail_ranger")
	var hacker: BattleDb.ClassDef = db.classes.get("class.hex_hacker")
	check(ranger != null and hacker != null, "두 직업이 있다")
	if ranger == null or hacker == null:
		return
	check_eq([ranger.levels.size(), hacker.levels.size()], [30, 30], "레벨 표 30줄")
	check_eq(ranger.levels[1], {"hp": 46, "tp": 36, "STR": 15, "INT": 9, "VIT": 11, "WIS": 12, "AGI": 20, "LUC": 16}, "레인저 Lv1")
	check_eq(ranger.levels[30], {"hp": 160, "tp": 84, "STR": 38, "INT": 18, "VIT": 24, "WIS": 25, "AGI": 50, "LUC": 38}, "레인저 Lv30")
	check_eq(hacker.levels[1], {"hp": 44, "tp": 52, "STR": 10, "INT": 17, "VIT": 10, "WIS": 18, "AGI": 12, "LUC": 19}, "해커 Lv1")
	check_eq(hacker.levels[30], {"hp": 150, "tp": 130, "STR": 20, "INT": 40, "VIT": 22, "WIS": 42, "AGI": 26, "LUC": 46}, "해커 Lv30")
	for c in [ranger, hacker]:
		for lv in range(2, 31):
			for k in c.levels[lv]:
				check(int(c.levels[lv][k]) >= int(c.levels[lv - 1][k]), "%s Lv%d %s 는 앞 레벨보다 작지 않다" % [c.id, lv, k])
	check_eq(ranger.start_equip, ["equip.rail_bow", "equip.padded_coat", "equip.scout_hood", ""] as Array[String], "레인저 시작 장비")
	check_eq(hacker.start_equip, ["equip.hex_pistol", "equip.glyph_robe", "equip.hex_mask", ""] as Array[String], "해커 시작 장비")
	check_eq([ranger.attack.element, ranger.attack.range_kind, hacker.attack.range_kind], ["pierce", "melee", "melee"], "맨손 일반 공격은 근접")
	check_eq(ranger.equip_kinds, ["bow", "body", "head", "hands", "feet", "accessory"] as Array[String], "레인저 장비 종류")
	check_eq(hacker.equip_kinds, ["gun", "body", "head", "feet", "accessory"] as Array[String], "해커 장비 종류")
	var tree := func(c: BattleDb.ClassDef) -> Array:
		return c.tree.map(func(e: Dictionary) -> Array:
			return [str(e["skill"]).get_slice(".", 2), e["pos"], e["requires"].map(func(r: Dictionary) -> String: return "%s %d" % [str(r["skill"]).get_slice(".", 2), r["level"]]), e["min_level"]])
	check_eq(tree.call(ranger), [
		["sharp_shot", [0, 0], [], 1], ["flash_arrow", [1, 0], [], 1], ["leg_shot", [2, 0], [], 1], ["bow_mastery", [3, 0], [], 1],
		["arm_shot", [2, 1], ["leg_shot 2"], 1], ["first_aim", [0, 1], ["sharp_shot 2", "bow_mastery 3"], 5], ["forage_sense", [3, 1], ["bow_mastery 1"], 1],
	], "레인저 트리 7칸")
	check_eq(tree.call(hacker), [
		["glitch_hex", [0, 0], [], 1], ["weak_hex", [1, 0], [], 1], ["frail_hex", [2, 0], [], 1], ["hex_mastery", [3, 0], [], 1],
		["jam_hex", [1, 1], ["weak_hex 2"], 1], ["numb_hex", [3, 1], ["hex_mastery 2"], 1], ["head_crack", [0, 1], ["glitch_hex 2"], 1],
		["mass_glitch", [0, 2], ["glitch_hex 3", "hex_mastery 3"], 5],
	], "해커 트리 8칸")
	# 장비 여섯(설계 §2.3 표): 종류, atk·matk·def·mdef, 속성, 능력치, 값.
	var eq := func(id: String) -> Array:
		var e := db.equip("equip." + id)
		return [e.kind, e.gear["atk"], e.gear["matk"], e.gear["def"], e.gear["mdef"], e.element, e.stats, e.price] if e != null else []
	check_eq(eq.call("rail_bow"), ["bow", 10, 0, 0, 0, "pierce", {}, 80], "레일 보우")
	check_eq(eq.call("coil_longbow"), ["bow", 18, 0, 0, 0, "pierce", {"AGI": 2}, 320], "코일 롱보우")
	check_eq(eq.call("hex_pistol"), ["gun", 7, 6, 0, 0, "pierce", {}, 80], "헥스 피스톨")
	check_eq(eq.call("glitch_carbine"), ["gun", 12, 12, 0, 0, "pierce", {"LUC": 2}, 320], "글리치 카빈")
	check_eq(eq.call("scout_hood"), ["head", 0, 0, 2, 1, "", {"AGI": 1}, 50], "정찰 후드")
	check_eq(eq.call("hex_mask"), ["head", 0, 0, 1, 3, "", {"LUC": 1}, 50], "헥스 마스크")
	var stock := {}
	for line in db.shop("shop.junk_workshop").stock:
		stock[line["item"]] = line["unlock"]
	check_eq([stock.get("equip.rail_bow"), stock.get("equip.coil_longbow"), stock.get("equip.hex_pistol"), stock.get("equip.glitch_carbine"),
		stock.get("equip.scout_hood"), stock.get("equip.hex_mask")],
		[{}, {"item.scrap_wire": 3, "item.copper_coil": 2}, {}, {"item.data_core": 2, "item.ether_crystal": 1}, {}, {}], "진열 풀림")
	# 스킬 값.
	var lv := func(id: String, level: int) -> Dictionary:
		return db.skill(id).level_row(level)
	check_eq([lv.call(RR + "sharp_shot", 1)["power"], lv.call(RR + "sharp_shot", 5)["power"], lv.call(RR + "sharp_shot", 1)["accuracy"]], [150, 190, 950], "샤프 샷 150→190, 명중 950")
	check_eq([lv.call(RR + "flash_arrow", 1)["ailment"], lv.call(RR + "flash_arrow", 5)["ailment"]["chance"]], [{"id": "blind", "chance": 600, "turns": 3}, 800], "플래시 애로 맹목 600→800")
	check_eq([lv.call(RR + "leg_shot", 1)["bind"]["part"], lv.call(RR + "arm_shot", 1)["bind"]["part"]], ["leg", "arm"], "레그 샷·암 샷 잠금")
	check_eq(db.skill(RR + "first_aim").priority, "first", "퍼스트 에임 선제")
	check_eq(range(1, 11).map(func(l: int) -> int: return int(lv.call(FORAGE, l)["gather_rare"])), [30, 60, 90, 120, 150, 180, 210, 240, 270, 300], "포리지 센스 gather_rare 30 × 레벨")
	check_eq([lv.call(RR + "bow_mastery", 1)["bonus"], lv.call(HH + "hex_mastery", 1)["bonus"]], [{"STR": 1, "AGI": 1}, {"LUC": 1, "max_tp": 3}], "마스터리 보정")
	check_eq([db.skill(HH + "glitch_hex").sure_hit, lv.call(HH + "glitch_hex", 1)["ailment"], lv.call(HH + "glitch_hex", 5)["ailment"]["chance"]],
		[true, {"id": "confusion", "chance": 500, "turns": 3}, 700], "글리치 헥스 혼란 500→700, 필중")
	check_eq([db.skill(WEAK).effect, lv.call(WEAK, 1)["kind"], lv.call(WEAK, 1)["value"], lv.call(WEAK, 5)["value"], lv.call(WEAK, 1)["turns"]],
		["debuff", "phys_atk", 750, 650, 3], "위크 헥스 공격 약화 750→650")
	check_eq([lv.call(HH + "frail_hex", 1)["value"], lv.call(HH + "frail_hex", 5)["value"]], [1250, 1400], "프레일 헥스 방어 약화 1250→1400")
	check_eq([db.skill(HH + "jam_hex").target, lv.call(HH + "jam_hex", 1)["ailment"]["id"], db.skill(HH + "mass_glitch").target], ["enemy_row", "blind", "enemy_all"], "재밍 헥스·매스 글리치 범위")
	check_eq(lv.call(HH + "numb_hex", 1)["ailment"]["id"], "paralysis", "넘 헥스 마비")
	check_eq([lv.call(HH + "head_crack", 1)["bind"]["part"], db.skill(HH + "head_crack").parts], ["head", ["arm"] as Array[String]], "헤드 크랙 머리 잠금(팔 부위)")
	var texts := TextDb.load_path("res://data/text/ko.json")
	check_eq([texts.t("class.rail_ranger"), texts.t("class.hex_hacker")], ["레일 레인저", "헥스 해커"], "직업 이름")
	for cid in db.class_ids:
		check(texts.has(db.classes[cid].desc_key) and not texts.t(db.classes[cid].desc_key).is_empty(), "%s 설명 글" % cid)


## C2 (M-C2 RANGED_WEAPONS 가 빔): 활·총을 낀 대원의 일반 공격은 원거리라 후열에서도 열 배율이 없고 적 후열에 닿는다.
## 맨손이면 직업의 근접, 검을 낀 기본 대원은 그대로 근접.
func test_bow_and_gun_attack_is_ranged() -> void:
	if _defs() == null:
		return
	var s := _town_party([["rail_ranger", "레인저"], ["hex_hacker", "해커"]], ["holo_knight", "blade_duelist", "blade_duelist_2"], ["r1", "r2"])
	var d := _defs()
	var pr := GrowthRules.profile(d, _slot(s, "r1"), _member(s, "r1"))
	var ph := GrowthRules.profile(d, _slot(s, "r2"), _member(s, "r2"))
	var pk := GrowthRules.profile(d, 0, s.party.members[0])
	check_eq([pr["weapon"], pr["attack"].range_kind, pr["attack"].element], ["equip.rail_bow", "ranged", "pierce"], "레일 보우: 원거리 관통")
	check_eq([ph["weapon"], ph["attack"].range_kind, ph["attack"].element], ["equip.hex_pistol", "ranged", "pierce"], "헥스 피스톨: 원거리 관통")
	check_eq([pk["attack"].range_kind, d.battle.classes["class.rail_ranger"].attack.range_kind], ["melee", "melee"], "검 기사는 근접, 정의 사본은 그대로")
	var bare := _member(s, "r1")
	var bow := bare.equip[0]
	bare.equip[0] = ""
	check_eq(GrowthRules.profile(d, _slot(s, "r1"), bare)["attack"].range_kind, "melee", "맨손 레인저: 직업의 근접")
	bare.equip[0] = bow
	# 전투: 후열 레인저·해커의 일반 공격은 열 배율 없이 적 후열에도 닿는다.
	s.location = ExplorationState.LABYRINTH
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, "formation.b1.rats")
	var b := s.battle
	check(b != null, "준비: 전투")
	if b == null:
		return
	for id in ["r1", "r2"]:
		var i := _slot(s, id)
		var u := b.party[i]
		check_eq([u.row, u.attack.range_kind], ["back", "ranged"], "%s: 후열 원거리 유닛" % id)
		var t := b.enemies[0]
		var inp := BattleRules.damage_inputs(b, d.battle.rules, u, u.attack, u.attack.level_row(1), t, false, 1000)
		check_eq(inp["row"], false, "%s: 후열에서 쏘아도 열 배율 없음" % id)
		check_eq(BattleRules.valid_targets(s, i, "attack").size(), b.enemies.filter(func(e: BattleUnit) -> bool: return e.alive()).size(), "%s: 살아 있는 적 모두가 대상" % id)
	var k := b.party[0]
	check_eq(k.attack.range_kind, "melee", "기사 일반 공격은 근접 그대로")


## C3 (M-C3 파티 effect 에 debuff 가 없음): 파티 약화 스킬을 정의가 받고(메모리 사본에 더한 시험 스킬도 오류 없음),
## 헥스 해커의 위크 헥스가 적 약화 칸에 공격 약화를 건다. 강화 쪽 값의 파티 약화는 거부한다.
func test_party_debuff() -> void:
	var files := Fx.battle_files()
	files["skills/hex_hacker.json"]["skills"].append(Fx.effect_skill("skill.hex_hacker.t_sap", false, [["elem_def", 1300, 2]]).merged({"effect": "debuff", "target": "enemy_row"}, true))
	files["classes/hex_hacker.json"]["tree"].append({"skill": "skill.hex_hacker.t_sap", "pos": [2, 1], "requires": [], "min_level": 1})
	check_eq(Fx.battle_db(files).errors, [] as Array[String], "파티 약화(줄 대상) 시험 스킬을 정의가 받는다")
	var bad := Fx.battle_files()
	bad["skills/hex_hacker.json"]["skills"].append(Fx.effect_skill("skill.hex_hacker.t_bad", false, [["phys_def", 750, 2]]).merged({"effect": "debuff"}, true))
	check(Fx.battle_db(bad).errors.any(func(e: String) -> bool: return e.contains("levels[0].value: debuff phys_def 는")), "강화 쪽 값(방어 750)의 파티 약화는 거부")
	var defs := Fx.defs_from(Fx.with_growth(Fx.battle_files(), {"initial_sp": 99}), Fx.party_with_skills(BattleDb.load_dir(Fx.DATA_DIR), {WEAK: 5}, Fx.recruit_party_dict()))
	check(defs != null, "준비: 해커가 위크 헥스 Lv5 를 배운 시험 파티")
	if defs == null:
		return
	var s := Fx.battle(defs, "formation.f1.rats_moth", 3)
	var hi := 4
	check_eq([s.party.members[hi].class_id, s.battle.party[hi].skills.get(WEAK, 0)], ["class.hex_hacker", 5], "칸 4 해커, 위크 헥스 Lv5")
	var ev := BattleRules.submit(s, Fx.cmds(s, {hi: Fx.use(WEAK, 0)}))
	var bf := Fx.of_type(ev, "buffed").filter(func(e: Dictionary) -> bool: return e["target"] == {"side": "enemy", "slot": 0})
	check(bf.size() == 1 and bf[0]["list"] == "debuffs" and bf[0]["effect"]["id"] == WEAK and bf[0]["effect"]["kind"] == "phys_atk" and bf[0]["effect"]["value"] == 650,
		"적 0 약화 칸에 공격 650: %s" % str(bf))
	if s.battle != null:
		var on := s.battle.enemies[0].debuffs.filter(func(x: Dictionary) -> bool: return x["id"] == WEAK)
		check(on.size() == 1 and on[0]["turns"] == 2, "턴 끝에 2턴 남음: %s" % str(s.battle.enemies[0].debuffs))
		check(s.battle.party[hi].buffs.is_empty(), "해커 자신의 강화 칸은 그대로")


## C4 (M-C4 더하기, M-C5 길드 대원도 셈): 채집 희귀 보너스 = 살아 있는 파티 대원의 포리지 센스 gather_rare 가운데 가장 큰 값.
## 길드 대원·쓰러진 대원은 빼고, 세 종류에 같다. 수확 굴림은 표의 희귀 확률 + 보너스로 같은 씨앗의 한 번 뽑기를 본다.
func test_forage_gather_bonus() -> void:
	if _defs() == null:
		return
	var s := _town_party([["rail_ranger", "가"], ["rail_ranger", "나"], ["rail_ranger", "다"]], ["holo_knight", "blade_duelist", "blade_duelist_2"], ["r1", "r2"])
	check_eq(GatherRules.skill_bonus(s, "take"), {"count": 0, "rare_permille": 0}, "아무도 배우지 않음: 0")
	_member(s, "r1").skills = {"skill.rail_ranger.bow_mastery": 1, FORAGE: 3}
	_member(s, "r2").skills = {"skill.rail_ranger.bow_mastery": 1, FORAGE: 2}
	_member(s, "r3").skills = {"skill.rail_ranger.bow_mastery": 1, FORAGE: 10}
	check(GuildRules.roster(s).has(_member(s, "r3")) and _slot(s, "r3") < 0, "준비: r3 는 길드에만")
	for kind in ["take", "chop", "mine"]:
		check_eq(GatherRules.skill_bonus(s, kind), {"count": 0, "rare_permille": 90}, "%s: 파티 r1(90)·r2(60) 가운데 큰 값, 길드 r3(300)은 빼고" % kind)
	_member(s, "r1").hp = 0
	check_eq(GatherRules.skill_bonus(s, "take")["rare_permille"], 60, "r1 쓰러짐: r2 의 60")
	_member(s, "r2").hp = 0
	check_eq(GatherRules.skill_bonus(s, "take")["rare_permille"], 0, "둘 다 쓰러짐: 0")
	# 굴림: 시험 채집 층(test_gather)의 추출 지점 g3(희귀 500‰)에서, 칸 3 대원이 포리지 센스 Lv10(300)을 가진다.
	var g := ExplorationRules.new_game(TG.defs(), 3, "full")
	g.party.members[3].skills[FORAGE] = 10
	var p: FloorModel.GatherPoint = g.floor_def.points["g3"]
	var table := g.defs.battle.gather_table(p.table)
	check_eq([table.rare_permille, GatherRules.skill_bonus(g, p.kind)["rare_permille"]], [500, 300], "준비: 표 500‰, 보너스 300")
	var between := 0
	for used in 40:
		# 같은 씨앗으로 같은 차례(무게 줄 → 개수 → 희귀)를 따라 뽑아 희귀 뽑기 값을 얻는다.
		var rng := GameRng.new(GatherRules.roll_seed(g, p, used))
		var line: Dictionary = {}
		var pick := rng.randi_range(1, table.total_weight())
		for x in table.items:
			pick -= int(x["weight"])
			if pick <= 0:
				line = x
				break
		rng.randi_range(int(line["lo"]), int(line["hi"]))
		var r := rng.randi_range(1, 1000)
		var got := GatherRules.roll(g, p, table, used)
		var rare := got.size() == 2
		check_eq(rare, r <= 800, "used %d: 희귀 뽑기 %d ≤ 500 + 300 일 때만 희귀" % [used, r])
		if r > 500 and r <= 800:
			between += 1
	check(between > 0, "준비: 보너스 덕에만 희귀가 나온 뽑기가 있다(%d번)" % between)
