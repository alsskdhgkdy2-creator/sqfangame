## 탐색 화면 장면 시험(05 §11.2, §8.4, §8.5): 실제 입력 경로로 누르고, 화면이 가진 상태·저장 파일을 본다.
## 시작 칸 (2,18) 북쪽, 시작 방은 안전 구역(위험도 0)이다. 북쪽으로 세 칸 가면 (2,15)에서 구역을 벗어난다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const A := ExplorationRules.Action
const START := Vector2i(2, 18)

var kit: Kit


func _open(platform: String = "native", query: String = "") -> DungeonScreen:
	timeout_sec = 20.0
	kit = Kit.new(tree)
	return await kit.open(platform, 7, query)


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _pad(s: DungeonScreen, action: int) -> TouchButton:
	return s.pad[action]


## 자동 저장 파일이 지금 상태와 같은 세대·같은 상태인지.
func _check_auto_matches(s: DungeonScreen, label: String) -> void:
	check_eq(kit.auto_generation(), s.state.generation, label + ": 자동 저장 세대")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), label + ": 자동 저장 내용 = 지금 상태")


## 위험도를 한계 바로 밑에 두고 북쪽으로 (2,15)까지 → 안전 구역을 벗어난 첫 걸음에 전투 대기.
func _walk_into_battle(s: DungeonScreen) -> void:
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for i in 6:
		if s.state.party.at.y <= 15:
			break
		await kit.press_key(KEY_W)


## 전투 층에서 기본 정책 명령을 많아야 turns 턴 내고(연출은 즉시), 아직 전투 중이면 디버그 요청 battle_finish(층의 입구 → 규칙의
## finish → 저장)로 끝낸 뒤 결과 창을 Enter 로 닫는다. 자연 전투가 몇 턴에 어떻게 끝나든(이어짐·승리·전멸) 같은 길이다(D15).
## 화면은 디버그 주소로 연 것이어야 한다. 돌려주는 값 = 전투 층이 부른 자동 저장 횟수(제출 + battle_finish).
func _resolve_battle(s: DungeonScreen, turns: int = 2) -> int:
	var saves := 0
	for i in turns:
		if not s.battle_layer.is_open() or s.battle_layer.phase != "command":
			break
		check(s.battle_layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT)), "정책 명령 제출")
		saves += 1
		await kit.frames(2)
	if s.battle_layer.is_open() and s.battle_layer.phase == "command":
		var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
		check(typeof(r) == TYPE_DICTIONARY and r.get("ok", false), "아직 전투 중이면 battle_finish: %s" % str(r))
		saves += 1
		await kit.frames(2)
	if s.battle_layer.is_open() and s.battle_layer.phase == "result":
		await kit.press_key(KEY_ENTER)
	return saves


func test_kit_purges_only_stale_scene_dirs() -> void:
	var stale := "user://%sstale_probe" % Kit.PREFIX
	DirAccess.make_dir_recursive_absolute(stale + "/saves")
	var f := FileAccess.open(stale + "/saves/auto.json", FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	kit = Kit.new(tree)
	check(not DirAccess.dir_exists_absolute(stale), "지난 실행의 임시 폴더를 지운다")
	check(not DirAccess.dir_exists_absolute(kit.dir), "새 폴더는 아직 없다(화면을 열 때 만든다)")
	check(Kit.is_scene_dir(kit.dir), "새 임시 폴더는 지울 수 있는 대상")
	for bad in ["user://saves", "user://", "user://settings.json", "user://test_scene_", "user://test_scene_1/../saves", "user://x/test_scene_1", "res://test_scene_1", "/tmp/test_scene_1"]:
		check(not Kit.is_scene_dir(bad), "지우면 안 되는 경로: " + bad)


func test_opens_new_game_and_autosaves() -> void:
	var s := await _open()
	check(s.state != null, "새 게임 상태")
	check_eq(s.state.party.at, START, "시작 칸")
	check_eq(s.autosave_count, 1, "새 게임 직후 자동 저장")
	_check_auto_matches(s, "새 게임")
	check(s.view.vertex_count() > 0, "시야 메시")
	check_eq(s.modal.kind, "", "창 없음")
	check_eq(s.view.camera_fov(), CameraGuard.VFOV_DEG, "카메라 시야각 = 반경 시험의 기준 시야각")
	var sz := s.view.get_viewport().get_visible_rect().size
	check(s.view.effective_aspect() <= CameraGuard.MAX_ASPECT, "기본 창의 유효 화면비 ≤ MAX_ASPECT (%s)" % sz)
	var want := CameraGuard.reach(2.0 * sqrt(2.0), 75.0, s.view.effective_aspect())
	check(is_equal_approx(s.view.guard_radius, want), "보정 반경 = 지금 시야각·화면비로 계산 (%f, %f)" % [s.view.guard_radius, want])


# ---- 입력 분리 (05 §11.2) ----

func test_key_and_pad_each_act_once() -> void:
	var s := await _open()
	await kit.press_key(KEY_W)
	check_eq(s.state.party.at, START + Vector2i(0, -1), "W 한 번 = 한 칸")
	check_eq(s.autosave_count, 2, "행동 뒤 자동 저장")
	_check_auto_matches(s, "W")
	# 터치 탭: 흉내 마우스가 함께 오지만 단추는 한 번만 받는다.
	await kit.tap(kit.center_of(_pad(s, A.TURN_RIGHT)))
	check_eq(s.state.party.facing, Dir.E, "오른쪽 회전 단추 탭 = 한 번 회전")
	# 실제 마우스 누르기.
	await kit.click(kit.center_of(_pad(s, A.TURN_LEFT)))
	check_eq(s.state.party.facing, Dir.N, "왼쪽 회전 단추 클릭 = 한 번 회전")
	await kit.press_key(KEY_UP)
	check_eq(s.state.party.at, START + Vector2i(0, -2), "↑ 키")
	check_eq(s.autosave_count, 5, "행동 넷 = 자동 저장 넷")
	check(not _pad(s, A.TURN_RIGHT).held and not _pad(s, A.TURN_LEFT).held, "뗀 뒤 눌림 없음")


func test_hold_repeats_only_after_delay() -> void:
	var s := await _open()
	kit.key(KEY_W, true)
	await kit.frames(4)
	check_eq(s.state.party.at, START + Vector2i(0, -1), "짧게 누르면 한 번(연출이 즉시 끝나도 바로 반복하지 않는다)")
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(2)
	check(s.state.party.at.y < START.y - 1, "누르고 있으면 반복 (%s)" % s.state.party.at)
	kit.key(KEY_W, false)
	await kit.frames(2)
	var at := s.state.party.at
	await kit.frames(4)
	check_eq(s.state.party.at, at, "떼면 멈춘다")
	# 이동 단추도 같다.
	s.state.party.facing = Dir.S
	var b := _pad(s, A.FORWARD)
	var p := kit.center_of(b)
	kit.touch(0, p, true)
	await kit.frames(4)
	check_eq(s.state.party.at, at + Vector2i(0, 1), "단추 짧게 = 한 번")
	kit.touch(0, p, false)
	await kit.frames(2)


func test_map_press_and_drag_onto_pad_does_not_move() -> void:
	var s := await _open()
	await kit.open_map()
	var before := kit.hash_now()
	var from := kit.map_cell(START)
	var fwd := kit.center_of(_pad(s, A.FORWARD))
	# 지도에서 누른 손가락이 이동 단추 위로 가서 뗀다: 누르기가 시작된 지도가 끝까지 가진다.
	s.map.tool = "pan"
	kit.touch(0, from, true)
	await kit.frames(1)
	kit.drag(0, from, fwd, 8)
	await kit.frames(1)
	check(not _pad(s, A.FORWARD).held, "끌고 지나간 이동 단추는 눌리지 않는다")
	kit.touch(0, fwd, false)
	await kit.frames(3)
	check_eq(s.state.party.at, START, "파티 그대로")
	check_eq(kit.hash_now(), before, "상태 그대로(이동 도구는 상태를 바꾸지 않는다)")
	check_eq(s.autosave_count, 1, "자동 저장 없음")
	# 마우스로 같은 일.
	kit.mouse(from, true)
	await kit.frames(1)
	var mm := InputEventMouseMotion.new()
	mm.position = fwd
	mm.global_position = fwd
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mm)
	Input.flush_buffered_events()
	kit.mouse(fwd, false)
	await kit.frames(3)
	check_eq(s.state.party.at, START, "마우스로 끌어도 파티 그대로")
	check(not _pad(s, A.FORWARD).held, "이동 단추 눌림 없음")


func test_pad_press_then_drag_to_map_does_not_draw() -> void:
	var s := await _open()
	await kit.open_map()
	var edges := s.state.annotation.edges.size()
	s.map.tool = "wall"
	var turn := kit.center_of(_pad(s, A.TURN_LEFT))
	var to := kit.map_edge(START, Dir.N)
	s.view.speed = 0.02  # 연출이 끝나지 않게 해 누르고 있기 반복을 막는다
	kit.touch(0, turn, true)
	await kit.frames(1)
	kit.drag(0, turn, to, 8)
	kit.touch(0, to, false)
	await kit.frames(2)
	check_eq(s.state.party.facing, Dir.W, "누른 순간 한 번 회전")
	check_eq(s.state.annotation.edges.size(), edges, "단추에서 시작한 끌기는 지도에 그리지 않는다")
	check(not s.map.is_stroking(), "지도 그리기 없음")


func test_wall_tap_toggles_exactly_once() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "wall"
	var e_pos := kit.map_edge(Vector2i(3, 17), Dir.E)
	var saves := s.autosave_count
	await kit.tap(e_pos)
	check_eq(s.state.annotation.edges.size(), 1, "터치 탭 한 번 = 벽 하나(흉내 마우스로 두 번 바뀌지 않는다)")
	check_eq(s.autosave_count, saves + 1, "지도 편집 한 단계 = 자동 저장")
	_check_auto_matches(s, "벽 탭")
	await kit.click(e_pos)
	check_eq(s.state.annotation.edges.size(), 0, "마우스 클릭 한 번 = 다시 지움")
	check_eq(s.state.party.at, START, "지도 탭은 파티를 움직이지 않는다")
	check_eq(s.autosave_count, saves + 2, "두 번째 편집 저장")


func test_second_finger_cancels_stroke() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "wall"
	var saves := s.autosave_count
	var a := kit.map_edge(Vector2i(1, 17), Dir.N)
	var b := kit.map_edge(Vector2i(4, 17), Dir.N)
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	await kit.frames(1)
	check(s.state.annotation.edges.size() >= 3, "끄는 동안 벽이 그려진다 (%d)" % s.state.annotation.edges.size())
	check(s.map.is_stroking(), "그리는 중")
	var second := kit.map_cell(Vector2i(3, 19))
	check(Rect2(Vector2.ZERO, s.map.size).has_point(s.map.geo.to_screen(Vector2(3.5, 19.5))), "준비: 두 번째 손가락도 지도 위")
	kit.touch(1, second, true)
	await kit.frames(1)
	check(not s.map.is_stroking(), "두 번째 손가락: 그리기 취소")
	check_eq(s.state.annotation.edges.size(), 0, "취소한 끌기는 되돌린다")
	kit.drag(0, b, a, 4)
	kit.touch(1, second, false)
	kit.touch(0, a, false)
	await kit.frames(3)
	check_eq(s.state.annotation.edges.size(), 0, "손가락을 모두 떼도 그리지 않는다")
	check_eq(s.state.annotation.undo_depth(), 0, "실행 취소 단계 없음")
	check_eq(s.autosave_count, saves, "자동 저장 없음")


func test_window_clears_queued_action() -> void:
	var s := await _open()
	s.view.speed = 0.02
	await kit.press_key(KEY_W)
	check(s.view.is_busy(), "이동 연출 중")
	await kit.press_key(KEY_D)
	check_eq(s._queued, A.TURN_RIGHT, "연출 중 입력은 미리 받는다")
	# 이동 연출 중에는 캠프가 열리지 않는다(07 §9.1): 창은 알림 창(층 3)을 직접 연다.
	s._alert("시험 알림")
	await kit.frames(1)
	check_eq(s.modal.kind, "alert", "알림 창 열림")
	check_eq(s._queued, -1, "창이 열리면 미리 받은 입력을 비운다")
	await kit.press_key(KEY_D)
	check_eq(s._queued, -1, "창이 열린 동안 입력을 받지 않는다")
	await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	check_eq(s.modal.kind, "", "알림 닫힘")
	s.view.speed = 0.0
	await kit.frames(3)
	check_eq(s.state.party.facing, Dir.N, "버린 회전은 일어나지 않는다")
	check_eq(s.state.party.at, START + Vector2i(0, -1), "이동 하나만")


func test_focus_loss_clears_input() -> void:
	var s := await _open()
	s.view.speed = 0.02
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_D)
	kit.touch(0, kit.center_of(_pad(s, A.FORWARD)), true)
	check(_pad(s, A.FORWARD).held, "이동 단추 눌림")
	s.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check_eq(s._queued, -1, "포커스를 잃으면 미리 받은 입력을 비운다")
	check(not _pad(s, A.FORWARD).held, "눌림 상태를 버린다")


func test_memo_dialog_swallows_movement_keys() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "memo"
	await kit.tap(kit.map_cell(Vector2i(3, 18)))
	check_eq(s.modal.kind, "memo", "메모 창 열림")
	var edit: LineEdit = s.modal.find_child("MemoEdit", true, false)
	check(edit != null, "메모 입력 칸")
	await kit.frames(1)
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_UP)
	check_eq(s.state.party.at, START, "메모 창이 열린 동안 이동하지 않는다")
	check_eq(edit.max_length, MapAnnotation.MEMO_MAX, "입력 칸 40자 제한")
	var saves := s.autosave_count
	edit.text = "  보물 상자  "
	await kit.click(kit.center_of(s.modal.find_child("MemoOk", true, false)))
	check_eq(s.modal.kind, "", "창 닫힘")
	check_eq(s.state.annotation.memos.get(Vector2i(3, 18), ""), "보물 상자", "앞뒤 공백을 지운다")
	check_eq(s.autosave_count, saves + 1, "메모 한 단계 = 자동 저장")
	# 웹 입력 창은 길이를 막지 못한다: 받은 뒤 40자로 자른다.
	s.apply_memo(Vector2i(3, 18), "가".repeat(50))
	check_eq(s.state.annotation.memos[Vector2i(3, 18)], "가".repeat(MapAnnotation.MEMO_MAX), "40자로 자른다")
	check_eq(s._toast.text, s.texts.t("msg.memo_cut"), "자른 것을 알린다")
	s.apply_memo(Vector2i(3, 18), "   ")
	check(not s.state.annotation.memos.has(Vector2i(3, 18)), "비우면 지운다")
	check_eq(s.autosave_count, saves + 3, "메모 단계마다 저장")


# ---- 불러오기·가져오기 실패는 상태를 바꾸지 않는다 (05 §8.5) ----

func test_failed_load_and_import_keep_state() -> void:
	var s := await _open()
	await kit.press_key(KEY_W)
	s.map.tool = "wall"
	await kit.tap(kit.map_edge(Vector2i(2, 17), Dir.W))
	var fp := kit.fingerprint()
	var saves := s.autosave_count
	var gen := kit.auto_generation()
	var bad := {
		"not json": "{not json",
		"wrong format": JSON.stringify({"format": "other", "schema": 1}),
		"empty": "",
	}
	for k in bad:
		check(not s.import_text(bad[k]), "가져오기 거부: " + k)
		check_eq(s.modal.kind, "alert", k + ": 알림 창")
		check_eq(kit.fingerprint(), fp, k + ": 화면 상태 그대로")
		s.modal.close()
	# 다른 층의 저장(구조는 맞음).
	var other := SaveCodec.encode(s.state).replace("\"f1_test\"", "\"f9_none\"")
	check(not s.import_text(other), "다른 층 저장 거부")
	check_eq(kit.fingerprint(), fp, "다른 층: 그대로")
	s.modal.close()
	# 1MB 넘는 글.
	check(not s.import_text("x".repeat(WebBridge.IMPORT_LIMIT + 1)), "1MB 초과 거부")
	check_eq(kit.fingerprint(), fp, "1MB 초과: 그대로")
	s.modal.close()
	# 빈 슬롯 불러오기.
	s._load_slot("slot2")
	check_eq(s.modal.kind, "alert", "빈 슬롯: 알림 창")
	check_eq(kit.fingerprint(), fp, "빈 슬롯: 그대로")
	s.modal.close()
	check_eq(s.autosave_count, saves, "실패는 자동 저장하지 않는다")
	check_eq(kit.auto_generation(), gen, "자동 저장 파일 그대로")


func test_import_replaces_state_and_late_result_is_dropped() -> void:
	var s := await _open()
	await kit.press_key(KEY_W)
	var text := SaveCodec.encode(s.state)
	var h := kit.hash_now()
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_D)
	check(kit.hash_now() != h, "준비: 상태가 바뀌었다")
	var saves := s.autosave_count
	check(s.import_text(text), "가져오기")
	check_eq(kit.hash_now(), h, "가져온 상태")
	var cam := s.view.camera_transform().origin
	var c := DungeonMeshBuilder.cell_center(START + Vector2i(0, -1))
	check(Vector2(cam.x - c.x, cam.z - c.z).length() <= CameraGuard.WIDE_LIMIT + 1e-4, "시야도 가져온 위치 (%s)" % cam)
	check_eq(s.autosave_count, saves + 1, "가져오기 직후 자동 저장")
	_check_auto_matches(s, "가져오기")
	# 웹 가져오기를 시작한 뒤 새 게임으로 넘어가면 늦게 온 결과를 버린다.
	s._import_token += 1
	s._import_epoch = s._epoch
	var token := s._import_token
	s._start_new_game()
	var fresh := kit.hash_now()
	s._on_import_result(token, "ok", text)
	check_eq(kit.hash_now(), fresh, "늦게 온 가져오기 결과는 버린다")
	# 같은 화면 세대에서 온 결과는 받는다.
	s._import_token += 1
	s._import_epoch = s._epoch
	s._on_import_result(s._import_token, "ok", text)
	check_eq(kit.hash_now(), h, "제때 온 결과는 받는다")
	s._on_import_result(s._import_token, "ok", SaveCodec.encode(ExplorationRules.new_game(s.store.defs, 3, "floor")))
	check_eq(kit.hash_now(), h, "이미 처리한 결과는 다시 받지 않는다")


# ---- 자동 저장 시점 (05 §8.4) ----

func test_autosave_call_points() -> void:
	var s := await _open("native", "debug=1")
	await kit.open_map()
	var n := s.autosave_count
	await kit.press_key(KEY_A)
	check_eq(s.autosave_count, n + 1, "규칙 행동(회전)")
	await kit.press_key(KEY_D)
	await kit.press_key(KEY_S)
	check_eq(s.state.party.at, START + Vector2i(0, 1), "준비: 남쪽 끝 칸")
	await kit.press_key(KEY_S)
	check_eq(s.state.party.at, START + Vector2i(0, 1), "준비: 남쪽은 벽")
	check_eq(s.autosave_count, n + 4, "막힌 이동도 거부가 아닌 규칙 행동")
	_check_auto_matches(s, "막힘")
	s.map.tool = "color"
	s.map.paint_color = 3
	var cell := Vector2i(1, 18)
	var old: Variant = s.state.annotation.floors.get(cell)
	await kit.tap(kit.map_cell(cell))
	check_eq(s.state.annotation.floors.get(cell), 3, "바닥 색")
	check_eq(s.autosave_count, n + 5, "지도 편집")
	await kit.tap(kit.map_cell(cell))
	check_eq(s.autosave_count, n + 5, "바뀐 것이 없는 편집은 저장하지 않는다")
	await kit.press_key(KEY_Z, true)
	check_eq(s.state.annotation.floors.get(cell), old, "Ctrl+Z 실행 취소")
	check_eq(s.autosave_count, n + 6, "실행 취소")
	_check_auto_matches(s, "실행 취소")
	await kit.tap(kit.center_of(s.toolbar.buttons["undo"]))
	check_eq(s.autosave_count, n + 6, "되돌릴 것이 없으면 저장하지 않는다")
	await _walk_into_battle(s)
	check(s.state.encounter.pending, "준비: 전투 대기")
	check(s.battle_layer.is_open(), "전투 층")
	var before := s.autosave_count
	_check_auto_matches(s, "전투 대기")
	# 거부된 행동: 전투 층이 막고, 직접 규칙에 넣어도 거부되어 저장하지 않는다.
	await kit.press_key(KEY_W)
	s._do_action(A.FORWARD)
	check_eq(s.autosave_count, before, "거부된 행동은 저장하지 않는다")
	var saves := await _resolve_battle(s)
	check(saves >= 1, "전투 턴 제출")
	check(not s.state.encounter.pending, "전투 해결")
	check(not s.battle_layer.is_open(), "전투 층 닫힘")
	check_eq(s.autosave_count, before + saves, "전투 턴 제출(·battle_finish)마다 자동 저장, 결과 창을 닫을 때는 저장하지 않음")
	_check_auto_matches(s, "전투 해결")


func test_pending_battle_is_saved_and_reopened() -> void:
	var s := await _open()
	await _walk_into_battle(s)
	check(s.battle_layer.is_open(), "전투 층")
	var h := kit.hash_now()
	s = await kit.reopen()
	check_eq(kit.hash_now(), h, "다시 열면 같은 상태")
	check(s.state.encounter.pending, "전투 대기 그대로")
	check(s.battle_layer.is_open() and s.battle_layer.phase == "command", "다시 열면 전투 층 명령 입력")
	await kit.press_key(KEY_W)
	check_eq(kit.hash_now(), h, "전투 창에서 이동하지 않는다")


func test_wiped_is_saved_and_reopened() -> void:
	var s := await _open()
	var copy := SaveCodec.decode(SaveCodec.encode(s.state), s.store.defs).state
	for m in copy.party.members:
		m.hp = 0
	copy.wiped = true
	check(s.import_text(SaveCodec.encode(copy)), "전멸 상태 가져오기")
	check_eq(s.modal.kind, "wipe", "전멸 창")
	var h := kit.hash_now()
	s = await kit.reopen()
	check(s.state.wiped, "다시 열어도 전멸")
	check_eq(kit.hash_now(), h, "같은 상태")
	check_eq(s.modal.kind, "wipe", "다시 열면 전멸 창")
	await kit.press_key(KEY_ESCAPE)
	check_eq(s.modal.kind, "wipe", "Esc 로 전멸 창을 닫지 않는다")
	await kit.click(kit.center_of(kit.modal_button(s.texts.t("wipe.new_game"))))
	check(not s.state.wiped, "새 게임")
	check_eq(s.state.party.at, START, "시작 칸")
	_check_auto_matches(s, "전멸 뒤 새 게임")


# ---- 교차 검토 묶음 1 회귀 시험 ----

## 자동 저장 파일에 적힌 벽 수.
func _auto_edges(s: DungeonScreen) -> int:
	var l := s.store.load_slot(SaveStore.AUTO)
	return l.result.state.annotation.edges.size() if l.ok() else -1


## 지도 그리기 획이 열린 동안 키·이동 단추 행동을 받지 않고, 확정하지 않은 획을 저장하지 않는다(05 §9.3, §8.4).
func test_stroke_blocks_actions_and_unsaved_stroke() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "wall"
	var saves := s.autosave_count
	var a := kit.map_edge(Vector2i(1, 17), Dir.N)
	var b := kit.map_edge(Vector2i(4, 17), Dir.N)
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	await kit.frames(1)
	check(s.map.is_stroking() and s.state.annotation.edges.size() >= 3, "준비: 그리는 중 (%d)" % s.state.annotation.edges.size())
	await kit.press_key(KEY_D)
	await kit.press_key(KEY_SPACE)
	await kit.tap(kit.center_of(_pad(s, A.TURN_RIGHT)), 1)
	check_eq(s.state.party.facing, Dir.N, "그리는 동안 키·단추 행동 없음")
	check_eq(s.state.steps, 0, "조사도 없음")
	check_eq(s._queued, -1, "미리 받지도 않는다")
	check(not s._autosave_pending, "미룬 저장도 없음")
	check_eq(s.autosave_count, saves, "그리는 동안 자동 저장 없음")
	check_eq(_auto_edges(s), 0, "자동 저장 파일에 확정하지 않은 획이 없다")
	# 두 번째 손가락으로 취소하면 저장 파일에도 남지 않는다.
	kit.touch(1, kit.map_cell(Vector2i(3, 19)), true)
	await kit.frames(1)
	kit.touch(1, kit.map_cell(Vector2i(3, 19)), false)
	kit.touch(0, b, false)
	await kit.frames(3)
	check_eq(s.state.annotation.edges.size(), 0, "취소한 획은 되돌린다")
	check_eq(_auto_edges(s), 0, "취소 뒤에도 저장 파일에 획이 없다")
	check_eq(s.autosave_count, saves, "취소는 저장하지 않는다")
	# 끝까지 그린 획은 끝난 뒤 한 번 저장한다. 손을 떼면 다시 행동을 받는다.
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	kit.touch(0, b, false)
	await kit.frames(3)
	var drawn := s.state.annotation.edges.size()
	check(drawn >= 3, "확정한 획")
	check_eq(s.autosave_count, saves + 1, "획 하나 = 저장 하나")
	check_eq(_auto_edges(s), drawn, "확정한 획만 저장")
	await kit.press_key(KEY_D)
	check_eq(s.state.party.facing, Dir.E, "손을 뗀 뒤에는 행동한다")


## 끌어 이동·핀치·아이콘 누르기 동안에도 막는다. 연출 중 미리 받은 행동과 누르고 있기 반복도 버린다.
func test_map_interaction_drops_queue_and_hold() -> void:
	var s := await _open()
	await kit.open_map()
	s.view.speed = 0.02
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_D)
	check_eq(s._queued, A.TURN_RIGHT, "준비: 연출 중 미리 받음")
	s.map.tool = "pan"
	var m := kit.map_cell(Vector2i(2, 18))
	kit.touch(0, m, true)
	await kit.frames(1)
	check(s.map.is_interacting(), "끌어 이동 중")
	await kit.press_key(KEY_A)
	check_eq(s._queued, A.TURN_RIGHT, "지도 상호작용 중 새 행동은 미리 받는 칸을 바꾸지 않는다")
	s.view.speed = 0.0
	await kit.frames(3)
	check_eq(s.state.party.facing, Dir.N, "지도를 누른 채 연출이 끝나면 미리 받은 행동을 버린다")
	check_eq(s._queued, -1, "미리 받은 칸 비움")
	# 두 손가락 핀치.
	kit.touch(1, kit.map_cell(Vector2i(4, 18)), true)
	await kit.frames(1)
	check(s.map._pinching, "준비: 핀치")
	await kit.press_key(KEY_D)
	check_eq(s.state.party.facing, Dir.N, "핀치 중 행동 없음")
	kit.touch(1, kit.map_cell(Vector2i(4, 18)), false)
	kit.touch(0, m, false)
	await kit.frames(2)
	# 아이콘 도구로 누르고 있는 동안.
	s.map.tool = "icon"
	kit.touch(0, m, true)
	await kit.frames(1)
	await kit.press_key(KEY_D)
	check_eq(s.state.party.facing, Dir.N, "아이콘 누르기 중 행동 없음")
	kit.touch(0, m, false)
	await kit.frames(2)
	# 누르고 있는 키(승인됨)도 지도를 누르면 반복하지 않는다.
	s.map.tool = "pan"
	var at := s.state.party.at
	var saves := s.autosave_count  # 막힌 입력 전 기준: 처음 받은 W 하나만 저장이 늘어야 한다
	kit.key(KEY_W, true)
	await kit.frames(1)
	check_eq(s.state.party.at, at + Vector2i(0, -1), "준비: W 한 칸")
	check_eq(s.autosave_count, saves + 1, "준비: W 저장 하나")
	kit.touch(0, m, true)
	await kit.frames(1)
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(3)
	check_eq(s.state.party.at, at + Vector2i(0, -1), "지도를 누르는 동안 누르고 있기 반복 없음")
	kit.touch(0, m, false)
	kit.key(KEY_W, false)
	await kit.frames(2)
	check_eq(s.state.party.at, at + Vector2i(0, -1), "뗀 뒤에도 그대로")
	check_eq(s.autosave_count, saves + 1, "막힌 행동은 저장하지 않는다(처음 W 하나만 저장)")


## 창이 열린 동안 누른 키는 창이 닫혀도 반복하지 않는다(05 §9.3: 승인된 키만 반복).
func test_key_pressed_in_window_does_not_repeat() -> void:
	var s := await _open()
	await kit.open_map()
	s.view.speed = 0.02
	await kit.press_key(KEY_W)
	check(s.view.is_busy(), "준비: 이동 연출 중")
	s._alert("시험 알림")
	await kit.frames(1)
	check_eq(s.modal.kind, "alert", "알림 창 열림")
	kit.key(KEY_W, true)
	await kit.frames(1)
	await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)))
	check_eq(s.modal.kind, "", "W 를 누른 채 알림 닫힘")
	s.view.speed = 0.0
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(3)
	check_eq(s.state.party.at, START + Vector2i(0, -1), "창 안에서 누른 W 는 반복하지 않는다")
	kit.key(KEY_W, false)
	await kit.frames(1)
	await kit.press_key(KEY_W)
	check_eq(s.state.party.at, START + Vector2i(0, -2), "뗐다가 다시 누르면 받는다")
	# 메모 창: 누른 채 닫아도 움직이지 않는다.
	s.view.speed = 0.02
	await kit.press_key(KEY_W)
	var at := s.state.party.at
	s.map.tool = "memo"
	await kit.tap(kit.map_cell(Vector2i(3, 18)))
	check_eq(s.modal.kind, "memo", "메모 창 열림")
	kit.key(KEY_W, true)
	await kit.frames(1)
	await kit.click(kit.center_of(s.modal.find_child("MemoCancel", true, false)))
	check_eq(s.modal.kind, "", "W 를 누른 채 메모 창 닫힘")
	s.view.speed = 0.0
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(3)
	check_eq(s.state.party.at, at, "메모 창 안에서 누른 W 는 반복하지 않는다")
	kit.key(KEY_W, false)
	await kit.frames(1)
	# 승인된 키를 누른 채 창이 열리고 닫혀도 다시 누르기 전까지 반복하지 않는다.
	kit.key(KEY_A, true)
	await kit.frames(1)
	check_eq(s.state.party.facing, Dir.W, "준비: A 회전")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check(s.modal.kind == "" and not s.party_menu.is_open(), "캠프 열고 닫음")
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(3)
	check_eq(s.state.party.facing, Dir.W, "창을 거친 키는 승인이 지워져 반복하지 않는다")
	kit.key(KEY_A, false)
	await kit.frames(1)


## 한 프레임에 행동 하나: 같은 프레임에 온 두 번째 행동은 다음 프레임에 한다.
func test_one_action_per_frame() -> void:
	var s := await _open()
	var saves := s.autosave_count
	kit.key(KEY_D, true)
	kit.touch(0, kit.center_of(_pad(s, A.TURN_LEFT)), true)
	var f := Engine.get_process_frames()
	check_eq(s.state.party.facing, Dir.E, "같은 프레임: 첫 행동만")
	check_eq(s.autosave_count, saves + 1, "같은 프레임: 저장 하나")
	check_eq(s._queued, A.TURN_LEFT, "두 번째는 미리 받는 칸")
	kit.key(KEY_D, false)
	kit.touch(0, kit.center_of(_pad(s, A.TURN_LEFT)), false)
	await kit.frames(3)
	check_eq(s.state.party.facing, Dir.N, "다음 프레임에 두 번째 행동")
	check(s._action_frame > f, "두 번째 행동은 다른 프레임 (%d > %d)" % [s._action_frame, f])
	check_eq(s.autosave_count, saves + 2, "행동 둘 = 저장 둘")
	check_eq(s._queued, -1, "미리 받은 칸 비움")
	# 연출 없는 조사 + 회전도 같다.
	kit.key(KEY_SPACE, true)
	kit.key(KEY_D, true)
	check_eq(s.state.party.facing, Dir.N, "조사한 프레임에는 회전하지 않는다")
	kit.key(KEY_SPACE, false)
	kit.key(KEY_D, false)
	await kit.frames(3)
	check_eq(s.state.party.facing, Dir.E, "회전은 다음 프레임")
	check_eq(s.autosave_count, saves + 4, "저장 넷")


func _modal_text(s: DungeonScreen) -> String:
	# 제목·묶음 머리는 문패(UiPlate), 본문은 Label.
	var out := ""
	for n in s.modal.find_children("*", "Control", true, false):
		if n is Label:
			out += (n as Label).text + "\n"
		elif n is UiPlate:
			out += (n as UiPlate).text + "\n"
	return out


## 자동 저장 실패 안내를 같은 처리의 다른 안내가 덮지 않는다(05 §8.4).
func test_autosave_failure_notice_is_not_overwritten() -> void:
	var s := await _open()
	var text := SaveCodec.encode(s.state)
	s.store.fail_points = ["write"]
	await kit.press_key(KEY_SPACE)
	check(not s.last_autosave_error.is_empty(), "준비: 자동 저장 실패")
	check_eq(s._toast.text, s.texts.t("msg.save_failed", {"reason": s.last_autosave_error}), "조사 안내보다 저장 실패 안내")
	# 불러오기·가져오기는 성공했지만 자동 저장이 실패하면 둘을 함께 알린다.
	s.store.fail_points = []
	check(s.store.save("slot1", s.state).is_empty(), "준비: 슬롯 1 저장")
	var slot_hash := SaveCodec.state_hash(s.store.load_slot("slot1").result.state)
	s.store.fail_points = ["write"]
	s._toast.text = ""
	s._load_slot("slot1")
	check_eq(kit.hash_now(), slot_hash, "불러오기는 했다")
	check_eq(s.modal.kind, "alert", "불러오기 + 저장 실패 = 알림 창")
	check(_modal_text(s).contains(s.texts.t("msg.loaded_save_failed", {"reason": s.last_autosave_error})), "불러옴·저장 실패를 함께 알린다")
	check(s._toast.text != s.texts.t("msg.loaded"), "「불러왔다」만 띄우지 않는다")
	s.modal.close()
	check(s.import_text(text), "가져오기는 한다")
	check_eq(s.modal.kind, "alert", "가져오기 + 저장 실패 = 알림 창")
	check(_modal_text(s).contains(s.texts.t("msg.imported_save_failed", {"reason": s.last_autosave_error})), "가져옴·저장 실패를 함께 알린다")
	check(s._toast.text != s.texts.t("msg.imported"), "「가져왔다」만 띄우지 않는다")
	s.modal.close()
	s.store.fail_points = []
	check(s.import_text(text), "다시 가져오기")
	check_eq(s._toast.text, s.texts.t("msg.imported"), "저장 성공이면 「가져왔다」")
	check_eq(s.modal.kind, "", "알림 창 없음")


## 네이티브 파일 고르기: 낡은 요청의 고르기·취소 콜백은 아무것도 바꾸지 않고 남의 창을 닫지 않는다(05 §8.5).
func test_stale_file_dialog_callbacks_do_nothing() -> void:
	var s := await _open()
	var good := kit.dir + "/good.json"
	var f := FileAccess.open(good, FileAccess.WRITE)
	f.store_string(SaveCodec.encode(ExplorationRules.new_game(s.store.defs, 3, "floor")))
	f.close()
	var h := kit.hash_now()
	s._import()
	var first := s._file_dialog
	check_eq(s.modal.kind, "file", "준비: 파일 고르기 창")
	s._export()
	var second := s._file_dialog
	check(first != second, "준비: 새 요청")
	first.canceled.emit()
	check_eq(s.modal.kind, "file", "낡은 취소는 새 요청의 창을 닫지 않는다")
	first.file_selected.emit(good)
	check_eq(kit.hash_now(), h, "낡은 고르기는 가져오지 않는다")
	check_eq(s.modal.kind, "file", "창 그대로")
	second.canceled.emit()
	check_eq(s.modal.kind, "", "지금 요청의 취소는 닫는다")
	second.file_selected.emit(kit.dir + "/late.json")
	check(not FileAccess.file_exists(kit.dir + "/late.json"), "끝난 요청의 고르기는 쓰지 않는다")
	# 다른 창이 그 자리를 차지했으면 닫지 않는다.
	s._import()
	var third := s._file_dialog
	s._alert("다른 알림")
	third.canceled.emit()
	check_eq(s.modal.kind, "alert", "남의 창(알림)을 닫지 않는다")
	third.file_selected.emit(good)
	check_eq(kit.hash_now(), h, "남의 창이 있을 때 고르기는 가져오지 않는다")
	s.modal.close()
	# 그사이 상태가 바뀌었으면(epoch) 버린다.
	s._import()
	var fourth := s._file_dialog
	s._epoch += 1
	fourth.file_selected.emit(good)
	check_eq(kit.hash_now(), h, "다른 epoch 의 고르기는 가져오지 않는다")
	check_eq(s.modal.kind, "file", "다른 epoch 의 콜백은 창도 닫지 않는다")
	s.modal.close()
	await kit.frames(1)


## 네이티브 내보내기·가져오기는 쓰기·읽기 뒤 오류를 보고 나서 성공을 알린다(05 §8.5).
func test_native_export_import_check_file_errors() -> void:
	var s := await _open()
	await kit.press_key(KEY_W)
	var out := kit.dir + "/export.json"
	s.file_fail_points = ["export_write"]
	s._export()
	s._file_dialog.file_selected.emit(out)
	check_eq(s.modal.kind, "alert", "쓰기 오류 = 알림 창")
	check(s._toast.text != s.texts.t("msg.exported"), "쓰기 오류면 「내보냈다」를 띄우지 않는다")
	s.modal.close()
	s.file_fail_points = []
	s._export()
	s._file_dialog.file_selected.emit(out)
	check_eq(s._toast.text, s.texts.t("msg.exported"), "정상 쓰기 = 내보냄 안내")
	var exported := SaveCodec.decode(FileAccess.get_file_as_string(out), s.store.defs)
	check(exported.ok() and SaveCodec.state_hash(exported.state) == kit.hash_now(), "내보낸 파일 = 지금 상태")
	var h := kit.hash_now()
	await kit.press_key(KEY_W)
	var moved := kit.hash_now()
	s.file_fail_points = ["import_read"]
	s._import()
	s._file_dialog.file_selected.emit(out)
	check_eq(s.modal.kind, "alert", "읽기 오류 = 알림 창")
	check(_modal_text(s).contains(s.texts.t("msg.import_error")), "가져오기 오류 안내")
	check_eq(kit.hash_now(), moved, "읽기 오류면 상태 그대로")
	s.modal.close()
	s.file_fail_points = []
	s._import()
	s._file_dialog.file_selected.emit(out)
	check_eq(kit.hash_now(), h, "정상 읽기 = 가져옴")
	check_eq(s.read_import(kit.dir + "/missing.json")["error"], "read", "없는 파일 = 읽기 실패")
	await kit.frames(1)


## 세 손가락에서 하나를 떼면 남은 두 손가락으로 핀치 기준을 다시 잡는다(확대가 튀지 않는다).
func test_pinch_rebases_when_finger_lifts() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "pan"
	var p0 := kit.map_cell(Vector2i(2, 18))
	var p1 := kit.map_cell(Vector2i(3, 18))
	var p2 := kit.map_cell(Vector2i(2, 16))
	for c in [Vector2(2.5, 18.5), Vector2(3.5, 18.5), Vector2(2.5, 16.5)]:
		check(Rect2(Vector2.ZERO, s.map.size).has_point(s.map.geo.to_screen(c)), "준비: 손가락이 지도 위 (%s)" % c)
	kit.touch(0, p0, true)
	kit.touch(1, p1, true)
	kit.touch(2, p2, true)
	await kit.frames(1)
	var px := s.map.geo.cell_px
	kit.touch(0, p0, false)
	await kit.frames(1)
	check(s.map._pinching, "두 손가락 남음 = 핀치 계속")
	kit.drag(1, p1, p1 + Vector2(0.05, 0), 1)  # 창 좌표 0.05 = 지도 몇 픽셀(시험 창이 작아 크게 늘어난다)
	await kit.frames(1)
	var ratio := s.map.geo.cell_px / px
	check(ratio > 0.95 and ratio < 1.05, "손가락이 바뀌어도 확대가 튀지 않는다 (×%f)" % ratio)
	kit.touch(1, p1, false)
	kit.touch(2, p2, false)
	await kit.frames(1)
	check(not s.map.is_interacting(), "다 떼면 상호작용 없음")


## 화면이 사라지면 웹 연결의 콜백을 놓는다(웹이 아닌 경로; 웹 전역 정리는 웹 확인이 본다).
func test_screen_exit_disposes_bridge() -> void:
	var s := await _open()
	var bridge := s.bridge
	check(bridge.has_callbacks(), "준비: 가져오기 콜백")
	kit.close_screen()
	check(not bridge.has_callbacks(), "화면이 사라지면 콜백을 놓는다")
	bridge.dispose()
	check(not bridge.has_callbacks(), "두 번 불러도 된다")


# ---- 묶음 1 재검토 반례 ----

## 검토 반례: 단추를 한 번 쓴 뒤(승인 기록) 연출 중 지도에 손가락 → 같은 단추 누름(막힘) → 지도 손가락 먼저 뗌 →
## 연출 끝. 막힌 누르기는 승인을 만들지도 앞 누르기의 승인을 다시 쓰지도 않아 반복하지 않는다.
func test_blocked_pad_press_gets_no_old_approval() -> void:
	var s := await _open()
	await kit.open_map()
	var rt := _pad(s, A.TURN_RIGHT)
	await kit.tap(kit.center_of(rt), 1)
	check_eq(s.state.party.facing, Dir.E, "준비: 단추 한 번 = 회전 하나")
	check(not s._pad_since.has(A.TURN_RIGHT), "떼면 승인을 지운다")
	s.view.speed = 0.02
	await kit.press_key(KEY_D)
	check(s.view.is_busy() and s.state.party.facing == Dir.S, "준비: 회전 연출 중")
	s.map.tool = "pan"
	var m := kit.map_cell(START)
	kit.touch(0, m, true)
	await kit.frames(1)
	check(s.map.is_interacting(), "준비: 지도에 손가락")
	kit.touch(1, kit.center_of(rt), true)
	await kit.frames(1)
	check(rt.held, "준비: 단추는 눌려 있다")
	check(not s._pad_since.has(A.TURN_RIGHT), "막힌 누르기는 승인을 만들지 않는다")
	kit.touch(0, m, false)
	await kit.frames(1)
	s.view.speed = 0.0
	await tree.create_timer(DungeonScreen.HOLD_REPEAT_MS / 1000.0 + 0.1).timeout
	await kit.frames(4)
	check_eq(s.state.party.facing, Dir.S, "막힌 누르기는 연출이 끝나도 반복하지 않는다")
	check_eq(s._queued, -1, "미리 받은 입력 없음")
	kit.touch(1, kit.center_of(rt), false)
	await kit.frames(2)
	await kit.tap(kit.center_of(rt), 1)
	check_eq(s.state.party.facing, Dir.W, "대조: 다시 누르면 받는다")


## 검토 반례: 같은 프레임 조사 + D(D 는 미리 받는 칸) → 다음 프레임 처리 전에 W. 새 요청도 미리 받는 칸을 거치고
## 나중 입력이 바꿔 W 하나만 한다(북쪽 이동 뒤 회전 같은 순서 뒤집힘 없음).
func test_queued_action_is_replaced_not_bypassed() -> void:
	var s := await _open()
	var saves := s.autosave_count
	kit.key(KEY_SPACE, true)
	kit.key(KEY_D, true)
	kit.key(KEY_SPACE, false)
	kit.key(KEY_D, false)
	check_eq(s._queued, A.TURN_RIGHT, "준비: D 는 미리 받는 칸")
	check_eq(s.autosave_count, saves + 1, "준비: 조사 저장 하나")
	await tree.process_frame  # 다음 프레임: 화면 _process 보다 먼저 입력이 온다
	kit.key(KEY_W, true)
	kit.key(KEY_W, false)
	check_eq(s.state.party.at, START, "W 는 미리 받는 칸을 건너뛰지 않는다")
	check_eq(s._queued, A.FORWARD, "나중 입력이 미리 받는 칸을 바꾼다")
	await kit.frames(4)
	check_eq(s.state.party.at, START + Vector2i(0, -1), "W 하나 = 북쪽 한 칸")
	check_eq(s.state.party.facing, Dir.N, "D 는 하지 않는다")
	check_eq(s.autosave_count, saves + 2, "조사 + W = 저장 둘")
	check_eq(s._queued, -1, "미리 받은 칸 비움")


## 검토 반례: 지도 제스처 중 도구 줄에서 도구를 바꾸면 진행 중인 제스처를 취소한다.
## 이동 도구로 누른 손가락은 바꾼 뒤 끌어도 벽을 그리지 않고, 벽 획은 지우개로 바꾸면 되돌린다. 편집·저장 없음.
func test_tool_change_cancels_map_gesture() -> void:
	var s := await _open()
	await kit.open_map()
	var edits := [0]
	s.map.edited.connect(func(_c: bool) -> void: edits[0] += 1)
	var saves := s.autosave_count
	var a := kit.map_edge(Vector2i(1, 17), Dir.N)
	var b := kit.map_edge(Vector2i(4, 17), Dir.N)
	# 1) 이동 도구로 누름 → 다른 손가락으로 「벽」 → 끌기.
	await kit.tap(kit.center_of(s.toolbar.buttons["pan"]), 1)
	check_eq(s.map.tool, "pan", "준비: 이동 도구")
	kit.touch(0, a, true)
	await kit.frames(1)
	await kit.tap(kit.center_of(s.toolbar.buttons["wall"]), 1)
	check_eq(s.map.tool, "wall", "도구 줄에서 벽으로 바꿈")
	kit.drag(0, a, b, 12)
	kit.touch(0, b, false)
	await kit.frames(3)
	check_eq(s.state.annotation.edges.size(), 0, "이동 도구로 시작한 제스처는 바꾼 도구로 그리지 않는다")
	# 2) 벽 획 중 「지우개」 → 획 취소·표시 되돌림, 계속 끌어도 지우지·그리지 않음.
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	await kit.frames(1)
	check(s.map.is_stroking() and s.state.annotation.edges.size() >= 3, "준비: 벽 획 (%d)" % s.state.annotation.edges.size())
	await kit.tap(kit.center_of(s.toolbar.buttons["eraser"]), 1)
	check_eq(s.map.tool, "eraser", "지우개로 바꿈")
	check(not s.map.is_stroking(), "획 취소")
	check_eq(s.state.annotation.edges.size(), 0, "취소한 획의 표시를 되돌린다")
	kit.drag(0, b, a, 12)
	kit.touch(0, a, false)
	await kit.frames(3)
	check_eq(s.state.annotation.edges.size(), 0, "바꾼 뒤 끌기도 아무것도 하지 않는다")
	# 3) 색 획 중 다른 색(같은 도구) → 취소. 견본 줄은 바닥 색 도구를 고르면 뜬다(M2.7 R1, 설명서 7쪽).
	await kit.tap(kit.center_of(s.toolbar.buttons["color"]), 1)
	check(s.toolbar.palette.is_visible_in_tree(), "바닥 색 도구 → 견본 줄")
	await kit.tap(kit.center_of(s.toolbar.buttons["color1"]), 1)
	var f0: Dictionary = s.state.annotation.floors.duplicate()
	var c0 := kit.map_cell(Vector2i(2, 17))
	var c1 := kit.map_cell(Vector2i(4, 17))
	kit.touch(0, c0, true)
	kit.drag(0, c0, c1, 8)
	await kit.frames(1)
	check(s.state.annotation.floors != f0, "준비: 색 획")
	await kit.tap(kit.center_of(s.toolbar.buttons["color2"]), 1)
	check_eq(s.state.annotation.floors, f0, "색을 바꾸면 색 획 취소")
	kit.touch(0, c1, false)
	await kit.frames(3)
	check_eq(s.state.annotation.floors, f0, "떼도 칠하지 않는다")
	check_eq(s.state.annotation.undo_depth(), 0, "실행 취소 단계 없음")
	check_eq(edits[0], 0, "edited 신호 없음")
	check_eq(s.autosave_count, saves, "자동 저장 없음")
	check(not s.map.is_interacting(), "다 떼면 상호작용 없음")
	# 대조: 바꾸지 않으면 그린다.
	await kit.tap(kit.center_of(s.toolbar.buttons["wall"]), 1)
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	kit.touch(0, b, false)
	await kit.frames(3)
	check(s.state.annotation.edges.size() >= 3, "대조: 벽 획 확정")
	check_eq(s.autosave_count, saves + 1, "대조: 저장 하나")


## 획이 열린 동안 미룬 자동 저장: 획을 끝내면 저장 하나(획 포함), 두 번째 손가락으로 취소하면 획 없는 상태를 저장 하나.
func test_deferred_autosave_on_stroke_end_and_cancel() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "wall"
	var a := kit.map_edge(Vector2i(1, 17), Dir.N)
	var b := kit.map_edge(Vector2i(4, 17), Dir.N)
	# 끝내기.
	var saves := s.autosave_count
	kit.touch(0, a, true)
	kit.drag(0, a, b, 12)
	await kit.frames(1)
	check(s._autosave(), "획 중 자동 저장 요청")
	check(s._autosave_pending, "획 중에는 미룬다")
	await kit.frames(2)
	check_eq(s.autosave_count, saves, "획 중에는 저장하지 않는다")
	check_eq(_auto_edges(s), 0, "파일에 확정하지 않은 획 없음")
	kit.touch(0, b, false)
	await kit.frames(3)
	var drawn := s.state.annotation.edges.size()
	check(drawn >= 3, "준비: 획 확정 (%d)" % drawn)
	check_eq(s.autosave_count, saves + 1, "획 끝 = 저장 하나(미룬 저장과 편집 저장이 겹치지 않는다)")
	check(not s._autosave_pending, "미룬 저장 비움")
	check_eq(_auto_edges(s), drawn, "파일 = 확정한 획")
	_check_auto_matches(s, "획 끝")
	# 취소.
	saves = s.autosave_count
	var c := kit.map_edge(Vector2i(1, 16), Dir.N)
	var d := kit.map_edge(Vector2i(4, 16), Dir.N)
	kit.touch(0, c, true)
	kit.drag(0, c, d, 12)
	await kit.frames(1)
	check(s.state.annotation.edges.size() > drawn, "준비: 두 번째 획")
	s._autosave()
	check(s._autosave_pending, "획 중에는 미룬다")
	var second := kit.map_cell(Vector2i(3, 19))
	kit.touch(1, second, true)
	await kit.frames(2)
	check(not s.map.is_stroking(), "두 번째 손가락: 획 취소")
	check_eq(s.autosave_count, saves + 1, "취소 뒤 미룬 저장 하나")
	check_eq(_auto_edges(s), drawn, "저장 = 취소한 획이 없는 상태")
	_check_auto_matches(s, "획 취소")
	kit.touch(1, second, false)
	kit.touch(0, d, false)
	await kit.frames(3)
	check_eq(s.autosave_count, saves + 1, "손가락을 떼도 더 저장하지 않는다")


## 핀치 손가락이 바뀌어도 지도 중심이 튀지 않는다(세 손가락 중 하나를 떼고 남은 둘로 아주 조금 끌기).
func test_pinch_finger_swap_keeps_center() -> void:
	var s := await _open()
	await kit.open_map()
	s.map.tool = "pan"
	var p0 := kit.map_cell(Vector2i(2, 18))
	var p1 := kit.map_cell(Vector2i(3, 18))
	var p2 := kit.map_cell(Vector2i(2, 16))
	kit.touch(0, p0, true)
	kit.touch(1, p1, true)
	kit.touch(2, p2, true)
	await kit.frames(1)
	var probe := Vector2(2.5, 17.5)
	var before := s.map.geo.to_screen(probe)
	var px := s.map.geo.cell_px
	kit.touch(0, p0, false)
	await kit.frames(1)
	check(s.map._pinching, "두 손가락 남음 = 핀치 계속")
	kit.drag(1, p1, p1 + Vector2(0.05, 0), 1)
	await kit.frames(1)
	var moved := s.map.geo.to_screen(probe).distance_to(before)
	check(moved < px * 0.25, "손가락이 바뀌어도 지도 중심이 튀지 않는다 (%.2f px, 칸 %.1f px)" % [moved, px])
	kit.touch(1, p1, false)
	kit.touch(2, p2, false)
	await kit.frames(1)


## 웹 확인용 hash_save: 저장 글의 상태 해시·세대 = 화면 상태 요약의 해시·세대.
func test_debug_hash_save_matches_snapshot() -> void:
	var s := await _open()
	await kit.press_key(KEY_W)
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "hash_save", "text": SaveCodec.encode(s.state)})))
	var snap := s.debug_snapshot()
	check(typeof(r) == TYPE_DICTIONARY and r.get("hash") == snap["hash"] and int(r.get("generation", -1)) == int(snap["generation"]), "hash_save = 상태 요약 (%s)" % str(r))
	var bad: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "hash_save", "text": "{"})))
	check(typeof(bad) == TYPE_DICTIONARY and bad.has("error"), "깨진 글 = 오류")


# ---- 성장 (07 §8.6·§9.5·§10.1, G-B2) ----

func _req(s: DungeonScreen, req: Dictionary) -> Dictionary:
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify(req)))
	return r if typeof(r) == TYPE_DICTIONARY else {}


## 탐색 화면에는 파티 상태 칸이 없다(원작: 상태는 캠프·전투에서, M2.7 R1). StatusPanel 부품은 그대로 레벨을 보인다.
func test_status_panel_shows_level_and_updates_after_level_up() -> void:
	var s := await _open("native", "debug=1")
	check(s.find_children("*", "StatusPanel", true, false).is_empty(), "탐색 화면에 상태 칸 없음")
	var names: Array[String] = []
	for k in s.party_data.name_keys:
		names.append(s.texts.t(k))
	var st := StatusPanel.new()
	st.set_state(s.state, s.texts, names)
	check_eq(st.level_text(1), "Lv 1", "대원 칸의 「Lv 1」")
	var r := _req(s, {"op": "grant_exp", "member": 1, "n": s.state.defs.battle.growth.cum(3)})
	check(r.get("ok", false), "grant_exp: %s" % str(r))
	st.refresh()
	check_eq(st.level_text(1), "Lv 3", "레벨업 뒤 「Lv 3」")
	check_eq(st.level_text(0), "Lv 1", "다른 대원 그대로")
	st.free()


func test_debug_supply_and_grant_exp_requests_autosave() -> void:
	var s := await _open("native", "debug=1")
	var n := s.autosave_count
	var r := _req(s, {"op": "supply", "item": "equip.ion_saber", "n": 2})
	check(r.get("ok", false), "supply: %s" % str(r))
	check_eq(s.state.gear_bag.get("equip.ion_saber", 0), 2, "가방 +2")
	check_eq(s.autosave_count, n + 1, "자동 저장")
	_check_auto_matches(s, "supply")
	var h := kit.hash_now()
	for bad in [{"op": "supply", "item": "equip.nope", "n": 1}, {"op": "supply", "item": "equip.ion_saber", "n": 0},
			{"op": "grant_exp", "member": 9, "n": 10}, {"op": "grant_exp", "member": 0, "n": 0}, {"op": "grant_exp", "member": true, "n": 10}]:
		r = _req(s, bad)
		check(not r.get("ok", true) and r.has("reason"), "거부 %s → %s" % [str(bad), str(r)])
	check_eq(kit.hash_now(), h, "거부는 상태를 바꾸지 않는다")
	check_eq(s.autosave_count, n + 1, "거부는 저장하지 않는다")
	r = _req(s, {"op": "grant_exp", "member": 0, "n": 30})
	check(r.get("ok", false) and s.state.party.members[0].level == 2, "grant_exp → Lv 2: %s" % str(r))
	check_eq(s.autosave_count, n + 2, "자동 저장")
	_check_auto_matches(s, "grant_exp")
	s._debug = false  # 디버그 주소가 아닌 화면과 같은 갈림
	r = _req(s, {"op": "supply", "item": "equip.ion_saber", "n": 1})
	check_eq(r.get("error"), "debug only", "supply 는 디버그 주소에서만")
	r = _req(s, {"op": "grant_exp", "member": 0, "n": 1})
	check_eq(r.get("error"), "debug only", "grant_exp 는 디버그 주소에서만")
	check_eq(s.autosave_count, n + 2, "저장 없음")


func test_snapshot_lists_party_menu_buttons_and_growth_fields() -> void:
	var s := await _open("native", "debug=1")
	var snap := s.debug_snapshot()
	check(snap["buttons"].has("CampButton") and snap["buttons"].has("Pad_forward"), "닫혀 있으면 탐색 단추")
	check_eq(snap["party_menu"], {"open": false}, "메뉴 닫힘")
	var m1: Dictionary = snap["members"][1]
	for k in ["level", "exp", "sp_left", "skills", "equip", "stats", "gear", "max_hp", "max_tp", "weapon", "attack_element"]:
		check(m1.has(k), "대원 필드 " + k)
	check_eq([m1["level"], m1["sp_left"], m1["weapon"], m1["attack_element"]], [1, 0, "equip.twin_edge", "slash"], "듀얼리스트 A 값")
	check(snap.has("gear_bag"), "가방")
	await kit.press_key(KEY_P)
	snap = s.debug_snapshot()
	var b: Dictionary = snap["buttons"]
	check(b.has("Camp_status") and b.has("Camp_records") and not b.has("Camp_close") and not b.has("Member_0"), "열려 있으면 캠프 명령 줄 다섯(카드는 고르기 때만): %s" % str(b.keys()))
	check(b.has("VPad_back") and b.has("VPad_ok") and b.has("VPad_up") and not b.has("VPad_left"), "키패드: 켜진 단추만(뿌리 ←→ 흐림): %s" % str(b.keys()))
	check_eq(snap["party_menu"]["pad"], {"up": true, "down": true, "left": false, "right": false, "ok": true, "back": true}, "키패드 상태 필드")
	check(not b.has("Pad_forward") and not b.has("MapButton") and not b.has("CampButton") and not b.has("Tool_wall"), "덮인 탐색 단추는 내지 않는다")
	check_eq([snap["party_menu"]["open"], snap["party_menu"]["page"], snap["party_menu"]["tab"], snap["party_menu"]["member"]], [true, "root", "", 0], "메뉴 필드")
	check(not snap["party_menu"].has("banner"), "설명 띠 없음(07 §9.8 ③)")
	check_eq([snap["party_menu"]["ribbon"], snap["party_menu"]["money"], snap["party_menu"]["notice"]],
		[s.texts.t("floor.f1_test") + " / B1F", s.texts.t("shop.money", {"money": ShopRow.grouped(s.state.money)}), ""], "장소 띠·소지금·알림 줄")
	await kit.press_key(KEY_2)
	snap = s.debug_snapshot()
	check(snap["buttons"].has("Member_0") and snap["buttons"].has("VPad_back") and snap["buttons"].has("Camp_equip") and snap["buttons"].has("Camp_records"),
		"고르기: 카드와 명령 줄 모두(고르기 중에도 다른 명령으로 바꿀 수 있다)")
	check_eq([snap["party_menu"]["page"], snap["party_menu"]["pick"], snap["party_menu"]["camp_cursor"]], ["pick", "status", PartyMenu.CAMP_KEYS.find("status")], "고르기 필드(2 = 상태)")
	await kit.press_key(KEY_ENTER)
	snap = s.debug_snapshot()
	check_eq([snap["party_menu"]["page"], snap["party_menu"]["tab"]], ["sub", "status"], "상태 화면")
	check(snap["buttons"].has("VPad_back") and snap["buttons"].has("StatusNext") and not snap["buttons"].has("StatusBack"), "상태 화면 단추(「뒤로」 없음, 키패드 「취소」)")
	check_eq(snap["party_menu"]["backdrop"], "board", "하위 화면 바탕도 무늬 판")
	s._on_debug_request(JSON.stringify({"op": "grant_exp", "member": 1, "n": 115}))
	await kit.press_key(KEY_4)
	await kit.press_key(KEY_E)
	await kit.tap(kit.center_of(s.party_menu.skill_tab.plus_button))
	await kit.press_key(KEY_F)
	snap = s.debug_snapshot()
	var pm: Dictionary = snap["party_menu"]
	check_eq([pm["tab"], pm["member"], pm["draft"], pm["dialog"], pm["dialog_pick"]], ["skills", 1, {"skill.blade_duelist.high_slash": 1}, "commit", 0], "초안·확인 창·고른 단추")
	check_eq(pm["sp_line"], "남은 SP 2 → 1", "남은 SP 줄(초안 뒤)")
	check(snap["buttons"].has("DialogOk") and snap["buttons"].has("DialogBack") and not snap["buttons"].has("Tab_status"), "확인 창이 떠 있으면 그 단추만")
	await kit.press_key(KEY_ESCAPE)
	snap = s.debug_snapshot()
	check(snap["party_menu"]["nodes"].has("skill.blade_duelist.leg_cutter"), "트리 노드 좌표(스킬 ID)")
	var p: Array = snap["party_menu"]["nodes"]["skill.blade_duelist.high_slash"]
	check_eq(p, s._css(s.party_menu.skill_tab.nodes[0].size / 2.0, s.party_menu.skill_tab.nodes[0]), "노드 좌표 = 노드 가운데")


func test_debug_battle_finish_refused_without_living_ally_changes_nothing() -> void:
	var s := await _open("native", "debug=1")
	await _walk_into_battle(s)
	check(s.battle_layer.is_open() and s.state.battle != null, "준비: 전투")
	for u in s.state.battle.party:
		u.hp = 0  # 살아 있는 아군 없음(구성): 승리 끝내기는 규칙이 거부한다(07 §3.4)
	var h := kit.hash_now()
	var n := s.autosave_count
	var gen := kit.auto_generation()
	var r := _req(s, {"op": "battle_finish"})
	await kit.frames(3)
	check_eq(r.get("ok"), false, "battle_finish 거부: %s" % str(r))
	check_eq(kit.hash_now(), h, "상태 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	check_eq(kit.auto_generation(), gen, "저장 파일 세대 그대로")
	check(s.battle_layer.phase == "command" and s.state.encounter.pending and not s.state.wiped, "전투 그대로(결과 창·전멸 없음)")


## 웹 확인 승리 경로의 고정 저장(tools/web_check_victory_save.json, 07 §10.5 7)이 지금 정의로 읽히고 고정 조건을 지키는지.
## 데이터가 바뀌어 이 시험이 실패하면 고정 저장을 다시 만든다(조건은 web_check.mjs 머리말과 같다).
func test_web_check_victory_save_fixture() -> void:
	var s := await _open("native", "debug=1")
	var text := FileAccess.get_file_as_string("res://tools/web_check_victory_save.json")
	var r := SaveCodec.decode(text, s.store.defs)
	check(r.ok(), "3판 저장으로 읽힌다: %s" % (r.error if not r.ok() else ""))
	if not r.ok():
		return
	var st := r.state
	var b := st.battle
	check(b != null and b.formation == "formation.f1.rats" and st.encounter.pending, "편성 formation.f1.rats 전투 중")
	for j in 2:
		check(b.enemies[j].hp == 0 and not b.enemies[j].kill.is_empty() and int(b.enemies[j].kill["turn"]) <= b.turn, "쥐 %d: HP 0·처치 기록" % j)
	check(b.enemies[2].hp > 0 and b.enemies[2].kill.is_empty() and b.enemies[2].charging.is_empty(), "쥐 2: 살아 있음·처치 기록 없음·준비 없음")
	for i in st.party.members.size():
		var m := st.party.members[i]
		check(m.hp == m.max_hp and m.tp == m.max_tp, "대원 %d HP·TP 가득" % i)
		check_eq(m.exp, st.defs.battle.growth.cum(2) - 4 if i == 1 else 0, "대원 %d exp" % i)
	for u in b.party + b.enemies:
		check(u.ailment.is_empty() and u.binds.is_empty() and u.buffs.is_empty() and u.debuffs.is_empty() and u.resist_acc.is_empty(), "유닛 상태 깨끗")
	var events: Array[Dictionary] = []
	check(BattleRules.finish(st, "victory", events), "finish(victory)")
	var end: Dictionary = events.filter(func(e: Dictionary) -> bool: return e["type"] == "battle_end")[0]
	check_eq([end["exp_total"], end["exp_alive"], end["exp_share"]], [24, 5, 4], "E 24·n 5·몫 4")
	s.battle_layer.state = st
	var lines := s.battle_layer.growth_lines(end)
	check_eq(lines, ["경험치 +4", "레벨 업", "듀얼리스트 A  Lv 1 → 2  SP +1"] as Array[String], "결과 창 줄")
