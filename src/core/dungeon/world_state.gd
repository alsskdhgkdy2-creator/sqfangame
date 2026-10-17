## 원정 뒤에도 남는 세계 변화: 열린 지름길, 찾은 숨은 통로. 규칙 함수만 바꾼다.
class_name WorldState
extends RefCounted

var shortcuts_open := {}  # Vector3i → true
var passages_found := {}  # Vector3i → true


func is_shortcut_open(e: Vector3i) -> bool:
	return shortcuts_open.has(e)


func open_shortcut(e: Vector3i) -> void:
	shortcuts_open[e] = true


func is_passage_found(e: Vector3i) -> bool:
	return passages_found.has(e)


func find_passage(e: Vector3i) -> void:
	passages_found[e] = true


func copy() -> WorldState:
	var w := WorldState.new()
	w.shortcuts_open = shortcuts_open.duplicate()
	w.passages_found = passages_found.duplicate()
	return w
