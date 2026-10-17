extends TestCase

const Fx := preload("res://tests/fixtures.gd")

## 3×2 기본 층: 위 줄 세 칸, 아래 줄 가운데 한 칸.
const BASE := [
	"+-+-+-+",
	"|. . .|",
	"+-+ +-+",
	"|#|.|#|",
	"+-+-+-+",
]


func _errors_of(d: Dictionary) -> Array[String]:
	return Fx.parse(d).errors


## 오류가 하나 이상 있고, 모두 "fx.json:줄:열: " 로 시작하며, 하나는 needle 을 담는지.
func _expect_error(d: Dictionary, needle: String, label: String) -> void:
	var errs := _errors_of(d)
	check(not errs.is_empty(), "%s: 오류가 나야 한다" % label)
	var re := RegEx.create_from_string("^fx\\.json:\\d+:\\d+: ")
	var found := false
	for e in errs:
		check(re.search(e) != null, "%s: 위치 없는 오류 %s" % [label, e])
		found = found or e.contains(needle)
	check(found, "%s: '%s' 를 담은 오류가 없다 %s" % [label, needle, str(errs)])


## 오류 없이 읽혔을 때의 도달·갇힘 분석 경고.
func _warnings(r: FloorLoader.Result) -> Array[String]:
	return FloorLoader.analyze(r.floor_def, "fx.json") if r.ok() else ["읽기 오류"] as Array[String]


func _with(grid: Array, extra: Dictionary = {}) -> Dictionary:
	return Fx.floor_dict(grid, extra)


func test_f1_test_loads_clean_with_all_devices() -> void:
	var r := FloorLoader.load_path(Fx.F1_PATH)
	check_eq(r.errors, [] as Array[String], "오류")
	var f := r.floor_def
	check_eq(FloorLoader.analyze(f, "f1_test.json"), [] as Array[String], "도달·갇힘 분석 경고 0")
	check_eq([f.width, f.height], [20, 20], "크기")
	check(f.edges_of_kind(FloorModel.Edge.DOOR).size() >= 2, "일반 문 2곳 이상")
	check_eq(f.edges_of_kind(FloorModel.Edge.SHORTCUT).size(), 1, "지름길 문 1곳")
	check_eq(f.edges_of_kind(FloorModel.Edge.PASSAGE).size(), 2, "숨은 통로 2곳")
	var oneways := f.edges_of_kind(FloorModel.Edge.ONEWAY)
	check(oneways.any(func(e: Vector3i) -> bool: return e.z == 0) and oneways.any(func(e: Vector3i) -> bool: return e.z == 1), "일방통행 가로·세로 하나씩")
	var kinds := f.cells().map(func(c: Vector2i) -> int: return f.cell_kind(c))
	check(kinds.has(FloorModel.Cell.DAMAGE) and kinds.has(FloorModel.Cell.ICE), "피해 바닥·미끄러운 바닥")
	check_eq(f.danger_at(f.start_at), 0, "시작은 안전 구역")


func test_good_floor_has_no_errors() -> void:
	var r := Fx.parse(_with(BASE))
	check(r.ok(), "기본 층 오류 %s" % str(r.errors))


func test_error_position_points_at_grid_char() -> void:
	var grid := BASE.duplicate()
	grid[1] = "|. x .|"  # 1줄 3열이 칸 자리인데 'x'
	var text := JSON.stringify(_with(grid), "\t")
	var errs := FloorLoader.parse_text(text, "fx.json").errors
	check_eq(errs.size(), 1, "오류 수 %s" % str(errs))
	var lines := text.split("\n")
	var want_line := -1
	for i in lines.size():
		if lines[i].contains("|. x .|"):
			want_line = i + 1
	var want_col: int = lines[want_line - 1].find("|. x .|") + 1 + 3
	check(errs[0].begins_with("fx.json:%d:%d: " % [want_line, want_col]), "위치 %s, 기대 %d:%d" % [errs[0], want_line, want_col])


func test_json_syntax_error_has_line() -> void:
	var errs := FloorLoader.parse_text("{\n  \"id\": \"fx\",\n  oops\n}", "fx.json").errors
	check(errs.size() == 1 and errs[0].begins_with("fx.json:3:"), "JSON 오류 위치 %s" % str(errs))


func test_type_errors() -> void:
	_expect_error(_with(BASE, {"size": [3.5, 2]}), "정수", "소수 크기")
	_expect_error(_with(BASE, {"size": [true, 2]}), "정수", "불리언 크기")
	_expect_error(_with(BASE, {"size": [0, 2]}), "양수", "0 크기")
	_expect_error(_with(BASE, {"encounter": {"danger_per_step": 2.5, "threshold_min": 1, "threshold_max": 2}}), "danger_per_step", "소수 위험도")
	_expect_error(_with(BASE, {"encounter": {"danger_per_step": 1, "threshold_min": true, "threshold_max": 2}}), "threshold_min", "불리언 한계")
	_expect_error(_with(BASE, {"damage_floor": {"damage": 1.5}}), "damage", "소수 피해")
	_expect_error(_with(BASE, {"id": 3}), "id", "id 자료형")


func test_range_errors() -> void:
	_expect_error(_with(BASE, {"damage_floor": {"damage": -1}}), "damage", "피해 음수")
	_expect_error(_with(BASE, {"encounter": {"danger_per_step": -1, "threshold_min": 1, "threshold_max": 2}}), "danger_per_step", "위험도 음수")
	_expect_error(_with(BASE, {"encounter": {"danger_per_step": 1, "threshold_min": 0, "threshold_max": 2}}), "threshold_min", "한계 0")
	_expect_error(_with(BASE, {"encounter": {"danger_per_step": 1, "threshold_min": 5, "threshold_max": 4}}), "threshold_min ≤ threshold_max", "한계 뒤집힘")
	_expect_error(_with(BASE, {"zones": [{"id": "z", "rect": [0, 0, 3, 1], "danger_per_step": 0}]}), "zones[0].rect", "구역 밖")
	_expect_error(_with(BASE, {"zones": [{"id": "z", "rect": [0, 0, 1, 1], "danger_per_step": -2}]}), "danger_per_step", "구역 위험도 음수")


func test_grid_shape_errors() -> void:
	_expect_error(_with(BASE.slice(0, 4), {"size": [3, 2]}), "줄 수", "줄 수")
	var short := BASE.duplicate()
	short[1] = "|. .|"
	_expect_error(_with(short), "길이", "줄 길이")
	var bad_corner := BASE.duplicate()
	bad_corner[2] = "+-+ --+"
	_expect_error(_with(bad_corner), "쓸 수 없다", "모서리 문자")
	var bad_v := BASE.duplicate()
	bad_v[1] = "|.v. .|"
	_expect_error(_with(bad_v), "'v'", "세로 경계에 v")
	var bad_h := BASE.duplicate()
	bad_h[2] = "+-+>+-+"
	_expect_error(_with(bad_h), "'>'", "가로 경계에 >")


func test_border_and_void_errors() -> void:
	var open_border := BASE.duplicate()
	open_border[1] = " . . .|"
	_expect_error(_with(open_border), "바깥 테두리", "테두리 열림")
	var void_open := BASE.duplicate()
	void_open[3] = "|# . #|"
	_expect_error(_with(void_open), "빈 곳", "빈 곳 옆 열림")


func test_shortcut_errors() -> void:
	var with_l := BASE.duplicate()
	with_l[1] = "|.L. .|"
	_expect_error(_with(with_l), "shortcuts 항목이 없다", "L 만 있음")
	_expect_error(_with(BASE, {"shortcuts": [{"at": [0, 0], "dir": "E"}]}), "L 이 아니다", "항목만 있음")
	_expect_error(_with(with_l, {"shortcuts": [{"at": [0, 0], "dir": "Q"}]}), "N·E·S·W", "방향 문자")
	_expect_error(_with(with_l, {"shortcuts": [{"at": [0, 0], "dir": "E"}, {"at": [1, 0], "dir": "W"}]}), "중복", "중복 항목")
	check(Fx.parse(_with(with_l, {"shortcuts": [{"at": [1, 0], "dir": "W"}]})).ok(), "올바른 지름길")


func test_start_errors() -> void:
	_expect_error(_with(BASE, {"start": {"at": [0, 1], "facing": "N"}}), "바닥 칸", "빈 곳 시작")
	var ice := BASE.duplicate()
	ice[1] = "|= . .|"
	_expect_error(_with(ice), "바닥 칸", "얼음 시작")
	_expect_error(_with(BASE, {"start": {"at": [0, 0], "facing": "X"}}), "N·E·S·W", "시작 방향")
	_expect_error(_with(BASE, {"start": {"at": [0.5, 0], "facing": "N"}}), "정수", "시작 좌표 소수")


func test_missing_damage_floor_with_damage_cells() -> void:
	var g := BASE.duplicate()
	g[1] = "|. ~ .|"
	var d := _with(g)
	d.erase("damage_floor")
	_expect_error(d, "damage_floor", "피해 정의 없음")


func test_warning_unreachable() -> void:
	var g := [
		"+-+-+-+",
		"|. .|.|",
		"+-+-+-+",
	]
	var r := Fx.parse(_with(g))
	var w := _warnings(r)
	check_eq(w.size(), 1, "경고 수 %s" % str(w))
	check(w.size() == 1 and w[0].contains("2:0") and w[0].contains("닿을 수 없다"), "닿을 수 없는 칸")


func test_warning_trapped_behind_oneway() -> void:
	var r := Fx.parse(_with(Fx.row_grid("...", " >")))
	var w := _warnings(r)
	check_eq(w.size(), 1, "경고 수 %s" % str(w))
	check(w.size() == 1 and w[0].contains("2:0") and w[0].contains("갇힘"), "갇힘 경고")


## 얼음 복도 가운데 칸 옆 갈림길: 단순 칸 연결로는 닿지만 실제로는 멈출 수 없어 못 간다.
func test_warning_ice_corridor_side_branch() -> void:
	var g := [
		"+-+-+-+-+-+",
		"|. = = = .|",
		"+-+-+ +-+-+",
		"|#|#|.|#|#|",
		"+-+-+-+-+-+",
	]
	var r := Fx.parse(_with(g))
	check(r.ok(), "오류 없음 %s" % str(r.errors))
	check(_naive_reachable(r.floor_def).has(Vector2i(2, 1)), "단순 BFS 는 갈림길을 닿음으로 센다")
	var w := _warnings(r)
	check_eq(w.size(), 1, "경고 수 %s" % str(w))
	check(w.size() == 1 and w[0].contains("2:1") and w[0].contains("닿을 수 없다"), "갈림길 칸 닿을 수 없음")


func test_shortcut_and_passage_count_as_reachable() -> void:
	# 일방통행으로 내려가 지름길을 열고, 숨은 통로로 시작 칸에 돌아온다.
	var g := [
		"+-+-+-+",
		"|. . .|",
		"+H+-+v+",
		"|.L. .|",
		"+-+-+-+",
	]
	var r := Fx.parse(_with(g, {"shortcuts": [{"at": [1, 1], "dir": "W"}]}))
	check_eq(_warnings(r), [] as Array[String], "통로·지름길 고려")
	var locked := _warnings(Fx.parse(_with(Fx.row_grid("...", " L"), {"shortcuts": [{"at": [2, 0], "dir": "W"}]})))
	check(locked.size() == 1 and locked[0].contains("2:0"), "반대쪽에서만 열리는 지름길 너머는 닿지 못함 %s" % str(locked))


func _naive_reachable(f: FloorModel) -> Dictionary:
	var seen := {f.start_at: true}
	var queue: Array[Vector2i] = [f.start_at]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in 4:
			var n := c + Dir.vec(d)
			if f.is_cell(n) and f.edge_kind(FloorModel.edge_of(c, d)) != FloorModel.Edge.WALL and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen
