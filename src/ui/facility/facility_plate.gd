## 시설·캠프의 왼쪽 위 문패(원작 시각 다이얼 + 「CAMP」 자리, x 0~190·y 0~100): 탐색 화면 층 문패와 같은 기울어진 판에
## 두 줄(층 이름 · 걸음). 둘째 줄이 비면 첫 줄을 세로 가운데에 쓴다(상점 이름 문패, 08 §8.3). 장식이라 누르기를 받지 않는다.
class_name FacilityPlate
extends Control

const SIZE := Vector2(182, 76)
const TOP := 12.0

var first := ""
var second := ""
## 마지막으로 그린 줄마다 글자 크기(시험): 줄 폭에 안 들면 줄인다(fit_size).
var drawn_sizes: Array[int] = []

## 글 줄 왼쪽 여백과 오른쪽까지 뺄 폭(줄 폭 = 판 폭 − TEXT_INSET).
const TEXT_X := 20.0
const TEXT_INSET := 32.0
## 줄일 때 가장 작은 글자 크기.
const MIN_FS := 14


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
	var tw := size.x - TEXT_INSET
	drawn_sizes = []
	for i in 2:
		var t := first if i == 0 else second
		if second.is_empty() and i == 1:
			break
		var fs := fit_size(font, t, 22 if i == 0 else 18, tw)
		var y := 32.0 if i == 0 else 62.0
		if second.is_empty():
			y = size.y / 2.0 + fs * 0.36
		drawn_sizes.append(fs)
		draw_string_outline(font, Vector2(TEXT_X, y), t, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, 6, Color.BLACK)
		draw_string(font, Vector2(TEXT_X, y), t, HORIZONTAL_ALIGNMENT_LEFT, tw, fs, UiTheme.TEXT)


## 글 t 가 폭 width 에 들 때까지 크기 fs 를 1씩 줄인다(MIN_FS 까지). 이미 들면 fs 그대로(예: 걸음 999999999 는 22 → 20).
static func fit_size(font: Font, t: String, fs: int, width: float) -> int:
	while fs > MIN_FS and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs
