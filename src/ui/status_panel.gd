## 위험도 게이지와 대원 5명 레벨·HP(05 §6, §9.1, 07 §9.5). 상태를 읽기만 한다.
class_name StatusPanel
extends Control

const GAUGE_COLORS := {"blue": Color(0.25, 0.55, 1.0), "yellow": Color(1.0, 0.82, 0.2), "red": Color(1.0, 0.25, 0.25)}

var state: ExplorationState
var texts: TextDb
var member_names: Array[String] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 180)


func set_state(s: ExplorationState, text_db: TextDb, names: Array[String]) -> void:
	state = s
	texts = text_db
	member_names = names
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## 대원 칸의 「Lv n」(07 §9.5). 레벨업 뒤 refresh 로 바로 바뀐다.
func level_text(i: int) -> String:
	return texts.t("hud.level", {"level": state.party.members[i].level})


## 대원 i 의 HP 막대 색(HpColor 한 규칙).
func hp_bar_color(i: int) -> Color:
	var m: PartyState.Member = state.party.members[i]
	return HpColor.of(m.hp, m.max_hp)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.07, 0.92))
	if state == null:
		return
	var font := get_theme_default_font()
	var x0 := 14.0
	var w := size.x - 28.0
	var y := 10.0
	var g := state.encounter.gauge()
	draw_string(font, Vector2(x0, y + 18), texts.t("hud.danger"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.8, 0.9, 1.0))
	var bar := Rect2(x0 + 90, y + 4, w - 90, 18)
	draw_rect(bar, Color(0.1, 0.13, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * g, bar.size.y)), GAUGE_COLORS[state.encounter.gauge_color()])
	draw_rect(bar, Color(0.4, 0.5, 0.55), false, 1.0)
	y += 34.0
	var row_h := (size.y - y - 6.0) / maxf(1.0, state.party.members.size())
	for i in state.party.members.size():
		var m: PartyState.Member = state.party.members[i]
		var name := member_names[i] if i < member_names.size() else m.id
		var col := Color(0.9, 0.95, 1.0) if m.alive() else Color(0.5, 0.4, 0.4)
		var ty := y + row_h * i + row_h * 0.7
		draw_string(font, Vector2(x0, ty), name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.37, 16, col)
		draw_string(font, Vector2(x0 + w * 0.37, ty), level_text(i), HORIZONTAL_ALIGNMENT_RIGHT, w * 0.13, 14, Color(1.0, 0.86, 0.45) if m.alive() else col)
		var hb := Rect2(x0 + w * 0.52, y + row_h * i + row_h * 0.25, w * 0.3, row_h * 0.45)
		draw_rect(hb, Color(0.1, 0.13, 0.16))
		var ratio := float(m.hp) / maxf(1.0, m.max_hp)
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * ratio, hb.size.y)), hp_bar_color(i))
		draw_string(font, Vector2(x0 + w * 0.84, ty), "%d/%d" % [m.hp, m.max_hp], HORIZONTAL_ALIGNMENT_RIGHT, w * 0.16, 15, col)
