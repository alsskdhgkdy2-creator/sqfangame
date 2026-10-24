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
	draw_placeholder(self, PORTRAIT, unit_name, class_color, INITIAL_FS, NAME_FS)
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


## 큰 초상 자리표시(그림은 M3, 캠프 상태·장비·소지품): 틀·이름 띠 없이 직업색 머리 + 몸 실루엣(위 짙게 → 아래 옅게)과 큰 첫 글자.
static func draw_silhouette(ci: Control, r: Rect2, cc: Color, initial: String, fs: int) -> void:
	var top := Color(cc.darkened(0.25), 0.9)
	var bottom := Color(cc.darkened(0.7), 0.35)
	var head_c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.2)
	var head_r := r.size.x * 0.17
	ci.draw_circle(head_c, head_r, top)
	var neck_y := head_c.y + head_r * 0.9
	var body := PackedVector2Array([Vector2(head_c.x - head_r * 0.7, neck_y), Vector2(head_c.x + head_r * 0.7, neck_y),
		Vector2(r.end.x - r.size.x * 0.06, neck_y + r.size.y * 0.16), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y),
		Vector2(r.position.x + r.size.x * 0.06, neck_y + r.size.y * 0.16)])
	var cols := PackedColorArray()
	for p in body:
		cols.append(top.lerp(bottom, clampf((p.y - neck_y) / maxf(1.0, r.end.y - neck_y), 0.0, 1.0)))
	ci.draw_polygon(body, cols)
	ci.draw_string(ci.get_theme_default_font(), Vector2(r.position.x, neck_y + r.size.y * 0.32 + fs * 0.36), initial,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 1, 1, 0.8))


## 초상 자리표시(그림은 M3): 틀 + 직업색 판(위 밝게 → 아래 어둡게), 이름 첫 글자를 크게, 아래 띠에 이름. 캠프 상태 화면도 같이 쓴다.
static func draw_placeholder(ci: Control, p: Rect2, who: String, cc: Color, initial_fs: int, name_fs: int) -> void:
	var font := ci.get_theme_default_font()
	ci.draw_rect(p, UiTheme.CMD_PLATE)
	var inner := p.grow(-4.0)
	var top := cc.darkened(0.35)
	var bottom := cc.darkened(0.75)
	ci.draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	ci.draw_rect(p.grow(-1.5), UiTheme.CMD_PLATE_EDGE, false, 3.0)
	ci.draw_string(font, Vector2(inner.position.x, inner.get_center().y + initial_fs * 0.3), who.left(1), HORIZONTAL_ALIGNMENT_CENTER, inner.size.x,
		initial_fs, Color(1, 1, 1, 0.85))
	var band_h := roundf(name_fs * 1.8)
	var band := Rect2(inner.position.x, inner.end.y - band_h, inner.size.x, band_h)
	ci.draw_rect(band, UiTheme.CMD_PLATE)
	ci.draw_string(font, Vector2(band.position.x + 10.0, band.get_center().y + name_fs * 0.36), who, HORIZONTAL_ALIGNMENT_LEFT,
		band.size.x - 20.0, name_fs, UiTheme.CARD_TEXT)
