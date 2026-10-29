## 의뢰 탐색 안내(M3 A8b, 설계 §6.5·§8 A8b F1~F3): B1F 탐사 허가 계단에서 임무 안내가 허가 안내를 이긴다, 허가가 없으면 허가 안내·물음 없음,
## 허가가 있으면 보통 계단 물음, 전투가 센 의뢰 안내는 전투 층이 닫힌 뒤, 전멸이면 안내 없음. 실제 걷기 → 자동 저장 → 다시 열기(교훈 1).
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(M-F…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const M1 := "mission.permit_b2f"
const MOTH := "quest.moth_sweep"
const STAIR := Vector2i(17, 1)
const BEFORE_STAIR := Vector2i(16, 1)

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null


func _arbor(query: String = "") -> Callable:
	return func(sc: DungeonScreen) -> void:
		sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		sc.url_query = query
		sc.native_debug = false


## 게임 묶음 마을에서 시작해 광장 → 아보르 입구 → 「탐사 시작」(실제 마을 화면 입구)으로 B1F 에 들어간다. prep 은 들어가기 전 마을 상태에.
func _enter_b1f(prep: Callable = Callable(), query: String = "") -> DungeonScreen:
	timeout_sec = 150.0
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_town("native", 7, query, _arbor(query))
	if prep.is_valid():
		prep.call(s)
	s.town_screen.handle("row", TownScreen.PLAZA_KEYS.find("entrance"))
	await kit.frames(1)
	s.town_screen.handle("row", 0)
	await kit.frames(3)
	check(not s.state.in_town() and s.state.floor_def.id == "b1f", "준비: B1F")
	return s


## 시험 준비: 칸 c 에 방향 d 로 선다(걷는 길은 걷기 시험이 본다). 위험도 한계값은 멀리.
func _place(s: DungeonScreen, c: Vector2i, d: int) -> void:
	s.state.encounter.threshold = 99999
	s.state.party.at = c
	s.state.party.facing = d
	s.view.rebuild(s.state.world)


func _mission_note(s: DungeonScreen) -> String:
	return s.texts.t("quest.note.done.council", {"quest": s.texts.t("quest.permit_b2f")})


## F1 (M-F1 의뢰 안내를 묶음 안내보다 먼저 띄움: 허가 안내에 덮인다), F3 (M-F3 진행 세기가 자동 저장 뒤: 다시 열면 진행이 없다):
## 첫 임무를 받은 채 B1F 계단 칸에 실제로 걸어 서면 안내는 임무 달성 안내(허가 안내가 아니다), 물음 없음, 자동 저장 하나에 진행 1.
## 다시 열어도 목표 달성. 그 칸에서 조사하면 이번에는 허가 안내.
func test_mission_notice_wins_over_the_gate_notice() -> void:
	var s := await _enter_b1f(func(sc: DungeonScreen) -> void:
		check_eq(sc.quest_action("accept", M1, "council")[0]["type"], "quest_accepted", "준비: 첫 임무 받기"))
	_place(s, BEFORE_STAIR, Dir.E)
	var n := s.autosave_count
	await kit.press_key(KEY_W)
	await kit.frames(3)
	var snap := s.debug_snapshot()
	check_eq([snap["at"], snap["modal"], snap["toast"], s.autosave_count], [[STAIR.x, STAIR.y], "", _mission_note(s), n + 1],
		"계단 칸: 임무 달성 안내가 이긴다, 물음 없음, 자동 저장 하나")
	s = await kit.reopen(_arbor())
	await kit.frames(2)
	check_eq([s.state.party.at, s.state.quests.entry(M1).progress, s.debug_snapshot()["modal"]], [STAIR, 1, ""], "다시 열기: 계단 칸, 진행 1, 물음 없음")
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_SPACE)
	await kit.frames(3)
	check_eq([s.debug_snapshot()["toast"], s.debug_snapshot()["modal"]], [s.texts.t("msg.no_permit"), ""], "조사: 허가 안내, 물음 없음")


## 첫 임무 없이 계단 칸에 서면 허가 안내만(물음 없음, 의뢰 안내 없음). 허가가 있으면 같은 걸음이 보통 계단 물음을 연다.
func test_gate_notice_without_the_mission_and_stairs_with_the_permit() -> void:
	var s := await _enter_b1f()
	_place(s, BEFORE_STAIR, Dir.E)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq([s.debug_snapshot()["at"], s.debug_snapshot()["toast"], s.debug_snapshot()["modal"], s.quest_events],
		[[STAIR.x, STAIR.y], s.texts.t("msg.no_permit"), "", [] as Array[Dictionary]], "허가 없음: 허가 안내, 물음 없음")
	kit.dispose()
	s = await _enter_b1f(func(sc: DungeonScreen) -> void: sc.state.flags["permit.b2f"] = true)
	_place(s, BEFORE_STAIR, Dir.E)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq(s.debug_snapshot()["modal"], "stairs", "허가가 있으면 보통 계단 물음")


## F2 (M-F2 전투 안내를 전투 동안 띄움): 나방 소탕을 받은 채 나방 무리 전투를 이긴다(디버그 끝내기 = 제출과 같은 길). 결과 창이 떠 있는 동안
## 안내 줄은 의뢰 안내가 아니고, 「확인」으로 전투 층이 닫힌 뒤 「케이블 나방 소탕: 1/4」.
func test_battle_notice_shows_after_the_battle_closes() -> void:
	var s := await _enter_b1f(func(sc: DungeonScreen) -> void:
		var st := sc.state
		st.enter_floor(st.defs.floors["b2f"])
		st.enter_floor(st.defs.first_floor())
		st.location = ExplorationState.TOWN
		check_eq(sc.quest_action("accept", MOTH, "pub")[0]["type"], "quest_accepted", "준비: 나방 소탕 받기"), "debug=1")
	var st := s.state
	st.encounter.danger = st.encounter.threshold
	check_eq(BattleRules.start(st, "formation.b1.rats_moth")[0]["type"], "battle_start", "준비: 나방 한 마리 무리")
	var ev: Array[Dictionary] = []
	BattleRules.damage_unit(st, st.battle.enemies[2], st.battle.enemies[2].hp, st.battle.party[0], "bash", "attack", ev, {})
	s._autosave()
	s = await kit.reopen(_arbor("debug=1"))
	await kit.frames(3)
	check(s.battle_layer.is_open(), "준비: 전투 층")
	var note := s.texts.t("quest.note.progress", {"quest": s.texts.t("quest.moth_sweep"), "n": 1, "target": 4})
	check(s.battle_layer.handle("finish", "victory"), "디버그 끝내기")
	await kit.frames(3)
	check_eq([s.battle_layer.is_open(), s.state.quests.entry(MOTH).progress], [true, 1], "결과 창: 전투 층은 열려 있고 진행 1")
	check(s.debug_snapshot()["toast"] != note and s._toast.text != note, "전투 동안 의뢰 안내를 띄우지 않는다")
	var t0 := Time.get_ticks_msec()
	while s.battle_layer.phase != "result" and Time.get_ticks_msec() - t0 < 10000:
		await kit.frames(1)
	var ok := s.battle_layer.find_child("ResultOk", true, false) as TouchButton
	check(ok != null and ok.is_visible_in_tree(), "「확인」 단추")
	await kit.tap(kit.center_of(ok))
	await kit.frames(2)
	check_eq([s.battle_layer.is_open(), s.debug_snapshot()["toast"]], [false, note], "닫힌 뒤: 「케이블 나방 소탕: 1/4」")


## 전멸이면 안내가 없다: 들고 있던 의뢰 안내(앞 제출이 센 것)가 있어도 전멸로 닫히면 띄우지 않는다.
func test_no_notice_on_a_wipe() -> void:
	var s := await _enter_b1f(Callable(), "debug=1")
	var st := s.state
	st.encounter.danger = st.encounter.threshold
	check_eq(BattleRules.start(st, "formation.b1.rats_moth")[0]["type"], "battle_start", "준비: 전투")
	s._autosave()
	s = await kit.reopen(_arbor("debug=1"))
	await kit.frames(3)
	s._battle_quest_note = "의뢰 안내(시험)"
	for u in s.state.battle.party:
		u.hp = 0  # 전멸 끝내기는 대원이 모두 쓰러졌을 때만 받는다
	check(s.battle_layer.handle("finish", "wiped"), "디버그 끝내기: 전멸")
	var t0 := Time.get_ticks_msec()
	while s.battle_layer.is_open() and Time.get_ticks_msec() - t0 < 10000:
		await kit.frames(1)
	await kit.frames(2)
	check(s.state.wiped and not s.battle_layer.is_open(), "전멸로 닫혔다")
	check(s.debug_snapshot()["toast"] != "의뢰 안내(시험)" and s._battle_quest_note.is_empty(), "전멸: 의뢰 안내를 띄우지 않고 버린다")
