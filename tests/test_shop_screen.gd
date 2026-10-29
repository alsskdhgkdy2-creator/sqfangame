## 상점 화면 시험(08 §8.12, S3a): 입구(디버그일 때만 「상점」, 캠프와 같은 여는 조건), 화면 차례와 한 단계 뒤로, 사기 흐름(확인 → 저장 →
## 장착 물음 → 무기 칸 0 / 방어구 칸 고르기 → 저장, 「아니오」마다 그대로), 이유 알림, 키 표 = 가상 키패드, 문맥 바뀜의 누르기 버림,
## 노랑 채움 하나, 키 시점(F2), 입력 갈고리(F3), best_slot(F5), 저장 실패(F6), 갈래 카드(F7), 64px·화면 안, 캠프 기본값.
## 미궁 화면을 띄우는 시험은 장면 시험 임시 폴더에만 저장한다. 상점만 띄우는 시험은 저장 갈고리를 센다(user://saves 는 쓰지 않는다).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const HM := preload("res://tests/held_matrix.gd")
const JUNK := "shop.junk_workshop"
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
const FINGER := 3
const PAD_NAMES := ["up", "down", "left", "right", "ok", "back"]
## 대원 칸(test_party): 0 홀로 나이트 [훈련용 홀로 블레이드, 트레이닝 실드, 패딩 코트, ""], 1 듀얼리스트 A [트윈 엣지, 패딩 코트, 그립 장갑, ""],
## 3 나노 메딕, 4 글리프 위저드 [글리프 스타일러스, 글리프 로브, 시그널 참, ""].
const KNIGHT := 0
const DUELIST := 1
const WIZARD := 4

var kit: Kit
var host: Control
var texts: TextDb
var saves := 0
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
		texts = TextDb.load_path("res://data/text/ko.json")


func _window(px: Vector2) -> Vector2:
	_kit()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 새 게임 상태(시드 1). money: 소지금.
func _state(money: int = 1000) -> ExplorationState:
	if _defs == null:
		_defs = Fx.defs()
	var s := ExplorationRules.new_game(_defs, 1, "floor")
	s.money = money
	return s


## 소재를 팔아 풀린 줄·한정 품절 줄·NEW 아닌 줄이 있는 상태(08 §7.7 과 같은 실데이터). 소지금 300(이온 세이버 360 흐림).
func _sold_state() -> ExplorationState:
	var s := _state(2000)
	s.materials = {"item.cable_scale": 3, "item.glow_scale": 1, "item.beetle_plate": 2, "item.intact_pincer": 1}
	var ev := ShopRules.sell(s, JUNK, [{"item": "item.cable_scale", "qty": 3}, {"item": "item.glow_scale", "qty": 1},
		{"item": "item.beetle_plate", "qty": 2}, {"item": "item.intact_pincer", "qty": 1}])
	check(ev.size() == 2 and ev[1]["type"] == "unlocked", "준비: 팔아서 풀림")
	check(ShopRules.buy(s, JUNK, "equip.aegis_plate", 1)[0]["type"] == "bought", "준비: 한정 줄 사기(재고 0)")
	check(ShopRules.buy(s, JUNK, "equip.training_sword", 1)[0]["type"] == "bought", "준비: 사기(NEW 아님)")
	s.money = 300
	return s


## 「아이템」 진열이 없는 묶음(상점 파일에서 소모품 줄을 뺀 정의)의 새 게임, 소지금 1000. 빈 구매 목록 시험용:
## M3 A4b 부터 실제 「아이템」 갈래는 늘 파는 소모품 넷이 있어 빈 목록이 아니다(설계 §7.2: 빈 구매 목록은 빈 갈래로 계속 본다).
func _no_items_state() -> ExplorationState:
	var files := Fx.battle_files()
	files["shop/junk_workshop.json"]["stock"] = (files["shop/junk_workshop.json"]["stock"] as Array).filter(
		func(l: Dictionary) -> bool: return not str(l["item"]).begins_with("use."))
	var s := ExplorationRules.new_game(Fx.defs_from(files), 1, "floor")
	s.money = 1000
	return s


## 판매용 상태: 소재(자료 차례) 네온 쥐 꼬리 3 · 케이블 인분 1 · 포자 주머니 2 · 드릴 발톱 4, 가방에 트윈 엣지 1, 소지금 1000.
## 꼬리 3 을 팔면 바이저, 드릴 발톱 3 이상을 팔면 전술 배턴·마그 부츠가 풀린다.
func _sell_state() -> ExplorationState:
	var s := _state(1000)
	s.materials = {"item.neon_rat_tail": 3, "item.cable_scale": 1, "item.spore_pouch": 2, "item.drill_claw": 4}
	s.gear_bag["equip.twin_edge"] = 1
	return s


## 미궁 화면 없이 상점만(창 크기 px, 화면 전체). 저장 갈고리는 센다.
func _fresh(s: ExplorationState = null, px: Vector2 = WINDOWS[0]) -> ShopScreen:
	timeout_sec = 120.0
	await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	saves = 0
	host = Control.new()
	host.name = "ShopHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sc := ShopScreen.new()
	host.add_child(sc)
	sc.build(texts)
	sc.save_hook = func() -> void: saves += 1
	sc.open(s if s != null else _state())
	await kit.frames(2)
	return sc


func _step(sc: ShopScreen, kind: String, arg: Variant = null) -> bool:
	var ok := sc.handle(kind, arg)
	await kit.frames(1)
	return ok


## 구매 목록 갈래 b(0 무기·1 방어구·2 장신구·3 아이템)·탭 t 까지.
func _to_list(sc: ShopScreen, b: int, t: int = 0, who: int = 0) -> void:
	await _step(sc, "root", 0)
	await _step(sc, "branch", b)
	if t > 0:
		await _step(sc, "tab", t)
	while sc.member != who:
		await _step(sc, "member_step", 1)


## 지금 목록에서 물건 줄 번호(없으면 -1).
static func _row_of(sc: ShopScreen, item: String) -> int:
	for i in sc.lines.size():
		if sc.lines[i]["item"] == item:
			return i
	return -1


## 화면이 가진 것 전부(입력 하나가 바꿀 수 있는 것).
func _sig(sc: ShopScreen) -> Array:
	return [sc.is_open(), sc.page, sc.branch, sc.tab, sc.member, sc.root_cursor, sc.branch_cursor, sc.buy_list.cursor, sc.dialog.mode,
		sc.dialog.pick, sc.dialog.slot_cursor, sc.dialog.qty, sc.multi, sc.marked.keys(), sc.ask, sc.notice, SaveCodec.state_hash(sc.state),
		saves, sc.accepted_inputs]


static func _pad_button(sc: ShopScreen, k: String) -> TouchButton:
	return sc.dir_pad.button(k) if k in ["up", "down", "left", "right"] else sc.active_key_pad().button(k)


static func _yellow(sc: ShopScreen) -> Array:
	return sc.yellow_fills().map(func(b: TouchButton) -> String: return str(b.name))


# ---- 입구 ----

## M3 A2 (R4 S4): 입구는 마을 광장 「정크 공방」 줄이다(디버그와 상관없다). 캠프와 같은 막는 때·처음부터 열기는 그대로다.
func test_entrance_is_the_plaza_and_opens_like_the_camp() -> void:
	timeout_sec = 120.0
	_kit()
	var s := await kit.open_town("native", 7, "", func(sc: DungeonScreen) -> void: sc.native_debug = false)
	var town := s.town_screen
	check(town.is_open() and town.page == "plaza", "준비: 광장")
	check(s.find_child("ShopButton", true, false) == null, "안내 줄 「상점」 단추는 없다")
	check_eq(town.plaza_list.rows[1].name, &"Plaza_shop", "광장 둘째 줄 = 정크 공방")
	await kit.tap(kit.center_of(town.plaza_list.rows[1]))
	var sc := s.shop_screen
	check(sc.is_open() and sc.page == "root" and sc.root_cursor == 0 and sc.member == 0, "「정크 공방」 → 뿌리·커서 0·대원 0")
	check(not s.hud_root.visible and not town.visible and town.covered, "열린 동안 탐색 HUD·마을 화면을 감춘다")
	check_eq(s.town_backdrop.place, "shop", "바탕 = 상점 그림")
	var at := s.state.party.at
	for k in [KEY_P, KEY_W, KEY_M, KEY_UP]:
		await kit.press_key(k)
	check(sc.is_open() and not s.party_menu.is_open() and not s._map_open and s.state.party.at == at, "P·이동·M: 캠프·지도·이동 없음")
	s._open_party()
	check(not s.party_menu.is_open(), "상점이 열려 있으면 캠프는 열리지 않는다")
	await kit.press_key(KEY_ESCAPE)
	check(not sc.is_open() and town.visible and not town.covered, "뿌리 Esc → 닫힘, 광장 다시")
	check(not s.hud_root.visible and not s.view_container.visible, "광장으로 돌아와도 탐색 HUD·3D 시야는 감춘 채")
	check_eq([town.page, town.plaza_cursor, s.town_backdrop.place], ["plaza", 1, "plaza"], "광장 커서는 「정크 공방」 그대로, 바탕은 광장")
	# 다시 열면 뿌리·커서 0·대원 0, 알림 없음.
	sc.open(s.state)
	sc.handle("root_cursor", 2)
	await kit.frames(1)
	sc.handle("confirm")
	await kit.frames(1)
	check(not sc.notice.is_empty(), "준비: 대화 → 이유")
	sc.close_shop()
	await kit.frames(1)
	s._open_shop()
	check(sc.is_open() and sc.root_cursor == 0 and sc.notice.is_empty() and sc.page == "root", "다시 열면 처음부터")
	sc.close_shop()
	# 막는 때: 층 3 창, 캠프, 전투 대기.
	s._alert("x")
	s._open_shop()
	check(not sc.is_open(), "알림 창이 떠 있으면 열리지 않는다")
	s._close_alert()
	await kit.frames(1)
	s._open_party()
	s._open_shop()
	check(s.party_menu.is_open() and not sc.is_open(), "캠프가 열려 있으면 열리지 않는다")
	s.party_menu.close_menu()
	await kit.frames(1)
	s.state.encounter.pending = true
	s._open_shop()
	check(not sc.is_open(), "전투 대기면 열리지 않는다")
	s.state.encounter.pending = false
	# 광장 줄을 키로 고른다(2 = 정크 공방).
	await kit.press_key(KEY_2)
	check(sc.is_open(), "키 2 → 상점")
	var snap: Dictionary = s.debug_snapshot()
	check(snap["shop"]["open"] and snap["shop"]["page"] == "root" and snap["buttons"].has("Root_buy"), "스냅숏 shop 칸·단추")
	check(not snap["buttons"].has("Plaza_shop"), "상점이 덮은 광장 줄은 스냅숏에 없다")
	check_eq(snap["money"], s.state.money, "스냅숏 소지금")


## M3 A2: 미궁에서는 상점을 열 수 없다(디버그여도). 안내 줄은 「캠프」「지도」뿐이고 디버그 요청 open_shop 은 없다.
func test_shop_is_closed_in_the_labyrinth() -> void:
	timeout_sec = 120.0
	_kit()
	for q in ["debug=1", ""]:
		var s := await kit.open("native", 7, q)
		var shown := s.hint_row.get_children().filter(func(c: Node) -> bool: return (c as Control).visible)
		check_eq(shown, [s.camp_button, s.map_button], "안내 줄 = 「캠프」「지도」 (%s)" % q)
		s._open_shop()
		check(not s.shop_screen.is_open(), "미궁에서는 열리지 않는다 (%s)" % q)
		var r: Dictionary = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "open_shop"})))
		check_eq(r.get("error", ""), "unknown op", "디버그 요청 open_shop 은 없다 (%s)" % q)
		check(not s.shop_screen.is_open(), "요청으로도 열리지 않는다 (%s)" % q)
		kit.close_screen()
		await kit.frames(1)


# ---- 화면 차례 ----

func test_pages_go_forward_and_back_one_step_at_a_time() -> void:
	_kit()
	var sc := await _fresh(_sold_state())
	check_eq(sc.root_list.rows.map(func(r: ListRow) -> String: return r.text),
		["1  사기", "2  팔기", "3  대화", "4  장비 바꾸기", "5  나가기"], "뿌리 명령 다섯")
	check(sc.root_list.rows[2].dimmed and sc.root_list.rows[3].dimmed and not sc.root_list.rows[0].dimmed, "대화·장비 바꾸기는 흐리다")
	check_eq(sc.banner.lines().slice(0, 2), [texts.t("shop.desc.buy"), ""], "설명 띠 = 커서 명령 설명")
	check_eq(sc.plate.first, texts.t("shop.junk_workshop"), "문패 = 상점 이름")
	# 흐린 명령은 이유만.
	await kit.tap(kit.center_of(sc.root_list.rows[2]))
	check_eq([sc.page, sc.notice], ["root", texts.t("shop.why.talk")], "대화 → 이유")
	await kit.press_key(KEY_4)
	check_eq(sc.notice, texts.t("shop.why.equip"), "4 → 장비 바꾸기 이유")
	await kit.press_key(KEY_1)
	check_eq([sc.page, sc.branch_cursor], ["branch", 0], "1 → 구매 갈래")
	check(sc.root_list.rows[0].chosen and not sc.root_list.rows[0].selected, "「사기」 줄 = 고른 모양")
	check_eq(sc.banner.lines().slice(0, 2), [texts.t("shop.desc.branch"), texts.t("shop.desc.weapon")], "갈래 설명 띠")
	check(sc.plate.is_visible_in_tree() and sc.find_child("BranchBack", true, false) == null, "갈래: 상점 문패 그대로, 「뒤로」 없음(§8.2)")
	check(not await _step(sc, "root", 0), "「사기」를 다시 누르면 아무 일 없음")
	await kit.press_key(KEY_DOWN)
	check_eq(sc.banner.lines()[1], texts.t("shop.desc.armor"), "커서 갈래 설명")
	await kit.press_key(KEY_ENTER)
	check_eq([sc.page, sc.branch, sc.tab, sc.buy_list.cursor], ["buy", 1, 0, 0], "선택 → 방어구 목록, 탭 0·커서 0")
	check_eq(sc.frame.banner.lines()[0], texts.t("shop.desc.armor"), "목록 설명 띠 = 갈래 설명")
	check(sc.buy_tabs.visible and sc.buy_tabs.kinds.size() == 6, "방어구 탭 여섯")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_X)
	check_eq([sc.tab, sc.buy_list.cursor, sc.buy_list.scroll.scroll], [1, 0, 0.0], "X → 다음 탭, 커서 0·맨 위")
	await kit.tap(kit.center_of(sc.buy_tabs.buttons[3]))
	check_eq(sc.tab, 3, "탭 누르기")
	await kit.press_key(KEY_Z)
	await kit.press_key(KEY_PAGEUP)
	await kit.press_key(KEY_PAGEUP)
	await kit.press_key(KEY_PAGEUP)
	check_eq(sc.tab, 0, "Z·PageUp → 앞 탭, 끝에서 멈춘다")
	await kit.press_key(KEY_BACKSPACE)
	check_eq([sc.page, sc.branch_cursor], ["branch", 1], "Backspace → 갈래, 커서는 떠난 갈래")
	await kit.press_key(KEY_3)
	check(sc.page == "buy" and not sc.buy_tabs.visible and sc.frame.list_top == ShopFrame.LIST_TOP, "장신구: 탭 없음, 목록 창 위 172")
	await kit.tap(kit.center_of(sc.frame.back_button))
	await kit.press_key(KEY_4)
	check_eq(sc.lines.map(func(l: Dictionary) -> String: return l["item"]), ["use.medica", "use.theriaca_a", "use.theriaca_b", "use.ariadne_beacon"],
		"아이템: 늘 파는 소모품 넷, 진열 차례(M3 A4b)")
	check(not sc.buy_tabs.visible and sc.frame.list_top == ShopFrame.LIST_TOP, "아이템: 탭 없음(원작 아이템 목록), 목록 창 위 172")
	check(sc.pad_state()["ok"] and sc.buy_list.cursor == 0, "아이템: 커서 첫 줄, 선택 켜짐")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_1)
	check_eq([sc.branch, sc.tab], [0, 0], "다른 갈래로 들어오면 탭 0")
	await kit.press_key(KEY_ESCAPE)
	await kit.tap(kit.center_of(sc.active_key_pad().button("back")), FINGER)
	check_eq([sc.page, sc.root_cursor], ["root", 0], "갈래에서 키패드 「취소」 → 뿌리, 커서 「사기」")
	await kit.press_key(KEY_1)
	await kit.tap(kit.center_of(sc.root_list.rows[4]))
	check(not sc.is_open(), "갈래에서 「나가기」 → 닫기")


# ---- 사기 흐름 ----

func test_buying_a_weapon_saves_then_equips_slot_zero() -> void:
	_kit()
	var sc := await _fresh(_state(1000))
	await _to_list(sc, 0, 0, KNIGHT)
	var s := sc.state
	var i := _row_of(sc, "equip.twin_edge")
	check(i >= 0 and sc.lines[i]["new"], "준비: 트윈 엣지 NEW")
	# 「아니오」: 상태 그대로.
	var h0 := SaveCodec.state_hash(s)
	await kit.tap(kit.center_of(sc.buy_list.rows[i]))
	check_eq([sc.dialog.mode, sc.ask, sc.dialog.pick], ["confirm", "buy", ShopDialog.YES], "확인 창, 첫 커서 「예」(D25)")
	check_eq(sc.dialog.message, "120엔이다. 살까?", "확인 글")
	check_eq([sc.dialog.item_icon, sc.dialog.item_name], ["kind_sword", texts.t("equip.twin_edge")], "창 머리 [아이콘] 이름")
	check_eq(sc.buy_list.cursor_mode, "chosen", "창이 뜬 동안 목록 커서 = chosen")
	await kit.tap(kit.center_of(sc.dialog.no_button))
	check_eq([SaveCodec.state_hash(s), saves, sc.dialog.mode], [h0, 0, ""], "「아니오」 → 상태·저장 그대로")
	check_eq([sc.buy_list.cursor, sc.buy_list.cursor_mode], [i, "cursor"], "같은 줄, cursor")
	# 「예」 → 사기·저장 → 장착 물음 → 「예」 → 칸 0·저장.
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	check_eq([s.money, int(s.gear_bag.get("equip.twin_edge", 0)), s.shop.bought.has("equip.twin_edge"), saves], [880, 1, true, 1], "산 뒤 소지금·가방·산 물건·저장 1")
	check(not sc.lines[i]["new"] and not sc.buy_list.rows[i].is_new, "NEW 꺼짐")
	check_eq(sc.frame.title_text, "880엔", "소지금 문패")
	check_eq([sc.dialog.mode, sc.ask, sc.dialog.message], ["confirm", "equip", texts.t("shop.confirm.equip")], "장착 물음")
	await kit.press_key(KEY_ENTER)
	check_eq(s.party.members[KNIGHT].equip[0], "equip.twin_edge", "무기 칸 0 에 낌")
	check_eq([int(s.gear_bag.get("equip.twin_edge", 0)), int(s.gear_bag.get("equip.training_sword", 0)), saves], [0, 1, 2], "옛 무기는 가방, 저장 2")
	check_eq([sc.dialog.mode, sc.buy_list.cursor, sc.buy_list.cursor_mode], ["", i, "cursor"], "끝: 같은 줄·cursor")
	# 장착 물음에서 「아니오」: 산 것은 가방에 남고 저장 하나.
	saves = 0
	var j := _row_of(sc, "equip.glyph_stylus")
	sc.member = 3  # 나노 메딕(지팡이: 나노 로드를 끼고 있다)
	await _step(sc, "row", j)
	await _step(sc, "dialog", ["confirm", null])
	check_eq([sc.ask, saves], ["equip", 1], "준비: 산 뒤 장착 물음")
	await kit.press_key(KEY_ESCAPE)
	check_eq([int(s.gear_bag.get("equip.glyph_stylus", 0)), s.party.members[3].equip[0], saves, sc.dialog.mode], [1, "equip.nano_rod", 1, ""],
		"장착 물음 취소: 산 것은 가방에 남고 장비 그대로, 저장 하나")


func test_buying_armor_opens_the_slot_picker_with_best_slot_first() -> void:
	_kit()
	var sc := await _fresh(_state(1000))
	await _to_list(sc, 1, 0, WIZARD)
	await kit.press_key(KEY_3)  # 아무것도 하지 않는다(목록에 숫자 키 없음)
	check_eq(sc.page, "buy", "목록의 숫자 키는 아무 일 없음")
	await _step(sc, "branch", 2)  # 목록에서 갈래 입력은 받지 않는다
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_3)  # 장신구
	var s := sc.state
	var i := _row_of(sc, "equip.signal_charm")
	await _step(sc, "row", i)
	await _step(sc, "dialog", ["confirm", null])
	await _step(sc, "dialog", ["confirm", null])
	check_eq([sc.dialog.mode, sc.ask, sc.dialog.slot_cursor], ["slots", "slots", 3], "칸 고르기, 첫 커서 = best_slot 3(빈 칸)")
	check_eq(sc.dialog.slot_data.map(func(d: Dictionary) -> String: return d["text"]),
		["방어구 1  " + texts.t("equip.glyph_robe"), "방어구 2  " + texts.t("equip.signal_charm"), "방어구 3  비어 있음"], "칸 줄 글")
	check(sc.dialog.slot_buttons[1].dimmed and not sc.dialog.slot_buttons[0].dimmed and not sc.dialog.slot_buttons[2].dimmed, "같은 장신구 칸(unchanged)만 흐림")
	check(not sc.dialog.no_button.selected and sc.dialog.slot_buttons[2].selected, "노랑 = 칸 커서 하나")
	# 막힌 칸을 누르면 창 안 둘째 줄에 이유, 창 그대로.
	await kit.tap(kit.center_of(sc.dialog.slot_buttons[1]))
	check_eq([sc.dialog.mode, sc.dialog.slot_reason], ["slots", texts.t("growth.reason.unchanged")], "막힌 칸 → 이유, 창 그대로")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(sc.dialog.slot_cursor, 1, "↑ 끝에서 멈춘다")
	check(not await _step(sc, "dialog", ["slot_move", -1]), "칸 1 에서 ↑ 는 거부")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	check(not await _step(sc, "dialog", ["slot_move", 1]), "칸 3 에서 ↓ 는 거부")
	check_eq(saves, 1, "준비: 산 뒤 저장 1")
	await kit.press_key(KEY_ENTER)
	check_eq(s.party.members[WIZARD].equip[3], "equip.signal_charm", "칸 3 에 낌")
	check_eq([saves, sc.dialog.mode, int(s.gear_bag.get("equip.signal_charm", 0))], [2, "", 0], "저장 2, 창 닫힘")
	check_eq(sc.notice, texts.t("growth.event.equipped", {"member": texts.t("member.glyph_wizard"), "item": texts.t("equip.signal_charm")}), "장착 안내")
	# 칸 고르기 「아니오」: 끼지 않고 가방에 남는다.
	saves = 0
	sc.member = KNIGHT
	await _step(sc, "row", i)
	await _step(sc, "dialog", ["confirm", null])
	await _step(sc, "dialog", ["confirm", null])
	check_eq(sc.dialog.mode, "slots", "준비: 칸 고르기")
	await kit.tap(kit.center_of(sc.dialog.no_button))
	check_eq([s.party.members[KNIGHT].equip[3], int(s.gear_bag.get("equip.signal_charm", 0)), saves, sc.dialog.mode], ["", 1, 1, ""],
		"칸 고르기 「아니오」: 끼지 않고 가방, 저장은 산 것 하나")


func test_reasons_show_without_a_dialog_and_unfit_member_gets_no_equip_prompt() -> void:
	_kit()
	var s := _sold_state()
	var sc := await _fresh(s)
	await _to_list(sc, 0)
	var h := SaveCodec.state_hash(s)
	var saber := _row_of(sc, "equip.ion_saber")
	check(sc.lines[saber]["new"] and sc.buy_list.rows[saber].dimmed, "준비: 이온 세이버 흐림(돈 모자람)")
	await kit.tap(kit.center_of(sc.buy_list.rows[saber]))
	check_eq([sc.dialog.mode, sc.notice], ["", texts.t("shop.why.no_money")], "돈 모자람: 창 없이 이유")
	check_eq(sc.frame.banner.lines()[1], texts.t("shop.why.no_money"), "설명 띠 둘째 줄")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_2)
	var aegis := _row_of(sc, "equip.aegis_plate")
	check_eq(sc.lines[aegis]["stock"], 0, "준비: 이지스 품절")
	check_eq(sc.buy_list.rows[aegis].right, texts.t("shop.sold_out"), "품절 줄")
	await _step(sc, "row", aegis)
	check_eq(sc.notice, texts.t("shop.why.sold_out", {"items": "%s 2개, %s 1개" % [texts.t("item.beetle_plate"), texts.t("item.intact_pincer")]}),
		"품절: 모자란 소재와 수")
	check_eq(sc.dialog.mode, "", "품절: 창 없음")
	s.gear_bag["equip.padded_coat"] = 99
	await _step(sc, "member_step", 1)
	var coat := _row_of(sc, "equip.padded_coat")
	await _step(sc, "row", coat)
	check_eq([sc.dialog.mode, sc.notice], ["", texts.t("shop.why.bag_full")], "가방 99: 이유")
	s.gear_bag.erase("equip.padded_coat")
	check_eq(SaveCodec.state_hash(s).length() > 0 and saves == 0, true, "이유 알림은 저장하지 않는다")
	# 못 끼는 대원: buy_unfit, 산 뒤 장착 물음 없음.
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_1)
	while sc.member != WIZARD:
		await _step(sc, "member_step", 1)
	var tw := _row_of(sc, "equip.twin_edge")
	sc.state.money = 300
	await _step(sc, "row", tw)
	check_eq(sc.dialog.message, texts.t("shop.confirm.buy_unfit", {"price": "120", "member": texts.t("member.glyph_wizard")}), "못 끼는 대원: buy_unfit")
	check(sc.frame.panel.drawn["dim_equip"] and not sc.frame.panel.totals.comparing and sc.frame.panel.drawn["mark"] == -1, "판: 장비 줄 흐림, 비교 없음")
	check_eq(sc.frame.desc_lines, [sc.values_text("equip.twin_edge"), texts.t("growth.reason.class")] as Array[String], "설명 둘째 줄 = 직업 이유")
	await _step(sc, "dialog", ["confirm", null])
	check_eq([sc.dialog.mode, int(s.gear_bag.get("equip.twin_edge", 0)), saves], ["", 1, 1], "산 뒤 장착 물음 없음(가방에 둔다)")
	check(h != SaveCodec.state_hash(s), "산 것은 상태를 바꿨다")


# ---- best_slot(F5) ----

func test_best_slot_follows_the_candidate_order_and_never_mutates_state() -> void:
	_kit()
	var s := _state(5000)
	var sc := await _fresh(s)
	var bag := func(item: String) -> Dictionary: return sc.preview_bag(item)
	# 장신구 0개(듀얼리스트 A) → 빈 칸 3.
	check_eq(sc.best_slot("equip.signal_charm", DUELIST, bag.call("equip.signal_charm")), 3, "장신구 0개 → 빈 칸 3")
	# 장신구 1개(위저드: 칸 2 시그널 참) → 빈 칸 3.
	check_eq(sc.best_slot("equip.thermal_ring", WIZARD, bag.call("equip.thermal_ring")), 3, "장신구 1개 → 빈 칸 3")
	# 장신구 2개(제한에 닿음) → 그 종류가 든 칸 번호순: 칸 2 는 같은 물건(unchanged)이라 칸 3.
	s.party.members[WIZARD].equip[3] = "equip.thermal_ring"
	check_eq(sc.best_slot("equip.signal_charm", WIZARD, bag.call("equip.signal_charm")), 3, "장신구 2개·같은 장신구 칸 unchanged → 칸 3")
	check_eq(sc.best_slot("equip.antitox_chip", WIZARD, bag.call("equip.antitox_chip")), 2, "장신구 2개 → 든 칸 번호순 첫째 2")
	s.party.members[WIZARD].equip[3] = ""
	# 같은 몸·같은 무기 → -1.
	check_eq(sc.best_slot("equip.padded_coat", KNIGHT, bag.call("equip.padded_coat")), -1, "같은 몸 → -1")
	check_eq(sc.best_slot("equip.training_sword", KNIGHT, bag.call("equip.training_sword")), -1, "같은 무기 → -1")
	check_eq(sc.best_slot("equip.twin_edge", KNIGHT, bag.call("equip.twin_edge")), 0, "다른 무기 → 칸 0")
	# 몸 제한에 닿음 → 몸이 든 칸 1. 돌아갈 옛 장비가 가방 99 개면 bag_full → 다른 칸도 막혀 -1.
	check_eq(sc.best_slot("equip.mesh_armor", DUELIST, bag.call("equip.mesh_armor")), 1, "몸 제한 → 몸이 든 칸 1")
	s.gear_bag["equip.padded_coat"] = 99
	check_eq(sc.best_slot("equip.mesh_armor", DUELIST, bag.call("equip.mesh_armor")), -1, "옛 장비 가방 99(bag_full) → -1")
	s.gear_bag.erase("equip.padded_coat")
	# 직업 안 맞음.
	check_eq(sc.best_slot("equip.twin_edge", WIZARD, bag.call("equip.twin_edge")), -1, "직업 안 맞음 → -1")
	check(not sc.can_wear("equip.twin_edge", WIZARD) and sc.can_wear("equip.nano_rod", WIZARD), "can_wear")
	# 사지 않은 물건도 사본 가방으로 판정(실제 가방이면 not_in_bag).
	check_eq(sc.best_slot("equip.signal_charm", DUELIST, s.gear_bag), -1, "실제 가방(없음) → -1")
	# 비교가 실제 상태를 바꾸지 않는다: 목록을 커서로 훑어도 해시·가방 그대로.
	var h := SaveCodec.state_hash(s)
	var bag0 := s.gear_bag.duplicate()
	await _step(sc, "root", 0)
	for b in 3:
		await _step(sc, "branch", b)
		for k in sc.lines.size():
			await _step(sc, "cursor", 1)
		await _step(sc, "member_step", 1)
		await _step(sc, "back")
	check_eq([SaveCodec.state_hash(s), s.gear_bag, saves], [h, bag0, 0], "비교는 상태를 바꾸지 않는다")
	# 판: 견주는 칸 = best_slot, 「지금 → 바꾸면」.
	await _step(sc, "branch", 2)
	while sc.member != DUELIST:
		await _step(sc, "member_step", 1)
	await _step(sc, "row", _row_of(sc, "equip.signal_charm"))
	await _step(sc, "dialog", ["cancel", null])
	check_eq([sc.frame.panel.drawn["mark"], sc.frame.panel.totals.comparing], [3, true], "판: 견주는 칸 3, 비교 중")
	check_eq(EquipTotals.delta_text(sc.frame.panel.totals.line_of("mdef")), "+2", "마법 방어 +2")
	check_eq(sc.frame.desc_lines, [sc.values_text("equip.signal_charm")] as Array[String], "낄 수 있으면 설명은 값 줄 하나(바뀌는 값은 판만)")


# ---- 인물 판 합계 표(EquipTotals, 마을 상점이 쓴다: 옛 캠프 장비 U8 시험을 상점 비교로 옮김, 07 §9.9 E2-c 고침) ----

## 시험이 따로 만든 사본으로 읽은 GrowthRules.profile(화면 도움 함수와 견준다).
static func _profile_with(s: ExplorationState, i: int, slot: int, item: String) -> Dictionary:
	var m := s.party.members[i]
	var copy := PartyState.Member.new(m.id, m.max_hp, m.hp, m.max_tp, m.tp)
	copy.class_id = m.class_id  # M3 A7: 직업은 대원이 가진다
	copy.level = m.level
	copy.exp = m.exp
	copy.skills = m.skills.duplicate()
	copy.equip = m.equip.duplicate()
	copy.equip[slot] = item
	return GrowthRules.profile(s.defs, i, copy)


static func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(0.01).encloses(inner)


## 목록 커서를 item 줄로(키 입력 cursor 로 한 칸씩).
func _cursor_to(sc: ShopScreen, item: String) -> void:
	var row := _row_of(sc, item)
	check(row >= 0, "준비: %s 줄이 있다" % item)
	var guard := 0
	while sc.buy_list.cursor != row and guard < 40:
		guard += 1
		await _step(sc, "cursor", 1 if sc.buy_list.cursor < row else -1)


## 합계 표의 값(지금·바꾸면)과 차이 글·색: 오르면 「+n」 + UP_COLOR, 내리면 「-n」 + DOWN_COLOR, 같으면 표시 없음 + VALUE_COLOR.
## 돌려주는 값: [오른 줄 수, 내린 줄 수].
func _check_totals(t: EquipTotals, now: Dictionary, after: Variant, tag: String) -> Array:
	check_eq(t.lines.size(), BattleLimits.GEAR.size() + BattleLimits.STATS.size(), tag + ": 줄 수")
	check_eq(t.comparing, after != null, tag + ": 견주는지")
	for g in BattleLimits.GEAR:
		var l := t.line_of(g)
		check_eq(l["name"], texts.t("stat." + g), "%s %s: 이름" % [tag, g])
		check_eq(l["now"], now["gear"][g], "%s %s: 지금" % [tag, g])
		check_eq(l["after"], after["gear"][g] if after != null else null, "%s %s: 바꾸면" % [tag, g])
	for k in BattleLimits.STATS:
		var l := t.line_of(k)
		check_eq(l["name"], texts.t("stat." + k), "%s %s: 이름" % [tag, k])
		check_eq(l["now"], now["stats"][k], "%s %s: 지금" % [tag, k])
		check_eq(l["after"], after["stats"][k] if after != null else null, "%s %s: 바꾸면" % [tag, k])
	var ups := 0
	var downs := 0
	for l in t.lines:
		var d: int = int(l["after"]) - int(l["now"]) if l["after"] != null else 0
		var dt := EquipTotals.delta_text(l)
		var dc := EquipTotals.delta_color(l)
		if d > 0:
			ups += 1
			check(dt == "+%d" % d and dc == EquipTotals.UP_COLOR, "%s %s: 오름 = 「+%d」 + 오름 색 (%s, %s)" % [tag, l["key"], d, dt, dc])
		elif d < 0:
			downs += 1
			check(dt == "-%d" % -d and dc == EquipTotals.DOWN_COLOR, "%s %s: 내림 = 「-%d」 + 내림 색 (%s, %s)" % [tag, l["key"], -d, dt, dc])
		else:
			check(dt.is_empty() and dc == EquipTotals.VALUE_COLOR, "%s %s: 같음 = 표시 없음 + 값 색 (%s, %s)" % [tag, l["key"], dt, dc])
	return [ups, downs]


## 상점 비교로 합계 표를 본다(듀얼리스트 A, 칸 0 트윈 엣지): 이온 세이버(오름), 훈련용 홀로 블레이드(내림), 트윈 엣지(지금 것: 낄 칸이 없어 견주지 않음),
## 나노 로드(못 낌: 견주지 않음), 방어구 메시 아머(민첩 내림·방어 오름이 한 줄에 섞임). 비교가 상태를 바꾸지 않는다.
func test_totals_show_profile_and_compare_the_cursor_candidate() -> void:
	_kit()
	var s := _sold_state()
	s.money = 5000
	s.materials["item.coated_scale"] = 3
	ShopRules.sell(s, JUNK, [{"item": "item.coated_scale", "qty": 3}])
	var sc := await _fresh(s)
	await _to_list(sc, 0, 0, DUELIST)
	var t := sc.frame.panel.totals
	var now := GrowthRules.profile(s.defs, DUELIST, s.party.members[DUELIST])
	var h := SaveCodec.state_hash(s)
	check(t.is_visible_in_tree(), "준비: 판의 합계 표가 보인다")
	var cases := [["equip.ion_saber", "오름", true], ["equip.training_sword", "내림", true], ["equip.twin_edge", "같은 장비", false], ["equip.nano_rod", "못 낌", false]]
	var seen := {}
	for c in cases:
		await _cursor_to(sc, c[0])
		var b := sc.best_slot(c[0], DUELIST, sc.preview_bag(c[0]))
		var after: Variant = _profile_with(s, DUELIST, b, c[0]) if c[2] else null
		check_eq([sc.frame.panel.drawn["mark"], b >= 0], [b if c[2] else -1, c[2]], "%s: 견주는 칸" % c[1])
		seen[c[1]] = _check_totals(t, now, after, c[1])
	check(seen["오름"][0] > 0 and seen["오름"][1] == 0, "이온 세이버: 오르기만 %s" % str(seen["오름"]))
	check(seen["내림"][1] > 0 and seen["내림"][0] == 0, "훈련용 홀로 블레이드: 내리기만 %s" % str(seen["내림"]))
	check_eq([seen["같은 장비"], seen["못 낌"]], [[0, 0], [0, 0]], "트윈 엣지(지금 것, 낄 칸 없음)·나노 로드(못 낌): 견주지 않고 차이 표시 없음")
	check(seen["오름"][0] + seen["오름"][1] < t.lines.size(), "오름 후보에도 같은 값 줄(표시 없음·값 색)이 있다")
	# 방어구: 메시 아머(몸 칸)는 오름·내림이 섞인다.
	sc = await _fresh(s)
	await _to_list(sc, 1, 1, DUELIST)
	t = sc.frame.panel.totals
	await _cursor_to(sc, "equip.mesh_armor")
	var mb := sc.best_slot("equip.mesh_armor", DUELIST, sc.preview_bag("equip.mesh_armor"))
	var mixed := _check_totals(t, now, _profile_with(s, DUELIST, mb, "equip.mesh_armor"), "메시 아머")
	check(mixed[0] > 0 and mixed[1] > 0, "메시 아머: 오름·내림이 섞인다 %s" % str(mixed))
	check_eq(SaveCodec.state_hash(s), h, "견주기만 했고 상태는 그대로")


## 인물 판의 능력치 묶음(원작 상점 인물 판의 STR~LUC 열 + 攻撃·防御 판): 두 크기에서 판 안, 직업 문패와 장비 줄 사이, 목록과 겹치지 않고,
## 칸 차례·줄 안·글자 맞춤(오름·내림 둘 다 견주는 중).
func test_totals_fit_in_the_character_panel_at_both_sizes() -> void:
	_kit()
	var s := _sold_state()
	s.money = 5000
	for c in [["equip.training_sword", "내림"], ["equip.ion_saber", "오름"]]:
		for px in WINDOWS:
			var sc := await _fresh(s, px)
			var size := sc.get_global_rect().size
			await _to_list(sc, 0, 0, DUELIST)
			await _cursor_to(sc, c[0])
			var t := sc.frame.panel.totals
			var panel := sc.frame.panel
			var font := t.get_theme_default_font()
			var tag := "%s %s(논리 %s)" % [c[1], str(px), str(size)]
			check(t.comparing, tag + ": 준비: 견주는 중")
			var tr := t.get_global_rect()
			var pr := panel.get_global_rect()
			check(_inside(tr, pr) and _inside(pr, sc.get_global_rect()), "%s: 판 안·화면 안 %s %s" % [tag, str(tr), str(pr)])
			check_eq(t.size, EquipTotals.needed_size(), tag + ": 줄이 다 들어가는 크기")
			var cp := Rect2(pr.position + panel.class_rect().position, panel.class_rect().size)
			check(tr.position.y >= cp.end.y and tr.end.y <= pr.position.y + panel.equip_rect(0).position.y, tag + ": 직업 문패와 장비 줄 사이")
			for k in BattleLimits.EQUIP_SLOTS:
				var er := Rect2(pr.position + panel.equip_rect(k).position, panel.equip_rect(k).size)
				check(_inside(er, pr) and not er.intersects(tr), "%s: 장비 줄 %d 는 판 안·합계 표 밖" % [tag, k])
			check(not sc.buy_list.get_global_rect().intersects(pr), tag + ": 목록과 판이 겹치지 않는다")
			for j in t.lines.size():
				var l := t.lines[j]
				var cl := t.line_layout(j)
				var who := "%s %s" % [tag, l["key"]]
				check(_inside(cl["line"], Rect2(Vector2.ZERO, t.size)), who + ": 묶음 안")
				for k in ["box", "name", "now", "arrow", "after", "delta"]:
					check(_inside(cl[k], cl["line"]), "%s: %s 이 줄 안" % [who, k])
				var order := ["name", "now", "arrow", "after", "delta"]
				for q in order.size() - 1:
					check((cl[order[q]] as Rect2).end.x <= (cl[order[q + 1]] as Rect2).position.x + 0.01, "%s: %s 다음 %s" % [who, order[q], order[q + 1]])
				check(font.get_string_size(l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.NAME_FS).x <= (cl["name"] as Rect2).size.x + 0.5, who + ": 이름")
				check(font.get_string_size(str(l["now"]), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (cl["now"] as Rect2).size.x + 0.5, who + ": 지금 값")
				check(font.get_string_size(str(l["after"]), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (cl["after"] as Rect2).size.x + 0.5, who + ": 바꾸면 값")
				check(font.get_string_size(EquipTotals.delta_text(l), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (cl["delta"] as Rect2).size.x + 0.5, who + ": 차이")
				for q in range(j + 1, t.lines.size()):
					check(not (cl["line"] as Rect2).intersects(t.line_layout(q)["line"]), "%s: %s 와 겹치지 않는다" % [who, t.lines[q]["key"]])
			# 원작 짜임: 능력치(힘~행운)가 한 열로 위, 공격·방어 판이 그 아래 2×2.
			var last_stat: Rect2 = t.line_layout(t.lines.size() - 1)["line"]
			for g in BattleLimits.GEAR.size():
				check((t.line_layout(g)["line"] as Rect2).position.y >= last_stat.end.y, tag + ": 공격·방어 판은 능력치 열 아래")
			check((t.line_layout(0)["line"] as Rect2).end.x <= (t.line_layout(1)["line"] as Rect2).position.x, tag + ": 공격 | 마법 공격 나란히")


## 모든 칸이 막히면(-1) 산 뒤 장착 물음이 없다.
func test_no_equip_prompt_when_every_slot_is_blocked() -> void:
	_kit()
	var s := _state(1000)
	var sc := await _fresh(s)
	await _to_list(sc, 1, 1, KNIGHT)  # 방어구 · 몸
	sc.buy_list.set_cursor(_row_of(sc, "equip.padded_coat"))
	await _step(sc, "member_step", 1)
	await _step(sc, "member_step", -1)
	check_eq(sc.frame.desc_lines, [sc.values_text("equip.padded_coat"), texts.t("shop.why.no_slot")] as Array[String], "설명 둘째 줄 = 낄 칸 없음")
	await _step(sc, "row", _row_of(sc, "equip.padded_coat"))
	check_eq(sc.dialog.message, "60엔이다. 살까?", "낄 수 있는 직업 → buy")
	await _step(sc, "dialog", ["confirm", null])
	check_eq([sc.dialog.mode, int(s.gear_bag.get("equip.padded_coat", 0)), saves], ["", 1, 1], "같은 몸(-1) → 장착 물음 없음")


# ---- 키 표 = 가상 키패드 ----

## 준비 입력 → 키패드 단추 k 를 누른 결과와 같은 키를 누른 결과가 같다. on: 켜짐/흐림. edge: 켜진 채 아무것도 바꾸지 않음.
func _parity(cases: Array, make: Callable = Callable()) -> void:
	for c in cases:
		var tag: String = c[0]
		var k: String = c[2]
		var sc := await _fresh(make.call() if make.is_valid() else _sold_state())
		for st in c[1]:
			await _step(sc, st[0], st[1] if (st as Array).size() > 1 else null)
		var pre := _sig(sc)
		var on: bool = sc.pad_state()[k]
		check_eq(on, c[3], tag + ": 켜짐/흐림")
		var b := _pad_button(sc, k)
		check(b.is_visible_in_tree() and b.disabled == not on, tag + ": 단추가 보이고 흐림이 상태와 같다")
		await kit.tap(kit.center_of(b), FINGER)
		var by_pad := _sig(sc)
		sc = await _fresh(make.call() if make.is_valid() else _sold_state())
		for st in c[1]:
			await _step(sc, st[0], st[1] if (st as Array).size() > 1 else null)
		check_eq(_sig(sc), pre, tag + ": 준비가 같다")
		await kit.press_key(ShopScreen.PAD_KEYS[k])
		var by_key := _sig(sc)
		check_eq(by_pad, by_key, tag + ": 키패드 = 키")
		if not on:
			check_eq(by_pad, pre, tag + ": 흐린 단추·키는 아무것도 바꾸지 않는다")
		elif c[4]:
			check_eq(by_pad, pre, tag + ": 가장자리: 켜진 채 아무것도 바꾸지 않는다")
		else:
			check(int(by_pad[-1]) == int(pre[-1]) + 1, "%s: 켜진 단추는 입력 하나 %s → %s" % [tag, pre[-1], by_pad[-1]])


func test_pad_matches_keys_on_root_and_branch() -> void:
	_kit()
	var br := [["root", 0]]
	await _parity([
		["뿌리 ↑", [], "up", true, false], ["뿌리 ↓", [], "down", true, false],
		["뿌리 ←", [], "left", false, false], ["뿌리 →", [], "right", false, false],
		["뿌리 선택", [], "ok", true, false], ["뿌리 취소", [], "back", true, false],
		["갈래 ↑", br, "up", true, false], ["갈래 ↓", br, "down", true, false],
		["갈래 ←", br, "left", true, false], ["갈래 →", br, "right", true, false],
		["갈래 선택", br, "ok", true, false], ["갈래 취소", br, "back", true, false],
	])


func test_pad_matches_keys_on_the_list_and_dialogs() -> void:
	_kit()
	var ls := [["root", 0], ["branch", 1]]
	var cf := ls + [["row", 1]]
	var eq := cf + [["dialog", ["confirm", null]]]
	var sl := eq + [["dialog", ["confirm", null]]]
	var empty := [["root", 0], ["branch", 3]]
	await _parity([
		["목록 ↑(가장자리)", ls, "up", true, true], ["목록 ↓", ls, "down", true, false],
		["목록 ←", ls, "left", true, false], ["목록 →", ls, "right", true, false],
		["목록 선택", ls, "ok", true, false], ["목록 취소", ls, "back", true, false],
		["확인 ↑", cf, "up", false, false], ["확인 ↓", cf, "down", false, false],
		["확인 ←(가장자리)", cf, "left", true, true], ["확인 →", cf, "right", true, false],
		["확인 선택", cf, "ok", true, false], ["확인 취소", cf, "back", true, false],
		["장착 물음 선택", eq, "ok", true, false], ["장착 물음 ↑", eq, "up", false, false],
		["칸 ↑", sl, "up", true, false], ["칸 ↓", sl, "down", true, false],
		["칸 ←", sl, "left", false, false], ["칸 →", sl, "right", false, false],
		["칸 선택", sl, "ok", true, false], ["칸 취소", sl, "back", true, false],
	])
	# 빈 구매 목록(소모품 진열이 없는 묶음의 「아이템」 갈래, M3 A4b).
	await _parity([["빈 목록 ↓", empty, "down", false, false], ["빈 목록 선택", empty, "ok", false, false]], _no_items_state)


# ---- 키 시점(F2) ----

func _key_event(code: int, pressed: bool, echo: bool = false, ctrl: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	k.ctrl_pressed = ctrl
	Input.parse_input_event(k)
	Input.flush_buffered_events()


func test_keys_act_once_on_the_first_press_and_never_on_release() -> void:
	_kit()
	var s := _state(1000)
	var sc := await _fresh(s)
	await _to_list(sc, 0, 0, KNIGHT)
	var i := _row_of(sc, "equip.twin_edge")
	sc.buy_list.set_cursor(i)
	# 갈래에서 Enter 를 누른 채(누름에서 목록이 열림), 손가락으로 줄을 눌러 확인 창 → Enter 를 떼도 사지 않는다.
	await _step(sc, "back")
	var n0 := sc.accepted_inputs
	_key_event(KEY_ENTER, true)
	await kit.frames(2)
	check_eq([sc.page, sc.accepted_inputs], ["buy", n0 + 1], "Enter 누름에서 한 번(목록 열림)")
	await kit.tap(kit.center_of(sc.buy_list.rows[i]), FINGER)
	check_eq([sc.dialog.mode, sc.ask], ["confirm", "buy"], "손가락으로 확인 창")
	var pre := _sig(sc)
	_key_event(KEY_ENTER, false)
	await kit.frames(2)
	check_eq(_sig(sc), pre, "Enter 를 떼도 사지 않는다(뗌은 일하지 않는다)")
	# 반복·조합 키는 삼키고 아무 일도 하지 않는다.
	_key_event(KEY_ENTER, true, true)
	await kit.frames(2)
	_key_event(KEY_ENTER, false)
	_key_event(KEY_ENTER, true, false, true)
	await kit.frames(2)
	_key_event(KEY_ENTER, false, false, true)
	await kit.frames(2)
	check_eq(_sig(sc), pre, "반복·Ctrl 조합 Enter 는 아무 일 없음")
	check_eq(s.money, 1000, "산 것 없음")
	# 키패드 「선택」은 단추 안에서 뗄 때 한 번.
	var ok := sc.active_key_pad().button("ok")
	kit.touch(FINGER, kit.center_of(ok), true)
	await kit.frames(2)
	check_eq(_sig(sc), pre, "키패드 「선택」 누름에서는 아무 일 없음")
	kit.touch(FINGER, kit.center_of(ok), false)
	await kit.frames(2)
	check_eq([s.money, sc.ask], [880, "equip"], "뗄 때 한 번: 샀다 → 장착 물음")


# ---- 입력 갈고리(F3)·문맥 ----

func test_one_input_per_frame_across_dialog_buttons_keys_and_pad() -> void:
	_kit()
	var s := _state(1000)
	var sc := await _fresh(s)
	await _to_list(sc, 0, 0, KNIGHT)
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	var n0 := sc.accepted_inputs
	# 같은 프레임: 창 「예」 누르기·Enter 키·키패드 「선택」.
	var yes := kit.center_of(sc.dialog.yes_button)
	var ok := kit.center_of(sc.active_key_pad().button("ok"))
	kit.touch(FINGER, yes, true)
	kit.touch(FINGER + 1, ok, true)
	kit.touch(FINGER, yes, false)
	_key_event(KEY_ENTER, true)
	kit.touch(FINGER + 1, ok, false)
	_key_event(KEY_ENTER, false)
	await kit.frames(2)
	check_eq([sc.accepted_inputs, s.money, sc.ask, s.party.members[KNIGHT].equip[0]], [n0 + 1, 880, "equip", "equip.training_sword"],
		"한 프레임에 한 입력: 사기만, 장착 물음은 그대로")
	# 창 단추는 화면 입구를 거친다: 층 3 막힘이면 창도 닫히지 않는다.
	var blocked := [true]
	sc.blocked_hook = func() -> bool: return blocked[0]
	await kit.tap(kit.center_of(sc.dialog.yes_button))
	check_eq([sc.dialog.mode, sc.ask, s.party.members[KNIGHT].equip[0]], ["confirm", "equip", "equip.training_sword"], "막힌 동안 창 단추는 아무 일 없음")
	blocked[0] = false
	await kit.tap(kit.center_of(sc.dialog.yes_button))
	check_eq(s.party.members[KNIGHT].equip[0], "equip.twin_edge", "풀리면 같은 단추가 일한다")


func test_buy_confirm_to_equip_prompt_is_a_context_change() -> void:
	_kit()
	var s := _state(1000)
	var sc := await _fresh(s)
	await _to_list(sc, 0, 0, KNIGHT)
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	var key0 := sc.selection_key()
	# 「예」 자리를 한 손가락으로 누른 채, 다른 길(Enter)로 산다 → 같은 confirm 모양의 장착 물음 → 뗀 손가락은 아무 일 없음.
	var yes := kit.center_of(sc.dialog.yes_button)
	kit.touch(FINGER, yes, true)
	await kit.frames(2)
	check(sc.dialog.yes_button.held, "준비: 「예」 눌림")
	await kit.press_key(KEY_ENTER)
	check_eq([sc.dialog.mode, sc.ask], ["confirm", "equip"], "같은 모양의 장착 물음")
	check(sc.selection_key() != key0 and sc.selection_key()[10] == ["equip", "equip.twin_edge", KNIGHT],
		"고름 값에 물음의 목적·대상이 들어간다: %s" % str(sc.selection_key()))
	check(not sc.dialog.yes_button.held, "눌림을 버렸다")
	kit.touch(FINGER, yes, false)
	await kit.frames(2)
	check_eq([sc.dialog.mode, s.party.members[KNIGHT].equip[0]], ["confirm", "equip.training_sword"], "뗀 손가락은 장착하지 않는다")
	# 창이 떠 있는 동안 Q/E·판 화살표·탭·숫자 키는 일하지 않고, 대상 물건·대원은 그대로.
	var pre := _sig(sc)
	for k in [KEY_Q, KEY_E, KEY_Z, KEY_X, KEY_1, KEY_PAGEDOWN]:
		await kit.press_key(k)
	for kind in ["member_step", "tab", "branch", "root", "back", "row"]:
		check(not sc.handle(kind, 1), "창이 떠 있으면 %s 는 거부" % kind)
		await kit.frames(1)
	check_eq(_sig(sc), pre, "창 동안 다른 입력은 아무 일 없음")
	check_eq([sc.ask_item, sc.ask_member], ["equip.twin_edge", KNIGHT], "대상 물건·대원 고정")


func test_context_changes_drop_held_presses() -> void:
	_kit()
	var s := _state(1000)
	var sc := await _fresh(s)
	await _to_list(sc, 0, 0, KNIGHT)
	var p := kit.center_of(sc.buy_list.rows[1])
	var cases := [["대원(E)", KEY_E], ["탭(X)", KEY_X], ["창(Enter)", KEY_ENTER]]
	for c in cases:
		sc.buy_list.set_cursor(0)
		kit.touch(FINGER, p, true)
		await kit.frames(2)
		check(sc.buy_list.rows[1].held, "%s 준비: 줄 눌림" % c[0])
		await kit.press_key(c[1])
		check(not sc.buy_list.rows[1].held, "%s: 눌림을 버렸다" % c[0])
		var pre := _sig(sc)
		kit.touch(FINGER, p, false)
		await kit.frames(2)
		check_eq(_sig(sc), pre, "%s: 떼도 아무 일 없음" % c[0])
		if sc.dialog.is_open():
			await _step(sc, "dialog", ["cancel", null])
		if sc.tab != 0:
			await _step(sc, "tab", 0)
	# 갈래: 하위 목록 줄을 누른 채 Esc → 떼도 목록이 열리지 않는다.
	await _step(sc, "back")
	var bp := kit.center_of(sc.branch_list.rows[2])
	kit.touch(FINGER, bp, true)
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)
	kit.touch(FINGER, bp, false)
	await kit.frames(2)
	check_eq(sc.page, "root", "갈래가 바뀐 뒤 뗀 하위 목록 줄은 아무 일 없음")


## 층 3 창이 눌린 「예」를 덮었다가 닫혀도 사지 않는다(미궁 화면의 창 신호가 상점 누르기를 버린다).
func test_layer_three_window_over_a_held_yes_buys_nothing() -> void:
	timeout_sec = 120.0
	_kit()
	var s := await kit.open_town("native", 7, "debug=1")  # M3 A2: 상점은 마을에서 연다
	var sc := s.shop_screen
	s.state.money = 1000
	s._open_shop()
	await kit.frames(1)
	await _to_list(sc, 0, 0, KNIGHT)
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	for under in [true, false]:
		var yes := kit.center_of(sc.dialog.yes_button)
		var sig := [kit.hash_now(), s.state.generation, s.autosave_count, sc.accepted_inputs]
		kit.touch(4, yes, true)
		await kit.frames(2)
		check(sc.dialog.yes_button.held, "준비: 「예」 눌림")
		s._alert("x")
		await kit.frames(2)
		check(not sc.dialog.yes_button.held, "층 3 창이 뜨면 눌림을 버린다")
		check(not sc.handle("dialog", ["confirm", null]), "층 3 창이 떠 있으면 상점 입구가 받지 않는다")
		await kit.press_key(KEY_ENTER)
		if not under and s.modal.is_open():
			await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)), 7)
			check_eq(s.modal.kind, "", "준비: 다른 손가락으로 알림을 닫음")
		kit.touch(4, yes, false)
		await kit.frames(2)
		check_eq([kit.hash_now(), s.state.generation, s.autosave_count, sc.accepted_inputs], sig, "사지 않았다(%s)" % ("덮은 채 뗌" if under else "닫은 뒤 뗌"))
		check_eq([sc.dialog.mode, sc.ask], ["confirm", "buy"], "확인 창 그대로")
		if s.modal.is_open():
			s._close_alert()
			await kit.frames(2)


const ARROW_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT}


## 손가락 FINGER 로 b 를 누른 채 답(커서·칸 커서·수량)을 dir 로 옮긴다(pad: 다른 손가락으로 방향 패드, key: 방향키). 옮긴 뒤 눌림이 풀렸고,
## 떼도 화면이 가진 것(칸 고르기 이유 포함)이 그대로인지 본다.
func _held_across(sc: ShopScreen, b: TouchButton, dir: String, variant: String, tag: String) -> void:
	var p := kit.center_of(b)
	var pre := [sc.dialog.pick, sc.dialog.slot_cursor, sc.dialog.qty]
	kit.touch(FINGER, p, true)
	await kit.frames(1)
	check(b.held, tag + ": 준비: 누르는 중")
	if variant == "pad":
		await kit.tap(kit.center_of(sc.dir_pad.button(dir)), FINGER + 1)
	else:
		await kit.press_key(ARROW_KEYS[dir])
	check([sc.dialog.pick, sc.dialog.slot_cursor, sc.dialog.qty] != pre, tag + ": 답이 옮겨졌다")
	check(not b.held, tag + ": 답이 바뀌면 누르기 취소")
	var moved := _sig(sc) + [sc.dialog.slot_reason]
	kit.touch(FINGER, p, false)
	await kit.frames(2)
	check_eq(_sig(sc) + [sc.dialog.slot_reason], moved, tag + ": 뗄 때 아무 일 없음(사기·끼기·저장 없음)")


## M-H9(답 커서)·M-H10(칸 커서)가 바뀌어도 누르기를 버리지 않음(검토 seq=9, 공용 창): 구매 확인 창에서 키패드 「선택」·「예」·「아니오」를,
## 칸 고르기에서 「선택」·칸 줄을 누른 채 답을 옮기면(다른 손가락 방향 패드·방향키) 누르기가 풀리고 떼도 사거나 끼거나 저장하지 않는다.
## 옮기지 않고 누른 「예」·칸 줄은 그대로 사고 낀다.
func test_answer_change_drops_held_presses() -> void:
	_kit()
	var sc := await _fresh(_state(1000))
	var s := sc.state
	await _to_list(sc, 2, 0, WIZARD)
	await _step(sc, "row", _row_of(sc, "equip.signal_charm"))
	check_eq([sc.dialog.mode, sc.ask, sc.dialog.pick, saves], ["confirm", "buy", ShopDialog.YES, 0], "준비: 구매 확인(「예」 먼저)")
	var ok := sc.active_key_pad().button("ok")
	for t in [["「선택」", ok], ["「예」", sc.dialog.yes_button], ["「아니오」", sc.dialog.no_button]]:
		for v in ["pad", "key"]:
			await _held_across(sc, t[1], "right" if sc.dialog.pick == ShopDialog.YES else "left", v, "구매 %s(%s)" % [t[0], v])
	check_eq([sc.dialog.mode, saves, int(s.gear_bag.get("equip.signal_charm", 0))], ["confirm", 0, 0], "구매 창 그대로, 사지 않았다")
	if sc.dialog.pick != ShopDialog.YES:
		await _step(sc, "dialog", ["pick", -1])
	await kit.tap(kit.center_of(sc.dialog.yes_button))
	check_eq([saves, sc.ask, sc.dialog.mode], [1, "equip", "confirm"], "보통 「예」 → 사고 저장, 장착 물음")
	await _step(sc, "dialog", ["confirm", null])
	check_eq([sc.dialog.mode, sc.dialog.slot_cursor], ["slots", 3], "준비: 칸 고르기(커서 칸 3)")
	for v in ["pad", "key"]:
		await _held_across(sc, sc.dialog.slot_buttons[2], "up", v, "칸 3 줄(%s)" % v)
		check_eq(sc.dialog.slot_cursor, 2, "준비: 커서 칸 2(막힌 칸)")
		await _held_across(sc, ok, "down", v, "칸 「선택」(%s)" % v)
	check_eq([sc.dialog.mode, saves, s.party.members[WIZARD].equip[3]], ["slots", 1, ""], "칸 고르기 그대로, 끼지 않았다")
	await kit.tap(kit.center_of(sc.dialog.slot_buttons[2]))
	check_eq([s.party.members[WIZARD].equip[3], saves, sc.dialog.mode], ["equip.signal_charm", 2, ""], "보통 칸 3 줄 → 끼고 저장")


## M-H14(수량이 바뀌어도 누르기를 버리지 않음, 검토 seq=10): 구매(메디카)·판매(네온 쥐 꼬리 3개) 수량 창에서 키패드 「선택」·「예」를 누른 채
## 수량을 바꾸면(다른 손가락 방향 패드 ↑↓·방향키) 누르기가 풀리고, 떼도 사고팔지 않고 저장하지 않는다. 바뀐 수량에서 누른 보통 「예」는
## 그 수량을 한 번 사고판다(저장 1).
func test_quantity_change_drops_held_presses() -> void:
	_kit()
	for sell in [false, true]:
		var s := _sell_state()
		var sc := await _fresh(s)
		var have := func() -> int: return int(s.materials.get(TAIL, 0)) if sell else int(s.consumables.get("use.medica", 0))
		if sell:
			await kit.press_key(KEY_2)
			await _step(sc, "row", 0)
		else:
			await _to_list(sc, 3)
			await _step(sc, "row", _row_of(sc, "use.medica"))
		var tag0 := "판매" if sell else "구매"
		check_eq([sc.dialog.mode, sc.dialog.qty, sc.dialog.pick, saves], ["qty", 1, ShopDialog.YES, 0], tag0 + ": 준비: 수량 창 1, 「예」 먼저")
		var n0: int = have.call()
		var money0 := s.money
		var ok := sc.active_key_pad().button("ok")
		for t in [["「선택」", ok], ["「예」", sc.dialog.yes_button]]:
			for v in ["pad", "key"]:
				await _held_across(sc, t[1], "up" if sc.dialog.qty < sc.dialog.max_qty else "down", v, "%s %s(%s)" % [tag0, t[0], v])
		check_eq([sc.dialog.mode, have.call(), s.money, saves], ["qty", n0, money0, 0], tag0 + ": 창 그대로, 사고팔지 않고 저장 없음")
		if sc.dialog.qty == 1:
			await _step(sc, "dialog", ["step", 1])
		var q := sc.dialog.qty
		await kit.tap(kit.center_of(sc.dialog.yes_button))
		check_eq([have.call(), saves], [n0 - q if sell else n0 + q, 1], "%s: 보통 「예」 → 수량 %d 을 한 번, 저장 1" % [tag0, q])


## 커서를 처음(0)으로 되돌린다(↑, 누르기 없음).
func _cursor_home(get: Callable) -> void:
	for i in 12:
		if int(get.call()) <= 0:
			return
		await kit.press_key(KEY_UP)


## M-D3(상점 고름 값에 뿌리·갈래·목록 커서와 그 물건이 없음, M3 A7d): 뿌리·갈래·구매 목록·판매 목록에서 키패드 「선택」과 커서 줄을
## 손가락 3 으로 누른 채 커서를 옮기면(손가락 4 방향 패드 ↓·방향키 ↓) 누르기가 풀리고, 떼도 쪽·창·고름·저장이 그대로다(옮긴 줄도, 누른 줄도
## 열지 않는다). 옮기지 않은 보통 누르기는 그 줄을 연다.
func test_selection_change_drops_held_presses() -> void:
	_kit()
	var sc := await _fresh(_sell_state())
	var ok := func() -> TouchButton: return sc.active_key_pad().button("ok")
	var down := func() -> TouchButton: return sc.dir_pad.button("down")
	var obs := func() -> Array: return _sig(sc) + [sc.selection_key()]
	var lists := [
		["뿌리", func() -> TouchButton: return sc.root_list.rows[0], func() -> int: return sc.root_cursor, func() -> void: pass],
		["갈래", func() -> TouchButton: return sc.branch_list.rows[0], func() -> int: return sc.branch_cursor,
			func() -> void: await _step(sc, "root", 0)],
		["구매 목록", func() -> TouchButton: return sc.buy_list.rows[0], func() -> int: return sc.buy_list.cursor,
			func() -> void: await _step(sc, "branch", 0)],
	]
	for l in lists:
		await (l[3] as Callable).call()
		for hold in [["「선택」", ok], ["커서 줄", l[1]]]:
			await HM.run(self, kit, {"name": "%s %s" % [l[0], hold[0]], "hold": hold[1], "pad": down, "key": KEY_DOWN, "value": l[2],
				"observe": obs, "reset": _cursor_home.bind(l[2])})
	check_eq([sc.page, sc.dialog.mode, saves], ["buy", "", 0], "구매 목록 그대로, 창 없음, 저장 없음")
	await _cursor_home(func() -> int: return sc.buy_list.cursor)
	await kit.tap(kit.center_of(sc.buy_list.rows[0]))
	check_eq([sc.dialog.mode, sc.ask, sc.ask_item], ["confirm", "buy", str(sc.lines[0]["item"])], "보통 누르기 → 그 줄의 구매 확인")
	await _step(sc, "dialog", ["cancel", null])
	for i in 2:
		await kit.press_key(KEY_ESCAPE)
	await _step(sc, "root", 1)
	check_eq(sc.page, "sell", "준비: 판매 목록")
	var sell_cursor := func() -> int: return sc.buy_list.cursor
	for hold in [["「선택」", ok], ["커서 줄", func() -> TouchButton: return sc.buy_list.rows[0]]]:
		await HM.run(self, kit, {"name": "판매 목록 %s" % hold[0], "hold": hold[1], "pad": down, "key": KEY_DOWN, "value": sell_cursor,
			"observe": obs, "reset": _cursor_home.bind(sell_cursor)})
	check_eq([sc.dialog.mode, saves, int(sc.state.materials.get(TAIL, 0))], ["", 0, 3], "판매 목록: 창 없음, 팔지 않음")
	await _cursor_home(sell_cursor)
	await kit.tap(kit.center_of(sc.buy_list.rows[0]))
	check_eq([sc.dialog.mode, sc.ask_item], ["qty", TAIL], "보통 누르기 → 그 줄(네온 쥐 꼬리 3개)의 수량 창")


## M-D14(상점이 줄을 다시 만들기 전에 sync, 검토 seq=13): 판매 소모품 목록 줄 0 에서 키패드 「선택」을 누른 채 그 칸의 물건이 넥타 → 메디카로
## 바뀌면(디버그 보급, 다시 만든 줄) 그 새로 고침에서 바로 누르기가 풀리고, 떼도 아무 창도 열지 않는다. 그 뒤 새로 시작한 누르기는 바뀐
## 것이 없는 새로 고침에서 풀리지 않고 떼면 한 번 일한다(메디카 1개 판매 확인).
func test_same_index_replacement_cancels_at_once_and_a_fresh_press_survives() -> void:
	timeout_sec = 120.0
	_kit()
	var s := await kit.open_town("native", 7, "debug=1")
	s.state.consumables = {"use.nectar": 2}
	s._open_shop()
	await kit.frames(2)
	var sc := s.shop_screen
	await _step(sc, "root", 1)
	await _step(sc, "tab", 2)
	var item := func() -> String: return str(sc.lines[sc.buy_list.cursor]["item"]) if sc.buy_list.cursor < sc.lines.size() else ""
	check_eq([sc.page, sc.buy_list.cursor, item.call()], ["sell", 0, "use.nectar"], "준비: 판매 소모품 줄 0 넥타")
	var ok := sc.active_key_pad().button("ok")
	var p := kit.center_of(ok)
	kit.touch(FINGER, p, true)
	await kit.frames(1)
	check(ok.held, "준비: 「선택」 누르는 중")
	var r: Dictionary = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "supply", "item": "use.medica", "n": 1})))
	await kit.frames(1)
	check(bool(r.get("ok", false)), "준비: 디버그 보급 메디카")
	check_eq([sc.buy_list.cursor, item.call()], [0, "use.medica"], "같은 칸(줄 0)의 물건이 메디카로 바뀌었다")
	check(not ok.held, "그 새로 고침에서 바로 「선택」 누르기가 풀린다")
	var n := sc.accepted_inputs
	kit.touch(FINGER, p, false)
	await kit.frames(2)
	check_eq([sc.dialog.mode, sc.accepted_inputs], ["", n], "뗄 때 아무 창도 열지 않는다")
	kit.touch(FINGER, p, true)
	await kit.frames(1)
	sc.refresh_view()
	await kit.frames(1)
	check(ok.held, "새 누르기는 바뀐 것이 없는 새로 고침에서 풀리지 않는다")
	kit.touch(FINGER, p, false)
	await kit.frames(2)
	check_eq([sc.dialog.mode, sc.ask_item, sc.accepted_inputs], ["confirm", "use.medica", n + 1], "떼면 한 번 일한다(메디카 판매 확인)")


# ---- 저장 실패(F6) ----

func test_save_failure_keeps_the_accepted_change_and_the_prompt_chain() -> void:
	timeout_sec = 120.0
	_kit()
	var s := await kit.open_town("native", 7, "debug=1")  # M3 A2: 상점은 마을에서 연다
	var sc := s.shop_screen
	s.state.money = 1000
	s._open_shop()
	await kit.frames(1)
	await _to_list(sc, 0, 0, KNIGHT)
	# 1. 사기 뒤 저장 실패 → 「아니오」: 메모리는 산 그대로, 다시 사지 않는다.
	var gen := s.state.generation
	var count := s.autosave_count
	s.store.fail_points = ["write"]
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	await _step(sc, "dialog", ["confirm", null])
	check(not s.last_autosave_error.is_empty(), "준비: 저장 실패")
	# M3 A3b(검토 R1): 상점이 열려 있으면 저장 실패 안내는 상점 안내 줄에 보인다(알림 줄은 창 위에 그리지 않는다).
	check_eq([sc.notice, s._toast.modulate.a], [texts.t("msg.save_failed", {"reason": s.last_autosave_error}), 0.0], "저장 실패 안내(상점 안내 줄)")
	check_eq([s.state.money, int(s.state.gear_bag.get("equip.twin_edge", 0)), sc.ask], [880, 1, "equip"], "산 것은 그대로, 장착 물음은 이어진다")
	check_eq(s.state.generation, gen, "저장이 실패해 세대는 그대로")
	await _step(sc, "dialog", ["confirm", 1])
	check_eq([s.state.money, int(s.state.gear_bag.get("equip.twin_edge", 0)), s.autosave_count, sc.dialog.mode], [880, 1, count, ""],
		"「아니오」: 되돌리지·다시 사지 않는다(성공한 저장 수 그대로)")
	# 2. 첫 저장 실패 → 장착·둘째 저장 성공: 저장 글에 새 장비와 가방으로 돌아온 옛 장비가 함께.
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	await _step(sc, "dialog", ["confirm", null])
	check_eq([s.state.money, int(s.state.gear_bag.get("equip.twin_edge", 0)), sc.ask], [760, 2, "equip"], "둘째 사기(저장 실패), 장착 물음")
	s.store.fail_points = []
	await _step(sc, "dialog", ["confirm", null])
	check_eq([s.autosave_count, s.state.generation], [count + 1, gen + 1], "장착 뒤 저장 하나 성공")
	check_eq([s.state.party.members[KNIGHT].equip[0], int(s.state.gear_bag.get("equip.twin_edge", 0)),
		int(s.state.gear_bag.get("equip.training_sword", 0))], ["equip.twin_edge", 1, 1], "장착: 새 장비·옛 장비 가방")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok(), "자동 저장 읽힘")
	check_eq(SaveCodec.state_hash(l.result.state), kit.hash_now(), "저장 글 = 지금 메모리 상태(온전)")
	check_eq([l.result.state.money, l.result.state.party.members[KNIGHT].equip[0]], [760, "equip.twin_edge"], "저장 글의 소지금·장비")


# ---- 노랑 채움 하나 ----

func test_one_yellow_fill_per_screen() -> void:
	_kit()
	var sc := await _fresh(_state(1000))
	check_eq(_yellow(sc), ["Root_buy"], "뿌리: 명령 커서 하나")
	await _step(sc, "root", 0)
	check_eq(_yellow(sc), ["Branch_weapon"], "갈래: 하위 목록만")
	check_eq(sc.root_list.rows[0].theme_state(), "fac:chosen", "「사기」 줄 = chosen")
	await _step(sc, "branch", 1)
	while sc.member != WIZARD:
		await _step(sc, "member_step", 1)
	await _step(sc, "tab", 3)  # 머리
	check_eq(_yellow(sc), ["Row_0"], "목록: 줄 커서 하나")
	check(sc.frame.panel.drawn["mark"] >= 1, "판의 견주는 칸 표시(테두리)")
	check(sc.frame.panel.find_children("*", "TouchButton", true, false).all(func(b: Node) -> bool: return not (b as TouchButton).selected),
		"판의 견주는 칸은 채움이 아니다")
	await _step(sc, "confirm")
	check_eq(_yellow(sc), ["Yes"], "확인 창: 고른 단추 하나")
	check_eq(sc.buy_list.rows[0].theme_state(), "cmd:chosen", "목록 커서 줄 = chosen")
	await _step(sc, "dialog", ["confirm", null])
	check_eq(_yellow(sc), ["Yes"], "장착 물음: 고른 단추 하나")
	await _step(sc, "dialog", ["confirm", null])
	check_eq(sc.dialog.mode, "slots", "준비: 칸 고르기")
	check_eq(_yellow(sc), ["Slot_%d" % sc.dialog.slot_cursor], "칸 고르기: 칸 커서 하나")
	await _step(sc, "dialog", ["cancel", null])
	await _step(sc, "back")
	await _step(sc, "branch", 3)
	check_eq(_yellow(sc), ["Row_0"], "아이템(M3 A4b): 줄 커서 하나")
	sc = await _fresh(_no_items_state())
	await _step(sc, "root", 0)
	await _step(sc, "branch", 3)
	check(sc.lines.is_empty(), "준비: 빈 구매 목록")
	check_eq(_yellow(sc), [], "빈 목록: 노랑 없음")


# ---- 카드(F7)·배치 ----

func test_branch_cards_hide_when_two_rows_do_not_fit() -> void:
	_kit()
	for px in WINDOWS:
		var sc := await _fresh(_state(), px)
		var size := tree.root.get_visible_rect().size
		check(sc.cards.visible, "%s 뿌리: 카드 보임" % str(px))
		await _step(sc, "root", 0)
		var fit := size.x - CharPanel.W - ShopScreen.CARDS_GAP - ShopFrame.PAD_SIDE >= 711.0
		check_eq(sc.cards_need(), 711.0, "지금 파티는 711px 가 필요하다")
		check_eq(sc.cards.visible, fit, "%s(논리 %s) 갈래 카드 %s" % [str(px), str(size), "보임" if fit else "숨김"])
		check_eq(sc.cards.visible, px.x > 1280.0, "1280×720 숨김, 1728×720 보임")
		if sc.cards.visible:
			var area := Rect2(ShopFrame.PAD_SIDE, 0, size.x - CharPanel.W - ShopScreen.CARDS_GAP - ShopFrame.PAD_SIDE, size.y)
			for c in sc.cards.cards:
				check(area.encloses(c.get_global_rect()), "카드 %s 는 PAD_SIDE ~ 판 왼쪽 − 24 안" % c.name)
	# 폭이 바뀌면 다시 정한다.
	var sc2 := await _fresh(_state(), WINDOWS[1])
	await _step(sc2, "root", 0)
	check(sc2.cards.visible, "준비: 넓은 화면 보임")
	await _window(WINDOWS[0])
	check(not sc2.cards.visible, "좁아지면 숨긴다")


func test_targets_are_64_inside_and_clear_of_the_panel_at_both_sizes() -> void:
	_kit()
	var screens := {
		"root": [], "branch": [["root", 0]], "weapon": [["root", 0], ["branch", 0]], "armor": [["root", 0], ["branch", 1], ["tab", 2]],
		"accessory": [["root", 0], ["branch", 2]], "confirm": [["root", 0], ["branch", 0], ["row", 0]],
		"slots": [["root", 0], ["branch", 1], ["tab", 4], ["row", 0], ["dialog", ["confirm", null]], ["dialog", ["confirm", null]]],
		"sell": [["root", 1]], "sell_multi": [["root", 1], ["multi"], ["row", 0], ["row", 3]],
		"sell_qty": [["root", 1], ["row", 0]], "sell_notice": [["root", 1], ["row", 0], ["dialog", ["step", 10]], ["dialog", ["confirm", 0]]],
	}
	for px in WINDOWS:
		for name in screens:
			var sc := await _fresh(_sell_state(), px)
			for st in screens[name]:
				await _step(sc, st[0], st[1] if (st as Array).size() > 1 else null)
			var size := tree.root.get_visible_rect().size
			var tag := "%s %s" % [str(px), name]
			var screen := Rect2(Vector2.ZERO, size)
			var panel := Rect2(size.x - CharPanel.W, 0, CharPanel.W, size.y)
			var bs := sc.visible_buttons()
			check(not bs.is_empty(), tag + ": 누를 것이 있다")
			for b in bs:
				var r := b.get_global_rect()
				check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str(b.size)])
				check(screen.encloses(r.grow(-0.5)), "%s: %s %s 가 화면 안" % [tag, b.name, str(r)])
				if b is PartyButton:
					check((b as PartyButton).clipped_parts().is_empty(), "%s: %s 글자 잘림 %s" % [tag, b.name, str((b as PartyButton).clipped_parts())])
			if name in ["weapon", "armor", "accessory", "confirm", "slots", "sell", "sell_multi", "sell_qty"]:
				for c in [sc.frame.list_window, sc.frame.desc_window, sc.buy_list, sc.buy_tabs]:
					if (c as Control).is_visible_in_tree():
						check(not (c as Control).get_global_rect().intersects(panel), "%s: %s 는 판과 겹치지 않음" % [tag, c.name])
			if sc.dialog.is_open():
				var wr := sc.dialog.window_rect()
				check(screen.encloses(wr) and not wr.intersects(panel), "%s: 창 %s 화면 안·판과 겹치지 않음" % [tag, str(wr)])
			if name == "branch":
				check(not sc.branch_list.get_global_rect().intersects(panel), tag + ": 하위 목록은 판과 겹치지 않음")
				check_eq(sc.branch_list.get_global_rect(), Rect2(440, 170, 300, FacilityList.content_height(4, 4, 4)), tag + ": 하위 목록 자리")
			if name == "root":
				check_eq(sc.root_list.get_global_rect(), Rect2(0, 166, 430, 344), tag + ": 명령 목록 x 0~430, y 166~510")
				check_eq(sc.money_plate.get_global_rect(), ShopFrame.TITLE, tag + ": 소지금 문패")
				check_eq(sc.plate.get_global_rect(), Rect2(0, 12, 182, 76), tag + ": 상점 문패")
				check_eq(sc.active_key_pad().get_global_rect().position, Vector2(size.x - 247, 427), tag + ": 「취소」「선택」 가로")
			else:
				check_eq(sc.active_key_pad().get_global_rect().position, Vector2(size.x - 118, 548), tag + ": 「취소」「선택」 세로")
			check_eq(sc.dir_pad.get_global_rect().position, Vector2(8, 511), tag + ": 십자")


# ---- 캠프 그대로 ----

func test_new_part_arguments_keep_the_camp_defaults() -> void:
	_kit()
	var fl := FacilityList.new()
	check_eq([fl.row_gap, fl.inner_pad], [FacilityList.GAP, FacilityList.PAD], "FacilityList 기본 = 캠프 6·6")
	check_eq(FacilityList.content_height(5), 2.0 * 6 + 5 * 64 + 4 * 6, "content_height 기본값 = 캠프")
	fl.free()
	var f := ShopFrame.new()
	check(f.desc_badges.is_empty(), "ShopFrame 머리글자 칸 기본 없음")
	f.free()
	# 캠프 장비 화면(07 §9.9 E2-c): 상점 틀(ShopFrame·CharPanel)을 쓰지 않고 왼쪽 상태 시트의 표지는 칸 커서.
	timeout_sec = 120.0
	var s := await kit.open("native", 7, "debug=1")
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	pm.handle("camp", PartyMenu.camp_index(2))
	await kit.frames(1)
	pm.handle("member", 1)
	await kit.frames(1)
	var et := pm.equip_tab
	var shop_parts := et.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is ShopFrame or n is CharPanel)
	check_eq([shop_parts.size(), et.drawn["mark"]], [0, 0], "캠프 장비: 상점 틀 없음·칸 0 표시")
	check_eq(pm.camp_list.rows[1].position.y - pm.camp_list.rows[0].position.y, 64.0 + 2.0, "캠프 명령 줄 사이 2(A7c: 줄 여섯이 방향 패드 위에 든다)")


# ---- 판매(S3b, §8.8) ----

const TAIL := "item.neon_rat_tail"
const DRILL := "item.drill_claw"


func test_sell_list_rows_tabs_and_single_sales() -> void:
	_kit()
	var s := _sell_state()
	var sc := await _fresh(s)
	await kit.press_key(KEY_2)
	check_eq([sc.page, sc.tab, sc.multi, sc.buy_list.cursor], ["sell", 0, false, 0], "2 → 판매 목록: 소재 탭·커서 0·여러 개 꺼짐")
	check(sc.buy_tabs.visible and Array(sc.buy_tabs.kinds) == ["material", "gear", "consumable"], "판매 탭 셋")
	check(sc.buy_tabs.buttons.all(func(b: TouchButton) -> bool: return b.text.is_empty()), "판매 탭은 아이콘만")
	check(sc.multi_button.is_visible_in_tree() and sc.multi_button.text == texts.t("shop.multi"), "「여러 개」 단추")
	check_eq(sc.multi_button.get_global_rect(), Rect2(16, 166, 200, 64), "「여러 개」 자리")
	check_eq(sc.buy_list.rows.slice(0, 4).map(func(r: ShopRow) -> Array: return [r.text, r.count, r.right]), [
		[texts.t(TAIL), "3개", "8"], [texts.t("item.cable_scale"), "1개", "12"], [texts.t("item.spore_pouch"), "2개", "10"],
		[texts.t(DRILL), "4개", "16"]], "소재 줄: 자료 차례, 「N개」, 한 개 판매값")
	check_eq(sc.frame.banner.lines()[0], texts.t("shop.desc.sell"), "설명 띠")
	# 2개 이상 → 수량 창(1~가진 수, 「예」 먼저). 「아니오」는 그대로.
	var h := SaveCodec.state_hash(s)
	await kit.tap(kit.center_of(sc.buy_list.rows[0]))
	check_eq([sc.dialog.mode, sc.dialog.max_qty, sc.dialog.qty, sc.dialog.pick], ["qty", 3, 1, ShopDialog.YES], "수량 창 1~3, 「예」 먼저")
	check_eq(sc.dialog.total_text(), "8엔이다. 팔까?", "판매 합계 문구")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_PAGEUP)
	check_eq(sc.dialog.qty, 3, "↑ +1, PageUp +10(끝에서 멈춤)")
	await kit.press_key(KEY_PAGEDOWN)
	check_eq(sc.dialog.qty, 1, "PageDown -10")
	await kit.press_key(KEY_ESCAPE)
	check_eq([SaveCodec.state_hash(s), saves, sc.dialog.mode, sc.page], [h, 0, "", "sell"], "취소: 그대로·저장 없음·판매 목록")
	# 수량 2 팔기.
	await _step(sc, "row", 2)
	await _step(sc, "dialog", ["step", 1])
	await _step(sc, "dialog", ["confirm", null])
	check_eq([s.money, int(s.materials.get("item.spore_pouch", 0)), int(s.shop.sold.get("item.spore_pouch", 0)), saves], [1020, 0, 2, 1],
		"포자 주머니 2 팔기: 소지금·소재·판 수·저장 1")
	check_eq([sc.dialog.mode, sc.dialog.notice_rows.map(func(r: Array) -> String: return r[1])], ["notice", [texts.t("equip.antitox_chip")]],
		"포자 주머니 2 → 해독 칩 입하 알림")
	await kit.press_key(KEY_ESCAPE)
	check_eq([sc.dialog.mode, sc.page, saves], ["", "sell", 1], "알림 취소로 닫기 → 판매 목록, 저장 그대로")
	# 1개 → 확인 창(머리에 [아이콘] 이름).
	await _step(sc, "row", 1)
	check_eq([sc.dialog.mode, sc.dialog.message, sc.dialog.item_icon, sc.dialog.item_name],
		["confirm", "12엔이다. 팔까?", "kind_material", texts.t("item.cable_scale")], "1개: 확인 창")
	check_eq(sc.buy_list.cursor_mode, "chosen", "한 줄 창: 목록 커서 chosen")
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([s.money, s.materials.has("item.cable_scale"), saves], [1032, false, 2], "케이블 인분 팔기")
	# 장비 탭: 가방 장비만(장착한 것은 없다).
	await kit.press_key(KEY_X)
	check_eq([sc.tab, sc.lines.map(func(l: Dictionary) -> String: return l["item"])], [1, ["equip.twin_edge"]], "장비 탭 = 가방 장비")
	check_eq([sc.buy_list.rows[0].right, sc.frame.desc_badges.size()], ["60", 6], "장비 판매값 = 값 ÷ 2, 머리글자 칸(M3 A7: 여섯 직업)")
	await _step(sc, "confirm")
	await _step(sc, "dialog", ["confirm", null])
	check_eq([s.money, s.gear_bag.has("equip.twin_edge"), saves], [1092, false, 3], "트윈 엣지 팔기")
	check(sc.lines.is_empty() and sc.frame.banner.lines()[1] == texts.t("shop.why.empty_sell"), "목록이 비면 empty_sell")
	check(not sc.pad_state()["ok"] and not sc.pad_state()["down"], "빈 목록: 선택·↓ 흐림")
	await kit.press_key(KEY_X)
	check(sc.tab == 2 and sc.lines.is_empty() and sc.frame.banner.lines()[1] == texts.t("shop.why.empty_sell"), "소모품 탭: 빈 목록")
	await kit.press_key(KEY_X)
	check_eq(sc.tab, 2, "탭은 끝에서 감기지 않는다")
	await kit.press_key(KEY_BACKSPACE)
	check_eq([sc.page, sc.root_cursor], ["root", 1], "취소 → 뿌리, 커서 「팔기」")
	await _step(sc, "root", 1)
	check_eq([sc.tab, sc.multi, sc.buy_list.cursor], [0, false, 0], "다시 들어오면 소재 탭·커서 0")


func test_multi_sell_end_states() -> void:
	_kit()
	var s := _sell_state()
	var sc := await _fresh(s)
	await _step(sc, "root", 1)
	await kit.press_key(KEY_M)
	check(sc.multi and sc.multi_button.text == texts.t("shop.multi.sell") and sc.multi_button.checked, "M → 여러 개, 단추 글 「고른 것 팔기」")
	check_eq(sc.frame.banner.lines()[0], texts.t("shop.desc.multi"), "설명 띠 = 여러 개")
	await kit.tap(kit.center_of(sc.buy_list.rows[0]))
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq([sc.marked.keys(), sc.buy_list.rows[0].checked, sc.buy_list.rows[3].checked, sc.dialog.mode], [[TAIL, DRILL], true, true, ""],
		"줄 누르기·선택 = 고름 켜기(창 없음)")
	await kit.press_key(KEY_ENTER)
	check_eq(sc.marked.keys(), [TAIL], "다시 선택 = 고름 끄기")
	await _step(sc, "row", 3)
	# 취소: 고름 그대로, 저장 없음.
	var h := SaveCodec.state_hash(s)
	await kit.press_key(KEY_M)
	check_eq([sc.dialog.mode, sc.ask, sc.buy_list.cursor_mode], ["confirm", "sell_multi", "none"], "고른 것 팔기 → 확인 창, 목록 커서 none")
	check_eq(sc.dialog.message, "%s엔이다. 팔까?" % ShopRow.grouped(3 * 8 + 4 * 16), "합계 = 고른 줄 가진 수 전부")
	await kit.tap(kit.center_of(sc.dialog.no_button))
	check_eq([SaveCodec.state_hash(s), saves, sc.multi, sc.marked.keys(), sc.buy_list.cursor], [h, 0, true, [TAIL, DRILL], 3],
		"「아니오」: 상태·저장 그대로, 여러 개·고름·커서 그대로")
	# 거부(money_full): 고름·여러 개 그대로, 이유, 저장 없음.
	s.money = BattleLimits.MONEY_MAX - 1
	h = SaveCodec.state_hash(s)
	await _step(sc, "multi")
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([SaveCodec.state_hash(s), saves, sc.multi, sc.marked.keys(), sc.notice, sc.dialog.mode],
		[h, 0, true, [TAIL, DRILL], texts.t("shop.why.money_full"), ""], "거부: 그대로·이유·저장 없음")
	s.money = 100
	# 받아들임: 저장 한 번(풀림 셋이어도), 고름 지움·여러 개 끔, 커서는 사라진 줄 → min(앞 번호, 새 마지막).
	await _step(sc, "multi")
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([s.money, s.materials.has(TAIL), s.materials.has(DRILL), saves], [100 + 24 + 64, false, false, 1], "받아들임: 판 값·소재·저장 1")
	check_eq([sc.multi, sc.marked.keys(), sc.lines.size(), sc.buy_list.cursor], [false, [], 2, 1], "고름 지움·여러 개 끔·커서 = 새 마지막 줄")
	check_eq([sc.dialog.mode, sc.ask, sc.buy_list.cursor_mode], ["notice", "notice", "none"], "풀림 → 입하 알림(목록 커서 none)")
	check_eq(sc.dialog.notice_rows.map(func(r: Array) -> String: return r[1]),
		[texts.t("equip.tactical_baton"), texts.t("equip.visor"), texts.t("equip.mag_boots")], "알림 물건 = 사건의 진열 차례")
	await kit.press_key(KEY_ENTER)
	check_eq([sc.dialog.mode, sc.ask, sc.page, sc.buy_list.cursor_mode, saves], ["", "", "sell", "cursor", 1], "알림 닫기 → 같은 판매 목록, cursor")


func test_multi_cancel_tab_change_and_remaining_cursor() -> void:
	_kit()
	var s := _sell_state()
	var sc := await _fresh(s)
	await _step(sc, "root", 1)
	await _step(sc, "multi")
	await _step(sc, "row", 1)
	await kit.press_key(KEY_ESCAPE)
	check_eq([sc.page, sc.multi, sc.marked.keys()], ["sell", false, []], "여러 개에서 취소 → 고름 지우고 끔(판매 목록 그대로)")
	await _step(sc, "multi")
	await _step(sc, "row", 2)
	await kit.press_key(KEY_X)
	check_eq([sc.tab, sc.multi, sc.marked.keys(), sc.buy_list.cursor], [1, true, [], 0], "여러 개를 켠 채 탭 바꿈: 고름 지움, 여러 개 그대로, 커서 0")
	await kit.press_key(KEY_Z)
	await kit.tap(kit.center_of(sc.frame.back_button))
	check_eq([sc.page, sc.multi], ["sell", false], "「뒤로」도 여러 개만 끈다")
	# 받아들임 뒤 커서 물건이 남아 있으면 그 물건: 꼬리 1개만 팔기(커서 꼬리, 2개 남음).
	await _step(sc, "row", 0)
	await _step(sc, "dialog", ["confirm", null])
	check_eq([int(s.materials[TAIL]), sc.buy_list.cursor, sc.lines[0]["item"]], [2, 0, TAIL], "남은 물건에 커서")
	# 마지막 줄(드릴 발톱 4개 전부) 팔기 → 커서 = 새 마지막 줄.
	await _step(sc, "row", 3)
	await _step(sc, "dialog", ["step", 10])
	await _step(sc, "dialog", ["confirm", null])
	check_eq([s.materials.has(DRILL), sc.lines.size(), sc.buy_list.cursor], [false, 3, 2], "마지막 줄을 다 팔면 커서 = 새 마지막")
	check_eq(sc.dialog.mode, "notice", "드릴 발톱 4 → 입하 알림")
	await _step(sc, "dialog", ["cancel", null])
	# 마지막 묶음: 남은 줄을 모두 여러 개로 팔면 목록이 빈다.
	await _step(sc, "multi")
	for i in sc.lines.size():
		await _step(sc, "row", i)
	await _step(sc, "multi")
	await _step(sc, "dialog", ["confirm", 0])
	check(sc.lines.is_empty() and sc.frame.banner.lines()[1] == texts.t("shop.why.empty_sell") and sc.frame.desc_title.is_empty(),
		"마지막 묶음: 빈 목록·비교 없음·empty_sell")
	check_eq(sc.frame.panel.drawn["mark"], -1, "판 비교 없음")


func test_sell_pad_matches_keys() -> void:
	_kit()
	var sl := [["root", 1]]
	var mu := sl + [["multi"]]
	var qt := sl + [["row", 0]]
	var nt := qt + [["dialog", ["step", 10]], ["dialog", ["confirm", 0]]]
	await _parity([
		["판매 ↑(가장자리)", sl, "up", true, true], ["판매 ↓", sl, "down", true, false],
		["판매 ←", sl, "left", true, false], ["판매 →", sl, "right", true, false],
		["판매 선택", sl, "ok", true, false], ["판매 취소", sl, "back", true, false],
		["여러 개 선택(고름)", mu, "ok", true, false], ["여러 개 취소(끔)", mu, "back", true, false],
		["수량 ↑", qt, "up", true, false], ["수량 ↓(가장자리)", qt, "down", true, true],
		["수량 →", qt, "right", true, false], ["수량 선택", qt, "ok", true, false], ["수량 취소", qt, "back", true, false],
		["알림 ↑", nt, "up", false, false], ["알림 ←", nt, "left", false, false],
		["알림 선택", nt, "ok", true, false], ["알림 취소", nt, "back", true, false],
	], _sell_state)


func test_sell_yellow_and_held_presses() -> void:
	_kit()
	var sc := await _fresh(_sell_state())
	await _step(sc, "root", 1)
	check_eq(_yellow(sc), ["Row_0"], "판매: 줄 커서 하나")
	await _step(sc, "row", 0)
	check_eq(_yellow(sc), ["Yes"], "수량 창: 고른 단추 하나")
	await _step(sc, "dialog", ["cancel", null])
	await _step(sc, "multi")
	await _step(sc, "row", 0)
	check_eq(_yellow(sc), ["Row_0"], "여러 개: 고른 줄은 하늘색, 노랑은 커서 하나")
	await _step(sc, "multi")
	check_eq(_yellow(sc), ["Yes"], "고른 것 팔기 확인: 창 단추 하나(목록 커서 없음)")
	check(not sc.buy_list.rows[0].chosen and not sc.buy_list.rows[0].selected, "목록 커서 줄을 그리지 않는다")
	await _step(sc, "dialog", ["confirm", 0])
	check_eq(_yellow(sc), ["Ok"], "입하 알림: 「확인」 하나")
	await _step(sc, "dialog", ["confirm", null])
	# 여러 개를 켜고 끄면 문맥이 바뀐다: 줄을 누른 채 M → 떼도 고르지 않는다.
	var p := kit.center_of(sc.buy_list.rows[0])
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	await kit.press_key(KEY_M)
	check(not sc.buy_list.rows[0].held, "M(여러 개) → 눌림을 버렸다")
	kit.touch(FINGER, p, false)
	await kit.frames(2)
	check_eq([sc.marked.keys(), sc.dialog.mode], [[], ""], "뗀 손가락은 고르지도 팔지도 않는다")


## 웹 확인 상점 단계의 고정 저장(tools/web_check_shop_save.json, §8.12)이 지금 정의로 읽히고 고정 조건을 지키는지.
func test_web_check_shop_save_fixture() -> void:
	if _defs == null:
		_defs = Fx.defs()
	var text := FileAccess.get_file_as_string("res://tools/web_check_shop_save.json")
	var r := SaveCodec.decode(text, _defs)
	check(r.ok(), "고정 저장 읽힘: %s" % (r.error if not r.ok() else ""))
	if not r.ok():
		return
	var s := r.state
	check_eq([s.money, s.materials, s.shop.sold, s.shop.bought.size(), s.battle == null, s.encounter.pending, s.wiped],
		[200, {TAIL: 3, DRILL: 1}, {}, 0, true, false, false], "새 게임 + 꼬리 3·드릴 발톱 1, 소지금 200")
	var ev := ShopRules.sell(s, JUNK, [{"item": TAIL, "qty": 3}])
	check(ev.size() == 2 and ev[1]["items"] == ["equip.visor"], "꼬리 3 팔기 → 바이저 입하 %s" % str(ev))
	var cat := ShopRules.catalog(_defs, s, JUNK)
	check(cat.any(func(l: Dictionary) -> bool: return l["item"] == "equip.twin_edge" and l["price"] <= 200), "트윈 엣지를 살 수 있다")


# ---- 독립 검토 고침(R1~R3) ----

static func _no_css(_p: Vector2, _c: Control) -> Array:
	return [0, 0]


## 판이 견주는 칸(_refresh_buy 와 같은 판정).
static func _expected_mark(sc: ShopScreen) -> int:
	var item: String = sc.lines[sc.buy_list.cursor]["item"]
	return sc.best_slot(item, sc.member, sc.preview_bag(item)) if sc.can_wear(item, sc.member) else -1


## R1: 줄을 누른 채 ↓ 를 누르고 같은 프레임에 줄을 떼면 입력은 하나만 받고, 커서·설명·견주는 칸·debug_info 가 맞는다.
func test_same_frame_row_release_is_rejected_without_moving_the_cursor() -> void:
	_kit()
	var sc := await _fresh(_state())
	await _to_list(sc, 0)
	var p := kit.center_of(sc.buy_list.rows[0])
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	var before := sc.accepted_inputs
	_key_event(KEY_DOWN, true)
	kit.touch(FINGER, p, false)
	_key_event(KEY_DOWN, false)
	await kit.frames(2)
	check_eq(sc.accepted_inputs - before, 1, "같은 프레임: 입력 하나만")
	check_eq(sc.buy_list.cursor, 1, "↓ 만 받았다: 커서 1")
	check_eq(sc.frame.desc_title, sc.buy_list.rows[sc.buy_list.cursor].text, "설명 제목 = 커서 줄")
	check_eq(sc.frame.panel.drawn["mark"], _expected_mark(sc), "견주는 칸 = 커서 줄의 칸")
	check_eq(sc.debug_info(_no_css)["cursor"]["row"], sc.buy_list.cursor, "debug_info 줄 = 커서")


## R1: 탭을 누른 채 ↓ 를 누르고 같은 프레임에 탭을 떼면 탭은 그대로다(보이는 탭·줄·debug_info 가 맞는다).
func test_same_frame_tab_release_is_rejected_without_changing_the_tab() -> void:
	_kit()
	var sc := await _fresh(_state())
	await _to_list(sc, 0)
	var p := kit.center_of(sc.buy_tabs.buttons[2])
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	var before := sc.accepted_inputs
	_key_event(KEY_DOWN, true)
	kit.touch(FINGER, p, false)
	_key_event(KEY_DOWN, false)
	await kit.frames(2)
	check_eq(sc.accepted_inputs - before, 1, "같은 프레임: 입력 하나만")
	check_eq([sc.tab, sc.buy_tabs.current], [0, 0], "탭 그대로(화면 = 탭 줄)")
	check(sc.buy_tabs.buttons[0].checked and not sc.buy_tabs.buttons[2].checked, "보이는 탭 = 「전체」")
	check(sc.lines.any(func(l: Dictionary) -> bool: return l["kind"] == "sword"), "줄은 「전체」 것(검 줄이 있다)")
	check_eq(sc.debug_info(_no_css)["tab"], "all", "debug_info 탭 = all")
	# 받아들인 탭 누르기는 그대로 탭을 바꾼다.
	await kit.tap(p)
	check_eq([sc.tab, sc.buy_tabs.current, sc.debug_info(_no_css)["tab"]], [2, 2, "staff"], "다음 프레임 탭 누르기 → 지팡이")
	check(sc.lines.all(func(l: Dictionary) -> bool: return l["kind"] == "staff"), "줄 = 지팡이")


## R2: 고름이 바뀌면(문맥) 바깥에서 누르고 있던 「여러 개」·키패드는 떼도 일하지 않는다.
func test_mark_changes_cancel_held_multi_and_pad_presses() -> void:
	_kit()
	var sc := await _fresh(_sell_state())
	await _step(sc, "root", 1)
	await _step(sc, "multi")
	# 고름 없음에서 「고른 것 팔기」를 누른 채 줄을 고른다 → 떼도 확인 창이 뜨지 않는다.
	var m := kit.center_of(sc.multi_button)
	kit.touch(FINGER, m, true)
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)
	check_eq(sc.marked.keys(), [TAIL], "준비: 꼬리 고름")
	kit.touch(FINGER, m, false)
	await kit.frames(2)
	check_eq([sc.ask, sc.dialog.mode, sc.multi, sc.marked.keys()], ["", "", true, [TAIL]], "고름 뒤 뗀 「여러 개」: 아무 일도 없다")
	# 고름 하나에서 누른 채 고름을 끈다 → 떼도 여러 개를 끄지 않는다.
	kit.touch(FINGER, m, true)
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)
	check_eq(sc.marked.keys(), [], "준비: 고름 끔")
	kit.touch(FINGER, m, false)
	await kit.frames(2)
	check_eq([sc.ask, sc.multi], ["", true], "고름 끈 뒤 뗀 「여러 개」: 여러 개 그대로")
	# 키패드 「선택」을 누른 채 Enter 로 고른다 → 떼도 고름을 다시 끄지 않는다.
	var ok := kit.center_of(_pad_button(sc, "ok"))
	kit.touch(FINGER, ok, true)
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)
	check_eq(sc.marked.keys(), [TAIL], "준비: 꼬리 고름")
	kit.touch(FINGER, ok, false)
	await kit.frames(2)
	check_eq(sc.marked.keys(), [TAIL], "뗀 키패드 「선택」: 고름 그대로")


## R3: 묶음 확인 창은 연 때의 줄을 판다. 창이 열린 동안 디버그 보급으로 같은 장비가 늘어도 보인 값만큼만 판다.
func test_batch_sale_sells_the_quoted_lines_after_a_debug_supply() -> void:
	timeout_sec = 120.0
	_kit()
	var dungeon := await kit.open_town("native", 7, "debug=1")  # M3 A2: 상점은 마을 광장 「정크 공방」
	var s := dungeon.state
	s.gear_bag["equip.twin_edge"] = 1
	await kit.tap(kit.center_of(dungeon.town_screen.plaza_list.rows[1]))
	var sc := dungeon.shop_screen
	await _step(sc, "root", 1)
	await _step(sc, "tab", 1)
	await _step(sc, "multi")
	await _step(sc, "row", _row_of(sc, "equip.twin_edge"))
	await _step(sc, "multi")
	var quote := sc.dialog.message
	check_eq(quote, "60엔이다. 팔까?", "준비: 트윈 엣지 1개 60엔")
	var money := s.money
	dungeon._on_debug_request(JSON.stringify({"op": "supply", "item": "equip.twin_edge", "n": 1}))
	await kit.frames(2)
	check_eq([int(s.gear_bag["equip.twin_edge"]), sc.dialog.message], [2, quote], "보급 뒤 가방 2, 창 글 그대로")
	var saves0 := dungeon.autosave_count  # 보급이 한 번 저장했다(그 뒤의 팔기만 센다)
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([s.money - money, int(s.gear_bag.get("equip.twin_edge", 0)), dungeon.autosave_count - saves0], [60, 1, 1],
		"「예」: 보인 60엔·1개만 팔고 1개 남음, 저장 1")


## R3: 연 때의 줄을 더는 갖고 있지 않으면 규칙이 거부한다(이유, 저장 없음, 소지금·가방·고름·여러 개 그대로).
## 줄어든 경우(꼬리 3 → 2)는 옛 코드가 남은 2개를 팔던 곳, 없어진 경우는 장비 탭.
func test_batch_sale_of_lines_no_longer_owned_is_rejected() -> void:
	_kit()
	var s := _sell_state()
	var sc := await _fresh(s)
	await _step(sc, "root", 1)
	await _step(sc, "multi")
	await _step(sc, "row", 0)
	await _step(sc, "multi")
	check_eq([sc.ask, sc.dialog.message], ["sell_multi", "24엔이다. 팔까?"], "준비: 꼬리 3개 묶음 확인 24엔")
	s.materials[TAIL] = 2
	sc.refresh_view()
	await kit.frames(1)
	var h := SaveCodec.state_hash(s)
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([SaveCodec.state_hash(s), saves, s.money, int(s.materials.get(TAIL, 0))], [h, 0, 1000, 2], "줄어듦 → 거부: 상태·저장·소지금·소재 그대로")
	check_eq(sc.notice, texts.t("shop.why.not_now"), "이유를 알림 줄에")
	check_eq([sc.multi, sc.marked.keys(), sc.ask], [true, [TAIL], ""], "여러 개·고름 그대로, 묶음 풀림")
	# 장비 탭: 고른 장비가 가방에서 없어졌다.
	await kit.press_key(KEY_X)
	await _step(sc, "row", 0)
	await _step(sc, "multi")
	check_eq([sc.ask, sc.dialog.message], ["sell_multi", "60엔이다. 팔까?"], "준비: 트윈 엣지 묶음 확인 60엔")
	s.gear_bag.erase("equip.twin_edge")
	sc.refresh_view()
	await kit.frames(1)
	h = SaveCodec.state_hash(s)
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([SaveCodec.state_hash(s), saves, s.money], [h, 0, 1000], "없어짐 → 거부: 상태·저장·소지금 그대로")
	check_eq([sc.notice, sc.multi, sc.marked.keys()], [texts.t("shop.why.not_now"), true, ["equip.twin_edge"]], "이유, 여러 개·고름 그대로")


# ---- D28-b: 공용 목록(InventoryList) 위의 상점 목록 ----

## 판매 상태: 가방에 장비 전부(목록이 넘친다), 소재 전부(정의 자료 차례와 ID 차례가 다르다).
func _full_bag_state() -> ExplorationState:
	var s := _state(1000)
	for id in s.defs.battle.equipment_ids:
		s.gear_bag[id] = 1
	for id in s.defs.battle.material_ids:
		s.materials[id] = 2
	return s


static func _shown(sc: ShopScreen) -> bool:
	return sc.buy_list.inv.shown_at(sc.buy_list.cursor)


## D28-b ①: 판매 소재 줄은 캠프 소지품과 같은 곳(BagRows)·같은 차례(정의 자료 차례 = data/items/materials.json).
func test_sell_materials_follow_the_definition_order_like_the_camp() -> void:
	_kit()
	var s := _full_bag_state()
	var ids: Array = Array(s.defs.battle.material_ids)
	var by_id := ids.duplicate()
	by_id.sort()
	check(by_id != ids, "준비: 정의 자료 차례와 ID 차례가 다르다")
	var sc := await _fresh(s)
	await _step(sc, "root", 1)
	check_eq(sc.lines.map(func(l: Dictionary) -> String: return l["item"]), ids, "판매 소재 줄 = 정의 자료 차례")
	check_eq(sc.lines.map(func(l: Dictionary) -> String: return l["item"]),
		BagRows.bag(s, ["material"]).map(func(l: Dictionary) -> String: return l["item"]), "캠프 소지품과 같은 가방 줄")
	check_eq(sc.debug_info(_no_css)["rows"].map(func(r: Dictionary) -> String: return r["name"]),
		ids.map(func(id: String) -> String: return texts.t(str(s.defs.battle.materials[id]))), "snapshot 줄 이름도 같은 차례")
	check_eq([int(sc.lines[0]["price"]), str(sc.lines[0]["icon"])], [ShopRules.sell_price(s.defs, ids[0]), "kind_material"], "판매값·아이콘은 상점이 붙인다")


## D28-b ②: 끝에서 ↑↓ 는 옮기지 않는다. 커서 줄을 손으로 내려 가렸으면 한 번 눌러 보이게만 하고(입력 하나), 다 보이면 아무 일 없다.
## 키와 키패드가 같다.
func test_list_end_reveals_a_hidden_cursor_by_keys_and_keypad() -> void:
	_kit()
	var sc := await _fresh(_full_bag_state())
	await _step(sc, "root", 1)
	await _step(sc, "tab", 1)
	var last := sc.lines.size() - 1
	check(sc.buy_list.scroll.max_scroll() > 0.0 and last > 8, "준비: 장비 판매 목록이 넘친다(%d 줄)" % (last + 1))
	sc.buy_list.set_cursor(last)
	await kit.frames(1)
	for how in ["key", "pad"]:
		sc.buy_list.scroll.scroll_to(0.0)
		await kit.frames(1)
		check(not _shown(sc), how + " 준비: 손으로 올려 끝 커서가 가려졌다")
		check(sc.pad_state()["down"] and not _pad_button(sc, "down").disabled, how + ": 끝에서도 ↓ 는 켜져 있다")
		var n := sc.accepted_inputs
		if how == "key":
			await kit.press_key(KEY_DOWN)
		else:
			await kit.tap(kit.center_of(_pad_button(sc, "down")), FINGER)
		check_eq([sc.buy_list.cursor, _shown(sc), sc.accepted_inputs], [last, true, n + 1], how + ": 끝 ↓ = 되돌림(입력 하나), 커서 그대로")
		await kit.frames(1)
		var pre := _sig(sc)
		var scroll := sc.buy_list.scroll.scroll
		if how == "key":
			await kit.press_key(KEY_DOWN)
		else:
			await kit.tap(kit.center_of(_pad_button(sc, "down")), FINGER)
		check_eq([_sig(sc), sc.buy_list.scroll.scroll], [pre, scroll], how + ": 다 보이면 끝 ↓ 는 아무 일 없음")
	# 첫 줄: ↑ 도 같다.
	sc.buy_list.set_cursor(0)
	sc.buy_list.scroll.scroll_to(sc.buy_list.scroll.max_scroll())
	await kit.frames(1)
	check(not _shown(sc), "준비: 손으로 내려 첫 줄 커서가 가려졌다")
	var m := sc.accepted_inputs
	await kit.press_key(KEY_UP)
	check_eq([sc.buy_list.cursor, _shown(sc), sc.accepted_inputs], [0, true, m + 1], "첫 줄 ↑ = 되돌림")
	await kit.frames(1)
	var pre0 := _sig(sc)
	await kit.tap(kit.center_of(_pad_button(sc, "up")), FINGER)
	check_eq(_sig(sc), pre0, "다 보이면 첫 줄 ↑(키패드)는 아무 일 없음")


## D28-b ③: 줄 자료(값·흐림·진열)가 바뀌면 커서 줄을 보이게 한다(지금 상점). 같은 줄로 다시 그리기는 손으로 내린 자리를 지킨다.
func test_list_reveals_the_cursor_when_its_rows_change() -> void:
	_kit()
	var s := _sold_state()
	var sc := await _fresh(s)
	await _to_list(sc, 1)
	var last := sc.lines.size() - 1
	check(sc.buy_list.scroll.max_scroll() > 0.0, "준비: 방어구 목록이 넘친다(%d 줄)" % (last + 1))
	sc.buy_list.set_cursor(last)
	sc.buy_list.scroll.scroll_to(0.0)
	await kit.frames(1)
	check(not _shown(sc), "준비: 손으로 올려 커서 줄이 가려졌다")
	sc.refresh_view()
	await kit.frames(1)
	check_eq([sc.buy_list.scroll.scroll, sc.buy_list.cursor], [0.0, last], "같은 줄 다시 그리기: 손으로 내린 자리 그대로")
	# 값이 바뀜(소지금 0 → 흐림).
	s.money = 0
	sc.refresh_view()
	await kit.frames(1)
	check(sc.buy_list.rows[0].dimmed, "준비: 소지금 0 → 줄이 흐려졌다")
	check_eq([sc.buy_list.cursor, _shown(sc)], [last, true], "소지금이 바뀌어 줄이 바뀜 → 커서 줄이 보인다")
	# 진열이 바뀜(꼬리를 팔아 바이저 입하, 줄이 는다).
	sc.buy_list.scroll.scroll_to(0.0)
	await kit.frames(1)
	var hidden := not _shown(sc)
	var n := sc.lines.size()
	s.materials["item.neon_rat_tail"] = 3
	var ev := ShopRules.sell(s, JUNK, [{"item": "item.neon_rat_tail", "qty": 3}])
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "unlocked"), "준비: 꼬리를 팔아 풀림")
	sc.refresh_view()
	await kit.frames(1)
	check_eq(sc.lines.size(), n + 1, "준비: 진열 줄이 하나 늘었다")
	check(hidden and _shown(sc), "진열이 바뀌어 줄이 바뀜 → 커서 줄이 보인다")


## D28-b ④: 빈 목록은 커서 -1. 선택·↑↓·줄·키·키패드가 아무것도 바꾸지 않고 오류도 없다(판매 소모품 탭, 소재가 없는 판매, 구매 「아이템」).
func test_empty_lists_have_cursor_minus_one_and_take_no_input() -> void:
	_kit()
	var cases := [
		["구매 아이템(소모품 진열 없음)", func() -> ExplorationState: return _no_items_state(), [["root", 0], ["branch", 3]]],
		["판매 소모품 탭", func() -> ExplorationState: return _sell_state(), [["root", 1], ["tab", 2]]],
		["판매 소재 없음", func() -> ExplorationState:
			var s := _state()
			s.materials = {}
			return s, [["root", 1]]],
	]
	for c in cases:
		var tag: String = c[0]
		var sc := await _fresh((c[1] as Callable).call())
		for st in c[2]:
			await _step(sc, st[0], st[1])
		check(sc.lines.is_empty() and sc.buy_list.row_count == 0, tag + ": 준비: 빈 목록")
		check_eq([sc.buy_list.cursor, sc.debug_info(_no_css)["cursor"]["row"]], [-1, -1], tag + ": 커서 -1(snapshot 도)")
		check_eq(sc.frame.desc_title, "", tag + ": 설명 비움")
		check_eq(sc.frame.banner.lines()[1], texts.t("shop.why.empty_buy" if sc.page == "buy" else "shop.why.empty_sell"), tag + ": 빈 목록 이유")
		var pad := sc.pad_state()
		check(not pad["ok"] and not pad["up"] and not pad["down"], tag + ": 선택·↑↓ 흐림")
		var pre := _sig(sc)
		for a in [["confirm", null], ["cursor", 1], ["cursor", -1], ["row", 0], ["row", -1]]:
			check(not sc.handle(a[0], a[1]), "%s: %s 거부" % [tag, str(a)])
			await kit.frames(1)
		for k in [KEY_ENTER, KEY_DOWN, KEY_UP]:
			await kit.press_key(k)
		for k in ["ok", "up", "down"]:
			await kit.tap(kit.center_of(_pad_button(sc, k)), FINGER)
		check_eq(_sig(sc), pre, tag + ": 아무것도 바뀌지 않는다")
		check_eq([sc.buy_list.cursor, sc.dialog.mode, sc.notice], [-1, "", ""], tag + ": 커서 -1·창 없음·알림 없음")


# ---- 「아이템」 갈래·소모품 판매(M3 A4b §6.4) ----

const MEDICA := "use.medica"
const BEACON := "use.ariadne_beacon"


## 「아이템」 갈래 = 소모품 줄(진열 차례, 풀린 줄만, 탭 없음). 줄 → 수량 창(「예」 먼저, 최대 = 공용 가방에 드는 수·소지금으로 살 수 있는 수),
## 「예」 → 산 수만큼·저장 하나. 가방 60/60 은 창 없이 이유만. 죽이는 변이: M-P1(최대가 가방 빈칸을 보지 않음)·M-P2(산 수가 늘 1).
func test_item_branch_buys_consumables_by_quantity() -> void:
	_kit()
	var s := _state(1000)
	s.materials = {"item.spore_pouch": 3, "item.glow_scale": 2}
	ShopRules.sell(s, JUNK, [{"item": "item.spore_pouch", "qty": 3}, {"item": "item.glow_scale", "qty": 2}])
	s.money = 100
	var sc := await _fresh(s)
	await _to_list(sc, 3)
	check_eq(sc.lines.map(func(l: Dictionary) -> String: return l["item"]),
		[MEDICA, "use.amrita", "use.nectar", "use.theriaca_a", "use.theriaca_b", BEACON], "풀린 줄(포자 3 → 암리타, 발광 비늘 2 → 넥타)까지 진열 차례")
	check(not sc.buy_tabs.visible, "탭 없음")
	check_eq(sc.buy_list.rows[0].text, texts.t("use.medica"), "줄 이름")
	await kit.tap(kit.center_of(sc.buy_list.rows[0]))
	check_eq([sc.dialog.mode, sc.ask, sc.dialog.pick, sc.dialog.qty, sc.dialog.max_qty], ["qty", "buy_item", ShopDialog.YES, 1, 5],
		"수량 창, 「예」 먼저, 최대 = 100엔 ÷ 20")
	check_eq([sc.dialog.item_icon, sc.dialog.item_name, sc.dialog.total_text()], [BagRows.CONSUMABLE_ICON, texts.t("use.medica"), "20엔이다. 살까?"],
		"창 머리·합계")
	check_eq(_yellow(sc), ["Yes"], "노랑은 「예」 하나")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(sc.dialog.total_text(), "60엔이다. 살까?", "↑↑ → 3개")
	await kit.press_key(KEY_ENTER)
	check_eq([s.money, s.consumables, saves, sc.dialog.mode, sc.page], [40, {MEDICA: 3}, 1, "", "buy"], "3개 사기·저장 하나·목록 그대로")
	# 가방 58/60 → 최대 2(소지금이 넉넉해도).
	s.money = 1000
	s.materials = {TAIL: 55}
	await _step(sc, "row", 0)
	check_eq([sc.dialog.mode, sc.dialog.max_qty], ["qty", 2], "가방 58/60: 최대 = 빈칸 2")
	await kit.press_key(KEY_ESCAPE)
	check_eq([s.consumables, saves, sc.dialog.mode], [{MEDICA: 3}, 1, ""], "취소: 그대로")
	# 가방 60/60 → 창 없이 이유만.
	s.materials = {TAIL: 57}
	var h := SaveCodec.state_hash(s)
	await _step(sc, "row", 0)
	check_eq([sc.dialog.mode, sc.notice, SaveCodec.state_hash(s), saves], ["", texts.t("shop.why.bag_full"), h, 1], "가방 60/60: 「더 가질 수 없다」만")


## 판매 「소모품」 탭 = 가진 소모품(정의 차례), 판매값 = 값 ÷ 2, 팔면 소지금·저장 하나(소모품 판매는 입하에 쓰이지 않는다).
func test_sell_consumables_tab_lists_and_sells_owned_consumables() -> void:
	_kit()
	var s := _state(1000)
	s.consumables = {BEACON: 2, MEDICA: 1}
	var sc := await _fresh(s)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_X)
	await kit.press_key(KEY_X)
	check_eq([sc.tab, sc.lines.map(func(l: Dictionary) -> String: return l["item"])], [2, [MEDICA, BEACON]], "소모품 탭: 정의 차례")
	check_eq(sc.buy_list.rows.slice(0, 2).map(func(r: ShopRow) -> Array: return [r.text, r.count, r.right]),
		[[texts.t("use.medica"), "1개", "10"], [texts.t("use.ariadne_beacon"), "2개", "75"]], "줄: 이름·「N개」·한 개 판매값(값 ÷ 2)")
	await _step(sc, "row", 0)
	check_eq([sc.dialog.mode, sc.dialog.message, sc.dialog.item_icon], ["confirm", "10엔이다. 팔까?", BagRows.CONSUMABLE_ICON], "1개: 확인 창")
	await _step(sc, "dialog", ["confirm", 0])
	check_eq([s.money, s.consumables, saves, s.shop.sold.has(MEDICA)], [1010, {BEACON: 2}, 1, false], "메디카 팔기: +10엔·저장 하나·판 수에 안 들어감")
	await _step(sc, "row", 0)
	check_eq([sc.dialog.mode, sc.dialog.max_qty, sc.dialog.total_text()], ["qty", 2, "75엔이다. 팔까?"], "2개: 수량 창")
