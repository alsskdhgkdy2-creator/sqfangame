## 파티 메뉴 장비 탭(07 §9.2, §5.7): 왼쪽 4칸 줄(칸 이름·장비 이름·주요 값), 칸을 누르면 오른쪽에 그 칸의 목록.
## 목록: 맨 위 「빼기」, 낄 수 있는 가방 장비(이름·개수·바뀌는 값), 아래에 낄 수 없는 가방 장비를 흐리게 이유와 함께.
## 줄을 누르면 바로 GrowthRules.equip(초안 없음) → 자동 저장, 목록을 닫고 커서는 그 칸. 칸 0 에 무기 아닌 것·칸 1~3 에 무기처럼
## 칸 종류가 다른 장비는 목록에 넣지 않는다. 판정은 GrowthRules.equip_block, 바뀌는 값은 바꾼 뒤의 GrowthRules.profile 과의 차이.
## 칸 줄 아래 합계 표(M2.6 U8): 목록이 닫혀 있으면 지금 합계, 열려 있으면 커서 줄로 바꿨을 때의 「지금 → 바꾸면」.
class_name PartyEquipTab
extends Control

const SLOT_SIZE := Vector2(460, 80)
const SLOT_GAP := 8.0
const LIST_X := 768.0
const ROW_H := 64.0
const ROW_GAP := 4.0

var menu: PartyMenu
## 칸 커서(0~3).
var cursor := 0
var list_open := false
## 목록 줄 커서.
var list_cursor := 0
var slot_rows: Array[PartyButton] = []
var list: PartyScroll
var rows: Array[PartyButton] = []
## 목록 줄 → 장비 ID("" = 빼기)
var row_items: Array[String] = []
## 목록 줄 → 막는 이유(growth.reason 코드, "" = 낄 수 있음)
var row_block: Array[String] = []
var totals: EquipTotals


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	for slot in BattleLimits.EQUIP_SLOTS:
		var b := PartyButton.new()
		b.name = "Slot_%d" % slot
		b.size = SLOT_SIZE
		b.align_left = true
		b.activated.connect(func() -> void: menu.handle("slot", slot))
		add_child(b)
		slot_rows.append(b)
	list = PartyScroll.new()
	list.name = "EquipList"
	list.visible = false
	add_child(list)
	totals = EquipTotals.new()
	totals.name = "EquipTotals"
	add_child(totals)


func reset() -> void:
	cursor = 0
	close_list()


func member_changed() -> void:
	close_list()


func context() -> String:
	return "%s|%d" % [str(list_open), cursor if list_open else -1]


func place(s: Vector2) -> void:
	for slot in slot_rows.size():
		slot_rows[slot].position = Vector2(PartyMenu.TAB_X, PartyMenu.TOP + slot * (SLOT_SIZE.y + SLOT_GAP))
	var totals_y := PartyMenu.TOP + slot_rows.size() * (SLOT_SIZE.y + SLOT_GAP)
	totals.position = Vector2(PartyMenu.TAB_X, totals_y)
	totals.size = Vector2(SLOT_SIZE.x, minf(EquipTotals.needed_height(), s.y - totals_y - 8))
	list.position = Vector2(LIST_X, PartyMenu.TOP)
	list.size = Vector2(maxf(504.0, s.x - 8 - LIST_X), s.y - PartyMenu.TOP - 8)
	for r in rows:
		r.size = Vector2(list.size.x, ROW_H)


func dispatch(kind: String, arg: Variant) -> bool:
	match kind:
		"slot":
			var slot := int(arg) if arg != null else -1
			if slot < 0 or slot >= BattleLimits.EQUIP_SLOTS:
				return false
			cursor = slot
			_open_list()
			return true
		"row":
			return _choose_row(int(arg) if arg != null else -1)
		"cursor":
			var d := int(arg) if arg != null else 1
			if list_open:
				var to := clampi(list_cursor + d, 0, row_items.size() - 1)
				if to == list_cursor:
					return false
				list_cursor = to
				list.ensure_visible(to * (ROW_H + ROW_GAP), to * (ROW_H + ROW_GAP) + ROW_H)
				return true
			var to_slot := clampi(cursor + d, 0, BattleLimits.EQUIP_SLOTS - 1)
			if to_slot == cursor:
				return false
			cursor = to_slot
			return true
		"confirm":
			if list_open:
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


func _open_list() -> void:
	list_open = true
	list_cursor = 0
	list.scroll_to(0.0)
	_build_rows()


func close_list() -> void:
	list_open = false
	list_cursor = 0
	if list != null:
		list.visible = false


## 줄 j 로 장착(또는 빼기). 못 끼는 줄이면 이유만 알린다(목록 그대로). 받아들여지면 목록을 닫고 커서는 그 칸.
func _choose_row(j: int) -> bool:
	if not list_open or j < 0 or j >= row_items.size():
		return false
	list_cursor = j
	if not row_block[j].is_empty():
		menu.show_notice(menu.reason_text(row_block[j]))
		return true
	if menu.apply(GrowthRules.equip(menu.state, menu.member, cursor, row_items[j])):
		close_list()
	return true


## 지금 칸의 목록 줄을 다시 정한다(가방·장비가 바뀌면 다시 부른다).
func _build_rows() -> void:
	row_items.clear()
	row_block.clear()
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var bag := menu.state.gear_bag
	row_items.append("")
	row_block.append(GrowthRules.equip_block(defs, i, m, bag, cursor, ""))
	var dim_items: Array[String] = []
	var dim_why: Array[String] = []
	for id in defs.battle.equipment_ids:
		if int(bag.get(id, 0)) < 1:
			continue
		var kind_why := GrowthRules.slot_block(defs.battle, defs.class_of(i), m.equip, cursor, id)
		if kind_why == "slot_kind":
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
	list_cursor = clampi(list_cursor, 0, row_items.size() - 1)


func refresh() -> void:
	if menu.state == null:
		return
	var defs := menu.state.defs
	var m := menu.current_member()
	for slot in slot_rows.size():
		var b := slot_rows[slot]
		var id: String = m.equip[slot]
		b.caption = menu.slot_name(slot)
		if id.is_empty():
			b.show_row(menu.texts.t("party.slot.empty"), "", "", true)
		else:
			b.show_row(menu.item_name(id), "", item_summary(defs.battle.equip(id)))
		# 목록이 열린 칸은 「지금 이 칸」(켜짐), 닫혀 있으면 커서.
		b.checked = list_open and slot == cursor
		b.selected = slot == cursor and not list_open
	list.visible = list_open
	var base := GrowthRules.profile(defs, menu.member, m)
	if not list_open:
		totals.show_totals(menu.texts, base, null)
		return
	_build_rows()
	# 낄 수 없는 줄이면 견주지 않는다(지금 값만).
	var blocked := not row_block[list_cursor].is_empty()
	totals.show_totals(menu.texts, base, null if blocked else profile_if(row_items[list_cursor]))
	while rows.size() < row_items.size():
		var r := PartyButton.new()
		var j := rows.size()
		r.name = "Row_%d" % j
		r.align_left = true
		r.scroller = list
		r.size = Vector2(list.size.x, ROW_H)
		r.activated.connect(func() -> void: menu.handle("row", j))
		list.content.add_child(r)
		rows.append(r)
	for j in rows.size():
		var r := rows[j]
		if j >= row_items.size():
			if r.visible:
				r.cancel()
			r.visible = false
			continue
		r.visible = true
		r.position = Vector2(0, j * (ROW_H + ROW_GAP))
		var id := row_items[j]
		var why := row_block[j]
		var name := menu.texts.t("party.unequip") if id.is_empty() else menu.item_name(id)
		var count := "" if id.is_empty() else menu.texts.t("party.count", {"n": int(menu.state.gear_bag.get(id, 0))})
		var note := menu.reason_text(why) if not why.is_empty() else change_text(base, id)
		r.show_row(name, count, note, not why.is_empty())
		r.selected = j == list_cursor
	list.set_content_height(row_items.size() * (ROW_H + ROW_GAP))


## 장비의 주요 값(공격·방어 등과 능력치 보정, 무기 속성).
func item_summary(e: BattleDb.EquipDef) -> String:
	if e == null:
		return ""
	var parts: Array[String] = []
	for g in BattleLimits.GEAR:
		if int(e.gear[g]) != 0:
			parts.append("%s %d" % [menu.texts.t("stat." + g), e.gear[g]])
	for k in BattleLimits.STATS:
		if e.stats.has(k):
			parts.append("%s %s" % [menu.texts.t("stat." + k), PartyMenu.signed(e.stats[k])])
	if e.weapon() and not e.element.is_empty():
		parts.append(menu.texts.t("element." + e.element))
	return " · ".join(parts)


## 지금 대원의 커서 칸을 item_id 로 바꾼(""= 빼기) 사본의 GrowthRules.profile(대원은 그대로). 목록 줄의 바뀌는 값과
## 합계 표의 「바꾸면」이 같이 쓴다(화면이 규칙 계산을 따로 하지 않는다).
func profile_if(item_id: String) -> Dictionary:
	var m := menu.current_member()
	var copy := PartyState.Member.new(m.id, m.max_hp, m.hp, m.max_tp, m.tp)
	copy.level = m.level
	copy.exp = m.exp
	copy.skills = m.skills.duplicate()
	copy.equip = m.equip.duplicate()
	copy.equip[cursor] = item_id
	return GrowthRules.profile(menu.state.defs, menu.member, copy)


## 이 칸을 item_id 로 바꿨을 때(""= 빼기) 공격·방어 넷과 능력치가 바뀌는 값(「공격 +8」「방어 -2」): profile_if 와 지금 묶음의 차이.
func change_text(base: Dictionary, item_id: String) -> String:
	var after := profile_if(item_id)
	var parts: Array[String] = []
	for g in BattleLimits.GEAR:
		var d: int = after["gear"][g] - base["gear"][g]
		if d != 0:
			parts.append(menu.texts.t("party.delta", {"name": menu.texts.t("stat." + g), "value": PartyMenu.signed(d)}))
	for k in BattleLimits.STATS:
		var d: int = after["stats"][k] - base["stats"][k]
		if d != 0:
			parts.append(menu.texts.t("party.delta", {"name": menu.texts.t("stat." + k), "value": PartyMenu.signed(d)}))
	return " · ".join(parts) if not parts.is_empty() else menu.texts.t("party.no_change")
