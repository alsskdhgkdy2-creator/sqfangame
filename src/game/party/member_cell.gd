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


## HP 막대 색(HpColor 한 규칙).
func hp_bar_color() -> Color:
	return HpColor.of(hp, max_hp)


## 지금 대원(selected)은 켜짐 모양이되 채움은 그대로(직업색 띠·HP 막대 색이 뜻을 가진다): 청록 굵은 테두리.
func theme_state() -> String:
	return UiTheme.state_of(held, false, selected, false, true)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lk := UiTheme.draw_button(self, r, theme_state())
	draw_rect(Rect2(4, 4, 10, size.y - 8), band)
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, 32), member_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 110, 20, lk["text"])
	draw_string(font, Vector2(size.x - 96, 32), level_text, HORIZONTAL_ALIGNMENT_RIGHT, 84, 20, lk["accent"])
	_bar(lk, 58.0, "HP", hp, max_hp, hp_text, hp_bar_color())
	_bar(lk, 84.0, "TP", tp, max_tp, tp_text, UiTheme.TP_BAR)
	if not sp_text.is_empty():
		draw_string(font, Vector2(24, 111), sp_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 16, lk["accent"])


func _bar(lk: Dictionary, y: float, label: String, v: int, vmax: int, value_text: String, col: Color) -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(24, y + 4), label, HORIZONTAL_ALIGNMENT_LEFT, 36, 15, lk["sub"])
	var bar := Rect2(60, y - 8, size.x - 170, 12)
	draw_rect(bar, Color(0.15, 0.2, 0.24))
	if vmax > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(v) / vmax, 0.0, 1.0), bar.size.y)), col)
	draw_string(font, Vector2(size.x - 104, y + 4), value_text, HORIZONTAL_ALIGNMENT_RIGHT, 92, 15, lk["text"])
