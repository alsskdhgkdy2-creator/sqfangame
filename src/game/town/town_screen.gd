## 마을 화면(M3 A2): 창 층 2(전투 층 뒤, 상점·캠프 앞). 마을에 있는 동안만 열려 있고, 바탕 그림은 탐색 화면의 TownBackdrop(층 0)이다.
## 쪽(page): plaza(광장, 원작 I HD The Verda Plaza yt_eo1hd_01) · entrance(아보르 입구, 원작 II HD 樹海入口 gw_27).
##   광장: 설명 띠(커서 시설 설명 / 안내) · 다이얼 자리 캠프 단추(TownPlate) · 시설 목록(왼쪽 띠에 커서 시설 그림) · 장소 문패 · 키패드.
##   입구: 띠(「아보르 B1F로 내려간다」 / 커서 줄 설명) · 캠프 단추 · 줄 둘(탐사 시작·마을로 돌아간다) · 파티 카드(읽기만) · 키패드.
## 일(캠프·상점·탐사 시작)은 신호로 탐색 화면에 맡긴다. 캠프·상점이 열린 동안 탐색 화면이 이 화면을 덮어 감춘다(set_covered).
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
## 아직 문을 열지 않은 시설(누르면 이유만). 숙소는 A2b 에서 연다.
const PLAZA_DIM := ["inn", "pub", "guild", "council"]
const ENTRANCE_KEYS := ["start", "back"]
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
## 장소 문패: 오른쪽 아래(W − 360 ~ W, y H − 88 ~ H − 12).
const PLACE_PLATE := Vector4(-360, -88, 0, -12)
const NOTICE_SEC := 2.5
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 키패드 자리(상점 뿌리와 같다): 십자 왼쪽 아래, 「취소」「선택」 가로 (W − 247, H − 293).
const PAD_DIR := Vector2(8, -209)
const PAD_KEYS_AT := Vector2(-247, -293)

# ---- 바깥에서 정하는 값 ----
var blocked_hook: Callable
## 지금 장소 그림을 그릴 화면 전체 바탕(탐색 화면 층 0).
var backdrop: TownArt.TownBackdrop

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## plaza · entrance
var page := "plaza"
var plaza_cursor := 0
var entrance_cursor := 0
var notice := ""
var covered := false
var accepted_inputs := 0

# ---- 부품 ----
var banner: FacilityBanner
var camp_plate: TownPlate
var plaza_list: FacilityList
var entrance_list: FacilityList
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


## 트리 순서 = 그리는·누르는 순서: 카드 → 띠 → 장소 문패(장식) → 목록 둘 → 캠프 단추 → 키패드.
func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
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
	camp_plate = TownPlate.new()
	add_child(camp_plate)
	camp_plate.setup("", texts.t("town.camp"))
	camp_plate.name = "CampButton"
	PartyMenu.place(camp_plate, Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, TownPlate.SIZE.x, TownPlate.SIZE.y))
	camp_plate.activated.connect(func() -> void: handle("camp"))
	var ok := texts.t("battle.ui.pad_ok")
	var back := texts.t("battle.ui.pad_back")
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	key_pad = VirtualPad.new().setup_keys(ok, back)
	key_pad.name = "KeyPad"
	for p in [dir_pad, key_pad]:
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
	return PLAZA_KEYS if p == "plaza" else ENTRANCE_KEYS


func _dispatch(kind: String, arg: Variant) -> bool:
	var keys := keys_of(page)
	match kind:
		"camp":
			camp_requested.emit()
			return true
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
			if page != "entrance":
				return false  # 광장의 취소는 아무 일도 하지 않는다(§8 고름 16)
			page = "plaza"
			plaza_cursor = PLAZA_KEYS.find("entrance")
			_clear_notice()
			return true
	return false


func cursor() -> int:
	return plaza_cursor if page == "plaza" else entrance_cursor


func _set_cursor(i: int) -> void:
	if page == "plaza":
		plaza_cursor = i
	else:
		entrance_cursor = i


## 줄 i 의 일. 광장: 흐린 시설 → 이유만, 정크 공방 → 상점(탐색 화면이 연다), 아보르 입구 → 입구 쪽. 입구: 탐사 시작 → 탐색 화면, 돌아가기 → 광장.
func _run(i: int) -> bool:
	if page == "plaza":
		var k: String = PLAZA_KEYS[i]
		if PLAZA_DIM.has(k):
			show_notice(texts.t("town.why.later"))
			return true
		match k:
			"shop":
				shop_requested.emit()
			"entrance":
				page = "entrance"
				entrance_cursor = 0
				_clear_notice()
		return true
	match ENTRANCE_KEYS[i]:
		"start":
			enter_requested.emit()
		"back":
			page = "plaza"
			plaza_cursor = PLAZA_KEYS.find("entrance")
			_clear_notice()
	return true


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
	var num := ShopScreen._number(code)
	if num >= 0 and num < keys_of(page).size():
		return ["row", num]
	if enter:
		return ["confirm", null]
	if back:
		return ["back", null] if page == "entrance" else []
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


func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		out[k] = not key_action(PAD_KEYS[k]).is_empty()
	return out


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

func show_notice(t: String) -> void:
	notice = t
	_notice_left = NOTICE_SEC
	_refresh_banner()


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

## 지금 장소 이름(캠프 장소 띠·장소 문패): 광장은 「뿌리마을 광장」, 입구는 그 시설 이름.
func place_text() -> String:
	return texts.t("town.plaza") if page == "plaza" else texts.t("town.fac.entrance")


## 지금 바탕 그림 열쇠(TownArt).
func art_key() -> String:
	return "plaza" if page == "plaza" else "entrance"


func day_text() -> String:
	return texts.t("town.day", {"n": state.day if state != null else 1})


func row_label(p: String, i: int) -> String:
	var k: String = keys_of(p)[i]
	var label := texts.t("town.fac." + k) if p == "plaza" else texts.t("entrance." + k)
	return "%d  %s" % [i + 1, label]


func desc_text() -> String:
	var k: String = keys_of(page)[cursor()]
	return texts.t("town.desc." + k) if page == "plaza" else texts.t("entrance.desc." + k)


# ---- 그리기 ----

func refresh_view() -> void:
	_refresh()


func _refresh() -> void:
	if not _built or not _open or state == null or covered:
		return  # 덮인 동안(캠프·상점)은 그리지 않는다: 바탕은 덮은 화면의 것(상점 그림)이다
	var ctx := "%s|%d" % [page, cursor()]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	var on_plaza := page == "plaza"
	plaza_list.visible = on_plaza
	place_plate.visible = on_plaza
	entrance_list.visible = not on_plaza
	cards.visible = not on_plaza
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
	entrance_list.show_rows(entrance_cursor if not on_plaza else -1, -1, elive)
	if not on_plaza:
		for c in cards.cards:
			c.queue_redraw()
	if backdrop != null:
		backdrop.show_place(art_key())
	_refresh_banner()
	var on := pad_state()
	dir_pad.set_enabled(on)
	key_pad.set_enabled(on)


func _refresh_banner() -> void:
	if banner == null or state == null:
		return
	if page == "plaza":
		banner.show_lines(desc_text(), notice, not notice.is_empty())
	else:
		banner.show_lines(texts.t("entrance.band"), notice if not notice.is_empty() else desc_text(), not notice.is_empty())


func _layout() -> void:
	if not _built:
		return
	PartyMenu.place(plaza_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, PLAZA_TOP, PLAZA_W, PLAZA_TOP + FacilityList.content_height(PLAZA_KEYS.size(), PLAZA_GAP, PLAZA_PAD)))
	PartyMenu.place(entrance_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, ENTRANCE_TOP, FacilityList.WIDTH, ENTRANCE_TOP + FacilityList.content_height(ENTRANCE_KEYS.size(), ENTRANCE_GAP, ENTRANCE_PAD)))
	banner.place()
	_place_pads()


# ---- 시험·디버그 읽기 ----

func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open or covered:
		return out
	for n in find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.get_parent() is VirtualPad:
			continue
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		out.append(b)
	for p in [dir_pad, key_pad]:
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
		dim.append(page == "plaza" and PLAZA_DIM.has(k))
	var names := []
	var l := plaza_list if page == "plaza" else entrance_list
	for i in keys.size():
		names.append(str(l.rows[i].name))
	return {
		"open": true, "page": page, "cursor": cursor(), "rows": names, "dim": dim, "band": [banner.head, banner.body],
		"place": place_text(), "art": art_key(), "day": day_text(), "covered": covered, "notice": notice,
		"pad": pad_state(), "buttons": buttons,
	}
