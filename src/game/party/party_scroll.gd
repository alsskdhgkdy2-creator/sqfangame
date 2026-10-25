## 파티 메뉴의 끌어 내리는 영역(07 §9.2): 자르기(clip) 영역 안에서 content 를 세로로 옮긴다. 넘치지 않으면 움직이지 않는다.
## content 밖으로 나간 부분은 그려지지도 눌리지도 않는다(clip_contents). 빈 곳을 눌러 끌어도, 줄(PartyButton.scroller)을
## 눌러 끌어도, 휠로도 내린다. 빈 곳 누르기도 누른 손가락·버튼이 뗄 때까지 가진다(흉내 낸 마우스는 버린다).
class_name PartyScroll
extends Control

const WHEEL_STEP := 64.0

## 내린 양이나 내용 높이가 바뀌었다(스크롤 막대를 다시 그린다).
signal scrolled

## 내용(이 컨트롤 기준 위치에 줄을 둔다). 자신은 포인터를 받지 않는다(빈 곳은 이 영역이 받는다).
var content := Control.new()
var content_height := 0.0
var scroll := 0.0
var _owner := TouchButton.NONE


func _init() -> void:
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.name = "Content"
	add_child(content)


func max_scroll() -> float:
	return maxf(0.0, content_height - size.y)


func scroll_to(y: float) -> void:
	scroll = clampf(y, 0.0, max_scroll())
	content.position = Vector2(0, -roundf(scroll))
	content.size = Vector2(size.x, maxf(content_height, size.y))
	scrolled.emit()


func scroll_by(dy: float) -> void:
	scroll_to(scroll + dy)


func wheel(down: bool) -> void:
	scroll_by(WHEEL_STEP if down else -WHEEL_STEP)


## 내용 좌표 top~bottom 이 다 보이게 내린다.
func ensure_visible(top: float, bottom: float) -> void:
	if top < scroll:
		scroll_to(top)
	elif bottom > scroll + size.y:
		scroll_to(bottom - size.y)


func set_content_height(h: float) -> void:
	content_height = h
	scroll_to(scroll)


## 내용 좌표의 사각형이 보이는 영역 안에 다 들어 있는지.
func shows(r: Rect2) -> bool:
	return r.position.y >= scroll - 0.5 and r.end.y <= scroll + size.y + 0.5


func cancel() -> void:
	_owner = TouchButton.NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		scroll_to(scroll)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _owner == TouchButton.NONE and not t.canceled:
			_owner = t.index
		elif not t.pressed and t.index == _owner:
			_owner = TouchButton.NONE
		accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _owner:
			scroll_by(-d.relative.y)
		accept_event()
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_WHEEL_UP or m.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if m.pressed:
				wheel(m.button_index == MOUSE_BUTTON_WHEEL_DOWN)
		elif m.device != InputEvent.DEVICE_ID_EMULATION and m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed and _owner == TouchButton.NONE:
				_owner = TouchButton.MOUSE
			elif not m.pressed and _owner == TouchButton.MOUSE:
				_owner = TouchButton.NONE
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _owner == TouchButton.MOUSE and mm.device != InputEvent.DEVICE_ID_EMULATION:
			scroll_by(-mm.relative.y)
		accept_event()
