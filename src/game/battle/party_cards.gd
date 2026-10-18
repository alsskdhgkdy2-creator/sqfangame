## 파티 카드(06 §9.1, M2.6 2.5단계 층 겹침 · research 04): 대원 5장이 전투 바탕 위 아래쪽에 간격을 두고 뜬다(반투명 채움,
## 카드 사이·위로 바탕이 보인다). 열은 높낮이로 보인다: 실효 전열 카드는 STAGGER 만큼 위로 올라 있다. 같은 열이 이어지는
## 카드 묶음마다 「전열」「후열」 문패가 첫 카드의 위 가장자리에 걸친다(문패는 장식: 누르기를 받지 않는다).
## 실효 열이 바뀌면(전열이 모두 쓰러져 후열이 앞으로 나오면) 뒤 둘의 문패·높이도 전열이 된다(refresh).
class_name PartyCards
extends Control

## 카드 사이·양옆·아래 여백. 1280×720 에서 카드 폭 244·높이 175 를 지킨다(대원 최대 상태 딱지 10개가 세 줄에 다 들어가는 크기).
const GAP := 8.0
const SIDE := 12.0
const BOTTOM := 4.0
## 전열 카드를 올리는 높이.
const STAGGER := 10.0
## 카드 가장 큰 높이: 넓은 화면에서도 카드가 길어지지 않고 아래에 붙는다(위로 바탕이 보인다).
const CARD_MAX_H := 190.0
const PLATE_FS := 15
## 문패를 카드 왼쪽 끝에서 들이는 폭.
const PLATE_INSET := 10.0

var display: BattleDisplay
var cards: Array[BattleCard] = []
## 카드마다 문패 하나(같은 열 묶음의 첫 카드 것만 보인다).
var plates: Array[UiPlate] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func setup(d: BattleDisplay, class_ids: Array[String]) -> void:
	display = d
	for c in cards:
		remove_child(c)
		c.queue_free()
	for p in plates:
		remove_child(p)
		p.queue_free()
	cards.clear()
	plates.clear()
	for u in d.party:
		var c := BattleCard.new()
		c.name = "Member_%d" % u.slot
		c.display = d
		c.unit_ref = u.ref()
		c.class_id = class_ids[u.slot] if u.slot < class_ids.size() else ""
		add_child(c)
		cards.append(c)
	# 문패는 카드 뒤에 붙인다(트리 순서 = 그리는 순서: 카드 위에 보인다).
	for i in cards.size():
		var p := UiPlate.new()
		p.name = "RowPlate_%d" % i
		p.font_size = PLATE_FS
		p.color = UiTheme.TEXT
		add_child(p)
		plates.append(p)
	layout()


## 카드 높이(모든 카드가 같다).
func card_height() -> float:
	return minf(CARD_MAX_H, size.y - BOTTOM - STAGGER - UiTheme.PLATE_H / 2.0)


## 실효 전열인지(올려 놓는 카드).
func raised(slot: int) -> bool:
	return display != null and display.effective_row(display.party[slot]) == "front"


func layout() -> void:
	var n := cards.size()
	if n == 0:
		return
	var w := floorf((size.x - 2.0 * SIDE - GAP * (n - 1)) / n)
	var h := card_height()
	var back_top := size.y - BOTTOM - h
	for i in n:
		cards[i].size = Vector2(w, h)
		cards[i].position = Vector2(SIDE + i * (w + GAP), back_top - (STAGGER if raised(i) else 0.0))
	var i := 0
	while i < n:
		var label := band_of(i)
		var j := i
		while j + 1 < n and band_of(j + 1) == label:
			j += 1
		for k in range(i, j + 1):
			plates[k].visible = k == i
		plates[i].text = label
		plates[i].position = cards[i].position + Vector2(PLATE_INSET, -UiTheme.PLATE_H / 2.0)
		i = j + 1


## 실효 열이 바뀌었을 수 있을 때(쓰러짐·소생 뒤).
func refresh() -> void:
	layout()


func card(slot: int) -> BattleCard:
	return cards[slot] if slot >= 0 and slot < cards.size() else null


## 문패 글자(시험용): 칸마다 「전열」/「후열」.
func band_of(slot: int) -> String:
	var u := display.party[slot]
	return display.texts.t("battle.ui.front" if display.effective_row(u) == "front" else "battle.ui.back_row")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
