## 목록 창 줄(부품 H)과 명령 알약(부품 J): PartyButton 의 입력(손가락 소유, 뗄 때 한 번, scroller 가 있으면 끌기 = 내리기)을
## 그대로 쓰고 그림만 ListParts 로 그린다(그리는 호출이 이 단추의 SheetParts.record 에 남는다).
## 줄: icon_name(종류 아이콘)·text·right(개수)·selected(노랑 커서 줄)·dim·equipped(「E」). 알약(pill): text·selected·checked.
class_name ListButton
extends PartyButton

## "row" · "pill"
var style := "row"
var icon_name := ""
var equipped := false:
	set(v):
		equipped = v
		queue_redraw()


func _init() -> void:
	super._init()
	align_left = true


func _draw() -> void:
	SheetParts.begin(self)
	var r := Rect2(Vector2.ZERO, size)
	if style == "pill":
		ListParts.draw_pill(self, r, text, pill_state())
	else:
		ListParts.draw_row(self, r, icon_name, text, right, selected, dimmed, equipped, held)


## 알약 모양 상태(커서가 켜짐보다 먼저).
func pill_state() -> String:
	if selected:
		return "selected_pressed" if held else "selected"
	if checked:
		return "checked_pressed" if held else "checked"
	return "pressed" if held else "normal"


## 그릴 글과 그 폭(시험이 잘림을 본다: 그리는 크기·자리와 같다).
func text_parts() -> Dictionary:
	var out := {}
	var r := Rect2(Vector2.ZERO, size)
	if style == "pill":
		out["main"] = [text, ListParts.PILL_FS, size.x - size.y]
		return out
	out["main"] = [text, ListParts.ROW_FS, ListParts.name_room(self, r, right, equipped)]
	if not right.is_empty():
		var body: Rect2 = ListParts.row_boxes(r)["body"]
		out["right"] = [right, ListParts.COUNT_FS, ListParts.right_edge(r, equipped) - body.position.x - ListParts.TEXT_PAD]
	return out
