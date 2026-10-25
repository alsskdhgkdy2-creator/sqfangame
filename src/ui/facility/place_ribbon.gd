## 캠프 맨 위 장소 띠(07 §9.8 ③, 원작 HD III research 07 §2.1 차례 6): 밝은 하늘색 띠에 남색 글자로 지금 장소 이름(지금은 층 이름).
## 오른쪽 끝은 소지금 문패 쪽으로 비스듬히 깎고(원작처럼), 아래에 가는 청록 선. 장식이라 누르기를 받지 않는다. 자리는 놓는 쪽이 앵커로 정한다.
class_name PlaceRibbon
extends Control

const FS := 28
## 글 왼쪽 여백(알림 줄 글도 같은 여백에서 시작한다).
const PAD := 24.0
## 오른쪽 끝 깎기(아래가 왼쪽으로 들어간다).
const SLANT := 16.0

var text := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


func show_text(t: String) -> void:
	if t != text:
		text = t
		queue_redraw()


## 글을 쓸 수 있는 폭(깎인 끝 앞까지).
func text_width() -> float:
	return size.x - PAD - SLANT - 8.0


func _draw() -> void:
	var b := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(PackedVector2Array([b.position, Vector2(b.end.x, 0), Vector2(b.end.x - SLANT, b.end.y), Vector2(0, b.end.y)]),
		UiTheme.RIBBON_FILL)
	draw_line(Vector2(0, b.end.y - 1.0), Vector2(b.end.x - SLANT, b.end.y - 1.0), UiTheme.RIBBON_EDGE, 2.0)
	draw_string(get_theme_default_font(), Vector2(PAD, b.get_center().y + FS * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, text_width(), FS,
		UiTheme.RIBBON_TEXT)
