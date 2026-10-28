## 파티 위치·방향과 대원 상태(HP·TP·성장 값). max_hp·max_tp 는 성장 묶음(GrowthRules.profile)에서 계산해 담아 둔다(저장하지 않는다).
## 전투 중에도 HP·TP는 여기에만 있다(06 §8.1). 성장 값은 GrowthRules 만 바꾼다(07 §8.1).
## members 는 파티(칸 순서, M3 A7): 1~5명, 전열이 모두 후열보다 앞, 열마다 3명까지. 길드에만 있는 대원은 ExplorationState.guild 에 있다.
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
	## 길드 대원(M3 A7): 직업 ID, 이름(등록한 이름, 비면 name_key 의 글), 기본 다섯의 이름 키(아니면 ""), 외형(0~1), 열(front·back).
	## 길드에 있는 대원의 row 는 파티로 돌아올 때의 열이다.
	var class_id := ""
	var name := ""
	var name_key := ""
	var look := 0
	var row := "front"

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
