## 캠프(M2.7 R2, 07 §9, research 05 §2.2): 미궁 화면 위에 덮는 전체 화면 층. 열린 동안 탐색 화면은 HUD 를 감추고
## 3D 시야만 화면 전체로 두며(DungeonScreen._hud_hidden), 캠프는 그것을 어둡게(CAMP_DIM) 하고 그 위에 원작 시설 화면의 짜임
## (gs2_653222·653235·jp_facility_img1, 원작 캠프 화면은 찾지 못해 시설 짜임으로 추정 — 사용자 결정)을 띄운다:
## 왼쪽 위 문패(층 이름·걸음, 원작 다이얼 자리), 위 설명 띠(FacilityBanner), 왼쪽 명령 목록(FacilityList), 아래 파티 카드 두 줄(PartyCards).
## 쪽(page): root(캠프 뿌리: 명령 목록) → pick(상태·스킬·장비: 파티 카드에서 대원 고르기, 추정) → sub(그 대원의 하위 화면).
## 소지품·기록은 파티 전체 것이라 고르기 없이 바로, 닫기는 탐색으로. Esc·P 는 한 단계 뒤로(하위 화면 → 뿌리 → 닫힘).
## 하위 화면은 원작 화면을 옮긴 것: 상태(PartyStatusTab, 상태 화면), 스킬(PartySkillTab, 스킬 트리), 장비·소지품(PartyEquipTab·
## PartyItemsTab, 상점 화면 짜임 ShopFrame), 기록(PartyRecordsTab, 불러오기 화면의 슬롯 카드). 기록의 일(저장·불러오기·내보내기·
## 가져오기·자동 지도·새 게임)은 탐색 화면이 records 갈고리로 준다.
## 값은 규칙의 읽기 함수(GrowthRules.profile·learn_block·equip_block·sp_left 등)에서 읽고 화면이 다시 계산하지 않는다(07 §11.4).
## 상태는 규칙 함수(allocate·equip·supply·grant_exp)로만 바꾸고, 받아들여지면 save_hook(자동 저장, 07 §8.5) 뒤 changed 를 낸다.
## 스킬 배분 초안은 화면 것이라 저장하지 않는다. 메뉴를 닫으면 없어지고, 열 때는 늘 상태 탭·칸 0 대원에서 시작한다(07 §9.1).
##
## 입력 입구 하나(07 §9.4, 06 §9.5): 단추·노드·목록 줄·키보드가 모두 handle() 로 온다. 확인 창이 떠 있으면 그 창 입력만,
## 한 프레임에 입력 하나만 받는다. 문맥(탭·대원·확인 창·장비 목록)이 바뀌면 눌려 있던 포인터를 모두 버린다
## (취소된 누르기는 뗄 때 아무 일도 하지 않는다). 열린 동안 키 누름은 모두 여기서 끝난다(뒤 미궁 화면으로 가지 않는다). 뗌은 그대로 둔다.
class_name PartyMenu
extends Control

signal opened
signal closed
## 캠프 명령(목록 순서). 숫자 키 1~6.
const CAMP_KEYS := ["status", "skills", "equip", "items", "records", "close"]
## 명령 목록 위(설명 띠 아래 16). 원작은 소지금 문패 아래(y 약 195)지만 소지금이 없어(M3) 위로 올렸다.
const CAMP_TOP := 116.0
## 규칙 함수가 상태를 바꿨다(저장 갈고리 뒤). 탐색 화면이 상태 칸을 새로 그린다.
signal changed(events: Array)

## 안내 글자(스킬 정보 띠 위, 07 §9.2).
const NOTICE_TEXT := Color(1.0, 0.85, 0.55)
const DIALOG_SIZE := Vector2(560, 240)
const DIALOG_BUTTON := Vector2(200, 64)
const NOTICE_SEC := 2.5
const TAB_KEYS := ["status", "skills", "equip", "items", "records"]
## 장비 칸 이름 키(칸 0 무기, 칸 1~3 방어구).
const SLOT_KEYS := ["party.slot.weapon", "party.slot.armor", "party.slot.armor", "party.slot.armor"]

# ---- 바깥에서 정하는 값 ----
## 「기록」의 일(탐색 화면이 준다): slots() -> Array, save(slot), load(slot), export(), import(), automap() -> String,
## set_automap(mode), new_game(). 캠프는 탐색 화면을 직접 부르지 않는다.
var records := {}
## 캠프 위에 다른 창(모달)이 떠 있으면 true: 그동안 키를 받지 않는다(그 창과 탐색 화면이 받는다).
var blocked_hook: Callable
## 디버그(디버그 주소 또는 네이티브 디버그 실행): 소지품 탭에 「임시 보급(시험용)」을 보인다(07 §5.7). 열 때마다 탐색 화면이 정한다.
var debug := false
## 규칙 함수가 상태를 바꾼 직후 부른다(자동 저장).
var save_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## root · pick · sub
var page := "root"
## 캠프 명령 목록 커서, 대원 고르기의 명령(0 상태·1 스킬·2 장비)과 커서(대원 칸).
var camp_cursor := 0
var pick_cmd := 0
var pick_cursor := 0
## 0 상태 · 1 스킬 · 2 장비 · 3 소지품 · 4 기록
var tab := 0
var member := 0
## 확인 창: "" · discard · commit · new_game
var dialog_kind := ""
## 확인 창에서 고른 단추: 0 「돌아가기」 · 1 「버리기」·「확정」·「새 게임」
var dialog_pick := 0
var notice := ""
## 받아들인 입력 수(시험용).
var accepted_inputs := 0

# ---- 부품 ----
## 캠프 뿌리·대원 고르기(시설 짜임): 문패·설명 띠·명령 목록·파티 카드(전투와 같은 부품, 값은 탐색 상태의 파티).
var camp_plate: FacilityPlate
var banner: FacilityBanner
var camp_list: FacilityList
var cards: PartyCards
var display: BattleDisplay
var status_tab: PartyStatusTab
var skill_tab: PartySkillTab
var equip_tab: PartyEquipTab
var items_tab: PartyItemsTab
var records_tab: PartyRecordsTab
var tabs: Array[Control] = []
var dialog_layer: Control
var dialog_buttons: Array[PartyButton] = []
var _dialog_text := Label.new()
var _notice_left := 0.0
## 확인 창의 둘째 단추 뒤에 할 일(버리기 뒤 탭·대원 바꾸기·닫기, 새 게임).
var _after_discard: Callable
var _built := false
var _open := false
var _input_frame := -1
var _context := ""


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 뒤의 지도·이동 단추에 포인터가 닿지 않게
	focus_mode = FOCUS_NONE
	visible = false


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	_build_camp()
	status_tab = PartyStatusTab.new()
	skill_tab = PartySkillTab.new()
	equip_tab = PartyEquipTab.new()
	items_tab = PartyItemsTab.new()
	records_tab = PartyRecordsTab.new()
	tabs = [status_tab, skill_tab, equip_tab, items_tab, records_tab]
	for i in tabs.size():
		var t: Control = tabs[i]
		t.name = "Tab" + TAB_KEYS[i].capitalize()
		add_child(t)
		t.call("setup", self)
	_build_dialog()
	_layout()


## 캠프 뿌리 부품(앵커로 붙인다). 트리 순서 = 그리는·누르는 순서: 카드 → 문패·띠(장식) → 명령 목록.
func _build_camp() -> void:
	cards = PartyCards.new()
	cards.name = "CampCards"
	add_child(cards)
	place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	camp_plate = FacilityPlate.new()
	camp_plate.name = "CampPlate"
	add_child(camp_plate)
	banner = FacilityBanner.new()
	banner.name = "CampBanner"
	add_child(banner)
	banner.place()
	camp_list = FacilityList.new()
	camp_list.name = "CampList"
	add_child(camp_list)
	place(camp_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, CAMP_TOP, FacilityList.WIDTH, CAMP_TOP + FacilityList.content_height(CAMP_KEYS.size())))
	var items := []
	for i in CAMP_KEYS.size():
		items.append({"name": "Camp_" + CAMP_KEYS[i], "text": camp_label(i)})
	camp_list.set_items(items)
	camp_list.pressed.connect(func(i: int) -> void: handle("camp", i))


## 명령 줄 글: 「1  상태」(숫자 키), 대원 고르기 중 마지막 줄은 「뒤로」.
func camp_label(i: int) -> String:
	if page == "pick" and i == CAMP_KEYS.size() - 1:
		return texts.t("camp.back")
	return "%d  %s" % [i + 1, texts.t("camp.cmd." + CAMP_KEYS[i])]


## 앵커(왼쪽 위·오른쪽 아래 비율)와 여백(left, top, right, bottom).
static func place(c: Control, a0: Vector2, a1: Vector2, off: Vector4) -> void:
	c.anchor_left = a0.x
	c.anchor_top = a0.y
	c.anchor_right = a1.x
	c.anchor_bottom = a1.y
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.z
	c.offset_bottom = off.w


func _build_dialog() -> void:
	dialog_layer = Control.new()
	dialog_layer.name = "Dialog"
	dialog_layer.mouse_filter = MOUSE_FILTER_STOP  # 떠 있는 동안 뒤 화면은 포인터를 받지 않는다
	dialog_layer.visible = false
	dialog_layer.draw.connect(_draw_dialog)
	add_child(dialog_layer)
	_dialog_text.add_theme_font_size_override("font_size", 22)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_layer.add_child(_dialog_text)
	for i in 2:
		var b := PartyButton.new()
		b.name = "DialogBack" if i == 0 else "DialogOk"
		b.skin = "cmd"  # 원작 습득 확인 창(jp_guide2_img2): 커서 쪽 노랑 알약, 다른 쪽 청록
		b.size = DIALOG_BUTTON
		b.activated.connect(func() -> void: handle("dialog_pick", i))
		dialog_layer.add_child(b)
		dialog_buttons.append(b)


func reason_text(code: String) -> String:
	return texts.t("growth.reason." + code)


func member_name(i: int) -> String:
	return texts.t(state.defs.party.name_keys[i])


func current_member() -> PartyState.Member:
	return state.party.members[member]


func slot_name(slot: int) -> String:
	return texts.t(SLOT_KEYS[slot], {"n": slot})


## 부호 붙은 수(글꼴 부분 집합에 U+2212 가 없어 ASCII 「-」를 쓴다).
static func signed(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	page = "root"
	camp_cursor = 0
	pick_cmd = 0
	pick_cursor = 0
	tab = 0
	member = 0
	dialog_kind = ""
	dialog_pick = 0
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	_open = true
	visible = true
	_setup_cards()
	cancel_pointers()
	_context = ""
	_layout()
	_refresh()
	opened.emit()


## 메뉴를 닫는다. 초안·열린 목록·확인 창을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_menu(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	dialog_kind = ""
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	cancel_pointers()
	if notify:
		closed.emit()


## 눌려 있던 포인터·끌기를 모두 버린다(취소된 누르기는 뗄 때 아무 일도 하지 않는다). 안의 문맥이 바뀔 때와,
## 바깥 창(층 3: 알림·파일 고르기·메모·전멸)이 열리고 닫힐 때 탐색 화면이 부른다.
func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


## 파티 카드를 지금 상태로 새로 만든다(열 때: 새 게임·불러오기로 파티가 바뀌었을 수 있다).
func _setup_cards() -> void:
	display = BattleDisplay.from_party(state, texts)
	cards.setup(display, state.defs.party.class_ids)
	for c in cards.cards:
		var slot := cards.cards.find(c)
		c.activated.connect(func() -> void: handle("member", slot))
		c.snap()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만. 캠프 위에 바깥 창이 떠 있으면(blocked_hook) 아무것도 받지 않는다.
## 캠프 뿌리: camp(명령 0~5)·camp_cursor(±1)·confirm·back·close. 대원 고르기: member(칸)·pick_move(Vector2i)·confirm·camp(5 = 뒤로)·back·close.
## 하위 화면: tab(0~3)·member(칸)·member_step(±1)·back(한 단계 뒤로)·to_root(캠프 뿌리로)·close(캠프 닫기)·
##       dialog_move(±1)·dialog_pick(0·1)·dialog_ok·dialog_back·
##       스킬 탭 node(트리 칸)·node_dir(Vector2i)·plus·minus·revert·commit·
##       장비 탭 slot(0~3)·row(목록 줄)·cursor(±1)·confirm·unequip·
##       상태·소지품 탭 cursor(±1)·confirm, 상태 split(「내역」), 소지품 supply_toggle·supply(장비 ID)·exp_100(대원)·exp_next(대원)
func handle(kind: String, arg: Variant = null) -> bool:
	if not _open:
		return false
	if blocked_hook.is_valid() and blocked_hook.call():
		return false  # 캠프 위에 바깥 창이 떠 있다: 키·단추·카드·목록 어느 입력도 받지 않는다
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = frame
		accepted_inputs += 1
		_refresh()
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	if not dialog_kind.is_empty():
		match kind:
			"dialog_move":
				dialog_pick = clampi(dialog_pick + int(arg), 0, 1)
				return true
			"dialog_pick":
				return _dialog_choose(int(arg))
			"dialog_ok":
				return _dialog_choose(dialog_pick)
			"dialog_back":
				return _dialog_choose(0)
		return false
	if page == "root":
		return _dispatch_root(kind, arg)
	if page == "pick":
		return _dispatch_pick(kind, arg)
	match kind:
		"tab":
			var t := int(arg) if arg != null else -1
			if t < 0 or t >= tabs.size() or t == tab:
				return false
			_guard(func() -> void: _set_tab(t))
			return true
		"member":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= state.party.members.size() or i == member or tab == 4:
				return false
			_guard(func() -> void: _set_member(i))
			return true
		"member_step":
			if tab == 4:
				return false  # 기록은 대원과 상관없다
			var n := state.party.members.size()
			var to := wrapi(member + (int(arg) if arg != null else 1), 0, n)
			_guard(func() -> void: _set_member(to))
			return true
		"back":
			if tab == 2 and equip_tab.list_open:
				return equip_tab.dispatch("list_close", null)
			_guard(_to_root)
			return true
		"to_root":
			_guard(_to_root)
			return true
		"close":
			_guard(close_menu)
			return true
	return tabs[tab].call("dispatch", kind, arg)


func _dispatch_root(kind: String, arg: Variant) -> bool:
	match kind:
		"camp_cursor":
			camp_cursor = wrapi(camp_cursor + (int(arg) if arg != null else 1), 0, CAMP_KEYS.size())
			return true
		"camp":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= CAMP_KEYS.size():
				return false
			camp_cursor = i
			return _run_camp(i)
		"confirm":
			return _run_camp(camp_cursor)
		"back", "close":
			close_menu()
			return true
	return false


## 캠프 명령: 상태·스킬·장비 → 대원 고르기, 소지품·기록 → 바로, 닫기 → 탐색으로.
func _run_camp(i: int) -> bool:
	match CAMP_KEYS[i]:
		"status", "skills", "equip":
			page = "pick"
			pick_cmd = i
			pick_cursor = member
			_clear_notice()
		"items":
			_open_sub(3)
		"records":
			_open_sub(4)
		"close":
			close_menu()
	return true


func _dispatch_pick(kind: String, arg: Variant) -> bool:
	var n := state.party.members.size()
	match kind:
		"member":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= n:
				return false
			member = i
			_open_sub(pick_cmd)
			return true
		"confirm":
			member = pick_cursor
			_open_sub(pick_cmd)
			return true
		"pick_move":
			var to := pick_target(pick_cursor, arg as Vector2i)
			if to == pick_cursor:
				return false
			pick_cursor = to
			return true
		"camp":
			if int(arg) != CAMP_KEYS.size() - 1:
				return false
			page = "root"
			return true
		"back":
			page = "root"
			return true
		"close":
			close_menu()
			return true
	return false


## 대원 고르기 커서 이동(파티 카드 두 줄): ←·→ 는 보이는 차례(윗줄 왼쪽 → 오른쪽, 아랫줄 왼쪽 → 오른쪽)로 앞·뒤(끝에서 돈다),
## ↑·↓ 는 다른 줄에서 가로 가운데가 가장 가까운 카드(그 쪽에 줄이 없으면 그대로).
func pick_target(from: int, dir: Vector2i) -> int:
	var order: Array[int] = []
	for top in [true, false]:
		var row: Array[int] = []
		for i in cards.cards.size():
			if cards.top_row(i) == top:
				row.append(i)
		row.sort_custom(func(a: int, b: int) -> bool: return cards.cards[a].position.x < cards.cards[b].position.x)
		order.append_array(row)
	if order.is_empty():
		return from
	if dir.x != 0:
		return order[wrapi(order.find(from) + dir.x, 0, order.size())]
	if dir.y == 0:
		return from
	var want_top := dir.y < 0
	if cards.top_row(from) == want_top:
		return from
	var cx := cards.cards[from].position.x + PartyCards.CARD.x / 2.0
	var best := from
	var best_d := INF
	for i in order:
		if cards.top_row(i) != want_top:
			continue
		var d := absf(cards.cards[i].position.x + PartyCards.CARD.x / 2.0 - cx)
		if d < best_d:
			best_d = d
			best = i
	return best


## 하위 화면 t(0 상태·1 스킬·2 장비·3 소지품·4 기록)를 지금 대원으로 연다.
func _open_sub(t: int) -> void:
	page = "sub"
	tab = t
	equip_tab.close_list()
	for tb in tabs:
		tb.call("member_changed")
	_clear_notice()
	_layout()


## 하위 화면에서 캠프 뿌리로(커서는 그 명령 줄).
func _to_root() -> void:
	page = "root"
	camp_cursor = tab
	equip_tab.close_list()
	_layout()


## 초안이 있으면 버리기 확인 창을 띄우고 「버리기」 뒤에 action 을 한다. 없으면 바로 한다.
func _guard(action: Callable) -> void:
	if skill_tab.has_draft():
		open_dialog("discard", action)
	else:
		action.call()


func _set_tab(t: int) -> void:
	tab = t
	equip_tab.close_list()  # 다른 탭에서 돌아오면 칸 줄부터
	_layout()


func _set_member(i: int) -> void:
	member = i
	for t in tabs:
		t.call("member_changed")


func open_dialog(kind: String, after: Callable = Callable()) -> void:
	dialog_kind = kind
	dialog_pick = 0  # 처음은 늘 「돌아가기」(Enter 만 눌러도 안전한 쪽, 07 §4.6)
	_after_discard = after


func _dialog_choose(i: int) -> bool:
	if i < 0 or i > 1:
		return false
	var kind := dialog_kind
	var after := _after_discard
	dialog_kind = ""
	_after_discard = Callable()
	if i == 0:
		return true  # 「돌아가기」: 창만 닫는다(초안 그대로)
	match kind:
		"discard":
			skill_tab.clear_draft()
			if after.is_valid():
				after.call()
		"commit":
			skill_tab.commit_now()
		_:
			if after.is_valid():
				after.call()
	return true


## 키보드(07 §9.4 표, 물리 키). 열린 동안 누른 키는 모두 삼킨다: 표에 없는 키·반복·Ctrl·Alt·Meta 키는 아무것도 하지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey:
		return
	if blocked_hook.is_valid() and blocked_hook.call():
		return  # 캠프 위에 뜬 창(기록의 메뉴 창 등)과 탐색 화면이 받는다
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var code := k.physical_keycode
	if not dialog_kind.is_empty():
		match code:
			KEY_LEFT:
				handle("dialog_move", -1)
			KEY_RIGHT:
				handle("dialog_move", 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				handle("dialog_ok")
			KEY_ESCAPE:
				handle("dialog_back")
		return
	if code == KEY_ESCAPE or event.is_action_pressed("open_party"):
		handle("back")
		return
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	if page == "root":
		if code >= KEY_1 and code <= KEY_6:
			handle("camp", code - KEY_1)
		elif code >= KEY_KP_1 and code <= KEY_KP_6:
			handle("camp", code - KEY_KP_1)
		elif code == KEY_UP:
			handle("camp_cursor", -1)
		elif code == KEY_DOWN:
			handle("camp_cursor", 1)
		elif enter:
			handle("confirm")
		return
	if page == "pick":
		match code:
			KEY_UP:
				handle("pick_move", Vector2i(0, -1))
			KEY_DOWN:
				handle("pick_move", Vector2i(0, 1))
			KEY_LEFT:
				handle("pick_move", Vector2i(-1, 0))
			KEY_RIGHT:
				handle("pick_move", Vector2i(1, 0))
		if enter:
			handle("confirm")
		return
	match code:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			handle("tab", code - KEY_1)
			return
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5:
			handle("tab", code - KEY_KP_1)
			return
		KEY_Q:
			handle("member_step", -1)
			return
		KEY_E:
			handle("member_step", 1)
			return
	if tab == 1:
		match code:
			KEY_UP:
				handle("node_dir", Vector2i(0, -1))
			KEY_DOWN:
				handle("node_dir", Vector2i(0, 1))
			KEY_LEFT:
				handle("node_dir", Vector2i(-1, 0))
			KEY_RIGHT:
				handle("node_dir", Vector2i(1, 0))
			KEY_BACKSPACE:
				handle("minus")
			KEY_R:
				handle("revert")
			KEY_F:
				handle("commit")
		if enter:
			handle("plus")
		return
	match code:
		KEY_UP:
			handle("cursor", -1)
		KEY_DOWN:
			handle("cursor", 1)
		KEY_BACKSPACE:
			if tab == 2:
				handle("unequip")
		KEY_LEFT:
			if tab == 4:
				handle("cursor_x", -1)  # 기록: 줄 안
		KEY_RIGHT:
			if tab == 4:
				handle("cursor_x", 1)
		KEY_V:
			if tab == 0:
				handle("split")  # 상태: 「내역」(기본·패시브·장비 보기)
	if enter:
		handle("confirm")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			cancel_pointers()


# ---- 규칙 결과 ----

## 규칙 함수의 이벤트 열을 받는다. 거부면 이유를 알림 줄에 띄우고 false. 받아들여졌으면 저장 갈고리 → 알림 → changed.
func apply(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(reason_text(str(events[0]["reason"])))
		return false
	if save_hook.is_valid():
		save_hook.call()
	show_notice(events_text(events))
	changed.emit(events)
	return true


## 알림 줄 글(받아들여진 성장 이벤트). 레벨업이 있으면 그 줄을 앞에.
func events_text(events: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for ev in events:
		var who := member_name(int(ev["member"])) if ev.has("member") else ""
		match str(ev["type"]):
			"level_up":
				lines.push_front(texts.t("battle.event.level_up", {"member": who, "from": ev["from"], "to": ev["to"]}))
			"exp":
				lines.append(texts.t("battle.event.exp_capped" if ev["capped"] else "battle.event.exp", {"member": who, "gained": ev["gained"]}))
			"skills_learned":
				lines.append(texts.t("growth.event.skills_learned", {"member": who, "sp_left": ev["sp_left"]}))
			"max_changed":
				lines.append(texts.t("growth.event.max_changed", {"member": who, "max_hp": ev["max_hp"], "max_tp": ev["max_tp"]}))
			"equipped":
				if str(ev["item"]).is_empty():
					lines.append(texts.t("growth.event.unequipped", {"member": who, "item": item_name(str(ev["removed"]))}))
				else:
					lines.append(texts.t("growth.event.equipped", {"member": who, "item": item_name(str(ev["item"]))}))
			"supplied":
				lines.append(texts.t("growth.event.supplied_capped" if ev["capped"] else "growth.event.supplied", {"item": item_name(str(ev["item"])), "amount": ev["amount"]}))
	return "\n".join(lines.slice(0, 2))


func item_name(id: String) -> String:
	var e := state.defs.battle.equip(id)
	return texts.t(e.name_key) if e != null else texts.t(id)


func show_notice(t: String) -> void:
	notice = t
	_notice_left = NOTICE_SEC
	_refresh_banner()
	queue_redraw()


## 안내를 비운다(글·남은 시간): 닫았다 다시 열 때 앞 안내가 남지 않는다.
func _clear_notice() -> void:
	notice = ""
	_notice_left = 0.0
	_refresh_banner()
	queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()


# ---- 그리기 ----

func _refresh() -> void:
	if not _built or not _open or state == null:
		return
	# 문맥이 바뀌면(탭·대원·확인 창·장비 목록) 앞 문맥에서 시작한 누르기를 버린다: 그 손가락은 뗄 때까지 아무것도 누르지 못한다.
	var sub := page == "sub"
	var ctx := "%s|%d|%d|%d|%s|%s" % [page, pick_cmd, tab, member, dialog_kind, tabs[tab].call("context") if sub else ""]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	for i in tabs.size():
		(tabs[i] as Control).visible = sub and i == tab
	if sub:
		tabs[tab].call("refresh")
	for c in [camp_plate, banner, camp_list, cards]:
		(c as Control).visible = not sub
	if not sub:
		_refresh_camp()
	_refresh_dialog()
	queue_redraw()


func _refresh_camp() -> void:
	camp_plate.show_lines(texts.t(state.floor_def.name_key), texts.t("hud.steps", {"steps": state.steps}))
	var pick := page == "pick"
	var live := []
	for i in CAMP_KEYS.size():
		camp_list.set_row_text(i, camp_label(i))
		live.append(not pick or i == CAMP_KEYS.size() - 1)
	camp_list.show_rows(-1 if pick else camp_cursor, pick_cmd if pick else -1, live)
	display.sync_party(state)
	# 고르기: 전투 아군 대상 고르기 표시(누를 수 있는 카드 모두 노랑 테두리, 커서 카드는 흰 안쪽 선).
	for c in cards.cards:
		c.target_mark = "valid" if pick else ""
		c.cursor = pick and c == cards.card(pick_cursor)
		c.current = false
		c.mouse_filter = MOUSE_FILTER_STOP if pick else MOUSE_FILTER_IGNORE
		if not pick:
			c.cancel()
		c.queue_redraw()
	_refresh_banner()


## 설명 띠: 뿌리 = 커서 명령의 설명, 고르기 = 물음. 안내(거부 이유 등)가 있으면 둘째 줄.
func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	var head := texts.t(("camp.pick." if page == "pick" else "camp.desc.") + CAMP_KEYS[pick_cmd if page == "pick" else camp_cursor])
	banner.show_lines(head, notice, not notice.is_empty())
	# 하위 화면은 제 자리에 안내를 보인다(스킬 = 정보 띠, 장비·소지품 = 설명 띠).
	if page == "sub" and (tabs[tab] as Object).has_method("notice_changed"):
		tabs[tab].call("notice_changed")


func _refresh_dialog() -> void:
	dialog_layer.visible = not dialog_kind.is_empty()
	if dialog_kind.is_empty():
		return
	match dialog_kind:
		"discard":
			_dialog_text.text = texts.t("party.dialog.discard_text")
			dialog_buttons[1].text = texts.t("party.dialog.discard")
		"new_game":
			_dialog_text.text = texts.t("menu.confirm_new_game")
			dialog_buttons[1].text = texts.t("menu.new_game")
		_:
			_dialog_text.text = texts.t("party.dialog.commit_text", {"n": skill_tab.draft_sp()})
			dialog_buttons[1].text = texts.t("party.dialog.commit")
	dialog_buttons[0].text = texts.t("party.dialog.back")
	for i in 2:
		dialog_buttons[i].selected = i == dialog_pick
		dialog_buttons[i].queue_redraw()
	dialog_layer.queue_redraw()


func dialog_rect() -> Rect2:
	return Rect2(((size - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)


func _layout() -> void:
	if not _built:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	for t in tabs:
		t.call("place", s)  # 하위 화면은 모두 앵커로 화면 전체에 붙는다
	dialog_layer.position = Vector2.ZERO
	dialog_layer.size = s
	var dr := Rect2(((s - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)
	_dialog_text.position = dr.position + Vector2(24, 20)
	_dialog_text.size = Vector2(DIALOG_SIZE.x - 48, DIALOG_SIZE.y - DIALOG_BUTTON.y - 56)
	var by := dr.end.y - DIALOG_BUTTON.y - 24
	dialog_buttons[0].position = Vector2(dr.position.x + 40, by)
	dialog_buttons[1].position = Vector2(dr.end.x - 40 - DIALOG_BUTTON.x, by)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.CAMP_DIM)


func _draw_dialog() -> void:
	dialog_layer.draw_rect(Rect2(Vector2.ZERO, dialog_layer.size), Color(0, 0, 0, 0.6))
	UiTheme.draw_tree_window(dialog_layer, dialog_rect(), true)  # 확인 창은 뒤 노드가 비치지 않게 불투명


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 단추·노드·줄 전부(확인 창이 떠 있으면 그 창 단추만). 끌어 내리는 영역 밖으로 다 나간 줄은 뺀다.
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open:
		return out
	var root_node: Node = dialog_layer if dialog_layer.visible else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		if root_node == self and dialog_layer.is_ancestor_of(b):
			continue
		if clipped_rect(b).size.y <= 0.0:
			continue
		out.append(b)
	return out


## 단추의 화면 사각형(이 메뉴 기준). 끌어 내리는 영역 안이면 그 영역으로 자른 부분.
func clipped_rect(b: Control) -> Rect2:
	var r := Rect2(b.get_global_position() - get_global_position(), b.size)
	var p := b.get_parent()
	while p != null and p != self:
		if p is PartyScroll:
			var sr := Rect2((p as Control).get_global_position() - get_global_position(), (p as Control).size)
			r = r.intersection(sr)
		p = p.get_parent()
	return r


## 디버그 요청 snapshot 의 파티 메뉴 정보(07 §8.6). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
## 단추는 보이는 부분의 가운데(끌어 내리는 영역에 반쯤 걸친 줄도 누를 수 있는 곳), 트리 노드는 스킬 ID 로도 낸다.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	var nodes := {}
	var tree := state.defs.class_of(member).tree
	for b in visible_buttons():
		var r := clipped_rect(b)
		var local := r.get_center() - (b.get_global_position() - get_global_position())
		var at: Array = css.call(local, b)
		buttons[b.name] = at
		if b is SkillNode and (b as SkillNode).index < tree.size():
			nodes[str(tree[(b as SkillNode).index]["skill"])] = at
	var rows := []
	if tab == 2 and equip_tab.list_open:
		for j in equip_tab.row_items.size():
			rows.append({"item": equip_tab.row_items[j], "block": equip_tab.row_block[j], "button": equip_tab.rows[j].name})
	return {
		"open": true, "page": page, "tab": TAB_KEYS[tab] if page == "sub" else "", "member": member,
		"camp_cursor": camp_cursor, "pick": CAMP_KEYS[pick_cmd] if page == "pick" else "", "pick_cursor": pick_cursor,
		"banner": banner.lines().slice(0, 2) if page != "sub" else [], "draft": skill_tab.draft.duplicate(),
		"cursor": {"skill": skill_tab.cursor_skill(), "slot": equip_tab.cursor, "list_open": equip_tab.list_open,
			"list_row": equip_tab.list_cursor if equip_tab.list_open else -1, "items": items_tab.cursor},
		"dialog": dialog_kind, "dialog_pick": dialog_pick, "sp_line": skill_tab._sp_label.text if tab == 1 else "",
		"notice": notice, "debug": debug, "supply_open": items_tab.supply_open, "equip_rows": rows,
		"records": {"cursor": [records_tab.cur_row, records_tab.cur_col], "cards": [0, 1, 2].map(records_tab.card_lines)} if tab == 4 else {},
		"buttons": buttons, "nodes": nodes,
	}


## 바깥(디버그 요청)이 상태를 바꿨을 때 열린 메뉴를 다시 그린다.
func refresh_view() -> void:
	_refresh()
