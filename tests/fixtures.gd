## 시험용 층·파티·상태 도우미(test_ 로 시작하지 않아 실행기가 시험으로 읽지 않는다).
extends RefCounted

const A := ExplorationRules.Action
const F1_PATH := "res://data/floors/f1_test.json"
const PARTY_PATH := "res://data/party/test_party.json"
const SAVE_DIR := "user://test_saves"

static var _f1: FloorModel
static var _party: PartyData


static func f1() -> FloorModel:
	if _f1 == null:
		_f1 = FloorLoader.load_path(F1_PATH).floor_def
	return _f1


static func members() -> Array[PartyState.Member]:
	if _party == null:
		_party = PartyData.load_path(PARTY_PATH)
	return _party.make_members()


## 기본 필드를 채운 층 정의 사전. extra로 덮어쓴다.
static func floor_dict(grid: Array, extra: Dictionary = {}) -> Dictionary:
	var w := (str(grid[0]).length() - 1) / 2
	var h := (grid.size() - 1) / 2
	var d := {
		"id": "fx", "name_key": "floor.fx", "theme": "stratum1", "size": [w, h], "grid": grid,
		"start": {"at": [0, 0], "facing": "E"}, "shortcuts": [],
		"encounter": {"danger_per_step": 10, "threshold_min": 1000, "threshold_max": 1000},
		"damage_floor": {"damage": 3},
	}
	d.merge(extra, true)
	return d


static func parse(d: Dictionary) -> FloorLoader.Result:
	return FloorLoader.parse_text(JSON.stringify(d, "\t"), "fx.json")


## 오류 없이 읽히는 층. 오류가 있으면 실행을 멈추게 null.
static func floor_of(grid: Array, extra: Dictionary = {}) -> FloorModel:
	var r := parse(floor_dict(grid, extra))
	if not r.ok():
		push_error("시험 층 오류: %s" % str(r.errors))
		return null
	return r.floor_def


## 한 줄 층. cells는 칸 문자들, inner는 칸 사이 세로 경계 문자들(길이 = 칸 수 − 1).
static func row_grid(cells: String, inner: String) -> Array:
	var border := "+" + "-+".repeat(cells.length())
	var mid := "|"
	for i in cells.length():
		mid += cells[i]
		mid += inner[i] if i < inner.length() else "|"
	return [border, mid, border]


static func row_floor(cells: String, inner: String, extra: Dictionary = {}) -> FloorModel:
	return floor_of(row_grid(cells, inner), extra)


static func game(f: FloorModel, seed_value: int = 1, automap: String = "floor") -> ExplorationState:
	return ExplorationRules.new_game(f, members(), seed_value, automap)


## 이벤트 종류만 뽑는다.
static func types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(e["type"])
	return out


## 절대 방향 문자열("NNE…")대로 실제 회전·전진 행동을 한다. 전투 대기면 해결한다. 모든 이벤트를 돌려준다.
static func walk(s: ExplorationState, dirs: String, automap: String = "floor") -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for ch in dirs:
		var want := Dir.from_name(ch)
		while s.party.facing != want:
			all.append_array(ExplorationRules.apply(s, A.TURN_RIGHT if Dir.right(s.party.facing) == want or Dir.opposite(s.party.facing) == want else A.TURN_LEFT, automap))
		all.append_array(ExplorationRules.apply(s, A.FORWARD, automap))
		if s.encounter.pending:
			ExplorationRules.resolve_battle(s)
	return all


static func face(s: ExplorationState, d: int, automap: String = "floor") -> void:
	while s.party.facing != d:
		ExplorationRules.apply(s, A.TURN_RIGHT, automap)


static func clean_saves() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SAVE_DIR)
