## 캠프 뿌리·대원 고르기의 바탕(07 §9.8 ④, 원작 HD III research 07 §2.1 차례 1·2): 화면 전체를 덮는 불투명 청록 무늬 판과,
## 판을 그리지 않아 뒤 3D 시야가 보이는 그림 창. 판은 위 → 아래 그라데이션에 가는 격자(약 44px), 아래쪽에 어두운 덩굴·잎(벡터).
## 그림 창은 위 끝 y 118(x 0 → W − 35), 오른쪽 위 끝에서 오른쪽 아래로 크게 굽어 (W − 308, 508)에 닿고, 아래 끝 y 508.
## 창 안에는 옅은 청록 물빛·격자·가로줄 무늬만 겹치고, 위 끝과 굽은 끝에 흰·하늘색 두 줄 테두리를 그린다.
## 장식이라 누르기를 받지 않는다(빈 곳·창 안 누르기는 캠프 층이 받는다). 자리는 늘 화면 전체(넓은 화면에서는 창 오른쪽이 오른쪽 끝 기준).
## 창 모양·덮임·판 다각형·테두리는 순수 함수(window_outline·window_right·covered·board_polygons·edge_lines)이고 _draw 가 그대로 그려서
## 시험이 그린 것을 읽는다(drawn).
class_name CampBackdrop
extends Control

const WINDOW_TOP := 118.0
const WINDOW_BOTTOM := 508.0
## 창 오른쪽 위 끝(W − 35)과 굽은 끝이 아래 끝에 닿는 곳(W − 308), 오른쪽 끝 기준.
const WINDOW_RIGHT := 35.0
const WINDOW_CURVE_END := 308.0
## 굽은 끝 모양: (W − 308, 118)을 가운데로 하는 반지름 273 × 390 타원 4분의 1(지수 2). 원작 III HD 프레임
## (yt_eo3hd_02 캠프 뿌리)에서 줄마다 판이 시작하는 x 를 재어 맞췄다(조정자 측정, rms 2.2px, 가장 큰 차 7.2px 는 맨 위 y 122~140).
const CURVE_POWER := 2.0
const CURVE_STEPS := 48
const GRID := 44.0
const SCAN := 4.0

const BOARD_TOP := Color("0e6b6e")
const BOARD_BOTTOM := Color("148582")
## 맨 위 띠 아래(y 66~118) 조금 어두운 띠(원작 OPTION·SAVE 알약 줄 자리).
const STRIP := Color("0b5862")
const STRIP_TOP := 66.0
const GRID_COLOR := Color(0.45, 0.93, 0.9, 0.16)
const WINDOW_TINT := Color(0.3, 0.85, 0.85, 0.14)
const WINDOW_GRID := Color(0.6, 0.97, 0.95, 0.10)
const SCAN_COLOR := Color(0.75, 1.0, 1.0, 0.05)
const EDGE_OUTER := Color(1, 1, 1, 0.95)
const EDGE_INNER := Color("9ff4f6")
## 하늘색 선과 흰 선 사이(판 쪽).
const EDGE_GAP := 6.0
const VINE := Color("064f57")
const LEAF := Color("05454f")

## 마지막으로 그린 것(시험·디버그): {size, board(판 다각형), tint(창 물빛 색), edges(테두리 두 줄), leaves(잎 수)}.
var drawn := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


## 폭 w 에서 창 오른쪽 끝의 x(y 가 창 위아래 밖이면 -1).
static func window_right(y: float, w: float) -> float:
	if y < WINDOW_TOP or y > WINDOW_BOTTOM:
		return -1.0
	var cx := w - WINDOW_CURVE_END
	var rx := WINDOW_CURVE_END - WINDOW_RIGHT
	var t := clampf((y - WINDOW_TOP) / (WINDOW_BOTTOM - WINDOW_TOP), 0.0, 1.0)
	return cx + rx * pow(1.0 - pow(t, CURVE_POWER), 1.0 / CURVE_POWER)


## 폭 w 의 굽은 끝 점들: (W − 35, 118) → (W − 308, 508). y 를 고르게 나누면 거의 평평한 아래 끝이 긴 직선 토막이 되므로
## 각도 θ(0 → π/2)를 고르게 나눈다: u = cos(θ)^(2/지수), t = sin(θ)^(2/지수)(지수 2 면 cos·sin 그대로). 두 끝은 정확히 맞춘다.
static func curve_points(w: float) -> PackedVector2Array:
	var cx := w - WINDOW_CURVE_END
	var rx := WINDOW_CURVE_END - WINDOW_RIGHT
	var ry := WINDOW_BOTTOM - WINDOW_TOP
	var out := PackedVector2Array()
	for i in CURVE_STEPS + 1:
		var th := PI / 2.0 * float(i) / CURVE_STEPS
		out.append(Vector2(cx + rx * pow(cos(th), 2.0 / CURVE_POWER), WINDOW_TOP + ry * pow(sin(th), 2.0 / CURVE_POWER)))
	out[0] = Vector2(w - WINDOW_RIGHT, WINDOW_TOP)
	out[CURVE_STEPS] = Vector2(cx, WINDOW_BOTTOM)
	return out


## 폭 w 의 그림 창 외곽(시계 방향): 왼쪽 위 (0, 118) → 오른쪽 위 → 굽은 끝 → (W − 308, 508) → 왼쪽 아래 (0, 508).
static func window_outline(w: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(0, WINDOW_TOP)])
	out.append_array(curve_points(w))
	out.append(Vector2(0, WINDOW_BOTTOM))
	return out


## 점 p 를 판이 덮는지(화면 w×h 안이고 그림 창 밖).
static func covered(p: Vector2, w: float, h: float) -> bool:
	if p.x < 0.0 or p.y < 0.0 or p.x > w or p.y > h:
		return false
	return not in_window(p, w)


## 점 p 가 그림 창 안인지(경계 포함하지 않음).
static func in_window(p: Vector2, w: float) -> bool:
	if p.y <= WINDOW_TOP or p.y >= WINDOW_BOTTOM or p.x < 0.0:
		return false
	return p.x < window_right(p.y, w)


## 폭 w·높이 h 의 판 다각형(창 자리는 비움): 위 띠, 굽은 끝 오른쪽, 아래. _draw 는 이것을 그대로 그린다.
static func board_polygons(w: float, h: float) -> Array[PackedVector2Array]:
	var right := curve_points(w)
	right.append(Vector2(w, WINDOW_BOTTOM))
	right.append(Vector2(w, WINDOW_TOP))
	return [PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, WINDOW_TOP), Vector2(0, WINDOW_TOP)]), right,
		PackedVector2Array([Vector2(0, WINDOW_BOTTOM), Vector2(w, WINDOW_BOTTOM), Vector2(w, h), Vector2(0, h)])]


## 창 테두리 두 줄(폭 w): white = 위 끝 (0, 118) → (W − 35, 118) → 굽은 끝 → (W − 308, 508),
## cyan = 판 쪽(위·오른쪽·아래)으로 EDGE_GAP 떨어진 선. 위 끝과 굽은 끝이 만나는 곳은 곧은 모서리 (W − 35 + 6, 118 − 6)다
## (굽은 끝은 맨 위에서 수직, 위 끝은 수평). 아래 끝(y 508)에는 선이 없다. _draw 는 이것을 그대로 그린다.
static func edge_lines(w: float) -> Dictionary:
	var curve := curve_points(w)
	var white := PackedVector2Array([Vector2(0, WINDOW_TOP)])
	white.append_array(curve)
	var cyan := PackedVector2Array([Vector2(0, WINDOW_TOP - EDGE_GAP), Vector2(w - WINDOW_RIGHT + EDGE_GAP, WINDOW_TOP - EDGE_GAP)])
	for i in range(1, curve.size()):
		cyan.append(curve[i] + _outward(curve, i) * EDGE_GAP)
	return {"white": white, "cyan": cyan}


## 판 색(y 의 그라데이션).
func _board_at(y: float) -> Color:
	return BOARD_TOP.lerp(BOARD_BOTTOM, clampf(y / maxf(1.0, size.y), 0.0, 1.0))


func _poly(pts: PackedVector2Array) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(_board_at(p.y))
	draw_polygon(pts, cols)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 1. 판(창 자리는 비움): 위 띠, 굽은 끝 오른쪽, 아래.
	var board := board_polygons(w, h)
	for pts in board:
		_poly(pts)
	draw_rect(Rect2(0, STRIP_TOP, w, WINDOW_TOP - STRIP_TOP), STRIP)
	# 2. 창 안: 옅은 물빛·가로줄 무늬(시야는 그대로 비친다).
	var tint := WINDOW_TINT
	draw_colored_polygon(window_outline(w), tint)
	var y := WINDOW_TOP + SCAN
	while y < WINDOW_BOTTOM:
		draw_line(Vector2(0, y), Vector2(window_right(y, w), y), SCAN_COLOR, 1.0)
		y += SCAN * 2.0
	# 3. 덩굴·잎(아래쪽, 카드 뒤).
	var leaves := _draw_vine(w, h)
	# 4. 격자: 판 위는 밝은 청록, 창 안은 더 옅게.
	var x := GRID
	while x < w:
		var top := window_right(WINDOW_TOP, w)
		var in_win_bottom := WINDOW_BOTTOM if x < curve_end_x(w) else curve_y_at(x, w)
		if x < top:
			draw_line(Vector2(x, 0), Vector2(x, WINDOW_TOP), GRID_COLOR, 1.0)
			draw_line(Vector2(x, WINDOW_TOP), Vector2(x, in_win_bottom), WINDOW_GRID, 1.0)
			draw_line(Vector2(x, in_win_bottom), Vector2(x, h), GRID_COLOR, 1.0)
		else:
			draw_line(Vector2(x, 0), Vector2(x, h), GRID_COLOR, 1.0)
		x += GRID
	y = GRID
	while y < h:
		var r := window_right(y, w)
		if r > 0.0 and y > WINDOW_TOP and y < WINDOW_BOTTOM:
			draw_line(Vector2(0, y), Vector2(r, y), WINDOW_GRID, 1.0)
			draw_line(Vector2(r, y), Vector2(w, y), GRID_COLOR, 1.0)
		else:
			draw_line(Vector2(0, y), Vector2(w, y), GRID_COLOR, 1.0)
		y += GRID
	# 5. 테두리: 위 끝과 굽은 끝에 흰 선, 판 쪽으로 6 떨어져 하늘색 선.
	var edges := edge_lines(w)
	draw_polyline(edges["white"], EDGE_OUTER, 3.0, true)
	draw_polyline(edges["cyan"], EDGE_INNER, 2.0, true)
	drawn = {"size": size, "board": board, "tint": tint, "edges": edges, "leaves": leaves}


## 굽은 끝이 아래 끝에 닿는 x(오른쪽 끝 기준).
static func curve_end_x(w: float) -> float:
	return w - WINDOW_CURVE_END


## 세로선 x 가 굽은 끝과 만나는 y(굽은 끝 아래 끝 x 보다 오른쪽일 때).
static func curve_y_at(x: float, w: float) -> float:
	var cx := w - WINDOW_CURVE_END
	var rx := WINDOW_CURVE_END - WINDOW_RIGHT
	var u := clampf((x - cx) / rx, 0.0, 1.0)
	var t := pow(1.0 - pow(u, CURVE_POWER), 1.0 / CURVE_POWER)
	return lerpf(WINDOW_TOP, WINDOW_BOTTOM, t)


## 굽은 끝 점 i 에서 판 쪽(바깥) 방향. 끝은 아래·왼쪽으로 가므로(d) 바깥은 오른쪽·아래 (d.y, −d.x)다.
static func _outward(curve: PackedVector2Array, i: int) -> Vector2:
	var a := curve[maxi(0, i - 1)]
	var b := curve[mini(curve.size() - 1, i + 1)]
	var d := (b - a).normalized()
	return Vector2(d.y, -d.x)


## 덩굴: 아래쪽 큰 줄기 둘(왼쪽에서 오른쪽으로 휘는 곡선)과 잎. 폭에 맞춰 가로로 늘이고 잎 모양은 그대로. 그린 잎 수를 돌려준다.
func _draw_vine(w: float, h: float) -> int:
	var sx := w / 1280.0
	var stems := [
		[Vector2(-40, h - 40), Vector2(260, h - 170), Vector2(560, h - 10), Vector2(760, h - 120)],
		[Vector2(640, h - 30), Vector2(860, h - 250), Vector2(1100, h - 40), Vector2(1320, h - 150)],
	]
	for s in stems:
		var pts := PackedVector2Array()
		for i in 33:
			pts.append(_bezier(s, float(i) / 32.0) * Vector2(sx, 1.0))
		draw_polyline(pts, VINE, 9.0, true)
	var leaves := [[Vector2(440, h - 150), -0.9], [Vector2(480, h - 100), 0.5], [Vector2(910, h - 150), -0.6],
		[Vector2(960, h - 95), 0.7], [Vector2(150, h - 90), -1.2], [Vector2(1180, h - 120), -0.3]]
	for l in leaves:
		_leaf((l[0] as Vector2) * Vector2(sx, 1.0), float(l[1]))
	return leaves.size()


static func _bezier(c: Array, t: float) -> Vector2:
	var u := 1.0 - t
	return (c[0] as Vector2) * u * u * u + (c[1] as Vector2) * 3.0 * u * u * t + (c[2] as Vector2) * 3.0 * u * t * t + (c[3] as Vector2) * t * t * t


## 잎 하나: 끝이 뾰족한 렌즈 모양(길이 96, 폭 44), angle 만큼 기울임.
func _leaf(at: Vector2, angle: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		pts.append(Vector2(lerpf(-48, 48, t), -22.0 * sin(PI * t)))
	for i in range(15, 0, -1):
		var t := float(i) / 16.0
		pts.append(Vector2(lerpf(-48, 48, t), 22.0 * sin(PI * t)))
	var tr := Transform2D(angle, at)
	draw_colored_polygon(tr * pts, LEAF)
