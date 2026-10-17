## 카메라 깊이 0 피하기(05 §9.2.1). 그리는 정점 가운데 카메라 깊이 w = dot(정점 − 카메라, 앞)이
## 0 근처인 것이 있으면, 카메라를 앞 방향 축으로 δ만큼 옮겨 모든 정점이 |w − δ| ≥ ε 가 되게 한다.
## 휴대폰 GPU 는 w = 0 인 정점을 가진 삼각형을 먼 꼭짓점에서 퍼지는 줄무늬로 그린다(03 M0 실기 확인).
class_name CameraGuard
extends RefCounted

const EPS := 0.05
## 2ε 안에 답이 없을 때 넓혀 찾는 한도(m).
const WIDE_LIMIT := 0.25
## 연출 계획(plan_path)이 찾는 최대 |Δδ| 의 정밀도(m).
const PLAN_M_TOL := 2e-4
## 반경 계산에 쓰는 시야: 세로 시야각(Camera3D.fov, 세로 고정)과 대상 화면비 가운데 가장 넓은 것(시야 영역 가로/세로).
const VFOV_DEG := 75.0
const MAX_ASPECT := 2.4
## 안전 조건의 허용치(m): 유효한 δ 는 |δ| ≤ 한도이고 모든 정점과 |w − δ| ≥ ε − FREE_TOL(is_free).
## nearest_free 는 이 허용 집합 하나로 「그대로」「가장 가까운 허용 점」「없음」을 정한다. search_within 은 돌려주기 전에 다시 확인한다.
const FREE_TOL := 1e-6

static var _warned := false


## 카메라를 cam + δ·fwd 로 옮길 δ. 옮길 필요가 없으면 0. fwd 는 단위 벡터.
## 후보는 정점마다 w ± ε, 가장 작은 |δ|, 같으면 뒤로 물러나는 쪽(δ < 0).
static func solve(verts: PackedVector3Array, cam: Vector3, fwd: Vector3, eps: float = EPS) -> float:
	var any_near := false
	var wide_reach := WIDE_LIMIT + eps
	var close := PackedFloat64Array()  # |w| < 3ε (|δ| ≤ 2ε 일 때 겹칠 수 있는 정점)
	var wide := PackedFloat64Array()  # |w| < WIDE_LIMIT + ε
	for v in verts:
		var w := (v - cam).dot(fwd)
		var a := absf(w)
		if a < eps:
			any_near = true
		if a < 3.0 * eps:
			close.append(w)
		if a < wide_reach:
			wide.append(w)
	if not any_near:
		return 0.0
	var d: Variant = search_within(close, eps, 2.0 * eps)
	if d == null:
		d = search_within(wide, eps, WIDE_LIMIT)
	if d == null:
		if not _warned:
			_warned = true
			push_warning("CameraGuard: |δ| ≤ %.2fm 안에 모든 정점을 ε 밖으로 둘 위치가 없어 가장 먼 위치를 쓴다 (카메라 %s)" % [WIDE_LIMIT, cam])
		d = best_effort(wide, WIDE_LIMIT)
	return d


## 연출 중 보정: solve 와 같은 안전 조건(모든 정점 |w − δ| ≥ ε, |δ| ≤ WIDE_LIMIT, 없으면 best_effort)으로,
## 유효한 δ 가운데 target 에 가장 가까운 것을 고른다(같으면 작은 |δ|, 그다음 뒤로 물러나는 쪽). target 이 유효하면 그대로.
## target 은 DungeonView 가 연출 계획(plan_path)이나 직전 프레임 δ 로 정한다.
static func solve_near(verts: PackedVector3Array, cam: Vector3, fwd: Vector3, target: float, eps: float = EPS) -> float:
	return solve_near_ws(depths(verts, cam, fwd, WIDE_LIMIT + eps), target, eps)


## solve_near 의 깊이 목록판(ws = depths(…, WIDE_LIMIT + ε)).
static func solve_near_ws(wide: PackedFloat64Array, target: float, eps: float = EPS) -> float:
	var d: Variant = nearest_free(wide, eps, WIDE_LIMIT, target)
	if d == null:
		d = best_effort(wide, WIDE_LIMIT)
	return d


## |w| < reach 인 정점의 깊이 w.
static func depths(verts: PackedVector3Array, cam: Vector3, fwd: Vector3, reach: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for v in verts:
		var w := (v - cam).dot(fwd)
		if absf(w) < reach:
			out.append(w)
	return out


## |δ| ≤ limit 안에서 모든 w 와 ε 이상 떨어진 δ 의 구간들 [a0, b0, a1, b1, …](오름차순, 끝점 포함).
## 정점 쪽 끝만 margin 만큼 안으로 줄인다(정점이 float32 라 실제 프레임의 w 는 1e-5 정도 다르다: 폭 0 인 틈을 계획하지 않게).
## 한도 쪽 끝(±limit)은 줄이지 않는다(정점이 없으면 [−limit, limit] 그대로, 양쪽이 대칭).
## 돌려주는 구간의 점은 모두 is_free 를 지킨다(margin ≥ 0). 정점 구간이 겹치면 합친다(맞닿기만 하면 끝점이 유효하다).
## 그런 δ 가 없으면 best_effort 한 점 [d, d]. ws 는 |w| < limit + ε 인 정점을 모두 담아야 한다.
static func free_intervals(ws: PackedFloat64Array, eps: float, limit: float, margin: float = 0.0) -> PackedFloat64Array:
	var sorted := ws.duplicate()
	sorted.sort()
	var out := PackedFloat64Array()
	var cur := -limit
	var i := 0
	while i < sorted.size():
		var a: float = sorted[i] - eps
		var b: float = sorted[i] + eps
		i += 1
		while i < sorted.size() and sorted[i] - eps < b:
			b = maxf(b, sorted[i] + eps)
			i += 1
		var x0 := cur + (margin if cur > -limit else 0.0)
		var x1 := minf(a - margin, limit)
		if x0 <= x1:
			out.append_array([x0, x1])
		cur = maxf(cur, b)
	var last0 := cur + (margin if cur > -limit else 0.0)
	if last0 <= limit:
		out.append_array([last0, limit])
	if out.is_empty():
		var d := best_effort(ws, limit)
		out.append_array([d, d])
	return out


## 연출 계획: 표본마다 허용 구간(free_intervals)이 주어질 때(표본 0 = 지금, 마지막 = 연출 끝), 처음 start·끝 end 를 지나며
## 이웃 표본 사이 |Δδ| 의 최댓값이 가장 작은 δ 경로. 최댓값 M 을 찾고(아래), 앞에서부터 도달 가능한 구간을 넓혀 가며
## (구간 ⊕ [−M, M]) ∩ 허용 구간 이 비지 않는지 본다(_feasible). 경로는 뒤에서부터 다음 값에 가장 가까운 점으로 고른다.
## M 찾기: 이웃 표본 허용 구간 사이의 가장 가까운 거리의 최댓값 L 은 하한이다(L 로 되면 그대로 답). 안 되면 L 위로
## 1mm·2mm·4mm… 넓혀 처음 되는 값을 찾고 그 사이를 PLAN_M_TOL 까지 반씩 줄인다(답은 참 최소 M 보다 PLAN_M_TOL 이하로 크다).
## end 가 NAN 이면 끝이 열린 계획(연출 앞 일부만 보는 계획): 마지막 표본은 그 허용 구간 안 어디든 되고,
## 경로의 마지막 값은 도달 가능한 점 가운데 pref 에 가장 가까운 것이다.
static func plan_path(allowed: Array[PackedFloat64Array], start: float, end: float, pref: float = 0.0) -> PackedFloat64Array:
	var n := allowed.size()
	var path := PackedFloat64Array()
	if n == 0:
		return path
	var open := is_nan(end)
	if n == 1:
		# 표본 하나는 처음이자 끝이다: 끝(정지 해)을 지킨다(start 는 이미 보인 값이라 경로에 둘 자리가 없다).
		path.append(start if open else end)
		return path
	var final: PackedFloat64Array = allowed[n - 1] if open else PackedFloat64Array([end, end])
	var cap := 2.0 * WIDE_LIMIT + 0.5
	var lo := _gap_bound(allowed, start, final)
	var hi := lo
	if not _feasible(allowed, start, final, hi):
		var grow := 1e-3
		hi = minf(lo + grow, cap)
		while not _feasible(allowed, start, final, hi):
			if hi >= cap:
				return path
			lo = hi
			grow *= 2.0
			hi = minf(lo + grow, cap)
		while hi - lo > PLAN_M_TOL:
			var mid := (lo + hi) / 2.0
			if _feasible(allowed, start, final, mid):
				hi = mid
			else:
				lo = mid
	var best: Array = _reach_sets(allowed, start, final, hi)
	for _i in 4:
		if not best.is_empty():
			break
		hi += 1e-9 + hi * 1e-9  # _feasible 과 같은 셈이지만 float 끝자리로 갈리면 조금 넓힌다
		best = _reach_sets(allowed, start, final, hi)
	if best.is_empty():
		return path
	path.resize(n)
	path[n - 1] = _closest_in(best[n - 1], pref, hi) if open else end
	for k in range(n - 2, -1, -1):
		path[k] = _closest_in(best[k], path[k + 1], hi)
	path[0] = start
	return path


## M 의 하한: 이웃 표본의 허용 구간 사이 가장 가까운 거리(처음 start 포함)의 최댓값. final = 마지막 표본 자리의 구간.
static func _gap_bound(allowed: Array[PackedFloat64Array], start: float, final: PackedFloat64Array) -> float:
	var n := allowed.size()
	var prev := PackedFloat64Array([start, start])
	var bound := 0.0
	for k in range(1, n):
		var cur: PackedFloat64Array = allowed[k] if k < n - 1 else final
		var d := INF
		var p := 0
		var q := 0
		while p < prev.size() and q < cur.size():
			if prev[p + 1] < cur[q]:
				d = minf(d, cur[q] - prev[p + 1])
				p += 2
			elif cur[q + 1] < prev[p]:
				d = minf(d, prev[p] - cur[q + 1])
				q += 2
			else:
				d = 0.0
				break
		bound = maxf(bound, d)
		prev = cur
	return bound


## _reach_sets 가 끝까지 가는지만 본다(구간을 남기지 않는 빠른 판정, 같은 셈·같은 허용치).
## 도달 구간이 하나이고 표본 허용 구간도 하나면 두 끝만 옮긴다. 아니면 넓힌 구간을 합치고 허용 구간과 겹친다.
static func _feasible(allowed: Array[PackedFloat64Array], start: float, final: PackedFloat64Array, m: float) -> bool:
	var n := allowed.size()
	var ca := start
	var cb := start
	var multi := PackedFloat64Array()  # 비어 있으면 도달 구간은 [ca, cb] 하나
	for k in range(1, n):
		var target: PackedFloat64Array = allowed[k] if k < n - 1 else final
		if multi.is_empty() and target.size() == 2:
			var a := maxf(ca - m, target[0])
			var b := minf(cb + m, target[1])
			if a > b + 1e-9:
				return false
			ca = a
			cb = maxf(a, b)
			continue
		var grown := PackedFloat64Array()
		if multi.is_empty():
			grown.append(ca - m)
			grown.append(cb + m)
		else:
			for j in range(0, multi.size(), 2):
				var ga := multi[j] - m
				var gb := multi[j + 1] + m
				if not grown.is_empty() and ga <= grown[grown.size() - 1]:
					grown[grown.size() - 1] = maxf(grown[grown.size() - 1], gb)
				else:
					grown.append(ga)
					grown.append(gb)
		var cut := PackedFloat64Array()
		var p := 0
		var q := 0
		while p < grown.size() and q < target.size():
			var a2 := maxf(grown[p], target[q])
			var b2 := minf(grown[p + 1], target[q + 1])
			if a2 <= b2 + 1e-9:
				cut.append(a2)
				cut.append(maxf(a2, b2))
			if grown[p + 1] < target[q + 1]:
				p += 2
			else:
				q += 2
		if cut.is_empty():
			return false
		if cut.size() == 2:
			ca = cut[0]
			cb = cut[1]
			multi = PackedFloat64Array()
		else:
			multi = cut
	return true


## 앞에서부터 도달 가능한 구간들. 끝까지 못 가면 빈 배열. final = 마지막 표본 자리의 구간.
static func _reach_sets(allowed: Array[PackedFloat64Array], start: float, final: PackedFloat64Array, m: float) -> Array:
	var sets := [PackedFloat64Array([start, start])]
	for k in range(1, allowed.size()):
		var grown := PackedFloat64Array()
		var prev: PackedFloat64Array = sets[k - 1]
		for j in range(0, prev.size(), 2):
			var a := prev[j] - m
			var b := prev[j + 1] + m
			if not grown.is_empty() and a <= grown[grown.size() - 1]:
				grown[grown.size() - 1] = maxf(grown[grown.size() - 1], b)
			else:
				grown.append_array([a, b])
		var target: PackedFloat64Array = allowed[k] if k < allowed.size() - 1 else final
		var cut := PackedFloat64Array()
		var p := 0
		var q := 0
		while p < grown.size() and q < target.size():
			var a2 := maxf(grown[p], target[q])
			var b2 := minf(grown[p + 1], target[q + 1])
			if a2 <= b2 + 1e-9:
				cut.append_array([a2, maxf(a2, b2)])
			if grown[p + 1] < target[q + 1]:
				p += 2
			else:
				q += 2
		if cut.is_empty():
			return []
		sets.append(cut)
	return sets


## 구간들 가운데 x 에 가장 가까운 점(계획이 맞으면 x 에서 m 안에 있다).
static func _closest_in(ranges: PackedFloat64Array, x: float, m: float) -> float:
	var best := x
	var best_d := INF
	for j in range(0, ranges.size(), 2):
		var c := clampf(x, ranges[j], ranges[j + 1])
		var dd := absf(c - x)
		if dd < best_d:
			best_d = dd
			best = c
	return best


## 안전 조건(is_free)을 지키는 δ 가운데 target 에 가장 가까운 것. 없으면 null. 세 판정 모두 is_free 의 허용 집합 하나로 한다:
## 허용 집합 = [−limit, limit] 에서 정점마다 막힌 열린 구간 (w − h, w + h), h = ε − FREE_TOL 을 뺀 것.
## - target(한도로 자른 값)이 허용되면 그대로 돌려준다.
## - 아니면 target 은 막힌 구간들이 겹쳐 이룬 한 덩어리(열린 구간) 안에 있고, 가장 가까운 허용 점은 그 덩어리의 양 끝 가운데 하나다
##   (끝점끼리 정확히 맞닿은 두 구간은 그 점이 허용되므로 합치지 않는다). 같으면 작은 |δ|, 그다음 뒤로 물러나는 쪽.
## - 두 끝이 모두 한도 밖이면(덩어리가 [−limit, limit] 을 덮으면) 허용 점이 없다: null.
## 끝점 w ± h 는 float 계산에서 is_free 를 몇 ulp 차이로 못 지킬 수 있어, 바깥쪽으로 몇 ulp 씩 옮겨 가며 다시 본다(_edge_free).
## ws 는 |w| < limit + ε 인 정점을 모두 담아야 한다.
static func nearest_free(ws: PackedFloat64Array, eps: float, limit: float, target: float) -> Variant:
	var t := clampf(target, -limit, limit)
	if is_free(ws, eps, limit, t):
		return t
	var h := eps - FREE_TOL
	var sorted := ws.duplicate()
	sorted.sort()
	var i := 0
	while i < sorted.size():
		var a: float = sorted[i] - h
		var b: float = sorted[i] + h
		i += 1
		while i < sorted.size() and sorted[i] - h < b:
			b = maxf(b, sorted[i] + h)
			i += 1
		if t < a or t > b:
			continue
		# t 가 이 덩어리 안(끝점 포함: float 로 끝점이 허용되지 않은 경우).
		var best: Variant = null
		for c in [_edge_free(ws, eps, limit, a, -1.0), _edge_free(ws, eps, limit, b, 1.0)]:
			if c == null:
				continue
			if best == null:
				best = c
				continue
			var dc := absf(float(c) - target)
			var db := absf(float(best) - target)
			if dc < db - 1e-12 or (absf(dc - db) <= 1e-12 and (absf(c) < absf(best) or (absf(c) == absf(best) and c < best))):
				best = c
		return best
	return null


## 끝점이 is_free 를 float 로 못 지키면 바깥쪽(dir)으로 조금씩 옮겨 다시 본다. 끝내 못 지키면 null.
static func _edge_free(ws: PackedFloat64Array, eps: float, limit: float, x: float, dir: float) -> Variant:
	var step := maxf(absf(x), eps) * 4e-16
	for k in 4:
		var c := x + dir * step * float(k * k)
		if is_free(ws, eps, limit, c):
			return c
	return null


## 깊이 목록 ws 에서 |δ| ≤ limit 인 가장 작은 답. 없으면 null. ws 는 |w| < limit + ε 인 정점을 모두 담아야 한다.
static func search_within(ws: PackedFloat64Array, eps: float, limit: float) -> Variant:
	var cands: Array[float] = []
	for w in ws:
		for c in [w - eps, w + eps]:
			# 한도를 FREE_TOL 안에서 넘는 후보(float 반올림)는 한도로 자른다. 자른 값도 아래에서 다시 확인한다.
			if absf(c) <= limit + FREE_TOL:
				cands.append(clampf(c, -limit, limit))
	cands.sort_custom(func(a: float, b: float) -> bool: return absf(a) < absf(b) or (absf(a) == absf(b) and a < b))
	for c in cands:
		if is_free(ws, eps, limit, c):
			return c
	return null


## δ 가 안전 조건을 지키는지: |δ| ≤ limit 이고 모든 w 와 |w − δ| ≥ ε − tol. ws 는 |w| < limit + ε 인 정점을 모두 담아야 한다.
static func is_free(ws: PackedFloat64Array, eps: float, limit: float, d: float, tol: float = FREE_TOL) -> bool:
	if absf(d) > limit:
		return false
	for w in ws:
		if absf(w - d) < eps - tol:
			return false
	return true


## 답이 없을 때: |δ| ≤ limit 안에서 가장 가까운 정점과의 거리(min |w − δ|)가 가장 큰 δ.
## 같으면 작은 |δ|, 그다음 뒤로 물러나는 쪽. ws 는 |w| < limit + ε 인 정점을 모두 담아야 한다(그 밖은 ε 이상 떨어져 있다).
static func best_effort(ws: PackedFloat64Array, limit: float) -> float:
	var sorted := Array(ws)
	sorted.sort()
	var cands: Array[float] = [0.0, -limit, limit]
	for i in sorted.size() - 1:
		var mid: float = (sorted[i] + sorted[i + 1]) / 2.0
		if absf(mid) <= limit:
			cands.append(mid)
	var best := 0.0
	var best_gap := -1.0
	for c in cands:
		var gap := INF
		for w in ws:
			gap = minf(gap, absf(w - c))
		if gap > best_gap + 1e-9 or (absf(gap - best_gap) <= 1e-9 and (absf(c) < absf(best) or (absf(c) == absf(best) and c < best))):
			best = c
			best_gap = gap
	return best


## 보정 뒤 가장 작은 |w|(시험·디버그용).
static func min_depth(verts: PackedVector3Array, cam: Vector3, fwd: Vector3) -> float:
	var m := INF
	for v in verts:
		m = minf(m, absf((v - cam).dot(fwd)))
	return m


## 볼 정점 반경(m). 깊이 0 근처 정점 P 의 삼각형이 화면에 들려면 다른 꼭짓점이 시야 안에 있어야 한다.
## 삼각형 최대 변 L, 가로 시야 반각 tan = k 이면 P 의 옆 거리가 L·(1 + k) 를 넘을 때 그 삼각형의 꼭짓점은 모두
## 같은 옆면 밖이라 통째로 버려진다. 그런 정점은 보정할 필요가 없다(겹침 검사에서도 뺀다). 여유로 ε·(1 + k) 를 더한다.
## 보정 뒤 카메라는 처음 위치에서 최대 WIDE_LIMIT 떨어지므로 그만큼 더 넓게 본다.
## 실제 화면은 DungeonView 가 지금 Camera3D.fov 와 시야 영역 화면비로 부른다(2.4 보다 넓은 창이면 반경이 커진다).
static func reach(max_triangle: float, vfov_deg: float = VFOV_DEG, max_aspect: float = MAX_ASPECT, eps: float = EPS) -> float:
	var k := tan(deg_to_rad(vfov_deg) / 2.0) * maxf(max_aspect, 1.0)
	return (max_triangle + eps) * (1.0 + k) + WIDE_LIMIT


## 정점을 바닥 평면 칸(한 변 cell m)으로 나눠 두고, 카메라 반경 안의 정점만 꺼낸다.
class Index:
	extends RefCounted
	var cell := 2.0
	var _buckets := {}  # Vector2i → PackedVector3Array

	func _init(verts: PackedVector3Array, cell_size: float = 2.0) -> void:
		cell = cell_size
		for v in verts:
			var k := Vector2i(floori(v.x / cell), floori(v.z / cell))
			if not _buckets.has(k):
				_buckets[k] = PackedVector3Array()
			_buckets[k].append(v)

	## 카메라에서 바닥 평면 거리 radius 안의 정점(칸 단위로 넉넉히, 거리로 다시 거른다).
	func near(cam: Vector3, radius: float) -> PackedVector3Array:
		var out := PackedVector3Array()
		var c := Vector2i(floori(cam.x / cell), floori(cam.z / cell))
		var span := int(ceil(radius / cell))
		var r2 := radius * radius
		for dy in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var b: Variant = _buckets.get(c + Vector2i(dx, dy))
				if b == null:
					continue
				for v in b:
					var dxz := Vector2(v.x - cam.x, v.z - cam.z)
					if dxz.length_squared() <= r2:
						out.append(v)
		return out
