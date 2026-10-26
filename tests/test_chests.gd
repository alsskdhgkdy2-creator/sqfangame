## 보물상자 규칙(M3 A3): 멈추면 묻는 chest 이벤트, 조사로 다시 묻기·빈 상자, OPEN(소재·장비·돈·열쇠), 가득이면 그대로,
## 거부·막힘, 결정성. 시험마다 죽이는 변이(설계 노트 §8.2, M-R…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

## 위 줄: (0,0) 시작, (1,0) 소재 셋, (2,0) 장비, (3,0) 돈 100, (4,0) 열쇠. (1,0) 아래 숨은 통로 h:1:1, 아래 줄은 그 통로로만 간다.
const GRID := [
	"+-+-+-+-+-+",
	"|. . . . .|",
	"+-+H+-+-+-+",
	"|. . . . .|",
	"+-+-+-+-+-+",
]
const CHESTS := [
	{"id": "m", "at": [1, 0], "item": "item.neon_rat_tail", "count": 3},
	{"id": "g", "at": [2, 0], "item": "equip.twin_edge"},
	{"id": "y", "at": [3, 0], "money": 100},
	{"id": "k", "at": [4, 0], "item": "key.moss_card"},
]

static var _f: FloorModel


static func floor_def() -> FloorModel:
	if _f == null:
		_f = FloorLoader.parse_text(JSON.stringify(Fx.floor_dict(GRID, {"chests": CHESTS})), "fx.json").floor_def
	return _f


func _game(seed_value: int = 3) -> ExplorationState:
	return Fx.game(floor_def(), seed_value, "full")


func _last(events: Array[Dictionary]) -> Dictionary:
	return events[-1] if not events.is_empty() else {}


func _do(s: ExplorationState, a: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, a, "full")


## R1 (M-R1a 인카운트보다 먼저 상자 이벤트, M-R1b 연 상자에도 이벤트): 멈춘 칸의 닫힌 상자만 묻는다.
func test_chest_event_on_stop() -> void:
	var s := _game()
	var ev := _do(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved", "chest"] as Array[String], "닫힌 상자 칸에 멈춤")
	check_eq(_last(ev), {"type": "chest", "chest": "m"}, "상자 id")
	check_eq(ExplorationRules.question_here(s), {"kind": "chest", "chest": "m"}, "question_here 상자")
	# 인카운트가 난 걸음에는 묻지 않는다.
	var e := _game()
	e.encounter.danger = e.encounter.threshold - 1
	var ev2 := _do(e, A.FORWARD)
	check(e.encounter.pending and not Fx.types(ev2).has("chest") and Fx.types(ev2)[-1] == "encounter", "인카운트 뒤에는 상자 이벤트 없음 %s" % str(Fx.types(ev2)))
	# 연 상자 칸에는 묻지 않는다.
	_do(s, A.OPEN)
	check_eq(ExplorationRules.question_here(s), {}, "연 상자는 물음 없음")
	_do(s, A.BACK)
	check_eq(Fx.types(_do(s, A.FORWARD)), ["moved"] as Array[String], "연 상자 칸에 다시 멈춰도 이벤트 없음")


## R1: 조사 — 닫힌 상자는 다시 묻고, 연 상자는 빈 상자, 바라본 숨은 통로가 먼저.
func test_investigate_on_chest() -> void:
	var s := _game()
	_do(s, A.FORWARD)
	s.party.facing = Dir.N
	check_eq(_last(_do(s, A.INVESTIGATE)), {"type": "chest", "chest": "m"}, "닫힌 상자: 다시 묻는다")
	s.party.facing = Dir.S
	check_eq(Fx.types(_do(s, A.INVESTIGATE)), ["passage_found"] as Array[String], "바라본 숨은 통로가 먼저")
	check_eq(_last(_do(s, A.INVESTIGATE)), {"type": "chest", "chest": "m"}, "통로를 찾은 뒤에는 상자")
	_do(s, A.OPEN)
	check_eq(_last(_do(s, A.INVESTIGATE)), {"type": "chest_empty", "chest": "m"}, "연 상자: 빈 상자")
	s.party.at = Vector2i(0, 0)
	check_eq(Fx.types(_do(s, A.INVESTIGATE)), ["nothing_found"] as Array[String], "상자 없는 칸")


## R2 (M-R2a count 무시, M-R2b 열었다고 표시 안 함, M-R2c OPEN 이 걸음을 더함, M-R6 OPEN 이 난수를 씀): 내용마다 정확히 더한다.
func test_open_each_content() -> void:
	var s := _game()
	s.materials = {"item.neon_rat_tail": 2}
	var want := [
		["m", {"type": "chest_opened", "chest": "m", "item": "item.neon_rat_tail", "count": 3}],
		["g", {"type": "chest_opened", "chest": "g", "item": "equip.twin_edge", "count": 1}],
		["y", {"type": "chest_opened", "chest": "y", "money": 100}],
		["k", {"type": "chest_opened", "chest": "k", "item": "key.moss_card", "count": 1}],
	]
	var money0 := s.money
	for w in want:
		_do(s, A.FORWARD)
		var steps := s.steps
		var danger := s.encounter.danger
		var rng := s.rng.get_state()
		var ev := _do(s, A.OPEN)
		check_eq(ev, [w[1]] as Array[Dictionary], "%s: 이벤트" % w[0])
		check(s.world.is_chest_opened(w[0]), "%s: 연 상자로 기록" % w[0])
		check_eq([s.steps, s.encounter.danger, s.rng.get_state()], [steps, danger, rng], "%s: 걸음·위험도·난수 그대로" % w[0])
	check_eq(s.materials, {"item.neon_rat_tail": 5}, "소재 2 + 3")
	check_eq(s.gear_bag, {"equip.twin_edge": 1}, "장비 가방")
	check_eq(s.money, money0 + 100, "소지금 +100")
	check_eq(s.key_items, {"key.moss_card": true}, "귀중품")
	var r := SaveCodec.decode(SaveCodec.encode(s), Fx.defs(floor_def()))
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "연 뒤 저장·읽기 같은 해시 %s" % r.error)


## R3 (M-R3 일부만 꺼내거나 상한에서 자름): 넣을 자리가 없으면 아무것도 바꾸지 않고 상자는 닫힌 채.
func test_full_keeps_chest_closed() -> void:
	for x in [["m", 1, "materials", {"item.neon_rat_tail": 9997}, {"item.neon_rat_tail": 9990}, "item.neon_rat_tail"],
			["g", 2, "gear_bag", {"equip.twin_edge": 99}, {"equip.twin_edge": 98}, "equip.twin_edge"]]:
		var s := _game()
		s.set(x[2], (x[3] as Dictionary).duplicate())
		s.party.at = Vector2i(x[1], 0)
		var before := SaveCodec.state_hash(s)
		var ev := _do(s, A.OPEN)
		check_eq(ev, [{"type": "chest_full", "chest": x[0], "item": x[5]}] as Array[Dictionary], "%s: chest_full" % x[0])
		check_eq(SaveCodec.state_hash(s), before, "%s: 상태 그대로" % x[0])
		s.set(x[2], (x[4] as Dictionary).duplicate())
		var ok := _do(s, A.OPEN)
		check(ok[0]["type"] == "chest_opened" and s.world.is_chest_opened(x[0]), "%s: 자리가 나면 열린다" % x[0])
	check_eq(_game().materials.get("item.neon_rat_tail", 0), 0, "준비 상태가 공유되지 않음")
	var m := _game()
	m.party.at = Vector2i(1, 0)
	m.materials = {"item.neon_rat_tail": 9996}
	_do(m, A.OPEN)
	check_eq(m.materials["item.neon_rat_tail"], 9999, "딱 상한까지는 연다")
	var y := _game()
	y.party.at = Vector2i(3, 0)
	y.money = BattleLimits.MONEY_MAX - 99
	var before_y := SaveCodec.state_hash(y)
	check_eq(_do(y, A.OPEN), [{"type": "chest_full", "chest": "y", "item": "", "money": 100}] as Array[Dictionary], "돈: chest_full")
	check_eq(SaveCodec.state_hash(y), before_y, "돈: 상태 그대로")
	y.money = BattleLimits.MONEY_MAX - 100
	_do(y, A.OPEN)
	check_eq(y.money, BattleLimits.MONEY_MAX, "돈: 딱 상한까지")


## R4 (M-R4 상자 없는 칸에서도 연다): 막힘·거부는 상태를 바꾸지 않는다.
func test_open_refusals() -> void:
	var s := _game()
	var before := SaveCodec.state_hash(s)
	check_eq(_do(s, A.OPEN), [{"type": "blocked", "reason": "not_chest"}] as Array[Dictionary], "상자 없는 칸")
	check_eq(SaveCodec.state_hash(s), before, "그대로")
	_do(s, A.FORWARD)
	_do(s, A.OPEN)
	before = SaveCodec.state_hash(s)
	check_eq(_do(s, A.OPEN), [{"type": "blocked", "reason": "not_chest"}] as Array[Dictionary], "이미 연 상자")
	check_eq(SaveCodec.state_hash(s), before, "그대로")
	var p := _game()
	p.party.at = Vector2i(2, 0)
	p.encounter.pending = true
	check_eq(_do(p, A.OPEN), [{"type": "rejected", "reason": "pending"}] as Array[Dictionary], "전투 대기")
	p.encounter.pending = false
	p.wiped = true
	check_eq(_do(p, A.OPEN), [{"type": "rejected", "reason": "wiped"}] as Array[Dictionary], "전멸")
	var t := ExplorationRules.new_game(Fx.defs(floor_def()), 3, "full", true)
	check_eq(_do(t, A.OPEN), [{"type": "rejected", "reason": "town"}] as Array[Dictionary], "마을")
	check(not p.world.is_chest_opened("g") and p.gear_bag.is_empty(), "거부된 OPEN 은 열지 않는다")
	check_eq([ExplorationRules.action_from_name("open"), A.OPEN, A.ENTER, A.STAIRS], [A.OPEN, 10, 9, 8], "행동 값(뒤에 더함)")


## question_here: 계단(시험 층 f1 의 (15,17))은 stairs, 상자 없는 칸은 빈 사전.
func test_question_here_stairs() -> void:
	var s := Fx.game(Fx.f1(), 1, "full")
	s.party.at = Vector2i(15, 17)
	check_eq(ExplorationRules.question_here(s), {"kind": "stairs", "way": "down", "to": "f2_test"}, "계단")
	s.party.at = Vector2i(14, 17)
	check_eq(ExplorationRules.question_here(s), {}, "아무것도 없음")


## R6: 같은 행동열이면 같은 이벤트·해시(상자 열기·가득·빈 상자 포함).
func test_chest_determinism() -> void:
	var names := ["forward", "open", "open", "forward", "investigate", "open", "forward", "open", "forward", "open", "back", "investigate"]
	var out := []
	for k in 2:
		var s := _game(9)
		var evs := []
		for n in names:
			evs.append(_do(s, ExplorationRules.action_from_name(n)))
		out.append([JSON.stringify(evs), SaveCodec.state_hash(s)])
	check_eq(out[0], out[1], "두 번 같은 결과")
