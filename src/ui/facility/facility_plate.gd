## 시설·캠프의 왼쪽 위 문패(원작 시각 다이얼 + 「CAMP」 자리, x 0~190·y 0~100): 탐색 화면 층 문패와 같은 기울어진 판에
## 두 줄(층 이름 · 걸음). 장식이라 누르기를 받지 않는다.
class_name FacilityPlate
extends Control

const SIZE := Vector2(182, 76)
const TOP := 12.0

var first := ""
var second := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = TOP
	offset_right = SIZE.x
	offset_bottom = TOP + SIZE.y


func show_lines(a: String, b: String) -> void:
	first = a
	second = b
	queue_redraw()


func _draw() -> void:
	UiTheme.draw_plate(self, Rect2(Vector2(-UiTheme.PLATE_SLANT, 0), size + Vector2(UiTheme.PLATE_SLANT, 0)), "", 1)
	var font := get_theme_default_font()
	for i in 2:
		var t := first if i == 0 else second
		var fs := 22 if i == 0 else 18
		var y := 32.0 if i == 0 else 62.0
		draw_string_outline(font, Vector2(20, y), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, fs, 6, Color.BLACK)
		draw_string(font, Vector2(20, y), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, fs, UiTheme.TEXT)
