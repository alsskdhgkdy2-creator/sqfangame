extends TestCase
## 저장 3판·이전 시험(07 §10.2). 4판(08 §4)부터 3판 문서는 읽을 때 4판으로 옮기므로, 3판 검사는 3판 문서(이전 경로)와 4판 문서 둘 다로 본다.
##
## 2판 고정 문자열(V2_NORMAL·V2_BATTLE·V2_WIPED)과 그 전투 유닛 입력값(V2_BATTLE_UNITS)은 저장 형식·정의를 바꾸기 전 코드
## (커밋 e9dd205 = 코드는 44feefd 그대로, 2026-10-18)로 만들었다(07 §11.3 0단계). 만든 방법: 저장소 밖의 일회용 스크립트를
## `flock /tmp/sqfangame-godot.lock timeout 120 godot --headless -s /tmp/sqf_gen/gen_v2.gd` 로 돌려 SaveCodec.encode 결과를 그대로 옮겼다.
## 스크립트 내용: data/ 정의(Fx.defs)로
##   V2_NORMAL — new_game(시드 5) → 전진 2·우회전, 나이트 HP 41·듀얼리스트 A TP 20·메딕 HP 0·위저드 TP 51, 소재 둘(saved_at 2026-10-10T01:02:03Z, generation 17)
##   V2_BATTLE — Fx.battle(beetle_rat, 시드 21) → 쥐 처치(damage_unit, 처치 기록), 갑충 준비 crush·위저드 부식 글리프 독(15, 3턴)·HP 170·누적 내성,
##               강화(오버클럭·디펜스 프로토콜)·약화(찢는 울음)·봉인(듀얼리스트 B 팔)·마비(메딕)·누적 내성, 나이트 HP 47·TP 일부 소모
##               (saved_at 2026-10-11T04:05:06Z, generation 23)
##   V2_WIPED — new_game(시드 9) → 전진 1, 모든 대원 HP 0·wiped(saved_at 2026-10-12T07:08:09Z, generation 29)
## V2_BATTLE_UNITS 는 같은 코드로 V2_BATTLE 을 읽은 전투 유닛(칸 순)의 stats·gear·resist·ailment_vuln·bind_vuln·일반 공격 속성·최대 HP·TP.
## 이 문자열들은 다시 만들 수 없다(2판을 쓰는 코드가 없어졌다). 고치지 않는다.

const Fx := preload("res://tests/fixtures.gd")

const V2_NORMAL := '{"format":"sqfangame-save","generation":17,"rules":"m2","saved_at":"2026-10-10T01:02:03Z","schema":2,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:16":0,"2:17":0,"2:18":0},"icons":{},"memos":{}},"battle":null,"encounter":{"danger":0,"pending":false,"threshold":147},"floor":"f1_test","knowledge":{"edges":{"h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:3:16":"open","v:3:17":"open","v:3:18":"open"},"visited":["2:16","2:17","2:18"]},"materials":{"item.beetle_plate":1,"item.neon_rat_tail":3},"party":{"at":[2,16],"facing":"E","members":[{"hp":41,"id":"holo_knight","tp":30},{"hp":52,"id":"blade_duelist","tp":20},{"hp":52,"id":"blade_duelist_2","tp":32},{"hp":0,"id":"nano_medic","tp":54},{"hp":40,"id":"glyph_wizard","tp":51}]},"rng":{"state":"35035103500997846"},"steps":2,"wiped":false,"world":{"passages_found":[],"shortcuts_open":[]}}}'
const V2_BATTLE := '{"format":"sqfangame-save","generation":23,"rules":"m2","saved_at":"2026-10-11T04:05:06Z","schema":2,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:18":0},"icons":{},"memos":{}},"battle":{"enemies":[{"ailment":{"damage":15,"id":"poison","turns":3},"binds":{},"buffs":[],"charging":"skill.enemy.crush","debuffs":[],"hp":170,"kill":null,"resist":{"poison":300}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":0,"kill":{"ailment":null,"binds":[],"by":"attack","element":"slash","turn":0},"resist":{}}],"formation":"formation.f1.beetle_rat","party":[{"ailment":null,"binds":{},"buffs":[{"id":"skill.holo_knight.defense_protocol","kind":"phys_def","seq":2,"turns":3,"value":750}],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[{"id":"skill.blade_duelist.overclock","kind":"phys_atk","seq":1,"turns":3,"value":1300}],"debuffs":[{"id":"skill.enemy.rending_howl","kind":"phys_def","seq":3,"turns":3,"value":1250}],"resist":{}},{"ailment":null,"binds":{"arm":2},"buffs":[],"debuffs":[],"resist":{}},{"ailment":{"id":"paralysis","turns":2},"binds":{},"buffs":[],"debuffs":[],"resist":{"sleep":600}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":4,"turn":0},"encounter":{"danger":221,"pending":true,"threshold":221},"floor":"f1_test","knowledge":{"edges":{"h:2:18":"open","h:2:19":"open","v:2:18":"open","v:3:18":"open"},"visited":["2:18"]},"materials":{"item.neon_rat_tail":2},"party":{"at":[2,18],"facing":"N","members":[{"hp":47,"id":"holo_knight","tp":30},{"hp":52,"id":"blade_duelist","tp":28},{"hp":52,"id":"blade_duelist_2","tp":32},{"hp":42,"id":"nano_medic","tp":54},{"hp":40,"id":"glyph_wizard","tp":56}]},"rng":{"state":"-8757809823500504218"},"steps":0,"wiped":false,"world":{"passages_found":[],"shortcuts_open":[]}}}'
const V2_WIPED := '{"format":"sqfangame-save","generation":29,"rules":"m2","saved_at":"2026-10-12T07:08:09Z","schema":2,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:17":0,"2:18":0},"icons":{},"memos":{}},"battle":null,"encounter":{"danger":0,"pending":false,"threshold":216},"floor":"f1_test","knowledge":{"edges":{"h:2:17":"open","h:2:18":"open","h:2:19":"open","v:2:17":"open","v:2:18":"open","v:3:17":"open","v:3:18":"open"},"visited":["2:17","2:18"]},"materials":{"item.neon_rat_tail":1},"party":{"at":[2,17],"facing":"N","members":[{"hp":0,"id":"holo_knight","tp":30},{"hp":0,"id":"blade_duelist","tp":32},{"hp":0,"id":"blade_duelist_2","tp":5},{"hp":0,"id":"nano_medic","tp":54},{"hp":0,"id":"glyph_wizard","tp":60}]},"rng":{"state":"-6774862146676765574"},"steps":1,"wiped":true,"world":{"passages_found":[],"shortcuts_open":[]}}}'
const V2_BATTLE_UNITS := '[{"ailment_vuln":{"paralysis":1000,"poison":1000,"sleep":1000},"attack":"slash","bind_vuln":{"arm":1000,"head":1000,"leg":1000},"gear":{"atk":8,"def":10,"matk":0,"mdef":4},"max_hp":60,"max_tp":30,"resist":{"bash":1000,"fire":1000,"ice":1000,"pierce":1000,"slash":1000,"volt":1000},"stats":{"AGI":11,"INT":8,"LUC":14,"STR":15,"VIT":19,"WIS":13}},{"ailment_vuln":{"paralysis":1000,"poison":1000,"sleep":1000},"attack":"slash","bind_vuln":{"arm":1000,"head":1000,"leg":1000},"gear":{"atk":14,"def":6,"matk":0,"mdef":2},"max_hp":52,"max_tp":32,"resist":{"bash":1000,"fire":1000,"ice":1000,"pierce":1000,"slash":1000,"volt":1000},"stats":{"AGI":18,"INT":8,"LUC":13,"STR":19,"VIT":13,"WIS":10}},{"ailment_vuln":{"paralysis":1000,"poison":1000,"sleep":1000},"attack":"slash","bind_vuln":{"arm":1000,"head":1000,"leg":1000},"gear":{"atk":14,"def":6,"matk":0,"mdef":2},"max_hp":52,"max_tp":32,"resist":{"bash":1000,"fire":1000,"ice":1000,"pierce":1000,"slash":1000,"volt":1000},"stats":{"AGI":18,"INT":8,"LUC":13,"STR":19,"VIT":13,"WIS":10}},{"ailment_vuln":{"paralysis":1000,"poison":1000,"sleep":1000},"attack":"bash","bind_vuln":{"arm":1000,"head":1000,"leg":1000},"gear":{"atk":6,"def":5,"matk":6,"mdef":5},"max_hp":42,"max_tp":54,"resist":{"bash":1000,"fire":1000,"ice":1000,"pierce":1000,"slash":1000,"volt":1000},"stats":{"AGI":13,"INT":14,"LUC":14,"STR":9,"VIT":12,"WIS":20}},{"ailment_vuln":{"paralysis":1000,"poison":1000,"sleep":1000},"attack":"bash","bind_vuln":{"arm":1000,"head":1000,"leg":1000},"gear":{"atk":4,"def":3,"matk":12,"mdef":6},"max_hp":40,"max_tp":60,"resist":{"bash":1000,"fire":1000,"ice":1000,"pierce":1000,"slash":1000,"volt":1000},"stats":{"AGI":12,"INT":21,"LUC":15,"STR":8,"VIT":8,"WIS":17}}]'
const BS := preload("res://tests/test_battle_save.gd")

const SHIELD_M := "skill.holo_knight.shield_mastery"
const HEAT := "skill.glyph_wizard.heat_glyph"
const CORRODE := "skill.glyph_wizard.corrode_glyph"
const HS := "skill.blade_duelist.high_slash"
const LEG := "skill.blade_duelist.leg_cutter"
const OVERCLOCK := "skill.blade_duelist.overclock"
const HOWL := "skill.enemy.rending_howl"

var _quiet: GameDefs


func _defs() -> GameDefs:
	if _quiet == null:
		_quiet = Fx.quiet_defs()
	return _quiet


func _canon(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


# ---- 3판 왕복 ----

## 성장 값이 있는 전투 중 상태: 레벨 3·패시브·초안 아닌 배운 스킬(레그 커터)·바꾼 장비·가방, 06 §10.2 의 전투 상태(강화·약화·봉인·상태이상·처치 기록·준비).
func _rich() -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), 21, "floor")
	GrowthRules.grant_exp(s, 0, 115)
	GrowthRules.grant_exp(s, 1, 115)
	GrowthRules.allocate(s, 0, {SHIELD_M: 2})
	GrowthRules.allocate(s, 1, {HS: 2, LEG: 1})
	GrowthRules.supply(s, "equip.aegis_plate", 1)
	GrowthRules.supply(s, "equip.ion_saber", 2)
	GrowthRules.equip(s, 0, 1, "equip.aegis_plate")
	GrowthRules.equip(s, 1, 0, "equip.ion_saber")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, "formation.f1.beetle_rat")
	BattleRules.submit(s, Fx.cmds(s))
	var b := s.battle
	BattleRules.damage_unit(s, b.enemies[1], b.enemies[1].hp, b.party[1], "volt", "attack", [] as Array[Dictionary], {})
	b.enemies[0].charging = "skill.enemy.crush"
	Fx.apply_effect(s, b.party[1], OVERCLOCK)
	Fx.apply_effect(s, b.party[1], HOWL)
	b.party[1].ailment = "poison"
	b.party[1].ailment_turns = 3
	b.party[1].ailment_damage = 4
	b.party[0].binds["arm"] = 2
	b.party[3].resist_acc["sleep"] = 600
	return s


## 5판 문서에서 3판 문서를 만든다(4판 꼴로 펴고 머리 3·"m2g", money·shop 없음). 시작 소지금·빈 상점 상태면 3판 → 5판 이전이 같은 상태를 돌려준다.
static func as_v3(doc: Dictionary) -> Dictionary:
	var d := Fx.as_v4(doc)
	d.merge({"schema": 3, "rules": "m2g"}, true)
	d["state"].erase("money")
	d["state"].erase("shop")
	return d


func test_v3_roundtrip_with_growth_mid_battle() -> void:
	var s := _rich()
	var m0 := s.party.members[0]
	check(m0.level == 3 and m0.skills.get(SHIELD_M) == 2 and m0.equip[1] == "equip.aegis_plate" and s.gear_bag.has("equip.training_shield") and s.battle != null, "준비: 성장 값·전투")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["schema"], doc["rules"]], [6.0, "m3t"], "6판 머리")
	var v3 := SaveCodec.decode(JSON.stringify(as_v3(doc)), _defs())
	check(v3.ok(), "3판 문서 읽기(4판으로 이전) %s" % v3.error)
	if v3.ok():
		check_eq([v3.from_schema, v3.saved_at, v3.generation, v3.state.money, SaveCodec.state_hash(v3.state)], [3, doc["saved_at"], int(doc["generation"]), 200, SaveCodec.state_hash(s)],
			"3판 이전: from_schema 3·머리 보존·시작 소지금·같은 해시(빈 상점)")
		check_eq(Fx.battle_hash(v3.state), Fx.battle_hash(s), "3판 이전: 같은 전투 해시")
	check_eq(doc["state"]["party"]["members"][1]["equip"], ["equip.ion_saber", "equip.padded_coat", "equip.grip_gloves", null], "equip 은 칸 순서 배열(빈 칸 null)")
	var r := SaveCodec.decode(SaveCodec.encode(s), _defs())
	check(r.ok(), "읽기 %s" % r.error)
	if not r.ok():
		return
	var c := r.state
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 해시")
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "같은 전투 해시")
	for i in 5:
		var a := s.party.members[i]
		var x := c.party.members[i]
		check_eq([x.level, x.exp, x.skills, x.equip, x.max_hp, x.max_tp], [a.level, a.exp, a.skills, a.equip, a.max_hp, a.max_tp], "대원 %d 성장 값" % i)
	check_eq(c.battle.party[1].attack.element, "volt", "읽은 전투도 무기 속성")
	var cmds := {1: Fx.atk(0), 2: Fx.atk(0)}
	var e1 := BattleRules.submit(s, Fx.cmds(s, cmds))
	var e2 := BattleRules.submit(c, Fx.cmds(c, cmds))
	check_eq(Fx.events_text(e2), Fx.events_text(e1), "같은 다음 턴 이벤트")
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 다음 상태")


# ---- 3판 거부 (07 §8.3 표의 줄마다) ----

## 5판 문서와, 같은 상태의 3판 문서(이전 경로, 「3판 검사 실패」로 이전 전에 거부) 둘 다.
func _expect_reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var before := SaveCodec.state_hash(s)
	var v4: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	for x in [["5판", v4, ""], ["3판", as_v3(v4), "3판 검사 실패: "]]:
		var doc: Dictionary = x[1]
		mutate.call(doc["state"])
		var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
		check(not r.ok() and r.state == null, "%s(%s): 거부되어야 한다" % [label, x[0]])
		check(r.error.begins_with(x[2]) and r.error.contains(needle), "%s(%s): 이유 '%s%s' 기대, 실제 '%s'" % [label, x[0], x[2], needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


func _m(d: Dictionary, i: int) -> Dictionary:
	return d["party"]["members"][i]


func test_v3_rejects_each_member_row() -> void:
	var s := ExplorationRules.new_game(_defs(), 2, "floor")
	var g := _defs().battle.growth
	GrowthRules.grant_exp(s, 0, 115)
	GrowthRules.allocate(s, 0, {SHIELD_M: 2})
	GrowthRules.grant_exp(s, 2, g.cum(30))
	check_eq([s.party.members[0].level, s.party.members[0].max_hp, s.party.members[0].hp, s.party.members[2].level], [3, 68 + 6, 74, 30], "준비: 나이트 Lv3 패시브 2(최대 HP 68 + 6)·듀얼리스트 B Lv30")
	var cases := [
		["level 0", func(d): _m(d, 1)["level"] = 0, "party.members[1].level 이 정수 1~30"],
		["level 31", func(d): _m(d, 1)["level"] = 31, "party.members[1].level 이 정수 1~30"],
		["level 소수", func(d): _m(d, 1)["level"] = 1.5, "party.members[1].level"],
		["exp = cum(level) − 1", func(d): _m(d, 0)["exp"] = g.cum(3) - 1, "party.members[0].exp 가 레벨 3 의 범위"],
		["exp = cum(level + 1)", func(d): _m(d, 0)["exp"] = g.cum(4), "party.members[0].exp 가 레벨 3 의 범위"],
		["상한인데 exp > cum(30)", func(d): _m(d, 2)["exp"] = g.cum(30) + 1, "party.members[2].exp 가 레벨 상한의 누적 경험치"],
		["exp 음수", func(d): _m(d, 1)["exp"] = -1, "party.members[1].exp 가 정수"],
		["모르는 스킬", func(d): _m(d, 1)["skills"]["skill.blade_duelist.nope"] = 1, "party.members[1].skills.skill.blade_duelist.nope: class.blade_duelist 트리에 없는"],
		["남의 직업 스킬", func(d): _m(d, 1)["skills"][HEAT] = 1, "party.members[1].skills.%s: class.blade_duelist 트리에 없는" % HEAT],
		["스킬 레벨 0", func(d): _m(d, 1)["skills"][HS] = 0, "party.members[1].skills.%s: 스킬 레벨 0" % HS],
		["스킬 레벨 최대 초과", func(d): _m(d, 2)["skills"][HS] = 6, "party.members[2].skills.%s: 스킬 레벨 6" % HS],
		["스킬 레벨 문자열", func(d): _m(d, 1)["skills"][HS] = "1", "party.members[1].skills.%s 가 정수가 아니다" % HS],
		["선행 미충족", func(d): _m(d, 2)["skills"][LEG] = 1, "party.members[2].skills.%s: 선행" % LEG],
		["관문 미달", func(d): _quick_low(d), "party.members[1].skills.skill.blade_duelist.quick_draw: 대원 레벨 5 이상"],
		["Σ > 얻은 SP", func(d): _m(d, 1)["skills"][HS] = 2, "party.members[1].skills: 배운 스킬 레벨의 합 4 이 얻은 SP 3"],
		["skills 객체 아님", func(d): _m(d, 1)["skills"] = [], "party.members[1].skills 가 객체가 아니다"],
		["equip 길이 3", func(d): _m(d, 1)["equip"].pop_back(), "party.members[1].equip 이 길이 4"],
		["칸 0 에 방어구", func(d): _m(d, 1)["equip"][0] = "equip.padded_coat", "party.members[1].equip[0]: equip.padded_coat: 칸 0 은 무기"],
		["직업이 못 끼는 장비", func(d): _m(d, 4)["equip"][3] = "equip.grip_gloves", "party.members[4].equip[3]: equip.grip_gloves: 이 직업은 낄 수 없다"],
		["방패 둘", func(d): _m(d, 0)["equip"][3] = "equip.training_shield", "party.members[0].equip"],
		["모르는 장비", func(d): _m(d, 0)["equip"][3] = "equip.nope", "party.members[0].equip[3] 가 null 또는 장비 ID"],
		["hp > 계산한 최대", func(d): _m(d, 0)["hp"] = 75, "party.members[0].hp 가 0~74"],
		["패시브를 빼면 hp 가 최대를 넘음", func(d): _m(d, 0)["skills"].erase(SHIELD_M), "party.members[0].hp 가 0~68"],
		["tp > 계산한 최대", func(d): _m(d, 1)["tp"] = 33, "party.members[1].tp 가 0~32"],
		["gear_bag 0개", func(d): d["gear_bag"]["equip.visor"] = 0, "gear_bag.equip.visor 가 정수 1~99"],
		["gear_bag 100개", func(d): d["gear_bag"]["equip.visor"] = 100, "gear_bag.equip.visor 가 정수 1~99"],
		["gear_bag 모르는 ID", func(d): d["gear_bag"]["item.neon_rat_tail"] = 1, "gear_bag 의 item.neon_rat_tail 는 모르는 장비"],
		["gear_bag 없음", func(d): d.erase("gear_bag"), "gear_bag 이 객체가 아니다"],
		["대원 객체의 모르는 키", func(d): _m(d, 3)["sp"] = 0, "party.members[3].sp 는 모르는 필드"],
		["대원 키 없음", func(d): _m(d, 3).erase("equip"), "party.members[3].equip 가 없다"],
	]
	for c in cases:
		_expect_reject(s, c[1], c[2], c[0])


## 듀얼리스트 A Lv4(SP 6) 에 퀵 드로 선행을 다 채우고 퀵 드로 1(관문 5).
func _quick_low(d: Dictionary) -> void:
	var m := _m(d, 1)
	m["level"] = 4
	m["exp"] = Fx.defs().battle.growth.cum(4)
	m["skills"] = {"skill.blade_duelist.blade_mastery": 3, OVERCLOCK: 1, "skill.blade_duelist.quick_draw": 1}


# ---- 2판 이전 ----

## 2판 원문을 읽은 사전과 3판 결과의 state_to_dict 에서 같은 경로를 비교한다(정규화 JSON).
func _same(orig: Dictionary, now: Dictionary, path: Array, label: String) -> void:
	var a: Variant = orig
	var b: Variant = now
	for k in path:
		a = a[k]
		b = b[k]
	check_eq(_canon(b), _canon(a), "%s: %s 보존" % [label, "/".join(path.map(func(k): return str(k)))])


func test_v2_migration_keeps_values_and_adds_growth_defaults() -> void:
	var defs := Fx.defs()
	for x in [["보통", V2_NORMAL], ["전투 중", V2_BATTLE], ["전멸", V2_WIPED]]:
		var label: String = x[0]
		var orig: Dictionary = JSON.parse_string(x[1])
		var r := SaveCodec.decode(x[1], defs)
		check(r.ok(), "%s: 이전 성공 %s" % [label, r.error])
		if not r.ok():
			continue
		var s := r.state
		var now := SaveCodec.state_to_dict(s)
		check_eq(now["floor_states"].keys(), ["f1_test"], "%s: 층 기록은 그 층 하나(5판)" % label)
		now.merge(now["floor_states"]["f1_test"])  # 5판 층 기록을 2판 자리와 견준다
		var o: Dictionary = orig["state"]
		for path in [["floor"], ["party", "at"], ["party", "facing"], ["world"], ["knowledge"], ["annotation"], ["encounter"], ["materials"], ["battle"], ["rng"], ["steps"], ["wiped"]]:
			_same(o, now, path, label)
		for i in 5:
			check_eq([now["party"]["members"][i]["hp"], now["party"]["members"][i]["tp"]], [int(o["party"]["members"][i]["hp"]), int(o["party"]["members"][i]["tp"])], "%s: 대원 %d HP·TP 보존" % [label, i])
			var m := s.party.members[i]
			check_eq([m.level, m.exp, m.skills, m.equip], [1, 0, defs.party.skills[i], defs.party.equips[i]], "%s: 대원 %d 성장 기본값(시작 배분·장비)" % [label, i])
		check_eq(s.gear_bag, {}, "%s: gear_bag {}" % label)
		check_eq([s.money, SaveCodec.state_to_dict(s)["shop"]], [200, {"sold": {}, "pool": {}, "bought": []}], "%s: 시작 소지금·빈 상점(08 §4)" % label)
		check_eq([r.from_schema, r.saved_at, r.generation, s.generation], [2, orig["saved_at"], int(orig["generation"]), int(orig["generation"])], "%s: 머리 보존·from_schema 2" % label)
		var again := SaveCodec.decode(x[1], defs)
		check(again.ok() and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(s), "%s: 두 번 읽어도 같은 해시" % label)
		_saves_same(s, label)


func test_v2_battle_units_keep_m2_inputs_and_lose_corrode() -> void:
	var defs := Fx.defs()
	var r := SaveCodec.decode(V2_BATTLE, defs)
	check(r.ok(), "이전 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	var want: Array = JSON.parse_string(V2_BATTLE_UNITS)
	for i in 5:
		var u := s.battle.party[i]
		var got := {"stats": u.stats, "gear": u.gear, "resist": u.resist, "ailment_vuln": u.ailment_vuln, "bind_vuln": u.bind_vuln, "attack": u.attack.element, "max_hp": u.max_hp, "max_tp": u.max_tp}
		check_eq(_canon(got), _canon(want[i]), "대원 %d 전투 유닛 입력값 = 2판 코드의 값(06 §6.1)" % i)
	check(s.battle.enemies[0].ailment == "poison" and s.battle.enemies[0].ailment_damage == 15, "적의 부식 글리프 독은 남음")
	# 부식 글리프 상실(07 §8.4 이전 정책): 명령은 unknown_skill 로 거부, 같은 자리의 열 글리프는 받음.
	var before := [SaveCodec.state_hash(s), str(s.rng.get_state()), _canon(s.battle.to_dict())]
	var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(CORRODE, 0)}))
	check(ev.size() == 1 and ev[0]["type"] == "rejected" and ev[0]["reason"] == "unknown_skill", "부식 글리프 → rejected{unknown_skill}: %s" % str(ev))
	check_eq([SaveCodec.state_hash(s), str(s.rng.get_state()), _canon(s.battle.to_dict())], before, "상태 해시·난수 불변")
	var ok := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
	check(not ok.is_empty() and ok[0]["type"] != "rejected", "열 글리프는 받는다: %s" % str(Fx.types(ok)))


func _v2_reject(text: String, mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(text)
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), Fx.defs())
	check(not r.ok() and r.state == null, "%s: 거부" % label)
	check(r.error.begins_with("2판 검사 실패: ") and r.error.contains(needle), "%s: 고정 2판 표로 이전 전에 거부, 실제 '%s'" % [label, r.error])


func test_v2_bad_original_rejected_before_migration() -> void:
	_v2_reject(V2_NORMAL, func(d): d["party"]["members"][0]["hp"] = 61, "party.members[0].hp 가 0~60", "나이트 HP 61")
	_v2_reject(V2_NORMAL, func(d): d["party"]["members"][0]["tp"] = 31, "party.members[0].tp 가 0~30", "나이트 TP 31")
	_v2_reject(V2_BATTLE, func(d): d["encounter"]["pending"] = false, "전투 대기", "battle 이 있는데 pending 거짓")
	_v2_reject(V2_BATTLE, func(d): d["battle"]["turn"] = -1, "battle.turn", "2판 battle 검사")
	var extra: Dictionary = JSON.parse_string(V2_NORMAL)
	extra["state"]["party"]["members"][0]["level"] = 7
	check(SaveCodec.decode(JSON.stringify(extra), Fx.defs()).ok(), "2판 대원의 남는 키는 보지 않는다(07 §10.2: 거부 사례가 아니다)")


## 지금 파티가 2판 고정 표와 다르면(대원 ID 바뀜·칸 순서 바뀜) 이전을 거부하고, 정의·지금 상태를 바꾸지 않는다.
func test_v2_migration_refuses_changed_party() -> void:
	var renamed := Fx.party_dict()
	renamed["members"][2]["id"] = "blade_duelist_b"
	var swapped := Fx.party_dict()
	var medic: Dictionary = swapped["members"][3]
	swapped["members"][3] = swapped["members"][4]
	swapped["members"][4] = medic
	for x in [["대원 ID 바뀜", renamed], ["칸 순서 바뀜", swapped]]:
		var defs := Fx.defs_from(Fx.battle_files(), x[1])
		check(defs != null, "%s: 정의는 읽힌다" % x[0])
		if defs == null:
			continue
		var ids_before := str(defs.party.ids)
		var start_before := Fx.events_text(defs.members().map(func(m): return [m.id, m.level, m.exp, m.skills, m.equip, m.hp, m.tp]))
		var current := ExplorationRules.new_game(defs, 4, "floor")
		var hash_before := SaveCodec.state_hash(current)
		for text in [V2_NORMAL, V2_BATTLE, V2_WIPED]:
			var r := SaveCodec.decode(text, defs)
			check(not r.ok() and r.state == null, "%s: 거부" % x[0])
			check(r.error.begins_with("2판 이전 실패: 지금 파티가 2판 파티"), "%s: 이유 %s" % [x[0], r.error])
		check_eq(str(defs.party.ids), ids_before, "%s: 정의의 대원 ID 그대로" % x[0])
		check_eq(Fx.events_text(defs.members().map(func(m): return [m.id, m.level, m.exp, m.skills, m.equip, m.hp, m.tp])), start_before, "%s: 시작 대원 값 그대로" % x[0])
		check_eq(SaveCodec.state_hash(current), hash_before, "%s: 지금 상태 불변" % x[0])


func test_v2_candidate_recovery_reads_bak() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(Fx.defs(), Fx.SAVE_DIR)
	var doc: Dictionary = JSON.parse_string(V2_NORMAL)
	doc["state"]["party"]["members"][0]["hp"] = 61
	var broken := JSON.stringify(doc)
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	for x in [[store.main_path("auto"), broken], [bak_path, V2_NORMAL]]:
		var f := FileAccess.open(x[0], FileAccess.WRITE)
		f.store_string(x[1])
		f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "bak" and l.failures.size() == 1, "깨진 2판 본 파일 → 정상 2판 .bak 이전: %s" % str(l.failures))
	if l.ok():
		check_eq([l.result.from_schema, l.result.saved_at, l.result.generation], [2, "2026-10-10T01:02:03Z", 17], ".bak 을 옮긴 결과")
	check_eq([FileAccess.get_file_as_string(store.main_path("auto")), FileAccess.get_file_as_string(bak_path)], [broken, V2_NORMAL], "파일은 그대로")
	Fx.clean_saves()


func _saves_same(s: ExplorationState, label: String) -> void:
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "%s: 4판 저장 → 읽기 같은 해시 %s" % [label, r.error])


# ---- 1판 → 4판 ----

func test_v1_migrates_straight_to_v4_with_growth_defaults() -> void:
	var defs := Fx.defs()
	for x in [[BS.V1_NORMAL, [30, 52, 23, 0, 40]], [BS.V1_PENDING, [60, 52, 52, 42, 1]], [BS.V1_WIPED, [0, 0, 0, 0, 0]]]:
		var r := SaveCodec.decode(x[0], defs)
		check(r.ok(), "이전 %s" % r.error)
		if not r.ok():
			continue
		var s := r.state
		check_eq([r.from_schema, s.party.members.map(func(m): return m.hp), s.party.members.map(func(m): return m.tp)], [1, x[1], [30, 32, 32, 54, 60]], "HP 비율 올림·TP 최대")
		for i in 5:
			var m := s.party.members[i]
			check_eq([m.id, m.level, m.exp, m.skills, m.equip], [defs.party.ids[i], 1, 0, defs.party.skills[i], defs.party.equips[i]], "대원 %d 성장 기본값" % i)
		check_eq([s.gear_bag, s.materials], [{}, {}], "가방·소재 비어 있음")
		check_eq([s.money, SaveCodec.state_to_dict(s)["shop"]], [200, {"sold": {}, "pool": {}, "bought": []}], "시작 소지금·빈 상점(08 §4)")
		check_eq(JSON.parse_string(SaveCodec.encode(s))["schema"], 6.0, "6판으로 쓴다")
		var again := SaveCodec.decode(x[0], defs)
		check(again.ok() and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(s), "두 번 읽어도 같은 해시")


func test_v1_pending_starts_battle_exactly_once() -> void:
	var defs := Fx.defs()
	var orig: Dictionary = JSON.parse_string(BS.V1_PENDING)
	var t := ExplorationState.new()
	t.defs = defs
	t.floor_def = defs.first_floor()
	t.rng.set_state(SaveCodec.parse_int64(orig["state"]["rng"]["state"]))
	var once := BattleRules.pick_formation(t)
	var after_once := str(t.rng.get_state())
	BattleRules.pick_formation(t)
	var after_twice := str(t.rng.get_state())
	var r := SaveCodec.decode(BS.V1_PENDING, defs)
	check(r.ok(), "이전 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	check_eq([s.battle.formation, str(s.rng.get_state())], [once, after_once], "편성·난수 = pick_formation 한 번")
	check(after_once != after_twice, "두 번 부른 난수와는 다르다")
	for i in 5:
		var u := s.battle.party[i]
		var p := GrowthRules.profile(defs, i, s.party.members[i])
		check_eq([u.stats, u.gear, u.max_hp, u.max_tp, u.hp], [p["stats"], p["gear"], p["max_hp"], p["max_tp"], s.party.members[i].hp], "대원 %d 전투 유닛 = 옮긴 대원의 묶음" % i)
	for text in [BS.V1_NORMAL, BS.V1_WIPED]:
		var o: Dictionary = JSON.parse_string(text)
		var n := SaveCodec.decode(text, defs)
		check(n.ok() and n.state.battle == null and str(n.state.rng.get_state()) == o["state"]["rng"]["state"], "pending 아니면 battle null·난수 그대로")
