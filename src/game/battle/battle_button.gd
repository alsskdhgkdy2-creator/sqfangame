## 전투 층의 글자 단추(명령·스킬 줄·뒤로·실행·로그·확인). TouchButton 의 입력 처리(포커스 없음, 손가락 소유, 흉내 마우스 버림)를
## 그대로 쓰고 그림만 바꾼다. dimmed 는 「못 고름」을 보이기만 하고 누르기는 받는다(누르면 이유를 알림 줄에 띄운다, 06 §9.2).
class_name BattleButton
extends TouchButton

## 오른쪽 글자(스킬 TP 등).
var right := "":
	set(v):
		right = v
		queue_redraw()
## 아래 작은 글자(못 쓰는 이유).
var note := "":
	set(v):
		note = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
## 글자 크기.
var font_size := 20
## 왼쪽 정렬(스킬 줄). 아니면 가운데.
var align_left := false


func set_text(t: String) -> void:
	text = t
	queue_redraw()


## 못 고름(dimmed)도 못 누름과 같은 흐린 모양(누르기는 받는다).
func theme_state() -> String:
	return UiTheme.state_of(held, selected, checked, disabled or dimmed)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lk := UiTheme.draw_button(self, r, theme_state())
	var font := get_theme_default_font()
	var fg: Color = lk["text"]
	var pad := 16.0
	var main_y := size.y / 2.0 + font_size * 0.36
	if not note.is_empty():
		main_y = size.y * 0.45 + font_size * 0.2
	if align_left:
		var right_w := 0.0
		if not right.is_empty():
			right_w = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2).x
			draw_string(font, Vector2(size.x - pad - right_w, main_y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, fg)
		draw_string(font, Vector2(pad, main_y), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * pad - right_w - 8.0, font_size, fg)
	else:
		draw_string(font, Vector2(0, main_y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, fg)
	if not note.is_empty():
		var nx := pad if align_left else 0.0
		var nw := size.x - 2.0 * pad if align_left else size.x
		var al := HORIZONTAL_ALIGNMENT_LEFT if align_left else HORIZONTAL_ALIGNMENT_CENTER
		draw_string(font, Vector2(nx, size.y - 9.0), note, al, nw, 14, lk["reason"])
