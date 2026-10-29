## 모험가 길드 화면(M3 A7c, 설계 §5·§4.1b·§4.2·§7 A7c U1~U7): 광장 「모험가 길드」 → 뿌리·등록(직업·외형·이름)·관리(이름 바꾸기·등록 지우기)·
## 편성과 순서, 캠프 「대열」 판(같은 FormBoard). 실제 흐름은 누르기 → 자동 저장 = 화면 → 새 화면으로 다시 읽기까지 본다(교훈 1).
## 그린 모양은 그리기 기록(SheetParts.record)과 만든 노드에서 읽는다(교훈 2). 값은 설계·자료의 글자 그대로 적는다(교훈 7).
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(설계 §7 A7c, M-U…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const SIZES := [Vector2(1280, 720), Vector2(1728, 720), Vector2(1280, 960)]
const FINGER := 3
const PAD_NAMES := ["up", "down", "left", "right", "ok", "back"]
## 직업 차례(01 §5 표, 설계 §4.2)와 화면 이름.
const CLASSES := ["class.holo_knight", "class.blade_duelist", "class.rail_ranger", "class.nano_medic", "class.glyph_wizard", "class.hex_hacker"]
const CLASS_NAMES := ["홀로나이트", "블레이드 듀얼리스트", "레일 레인저", "나노 메딕", "글리프 위저드", "헥스 해커"]
const GUILD_ROW := 3

var kit: Kit
var host: Control
var texts: TextDb
var saves := 0
var asked: Array = []
var _defs: GameDefs
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


# ---- 준비 ----

func _kit() -> void:
	if kit == null:
		kit = Kit.new(tree)
	if texts == null:
		texts = TextDb.load_path("res://data/text/ko.json")


func _window(px: Vector2) -> Vector2:
	_kit()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 마을 새 게임 상태(시드 1, 기본 다섯). recruit 이면 길드에 레일 레인저 「레일」(외형 0)을 등록해 둔다.
func _state(recruit: bool = false) -> ExplorationState:
	_kit()
	if _defs == null:
		_defs = Fx.defs()
	var s := ExplorationRules.new_game(_defs, 1, "floor", true)
	if recruit:
		var ev := GuildRules.register(s, "class.rail_ranger", 0, "레일", [])
		check_eq(ev[0]["type"], "registered", "준비: 레일 등록")
	return s


## 탐색 화면 없이 길드만(창 크기 px). 저장 갈고리·이름 부탁은 센다.
func _fresh(s: ExplorationState = null, px: Vector2 = SIZES[0]) -> GuildScreen:
	timeout_sec = 150.0
	await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	saves = 0
	asked = []
	host = Control.new()
	host.name = "GuildHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := GuildScreen.new()
	host.add_child(g)
	g.build(texts)
	g.save_hook = func() -> void: saves += 1
	g.name_requested.connect(func(d: String) -> void: asked.append(d))
	g.open(s if s != null else _state())
	await kit.frames(2)
	return g


func _step(g: GuildScreen, kind: String, arg: Variant = null) -> bool:
	var ok := g.handle(kind, arg)
	await kit.frames(1)
	return ok


## 화면이 가진 것 전부(입력 하나가 바꿀 수 있는 것).
func _sig(g: GuildScreen) -> Array:
	return [g.is_open(), g.page, g.root_cursor, g.class_cursor, g.look_cursor, g.manage_cursor, g.roster_inv.cursor, g.manage_inv.cursor,
		g.form_focus, g.board.front.duplicate(), g.board.back.duplicate(), g.board.cursor, g.board.held, g.dialog.mode, g.dialog.pick, g.asking,
		g.naming, g.notice, SaveCodec.state_hash(g.state), saves, asked.duplicate(), g.accepted_inputs]


static func _pad_button(g: GuildScreen, k: String) -> TouchButton:
	return g.dir_pad.button(k) if k in ["up", "down", "left", "right"] else g.active_key_pad().button(k)


## 탐색 화면을 마을로 띄운다(PC, 디버그 도구 없음).
func _town(prep: Callable = Callable()) -> DungeonScreen:
	timeout_sec = 180.0
	_kit()
	return await kit.open_town("native", 7, "", func(sc: DungeonScreen) -> void:
		sc.native_debug = false
		if prep.is_valid():
			prep.call(sc))


## 같은 저장 폴더로 마을 화면을 다시 연다(자동 저장을 읽는다).
func _reload() -> DungeonScreen:
	var s: DungeonScreen = await kit.reopen(func(sc: DungeonScreen) -> void:
		sc.start_mode = "town"
		sc.native_debug = false)
	await kit.frames(2)
	return s


## 광장 「모험가 길드」 줄을 실제로 누른다.
func _open_guild(s: DungeonScreen) -> GuildScreen:
	await kit.tap(kit.center_of(s.town_screen.plaza_list.rows[GUILD_ROW]))
	await kit.frames(1)
	return s.guild_screen


func _auto(s: DungeonScreen) -> SaveCodec.LoadResult:
	return SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)


func _check_saved(s: DungeonScreen, gen0: int, tag: String) -> void:
	check(s.state.generation > gen0, tag + ": 자동 저장했다(세대 +)")
	var a := _auto(s)
	check(a.ok() and SaveCodec.state_hash(a.state) == kit.hash_now(), "%s: 자동 저장 = 화면 %s" % [tag, a.error])


func _name_edit(s: DungeonScreen) -> LineEdit:
	return s.modal.find_child("NameEdit", true, false) as LineEdit


func _modal_button(s: DungeonScreen, n: String) -> Button:
	return s.modal.find_child(n, true, false) as Button


## 이름 창에 글을 넣고 「확인」을 실제로 누른다.
func _enter_name(s: DungeonScreen, t: String, tag: String) -> void:
	check_eq(s.modal.kind, "name", tag + ": 이름 창이 열렸다")
	var e := _name_edit(s)
	if e == null:
		return
	e.text = t
	await kit.tap(kit.center_of(_modal_button(s, "NameOk")))
	await kit.frames(2)


func _by_name(s: ExplorationState, n: String) -> PartyState.Member:
	for m in GuildRules.roster(s):
		if m.name == n:
			return m
	return null


static func _texts_of(c: CanvasItem) -> Array:
	return SheetParts.record(c).filter(func(e: Dictionary) -> bool: return e["kind"] == "text").map(func(e: Dictionary) -> String: return str(e["text"]))


static func _colors_of(c: CanvasItem, kind: String) -> Array:
	return SheetParts.record(c).filter(func(e: Dictionary) -> bool: return e["kind"] == kind).map(func(e: Dictionary) -> Color: return e["color"])


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


# ---- U1 광장 입구 ----

## U1 (M-U1 길드가 아직 PLAZA_DIM): 광장 「모험가 길드」 줄은 흐리지 않고 누르면 길드 뿌리(「아직 문을 열지 않았다」가 아님).
## 열린 동안 마을 화면을 덮고 바탕은 길드 그림, P = 캠프(길드는 덮였다가 돌아온다). 「나간다」·Esc = 광장(커서 「모험가 길드」 그대로).
## 키 4 도 연다. 「대화한다」는 흐리고 이유만.
func test_plaza_guild_row_opens_the_guild_and_cancel_returns_to_it() -> void:
	var s := await _town()
	var t := s.town_screen
	check(t.is_open() and t.page == "plaza", "준비: 광장")
	check_eq(str(t.plaza_list.rows[GUILD_ROW].name), "Plaza_guild", "넷째 줄 = 모험가 길드")
	check(not t.plaza_list.rows[GUILD_ROW].dimmed, "길드 줄은 흐리지 않다")
	var g := await _open_guild(s)
	check(g.is_open() and g.page == "root" and g.root_cursor == 0, "길드 줄 → 길드 뿌리, 커서 0")
	check(t.notice != s.texts.t("town.why.later"), "「아직 문을 열지 않았다」가 아니다")
	check(t.covered and not t.visible and not s.hud_root.visible, "마을 화면·탐색 HUD 를 덮는다")
	check_eq(s.town_backdrop.place, "guild", "바탕 = 길드 그림")
	check_eq(g.root_list.rows.map(func(r: ListRow) -> String: return r.text),
		["1  모험가 등록", "2  모험가 관리", "3  편성과 순서", "4  대화한다", "5  나간다"], "뿌리 줄 글(원작 차례)")
	check_eq(g.root_list.rows.map(func(r: ListRow) -> bool: return r.dimmed), [false, false, false, true, false], "「대화한다」만 흐림")
	check_eq(g.banner.lines(), ["새 모험가를 길드에 등록한다", "", false], "띠 = 커서 줄 설명")
	var snap: Dictionary = s.debug_snapshot()
	check(snap["guild_screen"]["open"] and snap["guild_screen"]["page"] == "root", "스냅숏 guild_screen")
	check(snap["buttons"].has("Guild_register") and snap["buttons"].has("GuildPlate") and not snap["buttons"].has("Plaza_guild"),
		"스냅숏 단추: 길드 줄·캠프 문패, 덮인 광장 줄은 없다 %s" % str(snap["buttons"].keys()))
	await kit.tap(kit.center_of(g.root_list.rows[3]))
	check_eq([g.page, g.notice, g.banner.lines()], ["root", "길드장이 자리를 비웠다", ["길드장과 이야기한다", "길드장이 자리를 비웠다", true]],
		"「대화한다」 → 이유만(둘째 줄)")
	# 캠프: P → 길드는 덮이고, 닫으면 같은 쪽으로.
	await kit.press_key(KEY_P)
	check(s.party_menu.is_open() and g.covered and not g.visible, "P → 캠프, 길드는 덮인다")
	await kit.press_key(KEY_ESCAPE)
	check(not s.party_menu.is_open() and g.is_open() and not g.covered and g.visible and t.covered, "캠프를 닫으면 길드 그대로(광장은 덮인 채)")
	check_eq(s.town_backdrop.place, "guild", "바탕은 길드 그대로")
	await kit.press_key(KEY_ESCAPE)
	check(not g.is_open() and t.visible and not t.covered, "뿌리 Esc → 광장")
	check_eq([t.page, t.plaza_cursor, s.town_backdrop.place], ["plaza", GUILD_ROW, "plaza"], "광장 커서는 「모험가 길드」 그대로, 바탕은 광장")
	await kit.press_key(KEY_4)
	check(g.is_open() and g.page == "root", "키 4 → 길드")
	await kit.tap(kit.center_of(g.root_list.rows[4]))
	check(not g.is_open() and t.plaza_cursor == GUILD_ROW, "「나간다」 → 광장")


# ---- U2 직업 고르기 ----

## U2 (M-U2 직업 목록에 헥스 해커가 없다): 직업 여섯을 차례대로, 직업 판 글(Lv 1·HP·TP·시작 장비·능력치)과 설명 상자 글을 그리기 기록에서 읽는다.
## 레일 레인저 Lv1 = HP 46 · TP 36(설계 §4.3), 시작 장비 레일 보우·패딩 코트·정찰 후드·빈칸, 주무기 「활」, 후열 사격형.
func test_class_page_lists_six_classes_and_draws_the_sheet() -> void:
	var g := await _fresh()
	await kit.press_key(KEY_1)
	check_eq([g.page, g.current_class()], ["class", "class.holo_knight"], "1 → 직업 고르기(커서 0)")
	check_eq(g.class_inv.used, 6, "줄 여섯")
	check_eq(range(g.class_inv.used).map(func(i: int) -> String: return g.class_inv.rows[i].text), CLASS_NAMES, "차례 = 01 §5 표")
	for i in g.class_inv.used:
		check(g.class_window.get_global_rect().encloses(g.class_inv.rows[i].get_global_rect().grow(-0.5)), "줄 %d 가 창 안(내리지 않아도 다 보인다)" % i)
		check(g.class_inv.rows[i].clipped_parts().is_empty(), "줄 %d 글이 잘리지 않는다(「블레이드 듀얼리스트」 포함)" % i)
	check_eq(range(g.class_inv.used).map(func(i: int) -> String: return (g.class_inv.rows[i] as ListButton).icon_name),
		["kind_sword", "kind_sword", "kind_bow", "kind_staff", "kind_staff", "kind_gun"], "줄 아이콘 칸 = 주무기 종류")
	for i in [1, 2, 3, 4, 5, 0]:
		await kit.tap(kit.center_of(g.class_inv.rows[i]))
		await kit.frames(1)
		check_eq([g.page, g.current_class()], ["class", CLASSES[i]], "줄 %d 누르기 → 커서만(외형으로 가지 않는다)" % i)
		var c: BattleDb.ClassDef = g.state.defs.battle.classes[CLASSES[i]]
		var p := GrowthRules.profile(g.state.defs, -1, g.preview_member(CLASSES[i]))
		var st := _texts_of(g.class_sheet)
		check(st.has("Lv 1") and st.has("HP %d/%d" % [p["max_hp"], p["max_hp"]]) and st.has("TP %d/%d" % [p["max_tp"], p["max_tp"]]),
			"%s: 판 글 Lv·HP·TP %s" % [CLASS_NAMES[i], str(st)])
		for e in c.start_equip:
			if not str(e).is_empty():
				check(st.has(PartyNames.item_name(g.state, g.texts, e)), "%s: 시작 장비 %s" % [CLASS_NAMES[i], e])
		for stat in BattleLimits.STATS:
			check(st.has(g.texts.t("stat." + stat)) and st.has(str(p["stats"][stat])), "%s: 능력치 %s" % [CLASS_NAMES[i], stat])
		check(_texts_of(g.class_plate).has(CLASS_NAMES[i]), "%s: 직업 문패" % CLASS_NAMES[i])
		check(_texts_of(g.class_desc).has(CLASS_NAMES[i]), "%s: 설명 상자 머리" % CLASS_NAMES[i])
	await kit.tap(kit.center_of(g.class_inv.rows[2]))
	await kit.frames(1)
	var st := _texts_of(g.class_sheet)
	check(st.has("HP 46/46") and st.has("TP 36/36"), "레일 레인저 Lv1 HP 46 · TP 36 %s" % str(st))
	check(st.has("레일 보우") and st.has("패딩 코트") and st.has("정찰 후드") and st.has("비어 있음"), "레일 레인저 시작 장비 넷")
	var dt := _texts_of(g.class_desc)
	check(dt.has("레일 활을 쏘는 정찰병.") and dt.has("주무기: 활") and dt.has("후열에서 쏘고 묶는 사격형"), "설명 상자 줄 %s" % str(dt))
	await kit.tap(kit.center_of(g.class_inv.rows[2]))
	check_eq([g.page, g.current_class(), g.look_cursor], ["look", "class.rail_ranger", 0], "커서 줄을 다시 누르면 외형(커서 A)")
	await kit.press_key(KEY_ESCAPE)
	check_eq([g.page, g.current_class()], ["class", "class.rail_ranger"], "외형 Esc → 직업(커서 그대로)")
	await kit.press_key(KEY_6)
	check_eq([g.page, g.current_class()], ["class", "class.hex_hacker"], "키 6 → 헥스 해커 줄(누르기와 같다)")
	await kit.press_key(KEY_6)
	check_eq([g.page, g.current_class()], ["look", "class.hex_hacker"], "키 6 다시 → 헥스 해커 외형")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check_eq([g.page, g.root_cursor], ["root", 0], "직업 Esc → 뿌리")


# ---- U3 외형 ----

## U3 (M-U3 큰 그림이 외형을 무시): 외형 띠 둘(A·B), 외형 1 은 직업색을 30% 짙게 그린다. 큰 그림 색은 커서 외형을 따른다. 고른 띠 = 밝은 테.
func test_look_page_draws_two_looks_in_different_colours() -> void:
	var g := await _fresh()
	await _step(g, "row", 0)
	await _step(g, "row", 5)
	await _step(g, "confirm")
	check_eq([g.page, g.current_class()], ["look", "class.hex_hacker"], "준비: 헥스 해커 외형")
	check_eq(g.strips.size(), 2, "외형 띠 둘")
	var base: Color = BattleCard.CLASS_COLORS["class.hex_hacker"]
	await kit.frames(1)
	check_eq(_colors_of(g.strips[0], "silhouette"), [base], "A 띠 = 직업색")
	check_eq(_colors_of(g.strips[1], "silhouette"), [base.darkened(0.3)], "B 띠 = 직업색 30% 짙게")
	check(base != base.darkened(0.3), "두 외형의 색이 다르다")
	check(_texts_of(g.strips[0]).has("A") and _texts_of(g.strips[1]).has("B"), "모서리 표 A·B")
	check_eq(_colors_of(g.look_portrait, "silhouette"), [base], "큰 그림 = 커서 외형 A")
	check_eq(_colors_of(g.strips[0], "outline"), [UiTheme.BTN_PICK], "고른 띠 = 밝은 테")
	await kit.tap(kit.center_of(g.strips[1]))
	await kit.frames(1)
	check_eq([g.look_cursor, asked], [1, []], "B 띠 누르기 → 커서 B(이름은 아직 묻지 않는다)")
	check_eq(_colors_of(g.look_portrait, "silhouette"), [base.darkened(0.3)], "큰 그림 = 외형 B 색")
	check_eq([_colors_of(g.strips[0], "outline"), _colors_of(g.strips[1], "outline")], [[UiTheme.CMD_PLATE_EDGE], [UiTheme.BTN_PICK]], "고른 띠가 B 로")
	check_eq(_texts_of(g.look_msg), ["외형을 고른다"], "외형 말 상자")
	await kit.press_key(KEY_LEFT)
	check_eq(g.look_cursor, 0, "← → A")
	await kit.press_key(KEY_2)
	check_eq([g.look_cursor, asked], [1, []], "키 2 → B")
	await kit.tap(kit.center_of(g.strips[1]))
	check_eq([g.naming, asked], ["register", ["해커1"]], "고른 띠를 다시 누르면 이름(기본 「해커1」)")


# ---- U4 이름·등록 ----

## U4 (M-U4 등록 뒤 자동 저장 없음): PC 이름 창(NameEdit 8자까지, 기본 「레인저1」). 맞지 않는 이름 → 외형 말 상자에 이유, 등록 없음.
## 취소 → 외형 그대로. 맞는 이름 → 확인 창(「예」 먼저) → 「예」 → 등록·자동 저장 = 화면 → 뿌리·안내. 다시 연 화면에도 그 대원(직업·외형·이름)이 있다.
func test_register_asks_a_name_confirms_saves_and_reloads() -> void:
	var s := await _town()
	var g := await _open_guild(s)
	var n0 := GuildRules.roster(s.state).size()
	await kit.press_key(KEY_1)
	await kit.tap(kit.center_of(g.class_inv.rows[2]))
	await kit.tap(kit.center_of(g.class_inv.rows[2]))
	await kit.tap(kit.center_of(g.strips[1]))
	await kit.tap(kit.center_of(g.strips[1]))
	check_eq([g.page, g.current_class(), g.look_cursor, g.naming], ["look", "class.rail_ranger", 1, "register"], "준비: 레인저 B 이름 묻기")
	var e := _name_edit(s)
	check(e != null, "이름 창 NameEdit")
	if e == null:
		return
	check_eq([s.modal.kind, e.max_length, e.text], ["name", 8, "레인저1"], "이름 창: 8자까지, 기본 「레인저1」")
	e.text = ""
	e.insert_text_at_caret("가나다라마바사아자차")
	check_eq(e.text, "가나다라마바사아", "넣는 글은 8자에서 멈춘다")
	var gen0 := s.state.generation
	var h0 := kit.hash_now()
	var bad := [["  ", "이름을 넣어야 한다"], ["a!b", "이름에 쓸 수 없는 글자가 있다"],
		[PartyNames.display_name(s.texts, s.state.party.members[0]), "같은 이름의 모험가가 있다"]]
	for b in bad:
		if not s.modal.is_open():
			await kit.tap(kit.center_of(g.strips[1]))
		await _enter_name(s, b[0], "「%s」" % b[0])
		check_eq([s.modal.is_open(), g.page, g.notice, g.dialog.is_open()], [false, "look", b[1], false], "「%s」 → 외형에 남고 이유" % b[0])
		check_eq(_texts_of(g.look_msg), [b[1]], "「%s」: 이유는 외형 말 상자에" % b[0])
	check_eq([GuildRules.roster(s.state).size(), kit.hash_now(), s.state.generation], [n0, h0, gen0], "맞지 않는 이름: 등록·저장 없음")
	await kit.tap(kit.center_of(g.strips[1]))
	await kit.tap(kit.center_of(_modal_button(s, "NameCancel")))
	check_eq([s.modal.is_open(), g.page, g.naming, kit.hash_now()], [false, "look", "", h0], "취소 → 외형 그대로, 등록 없음")
	await kit.tap(kit.center_of(g.strips[1]))
	await _enter_name(s, "레일", "레일")
	check(g.dialog.is_open(), "맞는 이름 → 확인 창")
	check_eq([g.dialog.message, g.dialog.pick], ["레일 레인저 레일을 등록할까?", ShopDialog.YES], "확인 글, 「예」 먼저")
	await kit.tap(kit.center_of(g.dialog.yes_button))
	await kit.frames(2)
	var m := _by_name(s.state, "레일")
	check(m != null, "「레일」 등록")
	if m == null:
		return
	check_eq([m.class_id, m.look, m.level, s.state.party.members.has(m), GuildRules.roster(s.state).size()],
		["class.rail_ranger", 1, 1, false, n0 + 1], "직업·외형 B·Lv1·파티 밖·명부 +1")
	_check_saved(s, gen0, "등록")
	check_eq([g.page, g.root_cursor, g.notice], ["root", 0, "레일이 길드에 들어왔다"], "뿌리로, 안내")
	var h := kit.hash_now()
	s = await _reload()
	check_eq(kit.hash_now(), h, "다시 연 화면: 같은 해시")
	var m2 := _by_name(s.state, "레일")
	check(m2 != null and m2.look == 1 and m2.class_id == "class.rail_ranger", "다시 연 화면: 「레일」 레인저 외형 B")
	g = await _open_guild(s)
	await kit.press_key(KEY_2)
	check_eq(g.page, "manage", "관리")
	var names := range(g.roster_inv.used).map(func(i: int) -> String: return g.roster_inv.rows[i].text)
	check(names.has("레일"), "등록부 목록에 「레일」 %s" % str(names))


# ---- 관리: 이름 바꾸기·등록 지우기 ----

## 관리(설계 §5.5, O7): 길드 대원 → 작은 목록 → 「이름 바꾸기」(같은 이름 창, 기본 = 지금 이름) → 자동 저장 = 화면 → 다시 읽기.
## 파티 대원 「등록 지우기」는 흐리고 이유만. 길드 대원은 확인(「아니오」 먼저) → 「예」 → 장비는 가방으로, 안내 두 줄, 자동 저장 = 화면 → 다시 읽기.
func test_manage_renames_and_removes_with_saves() -> void:
	var s := await _town(func(sc: DungeonScreen) -> void: pass)
	var r := GuildRules.register(s.state, "class.rail_ranger", 0, "레일", [])
	check_eq(r[0]["type"], "registered", "준비: 레일 등록")
	var id: String = r[0]["id"]
	s._autosave()
	var g := await _open_guild(s)
	await kit.tap(kit.center_of(g.root_list.rows[1]))
	check_eq([g.page, g.roster_ids.size()], ["manage", 6], "관리: 등록부 여섯")
	check_eq([g.roster_inv.rows[0].text, g.roster_inv.rows[0].right, (g.roster_inv.rows[0] as ListButton).icon_name], ["홀로나이트", "파티", "kind_sword"],
		"파티 대원 줄 = 이름 · 「파티」, 아이콘 칸 = 주무기")
	check_eq([g.roster_inv.rows[5].text, g.roster_inv.rows[5].right, (g.roster_inv.rows[5] as ListButton).icon_name], ["레일", "", "kind_bow"], "길드 대원 줄")
	check_eq(g.banner.lines(), ["등록한 모험가", "홀로나이트 Lv1 · 파티", false], "띠 둘째 줄 = 커서 대원 직업·레벨·파티")
	for i in 5:
		check(g.roster_inv.rows[i].clipped_parts().is_empty(), "등록부 줄 %d 글이 잘리지 않는다" % i)
	# 파티 대원은 지울 수 없다.
	await kit.tap(kit.center_of(g.roster_inv.rows[0]))
	check_eq(g.page, "manage_menu", "줄 → 작은 목록")
	check_eq(range(3).map(func(i: int) -> String: return g.manage_inv.rows[i].text), ["이름 바꾸기", "등록 지우기", "돌아가기"], "작은 목록 글")
	var h0 := kit.hash_now()
	await kit.tap(kit.center_of(g.manage_inv.rows[1]))
	check_eq([g.dialog.is_open(), g.notice, kit.hash_now()], [false, "파티에 있는 대원은 지울 수 없다", h0], "파티 대원 지우기 → 이유만")
	check_eq(g.banner.lines(), ["등록한 모험가", "파티에 있는 대원은 지울 수 없다", true], "이유는 띠 둘째 줄")
	await kit.press_key(KEY_ESCAPE)
	# 이름 바꾸기: 여섯째 줄은 내려야 보인다(등록부 다섯 줄) — 키로 내린다.
	check(not g.roster_inv.shown_at(5), "여섯째 줄은 처음에 가려져 있다")
	for i in 5:
		await kit.press_key(KEY_DOWN)
	check(g.roster_inv.shown_at(5) and g.roster_inv.cursor == 5, "↓ 다섯 → 여섯째 줄이 보인다")
	await kit.tap(kit.center_of(g.roster_inv.rows[5]))
	check_eq([g.page, g.managed_member().id], ["manage_menu", id], "레일 → 작은 목록")
	check_eq(g.banner.lines(), ["등록한 모험가", "레일 레인저 Lv1", false], "띠 = 고른 대원(파티 밖)")
	await kit.tap(kit.center_of(g.manage_inv.rows[0]))
	var e := _name_edit(s)
	check(e != null and e.text == "레일", "이름 창 기본 = 지금 이름")
	var gen0 := s.state.generation
	await _enter_name(s, PartyNames.display_name(s.texts, s.state.party.members[1]), "겹친 이름")
	check_eq([GuildRules.find(s.state, id).name, g.notice, s.state.generation], ["레일", "같은 이름의 모험가가 있다", gen0], "겹친 이름 → 이유, 그대로")
	await kit.tap(kit.center_of(g.manage_inv.rows[0]))
	await _enter_name(s, "활쟁이", "새 이름")
	check_eq([GuildRules.find(s.state, id).name, g.notice, g.page], ["활쟁이", "이름을 활쟁이로 바꿨다", "manage_menu"], "이름 바꿈, 안내")
	_check_saved(s, gen0, "이름 바꾸기")
	check_eq(g.roster_inv.rows[5].text, "활쟁이", "등록부 줄도 새 이름")
	var h := kit.hash_now()
	s = await _reload()
	check(kit.hash_now() == h and GuildRules.find(s.state, id) != null and GuildRules.find(s.state, id).name == "활쟁이", "다시 연 화면: 새 이름")
	# 등록 지우기.
	g = await _open_guild(s)
	await kit.press_key(KEY_2)
	for i in 5:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq([g.page, g.managed_member().id], ["manage_menu", id], "↓ 다섯·선택 → 활쟁이 작은 목록")
	var bag0 := s.state.gear_bag.duplicate()
	await kit.tap(kit.center_of(g.manage_inv.rows[1]))
	check(g.dialog.is_open(), "길드 대원 지우기 → 확인 창")
	check_eq([g.dialog.message, g.dialog.pick], ["활쟁이의 등록을 지울까?", ShopDialog.NO], "확인 글, 「아니오」 먼저")
	await kit.tap(kit.center_of(g.dialog.no_button))
	check(not g.dialog.is_open() and GuildRules.find(s.state, id) != null, "「아니오」 → 그대로")
	await kit.tap(kit.center_of(g.manage_inv.rows[1]))
	gen0 = s.state.generation
	await kit.tap(kit.center_of(g.dialog.yes_button))
	await kit.frames(2)
	check(GuildRules.find(s.state, id) == null and GuildRules.roster(s.state).size() == 5, "지웠다(명부 다섯)")
	for it in ["equip.rail_bow", "equip.padded_coat", "equip.scout_hood"]:
		check_eq(int(s.state.gear_bag.get(it, 0)), int(bag0.get(it, 0)) + 1, "%s 가 가방으로" % it)
	check_eq([g.page, g.notice], ["manage", "활쟁이의 등록을 지웠다\n장비 3개가 가방으로 갔다"], "등록부로, 안내 두 줄")
	check_eq(g.banner.lines(), ["활쟁이의 등록을 지웠다", "장비 3개가 가방으로 갔다", true], "U7: 두 줄 안내는 띠 두 줄")
	_check_saved(s, gen0, "등록 지우기")
	h = kit.hash_now()
	s = await _reload()
	check(kit.hash_now() == h and GuildRules.find(s.state, id) == null and int(s.state.gear_bag.get("equip.rail_bow", 0)) >= 1,
		"다시 연 화면: 지운 대원 없음, 장비는 가방에")


# ---- U5 편성 ----

## U5 (M-U5 취소가 초안을 남김): 편성 판 칸 → 등록부 대원 → 「결정」 → 편성·자동 저장 = 화면 → 다시 읽기. 취소는 초안을 버린다
## (다시 들어오면 지금 파티). 모두 비우고 「결정」 → 「파티에 대원이 없다」, 저장 없음. 여섯을 넣으면 「파티는 5명까지다」.
func test_formation_puts_a_recruit_saves_and_cancel_discards() -> void:
	var s := await _town()
	var r := GuildRules.register(s.state, "class.hex_hacker", 0, "해커", [])
	var id: String = r[0]["id"]
	s._autosave()
	var party0: Array = s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id)
	var g := await _open_guild(s)
	await kit.press_key(KEY_3)
	check_eq([g.page, g.form_focus, g.board.cursor], ["form", "board", 0], "3 → 편성(판 커서 0)")
	check_eq(g.board.members(), party0, "판 = 지금 파티(전열 다음 후열)")
	check_eq(g.roster_ids, ["", "holo_knight", "blade_duelist", "blade_duelist_2", "nano_medic", "glyph_wizard", id], "등록부 = 「비우기」 + 명부")
	check_eq(range(7).map(func(i: int) -> bool: return g.roster_inv.rows[i].dimmed), [false, true, true, true, true, true, false],
		"판 위 대원은 흐림")
	check_eq(g.banner.lines(), ["파티 편성과 순서를 정한다", "바꿀 칸을 고른다", false], "띠: 판 도움말")
	# 비운 판 「결정」.
	var gen0 := s.state.generation
	var h0 := kit.hash_now()
	for i in 5:
		await kit.tap(kit.center_of(g.board.slots[0 if i < 3 else 3]))
		check_eq(g.form_focus, "roster", "칸 → 등록부(%d)" % i)
		await kit.tap(kit.center_of(g.roster_inv.rows[0]))
	check_eq([g.board.front, g.board.back], [[], []], "모두 비움")
	await kit.tap(kit.center_of(g.board.decide_button))
	check_eq([g.page, g.notice, kit.hash_now(), s.state.generation], ["form", "파티에 대원이 없다", h0, gen0], "빈 판 결정 → 이유, 저장 없음")
	# 취소 = 초안 버림.
	await kit.press_key(KEY_ESCAPE)
	check_eq([g.page, g.root_cursor, kit.hash_now()], ["root", 2, h0], "Esc → 뿌리(커서 편성), 바뀐 것 없음")
	await kit.press_key(KEY_3)
	check_eq(g.board.members(), party0, "다시 들어오면 지금 파티(초안은 버렸다)")
	# 여섯은 안 된다.
	await kit.tap(kit.center_of(g.board.slots[5]))
	for i in 6:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq([g.board.back.size(), g.board.id_at(5)], [3, id], "빈 칸 → (↓ 여섯·선택) 해커 넣기(여섯)")
	await kit.tap(kit.center_of(g.board.decide_button))
	check_eq([g.notice, kit.hash_now()], ["파티는 5명까지다", h0], "여섯 → 이유")
	# 위저드 칸에 해커.
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_3)
	check_eq(g.board.members(), party0, "여섯 초안도 버렸다")
	var wiz := g.board.slot_of("glyph_wizard")
	await kit.tap(kit.center_of(g.board.slots[wiz]))
	check_eq([g.board.held, g.form_focus], [wiz, "roster"], "위저드 칸 고름")
	check_eq(g.banner.lines()[1], "그 칸에 넣을 대원을 고른다", "띠: 등록부 도움말")
	g.roster_inv.show_at(6)
	await kit.frames(1)
	await kit.tap(kit.center_of(g.roster_inv.rows[6]))
	check_eq([g.board.id_at(wiz), g.board.held, g.form_focus], [id, -1, "board"], "(내려서 누르기) 해커가 그 칸에")
	await kit.tap(kit.center_of(g.board.decide_button))
	await kit.frames(2)
	var want: Array = party0.map(func(x: String) -> String: return id if x == "glyph_wizard" else x)
	check_eq(s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id), want, "파티 = 위저드 자리에 해커")
	check(GuildRules.find(s.state, "glyph_wizard") != null and not s.state.party.members.has(GuildRules.find(s.state, "glyph_wizard")), "위저드는 길드로")
	_check_saved(s, gen0, "편성")
	check_eq([g.page, g.root_cursor, g.notice], ["root", 2, "파티를 편성했다"], "뿌리로, 안내")
	check_eq(g.cards.cards.map(func(c: BattleCard) -> String: return c.class_id), PartyNames.class_ids(s.state), "뿌리 카드는 새 파티로 다시 만든다")
	check(g.cards.cards.any(func(c: BattleCard) -> bool: return c.class_id == "class.hex_hacker"), "카드에 해커")
	var h := kit.hash_now()
	s = await _reload()
	check_eq([kit.hash_now(), s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id)], [h, want], "다시 연 화면: 같은 파티")


# ---- 캠프 「대열」 ----

## 캠프 「대열」(설계 §4.1b, seq=2): 같은 편성 판, 등록부 목록 없음. 칸 → 칸 = 두 칸 바꾸기(빈칸이면 그 열 끝), 빈칸을 먼저 고르면 이유,
## 「결정」 = DungeonScreen.arrange_party → 자동 저장 = 화면 → 다시 읽기 → 전투 유닛 차례. 키패드(실제 누르기) = 키.
func test_camp_arrange_board_swaps_saves_and_drives_battle() -> void:
	timeout_sec = 180.0
	_kit()
	var prep := func(sc: DungeonScreen) -> void:
		sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		sc.url_query = "debug=1"
	var s: DungeonScreen = await kit.open("native", 7, "debug=1", prep)
	s.state.encounter.threshold = 99999
	await kit.frames(2)
	var pm := s.party_menu
	var party0: Array = s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab], ["sub", 5], "캠프 5 → 대열")
	var board := pm.arrange_tab.board
	check(board.is_visible_in_tree() and pm.find_child("RosterList", true, false) == null, "편성 판, 등록부 목록 없음")
	check_eq(board.members(), party0, "판 = 지금 파티")
	check_eq(board.slots.map(func(b: ListButton) -> String: return b.icon_name), ["kind_sword", "kind_sword", "kind_sword", "kind_staff", "kind_staff", ""],
		"칸 아이콘 칸 = 주무기 종류(빈칸은 없음)")
	check(pm.notice_line.visible and pm.notice_line_text() == "대열 바꾸기", "알림 줄 = 「대열 바꾸기」")
	# 키패드 = 키: 같은 처음에서 같은 차례를 누른다(↓ ↓ ↓ 선택 ↓ 선택 = 칸 3 ↔ 칸 4).
	var seq := ["down", "down", "down", "ok", "down", "ok"]
	for k in seq:
		await kit.tap(kit.center_of(pm.dir_pad.button(k) if k == "down" else pm.active_key_pad().button(k)), FINGER)
	var by_pad := pm.arrange_tab.debug_info()
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_5)
	check_eq(board.members(), party0, "다시 들어오면 초안을 버린다")
	for k in seq:
		await kit.press_key(PartyMenu.PAD_KEYS[k])
	check_eq(pm.arrange_tab.debug_info(), by_pad, "키패드 차례 = 키 차례 %s" % str(by_pad))
	check_eq([board.id_at(3), board.id_at(4)], [party0[4], party0[3]], "칸 3 ↔ 칸 4")
	# 빈칸 먼저 고르기 → 이유.
	await kit.tap(kit.center_of(board.slots[5]))
	check_eq([board.held, pm.notice], [-1, "대원이 있는 칸을 고른다"], "빈칸 → 이유")
	# 고른 칸 → Esc 는 놓기만.
	await kit.tap(kit.center_of(board.slots[0]))
	check_eq(board.held, 0, "칸 0 고름")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.tab, board.held], ["sub", 5, -1], "Esc → 고른 칸만 놓음")
	var gen0 := s.state.generation
	await kit.tap(kit.center_of(board.decide_button))
	await kit.frames(2)
	var want := [party0[0], party0[1], party0[2], party0[4], party0[3]]
	check_eq(s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id), want, "결정 → 파티 차례")
	check_eq(pm.notice, "대열을 바꿨다", "안내")
	var a := _auto(s)
	check(s.state.generation > gen0 and a.ok() and SaveCodec.state_hash(a.state) == kit.hash_now(), "자동 저장 = 화면")
	await kit.tap(kit.center_of(board.decide_button))
	check_eq(pm.notice, "바뀐 것이 없다", "그대로 결정 → 이유")
	var h := kit.hash_now()
	s = await kit.reopen(prep)
	await kit.frames(2)
	check_eq([kit.hash_now(), s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id)], [h, want], "다시 연 화면: 같은 차례")
	var st: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_start"})))
	check(st is Dictionary and st.get("ok") == true, "battle_start")
	await kit.frames(2)
	if s.state.battle != null:
		check_eq(s.state.battle.party.map(func(u: BattleUnit) -> String: return u.def_id), want, "전투 유닛 차례")


# ---- U6 층 표·누를 자리·키패드 ----

const PAGES := {
	"root": [], "class": [["row", 0]], "look": [["row", 0], ["confirm"]], "manage": [["row", 1]],
	"manage_menu": [["row", 1], ["roster", 5]], "form": [["row", 2]], "form_roster": [["row", 2], ["slot", 3]],
	"remove": [["row", 1], ["roster", 5], ["row", 1]], "register": [["row", 0], ["confirm"], ["confirm"]],
}


func _to_page(g: GuildScreen, name: String) -> void:
	for st in PAGES[name]:
		await _step(g, st[0], st[1] if (st as Array).size() > 1 else null)
	if name == "register":
		g.name_entered("시험")
		await kit.frames(1)


## U6 (M-U6 외형 띠 폭 60): 1280×720·1728×720·1280×960 에서 쪽마다 층 표 자리, 누를 것은 모두 64 이상·화면 안, 왼쪽 목록은 방향 패드 위,
## 확인 창은 키패드와 겹치지 않는다(U7: 창이 가려지지 않는다).
func test_layer_boxes_and_targets_at_three_sizes() -> void:
	for px in SIZES:
		for name in PAGES:
			var g := await _fresh(_state(true), px)
			await _to_page(g, name)
			var size := tree.root.get_visible_rect().size
			var tag := "%s %s" % [str(px), name]
			var screen := Rect2(Vector2.ZERO, size)
			var dpad := _rect(g.dir_pad)
			check_eq(dpad.position, Vector2(8, size.y - 209), tag + ": 방향 패드")
			var kp := _rect(g.active_key_pad())
			check_eq(kp.position, Vector2(size.x - 118, size.y - 172) if name in ["class", "look", "register"] else Vector2(size.x - 247, size.y - 293), tag + ": 「취소」「선택」")
			var bs := g.visible_buttons()
			check(not bs.is_empty(), tag + ": 누를 것이 있다")
			for b in bs:
				var r := g.clipped_rect(b) if not (b.get_parent() is VirtualPad) else b.get_global_rect()
				check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str(b.size)])
				check(screen.encloses(r.grow(-0.5)), "%s: %s %s 가 화면 안" % [tag, b.name, str(r)])
				if not (b.get_parent() is VirtualPad):
					check(not r.intersects(dpad) and not r.intersects(kp), "%s: %s 는 키패드와 겹치지 않음" % [tag, b.name])
			check_eq(_rect(g.banner), Rect2(192, 0, size.x - 192, 100), tag + ": 띠")
			match name:
				"root":
					check_eq(_rect(g.root_list), Rect2(0, 166, 430, FacilityList.content_height(5, 3, 3)), tag + ": 뿌리 목록")
					check_eq(_rect(g.money_plate), Rect2(0, 112, 340, 50), tag + ": 소지금")
					check_eq(_rect(g.camp_plate), Rect2(0, 0, 176, 100), tag + ": 캠프 문패")
					check_eq(_rect(g.npc), Rect2(size.x - 560, 0, 560, size.y), tag + ": 길드장")
					check(g.camp_plate.visible and g.money_plate.visible and g.cards.visible, tag + ": 뿌리만 캠프 문패·소지금·카드")
				"class":
					check_eq(_rect(g.class_window), Rect2(48, 80, 340, 430), tag + ": 직업 목록")
					check_eq(_rect(g.class_plate), Rect2(460, 16, 360, 48), tag + ": 직업 문패")
					check_eq(_rect(g.class_sheet), Rect2(400, 96, size.x - 448, 252), tag + ": 직업 판")
					check_eq(_rect(g.class_desc), Rect2(400, 356, size.x - 448, 176), tag + ": 설명 상자")
					check(not _rect(g.class_desc).intersects(kp), tag + ": 설명 상자는 세로 키패드 위")
					check(not g.camp_plate.visible and not g.cards.visible, tag + ": 캠프 문패·카드 감춤")
				"look":
					check_eq([_rect(g.strips[0]), _rect(g.strips[1])], [Rect2(48, 80, 140, 420), Rect2(200, 80, 140, 420)], tag + ": 외형 띠 둘")
					check_eq(_rect(g.look_msg), Rect2(216, 520, 444, 120), tag + ": 말 상자")
					check_eq(_rect(g.look_portrait), Rect2(size.x - 560, 40, 420, size.y - 80), tag + ": 큰 그림")
					check(not _rect(g.look_portrait).intersects(kp), tag + ": 큰 그림은 세로 키패드에 가려지지 않는다")
					check(not _rect(g.look_msg).intersects(dpad) and not _rect(g.look_msg).intersects(kp), tag + ": 말 상자는 패드와 겹치지 않음")
				"manage", "manage_menu", "remove":
					check_eq(_rect(g.roster_window), Rect2(48, 112, 376, 360), tag + ": 등록부")
					if name == "manage":
						check_eq(GuildRules.rename(g.state, "holo_knight", "가나다라마바사아", [])[0]["type"], "renamed", tag + ": 준비: 8자 이름")
						g.refresh_view()
						await kit.frames(1)
						check(g.roster_inv.rows[0].text == "가나다라마바사아" and g.roster_inv.rows[0].right == "파티"
							and g.roster_inv.rows[0].clipped_parts().is_empty(), tag + ": 8자 이름과 「파티」가 한 줄에 잘리지 않고 든다")
					if name != "manage":
						check_eq(_rect(g.manage_window), Rect2(440, 112, 300, 222), tag + ": 작은 목록")
				"form", "form_roster":
					check_eq(_rect(g.roster_window), Rect2(48, 112, 376, 360), tag + ": 등록부")
					check_eq(_rect(g.board), Rect2(440, 112, 440, 594), tag + ": 편성 판")
					check(not _rect(g.board).intersects(_rect(g.roster_window)), tag + ": 판과 등록부는 겹치지 않는다")
					check(_rect(g.board).end.y <= size.y and not _rect(g.board).intersects(kp), tag + ": 판은 화면 안·키패드와 겹치지 않음")
			if g.dialog.is_open():
				var wr := g.dialog.window_rect()
				check(screen.encloses(wr) and not wr.intersects(kp) and not wr.intersects(dpad), "%s: 창 %s 는 화면 안, 패드에 가려지지 않음" % [tag, str(wr)])
			for c in [g.root_list, g.class_window, g.roster_window]:
				if (c as Control).is_visible_in_tree():
					check(_rect(c).end.y <= dpad.position.y + 0.5, "%s: %s 는 방향 패드 위에서 끝난다" % [tag, c.name])


func _parity(cases: Array) -> void:
	for c in cases:
		var tag: String = c[0]
		var k: String = c[2]
		var g := await _fresh(_state(true))
		await _to_page(g, c[1])
		var pre := _sig(g)
		var on: bool = g.pad_state()[k]
		check_eq(on, c[3], tag + ": 켜짐/흐림")
		var b := _pad_button(g, k)
		check(b.is_visible_in_tree() and b.disabled == not on, tag + ": 단추가 보이고 흐림이 상태와 같다")
		await kit.tap(kit.center_of(b), FINGER)
		var by_pad := _sig(g)
		g = await _fresh(_state(true))
		await _to_page(g, c[1])
		check_eq(_sig(g), pre, tag + ": 준비가 같다")
		await kit.press_key(GuildScreen.PAD_KEYS[k])
		check_eq(by_pad, _sig(g), tag + ": 키패드 = 키")
		if not on or c[4]:
			check_eq(by_pad, pre, tag + ": 아무것도 바꾸지 않는다")
		else:
			check(int(by_pad[-1]) == int(pre[-1]) + 1, "%s: 켜진 단추는 입력 하나" % tag)


## U6: 쪽마다 키패드(실제 누르기) = 키, 흐린 단추는 아무것도 하지 않는다.
func test_pad_matches_keys_on_every_page() -> void:
	_kit()
	await _parity([
		["뿌리 ↑", "root", "up", true, false], ["뿌리 ←", "root", "left", false, false], ["뿌리 선택", "root", "ok", true, false],
		["뿌리 취소", "root", "back", true, false],
		["직업 ↓", "class", "down", true, false], ["직업 ↑(끝)", "class", "up", true, true], ["직업 →", "class", "right", false, false],
		["직업 선택", "class", "ok", true, false], ["직업 취소", "class", "back", true, false],
		["외형 →", "look", "right", true, false], ["외형 ←(끝)", "look", "left", false, false], ["외형 ↓", "look", "down", false, false],
		["외형 선택", "look", "ok", true, false], ["외형 취소", "look", "back", true, false],
		["등록부 ↓", "manage", "down", true, false], ["등록부 선택", "manage", "ok", true, false], ["등록부 →", "manage", "right", false, false],
		["작은 목록 ↓", "manage_menu", "down", true, false], ["작은 목록 선택", "manage_menu", "ok", true, false],
		["작은 목록 취소", "manage_menu", "back", true, false],
		["판 ↓", "form", "down", true, false], ["판 →", "form", "right", true, false], ["판 선택", "form", "ok", true, false],
		["판 취소", "form", "back", true, false],
		["판 등록부 ↓", "form_roster", "down", true, false], ["판 등록부 ←", "form_roster", "left", true, false],
		["판 등록부 선택", "form_roster", "ok", true, false], ["판 등록부 취소", "form_roster", "back", true, false],
		["지우기 확인 ←", "remove", "left", true, false], ["지우기 확인 ↑", "remove", "up", false, false],
		["지우기 확인 선택", "remove", "ok", true, false], ["지우기 확인 취소", "remove", "back", true, false],
		["등록 확인 선택", "register", "ok", true, false], ["등록 확인 취소", "register", "back", true, false],
	])


# ---- 커서가 바뀌면 누르기를 버린다(검토 seq=7) ----

## 누르고 있던 단추(target)가 있는 채로 커서를 옮기면(variant "pad" = 다른 손가락 4 로 방향 패드 ↓, "key" = 키보드 ↓) 그 누르기는 취소되어
## 뗄 때 아무것도 하지 않는다. 옮긴 뒤 화면 = 뗀 뒤 화면.
func _held_then_move(page_name: String, target: Callable, variant: String, tag: String) -> void:
	var g := await _fresh(_state(true))
	await _to_page(g, page_name)
	var b: TouchButton = target.call(g)
	var p := kit.center_of(b)
	var pre := _sig(g)
	kit.touch(FINGER, p, true)
	await kit.frames(1)
	check(b.held, tag + ": 준비: 누르는 중")
	if variant == "pad":
		await kit.tap(kit.center_of(g.dir_pad.button("down")), FINGER + 1)
	else:
		await kit.press_key(KEY_DOWN)
	var moved := _sig(g)
	check(moved != pre, tag + ": 커서가 옮겨졌다")
	check(not b.held, tag + ": 커서가 바뀌면 누르기 취소")
	kit.touch(FINGER, p, false)
	await kit.frames(2)
	check_eq(_sig(g), moved, tag + ": 뗄 때 아무 일 없음(바뀐 커서로 일하지 않는다)")


## M-H1~M-H4(문맥이 옛 커서를 읽음): 직업 줄(줄 1 을 누른 채 커서 0 → 1: 떼면 외형으로 가던 검토 재현)과 키패드 「선택」을 누른 채 커서를
## 옮기는 곳 — 직업·등록부(관리)·작은 목록·편성 판·편성 등록부. 두 손가락(실제 터치)과 키보드 두 가지.
func test_cursor_change_drops_held_presses() -> void:
	_kit()
	var ok := func(g: GuildScreen) -> TouchButton: return g.active_key_pad().button("ok")
	var cases := [
		["직업 줄 1", "class", func(g: GuildScreen) -> TouchButton: return g.class_inv.rows[1]],
		["직업 「선택」", "class", ok], ["등록부 「선택」", "manage", ok], ["작은 목록 「선택」", "manage_menu", ok],
		["편성 판 「선택」", "form", ok], ["편성 등록부 「선택」", "form_roster", ok],
	]
	for c in cases:
		for v in ["pad", "key"]:
			await _held_then_move(c[1], c[2], v, "%s(%s)" % [c[0], v])


## M-H5(캠프 「대열」 문맥에 판 커서가 없음): 키패드 「선택」을 누른 채 판 커서를 옮기면(두 손가락·키보드) 뗄 때 칸을 고르지 않는다.
func test_camp_arrange_cursor_change_drops_held_ok() -> void:
	timeout_sec = 120.0
	_kit()
	var s: DungeonScreen = await kit.open("native", 7)
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	var board := pm.arrange_tab.board
	check_eq([pm.page, pm.tab, board.cursor, board.held], ["sub", 5, 0, -1], "준비: 대열, 커서 0")
	for v in ["pad", "key"]:
		var b := pm.active_key_pad().button("ok")
		var p := kit.center_of(b)
		var c0 := board.cursor
		kit.touch(FINGER, p, true)
		await kit.frames(1)
		check(b.held, v + ": 준비: 「선택」 누르는 중")
		if v == "pad":
			await kit.tap(kit.center_of(pm.dir_pad.button("down")), FINGER + 1)
		else:
			await kit.press_key(KEY_DOWN)
		check_eq(board.cursor, c0 + 1, v + ": 커서 +1")
		check(not b.held, v + ": 커서가 바뀌면 「선택」 누르기 취소")
		kit.touch(FINGER, p, false)
		await kit.frames(2)
		check_eq([board.held, board.cursor], [-1, c0 + 1], v + ": 뗄 때 칸을 고르지 않는다")


## 확인 창 답을 옮긴다: 「예」면 →, 「아니오」면 ←(pad: 손가락 4 로 방향 패드, key: 방향키).
func _move_answer(pad: VirtualPad, pick: int, variant: String) -> void:
	var right := pick == ShopDialog.YES
	if variant == "pad":
		await kit.tap(kit.center_of(pad.button("right" if right else "left")), FINGER + 1)
	else:
		await kit.press_key(KEY_RIGHT if right else KEY_LEFT)


## M-H9(답 커서가 바뀌어도 누르기를 버리지 않음, 검토 seq=9): 등록·지우기 확인 창에서 키패드 「선택」·「예」·「아니오」를 손가락 3 으로 누른 채
## 답을 옮기면(손가락 4 방향 패드·방향키) 그 누르기는 풀리고, 떼도 등록·지우기·저장이 없다(창은 옮긴 답 그대로).
## 답을 옮기지 않고 「예」를 누르면 그대로 등록·지우기하고 저장한다.
func test_answer_change_drops_held_presses() -> void:
	_kit()
	var targets := [
		["「선택」", func(g: GuildScreen) -> TouchButton: return g.active_key_pad().button("ok")],
		["「예」", func(g: GuildScreen) -> TouchButton: return g.dialog.yes_button],
		["「아니오」", func(g: GuildScreen) -> TouchButton: return g.dialog.no_button],
	]
	for page_name in ["register", "remove"]:
		var g := await _fresh(_state(true))
		await _to_page(g, page_name)
		var first := ShopDialog.YES if page_name == "register" else ShopDialog.NO
		check_eq([g.dialog.mode, g.dialog.pick, saves], ["confirm", first, 0], page_name + ": 준비: 확인 창")
		for t in targets:
			for v in ["pad", "key"]:
				var tag := "%s %s(%s)" % [page_name, t[0], v]
				var b: TouchButton = t[1].call(g)
				var p := kit.center_of(b)
				var pick0 := g.dialog.pick
				kit.touch(FINGER, p, true)
				await kit.frames(1)
				check(b.held, tag + ": 준비: 누르는 중")
				await _move_answer(g.dir_pad, pick0, v)
				check_eq(g.dialog.pick, 1 - pick0, tag + ": 답이 옮겨졌다")
				check(not b.held, tag + ": 답이 바뀌면 누르기 취소")
				var moved := _sig(g)
				kit.touch(FINGER, p, false)
				await kit.frames(2)
				check_eq(_sig(g), moved, tag + ": 뗄 때 아무 일 없음(등록·지우기·저장 없음)")
		check_eq([g.dialog.mode, saves, GuildRules.roster(g.state).size()], ["confirm", 0, 6], page_name + ": 창 그대로, 저장 없음, 명부 그대로")
		# 보통 흐름: 답을 옮기지 않고 「예」를 누른다.
		await kit.tap(kit.center_of(g.dialog.yes_button))
		await kit.frames(2)
		check_eq([g.dialog.mode, saves, GuildRules.roster(g.state).size()], ["", 1, 7 if page_name == "register" else 5],
			page_name + ": 「예」 → 일하고 저장 1")


## M-H9 실제 화면(검토 재현): 미궁 화면·자동 저장. 지우기 확인(「아니오」 먼저)에서 키패드 「선택」을 누른 채 손가락 4 로 ←(「예」) → 떼도
## 지우지 않고 저장하지 않는다(세대·자동 저장 그대로). 그 뒤 「예」를 누르면 지우고 자동 저장한다.
func test_held_select_across_an_answer_change_removes_nothing() -> void:
	var s := await _town()
	var r := GuildRules.register(s.state, "class.rail_ranger", 0, "레일", [])
	var id: String = r[0]["id"]
	s._autosave()
	var g := await _open_guild(s)
	await kit.press_key(KEY_2)
	for i in 5:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	await kit.tap(kit.center_of(g.manage_inv.rows[1]))
	check_eq([g.dialog.mode, g.dialog.pick, g.managed_member().id], ["confirm", ShopDialog.NO, id], "준비: 지우기 확인, 「아니오」 먼저")
	var gen0 := s.state.generation
	var h0 := kit.hash_now()
	var ok := g.active_key_pad().button("ok")
	var p := kit.center_of(ok)
	kit.touch(FINGER, p, true)
	await kit.frames(1)
	check(ok.held, "준비: 「선택」 누르는 중")
	await kit.tap(kit.center_of(g.dir_pad.button("left")), FINGER + 1)
	check_eq(g.dialog.pick, ShopDialog.YES, "← → 「예」")
	check(not ok.held, "답이 바뀌면 「선택」 누르기 취소")
	kit.touch(FINGER, p, false)
	await kit.frames(3)
	check_eq([GuildRules.find(s.state, id) != null, s.state.generation, kit.hash_now(), g.dialog.mode, g.dialog.pick],
		[true, gen0, h0, "confirm", ShopDialog.YES], "뗄 때 지우지 않고 저장하지 않는다")
	var a := _auto(s)
	check(a.ok() and GuildRules.find(a.state, id) != null, "자동 저장에도 그대로")
	await kit.tap(kit.center_of(g.dialog.yes_button))
	await kit.frames(2)
	check(GuildRules.find(s.state, id) == null, "「예」 → 지웠다")
	_check_saved(s, gen0, "지우기")


## M-H7(이름 칸 52)·M-H8(메모 칸 52): PC 이름 창의 NameEdit·확인·취소와 지도 메모 창의 MemoEdit·확인·취소는 1280×720·1728×720·1280×960 에서
## 64 이상이고 화면 안이다.
func test_native_text_entry_targets_at_three_sizes() -> void:
	for px in SIZES:
		var size := await _window(px)
		var s := await _town()
		var g := await _open_guild(s)
		await kit.press_key(KEY_1)
		await kit.press_key(KEY_ENTER)
		await kit.press_key(KEY_ENTER)
		await kit.frames(2)
		var tag := str(px)
		check_eq([g.page, s.modal.kind], ["look", "name"], tag + ": 준비: 이름 창")
		var screen := Rect2(Vector2.ZERO, size)
		for n in ["NameEdit", "NameOk", "NameCancel"]:
			var c := s.modal.find_child(n, true, false) as Control
			check(c != null, "%s: %s" % [tag, n])
			if c == null:
				continue
			var r := c.get_global_rect()
			check(r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s %s ≥ 64" % [tag, n, str(r.size)])
			check(screen.encloses(r), "%s: %s %s 가 화면 안" % [tag, n, str(r)])
		kit.dispose()
		kit = null
	# 지도 메모 창(M-H8 메모 칸 52): MemoEdit·확인·취소도 64 이상(seq=8, 이름 창과 같은 기준).
	for px in SIZES:
		var size := await _window(px)
		_kit()
		var s: DungeonScreen = await kit.open("native", 7)
		await kit.open_map()
		s.map.tool = "memo"
		await kit.tap(kit.map_cell(Vector2i(3, 18)))
		await kit.frames(2)
		var tag := "%s 메모" % str(px)
		check_eq(s.modal.kind, "memo", tag + ": 준비: 메모 창")
		var screen := Rect2(Vector2.ZERO, size)
		for n in ["MemoEdit", "MemoOk", "MemoCancel"]:
			var c := s.modal.find_child(n, true, false) as Control
			check(c != null, "%s: %s" % [tag, n])
			if c == null:
				continue
			var r := c.get_global_rect()
			check(r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s %s ≥ 64" % [tag, n, str(r.size)])
			check(screen.encloses(r), "%s: %s %s 가 화면 안" % [tag, n, str(r)])
		kit.dispose()
		kit = null


# ---- U7 안내 ----

## U7: 안내는 두 줄까지(띠 첫·둘째 줄), 쌓이지 않고 새 안내가 바꾼다, 시간이 지나면 띠는 쪽 설명으로. 외형 쪽 안내는 말 상자에.
func test_notices_are_two_lines_replace_and_expire() -> void:
	var g := await _fresh(_state(true))
	await _step(g, "row", 3)
	check_eq(g.banner.lines(), ["길드장과 이야기한다", "길드장이 자리를 비웠다", true], "한 줄 안내 = 둘째 줄")
	g.show_notice("첫 줄\n둘째 줄")
	check_eq(g.banner.lines(), ["첫 줄", "둘째 줄", true], "두 줄 안내 = 띠 두 줄")
	g.show_notice("새 안내")
	check_eq([g.notice, g.banner.lines()], ["새 안내", ["길드장과 이야기한다", "새 안내", true]], "새 안내가 바꾼다(쌓이지 않는다)")
	g._process(GuildScreen.NOTICE_SEC + 0.1)
	check_eq([g.notice, g.banner.lines()], ["", ["길드장과 이야기한다", "", false]], "시간이 지나면 지운다")
	await _step(g, "row", 0)
	check_eq(g.notice, "", "쪽을 옮기면 지운다")
	await _step(g, "confirm")
	g.show_notice("외형 안내")
	await kit.frames(1)
	check_eq(_texts_of(g.look_msg), ["외형 안내"], "외형 쪽 안내 = 말 상자")
