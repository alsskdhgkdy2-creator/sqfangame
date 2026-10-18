## 적 영역(06 §9.1): 후열은 위쪽(칸 150×150), 전열은 아래쪽(칸 200×200), 줄마다 가운데 정렬.
## 칸이 겹치면 뒤 칸의 누르는 자리가 가려지므로 두 줄을 위아래로 나눠 둔다(명세의 y 96~260·210~420 대신 68~218·220~420).
class_name EnemyArea
extends Control

const BACK_SIZE := 150.0
const FRONT_SIZE := 200.0
const GAP := 24.0
const BACK_TOP := 4.0
const FRONT_TOP := 156.0

var cards: Array[BattleCard] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(display: BattleDisplay) -> void:
	for c in cards:
		remove_child(c)
		c.queue_free()
	cards.clear()
	for u in display.enemies:
		var c := BattleCard.new()
		c.name = "Enemy_%d" % u.slot
		c.display = display
		c.unit_ref = u.ref()
		add_child(c)
		cards.append(c)
	layout()


func layout() -> void:
	if cards.is_empty():
		return
	var display := cards[0].display
	for row in ["back", "front"]:
		var list: Array[BattleCard] = []
		for c in cards:
			if display.enemies[c.unit_ref["slot"]].row == row:
				list.append(c)
		var s := BACK_SIZE if row == "back" else FRONT_SIZE
		var total := list.size() * s + maxf(0.0, list.size() - 1.0) * GAP
		var x := roundf((size.x - total) / 2.0)
		for c in list:
			c.size = Vector2(s, s)
			c.position = Vector2(x, BACK_TOP if row == "back" else FRONT_TOP)
			x += s + GAP


func card(slot: int) -> BattleCard:
	return cards[slot] if slot >= 0 and slot < cards.size() else null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
