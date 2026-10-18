## 명령 패널(06 §9.1·§9.2): 지금 대원 이름·TP, 명령 2×2(공격·스킬·방어·도주), 패널 안에서 바뀌는 스킬 목록,
## 아래 「뒤로」와 모든 명령이 차면 「실행」. 무엇을 보일지는 전투 층이 정하고, 누르기는 모두 pressed 하나로 전투 층 입구에 보낸다.
## 스킬 목록은 「뒤로」 위까지의 끌어 내리는 목록이다(스킬이 다섯 넘게 늘어도 「뒤로」·패널 밖으로 넘치지 않는다): 줄을 끌거나
## 휠로 내리고, 키보드 커서는 그 줄이 보이게 맞춘다. 끌기와 누르기는 파티 메뉴 목록과 같은 규칙(PartyButton·PartyScroll).
## 층 겹침(M2.6 2.5단계): 창 높이는 지금 내용에 맞춘다(fit_height, 전투 층이 정한 max_height 까지). 대원 이름(title)은 창 위
## 가장자리에 걸친 문패로, 부제(TP·안내)는 창 안 맨 위 줄로 그린다.
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
## 창 안쪽 여백(아래)과 단추 묶음 사이.
const PAD := 12.0
const SECTION_GAP := 16.0
## 부제 줄 높이(부제가 있을 때만).
const SUB_H := 26.0
const PLATE_X := 16.0
const PLATE_FS := 20

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
## 전투 층이 정하는 가장 큰 창 높이(대원 카드 위 가장자리 근처까지). 내용이 더 길면 스킬 목록을 끌어 내린다.
var max_height := 452.0


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
	fit_height()


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
	fit_height()


## rows: [{id, name, tp, reason}]
func show_skills(member_title: String, tp_text: String, rows: Array, cursor: int) -> void:
	# 처음 열 때(다른 모드·다른 대원에서 올 때)만 맨 위로. 다시 그릴 때는 끌어 내린 자리를 지킨다.
	var opening := mode != "skills" or title != member_title
	var moved := cursor != _skill_cursor
	_skill_cursor = cursor
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
	fit_height(rows.size())
	if opening:
		skill_list.scroll_to(0.0)
	if opening or moved:
		_show_cursor_row()


func show_target(member_title: String, prompt: String) -> void:
	mode = "target"
	title = member_title
	subtitle = prompt
	_hide_all()
	_show_back(true)
	fit_height()


func show_confirm(prompt: String) -> void:
	mode = "confirm"
	title = prompt
	subtitle = ""
	_hide_all()
	execute_button.visible = true
	execute_button.selected = true
	_show_back(true)
	fit_height()


func _show_back(enabled: bool) -> void:
	back_button.visible = true
	back_button.disabled = not enabled


## 단추 묶음이 시작하는 높이(문패가 창 안으로 들어온 반 + 부제 줄).
func rows_top() -> float:
	return UiTheme.PLATE_H / 2.0 + 8.0 + (SUB_H if not subtitle.is_empty() else 0.0)


## 지금 모드의 내용 높이(skill_rows: 스킬 목록 줄 수).
func content_height(skill_rows: int = 0) -> float:
	var top := rows_top()
	match mode:
		"menu":
			return top + 2.0 * CMD_SIZE.y + GAP + SECTION_GAP + BACK_SIZE.y + PAD
		"skills":
			return top + maxf(1.0, skill_rows) * (ROW_SIZE.y + GAP) - GAP + SECTION_GAP + BACK_SIZE.y + PAD
		"target":
			return top + BACK_SIZE.y + PAD
		"confirm":
			return top + EXEC_SIZE.y + SECTION_GAP + BACK_SIZE.y + PAD
	return top + PAD


## 창 높이를 내용에 맞춘다(max_height 까지). 위 가장자리는 그대로(전투 층이 둔 자리).
func fit_height(skill_rows: int = 0) -> void:
	var h := minf(content_height(skill_rows), max_height)
	if absf(size.y - h) > 0.01:
		size = Vector2(size.x, h)
	_layout()


func _layout() -> void:
	var x0 := 10.0
	var y0 := rows_top()
	for i in command_buttons.size():
		command_buttons[i].position = Vector2(x0 + (i % 2) * (CMD_SIZE.x + GAP), y0 + (i / 2) * (CMD_SIZE.y + GAP))
	back_button.position = Vector2(x0, size.y - BACK_SIZE.y - PAD)
	skill_list.position = Vector2(x0 + 10.0, y0)
	var list_h := maxf(ROW_SIZE.y, back_button.position.y - SECTION_GAP - y0)
	var resized := absf(skill_list.size.y - list_h) > 0.01
	skill_list.size = Vector2(ROW_SIZE.x, list_h)
	# 목록의 보이는 높이가 바뀌면(화면 크기·창 높이가 바뀜) 커서 줄이 보이게 맞춘다. 같은 크기로 다시 그릴 때는
	# 손으로 끌어 내린 자리를 그대로 둔다(1단계 규칙).
	if resized and mode == "skills":
		_show_cursor_row()
	execute_button.position = Vector2(x0, back_button.position.y - SECTION_GAP - EXEC_SIZE.y)
	queue_redraw()


## 스킬 목록 커서 줄이 보이게 끌어 내린다(줄이 이미 다 보이면 그대로).
func _show_cursor_row() -> void:
	var visible_rows := skill_rows.filter(func(b: PartyButton) -> bool: return b.visible).size()
	if _skill_cursor < 0 or _skill_cursor >= visible_rows:
		return
	var top := _skill_cursor * (ROW_SIZE.y + GAP)
	skill_list.ensure_visible(top, top + ROW_SIZE.y)


## 이름 문패 자리(창 위 가장자리에 걸친다: 반은 창 밖). 이름이 없으면 크기 0.
func plate_rect() -> Rect2:
	if title.is_empty() or texts == null:
		return Rect2()
	var sz := UiTheme.plate_size(get_theme_default_font(), title, PLATE_FS)
	sz.x = minf(sz.x, size.x - 2.0 * PLATE_X)
	return Rect2(Vector2(PLATE_X, -UiTheme.PLATE_H / 2.0), sz)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and texts != null:
		_layout()


func _draw() -> void:
	UiTheme.draw_window(self, Rect2(Vector2.ZERO, size))
	if title.is_empty():
		return
	var font := get_theme_default_font()
	UiTheme.draw_plate(self, plate_rect(), title, PLATE_FS)
	if not subtitle.is_empty():
		draw_string(font, Vector2(16, UiTheme.PLATE_H / 2.0 + 8.0 + 18.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, UiTheme.SUB_TEXT)
