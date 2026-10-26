extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

## test_movement 과 같은 5×3 장치 층.
const GRID := [
	"+-+-+-+-+-+",
	"|. .D. . .|",
	"+ +-+ +-+L+",
	"|.>. .<. .|",
	"+H+-+v+-+^+",
	"|. .H. . .|",
	"+-+-+-+-+-+",
]

var _floor: FloorModel


func _f() -> FloorModel:
	if _floor == null:
		_floor = Fx.floor_of(GRID, {"id": "fx_save", "shortcuts": [{"at": [4, 1], "dir": "N"}], "encounter": {"danger_per_step": 10, "threshold_min": 500, "threshold_max": 900}})
	return _floor


func _store() -> SaveStore:
	return SaveStore.new(Fx.defs(_f()), Fx.SAVE_DIR)


## 일방통행을 지나고, 숨은 통로를 찾고, 지름길을 연 상태(위치는 남쪽으로만 경계를 지난 (2,2)).
func _played() -> ExplorationState:
	var s := Fx.game(_f(), 99, "full")
	Fx.walk(s, "SEENWWS", "full")  # 동쪽으로만 v(1,1)을 지나 한 바퀴 돌아 (0,1)
	ExplorationRules.apply(s, A.INVESTIGATE, "full")  # 숨은 통로 h(0,2)
	Fx.walk(s, "SEEWN", "full")  # 통로로 (0,2)·(1,2), 숨은 통로 v(2,2) 앞 막힘, 다시 (0,1)
	Fx.walk(s, "EESEEN", "full")  # 남쪽으로만·북쪽으로만을 지나 (4,1)
	Fx.walk(s, "N", "full")  # 지름길 열기(움직이지 않음)
	Fx.walk(s, "NW", "full")  # (4,0) → (3,0)
	s.annotation.set_icon(Vector2i(3, 0), "arrow", Dir.E)
	s.annotation.set_memo(Vector2i(4, 0), "지름길")
	Fx.walk(s, "WSS", "full")  # (2,0) → (2,1) → 남쪽으로만 (2,2)
	return s


func _moved(dirs: String) -> ExplorationState:
	var s := _played()
	Fx.walk(s, dirs, "full")
	return s


func _roundtrip(s: ExplorationState) -> SaveCodec.LoadResult:
	return SaveCodec.decode(SaveCodec.encode(s), Fx.defs(_f()))


func test_roundtrip_same_hash_and_devices() -> void:
	var s := _played()
	check(s.world.is_shortcut_open(Vector3i(4, 1, 0)), "준비: 지름길 열림")
	check(s.world.is_passage_found(Vector3i(0, 2, 0)), "준비: 통로 찾음")
	check_eq(s.party.at, Vector2i(2, 2), "준비: 일방통행 뒤 위치")
	var r := _roundtrip(s)
	check(r.ok(), "읽기 %s" % r.error)
	if not r.ok():
		return
	check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "상태 해시 같음")
	check(r.state.world.is_shortcut_open(Vector3i(4, 1, 0)), "열린 지름길 유지")
	check(r.state.world.is_passage_found(Vector3i(0, 2, 0)), "찾은 통로 유지")
	check_eq([r.state.party.at, r.state.party.facing], [Vector2i(2, 2), Dir.S], "위치·방향 유지")
	check_eq(ExplorationRules.apply(r.state, A.BACK, "full"), [{"type": "blocked", "reason": "oneway"}] as Array[Dictionary], "일방통행 규칙 유지")


func test_rng_state_signed_and_large_values() -> void:
	for value in [-4611686018427387904, 9007199254740993, -1, 9223372036854775807, -9223372036854775807 - 1, 0]:
		var s := Fx.game(_f(), 5)
		s.rng.set_state(value)
		var text := SaveCodec.encode(s)
		check(text.contains("\"state\":\"%d\"" % value), "%d: 10진 문자열" % value)
		var r := SaveCodec.decode(text, Fx.defs(_f()))
		check(r.ok(), "%d: 읽기 %s" % [value, r.error])
		if not r.ok():
			continue
		check_eq(r.state.rng.get_state(), value, "%d: 상태 보존" % value)
		var a := []
		var b := []
		for i in 10:
			a.append(s.rng.randi_range(0, 1 << 30))
			b.append(r.state.rng.randi_range(0, 1 << 30))
		check_eq(b, a, "%d: 이어지는 난수열 일치" % value)


func test_parse_int64() -> void:
	check_eq(SaveCodec.parse_int64("9223372036854775807"), 9223372036854775807, "최대")
	check_eq(SaveCodec.parse_int64("-9223372036854775808"), -9223372036854775807 - 1, "최소")
	for bad in ["9223372036854775808", "-9223372036854775809", "99999999999999999999", "01", "+1", "-0", "1.0", "", "-", " 1", "1e3", 12]:
		check(SaveCodec.parse_int64(bad) == null, "거부: %s" % str(bad))


func test_to_int_rejects_fraction_and_bool() -> void:
	check_eq(SaveCodec.to_int(3.0), 3, "정수 같은 실수")
	for bad in [2.9, true, "3", null, INF]:
		check(SaveCodec.to_int(bad) == null, "거부: %s" % str(bad))


## 저장 문서의 한 필드를 바꿔 읽으면 거부되고 원래 상태는 그대로인지.
func _expect_reject(mutate: Callable, needle: String, label: String) -> void:
	var s := _played()
	var before := SaveCodec.state_hash(s)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), Fx.defs(_f()))
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


func test_rejects_bad_header() -> void:
	_expect_reject(func(d): d["format"] = "other", "format", "형식")
	_expect_reject(func(d): d["schema"] = 7, "schema", "새 schema")
	_expect_reject(func(d): d["schema"] = 1, "rules", "schema 1 + rules m3t 쌍")
	_expect_reject(func(d): d["schema"] = 3, "rules", "schema 3 + rules m3t 쌍")
	_expect_reject(func(d): d["schema"] = 4, "rules", "schema 4 + rules m3t 쌍")
	_expect_reject(func(d): d["schema"] = 5, "rules", "schema 5 + rules m3t 쌍")
	_expect_reject(func(d): d["rules"] = "m3f", "rules", "schema 6 + rules m3f 쌍")
	_expect_reject(func(d): d["rules"] = "m3s", "rules", "schema 6 + rules m3s 쌍")
	_expect_reject(func(d): d["rules"] = "m2g", "rules", "schema 6 + rules m2g 쌍")
	_expect_reject(func(d): d.merge({"schema": 3, "rules": "m2"}, true), "rules", "schema 3 + rules m2 쌍")
	_expect_reject(func(d): d.merge({"schema": 2, "rules": "m2g"}, true), "rules", "schema 2 + rules m2g 쌍")
	_expect_reject(func(d): d["schema"] = 0, "schema", "schema 0")
	_expect_reject(func(d): d["schema"] = 1.5, "schema", "schema 소수")
	_expect_reject(func(d): d["rules"] = "m0", "rules", "규칙 판")
	_expect_reject(func(d): d["state"]["floor"] = "f9", "층", "층 ID")
	_expect_reject(func(d): d.erase("generation"), "generation", "generation 없음")
	_expect_reject(func(d): d["saved_at"] = "2026-10-16 12:00", "saved_at", "saved_at 형식")
	_expect_reject(func(d): d["saved_at"] = "2026-10-16T04:05:06Z\n", "saved_at", "saved_at 끝 줄바꿈")


func test_rejects_bad_types() -> void:
	_expect_reject(func(d): d["state"]["steps"] = 2.9, "steps", "걸음 소수")
	_expect_reject(func(d): d["state"]["steps"] = true, "steps", "걸음 불리언")
	_expect_reject(func(d): d["state"]["party"]["members"][0]["hp"] = 2.9, "hp", "HP 소수")
	_expect_reject(func(d): d["state"]["encounter"]["pending"] = 1, "pending", "pending 숫자")
	_expect_reject(func(d): d["state"]["rng"]["state"] = 12345, "rng.state", "난수 숫자")
	_expect_reject(func(d): d["state"]["rng"]["state"] = "12x", "rng.state", "난수 문자")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["memos"]["4:0"] = "가".repeat(41), "memos", "메모 41자")
	_expect_reject(func(d): Fx.cur(d)["knowledge"]["visited"].append("01:0"), "visited", "칸 키 형식")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["floors"]["x:1"] = 1, "floors", "지도 칸 키")
	_expect_reject(func(d): Fx.cur(d)["knowledge"]["edges"]["q:1:1"] = "wall", "knowledge.edges", "경계 키")


func test_rejects_bad_ranges_and_refs() -> void:
	_expect_reject(func(d): d["state"]["party"]["at"] = [0, 5], "party.at", "층 밖 위치")
	_expect_reject(func(d): d["state"]["party"]["facing"] = "Q", "facing", "방향")
	_expect_reject(func(d): d["state"]["party"]["members"].pop_back(), "members", "대원 수")
	_expect_reject(func(d): d["state"]["party"]["members"].reverse(), "id", "대원 순서")
	_expect_reject(func(d): d["state"]["party"]["members"][0]["hp"] = 61, "hp", "HP 초과")
	_expect_reject(func(d): d["state"]["party"]["members"][0]["hp"] = -1, "hp", "HP 음수")
	_expect_reject(func(d): Fx.cur(d)["world"]["shortcuts_open"].append("v:1:0"), "shortcuts_open", "지름길 아닌 경계")
	_expect_reject(func(d): Fx.cur(d)["world"]["passages_found"].append("h:4:1"), "passages_found", "통로 아닌 경계")
	_expect_reject(func(d): Fx.cur(d)["knowledge"]["visited"].append("9:9"), "visited", "층 밖 방문")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["floors"]["0:0"] = 5, "floors", "지도 색 5")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["icons"]["0:0"] = {"type": "dragon"}, "icons", "아이콘 종류")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["icons"]["0:0"] = {"type": "arrow"}, "화살표", "화살표 방향")
	_expect_reject(func(d): Fx.cur(d)["annotation"]["auto_edges"].append("v:3:2"), "auto_edges", "표시 없는 자동 목록")
	_expect_reject(func(d): d["state"]["encounter"]["threshold"] = 0, "threshold", "한계값 0")
	_expect_reject(func(d): d["state"]["encounter"]["danger"] = -1, "danger", "위험도 음수")


func test_rejects_inconsistent_state() -> void:
	_expect_reject(func(d): d["state"]["wiped"] = true, "wiped", "HP 남았는데 전멸")
	_expect_reject(_zero_hp, "wiped", "모두 0 인데 전멸 아님")
	_expect_reject(_wiped_and_pending, "전투 대기", "전멸 + 대기")
	_expect_reject(func(d): Fx.cur(d)["world"]["passages_found"] = [], "겉모습", "찾은 통로를 잃은 관찰")
	_expect_reject(func(d): Fx.cur(d)["knowledge"]["edges"]["v:2:2"] = "passage", "겉모습", "못 찾은 통로를 통로로 관찰")


func _zero_hp(d: Dictionary) -> void:
	for m in d["state"]["party"]["members"]:
		m["hp"] = 0


func _wiped_and_pending(d: Dictionary) -> void:
	_zero_hp(d)
	d["state"]["wiped"] = true
	d["state"]["encounter"]["pending"] = true


func test_set_order_does_not_change_hash() -> void:
	var a := Fx.game(_f(), 3)
	var b := Fx.game(_f(), 3)
	var edges := [Vector3i(4, 1, 0), Vector3i(0, 2, 0), Vector3i(2, 2, 1)]
	a.world.open_shortcut(edges[0])
	a.world.find_passage(edges[1])
	a.world.find_passage(edges[2])
	b.world.find_passage(edges[2])
	b.world.find_passage(edges[1])
	b.world.open_shortcut(edges[0])
	for c in [Vector2i(3, 0), Vector2i(1, 2), Vector2i(4, 2)]:
		a.knowledge.visit(c)
	for c in [Vector2i(4, 2), Vector2i(3, 0), Vector2i(1, 2)]:
		b.knowledge.visit(c)
	for e in [Vector3i(3, 0, 0), Vector3i(0, 1, 1)]:
		a.annotation.auto_edge(e, "wall")
	for e in [Vector3i(0, 1, 1), Vector3i(3, 0, 0)]:
		b.annotation.auto_edge(e, "wall")
	a.annotation.set_memo(Vector2i(1, 0), "가")
	a.annotation.set_memo(Vector2i(0, 1), "나")
	b.annotation.set_memo(Vector2i(0, 1), "나")
	b.annotation.set_memo(Vector2i(1, 0), "가")
	check_eq(SaveCodec.state_hash(a), SaveCodec.state_hash(b), "넣은 순서와 상관없는 해시")
	check(SaveCodec.canonical_state(a).contains("\"visited\":[\"0:0\",\"1:2\",\"3:0\",\"4:2\"]"), "집합 배열 정렬")


func test_generation_and_saved_at() -> void:
	Fx.clean_saves()
	var store := _store()
	var s := _played()
	var h := SaveCodec.state_hash(s)
	check_eq(store.save("slot1", s), "", "저장")
	check_eq(store.save("auto", s), "", "다른 슬롯 저장")
	check_eq(s.generation, 2, "어느 슬롯이든 성공하면 generation +1")
	check_eq(SaveCodec.state_hash(s), h, "generation 은 해시 밖")
	check(SaveCodec.encode(s).contains("\"generation\":2"), "내보내기는 지금 값 그대로")
	check_eq(s.generation, 2, "내보내기는 올리지 않음")
	var l := store.load_slot("slot1")
	check(l.ok() and l.result.generation == 1 and l.result.state.generation == 1, "읽으면 그 파일의 값")
	if l.ok():
		check_eq(store.save("slot1", l.result.state), "", "읽은 상태 저장")
		check_eq(l.result.state.generation, 2, "읽은 값에 이어서 +1")
	var re := RegEx.create_from_string("^\\d{4}-\\d\\d-\\d\\dT\\d\\d:\\d\\d:\\d\\dZ$")
	check(l.ok() and re.search(l.result.saved_at) != null, "saved_at UTC 형식 %s" % (l.result.saved_at if l.ok() else ""))
	Fx.clean_saves()


func test_failed_write_keeps_generation() -> void:
	Fx.clean_saves()
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var blocker := FileAccess.open(Fx.SAVE_DIR + "/blocker", FileAccess.WRITE)
	blocker.store_string("파일")
	blocker.close()
	var store := SaveStore.new(Fx.defs(_f()), Fx.SAVE_DIR + "/blocker/sub")
	var s := _played()
	var why := store.save("auto", s)
	check(not why.is_empty(), "폴더 자리에 파일이 있으면 실패하고 사유를 돌려줌")
	check_eq(s.generation, 0, "실패하면 generation 그대로")
	Fx.clean_saves()


func test_slot_info_and_load_candidates() -> void:
	Fx.clean_saves()
	var store := _store()
	var none := store.slot_info("slot3")
	check(not none.exists and not none.ok, "없는 슬롯")
	var s := _played()
	store.save("slot3", s, "2026-10-16T04:05:06Z")
	var info := store.slot_info("slot3")
	check(info.exists and info.ok and info.saved_at == "2026-10-16T04:05:06Z" and info.generation == 1 and info.source_kind == "main", "슬롯 정보")
	var f := FileAccess.open(store.main_path("slot3"), FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	info = store.slot_info("slot3")
	check(info.exists and not info.ok, "깨진 슬롯은 있지만 정상 아님")
	var l := store.load_slot("slot3")
	check(l.all_failed() and l.failures.size() == 1 and l.source_kind == "", "모두 실패 알림과 사유")
	Fx.clean_saves()


## 쓰기 ①~③ 각 단계 뒤에 멈춘 경우 읽기 순서로 복구되는지.
func test_interrupted_writes_recover() -> void:
	var cases := {1: "A", 2: "A", 3: "B"}
	for stop in [1, 2, 3]:
		Fx.clean_saves()
		var store := _store()
		var a := _played()
		check_eq(store.save("auto", a), "", "A 저장")
		var hash_a := SaveCodec.state_hash(a)
		var b := _moved("N")
		var hash_b := SaveCodec.state_hash(b)
		store.stop_after_step = stop
		var gen := b.generation
		check(store.save("auto", b).begins_with("시험 중단"), "B 저장 %d단계에서 멈춤" % stop)
		check_eq(b.generation, gen, "%d단계 중단: 실패한 쓰기는 generation 그대로" % stop)
		store.stop_after_step = 0
		var l := store.load_slot("auto")
		check(l.ok(), "%d단계 중단 뒤 읽기 %s" % [stop, l.result.error])
		if l.ok():
			check_eq(SaveCodec.state_hash(l.result.state), hash_a if cases[stop] == "A" else hash_b, "%d단계 중단 뒤 %s 복구" % [stop, cases[stop]])
	Fx.clean_saves()


func test_partial_tmp_does_not_win() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _played()
	store.save("auto", a)
	var f := FileAccess.open(Fx.SAVE_DIR + "/auto.tmp", FileAccess.WRITE)
	f.store_string("{\"format\": \"sqfangame-save\", \"sch")
	f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source.ends_with("auto.json") and l.source_kind == "main", "깨진 .tmp 대신 본 파일")
	Fx.clean_saves()


func test_only_bak_recovers() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _played()
	store.save("slot2", a)
	var hash_a := SaveCodec.state_hash(a)
	store.save("slot2", _moved("E"))
	DirAccess.remove_absolute(store.main_path("slot2"))
	var l := store.load_slot("slot2")
	check(l.ok() and l.source.ends_with("slot2.bak") and l.source_kind == "bak", "본 파일 없이 .bak 에서 복구")
	check(l.ok() and SaveCodec.state_hash(l.result.state) == hash_a, ".bak 은 직전 정상 저장")
	Fx.clean_saves()


func test_broken_main_does_not_replace_good_bak() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _played()
	store.save("auto", a)
	store.save("auto", _moved("N"))  # 본 = B, .bak = A
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	var bak_before := FileAccess.get_file_as_string(bak_path)
	var f := FileAccess.open(store.main_path("auto"), FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source.ends_with("auto.bak") and l.failures.size() == 1, "깨진 본 파일 → .bak")
	var c := _moved("E")
	check_eq(store.save("auto", c), "", "C 저장")
	check_eq(FileAccess.get_file_as_string(bak_path), bak_before, "깨진 본 파일이 .bak 을 덮지 않음")
	l = store.load_slot("auto")
	check(l.ok() and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(c), "새 본 파일")
	Fx.clean_saves()


func test_all_candidates_broken_reported() -> void:
	Fx.clean_saves()
	var store := _store()
	check(not store.load_slot("auto").had_candidates, "후보 없음")
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(store.main_path("auto"), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	var l := store.load_slot("auto")
	check(not l.ok() and l.had_candidates, "후보가 모두 깨졌음을 알림")
	Fx.clean_saves()


func test_pending_and_wiped_saved_and_restored() -> void:
	Fx.clean_saves()
	var store := _store()
	var p := _played()
	p.encounter.danger = p.encounter.threshold
	BattleRules.start(p, "formation.f1.rats")
	check_eq(store.save("auto", p), "", "전투 대기 자동 저장")
	var l := store.load_slot("auto")
	check(l.ok() and l.result.state.encounter.pending, "전투 대기 복구")
	if l.ok():
		check_eq(ExplorationRules.apply(l.result.state, A.FORWARD, "full")[0]["reason"], "pending", "복구 뒤에도 거부")
	var w := _played()
	for m in w.party.members:
		m.hp = 0
	w.wiped = true
	check_eq(store.save("auto", w), "", "전멸 자동 저장")
	l = store.load_slot("auto")
	check(l.ok() and l.result.state.wiped, "전멸 복구")
	Fx.clean_saves()


func test_latest_manual_slot() -> void:
	Fx.clean_saves()
	var store := _store()
	check_eq(store.latest_manual(), "", "수동 저장 없음")
	store.save("slot1", _played(), "2026-10-16T01:00:00Z")
	store.save("slot2", _played(), "2026-10-16T03:00:00Z")
	store.save("slot3", _played(), "2026-10-16T02:00:00Z")
	store.save("auto", _played(), "2026-10-16T09:00:00Z")
	check_eq(store.latest_manual(), "slot2", "가장 늦은 정상 수동 슬롯")
	var f := FileAccess.open(store.main_path("slot2"), FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	check_eq(store.latest_manual(), "slot3", "깨진 슬롯은 건너뜀")
	Fx.clean_saves()
