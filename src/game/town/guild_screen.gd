## 모험가 길드 화면(M3 A7c, 설계 §5): 창 층 2(상점 뒤, 타이틀 앞). 마을 광장 「모험가 길드」에서 연다(상점과 같은 길: 마을 화면을 덮고
## 바탕은 TownBackdrop 의 guild 그림). 쪽(page):
##   root(원작 冒険者ギルド jp_guide1_img1): 다이얼 자리 캠프 단추(GuildPlate) · 띠 두 줄 · 소지금 · 줄 다섯(등록·관리·편성·대화(흐림)·나간다) ·
##     길드장 자리표시(오른쪽, 장식) · 파티 카드(읽기만).
##   class(원작 직업 고르기 jp_guide1_img2): 직업 문패 · 직업 목록 창(여섯) · 직업 판(Lv1 HP·TP·시작 장비·능력치·공격·방어) · 설명 상자.
##   look(원작 외형 고르기 jp_guide1_img3): 직업 문패 · 외형 띠 둘(자리표시 A·B) · 안내 상자 · 큰 자리표시.
##   manage(冒険者の管理): 등록부 목록 창(주무기 아이콘·이름·「파티」, 띠 둘째 줄 = 커서 대원 직업·Lv) → manage_menu: 작은 목록
##     (이름 바꾸기·등록 지우기·돌아가기).
##   form(원작 編成と並び替え gw_13): 등록부 목록 창(맨 앞 「비우기」, 판 위 대원은 흐림 + 「파티」) · 편성 판(FormBoard) · 길드장 자리표시.
## 이름은 탐색 화면이 받는다(name_requested → 웹 window.prompt, PC 는 LineEdit 창 → name_entered). 확인 창은 상점 창(ShopDialog).
## 상태는 규칙(GuildRules.register·rename·remove·form)으로만 바꾸고 받아들여지면 save_hook(자동 저장) 뒤 changed 를 낸다.
## 열기·닫기·커서 이동·거부는 저장하지 않는다. 입력 입구 하나(handle): 단추·목록 줄·키보드·가상 키패드가 모두 여기로 온다.
class_name GuildScreen
extends Control

signal opened
signal closed
signal camp_requested
## 이름 입력을 부탁한다(기본 이름). 탐색 화면이 받아 name_entered(글 또는 null) 를 부른다.
signal name_requested(default_name: String)
## 규칙이 상태를 바꿨다(저장 갈고리 뒤).
signal changed(events: Array)

const ROOT_KEYS := ["register", "manage", "form", "talk", "leave"]
const ROOT_DIM := ["talk"]
const MANAGE_KEYS := ["rename", "remove", "back"]
## 직업 차례(설계 §4.2: 01 §5 표 차례). 잠긴 직업은 없다.
const CLASS_ORDER := ["class.holo_knight", "class.blade_duelist", "class.rail_ranger", "class.nano_medic", "class.glyph_wizard", "class.hex_hacker"]
## 뿌리 목록: 숙소와 같은 x 0~430, y 166~, 줄 사이·안쪽 여백 3(줄 다섯이 방향 십자 y 511 위에 든다. 설계 표의 y 176 에서 10 올렸다).
const ROOT_TOP := 166.0
const ROOT_GAP := 3.0
const ROOT_PAD := 3.0
const MONEY_PLATE := Rect2(0, 112, 340, 50)
const NPC_W := 560.0
## 직업 고르기(1280×720 기준, 왼쪽 위 앵커. 오른쪽 끝은 W − 48). 목록 폭 340: 가장 긴 「블레이드 듀얼리스트」가 줄 글 자리에 든다
## (설계 표의 300 에서 340 으로 넓혔다). 줄 아이콘 칸 = 직업 주무기 종류.
const CLASS_PLATE := Rect2(460, 16, 360, 48)
const CLASS_LIST := Rect2(48, 80, 340, 430)
const CLASS_SHEET_X := 400.0
const CLASS_SHEET_TOP := 96.0
const CLASS_SHEET_H := 252.0
const CLASS_DESC_TOP := 356.0
const CLASS_DESC_H := 176.0
const RIGHT := 48.0
## 외형: 문패 왼쪽 위, 띠 둘(140×420), 안내 상자, 큰 자리표시(오른쪽, 세로 키패드 왼쪽에서 끝난다: W − 140).
const LOOK_PLATE := Rect2(48, 16, 300, 48)
const LOOK_STRIP := Vector2(140, 420)
const LOOK_TOP := 80.0
const LOOK_X := [48.0, 200.0]
const LOOK_MSG := Rect2(216, 520, 444, 120)
const LOOK_PORTRAIT := Vector4(-560, 40, -140, -40)
## 등록부 목록 창(관리·편성): 소지금 문패를 감추고 띠 아래부터, 다섯 줄(방향 십자 y 511 위). 폭 376: 8자 이름과 「파티」가 한 줄에 든다
## (원작 gw_13 처럼 줄에는 이름만, 아이콘 칸 = 주무기 종류, 직업·레벨은 띠 둘째 줄). 관리 작은 목록·편성 판은 그 오른쪽 x 440.
const ROSTER := Rect2(48, 112, 376, 360)
const MANAGE_MENU := Rect2(440, 112, 300, 222)
const BOARD_AT := Vector2(440, 112)
const NOTICE_SEC := 2.5
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_AT := Vector2(-247, -293)
## 세로 「취소」「선택」: 직업·외형 쪽(오른쪽 판·큰 그림을 가리지 않게).
const PAD_KEYS_STACKED := Vector2(-118, -172)
## 능력치 막대의 꽉 찬 값(Lv1 값이라 작다).
const STAT_FULL := 30.0

# ---- 바깥에서 정하는 값 ----
var blocked_hook: Callable
var save_hook: Callable
var backdrop: TownArt.TownBackdrop

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## root · class · look · manage · manage_menu · form
var page := "root"
var root_cursor := 0
var class_cursor := 0
var look_cursor := 0
var manage_cursor := 0
var menu_cursor := 0
## 편성: 커서가 있는 쪽("board" · "roster").
var form_focus := "board"
## 확인 창이 묻는 일: "" · register · remove
var asking := ""
## 이름 입력이 무엇을 위한 것인지: "" · register · rename
var naming := ""
## 등록할 이름(확인 창에서 「예」를 기다린다).
var pending_name := ""
var notice := ""
var covered := false
var accepted_inputs := 0

# ---- 부품 ----
var npc: Control
var cards: PartyCards
var banner: FacilityBanner
var money_plate: Control
var root_list: FacilityList
var class_plate: Control
var class_window: ListWindow
var class_inv: InventoryList
var class_sheet: Control
var class_desc: Control
var look_plate: Control
var strips: Array[LookStrip] = []
var look_msg: Control
var look_portrait: Control
var roster_window: ListWindow
var roster_inv: InventoryList
var manage_window: ListWindow
var manage_inv: InventoryList
var board: FormBoard
var camp_plate: TownPlate
var dialog: ShopDialog
var dir_pad: VirtualPad
var key_pad: VirtualPad
var key_pad_stacked: VirtualPad
## 등록부 목록 줄의 대원 ID(편성은 맨 앞이 「비우기」 "").
var roster_ids: Array[String] = []
var _notice_left := 0.0
var _built := false
var _open := false
var _input_frame := -1
var _context := ""


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 뒤의 마을 바탕·HUD 에 포인터가 닿지 않게
	focus_mode = FOCUS_NONE
	visible = false


## 트리 순서 = 그리는·누르는 순서: 길드장(장식) → 카드 → 띠 → 소지금 → 뿌리 목록 → 직업 쪽 → 외형 쪽 → 등록부 → 관리 목록 → 편성 판 →
## 캠프 단추 → 확인 창(어두운 판이 아래를 막는다) → 키패드(맨 위).
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	npc = _deco("GuildNpc", Vector2(1, 0), Vector2(1, 1), Vector4(-NPC_W, 0, 0, 0))
	npc.draw.connect(func() -> void: TownArt.paint(npc, Rect2(Vector2.ZERO, npc.size), "npc_guild"))
	cards = PartyCards.new()
	cards.name = "GuildCards"
	add_child(cards)
	PartyMenu.place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	banner = FacilityBanner.new()
	banner.name = "GuildBanner"
	add_child(banner)
	banner.place()
	money_plate = _deco("GuildMoney", Vector2.ZERO, Vector2.ZERO,
		Vector4(MONEY_PLATE.position.x, MONEY_PLATE.position.y, MONEY_PLATE.end.x, MONEY_PLATE.end.y))
	money_plate.draw.connect(func() -> void: ShopFrame.paint_title(money_plate, money_text(), true))
	root_list = FacilityList.new()
	root_list.name = "GuildList"
	root_list.row_gap = ROOT_GAP
	root_list.inner_pad = ROOT_PAD
	add_child(root_list)
	var items := []
	for k in ROOT_KEYS:
		items.append({"name": "Guild_" + k, "text": ""})
	root_list.set_items(items)
	root_list.pressed.connect(func(i: int) -> void: handle("row", i))
	_build_class()
	_build_look()
	roster_window = ListWindow.new()
	roster_window.name = "RosterWindow"
	add_child(roster_window)
	roster_window.list.name = "RosterList"
	roster_inv = InventoryList.new(roster_window.list, InventoryLook.new(), "Roster_")
	roster_inv.route = func(k: int) -> void: handle("roster", k)
	manage_window = ListWindow.new()
	manage_window.name = "ManageWindow"
	add_child(manage_window)
	manage_window.list.name = "ManageList"
	manage_inv = InventoryList.new(manage_window.list, InventoryLook.new(), "Manage_")
	manage_inv.route = func(k: int) -> void: handle("row", k)
	board = FormBoard.new()
	board.name = "GuildBoard"
	add_child(board)
	board.setup(texts)
	board.route = func(kind: String, arg: Variant) -> void: handle(kind, arg)
	camp_plate = TownPlate.new()
	add_child(camp_plate)
	camp_plate.setup("", texts.t("town.camp"))
	camp_plate.name = "GuildPlate"
	PartyMenu.place(camp_plate, Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, TownPlate.SIZE.x, TownPlate.SIZE.y))
	camp_plate.activated.connect(func() -> void: handle("camp"))
	dialog = ShopDialog.new()
	dialog.name = "GuildDialog"
	add_child(dialog)
	dialog.setup(texts)
	dialog.route = func(kind: String, arg: Variant) -> void: handle("dialog", [kind, arg])
	dialog.answered.connect(_on_answered)
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


func _build_class() -> void:
	class_plate = _deco("ClassPlate", Vector2.ZERO, Vector2.ZERO,
		Vector4(CLASS_PLATE.position.x, CLASS_PLATE.position.y, CLASS_PLATE.end.x, CLASS_PLATE.end.y))
	class_plate.draw.connect(func() -> void: _draw_plate(class_plate))
	class_window = ListWindow.new()
	class_window.name = "ClassWindow"
	add_child(class_window)
	class_window.list.name = "ClassList"
	PartyMenu.place(class_window, Vector2.ZERO, Vector2.ZERO,
		Vector4(CLASS_LIST.position.x, CLASS_LIST.position.y, CLASS_LIST.end.x, CLASS_LIST.end.y))
	class_inv = InventoryList.new(class_window.list, InventoryLook.new(), "Class_")
	class_inv.route = func(k: int) -> void: handle("row", k)
	class_sheet = _deco("ClassSheet", Vector2.ZERO, Vector2(1, 0),
		Vector4(CLASS_SHEET_X, CLASS_SHEET_TOP, -RIGHT, CLASS_SHEET_TOP + CLASS_SHEET_H))
	class_sheet.draw.connect(_draw_sheet)
	class_desc = _deco("ClassDesc", Vector2.ZERO, Vector2(1, 0),
		Vector4(CLASS_SHEET_X, CLASS_DESC_TOP, -RIGHT, CLASS_DESC_TOP + CLASS_DESC_H))
	class_desc.draw.connect(func() -> void:
		SheetParts.begin(class_desc)
		ListParts.draw_desc(class_desc, Rect2(Vector2.ZERO, class_desc.size), class_name_text(), "", class_desc_lines()))


func _build_look() -> void:
	look_plate = _deco("LookPlate", Vector2.ZERO, Vector2.ZERO,
		Vector4(LOOK_PLATE.position.x, LOOK_PLATE.position.y, LOOK_PLATE.end.x, LOOK_PLATE.end.y))
	look_plate.draw.connect(func() -> void: _draw_plate(look_plate))
	for i in GuildRules.LOOKS:
		var st := LookStrip.new()
		st.name = "Look_%d" % i
		st.look = i
		add_child(st)
		PartyMenu.place(st, Vector2.ZERO, Vector2.ZERO, Vector4(LOOK_X[i], LOOK_TOP, LOOK_X[i] + LOOK_STRIP.x, LOOK_TOP + LOOK_STRIP.y))
		st.activated.connect(func() -> void: handle("look", i))
		strips.append(st)
	look_msg = _deco("LookMsg", Vector2.ZERO, Vector2.ZERO, Vector4(LOOK_MSG.position.x, LOOK_MSG.position.y, LOOK_MSG.end.x, LOOK_MSG.end.y))
	look_msg.draw.connect(func() -> void:
		SheetParts.begin(look_msg)
		ListParts.draw_banner(look_msg, Rect2(Vector2.ZERO, look_msg.size))
		var lines := look_msg_text().split("\n")
		for k in lines.size():
			SheetParts._text(look_msg, Vector2(40, 46 + k * 32), lines[k], 22, Color.WHITE, look_msg.size.x - 80))
	look_portrait = _deco("LookPortrait", Vector2(1, 0), Vector2(1, 1), LOOK_PORTRAIT)
	look_portrait.draw.connect(func() -> void:
		var cid := current_class()
		var r := Rect2(Vector2.ZERO, look_portrait.size)
		var col := LookStrip.color_of(cid, look_cursor)
		SheetParts.begin(look_portrait)
		SheetParts._log(look_portrait, {"kind": "silhouette", "rect": r, "color": col})  # 실루엣은 기록을 남기지 않아 시험이 읽을 색을 적는다
		MemberPortrait.draw_silhouette(look_portrait, r, col, texts.t(GuildScreen.short_key(cid)).left(1), 200))


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.focus_mode = FOCUS_NONE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	return c


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


## 연다(광장 「모험가 길드」): 뿌리, 커서 0, 안내 없음.
func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	page = "root"
	root_cursor = 0
	class_cursor = 0
	look_cursor = 0
	manage_cursor = 0
	menu_cursor = 0
	asking = ""
	naming = ""
	pending_name = ""
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


func close_guild(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	covered = false
	asking = ""
	naming = ""
	dialog.close()
	_clear_notice()
	cancel_pointers()
	if notify:
		closed.emit()


## 캠프가 위에 열린 동안 감춘다. 걷으면 쪽·커서 그대로(캠프에서 대열이 바뀌었을 수 있어 카드를 다시 만든다).
func set_covered(on: bool) -> void:
	if not _open:
		return
	covered = on
	visible = not on
	cancel_pointers()
	if not on:
		_setup_cards()
		_refresh()


func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


func _setup_cards() -> void:
	cards.setup(BattleDisplay.from_party(state, texts), PartyNames.class_ids(state))
	for c in cards.cards:
		c.mouse_filter = MOUSE_FILTER_IGNORE  # 길드의 카드는 읽기만
		c.snap()


# ---- 입력 입구 ----

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


func _dispatch(kind: String, arg: Variant) -> bool:
	if dialog.is_open():
		if kind != "dialog" or typeof(arg) != TYPE_ARRAY or (arg as Array).size() != 2:
			return false
		return dialog.handle(str(arg[0]), arg[1])
	if kind == "camp":
		if page != "root":
			return false
		camp_requested.emit()
		return true
	match page:
		"root":
			return _dispatch_root(kind, arg)
		"class":
			return _dispatch_class(kind, arg)
		"look":
			return _dispatch_look(kind, arg)
		"manage":
			return _dispatch_manage(kind, arg)
		"manage_menu":
			return _dispatch_menu(kind, arg)
		"form":
			return _dispatch_form(kind, arg)
	return false


func _dispatch_root(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			root_cursor = wrapi(root_cursor + (int(arg) if arg != null else 1), 0, ROOT_KEYS.size())
			_clear_notice()
			return true
		"row":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= ROOT_KEYS.size():
				return false
			if i != root_cursor:
				_clear_notice()
			root_cursor = i
			return _run_root(i)
		"confirm":
			return _run_root(root_cursor)
		"back":
			close_guild()
			return true
	return false


func _run_root(i: int) -> bool:
	match ROOT_KEYS[i]:
		"register":
			page = "class"
			class_cursor = 0
			class_inv.reset(0)
			_clear_notice()
		"manage":
			page = "manage"
			manage_cursor = 0
			roster_inv.reset(0)
			_clear_notice()
		"form":
			page = "form"
			form_focus = "board"
			_load_board()
			board.cursor = 0
			roster_inv.reset(0)
			_clear_notice()
		"talk":
			show_notice(texts.t("guild.why.talk"))
		"leave":
			close_guild()
	return true


func _dispatch_class(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			return class_inv.move(int(arg) if arg != null else 1)
		"row":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= CLASS_ORDER.size():
				return false
			if i == class_cursor:
				return _to_look()
			class_inv.point(class_inv.rows[i])
			return true
		"confirm":
			return _to_look()
		"back":
			page = "root"
			root_cursor = 0
			return true
	return false


func _to_look() -> bool:
	page = "look"
	look_cursor = 0
	_clear_notice()
	return true


func _dispatch_look(kind: String, arg: Variant) -> bool:
	match kind:
		"look":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= GuildRules.LOOKS:
				return false
			if i == look_cursor:
				return _ask_name("register")
			look_cursor = i
			_clear_notice()
			return true
		"look_step":
			var to := clampi(look_cursor + (int(arg) if arg != null else 1), 0, GuildRules.LOOKS - 1)
			if to == look_cursor:
				return false
			look_cursor = to
			_clear_notice()
			return true
		"confirm":
			return _ask_name("register")
		"back":
			page = "class"
			_clear_notice()
			return true
	return false


func _dispatch_manage(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			return roster_inv.move(int(arg) if arg != null else 1)
		"roster":
			var k := int(arg) if arg != null else -1
			if k < 0 or k >= roster_ids.size():
				return false
			roster_inv.point(roster_inv.rows[k])
			return _open_menu()
		"confirm":
			return _open_menu()
		"back":
			page = "root"
			root_cursor = ROOT_KEYS.find("manage")
			_clear_notice()
			return true
	return false


func _open_menu() -> bool:
	if roster_inv.cursor < 0 or roster_inv.cursor >= roster_ids.size():
		return false
	manage_cursor = roster_inv.cursor
	page = "manage_menu"
	menu_cursor = 0
	manage_inv.reset(0)
	_clear_notice()
	return true


func _dispatch_menu(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			return manage_inv.move(int(arg) if arg != null else 1)
		"row":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= MANAGE_KEYS.size():
				return false
			manage_inv.point(manage_inv.rows[i])
			return _run_menu(i)
		"confirm":
			return _run_menu(manage_inv.cursor)
		"back":
			page = "manage"
			_clear_notice()
			return true
	return false


func _run_menu(i: int) -> bool:
	var m := managed_member()
	if m == null:
		return false
	match MANAGE_KEYS[i]:
		"rename":
			return _ask_name("rename")
		"remove":
			if state.party.members.has(m):
				show_notice(texts.t("guild.why.remove_party"))
				return true
			asking = "remove"
			dialog.open_confirm(texts.t("guild.ask_remove", {"name": PartyNames.display_name(texts, m)}), false)
		"back":
			page = "manage"
			_clear_notice()
	return true


## 편성: slot(판 칸)·roster(목록 줄, 0 = 「비우기」)·decide·cursor(±1, 커서가 있는 쪽)·focus(←→: 판 ↔ 목록)·confirm·back.
## 판 칸을 고르면 목록으로 넘어가고, 목록에서 고른 대원이 그 칸에 들어간다(판 위 대원이면 두 칸을 바꾼다).
func _dispatch_form(kind: String, arg: Variant) -> bool:
	match kind:
		"slot":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= FormBoard.SLOTS:
				return false
			board.cursor = i
			return _form_pick_slot(i)
		"roster":
			var k := int(arg) if arg != null else -1
			if k < 0 or k >= roster_ids.size():
				return false
			roster_inv.point(roster_inv.rows[k])
			return _form_put(k)
		"decide":
			board.cursor = FormBoard.DECIDE_AT
			form_focus = "board"
			return _form_decide()
		"cursor":
			if form_focus == "roster":
				return roster_inv.move(int(arg) if arg != null else 1)
			board.cursor = wrapi(board.cursor + (int(arg) if arg != null else 1), 0, FormBoard.SLOTS + 1)
			return true
		"focus":
			if form_focus == "roster":
				form_focus = "board"
				board.held = -1
				return true
			if board.cursor >= FormBoard.SLOTS:
				return false
			return _form_pick_slot(board.cursor)
		"confirm":
			if form_focus == "roster":
				return _form_put(roster_inv.cursor)
			if board.cursor == FormBoard.DECIDE_AT:
				return _form_decide()
			return _form_pick_slot(board.cursor)
		"back":
			if form_focus == "roster":
				form_focus = "board"
				board.held = -1
				return true
			page = "root"
			root_cursor = ROOT_KEYS.find("form")
			_clear_notice()
			return true  # 초안은 버린다
	return false


func _form_pick_slot(i: int) -> bool:
	if form_focus == "roster" and board.held == i:
		form_focus = "board"
		board.held = -1
		return true
	board.held = i
	form_focus = "roster"
	_clear_notice()
	return true


func _form_put(k: int) -> bool:
	if k < 0 or k >= roster_ids.size():
		return false
	if board.held < 0:
		if board.cursor >= FormBoard.SLOTS:
			return false
		board.held = board.cursor
	var at := board.held
	if not board.put(at, roster_ids[k]):
		if not roster_ids[k].is_empty() and board.slot_of(roster_ids[k]) < 0:
			show_notice(texts.t("guild.why.row_full"))
	board.cursor = at
	board.held = -1
	form_focus = "board"
	return true


func _form_decide() -> bool:
	var events := GuildRules.form(state, board.front.duplicate(), board.back.duplicate())
	if _rejected(events):
		return true
	_saved(events)
	page = "root"
	root_cursor = ROOT_KEYS.find("form")
	_setup_cards()
	show_notice(texts.t("guild.formed"))
	return true


# ---- 이름·확인 ----

## 이름 입력을 부탁한다(탐색 화면이 받는다). 등록은 「직업 줄임말 + 가장 작은 빈 번호」, 이름 바꾸기는 지금 이름이 기본값이다.
func _ask_name(why: String) -> bool:
	naming = why
	var m := managed_member() if why == "rename" else null
	name_requested.emit(PartyNames.display_name(texts, m) if m != null else default_name(current_class()))
	return true


## 탐색 화면이 넘겨준 이름(null = 취소). 등록: 규칙 검사 → 확인 창(「예」 먼저). 이름 바꾸기: 바로 규칙(받아들이면 자동 저장).
## 거부하면 안내(두 줄까지)를 띄우고 그 쪽에 남는다(외형 쪽·관리 작은 목록).
func name_entered(v: Variant) -> void:
	if not _open:
		return
	var why := naming
	naming = ""
	if v == null or why.is_empty():
		_refresh()
		return
	var t := str(v).strip_edges()
	if why == "register":
		var block := GuildRules.name_block(state, t, taken_names())
		if not block.is_empty():
			show_notice(texts.t("guild.why." + block))
			_refresh()
			return
		pending_name = t
		asking = "register"
		dialog.open_confirm(texts.t("guild.ask_register", {"name": t, "class": texts.t(current_class())}), true)
		_refresh()
		return
	var m := managed_member()
	if m == null:
		return
	var events := GuildRules.rename(state, m.id, t, taken_names(m.id))
	if not _rejected(events):
		_saved(events)
		_setup_cards()
		show_notice(texts.t("guild.renamed", {"name": t}))
	_refresh()


func _on_answered(yes: bool, _qty: int) -> void:
	var what := asking
	asking = ""
	if not yes:
		pending_name = ""
		return
	match what:
		"register":
			var events := GuildRules.register(state, current_class(), look_cursor, pending_name, taken_names())
			pending_name = ""
			if _rejected(events):
				return
			_saved(events)
			page = "root"
			root_cursor = 0
			show_notice(texts.t("guild.registered", {"name": events[0]["name"]}))
		"remove":
			var m := managed_member()
			if m == null:
				return
			var who := PartyNames.display_name(texts, m)
			var events := GuildRules.remove(state, m.id)
			if _rejected(events):
				return
			_saved(events)
			page = "manage"
			var lines := [texts.t("guild.removed", {"name": who})]
			var n: int = (events[0]["returned"] as Array).size()
			if n > 0:
				lines.append(texts.t("guild.gear_back", {"n": n}))
			show_notice("\n".join(lines))
	_refresh()


func _rejected(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(texts.t("guild.why." + str(events[0]["reason"])))
		return true
	return false


func _saved(events: Array[Dictionary]) -> void:
	if save_hook.is_valid():
		save_hook.call()
	changed.emit(events)


## 다른 대원의 화면 이름(등록한 이름, 기본 다섯은 이름 키 글). except_id 대원은 뺀다.
func taken_names(except_id: String = "") -> Array:
	var out := []
	for m in GuildRules.roster(state):
		if m.id != except_id:
			out.append(PartyNames.display_name(texts, m))
	return out


## 등록 기본 이름: 「직업 줄임말 + n」(가장 작은 빈 n).
func default_name(class_id: String) -> String:
	var taken := taken_names()
	var short := texts.t(short_key(class_id))
	var n := 1
	while taken.has("%s%d" % [short, n]):
		n += 1
	return "%s%d" % [short, n]


static func short_key(class_id: String) -> String:
	return "guild.short." + class_id.trim_prefix("class.")


# ---- 키 ----

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
	if event.is_action_pressed("open_party") and not dialog.is_open():
		if page == "root":
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
	if back:
		return ["back", null]
	if enter:
		return ["confirm", null]
	var num := ShopScreen._number(code)
	match page:
		"root":
			if num >= 0 and num < ROOT_KEYS.size():
				return ["row", num]
		"class":
			if num >= 0 and num < CLASS_ORDER.size():
				return ["row", num]
		"look":
			if num >= 0 and num < GuildRules.LOOKS:
				return ["look", num]
			return ["look_step", dir.x] if dir.x != 0 else []
		"manage_menu":
			if num >= 0 and num < MANAGE_KEYS.size():
				return ["row", num]
		"form":
			if dir.x != 0:
				return ["focus", dir.x]
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


## 키패드 단추마다 켤지: 키 표에 없거나 지금 늘 거부되는 것은 흐림.
func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		var a := key_action(PAD_KEYS[k])
		out[k] = not a.is_empty() and _may_accept(a)
	return out


func _may_accept(a: Array) -> bool:
	if dialog.is_open():
		return true
	match a[0]:
		"look_step":
			return clampi(look_cursor + int(a[1]), 0, GuildRules.LOOKS - 1) != look_cursor
		"focus":
			return form_focus == "roster" or board.cursor < FormBoard.SLOTS
		"cursor":
			match page:
				"class":
					return class_inv.can_move()
				"manage":
					return roster_inv.can_move()
				"form":
					return form_focus == "board" or roster_inv.can_move()
				"manage_menu":
					return manage_inv.can_move()
	return true


func stacked() -> bool:
	return page == "class" or page == "look"


func active_key_pad() -> VirtualPad:
	return key_pad_stacked if stacked() else key_pad


func _place_pads() -> void:
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var ks := VirtualPad.keys_size(false)
	PartyMenu.place(key_pad, Vector2(1, 1), Vector2(1, 1), Vector4(PAD_KEYS_AT.x, PAD_KEYS_AT.y, PAD_KEYS_AT.x + ks.x, PAD_KEYS_AT.y + ks.y))
	var kss := VirtualPad.keys_size(true)
	PartyMenu.place(key_pad_stacked, Vector2(1, 1), Vector2(1, 1),
		Vector4(PAD_KEYS_STACKED.x, PAD_KEYS_STACKED.y, PAD_KEYS_STACKED.x + kss.x, PAD_KEYS_STACKED.y + kss.y))
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

func show_notice(t: String, sec: float = NOTICE_SEC) -> void:
	notice = t
	_notice_left = sec
	_refresh_banner()
	if look_msg != null:
		look_msg.queue_redraw()


func clear_notice() -> void:
	_clear_notice()


func _clear_notice() -> void:
	notice = ""
	_notice_left = 0.0
	_refresh_banner()
	if look_msg != null:
		look_msg.queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()


# ---- 글 ----

func place_text() -> String:
	return texts.t("town.fac.guild")


func money_text() -> String:
	return texts.t("shop.money", {"money": ShopRow.grouped(state.money if state != null else 0)})


func day_text() -> String:
	return texts.t("town.day", {"n": state.day if state != null else 1})


func current_class() -> String:
	return CLASS_ORDER[clampi(class_cursor, 0, CLASS_ORDER.size() - 1)]


func class_name_text() -> String:
	return texts.t(current_class())


## 설명 상자 줄: 직업 설명(문장마다 한 줄, 둘까지) · 「주무기: …」 · 싸우는 자리.
func class_desc_lines() -> Array:
	var cid := current_class()
	var c: BattleDb.ClassDef = state.defs.battle.classes.get(cid) if state != null else null
	if c == null:
		return []
	var out := []
	for s in texts.t(c.desc_key).split(". ", false):
		out.append(s if s.ends_with(".") else s + ".")
	out = out.slice(0, 2)
	var weapon := ""
	for k in c.equip_kinds:
		if BattleLimits.WEAPON_KINDS.has(k):
			weapon = texts.t("equip_kind." + k)
			break
	out.append(texts.t("guild.class.weapon", {"weapon": weapon}))
	out.append(texts.t("guild.role." + cid.trim_prefix("class.")))
	return out


func look_msg_text() -> String:
	return notice if not notice.is_empty() and page == "look" else texts.t("guild.look.msg")


## 관리 쪽 등록부 커서 대원(작은 목록이 떠 있으면 그 대원).
func cursor_member() -> PartyState.Member:
	if page == "manage_menu":
		return managed_member()
	var roster := GuildRules.roster(state)
	var k := roster_inv.cursor
	return roster[k] if k >= 0 and k < roster.size() else null


## 띠 둘째 줄: 「직업 Lv n」(파티 대원이면 「· 파티」).
func member_line(m: PartyState.Member) -> String:
	if m == null:
		return ""
	var t := texts.t("guild.manage.row_right", {"class": texts.t(m.class_id), "level": m.level})
	return t + " · " + texts.t("guild.manage.party") if state.party.members.has(m) else t


## 직업 주무기 종류 아이콘(줄 아이콘 칸).
func weapon_icon(cid: String) -> String:
	return PartyArrangeTab.weapon_icon(state, cid)


func managed_member() -> PartyState.Member:
	var roster := GuildRules.roster(state)
	return roster[manage_cursor] if manage_cursor >= 0 and manage_cursor < roster.size() else null


func row_label(i: int) -> String:
	return "%d  %s" % [i + 1, texts.t("guild.row." + ROOT_KEYS[i])]


func band_lines() -> Array:
	match page:
		"root":
			return [texts.t("guild.desc." + ROOT_KEYS[root_cursor]), ""]
		"manage", "manage_menu":
			return [texts.t("guild.manage.band"), member_line(cursor_member())]
		"form":
			return [texts.t("guild.form.band"), texts.t("guild.form.help_roster" if form_focus == "roster" else "guild.form.help_board")]
	return ["", ""]


## 시작 장비·능력치 판에 쓰는 Lv1 대원(규칙의 profile 이 읽는다, 상태에는 넣지 않는다).
func preview_member(cid: String) -> PartyState.Member:
	var c: BattleDb.ClassDef = state.defs.battle.classes.get(cid)
	var m := PartyState.Member.new("preview")
	m.class_id = cid
	m.level = 1
	m.skills = {}
	m.equip = c.start_equip.duplicate()
	return m


# ---- 그리기 ----

func refresh_view() -> void:
	_refresh()


func _refresh() -> void:
	if not _built or not _open or state == null or covered:
		return
	# 문맥 = 쪽·모든 커서(목록 커서는 InventoryList 의 지금 값: class_cursor 는 아래 _refresh_class 에서야 따라온다)·초점·창·고른 칸.
	# 커서가 바뀌면 누르고 있던 줄·키패드를 버린다(뗄 때 바뀐 커서로 일하지 않게, 마을·캠프와 같다).
	var ctx := "%s|%d|%d|%d|%d|%d|%d|%s|%s|%d" % [page, root_cursor, class_inv.cursor, look_cursor, roster_inv.cursor, manage_inv.cursor,
		board.cursor, form_focus, dialog.mode, board.held]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	var on_root := page == "root"
	var on_class := page == "class"
	var on_look := page == "look"
	var on_roster := page in ["manage", "manage_menu", "form"]
	npc.visible = on_root or on_roster
	cards.visible = on_root
	banner.visible = on_root or on_roster
	money_plate.visible = on_root
	root_list.visible = on_root
	camp_plate.visible = on_root  # 캠프(P)는 뿌리에서만(숙소와 같다)
	for c in [class_plate, class_window, class_sheet, class_desc]:
		(c as Control).visible = on_class
	for c in [look_plate, look_msg, look_portrait]:
		(c as Control).visible = on_look
	for st in strips:
		st.visible = on_look
	roster_window.visible = on_roster
	manage_window.visible = page == "manage_menu"
	board.visible = page == "form"
	camp_plate.show_day(day_text())
	var live := []
	var dim := []
	for i in ROOT_KEYS.size():
		root_list.set_row_text(i, row_label(i))
		live.append(true)
		dim.append(ROOT_DIM.has(ROOT_KEYS[i]))
	root_list.show_rows(root_cursor if on_root else -1, -1, live, dim)
	if on_class:
		_refresh_class()
	if on_look:
		for st in strips:
			st.class_id = current_class()
			st.selected = st.look == look_cursor
			st.queue_redraw()
		for c in [look_plate, look_msg, look_portrait]:
			(c as Control).queue_redraw()
	if on_roster:
		_refresh_roster()
	if page == "manage_menu":
		var rows := []
		var m := managed_member()
		for k in MANAGE_KEYS:
			rows.append({"name": texts.t("guild.manage." + k), "dim": k == "remove" and m != null and state.party.members.has(m)})
		manage_inv.set_rows(rows)
		manage_inv.set_cursor_mode("cursor" if not dialog.is_open() else "chosen")
	if page == "form":
		board.info = PartyArrangeTab.member_info(state, texts)
		board.refresh(form_focus == "board" and not dialog.is_open())
	if cards.visible:
		for c in cards.cards:
			c.queue_redraw()
	money_plate.queue_redraw()
	npc.queue_redraw()
	if backdrop != null:
		backdrop.show_place("guild")
	_refresh_banner()
	_place_pads()
	var on := pad_state()
	for p in [dir_pad, key_pad, key_pad_stacked]:
		(p as VirtualPad).set_enabled(on)


func _refresh_class() -> void:
	var rows := []
	for cid in CLASS_ORDER:
		rows.append({"name": texts.t(cid), "icon": weapon_icon(cid)})
	class_inv.set_rows(rows)
	class_cursor = class_inv.cursor
	for c in [class_plate, class_sheet, class_desc]:
		(c as Control).queue_redraw()


## 등록부 목록: 관리 = 등록부 전부(이름 · 「직업 Lv n」 · 파티면 「파티」), 편성 = 맨 앞 「비우기」 + 등록부(판 위 대원은 흐림 + 「파티」).
func _refresh_roster() -> void:
	var rows := []
	roster_ids.clear()
	var form := page == "form"
	if form:
		roster_ids.append("")
		rows.append({"name": texts.t("guild.form.clear"), "id": ""})
	for m in GuildRules.roster(state):
		roster_ids.append(m.id)
		var c: BattleDb.ClassDef = state.defs.battle.classes.get(m.class_id)
		var in_party := board.slot_of(m.id) >= 0 if form else state.party.members.has(m)
		rows.append({"name": PartyNames.display_name(texts, m), "right": texts.t("guild.manage.party") if in_party else "", "dim": form and in_party,
			"id": m.id, "class": c.id if c != null else "", "icon": weapon_icon(m.class_id)})
	roster_inv.set_rows(rows)
	var mode := "cursor"
	if page == "manage_menu" or (form and form_focus != "roster"):
		mode = "chosen" if page == "manage_menu" else "none"
	roster_inv.set_cursor_mode(mode)


func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	var lines := band_lines()
	if not notice.is_empty() and page != "look":
		var n := notice.split("\n", false)
		if n.size() >= 2:
			banner.show_lines(n[0], n[1], true)
		else:
			banner.show_lines(lines[0], notice, true)
	else:
		banner.show_lines(lines[0], lines[1], false)


func _load_board() -> void:
	var f: Array[String] = []
	var b: Array[String] = []
	for m in state.party.members:
		(f if m.row == "front" else b).append(m.id)
	board.load_draft(f, b)


func _layout() -> void:
	if not _built:
		return
	PartyMenu.place(root_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, ROOT_TOP, FacilityList.WIDTH, ROOT_TOP + FacilityList.content_height(ROOT_KEYS.size(), ROOT_GAP, ROOT_PAD)))
	PartyMenu.place(roster_window, Vector2.ZERO, Vector2.ZERO, Vector4(ROSTER.position.x, ROSTER.position.y, ROSTER.end.x, ROSTER.end.y))
	PartyMenu.place(manage_window, Vector2.ZERO, Vector2.ZERO,
		Vector4(MANAGE_MENU.position.x, MANAGE_MENU.position.y, MANAGE_MENU.end.x, MANAGE_MENU.end.y))
	PartyMenu.place(board, Vector2.ZERO, Vector2.ZERO, Vector4(BOARD_AT.x, BOARD_AT.y, BOARD_AT.x + FormBoard.SIZE.x, BOARD_AT.y + FormBoard.SIZE.y))
	banner.place()
	var s := size if size.x > 0.0 else get_viewport_rect().size
	dialog.set_area(Rect2(Vector2.ZERO, s))
	_place_pads()


## 직업 문패(SheetParts.draw_class_plate: 잎 장식 + 알약).
func _draw_plate(ci: Control) -> void:
	SheetParts.begin(ci)
	var r := Rect2(Vector2.ZERO, ci.size)
	SheetParts.draw_class_plate(ci, Rect2(r.position.x + 40, r.position.y + 4, r.size.x - 80, r.size.y - 8), class_name_text())


## 직업 판(원작 jp_guide1_img2 위 판): 왼쪽 위 「Lv 1」·HP·TP, 그 아래 시작 장비 넷(장비 줄), 오른쪽 능력치 여섯(능력치 줄)과 공격·방어.
func _draw_sheet() -> void:
	var ci := class_sheet
	SheetParts.begin(ci)
	var r := Rect2(Vector2.ZERO, ci.size)
	ListParts.draw_panel(ci, r, "tree")
	if state == null:
		return
	var cid := current_class()
	var m := preview_member(cid)
	var p := GrowthRules.profile(state.defs, -1, m)
	var lx := 16.0
	var lw := r.size.x * 0.46
	SheetParts._text(ci, Vector2(lx, 36), texts.t("party.level", {"level": 1}), 24, Color.WHITE, 90)
	SheetParts._text(ci, Vector2(lx + 100, 30), "HP %d/%d" % [p["max_hp"], p["max_hp"]], 18, Color.WHITE, lw - 100)
	SheetParts._text(ci, Vector2(lx + 100, 54), "TP %d/%d" % [p["max_tp"], p["max_tp"]], 18, Color.WHITE, lw - 100)
	for slot in 4:
		var id: String = m.equip[slot]
		var row := Rect2(lx, 72 + slot * 42, lw - 16, 38)
		SheetParts.draw_equip_row(ci, row, SheetParts.kind_icon(state.defs, id), PartyNames.item_name(state, texts, id) if not id.is_empty() else texts.t("party.slot.empty"), id.is_empty())
	var sx := lx + lw
	var sw := r.size.x - sx - 16
	for k in BattleLimits.STATS.size():
		var stat: String = BattleLimits.STATS[k]
		var v: int = p["stats"][stat]
		SheetParts.draw_stat_row(ci, Rect2(sx, 14 + k * 32, sw, 28), texts.t("stat." + stat), str(v), v / STAT_FULL)
	var gy := 14 + 6 * 32 + 4.0
	var half := (sw - 8) / 2.0
	SheetParts.draw_stat_row(ci, Rect2(sx, gy, half, 28), texts.t("stat.atk"), str(p["gear"]["atk"]), 0.0)
	SheetParts.draw_stat_row(ci, Rect2(sx + half + 8, gy, half, 28), texts.t("stat.def"), str(p["gear"]["def"]), 0.0)


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
		if root_node == self and dialog.is_ancestor_of(b):
			continue
		if clipped_rect(b).size.y <= 0.0:
			continue  # 등록부를 내려야 보이는 줄
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


## 단추의 화면 사각형(이 화면 기준). 끌어 내리는 영역(PartyScroll) 안이면 그 영역으로 자른 부분(상점과 같다).
func clipped_rect(b: Control) -> Rect2:
	var r := Rect2(b.get_global_position() - get_global_position(), b.size)
	var p := b.get_parent()
	while p != null and p != self:
		if p is PartyScroll:
			r = r.intersection(Rect2((p as Control).get_global_position() - get_global_position(), (p as Control).size))
		p = p.get_parent()
	return r


## 디버그 snapshot 의 guild_screen 정보.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	return {
		"open": true, "page": page, "covered": covered, "notice": notice, "band": [banner.head, banner.body],
		"root_cursor": root_cursor, "class": current_class() if page in ["class", "look"] else "", "class_cursor": class_cursor,
		"look": look_cursor, "roster": roster_ids.duplicate() if page in ["manage", "manage_menu", "form"] else [],
		"roster_cursor": roster_inv.cursor, "managed": managed_member().id if page == "manage_menu" and managed_member() != null else "",
		"form": {"front": board.front.duplicate(), "back": board.back.duplicate(), "cursor": board.cursor, "held": board.held,
			"focus": form_focus} if page == "form" else {},
		"asking": asking, "naming": naming, "pad": pad_state(), "buttons": buttons,
		"dialog": {"mode": dialog.mode, "pick": dialog.pick, "text": dialog.message},
	}


## 외형 띠(설계 §5.3, 그림 전 B6 자리표시): 직업색 판(외형 1 은 더 짙게) + 큰 첫 글자 + 모서리 표(A·B). 누르면 그 외형.
## 바탕 채움은 SheetParts 기록에 남는다(시험이 그린 색을 읽는다).
class LookStrip:
	extends TouchButton

	var look := 0
	var class_id := ""

	## 외형 색: 직업색, 외형 1 은 30% 짙게.
	static func color_of(cid: String, lk: int) -> Color:
		var base: Color = BattleCard.CLASS_COLORS.get(cid, Color(0.7, 0.7, 0.7))
		return base.darkened(0.3) if lk == 1 else base

	func _draw() -> void:
		SheetParts.begin(self)
		var r := Rect2(Vector2.ZERO, size)
		var col := color_of(class_id, look)
		SheetParts._fill(self, r, UiTheme.CMD_PLATE)
		SheetParts._fill(self, r.grow(-6.0), col.darkened(0.5))
		SheetParts._log(self, {"kind": "silhouette", "rect": r.grow(-10.0), "color": col})
		MemberPortrait.draw_silhouette(self, r.grow(-10.0), col, "", 1)
		var mark := Rect2(r.end.x - 40, r.position.y + 8, 32, 32)
		SheetParts._fill(self, mark, UiTheme.CMD_PLATE)
		SheetParts._text(self, Vector2(mark.position.x, mark.get_center().y + 20 * 0.36), "AB"[look] if look < 2 else "?", 20, Color.WHITE,
			mark.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var edge := UiTheme.BTN_PICK if selected else UiTheme.CMD_PLATE_EDGE
		UiTheme.draw_outline(self, r.grow(-2.0), edge, 4.0 if selected else 2.0, 0.0)
		SheetParts._log(self, {"kind": "outline", "rect": r.grow(-2.0), "color": edge})
