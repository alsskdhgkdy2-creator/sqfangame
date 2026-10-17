## 1인칭 미궁 시야(05 §9.2): 메시를 붙이고, 규칙 이벤트를 이동·회전·막힘 연출로 재생한다.
## 카메라는 연출이 정한 위치·방향에 매 프레임 깊이 보정(CameraGuard)을 마지막으로 적용한다.
## 규칙 상태는 연출보다 먼저 확정되어 있다. 이 노드는 상태를 바꾸지 않는다.
class_name DungeonView
extends Node3D

signal animation_finished

const EYE_HEIGHT := 1.0
const MOVE_TIME := 0.2
const SLIDE_TIME := 0.12
const TURN_TIME := 0.15
const BUMP_TIME := 0.18
## 막힘 연출에서 앞으로 밀리는 최대 거리(m).
const BUMP_DISTANCE := 0.25
## 연출 보정 계획의 표본 간격 기본값(연출 시간, 초): 휴대폰의 보통 화면 갱신(60Hz) 한 프레임.
## 실제 간격은 plan_step(최근 프레임 간격의 중앙값)을 쓴다. 90·120Hz 화면에서도 프레임이 표본에 맞게 한다.
const GUARD_PLAN_STEP := 1.0 / 60.0
const PLAN_STEP_MIN := 1.0 / 240.0
const PLAN_STEP_MAX := 1.0 / 30.0
## 프레임 시각이 표본 시각에서 표본 간격의 이 비율 안이면 표본에 맞은 것으로 본다.
const PLAN_ALIGN_TOL := 0.05
## 이번 프레임 간격이 계획 간격에서 이 비율보다 다르면(튐·지연·주기 전환) 그 프레임에서 다시 계획한다.
## 이보다 작은 흔들림(지터)은 계획을 따르고, 계획 값이 그 프레임 자세에서 막힐 때만 다시 계획한다(_apply_camera).
const PLAN_EVENT_TOL := 0.3
## 한 번에 계획하는 격자 표본 수의 한도. 연출이 더 길면(여러 칸 미끄러짐) 앞부분만 끝이 열린 계획으로 세우고,
## 남은 계획이 PLAN_EXTEND 표본보다 짧아지면 그 프레임부터 이어 계획한다(계획 한 번의 비용을 연출 길이와 상관없이 묶는다).
const PLAN_HORIZON := 24
const PLAN_EXTEND := 8
## 최근 프레임 간격의 중앙값(plan_step)이 지금 계획의 표본 간격에서 이 비율보다 달라지면 새 간격의 격자로 다시 계획한다.
const PLAN_STEP_TOL := 0.15
## 계획이 쓰는 안전 구간의 양쪽 여유(m).
const GUARD_PLAN_MARGIN := 1e-4

## 연출 속도 배율. 0 이면 즉시 끝난다(시험용).
var speed := 1.0
## 마지막 프레임의 보정 거리(디버그·시험용).
var last_guard_delta := 0.0
## reset_guard_stats 이후 보정 통계(디버그·시험용): 계산한 프레임 수, 가장 큰 |δ|, 이웃 프레임 사이 가장 큰 |Δδ|.
var guard_frames := 0
var guard_max_delta := 0.0
var guard_max_step := 0.0
## 연출 보정 계획(_plan_guard) 한 번에 걸린 시간(ms): 마지막 값과 가장 큰 값(디버그·비용 측정용).
var last_plan_ms := 0.0
var max_plan_ms := 0.0
## 연출 하나(쉬지 않고 이어진 재생 묶음)의 계획 횟수·누적 계획 시간(ms). 지금 묶음과 지난 묶음, 가장 큰 누적(디버그·비용 측정용).
var plan_count := 0
var plan_ms_total := 0.0
var last_anim_plan_count := 0
var last_anim_plan_ms := 0.0
var max_anim_plan_ms := 0.0
var max_anim_plan_count := 0
## 계획 한 번에 새로 계산한 표본 수(나머지는 같은 격자의 앞 계획에서 다시 쓴다).
var last_plan_sampled := 0

var _floor: FloorModel
var _mesh_instance := MeshInstance3D.new()
var _camera := Camera3D.new()
var _light := OmniLight3D.new()
var _materials := {}
var _verts := PackedVector3Array()
var _index: CameraGuard.Index
## 보정이 보는 정점 반경(m, CameraGuard.reach).
var guard_radius := 8.0
var _max_triangle := 0.0
var _segments: Array[Dictionary] = []
var _seg_time := 0.0
## 연출이 끝난 뒤의 기준 자세.
var _pos := Vector3.ZERO
var _yaw := 0.0
## 지금 프레임의 연출 자세(보정 전).
var _view_pos := Vector3.ZERO
var _view_yaw := 0.0
var _last_pose := Transform3D()
## 연출 보정 계획(05 §9.2.1): play 때 앞으로의 연출을 plan_step 간격으로 미리 보고 정한 δ 경로.
## 한 번에 PLAN_HORIZON 표본까지 보고, 더 긴 연출은 끝이 열린 앞부분 계획을 이어 붙인다.
## 처음은 지금 δ, 끝은 연출 끝까지 덮으면 끝 자세의 정지 해, 표본마다 안전 구간 안,
## 이웃 표본 사이 |Δδ| 최댓값이 그 계획 구간 안에서 가장 작다(연출 전체의 전역 최적은 아니다).
## 실제 프레임은 계획을 목표로 가장 가까운 유효 후보를 쓴다(안전 조건이 우선).
var _plan := PackedFloat64Array()
## 계획 표본의 시각(계획을 세운 때부터, 초). 표본 0 은 지금, 그다음은 표본 격자의 시각, 마지막은 연출이 실제로 끝나는 시각.
var _plan_times := PackedFloat64Array()
## 다음 계획의 표본 간격(초). 최근 프레임 간격(연출 시간)의 중앙값으로 정한다(시험이 바꿔 둘 수 있다).
var plan_step := GUARD_PLAN_STEP
## 지금 계획이 쓴 표본 간격.
var _plan_step_used := GUARD_PLAN_STEP
## 최근 프레임 간격(연출 시간). set_pose 는 지우지 않는다: 화면 갱신 주기는 자세가 아니라 화면의 성질이라
## 불러오기·새 게임으로 자세를 바꿔도 그대로다(시험이 그 연출을 시작할 때의 값을 기록·복원한다).
var _dt_hist := PackedFloat64Array()
## 연출 시계(초): 쉬지 않고 이어진 재생 묶음을 시작한 뒤 흐른 연출 시간.
var _clock := 0.0
## 표본 격자: 연출 시계 _grid_origin + j·_grid_step 의 자세를 표본으로 쓴다. 다시 계획해도 격자가 같으면 표본의 허용 구간을
## _sample_cache(j → 허용 구간)에서 다시 쓴다. 격자(간격·기준)·반경·재생이 바뀌면 비운다.
var _grid_step := GUARD_PLAN_STEP
var _grid_origin := 0.0
var _sample_cache := {}
var _cache_radius := -1.0
var _cache_id := -1
## 지금 계획이 연출 끝까지 가지 않고 앞부분만 본 것인지(PLAN_HORIZON).
var _plan_open := false
## 계획 값이 그 프레임 자세에서 막혀 다시 계획한 횟수(시험·디버그용, 누적).
var invalid_replans := 0
var _end_key := Vector2(-1, -1)
var _pool_key := Vector2(-1, -1)
var _pool := PackedVector3Array()
var _pool_bins_cache := {}
var _end_delta := 0.0
## 계획을 세울 때 쓴 보정 반경(시험용: 창 크기가 바뀐 뒤 다시 계획했는지).
var _plan_radius := -1.0
## 재생 번호. play·set_pose 마다 오른다. 미뤄 낸 끝 신호는 번호가 그대로일 때만 낸다(05 §9.2).
var _play_id := 0
## 마지막으로 꺼낸 반경 안 정점(회전 중에는 눈 위치가 같아 다시 쓴다).
var _near_eye := Vector3(INF, INF, INF)
var _near_radius := -1.0
var _near_verts := PackedVector3Array()
var _plan_time := 0.0


func _ready() -> void:
	add_child(_mesh_instance)
	_camera.fov = 75.0
	_camera.current = true
	add_child(_camera)
	_light.omni_range = 9.0
	_light.light_color = Color(0.7, 0.9, 1.0)
	_light.light_energy = 1.2
	_camera.add_child(_light)
	_light.position = Vector3(0, 0.5, 0.2)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.015, 0.025)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.02, 0.05, 0.08)
	env.environment.fog_density = 0.07
	add_child(env)
	get_viewport().size_changed.connect(_on_viewport_resized)


## 화면 크기가 바뀌면 보정 반경이 바뀔 수 있다. 정지 중이면 정지 해를 바로 다시 계산한다.
## 연출 중이면 정지 해를 끼워 넣지 않는다. 먼저 새 반경에서 이번 프레임의 δ 를 정하고(지금 δ 가 새 조건에서도 안전하면
## 그대로, 아니면 그에 가장 가까운 안전한 값, solve_near), 그 실제로 보인 값에서 남은 연출을 다시 계획한다.
func _on_viewport_resized() -> void:
	_last_pose = Transform3D()
	if _index == null:
		return
	if is_busy() and speed > 0.0:
		_apply_camera(last_guard_delta)
		_plan_guard()
	else:
		_apply_camera()


## 층을 정하고 메시를 만든다.
func setup(f: FloorModel, world: WorldState) -> void:
	_floor = f
	_make_materials(f.theme)
	rebuild(world)


## 세계 상태(열린 지름길·찾은 통로)가 바뀌면 메시와 정점 목록을 다시 만든다.
func rebuild(world: WorldState) -> void:
	var built := DungeonMeshBuilder.build(_floor, world)
	for i in built.surface_names.size():
		built.mesh.surface_set_material(i, _materials[built.surface_names[i]])
	_mesh_instance.mesh = built.mesh
	_verts = built.verts
	_index = CameraGuard.Index.new(_verts)
	_near_eye = Vector3(INF, INF, INF)
	_max_triangle = built.max_triangle
	_update_radius()
	_last_pose = Transform3D()  # 정점이 바뀌었으니 보정을 다시 계산


func vertex_count() -> int:
	return _verts.size()


## 지금 카메라 위치(보정 포함)와 방향.
func camera_transform() -> Transform3D:
	return _camera.global_transform


func camera_fov() -> float:
	return _camera.fov


func reset_guard_stats() -> void:
	guard_frames = 0
	guard_max_delta = 0.0
	guard_max_step = 0.0


## 보정 반경을 지금 Camera3D 의 세로 시야각과 시야 영역의 화면비로 정한다.
func _update_radius() -> void:
	var sz := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	var aspect := sz.x / sz.y if sz.y > 0.0 else CameraGuard.MAX_ASPECT
	guard_radius = CameraGuard.reach(_max_triangle, _camera.fov, aspect)


## 연출 없이 자세를 바로 정한다(새 게임·불러오기). 진행 중이던 재생과 아직 내지 않은 끝 신호를 취소한다.
## 정지 해는 직전 자세와 같아 보여도 늘 다시 계산한다(연출 중 해가 남지 않게).
func set_pose(cell: Vector2i, facing: int) -> void:
	_play_id += 1
	_segments.clear()
	_seg_time = 0.0
	_clock = 0.0
	_plan = PackedFloat64Array()
	_plan_times = PackedFloat64Array()
	_last_pose = Transform3D()
	_pos = DungeonMeshBuilder.cell_center(cell)
	_yaw = yaw_of(facing)
	_view_pos = _pos
	_view_yaw = _yaw
	_apply_camera()


static func yaw_of(facing: int) -> float:
	return -facing * PI / 2.0


## 연출이 끝난 yaw 를 set_pose 와 똑같은 값(yaw_of)으로 맞춘다. 같은 자세의 정지 해가 float 표현 차이로
## 갈리지 않게 한다(±ε 두 후보가 같은 거리일 때 1e-7 차이로 뒤집힐 수 있다).
static func _rest_yaw(yaw: float) -> float:
	return yaw_of(posmod(roundi(-yaw / (PI / 2.0)), 4))


func is_busy() -> bool:
	return not _segments.is_empty()


## 규칙 이벤트를 연출로 쌓는다. move_dir = 이번 행동이 움직이려던 방향(막힘 연출용, 없으면 -1).
func play(events: Array[Dictionary], move_dir: int = -1) -> void:
	_play_id += 1  # 앞 재생이 미뤄 둔 끝 신호는 이 재생의 끝 신호가 대신한다
	if _segments.is_empty():
		# 새 연출 묶음: 연출 시계와 표본 격자를 지금에 맞추고 비용 기록을 새로 센다.
		_clock = 0.0
		_grid_origin = 0.0
		_grid_step = plan_step
		plan_count = 0
		plan_ms_total = 0.0
	var plan_pos: Vector3 = _pos if _segments.is_empty() else _segments[-1]["to_pos"]
	var plan_yaw: float = _yaw if _segments.is_empty() else _segments[-1]["to_yaw"]
	for ev in events:
		match ev["type"]:
			"moved":
				var to := DungeonMeshBuilder.cell_center(ev["to"])
				var dur := MOVE_TIME if ev["via"] == "step" else SLIDE_TIME
				_segments.append({"kind": "move", "from_pos": plan_pos, "to_pos": to, "from_yaw": plan_yaw, "to_yaw": plan_yaw, "time": dur, "ease": ev["via"] == "step"})
				plan_pos = to
			"turned":
				var target := yaw_of(ev["facing"])
				var to_yaw: float = plan_yaw + wrapf(target - plan_yaw, -PI, PI)
				_segments.append({"kind": "turn", "from_pos": plan_pos, "to_pos": plan_pos, "from_yaw": plan_yaw, "to_yaw": to_yaw, "time": TURN_TIME})
				plan_yaw = to_yaw
			"blocked":
				if move_dir >= 0:
					var v := Dir.vec(move_dir)
					_segments.append({"kind": "bump", "from_pos": plan_pos, "to_pos": plan_pos, "from_yaw": plan_yaw, "to_yaw": plan_yaw, "time": BUMP_TIME, "dir": Vector3(v.x, 0, v.y)})
	if not _segments.is_empty() and speed > 0.0:
		_plan_guard()
	# 끝 신호는 다음 차례에 낸다(받는 쪽이 곧바로 다음 행동을 시작해도 되돌아 호출되지 않게).
	if _segments.is_empty():
		_emit_finished.call_deferred(_play_id)
	elif speed <= 0.0:
		_finish_all()


## 미뤄 낸 끝 신호: 그사이 set_pose·새 play 가 없었을 때만 낸다.
func _emit_finished(id: int) -> void:
	if id == _play_id:
		animation_finished.emit()


func _finish_all() -> void:
	if _segments.is_empty():
		return
	var last: Dictionary = _segments[-1]
	_pos = last["to_pos"]
	_yaw = _rest_yaw(last["to_yaw"])
	_segments.clear()
	_seg_time = 0.0
	_view_pos = _pos
	_view_yaw = _yaw
	_clock = 0.0
	_last_pose = Transform3D()  # 끝 자세가 직전 자세와 같아 보여도 정지 해로 다시 계산한다
	_apply_camera()
	_note_animation_cost()
	_emit_finished.call_deferred(_play_id)


## 끝난 연출 묶음의 계획 횟수·누적 시간을 「지난 연출」 기록으로 옮긴다.
func _note_animation_cost() -> void:
	last_anim_plan_count = plan_count
	last_anim_plan_ms = plan_ms_total
	max_anim_plan_ms = maxf(max_anim_plan_ms, plan_ms_total)
	max_anim_plan_count = maxi(max_anim_plan_count, plan_count)


func _process(delta: float) -> void:
	var dt := delta * speed
	if speed > 0.0:
		_note_frame_time(dt)
	if _segments.is_empty():
		return
	if speed <= 0.0:
		_finish_all()
		return
	_seg_time += delta * speed
	while not _segments.is_empty() and _seg_time >= _segments[0]["time"]:
		_seg_time -= _segments[0]["time"]
		var done: Dictionary = _segments.pop_front()
		_pos = done["to_pos"]
		_yaw = done["to_yaw"]
	if _segments.is_empty():
		_seg_time = 0.0
		_yaw = _rest_yaw(_yaw)
		_view_pos = _pos
		_view_yaw = _yaw
		_clock = 0.0
		_last_pose = Transform3D()  # 끝 자세는 직전 프레임과 거의 같아도 정지 해로 다시 계산한다
		_apply_camera()
		_note_animation_cost()
		animation_finished.emit()
		return
	var pose := _segment_pose(_segments[0], _seg_time)
	_view_pos = pose[0]
	_view_yaw = pose[1]
	_plan_time += dt
	_clock += dt
	if not _plan.is_empty():
		_replan_if_needed(dt)
	_apply_camera(_plan_target(), true)


## 이번 프레임에서 다시 계획할지 정한다(05 §9.2.1).
## - 최근 간격의 중앙값이 계획 간격에서 PLAN_STEP_TOL 넘게 바뀜(주기 전환): 새 간격의 격자를 이 프레임에 맞춰 세운다.
## - 이번 간격이 계획 간격에서 PLAN_EVENT_TOL 넘게 다름(튐·지연, 120→60Hz 의 두 표본 건너뜀, 60→120Hz 의 반 표본):
##   이 프레임부터 다시 계획한다(건너뛴 표본을 지나는 계획을 따르지 않는다). 프레임이 격자에서 어긋났으면 격자를
##   이 프레임에 맞춰 옮긴다(뒤이어 고른 프레임이 다시 표본에 맞는다).
## - 앞부분만 본 계획이 거의 끝나 감: 이 프레임부터 이어 계획한다(같은 격자라 이미 계산한 표본은 다시 쓴다).
## 작은 흔들림(지터)은 여기서 다시 계획하지 않는다. 계획 값이 그 프레임 자세에서 막히면 _apply_camera 가 다시 계획한다.
func _replan_if_needed(dt: float) -> void:
	var step := _plan_step_used
	if absf(plan_step - step) > PLAN_STEP_TOL * step:
		_set_grid(plan_step, _clock)
		_plan_guard(true)
		return
	if absf(dt - step) > PLAN_EVENT_TOL * step:
		var phase := fposmod(_clock - _grid_origin, _grid_step)
		if minf(phase, _grid_step - phase) > PLAN_ALIGN_TOL * _grid_step:
			_set_grid(_grid_step, _clock)
		_plan_guard(true)
		return
	if _plan_open and _plan_times[_plan_times.size() - 1] - _plan_time < PLAN_EXTEND * step:
		_plan_guard(true)


func _set_grid(step: float, origin: float) -> void:
	_grid_step = step
	_grid_origin = origin
	_sample_cache.clear()


## 최근 프레임 간격(연출 시간)을 모아 다음 계획의 표본 간격을 정한다(중앙값이라 한 번 튄 프레임은 무시한다).
func _note_frame_time(dt: float) -> void:
	if dt <= 0.0:
		return
	_dt_hist.append(dt)
	if _dt_hist.size() > 5:
		_dt_hist.remove_at(0)
	var sorted := _dt_hist.duplicate()
	sorted.sort()
	plan_step = clampf(sorted[sorted.size() / 2], PLAN_STEP_MIN, PLAN_STEP_MAX)


## 구간 seg 를 시작한 지 time 초 뒤의 연출 자세 [위치, yaw].
static func _segment_pose(seg: Dictionary, time: float) -> Array:
	var t: float = clampf(time / seg["time"], 0.0, 1.0)
	match seg["kind"]:
		"move":
			var k := smoothstep(0.0, 1.0, t) if seg["ease"] else t
			return [(seg["from_pos"] as Vector3).lerp(seg["to_pos"], k), seg["from_yaw"]]
		"turn":
			return [seg["from_pos"], lerpf(seg["from_yaw"], seg["to_yaw"], smoothstep(0.0, 1.0, t))]
		"bump":
			return [seg["from_pos"] + seg["dir"] * BUMP_DISTANCE * sin(PI * t), seg["from_yaw"]]
	return [seg["to_pos"], seg["to_yaw"]]


## 지금부터 남은 연출의 δ 계획을 세운다.
## 표본은 지금(0), 표본 격자(연출 시계 _grid_origin + j·_grid_step)의 지금 뒤 시각들, 연출이 실제로 끝나는 시각의 끝 자세
## (정지 해로 고정). 격자 표본의 허용 구간은 같은 격자의 앞 계획에서 계산한 것을 다시 쓴다(_sample_cache).
## from_frame = false: 지금 자세는 이미 last_guard_delta 로 보였다(표본 0 = 그 값으로 고정).
## from_frame = true: 지금 자세는 이번 프레임에 처음 보인다. 앞에 「직전 프레임 = last_guard_delta」를 두고 표본 0 도 고른다.
func _plan_guard(from_frame: bool = false) -> void:
	var t0 := Time.get_ticks_usec()
	_plan = PackedFloat64Array()
	_plan_times = PackedFloat64Array()
	_plan_time = 0.0
	if _index == null or _segments.is_empty():
		return
	_update_radius()
	if _cache_radius != guard_radius or _cache_id != _play_id:
		_sample_cache.clear()
		_cache_radius = guard_radius
		_cache_id = _play_id
	var step := _grid_step
	_plan_step_used = step
	var sampled := 0
	var allowed: Array[PackedFloat64Array] = []
	if from_frame:
		allowed.append(PackedFloat64Array([last_guard_delta, last_guard_delta]))
		allowed.append(_sample_allowed(_segments[0], _segment_pose(_segments[0], _seg_time)))
		sampled += 1
	else:
		allowed.append(PackedFloat64Array())  # 표본 0 = 지금(plan_path 가 start 로 고정한다)
	_plan_times.append(0.0)
	var remaining := -_seg_time
	for seg in _segments:
		remaining += seg["time"]
	var j := floori((_clock - _grid_origin) / step + PLAN_ALIGN_TOL) + 1
	var seg_i := 0
	var seg_t := _seg_time
	var rel_prev := 0.0
	var count := 0
	_plan_open = false
	while true:
		var rel := _grid_origin + j * step - _clock
		if rel >= remaining - 1e-9:
			break
		if count >= PLAN_HORIZON:
			_plan_open = true
			break
		seg_t += rel - rel_prev
		rel_prev = rel
		while seg_i < _segments.size() and seg_t >= _segments[seg_i]["time"]:
			seg_t -= _segments[seg_i]["time"]
			seg_i += 1
		if seg_i >= _segments.size():
			break
		var a: Variant = _sample_cache.get(j)
		if a == null:
			a = _sample_allowed(_segments[seg_i], _segment_pose(_segments[seg_i], seg_t))
			_sample_cache[j] = a
			sampled += 1
		allowed.append(a)
		_plan_times.append(rel)
		j += 1
		count += 1
	var end_pose: Array = [_segments[-1]["to_pos"], _segments[-1]["to_yaw"]]
	if not _plan_open:
		allowed.append(PackedFloat64Array())  # 끝 표본(정지 해로 고정)
		_plan_times.append(remaining)
	# 끝 자세의 정지 해는 같은 재생·반경이면 다시 쓴다(다시 계획할 때마다 반경 안 정점을 다시 꺼내지 않게).
	if _end_key != Vector2(_play_id, guard_radius):
		_end_key = Vector2(_play_id, guard_radius)
		_end_delta = _static_delta(end_pose[0], _rest_yaw(end_pose[1]))
	# 앞부분만 보는 계획은 끝이 열려 있고, 마지막 값은 끝 자세의 정지 해 쪽으로 고른다.
	_plan = CameraGuard.plan_path(allowed, last_guard_delta, NAN if _plan_open else _end_delta, _end_delta)
	if from_frame:
		_plan = _plan.slice(1)
	_plan_radius = guard_radius
	last_plan_sampled = sampled
	last_plan_ms = (Time.get_ticks_usec() - t0) / 1000.0
	max_plan_ms = maxf(max_plan_ms, last_plan_ms)
	plan_count += 1
	plan_ms_total += last_plan_ms


## 자세 pose 의 허용 구간(free_intervals). 정점은 그 구간의 후보(_seg_cands)에서 _near(eye) 와 같은 조건
## (바닥 평면 거리² ≤ 반경²)과 같은 깊이 조건(|w| < WIDE_LIMIT + ε)으로 고른다: 정점 집합이 보정(_apply_camera)과 같다.
func _sample_allowed(seg: Dictionary, pose: Array) -> PackedFloat64Array:
	var eye: Vector3 = pose[0] + Vector3.UP * EYE_HEIGHT
	var fwd := -Basis(Vector3.UP, pose[1]).z
	var r2 := guard_radius * guard_radius
	var reach := CameraGuard.WIDE_LIMIT + CameraGuard.EPS
	var ws := PackedFloat64Array()
	var cands := _seg_cands(seg)
	if seg.has("bins"):
		# 방향이 고정된 구간: w = v·fwd − eye·fwd 라 판 [eye·fwd − reach, eye·fwd + reach] 에 걸치는 칸만 본다
		# (칸 경계에 여유를 두고, 아래와 같은 조건으로 다시 거른다).
		var bins: Dictionary = seg["bins"]
		var e := eye.dot(fwd)
		for key in range(floori((e - reach - 1e-4) / _BIN), floori((e + reach + 1e-4) / _BIN) + 1):
			if not bins.has(key):
				continue
			var bv: PackedVector3Array = bins[key]
			for v in bv:
				var w := (v - eye).dot(fwd)
				if absf(w) < reach and Vector2(v.x - eye.x, v.z - eye.z).length_squared() <= r2:
					ws.append(w)
	else:
		for v in cands:
			var w := (v - eye).dot(fwd)
			if absf(w) < reach and Vector2(v.x - eye.x, v.z - eye.z).length_squared() <= r2:
				ws.append(w)
	return CameraGuard.free_intervals(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, GUARD_PLAN_MARGIN)


## 연출 구간 하나 동안 깊이 |w| < WIDE_LIMIT + ε 가 될 수 있는 반경 안 정점(표본마다 전체 정점을 다시 보지 않게 한 번 고른다).
## 정점은 남은 연출 전체를 덮는 한 번의 반경 질의(_batch_pool)에서 거른다.
## - 이동·막힘(방향 고정, 눈이 선분 위): 선분까지 바닥 평면 거리 ≤ 반경, 앞 방향 투영이 눈의 투영 범위 ± reach 안.
##   투영 BIN 간격의 칸(seg["bins"])으로 나눠 두고, 표본마다 그 표본의 판(투영 ± reach)에 걸치는 칸만 본다.
## - 회전(눈 고정, 90° 이하): w(yaw) 는 yaw 의 정현파라 90° 안에서 0 을 많아야 한 번 지난다. 양 끝의 부호가 다르거나
##   양 끝 가운데 하나가 |w| < reach 인 정점만 남는다(0 을 지나지 않으면 |w| 의 가장 작은 값은 끝점에 있다).
const _BIN := 0.25


func _seg_cands(seg: Dictionary) -> PackedVector3Array:
	if seg.get("cands_r", -1.0) == guard_radius:
		return seg["cands"]
	var reach := CameraGuard.WIDE_LIMIT + CameraGuard.EPS
	var r2 := guard_radius * guard_radius
	var out := PackedVector3Array()
	var p0: Vector3 = seg["from_pos"]
	var up := Vector3.UP * EYE_HEIGHT
	var pool := _batch_pool()
	if seg["kind"] == "turn":
		var eye := p0 + up
		var f0 := -Basis(Vector3.UP, seg["from_yaw"]).z
		var f1 := -Basis(Vector3.UP, seg["to_yaw"]).z
		var wide := absf(float(seg["to_yaw"]) - float(seg["from_yaw"])) > PI / 2.0 + 1e-6
		for v in pool:
			if Vector2(v.x - eye.x, v.z - eye.z).length_squared() > r2:
				continue
			var w0 := (v - eye).dot(f0)
			var w1 := (v - eye).dot(f1)
			if wide or w0 * w1 <= 0.0 or minf(absf(w0), absf(w1)) < reach:
				out.append(v)
	else:
		var p1: Vector3 = seg["to_pos"] if seg["kind"] == "move" else p0 + seg["dir"] * BUMP_DISTANCE
		var fwd := -Basis(Vector3.UP, seg["from_yaw"]).z
		var e0 := (p0 + up).dot(fwd)
		var e1 := (p1 + up).dot(fwd)
		var lo := minf(e0, e1) - reach
		var hi := maxf(e0, e1) + reach
		var a := Vector2(p0.x, p0.z)
		var ab := Vector2(p1.x - p0.x, p1.z - p0.z)
		var ab2 := maxf(ab.length_squared(), 1e-12)
		var bins := {}
		var pool_bins := _pool_bins(seg["from_yaw"], fwd)
		var near_pool := PackedVector3Array()
		for key in range(floori(lo / _BIN), floori(hi / _BIN) + 1):
			if pool_bins.has(key):
				near_pool.append_array(pool_bins[key])
		for v in near_pool:
			var pv := v.dot(fwd)
			if pv <= lo or pv >= hi:
				continue
			# 선분까지 바닥 평면 거리(여유 1e-4: 표본마다 같은 조건으로 다시 거른다).
			var q := Vector2(v.x, v.z)
			var t := clampf((q - a).dot(ab) / ab2, 0.0, 1.0)
			if (q - (a + ab * t)).length() > guard_radius + 1e-4:
				continue
			var key := floori(pv / _BIN)
			if not bins.has(key):
				bins[key] = PackedVector3Array()
			bins[key].append(v)
			out.append(v)
		seg["bins"] = bins
	seg["cands"] = out
	seg["cands_r"] = guard_radius
	return out


## _batch_pool 의 정점을 방향 fwd 의 투영 _BIN 칸으로 나눈 것(여러 칸 미끄러짐은 구간마다 방향이 같아 한 번만 나눈다).
func _pool_bins(yaw: float, fwd: Vector3) -> Dictionary:
	var pool := _batch_pool()
	if _pool_bins_cache.has(yaw):
		return _pool_bins_cache[yaw]
	var bins := {}
	for v in pool:
		var key := floori(v.dot(fwd) / _BIN)
		if not bins.has(key):
			bins[key] = PackedVector3Array()
		bins[key].append(v)
	_pool_bins_cache[yaw] = bins
	return bins


## 남은 연출의 모든 눈 위치를 덮는 반경 안 정점(같은 재생·반경이면 다시 쓴다).
func _batch_pool() -> PackedVector3Array:
	var key := Vector2(_play_id, guard_radius)
	if _pool_key == key:
		return _pool
	_pool_bins_cache = {}
	var lo := Vector2(INF, INF)
	var hi := -lo
	for seg in _segments:
		for p in [seg["from_pos"], seg["to_pos"]] + ([seg["from_pos"] + seg["dir"] * BUMP_DISTANCE] if seg["kind"] == "bump" else []):
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var c := (lo + hi) / 2.0
	_pool = _index.near(Vector3(c.x, 0.0, c.y), guard_radius + (hi - lo).length() / 2.0 + 1e-3)
	_pool_key = key
	return _pool


## 계획에서 지금 연출 시각의 δ(표본 사이는 시각 비율로 직선으로 잇는다). 계획이 없으면 직전 δ.
func _plan_target() -> float:
	if _plan.is_empty():
		return last_guard_delta
	var n := _plan.size()
	if n == 1 or _plan_time >= _plan_times[n - 1]:
		return _plan[n - 1]
	var i := clampi(_plan_times.bsearch(_plan_time + 1e-9, false) - 1, 0, n - 2)
	var t0: float = _plan_times[i]
	var t1: float = _plan_times[i + 1]
	return lerpf(_plan[i], _plan[i + 1], clampf((_plan_time - t0) / maxf(t1 - t0, 1e-9), 0.0, 1.0))


## 눈 위치 eye 에서 보정 반경 안의 정점.
func _near(eye: Vector3) -> PackedVector3Array:
	if eye != _near_eye or guard_radius != _near_radius:
		_near_eye = eye
		_near_radius = guard_radius
		_near_verts = _index.near(eye, guard_radius)
	return _near_verts


## 자세(pos·yaw)의 정지 해.
func _static_delta(pos: Vector3, yaw: float) -> float:
	if _index == null:
		return 0.0
	var eye := pos + Vector3.UP * EYE_HEIGHT
	_update_radius()
	return CameraGuard.solve(_near(eye), eye, -Basis(Vector3.UP, yaw).z)


## 연출 자세 + 깊이 보정 → 카메라. 자세가 바뀌지 않았으면 다시 계산하지 않는다.
## target 이 NAN 이면 정지 자세: 이력과 상관없는 결정적 해(CameraGuard.solve).
## 연출 중이면 target(계획 값)에 가장 가까운 유효 후보(CameraGuard.solve_near, 05 §9.2.1).
## replan = true(연출 프레임)이고 계획 값이 이 자세에서 막혔으면(표본 사이 시각·지터) 먼저 이 프레임부터 다시 계획하고
## 그 계획이 고른 값을 목표로 쓴다(안전 조건이 계획 밖으로 크게 옮기지 않게).
func _apply_camera(target: float = NAN, replan: bool = false) -> void:
	var basis := Basis(Vector3.UP, _view_yaw)
	var eye := _view_pos + Vector3.UP * EYE_HEIGHT
	var pose := Transform3D(basis, eye)
	if pose.is_equal_approx(_last_pose):
		return
	_last_pose = pose
	var fwd := -basis.z
	_update_radius()
	var before := last_guard_delta
	if _index == null:
		last_guard_delta = 0.0
	elif is_nan(target):
		last_guard_delta = CameraGuard.solve(_near(eye), eye, fwd)
	else:
		var ws := CameraGuard.depths(_near(eye), eye, fwd, CameraGuard.WIDE_LIMIT + CameraGuard.EPS)
		if replan and not _plan.is_empty() and not CameraGuard.is_free(ws, CameraGuard.EPS, CameraGuard.WIDE_LIMIT, target):
			_plan_guard(true)
			invalid_replans += 1
			target = _plan_target()
		last_guard_delta = CameraGuard.solve_near_ws(ws, target)
	if guard_frames > 0:
		guard_max_step = maxf(guard_max_step, absf(last_guard_delta - before))
	guard_frames += 1
	guard_max_delta = maxf(guard_max_delta, absf(last_guard_delta))
	_camera.global_transform = Transform3D(basis, eye + fwd * last_guard_delta)


func _make_materials(theme: String) -> void:
	var dir := "res://assets/textures/%s/" % theme
	var wall := StandardMaterial3D.new()
	wall.albedo_texture = load(dir + "wall.png")
	wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wall.roughness = 0.9
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load(dir + "floor.png")
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	floor_mat.vertex_color_use_as_albedo = true
	floor_mat.roughness = 0.85
	var ceiling := StandardMaterial3D.new()
	ceiling.vertex_color_use_as_albedo = true
	ceiling.roughness = 1.0
	var frame := StandardMaterial3D.new()
	frame.vertex_color_use_as_albedo = true
	frame.metallic = 0.5
	frame.roughness = 0.45
	var plate := StandardMaterial3D.new()
	plate.vertex_color_use_as_albedo = true
	plate.roughness = 0.6
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.disable_fog = true
	_materials = {"wall": wall, "floor": floor_mat, "ceiling": ceiling, "frame": frame, "plate": plate, "glow": glow}
