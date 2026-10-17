## 파티 위치·방향과 대원 HP. max_hp는 정의 데이터에서 온다.
class_name PartyState
extends RefCounted


class Member:
	extends RefCounted
	var id := ""
	var max_hp := 1
	var hp := 1

	func _init(member_id: String = "", max_value: int = 1, value: int = 1) -> void:
		id = member_id
		max_hp = max_value
		hp = value

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
