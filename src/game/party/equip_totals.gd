## 장비 탭 칸 줄 아래 합계 표(M2.6 U8): 공격·마법 공격·방어·마법 방어(왼쪽)와 힘~행운(오른쪽).
## 목록이 닫혀 있으면 지금 값, 목록에서 고른 줄이 있으면 「지금 → 바꾸면」과 차이(색 + 「+8」「-2」 부호).
## 값은 모두 넘겨받은 GrowthRules.profile 묶음에서 읽는다(표가 규칙 계산을 따로 하지 않는다).
class_name EquipTotals
extends Control

const PAD := 14.0
const HEAD_H := 34.0
const LINE_H := 28.0
const GROUP_GAP := 18.0
const COL_GAP := 6.0
const NAME_FS := 15
const VALUE_FS := 16
const NAME_COLOR := Color(0.7, 0.85, 0.9)
const VALUE_COLOR := Color(0.92, 0.97, 1.0)
const UP_COLOR := Color(0.45, 0.95, 0.6)
const DOWN_COLOR := Color(1.0, 0.55, 0.45)
const ARROW := "→"

var title := ""
var compare_label := ""
## [{key, name, now, after}] — after 는 견줄 때만(아니면 null). 왼쪽 묶음 GEAR, 오른쪽 묶음 STATS 차례.
var lines: Array[Dictionary] = []
var comparing := false


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## now·after: GrowthRules.profile 묶음. after 가 null 이면 지금 값만.
func show_totals(texts: TextDb, now: Dictionary, after: Variant) -> void:
	title = texts.t("party.totals.title")
	compare_label = texts.t("party.totals.compare")
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


## 표가 다 들어가는 높이.
static func needed_height() -> float:
	return PAD + HEAD_H + maxf(BattleLimits.GEAR.size(), BattleLimits.STATS.size()) * LINE_H + PAD * 0.5


## 줄 i 의 칸들(Rect2): name · now · arrow · after · delta. 열 폭은 모든 줄의 글자 폭으로 같게 잡는다.
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
	var group := 0 if i < BattleLimits.GEAR.size() else 1
	var row := i if group == 0 else i - BattleLimits.GEAR.size()
	var gw := (size.x - 2.0 * PAD - GROUP_GAP) / 2.0
	var x := PAD + group * (gw + GROUP_GAP)
	var y := PAD + HEAD_H + row * LINE_H
	var now_x := x + name_w + COL_GAP * 2.0
	var arrow_x := now_x + value_w + COL_GAP
	var after_x := arrow_x + arrow_w + COL_GAP
	var delta_x := after_x + value_w + COL_GAP
	return {
		"line": Rect2(x, y, gw, LINE_H),
		"name": Rect2(x, y, name_w, LINE_H),
		"now": Rect2(now_x, y, value_w, LINE_H),
		"arrow": Rect2(arrow_x, y, arrow_w, LINE_H),
		"after": Rect2(after_x, y, value_w, LINE_H),
		"delta": Rect2(delta_x, y, delta_w, LINE_H),
	}


func _draw() -> void:
	UiTheme.draw_window(self, Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	draw_string(font, Vector2(PAD, PAD + 20), title, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.5, 17, UiTheme.HEAD_TEXT)
	if comparing:
		draw_string(font, Vector2(size.x * 0.4, PAD + 20), compare_label, HORIZONTAL_ALIGNMENT_RIGHT, size.x * 0.6 - PAD, 15, NAME_COLOR)
	for i in lines.size():
		var l := lines[i]
		var c := line_layout(i)
		var ty := (c["line"] as Rect2).position.y + LINE_H * 0.72
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
