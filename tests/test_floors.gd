## 여러 층(M3 A1): 층 묶음·계단 형식과 검사, 계단을 넣은 도달·갇힘 분석, 계단 규칙(밟기·조사·층 바꾸기), 층별 기록 분리.
## 시험마다 이름 붙은 변이(설계 노트 §7, M…)를 죽이는지 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

## 위층 fa: (0,0) 시작, (2,0) 내려가는 계단(내려설 칸 (1,0)). 아래층 fb: (0,0) 올라가는 계단(내려설 칸 (1,0)), 시작 없음.
const FA_STAIR := {"at": [2, 0], "way": "down", "exit": "W", "to": {"floor": "fb", "at": [0, 0]}}
const FB_STAIR := {"at": [0, 0], "way": "up", "exit": "E", "to": {"floor": "fa", "at": [2, 0]}}


func _dict(id: String, cells: String, stairs: Array, extra: Dictionary = {}) -> Dictionary:
	var d := Fx.floor_dict(Fx.row_grid(cells, " ".repeat(cells.length() - 1)), {"id": id, "name_key": "floor.f1_test", "stairs": stairs})
	d.merge(extra, true)
	return d


func _fa(extra: Dictionary = {}) -> Dictionary:
	return _dict("fa", "...", [FA_STAIR], extra)


func _fb(extra: Dictionary = {}) -> Dictionary:
	var d := _dict("fb", "...", [FB_STAIR], extra)
	if not extra.has("start"):
		d.erase("start")
	return d


func _model(d: Dictionary) -> FloorModel:
	var r := Fx.parse(d)
	if not r.ok():
		push_error("시험 층 오류: %s" % str(r.errors))
		return null
	return r.floor_def


func _errors(d: Dictionary) -> Array[String]:
	return Fx.parse(d).errors


func _has(errs: Array, needle: String, label: String) -> void:
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


## fa·fb 묶음의 정의(출현 표: fa = f1, fb = f2, 한계값은 층마다 따로 줄 수 있다).
func _pair_defs(fa_extra: Dictionary = {}, fb_extra: Dictionary = {}) -> GameDefs:
	var a := _model(_fa(fa_extra))
	var b := _model(_fb(fb_extra))
	a.encounter_table = "encounter.f1_test"
	b.encounter_table = "encounter.f2_test"
	check_eq(FloorLoader.check_set([a, b] as Array[FloorModel]), [] as Array[String], "준비: fa·fb 층 사이 검사 통과")
	return GameDefs.assemble([a, b] as Array[FloorModel], Fx.defs().party, Fx.defs().battle)


# ---- 형식·묶음 (T1~T5) ----

## T1 (M1: 깊이를 0부터 세면 B0F): 실제 묶음이 오류·경고 없이 읽히고 층 표시가 B1F·B2F.
func test_real_set_loads_clean_with_labels() -> void:
	var texts := TextDb.load_path("res://data/text/ko.json")
	var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", texts)
	check_eq(r.errors, [] as Array[String], "오류 0")
	if not r.ok():
		return
	var d := r.defs
	check_eq(d.floor_ids, ["f1_test", "f2_test"] as Array[String], "깊이 차례")
	check_eq([d.first_floor().id, d.depth_of("f1_test"), d.depth_of("f2_test"), d.depth_of("nope")], ["f1_test", 1, 2, 0], "깊이")
	check_eq([FloorNames.label(texts, d, d.floor_by_id("f1_test")), FloorNames.label(texts, d, d.floor_by_id("f2_test"))], ["B1F", "B2F"], "층 표시")
	check_eq(FloorNames.place(texts, d, d.first_floor()), "시험 층 / B1F", "장소 글(원작 「第1階層 / B1F」 꼴)")
	for id in d.floor_ids:
		check_eq(FloorLoader.analyze(d.floor_by_id(id), id + ".json"), [] as Array[String], "%s: 분석 경고 0" % id)
	var down := d.first_floor().stair_at(Vector2i(15, 17))
	check(down != null and down.way == "down" and down.to_floor == "f2_test" and down.to_at == Vector2i(0, 0) and down.exit == Dir.W, "f1 내려가는 계단")
	check(not d.floor_by_id("f2_test").has_start(), "f2 는 시작 칸 없음")


## T2 (M2a 칸 종류, M2b 내려설 경계, M2c 중복, M2d 내려설 칸이 계단): 계단 형식 오류.
func test_stair_format_errors() -> void:
	var cases := [
		["바닥 칸 아님", _dict("fa", ".~.", [{"at": [1, 0], "way": "down", "exit": "W", "to": {"floor": "fb", "at": [0, 0]}}]), "이 바닥 칸(.)이 아니다"],
		["내려설 칸이 바닥 아님", _dict("fa", "~..", [FA_STAIR.merged({"at": [1, 0]}, true)]), "내려설 칸 0:0 이 바닥 칸(.)이 아니다"],
		["내려설 칸 판 밖", _dict("fa", "...", [FA_STAIR.merged({"exit": "E"}, true)]), "내려설 칸 3:0 이 바닥 칸(.)이 아니다"],
		["내려설 경계 벽", Fx.floor_dict(Fx.row_grid("...", " |"), {"id": "fa", "stairs": [FA_STAIR]}), "사이 경계가 열림·문이 아니다"],
		["내려설 경계 일방통행", Fx.floor_dict(Fx.row_grid("...", " >"), {"id": "fa", "stairs": [FA_STAIR]}), "사이 경계가 열림·문이 아니다"],
		["두 계단 한 칸", _dict("fa", "...", [FA_STAIR, FA_STAIR.merged({"exit": "W"}, true)]), "계단이 이미 있다"],
		["내려설 칸이 계단", _dict("fa", "...", [FA_STAIR, FA_STAIR.merged({"at": [1, 0]}, true)]), "내려설 칸 1:0 이 계단이다"],
		["시작 칸", _dict("fa", "...", [FA_STAIR.merged({"at": [0, 0], "exit": "E"}, true)]), "이 시작 칸이다"],
		["way", _dict("fa", "...", [FA_STAIR.merged({"way": "sideways"}, true)]), "way 는 up·down"],
		["exit", _dict("fa", "...", [FA_STAIR.merged({"exit": "X"}, true)]), "exit 는 N·E·S·W"],
		["to 꼴", _dict("fa", "...", [FA_STAIR.merged({"to": "fb"}, true)]), "to 는"],
		["to.floor ID", _dict("fa", "...", [FA_STAIR.merged({"to": {"floor": "F B", "at": [0, 0]}}, true)]), "to 는"],
		["to.at", _dict("fa", "...", [FA_STAIR.merged({"to": {"floor": "fb", "at": [0]}}, true)]), "to.at"],
		["배열 아님", _dict("fa", "...", []).merged({"stairs": {}}, true), "stairs는 배열"],
	]
	for c in cases:
		_has(_errors(c[1]), c[2], c[0])
	# 문 너머로 내려서는 것은 된다.
	check(Fx.parse(Fx.floor_dict(Fx.row_grid("...", " D"), {"id": "fa", "stairs": [FA_STAIR]})).ok(), "문 너머 내려서기 받음")


## T2 보강: 계단 오류는 stairs 키 줄을 가리킨다(다른 형식 오류와 같은 파일:줄:열).
func test_stair_error_points_at_stairs_key() -> void:
	var text := JSON.stringify(_dict("fa", ".~.", [FA_STAIR.merged({"at": [1, 0]}, true)]), "\t")
	var r := FloorLoader.parse_text(text, "fx.json")
	var line := 0
	var lines := text.split("\n")
	for i in lines.size():
		if lines[i].contains("\"stairs\""):
			line = i + 1
	check(r.errors.size() == 1 and r.errors[0].begins_with("fx.json:%d:" % line), "stairs 키 줄 %d: %s" % [line, str(r.errors)])


## T3 (M3: start 를 늘 빼도 받음): 계단이 있을 때만 start 를 뺄 수 있다.
func test_start_optional_only_with_stairs() -> void:
	check(Fx.parse(_fb()).ok(), "계단 있는 층은 start 없이 받음")
	var d := _dict("fx", "...", [])
	d.erase("start")
	_has(_errors(d), "start는 객체", "빈 계단 목록이면 start 필요")
	d.erase("stairs")
	_has(_errors(d), "start는 객체", "계단 없는 층은 start 필요")


## T4 (M4a 짝 되짚기 없음, M4b 출현 표를 첫 층만 봄): 층 사이 검사.
func test_set_errors() -> void:
	var a := _model(_fa())
	var b := _model(_fb())
	check_eq(FloorLoader.check_set([a, b] as Array[FloorModel]), [] as Array[String], "맞는 짝")
	var cases := [
		["없는 층", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[0].stair_at(Vector2i(2, 0)).to_floor = "fz", "없는 층 fz"],
		["짝 칸에 계단 없음", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[0].stair_at(Vector2i(2, 0)).to_at = Vector2i(2, 0), "에 계단이 없다"],
		["짝이 되가리키지 않음", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[1].stair_at(Vector2i(0, 0)).to_at = Vector2i(1, 0), "이 계단을 가리키지 않는다"],
		["같은 층", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[0].stair_at(Vector2i(2, 0)).to_floor = "fa", "같은 층"],
		["방향 같음", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[1].stair_at(Vector2i(0, 0)).way = "down", "바로 아래층"],
		["첫 층 시작 없음", [_model(_fb()), _model(_fa())], func(_x: Array) -> void: pass, "첫 층에는 start"],
		["아래층에 올라가는 계단 없음", [_model(_fa()), _model(_fb())], func(x: Array) -> void: x[1].stair_at(Vector2i(0, 0)).way = "down", "올라가는 계단(up)"],
		["ID 두 번", [_model(_fa()), _model(_fa())], func(_x: Array) -> void: pass, "두 번"],
	]
	for c in cases:
		var floors: Array[FloorModel] = []
		floors.assign(c[1])
		c[2].call(floors)
		_has(FloorLoader.check_set(floors), c[3], c[0])
	# 한 층 건너뛰기: fa → fc(셋째)로 내려가는 계단.
	var fa := _model(_fa())
	var md := _dict("fm", "...", [{"at": [0, 0], "way": "up", "exit": "E", "to": {"floor": "fa", "at": [2, 0]}}])
	md.erase("start")
	var mid := _model(md)
	var fc := _model(_fb())
	fc.id = "fc"
	fa.stair_at(Vector2i(2, 0)).to_floor = "fc"
	_has(FloorLoader.check_set([fa, mid, fc] as Array[FloorModel]), "바로 아래층으로 이어져야", "층 건너뛰기")


## T4: 층 묶음 파일·GameDefs 의 층마다 검사(출현 표, 화면 문구).
func test_set_file_and_defs_errors() -> void:
	var r := FloorLoader.load_set("res://tests/no_such_labyrinth.json")
	check(not r.ok() and r.floors.is_empty(), "파일 없음")
	var db := Fx.defs().battle
	var party := PartyData.read_path(Fx.PARTY_PATH)
	var a := _model(_fa())
	var b := _model(_fb())
	a.encounter_table = "encounter.f1_test"
	b.encounter_table = "encounter.nope"
	_has(GameDefs.from_parts([a, b] as Array[FloorModel], party, db).errors, "fb: encounter.table: 없는 출현 표 encounter.nope", "둘째 층 출현 표")
	b.encounter_table = "encounter.f2_test"
	b.name_key = "floor.nope"
	party = PartyData.read_path(Fx.PARTY_PATH)
	_has(GameDefs.from_parts([a, b] as Array[FloorModel], party, db, TextDb.load_path("res://data/text/ko.json")).errors, "ko.json: floor.nope", "층 이름 문구")
	b.name_key = "floor.f2_test"
	b.stair_at(Vector2i(0, 0)).to_at = Vector2i(1, 0)
	party = PartyData.read_path(Fx.PARTY_PATH)
	_has(GameDefs.from_parts([a, b] as Array[FloorModel], party, db).errors, "가리키지 않는다", "GameDefs 도 층 사이 검사")


## T5 (M5a 들어오는 곳 = 시작 칸만): 시작 없는 층은 계단 칸에서 닿는 칸이 모두 닿은 것.
func test_analysis_entries_are_stairs() -> void:
	check_eq(FloorLoader.analyze(_model(_fb()), "fb.json"), [] as Array[String], "시작 없는 층 경고 0")
	check_eq(FloorLoader.entries(_model(_fb())), [Vector2i(0, 0)] as Array[Vector2i], "들어오는 곳 = 계단 칸")
	check_eq(FloorLoader.can_return(_model(_fb()), Vector2i(2, 0), WorldState.new()), FloorLoader.Reach.YES, "올라가는 계단으로 나갈 수 있음")


## T5 (M5b 모든 계단을 나가는 곳으로 봄): 내려가는 계단만 닿는 곳은 갇힘이다.
func test_analysis_down_stairs_only_region_is_trapped() -> void:
	# fm: (0,0) 올라가는 계단, (1,0) 에서 일방통행 > 로 (2,0)…(3,0) 에 들어가면 (3,0) 내려가는 계단만 있다.
	var d := Fx.floor_dict(Fx.row_grid("....", " > "), {"id": "fm", "stairs": [
		{"at": [0, 0], "way": "up", "exit": "E", "to": {"floor": "fa", "at": [2, 0]}},
		{"at": [3, 0], "way": "down", "exit": "W", "to": {"floor": "fb", "at": [0, 0]}}]})
	d.erase("start")
	var f := _model(d)
	var w := FloorLoader.analyze(f, "fm.json")
	check(w.any(func(s: String) -> bool: return s.contains("칸 2:0") and s.contains("갇힘") and s.contains("올라가는 계단")), "내려가는 계단 쪽 2:0 갇힘 %s" % str(w))
	check(w.any(func(s: String) -> bool: return s.contains("칸 3:0") and s.contains("갇힘")), "내려가는 계단 칸 3:0 도 갇힘 %s" % str(w))
	check(not w.any(func(s: String) -> bool: return s.contains("칸 1:0")), "1:0 은 경고 없음 %s" % str(w))
	check_eq(FloorLoader.can_return(f, Vector2i(3, 0), WorldState.new()), FloorLoader.Reach.NO, "3:0 에서 못 나감")


# ---- 규칙 (R1~R9) ----

func _types(events: Array[Dictionary]) -> Array[String]:
	return Fx.types(events)


## fa 에서 (1,0) 동쪽을 보고 선 상태(위험도 한계 큼).
func _at_fa(defs: GameDefs, automap: String = "floor") -> ExplorationState:
	var s := ExplorationRules.new_game(defs, 5, automap)
	s.party.at = Vector2i(1, 0)
	s.party.facing = Dir.E
	return s


## R1 (M6: 인카운트 판정보다 먼저 냄): 계단 칸으로 걸어 들어가면 마지막에 stairs, 걸음 +1, 위험도 더함.
func test_move_onto_stairs_emits_event_last() -> void:
	var s := _at_fa(_pair_defs())
	var steps := s.steps
	var danger := s.encounter.danger
	var ev := ExplorationRules.apply(s, A.FORWARD, "floor")
	check_eq(_types(ev), ["moved", "stairs"] as Array[String], "이벤트 차례")
	check_eq([ev[-1]["way"], ev[-1]["to"]], ["down", "fb"], "계단 필드")
	check_eq([s.steps, s.encounter.danger, s.floor_def.id], [steps + 1, danger + 10, "fa"], "걸음·위험도는 보통 이동, 층은 그대로")
	# 후진·평행 이동으로 들어가도 같다.
	s.party.at = Vector2i(1, 0)
	s.party.facing = Dir.W
	check_eq(_types(ExplorationRules.apply(s, A.BACK, "floor")), ["moved", "stairs"] as Array[String], "후진으로 밟기")


## R2 (M7: 늘 냄): 그 걸음에 전투가 나면 stairs 이벤트가 없다(전투 뒤에는 계단 위 조사로 다시 묻는다).
## 계단 칸은 바닥(.)이라 그 걸음에 피해 바닥 전멸은 일어나지 않는다(형식 검사).
func test_no_stairs_event_with_encounter() -> void:
	var s := _at_fa(_pair_defs())
	s.encounter.danger = s.encounter.threshold - 1
	var ev := ExplorationRules.apply(s, A.FORWARD, "floor")
	check(_types(ev).has("encounter") and not _types(ev).has("stairs"), "인카운트면 없음 %s" % str(_types(ev)))
	check_eq(s.party.at, Vector2i(2, 0), "계단 칸에 섰다")
	BattleRules.finish(s, "victory")
	check_eq(_types(ExplorationRules.apply(s, A.INVESTIGATE, "floor")), ["stairs"] as Array[String], "전투 뒤 조사로 다시 묻는다")


## R3: 미끄러져 계단 칸에서 멈춰도 stairs.
func test_slide_ending_on_stairs() -> void:
	var defs := _pair_defs({"size": [5, 1], "grid": Fx.row_grid("..=..", "    "), "stairs": [FA_STAIR.merged({"at": [3, 0], "exit": "E"}, true)]},
		{"stairs": [FB_STAIR.merged({"to": {"floor": "fa", "at": [3, 0]}}, true)]})
	var s := ExplorationRules.new_game(defs, 5, "floor")
	s.party.facing = Dir.E
	s.party.at = Vector2i(1, 0)
	var ev := ExplorationRules.apply(s, A.FORWARD, "floor")
	check_eq(_types(ev), ["moved", "moved", "stairs"] as Array[String], "미끄러져 계단에서 멈춤")
	check_eq(s.party.at, Vector2i(3, 0), "계단 칸")


## R4 (M8: 계단 위 조사가 nothing_found): 계단 위 조사는 다시 묻는다. 바라보는 숨은 통로가 먼저다.
func test_investigate_on_stairs() -> void:
	var s := _at_fa(_pair_defs())
	s.party.at = Vector2i(2, 0)
	check_eq(_types(ExplorationRules.apply(s, A.INVESTIGATE, "floor")), ["stairs"] as Array[String], "계단 위 조사")
	s.party.at = Vector2i(1, 0)
	check_eq(_types(ExplorationRules.apply(s, A.INVESTIGATE, "floor")), ["nothing_found"] as Array[String], "계단 밖 조사")
	var p := _pair_defs({"grid": Fx.row_grid("...", " H"), "stairs": [FA_STAIR.merged({"at": [1, 0], "exit": "W"}, true)]},
		{"stairs": [FB_STAIR.merged({"to": {"floor": "fa", "at": [1, 0]}}, true)]})
	var t := ExplorationRules.new_game(p, 5, "floor")
	t.party.at = Vector2i(1, 0)
	t.party.facing = Dir.E
	check_eq(_types(ExplorationRules.apply(t, A.INVESTIGATE, "floor")), ["passage_found"] as Array[String], "바라보는 숨은 통로 먼저")
	check_eq(_types(ExplorationRules.apply(t, A.INVESTIGATE, "floor")), ["stairs"] as Array[String], "찾은 뒤에는 계단")


## R5: 계단 밖 STAIRS 는 막힘(상태 그대로), 전투 대기·전멸이면 거부.
func test_stairs_action_off_stairs_and_rejected() -> void:
	var s := _at_fa(_pair_defs())
	var before := SaveCodec.state_hash(s)
	check_eq(ExplorationRules.apply(s, A.STAIRS, "floor"), [{"type": "blocked", "reason": "not_stairs"}] as Array[Dictionary], "막힘 not_stairs")
	check_eq(SaveCodec.state_hash(s), before, "상태 그대로")
	check_eq(ExplorationRules.action_from_name("stairs"), A.STAIRS, "행동 이름")
	s.party.at = Vector2i(2, 0)
	s.wiped = true
	check_eq(_types(ExplorationRules.apply(s, A.STAIRS, "floor")), ["rejected"] as Array[String], "전멸 거부")
	s.wiped = false
	s.encounter.pending = true
	check_eq(_types(ExplorationRules.apply(s, A.STAIRS, "floor")), ["rejected"] as Array[String], "전투 대기 거부")


## R6 (M9a 걸음 +1, M9b 방향 반대, M9c 계단 칸 기록 없음): 층 바꾸기는 짝 계단 칸에 서서 그 exit 를 본다.
func test_take_stairs_moves_to_paired_stair() -> void:
	for automap in ["floor", "full", "off"]:
		var s := _at_fa(_pair_defs(), automap)
		s.party.at = Vector2i(2, 0)
		s.encounter.danger = 30
		var keep := [s.steps, s.encounter.danger, s.encounter.threshold, s.rng.get_state()]
		var ev := ExplorationRules.apply(s, A.STAIRS, automap)
		check_eq(ev, [{"type": "floor_changed", "from": "fa", "to": "fb", "at": Vector2i(0, 0), "facing": Dir.E}] as Array[Dictionary], automap + ": 이벤트")
		check_eq([s.floor_def.id, s.party.at, s.party.facing], ["fb", Vector2i(0, 0), Dir.E], automap + ": 층·칸·방향")
		check_eq([s.steps, s.encounter.danger, s.encounter.threshold, s.rng.get_state()], keep, automap + ": 걸음·위험도·한계값·난수 그대로")
		check(s.knowledge.is_visited(Vector2i(0, 0)) and s.knowledge.look_of(Vector3i(1, 0, 1)) == "open", automap + ": 계단 칸 방문·관찰")
		check_eq(s.annotation.floors.has(Vector2i(0, 0)), automap != "off", automap + ": 자동 바닥 색")
		check(s.annotation.icons.is_empty(), automap + ": 계단 아이콘은 자동으로 쓰지 않는다(원작: 플레이어가 놓는 아이콘)")
		check(ExplorationRules.can_act(s), automap + ": 도착 뒤 행동 가능")
		# 도착만으로는 묻지 않는다: 내려섰다 다시 밟으면 묻는다.
		check_eq(_types(ExplorationRules.apply(s, A.FORWARD, automap)), ["moved"] as Array[String], automap + ": 내려서기")
		check_eq(_types(ExplorationRules.apply(s, A.BACK, automap)), ["moved", "stairs"] as Array[String], automap + ": 다시 밟으면 계단")
		check_eq(ExplorationRules.apply(s, A.STAIRS, automap)[0]["to"], "fa", automap + ": 올라가기")
		check_eq([s.floor_def.id, s.party.at, s.party.facing], ["fa", Vector2i(2, 0), Dir.W], automap + ": 위층 계단 칸, 서쪽")


## R7 (M10a 세계 상태 하나를 같이 씀, M10b 들어갈 때마다 새 기록, M10c 지도 그림을 바꾸지 않음): 층마다 기록이 따로다.
func test_per_floor_records_are_isolated() -> void:
	var s := ExplorationRules.new_game(Fx.defs(), 11, "full")
	s.encounter.threshold = 99999
	s.party.at = Vector2i(14, 17)
	s.party.facing = Dir.E
	check_eq(_types(ExplorationRules.apply(s, A.FORWARD, "full")), ["moved", "stairs"] as Array[String], "f1 계단 밟기")
	var f1_before := JSON.stringify(SaveCodec.floor_state_to_dict(s.floor_states["f1_test"]), "", true)
	var f1_world := s.world
	var f1_ann := s.annotation
	ExplorationRules.apply(s, A.STAIRS, "full")
	check(s.world != f1_world and s.annotation != f1_ann, "f2 는 다른 기록 객체")
	check_eq(s.floor_states.keys(), ["f1_test", "f2_test"], "들어가 본 층 둘")
	Fx.walk(s, "EEEE", "full")  # (4,0)
	s.party.facing = Dir.S
	check_eq(_types(ExplorationRules.apply(s, A.INVESTIGATE, "full")), ["passage_found"] as Array[String], "f2 숨은 통로 h:4:1")
	Fx.walk(s, "S", "full")  # (4,1)
	s.party.facing = Dir.W
	check_eq(_types(ExplorationRules.apply(s, A.FORWARD, "full")), ["shortcut_opened"] as Array[String], "f2 지름길 v:4:1")
	s.annotation.begin_stroke()
	s.annotation.paint_floor(Vector2i(3, 1), 2)
	s.annotation.end_stroke()
	s.annotation.begin_stroke()
	s.annotation.set_memo(Vector2i(4, 1), "f2")
	s.annotation.end_stroke()
	Fx.walk(s, "WWNWW", "full")  # 지름길로 (3,1)·(2,1)·(2,0)·(1,0)·(0,0) 계단
	check_eq(s.party.at, Vector2i(0, 0), "f2 계단으로 돌아옴")
	ExplorationRules.apply(s, A.STAIRS, "full")
	check_eq(s.floor_def.id, "f1_test", "f1 로 올라옴")
	check(s.world == f1_world and s.annotation == f1_ann, "f1 기록 객체 그대로")
	check_eq(JSON.stringify(SaveCodec.floor_state_to_dict(s.floor_states["f1_test"]), "", true), f1_before, "f1 기록이 f2 일로 바뀌지 않았다")
	check(not s.world.is_passage_found(Vector3i(4, 1, 0)) and not s.world.is_shortcut_open(Vector3i(4, 1, 1)), "f1 세계 상태에 f2 경계 없음")
	check(not s.annotation.can_undo(), "f1 지도 실행 취소 기록 없음")
	check(not s.annotation.undo(), "f1 에서 되돌려도 f2 그림을 건드리지 않는다")
	s.party.at = Vector2i(15, 17)
	ExplorationRules.apply(s, A.STAIRS, "full")
	var f2 := s.floor_states["f2_test"] as FloorState
	check(f2.world.is_passage_found(Vector3i(4, 1, 0)) and f2.world.is_shortcut_open(Vector3i(4, 1, 1)), "f2 세계 상태 남음")
	check_eq([f2.annotation.floors.get(Vector2i(3, 1)), f2.annotation.memos.get(Vector2i(4, 1)), f2.annotation.undo_depth()], [2, "f2", 2], "f2 지도 그림·실행 취소 기록 남음")
	check(f2.knowledge.is_visited(Vector2i(4, 1)), "f2 방문 기록 남음")


## R8 (M11: 첫 층 출현 표·한계값): 지금 층의 출현 표에서 뽑고, 전투 뒤 한계값은 지금 층 범위다.
func test_encounter_uses_current_floor_table_and_range() -> void:
	var defs := _pair_defs({}, {"encounter": {"danger_per_step": 10, "threshold_min": 5, "threshold_max": 5}})
	var s := _at_fa(defs)
	s.party.at = Vector2i(2, 0)
	ExplorationRules.apply(s, A.STAIRS, "floor")
	check_eq(s.floor_def.id, "fb", "준비: fb")
	s.encounter.danger = s.encounter.threshold - 1
	var ev := ExplorationRules.apply(s, A.FORWARD, "floor")
	check(_types(ev).has("encounter"), "준비: 전투")
	check(defs.battle.table_formations("encounter.f2_test").has(s.battle.formation), "fb 출현 표의 편성 %s" % s.battle.formation)
	BattleRules.finish(s, "victory")
	check_eq(s.encounter.threshold, 5, "fb 한계값 범위(5~5)로 다시 뽑음(fa 는 1000)")


## R9: 휴식은 그 층 시작 칸에서만(시작 없는 층은 없음). 새 게임은 첫 층 기록 하나.
func test_rest_and_new_game_floor() -> void:
	var s := _at_fa(_pair_defs())
	check_eq(s.floor_states.keys(), ["fa"], "새 게임은 첫 층 기록 하나")
	s.party.at = Vector2i(2, 0)
	ExplorationRules.apply(s, A.STAIRS, "floor")
	check_eq(ExplorationRules.apply(s, A.REST, "floor"), [{"type": "blocked", "reason": "not_rest_point"}] as Array[Dictionary], "시작 없는 층은 쉴 수 없다")
