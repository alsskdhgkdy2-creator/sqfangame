## 실제 시야 노드의 연출을 프레임 간격으로 돌리며 카메라 보정(05 §9.2.1)을 잰다.
## 모든 칸·네 방향에서 좌우 회전, 열린 쪽 이동, 막힌 쪽 막힘 연출. 세계는 처음 상태와 장치를 모두 연 상태 둘.
## 시야 영역 화면비: 옛 1280 창의 지도 옆 시야(768×720), 가장 넓은 대상 화면(MAX_SCREEN_ASPECT 2.4, 렌즈 가운데),
## 지도 판을 연 화면 둘(M2.7 R1 렌즈 이동: 1280×720 p = 550/1280, 1728×720 p = 550/1728 → 유효 화면비 ≈ 3.164 = 가장 넓다).
## 연출 중 목표는 play 때 세운 계획(DungeonView._plan_guard: 안전 구간만 지나며 표본 사이 |Δδ| 최댓값이 가장 작은 경로),
## 실제 프레임은 계획 값에 가장 가까운 유효 후보(CameraGuard.solve_near), 정지 자세는 결정적 해(solve).
## 연출마다: 프레임 한도 안에 실제로 끝났는지, 중간 자세가 움직였는지, 끝 자세가 사건에서 따로 구한 도착 자세
## (칸 가운데·yaw_of(방향))인지, 끝 δ 가 그 도착 자세의 정지 해인지 본다.
## 튐 분류: 같은 프레임의 계획 값 변화도 0.2m 를 넘으면 「계획된 튐」, 아니면 「계획 밖의 튐」(실패).
## 계획된 튐이 정말 피할 수 없는지는 계획기와 따로 확인한다(_independent_bounds).
## 단언: 계획 밖의 회전 |Δδ| > 0.2m 프레임 0, 계획된 것은 알려진 칸(PLANNED_JUMP_CELL)에서만 PLANNED_JUMP_MAX 이하이고
## 독립 확인으로도 0.2m 경로가 없다, |Δδ| > 2ε 프레임이 연속성 도입 전보다 적다, 보정 뒤 최소 |w| 유지
## (best-effort 프레임은 정지 규칙의 값 이상), 이동·막힘의 최대 |Δδ| 가 전보다 나쁘지 않다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const FRAME := 1.0 / 60.0
## test_mesh_builder 와 같은 값(회전 중 best-effort 여유의 하한).
const ROTATION_MIN_GAP := 0.025
## 연속성 도입 전(매 프레임 solve, 2026-10-16) f1_test 실측: 회전 |Δδ| > 2ε 프레임 수, 이동·막힘 최대 |Δδ|, 최소 |w|.
const BEFORE := {
	"narrow": {"turn_over_2eps": 580, "move_step": 0.0977, "bump_step": 0.05},
	"max": {"turn_over_2eps": 1002, "move_step": 0.0977, "bump_step": 0.05},
}
const BEFORE_MIN_GAP := 0.0495
## 계획된 회전 튐(> 0.2m)이 나는 칸: 눈 (6, 1, 32)에서 23° 무렵 북쪽 문 h:2:16 의 틀과
## 동쪽 지름길 v:5:17 의 틀(0.25m 격자 정점)이 겹쳐 ±0.25 를 모두 막고(best-effort), 37° 무렵 +0.128~+0.134 만 남는다.
## 세계 둘 × 네 방향 = 8 프레임(2026-10-17 측정, 60Hz). 다른 칸에서 생기거나 늘면 실패.
const PLANNED_JUMP_CELL := "(3, 16)"
const PLANNED_JUMP_MAX := 8
## 연출 하나에 돌리는 프레임 한도(120Hz 의 가장 긴 연출도 30 프레임 안이다).
const FRAME_LIMIT := 240
## 독립 확인의 δ 격자 간격(m).
const GRID := 0.001

## 시야 영역 화면비(세로 720 기준)와 렌즈 이동 비율(지도 판이 덮은 폭 비율). 측정 스크립트가 바꿔 부를 수 있다.
var aspect := CameraGuard.MAX_SCREEN_ASPECT
var lens := 0.0
## 프레임 간격(초, _dt_at). spike_frame 번째 프레임(0부터)만 spike_dt, switch_frame 번째부터는 switch_dt(주기 전환),
## jitter > 0 이면 간격마다 ±jitter 를 고정 시드로 더한다. -1 이면 그 일이 없다.
var frame_dt := FRAME
var spike_frame := -1
var spike_dt := 0.1
var switch_frame := -1
var switch_dt := FRAME
var jitter := 0.0
var _rng := RandomNumberGenerator.new()
## 비어 있지 않으면 연출마다 시작 전에 시야 노드의 프레임 간격 이력을 이것으로 둔다(이 주기로 돌던 상태).
var pre_hist := PackedFloat64Array()
var _sv: SubViewport
var _stats := {}
var _prev := 0.0
var _prev_target := 0.0
var _last_step := 0.0
var _world_name := ""
var _cur_run := {}
## 지금 연출에서 돌린 프레임 수(0부터, _check_frame 이 보는 프레임의 차례).
var _frame_n := 0
## 계획된 큰 튐의 자세(보고용)와 그 연출(독립 확인용). 시험마다 새 객체라 빈 상태에서 시작한다.
var planned_poses: Array[String] = []
var planned_runs: Array[Dictionary] = []


func teardown() -> void:
	if _sv != null and is_instance_valid(_sv):
		if _sv.get_parent() != null:
			_sv.get_parent().remove_child(_sv)
		_sv.free()


func _all_open_world(f: FloorModel) -> WorldState:
	var w := WorldState.new()
	for e in f.edges_of_kind(FloorModel.Edge.SHORTCUT):
		w.open_shortcut(e)
	for e in f.edges_of_kind(FloorModel.Edge.PASSAGE):
		w.find_passage(e)
	return w


func _make_view(f: FloorModel) -> DungeonView:
	_sv = SubViewport.new()
	_sv.size = Vector2i(roundi(720 * aspect), 720)
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(_sv)
	var v := DungeonView.new()
	_sv.add_child(v)
	v.set_process(false)  # 프레임은 시험이 직접 돌린다
	v.speed = 1.0
	v.setup(f, WorldState.new())
	v.set_lens_cover(lens)
	return v


func _reset(kind: String) -> void:
	_stats[kind] = {"animations": 0, "frames": 0, "frames_shifted": 0, "max_delta": 0.0, "max_step": 0.0, "min_gap": INF, "steps_over_eps": 0, "steps_over_2eps": 0, "steps_over_0.2": 0, "best_effort_frames": 0, "max_end_step": 0.0, "planned_over_0.2": 0, "unplanned_over_0.2": 0}


## 도착 자세의 정지 해(보정 시야와 같은 반경의 정점으로, 시야 노드의 계산을 거치지 않고 구한다).
func _static_at(v: DungeonView, cell: Vector2i, facing: int) -> float:
	var eye := DungeonMeshBuilder.cell_center(cell) + Vector3.UP * DungeonView.EYE_HEIGHT
	var fwd := -Basis(Vector3.UP, DungeonView.yaw_of(facing)).z
	return CameraGuard.solve(v._index.near(eye, v.guard_radius), eye, fwd)


## 이번 프레임(0부터)의 간격.
func _dt_at(n: int) -> float:
	if n == spike_frame:
		return spike_dt
	var dt := switch_dt if switch_frame >= 0 and n >= switch_frame else frame_dt
	if jitter > 0.0:
		dt += _rng.randf_range(-jitter, jitter)
	return dt


## 시야 노드의 프레임 간격 이력과 그 중앙값(plan_step)을 둔다(그 주기로 이미 돌던 상태).
static func _set_rate_history(v: DungeonView, hist: PackedFloat64Array) -> void:
	v._dt_hist = hist.duplicate()
	var sorted := hist.duplicate()
	sorted.sort()
	v.plan_step = clampf(sorted[sorted.size() / 2], DungeonView.PLAN_STEP_MIN, DungeonView.PLAN_STEP_MAX)


## 연출 하나를 끝까지 돌린다. 시작 자세의 보정도 프레임 하나로 센다(|Δδ| 의 출발점).
## end_cell·end_facing 은 사건에서 따로 구한 도착 자세.
## 원래 실행을 기록한다(독립 확인은 다시 돌리지 않고 이 기록을 읽는다): 시작 때의 프레임 간격 이력·plan_step·시작 δ,
## 프레임마다 [보정 전 위치, yaw, 보인 δ, 간격](끝 프레임 전까지), 계획 횟수·누적 시간.
func _run(v: DungeonView, kind: String, cell: Vector2i, facing: int, events: Array[Dictionary], move_dir: int, label: String, end_cell: Vector2i, end_facing: int) -> void:
	if not pre_hist.is_empty():
		_set_rate_history(v, pre_hist)
	v.set_pose(cell, facing)
	v.reset_guard_stats()
	v._last_pose = Transform3D()
	v._apply_camera()
	_prev = v.last_guard_delta
	_prev_target = _prev
	_cur_run = {"world": _world_name, "cell": cell, "facing": facing, "events": events, "move_dir": move_dir, "label": label,
		"end_cell": end_cell, "end_facing": end_facing, "recorded": false,
		"start_hist": v._dt_hist.duplicate(), "start_plan_step": v.plan_step, "start_delta": v.last_guard_delta, "frames": []}
	var start_pos := v._view_pos
	var start_yaw := v._view_yaw
	v.play(events, move_dir)
	var st: Dictionary = _stats[kind]
	var n := 0
	var progressed := false
	while v.is_busy() and n < FRAME_LIMIT:
		_frame_n = n
		var dt := _dt_at(n)
		v._process(dt)
		n += 1
		if v.is_busy():
			_cur_run["frames"].append([v._view_pos, v._view_yaw, v.last_guard_delta, dt])
		else:
			_cur_run["end_dt"] = dt
		if v.is_busy() and (not v._view_pos.is_equal_approx(start_pos) or not is_equal_approx(v._view_yaw, start_yaw)):
			progressed = true
		_check_frame(v, st, label)
	_cur_run["plan_count"] = v.plan_count
	_cur_run["plan_ms"] = v.plan_ms_total
	st["plan_count_max"] = maxi(st.get("plan_count_max", 0), v.plan_count)
	st["plan_count_sum"] = st.get("plan_count_sum", 0) + v.plan_count
	st["plan_ms_total_max"] = maxf(st.get("plan_ms_total_max", 0.0), v.plan_ms_total)
	if v.is_busy():
		failures.append("%s: %d 프레임 안에 끝나지 않았다" % [label, FRAME_LIMIT])
		return
	if n >= 2 and not progressed:
		failures.append("%s: 중간 프레임 %d 개 동안 자세가 시작에서 움직이지 않았다" % [label, n - 1])
	# 도착 자세: 사건에서 따로 구한 칸 가운데·방향.
	var want_pos := DungeonMeshBuilder.cell_center(end_cell)
	var want_yaw := DungeonView.yaw_of(end_facing)
	var cam := v.camera_transform()
	if not v._pos.is_equal_approx(want_pos) or not cam.basis.is_equal_approx(Basis(Vector3.UP, want_yaw)):
		failures.append("%s: 끝 자세 %s yaw %.4f ≠ 도착 %s yaw %.4f" % [label, v._pos, v._yaw, want_pos, want_yaw])
	var want := _static_at(v, end_cell, end_facing)
	if absf(v.last_guard_delta - want) > 1e-5:
		failures.append("%s: 끝 δ %.4f ≠ 도착 자세의 정지 해 %.4f" % [label, v.last_guard_delta, want])
	var fwd := -Basis(Vector3.UP, want_yaw).z
	if not cam.origin.is_equal_approx(want_pos + Vector3.UP * DungeonView.EYE_HEIGHT + fwd * want):
		failures.append("%s: 끝 카메라 위치 %s 가 도착 자세 + 정지 해가 아니다" % [label, cam.origin])
	st["max_end_step"] = maxf(st["max_end_step"], _last_step)
	st["animations"] += 1
	st["frames"] += v.guard_frames
	st["max_delta"] = maxf(st["max_delta"], v.guard_max_delta)
	st["max_step"] = maxf(st["max_step"], v.guard_max_step)


func _check_frame(v: DungeonView, st: Dictionary, label: String) -> void:
	if v.last_guard_delta != 0.0:
		st["frames_shifted"] += 1
	var old := _prev
	var step := absf(v.last_guard_delta - old)
	_last_step = step
	_prev = v.last_guard_delta
	# 계획(δ 경로)의 같은 프레임 변화. 끝 프레임은 계획의 끝 값(끝 자세의 정지 해)과 비교한다.
	var target: float
	if v.is_busy():
		target = v._plan_target()
	elif not v._plan.is_empty():
		target = v._plan[v._plan.size() - 1]
	else:
		target = v.last_guard_delta
	var plan_step := absf(target - _prev_target)
	_prev_target = target
	if step > 0.2 + 1e-6:
		if plan_step > 0.2 + 1e-6:
			st["planned_over_0.2"] += 1
			if planned_poses.size() < 24:
				planned_poses.append("%s %s 프레임 %d: δ %.3f → %.3f" % [_world_name, label, v.guard_frames - 1, old, v.last_guard_delta])
			if not _cur_run["recorded"]:
				_cur_run["recorded"] = true
				_cur_run["jump_frame"] = _frame_n
				planned_runs.append(_cur_run)
		else:
			st["unplanned_over_0.2"] += 1
			failures.append("%s: 계획 밖의 큰 튐 |Δδ| %.3f (계획 변화 %.3f)" % [label, step, plan_step])
	for k in [["steps_over_eps", CameraGuard.EPS], ["steps_over_2eps", 2.0 * CameraGuard.EPS], ["steps_over_0.2", 0.2]]:
		if step > k[1] + 1e-6:
			st[k[0]] += 1
	var t := v.camera_transform()
	var fwd := -t.basis.z
	# 보정 전 위치에서 반경 안의 정점(보정이 본 것과 같은 집합).
	var eye := t.origin - fwd * v.last_guard_delta
	var near := v._index.near(eye, v.guard_radius)
	var gap := CameraGuard.min_depth(near, t.origin, fwd)
	st["min_gap"] = minf(st["min_gap"], gap)
	# 정점·카메라가 float32 라 |w| 에 1e-6 정도 오차가 있다.
	if gap < CameraGuard.EPS - 1e-5:
		# ε 를 확보하지 못한 프레임: 정지 규칙(solve)의 best-effort 여유 이상이어야 한다.
		st["best_effort_frames"] += 1
		var d0 := CameraGuard.solve(near, eye, fwd)
		var gap0 := CameraGuard.min_depth(near, eye + fwd * d0, fwd)
		if gap < gap0 - 1e-5:
			failures.append("%s: best-effort 여유 %.4f < 정지 규칙 %.4f" % [label, gap, gap0])
	if gap < ROTATION_MIN_GAP:
		failures.append("%s: 보정 뒤 최소 |w| %.4f < %.3f (δ %.3f)" % [label, gap, ROTATION_MIN_GAP, v.last_guard_delta])


## 칸·방향마다 회전 둘과 이동 또는 막힘 하나를 돌린다. pick(cell) 이 false 인 칸은 뺀다.
func _sweep(v: DungeonView, f: FloorModel, world: WorldState, pick: Callable) -> void:
	for c in f.cells():
		if not pick.call(c):
			continue
		for facing in 4:
			for nf in [Dir.left(facing), Dir.right(facing)]:
				var ev: Array[Dictionary] = [{"type": "turned", "facing": nf}]
				_run(v, "turn", c, facing, ev, -1, "회전 %s %s→%s" % [c, Dir.name_of(facing), Dir.name_of(nf)], c, nf)
			var path := ExplorationRules.move_path(f, world, c, facing)
			if ExplorationRules.block_reason(f, world, c, facing) == "" and not path.is_empty():
				var mv: Array[Dictionary] = [{"type": "moved", "to": path[0], "via": "step"}]
				_run(v, "move", c, facing, mv, facing, "이동 %s %s" % [c, Dir.name_of(facing)], path[0], facing)
			else:
				var bl: Array[Dictionary] = [{"type": "blocked", "reason": "wall"}]
				_run(v, "bump", c, facing, bl, facing, "막힘 %s %s" % [c, Dir.name_of(facing)], c, facing)


func test_animation_frames_narrow_view() -> void:
	aspect = 768.0 / 720.0
	_measure_and_check("narrow")


func test_animation_frames_max_aspect() -> void:
	aspect = CameraGuard.MAX_SCREEN_ASPECT
	_measure_and_check("max")


## 지도 판을 연 1728×720(가장 넓은 유효 화면비). 연속성 도입 전 측정값이 없어 가장 넓던 「max」(2.4) 기준과 견준다.
func test_animation_frames_map_open_wide() -> void:
	aspect = 1728.0 / 720.0
	lens = MapWindow.WIDTH / 1728.0
	_measure_and_check("max")


## 지도 판을 연 1280×720.
func test_animation_frames_map_open_1280() -> void:
	aspect = 1280.0 / 720.0
	lens = MapWindow.WIDTH / 1280.0
	_measure_and_check("max")


func _measure_and_check(base_key: String) -> void:
	timeout_sec = 180.0
	check(planned_poses.is_empty() and planned_runs.is_empty() and _stats.is_empty(), "시험마다 빈 기록에서 시작한다")
	var t0 := Time.get_ticks_msec()
	var f := Fx.f1()
	var v := _make_view(f)
	var real_aspect := float(_sv.size.x) / _sv.size.y
	check(is_equal_approx(v.effective_aspect(), real_aspect * (1.0 + lens)), "유효 화면비 = 화면비·(1 + 렌즈 이동 %.3f)" % lens)
	check(v.effective_aspect() <= CameraGuard.MAX_ASPECT + 1e-6, "유효 화면비 %.3f ≤ MAX_ASPECT" % v.effective_aspect())
	check(is_equal_approx(v.guard_radius, CameraGuard.reach(2.0 * sqrt(2.0), v.camera_fov(), v.effective_aspect())), "반경은 지금 시야각·유효 화면비로 정한다")
	for kind in ["turn", "move", "bump"]:
		_reset(kind)
	v.max_plan_ms = 0.0
	var independent: Array[String] = []
	for wi in 2:
		var world := WorldState.new() if wi == 0 else _all_open_world(f)
		_world_name = "처음" if wi == 0 else "모두 엶"
		v.rebuild(world)
		var before_runs := planned_runs.size()
		_sweep(v, f, world, func(_c: Vector2i) -> bool: return true)
		# 이 세계에서 계획된 튐이 난 연출: 계획기를 쓰지 않고 0.2m 경로가 없는지 확인한다.
		for k in range(before_runs, planned_runs.size()):
			var run: Dictionary = planned_runs[k]
			_check_planned_run(v, run, 0, true, "60Hz")
			var b: Dictionary = run["bounds"]
			independent.append("%s %s 프레임 %d: 독립 확인 최소 M 하한 %.4f · 상한 %.4f, 보인 경로 %.4f, 0.2m 도달 불가 %s" % [run["world"], run["label"], run["jump_frame"], b["lower"], b["upper"], b["shown"], b["proof"]])
		# 기록이 원래 실행 그대로인지: 시작 상태를 되돌려 다시 돌리면 같은 δ 가 나온다(계획된 튐 연출 가운데 둘).
		for k in range(before_runs, mini(planned_runs.size(), before_runs + 2)):
			check(_replay_matches(v, planned_runs[k]), "%s %s: 시작 상태를 되돌려 다시 돌리면 기록과 같다" % [planned_runs[k]["world"], planned_runs[k]["label"]])
	for kind in _stats:
		print("  %s 연출 보정 (60fps): %s" % [kind, _stats[kind]])
	print("  시야 영역 %s, 반경 %.3f m, 계획 한 번 최대 %.2f ms, 걸린 시간 %d ms" % [_sv.size, v.guard_radius, v.max_plan_ms, Time.get_ticks_msec() - t0])
	for fp in planned_poses:
		print("  계획된 튐: ", fp)
	for line in independent:
		print("  ", line)
	var base: Dictionary = BEFORE[base_key]
	var turn: Dictionary = _stats["turn"]
	check(turn["animations"] > 0 and _stats["move"]["animations"] > 0 and _stats["bump"]["animations"] > 0, "연출을 돌렸다")
	check_eq(turn["unplanned_over_0.2"], 0, "회전: 계획 밖의 |Δδ| > 0.2m 프레임")
	check(turn["planned_over_0.2"] <= PLANNED_JUMP_MAX, "회전: 계획된 |Δδ| > 0.2m 프레임 %d ≤ %d" % [turn["planned_over_0.2"], PLANNED_JUMP_MAX])
	check(planned_runs.size() == independent.size() and planned_runs.size() == turn["planned_over_0.2"], "계획된 튐마다 독립 확인을 했다")
	for fp in planned_poses:
		check(fp.contains(PLANNED_JUMP_CELL), "계획된 튐은 알려진 칸에서만: " + fp)
	check(turn["steps_over_2eps"] < base["turn_over_2eps"], "회전: |Δδ| > 2ε 프레임 %d < 전 %d" % [turn["steps_over_2eps"], base["turn_over_2eps"]])
	check(_stats["move"]["max_step"] <= base["move_step"] + 1e-4, "이동: 최대 |Δδ| %.4f ≤ 전 %.4f" % [_stats["move"]["max_step"], base["move_step"]])
	check(_stats["bump"]["max_step"] <= base["bump_step"] + 1e-4, "막힘: 최대 |Δδ| %.4f ≤ 전 %.4f" % [_stats["bump"]["max_step"], base["bump_step"]])
	for kind in _stats:
		check(_stats[kind]["min_gap"] >= BEFORE_MIN_GAP - 1e-4, "%s: 보정 뒤 최소 |w| %.4f ≥ %.4f" % [kind, _stats[kind]["min_gap"], BEFORE_MIN_GAP])


# ---- 계획된 튐의 독립 확인 ----

## 계획기(free_intervals·plan_path·nearest_free)를 쓰지 않는 독립 계산. 원래 실행의 기록(_run 의 run["frames"]: 프레임마다
## 보정 전 자세·보인 δ)을 읽어, 프레임마다 그 자세에서 δ ∈ [−0.25, 0.25] 를 GRID(1mm) 간격으로 훑어 허용 점을 정하고,
## 이웃 프레임 사이 |Δδ| ≤ M 인 경로가 있는 가장 작은 M 을 앞에서부터 도달 가능한 점 집합(너비 우선)으로 찾는다.
## 처음은 실제로 보인 시작 δ(from > 0 이면 그 앞 프레임에 보인 δ), 끝은 실제 연출 끝 프레임(끝 자세)의 정지 해로 고정한다.
## 두 가지로 재서 참 최소 M(안전 규칙을 지키는 연속 경로 가운데 가장 작은 최대 |Δδ|) M* 를 위아래로 묶는다.
## - 넉넉히(하한): 참 경로의 점은 허용 점(여유 ≥ ε − FREE_TOL)이거나 best-effort 점(여유 = 그 프레임의 연속 최대 여유 G*)이다.
##   G* 는 격자의 최대 여유 g 이상이므로 참 점의 여유 ≥ min(ε − FREE_TOL, g). 여유(가장 가까운 정점까지 거리)는 δ 에 대해
##   기울기 1 이하라, 참 점에서 GRID/2 안의 격자점은 여유가 GRID/2 넘게 줄지 않는다. 그래서 여유 ≥ min(ε − FREE_TOL, g) − GRID/2
##   인 격자점을 모두 허용하면 참 경로의 점마다 가까운 격자점이 허용되고(best-effort 최적점 근처 포함), 그 격자 경로의
##   이웃 사이는 M* + GRID 이하다. 이분 탐색은 「M + GRID 로 도달 불가」로 확인된 쪽(lo)을 하한으로 쓴다: 그 M 에서 격자 경로가
##   없으면 M* > M 이다(_min_step). 0.2m 는 따로 직접 본다: M = 0.2 + GRID 로 도달 불가면 M* > 0.2 (「proof」).
## - 규칙대로(상한): 점은 안전 조건(여유 ≥ ε − FREE_TOL)을 지키는 격자점, best-effort 프레임은 CameraGuard.best_effort 의
##   한 점만, 이웃 사이는 M 까지. 찾은 격자 경로는 실제로 쓸 수 있는 경로라 M* 는 이 값 이하다(도달 가능 쪽 hi).
##   이 상한은 「찾아낸 격자 경로보다 크게 나쁘지 않다」의 비교 기준이지, 연속 공간에 더 좋은 경로가 없다는 증명은 아니다.
## 반환 {"lower", "upper", "proof": 0.2m 로 도달 불가인지, "shown": 실제로 보인 δ 경로의 최대 |Δδ|(같은 구간)}.
func _independent_bounds(v: DungeonView, run: Dictionary, from: int = 0) -> Dictionary:
	var frames: Array = run["frames"]
	var start: float = run["start_delta"] if from == 0 else float(frames[from - 1][2])
	var end := _static_at(v, run["end_cell"], run["end_facing"])
	var loose: Array[PackedFloat64Array] = []
	var exact: Array[PackedFloat64Array] = []
	var shown := 0.0
	var prev := start
	for i in range(from, frames.size()):
		var pts := _grid_points_ws(_frame_depths(v, frames[i][0], frames[i][1]))
		loose.append(pts[0])
		exact.append(pts[1])
		shown = maxf(shown, absf(float(frames[i][2]) - prev))
		prev = frames[i][2]
	shown = maxf(shown, absf(end - prev))
	var b := _bounds_from_sets(loose, exact, start, end)
	b["shown"] = shown
	return b


## 넉넉한·규칙대로의 점 집합에서 하한·상한·0.2m 직접 확인.
func _bounds_from_sets(loose: Array[PackedFloat64Array], exact: Array[PackedFloat64Array], start: float, end: float) -> Dictionary:
	var lo_r := _min_step(loose, start, end, GRID)
	var up_r := _min_step(exact, start, end, 0.0)
	return {"lower": lo_r[0], "upper": up_r[1], "proof": not _reachable(loose, start, end, 0.2 + GRID)}


## 한 자세에서 보정이 보는 정점의 깊이(반경 안, |w| < WIDE_LIMIT + ε + GRID).
func _frame_depths(v: DungeonView, pos: Vector3, yaw: float) -> PackedFloat64Array:
	var eye := pos + Vector3.UP * DungeonView.EYE_HEIGHT
	var fwd := -Basis(Vector3.UP, yaw).z
	var ws := PackedFloat64Array()
	for p in v._index.near(eye, v.guard_radius):
		var w := (p - eye).dot(fwd)
		if absf(w) < CameraGuard.WIDE_LIMIT + CameraGuard.EPS + GRID:
			ws.append(w)
	return ws


## 깊이 목록의 허용 점 [넉넉히, 규칙대로](오름차순). 넉넉히의 기준은 min(ε − FREE_TOL, 격자 최대 여유) − GRID/2.
func _grid_points_ws(ws: PackedFloat64Array) -> Array:
	var n := roundi(2.0 * CameraGuard.WIDE_LIMIT / GRID) + 1
	var gaps := PackedFloat64Array()
	gaps.resize(n)
	var best := 0.0
	for j in n:
		var d := -CameraGuard.WIDE_LIMIT + j * GRID
		var g := INF
		for w in ws:
			g = minf(g, absf(w - d))
		gaps[j] = g
		best = maxf(best, g)
	var exact_need := CameraGuard.EPS - CameraGuard.FREE_TOL
	var loose_need := minf(exact_need, best) - GRID / 2.0
	var loose := PackedFloat64Array()
	var exact := PackedFloat64Array()
	for j in n:
		var d := -CameraGuard.WIDE_LIMIT + j * GRID
		if gaps[j] >= loose_need:
			loose.append(d)
		if gaps[j] >= exact_need:
			exact.append(d)
	if exact.is_empty():
		var keep := PackedFloat64Array()
		for w in ws:
			if absf(w) < CameraGuard.WIDE_LIMIT + CameraGuard.EPS:
				keep.append(w)
		exact.append(CameraGuard.best_effort(keep, CameraGuard.WIDE_LIMIT))
	return [loose, exact]


## 가장 작은 M 의 이분 탐색(0.1mm 까지): [lo, hi]. lo = M + slack 로 도달 불가로 확인된 값(처음 0), hi = 도달 가능한 값.
## 경로가 없으면 [INF, INF].
func _min_step(sets: Array[PackedFloat64Array], start: float, end: float, slack: float) -> Array:
	var lo := 0.0
	var hi := 2.0 * CameraGuard.WIDE_LIMIT + 2.0 * GRID
	if not _reachable(sets, start, end, hi + slack):
		return [INF, INF]
	while hi - lo > 1e-4:
		var mid := (lo + hi) / 2.0
		if _reachable(sets, start, end, mid + slack):
			hi = mid
		else:
			lo = mid
	return [lo, hi]


## start → sets[0] → … → sets[-1] → end 를 이웃 사이 |Δδ| ≤ r 로 이을 수 있는지(앞에서부터 도달 점 집합).
func _reachable(sets: Array[PackedFloat64Array], start: float, end: float, r: float) -> bool:
	var reach := PackedFloat64Array([start])
	for pts in sets:
		var next := PackedFloat64Array()
		for x in pts:
			if _nearest_gap(reach, x) <= r + 1e-12:
				next.append(x)
		if next.is_empty():
			return false
		reach = next
	return _nearest_gap(reach, end) <= r + 1e-12


## 오름차순 배열 a 에서 x 와 가장 가까운 값까지의 거리.
func _nearest_gap(a: PackedFloat64Array, x: float) -> float:
	var i := a.bsearch(x)
	var g := INF
	if i < a.size():
		g = absf(a[i] - x)
	if i > 0:
		g = minf(g, absf(a[i - 1] - x))
	return g


## 기록한 연출을 시작 상태(프레임 간격 이력·plan_step)까지 되돌려 같은 프레임 간격으로 다시 돌리고, 프레임마다 보인 δ 가
## 기록과 같은지 본다(다시 돌린 결과로 판정할 일이 있을 때 먼저 확인한다).
func _replay_matches(v: DungeonView, run: Dictionary) -> bool:
	_set_rate_history(v, run["start_hist"])
	v.plan_step = run["start_plan_step"]
	v.set_pose(run["cell"], run["facing"])
	v._last_pose = Transform3D()
	v._apply_camera()
	if v.last_guard_delta != run["start_delta"]:
		return false
	v.play(run["events"], run["move_dir"])
	var frames: Array = run["frames"]
	for i in frames.size():
		v._process(frames[i][3])
		if not v.is_busy() or v.last_guard_delta != frames[i][2] or v._view_pos != frames[i][0] or v._view_yaw != frames[i][1]:
			return false
	v._process(run["end_dt"])
	return not v.is_busy()


## 계획된 튐이 난 연출 하나를 독립 확인하고 결과를 run 에 남긴다. proof = 「0.2m 경로 없음」을 단언할지.
## optimal = 실제로 보인 경로의 최대 |Δδ| 가 규칙대로 찾은 실제 경로의 M(상한) + GRID 이하인지 단언할지
## (프레임 시각을 미리 알 수 있는 고른 주기에서만: 지터·주기 전환은 계획기가 앞으로의 프레임 시각을 모른다).
func _check_planned_run(v: DungeonView, run: Dictionary, from: int, proof: bool, label: String, optimal: bool = true) -> void:
	var b := _independent_bounds(v, run, from)
	run["bounds"] = b
	run["from"] = from
	if optimal:
		check(b["shown"] <= b["upper"] + GRID, "%s %s %s: 보인 경로 최대 |Δδ| %.3f ≤ 독립 확인의 실제 경로 %.3f (계획기가 놓친 경로 없음)" % [label, run["world"], run["label"], b["shown"], b["upper"]])
	if proof:
		check(b["proof"], "%s %s %s: 독립 확인(넉넉히)으로 M = 0.2m 도달 불가 (하한 %.4f)" % [label, run["world"], run["label"], b["lower"]])


## 칸 cell 의 계획된 튐 연출마다 한 줄(보고용): 세계·연출·튄 프레임·튐 크기 아닌 경로 값과 독립 확인 값.
func _cell_lines(cfg_name: String, cell: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for run in planned_runs:
		if run["cell"] != cell:
			continue
		var b: Dictionary = run["bounds"]
		out.append("    %s %s %s 프레임 %d(%s): 보인 경로 %.4f, 하한 %.4f, 상한 %.4f, 0.2m 도달 불가 %s" % [
			cfg_name, run["world"], run["label"], run["jump_frame"], "튄 프레임부터" if run["from"] > 0 else "처음부터",
			b["shown"], b["lower"], b["upper"], b["proof"]])
	if out.is_empty():
		out.append("    %s: 칸 %s 계획된 튐 없음" % [cfg_name, cell])
	return out


func _bounds_text(runs: Array[Dictionary]) -> String:
	var lo := INF
	var hi := -INF
	var up_min := INF
	for run in runs:
		lo = minf(lo, run["bounds"]["lower"])
		hi = maxf(hi, run["bounds"]["lower"])
		up_min = minf(up_min, run["bounds"]["upper"])
	return "독립 확인 하한 %.3f~%.3f, 상한 최소 %.3f" % [lo, hi, up_min]


# ---- 다른 프레임률 (05 §9.2.1) ----

## 30·90·120Hz 와 60Hz 에서 연출마다 셋째 프레임 하나가 0.04초(표본 2.4개)로 튀는 경우. 화면비는 좁은 쪽(768×720), 세계 둘.
## 시간을 줄이려고 칸 일부만 돈다: (x + 2y) % 6 == 0 인 칸과 알려진 칸 (3,16). 나머지 칸은 60Hz 전체 스윕이 본다.
## 시야 노드는 최근 프레임 간격으로 표본 간격을 정하고, 프레임이 표본에서 어긋나면 그 프레임에서 다시 계획한다.
## 단언: 계획 밖의 0.2m 넘는 튐 0, 계획된 튐은 그 프레임률의 독립 확인으로도 0.2m 경로가 없다,
## 프레임마다 보정 뒤 |w| ≥ min(ε, 같은 자세 정지 규칙의 best-effort 여유)(_check_frame). 최소 |w| 는 보고한다
## (60Hz 와 다른 자세를 지나므로 60Hz 기준값 BEFORE_MIN_GAP 과 바로 비교하지 않는다).
func test_animation_frames_other_rates() -> void:
	timeout_sec = 240.0
	aspect = 768.0 / 720.0
	var f := Fx.f1()
	var v := _make_view(f)
	var pick := func(c: Vector2i) -> bool: return (c.x + 2 * c.y) % 6 == 0 or c == Vector2i(3, 16)
	var rows: Array[String] = []
	spike_dt = 0.04
	for cfg in [["30Hz", 1.0 / 30.0, -1], ["90Hz", 1.0 / 90.0, -1], ["120Hz", 1.0 / 120.0, -1], ["60Hz+0.04초 1회", FRAME, 2]]:
		frame_dt = cfg[1]
		spike_frame = cfg[2]
		pre_hist = PackedFloat64Array([frame_dt, frame_dt, frame_dt, frame_dt, frame_dt])  # 이 프레임률로 이미 돌던 상태
		for kind in ["turn", "move", "bump"]:
			_reset(kind)
		planned_poses.clear()
		planned_runs.clear()
		var spike_jumps := 0
		for wi in 2:
			var world := WorldState.new() if wi == 0 else _all_open_world(f)
			_world_name = "처음" if wi == 0 else "모두 엶"
			v.rebuild(world)
			var before_runs := planned_runs.size()
			_sweep(v, f, world, pick)
			for k in range(before_runs, planned_runs.size()):
				var run: Dictionary = planned_runs[k]
				# 튄 프레임 뒤의 튐은 튄 프레임부터 본다(그 전 선택은 튐을 몰랐고, 튄 프레임에서 다시 계획한다).
				# 미리 알 수 없는 튐이라 「피할 수 없음」의 증명(하한 > 0.2)은 단언하지 않고 보고한다. 계획기가 놓친 경로가 없는지는 단언한다.
				var from: int = spike_frame if spike_frame >= 0 and run["jump_frame"] >= spike_frame else 0
				_check_planned_run(v, run, from, from == 0, cfg[0])
				if from > 0:
					spike_jumps += 1
		var cells := {}
		for run in planned_runs:
			cells[str(run["cell"])] = true
		var row := "%s: 연출 %d, 계획 밖 >0.2m %d, 계획된 >0.2m %d (칸 %s), 회전 최대 |Δδ| %.3f, >2ε %d, 최소 |w| 회전 %.4f·이동 %.4f·막힘 %.4f, 이동 최대 |Δδ| %.4f, 막힘 최대 |Δδ| %.4f" % [
			cfg[0], _stats["turn"]["animations"] + _stats["move"]["animations"] + _stats["bump"]["animations"],
			_stats["turn"]["unplanned_over_0.2"] + _stats["move"]["unplanned_over_0.2"] + _stats["bump"]["unplanned_over_0.2"],
			_stats["turn"]["planned_over_0.2"] + _stats["move"]["planned_over_0.2"] + _stats["bump"]["planned_over_0.2"], cells.keys(),
			_stats["turn"]["max_step"], _stats["turn"]["steps_over_2eps"],
			_stats["turn"]["min_gap"], _stats["move"]["min_gap"], _stats["bump"]["min_gap"],
			_stats["move"]["max_step"], _stats["bump"]["max_step"]]
		row += ", 계획된 튐의 " + _bounds_text(planned_runs) if not planned_runs.is_empty() else ""
		var proven := 0
		for run in planned_runs:
			if run["bounds"]["proof"]:
				proven += 1
		row += ", 피할 수 없음 증명 %d/%d" % [proven, planned_runs.size()] if not planned_runs.is_empty() else ""
		row += " (그 가운데 튄 프레임 뒤 %d 개)" % spike_jumps if spike_jumps > 0 else ""
		rows.append(row)
		rows.append_array(_cell_lines(cfg[0], Vector2i(3, 16)))
		for kind in _stats:
			check_eq(_stats[kind]["unplanned_over_0.2"], 0, "%s %s: 계획 밖의 |Δδ| > 0.2m 프레임" % [cfg[0], kind])
		check(_stats["turn"]["animations"] > 0 and _stats["move"]["animations"] > 0 and _stats["bump"]["animations"] > 0, cfg[0] + ": 연출을 돌렸다")
	for row in rows:
		print("  ", row)


# ---- 가변 주기 (05 §9.2.1) ----

## 주기 전환(120→60Hz·60→120Hz, 연출 셋째 프레임부터), 60Hz 에서 정확히 표본 셋을 건너뛰는 0.05초 지연 한 번,
## 반복 지터(60Hz ±2ms·120Hz ±1ms, 고정 시드). 칸은 다른 프레임률 시험과 같은 일부, 화면비는 좁은 쪽, 세계 둘.
## 단언: 계획 밖의 0.2m 넘는 튐 0, 프레임마다 보정 뒤 |w| ≥ min(ε, 같은 자세 정지 규칙의 best-effort 여유)(_check_frame).
## 계획된 튐은 원래 실행 기록으로 독립 확인해 보고한다(앞으로의 프레임 시각을 계획기가 모르므로 최적성·증명은 단언하지 않는다).
func test_animation_frames_variable_timing() -> void:
	timeout_sec = 300.0
	aspect = 768.0 / 720.0
	var f := Fx.f1()
	var v := _make_view(f)
	var pick := func(c: Vector2i) -> bool: return (c.x + 2 * c.y) % 6 == 0 or c == Vector2i(3, 16)
	var h60 := PackedFloat64Array([FRAME, FRAME, FRAME, FRAME, FRAME])
	var h120 := PackedFloat64Array([1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120])
	# [이름, 이력, frame_dt, switch_frame, switch_dt, spike_frame, spike_dt, jitter]
	var cfgs := [
		["120→60Hz", h120, 1.0 / 120, 2, FRAME, -1, 0.0, 0.0],
		["60→120Hz", h60, FRAME, 2, 1.0 / 120, -1, 0.0, 0.0],
		["60Hz+0.05초(표본 3개) 1회", h60, FRAME, -1, FRAME, 2, 0.05, 0.0],
		["60Hz 지터 ±2ms", h60, FRAME, -1, FRAME, -1, 0.0, 0.002],
		["120Hz 지터 ±1ms", h120, 1.0 / 120, -1, FRAME, -1, 0.0, 0.001],
	]
	var rows: Array[String] = []
	for cfg in cfgs:
		pre_hist = cfg[1]
		frame_dt = cfg[2]
		switch_frame = cfg[3]
		switch_dt = cfg[4]
		spike_frame = cfg[5]
		spike_dt = cfg[6]
		jitter = cfg[7]
		_rng.seed = 20261017
		for kind in ["turn", "move", "bump"]:
			_reset(kind)
		planned_poses.clear()
		planned_runs.clear()
		for wi in 2:
			var world := WorldState.new() if wi == 0 else _all_open_world(f)
			_world_name = "처음" if wi == 0 else "모두 엶"
			v.rebuild(world)
			var before_runs := planned_runs.size()
			_sweep(v, f, world, pick)
			for k in range(before_runs, planned_runs.size()):
				_check_planned_run(v, planned_runs[k], 0, false, cfg[0], false)
		var cells := {}
		var proven := 0
		for run in planned_runs:
			cells[str(run["cell"])] = true
			if run["bounds"]["proof"]:
				proven += 1
		var unplanned := 0
		var planned := 0
		for kind in _stats:
			unplanned += _stats[kind]["unplanned_over_0.2"]
			planned += _stats[kind]["planned_over_0.2"]
			check_eq(_stats[kind]["unplanned_over_0.2"], 0, "%s %s: 계획 밖의 |Δδ| > 0.2m 프레임" % [cfg[0], kind])
		var row := "%s: 연출 %d, 계획 밖 >0.2m %d, 계획된 >0.2m %d (칸 %s), 회전 최대 |Δδ| %.3f, 최소 |w| 회전 %.4f·이동 %.4f·막힘 %.4f, 이동 최대 |Δδ| %.4f, 막힘 최대 |Δδ| %.4f, best-effort 프레임 %d, 연출당 계획 최대 %d회 (회전 %d·이동 %d·막힘 %d), 연출당 누적 계획 최대 %.2f ms" % [
			cfg[0], _stats["turn"]["animations"] + _stats["move"]["animations"] + _stats["bump"]["animations"], unplanned, planned, cells.keys(),
			_stats["turn"]["max_step"], _stats["turn"]["min_gap"], _stats["move"]["min_gap"], _stats["bump"]["min_gap"],
			_stats["move"]["max_step"], _stats["bump"]["max_step"],
			_stats["turn"]["best_effort_frames"] + _stats["move"]["best_effort_frames"] + _stats["bump"]["best_effort_frames"],
			maxi(maxi(_stats["turn"]["plan_count_max"], _stats["move"]["plan_count_max"]), _stats["bump"]["plan_count_max"]),
			_stats["turn"]["plan_count_max"], _stats["move"]["plan_count_max"], _stats["bump"]["plan_count_max"],
			maxf(maxf(_stats["turn"]["plan_ms_total_max"], _stats["move"]["plan_ms_total_max"]), _stats["bump"]["plan_ms_total_max"])]
		if not planned_runs.is_empty():
			row += ", 계획된 튐의 " + _bounds_text(planned_runs) + ", 0.2m 도달 불가 %d/%d" % [proven, planned_runs.size()]
		rows.append(row)
		rows.append_array(_cell_lines(cfg[0], Vector2i(3, 16)))
		check(_stats["turn"]["animations"] > 0 and _stats["move"]["animations"] > 0 and _stats["bump"]["animations"] > 0, cfg[0] + ": 연출을 돌렸다")
	for row in rows:
		print("  ", row)


## 고른 주기에서는 연출 하나에 계획이 한 번(play)뿐이다: 다시 계획하는 조건(어긋남·간격 다름·주기 바뀜)이 헛돌지 않는다.
func test_regular_rate_plans_once() -> void:
	timeout_sec = 60.0
	aspect = 768.0 / 720.0
	var f := Fx.f1()
	var v := _make_view(f)
	for rate in [FRAME, 1.0 / 120, 1.0 / 90]:
		frame_dt = rate
		pre_hist = PackedFloat64Array([rate, rate, rate, rate, rate])
		_reset("turn")
		_reset("move")
		_reset("bump")
		_world_name = "처음"
		_sweep(v, f, WorldState.new(), func(c: Vector2i) -> bool: return (c.x + c.y) % 7 == 0)
		for kind in _stats:
			check_eq(_stats[kind]["plan_count_max"], 1, "%.0fHz %s: 연출당 계획 횟수" % [1.0 / rate, kind])


## 다시 계획하는 조건(05 §9.2.1)을 하나씩 본다. 긴 미끄러짐(처음 세계 (12,8) 동쪽) 위에서:
## - 60Hz 에서 정확히 표본 셋을 건너뛰는 0.05초: 격자에는 맞지만 간격이 달라 그 프레임에서 다시 계획한다(격자 그대로).
## - 60Hz 에서 0.04초: 격자에서 어긋나 다시 계획하고 격자를 그 프레임에 맞춘다(다음 고른 프레임은 다시 계획 없음).
## - 120→60Hz: 두 표본 건너뛰는 프레임마다 다시 계획하고, 중앙값이 바뀌면 1/60 격자로 옮긴 뒤로는 다시 계획하지 않는다.
## - 작은 지터(±1%): 다시 계획하지 않는다(계획 값이 막히지 않는 한).
func test_replan_triggers() -> void:
	var f := Fx.f1()
	var v := _make_view(f)
	var world := WorldState.new()
	var c := Vector2i(12, 8)
	var path := ExplorationRules.move_path(f, world, c, Dir.E)
	check(path.size() >= 4, "준비: 긴 미끄러짐 (%d 칸)" % path.size())
	var ev: Array[Dictionary] = []
	for i in path.size():
		ev.append({"type": "moved", "to": path[i], "via": "step" if i == 0 else "slide"})
	var h60 := PackedFloat64Array([FRAME, FRAME, FRAME, FRAME, FRAME])
	var h120 := PackedFloat64Array([1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120])
	# 0.05초 지연.
	_set_rate_history(v, h60)
	v.set_pose(c, Dir.E)
	v.play(ev, Dir.E)
	v._process(FRAME)
	v._process(FRAME)
	var n0 := v.plan_count
	var origin0 := v._grid_origin
	v._process(0.05)
	check_eq(v.plan_count, n0 + 1, "0.05초(표본 셋 건너뜀): 그 프레임에서 다시 계획")
	check_eq(v._grid_origin, origin0, "0.05초: 격자에 맞으니 격자는 그대로")
	v._process(FRAME)
	check_eq(v.plan_count, n0 + 1, "0.05초 뒤 고른 프레임: 다시 계획 없음")
	# 0.04초 튐.
	_set_rate_history(v, h60)
	v.set_pose(c, Dir.E)
	v.play(ev, Dir.E)
	v._process(FRAME)
	n0 = v.plan_count
	v._process(0.04)
	check_eq(v.plan_count, n0 + 1, "0.04초(표본 2.4개): 그 프레임에서 다시 계획")
	check(absf(v._grid_origin - v._clock) < 1e-12, "0.04초: 격자를 그 프레임에 맞춘다")
	v._process(FRAME)
	v._process(FRAME)
	check_eq(v.plan_count, n0 + 1, "튐 뒤 고른 프레임: 다시 계획 없음")
	# 120→60Hz.
	_set_rate_history(v, h120)
	v.set_pose(c, Dir.E)
	v.play(ev, Dir.E)
	check(is_equal_approx(v._grid_step, 1.0 / 120), "준비: 120Hz 격자")
	var counts := []
	for i in 6:
		v._process(FRAME)
		counts.append(v.plan_count)
	check(is_equal_approx(v._grid_step, FRAME), "120→60Hz: 중앙값이 바뀌면 1/60 격자로 옮긴다 (%.5f)" % v._grid_step)
	check(counts[0] == 2 and counts[1] == 3, "120→60Hz: 두 표본 건너뛰는 프레임마다 다시 계획 %s" % [counts])
	check(counts[5] == counts[3], "120→60Hz: 1/60 격자로 옮긴 뒤 다시 계획 없음 %s" % [counts])
	# 작은 지터.
	_set_rate_history(v, h60)
	v.set_pose(c, Dir.E)
	v.play(ev, Dir.E)
	var inv0 := v.invalid_replans
	for i in 12:
		v._process(FRAME * (1.0 + (0.01 if i % 2 == 0 else -0.01)))
	check_eq(v.plan_count - (v.invalid_replans - inv0), 1, "±1% 지터: 사건으로 다시 계획하지 않는다")


# ---- 독립 하한의 계약 ----

## 검토 반례: 한 중간 표본의 깊이 8 개, 시작 = 끝 = −0.01. 연속 최대 여유는 δ = 0.0005 의 0.0497 이라 best-effort 표본이고,
## 그 점을 지나는 경로의 최대 변화는 0.0105m 다. 하한은 0.0105 이하여야 한다(격자 최고값이 0.2 쪽 0.0496 이어도
## best-effort 최적점 근처 격자점 0·0.001 을 허용한다). 상한(규칙대로)은 best_effort 한 점을 지나는 0.0105 다.
func test_independent_lower_bound_best_effort_counterexample() -> void:
	var ws := PackedFloat64Array([-0.25, -0.17, -0.09, -0.0492, 0.0502, 0.1003, 0.1504, 0.2496])
	check(CameraGuard.nearest_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, 0.0) == null, "준비: 허용 점이 없다(best-effort 표본)")
	var be := CameraGuard.best_effort(ws, CameraGuard.WIDE_LIMIT)
	check(absf(be - 0.0005) < 1e-9, "준비: best-effort 점 0.0005 (%.6f)" % be)
	var pts := _grid_points_ws(ws)
	var loose: Array[PackedFloat64Array] = [pts[0]]
	var exact: Array[PackedFloat64Array] = [pts[1]]
	check(_nearest_gap(pts[0], 0.0) < 1e-9 and _nearest_gap(pts[0], 0.001) < 1e-9, "best-effort 최적점 근처 격자점 0·0.001 이 넉넉한 집합에 있다")
	var b := _bounds_from_sets(loose, exact, -0.01, -0.01)
	check(b["lower"] <= 0.0105 + 1e-9, "하한 %.5f ≤ 참 최소 0.0105" % b["lower"])
	# 격자로 옮기면 0.0105 − GRID/2(점 0 을 지나는 길), 넉넉히 판정이 GRID 를 더 빼고, 이분 탐색 정밀도 1e-4.
	check(b["lower"] >= 0.0105 - 1.5 * GRID - 2e-4, "하한이 지나치게 낮지 않다 (%.5f)" % b["lower"])
	check(absf(b["upper"] - 0.0105) <= 2e-4, "상한 = best-effort 한 점을 지나는 경로 %.5f" % b["upper"])
	check(not b["proof"], "0.2m 로 도달 가능")
	# 하한은 이분 탐색의 도달 불가 쪽(lo): lo + GRID 로는 정말 도달하지 못한다.
	check(not _reachable(loose, -0.01, -0.01, b["lower"] + GRID), "하한 + GRID 로 도달 불가")


## set_pose 는 프레임 간격 이력과 plan_step 을 지우지 않는다(화면 갱신 주기는 자세가 아니라 화면의 성질).
func test_set_pose_keeps_frame_history() -> void:
	var f := Fx.f1()
	var v := _make_view(f)
	var h120 := PackedFloat64Array([1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120])
	_set_rate_history(v, h120)
	v.set_pose(Vector2i(2, 17), Dir.E)
	check_eq(v._dt_hist, h120, "set_pose 뒤 이력 그대로")
	check(is_equal_approx(v.plan_step, 1.0 / 120), "set_pose 뒤 plan_step 그대로")
	var ev: Array[Dictionary] = [{"type": "turned", "facing": Dir.S}]
	v.play(ev)
	check(is_equal_approx(v._grid_step, 1.0 / 120), "다음 연출은 그 주기의 격자로 계획한다")


## 계획 표본의 허용 구간(구간 후보 _seg_cands 로 고른 정점)이 보정과 같은 정점 집합(_index.near)으로 구한 것과 같다.
func test_sample_candidates_match_near() -> void:
	timeout_sec = 60.0
	aspect = CameraGuard.MAX_SCREEN_ASPECT
	lens = MapWindow.WIDTH / 1728.0  # 가장 넓은 유효 화면비(지도 판을 연 1728×720)
	var f := Fx.f1()
	var v := _make_view(f)
	var world := _all_open_world(f)
	v.rebuild(world)
	var compared := 0
	var bad := 0
	for c in f.cells():
		if (c.x + c.y) % 3 != 0:
			continue
		for facing in 4:
			var evs: Array = [[[{"type": "turned", "facing": Dir.right(facing)}], -1]]
			var path := ExplorationRules.move_path(f, world, c, facing)
			if ExplorationRules.block_reason(f, world, c, facing) == "" and not path.is_empty():
				evs.append([[{"type": "moved", "to": path[0], "via": "step"}], facing])
			else:
				evs.append([[{"type": "blocked", "reason": "wall"}], facing])
			for e in evs:
				var ev: Array[Dictionary] = []
				ev.assign(e[0])
				v.set_pose(c, facing)
				v.play(ev, e[1])
				var seg: Dictionary = v._segments[0]
				for t in [0.0, 0.31, 0.5, 0.77, 0.999]:
					var pose := DungeonView._segment_pose(seg, t * seg["time"])
					var eye: Vector3 = pose[0] + Vector3.UP * DungeonView.EYE_HEIGHT
					var fwd := -Basis(Vector3.UP, pose[1]).z
					var ws := CameraGuard.depths(v._index.near(eye, v.guard_radius), eye, fwd, CameraGuard.WIDE_LIMIT + CameraGuard.EPS)
					var want := CameraGuard.free_intervals(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, DungeonView.GUARD_PLAN_MARGIN)
					var got := v._sample_allowed(seg, pose)
					compared += 1
					if got != want:
						bad += 1
						if bad <= 5:
							failures.append("%s %s %s t=%.2f: 후보로 구한 허용 구간 %s ≠ %s" % [c, Dir.name_of(facing), seg["kind"], t, got, want])
				v.set_pose(c, facing)
	check(compared > 1000, "준비: 비교 %d 번" % compared)
	check_eq(bad, 0, "후보로 구한 허용 구간이 다르다")


# ---- 연출 중 창 크기 변경 ----

## 회전 중 δ 가 같은 자세의 정지 해와 다른 프레임을 찾는다. [칸, 방향, 새 방향, 프레임 수] 또는 [].
func _find_turn_frame_off_static(v: DungeonView, f: FloorModel) -> Array:
	for c in f.cells():
		for facing in 4:
			var nf := Dir.right(facing)
			v.set_pose(c, facing)
			var ev: Array[Dictionary] = [{"type": "turned", "facing": nf}]
			v.play(ev)
			var k := 0
			while v.is_busy() and k < 20:
				v._process(FRAME)
				k += 1
				if not v.is_busy():
					break
				var eye := v._view_pos + Vector3.UP * DungeonView.EYE_HEIGHT
				var fwd := -Basis(Vector3.UP, v._view_yaw).z
				var s0 := CameraGuard.solve(v._index.near(eye, v.guard_radius), eye, fwd)
				if absf(v.last_guard_delta - s0) > 0.01:
					return [c, facing, nf, k]
	return []


## 연출 중 크기가 바뀌면 정지 해를 끼워 넣지 않고 지금 δ 에서 남은 연출을 다시 계획한다(화면비 같음·다름 둘 다).
func test_resize_during_turn_replans_from_current_delta() -> void:
	timeout_sec = 60.0
	aspect = CameraGuard.MAX_ASPECT
	var f := Fx.f1()
	var v := _make_view(f)
	var found := _find_turn_frame_off_static(v, f)
	check(not found.is_empty(), "준비: 회전 중 δ ≠ 정지 해인 프레임")
	if found.is_empty():
		return
	for cfg in [["화면비 같음", Vector2i(2592, 1080)], ["화면비 다름", Vector2i(768, 720)]]:
		_sv.size = Vector2i(roundi(720 * aspect), 720)
		_reset("turn")
		var ev: Array[Dictionary] = [{"type": "turned", "facing": found[2]}]
		v.set_pose(found[0], found[1])
		v.play(ev)
		for i in found[3]:
			v._process(FRAME)
		check(v.is_busy(), cfg[0] + ": 준비: 아직 회전 중")
		var d0 := v.last_guard_delta
		var r0 := v.guard_radius
		_sv.size = cfg[1]
		var new_size: Vector2i = cfg[1]
		var new_aspect := float(new_size.x) / new_size.y
		check(is_equal_approx(v.guard_radius, CameraGuard.reach(2.0 * sqrt(2.0), v.camera_fov(), new_aspect)), cfg[0] + ": 반경을 새 화면비로 다시 정한다")
		check(is_equal_approx(v._plan_radius, v.guard_radius), "%s: 남은 연출을 새 반경으로 다시 계획한다 (계획 %.3f, 반경 %.3f)" % [cfg[0], v._plan_radius, v.guard_radius])
		check(v._plan[0] == v.last_guard_delta, cfg[0] + ": 다시 세운 계획은 이번 프레임에 실제로 적용한 δ 에서 시작한다")
		var eye := v._view_pos + Vector3.UP * DungeonView.EYE_HEIGHT
		var fwd := -Basis(Vector3.UP, v._view_yaw).z
		var ws := CameraGuard.depths(v._index.near(eye, v.guard_radius), eye, fwd, CameraGuard.WIDE_LIMIT + CameraGuard.EPS)
		if CameraGuard.is_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, d0):
			check(absf(v.last_guard_delta - d0) < 1e-9, "%s: 지금 δ 가 새 반경에서도 안전하면 그대로 (%.4f → %.4f, 반경 %.3f → %.3f)" % [cfg[0], d0, v.last_guard_delta, r0, v.guard_radius])
		else:
			check(CameraGuard.is_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, v.last_guard_delta), cfg[0] + ": 새 반경에서 안전한 δ")
		# 남은 연출: 계획 밖의 튐 없이 끝나고 끝은 정지 해.
		_prev = v.last_guard_delta
		_prev_target = v._plan_target()
		_cur_run = {"world": "처음", "label": cfg[0], "recorded": false}
		var n := 0
		while v.is_busy() and n < FRAME_LIMIT:
			v._process(FRAME)
			n += 1
			_check_frame(v, _stats["turn"], "크기 변경 뒤 " + cfg[0])
		check(not v.is_busy(), cfg[0] + ": 연출이 끝났다")
		check(absf(v.last_guard_delta - _static_at(v, found[0], found[2])) <= 1e-5, cfg[0] + ": 끝 δ = 새 반경의 정지 해")
	# 정지 중에는 정지 해를 바로 쓴다.
	_sv.size = Vector2i(roundi(720 * aspect), 720)
	v.set_pose(found[0], found[1])
	_sv.size = Vector2i(768, 720)
	check(absf(v.last_guard_delta - _static_at(v, found[0], found[1])) <= 1e-9, "정지 중 크기 변경 = 새 반경의 정지 해")


## 좁은 → 넓은 화면비: 반경이 커져 지금 δ 가 새 정점의 금지 구간에 들어가면, 먼저 새 조건에서 이번 프레임 δ 를 정하고
## (지금 δ 에 가장 가까운 안전한 값, solve_near) 그 적용한 값에서 남은 연출을 계획한다(계획의 첫 값 = 실제로 보인 값).
func test_resize_wider_replans_from_applied_delta() -> void:
	timeout_sec = 120.0
	aspect = 768.0 / 720.0
	var f := Fx.f1()
	var v := _make_view(f)
	var wide_w := roundi(720 * CameraGuard.MAX_ASPECT)
	var wide_r := CameraGuard.reach(2.0 * sqrt(2.0), v.camera_fov(), wide_w / 720.0)
	var found := []
	for c in f.cells():
		for facing in 4:
			for nf in [Dir.left(facing), Dir.right(facing)]:
				v.set_pose(c, facing)
				var ev: Array[Dictionary] = [{"type": "turned", "facing": nf}]
				v.play(ev)
				var k := 0
				while v.is_busy() and k < 20:
					v._process(FRAME)
					k += 1
					if not v.is_busy():
						break
					var eye := v._view_pos + Vector3.UP * DungeonView.EYE_HEIGHT
					var fwd := -Basis(Vector3.UP, v._view_yaw).z
					var ws := CameraGuard.depths(v._index.near(eye, wide_r), eye, fwd, CameraGuard.WIDE_LIMIT + CameraGuard.EPS)
					if not CameraGuard.is_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, v.last_guard_delta):
						found = [c, facing, nf, k]
						break
				if not found.is_empty():
					break
			if not found.is_empty():
				break
		if not found.is_empty():
			break
	check(not found.is_empty(), "준비: 넓은 화면비에서 지금 δ 가 막히는 회전 프레임")
	if found.is_empty():
		return
	_set_rate_history(v, PackedFloat64Array([FRAME, FRAME, FRAME, FRAME, FRAME]))
	v.set_pose(found[0], found[1])
	var ev2: Array[Dictionary] = [{"type": "turned", "facing": found[2]}]
	v.play(ev2)
	for i in found[3]:
		v._process(FRAME)
	var d0 := v.last_guard_delta
	_sv.size = Vector2i(wide_w, 720)
	check(is_equal_approx(v.guard_radius, wide_r), "반경이 넓은 화면비로 커졌다")
	var eye := v._view_pos + Vector3.UP * DungeonView.EYE_HEIGHT
	var fwd := -Basis(Vector3.UP, v._view_yaw).z
	var near := v._index.near(eye, v.guard_radius)
	var ws := CameraGuard.depths(near, eye, fwd, CameraGuard.WIDE_LIMIT + CameraGuard.EPS)
	check(v.last_guard_delta != d0, "실제 δ 가 바뀌었다 (%.4f → %.4f)" % [d0, v.last_guard_delta])
	check_eq(v.last_guard_delta, CameraGuard.solve_near(near, eye, fwd, d0), "이번 프레임 δ = 새 조건에서 지금 δ 에 가장 가까운 안전한 값")
	check(CameraGuard.is_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, v.last_guard_delta), "새 반경에서 안전")
	check(v._plan[0] == v.last_guard_delta, "계획의 첫 값 = 적용한 δ (%.4f, %.4f)" % [v._plan[0], v.last_guard_delta])
	check(is_equal_approx(v._plan_radius, v.guard_radius), "새 반경으로 계획했다")
	var cam := v.camera_transform()
	check(cam.origin.is_equal_approx(eye + fwd * v.last_guard_delta), "카메라 = 보정 전 자세 + 적용한 δ")
	# 남은 연출: 계획 밖의 튐 없이 끝나고 끝은 정지 해.
	_reset("turn")
	_prev = v.last_guard_delta
	_prev_target = v._plan_target()
	_cur_run = {"world": "처음", "label": "넓힌 뒤", "recorded": false}
	var n := 0
	while v.is_busy() and n < FRAME_LIMIT:
		v._process(FRAME)
		n += 1
		_check_frame(v, _stats["turn"], "넓힌 뒤")
	check(not v.is_busy(), "연출이 끝났다")
	check_eq(_stats["turn"]["unplanned_over_0.2"], 0, "넓힌 뒤 계획 밖의 큰 튐 없음")
	check(absf(v.last_guard_delta - _static_at(v, found[0], found[2])) <= 1e-5, "끝 δ = 새 반경의 정지 해")
	print("  넓힌 회전: %s %s→%s 프레임 %d, δ %.4f → %.4f" % [found[0], Dir.name_of(found[1]), Dir.name_of(found[2]), found[3], d0, _prev])


# ---- 정지 해의 결정성 (경계 계약) ----

## 연출 중 해(정지 해와 다른 유효 δ)가 남은 채 같은 자세로 set_pose·_finish_all 이 오면 정지 해로 다시 계산한다.
func test_set_pose_and_finish_recompute_static() -> void:
	aspect = CameraGuard.MAX_ASPECT
	var f := Fx.f1()
	var v := _make_view(f)
	var hit := []
	for c in f.cells():
		for facing in 4:
			v.set_pose(c, facing)
			var s0 := v.last_guard_delta
			for t in [0.1, -0.1, 0.2, -0.2]:
				v._last_pose = Transform3D()
				v._apply_camera(t)
				if absf(v.last_guard_delta - s0) > 1e-3:
					hit = [c, facing, t, s0]
					break
			if not hit.is_empty():
				break
		if not hit.is_empty():
			break
	check(not hit.is_empty(), "준비: 정지 해와 다른 유효 δ 가 있는 자세")
	if hit.is_empty():
		return
	v._last_pose = Transform3D()
	v._apply_camera(hit[2])
	check(absf(v.last_guard_delta - hit[3]) > 1e-3, "준비: 연출 중 해가 남아 있다")
	v.set_pose(hit[0], hit[1])
	check_eq(v.last_guard_delta, hit[3], "같은 자세 set_pose = 정지 해")
	v._last_pose = Transform3D()
	v._apply_camera(hit[2])
	v.speed = 0.0
	var bl: Array[Dictionary] = [{"type": "blocked", "reason": "wall"}]
	v.play(bl, hit[1])  # 막힘은 같은 자세로 끝난다
	check(not v.is_busy(), "즉시 끝남")
	check_eq(v.last_guard_delta, hit[3], "같은 자세로 끝나는 _finish_all = 정지 해")


# ---- 비용 ----

## 가장 긴 연출(가장 긴 미끄러짐)의 play() 한 번 계획 시간, 프레임 간격(60·120Hz, 가운데 한 번 튐, 지터)마다
## 연출 하나의 계획 횟수·누적 계획 시간을 헤드리스로 잰다(시간은 보고만. 고른 주기의 계획 한 번과 계획 밖 튐 없음은 단언).
func test_plan_cost_longest_slide() -> void:
	aspect = CameraGuard.MAX_ASPECT
	var f := Fx.f1()
	var v := _make_view(f)
	var best := []
	for wi in 2:
		var world := WorldState.new() if wi == 0 else _all_open_world(f)
		for c in f.cells():
			for facing in 4:
				if ExplorationRules.block_reason(f, world, c, facing) != "":
					continue
				var path := ExplorationRules.move_path(f, world, c, facing)
				if best.is_empty() or path.size() > best[3].size():
					best = [wi, c, facing, path]
	check(not best.is_empty(), "준비: 이동 경로")
	if best.is_empty():
		return
	v.rebuild(WorldState.new() if best[0] == 0 else _all_open_world(f))
	var ev: Array[Dictionary] = []
	var path: Array = best[3]
	for i in path.size():
		ev.append({"type": "moved", "to": path[i], "via": "step" if i == 0 else "slide"})
	var times := []
	for i in 5:
		v.set_pose(best[1], best[2])
		v.play(ev, best[2])
		times.append(v.last_plan_ms)
	times.sort()
	var dur := DungeonView.MOVE_TIME + (path.size() - 1) * DungeonView.SLIDE_TIME
	print("  가장 긴 미끄러짐: %s %s 에서 %d 칸 (연출 %.2f초, 표본 %d), play() 계획 %s ms (중앙 %.2f ms)" % [
		best[1], Dir.name_of(best[2]), path.size(), dur, v._plan.size(), times, times[2]])
	check(v._plan_open and v._plan.size() == DungeonView.PLAN_HORIZON + 1, "긴 연출은 앞부분(표본 %d + 지금)만 끝이 열린 계획으로 세운다 (%d)" % [DungeonView.PLAN_HORIZON, v._plan.size()])
	# 프레임 간격마다 연출 하나를 끝까지 돌려 계획 횟수·누적 계획 시간을 잰다(다시 계획 포함). 계획 밖의 큰 튐 없음.
	var h60 := PackedFloat64Array([FRAME, FRAME, FRAME, FRAME, FRAME])
	var h120 := PackedFloat64Array([1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120, 1.0 / 120])
	# [이름, 이력, frame_dt, spike_frame, spike_dt, jitter]
	for cfg in [["60Hz", h60, FRAME, -1, 0.0, 0.0], ["120Hz", h120, 1.0 / 120, -1, 0.0, 0.0],
			["60Hz+0.04초 1회(가운데)", h60, FRAME, 20, 0.04, 0.0], ["120Hz 지터 ±1ms", h120, 1.0 / 120, -1, 0.0, 0.001],
			["60Hz 지터 ±2ms", h60, FRAME, -1, 0.0, 0.002]]:
		pre_hist = cfg[1]
		frame_dt = cfg[2]
		spike_frame = cfg[3]
		spike_dt = cfg[4]
		jitter = cfg[5]
		_rng.seed = 7
		var counts := []
		var totals := []
		var maxes := []
		for rep_i in 3:
			_reset("move")
			_world_name = "긴 미끄러짐"
			v.max_plan_ms = 0.0
			_run(v, "move", best[1], best[2], ev, best[2], "긴 미끄러짐 " + cfg[0], path[path.size() - 1], best[2])
			counts.append(v.last_anim_plan_count)
			totals.append(snappedf(v.last_anim_plan_ms, 0.01))
			maxes.append(snappedf(v.max_plan_ms, 0.01))
			check_eq(_stats["move"]["unplanned_over_0.2"], 0, cfg[0] + ": 계획 밖의 큰 튐 없음")
		print("  긴 미끄러짐 %s: 계획 횟수 %s, 누적 계획 %s ms, 한 번 최대 %s ms, 프레임 수 %d" % [cfg[0], counts, totals, maxes, _stats["move"]["frames"]])
		if cfg[3] < 0 and cfg[5] == 0.0:
			# 고른 주기: 앞부분 계획(PLAN_HORIZON 표본)을 PLAN_EXTEND 남을 때마다 잇는 것 말고는 다시 계획하지 않는다.
			var samples := ceili(dur / cfg[2])
			var most := 1 + ceili(float(maxi(samples - DungeonView.PLAN_HORIZON, 0)) / (DungeonView.PLAN_HORIZON - DungeonView.PLAN_EXTEND))
			check(counts[0] <= most, "%s: 고른 주기 계획 %d 번 ≤ %d (앞부분 계획 잇기만)" % [cfg[0], counts[0], most])
