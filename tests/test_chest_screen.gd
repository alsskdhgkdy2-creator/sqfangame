## 상자·잠긴 문·귀중품·옛 저장 옮김의 화면(M3 A3b, 설계 노트 §6·§8.4): 실제 미궁(open_arbor)으로 띄운다.
## 상자 물음(층 3 kind "chest", 「예」 먼저, Esc·Backspace·「아니오」 = 닫기만, 「예」 = OPEN·안내·자동 저장), 물음의 경합,
## 잠긴 문 안내와 시야 다시 만들기, 캠프 소지품의 귀중품 줄(상점 판매에는 없음), 시험 층 저장을 옮긴 알림(읽는 길마다)과 슬롯 카드.
## 시험마다 죽이는 변이(M-U…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const V7 := preload("res://tests/test_save_v7.gd")
## B1F: 시작 칸 (9,18) 북쪽, 상자 c1 (10,16) 네온 쥐 꼬리 ×3, 그 서쪽 (9,16).
const C1 := Vector2i(10, 16)
const BESIDE := Vector2i(9, 16)
const RAT := "item.neon_rat_tail"
const MOSS := "key.moss_card"

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _open(query: String = "", prepare: Callable = Callable()) -> DungeonScreen:
	timeout_sec = 60.0
	if kit != null:
		kit.dispose()  # 앞 키트를 치우지 않으면 그 화면이 트리에 남아 뒤 시험의 입력을 가로챈다
	kit = Kit.new(tree)
	return await kit.open_arbor("native", 7, query, prepare)


## 실제 미궁을 유지하는 다시 열기 준비.
static func _arbor(mode: String = "labyrinth") -> Callable:
	return func(s: DungeonScreen) -> void:
		s.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		s.start_mode = mode


## 임시 저장 폴더에 슬롯 파일을 쓴다(화면을 열기 전에도 된다).
func _write_slot(slot: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(kit.dir + "/saves")
	var f := FileAccess.open("%s/saves/%s.json" % [kit.dir, slot], FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_slot(slot: String, ext: String = "json") -> String:
	return FileAccess.get_file_as_string("%s/saves/%s.%s" % [kit.dir, slot, ext])


## (9,16) 에서 동쪽(상자 쪽)을 보고 선다(인카운트 없음).
func _beside_c1(s: DungeonScreen) -> void:
	s.state.party.at = BESIDE
	s.state.party.facing = Dir.E
	s.state.encounter.threshold = 99999
	s._set_state(s.state)
	await kit.frames(2)


func _labels(s: DungeonScreen) -> Array:
	return s.modal.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _focus(s: DungeonScreen) -> Control:
	return s.get_viewport().gui_get_focus_owner()


func _mesh_id(s: DungeonScreen) -> int:
	return s.view._mesh_instance.mesh.get_instance_id()


func _key_event(code: int, pressed: bool, echo: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	Input.parse_input_event(k)
	Input.flush_buffered_events()


func _wait_idle(s: DungeonScreen) -> void:
	for i in 120:
		if not s.view.is_busy():
			break
		await kit.frames(1)
	await kit.frames(3)


## U1 (M-U1a 처음 포커스 「아니오」, M-U1b OPEN 뒤 자동 저장 없음): 새 게임 B1F 에서 실제 키로 c1 에 서면 상자 물음.
## Esc·Backspace·「아니오」는 닫기만(저장 없음, 캠프 안 열림), 조사로 다시 묻고, Enter(「예」) = 열기·안내·자동 저장·시야 다시 만들기.
## 떠났다 돌아오면 묻지 않고, 조사하면 「빈 상자다」.
func test_chest_question_and_open() -> void:
	var s := await _open()
	var snap := s.debug_snapshot()
	check_eq([s.state.floor_def.id, s.state.party.at, snap["set"], snap["save_dir"], s._floor_label.text],
		["b1f", Vector2i(9, 18), "game", kit.dir + "/saves", "네온 이끼숲 / B1F"], "준비: 실제 미궁 B1F 시작 칸")
	s.state.encounter.threshold = 99999
	for k in [KEY_W, KEY_W, KEY_E]:
		await kit.press_key(k)
	await kit.frames(3)
	check_eq([s.state.party.at, s.modal.kind], [C1, "chest"], "상자 칸에 멈추면 상자 물음")
	check_eq(s.modal.title_plate.text, "보물상자", "제목 문패")
	check(_labels(s).has("보물상자가 있다. 열어 볼까?"), "물음 글 %s" % str(_labels(s)))
	var yes := s.modal.find_child("ChestYes", true, false) as Button
	var no := s.modal.find_child("ChestNo", true, false) as Button
	check(yes != null and no != null and yes.text == "예" and no.text == "아니오" and yes.size.y >= 64.0, "「예」「아니오」 64 이상")
	check_eq(_focus(s), yes, "처음 커서는 「예」(D25)")
	snap = s.debug_snapshot()
	check(snap["modal"] == "chest" and snap["buttons"].has("ChestYes") and snap["buttons"].has("ChestNo") and snap["chest_here"] == "c1",
		"스냅숏 modal·단추·chest_here")
	var h := kit.hash_now()
	for how in ["Esc", "Backspace", "아니오"]:
		if s.modal.kind != "chest":
			await kit.press_key(KEY_SPACE)  # 조사로 다시 묻는다(조사도 규칙 행동이라 자동 저장한다)
			check_eq(s.modal.kind, "chest", "%s: 조사로 다시 묻는다" % how)
		var saves := s.autosave_count
		match how:
			"Esc":
				await kit.press_key(KEY_ESCAPE)
			"Backspace":
				await kit.press_key(KEY_BACKSPACE)
			_:
				await kit.click(kit.center_of(s.modal.find_child("ChestNo", true, false)))
		await kit.frames(2)
		check_eq([s.modal.kind, s.autosave_count, kit.hash_now(), s.party_menu.is_open(), s.state.party.at], ["", saves, h, false, C1],
			"%s: 닫기만(저장 없음, 캠프 안 열림, 상자 위)" % how)
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "chest", "준비: 조사로 다시 묻는다")
	var saves := s.autosave_count
	var mesh0 := _mesh_id(s)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s.modal.kind, "", "「예」로 닫힘")
	check(s.state.world.is_chest_opened("c1"), "c1 을 열었다")
	check_eq(int(s.state.materials.get(RAT, 0)), 3, "네온 쥐 꼬리 +3")
	check_eq(s._toast.text, "네온 쥐 꼬리 3개를 얻었다", "안내 줄(얻었다)")
	check_eq(s.autosave_count, saves + 1, "열기 자동 저장")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), "자동 저장 = 지금 상태")
	check(_mesh_id(s) != mesh0, "상자 겉모습(닫힘 → 열림)을 다시 만든다")
	snap = s.debug_snapshot()
	check_eq([snap["chests_opened"], snap["chest_here"], snap["toast"], snap["key_items"]], [1, "", "네온 쥐 꼬리 3개를 얻었다", []], "스냅숏 상자 수·발밑·알림")
	# 떠났다 돌아오면 묻지 않는다. 조사 = 빈 상자.
	await kit.press_key(KEY_Q)
	await kit.press_key(KEY_E)
	await kit.frames(3)
	check_eq([s.state.party.at, s.modal.kind], [C1, ""], "연 상자 칸에 다시 서도 묻지 않는다")
	await kit.press_key(KEY_SPACE)
	await kit.frames(1)
	check_eq([s.modal.kind, s._toast.text], ["", "빈 상자다"], "연 상자 조사 = 빈 상자")


## U2 (M-U2 물음 다시 보기가 상자를 무시): 연출 중에 미리 받은 행동, 누르고 있던 키, 다른 창(메모) 뒤, 불러오기.
func test_chest_question_races() -> void:
	var s := await _open()
	# (가) 연출 중 미리 받은 회전은 물음을 건너뛰지 못한다.
	await _beside_c1(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	check(s.view.is_busy() and s.state.party.at == C1, "준비: 상자로 걷는 연출 중")
	await kit.press_key(KEY_D)
	await _wait_idle(s)
	check_eq([s.modal.kind, s.state.party.at, s.state.party.facing], ["chest", C1, Dir.E], "(가) 연출이 끝나면 상자 물음, 미리 받은 회전은 버림")
	s.view.speed = 0.0
	await kit.press_key(KEY_ESCAPE)
	# (나) 조사(Space)를 누른 채 물음 → 반복·뗌으로 고르지 않는다.
	_key_event(KEY_SPACE, true)
	await kit.frames(3)
	check_eq(s.modal.kind, "chest", "(나) 조사로 물음")
	for i in 3:
		_key_event(KEY_SPACE, true, true)
		await kit.frames(1)
	_key_event(KEY_SPACE, false)
	await kit.frames(3)
	check(s.modal.kind == "chest" and not s.state.world.is_chest_opened("c1"), "(나) 반복·뗌으로 고르지 않음")
	await kit.press_key(KEY_ESCAPE)
	# (다) 연출 중에 메모 창이 열리면 물음은 남고, 메모 창을 닫으면 상자 물음.
	await _beside_c1(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	s._on_memo_requested(BESIDE)
	await _wait_idle(s)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "(다) 메모 창이 열린 동안 물음은 남는다")
	await kit.click(kit.center_of(s.modal.find_child("MemoCancel", true, false)))
	await kit.frames(3)
	check_eq([s.modal.kind, s.state.party.at], ["chest", C1], "(다) 메모 창을 닫으면 상자 물음")
	check_eq(_focus(s), s.modal.find_child("ChestYes", true, false), "(다) 「예」에 포커스")
	await kit.press_key(KEY_ESCAPE)
	# (라) 물음이 남은 채 가져오기(상태 바꾸기)를 하면 물음은 버린다.
	await _beside_c1(s)
	var away := SaveCodec.encode(s.state)
	await kit.press_key(KEY_W)
	s._on_memo_requested(BESIDE)
	await _wait_idle(s)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "(라) 준비: 메모 창 뒤에 물음")
	check(s.import_text(away), "(라) 가져오기")
	s.view.speed = 0.0
	await kit.frames(4)
	check_eq([s.modal.kind, s._stairs_ask, s.state.party.at], ["", false, BESIDE], "(라) 가져오면 물음을 버린다")


## U3 (M-U3 lock_opened 뒤 시야를 다시 만들지 않음): B2F 잠긴 문 — 열쇠 없이 부딪힘·열쇠로 뒷걸음 안내, 열면 안내·자동 저장·시야(잠긴 문 → 문),
## 그다음 지나간다. B3F 봉인 문은 「굳게 봉인된 문」.
func test_lock_toasts_and_rebuild() -> void:
	var s := await _open()
	var st := s.state
	var b2 := st.defs.floor_by_id("b2f")
	st.enter_floor(b2)
	st.party.at = Vector2i(16, 3)
	st.party.facing = Dir.S
	st.encounter.threshold = 99999
	s._set_state(st)
	await kit.frames(2)
	var e := FloorModel.edge_of(Vector2i(16, 3), Dir.S)
	check_eq([b2.edge_kind(e), DungeonMeshBuilder.edge_style(b2, st.world, e), s._floor_label.text],
		[FloorModel.Edge.LOCK, "locked", "네온 이끼숲 / B2F"], "준비: B2F 잠긴 문 앞")
	await kit.press_key(KEY_W)
	await kit.frames(1)
	check_eq([s._toast.text, s.debug_snapshot()["locks_open"], st.party.at], ["잠긴 문이다. 열쇠가 필요하다", 0, Vector2i(16, 3)], "열쇠 없이 부딪힘")
	st.key_items[MOSS] = true
	st.world.open_chest("c1")  # 열쇠와 그 상자는 맞물린다(저장 검사)
	_face(s, Dir.N)
	await kit.press_key(KEY_S)
	await kit.frames(1)
	check_eq([s._toast.text, s.state.world.is_lock_open(e)], ["열쇠가 맞는다. 문을 마주 보고 열자", false], "열쇠로 뒷걸음: 열지 않는다")
	_face(s, Dir.S)
	var saves := s.autosave_count
	var mesh0 := _mesh_id(s)
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check_eq(s._toast.text, "이끼 낀 출입 카드로 문을 열었다", "연 안내(조사 고르기)")
	check_eq([s.state.world.is_lock_open(e), s.state.party.at, s.autosave_count], [true, Vector2i(16, 3), saves + 1], "열림, 움직이지 않음, 자동 저장")
	check_eq([s.debug_snapshot()["locks_open"], s.debug_snapshot()["key_items"]], [1, [MOSS]], "스냅숏 문·귀중품")
	check(_mesh_id(s) != mesh0 and DungeonMeshBuilder.edge_style(b2, s.state.world, e) == "door", "시야를 다시 만든다(잠긴 문 → 문)")
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check_eq(s.state.party.at, Vector2i(16, 4), "열린 문을 지나간다")
	# B3F 봉인 문(v:9:2): 서쪽으로 부딪히면 봉인 안내.
	st = s.state
	st.enter_floor(st.defs.floor_by_id("b3f"))
	st.party.at = Vector2i(9, 2)
	st.party.facing = Dir.W
	s._set_state(st)
	await kit.frames(2)
	await kit.press_key(KEY_W)
	await kit.frames(1)
	check_eq([s._toast.text, s.state.party.at], ["굳게 봉인된 문이다. 지금은 열 수 없다", Vector2i(9, 2)], "봉인 문")


## 화면 상태의 방향만 바꾼다(실제 회전 키 대신: 회전도 자동 저장한다).
func _face(s: DungeonScreen, d: int) -> void:
	s.state.party.facing = d
	s.view.set_pose(s.state.party.at, d)


## U4 (M-U4a 상점 판매에 귀중품 줄, M-U4b 띠에 귀중품 수 없음): 소지품 — 장비 → 소재 → 귀중품 차례, 귀중품 줄은 열쇠 아이콘·「귀중품」,
## 설명 상자 = 이름·아이콘·설명 글·「귀중품 · 팔 수 없다」, 띠는 「소지품   n/60」(M3 A4b: 원작 띠, 귀중품은 칸을 세지 않는다). 상점 판매 목록(세 탭)에는 귀중품이 없다.
func test_key_rows_in_items_and_not_in_shop() -> void:
	var s := await _open()
	s.state.materials[RAT] = 2
	s.state.key_items[MOSS] = true
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(1)
	var pm := s.party_menu
	var it := pm.items_tab
	check_eq([pm.page, it.row_items], ["sub", [RAT, MOSS]], "소지품 줄: 소재 → 귀중품")
	var m: Dictionary = it.inv.data[1]
	check_eq([m["icon"], m["name"], m["right"]], ["kind_key", "이끼 낀 출입 카드", "귀중품"], "귀중품 줄: 열쇠 아이콘·이름·「귀중품」")
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check_eq(it.cursor_stop(), it.rows[1], "준비: 커서 = 귀중품 줄")
	check_eq([it.desc.title, it.desc.icon, it.desc.lines],
		["이끼 낀 출입 카드", "kind_key", ["B2F의 잠긴 문을 여는 카드. 이끼가 단자에 엉겨 붙었다", "귀중품 · 팔 수 없다"]], "설명 상자")
	check_eq(s.debug_snapshot()["party_menu"]["strip"], "소지품   2/60", "띠 글: 공용 가방 칸 수, 귀중품은 세지 않는다(M3 A4b·D31: 소재 2 만)")
	var pmsnap: Dictionary = s.debug_snapshot()["party_menu"]
	check_eq([pmsnap.get("tab"), pmsnap.get("item_rows"), pmsnap.get("item_desc")],
		["items", [RAT, MOSS], ["이끼 낀 출입 카드", "B2F의 잠긴 문을 여는 카드. 이끼가 단자에 엉겨 붙었다", "귀중품 · 팔 수 없다"]], "스냅숏 소지품 줄·설명")
	check(not it.can_confirm(), "귀중품 줄에서 「선택」은 흐림(가방 줄과 달리 알약이 없다, M3 A4b)")
	s.shop_screen.state = s.state
	for i in ShopScreen.SELL_KINDS.size():
		s.shop_screen.tab = i
		var items: Array = s.shop_screen.sell_lines().map(func(x: Dictionary) -> String: return x["item"])
		check(not items.has(MOSS), "상점 판매 %s 탭에 귀중품 없음 %s" % [ShopScreen.SELL_KINDS[i], str(items)])
	s.shop_screen.tab = 0
	check_eq(s.shop_screen.sell_lines().map(func(x: Dictionary) -> String: return x["item"]), [RAT], "상점 판매 소재 탭은 그대로")


## U5 (M-U5 알리지 않고 옮김): 시험 층 저장은 읽는 길마다 옮김 알림(msg.relocated, 「알림」 창)을 띄운다.
## 시작(자동 저장) → 마을, 알림을 닫으면 광장 · 다음 자동 저장이 8판(M3 A4), .bak = 6판 원본.
func test_relocation_alert_on_start_and_bak() -> void:
	timeout_sec = 60.0
	kit = Kit.new(tree)
	_write_slot("auto", V7.V6_TOWN)
	var s := await kit.open_arbor()
	check_eq([s.modal.kind, s.modal.title_plate.text], ["alert", "알림"], "시작: 옮김 알림")
	check(_labels(s).has(s.texts.t("msg.relocated")), "알림 글 %s" % str(_labels(s)))
	check_eq(s._toast.modulate.a, 0.0, "알림 줄이 「확인」을 가리지 않는다")
	check_eq([s.state.location, s.state.floor_def.id, s.state.money, s.state.day, s.autosave_count], ["town", "b1f", 480, 3, 0], "마을·돈·날 그대로, 아직 쓰지 않음")
	check_eq(_read_slot("auto"), V7.V6_TOWN, "본 파일은 아직 6판")
	await kit.click(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	await kit.frames(2)
	check_eq([s.modal.kind, s.town_screen.is_open(), s.town_screen.page], ["", true, "plaza"], "알림을 닫으면 광장")
	s._enter_labyrinth()
	await kit.frames(2)
	var doc: Dictionary = JSON.parse_string(_read_slot("auto"))
	check_eq([doc["schema"], doc["state"]["floor"], doc["state"]["location"]], [8.0, "b1f", "labyrinth"], "다음 자동 저장은 8판")
	check_eq(_read_slot("auto", "bak"), V7.V6_TOWN, ".bak = 6판 원본")


## U5: 타이틀 「이어하기」(저장하지 않는다) — 전투 대기 저장은 전투 없이 마을, 알림. 다시 열면 다시 옮기고 알린다.
func test_relocation_alert_on_continue() -> void:
	timeout_sec = 60.0
	kit = Kit.new(tree)
	_write_slot("auto", V7.V6_BATTLE)
	var s := await kit.open_arbor("native", 7, "", func(x: DungeonScreen) -> void: x.start_mode = "title")
	check(s.title_screen.is_open() and s.state == null, "준비: 타이틀")
	s._continue_game()
	await kit.frames(2)
	check_eq([s.modal.kind, s.state.location, s.state.encounter.pending, s.battle_layer.is_open(), s.autosave_count], ["alert", "town", false, false, 0],
		"이어하기: 알림, 마을, 전투 버림, 쓰지 않음")
	check(_labels(s).has(s.texts.t("msg.relocated")), "알림 글")
	s = await kit.reopen(_arbor("title"))
	s._continue_game()
	await kit.frames(2)
	check_eq(s.modal.kind, "alert", "다시 열어 이어하면 다시 알린다(저장하지 않았다)")


## U5: 수동 슬롯 불러오기·가져오기·전멸 뒤 기록으로 돌아가기는 안내 줄과 옮김 알림, 자동 저장 8판.
## 전멸한 저장은 B1F 시작 칸에서 전멸 그대로: 알림을 닫으면 전멸 창. 옮기지 않은 저장은 알림이 없다.
## 자동 저장에 실패하면 실패와 옮김을 한 알림에 함께 적는다.
func test_relocation_alert_on_load_import_and_wipe() -> void:
	var s := await _open()
	_write_slot("slot1", V7.V6_TOWN)
	var saves := s.autosave_count
	s._load_slot("slot1")
	await kit.frames(2)
	check_eq([s.modal.kind, s._toast.modulate.a, s.state.location, s.autosave_count], ["alert", 0.0, "town", saves + 1],
		"불러오기: 알림(알림 줄은 「확인」을 가리지 않게 쓰지 않는다)·자동 저장")
	check(_labels(s).has("불러왔다\n" + s.texts.t("msg.relocated")), "불러오기 알림 글 = 안내 + 옮김 %s" % str(_labels(s)))
	check_eq(JSON.parse_string(_read_slot("auto"))["schema"], 8.0, "자동 저장 8판")
	await kit.click(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	await kit.frames(1)
	# 가져오기(전멸한 6판): 알림 → 닫으면 전멸 창.
	check(s.import_text(V7.V6_WIPED), "가져오기")
	await kit.frames(2)
	check_eq([s.modal.kind, s._toast.modulate.a, s.state.wiped, s.state.party.at, s.state.location], ["alert", 0.0, true, Vector2i(9, 18), "labyrinth"],
		"가져오기: 알림, B1F 시작 칸에서 전멸 그대로")
	check(_labels(s).has("가져왔다\n" + s.texts.t("msg.relocated")), "가져오기 알림 글 = 안내 + 옮김")
	await kit.click(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe", "알림을 닫으면 전멸 창")
	# 전멸 창 「마지막 기록으로 돌아간다」(slot1 = 옮길 저장) → 지도 물음 「아니오」 → 알림.
	var load_b := s.modal.find_child("WipeLoad", true, false)
	check(load_b != null, "옮길 수동 저장도 돌아갈 기록으로 보인다")
	await kit.click(kit.center_of(load_b))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "지도 물음")
	await kit.click(kit.center_of(s.modal.find_child("WipeMapNo", true, false)))
	await kit.frames(2)
	check_eq([s.modal.kind, s._toast.modulate.a, s.state.wiped, s.state.location], ["alert", 0.0, false, "town"], "전멸 뒤 기록: 알림, 마을")
	check(_labels(s).has("불러왔다\n" + s.texts.t("msg.relocated")), "전멸 뒤 알림 글 = 안내 + 옮김")
	await kit.click(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	await kit.frames(1)
	# 옮기지 않은 저장(지금 8판)은 알림이 없다.
	check(s.import_text(SaveCodec.encode(s.state)), "8판 가져오기")
	await kit.frames(2)
	check_eq([s.modal.kind, s.town_screen.notice, s._toast.modulate.a], ["", "가져왔다", 0.0], "옮기지 않은 저장은 알림 없이 안내(광장이 열려 있어 광장 안내 줄)")
	# 자동 저장 실패: 한 알림에 실패와 옮김(남은 안내 줄 「가져왔다」는 지운다).
	s.store.stop_after_step = 1
	s._load_slot("slot1")
	await kit.frames(2)
	var want := s.texts.t("msg.loaded_save_failed", {"reason": "시험 중단: 1단계 뒤"}) + "\n" + s.texts.t("msg.relocated")
	check_eq(s.modal.kind, "alert", "실패: 알림")
	check(_labels(s).has(want), "실패와 옮김을 한 알림에 %s" % str(_labels(s)))
	check_eq(s._toast.modulate.a, 0.0, "실패 알림도 알림 줄에 가리지 않는다")
	s.store.stop_after_step = 0


## 옮길 수동 저장의 슬롯 카드는 깨진 것으로 보이지 않는다: 마을 저장은 광장, 전멸 저장은 B1F, 걸음 그대로.
func test_relocated_slot_cards_are_not_broken() -> void:
	var s := await _open()
	_write_slot("slot1", V7.V6_TOWN)
	_write_slot("slot2", V7.V6_WIPED)
	var cards := s.record_slots()
	check_eq([cards[0]["ok"], cards[0].get("where")], [true, "뿌리마을 광장 · 걸음 7"], "slot1: 광장")
	check_eq([cards[1]["ok"], cards[1].get("where")], [true, "네온 이끼숲 / B1F · 걸음 40"], "slot2: B1F")
	check_eq(cards[2]["ok"], false, "slot3: 없음")
	check_eq(s.store.latest_manual().is_empty(), false, "전멸 창이 고를 수동 저장이 있다")
	check_eq([_read_slot("slot1"), _read_slot("slot2")], [V7.V6_TOWN, V7.V6_WIPED], "카드를 보여도 파일은 그대로")


## U6 (A2 터치 확인): 상자 물음이 떠 있으면 HUD 단추(층 1)는 어둠 막(층 3)이 먹고, 물음 단추는 터치로 고른다.
func test_chest_modal_by_touch() -> void:
	var s := await _open()
	await _beside_c1(s)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq(s.modal.kind, "chest", "준비: 상자 물음")
	var h := kit.hash_now()
	for b in [s.pad[DungeonScreen.A.FORWARD], s.pad[DungeonScreen.A.INVESTIGATE], s.camp_button]:
		await kit.tap(kit.center_of(b))
		await kit.frames(2)
		check_eq([s.modal.kind, kit.hash_now(), s.party_menu.is_open()], ["chest", h, false], "물음 아래 %s 누르기는 먹힌다" % (b as Control).name)
	await kit.tap(kit.center_of(s.modal.find_child("ChestNo", true, false)))
	await kit.frames(2)
	check_eq([s.modal.kind, kit.hash_now()], ["", h], "「아니오」 터치")
	await kit.tap(kit.center_of(s.pad[DungeonScreen.A.INVESTIGATE]))
	await kit.frames(3)
	check_eq(s.modal.kind, "chest", "「조사」 단추 터치로 다시 묻는다")
	await kit.tap(kit.center_of(s.modal.find_child("ChestYes", true, false)))
	await kit.frames(3)
	check(s.modal.kind == "" and s.state.world.is_chest_opened("c1"), "「예」 터치로 연다")


## 층 표(§6, 알림 행 = 기존 _alert): 옮김 알림(실패와 함께 적은 것 포함)·상자 물음이 1280×720·1280×960 에서 화면 안,
## 글은 창 안에서 감기고 「확인」은 64 이상. 상자 안내 글은 알림 줄 폭 안(실제 글꼴, 가장 긴 이름·개수).
func test_alert_and_question_fit() -> void:
	var s := await _open()
	var texts := [s.texts.t("msg.relocated"), s.texts.t("msg.imported") + "\n" + s.texts.t("msg.relocated"),
		s.texts.t("msg.loaded_save_failed", {"reason": "임시 파일 이름을 바꿀 수 없다 (시험 실패)"}) + "\n" + s.texts.t("msg.relocated")]
	for px in [Vector2(1280, 720), Vector2(1280, 960)]:
		if _root_size == Vector2i.ZERO:
			_root_size = tree.root.size
		tree.root.size = Vector2i(px)
		await kit.frames(3)
		var screen := Rect2(Vector2.ZERO, s.get_viewport_rect().size)
		for t in texts:
			s._alert(t)
			await kit.frames(3)
			var panel := s.modal._panel.get_global_rect()
			var label: Label = s.modal.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == t)[0]
			var ok_b := s.modal.find_child("AlertOk", true, false) as Control
			check(screen.encloses(panel) and panel.encloses(label.get_global_rect()) and panel.encloses(ok_b.get_global_rect()),
				"%s: 알림 창·글·확인이 화면 안 %s" % [px, str(panel)])
			check(label.get_line_count() >= 2 and label.get_visible_line_count() == label.get_line_count(), "%s: 글이 감기고 잘리지 않는다" % px)
			check(ok_b.size.y >= 64.0, "%s: 확인 64 이상" % px)
			s._close_alert()
			await kit.frames(1)
	tree.root.size = _root_size
	await kit.frames(3)
	var font := s._toast.get_theme_default_font()
	var fs := s._toast.get_theme_font_size("font_size")
	var room := s.get_viewport_rect().size.x - 2.0 * DungeonScreen.EDGE
	var longest := ""
	for id in s.state.defs.battle.material_ids + s.state.defs.battle.equipment_ids:
		var cand := s.texts.t("msg.chest_full", {"item": PartyNames.item_name(s.state, s.texts, id)})
		if cand.length() > longest.length():
			longest = cand
	for t in [longest, s.texts.t("msg.chest_item", {"item": "네온 쥐 꼬리", "count": 99}), s.texts.t("msg.chest_money", {"money": "99,999"}),
			s.texts.t("msg.lock_opened", {"key": "이끼 낀 출입 카드"}), s.texts.t("msg.sealed"), s.texts.t("msg.lock_closed"), s.texts.t("msg.chest_full_money")]:
		check(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room, "알림 줄 폭 안: %s" % t)


## (M-W1 debug 없이도 set=test 를 받음, M-W2 시험이 바꾼 폴더를 덮음) 디버그 주소의 &set=test 만 시험 층 묶음·시험 저장 폴더로 바꾼다.
## 트리에 넣지 않은 화면에서 주소 인자만 본다(파일을 건드리지 않는다). 띄우면 시험 층 f1_test 에서 시작한다.
func test_set_query_switches_set_and_folder() -> void:
	timeout_sec = 60.0
	for c in [["debug=1&set=test", true], ["set=test", false], ["debug=1", false], ["debug=1&set=game", false], ["debug=0&set=test", false]]:
		var sc: DungeonScreen = Kit.SCREEN.instantiate()
		sc.bridge = WebBridge.new("native", c[0])
		sc._apply_set_query()
		var want := [DungeonScreen.TEST_LABYRINTH_PATH, DungeonScreen.TEST_SAVE_DIR] if c[1] else [DungeonScreen.LABYRINTH_PATH, DungeonScreen.SAVE_DIR]
		check_eq([sc.labyrinth_path, sc.save_dir], want, "%s → %s" % [c[0], "시험 묶음" if c[1] else "실제 미궁"])
		if c[1]:
			sc.labyrinth_path = "res://x.json"
			sc.save_dir = "user://test_x"
			sc._apply_set_query()
			check_eq([sc.labyrinth_path, sc.save_dir], ["res://x.json", "user://test_x"], "시험이 바꾼 경로·폴더는 그대로")
		for n in [sc._floor_label, sc._steps_label, sc._toast, sc._warn_label, sc._flash, sc.save_chip]:
			(n as Node).free()
		sc.free()
	check_eq([DungeonScreen.LABYRINTH_PATH, DungeonScreen.TEST_LABYRINTH_PATH, DungeonScreen.SAVE_DIR, DungeonScreen.TEST_SAVE_DIR],
		["res://data/floors/arbor.json", "res://data/floors/labyrinth.json", "user://saves", "user://saves_test"], "게임 = 실제 미궁, 저장 폴더 둘")
	var s := await _open("debug=1&set=test")
	check_eq([s.state.floor_def.id, s.debug_snapshot()["set"], s.save_dir], ["f1_test", "test", kit.dir + "/saves"], "&set=test 로 띄우면 시험 층(시험 폴더는 그대로)")


# ---- 알림 줄과 창(검토 뒤 고침): 알림 줄(층 4)은 열린 창(층 3)의 판을 가리지 않는다 ----

const SIZES := [Vector2i(1280, 720), Vector2i(1728, 720), Vector2i(1280, 960)]


## 보이는 알림 줄 글의 화면 사각형(가운데 정렬 글 폭·글꼴 높이). 안 보이면 빈 사각형.
func _toast_text_rect(s: DungeonScreen) -> Rect2:
	return _text_rect(s._toast)


## 보이는 글줄(알림 줄·저장 실패 안내 글줄) 글의 화면 사각형. 안 보이면 빈 사각형.
func _text_rect(t: Label) -> Rect2:
	if t.modulate.a <= 0.0 or t.text.is_empty() or not t.is_visible_in_tree():
		return Rect2()
	var r := t.get_global_rect()
	var font := t.get_theme_default_font()
	var fs := t.get_theme_font_size("font_size")
	var w := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var h := font.get_height(fs)
	return Rect2(r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y - h) / 2.0, w, h)


## 창 판(제목 문패 포함)의 화면 사각형.
func _modal_rect(s: DungeonScreen) -> Rect2:
	return s.modal._panel.get_global_rect().merge(s.modal.title_plate.get_global_rect())


func _sized_open(px: Vector2i) -> DungeonScreen:
	if kit != null:
		kit.dispose()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = px
	var s := await _open()
	s.state.encounter.threshold = 99999
	await kit.frames(3)
	return s


## (M-T1 창이 열릴 때 알림 줄을 지우지 않음) 실제 상자 열기 안내 → 네이티브 메모 창, 잠긴 문 연 안내 → 잘못된 가져오기 알림:
## 세 크기에서 창이 뜨면 일반 안내는 지워지고(보이지 않음), 창을 닫아도 되살아나지 않는다. 창 판·단추와 겹치는 알림 글이 없다.
func test_toast_never_covers_a_modal() -> void:
	for px in SIZES:
		var s := await _sized_open(px)
		var tag := "%dx%d" % [px.x, px.y]
		for k in [KEY_W, KEY_W, KEY_E]:
			await kit.press_key(k)
		await _wait_idle(s)
		check_eq(s.modal.kind, "chest", tag + " 준비: 상자 물음")
		await kit.click(kit.center_of(s.modal.find_child("ChestYes", true, false)))
		await kit.frames(2)
		check(s._toast.text == "네온 쥐 꼬리 3개를 얻었다" and s._toast.modulate.a > 0.9, tag + " 준비: 실제 열기 안내가 보인다")
		var before := _toast_text_rect(s)
		s._on_memo_requested(BESIDE)
		await kit.frames(3)
		var ok_b := s.modal.find_child("MemoOk", true, false) as Control
		var cancel_b := s.modal.find_child("MemoCancel", true, false) as Control
		check_eq([s.modal.kind, s._toast.modulate.a, s.debug_snapshot()["toast"]], ["memo", 0.0, ""], tag + " 메모 창: 상자 안내를 지운다")
		check(not _toast_text_rect(s).intersects(_modal_rect(s)), tag + " 메모 판과 겹치는 알림 글 없음")
		if px.y == 720:
			check(before.intersects(ok_b.get_global_rect()) or before.intersects(cancel_b.get_global_rect()),
				tag + " (전제) 고치기 전 자리라면 메모 단추와 겹친다 %s / %s" % [str(before), str(ok_b.get_global_rect())])
		await kit.click(kit.center_of(cancel_b))
		await kit.frames(3)
		check_eq([s.modal.kind, s._toast.modulate.a], ["", 0.0], tag + " 창을 닫아도 일반 안내는 되살아나지 않는다")
		# 잠긴 문 연 안내 → 잘못된 가져오기 알림.
		var st := s.state
		st.enter_floor(st.defs.floor_by_id("b2f"))
		st.party.at = Vector2i(16, 3)
		st.party.facing = Dir.S
		st.key_items[MOSS] = true
		st.world.open_chest("c1")
		s._set_state(st)
		await kit.frames(2)
		await kit.press_key(KEY_W)
		await kit.frames(2)
		check(s._toast.text == "이끼 낀 출입 카드로 문을 열었다" and s._toast.modulate.a > 0.9, tag + " 준비: 문 연 안내가 보인다")
		before = _toast_text_rect(s)
		check(not s.import_text("bad"), tag + " 잘못된 글 가져오기")
		await kit.frames(3)
		var alert_ok := s.modal.find_child("AlertOk", true, false) as Control
		check_eq([s.modal.kind, s._toast.modulate.a], ["alert", 0.0], tag + " 가져오기 실패 알림: 문 연 안내를 지운다")
		check(not _toast_text_rect(s).intersects(_modal_rect(s)), tag + " 알림 판과 겹치는 알림 글 없음")
		if px.y == 720:
			check(before.intersects(alert_ok.get_global_rect()), tag + " (전제) 고치기 전 자리라면 「확인」과 겹친다")
		s.modal.close()
		await kit.frames(1)


## (M-T2 창이 열리면 저장 실패 안내도 지움, M-T3 창 둘레로 옮기지 않음) 저장 실패 안내(05 §8.4)는 어떤 창이 열려도 잃지 않고 겹치지 않는다:
## 창 종류마다(알림·메모·계단·마을 문·상자·전멸·지도 물음·파일 고르기) 세 크기에서 판 위(또는 아래) 빈 띠에 보이거나, 자리가 없으면
## 미뤄 두었다가 창을 닫으면 새 시간으로 다시 보인다. 판·제목 문패와 겹치지 않는다.
func test_save_failure_toast_with_each_modal_kind() -> void:
	for px in SIZES:
		var s := await _sized_open(px)
		var openers := {
			"alert": func() -> void: s._alert(s.texts.t("msg.relocated")),
			"memo": func() -> void: s._on_memo_requested(BESIDE),
			"stairs": func() -> void:
				s.state.party.at = Vector2i(17, 1)
				s._open_stairs(),
			"gate": func() -> void:
				s.state.party.at = s.state.floor_def.start_at
				s._open_stairs(),
			"chest": func() -> void:
				s.state.party.at = C1
				s._open_stairs(),
			"wipe": func() -> void: s._open_wipe(),
			"wipe_map": func() -> void: s._ask_wipe_map(s.state, false),
			"file": func() -> void: s.modal.open("file", s.texts.t("menu.choosing_file"), [] as Array[Control]),
		}
		for name in openers:
			var tag := "%dx%d %s" % [px.x, px.y, name]
			s.state.party.at = BESIDE
			s.store.fail_points = ["write"]
			s._autosave()
			s.store.fail_points = []
			var want := s.texts.t("msg.save_failed", {"reason": s.last_autosave_error})
			check(s._warn_label.text == want and s._warn_label.modulate.a > 0.9, tag + " 준비: 저장 실패 안내(자기 글줄)")
			(openers[name] as Callable).call()
			await kit.frames(3)
			var kind: String = "stairs" if name == "gate" else name
			check_eq(s.modal.kind, kind, tag + " 창")
			var shown := s.warning_shown() == want
			check(shown or (s._warn_text == want and s._warn_at == null), tag + " 실패 안내가 보이거나 들고 있다")
			var wr := _text_rect(s._warn_label)
			check(not wr.intersects(_modal_rect(s)), tag + " 판과 겹치지 않는다 %s / %s" % [str(wr), str(_modal_rect(s))])
			check(not wr.intersects(s.save_chip.get_global_rect()), tag + " 저장 칩과 겹치지 않는다")
			s.modal.close()
			await kit.frames(2)
			check_eq(s.warning_shown(), want, tag + " 창을 닫은 뒤에도 실패 안내가 보인다")
			s._warn_end()


## (M-T4 화면 창 위에 알림 줄을 그림) 화면 창(층 2)이 열려 있으면 알림 줄은 그리지 않는다: 그 창이 열린 동안 나온 안내(기록 「저장했다」,
## 상점 저장 실패)는 그 창의 안내 줄로, 창이 열리기 전부터 보이던 일반 안내(상자 결과)는 지우고, 저장 실패 안내는 그 창 안내 줄로 옮긴다.
func test_toasts_over_windows_go_to_the_window_notice() -> void:
	var s := await _sized_open(Vector2i(1280, 720))
	var pm := s.party_menu
	s._show_toast("네온 쥐 꼬리 3개를 얻었다")
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq([pm.is_open(), s._toast.modulate.a, pm.notice], [true, 0.0, ""], "캠프가 열리면 보이던 상자 안내는 지운다")
	await kit.press_key(KEY_5)
	await kit.frames(2)
	s._save_slot("slot1")
	await kit.frames(2)
	check_eq([pm.tab, s._toast.text, s._toast.modulate.a, pm.notice], [4, "저장했다", 0.0, "저장했다"], "기록 「저장했다」는 캠프 안내 줄로")
	pm.close_menu()
	await kit.frames(1)
	s.store.fail_points = ["write"]
	s._autosave()
	s.store.fail_points = []
	var want := s.texts.t("msg.save_failed", {"reason": s.last_autosave_error})
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq([s._toast.modulate.a, pm.notice], [0.0, want], "저장 실패 안내는 캠프가 열려도 캠프 안내 줄에 남는다")
	pm.close_menu()
	await kit.frames(1)
	# 마을(새 게임, 광장): 광장 위 안내, 상점 안의 저장 실패.
	kit.dispose()
	kit = Kit.new(tree)
	s = await kit.open_town()
	await kit.frames(2)
	check(s.town_screen.is_open() and s.town_screen.page == "plaza", "준비: 광장")
	s._show_toast("시험 안내")
	await kit.frames(2)
	check_eq([s._toast.modulate.a, s.town_screen.notice], [0.0, "시험 안내"], "광장이 열린 동안 나온 안내는 광장 안내 줄로")
	s._open_shop()
	await kit.frames(2)
	s.store.fail_points = ["write"]
	s._autosave()
	s.store.fail_points = []
	await kit.frames(2)
	check_eq([s.shop_screen.is_open(), s._toast.modulate.a, s.shop_screen.notice],
		[true, 0.0, s.texts.t("msg.save_failed", {"reason": s.last_autosave_error})], "상점 안 저장 실패는 상점 안내 줄로")


## 낮은 지적(검토): 실제 열기(OPEN)의 화면 안내 — 소재 ×n, 장비 ×1, 돈, 소재 가득, 돈 가득. 상자 수·자동 저장도 본다.
func test_chest_result_toasts_on_real_open() -> void:
	var s := await _open()
	var st := s.state
	st.encounter.threshold = 99999
	# [상자, 칸, 준비, 안내, 연 뒤 열림, 자동 저장 +1]
	var cases := [
		["c4", Vector2i(17, 4), func() -> void: pass, "발광 인분 2개를 얻었다", true, true],
		["c2", Vector2i(1, 2), func() -> void: pass, "마그 부츠를 얻었다", true, true],
		["c3", Vector2i(18, 9), func() -> void: pass, "100엔을 얻었다", true, true],
		["c1", C1, func() -> void: st.materials[RAT] = 9999, "네온 쥐 꼬리를 더 가질 수 없다. 상자는 그대로 두었다", false, false],
		["c3", Vector2i(18, 9), func() -> void: pass, "여기에는 상자가 없다", true, false],  # 연 상자에 OPEN = not_chest(「빈 상자다」는 조사)
	]
	for c in cases:
		st.party.at = c[1]
		(c[2] as Callable).call()
		var saves := s.autosave_count
		var money := st.money
		s.request_action(DungeonScreen.A.OPEN)
		await kit.frames(2)
		check_eq([s._toast.text, st.world.is_chest_opened(c[0])], [c[3], c[4]], "%s %s: 실제 열기 안내·열림" % [c[0], c[3]])
		if c[5]:
			check_eq(s.autosave_count, saves + 1, "%s 열기는 자동 저장" % c[0])
		if c[3] == "100엔을 얻었다":
			check_eq(st.money, money + 100, "c3 돈 +100")
	check_eq([int(st.materials.get("item.glow_scale", 0)), int(st.gear_bag.get("equip.mag_boots", 0)), int(st.materials[RAT])], [2, 1, 9999],
		"소재 +2·장비 +1, 가득한 소재는 그대로")
	# 돈 가득: 새 게임에서 c3 을 소지금 최대로.
	kit.dispose()
	s = await _open()
	st = s.state
	st.encounter.threshold = 99999
	st.money = BattleLimits.MONEY_MAX
	st.party.at = Vector2i(18, 9)
	s.request_action(DungeonScreen.A.OPEN)
	await kit.frames(2)
	check_eq([s._toast.text, st.world.is_chest_opened("c3"), st.money], ["돈을 더 가질 수 없다. 상자는 그대로 두었다", false, BattleLimits.MONEY_MAX],
		"c3 돈 가득: 안내, 상자는 닫힌 채, 돈 그대로")


# ---- 저장 실패 안내 기록(검토 R1): 이 화면이 가지고, 보이는 곳으로 넘기며, 보이는 동안만 시간이 준다 ----

## 지금 보이는 안내들(알림 줄, 저장 실패 안내 글줄, 보이는 화면 창의 안내 줄).
func _visible_notices(s: DungeonScreen) -> Array:
	var a := []
	for l in [s._toast, s._warn_label]:
		if l.modulate.a > 0.0 and not l.text.is_empty() and l.is_visible_in_tree():
			a.append(l.text)
	for w in [s.town_screen, s.party_menu, s.shop_screen]:
		if w.is_visible_in_tree() and not w.notice.is_empty():
			a.append(w.notice)
	return a


## 저장을 한 번 실패시키며 f 를 부른다. 실패 안내 글을 돌려준다.
func _fail_save(s: DungeonScreen, f: Callable) -> String:
	s.store.fail_points = ["write"]
	f.call()
	s.store.fail_points = []
	return s.texts.t("msg.save_failed", {"reason": s.last_autosave_error})


func _town_open() -> DungeonScreen:
	if kit != null:
		kit.dispose()
	timeout_sec = 60.0
	kit = Kit.new(tree)
	var s := await kit.open_town()
	await kit.frames(2)
	return s


func _wait(sec: float) -> void:
	await tree.create_timer(sec).timeout
	await kit.frames(1)


## (M-W3 닫히거나 가려진 곳에서 넘기지 않음) 저장 실패 안내는 보이던 곳이 닫히거나 가려지면 다음 보이는 곳으로 넘어간다.
## 검토의 세 경우(숙소 실패 → 캠프, 캠프 실패 → 닫기, 상점 실패 → 닫기)와 미궁 캠프 닫기, 마을 → 미궁.
func test_save_warning_follows_the_screens() -> void:
	# 1) 숙소 「묵는다」 저장 실패 → 캠프: 캠프 안내 줄에서 다 보인 뒤 끝난다(가려진 마을에서 몰래 끝나지 않는다).
	var s := await _town_open()
	s.town_screen.handle("row", 0)
	await kit.frames(3)
	var want := _fail_save(s, func() -> void: s.town_screen._on_stay_answered(true, 1))
	await kit.frames(3)
	check_eq([s.town_screen.page, _visible_notices(s)], ["inn", [want]], "숙소 실패: 숙소 안내 줄(묵었다는 안내보다 앞)")
	s.town_screen.handle("camp")
	await kit.frames(3)
	check_eq([s.party_menu.is_open(), s.party_menu.notice, _visible_notices(s)], [true, want, [want]], "숙소 → 캠프: 캠프 안내 줄로 넘긴다")
	var left0 := s._warn_left
	check(left0 > 1.5, "넘길 때 남은 시간 %.2f" % left0)
	await _wait(1.0)
	check(_visible_notices(s) == [want] and s._warn_left < left0 - 0.5, "캠프에서 보이는 동안 시간이 준다 %.2f" % s._warn_left)
	await _wait(1.6)
	check_eq([s._warn_left, _visible_notices(s)], [0.0, []], "다 보인 뒤 끝난다(캠프에서)")
	s.party_menu.close_menu()
	await kit.frames(2)
	check_eq([s.town_screen.notice, _visible_notices(s)], ["", []], "끝난 안내는 숙소에 되살아나지 않는다")
	# 2) 마을 캠프 저장 실패 → 닫기: 마을 안내 줄로.
	s = await _town_open()
	s._open_party()
	await kit.frames(3)
	want = _fail_save(s, s._on_party_save)
	await kit.frames(3)
	check_eq([s.party_menu.notice, _visible_notices(s)], [want, [want]], "캠프 실패: 캠프 안내 줄")
	s.party_menu.close_menu()
	await kit.frames(3)
	check_eq([s.town_screen.notice, _visible_notices(s)], [want, [want]], "캠프 닫기 → 광장 안내 줄로 넘긴다")
	check(s._warn_left > 1.0, "닫아도 남은 시간 %.2f" % s._warn_left)
	# 3) 상점 저장 실패 → 닫기: 마을 안내 줄로.
	s = await _town_open()
	s._open_shop()
	await kit.frames(3)
	want = _fail_save(s, s._on_shop_save)
	await kit.frames(3)
	check_eq([s.shop_screen.notice, _visible_notices(s)], [want, [want]], "상점 실패: 상점 안내 줄")
	s.shop_screen.close_shop()
	await kit.frames(3)
	check_eq([s.town_screen.notice, _visible_notices(s)], [want, [want]], "상점 닫기 → 광장 안내 줄로 넘긴다")
	check(s._warn_left > 1.0, "닫아도 남은 시간 %.2f" % s._warn_left)
	# 4) 미궁 캠프 저장 실패 → 닫기: 알림 줄로.
	s = await _open()
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_P)
	await kit.frames(2)
	want = _fail_save(s, s._on_party_save)
	await kit.frames(3)
	check_eq(_visible_notices(s), [want], "미궁 캠프 실패: 캠프 안내 줄")
	s.party_menu.close_menu()
	await kit.frames(3)
	check_eq([s.warning_shown(), _visible_notices(s)], [want, [want]], "캠프 닫기 → 탐색 띠(실패 안내 글줄)로 넘긴다")
	# 5) 마을 → 미궁(들어가기 저장도 실패): 마을 안내 줄 → 탐색 띠. 장소 안내(일반 알림 줄)도 바로 보인다.
	s = await _town_open()
	want = _fail_save(s, s._autosave)
	await kit.frames(2)
	check_eq(_visible_notices(s), [want], "광장 실패: 광장 안내 줄")
	s.store.fail_points = ["write"]
	s._enter_labyrinth()
	s.store.fail_points = []
	await kit.frames(3)
	var place := FloorNames.place(s.texts, s.state.defs, s.state.floor_def)
	check_eq([s.state.location, s.town_screen.is_open(), _visible_notices(s)], ["labyrinth", false, [place, want]],
		"미궁으로 → 알림 줄에 장소 안내, 그 위 띠에 실패 안내(둘 다 보인다)")
	check(not _text_rect(s._toast).intersects(_text_rect(s._warn_label)), "두 글줄은 겹치지 않는다")
	await _wait(2.3)
	check_eq(_visible_notices(s), [], "둘 다 제 시간에 끝난다")


## (M-W4 가려진 동안에도 시간이 줆) 실패 안내의 시간은 놓인 동안만 준다: 판 위·아래에 자리가 없는 창이 열린 동안 들고만 있고
## 멈추며, 닫으면 남은 시간으로 다시 보인다. 실패 안내가 있는 동안 온 일반 안내는 곧바로 보인다. 자동 저장이 성공하면 거둔다.
func test_save_warning_time_counts_only_while_shown() -> void:
	var s := await _open()
	s.state.encounter.threshold = 99999
	var want := _fail_save(s, s._autosave)
	await kit.frames(3)
	check_eq(_visible_notices(s), [want], "준비: 알림 줄에 실패 안내")
	# 판 위·아래에 알림 줄 자리가 없는 창: 지금 게임의 창들은 세 크기 모두 판 위에 자리가 있어(조사 a3b_probe_modal.gd) 실제 흐름으로는
	# 생기지 않는다. 그래서 연 알림 창의 판 사각형을 화면 높이 거의 전부로 바꿔(가운데 정렬 컨테이너는 크기 변화만으로 다시 놓지 않는다) 그 경우를 만든다.
	s._alert("시험 알림")
	await kit.frames(3)
	s.modal._panel.position.y = 40.0
	s.modal._panel.size.y = s.get_viewport_rect().size.y - 70.0
	await kit.frames(3)
	var r := _modal_rect(s)
	var h := s.get_viewport_rect().size.y
	check(r.position.y - DungeonScreen.TOAST_GAP - DungeonScreen.TOAST_H < DungeonScreen.SAVE_CHIP_TOP + DungeonScreen.SAVE_CHIP_H + DungeonScreen.TOAST_GAP
		and r.end.y + DungeonScreen.TOAST_GAP + DungeonScreen.TOAST_H > h - DungeonScreen.EDGE, "(전제) 판 위·아래에 자리가 없다 %s" % str(r))
	check_eq([_visible_notices(s), s._warn_text, s._warn_at], [[], want, null], "가려진 동안 보이지 않고 기록은 남는다(들고 있음)")
	var l1 := s._warn_left
	await _wait(1.0)
	check(absf(s._warn_left - l1) < 0.001, "가려진 동안 시간이 멈춘다 %.3f → %.3f" % [l1, s._warn_left])
	s.modal.close()
	await kit.frames(3)
	check_eq(_visible_notices(s), [want], "창을 닫으면 다시 보인다")
	await _wait(0.5)
	check(s._warn_left < l1 - 0.3 and s._warn_left > 0.0, "보이는 동안 다시 준다 %.2f" % s._warn_left)
	# 일반 안내는 기다리지 않는다(자기 글줄).
	s._show_toast("시험 안내")
	await kit.frames(1)
	check_eq(_visible_notices(s), ["시험 안내", want], "실패 안내가 있는 동안 온 일반 안내도 곧바로 보인다")
	await _wait(2.2)
	check_eq([s._warn_left, _visible_notices(s)], [0.0, []], "둘 다 제 시간에 끝난다")
	# 자동 저장이 성공하면 거둔다(다시 저장했으니 맞지 않는 안내).
	want = _fail_save(s, s._autosave)
	await kit.frames(2)
	check_eq(_visible_notices(s), [want], "준비: 다시 실패")
	check(s._autosave(), "자동 저장 성공")
	await kit.frames(2)
	check_eq([s._warn_left, _visible_notices(s)], [0.0, []], "자동 저장이 성공하면 실패 안내를 거둔다")


# ---- 저장 실패 안내 글줄과 일반 알림 줄(검토 R2~R4): 두 글줄은 따로, 실패 안내는 자기 시간 하나 ----

## (자리) 탐색 중 실패 안내 띠는 일반 알림 줄·HUD(층 이름 문패·작은 지도·위험 구슬)·이동 단추와 겹치지 않는다(세 크기, 긴 실패 글).
func test_warning_band_is_clear_of_the_hud() -> void:
	for px in SIZES:
		var s := await _sized_open(px)
		var tag := "%dx%d" % [px.x, px.y]
		var want := _fail_save(s, s._autosave)
		s._show_toast("네온 쥐 꼬리 3개를 얻었다")
		await kit.frames(3)
		check_eq(_visible_notices(s), ["네온 쥐 꼬리 3개를 얻었다", want], tag + " 준비: 두 글줄이 보인다")
		var wr := _text_rect(s._warn_label)
		var wl := s._warn_label.get_global_rect()
		check(not wl.intersects(s._toast.get_global_rect()), tag + " 실패 안내 띠와 알림 줄 띠가 겹치지 않는다 %s / %s" % [str(wl), str(s._toast.get_global_rect())])
		var hud: Array = [s.floor_plate, s.minimap, s.orb] + s.pad.values()
		for c in hud:
			var cc := c as Control
			if cc.is_visible_in_tree():
				check(not wr.intersects(cc.get_global_rect()), tag + " 실패 안내 글이 %s 와 겹치지 않는다 %s / %s" % [cc.name, str(wr), str(cc.get_global_rect())])
		check(Rect2(Vector2.ZERO, s.get_viewport_rect().size).encloses(wr), tag + " 화면 안")


## R2 (M-R2 실패 안내가 일반 알림 줄을 나눠 쓰며 줄 세움): 실패 안내가 있어도 일반 결과는 버려지지 않는다.
## 저장이 되살아난 뒤 실제 열기 → 보상 안내가 보이고 실패 안내는 거둔다. 시험 층 벽 부딪힘 → 「벽이다」(HEAD 와 같다).
## 실제 열기 중 두 번째 실패 → 보상 안내가 보이고 실패 안내는 새 것 하나로 바뀐다.
func test_warning_does_not_eat_ordinary_results() -> void:
	var s := await _open()
	s.state.encounter.threshold = 99999
	var want := _fail_save(s, s._autosave)
	await kit.frames(2)
	check_eq(s.warning_shown(), want, "준비: 실패 안내")
	s.state.party.at = C1
	s.request_action(DungeonScreen.A.OPEN)
	await kit.frames(3)
	check_eq([s.state.world.is_chest_opened("c1"), s.last_autosave_error, _visible_notices(s)], [true, "", ["네온 쥐 꼬리 3개를 얻었다"]],
		"되살아난 뒤 열기: 보상 안내가 보이고 실패 안내는 거둔다")
	# 두 번째 실패가 실제 열기 중에.
	want = _fail_save(s, s._autosave)
	await kit.frames(2)
	s.state.party.at = Vector2i(17, 4)
	s.store.fail_points = ["write"]
	s.request_action(DungeonScreen.A.OPEN)
	s.store.fail_points = []
	await kit.frames(3)
	var seen := _visible_notices(s)
	check_eq([s.state.world.is_chest_opened("c4"), seen, seen.count(want)], [true, ["발광 인분 2개를 얻었다", want], 1],
		"실패 중 열기: 보상 안내와 새 실패 안내 하나")
	check(s._warn_left > 1.9, "새 실패 안내는 새 2초 %.2f" % s._warn_left)
	# 시험 층(HEAD 비교): (2,19) 남쪽 벽.
	kit.dispose()
	kit = Kit.new(tree)
	s = await kit.open()
	s.state.party.at = Vector2i(2, 19)
	s.state.party.facing = Dir.S
	s._set_state(s.state)
	await kit.frames(2)
	want = _fail_save(s, s._autosave)
	await kit.frames(2)
	s.request_action(DungeonScreen.A.FORWARD)
	await kit.frames(3)
	check_eq([s.state.party.at, s.last_autosave_error, _visible_notices(s)], [Vector2i(2, 19), "", ["벽이다"]], "되살아난 뒤 벽 부딪힘 = 「벽이다」")


## R4 (M-R4 실패 안내의 수명이 알림 줄 사라짐에 묶임): 끝 무렵 프레임 시간이 튀어도(1/60 초 119번, 100ms 한 번, 20ms 들) 실패 안내는
## 그 프레임에 끝나고 남지 않는다. 그 뒤 일반 안내는 곧바로 보인다.
func test_warning_ends_through_a_frame_spike() -> void:
	var s := await _open()
	s.set_process(false)
	var want := _fail_save(s, s._autosave)
	check_eq(s.warning_shown(), want, "준비: 실패 안내")
	for i in 119:
		s._fade_toast(1.0 / 60.0)
	check(s._warn_left > 0.0 and s.warning_shown() == want, "(전제) 끝 무렵에도 보인다 %.4f" % s._warn_left)
	s._fade_toast(0.1)
	check_eq([s._warn_left, s._warn_text, s.warning_shown(), s._warn_label.modulate.a, s._warn_at], [0.0, "", "", 0.0, null], "튄 프레임에서 끝난다")
	s._show_toast("끝난 뒤 안내")
	check_eq([s._toast.text, s._toast.modulate.a], ["끝난 뒤 안내", 1.0], "그 뒤 일반 안내는 곧바로 보인다")
	for i in 100:
		s._fade_toast(0.02)
	check_eq([s._warn_left, s.warning_shown()], [0.0, ""], "2초 뒤에도 실패 안내는 없다")
	s.set_process(true)


## R3 (M-R3 창이 열려도 화면 창 안내 줄을 고름): 캠프 안내 줄의 실패 안내 위로 아주 큰 가져오기 오류 알림(모르는 층 이름 1100자)이 뜨면
## 실패 안내는 창 둘레 띠로 옮기거나(자리가 없으면) 들고만 있고 시간을 멈춘다. 창을 닫으면 그때 남은 시간으로 캠프 안내 줄에 돌아온다.
func test_warning_under_an_oversized_alert() -> void:
	var s := await _sized_open(Vector2i(1280, 720))
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.frames(2)
	var want := _fail_save(s, s._on_party_save)
	await kit.frames(3)
	check_eq([pm.notice, s.warning_shown()], [want, want], "준비: 캠프 안내 줄에 실패 안내")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s.state))
	doc["state"]["floor"] = "x".repeat(1100)
	check(not s.import_text(JSON.stringify(doc)), "모르는 층 이름 가져오기는 실패")
	await kit.frames(4)
	var r := _modal_rect(s)
	check(s.modal.kind == "alert" and r.intersects(pm.notice_line.get_global_rect()), "(전제) 큰 알림 판이 캠프 안내 줄을 덮는다 %s" % str(r))
	# 이 판은 화면 높이를 다 덮어(위·아래 빈 띠 없음) 실패 안내는 들고만 있다.
	check(r.position.y - DungeonScreen.TOAST_GAP - DungeonScreen.TOAST_H < DungeonScreen.SAVE_CHIP_TOP + DungeonScreen.SAVE_CHIP_H + DungeonScreen.TOAST_GAP
		and r.end.y + DungeonScreen.TOAST_GAP + DungeonScreen.TOAST_H > s.get_viewport_rect().size.y - DungeonScreen.EDGE, "(전제) 판 위·아래에 띠가 없다")
	check_eq([s._warn_at, s._warn_text, pm.notice != want, s.warning_shown()], [null, want, true, ""], "덮인 캠프 안내 줄에서 거두고 들고만 있다")
	var l1 := s._warn_left
	await _wait(1.0)
	check(absf(s._warn_left - l1) < 0.001, "들고 있는 동안 시간이 멈춘다 %.3f → %.3f" % [l1, s._warn_left])
	s.modal.close()
	await kit.frames(3)
	check_eq([pm.notice, s.warning_shown()], [want, want], "창을 닫으면 캠프 안내 줄로 돌아온다")
	check(s._warn_left > l1 - 0.1, "남은 시간은 읽을 수 없던 동안 그대로 %.2f / %.2f" % [l1, s._warn_left])


# ---- 전투 띠와 시작 오류(검토 R5·R6) ----

## 시험 층에서 실제로 조사(「아무것도 없다」)한 뒤 위험을 문턱 바로 아래로 두고 걸어 전투에 든다. fail = 그 걸음의 자동 저장을 실패시킨다.
func _investigate_then_battle(px: Vector2i, fail: bool) -> DungeonScreen:
	if kit != null:
		kit.dispose()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = px
	timeout_sec = 60.0
	kit = Kit.new(tree)
	var s := await kit.open("native", 7, "debug=1")
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_SPACE)
	check(s._toast.text == s.texts.t("msg.nothing_found") and s._toast.modulate.a > 0.0 and s.modal.kind == "", "준비: 조사 안내가 보인다")
	s.state.encounter.danger = s.state.encounter.threshold - 1
	if fail:
		s.store.fail_points = ["write"]
	for i in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	s.store.fail_points = []
	await kit.frames(3)
	check(s.battle_layer.is_open(), "준비: 전투")
	return s


## R5 (M-R5 전투 띠에 실패 안내가 있는데 일반 안내를 그림, M-R5a 전투가 열려도 보이던 일반 안내를 남김): 전투 띠는 한 줄이다.
## 전투가 열리면 보이던 일반 안내(전투를 연 행동의 결과)는 지운다. 실패 안내가 전투 띠에 있으면 그것만 보이고, 그동안 나온 일반 안내는
## 그리지 않으며, 실패 안내가 끝나도 되살아나지 않는다. 실패 안내가 없으면 전투 띠는 HEAD 그대로 일반 안내를 보인다(세 크기).
func test_battle_band_holds_one_line() -> void:
	for px in SIZES:
		var tag := "%dx%d" % [px.x, px.y]
		var s := await _investigate_then_battle(px, true)
		var want := s.texts.t("msg.save_failed", {"reason": s.last_autosave_error})
		check_eq(_visible_notices(s), [want], tag + " 전투가 열리면 실패 안내만(조사 안내는 지운다)")
		var wr := s._warn_label.get_global_rect()
		check(is_equal_approx(wr.position.y, BattleLayer.TOAST_Y) and wr.position.x >= BattleLayer.TOAST_LEFT, tag + " 실패 안내는 전투 띠 %s" % str(wr))
		s._show_toast("전투 중 안내")
		await kit.frames(1)
		check_eq(_visible_notices(s), [want], tag + " 실패 안내가 있는 동안 전투 띠에 일반 안내를 그리지 않는다")
		await _wait(2.2)
		check_eq([s.battle_layer.is_open(), _visible_notices(s)], [true, []], tag + " 실패 안내가 끝나도 지난 안내는 되살아나지 않는다")
		s._show_toast("전투 띠 안내")
		await kit.frames(1)
		var tr := s._toast.get_global_rect()
		check(_visible_notices(s) == ["전투 띠 안내"] and is_equal_approx(tr.position.y, BattleLayer.TOAST_Y) and tr.position.x >= BattleLayer.TOAST_LEFT,
			tag + " 실패 안내가 없으면 전투 띠는 HEAD 그대로 %s" % str(tr))
		# 실패 없이 전투가 열려도 조사 안내는 지운다(화면 이동).
		s = await _investigate_then_battle(px, false)
		check_eq(_visible_notices(s), [], tag + " 실패 없이 전투가 열려도 보이던 일반 안내는 지운다")


## R6 (M-R6 시작 오류가 실패 안내 글줄을 남김): 정의를 읽지 못해 시작 오류가 나면 미리 만든 실패 안내 글줄도 치운다.
func test_start_error_frees_the_warning_label() -> void:
	timeout_sec = 30.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var held := []
	var s := await kit.open("native", 7, "", func(x: DungeonScreen) -> void:
		held.append(x._warn_label)
		x.party_path = "res://data/party/missing-a3b-fixture.json")
	check(s.start_error != null, "준비: 시작 오류")
	check(not is_instance_valid(held[0]), "실패 안내 글줄도 치웠다")
