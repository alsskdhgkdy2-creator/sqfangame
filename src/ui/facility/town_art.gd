## 마을 그림 자리표시(M3 A2, 그림은 B5): 장소·시설마다 세로 그라데이션 하나와 벡터 실루엣 하나를 그린다. 글자·그림 파일은 없다.
## 그리는 함수 하나(paint)를 바탕(TownBackdrop, 화면 전체)·광장 목록의 그림 띠·여관·길드(M3 A7c) NPC 자리가 같이 쓴다(D28).
## 그린 것은 캔버스마다 drawn 기록에 남는다(시험이 읽는다, CampBackdrop 와 같은 방식).
class_name TownArt
extends RefCounted

## 열쇠 → [위 색, 아래 색, 실루엣 색, 실루엣 모양].
const LOOKS := {
	"title": [Color("071e26"), Color("0e6b6e"), Color(0.45, 0.93, 0.9, 0.22), "tree"],
	"plaza": [Color("1d3d5c"), Color("c98a4b"), Color(0.05, 0.08, 0.12, 0.55), "roofs"],
	"inn": [Color("4a2a12"), Color("d9a45a"), Color(0.12, 0.06, 0.02, 0.5), "capsules"],
	"shop": [Color("10261c"), Color("4d7a3c"), Color(0.02, 0.06, 0.03, 0.55), "gear"],
	"entrance": [Color("1a0f33"), Color("6b3fa0"), Color(0.03, 0.02, 0.08, 0.6), "arch"],
	"pub": [Color("2b1030"), Color("a04a6b"), Color(0.06, 0.02, 0.06, 0.5), "roofs"],
	"guild": [Color("13233d"), Color("4a6fa5"), Color(0.03, 0.05, 0.1, 0.5), "roofs"],
	"council": [Color("1f2a2e"), Color("7d8f94"), Color(0.04, 0.06, 0.07, 0.5), "roofs"],
	"npc_inn": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.08, 0.04, 0.02, 0.62), "figure"],
	"npc_guild": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.04, 0.1, 0.62), "figure"],
}

## 캔버스 → 마지막으로 그린 것 [{key, rect, top, bottom, shape}](시험용).
static var drawn := {}


## 캔버스 ci 의 사각형 r 에 열쇠 key 의 그림을 그린다. 모르는 열쇠면 아무것도 그리지 않고 false.
static func paint(ci: CanvasItem, r: Rect2, key: String) -> bool:
	if not LOOKS.has(key) or r.size.x <= 0.0 or r.size.y <= 0.0:
		return false
	var look: Array = LOOKS[key]
	var top: Color = look[0]
	var bottom: Color = look[1]
	if top.a > 0.0 or bottom.a > 0.0:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
	_shape(ci, r, str(look[3]), look[2])
	drawn[ci.get_instance_id()] = {"key": key, "rect": r, "top": top, "bottom": bottom, "shape": look[3]}
	return true


## 마지막으로 ci 에 그린 열쇠(없으면 "").
static func drawn_key(ci: CanvasItem) -> String:
	var d: Dictionary = drawn.get(ci.get_instance_id(), {})
	return str(d.get("key", ""))


static func _shape(ci: CanvasItem, r: Rect2, shape: String, col: Color) -> void:
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	match shape:
		"roofs":
			var pts := PackedVector2Array([o + Vector2(0, h)])
			var xs := [0.0, 0.08, 0.14, 0.22, 0.3, 0.38, 0.46, 0.55, 0.62, 0.7, 0.8, 0.88, 0.95, 1.0]
			var ys := [0.7, 0.55, 0.62, 0.42, 0.58, 0.5, 0.3, 0.52, 0.45, 0.6, 0.4, 0.55, 0.5, 0.65]
			for i in xs.size():
				pts.append(o + Vector2(w * xs[i], h * ys[i]))
			pts.append(o + Vector2(w, h))
			ci.draw_colored_polygon(pts, col)
		"capsules":
			for row in 2:
				for k in 4:
					var cr := Rect2(o + Vector2(w * (0.1 + k * 0.2), h * (0.45 + row * 0.22)), Vector2(w * 0.16, h * 0.16))
					UiTheme.fill_round(ci, cr, col, int(minf(cr.size.y, 40.0) / 2.0))
		"gear":
			var c := o + Vector2(w * 0.7, h * 0.6)
			var rad := minf(w, h) * 0.28
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				var rr := rad * (1.0 if i % 4 < 2 else 0.8)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"arch":
			var base := o + Vector2(w * 0.5, h)
			var pts := PackedVector2Array([base + Vector2(-w * 0.32, 0)])
			for i in 17:
				var a := PI + PI * i / 16.0
				pts.append(o + Vector2(w * 0.5, h * 0.45) + Vector2(cos(a) * w * 0.32, sin(a) * h * 0.3))
			pts.append(base + Vector2(w * 0.32, 0))
			pts.append(base + Vector2(w * 0.2, 0))
			for i in 17:
				var a := 2.0 * PI - PI * i / 16.0
				pts.append(o + Vector2(w * 0.5, h * 0.5) + Vector2(cos(a) * w * 0.2, sin(a) * h * 0.2))
			pts.append(base + Vector2(-w * 0.2, 0))
			ci.draw_colored_polygon(pts, col)
		"tree":
			var trunk := PackedVector2Array([o + Vector2(w * 0.46, h), o + Vector2(w * 0.48, h * 0.4), o + Vector2(w * 0.52, h * 0.4),
				o + Vector2(w * 0.54, h)])
			ci.draw_colored_polygon(trunk, col)
			for i in 7:
				var a := PI + PI * (i + 0.5) / 7.0
				ci.draw_line(o + Vector2(w * 0.5, h * 0.42), o + Vector2(w * 0.5, h * 0.42) + Vector2(cos(a), sin(a)) * minf(w, h) * 0.4, col, 6.0)
		"figure":
			var c := o + Vector2(w * 0.5, h * 0.28)
			var rad := minf(w * 0.18, h * 0.12)
			var head := PackedVector2Array()
			for i in 24:
				head.append(c + Vector2(cos(TAU * i / 24.0), sin(TAU * i / 24.0)) * rad)
			ci.draw_colored_polygon(head, col)
			ci.draw_colored_polygon(PackedVector2Array([o + Vector2(w * 0.12, h), o + Vector2(w * 0.3, h * 0.45),
				o + Vector2(w * 0.7, h * 0.45), o + Vector2(w * 0.88, h)]), col)


## 마을에 있는 동안 3D 시야 위에 까는 화면 전체 바탕(층 0, 누르기 없음). place 가 지금 그림 열쇠다.
class TownBackdrop:
	extends Control

	var place := "plaza"

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		focus_mode = FOCUS_NONE
		set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		visible = false

	func show_place(key: String) -> void:
		if key != place:
			place = key
			queue_redraw()

	func _draw() -> void:
		TownArt.paint(self, Rect2(Vector2.ZERO, size), place)
