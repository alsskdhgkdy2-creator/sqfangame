## 캠프 장비 화면(07 §9.2, §5.7, M2.7 R2-c: 원작 상점 사기 화면 jp_guide3_img1 짜임, ShopFrame).
## 왼쪽 목록 창: 목록이 닫혀 있으면 장비 칸 넷(장비 이름·오른쪽 칸 이름·주요 값), 칸을 누르면 그 칸의 목록.
## 목록: 맨 위 「빼기」, 낄 수 있는 가방 장비(이름·개수·바뀌는 값), 아래에 낄 수 없는 가방 장비를 흐리게 이유와 함께.
## 줄을 누르면 바로 GrowthRules.equip(초안 없음) → 자동 저장, 목록을 닫고 커서는 그 칸. 칸 0 에 무기 아닌 것·칸 1~3 에 무기처럼
## 칸 종류가 다른 장비는 목록에 넣지 않는다. 판정은 GrowthRules.equip_block, 바뀌는 값은 바꾼 뒤의 GrowthRules.profile 과의 차이.
## 왼쪽 아래 설명 창: 커서 칸의 장비(닫힘) 또는 커서 줄(열림)의 이름·주요 값·바뀌는 값/막는 이유.
## 오른쪽 인물 판(CharPanel): 능력치 묶음(M2.6 U8 합계)이 닫혀 있으면 지금 값, 열려 있으면 커서 줄로 바꿨을 때의 「지금 → 바꾸면」.
## 설명 띠: 물음(어느 칸 / 무엇을 낄까) + 안내(거부 이유).
class_name PartyEquipTab
extends Control

const SLOT_H := 64.0
const SLOT_GAP := 8.0
const ROW_H := 64.0
const ROW_GAP := 4.0

var menu: PartyMenu
## 칸 커서(0~3).
var cursor := 0
var list_open := false
## 목록 줄 커서.
var list_cursor := 0
var frame: ShopFrame
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
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame = ShopFrame.new()
	frame.name = "EquipFrame"
	add_child(frame)
	frame.build("Equip", menu.texts.t("camp.back"), true)
	frame.back.connect(func() -> void: menu.handle("back"))
	frame.panel.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	totals = frame.panel.totals
	var la: Array = frame.list_anchor()
	var off: Vector4 = la[2]
	for slot in BattleLimits.EQUIP_SLOTS:
		var b := PartyButton.new()
		b.name = "Slot_%d" % slot
		b.align_left = true
		b.skin = "fac"
		b.activated.connect(func() -> void: menu.handle("slot", slot))
		add_child(b)
		var y := off.y + slot * (SLOT_H + SLOT_GAP)
		PartyMenu.place(b, Vector2(0, 0), Vector2(1, 0), Vector4(off.x, y, off.z, y + SLOT_H))
		slot_rows.append(b)
	list = PartyScroll.new()
	list.name = "EquipList"
	list.visible = false
	add_child(list)
	PartyMenu.place(list, la[0], la[1], off)
	list.resized.connect(func() -> void:
		if menu.state != null and visible and list_open:
			refresh())


func reset() -> void:
	cursor = 0
	close_list()


func member_changed() -> void:
	close_list()


func context() -> String:
	return "%s|%d" % [str(list_open), cursor if list_open else -1]


func place(_s: Vector2) -> void:
	if menu.state != null and visible:
		refresh()


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
		b.visible = not list_open
		if list_open:
			b.cancel()
		# 원작 상점 줄(이름 + 오른쪽 값) 짜임: 장비 이름, 오른쪽 칸 이름, 아래 주요 값.
		if id.is_empty():
			b.show_row(menu.texts.t("party.slot.empty"), menu.slot_name(slot), "", true)
		else:
			b.show_row(menu.item_name(id), menu.slot_name(slot), item_summary(defs.battle.equip(id)))
		b.selected = slot == cursor and not list_open
	list.visible = list_open
	frame.show_title(menu.texts.t("camp.cmd.equip"))
	_refresh_banner()
	var base := GrowthRules.profile(defs, menu.member, m)
	if not list_open:
		frame.panel.show_member(menu, menu.member, null, cursor)
		var cur: String = m.equip[cursor]
		var lines: Array[String] = [menu.slot_name(cursor)]
		if not cur.is_empty():
			lines.append(item_summary(defs.battle.equip(cur)))
		frame.show_desc(menu.texts.t("party.slot.empty") if cur.is_empty() else menu.item_name(cur), lines)
		return
	_build_rows()
	# 낄 수 없는 줄이면 견주지 않는다(지금 값만).
	var blocked := not row_block[list_cursor].is_empty()
	frame.panel.show_member(menu, menu.member, null if blocked else profile_if(row_items[list_cursor]), cursor)
	while rows.size() < row_items.size():
		var r := PartyButton.new()
		var j := rows.size()
		r.name = "Row_%d" % j
		r.align_left = true
		r.skin = "fac"
		r.scroller = list
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
		r.size = Vector2(list.size.x, ROW_H)
		var id := row_items[j]
		var why := row_block[j]
		var name := menu.texts.t("party.unequip") if id.is_empty() else menu.item_name(id)
		var count := "" if id.is_empty() else menu.texts.t("party.count", {"n": int(menu.state.gear_bag.get(id, 0))})
		var note := menu.reason_text(why) if not why.is_empty() else change_text(base, id)
		r.show_row(name, count, note, not why.is_empty())
		r.selected = j == list_cursor
	list.set_content_height(row_items.size() * (ROW_H + ROW_GAP))
	var cid := row_items[list_cursor]
	var lines: Array[String] = [menu.slot_name(cursor)]
	if not cid.is_empty():
		lines[0] += "  " + menu.texts.t("party.count", {"n": int(menu.state.gear_bag.get(cid, 0))})
		lines.append(item_summary(defs.battle.equip(cid)))
	lines.append(menu.reason_text(row_block[list_cursor]) if blocked else change_text(base, cid))
	frame.show_desc(menu.texts.t("party.unequip") if cid.is_empty() else menu.item_name(cid), lines)


## 설명 띠: 물음 + 안내(거부 이유 등).
func _refresh_banner() -> void:
	var head := menu.texts.t("camp.equip.list", {"slot": menu.slot_name(cursor)}) if list_open else menu.texts.t("camp.equip.slots")
	frame.banner.show_lines(head, menu.notice, not menu.notice.is_empty())


func notice_changed() -> void:
	if menu.state != null:
		_refresh_banner()


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
