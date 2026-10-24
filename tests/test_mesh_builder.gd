## 미궁 메시(05 §9.2): 재질별 합친 메시, 면마다 UV 0~1, 경계 겉모습 구별, 장식 정점 0.25m 격자,
## 그리고 실제 f1_test 형상으로 회전·이동 궤적을 훑어 카메라 보정 답이 2ε 안에 있는지(§9.2.1 ②).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const EPS := CameraGuard.EPS
const STEP_DEG := 0.5
const STEP_T := 0.02
## dungeon_view 의 막힘 연출 최대 전진(m)과 같게 둔다.
const BUMP := DungeonView.BUMP_DISTANCE
## 회전 중에는 0.25m 안에서도 모든 정점을 ε 밖에 둘 수 없는 각도가 있다(f1_test 에서 보정이 필요한 회전 자세의 약 1%).
## 그때는 가장 먼 위치(CameraGuard.best_effort)를 쓰고, 그 여유가 이 값 이상인지 본다(2026-10-16 f1_test 실측 최소 0.0306m).
const ROTATION_MIN_GAP := 0.025
## 각도·거리 통에 넣는 깊이 폭: 넓혀 찾기(WIDE_LIMIT)까지 겹칠 수 있는 정점을 모두 담는다.
const REACH_W := CameraGuard.WIDE_LIMIT + EPS


func _all_open_world(f: FloorModel) -> WorldState:
	var w := WorldState.new()
	for e in f.edges_of_kind(FloorModel.Edge.SHORTCUT):
		w.open_shortcut(e)
	for e in f.edges_of_kind(FloorModel.Edge.PASSAGE):
		w.find_passage(e)
	return w


var _radius := 0.0
var _stats := {}


func _reset_stats() -> void:
	_stats = {"need": 0, "wide": 0, "best_effort": 0, "min_gap": INF, "max_delta": 0.0}


## 삼각형 최대 변 L 을 고정한다: 보정 반경 R = (L + ε)·(1 + tan(가로 반각)) 의 근거(CameraGuard.reach).
## 가장 큰 삼각형은 칸 한 면(2m × 2m)의 대각선이다.
func test_max_triangle_fixed() -> void:
	var b := DungeonMeshBuilder.build(Fx.f1(), _all_open_world(Fx.f1()))
	check(absf(b.max_triangle - 2.0 * sqrt(2.0)) < 1e-4, "삼각형 최대 변 %.4f (2√2 기대)" % b.max_triangle)
	var r := CameraGuard.reach(b.max_triangle)
	check(r > 9.5 and r < 10.5, "보정 반경(가장 넓은 유효 화면비 %.2f) %.2f m" % [CameraGuard.MAX_ASPECT, r])


func test_surfaces_per_material_under_ten() -> void:
	var b := DungeonMeshBuilder.build(Fx.f1(), WorldState.new())
	check(b.mesh.get_surface_count() <= 10, "그리기 호출(표면) %d개" % b.mesh.get_surface_count())
	check_eq(b.mesh.get_surface_count(), b.surface_names.size(), "표면 이름 수")
	for name in ["wall", "floor", "ceiling", "frame", "plate", "glow"]:
		check(b.surface_names.has(name), "표면 %s" % name)
	check(b.verts.size() > 500, "정점 목록 %d" % b.verts.size())


func test_uv_in_unit_range() -> void:
	var b := DungeonMeshBuilder.build(Fx.f1(), _all_open_world(Fx.f1()))
	for i in b.mesh.get_surface_count():
		var uvs: PackedVector2Array = b.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV]
		for uv in uvs:
			if uv.x < -1e-5 or uv.x > 1.0 + 1e-5 or uv.y < -1e-5 or uv.y > 1.0 + 1e-5:
				failures.append("표면 %s UV %s" % [b.surface_names[i], uv])
				break


func test_decoration_on_quarter_grid() -> void:
	var b := DungeonMeshBuilder.build(Fx.f1(), _all_open_world(Fx.f1()))
	var bad := 0
	for v in b.verts:
		if absf(v.x * 4.0 - roundf(v.x * 4.0)) > 1e-4 or absf(v.z * 4.0 - roundf(v.z * 4.0)) > 1e-4:
			bad += 1
	check_eq(bad, 0, "평면 위치가 0.25m 격자 밖인 정점 수")


func test_edge_styles_distinct() -> void:
	var f := Fx.f1()
	var w := WorldState.new()
	var sc: Vector3i = f.edges_of_kind(FloorModel.Edge.SHORTCUT)[0]
	var hp: Vector3i = f.edges_of_kind(FloorModel.Edge.PASSAGE)[0]
	check_eq(DungeonMeshBuilder.edge_style(f, w, hp), "wall", "못 찾은 숨은 통로는 벽과 같다")
	check_eq(DungeonMeshBuilder.edge_style(f, w, sc), "shortcut_closed", "닫힌 지름길")
	check_eq(DungeonMeshBuilder.edge_style(f, w, f.edges_of_kind(FloorModel.Edge.DOOR)[0]), "door", "문")
	check_eq(DungeonMeshBuilder.edge_style(f, w, f.edges_of_kind(FloorModel.Edge.ONEWAY)[0]), "oneway", "일방통행")
	var closed := DungeonMeshBuilder.build(f, w)
	w.open_shortcut(sc)
	w.find_passage(hp)
	check_eq(DungeonMeshBuilder.edge_style(f, w, hp), "passage", "찾은 숨은 통로")
	check_eq(DungeonMeshBuilder.edge_style(f, w, sc), "shortcut_open", "열린 지름길")
	var opened := DungeonMeshBuilder.build(f, w)
	check(_tri_count(opened, "plate") < _tri_count(closed, "plate"), "열린 지름길은 문판이 없다")
	check(_tri_count(opened, "frame") > _tri_count(closed, "frame"), "찾은 통로는 청록 테두리가 생긴다")


func _tri_count(b: DungeonMeshBuilder.Built, surface: String) -> int:
	var i := b.surface_names.find(surface)
	if i < 0:
		return 0
	return (b.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


## 칸 가운데에서 0~360°(0.5° 간격) 회전: 보정 반경 안의 정점 기준으로 실제 보정 뒤 최소 |w| ≥ ROTATION_MIN_GAP.
## 모서리가 많은 방에서는 2ε 를 넘게 옮기거나(약 14%) ε 를 다 확보하지 못하는 각도(약 1%)가 있다(통계를 찍는다).
## 빠르게: 정점마다 |w| < REACH_W 가 되는 각도 창을 미리 구해 그 각도 칸에만 넣는다.
func test_sweep_rotation_at_cell_centers() -> void:
	_reset_stats()
	var f := Fx.f1()
	for world in [WorldState.new(), _all_open_world(f)]:
		var built := DungeonMeshBuilder.build(f, world)
		var verts := built.verts
		_radius = CameraGuard.reach(built.max_triangle)
		for c in f.cells():
			var cam := DungeonMeshBuilder.cell_center(c) + Vector3.UP * DungeonView.EYE_HEIGHT
			_sweep_rotation(verts, cam, "칸 %s" % c)
	print("  회전 보정 통계 (보정 필요 / 2ε 넘음 / ε 확보 못함 / 최소 |w| / 최대 |δ|): ", _stats)


func _sweep_rotation(verts: PackedVector3Array, cam: Vector3, label: String) -> void:
	var bins := int(360.0 / STEP_DEG)
	var buckets := {}
	for v in verts:
		var d := Vector2(v.x - cam.x, v.z - cam.z)
		var r := d.length()
		if r < 1e-9 or r > _radius:
			continue
		# 앞 = (-sinθ, -cosθ) 일 때 w = -(d.x·sinθ + d.y·cosθ) = -r·sin(θ + φ), φ = atan2(d.y, d.x)
		var phi := atan2(d.y, d.x)
		var half := asin(minf(1.0, REACH_W / r)) + deg_to_rad(STEP_DEG)
		for zero in [-phi, PI - phi]:
			var k0 := int(floor(rad_to_deg(zero - half) / STEP_DEG))
			var k1 := int(ceil(rad_to_deg(zero + half) / STEP_DEG))
			for k in range(k0, k1 + 1):
				var kk := posmod(k, bins)
				if not buckets.has(kk):
					buckets[kk] = {}
				buckets[kk][v] = true
	for kk in buckets:
		var a := deg_to_rad(kk * STEP_DEG)
		var fwd := Vector3(-sin(a), 0.0, -cos(a))
		_check_pose(buckets[kk].keys(), cam, fwd, "%s %.1f°" % [label, kk * STEP_DEG], false)


## 가능한 이동(문·열린 지름길·찾은 통로·일방통행)마다 가운데→가운데 궤적(t 0.02 간격)을 앞 방향 그대로 훑는다.
## 후진은 같은 궤적을 반대 방향에서 보는 것이라 |w| 가 같고, 평행 이동은 앞 방향 깊이가 변하지 않는다(가운데 회전 시험이 덮음).
## 막힘 연출(앞으로 BUMP 만큼)도 칸마다 네 방향으로 훑는다.
func test_sweep_move_trajectories() -> void:
	_reset_stats()
	var f := Fx.f1()
	var world := _all_open_world(f)
	var built := DungeonMeshBuilder.build(f, world)
	var verts := built.verts
	_radius = CameraGuard.reach(built.max_triangle)
	for c in f.cells():
		var cam := DungeonMeshBuilder.cell_center(c) + Vector3.UP * DungeonView.EYE_HEIGHT
		for d in 4:
			var v2 := Dir.vec(d)
			var fwd := Vector3(v2.x, 0, v2.y)
			var reach := BUMP
			if ExplorationRules.block_reason(f, world, c, d) == "":
				reach = DungeonMeshBuilder.CELL
			_sweep_line(verts, cam, fwd, reach, "칸 %s 방향 %s" % [c, Dir.name_of(d)])
	print("  이동·막힘 궤적 보정 통계: ", _stats)


func _sweep_line(verts: PackedVector3Array, cam: Vector3, fwd: Vector3, reach: float, label: String) -> void:
	var step := STEP_T * DungeonMeshBuilder.CELL
	var n := int(ceil(reach / step))
	var buckets := {}
	for v in verts:
		var w0 := (v - cam).dot(fwd)
		# 카메라가 s 만큼 나아가면 w = w0 - s
		var k0 := maxi(0, int(floor((w0 - REACH_W) / step)))
		var k1 := mini(n, int(ceil((w0 + REACH_W) / step)))
		for k in range(k0, k1 + 1):
			if not buckets.has(k):
				buckets[k] = []
			buckets[k].append(v)
	for k in buckets:
		var s := minf(k * step, reach)
		_check_pose(buckets[k], cam + fwd * s, fwd, "%s s=%.2f" % [label, s], true)


## 한 자세 검사. strict 이면 2ε 안에 답이 있어야 하고, 아니면 실제 보정(solve) 뒤 최소 |w| ≥ ROTATION_MIN_GAP.
func _check_pose(near: Array, cam: Vector3, fwd: Vector3, label: String, strict: bool) -> void:
	var local := PackedVector3Array()
	var any := false
	for v in near:
		if Vector2(v.x - cam.x, v.z - cam.z).length() > _radius:
			continue
		local.append(v)
		if absf((v - cam).dot(fwd)) < EPS:
			any = true
	if not any:
		return
	_stats["need"] += 1
	var d := CameraGuard.solve(local, cam, fwd)
	if absf(d) > 2.0 * EPS + 1e-9:
		_stats["wide"] += 1
	var gap := CameraGuard.min_depth(local, cam + fwd * d, fwd)
	if gap < EPS - 1e-6:
		_stats["best_effort"] += 1
	_stats["min_gap"] = minf(_stats["min_gap"], gap)
	_stats["max_delta"] = maxf(_stats["max_delta"], absf(d))
	if strict and (absf(d) > 2.0 * EPS + 1e-9 or gap < EPS - 1e-6):
		failures.append("%s: 2ε 안에 답이 없음 (δ %.3f, 최소 |w| %.3f)" % [label, d, gap])
	elif not strict and gap < ROTATION_MIN_GAP:
		failures.append("%s: 보정 뒤 최소 |w| %.4f < %.2f" % [label, gap, ROTATION_MIN_GAP])
