## 창 하나를 화면 가운데에 띄운다(전투·전멸·메뉴·메모·알림). 열려 있는 동안 뒤 화면은 입력을 받지 않는다.
## 열리고 닫힐 때 신호를 낸다: 화면은 열릴 때 미리 받은 입력을 비운다(05 §9.3).
class_name ModalLayer
extends Control

signal opened(kind: String)
signal closed(kind: String)

## 창과 창 단추 모양은 공용 UiTheme(원작 옵션 창처럼): 고른 것(키보드 포커스·포인터 위)은 따뜻한 채움 + 어두운 글자,
## 켜진 것(지금 고른 설정)은 밝은 청록 채움 + 어두운 글자. 못 누르는 단추도 키보드 포커스는 받는다(이동이 건너뛰지 않는다).

## 제목 문패 글자 크기와, 문패가 창 안으로 들어오는 만큼 비워 두는 위 여백.
const TITLE_FS := 24
const TITLE_ROOM := 14

## 지금 열린 창 종류("" 이면 없음).
var kind := ""

var _panel := PanelContainer.new()
var _box := VBoxContainer.new()
## 제목 문패(창 위 가장자리에 걸친다, 누르기를 받지 않는다). 창보다 뒤에 붙여 위에 그린다.
var title_plate := UiPlate.new()
## 가운데 창 대신 띄운 부품(open_part, M3 A9b 이야기 상자). 없으면 null. 어두운 판·가운데 창·제목 문패는 그동안 감춘다.
## 부품은 이 층의 자식으로 남고(닫히면 감춤) 층과 함께 사라진다: 주인은 하나(창 층)다.
var part: Control = null
var _dim: ColorRect
var _center: CenterContainer


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
	_dim = dim
	var center := CenterContainer.new()
	_center = center
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var box := UiTheme.window_box(22)
	box.content_margin_top = 22 + TITLE_ROOM
	_panel.add_theme_stylebox_override("panel", box)
	center.add_child(_panel)
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	title_plate.name = "TitlePlate"
	title_plate.font_size = TITLE_FS
	add_child(title_plate)
	_panel.item_rect_changed.connect(_place_title)


func is_open() -> bool:
	return not kind.is_empty()


## 창을 연다(열려 있던 창은 닫는다). rows 는 제목 아래에 차례로 붙는다.
func open(new_kind: String, title: String, rows: Array[Control]) -> void:
	if is_open():
		close()
	_show_window(true)
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	title_plate.text = title
	for r in rows:
		_box.add_child(r)
	kind = new_kind
	visible = true
	_place_title.call_deferred()
	opened.emit(kind)


## 가운데 창 대신 부품 하나를 화면 전체에 띄운다(M3 A9b: 클리어 이야기 상자 kind "clear"). 열린 동안 다른 창과 같이 뒤 화면 입력을 막고
## (is_open·kind), 어두운 판·가운데 창·제목 문패는 감춘다(부품이 스스로 그린다). 부품은 이 층에 맡겨 둔다(adopt_part): 닫으면 감추기만 하고
## 층과 함께 사라진다(떼어 두면 주인이 없어 화면이 사라져도 남는다).
func open_part(new_kind: String, p: Control) -> void:
	if is_open():
		close()
	adopt_part(p)
	_show_window(false)
	title_plate.text = ""
	part = p
	move_child(p, get_child_count() - 1)  # 제목 문패보다 위
	p.visible = true
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
	if part != null:
		part.visible = false  # 감추기만(층이 주인이다), 다음 open 은 부품 없이 연다
		part = null
	_show_window(true)
	closed.emit(was)


## 부품을 이 층의 자식으로 맡긴다(감춘 채, 화면 전체). 이미 자식이면 그대로. 화면을 만들 때 불러 두면 한 번도 열지 않은 부품도 층과 함께 사라진다.
func adopt_part(p: Control) -> void:
	if p.get_parent() == self:
		return
	p.visible = false
	p.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(p)


## 알림 띠가 비켜 갈 창의 화면 사각형: 가운데 창과 제목 문패, 부품이면 그 band_rect()(없으면 화면 전체).
func band_rect() -> Rect2:
	if part != null:
		return part.call("band_rect") if part.has_method("band_rect") else get_global_rect()
	return _panel.get_global_rect().merge(title_plate.get_global_rect())


func _show_window(on: bool) -> void:
	_dim.visible = on
	_center.visible = on
	title_plate.visible = on


## 창 단추(키보드 포커스 허용: 창 안에서는 이동 입력을 받지 않는다). 누를 수 있는지는 만들 때 정한다(모양이 그에 맞춰진다).
static func button(text: String, on_press: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 64)  # 누르는 칸은 64 이상(05 §9.1)
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 20)
	UiTheme.style_button(b, false)
	b.pressed.connect(on_press)
	return b


## 켜진 단추(지금 고른 설정)로 표시한다. 고른 것(포커스) 표시는 그 위에 그대로 덮인다.
static func set_checked(b: Button, on: bool) -> void:
	UiTheme.style_button(b, on)
	b.set_meta("checked", on)


static func is_checked(b: Button) -> bool:
	return bool(b.get_meta("checked", false))


## 창 가운데 위 가장자리에 제목 문패를 건다(창 크기·자리가 바뀔 때마다).
func _place_title() -> void:
	var r := _panel.get_global_rect()
	title_plate.global_position = Vector2(roundf(r.get_center().x - title_plate.size.x / 2.0), roundf(r.position.y - title_plate.size.y / 2.0))


## 창 안 묶음 머리(저장·불러오기·자동 지도): 작은 문패(장식, 누르기를 받지 않는다).
static func section(text: String) -> Control:
	var p := UiPlate.new()
	p.font_size = 17
	p.color = UiTheme.TEXT
	p.text = text
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


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
