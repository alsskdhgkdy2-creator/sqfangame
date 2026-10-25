## 시설·캠프의 명령 목록(M2.7 R2, 원작 HD jp_facility_img1·gs2_653235·gs2_653222): 화면 왼쪽 가장자리에 붙은 거의 검은 뒤판 위에
## 줄을 세로로 쌓고, 목록 전체의 오른쪽 가장자리는 오른쪽으로 볼록한 원호다(전투 명령 목록 CommandPanel 과 같은 원호, 줄은 ListRow).
## 줄 모양은 「fac:*」: 전투 「cmd:*」(청록 줄·노랑 커서·고른 명령 밝은 시안)에 평소 줄 글자만 원작 시설의 물빛(UiTheme.FAC_TEXT).
## 줄 높이 64(원작 약 50, 누르는 칸 64 이상).
## 놓는 쪽이 왼쪽 위와 크기(WIDTH × content_height)를 앵커로 정한다. 누르기는 pressed(줄 번호) 하나로 보낸다.
## 줄 사이(row_gap)·안쪽 여백(inner_pad)은 놓는 쪽이 바꿀 수 있다(상점 뿌리 4·4, 08 §8.3). 기본값은 캠프(6·6)다.
class_name FacilityList
extends Control

signal pressed(index: int)

const WIDTH := 430.0
const ROW_H := 64.0
const GAP := 6.0
const PAD := 6.0
## 원호가 줄 위·아래 끝보다 가운데에서 더 나오는 폭, 줄 끝과 뒤판 테두리 사이.
const BULGE := 40.0
const RIM := 10.0

var rows: Array[ListRow] = []
## 줄 사이·안쪽 여백(content_height 에 같은 값을 준다).
var row_gap := GAP
var inner_pad := PAD


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP  # 줄 사이·뒤판을 누르면 목록이 받는다(뒤 층으로 새지 않는다)
	focus_mode = FOCUS_NONE


## 줄 n 개의 목록 높이(줄 사이 gap, 안쪽 여백 pad).
static func content_height(n: int, gap: float = GAP, pad: float = PAD) -> float:
	return 2.0 * pad + n * ROW_H + maxf(0.0, n - 1.0) * gap


## 줄을 만든다(items: [{name, text}]). 이미 있으면 글자만 바꾼다.
func set_items(items: Array) -> void:
	while rows.size() < items.size():
		var b := ListRow.new()
		b.curve = self
		b.skin = "fac"
		b.size = Vector2(100, ROW_H)
		var idx := rows.size()
		b.activated.connect(func() -> void: pressed.emit(idx))
		add_child(b)
		rows.append(b)
	for i in rows.size():
		rows[i].visible = i < items.size()
		if i < items.size():
			rows[i].name = str(items[i]["name"])
			rows[i].text = str(items[i]["text"])
	_layout()


## 줄 모양: cursor 줄은 노랑, chosen 줄은 「고른」 시안, live[i] 가 거짓인 줄은 누르기를 받지 않는다(그림은 그대로).
## dim[i] 가 참인 줄은 흐리다(누르기는 받는다: 상점 뿌리의 대화·장비 바꾸기는 눌러 이유를 본다).
func show_rows(cursor: int, chosen: int, live: Array, dim: Array = []) -> void:
	for i in rows.size():
		var b := rows[i]
		b.selected = i == cursor
		b.chosen = i == chosen
		b.dimmed = dim[i] if i < dim.size() else false
		var on: bool = live[i] if i < live.size() else true
		b.mouse_filter = MOUSE_FILTER_STOP if on else MOUSE_FILTER_IGNORE
		if not on:
			b.cancel()
		b.queue_redraw()


func set_row_text(i: int, t: String) -> void:
	if i >= 0 and i < rows.size() and rows[i].text != t:
		rows[i].text = t
		rows[i].queue_redraw()


func cancel() -> void:
	for b in rows:
		b.cancel()


func row_y(i: int) -> float:
	return inner_pad + i * (ROW_H + row_gap)


## 목록 기준 y 에서 오른쪽 가장자리 x(원호: 가운데 높이에서 가장 오른쪽, 위·아래 끝은 BULGE 만큼 안쪽).
func arc_x(y: float) -> float:
	var h := maxf(1.0, size.y)
	var r := (h * h / 4.0 + BULGE * BULGE) / (2.0 * BULGE)
	var cx := size.x - RIM - r
	var dy := clampf(y - h / 2.0, -h / 2.0, h / 2.0)
	return cx + sqrt(maxf(0.0, r * r - dy * dy))


func _layout() -> void:
	for i in rows.size():
		var y := row_y(i)
		rows[i].position = Vector2(inner_pad, y)
		rows[i].size = Vector2(maxf(arc_x(y), arc_x(y + ROW_H)) - inner_pad, ROW_H)
		rows[i].queue_redraw()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## 뒤판: 왼쪽은 화면 가장자리에 붙어 곧고, 오른쪽은 원호(줄 끝보다 RIM 바깥).
func plate_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0)])
	var n := 24
	for k in n + 1:
		var y := size.y * k / n
		pts.append(Vector2(arc_x(y) + RIM - 2.0, y))
	pts.append(Vector2(0, size.y))
	return pts


func _draw() -> void:
	var pts := plate_polygon()
	draw_colored_polygon(pts, UiTheme.FAC_PLATE)
	var line := pts.duplicate()
	line.remove_at(0)
	draw_polyline(line, UiTheme.FAC_PLATE_EDGE, 3.0, true)
	draw_line(Vector2(0, 1.5), pts[1] + Vector2(0, 1.5), UiTheme.FAC_PLATE_EDGE, 3.0)
	draw_line(Vector2(0, size.y - 1.5), pts[pts.size() - 2] - Vector2(0, 1.5), UiTheme.FAC_PLATE_EDGE, 3.0)
