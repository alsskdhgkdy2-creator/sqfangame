## 마을 화면(M3 A2a): 광장(§5.2)·아보르 입구(§5.3)·마을 문 물음(§5.6)·마을에서 연 캠프(§5.7)·키·층 표와 글 맞춤(§5).
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(설계 노트 §7.3, M…)를 적는다.
## 상점을 광장에서 여는 것(P2)은 test_shop_screen.test_entrance_is_the_plaza_and_opens_like_the_camp 가 본다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const PLAZA := ["Plaza_inn", "Plaza_shop", "Plaza_pub", "Plaza_guild", "Plaza_council", "Plaza_entrance"]
const SIZES := [Vector2(1280, 720), Vector2(1728, 720), Vector2(1280, 960)]
const FINGER := 3

var kit: Kit
var _root_size := Vector2i.ZERO


func _town(query: String = "") -> DungeonScreen:
	timeout_sec = 90.0
	if kit == null:
		kit = Kit.new(tree)
	return await kit.open_town("native", 7, query)


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


func _row(t: TownScreen, i: int) -> ListRow:
	return (t.plaza_list if t.page == "plaza" else t.entrance_list).rows[i]


static func _view_off(s: DungeonScreen) -> bool:
	return not s.view_container.visible and s._view_sv.render_target_update_mode == SubViewport.UPDATE_DISABLED and not s.view.can_process()


## P1 (Mv 줄 차례가 다름, Mw 흐린 줄이 일함, Mx 캠프 밑에 마을 화면이 보임): 광장 줄·흐림·띠·그림 띠·장소 문패·캠프.
func test_plaza() -> void:
	var s := await _town()
	var t := s.town_screen
	check(s.state.in_town() and t.is_open() and t.page == "plaza", "마을 새 게임 → 광장")
	check_eq(t.plaza_list.rows.map(func(r: ListRow) -> String: return str(r.name)), PLAZA, "줄 차례(원작 차례)")
	check_eq(t.plaza_list.rows.map(func(r: ListRow) -> String: return r.text),
		["1  캡슐 숙소", "2  정크 공방", "3  정보상 바", "4  모험가 길드", "5  관리국", "6  아보르 입구"], "줄 글")
	check_eq(t.plaza_list.rows.map(func(r: ListRow) -> bool: return r.dimmed), [false, false, true, false, true, false],
		"흐린 줄: 정보상 바·관리국(숙소는 A2b, 길드는 A7c 에서 연다)")
	check(not s.hud_root.visible and _view_off(s) and s.town_backdrop.visible and s.town_backdrop.place == "plaza", "HUD·시야 감춤, 광장 바탕")
	check_eq(t.banner.lines(), [s.texts.t("town.desc.inn"), "", false], "띠 첫 줄 = 커서 시설 설명")
	check_eq(t.place_plate.first, s.texts.t("town.plaza"), "장소 문패")
	check_eq(t.camp_plate.day_text, "1일째", "다이얼 자리 = 1일째")
	check_eq(t.camp_plate.text, s.texts.t("town.camp"), "다이얼 아래 「캠프」")
	await kit.frames(1)
	check_eq(TownArt.drawn_key(t.plaza_list), "inn", "그림 띠 = 커서 시설")
	check_eq(TownArt.drawn_key(s.town_backdrop), "plaza", "바탕 그림 = 광장")
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check_eq([t.plaza_cursor, t.banner.head, TownArt.drawn_key(t.plaza_list)], [1, s.texts.t("town.desc.shop"), "shop"], "커서를 따라 띠·그림 띠")
	# 흐린 줄: 이유만(상태·저장·창 그대로).
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.tap(kit.center_of(t.plaza_list.rows[2]))
	check_eq(t.banner.lines(), [s.texts.t("town.desc.pub"), s.texts.t("town.why.later"), true], "흐린 줄: 둘째 줄에 이유")
	check_eq([kit.hash_now(), s.autosave_count, t.page, s.shop_screen.is_open(), s.party_menu.is_open()], [h, saves, "plaza", false, false],
		"흐린 줄은 아무 일도 하지 않는다")
	await kit.press_key(KEY_UP)
	check_eq(t.banner.lines(), [s.texts.t("town.desc.shop"), "", false], "커서를 옮기면 이유를 지운다")
	# 캠프: 다이얼 자리 단추.
	await kit.tap(kit.center_of(t.camp_plate))
	await kit.frames(1)
	var pm := s.party_menu
	check(pm.is_open() and pm.page == "root", "「캠프」 → 캠프 뿌리")
	check(not t.visible and t.covered, "캠프가 열린 동안 마을 화면을 감춘다")
	check(s.town_backdrop.visible and _view_off(s), "캠프 그림 창에는 마을 바탕(3D 시야 꺼짐)")
	check_eq([pm.ribbon.text, pm.camp_plate.first], [s.texts.t("town.plaza"), "1일째"], "캠프 장소 띠·문패 = 광장·날")
	check(not s.debug_snapshot()["buttons"].has("Plaza_shop"), "캠프가 덮은 광장 줄은 스냅숏에 없다")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open() and t.visible and not t.covered and t.plaza_cursor == 1, "캠프를 닫으면 광장 그대로")
	var snap: Dictionary = s.debug_snapshot()
	check_eq([snap["location"], snap["day"], snap["town"]["page"], snap["town"]["rows"], snap["town"]["art"]], ["town", 1, "plaza", PLAZA, "plaza"],
		"스냅숏 location·day·town")
	check(snap["buttons"].has("Plaza_shop") and snap["buttons"].has("CampButton") and not snap["buttons"].has("MapButton"), "스냅숏 단추 = 광장")


## P3 (Mz 들어가자마자 물음): 입구 쪽 → 탐사 시작 = 미궁 시작 칸(물음 없음)·시야·HUD·저장 +1. 돌아가기 = 광장.
func test_entrance() -> void:
	var s := await _town()
	var t := s.town_screen
	await kit.press_key(KEY_6)
	check_eq(t.page, "entrance", "6 → 입구")
	check_eq(t.entrance_list.rows.map(func(r: ListRow) -> String: return str(r.name)), ["Entrance_start", "Entrance_back"], "입구 줄")
	check_eq(t.banner.lines(), [s.texts.t("entrance.band"), s.texts.t("entrance.desc.start"), false], "입구 띠")
	check(t.cards.visible and not t.plaza_list.visible and not t.place_plate.visible, "입구: 파티 카드, 광장 목록·문패 없음")
	check(t.cards.cards.all(func(c: Control) -> bool: return c.mouse_filter == Control.MOUSE_FILTER_IGNORE), "카드는 읽기만")
	check_eq([s.town_backdrop.place, s.debug_snapshot()["town"]["place"]], ["entrance", s.texts.t("town.fac.entrance")], "입구 바탕·장소")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.plaza_cursor], ["plaza", 5], "취소 → 광장(커서 = 아보르 입구)")
	await kit.press_key(KEY_ENTER)
	check_eq(t.page, "entrance", "Enter → 입구")
	await kit.tap(kit.center_of(t.entrance_list.rows[1]))
	check_eq([t.page, t.plaza_cursor], ["plaza", 5], "「마을로 돌아간다」 → 광장")
	await kit.press_key(KEY_6)
	var saves := s.autosave_count
	await kit.tap(kit.center_of(t.entrance_list.rows[0]))
	await kit.frames(3)
	var f := s.state.defs.first_floor()
	check_eq([s.state.location, s.state.floor_def.id, s.state.party.at, s.state.party.facing], ["labyrinth", f.id, f.start_at, f.start_facing],
		"미궁 시작 칸·시작 방향")
	check_eq(s.modal.kind, "", "들어가자마자 묻지 않는다")
	check_eq(s.autosave_count, saves + 1, "들어가면 자동 저장")
	check(not t.is_open() and s.hud_root.visible and s.view_container.visible and s.view.can_process() and not s.town_backdrop.visible,
		"마을 화면 닫힘, HUD·시야")
	check_eq(s._toast.text, FloorNames.place(s.texts, s.state.defs, f), "장소 토스트")
	check(s.state.knowledge.is_visited(f.start_at), "시작 칸 방문")
	check(SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.store.defs).state.location == "labyrinth",
		"자동 저장도 미궁")


## 미궁 문 밖 한 칸(북쪽)에 선다(실제 키로 들어가 걷는다). 위험도 한계 큼.
func _beside_gate(s: DungeonScreen) -> void:
	await kit.press_key(KEY_6)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_W)
	check_eq(s.state.party.at, s.state.floor_def.start_at + Vector2i(0, -1), "준비: 문 밖 한 칸")


func _labels(s: DungeonScreen) -> Array:
	return s.modal.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


## P4 (Ma2 문 물음이 안 뜸): 문으로 돌아오면 마을 글의 물음(「예」 먼저). 「아니오」 그대로, 조사로 다시, 「예」 → 광장·저장 +1.
func test_exit_prompt() -> void:
	var s := await _town()
	await _beside_gate(s)
	await kit.press_key(KEY_S)
	check_eq(s.modal.kind, "stairs", "문으로 돌아오면 물음")
	check_eq(s.modal.title_plate.text, s.texts.t("stairs.title_town"), "제목 = 아보르 입구")
	check(_labels(s).has(s.texts.t("stairs.ask_town")), "마을 물음 %s" % str(_labels(s)))
	check_eq(s.get_viewport().gui_get_focus_owner(), s.modal.find_child("StairsYes", true, false), "「예」에 포커스")
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.tap(kit.center_of(s.modal.find_child("StairsNo", true, false)))
	check_eq([s.modal.kind, kit.hash_now(), s.autosave_count, s.state.location], ["", h, saves, "labyrinth"], "「아니오」: 그대로·저장 없음")
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "stairs", "문 위 조사 → 다시 묻는다")
	await kit.press_key(KEY_BACKSPACE)
	check_eq(s.modal.kind, "", "Backspace = 「아니오」")
	await kit.press_key(KEY_SPACE)
	saves = s.autosave_count
	await kit.tap(kit.center_of(s.modal.find_child("StairsYes", true, false)))
	await kit.frames(3)
	var t := s.town_screen
	check(s.state.in_town() and t.is_open() and t.page == "plaza" and t.plaza_cursor == 0, "「예」 → 광장")
	check_eq(s.autosave_count, saves + 1, "마을로 = 저장 하나(조사 저장 뒤에 센다)")
	check_eq(SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.store.defs).state.location, "town", "자동 저장도 마을")
	check_eq(s._toast.text, s.texts.t("town.name"), "토스트 「뿌리마을」")
	check(_view_off(s) and not s.hud_root.visible, "시야 꺼짐·HUD 감춤")
	check_eq(s.state.party.at, s.state.floor_def.start_at, "위치는 B1F 시작 칸")


## P4: A1 경주 고침이 문에도 선다 — 걷는 연출 중 메모 창이 열리면 물음은 남고, 창을 닫은 뒤 문 물음이 뜬다.
func test_exit_prompt_waits_for_other_window() -> void:
	var s := await _town()
	await _beside_gate(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_S)
	check(s.view.is_busy() and s.state.party.at == s.state.floor_def.start_at, "준비 — 문으로 걷는 연출 중")
	s._on_memo_requested(s.state.party.at)
	for i in 120:
		if not s.view.is_busy():
			break
		await kit.frames(1)
	await kit.frames(3)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "메모 창이 열린 동안 물음은 남는다")
	await kit.click(kit.center_of(s.modal.find_child("MemoCancel", true, false)))
	await kit.frames(3)
	check_eq(s.modal.kind, "stairs", "메모 창을 닫으면 문 물음")
	check_eq(s.modal.title_plate.text, s.texts.t("stairs.title_town"), "마을 글")
	s.view.speed = 0.0


## P5: 마을에서 연 캠프 기록으로 미궁 슬롯을 불러오면 미궁(시야·HUD). 타이틀에서 가져오면 타이틀을 떠난다.
func test_load_and_import_switch_location() -> void:
	var s := await _town()
	await _beside_gate(s)
	s._save_slot("slot1")
	var slot_hash := kit.hash_now()
	await kit.press_key(KEY_S)
	await kit.tap(kit.center_of(s.modal.find_child("StairsYes", true, false)))
	await kit.frames(2)
	check(s.state.in_town(), "준비: 마을")
	await kit.tap(kit.center_of(s.town_screen.camp_plate))
	await kit.press_key(KEY_6)
	await kit.frames(2)
	var rt := s.party_menu.records_tab
	check_eq(rt.row_set, "camp", "캠프 기록 줄 묶음")
	await kit.tap(kit.center_of(rt.load_buttons[0]))
	await kit.frames(3)
	check(not s.state.in_town() and kit.hash_now() == slot_hash, "슬롯 1(미궁) → 미궁, 같은 해시")
	# 슬롯 줄의 장소: 마을 저장은 「뿌리마을 광장」, 미궁 저장은 층 이름.
	s._save_slot("slot2")
	var town_slot := ExplorationRules.new_game(s.store.defs, 3, "full", true)
	s.store.save("slot3", town_slot)
	var lines := s.record_slots()
	check(str(lines[0]["where"]).begins_with(FloorNames.place(s.texts, s.state.defs, s.state.floor_def)), "미궁 슬롯 = 층 이름 %s" % lines[0]["where"])
	check(str(lines[2]["where"]).begins_with(s.texts.t("town.plaza")), "마을 슬롯 = 뿌리마을 광장 %s" % lines[2]["where"])
	check(not s.town_screen.is_open() and s.hud_root.visible and s.view_container.visible and s.view.can_process(), "미궁 화면")
	# 타이틀에서 가져오기(네이티브 파일 고르기 대신 가져온 글을 바로 넘긴다).
	var text := SaveCodec.encode(s.state)
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.start_mode = "title")
	check(s.title_screen.is_open(), "준비: 타이틀")
	check(s.import_text(text), "가져오기")
	await kit.frames(2)
	check(not s.title_screen.is_open() and s.state != null and kit.hash_now() == slot_hash and s.hud_root.visible, "가져오면 타이틀을 떠나 미궁")


## P6: 광장 키 — ↑↓ 감김, 1~6, Enter, P = 캠프, Esc 없음. 마을에서 W·M·Space·R 는 아무 일도 하지 않는다.
func test_plaza_keys() -> void:
	var s := await _town()
	var t := s.town_screen
	await kit.press_key(KEY_UP)
	check_eq(t.plaza_cursor, 5, "↑ 감김")
	await kit.press_key(KEY_DOWN)
	check_eq(t.plaza_cursor, 0, "↓ 감김")
	var pad := t.pad_state()
	check(not pad["back"] and not pad["left"] and not pad["right"] and pad["up"] and pad["down"] and pad["ok"], "광장: 취소·←→ 흐림")
	for k in TownScreen.PAD_KEYS:
		check_eq(not t.key_action(TownScreen.PAD_KEYS[k]).is_empty(), pad[k], "키패드 %s = 키 표" % k)
	await kit.tap(kit.center_of(t.dir_pad.button("down")))
	await kit.frames(2)
	check_eq(t.plaza_cursor, 1, "키패드 ↓")
	var h := kit.hash_now()
	var saves := s.autosave_count
	for k in [KEY_W, KEY_M, KEY_SPACE, KEY_R, KEY_ESCAPE, KEY_A]:
		await kit.press_key(k)
	check_eq([kit.hash_now(), s.autosave_count, s._map_open, s.party_menu.is_open(), s.modal.kind, t.page], [h, saves, false, false, "", "plaza"],
		"W·M·Space·R·Esc·A: 아무 일 없음")
	check(not s.party_menu.is_open(), "Esc 는 캠프를 열지 않는다(마을, §8 고름 16)")
	await kit.press_key(KEY_P)
	check(s.party_menu.is_open(), "P → 캠프")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_3)
	check_eq([t.plaza_cursor, t.notice, t.page], [2, s.texts.t("town.why.later"), "plaza"], "3 → 정보상 바(흐림: 이유)")
	await kit.press_key(KEY_1)
	check_eq([t.plaza_cursor, t.page], [0, "inn"], "1 → 숙소 쪽(A2b)")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.plaza_cursor], ["plaza", 0], "숙소 취소 → 광장(커서 숙소)")
	await kit.press_key(KEY_6)
	check_eq(t.page, "entrance", "6 → 입구")
	await kit.press_key(KEY_3)
	check_eq(t.page, "entrance", "입구에서 3 은 없다")
	s._do_action(ExplorationRules.Action.FORWARD)
	check_eq(kit.hash_now(), h, "마을에서는 이동 행동이 들어가지 않는다")


## P7 (Mb2 ko.json 의 긴 설명): 세 창 크기에서 층 표 — 화면 안, 누르는 것 64 이상, 허용한 겹침만. 실제 글꼴로 글이 자리에 든다.
func test_layer_tables_and_text_fit() -> void:
	var s := await _town()
	var t := s.town_screen
	for px in SIZES:
		await _window(px)
		var W: float = px.x
		var H: float = px.y
		var screen := Rect2(Vector2.ZERO, px as Vector2)
		for page in ["plaza", "entrance"]:
			if t.page != page:
				if page == "entrance":
					t.handle("row", 5)
				else:
					t.handle("back")
				await kit.frames(2)
			check_eq(t.page, page, "준비 %s" % page)
			var boxes := {"banner": t.banner.get_global_rect(), "camp": t.camp_plate.get_global_rect(), "dir": t.dir_pad.get_global_rect(),
				"keys": t.key_pad.get_global_rect()}
			check_eq(boxes["banner"], Rect2(192, 0, W - 192, 100), "%s %s: 띠" % [px, page])
			check_eq(boxes["camp"], Rect2(0, 0, 176, 100), "%s %s: 캠프 단추" % [px, page])
			check_eq(boxes["dir"].position, Vector2(8, H - 209), "%s %s: 십자" % [px, page])
			check_eq(boxes["keys"].position, Vector2(W - 247, H - 293), "%s %s: 「취소」「선택」" % [px, page])
			var list: FacilityList = t.plaza_list if page == "plaza" else t.entrance_list
			boxes["list"] = list.get_global_rect()
			if page == "plaza":
				check_eq(boxes["list"], Rect2(0, 104, 580, 405), "%s: 광장 목록 x 0~580·y 104~509" % px)
				boxes["plate"] = t.place_plate.get_global_rect()
				check_eq(boxes["plate"], Rect2(W - 360, H - 88, 360, 76), "%s: 장소 문패" % px)
				var sr := list.strip_rect()
				check(Rect2(Vector2.ZERO, list.size).encloses(sr) and sr.end.x <= list.rows[0].position.x and sr.size.x > 100.0,
					"%s: 그림 띠는 목록 틀 안, 줄 왼쪽 %s" % [px, sr])
			else:
				check_eq(boxes["list"], Rect2(0, 288, 430, 140), "%s: 입구 목록 x 0~430·y 288~428(gw_27 y 300~415 둘레)" % px)
				boxes["cards"] = t.cards.get_global_rect()
				check(boxes["cards"].position.y >= boxes["list"].end.y, "%s: 카드는 입구 목록 아래" % px)
			for k in boxes:
				check(screen.encloses(boxes[k]), "%s %s: %s 화면 안" % [px, page, k])
			# 겹침: 허용 = 십자가 읽기 전용 카드 위(상점 뿌리와 같다). 나머지는 서로 겹치지 않는다.
			var ks: Array = boxes.keys()
			for i in ks.size():
				for j in range(i + 1, ks.size()):
					var pair := [ks[i], ks[j]]
					pair.sort()
					if pair == ["cards", "dir"]:
						continue
					check(not boxes[ks[i]].intersects(boxes[ks[j]]), "%s %s: %s·%s 안 겹침" % [px, page, ks[i], ks[j]])
			for b in t.visible_buttons():
				check(b.size.y >= 64.0 and b.size.x >= 64.0, "%s %s: %s 누르는 크기 %s" % [px, page, b.name, b.size])
	await _window(SIZES[0])
	# 글 맞춤(1280×720, 실제 글꼴): 띠 두 줄, 줄 글, 장소 문패, 다이얼 날, 타이틀 알약·로고.
	if t.page != "plaza":
		t.handle("back")
		await kit.frames(2)
	var font := t.banner.get_theme_default_font()
	var band_room := t.banner.size.x - 2.0 * FacilityBanner.PAD
	var fails := []
	var heads := []
	for k in TownScreen.PLAZA_KEYS:
		heads.append(s.texts.t("town.desc." + k))
	for k in TownScreen.ENTRANCE_KEYS:
		heads.append(s.texts.t("entrance.desc." + k))
	heads.append(s.texts.t("entrance.band"))
	for x in heads:
		if font.get_string_size(x, HORIZONTAL_ALIGNMENT_LEFT, -1, FacilityBanner.FS).x > band_room:
			fails.append("띠 %s" % x)
	if font.get_string_size(s.texts.t("town.why.later"), HORIZONTAL_ALIGNMENT_LEFT, -1, FacilityBanner.SUB_FS).x > band_room:
		fails.append("띠 둘째 줄")
	for p in ["plaza", "entrance"]:
		var l: FacilityList = t.plaza_list if p == "plaza" else t.entrance_list
		for i in t.keys_of(p).size():
			var row := l.rows[i]
			var pts := row.polygon()
			var room := minf(pts[1].x, pts[2].x) - 22.0 - 24.0
			var w := row.get_theme_default_font().get_string_size(t.row_label(p, i), HORIZONTAL_ALIGNMENT_LEFT, -1, row.font_size).x
			print("글 맞춤 줄 %s: %.1f / %.1f" % [t.row_label(p, i), w, room])
			if w > room:
				fails.append("줄 %s %.1f > %.1f" % [t.row_label(p, i), w, room])
	t.place_plate.queue_redraw()
	await kit.frames(1)
	check_eq(t.place_plate.drawn_sizes, [22], "장소 문패 글은 줄이지 않는다")
	var day := s.texts.t("town.day", {"n": ExplorationState.DAY_MAX})
	if font.get_string_size(day, HORIZONTAL_ALIGNMENT_LEFT, -1, TownPlate.DAY_FS).x > TownPlate.SIZE.x - FacilityPlate.TEXT_INSET:
		fails.append("다이얼 %s" % day)
	for k in TitleScreen.MENU_KEYS:
		if font.get_string_size(s.texts.t("title." + k), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x > TitleScreen.PILL.x - 48.0:
			fails.append("타이틀 %s" % k)
	if font.get_string_size(s.texts.t("title.name"), HORIZONTAL_ALIGNMENT_LEFT, -1, TitleScreen.LOGO_FS).x > SIZES[0].x - 64.0:
		fails.append("로고")
	check_eq(fails, [], "모든 마을·타이틀 글이 자리에 든다")


## 준비: 타이틀(state 없음)이면 _open_title, 마을이면 새 마을 상태. 그다음 steps 를 한 프레임에 하나씩 넣는다.
func _sweep_prep(s: DungeonScreen, where: String, steps: Array) -> Control:
	if where == "title":
		s._open_title()
	else:
		s._set_state(ExplorationRules.new_game(s.store.defs, 7, s.settings.automap, true))
	await kit.frames(2)
	var scr: Control = s.title_screen if where == "title" else s.town_screen
	for st in steps:
		check(scr.call("handle", st[0], st[1]), "준비 %s %s" % [where, str(st)])
		await kit.frames(1)
	await kit.frames(1)
	return scr


## R1 (Mr1 타이틀 확인 창이 키패드를 덮음, Mpad 타이틀 키패드 표가 움직일 수 없는 ←→·↑↓를 켬): 새 화면의 모든 쪽·창 상태에서 켜진
## 키패드 단추를 실제 터치(InputEventScreenTouch)로 누르면 그 입력이 받아지고(받은 입력 +1), 흐린 단추는 아무 일 없다.
## 키패드 표(pad_state)와 실제 터치 전달이 어긋나지 않게 한다. 커서는 끝이 아닌 자리에 둔다(끝은 켜 둔 채 움직이지 않는다, 캠프와 같다).
## 단추가 둘뿐인 창(숙박 확인)은 끝이 없을 수 없어 「예」·「아니오」 두 상태로 나눠, 움직일 자리가 있는 쪽에서 누른다(건너뛴 쪽도 켜짐은 본다).
## M3 A2b(Mpad2 숙소 기록 쪽 ←→ 를 켬, Mr2 숙박 확인 창을 키패드 뒤에 붙임): 숙소·숙박 확인 두 상태·숙소 기록 쪽을 더했다.
## 전멸 창·지도 물음(층 3)은 탐색 HUD 키패드를 덮는다(키패드가 살아 있지 않다): 이 표에 없다.
func test_every_enabled_pad_button_acts_on_touch() -> void:
	await _town()  # 자동 저장(마을 새 게임) → 타이틀에 「이어하기」
	kit.close_screen()
	await kit.frames(1)
	DirAccess.make_dir_recursive_absolute(kit.dir)
	var s := await kit.open_title()
	var dirs := ["up", "down", "left", "right"]
	# [이름, 곳, 준비 입력, 켜질 단추]
	var cases := [
		["타이틀 메뉴(커서 설정)", "title", [["cursor", -1]], ["up", "down", "ok"]],
		["타이틀 새 게임 확인", "title", [["row", 2]], ["left", "right", "ok", "back"]],
		["타이틀 불러오기(둘째 줄, 빈 슬롯)", "title", [["row", 1], ["cursor", 1]], ["up", "down", "back"]],
		["타이틀 설정(가운데 칸)", "title", [["row", 3], ["cursor_x", 1]], ["left", "right", "ok", "back"]],
		["광장", "town", [], ["up", "down", "ok"]],
		["아보르 입구", "town", [["row", 5]], ["up", "down", "ok", "back"]],
		["캡슐 숙소(커서 기록)", "town", [["row", 0], ["cursor", 1]], ["up", "down", "ok", "back"]],
		["숙박 확인(「예」)", "town", [["row", 0], ["row", 0]], ["left", "right", "ok", "back"], ["left"]],
		["숙박 확인(「아니오」)", "town", [["row", 0], ["row", 0], ["dialog", ["pick", 1]]], ["left", "right", "ok", "back"], ["right"]],
		["숙소 기록(둘째 줄)", "town", [["row", 0], ["row", 1], ["cursor", 1]], ["up", "down", "ok", "back"]],
	]
	var pages := {"타이틀 메뉴(커서 설정)": ["menu", false], "타이틀 새 게임 확인": ["menu", true], "타이틀 불러오기(둘째 줄, 빈 슬롯)": ["load", false],
		"타이틀 설정(가운데 칸)": ["settings", false], "광장": ["plaza", false], "아보르 입구": ["entrance", false], "캡슐 숙소(커서 기록)": ["inn", false],
		"숙박 확인(「예」)": ["inn", true], "숙박 확인(「아니오」)": ["inn", true], "숙소 기록(둘째 줄)": ["inn_save", false]}
	for c in cases:
		var skip: Array = c[4] if c.size() > 4 else []
		for k in TitleScreen.PAD_KEYS:
			var scr: Control = await _sweep_prep(s, c[1], c[2])
			if k == "up":
				check_eq([scr.get("page"), bool(scr.get("dialog").call("is_open"))], pages[c[0]], "%s: 준비된 쪽" % c[0])
			var vp: VirtualPad = scr.get("dir_pad") if dirs.has(k) else scr.call("active_key_pad")
			var b := vp.button(k)
			var on: bool = scr.call("pad_state")[k]
			var tag := "%s: 키패드 %s" % [c[0], k]
			check_eq(on, (c[3] as Array).has(k), tag + " 켜짐")
			check_eq(not b.disabled, on, tag + " 단추 흐림 = 키패드 표")
			check(b.is_visible_in_tree(), tag + " 보임")
			if skip.has(k):
				continue  # 끝: 다른 상태에서 누른다
			var n: int = scr.get("accepted_inputs")
			await kit.tap(kit.center_of(b), FINGER)
			await kit.frames(1)
			check_eq(int(scr.get("accepted_inputs")) - n, 1 if on else 0, tag + (" 터치 → 받음" if on else " 흐림 → 아무 일 없음"))


## L1 (Mtoast 물음이 떠도 장소 안내가 남음, Mtoast2 저장 실패 안내까지 지움): 들어온 뒤 2초 안에 문으로 돌아오면 문 물음이 뜨고,
## 들어올 때의 장소 안내(층 4, 물음 띠 아래 테두리와 겹친다)는 지운다. 그때의 자동 저장이 실패했으면 그 안내는 남긴다.
func test_gate_prompt_hides_the_place_toast() -> void:
	var s := await _town()
	await kit.press_key(KEY_6)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	var place := FloorNames.place(s.texts, s.state.defs, s.state.floor_def)
	check(s._toast.text == place and s._toast.modulate.a > 0.9, "준비: 장소 안내가 보인다")
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	check_eq(s.modal.kind, "stairs", "문 물음")
	check(s._toast_left <= 0.0 and s._toast.modulate.a == 0.0, "물음이 뜨면 장소 안내를 지운다")
	await kit.frames(3)
	check_eq(s._toast.modulate.a, 0.0, "다시 나타나지 않는다")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_W)
	s.store.fail_points = ["write"]
	await kit.press_key(KEY_S)
	s.store.fail_points = []
	check_eq(s.modal.kind, "stairs", "준비: 다시 문 물음")
	check(not s.last_autosave_error.is_empty(), "준비: 자동 저장 실패")
	# M3 A3b(검토 R2~R4): 저장 실패 안내는 자기 글줄(SaveWarning)에 보인다.
	check(s._warn_label.text == s.texts.t("msg.save_failed", {"reason": s.last_autosave_error}) and s._warn_label.modulate.a > 0.9,
		"저장 실패 안내는 물음이 떠도 남는다")
