## 캠프 장비·소지품 인물 판의 능력치 묶음(M2.6 U8 → M2.7 R2-c, 원작 상점 인물 판 jp_guide3_img1~3 의 STR~LUC 줄과 攻撃·防御 판):
## 위에 힘~행운 한 열(이름 칸 + 값), 아래에 공격·마법 공격 / 방어·마법 방어 2×2 판.
## 목록이 닫혀 있으면 지금 값, 목록에서 고른 줄이 있으면 「지금 → 바꾸면」과 차이(색 + 「+8」「-2」 부호).
## 값은 모두 넘겨받은 GrowthRules.profile 묶음에서 읽는다(표가 규칙 계산을 따로 하지 않는다).
class_name EquipTotals
extends Control

const STAT_W := 250.0
const STAT_H := 27.0
const STAT_PITCH := 30.0
const GEAR_W := 244.0
const GEAR_H := 32.0
const GEAR_PITCH := 38.0
const GEAR_GAP_X := 8.0
## 능력치 열과 공격·방어 판 사이.
const GROUP_GAP := 10.0
const PAD := 8.0
const COL_GAP := 6.0
const NAME_FS := 15
const VALUE_FS := 16
const NAME_COLOR := Color(0.7, 0.85, 0.9)
const VALUE_COLOR := Color(0.92, 0.97, 1.0)
const UP_COLOR := Color(0.45, 0.95, 0.6)
const DOWN_COLOR := Color(1.0, 0.55, 0.45)
const ARROW := "→"

## [{key, name, now, after}] — after 는 견줄 때만(아니면 null). GEAR 차례 다음 STATS 차례.
var lines: Array[Dictionary] = []
var comparing := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## now·after: GrowthRules.profile 묶음. after 가 null 이면 지금 값만.
func show_totals(texts: TextDb, now: Dictionary, after: Variant) -> void:
	comparing = after != null
	lines.clear()
	for g in BattleLimits.GEAR:
		lines.append({"key": g, "name": texts.t("stat." + g), "now": int(now["gear"][g]), "after": int(after["gear"][g]) if comparing else null})
	for k in BattleLimits.STATS:
		lines.append({"key": k, "name": texts.t("stat." + k), "now": int(now["stats"][k]), "after": int(after["stats"][k]) if comparing else null})
	queue_redraw()


func line_of(key: String) -> Dictionary:
	for l in lines:
		if l["key"] == key:
			return l
	return {}


## 「+8」「-2」(같으면 "").
static func delta_text(l: Dictionary) -> String:
	if l.get("after") == null:
		return ""
	var d: int = int(l["after"]) - int(l["now"])
	return "" if d == 0 else PartyMenu.signed(d)


static func delta_color(l: Dictionary) -> Color:
	if l.get("after") == null:
		return VALUE_COLOR
	var d: int = int(l["after"]) - int(l["now"])
	return UP_COLOR if d > 0 else (DOWN_COLOR if d < 0 else VALUE_COLOR)


## 묶음 전체 크기(능력치 열 + 공격·방어 판 두 줄).
static func needed_size() -> Vector2:
	var stats_h := (BattleLimits.STATS.size() - 1) * STAT_PITCH + STAT_H
	var gear_rows := ceili(BattleLimits.GEAR.size() / 2.0)
	return Vector2(maxf(STAT_W, 2.0 * GEAR_W + GEAR_GAP_X), stats_h + GROUP_GAP + (gear_rows - 1) * GEAR_PITCH + GEAR_H)


static func needed_height() -> float:
	return needed_size().y


## 줄 i 의 칸들(Rect2): line · box(이름 칸) · name · now · arrow · after · delta. 열 폭은 모든 줄의 글자 폭으로 같게 잡는다.
func line_layout(i: int) -> Dictionary:
	var font := get_theme_default_font()
	var name_w := 0.0
	var value_w := 0.0
	var delta_w := 0.0
	for l in lines:
		name_w = maxf(name_w, font.get_string_size(l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FS).x)
		value_w = maxf(value_w, font.get_string_size(str(l["now"]), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS).x)
		if l["after"] != null:
			value_w = maxf(value_w, font.get_string_size(str(l["after"]), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS).x)
		delta_w = maxf(delta_w, font.get_string_size(delta_text(l), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS).x)
	var arrow_w := font.get_string_size(ARROW, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS).x
	var line: Rect2
	var ng := BattleLimits.GEAR.size()
	if i >= ng:
		line = Rect2(0, (i - ng) * STAT_PITCH, STAT_W, STAT_H)
	else:
		var top := (BattleLimits.STATS.size() - 1) * STAT_PITCH + STAT_H + GROUP_GAP
		line = Rect2((i % 2) * (GEAR_W + GEAR_GAP_X), top + (i / 2) * GEAR_PITCH, GEAR_W, GEAR_H)
	var x := line.position.x
	var y := line.position.y
	var h := line.size.y
	var box := Rect2(x, y, name_w + 2.0 * PAD, h)
	var now_x := box.end.x + COL_GAP
	var arrow_x := now_x + value_w + COL_GAP
	var after_x := arrow_x + arrow_w + COL_GAP
	var delta_x := after_x + value_w + COL_GAP
	return {
		"line": line,
		"box": box,
		"name": Rect2(x + PAD, y, name_w, h),
		"now": Rect2(now_x, y, value_w, h),
		"arrow": Rect2(arrow_x, y, arrow_w, h),
		"after": Rect2(after_x, y, value_w, h),
		"delta": Rect2(delta_x, y, delta_w, h),
	}


func _draw() -> void:
	var font := get_theme_default_font()
	for i in lines.size():
		var l := lines[i]
		var c := line_layout(i)
		var lr: Rect2 = c["line"]
		var gear := i < BattleLimits.GEAR.size()
		draw_rect(lr, UiTheme.ST_GEAR_VALUE if gear else UiTheme.ST_ROW)
		draw_rect(c["box"], UiTheme.ST_GEAR_LABEL if gear else UiTheme.ST_ROW_NAME)
		var ty := lr.position.y + lr.size.y * 0.5 + VALUE_FS * 0.36
		draw_string(font, Vector2((c["name"] as Rect2).position.x, ty), l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FS, NAME_COLOR)
		_value(font, c["now"], ty, str(l["now"]), VALUE_COLOR)
		if l["after"] == null:
			continue
		var col := delta_color(l)
		draw_string(font, Vector2((c["arrow"] as Rect2).position.x, ty), ARROW, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS, NAME_COLOR)
		_value(font, c["after"], ty, str(l["after"]), col)
		draw_string(font, Vector2((c["delta"] as Rect2).position.x, ty), delta_text(l), HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FS, col)


func _value(font: Font, r: Rect2, ty: float, t: String, col: Color) -> void:
	draw_string(font, Vector2(r.position.x, ty), t, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, VALUE_FS, col)
