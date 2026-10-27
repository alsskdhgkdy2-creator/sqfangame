## 캠프 소지품 화면(07 §9.9 E2-b, research 08 §4.1: 원작 III HD 소지품 yt_eo3hd_05). 대원 판은 없다(D27 ②).
## 맨 위는 뿌리의 띠(걸음 문패·장소 띠·소지금)이고, 알림 줄 자리의 띠에 「소지품   장비 n · 소재 n」(가진 종류 수)을 PartyMenu 가 쓴다.
## 층(1280×720, 뒤 → 앞): 목록 창(부품 H, x 135~642 · y 178~468, 줄 넷이 다 보인다) → 「임시 보급」 알약(디버그만, 원작 使う 자리
## x 735~975 · y 278~342) → 설명 상자(부품 I, x 288~990 · y 530~712). 넓은 화면은 왼쪽 앵커 그대로, 높은 화면은 설명 상자가 아래에 붙고
## 목록 창이 줄 단위로 아래로 늘어난다(설명 상자 위 62 까지).
## 목록: 장비(자료 차례, 가진 것)와 소재(정의 자료 차례, 가진 것, 상점 판매와 같다)를 한 줄씩(묶음 머리 없음, 아이콘이 가른다). 줄 = 종류 아이콘 · 이름 · 「n개」.
## 커서(노랑 하나): ↑↓ 줄 사이(돌지 않음, 끝에서는 아무 일 없음), 줄을 누르면 커서가 그 줄로, 줄 위 끌기는 내리기만 한다.
## 선택은 줄에서 아무 일 없다(키패드 「선택」 흐림). 설명 상자 = 커서 줄의 장비(값·받는 배율·낄 수 있는 직업·판매값)나 소재(「소재」·판매값).
## 디버그(07 §5.7): 알약이 커서 칸 0(줄 앞). 누르거나 Enter 로 보급 줄을 연다: 목록이 가방 줄 대신 장비마다 「+1」, 대원마다 이름 줄 아래
## 「경험치 +100」「다음 레벨까지」가 된다(GrowthRules.supply·grant_exp → 자동 저장). 커서는 알약과 보급 단추 사이, 단추를 누르면 커서도 그 단추로.
class_name PartyItemsTab
extends Control

## 1280×720 기준 자리(왼쪽 위 앵커). 설명 상자는 왼쪽 아래 앵커(아래 여백 8).
const LIST_BOX := Rect2(135, 178, 507, 290)
const PILL_BOX := Rect2(735, 278, 240, 64)
const DESC_BOX := Rect2(288, 530, 702, 182)
const DESC_BOTTOM := 8.0
## 목록 창 아래 끝과 설명 상자 위 끝 사이(720 에서 468 → 530).
const DESC_GAP := 62.0
const PLUS_SIZE := Vector2(96, 64)
const EXP_STEP := 100

var menu: PartyMenu
var window: ListWindow
var list: PartyScroll
var desc: DescBox
var supply_button: ListButton
## 공용 목록(D28): 줄·커서·내림·되돌림·누르기·「선택」 막기·설명 연결. 알약과 보급 단추는 이 화면이 갈고리로 더한다.
var inv: InventoryList
## 보급 줄이 열려 있는지(디버그).
var supply_open := false
## 커서 칸(stops 차례). 칸이 없으면 -1.
var cursor: int:
	get:
		return inv.cursor if inv != null else 0
	set(v):
		inv.cursor = v
## 줄(가방 줄 또는 보급의 장비·대원 줄, 공용 목록의 줄 단추 Row_k). 앞 inv.used 개를 쓴다.
var rows: Array[ListButton]:
	get:
		var out: Array[ListButton] = []
		if inv != null:
			out.assign(inv.rows)
		return out
## 가방 줄의 ID(rows 차례, 장비 ID 또는 소재 ID). 보급 줄이 열려 있으면 비어 있다.
var row_items: Array[String] = []
## 보급 「+1」 단추(장비 ID 순) · 대원별 「경험치 +100」·「다음 레벨까지」.
var plus_buttons: Array[PartyButton] = []
var exp_buttons: Array[PartyButton] = []
var next_buttons: Array[PartyButton] = []
## 보급 줄의 대원 이름 줄(대원 차례).
var member_rows: Array[ListButton] = []


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	window = ListWindow.new()
	window.name = "ItemsWindow"
	add_child(window)
	list = window.list
	list.name = "ItemsList"
	inv = InventoryList.new(list, InventoryLook.new())
	inv.behind = true  # 줄은 보급 단추 뒤에 그린다(내용의 맨 앞)
	inv.route = func(k: int) -> void: menu.handle("item_row", k)
	inv.stops_hook = stops
	inv.group_top_hook = group_top
	inv.confirmable = func(c: Control) -> bool: return row_index(c) < 0  # 가방 줄은 「선택」 흐림
	inv.changed.connect(_refresh_desc)
	inv.watch_resize(func() -> void:
		if menu.state != null and visible:
			refresh())
	supply_button = ListButton.new()
	supply_button.name = "SupplyToggle"
	supply_button.style = "pill"
	supply_button.activated.connect(func() -> void: menu.handle("supply_toggle"))
	add_child(supply_button)
	PartyMenu.place(supply_button, Vector2.ZERO, Vector2.ZERO, Vector4(PILL_BOX.position.x, PILL_BOX.position.y, PILL_BOX.end.x, PILL_BOX.end.y))
	desc = DescBox.new()
	desc.name = "ItemsDesc"
	add_child(desc)
	PartyMenu.place(desc, Vector2(0, 1), Vector2(0, 1),
		Vector4(DESC_BOX.position.x, -DESC_BOTTOM - DESC_BOX.size.y, DESC_BOX.end.x, -DESC_BOTTOM))


func _press_button(n: String, sz: Vector2, kind: String, arg: Variant) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.size = sz
	b.scroller = list
	b.activated.connect(func() -> void: menu.handle(kind, arg))
	list.content.add_child(b)
	return b


func reset() -> void:
	enter()


## 화면에 들어올 때(캠프를 열 때·다른 화면에서 올 때): 보급 줄은 닫고, 커서는 첫 가방 줄(디버그면 알약 다음), 목록 맨 위.
func enter() -> void:
	supply_open = false
	if inv != null:
		inv.reset(1 if menu != null and menu.debug else 0)


func member_changed() -> void:
	pass


func context() -> String:
	return "supply" if supply_open else ""


## 목록 창 자리: 위 178 에서 줄 단위로, 아래 끝은 설명 상자 위 DESC_GAP 까지(720 에서 줄 넷, 960 에서 일곱).
static func list_rect(s: Vector2) -> Rect2:
	var desc_top := s.y - DESC_BOTTOM - DESC_BOX.size.y
	var n := ListParts.rows_for(desc_top - DESC_GAP - LIST_BOX.position.y)
	return Rect2(LIST_BOX.position, Vector2(LIST_BOX.size.x, ListParts.list_height(n)))


func place(s: Vector2) -> void:
	var lr := list_rect(s)
	PartyMenu.place(window, Vector2.ZERO, Vector2.ZERO, Vector4(lr.position.x, lr.position.y, lr.end.x, lr.end.y))
	if menu.state != null and visible:
		refresh()


## 커서가 설 수 있는 칸(차례): 디버그면 알약, 그다음 가방 줄 또는 보급 단추.
func stops() -> Array[Control]:
	var out: Array[Control] = []
	if menu.debug:
		out.append(supply_button)
	if supply_open:
		for b in plus_buttons:
			if b.visible:
				out.append(b)
		for j in exp_buttons.size():
			if exp_buttons[j].visible:
				out.append(exp_buttons[j])
				out.append(next_buttons[j])
	else:
		for k in row_items.size():
			out.append(inv.rows[k])
	return out


## c 가 몇째 가방 줄인지(가방 줄이 아니면 -1).
func row_index(c: Control) -> int:
	return inv.rows.find(c) if c is ListButton and c != supply_button else -1


## 커서 칸(없으면 null).
func cursor_stop() -> Control:
	return inv.cursor_stop()


## Enter 가 할 일이 있는지(알약·보급 단추). 가방 줄은 없다(키패드 「선택」 흐림).
func can_confirm() -> bool:
	return inv.can_confirm()


## ↑↓ 가 갈 칸이 있는지(칸이 없으면 흐림).
func can_move() -> bool:
	return inv.can_move()


## 띠 글(알림이 없을 때): 「소지품   장비 n · 소재 n · 귀중품 n」, n 은 가진 종류 수(개수 1 이상, 귀중품은 가진 수).
func caption() -> String:
	var gear := 0
	for id in menu.state.defs.battle.equipment_ids:
		if int(menu.state.gear_bag.get(id, 0)) >= 1:
			gear += 1
	var mats := 0
	for id in menu.state.materials:
		if int(menu.state.materials[id]) >= 1:
			mats += 1
	return menu.texts.t("party.items.strip", {"gear": gear, "materials": mats, "keys": menu.state.key_items.size()})


func dispatch(kind: String, arg: Variant) -> bool:
	var ids := menu.state.defs.battle.equipment_ids
	match kind:
		"cursor":
			return inv.move(int(arg) if arg != null else 1)
		"confirm":
			# 가방 줄(「선택」 흐림)이면 아무것도 바꾸지 않는다(내림도 그대로, 키패드 = 키). 아니면 커서 칸(대원 단추면 그 대원 이름 줄까지)을
			# 보이게 한 뒤 누른다.
			return inv.confirm(_press)
		"item_row":
			var i := int(arg) if arg != null else -1
			var k := stops().find(inv.rows[i]) if i >= 0 and i < inv.used else -1
			if k < 0 or k == cursor:
				return false
			return inv.point(inv.rows[i])
	if not menu.debug:
		return false
	match kind:
		"supply_toggle":
			supply_open = not supply_open
			inv.reset(0)
			return true
		"supply":
			if not supply_open or not ids.has(str(arg)):
				return false
			_point(plus_buttons[ids.find(str(arg))])
			menu.apply(GrowthRules.supply(menu.state, str(arg), 1))
			return true
		"exp_100":
			var i := int(arg)
			if not supply_open or i < 0 or i >= menu.state.party.members.size():
				return false
			_point(exp_buttons[i])
			menu.apply(GrowthRules.grant_exp(menu.state, i, EXP_STEP))
			return true
		"exp_next":
			if not supply_open:
				return false
			var i := int(arg)
			if i < 0 or i >= menu.state.party.members.size():
				return false
			_point(next_buttons[i])
			var m := menu.state.party.members[i]
			var g := menu.state.defs.battle.growth
			if m.level >= g.level_cap:
				menu.show_notice(menu.texts.t("party.exp_max"))
				return true
			menu.apply(GrowthRules.grant_exp(menu.state, i, g.cum(m.level + 1) - m.exp))
			return true
	return false


## 포인터로 누른 보급 단추로 커서를 옮기고 그 묶음(대원 단추면 이름 줄까지)을 보이게 한다.
func _point(b: Control) -> void:
	inv.point(b)


## 키보드 Enter: 커서 칸이 하는 일(단추 누르기와 같은 일, 입력은 이 하나로 센다).
func _press(b: Control) -> bool:
	if b == supply_button:
		return dispatch("supply_toggle", null)
	var k := plus_buttons.find(b)
	if k >= 0:
		return dispatch("supply", menu.state.defs.battle.equipment_ids[k])
	k = exp_buttons.find(b)
	if k >= 0:
		return dispatch("exp_100", k)
	k = next_buttons.find(b)
	if k >= 0:
		return dispatch("exp_next", k)
	return false


## 커서 칸(묶음)이 목록 보이는 곳 안에 다 있는지. 알약은 목록 밖이라 늘 참.
func shown(b: Control) -> bool:
	return inv.shown(b)


## 칸이 속한 묶음의 위 끝(목록 내용 좌표): 대원 경험치 단추면 그 대원 이름 줄 위, 아니면 칸 위.
func group_top(b: Control) -> float:
	if exp_buttons.has(b) or next_buttons.has(b):
		return b.position.y - ListParts.ROW_H - ListParts.ROW_GAP
	return b.position.y


func refresh() -> void:
	if menu.state == null:
		return
	row_items.clear()
	var defs := menu.state.defs
	var ids := defs.battle.equipment_ids
	var w := list.size.x
	var lines: Array = []
	supply_button.visible = menu.debug
	supply_button.text = menu.texts.t("party.supply")
	supply_button.checked = supply_open
	while plus_buttons.size() < ids.size():
		var k := plus_buttons.size()
		plus_buttons.append(_press_button("Supply_%d" % k, PLUS_SIZE, "supply", ids[k]))
	var n := menu.state.party.members.size()
	while exp_buttons.size() < n:
		var k := exp_buttons.size()
		exp_buttons.append(_press_button("Exp_%d" % k, Vector2(200, 64), "exp_100", k))
		next_buttons.append(_press_button("ExpNext_%d" % k, Vector2(200, 64), "exp_next", k))
	var member_lines: Array[int] = []
	var show_supply := menu.debug and supply_open
	# 보급 줄: 장비마다 읽기만 하는 줄(오른쪽에 「+1」 자리) + 「+1」, 대원마다 이름 줄 + 단추 줄(줄 단추 없음).
	for k in plus_buttons.size():
		var b := plus_buttons[k]
		b.visible = show_supply and k < ids.size()
		if not b.visible:
			continue
		var bag := int(menu.state.gear_bag.get(ids[k], 0))
		lines.append({"icon": SheetParts.kind_icon(defs, ids[k]), "name": menu.item_name(ids[k]),
			"right": menu.texts.t("party.count", {"n": bag}), "press": false, "room": PLUS_SIZE.x + 8, "id": ids[k]})
		b.position = Vector2(w - PLUS_SIZE.x, inv.line_y(lines.size() - 1))
		b.text = menu.texts.t("party.supply.plus")
	for k in exp_buttons.size():
		var vis := show_supply and k < n
		exp_buttons[k].visible = vis
		next_buttons[k].visible = vis
		if not vis:
			continue
		var m := menu.state.party.members[k]
		member_lines.append(lines.size())
		lines.append({"name": menu.member_name(k), "right": menu.texts.t("party.items.member", {"level": m.level, "exp": m.exp}),
			"press": false})
		lines.append({"row": false})
		var y := inv.line_y(lines.size() - 1)
		var bw := floorf((w - 8.0) / 2.0)
		exp_buttons[k].position = Vector2(0, y)
		exp_buttons[k].size = Vector2(bw, ListParts.ROW_H)
		exp_buttons[k].text = menu.texts.t("party.supply.exp")
		next_buttons[k].position = Vector2(w - bw, y)
		next_buttons[k].size = Vector2(bw, ListParts.ROW_H)
		next_buttons[k].text = menu.texts.t("party.supply.next")
		next_buttons[k].dimmed = m.level >= defs.battle.growth.level_cap
	if not show_supply:
		for line in BagRows.bag(menu.state, BagRows.CAMP_KINDS):
			var id: String = line["item"]
			row_items.append(id)
			var right := menu.texts.t("party.items.key") if _is_key(id) else menu.texts.t("party.count", {"n": item_count(id)})
			lines.append({"icon": item_icon(id), "name": item_label(id), "right": right, "id": id})
		if row_items.is_empty():
			lines.append({"name": menu.texts.t("party.items.none"), "dim": true, "press": false})
	# 커서 표시는 공용 목록이 칸마다 다시 켠다. 감춘 단추의 표시는 여기서 지운다.
	for b in [supply_button] + plus_buttons + exp_buttons + next_buttons:
		(b as PartyButton).selected = false
	inv.set_rows(lines)
	# 대원 이름 줄(줄 단추): 줄 번호 → 그 앞의 줄 단추 수.
	member_rows.clear()
	for li in member_lines:
		var r := 0
		for j in li:
			if bool((lines[j] as Dictionary).get("row", true)):
				r += 1
		member_rows.append(inv.rows[r] as ListButton)
	window.queue_redraw()


func item_icon(id: String) -> String:
	if _is_key(id):
		return BagRows.KEY_ICON
	return SheetParts.kind_icon(menu.state.defs, id) if menu.state.defs.battle.equip(id) != null else str(ShopTabs.ICONS["material"])


func item_label(id: String) -> String:
	if _is_key(id):
		return menu.texts.t(menu.state.defs.battle.key_items[id]["name_key"])
	return menu.item_name(id)


## 귀중품(열쇠, M3 A3) ID 인지.
func _is_key(id: String) -> bool:
	return menu.state.defs.battle.key_items.has(id)


func item_count(id: String) -> int:
	if _is_key(id):
		return 1 if menu.state.key_items.has(id) else 0
	if menu.state.defs.battle.equip(id) != null:
		return int(menu.state.gear_bag.get(id, 0))
	return int(menu.state.materials.get(id, 0))


## 설명 상자: 커서 칸의 것(가방 줄 = 그 장비·소재, 「+1」 = 그 장비, 대원 단추 = 그 대원, 알약 = 보급 설명). 커서가 없으면 빈 상자.
func _refresh_desc() -> void:
	var c := cursor_stop()
	if c == null:
		desc.show_desc("", "", [] as Array[String])
		return
	if c == supply_button:
		desc.show_desc(menu.texts.t("party.supply"), "", [menu.texts.t("party.supply.desc")] as Array[String])
		return
	var k := row_index(c)
	if k >= 0:
		_desc_item(row_items[k])
		return
	k = plus_buttons.find(c)
	if k >= 0:
		_desc_item(menu.state.defs.battle.equipment_ids[k])
		return
	k = exp_buttons.find(c)
	if k < 0:
		k = next_buttons.find(c)
	if k >= 0:
		desc.show_desc(menu.member_name(k), "", member_lines(k))


## 장비·소재 설명(07 §9.9 E2-b): 장비 = 값 · 받는 배율 · 낄 수 있는 직업 · 판매값(빈 줄은 뺀다), 소재 = 「소재」 · 판매값.
## 소재가 상점에서 무엇을 푸는지는 쓰지 않는다(원작도 쓰지 않는다).
func item_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	var t := menu.texts
	if _is_key(id):
		# 귀중품(M3 A3): 설명 글 · 「귀중품 · 팔 수 없다」(판매값 없음).
		return [t.t(menu.state.defs.battle.key_items[id]["desc_key"]), t.t("party.items.key_line")] as Array[String]
	var e := menu.state.defs.battle.equip(id)
	if e != null:
		for s in [PartyNames.values_text(menu.state, t, id), PartyNames.received_text(menu.state, t, id)]:
			if not str(s).is_empty():
				out.append(str(s))
		var fits := _fits_text(e)
		if not fits.is_empty():
			out.append(t.t("party.items.fits", {"classes": fits}))
	else:
		out.append(t.t("party.items.materials"))
	out.append(t.t("party.items.sell", {"money": ShopRules.sell_price(menu.state.defs, id)}))
	return out


func _desc_item(id: String) -> void:
	desc.show_desc(item_label(id), item_icon(id), item_lines(id))


## 대원 단추의 설명: 「Lv n」, 경험치, 「다음 레벨까지 n」(최대 레벨이면 「최대」).
func member_lines(i: int) -> Array[String]:
	var t := menu.texts
	var m := menu.state.party.members[i]
	var g := menu.state.defs.battle.growth
	var next := t.t("party.exp_next", {"n": g.cum(m.level + 1) - m.exp}) if m.level < g.level_cap else t.t("party.exp_max")
	return [t.t("party.level", {"level": m.level}), t.t("party.exp", {"exp": m.exp}), next] as Array[String]


## 낄 수 있는 직업(지금 파티의 직업 가운데, 파티 순서).
func _fits_text(e: BattleDb.EquipDef) -> String:
	var names: Array[String] = []
	var seen := {}
	for cid in menu.state.defs.party.class_ids:
		if seen.has(cid):
			continue
		seen[cid] = true
		var c: BattleDb.ClassDef = menu.state.defs.battle.classes.get(cid)
		if c != null and e.fits(c):
			names.append(menu.texts.t(c.name_key))
	return "·".join(names)
