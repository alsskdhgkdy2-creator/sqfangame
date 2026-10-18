## 파티 위치·방향과 대원 상태(HP·TP·성장 값). max_hp·max_tp 는 성장 묶음(GrowthRules.profile)에서 계산해 담아 둔다(저장하지 않는다).
## 전투 중에도 HP·TP는 여기에만 있다(06 §8.1). 성장 값은 GrowthRules 만 바꾼다(07 §8.1).
class_name PartyState
extends RefCounted


class Member:
	extends RefCounted
	var id := ""
	var max_hp := 1
	var hp := 1
	var max_tp := 0
	var tp := 0
	## 성장(07 §8.1): 레벨, 누적 경험치, 배운 스킬(스킬 ID → 레벨, 패시브 포함), 장비 칸 넷(빈 칸 "").
	var level := 1
	var exp := 0
	var skills := {}
	var equip: Array[String] = ["", "", "", ""]

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
