## FOE 의 화면(M3 A6). A6a 는 중간 단계다: 화면은 새 탐색 이벤트(foe_moved·foe_turned·foe_alert·foe_lost·foe_contact·foe_respawned)를 그리지 않고
## 오류 없이 넘기며, 접촉 전투는 있는 전투 대기 길(pending → 전투 층)로 그 FOE 의 카드 하나로 열린다. A6c 가 표시(3D·지도·알림)를 더하며 이 파일을 넓힌다.
## 실제 미궁(open_arbor) B1F 숫양 f1(시작 (12,9) 동쪽, 경로 (12..17,9)). 얻는 길은 실제 키 → 자동 저장 → 문서로 본다.
## 시험마다 죽이는 변이(M-I…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
## B1F: 시작 칸 (9,18) 북쪽(마을 문), 그 북쪽 (9,17).
const START := Vector2i(9, 18)
const PLAIN := Vector2i(9, 17)

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _open() -> DungeonScreen:
	timeout_sec = 90.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7)
	s.state.encounter.threshold = 99999
	return s


func _auto_doc(s: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)))


## I1 (중간 단계): 걸음마다 숫양이 움직여도 화면은 알림·창 없이 걷기만 하고, 자동 저장(10판)에 숫양 자리가 있다.
func test_interim_foe_moves_are_silent() -> void:
	var s := await _open()
	check_eq([s.state.floor_def.id, s.state.party.at, s.state.world.foes["f1"].at], ["b1f", START, Vector2i(12, 9)], "준비: B1F 시작 칸, 숫양 처음 칸")
	var saves := s.autosave_count
	await kit.press_key(KEY_W)
	await kit.frames(3)
	var snap := s.debug_snapshot()
	check_eq([snap["at"], snap["modal"], snap["toast"], snap["pending"], s.battle_layer.is_open()], [[PLAIN.x, PLAIN.y], "", "", false, false], "한 걸음: 창·알림 없음")
	check_eq([s.state.world.foes["f1"].at, s.autosave_count], [Vector2i(13, 9), saves + 1], "숫양은 한 칸 움직였고 자동 저장 하나")
	var doc := _auto_doc(s)
	check_eq([doc["schema"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["at"]], [10.0, [13.0, 9.0]], "자동 저장 10판에 숫양 자리")
	for i in 5:
		await kit.press_key(KEY_E if i % 2 == 0 else KEY_Q)  # (9,17) ↔ (10,17) 옆걸음
		await kit.frames(2)
	snap = s.debug_snapshot()
	check_eq([snap["at"], s.state.world.foes["f1"].at, s.state.world.foes["f1"].facing, snap["modal"], snap["toast"], snap["pending"], s.autosave_count],
		[[10, 17], Vector2i(17, 9), Dir.W, "", "", false, saves + 6], "여섯 걸음: 숫양은 끝 칸에서 돌았다(돌기 이벤트도 조용히), 창·알림 없음")


## I2 (M-I2 접촉 전투가 전투 대기 길을 거치지 않음): 숫양에 부딪히면 전투 층이 열리고 적 카드는 숫양 하나다. 자동 저장의 battle 은 foe f1.
func test_interim_contact_opens_battle() -> void:
	var s := await _open()
	s.state.party.at = Vector2i(11, 9)
	s.state.party.facing = Dir.E
	s._set_state(s.state)
	await kit.frames(2)
	var danger := s.state.encounter.danger
	await kit.press_key(KEY_W)
	await kit.frames(4)
	check(s.battle_layer.is_open(), "전투 층이 열렸다")
	check_eq([s.state.party.at, s.state.encounter.pending, s.state.encounter.danger, s.state.battle != null and s.state.battle.foe == "f1"], [Vector2i(11, 9), true, danger, true],
		"제자리, 전투 대기, 위험도 그대로, battle.foe f1")
	if not s.battle_layer.is_open():
		return
	var cards: Array = s.battle_layer.enemy_area.cards
	check_eq(cards.size(), 1, "적 카드 하나")
	if cards.size() == 1:
		var u: BattleDisplay.DUnit = cards[0].unit()
		check_eq([u.def_id, u.name, u.hp, u.max_hp], ["enemy.foe_ether_ram", "에테르 숫양", 600, 600], "숫양 카드")
	var doc := _auto_doc(s)
	check_eq([doc["schema"], doc["state"]["battle"]["foe"], doc["state"]["battle"]["formation"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]],
		[10.0, "f1", "formation.foe.ether_ram", "battle"], "자동 저장: 접촉 전투")


## I3 (M-I3 숙박 자동 저장이 이벤트 하나(stayed)일 때만): 숙박에 FOE 되살아남(foe_respawned)이 붙어도 자동 저장하고, 숙소 화면은 그 이벤트를 넘긴다.
func test_interim_inn_stay_with_respawn_autosaves() -> void:
	var s := await _open()
	var ram: WorldState.FoeState = s.state.world.foes["f1"]
	ram.state = "defeated"
	ram.day = 1
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	await kit.frames(3)
	check_eq([s.state.party.at, s.modal.kind], [START, "stairs"], "마을 문 물음")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(s.state.in_town() and s.town_screen.is_open(), "마을 광장")
	var t := s.town_screen
	await kit.tap(kit.center_of(t.plaza_list.rows[0]))
	await kit.frames(1)
	check_eq(t.page, "inn", "준비: 숙소")
	var saves := s.autosave_count
	await kit.tap(kit.center_of(t.inn_list.rows[0]))
	await kit.tap(kit.center_of(t.dialog.yes_button))
	await kit.frames(2)
	check_eq([s.state.day, s.autosave_count, s.state.floor_states["b1f"].world.foes["f1"].state], [2, saves + 1, "patrol"], "숙박: 2일째, 숫양 되살아남, 자동 저장")
	var doc := _auto_doc(s)
	check_eq([doc["state"]["day"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]], [2.0, "patrol"], "자동 저장에 되살아난 숫양")
	check_eq(s.debug_snapshot()["modal"], "", "창 없음")
