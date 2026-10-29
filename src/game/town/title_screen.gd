## 타이틀 화면(M3 A2, 원작 I HD 타이틀 man_2: 로고 아래 짧은 알약 세로 줄, 커서 줄은 노랑). 창 층 2 의 맨 끝 자식이라 위에 덮는다.
## 제 바탕(TownArt "title", 불투명)을 그려 뒤의 탐색 화면이 보이지 않는다. 열린 동안 탐색 화면은 상태가 없다(state == null).
## 쪽(page): menu(이어하기·불러오기·새 게임·설정) → load(기록 판: 슬롯 「불러오기」와 「가져오기」만) · settings(기록 판: 자동 지도만).
## 기록 판은 캠프와 같은 PartyRecordsTab 이다(D28): 이 화면이 그 주인(texts·records·state·handle·open_dialog)이다.
## 일(이어하기·새 게임·불러오기·가져오기·자동 지도)은 탐색 화면이 actions·records 갈고리로 준다. 상태가 정해지면 탐색 화면이 이 화면을 닫는다.
## 입력 입구 하나(07 §9.4): 단추·키보드·가상 키패드가 모두 handle() 로 온다. 층 3 창이 떠 있으면(blocked_hook) 받지 않고 한 프레임에 하나만.
class_name TitleScreen
extends Control

signal opened
signal closed

## 메뉴 줄(이어하기는 자동 저장을 읽을 수 있을 때만).
const MENU_KEYS := ["continue", "load", "new_game", "settings"]
const MENU_NAMES := {"continue": "TitleContinue", "load": "TitleLoad", "new_game": "TitleNewGame", "settings": "TitleSettings"}
## 메뉴 알약: 360×64, 사이 8, 가운데, 첫 줄 위 y 380(§5.1).
const PILL := Vector2(360, 64)
const PILL_GAP := 8.0
const MENU_TOP := 380.0
## 로고(가운데 y 150~230)와 팬게임 안내(아래 가운데 y 680~704).
const LOGO_Y := 150.0
const LOGO_H := 80.0
const LOGO_FS := 64
const NOTICE_BOTTOM := 16.0
const NOTICE_H := 24.0
const NOTICE_FS := 18
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 키패드 자리: 십자 왼쪽 아래(캠프와 같다), 메뉴는 「취소」「선택」 가로(W − 247, H − 293), 기록 판은 캠프 기록과 같은 세로.
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_MENU := Vector2(-247, -293)

# ---- 바깥에서 정하는 값 ----
var blocked_hook: Callable
## 메뉴의 일: continue(자동 저장 이어하기)·new_game(마을에서 새 게임).
var actions := {}
## 기록 판 갈고리(캠프 records 와 같은 열쇠): slots·load·import·automap·set_automap.
var records := {}

# ---- 상태 ----
var texts: TextDb
## 기록 판 주인 규약(PartyRecordsTab 이 읽는다): 타이틀에는 탐색 상태가 없다.
var state: ExplorationState = null
## menu · load · settings
var page := "menu"
var cursor := 0
## 지금 보이는 메뉴 줄(MENU_KEYS 차례 가운데 보이는 것).
var rows: Array[String] = []
var can_continue := false
var accepted_inputs := 0

# ---- 부품 ----
var menu_buttons := {}
var records_tab: PartyRecordsTab
var ribbon: PlaceRibbon
var dialog: ConfirmBand
var dir_pad: VirtualPad
var key_pad: VirtualPad
var key_pad_stacked: VirtualPad
var _after: Callable
var _built := false
var _open := false
var _input_frame := -1
## 누르기 지킴이(PressGuard, M3 A7d): 고름 값(selection_key)이 바뀌면 눌림을 버리고, 누를 때와 뗄 때 값이 다르면 일하지 않는다.
var press_guard := PressGuard.new(self)


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 바탕이 아래 화면을 모두 가린다(누르기도)
	focus_mode = FOCUS_NONE
	visible = false


## 트리 순서 = 그리는·누르는 순서: (바탕·로고는 _draw) → 메뉴 알약 → 장소 띠 → 기록 판 → 확인 창(어두운 판이 아래를 막는다) → 키패드(맨 위).
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	for k in MENU_KEYS:
		var b := ListButton.new()
		b.name = MENU_NAMES[k]
		b.text = texts.t("title." + k)
		b.style = "pill"
		b.look = "option"
		add_child(b)
		b.activated.connect(func() -> void: handle("row", rows.find(k)))
		menu_buttons[k] = b
	ribbon = PlaceRibbon.new()
	ribbon.name = "TitleRibbon"
	add_child(ribbon)
	PartyMenu.place(ribbon, Vector2.ZERO, Vector2(1, 0), Vector4(PartyMenu.RIBBON_X, 0, -16, PartyMenu.RIBBON_H))
	records_tab = PartyRecordsTab.new()
	records_tab.name = "TitleRecords"
	add_child(records_tab)
	records_tab.setup(self, "title_load")
	dialog = ConfirmBand.new()
	add_child(dialog)
	dialog.route = func(i: int) -> void: handle("dialog_pick", i)
	_build_pads()  # 키패드는 확인 창 위(§5.1 층 5·6, 캠프와 같다): 창의 어두운 판이 키패드 누르기를 먹지 않는다
	_layout()


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


## 연다: 메뉴 쪽, 커서는 첫 줄. continue_ok 이면 「이어하기」가 첫 줄이다.
func open(continue_ok: bool) -> void:
	assert(_built, "build() 를 먼저 부른다")
	can_continue = continue_ok
	rows.clear()
	for k in MENU_KEYS:
		if k != "continue" or can_continue:
			rows.append(k)
	page = "menu"
	cursor = 0
	dialog.close()
	_after = Callable()
	_open = true
	visible = true
	cancel_pointers()
	press_guard.reset()
	_layout()
	_refresh()
	opened.emit()


func close_title(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	dialog.close()
	_after = Callable()
	cancel_pointers()
	if notify:
		closed.emit()


## 고름 값(PressGuard, M3 A7d): 쪽·메뉴 커서·확인 띠(떠 있는지·고름), 기록 쪽이면 기록 판의 커서 줄·칸(불러올 슬롯).
func selection_key() -> Array:
	if not _built or not _open:
		return []
	var menu := page == "menu"
	return [page, cursor if menu else -1, dialog.key_part(), [] if menu else records_tab.key_part()]


func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()


# ---- 입력 입구 ----

## 메뉴: row(줄 번호)·cursor(±1, 감김)·confirm. 기록 판: PartyRecordsTab 의 입력(cursor·cursor_x·confirm·record_*)·back(메뉴로).
## 확인 창: dialog_move(±1)·dialog_pick(0·1)·dialog_ok·dialog_back.
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
		match kind:
			"dialog_move":
				dialog.move(int(arg))
				return true
			"dialog_pick":
				return _choose(int(arg))
			"dialog_ok":
				return _choose(dialog.pick)
			"dialog_back":
				return _choose(0)
		return false
	if page == "menu":
		match kind:
			"cursor":
				cursor = wrapi(cursor + (int(arg) if arg != null else 1), 0, rows.size())
				return true
			"row":
				var i := int(arg) if arg != null else -1
				if i < 0 or i >= rows.size():
					return false
				cursor = i
				return _run(i)
			"confirm":
				return _run(cursor)
		return false
	if kind == "back":
		page = "menu"
		return true
	return records_tab.dispatch(kind, arg)


## 메뉴 줄: 이어하기 → 탐색 화면, 불러오기·설정 → 기록 판, 새 게임 → (이어할 진행이 있으면 확인 창) → 탐색 화면.
func _run(i: int) -> bool:
	match rows[i]:
		"continue":
			_call_action("continue")
		"load", "settings":
			page = rows[i]
			records_tab.set_rows("title_load" if page == "load" else "title_settings")
			records_tab.member_changed()  # 슬롯을 새로 읽는다
		"new_game":
			if can_continue:
				open_dialog("new_game", actions.get("new_game", Callable()))
			else:
				_call_action("new_game")
	return true


func _call_action(k: String) -> void:
	var c: Callable = actions.get(k, Callable())
	if c.is_valid():
		c.call()


## 기록 판 주인 규약: 확인 창을 띄운다(타이틀은 새 게임 확인 하나, 처음 커서 「돌아가기」).
func open_dialog(_kind: String, after: Callable = Callable()) -> void:
	_after = after
	dialog.open(texts.t("title.confirm_new"), texts.t("title.new_game"), texts.t("party.dialog.back"))


func _choose(i: int) -> bool:
	if i < 0 or i > 1:
		return false
	var after := _after
	_after = Callable()
	dialog.close()
	if i == 1 and after.is_valid():
		after.call()
	return true


# ---- 키 ----

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


## 키 표 하나(키보드와 키패드가 같이 쓴다): 물리 키 → [입력 종류, 값], 하는 일이 없으면 []. 부작용 없음.
func key_action(code: int) -> Array:
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	var back := code == KEY_ESCAPE or code == KEY_BACKSPACE
	var dir := ShopScreen._arrow(code)
	if dialog.is_open():
		if dir.x != 0:
			return ["dialog_move", dir.x]
		if back:
			return ["dialog_back", null]
		return ["dialog_ok", null] if enter else []
	if page == "menu":
		var num := ShopScreen._number(code)
		if num >= 0 and num < rows.size():
			return ["row", num]
		if enter:
			return ["confirm", null]
		return ["cursor", dir.y] if dir.y != 0 else []
	if back:
		return ["back", null]
	if enter:
		return ["confirm", null]
	if dir.y != 0:
		return ["cursor", dir.y]
	if dir.x != 0:
		return ["cursor_x", dir.x]
	return []


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


## 키패드 단추마다 켤지: 키 표에 없거나(메뉴 ←→·취소) 늘 거부되는 것은 흐림 — 기록 판에서 커서 단추가 흐린 선택, 줄이 하나뿐인
## ↑↓(설정), 그 줄에 알약이 하나뿐인 ←→(불러오기). 움직일 자리가 있는 끝에서는 켜 둔다(캠프와 같다).
func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		var a := key_action(PAD_KEYS[k])
		out[k] = not a.is_empty() and _may_accept(a)
	return out


func _may_accept(a: Array) -> bool:
	if dialog.is_open() or page == "menu":
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
	return page != "menu"


func active_key_pad() -> VirtualPad:
	return key_pad_stacked if stacked() else key_pad


func _place_pads() -> void:
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var st := stacked()
	var k := PartyMenu.PAD_KEYS_RECORDS if st else PAD_KEYS_MENU
	var ks := VirtualPad.keys_size(st)
	PartyMenu.place(active_key_pad(), Vector2(1, 1), Vector2(1, 1), Vector4(k.x, k.y, k.x + ks.x, k.y + ks.y))
	key_pad.visible = not st
	key_pad_stacked.visible = st


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
			if _open:
				_refresh()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			cancel_pointers()


# ---- 그리기 ----

## 바깥(자동 지도 바꾸기·슬롯)이 값을 바꿨을 때 다시 그린다.
func refresh_view() -> void:
	records_tab.member_changed()
	_refresh()


func _refresh() -> void:
	if not _built or not _open:
		return
	var on_menu := page == "menu"
	for k in MENU_KEYS:
		var b: ListButton = menu_buttons[k]
		var i := rows.find(k)
		b.visible = on_menu and i >= 0
		b.selected = on_menu and i == cursor
		b.queue_redraw()
	ribbon.visible = not on_menu
	records_tab.visible = not on_menu
	if not on_menu:
		ribbon.show_text(texts.t("title." + page))
		records_tab.refresh()
	_layout()
	var on := pad_state()
	for p in [dir_pad, key_pad, key_pad_stacked]:
		(p as VirtualPad).set_enabled(on)
	queue_redraw()
	# 고름 값(selection_key)이 바뀌었으면 앞 값에서 시작한 누르기를 버린다. 맨 끝: 줄을 다시 만들고 커서를 맞춘 뒤의 값과 견준다
	# (검토 seq=13: 앞에서 견주면 같은 칸의 물건이 바뀐 것을 놓치고 기억한 값이 낡는다).
	press_guard.sync()


func menu_rect(i: int) -> Rect2:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return Rect2(Vector2(roundf((s.x - PILL.x) / 2.0), MENU_TOP + i * (PILL.y + PILL_GAP)), PILL)


func _layout() -> void:
	if not _built:
		return
	var s := size if size.x > 0.0 else get_viewport_rect().size
	for k in MENU_KEYS:
		var i := rows.find(k)
		var r := menu_rect(maxi(i, 0))
		PartyMenu.place(menu_buttons[k], Vector2(0.5, 0), Vector2(0.5, 0), Vector4(-PILL.x / 2.0, r.position.y, PILL.x / 2.0, r.end.y))
	records_tab.place(s)
	_place_pads()


func logo_rect() -> Rect2:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return Rect2(0, LOGO_Y, s.x, LOGO_H)


func notice_rect() -> Rect2:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return Rect2(0, s.y - NOTICE_BOTTOM - NOTICE_H, s.x, NOTICE_H)


func _draw() -> void:
	TownArt.paint(self, Rect2(Vector2.ZERO, size), "title")
	if page != "menu":
		return  # 기록 판이 가운데를 덮는다: 로고는 메뉴에서만
	var font := get_theme_default_font()
	var lr := logo_rect()
	var base := Vector2(0, lr.get_center().y + LOGO_FS * 0.36)
	draw_string_outline(font, base, texts.t("title.name"), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, LOGO_FS, 10, Color(0, 0, 0, 0.8))
	draw_string(font, base, texts.t("title.name"), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, LOGO_FS, UiTheme.FAC_TEXT)
	var nr := notice_rect()
	draw_string(font, Vector2(0, nr.get_center().y + NOTICE_FS * 0.36), texts.t("title.notice"), HORIZONTAL_ALIGNMENT_CENTER, nr.size.x,
		NOTICE_FS, UiTheme.TEXT)


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 단추(확인 창이 떠 있으면 그 창 단추만)와 켜진 키패드 단추.
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


## 지금 노랑으로 채운 것(한 화면 하나).
func yellow_fills() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	for n in find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.selected and b.is_visible_in_tree() and not (b is ListButton and (b as ListButton).cursor_ring):
			out.append(b)
	return out


## 디버그 snapshot 의 title 정보. css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
func debug_info(css: Callable) -> Dictionary:
	if not _open:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	return {
		"open": true, "page": page, "rows": rows.duplicate(), "cursor": cursor, "continue": can_continue,
		"dialog": dialog.is_open(), "dialog_pick": dialog.pick,
		"records": {"rows": records_tab.row_set, "cursor": [records_tab.cur_row, records_tab.cur_col]} if page != "menu" else {},
		"pad": pad_state(), "buttons": buttons,
	}
