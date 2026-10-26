## 마을(M3 A2a) 규칙: 장소(마을·미궁)와 행동, B1F 시작 칸 = 마을 문(계단 물음 이벤트·STAIRS 로 마을), ENTER, 층 묶음 검사, 마을 새 게임.
## 시험마다 이름 붙은 변이(설계 노트 §7.1, M…)를 죽이는지 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
## 층 묶음 파일 시험이 쓰는 임시 폴더(user://saves 가 아니다).
const SET_DIR := "user://test_town_set"

static var _real: GameDefs


## 실제 층 묶음(labyrinth.json: entrance = f1_test)의 정의.
func _defs() -> GameDefs:
	if _real == null:
		var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", TextDb.load_path("res://data/text/ko.json"))
		check(r.ok(), "실제 묶음 읽기 %s" % str(r.errors))
		_real = r.defs
	return _real


func _town(seed_value: int = 5, automap: String = "full") -> ExplorationState:
	return ExplorationRules.new_game(_defs(), seed_value, automap, true)


func _rng(s: ExplorationState) -> Variant:
	return SaveCodec.state_to_dict(s)["rng"]


## T1 (Ma 위험도 그대로 둠, Mb 앞 방향 그대로, Mc 시작 칸 기록 안 함): ENTER 는 미궁 첫 층 시작 칸·시작 방향, 위험도 0, 한계·걸음·난수 그대로.
func test_enter_from_town() -> void:
	for automap in ["floor", "full"]:
		var s := _town(5, automap)
		var f := _defs().first_floor()
		s.encounter.danger = 77
		s.party.facing = Dir.opposite(f.start_facing)  # 마을에서 돌아온 방향이 남아 있어도
		s.steps = 12
		var threshold := s.encounter.threshold
		var rng: Variant = _rng(s)
		check(not s.knowledge.is_visited(f.start_at), "준비: 마을 새 게임은 시작 칸을 기록하지 않았다")
		var ev := ExplorationRules.apply(s, A.ENTER, automap)
		check_eq(Fx.types(ev), ["entered"] as Array[String], "%s: 이벤트" % automap)
		check_eq([ev[0]["floor"], ev[0]["at"], ev[0]["facing"]], [f.id, f.start_at, f.start_facing], "%s: 이벤트 필드" % automap)
		check_eq([s.location, s.floor_def.id, s.party.at, s.party.facing], [ExplorationState.LABYRINTH, f.id, f.start_at, f.start_facing],
			"%s: 미궁 첫 층 시작 칸·시작 방향" % automap)
		check_eq([s.encounter.danger, s.encounter.threshold, s.steps, _rng(s)], [0, threshold, 12, rng], "%s: 위험도 0, 한계·걸음·난수 그대로" % automap)
		check(s.knowledge.is_visited(f.start_at) and s.annotation.floors.has(f.start_at), "%s: 시작 칸 방문·자동 바닥" % automap)
		check(not s.in_town(), "%s: 마을 밖" % automap)


## T2 (Md 마을에서 이동 허용): 마을에서는 ENTER 말고 모든 행동이 rejected town(상태 그대로). 미궁의 ENTER 는 blocked not_town.
func test_town_rejects_other_actions() -> void:
	var s := _town()
	var before := SaveCodec.state_hash(s)
	for a in A.values():
		if a == A.ENTER:
			continue
		var ev := ExplorationRules.apply(s, a, "full")
		check_eq(ev, [{"type": "rejected", "reason": "town"}] as Array[Dictionary], "마을에서 %s" % ExplorationRules.ACTION_NAMES.find_key(a))
	check_eq(SaveCodec.state_hash(s), before, "마을 상태 그대로")
	ExplorationRules.apply(s, A.ENTER, "full")
	var h := SaveCodec.state_hash(s)
	check_eq(ExplorationRules.apply(s, A.ENTER, "full"), [{"type": "blocked", "reason": "not_town"}] as Array[Dictionary], "미궁의 ENTER")
	check_eq(SaveCodec.state_hash(s), h, "미궁의 ENTER 는 상태를 바꾸지 않는다")
	check_eq(ExplorationRules.ACTION_NAMES["enter"], A.ENTER, "행동 이름 enter")
	check_eq(A.STAIRS, 8, "STAIRS 값은 그대로 8")


## 실제 층 둘을 새로 읽고 B1F 안전 구역(시작 칸 둘레 위험도 0)을 지운 묶음(entrance 그대로): 문 칸에서 전투가 날 수 있다.
func _unsafe_defs() -> GameDefs:
	var f1 := FloorLoader.load_path(Fx.F1_PATH).floor_def
	f1.zones = []
	var r := GameDefs.from_parts([f1, FloorLoader.load_path(Fx.F2_PATH).floor_def] as Array[FloorModel], PartyData.read_path(Fx.PARTY_PATH),
		Fx.defs().battle, null, true, "f1_test")
	check(r.ok(), "안전 구역 없는 묶음 %s" % str(r.errors))
	return r.defs


## 미궁 B1F 시작 칸(마을 문)에서 한 칸 나갔다가 돌아올 준비: 시작 칸에서 북쪽 한 칸.
func _off_gate(defs: GameDefs = null) -> ExplorationState:
	var s := ExplorationRules.new_game(defs if defs != null else _defs(), 5, "full", true)
	ExplorationRules.apply(s, A.ENTER, "full")
	s.encounter.threshold = 100000
	var ev := ExplorationRules.apply(s, A.FORWARD, "full")
	check_eq(Fx.types(ev), ["moved"] as Array[String], "준비: 문 밖으로 한 칸")
	return s


## T3 (Me entrance 열쇠 없이도 문, Mf 인카운트 판정보다 먼저 냄): 문 칸에 멈추면 마지막 이벤트 stairs {up, town}, 조사도 같다.
## 그 걸음에 전투가 나면 없다. 마을 문이 없는 시험 묶음(assemble)의 시작 칸은 아무것도 내지 않는다.
func test_gate_event() -> void:
	var s := _off_gate()
	var ev := ExplorationRules.apply(s, A.BACK, "full")
	check_eq(Fx.types(ev), ["moved", "stairs"] as Array[String], "문 칸으로 돌아오면 마지막에 물음")
	check_eq([ev[-1]["way"], ev[-1]["to"]], ["up", ExplorationState.TOWN], "문 이벤트 필드")
	check_eq(Fx.types(ExplorationRules.apply(s, A.INVESTIGATE, "full")), ["stairs"] as Array[String], "문 위 조사도 묻는다")
	check_eq(ExplorationRules.stair_here(s), {"way": "up", "to": ExplorationState.TOWN}, "stair_here = 문")
	# 그 걸음에 전투가 나면 묻지 않는다(실제 B1F 문 둘레는 안전 구역이라 구역을 지운 묶음으로 본다).
	var e := _off_gate(_unsafe_defs())
	e.encounter.danger = e.encounter.threshold - 1
	var ev2 := ExplorationRules.apply(e, A.BACK, "full")
	check(Fx.types(ev2).has("encounter") and not Fx.types(ev2).has("stairs"), "인카운트면 물음 없음 %s" % str(Fx.types(ev2)))
	check_eq(e.party.at, e.floor_def.start_at, "문 칸에 섰다")
	# 마을 문이 없는 묶음(시험 정의): 시작 칸은 그냥 바닥.
	var plain := ExplorationRules.new_game(Fx.defs(), 5, "full")
	plain.encounter.threshold = 100000
	var start := plain.party.at
	Fx.walk(plain, "N", "full")
	var back := ExplorationRules.apply(plain, A.BACK, "full")
	check_eq([plain.party.at, Fx.types(back)], [start, ["moved"] as Array[String]], "entrance 없는 묶음의 시작 칸: 물음 없음")
	check(ExplorationRules.stair_here(plain).is_empty() and not Fx.defs().is_gate(plain.floor_def, start), "entrance 없는 묶음: 문 아님")
	check(ExplorationRules.stair_here(_town()).is_empty(), "마을에서는 문도 계단도 없다")


## T4 (Mg 장소를 바꾸지 않음): 문 위 STAIRS → 마을. 층·칸·방향·걸음·위험도·한계·난수 그대로, 이벤트 to_town.
func test_stairs_on_gate_goes_to_town() -> void:
	var s := _off_gate()
	ExplorationRules.apply(s, A.BACK, "full")
	s.encounter.danger = 40
	var keep := [s.floor_def.id, s.party.at, s.party.facing, s.steps, s.encounter.danger, s.encounter.threshold, _rng(s)]
	var ev := ExplorationRules.apply(s, A.STAIRS, "full")
	check_eq(ev, [{"type": "to_town"}] as Array[Dictionary], "이벤트 to_town")
	check(s.in_town(), "마을에 있다")
	check_eq([s.floor_def.id, s.party.at, s.party.facing, s.steps, s.encounter.danger, s.encounter.threshold, _rng(s)], keep, "나머지 그대로")
	# 마을에서 들어가면 다시 시작 칸, 위험도 0.
	ExplorationRules.apply(s, A.ENTER, "full")
	check_eq([s.location, s.encounter.danger], [ExplorationState.LABYRINTH, 0], "다시 들어가면 위험도 0")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean_set_dir() -> void:
	var d := DirAccess.open(SET_DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(SET_DIR)


## 임시 폴더에 층 둘(f1·f2 원본 그대로)과 묶음 파일을 써서 읽는다.
func _load_set(manifest: Dictionary) -> FloorLoader.SetResult:
	_clean_set_dir()
	DirAccess.make_dir_recursive_absolute(SET_DIR)
	for id in ["f1_test", "f2_test"]:
		_write(SET_DIR + "/%s.json" % id, FileAccess.get_file_as_string("res://data/floors/%s.json" % id))
	_write(SET_DIR + "/labyrinth.json", JSON.stringify(manifest))
	return FloorLoader.load_set(SET_DIR + "/labyrinth.json")


## T5 (Mh entrance 검사 없음, Mi 아래층에 시작 허용): entrance 형식·자리, 둘째 층부터 시작 칸 금지.
func test_set_checks() -> void:
	var base := {"id": "labyrinth.t", "floors": ["f1_test", "f2_test"]}
	var ok := _load_set(base.merged({"entrance": "f1_test"}))
	check(ok.ok() and ok.entrance == "f1_test", "맞는 entrance %s" % str(ok.errors))
	var none := _load_set(base)
	check(none.ok() and none.entrance.is_empty(), "entrance 없음 = 마을 문 없음")
	for bad in [7, "", ["f1_test"], null]:
		var r := _load_set(base.merged({"entrance": bad}))
		check(r.errors.any(func(e: String) -> bool: return e.contains("labyrinth.json") and e.contains("entrance 는 층 ID 문자열")),
			"entrance %s 거부: %s" % [str(bad), str(r.errors)])
	_clean_set_dir()
	var party := PartyData.read_path(Fx.PARTY_PATH)
	var db := Fx.defs().battle
	for x in [["f2_test", "둘째 층"], ["f9", "모르는 층"]]:
		var floors: Array[FloorModel] = [FloorLoader.load_path(Fx.F1_PATH).floor_def, FloorLoader.load_path(Fx.F2_PATH).floor_def]
		var r := GameDefs.from_parts(floors, PartyData.read_path(Fx.PARTY_PATH), db, null, true, x[0])
		check(r.errors.any(func(e: String) -> bool: return e.contains("entrance: 마을 문은 첫 층(f1_test)") and e.contains(x[0])), "%s: %s" % [x[1], str(r.errors)])
	var good := GameDefs.from_parts([FloorLoader.load_path(Fx.F1_PATH).floor_def, FloorLoader.load_path(Fx.F2_PATH).floor_def] as Array[FloorModel],
		party, db, null, true, "f1_test")
	check(good.ok() and good.defs.entrance == "f1_test", "첫 층 entrance %s" % str(good.errors))
	# 둘째 층의 시작 칸.
	var f2 := FloorLoader.load_path(Fx.F2_PATH).floor_def
	f2.start_at = Vector2i(1, 1)
	f2.start_facing = Dir.E
	check(f2.has_start(), "준비: f2 에 시작 칸")
	var errs := FloorLoader.check_set([FloorLoader.load_path(Fx.F1_PATH).floor_def, f2] as Array[FloorModel])
	check(errs.any(func(e: String) -> bool: return e.contains("f2_test: start 는 첫 층에만")), "둘째 층 시작 칸 거부 %s" % str(errs))


## T6 (Mj 마을에서도 시작 칸 기록): 마을 새 게임은 마을·1일째, B1F 기록은 있지만 방문 없음, 난수는 미궁 새 게임과 같다.
func test_new_game_in_town() -> void:
	var t := ExplorationRules.new_game(_defs(), 9, "full", true)
	var l := ExplorationRules.new_game(_defs(), 9, "full")
	check_eq([t.location, t.day, t.floor_def.id, t.party.at, t.party.facing], [ExplorationState.TOWN, 1, "f1_test", l.party.at, l.party.facing],
		"마을·1일째·첫 층 시작 칸")
	check(t.floor_states.has("f1_test") and t.knowledge.visited.is_empty() and t.annotation.floors.is_empty(), "B1F 기록은 비어 있다")
	check_eq([_rng(t), t.encounter.threshold, t.money], [_rng(l), l.encounter.threshold, l.money], "난수·한계·소지금은 미궁 새 게임과 같다")
	check_eq([l.location, l.day], [ExplorationState.LABYRINTH, 1], "기본 새 게임은 미궁(시뮬·장면 시험)")


func teardown() -> void:
	_clean_set_dir()
	super()
