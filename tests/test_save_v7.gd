## 저장 7판(M3 A3): 귀중품(key_items)·층 기록 world 의 locks_open·chests_opened, 열쇠·상자·문 맞물림 검사, 6판 → 7판 이전,
## 은퇴한 시험 층(f1_test·f2_test) 저장을 게임 묶음(arbor)의 새 미궁으로 옮기기. 시험마다 죽이는 변이(설계 노트 §8.3, M-S…)를 적는다.
## 6판 고정 문서 셋은 A3 전 코드(HEAD 51e52c7)로 만든 것이다(오늘 쓴 6판 저장이 계속 읽히는지): 생성기는 저장소 밖에 두었다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const BS := preload("res://tests/test_battle_save.gd")
const GS := preload("res://tests/test_growth_save.gd")
const V5 := preload("res://tests/test_save_v5.gd")
const V6 := preload("res://tests/test_save_v6.gd")
const ROUTE_PATH := "res://data/floors/arbor_route.json"

## 6판: 마을 3일째(f1 시작 칸), 두 층 기록(f1 메모·계단 아이콘, f2 찾은 통로·연 지름길·메모), 소재 둘·가방·소지금 480·상점.
const V6_TOWN := '{"format":"sqfangame-save","generation":71,"rules":"m3t","saved_at":"2026-10-27T01:02:03Z","schema":6,"state":{"battle":null,"day":3,"encounter":{"danger":0,"pending":false,"threshold":99999},"floor":"f1_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["v:16:17"],"edges":{"v:16:17":"wall"},"floors":{"15:17":0,"2:18":0},"icons":{"15:17":{"type":"stairs_down"}},"memos":{"2:17":"입구 앞"}},"knowledge":{"edges":{"h:15:17":"open","h:15:18":"open","h:2:18":"open","h:2:19":"open","v:15:17":"open","v:16:17":"wall","v:2:18":"open","v:3:18":"open"},"visited":["15:17","2:18"]},"world":{"passages_found":[],"shortcuts_open":[]}},"f2_test":{"annotation":{"auto_edges":["h:0:0","h:0:1","h:1:0","h:1:1","h:2:0","h:3:0","h:3:1","h:3:2","h:4:0","v:0:0","v:4:1","v:5:0","v:5:1"],"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","v:0:0":"wall","v:4:1":"door","v:5:0":"wall","v:5:1":"wall"},"floors":{"0:0":0,"1:0":0,"2:0":0,"3:0":0,"3:1":0,"4:0":0,"4:1":0},"icons":{},"memos":{"4:1":"아래층"}},"knowledge":{"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:2:1":"open","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","h:4:1":"passage","h:4:2":"open","v:0:0":"wall","v:1:0":"open","v:2:0":"open","v:3:0":"open","v:3:1":"open","v:4:0":"open","v:4:1":"shortcut","v:5:0":"wall","v:5:1":"wall"},"visited":["0:0","1:0","2:0","3:0","3:1","4:0","4:1"]},"world":{"passages_found":["h:4:1"],"shortcuts_open":["v:4:1"]}}},"gear_bag":{"equip.twin_edge":1},"location":"town","materials":{"item.glow_scale":2,"item.neon_rat_tail":4},"money":480,"party":{"at":[2,18],"facing":"S","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-8757809823500504218"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":7,"wiped":false}}'
## 6판: f2 (4,1) 동쪽 전투 대기(formation.f2.serpent_moles), 2일째.
const V6_BATTLE := '{"format":"sqfangame-save","generation":72,"rules":"m3t","saved_at":"2026-10-27T04:05:06Z","schema":6,"state":{"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":150,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":120,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":150,"kill":null,"resist":{}}],"formation":"formation.f2.serpent_moles","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"day":2,"encounter":{"danger":80,"pending":true,"threshold":71},"floor":"f2_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["v:16:17"],"edges":{"v:16:17":"wall"},"floors":{"15:17":0,"2:18":2},"icons":{"3:18":{"dir":"E","type":"arrow"}},"memos":{"2:17":"입구 앞"}},"knowledge":{"edges":{"h:15:17":"open","h:15:18":"open","h:2:18":"open","h:2:19":"open","v:15:17":"open","v:16:17":"wall","v:2:18":"open","v:3:18":"open"},"visited":["15:17","2:18"]},"world":{"passages_found":[],"shortcuts_open":[]}},"f2_test":{"annotation":{"auto_edges":["h:0:0","h:0:1","h:1:0","h:1:1","h:2:0","h:3:0","h:3:1","h:3:2","h:4:0","v:0:0","v:4:1","v:5:0","v:5:1"],"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","v:0:0":"wall","v:4:1":"door","v:5:0":"wall","v:5:1":"wall"},"floors":{"0:0":0,"1:0":0,"2:0":0,"3:0":0,"3:1":0,"4:0":0,"4:1":0},"icons":{"0:0":{"type":"stairs_up"}},"memos":{"4:1":"아래층"}},"knowledge":{"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:2:1":"open","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","h:4:1":"passage","h:4:2":"open","v:0:0":"wall","v:1:0":"open","v:2:0":"open","v:3:0":"open","v:3:1":"open","v:4:0":"open","v:4:1":"shortcut","v:5:0":"wall","v:5:1":"wall"},"visited":["0:0","1:0","2:0","3:0","3:1","4:0","4:1"]},"world":{"passages_found":["h:4:1"],"shortcuts_open":["v:4:1"]}}},"gear_bag":{},"location":"labyrinth","materials":{"item.neon_rat_tail":4},"money":350,"party":{"at":[4,1],"facing":"E","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-9187674351286622835"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":8,"wiped":false}}'
## 6판: f1 시작 칸에서 전멸, 4일째, 걸음 40.
const V6_WIPED := '{"format":"sqfangame-save","generation":73,"rules":"m3t","saved_at":"2026-10-27T07:08:09Z","schema":6,"state":{"battle":null,"day":4,"encounter":{"danger":0,"pending":false,"threshold":147},"floor":"f1_test","floor_states":{"f1_test":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:18":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:2:18":"open","h:2:19":"open","v:2:18":"open","v:3:18":"open"},"visited":["2:18"]},"world":{"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"location":"labyrinth","materials":{},"money":200,"party":{"at":[2,18],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":0,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":0,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":0,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"35035103500997846"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":40,"wiped":true}}'


## JSON 정규화(정수·실수 차이를 없앤다).
static func _norm(x: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(x)), "", true)


## 게임 묶음 고정 공략을 앞에서 n 개 행동까지 걷는다(전투는 이겼다고 친다). 124 면 B3F 열쇠 상자를 연 뒤:
## 열쇠 둘, B2F 문 열림, B3F 관문은 닫힘, 세 층 기록.
func _arbor_state(n: int) -> ExplorationState:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	var s := ExplorationRules.new_game(Fx.arbor(), 31, "full")
	for i in n:
		ExplorationRules.apply(s, ExplorationRules.action_from_name(route["actions"][i]), "full")
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
	return s


func _lock_edge(floor_id: String, sealed: bool) -> String:
	var f := Fx.arbor().floor_by_id(floor_id)
	for e in f.edges_of_kind(FloorModel.Edge.LOCK):
		if f.is_sealed(e) == sealed:
			return GridKey.edge(e)
	return ""


## S1 (M-S1 floor_state_to_dict 가 chests_opened 를 빠뜨림): 열쇠·문·상자가 세 층에 걸친 상태를 쓰고 읽으면 같은 해시, world 키는 정확히 넷.
func test_v7_roundtrip() -> void:
	var s := _arbor_state(124)
	check_eq([s.floor_def.id, s.party.at, s.floor_states.size()], ["b3f", Vector2i(1, 12), 3], "준비: B3F 열쇠 상자 위, 세 층")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["schema"], doc["rules"], doc["state"]["key_items"]], [11.0, "m3r", ["key.moss_card", "key.relay_fuse"]], "11판 머리·귀중품(정렬)")
	for id in ["b1f", "b2f", "b3f"]:
		var keys: Array = doc["state"]["floor_states"][id]["world"].keys()
		keys.sort()
		check_eq(keys, ["chests_opened", "foes", "gather_used", "locks_open", "passages_found", "shortcuts_open"], "%s: world 키 정확히 여섯(10판)" % id)
	var w2: Dictionary = doc["state"]["floor_states"]["b2f"]["world"]
	var w3: Dictionary = doc["state"]["floor_states"]["b3f"]["world"]
	check_eq([w2["locks_open"], w3["locks_open"]], [[_lock_edge("b2f", false)], []], "B2F 문 열림, B3F 관문 닫힘")
	check(w2["chests_opened"].has("c1") and w3["chests_opened"] == ["c1"], "열쇠 상자 기록 %s %s" % [str(w2["chests_opened"]), str(w3["chests_opened"])])
	check(doc["state"]["floor_states"]["b1f"]["world"]["chests_opened"].has("c1"), "B1F 입구 상자")
	var r := SaveCodec.decode(JSON.stringify(doc), Fx.arbor())
	check(r.ok(), "읽기 %s" % r.error)
	if r.ok():
		check_eq([SaveCodec.state_hash(r.state), r.from_schema, r.relocated], [SaveCodec.state_hash(s), 11, false], "같은 해시, 11판, 옮김 없음")
		check(r.state.floor_states["b2f"].world.locks_open.size() == 1 and r.state.key_items.size() == 2, "문·열쇠 복원")
	var opened := SaveCodec.state_hash(s)
	s.floor_states["b1f"].world.chests_opened.erase("c1")
	check(SaveCodec.state_hash(s) != opened, "연 상자가 다르면 해시가 다르다")
	# 시험 묶음 새 게임: 빈 귀중품·빈 목록.
	var n := ExplorationRules.new_game(Fx.defs(), 5, "full")
	var nd: Dictionary = JSON.parse_string(SaveCodec.encode(n))
	check_eq([nd["state"]["key_items"], nd["state"]["floor_states"]["f1_test"]["world"]["locks_open"], nd["state"]["floor_states"]["f1_test"]["world"]["chests_opened"]],
		[[], [], []], "시험 묶음: 빈 귀중품·문·상자")


## 문서(머리 포함)를 바꿔 읽으면 거부(이유에 needle), 지금 상태 그대로.
func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var before := SaveCodec.state_hash(s)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


## S2 (M-S2a 맞물림 ①, M-S2b 맞물림 ②, M-S2c 봉인 문 열림 받음): 형식·참조·맞물림·머리 거부.
func test_v7_rejects() -> void:
	var s := _arbor_state(124)
	var lock2 := _lock_edge("b2f", false)
	var seal3 := _lock_edge("b3f", true)
	check(not lock2.is_empty() and not seal3.is_empty(), "준비: 문 경계")
	var fs := func(d: Dictionary, id: String) -> Dictionary: return d["state"]["floor_states"][id]["world"]
	_reject(s, func(d): fs.call(d, "b2f")["x"] = [], "floor_states.b2f.world.x 는 모르는 필드다", "모르는 world 키")
	_reject(s, func(d): fs.call(d, "b2f").erase("locks_open"), "floor_states.b2f.world.locks_open 가 없다", "locks_open 없음")
	_reject(s, func(d): fs.call(d, "b1f").erase("chests_opened"), "floor_states.b1f.world.chests_opened 가 없다", "chests_opened 없음")
	_reject(s, func(d): fs.call(d, "b2f")["locks_open"].append("h:0:0"), "floor_states.b2f.world.locks_open: h:0:0 가 그 종류의 경계가 아니다", "K 가 아닌 경계")
	_reject(s, func(d): fs.call(d, "b3f")["locks_open"] = [seal3], "floor_states.b3f.world.locks_open: %s 는 봉인 문이라 열릴 수 없다" % seal3, "봉인 문 열림")
	_reject(s, func(d): fs.call(d, "b2f")["chests_opened"].append("zz"), "floor_states.b2f.world.chests_opened: zz 는 이 층의 상자가 아니다", "모르는 상자")
	_reject(s, func(d): fs.call(d, "b2f")["chests_opened"].append("c1"), "floor_states.b2f.world.chests_opened: c1 가 두 번 있다", "상자 두 번")
	_reject(s, func(d): fs.call(d, "b2f")["chests_opened"] = "c1", "floor_states.b2f.world.chests_opened: 배열이 아니다", "상자 목록이 배열 아님")
	_reject(s, func(d): d["state"]["key_items"].append("key.moss_card"), "key_items 에 key.moss_card 가 두 번 있다", "열쇠 두 번")
	_reject(s, func(d): d["state"]["key_items"].append("key.nope"), "key_items 의 key.nope 는 모르는 귀중품이다", "모르는 귀중품")
	_reject(s, func(d): d["state"].erase("key_items"), "key_items 가 배열이 아니다", "key_items 없음")
	# 맞물림 ①: 열쇠를 가졌는데 그 상자를 열지 않았다.
	_reject(s, func(d): fs.call(d, "b3f")["chests_opened"].erase("c1"), "key_items 에 key.relay_fuse 가 있는데 그 상자 b3f:c1 를 열지 않았다", "열쇠만 있음")
	# 맞물림 ②: 상자를 열었는데 열쇠가 없다.
	_reject(s, func(d): d["state"]["key_items"] = ["key.moss_card"], "floor_states.b3f.world.chests_opened 의 c1 를 열었는데 열쇠 key.relay_fuse 가 없다", "상자만 열림")
	# 맞물림 ③: 문이 열렸는데 열쇠가 없다(그 열쇠 상자도 닫힘으로 맞춰 ①·②를 피한다).
	_reject(s, func(d):
		d["state"]["key_items"] = ["key.relay_fuse"]
		fs.call(d, "b2f")["chests_opened"].erase("c1"),
		"floor_states.b2f.world.locks_open 의 %s 가 열렸는데 열쇠 key.moss_card 가 없다" % lock2, "문만 열림")
	# 머리.
	_reject(s, func(d): d["schema"] = 6, "규칙 판(rules)이 schema 6 와 맞지 않다", "6판 머리에 m3i")
	_reject(s, func(d): d["rules"] = "m3t", "규칙 판(rules)이 schema 11 와 맞지 않다", "11판 머리에 m3t")
	_reject(s, func(d): d["schema"] = 12, "지원하지 않는 schema 다", "12판")


## S3 (M-S3 migrate_v6 가 day 를 버림): HEAD 코드로 만든 6판 고정 문서 셋을 시험 묶음으로 읽으면 7판, 원래 필드는 그대로이고 더해진 것은 빈 값뿐.
func test_fixed_v6_strings_migrate() -> void:
	for x in [["6판 마을", V6_TOWN, "town", 3], ["6판 전투", V6_BATTLE, "labyrinth", 2], ["6판 전멸", V6_WIPED, "labyrinth", 4]]:
		var orig: Dictionary = JSON.parse_string(x[1])
		var r := SaveCodec.decode(x[1], Fx.defs())
		check(r.ok(), "%s: 읽기 %s" % [x[0], r.error])
		if not r.ok():
			continue
		check_eq([r.from_schema, r.relocated, r.saved_at, r.generation, r.state.location, r.state.day],
			[6, false, orig["saved_at"], int(orig["generation"]), x[2], x[3]], "%s: 6판·옮김 없음·saved_at·generation·장소·날" % x[0])
		var o: Dictionary = orig["state"]
		for id in o["floor_states"]:
			o["floor_states"][id]["world"].merge({"locks_open": [], "chests_opened": [], "gather_used": {}, "foes": Fx.fresh_foes(id)})
		var sv := Fx.strip_v11(SaveCodec.state_to_dict(r.state), r.state.defs)  # M3 A7: 11판이 더한 길드 값은 기본값이어야 하고, 견주기에서는 뺀다
		check_eq(sv["bad"], "", "%s: 11판 길드 값은 기본값" % x[0])
		var now: Dictionary = sv["state"]
		for k in o:
			check_eq(_norm(now[k]), _norm(o[k]), "%s: %s 보존" % [x[0], k])
		check_eq(now.keys().filter(func(k: String) -> bool: return not o.has(k)), ["key_items", "consumables"], "%s: 더해진 필드는 key_items·consumables(8판) 뿐" % x[0])
		check_eq([now["key_items"], now["consumables"]], [[], {}], "%s: 빈 귀중품·빈 소모품" % x[0])
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
		check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판으로 쓴다" % x[0])
		var again := SaveCodec.decode(JSON.stringify(doc), Fx.defs())
		check(again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 11판 다시 읽기 같은 해시" % x[0])
	var bad: Dictionary = JSON.parse_string(V6_TOWN)
	bad["state"]["floor_states"].erase("f1_test")
	var rb := SaveCodec.decode(JSON.stringify(bad), Fx.defs())
	check(not rb.ok() and rb.error.begins_with("6판 검사 실패: ") and rb.error.contains("지금 층 f1_test 가 없다"), "6판 검사 %s" % rb.error)


## S4: 1~6판 고정 문서 모두 시험 묶음으로 7판이 된다(머리 보존, 다시 읽으면 같은 해시, 빈 귀중품).
func test_every_old_schema_migrates_to_v7() -> void:
	for x in [["1판 보통", BS.V1_NORMAL, 1], ["1판 전투 대기", BS.V1_PENDING, 1], ["1판 전멸", BS.V1_WIPED, 1],
			["2판 보통", GS.V2_NORMAL, 2], ["2판 전투", GS.V2_BATTLE, 2], ["2판 전멸", GS.V2_WIPED, 2],
			["3판 웹 승리 고정 문서", FileAccess.get_file_as_string(V5.VICTORY_V3), 3],
			["4판 웹 상점 고정 문서", FileAccess.get_file_as_string(V5.SHOP_V4), 4],
			["4판 장치", V5.V4_DEVICES, 4], ["4판 전투", V5.V4_BATTLE, 4],
			["5판 두 층", V6.V5_TWO_FLOORS, 5], ["5판 전투", V6.V5_BATTLE, 5],
			["6판 마을", V6_TOWN, 6], ["6판 전투", V6_BATTLE, 6], ["6판 전멸", V6_WIPED, 6]]:
		var orig: Dictionary = JSON.parse_string(x[1])
		var r := SaveCodec.decode(x[1], Fx.defs())
		check(r.ok(), "%s: 이전 성공 %s" % [x[0], r.error])
		if not r.ok():
			continue
		check_eq([r.from_schema, r.saved_at, r.generation, r.state.key_items], [x[2], orig["saved_at"], int(orig["generation"]), {}],
			"%s: from_schema·saved_at·generation·빈 귀중품" % x[0])
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
		check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판으로 쓴다" % x[0])
		var again := SaveCodec.decode(JSON.stringify(doc), Fx.defs())
		check(again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 다시 읽기 같은 해시" % x[0])


## S5 (M-S5a 전투 대기를 남김, M-S5b 가방을 잃음, M-S5c relocated 표시 없음): 시험 층 저장을 게임 묶음으로 읽으면 새 미궁으로 옮긴다.
## 마을(전멸이면 B1F 시작 칸에서 전멸), 대원·돈·소재·가방·상점·귀중품·날·난수·걸음·한계값·generation 은 그대로, 전투 대기는 버리고 B1F 기록 하나.
func test_relocation_with_game_set() -> void:
	var defs := Fx.arbor()
	check(defs != null and defs.retired != null, "arbor 와 은퇴한 묶음")
	if defs == null or defs.retired == null:
		return
	var b1 := defs.first_floor()
	var now_test := SaveCodec.encode(SaveCodec.decode(V6_BATTLE, Fx.defs()).state, "2026-10-27T09:00:00Z", 80)
	for x in [["6판 마을", V6_TOWN, 6], ["6판 전투", V6_BATTLE, 6], ["6판 전멸", V6_WIPED, 6], ["1판 보통", BS.V1_NORMAL, 1],
			["3판 웹 승리 고정 문서", FileAccess.get_file_as_string(V5.VICTORY_V3), 3], ["지금 판(11판) 시험 층 저장", now_test, SaveCodec.SCHEMA]]:
		var old := SaveCodec.decode(x[1], defs.retired)
		var r := SaveCodec.decode(x[1], defs)
		check(old.ok() and r.ok(), "%s: 읽기 %s / %s" % [x[0], old.error, r.error])
		if not (old.ok() and r.ok()):
			continue
		var o := old.state
		var n := r.state
		check_eq([r.relocated, r.from_schema, r.saved_at, r.generation], [true, x[2], old.saved_at, old.generation], "%s: 옮김·원본 판·saved_at·generation" % x[0])
		check_eq([n.floor_def.id, n.party.at, n.party.facing, n.location, n.wiped],
			["b1f", b1.start_at, b1.start_facing, ExplorationState.LABYRINTH if o.wiped else ExplorationState.TOWN, o.wiped], "%s: 마을(전멸이면 B1F 시작 칸)" % x[0])
		check_eq([n.floor_states.keys(), n.encounter.pending, n.battle == null, n.encounter.danger, n.encounter.threshold],
			[["b1f"], false, true, 0, o.encounter.threshold], "%s: B1F 기록 하나, 전투 대기 없음, 위험도 0, 한계값 그대로" % x[0])
		var od := SaveCodec.state_to_dict(o)
		var nd := SaveCodec.state_to_dict(n)
		for k in ["materials", "gear_bag", "consumables", "money", "shop", "key_items", "day", "rng", "steps"]:
			check_eq(_norm(nd[k]), _norm(od[k]), "%s: %s 그대로" % [x[0], k])
		check_eq(_norm(nd["party"]["members"]), _norm(od["party"]["members"]), "%s: 대원 그대로" % x[0])
		var again := SaveCodec.decode(SaveCodec.encode(n), defs)
		check(again.ok() and not again.relocated and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(n),
			"%s: 9판으로 다시 쓰고 읽으면 옮김 없이 같은 해시 %s" % [x[0], again.error])
	var town := SaveCodec.decode(V6_TOWN, defs).state
	check(town != null and town.gear_bag == {"equip.twin_edge": 1} and town.money == 480, "6판 마을: 가방·돈 값")
	# 깨진 시험 층 저장은 옛 정의 검사에서 걸린다.
	var bad: Dictionary = JSON.parse_string(V6_TOWN)
	bad["state"]["floor_states"].erase("f1_test")
	var rb := SaveCodec.decode(JSON.stringify(bad), defs)
	check(not rb.ok() and rb.state == null and rb.error.begins_with("옛 시험 층 저장 검사 실패: 6판 검사 실패: "), "깨진 옛 저장 %s" % rb.error)
	# 게임 층을 가리키는 저장은 옮기지 않는다(시험 묶음에는 은퇴한 묶음이 없다).
	check(not SaveCodec.decode(V6_TOWN, Fx.defs()).relocated, "시험 묶음은 옮기지 않는다")


## S6: 6판 본 파일을 게임 묶음으로 읽어 옮긴 뒤 자동 저장하면 .bak 은 6판 원본 그대로, 본 파일은 7판 B1F(시험 저장 폴더).
func test_relocated_autosave_keeps_v6_bak() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(Fx.arbor(), Fx.SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var main := store.main_path("auto")
	var bak := main.get_basename() + ".bak"
	var f := FileAccess.open(main, FileAccess.WRITE)
	f.store_string(V6_TOWN)
	f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and l.result.relocated, "6판 본 파일을 옮겨 읽음 %s" % str(l.failures))
	if not l.ok():
		Fx.clean_saves()
		return
	check_eq(store.save("auto", l.result.state), "", "자동 저장")
	check_eq(FileAccess.get_file_as_string(bak), V6_TOWN, ".bak 은 6판 원본")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main))
	check_eq([doc["schema"], doc["state"]["floor"], doc["state"]["location"], doc["generation"]], [11.0, "b1f", "town", 72.0], "본 파일은 11판 B1F 마을")
	var again := store.load_slot("auto")
	check(again.ok() and again.source_kind == "main" and not again.result.relocated and again.result.from_schema == 11, "다시 읽으면 옮김 없음")
	Fx.clean_saves()


func teardown() -> void:
	Fx.clean_saves()
	super()
