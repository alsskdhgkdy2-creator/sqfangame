## 명령 목록(06 §9.1·§9.2, M2.7 R3: 원작 HD 1868180_0e36b17e 의 왼쪽 명령 목록). 초상 오른쪽에 세로로 줄을 쌓고,
## 목록 전체의 오른쪽 가장자리는 오른쪽으로 볼록한 원호다(뒤판과 줄 끝이 같은 원호를 따른다, ListRow).
## 줄: 공격·스킬·방어·도주(숫자 키 1~4), 그 아래 「뒤로」. 모든 명령이 차면 「실행」과 「뒤로」.
## 스킬 목록(원작 III HD gs2_653224): 명령 목록 오른쪽의 따로 된 판(skill_panel, 이 컨트롤의 자식이지만 영역 밖 오른쪽에 놓인다).
## 첫 줄 위가 「스킬」 줄 위와 맞고, 높이는 줄을 감싸되 가장 크게 파티 카드 위 − 8(skill_area, 전투 층이 정한다). 줄은 청록, 커서 줄은 옅은 노랑,
## TP 는 오른쪽 남색 상자. 넘치면 끌어 내린다(PartyScroll, 줄을 끌거나 휠, 키보드 커서는 그 줄이 보이게 맞춘다). 설명은 위 메시지 띠.
## 스킬 고르기·대상 고르기 동안 명령 줄은 그대로 보이고, 고른 명령(스킬·공격)은 밝은 시안 「고른」 모양, 누르기는 받지 않는다(「뒤로」만).
## 대상 고르기에 들어가면 스킬 판은 닫힌다(고를 적 칸을 덮지 않는다). 무엇을 보일지는 전투 층이 정하고, 누르기는 모두 pressed 하나로 보낸다.
class_name CommandPanel
extends Control

## kind: "command"(arg 0~3) · "skill"(arg 스킬 ID) · "back" · "execute"
signal pressed(kind: String, arg: Variant)

const COMMANDS := ["attack", "skill", "guard", "escape"]
## 줄 높이·간격(누르는 칸 64 이상), 뒤판 안쪽 여백.
const ROW_H := 64.0
const GAP := 6.0
const PAD := 6.0
## 스킬 판 안쪽 여백, 스킬 줄 사이.
const SKILL_PAD := 8.0
const SKILL_GAP := 4.0
## 원호가 줄 위·아래 끝보다 가운데에서 더 나오는 폭.
const BULGE := 40.0
## 오른쪽 끝(가운데)과 뒤판 테두리 사이.
const RIM := 10.0

var texts: TextDb
var command_buttons: Array[ListRow] = []
## 스킬 목록 판(테두리)과 그 안의 끌어 내리는 목록.
var skill_panel: Control
var skill_list: PartyScroll
var skill_rows: Array[ListRow] = []
## 스킬 판 자리(이 컨트롤 기준). 전투 층이 화면 크기에 맞춰 정한다(set_skill_area).
var skill_area := Rect2(300, 76, 410, 292)
## 마지막으로 보인 스킬 목록 커서(바뀔 때만 그 줄이 보이게 맞춘다: 다시 그리기만 할 때는 끌어 내린 자리를 지킨다).
var _skill_cursor := -1
var back_button: ListRow
var execute_button: ListRow
## "none" / "menu" / "skills" / "target" / "confirm"
var mode := "none"
## 지금 보이는 대원 이름(초상·시험용).
var title := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func build(text_db: TextDb) -> void:
	texts = text_db
	for i in COMMANDS.size():
		var b := _row("Cmd_" + COMMANDS[i], "%d  %s" % [i + 1, texts.t("battle.cmd." + COMMANDS[i])], self)
		b.activated.connect(func() -> void: pressed.emit("command", i))
		command_buttons.append(b)
	execute_button = _row("Execute", texts.t("battle.ui.execute"), self)
	execute_button.activated.connect(func() -> void: pressed.emit("execute", null))
	back_button = _row("Back", texts.t("battle.ui.back"), self)
	back_button.activated.connect(func() -> void: pressed.emit("back", null))
	skill_panel = Control.new()
	skill_panel.name = "SkillPanel"
	skill_panel.mouse_filter = MOUSE_FILTER_STOP
	skill_panel.draw.connect(_draw_skill_panel)
	add_child(skill_panel)
	skill_list = PartyScroll.new()
	skill_list.name = "SkillList"
	skill_panel.add_child(skill_list)
	skill_list.content.item_rect_changed.connect(func() -> void:
		for r in skill_rows:
			r.queue_redraw())
	show_none()


func _row(n: String, t: String, parent: Node) -> ListRow:
	var b := ListRow.new()
	b.name = n
	b.text = t
	b.curve = self
	b.size = Vector2(100, ROW_H)
	parent.add_child(b)
	return b


func _hide_all() -> void:
	for b in command_buttons:
		b.visible = false
		b.chosen = false
		b.mouse_filter = MOUSE_FILTER_STOP
		b.cancel()
	for b in skill_rows:
		b.visible = false
		b.cancel()
	skill_list.cancel()
	skill_panel.visible = false
	back_button.visible = false
	back_button.cancel()
	execute_button.visible = false
	execute_button.cancel()


func show_none() -> void:
	mode = "none"
	title = ""
	_hide_all()
	_layout()


## blocked: 명령 번호 → 못 고르는 이유(흐리게 + 이유 글자, 누르면 이유를 알린다).
func show_menu(member_title: String, cursor: int, can_back: bool, blocked: Dictionary) -> void:
	mode = "menu"
	title = member_title
	_hide_all()
	for i in command_buttons.size():
		var b := command_buttons[i]
		b.visible = true
		b.selected = i == cursor
		b.dimmed = blocked.has(i)
		b.note = str(blocked.get(i, ""))
	_show_back(can_back)
	_layout()


## rows: [{id, name, tp, reason}]
func show_skills(member_title: String, rows: Array, cursor: int) -> void:
	# 처음 열 때(다른 모드·다른 대원에서 올 때)만 맨 위로. 다시 그릴 때는 끌어 내린 자리를 지킨다.
	var opening := mode != "skills" or title != member_title
	var moved := cursor != _skill_cursor
	_skill_cursor = cursor
	mode = "skills"
	title = member_title
	_hide_all()
	_show_commands_fixed(1)
	while skill_rows.size() < rows.size():
		var b := _row("Skill_%d" % skill_rows.size(), "", skill_list.content)
		b.curve = null
		b.skin = "skill"
		b.boxed_right = true
		b.font_size = 20
		b.scroller = skill_list
		var idx := skill_rows.size()
		b.activated.connect(func() -> void: pressed.emit("skill", skill_rows[idx].get_meta("skill_id", "")))
		skill_rows.append(b)
	skill_panel.visible = true
	for i in rows.size():
		var b := skill_rows[i]
		b.visible = true
		b.position = Vector2(0, i * (ROW_H + SKILL_GAP))
		b.set_meta("skill_id", rows[i]["id"])
		b.show_row(rows[i]["name"], str(int(rows[i]["tp"])), str(rows[i]["reason"]), not str(rows[i]["reason"]).is_empty())
		b.selected = i == cursor
	skill_list.set_content_height(rows.size() * (ROW_H + SKILL_GAP) - SKILL_GAP)
	_show_back(true)
	_layout()
	if opening:
		skill_list.scroll_to(0.0)
	if opening or moved:
		_show_cursor_row()


## 대상 고르기: 명령 줄을 보인 채 고른 명령(chosen)만 「고른」 모양, 누를 수 있는 것은 「뒤로」뿐. 스킬 판은 닫는다.
func show_target(member_title: String, chosen: int = 0) -> void:
	mode = "target"
	title = member_title
	_hide_all()
	_show_commands_fixed(chosen)
	_show_back(true)
	_layout()


## 명령 줄을 보이되 누르기는 받지 않고, 고른 줄(chosen)만 「고른」 모양.
func _show_commands_fixed(chosen: int) -> void:
	for i in command_buttons.size():
		var b := command_buttons[i]
		b.visible = true
		b.selected = false
		b.dimmed = false
		b.note = ""
		b.chosen = i == chosen
		b.mouse_filter = MOUSE_FILTER_IGNORE


## 스킬 판 자리(이 컨트롤 기준).
func set_skill_area(r: Rect2) -> void:
	skill_area = r
	if texts != null:
		_layout()


func show_confirm(member_title: String = "") -> void:
	mode = "confirm"
	title = member_title
	_hide_all()
	execute_button.visible = true
	execute_button.selected = true
	_show_back(true)
	_layout()


func _show_back(enabled: bool) -> void:
	back_button.visible = true
	back_button.disabled = not enabled


## 줄 i 의 위 y(목록 기준).
static func row_y(i: int) -> float:
	return PAD + i * (ROW_H + GAP)


## 목록 기준 y 에서 오른쪽 가장자리 x(원호: 가운데 높이에서 가장 오른쪽, 위·아래 끝은 BULGE 만큼 안쪽).
func arc_x(y: float) -> float:
	var h := maxf(1.0, size.y)
	var r := (h * h / 4.0 + BULGE * BULGE) / (2.0 * BULGE)
	var cx := size.x - RIM - r
	var dy := clampf(y - h / 2.0, -h / 2.0, h / 2.0)
	return cx + sqrt(maxf(0.0, r * r - dy * dy))


func _layout() -> void:
	var i := 0
	if mode == "menu" or mode == "target" or mode == "skills":
		for b in command_buttons:
			_place_row(b, row_y(i))
			i += 1
	elif mode == "confirm":
		_place_row(execute_button, row_y(0))
	# 「뒤로」는 목록 맨 아래(명령 줄이 있으면 그 바로 아래보다 위로 오지 않는다).
	_place_row(back_button, maxf(size.y - PAD - ROW_H, row_y(i)))
	# 판 높이 = 줄 + 여백, 가장 크게 skill_area(카드 위 − 8)까지. 넘칠 때만 끌어 내린다(원작 gs2_653224 처럼 줄을 감싼다).
	var n := skill_rows.filter(func(b: ListRow) -> bool: return b.visible).size()
	var content_h := maxf(ROW_H, n * (ROW_H + SKILL_GAP) - SKILL_GAP)
	skill_panel.position = skill_area.position
	skill_panel.size = Vector2(skill_area.size.x, minf(skill_area.size.y, content_h + 2.0 * SKILL_PAD))
	skill_list.position = Vector2(SKILL_PAD, SKILL_PAD)
	var list_h := maxf(ROW_H, skill_panel.size.y - 2.0 * SKILL_PAD)
	var resized := absf(skill_list.size.y - list_h) > 0.01
	skill_list.size = Vector2(skill_area.size.x - 2.0 * SKILL_PAD, list_h)
	for r in skill_rows:
		r.size = Vector2(skill_list.size.x, ROW_H)
	# 목록의 보이는 높이가 바뀌면(화면 크기가 바뀜) 커서 줄이 보이게 맞춘다. 같은 크기로 다시 그릴 때는 손으로 끌어 내린 자리를 둔다.
	if resized and mode == "skills":
		_show_cursor_row()
	for b in command_buttons + skill_rows + [back_button, execute_button]:
		(b as ListRow).queue_redraw()
	queue_redraw()


## 줄 하나를 y 에 놓는다. 폭은 그 줄 위·아래 원호 끝 중 먼 쪽까지(누르는 칸 = 그린 모양을 감싸는 사각형: 원호 아래쪽 줄은
## 짧아져 오른쪽 스킬 판과 겹치지 않는다).
func _place_row(b: ListRow, y: float) -> void:
	b.position = Vector2(PAD, y)
	b.size = Vector2(maxf(arc_x(y), arc_x(y + ROW_H)) - PAD, ROW_H)


## 스킬 목록 커서 줄이 보이게 끌어 내린다(줄이 이미 다 보이면 그대로).
func _show_cursor_row() -> void:
	var visible_rows := skill_rows.filter(func(b: ListRow) -> bool: return b.visible).size()
	if _skill_cursor < 0 or _skill_cursor >= visible_rows:
		return
	var top := _skill_cursor * (ROW_H + SKILL_GAP)
	skill_list.ensure_visible(top, top + ROW_H)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and texts != null:
		_layout()


## 뒤판: 왼쪽은 곧고 오른쪽은 원호(바깥 여백 RIM 만큼 줄 끝보다 바깥).
func plate_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, 0)])
	var n := 24
	for k in n + 1:
		var y := size.y * k / n
		pts.append(Vector2(arc_x(y) + RIM - 2.0, y))
	pts.append(Vector2(0, size.y))
	return pts


func _draw() -> void:
	if mode == "none":
		return
	var pts := plate_polygon()
	draw_colored_polygon(pts, UiTheme.CMD_PLATE)
	var line := pts.duplicate()
	line.remove_at(0)
	draw_polyline(line, UiTheme.CMD_PLATE_EDGE, 3.0, true)


## 스킬 판: 남색 판, 가는 밝은 테두리(gs2_653224).
func _draw_skill_panel() -> void:
	var r := Rect2(Vector2.ZERO, skill_panel.size)
	skill_panel.draw_rect(r, UiTheme.SKILL_PANEL)
	skill_panel.draw_rect(r.grow(-1.5), UiTheme.SKILL_PANEL_EDGE, false, 2.0)
