extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const ALL_ACTIONS := [A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT, A.TURN_LEFT, A.TURN_RIGHT, A.INVESTIGATE]


func _corridor(lo: int, hi: int, extra: Dictionary = {}) -> ExplorationState:
	var d := {"encounter": {"danger_per_step": 10, "threshold_min": lo, "threshold_max": hi}}
	d.merge(extra, true)
	return Fx.game(Fx.row_floor("......", "     ", d))


func test_danger_per_step_and_free_actions() -> void:
	var s := _corridor(1000, 1000)
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check_eq(s.encounter.danger, 10, "걸음마다 증가")
	for action in [A.TURN_LEFT, A.TURN_RIGHT, A.INVESTIGATE]:
		ExplorationRules.apply(s, action, "floor")
	s.party.facing = Dir.N
	ExplorationRules.apply(s, A.FORWARD, "floor")  # 막힘
	check_eq(s.encounter.danger, 10, "회전·조사·막힘 0")


func test_safe_zone_adds_nothing() -> void:
	var s := _corridor(1000, 1000, {"zones": [{"id": "safe", "rect": [0, 0, 2, 0], "danger_per_step": 0}]})
	ExplorationRules.apply(s, A.FORWARD, "floor")
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check_eq(s.encounter.danger, 0, "안전 구역 0")
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check_eq(s.encounter.danger, 10, "구역 밖은 기본값")


func test_encounter_triggers_at_threshold() -> void:
	var s := _corridor(30, 30)
	var t := []
	for i in 3:
		t.append(Fx.types(ExplorationRules.apply(s, A.FORWARD, "floor")))
	check_eq(t[2], ["moved", "encounter"], "세 걸음째 인카운트")
	check(s.encounter.pending, "전투 대기")


func test_rejected_while_pending_keeps_state() -> void:
	var s := _corridor(10, 10)
	ExplorationRules.apply(s, A.FORWARD, "full")
	check(s.encounter.pending, "대기")
	var h := SaveCodec.state_hash(s)
	var rng := s.rng.get_state()
	for action in ALL_ACTIONS:
		check_eq(ExplorationRules.apply(s, action, "full"), [{"type": "rejected", "reason": "pending"}] as Array[Dictionary], "대기 중 거부 %d" % action)
	check_eq(SaveCodec.state_hash(s), h, "상태 불변")
	check_eq(s.rng.get_state(), rng, "난수 불변")


func test_rejected_while_wiped_keeps_state() -> void:
	var s := _corridor(1000, 1000)
	for m in s.party.members:
		m.hp = 0
	s.wiped = true
	var h := SaveCodec.state_hash(s)
	for action in ALL_ACTIONS:
		check_eq(ExplorationRules.apply(s, action, "floor"), [{"type": "rejected", "reason": "wiped"}] as Array[Dictionary], "전멸 중 거부 %d" % action)
	check_eq(SaveCodec.state_hash(s), h, "상태 불변")
	check(not ExplorationRules.resolve_battle(s), "전멸 중 전투 해결 거부")


func test_resolve_battle_once() -> void:
	var s := _corridor(10, 20)
	check(not ExplorationRules.resolve_battle(s), "대기 아닐 때 거부")
	while not s.encounter.pending:
		ExplorationRules.apply(s, A.FORWARD, "floor")
	var expect := GameRng.new()
	expect.set_state(s.rng.get_state())
	check(ExplorationRules.resolve_battle(s), "해결")
	check_eq([s.encounter.danger, s.encounter.pending], [0, false], "위험도 0·대기 해제")
	check_eq(s.encounter.threshold, expect.randi_range(10, 20), "한계값을 GameRng 로 새로 뽑음")
	var h := SaveCodec.state_hash(s)
	check(not ExplorationRules.resolve_battle(s), "두 번째 해결 거부")
	check_eq(SaveCodec.state_hash(s), h, "중복 해결은 상태 불변")


func test_threshold_range_and_same_seed_sequence() -> void:
	var f := Fx.f1()
	var seqs := []
	for run in 2:
		var s := Fx.game(f, 777)
		var seq := [s.encounter.threshold]
		for i in 30:
			s.encounter.pending = true
			ExplorationRules.resolve_battle(s)
			seq.append(s.encounter.threshold)
		seqs.append(seq)
	check_eq(seqs[0], seqs[1], "같은 시드면 같은 한계값 열")
	check(seqs[0].all(func(t: int) -> bool: return t >= 120 and t <= 240), "한계값 범위 120~240")
	var other := Fx.game(f, 778).encounter.threshold
	check(seqs[0].size() == 31 and (other != seqs[0][0] or Fx.game(f, 779).encounter.threshold != seqs[0][0]), "다른 시드는 다른 열")


func test_gauge_clamped_and_colors() -> void:
	var e := EncounterState.new()
	e.threshold = 200
	check_eq(e.gauge(), 0.0, "0")
	e.danger = 99
	check_eq(e.gauge_color(), "blue", "0.5 미만 파랑")
	e.danger = 100
	check_eq(e.gauge_color(), "yellow", "0.5 노랑")
	e.danger = 170
	check_eq(e.gauge_color(), "red", "0.85 빨강")
	e.danger = 500
	check_eq(e.gauge(), 1.0, "1 로 고정")
