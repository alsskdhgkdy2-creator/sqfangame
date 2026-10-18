## 전투 층(06 §9): 미궁 화면 위에 덮는 전체 화면 Control. 3D 시야 크기는 바꾸지 않고 뒤를 검정 75%로 어둡게 한다.
## 상태는 규칙 함수(BattleRules)로만 바꾸고, 그리는 값은 BattleDisplay 에서 읽는다(06 §8.1).
##
## 입력 입구 하나(06 §9.5, 05 §9.3): 명령 단추·스킬 목록·대상 누르기·키보드·「실행」·「뒤로」·건너뛰기·로그·결과 확인이
## 모두 handle() 로 온다. 조건(연출 중·로그 창·결과 창·전투 단계 아님)에 맞지 않으면 버리고, 한 프레임에 입력 하나만 받는다.
## 연출 중에는 건너뛰기만 받는다(미리 받지 않는다). 전투 명령은 누르고 있기 반복이 없다.
##
## 제출 순서(06 §8.7): 「실행」 → BattleRules.submit(그 턴이 끝남) → save_hook(자동 저장) → 연출.
## 그래서 연출 중 새로고침해도 저장된 것은 그 턴이 끝난 상태다. 고르던 명령은 저장하지 않는다.
class_name BattleLayer
extends Control

signal opened
## 전투가 끝나 층이 닫혔다. outcome: victory·escaped·wiped(전멸은 결과 창 없이 바로, 06 §9.3).
signal closed(outcome: String)
## 제출이 받아들여졌다(저장 갈고리 뒤, 연출 전). 시험·디버그용.
signal submitted(events: Array)

const TOP_H := 64.0
const PANEL_W := 340.0
const PANEL_BOTTOM := 516.0
const ENEMY_BOTTOM := 420.0
const PARTY_TOP := 516.0
const LOG_BUTTON := Vector2(80, 64)
const NOTICE_SEC := 2.0
## 연출 한 단계의 길이(초, anim_speed 1). 행동 하나 약 0.6초, 독 한 번 약 0.3초(06 §9.3).
const STEP_SEC := {"action": 0.6, "failed": 0.5, "idle": 0.4, "guarding": 0.35, "poison_tick": 0.3, "turn_end": 0.15, "": 0.3}
## 새 연출 단계를 여는 이벤트. 나머지는 앞 단계에 붙는다.
const HEADS := ["action", "failed", "idle", "guarding", "poison_tick", "turn_end"]
## 상세 이벤트를 단계 안 어느 시점에 보이는지(단계 길이의 비율).
const DETAIL_AT := 0.35
## 대상을 묻지 않고 바로 확정하는 대상 규칙(06 §9.2).
const AUTO_TARGETS := ["self", "enemy_all", "ally_all"]
const REASON_KEYS := ["no_tp", "bound_head", "bound_arm", "bound_leg", "no_target", "no_escape", "unknown_skill"]
## 결과 창: 폭, 가장 작은 높이, 본문 시작(제목 아래), 본문과 「확인」 사이, 「확인」 아래 여백.
const RESULT_W := 560.0
const RESULT_MIN_H := 340.0
const RESULT_TOP := 84.0
const RESULT_GAP := 12.0
const RESULT_BOTTOM := 20.0
## 탐색 화면이 전투 중 알림 줄(저장 실패 등)을 띄우는 자리: 위 막대 바로 아래, 높이 TOAST_H. 결과 창은 이 줄 아래에 둔다.
const TOAST_Y := TOP_H + 8.0
const TOAST_H := 36.0
## 스킬 설명 칸(적 영역 아래 ~ 대원 칸 위, 스킬 목록·그 스킬의 대상 고르기 동안).
const INFO_GAP := 6.0

# ---- 바깥에서 정하는 값 ----
## 0 이면 연출을 바로 끝 상태로 맞춘다(시험).
var anim_speed := 1.0
## 디버그 주소: 로그에 판정 이유를 펼친다(06 §9.4). 디버그 끝내기("finish")도 이때만 받는다.
var debug := false
## 제출 결과가 정해진 직후, 연출 전에 부른다(자동 저장).
var save_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
var display: BattleDisplay
## closed / command / anim / result
var phase := "closed"
## 명령 단계 안: menu / skills / target / confirm
var sub := "menu"
## 지금 명령을 고르는 대원 칸(-1 = 없음: 모두 찼거나 닫힘).
var member := -1
## 대원 순서 5칸. 고르지 않았거나 명령을 받지 않는 대원은 null.
var commands: Array = []
## 키보드 커서(메뉴 0~3, 스킬 줄 번호, 대상 목록 번호).
var cursor := 0
## 대상을 고르는 중인 스킬 ID("attack" = 일반 공격).
var target_skill := ""
var target_side := ""
var target_slots: Array[int] = []
## 스킬 목록에서 대상 고르기로 왔는지(뒤로 갈 곳).
var target_from_skills := false
var outcome := ""
var end_event := {}
## 마지막으로 받아들인 제출의 이벤트 열.
var last_events: Array[Dictionary] = []
## 받아들인 입력 수(시험용).
var accepted_inputs := 0

# ---- 부품 ----
var enemy_area: EnemyArea
var party_cards: PartyCards
var panel: CommandPanel
## 스킬 설명 칸(누르기를 받지 않는다). 머리(이름·Lv·TP)와 설명 한 줄(SkillSummary).
var skill_info: Control
var skill_info_title := ""
var skill_info_text := ""
var log_button: BattleButton
var log_view: BattleLogView
var result_panel: Control
var result_ok: BattleButton
var skip_catcher: Control
var _result_title := Label.new()
var _result_body := Label.new()
## 결과 본문(넘치면 끌어 내린다, 07 §9.6).
var result_scroll: PartyScroll
## 결과 창 본문 줄(드롭·경험치·레벨업). 디버그 상태 요약도 이것을 낸다(07 §8.6).
var result_lines: Array[String] = []
var _built := false
var _input_frame := -1
var _notice := ""
var _notice_left := 0.0
var _announce := ""
## 입력 문맥(단계·명령 단계·대원·대상 스킬·로그·결과 창). 바뀌면 눌려 있던 포인터를 모두 버린다.
var _context := ""

# ---- 연출 ----
var _steps: Array[Dictionary] = []
var _step_i := 0
var _step_t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	visible = false


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	enemy_area = EnemyArea.new()
	enemy_area.name = "EnemyArea"
	add_child(enemy_area)
	party_cards = PartyCards.new()
	party_cards.name = "PartyCards"
	add_child(party_cards)
	panel = CommandPanel.new()
	panel.name = "CommandPanel"
	add_child(panel)
	panel.build(texts)
	panel.pressed.connect(_on_panel)
	skill_info = Control.new()
	skill_info.name = "SkillInfo"
	skill_info.mouse_filter = MOUSE_FILTER_IGNORE
	skill_info.visible = false
	skill_info.draw.connect(_draw_skill_info)
	add_child(skill_info)
	log_button = BattleButton.new()
	log_button.name = "LogButton"
	log_button.setup("", texts.t("battle.ui.log"))
	log_button.font_size = 18
	log_button.size = LOG_BUTTON
	add_child(log_button)
	log_button.activated.connect(func() -> void: handle("log"))
	log_view = BattleLogView.new()
	log_view.name = "BattleLog"
	add_child(log_view)
	log_view.build(texts)
	log_view.close_requested.connect(func() -> void: handle("log_close"))
	_build_result()
	skip_catcher = Control.new()
	skip_catcher.name = "SkipCatcher"
	skip_catcher.mouse_filter = MOUSE_FILTER_STOP
	skip_catcher.visible = false
	skip_catcher.gui_input.connect(_on_catcher_input)
	add_child(skip_catcher)
	_layout()


func _build_result() -> void:
	result_panel = Control.new()
	result_panel.name = "ResultPanel"
	result_panel.mouse_filter = MOUSE_FILTER_STOP
	result_panel.visible = false
	result_panel.draw.connect(func() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.07, 0.1, 0.97)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.3, 0.8, 0.9)
		sb.set_corner_radius_all(12)
		result_panel.draw_style_box(sb, Rect2(Vector2.ZERO, result_panel.size)))
	add_child(result_panel)
	_result_title.add_theme_font_size_override("font_size", 30)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel.add_child(_result_title)
	result_scroll = PartyScroll.new()
	result_scroll.name = "ResultBody"
	result_panel.add_child(result_scroll)
	_result_body.add_theme_font_size_override("font_size", 20)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.mouse_filter = MOUSE_FILTER_IGNORE
	result_scroll.content.add_child(_result_body)
	result_ok = BattleButton.new()
	result_ok.name = "ResultOk"
	result_ok.setup("", texts.t("ui.ok"))
	result_ok.size = Vector2(240, 64)
	result_panel.add_child(result_ok)
	result_ok.activated.connect(func() -> void: handle("result_ok"))


# ---- 열기·닫기 ----

func is_open() -> bool:
	return phase != "closed"


## 연출 중인지.
func is_busy() -> bool:
	return phase == "anim"


## 전투 중인 상태로 층을 연다. 늘 그 턴 명령 입력 처음에서 시작한다(06 §8.7: 고르던 명령은 저장하지 않는다).
func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null or s.battle == null:
		return
	state = s
	display = BattleDisplay.from_state(s, texts)
	enemy_area.setup(display)
	party_cards.setup(display, s.defs.party.class_ids)
	for c in _all_cards():
		c.activated.connect(_on_card.bind(c.unit_ref))
		c.snap()
	log_view.clear()
	log_view.close()
	result_panel.visible = false
	skip_catcher.visible = false
	outcome = ""
	end_event = {}
	last_events.clear()
	result_lines.clear()
	_steps.clear()
	_notice = ""
	_announce = ""
	visible = true
	phase = "command"
	_cancel_pointers()
	_begin_turn()
	if s.battle.turn == 0:
		_show_notice(texts.t("msg.encounter"))
	_layout()
	opened.emit()


## 층을 닫는다(전투 끝). 결과 창·연출을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_layer(notify: bool = true) -> void:
	if phase == "closed":
		return
	phase = "closed"
	visible = false
	skip_catcher.visible = false
	result_panel.visible = false
	log_view.close()
	_cancel_pointers()
	if notify:
		closed.emit(outcome)


func _cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만.
## kind: command(0~3)·skill(ID)·target({side, slot})·cursor(±1)·target_cursor(±1)·confirm·back·execute·log·log_close·
##       skip·result_ok·commands(명령 배열: 디버그 자동 명령, 같은 조건으로 제출)
func handle(kind: String, arg: Variant = null) -> bool:
	if phase == "closed":
		return false
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = frame
		accepted_inputs += 1
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	match phase:
		"anim":
			if kind == "skip" or kind == "confirm":
				_skip()
				return true
			return false
		"result":
			if kind == "result_ok" or kind == "confirm":
				close_layer()
				return true
			return false
	# 명령 단계
	if log_view.visible:
		match kind:
			"log", "log_close", "back":
				log_view.close()
				_refresh()
				return true
			"cursor":
				log_view.scroll_by(int(arg))
				return true
		return false
	match kind:
		"log":
			log_view.open(status_text())
			_refresh()
			return true
		"command":
			return _choose_command(int(arg))
		"skill":
			return _choose_skill(str(arg))
		"target":
			return _choose_target(arg)
		"cursor":
			return _move_cursor(int(arg))
		"target_cursor":
			return _move_target_cursor(int(arg))
		"confirm":
			return _confirm()
		"back":
			return _back()
		"execute":
			if sub != "confirm":
				return false
			_submit()
			return true
		"commands":
			if typeof(arg) != TYPE_ARRAY:
				return false
			commands = (arg as Array).duplicate(true)
			_submit()
			return true
		"finish":
			return _debug_finish(str(arg) if arg != null else "victory")
	return false


func _on_panel(kind: String, arg: Variant) -> void:
	handle(kind, arg)


func _on_card(r: Dictionary) -> void:
	handle("target", r)


## 연출 중 화면 아무 곳 누르기 = 건너뛰기. 흉내 낸 마우스는 버린다(원래 터치와 두 번 처리하지 않는다).
func _on_catcher_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if (ev as InputEventScreenTouch).pressed:
			handle("skip")
		skip_catcher.accept_event()
	elif ev is InputEventMouseButton:
		var m := ev as InputEventMouseButton
		if m.pressed and m.device != InputEvent.DEVICE_ID_EMULATION and m.button_index == MOUSE_BUTTON_LEFT:
			handle("skip")
		skip_catcher.accept_event()


## 키보드(06 §9.2): 1~4 명령, ↑↓ 목록, ←→ 대상, Enter·Space 확정·실행·건너뛰기, Esc·Backspace 뒤로, L 로그. 물리 키.
## 층이 열려 있으면 누른 키는 모두 여기서 끝난다(뒤 미궁 화면의 이동·메뉴·조사로 가지 않는다). 떼기는 그대로 둔다.
func _unhandled_input(event: InputEvent) -> void:
	if phase == "closed" or not event is InputEventKey:
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	match k.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			handle("command", k.physical_keycode - KEY_1)
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4:
			handle("command", k.physical_keycode - KEY_KP_1)
		KEY_UP:
			handle("cursor", -1)
		KEY_DOWN:
			handle("cursor", 1)
		KEY_LEFT:
			handle("target_cursor", -1)
		KEY_RIGHT:
			handle("target_cursor", 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			handle("confirm")
		KEY_ESCAPE, KEY_BACKSPACE:
			handle("back")
		KEY_L:
			handle("log")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_cancel_pointers()


# ---- 명령 고르기 (06 §9.2) ----

func _begin_turn() -> void:
	commands.clear()
	for i in state.battle.party.size():
		commands.append(null)
	member = _next_commandable(0)
	sub = "menu" if member >= 0 else "confirm"
	cursor = 0
	target_skill = ""
	_refresh()


func _next_commandable(from: int) -> int:
	for i in range(from, state.battle.party.size()):
		if BattleRules.can_command(state, i):
			return i
	return -1


func _prev_commandable(before: int) -> int:
	for i in range(mini(before, state.battle.party.size()) - 1, -1, -1):
		if BattleRules.can_command(state, i):
			return i
	return -1


func _choose_command(i: int) -> bool:
	if sub != "menu" or i < 0 or i > 3:
		return false
	match i:
		0:
			var why := BattleRules.skill_block_reason(state, member, "attack")
			if not why.is_empty():
				_show_notice(_reason_text(why))
				return true
			_enter_target("attack", false)
		1:
			sub = "skills"
			cursor = 0
			_refresh()
		2:
			commands[member] = {"kind": "guard"}
			_advance()
		3:
			var why := BattleRules.escape_block_reason(state, member)
			if not why.is_empty():
				_show_notice(_reason_text(why))
				return true
			commands[member] = {"kind": "escape"}
			_advance()
	return true


func _skill_ids() -> Array[String]:
	var out: Array[String] = []
	if member < 0:
		return out
	for sid in state.battle.party[member].skills:
		out.append(str(sid))
	return out


func _choose_skill(sid: String) -> bool:
	if sub != "skills" or not _skill_ids().has(sid):
		return false
	# 누른 줄로 커서를 옮긴다: 못 쓰는 스킬이어도 설명 칸이 그 스킬을 보이고 이유를 알린다(이어서 Enter 는 같은 줄).
	cursor = _skill_ids().find(sid)
	var why := BattleRules.skill_block_reason(state, member, sid)
	if not why.is_empty():
		_refresh()
		_show_notice(_reason_text(why))
		return true
	var s := BattleRules.skill_of(state, member, sid)
	if AUTO_TARGETS.has(s.target):
		commands[member] = {"kind": "skill", "skill": sid}
		_advance()
	else:
		_enter_target(sid, true)
	return true


func _enter_target(sid: String, from_skills: bool) -> void:
	var u := state.battle.party[member]
	var s := BattleRules.skill_of(state, member, sid)
	target_skill = sid
	target_from_skills = from_skills
	target_side = BattleRules.target_side(u, s)
	target_slots = BattleRules.valid_targets(state, member, sid)
	sub = "target"
	cursor = 0
	_refresh()


func _choose_target(r: Variant) -> bool:
	if sub != "target" or typeof(r) != TYPE_DICTIONARY:
		return false
	if r.get("side") != target_side:
		return false
	var slot := int(r.get("slot", -1))
	if not target_slots.has(slot):
		var du := display.unit(r)
		if du != null and (du.alive() or target_side == BattleUnit.PARTY):
			_show_notice(texts.t("battle.reason.unreachable" if target_side == BattleUnit.ENEMY else "battle.reason.not_target"))
			return true
		return false
	if target_skill == "attack":
		commands[member] = {"kind": "attack", "target": slot}
	else:
		commands[member] = {"kind": "skill", "skill": target_skill, "target": slot}
	_advance()
	return true


func _advance() -> void:
	member = _next_commandable(member + 1)
	sub = "menu" if member >= 0 else "confirm"
	cursor = 0
	target_skill = ""
	_refresh()


func _back() -> bool:
	match sub:
		"target":
			sub = "skills" if target_from_skills else "menu"
			cursor = maxi(0, _skill_ids().find(target_skill)) if target_from_skills else 0
			target_skill = ""
		"skills":
			sub = "menu"
			cursor = 1
		"menu", "confirm":
			var prev := _prev_commandable(member if sub == "menu" else state.battle.party.size())
			if prev < 0:
				return false
			commands[prev] = null
			member = prev
			sub = "menu"
			cursor = 0
	_refresh()
	return true


func _confirm() -> bool:
	match sub:
		"menu":
			return _choose_command(cursor)
		"skills":
			var ids := _skill_ids()
			return _choose_skill(ids[cursor]) if cursor < ids.size() else false
		"target":
			if target_slots.is_empty():
				return false
			return _choose_target({"side": target_side, "slot": target_slots[cursor]})
		"confirm":
			_submit()
			return true
	return false


func _move_cursor(d: int) -> bool:
	match sub:
		"menu":
			cursor = wrapi(cursor + d, 0, 4)
		"skills":
			var n := _skill_ids().size()
			if n == 0:
				return false
			cursor = wrapi(cursor + d, 0, n)
		_:
			return false
	_refresh()
	return true


func _move_target_cursor(d: int) -> bool:
	if sub != "target" or target_slots.is_empty():
		return false
	cursor = wrapi(cursor + d, 0, target_slots.size())
	_refresh()
	return true


func _reason_text(code: String) -> String:
	return texts.t("battle.reason." + code) if REASON_KEYS.has(code) else code


func _show_notice(t: String) -> void:
	_notice = t
	_notice_left = NOTICE_SEC
	queue_redraw()


# ---- 제출 (06 §8.7) ----

func _submit() -> void:
	var events := BattleRules.submit(state, commands.duplicate(true))
	if events.size() == 1 and events[0]["type"] == "rejected":
		_show_notice(texts.t("battle.ui.rejected", {"reason": str(events[0].get("reason", ""))}))
		_begin_turn()
		return
	_commit(events)


## 디버그 주소에서만(웹 확인의 battle_finish): 지금 전투를 규칙의 finish 로 끝내고 제출과 같은 길(저장 → 연출 → 결과 창)로 보인다.
## 전투 승패(밸런스)와 상관없이 전투를 넘기는 확인용. 규칙이 거부하면(전멸이 아닌데 wiped 등) false.
func _debug_finish(how: String) -> bool:
	if not debug:
		return false
	var events: Array[Dictionary] = []
	if not BattleRules.finish(state, how, events):
		return false
	_commit(events)
	return true


## 결과가 정해진 이벤트 열(제출·디버그 끝내기): 연출보다 먼저 저장한다(연출 중 새로고침해도 같은 결과).
func _commit(events: Array[Dictionary]) -> void:
	last_events = events
	if save_hook.is_valid():
		save_hook.call()
	submitted.emit(events)
	_start_anim(events)


# ---- 연출 (06 §9.3) ----

func _start_anim(events: Array[Dictionary]) -> void:
	phase = "anim"
	member = -1
	_cancel_pointers()
	_steps = _make_steps(events)
	_step_i = 0
	_step_t = 0.0
	_announce = ""
	_notice = ""
	skip_catcher.visible = true
	_refresh()
	if anim_speed <= 0.0:
		_skip()


static func _make_steps(events: Array[Dictionary]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for ev in events:
		var t: String = ev["type"]
		var merge_guard: bool = t == "guarding" and not steps.is_empty() and steps[-1]["head"].get("type") == "guarding"
		if HEADS.has(t) and not merge_guard:
			steps.append({"head": ev, "details": [], "started": false, "applied": false, "dur": float(STEP_SEC.get(t, 0.3))})
		elif steps.is_empty():
			steps.append({"head": {}, "details": [ev], "started": false, "applied": false, "dur": float(STEP_SEC[""])})
		else:
			steps[-1]["details"].append(ev)
	return steps


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
			queue_redraw()
	if phase != "anim":
		return
	_step_t += delta * anim_speed
	var guard := 0
	while phase == "anim" and _step_i < _steps.size() and guard < 64:
		guard += 1
		var st: Dictionary = _steps[_step_i]
		if not st["started"]:
			_begin_step(st, true)
		if not st["applied"] and _step_t >= st["dur"] * DETAIL_AT:
			_apply_details(st, true)
		if _step_t < st["dur"]:
			break
		_step_t -= st["dur"]
		_step_i += 1
	if phase == "anim" and _step_i >= _steps.size():
		_end_anim()


func _begin_step(st: Dictionary, animate: bool) -> void:
	st["started"] = true
	var head: Dictionary = st["head"]
	if head.is_empty():
		return
	display.apply(head)
	_log(head)
	var line := display.describe(head)
	if not line.is_empty() and head["type"] != "turn_end":
		_announce = line
	if animate:
		var who: Variant = head.get("unit", head.get("target"))
		var c := _card_of(who)
		if c != null:
			c.flash = 1.0
		if head["type"] == "poison_tick" and c != null:
			c.pop(str(head["amount"]), Color(0.95, 0.72, 1.0))
	_refresh_cards()
	queue_redraw()


func _apply_details(st: Dictionary, animate: bool) -> void:
	st["applied"] = true
	for ev in st["details"]:
		display.apply(ev)
		_log(ev)
		if animate:
			_popup_for(ev)
	_refresh_cards()


func _popup_for(ev: Dictionary) -> void:
	var c := _card_of(ev.get("target"))
	if c == null:
		return
	match str(ev["type"]):
		"damaged":
			if ev.get("immune", false):
				c.pop(texts.t("battle.popup.immune"), Color(0.9, 0.9, 0.9))
				return
			var party_hit: bool = ev["target"]["side"] == BattleUnit.PARTY
			var subs: Array[String] = []
			if ev.get("weak", false):
				subs.append(texts.t("battle.popup.weak"))
			if ev.get("crit", false):
				subs.append(texts.t("battle.popup.crit"))
			c.pop(str(ev["amount"]), Color(1.0, 0.62, 0.5) if party_hit else Color(1.0, 1.0, 0.92), " ".join(subs))
		"missed":
			c.pop(texts.t("battle.popup.miss"), Color(0.88, 0.92, 0.96))
		"healed", "revived":
			c.pop("+" + str(ev.get("amount", ev.get("hp", 0))), Color(0.55, 1.0, 0.62))


## 남은 연출을 끝 상태로 바로 맞춘다.
func _skip() -> void:
	while _step_i < _steps.size():
		var st: Dictionary = _steps[_step_i]
		if not st["started"]:
			_begin_step(st, false)
		if not st["applied"]:
			_apply_details(st, false)
		_step_i += 1
	for c in _all_cards():
		c.snap()
	_end_anim()


func _end_anim() -> void:
	skip_catcher.visible = false
	_announce = ""
	end_event = {}
	for ev in last_events:
		if ev["type"] == "battle_end":
			end_event = ev
	for c in _all_cards():
		c.snap()
	if end_event.is_empty():
		display.sync(state)
		phase = "command"
		_begin_turn()
		for c in _all_cards():
			c.snap()
		return
	outcome = str(end_event["outcome"])
	if outcome == "wiped":
		close_layer()
		return
	phase = "result"
	_show_result()


func _show_result() -> void:
	var lines: Array[String] = []
	if outcome == "victory":
		_result_title.text = texts.t("battle.result.victory")
		var drops: Array = end_event.get("drops", [])
		if drops.is_empty():
			lines.append(texts.t("battle.result.no_drops"))
		else:
			lines.append(texts.t("battle.result.drops"))
			# 같은 소재는 한 줄로 모은다(드롭은 한 번에 1개씩, 06 §3.17).
			var order: Array[String] = []
			var sums := {}
			var capped := {}
			for d in drops:
				var item := str(d["item"])
				if not sums.has(item):
					order.append(item)
					sums[item] = 0
				sums[item] += int(d["amount"])
				if d.get("capped", false):
					capped[item] = true
			for item in order:
				var line := texts.t("battle.result.drop", {"item": texts.t(item), "n": sums[item]}) if sums[item] > 0 else ""
				if capped.has(item):
					line = texts.t("battle.result.drop_capped", {"item": texts.t(item)}) if line.is_empty() else line + " " + texts.t("battle.result.capped")
				lines.append(line)
		lines.append_array(growth_lines(end_event))
	elif end_event.get("reason", "") == "turn_cap":
		_result_title.text = texts.t("battle.result.ended")
		lines.append(texts.t("battle.result.turn_cap"))
	else:
		_result_title.text = texts.t("battle.result.escaped")
		lines.append(texts.t("battle.event.escaped"))
	result_lines = lines
	_result_body.text = "\n".join(lines)
	result_scroll.scroll_to(0.0)
	result_panel.visible = true
	panel.show_none()
	_cancel_pointers()
	_layout()
	_refresh()


## 승리 battle_end 의 경험치·레벨업 줄(07 §3.5). 성장 필드가 없거나(도주·전멸·턴 상한) exp_total 이 0 이면 경험치 줄이 없다.
## 모두 받았고 같은 양·상한 없음이면 「경험치 +7」 한 줄, 그 밖에는 머리 「경험치」 아래 대원마다 한 줄(칸 순).
## 레벨이 오른 대원이 있으면 머리 「레벨 업」 아래 그 대원마다 「Lv 1 → 2  SP +1」.
func growth_lines(end_ev: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rows: Array = end_ev.get("members", [])
	if int(end_ev.get("exp_total", 0)) <= 0 or rows.is_empty():
		return out
	var same := true
	for r in rows:
		if r["status"] != "received" or r["capped"] or int(r["gained"]) != int(rows[0]["gained"]):
			same = false
	if same:
		out.append(texts.t("battle.result.exp", {"n": rows[0]["gained"]}))
	else:
		out.append(texts.t("battle.result.exp_head"))
		for r in rows:
			var who := _member_name(int(r["member"]))
			match str(r["status"]):
				"down":
					out.append(texts.t("battle.result.exp_down", {"member": who}))
				"at_cap":
					out.append(texts.t("battle.result.exp_at_cap", {"member": who}))
				_:
					var key := "battle.result.exp_member_capped" if r["capped"] else "battle.result.exp_member"
					out.append(texts.t(key, {"member": who, "n": r["gained"]}))
	var head := true
	for r in rows:
		if int(r["to"]) > int(r["from"]):
			if head:
				out.append(texts.t("battle.result.level_up_head"))
				head = false
			var args := {"member": _member_name(int(r["member"])), "from": r["from"], "to": r["to"], "sp": r["sp_gained"]}
			out.append(texts.t("battle.result.level_up_sp" if int(r["sp_gained"]) > 0 else "battle.result.level_up", args))
	return out


func _member_name(i: int) -> String:
	return texts.t(state.defs.party.name_keys[i]) if state != null and i < state.defs.party.name_keys.size() else str(i)


func _log(ev: Dictionary) -> void:
	var line := display.describe(ev)
	if line.is_empty():
		return
	if debug:
		var d := BattleDisplay.debug_detail(ev)
		if not d.is_empty():
			line += "\n    [" + d + "]"
	log_view.add_line(line)


# ---- 그리기 상태 ----

func _all_cards() -> Array[BattleCard]:
	var out: Array[BattleCard] = []
	if enemy_area != null:
		out.append_array(enemy_area.cards)
	if party_cards != null:
		out.append_array(party_cards.cards)
	return out


func _card_of(r: Variant) -> BattleCard:
	if typeof(r) != TYPE_DICTIONARY:
		return null
	var slot := int(r.get("slot", -1))
	return enemy_area.card(slot) if r.get("side") == BattleUnit.ENEMY else party_cards.card(slot)


func _refresh() -> void:
	if not _built or display == null:
		return
	# 문맥이 바뀌면(로그 열기·닫기, 대상·대원·단계 전환, 연출 시작·끝, 결과 창) 앞 문맥에서 시작한 누르기를 버린다:
	# 그 손가락은 뗄 때까지 아무 단추·칸도 누르지 못한다(누른 때와 뗀 때의 문맥이 같아야 한다).
	var ctx := "%s|%s|%d|%s|%s|%s" % [phase, sub, member, target_skill, str(log_view.visible), str(result_panel.visible)]
	if ctx != _context:
		_context = ctx
		_cancel_pointers()
	_refresh_cards()
	_refresh_panel()
	_refresh_skill_info()
	queue_redraw()


func _refresh_cards() -> void:
	var lit_row := ""
	var row_target := false
	if sub == "target" and phase == "command" and not target_slots.is_empty():
		var s := BattleRules.skill_of(state, member, target_skill)
		row_target = s != null and s.target.ends_with("_row")
		if row_target:
			lit_row = display.effective_row(display.unit({"side": target_side, "slot": target_slots[cursor]}))
	for c in _all_cards():
		var u := c.unit()
		c.cursor = false
		c.reason = ""
		var mark := ""
		if sub == "target" and phase == "command" and c.unit_ref["side"] == target_side:
			if target_slots.has(c.unit_ref["slot"]):
				mark = "valid"
				if row_target and display.effective_row(u) == lit_row:
					mark = "lit"
				c.cursor = target_slots[cursor] == c.unit_ref["slot"]
			elif u.alive() or target_side == BattleUnit.PARTY:
				mark = "invalid"
				c.reason = texts.t("battle.reason.unreachable" if target_side == BattleUnit.ENEMY else "battle.reason.not_target")
		c.target_mark = mark
		c.mouse_filter = MOUSE_FILTER_STOP if (u.alive() or not c.is_enemy()) else MOUSE_FILTER_IGNORE
		# 칸은 대상 고르기 중(로그 창이 닫혀 있고 그 편이 대상 쪽)에만 누르기를 받는다.
		c.disabled = not (phase == "command" and sub == "target" and not log_view.visible and c.unit_ref["side"] == target_side)
		if not c.is_enemy():
			var i: int = c.unit_ref["slot"]
			c.current = phase == "command" and i == member
			c.command_text = _command_label(commands[i]) if phase == "command" and i < commands.size() else ""
		c.queue_redraw()
	party_cards.queue_redraw()


func _command_label(c: Variant) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return ""
	match str(c["kind"]):
		"attack":
			return texts.t("battle.cmd.attack")
		"guard":
			return texts.t("battle.cmd.guard")
		"escape":
			return texts.t("battle.cmd.escape")
		"skill":
			return texts.t(str(c["skill"]))
	return ""


func _refresh_panel() -> void:
	panel.visible = phase == "command"
	if phase != "command":
		panel.show_none()
		return
	if sub == "confirm":
		panel.show_confirm(texts.t("battle.ui.ready"))
		return
	var u := display.party[member]
	var title := u.name
	var tp_text := "TP %d/%d" % [u.tp, u.max_tp]
	match sub:
		"menu":
			var blocked := {}
			var why := BattleRules.skill_block_reason(state, member, "attack")
			if not why.is_empty():
				blocked[0] = _reason_text(why)
			why = BattleRules.escape_block_reason(state, member)
			if not why.is_empty():
				blocked[3] = _reason_text(why)
			panel.show_menu(title, tp_text, cursor, _prev_commandable(member) >= 0, blocked)
		"skills":
			var rows := []
			for sid in _skill_ids():
				var s := BattleRules.skill_of(state, member, sid)
				var why := BattleRules.skill_block_reason(state, member, sid)
				rows.append({"id": sid, "name": texts.t(s.name_key), "tp": BattleRules.tp_cost(state.battle.party[member], s),
					"reason": _reason_text(why) if not why.is_empty() else ""})
			panel.show_skills(title, tp_text, rows, cursor)
		"target":
			panel.show_target(title, texts.t("battle.ui.choose_target", {"skill": display.skill_name(target_skill)}))


## 스킬 목록에서 커서가 있는 스킬, 또는 목록에서 고른 스킬의 대상 고르기 동안 그 스킬 설명(06 §9.2, M2.6 U2).
## 숫자는 SkillSummary 가 스킬 정의에서 읽는다. 로그 창이 열리면 감춘다(같은 자리를 덮는다).
func _refresh_skill_info() -> void:
	var sid := ""
	if phase == "command" and not log_view.visible:
		if sub == "skills":
			var ids := _skill_ids()
			if cursor >= 0 and cursor < ids.size():
				sid = ids[cursor]
		elif sub == "target" and target_from_skills:
			sid = target_skill
	skill_info.visible = not sid.is_empty()
	if sid.is_empty():
		skill_info_title = ""
		skill_info_text = ""
		return
	var s := BattleRules.skill_of(state, member, sid)
	var level := int(state.battle.party[member].skills.get(sid, 1))
	skill_info_title = SkillSummary.head(texts, s, level)
	skill_info_text = SkillSummary.line(texts, s, level)
	skill_info.queue_redraw()


func _draw_skill_info() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.09, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.55, 0.62)
	sb.set_corner_radius_all(10)
	skill_info.draw_style_box(sb, Rect2(Vector2.ZERO, skill_info.size))
	var font := get_theme_default_font()
	var w := skill_info.size.x - 32.0
	skill_info.draw_string(font, Vector2(16, 30), skill_info_title, HORIZONTAL_ALIGNMENT_LEFT, w, 19, Color(1.0, 0.88, 0.5))
	skill_info.draw_multiline_string(font, Vector2(16, 58), skill_info_text, HORIZONTAL_ALIGNMENT_LEFT, w, 17, 2, Color(0.88, 0.95, 1.0))


func _layout() -> void:
	if not _built:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	var left_w := s.x - PANEL_W
	enemy_area.position = Vector2(0, TOP_H)
	enemy_area.size = Vector2(left_w, ENEMY_BOTTOM - TOP_H)
	panel.position = Vector2(left_w, TOP_H)
	panel.size = Vector2(PANEL_W, PANEL_BOTTOM - TOP_H)
	skill_info.position = Vector2(16, ENEMY_BOTTOM + INFO_GAP)
	skill_info.size = Vector2(left_w - 32, PARTY_TOP - ENEMY_BOTTOM - 2.0 * INFO_GAP)
	party_cards.position = Vector2(0, PARTY_TOP)
	party_cards.size = Vector2(s.x, s.y - PARTY_TOP)
	log_button.position = Vector2(s.x - LOG_BUTTON.x, 0)
	log_view.position = Vector2(16, TOP_H + 8)
	log_view.size = Vector2(s.x - 32, PANEL_BOTTOM - TOP_H - 8)
	# 결과 창: 본문 줄이 많으면 높이를 늘리되 알림 줄 아래부터 화면 아래 8 안에 둔다(알림 줄과 위 막대를 가리지 않는다).
	# 그래도 넘치면 본문을 끌어 내린다(07 §9.6).
	var body_w := RESULT_W - 40.0
	_result_body.size = Vector2(body_w, _result_body.size.y)
	var body_h := maxf(1.0, _result_body.get_line_count()) * (_result_body.get_line_height() + _result_body.get_theme_constant("line_spacing"))
	var chrome := RESULT_TOP + RESULT_GAP + result_ok.size.y + RESULT_BOTTOM
	var clear_top := TOAST_Y + TOAST_H + 4.0
	var rp := Vector2(RESULT_W, clampf(chrome + body_h, RESULT_MIN_H, maxf(RESULT_MIN_H, s.y - 8.0 - clear_top)))
	result_panel.size = rp
	var py := roundf((PARTY_TOP - rp.y) / 2.0 + TOP_H / 2.0)
	var low := maxf(8.0, s.y - 8.0 - rp.y)
	result_panel.position = Vector2(roundf((s.x - rp.x) / 2.0), clampf(py, minf(clear_top, low), low))
	_result_title.position = Vector2(20, 24)
	_result_title.size = Vector2(rp.x - 40, 44)
	result_scroll.position = Vector2(20, RESULT_TOP)
	result_scroll.size = Vector2(body_w, rp.y - chrome)
	_result_body.position = Vector2.ZERO
	_result_body.size = Vector2(body_w, body_h)
	result_scroll.set_content_height(body_h)
	result_ok.position = Vector2((rp.x - result_ok.size.x) / 2.0, rp.y - result_ok.size.y - RESULT_BOTTOM)
	skip_catcher.position = Vector2.ZERO
	skip_catcher.size = s
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(0, 0, size.x, TOP_H), Color(0.02, 0.04, 0.06, 0.92))
	draw_line(Vector2(0, TOP_H), Vector2(size.x, TOP_H), Color(0.25, 0.55, 0.62), 1.0)
	if display == null:
		return
	var font := get_theme_default_font()
	draw_string(font, Vector2(20, 42), texts.t("battle.ui.turn", {"n": display.turn + 1}), HORIZONTAL_ALIGNMENT_LEFT, 140, 24, Color(0.9, 0.97, 1.0))
	var line := _announce if phase == "anim" else _notice
	if not line.is_empty():
		var col := Color(1.0, 0.95, 0.7) if phase == "anim" else Color(1.0, 0.7, 0.5)
		draw_string(font, Vector2(150, 42), line, HORIZONTAL_ALIGNMENT_CENTER, size.x - 150 - LOG_BUTTON.x - 20, 22, col)


## 로그 창 위에 보이는 지금 상태 전부(06 §9.1 상태 표의 전체 보기). 적 HP 숫자는 쓰지 않는다(D13).
func status_text() -> String:
	var lines: Array[String] = []
	for u in display.party + display.enemies:
		var parts: Array[String] = [u.name]
		if u.side == BattleUnit.PARTY:
			parts.append("HP %d/%d  TP %d/%d" % [u.hp, u.max_hp, u.tp, u.max_tp])
		if not u.alive():
			parts.append(texts.t("battle.ui.down"))
		for c in display.chips(u):
			var mark := "↑" if c["kind"] == "buff" else "↓" if c["kind"] == "debuff" else ""
			parts.append(mark + str(c["text"]))
		if not u.charging.is_empty():
			parts.append("! " + display.skill_name(u.charging))
		lines.append(" · ".join(parts))
	return "\n".join(lines)


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 전투 층 단추 전부(로그 창·결과 창이 덮은 단추는 빼고, 연출 중이면 없음).
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if phase == "anim" or phase == "closed":
		return out
	var root_node: Node = self
	if result_panel.visible:
		root_node = result_panel
	elif log_view.visible:
		root_node = log_view
		out.append(log_button)
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.is_visible_in_tree() and b.mouse_filter != MOUSE_FILTER_IGNORE and not out.has(b):
			# 스킬 목록 줄은 목록 안에 다 보일 때만(잘려 안 보이는 줄의 가운데는 다른 것 위다)
			if b is PartyButton and (b as PartyButton).scroller != null and not (b as PartyButton).scroller.shows(Rect2(b.position, b.size)):
				continue
			out.append(b)
	return out


## 디버그 요청 snapshot 의 전투 정보(06 §8.9). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
func debug_info(css: Callable) -> Dictionary:
	if phase == "closed" or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	var enemy_hp := []
	var charging := []
	if state.battle != null:
		for u in state.battle.enemies:
			enemy_hp.append(u.hp)
			charging.append(u.charging)
	return {"open": true, "phase": phase, "sub": sub, "member": member, "turn": display.turn,
		"targets": target_slots if sub == "target" else [], "target_side": target_side if sub == "target" else "",
		"enemy_hp": enemy_hp, "charging": charging, "log": log_view.visible, "log_lines": log_view.lines.size(), "outcome": outcome,
		"result_lines": result_lines if phase == "result" else [], "panel": panel.visible,
		"skill_info": [skill_info_title, skill_info_text] if skill_info.visible else [], "buttons": buttons}
