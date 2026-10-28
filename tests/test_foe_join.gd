## FOE 합류(M3 A6b 설계 §4.6·§4.7·§3.3·§7.3): 전투 턴 끝에 합류 범위 안의 FOE 만 움직이고(J1), N턴 뒤 합류의 N 과 때(J2), 들어갈 열(J3),
## 붙은 유닛이 보통 적과 같은지(J4), 저장 왕복·검사(J5), FOE 가 범위 밖이면 인카운트 전투가 바이트까지 같은지(J6).
## 시험 층은 Fx 글 층, 정의는 data/ 사본에서 적이 아무것도 하지 않는 시험 스킬(MEND)을 먼저 쓰는 것(Fx.quiet_defs, 파티가 쓰러지지 않는다).
## 시험마다 죽이는 변이(M-J…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const RAM_FORMATION := "formation.foe.ether_ram"
const RATS := "formation.f1.rats"
const BEETLE_RAT := "formation.f1.beetle_rat"
const RATS_MOTH := "formation.f1.rats_moth"
const E := BattleUnit.ENEMY
const P := BattleUnit.PARTY

## 7×3 모두 열림, 시작 (0,0). 파티는 가운데 (3,1)에 둔다(시작 칸은 FOE 칸이 아니다).
const GRID := [
	"+-+-+-+-+-+-+-+",
	"|. . . . . . .|",
	"+ + + + + + + +",
	"|. . . . . . .|",
	"+ + + + + + + +",
	"|. . . . . . .|",
	"+-+-+-+-+-+-+-+",
]
const MID := Vector2i(3, 1)

static var _quiet: GameDefs


func _ram(id: String, at: Array, facing: String, path: Array, join: int) -> Dictionary:
	return {"id": id, "foe": "foe.ether_ram", "kind": "patrol", "at": at, "facing": facing, "path": path, "join": join, "respawn": "never"}


func _delver(id: String, at: Array, facing: String, join: int) -> Dictionary:
	return {"id": id, "foe": "foe.lost_delver", "kind": "chase", "at": at, "facing": facing, "sight": 3, "chase": 4, "join": join, "respawn": "never"}


func _guard(id: String, at: Array) -> Dictionary:
	return {"id": id, "foe": "foe.warden", "kind": "guard", "at": at, "facing": "N", "respawn": "never"}


## 적이 MEND 만 쓰는 정의(EXACT: 명중·피해 난수 고정)를 이 층 하나로 묶는다.
func _defs(f: FloorModel) -> GameDefs:
	if _quiet == null:
		_quiet = Fx.quiet_defs(Fx.EXACT)
	if f.encounter_table.is_empty():
		f.encounter_table = "encounter.f1_test"
	return GameDefs.assemble([f] as Array[FloorModel], _quiet.party, _quiet.battle)


func _game(foes: Array) -> ExplorationState:
	var f := Fx.floor_of(GRID, {"foes": foes})
	assert(f != null)
	var s := ExplorationRules.new_game(_defs(f), 5, "floor")
	s.party.at = MID
	s.party.facing = Dir.E
	return s


## 파티 (3,1)에서 인카운트 전투(위험도를 한계값까지 채워 저장과 맞춘다).
func _encounter(foes: Array, formation: String) -> ExplorationState:
	var s := _game(foes)
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, formation)
	assert(st[0]["type"] == "battle_start")
	return s


## FOE 기록 일곱 값 전부.
func _rec(s: ExplorationState, id: String) -> Array:
	var fs: WorldState.FoeState = s.world.foes[id]
	return [fs.at, fs.facing, fs.state, fs.path_i, fs.dir, fs.stun, fs.day]


func _foe_events(ev: Array[Dictionary]) -> Array[Dictionary]:
	return ev.filter(func(e: Dictionary) -> bool: return str(e["type"]).begins_with("foe_"))


## 모두 방어로 한 턴.
func _guard_turn(s: ExplorationState) -> Array[Dictionary]:
	return BattleRules.submit(s, Fx.cmds(s))


## 그 칸 적이 이 이벤트 열에서 행동했는지.
func _acted(ev: Array[Dictionary], slot: int) -> bool:
	return ev.any(func(e: Dictionary) -> bool: return e["type"] == "action" and e["unit"] == {"side": E, "slot": slot})


## 정의한 열(쓰러진 유닛 포함)의 유닛 수를 시험이 직접 센다(규칙의 row_count 를 쓰지 않는다).
func _rows(s: ExplorationState) -> Array:
	var front := 0
	var back := 0
	for u in s.battle.enemies:
		if u.row == "front":
			front += 1
		elif u.row == "back":
			back += 1
	return [front, back]


## 적 u 를 처치된 상태로(저장 검사가 받는 처치 기록).
func _kill(s: ExplorationState, slot: int) -> void:
	var u: BattleUnit = s.battle.enemies[slot]
	u.hp = 0
	u.kill = {"turn": s.battle.turn, "element": "slash", "ailment": "", "binds": [], "by": "attack"}


# ---- J1 누가 움직이나 ----

## J1 (M-J1 모든 FOE 가 움직임): 거리 d ≤ join 인 FOE 만 턴 끝에 움직인다. join + 1 칸의 FOE·문지기·쉬는 FOE 는 기록 일곱 값이 그대로다.
func test_only_in_range_act() -> void:
	var s := _encounter([
		_ram("a", [5, 1], "W", [[5, 1], [6, 1]], 2),  # d 2 = join
		_ram("b", [6, 2], "W", [[6, 2], [5, 2]], 3),  # d 4 = join + 1
		_guard("g", [3, 0]),  # d 1, 문지기
		_delver("c", [0, 1], "E", 3),  # d 3 = join
		_delver("z", [1, 0], "E", 3),  # d 3, 쉰다
	], RATS)
	s.world.foes["z"].stun = 1
	var keep := {"b": _rec(s, "b"), "g": _rec(s, "g"), "z": _rec(s, "z")}
	check_eq(keep, {"b": [Vector2i(6, 2), Dir.W, "patrol", 0, 1, 0, 0], "g": [Vector2i(3, 0), Dir.N, "idle", 0, 1, 0, 0],
		"z": [Vector2i(1, 0), Dir.E, "idle", 0, 1, 1, 0]}, "준비: 처음 기록")
	check_eq(FoeRules.join_eta(s), [{"foe": "a", "n": 2, "wait": false}, {"foe": "c", "n": 3, "wait": false}], "합류 예정: 범위 안 둘")
	var ev := _guard_turn(s)
	check_eq(_foe_events(ev), [{"type": "foe_join", "foe": "a", "n": 1}, {"type": "foe_join", "foe": "c", "n": 2}], "턴 끝: a·c 만 한 걸음")
	check_eq([_rec(s, "a"), _rec(s, "c")], [[Vector2i(4, 1), Dir.W, "join", 0, 1, 0, 0], [Vector2i(1, 1), Dir.E, "join", 0, 1, 0, 0]], "a·c 는 join")
	check_eq({"b": _rec(s, "b"), "g": _rec(s, "g"), "z": _rec(s, "z")}, keep, "b(join + 1)·문지기·쉬는 FOE 는 그대로")
	_guard_turn(s)
	check_eq({"b": _rec(s, "b"), "g": _rec(s, "g"), "z": _rec(s, "z")}, keep, "둘째 턴도 그대로(전투 중에는 쉼도 줄지 않는다)")


# ---- J2 N 과 때 ----

## J2 (M-J2a 맞닿은 뒤 한 턴 늦게(d 0) 합류, M-J2b 합류한 턴에 행동): join_eta 의 n 은 걸음 거리이고 제출마다 하나씩 준다.
## n 1 이면 그 턴 끝에 붙고(foe_joined 는 turn_end 뒤), 그 턴에는 행동하지 않으며 다음 제출부터 행동한다.
func test_eta_and_timing() -> void:
	var s := _encounter([_ram("a", [6, 1], "W", [[6, 1], [5, 1]], 3)], BEETLE_RAT)
	check_eq(FoeRules.join_eta(s), [{"foe": "a", "n": 3, "wait": false}], "처음 n 3(걸음 거리)")
	var ev := _guard_turn(s)
	check_eq([FoeRules.join_eta(s), s.world.foes["a"].at], [[{"foe": "a", "n": 2, "wait": false}], Vector2i(5, 1)], "제출 1: n 2")
	ev = _guard_turn(s)
	check_eq([FoeRules.join_eta(s), s.world.foes["a"].at], [[{"foe": "a", "n": 1, "wait": false}], Vector2i(4, 1)], "제출 2: n 1")
	check_eq(s.battle.enemies.size(), 2, "아직 붙지 않았다")
	ev = _guard_turn(s)
	var types := Fx.types(ev)
	check(types.has("turn_end") and types.find("foe_joined") > types.find("turn_end"), "제출 3: 그 턴 끝에 합류 %s" % str(types))
	check_eq(Fx.of_type(ev, "foe_joined"), [{"type": "foe_joined", "foe": "a", "slot": 2, "row": "front"}] as Array[Dictionary], "foe_joined")
	check(not _acted(ev, 2), "합류한 턴에는 행동하지 않는다")
	if s.battle.enemies.size() != 3:
		check(false, "붙지 않았다(적 %d)" % s.battle.enemies.size())
		return
	check_eq([s.battle.enemies.size(), s.battle.turn, _rec(s, "a"), FoeRules.join_eta(s)],
		[3, 3, [Vector2i(4, 1), Dir.W, "battle", 0, 1, 0, 0], []], "붙음: 적 셋, battle, 예정 없음")
	check_eq([s.battle.joined, s.battle.enemies[2].def_id, s.battle.enemies[2].hp], [[{"foe": "a", "row": "front"}], "enemy.foe_ether_ram", 600], "합류 유닛")
	ev = _guard_turn(s)
	check(_acted(ev, 2), "다음 제출부터 행동한다")
	check_eq(_foe_events(ev), [], "붙은 뒤에는 더 움직이지 않는다")


# ---- J3 열 ----

## J3 (M-J3 살아 있는 유닛만 셈): 무리의 열에 자리가 있으면 그 열, 차면 다른 열, 3 + 3 이면 기다린다(wait). 쓰러진 유닛도 센다.
## 비어 있던 전열(후열이 나와 있던)에 붙으면 row_shift.
func test_rows() -> void:
	# 자기 열: 전열 둘 + 숫양(전열).
	var s := _encounter([_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2)], BEETLE_RAT)
	var ev := _guard_turn(s)
	check_eq([Fx.of_type(ev, "foe_joined"), _rows(s)], [[{"type": "foe_joined", "foe": "a", "slot": 2, "row": "front"}], [3, 0]], "자기 열(전열)")
	# 다른 열과 기다림: 전열 셋 + 맞닿은 숫양 넷 → 셋은 후열, 넷째는 기다린다.
	s = _encounter([
		_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2), _ram("b", [3, 0], "S", [[3, 0], [4, 0]], 2),
		_ram("c", [3, 2], "N", [[3, 2], [4, 2]], 2), _ram("d", [2, 1], "E", [[2, 1], [1, 1]], 2),
	], RATS)
	ev = _guard_turn(s)
	var joined := Fx.of_type(ev, "foe_joined").map(func(e: Dictionary) -> Array: return [e["foe"], e["slot"], e["row"]])
	check_eq(joined, [["a", 3, "back"], ["b", 4, "back"], ["c", 5, "back"]], "셋은 후열")
	check_eq([_rows(s), s.battle.enemies.size(), _rec(s, "d")[2], FoeRules.join_eta(s)], [[3, 3], 6, "join", [{"foe": "d", "n": 1, "wait": true}]], "3 + 3: d 는 기다린다")
	ev = _guard_turn(s)
	check_eq([_foe_events(ev), s.battle.enemies.size(), _rec(s, "d")], [[], 6, [Vector2i(2, 1), Dir.E, "join", 0, 1, 0, 0]], "다음 턴도 기다린다")
	# 쓰러진 유닛도 센다: 쥐 하나가 쓰러져도 전열은 셋이라 후열로.
	s = _encounter([_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2)], RATS)
	_kill(s, 0)
	ev = _guard_turn(s)
	check_eq([Fx.of_type(ev, "foe_joined").map(func(e: Dictionary) -> String: return e["row"]), _rows(s)], [["back"], [3, 1]], "쓰러진 쥐도 센다: 전열 넷이 되지 않는다")
	# 빈 전열: 쥐 둘이 쓰러져 나방(후열)이 나와 있다 → 숫양이 전열에 붙으면 row_shift(되돌아감).
	s = _encounter([_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2)], RATS_MOTH)
	_kill(s, 0)
	_kill(s, 1)
	s.battle.promoted[E] = true
	ev = _guard_turn(s)
	var types := Fx.types(ev)
	check_eq(types.slice(types.find("foe_joined")), ["foe_joined", "row_shift"] as Array[String], "합류 뒤 열 바뀜")
	if s.battle.enemies.size() != 4:
		check(false, "붙지 않았다(적 %d)" % s.battle.enemies.size())
		return
	check_eq([ev[-1], s.battle.enemies[3].row, s.battle.promoted[E]], [{"type": "row_shift", "side": E, "promoted": false}, "front", false], "전열이 다시 생겼다")


# ---- J4 붙은 유닛 ----

## J4 (M-J4 끝 판정이 붙은 유닛을 보지 않음): 칸으로 고를 수 있고 맞으며, 승리에는 그것도 쓰러져야 하고, 경험치·드롭에 들고, 승리면 그 FOE 는 쓰러진다.
func test_joined_unit_is_an_enemy() -> void:
	var s := _encounter([_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2)], BEETLE_RAT)
	s.day = 2
	_guard_turn(s)
	check_eq(s.battle.enemies.size(), 3, "준비: 붙었다")
	if s.battle.enemies.size() != 3:
		return
	check(BattleRules.valid_targets(s, 0, "attack").has(2), "칸 2 를 고를 수 있다")
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.atk(2)}))
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "damaged" and e["target"] == {"side": E, "slot": 2}), "칸 2 가 맞는다")
	check(s.battle.enemies[2].hp < 600, "HP 가 줄었다")
	_kill(s, 0)
	_kill(s, 1)
	var end_ev: Array[Dictionary] = []
	check_eq([BattleRules._check_end(s, end_ev), s.battle != null, end_ev], [false, true, []], "숫양이 살아 있으면 끝나지 않는다")
	if s.battle == null:
		return
	_kill(s, 2)
	check(BattleRules._check_end(s, end_ev), "모두 쓰러지면 승리")
	var end: Dictionary = end_ev[-1]
	# 경험치: 딱정벌레 40 + 쥐 12 + 숫양 180.
	check_eq([end["outcome"], end["exp_total"], Array(end.get("foes_defeated", []))], ["victory", 232, ["a"]], "경험치 232, 쓰러뜨린 FOE a")
	var ram_drops: Array = end["drops"].filter(func(d: Dictionary) -> bool: return d["enemy"] == 2)
	check_eq(ram_drops.map(func(d: Dictionary) -> String: return d["item"]), ["item.ether_horn"], "숫양 드롭(1000)")
	check_eq([_rec(s, "a"), end_ev.filter(func(e: Dictionary) -> bool: return e["type"] == "foe_defeated")],
		[[Vector2i(4, 1), Dir.W, "defeated", 0, 1, 0, 2], [{"type": "foe_defeated", "foe": "a"}]], "붙은 FOE 는 쓰러짐(2일째)")


# ---- J5 저장 ----

## 접촉 전투(k, 숫양 무리) + 맞닿은 숫양 a 가 첫 턴 끝에 붙은 상태.
func _contact_joined() -> ExplorationState:
	var s := _game([_ram("k", [2, 1], "E", [[2, 1], [1, 1]], 2), _ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2)])
	var st := BattleRules.start(s, RAM_FORMATION, "k")
	_guard_turn(s)
	var ok: bool = st[0]["type"] == "battle_start" and s.battle != null and s.battle.enemies.size() == 2
	check(ok, "준비: 접촉 전투에 숫양 a 가 붙었다")
	return s if ok else null


func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])


func _foes(doc: Dictionary) -> Dictionary:
	return doc["state"]["floor_states"]["fx"]["world"]["foes"]


## J5 (M-J5a 읽을 때 합류 유닛을 버림): 합류가 있는 전투 저장은 같은 해시로 돌아오고, 읽은 뒤 계속해도 FOE 가 늘거나 줄지 않는다.
func test_save_roundtrip() -> void:
	var s := _contact_joined()
	if s == null:
		return
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	var bd: Dictionary = doc["state"]["battle"]
	check_eq([bd["foe"], bd.get("joined"), bd["enemies"].size(), _foes(doc)["k"]["state"], _foes(doc)["a"]["state"]],
		["k", [{"foe": "a", "row": "front"}], 2, "battle", "battle"], "문서: foe k, joined a, 적 둘")
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(r.ok(), "읽힘 %s" % r.error)
	if not r.ok():
		return
	var t := r.state
	check_eq([SaveCodec.state_hash(t), Fx.battle_hash(t)], [SaveCodec.state_hash(s), Fx.battle_hash(s)], "같은 해시")
	var units := t.battle.enemies.map(func(u: BattleUnit) -> Array: return [u.def_id, u.slot, u.row])
	check_eq([units, t.battle.joined], [[["enemy.foe_ether_ram", 0, "front"], ["enemy.foe_ether_ram", 1, "front"]], [{"foe": "a", "row": "front"}]],
		"읽은 전투: 합류 유닛 그대로")
	if t.battle.enemies.size() != 2:
		return
	# 계속: 두 사본이 같은 명령으로 같은 이벤트, 숫양 둘을 쓰러뜨리면 둘 다 쓰러짐(늘거나 줄지 않는다).
	var logs := []
	for x in [s, t]:
		var log := []
		log.append_array(_guard_turn(x))
		_kill(x, 0)
		_kill(x, 1)
		var ev: Array[Dictionary] = []
		BattleRules._check_end(x, ev)
		log.append_array(ev)
		logs.append([log, SaveCodec.state_hash(x), _rec(x, "k")[2], _rec(x, "a")[2]])
	check_eq(logs[1], logs[0], "읽은 사본 = 그대로 계속")
	check_eq([logs[0][2], logs[0][3]], ["defeated", "defeated"], "k·a 모두 쓰러짐")


## J5 (M-J5b 같은 합류 id 를 둘 받음): 검사가 거부하는 문서.
func test_save_rejects() -> void:
	var s := _contact_joined()
	if s == null:
		return
	_reject(s, func(d): d["state"]["battle"]["enemies"].pop_back(), "battle.enemies: 길이 2 의 배열이어야 한다(편성의 적 수 + 합류 수)", "적 수가 모자람")
	var twice := func(d: Dictionary) -> void:
		d["state"]["battle"]["joined"].append({"foe": "a", "row": "back"})
		d["state"]["battle"]["enemies"].append(d["state"]["battle"]["enemies"][1].duplicate(true))
	_reject(s, twice, "battle.joined[1].foe: 합류 FOE a 가 둘이다", "같은 합류 FOE 둘")
	_reject(s, func(d): d["state"]["battle"]["joined"][0]["foe"] = "f9", "battle.joined[0].foe: 이 층의 FOE 가 아니다", "모르는 합류 FOE")
	_reject(s, func(d): d["state"]["battle"]["joined"][0]["foe"] = "k", "battle.joined[0].foe: 접촉한 FOE k 는 합류하지 않는다", "접촉 FOE 가 합류")
	_reject(s, func(d): d["state"]["battle"]["joined"][0]["row"] = "middle", "battle.joined[0].row: front 또는 back 이어야 한다", "모르는 열")
	_reject(s, func(d): d["state"]["battle"]["joined"] = [], "battle.joined: 비어 있지 않은 배열이어야 한다", "빈 joined")
	_reject(s, func(d): d["state"]["battle"]["joined"][0]["slot"] = 1, "battle.joined[0].slot: 모르는 필드", "joined 의 모르는 키")
	_reject(s, func(d): _foes(d)["a"]["state"] = "join", "battle 상태인 FOE [\"k\"] 가 전투의 FOE [\"a\", \"k\"] 와 맞지 않다", "합류 FOE 가 battle 상태가 아님")
	_reject(s, func(d): d["state"]["battle"]["formation"] = RATS, "battle.formation: 접촉한 FOE k 의 무리가 아니다", "접촉 FOE 와 다른 무리")
	var no_battle := func(d: Dictionary) -> void:
		d["state"]["battle"] = null
		d["state"]["encounter"]["pending"] = false
		_foes(d)["k"]["state"] = "patrol"
	_reject(s, no_battle, "floor_states.fx.world.foes.a.state: battle 는 지금 층의 전투 중에만 있을 수 있다", "전투 없이 battle 상태")
	# 열마다 3 이하(쓰러진 유닛도): 전열 셋 + 합류 넷(후열 넷).
	var r := _encounter([
		_ram("a", [4, 1], "W", [[4, 1], [5, 1]], 2), _ram("b", [3, 0], "S", [[3, 0], [4, 0]], 2),
		_ram("c", [3, 2], "N", [[3, 2], [4, 2]], 2),
	], RATS)
	_guard_turn(r)
	check_eq(_rows(r), [3, 3], "준비: 3 + 3")
	if _rows(r) != [3, 3]:
		return
	var fourth := func(d: Dictionary) -> void:
		d["state"]["battle"]["joined"][0]["row"] = "front"
	_reject(r, fourth, "battle.joined: front 열이 4 칸이다(열마다 3 이하)", "전열 넷")


# ---- J6 범위 밖이면 그대로 ----

## J6 (M-J6 늘 "joined": [] 을 씀): f1_test 인카운트 전투는 FOE 규칙을 켜고 끈 이벤트·전투 사전이 같고, 전투 사전에 foe·joined 키가 없다.
## FOE 가 합류 범위 밖인 층도 켜고 끈 결과가 같고 그 FOE 기록은 그대로다.
func test_encounters_unchanged() -> void:
	var runs := []
	for on in [true, false]:
		FoeRules.enabled = on
		var s := Fx.game(Fx.f1(), 77, "floor")
		s.encounter.danger = s.encounter.threshold
		var log := []
		log.append_array(BattleRules.start(s, BattleRules.pick_formation(s)))
		var dicts := []
		for i in 3:
			log.append_array(BattleRules.submit(s, Fx.cmds(s, {0: Fx.atk(0)})))
			if s.battle == null:
				break
			dicts.append(s.battle.to_dict())
		runs.append([Fx.events_text(log), JSON.stringify(dicts, "", true), SaveCodec.state_hash(s)])
		check(not dicts.is_empty() and dicts.all(func(d: Dictionary) -> bool: return not d.has("foe") and not d.has("joined")), "f1_test: foe·joined 키 없음")
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
		check(doc["state"]["battle"] == null or not doc["state"]["battle"].has("joined"), "저장 문서에도 joined 키 없음")
	FoeRules.enabled = true
	check_eq(runs[0], runs[1], "f1_test: 켜고 끈 결과가 같다")
	var far := []
	for on in [true, false]:
		FoeRules.enabled = on
		var s := _encounter([_ram("b", [6, 2], "W", [[6, 2], [5, 2]], 3)], RATS)
		var before := _rec(s, "b")
		var log := []
		for i in 3:
			log.append_array(_guard_turn(s))
		far.append([Fx.events_text(log), JSON.stringify(s.battle.to_dict(), "", true), _rec(s, "b") == before, s.battle.to_dict().has("joined")])
	FoeRules.enabled = true
	check_eq(far[0], far[1], "범위 밖 FOE: 켜고 끈 결과가 같다")
	check_eq([far[0][2], far[0][3]], [true, false], "범위 밖 FOE 기록 그대로, joined 키 없음")


func teardown() -> void:
	FoeRules.enabled = true
	super()
