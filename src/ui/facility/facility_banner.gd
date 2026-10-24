## 시설·캠프의 위 설명 띠(M2.7 R2, 원작 HD gs2_653222·653235·jp_facility_img1): 다이얼 자리 오른쪽(x 192)부터 화면 오른쪽 끝까지,
## 높이 100. 짙은 청록 그라데이션, 왼쪽 아래 모서리를 깎고 아래에 어두운 선. 두 줄: 첫 줄 = 설명·물음(큰 밝은 글자),
## 둘째 줄 = 설명 둘째 줄 또는 안내(notice 면 따뜻한 글자). 장식이라 누르기를 받지 않는다. 자리는 놓는 쪽이 앵커로 정한다(place).
class_name FacilityBanner
extends Control

const X := 192.0
const H := 100.0
const FS := 30
const SUB_FS := 22
const PAD := 34.0
const CUT := 28.0

var head := ""
var body := ""
## body 가 안내(거부 이유 등)인지.
var notice := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## 띠를 놓는다: 왼쪽 위(X, 0) ~ 오른쪽 끝, 높이 H(앵커: 위 넓게).
func place() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = X
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = H


func show_lines(first: String, second: String = "", is_notice: bool = false) -> void:
	if first == head and second == body and is_notice == notice:
		return
	head = first
	body = second
	notice = is_notice
	queue_redraw()


func lines() -> Array:
	return [head, body, notice]


func _draw() -> void:
	var b := Rect2(Vector2.ZERO, size)
	var pts := PackedVector2Array([b.position, Vector2(b.end.x, 0), b.end, Vector2(CUT, b.end.y), Vector2(0, b.end.y - CUT)])
	var cols := PackedColorArray()
	for p in pts:
		cols.append(UiTheme.FAC_BANNER_TOP.lerp(UiTheme.FAC_BANNER_BOTTOM, p.y / maxf(1.0, b.size.y)))
	draw_polygon(pts, cols)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, UiTheme.FAC_BANNER_EDGE, 3.0, true)
	var font := get_theme_default_font()
	var tw := b.size.x - 2.0 * PAD
	var head_y := 44.0 if not body.is_empty() else b.get_center().y + FS * 0.36
	draw_string(font, Vector2(PAD, head_y), head, HORIZONTAL_ALIGNMENT_LEFT, tw, FS, UiTheme.BATTLE_BANNER_TEXT)
	if not body.is_empty():
		draw_string(font, Vector2(PAD, 82.0), body, HORIZONTAL_ALIGNMENT_LEFT, tw, SUB_FS,
			UiTheme.BATTLE_BANNER_NOTICE if notice else UiTheme.BATTLE_BANNER_TEXT)
