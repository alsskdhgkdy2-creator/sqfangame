## FOE 의 화면(M3 A6). A6a 는 중간 단계다: 화면은 새 탐색 이벤트(foe_moved·foe_turned·foe_alert·foe_lost·foe_contact·foe_respawned)를 그리지 않고
## 오류 없이 넘기며, 접촉 전투는 있는 전투 대기 길(pending → 전투 층)로 그 FOE 의 카드 하나로 열린다. A6c 가 표시(3D·지도·알림)를 더하며 이 파일을 넓힌다.
## 실제 미궁(open_arbor) B1F 숫양 f1(시작 (12,9) 동쪽, 경로 (12..17,9)). 얻는 길은 실제 키 → 자동 저장 → 문서로 본다.
## A6b: 전투 중 합류(I4)는 실제 키·명령 입구 → 연출 → 자동 저장 → 새 화면 → 승리 길로 본다.
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


## 모두 방어(명령을 받는 대원만).
func _guards(s: DungeonScreen) -> Array:
	var out := []
	for i in s.state.battle.party.size():
		out.append({"kind": "guard"} if BattleRules.can_command(s.state, i) else null)
	return out


func _card_ids(s: DungeonScreen) -> Array:
	return s.battle_layer.enemy_area.cards.map(func(c: BattleCard) -> Array: return [str(c.name), c.unit().def_id, c.unit().row])


## I4 (A6b, M-I4 합류 단계에서 적 칸을 다시 만들지 않음): 실제 B1F 에서 숫양이 합류 범위(2) 안에 있을 때 인카운트가 나면, 턴을 넘기는 동안
## 다가와 둘째 턴 끝에 붙는다. 그 단계의 메시지 띠·로그는 「에테르 숫양이 합류했다!」, 적 칸에 숫양 카드가 생긴다. 붙은 턴의 자동 저장 = 화면,
## 그 저장으로 새로 연 화면에도 숫양 카드가 있고, 이기면 숫양은 쓰러지고 경험치·드롭에 든다.
func test_join_flow() -> void:
	var s := await _open()
	var ram: WorldState.FoeState = s.state.world.foes["f1"]
	ram.at = Vector2i(13, 9)
	ram.path_i = 1
	ram.dir = -1
	ram.facing = Dir.W
	s.state.party.at = Vector2i(11, 9)
	s.state.party.facing = Dir.E
	s.state.encounter.danger = s.state.encounter.threshold - 1
	s._set_state(s.state)
	await kit.frames(2)
	await kit.press_key(KEY_S)  # 뒤로 (10,9), 숫양은 (12,9)
	await kit.frames(4)
	check(s.battle_layer.is_open(), "인카운트 전투가 열렸다")
	if not s.battle_layer.is_open():
		return
	var n := s.state.battle.enemies.size()
	check_eq([s.state.battle.formation, n], ["formation.b1.rats", 3], "준비: 시드 7 의 무리는 쥐 셋(전열 셋)")
	check_eq([s.state.party.at, ram.at, s.state.battle.foe, FoeRules.join_eta(s.state)], [Vector2i(10, 9), Vector2i(12, 9), "", [{"foe": "f1", "n": 2, "wait": false}]],
		"(10,9), 숫양 (12,9): 2턴 뒤 합류")
	check_eq(s.battle_layer.enemy_area.cards.size(), n, "카드는 편성만")
	var layer := s.battle_layer
	layer.handle("commands", _guards(s))
	await kit.frames(3)
	check_eq([ram.at, ram.state, FoeRules.join_eta(s.state), layer.enemy_area.cards.size()], [Vector2i(11, 9), "join", [{"foe": "f1", "n": 1, "wait": false}], n], "1턴: 한 걸음")
	# 합류 턴은 연출을 보며 넘긴다: foe_joined 단계의 띠 글과 그때의 적 칸.
	var line := "에테르 숫양이 합류했다!"  # 「{name}이(가) 합류했다!」, 받침 있는 이름
	layer.anim_speed = 4.0
	layer.handle("commands", _guards(s))
	var seen := []
	for i in 600:
		await kit.frames(1)
		if layer.phase != "anim":
			break
		var head: String = layer.banner_lines()[0]
		if head == line and seen.is_empty():
			seen = [head, layer.enemy_area.cards.size()]
	layer.anim_speed = 0.0
	check_eq(seen, [line, n + 1], "합류 단계: 띠 글, 숫양 카드가 생겼다")
	var row := "back"  # 전열이 차 있어 후열로(설계 §4.7)
	check_eq([ram.state, s.state.battle.joined, s.state.battle.enemies.size(), layer.phase], ["battle", [{"foe": "f1", "row": row}], n + 1, "command"], "붙음: battle, joined, 명령 입력")
	check_eq(_card_ids(s)[-1], ["Enemy_%d" % n, "enemy.foe_ether_ram", row], "마지막 카드는 숫양")
	check(layer.log_view.lines.has(line), "로그에 같은 줄")
	var doc := _auto_doc(s)
	var r := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now() and r.state.battle.to_dict() == s.state.battle.to_dict(), "자동 저장 = 화면 %s" % r.error)
	check_eq([doc["state"]["battle"]["joined"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]], [[{"foe": "f1", "row": row}], "battle"], "자동 저장: joined")
	# 그 저장으로 새 화면.
	var h := kit.hash_now()
	var cards := _card_ids(s)
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)
	layer = s.battle_layer
	check_eq([kit.hash_now(), layer.is_open(), layer.phase, _card_ids(s)], [h, true, "command", cards], "새 화면: 같은 상태, 숫양 카드")
	ram = s.state.world.foes["f1"]
	# 이기기: 적 HP 를 1 로 두고 기본 정책으로 친다.
	var exp_sum := 0
	for u in s.state.battle.enemies:
		u.hp = 1
		exp_sum += s.state.defs.battle.enemies[u.def_id].exp
	var end := {}
	for t in 6:
		if layer.phase != "command":
			break
		layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
		await kit.frames(2)
		end = layer.end_event
	check_eq([layer.phase, end.get("outcome"), Array(end.get("foes_defeated", [])), end.get("exp_total")], ["result", "victory", ["f1"], exp_sum], "승리: 숫양 쓰러뜨림, 경험치에 180 포함")
	var horns: Array = end.get("drops", []).filter(func(d: Dictionary) -> bool: return d["enemy"] == n)
	check_eq(horns.map(func(d: Dictionary) -> String: return d["item"]), ["item.ether_horn"], "숫양 칸의 드롭")
	check_eq([ram.state, ram.day], ["defeated", s.state.day], "숫양은 쓰러짐")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([layer.is_open(), _auto_doc(s)["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]], [false, "defeated"], "탐색으로, 자동 저장에 쓰러짐")
