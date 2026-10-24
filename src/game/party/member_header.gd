## 캠프 하위 화면의 위 줄(M2.7 R2, 원작 HD 상태·스킬 화면 gs2_653218·jp_guide2_img1~3): 화면 위 가장자리에 붙는다(앵커 위 넓게, 높이 H).
## 이름 칸(밝은 판, x 0~330·y 0~64, 양 끝에 앞·다음 대원 단추 = 원작 L·R) + Lv 띠(이름 칸 오른쪽 ~ 오른쪽 끝, y 18~64:
## 「Lv n」과 덧붙인 글) + 정보 띠(전체 폭, y 64~118: 왼쪽 HP·TP, 오른쪽 글과 막대). 오른쪽 위 「뒤로」.
## 띠는 장식(그리기만), 단추는 자식 PartyButton. 색은 palette(상태 = 청록 "status", 스킬 트리 = 파랑 "tree").
## 누르기는 step(±1)·back 신호로 내보낸다(놓는 하위 화면이 메뉴의 입력 입구로 보낸다).
class_name MemberHeader
extends Control

signal step(dir: int)
signal back

const H := 118.0
const NAME_TAB := Rect2(0, 0, 330, 64)
const LV_BAND_Y := 18.0
const INFO_Y := 64.0
const INFO_H := 54.0
const SWITCH_SIZE := Vector2(64, 64)
const BACK_SIZE := Vector2(120, 64)

var palette := "status"
var name_text := ""
var level_text := ""
## Lv 띠의 덧붙인 글(누적 경험치·남은 SP 등).
var level_extra := ""
var hp_text := ""
var tp_text := ""
## 정보 띠 오른쪽 글과 막대 비율(0 미만이면 막대 없음).
var right_text := ""
var right_ratio := -1.0
var prev_button: PartyButton
var next_button: PartyButton
var back_button: PartyButton


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## 단추를 만들고 위 가장자리에 붙인다. prefix: 단추 이름 앞(「Status」→ StatusPrev·StatusNext·StatusBack). back_label 이 비면 「뒤로」 없음.
func build(prefix: String, back_label: String) -> void:
	PartyMenu.place(self, Vector2(0, 0), Vector2(1, 0), Vector4(0, 0, 0, H))
	prev_button = _button(prefix + "Prev", "left", "", Vector2.ZERO, Vector4(0, 0, SWITCH_SIZE.x, SWITCH_SIZE.y))
	prev_button.activated.connect(func() -> void: step.emit(-1))
	next_button = _button(prefix + "Next", "right", "", Vector2.ZERO, Vector4(NAME_TAB.end.x - SWITCH_SIZE.x, 0, NAME_TAB.end.x, SWITCH_SIZE.y))
	next_button.activated.connect(func() -> void: step.emit(1))
	if back_label.is_empty():  # 상점 짜임의 인물 판: 「뒤로」는 화면 왼쪽 위(ShopFrame)
		return
	back_button = _button(prefix + "Back", "", back_label, Vector2(1, 0), Vector4(-8 - BACK_SIZE.x, 0, -8, BACK_SIZE.y))
	back_button.activated.connect(func() -> void: back.emit())


func _button(n: String, icon_name: String, label: String, a: Vector2, off: Vector4) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.icon = icon_name
	b.text = label
	add_child(b)
	PartyMenu.place(b, a, a, off)
	return b


func name_tab_rect() -> Rect2:
	return NAME_TAB


func lv_band_rect() -> Rect2:
	return Rect2(NAME_TAB.end.x, LV_BAND_Y, size.x - NAME_TAB.end.x, NAME_TAB.end.y - LV_BAND_Y)


func info_rect() -> Rect2:
	return Rect2(0, INFO_Y, size.x, INFO_H)


## [이름 칸, 이름 글자, Lv 띠, 정보 띠 위, 정보 띠 아래].
func colors() -> Array[Color]:
	if palette == "tree":
		return [UiTheme.TREE_NAME_TAB, UiTheme.TREE_NAME_TEXT, UiTheme.TREE_LV_BAND, UiTheme.TREE_INFO_TOP, UiTheme.TREE_INFO_BOTTOM]
	return [UiTheme.ST_NAME_TAB, UiTheme.ST_NAME_TEXT, UiTheme.ST_LV_BAND, UiTheme.ST_INFO_TOP, UiTheme.ST_INFO_BOTTOM]


func _txt(pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(get_theme_default_font(), pos, s, align as HorizontalAlignment, w, fs, col)


func _draw() -> void:
	var c := colors()
	var w := size.x
	var info := info_rect()
	draw_polygon(PackedVector2Array([info.position, Vector2(info.end.x, info.position.y), info.end, Vector2(0, info.end.y)]),
		PackedColorArray([c[3], c[3], c[4], c[4]]))
	draw_line(Vector2(0, info.end.y - 1.0), Vector2(w, info.end.y - 1.0), UiTheme.FAC_BANNER_EDGE, 2.0)
	var lv := lv_band_rect()
	draw_colored_polygon(PackedVector2Array([Vector2(lv.position.x - 6, lv.end.y), Vector2(lv.position.x + 14, lv.position.y),
		Vector2(w, lv.position.y), Vector2(w, lv.end.y)]), c[2])
	var nt := NAME_TAB
	draw_colored_polygon(PackedVector2Array([nt.position, Vector2(nt.end.x - 10, 0), Vector2(nt.end.x + 10, nt.end.y), Vector2(0, nt.end.y)]), c[0])
	_txt(Vector2(SWITCH_SIZE.x, 42), name_text, 28, c[1], nt.size.x - 2.0 * SWITCH_SIZE.x, HORIZONTAL_ALIGNMENT_CENTER)
	var lx := lv.position.x + 28.0
	_txt(Vector2(lx, 56), level_text, 30, UiTheme.ST_LV_TEXT)
	var back_w := BACK_SIZE.x + 24 if back_button != null else 16.0
	_txt(Vector2(lx + 130, 54), level_extra, 20, UiTheme.TEXT, maxf(40.0, w - back_w - lx - 130))
	var by := info.position.y + 36.0
	_txt(Vector2(20, by), "HP", 16, UiTheme.CARD_LABEL)
	_txt(Vector2(52, by), hp_text, 22, UiTheme.TEXT)
	_txt(Vector2(215, by), "TP", 16, UiTheme.CARD_LABEL)
	_txt(Vector2(247, by), tp_text, 22, UiTheme.ST_LV_TEXT)
	if right_ratio >= 0.0:
		var bar := Rect2(w - 175, info.position.y + 21, 155, 12)
		_txt(Vector2(bar.position.x - 400, by), right_text, 20, UiTheme.TEXT, 388, HORIZONTAL_ALIGNMENT_RIGHT)
		UiTheme.draw_gauge(self, bar, right_ratio, UiTheme.CARD_TP, UiTheme.ST_BAR_FILL, c[2])
