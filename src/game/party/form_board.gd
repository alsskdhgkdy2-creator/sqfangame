## 편성 판(M3 A7c, 설계 §5.6·§4.1b, D28 공용 부품): 원작 GAME Watch 편성 화면(gw_13)의 가운데 판. 「전열」 칸 셋 · 「후열」 칸 셋과
## 그 아래 「결정」 알약, 알약 아래 커서 대원의 HP·TP 카드. 길드 「편성과 순서」(등록부 목록이 옆에 붙는다)와 캠프 「대열」(목록 없음)이 같이 쓴다.
## 초안은 화면 것이다(front·back 은 ID 목록, 열마다 앞으로 채운다: 가운데 빈칸은 남지 않는다 — 원작과 다른 점, 설계 §4.1).
## 칸 번호: 0~2 전열, 3~5 후열. 커서 6 = 「결정」. held 는 고른 칸(캠프: 바꿀 첫 칸, 길드: 등록부에서 넣을 칸), 없으면 -1.
## 누르기는 route(kind, arg) 하나로 보낸다: ["slot", 칸] · ["decide", null]. 받을지는 화면 입구가 정한다.
## 그림: 판 테(ListParts.draw_panel "tree")·열 이름은 이 컨트롤, 칸 줄은 ListButton(부품 H 줄), 「결정」은 ListButton 알약, 카드는 FormCard.
class_name FormBoard
extends Control

## 판(이 컨트롤 기준). 칸 줄은 판 안 오른쪽 300×64, 열 이름 칸은 그 왼쪽.
const SIZE := Vector2(440, 594)
const PANEL := Rect2(0, 0, 440, 436)
const LABEL := Rect2(16, 0, 100, 64)
const SLOT_X := 124.0
const SLOT_W := 300.0
const SLOT_H := 64.0
const FRONT_TOP := 12.0
const BACK_TOP := 224.0
const SLOT_GAP := 4.0
const DECIDE := Rect2(100, 444, 240, 64)
const CARD := Rect2(103, 514, 233, 80)
const LABEL_FS := 22
const ROW_MAX := BattleLimits.ROW_MAX
const SLOTS := 6
const DECIDE_AT := 6

var route: Callable
var texts: TextDb
## 초안(ID, 열마다 앞으로 채움).
var front: Array[String] = []
var back: Array[String] = []
## ID → {name, hp, max_hp, tp, max_tp, class, color, icon}(그림 글).
var info := {}
var cursor := 0
var held := -1
var slots: Array[ListButton] = []
var decide_button: ListButton
var card: FormCard


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	custom_minimum_size = SIZE


func setup(text_db: TextDb) -> void:
	texts = text_db
	for i in SLOTS:
		var b := ListButton.new()
		b.name = "FormSlot_%d" % i
		b.position = slot_rect(i).position
		b.size = slot_rect(i).size
		b.activated.connect(func() -> void: _press("slot", i))
		add_child(b)
		slots.append(b)
	decide_button = ListButton.new()
	decide_button.name = "FormDecide"
	decide_button.style = "pill"
	decide_button.text = texts.t("guild.form.decide")
	decide_button.position = DECIDE.position
	decide_button.size = DECIDE.size
	decide_button.activated.connect(func() -> void: _press("decide", null))
	add_child(decide_button)
	card = FormCard.new()
	card.name = "FormCard"
	card.position = CARD.position
	card.size = CARD.size
	add_child(card)


func _press(kind: String, arg: Variant) -> void:
	if route.is_valid():
		route.call(kind, arg)


## 칸 i 의 자리(이 컨트롤 기준).
static func slot_rect(i: int) -> Rect2:
	var top := FRONT_TOP if i < ROW_MAX else BACK_TOP
	return Rect2(SLOT_X, top + (i % ROW_MAX) * (SLOT_H + SLOT_GAP), SLOT_W, SLOT_H)


## 열 이름 칸(0 전열, 1 후열).
static func label_rect(row: int) -> Rect2:
	var r := slot_rect(row * ROW_MAX)
	return Rect2(LABEL.position.x, r.position.y, LABEL.size.x, SLOT_H * ROW_MAX + SLOT_GAP * (ROW_MAX - 1))


# ---- 초안 ----

func load_draft(f: Array, b: Array) -> void:
	front.assign(f)
	back.assign(b)
	held = -1


## 칸 i 의 대원 ID(빈칸 "").
func id_at(i: int) -> String:
	var row := front if i < ROW_MAX else back
	var k := i % ROW_MAX
	return row[k] if k < row.size() else ""


## 대원 id 가 놓인 칸(없으면 -1).
func slot_of(id: String) -> int:
	if id.is_empty():
		return -1
	var k := front.find(id)
	if k >= 0:
		return k
	k = back.find(id)
	return ROW_MAX + k if k >= 0 else -1


func members() -> Array[String]:
	var out: Array[String] = []
	out.append_array(front)
	out.append_array(back)
	return out


## 두 칸을 바꾼다(캠프 대열·길드에서 판 위 대원끼리). 빈칸 쪽으로는 그 열 끝으로 옮긴다(열은 앞으로 채운다).
## 같은 열 안의 빈칸이면 그 열 끝으로. 바뀌었으면 true.
func swap(a: int, b: int) -> bool:
	var ia := id_at(a)
	var ib := id_at(b)
	if a == b or (ia.is_empty() and ib.is_empty()):
		return false
	if not ia.is_empty() and not ib.is_empty():
		_set_at(a, ib)
		_set_at(b, ia)
		return true
	var mover := ib if ia.is_empty() else ia
	var to := a if ia.is_empty() else b
	var to_row := front if to < ROW_MAX else back
	var from_row := front if slot_of(mover) < ROW_MAX else back
	if to_row != from_row and to_row.size() >= ROW_MAX:
		return false
	from_row.erase(mover)
	to_row.append(mover)
	return true


## 칸 i 에 대원 id 를 넣는다(길드: 등록부에서 고름). "" 면 그 칸을 비운다. 이미 판에 있는 대원이면 두 칸을 바꾼다.
## 판에 없는 대원이면 그 칸 대원을 내보내고 넣는다(빈칸이면 그 열 끝). 바뀌었으면 true.
func put(i: int, id: String) -> bool:
	var cur := id_at(i)
	if id.is_empty():
		if cur.is_empty():
			return false
		(front if i < ROW_MAX else back).erase(cur)
		return true
	var at := slot_of(id)
	if at >= 0:
		return swap(i, at)
	if cur.is_empty():
		var row := front if i < ROW_MAX else back
		if row.size() >= ROW_MAX:
			return false
		row.append(id)
		return true
	_set_at(i, id)
	return true


func _set_at(i: int, id: String) -> void:
	var row := front if i < ROW_MAX else back
	row[i % ROW_MAX] = id


# ---- 그리기 ----

## 칸·알약·카드를 초안·커서·고른 칸으로 다시 그린다. on 이 거짓이면 커서 표시를 하지 않는다(길드 등록부에 커서가 있을 때).
func refresh(on: bool = true) -> void:
	var empty := texts.t("guild.form.empty")
	for i in SLOTS:
		var b := slots[i]
		var id := id_at(i)
		var d: Dictionary = info.get(id, {})
		b.icon_name = str(d.get("icon", ""))
		b.show_row(str(d.get("name", "")) if not id.is_empty() else empty, "", "", id.is_empty())
		b.selected = on and cursor == i
		b.chosen = held == i
	decide_button.selected = on and cursor == DECIDE_AT
	var who := id_at(cursor) if cursor < SLOTS else ""
	card.show_member(info.get(who, {}), texts)
	queue_redraw()


func _draw() -> void:
	SheetParts.begin(self)
	ListParts.draw_panel(self, PANEL, "tree")
	for row in 2:
		var r := label_rect(row)
		SheetParts._text(self, Vector2(r.position.x, r.get_center().y + LABEL_FS * 0.36), texts.t("guild.form.front" if row == 0 else "guild.form.back"),
			LABEL_FS, Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


## 커서 대원의 HP·TP 카드(원작 gw_13 「결 정」 아래 카드, 파티 카드 색). 빈칸이면 비운다.
class FormCard:
	extends Control

	const FS := 18
	var d := {}
	var texts: TextDb

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func show_member(data: Dictionary, text_db: TextDb) -> void:
		d = data
		texts = text_db
		visible = not data.is_empty()
		queue_redraw()

	func _draw() -> void:
		SheetParts.begin(self)
		if d.is_empty():
			return
		var r := Rect2(Vector2.ZERO, size)
		SheetParts._fill(self, r, UiTheme.CMD_PLATE)
		SheetParts._fill(self, Rect2(r.position, Vector2(6, r.size.y)), d.get("color", Color.WHITE))
		SheetParts._text(self, Vector2(14, 24), str(d.get("name", "")), FS, UiTheme.CARD_TEXT, r.size.x - 20)
		var hp := "HP %d/%d" % [int(d.get("hp", 0)), int(d.get("max_hp", 0))]
		var tp := "TP %d/%d" % [int(d.get("tp", 0)), int(d.get("max_tp", 0))]
		SheetParts._text(self, Vector2(14, 50), hp, FS, UiTheme.CARD_TEXT, 110)
		SheetParts._text(self, Vector2(124, 50), tp, FS, UiTheme.CARD_TEXT, 105)
		var hb := Rect2(14, 58, 100, 8)
		var tb := Rect2(124, 58, 100, 8)
		UiTheme.draw_gauge(self, hb, float(d.get("hp", 0)) / maxf(1.0, float(d.get("max_hp", 1))), HpColor.of(int(d.get("hp", 0)), int(d.get("max_hp", 1))), UiTheme.CARD_TP)
		UiTheme.draw_gauge(self, tb, float(d.get("tp", 0)) / maxf(1.0, float(d.get("max_tp", 1))), UiTheme.CARD_TP, UiTheme.CARD_TP)
