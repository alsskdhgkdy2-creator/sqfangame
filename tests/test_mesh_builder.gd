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


# ---- M3 A3: 상자·잠긴 문(실제 미궁 arbor) ----

## 상자 c 의 정점(칸 가운데 ±0.5m·높이 0.5m 상자 안). 바닥·벽 정점은 칸 가운데에서 1m 이상 떨어져 들지 않는다.
static func _chest_verts(b: DungeonMeshBuilder.Built, c: Vector2i) -> Array[Vector3]:
	var o := DungeonMeshBuilder.cell_center(c)
	var out: Array[Vector3] = []
	for v in b.verts:
		if absf(v.x - o.x) <= 0.75 and absf(v.z - o.z) <= 0.75 and v.y <= DungeonMeshBuilder.WALL_H - 0.01:
			out.append(v)
	return out


## 표면의 정점 색 묶음. 메시는 색을 낮은 정밀도로 담으므로 has 로 가까운 색(채널마다 1/128 안)을 찾는다.
class _Colors:
	extends RefCounted
	var list: Array[Color] = []

	func has(c: Color) -> bool:
		for x in list:
			if absf(x.r - c.r) < 1.0 / 128.0 and absf(x.g - c.g) < 1.0 / 128.0 and absf(x.b - c.b) < 1.0 / 128.0 and absf(x.a - c.a) < 1.0 / 128.0:
				return true
		return false


static func _colors(b: DungeonMeshBuilder.Built, surface: String) -> _Colors:
	var out := _Colors.new()
	var i := b.surface_names.find(surface)
	if i < 0:
		return out
	var seen := {}
	for col in b.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
		if not seen.has(col):
			seen[col] = true
			out.list.append(col)
	return out


## (M-M1 상자 모서리 ±0.6m: 격자 밖) 상자 정점: 평면 0.25m 격자, 높이 0.5m 이하, 칸 가운데 ±0.5m. 닫힘 12개(모서리 8 + 뚜껑 띠 4), 열림 8개.
## 닫힘 = 호박색 몸통 + 발광 뚜껑 띠, 열림 = 어두운 몸통(발광 띠 없음). 세 층 모든 정점이 0.25m 격자.
func test_chest_geometry_and_colors() -> void:
	var defs := Fx.arbor()
	var f := defs.floor_by_id("b1f")
	var closed := DungeonMeshBuilder.build(f, WorldState.new())
	var w := WorldState.new()
	for c in f.chest_list():
		w.open_chest(c.id)
	var opened := DungeonMeshBuilder.build(f, w)
	for c in f.chest_list():
		var o := DungeonMeshBuilder.cell_center(c.at)
		for x in [[closed, 12, "닫힘"], [opened, 8, "열림"]]:
			var vs := _chest_verts(x[0], c.at)
			check_eq(vs.size(), x[1], "%s %s: 상자 정점 수" % [c.id, x[2]])
			for v in vs:
				var off := Vector2(v.x - o.x, v.z - o.z)
				check(absf(off.x) <= DungeonMeshBuilder.CHEST_HALF + 1e-4 and absf(off.y) <= DungeonMeshBuilder.CHEST_HALF + 1e-4
					and v.y <= DungeonMeshBuilder.CHEST_H + 1e-4, "%s %s: 정점 %s 이 상자 안" % [c.id, x[2], v])
	check(_colors(closed, "plate").has(DungeonMeshBuilder.CHEST_CLOSED) and not _colors(closed, "plate").has(DungeonMeshBuilder.CHEST_OPENED),
		"닫힘: 호박색 몸통")
	check(_colors(closed, "glow").has(DungeonMeshBuilder.CHEST_LID_GLOW), "닫힘: 발광 뚜껑 띠")
	check(_colors(opened, "plate").has(DungeonMeshBuilder.CHEST_OPENED) and not _colors(opened, "plate").has(DungeonMeshBuilder.CHEST_CLOSED),
		"열림: 어두운 몸통")
	check(not _colors(opened, "glow").has(DungeonMeshBuilder.CHEST_LID_GLOW), "열림: 발광 띠 없음")
	check_eq(closed.mesh.get_surface_count(), DungeonMeshBuilder.build(f, w).mesh.get_surface_count(), "열림·닫힘 표면 수 같음(재질 재사용)")
	for id in defs.floor_ids:
		var b := DungeonMeshBuilder.build(defs.floor_by_id(id), WorldState.new())
		var bad := 0
		for v in b.verts:
			if absf(v.x * 4.0 - roundf(v.x * 4.0)) > 1e-4 or absf(v.z * 4.0 - roundf(v.z * 4.0)) > 1e-4:
				bad += 1
		check_eq(bad, 0, "%s: 평면 위치가 0.25m 격자 밖인 정점 수" % id)


## 잠긴 문 겉모습: B2F 열쇠 문 locked(보라 문판·자홍 등) → 열면 door, B3F 봉인 문 sealed(검붉은 문판·붉은 등·빗장, 세계 상태와 상관없이).
func test_lock_styles() -> void:
	var defs := Fx.arbor()
	var b2 := defs.floor_by_id("b2f")
	var lock: Vector3i = b2.edges_of_kind(FloorModel.Edge.LOCK)[0]
	var w := WorldState.new()
	check_eq(DungeonMeshBuilder.edge_style(b2, w, lock), "locked", "닫힌 열쇠 문")
	var shut := DungeonMeshBuilder.build(b2, w)
	check(_colors(shut, "plate").has(DungeonMeshBuilder.LOCK_PLATE[0]) and _colors(shut, "glow").has(DungeonMeshBuilder.LAMP_LOCKED), "잠긴 문 문판·등 색")
	w.open_lock(lock)
	check_eq(DungeonMeshBuilder.edge_style(b2, w, lock), "door", "연 열쇠 문 = 문")
	var open := DungeonMeshBuilder.build(b2, w)
	check(not _colors(open, "plate").has(DungeonMeshBuilder.LOCK_PLATE[0]) and _colors(open, "plate").has(DungeonMeshBuilder.DOOR_PLATE[0]), "연 뒤 문 색")
	var b3 := defs.floor_by_id("b3f")
	var seal := Vector3i(-1, -1, -1)
	for e in b3.edges_of_kind(FloorModel.Edge.LOCK):
		if b3.is_sealed(e):
			seal = e
	var w3 := WorldState.new()
	w3.open_lock(seal)  # 규칙은 열지 않지만 겉모습은 세계 상태와 상관없다
	check_eq(DungeonMeshBuilder.edge_style(b3, w3, seal), "sealed", "봉인 문")
	var sealed := DungeonMeshBuilder.build(b3, WorldState.new())
	check(_colors(sealed, "plate").has(DungeonMeshBuilder.SEAL_PLATE[0]) and _colors(sealed, "plate").has(DungeonMeshBuilder.SEAL_BAR)
		and _colors(sealed, "glow").has(DungeonMeshBuilder.LAMP_SEALED), "봉인 문판·빗장·등 색")


## B1F 상자 칸과 그 네 이웃(닫힌 상자 = 정점이 가장 많다): 칸 가운데 회전(0.5° 간격, 보정 뒤 최소 |w| ≥ 0.025m)과
## 이동·막힘 궤적(2ε 안에 답). §9.2.1 ② 의 f1_test 훑기와 같은 기준.
func test_sweep_around_b1f_chests() -> void:
	_reset_stats()
	var f := Fx.arbor().floor_by_id("b1f")
	var world := WorldState.new()
	for e in f.edges_of_kind(FloorModel.Edge.SHORTCUT):
		world.open_shortcut(e)
	for e in f.edges_of_kind(FloorModel.Edge.PASSAGE):
		world.find_passage(e)
	var built := DungeonMeshBuilder.build(f, world)
	_radius = CameraGuard.reach(built.max_triangle)
	var cells := {}
	for ch in f.chest_list():
		cells[ch.at] = true
		for d in 4:
			var n := ch.at + Dir.vec(d)
			if f.is_cell(n):
				cells[n] = true
	for c in cells:
		var cam := DungeonMeshBuilder.cell_center(c) + Vector3.UP * DungeonView.EYE_HEIGHT
		_sweep_rotation(built.verts, cam, "B1F 칸 %s" % c)
		for d in 4:
			var v2 := Dir.vec(d)
			var reach := BUMP if ExplorationRules.block_reason(f, world, c, d) != "" else DungeonMeshBuilder.CELL
			_sweep_line(built.verts, cam, Vector3(v2.x, 0, v2.y), reach, "B1F 칸 %s 방향 %s" % [c, Dir.name_of(d)])
	check(cells.size() >= 2 * f.chest_list().size(), "훑은 칸 %d(상자마다 이웃 하나 이상)" % cells.size())
	print("  B1F 상자 둘레 보정 통계: ", _stats)


# ---- M3 A5: 채집 지점(실제 미궁 arbor) ----

## 지점 칸 c 의 정점(칸 가운데 ±0.5m 안, 벽 높이 아래). 바닥·벽 정점은 칸 가운데에서 1m 이상 떨어져 들지 않는다.
static func _point_verts(b: DungeonMeshBuilder.Built, c: Vector2i) -> Array[Vector3]:
	var o := DungeonMeshBuilder.cell_center(c)
	var out: Array[Vector3] = []
	for v in b.verts:
		if absf(v.x - o.x) <= 0.5 and absf(v.z - o.z) <= 0.5 and v.y <= DungeonMeshBuilder.WALL_H - 0.01:
			out.append(v)
	return out


## (M-M1 기둥 모서리 ±0.3m: 격자 밖) 지점 기둥: 평면 ±0.25m(0.25m 격자), 높이 0.75m 이하. 남음 = 몸통 + 띠 경계(12 정점), 다 씀 = 8 정점.
## 남음 = 종류 색 몸통(plate)·밝은 띠(glow), 다 씀 = 회색(frame) 하나(종류 색·띠 없음). 세 층의 모든 지점 정점이 0.25m 격자.
func test_point_geometry_and_colors() -> void:
	var defs := Fx.arbor()
	for id in defs.floor_ids:
		var f := defs.floor_by_id(id)
		if f.point_list().is_empty():
			continue
		var fresh := DungeonMeshBuilder.build(f, WorldState.new())
		var w := WorldState.new()
		for p in f.point_list():
			for i in p.uses:
				w.take_gather(p.id)
		var spent := DungeonMeshBuilder.build(f, w)
		for p in f.point_list():
			var o := DungeonMeshBuilder.cell_center(p.at)
			for x in [[fresh, 12, "남음"], [spent, 8, "다 씀"]]:
				var vs := _point_verts(x[0], p.at)
				check_eq(vs.size(), x[1], "%s %s %s: 기둥 정점 수" % [id, p.id, x[2]])
				for v in vs:
					var off := Vector2(v.x - o.x, v.z - o.z)
					check(absf(absf(off.x) - DungeonMeshBuilder.POINT_HALF) < 1e-4 and absf(absf(off.y) - DungeonMeshBuilder.POINT_HALF) < 1e-4
						and v.y <= DungeonMeshBuilder.POINT_H + 1e-4, "%s %s %s: 정점 %s 이 ±0.25m·0.75m 기둥 모서리" % [id, p.id, x[2], v])
					check(absf(v.x * 4.0 - roundf(v.x * 4.0)) < 1e-4 and absf(v.z * 4.0 - roundf(v.z * 4.0)) < 1e-4, "%s %s: 정점 %s 이 0.25m 격자" % [id, p.id, v])
		for k in DungeonMeshBuilder.POINT_COLORS:
			var has_kind := f.point_list().any(func(p: FloorModel.GatherPoint) -> bool: return p.kind == k)
			check_eq(_colors(fresh, "plate").has(DungeonMeshBuilder.POINT_COLORS[k]), has_kind, "%s 남음: %s 몸통 색" % [id, k])
			check_eq(_colors(fresh, "glow").has(DungeonMeshBuilder.POINT_GLOW[k]), has_kind, "%s 남음: %s 띠 색" % [id, k])
			check(not _colors(spent, "plate").has(DungeonMeshBuilder.POINT_COLORS[k]) and not _colors(spent, "glow").has(DungeonMeshBuilder.POINT_GLOW[k]),
				"%s 다 씀: %s 색·띠 없음" % [id, k])
		check(_colors(spent, "frame").has(DungeonMeshBuilder.POINT_SPENT) and not _colors(fresh, "frame").has(DungeonMeshBuilder.POINT_SPENT),
			"%s: 다 쓴 회색은 다 썼을 때만" % id)
		check_eq(fresh.mesh.get_surface_count(), spent.mesh.get_surface_count(), "%s: 남음·다 씀 표면 수 같음(재질 재사용)" % id)
	var cols := [DungeonMeshBuilder.CHEST_CLOSED, DungeonMeshBuilder.LOCK_PLATE[0], DungeonMeshBuilder.STAIRS_TINT["down"], DungeonMeshBuilder.STAIRS_TINT["up"],
		DungeonMeshBuilder.FLOOR_TINT[FloorModel.Cell.DAMAGE], DungeonMeshBuilder.FLOOR_TINT[FloorModel.Cell.ICE]]
	for k in DungeonMeshBuilder.POINT_COLORS:
		for c in cols:
			var d: Color = DungeonMeshBuilder.POINT_COLORS[k]
			check(absf(d.r - c.r) + absf(d.g - c.g) + absf(d.b - c.b) > 0.3, "%s 색은 상자·잠긴 문·계단·피해·얼음 바닥 색과 다르다" % k)


## B1F 지점 칸(g1·g2)과 그 네 이웃: 상자 둘레와 같은 기준으로 회전·이동·막힘 궤적을 훑는다(기둥은 칸 안, 눈높이 아래).
func test_sweep_around_b1f_points() -> void:
	_reset_stats()
	var f := Fx.arbor().floor_by_id("b1f")
	var world := WorldState.new()
	for e in f.edges_of_kind(FloorModel.Edge.SHORTCUT):
		world.open_shortcut(e)
	for e in f.edges_of_kind(FloorModel.Edge.PASSAGE):
		world.find_passage(e)
	var built := DungeonMeshBuilder.build(f, world)
	check(DungeonMeshBuilder.POINT_H < DungeonView.EYE_HEIGHT, "기둥 높이 %s < 눈높이 %s" % [DungeonMeshBuilder.POINT_H, DungeonView.EYE_HEIGHT])
	_radius = CameraGuard.reach(built.max_triangle)
	var cells := {}
	for p in f.point_list():
		cells[p.at] = true
		for d in 4:
			var n := p.at + Dir.vec(d)
			if f.is_cell(n):
				cells[n] = true
	for c in cells:
		var cam := DungeonMeshBuilder.cell_center(c) + Vector3.UP * DungeonView.EYE_HEIGHT
		_sweep_rotation(built.verts, cam, "B1F 칸 %s" % c)
		for d in 4:
			var v2 := Dir.vec(d)
			var reach := BUMP if ExplorationRules.block_reason(f, world, c, d) != "" else DungeonMeshBuilder.CELL
			_sweep_line(built.verts, cam, Vector3(v2.x, 0, v2.y), reach, "B1F 칸 %s 방향 %s" % [c, Dir.name_of(d)])
	check_eq(f.point_list().size(), 2, "B1F 지점 둘")
	check(cells.size() >= 2 * f.point_list().size(), "훑은 칸 %d(지점마다 이웃 하나 이상)" % cells.size())
	print("  B1F 지점 둘레 보정 통계: ", _stats)


## M3 A6c(설계 §5.1·§7.5): FOE 표지 메시(foe_mesh)는 칸 가운데 ±0.7m 안, 높이 0~1.62m. 공은 가시 60장(정이십면체 면 20 × 3)이고 정점 색이
## 준 위협 색, 차양은 흰 plate, 그림자는 바닥 색조의 어두운 frame 십이각형(seq=7: 바닥의 구멍처럼 읽히지 않게). 표면은 glow·plate·frame 셋(층 재질을 다시 쓴다, 새 셰이더 없음).
func test_foe_mesh_geometry() -> void:
	var red := Color(1.0, 0.16, 0.12)
	var b := DungeonMeshBuilder.foe_mesh(red)
	check_eq(b.surface_names, ["frame", "plate", "glow"] as Array[String], "표면: 그림자·차양·공")
	var top := 0.0
	var bottom := INF
	for v in b.verts:
		check(absf(v.x) <= 0.7 + 1e-4 and absf(v.z) <= 0.7 + 1e-4, "정점 %s 이 ±0.7m 안" % v)
		top = maxf(top, v.y)
		bottom = minf(bottom, v.y)
	# 가장 높은 가시는 곧게 위가 아니라 1.0 + 0.62·cos(37.4°) ≈ 1.579m(정이십면체 면 가운데 방향). 0.02 는 그림자.
	check(top <= 1.62 + 1e-4 and top > 1.55 and absf(bottom - 0.02) < 1e-4, "높이 %.3f ~ %.3f 는 0 ~ 1.62 안" % [bottom, top])
	check_eq(_tri_count(b, "glow"), 60, "가시 삼각형 60")
	# 정점 색은 8비트로 저장된다(1/255 안).
	check(_same8(_colors(b, "glow").list, [red]), "공 정점 색 = 준 위협 색(1.0, 0.16, 0.12) %s" % str(_colors(b, "glow").list))
	check(_same8(_colors(b, "plate").list, [Color(1, 1, 1)]), "차양 흰색")
	check(_same8(_colors(b, "frame").list, [Color(0.23, 0.25, 0.18)]), "그림자 어두운 바닥 색조 %s" % str(_colors(b, "frame").list))
	var visor := b.mesh.surface_get_arrays(b.surface_names.find("plate"))[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var front := 0.0
	for v in visor:
		front = minf(front, v.z)
	check(absf(front + 0.7) < 1e-4, "차양 앞 끝 z −0.7(앞 = −z) %.3f" % front)


## 색 목록이 8비트 저장 오차(1/255) 안에서 같다.
static func _same8(got: Array, want: Array) -> bool:
	if got.size() != want.size():
		return false
	for i in got.size():
		var a: Color = got[i]
		var b: Color = want[i]
		if absf(a.r - b.r) > 1.0 / 255.0 + 1e-6 or absf(a.g - b.g) > 1.0 / 255.0 + 1e-6 or absf(a.b - b.b) > 1.0 / 255.0 + 1e-6 or absf(a.a - b.a) > 1.0 / 255.0 + 1e-6:
			return false
	return true


## M3 A6c(교훈 6): 층 메시(build)의 정점 수는 FOE 표지 뒤에도 그대로다(표지는 따로 그린다). 수는 HEAD 067525d 사본과 이 트리에서 같게 쟀다.
func test_build_vertex_counts_unchanged() -> void:
	var want := {"b1f": [584, 2120], "b2f": [644, 2272], "b3f": [690, 2600]}
	var defs := Fx.arbor()
	for id in want:
		var b := DungeonMeshBuilder.build(defs.floor_by_id(id), WorldState.new())
		var n := 0
		for i in b.mesh.get_surface_count():
			n += b.mesh.surface_get_array_len(i)
		check_eq([b.verts.size(), n], want[id], "%s: 보정 정점·메시 정점 수" % id)
	check_eq([DungeonMeshBuilder.build(Fx.f1(), WorldState.new()).verts.size(), DungeonMeshBuilder.build(Fx.f2(), WorldState.new()).verts.size()], [676, 84],
		"시험 층 보정 정점 수")
