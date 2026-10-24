## 적 영역(06 §9.1, M2.7 R3: 원작 HD 1868180_0e36b17e·gw_26 처럼 명령 목록 오른쪽 영역 가운데, 파티 카드 위).
## 후열은 위쪽(칸 BACK_SIZE), 전열은 아래쪽(칸 FRONT_SIZE), 줄마다 가운데 정렬. 두 줄 사이는 HP 표가 뜰 높이만큼 띄운다
## (전열 적 위의 HP 표가 후열 칸을 덮지 않는다). 칸 자리는 단계(명령·대상·연출·결과)와 상관없이 같다.
## HP 표(원작 jp_guide5_img1·gw_31): 대상 고르기 중 커서가 있는 적 위에 「HP」 막대(숫자 없음, D13)와 아래를 가리키는 삼각형.
## 표는 칸들 뒤(트리 마지막)에 그리는 장식이고 누르기를 받지 않는다.
class_name EnemyArea
extends Control

const BACK_SIZE := 150.0
const FRONT_SIZE := 160.0
const GAP := 20.0
const BACK_TOP := 0.0
## HP 표: 크기, 삼각형 높이, 칸 위에 표가 차지하는 높이 전체(삼각형 포함), 글자 크기.
const TAG := Vector2(112, 24)
const TAG_TRI := 9.0
const TAG_SPACE := 38.0
const TAG_FS := 15
## 전열 위 = 후열 아래 + HP 표 자리.
const FRONT_TOP := BACK_SIZE + TAG_SPACE

var cards: Array[BattleCard] = []
## HP 표를 그리는 장식(칸들 위, 누르기 없음).
var hp_tag: Control


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
	if hp_tag == null:
		hp_tag = Control.new()
		hp_tag.name = "HpTag"
		hp_tag.mouse_filter = MOUSE_FILTER_IGNORE
		hp_tag.draw.connect(_draw_tag)
	else:
		remove_child(hp_tag)
	add_child(hp_tag)
	layout()


func layout() -> void:
	if hp_tag != null:
		hp_tag.position = Vector2.ZERO
		hp_tag.size = size
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


## HP 표가 붙은 적(대상 고르기 중 커서가 있고 살아 있는 적). 없으면 null.
func tagged() -> BattleCard:
	for c in cards:
		if c.cursor and (c.target_mark == "valid" or c.target_mark == "lit") and c.unit() != null and c.unit().alive():
			return c
	return null


## HP 표 자리(이 영역 기준, 삼각형 제외). 붙은 적이 없으면 빈 Rect2.
func tag_rect() -> Rect2:
	var c := tagged()
	if c == null:
		return Rect2()
	return Rect2(roundf(c.position.x + (c.size.x - TAG.x) / 2.0), c.position.y - TAG_SPACE + 2.0, TAG.x, TAG.y)


func refresh_tag() -> void:
	if hp_tag != null:
		hp_tag.queue_redraw()


func _draw_tag() -> void:
	var c := tagged()
	if c == null:
		return
	var u := c.unit()
	var r := tag_rect()
	var font := get_theme_default_font()
	hp_tag.draw_rect(r, UiTheme.HINT_PILL)
	hp_tag.draw_rect(r, UiTheme.CARD_ACTIVE, false, 2.0)
	hp_tag.draw_string(font, Vector2(r.position.x + 6.0, r.get_center().y + TAG_FS * 0.36), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FS,
		UiTheme.BATTLE_BANNER_TEXT)
	var bar := Rect2(r.position.x + 34.0, r.get_center().y - 4.0, r.size.x - 42.0, 8.0)
	var shown := c.shown_hp if c.shown_hp >= 0.0 else float(u.hp)
	UiTheme.draw_gauge(hp_tag, bar, shown / maxf(1.0, float(u.max_hp)), UiTheme.CARD_HP_FROM, UiTheme.CARD_HP_TO)
	var cx := r.get_center().x
	var ty := r.end.y + 2.0
	hp_tag.draw_colored_polygon(PackedVector2Array([Vector2(cx - TAG_TRI, ty), Vector2(cx + TAG_TRI, ty), Vector2(cx, ty + TAG_TRI)]),
		UiTheme.CARD_HP_FROM)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		layout()
