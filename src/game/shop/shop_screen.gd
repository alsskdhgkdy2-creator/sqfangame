## 상점 화면(08 §8, M3 R4 S3a): 미궁 화면 위에 덮는 전체 화면 층(창 층 2). 캠프(PartyMenu)와 같은 뼈대다:
## 열린 동안 탐색 화면은 HUD 를 감추고 3D 시야만 남기며, 상점은 그것을 어둡게(CAMP_DIM) 하고 그 위에 원작 HD 상점 화면의 짜임을 띄운다.
## 쪽(page): root(뿌리: 문패·설명 띠·소지금 문패·명령 다섯·파티 카드, 원작 facility_img3) → branch(구매 갈래: 「사기」는 고른 모양,
## 하위 목록 넷·오른쪽 인물 판, 원작 B) → buy(구매 목록: §7.1 층 표 = ShopFrame·탭·칸 목록·설명 창·인물 판, 원작 B 무기·C 방어구).
## 뿌리 「팔기」 → sell(판매 목록 §8.8: 소재·장비·소모품 탭, 「여러 개」 단추). 구매·판매 목록은 같은 짜임(ShopFrame·탭 줄·칸 목록)을 쓴다.
## 팔기 흐름(§8.8): 한 줄(2개 이상 = 수량 창, 1개 = 확인 창) 또는 여러 개(고른 줄 모두를 한 묶음) → ShopRules.sell → 입하 알림.
## 사기 흐름(§8.6): 줄 → 확인 창(ShopRules.buy) → 장착 물음 → 무기는 칸 0, 방어구·장신구는 칸 고르기 창(GrowthRules.equip).
## 창이 이어지는 동안 대상 물건·대원은 확인 창을 연 때의 것으로 고정한다(ask_item·ask_member).
## 상태는 규칙 함수(ShopRules.buy·GrowthRules.equip)로만 바꾸고, 받아들여지면 save_hook(자동 저장) 뒤 changed 를 낸다. 저장이 실패해도
## 메모리 상태를 되돌리거나 규칙을 다시 부르지 않고 차례를 이어 간다(§8.11 F6, 실패 안내는 탐색 화면의 토스트).
##
## 입력 입구 하나(§8, 07 §9.4): 단추·목록 줄·탭·창 단추(ShopDialog.route)·키보드·가상 키패드가 모두 handle() 로 온다.
## 층 3 창이 떠 있으면(blocked_hook) 아무것도 받지 않고, 한 프레임에 입력 하나만 받는다. 문맥(쪽·갈래·탭·대원·창의 목적·대상)이 바뀌면
## 눌려 있던 포인터를 모두 버린다. 열린 동안 키 누름은 모두 여기서 끝난다(P 도 아무 일 없음). 키보드와 키패드는 키 표 key_action 하나를 같이 쓴다.
class_name ShopScreen
extends Control

signal opened
signal closed
## 규칙 함수가 상태를 바꿨다(저장 갈고리 뒤). 탐색 화면이 상태 칸·디버그를 새로 맞춘다.
signal changed(events: Array)

## 지금 여는 상점(D24 임시 입구는 이것 하나).
const SHOP_ID := "shop.junk_workshop"
## 뿌리 명령(원작 다섯 줄, 숫자 키 1~5).
const ROOT_KEYS := ["buy", "sell", "talk", "equip", "leave"]
## 흐린 명령: 누르면 이유만(NPC·상점 안 장비 바꾸기는 S4·M3, §8.3).
const ROOT_DIM := ["talk", "equip"]
## 구매 갈래(숫자 키 1~4).
const BRANCH_KEYS := ["weapon", "armor", "accessory", "item"]
## 탭 줄이 있는 갈래(ShopTabs.SETS 이름). 없는 갈래의 종류: 장신구, 아이템(소모품은 다음 단계라 빈 목록, D24).
const BRANCH_TABS := ["weapon", "armor"]
const BRANCH_KINDS := {"accessory": ["accessory"], "item": []}
## 뿌리 명령 목록(§8.3): x 0~430, y 166~510(줄 64, 사이 4, 안쪽 여백 4).
const ROOT_TOP := 166.0
const ROOT_GAP := 4.0
const ROOT_PAD := 4.0
## 구매 갈래 하위 목록(§8.4): x 440, 폭 300, 위 끝 = 「사기」 줄 위 끝.
const BRANCH_X := 440.0
const BRANCH_W := 300.0
## 구매 갈래의 파티 카드: x PAD_SIDE ~ 인물 판 왼쪽 − 24(§8.4).
const CARDS_GAP := 24.0
const NOTICE_SEC := 2.5
## 설명 창 직업 머리글자 칸 차례(shop.badge.*, §8.5).
const BADGE_CLASSES := ["holo_knight", "blade_duelist", "nano_medic", "glyph_wizard"]
## 가상 키패드 단추 → 같은 일을 하는 물리 키(캠프와 같다).
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 키패드 자리(캠프와 같은 값): 십자 왼쪽 아래 (8, 511), 뿌리 「취소」「선택」 가로 (W − 247, 427), 그 밖 세로 (W − 118, 548).
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_ROOT := Vector2(-247, -293)
const PAD_KEYS_SIDE := Vector2(-118, -172)
## 상점 쪽 거부 이유 중 그 글이 있는 것(나머지는 shop.why.not_now, §8.10).
const WHY_KEYS := ["no_money", "sold_out", "bag_full", "money_full", "not_now"]
## 「여러 개」 단추 자리(탭 줄 왼쪽 빈 곳, §8.8).
const MULTI := Rect2(16, 166, 200, 64)

# ---- 바깥에서 정하는 값 ----
## 상점 위에 다른 창(층 3 모달)이 떠 있으면 true: 그동안 아무 입력도 받지 않는다.
var blocked_hook: Callable
## 규칙 함수가 상태를 바꾼 직후 부른다(자동 저장).
var save_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## root · branch · buy
var page := "root"
var root_cursor := 0
var branch_cursor := 0
## 구매 목록의 갈래(BRANCH_KEYS 번호)·탭.
var branch := 0
var tab := 0
var member := 0
## 창의 목적: "" · buy(사기 확인) · equip(장착 물음) · slots(칸 고르기). 대상 물건·대원은 확인 창을 연 때 고정한다.
var ask := ""
var ask_item := ""
var ask_member := 0
## 묶음 팔기 확인 창을 연 때의 팔 줄 [{item, qty}](검토 R3). 「예」는 이 줄만 판다. 창이 닫히면 비운다.
var ask_lines: Array = []
var notice := ""
## 받아들인 입력 수(시험·디버그).
var accepted_inputs := 0
## 지금 목록 줄. 구매 = ShopRules.catalog 줄 + kind, 판매 = {item, count, price, kind}.
var lines: Array[Dictionary] = []
## 판매 「여러 개」 켜짐과 고른 물건(ID → true).
var multi := false
var marked := {}

# ---- 부품 ----
var cards: PartyCards
var plate: FacilityPlate
var banner: FacilityBanner
var money_plate: Control
var root_list: FacilityList
var branch_list: FacilityList
var branch_panel: CharPanel
## 판매 목록의 「여러 개」 단추(x 16, y 166, 200×64, §8.8).
var multi_button: PartyButton
var frame: ShopFrame
var buy_list: ShopList
var buy_tabs: ShopTabs
var dialog: ShopDialog
var dir_pad: VirtualPad
var key_pad: VirtualPad
var key_pad_stacked: VirtualPad
var _notice_left := 0.0
var _tabs_set := ""
var _built := false
var _open := false
var _input_frame := -1
var _context := ""


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 빈 곳 누르기를 막는다(뒤 탐색 화면에 닿지 않게)
	focus_mode = FOCUS_NONE
	visible = false


## 부품을 만든다. 트리 순서 = 그리는·누르는 순서: 카드 → 문패·띠·소지금(장식) → 명령 목록 → 하위 목록 → 갈래 판·「뒤로」 →
## 구매 짜임(ShopFrame) → 칸 목록 → 탭 줄 → 상점 창 → 가상 키패드(창 위: 창이 떠 있어도 누를 수 있다, §8.3).
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	cards = PartyCards.new()
	cards.name = "ShopCards"
	add_child(cards)
	plate = FacilityPlate.new()
	plate.name = "ShopPlate"
	add_child(plate)
	banner = FacilityBanner.new()
	banner.name = "ShopBanner"
	add_child(banner)
	banner.place()
	money_plate = Control.new()
	money_plate.name = "ShopMoney"
	money_plate.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(money_plate)
	var t := ShopFrame.TITLE
	PartyMenu.place(money_plate, Vector2.ZERO, Vector2.ZERO, Vector4(t.position.x, t.position.y, t.end.x, t.end.y))
	money_plate.draw.connect(func() -> void: ShopFrame.paint_title(money_plate, money_text(), true))
	root_list = _facility_list("ShopRootList", "Root_", ROOT_KEYS, "root")
	branch_list = _facility_list("ShopBranchList", "Branch_", BRANCH_KEYS, "branch")
	branch_panel = CharPanel.new()
	branch_panel.name = "BranchPanel"
	add_child(branch_panel)
	branch_panel.build("Branch")
	branch_panel.step.connect(func(d: int) -> void: handle("member_step", d))
	frame = ShopFrame.new()
	frame.name = "BuyFrame"
	add_child(frame)
	frame.build("Buy", texts.t("camp.back"), true, ShopFrame.PAD_SIDE, ShopFrame.TABS_LIST_TOP)
	frame.back.connect(func() -> void: handle("back"))
	frame.panel.step.connect(func(d: int) -> void: handle("member_step", d))
	buy_list = ShopList.new()
	buy_list.name = "BuyList"
	buy_list.new_text = texts.t("shop.new")
	add_child(buy_list)
	buy_list.route = func(i: int) -> void: handle("row", i)  # 커서는 화면이 받은 뒤에만 옮긴다(검토 R1)
	buy_tabs = ShopTabs.new()
	buy_tabs.name = "BuyTabs"
	add_child(buy_tabs)
	buy_tabs.route = func(i: int) -> void: handle("tab", i)  # 고른 칸도 화면이 받은 뒤에만
	multi_button = PartyButton.new()
	multi_button.name = "MultiButton"
	add_child(multi_button)
	PartyMenu.place(multi_button, Vector2.ZERO, Vector2.ZERO, Vector4(MULTI.position.x, MULTI.position.y, MULTI.end.x, MULTI.end.y))
	multi_button.activated.connect(func() -> void: handle("multi"))
	dialog = ShopDialog.new()
	dialog.name = "ShopDialog"
	add_child(dialog)
	dialog.setup(texts)
	dialog.route = func(kind: String, arg: Variant) -> void: handle("dialog", [kind, arg])
	dialog.answered.connect(_on_answered)
	dialog.slot_picked.connect(_on_slot_picked)
	dialog.closed.connect(func() -> void: ask = "")  # 입하 알림을 닫았다
	_build_pads()
	_layout()


func _facility_list(n: String, row_prefix: String, keys: Array, kind: String) -> FacilityList:
	var l := FacilityList.new()
	l.name = n
	l.row_gap = ROOT_GAP
	l.inner_pad = ROOT_PAD
	add_child(l)
	var items := []
	for i in keys.size():
		items.append({"name": row_prefix + str(keys[i]), "text": ""})
	l.set_items(items)
	l.pressed.connect(func(i: int) -> void: handle(kind, i))
	return l


func _build_pads() -> void:
	var ok := texts.t("battle.ui.pad_ok")
	var back := texts.t("battle.ui.pad_back")
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	key_pad = VirtualPad.new().setup_keys(ok, back)
	key_pad.name = "KeyPad"
	key_pad_stacked = VirtualPad.new().setup_keys(ok, back, true)
	key_pad_stacked.name = "KeyPadStacked"
	for p in [dir_pad, key_pad, key_pad_stacked]:
		add_child(p)
		(p as VirtualPad).pressed.connect(_on_vpad)


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


## 연다(§8.1): 늘 뿌리·명령 커서 0·대원 0, 알림 없음.
func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	page = "root"
	root_cursor = 0
	branch_cursor = 0
	branch = 0
	tab = 0
	member = 0
	ask = ""
	ask_item = ""
	ask_member = 0
	ask_lines = []
	lines = []
	multi = false
	marked.clear()
	dialog.close()
	_clear_notice()
	_open = true
	visible = true
	_setup_cards()
	cancel_pointers()
	_context = ""
	_layout()
	_refresh()
	opened.emit()


## 닫는다. 떠 있던 창·물음을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_shop(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	dialog.close()
	ask = ""
	ask_lines = []
	_clear_notice()
	cancel_pointers()
	if notify:
		closed.emit()


## 눌려 있던 포인터·끌기를 모두 버린다(문맥이 바뀔 때, 바깥 층 3 창이 열리고 닫힐 때 탐색 화면이 부른다).
func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


func _setup_cards() -> void:
	cards.setup(BattleDisplay.from_party(state, texts), state.defs.party.class_ids)
	for c in cards.cards:
		c.mouse_filter = MOUSE_FILTER_IGNORE  # 상점의 카드는 읽기만
		c.snap()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만. 층 3 창이 떠 있으면(blocked_hook) 아무것도 받지 않는다.
## 뿌리: root(0~4)·root_cursor(±1)·confirm·back·close. 구매 갈래: branch(0~3)·branch_cursor(±1)·confirm·member_step(±1)·
## root(뿌리 명령 줄)·back·close. 구매 목록: row(줄)·cursor(±1)·confirm·tab(칸)·tab_step(±1)·member_step(±1)·back·close.
## 창이 떠 있으면 dialog([ShopDialog 입력 종류, 값])만 받는다(창 단추·키·키패드 모두 이 길).
func handle(kind: String, arg: Variant = null) -> bool:
	if not _open:
		return false
	if blocked_hook.is_valid() and blocked_hook.call():
		return false
	var f := Engine.get_process_frames()
	if f == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = f
		accepted_inputs += 1
		_refresh()
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	if dialog.is_open():
		if kind != "dialog" or typeof(arg) != TYPE_ARRAY or (arg as Array).size() != 2:
			return false  # 창이 떠 있는 동안 Q/E·판 화살표·탭·숫자 키·뒤 화면 단추는 일하지 않는다(§8.6)
		return dialog.handle(str(arg[0]), arg[1])
	match page:
		"root":
			return _dispatch_root(kind, arg)
		"branch":
			return _dispatch_branch(kind, arg)
		"buy":
			return _dispatch_buy(kind, arg)
		"sell":
			return _dispatch_sell(kind, arg)
	return false


func _dispatch_root(kind: String, arg: Variant) -> bool:
	match kind:
		"root_cursor":
			root_cursor = wrapi(root_cursor + (int(arg) if arg != null else 1), 0, ROOT_KEYS.size())
			return true
		"root":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= ROOT_KEYS.size():
				return false
			root_cursor = i
			return _run_root(i)
		"confirm":
			return _run_root(root_cursor)
		"back", "close":
			close_shop()
			return true
	return false


## 뿌리 명령: 사기 → 구매 갈래, 팔기 → 판매 목록(S3b), 대화·장비 바꾸기 → 이유, 나가기 → 닫기.
func _run_root(i: int) -> bool:
	match ROOT_KEYS[i]:
		"buy":
			page = "branch"
			branch_cursor = 0
			_clear_notice()
		"sell":
			_open_sell()
		"talk", "equip":
			show_notice(texts.t("shop.why." + ROOT_KEYS[i]))
		"leave":
			close_shop()
	return true


## 판매 목록을 연다(§8.8): 소재 탭·커서 0·맨 위·여러 개 꺼짐.
func _open_sell() -> void:
	page = "sell"
	tab = 0
	multi = false
	marked.clear()
	_clear_notice()
	if _tabs_set != "sell":
		_tabs_set = "sell"
		buy_tabs.setup("sell", texts.t("shop.tab.all"))
	_reset_rows()


func _dispatch_sell(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor", "tab", "tab_step", "member_step", "close":
			if kind == "tab" or kind == "tab_step":
				var before := tab
				var ok := _dispatch_buy(kind, arg)
				if ok and tab != before:
					marked.clear()  # 탭을 바꾸면 고름을 지운다(여러 개 켜짐은 그대로)
				return ok
			return _dispatch_buy(kind, arg)
		"row":
			return _sell_row(int(arg) if arg != null else -1)
		"confirm":
			return _sell_row(buy_list.cursor)
		"multi":
			if not multi:
				multi = true
				return true
			if marked.is_empty():
				multi = false
				return true
			_ask_sell_multi()
			return true
		"back":
			if multi:
				multi = false  # 「취소」·「뒤로」는 고름을 지우고 여러 개를 끈다
				marked.clear()
				return true
			page = "root"
			root_cursor = 1  # 떠난 자리 「팔기」
			_clear_notice()
			return true
	return false


## 판매 줄 i: 여러 개면 고름을 켜고 끈다. 아니면 2개 이상은 수량 창, 1개는 확인 창(첫 커서 「예」).
func _sell_row(i: int) -> bool:
	if i < 0 or i >= lines.size():
		return false
	buy_list.set_cursor(i)
	var line := lines[i]
	var item: String = line["item"]
	if multi:
		if marked.has(item):
			marked.erase(item)
		else:
			marked[item] = true
		return true
	ask = "sell"
	ask_item = item
	ask_member = member
	var n := int(line["count"])
	var unit := int(line["price"])
	if n >= 2:
		dialog.open_qty(str(line["icon"]), sell_name(item), unit, n, "shop.qty.sell", true)
	else:
		dialog.open_confirm(texts.t("shop.confirm.sell", {"total": ShopRow.grouped(unit)}), true, str(line["icon"]), sell_name(item))
	return true


## 고른 줄(목록 차례, 가진 수 전부)의 팔기 줄.
func marked_lines() -> Array:
	var out := []
	for line in lines:
		if marked.has(line["item"]):
			out.append({"item": line["item"], "qty": int(line["count"])})
	return out


## 「고른 것 팔기」: 고른 줄 모두에 대한 확인 창(한 줄을 가리키지 않으므로 목록 커서는 "none").
func _ask_sell_multi() -> void:
	var total := 0
	var ids: Array[String] = []
	ask_lines = marked_lines()
	for x in ask_lines:
		total += ShopRules.sell_price(state.defs, x["item"]) * int(x["qty"])
		ids.append(x["item"])
	ask = "sell_multi"
	ask_item = ",".join(ids)
	ask_member = member
	dialog.open_confirm(texts.t("shop.confirm.sell", {"total": ShopRow.grouped(total)}), true)


## 팔기(§8.8 끝난 뒤 상태 F1). 거부: 이유만(고름·여러 개 그대로, 저장 없음). 받아들임: 저장 한 번, 고름을 지우고 여러 개를 끄고,
## 커서는 같은 물건(없어졌으면 앞 줄 번호와 새 마지막 줄 가운데 작은 곳). 풀림이 있으면 입하 알림 한 번.
func _do_sell(sell: Array) -> void:
	var cur_item: String = lines[buy_list.cursor]["item"] if buy_list.cursor >= 0 and buy_list.cursor < lines.size() else ""
	var cur_i := buy_list.cursor
	var events := ShopRules.sell(state, SHOP_ID, sell)
	if not _apply_shop(events):
		return
	marked.clear()
	multi = false
	lines = sell_lines()
	buy_list.set_rows(sell_rows_of(lines))
	var at := -1
	for i in lines.size():
		if lines[i]["item"] == cur_item:
			at = i
	if at < 0:
		at = mini(cur_i, lines.size() - 1)
	buy_list.set_cursor(maxi(at, 0))
	for ev in events:
		if ev["type"] == "unlocked":
			var items := []
			for id in ev["items"]:
				items.append({"icon": icon_of(str(id)), "name": PartyNames.item_name(state, texts, str(id))})
			ask = "notice"
			ask_item = ",".join(PackedStringArray(ev["items"]))
			dialog.open_notice(texts.t(state.defs.battle.shop(SHOP_ID).name_key), items)


func _dispatch_branch(kind: String, arg: Variant) -> bool:
	match kind:
		"branch_cursor":
			branch_cursor = wrapi(branch_cursor + (int(arg) if arg != null else 1), 0, BRANCH_KEYS.size())
			return true
		"branch":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= BRANCH_KEYS.size():
				return false
			_open_list(i)
			return true
		"confirm":
			_open_list(branch_cursor)
			return true
		"member_step":
			return _step_member(arg)
		"root":
			# 갈래에서도 뿌리 명령 줄은 일한다(캠프 고르기와 같다). 「사기」를 다시 누르면 아무 일도 없다.
			var i := int(arg) if arg != null else -1
			if i <= 0 or i >= ROOT_KEYS.size():
				return false
			if ROOT_KEYS[i] == "leave":
				close_shop()
				return true
			return _run_root(i)
		"back":
			page = "root"
			root_cursor = 0  # 떠난 자리 「사기」
			_clear_notice()
			return true
		"close":
			close_shop()
			return true
	return false


func _dispatch_buy(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			# 돌지 않는 ↑↓(공용 목록): 끝에서는 옮기지 않고, 커서 줄이 손으로 내려 가려져 있으면 보이게만 한다(입력 하나, 07 §9.7).
			var d := int(arg) if arg != null else 1
			var at := buy_list.cursor
			if lines.is_empty() or at < 0 or d == 0:
				return false
			var to := clampi(at + d, 0, lines.size() - 1)
			return buy_list.inv.move(to - at if to != at else d)
		"row":
			return _buy_row(int(arg) if arg != null else -1)
		"confirm":
			return _buy_row(buy_list.cursor)
		"tab":
			var i := int(arg) if arg != null else -1
			if not has_tabs() or i < 0 or i >= buy_tabs.kinds.size() or i == tab:
				return false
			_set_tab(i)
			return true
		"tab_step":
			if not has_tabs():
				return false
			var to_tab := clampi(tab + (int(arg) if arg != null else 1), 0, buy_tabs.kinds.size() - 1)  # 끝에서 감기지 않는다
			if to_tab == tab:
				return false
			_set_tab(to_tab)
			return true
		"member_step":
			return _step_member(arg)
		"back":
			page = "branch"
			branch_cursor = branch  # 떠난 자리 그 갈래
			_clear_notice()
			return true
		"close":
			close_shop()
			return true
	return false


func _step_member(arg: Variant) -> bool:
	var n := state.party.members.size()
	if n < 2:
		return false
	member = wrapi(member + (int(arg) if arg != null else 1), 0, n)
	return true


## 판매 목록 탭 차례(ShopTabs.SETS["sell"]).
const SELL_KINDS := ["material", "gear", "consumable"]


## 갈래 i 의 구매 목록을 연다: 탭 0, 커서 0, 맨 위.
func _open_list(i: int) -> void:
	branch = i
	branch_cursor = i
	page = "buy"
	tab = 0
	_clear_notice()
	if has_tabs() and _tabs_set != BRANCH_KEYS[i]:
		_tabs_set = BRANCH_KEYS[i]
		buy_tabs.setup(_tabs_set, texts.t("shop.tab.all"))
	_reset_rows()


func _set_tab(i: int) -> void:
	tab = i
	_reset_rows()


## 줄을 지금 갈래·탭으로 다시 놓고 커서 0·맨 위로.
func _reset_rows() -> void:
	lines = buy_lines() if page == "buy" else sell_lines()
	buy_list.set_rows(rows_of(lines) if page == "buy" else sell_rows_of(lines))
	buy_list.set_cursor(0)
	buy_list.scroll.scroll_to(0.0)


## 지금 목록에 탭 줄이 있는지(구매 무기·방어구, 판매).
func has_tabs() -> bool:
	return page == "sell" or (page == "buy" and BRANCH_TABS.has(BRANCH_KEYS[branch]))


# ---- 사기 흐름(§8.6) ----

## 줄 i 를 산다: 사지 못하면 이유만(창 없음), 아니면 확인 창(첫 커서 「예」, D25). 대상 물건·대원은 여기서 고정한다.
func _buy_row(i: int) -> bool:
	if i < 0 or i >= lines.size():
		return false
	buy_list.set_cursor(i)
	var line := lines[i]
	var item: String = line["item"]
	if sold_out(line):
		show_notice(sold_out_text(item))
		return true
	if not bool(line["affordable"]):
		show_notice(texts.t("shop.why.no_money"))
		return true
	if int(state.gear_bag.get(item, 0)) >= BattleLimits.BAG_MAX:
		show_notice(texts.t("shop.why.bag_full"))
		return true
	ask = "buy"
	ask_item = item
	ask_member = member
	var price := ShopRow.grouped(int(line["price"]))
	var text := texts.t("shop.confirm.buy", {"price": price}) if can_wear(item, member) \
		else texts.t("shop.confirm.buy_unfit", {"price": price, "member": PartyNames.member_name(state, texts, member)})
	dialog.open_confirm(text, true, icon_of(item), PartyNames.item_name(state, texts, item))
	return true


## 확인 창·장착 물음의 답(창이 이미 닫혔다, 화면 입구를 지난 입력 안에서 불린다).
func _on_answered(yes: bool, qty: int) -> void:
	var was := ask
	var batch := ask_lines
	ask = ""
	ask_lines = []
	if not yes:
		return  # 「아니오」·취소: 상태 그대로(산 물건은 가방에 남는다)
	match was:
		"buy":
			if not _apply_shop(ShopRules.buy(state, SHOP_ID, ask_item, 1)):
				return
			# 산 뒤 실제 가방으로 다시 판정한다(§8.6 4): 낄 칸이 있으면 장착 물음.
			if best_slot(ask_item, ask_member, state.gear_bag) >= 0:
				ask = "equip"
				dialog.open_confirm(texts.t("shop.confirm.equip"), true, icon_of(ask_item), PartyNames.item_name(state, texts, ask_item))
		"equip":
			var e := state.defs.battle.equip(ask_item)
			if e != null and e.weapon():
				_apply_equip(GrowthRules.equip(state, ask_member, 0, ask_item))
				return
			ask = "slots"
			dialog.open_slots(slot_rows(ask_item, ask_member), best_slot(ask_item, ask_member, state.gear_bag))
		"sell":
			_do_sell([{"item": ask_item, "qty": qty}])
		"sell_multi":
			_do_sell(batch)  # 연 때의 줄 그대로(가진 수가 줄었으면 규칙이 거부한다)


func _on_slot_picked(slot: int) -> void:
	ask = ""
	if slot < 0:
		return  # 끼지 않기(물건은 가방에 남는다)
	_apply_equip(GrowthRules.equip(state, ask_member, slot, ask_item))


## 상점 규칙 결과. 거부면 이유를 알림 줄에(상태 그대로) false. 받아들였으면 저장 갈고리 → changed, true.
func _apply_shop(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(why_text(str(events[0]["reason"])))
		return false
	_saved(events)
	return true


func _apply_equip(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(texts.t("growth.reason." + str(events[0]["reason"])))
		return false
	_saved(events)
	var ev := events[0]
	show_notice(texts.t("growth.event.equipped", {"member": PartyNames.member_name(state, texts, int(ev["member"])),
		"item": PartyNames.item_name(state, texts, str(ev["item"]))}))
	return true


## 받아들인 변경 뒤: 자동 저장(실패해도 되돌리거나 다시 부르지 않는다, F6) → changed.
func _saved(events: Array[Dictionary]) -> void:
	if save_hook.is_valid():
		save_hook.call()
	changed.emit(events)


## 거부 이유 글(§8.10): 표에 있는 이유는 그 글, 품절은 모자란 소재, 그 밖은 shop.why.not_now.
func why_text(reason: String) -> String:
	if reason == "sold_out":
		return sold_out_text(ask_item)
	return texts.t("shop.why." + (reason if WHY_KEYS.has(reason) else "not_now"))


## 「품절이다. 더 팔아야 할 소재: 네온 쥐 꼬리 3개, …」(ShopRules.shortage, unlock 차례).
func sold_out_text(item: String) -> String:
	var parts: Array[String] = []
	var lack := ShopRules.shortage(state.defs, state, SHOP_ID, item)
	for m in lack:
		parts.append("%s %s" % [texts.t(str(m)), texts.t("party.count", {"n": int(lack[m])})])
	return texts.t("shop.why.sold_out", {"items": ", ".join(parts)})


## 칸 고르기 줄(칸 1~3): 「방어구 1  패딩 코트」, 막는 이유(GrowthRules.equip_block, 실제 가방).
func slot_rows(item: String, i: int) -> Array:
	var m := state.party.members[i]
	var out := []
	for slot in range(1, BattleLimits.EQUIP_SLOTS):
		var id: String = m.equip[slot]
		var now := texts.t("party.slot.empty") if id.is_empty() else PartyNames.item_name(state, texts, id)
		var why := GrowthRules.equip_block(state.defs, i, m, state.gear_bag, slot, item)
		out.append({"text": "%s  %s" % [PartyNames.slot_name(texts, slot), now], "why": "" if why.is_empty() else texts.t("growth.reason." + why)})
	return out


# ---- 견주는 칸·비교(§8.5, F5) ----

## 대원 i 가 item 을 낄 칸(bag 으로 판정, 실제 상태는 바꾸지 않는다). 후보 차례: 무기 = 칸 0. 방어구·장신구 = 같은 종류 제한에
## 닿았으면 그 종류가 든 칸, 아니면 빈 칸(번호순), 이어서 남은 칸 1~3. 그 가운데 GrowthRules.equip_block 이 빈 첫 칸, 없으면 -1.
func best_slot(item: String, i: int, bag: Dictionary) -> int:
	var defs := state.defs
	var e := defs.battle.equip(item)
	if e == null or i < 0 or i >= state.party.members.size():
		return -1
	var m := state.party.members[i]
	var order: Array[int] = []
	if e.weapon():
		order.append(0)
	else:
		var same: Array[int] = []
		var empty: Array[int] = []
		for slot in range(1, BattleLimits.EQUIP_SLOTS):
			var id: String = m.equip[slot]
			if id.is_empty():
				empty.append(slot)
				continue
			var o := defs.battle.equip(id)
			if o != null and o.kind == e.kind:
				same.append(slot)
		order.assign(same if same.size() >= int(BattleLimits.KIND_LIMIT.get(e.kind, 1)) else empty)
		for slot in range(1, BattleLimits.EQUIP_SLOTS):
			if not order.has(slot):
				order.append(slot)
	for slot in order:
		if GrowthRules.equip_block(defs, i, m, bag, slot, item).is_empty():
			return slot
	return -1


## 사기 전 비교용 가방: 실제 가방 사본에 그 물건 하나를 더한 것(사지 않은 물건이 not_in_bag 으로 막히지 않게, F5).
func preview_bag(item: String) -> Dictionary:
	var bag := state.gear_bag.duplicate()
	bag[item] = int(bag.get(item, 0)) + 1
	return bag


## 대원 i 의 직업이 item 을 낄 수 있는지(직업·전용 직업만, 칸·가방과 상관없이). 못 끼면 확인 글이 buy_unfit 이다.
func can_wear(item: String, i: int) -> bool:
	var e := state.defs.battle.equip(item)
	return e != null and e.fits(state.defs.class_of(i))


## 대원 i 의 slot 을 item 으로 바꾼 사본의 GrowthRules.profile(대원·가방은 그대로).
func profile_if(i: int, slot: int, item: String) -> Dictionary:
	var m := state.party.members[i]
	var copy := PartyState.Member.new(m.id, m.max_hp, m.hp, m.max_tp, m.tp)
	copy.level = m.level
	copy.exp = m.exp
	copy.skills = m.skills.duplicate()
	copy.equip = m.equip.duplicate()
	copy.equip[slot] = item
	return GrowthRules.profile(state.defs, i, copy)


## 바뀌는 값 「공격 +8 · 민첩 -2」(같으면 party.no_change).
func change_text(base: Dictionary, after: Dictionary) -> String:
	var parts: Array[String] = []
	for g in BattleLimits.GEAR:
		var d: int = int(after["gear"][g]) - int(base["gear"][g])
		if d != 0:
			parts.append(texts.t("party.delta", {"name": texts.t("stat." + g), "value": PartyNames.signed(d)}))
	for k in BattleLimits.STATS:
		var d: int = int(after["stats"][k]) - int(base["stats"][k])
		if d != 0:
			parts.append(texts.t("party.delta", {"name": texts.t("stat." + k), "value": PartyNames.signed(d)}))
	return " · ".join(parts) if not parts.is_empty() else texts.t("party.no_change")


## 장비 값 줄 「공격 +8 · 베기」(설명 창 본문, 캠프 장비 목록의 바뀌는 값과 같은 꼴).
func values_text(item: String) -> String:
	return PartyNames.values_text(state, texts, item)


# ---- 줄 자료 ----

## 지금 갈래·탭의 진열 줄(ShopRules.catalog 를 종류로 거른다). 「전체」는 탭 차례로 묶고 묶음 안은 진열 차례.
func buy_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var key: String = BRANCH_KEYS[branch]
	var kinds: Array = []
	if BRANCH_TABS.has(key):
		var set: Array = ShopTabs.SETS[key]
		var k: String = set[clampi(tab, 0, set.size() - 1)]
		kinds = set.slice(1) if k == "all" else [k]
	else:
		kinds = BRANCH_KINDS[key]
	var cat := ShopRules.catalog(state.defs, state, SHOP_ID)
	for k in kinds:
		for line in cat:
			var e := state.defs.battle.equip(line["item"])
			if e != null and e.kind == k:
				var l := line.duplicate()
				l["kind"] = k
				out.append(l)
	return out


func rows_of(ls: Array[Dictionary]) -> Array:
	var out := []
	for line in ls:
		var item: String = line["item"]
		var so := sold_out(line)
		out.append({"icon": icon_of(item), "name": PartyNames.item_name(state, texts, item), "new": bool(line["new"]),
			"right": texts.t("shop.sold_out") if so else ShopRow.grouped(int(line["price"])), "count": "",
			"dim": so or not bool(line["affordable"]), "checked": false})
	return out


## 판매 줄(§8.8): 가방 줄(BagRows, 캠프 소지품과 같은 곳·같은 차례)에 판매값을 붙인다. 소재 탭 = 가진 소재(정의 자료 차례),
## 장비 탭 = 가방 장비(자료 차례), 소모품 탭 = 빈 목록.
func sell_lines() -> Array[Dictionary]:
	var k := str(SELL_KINDS[clampi(tab, 0, SELL_KINDS.size() - 1)])
	if k == "consumable":
		return [] as Array[Dictionary]
	var out := BagRows.bag(state, [k])
	for line in out:
		line["price"] = ShopRules.sell_price(state.defs, str(line["item"]))
	return out


func sell_rows_of(ls: Array[Dictionary]) -> Array:
	var out := []
	for line in ls:
		var item: String = line["item"]
		out.append({"icon": line["icon"], "name": sell_name(item), "new": false, "right": ShopRow.grouped(int(line["price"])),
			"count": texts.t("party.count", {"n": int(line["count"])}), "dim": false, "checked": marked.has(item)})
	return out


## 판매 줄 이름(소재·장비).
func sell_name(item: String) -> String:
	if state.defs.battle.materials.has(item):
		return texts.t(str(state.defs.battle.materials[item]))
	return PartyNames.item_name(state, texts, item)


static func sold_out(line: Dictionary) -> bool:
	return bool(line["limited"]) and int(line["stock"]) < 1


func icon_of(item: String) -> String:
	var e := state.defs.battle.equip(item)
	return str(ShopTabs.ICONS.get(e.kind, "")) if e != null else ""


func money_text() -> String:
	return texts.t("shop.money", {"money": ShopRow.grouped(state.money if state != null else 0)})


# ---- 키 ----

## 키보드(§8.9 F2, 캠프와 같다): 반복이 아닌 첫 키 누름에서 한 번. 뗌·반복·Ctrl·Alt·Meta 는 아무 일도 하지 않는다.
## 열린 동안 누른 키는 모두 삼킨다(P 포함). 층 3 창이 떠 있으면 그 창과 탐색 화면이 받는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey:
		return
	if blocked_hook.is_valid() and blocked_hook.call():
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var a := key_action(k.physical_keycode)
	if not a.is_empty():
		handle(a[0], a[1])


## 키 표 하나(§8.9): 물리 키 → 지금 쪽·창에서 그 키가 보내는 [입력 종류, 값], 하는 일이 없으면 []. 부작용 없음.
## 키보드와 가상 키패드(_on_vpad·pad_state)가 같이 쓴다. 선택 = Enter·키패드 Enter·Space, 취소 = Esc·Backspace.
func key_action(code: int) -> Array:
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	var back := code == KEY_ESCAPE or code == KEY_BACKSPACE
	var dir := _arrow(code)
	if dialog.is_open():
		var d := ""
		var v: Variant = null
		match dialog.mode:
			"confirm":
				if dir.x != 0:
					d = "pick"
					v = dir.x
			"qty":
				if dir.x != 0:
					d = "pick"
					v = dir.x
				elif dir.y != 0:
					d = "step"
					v = -dir.y
				elif code == KEY_PAGEUP:
					d = "step"
					v = 10
				elif code == KEY_PAGEDOWN:
					d = "step"
					v = -10
			"slots":
				if dir.y != 0:
					d = "slot_move"
					v = dir.y
		if back:
			d = "cancel"
		elif enter:
			d = "confirm"
		return [] if d.is_empty() else ["dialog", [d, v]]
	if back:
		return ["back", null]
	var num := _number(code)
	match page:
		"root":
			if num >= 0 and num < ROOT_KEYS.size():
				return ["root", num]
			if enter:
				return ["confirm", null]
			return ["root_cursor", dir.y] if dir.y != 0 else []
		"branch":
			if num >= 0 and num < BRANCH_KEYS.size():
				return ["branch", num]
			if enter:
				return ["confirm", null]
			if dir.y != 0:
				return ["branch_cursor", dir.y]
		"buy", "sell":
			if enter:
				return ["confirm", null]
			if dir.y != 0:
				return ["cursor", dir.y]
			if page == "sell" and code == KEY_M:
				return ["multi", null]
			if has_tabs():
				match code:
					KEY_Z, KEY_PAGEUP:
						return ["tab_step", -1]
					KEY_X, KEY_PAGEDOWN:
						return ["tab_step", 1]
		_:
			return []
	if dir.x != 0:
		return ["member_step", dir.x]
	match code:
		KEY_Q:
			return ["member_step", -1]
		KEY_E:
			return ["member_step", 1]
	return []


static func _arrow(code: int) -> Vector2i:
	match code:
		KEY_UP:
			return Vector2i(0, -1)
		KEY_DOWN:
			return Vector2i(0, 1)
		KEY_LEFT:
			return Vector2i(-1, 0)
		KEY_RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO


## 숫자 키(윗줄·키패드) 1~9 → 0~8, 아니면 -1.
static func _number(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_1
	return -1


## 가상 키패드 누르기 → 그 단추와 같은 키의 입력(방향은 누르는 순간, 선택·취소는 단추 안에서 뗄 때: VirtualPad).
func _on_vpad(kind: String, arg: Variant) -> void:
	var code := KEY_NONE
	match kind:
		"ok":
			code = KEY_ENTER
		"back":
			code = KEY_ESCAPE
		"move":
			var d := arg as Vector2i
			for k in ["up", "down", "left", "right"]:
				if VirtualPad.DIRS[k] == d:
					code = PAD_KEYS[k]
	var a := key_action(code)
	if not a.is_empty():
		handle(a[0], a[1])


## 키패드 단추마다 켤지(이름 → 참). 그 키가 지금 아무 일도 하지 않으면 흐림: 키 표에 없거나(뿌리 ←→, 확인 창 ↑↓, 칸 고르기 ←→),
## 늘 거부되는 것(빈 구매 목록의 ↑↓·선택, 대원이 하나뿐인 대원 넘기기).
func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		var a := key_action(PAD_KEYS[k])
		out[k] = not a.is_empty() and _may_accept(a)
	return out


func _may_accept(a: Array) -> bool:
	if dialog.is_open():
		return true
	match str(a[0]):
		"confirm", "cursor":
			return not (page == "buy" or page == "sell") or not lines.is_empty()
		"member_step":
			return state != null and state.party.members.size() > 1
	return true


func _place_pads() -> void:
	var stacked := page != "root"
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var k := PAD_KEYS_SIDE if stacked else PAD_KEYS_ROOT
	var ks := VirtualPad.keys_size(stacked)
	PartyMenu.place(active_key_pad(), Vector2(1, 1), Vector2(1, 1), Vector4(k.x, k.y, k.x + ks.x, k.y + ks.y))
	key_pad.visible = not stacked
	key_pad_stacked.visible = stacked


## 지금 보이는 「취소」「선택」 묶음(뿌리 = 가로, 그 밖 = 세로).
func active_key_pad() -> VirtualPad:
	return key_pad if page == "root" else key_pad_stacked


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
			if _open:
				_refresh()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			cancel_pointers()


# ---- 알림 ----

## sec = 보일 시간(DungeonScreen 의 저장 실패 안내는 남은 시간을 넘긴다).
func show_notice(t: String, sec: float = NOTICE_SEC) -> void:
	notice = t
	_notice_left = sec
	_refresh_banner()


## 다른 화면이 넘겨준 안내를 거둔다(DungeonScreen: 저장 실패 안내가 다른 곳으로 옮겨 갈 때).
func clear_notice() -> void:
	_clear_notice()


func _clear_notice() -> void:
	notice = ""
	_notice_left = 0.0
	_refresh_banner()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()


# ---- 그리기 ----

func _refresh() -> void:
	if not _built or not _open or state == null:
		return
	# 문맥(쪽·갈래·탭·대원·창 모양·창의 목적과 대상)이 바뀌면 앞 문맥에서 시작한 누르기를 버린다.
	var target := "%s|%s|%d" % [ask, ask_item, ask_member] if not ask.is_empty() else ""
	# 고름도 문맥이다(검토 R2): 고르거나 끄면 바깥에서 누르고 있던 「여러 개」·키패드·「뒤로」가 새 고름에 일하지 않는다.
	var picks: Array = marked.keys()
	picks.sort()
	var ctx := "%s|%d|%d|%d|%s|%s|%s|%s" % [page, branch, tab, member, str(multi), ",".join(picks), dialog.mode, target]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	var rootish := page == "root" or page == "branch"
	var on_branch := page == "branch"
	var on_list := page == "buy" or page == "sell"
	for c in [plate, banner, money_plate, root_list]:
		(c as Control).visible = rootish
	for c in [branch_list, branch_panel]:
		(c as Control).visible = on_branch
	cards.visible = page == "root" or (on_branch and cards_fit())
	for c in [frame, buy_list]:
		(c as Control).visible = on_list
	buy_tabs.visible = on_list and has_tabs()
	multi_button.visible = page == "sell"
	_layout()
	if rootish:
		_refresh_root()
	if page == "buy":
		_refresh_buy()
	elif page == "sell":
		_refresh_sell()
	_refresh_banner()
	var mode := "cursor"
	if dialog.is_open():
		mode = "none" if ask == "sell_multi" or ask == "notice" else "chosen"
	buy_list.set_cursor_mode(mode)
	_refresh_pad()
	queue_redraw()


func _refresh_root() -> void:
	plate.show_lines(texts.t(state.defs.battle.shop(SHOP_ID).name_key), "")
	money_plate.queue_redraw()
	var on_branch := page == "branch"
	var live := []
	var dim := []
	for i in ROOT_KEYS.size():
		# 갈래에서는 숫자 키가 하위 목록 것이라 명령 줄에 번호를 쓰지 않는다.
		var label := texts.t("shop.cmd." + ROOT_KEYS[i])
		root_list.set_row_text(i, label if on_branch else "%d  %s" % [i + 1, label])
		live.append(true)
		dim.append(ROOT_DIM.has(ROOT_KEYS[i]))
	root_list.show_rows(-1 if on_branch else root_cursor, 0 if on_branch else -1, live, dim)
	if on_branch:
		var blive := []
		for i in BRANCH_KEYS.size():
			branch_list.set_row_text(i, "%d  %s" % [i + 1, texts.t("shop.branch." + BRANCH_KEYS[i])])
			blive.append(true)
		branch_list.show_rows(branch_cursor, -1, blive)
		branch_panel.show_member(state, texts, member, null, -1)
	for c in cards.cards:
		c.queue_redraw()


func _refresh_buy() -> void:
	frame.show_title(money_text(), true)
	if has_tabs():
		buy_tabs.select(tab)
	lines = buy_lines()
	buy_list.set_rows(rows_of(lines))
	var at := buy_list.cursor
	if at < 0 or at >= lines.size():  # 빈 목록(커서 -1)
		frame.panel.show_member(state, texts, member, null, -1)
		frame.show_desc("", [] as Array[String])
		return
	var item: String = lines[at]["item"]
	# 본문 = 값 줄. 바뀌는 값은 판이 보이므로 되풀이하지 않고, 둘째 줄은 이유가 있을 때만(§8.5).
	var desc: Array[String] = [values_text(item)]
	if not can_wear(item, member):
		frame.panel.show_member(state, texts, member, null, -1, true)
		desc.append(texts.t("growth.reason.class"))
	else:
		var b := best_slot(item, member, preview_bag(item))
		if b < 0:
			frame.panel.show_member(state, texts, member, null, -1)
			desc.append(texts.t("shop.why.no_slot"))
		else:
			frame.panel.show_member(state, texts, member, profile_if(member, b, item), b)
	frame.show_desc(PartyNames.item_name(state, texts, item), desc, badges(item))


## 판매 목록(§8.8): 소지금 문패·탭·줄·설명 창(장비는 값 줄과 머리글자 칸)·판(비교 없음)·「여러 개」 단추.
func _refresh_sell() -> void:
	frame.show_title(money_text(), true)
	buy_tabs.select(tab)
	multi_button.text = texts.t("shop.multi.sell" if multi else "shop.multi")
	multi_button.checked = multi
	multi_button.queue_redraw()
	lines = sell_lines()
	buy_list.set_rows(sell_rows_of(lines))
	frame.panel.show_member(state, texts, member, null, -1)
	var at := buy_list.cursor
	if at < 0 or at >= lines.size():  # 빈 목록(커서 -1)
		frame.show_desc("", [] as Array[String])
		return
	var line := lines[at]
	var item: String = line["item"]
	if line["kind"] == "material":
		frame.show_desc(sell_name(item), [texts.t("shop.tab.material")] as Array[String])
	else:
		frame.show_desc(sell_name(item), [values_text(item)] as Array[String], badges(item))


## 설명 창 머리글자 칸 [[「홀」, 낄 수 있는지], …](§8.5).
func badges(item: String) -> Array:
	var e := state.defs.battle.equip(item)
	var out := []
	for k in BADGE_CLASSES:
		var c: BattleDb.ClassDef = state.defs.battle.classes.get("class." + k)
		out.append([texts.t("shop.badge." + k), e != null and c != null and e.fits(c)])
	return out


## 설명 띠: 뿌리 = 커서 명령 설명, 갈래 = 물음 + 커서 갈래 설명, 목록 = 갈래 설명. 안내(이유)가 있으면 둘째 줄.
func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	match page:
		"root":
			banner.show_lines(texts.t("shop.desc." + ROOT_KEYS[root_cursor]), notice, not notice.is_empty())
		"branch":
			var sub := notice if not notice.is_empty() else texts.t("shop.desc." + BRANCH_KEYS[branch_cursor])
			banner.show_lines(texts.t("shop.desc.branch"), sub, not notice.is_empty())
		"buy":
			var body := notice
			if body.is_empty() and lines.is_empty():
				body = texts.t("shop.why.empty_buy")
			frame.banner.show_lines(texts.t("shop.desc." + BRANCH_KEYS[branch]), body, not notice.is_empty())
		"sell":
			var body := notice
			if body.is_empty() and lines.is_empty():
				body = texts.t("shop.why.empty_sell")
			frame.banner.show_lines(texts.t("shop.desc.multi" if multi else "shop.desc.sell"), body, not notice.is_empty())


func _refresh_pad() -> void:
	_place_pads()
	var on := pad_state()
	for p in [dir_pad, key_pad, key_pad_stacked]:
		(p as VirtualPad).set_enabled(on)


## 구매 갈래에서 파티 카드 두 줄이 PAD_SIDE ~ 판 왼쪽 − 24 사이에 들어가는지(F7). 들어가지 않으면 카드 묶음을 숨긴다.
func cards_fit() -> bool:
	return cards_room() >= cards_need()


func cards_room() -> float:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return s.x - CharPanel.W - CARDS_GAP - ShopFrame.PAD_SIDE


## 카드 두 줄 가운데 긴 줄의 폭.
func cards_need() -> float:
	var need := 0.0
	for top in [true, false]:
		var n := 0
		for i in cards.cards.size():
			if cards.top_row(i) == top:
				n += 1
		need = maxf(need, n * PartyCards.CARD.x + maxf(0.0, n - 1.0) * PartyCards.GAP)
	return need


func _layout() -> void:
	if not _built:
		return
	var s := size if size.x > 0.0 else get_viewport_rect().size
	PartyMenu.place(root_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, ROOT_TOP, FacilityList.WIDTH, ROOT_TOP + FacilityList.content_height(ROOT_KEYS.size(), ROOT_GAP, ROOT_PAD)))
	var bt := ROOT_TOP + ROOT_PAD
	PartyMenu.place(branch_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(BRANCH_X, bt, BRANCH_X + BRANCH_W, bt + FacilityList.content_height(BRANCH_KEYS.size(), ROOT_GAP, ROOT_PAD)))
	banner.place()
	if page == "branch":
		banner.offset_right = -CharPanel.W - 8.0  # 판 왼쪽까지(ShopFrame 띠와 같다)
		PartyMenu.place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(ShopFrame.PAD_SIDE, -PartyCards.HEIGHT, -CharPanel.W - CARDS_GAP, 0))
	else:
		PartyMenu.place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	var top := ShopFrame.TABS_LIST_TOP if has_tabs() else ShopFrame.LIST_TOP
	if frame.list_top != top:
		frame.set_list_top(top)
	var la: Array = frame.list_anchor()
	PartyMenu.place(buy_list, la[0], la[1], la[2])
	buy_tabs.position = Vector2(frame.left, ShopTabs.TOP)
	dialog.set_area(Rect2(frame.left, top, s.x - CharPanel.W - ShopFrame.GAP - frame.left, ShopFrame.LIST_BOTTOM - top))
	_place_pads()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.CAMP_DIM)


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 단추·줄 전부(창이 떠 있으면 그 창 단추만)와 켜진 키패드 단추. 끌어 내리는 영역 밖으로 다 나간 줄은 뺀다.
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open:
		return out
	var root_node: Node = dialog if dialog.is_open() else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.get_parent() is VirtualPad:
			continue
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		if root_node == self and dialog.is_ancestor_of(b):
			continue
		if clipped_rect(b).size.y <= 0.0:
			continue
		out.append(b)
	for p in [dir_pad, key_pad, key_pad_stacked]:
		var vp := p as VirtualPad
		if not vp.is_visible_in_tree():
			continue
		for k in vp.buttons:
			var b: TouchButton = vp.buttons[k]
			if not b.disabled:
				out.append(b)
	return out


## 단추의 화면 사각형(이 화면 기준). 끌어 내리는 영역 안이면 그 영역으로 자른 부분.
func clipped_rect(b: Control) -> Rect2:
	var r := Rect2(b.get_global_position() - get_global_position(), b.size)
	var p := b.get_parent()
	while p != null and p != self:
		if p is PartyScroll:
			r = r.intersection(Rect2((p as Control).get_global_position() - get_global_position(), (p as Control).size))
		p = p.get_parent()
	return r


## 지금 노랑으로 채운 것(selected 인 보이는 단추·줄, 07 §9.2 한 화면 하나).
func yellow_fills() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	for n in find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.selected and b.is_visible_in_tree():
			out.append(b)
	return out


## 디버그 요청 snapshot 의 상점 정보(§8.11). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		var r := clipped_rect(b)
		buttons[b.name] = css.call(r.get_center() - (b.get_global_position() - get_global_position()), b)
	var rows := []
	if page == "buy" or page == "sell":
		for d in (rows_of(lines) if page == "buy" else sell_rows_of(lines)):
			rows.append({"name": d["name"], "right": d["right"], "dim": d["dim"], "checked": d["checked"], "new": d["new"], "count": d["count"]})
	return {
		"open": true, "page": page, "branch": BRANCH_KEYS[branch] if page == "buy" else "",
		"tab": buy_tabs.kinds[tab] if has_tabs() and tab < buy_tabs.kinds.size() else "", "member": member,
		"cursor": {"root": root_cursor, "branch": branch_cursor, "row": buy_list.cursor if page == "buy" or page == "sell" else -1},
		"rows": rows, "multi": multi, "marked": marked.keys(),
		"dialog": {"mode": dialog.mode, "ask": ask, "item": ask_item if not ask.is_empty() else "", "pick": dialog.pick, "qty": dialog.qty,
			"slot": dialog.slot_cursor if dialog.mode == "slots" else -1},
		"money": state.money, "notice": notice, "cards": cards.visible, "pad": pad_state(), "buttons": buttons,
	}


## 바깥(디버그 요청)이 상태를 바꿨을 때 다시 그린다.
func refresh_view() -> void:
	_refresh()
