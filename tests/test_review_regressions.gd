## 독립 검토(Astra) 반례를 고정하는 회귀 시험.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

var _floor: FloorModel


func _f() -> FloorModel:
	if _floor == null:
		# 동쪽 끝에 숨은 통로 v:4:0 과 지름길 v:5:0((4,0) 쪽에서 열림). 걸음 1~3 은 서로 다른 상태다.
		_floor = Fx.floor_of(Fx.row_grid("......", "   HL"), {"id": "fx_review", "shortcuts": [{"at": [4, 0], "dir": "E"}]})
	return _floor


func _store() -> SaveStore:
	return SaveStore.new(_f(), Fx.members(), Fx.SAVE_DIR)


func _state(steps: int) -> ExplorationState:
	var s := Fx.game(_f(), 7, "full")
	for i in steps:
		ExplorationRules.apply(s, A.FORWARD, "full")
	return s


func _doc(s: ExplorationState) -> Dictionary:
	return JSON.parse_string(SaveCodec.encode(s))


func _decode(doc: Dictionary) -> SaveCodec.LoadResult:
	return SaveCodec.decode(JSON.stringify(doc), _f(), Fx.members())


# ---- 1. .tmp 하나만 남은 정상 후보 ----

func test_tmp_only_candidate_survives_failed_save() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _state(1)
	store.stop_after_step = 1
	store.save("auto", a)
	store.stop_after_step = 0
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "tmp", "준비: .tmp 에서만 A 를 읽음")
	var hash_a := SaveCodec.state_hash(a)
	check(not store.save("auto", l.result.state, "invalid").is_empty(), "시각 검사 실패로 저장 실패")
	l = store.load_slot("auto")
	check(l.ok(), "정상 후보 A 가 남아 있음 (%s)" % l.result.error)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == hash_a, "남은 후보는 A")
	Fx.clean_saves()


# ---- 2. 32비트를 넘는 좌표 ----

func test_large_coordinates_rejected_in_save() -> void:
	var s := _state(2)
	var doc := _doc(s)
	doc["state"]["party"]["at"] = [4294967298, 0]
	check(not _decode(doc).ok(), "party.at 4294967298 거부")
	doc = _doc(s)
	doc["state"]["party"]["at"] = [2, 4294967296]
	check(not _decode(doc).ok(), "party.at y 4294967296 거부")


func test_large_coordinates_rejected_in_floor() -> void:
	var g := Fx.row_grid(".....", "    ")
	var cases := {
		"start": {"start": {"at": [4294967296, 0], "facing": "E"}},
		"zones": {"zones": [{"id": "z", "rect": [4294967296, 0, 4294967297, 0], "danger_per_step": 0}]},
		"shortcuts": {"shortcuts": [{"at": [4294967297, 0], "dir": "E"}]},
	}
	var lgrid := Fx.row_grid(".....", " L  ")
	for key in cases:
		var r := Fx.parse(Fx.floor_dict(lgrid if key == "shortcuts" else g, cases[key]))
		check(not r.ok(), "%s 의 큰 좌표 거부" % key)


# ---- 3. saved_at 형식 ----

func test_saved_at_must_be_real_utc_time() -> void:
	var s := _state(1)
	for bad in ["ZZZ", "2026-99-99T99:99:99Z", "2026-02-30T00:00:00Z", "2025-02-29T00:00:00Z", "2026-10-16T24:00:00Z", "2026-10-16T12:00:00.5Z", "2026-10-16T12:00:00+09:00", "2026-1-16T12:00:00Z"]:
		var doc := _doc(s)
		doc["saved_at"] = bad
		check(not _decode(doc).ok(), "saved_at 거부: %s" % bad)
	for good in ["2024-02-29T23:59:59Z", "2026-10-16T00:00:00Z"]:
		var doc := _doc(s)
		doc["saved_at"] = good
		check(_decode(doc).ok(), "saved_at 허용: %s" % good)


func test_latest_manual_ignores_bad_saved_at() -> void:
	Fx.clean_saves()
	var store := _store()
	store.save("slot1", _state(1), "2026-10-16T01:00:00Z")
	var doc := _doc(_state(2))
	doc["saved_at"] = "ZZZ"
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(store.main_path("slot2"), FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	check_eq(store.latest_manual(), "slot1", "형식이 틀린 saved_at 슬롯은 고르지 않음")
	Fx.clean_saves()


# ---- 4. 위험도와 전투 대기 ----

func test_pending_must_match_danger() -> void:
	var s := _state(1)
	var doc := _doc(s)
	doc["state"]["encounter"] = {"danger": 0, "threshold": 120, "pending": true}
	check(not _decode(doc).ok(), "danger < threshold 인데 대기 거부")
	doc["state"]["encounter"] = {"danger": 120, "threshold": 120, "pending": false}
	check(not _decode(doc).ok(), "danger ≥ threshold 인데 대기 아님 거부")
	doc["state"]["encounter"] = {"danger": 120, "threshold": 120, "pending": true}
	check(_decode(doc).ok(), "danger ≥ threshold 이고 대기 허용")


func test_wiped_state_keeps_pending_invariant() -> void:
	var f := Fx.floor_of(Fx.row_grid(".~.", "  "), {"id": "fx_review", "encounter": {"danger_per_step": 50, "threshold_min": 10, "threshold_max": 10}})
	var s := Fx.game(f, 3)
	for m in s.party.members:
		m.hp = 1
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check(s.wiped and not s.encounter.pending and s.encounter.danger < s.encounter.threshold, "전멸한 걸음은 위험도를 더하지 않음")
	var r := SaveCodec.decode(SaveCodec.encode(s), f, Fx.members())
	check(r.ok(), "전멸 상태 저장·읽기 (%s)" % r.error)


# ---- 5. 갇힘 분석: (칸, 세계 상태) ----

## 반례 1: (1,0) 은 갇힘이 아니고 (3,0) 만 갇힘.
func test_trap_analysis_no_false_positive() -> void:
	var g := [
		"+-+-+-+-+",
		"|.H=>.>.|",
		"+ +-+ +-+",
		"|. . .|#|",
		"+-+-+-+-+",
	]
	var r := Fx.parse(Fx.floor_dict(g))
	check(r.ok(), "오류 없음 %s" % str(r.errors))
	var w := FloorLoader.analyze(r.floor_def, "fx.json")
	var trapped := w.filter(func(s: String) -> bool: return s.contains("갇힘"))
	check(trapped.size() > 0 and trapped.all(func(s: String) -> bool: return s.contains("칸 3:0")), "갇힘은 3:0 뿐 %s" % str(w))
	check(not w.any(func(s: String) -> bool: return s.contains("칸 1:0")), "1:0 은 경고 없음 %s" % str(w))


## 반례 2: 통로를 찾은 뒤의 (2,0) 은 갇힘.
func test_trap_analysis_finds_state_dependent_trap() -> void:
	var g := [
		"+-+-+-+",
		"|.H= .|",
		"+-+v+^+",
		"|#|. .|",
		"+-+-+-+",
	]
	var r := Fx.parse(Fx.floor_dict(g, {"start": {"at": [1, 1], "facing": "E"}}))
	check(r.ok(), "오류 없음 %s" % str(r.errors))
	var w := FloorLoader.analyze(r.floor_def, "fx.json")
	check(w.any(func(s: String) -> bool: return s.contains("칸 2:0") and s.contains("갇힘") and s.contains("v:1:0")), "통로를 찾은 상태의 2:0 갇힘 %s" % str(w))
	# 실제 규칙으로 걸어서 확인: E N W, 조사, S E N 뒤 (2,0) 에서 시작으로 돌아갈 수 없다.
	var s := Fx.game(r.floor_def, 1)
	Fx.walk(s, "ENW")
	ExplorationRules.apply(s, A.INVESTIGATE, "floor")
	Fx.walk(s, "SEN")
	check_eq(s.party.at, Vector2i(2, 0), "반례 경로")
	check_eq(FloorLoader.can_return(r.floor_def, s.party.at, s.world), FloorLoader.Reach.NO, "그 상태에서는 시작 칸으로 못 돌아감")
	check_eq(FloorLoader.can_return(r.floor_def, s.party.at, WorldState.new()), FloorLoader.Reach.YES, "통로를 찾기 전 상태라면 돌아갈 수 있음")


func test_trap_analysis_state_limit() -> void:
	# 숨은 통로 13개: 세계 상태가 4096 을 넘으면 분석하지 않고 알린다.
	var cells := ".".repeat(14)
	var r := Fx.parse(Fx.floor_dict(Fx.row_grid(cells, "H".repeat(13))))
	check(r.ok(), "오류 없음")
	var w := FloorLoader.analyze(r.floor_def, "fx.json")
	check(w.size() == 1 and w[0].contains("4096"), "상태 수 한도 경고 %s" % str(w))


# ---- 6. 자동 경계 표시 끄기 ----

func test_toggle_turns_off_auto_mark() -> void:
	var m := MapAnnotation.new(4, 4)
	var e := Vector3i(1, 1, 0)
	m.auto_edge(e, "wall")
	m.toggle_edge(e, "wall")
	check(not m.edges.has(e) and not m.auto_edges.has(e), "자동 벽도 한 번에 꺼짐")
	m.undo()
	check(m.edges.get(e) == "wall" and m.auto_edges.has(e), "실행 취소는 자동 벽으로 되돌림")


# ---- 7. 격자 줄 이스케이프·문자열 아닌 줄 ----

func test_grid_error_position_with_escape_and_non_string_row() -> void:
	var d := Fx.floor_dict(Fx.row_grid("...", "  "))
	d["grid"][1] = "|. x .|"
	var text := JSON.stringify(d, "\t").replace("\"|. x .|\"", "\"|\\u002e x .|\"")
	var errs := FloorLoader.parse_text(text, "fx.json").errors
	var lines := text.split("\n")
	var want_line := -1
	for i in lines.size():
		if lines[i].contains("\\u002e"):
			want_line = i + 1
	var row_col: int = lines[want_line - 1].find("\"|") + 2
	check(errs.size() >= 1 and errs[0].begins_with("fx.json:%d:%d: " % [want_line, row_col]), "이스케이프가 있으면 줄 시작 위치 %s (기대 %d:%d)" % [str(errs), want_line, row_col])
	var d2 := Fx.floor_dict(Fx.row_grid("...", "  "))
	d2["grid"][0] = 5
	d2["grid"][1] = "|. x .|"
	var text2 := JSON.stringify(d2, "\t")
	var errs2 := FloorLoader.parse_text(text2, "fx.json").errors
	var lines2 := text2.split("\n")
	var line_x := -1
	for i in lines2.size():
		if lines2[i].contains("|. x .|"):
			line_x = i + 1
	var col_x: int = lines2[line_x - 1].find("|. x .|") + 1 + 3
	check(errs2.any(func(e: String) -> bool: return e.begins_with("fx.json:%d:%d: " % [line_x, col_x])), "문자열 아닌 줄 뒤의 위치 %s (기대 %d:%d)" % [str(errs2), line_x, col_x])


## 슬롯을 준비한다: "main" 은 정상 본 파일 A, "tmp_only" 는 ①만 끝난 .tmp A.
func _prepare(store: SaveStore, start: String, a: ExplorationState) -> void:
	if start == "main":
		store.save("auto", a)
	else:
		store.stop_after_step = 1
		store.save("auto", a)
		store.stop_after_step = 0


## 단계 안에서 실패해도(①쓰기 ②검사 ③옮기기·.bak 지운 뒤 ④이름 바꾸기, 쓰기 전 정리) 정상 후보를 잃지 않는다.
func test_in_step_failures_keep_a_good_candidate() -> void:
	var points := ["write", "check", "move_main", "after_bak_removed", "rename_tmp"]
	for point in points:
		for start in ["main", "tmp_only"]:
			var label := "%s/%s" % [start, point]
			Fx.clean_saves()
			var store := _store()
			var a := _state(1)
			_prepare(store, start, a)
			var hash_a := SaveCodec.state_hash(a)
			var b := _state(3)
			var gen := b.generation
			if point == "check":
				check(not store.save("auto", b, "invalid").is_empty(), "%s: 검사 실패" % label)
			else:
				store.fail_points = [point]
				check(not store.save("auto", b).is_empty(), "%s: 단계 안 실패" % label)
				store.fail_points = []
			check_eq(b.generation, gen, "%s: 실패하면 generation 그대로" % label)
			var l := store.load_slot("auto")
			check(l.ok(), "%s: 정상 후보가 남음 (%s)" % [label, l.result.error])
			if l.ok():
				var h := SaveCodec.state_hash(l.result.state)
				check(h == hash_a or (point == "rename_tmp" and h == SaveCodec.state_hash(b)), "%s: 남은 후보는 A(④ 실패면 검사를 통과한 B 도 됨)" % label)
			check_eq(store.save("auto", b), "", "%s: 다음 저장은 성공" % label)
			l = store.load_slot("auto")
			check(l.ok() and l.source_kind == "main" and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(b), "%s: 다음 저장 뒤 본 파일 B" % label)
	Fx.clean_saves()


func _write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## 쓰기 전 정리의 지우기·올리기가 실패해도 정상 후보를 잃지 않고, 다음 저장은 된다.
func test_settle_failures_keep_a_good_candidate() -> void:
	var tmp_path := Fx.SAVE_DIR + "/auto.tmp"
	for point in ["settle_remove_tmp", "settle_remove_main", "settle_promote"]:
		Fx.clean_saves()
		var store := _store()
		var a := _state(1)
		match point:
			"settle_remove_tmp":
				store.save("auto", a)  # 정상 본 파일 + 깨진 .tmp
				_write_raw(tmp_path, "{bad")
			"settle_remove_main":
				_prepare(store, "tmp_only", a)  # 정상 .tmp + 깨진 본 파일
				_write_raw(store.main_path("auto"), "broken")
			_:
				_prepare(store, "tmp_only", a)  # 정상 .tmp 만
		var b := _state(3)
		store.fail_points = [point]
		check(not store.save("auto", b).is_empty(), "%s: 실패를 돌려줌" % point)
		store.fail_points = []
		check_eq(b.generation, 0, "%s: generation 그대로" % point)
		var l := store.load_slot("auto")
		check(l.ok() and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(a), "%s: 정상 후보 A 가 남음" % point)
		check_eq(store.save("auto", b), "", "%s: 다음 저장은 성공" % point)
		check(store.load_slot("auto").source_kind == "main", "%s: 다음 저장 뒤 본 파일" % point)
	Fx.clean_saves()


func test_settle_promotes_tmp_over_broken_main_and_drops_bad_tmp() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _state(1)
	_prepare(store, "tmp_only", a)
	_write_raw(store.main_path("auto"), "broken")
	store.fail_points = ["write"]
	store.save("auto", _state(2))
	store.fail_points = []
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(a), "깨진 본 파일 대신 정상 .tmp 를 본 파일로 올림")
	_write_raw(Fx.SAVE_DIR + "/auto.tmp", "{bad")
	store.stop_after_step = 2
	store.save("auto", _state(2))
	store.stop_after_step = 0
	check(FileAccess.file_exists(Fx.SAVE_DIR + "/auto.tmp") and store.load_slot("auto").source_kind == "main", "깨진 .tmp 는 지우고 새 .tmp 를 씀, 본 파일이 먼저")
	Fx.clean_saves()


## 본 파일과 .tmp 가 둘 다 정상이면 본 파일이 먼저 읽히고, 다음 쓰기가 .tmp 를 덮는다.
func test_main_and_tmp_both_valid() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _state(1)
	store.save("auto", a)
	store.stop_after_step = 2
	store.save("auto", _state(2))  # 검사를 통과한 .tmp 를 남기고 멈춤
	store.stop_after_step = 0
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(a), "본 파일 A 가 먼저")
	var c := _state(3)
	check_eq(store.save("auto", c), "", "다음 저장")
	check(not FileAccess.file_exists(Fx.SAVE_DIR + "/auto.tmp"), "남았던 .tmp 는 덮어써져 본 파일이 됨")
	var bak := SaveCodec.decode(FileAccess.get_file_as_string(Fx.SAVE_DIR + "/auto.bak"), _f(), Fx.members())
	check(bak.ok() and SaveCodec.state_hash(bak.state) == SaveCodec.state_hash(a), ".bak 은 이전 본 파일 A")
	l = store.load_slot("auto")
	check(l.ok() and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(c), "본 파일 C")
	Fx.clean_saves()


## 복구·정리 뒤 generation 의 정확한 값.
func test_generation_after_recovery() -> void:
	Fx.clean_saves()
	var store := _store()
	var a := _state(1)
	_prepare(store, "tmp_only", a)
	check_eq(a.generation, 0, "중단된 쓰기는 상태의 generation 을 올리지 않음")
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "tmp" and l.result.generation == 1, ".tmp 문서의 generation 1")
	if not l.ok():
		return
	check_eq(store.save("auto", l.result.state), "", "복구한 상태 저장")
	check_eq(l.result.state.generation, 2, "읽은 1 에 이어 2")
	check_eq(store.slot_info("auto").generation, 2, "본 파일 generation 2")
	var bak := SaveCodec.decode(FileAccess.get_file_as_string(Fx.SAVE_DIR + "/auto.bak"), _f(), Fx.members())
	check(bak.ok() and bak.generation == 1, "정리 단계가 올린 .tmp(1)가 .bak 으로")
	Fx.clean_saves()


# ---- 8. 문서 트리를 돌며 필드 지우기·자료형 바꾸기 ----

## 고정 필드가 있는 사전(지우면 거부되어야 하는 것)의 경로.
const RECORDS := [
	[], ["state"], ["state", "party"], ["state", "party", "members", 0], ["state", "world"], ["state", "knowledge"],
	["state", "annotation"], ["state", "annotation", "icons", "1:0"], ["state", "encounter"], ["state", "rng"],
]


## 찾은 통로·연 지름길·아이콘·메모가 모두 있는 상태(빈 배열이라 원소 경로가 빠지지 않게).
func _rich_state() -> ExplorationState:
	var s := _state(3)
	ExplorationRules.apply(s, A.INVESTIGATE, "full")  # v:4:0
	for i in 3:
		ExplorationRules.apply(s, A.FORWARD, "full")  # (4,0) → 지름길 v:5:0 열기 → (5,0)
	s.annotation.set_icon(Vector2i(1, 0), "arrow", Dir.E)
	s.annotation.set_memo(Vector2i(2, 0), "메모")
	return s


func _at(doc: Variant, path: Array) -> Variant:
	var node: Variant = doc
	for k in path:
		node = node[k]
	return node


## 잎까지 모든 경로(사전 키·배열 번호).
func _paths(node: Variant, prefix: Array, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k in node:
			out.append(prefix + [k])
			_paths(node[k], prefix + [k], out)
	elif typeof(node) == TYPE_ARRAY:
		for i in node.size():
			out.append(prefix + [i])
			_paths(node[i], prefix + [i], out)


## 실패한 decode 가 지금 상태(같은 원문에서 읽은 것)와 원문을 건드리지 않았는지.
func _check_rejected(original: String, doc: Dictionary, label: String) -> void:
	var current := SaveCodec.decode(original, _f(), Fx.members()).state
	var before := SaveCodec.state_hash(current)
	var r := SaveCodec.decode(JSON.stringify(doc), _f(), Fx.members())
	check(not r.ok() and r.state == null and not r.error.is_empty(), "%s: 거부되어야 한다" % label)
	check_eq(SaveCodec.state_hash(current), before, "%s: 지금 상태 불변" % label)
	check_eq(SaveCodec.state_hash(SaveCodec.decode(original, _f(), Fx.members()).state), before, "%s: 원문 그대로" % label)


func test_every_required_field_is_required() -> void:
	var original := SaveCodec.encode(_rich_state())
	var n := 0
	for rec in RECORDS:
		var node: Dictionary = _at(JSON.parse_string(original), rec)
		for key in node:
			var doc: Dictionary = JSON.parse_string(original)
			(_at(doc, rec) as Dictionary).erase(key)
			_check_rejected(original, doc, "필드 %s 지움" % str(rec + [key]))
			n += 1
	check(n >= 30, "고정 필드 %d개 확인" % n)


func test_every_node_rejects_wrong_container_type() -> void:
	var original := SaveCodec.encode(_rich_state())
	var paths := []
	_paths(JSON.parse_string(original), [], paths)
	var joined := ",".join(paths.map(func(p: Array) -> String: return "/".join(p.map(func(k: Variant) -> String: return str(k)))))
	check(joined.contains("state/world/shortcuts_open/0") and joined.contains("state/world/passages_found/0") and joined.contains("state/annotation/memos/2:0"), "통로·지름길·메모 원소 경로가 있음")
	var n := 0
	for path in paths:
		var kind := typeof(_at(JSON.parse_string(original), path))
		for wrong in [[], {}, "x", 7, true, null]:
			if _kind(typeof(wrong)) == _kind(kind):
				continue
			var doc: Dictionary = JSON.parse_string(original)
			_at(doc, path.slice(0, -1))[path[-1]] = wrong
			_check_rejected(original, doc, "%s → %s" % [str(path), str(wrong)])
			n += 1
	check(n >= 150, "자료형 바꾸기 %d가지 확인" % n)


## JSON 숫자는 실수로 읽히므로 정수·실수를 같은 종류로 본다.
func _kind(t: int) -> int:
	return TYPE_FLOAT if t == TYPE_INT else t


# ---- 2차 검토 ----

## B. 미끄러져 지나가기만 하는 칸은 갇힘 경고를 내지 않고 닿은 것으로 센다.
## 05 문서 §3(67행) 정책: 멈춘 칸만 경고하고, 미끄러져 지나가기만 하는 칸은 따로 경고하지 않는다.
func test_slide_through_cell_is_reached_not_trapped() -> void:
	var r := Fx.parse(Fx.floor_dict(["+-+-+-+-+", "|.>= = .|", "+-+-+-+-+"]))
	check(r.ok(), "오류 없음 %s" % str(r.errors))
	var w := FloorLoader.analyze(r.floor_def, "fx.json")
	var trapped := w.filter(func(s: String) -> bool: return s.contains("갇힘"))
	check(trapped.any(func(s: String) -> bool: return s.contains("칸 1:0")) and trapped.any(func(s: String) -> bool: return s.contains("칸 3:0")), "1:0·3:0 갇힘 %s" % str(w))
	check(trapped.all(func(s: String) -> bool: return s.contains("칸 1:0") or s.contains("칸 3:0")), "갇힘은 1:0·3:0 뿐 %s" % str(w))
	check(not w.any(func(s: String) -> bool: return s.contains("칸 2:0")), "2:0 은 경고 없음(닿음, 머물 수 없음) %s" % str(w))


## C. saved_at 은 정확히 20자이고 실제 시각.
func test_saved_at_edge_cases() -> void:
	var s := _state(1)
	for bad in ["2026-10-16T12:00:00Z\n", "2026-00-16T12:00:00Z", "2026-10-00T12:00:00Z", "2026-10-16T12:60:00Z", "2026-10-16T12:00:60Z", "1900-02-29T00:00:00Z"]:
		var doc := _doc(s)
		doc["saved_at"] = bad
		check(not _decode(doc).ok(), "saved_at 거부: %s" % bad.c_escape())
	var good := _doc(s)
	good["saved_at"] = "2000-02-29T00:00:00Z"
	check(_decode(good).ok(), "saved_at 허용: 2000-02-29")


## D. 최상위 grid 키를 찾아 위치를 잡는다.
func _grid_error_at(text: String, row_text: String, label: String) -> void:
	var errs := FloorLoader.parse_text(text, "fx.json").errors
	var lines := text.split("\n")
	var want := ""
	for i in lines.size():
		var at := lines[i].find(row_text)
		if at >= 0:
			want = "fx.json:%d:%d: " % [i + 1, at + 1 + 3]
	check(errs.size() == 1 and errs[0].begins_with(want), "%s: %s (기대 %s)" % [label, str(errs), want])


func _ordered_text(first: Array, grid_key: String) -> String:
	var d := Fx.floor_dict(Fx.row_grid("...", "  "))
	d["grid"][1] = "|. x .|"
	var parts: Array[String] = []
	for kv in first:
		parts.append("%s: %s" % [JSON.stringify(kv[0]), JSON.stringify(kv[1])])
	for k in ["name_key", "theme", "size", "start", "shortcuts", "encounter", "damage_floor"]:
		if not first.any(func(kv: Array) -> bool: return kv[0] == k):
			parts.append("%s: %s" % [JSON.stringify(k), JSON.stringify(d[k])])
	if not first.any(func(kv: Array) -> bool: return kv[0] == "id"):
		parts.append("\"id\": \"fx\"")
	var rows: Array[String] = []
	for row in d["grid"]:
		rows.append("    " + JSON.stringify(row))
	parts.append("%s: [\n%s\n  ]" % [grid_key, ",\n".join(rows)])
	return "{\n  " + ",\n  ".join(parts) + "\n}"


func test_grid_position_uses_real_top_level_key() -> void:
	_grid_error_at(_ordered_text([["id", "grid"]], "\"grid\""), "|. x .|", "id 값이 \"grid\"")
	_grid_error_at(_ordered_text([["start", {"at": [0, 0], "facing": "E", "grid": ["|. . .|"]}]], "\"grid\""), "|. x .|", "앞선 중첩 객체의 grid 키")
	_grid_error_at(_ordered_text([["id", "fx"]], "\"gr\\u0069d\""), "|. x .|", "이스케이프한 grid 키")


## E. generation 범위 0 ≤ g ≤ 2^53 − 2.
func test_generation_precision_limit() -> void:
	var max_gen := 9007199254740990  # 2^53 - 2
	var doc := _doc(_state(1))
	doc["generation"] = max_gen + 1
	check(not _decode(doc).ok(), "2^53 - 1 거부")
	doc["generation"] = max_gen
	var r := _decode(doc)
	check(r.ok() and r.state.generation == max_gen, "2^53 - 2 읽힘")
	if r.ok():
		Fx.clean_saves()
		var store := _store()
		check(not store.save("auto", r.state).is_empty(), "다음 저장은 범위를 넘어 실패")
		check_eq(r.state.generation, max_gen, "실패하면 generation 그대로")
		check(not store.load_slot("auto").had_candidates, "파일을 쓰지 않음")
		Fx.clean_saves()
	var s := _state(1)
	s.generation = 41
	Fx.clean_saves()
	check_eq(_store().save("auto", s), "", "보통 값 저장")
	check_eq(s.generation, 42, "보통 값은 +1")
	Fx.clean_saves()


## A. 분석 한도: 비트 수와 노드 수를 analyze·can_return 이 함께 쓴다.
func test_analysis_limits_shared() -> void:
	# 14×2 열린 방, 두 줄 사이 경계 14개 중 13개가 숨은 통로(H), 하나만 열림.
	var mid := "+" + "H+".repeat(13) + " +"
	var row := "|" + ". ".repeat(13) + ".|"
	var wall := "+" + "-+".repeat(14)
	var r := Fx.parse(Fx.floor_dict([wall, row, mid, row, wall]))
	check(r.ok(), "오류 없음 %s" % str(r.errors))
	var w := FloorLoader.analyze(r.floor_def, "fx.json")
	check(w.size() == 1 and w[0].contains("분석 미완료") and w[0].contains("4096"), "비트 한도: 분석 거부 %s" % str(w))
	var t0 := Time.get_ticks_msec()
	check_eq(FloorLoader.can_return(r.floor_def, Vector2i(13, 1), WorldState.new()), FloorLoader.Reach.UNKNOWN, "비트 한도: can_return 알 수 없음")
	check(Time.get_ticks_msec() - t0 < 1000, "비트 한도면 바로 돌아옴")
	# 노드 한도: f1_test(1104 노드)에 작은 한도를 넣는다.
	var f := Fx.f1()
	var small := FloorLoader.analyze(f, "f1.json", 100)
	check(small.size() == 1 and small[0].contains("분석 미완료"), "노드 한도: 분석 미완료 %s" % str(small))
	check(FloorLoader.analyze(f, "f1.json").is_empty(), "기본 한도면 경고 없음")
	var far := Vector2i(17, 1)
	check(f.is_cell(far), "먼 칸 %s" % str(far))
	check_eq(FloorLoader.can_return(f, far, WorldState.new(), 10), FloorLoader.Reach.UNKNOWN, "노드 한도: can_return 알 수 없음")
	check_eq(FloorLoader.can_return(f, far, WorldState.new()), FloorLoader.Reach.YES, "기본 한도면 돌아갈 수 있음")
	check_eq(FloorLoader.can_return(f, f.start_at, WorldState.new(), 1), FloorLoader.Reach.YES, "시작 칸이면 한도와 상관없이 돌아감")


# ---- 3차 검토 ----

const SLOT_FILES := ["auto.json", "auto.tmp", "auto.bak"]


## 슬롯 파일 이름 → 내용(없으면 빠짐).
func _files() -> Dictionary:
	var out := {}
	for name in SLOT_FILES:
		var path: String = Fx.SAVE_DIR + "/" + name
		if FileAccess.file_exists(path):
			out[name] = FileAccess.get_file_as_string(path)
	return out


## 1. 읽기 실패는 내용 손상이 아니다: 그 파일을 지우거나 옮기지 않고 저장을 실패로 돌려준다.
func test_read_failure_is_not_corruption() -> void:
	# 정리 단계 .tmp 읽기 실패 + ① 실패 / ② 시각 실패
	for second in ["write", "invalid"]:
		Fx.clean_saves()
		var store := _store()
		_prepare(store, "tmp_only", _state(1))
		var before := _files()
		var points: Array[String] = ["read_tmp"]
		if second == "write":
			points.append("write")
		store.fail_points = points
		var why := store.save("auto", _state(3), "invalid" if second == "invalid" else "")
		store.fail_points = []
		check(not why.is_empty(), "read_tmp+%s: 실패를 돌려줌" % second)
		check_eq(_files(), before, "read_tmp+%s: .tmp A 를 지우지 않음" % second)
	# 정리 단계 본 파일 읽기 실패: 정상 본 파일 Z 와 정상 .tmp A 가 있을 때 본 파일을 지우고 .tmp 를 올리지 않는다.
	Fx.clean_saves()
	var store := _store()
	store.save("auto", _state(1))
	store.stop_after_step = 2
	store.save("auto", _state(2))
	store.stop_after_step = 0
	var before := _files()
	store.fail_points = ["read_main", "write"]
	check(not store.save("auto", _state(3)).is_empty(), "정리 read_main+write: 실패를 돌려줌")
	store.fail_points = []
	check_eq(_files(), before, "정리 read_main+write: 본 파일 Z·.tmp A 그대로")
	# ③ 본 파일 읽기 실패: 정상 본 파일 A 를 깨진 것으로 보고 지우지 않는다. 내용이 다른 .bak Z 도 그대로.
	for extra in [[], ["rename_tmp"]]:
		Fx.clean_saves()
		store = _store()
		store.save("auto", _state(1))  # Z
		store.save("auto", _state(2))  # A, Z 는 .bak 으로
		var files_before := _files()
		check(files_before.has("auto.json") and files_before.has("auto.bak") and files_before["auto.json"] != files_before["auto.bak"], "③ 준비: 본 파일 A, 내용이 다른 .bak Z")
		var points: Array[String] = ["read_main"]
		points.append_array(extra)
		store.fail_points = points
		var b := _state(3)
		check(not store.save("auto", b).is_empty(), "③ %s: 실패를 돌려줌" % str(points))
		store.fail_points = []
		check_eq(b.generation, 0, "③ %s: generation 그대로" % str(points))
		var after := _files()
		check(after.get("auto.json") == files_before["auto.json"], "③ %s: 본 파일 A 내용 그대로" % str(points))
		check(after.get("auto.bak") == files_before["auto.bak"], "③ %s: .bak Z 내용 그대로" % str(points))
		var tmp := SaveCodec.decode(str(after.get("auto.tmp", "")), _f(), Fx.members())
		check(tmp.ok() and SaveCodec.state_hash(tmp.state) == SaveCodec.state_hash(b), "③ %s: 새 .tmp 는 정상이고 B" % str(points))
		check_eq(store.save("auto", b), "", "③ %s: 다음 저장은 성공" % str(points))
	Fx.clean_saves()


## 2. budget 0·음수는 탐색하지 않고 한도 초과로 다룬다(시작 칸이면 can_return 은 YES).
func test_budget_zero_or_negative() -> void:
	var walled := Fx.floor_of(Fx.row_grid("..", "|"), {"id": "fx_walled"})  # 시작 칸이 막혀 노드 하나로 끝나는 층
	for budget in [0, -1]:
		for f in [walled, Fx.f1()]:
			var w := FloorLoader.analyze(f, "fx.json", budget)
			check(w.size() == 1 and w[0].contains("분석 미완료"), "budget %d %s: 분석 미완료 %s" % [budget, f.id, str(w)])
		check_eq(FloorLoader.can_return(walled, Vector2i(1, 0), WorldState.new(), budget), FloorLoader.Reach.UNKNOWN, "budget %d: 알 수 없음" % budget)
		check_eq(FloorLoader.can_return(walled, walled.start_at, WorldState.new(), budget), FloorLoader.Reach.YES, "budget %d: 시작 칸은 YES" % budget)


## a. 실제 .bak 을 지운 뒤 실패: 내용이 다른 .bak Z 는 지워지고 본 파일 A 가 남는다.
func test_failure_after_real_bak_removed() -> void:
	Fx.clean_saves()
	var store := _store()
	var z := _state(1)
	var a := _state(2)
	store.save("auto", z)
	store.save("auto", a)
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	var bak := SaveCodec.decode(FileAccess.get_file_as_string(bak_path), _f(), Fx.members())
	check(bak.ok() and SaveCodec.state_hash(bak.state) == SaveCodec.state_hash(z) and SaveCodec.state_hash(z) != SaveCodec.state_hash(a), "준비: 본 파일 A, 내용이 다른 .bak Z")
	var b := _state(3)
	store.fail_points = ["after_bak_removed"]
	check(not store.save("auto", b).is_empty(), "실패를 돌려줌")
	store.fail_points = []
	check(not FileAccess.file_exists(bak_path), ".bak Z 가 실제로 지워짐")
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(a), "본 파일 A 가 읽힘")
	check_eq(store.save("auto", b), "", "다음 저장은 성공")
	l = store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and SaveCodec.state_hash(l.result.state) == SaveCodec.state_hash(b), "본 파일 B")
	Fx.clean_saves()


## b. 저장 전 generation 거부는 파일을 건드리지 않는다(정리 단계도 돌지 않음).
func test_generation_precheck_touches_no_file() -> void:
	Fx.clean_saves()
	var store := _store()
	_prepare(store, "tmp_only", _state(1))
	var before := _files()
	var s := _state(3)
	s.generation = SaveCodec.MAX_GENERATION
	check(not store.save("auto", s).is_empty(), "실패를 돌려줌")
	check_eq(s.generation, SaveCodec.MAX_GENERATION, "generation 그대로")
	check_eq(_files(), before, "파일 이름·내용 그대로(.tmp 가 본 파일로 올라가지 않음)")
	Fx.clean_saves()


## c. 본 파일이 세대보다 우선: 더 높은 세대의 정상 .tmp 가 있어도 본 파일을 먼저 읽는다.
func test_main_wins_over_newer_tmp() -> void:
	Fx.clean_saves()
	var store := _store()
	store.save("auto", _state(1))
	var newer := _state(2)
	newer.generation = 5
	store.stop_after_step = 2
	store.save("auto", newer)
	store.stop_after_step = 0
	var tmp := SaveCodec.decode(FileAccess.get_file_as_string(Fx.SAVE_DIR + "/auto.tmp"), _f(), Fx.members())
	check(tmp.ok() and tmp.generation == 6, "준비: 정상 .tmp 세대 6")
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and l.result.generation == 1, "본 파일(세대 1)이 먼저")
	Fx.clean_saves()


## d. generation 위 경계: MAX − 1 은 저장되어 MAX 가 되고, 그다음은 거부.
func test_generation_upper_boundary() -> void:
	Fx.clean_saves()
	var store := _store()
	var s := _state(1)
	s.generation = SaveCodec.MAX_GENERATION - 1
	check_eq(store.save("auto", s), "", "MAX − 1 저장")
	check_eq(s.generation, SaveCodec.MAX_GENERATION, "MAX 가 됨")
	check_eq(store.slot_info("auto").generation, SaveCodec.MAX_GENERATION, "파일도 MAX")
	check(not store.save("auto", s).is_empty(), "그다음 저장은 거부")
	check_eq(s.generation, SaveCodec.MAX_GENERATION, "generation 그대로")
	Fx.clean_saves()


## d. 맨 위 grid 키가 두 번이면 마지막 값(파서가 쓰는 값)의 위치를 짚는다.
func test_duplicate_top_level_grid_key() -> void:
	_grid_error_at(_ordered_text([["grid", Fx.row_grid("...", "  ")]], "\"grid\""), "|. x .|", "grid 키 두 번")


## 실제 열기·읽기 경로의 분류: 못 읽음(read_error) / 정상 / 읽었지만 내용이 틀림(broken).
func test_check_file_classifies_real_reads() -> void:
	Fx.clean_saves()
	var store := _store()
	var missing := store._check_file(Fx.SAVE_DIR + "/none.json", "")
	check(not missing.read_error.is_empty() and missing.error.is_empty(), "없는 경로: read_error 만 (%s / %s)" % [missing.read_error, missing.error])
	store.save("auto", _state(1))
	var good := store._check_file(store.main_path("auto"), "")
	check(good.good(), "정상 저장 파일: good (%s / %s)" % [good.read_error, good.error])
	var empty_path := Fx.SAVE_DIR + "/empty.json"
	_write_raw(empty_path, "")
	check_eq(FileAccess.get_file_as_string(empty_path).length(), 0, "준비: 0바이트 파일")
	var empty := store._check_file(empty_path, "")
	check(empty.read_error.is_empty() and empty.broken(), "빈 파일: 읽기는 성공, broken (%s / %s)" % [empty.read_error, empty.error])
	var bad_path := Fx.SAVE_DIR + "/bad.json"
	_write_raw(bad_path, "{bad")
	var bad := store._check_file(bad_path, "")
	check(bad.broken(), "잘못된 JSON: broken (%s / %s)" % [bad.read_error, bad.error])
	Fx.clean_saves()
