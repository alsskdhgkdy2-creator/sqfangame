## 잠긴 문 규칙(M3 A3): 열쇠 없이 부딪히면 locked, 열쇠로 정면 전진·조사만 연다(걸음 없음), 뒤·옆·미끄러짐은 lock_closed,
## 열면 양쪽으로 지나가고 반대쪽에서도 열며 열쇠는 남는다, 봉인은 늘 sealed, 겉모습·지식·자동 지도, 연 뒤 저장.
## 시험마다 죽이는 변이(설계 노트 §8.2, M-R5…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const KEY := "key.moss_card"

## 위 줄: (0,0) 시작(동쪽), (1,0) 얼음, (1,0)|(2,0) 열쇠 문, (2,0)|(3,0) 봉인 문. (0,0) 아래 (0,1) 에 열쇠 상자 k.
const GRID := [
	"+-+-+-+-+",
	"|. =K.K.|",
	"+ +-+-+-+",
	"|.|.|.|.|",
	"+-+-+-+-+",
]
static var LOCK := FloorModel.edge_of(Vector2i(1, 0), Dir.E)
static var SEAL := FloorModel.edge_of(Vector2i(2, 0), Dir.E)

static var _f: FloorModel


static func floor_def() -> FloorModel:
	if _f == null:
		_f = Fx.floor_of(GRID, {
			"locks": [{"at": [1, 0], "dir": "E", "key": KEY}, {"at": [3, 0], "dir": "W", "seal": "boss"}],
			"chests": [{"id": "k", "at": [0, 1], "item": KEY}],
		})
	return _f


func _do(s: ExplorationState, a: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, a, "full")


## 새 게임. with_key 면 실제로 (0,1) 상자를 열어 열쇠를 얻고 (0,0) 동쪽을 본다.
func _game(with_key: bool = false) -> ExplorationState:
	var s := Fx.game(floor_def(), 3, "full")
	if with_key:
		Fx.walk(s, "S", "full")
		_do(s, A.OPEN)
		Fx.walk(s, "N", "full")
		Fx.face(s, Dir.E, "full")
	return s


func _place(s: ExplorationState, at: Vector2i, facing: int) -> void:
	s.party.at = at
	s.party.facing = facing


func test_fixture() -> void:
	var f := floor_def()
	check(f != null and f.edge_kind(LOCK) == FloorModel.Edge.LOCK and f.edge_kind(SEAL) == FloorModel.Edge.LOCK, "열쇠 문·봉인 문")
	check(f.lock_key(LOCK) == KEY and f.is_sealed(SEAL) and not f.is_sealed(LOCK), "열쇠·봉인")
	check(_game(true).key_items.has(KEY) and not _game().key_items.has(KEY), "열쇠 얻기")


## 열쇠 없이: 부딪히면 locked, 조사도 locked, 상태 그대로. 얼음으로 미끄러져 와도 문 앞에서 멈춘다.
func test_locked_without_key() -> void:
	var s := _game()
	var ev := _do(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved"] as Array[String], "얼음 칸에서 문 앞에 멈춤")
	check_eq(s.party.at, Vector2i(1, 0), "(1,0)")
	var before := SaveCodec.state_hash(s)
	check_eq(_do(s, A.FORWARD), [{"type": "blocked", "reason": "locked"}] as Array[Dictionary], "부딪힘")
	check_eq(_do(s, A.INVESTIGATE), [{"type": "blocked", "reason": "locked"}] as Array[Dictionary], "조사")
	check_eq(SaveCodec.state_hash(s), before, "상태 그대로")
	check_eq(ExplorationRules.block_reason(s.floor_def, s.world, Vector2i(1, 0), Dir.E), "locked", "열쇠 인자 없으면 locked")


## M-R5c(옆걸음이 연다): 열쇠가 있어도 뒤·옆걸음·미끄러짐은 lock_closed 이고 열지 않는다. 정면 전진만 연다(이동·걸음 없음).
func test_key_opens_forward_only() -> void:
	var s := _game(true)
	var ev := _do(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved"] as Array[String], "얼음 미끄러짐은 문을 열지 않는다")
	check(not s.world.is_lock_open(LOCK), "미끄러진 뒤 닫힘")
	_do(s, A.TURN_LEFT)
	check_eq(s.party.facing, Dir.N, "북쪽을 본다")
	check_eq(_do(s, A.STRAFE_RIGHT), [{"type": "blocked", "reason": "lock_closed"}] as Array[Dictionary], "옆걸음")
	_do(s, A.TURN_LEFT)
	check_eq(s.party.facing, Dir.W, "서쪽을 본다")
	check_eq(_do(s, A.BACK), [{"type": "blocked", "reason": "lock_closed"}] as Array[Dictionary], "뒷걸음")
	check(not s.world.is_lock_open(LOCK), "뒤·옆으로는 닫힘")
	Fx.face(s, Dir.E, "full")
	var steps := s.steps
	var danger := s.encounter.danger
	var rng := s.rng.get_state()
	check_eq(_do(s, A.FORWARD), [{"type": "lock_opened", "edge": LOCK, "key": KEY}] as Array[Dictionary], "정면 전진이 연다")
	check_eq([s.party.at, s.steps, s.encounter.danger, s.rng.get_state()], [Vector2i(1, 0), steps, danger, rng], "움직이지 않고 걸음·위험도·난수 그대로")
	check(s.world.is_lock_open(LOCK), "열림")
	var ev2 := _do(s, A.FORWARD)
	check_eq(Fx.types(ev2), ["moved"] as Array[String], "다음 전진은 지나간다")
	check_eq(s.party.at, Vector2i(2, 0), "(2,0)")


## M-R5a(열쇠가 사라짐)·M-R5b(한쪽에서만 열림): 반대쪽에서도 열고, 열쇠는 남고, 열린 문은 양쪽으로 지나간다(얼음 미끄러짐도).
func test_other_side_and_key_kept() -> void:
	var s := _game(true)
	_place(s, Vector2i(2, 0), Dir.W)
	check_eq(_do(s, A.FORWARD), [{"type": "lock_opened", "edge": LOCK, "key": KEY}] as Array[Dictionary], "반대쪽에서 연다")
	check(s.key_items.has(KEY), "열쇠는 남는다")
	var ev := _do(s, A.FORWARD)
	check_eq(Fx.types(ev), ["moved", "moved"] as Array[String], "서쪽으로 지나 얼음에서 미끄러짐")
	check_eq(s.party.at, Vector2i(0, 0), "(0,0)")
	Fx.face(s, Dir.E, "full")
	_do(s, A.FORWARD)
	check_eq(s.party.at, Vector2i(2, 0), "동쪽으로 열린 문을 미끄러져 지남")
	check_eq(ExplorationRules.block_reason(s.floor_def, s.world, Vector2i(1, 0), Dir.E), "", "열린 문은 막지 않음")
	check_eq(ExplorationRules.block_reason(s.floor_def, s.world, Vector2i(2, 0), Dir.W), "", "반대쪽도")


## 봉인 문은 열쇠가 있든 없든, 어느 쪽에서든 sealed 이고 상태가 그대로다.
func test_sealed_always() -> void:
	for with_key in [false, true]:
		for side in [[Vector2i(2, 0), Dir.E], [Vector2i(3, 0), Dir.W]]:
			var s := _game(with_key)
			_place(s, side[0], side[1])
			var before := SaveCodec.state_hash(s)
			check_eq(_do(s, A.FORWARD), [{"type": "blocked", "reason": "sealed"}] as Array[Dictionary], "봉인 전진 %s %s" % [with_key, side])
			check_eq(_do(s, A.INVESTIGATE), [{"type": "blocked", "reason": "sealed"}] as Array[Dictionary], "봉인 조사 %s %s" % [with_key, side])
			check_eq(SaveCodec.state_hash(s), before, "봉인: 그대로 %s %s" % [with_key, side])
			check(not s.world.is_lock_open(SEAL), "봉인은 닫힘")


## 조사: 열쇠가 있으면 연다(걸음 없음), 없으면 locked.
func test_investigate_lock() -> void:
	var s := _game()
	_place(s, Vector2i(1, 0), Dir.E)
	check_eq(_do(s, A.INVESTIGATE), [{"type": "blocked", "reason": "locked"}] as Array[Dictionary], "열쇠 없음")
	var k := _game(true)
	_place(k, Vector2i(1, 0), Dir.E)
	var steps := k.steps
	check_eq(_do(k, A.INVESTIGATE), [{"type": "lock_opened", "edge": LOCK, "key": KEY}] as Array[Dictionary], "열쇠로 연다")
	check(k.world.is_lock_open(LOCK) and k.steps == steps and k.party.at == Vector2i(1, 0), "열림, 걸음·위치 그대로")
	check_eq(_do(k, A.INVESTIGATE), [{"type": "nothing_found"}] as Array[Dictionary], "열린 문 조사")


## M-R5d(지식을 다시 보지 않음): 겉모습 locked → door, 지식·자동 지도, 연 뒤 저장·읽기가 같은 해시.
func test_look_knowledge_and_save() -> void:
	var s := _game(true)
	_do(s, A.FORWARD)
	check_eq(ExplorationRules.look_of(s.floor_def, s.world, LOCK), "locked", "닫힌 겉모습")
	check_eq(s.knowledge.look_of(LOCK), "locked", "지식: locked")
	check_eq(s.annotation.edge_mark(LOCK), "door", "자동 지도: 문")
	check_eq(ExplorationRules.look_of(s.floor_def, s.world, SEAL), "locked", "봉인도 locked 겉모습")
	_do(s, A.FORWARD)
	check_eq(ExplorationRules.look_of(s.floor_def, s.world, LOCK), "door", "연 겉모습")
	check_eq(s.knowledge.look_of(LOCK), "door", "지식: door")
	check_eq(s.annotation.edge_mark(LOCK), "door", "자동 지도: 그대로 문")
	var defs := Fx.defs(floor_def())
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok(), "연 뒤 읽기 %s" % r.error)
	if r.ok():
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "같은 해시")
		check(r.state.world.is_lock_open(LOCK) and r.state.key_items.has(KEY), "열림·열쇠 저장")
