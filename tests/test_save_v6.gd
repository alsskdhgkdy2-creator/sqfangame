## 저장 6판(M3 A2a): 장소(location: town·labyrinth)·날(day). 마을 불변식(첫 층 시작 칸, 전투 대기·전멸 아님) 검사,
## 그리고 1~5판 모두 6판으로 옮기기(옛 저장은 미궁·1일째). 시험마다 이름 붙은 변이(설계 노트 §7.2, M…)를 죽이는지 적는다.
## 5판 고정 문서 둘은 A2 전 코드(6ba5025)로 만든 것이다(오늘 쓴 저장이 계속 읽히는지): 생성기는 tmp/ 에 두고 지웠다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const BS := preload("res://tests/test_battle_save.gd")
const GS := preload("res://tests/test_growth_save.gd")
const V5 := preload("res://tests/test_save_v5.gd")
const A := ExplorationRules.Action

## 5판: f1 에서 내려가 f2 (3,1) 서쪽, 두 층 기록(f1 메모·화살표, f2 찾은 통로·연 지름길·메모·계단 아이콘), 소재·소지금·상점.
const V5_TWO_FLOORS := '{"format":"sqfangame-save","generation":57,"rules":"m3f","saved_at":"2026-10-22T07:08:09Z","schema":5,"state":{"battle":null,"encounter":{"danger":70,"pending":false,"threshold":99999},"floor":"f2_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["v:16:17"],"edges":{"v:16:17":"wall"},"floors":{"15:17":0,"2:18":2},"icons":{"3:18":{"dir":"E","type":"arrow"}},"memos":{"2:17":"입구 앞"}},"knowledge":{"edges":{"h:15:17":"open","h:15:18":"open","h:2:18":"open","h:2:19":"open","v:15:17":"open","v:16:17":"wall","v:2:18":"open","v:3:18":"open"},"visited":["15:17","2:18"]},"world":{"passages_found":[],"shortcuts_open":[]}},"f2_test":{"annotation":{"auto_edges":["h:0:0","h:0:1","h:1:0","h:1:1","h:2:0","h:3:0","h:3:1","h:3:2","h:4:0","v:0:0","v:4:1","v:5:0","v:5:1"],"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","v:0:0":"wall","v:4:1":"door","v:5:0":"wall","v:5:1":"wall"},"floors":{"0:0":0,"1:0":0,"2:0":0,"3:0":0,"3:1":0,"4:0":0,"4:1":0},"icons":{"0:0":{"type":"stairs_up"}},"memos":{"4:1":"아래층"}},"knowledge":{"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:2:1":"open","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","h:4:1":"passage","h:4:2":"open","v:0:0":"wall","v:1:0":"open","v:2:0":"open","v:3:0":"open","v:3:1":"open","v:4:0":"open","v:4:1":"shortcut","v:5:0":"wall","v:5:1":"wall"},"visited":["0:0","1:0","2:0","3:0","3:1","4:0","4:1"]},"world":{"passages_found":["h:4:1"],"shortcuts_open":["v:4:1"]}}},"gear_bag":{},"materials":{"item.neon_rat_tail":4},"money":350,"party":{"at":[3,1],"facing":"W","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-8757809823500504218"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":7,"wiped":false}}'
## 5판: f2 (4,1)에서 전투 대기(formation.f2.serpent_moles).
const V5_BATTLE := '{"format":"sqfangame-save","generation":58,"rules":"m3f","saved_at":"2026-10-23T10:11:12Z","schema":5,"state":{"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":150,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":120,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":150,"kill":null,"resist":{}}],"formation":"formation.f2.serpent_moles","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"encounter":{"danger":80,"pending":true,"threshold":71},"floor":"f2_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["v:16:17"],"edges":{"v:16:17":"wall"},"floors":{"15:17":0,"2:18":2},"icons":{"3:18":{"dir":"E","type":"arrow"}},"memos":{"2:17":"입구 앞"}},"knowledge":{"edges":{"h:15:17":"open","h:15:18":"open","h:2:18":"open","h:2:19":"open","v:15:17":"open","v:16:17":"wall","v:2:18":"open","v:3:18":"open"},"visited":["15:17","2:18"]},"world":{"passages_found":[],"shortcuts_open":[]}},"f2_test":{"annotation":{"auto_edges":["h:0:0","h:0:1","h:1:0","h:1:1","h:2:0","h:3:0","h:3:1","h:3:2","h:4:0","v:0:0","v:4:1","v:5:0","v:5:1"],"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","v:0:0":"wall","v:4:1":"door","v:5:0":"wall","v:5:1":"wall"},"floors":{"0:0":0,"1:0":0,"2:0":0,"3:0":0,"3:1":0,"4:0":0,"4:1":0},"icons":{"0:0":{"type":"stairs_up"}},"memos":{"4:1":"아래층"}},"knowledge":{"edges":{"h:0:0":"wall","h:0:1":"wall","h:1:0":"wall","h:1:1":"wall","h:2:0":"wall","h:2:1":"open","h:3:0":"wall","h:3:1":"wall","h:3:2":"wall","h:4:0":"wall","h:4:1":"passage","h:4:2":"open","v:0:0":"wall","v:1:0":"open","v:2:0":"open","v:3:0":"open","v:3:1":"open","v:4:0":"open","v:4:1":"shortcut","v:5:0":"wall","v:5:1":"wall"},"visited":["0:0","1:0","2:0","3:0","3:1","4:0","4:1"]},"world":{"passages_found":["h:4:1"],"shortcuts_open":["v:4:1"]}}},"gear_bag":{},"materials":{"item.neon_rat_tail":4},"money":350,"party":{"at":[4,1],"facing":"E","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-9187674351286622835"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":8,"wiped":false}}'


func _defs() -> GameDefs:
	return Fx.defs()


## JSON 정규화(정수·실수 차이를 없앤다).
static func _norm(x: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(x)), "", true)


## 5판 시험의 두 층 상태(f2 (3,1), 두 층 기록).
func _two() -> ExplorationState:
	return V5.new()._two_floors()


## 마을 새 게임(1일째).
func _town(day: int = 1) -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), 5, "full", true)
	s.day = day
	return s


## S1 (Mk location 안 씀, Ml day 안 씀): 마을(7일째)과 미궁 f2 를 쓰고 읽으면 같은 해시·장소·날.
func test_v6_roundtrip_town_and_labyrinth() -> void:
	var t := _town(7)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(t))
	check_eq([doc["schema"], doc["rules"], doc["state"]["location"], doc["state"]["day"]], [10.0, "m3o", "town", 7.0], "10판 머리·마을·7일째")
	var r := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(r.ok(), "마을 읽기 %s" % r.error)
	if r.ok():
		check_eq([SaveCodec.state_hash(r.state), r.from_schema, r.state.location, r.state.day, r.state.party.at],
			[SaveCodec.state_hash(t), 10, "town", 7, t.party.at], "마을: 같은 해시·장소·날·위치")
	var t8 := _town(8)
	check(SaveCodec.state_hash(t8) != SaveCodec.state_hash(t), "날이 다르면 해시가 다르다")
	var l := _two()
	l.day = 3
	var ld: Dictionary = JSON.parse_string(SaveCodec.encode(l))
	check_eq([ld["state"]["location"], ld["state"]["day"], ld["state"]["floor"]], ["labyrinth", 3.0, "f2_test"], "미궁 f2·3일째")
	var lr := SaveCodec.decode(JSON.stringify(ld), _defs())
	check(lr.ok() and SaveCodec.state_hash(lr.state) == SaveCodec.state_hash(l) and lr.state.location == "labyrinth" and lr.state.day == 3,
		"미궁 읽기 %s" % lr.error)
	var town_l := l
	town_l.location = ExplorationState.TOWN
	check(SaveCodec.state_hash(town_l) != SaveCodec.state_hash(lr.state), "장소가 다르면 해시가 다르다")


## 문서의 state 를 바꿔 읽으면 거부(이유에 needle), 지금 상태 그대로.
func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var before := SaveCodec.state_hash(s)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


## S2 (Mm 마을 불변식 검사 없음): 장소·날 형식, 마을이면 첫 층 시작 칸·전투 대기 아님·전멸 아님.
func test_v6_rejects() -> void:
	var t := _town(2)
	const LOC := "location 이 town·labyrinth 가 아니다"
	var day_msg := "day 가 1~%d 정수가 아니다" % ExplorationState.DAY_MAX
	_reject(t, func(d): d.erase("location"), LOC, "location 없음")
	_reject(t, func(d): d["location"] = "castle", LOC, "모르는 장소")
	_reject(t, func(d): d["location"] = 1, LOC, "장소가 수")
	_reject(t, func(d): d["location"] = null, LOC, "장소 null")
	for bad in [0, -1, 2.5, 100000, true, "3", null]:
		_reject(t, func(d): d["day"] = bad, day_msg, "day %s" % str(bad))
	_reject(t, func(d): d.erase("day"), day_msg, "day 없음")
	# 마을인데 f2 에 있다(f2 (3,1) 상태에 location town).
	var f2 := _two()
	_reject(f2, func(d): d["location"] = "town", "마을에 있으면 층은 첫 층(f1_test)", "마을인데 f2")
	# 마을인데 시작 칸이 아니다.
	var off := ExplorationRules.new_game(_defs(), 5, "full")
	off.encounter.threshold = 99999
	Fx.walk(off, "N", "full")
	_reject(off, func(d): d["location"] = "town", "위치는 그 시작 칸", "마을인데 시작 칸 밖")
	# 마을인데 전투 대기(1판 전투 대기 문서는 시작 칸 (2,18)).
	var pend := SaveCodec.decode(BS.V1_PENDING, _defs())
	check(pend.ok() and pend.state.encounter.pending and pend.state.party.at == pend.state.floor_def.start_at, "준비: 시작 칸 전투 대기 %s" % pend.error)
	if pend.ok():
		_reject(pend.state, func(d): d["location"] = "town", "마을에서는 전투 대기·전멸일 수 없다", "마을인데 전투 대기")
	var wiped := SaveCodec.decode(BS.V1_WIPED, _defs())
	check(wiped.ok() and wiped.state.wiped and wiped.state.party.at == wiped.state.floor_def.start_at, "준비: 시작 칸 전멸 %s" % wiped.error)
	if wiped.ok():
		_reject(wiped.state, func(d): d["location"] = "town", "마을에서는 전투 대기·전멸일 수 없다", "마을인데 전멸")
	# 경계값은 받는다.
	for ok_day in [1, ExplorationState.DAY_MAX]:
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(t))
		doc["state"]["day"] = ok_day
		var r := SaveCodec.decode(JSON.stringify(doc), _defs())
		check(r.ok() and r.state.day == ok_day, "day %d 받음 %s" % [ok_day, r.error])


## 옛 문서 text(판 from)를 읽으면 6판 상태(미궁·1일째), 머리 보존, 6판으로 쓰고 다시 읽으면 같은 해시.
func _migrates(text: String, from: int, label: String) -> SaveCodec.LoadResult:
	var orig: Dictionary = JSON.parse_string(text)
	var r := SaveCodec.decode(text, _defs())
	check(r.ok(), "%s: 이전 성공 %s" % [label, r.error])
	if not r.ok():
		return r
	check_eq([r.from_schema, r.saved_at, r.generation, r.state.location, r.state.day], [from, orig["saved_at"], int(orig["generation"]), "labyrinth", 1],
		"%s: from_schema·saved_at·generation·미궁·1일째" % label)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
	check_eq([doc["schema"], doc["rules"], doc["state"]["location"], doc["state"]["day"]], [10.0, "m3o", "labyrinth", 1.0], "%s: 10판으로 쓴다" % label)
	var again := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(again.ok() and again.from_schema == 10 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 10판 다시 읽기 같은 해시" % label)
	return r


## S3 (Mn migrate_v5 없음 = 5판을 6판 읽기로 읽으면 location 이 없어 거부, Mo 5판을 마을로 옮김): 1~5판 모두.
func test_every_old_schema_migrates_to_v6() -> void:
	for x in [["1판 보통", BS.V1_NORMAL, 1], ["1판 전투 대기", BS.V1_PENDING, 1], ["1판 전멸", BS.V1_WIPED, 1],
			["2판 보통", GS.V2_NORMAL, 2], ["2판 전투", GS.V2_BATTLE, 2], ["2판 전멸", GS.V2_WIPED, 2],
			["3판 웹 승리 고정 문서", FileAccess.get_file_as_string(V5.VICTORY_V3), 3],
			["4판 웹 상점 고정 문서", FileAccess.get_file_as_string(V5.SHOP_V4), 4],
			["4판 장치", V5.V4_DEVICES, 4], ["4판 전투", V5.V4_BATTLE, 4],
			["5판 두 층", V5_TWO_FLOORS, 5], ["5판 전투", V5_BATTLE, 5]]:
		_migrates(x[1], x[2], x[0])


## S3: 5판 고정 문서의 값이 모두 그대로 옮겨진다(층 기록 둘·위치·방향·위험도·난수·소재·소지금·상점·전투).
func test_v5_fixed_values_survive() -> void:
	for text in [V5_TWO_FLOORS, V5_BATTLE]:
		var o: Dictionary = JSON.parse_string(text)["state"]
		var r := SaveCodec.decode(text, _defs())
		check(r.ok(), "읽기 %s" % r.error)
		if not r.ok():
			continue
		var now := SaveCodec.state_to_dict(r.state)
		# 7판(M3 A3)이 층 기록 world 에 더한 빈 목록 둘, 9판(M3 A5)의 빈 채집 기록, 10판(M3 A6)의 처음 FOE 기록은 원본에 넣어 두고 비교한다(나머지는 그대로).
		for id in o["floor_states"]:
			o["floor_states"][id]["world"].merge({"locks_open": [], "chests_opened": [], "gather_used": {}, "foes": Fx.fresh_foes(id)})
		for k in o:
			check_eq(_norm(now[k]), _norm(o[k]), "%s 보존 (%s)" % [k, str(o["party"]["at"])])
		check_eq(now.keys().filter(func(k: String) -> bool: return not o.has(k)), ["location", "day", "key_items", "consumables"], "6·7·8판에서 더해진 필드는 location·day·key_items·consumables 뿐")
		check_eq([now["key_items"], now["consumables"]], [[], {}], "귀중품·소모품(8판)은 비었다")
	var two := SaveCodec.decode(V5_TWO_FLOORS, _defs()).state
	check_eq([two.floor_def.id, two.party.at, two.annotation.memos, two.floor_states["f1_test"].annotation.memos],
		["f2_test", Vector2i(3, 1), {Vector2i(4, 1): "아래층"}, {Vector2i(2, 17): "입구 앞"}], "5판 두 층: 지금 층·위치·두 층 메모")
	check(two.world.is_shortcut_open(Vector3i(4, 1, 1)) and two.world.is_passage_found(Vector3i(4, 1, 0)), "5판 두 층: 지름길·통로")
	var bat := SaveCodec.decode(V5_BATTLE, _defs()).state
	check(bat.encounter.pending and bat.battle != null and bat.battle.formation == "formation.f2.serpent_moles", "5판 전투: f2 표의 전투 그대로")
	# 5판 검사가 그대로 돈다: 5판 문서의 잘못된 층 기록은 「5판 검사 실패」.
	var bad: Dictionary = JSON.parse_string(V5_TWO_FLOORS)
	bad["state"]["floor_states"].erase("f2_test")
	var rb := SaveCodec.decode(JSON.stringify(bad), _defs())
	check(not rb.ok() and rb.error.begins_with("5판 검사 실패: ") and rb.error.contains("지금 층 f2_test 가 없다"), "5판 검사 %s" % rb.error)
	# 5판 문서에 location 을 넣어도 5판 읽기는 보지 않는다(5판 저장은 모두 미궁).
	var odd: Dictionary = JSON.parse_string(V5_TWO_FLOORS)
	odd["state"]["location"] = "town"
	var ro := SaveCodec.decode(JSON.stringify(odd), _defs())
	check(ro.ok() and ro.state.location == "labyrinth", "5판의 location 은 무시하고 미궁 %s" % ro.error)


## S4: 깨진 본 파일 → 정상 5판 .bak 을 6판으로 옮겨 읽는다(시험 저장 폴더, 파일은 그대로).
func test_v5_candidate_recovery_reads_bak() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(_defs(), Fx.SAVE_DIR)
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	for x in [[store.main_path("auto"), "{broken"], [bak_path, V5_TWO_FLOORS]]:
		var f := FileAccess.open(x[0], FileAccess.WRITE)
		f.store_string(x[1])
		f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "bak", "깨진 본 파일 → 정상 5판 .bak: %s" % str(l.failures))
	if l.ok():
		check_eq([l.result.from_schema, l.result.saved_at, l.result.generation, l.result.state.location], [5, "2026-10-22T07:08:09Z", 57, "labyrinth"],
			".bak 을 옮긴 결과")
	check_eq(FileAccess.get_file_as_string(bak_path), V5_TWO_FLOORS, ".bak 파일은 그대로")
	Fx.clean_saves()


func teardown() -> void:
	Fx.clean_saves()
	super()
