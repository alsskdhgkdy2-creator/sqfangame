## 마을의 다이얼 자리(M3 A2, 원작 시계 다이얼 + 「Ⓨ CAMP」): 왼쪽 위 0,0 176×100 전체가 캠프를 여는 단추 하나(CampButton)다.
## 위 0~66 은 기울어진 판에 날(「n일째」), 아래 66~100 은 어두운 알약에 「캠프」. 광장·아보르 입구·여관이 같이 쓴다(D28).
class_name TownPlate
extends TouchButton

const SIZE := Vector2(176, 100)
const DIAL_H := 66.0
const PILL := Rect2(8, 68, 160, 30)
const DAY_FS := 22
const PILL_FS := 18

## 위 줄(날).
var day_text := ""


func _init() -> void:
	super()
	name = "CampButton"


func show_day(t: String) -> void:
	if t != day_text:
		day_text = t
		queue_redraw()


func _draw() -> void:
	UiTheme.draw_plate(self, Rect2(Vector2(-UiTheme.PLATE_SLANT, 0), Vector2(size.x + UiTheme.PLATE_SLANT, DIAL_H)), "", 1)
	var font := get_theme_default_font()
	var fs := FacilityPlate.fit_size(font, day_text, DAY_FS, size.x - FacilityPlate.TEXT_INSET)
	draw_string_outline(font, Vector2(FacilityPlate.TEXT_X, DIAL_H / 2.0 + fs * 0.36), day_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - FacilityPlate.TEXT_INSET, fs, 6, Color.BLACK)
	draw_string(font, Vector2(FacilityPlate.TEXT_X, DIAL_H / 2.0 + fs * 0.36), day_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - FacilityPlate.TEXT_INSET, fs, UiTheme.TEXT)
	var pill_col := Color(0.03, 0.12, 0.15, 0.9) if not held else Color(0.1, 0.3, 0.34, 0.95)
	UiTheme.fill_round(self, PILL, pill_col, int(PILL.size.y / 2.0), UiTheme.FAC_PLATE_EDGE, 2)
	draw_string(font, Vector2(PILL.position.x, PILL.get_center().y + PILL_FS * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, PILL.size.x,
		PILL_FS, UiTheme.TEXT)
