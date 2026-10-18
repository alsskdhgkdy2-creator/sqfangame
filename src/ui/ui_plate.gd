## 문패 하나(창 테두리에 걸치는 이름표, M2.6 2.5단계·research 04 원칙 3): 누르기를 받지 않는 장식이다(mouse_filter IGNORE).
## 크기는 글자에 맞춘다(fit). 놓는 쪽이 창 테두리에 걸치게(위 가장자리면 y = 창 위 - 높이/2) 둔다.
class_name UiPlate
extends Control

var text := "":
	set(v):
		text = v
		fit()
var font_size := 20:
	set(v):
		font_size = v
		fit()
var color := UiTheme.HEAD_TEXT


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_THEME_CHANGED:
		fit()


## 글자에 맞춘 크기로(글꼴은 트리에 들어간 뒤의 것).
func fit() -> void:
	var sz := UiTheme.plate_size(get_theme_default_font(), text, font_size) if not text.is_empty() else Vector2.ZERO
	sz.y = maxf(sz.y, roundf(font_size * 1.6)) if not text.is_empty() else 0.0
	custom_minimum_size = sz
	size = sz
	queue_redraw()


func _draw() -> void:
	if not text.is_empty():
		UiTheme.draw_plate(self, Rect2(Vector2.ZERO, size), text, font_size, color)
