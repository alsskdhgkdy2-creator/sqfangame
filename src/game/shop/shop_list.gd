## 상점 칸 목록(08 §7.4, 원작 HD 상점 jp_guide3_img1·2): 끌어 내리는 영역(PartyScroll) 안에 ShopRow 줄(64, 사이 4)을 두고,
## 목록 창에 보이는 줄 수만큼 칸을 채운다(남는 칸은 어두운 빈 줄 + 빈 아이콘 칸, 장식이라 누르기를 받지 않는다).
## 줄이 넘치면 오른쪽에 가는 위치 막대(BattleLogView.scroll_bar_rect 와 같은 그림). 막대 자리는 늘 비워 둬서 줄 폭이 바뀌지 않는다.
## 커서 줄 하나만 노랑(selected)이다. 줄을 누르면(뗄 때) 커서를 그 줄로 옮기고 picked 를 낸다. 끌기는 고르기가 아니다(PartyButton).
## cursor_mode 로 커서 줄 모양을 바꾼다(노랑은 화면에 하나, 07 §9.2): 창이 그 줄에 대해 떠 있으면 「chosen」(밝은 시안), 여러 줄
## 팔기 확인처럼 줄 하나에 대한 창이 아니면 「none」, 창이 닫히면 「cursor」. 바꾸는 쪽은 화면(S3)이다.
## set_rows 가 다른 줄을 놓으면 눌려 있던 줄·끌기를 버린다(같은 줄을 다시 놓으면 아무것도 바꾸지 않는다).
class_name ShopList
extends Control

signal picked(index: int)

const ROW_H := 64.0
const ROW_GAP := 4.0
const PITCH := ROW_H + ROW_GAP
const BAR_W := 4.0
const BAR_GAP := 4.0

var scroll: PartyScroll
## 쓰는 줄(앞 row_count 개가 보인다).
var rows: Array[ShopRow] = []
var row_count := 0
var cursor := 0
var new_text := "NEW"
## "cursor"(커서 줄 노랑) · "chosen"(커서 줄 밝은 시안, 노랑은 창 단추) · "none"(커서 줄 표시 없음, 커서 자리는 그대로).
var cursor_mode := "cursor"
var _empties: Control
## 지금 보이는 줄 자료(set_rows 가 같은 자료면 아무것도 하지 않는다).
var _data: Array = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	scroll = PartyScroll.new()
	scroll.name = "Scroll"
	add_child(scroll)
	_empties = Control.new()
	_empties.name = "Empties"
	_empties.mouse_filter = MOUSE_FILTER_IGNORE
	_empties.draw.connect(_draw_empties)
	scroll.content.add_child(_empties)
	scroll.content.item_rect_changed.connect(queue_redraw)  # 내리면 위치 막대를 다시 그린다


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## 줄 폭(위치 막대 자리를 뺀 끌어 내리는 영역 폭).
func row_width() -> float:
	return maxf(0.0, size.x - BAR_W - BAR_GAP)


func _layout() -> void:
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(row_width(), size.y)
	for i in rows.size():
		rows[i].position = Vector2(0, i * PITCH)
		rows[i].size = Vector2(row_width(), ROW_H)
	_empties.position = Vector2.ZERO
	_empties.size = Vector2(row_width(), maxf(size.y, row_count * PITCH))
	scroll.set_content_height(maxf(0.0, row_count * PITCH - ROW_GAP))
	_show_cursor()
	_empties.queue_redraw()
	queue_redraw()


## 줄마다 {icon, name, new, right, count, dim, checked}. 커서는 줄 수 안으로 맞춘다.
func set_rows(data: Array) -> void:
	if data == _data and row_count == data.size():
		return
	cancel()  # 다른 줄이 놓인다: 눌려 있던 줄·끌기가 새 줄을 고르거나 내리지 않게(07 §9.4)
	_data = data.duplicate(true)
	row_count = data.size()
	while rows.size() < row_count:
		var r := ShopRow.new()
		var k := rows.size()
		r.name = "Row_%d" % k
		r.scroller = scroll
		r.activated.connect(func() -> void: _on_row(k))
		scroll.content.add_child(r)
		rows.append(r)
	for i in rows.size():
		var r := rows[i]
		r.visible = i < row_count
		if i >= row_count:
			r.cancel()
			continue
		var d: Dictionary = data[i]
		r.kind_icon = str(d.get("icon", ""))
		r.text = str(d.get("name", ""))
		r.is_new = bool(d.get("new", false))
		r.new_text = new_text
		r.right = str(d.get("right", ""))
		r.count = str(d.get("count", ""))
		r.dimmed = bool(d.get("dim", false))
		r.checked = bool(d.get("checked", false))
		r.queue_redraw()
	cursor = clampi(cursor, 0, maxi(0, row_count - 1))
	_layout()


## 커서를 줄 i 로(줄 수 안으로 맞추고, 그 줄이 보이게 내린다).
func set_cursor(i: int) -> void:
	cursor = clampi(i, 0, maxi(0, row_count - 1))
	_show_cursor()


## 커서 줄 모양을 바꾼다(커서 자리·내림은 그대로).
func set_cursor_mode(m: String) -> void:
	cursor_mode = m
	_mark_cursor()


func _mark_cursor() -> void:
	for i in rows.size():
		var at := i < row_count and i == cursor
		rows[i].selected = at and cursor_mode == "cursor"
		rows[i].chosen = at and cursor_mode == "chosen"


func _show_cursor() -> void:
	_mark_cursor()
	if row_count > 0:
		scroll.ensure_visible(cursor * PITCH, cursor * PITCH + ROW_H)


func _on_row(i: int) -> void:
	if i >= row_count:
		return
	set_cursor(i)
	picked.emit(i)


## 눌려 있던 포인터를 모두 버린다(문맥이 바뀔 때, 07 §9.4).
func cancel() -> void:
	scroll.cancel()
	for r in rows:
		r.cancel()


## 목록 창에 보이는 줄 수(다 들어가는 줄만).
func visible_slots() -> int:
	return maxi(1, int(floor((size.y + ROW_GAP) / PITCH)))


## 그리는 빈 칸 수.
func empty_count() -> int:
	return maxi(0, visible_slots() - row_count)


## 칸 i(줄·빈 칸 공통)의 사각형(끌어 내리는 내용 좌표).
func slot_rect(i: int) -> Rect2:
	return Rect2(0, i * PITCH, row_width(), ROW_H)


func _draw_empties() -> void:
	for k in empty_count():
		var r := slot_rect(row_count + k)
		var cell := Rect2(r.position, Vector2(ROW_H, ROW_H))
		_empties.draw_rect(cell, UiTheme.SHOP_ICON_CELL)
		UiTheme.draw_outline(_empties, cell, UiTheme.SHOP_ICON_EDGE, 1.5, 0.0)
		var bar := Rect2(r.position.x + ROW_H + ShopRow.ICON_GAP, r.position.y, r.size.x - ROW_H - ShopRow.ICON_GAP, ROW_H)
		_empties.draw_colored_polygon(UiTheme.chamfer_points(bar, UiTheme.BTN_CHAMFER), UiTheme.SHOP_EMPTY_ROW)
		UiTheme.draw_outline(_empties, bar, UiTheme.SHOP_ICON_EDGE, 1.0)


## 위치 막대(이 목록 기준). 넘치지 않으면 빈 Rect2.
func scroll_bar_rect() -> Rect2:
	var m := scroll.max_scroll()
	if m <= 0.0:
		return Rect2()
	var view := scroll.size.y
	var h := maxf(24.0, view * view / (view + m))
	var y := (view - h) * (scroll.scroll / m)
	return Rect2(size.x - BAR_W, y, BAR_W, h)


func _draw() -> void:
	var bar := scroll_bar_rect()
	if bar.has_area():
		draw_rect(Rect2(bar.position.x, 0, BAR_W, scroll.size.y), Color(1, 1, 1, 0.12))
		draw_rect(bar, Color(0.75, 0.92, 1.0, 0.85))
