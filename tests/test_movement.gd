extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

## 5×3 시험 층.
## v(2,0) 문, h(4,1) 지름길(아래 칸 (4,1) 쪽에서만 열림), v(1,1) 동쪽으로만, v(3,1) 서쪽으로만,
## h(2,2) 남쪽으로만, h(4,2) 북쪽으로만, h(0,2)·v(2,2) 숨은 통로.
const GRID := [
	"+-+-+-+-+-+",
	"|. .D. . .|",
	"+ +-+ +-+L+",
	"|.>. .<. .|",
	"+H+-+v+-+^+",
	"|. .H. . .|",
	"+-+-+-+-+-+",
]


func _game() -> ExplorationState:
	return Fx.game(Fx.floor_of(GRID, {"shortcuts": [{"at": [4, 1], "dir": "N"}]}))


func _place(s: ExplorationState, x: int, y: int, facing: int) -> void:
	s.party.at = Vector2i(x, y)
	s.party.facing = facing


func _act(s: ExplorationState, action: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, action, "floor")


func _blocked(s: ExplorationState, action: int, reason: String, label: String) -> void:
	var at := s.party.at
	var steps := s.steps
	var ev := _act(s, action)
	check_eq(ev, [{"type": "blocked", "reason": reason}] as Array[Dictionary], label)
	check_eq(s.party.at, at, label + " 위치")
	check_eq(s.steps, steps, label + " 걸음")


func test_forward_back_strafe_turn() -> void:
	var s := _game()
	check_eq(_act(s, A.FORWARD), [{"type": "moved", "from": Vector2i(0, 0), "to": Vector2i(1, 0), "dir": Dir.E, "via": "step", "door": false}] as Array[Dictionary], "전진")
	check_eq(_act(s, A.TURN_RIGHT), [{"type": "turned", "facing": Dir.S}] as Array[Dictionary], "오른쪽 회전")
	_blocked(s, A.BACK, "wall", "후진(북쪽 테두리)")
	var ev := _act(s, A.STRAFE_LEFT)  # 남쪽을 보고 왼쪽 = 동쪽, 문
	check_eq(ev[0]["to"], Vector2i(2, 0), "왼쪽 평행 이동")
	check_eq(ev[0]["door"], true, "문을 지남")
	check_eq(s.party.facing, Dir.S, "평행 이동은 방향 유지")
	ev = _act(s, A.STRAFE_RIGHT)  # 서쪽, 문
	check_eq(ev[0]["to"], Vector2i(1, 0), "오른쪽 평행 이동(문 반대 방향)")
	_act(s, A.TURN_LEFT)
	check_eq(s.party.facing, Dir.E, "왼쪽 회전")
	ev = _act(s, A.BACK)
	check_eq(ev[0]["to"], Vector2i(0, 0), "후진")
	check_eq(s.party.facing, Dir.E, "후진은 방향 유지")
	check_eq(s.steps, 4, "걸음 수(회전·막힘 제외)")


func test_oneway_both_directions_with_back_and_strafe() -> void:
	var s := _game()
	_place(s, 1, 1, Dir.E)
	_blocked(s, A.BACK, "oneway", "동쪽으로만: 후진으로 서쪽")
	_place(s, 1, 1, Dir.W)
	_blocked(s, A.FORWARD, "oneway", "동쪽으로만: 전진으로 서쪽")
	_place(s, 0, 1, Dir.W)
	check_eq(_act(s, A.BACK)[0]["to"], Vector2i(1, 1), "후진으로 동쪽 통과")
	_place(s, 0, 1, Dir.N)
	check_eq(_act(s, A.STRAFE_RIGHT)[0]["to"], Vector2i(1, 1), "평행 이동으로 동쪽 통과")
	_place(s, 2, 1, Dir.N)
	_blocked(s, A.STRAFE_RIGHT, "oneway", "서쪽으로만: 평행 이동으로 동쪽")
	_place(s, 3, 1, Dir.W)
	check_eq(_act(s, A.FORWARD)[0]["to"], Vector2i(2, 1), "서쪽으로만: 서쪽 통과")
	_place(s, 2, 1, Dir.N)
	check_eq(_act(s, A.BACK)[0]["to"], Vector2i(2, 2), "남쪽으로만: 후진으로 통과")
	_blocked(s, A.FORWARD, "oneway", "남쪽으로만: 북쪽")
	_place(s, 4, 2, Dir.N)
	check_eq(_act(s, A.FORWARD)[0]["to"], Vector2i(4, 1), "북쪽으로만: 통과")
	_place(s, 4, 1, Dir.N)
	_blocked(s, A.BACK, "oneway", "북쪽으로만: 남쪽")


func test_door_both_ways() -> void:
	var s := _game()
	_place(s, 1, 0, Dir.E)
	var ev := _act(s, A.FORWARD)
	check(ev[0]["door"] and ev[0]["to"] == Vector2i(2, 0), "동쪽으로 문 통과")
	_act(s, A.TURN_LEFT)
	_act(s, A.TURN_LEFT)
	ev = _act(s, A.FORWARD)
	check(ev[0]["door"] and ev[0]["to"] == Vector2i(1, 0), "서쪽으로 문 통과")


func test_shortcut_rules() -> void:
	var s := _game()
	var e := Vector3i(4, 1, 0)
	_place(s, 4, 0, Dir.S)
	_blocked(s, A.FORWARD, "shortcut_locked", "반대쪽 전진")
	check_eq(_act(s, A.INVESTIGATE), [{"type": "nothing_found"}] as Array[Dictionary], "반대쪽 조사")
	_place(s, 4, 1, Dir.S)
	_blocked(s, A.BACK, "shortcut_closed", "열 수 있는 쪽 후진")
	_place(s, 4, 1, Dir.E)
	_blocked(s, A.STRAFE_LEFT, "shortcut_closed", "열 수 있는 쪽 평행 이동")
	check(not s.world.is_shortcut_open(e), "후진·평행 이동으로는 안 열림")
	_place(s, 4, 1, Dir.N)
	var danger := s.encounter.danger
	check_eq(_act(s, A.FORWARD), [{"type": "shortcut_opened", "edge": e}] as Array[Dictionary], "정면 전진으로 엶")
	check_eq(s.party.at, Vector2i(4, 1), "여는 행동에서는 움직이지 않음")
	check_eq(s.steps, 0, "여는 행동은 걸음 0")
	check_eq(s.encounter.danger, danger, "여는 행동은 위험도 0")
	check(s.world.is_shortcut_open(e), "세계 상태에 기록")
	check_eq(_act(s, A.FORWARD)[0]["to"], Vector2i(4, 0), "연 뒤 북쪽 통과")
	_act(s, A.TURN_RIGHT)
	_act(s, A.TURN_RIGHT)
	check_eq(_act(s, A.FORWARD)[0]["to"], Vector2i(4, 1), "연 뒤 남쪽 통과")


func test_shortcut_opens_by_investigate() -> void:
	var s := _game()
	_place(s, 4, 1, Dir.N)
	check_eq(_act(s, A.INVESTIGATE), [{"type": "shortcut_opened", "edge": Vector3i(4, 1, 0)}] as Array[Dictionary], "조사로 엶")
	check_eq(s.knowledge.look_of(Vector3i(4, 1, 0)), "shortcut", "관찰 갱신")
	check_eq(_act(s, A.INVESTIGATE), [{"type": "nothing_found"}] as Array[Dictionary], "이미 열린 문 조사")


func test_hidden_passage() -> void:
	var s := _game()
	var e := Vector3i(0, 2, 0)
	_place(s, 0, 1, Dir.S)
	ExplorationRules.record_cell(s, s.party.at, "floor")
	check_eq(s.knowledge.look_of(e), "wall", "찾기 전 겉모습은 벽")
	_blocked(s, A.FORWARD, "wall", "찾기 전 막힘")
	var danger := s.encounter.danger
	check_eq(_act(s, A.INVESTIGATE), [{"type": "passage_found", "edge": e}] as Array[Dictionary], "조사로 찾음")
	check_eq(s.knowledge.look_of(e), "passage", "조사 직후 관찰 갱신")
	check_eq([s.steps, s.encounter.danger], [0, danger], "조사는 걸음·위험도 0")
	check_eq(_act(s, A.FORWARD)[0]["to"], Vector2i(0, 2), "찾은 뒤 남쪽")
	check_eq(_act(s, A.BACK)[0]["to"], Vector2i(0, 1), "찾은 뒤 북쪽")
	check_eq(_act(s, A.INVESTIGATE), [{"type": "nothing_found"}] as Array[Dictionary], "이미 찾은 통로")
	_place(s, 1, 2, Dir.E)
	_blocked(s, A.FORWARD, "wall", "다른 숨은 통로는 아직 막힘")


func test_blocked_by_wall_into_void_edge() -> void:
	var s := _game()
	_place(s, 1, 1, Dir.S)
	_blocked(s, A.FORWARD, "wall", "벽")
	check(s.knowledge.visited.size() == 1, "막힘은 기록 없음")
