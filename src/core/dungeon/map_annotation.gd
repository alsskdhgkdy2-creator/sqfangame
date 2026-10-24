## 플레이어 지도 그림과 자동 기록. 이동 판정에 쓰이지 않는다.
## 플레이어 편집은 끌기(stroke) 단위로 실행 취소한다. 자동 기록은 실행 취소 기록에 들어가지 않는다.
class_name MapAnnotation
extends RefCounted

const MAX_UNDO := 100
const MEMO_MAX := 40
const AUTO_COLOR := 0
const EDGE_MARKS := ["wall", "door"]
const ICONS := ["door", "shortcut", "stairs_up", "stairs_down", "chest", "gather", "event", "danger", "foe", "arrow", "warp", "pin"]

var width := 0
var height := 0
var floors := {}  # Vector2i → 0~4
var edges := {}  # Vector3i → "wall"·"door"
var auto_edges := {}  # Vector3i → true (자동 기록이 쓴 경계 표시)
var icons := {}  # Vector2i → {"type": String, "dir": int(arrow만, 아니면 -1)}
var memos := {}  # Vector2i → String
## 표시가 바뀔 때마다 오른다(편집·되돌리기·획 취소·자동 기록). 저장하지 않는다. 화면이 지도 보기를 다시 그릴지 본다.
var version := 0

var _undo: Array = []  # 단계마다 [{layer, key, had, old, old_auto}]
var _stroke: Array = []
var _stroke_seen := {}
var _stroke_open := false


func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h


# ---- 끌기 단위 ----

## 끌기 시작. 끝날 때까지의 편집이 한 단계가 된다.
func begin_stroke() -> void:
	_flush_stroke()
	_stroke_open = true


## 끌기를 끝낸다. 실제로 바뀐 것이 있어 실행 취소 한 단계가 생겼으면 true(자동 저장 판단용).
func end_stroke() -> bool:
	_stroke_open = false
	return _flush_stroke()


## 아직 확정하지 않은 끌기를 되돌리고 버린다(두 손가락 전환 등). 실행 취소 기록에 넣지 않는다.
func cancel_stroke() -> void:
	_revert(_stroke)
	_stroke = []
	_stroke_seen = {}
	_stroke_open = false


func can_undo() -> bool:
	return not _undo.is_empty()


func undo_depth() -> int:
	return _undo.size()


## 마지막 단계의 편집이 바꾼 항목만 이전 값으로 되돌린다.
func undo() -> bool:
	if _stroke_open:
		end_stroke()
	if _undo.is_empty():
		return false
	_revert(_undo.pop_back())
	return true


# ---- 플레이어 편집 (성공하면 true) ----

## 지금 경계 표시("wall"·"door"), 없으면 "". 벽 선 끌기에서 첫 경계를 켰는지 끌지 정할 때 쓴다.
func edge_mark(e: Vector3i) -> String:
	return edges.get(e, "")


## 같은 표시가 있으면(자동 표시 포함) 끄고, 아니면 켠다.
func toggle_edge(e: Vector3i, mark: String) -> bool:
	if edges.get(e, "") == mark:
		return erase_edge(e)
	return paint_edge(e, mark)


## 켜기: 경계에 표시를 쓴다.
func paint_edge(e: Vector3i, mark: String) -> bool:
	if not _edge_ok(e) or not EDGE_MARKS.has(mark):
		return false
	_edit("edges", e, mark)
	return true


## 끄기: 그 표시가 있을 때만 지운다(다른 표시는 둔다).
func unpaint_edge(e: Vector3i, mark: String) -> bool:
	if not _edge_ok(e) or not EDGE_MARKS.has(mark):
		return false
	if edges.get(e, "") == mark:
		_edit("edges", e, null)
	return true


## 지우개: 경계 표시를 종류와 상관없이 지운다.
func erase_edge(e: Vector3i) -> bool:
	if not _edge_ok(e):
		return false
	_edit("edges", e, null)
	return true


func paint_floor(c: Vector2i, color: int) -> bool:
	if not _cell_ok(c) or color < 1 or color > 4:
		return false
	_edit("floors", c, color)
	return true


## arrow는 방향(Dir)이 있어야 하고, 다른 아이콘은 방향을 무시한다.
func set_icon(c: Vector2i, type: String, dir: int = -1) -> bool:
	if not _cell_ok(c) or not ICONS.has(type):
		return false
	if type == "arrow" and (dir < 0 or dir > 3):
		return false
	_edit("icons", c, {"type": type, "dir": dir if type == "arrow" else -1})
	return true


## 빈 문자열이면 지운다. 40자를 넘으면 거부.
func set_memo(c: Vector2i, text: String) -> bool:
	if not _cell_ok(c) or text.length() > MEMO_MAX:
		return false
	_edit("memos", c, null if text.is_empty() else text)
	return true


## 칸의 색·아이콘·메모를 한 단계로 지운다.
func erase_cell(c: Vector2i) -> bool:
	if not _cell_ok(c):
		return false
	var single := not _stroke_open
	if single:
		begin_stroke()
	_edit("floors", c, null)
	_edit("icons", c, null)
	_edit("memos", c, null)
	if single:
		end_stroke()
	return true


# ---- 자동 기록 (실행 취소에 들어가지 않음) ----

## 바닥 색이 비어 있으면 자동 색 0.
func auto_floor(c: Vector2i) -> void:
	if _cell_ok(c) and not floors.has(c):
		floors[c] = AUTO_COLOR
		version += 1


## 경계 표시가 비어 있으면 쓰고 자동 목록에 넣는다.
func auto_edge(e: Vector3i, mark: String) -> void:
	if _edge_ok(e) and not edges.has(e):
		edges[e] = mark
		auto_edges[e] = true
		version += 1


## 자동으로 쓴 벽 표시만 지운다(찾은 숨은 통로).
func clear_auto_wall(e: Vector3i) -> void:
	if auto_edges.has(e) and edges.get(e, "") == "wall":
		edges.erase(e)
		auto_edges.erase(e)
		version += 1


# ---- 내부 ----

func _cell_ok(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func _edge_ok(e: Vector3i) -> bool:
	if e.z == 0:
		return e.x >= 0 and e.x < width and e.y >= 0 and e.y <= height
	return e.z == 1 and e.x >= 0 and e.x <= width and e.y >= 0 and e.y < height


func _layer(name: String) -> Dictionary:
	match name:
		"floors":
			return floors
		"edges":
			return edges
		"icons":
			return icons
		_:
			return memos


## 값을 바꾸고 첫 이전 값을 지금 끌기에 남긴다. 경계를 고치면 자동 목록에서 뺀다.
func _edit(layer: String, key: Variant, value: Variant) -> void:
	var d := _layer(layer)
	var was_auto := layer == "edges" and auto_edges.has(key)
	if d.get(key) == value and not was_auto:
		return
	var tag := "%s|%s" % [layer, key]
	if not _stroke_seen.has(tag):
		_stroke_seen[tag] = true
		_stroke.append({"layer": layer, "key": key, "had": d.has(key), "old": d.get(key), "old_auto": was_auto})
	if value == null:
		d.erase(key)
	else:
		d[key] = value
	if layer == "edges":
		auto_edges.erase(key)
	version += 1
	if not _stroke_open:
		_flush_stroke()


## 지금 끌기를 실행 취소 기록에 넣는다. 결과적으로 바뀐 것이 없으면 넣지 않고 false.
func _flush_stroke() -> bool:
	var changed := _net_changed(_stroke)
	if changed:
		_undo.append(_stroke)
		if _undo.size() > MAX_UNDO:
			_undo.pop_front()
	_stroke = []
	_stroke_seen = {}
	return changed


## 기록한 항목 가운데 지금 값(경계는 자동 여부 포함)이 이전과 다른 것이 있는지.
func _net_changed(changes: Array) -> bool:
	for ch in changes:
		var d := _layer(ch["layer"])
		if d.has(ch["key"]) != ch["had"] or (ch["had"] and d[ch["key"]] != ch["old"]):
			return true
		if ch["layer"] == "edges" and auto_edges.has(ch["key"]) != ch["old_auto"]:
			return true
	return false


func _revert(changes: Array) -> void:
	if not changes.is_empty():
		version += 1
	for i in range(changes.size() - 1, -1, -1):
		var ch: Dictionary = changes[i]
		var d := _layer(ch["layer"])
		if ch["had"]:
			d[ch["key"]] = ch["old"]
		else:
			d.erase(ch["key"])
		if ch["layer"] == "edges":
			if ch["old_auto"]:
				auto_edges[ch["key"]] = true
			else:
				auto_edges.erase(ch["key"])
