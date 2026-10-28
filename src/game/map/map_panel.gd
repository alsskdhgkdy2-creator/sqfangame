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
## 색은 원작 HD 지도(nin_02 에서 뽑음): 남색 바탕, 파란 모눈, 밝은 파랑 바닥(자동·0), 밝은 청록 벽, 초록 파티.
## 플레이어 바닥 색 1~4 는 자동 파랑과 구별되는 색(보라·초록·노랑·분홍빨강, 설명서 7쪽 견본처럼 알아보기 쉽게).
const FLOOR_COLORS := [Color("1b9fdf"), Color(0.6, 0.45, 0.98), Color(0.22, 0.74, 0.36), Color(0.95, 0.8, 0.25), Color(0.93, 0.36, 0.5)]
const BG := Color("01274b")
const GRID := Color("0e4878")
## 청사진 모눈(M2.6 U7): 층 칸 안 바탕, 층 밖 흐린 선, GRID_MAJOR 칸마다 조금 밝은 선.
const FLOOR_BG := Color("032b4e")
const GRID_OUT := Color("0e4878", 0.45)
const GRID_MAJOR := 5
const GRID_MAJOR_IN := Color("1a5f95")
const GRID_MAJOR_OUT := Color("1a5f95", 0.5)
const WALL_COLOR := Color("94ebf4")
const AUTO_WALL_COLOR := Color("6cc6dc")
const DOOR_COLOR := Color(1.0, 0.65, 0.2)
const PARTY_COLOR := Color("65fcb7")
const NONE := -2
const MOUSE := -1

var state: ExplorationState
var geo := MapGeometry.new()
## 패널 바탕색.
var bg := BG
## 모눈 선 진하기(층 전체 보기는 원작처럼 더 흐리게).
var grid_alpha := 1.0
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
## 기본 확대: 0 보다 크면 패널 폭에 이만큼의 칸이 들어가는 크기(원작 HD 그리기 격자는 약 7칸, nin_02).
## 지도를 열 때·「파티로」·상태를 바꿀 때 이 크기로 돌아간다. 확대·축소·핀치는 그대로 된다.
var home_columns := 0
## 기본 확대 뒤 사용자가 확대·축소했는지(크기가 바뀌어도 사용자 확대는 지킨다).
var _zoomed := false

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


func _init() -> void:
	focus_mode = FOCUS_NONE
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if not _zoomed:
			_home_zoom()
		refresh()


## 기본 확대 크기(칸 px). home_columns 가 0 이거나 폭을 모르면 지금 크기.
func home_cell_px() -> float:
	if home_columns <= 0 or size.x <= 0.0:
		return geo.cell_px
	return clampf(floorf(size.x / home_columns), MapGeometry.MIN_CELL_PX, MapGeometry.MAX_CELL_PX)


func _home_zoom() -> void:
	geo.cell_px = home_cell_px()
	_zoomed = false


func set_state(s: ExplorationState) -> void:
	cancel_input()
	state = s
	geo.width = s.floor_def.width
	geo.height = s.floor_def.height
	follow = true
	_home_zoom()
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


## 「파티로」·지도 열기: 파티를 따라가고 기본 확대로 돌아간다.
func to_party() -> void:
	follow = true
	_home_zoom()
	refresh()


func zoom(factor: float) -> void:
	_zoomed = true
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
	_zoomed = true
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
	_zoomed = true
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

## 그리는 차례(M2.6 U7): 바탕 → 모눈 → 지도 표시(바닥 색·벽·문·아이콘·메모) → FOE(M3 A6c) → 파티 표시.
## 그리기 격자에는 좌표 자가 없다(원작 HD: 자는 층 전체 보기에만 있다, MapOverview).
const LAYERS := ["blueprint", "grid", "floors", "edges", "icons", "memos", "foes", "party"]
## FOE 원(M3 A6c, 설계 §5.2, 원작 jp_guide5_img3): 칸 한 변 × 0.36 반지름의 위협 색 원, 흰 테 1.5px, 바라보는 쪽 흰 삼각형(파티 모양 × 0.8).
const FOE_RADIUS := 0.36
const FOE_RIM := Color(1, 1, 1)
const FOE_RIM_W := 1.5
const FOE_TRI_SCALE := 0.8

## 마지막 그리기의 층 차례와 그린 FOE(시험·디버그, 교훈 2): [{id, cell, color, facing}].
var drawn_layers: Array[String] = []
var drawn_foes: Array[Dictionary] = []


## drawn_foes 를 JSON 으로 옮길 수 있게(디버그 스냅숏): [{id, cell: [x, y], color: "rrggbb", facing}].
func foes_info() -> Array:
	return drawn_foes.map(func(d: Dictionary) -> Dictionary: return {"id": d["id"], "cell": [d["cell"].x, d["cell"].y],
		"color": (d["color"] as Color).to_html(false), "facing": d["facing"]})


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	drawn_layers.clear()
	drawn_foes.clear()
	if state == null:
		return
	for layer in LAYERS:
		drawn_layers.append(layer)
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
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), _ga(GRID_MAJOR_OUT if major else GRID_OUT), 1.0)
		if x >= 0 and x <= geo.width:
			draw_line(Vector2(sx, fr.position.y), Vector2(sx, fr.end.y), _ga(GRID_MAJOR_IN if major else GRID), 1.0)
	for y in range(floori(a.y), ceili(b.y) + 1):
		var sy := geo.to_screen(Vector2(0, y)).y
		var major := posmod(y, GRID_MAJOR) == 0
		draw_line(Vector2(0, sy), Vector2(size.x, sy), _ga(GRID_MAJOR_OUT if major else GRID_OUT), 1.0)
		if y >= 0 and y <= geo.height:
			draw_line(Vector2(fr.position.x, sy), Vector2(fr.end.x, sy), _ga(GRID_MAJOR_IN if major else GRID), 1.0)


func _ga(c: Color) -> Color:
	return Color(c, c.a * grid_alpha)


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
	draw_colored_polygon(_arrow(state.party.at, state.party.facing, 1.0), PARTY_COLOR)


## 칸 c 가운데의 facing 쪽 삼각형(파티 표시 모양, mult 배).
func _arrow(c: Vector2i, facing: int, mult: float) -> PackedVector2Array:
	var px := geo.cell_px
	var center := geo.cell_rect(c).get_center()
	var rot := facing * PI / 2.0
	var tri := PackedVector2Array()
	for v in [Vector2(0, -0.34), Vector2(-0.26, 0.26), Vector2(0.26, 0.26)]:
		tri.append(center + (v * px * mult).rotated(rot))
	return tri


## 지금 층의 살아 있는 FOE 모두(설계 §8 Q8: 가 본 곳이 아니어도, 쓰러진 것은 빼고). 네 지도(그리기 격자·층 전체·미니맵·전투 미니맵)가 같은 층.
func _draw_foes() -> void:
	for id in FoeLook.living(state):
		var fs: WorldState.FoeState = state.world.foes[id]
		var col := FoeLook.color(state, id)
		var center := geo.cell_rect(fs.at).get_center()
		var r := geo.cell_px * FOE_RADIUS
		draw_circle(center, r, col)
		draw_arc(center, r, 0.0, TAU, 24, FOE_RIM, FOE_RIM_W, true)
		draw_colored_polygon(_arrow(fs.at, fs.facing, FOE_TRI_SCALE), FOE_RIM)
		drawn_foes.append({"id": id, "cell": fs.at, "color": col, "facing": fs.facing})


# ---- 디버그·시험용 위치(이 컨트롤 안 좌표) ----

func cell_point(c: Vector2i) -> Vector2:
	return geo.cell_rect(c).get_center()


func edge_point(e: Vector3i) -> Vector2:
	var seg := geo.edge_segment(e)
	return (seg[0] + seg[1]) / 2.0
