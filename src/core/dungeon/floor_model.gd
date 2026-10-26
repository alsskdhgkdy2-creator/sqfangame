## 층의 정적 정의: 칸 종류, 경계 종류, 지름길 열 수 있는 쪽, 구역, 시작, 계단, 잠긴 문·보물상자·예약 구역(M3 A3). 읽은 뒤 바뀌지 않는다.
class_name FloorModel
extends RefCounted


## 계단 하나(M3 A1). 짝은 다른 층의 계단(to_floor 의 to_at)이고 방향(way)이 반대다.
## 계단으로 이 층에 오면 이 계단 칸에 서서 exit 쪽을 바라본다. at + exit 는 바닥 칸이고 그 사이 경계는 열림·문이다(내려설 수 있다).
class Stair:
	extends RefCounted
	var at := Vector2i.ZERO
	## "up"·"down"
	var way := ""
	var exit := Dir.N
	var to_floor := ""
	var to_at := Vector2i.ZERO


## 보물상자 하나(M3 A3). 내용은 item(소재 item.·장비 equip.·열쇠 key.) count 개, 또는 money 엔(item 이 "" 이면 money).
## 저장은 칸이 아니라 id(층 안에서 하나)로 연 것을 기억한다(층을 다듬어 상자를 옮겨도 저장이 깨지지 않게).
class Chest:
	extends RefCounted
	var id := ""
	var at := Vector2i.ZERO
	var item := ""
	var count := 1
	var money := 0

enum Cell { VOID, FLOOR, DAMAGE, ICE }
## LOCK(M3 A3, 격자 K): 잠긴 문. 열쇠 문(locks 의 key)은 열쇠를 가지고 어느 쪽에서나 열고, 봉인 문(seal)은 A3 에서 열리지 않는다.
## 값이 밀리지 않게 새 종류는 맨 뒤에 둔다.
enum Edge { OPEN, WALL, DOOR, SHORTCUT, PASSAGE, ONEWAY, LOCK }

var id := ""
var name_key := ""
var theme := ""
var width := 0
var height := 0
## 시작 칸. 계단이 있는 층은 없어도 된다(그때 GridKey.BAD_CELL, has_start 거짓). 층 묶음의 첫 층은 있어야 한다.
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
## 계단: 칸 Vector2i → Stair.
var stairs := {}
## 보물상자(M3 A3): id → Chest(읽은 차례). 칸 → id 는 _chest_cells.
var chests := {}
## 예약 구역(M3 A3, A9 보스 방 자리): 아직 닿지 않아도 되는 칸들의 사각형(Rect2i). 분석이 「닿을 수 없다」를 내지 않는다.
var reserved: Array[Rect2i] = []

var _cells := PackedByteArray()
var _h := PackedByteArray()
var _v := PackedByteArray()
var _oneway_dir := {}  # Vector3i → 지나갈 수 있는 방향
var _shortcut_opener := {}  # Vector3i → 열 수 있는 쪽 칸 Vector2i
var _lock_key := {}  # Vector3i → 열쇠 ID(봉인 문은 "")
var _lock_seal := {}  # Vector3i → 봉인 이유(열쇠 문에는 없다)
var _chest_cells := {}  # Vector2i → 상자 id


func _init(w: int = 1, h: int = 1) -> void:
	width = w
	height = h
	_cells.resize(w * h)
	_h.resize(w * (h + 1))
	_v.resize((w + 1) * h)


func has_start() -> bool:
	return start_at != GridKey.BAD_CELL


## 칸 c 의 계단. 없으면 null.
func stair_at(c: Vector2i) -> Stair:
	return stairs.get(c)


## 계단 목록(줄 순서).
func stair_list() -> Array[Stair]:
	var out: Array[Stair] = []
	for c in cells():
		if stairs.has(c):
			out.append(stairs[c])
	return out


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


## 잠긴 문을 둔다(M3 A3): key 가 비어 있지 않으면 열쇠 문, 아니면 seal 이유의 봉인 문.
func set_lock(e: Vector3i, key: String, seal: String = "") -> void:
	_lock_key[e] = key
	if key.is_empty():
		_lock_seal[e] = seal
	else:
		_lock_seal.erase(e)


## 잠긴 문 항목이 있는지.
func has_lock_entry(e: Vector3i) -> bool:
	return _lock_key.has(e)


## 열쇠 문의 열쇠 ID. 봉인 문·잠긴 문이 아니면 "".
func lock_key(e: Vector3i) -> String:
	return _lock_key.get(e, "")


## 봉인 문인지(잠긴 문 가운데 열쇠가 없는 것).
func is_sealed(e: Vector3i) -> bool:
	return _lock_seal.has(e)


## 봉인 이유("boss" 등). 봉인 문이 아니면 "".
func seal_of(e: Vector3i) -> String:
	return _lock_seal.get(e, "")


## 상자를 둔다. 같은 칸·id 검사는 읽는 쪽(FloorLoader)이 한다.
func add_chest(c: Chest) -> void:
	chests[c.id] = c
	_chest_cells[c.at] = c.id


## 칸 c 의 상자. 없으면 null.
func chest_at(c: Vector2i) -> Chest:
	return chests.get(_chest_cells.get(c, ""))


## 상자 목록(읽은 차례).
func chest_list() -> Array[Chest]:
	var out: Array[Chest] = []
	for id in chests:
		out.append(chests[id])
	return out


## 칸 c 가 예약 구역 안인지.
func is_reserved(c: Vector2i) -> bool:
	for r in reserved:
		if r.has_point(c):
			return true
	return false
