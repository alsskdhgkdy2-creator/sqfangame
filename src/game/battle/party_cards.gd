## 파티 줄(06 §9.1): 대원 5칸(간격 8). 앞 셋 위에 「전열」, 뒤 둘 위에 「후열」 띠.
## 실효 열이 바뀌면(전열이 모두 쓰러져 후열이 앞으로 나오면) 뒤 둘의 띠도 「전열」이 된다.
class_name PartyCards
extends Control

const GAP := 8.0
const BAND_H := 24.0
const CARD_TOP := 28.0

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


func layout() -> void:
	var n := cards.size()
	if n == 0:
		return
	var w := floorf((size.x - GAP * (n + 1)) / n)
	for i in n:
		cards[i].size = Vector2(w, size.y - CARD_TOP)
		cards[i].position = Vector2(GAP + i * (w + GAP), CARD_TOP)
	queue_redraw()


func card(slot: int) -> BattleCard:
	return cards[slot] if slot >= 0 and slot < cards.size() else null


## 띠 글자(시험용): 칸마다 「전열」/「후열」.
func band_of(slot: int) -> String:
	var u := display.party[slot]
	return display.texts.t("battle.ui.front" if display.effective_row(u) == "front" else "battle.ui.back_row")


func _draw() -> void:
	if display == null or cards.is_empty():
		return
	var font := get_theme_default_font()
	# 같은 띠 글자가 이어지는 칸끼리 띠 하나.
	var i := 0
	while i < cards.size():
		var label := band_of(i)
		var j := i
		while j + 1 < cards.size() and display.party[j + 1].row == display.party[i].row:
			j += 1
		var x0 := cards[i].position.x
		var x1 := cards[j].position.x + cards[j].size.x
		var front := label == display.texts.t("battle.ui.front")
		var col := Color(0.25, 0.5, 0.6, 0.85) if front else Color(0.3, 0.3, 0.45, 0.85)
		draw_rect(Rect2(x0, 2, x1 - x0, BAND_H - 4), col)
		draw_string(font, Vector2(x0 + 10, BAND_H - 7), label, HORIZONTAL_ALIGNMENT_LEFT, x1 - x0 - 20, 15, Color(0.92, 0.97, 1.0))
		i = j + 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
