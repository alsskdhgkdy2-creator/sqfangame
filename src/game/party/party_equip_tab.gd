## 캠프 장비 화면(07 §9.9 E2-c, D27 ③, research 08 §5.1: 원작 I HD 장비 yt_eo1hd_04 를 좌우 그대로): 왼쪽은 상태 시트(SheetParts),
## 오른쪽은 칸·후보 목록 창(부품 H), 아래는 설명 상자(부품 I). 상점 틀(ShopFrame·CharPanel·EquipTotals)은 쓰지 않는다.
## 층(1280×720, 뒤 → 앞): 가운데 초상(직업색 실루엣, 그림은 M3. 왼쪽 열 464 ~ 목록 창 왼쪽 − 8 로 자른다) → 위 대원 띠(MemberHeader:
## 이름 탭 + 「Lv n」 + HP·TP, 오른쪽은 비어 있고 안내만 뜬다) → 왼쪽 열(상태와 같은 자리: 직업 문패·능력치 여섯 줄·공격·방어 두 줄·
## 장비 네 줄은 표시만) → 목록 창(x 840 ~ W − 8, y 130 부터 줄 단위) → 설명 상자(오른쪽 끝 W − 130, 왼쪽 끝 max(664, W − 863), y H − 197 ~ H − 8).
## 칸 고르기(목록 창 첫 단계): 줄 넷 Slot_k = 종류 아이콘(빈 칸은 빈 아이콘) + 장비 이름 또는 「비어 있음」. ↑↓ 칸 커서(돌지 않음), ←→·Q/E 대원,
## 선택·줄 누르기 = 그 칸 목록, 취소 = 뿌리.
## 목록: 원작 차례로 지금 낀 것(「E」) → 그 칸에 들어가는 가방 장비(낄 수 있는 것, 다음에 흐린 못 끼는 것) → 「빼기」(빈 아이콘) 맨 끝.
## 커서는 「E」 줄(없으면 첫 줄)에서 시작, ↑↓ 돌지 않고 커서 줄이 보이게 내린다. ←→ 흐림, Q/E 없음. 선택(줄 누르기도) = 장착
## (GrowthRules.equip → 자동 저장, 목록을 닫고 커서는 그 칸), 「빼기」 = 빼기, 「E」 줄 = 바꾸지 않고 닫기, 못 끼는 줄 = 이유 안내(목록 그대로).
## 취소 = 목록만 닫기. 대원이 바뀌면 목록을 닫는다.
## 왼쪽 열 값: 칸 고르기는 지금 값, 목록은 커서 줄로 바꾼 뒤 값(profile_if)을 바뀐 것만 ↑↓ 와 함께(「E」 줄·못 끼는 줄은 지금 값).
## 노랑 채움은 목록 창 커서 줄 하나(흐린 줄이면 흐린 커서 모양: 어두운 몸 + 노란 테, 채움 없음). 왼쪽 표지(mark)는 노란 테두리
## (칸 고르기 = 커서 칸, 목록 = 연 칸).
class_name PartyEquipTab
extends Control

const TOP_H := MemberHeader.H
## 목록 창: 왼쪽 끝 840(오른쪽 앵커 W − 8 에서 폭 432), 위 130. 아래 끝은 줄 단위로, 설명 상자 위 LIST_GAP 보다 내려가지 않는다.
const LIST_W := 432.0
const LIST_EDGE := 8.0
const LIST_Y := 130.0
const LIST_GAP := 23.0
## 설명 상자: 오른쪽 끝 W − 130(세로 「취소」「선택」 왼쪽 12), 폭 733 까지, 왼쪽 끝은 방향 십자(456~656) 오른쪽 664 보다 왼쪽으로 가지 않는다.
const DESC_EDGE := 130.0
const DESC_W := 733.0
const DESC_MIN_X := 664.0
const DESC_H := 189.0
const DESC_BOTTOM := 8.0
## 초상: 상태와 같은 가운데(W/2 + 20 ± 240), 왼쪽 열 끝 LEFT_W 와 목록 창 왼쪽 − PORTRAIT_GAP 사이로 자른다.
const PORTRAIT_GAP := 8.0
## 띠 오른쪽 안내(스킬 띠의 안내와 같은 글자): x 400 ~ W − 20.
const NOTE_X := 400.0
const NOTE_EDGE := 20.0

var menu: PartyMenu
## 칸 커서(0~3).
var cursor := 0
var list_open := false
## 목록 줄 커서.
var list_cursor := 0
var top: MemberHeader
var portrait: Control
var left: Control
var window: ListWindow
var list: PartyScroll
var desc: DescBox
var note_label: Label
var slot_rows: Array[ListButton] = []
var rows: Array[ListButton] = []
## 목록 줄 → 장비 ID("" = 빼기). 「E」 줄은 지금 낀 장비.
var row_items: Array[String] = []
## 목록 줄 → 막는 이유(growth.reason 코드, "" = 고를 수 있음). 「E」 줄은 "".
var row_block: Array[String] = []
## 「E」 줄 번호(지금 낀 것이 없으면 -1, 있으면 0).
var equipped_row := -1
## 마지막으로 그린 값(시험·디버그): name, class, class_color, level, hp, tp, stats{키: [지금, 바꾸면, 막대 비율]}, gear{키: [지금, 바꾸면]},
## equip[[아이콘, 이름, 비었는지]], mark(표지 칸), preview(바꾸면 값을 보이는지).
var drawn := {}
var _view_size := Vector2.ZERO


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# 트리 순서 = 그리는 순서(층 표): 초상 → 위 띠 → 왼쪽 열 → 목록 창 → 설명 상자 → 띠 안내.
	portrait = _deco("EquipPortrait", Vector2(0.5, 0), Vector2(0.5, 1), Vector4(-PartyStatusTab.PORTRAIT_HALF, TOP_H, PartyStatusTab.PORTRAIT_HALF, 0),
		_draw_portrait)
	top = MemberHeader.new()
	top.name = "EquipTop"
	add_child(top)
	top.build("Equip")
	top.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	left = _deco("EquipLeft", Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, PartyStatusTab.LEFT_W, 720), _draw_left)
	window = ListWindow.new()
	window.name = "EquipWindow"
	add_child(window)
	list = window.list
	list.name = "EquipList"
	list.resized.connect(_on_list_resized)
	for slot in BattleLimits.EQUIP_SLOTS:
		var b := _row_button("Slot_%d" % slot)
		b.activated.connect(func() -> void: menu.handle("slot", slot))
		b.position = window.row_rect(slot).position
		slot_rows.append(b)
	desc = DescBox.new()
	desc.name = "EquipDesc"
	add_child(desc)
	note_label = Label.new()
	note_label.name = "EquipNote"
	note_label.add_theme_font_size_override("font_size", 18)
	note_label.add_theme_color_override("font_color", MemberHeader.STRIP_ACCENT)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note_label.clip_text = true
	note_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(note_label)
	PartyMenu.place(note_label, Vector2(0, 0), Vector2(1, 0), Vector4(NOTE_X, MemberHeader.INFO_Y, -NOTE_EDGE, MemberHeader.INFO_Y + MemberHeader.INFO_H))


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4, painter: Callable) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	c.draw.connect(painter.bind(c))
	return c


func _row_button(n: String) -> ListButton:
	var b := ListButton.new()
	b.name = n
	b.scroller = list
	list.content.add_child(b)
	return b


## 보이는 곳 크기가 바뀌면(높은 화면 ↔ 낮은 화면) 줄을 다시 놓고 커서 줄을 보이게 한다.
func _on_list_resized() -> void:
	if list.size == _view_size:
		return
	_view_size = list.size
	if menu.state != null and visible:
		refresh()
		if list_open:
			_show(list_cursor)


func reset() -> void:
	cursor = 0
	close_list()


func member_changed() -> void:
	close_list()


func context() -> String:
	return "%s|%d" % [str(list_open), cursor if list_open else -1]


# ---- 자리(화면 크기 s, 시험도 같이 쓴다) ----

## 목록 창: 오른쪽 앵커(W − 8, 폭 432), 위 130 에서 줄 단위로, 설명 상자 위 LIST_GAP 까지(720 에서 다섯 줄).
static func list_rect(s: Vector2) -> Rect2:
	var desc_top := desc_rect(s).position.y
	var n := ListParts.rows_for(desc_top - LIST_GAP - LIST_Y)
	return Rect2(s.x - LIST_EDGE - LIST_W, LIST_Y, LIST_W, ListParts.list_height(n))


## 설명 상자: 오른쪽 끝 W − 130, 왼쪽 끝 max(664, W − 130 − 733), 아래 끝 H − 8.
static func desc_rect(s: Vector2) -> Rect2:
	var right := s.x - DESC_EDGE
	var x0 := maxf(DESC_MIN_X, right - DESC_W)
	return Rect2(x0, s.y - DESC_BOTTOM - DESC_H, right - x0, DESC_H)


## 초상 가로 자리: 상태와 같은 가운데 ± 240 을 왼쪽 열 끝과 목록 창 왼쪽 − 8 사이로 자른다.
static func portrait_span(s: Vector2) -> Vector2:
	var span := PartyStatusTab.portrait_span(s.x)
	return Vector2(span.x, minf(span.y, list_rect(s).position.x - PORTRAIT_GAP))


func place(s: Vector2) -> void:
	var span := portrait_span(s)
	portrait.offset_left = span.x - s.x / 2.0
	portrait.offset_right = span.y - s.x / 2.0
	var lr := list_rect(s)
	PartyMenu.place(window, Vector2(1, 0), Vector2(1, 0), Vector4(lr.position.x - s.x, lr.position.y, lr.end.x - s.x, lr.end.y))
	var dr := desc_rect(s)
	PartyMenu.place(desc, Vector2(1, 1), Vector2(1, 1), Vector4(dr.position.x - s.x, dr.position.y - s.y, dr.end.x - s.x, dr.end.y - s.y))
	if menu.state != null and visible:
		refresh()


func stat_rect(i: int) -> Rect2:
	return Rect2(PartyStatusTab.STAT_X, PartyStatusTab.STAT_Y + i * PartyStatusTab.STAT_PITCH, PartyStatusTab.STAT_W, PartyStatusTab.STAT_H)


func gear_row_rect(row: int) -> Rect2:
	return Rect2(PartyStatusTab.GEAR_X, PartyStatusTab.GEAR_Y + row * PartyStatusTab.GEAR_PITCH, PartyStatusTab.GEAR_W, PartyStatusTab.GEAR_H)


## 공격·방어 칸(BattleLimits.GEAR 차례): 공격·방어가 첫 줄, 마법 공격·마법 방어가 둘째 줄(상태와 같다).
func gear_rect(i: int) -> Rect2:
	var k: String = BattleLimits.GEAR[i]
	var row := 0 if k in ["atk", "def"] else 1
	var col := 0 if k in ["atk", "matk"] else 1
	return SheetParts.gear_cells(gear_row_rect(row))[col]["cell"]


func equip_rect(slot: int) -> Rect2:
	return Rect2(PartyStatusTab.EQUIP_X, PartyStatusTab.EQUIP_Y + slot * PartyStatusTab.EQUIP_PITCH, PartyStatusTab.EQUIP_W, PartyStatusTab.EQUIP_H)


func class_rect() -> Rect2:
	return PartyStatusTab.CLASS_PLATE


func class_extent() -> Rect2:
	return SheetParts.class_plate_extent(PartyStatusTab.CLASS_PLATE)


func portrait_rect() -> Rect2:
	return portrait.get_rect()


# ---- 입력 ----

func dispatch(kind: String, arg: Variant) -> bool:
	match kind:
		"slot":
			var slot := int(arg) if arg != null else -1
			if slot < 0 or slot >= BattleLimits.EQUIP_SLOTS or list_open:
				return false
			cursor = slot
			_open_list()
			return true
		"row":
			return _choose_row(int(arg) if arg != null else -1)
		"cursor":
			return _move(int(arg) if arg != null else 1)
		"confirm":
			if list_open:
				_show(list_cursor)
				return _choose_row(list_cursor)
			_open_list()
			return true
		"unequip":
			close_list()
			menu.apply(GrowthRules.equip(menu.state, menu.member, cursor, ""))
			return true
		"list_close":
			if not list_open:
				return false
			close_list()
			return true
	return false


## ↑↓ 하나(돌지 않음). 목록이면 커서 줄이 보이게 내린다. 끝에서는 커서를 옮기지 않고, 손으로 내려 커서 줄이 가려져 있으면 보이게만 한다.
func _move(d: int) -> bool:
	if not list_open:
		var to_slot := clampi(cursor + d, 0, BattleLimits.EQUIP_SLOTS - 1)
		if to_slot == cursor:
			return false
		cursor = to_slot
		return true
	var to := list_cursor + d
	if to < 0 or to >= row_items.size():
		if shown(list_cursor):
			return false
		_show(list_cursor)
		return true
	list_cursor = to
	_show(to)
	return true


func _show(j: int) -> void:
	var r := window.row_rect(j)
	list.ensure_visible(r.position.y, r.end.y)


## 목록 줄 j 가 보이는 곳 안에 다 있는지.
func shown(j: int) -> bool:
	return list.shows(window.row_rect(j))


func _open_list() -> void:
	list_open = true
	_build_rows()
	list_cursor = maxi(equipped_row, 0)
	list.scroll_to(0.0)
	_show(list_cursor)


func close_list() -> void:
	list_open = false
	list_cursor = 0
	if list != null:
		list.scroll_to(0.0)


## 줄 j 고르기: 「E」 줄이면 바꾸지 않고 닫는다(규칙을 부르지 않는다). 못 끼는 줄이면 이유만 알린다(목록 그대로).
## 낄 수 있는 줄·「빼기」면 GrowthRules.equip → 받아들여지면 목록을 닫고 커서는 그 칸.
func _choose_row(j: int) -> bool:
	if not list_open or j < 0 or j >= row_items.size():
		return false
	list_cursor = j
	if j == equipped_row:
		close_list()
		return true
	if not row_block[j].is_empty():
		menu.show_notice(menu.reason_text(row_block[j]))
		return true
	if menu.apply(GrowthRules.equip(menu.state, menu.member, cursor, row_items[j])):
		close_list()
	return true


## 지금 칸의 목록 줄(원작 차례): 「E」(지금 낀 것) → 그 칸 종류의 가방 장비(낄 수 있는 것, 다음에 못 끼는 것) → 「빼기」.
## 칸 종류가 다른 장비(칸 0 에 무기 아닌 것·칸 1~3 에 무기)는 넣지 않는다. 판정은 GrowthRules.equip_block.
func _build_rows() -> void:
	row_items.clear()
	row_block.clear()
	equipped_row = -1
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var bag := menu.state.gear_bag
	var cur: String = m.equip[cursor]
	if not cur.is_empty():
		equipped_row = 0
		row_items.append(cur)
		row_block.append("")
	var dim_items: Array[String] = []
	var dim_why: Array[String] = []
	for id in defs.battle.equipment_ids:
		if int(bag.get(id, 0)) < 1:
			continue
		if GrowthRules.slot_block(defs.battle, defs.class_of(i), m.equip, cursor, id) == "slot_kind":
			continue
		var why := GrowthRules.equip_block(defs, i, m, bag, cursor, id)
		if why.is_empty():
			row_items.append(id)
			row_block.append("")
		else:
			dim_items.append(id)
			dim_why.append(why)
	row_items.append_array(dim_items)
	row_block.append_array(dim_why)
	row_items.append("")
	row_block.append(GrowthRules.equip_block(defs, i, m, bag, cursor, ""))
	list_cursor = clampi(list_cursor, 0, row_items.size() - 1)


## 「선택」이 할 일이 있는지(늘 있다: 칸 = 목록 열기, 목록 = 장착·빼기·닫기·이유).
func can_confirm() -> bool:
	return true


# ---- 값 ----

func refresh() -> void:
	if menu.state == null:
		return
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var t := menu.texts
	if list_open:
		_build_rows()
	# 위 띠: 이름·Lv·HP·TP. 오른쪽은 비우고(원작처럼) 안내만 뜬다. 목록이 열려 있으면 대원 단추는 흐리고 받지 않는다.
	top.name_text = menu.member_name(i)
	top.level_text = t.t("party.level", {"level": m.level})
	top.hp_text = t.t("party.hp", {"hp": m.hp, "max": m.max_hp})
	top.tp_text = t.t("party.tp", {"tp": m.tp, "max": m.max_tp})
	top.right_text = ""
	top.right_ratio = -1.0
	for b in [top.prev_button, top.next_button]:
		(b as PartyButton).disabled = list_open
		if list_open:
			(b as PartyButton).cancel()
	notice_changed()
	# 왼쪽 열: 지금 값과 (목록이면) 커서 줄로 바꾼 뒤 값.
	var p := GrowthRules.profile(defs, i, m)
	var preview := list_open and list_cursor != equipped_row and row_block[list_cursor].is_empty()
	var after := profile_if(row_items[list_cursor]) if preview else p
	var g := defs.battle.growth
	var c := defs.class_of(i)
	var cap_row: Dictionary = c.levels.get(g.level_cap, c.levels.get(m.level, {}))
	var stats := {}
	for k in PartyStatusTab.STAT_ROWS:
		var now := int(p["stats"][k])
		var then := int(after["stats"][k])
		var top_v := maxf(1.0, float(cap_row.get(k, then)))
		stats[k] = [now, then, clampf(float(then) / top_v, 0.0, 1.0)]
	var gear := {}
	for k in BattleLimits.GEAR:
		gear[k] = [int(p["gear"][k]), int(after["gear"][k])]
	var equip := []
	for slot in m.equip.size():
		var id: String = m.equip[slot]
		equip.append([SheetParts.kind_icon(defs, id), menu.item_name(id) if not id.is_empty() else t.t("party.slot.empty"), id.is_empty()])
	drawn = {
		"name": menu.member_name(i), "class": t.t(defs.party.class_ids[i]),
		"class_color": BattleCard.CLASS_COLORS.get(defs.party.class_ids[i], Color(0.7, 0.7, 0.7)),
		"level": top.level_text, "hp": top.hp_text, "tp": top.tp_text,
		"stats": stats, "gear": gear, "equip": equip, "mark": cursor, "preview": preview,
	}
	_refresh_rows()
	_refresh_desc()
	for d in [top, left, portrait, window]:
		(d as Control).queue_redraw()


## 목록 창 줄: 칸 고르기면 Slot_k 넷, 목록이면 Row_j(쓰지 않는 줄은 감춘다). 노랑 커서는 지금 단계의 커서 줄 하나.
func _refresh_rows() -> void:
	var defs := menu.state.defs
	var m := menu.current_member()
	var t := menu.texts
	for slot in slot_rows.size():
		var b := slot_rows[slot]
		var id: String = m.equip[slot]
		b.visible = not list_open
		if list_open:
			b.cancel()
		var sr := window.row_rect(slot)
		b.position = sr.position
		b.size = sr.size
		b.icon_name = SheetParts.kind_icon(defs, id)
		b.equipped = false
		b.show_row(t.t("party.slot.empty") if id.is_empty() else menu.item_name(id), "", "", false)
		b.selected = slot == cursor and not list_open
	while rows.size() < row_items.size() and list_open:
		var j := rows.size()
		var r := _row_button("Row_%d" % j)
		r.activated.connect(func() -> void: menu.handle("row", j))
		rows.append(r)
	for j in rows.size():
		var r := rows[j]
		if not list_open or j >= row_items.size():
			if r.visible:
				r.cancel()
			r.visible = false
			continue
		var id := row_items[j]
		r.visible = true
		var rr := window.row_rect(j)
		r.position = rr.position
		r.size = rr.size
		r.icon_name = SheetParts.kind_icon(defs, id)
		r.equipped = j == equipped_row
		var count := "" if id.is_empty() or j == equipped_row else t.t("party.count", {"n": int(menu.state.gear_bag.get(id, 0))})
		r.show_row(t.t("party.unequip") if id.is_empty() else menu.item_name(id), count, "", not row_block[j].is_empty())
		r.selected = j == list_cursor
	var n := row_items.size() if list_open else slot_rows.size()
	list.set_content_height(ListWindow.content_height(n))
	window.queue_redraw()


## 설명 상자: 칸 고르기 = 커서 칸의 장비(빈 칸은 머리 「비어 있음」만), 목록 = 커서 줄(낄 수 있는 것·「E」: 값과 받는 배율,
## 못 끼는 것: 그 아래 이유, 「빼기」: 하는 일 한 줄과 막히면 이유). 장비면 머리 오른쪽에 파티 직업 표(낄 수 있으면 켜짐).
func _refresh_desc() -> void:
	var t := menu.texts
	var id: String = menu.current_member().equip[cursor]
	var why := ""
	if list_open:
		id = row_items[list_cursor]
		why = row_block[list_cursor]
		if id.is_empty():
			var lines: Array[String] = [t.t("party.equip.unequip_desc")]
			if not why.is_empty():
				lines.append(menu.reason_text(why))
			desc.show_desc(t.t("party.unequip"), "", lines)
			return
	if id.is_empty():
		desc.show_desc(t.t("party.slot.empty"), "", [] as Array[String])
		return
	var lines := item_lines(id)
	if not why.is_empty():
		lines.append(menu.reason_text(why))
	desc.show_desc(menu.item_name(id), SheetParts.kind_icon(menu.state.defs, id), lines, class_table(id))


## 장비 설명 줄: 값(상점·소지품과 같은 글)과 받는 배율(상태와 같은 글). 빈 줄은 뺀다.
func item_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	for s in [PartyNames.values_text(menu.state, menu.texts, id), PartyNames.received_text(menu.state, menu.texts, id)]:
		if not str(s).is_empty():
			out.append(str(s))
	return out


## 직업 표 [[머리글자(shop.badge.*), 낄 수 있는지], …]: 지금 파티의 직업(파티 차례, 겹치면 한 번).
func class_table(id: String) -> Array:
	var e := menu.state.defs.battle.equip(id)
	var out := []
	var seen := {}
	for cid in menu.state.defs.party.class_ids:
		if seen.has(cid):
			continue
		seen[cid] = true
		var c: BattleDb.ClassDef = menu.state.defs.battle.classes.get(cid)
		out.append([menu.texts.t("shop.badge." + str(cid).trim_prefix("class.")), e != null and c != null and e.fits(c)])
	return out


## 안내(거부 이유·장착 결과)는 위 띠 오른쪽(원작에서 비어 있는 자리)에 노란 글자로. 없으면 비운다.
func notice_changed() -> void:
	note_label.text = "   ".join(menu.notice.split("\n", false))


## 지금 대원의 커서 칸을 item_id 로 바꾼(""= 빼기) 사본의 GrowthRules.profile(대원은 그대로). 왼쪽 열의 바꾸면 값이 쓴다
## (화면이 규칙 계산을 따로 하지 않는다).
func profile_if(item_id: String) -> Dictionary:
	var m := menu.current_member()
	var copy := PartyState.Member.new(m.id, m.max_hp, m.hp, m.max_tp, m.tp)
	copy.level = m.level
	copy.exp = m.exp
	copy.skills = m.skills.duplicate()
	copy.equip = m.equip.duplicate()
	copy.equip[cursor] = item_id
	return GrowthRules.profile(menu.state.defs, menu.member, copy)


# ---- 그리기 ----

## 바꾸면 값 [글, 방향]: 같으면 ["", 0](지금 값만), 다르면 새 값과 ±1.
static func after_of(now: int, then: int) -> Array:
	return ["", 0] if now == then else [str(then), 1 if then > now else -1]


func _draw_left(ci: Control) -> void:
	SheetParts.begin(ci)  # 이번 그리기의 기록(시험이 본다)
	if drawn.is_empty():
		return
	var t := menu.texts
	SheetParts.draw_class_plate(ci, class_rect(), drawn["class"])
	for i in PartyStatusTab.STAT_ROWS.size():
		var k: String = PartyStatusTab.STAT_ROWS[i]
		var v: Array = drawn["stats"][k]
		var a := after_of(v[0], v[1])
		SheetParts.draw_stat_row(ci, stat_rect(i), t.t("stat." + k), str(v[0]), v[2], a[0], a[1])
	var g: Dictionary = drawn["gear"]
	for row in 2:
		var pairs := []
		for k in (["atk", "def"] if row == 0 else ["matk", "mdef"]):
			var a := after_of(g[k][0], g[k][1])
			pairs.append([t.t("stat." + k), str(g[k][0]), a[0], a[1]])
		SheetParts.draw_gear_row(ci, gear_row_rect(row), pairs)
	for slot in drawn["equip"].size():
		var e: Array = drawn["equip"][slot]
		SheetParts.draw_equip_row(ci, equip_rect(slot), e[0], e[1], e[2], slot == drawn["mark"])


func _draw_portrait(ci: Control) -> void:
	if drawn.is_empty():
		return
	MemberPortrait.draw_silhouette(ci, Rect2(Vector2.ZERO, ci.size), drawn["class_color"], str(drawn["name"]).left(1), 220)
