## 화면 단추(05 §9.3): 키보드 포커스를 갖지 않고(포커스 가진 Button 은 방향키를 먹고 Space 로 다시 눌린다),
## 손가락마다 터치를 직접 받고(흉내 마우스는 손가락 0 만 만들어 준다), 흉내 낸 마우스 이벤트는 버린다.
## 누르기가 시작된 단추가 그 손가락·버튼을 뗄 때까지 가진다.
class_name TouchButton
extends Control

## fire_on_press 면 누르는 순간, 아니면 단추 안에서 뗄 때.
signal activated
## 눌림이 끝났다(뗌·취소). 누르고 있기 반복의 승인을 지우는 데 쓴다.
signal released

const NONE := -2
const MOUSE := -1

## 그릴 기호(VectorIcons 이름)와 글자. 둘 다 있으면 기호 아래 작은 글자.
var icon := ""
var icon_dir := 0
var text := ""
var fire_on_press := false
## 지금 고른 도구 등 강조 표시.
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		if v:
			cancel()
		queue_redraw()
## 색 견본(바닥 색 도구). 알파 0 이면 그리지 않는다.
var swatch := Color(0, 0, 0, 0)
## 지금 눌려 있는지(누르고 있으면 반복용).
var held := false

var _owner := NONE


func _init() -> void:
	focus_mode = FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 64)


func setup(icon_name: String, label: String = "", press_mode: bool = false) -> TouchButton:
	icon = icon_name
	text = label
	fire_on_press = press_mode
	return self


## 창이 열리거나 포커스를 잃을 때: 눌림 상태를 버린다(떼기가 오지 않을 수 있다).
func cancel() -> void:
	var was_held := held
	held = false
	_owner = NONE
	queue_redraw()
	if was_held:
		released.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _owner == NONE and not t.canceled:
			_owner = t.index
			_down()
		elif not t.pressed and t.index == _owner:
			_up(not t.canceled and Rect2(Vector2.ZERO, size).has_point(t.position))
		accept_event()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.device != InputEvent.DEVICE_ID_EMULATION and m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed and _owner == NONE:
				_owner = MOUSE
				_down()
			elif not m.pressed and _owner == MOUSE:
				_up(not m.canceled and Rect2(Vector2.ZERO, size).has_point(m.position))
		accept_event()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		accept_event()


func _down() -> void:
	if disabled:
		_owner = NONE
		return
	held = true
	queue_redraw()
	if fire_on_press:
		activated.emit()


func _up(inside: bool) -> void:
	var was_held := held
	held = false
	_owner = NONE
	queue_redraw()
	if was_held and inside and not fire_on_press and not disabled:
		activated.emit()
	if was_held:
		released.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0.08, 0.12, 0.16, 0.82)
	if held:
		bg = Color(0.16, 0.32, 0.4, 0.95)
	elif selected:
		bg = Color(0.12, 0.26, 0.32, 0.95)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = Color(0.4, 0.95, 1.0) if selected else Color(0.3, 0.45, 0.52)
	draw_style_box(sb, r)
	var fg := Color(0.85, 0.95, 1.0) if not disabled else Color(0.4, 0.45, 0.5)
	var font := get_theme_default_font()
	var fs := 16
	var icon_rect := r.grow(-size.x * 0.18)
	if not text.is_empty() and not icon.is_empty():
		icon_rect = Rect2(Vector2(size.x * 0.24, size.y * 0.08), Vector2(size.x * 0.52, size.x * 0.52))
	if swatch.a > 0.0:
		draw_rect(Rect2(size * 0.22, size * 0.56), swatch)
	if not icon.is_empty():
		VectorIcons.draw(self, icon, icon_rect, fg, icon_dir)
	if not text.is_empty():
		var y := size.y - 10.0 if not icon.is_empty() else size.y / 2.0 + fs * 0.35
		var fsize := fs if not icon.is_empty() else 20
		draw_string(font, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, fsize, fg)
