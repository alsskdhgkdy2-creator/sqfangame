## 카메라 깊이 0 피하기(05 §9.2.1, §11.2 카메라 보정).
extends TestCase

const EPS := CameraGuard.EPS
## nearest_free 퍼지 확인의 격자 간격(m).
const GRID_FINE := 1e-6


## 칸 모서리 격자 정점(바닥·천장 높이).
func _grid(w: int, h: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for y in h + 1:
		for x in w + 1:
			for hh in [0.0, 2.0]:
				out.append(Vector3((x - 0.5) * 2.0, hh, (y - 0.5) * 2.0))
	return out


func _check_fixed(verts: PackedVector3Array, cam: Vector3, fwd: Vector3, label: String) -> float:
	var d := CameraGuard.solve(verts, cam, fwd)
	check(absf(d) <= 2.0 * EPS + 1e-9, "%s: |δ| %.4f > 2ε" % [label, d])
	var m := CameraGuard.min_depth(verts, cam + fwd * d, fwd)
	check(m >= EPS - 1e-6, "%s: 보정 뒤 최소 |w| %.4f < ε" % [label, m])
	return d


func test_boundary_plane_position() -> void:
	# 칸 (5,5) 가운데 (10, 1, 10) 에서 북쪽으로 반 칸 = 경계 면 z = 9.
	var verts := _grid(10, 10)
	var d := _check_fixed(verts, Vector3(10, 1, 9), Vector3.FORWARD, "경계 면")
	check(d != 0.0, "경계 면에서는 옮겨야 함")
	check(d < 0.0, "같은 거리면 뒤로 물러남(δ < 0), 실제 %f" % d)


func test_45_degree_turn() -> void:
	var verts := _grid(10, 10)
	var fwd := Vector3(-1, 0, -1).normalized()
	check(CameraGuard.min_depth(verts, Vector3(10, 1, 10), fwd) < 1e-6, "45°에서 깊이 0 정점이 있어야 함(시험 전제)")
	_check_fixed(verts, Vector3(10, 1, 10), fwd, "45° 회전")


func test_far_vertex_on_wide_view() -> void:
	# 화면비와 상관없이 모든 정점을 본다: 옆으로 멀리(시야 밖일 수 있는) 정점도 깊이 0 이면 보정한다.
	var verts := PackedVector3Array([Vector3(40, 0, 0), Vector3(0, 0, -5), Vector3(-3, 2, 3)])
	var d := _check_fixed(verts, Vector3.ZERO, Vector3.FORWARD, "멀리 있는 정점")
	check(d != 0.0, "멀리 있는 깊이 0 정점도 보정")


func test_safe_position_unchanged() -> void:
	var verts := _grid(10, 10)
	check_eq(CameraGuard.solve(verts, Vector3(10, 1, 10), Vector3.FORWARD), 0.0, "칸 가운데 정면")
	check_eq(CameraGuard.solve(verts, Vector3(10, 1, 10.4), Vector3.RIGHT), 0.0, "칸 안 평행 이동 중")


func test_tie_prefers_backward() -> void:
	var verts := PackedVector3Array([Vector3(0, 0, 0)])
	check_eq(CameraGuard.solve(verts, Vector3.ZERO, Vector3.FORWARD), -EPS, "정점 하나가 정확히 0: 뒤로 ε")


func test_dense_cluster_widens_search() -> void:
	# 1단계 실험의 몰림: w = -0.085, 0, +0.085 → 2ε 안에 답이 없고 넓혀 찾는다.
	var verts := PackedVector3Array([Vector3(0, 0, 0.085), Vector3(0, 0, 0), Vector3(0, 0, -0.085)])
	var d := CameraGuard.solve(verts, Vector3.ZERO, Vector3.FORWARD)
	check(absf(d) > 2.0 * EPS and absf(d) <= CameraGuard.WIDE_LIMIT, "넓힌 범위의 답, 실제 %f" % d)
	check(CameraGuard.min_depth(verts, Vector3.FORWARD * d, Vector3.FORWARD) >= EPS - 1e-6, "넓힌 답도 |w| ≥ ε")


# ---- 허용치·경계 계약 ----

## 깊이 목록 → 한 줄 위의 정점(카메라 원점, 앞 = FORWARD 이면 w 가 그대로 깊이).
func _line(ws: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for w in ws:
		out.append(Vector3.FORWARD * w)
	return out


## 허용 집합은 is_free 하나: 막힌 구간은 (w − h, w + h), h = ε − FREE_TOL. 깊이 0 과 0.0999985 의 두 구간은
## (−0.049999, 0.049999) 와 (0.0499995, 0.1499975) 라 겹치지 않고 [0.049999, 0.0499995] 가 허용된다.
## 목표 0.04 에서 가장 가까운 허용 점은 그 틈의 아래 끝 +0.049999 다(음수 쪽 −0.049999 보다 가깝다).
func test_nearest_free_uses_is_free_set() -> void:
	var ws := PackedFloat64Array([0.0, 0.0999985])
	var h := 0.05 - CameraGuard.FREE_TOL
	var d: Variant = CameraGuard.nearest_free(ws, 0.05, 0.25, 0.04)
	check(d != null, "답이 있다")
	if d == null:
		return
	check(CameraGuard.is_free(ws, 0.05, 0.25, d), "돌려준 δ %.7f 는 안전 조건을 지킨다" % d)
	check(absf(d - h) < 1e-12, "가장 가까운 허용 점 = 틈의 아래 끝 %.7f (실제 %.9f)" % [h, d])
	# 검토 반례: 목표 0.04999925 는 두 깊이와 0.04999925 ≥ 0.049999 떨어져 허용된다 → 그대로.
	var t := 0.04999925
	check(CameraGuard.is_free(ws, 0.05, 0.25, t), "준비: 목표가 허용된다")
	check_eq(CameraGuard.nearest_free(ws, 0.05, 0.25, t), t, "허용되는 목표는 그대로 돌려준다")
	# 정확히 맞닿은 두 구간: 맞닿은 점이 허용되면 그 점(합치지 않는다).
	var touch := PackedFloat64Array([0.0, 2.0 * h])
	var dt: Variant = CameraGuard.nearest_free(touch, 0.05, 0.25, h * 0.9)
	check(dt != null and CameraGuard.is_free(touch, 0.05, 0.25, dt) and absf(float(dt) - h) < 1e-9, "맞닿은 점 %s" % str(dt))
	# 겹쳐 합쳐진 덩어리: 끝점이 덩어리 밖.
	var merged := PackedFloat64Array([0.0, 0.09])
	var dm: Variant = CameraGuard.nearest_free(merged, 0.05, 0.25, 0.05)
	check(dm != null and absf(float(dm) - (0.09 + h)) < 1e-9, "합친 덩어리의 가까운 끝 %s" % str(dm))


## 한도를 허용치만큼 넘는 끝점은 돌려주지 않는다(검토 지적: 예전에는 limit + 1e-6 까지 받았다).
func test_nearest_free_never_exceeds_limit() -> void:
	var ws := PackedFloat64Array([0.2000005])
	var d: Variant = CameraGuard.nearest_free(ws, 0.05, 0.25, 0.24)
	check(d != null and absf(d) <= 0.25 and CameraGuard.is_free(ws, 0.05, 0.25, d), "한도 안의 유효한 δ (%s)" % str(d))
	var w2 := PackedFloat64Array([0.0])
	var d2: Variant = CameraGuard.nearest_free(w2, 0.05, 0.25, 0.9)
	check_eq(d2, 0.25, "목표가 한도 밖이면 한도로 자른다")
	# 한도 안이 모두 막히면 null(solve_near 는 best_effort).
	var full := PackedFloat64Array([-0.24, -0.16, -0.08, 0.0, 0.08, 0.16, 0.24])
	check(CameraGuard.nearest_free(full, 0.05, 0.25, 0.01) == null, "모두 막히면 null")


## solve_near 가 내놓는 값은 모두 안전 조건을 지키거나(is_free), 답이 없을 때의 best_effort 다.
## 답이 없다고 할 때는 1mm 격자에 ε + 1e-4 이상 떨어진 점도, 1µm 격자의 허용 점도 정말 없다.
## 답이 있을 때는 1µm 격자에 그 답보다 target 에 더 가까운 허용 점이 없다.
func test_solve_near_outputs_pass_final_check() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261017
	var bad := 0
	var nulls := 0
	var checked := 0
	for trial in 1000:
		var ws := PackedFloat64Array()
		var n := rng.randi_range(0, 14)
		var snap: float = [0.05, 0.09, 0.1][trial % 3]
		for i in n:
			# 겹침·맞닿음이 잘 생기게 격자 근처에 몰아 두고, 절반은 허용치 근처(±3e-6)만큼 흔든다.
			ws.append(snappedf(rng.randf_range(-0.3, 0.3), snap) + rng.randf_range(-3e-6, 3e-6) * float(rng.randi_range(0, 1)))
		var target := rng.randf_range(-0.3, 0.3)
		var d := CameraGuard.solve_near(_line(Array(ws)), Vector3.ZERO, Vector3.FORWARD, target)
		var keep := CameraGuard.depths(_line(Array(ws)), Vector3.ZERO, Vector3.FORWARD, CameraGuard.WIDE_LIMIT + EPS)
		var nf: Variant = CameraGuard.nearest_free(keep, EPS, CameraGuard.WIDE_LIMIT, target)
		if nf == null:
			nulls += 1
			if d != CameraGuard.best_effort(keep, CameraGuard.WIDE_LIMIT):
				bad += 1
				failures.append("답이 없을 때 best_effort 가 아니다: %s → %f" % [ws, d])
			var x := -CameraGuard.WIDE_LIMIT
			while x <= CameraGuard.WIDE_LIMIT:
				if CameraGuard.is_free(keep, EPS + 1e-4, CameraGuard.WIDE_LIMIT, x, 0.0):
					bad += 1
					failures.append("답이 없다고 했지만 %f 가 비어 있다: %s" % [x, ws])
					break
				x += 1e-3
			if _grid_nearest(keep, target) < INF:
				bad += 1
				failures.append("답이 없다고 했지만 1µm 격자에 허용 점이 있다: %s" % [ws])
		elif not CameraGuard.is_free(keep, EPS, CameraGuard.WIDE_LIMIT, d) or d != nf:
			bad += 1
			failures.append("최종 확인 실패: %s, 목표 %f → %f" % [ws, target, d])
		else:
			# 돌려준 값보다 target 에 (격자 간격 넘게) 더 가까운 허용 점이 1µm 격자에 없다.
			checked += 1
			var g := _grid_nearest(keep, target)
			if g < absf(d - target) - GRID_FINE:
				bad += 1
				failures.append("더 가까운 허용 점이 있다: %s, 목표 %.7f → %.7f, 격자 거리 %.7f" % [ws, target, d, g])
		if bad > 5:
			break
	check(nulls > 0 and nulls < 1000, "준비: 답 없음과 있음이 섞였다 (%d)" % nulls)
	check(checked > 500, "준비: 1µm 격자 확인 %d 번" % checked)


## 1µm 격자(target 에서 시작)에서 target 에 가장 가까운 허용 점(is_free)까지의 거리. 없으면 INF.
## 모든 격자점을 is_free 로 본다. 다만 막힌 점은 그 점을 막은 정점의 막힌 범위 끝 바로 앞 격자로 건너뛴다
## (그 사이의 격자점은 같은 정점이 막는다: 거리 < ε − FREE_TOL).
func _grid_nearest(ws: PackedFloat64Array, target: float) -> float:
	var lim := CameraGuard.WIDE_LIMIT
	var h := EPS - CameraGuard.FREE_TOL
	var t := clampf(target, -lim, lim)
	var best := INF
	for dir in [1.0, -1.0]:
		var k := 0
		while true:
			var x: float = t + dir * k * GRID_FINE
			if absf(x) > lim:
				break
			var blocker := NAN
			for w in ws:
				if absf(w - x) < h:
					blocker = w
					break
			if is_nan(blocker):
				best = minf(best, absf(x - target))
				break
			var edge: float = blocker + dir * h
			k = maxi(k + 1, floori(absf(edge - t) / GRID_FINE))
	return best


## free_intervals: 정점이 없으면 [−limit, limit] 그대로(margin 은 정점 쪽 끝에만, 양쪽 대칭).
## 돌려준 구간의 점은 모두 안전 조건을 지킨다.
func test_free_intervals_margin_contract() -> void:
	var m := 1e-4
	check_eq(CameraGuard.free_intervals(PackedFloat64Array(), EPS, 0.25, m), PackedFloat64Array([-0.25, 0.25]), "정점 없음 = 한도 전체(대칭)")
	var one := CameraGuard.free_intervals(PackedFloat64Array([0.0]), EPS, 0.25, m)
	check_eq(one.size(), 4, "정점 하나 = 구간 둘")
	if one.size() == 4:
		check(is_equal_approx(one[0], -0.25) and is_equal_approx(one[3], 0.25), "한도 쪽 끝은 줄이지 않는다 %s" % one)
		check(is_equal_approx(one[1], -EPS - m) and is_equal_approx(one[2], EPS + m), "정점 쪽 끝만 margin 만큼 줄인다 %s" % one)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for trial in 500:
		var ws := PackedFloat64Array()
		for i in rng.randi_range(1, 6):
			ws.append(rng.randf_range(-0.3, 0.3))
		var iv := CameraGuard.free_intervals(ws, EPS, 0.25, 0.0)
		if iv.size() == 2 and iv[0] == iv[1]:
			continue  # best_effort 한 점
		for j in range(0, iv.size(), 2):
			for x in [iv[j], (iv[j] + iv[j + 1]) / 2.0, iv[j + 1]]:
				if not CameraGuard.is_free(ws, EPS, 0.25, x):
					failures.append("구간 점 %f 가 안전 조건을 어긴다: %s → %s" % [x, ws, iv])


## plan_path: 표본 없음 = 빈 경로, 표본 하나 = 끝 값 하나(처음과 끝이 같은 표본, 끝을 지킨다), 둘 이상 = 처음·끝 고정.
func test_plan_path_boundaries() -> void:
	var allowed: Array[PackedFloat64Array] = []
	check_eq(CameraGuard.plan_path(allowed, 0.1, -0.1).size(), 0, "표본 없음")
	allowed.append(PackedFloat64Array([-0.25, 0.25]))
	check_eq(CameraGuard.plan_path(allowed, 0.1, -0.1), PackedFloat64Array([-0.1]), "표본 하나, start ≠ end → 끝 값")
	allowed.append(PackedFloat64Array())
	var p := CameraGuard.plan_path(allowed, 0.1, -0.1)
	check(p.size() == 2 and p[0] == 0.1 and p[1] == -0.1, "표본 둘 = 처음·끝 %s" % p)
