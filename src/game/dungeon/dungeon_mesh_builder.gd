## 층 정의 + 세계 상태 → 재질별로 합친 미궁 메시와 카메라 보정용 정점 목록(05 §9.2).
## 노드에 의존하지 않는다. 면마다 UV 0~1(칸 한 면에 텍스처 한 장), 구멍 난 벽 조각은 그 면의 일부 UV.
## 장식(문틀·문판·화살표·구멍 테두리)의 평면 위치는 경계 기준 0.25m 격자에 둔다(05 §9.2.1 ①).
class_name DungeonMeshBuilder
extends RefCounted

const CELL := 2.0
const WALL_H := 2.0
## 재질(표면) 이름. 이 순서로 표면을 만든다(빈 표면은 건너뛴다).
const SURFACES := ["wall", "floor", "ceiling", "frame", "plate", "glow"]

# 경계 한 변(u: 0~2m) 위 출입구·문틀 위치. 모두 0.25m 격자.
const OPEN_U0 := 0.5
const OPEN_U1 := 1.5
const OPEN_H := 1.5
const JAMB_U0 := 0.25
const JAMB_U1 := 1.75
const LINTEL_H := 1.75
const FRAME_D := 0.25
const LAMP_U0 := 0.75
const LAMP_U1 := 1.25

const WHITE := Color(1, 1, 1)
const FLOOR_TINT := {
	FloorModel.Cell.FLOOR: Color(1, 1, 1),
	FloorModel.Cell.DAMAGE: Color(1.0, 0.42, 0.36),
	FloorModel.Cell.ICE: Color(0.62, 0.9, 1.0),
}
## 계단 칸 바닥 색(M3 A1 자리표시: 정점을 더하지 않고 바닥 색만 바꾼다. 계단 모형은 그림 단계에서).
const STAIRS_TINT := {"down": Color(0.72, 0.5, 1.0), "up": Color(1.0, 0.85, 0.35)}
const CEILING_COLOR := Color(0.14, 0.16, 0.2)
const FRAME_COLOR := Color(0.32, 0.36, 0.42)
const DOOR_PLATE := [Color(0.1, 0.36, 0.42), Color(0.08, 0.3, 0.36)]
const SHORTCUT_PLATE_OPENER := [Color(0.78, 0.52, 0.12), Color(0.68, 0.44, 0.1)]
const SHORTCUT_PLATE_LOCKED := [Color(0.36, 0.12, 0.1), Color(0.3, 0.1, 0.08)]
const LAMP_DOOR := Color(0.3, 0.95, 1.0)
const LAMP_CLOSED_OPENER := Color(1.0, 0.7, 0.15)
const LAMP_CLOSED_LOCKED := Color(1.0, 0.18, 0.12)
const LAMP_OPEN := Color(0.3, 1.0, 0.45)
const ONEWAY_COLOR := Color(1.0, 0.85, 0.2)
const PASSAGE_RIM := Color(0.12, 0.42, 0.44)


class Built:
	extends RefCounted
	var mesh := ArrayMesh.new()
	## 메시 표면 순서대로의 재질 이름.
	var surface_names: Array[String] = []
	## 그리는 모든 정점의 세계 좌표(중복 제거). 카메라 보정이 쓴다.
	var verts := PackedVector3Array()
	## 삼각형의 가장 긴 변(m). 카메라 보정 반경(CameraGuard.reach)의 근거.
	var max_triangle := 0.0


## 경계 한 변의 좌표계: P(u, h, d) = o + a·u + 위·h + n·d. n 은 A 칸(북·서) → B 칸(남·동).
class EdgeFrame:
	extends RefCounted
	var o := Vector3.ZERO
	var a := Vector3.ZERO
	var n := Vector3.ZERO

	func p(u: float, h: float, d: float) -> Vector3:
		return o + a * u + Vector3.UP * h + n * d


## 경계의 3D 겉모습: wall·open·door·shortcut_closed·shortcut_open·oneway·passage(찾은 숨은 통로).
## 못 찾은 숨은 통로는 wall 과 같다.
static func edge_style(f: FloorModel, world: WorldState, e: Vector3i) -> String:
	match f.edge_kind(e):
		FloorModel.Edge.OPEN:
			return "open"
		FloorModel.Edge.DOOR:
			return "door"
		FloorModel.Edge.SHORTCUT:
			return "shortcut_open" if world.is_shortcut_open(e) else "shortcut_closed"
		FloorModel.Edge.ONEWAY:
			return "oneway"
		FloorModel.Edge.PASSAGE:
			return "passage" if world.is_passage_found(e) else "wall"
		_:
			return "wall"


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0.0, c.y * CELL)


static func edge_frame(e: Vector3i) -> EdgeFrame:
	var fr := EdgeFrame.new()
	fr.o = Vector3((e.x - 0.5) * CELL, 0.0, (e.y - 0.5) * CELL)
	if e.z == 0:
		fr.a = Vector3.RIGHT
		fr.n = Vector3.BACK  # +z = 남쪽
	else:
		fr.a = Vector3.BACK
		fr.n = Vector3.RIGHT  # +x = 동쪽
	return fr


static func build(f: FloorModel, world: WorldState) -> Built:
	var b := _Builder.new()
	for c in f.cells():
		b.cell(f, c)
	for y in f.height + 1:
		for x in f.width:
			b.edge(f, world, Vector3i(x, y, 0))
	for y in f.height:
		for x in f.width + 1:
			b.edge(f, world, Vector3i(x, y, 1))
	return b.finish()


class _Builder:
	extends RefCounted
	var tools := {}
	var counts := {}
	var seen := {}
	var out := Built.new()

	func _init() -> void:
		for name in SURFACES:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[name] = st
			counts[name] = 0

	func finish() -> Built:
		for name in SURFACES:
			if counts[name] == 0:
				continue
			var st: SurfaceTool = tools[name]
			st.index()
			st.commit(out.mesh)
			out.mesh.surface_set_name(out.surface_names.size(), name)
			out.surface_names.append(name)
		return out

	## 사각형 p0~p3(둘레 순서) 한 장. normal 쪽에서 보이게 감는다(Godot 는 시계 방향이 앞면).
	func quad(surface: String, p: Array[Vector3], uv: Array[Vector2], normal: Vector3, color: Color) -> void:
		var st: SurfaceTool = tools[surface]
		var order := [0, 1, 2, 0, 2, 3]
		if (p[1] - p[0]).cross(p[2] - p[0]).dot(normal) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for i in order:
			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(uv[i])
			st.add_vertex(p[i])
		counts[surface] += 1
		_measure([p[0], p[1], p[2]])
		_measure([p[0], p[2], p[3]])
		for v in p:
			var key := v.snappedf(0.0001)
			if not seen.has(key):
				seen[key] = true
				out.verts.append(key)

	func triangle(surface: String, p: Array[Vector3], normal: Vector3, color: Color) -> void:
		var st: SurfaceTool = tools[surface]
		var order := [0, 1, 2]
		if (p[1] - p[0]).cross(p[2] - p[0]).dot(normal) > 0.0:
			order = [0, 2, 1]
		for i in order:
			st.set_normal(normal)
			st.set_color(color)
			st.set_uv(Vector2(0.5, 0.5))
			st.add_vertex(p[i])
		counts[surface] += 1
		_measure(p)
		for v in p:
			var key := v.snappedf(0.0001)
			if not seen.has(key):
				seen[key] = true
				out.verts.append(key)

	func _measure(t: Array[Vector3]) -> void:
		out.max_triangle = maxf(out.max_triangle, maxf(t[0].distance_to(t[1]), maxf(t[1].distance_to(t[2]), t[2].distance_to(t[0]))))

	func cell(f: FloorModel, c: Vector2i) -> void:
		var x0 := (c.x - 0.5) * CELL
		var z0 := (c.y - 0.5) * CELL
		var uv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var tint: Color = FLOOR_TINT.get(f.cell_kind(c), WHITE)
		var st := f.stair_at(c)
		if st != null:
			tint = STAIRS_TINT[st.way]
		quad("floor", [Vector3(x0, 0, z0), Vector3(x0 + CELL, 0, z0), Vector3(x0 + CELL, 0, z0 + CELL), Vector3(x0, 0, z0 + CELL)], uv, Vector3.UP, tint)
		quad("ceiling", [Vector3(x0, WALL_H, z0), Vector3(x0 + CELL, WALL_H, z0), Vector3(x0 + CELL, WALL_H, z0 + CELL), Vector3(x0, WALL_H, z0 + CELL)], uv, Vector3.DOWN, CEILING_COLOR)

	## 경계 면 위의 직사각형(u0~u1, h0~h1)을 side 쪽(+1 = B 칸, -1 = A 칸)에서 보이게. UV 는 그 면 전체 기준.
	func rect(surface: String, fr: EdgeFrame, u0: float, u1: float, h0: float, h1: float, d: float, side: int, color: Color) -> void:
		var p: Array[Vector3] = [fr.p(u0, h0, d), fr.p(u1, h0, d), fr.p(u1, h1, d), fr.p(u0, h1, d)]
		var uv: Array[Vector2] = [
			Vector2(u0 / CELL, 1.0 - h0 / WALL_H), Vector2(u1 / CELL, 1.0 - h0 / WALL_H),
			Vector2(u1 / CELL, 1.0 - h1 / WALL_H), Vector2(u0 / CELL, 1.0 - h1 / WALL_H),
		]
		quad(surface, p, uv, fr.n * side, color)

	## 문틀 상자 하나(바닥 면 없음). 앞뒤 면(d0·d1)은 lamp 가 있으면 가운데를 발광 재질로 나눈다.
	func box(fr: EdgeFrame, u0: float, u1: float, h0: float, h1: float, lamp: Array) -> void:
		var d0 := -FRAME_D
		var d1 := FRAME_D
		var full: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		# 위·아래(아래는 문 위 상인방만)
		quad("frame", [fr.p(u0, h1, d0), fr.p(u1, h1, d0), fr.p(u1, h1, d1), fr.p(u0, h1, d1)], full, Vector3.UP, FRAME_COLOR)
		if h0 > 0.0:
			quad("frame", [fr.p(u0, h0, d0), fr.p(u1, h0, d0), fr.p(u1, h0, d1), fr.p(u0, h0, d1)], full, Vector3.DOWN, FRAME_COLOR)
		# 양 끝(u0·u1)
		quad("frame", [fr.p(u0, h0, d0), fr.p(u0, h0, d1), fr.p(u0, h1, d1), fr.p(u0, h1, d0)], full, -fr.a, FRAME_COLOR)
		quad("frame", [fr.p(u1, h0, d0), fr.p(u1, h0, d1), fr.p(u1, h1, d1), fr.p(u1, h1, d0)], full, fr.a, FRAME_COLOR)
		# 앞뒤(B 쪽 d1, A 쪽 d0)
		for side in [1, -1]:
			var d := d1 if side == 1 else d0
			if lamp.is_empty():
				rect("frame", fr, u0, u1, h0, h1, d, side, FRAME_COLOR)
			else:
				var lamp_color: Color = lamp[0] if side == 1 else lamp[1]
				rect("frame", fr, u0, LAMP_U0, h0, h1, d, side, FRAME_COLOR)
				rect("glow", fr, LAMP_U0, LAMP_U1, h0, h1, d, side, lamp_color)
				rect("frame", fr, LAMP_U1, u1, h0, h1, d, side, FRAME_COLOR)

	## 출입구가 있는 벽(문·지름길 문): 양옆과 위 벽 조각 + 문틀. lamp = [B 쪽 색, A 쪽 색].
	func doorway(fr: EdgeFrame, sides: Array, lamp: Array) -> void:
		for side in sides:
			rect("wall", fr, 0.0, OPEN_U0, 0.0, WALL_H, 0.0, side, WHITE)
			rect("wall", fr, OPEN_U1, CELL, 0.0, WALL_H, 0.0, side, WHITE)
			rect("wall", fr, OPEN_U0, OPEN_U1, OPEN_H, WALL_H, 0.0, side, WHITE)
		box(fr, JAMB_U0, OPEN_U0, 0.0, OPEN_H, [])
		box(fr, OPEN_U1, JAMB_U1, 0.0, OPEN_H, [])
		box(fr, JAMB_U0, JAMB_U1, OPEN_H, LINTEL_H, lamp)

	## 문판(두 쪽). colors_b·colors_a = B 쪽·A 쪽에서 본 두 쪽 색.
	func plate(fr: EdgeFrame, colors_b: Array, colors_a: Array) -> void:
		var mid := CELL / 2.0
		for side in [1, -1]:
			var cs: Array = colors_b if side == 1 else colors_a
			rect("plate", fr, OPEN_U0, mid, 0.0, OPEN_H, 0.0, side, cs[0])
			rect("plate", fr, mid, OPEN_U1, 0.0, OPEN_H, 0.0, side, cs[1])

	## 바닥 화살표: 경계를 가로질러 dir_sign(+1 = A→B) 쪽을 가리키는 삼각형 두 개.
	func oneway_arrows(fr: EdgeFrame, dir_sign: int, a_ok: bool, b_ok: bool) -> void:
		var y := 0.02
		for tri in [[0.75, 0.25], [-0.25, -0.75]]:
			var tip: float = tri[0] * dir_sign
			var base: float = tri[1] * dir_sign
			# 화살표가 놓인 쪽 칸이 있어야 그린다(경계를 걸치는 것은 두 칸 다 있어야).
			var lo := minf(tip, base)
			var hi := maxf(tip, base)
			if (lo < 0.0 and not a_ok) or (hi > 0.0 and not b_ok):
				continue
			var p: Array[Vector3] = [fr.p(1.0, y, tip), fr.p(OPEN_U0, y, base), fr.p(OPEN_U1, y, base)]
			triangle("glow", p, Vector3.UP, ONEWAY_COLOR)

	## 찾은 숨은 통로: 벽에 난 구멍과 청록 금속 테두리(벽과 같은 면, 문처럼 튀어나온 틀·등은 없다).
	func passage(fr: EdgeFrame, sides: Array) -> void:
		for side in sides:
			rect("wall", fr, 0.0, JAMB_U0, 0.0, WALL_H, 0.0, side, WHITE)
			rect("wall", fr, JAMB_U1, CELL, 0.0, WALL_H, 0.0, side, WHITE)
			rect("wall", fr, JAMB_U0, JAMB_U1, LINTEL_H, WALL_H, 0.0, side, WHITE)
			rect("frame", fr, JAMB_U0, OPEN_U0, 0.0, LINTEL_H, 0.0, side, PASSAGE_RIM)
			rect("frame", fr, OPEN_U1, JAMB_U1, 0.0, LINTEL_H, 0.0, side, PASSAGE_RIM)
			rect("frame", fr, OPEN_U0, OPEN_U1, OPEN_H, LINTEL_H, 0.0, side, PASSAGE_RIM)

	func edge(f: FloorModel, world: WorldState, e: Vector3i) -> void:
		var pair := FloorModel.cells_of_edge(e)
		var a_ok := f.is_cell(pair[0])
		var b_ok := f.is_cell(pair[1])
		if not a_ok and not b_ok:
			return
		var sides := []
		if b_ok:
			sides.append(1)
		if a_ok:
			sides.append(-1)
		var fr := DungeonMeshBuilder.edge_frame(e)
		match DungeonMeshBuilder.edge_style(f, world, e):
			"open":
				pass
			"door":
				doorway(fr, sides, [LAMP_DOOR, LAMP_DOOR])
				plate(fr, DOOR_PLATE, DOOR_PLATE)
			"shortcut_closed", "shortcut_open":
				var opener_is_b := f.shortcut_opener(e) == pair[1]
				var open := world.is_shortcut_open(e)
				var lamp_b := LAMP_OPEN if open else (LAMP_CLOSED_OPENER if opener_is_b else LAMP_CLOSED_LOCKED)
				var lamp_a := LAMP_OPEN if open else (LAMP_CLOSED_LOCKED if opener_is_b else LAMP_CLOSED_OPENER)
				doorway(fr, sides, [lamp_b, lamp_a])
				if not open:
					var pb: Array = SHORTCUT_PLATE_OPENER if opener_is_b else SHORTCUT_PLATE_LOCKED
					var pa: Array = SHORTCUT_PLATE_LOCKED if opener_is_b else SHORTCUT_PLATE_OPENER
					plate(fr, pb, pa)
			"oneway":
				var d := f.oneway_dir(e)
				var dir_sign := 1 if (d == Dir.S or d == Dir.E) else -1
				oneway_arrows(fr, dir_sign, a_ok, b_ok)
			"passage":
				passage(fr, sides)
			_:
				for side in sides:
					rect("wall", fr, 0.0, CELL, 0.0, WALL_H, 0.0, side, WHITE)
