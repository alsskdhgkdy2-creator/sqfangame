## 전멸 뒤 지도 남기기(M3 A2b, 설계 §4.6): TownRules.keep_map 과 전멸 창 → 지도 물음 → 마을.
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(설계 노트 §7.4, M…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const V5 := preload("res://tests/test_save_v5.gd")

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _ann(r: FloorState) -> Dictionary:
	return SaveCodec.floor_state_to_dict(r)["annotation"]


func _rest(r: FloorState) -> Array:
	var d := SaveCodec.floor_state_to_dict(r)
	return [d["world"], d["knowledge"]]


## W1 (Mi2 방문 기록도 복사함, Mj2 더한 층이 지금 층이 됨): 전멸 쪽 지도 그림이 층마다 이긴다. 대상에만 있는 층은 그대로, 전멸 쪽에만 있는
## 층은 그림만 더하고 지금 층은 바뀌지 않는다. 세계·방문 기록은 대상 것. 결과는 저장 검사를 지난다(찾은 통로의 겉모습 검사).
func test_keep_map_rules() -> void:
	var v5 := V5.new()
	var wiped := v5._two_floors()
	var defs := wiped.defs
	check_eq([wiped.floor_def.id, wiped.floor_states.keys()], ["f2_test", ["f1_test", "f2_test"]], "준비: 전멸 쪽 두 층(f2 에 찾은 통로·메모)")
	var wf1: FloorState = wiped.floor_states["f1_test"]
	wf1.annotation.floors[Vector2i(3, 17)] = 2
	wf1.annotation.set_memo(Vector2i(2, 16), "전멸 쪽")
	var wiped_hash := SaveCodec.state_hash(wiped)
	# 가: 대상 = 마을 새 게임(f1 만, 다른 그림). 전멸 쪽 f1 그림이 대상 f1 그림을 바꾸고 f2 는 그림만 더한다.
	var target := ExplorationRules.new_game(defs, 9, "full", true)
	var tf1: FloorState = target.floor_states["f1_test"]
	tf1.annotation.floors[Vector2i(5, 5)] = 4
	tf1.annotation.set_memo(Vector2i(6, 6), "대상 쪽")
	var tf1_rest := _rest(tf1)
	TownRules.keep_map(target, wiped)
	check_eq(target.floor_states.keys(), ["f1_test", "f2_test"], "가: 전멸 쪽에만 있던 f2 기록을 더한다")
	check_eq([target.floor_def.id, target.in_town(), target.party.at], ["f1_test", true, defs.first_floor().start_at], "가: 지금 층·장소·위치는 그대로")
	check_eq(_ann(target.floor_states["f1_test"]), _ann(wf1), "가: f1 그림 = 전멸 쪽(대상 쪽 그림은 사라진다)")
	check_eq(_rest(target.floor_states["f1_test"]), tf1_rest, "가: f1 세계·방문 기록은 대상 것")
	var tf2: FloorState = target.floor_states["f2_test"]
	check_eq(_ann(tf2), _ann(wiped.floor_states["f2_test"]), "가: f2 그림 = 전멸 쪽(메모 「아래층」)")
	check_eq(_rest(tf2), [{"passages_found": [], "shortcuts_open": [], "locks_open": [], "chests_opened": []}, {"edges": {}, "visited": []}], "가: 더한 f2 의 세계·방문 기록은 비었다")
	var r := SaveCodec.decode(SaveCodec.encode(target), defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(target), "가: 저장 → 읽기 같은 해시 %s" % r.error)
	check_eq(SaveCodec.state_hash(wiped), wiped_hash, "가: 전멸 쪽 상태는 그대로")
	tf2.annotation.set_memo(Vector2i(0, 0), "고침")
	check(not wiped.floor_states["f2_test"].annotation.memos.has(Vector2i(0, 0)), "가: 복사본이라 고쳐도 전멸 쪽은 그대로")
	# 나: 대상 = 두 층(f2 에 있음), 전멸 쪽 = 마을 새 게임(f1 만). 대상 f2 는 그대로, f1 그림만 바뀐다.
	var target2 := v5._two_floors()
	var t2f2 := _ann(target2.floor_states["f2_test"])
	var t2f2_rest := _rest(target2.floor_states["f2_test"])
	var wiped2 := ExplorationRules.new_game(defs, 9, "full", true)
	wiped2.floor_states["f1_test"].annotation.set_memo(Vector2i(1, 1), "새 게임 쪽")
	TownRules.keep_map(target2, wiped2)
	check_eq([target2.floor_def.id, target2.floor_states.keys()], ["f2_test", ["f1_test", "f2_test"]], "나: 지금 층 f2·층 기록 둘 그대로")
	check_eq([_ann(target2.floor_states["f2_test"]), _rest(target2.floor_states["f2_test"])], [t2f2, t2f2_rest], "나: 대상에만 있는 층(f2)은 그대로")
	check_eq(target2.floor_states["f1_test"].annotation.memos, {Vector2i(1, 1): "새 게임 쪽"}, "나: f1 그림 = 전멸 쪽")
	r = SaveCodec.decode(SaveCodec.encode(target2), defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(target2), "나: 저장 → 읽기 같은 해시 %s" % r.error)


## 지금 상태를 전멸로 만들어(미궁 B1F, 전멸 표시·모두 HP 0, f1 에 메모) 가져온다 → 전멸 창.
func _import_wiped(s: DungeonScreen, memo: String) -> void:
	var copy := SaveCodec.decode(SaveCodec.encode(s.state), s.store.defs).state
	if copy.in_town():
		ExplorationRules.apply(copy, ExplorationRules.Action.ENTER, "full")
	for m in copy.party.members:
		m.hp = 0
	copy.wiped = true
	copy.floor_states["f1_test"].annotation.set_memo(Vector2i(2, 16), memo)
	check(s.import_text(SaveCodec.encode(copy)), "준비: 전멸 상태 가져오기")
	await kit.frames(2)


func _button(s: DungeonScreen, n: String) -> Button:
	return s.modal.find_child(n, true, false) as Button


## W2 (Mk2 지도 물음을 건너뜀): 수동 저장이 없으면 「처음부터」만 → 지도 물음(포커스 「예」, Esc 없음, 답하기 전 상태 그대로) → 「예」 = 마을 새 게임에
## 전멸 쪽 그림. 물음 중 새로 고침 → 타이틀 → 이어하기 → 전멸 창. 숙소에서 기록한 슬롯이 있으면 「마지막 기록으로 돌아간다」 → 물음 →
## 「예」 = 전멸 쪽 그림을 남긴 광장·저장 +1, 「아니오」 = 슬롯 그림 그대로.
func test_wipe_window_asks_about_the_map() -> void:
	timeout_sec = 90.0
	kit = Kit.new(tree)
	var s := await kit.open_town()
	await _import_wiped(s, "그린 지도")
	check_eq(s.modal.kind, "wipe", "전멸 창")
	check(_button(s, "WipeLoad") == null and _button(s, "WipeNewGame") != null, "수동 저장이 없으면 「처음부터」만")
	check_eq(_button(s, "WipeNewGame").text, s.texts.t("wipe.new_game"), "「처음부터」")
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.tap(kit.center_of(_button(s, "WipeNewGame")))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "「처음부터」 → 지도 물음")
	check_eq(s.modal.title_plate.text, s.texts.t("wipe.map_title"), "물음 제목")
	check_eq(s.get_viewport().gui_get_focus_owner(), _button(s, "WipeMapYes"), "처음 포커스 「예」")
	check_eq([kit.hash_now(), s.autosave_count, s.state.wiped], [h, saves, true], "답하기 전에는 상태·저장 그대로")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_BACKSPACE)
	check_eq([s.modal.kind, s.party_menu.is_open()], ["wipe_map", false], "Esc·Backspace 로 닫히지 않는다")
	# 물음 중 새로 고침: 자동 저장은 전멸 그대로 → 타이틀 이어하기 → 전멸 창.
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.start_mode = "title")
	check(s.title_screen.is_open() and s.title_screen.can_continue, "새로 고침 → 타이틀(이어하기)")
	await kit.tap(kit.center_of(s.title_screen.menu_buttons["continue"]))
	await kit.frames(2)
	check(s.state != null and s.state.wiped and s.modal.kind == "wipe", "이어하기 → 전멸 창 다시")
	await kit.tap(kit.center_of(_button(s, "WipeNewGame")))
	await kit.frames(2)
	saves = s.autosave_count
	await kit.tap(kit.center_of(_button(s, "WipeMapYes")))
	await kit.frames(2)
	check(not s.state.wiped and s.state.in_town() and s.state.day == 1 and s.town_screen.is_open() and s.town_screen.page == "plaza",
		"「예」 → 마을 새 게임(1일째) 광장")
	check_eq(s.state.floor_states["f1_test"].annotation.memos.get(Vector2i(2, 16), ""), "그린 지도", "전멸 쪽 그림을 남긴다")
	check_eq([s.modal.kind, s.autosave_count], ["", saves + 1], "물음 닫힘, 자동 저장 +1")
	# 숙소에서 기록 → 미궁 → 전멸 → 「마지막 기록으로 돌아간다」.
	s.state.floor_states["f1_test"].annotation.memos.clear()  # 슬롯 그림은 비운다(「아니오」 확인용)
	s._save_slot("slot1")
	var slot_hash := kit.hash_now()
	await _import_wiped(s, "두 번째 지도")
	check(_button(s, "WipeLoad") != null, "수동 저장이 있으면 「마지막 기록으로 돌아간다」")
	check_eq(_button(s, "WipeLoad").text, s.texts.t("wipe.load_manual"), "「마지막 기록으로 돌아간다」")
	await kit.tap(kit.center_of(_button(s, "WipeLoad")))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "불러오기 → 지도 물음")
	check(s.state.wiped, "답하기 전에는 전멸 상태 그대로")
	saves = s.autosave_count
	await kit.tap(kit.center_of(_button(s, "WipeMapNo")))
	await kit.frames(2)
	check(not s.state.wiped and s.state.in_town() and s.town_screen.is_open() and s.town_screen.page == "plaza", "「아니오」 → 기록한 마을(광장)")
	check_eq([kit.hash_now(), s.state.floor_states["f1_test"].annotation.memos], [slot_hash, {}], "「아니오」: 슬롯 그대로(그림도)")
	check_eq([s.autosave_count, s._toast.text], [saves + 1, s.texts.t("msg.loaded")], "자동 저장 +1, 불러옴 안내")
	await _import_wiped(s, "세 번째 지도")
	await kit.tap(kit.center_of(_button(s, "WipeLoad")))
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)  # 포커스 「예」
	await kit.frames(2)
	check(not s.state.wiped and s.state.in_town(), "Enter(「예」) → 마을")
	check_eq(s.state.floor_states["f1_test"].annotation.memos, {Vector2i(2, 16): "세 번째 지도"}, "「예」: 전멸 쪽 그림")
	var auto := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.store.defs)
	check(auto.ok() and SaveCodec.state_hash(auto.state) == kit.hash_now(), "자동 저장 = 남긴 상태")


## W2 (실패): 슬롯이 그사이 깨졌으면 알림만, 전멸 상태 그대로(물음 없음).
func test_wipe_load_fails_before_asking() -> void:
	timeout_sec = 60.0
	kit = Kit.new(tree)
	var s := await kit.open_town()
	s._save_slot("slot1")
	await _import_wiped(s, "지도")
	var main := s.store.main_path("slot1")
	for other in [main.get_basename() + ".tmp", main.get_basename() + ".bak"]:
		if FileAccess.file_exists(other):
			DirAccess.remove_absolute(other)
	var f := FileAccess.open(main, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var h := kit.hash_now()
	await kit.tap(kit.center_of(_button(s, "WipeLoad")))
	await kit.frames(2)
	check_eq(s.modal.kind, "alert", "깨진 슬롯 → 알림(물음 없음)")
	check_eq([kit.hash_now(), s.state.wiped], [h, true], "전멸 상태 그대로")


## L2 리뷰 고침(Mq1 지도 물음이 알림 줄을 남김, Mq2 전멸 창이 알림 줄을 남김, Mq3 저장 실패 안내까지 지움): 층 3 물음 창(전멸 창·지도 물음,
## 계단·마을 문과 같은 _open_question)이 뜨면 화면 아래쪽 알림 줄(층 4: 「가져왔다」 같은 안내)을 지운다. 저장 실패 안내는 남긴다.
func test_questions_clear_ordinary_toasts() -> void:
	timeout_sec = 60.0
	kit = Kit.new(tree)
	var s := await kit.open_town()
	await _import_wiped(s, "지도")
	check_eq(s.modal.kind, "wipe", "준비: 전멸 창")
	check(s._toast_left <= 0.0 and s._toast.modulate.a == 0.0, "전멸 창이 뜨면 「가져왔다」 안내를 지운다")
	s._show_toast(s.texts.t("msg.imported"))
	check(s._toast.modulate.a > 0.9, "준비: 전멸 창 위로 안내가 다시 보인다")
	await kit.tap(kit.center_of(_button(s, "WipeNewGame")))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "준비: 지도 물음")
	check(s._toast_left <= 0.0 and s._toast.modulate.a == 0.0, "지도 물음이 뜨면 안내를 지운다")
	await kit.frames(3)
	check_eq(s._toast.modulate.a, 0.0, "다시 나타나지 않는다")
	await kit.tap(kit.center_of(_button(s, "WipeMapNo")))
	await kit.frames(2)
	# 저장 실패 안내는 남는다: 전멸 창(가져오기 뒤 자동 저장 실패는 알림 창이라 안내로 직접 띄운다) → 지도 물음.
	await _import_wiped(s, "지도 둘")
	var why := "시험 실패"
	s._show_toast(s.texts.t("msg.save_failed", {"reason": why}), true)
	await kit.tap(kit.center_of(_button(s, "WipeNewGame")))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "준비: 다시 지도 물음")
	check(s._toast.text == s.texts.t("msg.save_failed", {"reason": why}) and s._toast.modulate.a > 0.9, "저장 실패 안내는 물음이 떠도 남는다")
