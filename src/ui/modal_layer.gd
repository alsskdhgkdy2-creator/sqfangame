## 창 하나를 화면 가운데에 띄운다(전투·전멸·메뉴·메모·알림). 열려 있는 동안 뒤 화면은 입력을 받지 않는다.
## 열리고 닫힐 때 신호를 낸다: 화면은 열릴 때 미리 받은 입력을 비운다(05 §9.3).
class_name ModalLayer
extends Control

signal opened(kind: String)
signal closed(kind: String)

## 창 단추 색(원작 옵션 창처럼): 평소는 어두운 바탕 + 보이는 테두리, 고른 것(키보드 포커스·포인터 위)은 따뜻한 채움 + 어두운 글자,
## 켜진 것(지금 고른 설정)은 밝은 청록 채움 + 어두운 글자. 못 누르는 단추도 키보드 포커스는 받는다(이동이 건너뛰지 않는다):
## Godot 는 그 위에 focus 상자를 덮고 글자는 font_disabled_color 로 그리므로, 못 누르는 단추의 focus 는 채움 없이 따뜻한 테두리만이다.
## 글자 대비는 Godot 가 실제로 겹쳐 그리는 짝마다 4.5:1 이상(시험이 본다).
const BTN_BG := Color(0.07, 0.12, 0.16)
const BTN_BORDER := Color(0.36, 0.62, 0.7)
const BTN_TEXT := Color(0.9, 0.96, 1.0)
const BTN_PICK := Color(1.0, 0.8, 0.34)
const BTN_PICK_PRESSED := Color(1.0, 0.9, 0.55)
const BTN_PICK_TEXT := Color(0.1, 0.07, 0.02)
const BTN_CHECKED := Color(0.55, 0.88, 0.95)
const BTN_CHECKED_BORDER := Color(0.18, 0.42, 0.5)
const BTN_DISABLED_BG := Color(0.06, 0.08, 0.1)
const BTN_DISABLED_BORDER := Color(0.22, 0.3, 0.34)
const BTN_DISABLED_TEXT := Color(0.52, 0.57, 0.62)

## 지금 열린 창 종류("" 이면 없음).
var kind := ""

var _panel := PanelContainer.new()
var _box := VBoxContainer.new()


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.11, 0.97)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.8, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)


func is_open() -> bool:
	return not kind.is_empty()


## 창을 연다(열려 있던 창은 닫는다). rows 는 제목 아래에 차례로 붙는다.
func open(new_kind: String, title: String, rows: Array[Control]) -> void:
	if is_open():
		close()
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 26)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(head)
	for r in rows:
		_box.add_child(r)
	kind = new_kind
	visible = true
	opened.emit(kind)


func close() -> void:
	if not is_open():
		return
	var was := kind
	kind = ""
	visible = false
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	closed.emit(was)


## 창 단추(키보드 포커스 허용: 창 안에서는 이동 입력을 받지 않는다). 누를 수 있는지는 만들 때 정한다(모양이 그에 맞춰진다).
static func button(text: String, on_press: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 60)
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 20)
	_style(b, false)
	b.pressed.connect(on_press)
	return b


## 켜진 단추(지금 고른 설정)로 표시한다. 고른 것(포커스) 표시는 그 위에 그대로 덮인다.
static func set_checked(b: Button, on: bool) -> void:
	_style(b, on)
	b.set_meta("checked", on)


static func is_checked(b: Button) -> bool:
	return bool(b.get_meta("checked", false))


static func _button_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	return sb


static func _style(b: Button, checked: bool) -> void:
	var base := BTN_CHECKED if checked else BTN_BG
	var text := BTN_PICK_TEXT if checked else BTN_TEXT
	b.add_theme_stylebox_override("normal", _button_box(base, BTN_CHECKED_BORDER if checked else BTN_BORDER, 2))
	b.add_theme_stylebox_override("hover", _button_box(BTN_PICK, BTN_PICK.lightened(0.4), 2))
	b.add_theme_stylebox_override("pressed", _button_box(BTN_PICK_PRESSED, BTN_PICK.lightened(0.4), 2))
	b.add_theme_stylebox_override("hover_pressed", _button_box(BTN_PICK_PRESSED, BTN_PICK.lightened(0.4), 2))
	var focus := _button_box(BTN_PICK, BTN_PICK.lightened(0.4), 3)
	if b.disabled:
		focus.draw_center = false  # 못 누르는 단추: 바탕은 disabled 그대로, 글자는 font_disabled_color(채우면 대비가 무너진다)
		focus.border_color = BTN_PICK
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", _button_box(BTN_DISABLED_BG, BTN_DISABLED_BORDER, 2))
	b.add_theme_color_override("font_color", text)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, BTN_PICK_TEXT)
	b.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)


static func label(text: String, font_size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	return l


static func row(children: Array[Control]) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in children:
		h.add_child(c)
	return h
