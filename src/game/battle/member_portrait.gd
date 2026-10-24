## 지금 명령을 고르는 대원의 초상과 그 아래 TP 게이지(M2.7 R3: 원작 HD 1868180_0e36b17e 왼쪽 초상 + BOOST 게이지 자리).
## 그림이 아직 없어(M3) 직업색 판에 이름 첫 글자를 크게 쓰고 아래 띠에 이름을 둔다. 게이지 자리에는 원작의 BOOST 대신
## 그 대원의 TP(「TP」 + 시안 막대 + 수치)를 보인다. 장식이라 누르기를 받지 않는다(명령 목록이 오른쪽 끝을 덮는다).
class_name MemberPortrait
extends Control

## 초상 칸(이 컨트롤 기준)과 그 아래 게이지 칸. 전체 크기 = SIZE.
const PORTRAIT := Rect2(0, 0, 180, 359)
const GAUGE := Rect2(0, 363, 267, 34)
const SIZE := Vector2(267, 397)
const INITIAL_FS := 120
const NAME_FS := 20
const GAUGE_FS := 18

var unit_name := ""
var class_color := Color(0.7, 0.7, 0.7)
var tp := 0
var max_tp := 0


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = SIZE


func show_member(n: String, cc: Color, tp_now: int, tp_max: int) -> void:
	unit_name = n
	class_color = cc
	tp = tp_now
	max_tp = tp_max
	visible = true
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var p := PORTRAIT
	# 틀 + 직업색 판(위 밝게 → 아래 어둡게).
	draw_rect(p, UiTheme.CMD_PLATE)
	var inner := p.grow(-4.0)
	var top := class_color.darkened(0.35)
	var bottom := class_color.darkened(0.75)
	draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	draw_rect(p.grow(-1.5), UiTheme.CMD_PLATE_EDGE, false, 3.0)
	var initial := unit_name.left(1)
	draw_string(font, Vector2(inner.position.x, inner.get_center().y + INITIAL_FS * 0.3), initial, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x,
		INITIAL_FS, Color(1, 1, 1, 0.85))
	var band := Rect2(inner.position.x, inner.end.y - 36.0, inner.size.x, 36.0)
	draw_rect(band, UiTheme.CMD_PLATE)
	draw_string(font, Vector2(band.position.x + 10.0, band.get_center().y + NAME_FS * 0.36), unit_name, HORIZONTAL_ALIGNMENT_LEFT,
		band.size.x - 20.0, NAME_FS, UiTheme.CARD_TEXT)
	# TP 게이지(원작 BOOST 줄 자리): 어두운 판, 「TP」, 시안 막대, 수치.
	var g := GAUGE
	draw_rect(g, UiTheme.HINT_PILL)
	draw_rect(g.grow(-1.0), UiTheme.CMD_PLATE_EDGE, false, 2.0)
	var base := g.get_center().y + GAUGE_FS * 0.36
	draw_string(font, Vector2(g.position.x + 10.0, base), "TP", HORIZONTAL_ALIGNMENT_LEFT, -1, GAUGE_FS, UiTheme.BATTLE_BANNER_TEXT)
	var val := "%d/%d" % [tp, max_tp]
	var vw := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, GAUGE_FS).x
	draw_string(font, Vector2(g.end.x - 10.0 - vw, base), val, HORIZONTAL_ALIGNMENT_LEFT, -1, GAUGE_FS, UiTheme.BATTLE_BANNER_TEXT)
	var bar := Rect2(g.position.x + 44.0, g.get_center().y - 4.0, g.size.x - 44.0 - 20.0 - vw, 8.0)
	UiTheme.draw_gauge(self, bar, float(tp) / maxf(1.0, float(max_tp)), UiTheme.CARD_TP, UiTheme.CARD_TP)
