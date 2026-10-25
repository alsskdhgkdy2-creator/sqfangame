## 파티 메뉴의 글자 단추·목록 줄(07 §9.2·§9.4). TouchButton 의 입력 처리(포커스 없음, 손가락 소유, 흉내 마우스 버림,
## 누르고 있기 반복 없음, 단추 안에서 뗄 때 한 번)를 그대로 쓰고 그림만 바꾼다.
## scroller 가 있으면 끌어 내리는 목록의 줄이다: 누른 채 DRAG_START 넘게 끌면 그 목록을 끌어 내리고, 그 누르기는 뗄 때
## 아무 일도 하지 않는다(끌기와 누르기를 포인터 소유권으로 나눈다). 휠도 그 목록으로 보낸다.
## dimmed 는 「못 고름」을 보이기만 하고 누르기는 받는다(누르면 이유를 알림 줄에 띄운다). 글자 없이 icon 만 있으면 벡터 기호를 그린다.
class_name PartyButton
extends TouchButton

## 이만큼(px) 끌면 누르기가 아니라 끌기다.
const DRAG_START := 12.0

## 오른쪽 글자(개수 등).
var right := ""
## 아래 작은 글자(바뀌는 값·못 끼는 이유).
var note := ""
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
var font_size := 20
## 왼쪽 정렬(목록 줄). 아니면 가운데.
var align_left := false
## 왼쪽 위 작은 글자(장비 칸 이름).
var caption := ""
var scroller: PartyScroll
## 이번 누르기가 끌기가 되었는지.
var dragging := false
var _travel := 0.0


func show_row(main: String, right_text: String = "", note_text: String = "", dim: bool = false) -> void:
	text = main
	right = right_text
	note = note_text
	dimmed = dim
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if scroller != null:
		if event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index == MOUSE_BUTTON_WHEEL_UP or m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if m.pressed:
					scroller.wheel(m.button_index == MOUSE_BUTTON_WHEEL_DOWN)
				accept_event()
				return
		var mine := false
		var rel := Vector2.ZERO
		if event is InputEventScreenDrag:
			mine = (event as InputEventScreenDrag).index == _owner
			rel = (event as InputEventScreenDrag).relative
		elif event is InputEventMouseMotion:
			mine = _owner == MOUSE and (event as InputEventMouseMotion).device != InputEvent.DEVICE_ID_EMULATION
			rel = (event as InputEventMouseMotion).relative
		if mine:
			_travel += rel.length()
			if not dragging and _travel >= DRAG_START:
				dragging = true
				held = false  # 끌기가 되었다: 뗄 때 누르기로 치지 않는다(소유는 뗄 때까지 그대로)
				queue_redraw()
			if dragging:
				scroller.scroll_by(-rel.y)
			accept_event()
			return
	super._gui_input(event)


func _down() -> void:
	_travel = 0.0
	dragging = false
	super._down()


## 못 고름(dimmed)도 못 누름과 같은 흐린 모양(누르기는 받는다).
## skin 이 있으면 그 부품 모양(「hint:normal」 등), 없는 상태는 공용 모양.
func theme_state() -> String:
	var st := UiTheme.state_of(held, selected, checked, disabled or dimmed)
	return skin + ":" + st if not skin.is_empty() and UiTheme.has_look(skin + ":" + st) else st


## 글자 안 여백(왼쪽 정렬 줄의 양 끝).
const PAD := 16.0
const NOTE_FS := 14
const CAPTION_FS := 14


## 글자마다 [글, 글자 크기, 그릴 폭](그리기와 같은 값). 시험이 잘림을 본다(clipped_parts).
func text_parts() -> Dictionary:
	var out := {}
	if not icon.is_empty() and text.is_empty():
		return out
	var font := get_theme_default_font()
	if not caption.is_empty():
		out["caption"] = [caption, CAPTION_FS, size.x - 2.0 * PAD]
	if align_left:
		var right_w := 0.0
		if not right.is_empty():
			right_w = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2).x
			out["right"] = [right, font_size - 2, size.x - 2.0 * PAD]
		out["main"] = [text, font_size, size.x - 2.0 * PAD - right_w - 8.0]
	else:
		out["main"] = [text, font_size, size.x - 2.0 * PAD]
	if not note.is_empty():
		out["note"] = [note, NOTE_FS, size.x - 2.0 * PAD if align_left else size.x]
	return out


## 그릴 폭보다 넓어 잘리는 글자 이름(main·right·note·caption).
func clipped_parts() -> Array[String]:
	var out: Array[String] = []
	var font := get_theme_default_font()
	var parts := text_parts()
	for k in parts:
		var p: Array = parts[k]
		if font.get_string_size(str(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(p[1])).x > float(p[2]) + 0.5:
			out.append(k)
	return out


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var lk := UiTheme.draw_button(self, r, theme_state())
	var font := get_theme_default_font()
	var fg: Color = lk["text"]
	var pad := PAD
	var main_y := size.y / 2.0 + font_size * 0.36
	if not note.is_empty() or not caption.is_empty():
		main_y = size.y * 0.5 + font_size * 0.2
	if not caption.is_empty():
		draw_string(font, Vector2(pad, 22), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * pad, CAPTION_FS, lk["sub"])
	if not icon.is_empty() and text.is_empty():
		var side := minf(size.x, size.y) * 0.5
		VectorIcons.draw(self, icon, Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), fg, icon_dir)
	elif align_left:
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
		draw_string(font, Vector2(nx, size.y - 10.0), note, al, nw, NOTE_FS, lk["reason"] if dimmed else lk["sub"])
