## 숙소 화면(M3 A2b, 설계 §5.5): 원작 I HD 長鳴鶏の宿(jp_facility_img1) 층 표 — 숙박 확인(「예」 먼저)·자동 저장·날·카드, 기록 쪽(D30 = R-B),
## 캠프 「저장」은 숙소에서 연 캠프에서만. 시작 칸 휴식은 없앴다(R1). 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다).
## 시험마다 이름 붙은 변이(설계 노트 §7.4, M…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const SIZES := [Vector2(1280, 720), Vector2(1728, 720), Vector2(1280, 960)]
const INN := ["Inn_stay", "Inn_save", "Inn_talk", "Inn_leave"]

var kit: Kit
var _root_size := Vector2i.ZERO


func _town() -> DungeonScreen:
	timeout_sec = 90.0
	if kit == null:
		kit = Kit.new(tree)
	return await kit.open_town()


func teardown() -> void:
	if kit != null:
		kit.dispose()
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _window(px: Vector2) -> void:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)


func _inn(s: DungeonScreen) -> TownScreen:
	var t := s.town_screen
	await kit.tap(kit.center_of(t.plaza_list.rows[0]))
	await kit.frames(1)
	check_eq(t.page, "inn", "준비: 광장 「캡슐 숙소」 → 숙소")
	return t


func _names(t: TownScreen) -> Array:
	return t.visible_buttons().filter(func(b: TouchButton) -> bool: return not (b.get_parent() is VirtualPad)).map(
		func(b: TouchButton) -> String: return str(b.name))


## I4 (Mg2 숙박 뒤 자동 저장 없음): 숙소 쪽 — 줄 넷(대화 흐림), 띠(설명 / 숙박비), 소지금, 주인 자리표시, 카드. 숙박 → 확인 창 「예」 먼저 →
## 「아니오」·Esc 는 그대로 → 「예」 = HP·TP 가득·2일째·돈 −10·자동 저장 +1·안내·카드. 돈이 모자라면 창 없이 이유. 대화 = 이유. 취소·나간다 = 광장.
func test_inn_page_and_stay() -> void:
	var s := await _town()
	var t := await _inn(s)
	check_eq(t.inn_list.rows.map(func(r: ListRow) -> String: return str(r.name)), INN, "줄 이름")
	check_eq(t.inn_list.rows.map(func(r: ListRow) -> String: return r.text), ["1  숙박한다", "2  기록한다", "3  대화한다", "4  나간다"], "줄 글")
	check_eq(t.inn_list.rows.map(func(r: ListRow) -> bool: return r.dimmed), [false, false, true, false], "대화만 흐림")
	check_eq(t.banner.lines(), [s.texts.t("inn.desc.stay"), s.texts.t("inn.price", {"price": "10"}), false], "띠: 설명 / 숙박비 10엔")
	check(t.npc.is_visible_in_tree() and t.money_plate.is_visible_in_tree() and t.cards.is_visible_in_tree(), "주인 자리표시·소지금·카드")
	check(not t.plaza_list.is_visible_in_tree() and not t.place_plate.is_visible_in_tree(), "광장 줄·장소 문패는 감춘다")
	check_eq([t.money_text(), t.place_text(), t.art_key(), s.town_backdrop.place], [s.texts.t("shop.money", {"money": "200"}), "캡슐 숙소", "inn", "inn"],
		"소지금 200엔·장소·그림")
	await kit.frames(1)
	check_eq(TownArt.drawn_key(t.npc), "npc_inn", "주인 자리표시 그림")
	check_eq(_names(t), INN + ["CampButton"], "보이는 단추 = 숙소 줄·캠프(트리 순서)")
	for m in s.state.party.members:
		m.hp = 1
		m.tp = 0
	s.state.party.members[0].hp = 0
	t.refresh_view()
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.tap(kit.center_of(t.inn_list.rows[0]))
	check_eq([t.dialog.mode, t.dialog.pick, t.dialog.message], ["confirm", ShopDialog.YES, s.texts.t("inn.ask_stay", {"price": "10"})],
		"숙박 → 확인 창(「예」 먼저, D25)")
	check_eq(_names(t), ["Yes", "No"], "창이 떠 있으면 창 단추만")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.dialog.mode, kit.hash_now(), s.autosave_count, t.page], ["", h, saves, "inn"], "Esc = 아니오: 그대로")
	await kit.press_key(KEY_1)
	await kit.tap(kit.center_of(t.dialog.no_button))
	check_eq([t.dialog.mode, kit.hash_now(), s.autosave_count], ["", h, saves], "「아니오」: 그대로")
	await kit.press_key(KEY_ENTER)
	check_eq(t.dialog.mode, "confirm", "Enter(숙박 줄) → 확인 창")
	await kit.tap(kit.center_of(t.dialog.yes_button))
	await kit.frames(2)
	check(s.state.party.members.all(func(m: PartyState.Member) -> bool: return m.hp == m.max_hp and m.tp == m.max_tp), "HP·TP 가득(쓰러진 대원도)")
	check_eq([s.state.day, s.state.money, s.autosave_count], [2, 190, saves + 1], "2일째·190엔·자동 저장 +1")
	var auto := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.store.defs)
	check(auto.ok() and auto.state.day == 2 and SaveCodec.state_hash(auto.state) == kit.hash_now(), "자동 저장 = 묵은 상태")
	check_eq(t.banner.lines(), [s.texts.t("inn.desc.stay"), s.texts.t("inn.stayed"), true], "띠 둘째 줄: 묵었다")
	check_eq([t.camp_plate.day_text, t.money_text()], ["2일째", s.texts.t("shop.money", {"money": "190"})], "다이얼 2일째·소지금")
	check(t.cards.display.party.all(func(u) -> bool: return u.hp == u.max_hp and u.tp == u.max_tp), "카드도 가득")
	check_eq(s.debug_snapshot()["town"]["day"], "2일째", "스냅숏 날")
	# 돈이 모자람: 창 없이 이유만.
	s.state.money = 5
	h = kit.hash_now()
	saves = s.autosave_count
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_1)
	check_eq([t.dialog.mode, t.notice, kit.hash_now(), s.autosave_count], ["", s.texts.t("shop.why.no_money"), h, saves], "돈이 모자라면 이유만")
	await kit.tap(kit.center_of(t.inn_list.rows[2]))
	check_eq([t.notice, t.page, kit.hash_now()], [s.texts.t("inn.why.talk"), "inn", h], "대화(흐림) → 이유만")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.plaza_cursor], ["plaza", 0], "취소 → 광장(커서 숙소)")
	await kit.press_key(KEY_1)
	await kit.press_key(KEY_4)
	check_eq([t.page, t.plaza_cursor], ["plaza", 0], "「나간다」 → 광장")


## M-H9(답 커서가 바뀌어도 누르기를 버리지 않음, 검토 seq=9, 공용 창): 숙박 확인 창에서 키패드 「선택」·「예」·「아니오」를 손가락 3 으로 누른 채
## 답을 옮기면(손가락 4 방향 패드·방향키) 누르기가 풀리고, 떼도 묵지 않고 저장하지 않는다. 옮기지 않은 「예」는 묵고 자동 저장한다.
func test_answer_change_drops_held_presses() -> void:
	var s := await _town()
	var t := await _inn(s)
	await kit.press_key(KEY_1)
	check_eq([t.dialog.mode, t.dialog.pick], ["confirm", ShopDialog.YES], "준비: 숙박 확인(「예」 먼저)")
	var h := kit.hash_now()
	var saves := s.autosave_count
	var ok := t.active_key_pad().button("ok")
	for c in [["「선택」", ok], ["「예」", t.dialog.yes_button], ["「아니오」", t.dialog.no_button]]:
		for v in ["pad", "key"]:
			var tag := "%s(%s)" % [c[0], v]
			var b: TouchButton = c[1]
			var p := kit.center_of(b)
			var pick0 := t.dialog.pick
			var right := pick0 == ShopDialog.YES
			kit.touch(3, p, true)
			await kit.frames(1)
			check(b.held, tag + ": 준비: 누르는 중")
			if v == "pad":
				await kit.tap(kit.center_of(t.dir_pad.button("right" if right else "left")), 4)
			else:
				await kit.press_key(KEY_RIGHT if right else KEY_LEFT)
			check_eq(t.dialog.pick, 1 - pick0, tag + ": 답이 옮겨졌다")
			check(not b.held, tag + ": 답이 바뀌면 누르기 취소")
			kit.touch(3, p, false)
			await kit.frames(2)
			check_eq([t.dialog.mode, t.dialog.pick, kit.hash_now(), s.autosave_count, s.state.day], ["confirm", 1 - pick0, h, saves, 1],
				tag + ": 뗄 때 아무 일 없음(묵지 않고 저장 없음)")
	await kit.tap(kit.center_of(t.dialog.yes_button))
	await kit.frames(2)
	check_eq([t.dialog.mode, s.state.day, s.autosave_count], ["", 2, saves + 1], "보통 「예」 → 묵고 자동 저장")


## I5 (Mh2 캠프 「저장」이 어디서나 일함): 숙소 「기록한다」 = 기록 판(inn_save: 「저장」만) → 슬롯 1 기록(세대 +1, 슬롯 줄) → 취소 = 숙소.
## 캠프 「기록」: 숙소에서 열면 「저장」이 살아 있고, 광장·미궁에서 열면 흐리고 도움말은 이유, 누르거나 입력해도 쓰지 않는다. 불러오기는 그대로.
func test_inn_save_page_and_camp_save_rule() -> void:
	var s := await _town()
	var t := await _inn(s)
	await kit.tap(kit.center_of(t.inn_list.rows[1]))
	await kit.frames(1)
	var rt := t.records_tab
	check_eq([t.page, rt.row_set, t.ribbon.text], ["inn_save", "inn_save", s.texts.t("inn.save")], "「기록한다」 → 기록 쪽(장소 띠 「기록한다」)")
	check_eq(_names(t), ["Save_slot1", "Save_slot2", "Save_slot3", "CampButton"], "보이는 단추 = 「저장」 셋·캠프(트리 순서)")
	check(t.key_pad_stacked.is_visible_in_tree() and not t.key_pad.is_visible_in_tree(), "세로 키패드")
	check(not t.banner.is_visible_in_tree() and not t.inn_list.is_visible_in_tree() and not t.cards.is_visible_in_tree(), "띠·숙소 줄·카드 감춤")
	check_eq(rt.help_text(), s.texts.t("camp.records.help.save", {"n": 1}), "도움말 = 슬롯 1 저장")
	check(not rt.save_buttons[0].disabled, "숙소에서는 「저장」이 산다")
	await kit.tap(kit.center_of(rt.save_buttons[0]))
	await kit.frames(2)
	var l := s.store.load_slot("slot1")
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now() and l.result.state.in_town(), "슬롯 1 = 지금 상태(마을)")
	check(l.ok() and l.result.generation == s.state.generation, "세대 = 지금 세대")
	check_eq(rt.card_lines(0)[1], s.texts.t("menu.slot_where", {"floor": s.texts.t("town.plaza"), "steps": 0}), "슬롯 줄 = 광장 · 걸음")
	var gen := l.result.generation if l.ok() else -1
	await kit.tap(kit.center_of(rt.save_buttons[0]))
	await kit.frames(2)
	check_eq(s.store.load_slot("slot1").result.generation, gen + 1, "다시 기록하면 세대 +1")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.inn_cursor], ["inn", 1], "취소 → 숙소(커서 「기록한다」)")
	# 숙소에서 연 캠프: 「저장」이 산다.
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_6)
	var pm := s.party_menu
	var crt := pm.records_tab
	check_eq([pm.is_open(), pm.tab, pm.ribbon.text], [true, 4, "캡슐 숙소"], "숙소에서 연 캠프 「기록」(장소 띠 숙소)")
	check(not crt.save_buttons[1].disabled and crt.help_text() == s.texts.t("camp.records.help.save", {"n": 1}), "숙소에서 연 캠프: 「저장」 산다")
	await kit.tap(kit.center_of(crt.save_buttons[1]))
	await kit.frames(2)
	check(s.store.load_slot("slot2").ok(), "숙소 캠프에서 슬롯 2 저장")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open() and t.page == "inn", "준비: 캠프 닫힘, 숙소")
	# 광장에서 연 캠프: 흐림·이유·쓰지 않음.
	await kit.press_key(KEY_ESCAPE)
	check_eq(t.page, "plaza", "준비: 광장")
	await _camp_save_is_closed(s, "광장")
	# 미궁에서 연 캠프.
	await kit.press_key(KEY_6)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	check(not s.state.in_town(), "준비: 미궁")
	await _camp_save_is_closed(s, "미궁")


func _camp_save_is_closed(s: DungeonScreen, tag: String) -> void:
	var pm := s.party_menu
	var crt := pm.records_tab
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_6)
	check_eq([pm.is_open(), pm.tab, crt.cur_row, crt.cur_col], [true, 4, 0, 0], "%s: 캠프 「기록」(커서 슬롯 1 「저장」)" % tag)
	check(crt.save_buttons.all(func(b: ListButton) -> bool: return b.disabled and b.visible), "%s: 「저장」 셋 흐림" % tag)
	check_eq(crt.help_text(), s.texts.t("camp.records.help.save_inn"), "%s: 도움말 = 숙소에서 기록한다" % tag)
	check(not pm.pad_state()["ok"], "%s: 흐린 「저장」 위 선택 흐림" % tag)
	var files := _slot_files(s)
	var h := kit.hash_now()
	await kit.tap(kit.center_of(crt.save_buttons[2]))
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	check(not crt.dispatch("record_save", 2), "%s: record_save 입력도 거부" % tag)
	check_eq([_slot_files(s), kit.hash_now()], [files, h], "%s: 슬롯 파일 그대로" % tag)
	check(not crt.load_buttons[0].disabled and not crt.band_buttons[0].disabled, "%s: 불러오기·내보내기는 그대로" % tag)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "%s: 캠프 닫힘" % tag)


func _slot_files(s: DungeonScreen) -> Dictionary:
	var out := {}
	for slot in SaveStore.MANUAL_SLOTS:
		var p := s.store.main_path(slot)
		out[slot] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""
	return out


## R1 (Ml2 R 이 아직 회복함): 시작 칸 휴식은 없다 — Pad_rest 단추 없음, 시작 칸에서 R 은 상태를 바꾸지 않는다, 행동 이름에 rest 없음, STAIRS = 8.
func test_rest_is_removed() -> void:
	var s := await _town()
	await kit.press_key(KEY_6)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	check(not s.state.in_town() and s.state.party.at == s.state.floor_def.start_at, "준비: B1F 시작 칸")
	check(s.find_child("Pad_rest", true, false) == null, "Pad_rest 단추 없음")
	check(not s.debug_snapshot()["buttons"].has("Pad_rest"), "스냅숏에도 없음")
	s.state.party.members[1].hp = 3
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.press_key(KEY_R)
	await kit.frames(2)
	check_eq([s.state.party.members[1].hp, kit.hash_now(), s.autosave_count, s.modal.kind], [3, h, saves, ""], "시작 칸 R: 아무 일 없음")
	check(not ExplorationRules.ACTION_NAMES.has("rest"), "행동 이름에 rest 없음")
	check_eq([ExplorationRules.Action.STAIRS, ExplorationRules.Action.ENTER, ExplorationRules.ACTION_NAMES["stairs"]], [8, 9, 8], "STAIRS 8·ENTER 9 그대로")
	for k in ["action.rest", "msg.rested", "msg.not_rest_point"]:
		check(not s.texts.has(k), "글 %s 없음" % k)


## 숙소 층 표(§5.5)를 세 창 크기에서: 띠·캠프 단추·소지금·숙소 줄·카드·키패드 자리, 화면 안, 누르는 것 64 이상, 허용한 겹침만
## (주인 자리표시는 장식: 무엇과 겹쳐도 된다, 십자는 읽기 전용 카드 위). 숙박 확인 창은 화면 가운데 안. 기록 쪽은 장소 띠·판·세로 키패드.
## 실제 글꼴로 숙소·전멸 글이 자리에 든다.
func test_inn_layer_table_and_text_fit() -> void:
	var s := await _town()
	var t := await _inn(s)
	for px in SIZES:
		await _window(px)
		var W: float = px.x
		var H: float = px.y
		var screen := Rect2(Vector2.ZERO, px as Vector2)
		var boxes := {"banner": t.banner.get_global_rect(), "camp": t.camp_plate.get_global_rect(), "money": t.money_plate.get_global_rect(),
			"list": t.inn_list.get_global_rect(), "cards": t.cards.get_global_rect(), "dir": t.dir_pad.get_global_rect(),
			"keys": t.key_pad.get_global_rect()}
		check_eq(boxes["banner"], Rect2(192, 0, W - 192, 100), "%s: 띠" % px)
		check_eq(boxes["camp"], Rect2(0, 0, 176, 100), "%s: 캠프 단추" % px)
		check_eq(boxes["money"], Rect2(0, 112, 340, 50), "%s: 소지금 0,112 340×50" % px)
		check_eq(boxes["list"], Rect2(0, 166, 430, FacilityList.content_height(4, TownScreen.INN_GAP, TownScreen.INN_PAD)), "%s: 숙소 줄 x 0~430·y 166~" % px)
		check_eq(t.npc.get_global_rect(), Rect2(W - 560, 0, 560, H), "%s: 주인 자리표시 오른쪽 화면 높이" % px)
		check_eq(boxes["dir"].position, Vector2(8, H - 209), "%s: 십자" % px)
		check_eq(boxes["keys"].position, Vector2(W - 247, H - 293), "%s: 「취소」「선택」" % px)
		check(boxes["cards"].position.y >= boxes["list"].end.y, "%s: 카드는 숙소 줄 아래" % px)
		for k in boxes:
			check(screen.encloses(boxes[k]), "%s: %s 화면 안" % [px, k])
		var ks: Array = boxes.keys()
		for i in ks.size():
			for j in range(i + 1, ks.size()):
				var pair := [ks[i], ks[j]]
				pair.sort()
				if pair == ["cards", "dir"]:
					continue
				check(not boxes[ks[i]].intersects(boxes[ks[j]]), "%s: %s·%s 안 겹침" % [px, ks[i], ks[j]])
		for b in t.visible_buttons():
			check(b.size.y >= 64.0 and b.size.x >= 64.0, "%s: %s 누르는 크기 %s" % [px, b.name, b.size])
		t.handle("row", 0)
		await kit.frames(2)
		check_eq(t.dialog.mode, "confirm", "%s: 준비 확인 창" % px)
		check(screen.encloses(t.dialog.window_rect()), "%s: 확인 창 화면 안 %s" % [px, t.dialog.window_rect()])
		for b in [t.dialog.yes_button, t.dialog.no_button]:
			check(screen.encloses(b.get_global_rect()) and b.size.y >= 64.0, "%s: 창 단추 %s" % [px, b.name])
		t.handle("dialog", ["cancel", null])
		await kit.frames(2)
		t.handle("row", 1)
		await kit.frames(2)
		check_eq(t.page, "inn_save", "%s: 준비 기록 쪽" % px)
		check_eq(t.ribbon.get_global_rect(), Rect2(176, 0, W - 176 - 16, 66), "%s: 장소 띠" % px)
		check(screen.encloses(t.records_tab.window.get_global_rect()) and screen.encloses(t.key_pad_stacked.get_global_rect()), "%s: 판·세로 키패드 화면 안" % px)
		check(not t.records_tab.window.get_global_rect().intersects(t.camp_plate.get_global_rect()), "%s: 판·캠프 단추 안 겹침" % px)
		t.handle("back")
		await kit.frames(2)
	await _window(SIZES[0])
	# 글 맞춤(1280×720, 실제 글꼴).
	var font := t.banner.get_theme_default_font()
	var band_room := t.banner.size.x - 2.0 * FacilityBanner.PAD
	var fails := []
	for k in TownScreen.INN_KEYS:
		if font.get_string_size(s.texts.t("inn.desc." + k), HORIZONTAL_ALIGNMENT_LEFT, -1, FacilityBanner.FS).x > band_room:
			fails.append("띠 inn.desc.%s" % k)
	for x in [s.texts.t("inn.price", {"price": "9,999,990"}), s.texts.t("inn.stayed"), s.texts.t("inn.why.talk"), s.texts.t("inn.why.day_max")]:
		if font.get_string_size(x, HORIZONTAL_ALIGNMENT_LEFT, -1, FacilityBanner.SUB_FS).x > band_room:
			fails.append("띠 둘째 줄 %s" % x)
	for i in TownScreen.INN_KEYS.size():
		var row := t.inn_list.rows[i]
		var pts := row.polygon()
		var room := minf(pts[1].x, pts[2].x) - 22.0 - 24.0
		var w := row.get_theme_default_font().get_string_size(t.row_label("inn", i), HORIZONTAL_ALIGNMENT_LEFT, -1, row.font_size).x
		if w > room:
			fails.append("줄 %s %.1f > %.1f" % [t.row_label("inn", i), w, room])
	if font.get_string_size(s.texts.t("inn.ask_stay", {"price": "9,999,990"}), HORIZONTAL_ALIGNMENT_LEFT, -1, ShopDialog.TEXT_FS).x \
			> 2.0 * (ShopDialog.W - 2.0 * ShopDialog.PAD):
		fails.append("확인 창 글(두 줄 안)")
	if font.get_string_size(s.texts.t("camp.records.help.save_inn"), HORIZONTAL_ALIGNMENT_LEFT, -1, PartyRecordsTab.HELP_FS).x > PartyRecordsTab.HELP.size.x:
		fails.append("기록 도움말 save_inn")
	if font.get_string_size(s.texts.t("inn.save"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x > t.ribbon.size.x:
		fails.append("장소 띠 기록한다")
	if t.money_plate.size.x < font.get_string_size(s.texts.t("shop.money", {"money": "9,999,999"}), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 32.0:
		fails.append("소지금 9,999,999엔")
	# 전멸 창·지도 물음(층 3 창: 글은 360 폭에서 감기고, 단추는 240 이상에서 글에 맞춰 넓어진다): 단추 글이 창 폭 안(화면 안).
	for k in ["wipe.load_manual", "wipe.new_game", "wipe.map_ask", "wipe.map_title"]:
		if font.get_string_size(s.texts.t(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > SIZES[0].x - 200.0:
			fails.append("전멸 %s" % k)
	if font.get_string_size(s.texts.t("wipe.map_ask"), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 2.0 * 360.0:
		fails.append("지도 물음 두 줄 안")
	check_eq(fails, [], "숙소·전멸 글이 자리에 든다")
