## 층의 정적 정의: 칸 종류, 경계 종류, 지름길 열 수 있는 쪽, 구역, 시작, 계단, 잠긴 문·보물상자·예약 구역(M3 A3), 채집 지점(A5), FOE 배치(A6).
## 읽은 뒤 바뀌지 않는다.
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
	## 내려가는 계단을 막는 진행 플래그(M3 A8, 관리국 탐사 허가). 없으면 "".
	var needs := ""


## 보물상자 하나(M3 A3). 내용은 item(소재 item.·장비 equip.·열쇠 key.) count 개, 또는 money 엔(item 이 "" 이면 money).
## 저장은 칸이 아니라 id(층 안에서 하나)로 연 것을 기억한다(층을 다듬어 상자를 옮겨도 저장이 깨지지 않게).
class Chest:
	extends RefCounted
	var id := ""
	var at := Vector2i.ZERO
	var item := ""
	var count := 1
	var money := 0

## 채집 지점 하나(M3 A5, 01 §3.6): 종류(take 채취·chop 절단·mine 추출), 하루 횟수, 채집 표 ID.
## 저장은 칸이 아니라 id(층 안에서 하나)로 그날 쓴 횟수를 기억한다(상자와 같다). id 를 바꾸거나 지우면 저장 이전이 필요하다.
class GatherPoint:
	extends RefCounted
	var id := ""
	var at := Vector2i.ZERO
	var kind := ""
	var uses := 1
	var table := ""

## FOE 하나의 배치(M3 A6, 01 §3.5): 정의(foe., 무리·위협 레벨), 종류(patrol 순회·chase 추적·guard 문지기), 시작 칸·방향,
## 경로(순회는 반드시, 추적은 있으면 그 길을 돈다), 시야·추적 거리(추적), 합류 거리(순회·추적), 되살아남(never·after_days·floor_reload).
## 저장은 id(층 안에서 하나)로 상태를 기억한다. id·경로·칸을 바꾸면 저장 이전이 필요하다.
class FoeSpawn:
	extends RefCounted
	var id := ""
	var foe := ""
	var kind := ""
	var at := Vector2i.ZERO
	var facing := 0
	var path: Array[Vector2i] = []
	var sight := 0
	var chase := 0
	var join := 0
	var respawn := ""
	var respawn_days := 0

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
## 채집 지점(M3 A5): id → GatherPoint(읽은 차례). 칸 → id 는 _point_cells.
var points := {}
## FOE(M3 A6): id → FoeSpawn(읽은 차례, FOE 가 움직이는 차례이기도 하다).
var foes := {}
## 예약 구역(M3 A3, A9 보스 방 자리): 아직 닿지 않아도 되는 칸들의 사각형(Rect2i). 분석이 「닿을 수 없다」를 내지 않는다.
var reserved: Array[Rect2i] = []
## 귀환 비콘을 쓸 수 없는 칸(M3 A4 갈고리, A9 보스 방): 칸 Vector2i → true. 층 키 no_return(사각형들, M3 A9)이 채운다.
## ItemRules.return_block 이 「sealed」로 막는다.
var no_return := {}
## 봉인 문 뒤 칸(M3 A9 설계 조건 1): needs 가 있는 봉인 경계 Vector3i → {칸 Vector2i: true}. 그 봉인만 닫고 다른 세계 비트는 모두 열 수 있다고 칠 때
## 들어오는 곳(시작 칸·계단)에서 닿지 못하는 칸이다(FloorLoader 가 읽을 때 한 번 센다). 닫힌 봉인 뒤에 선 저장은 영영 나오지 못하므로 저장 검사가 거부한다.
var behind_seal := {}

var _cells := PackedByteArray()
var _h := PackedByteArray()
var _v := PackedByteArray()
var _oneway_dir := {}  # Vector3i → 지나갈 수 있는 방향
var _shortcut_opener := {}  # Vector3i → 열 수 있는 쪽 칸 Vector2i
var _lock_key := {}  # Vector3i → 열쇠 ID(봉인 문은 "")
var _lock_seal := {}  # Vector3i → 봉인 이유(열쇠 문에는 없다)
var _seal_needs := {}  # Vector3i → 봉인을 여는 진행 플래그(M3 A9, needs 가 있는 봉인만)
var _chest_cells := {}  # Vector2i → 상자 id
var _point_cells := {}  # Vector2i → 채집 지점 id


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


## 잠긴 문을 둔다(M3 A3): key 가 비어 있지 않으면 열쇠 문, 아니면 seal 이유의 봉인 문. needs(M3 A9)는 봉인 문을 여는 진행 플래그.
func set_lock(e: Vector3i, key: String, seal: String = "", needs: String = "") -> void:
	_lock_key[e] = key
	_seal_needs.erase(e)
	if key.is_empty():
		_lock_seal[e] = seal
		if not needs.is_empty():
			_seal_needs[e] = needs
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


## 봉인 문을 여는 진행 플래그(M3 A9). needs 가 없는 봉인·봉인이 아닌 경계는 "".
func seal_needs(e: Vector3i) -> String:
	return _seal_needs.get(e, "")


## needs 가 있는 봉인 경계들(경계 순서, M3 A9).
func needs_seals() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for e in edges_of_kind(Edge.LOCK):
		if _seal_needs.has(e):
			out.append(e)
	return out


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


func add_point(p: GatherPoint) -> void:
	points[p.id] = p
	_point_cells[p.at] = p.id


## 칸 c 의 채집 지점. 없으면 null.
func point_at(c: Vector2i) -> GatherPoint:
	return points.get(_point_cells.get(c, ""))


## 채집 지점 목록(읽은 차례).
func point_list() -> Array[GatherPoint]:
	var out: Array[GatherPoint] = []
	for id in points:
		out.append(points[id])
	return out


## 칸 c 가 예약 구역 안인지.
func is_reserved(c: Vector2i) -> bool:
	for r in reserved:
		if r.has_point(c):
			return true
	return false


## FOE 배치 목록(읽은 차례 = 움직이는 차례, M3 A6).
func foe_list() -> Array[FoeSpawn]:
	var out: Array[FoeSpawn] = []
	for id in foes:
		out.append(foes[id])
	return out


## FOE 가 설 수 있는 칸(M3 A6, 설계 §4.2): 바닥(.)·피해 바닥(~)이고 시작 칸(마을 문)·계단·예약 구역이 아니다. 얼음·빈 곳은 아니다.
func is_foe_cell(c: Vector2i) -> bool:
	var k := cell_kind(c)
	if k != Cell.FLOOR and k != Cell.DAMAGE:
		return false
	if has_start() and c == start_at:
		return false
	return not stairs.has(c) and not is_reserved(c)


## FOE 가 칸 c 에서 d 쪽으로 한 걸음 갈 수 있는지(M3 A6): 열린 경계(문·지름길·숨은 통로·잠긴 문·일방통행은 늘 막는다)로 FOE 칸에 든다.
## 다른 FOE·파티가 있는지는 보지 않는다(부르는 쪽이 본다).
func foe_step(c: Vector2i, d: int) -> bool:
	return edge_kind(edge_of(c, d)) == Edge.OPEN and is_foe_cell(c + Dir.vec(d))
