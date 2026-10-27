## 타이틀(M3 A2a, §5.1): 시작 화면·이어하기·새 게임(확인)·불러오기·설정, 키 = 키패드, 깨진 자동 저장, 다시 열면 다시 타이틀.
## 3D 시야 끄기(조정자 조정 2): 타이틀·마을에서는 SubViewport 를 그리지 않고 시야 노드가 멈추며, 미궁에 들어가면 되살린다.
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(설계 노트 §7.3, M…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const FINGER := 3

var kit: Kit


func _kit() -> void:
	timeout_sec = 60.0
	if kit == null:
		kit = Kit.new(tree)


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _title(prepare: Callable = Callable()) -> DungeonScreen:
	_kit()
	return await kit.open_title("native", 7, "", prepare)


## 자동 저장을 하나 만든다(미궁 새 게임 → 한 칸 → 자동 저장)와 그 해시.
func _make_labyrinth_save() -> String:
	_kit()
	var s := await kit.open()
	await kit.press_key(KEY_W)
	var h := SaveCodec.state_hash(s.state)
	kit.close_screen()
	await kit.frames(1)
	return h


func _visible_names(t: TitleScreen) -> Array:
	return t.visible_buttons().filter(func(b: TouchButton) -> bool: return not (b.get_parent() is VirtualPad)).map(
		func(b: TouchButton) -> String: return str(b.name))


func _press(t: TitleScreen, k: String) -> void:
	await kit.tap(kit.center_of(t.menu_buttons[k]))
	await kit.frames(2)


## 3D 시야가 꺼졌는지(그리지 않음·멈춤·감춤)를 한 묶음으로.
static func _view_off(s: DungeonScreen) -> bool:
	return not s.view_container.visible and s._view_sv.render_target_update_mode == SubViewport.UPDATE_DISABLED \
		and s.view.process_mode == Node.PROCESS_MODE_DISABLED and not s.view.can_process()


static func _view_on(s: DungeonScreen) -> bool:
	return s.view_container.visible and s._view_sv.render_target_update_mode == s._view_sv_mode \
		and s._view_sv_mode != SubViewport.UPDATE_DISABLED and s.view.can_process()


## U1 (Mp 이어하기 늘 보임): 빈 폴더 타이틀 = 불러오기·새 게임·설정, 상태 없음, HUD·시야 감춤, 스냅숏 title.
func test_title_boot_on_empty_folder() -> void:
	var s := await _title()
	var t := s.title_screen
	check(t.is_open() and t.page == "menu" and s.state == null, "타이틀, 상태 없음")
	check_eq(t.rows, ["load", "new_game", "settings"] as Array[String], "줄 = 불러오기·새 게임·설정(이어하기 없음)")
	check(not t.menu_buttons["continue"].visible, "「이어하기」 단추 감춤")
	check_eq(_visible_names(t), ["TitleLoad", "TitleNewGame", "TitleSettings"], "보이는 단추")
	check_eq(t.cursor, 0, "커서는 첫 줄")
	check(t.menu_buttons["load"].selected and _yellow(t) == ["TitleLoad"], "노랑 채움 하나 = 첫 줄")
	check(not s.hud_root.visible and not s.town_backdrop.visible and not s.town_screen.is_open(), "HUD·마을 감춤")
	check(_view_off(s), "3D 시야 꺼짐")
	check_eq(s.autosave_count, 0, "타이틀은 저장하지 않는다")
	check(not DirAccess.dir_exists_absolute(s.save_dir) or DirAccess.get_files_at(s.save_dir).is_empty(), "저장 파일 없음")
	var snap: Dictionary = s.debug_snapshot()
	check_eq([snap["hash"], snap["title"]["open"], snap["title"]["rows"], snap["title"]["continue"]], ["", true, ["load", "new_game", "settings"], false],
		"스냅숏 title")
	check(snap["buttons"].has("TitleNewGame") and not snap["buttons"].has("TitleContinue") and not snap["buttons"].has("CampButton"), "스냅숏 단추")
	check(JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "simulate", "actions": ["forward"]})))["error"] == "no state", "상태가 없으면 simulate 없음")
	# 그린 것: 바탕 그림(title)과 로고·안내 글.
	check_eq(TownArt.drawn_key(t), "title", "타이틀 바탕 그림")


static func _yellow(t: TitleScreen) -> Array:
	return t.yellow_fills().map(func(b: TouchButton) -> String: return str(b.name))


## 웹 확인 C 가 찾은 것: 타이틀(상태 없음)에서도 입력을 받으면 디버그 상태 요약을 다시 낸다(쪽이 바뀐 요약).
func test_title_publishes_debug_snapshot_on_input() -> void:
	_kit()
	var s := await kit.open_title("native", 7, "debug=1")
	await kit.frames(4)
	var n := s.debug_publishes
	check(n > 0, "준비: 처음 요약")
	await kit.frames(4)
	check_eq(s.debug_publishes, n, "바뀐 것이 없으면 다시 내지 않는다")
	await _press(s.title_screen, "load")
	check(s.debug_publishes > n, "타이틀 입력 → 요약을 다시 낸다(%d → %d)" % [n, s.debug_publishes])
	check_eq(s.debug_snapshot()["title"]["page"], "load", "요약의 쪽 = 불러오기")


## U2 (Mq 이어하기가 새 게임): 자동 저장이 있으면 이어하기가 첫 줄, 고르면 같은 해시·HUD·시야, 저장하지 않는다. 마을 저장이면 광장.
func test_continue_resumes_the_autosave() -> void:
	var h := await _make_labyrinth_save()
	var s := await _title()
	var t := s.title_screen
	check_eq(t.rows, ["continue", "load", "new_game", "settings"] as Array[String], "이어하기가 첫 줄")
	check(t.menu_buttons["continue"].selected, "커서 = 이어하기")
	await _press(t, "continue")
	check(not t.is_open() and s.state != null, "타이틀 닫힘")
	check_eq([SaveCodec.state_hash(s.state), s.autosave_count, s.state.location], [h, 0, "labyrinth"], "같은 해시, 저장 안 함, 미궁")
	check(s.hud_root.visible and _view_on(s), "HUD·3D 시야 되살림")
	check_eq([s.view._pos, s.view._yaw], [DungeonMeshBuilder.cell_center(s.state.party.at), DungeonView.yaw_of(s.state.party.facing)], "시야 자세 = 상태")
	# 마을 자동 저장 → 이어하기 → 광장.
	s._start_new_game()
	await kit.frames(2)
	check(s.state.in_town() and s.autosave_count == 1, "준비: 마을 새 게임 저장")
	var th := SaveCodec.state_hash(s.state)
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.start_mode = "title")
	await _press(s.title_screen, "continue")
	check(s.town_screen.is_open() and s.town_screen.page == "plaza" and SaveCodec.state_hash(s.state) == th, "마을 저장 → 광장, 같은 해시")
	check(_view_off(s) and not s.hud_root.visible and s.town_backdrop.visible, "마을: 시야 꺼짐·HUD 감춤·바탕")


## U3 (Mr 확인 없음): 자동 저장이 있으면 새 게임은 확인 창(「돌아가기」 먼저), 돌아가기는 타이틀 그대로, 고르면 마을·1일째·저장 +1.
## 자동 저장이 없으면 바로 시작한다.
func test_new_game_confirm() -> void:
	await _make_labyrinth_save()
	var s := await _title()
	var t := s.title_screen
	await _press(t, "new_game")
	check(t.dialog.is_open() and t.dialog.pick == 0, "확인 창, 커서 「돌아가기」")
	check_eq(t.dialog.label.text, s.texts.t("title.confirm_new"), "확인 글")
	check_eq(_visible_names(t), ["DialogBack", "DialogOk"], "창이 떠 있으면 창 단추만")
	await kit.press_key(KEY_ESCAPE)
	check(t.is_open() and not t.dialog.is_open() and s.state == null, "Esc = 돌아가기: 타이틀 그대로")
	await kit.press_key(KEY_3)
	check(t.dialog.is_open(), "키 3 = 새 게임 → 확인 창")
	await kit.press_key(KEY_RIGHT)
	check_eq(t.dialog.pick, 1, "→ 로 「새 게임」")
	await kit.press_key(KEY_ENTER)
	check(not t.is_open() and s.state != null and s.state.in_town() and s.state.day == 1, "마을·1일째")
	check_eq(s.autosave_count, 1, "새 게임은 저장한다")
	check(s.town_screen.is_open() and s.town_screen.page == "plaza", "광장")
	# 자동 저장이 없으면 확인 없이 바로.
	kit.close_screen()
	remove_saves(kit.dir + "/saves")
	await kit.frames(1)
	s = await kit.open_title()
	await _press(s.title_screen, "new_game")
	check(not s.title_screen.is_open() and s.state != null and s.state.in_town(), "자동 저장이 없으면 확인 없이 마을")


static func remove_saves(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))


## U4 (Ms 타이틀에 「저장」 알약이 보임): 불러오기 쪽은 슬롯 「불러오기」·「가져오기」만, 빈 칸은 흐림. 불러오기 → 상태·저장. 취소 → 메뉴.
func test_load_page() -> void:
	_kit()
	var s := await kit.open()
	await kit.press_key(KEY_W)
	s._save_slot("slot2")
	var slot_hash := SaveCodec.state_hash(s.state)
	kit.close_screen()
	await kit.frames(1)
	s = await kit.open_title()
	var t := s.title_screen
	await _press(t, "load")
	check_eq(t.page, "load", "불러오기 쪽")
	check_eq(t.ribbon.text, s.texts.t("title.load"), "장소 띠 「불러오기」")
	var rt := t.records_tab
	check_eq(rt.row_set, "title_load", "줄 묶음 title_load")
	var names := _visible_names(t)
	check_eq(names, ["Load_slot1", "Load_slot2", "Load_slot3", "Import"], "보이는 단추 = 슬롯 불러오기 셋·가져오기")
	for n in ["Save_slot1", "Save_slot2", "Save_slot3", "Export", "NewGame", "Automap_off"]:
		var b := t.find_child(n, true, false) as Control
		check(b != null and not b.is_visible_in_tree(), "%s 는 보이지 않는다" % n)
	check(rt.load_buttons[0].disabled and not rt.load_buttons[1].disabled and rt.load_buttons[2].disabled, "빈 칸은 흐림")
	check(not rt.dispatch("record_save", 0) and not rt.dispatch("record_export", null) and not rt.dispatch("record_new_game", null),
		"보이지 않는 알약의 입력은 받지 않는다")
	check_eq(rt.track_count(), 4, "길 넷(슬롯 셋·파일)")
	check_eq(rt.grid().map(func(r: Array) -> int: return r.size()), [1, 1, 1, 1], "줄마다 알약 하나")
	# 「가져오기」 알약은 길 한 줄을 다 쓴다(위에서부터 채움).
	var imp := rt.band_buttons[1]
	check_eq(imp.position.y - rt.window.position.y, PartyRecordsTab.track_rect(3).position.y + ListParts.OPT_TRACK_INSET, "파일 줄 = 넷째 길")
	check(absf(imp.size.x - PartyRecordsTab.VALUE_W) < 1.0, "알약 하나가 값 칸 폭 전체")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.cursor], ["menu", t.rows.find("load")], "취소 → 메뉴(커서 그대로 불러오기)")
	await _press(t, "load")
	await kit.tap(kit.center_of(rt.load_buttons[1]))
	await kit.frames(2)
	check(not t.is_open() and s.state != null and SaveCodec.state_hash(s.state) == slot_hash, "슬롯 2 불러오기 → 같은 해시")
	check_eq(s.autosave_count, 1, "불러오기는 자동 저장")
	check(_view_on(s) and s.hud_root.visible, "미궁 저장 → 시야·HUD")


## U5: 설정 쪽은 자동 지도 줄 하나, 바꾸면 설정 파일에 쓴다.
func test_settings_page() -> void:
	_kit()
	DirAccess.make_dir_recursive_absolute(kit.dir)  # 설정 파일 폴더(실제 user:// 는 늘 있다, 시험 임시 폴더는 저장 전에는 없다)
	var s := await _title()
	var t := s.title_screen
	await _press(t, "settings")
	check_eq([t.page, t.records_tab.row_set, t.ribbon.text], ["settings", "title_settings", s.texts.t("title.settings")], "설정 쪽")
	check_eq(_visible_names(t), ["Automap_off", "Automap_floor", "Automap_full"], "자동 지도 셋만")
	check_eq(t.records_tab.track_count(), 1, "길 하나")
	var before := s.settings.automap
	var other := "off" if before != "off" else "full"
	await kit.tap(kit.center_of(t.find_child("Automap_" + other, true, false)))
	await kit.frames(2)
	check_eq([s.settings.automap, GameSettings.load_from(s.settings_path).automap], [other, other], "바꾼 값이 설정 파일에")
	check((t.find_child("Automap_" + other, true, false) as ListButton).checked, "고른 값이 켜짐")
	check(s.state == null and t.is_open(), "타이틀 그대로")


## U6 (Mt 키패드와 키 표가 다름): 모든 쪽에서 키패드 단추 = 그 키. 메뉴 ↑↓ 감김, Esc 없음, 반복 키 무시.
func test_keys_equal_pad() -> void:
	await _make_labyrinth_save()
	var s := await _title()
	var t := s.title_screen
	for page in ["menu", "load", "settings"]:
		if page != "menu":
			t.page = "menu"
			t.handle("row", t.rows.find(page))
			await kit.frames(1)
		check_eq(t.page, page, "준비: %s" % page)
		var st := t.pad_state()
		for k in TitleScreen.PAD_KEYS:
			var a := t.key_action(TitleScreen.PAD_KEYS[k])
			check_eq(st[k], not a.is_empty() and t._may_accept(a), "%s: 키패드 %s 켜짐 = 키 표" % [page, k])
			var vp := t.dir_pad if k in ["up", "down", "left", "right"] else t.active_key_pad()
			check_eq(not vp.button(k).disabled, st[k], "%s: 키패드 %s 단추 흐림" % [page, k])
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.cursor], ["menu", t.rows.find("settings")], "준비: 메뉴(커서 = 설정 줄)")
	for i in t.rows.size():
		if t.cursor == 0:
			break
		await kit.press_key(KEY_DOWN)
	check_eq(t.cursor, 0, "준비: ↓ 로 감겨 첫 줄")
	var pad := t.pad_state()
	check(not pad["back"] and not pad["left"] and not pad["right"] and pad["up"] and pad["down"] and pad["ok"], "메뉴: 취소·←→ 흐림")
	await kit.press_key(KEY_UP)
	check_eq(t.cursor, t.rows.size() - 1, "↑ 는 감긴다")
	await kit.press_key(KEY_DOWN)
	check_eq(t.cursor, 0, "↓ 로 다시 첫 줄")
	# 키패드 ↓ = KEY_DOWN.
	await kit.tap(kit.center_of(t.dir_pad.button("down")))
	await kit.frames(2)
	check_eq(t.cursor, 1, "키패드 ↓")
	# 반복 키는 무시한다.
	var n := t.accepted_inputs
	var k := InputEventKey.new()
	k.physical_keycode = KEY_DOWN
	k.keycode = KEY_DOWN
	k.pressed = true
	k.echo = true
	Input.parse_input_event(k)
	Input.flush_buffered_events()
	await kit.frames(2)
	check_eq([t.accepted_inputs, t.cursor], [n, 1], "반복 키 무시")
	await kit.press_key(KEY_ESCAPE)
	check_eq([t.page, t.cursor, s.state], ["menu", 1, null], "메뉴 Esc 는 아무 일 없음")
	# 숫자 키 = 줄.
	await kit.press_key(KEY_4)
	check_eq(t.page, "settings", "키 4 = 설정(이어하기가 있을 때)")


## U7: 깨진 자동 저장 → 타이틀 + 알림, 이어하기 없음.
func test_broken_autosave_shows_alert_over_title() -> void:
	_kit()
	DirAccess.make_dir_recursive_absolute(kit.dir + "/saves")
	var f := FileAccess.open(kit.dir + "/saves/auto.json", FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var s := await kit.open_title()
	check(s.title_screen.is_open() and not s.title_screen.can_continue, "이어하기 없음")
	check_eq(s.modal.kind, "alert", "알림")
	var labels := s.modal.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.has(s.texts.t("title.auto_broken")), "타이틀 알림 글 %s" % str(labels))
	check(not s.title_screen.handle("row", 0), "알림이 떠 있으면 타이틀은 받지 않는다")
	check(s.state == null, "새 게임으로 시작하지 않는다")
	check_eq(FileAccess.get_file_as_string(kit.dir + "/saves/auto.json"), "{broken", "깨진 파일은 그대로")
	await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	await kit.frames(2)
	check(s.modal.kind == "" and s.title_screen.handle("row", 0), "알림을 닫으면 타이틀이 받는다")


## U8 (Mu 기본 시작이 이어하기): 같은 폴더로 다시 열면(웹 새로 고침) 타이틀이 다시 뜬다.
func test_reopen_shows_title_again() -> void:
	var h := await _make_labyrinth_save()
	_kit()
	var plain: DungeonScreen = Kit.SCREEN.instantiate()
	check_eq(plain.start_mode, "title", "화면 기본 시작은 타이틀")
	# 트리에 넣지 않은 화면: 미리 만든 부품(_ready 가 트리에 넣는 것)도 함께 지운다(_show_start_error 와 같다).
	for n in [plain._floor_label, plain._steps_label, plain._toast, plain._warn_label, plain._flash, plain.save_chip]:
		(n as Node).free()
	plain.free()
	var s := await kit.open_title()
	await _press(s.title_screen, "continue")
	check(s.state != null, "준비: 이어함")
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.start_mode = "title")
	check(s.title_screen.is_open() and s.state == null and s.title_screen.can_continue, "다시 열면 타이틀(이어하지 않음)")
	check(_view_off(s), "타이틀: 시야 꺼짐")
	await _press(s.title_screen, "continue")
	check_eq(SaveCodec.state_hash(s.state), h, "다시 이어하면 같은 해시")


## 조정 2: 3D 시야는 타이틀·마을에서 그리지 않고 멈추며(카메라 보정·연출 없음), 미궁에서 되살린다. 크기가 바뀌어도 꺼진 동안은 풀지 않는다.
func test_view_stops_outside_the_labyrinth() -> void:
	var s := await _title()
	check(_view_off(s), "타이틀: 꺼짐")
	var g := s.view.guard_frames
	await kit.frames(5)
	check_eq(s.view.guard_frames, g, "타이틀: 카메라 보정 프레임 없음")
	await _press(s.title_screen, "new_game")
	check(s.state.in_town() and _view_off(s), "마을: 꺼짐")
	var root_size := tree.root.size
	tree.root.size = Vector2i(1728, 720)
	await kit.frames(3)
	check(s.view._resize_missed, "마을에서 바뀐 크기는 미뤄 둔다(보정 안 풂)")
	check_eq(s.view.guard_frames, g, "마을: 카메라 보정 프레임 없음")
	s.town_screen.handle("row", TownScreen.PLAZA_KEYS.find("entrance"))
	await kit.frames(1)
	s.town_screen.handle("row", 0)
	await kit.frames(3)
	check(not s.state.in_town() and _view_on(s), "미궁: 되살림")
	check(not s.view._resize_missed, "되살리면 미룬 크기 바뀜을 푼다")
	check_eq([s.view._pos, s.view._yaw], [DungeonMeshBuilder.cell_center(s.state.party.at), DungeonView.yaw_of(s.state.party.facing)], "시작 칸·시작 방향")
	# 미궁에서 마을로 나가면 다시 끈다.
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	check_eq(s.modal.kind, "stairs", "준비: 문 물음")
	await kit.tap(kit.center_of(s.modal.find_child("StairsYes", true, false)))
	await kit.frames(3)
	check(s.state.in_town() and _view_off(s) and not s.view.is_busy(), "마을로 나가면 다시 꺼짐(연출 없음)")
	tree.root.size = root_size
	await kit.frames(2)


## R1 (Mr1 확인 창을 키패드 뒤에 붙임, Mr1b 창이 열리고 닫힐 때 눌림을 버리지 않음): 확인 창이 떠 있어도 키패드는 실제 터치로 일한다
## (§5.1 층 5 창 · 층 6 키패드, 캠프와 같은 트리 순서). ←·→·취소·선택 모두, 창이 열리고 닫힐 때 누르고 있던 손가락은 버린다.
func test_confirm_takes_pad_touches() -> void:
	await _make_labyrinth_save()
	var s := await _title()
	var t := s.title_screen
	for p in [t.dir_pad, t.key_pad, t.key_pad_stacked]:
		check(t.dialog.get_index() < (p as Control).get_index(), "트리: 확인 창 → %s" % (p as Control).name)
	await kit.press_key(KEY_3)
	check(t.dialog.is_open() and t.dialog.pick == 0, "준비: 확인 창(「돌아가기」)")
	var pad := t.pad_state()
	check(pad["left"] and pad["right"] and pad["ok"] and pad["back"] and not pad["up"] and not pad["down"], "확인 창: ←→·선택·취소 켜짐, ↑↓ 흐림")
	await kit.tap(kit.center_of(t.dir_pad.button("right")), FINGER)
	check_eq(t.dialog.pick, 1, "키패드 → 터치 = 「새 게임」")
	await kit.tap(kit.center_of(t.dir_pad.button("left")), FINGER)
	check_eq(t.dialog.pick, 0, "키패드 ← 터치 = 「돌아가기」")
	await kit.tap(kit.center_of(t.key_pad.button("back")), FINGER)
	check(t.is_open() and not t.dialog.is_open() and s.state == null, "키패드 취소 터치 = 돌아가기(타이틀 그대로)")
	await kit.press_key(KEY_3)
	await kit.tap(kit.center_of(t.key_pad.button("ok")), FINGER)
	check(t.is_open() and not t.dialog.is_open() and s.state == null, "「돌아가기」에서 키패드 선택 터치 = 닫기만")
	# 창이 열릴 때: 커서를 새 게임 줄에 둔 채 「선택」을 누르고 키 3(창만 열림) → 눌림을 버린다 → 떼도 창을 닫지 않는다.
	check_eq(t.cursor, t.rows.find("new_game"), "준비: 커서 = 새 게임 줄")
	var ok := t.key_pad.button("ok")
	var at := kit.center_of(ok)
	kit.touch(FINGER, at, true)
	await kit.frames(2)
	check(ok.held, "준비: 키패드 「선택」 누르는 중")
	await kit.press_key(KEY_3)
	check(t.dialog.is_open() and not ok.held, "창이 열리면 눌림을 버린다")
	kit.touch(FINGER, at, false)
	await kit.frames(3)
	check(t.dialog.is_open() and t.dialog.pick == 0, "뗄 때 창 「돌아가기」를 고르지 않는다")
	# 창이 닫힐 때: 창에서 「선택」을 누른 채 Esc(닫힘) → 뗄 때 메뉴 줄(새 게임 → 창)을 고르지 않는다.
	kit.touch(FINGER, at, true)
	await kit.frames(2)
	check(ok.held, "준비: 창에서 키패드 「선택」 누르는 중")
	await kit.press_key(KEY_ESCAPE)
	check(not t.dialog.is_open() and not ok.held, "창이 닫히면 눌림을 버린다")
	var n := t.accepted_inputs
	kit.touch(FINGER, at, false)
	await kit.frames(3)
	check_eq([t.accepted_inputs, t.page, t.cursor, t.dialog.is_open(), s.state], [n, "menu", t.rows.find("new_game"), false, null],
		"뗄 때 메뉴 줄을 고르지 않는다")
	# → 뒤 선택(둘 다 터치) = 새 게임.
	await kit.press_key(KEY_3)
	await kit.tap(kit.center_of(t.dir_pad.button("right")), FINGER)
	await kit.tap(kit.center_of(t.key_pad.button("ok")), FINGER)
	check(not t.is_open() and s.state != null and s.state.in_town() and s.state.day == 1, "키패드 → · 선택 터치 = 새 게임(마을 1일째)")
	check_eq(s.autosave_count, 1, "새 게임은 저장한다")


## R3 (Mhi 가져오기 감춤 검사 빠짐 = 검토자 변이 hidden_import_accepted, Mha 자동 지도 감춤 검사 빠짐, Mhl 불러오기 감춤 검사 빠짐):
## 줄 묶음마다 보이지 않는 알약의 입력 종류는 거부되고 주인 갈고리를 부르지 않는다. 보이는 알약은 받는다(빈 슬롯 불러오기만 거부).
## 캠프 묶음은 감춘 알약이 없다(전부 보인다). 갈고리는 기록하는 가짜로 바꿔 실제 저장·파일 창을 열지 않는다.
func test_hidden_pills_reject_their_input() -> void:
	_kit()
	var s := await kit.open()
	s._save_slot("slot2")
	kit.close_screen()
	await kit.frames(1)
	s = await kit.open_title()
	var t := s.title_screen
	var rt := t.records_tab
	var calls := []
	var real: Dictionary = t.records
	t.records = {
		"slots": real["slots"],
		"automap": real["automap"],
		"save": func(id: String) -> void: calls.append(["save", id]),
		"load": func(id: String) -> void: calls.append(["load", id]),
		"export": func() -> void: calls.append(["export"]),
		"import": func() -> void: calls.append(["import"]),
		"set_automap": func(m: String) -> void: calls.append(["automap", m]),
		"new_game": func() -> void: calls.append(["new_game"]),
	}
	var pills: Array[ListButton] = []
	pills.append_array(rt.save_buttons)
	pills.append_array(rt.load_buttons)
	pills.append_array(rt.band_buttons)
	check_eq(pills.size(), 3 + 3 + 2 + ExplorationRules.AUTOMAP_MODES.size() + 1, "알약 전부(저장 셋·불러오기 셋·파일 둘·자동 지도·새 게임)")
	var hidden_seen := {}
	for rs in ["title_load", "title_settings", "camp"]:
		rt.set_rows(rs)
		rt.member_changed()
		rt.refresh()  # 슬롯을 읽는다(캠프 묶음은 상태가 없어 앞 묶음에서 읽은 그대로)
		var hidden := 0
		for b in pills:
			var kind := str(b.get_meta("kind"))
			var arg: Variant = b.get_meta("arg") if b.has_meta("arg") else null  # null 값 meta 는 지워진다(내보내기·가져오기·새 게임)
			calls.clear()
			var ok := rt.dispatch(kind, arg)
			if t.dialog.is_open():
				t.dialog.close()
			var tag := "%s: %s(%s)" % [rs, kind, str(arg)]
			if not b.visible:
				hidden += 1
				hidden_seen[kind] = true
				check(not ok and calls.is_empty(), tag + " 보이지 않으면 거부·갈고리 없음")
			elif kind == "record_load" and int(arg) != 1:
				check(not ok and calls.is_empty(), tag + " 빈 슬롯 불러오기는 거부")
			elif kind == "record_new_game":
				check(ok, tag + " 보이면 받는다(확인 창)")
			else:
				check(ok and calls.size() == 1, tag + " 보이면 받는다 %s" % str(calls))
		check_eq(hidden, {"title_load": 8, "title_settings": 9, "camp": 0}[rs], rs + ": 감춘 알약 수")
	check_eq(hidden_seen.keys().size(), 6, "감춘 알약으로 입력 종류 여섯을 모두 거부해 봤다 %s" % str(hidden_seen.keys()))
	t.records = real


## 타이틀 불러오기 쪽 「가져오기」(값이 null 인 알약)도 Enter 로 누른 것과 같다: 파일 고르기 창, 타이틀은 뒤에.
func test_enter_on_import_pill() -> void:
	var s := await _title()
	var t := s.title_screen
	await _press(t, "load")
	for i in 3:
		await kit.press_key(KEY_DOWN)
	check_eq(t.records_tab.cursor_button().name, "Import", "준비: 커서 가져오기")
	await kit.press_key(KEY_ENTER)
	check(s.modal.kind == "file" and t.is_open() and t.page == "load", "Enter 가져오기 → 파일 고르기 창(타이틀은 뒤에)")
	s._finish_file_request()
	await kit.frames(2)
	check(s.modal.kind == "" and t.is_open() and s.state == null, "파일 창 닫힘 → 타이틀 그대로")
