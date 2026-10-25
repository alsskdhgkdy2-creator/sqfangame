## 굽은 끝 목록 창(부품 H, ListParts): 테와 스크롤 막대를 그리고, 안의 줄 자리에 끌어 내리는 영역(PartyScroll)을 둔다.
## 줄(ListButton 등)은 list.content 에 내용 좌표로 둔다(row_rect). 테는 장식(누르기는 뒤로), 줄 자리는 목록이 받는다(끌기·휠).
## 그리기 기록은 이 컨트롤의 SheetParts.record(테·막대), 줄의 기록은 줄마다.
class_name ListWindow
extends Control

var list: PartyScroll


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	list = PartyScroll.new()
	list.name = "List"
	add_child(list)
	list.scrolled.connect(queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var rr := ListParts.rows_rect(Rect2(Vector2.ZERO, size))
		list.position = rr.position
		list.size = rr.size
		queue_redraw()


## 줄 k 의 자리(내용 좌표, 목록 폭 전체).
func row_rect(k: int) -> Rect2:
	return Rect2(0, k * (ListParts.ROW_H + ListParts.ROW_GAP), list.size.x, ListParts.ROW_H)


## 줄 n 개의 내용 높이.
static func content_height(n: int) -> float:
	return n * ListParts.ROW_H + maxi(0, n - 1) * ListParts.ROW_GAP


func _draw() -> void:
	SheetParts.begin(self)
	ListParts.draw_list_window(self, Rect2(Vector2.ZERO, size), list.scroll, list.content_height)
