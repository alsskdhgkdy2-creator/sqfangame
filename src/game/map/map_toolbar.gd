## 지도 도구(05 §7.2). 원작 HD 지도 판(guide4·nin_02)의 맨 오른쪽 세로 도구 열: 위에 층 문패, 아래로 벽 선·문 표시·바닥 색·
## 아이콘·메모·지우개·이동. 바닥 색을 고르면 그 단추 왼쪽에 4색 견본 줄이 뜬다(설명서 7쪽 「カラーパレット」).
## 실행 취소·확대·축소·파티로는 이 열에 두지 않고 action_buttons() 로 내준다(탐색 화면이 왼쪽 아래 안내 줄에 둔다, 원작 UNDO 안내).
## 지금 도구를 항상 강조 표시한다. 단추는 TouchButton(포커스 없음, 뗄 때 실행).
class_name MapToolbar
extends Control

## 도구 고르기: tool, color(바닥 색 견본이면 1~4, 열의 바닥 색 단추면 0 = 지금 색 그대로).
signal tool_chosen(tool: String, color: int)
## 그 밖의 단추: "undo"·"to_party"·"zoom_in"·"zoom_out".
signal action(name: String)

const GAP := 6.0
const BUTTON := 64.0
## 열 폭(단추 + 좌우 여백).
const WIDTH := BUTTON + 2.0 * GAP
## 층 문패 높이.
const PLATE_H := 44.0
const TOOL_KEYS := ["wall", "door", "color", "icon", "memo", "eraser", "pan"]
const ACTION_KEYS := ["undo", "zoom_in", "zoom_out", "to_party"]

## 키 → TouchButton(열 도구·색 견본 color1~4·행동 단추).
var buttons := {}
## 바닥 색 견본 줄(바닥 색 도구일 때만 보인다).
var palette := Control.new()
var floor_plate := FloorTag.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, PLATE_H + GAP + TOOL_KEYS.size() * (BUTTON + GAP))


func build(texts: TextDb, floor_name: String) -> void:
	floor_plate.name = "FloorPlate"
	floor_plate.text = floor_name
	add_child(floor_plate)
	_add("wall", "wall", texts.t("map.tool.wall_short"), func(): tool_chosen.emit("wall", 0))
	_add("door", "door_mark", texts.t("map.tool.door_short"), func(): tool_chosen.emit("door", 0))
	_add("color", "", "", func(): tool_chosen.emit("color", 0))
	_add("icon", "pin", texts.t("map.tool.icon_short"), func(): tool_chosen.emit("icon", 0))
	_add("memo", "memo", texts.t("map.tool.memo_short"), func(): tool_chosen.emit("memo", 0))
	_add("eraser", "eraser", texts.t("map.tool.eraser_short"), func(): tool_chosen.emit("eraser", 0))
	_add("pan", "pan", texts.t("map.tool.pan_short"), func(): tool_chosen.emit("pan", 0))
	palette.name = "ColorPalette"
	palette.mouse_filter = MOUSE_FILTER_IGNORE
	palette.visible = false
	add_child(palette)
	for i in range(1, 5):
		var n := i
		var b := _add("color%d" % i, "", "", func(): tool_chosen.emit("color", n), palette)
		b.swatch = MapPanel.FLOOR_COLORS[i]
	_add("undo", "undo", texts.t("map.undo_short"), func(): action.emit("undo"), null)
	_add("zoom_in", "zoom_in", "", func(): action.emit("zoom_in"), null)
	_add("zoom_out", "zoom_out", "", func(): action.emit("zoom_out"), null)
	_add("to_party", "party", texts.t("map.to_party"), func(): action.emit("to_party"), null)
	_layout()


## parent 가 null 이면 트리에 넣지 않는다(action_buttons 를 받는 쪽이 넣는다).
func _add(key: String, icon: String, text: String, on_press: Callable, parent: Node = self) -> TouchButton:
	var b := TouchButton.new().setup(icon, text)
	b.name = "Tool_" + key
	if TOOL_KEYS.has(key):
		b.skin = "tool"
	b.activated.connect(on_press)
	if parent != null:
		parent.add_child(b)
	buttons[key] = b
	return b


func action_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	for k in ACTION_KEYS:
		out.append(buttons[k])
	return out


## 열 안 배치(고정 크기 단추를 위에서 아래로). 색 견본 줄은 바닥 색 단추의 왼쪽(열 밖, 층 전체 보기 위에 뜬다).
func _layout() -> void:
	floor_plate.position = Vector2(GAP, GAP)
	floor_plate.size = Vector2(BUTTON, PLATE_H - GAP)
	for i in TOOL_KEYS.size():
		var b: TouchButton = buttons[TOOL_KEYS[i]]
		b.position = Vector2(GAP, tool_y(i))
		b.size = Vector2(BUTTON, BUTTON)
	var n := 4
	palette.size = Vector2(n * BUTTON + (n - 1) * GAP, BUTTON)
	palette.position = Vector2(-palette.size.x - GAP, tool_y(TOOL_KEYS.find("color")))
	for i in n:
		var b: TouchButton = buttons["color%d" % (i + 1)]
		b.position = Vector2(i * (BUTTON + GAP), 0)
		b.size = Vector2(BUTTON, BUTTON)


## 도구 칸 i 의 위 y(열 기준).
static func tool_y(i: int) -> float:
	return PLATE_H + GAP + i * (BUTTON + GAP)


## 지금 도구 강조. 바닥 색 단추는 지금 색 견본을 보이고, 바닥 색 도구일 때만 견본 줄을 띄운다.
func show_current(tool: String, color: int, icon_type: String, can_undo: bool) -> void:
	for key in buttons:
		var b: TouchButton = buttons[key]
		b.selected = (key == tool) or (tool == "color" and key == "color%d" % color)
	var cb: TouchButton = buttons["color"]
	cb.swatch = MapPanel.FLOOR_COLORS[clampi(color, 1, 4)]
	cb.queue_redraw()
	if palette.visible != (tool == "color"):
		palette.visible = tool == "color"
		if not palette.visible:
			for i in range(1, 5):
				(buttons["color%d" % i] as TouchButton).cancel()
	var ib: TouchButton = buttons["icon"]
	ib.icon = icon_type
	ib.queue_redraw()
	(buttons["undo"] as TouchButton).disabled = not can_undo


func cancel_all() -> void:
	for key in buttons:
		(buttons[key] as TouchButton).cancel()


## 층 문패(원작의 층 고르기 자리). 층이 하나라 고르기 화살표는 없다. 장식이라 누르기를 받지 않는다.
class FloorTag:
	extends Control
	const FS := 15
	var text := "":
		set(v):
			text = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiTheme.fill_round(self, Rect2(Vector2.ZERO, size), MapPanel.BG, 6, MapWindow.SEPARATOR, 2)
		draw_string(get_theme_default_font(), Vector2(0, size.y / 2.0 + FS * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, FS, UiTheme.TEXT)
