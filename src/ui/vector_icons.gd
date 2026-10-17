## 단추·지도 기호를 선과 다각형으로 그린다. 글꼴 부분 집합에 ↶↷⇠⇢≡↺ 같은 기호가 없어 글자 대신 쓴다.
## 좌표는 rect 안의 0~1 단위. M1 지도 아이콘은 단순 벡터 기호다(05 §13).
class_name VectorIcons
extends RefCounted

const MAP_ICONS := ["door", "shortcut", "stairs_up", "stairs_down", "chest", "gather", "event", "danger", "foe", "arrow", "warp", "pin"]


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
		_:
			ci.draw_rect(Rect2(p.call(0.3, 0.3), rect.size * 0.4), color, false, w)


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
