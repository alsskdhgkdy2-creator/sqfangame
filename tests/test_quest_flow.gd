## 의뢰의 화면 길(M3 A8a, 설계 §4.3·§5.3): 실제 행동 → 자동 저장 → 다시 열기로 본다. A8b 의 정보상 바·관리국 화면 전이라
## 받기·보고는 화면 입구 DungeonScreen.quest_action(A8b 화면이 부를 곳)으로 한다. 조정자 조건 1·2·4·5·6.
## 시험마다 죽이는 변이(M-F…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const M1 := "mission.permit_b2f"
const MOTH := "quest.moth_sweep"
const STAIR := Vector2i(17, 1)
const BEFORE_STAIR := Vector2i(16, 1)

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _arbor(query: String = "") -> Callable:
	return func(sc: DungeonScreen) -> void:
		sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		sc.url_query = query


func _auto_doc(s: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)))


## 타이틀(게임 묶음) → 「새 게임」 → 마을.
func _title_new_game(query: String = "") -> DungeonScreen:
	timeout_sec = 120.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_title("native", 7, query, _arbor(query))
	await kit.tap(kit.center_of(s.title_screen.menu_buttons["new_game"]))
	await kit.frames(2)
	return s


## 광장 → 아보르 입구 → 「탐사 시작」(실제 마을 화면 입구).
func _enter(s: DungeonScreen) -> void:
	s.town_screen.handle("row", TownScreen.PLAZA_KEYS.find("entrance"))
	await kit.frames(1)
	s.town_screen.handle("row", 0)
	await kit.frames(3)


## 시험 준비: 미궁에서 칸 c 에 방향 d 로 선다(걷는 길은 걷기 시험이 본다). 위험도 한계값은 멀리.
func _place(s: DungeonScreen, c: Vector2i, d: int) -> void:
	s.state.encounter.threshold = 99999
	s.state.party.at = c
	s.state.party.facing = d
	s.view.rebuild(s.state.world)


## F1 (조정자 조건 2, M-F1 화면 새 게임이 허가를 받음): 타이틀에서 시작한 진짜 새 게임은 마을에서 플래그 없이 시작하고, 자동 저장도 빈 flags 다.
func test_title_new_game_has_no_flags() -> void:
	var s := await _title_new_game()
	check(s.state != null and s.state.in_town(), "새 게임: 마을")
	if s.state == null:
		return
	check_eq([s.state.flags, s.debug_snapshot()["flags"], _auto_doc(s)["state"]["flags"], _auto_doc(s)["state"]["quests"]], [{}, [], [], {}], "플래그 없음(상태·스냅숏·자동 저장)")


## F2 (조정자 조건 1, M-F2 observe 가 자동 저장 뒤, M-F3 막힌 계단에서 물음이 열림(계단 사건·stair_here 의 허가 검사를 빼고 STAIRS 만 막음)): 허가 없이 계단 칸에 서면 첫 임무 도착을 세고(자동 저장에 실림)
## 물음 대신 no_permit 알림. 다시 열어도 그대로. 보고 뒤(자동 저장 한 번) 같은 칸은 보통 계단 물음을 연다.
func test_gate_and_reach_through_saves() -> void:
	var s := await _title_new_game()
	var saves := s.autosave_count
	var acc := s.quest_action("accept", M1, "council")
	check_eq([acc[0]["type"], s.autosave_count], ["quest_accepted", saves + 1], "첫 임무 받기: 자동 저장 하나")
	await _enter(s)
	check(not s.state.in_town() and s.state.floor_def.id == "b1f", "B1F 에 들어왔다")
	_place(s, BEFORE_STAIR, Dir.E)
	saves = s.autosave_count
	await kit.press_key(KEY_W)
	await kit.frames(3)
	var snap := s.debug_snapshot()
	check_eq([snap["at"], snap["modal"], snap["toast"], s.autosave_count], [[STAIR.x, STAIR.y], "", s.texts.t("msg.no_permit"), saves + 1],
		"계단 칸: 물음 없음, 「관리국의 탐사 허가가 아직 없다」, 자동 저장 하나")
	check_eq([snap["quests"][M1]["status"], snap["quests"][M1]["progress"], snap["quest_events"]], ["done", 1, [{"type": "quest_done", "quest": M1}]], "첫 임무 도착을 셌다")
	check_eq(_auto_doc(s)["state"]["quests"][M1]["progress"], 1.0, "자동 저장에 진행 1")
	s = await kit.reopen(_arbor())
	await kit.frames(2)
	check_eq([s.state.party.at, QuestRules.status_of(s.state, s.state.defs.quests.quests[M1]), s.debug_snapshot()["modal"]], [STAIR, "done", ""],
		"다시 열기: 계단 칸, 목표 달성, 물음 없음")
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_SPACE)
	await kit.frames(3)
	check_eq([s.debug_snapshot()["modal"], s.debug_snapshot()["toast"]], ["", s.texts.t("msg.no_permit")], "조사해도 물음 없이 no_permit")
	# 마을로: 문 칸 바로 앞에서 실제로 걸어 문 물음 「예」.
	_place(s, Vector2i(9, 17), Dir.S)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq(s.debug_snapshot()["modal"], "stairs", "마을 문 물음")
	await kit.click(kit.center_of(kit.modal_button(s.texts.t("ui.yes"))))
	await kit.frames(3)
	check(s.state.in_town(), "마을로 돌아왔다")
	saves = s.autosave_count
	var money := s.state.money
	var rep := s.quest_action("report", M1, "council")
	check_eq([rep.back()["type"], s.autosave_count, s.state.money, s.state.flags], ["quest_reported", saves + 1, money + 100, {"permit.b2f": true}],
		"보고: 자동 저장 하나에 돈·허가")
	s = await kit.reopen(_arbor())
	await kit.frames(2)
	check_eq([s.state.flags, s.state.money, s.quest_action("report", M1, "council")[0].get("reason")], [{"permit.b2f": true}, money + 100, "not_accepted"],
		"다시 열기: 허가·돈 그대로, 다시 보고되지 않는다")
	await _enter(s)
	_place(s, BEFORE_STAIR, Dir.E)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq([s.debug_snapshot()["at"], s.debug_snapshot()["modal"]], [[STAIR.x, STAIR.y], "stairs"], "보고 뒤 같은 칸: 보통 계단 물음")


## F3 (조정자 조건 5, M-F4 전투 제출 갈고리가 저장 뒤, M-F5 다시 연 전투에서 두 번 셈): 나방 소탕을 받은 채 전투 한가운데 저장 → 다시 열기 →
## 디버그 끝내기(제출과 같은 길). 진행은 정확히 1, 자동 저장에도 1.
func test_mid_battle_reload_counts_once() -> void:
	timeout_sec = 120.0
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7, "debug=1")
	var st := s.state
	st.enter_floor(st.defs.floors["b2f"])  # 나방 소탕의 발급 조건(B2F 를 다녀옴)
	st.enter_floor(st.defs.floors["b1f"])
	var e := QuestState.Entry.new()
	st.quests.entries[MOTH] = e
	st.encounter.danger = st.encounter.threshold
	check_eq(BattleRules.start(st, "formation.b1.rats_moth")[0]["type"], "battle_start", "준비: 나방 한 마리 무리")
	var ev: Array[Dictionary] = []
	BattleRules.damage_unit(st, st.battle.enemies[2], st.battle.enemies[2].hp, st.battle.party[0], "bash", "attack", ev, {})
	s._autosave()
	check_eq(_auto_doc(s)["state"]["quests"][MOTH]["progress"], 0.0, "전투 중 자동 저장: 진행 0")
	s = await kit.reopen(_arbor("debug=1"))
	await kit.frames(3)
	check(s.battle_layer.is_open() and s.state.battle != null, "다시 열기: 전투 층")
	var saves := s.autosave_count
	check(s.battle_layer.handle("finish", "victory"), "디버그 끝내기(제출과 같은 길)")
	await kit.frames(3)
	check_eq([s.state.quests.entry(MOTH).progress, s.autosave_count, s.quest_events],
		[1, saves + 1, [{"type": "quest_progress", "quest": MOTH, "progress": 1, "target": 4}]], "나방 하나: 1/4, 자동 저장 하나")
	check_eq(_auto_doc(s)["state"]["quests"][MOTH]["progress"], 1.0, "자동 저장에 진행 1")
	s = await kit.reopen(_arbor("debug=1"))
	await kit.frames(2)
	check_eq(s.state.quests.entry(MOTH).progress, 1, "다시 열어도 1")


## F4 (조정자 조건 6, M-F6 디버그 주소가 아니어도 받음, M-F7 모르는 플래그를 받음): quest_flag·quest 디버그 요청(JSON, 거부는 ok:false).
func test_debug_ops() -> void:
	timeout_sec = 120.0
	var s := await _title_new_game()
	check_eq(JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest_flag", "flag": "permit.b2f"}))), {"error": "debug only"}, "디버그 주소가 아니면 거부")
	check_eq(s.state.flags, {}, "그대로")
	s = await _title_new_game("debug=1")
	var saves := s.autosave_count
	for bad in ["permit.nope", 3, null, "permit.boss.x"]:
		check_eq(JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest_flag", "flag": bad}))), {"ok": false, "reason": "unknown_flag"}, "모르는 플래그 %s" % str(bad))
	check_eq([s.state.flags, s.autosave_count], [{}, saves], "거부: 바뀌지 않고 저장도 없다")
	check_eq(JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest_flag", "flag": "permit.b2f"}))), {"ok": true}, "permit.b2f")
	check_eq([s.state.flags, s.autosave_count, _auto_doc(s)["state"]["flags"]], [{"permit.b2f": true}, saves + 1, ["permit.b2f"]], "플래그·자동 저장 하나")
	check_eq(JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest_flag", "flag": "permit.b2f"}))), {"ok": false, "reason": "already"}, "두 번")
	var r: Dictionary = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest", "action": "accept", "quest": "quest.moss_soup", "giver": "council"})))
	check_eq(r, {"ok": false, "reason": "wrong_giver"}, "quest 요청 거부는 ok:false")
	r = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest", "action": "accept", "quest": "quest.moss_soup", "giver": "pub"})))
	check(r.get("ok") == true and s.state.quests.is_accepted("quest.moss_soup"), "quest 요청 받기 %s" % str(r))
	r = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "quest", "action": "fly", "quest": "quest.moss_soup", "giver": "pub"})))
	check_eq(r, {"ok": false, "reason": "bad_kind"}, "모르는 동작")
	var q: Dictionary = s.debug_snapshot()["quests"]["quest.moss_soup"]
	check_eq([q["giver"], q["status"], q["progress"], q["target"], q["reports"]], ["pub", "accepted", 0, 3, 0], "스냅숏 quests")
