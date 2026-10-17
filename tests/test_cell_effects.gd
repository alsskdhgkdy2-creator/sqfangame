extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action


func _row(cells: String, inner: String, extra: Dictionary = {}) -> ExplorationState:
	return Fx.game(Fx.row_floor(cells, inner, extra))


func _fwd(s: ExplorationState) -> Array[Dictionary]:
	return ExplorationRules.apply(s, A.FORWARD, "floor")


func _ends(events: Array[Dictionary]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for e in events:
		if e["type"] == "moved":
			out.append(e["to"])
	return out


func test_damage_floor_hits_living_members_only() -> void:
	var s := _row(".~.", "  ")
	s.party.members[1].hp = 2
	s.party.members[2].hp = 0
	var ev := _fwd(s)
	check_eq(Fx.types(ev), ["moved", "damaged"] as Array[String], "이벤트 순서")
	check_eq(ev[1]["amounts"], [3, 2, 0, 3, 3] as Array[int], "대원별 피해(0 미만 없음, 쓰러진 대원 0)")
	check_eq(s.party.members[1].hp, 0, "HP 0 에서 멈춤")
	check_eq(s.party.members[0].hp, 57, "살아 있는 대원 피해")
	check(not s.wiped, "아직 전멸 아님")


func test_damage_floor_wipe_skips_danger_and_rng() -> void:
	var s := _row(".~.", "  ", {"encounter": {"danger_per_step": 50, "threshold_min": 10, "threshold_max": 10}})
	for m in s.party.members:
		m.hp = 1
	var rng_state := s.rng.get_state()
	var ev := _fwd(s)
	check_eq(Fx.types(ev), ["moved", "damaged", "wiped"] as Array[String], "전멸 이벤트, 인카운트 없음")
	check(s.wiped, "전멸")
	check_eq(s.steps, 1, "걸음은 기록")
	check(s.knowledge.is_visited(Vector2i(1, 0)), "방문은 기록")
	check_eq(s.encounter.danger, 0, "위험도 건너뜀")
	check(not s.encounter.pending, "인카운트 건너뜀")
	check_eq(s.rng.get_state(), rng_state, "난수 불변")


func test_slide_stops_at_wall_on_ice() -> void:
	var s := _row(".===", "   ")
	var ev := _fwd(s)
	check_eq(_ends(ev), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i], "지나간 칸")
	check_eq(ev.map(func(e: Dictionary) -> String: return e["via"]), ["step", "slide", "slide"], "step 뒤 slide")
	check_eq(s.party.at, Vector2i(3, 0), "벽 앞 얼음 칸에서 멈춤")
	check_eq(s.steps, 1, "걸음 1")
	check_eq(s.encounter.danger, 10, "위험도 1회")
	for x in 4:
		check(s.knowledge.is_visited(Vector2i(x, 0)), "지나간 칸 방문 %d" % x)
		check(s.annotation.floors.has(Vector2i(x, 0)), "지나간 칸 자동 지도 %d" % x)


func test_slide_enters_floor_and_stops() -> void:
	var s := _row(".==..", "    ")
	_fwd(s)
	check_eq(s.party.at, Vector2i(3, 0), "얼음 다음 바닥 칸에 들어가 멈춤")


func test_slide_through_door() -> void:
	var s := _row(".==.", "  D")
	var ev := _fwd(s)
	check_eq(s.party.at, Vector2i(3, 0), "문을 지나 미끄러짐")
	check(ev[2]["door"] and ev[2]["via"] == "slide", "미끄러지며 문 통과 표시")


func test_slide_and_shortcut() -> void:
	var s := _row(".==.", "  L", {"shortcuts": [{"at": [2, 0], "dir": "E"}]})
	_fwd(s)
	check_eq(s.party.at, Vector2i(2, 0), "닫힌 지름길(열 수 있는 쪽) 앞에서 멈춤")
	check(not s.world.is_shortcut_open(Vector3i(3, 0, 1)), "미끄러짐으로는 안 열림")
	check_eq(Fx.types(_fwd(s)), ["shortcut_opened"] as Array[String], "얼음 위에서 정면 전진으로 엶")
	_fwd(s)
	check_eq(s.party.at, Vector2i(3, 0), "연 뒤 지나감")
	var t := _row(".==.", "  L", {"shortcuts": [{"at": [2, 0], "dir": "E"}]})
	t.world.open_shortcut(Vector3i(3, 0, 1))
	_fwd(t)
	check_eq(t.party.at, Vector2i(3, 0), "열린 지름길은 미끄러져 지나감")
	var u := _row(".==.", "  L", {"shortcuts": [{"at": [3, 0], "dir": "W"}], "start": {"at": [0, 0], "facing": "E"}})
	_fwd(u)
	check_eq(u.party.at, Vector2i(2, 0), "반대쪽 닫힌 지름길 앞에서 멈춤")


func test_slide_and_oneway() -> void:
	var s := _row(".==.", " > ")
	_fwd(s)
	check_eq(s.party.at, Vector2i(3, 0), "허용 방향 일방통행은 미끄러져 지나감")
	var t := _row(".==.", " < ")
	_fwd(t)
	check_eq(t.party.at, Vector2i(1, 0), "반대 방향 일방통행 앞에서 멈춤")
	check_eq(t.steps, 1, "막혀 끝나도 걸음 1")


func test_slide_and_hidden_passage() -> void:
	var s := _row(".===", " H ")
	_fwd(s)
	check_eq(s.party.at, Vector2i(1, 0), "못 찾은 통로 앞에서 멈춤")
	check_eq(Fx.types(ExplorationRules.apply(s, A.INVESTIGATE, "floor")), ["passage_found"] as Array[String], "얼음 위에서 조사")
	_fwd(s)
	check_eq(s.party.at, Vector2i(3, 0), "찾은 통로를 지나 미끄러짐")


func test_slide_ends_on_damage_floor() -> void:
	var s := _row(".==~", "   ")
	var ev := _fwd(s)
	check_eq(Fx.types(ev), ["moved", "moved", "moved", "damaged"] as Array[String], "끝 칸 피해")
	check_eq(s.party.at, Vector2i(3, 0), "피해 바닥에서 멈춤")


func test_slide_danger_uses_last_cell_zone() -> void:
	var safe := {"zones": [{"id": "safe", "rect": [3, 0, 3, 0], "danger_per_step": 0}]}
	var s := _row(".==.", "   ", safe)
	_fwd(s)
	check_eq(s.encounter.danger, 0, "마지막 칸이 안전 구역이면 0")
	var t := _row("...=", "   ", {"zones": [{"id": "hot", "rect": [1, 0, 1, 0], "danger_per_step": 7}]})
	_fwd(t)
	check_eq(t.encounter.danger, 7, "구역 위험도")
	_fwd(t)
	check_eq(t.encounter.danger, 17, "구역 밖은 층 기본값")
