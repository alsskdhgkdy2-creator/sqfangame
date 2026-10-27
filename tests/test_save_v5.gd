## 저장 5판(M3 A1): 층마다 기록(floor_states), 지금 층·위치는 전체 몫. 검사, 그리고 1~4판 모두 5판으로 옮기기.
## 4판 고정 문서 둘은 A1 전 코드(2a05fb3)로 f1_test 고정 공략을 걸어 만든 것이다(오늘 쓴 저장이 계속 읽히는지).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const BS := preload("res://tests/test_battle_save.gd")
const GS := preload("res://tests/test_growth_save.gd")
const A := ExplorationRules.Action

## 4판: 고정 공략 19행동 뒤 (2,5), 숨은 통로 h:2:6 찾음, 자동 경계 표시(full), 바닥 색·화살표·계단 아이콘·메모, 소재·소지금·상점.
const V4_DEVICES := '{"format":"sqfangame-save","generation":41,"rules":"m3s","saved_at":"2026-10-20T01:02:03Z","schema":4,"state":{"annotation":{"auto_edges":["h:2:16","v:2:11","v:2:12","v:2:13","v:2:14","v:2:15","v:3:11","v:3:12","v:3:13","v:3:14","v:3:15"],"edges":{"h:2:16":"door","v:2:11":"wall","v:2:12":"wall","v:2:13":"wall","v:2:14":"wall","v:2:15":"wall","v:3:11":"wall","v:3:12":"wall","v:3:13":"wall","v:3:14":"wall","v:3:15":"wall"},"floors":{"2:10":3,"2:11":0,"2:12":0,"2:13":0,"2:14":0,"2:15":0,"2:16":0,"2:17":0,"2:18":0,"2:4":0,"2:5":0,"2:6":0,"2:7":0,"2:8":0,"2:9":0},"icons":{"2:4":{"type":"stairs_down"},"2:9":{"dir":"E","type":"arrow"}},"memos":{"2:5":"숨은 방"}},"battle":null,"encounter":{"danger":130,"pending":false,"threshold":169},"floor":"f1_test","gear_bag":{},"knowledge":{"edges":{"h:2:10":"open","h:2:11":"open","h:2:12":"open","h:2:13":"open","h:2:14":"open","h:2:15":"open","h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","h:2:4":"open","h:2:5":"open","h:2:6":"passage","h:2:7":"open","h:2:8":"open","h:2:9":"open","v:2:10":"open","v:2:11":"wall","v:2:12":"wall","v:2:13":"wall","v:2:14":"wall","v:2:15":"wall","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:2:4":"open","v:2:5":"open","v:2:6":"open","v:2:7":"open","v:2:8":"open","v:2:9":"open","v:3:10":"open","v:3:11":"wall","v:3:12":"wall","v:3:13":"wall","v:3:14":"wall","v:3:15":"wall","v:3:16":"open","v:3:17":"open","v:3:18":"open","v:3:4":"open","v:3:5":"open","v:3:6":"open","v:3:7":"open","v:3:8":"open","v:3:9":"open"},"visited":["2:10","2:11","2:12","2:13","2:14","2:15","2:16","2:17","2:18","2:4","2:5","2:6","2:7","2:8","2:9"]},"materials":{"item.neon_rat_tail":4},"money":350,"party":{"at":[2,5],"facing":"S","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"8551677709994552875"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":15,"wiped":false,"world":{"passages_found":["h:2:6"],"shortcuts_open":[]}}}'
## 4판: 이어 걸어 (3,8)에서 전투 대기(battle 있음).
const V4_BATTLE := '{"format":"sqfangame-save","generation":42,"rules":"m3s","saved_at":"2026-10-21T04:05:06Z","schema":4,"state":{"annotation":{"auto_edges":["h:2:16","v:2:11","v:2:12","v:2:13","v:2:14","v:2:15","v:3:11","v:3:12","v:3:13","v:3:14","v:3:15"],"edges":{"h:2:16":"door","v:2:11":"wall","v:2:12":"wall","v:2:13":"wall","v:2:14":"wall","v:2:15":"wall","v:3:11":"wall","v:3:12":"wall","v:3:13":"wall","v:3:14":"wall","v:3:15":"wall"},"floors":{"2:10":3,"2:11":0,"2:12":0,"2:13":0,"2:14":0,"2:15":0,"2:16":0,"2:17":0,"2:18":0,"2:4":0,"2:5":0,"2:6":0,"2:7":0,"2:8":0,"2:9":0,"3:8":0},"icons":{"2:4":{"type":"stairs_down"},"2:9":{"dir":"E","type":"arrow"}},"memos":{"2:5":"숨은 방"}},"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":90,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":90,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78,"kill":null,"resist":{}}],"formation":"formation.f1.rats_moth","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"encounter":{"danger":170,"pending":true,"threshold":169},"floor":"f1_test","gear_bag":{},"knowledge":{"edges":{"h:2:10":"open","h:2:11":"open","h:2:12":"open","h:2:13":"open","h:2:14":"open","h:2:15":"open","h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","h:2:4":"open","h:2:5":"open","h:2:6":"passage","h:2:7":"open","h:2:8":"open","h:2:9":"open","h:3:8":"open","h:3:9":"open","v:2:10":"open","v:2:11":"wall","v:2:12":"wall","v:2:13":"wall","v:2:14":"wall","v:2:15":"wall","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:2:4":"open","v:2:5":"open","v:2:6":"open","v:2:7":"open","v:2:8":"open","v:2:9":"open","v:3:10":"open","v:3:11":"wall","v:3:12":"wall","v:3:13":"wall","v:3:14":"wall","v:3:15":"wall","v:3:16":"open","v:3:17":"open","v:3:18":"open","v:3:4":"open","v:3:5":"open","v:3:6":"open","v:3:7":"open","v:3:8":"open","v:3:9":"open","v:4:8":"open"},"visited":["2:10","2:11","2:12","2:13","2:14","2:15","2:16","2:17","2:18","2:4","2:5","2:6","2:7","2:8","2:9","3:8"]},"materials":{"item.neon_rat_tail":4},"money":350,"party":{"at":[3,8],"facing":"E","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"2899686016712193326"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":19,"wiped":false,"world":{"passages_found":["h:2:6"],"shortcuts_open":[]}}}'
const VICTORY_V3 := "res://tools/web_check_victory_save.json"
const SHOP_V4 := "res://tools/web_check_shop_save.json"


func _defs() -> GameDefs:
	return Fx.defs()


## f1 에서 f2 로 내려가 지름길·숨은 통로·그림을 남기고 f2 (1,1)에 선 상태(두 층 기록).
func _two_floors() -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), 21, "full")
	s.encounter.threshold = 99999
	s.party.at = Vector2i(14, 17)
	s.party.facing = Dir.E
	ExplorationRules.apply(s, A.FORWARD, "full")
	ExplorationRules.apply(s, A.STAIRS, "full")
	Fx.walk(s, "EEEE", "full")
	s.party.facing = Dir.S
	ExplorationRules.apply(s, A.INVESTIGATE, "full")
	Fx.walk(s, "S", "full")
	s.party.facing = Dir.W
	ExplorationRules.apply(s, A.FORWARD, "full")
	s.annotation.set_memo(Vector2i(4, 1), "아래층")
	Fx.walk(s, "W", "full")
	return s


## S1 (M12: 지금 층만 씀): 두 층 기록이 모두 남고 같은 해시로 돌아온다.
func test_v5_roundtrip_two_floors() -> void:
	var s := _two_floors()
	check_eq([s.floor_def.id, s.party.at], ["f2_test", Vector2i(3, 1)], "준비: f2 (3,1)")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	# 지금 쓰는 판은 8판(층 기록 짜임은 5판 그대로, M3 A2 가 장소·날을, M3 A3 이 귀중품과 world 의 문·상자 목록을 더했고, M3 A4 가 소모품을 더했다).
	check_eq([doc["schema"], doc["rules"], doc["state"]["floor"], doc["state"]["location"], doc["state"]["day"]],
		[8.0, "m3i", "f2_test", "labyrinth", 1.0], "8판 머리·지금 층·장소·날")
	check_eq(doc["state"]["floor_states"].keys(), ["f1_test", "f2_test"], "층 기록 둘(키 정렬)")
	for k in ["world", "knowledge", "annotation"]:
		check(not doc["state"].has(k), "%s 는 state 바로 아래에 없다" % k)
	check_eq(doc["state"]["floor_states"]["f2_test"]["world"], {"passages_found": ["h:4:1"], "shortcuts_open": ["v:4:1"], "locks_open": [], "chests_opened": []}, "f2 세계 상태")
	check_eq(doc["state"]["floor_states"]["f1_test"]["world"], {"passages_found": [], "shortcuts_open": [], "locks_open": [], "chests_opened": []}, "f1 세계 상태")
	var r := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(r.ok(), "읽기 %s" % r.error)
	if not r.ok():
		return
	check_eq([SaveCodec.state_hash(r.state), r.from_schema, r.state.floor_def.id, r.state.party.at], [SaveCodec.state_hash(s), 8, "f2_test", Vector2i(3, 1)], "같은 해시·지금 층·위치")
	check(r.state.world == r.state.floor_states["f2_test"].world, "지금 층 기록이 f2")
	check_eq(r.state.annotation.memos, {Vector2i(4, 1): "아래층"}, "f2 메모")
	# 읽은 상태로 계단을 올라가면 f1 기록이 이어진다.
	Fx.walk(r.state, "WNWW", "full")
	ExplorationRules.apply(r.state, A.STAIRS, "full")
	check_eq([r.state.floor_def.id, r.state.party.at], ["f1_test", Vector2i(15, 17)], "읽은 상태로 올라감")
	check(r.state.knowledge.is_visited(Vector2i(15, 17)) and r.state.knowledge.visited.size() == 2, "f1 방문 기록 이어짐(시작 칸·계단 칸)")


func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var before := SaveCodec.state_hash(s)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


## S2 (M13: 모든 기록을 지금 층으로 검사): floor_states 검사.
func test_v5_rejects_bad_floor_states() -> void:
	var s := _two_floors()
	_reject(s, func(d): d["floor_states"].erase("f2_test"), "지금 층 f2_test 가 없다", "지금 층 기록 없음")
	_reject(s, func(d): d.erase("floor_states"), "floor_states 가 객체가 아니다", "floor_states 없음")
	_reject(s, func(d): d["floor_states"]["f9"] = d["floor_states"]["f1_test"].duplicate(true), "f9 는 모르는 층", "모르는 층 키")
	_reject(s, func(d): d["floor_states"]["f1_test"]["extra"] = 1, "floor_states.f1_test.extra 는 모르는 필드", "모르는 필드")
	_reject(s, func(d): d["floor_states"]["f1_test"].erase("annotation"), "floor_states.f1_test.annotation 가 없다", "빠진 필드")
	_reject(s, func(d): d["floor_states"]["f1_test"] = [], "floor_states.f1_test 가 객체가 아니다", "객체 아님")
	# f2 에만 있는 지름길 경계를 f1 기록에 넣으면 f1 정의로 검사해 거부한다.
	_reject(s, func(d): d["floor_states"]["f1_test"]["world"]["shortcuts_open"].append("v:4:1"), "floor_states.f1_test.world.shortcuts_open", "다른 층 경계")
	_reject(s, func(d): d["floor_states"]["f2_test"]["knowledge"]["visited"].append("9:9"), "floor_states.f2_test.knowledge.visited", "f2 밖 방문")
	_reject(s, func(d): d["floor_states"]["f2_test"]["knowledge"]["edges"]["h:4:1"] = "wall", "floor_states.f2_test.knowledge.edges 의 h:4:1 겉모습", "f2 겉모습")
	# 지금 층이 아닌 f1 기록도 제 세계 상태와 맞아야 한다(리뷰: 지금 층만 맞춰 보면 지나간다). f1 의 벽 겉모습 하나를 열림으로.
	var f1_wall := _first_wall(s.floor_states["f1_test"])
	check(f1_wall != "", "준비: f1 기록에 본 벽")
	_reject(s, func(d): d["floor_states"]["f1_test"]["knowledge"]["edges"][f1_wall] = "open", "floor_states.f1_test.knowledge.edges 의 %s 겉모습" % f1_wall, "f1(지금 층 아님) 겉모습")
	# 5판은 기록이 하나여도 경로에 floor_states.<층 ID>. 를 붙인다.
	var one := ExplorationRules.new_game(_defs(), 21, "full")
	one.encounter.threshold = 99999
	for a in [A.FORWARD, A.TURN_LEFT, A.FORWARD, A.TURN_LEFT, A.FORWARD, A.TURN_LEFT, A.FORWARD]:
		ExplorationRules.apply(one, a, "full")
	check_eq(one.floor_states.size(), 1, "준비: 기록 하나")
	var one_wall := _first_wall(one.floor_states["f1_test"])
	check(one_wall != "", "준비: 기록 하나에 본 벽")
	_reject(one, func(d): d["floor_states"]["f1_test"]["knowledge"]["edges"][one_wall] = "open", "floor_states.f1_test.knowledge.edges 의 %s 겉모습" % one_wall, "기록 하나의 겉모습")
	# 위치는 지금 층(f2, 5×3)으로 본다: (2,10)은 f1 의 칸이지만 f2 밖이다.
	_reject(s, func(d): d["party"]["at"] = [2, 10], "party.at", "위치는 지금 층")


## 층 기록에서 벽으로 본 경계 하나(키 글). 없으면 "".
static func _first_wall(r: FloorState) -> String:
	for e in r.knowledge.edges:
		if r.knowledge.edges[e] == "wall":
			return GridKey.edge(e)
	return ""


## S2 (M14: 전투 편성을 첫 층 표로 검사): f2 에서 난 전투는 f2 출현 표의 편성이어야 한다.
func test_v5_battle_checked_against_current_floor_table() -> void:
	var s := _two_floors()
	s.encounter.threshold = s.encounter.danger + 1
	ExplorationRules.apply(s, A.BACK, "full")
	check(s.encounter.pending and s.battle != null, "준비: f2 에서 전투")
	check(_defs().battle.table_formations("encounter.f2_test").has(s.battle.formation), "준비: f2 표의 편성")
	var r := SaveCodec.decode(SaveCodec.encode(s), _defs())
	check(r.ok() and Fx.battle_hash(r.state) == Fx.battle_hash(s), "f2 전투 그대로 읽음 %s" % r.error)
	_reject(s, func(d): d["battle"]["formation"] = "formation.f1.rats", "이 층 출현 표의 편성이 아니다", "f1 표 편성")


## JSON 으로 한 번 돌려 정수·실수 표기를 맞춘 정렬 글.
static func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


## 옛 문서 하나를 읽어 5판으로 옮겼는지: from_schema·머리 보존, 5판으로 쓰고 다시 읽어 같은 해시, 층 기록은 f1_test 하나.
func _migrates(text: String, from: int, label: String) -> SaveCodec.LoadResult:
	var orig: Dictionary = JSON.parse_string(text)
	var r := SaveCodec.decode(text, _defs())
	check(r.ok(), "%s: 이전 성공 %s" % [label, r.error])
	if not r.ok():
		return r
	check_eq([r.from_schema, r.saved_at, r.generation, r.state.generation], [from, orig["saved_at"], int(orig["generation"]), int(orig["generation"])], "%s: from_schema·saved_at·generation" % label)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
	# M3 A2: 지금 판은 6판. 옛 저장은 미궁(층 기록 짜임은 5판 그대로)·1일째로 옮긴다.
	check_eq([doc["schema"], doc["rules"], doc["state"]["floor"], doc["state"]["floor_states"].keys(), doc["state"]["location"], doc["state"]["day"]],
		[8.0, "m3i", "f1_test", ["f1_test"], "labyrinth", 1.0], "%s: 8판으로 쓴다(층 하나, 미궁·1일째)" % label)
	var again := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(again.ok() and again.from_schema == 8 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 8판 다시 읽기 같은 해시" % label)
	if from >= 2:
		# 층 기록은 옛 문서의 world·knowledge·annotation 그대로(정규화해 견줌).
		var o: Dictionary = orig["state"]
		var rec: Dictionary = doc["state"]["floor_states"]["f1_test"]
		o["world"].merge({"locks_open": [], "chests_opened": []})  # 7판(M3 A3)이 world 에 더한 빈 목록 둘
		for k in ["world", "knowledge", "annotation"]:
			check_eq(_norm(rec[k]), _norm(o[k]), "%s: %s 보존" % [label, k])
	return r


## S3 (M15: migrate_v4 없음 — 4판을 5판 읽기로 읽으면 floor_states 가 없어 거부): 1~4판 모두.
func test_every_old_schema_migrates_to_v5() -> void:
	for x in [["1판 보통", BS.V1_NORMAL, 1], ["1판 전투 대기", BS.V1_PENDING, 1], ["1판 전멸", BS.V1_WIPED, 1],
			["2판 보통", GS.V2_NORMAL, 2], ["2판 전투", GS.V2_BATTLE, 2], ["2판 전멸", GS.V2_WIPED, 2],
			["3판 웹 승리 고정 문서", FileAccess.get_file_as_string(VICTORY_V3), 3],
			["4판 웹 상점 고정 문서", FileAccess.get_file_as_string(SHOP_V4), 4],
			["4판 장치", V4_DEVICES, 4], ["4판 전투", V4_BATTLE, 4]]:
		_migrates(x[1], x[2], x[0])


## S3: 4판 고정 문서의 값이 그대로 옮겨진다(위치·방향·위험도·난수·소재·소지금·상점·전투).
func test_v4_fixed_values_survive() -> void:
	for text in [V4_DEVICES, V4_BATTLE, FileAccess.get_file_as_string(SHOP_V4)]:
		var o: Dictionary = JSON.parse_string(text)["state"]
		var r := SaveCodec.decode(text, _defs())
		check(r.ok(), "읽기 %s" % r.error)
		if not r.ok():
			continue
		var now := SaveCodec.state_to_dict(r.state)
		for k in ["floor", "party", "encounter", "materials", "gear_bag", "money", "shop", "battle", "rng", "steps", "wiped"]:
			check_eq(_norm(now[k]), _norm(o[k]), "%s 보존 (%s)" % [k, str(o["party"]["at"])])
	var dev := SaveCodec.decode(V4_DEVICES, _defs()).state
	check(dev.world.is_passage_found(Vector3i(2, 6, 0)) and dev.annotation.memos.get(Vector2i(2, 5)) == "숨은 방" and dev.annotation.icons.get(Vector2i(2, 4), {}).get("type") == "stairs_down",
		"4판 장치: 찾은 통로·메모·플레이어 계단 아이콘")
	var bat := SaveCodec.decode(V4_BATTLE, _defs()).state
	check(bat.encounter.pending and bat.battle != null and _defs().battle.table_formations("encounter.f1_test").has(bat.battle.formation), "4판 전투: f1 표의 전투 그대로")
	# 4판 검사가 그대로 돈다: 4판 문서의 잘못된 층 기록은 「4판 검사 실패」.
	var bad: Dictionary = JSON.parse_string(V4_DEVICES)
	bad["state"]["world"]["passages_found"] = []
	var rb := SaveCodec.decode(JSON.stringify(bad), _defs())
	check(not rb.ok() and rb.error.begins_with("4판 검사 실패: ") and rb.error.contains("겉모습"), "4판 검사 %s" % rb.error)


## S4: 깨진 본 파일 → 정상 4판 .bak 을 5판으로 옮겨 읽는다(파일은 그대로).
func test_v4_candidate_recovery_reads_bak() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(_defs(), Fx.SAVE_DIR)
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	for x in [[store.main_path("auto"), "{broken"], [bak_path, V4_DEVICES]]:
		var f := FileAccess.open(x[0], FileAccess.WRITE)
		f.store_string(x[1])
		f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "bak", "깨진 본 파일 → 정상 4판 .bak: %s" % str(l.failures))
	if l.ok():
		check_eq([l.result.from_schema, l.result.saved_at, l.result.generation], [4, "2026-10-20T01:02:03Z", 41], ".bak 을 옮긴 결과")
	check_eq([FileAccess.get_file_as_string(store.main_path("auto")), FileAccess.get_file_as_string(bak_path)], ["{broken", V4_DEVICES], "파일은 그대로")
	Fx.clean_saves()
