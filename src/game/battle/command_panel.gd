## 명령 패널(06 §9.1·§9.2): 지금 대원 이름·TP, 명령 2×2(공격·스킬·방어·도주), 패널 안에서 바뀌는 스킬 목록,
## 아래 「뒤로」와 모든 명령이 차면 「실행」. 무엇을 보일지는 전투 층이 정하고, 누르기는 모두 pressed 하나로 전투 층 입구에 보낸다.
## 스킬 목록은 「뒤로」 위까지의 끌어 내리는 목록이다(스킬이 다섯 넘게 늘어도 「뒤로」·패널 밖으로 넘치지 않는다): 줄을 끌거나
## 휠로 내리고, 키보드 커서는 그 줄이 보이게 맞춘다. 끌기와 누르기는 파티 메뉴 목록과 같은 규칙(PartyButton·PartyScroll).
class_name CommandPanel
extends Control

## kind: "command"(arg 0~3) · "skill"(arg 스킬 ID) · "back" · "execute"
signal pressed(kind: String, arg: Variant)

const COMMANDS := ["attack", "skill", "guard", "escape"]
const CMD_SIZE := Vector2(160, 72)
const ROW_SIZE := Vector2(300, 64)
const BACK_SIZE := Vector2(160, 64)
const EXEC_SIZE := Vector2(320, 72)
const GAP := 8.0
const HEAD_H := 56.0

var texts: TextDb
var command_buttons: Array[BattleButton] = []
var skill_list: PartyScroll
var skill_rows: Array[PartyButton] = []
## 마지막으로 보인 스킬 목록 커서(바뀔 때만 그 줄이 보이게 맞춘다: 다시 그리기만 할 때는 끌어 내린 자리를 지킨다).
var _skill_cursor := -1
var back_button: BattleButton
var execute_button: BattleButton
## "none" / "menu" / "skills" / "target" / "confirm"
var mode := "none"
var title := ""
var subtitle := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP


func build(text_db: TextDb) -> void:
	texts = text_db
	for i in COMMANDS.size():
		var b := _button("Cmd_" + COMMANDS[i], "%d %s" % [i + 1, texts.t("battle.cmd." + COMMANDS[i])], CMD_SIZE)
		b.activated.connect(func() -> void: pressed.emit("command", i))
		command_buttons.append(b)
	back_button = _button("Back", texts.t("battle.ui.back"), BACK_SIZE)
	back_button.activated.connect(func() -> void: pressed.emit("back", null))
	execute_button = _button("Execute", texts.t("battle.ui.execute"), EXEC_SIZE)
	execute_button.font_size = 24
	execute_button.activated.connect(func() -> void: pressed.emit("execute", null))
	skill_list = PartyScroll.new()
	skill_list.name = "SkillList"
	add_child(skill_list)
	show_none()


func _button(n: String, t: String, s: Vector2) -> BattleButton:
	var b := BattleButton.new()
	b.name = n
	b.setup("", t)
	b.size = s
	b.custom_minimum_size = s
	add_child(b)
	return b


func _hide_all() -> void:
	for b in command_buttons:
		b.visible = false
		b.cancel()
	for b in skill_rows:
		b.visible = false
		b.cancel()
	skill_list.cancel()
	skill_list.visible = false
	back_button.visible = false
	back_button.cancel()
	execute_button.visible = false
	execute_button.cancel()


func show_none() -> void:
	mode = "none"
	title = ""
	subtitle = ""
	_hide_all()
	queue_redraw()


## blocked: 명령 번호 → 못 고르는 이유(흐리게 + 이유 글자).
func show_menu(member_title: String, tp_text: String, cursor: int, can_back: bool, blocked: Dictionary) -> void:
	mode = "menu"
	title = member_title
	subtitle = tp_text
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
func show_skills(member_title: String, tp_text: String, rows: Array, cursor: int) -> void:
	# 처음 열 때(다른 모드·다른 대원에서 올 때)만 맨 위로. 다시 그릴 때는 끌어 내린 자리를 지킨다.
	var opening := mode != "skills" or title != member_title
	mode = "skills"
	title = member_title
	subtitle = tp_text
	_hide_all()
	while skill_rows.size() < rows.size():
		var b := PartyButton.new()
		b.name = "Skill_%d" % skill_rows.size()
		b.size = ROW_SIZE
		b.align_left = true
		b.scroller = skill_list
		var idx := skill_rows.size()
		b.activated.connect(func() -> void: pressed.emit("skill", skill_rows[idx].get_meta("skill_id", "")))
		skill_list.content.add_child(b)
		skill_rows.append(b)
	skill_list.visible = true
	for i in rows.size():
		var b := skill_rows[i]
		b.visible = true
		b.position = Vector2(0, i * (ROW_SIZE.y + GAP))
		b.set_meta("skill_id", rows[i]["id"])
		b.show_row(rows[i]["name"], "TP %d" % int(rows[i]["tp"]), str(rows[i]["reason"]), not str(rows[i]["reason"]).is_empty())
		b.selected = i == cursor
	skill_list.set_content_height(rows.size() * (ROW_SIZE.y + GAP) - GAP)
	_show_back(true)
	_layout()
	if opening:
		skill_list.scroll_to(0.0)
	if (opening or cursor != _skill_cursor) and cursor >= 0 and cursor < rows.size():
		var top := cursor * (ROW_SIZE.y + GAP)
		skill_list.ensure_visible(top, top + ROW_SIZE.y)
	_skill_cursor = cursor


func show_target(member_title: String, prompt: String) -> void:
	mode = "target"
	title = member_title
	subtitle = prompt
	_hide_all()
	_show_back(true)
	_layout()


func show_confirm(prompt: String) -> void:
	mode = "confirm"
	title = prompt
	subtitle = ""
	_hide_all()
	execute_button.visible = true
	execute_button.selected = true
	_show_back(true)
	_layout()


func _show_back(enabled: bool) -> void:
	back_button.visible = true
	back_button.disabled = not enabled


func _layout() -> void:
	var x0 := 10.0
	var y0 := HEAD_H + 8.0
	for i in command_buttons.size():
		command_buttons[i].position = Vector2(x0 + (i % 2) * (CMD_SIZE.x + GAP), y0 + (i / 2) * (CMD_SIZE.y + GAP))
	back_button.position = Vector2(x0, size.y - BACK_SIZE.y - 8.0)
	skill_list.position = Vector2(x0 + 10.0, y0)
	skill_list.size = Vector2(ROW_SIZE.x, maxf(ROW_SIZE.y, back_button.position.y - GAP - y0))
	execute_button.position = Vector2(x0, size.y - BACK_SIZE.y - 8.0 - EXEC_SIZE.y - 16.0)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and texts != null:
		_layout()


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.09, 0.9)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.55, 0.62)
	sb.set_corner_radius_all(10)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if title.is_empty():
		return
	var font := get_theme_default_font()
	draw_string(font, Vector2(16, 30), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 21, Color(0.95, 0.98, 1.0))
	if not subtitle.is_empty():
		draw_string(font, Vector2(16, 52), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, Color(0.7, 0.85, 0.9))
