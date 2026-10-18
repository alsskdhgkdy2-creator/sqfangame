## 파티 메뉴 대원 열의 칸 하나(07 §9.2): 직업색 띠(04 §3.1), 이름, 「Lv 3」, HP·TP 막대·수치, 스킬 탭에서는 「SP 2」.
## 누르기는 TouchButton 그대로(그 대원 고르기). 지금 대원이면 selected.
class_name MemberCell
extends TouchButton

var band := Color(0.7, 0.7, 0.7)
var member_name := ""
var level_text := ""
var hp := 0
var max_hp := 1
var tp := 0
var max_tp := 0
var hp_text := ""
var tp_text := ""
## 비어 있으면 그리지 않는다.
var sp_text := ""


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.32, 0.4, 0.98) if held else (Color(0.1, 0.2, 0.25, 0.98) if selected else Color(0.06, 0.1, 0.13, 0.96))
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = Color(0.45, 0.95, 1.0) if selected else Color(0.3, 0.45, 0.52)
	draw_style_box(sb, r)
	draw_rect(Rect2(4, 4, 10, size.y - 8), band)
	var font := get_theme_default_font()
	var fg := Color(0.9, 0.97, 1.0)
	draw_string(font, Vector2(24, 32), member_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 20, fg)
	draw_string(font, Vector2(size.x - 96, 32), level_text, HORIZONTAL_ALIGNMENT_RIGHT, 84, 20, Color(1.0, 0.86, 0.45))
	_bar(58.0, "HP", hp, max_hp, hp_text, Color(0.35, 0.9, 0.45))
	_bar(84.0, "TP", tp, max_tp, tp_text, Color(0.4, 0.7, 1.0))
	if not sp_text.is_empty():
		draw_string(font, Vector2(24, 111), sp_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 16, Color(1.0, 0.86, 0.45))


func _bar(y: float, label: String, v: int, vmax: int, value_text: String, col: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, 36, 15, Color(0.7, 0.82, 0.88))
	var bar := Rect2(60, y - 8, size.x - 170, 12)
	draw_rect(bar, Color(0.15, 0.2, 0.24))
	if vmax > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(v) / vmax, 0.0, 1.0), bar.size.y)), col)
	draw_string(font, Vector2(size.x - 104, y + 4), value_text, HORIZONTAL_ALIGNMENT_RIGHT, 92, 15, Color(0.85, 0.93, 0.97))
