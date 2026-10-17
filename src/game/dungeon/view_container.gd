## 3D 시야 영역. 누르기를 받아 소유하되(누르기가 시작된 곳이 끝까지 가진다) 아무 일도 하지 않고,
## 입력을 SubViewport 안으로 넘기지 않는다(3D 세계에는 입력을 받는 노드가 없다).
extends SubViewportContainer


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	stretch = true


func _propagate_input_event(_event: InputEvent) -> bool:
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseMotion:
		accept_event()
