## 파티 위치·방향과 대원 HP·TP. max_hp·max_tp는 정의 데이터에서 온다.
## 전투 중에도 HP·TP는 여기에만 있다(06 §8.1).
class_name PartyState
extends RefCounted


class Member:
	extends RefCounted
	var id := ""
	var max_hp := 1
	var hp := 1
	var max_tp := 0
	var tp := 0

	func _init(member_id: String = "", max_value: int = 1, value: int = 1, max_tp_value: int = 0, tp_value: int = 0) -> void:
		id = member_id
		max_hp = max_value
		hp = value
		max_tp = max_tp_value
		tp = tp_value

	func alive() -> bool:
		return hp > 0


var at := Vector2i.ZERO
var facing := Dir.N
var members: Array[Member] = []


func all_down() -> bool:
	for m in members:
		if m.alive():
			return false
	return true
