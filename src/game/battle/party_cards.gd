## 파티 카드(06 §9.1, M2.7 R3: 원작 HD 1868180_0e36b17e·1810820_1f51fd75). 화면 아래 가운데에 두 줄로 겹치지 않게 뜬다:
## 윗줄 = 편성 전열, 아랫줄 = 편성 후열, 줄마다 가운데 정렬(그래서 두 줄이 엇갈린다). 카드 233×80(원작 233×67, 누르는 칸 64 이상이 되게
## 키웠다). 열 문패는 없다(원작에 없다). 카드 자리는 편성 열로 정하고 전투 중에 바뀌지 않는다(전열이 모두 쓰러져도 그대로).
class_name PartyCards
extends Control

const CARD := Vector2(233, 80)
## 카드 사이(가로)·줄 사이·화면 아래 여백.
const GAP := 6.0
const ROW_GAP := 4.0
const BOTTOM := 8.0
## 이 판 전체 높이(두 줄 + 아래 여백). 전투 층이 화면 아래에 이 높이로 붙인다.
const HEIGHT := CARD.y * 2.0 + ROW_GAP + BOTTOM

var display: BattleDisplay
var cards: Array[BattleCard] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(d: BattleDisplay, class_ids: Array[String]) -> void:
	display = d
	for c in cards:
		remove_child(c)
		c.queue_free()
	cards.clear()
	for u in d.party:
		var c := BattleCard.new()
		c.name = "Member_%d" % u.slot
		c.display = d
		c.unit_ref = u.ref()
		c.class_id = class_ids[u.slot] if u.slot < class_ids.size() else ""
		add_child(c)
		cards.append(c)
	layout()


## 윗줄(편성 전열)인지.
func top_row(slot: int) -> bool:
	return display != null and display.party[slot].row == "front"


func layout() -> void:
	var n := cards.size()
	if n == 0:
		return
	for top in [true, false]:
		var list: Array[BattleCard] = []
		for i in n:
			if top_row(i) == top:
				list.append(cards[i])
		var total := list.size() * CARD.x + maxf(0.0, list.size() - 1.0) * GAP
		var x := roundf((size.x - total) / 2.0)
		var y := size.y - BOTTOM - CARD.y - (CARD.y + ROW_GAP if top else 0.0)
		for c in list:
			c.size = CARD
			c.position = Vector2(x, y)
			x += CARD.x + GAP


## 쓰러짐·소생 뒤(자리는 그대로, 다시 그리기만).
func refresh() -> void:
	layout()


func card(slot: int) -> BattleCard:
	return cards[slot] if slot >= 0 and slot < cards.size() else null


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
