extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action


## 세 칸 복도, 가운데 칸 북쪽에 방 하나. v(2,0) 문, h(1,1) 숨은 통로.
const GRID := [
	"+-+-+-+",
	"|. .D.|",
	"+-+H+-+",
	"|#|.|#|",
	"+-+-+-+",
]


func _game(automap: String = "floor") -> ExplorationState:
	return Fx.game(Fx.floor_of(GRID), 1, automap)


func _snapshot(s: ExplorationState) -> String:
	var d := SaveCodec.state_to_dict(s)
	var r: Dictionary = d["floor_states"][d["floor"]]
	return JSON.stringify([r["world"], r["knowledge"]], "", true)


func test_drawn_wall_does_not_block_and_erased_wall_still_blocks() -> void:
	var s := _game("full")
	s.annotation.paint_edge(Vector3i(1, 0, 1), "wall")
	check_eq(ExplorationRules.apply(s, A.FORWARD, "full")[0]["type"], "moved", "그린 벽을 지나감")
	var north := Vector3i(1, 0, 0)
	check_eq(s.annotation.edges.get(north), "wall", "자동 벽 표시")
	s.annotation.erase_edge(north)
	s.party.facing = Dir.N
	check_eq(ExplorationRules.apply(s, A.FORWARD, "full"), [{"type": "blocked", "reason": "wall"}] as Array[Dictionary], "지운 벽도 막힘")


func test_map_edits_do_not_touch_world_or_knowledge() -> void:
	var s := _game()
	var before := _snapshot(s)
	var m := s.annotation
	m.begin_stroke()
	m.paint_floor(Vector2i(2, 0), 3)
	m.paint_edge(Vector3i(1, 1, 0), "door")
	m.end_stroke()
	m.set_icon(Vector2i(1, 1), "arrow", Dir.E)
	m.set_memo(Vector2i(0, 0), "출발")
	m.toggle_edge(Vector3i(2, 0, 1), "wall")
	m.erase_cell(Vector2i(0, 0))
	m.undo()
	check_eq(_snapshot(s), before, "세계·방문 기록 불변")


func test_new_game_records_start_cell() -> void:
	for mode in ["off", "floor", "full"]:
		var s := _game(mode)
		check(s.knowledge.is_visited(Vector2i(0, 0)), "%s: 시작 칸 방문" % mode)
		for d in 4:
			check(not s.knowledge.look_of(FloorModel.edge_of(Vector2i(0, 0), d)).is_empty(), "%s: 시작 칸 경계 %d 관찰" % [mode, d])
		check_eq(s.annotation.floors.has(Vector2i(0, 0)), mode != "off", "%s: 시작 칸 자동 색" % mode)
		check_eq(s.annotation.edges.size(), 3 if mode == "full" else 0, "%s: 시작 칸 자동 벽" % mode)


func test_automap_modes() -> void:
	var off := _game("off")
	ExplorationRules.apply(off, A.FORWARD, "off")
	check(off.annotation.floors.is_empty() and off.annotation.edges.is_empty(), "off: 지도 그림 없음")
	check(off.knowledge.is_visited(Vector2i(1, 0)), "off: 방문 기록은 남음")
	var fl := _game("floor")
	ExplorationRules.apply(fl, A.FORWARD, "floor")
	check_eq(fl.annotation.floors.get(Vector2i(1, 0)), 0, "floor: 자동 색 0")
	check(fl.annotation.edges.is_empty(), "floor: 경계 표시 없음")
	var full := _game("full")
	ExplorationRules.apply(full, A.FORWARD, "full")
	check_eq(full.annotation.edges.get(Vector3i(1, 0, 0)), "wall", "full: 벽")
	check_eq(full.annotation.edges.get(Vector3i(2, 0, 1)), "door", "full: 문")
	check_eq(full.annotation.edges.get(Vector3i(1, 1, 0)), "wall", "full: 못 찾은 통로는 벽")
	check(full.annotation.auto_edges.has(Vector3i(2, 0, 1)), "full: 자동 목록")
	check(not full.annotation.floors.has(Vector2i(2, 0)), "가 보지 않은 칸은 공개하지 않음")


func test_automap_does_not_overwrite_player() -> void:
	var s := _game("full")
	s.annotation.paint_floor(Vector2i(1, 0), 2)
	s.annotation.paint_edge(Vector3i(1, 0, 0), "door")
	ExplorationRules.apply(s, A.FORWARD, "full")
	check_eq(s.annotation.floors[Vector2i(1, 0)], 2, "플레이어 색 유지")
	check_eq(s.annotation.edges[Vector3i(1, 0, 0)], "door", "플레이어 경계 표시 유지")
	check(not s.annotation.auto_edges.has(Vector3i(1, 0, 0)), "플레이어 표시는 자동 목록 밖")


func test_erased_auto_mark_comes_back_on_revisit() -> void:
	var s := _game("full")
	var north := Vector3i(0, 0, 0)
	s.annotation.erase_edge(north)
	check(not s.annotation.edges.has(north), "지움")
	ExplorationRules.apply(s, A.FORWARD, "full")
	ExplorationRules.apply(s, A.BACK, "full")
	check_eq(s.annotation.edges.get(north), "wall", "다시 들르면 다시 생김")
	check(s.annotation.auto_edges.has(north), "다시 자동 목록")


func test_found_passage_clears_only_auto_wall() -> void:
	var e := Vector3i(1, 1, 0)
	var s := _game("full")
	ExplorationRules.apply(s, A.FORWARD, "full")
	ExplorationRules.apply(s, A.TURN_RIGHT, "full")
	check(s.annotation.auto_edges.has(e), "통로 자리의 자동 벽")
	ExplorationRules.apply(s, A.INVESTIGATE, "full")
	check(not s.annotation.edges.has(e) and not s.annotation.auto_edges.has(e), "자동 벽 표시 지움")
	var t := _game("full")
	t.annotation.paint_edge(e, "wall")
	ExplorationRules.apply(t, A.FORWARD, "full")
	ExplorationRules.apply(t, A.TURN_RIGHT, "full")
	ExplorationRules.apply(t, A.INVESTIGATE, "full")
	check_eq(t.annotation.edges.get(e), "wall", "플레이어가 그린 벽은 둠")


func test_player_fixing_auto_mark_leaves_auto_list() -> void:
	var s := _game("full")
	var north := Vector3i(0, 0, 0)
	s.annotation.paint_edge(north, "door")
	check(not s.annotation.auto_edges.has(north), "고치면 자동 목록에서 빠짐")
	s.annotation.undo()
	check(s.annotation.auto_edges.has(north) and s.annotation.edges[north] == "wall", "실행 취소는 자동 여부까지 되돌림")


func test_undo_reverts_only_that_edit() -> void:
	var s := _game("full")
	var m := s.annotation
	m.paint_floor(Vector2i(2, 0), 4)
	ExplorationRules.apply(s, A.FORWARD, "full")
	ExplorationRules.apply(s, A.FORWARD, "full")
	check_eq(m.floors[Vector2i(2, 0)], 4, "자동 기록이 플레이어 색을 덮지 않음")
	check(m.undo(), "실행 취소")
	check(not m.floors.has(Vector2i(2, 0)), "그 편집 항목만 되돌림(이전 값 없음)")
	check_eq(m.floors.get(Vector2i(1, 0)), 0, "다른 칸 자동 기록은 남음")
	check(m.edges.has(Vector3i(2, 0, 0)), "다른 경계 자동 기록은 남음")
	check(not m.undo(), "더 되돌릴 것 없음")


func test_drag_is_one_step_and_cancel() -> void:
	var m := MapAnnotation.new(6, 6)
	m.begin_stroke()
	for x in 5:
		m.paint_floor(Vector2i(x, 0), 1)
		m.paint_floor(Vector2i(x, 0), 2)
	m.end_stroke()
	check_eq(m.undo_depth(), 1, "끌기 한 번 = 한 단계")
	m.undo()
	check(m.floors.is_empty(), "한 번에 모두 되돌림")
	m.begin_stroke()
	m.paint_edge(Vector3i(0, 0, 0), "wall")
	m.cancel_stroke()
	check(m.edges.is_empty() and m.undo_depth() == 0, "확정 전 취소")


func test_undo_limit_100() -> void:
	var m := MapAnnotation.new(20, 20)
	for i in 120:
		m.paint_floor(Vector2i(i % 20, i / 20), 1 + i % 4)
	check_eq(m.undo_depth(), 100, "100단계 한도")
	var n := 0
	while m.undo():
		n += 1
	check_eq(n, 100, "100번까지 되돌림")
	check_eq(m.floors.size(), 20, "앞 20개 편집은 남음")


func test_edit_validation() -> void:
	var m := MapAnnotation.new(4, 4)
	check(not m.set_memo(Vector2i(0, 0), "가".repeat(41)), "41자 거부")
	check(m.set_memo(Vector2i(0, 0), "가".repeat(40)), "40자 허용")
	check(m.set_memo(Vector2i(0, 0), "") and not m.memos.has(Vector2i(0, 0)), "비우면 지움")
	check(not m.set_icon(Vector2i(0, 0), "arrow"), "화살표는 방향 필요")
	check(m.set_icon(Vector2i(0, 0), "arrow", Dir.W), "화살표 방향")
	check(not m.set_icon(Vector2i(0, 0), "dragon"), "모르는 아이콘")
	check(not m.paint_floor(Vector2i(0, 0), 0) and not m.paint_floor(Vector2i(0, 0), 5), "색은 1~4")
	check(not m.paint_floor(Vector2i(4, 0), 1), "층 밖 거부")
	check(m.toggle_edge(Vector3i(0, 0, 1), "wall") and m.edges.has(Vector3i(0, 0, 1)), "벽 켜기")
	check(m.toggle_edge(Vector3i(0, 0, 1), "wall") and not m.edges.has(Vector3i(0, 0, 1)), "벽 끄기")


func test_end_stroke_reports_change() -> void:
	var m := MapAnnotation.new(6, 6)
	m.begin_stroke()
	check(not m.end_stroke(), "빈 끌기는 false")
	m.begin_stroke()
	m.paint_floor(Vector2i(0, 0), 1)
	check(m.end_stroke(), "바뀐 끌기는 true")
	m.begin_stroke()
	m.paint_floor(Vector2i(0, 0), 1)
	check(not m.end_stroke(), "같은 값으로 칠하면 false")
	m.begin_stroke()
	m.paint_edge(Vector3i(1, 1, 0), "wall")
	m.unpaint_edge(Vector3i(1, 1, 0), "wall")
	check(not m.end_stroke(), "켰다 끈 끌기는 바뀐 것 없음")
	check_eq(m.undo_depth(), 1, "바뀐 것 없는 끌기는 기록하지 않음")


func test_end_stroke_with_full_undo_history() -> void:
	var m := MapAnnotation.new(20, 20)
	for i in 100:
		m.paint_floor(Vector2i(i % 20, i / 20), 1)
	check_eq(m.undo_depth(), 100, "가득 참")
	m.begin_stroke()
	m.paint_floor(Vector2i(0, 9), 2)
	check(m.end_stroke(), "가득 찬 상태에서도 바뀌면 true")
	m.begin_stroke()
	m.paint_floor(Vector2i(0, 9), 2)
	check(not m.end_stroke(), "가득 찬 상태에서도 바뀐 것 없으면 false")
	check_eq(m.undo_depth(), 100, "한도 유지")


func test_cancel_stroke_not_recorded() -> void:
	var m := MapAnnotation.new(6, 6)
	m.paint_floor(Vector2i(0, 0), 3)
	m.begin_stroke()
	m.paint_floor(Vector2i(0, 0), 4)
	m.paint_floor(Vector2i(1, 0), 4)
	m.paint_edge(Vector3i(2, 2, 1), "door")
	m.cancel_stroke()
	check_eq(m.floors, {Vector2i(0, 0): 3}, "끌기 변경을 되돌림")
	check(m.edges.is_empty(), "경계도 되돌림")
	check_eq(m.undo_depth(), 1, "취소한 끌기는 기록하지 않음")
	m.undo()
	check(m.floors.is_empty(), "그 전 단계는 그대로 되돌릴 수 있음")


func test_explicit_on_off_for_wall_drag() -> void:
	var m := MapAnnotation.new(6, 6)
	var a := Vector3i(1, 0, 0)
	var b := Vector3i(2, 0, 0)
	m.paint_edge(b, "wall")
	m.paint_edge(Vector3i(3, 0, 0), "door")
	# 첫 경계가 비어 있으니 이번 끌기는 켜기만.
	check_eq(m.edge_mark(a), "", "첫 경계 비어 있음")
	m.begin_stroke()
	for e in [a, b]:
		m.paint_edge(e, "wall")
	m.end_stroke()
	check(m.edge_mark(a) == "wall" and m.edge_mark(b) == "wall", "켜기만: 이미 켜진 것도 켜진 채")
	# 첫 경계가 켜져 있으니 이번 끌기는 끄기만, 다른 표시(door)는 두기.
	m.begin_stroke()
	for e in [a, b, Vector3i(3, 0, 0), Vector3i(4, 0, 0)]:
		m.unpaint_edge(e, "wall")
	m.end_stroke()
	check(m.edge_mark(a) == "" and m.edge_mark(b) == "", "끄기만")
	check_eq(m.edge_mark(Vector3i(3, 0, 0)), "door", "다른 표시는 둠")
	check(m.edge_mark(Vector3i(4, 0, 0)) == "", "빈 경계는 켜지 않음")
