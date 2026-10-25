## 캠프 하위 화면의 위 줄(M2.7 R2, 원작 HD 상태·스킬 화면 gs2_653218·jp_guide2_img1~3): 화면 위 가장자리에 붙는다(앵커 위 넓게, 높이 H).
## 이름 칸(밝은 판, x 0~330·y 0~64, 양 끝에 앞·다음 대원 단추 = 원작 L·R) + Lv 띠(이름 칸 오른쪽 ~ 오른쪽 끝, y 18~64:
## 「Lv n」) + 정보 띠(전체 폭, y 64~118: 왼쪽 HP·TP(show_vitals), 오른쪽 글과 막대). 「뒤로」 단추는 없다(07 §9.9 E1 ⑤).
## 띠는 장식(그리기만), 단추는 자식 PartyButton. 색은 원작 III 근사 한 벌(UiTheme.MEMBER_*, 07 §9.9 E1 ②): 상태·스킬·인물 판이 같다.
## 누르기는 step(±1) 신호로 내보낸다(놓는 하위 화면이 메뉴의 입력 입구로 보낸다).
class_name MemberHeader
extends Control

signal step(dir: int)

const H := 118.0
const NAME_TAB := Rect2(0, 0, 330, 64)
const LV_BAND_Y := 18.0
const INFO_Y := 64.0
const INFO_H := 54.0
const SWITCH_SIZE := Vector2(64, 64)
## 정보 띠 글자(흰 글자, 이름표, 노란 TP·안내): 띠 두 끝 색에 대비 4.5:1 이상(시험).
const STRIP_TEXT := UiTheme.TEXT
const STRIP_LABEL := UiTheme.TEXT
const STRIP_ACCENT := UiTheme.ST_LV_TEXT

var name_text := ""
var level_text := ""
## 정보 띠 왼쪽 HP·TP 를 그리는지(스킬 화면은 남은 SP 만 둔다, 07 §9.9 E1 ③).
var show_vitals := true
var hp_text := ""
var tp_text := ""
## 정보 띠 오른쪽 글과 막대 비율(0 미만이면 막대 없음).
var right_text := ""
var right_ratio := -1.0
var prev_button: PartyButton
var next_button: PartyButton
## 마지막으로 그린 글(시험): lv(Lv 띠의 글), strip(정보 띠의 글, 왼쪽 → 오른쪽), colors.
var drawn := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## 단추를 만들고 위 가장자리에 붙인다. prefix: 단추 이름 앞(「Status」→ StatusPrev·StatusNext).
func build(prefix: String) -> void:
	PartyMenu.place(self, Vector2(0, 0), Vector2(1, 0), Vector4(0, 0, 0, H))
	prev_button = _button(prefix + "Prev", "left", "", Vector2.ZERO, Vector4(0, 0, SWITCH_SIZE.x, SWITCH_SIZE.y))
	prev_button.activated.connect(func() -> void: step.emit(-1))
	next_button = _button(prefix + "Next", "right", "", Vector2.ZERO, Vector4(NAME_TAB.end.x - SWITCH_SIZE.x, 0, NAME_TAB.end.x, SWITCH_SIZE.y))
	next_button.activated.connect(func() -> void: step.emit(1))


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
static func colors() -> Array[Color]:
	return [UiTheme.MEMBER_NAME_TAB, UiTheme.MEMBER_NAME_TEXT, UiTheme.MEMBER_LV_BAND, UiTheme.MEMBER_STRIP_TOP, UiTheme.MEMBER_STRIP_BOTTOM]


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
	var by := info.position.y + 36.0
	var strip: Array[String] = []
	if show_vitals:
		strip.append_array(["HP", hp_text, "TP", tp_text])
		_txt(Vector2(20, by), "HP", 16, STRIP_LABEL)
		_txt(Vector2(52, by), hp_text, 22, STRIP_TEXT)
		_txt(Vector2(215, by), "TP", 16, STRIP_LABEL)
		_txt(Vector2(247, by), tp_text, 22, STRIP_ACCENT)
	if right_ratio >= 0.0:
		var bar := Rect2(w - 175, info.position.y + 21, 155, 12)
		_txt(Vector2(bar.position.x - 400, by), right_text, 20, STRIP_TEXT, 388, HORIZONTAL_ALIGNMENT_RIGHT)
		UiTheme.draw_gauge(self, bar, right_ratio, UiTheme.CARD_TP, UiTheme.ST_BAR_FILL, c[2])
		strip.append(right_text)
	drawn = {"lv": [level_text], "strip": strip, "colors": c}
