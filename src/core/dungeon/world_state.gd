## 원정 뒤에도 남는 세계 변화(한 층): 열린 지름길, 찾은 숨은 통로, 연 잠긴 문·연 보물상자(M3 A3). 규칙 함수만 바꾼다.
class_name WorldState
extends RefCounted

var shortcuts_open := {}  # Vector3i → true
var passages_found := {}  # Vector3i → true
var locks_open := {}  # Vector3i → true (열쇠 문만, 봉인 문은 열리지 않는다)
var chests_opened := {}  # 상자 id String → true


func is_shortcut_open(e: Vector3i) -> bool:
	return shortcuts_open.has(e)


func open_shortcut(e: Vector3i) -> void:
	shortcuts_open[e] = true


func is_passage_found(e: Vector3i) -> bool:
	return passages_found.has(e)


func find_passage(e: Vector3i) -> void:
	passages_found[e] = true


func is_lock_open(e: Vector3i) -> bool:
	return locks_open.has(e)


func open_lock(e: Vector3i) -> void:
	locks_open[e] = true


func is_chest_opened(id: String) -> bool:
	return chests_opened.has(id)


func open_chest(id: String) -> void:
	chests_opened[id] = true


func copy() -> WorldState:
	var w := WorldState.new()
	w.shortcuts_open = shortcuts_open.duplicate()
	w.passages_found = passages_found.duplicate()
	w.locks_open = locks_open.duplicate()
	w.chests_opened = chests_opened.duplicate()
	return w
