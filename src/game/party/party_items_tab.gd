## 캠프 소지품 화면(07 §9.9 E2-b, research 08 §4.1: 원작 III HD 소지품 yt_eo3hd_05 — 목록·「使う」「捨てる」 알약·설명 상자·띠 「ITEM 12/60」).
## 대원 판은 없다(D27 ②). 맨 위는 뿌리의 띠(걸음 문패·장소 띠·소지금)이고, 알림 줄 자리의 띠에 「소지품   n/60」(공용 가방 D31, 넘쳤으면
## 「… · 가방이 넘쳤다」 경고 색)을 PartyMenu 가 쓴다(caption).
## 층(1280×720, 뒤 → 앞, M3 A4 설계 §6.1 층 표): 목록 창(부품 H, x 135~642 · y 178~468, 줄 넷이 다 보인다) → 「쓰기」 알약(원작 使う 자리
## x 735~975 · y 278~342) → 「버리기」 알약(원작 捨てる 자리 y 350~414, 장비·소재 줄에서도 자리가 그대로) → 「임시 보급」 알약(디버그만,
## y 430~494, D5) → 설명 상자(부품 I, x 288~990 · y 530~712, 고르기 중에는 감춘다) → 수량 창(ItemQty, 상점 수량 창 부품, 목록 창 가운데).
## 넓은 화면은 왼쪽 앵커 그대로, 높은 화면은 설명 상자가 아래에 붙고 목록 창이 줄 단위로 아래로 늘어난다(설명 상자 위 62 까지).
## 목록: 소모품 → 장비 → 소재 → 귀중품(BagRows.CAMP_KINDS)을 한 줄씩(묶음 머리 없음, 아이콘이 가른다, D1). 줄 = 종류 아이콘 · 이름 · 「n개」.
## 쪽(mode, 키 = 키패드): list(↑↓ 줄 사이, 돌지 않음) → Enter 로 pills(소모품 줄은 「쓰기」, 장비·소재 줄은 「버리기」에서 시작, 귀중품 줄은 아무 일 없음,
## ↑↓ 보이는 알약 사이, Enter = 그 알약, Esc = list) → 「쓰기」(대상이 있는 소모품)면 pick(설명 상자 대신 파티 카드, 방향 = 카드 사이,
## Enter·카드 누르기 = ItemRules.use, 받아들이면 list(커서는 그 물건 또는 가까운 줄), 거부면 이유만 보이고 pick 그대로, Esc = pills).
## 알약은 커서 줄 종류대로 보인다(설계 §6.1 표): 소모품 = 쓰기·버리기, 장비·소재 = 버리기만(쓰기 자리는 비운다), 귀중품 = 없음.
## 「쓰기」가 쓸 수 없으면(전투 전용·마을의 비콘·막힌 칸) 흐리고 누르면 이유만. 비콘은 확인 창(「돌아가기」 먼저) → 마을로(D2·§6.3).
## 「버리기」: 1개면 확인 창(「돌아가기」 먼저), 2개 이상이면 수량 창(「아니오」 먼저, D4·D25). 노랑은 하나: 알약·카드·창에 커서가 있으면
## 목록 커서 줄은 「chosen」(밝은 시안). 줄을 누르면 list 로 돌아가 커서가 그 줄로, 알약을 누르면 커서 줄에 대해 그 일을 한다.
## 디버그(07 §5.7): 「임시 보급」 알약이 커서 칸 0(줄 앞). 누르거나 Enter 로 보급 줄을 연다: 목록이 가방 줄 대신 장비마다 「+1」, 대원마다 이름 줄 아래
## 「경험치 +100」「다음 레벨까지」가 된다(GrowthRules.supply·grant_exp → 자동 저장). 커서는 알약과 보급 단추 사이, 단추를 누르면 커서도 그 단추로.
class_name PartyItemsTab
extends Control

## 1280×720 기준 자리(왼쪽 위 앵커). 설명 상자는 왼쪽 아래 앵커(아래 여백 8).
const LIST_BOX := Rect2(135, 178, 507, 290)
## 「쓰기」·「버리기」(원작 使う·捨てる 자리)와 디버그 「임시 보급」(D5: 使う 자리에서 아래로 옮겼다).
const USE_BOX := Rect2(735, 278, 240, 64)
const DROP_BOX := Rect2(735, 350, 240, 64)
const SUPPLY_BOX := Rect2(735, 430, 240, 64)
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
var use_button: ListButton
var drop_button: ListButton
## 버리기 수량 창(상점 수량 창 부품, 값 없는 꼴).
var qty: ShopDialog
## list · pills · pick
var mode := "list"
## 알약 커서: 0 「쓰기」 · 1 「버리기」.
var pill := 0
## 쓰기·버리기 대상 물건(알약을 고른 때 고정한다).
var target_item := ""
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
	inv.confirmable = func(c: Control) -> bool: return row_index(c) < 0 or row_kind(row_items[row_index(c)]) != "key"  # 귀중품 줄은 「선택」 흐림
	inv.changed.connect(func() -> void:
		_refresh_desc()
		_refresh_pills())
	inv.watch_resize(func() -> void:
		if menu.state != null and visible:
			refresh())
	use_button = _pill("ItemUse", USE_BOX, func() -> void: menu.handle("item_pill", 0))
	drop_button = _pill("ItemDrop", DROP_BOX, func() -> void: menu.handle("item_pill", 1))
	supply_button = _pill("SupplyToggle", SUPPLY_BOX, func() -> void: menu.handle("supply_toggle"))
	desc = DescBox.new()
	desc.name = "ItemsDesc"
	add_child(desc)
	PartyMenu.place(desc, Vector2(0, 1), Vector2(0, 1),
		Vector4(DESC_BOX.position.x, -DESC_BOTTOM - DESC_BOX.size.y, DESC_BOX.end.x, -DESC_BOTTOM))
	qty = ShopDialog.new()
	qty.name = "ItemQty"
	add_child(qty)
	qty.setup(m.texts)
	qty.route = func(kind: String, arg: Variant) -> void: menu.handle("qty", [kind, arg])
	qty.answered.connect(_on_qty_answered)


func _pill(n: String, box: Rect2, act: Callable) -> ListButton:
	var b := ListButton.new()
	b.name = n
	b.style = "pill"
	b.activated.connect(act)
	add_child(b)
	PartyMenu.place(b, Vector2.ZERO, Vector2.ZERO, Vector4(box.position.x, box.position.y, box.end.x, box.end.y))
	return b


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


## 화면에 들어올 때(캠프를 열 때·다른 화면에서 올 때): 보급 줄은 닫고, 쪽은 list, 커서는 첫 가방 줄(디버그면 알약 다음), 목록 맨 위.
func enter() -> void:
	supply_open = false
	mode = "list"
	target_item = ""
	if qty != null and qty.is_open():
		qty.close()
	if inv != null:
		inv.reset(1 if menu != null and menu.debug else 0)


func member_changed() -> void:
	pass


func context() -> String:
	return "%s|%s|%s|%s" % ["supply" if supply_open else "", mode, target_item, qty.mode if qty != null else ""]


## 수량 창이 떠 있는지(떠 있으면 그 창 입력만 받는다).
func qty_open() -> bool:
	return qty != null and qty.is_open()


## 목록 창 자리: 위 178 에서 줄 단위로, 아래 끝은 설명 상자 위 DESC_GAP 까지(720 에서 줄 넷, 960 에서 일곱).
static func list_rect(s: Vector2) -> Rect2:
	var desc_top := s.y - DESC_BOTTOM - DESC_BOX.size.y
	var n := ListParts.rows_for(desc_top - DESC_GAP - LIST_BOX.position.y)
	return Rect2(LIST_BOX.position, Vector2(LIST_BOX.size.x, ListParts.list_height(n)))


func place(s: Vector2) -> void:
	var lr := list_rect(s)
	PartyMenu.place(window, Vector2.ZERO, Vector2.ZERO, Vector4(lr.position.x, lr.position.y, lr.end.x, lr.end.y))
	qty.set_area(lr)
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


## Enter 가 할 일이 있는지(키패드 「선택」 = 키): 알약·고르기 쪽은 늘, 목록 쪽은 알약·보급 단추·귀중품 아닌 가방 줄.
func can_confirm() -> bool:
	if mode != "list":
		return true
	return inv.can_confirm()


## ↑↓ 가 갈 칸이 있는지(칸이 없으면 흐림). 알약 쪽은 보이는 알약이 둘일 때.
func can_move() -> bool:
	if mode == "pills":
		return _pills_shown().size() > 1
	return mode == "list" and inv.can_move()


## 띠 글(알림이 없을 때, 원작 띠 「ITEM 12/60」): 「소지품   n/60」(공용 가방 D31, BagRules.used), 넘쳤으면 「… · 가방이 넘쳤다」(N3).
## 고르기 중에는 물음 「{물건}: 누구에게 쓸까?」(거부 이유가 잠깐 덮고 끝나면 돌아온다).
func caption() -> String:
	if mode == "pick":
		return menu.texts.t("party.items.pick", {"item": item_label(target_item)})
	var used := BagRules.used(menu.state)
	return menu.texts.t("party.items.strip_over" if over() else "party.items.strip", {"used": used, "slots": BagRules.SLOTS})


## 가방이 60칸을 넘었는지(옛 저장, 띠를 경고 색으로).
func over() -> bool:
	return BagRules.used(menu.state) > BagRules.SLOTS


func dispatch(kind: String, arg: Variant) -> bool:
	var ids := menu.state.defs.battle.equipment_ids
	match kind:
		"qty":
			var a: Array = arg if arg is Array else []
			return qty.handle(str(a[0]), a[1]) if qty_open() and a.size() == 2 else false
		"cursor":
			if mode == "pills":
				return _pill_move(int(arg) if arg != null else 1)
			if mode != "list":
				return false
			return inv.move(int(arg) if arg != null else 1)
		"confirm":
			match mode:
				"pills":
					return _act(pill)
				"pick":
					return _use_on(menu.pick_cursor)
			# 가방 줄: 알약 쪽으로(귀중품 줄은 아무 일 없음, 키패드 「선택」 흐림). 아니면 커서 칸(대원 단추면 그 대원 이름 줄까지)을
			# 보이게 한 뒤 누른다.
			if row_index(cursor_stop()) >= 0:
				return _enter_pills()
			return inv.confirm(_press)
		"item_row":
			var i := int(arg) if arg != null else -1
			var k := stops().find(inv.rows[i]) if i >= 0 and i < inv.used else -1
			if k < 0:
				return false
			if mode != "list":
				_to_list()  # 알약·고르기 쪽에서 줄을 누르면 목록 쪽으로(커서는 그 줄)
				if k == cursor:
					return true
			elif k == cursor:
				return false
			return inv.point(inv.rows[i])
		"item_pill":
			return _pill_press(int(arg) if arg != null else -1)
		"mode_back":
			match mode:
				"pills":
					_to_list()
					return true
				"pick":
					mode = "pills"
					return true
			return false
		"pick_move":
			if mode != "pick":
				return false
			var to := menu.pick_target(menu.pick_cursor, arg as Vector2i)
			if to == menu.pick_cursor:
				return false
			menu.pick_cursor = to
			return true
		"pick_member":
			var i := int(arg) if arg != null else -1
			if mode != "pick" or i < 0 or i >= menu.state.party.members.size():
				return false
			menu.pick_cursor = i
			return _use_on(i)
	if not menu.debug:
		return false
	match kind:
		"supply_toggle":
			supply_open = not supply_open
			mode = "list"
			target_item = ""
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


# ---- 쓰기·버리기(M3 A4b) ----

## 지금 커서 가방 줄의 물건 ID(가방 줄이 아니면 "").
func cursor_item() -> String:
	var k := row_index(cursor_stop())
	return row_items[k] if k >= 0 and k < row_items.size() else ""


## 물건 종류: consumable · gear · material · key · ""(없음).
func row_kind(id: String) -> String:
	if id.is_empty():
		return ""
	if _is_key(id):
		return "key"
	if id.begins_with("use."):
		return "consumable"
	if id.begins_with("equip."):
		return "gear"
	return "material"


## 알약이 대상으로 삼는 물건: 알약·고르기 쪽은 고정한 물건, 목록 쪽은 커서 줄.
func pill_item() -> String:
	return target_item if mode != "list" else cursor_item()


## 보이는 알약 번호(0 쓰기 · 1 버리기, 설계 §6.1 표).
func _pills_shown() -> Array[int]:
	var out: Array[int] = []
	if supply_open:
		return out
	var k := row_kind(pill_item())
	if k == "consumable":
		out.append(0)
	if k in ["consumable", "gear", "material"]:
		out.append(1)
	return out


## 「쓰기」가 지금 안 되는 이유(대원과 상관없는 것만: 전투 전용·마을의 비콘·막힌 칸 등). 대원마다의 이유는 고르기에서 보인다.
func use_why(id: String) -> String:
	var w := ItemRules.use_block(menu.state, id, -1)
	return "" if w == "bad_member" else w


func _enter_pills() -> bool:
	var id := cursor_item()
	var shown := _pills_shown()
	if shown.is_empty():
		return false
	mode = "pills"
	target_item = id
	pill = shown[0]
	return true


func _to_list() -> void:
	mode = "list"
	target_item = ""


func _pill_move(d: int) -> bool:
	var shown := _pills_shown()
	var at := shown.find(pill)
	var to := clampi(at + d, 0, shown.size() - 1)
	if at < 0 or to == at:
		return false
	pill = shown[to]
	return true


## 알약 누르기: 그 알약이 보이면 커서 줄에 대해 그 일을 한다(알약 쪽으로 옮겨 커서를 그 알약에).
func _pill_press(i: int) -> bool:
	var id := pill_item()
	if not _pills_shown().has(i):
		return false
	mode = "pills"
	target_item = id
	pill = i
	return _act(i)


func _act(i: int) -> bool:
	return _use(target_item) if i == 0 else _drop(target_item)


## 「쓰기」: 안 되면 이유만. 비콘은 확인 창(「돌아가기」 먼저), 대상이 있는 것은 고르기(첫 커서 = 쓸 수 있는 첫 대원).
func _use(id: String) -> bool:
	var why := use_why(id)
	if not why.is_empty():
		menu.show_notice(menu.texts.t("item.why." + why))
		return true
	var c := menu.state.defs.battle.consumable(id)
	if c.effect == "return":
		menu.open_dialog("beacon", func() -> void: _use_on(-1))
		return true
	mode = "pick"
	menu.pick_cursor = 0
	for i in menu.state.party.members.size():
		if ItemRules.use_block(menu.state, id, i).is_empty():
			menu.pick_cursor = i
			break
	menu.clear_notice()
	return true


## 대원 i 에게 쓴다(비콘은 -1). 받아들이면 목록 쪽(커서는 그 물건 또는 가까운 줄), 거부면 이유만 보이고 고르기 그대로.
func _use_on(i: int) -> bool:
	var id := target_item
	if menu.apply(ItemRules.use(menu.state, id, i), "item.why.") and menu.is_open():
		_back_to_list(id)
	return true


## 「버리기」: 1개면 확인 창(「돌아가기」 먼저), 2개 이상이면 수량 창(「아니오」 먼저, 1~가진 수).
func _drop(id: String) -> bool:
	var n := item_count(id)
	if n < 1 or row_kind(id) == "key":
		return false
	if n == 1:
		menu.open_dialog("drop", func() -> void: _do_drop(id, 1), {"item": item_label(id)})
	else:
		qty.open_count(item_icon(id), item_label(id), n, "party.items.drop_qty")
	return true


func _on_qty_answered(yes: bool, n: int) -> void:
	if yes:
		_do_drop(target_item, n)


func _do_drop(id: String, n: int) -> void:
	if menu.apply(ItemRules.discard(menu.state, id, n), "item.why."):
		_back_to_list(id)


## 받아들인 뒤 목록 쪽으로: 커서는 그 물건 줄, 없어졌으면 앞 줄 번호와 새 마지막 줄 가운데 작은 곳(Q9).
func _back_to_list(id: String) -> void:
	var old := maxi(row_index(cursor_stop()), 0)
	_to_list()
	refresh()
	if row_items.is_empty():
		inv.reset(1 if menu.debug else 0)
		return
	var at := row_items.find(id)
	if at < 0:
		at = mini(old, row_items.size() - 1)
	var k := stops().find(inv.rows[at])
	if k >= 0:
		cursor = k


## 알약 모양: 보이는 것·흐림(쓰기를 못 하는 이유)·노랑(알약 쪽 커서). 노랑은 하나: 알약·고르기·창이면 목록 커서는 chosen.
func _refresh_pills() -> void:
	if menu == null or menu.state == null:
		return
	var shown := _pills_shown()
	var id := pill_item()
	use_button.visible = shown.has(0)
	drop_button.visible = shown.has(1)
	use_button.text = menu.texts.t("party.items.use")
	drop_button.text = menu.texts.t("party.items.drop")
	use_button.dimmed = use_button.visible and not use_why(id).is_empty()
	use_button.selected = mode == "pills" and pill == 0 and menu.dialog_kind.is_empty() and not qty_open()
	drop_button.selected = mode == "pills" and pill == 1 and menu.dialog_kind.is_empty() and not qty_open()
	for b in [use_button, drop_button]:
		(b as ListButton).queue_redraw()
	desc.visible = mode != "pick"
	inv.set_cursor_mode("cursor" if mode == "list" and menu.dialog_kind.is_empty() and not qty_open() else "chosen")


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
		if mode != "list" and not row_items.has(target_item):
			_to_list()  # 대상이 가방에서 없어졌다(다른 길로 바뀐 상태)
	# 커서 표시는 공용 목록이 칸마다 다시 켠다. 감춘 단추의 표시는 여기서 지운다.
	for b in [supply_button] + plus_buttons + exp_buttons + next_buttons:
		(b as PartyButton).selected = false
	inv.set_rows(lines)
	_refresh_pills()
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
	if id.begins_with("use."):
		return BagRows.CONSUMABLE_ICON
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
	if id.begins_with("use."):
		return int(menu.state.consumables.get(id, 0))
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


## 장비·소재 설명(07 §9.9 E2-b): 장비 = 값 · 받는 배율 · 낄 수 있는 직업 · 판매값(빈 줄은 뺀다),
## 소모품(M3 A4) = 설명 글 · 「소모품」 · 판매값. 소재(M3 A5) = 설명 글 · 「소재」 · 판매값.
## 소재가 상점에서 무엇을 푸는지는 쓰지 않는다(원작도 쓰지 않는다).
func item_lines(id: String) -> Array[String]:
	var out: Array[String] = []
	var t := menu.texts
	if _is_key(id):
		# 귀중품(M3 A3): 설명 글 · 「귀중품 · 팔 수 없다」(판매값 없음).
		return [t.t(menu.state.defs.battle.key_items[id]["desc_key"]), t.t("party.items.key_line")] as Array[String]
	var c := menu.state.defs.battle.consumable(id)
	var e := menu.state.defs.battle.equip(id)
	if c != null:
		out.append(t.t(c.desc_key))
		out.append(t.t("party.items.consumable"))
	elif e != null:
		for s in [PartyNames.values_text(menu.state, t, id), PartyNames.received_text(menu.state, t, id)]:
			if not str(s).is_empty():
				out.append(str(s))
		var fits := _fits_text(e)
		if not fits.is_empty():
			out.append(t.t("party.items.fits", {"classes": fits}))
	else:
		# 소재(M3 A5, 설계 §2.6): 소모품처럼 설명 글 · 「소재」 · 판매값.
		var dk := str(menu.state.defs.battle.material_desc.get(id, ""))
		if not dk.is_empty():
			out.append(t.t(dk))
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
