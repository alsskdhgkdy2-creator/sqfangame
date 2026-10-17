## 층의 정적 정의: 칸 종류, 경계 종류, 지름길 열 수 있는 쪽, 구역, 시작. 읽은 뒤 바뀌지 않는다.
class_name FloorModel
extends RefCounted

enum Cell { VOID, FLOOR, DAMAGE, ICE }
enum Edge { OPEN, WALL, DOOR, SHORTCUT, PASSAGE, ONEWAY }

var id := ""
var name_key := ""
var theme := ""
var width := 0
var height := 0
var start_at := Vector2i.ZERO
var start_facing := Dir.N
var danger_per_step := 0
var threshold_min := 1
var threshold_max := 1
## 인카운트 출현 표 ID(06 §8.2). 없으면 빈 문자열.
var encounter_table := ""
var damage := 0
## 구역: {"id": String, "rect": Rect2i, "danger_per_step": int}. 목록 순서대로 처음 맞는 것.
var zones: Array[Dictionary] = []

var _cells := PackedByteArray()
var _h := PackedByteArray()
var _v := PackedByteArray()
var _oneway_dir := {}  # Vector3i → 지나갈 수 있는 방향
var _shortcut_opener := {}  # Vector3i → 열 수 있는 쪽 칸 Vector2i


func _init(w: int = 1, h: int = 1) -> void:
	width = w
	height = h
	_cells.resize(w * h)
	_h.resize(w * (h + 1))
	_v.resize((w + 1) * h)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func cell_kind(c: Vector2i) -> int:
	if not in_bounds(c):
		return Cell.VOID
	return _cells[c.y * width + c.x]


## 빈 곳(#)이 아닌 칸인지.
func is_cell(c: Vector2i) -> bool:
	return cell_kind(c) != Cell.VOID


func set_cell(c: Vector2i, kind: int) -> void:
	_cells[c.y * width + c.x] = kind


func edge_in_range(e: Vector3i) -> bool:
	if e.z == 0:
		return e.x >= 0 and e.x < width and e.y >= 0 and e.y <= height
	if e.z == 1:
		return e.x >= 0 and e.x <= width and e.y >= 0 and e.y < height
	return false


func edge_kind(e: Vector3i) -> int:
	if not edge_in_range(e):
		return Edge.WALL
	if e.z == 0:
		return _h[e.y * width + e.x]
	return _v[e.y * (width + 1) + e.x]


func set_edge(e: Vector3i, kind: int, oneway_dir: int = -1) -> void:
	if e.z == 0:
		_h[e.y * width + e.x] = kind
	else:
		_v[e.y * (width + 1) + e.x] = kind
	if kind == Edge.ONEWAY:
		_oneway_dir[e] = oneway_dir


## 칸 c의 d 방향 경계.
static func edge_of(c: Vector2i, d: int) -> Vector3i:
	match d:
		Dir.N:
			return Vector3i(c.x, c.y, 0)
		Dir.S:
			return Vector3i(c.x, c.y + 1, 0)
		Dir.W:
			return Vector3i(c.x, c.y, 1)
		_:
			return Vector3i(c.x + 1, c.y, 1)


## 경계 양쪽 칸(북·서쪽 칸 먼저). 판 밖일 수 있다.
static func cells_of_edge(e: Vector3i) -> Array[Vector2i]:
	if e.z == 0:
		return [Vector2i(e.x, e.y - 1), Vector2i(e.x, e.y)]
	return [Vector2i(e.x - 1, e.y), Vector2i(e.x, e.y)]


## 일방통행 경계가 허용하는 방향. 일방통행이 아니면 -1.
func oneway_dir(e: Vector3i) -> int:
	return _oneway_dir.get(e, -1)


func set_shortcut_opener(e: Vector3i, c: Vector2i) -> void:
	_shortcut_opener[e] = c


## 지름길 문을 열 수 있는 쪽 칸. 지름길이 아니면 GridKey.BAD_CELL.
func shortcut_opener(e: Vector3i) -> Vector2i:
	return _shortcut_opener.get(e, GridKey.BAD_CELL)


## 칸 c에서 한 걸음 내디딜 때 더하는 위험도.
func danger_at(c: Vector2i) -> int:
	for z in zones:
		var r: Rect2i = z["rect"]
		if r.has_point(c):
			return z["danger_per_step"]
	return danger_per_step


## 종류가 kind인 경계 목록(h 먼저, 줄 순서).
func edges_of_kind(kind: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in height + 1:
		for x in width:
			if _h[y * width + x] == kind:
				out.append(Vector3i(x, y, 0))
	for y in height:
		for x in width + 1:
			if _v[y * (width + 1) + x] == kind:
				out.append(Vector3i(x, y, 1))
	return out


## 빈 곳이 아닌 칸 목록(줄 순서).
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			if _cells[y * width + x] != Cell.VOID:
				out.append(Vector2i(x, y))
	return out
