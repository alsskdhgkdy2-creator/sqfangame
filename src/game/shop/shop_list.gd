## 상점 칸 목록의 틀(08 §7.4, 원작 HD 상점 jp_guide3_img1·2): 끌어 내리는 영역(PartyScroll) 하나를 두고, 그 안의 줄은 공용 목록(InventoryList,
## D28-b)이 ShopRowLook 모양(ShopRow 줄 64, 사이 4)으로 놓는다. 틀이 맡는 것: 영역 크기(오른쪽 위치 막대 자리를 늘 비워 둬서 줄 폭이
## 바뀌지 않는다), 목록 창에 보이는 줄 수만큼 남는 칸(어두운 빈 줄 + 빈 아이콘 칸, 장식이라 누르기를 받지 않는다), 줄이 넘치면 가는 위치 막대
## (BattleLogView.scroll_bar_rect 와 같은 그림).
## 공용 목록이 맡는 것: 줄 단추(Row_k)·커서(노랑 하나, 칸이 없으면 -1)·커서 모양·route·picked·끌기와 눌림 버림·끝에서 가려진 커서 되돌림.
## route 가 있으면 줄 누르기는 route(i) 만 부른다(커서도 picked 도 그대로): 입력을 받을지 정하는 화면(S3)이 받은 뒤 커서를 옮긴다.
## cursor_mode 로 커서 줄 모양을 바꾼다(노랑은 화면에 하나, 07 §9.2): 창이 그 줄에 대해 떠 있으면 「chosen」(밝은 시안), 여러 줄
## 팔기 확인처럼 줄 하나에 대한 창이 아니면 「none」, 창이 닫히면 「cursor」. 바꾸는 쪽은 화면(S3)이다.
## set_rows 가 다른 줄을 놓으면 눌려 있던 줄·끌기를 버리고 커서 줄을 보이게 한다(reveal_on_change). 같은 줄을 다시 놓으면 아무것도 바꾸지 않는다.
## 아래 rows·cursor·route 등은 공용 목록을 그대로 읽고 쓰는 이름이다(화면·시험·디버그가 쓰던 이름).
class_name ShopList
extends Control

signal picked(index: int)

const ROW_H := 64.0
const ROW_GAP := 4.0
const PITCH := ROW_H + ROW_GAP
const BAR_W := 4.0
const BAR_GAP := 4.0

var scroll: PartyScroll
var look: ShopRowLook
## 공용 목록(D28-b): 줄·커서·내림·되돌림·누르기.
var inv: InventoryList
## 줄 단추(앞 row_count 개가 보인다).
var rows: Array[ShopRow]:
	get:
		var out: Array[ShopRow] = []
		out.assign(inv.rows)
		return out
var row_count: int:
	get:
		return inv.used
## 커서 줄. 줄이 없으면 -1.
var cursor: int:
	get:
		return inv.cursor
var new_text: String:
	get:
		return look.new_text
	set(v):
		look.new_text = v
## "cursor"(커서 줄 노랑) · "chosen"(커서 줄 밝은 시안, 노랑은 창 단추) · "none"(커서 줄 표시 없음, 커서 자리는 그대로).
var cursor_mode: String:
	get:
		return inv.cursor_mode
## 입력 입구(08 §7.4·§8.11, ShopDialog.route 와 같은 방식). 비어 있으면 S2 그대로.
var route: Callable:
	get:
		return inv.route
	set(v):
		inv.route = v
var _empties: Control


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
	look = ShopRowLook.new()
	inv = InventoryList.new(scroll, look, "Row_")
	inv.reveal_on_change = true  # 진열·값이 바뀌면 커서 줄을 보이게 한다(D28-b ③)
	inv.picked.connect(func(i: int) -> void: picked.emit(i))
	inv.watch_resize(func() -> void: inv.set_rows(inv.data))  # 새 폭으로 줄을 놓고 커서 줄을 한 번 보이게 한다


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## 줄 폭(위치 막대 자리를 뺀 끌어 내리는 영역 폭).
func row_width() -> float:
	return maxf(0.0, size.x - BAR_W - BAR_GAP)


func _layout() -> void:
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(row_width(), size.y)  # 크기가 바뀌면 공용 목록이 줄을 다시 놓는다(watch_resize)
	_frame()


## 틀 그림(빈 칸·위치 막대)을 지금 줄 수에 맞춘다.
func _frame() -> void:
	_empties.position = Vector2.ZERO
	_empties.size = Vector2(row_width(), maxf(size.y, row_count * inv.pitch()))
	_empties.queue_redraw()
	queue_redraw()


## 줄마다 {icon, name, new, right, count, dim, checked}. 커서는 줄 수 안으로 맞춘다.
func set_rows(data: Array) -> void:
	inv.set_rows(data)
	_frame()


## 커서를 줄 i 로(줄 수 안으로 맞추고, 그 줄이 보이게 내린다).
func set_cursor(i: int) -> void:
	inv.set_cursor(i)


## 커서 줄 모양을 바꾼다(커서 자리·내림은 그대로).
func set_cursor_mode(m: String) -> void:
	inv.set_cursor_mode(m)


## 눌려 있던 포인터를 모두 버린다(문맥이 바뀔 때, 07 §9.4).
func cancel() -> void:
	inv.cancel()


## 목록 창에 보이는 줄 수(다 들어가는 줄만).
func visible_slots() -> int:
	return maxi(1, int(floor((size.y + look.gap) / inv.pitch())))


## 그리는 빈 칸 수.
func empty_count() -> int:
	return maxi(0, visible_slots() - row_count)


## 칸 i(줄·빈 칸 공통)의 사각형(끌어 내리는 내용 좌표).
func slot_rect(i: int) -> Rect2:
	return Rect2(0, inv.line_y(i), row_width(), look.row_h)


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
