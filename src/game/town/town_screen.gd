## 마을 화면(M3 A2): 창 층 2(전투 층 뒤, 상점·캠프 앞). 마을에 있는 동안만 열려 있고, 바탕 그림은 탐색 화면의 TownBackdrop(층 0)이다.
## 쪽(page): plaza(광장, 원작 I HD The Verda Plaza yt_eo1hd_01) · entrance(아보르 입구, 원작 II HD 樹海入口 gw_27) ·
##   inn(캡슐 숙소, 원작 I HD 長鳴鶏の宿 jp_facility_img1, M3 A2b) · inn_save(숙소 「기록한다」: 기록 판 inn_save 줄, 원작 숙소 Save Game).
##   광장: 설명 띠(커서 시설 설명 / 안내) · 다이얼 자리 캠프 단추(TownPlate) · 시설 목록(왼쪽 띠에 커서 시설 그림) · 장소 문패 · 키패드.
##   입구: 띠(「아보르 B1F로 내려간다」 / 커서 줄 설명) · 캠프 단추 · 줄 둘(탐사 시작·마을로 돌아간다) · 파티 카드(읽기만) · 키패드.
##   숙소: 주인 자리표시(오른쪽, 장식) · 띠(커서 줄 설명 / 숙박비·안내) · 캠프 단추 · 소지금 · 줄 넷(숙박·기록·대화(흐림)·나간다) ·
##   파티 카드 · 숙박 확인 창(상점 창, 「예」 먼저 D25) · 키패드. 기록: 장소 띠 「기록한다」 · 기록 판(「저장」만) · 세로 키패드.
## 일(캠프·상점·탐사 시작)은 신호로, 숙박은 stay_hook 으로, 슬롯 저장은 records 갈고리(기록 판 주인 규약)로 탐색 화면에 맡긴다. 캠프·상점이 열린 동안 탐색 화면이 이 화면을 덮어 감춘다(set_covered).
## 입력 입구 하나(07 §9.4): 단추·목록 줄·키보드·가상 키패드가 모두 handle() 로 온다. 층 3 창이 떠 있으면(blocked_hook) 받지 않는다.
class_name TownScreen
extends Control

signal opened
signal closed
signal camp_requested
signal shop_requested
signal enter_requested

## 광장 시설(원작 차례, 숫자 키 1~6).
const PLAZA_KEYS := ["inn", "shop", "pub", "guild", "council", "entrance"]
## 아직 문을 열지 않은 시설(누르면 이유만).
const PLAZA_DIM := ["pub", "guild", "council"]
const ENTRANCE_KEYS := ["start", "back"]
## 숙소 줄(원작 차례에서 夜まで休憩する·預かり所는 뺀다: 시계·맡김이 없다). 대화는 주인이 없어 흐림.
const INN_KEYS := ["stay", "save", "talk", "leave"]
const INN_DIM := ["talk"]
## 광장 목록: x 0~580(왼쪽 띠 150), y 104~509, 줄 사이 3·안쪽 여백 3(§5.2).
const PLAZA_TOP := 104.0
const PLAZA_W := 580.0
const PLAZA_LEAD := 150.0
const PLAZA_GAP := 3.0
const PLAZA_PAD := 3.0
## 입구 목록: x 0~430, y 288~428(원작 gw_27 의 두 줄 y 300~415 둘레, 줄 64 라 위아래로 조금 넓다). 줄 사이 4·안쪽 여백 4.
const ENTRANCE_TOP := 288.0
const ENTRANCE_GAP := 4.0
const ENTRANCE_PAD := 4.0
## 숙소 목록: x 0~430, y 166~(줄 넷), 줄 사이 4·안쪽 여백 4(§5.5). 소지금 문패 0,112 340×50. 주인 자리표시 x W − 560 ~ W, 화면 높이.
const INN_TOP := 166.0
const INN_GAP := 4.0
const INN_PAD := 4.0
const MONEY_PLATE := Rect2(0, 112, 340, 50)
const NPC_W := 560.0
## 장소 문패: 오른쪽 아래(W − 360 ~ W, y H − 88 ~ H − 12).
const PLACE_PLATE := Vector4(-360, -88, 0, -12)
const NOTICE_SEC := 2.5
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 키패드 자리(상점 뿌리와 같다): 십자 왼쪽 아래, 「취소」「선택」 가로 (W − 247, H − 293).
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_AT := Vector2(-247, -293)

# ---- 바깥에서 정하는 값 ----
var blocked_hook: Callable
## 숙박(탐색 화면이 TownRules.stay·자동 저장을 하고 이벤트 열을 돌려준다).
var stay_hook: Callable
## 기록 판 주인 규약(PartyRecordsTab): slots·save·automap·can_save 등. 숙소 기록 쪽은 늘 저장을 받는다.
var records := {}
## 지금 장소 그림을 그릴 화면 전체 바탕(탐색 화면 층 0).
var backdrop: TownArt.TownBackdrop

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## plaza · entrance · inn · inn_save
var page := "plaza"
var plaza_cursor := 0
var entrance_cursor := 0
var inn_cursor := 0
var notice := ""
var covered := false
var accepted_inputs := 0

# ---- 부품 ----
var banner: FacilityBanner
var camp_plate: TownPlate
var plaza_list: FacilityList
var entrance_list: FacilityList
var inn_list: FacilityList
var npc: Control
var money_plate: Control
var ribbon: PlaceRibbon
var records_tab: PartyRecordsTab
var dialog: ShopDialog
var key_pad_stacked: VirtualPad
var place_plate: FacilityPlate
var cards: PartyCards
var dir_pad: VirtualPad
var key_pad: VirtualPad
var _notice_left := 0.0
var _built := false
var _open := false
var _input_frame := -1
var _context := ""


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE  # 빈 곳은 아래(바탕만, 3D 시야는 감췄다)로: 막을 것이 없다
	focus_mode = FOCUS_NONE
	visible = false


## 트리 순서 = 그리는·누르는 순서: 숙소 주인(장식) → 카드 → 띠 → 장소 문패(장식) → 목록 셋 → 소지금(장식) → 장소 띠 → 기록 판 →
## 캠프 단추 → 숙박 확인 창(어두운 판이 아래를 막는다) → 키패드(맨 위, 확인 창에서도 누른다: 캠프·타이틀과 같다).
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	npc = Control.new()
	npc.name = "InnNpc"
	npc.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(npc)
	PartyMenu.place(npc, Vector2(1, 0), Vector2(1, 1), Vector4(-NPC_W, 0, 0, 0))
	npc.draw.connect(func() -> void: TownArt.paint(npc, Rect2(Vector2.ZERO, npc.size), "npc_inn"))
	cards = PartyCards.new()
	cards.name = "TownCards"
	add_child(cards)
	PartyMenu.place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	banner = FacilityBanner.new()
	banner.name = "TownBanner"
	add_child(banner)
	banner.place()
	place_plate = FacilityPlate.new()
	place_plate.name = "TownPlacePlate"
	add_child(place_plate)
	PartyMenu.place(place_plate, Vector2(1, 1), Vector2(1, 1), PLACE_PLATE)
	plaza_list = _list("PlazaList", "Plaza_", PLAZA_KEYS, "row", PLAZA_GAP, PLAZA_PAD)
	plaza_list.lead = PLAZA_LEAD
	entrance_list = _list("EntranceList", "Entrance_", ENTRANCE_KEYS, "row", ENTRANCE_GAP, ENTRANCE_PAD)
	inn_list = _list("InnList", "Inn_", INN_KEYS, "row", INN_GAP, INN_PAD)
	money_plate = Control.new()
	money_plate.name = "InnMoney"
	money_plate.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(money_plate)
	PartyMenu.place(money_plate, Vector2.ZERO, Vector2.ZERO,
		Vector4(MONEY_PLATE.position.x, MONEY_PLATE.position.y, MONEY_PLATE.end.x, MONEY_PLATE.end.y))
	money_plate.draw.connect(func() -> void: ShopFrame.paint_title(money_plate, money_text(), true))
	ribbon = PlaceRibbon.new()
	ribbon.name = "InnRibbon"
	add_child(ribbon)
	PartyMenu.place(ribbon, Vector2.ZERO, Vector2(1, 0), Vector4(PartyMenu.RIBBON_X, 0, -16, PartyMenu.RIBBON_H))
	records_tab = PartyRecordsTab.new()
	records_tab.name = "InnRecords"
	add_child(records_tab)
	records_tab.setup(self, "inn_save")
	camp_plate = TownPlate.new()
	add_child(camp_plate)
	camp_plate.setup("", texts.t("town.camp"))
	camp_plate.name = "CampButton"
	PartyMenu.place(camp_plate, Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, TownPlate.SIZE.x, TownPlate.SIZE.y))
	camp_plate.activated.connect(func() -> void: handle("camp"))
	dialog = ShopDialog.new()
	dialog.name = "InnDialog"
	add_child(dialog)
	dialog.setup(texts)
	dialog.route = func(kind: String, arg: Variant) -> void: handle("dialog", [kind, arg])
	dialog.answered.connect(_on_stay_answered)
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
	_layout()


func _list(n: String, row_prefix: String, keys: Array, kind: String, gap: float, pad: float) -> FacilityList:
	var l := FacilityList.new()
	l.name = n
	l.row_gap = gap
	l.inner_pad = pad
	add_child(l)
	var items := []
	for i in keys.size():
		items.append({"name": row_prefix + str(keys[i]), "text": ""})
	l.set_items(items)
	l.pressed.connect(func(i: int) -> void: handle(kind, i))
	return l


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


## 연다(마을에 들어올 때): 광장, 커서 0, 안내 없음.
func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	page = "plaza"
	plaza_cursor = 0
	entrance_cursor = 0
	inn_cursor = 0
	dialog.close()
	covered = false
	_clear_notice()
	_open = true
	visible = true
	_setup_cards()
	cancel_pointers()
	_context = ""
	_layout()
	_refresh()
	opened.emit()


func close_town(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	covered = false
	dialog.close()
	_clear_notice()
	cancel_pointers()
	if notify:
		closed.emit()


## 캠프·상점이 위에 열린 동안 감춘다(그림 창에는 마을 바탕만 보인다, research 07 §2.2). 걷으면 쪽·커서 그대로 돌아온다.
func set_covered(on: bool) -> void:
	if not _open:
		return
	covered = on
	visible = not on
	cancel_pointers()
	if not on:
		_setup_cards()  # 캠프·상점에서 파티가 바뀌었을 수 있다
		_refresh()


func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()


func _setup_cards() -> void:
	cards.setup(BattleDisplay.from_party(state, texts), state.defs.party.class_ids)
	for c in cards.cards:
		c.mouse_filter = MOUSE_FILTER_IGNORE  # 입구의 카드는 읽기만
		c.snap()


# ---- 입력 입구 ----

## 광장: row(0~5)·cursor(±1, 감김)·confirm·camp. 입구: row(0~1)·cursor(±1)·confirm·back(광장으로)·camp.
func handle(kind: String, arg: Variant = null) -> bool:
	if not _open or covered:
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


func keys_of(p: String) -> Array:
	match p:
		"plaza":
			return PLAZA_KEYS
		"entrance":
			return ENTRANCE_KEYS
		"inn":
			return INN_KEYS
	return []


## 숙박 확인 창이 떠 있으면 dialog([ShopDialog 입력 종류, 값])만 받는다. 기록 쪽: back(숙소로)·camp, 나머지는 기록 판 입력.
func _dispatch(kind: String, arg: Variant) -> bool:
	if dialog.is_open():
		if kind != "dialog" or typeof(arg) != TYPE_ARRAY or (arg as Array).size() != 2:
			return false
		return dialog.handle(str(arg[0]), arg[1])
	if kind == "camp":
		camp_requested.emit()
		return true
	if page == "inn_save":
		if kind == "back":
			page = "inn"
			_clear_notice()
			return true
		return records_tab.dispatch(kind, arg)
	var keys := keys_of(page)
	match kind:
		"cursor":
			var c := wrapi(cursor() + (int(arg) if arg != null else 1), 0, keys.size())
			_set_cursor(c)
			_clear_notice()
			return true
		"row":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= keys.size():
				return false
			if i != cursor():
				_clear_notice()
			_set_cursor(i)
			return _run(i)
		"confirm":
			return _run(cursor())
		"back":
			if page == "plaza":
				return false  # 광장의 취소는 아무 일도 하지 않는다(§8 고름 16)
			_to_plaza("entrance" if page == "entrance" else "inn")
			return true
	return false


## 광장으로 돌아온다(커서는 떠난 시설 줄).
func _to_plaza(from: String) -> void:
	page = "plaza"
	plaza_cursor = PLAZA_KEYS.find(from)
	_clear_notice()


func cursor() -> int:
	match page:
		"plaza":
			return plaza_cursor
		"entrance":
			return entrance_cursor
		"inn", "inn_save":
			return inn_cursor
	return 0


func _set_cursor(i: int) -> void:
	match page:
		"plaza":
			plaza_cursor = i
		"entrance":
			entrance_cursor = i
		"inn":
			inn_cursor = i


## 줄 i 의 일. 광장: 흐린 시설 → 이유만, 캡슐 숙소 → 숙소 쪽, 정크 공방 → 상점(탐색 화면이 연다), 아보르 입구 → 입구 쪽.
## 입구: 탐사 시작 → 탐색 화면, 돌아가기 → 광장. 숙소: 숙박 → 확인 창(돈이 모자라면 이유만), 기록 → 기록 쪽, 대화 → 이유만, 나간다 → 광장.
func _run(i: int) -> bool:
	match page:
		"plaza":
			var k: String = PLAZA_KEYS[i]
			if PLAZA_DIM.has(k):
				show_notice(texts.t("town.why.later"))
				return true
			match k:
				"inn":
					page = "inn"
					inn_cursor = 0
					_clear_notice()
				"shop":
					shop_requested.emit()
				"entrance":
					page = "entrance"
					entrance_cursor = 0
					_clear_notice()
			return true
		"entrance":
			match ENTRANCE_KEYS[i]:
				"start":
					enter_requested.emit()
				"back":
					_to_plaza("entrance")
			return true
	match INN_KEYS[i]:
		"stay":
			_ask_stay()
		"save":
			page = "inn_save"
			records_tab.set_rows("inn_save")
			records_tab.member_changed()  # 슬롯을 새로 읽는다
			_clear_notice()
		"talk":
			show_notice(texts.t("inn.why.talk"))
		"leave":
			_to_plaza("inn")
	return true


## 숙박 확인(「예」 먼저, D25: 값을 치르는 물음). 돈이 모자라면 창 없이 이유만.
func _ask_stay() -> void:
	var price := TownRules.inn_price(state)
	if state.money < price:
		show_notice(texts.t("shop.why.no_money"))
		return
	_clear_notice()
	dialog.open_confirm(texts.t("inn.ask_stay", {"price": ShopRow.grouped(price)}), true)


## 숙박 확인의 답: 「예」면 탐색 화면이 묵는다(규칙·자동 저장). 결과를 띠 둘째 줄에 알린다.
func _on_stay_answered(yes: bool, _qty: int) -> void:
	if not yes or not stay_hook.is_valid():
		return
	var events: Array = stay_hook.call()
	for e in events:
		match str(e["type"]):
			"stayed":
				_setup_cards()
				show_notice(texts.t("inn.stayed"))
			"blocked":
				show_notice(texts.t("shop.why.no_money") if e["reason"] == "no_money" else texts.t("inn.why.day_max"))


## 기록 판 주인 규약: 숙소 기록 쪽에는 확인 창을 띄울 일이 없다(새 게임 줄이 없다).
func open_dialog(_kind: String, _after: Callable = Callable()) -> void:
	pass


# ---- 키 ----

## 키보드: 반복이 아닌 첫 누름에서 한 번. 열린 동안(덮이지 않았을 때) 누른 키는 모두 삼킨다. P = 캠프.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or covered or not event is InputEventKey:
		return
	if blocked_hook.is_valid() and blocked_hook.call():
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	if event.is_action_pressed("open_party"):
		handle("camp")
		return
	var a := key_action(k.physical_keycode)
	if not a.is_empty():
		handle(a[0], a[1])


## 키 표 하나(키보드와 키패드가 같이 쓴다): 물리 키 → [입력 종류, 값], 하는 일이 없으면 []. 부작용 없음.
func key_action(code: int) -> Array:
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	var back := code == KEY_ESCAPE or code == KEY_BACKSPACE
	var dir := ShopScreen._arrow(code)
	if dialog.is_open():
		if back:
			return ["dialog", ["cancel", null]]
		if enter:
			return ["dialog", ["confirm", null]]
		return ["dialog", ["pick", dir.x]] if dir.x != 0 else []
	if page == "inn_save":
		if back:
			return ["back", null]
		if enter:
			return ["confirm", null]
		if dir.y != 0:
			return ["cursor", dir.y]
		return ["cursor_x", dir.x] if dir.x != 0 else []
	var num := ShopScreen._number(code)
	if num >= 0 and num < keys_of(page).size():
		return ["row", num]
	if enter:
		return ["confirm", null]
	if back:
		return ["back", null] if page != "plaza" else []
	return ["cursor", dir.y] if dir.y != 0 else []


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


## 키패드 단추마다 켤지: 키 표에 없거나 늘 거부되는 것은 흐림. 기록 쪽은 타이틀·캠프 기록과 같다(흐린 알약 위 선택, 줄 하나뿐인 ↑↓,
## 알약 하나뿐인 줄의 ←→). 끝이라도 움직일 자리가 있으면 켜 둔다.
func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		var a := key_action(PAD_KEYS[k])
		out[k] = not a.is_empty() and _may_accept(a)
	return out


func _may_accept(a: Array) -> bool:
	if dialog.is_open() or page != "inn_save":
		return true
	var g := records_tab.grid()
	match a[0]:
		"confirm":
			return not records_tab.cursor_button().disabled
		"cursor":
			return g.size() > 1
		"cursor_x":
			return (g[records_tab.cur_row] as Array).size() > 1
	return true


func stacked() -> bool:
	return page == "inn_save"


func active_key_pad() -> VirtualPad:
	return key_pad_stacked if stacked() else key_pad


func _place_pads() -> void:
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var ks := VirtualPad.keys_size(false)
	PartyMenu.place(key_pad, Vector2(1, 1), Vector2(1, 1), Vector4(PAD_KEYS_AT.x, PAD_KEYS_AT.y, PAD_KEYS_AT.x + ks.x, PAD_KEYS_AT.y + ks.y))
	var k := PartyMenu.PAD_KEYS_RECORDS
	var kss := VirtualPad.keys_size(true)
	PartyMenu.place(key_pad_stacked, Vector2(1, 1), Vector2(1, 1), Vector4(k.x, k.y, k.x + kss.x, k.y + kss.y))
	key_pad.visible = not stacked()
	key_pad_stacked.visible = stacked()


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


# ---- 글 ----

## 지금 장소 이름(캠프 장소 띠·장소 문패): 광장은 「뿌리마을 광장」, 입구·숙소는 그 시설 이름.
func place_text() -> String:
	match page:
		"plaza":
			return texts.t("town.plaza")
		"entrance":
			return texts.t("town.fac.entrance")
	return texts.t("town.fac.inn")


## 지금 바탕 그림 열쇠(TownArt).
func art_key() -> String:
	match page:
		"plaza", "entrance":
			return page
	return "inn"


## 숙소 소지금 문패 글(상점과 같은 꼴).
func money_text() -> String:
	return texts.t("shop.money", {"money": ShopRow.grouped(state.money if state != null else 0)})


## 숙소 띠 둘째 줄: 숙박비.
func price_text() -> String:
	return texts.t("inn.price", {"price": ShopRow.grouped(TownRules.inn_price(state))})


func day_text() -> String:
	return texts.t("town.day", {"n": state.day if state != null else 1})


func row_label(p: String, i: int) -> String:
	var k: String = keys_of(p)[i]
	var label := ""
	match p:
		"plaza":
			label = texts.t("town.fac." + k)
		"entrance":
			label = texts.t("entrance." + k)
		_:
			label = texts.t("inn." + k)
	return "%d  %s" % [i + 1, label]


func desc_text() -> String:
	var p := "inn" if page == "inn_save" else page
	var k: String = keys_of(p)[cursor()]
	match p:
		"plaza":
			return texts.t("town.desc." + k)
		"entrance":
			return texts.t("entrance.desc." + k)
	return texts.t("inn.desc." + k)


# ---- 그리기 ----

## 바깥(슬롯 저장·숙박)이 값을 바꿨을 때 다시 그린다.
func refresh_view() -> void:
	records_tab.member_changed()
	_refresh()


func _refresh() -> void:
	if not _built or not _open or state == null or covered:
		return  # 덮인 동안(캠프·상점)은 그리지 않는다: 바탕은 덮은 화면의 것(상점 그림)이다
	var ctx := "%s|%d|%s" % [page, cursor(), dialog.mode]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	var on_plaza := page == "plaza"
	var on_inn := page == "inn"
	var on_save := page == "inn_save"
	plaza_list.visible = on_plaza
	place_plate.visible = on_plaza
	entrance_list.visible = page == "entrance"
	inn_list.visible = on_inn
	cards.visible = page == "entrance" or on_inn
	npc.visible = on_inn
	money_plate.visible = on_inn
	banner.visible = not on_save
	ribbon.visible = on_save
	records_tab.visible = on_save
	camp_plate.show_day(day_text())
	place_plate.show_lines(place_text(), "")
	var live := []
	var dim := []
	for i in PLAZA_KEYS.size():
		plaza_list.set_row_text(i, row_label("plaza", i))
		live.append(true)
		dim.append(PLAZA_DIM.has(PLAZA_KEYS[i]))
	plaza_list.show_rows(plaza_cursor if on_plaza else -1, -1, live, dim)
	plaza_list.show_strip(PLAZA_KEYS[plaza_cursor])
	var elive := []
	for i in ENTRANCE_KEYS.size():
		entrance_list.set_row_text(i, row_label("entrance", i))
		elive.append(true)
	entrance_list.show_rows(entrance_cursor if page == "entrance" else -1, -1, elive)
	var ilive := []
	var idim := []
	for i in INN_KEYS.size():
		inn_list.set_row_text(i, row_label("inn", i))
		ilive.append(true)
		idim.append(INN_DIM.has(INN_KEYS[i]))
	inn_list.show_rows(inn_cursor if on_inn else -1, -1, ilive, idim)
	if cards.visible:
		for c in cards.cards:
			c.queue_redraw()
	money_plate.queue_redraw()
	npc.queue_redraw()
	if on_save:
		ribbon.show_text(texts.t("inn.save"))
		records_tab.refresh()
	if backdrop != null:
		backdrop.show_place(art_key())
	_refresh_banner()
	_place_pads()
	var on := pad_state()
	for p in [dir_pad, key_pad, key_pad_stacked]:
		(p as VirtualPad).set_enabled(on)


func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	match page:
		"plaza":
			banner.show_lines(desc_text(), notice, not notice.is_empty())
		"entrance":
			banner.show_lines(texts.t("entrance.band"), notice if not notice.is_empty() else desc_text(), not notice.is_empty())
		_:
			banner.show_lines(desc_text(), notice if not notice.is_empty() else price_text(), not notice.is_empty())


func _layout() -> void:
	if not _built:
		return
	PartyMenu.place(plaza_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, PLAZA_TOP, PLAZA_W, PLAZA_TOP + FacilityList.content_height(PLAZA_KEYS.size(), PLAZA_GAP, PLAZA_PAD)))
	PartyMenu.place(entrance_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, ENTRANCE_TOP, FacilityList.WIDTH, ENTRANCE_TOP + FacilityList.content_height(ENTRANCE_KEYS.size(), ENTRANCE_GAP, ENTRANCE_PAD)))
	PartyMenu.place(inn_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, INN_TOP, FacilityList.WIDTH, INN_TOP + FacilityList.content_height(INN_KEYS.size(), INN_GAP, INN_PAD)))
	banner.place()
	var s := size if size.x > 0.0 else get_viewport_rect().size
	records_tab.place(s)
	dialog.set_area(Rect2(Vector2.ZERO, s))
	_place_pads()


# ---- 시험·디버그 읽기 ----

func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open or covered:
		return out
	var root_node: Node = dialog if dialog.is_open() else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.get_parent() is VirtualPad:
			continue
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		out.append(b)
	for p in [dir_pad, key_pad, key_pad_stacked]:
		var vp := p as VirtualPad
		for k in vp.buttons:
			var b: TouchButton = vp.buttons[k]
			if not b.disabled and b.is_visible_in_tree():
				out.append(b)
	return out


func yellow_fills() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	for n in find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.selected and b.is_visible_in_tree():
			out.append(b)
	return out


## 디버그 snapshot 의 town 정보.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	var keys := keys_of(page)
	var dim := []
	for k in keys:
		dim.append((page == "plaza" and PLAZA_DIM.has(k)) or (page == "inn" and INN_DIM.has(k)))
	var names := []
	var l: FacilityList = {"plaza": plaza_list, "entrance": entrance_list, "inn": inn_list}.get(page)
	for i in keys.size():
		names.append(str(l.rows[i].name))
	var out := {
		"open": true, "page": page, "cursor": cursor(), "rows": names, "dim": dim, "band": [banner.head, banner.body],
		"place": place_text(), "art": art_key(), "day": day_text(), "covered": covered, "notice": notice,
		"pad": pad_state(), "buttons": buttons, "money": state.money,
		"dialog": {"mode": dialog.mode, "pick": dialog.pick, "text": dialog.message},
	}
	if page == "inn":
		out["price"] = TownRules.inn_price(state)
	if page == "inn_save":
		var cards_out := []
		for i in 3:
			cards_out.append(records_tab.card_lines(i))
		out["records"] = {"rows": records_tab.row_set, "cursor": [records_tab.cur_row, records_tab.cur_col], "cards": cards_out,
			"help": records_tab.help_text()}
	return out
