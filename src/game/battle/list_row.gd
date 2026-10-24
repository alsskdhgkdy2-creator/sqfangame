## 전투 명령 목록의 줄 하나(원작 HD 1868180_0e36b17e: 오른쪽 끝이 목록 전체의 굽은 가장자리를 따른다).
## 입력은 PartyButton 그대로(포커스 없음, 손가락 소유, 목록 줄이면 끌어 내리기). 그림만 바꾼다: 왼쪽은 곧고 오른쪽 끝은
## curve(CommandPanel)가 정하는 원호 위의 점이다. 모양은 UiTheme 의 "cmd:*"(청록 줄·노랑 커서·어두운 못 고름).
class_name ListRow
extends PartyButton

## 오른쪽 끝을 정하는 목록(CommandPanel, arc_x: 목록 기준 y → 목록 기준 x). 없으면 사각형.
## 형은 Control 로 둔다: CommandPanel 이 ListRow 를 쓰므로 여기서 CommandPanel 형을 쓰면 스크립트끼리 서로 붙잡아 끝날 때 새는 것이 남는다.
var curve: Control
## 고른 명령 표시(스킬 고르기·대상 고르기 중): 밝은 시안 「cmd:chosen」(gs2_653224). 누르기는 받지 않는다(mouse_filter 는 부르는 쪽이 정한다).
var chosen := false
## 오른쪽 글자(TP)를 남색 상자에 흰 숫자로(스킬 목록 줄, gs2_653224).
var boxed_right := false
const BOX_W := 64.0


func _init() -> void:
	super()  # TouchButton._init: 포커스 없음, 누르기 받음, 가장 작은 크기 64×64
	skin = "cmd"
	align_left = true
	font_size = 24


func theme_state() -> String:
	if chosen and UiTheme.has_look(skin + ":chosen"):
		return skin + ":chosen"
	var st := UiTheme.state_of(held, selected, false, disabled or dimmed)
	return skin + ":" + st if UiTheme.has_look(skin + ":" + st) else st


## 줄 위·아래 오른쪽 끝(이 줄 기준 x).
func right_edge() -> Vector2:
	if curve == null or not is_inside_tree() or not curve.is_inside_tree():
		return Vector2(size.x, size.x)
	var to_list := curve.get_global_transform().affine_inverse() * get_global_transform()
	var x0 := (to_list * Vector2.ZERO).x
	var top: float = curve.call("arc_x", (to_list * Vector2.ZERO).y)
	var bottom: float = curve.call("arc_x", (to_list * Vector2(0, size.y)).y)
	return Vector2(top - x0, bottom - x0)


func polygon() -> PackedVector2Array:
	var e := right_edge()
	return PackedVector2Array([Vector2.ZERO, Vector2(minf(e.x, size.x), 0), Vector2(minf(e.y, size.x), size.y), Vector2(0, size.y)])


func _draw() -> void:
	var lk := UiTheme.look(theme_state())
	var pts := polygon()
	var cols := PackedColorArray()
	for p in pts:
		cols.append((lk["top"] as Color).lerp(lk["bottom"], p.y / maxf(1.0, size.y)))
	draw_polygon(pts, cols)
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, lk["outer"], float(lk["outer_w"]), true)
	var fg: Color = lk["text"]
	var font := get_theme_default_font()
	var pad := 22.0
	var edge := minf(pts[1].x, pts[2].x)
	var main_y := size.y / 2.0 + font_size * 0.36
	if not note.is_empty():
		main_y = size.y * 0.45 + font_size * 0.2
	var right_w := 0.0
	if not right.is_empty() and boxed_right:
		var box := Rect2(edge - 8.0 - BOX_W, 8.0, BOX_W, size.y - 16.0)
		draw_rect(box, UiTheme.SKILL_TP_BOX)
		var nw := font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2).x
		draw_string(font, Vector2(box.end.x - 8.0 - nw, box.get_center().y + (font_size - 2) * 0.36), right, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size - 2, UiTheme.CMD_TEXT)
		right_w = BOX_W
	elif not right.is_empty():
		right_w = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4).x
		draw_string(font, Vector2(edge - 16.0 - right_w, main_y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 4, fg)
	draw_string(font, Vector2(pad, main_y), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(8.0, edge - pad - 24.0 - right_w), font_size, fg)
	if not note.is_empty():
		draw_string(font, Vector2(pad, size.y - 9.0), note, HORIZONTAL_ALIGNMENT_LEFT, edge - pad - 12.0, 14, lk["reason"])
