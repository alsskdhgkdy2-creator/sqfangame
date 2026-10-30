## FOE 의 화면(M3 A6). A6a 는 중간 단계다: 화면은 새 탐색 이벤트(foe_moved·foe_turned·foe_alert·foe_lost·foe_contact·foe_respawned)를 그리지 않고
## 오류 없이 넘기며, 접촉 전투는 있는 전투 대기 길(pending → 전투 층)로 그 FOE 의 카드 하나로 열린다. A6c 가 표시(3D·지도·알림)를 더하며 이 파일을 넓힌다.
## 실제 미궁(open_arbor) B1F 숫양 f1(시작 (12,9) 동쪽, 경로 (12..17,9)). 얻는 길은 실제 키 → 자동 저장 → 문서로 본다.
## A6b: 전투 중 합류(I4)는 실제 키·명령 입구 → 연출 → 자동 저장 → 새 화면 → 승리 길로 본다.
## 시험마다 죽이는 변이(M-I…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
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
	check_eq([doc["schema"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["at"]], [13.0, [13.0, 9.0]], "자동 저장 13판에 숫양 자리")
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
	var bat: Variant = doc["state"].get("battle")
	if not bat is Dictionary:
		check(false, "자동 저장에 battle 이 있다")
		return
	check_eq([doc["schema"], bat["foe"], bat["formation"], doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]],
		[13.0, "f1", "formation.foe.ether_ram", "battle"], "자동 저장: 접촉 전투")


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


func _cells(m: MapPanel) -> Array:
	return m.drawn_foes.map(func(d: Dictionary) -> Vector2i: return d["cell"])


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
	# U5 (A6c, M-U5a n 하나 어긋남): 알약 「FOE 2턴 뒤 합류」, 전투 미니맵에 숫양 원 (12,9).
	check_eq([layer.join_pill.visible, layer.join_pill.text, _cells(layer.minimap)], [true, "FOE 2턴 뒤 합류", [Vector2i(12, 9)]], "알약 2턴, 미니맵 원")
	check_eq([s.view.foes_root.visible, _marker(s, "f1") != null], [false, true], "인카운트 전투 중에도 표지 감춤(멈춘 공이 합류를 잘못 읽게 하지 않는다)")
	layer.handle("commands", _guards(s))
	await kit.frames(3)
	check_eq([ram.at, ram.state, FoeRules.join_eta(s.state), layer.enemy_area.cards.size()], [Vector2i(11, 9), "join", [{"foe": "f1", "n": 1, "wait": false}], n], "1턴: 한 걸음")
	check_eq([layer.join_pill.text, _cells(layer.minimap)], ["FOE 1턴 뒤 합류", [Vector2i(11, 9)]], "알약 1턴, 원은 파티 옆 (11,9)")
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
	check_eq([layer.join_pill.visible, layer.join_pill.text, _cells(layer.minimap)], [false, "", [Vector2i(11, 9)]], "붙은 뒤 알약 숨음, 원은 그대로(battle)")
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


# ---- A6c: 3D 표지·지도·알림·접촉·합류 알약·도주·되살아남·맞춤 (설계 §5·§7.5) ----

const RED := Color(1.0, 0.16, 0.12)
const ORANGE := Color(1.0, 0.55, 0.1)
const YELLOW := Color(0.95, 0.85, 0.25)
## 고정한 지도 그리기 차례(교훈 7: MapPanel.LAYERS 와 견주지 않는다).
const MAP_ORDER: Array[String] = ["blueprint", "grid", "floors", "edges", "icons", "memos", "foes", "party"]


func _open_q(query: String) -> DungeonScreen:
	timeout_sec = 120.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7, query)
	s.state.encounter.threshold = 99999
	return s


## 표지 메시 glow 표면의 정점 색들(겹침 없이).
static func _glow_colors(node: MeshInstance3D) -> Array:
	var out := []
	var m := node.mesh as ArrayMesh
	for i in m.get_surface_count():
		if m.surface_get_name(i) == "glow":
			for c in m.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
				if not out.has(c):
					out.append(c)
	return out


## 8비트 저장 오차(1/255) 안에서 같은 색.
static func _near_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= 1.0 / 255.0 + 1e-6 and absf(a.g - b.g) <= 1.0 / 255.0 + 1e-6 and absf(a.b - b.b) <= 1.0 / 255.0 + 1e-6


func _marker(s: DungeonScreen, id: String) -> MeshInstance3D:
	return s.view.foes_root.get_node_or_null("Foe_" + id) as MeshInstance3D


## U1 (M-U1a foe_moved 에 표지를 옮기지 않음, M-U1b 위협 색을 레벨이 아니라 종류로): 살아 있는 FOE 마다 칸 가운데·바라보는 쪽 표지 하나,
## glow 정점 색 = 위협 색(고정 값). 걸음 뒤 연출이 새 칸에서 끝난다. 쓰러진 FOE 는 표지가 없다. 카메라 보정 정점에는 표지가 들지 않는다.
func test_markers_3d() -> void:
	var s := await _open()
	var m := _marker(s, "f1")
	check(m != null and s.view.foes_root.get_child_count() == 1, "표지 하나(Foe_f1)")
	if m == null:
		return
	check_eq([m.transform.origin, absf(wrapf(m.transform.basis.get_euler().y - DungeonView.yaw_of(Dir.E), -PI, PI)) < 1e-4],
		[Vector3(24, 0, 18), true], "(12,9) 가운데(24, 0, 18), 동쪽")
	var glow := _glow_colors(m)
	check(glow.size() == 1 and _near_color(glow[0], RED), "레벨 1 파티 · 숫양 레벨 6: 빨강 %s" % str(glow))
	check_eq(s.view.vertex_count(), DungeonMeshBuilder.build(s.state.floor_def, s.state.world).verts.size(), "보정 정점은 층 메시뿐")
	# 레벨이 오르면 색이 바뀐다(종류 색이 아니다): 최고 레벨 2 → 차이 4 → 주황, 7 → −1 → 노랑.
	for p in [[2, ORANGE, "주황"], [7, YELLOW, "노랑"]]:
		s.state.party.members[0].level = p[0]
		s._set_state(s.state)
		await kit.frames(2)
		glow = _glow_colors(_marker(s, "f1"))
		check(glow.size() == 1 and _near_color(glow[0], p[1]), "최고 레벨 %d: %s %s" % [p[0], p[2], str(glow)])
	# 걸음 연출(속도 1): 끝나면 새 칸 (13,9).
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	var moved := false
	for i in 240:
		await kit.frames(1)
		if not s.view.foe_busy() and not s.view.is_busy():
			break
		moved = moved or _marker(s, "f1").transform.origin.x > 24.01
	s.view.speed = 0.0
	check_eq([s.state.world.foes["f1"].at, _marker(s, "f1").transform.origin], [Vector2i(13, 9), Vector3(26, 0, 18)], "연출 끝: (13,9) 가운데")
	check(moved, "연출 중에 사이 자리를 지났다")
	# 쓰러지면 표지가 없다.
	s.state.world.foes["f1"].state = "defeated"
	s.state.world.foes["f1"].day = 1
	s._set_state(s.state)
	await kit.frames(2)
	check_eq([_marker(s, "f1") == null, s.view.foes_root.get_child_count(), s.view.foe_marks()], [true, 0, {}], "쓰러진 숫양: 표지 없음")


## 표지 메시의 정점(겹침 없이, 지역 좌표).
static func _mark_verts() -> PackedVector3Array:
	var out := PackedVector3Array()
	var seen := {}
	var b := DungeonMeshBuilder.foe_mesh(RED)
	for i in b.mesh.get_surface_count():
		for v in b.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			var key: Vector3 = v.snappedf(0.0001)
			if not seen.has(key):
				seen[key] = true
				out.append(v)
	return out


## 점 p 에서 선분 a–b 까지 거리.
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * k)


## 파티 행동 하나(act)와 FOE 연출 하나(foe 칸 s·바라봄 f0 → 칸 n·바라봄 f1)를 time 표본마다 맞춰, 표지의 모든 정점과 카메라 사이의
## 가장 짧은 거리. 카메라 = 시야의 구간 자세(DungeonView._segment_pose, play 와 같은 구간) + 눈높이 + 앞 방향 보정 δ 의 모든 값
## (|δ| ≤ CameraGuard.WIDE_LIMIT, 보정이 고를 수 있는 전부라 실제 보정 계획과 상관없다). 표지 = DungeonView.foe_pose(시야와 같은 함수).
## 파티는 (0,0) 동쪽: 시야·표지 모양은 y 축 90° 돌림에 같으므로(표지는 FOE yaw 로 돈다) 다른 바라봄은 같은 경우의 돌림이다.
## scale: 표지 배율(M3 A9b 보스 FoeLook.BOSS_SCALE, 보통 1).
static func _clearance(act: String, s: Vector2i, f0: int, n: Vector2i, f1: int, verts: PackedVector3Array, scale: float = 1.0) -> float:
	var p0 := DungeonMeshBuilder.cell_center(Vector2i.ZERO)
	var y0 := DungeonView.yaw_of(Dir.E)
	var seg: Dictionary
	match act:
		"forward", "back", "strafe_l", "strafe_r":
			var to: Vector2i = {"forward": Vector2i(1, 0), "back": Vector2i(-1, 0), "strafe_l": Vector2i(0, -1), "strafe_r": Vector2i(0, 1)}[act]
			seg = {"kind": "move", "from_pos": p0, "to_pos": DungeonMeshBuilder.cell_center(to), "from_yaw": y0, "to_yaw": y0, "time": DungeonView.MOVE_TIME, "ease": true}
		_:
			var target := DungeonView.yaw_of(Dir.N if act == "turn_l" else Dir.S)
			seg = {"kind": "turn", "from_pos": p0, "to_pos": p0, "from_yaw": y0, "to_yaw": y0 + wrapf(target - y0, -PI, PI), "time": DungeonView.TURN_TIME}
	var fy := DungeonView.yaw_of(f0)
	var ty := fy + wrapf(DungeonView.yaw_of(f1) - fy, -PI, PI)
	var fp := DungeonMeshBuilder.cell_center(s)
	var tp := DungeonMeshBuilder.cell_center(n)
	var least := INF
	for i in 21:
		var time := i * DungeonView.MOVE_TIME / 20.0
		var cam: Array = DungeonView._segment_pose(seg, time)
		var fwd := -Basis(Vector3.UP, cam[1]).z
		var eye: Vector3 = cam[0] + Vector3.UP * DungeonView.EYE_HEIGHT
		var a := eye - fwd * CameraGuard.WIDE_LIMIT
		var b := eye + fwd * CameraGuard.WIDE_LIMIT
		var fpose := DungeonView.foe_pose(fp, tp, fy, ty, time, DungeonView.MOVE_TIME)
		var tr := Transform3D(Basis(Vector3.UP, fpose[1]).scaled(Vector3.ONE * scale), fpose[0])
		for v in verts:
			least = minf(least, _seg_dist(tr * v, a, b))
	return least


## U1 (카메라, seq=9 R2, M-U10 돌며 걷기(옛 연출)): 한 걸음의 모든 조합에서 표지의 모든 정점(가시·차양·그림자)이 카메라에서 0.75m 이상.
## 파티: 앞·뒤·옆 걸음 둘·돌기 둘. FOE: (0,0) 둘레 5×5 의 모든 칸(파티 칸·파티가 들어갈 칸 제외)에서 네 바라봄 × (이웃 칸 넷으로 걷기
## (들어갈 칸 제외, 비운 칸 포함, 걷는 쪽을 본다) 또는 제자리에서 다른 쪽으로 돌기). 표본은 0, 0.01 … 0.2초(프레임이 아니라 같은 함수).
## 검토의 실제 경우(파티 (2,2) 동쪽 → (3,2), 순찰 (2,1) 동쪽 → 남쪽으로 (2,2))는 이름 붙인 줄로 따로 본다.
func test_marker_clearance_every_single_step() -> void:
	timeout_sec = 120.0
	var verts := _mark_verts()
	check_eq(verts.size(), 51, "표지 정점(겹침 없이) 51")
	var acts := ["forward", "back", "strafe_l", "strafe_r", "turn_l", "turn_r"]
	var party_to := {"forward": Vector2i(1, 0), "back": Vector2i(-1, 0), "strafe_l": Vector2i(0, -1), "strafe_r": Vector2i(0, 1), "turn_l": Vector2i.ZERO, "turn_r": Vector2i.ZERO}
	var cases := 0
	var least := INF
	var worst := ""
	for act in acts:
		var pe: Vector2i = party_to[act]
		for sx in range(-2, 3):
			for sy in range(-2, 3):
				var s := Vector2i(sx, sy)
				if s == Vector2i.ZERO or s == pe:
					continue
				for f0 in 4:
					var outs := []
					for d in 4:
						var n: Vector2i = s + Dir.vec(d)
						if n == pe:
							continue  # 파티가 있는 칸(들어간 칸, 돌기면 제자리)으로는 걷지 않는다: 접촉
						outs.append([n, d])
					for f1 in 4:
						if f1 != f0:
							outs.append([s, f1])
					for o in outs:
						var c := _clearance(act, s, f0, o[0], o[1], verts)
						cases += 1
						if c < least:
							least = c
							worst = "%s, FOE %s %d → %s %d" % [act, s, f0, o[0], o[1]]
	check_eq(cases, 3840, "조합 수(돌기 2 × 656 + 걸음 4 × 632)")
	check(least >= 0.75, "모든 한 걸음: 최소 %.4fm ≥ 0.75 (%s)" % [least, worst])
	var named := _clearance("forward", Vector2i(0, -1), Dir.E, Vector2i(0, 0), Dir.S, verts)
	check(named >= 0.75, "검토 R2 줄(앞으로, FOE 북쪽 칸 동쪽 → 비운 칸으로 남쪽): %.4fm ≥ 0.75" % named)


## U1 (카메라, 검토 R2 그대로): 실제 규칙(열린 5×5, 파티 (2,2) 동쪽 → 앞으로, 순찰 (2,1) 동쪽 → 남쪽으로 (2,2))과 실제 시야(보정 포함)를
## 고정 간격 0.005초로 손수 돌려(프레임 시각에 기대지 않는다) 카메라와 표지의 모든 정점 사이가 0.75m 이상.
func test_marker_clearance_review_case_real_view() -> void:
	timeout_sec = 60.0
	var grid := ["+-+-+-+-+-+", "|. . . . .|", "+ + + + + +", "|. . . . .|", "+ + + + + +", "|. . . . .|", "+ + + + + +", "|. . . . .|", "+ + + + + +", "|. . . . .|", "+-+-+-+-+-+"]
	var foes := [{"id": "a", "foe": "foe.ether_ram", "kind": "patrol", "at": [2, 1], "facing": "E", "path": [[2, 1], [2, 2]], "join": 2, "respawn": "never"}]
	var f := Fx.floor_of(grid, {"foes": foes})
	var st := ExplorationRules.new_game(Fx.defs(f), 3, "floor")
	st.party.at = Vector2i(2, 2)
	st.party.facing = Dir.E
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	tree.root.add_child(sv)
	var v := DungeonView.new()
	sv.add_child(v)
	await tree.process_frame
	v.set_process(false)
	v.setup(f, st.world)
	v.set_pose(st.party.at, st.party.facing)
	v.sync_foes(st)
	v.speed = 1.0
	var ev := ExplorationRules.apply(st, ExplorationRules.Action.FORWARD, "floor")
	var kinds := ev.filter(func(e: Dictionary) -> bool: return e["type"] in ["moved", "foe_moved"]).map(func(e: Dictionary) -> Array:
		return [e["type"], e["to"], e.get("facing", -1)])
	check_eq(kinds, [["moved", Vector2i(3, 2), -1], ["foe_moved", Vector2i(2, 2), Dir.S]], "실제 규칙: 파티 (3,2), 순찰은 남쪽을 보며 비운 (2,2)로")
	v.play(ev, Dir.E)
	var node: MeshInstance3D = _marker_of(v, "a")
	var least := INF
	for i in 41:
		var cam := v.camera_transform().origin
		for surf in node.mesh.get_surface_count():
			for vert in node.mesh.surface_get_arrays(surf)[Mesh.ARRAY_VERTEX]:
				least = minf(least, cam.distance_to(node.transform * vert))
		v._process(0.005)
	check(least >= 0.75, "실제 시야: 최소 %.4fm ≥ 0.75" % least)
	check_eq([v.is_busy(), v.foe_busy(), node.transform.origin], [false, false, Vector3(4, 0, 4)], "끝: 표지는 (2,2) 가운데")
	sv.queue_free()


func _marker_of(v: DungeonView, id: String) -> MeshInstance3D:
	return v.foes_root.get_node_or_null("Foe_" + id) as MeshInstance3D


## U2 (M-U2 foes 를 floors 앞에 그림): 지도(그리기 격자)·층 전체·미니맵·전투 미니맵이 같은 FOE 원(색·칸·방향)을 그리고, 차례는 메모 뒤·파티 앞.
func test_map_discs() -> void:
	var s := await _open()
	await kit.open_map()
	await kit.frames(2)
	var want := [{"id": "f1", "cell": Vector2i(12, 9), "color": RED, "facing": Dir.E, "boss": false}]  # M3 A9b: drawn_foes 에 boss 키가 더해졌다
	for v in [["지도", s.map], ["층 전체", s.map_window.overview]]:
		check_eq(v[1].drawn_foes, want, v[0] + ": 숫양 원")
		check_eq(v[1].drawn_layers, MAP_ORDER, v[0] + ": 메모 뒤·파티 앞")
	await kit.press_key(KEY_M)
	await kit.frames(2)
	check_eq([s.minimap.drawn_foes, s.minimap.drawn_layers], [want, MAP_ORDER], "미니맵: 숫양 원, 차례")
	# 전투 미니맵: (11,9) 동쪽에서 부딪혀 접촉 전투.
	s.state.party.at = Vector2i(11, 9)
	s.state.party.facing = Dir.E
	s._set_state(s.state)
	await kit.frames(2)
	await kit.press_key(KEY_W)
	await kit.frames(4)
	check(s.battle_layer.is_open(), "접촉 전투")
	if not s.battle_layer.is_open():
		return
	check_eq([s.battle_layer.minimap.drawn_foes, s.battle_layer.minimap.drawn_layers], [want, MAP_ORDER], "전투 미니맵: 숫양 원(battle 상태도 살아 있다)")


## U3 (M-U3 알림 없음): B2F 탐험가 방(문 (3,8)–(3,9))에서 남쪽 (3,10)으로 들어서면 서쪽을 보는 탐험가(5,10, 시야 3)에게 들킨다.
## 알림 줄은 「잠식된 탐험가에게 들켰다!」 한 줄이고, 다음 안내가 바꾼다(쌓지 않는다).
func test_alert_toast() -> void:
	var s := await _open()
	s.state.enter_floor(s.state.defs.floor_by_id("b2f"))
	s.state.party.at = Vector2i(3, 9)
	s.state.party.facing = Dir.S
	s._set_state(s.state)
	await kit.frames(2)
	check_eq([s.state.floor_def.id, s.state.world.foes["f2"].state, s.state.world.foes["f2"].at], ["b2f", "idle", Vector2i(5, 10)], "준비: B2F, 탐험가 (5,10)")
	await kit.press_key(KEY_W)
	await kit.frames(2)
	var snap := s.debug_snapshot()
	check_eq([snap["at"], s.state.world.foes["f2"].state, snap["toast"], snap["modal"]], [[3, 10], "alert", "잠식된 탐험가에게 들켰다!", ""], "들켰다: 알림 한 줄")
	check_eq(s._toast.get_line_count(), 1, "한 줄")
	await kit.press_key(KEY_SPACE)  # 조사: 「아무것도 없다」가 알림을 바꾼다
	await kit.frames(2)
	check_eq(s.debug_snapshot()["toast"], s.texts.t("msg.nothing_found"), "다음 안내가 바꾼다(쌓지 않는다)")


## 숫양에 부딪혀 접촉 전투: B1F 시작 (9,18)에서 앞으로 아홉((9,9)), 오른쪽으로 돌아 둘((11,9), 숫양은 그때 (12,9) 서쪽), 앞으로 → 부딪힘.
func _walk_into_ram(s: DungeonScreen) -> void:
	for i in 9:
		await kit.press_key(KEY_W)
	await kit.press_key(KEY_D)
	for i in 2:
		await kit.press_key(KEY_W)
	check_eq([s.state.party.at, s.state.world.foes["f1"].at, s.state.world.foes["f1"].facing], [Vector2i(11, 9), Vector2i(12, 9), Dir.W], "(11,9), 숫양 (12,9) 서쪽")
	await kit.press_key(KEY_W)
	await kit.frames(4)


## U4 (M-U4 접촉 FOE 를 battle 로 두지 않음) · U7 (M-U7 숙박 새 날에 FOE 되살아남 없음): 실제 걸음으로 접촉 → 전투 시작 자동 저장 = 화면
## (battle.foe f1, 숫양 battle) → 그 저장으로 새 화면도 같다 → 이기면 쓰러짐, 표지·원이 없고 자동 저장 = 화면 → 마을 문 → 숙박 → 둘째 날
## 자동 저장에 숫양이 처음 상태 → 미궁에 들어가면 숫양이 (12,9)에 있다.
func test_contact_victory_and_respawn() -> void:
	var s := await _open()
	await _walk_into_ram(s)
	var layer := s.battle_layer
	check(layer.is_open() and s.state.battle != null and s.state.battle.foe == "f1", "접촉 전투(battle.foe f1)")
	if not layer.is_open():
		return
	check_eq(layer.banner_lines(), ["FOE 에테르 숫양!", "FOE와 마주쳤다!", true], "첫 띠: 「FOE 에테르 숫양!」 + 「FOE와 마주쳤다!」")
	# U9 (seq=7, M-U9 전투 중 표지를 감추지 않음): 전투 동안 3D 표지(Foes)는 감춘다. 표지 자체는 남는다.
	check_eq([s.view.foes_root.visible, _marker(s, "f1") != null, s.debug_snapshot()["foe_marks_shown"]], [false, true, false], "전투 중 표지 감춤")
	var doc := _auto_doc(s)
	var r := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now(), "전투 시작 자동 저장 = 화면 %s" % r.error)
	var bat: Variant = doc["state"].get("battle")
	check_eq([bat.get("foe") if bat is Dictionary else null, doc["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]["state"]], ["f1", "battle"], "저장: foe f1, 숫양 battle")
	var h := kit.hash_now()
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)
	layer = s.battle_layer
	check_eq([kit.hash_now(), layer.is_open(), layer.enemy_area.cards.size(), s.state.battle.foe if s.state.battle != null else ""], [h, true, 1, "f1"], "새 화면: 같은 전투")
	check(not s.view.foes_root.visible, "새 화면의 전투: 표지 감춤")
	if not layer.is_open() or s.state.battle == null:
		return
	# 이기기: 숫양 HP 1, 기본 정책.
	s.state.battle.enemies[0].hp = 1
	for t in 6:
		if layer.phase != "command":
			break
		layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
		await kit.frames(2)
	check_eq([layer.phase, layer.end_event.get("outcome"), Array(layer.end_event.get("foes_defeated", []))], ["result", "victory", ["f1"]], "승리")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([layer.is_open(), s.state.world.foes["f1"].state, _marker(s, "f1") == null, s.minimap.drawn_foes], [false, "defeated", true, []], "쓰러짐: 표지·원 없음")
	# M3 A9b (M-U2 보스가 아닌 FOE 승리에도 이야기 상자): 보통 FOE 를 이겨도 클리어 이야기 상자는 열리지 않는다.
	check_eq([s.modal.kind, s.debug_snapshot()["story"], s.debug_snapshot()["cleared"]], ["", {}, []], "보통 FOE 승리: 이야기 상자 없음")
	# U9 (M-U9b 닫혀도 다시 보이지 않음): 전투가 닫히면 표지 층이 다시 보인다.
	check_eq([s.view.foes_root.visible, s.debug_snapshot()["foe_marks_shown"]], [true, true], "전투 뒤 표지 층 보임")
	r = SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now(), "끝 자동 저장 = 화면")
	s.state.encounter.threshold = 99999  # 돌아가는 길에 인카운트가 나지 않게(저장 비교 뒤)
	# 마을 문으로: 뒤로 둘((9,9)), 오른쪽으로 돌아(남쪽) 앞으로 아홉 → 시작 칸 (9,18) 마을 문 물음.
	await kit.press_key(KEY_S)
	await kit.press_key(KEY_S)
	await kit.press_key(KEY_D)
	for i in 9:
		await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq([s.state.party.at, s.modal.kind], [START, "stairs"], "마을 문 물음")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(s.state.in_town() and s.town_screen.is_open(), "마을")
	var t := s.town_screen
	await kit.tap(kit.center_of(t.plaza_list.rows[0]))
	await kit.frames(1)
	await kit.tap(kit.center_of(t.inn_list.rows[0]))
	await kit.tap(kit.center_of(t.dialog.yes_button))
	await kit.frames(2)
	check_eq([s.state.day, s.state.floor_states["b1f"].world.foes["f1"].state], [2, "patrol"], "숙박: 둘째 날, 숫양 되살아남")
	var fresh: Dictionary = _auto_doc(s)["state"]["floor_states"]["b1f"]["world"]["foes"]["f1"]
	check_eq(fresh, {"at": [12.0, 9.0], "facing": "E", "state": "patrol", "path_i": 0.0, "dir": 1.0, "stun": 0.0, "day": 0.0}, "숙박 뒤 자동 저장: 숫양 처음 상태")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_6)
	await kit.tap(kit.center_of(t.entrance_list.rows[0]))
	await kit.frames(3)
	check_eq([s.state.location, s.state.party.at, s.state.world.foes["f1"].at, _marker(s, "f1") != null], ["labyrinth", START, Vector2i(12, 9), true],
		"들어가면 숫양이 (12,9), 표지 있음")


## U6: 숫양에서 도주하면(디버그 끝내기 escaped) 파티는 제자리, 숫양은 두 걸음 쉰다: 물러났다 다시 맞닿아도 접촉이 없고, 자동 저장 = 화면.
func test_escape_then_two_free_steps() -> void:
	var s := await _open_q("debug=1")
	await _walk_into_ram(s)
	var layer := s.battle_layer
	check(layer.is_open(), "접촉 전투")
	if not layer.is_open():
		return
	check(layer.handle("finish", "escaped"), "도주로 끝냄")
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([layer.is_open(), s.state.party.at, s.state.world.foes["f1"].stun, s.state.world.foes["f1"].state], [false, Vector2i(11, 9), 2, "return"], "제자리, 숫양 두 걸음 쉼")
	# U9: 도주로 닫히면 표지가 다시 보이고 지금 자리·색으로 맞춰져 있다.
	var mk := _marker(s, "f1")
	check_eq([s.view.foes_root.visible, mk != null, mk.transform.origin if mk != null else Vector3.ZERO, _glow_colors(mk).size() if mk != null else 0],
		[true, true, DungeonMeshBuilder.cell_center(s.state.world.foes["f1"].at), 1], "도주 뒤 표지 보임·제자리")
	await kit.press_key(KEY_S)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq([s.state.party.at, s.state.encounter.pending, s.battle_layer.is_open(), s.state.world.foes["f1"].at, s.state.world.foes["f1"].stun],
		[Vector2i(11, 9), false, false, Vector2i(12, 9), 0], "두 걸음(물러남·다시 맞닿음): 접촉 없음")
	var r := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now(), "자동 저장 = 화면")


## 디버그 요청 하나(JSON 문자열을 오가는 실제 길, 웹 확인과 같다)의 답.
func _op(s: DungeonScreen, req: Dictionary) -> Dictionary:
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify(req)))
	return r if r is Dictionary else {}


## R1 (seq=9, M-R1 정수 값 float 를 int 로 바꾸지 않음, M-R1b 규칙이 거부해도 ok): 디버그 battle_commands 는 JSON 수(float)를 받는다.
## 표적 0 공격은 턴·세대를 나아가게 하고 자동 저장 = 화면, 새 화면도 같다. 소수(0.5)·참거짓·범위 밖(9) 표적은 ok false·이유·칸이고 턴·세대는 그대로.
func test_debug_battle_commands_json() -> void:
	var s := await _open_q("debug=1")
	var st := _op(s, {"op": "battle_start"})
	check_eq([st.get("ok"), st.get("open")], [true, true], "battle_start: 인카운트 전투")
	await kit.frames(2)
	var layer := s.battle_layer
	if not layer.is_open() or s.state.battle == null:
		return
	var turn := s.state.battle.turn
	var gen := s.state.generation
	for bad in [0.5, true, 9]:
		var r := _op(s, {"op": "battle_commands", "commands": Fx.cmds(s.state, {0: {"kind": "attack", "target": bad}})})
		await kit.frames(2)
		check_eq([r.get("ok"), r.get("reason"), r.get("slot"), s.state.battle.turn, s.state.generation, layer.phase], [false, "invalid_target", 0.0, turn, gen, "command"],
			"표적 %s: 거부(ok false), 턴·세대 그대로" % str(bad))
	var ok := _op(s, {"op": "battle_commands", "commands": Fx.cmds(s.state, {0: Fx.atk(0)})})
	await kit.frames(3)
	check_eq([ok.get("ok"), s.state.battle.turn if s.state.battle != null else -1, s.state.generation > gen, layer.phase], [true, turn + 1, true, "command"],
		"표적 0 공격(JSON 0 = float): 받아들여 턴·세대가 나아갔다")
	var r2 := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r2.ok() and SaveCodec.state_hash(r2.state) == kit.hash_now(), "자동 저장 = 화면 %s" % r2.error)
	var h := kit.hash_now()
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)
	check_eq([kit.hash_now(), s.battle_layer.is_open(), s.state.battle.turn if s.state.battle != null else -1], [h, true, turn + 1], "새 화면: 같은 해시·같은 턴의 전투")


## U8: 가장 긴 알림 「잠식된 탐험가에게 들켰다!」가 알림 줄(36px) 한 줄에, 「FOE 9턴 뒤 합류」가 알약(227×40)에 들어간다.
## FOE 가 보이는 곳에서 화면 이동 단추(터치)로 걷는다.
func test_fit_and_touch_pad() -> void:
	var s := await _open()
	var font := s._toast.get_theme_font("font")
	var fs := s._toast.get_theme_font_size("font_size")
	var w := font.get_string_size("잠식된 탐험가에게 들켰다!", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	check(w.x <= s._toast.size.x and w.y <= DungeonScreen.TOAST_H, "알림 %s ≤ %s × %d" % [str(w), str(s._toast.size.x), DungeonScreen.TOAST_H])
	var pill := s.battle_layer.join_pill
	var pw := pill.get_theme_default_font().get_string_size(s.texts.t("battle.join_eta", {"n": 9}), HORIZONTAL_ALIGNMENT_LEFT, -1, JoinPill.FS)
	check(pw.x <= JoinPill.SIZE.x - 24.0 and pw.y <= JoinPill.SIZE.y, "알약 글 %s 은 227×40 안(양옆 12px)" % str(pw))
	# (9,17)에서 동쪽을 보면 숫양 복도는 아니지만 표지는 층에 있다: 이동 단추로 앞으로·뒤로.
	check(_marker(s, "f1") != null, "숫양 표지")
	await kit.tap(kit.center_of(s.pad[ExplorationRules.Action.FORWARD]))
	await kit.frames(3)
	check_eq([s.state.party.at, s.state.world.foes["f1"].at, _marker(s, "f1").transform.origin], [PLAIN, Vector2i(13, 9), Vector3(26, 0, 18)], "터치 앞으로: 숫양도 한 칸")
	await kit.tap(kit.center_of(s.pad[ExplorationRules.Action.BACK]))
	await kit.frames(3)
	check_eq([s.state.party.at, s.state.world.foes["f1"].at], [START, Vector2i(14, 9)], "터치 뒤로")
