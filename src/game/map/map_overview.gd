## 읽기 전용 지도(플레이어 지도 그림: 표시·자동 지도·파티 화살표). 누르기를 받지 않는다(MOUSE_FILTER_IGNORE).
## - 층 전체 보기(is_mini = false): 지도 판 위쪽(원작 HD guide4·nin_02). 층 전체를 맞춰 넣고, 위에 구역 번호(1, 2, 3…),
##   왼쪽에 구역 글자(A, B, C…)의 자를 둔다. 구역은 GRID_MAJOR(5)×5 칸이고 밝은 5칸 모눈 선과 맞는다.
##   그리기 격자(source)가 보이는 범위를 가는 청록 사각형으로 그린다(nin_02). 모눈은 그리기 격자보다 흐리다.
## - 미니맵(is_mini = true): 탐색 화면 오른쪽 위의 작은 반투명 지도(원작 III HD gw_28). 파티 둘레, 북쪽이 위, 가는 테두리.
class_name MapOverview
extends MapPanel

## 자 띠 두께(위 띠 높이 = 왼쪽 띠 폭).
const RULER := 22.0
const RULER_FS := 14
const RULER_BG := Color("00d093")
const RULER_LINE := Color("01274b")
const RULER_TEXT := Color("01274b")
## 그리기 격자가 보이는 범위(가는 실선).
const VIEW_RECT := Color("1db5cc")
## 층 전체 보기 모눈 진하기, 미니맵 테두리.
const OVERVIEW_GRID_ALPHA := 0.5
const MINI_FRAME := Color("94ebf4")
## 미니맵 칸 크기와 불투명도.
const MINI_CELL := 26.0
const MINI_ALPHA := 0.78

var is_mini := false
## 보이는 범위를 그릴 그리기 격자(층 전체 보기만).
var source: MapPanel


func _init() -> void:
	super()  # MapPanel._init: clip_contents(모눈·칸이 틀 밖으로 그려지지 않는다). GDScript 는 부모 _init 을 저절로 부르지 않는다.
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(as_mini: bool, src: MapPanel = null) -> MapOverview:
	is_mini = as_mini
	source = src
	if is_mini:
		modulate.a = MINI_ALPHA
	else:
		grid_alpha = OVERVIEW_GRID_ALPHA
	if source != null:
		source.view_changed.connect(queue_redraw)  # 보이는 범위 사각형(표시가 바뀌면 탐색 화면이 다시 그리게 한다)
	return self


func refresh() -> void:
	if state == null:
		queue_redraw()
		return
	if is_mini:
		geo.cell_px = MINI_CELL
		geo.center_on(Vector2(state.party.at) + Vector2(0.5, 0.5), size / 2.0)
	else:
		var area := map_area()
		var px := floorf(minf(area.size.x / geo.width, area.size.y / geo.height))
		geo.cell_px = maxf(1.0, px)
		var used := Vector2(geo.width, geo.height) * geo.cell_px
		geo.origin = (area.position + (area.size - used) / 2.0).floor()
	queue_redraw()


## 지도를 그리는 영역(층 전체 보기는 자 띠를 뺀 곳).
func map_area() -> Rect2:
	if is_mini:
		return Rect2(Vector2.ZERO, size)
	return Rect2(Vector2(RULER, RULER), size - Vector2(RULER, RULER) - Vector2(4, 4))


## 마지막으로 그린 지도 표시(시험·디버그: 다시 그렸는지와 그린 내용). {"version", "icons", "memos", "edges", "floors", "count"}.
var drawn := {"count": 0}


func _draw() -> void:
	super._draw()
	if state != null:
		var a := state.annotation
		drawn = {"count": int(drawn["count"]) + 1, "version": a.version, "icons": a.icons.size(), "memos": a.memos.size(),
			"edges": a.edges.size(), "floors": a.floors.size()}
	if is_mini:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), MINI_FRAME, false, 2.0)
		return
	if state == null:
		return
	_draw_view_rect()
	_draw_ruler()


## 구역 자: [{index, text, rect}]. 가로(vertical = false)는 번호 1, 2, 3…, 세로는 글자 A, B, C…. rect 는 그 구역의 자 칸.
func sector_labels(vertical: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := geo.height if vertical else geo.width
	for i in ceili(float(n) / GRID_MAJOR):
		var a := i * GRID_MAJOR
		var b := mini(n, a + GRID_MAJOR)
		var r: Rect2
		if vertical:
			var y0 := geo.to_screen(Vector2(0, a)).y
			var y1 := geo.to_screen(Vector2(0, b)).y
			r = Rect2(0, y0, RULER, y1 - y0)
		else:
			var x0 := geo.to_screen(Vector2(a, 0)).x
			var x1 := geo.to_screen(Vector2(b, 0)).x
			r = Rect2(x0, 0, x1 - x0, RULER)
		out.append({"index": i, "text": sector_name(i, vertical), "rect": r})
	return out


## 구역 이름: 가로 0 → 「1」, 세로 0 → 「A」(26 넘으면 AA…).
static func sector_name(i: int, vertical: bool) -> String:
	if not vertical:
		return str(i + 1)
	var out := ""
	var n := i
	while true:
		out = char(65 + n % 26) + out
		n = n / 26 - 1
		if n < 0:
			break
	return out


func _draw_ruler() -> void:
	var font := get_theme_default_font()
	for vertical in [false, true]:
		for l in sector_labels(vertical):
			var r: Rect2 = l["rect"]
			draw_rect(r.grow(-1.0), RULER_BG)
			draw_rect(r.grow(-1.0), RULER_LINE, false, 1.0)
			draw_string(font, Vector2(r.position.x, r.get_center().y + RULER_FS * 0.36), l["text"], HORIZONTAL_ALIGNMENT_CENTER,
				r.size.x, RULER_FS, RULER_TEXT)


## 그리기 격자가 보이는 범위(이 지도 좌표의 사각형). 그리기 격자가 없으면 빈 사각형.
func view_rect() -> Rect2:
	if source == null or source.size.x <= 0.0:
		return Rect2()
	var a := geo.to_screen(source.geo.to_map(Vector2.ZERO))
	var b := geo.to_screen(source.geo.to_map(source.size))
	return Rect2(a, b - a)


func _draw_view_rect() -> void:
	var r := view_rect().intersection(map_area())
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_rect(r.grow(-1.0), VIEW_RECT, false, 2.0)
