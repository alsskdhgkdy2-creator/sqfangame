## 설명 상자(부품 I, ListParts.draw_desc): 굽은 끝 테, 어두운 머리(이름·종류 아이콘, 직업 표), 밝은 몸(줄 넷까지). 장식(누르기는 뒤로).
## look = "tree" 이면 스킬 설명 모양(07 §9.9 E2-d, 원작 I HD 스킬 트리): 둥근 판, 머리에 이름·레벨 탭·「Lv n」 막대, 몸에 줄을 칸으로.
## 소지품·장비는 기본("bag")이고 선택지 없이 부른다(그리기가 E2-b·E2-c 그대로). 그리기 기록은 이 컨트롤의 SheetParts.record.
class_name DescBox
extends Control

## "bag"(소지품·장비) · "tree"(스킬).
var look := "bag"
var title := ""
var icon := ""
var lines: Array[String] = []
## 장비 화면 직업 표 [[글, 낄 수 있는지], …].
var table: Array = []
## 화면별 선택지(ListParts.draw_desc 의 opts: levels·bar·bar_text·per_col·max_cols·line_h·room·accent_first). look 은 위 값을 쓴다.
var opts := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func show_desc(t: String, ic: String, ls: Array[String], tb: Array = [], op: Dictionary = {}) -> void:
	title = t
	icon = ic
	lines = ls
	table = tb
	opts = op
	queue_redraw()


func _draw() -> void:
	SheetParts.begin(self)
	var op := opts
	if look != "bag":
		op = opts.duplicate()
		op["look"] = look
	ListParts.draw_desc(self, Rect2(Vector2.ZERO, size), title, icon, lines, table, op)
