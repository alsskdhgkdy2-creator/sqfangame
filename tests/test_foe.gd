## FOE 규칙(M3 A6 설계 §4·§7.2): 걸음마다 한 번(R1), 순회(R2), 추적·시야·포기·돌아감(R3), 접촉과 차례(R4), 전투 끝(R5),
## 되살아남·층 들어서기(R6), 결정성(R7). 시험 층은 Fx 글 층(FOE 정의는 실제 자료). 시험마다 죽이는 변이(M-R…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const RAM_FORMATION := "formation.foe.ether_ram"

## 위아래 줄이 막힌 7×2: 위 줄 (2,0)·(3,0) 얼음, 시작 (0,0). 아래 줄은 FOE 만 다닌다.
const GRID_SPLIT := [
	"+-+-+-+-+-+-+-+",
	"|. . = = . . .|",
	"+-+-+-+-+-+-+-+",
	"|. . . . . . .|",
	"+-+-+-+-+-+-+-+",
]
## 8×3: 위 두 줄은 (0,0)–(0,1) 문, (7,0)–(7,1) 열림으로 이어진다. 시작은 (7,2)(북쪽).
const GRID_C := [
	"+-+-+-+-+-+-+-+-+",
	"|. . . . . . . .|",
	"+D+-+-+-+-+-+-+ +",
	"|. . . . . . . .|",
	"+-+-+-+-+-+-+-+ +",
	"|#|#|#|#|#|#|#|.|",
	"+-+-+-+-+-+-+-+-+",
]
## 4×3 모두 열림, 시작 (3,0).
const GRID_OPEN := [
	"+-+-+-+-+",
	"|. . . .|",
	"+ + + + +",
	"|. . . .|",
	"+ + + + +",
	"|. . . .|",
	"+-+-+-+-+",
]
## 7×2: (3,0)–(3,1) 만 열려 있다.
const GRID_T := [
	"+-+-+-+-+-+-+-+",
	"|. . . . . . .|",
	"+-+-+-+ +-+-+-+",
	"|. . . . . . .|",
	"+-+-+-+-+-+-+-+",
]


func _patrol(id: String, at: Array, facing: String, path: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "foe": "foe.ether_ram", "kind": "patrol", "at": at, "facing": facing, "path": path, "join": 4, "respawn": "never"}
	d.merge(extra, true)
	return d


func _chaser(id: String, at: Array, facing: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "foe": "foe.lost_delver", "kind": "chase", "at": at, "facing": facing, "sight": 3, "chase": 4, "join": 3, "respawn": "never"}
	d.merge(extra, true)
	return d


func _guard(id: String, at: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "foe": "foe.warden", "kind": "guard", "at": at, "facing": "N", "respawn": "never"}
	d.merge(extra, true)
	return d


func _floor(grid: Array, foes: Array, extra: Dictionary = {}) -> FloorModel:
	var d := {"foes": foes}
	d.merge(extra, true)
	return Fx.floor_of(grid, d)


func _game(grid: Array, foes: Array, extra: Dictionary = {}) -> ExplorationState:
	var f := _floor(grid, foes, extra)
	assert(f != null)
	return ExplorationRules.new_game(Fx.defs(f), 5, "full")


func _put(s: ExplorationState, at: Vector2i, facing: int) -> void:
	s.party.at = at
	s.party.facing = facing


## FOE 기록 [칸, 방향, 경로 자리, 상태].
func _rec(s: ExplorationState, id: String) -> Array:
	var fs: WorldState.FoeState = s.world.foes[id]
	return [fs.at, fs.facing, fs.path_i, fs.state]


func _foe_events(ev: Array[Dictionary]) -> Array[Dictionary]:
	return ev.filter(func(e: Dictionary) -> bool: return str(e["type"]).begins_with("foe_"))


func _act(s: ExplorationState, a: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, a, "full")


# ---- R1 걸음마다 한 번 ----

## R1 (M-R1a 회전에 차례, M-R1b 벽에 부딪혀도 차례): 걸음 수가 오를 때만 FOE 가 움직이고, 미끄러짐은 한 번이다.
func test_tick_per_step() -> void:
	var path := [[0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1]]
	var s := _game(GRID_SPLIT, [_patrol("p", [0, 1], "E", path)])
	var start := _rec(s, "p")
	check_eq(start, [Vector2i(0, 1), Dir.E, 0, "patrol"], "처음: 순회")
	var ev := _act(s, A.TURN_RIGHT)
	check_eq([_rec(s, "p"), s.steps, _foe_events(ev)], [start, 0, []], "회전: 차례 없음")
	ev = _act(s, A.FORWARD)
	check_eq([Fx.types(ev), _rec(s, "p"), s.steps], [["blocked"], start, 0], "벽에 부딪힘: 차례 없음")
	_act(s, A.TURN_LEFT)
	ev = _act(s, A.INVESTIGATE)
	check_eq([_rec(s, "p"), _foe_events(ev)], [start, []], "조사: 차례 없음")
	ev = _act(s, A.FORWARD)
	check_eq([s.party.at, s.steps, _rec(s, "p")], [Vector2i(1, 0), 1, [Vector2i(1, 1), Dir.E, 1, "patrol"]], "한 칸: 차례 하나")
	check_eq(_foe_events(ev), [{"type": "foe_moved", "foe": "p", "from": Vector2i(0, 1), "to": Vector2i(1, 1), "facing": Dir.E}], "foe_moved")
	ev = _act(s, A.FORWARD)
	check_eq([s.party.at, s.steps, _rec(s, "p")], [Vector2i(4, 0), 2, [Vector2i(2, 1), Dir.E, 2, "patrol"]], "얼음 미끄러짐(세 칸): 차례 하나")
	check_eq(_foe_events(ev).size(), 1, "미끄러짐에도 foe_moved 하나")
	_act(s, A.BACK)
	check_eq([s.steps, _rec(s, "p")[0]], [3, Vector2i(3, 1)], "뒤로 걸어도 차례")


# ---- R2 순회 ----

## R2 (M-R2a 끝에서 돌기와 걷기를 한 행동에): 경로 셋의 왕복 열두 행동을 고정 칸으로. 도는 것은 그 자체로 한 행동이다.
func test_patrol_ping_pong() -> void:
	var s := _game(GRID_SPLIT, [_patrol("p", [1, 1], "E", [[1, 1], [2, 1], [3, 1]])])
	var cells: Array[Vector2i] = []
	var facings: Array[int] = []
	var turned := 0
	for i in 12:
		var ev := _act(s, A.FORWARD if i % 2 == 0 else A.BACK)
		turned += ev.filter(func(e: Dictionary) -> bool: return e["type"] == "foe_turned").size()
		cells.append(s.world.foes["p"].at)
		facings.append(s.world.foes["p"].facing)
	check_eq(s.steps, 12, "준비: 열두 걸음")
	check_eq(cells, [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 1),
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(1, 1)] as Array[Vector2i], "칸 열두")
	check_eq(facings, [Dir.E, Dir.E, Dir.W, Dir.W, Dir.W, Dir.E, Dir.E, Dir.E, Dir.W, Dir.W, Dir.W, Dir.E] as Array[int], "방향 열두")
	check_eq(turned, 4, "돌기 넷")


## R2: 다른 FOE 가 선 칸이면 기다린다(그쪽을 본다).
func test_patrol_waits_for_another_foe() -> void:
	var s := _game(GRID_SPLIT, [_patrol("a", [1, 1], "E", [[1, 1], [2, 1]]), _patrol("b", [3, 1], "W", [[3, 1], [2, 1]])])
	_act(s, A.FORWARD)
	check_eq([_rec(s, "a"), _rec(s, "b")], [[Vector2i(2, 1), Dir.E, 1, "patrol"], [Vector2i(3, 1), Dir.W, 0, "patrol"]], "1: a 가 먼저 들고 b 는 기다림")
	_act(s, A.BACK)
	check_eq([_rec(s, "a"), _rec(s, "b")], [[Vector2i(2, 1), Dir.W, 1, "patrol"], [Vector2i(3, 1), Dir.W, 0, "patrol"]], "2: a 는 돌고 b 는 기다림")
	_act(s, A.FORWARD)
	check_eq([_rec(s, "a"), _rec(s, "b")], [[Vector2i(1, 1), Dir.W, 0, "patrol"], [Vector2i(2, 1), Dir.W, 1, "patrol"]], "3: a 가 비키자 b 가 든다")


## R2 (M-R2b FOE 걸음이 문을 지남): FOE 걸음과 거리는 문을 지나지 않는다.
func test_foe_steps_do_not_cross_doors() -> void:
	var f := _floor(Fx.row_grid(".....", "  D "), [])
	check_eq([f.foe_step(Vector2i(2, 0), Dir.E), f.foe_step(Vector2i(3, 0), Dir.W), f.foe_step(Vector2i(1, 0), Dir.E)], [false, false, true], "문은 FOE 걸음을 막는다")
	var dist := FoeRules.distances(f, Vector2i(4, 0))
	check_eq([dist.has(Vector2i(3, 0)), dist.has(Vector2i(2, 0)), dist.has(Vector2i(1, 0))], [true, false, false], "거리는 문 너머로 번지지 않는다")
	check_eq(FoeRules.distances(f, Vector2i(0, 0)), {}, "FOE 가 못 서는 칸(시작)까지는 거리가 없다")


# ---- R3 추적 ----

func _sight(cells: String, inner: String, target: Vector2i, facing: int = Dir.W) -> bool:
	var f := _floor(Fx.row_grid(cells, inner), [_chaser("c", [7, 0], "W")])
	var sp: FloorModel.FoeSpawn = f.foes["c"]
	var fs := WorldState.FoeState.fresh(sp)
	fs.facing = facing
	return FoeRules.sees(f, sp, fs, target)


## R3 (M-R3a 시야가 문을 지남): 바라보는 쪽 곧게 sight 칸, 벽·문이 막고 얼음은 비친다.
func test_sight() -> void:
	check_eq([_sight("........", "       ", Vector2i(6, 0)), _sight("........", "       ", Vector2i(4, 0)), _sight("........", "       ", Vector2i(3, 0))],
		[true, true, false], "곧게 세 칸까지")
	check(not _sight("........", "       ", Vector2i(6, 0), Dir.E), "등 뒤는 못 본다")
	check_eq([_sight("........", "     | ", Vector2i(6, 0)), _sight("........", "     | ", Vector2i(5, 0))], [true, false], "벽이 막는다")
	check_eq([_sight("........", "     D ", Vector2i(6, 0)), _sight("........", "     D ", Vector2i(5, 0))], [true, false], "문이 막는다")
	check_eq([_sight("......=.", "       ", Vector2i(5, 0)), _sight("......=.", "       ", Vector2i(4, 0))], [true, true], "얼음은 비친다")


## R3 (M-R3b 발견한 차례에 바로 쫓음, M-R3c 포기하지 않음): 발견 한 차례 → 추적 → 문 너머로 멀어지면 포기 → 돌아가 시작 방향으로 선다.
func test_chase_alert_lose_and_return() -> void:
	var s := _game(GRID_C, [_chaser("c", [7, 0], "W")], {"start": {"at": [7, 2], "facing": "N"}})
	_put(s, Vector2i(3, 0), Dir.E)
	var ev := _act(s, A.FORWARD)
	check_eq([_rec(s, "c"), _foe_events(ev)], [[Vector2i(7, 0), Dir.W, 0, "alert"], [{"type": "foe_alert", "foe": "c"}]], "1: 발견, 움직이지 않음")
	var cells: Array[Vector2i] = []
	for i in 4:
		_act(s, A.BACK)
		cells.append(s.world.foes["c"].at)
	check_eq([cells, s.party.at, s.world.foes["c"].state], [[Vector2i(6, 0), Vector2i(5, 0), Vector2i(4, 0), Vector2i(3, 0)] as Array[Vector2i], Vector2i(0, 0), "chase"],
		"2~5: 다음 차례부터 한 칸씩 쫓는다")
	_act(s, A.TURN_RIGHT)
	ev = _act(s, A.FORWARD)
	check_eq(s.party.at, Vector2i(0, 1), "준비: 문 너머 아래 줄")
	check_eq([_rec(s, "c"), Fx.types(_foe_events(ev))], [[Vector2i(4, 0), Dir.E, 0, "return"], ["foe_lost", "foe_moved"]],
		"6: 돌아가는 길이 chase 4 보다 멀다(12) → 포기하고 같은 차례에 돌아가기 시작")
	_act(s, A.TURN_LEFT)
	for i in 3:
		_act(s, A.FORWARD)
	check_eq(_rec(s, "c"), [Vector2i(7, 0), Dir.W, 0, "idle"], "9: 시작 칸에 닿으면 시작 방향으로 선다")
	_act(s, A.FORWARD)
	check_eq(_rec(s, "c"), [Vector2i(7, 0), Dir.W, 0, "idle"], "10: 그대로 선다")


## R3: 문으로만 이어진 곳(거리 없음)이면 바로 포기한다. 돌아가던 FOE 도 파티를 보면 다시 발견한다.
func test_chase_gives_up_behind_a_door_and_realerts() -> void:
	var grid := GRID_C.duplicate()
	grid[2] = "+D+-+-+-+-+-+-+-+"
	var s := _game(grid, [_chaser("c", [7, 0], "W")], {"start": {"at": [7, 2], "facing": "N"}, "stairs": []})
	var fs: WorldState.FoeState = s.world.foes["c"]
	fs.at = Vector2i(1, 0)
	fs.state = "chase"
	_put(s, Vector2i(0, 1), Dir.S)
	var ev: Array[Dictionary] = []
	check_eq(FoeRules.tick(s, ev), {}, "접촉 없음")
	check_eq([_rec(s, "c"), Fx.types(ev)], [[Vector2i(2, 0), Dir.E, 0, "return"], ["foe_lost", "foe_moved"]], "문 너머는 거리가 없다 → 포기")
	fs.at = Vector2i(5, 0)
	fs.facing = Dir.W
	_put(s, Vector2i(2, 0), Dir.E)
	ev.clear()
	FoeRules.tick(s, ev)
	check_eq([_rec(s, "c"), ev], [[Vector2i(5, 0), Dir.W, 0, "alert"], [{"type": "foe_alert", "foe": "c"}]], "돌아가다가 다시 발견")


## R3: 너비 우선 거리가 같으면 N·E·S·W 차례로 고른다.
func test_chase_tie_break() -> void:
	var s := _game(GRID_OPEN, [_chaser("c", [1, 2], "W")], {"start": {"at": [3, 0], "facing": "W"}})
	var fs: WorldState.FoeState = s.world.foes["c"]
	fs.state = "chase"
	_put(s, Vector2i(0, 1), Dir.N)
	var ev: Array[Dictionary] = []
	FoeRules.tick(s, ev)
	check_eq(_rec(s, "c"), [Vector2i(1, 1), Dir.N, 0, "chase"], "(1,2)→(0,1): 북 (1,1) 과 서 (0,2) 가운데 북")
	fs.at = Vector2i(1, 0)
	fs.facing = Dir.W
	ev.clear()
	FoeRules.tick(s, ev)
	check_eq(_rec(s, "c"), [Vector2i(1, 1), Dir.S, 0, "chase"], "(1,0)→(0,1): 남 (1,1) 과 서 (0,0) 가운데 남")


# ---- R4 접촉과 차례 ----

## R4 (M-R4b 파티가 FOE 칸에 들어감): 부딪힘은 움직이지 않고 걸음·차례 없이 그 FOE 의 무리와 전투, 위험도 그대로. 엇갈림도 부딪힘이다.
func test_bump_contact() -> void:
	var s := _game(Fx.row_grid("......", "     "), [_patrol("p", [3, 0], "W", [[3, 0], [2, 0], [1, 0]])])
	_put(s, Vector2i(2, 0), Dir.E)
	var danger := s.encounter.danger
	var ev := _act(s, A.FORWARD)
	check_eq(ev, [{"type": "foe_contact", "foe": "p", "by": "party", "side": "front"}, {"type": "encounter", "formation": RAM_FORMATION, "foe": "p"}],
		"이벤트: 접촉 → 전투(엇갈리려던 순회도 부딪힘)")
	check_eq([s.party.at, s.steps, s.encounter.danger, s.encounter.pending], [Vector2i(2, 0), 0, danger, true], "제자리·걸음 없음·위험도 그대로·전투 대기")
	check_eq(_rec(s, "p"), [Vector2i(3, 0), Dir.W, 0, "battle"], "FOE 는 차례 없이 전투 상태")
	check(s.battle != null and s.battle.foe == "p" and s.battle.formation == RAM_FORMATION and s.battle.enemies[0].def_id == "enemy.foe_ether_ram", "battle.foe·무리")


## R4 (M-R4a 접촉 뒤에도 인카운트를 굴림): FOE 가 파티 칸으로 걸어 들면 자기 칸에 선 채 전투. 위험도가 한계 한 걸음 앞이어도 인카운트는 없다.
func test_foe_steps_into_party() -> void:
	var foes := [_patrol("p", [3, 0], "W", [[3, 0], [2, 0], [1, 0]])]
	var s := _game(Fx.row_grid("......", "     "), foes)
	_put(s, Vector2i(1, 0), Dir.E)
	s.encounter.danger = s.encounter.threshold - 10
	var danger := s.encounter.danger
	var ev := _act(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved", "foe_contact", "encounter"] as Array[String], "걸음 → 접촉 → 전투")
	check_eq(ev[1], {"type": "foe_contact", "foe": "p", "by": "foe", "side": "front"}, "FOE 쪽 접촉")
	check_eq(ev[2], {"type": "encounter", "formation": RAM_FORMATION, "foe": "p"}, "FOE 무리")
	check_eq([s.party.at, s.steps, s.encounter.danger, _rec(s, "p")], [Vector2i(2, 0), 1, danger, [Vector2i(3, 0), Dir.W, 0, "battle"]],
		"파티는 옮기고 FOE 는 제자리, 위험도 그대로")
	# 대조: FOE 차례를 끄면 같은 걸음이 인카운트를 연다(위험도가 한계에 닿는다).
	var t := _game(Fx.row_grid("......", "     "), foes)
	_put(t, Vector2i(1, 0), Dir.E)
	t.encounter.danger = t.encounter.threshold - 10
	FoeRules.enabled = false
	var tev := _act(t, A.FORWARD)
	FoeRules.enabled = true
	check_eq([Fx.types(tev), t.encounter.danger, t.battle != null and t.battle.foe.is_empty()], [["moved", "encounter"] as Array[String], t.encounter.threshold, true],
		"대조: FOE 없이는 인카운트")


## R4: 얼음 미끄러짐은 FOE 앞 마지막 얼음 칸에서 멈추고 전투(차례 없음).
func test_slide_stops_before_foe() -> void:
	var s := _game(Fx.row_grid("..===.", "     "), [_chaser("c", [5, 0], "W", {"sight": 1})])
	_put(s, Vector2i(1, 0), Dir.E)
	var ev := _act(s, A.FORWARD)
	check_eq([s.party.at, s.steps, Fx.types(ev).slice(-2), ev[-2]["by"], _rec(s, "c")],
		[Vector2i(4, 0), 1, ["foe_contact", "encounter"] as Array[String], "party", [Vector2i(5, 0), Dir.W, 0, "battle"]], "얼음 (4,0) 에서 멈추고 부딪힘")


## R4 (M-R4c 문지기가 문 너머로 발동): 문지기는 열린 경계로 맞닿은 칸에 멈추면 전투, 문·벽 너머는 아니다.
func test_guard_trigger() -> void:
	var s := _game(Fx.row_grid("......", "     "), [_guard("g", [3, 0])])
	_put(s, Vector2i(1, 0), Dir.E)
	var ev := _act(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved", "foe_contact", "encounter"] as Array[String], "열린 경계: 전투")
	check_eq(ev[1], {"type": "foe_contact", "foe": "g", "by": "guard", "side": "left"}, "문지기 접촉(북을 보는 문지기의 왼쪽)")
	for inner in ["  D  ", "  |  "]:
		var t := _game(Fx.row_grid("......", inner), [_guard("g", [3, 0])])
		_put(t, Vector2i(1, 0), Dir.E)
		var tev := _act(t, A.FORWARD)
		check_eq([t.party.at, Fx.types(tev), t.encounter.pending], [Vector2i(2, 0), ["moved"] as Array[String], false], "경계 「%s」 너머: 전투 없음" % inner[2])


## R4: 한 차례에 둘이 파티 칸으로 들려 하면 자료 차례의 첫째만 접촉하고 둘째는 기다린다.
func test_first_contact_wins() -> void:
	var s := _game(GRID_T, [_patrol("a", [2, 0], "E", [[2, 0], [3, 0]]), _patrol("b", [4, 0], "W", [[4, 0], [3, 0]])])
	_put(s, Vector2i(3, 1), Dir.N)
	var ev := _act(s, A.FORWARD)
	check_eq(_foe_events(ev), [{"type": "foe_contact", "foe": "a", "by": "foe", "side": "front"}], "a 하나만 접촉")
	check_eq([_rec(s, "a"), _rec(s, "b")], [[Vector2i(2, 0), Dir.E, 0, "battle"], [Vector2i(4, 0), Dir.W, 0, "patrol"]], "b 는 제자리에서 기다림")


## R4: 피해 바닥에서 전멸하면 FOE 는 움직이지 않는다.
func test_wipe_before_foes_act() -> void:
	var s := _game(Fx.row_grid("..~...", "     "), [_patrol("p", [3, 0], "W", [[3, 0], [2, 0]])])
	for m in s.party.members:
		m.hp = 1
	_put(s, Vector2i(1, 0), Dir.E)
	var ev := _act(s, A.FORWARD)
	check(s.wiped and Fx.types(ev).has("wiped"), "전멸 %s" % str(Fx.types(ev)))
	check_eq([_foe_events(ev), _rec(s, "p"), s.battle], [[], [Vector2i(3, 0), Dir.W, 0, "patrol"], null], "FOE 는 그대로")


# ---- R5 전투 끝 ----

func _bumped(foes: Array, at: Vector2i = Vector2i(2, 0)) -> ExplorationState:
	var s := _game(Fx.row_grid("......", "     "), foes)
	_put(s, at, Dir.E)
	_act(s, A.FORWARD)
	assert(s.battle != null)
	return s


## R5 (M-R5b 승리해도 쓰러짐으로 두지 않음): 승리면 쓰러짐(그날), 경험치에 FOE 의 180, 드롭을 굴린다. 인카운트 전투의 battle_end 는 그대로다.
func test_victory() -> void:
	var s := _bumped([_patrol("p", [3, 0], "W", [[3, 0], [2, 0]])])
	s.day = 3
	var u: BattleUnit = s.battle.enemies[0]
	u.hp = 0
	u.kill = {"turn": 1, "element": "slash", "ailment": "", "binds": [], "by": 0}
	var ev: Array[Dictionary] = []
	check(BattleRules.finish(s, "victory", ev), "승리")
	var fs: WorldState.FoeState = s.world.foes["p"]
	check_eq([fs.state, fs.day, fs.stun, fs.at], ["defeated", 3, 0, Vector2i(3, 0)], "쓰러짐, 3일째")
	var end: Dictionary = ev[-1]
	check_eq([end["type"], end["exp_total"], Array(end.get("foes_defeated", [])), end["drops"][0]["item"]], ["battle_end", 180, ["p"], "item.ether_horn"], "경험치 180·쓰러뜨린 FOE·드롭")
	check(ev.any(func(e: Dictionary) -> bool: return e == {"type": "foe_defeated", "foe": "p"}), "foe_defeated")
	check_eq([s.encounter.pending, s.battle, FoeRules.foe_at(s, Vector2i(3, 0))], [false, null, ""], "끝, 쓰러진 FOE 는 칸을 막지 않는다")
	_act(s, A.FORWARD)
	check_eq([s.party.at, s.encounter.pending], [Vector2i(3, 0), false], "쓰러진 FOE 칸을 지나간다")
	# 인카운트 전투는 foes_defeated 를 쓰지 않는다.
	var t := Fx.game(Fx.f1())
	BattleRules.start(t, BattleRules.pick_formation(t))
	var tev: Array[Dictionary] = []
	BattleRules.finish(t, "victory", tev)
	check(not tev[-1].has("foes_defeated") and not tev.any(func(e: Dictionary) -> bool: return e["type"] == "foe_defeated"), "인카운트 battle_end 는 그대로")


## R5 (M-R5a 도주해도 쉬지 않음): 도주면 파티는 제자리, FOE 는 두 걸음 쉰다(맞닿아도 접촉 없음), 셋째 걸음부터 다시 움직인다.
func test_escape_stun() -> void:
	var s := _bumped([_chaser("c", [3, 0], "W")])
	check(BattleRules.finish(s, "escaped"), "도주")
	check_eq([s.party.at, _rec(s, "c"), s.world.foes["c"].stun], [Vector2i(2, 0), [Vector2i(3, 0), Dir.W, 0, "chase"], 2], "제자리, 추적은 chase 로 두 걸음 쉼")
	var ev := _act(s, A.BACK)
	check_eq([s.party.at, _foe_events(ev), _rec(s, "c")[0], s.world.foes["c"].stun], [Vector2i(1, 0), [], Vector2i(3, 0), 1], "1: 쉼")
	ev = _act(s, A.FORWARD)
	check_eq([s.party.at, _foe_events(ev), s.encounter.pending, s.world.foes["c"].stun], [Vector2i(2, 0), [], false, 0], "2: 맞닿아도 쉼(접촉 없음)")
	ev = _act(s, A.BACK)
	check_eq([s.party.at, Fx.types(_foe_events(ev)), _rec(s, "c")[0]], [Vector2i(1, 0), ["foe_moved"], Vector2i(2, 0)], "3: 다시 쫓는다")
	ev = _act(s, A.FORWARD)
	check_eq(_foe_events(ev), [{"type": "foe_contact", "foe": "c", "by": "party", "side": "front"}], "4: 부딪히면 다시 전투")
	# 쉬는 FOE 에 일부러 부딪혀도 접촉이다. 턴 상한(도주로 끝남)도 같다.
	var t := _bumped([_patrol("p", [3, 0], "W", [[3, 0], [2, 0]])])
	var cap_ev: Array[Dictionary] = []
	BattleRules.finish(t, "escaped", cap_ev, "turn_cap")
	check_eq([_rec(t, "p"), t.world.foes["p"].stun], [[Vector2i(3, 0), Dir.W, 0, "return"], 2], "턴 상한: 순회는 return 으로 두 걸음 쉼")
	check_eq(_foe_events(_act(t, A.FORWARD)), [{"type": "foe_contact", "foe": "p", "by": "party", "side": "front"}], "쉬는 FOE 에 부딪힘")
	var g := _bumped([_guard("g", [3, 0])])
	BattleRules.finish(g, "escaped")
	check_eq([_rec(g, "g"), g.world.foes["g"].stun], [[Vector2i(3, 0), Dir.N, 0, "idle"], 2], "문지기는 idle 로 쉼")


## R5: 전멸이면 FOE 는 자리·방향 그대로 전투에서 빠지고(쉬지 않는다) 전멸 상태는 저장·읽기가 된다.
func test_wipe_leaves_foes() -> void:
	var s := _bumped([_guard("g", [3, 0])])
	for u in s.battle.party:
		u.hp = 0
	for m in s.party.members:
		m.hp = 0
	check(BattleRules.finish(s, "wiped"), "전멸")
	check_eq([s.wiped, _rec(s, "g"), s.world.foes["g"].stun], [true, [Vector2i(3, 0), Dir.N, 0, "idle"], 0], "자리 그대로, battle 에서 빠짐")
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "전멸 상태 저장·읽기 %s" % r.error)
	# M3 A9a 검토 L1 (M-R5w 전멸이 남은 쉼을 둔다): 턴 상한으로 쉬는 FOE 에 부딪혀 연 전투에서 전멸해도 쉬지 않는다(남은 쉼 0).
	var t := _bumped([_patrol("p", [3, 0], "W", [[3, 0], [2, 0]])])
	BattleRules.finish(t, "escaped", [] as Array[Dictionary], "turn_cap")
	check_eq(t.world.foes["p"].stun, FoeRules.ESCAPE_STUN, "준비: 턴 상한으로 쉼 2")
	check_eq(_foe_events(_act(t, A.FORWARD)), [{"type": "foe_contact", "foe": "p", "by": "party", "side": "front"}], "준비: 쉬는 FOE 에 부딪혀 다시 전투")
	check_eq([t.world.foes["p"].state, t.world.foes["p"].stun], ["battle", FoeRules.ESCAPE_STUN], "준비: 쉼이 남은 채 전투")
	for u in t.battle.party:
		u.hp = 0
	for m in t.party.members:
		m.hp = 0
	check(BattleRules.finish(t, "wiped"), "전멸(쉼이 남은 FOE)")
	check_eq([_rec(t, "p"), t.world.foes["p"].stun], [[Vector2i(3, 0), Dir.W, 0, "return"], 0], "전멸: 순회는 return, 남은 쉼도 0")
	var tr := SaveCodec.decode(SaveCodec.encode(t), t.defs)
	check(tr.ok() and SaveCodec.state_hash(tr.state) == SaveCodec.state_hash(t), "저장·읽기 %s" % tr.error)


# ---- R6 되살아남·층 들어서기 ----

func _down(s: ExplorationState, floor_id: String, id: String, day: int) -> void:
	var fs: WorldState.FoeState = s.floor_states[floor_id].world.foes[id]
	fs.state = "defeated"
	fs.day = day


## R6 (M-R6a after_days 하루 이르게): never 는 열 번 묵어도 그대로, after_days 2 는 정확히 d + 2 일에 숙박으로 되살아난다.
func test_respawn_after_days() -> void:
	var s := _game(Fx.row_grid("......", "     "), [_guard("n", [3, 0]), _guard("d", [5, 0], {"respawn": "after_days", "respawn_days": 2})])
	var fid := s.floor_def.id
	_down(s, fid, "n", 1)
	_down(s, fid, "d", 1)
	s.location = ExplorationState.TOWN
	s.money = 100000
	var ev := TownRules.stay(s)
	check_eq([s.day, Fx.types(ev), s.world.foes["d"].state], [2, ["stayed"] as Array[String], "defeated"], "2일째: 아직")
	ev = TownRules.stay(s)
	check_eq([s.day, ev[0], ev[-1]["type"]], [3, {"type": "foe_respawned", "floor": fid, "foe": "d"}, "stayed"], "3일째: 되살아남")
	check_eq(_rec(s, "d"), [Vector2i(5, 0), Dir.N, 0, "idle"], "처음 상태")
	for i in 8:
		TownRules.stay(s)
	check_eq([s.day, s.world.foes["n"].state, s.world.foes["n"].day], [11, "defeated", 1], "never 는 열 번 묵어도 그대로")


## R6: after_days 는 지금 층이 아닌 층 기록에서도 되살아난다(게임 층: B1F 숫양 after_days 1).
func test_respawn_on_other_floor() -> void:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 31, "full")
	_down(s, "b1f", "f1", 1)
	s.enter_floor(defs.floor_by_id("b2f"))
	s.location = ExplorationState.TOWN
	s.money = 100000
	var ev := TownRules.stay(s)
	check_eq([s.floor_def.id, ev[0]], ["b2f", {"type": "foe_respawned", "floor": "b1f", "foe": "f1"}], "다른 층의 숫양이 되살아남")
	check_eq(s.floor_states["b1f"].world.foes["f1"].state, "patrol", "처음 상태(순회)")


## R6 (M-R6b floor_reload 를 읽을 때 되살림, M-R6c 들어설 때 살아 있는 FOE 를 되돌리지 않음): floor_reload 는 계단 도착·ENTER 에서만,
## 읽기·비콘·숙박에서는 아니다. 살아 있는 FOE 는 들어설 때 처음 상태로.
func test_floor_reload_and_entry() -> void:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 31, "full")
	var b1 := defs.floor_by_id("b1f")
	var down: FloorModel.Stair = null
	for st in b1.stair_list():
		if st.to_floor == "b2f":
			down = st
	s.enter_floor(defs.floor_by_id("b2f"))
	for st in s.floor_def.stair_list():
		if st.to_floor == "b1f":
			_put(s, st.at, Dir.N)
	_down(s, "b2f", "f2", 1)
	# 읽기: 그대로.
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok() and r.state.floor_states["b2f"].world.foes["f2"].state == "defeated", "읽기로는 되살아나지 않는다 %s" % r.error)
	# 비콘: 그대로.
	s.consumables = {"use.ariadne_beacon": 1}
	ItemRules.use(s, "use.ariadne_beacon", -1)
	check_eq([s.in_town(), s.floor_states["b2f"].world.foes["f2"].state], [true, "defeated"], "비콘으로 마을: 그대로")
	s.money = 100000
	TownRules.stay(s)
	check_eq(s.floor_states["b2f"].world.foes["f2"].state, "defeated", "숙박: 그대로")
	# B1F 로 들어가(ENTER) 숫양을 옮겨 둔 뒤 계단으로 B2F → 되살아남. B1F 로 돌아오면 숫양은 처음 칸.
	_act(s, A.ENTER)
	var ram: WorldState.FoeState = s.world.foes["f1"]
	ram.at = Vector2i(15, 9)
	ram.path_i = 3
	_put(s, down.at, Dir.N)
	_act(s, A.STAIRS)
	check_eq([s.floor_def.id, _rec(s, "f2")], ["b2f", [Vector2i(5, 10), Dir.W, 0, "idle"]], "계단 도착: floor_reload 되살아남")
	s.world.foes["f2"].at = Vector2i(4, 10)
	s.world.foes["f2"].state = "chase"
	for st in s.floor_def.stair_list():
		if st.to_floor == "b1f":
			_put(s, st.at, Dir.N)
	_act(s, A.STAIRS)
	check_eq([s.floor_def.id, _rec(s, "f1")], ["b1f", [Vector2i(12, 9), Dir.E, 0, "patrol"]], "B1F 로 돌아옴: 살아 있는 숫양은 처음 칸")
	check_eq(s.floor_states["b2f"].world.foes["f2"].state, "chase", "떠난 층 기록은 다음 들어설 때까지 그대로")


## R6: ENTER(마을 → B1F)도 들어서기다: floor_reload 가 되살아나고 살아 있는 FOE 는 처음 상태로.
func test_enter_is_floor_reload() -> void:
	var s := _game(Fx.row_grid("......", "     "), [_guard("r", [3, 0], {"respawn": "floor_reload"}), _patrol("p", [4, 0], "E", [[4, 0], [5, 0]])])
	_down(s, s.floor_def.id, "r", 1)
	s.world.foes["p"].at = Vector2i(5, 0)
	s.world.foes["p"].path_i = 1
	s.location = ExplorationState.TOWN
	_act(s, A.ENTER)
	check_eq([s.in_town(), _rec(s, "r"), _rec(s, "p")], [false, [Vector2i(3, 0), Dir.N, 0, "idle"], [Vector2i(4, 0), Dir.E, 0, "patrol"]], "ENTER: 되살아남·처음 칸")


# ---- R7 결정성 ----

## R7 (M-R7 동점을 s.rng 로 가름): FOE 차례는 난수를 쓰지 않는다. 같은 상태·행동은 같은 이벤트.
func test_no_rng_and_repeatable() -> void:
	var s := _game(GRID_OPEN, [_chaser("c", [1, 2], "W")], {"start": {"at": [3, 0], "facing": "W"}})
	s.world.foes["c"].state = "chase"
	_put(s, Vector2i(0, 1), Dir.N)
	var before := s.rng.get_state()
	for i in 3:
		FoeRules.tick(s, [] as Array[Dictionary])
	check_eq(s.rng.get_state(), before, "차례 셋 뒤 난수 상태 그대로")
	var logs := []
	for k in 2:
		var t := _game(GRID_C, [_chaser("c", [2, 0], "E"), _patrol("p", [1, 1], "E", [[1, 1], [2, 1], [3, 1], [4, 1]])], {"start": {"at": [7, 2], "facing": "N"}})
		var log := []
		for a in [A.FORWARD, A.FORWARD, A.TURN_LEFT, A.FORWARD, A.FORWARD, A.FORWARD, A.BACK, A.FORWARD, A.FORWARD]:
			log.append_array(_act(t, a))
		logs.append([log, SaveCodec.state_hash(t)])
	check_eq(logs[0], logs[1], "같은 상태·행동 → 같은 이벤트·해시")


## R7: 중간에 저장·읽기를 끼워도 끝까지 그대로 걸은 것과 같다(FOE 상태가 저장에 다 있다).
func test_reload_equals_play() -> void:
	var foes := [_chaser("c", [2, 0], "E"), _patrol("p", [1, 1], "E", [[1, 1], [2, 1], [3, 1], [4, 1]])]
	var acts := [A.FORWARD, A.FORWARD, A.TURN_LEFT, A.FORWARD, A.FORWARD, A.FORWARD, A.BACK, A.FORWARD, A.FORWARD, A.BACK, A.BACK]
	var runs := []
	for reload_at in [-1, 4]:
		var t := _game(GRID_C, foes, {"start": {"at": [7, 2], "facing": "N"}})
		var log := []
		for i in acts.size():
			if i == reload_at:
				var r := SaveCodec.decode(SaveCodec.encode(t), t.defs)
				check(r.ok(), "중간 읽기 %s" % r.error)
				t = r.state
			log.append_array(_act(t, acts[i]))
		runs.append([log, SaveCodec.state_hash(t)])
	check_eq(runs[0], runs[1], "중간 저장·읽기 = 그대로 걸음")
	check(runs[0][0].any(func(e: Dictionary) -> bool: return str(e["type"]).begins_with("foe_")), "준비: FOE 가 움직였다")


## R7: FOE 가 없는 f1_test 에서는 FOE 규칙을 꺼도 같은 이벤트·해시다(인카운트 전투 포함).
func test_no_foe_floor_unchanged() -> void:
	var runs := []
	for on in [true, false]:
		FoeRules.enabled = on
		var s := Fx.game(Fx.f1(), 77, "full")
		var pick := GameRng.new(2024)
		var log := []
		for i in 300:
			var roll := pick.randi_range(0, 9)
			log.append_array(_act(s, A.FORWARD if roll < 5 else pick.randi_range(0, 6)))
			if s.encounter.pending:
				var ev: Array[Dictionary] = []
				BattleRules.finish(s, "victory", ev)
				log.append_array(ev)
		runs.append([log, SaveCodec.state_hash(s)])
	FoeRules.enabled = true
	check(runs[0][0].any(func(e: Dictionary) -> bool: return e["type"] == "battle_end"), "준비: 인카운트 전투가 있었다")
	check_eq(runs[0], runs[1], "켜고 끈 결과가 같다")


func teardown() -> void:
	FoeRules.enabled = true
	super()
