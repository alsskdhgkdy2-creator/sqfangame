## 지도 도구 줄(05 §7.2): 벽 선·문 표시·바닥 색 4색·아이콘·메모·지우개·이동, 실행 취소·파티로·확대·축소.
## 지금 도구를 항상 강조 표시한다. 단추는 TouchButton(포커스 없음, 뗄 때 실행).
class_name MapToolbar
extends Control

## 도구 고르기: tool, color(바닥 색 도구일 때 1~4).
signal tool_chosen(tool: String, color: int)
## 그 밖의 단추: "undo"·"to_party"·"zoom_in"·"zoom_out"·"icon_picker".
signal action(name: String)

const COLUMNS := 7
const GAP := 6.0
const BUTTON := 64.0

## 키 → TouchButton.
var buttons := {}
var _order: Array[String] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(COLUMNS * BUTTON + (COLUMNS - 1) * GAP, 2 * BUTTON + GAP)


func build(texts: TextDb) -> void:
	_add("wall", "wall", texts.t("map.tool.wall_short"), func(): tool_chosen.emit("wall", 0))
	_add("door", "door_mark", texts.t("map.tool.door_short"), func(): tool_chosen.emit("door", 0))
	for i in range(1, 5):
		var n := i
		var b := _add("color%d" % i, "", "", func(): tool_chosen.emit("color", n))
		b.swatch = MapPanel.FLOOR_COLORS[i]
	_add("zoom_in", "zoom_in", "", func(): action.emit("zoom_in"))
	_add("icon", "pin", texts.t("map.tool.icon_short"), func(): action.emit("icon_picker"))
	_add("memo", "memo", texts.t("map.tool.memo_short"), func(): tool_chosen.emit("memo", 0))
	_add("eraser", "eraser", texts.t("map.tool.eraser_short"), func(): tool_chosen.emit("eraser", 0))
	_add("pan", "pan", texts.t("map.tool.pan_short"), func(): tool_chosen.emit("pan", 0))
	_add("undo", "undo", texts.t("map.undo_short"), func(): action.emit("undo"))
	_add("to_party", "party", texts.t("map.to_party"), func(): action.emit("to_party"))
	_add("zoom_out", "zoom_out", "", func(): action.emit("zoom_out"))
	_layout()


func _add(key: String, icon: String, text: String, on_press: Callable) -> TouchButton:
	var b := TouchButton.new().setup(icon, text)
	b.name = "Tool_" + key
	b.activated.connect(on_press)
	add_child(b)
	buttons[key] = b
	_order.append(key)
	return b


func _layout() -> void:
	for i in _order.size():
		var b: TouchButton = buttons[_order[i]]
		b.position = Vector2((i % COLUMNS) * (BUTTON + GAP), (i / COLUMNS) * (BUTTON + GAP))
		b.size = Vector2(BUTTON, BUTTON)


## 지금 도구 강조. 아이콘 단추는 고른 아이콘 모양을 보인다.
func show_current(tool: String, color: int, icon_type: String, can_undo: bool) -> void:
	for key in buttons:
		var b: TouchButton = buttons[key]
		b.selected = (key == tool) or (tool == "color" and key == "color%d" % color) or (tool == "icon" and key == "icon")
	var ib: TouchButton = buttons["icon"]
	ib.icon = icon_type
	ib.queue_redraw()
	(buttons["undo"] as TouchButton).disabled = not can_undo


func cancel_all() -> void:
	for key in buttons:
		(buttons[key] as TouchButton).cancel()
