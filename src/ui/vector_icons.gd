## 단추·지도 기호를 선과 다각형으로 그린다. 글꼴 부분 집합에 ↶↷⇠⇢≡↺ 같은 기호가 없어 글자 대신 쓴다.
## 좌표는 rect 안의 0~1 단위. M1 지도 아이콘은 단순 벡터 기호다(05 §13).
class_name VectorIcons
extends RefCounted

const MAP_ICONS := ["door", "shortcut", "stairs_up", "stairs_down", "chest", "gather", "event", "danger", "foe", "arrow", "warp", "pin"]
## 상점 종류 아이콘(08 §7.2).
const KIND_ICONS := ["kind_sword", "kind_staff", "kind_body", "kind_shield", "kind_head", "kind_hands", "kind_feet", "kind_accessory",
	"kind_material", "kind_consumable"]


static func draw(ci: CanvasItem, name: String, rect: Rect2, color: Color, dir: int = 0) -> void:
	var p := func(x: float, y: float) -> Vector2:
		return rect.position + Vector2(x, y) * rect.size
	var w := maxf(1.5, rect.size.x * 0.08)
	match name:
		"up", "down", "left", "right":
			var rot: int = {"up": 0, "right": 1, "down": 2, "left": 3}[name]
			_arrow(ci, rect, rot, color, w)
		"turn_left", "turn_right":
			# 위쪽 반원 호, 끝(오른쪽 회전이면 오른쪽 끝)에서 아래를 가리키는 화살촉.
			var s := -1.0 if name == "turn_left" else 1.0
			var center: Vector2 = p.call(0.5, 0.6)
			var r := rect.size.x * 0.27
			ci.draw_arc(center, r, PI, TAU, 16, color, w, true)
			var tip := center + Vector2(s * r, 0)
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-rect.size.x * 0.12, -rect.size.y * 0.02), tip + Vector2(rect.size.x * 0.12, -rect.size.y * 0.02), tip + Vector2(0, rect.size.y * 0.16)]), color)
		"strafe_left", "strafe_right":
			var s := -1.0 if name == "strafe_left" else 1.0
			for i in 3:
				var x0 := 0.5 - s * 0.32 + s * i * 0.16
				ci.draw_line(p.call(x0, 0.5), p.call(x0 + s * 0.08, 0.5), color, w)
			ci.draw_colored_polygon(PackedVector2Array([p.call(0.5 + s * 0.14, 0.32), p.call(0.5 + s * 0.14, 0.68), p.call(0.5 + s * 0.36, 0.5)]), color)
		"investigate":
			ci.draw_arc(p.call(0.43, 0.42), rect.size.x * 0.2, 0, TAU, 24, color, w, true)
			ci.draw_line(p.call(0.57, 0.57), p.call(0.8, 0.8), color, w * 1.4)
		"menu":
			for y in [0.3, 0.5, 0.7]:
				ci.draw_line(p.call(0.22, y), p.call(0.78, y), color, w)
		"map":
			ci.draw_polyline(PackedVector2Array([p.call(0.15, 0.25), p.call(0.38, 0.18), p.call(0.62, 0.28), p.call(0.85, 0.2), p.call(0.85, 0.75), p.call(0.62, 0.82), p.call(0.38, 0.72), p.call(0.15, 0.8), p.call(0.15, 0.25)]), color, w * 0.8, true)
			ci.draw_line(p.call(0.38, 0.18), p.call(0.38, 0.72), color, w * 0.6)
			ci.draw_line(p.call(0.62, 0.28), p.call(0.62, 0.82), color, w * 0.6)
		"undo":
			ci.draw_arc(p.call(0.52, 0.55), rect.size.x * 0.24, deg_to_rad(-200), deg_to_rad(40), 20, color, w, true)
			var a0: Vector2 = p.call(0.52, 0.55) + Vector2(cos(deg_to_rad(-200)), sin(deg_to_rad(-200))) * rect.size.x * 0.24
			ci.draw_colored_polygon(PackedVector2Array([a0 + Vector2(-rect.size.x * 0.12, -rect.size.y * 0.02), a0 + Vector2(rect.size.x * 0.1, -rect.size.y * 0.06), a0 + Vector2(0, rect.size.y * 0.14)]), color)
		"pan":
			for r in 4:
				_arrow(ci, Rect2(p.call(0.5, 0.5) + Vector2(rect.size.x * 0.22, 0).rotated(r * PI / 2.0 - PI / 2.0) - rect.size * 0.14, rect.size * 0.28), r, color, w * 0.8)
		"party":
			ci.draw_arc(p.call(0.5, 0.5), rect.size.x * 0.26, 0, TAU, 24, color, w, true)
			ci.draw_circle(p.call(0.5, 0.5), rect.size.x * 0.08, color)
		"zoom_in", "zoom_out":
			ci.draw_line(p.call(0.25, 0.5), p.call(0.75, 0.5), color, w * 1.2)
			if name == "zoom_in":
				ci.draw_line(p.call(0.5, 0.25), p.call(0.5, 0.75), color, w * 1.2)
		"wall":
			ci.draw_line(p.call(0.15, 0.5), p.call(0.85, 0.5), color, w * 1.6)
			ci.draw_line(p.call(0.15, 0.3), p.call(0.15, 0.7), color, w * 0.6)
			ci.draw_line(p.call(0.85, 0.3), p.call(0.85, 0.7), color, w * 0.6)
		"door_mark":
			ci.draw_line(p.call(0.1, 0.5), p.call(0.32, 0.5), color, w * 1.6)
			ci.draw_line(p.call(0.68, 0.5), p.call(0.9, 0.5), color, w * 1.6)
			ci.draw_rect(Rect2(p.call(0.34, 0.36), rect.size * Vector2(0.32, 0.28)), Color(1.0, 0.65, 0.2), false, w)
		"eraser":
			ci.draw_colored_polygon(PackedVector2Array([p.call(0.25, 0.65), p.call(0.55, 0.3), p.call(0.8, 0.5), p.call(0.5, 0.82)]), color)
			ci.draw_line(p.call(0.2, 0.85), p.call(0.8, 0.85), color, w * 0.6)
		"memo":
			ci.draw_rect(Rect2(p.call(0.22, 0.18), rect.size * Vector2(0.56, 0.64)), color, false, w)
			for y in [0.35, 0.5, 0.65]:
				ci.draw_line(p.call(0.32, y), p.call(0.68, y), color, w * 0.6)
		"door":
			ci.draw_rect(Rect2(p.call(0.28, 0.18), rect.size * Vector2(0.44, 0.64)), color, false, w)
			ci.draw_circle(p.call(0.62, 0.52), rect.size.x * 0.05, color)
		"shortcut":
			ci.draw_rect(Rect2(p.call(0.28, 0.18), rect.size * Vector2(0.44, 0.64)), color, false, w)
			ci.draw_line(p.call(0.36, 0.5), p.call(0.64, 0.5), color, w)
			ci.draw_colored_polygon(PackedVector2Array([p.call(0.58, 0.4), p.call(0.58, 0.6), p.call(0.7, 0.5)]), color)
		"stairs_up", "stairs_down":
			var pts := PackedVector2Array([p.call(0.15, 0.82), p.call(0.15, 0.66), p.call(0.38, 0.66), p.call(0.38, 0.48), p.call(0.6, 0.48), p.call(0.6, 0.3), p.call(0.85, 0.3)])
			ci.draw_polyline(pts, color, w, true)
			_arrow(ci, Rect2(p.call(0.55 if name == "stairs_up" else 0.15, 0.05 if name == "stairs_up" else 0.22), rect.size * 0.3), 0 if name == "stairs_up" else 2, color, w * 0.7)
		"chest":
			ci.draw_rect(Rect2(p.call(0.18, 0.38), rect.size * Vector2(0.64, 0.42)), color, false, w)
			ci.draw_line(p.call(0.18, 0.52), p.call(0.82, 0.52), color, w * 0.7)
			ci.draw_arc(p.call(0.5, 0.42), rect.size.x * 0.32, PI, TAU, 12, color, w * 0.8)
		"gather":
			ci.draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.15), p.call(0.78, 0.5), p.call(0.5, 0.85), p.call(0.22, 0.5)]), color)
		"event":
			ci.draw_line(p.call(0.5, 0.15), p.call(0.5, 0.62), color, w * 1.5)
			ci.draw_circle(p.call(0.5, 0.8), rect.size.x * 0.07, color)
		"danger":
			ci.draw_polyline(PackedVector2Array([p.call(0.5, 0.15), p.call(0.88, 0.82), p.call(0.12, 0.82), p.call(0.5, 0.15)]), color, w, true)
			ci.draw_line(p.call(0.5, 0.38), p.call(0.5, 0.62), color, w)
			ci.draw_circle(p.call(0.5, 0.72), rect.size.x * 0.04, color)
		"foe":
			ci.draw_circle(p.call(0.5, 0.5), rect.size.x * 0.32, color)
			ci.draw_circle(p.call(0.38, 0.45), rect.size.x * 0.06, Color.BLACK)
			ci.draw_circle(p.call(0.62, 0.45), rect.size.x * 0.06, Color.BLACK)
		"arrow":
			_arrow(ci, rect, dir, color, w)
		"warp":
			for r in [0.32, 0.2, 0.08]:
				ci.draw_arc(p.call(0.5, 0.5), rect.size.x * r, 0, TAU, 20, color, w * 0.7, true)
		"pin":
			ci.draw_circle(p.call(0.5, 0.38), rect.size.x * 0.18, color)
			ci.draw_colored_polygon(PackedVector2Array([p.call(0.36, 0.46), p.call(0.64, 0.46), p.call(0.5, 0.86)]), color)
		"kind_sword", "kind_staff", "kind_body", "kind_shield", "kind_head", "kind_hands", "kind_feet", "kind_accessory", \
				"kind_material", "kind_consumable":
			_kind(ci, name, rect, color)
		_:
			ci.draw_rect(Rect2(p.call(0.3, 0.3), rect.size * 0.4), color, false, w)


## 상점 종류 아이콘(08 §7.2): 원작 종류 아이콘 모양을 한 가지 색 그림으로. 28~40px 에서도 서로 구별되게 굵은 면 위주(겉모양으로 가린다).
static func _kind(ci: CanvasItem, name: String, rect: Rect2, color: Color) -> void:
	for sh in kind_shapes(name, rect):
		match str(sh["type"]):
			"poly":
				ci.draw_colored_polygon(sh["points"], color)
			"line":
				ci.draw_line(sh["from"], sh["to"], color, sh["width"])
			"circle":
				ci.draw_circle(sh["center"], sh["radius"], color)
			"arc":
				ci.draw_arc(sh["center"], sh["radius"], sh["from"], sh["to"], 24, color, sh["width"], true)
			"rect":
				ci.draw_rect(sh["rect"], color)


## 종류 아이콘의 도형 목록(그리기와 시험이 같이 쓴다): {type: poly|line|circle|arc|rect, …}. 모르는 이름이면 빈 배열.
static func kind_shapes(name: String, rect: Rect2) -> Array[Dictionary]:
	var p := func(x: float, y: float) -> Vector2:
		return rect.position + Vector2(x, y) * rect.size
	var poly := func(pts: Array) -> Dictionary:
		var out := PackedVector2Array()
		for q in pts:
			out.append(p.call(q[0], q[1]))
		return {"type": "poly", "points": out}
	var s := rect.size.x
	var w := maxf(1.5, s * 0.08)
	var line := func(x0: float, y0: float, x1: float, y1: float, k: float) -> Dictionary:
		return {"type": "line", "from": p.call(x0, y0), "to": p.call(x1, y1), "width": w * k}
	var box := func(x: float, y: float, bw: float, bh: float) -> Dictionary:
		return {"type": "rect", "rect": Rect2(p.call(x, y), rect.size * Vector2(bw, bh))}
	var out: Array[Dictionary] = []
	match name:
		"kind_sword":
			# 왼쪽 아래 → 오른쪽 위 비스듬한 날, 가로 날밑, 손잡이.
			out.append(poly.call([[0.3, 0.58], [0.76, 0.12], [0.9, 0.1], [0.88, 0.24], [0.42, 0.7]]))
			out.append(line.call(0.22, 0.5, 0.5, 0.78, 1.3))
			out.append(line.call(0.36, 0.64, 0.16, 0.84, 1.4))
		"kind_staff":
			# 끝이 말린 막대.
			out.append(line.call(0.3, 0.88, 0.56, 0.36, 1.3))
			out.append({"type": "arc", "center": p.call(0.62, 0.26), "radius": s * 0.14, "from": deg_to_rad(120), "to": deg_to_rad(470), "width": w * 1.2})
			out.append({"type": "circle", "center": p.call(0.64, 0.27), "radius": s * 0.05})
		"kind_body":
			# 가슴 갑옷: 어깨가 넓고 허리가 좁은 판, 목 파임.
			out.append(poly.call([[0.2, 0.2], [0.38, 0.14], [0.5, 0.24], [0.62, 0.14], [0.8, 0.2], [0.72, 0.5], [0.68, 0.86], [0.32, 0.86], [0.28, 0.5]]))
		"kind_shield":
			# 위가 평평하고 아래가 뾰족한 방패.
			out.append(poly.call([[0.2, 0.16], [0.8, 0.16], [0.78, 0.5], [0.5, 0.88], [0.22, 0.5]]))
		"kind_head":
			# 투구: 둥근 머리 + 양옆으로 뻗은 챙 + 볏.
			out.append({"type": "circle", "center": p.call(0.5, 0.5), "radius": s * 0.3})
			out.append(box.call(0.14, 0.58, 0.72, 0.12))
			out.append(poly.call([[0.44, 0.22], [0.5, 0.06], [0.56, 0.22]]))
		"kind_hands":
			# 장갑: 손바닥 + 손가락 넷 + 엄지 + 손목.
			out.append(box.call(0.3, 0.42, 0.4, 0.3))
			for i in 4:
				out.append(box.call(0.3 + i * 0.1, 0.16 + absf(i - 1.5) * 0.04, 0.08, 0.3))
			out.append(poly.call([[0.3, 0.5], [0.14, 0.36], [0.1, 0.44], [0.28, 0.66]]))
			out.append(box.call(0.32, 0.74, 0.36, 0.12))
		"kind_feet":
			# 장화: 세로 몸통 + 앞으로 뻗은 발.
			out.append(poly.call([[0.28, 0.12], [0.54, 0.12], [0.56, 0.6], [0.84, 0.68], [0.86, 0.86], [0.26, 0.86]]))
		"kind_accessory":
			# 반지: 고리 + 위 보석.
			out.append({"type": "arc", "center": p.call(0.5, 0.6), "radius": s * 0.24, "from": 0.0, "to": TAU, "width": w * 1.3})
			out.append(poly.call([[0.5, 0.12], [0.64, 0.26], [0.5, 0.4], [0.36, 0.26]]))
		"kind_material":
			# 묶은 자루: 둥근 몸 + 묶은 목 + 벌어진 주둥이.
			out.append({"type": "circle", "center": p.call(0.5, 0.62), "radius": s * 0.27})
			out.append(poly.call([[0.36, 0.38], [0.64, 0.38], [0.56, 0.3], [0.44, 0.3]]))
			out.append(poly.call([[0.44, 0.3], [0.3, 0.12], [0.5, 0.2], [0.7, 0.12], [0.56, 0.3]]))
		"kind_consumable":
			# 물약 병: 둥근 몸 + 목 + 마개.
			out.append({"type": "circle", "center": p.call(0.5, 0.64), "radius": s * 0.24})
			out.append(box.call(0.42, 0.26, 0.16, 0.2))
			out.append(box.call(0.36, 0.14, 0.28, 0.1))
	return out


## 방향 dir(0 = 위·북, 1 = 오른쪽·동 …)을 가리키는 화살표.
static func _arrow(ci: CanvasItem, rect: Rect2, dir: int, color: Color, w: float) -> void:
	var c := rect.get_center()
	var s := rect.size.x
	var rot := dir * PI / 2.0
	var shaft := [Vector2(0, 0.3), Vector2(0, -0.05)]
	var head := [Vector2(0, -0.35), Vector2(-0.22, -0.02), Vector2(0.22, -0.02)]
	ci.draw_line(c + (shaft[0] * s).rotated(rot), c + (shaft[1] * s).rotated(rot), color, w * 1.2)
	var poly := PackedVector2Array()
	for h in head:
		poly.append(c + (h * s).rotated(rot))
	ci.draw_colored_polygon(poly, color)
