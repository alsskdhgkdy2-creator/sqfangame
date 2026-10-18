## 지도 패널(05 §7.2, §9.3): 플레이어 지도 그림을 그리고 편집한다. 지도 그림만 바꾸고 세계·이동에는 관여하지 않는다.
## 입력: 마우스 왼쪽 = 지금 도구, 휠 = 확대·축소, 가운데·오른쪽 끌기 = 이동.
## 터치 한 손가락 = 지금 도구, 두 손가락 = 이동·확대. 그리던 중 두 번째 손가락이 닿으면 그리던 것을 취소하고,
## 손가락을 모두 뗄 때까지 도구를 쓰지 않는다. 흉내 낸 마우스(터치에서 만든 것)는 버린다(터치로 이미 처리).
class_name MapPanel
extends Control

## 편집 한 단계가 끝남. changed 면 실행 취소 한 단계가 생긴 것(자동 저장).
signal edited(changed: bool)
signal memo_requested(cell: Vector2i)
## 이동·확대(디버그 위치 정보 갱신용).
signal view_changed

const TAP_SLOP := 10.0
const TOOLS := ["wall", "door", "color", "icon", "memo", "eraser", "pan"]
## 바닥 색 0(자동)·1~4.
const FLOOR_COLORS := [Color(0.12, 0.3, 0.33), Color(0.2, 0.42, 0.9), Color(0.22, 0.68, 0.32), Color(0.88, 0.74, 0.18), Color(0.86, 0.28, 0.36)]
const BG := Color(0.025, 0.04, 0.055)
const GRID := Color(0.2, 0.3, 0.36, 0.35)
## 청사진 모눈(M2.6 U7): 층 칸 안 바탕, 층 밖 흐린 선, GRID_MAJOR 칸마다 조금 밝은 선.
const FLOOR_BG := Color(0.035, 0.075, 0.105)
const GRID_OUT := Color(0.2, 0.3, 0.36, 0.14)
const GRID_MAJOR := 5
const GRID_MAJOR_IN := Color(0.3, 0.48, 0.56, 0.55)
const GRID_MAJOR_OUT := Color(0.25, 0.38, 0.45, 0.24)
## 좌표 머리: 위 띠 높이·왼쪽 띠 폭·글자 크기·색.
const HEAD_H := 18.0
const HEAD_W := 24.0
const HEAD_FS := 12
const HEAD_BG := Color(0.015, 0.03, 0.045, 0.78)
const HEAD_TEXT := Color(0.62, 0.8, 0.88)
const WALL_COLOR := Color(0.9, 0.95, 1.0)
const AUTO_WALL_COLOR := Color(0.6, 0.72, 0.8)
const DOOR_COLOR := Color(1.0, 0.65, 0.2)
const PARTY_COLOR := Color(0.3, 1.0, 0.9)
const NONE := -2
const MOUSE := -1

var state: ExplorationState
var geo := MapGeometry.new()
## 도구·색·아이콘. 진행 중인 제스처(누르고 있는 손가락·마우스)가 있을 때 바꾸면 그 제스처를 취소한다
## (획이면 표시도 되돌리고 edited·자동 저장 없음). 제스처는 시작할 때의 값(_g_*)을 끝까지 쓴다.
var tool := "wall":
	set(v):
		if v != tool:
			_cancel_gesture()
		tool = v
var paint_color := 1:
	set(v):
		if v != paint_color:
			_cancel_gesture()
		paint_color = v
var icon_type := "pin":
	set(v):
		if v != icon_type:
			_cancel_gesture()
		icon_type = v
var _g_tool := "wall"
var _g_color := 1
var _g_icon := "pin"
## 파티 위치를 따라간다. 끌어 옮기면 꺼지고 「파티로」로 켠다.
var follow := true

var _touches := {}  # 터치 index → 위치
var _tool_owner := NONE
var _pan_owner := NONE
var _gesture_lock := false
var _pinching := false
var _pinch_dist := 0.0
var _pinch_center := Vector2.ZERO
## 핀치에 쓰는 두 접점(터치 index). 바뀌면 기준 거리·중심을 다시 잡는다.
var _pinch_pair: Array = []
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _moved := false
var _stroke_open := false
var _edge_mode := ""
var _last_edge := GridKey.BAD_EDGE
var _last_cell := GridKey.BAD_CELL
## 층 폭 → 가장 넓은 열 머리 폭(header_need).
var _col_need := {}


func _init() -> void:
	focus_mode = FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		refresh()


func set_state(s: ExplorationState) -> void:
	cancel_input()
	state = s
	geo.width = s.floor_def.width
	geo.height = s.floor_def.height
	refresh()


func refresh() -> void:
	if state != null and follow:
		geo.center_on(Vector2(state.party.at) + Vector2(0.5, 0.5), size / 2.0)
	queue_redraw()
	view_changed.emit()


## 그리는 중인지(끌기를 확정하지 않음). 이때 지도 표시(state.annotation)에는 확정하지 않은 획이 들어 있다.
func is_stroking() -> bool:
	return _stroke_open


## 지도에서 진행 중인 상호작용이 있는지: 그리기 획·끌어 이동·핀치·아이콘·메모 누르기, 닿아 있는 손가락.
## 이동 행동은 이 동안 받지 않는다(05 §9.3).
func is_interacting() -> bool:
	return _stroke_open or _tool_owner != NONE or _pan_owner != NONE or not _touches.is_empty() or _pinching or _gesture_lock


## 창이 열리거나 포커스를 잃을 때·불러올 때: 확정하지 않은 그리기를 취소하고 포인터 상태를 비운다.
func cancel_input() -> void:
	if _stroke_open and state != null:
		state.annotation.cancel_stroke()
	_stroke_open = false
	_touches.clear()
	_tool_owner = NONE
	_pan_owner = NONE
	_gesture_lock = false
	_pinching = false
	_pinch_pair = []
	queue_redraw()


func to_party() -> void:
	follow = true
	refresh()


func zoom(factor: float) -> void:
	geo.zoom_at(size / 2.0, factor)
	refresh()


func undo() -> bool:
	if _stroke_open or state == null:
		return false
	var ok := state.annotation.undo()
	if ok:
		queue_redraw()
		edited.emit(true)
	return ok


# ---- 입력 ----

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		accept_event()
		if m.device == InputEvent.DEVICE_ID_EMULATION:
			return
		match m.button_index:
			MOUSE_BUTTON_LEFT:
				if m.pressed and _tool_owner == NONE and _touches.is_empty():
					_tool_begin(MOUSE, m.position)
				elif not m.pressed and _tool_owner == MOUSE:
					if m.canceled:
						_tool_cancel()
					else:
						_tool_end(m.position)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				if m.pressed and _pan_owner == NONE:
					_pan_owner = MOUSE
					_last_pos = m.position
				elif not m.pressed and _pan_owner == MOUSE:
					_pan_owner = NONE
			MOUSE_BUTTON_WHEEL_UP:
				if m.pressed:
					_zoom_at(m.position, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if m.pressed:
					_zoom_at(m.position, 1.0 / 1.15)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		accept_event()
		if mm.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if _tool_owner == MOUSE:
			_tool_move(mm.position)
		elif _pan_owner == MOUSE:
			_pan(mm.position - _last_pos)
			_last_pos = mm.position
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		accept_event()
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() >= 2:
				_start_pinch()
			elif not _gesture_lock and _tool_owner == NONE:
				_tool_begin(t.index, t.position)
		else:
			_touches.erase(t.index)
			if t.index == _tool_owner:
				if t.canceled:
					_tool_cancel()
				else:
					_tool_end(t.position)
			if _touches.size() < 2:
				_pinching = false
			elif _pinching:
				_rebase_pinch()
			if _touches.is_empty():
				_gesture_lock = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		accept_event()
		_touches[d.index] = d.position
		if _pinching:
			_update_pinch()
		elif d.index == _tool_owner:
			_tool_move(d.position)
	elif event is InputEventMagnifyGesture:
		accept_event()
		_zoom_at((event as InputEventMagnifyGesture).position, (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		accept_event()
		_pan(-(event as InputEventPanGesture).delta * 8.0)


func _start_pinch() -> void:
	if _tool_owner != NONE:
		_tool_cancel()
	_gesture_lock = true
	_pinching = true
	_rebase_pinch()


## 지금 두 접점으로 핀치 기준 거리·중심을 잡는다(확대·이동하지 않는다).
func _rebase_pinch() -> void:
	_pinch_pair = _pair_keys()
	var pts := _two_touches()
	_pinch_dist = maxf(1.0, pts[0].distance_to(pts[1]))
	_pinch_center = (pts[0] + pts[1]) / 2.0


func _update_pinch() -> void:
	if _pair_keys() != _pinch_pair:
		# 손가락이 바뀌었다(세 손가락 → 두 손가락 등): 새 쌍의 거리를 옛 쌍과 비교하지 않는다.
		_rebase_pinch()
		return
	var pts := _two_touches()
	var dist := maxf(1.0, pts[0].distance_to(pts[1]))
	var center := (pts[0] + pts[1]) / 2.0
	follow = false
	geo.zoom_at(_pinch_center, dist / _pinch_dist)
	geo.pan(center - _pinch_center)
	_pinch_dist = dist
	_pinch_center = center
	queue_redraw()
	view_changed.emit()


func _pair_keys() -> Array:
	var keys := _touches.keys()
	keys.sort()
	return keys.slice(0, 2)


func _two_touches() -> Array[Vector2]:
	var keys := _pair_keys()
	return [_touches[keys[0]], _touches[keys[1]]]


func _zoom_at(pivot: Vector2, factor: float) -> void:
	if follow:
		geo.zoom_at(size / 2.0, factor)
		refresh()
		return
	geo.zoom_at(pivot, factor)
	queue_redraw()
	view_changed.emit()


func _pan(delta: Vector2) -> void:
	follow = false
	geo.pan(delta)
	queue_redraw()
	view_changed.emit()


# ---- 도구 ----

func _tool_begin(owner: int, pos: Vector2) -> void:
	_tool_owner = owner
	_g_tool = tool
	_g_color = paint_color
	_g_icon = icon_type
	_press_pos = pos
	_last_pos = pos
	_moved = false
	_edge_mode = ""
	_last_edge = GridKey.BAD_EDGE
	_last_cell = GridKey.BAD_CELL
	match _g_tool:
		"wall", "door", "color", "eraser":
			state.annotation.begin_stroke()
			_stroke_open = true
			_apply_at(pos)
			queue_redraw()


func _tool_move(pos: Vector2) -> void:
	if pos.distance_to(_press_pos) > TAP_SLOP:
		_moved = true
	match _g_tool:
		"wall", "door", "color", "eraser":
			# 빠르게 끌어도 지나간 경계·칸을 놓치지 않게 칸 0.2 간격으로 나눠 적용한다.
			var steps := maxi(1, ceili(_last_pos.distance_to(pos) / maxf(2.0, geo.cell_px * 0.2)))
			for i in range(1, steps + 1):
				_apply_at(_last_pos.lerp(pos, float(i) / steps))
			queue_redraw()
		"pan":
			_pan(pos - _last_pos)
	_last_pos = pos


func _tool_end(pos: Vector2) -> void:
	_tool_move(pos)
	_tool_owner = NONE
	match _g_tool:
		"icon":
			if not _moved:
				_place_icon(geo.pick_cell(pos))
		"memo":
			if not _moved:
				var c := geo.pick_cell(pos)
				if c != GridKey.BAD_CELL:
					memo_requested.emit(c)
	if _stroke_open:
		_stroke_open = false
		var changed := state.annotation.end_stroke()
		queue_redraw()
		edited.emit(changed)


## 도구가 바뀔 때: 진행 중인 도구 제스처를 취소한다(손가락은 닿아 있어도 그 손가락은 더 그리지 않는다).
func _cancel_gesture() -> void:
	if _tool_owner != NONE:
		_tool_cancel()


func _tool_cancel() -> void:
	if _stroke_open:
		state.annotation.cancel_stroke()
		_stroke_open = false
	_tool_owner = NONE
	queue_redraw()


func _apply_at(pos: Vector2) -> void:
	var ann := state.annotation
	match _g_tool:
		"wall", "door":
			var e := geo.pick_edge(pos)
			if e == GridKey.BAD_EDGE or e == _last_edge:
				return
			_last_edge = e
			var mark := _g_tool if _g_tool == "wall" else "door"
			if _edge_mode.is_empty():
				# 처음 누른 경계: 켜고 끈 결과에 따라 이 끌기 동안 켜기만·끄기만 한다(05 §7.2).
				ann.toggle_edge(e, mark)
				_edge_mode = "on" if ann.edge_mark(e) == mark else "off"
			elif _edge_mode == "on":
				ann.paint_edge(e, mark)
			else:
				ann.unpaint_edge(e, mark)
		"color":
			var c := geo.pick_cell(pos)
			if c != GridKey.BAD_CELL and c != _last_cell:
				_last_cell = c
				ann.paint_floor(c, _g_color)
		"eraser":
			var e := geo.pick_edge(pos)
			if e != GridKey.BAD_EDGE:
				if e != _last_edge:
					_last_edge = e
					ann.erase_edge(e)
				return
			var c := geo.pick_cell(pos)
			if c != GridKey.BAD_CELL and c != _last_cell:
				_last_cell = c
				ann.erase_cell(c)


func _place_icon(c: Vector2i) -> void:
	if c == GridKey.BAD_CELL:
		return
	var ann := state.annotation
	var cur: Variant = ann.icons.get(c)
	var dir := -1
	if _g_icon == "arrow":
		dir = state.party.facing
		if cur != null and cur["type"] == "arrow":
			dir = (int(cur["dir"]) + 1) % 4
	ann.begin_stroke()
	ann.set_icon(c, _g_icon, dir)
	var changed := ann.end_stroke()
	queue_redraw()
	edited.emit(changed)


# ---- 그리기 ----

## 그리는 차례(M2.6 U7). 좌표 머리는 모눈 위, 지도 표시(바닥 색·벽·문·아이콘·메모)와 파티 표시 아래: 머리가 표시를 덮지 않는다.
const LAYERS := ["blueprint", "grid", "headers", "floors", "edges", "icons", "memos", "party"]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if state == null:
		return
	for layer in LAYERS:
		call("_draw_" + layer)


## 층 칸 영역(화면 좌표).
func floor_rect() -> Rect2:
	return Rect2(geo.to_screen(Vector2.ZERO), Vector2(geo.width, geo.height) * geo.cell_px)


## 청사진 바탕: 층 칸 안을 조금 밝게(밖은 BG 그대로).
func _draw_blueprint() -> void:
	draw_rect(floor_rect().intersection(Rect2(Vector2.ZERO, size)), FLOOR_BG)


## 패널 전체 모눈(층 칸에 맞춘다). 층 밖은 흐리게, GRID_MAJOR 칸마다 조금 굵은 선.
func _draw_grid() -> void:
	var a := geo.to_map(Vector2.ZERO)
	var b := geo.to_map(size)
	var fr := floor_rect()
	for x in range(floori(a.x), ceili(b.x) + 1):
		var sx := geo.to_screen(Vector2(x, 0)).x
		var major := posmod(x, GRID_MAJOR) == 0
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), GRID_MAJOR_OUT if major else GRID_OUT, 1.0)
		if x >= 0 and x <= geo.width:
			draw_line(Vector2(sx, fr.position.y), Vector2(sx, fr.end.y), GRID_MAJOR_IN if major else GRID, 1.0)
	for y in range(floori(a.y), ceili(b.y) + 1):
		var sy := geo.to_screen(Vector2(0, y)).y
		var major := posmod(y, GRID_MAJOR) == 0
		draw_line(Vector2(0, sy), Vector2(size.x, sy), GRID_MAJOR_OUT if major else GRID_OUT, 1.0)
		if y >= 0 and y <= geo.height:
			draw_line(Vector2(fr.position.x, sy), Vector2(fr.end.x, sy), GRID_MAJOR_IN if major else GRID, 1.0)


## 열 이름: 0 → A, 25 → Z, 26 → AA(층 칸 번호와 1:1).
static func column_name(i: int) -> String:
	var out := ""
	var n := i
	while true:
		out = char(65 + n % 26) + out
		n = n / 26 - 1
		if n < 0:
			break
	return out


## 행 이름: 0 → 「1」.
static func row_name(i: int) -> String:
	return str(i + 1)


## 머리 글자 하나가 차지하는 폭(열: 이 층의 모든 열 이름 가운데 가장 넓은 것 + 좌우 2px) 또는 높이(행).
## 열 이름 폭은 글자마다 달라(「AI」보다 「AG」「AW」가 넓다) 마지막 열만 재면 이웃과 겹칠 수 있다. 층 폭마다 한 번 잰다.
func header_need(vertical: bool) -> float:
	var font := get_theme_default_font()
	if vertical:
		return font.get_height(HEAD_FS) * 0.8 + 2.0
	if not _col_need.has(geo.width):
		var widest := 0.0
		for i in geo.width:
			widest = maxf(widest, font.get_string_size(column_name(i), HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_FS).x)
		_col_need[geo.width] = widest + 4.0
	return _col_need[geo.width]


## 머리 글자 몇 칸마다 하나를 보일지(1 = 모두). 글자가 칸보다 넓으면 2·5·10 칸마다로 솎는다(0 = 숨김).
func header_step(vertical: bool) -> int:
	var need := header_need(vertical)
	for k in [1, 2, 5, 10]:
		if k * geo.cell_px >= need:
			return k
	return 0


## 보이는 열 머리: [{index, text, rect}]. rect 는 글자 상자(그 열 가운데, 위 띠 HEAD_H 안). 왼쪽 띠 위(모서리)는 비운다.
func column_labels() -> Array[Dictionary]:
	return _labels(false)


## 보이는 행 머리: [{index, text, rect}]. rect 는 글자 상자(그 행 가운데, 왼쪽 띠 HEAD_W 안).
func row_labels() -> Array[Dictionary]:
	return _labels(true)


func _labels(vertical: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var k := header_step(vertical)
	if k == 0:
		return out
	var font := get_theme_default_font()
	var band := Rect2(0, HEAD_H, HEAD_W, size.y - HEAD_H) if vertical else Rect2(HEAD_W, 0, size.x - HEAD_W, HEAD_H)
	var fh := font.get_height(HEAD_FS) * 0.8
	for i in range(0, geo.height if vertical else geo.width, k):
		var t := row_name(i) if vertical else column_name(i)
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HEAD_FS).x + 4.0
		var c := Vector2(HEAD_W / 2.0, geo.to_screen(Vector2(0, i + 0.5)).y) if vertical else Vector2(geo.to_screen(Vector2(i + 0.5, 0)).x, HEAD_H / 2.0)
		var r := Rect2(c - Vector2(tw, fh) / 2.0, Vector2(tw, fh))
		if band.grow(0.01).encloses(r):
			out.append({"index": i, "text": t, "rect": r})
	return out


## 좌표 머리: 위·왼쪽 반투명 띠와 글자(지도 표시 아래에 그린다: LAYERS).
func _draw_headers() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(0, 0, size.x, HEAD_H), HEAD_BG)
	draw_rect(Rect2(0, HEAD_H, HEAD_W, size.y - HEAD_H), HEAD_BG)
	# 글자 상자 가운데에 숫자·영문 대문자 높이(약 0.72em)의 가운데를 맞춘다.
	for l in column_labels() + row_labels():
		var r: Rect2 = l["rect"]
		draw_string(font, Vector2(r.position.x, r.get_center().y + HEAD_FS * 0.36), l["text"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, HEAD_FS, HEAD_TEXT)


func _draw_floors() -> void:
	var ann := state.annotation
	for c in ann.floors:
		draw_rect(geo.cell_rect(c).grow(-0.5), FLOOR_COLORS[clampi(ann.floors[c], 0, 4)])


func _draw_edges() -> void:
	var ann := state.annotation
	var px := geo.cell_px
	var lw := maxf(2.0, px * 0.12)
	for e in ann.edges:
		var seg := geo.edge_segment(e)
		var col := AUTO_WALL_COLOR if ann.auto_edges.has(e) else WALL_COLOR
		if ann.edges[e] == "door":
			var a := seg[0].lerp(seg[1], 0.3)
			var b := seg[0].lerp(seg[1], 0.7)
			draw_line(seg[0], a, col, lw)
			draw_line(b, seg[1], col, lw)
			var mid := (seg[0] + seg[1]) / 2.0
			var half := Vector2(px * 0.18, px * 0.18)
			draw_rect(Rect2(mid - half, half * 2.0), DOOR_COLOR, false, maxf(1.5, lw * 0.6))
		else:
			draw_line(seg[0], seg[1], col, lw)


func _draw_icons() -> void:
	var ann := state.annotation
	for c in ann.icons:
		var ic: Dictionary = ann.icons[c]
		VectorIcons.draw(self, ic["type"], geo.cell_rect(c).grow(-geo.cell_px * 0.12), Color(1, 1, 1, 0.92), maxi(0, int(ic["dir"])))


func _draw_memos() -> void:
	var ann := state.annotation
	for c in ann.memos:
		var r := geo.cell_rect(c)
		var t := geo.cell_px * 0.32
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x - t, 0), r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x, t)]), Color(1.0, 0.9, 0.3))


func _draw_party() -> void:
	var px := geo.cell_px
	var pr := geo.cell_rect(state.party.at)
	var center := pr.get_center()
	var rot := state.party.facing * PI / 2.0
	var tri := PackedVector2Array()
	for v in [Vector2(0, -0.34), Vector2(-0.26, 0.26), Vector2(0.26, 0.26)]:
		tri.append(center + (v * px).rotated(rot))
	draw_colored_polygon(tri, PARTY_COLOR)


# ---- 디버그·시험용 위치(이 컨트롤 안 좌표) ----

func cell_point(c: Vector2i) -> Vector2:
	return geo.cell_rect(c).get_center()


func edge_point(e: Vector3i) -> Vector2:
	var seg := geo.edge_segment(e)
	return (seg[0] + seg[1]) / 2.0
