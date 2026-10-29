## 정보상 바·관리국 화면(M3 A8b, 설계 §6): 창 층 2(길드 뒤, 타이틀 앞). 마을 광장 「정보상 바」·「관리국」에서 연다(길드와 같은 길: 마을 화면을
## 덮고 바탕은 TownBackdrop 의 pub·council 그림). giver = "pub" · "council" 하나로 두 시설을 맡는다. 쪽(page):
##   root(원작 I HD 酒場 jp_facility_img4 · 執政院 jp_facility_img5): 다이얼 자리 캠프 단추 · 띠 두 줄 · 소지금 · 줄 넷(받는다·보고한다·대화(흐림)·
##     나간다) · 주인 자리표시(오른쪽, 장식) · 파티 카드(읽기만).
##   accept(원작 II HD 의뢰 목록 gw_16): 띠·소지금 그대로, 가운데 목록 창(이 시설의 잠기지 않은 의뢰 · 오른쪽 표 NEW·수락 중·달성·n일 뒤·완료) ·
##     아래 말 상자(의뢰인 · 설명 · 목표와 진행 · 보수). 파티 카드는 감춘다.
##   report: 받은 의뢰만(달성 = 「달성」, 못 이룬 것 = 흐림 「진행 n/N」). 보고하면 말 상자가 다음 입력까지 결과(보수·레벨 업)를 보인다.
## 확인 창은 상점 창(ShopDialog): 받기·보고는 「예」 먼저, 포기는 「아니오」 먼저(진행이 사라진다). 상태는 action_hook(탐색 화면의 quest_action:
## 받아들이면 자동 저장 한 번)으로만 바꾸고 받아들여지면 changed 를 낸다. 열기·닫기·커서 이동·거부는 저장하지 않는다.
## 입력 입구 하나(handle): 단추·목록 줄·키보드·가상 키패드가 모두 여기로 온다.
class_name QuestScreen
extends Control

signal opened
signal closed
signal camp_requested
## 규칙이 상태를 바꿨다(저장 갈고리 뒤).
signal changed(events: Array)

const GIVERS := ["pub", "council"]
const ROOT_KEYS := ["accept", "report", "talk", "leave"]
const ROOT_DIM := ["talk"]
## 뿌리 목록: 길드와 같은 x 0~430, y 166~(줄 넷이 방향 십자 y 511 위에 든다).
const ROOT_TOP := 166.0
const ROOT_GAP := 3.0
const ROOT_PAD := 3.0
const MONEY_PLATE := Rect2(0, 112, 340, 50)
const NPC_W := 560.0
## 의뢰 목록 창(gw_16: 소지금 문패 아래 가운데). 폭 760, 줄 넷(이 묶음은 시설마다 셋까지, 넘으면 끌어 내린다).
const LIST_W := 760.0
const LIST_TOP := 172.0
const LIST_ROWS := 4
## 말 상자(gw_16 아래 상자): 아래 앵커. 왼쪽은 방향 십자(x 8~208) 오른쪽, 오른쪽은 선택·취소 키패드(W − 247~) 왼쪽에서 끝난다.
const BOX_LEFT := 216.0
const BOX_RIGHT := 256.0
const BOX_H := 232.0
const BOX_BOTTOM := 16.0
const NOTICE_SEC := 2.5
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 목록 줄 아이콘 칸 = 목표 종류(있는 벡터 아이콘).
const KIND_ICONS := {"kill": "kind_sword", "foe": "foe", "deliver": "gather", "reach": "pin"}
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_AT := Vector2(-247, -293)

# ---- 바깥에서 정하는 값 ----
var blocked_hook: Callable
## (kind: accept·abandon·report, id, giver) → 이벤트 목록. 탐색 화면의 quest_action(받아들이면 자동 저장 한 번).
var action_hook: Callable
var backdrop: TownArt.TownBackdrop

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
var giver := "pub"
## root · accept · report
var page := "root"
var root_cursor := 0
## 확인 창이 묻는 일: "" · accept · abandon · report
var asking := ""
## 확인 창이 묻는 의뢰 ID.
var asking_id := ""
## 보고 결과(말 상자가 다음 입력까지 보인다): {title, lines}. 비면 보통 말 상자.
var result := {}
var notice := ""
var covered := false
var accepted_inputs := 0

# ---- 부품 ----
var npc: Control
var cards: PartyCards
var banner: FacilityBanner
var money_plate: Control
var root_list: FacilityList
var list_window: ListWindow
var list_inv: InventoryList
var box: Control
var camp_plate: TownPlate
var dialog: ShopDialog
var dir_pad: VirtualPad
var key_pad: VirtualPad
## 목록 줄의 의뢰 ID(줄 차례 = 자료 차례).
var list_ids: Array[String] = []
var _notice_left := 0.0
var _built := false
var _open := false
var _input_frame := -1
## 누르기 지킴이(PressGuard, M3 A7d): 고름 값(selection_key)이 바뀌면 눌림을 버리고, 누를 때와 뗄 때 값이 다르면 일하지 않는다.
var press_guard := PressGuard.new(self)


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 뒤의 마을 바탕·HUD 에 포인터가 닿지 않게
	focus_mode = FOCUS_NONE
	visible = false


## 트리 순서 = 그리는·누르는 순서(설계 §6.3 층 표): 주인(장식) → 카드 → 띠 → 소지금 → 뿌리 목록 → 의뢰 목록 창 → 말 상자 → 캠프 단추 →
## 확인 창(어두운 판이 아래를 막는다) → 키패드(맨 위).
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	npc = _deco("QuestNpc", Vector2(1, 0), Vector2(1, 1), Vector4(-NPC_W, 0, 0, 0))
	npc.draw.connect(func() -> void: TownArt.paint(npc, Rect2(Vector2.ZERO, npc.size), "npc_" + giver))
	cards = PartyCards.new()
	cards.name = "QuestCards"
	add_child(cards)
	PartyMenu.place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	banner = FacilityBanner.new()
	banner.name = "QuestBanner"
	add_child(banner)
	banner.place()
	money_plate = _deco("QuestMoney", Vector2.ZERO, Vector2.ZERO,
		Vector4(MONEY_PLATE.position.x, MONEY_PLATE.position.y, MONEY_PLATE.end.x, MONEY_PLATE.end.y))
	money_plate.draw.connect(func() -> void: ShopFrame.paint_title(money_plate, money_text(), true))
	root_list = FacilityList.new()
	root_list.name = "QuestRoot"
	root_list.row_gap = ROOT_GAP
	root_list.inner_pad = ROOT_PAD
	add_child(root_list)
	var items := []
	for k in ROOT_KEYS:
		items.append({"name": "Quest_" + k, "text": ""})
	root_list.set_items(items)
	root_list.pressed.connect(func(i: int) -> void: handle("row", i))
	list_window = ListWindow.new()
	list_window.name = "QuestListWindow"
	add_child(list_window)
	list_window.list.name = "QuestList"
	list_inv = InventoryList.new(list_window.list, InventoryLook.new(), "QuestRow_")
	list_inv.route = func(k: int) -> void: handle("quest", k)
	box = _deco("QuestBox", Vector2(0, 1), Vector2(1, 1), Vector4(BOX_LEFT, -BOX_BOTTOM - BOX_H, -BOX_RIGHT, -BOX_BOTTOM))
	box.draw.connect(_draw_box)
	camp_plate = TownPlate.new()
	add_child(camp_plate)
	camp_plate.setup("", texts.t("town.camp"))
	camp_plate.name = "QuestPlate"
	PartyMenu.place(camp_plate, Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, TownPlate.SIZE.x, TownPlate.SIZE.y))
	camp_plate.activated.connect(func() -> void: handle("camp"))
	dialog = ShopDialog.new()
	dialog.name = "QuestDialog"
	add_child(dialog)
	dialog.setup(texts)
	dialog.route = func(kind: String, arg: Variant) -> void: handle("dialog", [kind, arg])
	dialog.answered.connect(_on_answered)
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	key_pad = VirtualPad.new().setup_keys(texts.t("battle.ui.pad_ok"), texts.t("battle.ui.pad_back"))
	key_pad.name = "KeyPad"
	for p in [dir_pad, key_pad]:
		add_child(p)
		(p as VirtualPad).pressed.connect(_on_vpad)
	_layout()


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


## 연다(광장 「정보상 바」 = pub · 「관리국」 = council): 뿌리, 커서 0, 안내 없음.
func open(s: ExplorationState, who: String) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null or not GIVERS.has(who):
		return
	state = s
	giver = who
	page = "root"
	root_cursor = 0
	asking = ""
	asking_id = ""
	result = {}
	dialog.close()
	covered = false
	_clear_notice()
	_open = true
	visible = true
	_setup_cards()
	cancel_pointers()
	press_guard.reset()
	list_inv.reset(0)
	_layout()
	_refresh()
	opened.emit()


func close_quest(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	covered = false
	asking = ""
	asking_id = ""
	result = {}
	dialog.close()
	_clear_notice()
	cancel_pointers()
	if notify:
		closed.emit()


## 캠프가 위에 열린 동안 감춘다. 걷으면 쪽·커서 그대로(캠프에서 대열·경험치가 바뀌었을 수 있어 카드를 다시 만든다).
func set_covered(on: bool) -> void:
	if not _open:
		return
	covered = on
	visible = not on
	cancel_pointers()
	if not on:
		_setup_cards()
		_refresh()


## 고름 값(PressGuard, M3 A7d) = 쪽·시설·뿌리 커서·목록 커서(InventoryList 의 지금 값)·목록 줄의 의뢰 ID·창의 답.
func selection_key() -> Array:
	if not _built or not _open:
		return []
	return [page, giver, root_cursor, list_inv.cursor, list_ids.duplicate(), dialog.key_part()]


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
		c.mouse_filter = MOUSE_FILTER_IGNORE  # 시설의 카드는 읽기만
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
	var had_result := not result.is_empty() and not dialog.is_open()
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = f
		accepted_inputs += 1
		if had_result:
			result = {}  # 보고 결과는 다음 입력까지(§6.4). 보고는 확인 창 안의 입력이라 그 입력이 결과를 지우지 않는다
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
		"accept", "report":
			return _dispatch_list(kind, arg)
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
			close_quest()
			return true
	return false


func _run_root(i: int) -> bool:
	match ROOT_KEYS[i]:
		"accept", "report":
			page = ROOT_KEYS[i]
			result = {}
			list_inv.reset(0)
			_clear_notice()
		"talk":
			show_notice(texts.t("quest.why.talk"))
		"leave":
			close_quest()
	return true


func _dispatch_list(kind: String, arg: Variant) -> bool:
	match kind:
		"cursor":
			return list_inv.move(int(arg) if arg != null else 1)
		"quest":
			var k := int(arg) if arg != null else -1
			if k < 0 or k >= list_ids.size():
				return false
			list_inv.point(list_inv.rows[k])
			return _pick(k)
		"confirm":
			return _pick(list_inv.cursor)
		"back":
			root_cursor = ROOT_KEYS.find(page)
			page = "root"
			result = {}
			_clear_notice()
			return true
	return false


## 줄 k 를 골랐다. 받는 쪽: 받을 수 있음 → 받기 확인(예 먼저) · 받은 정보상 바 의뢰 → 포기 확인(아니오 먼저) · 받은 임무 → 이유 ·
## 식는 중·완료 → 이유. 보고 쪽: 달성 → 보고 확인(예 먼저) · 못 이룸 → 이유.
func _pick(k: int) -> bool:
	if k < 0 or k >= list_ids.size():
		return false
	var id := list_ids[k]
	var q := state.defs.quests.get_def(id)
	var st := QuestRules.status_of(state, q)
	if page == "report":
		if st != QuestRules.DONE:
			show_notice(texts.t("quest.why.not_done"))
			return true
		var ask := texts.t("quest.ask.report." + giver)
		if q.kind == "deliver":
			ask += "\n" + texts.t("quest.ask.deliver", {"item": PartyNames.item_name(state, texts, q.target), "n": q.count})
		_ask("report", id, ask, true)
		return true
	match st:
		QuestRules.AVAILABLE:
			_ask("accept", id, texts.t("quest.ask.accept." + giver), true)
		QuestRules.ACCEPTED, QuestRules.DONE:
			if q.giver == "council":
				show_notice(texts.t("quest.why.no_abandon"))
			else:
				_ask("abandon", id, texts.t("quest.ask.abandon"), false)
		QuestRules.COOLING:
			show_notice(texts.t("quest.why.cooling", {"n": QuestRules.opens_on(state, q) - state.day}))
		QuestRules.FINISHED:
			show_notice(texts.t("quest.why.finished"))
	return true


func _ask(what: String, id: String, text: String, yes_first: bool) -> void:
	asking = what
	asking_id = id
	_clear_notice()
	dialog.open_confirm(text, yes_first)


func _on_answered(yes: bool, _qty: int) -> void:
	var what := asking
	var id := asking_id
	asking = ""
	asking_id = ""
	if not yes or what.is_empty():
		return
	var events: Array[Dictionary] = action_hook.call(what, id, giver) if action_hook.is_valid() else [{"type": "rejected", "reason": "busy"}]
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(texts.t("quest.why." + str(events[0]["reason"])))
		return
	changed.emit(events)
	var title := quest_name(id)
	match what:
		"accept":
			show_notice(texts.t("quest.accepted." + giver, {"quest": title}))
		"abandon":
			show_notice(texts.t("quest.abandoned", {"quest": title}))
		"report":
			result = {"title": texts.t("quest.result.head"), "lines": result_lines(events)}
			_setup_cards()
			show_notice(texts.t("quest.reported"))
	_refresh()


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
	if page == "root" and num >= 0 and num < ROOT_KEYS.size():
		return ["row", num]
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
		"cursor":
			return page == "root" or list_inv.can_move()
		"confirm":
			return page == "root" or (list_inv.cursor >= 0 and list_inv.cursor < list_ids.size())
	return true


func _place_pads() -> void:
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var ks := VirtualPad.keys_size(false)
	PartyMenu.place(key_pad, Vector2(1, 1), Vector2(1, 1), Vector4(PAD_KEYS_AT.x, PAD_KEYS_AT.y, PAD_KEYS_AT.x + ks.x, PAD_KEYS_AT.y + ks.y))


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

func place_text() -> String:
	return texts.t("town.fac." + giver)


func money_text() -> String:
	return texts.t("shop.money", {"money": ShopRow.grouped(state.money if state != null else 0)})


func day_text() -> String:
	return texts.t("town.day", {"n": state.day if state != null else 1})


func quest_name(id: String) -> String:
	var q := state.defs.quests.get_def(id) if state != null else null
	return texts.t(q.name_key) if q != null else ""


func row_label(i: int) -> String:
	var k: String = ROOT_KEYS[i]
	var key := "quest.row." + giver + "." + k if k in ["accept", "report"] else "quest.row." + k
	return "%d  %s" % [i + 1, texts.t(key)]


func band_lines() -> Array:
	match page:
		"root":
			var k: String = ROOT_KEYS[root_cursor]
			return [texts.t("quest.desc." + giver + "." + k if k in ["accept", "report"] else "quest.desc." + k), ""]
		"accept":
			return [texts.t("quest.band.accept." + giver), ""]
		"report":
			return [texts.t("quest.band.report." + giver), ""]
	return ["", ""]


## 목록에 보일 의뢰(자료 차례): 받는 쪽 = 이 시설의 잠기지 않은 의뢰, 보고 쪽 = 이 시설의 받은 의뢰.
func visible_ids() -> Array[String]:
	var out: Array[String] = []
	if state == null:
		return out
	for id in QuestRules.ids_of(state, giver):
		var q: QuestDb.QuestDef = state.defs.quests.quests[id]
		if page == "report":
			if state.quests.is_accepted(id):
				out.append(id)
		elif QuestRules.status_of(state, q) != QuestRules.LOCKED:
			out.append(id)
	return out


## 오른쪽 표와 흐림(§6.2): NEW(기록 없음) · 수락 중 · 달성 · n일 뒤(흐림) · 완료(흐림). 보고 쪽의 못 이룬 줄은 「진행 n/N」(흐림).
func mark_of(id: String) -> Array:
	var q := state.defs.quests.get_def(id)
	match QuestRules.status_of(state, q):
		QuestRules.AVAILABLE:
			return [texts.t("quest.mark.new") if QuestRules.is_new(state, q) else "", false]
		QuestRules.ACCEPTED:
			if page == "report":
				return [texts.t("quest.mark.progress", {"n": QuestRules.progress_of(state, q), "target": q.count}), true]
			return [texts.t("quest.mark.accepted"), false]
		QuestRules.DONE:
			return [texts.t("quest.mark.done"), false]
		QuestRules.COOLING:
			return [texts.t("quest.mark.cooling", {"n": QuestRules.opens_on(state, q) - state.day}), true]
		QuestRules.FINISHED:
			return [texts.t("quest.mark.finished"), true]
	return ["", false]


## 목표 글(「목표: …  진행 n/N」, deliver 는 「가진 수 k/N」).
func goal_text(q: QuestDb.QuestDef) -> String:
	var what := ""
	match q.kind:
		"kill":
			what = texts.t("quest.goal.kill", {"enemy": texts.t(state.defs.battle.enemies[q.target].name_key), "n": q.count})
		"foe":
			what = texts.t("quest.goal.foe", {"foe": foe_name(q.target), "n": q.count})
		"deliver":
			what = texts.t("quest.goal.deliver", {"item": PartyNames.item_name(state, texts, q.target), "n": q.count})
		"reach":
			what = texts.t("quest.goal.reach", {"where": texts.t(q.where_key)})
	var key := "quest.ui.goal_have" if q.kind == "deliver" else "quest.ui.goal"
	return texts.t(key, {"goal": what, "n": QuestRules.progress_of(state, q), "target": q.count})


## FOE 정의 ID 의 이름(그 무리 적 하나의 이름, FoeLook.name_of 와 같은 길. 층 자리가 아니라 정의에서 찾는다). 모르면 id.
func foe_name(foe_def: String) -> String:
	var fd: BattleDb.FoeDef = state.defs.battle.foe(foe_def)
	var f: BattleDb.FormationDef = state.defs.battle.formations.get(fd.formation) if fd != null else null
	if f == null or f.enemies.size() != 1:
		return foe_def
	return texts.t(state.defs.battle.enemies[f.enemies[0]["enemy"]].name_key)


## 보수 글(「보수: 100엔 · 메디카 2 · 경험치 30 · B2F 탐사 허가」, 반복이면 「 · 반복: 하룻밤 뒤」).
func reward_text(q: QuestDb.QuestDef) -> String:
	var parts := []
	if q.money > 0:
		parts.append(texts.t("quest.ui.money", {"money": ShopRow.grouped(q.money)}))
	for r in q.items:
		parts.append(texts.t("quest.ui.item", {"item": PartyNames.item_name(state, texts, r["item"]), "n": r["count"]}))
	if q.exp > 0:
		parts.append(texts.t("quest.ui.exp", {"exp": q.exp}))
	for f in q.flags:
		parts.append(texts.t("quest.flag." + f))
	var t := texts.t("quest.ui.reward", {"list": " · ".join(parts)})
	if q.repeats():
		t += " · " + texts.t("quest.ui.repeat_1" if q.repeat_days == 1 else ("quest.ui.repeat_0" if q.repeat_days == 0 else "quest.ui.repeat_n"),
			{"n": q.repeat_days})
	return t


## 말 상자의 [제목, 줄]. 결과가 있으면 결과, 목록이 비면 「지금은 의뢰가 없다」, 아니면 커서 의뢰: 제목 = 의뢰인, 줄 = 설명(남는 줄에 접어
## 넣는다) · 목표 · 보수.
func box_model() -> Array:
	if not result.is_empty():
		return [str(result["title"]), (result["lines"] as Array).duplicate()]
	var id := cursor_id()
	if id.is_empty():
		return ["", [texts.t("quest.ui.empty." + page + "." + giver)]]
	var q := state.defs.quests.get_def(id)
	return [texts.t(q.client_key), [texts.t(q.desc_key), goal_text(q), reward_text(q)]]


func cursor_id() -> String:
	var k := list_inv.cursor
	return list_ids[k] if page != "root" and k >= 0 and k < list_ids.size() else ""


## 보고 결과 줄(§6.4, 말 상자 줄 넷까지): 돈·물건 → 허가 → 경험치 → 대원(레벨 업 · 쓰러짐 · 상한).
## 경험치 줄은 의뢰에 정한 보수(대원 하나를 대표로 쓰지 않는다: 차례를 바꿔도 같다), 상한에 걸려 덜 받은 대원은 같은 줄에 「상한 이름 n, …」.
## 넘치면 ① 레벨 업을 한 줄로 ② 못 받은 대원을 한 줄로(까닭별로 묶어 이름마다 까닭이 남는다) ③ 머리 줄을 위에서부터 둘씩 합친다.
func result_lines(events: Array[Dictionary]) -> Array:
	var rep: Dictionary = events.back()
	var q := state.defs.quests.get_def(str(rep["quest"]))
	var gains := []
	if int(rep["money"]) > 0:
		gains.append(texts.t("quest.ui.money", {"money": ShopRow.grouped(int(rep["money"]))}))
	for r in rep["items"]:
		gains.append(texts.t("quest.result.item", {"item": PartyNames.item_name(state, texts, r["item"]), "n": r["count"]}))
	var head := []
	if not gains.is_empty():
		head.append(" · ".join(gains))
	for f in rep["flags"]:
		head.append(texts.t("quest.result.flag", {"flag": texts.t("quest.flag." + f)}))
	var ups := []
	var cut := []
	var down := []
	var capped := []
	var full_misses := []
	for r in rep["members"]:
		var nm := PartyNames.display_name(texts, state.party.members[int(r["member"])])
		match str(r["status"]):
			"down":
				down.append(nm)
				full_misses.append(texts.t("quest.result.down", {"name": nm}))
			"at_cap":
				capped.append(nm)
				full_misses.append(texts.t("quest.result.cap", {"name": nm}))
			_:
				if int(r["gained"]) < q.exp:
					cut.append("%s %d" % [nm, int(r["gained"])])
		if int(r["to"]) > int(r["from"]):
			ups.append([nm, int(r["to"])])
	if q.exp > 0:
		var exp_line := texts.t("quest.result.exp", {"exp": q.exp})
		if not cut.is_empty():
			exp_line += " · " + texts.t("quest.result.cut", {"list": ", ".join(cut)})
		head.append(exp_line)
	var up_lines := []
	for u in ups:
		up_lines.append(texts.t("quest.result.level", {"name": u[0], "level": u[1]}))
	var misses := full_misses
	if head.size() + up_lines.size() + misses.size() > ListParts.DESC_LINES and ups.size() > 1:
		var parts := []
		for u in ups:
			parts.append("%s %d" % u)
		up_lines = [texts.t("quest.result.levels", {"list": ", ".join(parts)})]
	if head.size() + up_lines.size() + misses.size() > ListParts.DESC_LINES and misses.size() > 1:
		var why := []
		if not down.is_empty():
			why.append(texts.t("quest.result.why_down", {"list": ", ".join(down)}))
		if not capped.is_empty():
			why.append(texts.t("quest.result.why_cap", {"list": ", ".join(capped)}))
		misses = [texts.t("quest.result.no_exp", {"list": " · ".join(why)})]
	while head.size() + up_lines.size() + misses.size() > ListParts.DESC_LINES and head.size() > 1:
		head = [head[0] + " · " + head[1]] + head.slice(2)
	return head + up_lines + misses


# ---- 그리기 ----

func refresh_view() -> void:
	_refresh()


func _refresh() -> void:
	if not _built or not _open or state == null or covered:
		return
	var on_root := page == "root"
	cards.visible = on_root
	root_list.visible = on_root
	camp_plate.visible = on_root  # 캠프(P)는 뿌리에서만(숙소·길드와 같다)
	list_window.visible = not on_root
	box.visible = not on_root
	camp_plate.show_day(day_text())
	var live := []
	var dim := []
	for i in ROOT_KEYS.size():
		root_list.set_row_text(i, row_label(i))
		live.append(true)
		dim.append(ROOT_DIM.has(ROOT_KEYS[i]))
	root_list.show_rows(root_cursor if on_root else -1, -1, live, dim)
	if not on_root:
		_refresh_list()
		box.queue_redraw()
	if cards.visible:
		for c in cards.cards:
			c.queue_redraw()
	money_plate.queue_redraw()
	npc.queue_redraw()
	if backdrop != null:
		backdrop.show_place(giver)
	_refresh_banner()
	_place_pads()
	var on := pad_state()
	for p in [dir_pad, key_pad]:
		(p as VirtualPad).set_enabled(on)
	# 고름 값(selection_key)이 바뀌었으면 앞 값에서 시작한 누르기를 버린다. 맨 끝: 줄을 다시 만들고 커서를 맞춘 뒤의 값과 견준다(A7d 규칙).
	press_guard.sync()


## 목록 줄: 아이콘(목표 종류) · 이름 · 오른쪽 표 · 흐림(식는 중·완료·보고 쪽의 못 이룬 의뢰).
func _refresh_list() -> void:
	list_ids = visible_ids()
	var rows := []
	for id in list_ids:
		var m := mark_of(id)
		rows.append({"name": quest_name(id), "right": m[0], "dim": m[1], "id": id, "icon": KIND_ICONS[state.defs.quests.get_def(id).kind]})
	list_inv.set_rows(rows)
	list_inv.set_cursor_mode("cursor" if not dialog.is_open() else "chosen")


func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	var lines := band_lines()
	if not notice.is_empty():
		var n := notice.split("\n", false)
		if n.size() >= 2:
			banner.show_lines(n[0], n[1], true)
		else:
			banner.show_lines(lines[0], notice, true)
	else:
		banner.show_lines(lines[0], lines[1], false)


func _layout() -> void:
	if not _built:
		return
	PartyMenu.place(root_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, ROOT_TOP, FacilityList.WIDTH, ROOT_TOP + FacilityList.content_height(ROOT_KEYS.size(), ROOT_GAP, ROOT_PAD)))
	var lh := ListParts.list_height(LIST_ROWS)
	PartyMenu.place(list_window, Vector2(0.5, 0), Vector2(0.5, 0), Vector4(-LIST_W / 2.0, LIST_TOP, LIST_W / 2.0, LIST_TOP + lh))
	banner.place()
	var s := size if size.x > 0.0 else get_viewport_rect().size
	dialog.set_area(Rect2(Vector2.ZERO, s))
	_place_pads()


## 말 상자(ListParts.draw_desc): 제목 = 의뢰인(결과면 「보수를 받았다」). 설명은 목표·보수 앞의 남는 줄에 낱말 단위로 접어 넣는다.
func _draw_box() -> void:
	SheetParts.begin(box)
	var r := Rect2(Vector2.ZERO, box.size)
	var m := box_model()
	var lines: Array = m[1]
	if result.is_empty() and not cursor_id().is_empty():
		var tail := lines.slice(1)
		var room := ListParts.DESC_LINES - tail.size()
		lines = wrap_text(str(lines[0]), ListParts.line_room(r), room) + tail
	ListParts.draw_desc(box, r, str(m[0]), "", lines)


## t 를 폭 w 안에 낱말 단위로 많아야 n 줄로 접는다(마지막 줄에 나머지를 모두 넣는다: 넘치면 draw_desc 가 글씨를 줄인다).
func wrap_text(t: String, w: float, n: int) -> Array:
	var words := t.split(" ", false)
	var out := []
	var cur := ""
	for i in words.size():
		var next := words[i] if cur.is_empty() else cur + " " + words[i]
		if out.size() < n - 1 and not cur.is_empty() and SheetParts.text_width(box, next, ListParts.DESC_FS) > w:
			out.append(cur)
			cur = words[i]
		else:
			cur = next
	if not cur.is_empty():
		out.append(cur)
	return out


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
			continue
		out.append(b)
	for p in [dir_pad, key_pad]:
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


## 디버그 snapshot 의 quest_screen 정보.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	var rows := []
	if page != "root":
		for id in list_ids:
			var m := mark_of(id)
			rows.append({"id": id, "mark": m[0], "dim": m[1]})
	var bm := box_model()
	return {
		"open": true, "giver": giver, "page": page, "covered": covered, "notice": notice, "band": [banner.head, banner.body],
		"root_cursor": root_cursor, "rows": rows, "cursor": list_inv.cursor if page != "root" else -1,
		"box": {"title": bm[0], "lines": bm[1]}, "result": not result.is_empty(),
		"asking": asking, "asking_id": asking_id, "pad": pad_state(), "buttons": buttons,
		"dialog": {"mode": dialog.mode, "pick": dialog.pick, "text": dialog.message},
	}
