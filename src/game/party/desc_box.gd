## 설명 상자(부품 I, ListParts.draw_desc): 굽은 끝 테, 어두운 머리(이름·종류 아이콘, 직업 표), 밝은 몸(줄 넷까지). 장식(누르기는 뒤로).
## 그리기 기록은 이 컨트롤의 SheetParts.record.
class_name DescBox
extends Control

var title := ""
var icon := ""
var lines: Array[String] = []
## 장비 화면 직업 표 [[글, 낄 수 있는지], …].
var table: Array = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func show_desc(t: String, ic: String, ls: Array[String], tb: Array = []) -> void:
	title = t
	icon = ic
	lines = ls
	table = tb
	queue_redraw()


func _draw() -> void:
	SheetParts.begin(self)
	ListParts.draw_desc(self, Rect2(Vector2.ZERO, size), title, icon, lines, table)
