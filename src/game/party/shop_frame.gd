## 캠프 장비·소지품의 상점 짜임(M2.7 R2-c, 원작 상점 화면 jp_guide3_img1~3, 1280×720 기준 실측):
## 원작 다이얼 자리(x 0~180, y 0~100) → 「뒤로」 140×64, 설명 띠 x 192 → 인물 판 왼쪽(원작 180~750) · y 0~100,
## 돈 문패 자리(x 0~340, y 140~190) → 화면 이름 문패 x 0~340 · y 112~162, 목록 창 x 16(캠프는 232, P3 키패드 자리) → 판 왼쪽 − 24 · y 172~500(원작 30~710 · 240~505),
## 설명 창 같은 폭 · y 510 → 아래 − 8(원작 15~730 · 520~710), 인물 판 오른쪽 W(원작 765~1280). 앵커로 붙여 넓은 창에서는 왼쪽이 넓어진다.
## 장식(띠·문패·창)은 그리기만, 누르는 것은 「뒤로」와 판의 대원 단추. 목록 줄은 놓는 하위 화면이 list_offsets() 자리에 둔다.
class_name ShopFrame
extends Control

signal back

const BACK := Rect2(16, 18, 140, 64)
const TITLE := Rect2(0, 112, 340, 50)
const SIDE := 16.0
## 캠프의 왼쪽 창 왼쪽 끝(P3, 사용자 결정 2026-10-25): 왼쪽 아래 방향 십자(x 8~208) 오른쪽 + 24. 띠·문패·「뒤로」는 그대로.
const PAD_SIDE := 232.0
## 왼쪽 창과 인물 판 사이.
const GAP := 24.0
const LIST_TOP := 172.0
## 상점(08 §7.1): 문패 아래에 종류 탭 줄(y 166~230)이 있으면 목록 창 위 끝.
const TABS_LIST_TOP := 236.0
const LIST_BOTTOM := 500.0
const DESC_TOP := 510.0
const BOTTOM := 8.0
## 창 안 여백(양 끝 마개 안쪽).
const PAD := 14.0
const DESC_HEAD_H := 40.0
const DESC_FS := 18
const DESC_LINE_H := 28.0

var back_button: PartyButton
var banner: FacilityBanner
var title_plate: Control
var list_window: Control
var desc_window: Control
var panel: CharPanel
var title_text := ""
## 문패 글을 오른쪽에 맞춘다(상점 소지금 「1,480엔」, 08 §7.1). 캠프 화면 이름은 가운데.
var title_right := false
var desc_title := ""
var desc_lines: Array[String] = []
var _has_desc := true
## 왼쪽 목록·설명 창의 왼쪽 끝(build 의 left).
var left := SIDE
## 목록 창 위 끝(build 의 list_top).
var list_top := LIST_TOP


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## prefix: 단추 이름 앞(「Equip」→ EquipBack·EquipPrev·EquipNext). with_desc: 설명 창이 있는지(없으면 목록 창이 아래까지).
## left_x: 왼쪽 목록·설명 창의 왼쪽 끝(캠프는 PAD_SIDE, 가상 키패드 자리를 비운다).
## top: 목록 창 위 끝(캠프는 LIST_TOP, 상점에 종류 탭 줄이 있으면 TABS_LIST_TOP).
func build(prefix: String, back_label: String, with_desc: bool, left_x: float = SIDE, top: float = LIST_TOP) -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_has_desc = with_desc
	left = left_x
	list_top = top
	list_window = _deco(prefix + "ListWindow", Vector2(0, 0), Vector2(1, 0 if with_desc else 1),
		Vector4(left, list_top, -CharPanel.W - GAP, LIST_BOTTOM if with_desc else -BOTTOM),
		func(c: Control) -> void: UiTheme.draw_shop_window(c, Rect2(Vector2.ZERO, c.size)))
	desc_window = _deco(prefix + "DescWindow", Vector2(0, 0), Vector2(1, 1), Vector4(left, DESC_TOP, -CharPanel.W - GAP, -BOTTOM), _draw_desc)
	desc_window.visible = with_desc
	title_plate = _deco(prefix + "Title", Vector2.ZERO, Vector2.ZERO, Vector4(TITLE.position.x, TITLE.position.y, TITLE.end.x, TITLE.end.y),
		_draw_title)
	banner = FacilityBanner.new()
	banner.name = prefix + "Banner"
	add_child(banner)
	PartyMenu.place(banner, Vector2(0, 0), Vector2(1, 0), Vector4(FacilityBanner.X, 0, -CharPanel.W - 8, FacilityBanner.H))
	panel = CharPanel.new()
	panel.name = prefix + "Panel"
	add_child(panel)
	panel.build(prefix)
	back_button = PartyButton.new()
	back_button.name = prefix + "Back"
	back_button.text = back_label
	add_child(back_button)
	PartyMenu.place(back_button, Vector2.ZERO, Vector2.ZERO, Vector4(BACK.position.x, BACK.position.y, BACK.end.x, BACK.end.y))
	back_button.activated.connect(func() -> void: back.emit())


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4, painter: Callable) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	c.draw.connect(painter.bind(c))
	return c


## 목록 창 안쪽(줄을 놓는 곳)의 앵커와 여백: [a0, a1, Vector4].
func list_anchor() -> Array:
	return [Vector2(0, 0), Vector2(1, 0 if _has_desc else 1),
		Vector4(left + PAD, list_top + PAD * 0.75, -CharPanel.W - GAP - PAD, (LIST_BOTTOM if _has_desc else -BOTTOM) - PAD * 0.75)]


func list_window_rect() -> Rect2:
	return list_window.get_rect()


func desc_rect() -> Rect2:
	return desc_window.get_rect()


func banner_rect() -> Rect2:
	return banner.get_rect()


func title_rect() -> Rect2:
	return title_plate.get_rect()


func show_title(t: String, right: bool = false) -> void:
	if t != title_text or right != title_right:
		title_text = t
		title_right = right
		title_plate.queue_redraw()


## 오른쪽 맞춤 문패 글의 오른쪽 끝 여백(기울기 + 안쪽 선 안).
const TITLE_RIGHT_PAD := 28.0
const TITLE_FS := 24


func _draw_title(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	if not title_right:
		UiTheme.draw_plate(c, r, title_text, TITLE_FS)
		return
	UiTheme.draw_plate(c, r, "", TITLE_FS)
	c.draw_string(c.get_theme_default_font(), Vector2(0, r.get_center().y + TITLE_FS * 0.36), title_text, HORIZONTAL_ALIGNMENT_RIGHT,
		r.size.x - TITLE_RIGHT_PAD, TITLE_FS, UiTheme.HEAD_TEXT)


func show_desc(title: String, lines: Array[String]) -> void:
	desc_title = title
	desc_lines = lines
	desc_window.queue_redraw()


## 설명 줄 i 의 글자 바닥 자리(설명 창 기준).
func desc_line_pos(i: int) -> Vector2:
	return Vector2(PAD + 6.0, 6.0 + DESC_HEAD_H + 10.0 + (i + 1) * DESC_LINE_H - 7.0)


## 설명 창에 들어가는 줄 수.
func desc_capacity() -> int:
	return int((desc_window.size.y - DESC_HEAD_H - 16.0) / DESC_LINE_H)


func _draw_desc(c: Control) -> void:
	UiTheme.draw_shop_window(c, Rect2(Vector2.ZERO, c.size), DESC_HEAD_H)
	var font := c.get_theme_default_font()
	c.draw_string(font, Vector2(PAD + 6.0, 6.0 + DESC_HEAD_H * 0.5 + 22 * 0.36), desc_title, HORIZONTAL_ALIGNMENT_LEFT,
		c.size.x - 2.0 * PAD - 12.0, 22, UiTheme.TEXT)
	for i in mini(desc_lines.size(), desc_capacity()):
		c.draw_string(font, desc_line_pos(i), desc_lines[i], HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 2.0 * PAD - 12.0, DESC_FS,
			UiTheme.SHOP_SECTION_TEXT if i == 0 else UiTheme.TEXT)
