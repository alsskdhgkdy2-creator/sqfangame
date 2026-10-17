## 지도 패널의 좌표 변환과 고르기(노드 없음). 지도 좌표 1 = 칸 한 변, (0,0) = 칸 (0,0)의 북서 모서리.
## 화면 = origin + 지도 × cell_px.
class_name MapGeometry
extends RefCounted

const MIN_CELL_PX := 10.0
const MAX_CELL_PX := 72.0
## 경계 고르기: 칸 한 변의 이 비율 안이면 경계(05 §7.2).
const EDGE_PICK := 0.25

var width := 1
var height := 1
var cell_px := 22.0
var origin := Vector2.ZERO


func _init(w: int = 1, h: int = 1) -> void:
	width = w
	height = h


func to_map(screen: Vector2) -> Vector2:
	return (screen - origin) / cell_px


func to_screen(map: Vector2) -> Vector2:
	return origin + map * cell_px


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(to_screen(Vector2(c)), Vector2(cell_px, cell_px))


## 화면 점이 있는 칸. 판 밖이면 GridKey.BAD_CELL.
func pick_cell(screen: Vector2) -> Vector2i:
	var m := to_map(screen)
	var c := Vector2i(floori(m.x), floori(m.y))
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return GridKey.BAD_CELL
	return c


## 화면 점에서 가장 가까운 경계가 칸 한 변의 25% 안이면 그 경계. 아니면 GridKey.BAD_EDGE.
func pick_edge(screen: Vector2) -> Vector3i:
	var m := to_map(screen)
	var cx := floori(m.x)
	var cy := floori(m.y)
	var lx := m.x - cx
	var ly := m.y - cy
	var dists := [ly, 1.0 - ly, lx, 1.0 - lx]  # 북·남·서·동
	var best := 0
	for i in 4:
		if dists[i] < dists[best]:
			best = i
	if dists[best] > EDGE_PICK:
		return GridKey.BAD_EDGE
	var e: Vector3i
	match best:
		0:
			e = Vector3i(cx, cy, 0)
		1:
			e = Vector3i(cx, cy + 1, 0)
		2:
			e = Vector3i(cx, cy, 1)
		_:
			e = Vector3i(cx + 1, cy, 1)
	if not edge_in_range(e):
		return GridKey.BAD_EDGE
	return e


func edge_in_range(e: Vector3i) -> bool:
	if e.z == 0:
		return e.x >= 0 and e.x < width and e.y >= 0 and e.y <= height
	return e.z == 1 and e.x >= 0 and e.x <= width and e.y >= 0 and e.y < height


## 경계의 화면 위 양 끝점.
func edge_segment(e: Vector3i) -> Array[Vector2]:
	if e.z == 0:
		return [to_screen(Vector2(e.x, e.y)), to_screen(Vector2(e.x + 1, e.y))]
	return [to_screen(Vector2(e.x, e.y)), to_screen(Vector2(e.x, e.y + 1))]


## 화면 점 pivot 아래의 지도 위치를 그대로 두고 확대·축소한다.
func zoom_at(pivot: Vector2, factor: float) -> void:
	var before := to_map(pivot)
	cell_px = clampf(cell_px * factor, MIN_CELL_PX, MAX_CELL_PX)
	origin = pivot - before * cell_px


func pan(delta: Vector2) -> void:
	origin += delta


## 지도 위치 map 이 화면 점 at 에 오게 한다.
func center_on(map: Vector2, at: Vector2) -> void:
	origin = at - map * cell_px
