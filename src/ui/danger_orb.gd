## 위험 보석(원작 HD 탐색 화면 오른쪽 아래 모서리, gw_28·nin_02): 조우 위험도를 색으로 보인다(안전 파랑 → 노랑 → 주황 → 빨강).
## 그림 에셋 전의 자리표시: 코드로 그린 둥근 보석. 화면(시야 영역) 모서리에 걸쳐 일부가 잘린다. 누르기를 받지 않는다.
class_name DangerOrb
extends Control

const RADIUS := 52.0
## 보석 가운데가 시야 영역 오른쪽 아래 모서리에서 떨어진 거리(오른쪽, 아래). 지도 판이 열리면 판 왼쪽 끝에 반쯤 가려진다.
const CENTER_FROM_CORNER := Vector2(14.0, 78.0)
## 게이지(0~1) 기준점과 색: 안전 파랑 → 노랑 → 주황 → 빨강.
const STOPS := [[0.0, Color(0.2, 0.5, 1.0)], [0.5, Color(1.0, 0.86, 0.2)], [0.75, Color(1.0, 0.55, 0.12)], [1.0, Color(0.95, 0.15, 0.12)]]
const RIM := Color(0.02, 0.06, 0.1)

var gauge := 0.0:
	set(v):
		gauge = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	set_anchors_preset(PRESET_BOTTOM_RIGHT)
	offset_left = CENTER_FROM_CORNER.x * -1.0 - RADIUS
	offset_right = -CENTER_FROM_CORNER.x + RADIUS
	offset_top = -CENTER_FROM_CORNER.y - RADIUS
	offset_bottom = -CENTER_FROM_CORNER.y + RADIUS


static func color_of(g: float) -> Color:
	for i in range(1, STOPS.size()):
		var a: Array = STOPS[i - 1]
		var b: Array = STOPS[i]
		if g <= b[0]:
			return (a[1] as Color).lerp(b[1], (g - a[0]) / (b[0] - a[0]))
	return STOPS[-1][1]


func _draw() -> void:
	var c := size / 2.0
	var col := color_of(gauge)
	draw_circle(c, RADIUS, RIM)
	draw_circle(c, RADIUS - 5.0, col.darkened(0.35))
	draw_circle(c, RADIUS - 12.0, col)
	draw_circle(c + Vector2(-RADIUS * 0.3, -RADIUS * 0.3), RADIUS * 0.22, Color(1, 1, 1, 0.45))
