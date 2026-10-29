## 계단 화면(M3 A1): 계단을 밟으면 확인 창(층 3, 「예」 먼저), 「예」면 층을 바꾸고 시야·지도·층 문패를 다시 맞추고 자동 저장,
## 「아니오」·Esc·Backspace 면 그대로. 키와 단추, 전투가 난 걸음, 지도 판, 장소 글이 실제 글꼴에서 잘리지 않는지.
## f1_test 내려가는 계단 (15,17), 내려설 칸 (14,17). f2_test 올라가는 계단 (0,0), 동쪽을 본다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const STAIR := Vector2i(15, 17)
const BESIDE := Vector2i(14, 17)

var kit: Kit


func _open(query: String = "") -> DungeonScreen:
	timeout_sec = 30.0
	kit = Kit.new(tree)
	return await kit.open("native", 7, query)


func teardown() -> void:
	if kit != null:
		kit.dispose()


## 계단 옆 (14,17)에서 동쪽(계단 쪽)을 보고 서게 하고(위험도 한계 큼) 화면을 그 상태로 맞춘다.
func _beside_stairs(s: DungeonScreen) -> void:
	s.state.party.at = BESIDE
	s.state.party.facing = Dir.E
	s.state.encounter.threshold = 99999
	s._set_state(s.state)
	await kit.frames(2)


## 앞으로 걸어 계단을 밟는다(실제 키 경로).
func _step_on(s: DungeonScreen) -> void:
	await kit.press_key(KEY_W)
	await kit.frames(3)


func _focus(s: DungeonScreen) -> Control:
	return s.get_viewport().gui_get_focus_owner()


func _key_event(code: int, pressed: bool, echo: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	Input.parse_input_event(k)
	Input.flush_buffered_events()


## U1 (M17 확인 창 없음, M18 첫 포커스 없음): 계단을 밟으면 연출 뒤 확인 창, 「예」에 포커스.
func test_step_onto_stairs_opens_prompt() -> void:
	var s := await _open()
	await _beside_stairs(s)
	await _step_on(s)
	check_eq([s.state.party.at, s.state.floor_def.id], [STAIR, "f1_test"], "계단 칸, 층 그대로")
	check_eq(s.modal.kind, "stairs", "계단 확인 창")
	check_eq(s.modal.title_plate.text, s.texts.t("stairs.title"), "제목 문패")
	var labels := s.modal.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.has(s.texts.t("stairs.ask_down")), "내려가는 물음 %s" % str(labels))
	var yes := s.modal.find_child("StairsYes", true, false) as Button
	var no := s.modal.find_child("StairsNo", true, false) as Button
	check(yes != null and no != null and yes.text == "예" and no.text == "아니오", "「예」「아니오」")
	check_eq(_focus(s), yes, "처음 커서는 「예」(D25)")
	check(yes.size.y >= 64.0 and no.size.y >= 64.0, "단추 높이 64 이상")
	check_eq(s.layers["Modal"].layer, DungeonScreen.LAYER_MODAL, "층 3 창")
	check(s._input_blocked(), "창이 열린 동안 이동 막힘")
	check_eq(s.debug_snapshot()["modal"], "stairs", "스냅숏 modal")
	check(s.debug_snapshot()["buttons"].has("StairsYes"), "스냅숏 단추")


## U2: 「아니오」는 닫기만 한다(층·칸·방향 그대로, 저장 없음).
func test_no_keeps_party_on_stairs() -> void:
	var s := await _open()
	await _beside_stairs(s)
	await _step_on(s)
	var saves := s.autosave_count
	var h := kit.hash_now()
	await kit.click(kit.center_of(s.modal.find_child("StairsNo", true, false)))
	check_eq(s.modal.kind, "", "창 닫힘")
	check_eq([s.state.floor_def.id, s.state.party.at, s.state.party.facing, s.autosave_count, kit.hash_now()], ["f1_test", STAIR, Dir.E, saves, h], "그대로, 저장 없음")
	check(not s._input_blocked(), "다시 움직일 수 있다")


## U3 (M19 시야를 새 층으로 다시 만들지 않음): 「예」면 f2 계단 칸, 층 문패·지도 문패·알림 줄, 시야·지도 판, 자동 저장, 다시 열어도 f2.
func test_yes_changes_floor_and_view() -> void:
	var s := await _open()
	await _beside_stairs(s)
	await _step_on(s)
	var saves := s.autosave_count
	var danger := s.state.encounter.danger
	var steps := s.state.steps
	await kit.click(kit.center_of(s.modal.find_child("StairsYes", true, false)))
	await kit.frames(3)
	check_eq(s.modal.kind, "", "창 닫힘")
	check_eq([s.state.floor_def.id, s.state.party.at, s.state.party.facing], ["f2_test", Vector2i(0, 0), Dir.E], "f2 계단 칸, 동쪽")
	check_eq([s.state.steps, s.state.encounter.danger], [steps, danger], "걸음·위험도 그대로")
	check_eq(s._floor_label.text, "시험 층 2 / B2F", "층 문패 장소 글")
	check_eq(s.toolbar.floor_plate.text, "B2F", "지도 판 층 문패")
	check_eq(s._toast.text, "시험 층 2 / B2F", "알림 줄")
	check_eq(s.view._floor, s.state.floor_def, "시야가 f2")
	check_eq(s.floor_def, s.state.floor_def, "화면이 보는 층")
	check_eq([s.map.geo.width, s.map.geo.height, s.map.state == s.state], [5, 3, true], "지도 판 f2 크기")
	check_eq(s.debug_snapshot()["floor"], "f2_test", "스냅숏 floor")
	check_eq(s.autosave_count, saves + 1, "층 바꾸기 자동 저장")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and l.result.state.floor_def.id == "f2_test" and SaveCodec.state_hash(l.result.state) == kit.hash_now(), "자동 저장 = 지금 상태(f2)")
	# 내려섰다 다시 밟으면 위로 올라가는 물음.
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	await kit.frames(3)
	check_eq(s.modal.kind, "stairs", "다시 밟으면 확인 창")
	var labels := s.modal.find_children("*", "Label", true, false).map(func(x: Label) -> String: return x.text)
	check(labels.has(s.texts.t("stairs.ask_up")), "올라가는 물음")
	await kit.click(kit.center_of(s.modal.find_child("StairsNo", true, false)))
	s = await kit.reopen()
	check_eq([s.state.floor_def.id, s._floor_label.text, s.toolbar.floor_plate.text, s.view._floor.id], ["f2_test", "시험 층 2 / B2F", "B2F", "f2_test"], "다시 열어도 f2")
	check_eq(s.modal.kind, "", "다시 열 때는 묻지 않는다(조사로 다시 묻는다)")
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "stairs", "계단 위 조사로 확인 창")


## U4 (M20 Esc 를 받지 않음): Enter·Space = 「예」, Esc·Backspace = 「아니오」, 방향 키로 커서를 옮긴다.
func test_keys_answer_prompt() -> void:
	var s := await _open()
	for x in [[KEY_ESCAPE, "f1_test"], [KEY_BACKSPACE, "f1_test"], [KEY_ENTER, "f2_test"]]:
		await _beside_stairs(s)
		await _step_on(s)
		check_eq(s.modal.kind, "stairs", "%s: 준비 창" % OS.get_keycode_string(x[0]))
		await kit.press_key(x[0])
		await kit.frames(3)
		check_eq([s.modal.kind, s.state.floor_def.id], ["", x[1]], "%s → %s" % [OS.get_keycode_string(x[0]), x[1]])
		check(not s.party_menu.is_open(), "%s: 캠프는 열리지 않는다" % OS.get_keycode_string(x[0]))
		if s.state.floor_def.id != "f1_test":
			s.state.floor_def = s.state.defs.first_floor()
			s._set_state(s.state)
	# Space(조사 키이기도 하다) = 「예」.
	await _beside_stairs(s)
	await _step_on(s)
	await kit.press_key(KEY_SPACE)
	await kit.frames(3)
	check_eq(s.state.floor_def.id, "f2_test", "Space → 예")
	s.state.floor_def = s.state.defs.first_floor()
	# 방향 키로 「아니오」에 커서를 옮기고 Enter.
	await _beside_stairs(s)
	await _step_on(s)
	await kit.press_key(KEY_RIGHT)
	check_eq(_focus(s), s.modal.find_child("StairsNo", true, false), "→ 로 「아니오」")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([s.modal.kind, s.state.floor_def.id, s.state.party.at], ["", "f1_test", STAIR], "「아니오」 커서 + Enter")


## U4 (M21 반복 입력으로 고름): 눌린 채 반복된 Space 와, 창이 뜨기 전부터 누르고 있던 키를 떼는 것은 고르지 않는다.
## 창을 닫은 뒤에도 누르고 있던 키는 다른 행동(회전)의 연출이 끝난 뒤 반복되지 않는다(M21: _key_since 를 지우지 않음).
func test_held_keys_do_not_answer() -> void:
	var s := await _open()
	await _beside_stairs(s)
	s.state.party.at = STAIR
	s._set_state(s.state)
	# 계단 위에서 Space(조사)를 누른 채 → 창이 뜬다 → 반복 Space → 뗀다.
	_key_event(KEY_SPACE, true)
	await kit.frames(3)
	check_eq(s.modal.kind, "stairs", "조사로 창")
	for i in 3:
		_key_event(KEY_SPACE, true, true)
		await kit.frames(1)
	_key_event(KEY_SPACE, false)
	await kit.frames(3)
	check_eq([s.modal.kind, s.state.floor_def.id], ["stairs", "f1_test"], "반복·뗌으로 고르지 않음")
	await kit.press_key(KEY_ESCAPE)
	# W 를 누른 채 계단을 밟고, 창을 Esc 로 닫은 뒤에도 W 는 반복되지 않는다(뗐다가 다시 눌러야 한다).
	await _beside_stairs(s)
	kit.key(KEY_W, true)
	await kit.frames(3)
	check_eq(s.modal.kind, "stairs", "W 로 밟고 창")
	await kit.press_key(KEY_ESCAPE)
	await tree.create_timer(0.4).timeout
	await kit.frames(3)
	check_eq(s.state.party.at, STAIR, "누르고 있던 W 로 움직이지 않음")
	# W 를 계속 누른 채(반복 지연 220ms 를 넘겼다) A 로 돈다: 회전 연출이 끝나도 W 는 반복되지 않는다(창이 지운 키는 다시 눌러야 한다).
	var steps := s.state.steps
	await kit.press_key(KEY_A)
	await tree.create_timer(0.3).timeout
	await kit.frames(4)
	check_eq([s.state.party.at, s.state.party.facing, s.state.steps], [STAIR, Dir.N, steps], "회전 뒤에도 누르고 있던 W 로 움직이지 않음")
	kit.key(KEY_W, false)
	await kit.frames(2)


## U4b (리뷰): 이동 연출 중(연출 속도 1)에 지도 손짓(마우스 오른쪽 끌기·한 손가락 터치)을 시작해도 계단 물음을 버리지 않는다.
## 연출이 끝나면 창이 뜨고, 창이 지도 손짓을 취소한다(05 §9.3). 연출 중에 미리 받은 회전·누르고 있던 W 는 물음을 건너뛰지 않는다.
func test_map_gesture_during_move_keeps_prompt() -> void:
	var s := await _open()
	for by_touch in [false, true]:
		var how := "터치" if by_touch else "마우스"
		await _beside_stairs(s)
		if not s._map_open:
			await kit.open_map()
		s.view.speed = 1.0
		kit.key(KEY_W, true)
		check(s.view.is_busy() and s.state.party.at == STAIR, "%s: 준비 — 계단으로 걷는 연출 중" % how)
		var marks: int = s.state.annotation.floors.size()  # 걸음의 자동 바닥 색까지 든 뒤
		await kit.press_key(KEY_D)  # 연출 중이라 미리 받는 칸에 들어간다
		var pos := kit.center_of(s.map)
		if by_touch:
			kit.touch(3, pos, true)
		else:
			kit.mouse(pos, true, MOUSE_BUTTON_RIGHT)
		check(s.view.is_busy() and s.map.is_interacting(), "%s: 준비 — 연출 중에 지도 손짓 시작" % how)
		for i in 120:
			if not s.view.is_busy():
				break
			await kit.frames(1)
		await kit.frames(3)
		check_eq([s.modal.kind, s.map.is_interacting()], ["stairs", false], "%s: 연출이 끝나면 계단 창, 지도 손짓 취소" % how)
		check_eq([s.state.party.at, s.state.party.facing], [STAIR, Dir.E], "%s: 미리 받은 D·누르고 있던 W 가 물음을 건너뛰지 않음" % how)
		if by_touch:
			kit.touch(3, pos, false)
		else:
			kit.mouse(pos, false, MOUSE_BUTTON_RIGHT)
		kit.key(KEY_W, false)
		await kit.frames(3)
		check_eq([s.modal.kind, s.state.party.at, s.state.party.facing], ["stairs", STAIR, Dir.E], "%s: 손을 떼도 창 그대로" % how)
		check_eq(s.state.annotation.floors.size(), marks, "%s: 취소된 손짓은 지도 표시를 바꾸지 않음" % how)
		s.view.speed = 0.0
		await kit.press_key(KEY_ESCAPE)
		await kit.frames(2)
		check_eq([s.modal.kind, s.state.party.at, s.state.floor_def.id], ["", STAIR, "f1_test"], "%s: 「아니오」" % how)


## U4c (리뷰): 이동 연출 중에 다른 창(지도 메모 창)이 열려 연출 끝에 계단 창을 띄울 수 없으면 물음을 남겨 두고, 그 창이 닫힌 뒤 띄운다.
func test_prompt_waits_for_other_window() -> void:
	var s := await _open()
	await _beside_stairs(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	check(s.view.is_busy() and s.state.party.at == STAIR, "준비 — 계단으로 걷는 연출 중")
	s._on_memo_requested(BESIDE)  # 지도 메모 도구가 여는 창(PC)
	for i in 120:
		if not s.view.is_busy():
			break
		await kit.frames(1)
	await kit.frames(3)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "메모 창이 열린 동안 물음은 남는다")
	await kit.click(kit.center_of(s.modal.find_child("MemoCancel", true, false)))
	await kit.frames(3)
	check_eq([s.modal.kind, s.state.party.at, s.state.floor_def.id], ["stairs", STAIR, "f1_test"], "메모 창을 닫으면 계단 창")
	check_eq(_focus(s), s.modal.find_child("StairsYes", true, false), "「예」에 포커스")


## U4d (리뷰 2): 메모 창 뒤에 남은 물음 — 「취소」 클릭과 같은 입력 묶음(프레임을 넘기기 전)에 온 이동·회전 키는
## 미뤄 둔 다시 보기보다 먼저 와도 물음을 낡게 만들지 못한다: 그 요청 대신 계단 창이 한 번 뜨고 파티는 그대로.
func test_input_right_after_closing_blocker_cannot_skip_prompt() -> void:
	var s := await _open()
	var opened := [0]
	s.modal.opened.connect(func(kind: String) -> void:
		if kind == "stairs":
			opened[0] += 1)
	for x in [[KEY_S, "S(뒤로)"], [KEY_A, "A(회전)"]]:
		var how: String = x[1]
		await _beside_stairs(s)
		opened[0] = 0
		s.view.speed = 1.0
		await kit.press_key(KEY_W)
		s._on_memo_requested(BESIDE)
		for i in 120:
			if not s.view.is_busy():
				break
			await kit.frames(1)
		await kit.frames(2)
		check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "%s: 준비 — 메모 창 뒤에 물음" % how)
		var steps := s.state.steps
		var at := kit.center_of(s.modal.find_child("MemoCancel", true, false))
		kit.mouse(at, true)
		kit.mouse(at, false)
		check_eq(s.modal.kind, "", "%s: 준비 — 메모 창 닫힘, 다시 보기는 아직" % how)
		kit.key(x[0], true)
		kit.key(x[0], false)
		await tree.create_timer(0.4).timeout
		await kit.frames(4)
		check_eq([s.modal.kind, opened[0], s.state.party.at, s.state.party.facing, s.state.steps], ["stairs", 1, STAIR, Dir.E, steps], "%s: 키 대신 계단 창 하나, 파티 그대로" % how)
		s.view.speed = 0.0
		await kit.press_key(KEY_ESCAPE)
		await kit.frames(2)


## U5: 계단을 밟은 걸음에 전투가 나면 확인 창을 띄우지 않고, 전투 뒤 계단 위 조사로 묻는다.
func test_battle_on_stair_step_then_investigate() -> void:
	var s := await _open("debug=1")
	await _beside_stairs(s)
	s.state.encounter.threshold = s.state.encounter.danger + 1
	await _step_on(s)
	check(s.battle_layer.is_open() and s.modal.kind == "", "전투 층, 계단 창 없음")
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
	check(typeof(r) == TYPE_DICTIONARY and r.get("ok", false), "battle_finish %s" % str(r))
	await kit.frames(2)
	if s.battle_layer.is_open():
		await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(not s.battle_layer.is_open() and s.modal.kind == "", "전투 뒤에도 묻지 않음")
	check_eq(s.state.party.at, STAIR, "계단 위")
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "stairs", "조사로 확인 창")


## U6: 지도 판을 연 채 층을 바꾸면 판은 열린 채 새 층을 보이고, 실행 취소는 새 층 그림만 본다.
func test_map_panel_follows_floor_change() -> void:
	var s := await _open()
	await _beside_stairs(s)
	await kit.open_map()
	s.state.annotation.begin_stroke()
	s.state.annotation.paint_floor(BESIDE, 3)
	s.state.annotation.end_stroke()
	await _step_on(s)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s.state.floor_def.id, "f2_test", "준비: f2")
	check(s._map_open and s.map_window.is_visible_in_tree(), "지도 판 열린 채")
	check_eq([s.map.geo.width, s.map.geo.height, s.map.state.annotation == s.state.floor_states["f2_test"].annotation], [5, 3, true], "지도 판이 f2 기록")
	check(not s.map.undo(), "f2 에는 되돌릴 것이 없다(f1 그림은 f1 의 실행 취소 기록)")
	check_eq(s.state.floor_states["f1_test"].annotation.floors.get(BESIDE), 3, "f1 그림 그대로")


## U7: 장소 글이 네 자리에 실제 글꼴로 잘리지 않는다 — 층 묶음의 모든 층 이름(자료에서 읽는다, A3 의 진짜 층 이름도 덮는다).
## 탐색 층 문패(22px), 캠프 장소 띠(28px), 기록 슬롯 둘째 줄(16px, 걸음 99999·실제 시각 꼴), 지도 판 층 문패(15px, 층 표시만).
func test_place_text_fits_everywhere() -> void:
	var s := await _open()
	var defs := s.state.defs
	var font := s._floor_label.get_theme_font("font")
	s._save_slot("slot1")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_6)
	await kit.frames(2)
	var pm := s.party_menu
	var rt := pm.records_tab
	check(pm.is_open() and pm.ribbon.is_visible_in_tree(), "준비: 캠프 기록")
	var time_text: String = rt.card_lines(0)[2]
	check(not time_text.is_empty(), "준비: 슬롯 시각")
	var line_w := RecordsTab_label_room()
	var fails := []
	for id in defs.floor_ids:
		var f := defs.floor_by_id(id)
		var place := FloorNames.place(s.texts, defs, f)
		var label := FloorNames.label(s.texts, defs, f)
		var plate_w := font.get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var plate_room := DungeonScreen.PLATE_SIZE.x - 2.0 * s._floor_label.position.x
		var ribbon_w := pm.ribbon.get_theme_default_font().get_string_size(place, HORIZONTAL_ALIGNMENT_LEFT, -1, PlaceRibbon.FS).x
		var slot := "%s   %s" % [s.texts.t("menu.slot_where", {"floor": place, "steps": 99999}), time_text]
		var slot_w := rt.window.get_theme_default_font().get_string_size(slot, HORIZONTAL_ALIGNMENT_LEFT, -1, ListParts.OPT_LABEL_SUB_FS).x
		var tag_w := s.toolbar.floor_plate.get_theme_default_font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, MapToolbar.FloorTag.FS).x
		var tag_room := s.toolbar.floor_plate.size.x - 8.0
		for x in [["탐색 층 문패", plate_w, plate_room], ["캠프 장소 띠", ribbon_w, pm.ribbon.text_width()], ["기록 슬롯 줄", slot_w, line_w], ["지도 판 층 문패", tag_w, tag_room]]:
			print("글 맞춤 %s %s: %.1f / %.1f" % [id, x[0], x[1], x[2]])
			if x[1] > x[2]:
				fails.append("%s %s %.1f > %.1f" % [id, x[0], x[1], x[2]])
	check_eq(fails, [], "모든 층 이름이 네 자리에 든다")


## 기록 슬롯 이름 알약 글 폭(알약 폭 − 양쪽 여백).
static func RecordsTab_label_room() -> float:
	return PartyRecordsTab.LABEL_W - 2.0 * ListParts.OPT_LABEL_PAD
