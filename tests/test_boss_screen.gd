## 보스의 화면 — M3 A9a 임시 상태(설계 §9.1, 조정자 조건 3). A9a 는 규칙·자료·저장만 단다: 화면은 봉인이 열리면 다시 그리고 알림을 띄우며,
## 플래그를 가진 채 봉인에 뒤·옆으로 부딪히면 seal_closed 알림이다. boss 이벤트(보스에 부딪힘·조사)는 아직 아무것도 보이지 않고(창·알림 없음),
## FIGHT 단추·키는 없다(규칙 행동으로만 열린다, 열리면 있는 전투 대기 길로 전투 층이 뜬다). A9b 가 보스 물음 창·FIGHT·클리어 상자를 달며 이 파일을 넓힌다.
## 실제 미궁(open_arbor) B3F 봉인 앞 (9,2). 얻는 길은 실제 키 → 자동 저장 → 문서로 본다. 시험마다 죽이는 변이(M-V…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const SEAL := Vector3i(9, 2, 1)

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()


## B3F 칸 at·facing 에 선 미궁 화면. flag 면 permit.boss, open 이면 봉인이 열렸다.
func _open(at: Vector2i, facing: int, flag: bool, open: bool = false) -> DungeonScreen:
	timeout_sec = 90.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7)
	Fx.to_floor(s.state, "b3f", at, facing)
	s.state.encounter.threshold = 99999
	if flag:
		s.state.flags["permit.boss"] = true
	if open:
		s.state.world.open_lock(SEAL)
	s._set_state(s.state)
	await kit.frames(2)
	return s


func _auto_doc(s: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)))


## V1 (M-V1 seal_opened 를 다시 그리지 않음, M-V2 seal_opened 알림을 지움): 플래그 없이 앞으로 → 「sealed」 알림. 플래그를 가진 채 뒤로 → seal_closed 알림,
## 앞으로 → 봉인이 열리고(움직이지 않음) 알림·다시 그림·자동 저장(13판 locks_open).
func test_seal_toasts_and_rebuild() -> void:
	var texts := TextDb.load_path("res://data/text/ko.json")
	var s := await _open(Vector2i(9, 2), Dir.W, false)
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check_eq([s._toast.text, s.state.world.is_lock_open(SEAL)], [texts.t("msg.sealed"), false], "플래그 없음: sealed 알림")
	s = await _open(Vector2i(9, 2), Dir.E, true)
	await kit.press_key(KEY_S)
	await kit.frames(2)
	check_eq([s._toast.text, s.state.party.at], [texts.t("msg.seal_closed"), Vector2i(9, 2)], "플래그 있음, 뒤로: seal_closed 알림")
	s = await _open(Vector2i(9, 2), Dir.W, true)
	var mesh0 := s.view._mesh_instance.mesh.get_instance_id()
	var saves := s.autosave_count
	await kit.press_key(KEY_W)
	await kit.frames(3)
	var snap := s.debug_snapshot()
	check_eq([s._toast.text, snap["modal"], snap["at"], s.state.world.is_lock_open(SEAL), s.autosave_count], [texts.t("msg.seal_opened"), "", [9, 2], true, saves + 1],
		"플래그 있음, 앞으로: 봉인 열림 알림, 제자리, 자동 저장 하나")
	check(s.view._mesh_instance.mesh.get_instance_id() != mesh0, "봉인 열림은 시야를 다시 만든다")
	check_eq(DungeonMeshBuilder.edge_style(s.state.floor_def, s.state.world, SEAL), "door", "그리는 모양: 열린 문")
	var doc := _auto_doc(s)
	check_eq([doc["schema"], doc["state"]["floor_states"]["b3f"]["world"]["locks_open"]], [13.0, ["v:9:2"]], "자동 저장 13판 locks_open 에 봉인")


## V2 (A9a 임시 상태, A9b 가 넓힌다): 보스에 부딪히거나 바라보고 조사하면 아무것도 보이지 않는다(창·알림·전투 없음, 제자리). FIGHT 키·단추는 없다.
func test_interim_boss_event_is_silent() -> void:
	var s := await _open(Vector2i(5, 2), Dir.W, true, true)
	for key in [KEY_W, KEY_SPACE]:
		await kit.press_key(key)
		await kit.frames(3)
		var snap := s.debug_snapshot()
		check_eq([snap["at"], snap["modal"], snap["toast"], snap["pending"], s.battle_layer.is_open(), s.state.world.foes["boss"].state],
			[[5, 2], "", "", false, false, "idle"], "키 %d: 보스 이벤트는 조용하다(A9a 임시)" % key)
	check(not DungeonScreen.KEY_ACTIONS.values().has(ExplorationRules.Action.FIGHT), "FIGHT 키 없음")
	check(not s.debug_snapshot()["buttons"].keys().any(func(k: String) -> bool: return k.contains("fight")), "FIGHT 단추 없음 %s" % str(s.debug_snapshot()["buttons"].keys()))


## V3 (M-V3 FIGHT 접촉이 전투 대기 길을 거치지 않음): 규칙 행동 FIGHT 는 있는 전투 대기 길로 전투 층을 연다(적 카드는 네온 펜리르 하나). 자동 저장 battle.foe boss.
func test_fight_opens_battle_layer() -> void:
	var s := await _open(Vector2i(5, 2), Dir.W, true, true)
	s._do_action(ExplorationRules.Action.FIGHT)
	await kit.frames(4)
	check(s.battle_layer.is_open(), "전투 층이 열렸다")
	check_eq([s.state.encounter.pending, s.state.battle != null and s.state.battle.foe == "boss", s.state.world.foes["boss"].state], [true, true, "battle"], "보스 전투 대기")
	if not s.battle_layer.is_open():
		return
	var cards: Array = s.battle_layer.enemy_area.cards
	check_eq(cards.size(), 1, "적 카드 하나")
	if cards.size() == 1:
		var u: BattleDisplay.DUnit = cards[0].unit()
		check_eq([u.def_id, u.name, u.hp, u.max_hp], ["enemy.boss_fenrir", "네온 펜리르", 1800, 1800], "펜리르 카드")
	var doc := _auto_doc(s)
	var bat: Variant = doc["state"].get("battle")
	check(bat is Dictionary and bat.get("foe") == "boss", "자동 저장 battle.foe boss")
