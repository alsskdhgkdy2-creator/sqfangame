## 파티 메뉴(07 §9): 미궁 화면 위에 덮는 전체 화면 층. 층 겹침(M2.6 2.5단계, research 04): 열린 동안 탐색 화면은 HUD 를 감추고
## 3D 시야만 화면 전체로 두며(DungeonScreen._hud_hidden), 메뉴는 그것을 어둡게(MENU_DIM) 하고 그 위에 「파티」 문패·대원 카드 열
## (간격을 두고 뜬다)·내용 창(탭 내용)을 띄운다. 탭 넷과 「닫기」는 내용 창 위 가장자리에
## 걸친 폴더 탭이다(트리에서 창보다 뒤: 겹친 곳을 누르면 탭이 받는다).
## 값은 규칙의 읽기 함수(GrowthRules.profile·learn_block·equip_block·sp_left 등)에서 읽고 화면이 다시 계산하지 않는다(07 §11.4).
## 상태는 규칙 함수(allocate·equip·supply·grant_exp)로만 바꾸고, 받아들여지면 save_hook(자동 저장, 07 §8.5) 뒤 changed 를 낸다.
## 스킬 배분 초안은 화면 것이라 저장하지 않는다. 메뉴를 닫으면 없어지고, 열 때는 늘 상태 탭·칸 0 대원에서 시작한다(07 §9.1).
##
## 입력 입구 하나(07 §9.4, 06 §9.5): 단추·노드·목록 줄·키보드가 모두 handle() 로 온다. 확인 창이 떠 있으면 그 창 입력만,
## 한 프레임에 입력 하나만 받는다. 문맥(탭·대원·확인 창·장비 목록)이 바뀌면 눌려 있던 포인터를 모두 버린다
## (취소된 누르기는 뗄 때 아무 일도 하지 않는다). 열린 동안 키 누름은 모두 여기서 끝난다(뒤 미궁 화면으로 가지 않는다). 뗌은 그대로 둔다.
class_name PartyMenu
extends Control

signal opened
signal closed
## 규칙 함수가 상태를 바꿨다(저장 갈고리 뒤). 탐색 화면이 상태 칸을 새로 그린다.
signal changed(events: Array)

const TOP := 80.0
## 대원 카드 열(왼쪽 여백·폭).
const MEMBER_X := 6.0
const MEMBER_W := 280.0
## 내용 창: 왼쪽(탭 내용 TAB_X 조금 앞)·위(폴더 탭이 걸친다: 탭 아래쪽 TAB_OVERLAP 만큼이 창 위에 겹친다).
const CONTENT_X := 292.0
const TAB_Y := 4.0
const TAB_OVERLAP := 20.0
const CELL_H := 120.0
const CELL_GAP := 8.0
const TAB_X := 300.0
const TAB_SIZE := Vector2(152, 64)
const TAB_GAP := 8.0
## 안내 글자(반투명 알림 띠 UiTheme.BANNER_FILL 위).
const NOTICE_TEXT := Color(1.0, 0.85, 0.55)
const CLOSE_SIZE := Vector2(112, 64)
const DIALOG_SIZE := Vector2(560, 240)
const DIALOG_BUTTON := Vector2(200, 64)
const NOTICE_SEC := 2.5
const TAB_KEYS := ["status", "skills", "equip", "items"]
## 장비 칸 이름 키(칸 0 무기, 칸 1~3 방어구).
const SLOT_KEYS := ["party.slot.weapon", "party.slot.armor", "party.slot.armor", "party.slot.armor"]

# ---- 바깥에서 정하는 값 ----
## 디버그(디버그 주소 또는 네이티브 디버그 실행): 소지품 탭에 「임시 보급(시험용)」을 보인다(07 §5.7). 열 때마다 탐색 화면이 정한다.
var debug := false
## 규칙 함수가 상태를 바꾼 직후 부른다(자동 저장).
var save_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## 0 상태 · 1 스킬 · 2 장비 · 3 소지품
var tab := 0
var member := 0
## 확인 창: "" · discard · commit
var dialog_kind := ""
## 확인 창에서 고른 단추: 0 「돌아가기」 · 1 「버리기」·「확정」
var dialog_pick := 0
var notice := ""
## 받아들인 입력 수(시험용).
var accepted_inputs := 0

# ---- 부품 ----
var tab_buttons: Array[PartyButton] = []
var close_button: PartyButton
var cells: Array[MemberCell] = []
var status_tab: PartyStatusTab
var skill_tab: PartySkillTab
var equip_tab: PartyEquipTab
var items_tab: PartyItemsTab
var tabs: Array[Control] = []
var dialog_layer: Control
var dialog_buttons: Array[PartyButton] = []
var _dialog_text := Label.new()
## 「파티」 문패(장식).
var _title := UiPlate.new()
var _notice_label := Label.new()
var _notice_left := 0.0
## 버리기 확인 창의 「버리기」 뒤에 할 일(탭·대원 바꾸기·닫기).
var _after_discard: Callable
var _built := false
var _open := false
var _input_frame := -1
var _context := ""


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 뒤의 지도·이동 단추에 포인터가 닿지 않게
	focus_mode = FOCUS_NONE
	visible = false


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	_title.name = "TitlePlate"
	_title.font_size = 24
	_title.text = texts.t("party.title")
	add_child(_title)
	for i in TAB_KEYS.size():
		var b := PartyButton.new()
		b.name = "Tab_" + TAB_KEYS[i]
		b.text = texts.t("party.tab." + TAB_KEYS[i])
		b.size = TAB_SIZE
		b.activated.connect(func() -> void: handle("tab", i))
		add_child(b)
		tab_buttons.append(b)
	close_button = PartyButton.new()
	close_button.name = "Close"
	close_button.text = texts.t("menu.close")
	close_button.size = CLOSE_SIZE
	close_button.activated.connect(func() -> void: handle("close"))
	add_child(close_button)
	_notice_label.name = "Notice"
	_notice_label.add_theme_font_size_override("font_size", 15)
	_notice_label.add_theme_color_override("font_color", NOTICE_TEXT)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.max_lines_visible = 2
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.clip_text = true
	add_child(_notice_label)
	for i in 5:
		var c := MemberCell.new()
		c.name = "Member_%d" % i
		c.size = Vector2(MEMBER_W, CELL_H)
		c.activated.connect(func() -> void: handle("member", i))
		add_child(c)
		cells.append(c)
	status_tab = PartyStatusTab.new()
	skill_tab = PartySkillTab.new()
	equip_tab = PartyEquipTab.new()
	items_tab = PartyItemsTab.new()
	tabs = [status_tab, skill_tab, equip_tab, items_tab]
	for i in tabs.size():
		var t: Control = tabs[i]
		t.name = "Tab" + TAB_KEYS[i].capitalize()
		add_child(t)
		t.call("setup", self)
	_build_dialog()
	_layout()


func _build_dialog() -> void:
	dialog_layer = Control.new()
	dialog_layer.name = "Dialog"
	dialog_layer.mouse_filter = MOUSE_FILTER_STOP  # 떠 있는 동안 뒤 화면은 포인터를 받지 않는다
	dialog_layer.visible = false
	dialog_layer.draw.connect(_draw_dialog)
	add_child(dialog_layer)
	_dialog_text.add_theme_font_size_override("font_size", 22)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_layer.add_child(_dialog_text)
	for i in 2:
		var b := PartyButton.new()
		b.name = "DialogBack" if i == 0 else "DialogOk"
		b.size = DIALOG_BUTTON
		b.activated.connect(func() -> void: handle("dialog_pick", i))
		dialog_layer.add_child(b)
		dialog_buttons.append(b)


func reason_text(code: String) -> String:
	return texts.t("growth.reason." + code)


func member_name(i: int) -> String:
	return texts.t(state.defs.party.name_keys[i])


func current_member() -> PartyState.Member:
	return state.party.members[member]


func slot_name(slot: int) -> String:
	return texts.t(SLOT_KEYS[slot], {"n": slot})


## 부호 붙은 수(글꼴 부분 집합에 U+2212 가 없어 ASCII 「-」를 쓴다).
static func signed(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	tab = 0
	member = 0
	dialog_kind = ""
	dialog_pick = 0
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	_open = true
	visible = true
	_cancel_pointers()
	_context = ""
	_layout()
	_refresh()
	opened.emit()


## 메뉴를 닫는다. 초안·열린 목록·확인 창을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_menu(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	dialog_kind = ""
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	_cancel_pointers()
	if notify:
		closed.emit()


func _cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만.
## kind: tab(0~3)·member(칸)·member_step(±1)·back·close·
##       dialog_move(±1)·dialog_pick(0·1)·dialog_ok·dialog_back·
##       스킬 탭 node(트리 칸)·node_dir(Vector2i)·plus·minus·revert·commit·
##       장비 탭 slot(0~3)·row(목록 줄)·cursor(±1)·confirm·unequip·
##       상태·소지품 탭 cursor(±1)·confirm, 소지품 supply_toggle·supply(장비 ID)·exp_100(대원)·exp_next(대원)
func handle(kind: String, arg: Variant = null) -> bool:
	if not _open:
		return false
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = frame
		accepted_inputs += 1
		_refresh()
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	if not dialog_kind.is_empty():
		match kind:
			"dialog_move":
				dialog_pick = clampi(dialog_pick + int(arg), 0, 1)
				return true
			"dialog_pick":
				return _dialog_choose(int(arg))
			"dialog_ok":
				return _dialog_choose(dialog_pick)
			"dialog_back":
				return _dialog_choose(0)
		return false
	match kind:
		"tab":
			var t := int(arg) if arg != null else -1
			if t < 0 or t >= tabs.size() or t == tab:
				return false
			_guard(func() -> void: _set_tab(t))
			return true
		"member":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= state.party.members.size() or i == member:
				return false
			_guard(func() -> void: _set_member(i))
			return true
		"member_step":
			var n := state.party.members.size()
			var to := wrapi(member + (int(arg) if arg != null else 1), 0, n)
			_guard(func() -> void: _set_member(to))
			return true
		"back":
			if tab == 2 and equip_tab.list_open:
				return equip_tab.dispatch("list_close", null)
			_guard(close_menu)
			return true
		"close":
			_guard(close_menu)
			return true
	return tabs[tab].call("dispatch", kind, arg)


## 초안이 있으면 버리기 확인 창을 띄우고 「버리기」 뒤에 action 을 한다. 없으면 바로 한다.
func _guard(action: Callable) -> void:
	if skill_tab.has_draft():
		open_dialog("discard", action)
	else:
		action.call()


func _set_tab(t: int) -> void:
	tab = t
	equip_tab.close_list()  # 다른 탭에서 돌아오면 칸 줄부터
	_layout()


func _set_member(i: int) -> void:
	member = i
	for t in tabs:
		t.call("member_changed")


func open_dialog(kind: String, after: Callable = Callable()) -> void:
	dialog_kind = kind
	dialog_pick = 0  # 처음은 늘 「돌아가기」(Enter 만 눌러도 안전한 쪽, 07 §4.6)
	_after_discard = after


func _dialog_choose(i: int) -> bool:
	if i < 0 or i > 1:
		return false
	var kind := dialog_kind
	var after := _after_discard
	dialog_kind = ""
	_after_discard = Callable()
	if i == 0:
		return true  # 「돌아가기」: 창만 닫는다(초안 그대로)
	match kind:
		"discard":
			skill_tab.clear_draft()
			if after.is_valid():
				after.call()
		"commit":
			skill_tab.commit_now()
	return true


## 키보드(07 §9.4 표, 물리 키). 열린 동안 누른 키는 모두 삼킨다: 표에 없는 키·반복·Ctrl·Alt·Meta 키는 아무것도 하지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey:
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var code := k.physical_keycode
	if not dialog_kind.is_empty():
		match code:
			KEY_LEFT:
				handle("dialog_move", -1)
			KEY_RIGHT:
				handle("dialog_move", 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				handle("dialog_ok")
			KEY_ESCAPE:
				handle("dialog_back")
		return
	if code == KEY_ESCAPE or event.is_action_pressed("open_party"):
		handle("back")
		return
	match code:
		KEY_1, KEY_2, KEY_3, KEY_4:
			handle("tab", code - KEY_1)
			return
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4:
			handle("tab", code - KEY_KP_1)
			return
		KEY_Q:
			handle("member_step", -1)
			return
		KEY_E:
			handle("member_step", 1)
			return
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	if tab == 1:
		match code:
			KEY_UP:
				handle("node_dir", Vector2i(0, -1))
			KEY_DOWN:
				handle("node_dir", Vector2i(0, 1))
			KEY_LEFT:
				handle("node_dir", Vector2i(-1, 0))
			KEY_RIGHT:
				handle("node_dir", Vector2i(1, 0))
			KEY_BACKSPACE:
				handle("minus")
			KEY_R:
				handle("revert")
			KEY_F:
				handle("commit")
		if enter:
			handle("plus")
		return
	match code:
		KEY_UP:
			handle("cursor", -1)
		KEY_DOWN:
			handle("cursor", 1)
		KEY_BACKSPACE:
			if tab == 2:
				handle("unequip")
	if enter:
		handle("confirm")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_cancel_pointers()


# ---- 규칙 결과 ----

## 규칙 함수의 이벤트 열을 받는다. 거부면 이유를 알림 줄에 띄우고 false. 받아들여졌으면 저장 갈고리 → 알림 → changed.
func apply(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(reason_text(str(events[0]["reason"])))
		return false
	if save_hook.is_valid():
		save_hook.call()
	show_notice(events_text(events))
	changed.emit(events)
	return true


## 알림 줄 글(받아들여진 성장 이벤트). 레벨업이 있으면 그 줄을 앞에.
func events_text(events: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for ev in events:
		var who := member_name(int(ev["member"])) if ev.has("member") else ""
		match str(ev["type"]):
			"level_up":
				lines.push_front(texts.t("battle.event.level_up", {"member": who, "from": ev["from"], "to": ev["to"]}))
			"exp":
				lines.append(texts.t("battle.event.exp_capped" if ev["capped"] else "battle.event.exp", {"member": who, "gained": ev["gained"]}))
			"skills_learned":
				lines.append(texts.t("growth.event.skills_learned", {"member": who, "sp_left": ev["sp_left"]}))
			"max_changed":
				lines.append(texts.t("growth.event.max_changed", {"member": who, "max_hp": ev["max_hp"], "max_tp": ev["max_tp"]}))
			"equipped":
				if str(ev["item"]).is_empty():
					lines.append(texts.t("growth.event.unequipped", {"member": who, "item": item_name(str(ev["removed"]))}))
				else:
					lines.append(texts.t("growth.event.equipped", {"member": who, "item": item_name(str(ev["item"]))}))
			"supplied":
				lines.append(texts.t("growth.event.supplied_capped" if ev["capped"] else "growth.event.supplied", {"item": item_name(str(ev["item"])), "amount": ev["amount"]}))
	return "\n".join(lines.slice(0, 2))


func item_name(id: String) -> String:
	var e := state.defs.battle.equip(id)
	return texts.t(e.name_key) if e != null else texts.t(id)


func show_notice(t: String) -> void:
	notice = t
	_notice_left = NOTICE_SEC
	_notice_label.text = t
	_notice_label.modulate.a = 1.0
	queue_redraw()


## 알림 줄을 비운다(글·남은 시간·흐림 모두): 닫았다 다시 열 때 앞 알림이 남지 않는다.
func _clear_notice() -> void:
	notice = ""
	_notice_left = 0.0
	_notice_label.text = ""
	_notice_label.modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice_label.modulate.a = clampf(_notice_left / 0.5, 0.0, 1.0)
		if _notice_left <= 0.0:
			_clear_notice()


# ---- 그리기 ----

func _refresh() -> void:
	if not _built or not _open or state == null:
		return
	# 문맥이 바뀌면(탭·대원·확인 창·장비 목록) 앞 문맥에서 시작한 누르기를 버린다: 그 손가락은 뗄 때까지 아무것도 누르지 못한다.
	var ctx := "%d|%d|%s|%s" % [tab, member, dialog_kind, tabs[tab].call("context")]
	if ctx != _context:
		_context = ctx
		_cancel_pointers()
	for i in tab_buttons.size():
		tab_buttons[i].checked = i == tab
	_refresh_cells()
	for i in tabs.size():
		(tabs[i] as Control).visible = i == tab
	tabs[tab].call("refresh")
	_refresh_dialog()
	queue_redraw()


func _refresh_cells() -> void:
	var n := state.party.members.size()
	for i in cells.size():
		var c := cells[i]
		c.visible = i < n
		if i >= n:
			continue
		var m := state.party.members[i]
		c.selected = i == member
		c.band = BattleCard.CLASS_COLORS.get(state.defs.party.class_ids[i], Color(0.7, 0.7, 0.7))
		c.member_name = member_name(i)
		c.level_text = texts.t("party.level", {"level": m.level})
		c.hp = m.hp
		c.max_hp = m.max_hp
		c.tp = m.tp
		c.max_tp = m.max_tp
		c.hp_text = texts.t("party.hp", {"hp": m.hp, "max": m.max_hp})
		c.tp_text = texts.t("party.tp", {"tp": m.tp, "max": m.max_tp})
		c.sp_text = texts.t("party.sp", {"sp": GrowthRules.sp_left(state.defs, m)}) if tab == 1 else ""
		c.queue_redraw()


func _refresh_dialog() -> void:
	dialog_layer.visible = not dialog_kind.is_empty()
	if dialog_kind.is_empty():
		return
	if dialog_kind == "discard":
		_dialog_text.text = texts.t("party.dialog.discard_text")
	else:
		_dialog_text.text = texts.t("party.dialog.commit_text", {"n": skill_tab.draft_sp()})
	dialog_buttons[0].text = texts.t("party.dialog.back")
	dialog_buttons[1].text = texts.t("party.dialog.discard" if dialog_kind == "discard" else "party.dialog.commit")
	for i in 2:
		dialog_buttons[i].selected = i == dialog_pick
		dialog_buttons[i].queue_redraw()
	dialog_layer.queue_redraw()


func dialog_rect() -> Rect2:
	return Rect2(((size - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)


func _layout() -> void:
	if not _built:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	_title.position = Vector2(MEMBER_X + 4.0, roundf((TOP - _title.size.y) / 2.0))
	for i in tab_buttons.size():
		tab_buttons[i].position = Vector2(TAB_X + i * (TAB_SIZE.x + TAB_GAP), TAB_Y)
	close_button.position = Vector2(s.x - CLOSE_SIZE.x - 8, TAB_Y)
	var nx := TAB_X + tab_buttons.size() * (TAB_SIZE.x + TAB_GAP) + 4
	_notice_label.position = Vector2(nx + 8, TAB_Y + 4)
	_notice_label.size = Vector2(maxf(0.0, close_button.position.x - 16 - nx - 8), content_rect().position.y - TAB_Y - 8)
	for i in cells.size():
		cells[i].size = Vector2(MEMBER_W, CELL_H)
		cells[i].position = Vector2(MEMBER_X, TOP + i * (CELL_H + CELL_GAP))
	for t in tabs:
		var c := t as Control
		c.position = Vector2.ZERO
		c.size = s
		c.call("place", s)
	dialog_layer.position = Vector2.ZERO
	dialog_layer.size = s
	var dr := Rect2(((s - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)
	_dialog_text.position = dr.position + Vector2(24, 20)
	_dialog_text.size = Vector2(DIALOG_SIZE.x - 48, DIALOG_SIZE.y - DIALOG_BUTTON.y - 56)
	var by := dr.end.y - DIALOG_BUTTON.y - 24
	dialog_buttons[0].position = Vector2(dr.position.x + 40, by)
	dialog_buttons[1].position = Vector2(dr.end.x - 40 - DIALOG_BUTTON.x, by)
	queue_redraw()


## 내용 창(탭 내용이 그 안에 놓인다). 위 가장자리는 폴더 탭 아래쪽에 걸친다.
func content_rect() -> Rect2:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	var top := TAB_Y + TAB_SIZE.y - TAB_OVERLAP
	return Rect2(CONTENT_X, top, s.x - CONTENT_X - 6.0, s.y - top - 6.0)


## 안내 글 뒤 띠 자리(안내가 있을 때만 그린다).
func notice_rect() -> Rect2:
	return Rect2(_notice_label.position - Vector2(8, 4), _notice_label.size + Vector2(16, 8))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.MENU_DIM)
	UiTheme.draw_window(self, content_rect())
	if not notice.is_empty() and _notice_label.visible:
		UiTheme.draw_banner(self, notice_rect())


func _draw_dialog() -> void:
	dialog_layer.draw_rect(Rect2(Vector2.ZERO, dialog_layer.size), Color(0, 0, 0, 0.6))
	UiTheme.draw_window(dialog_layer, dialog_rect())


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 단추·노드·줄 전부(확인 창이 떠 있으면 그 창 단추만). 끌어 내리는 영역 밖으로 다 나간 줄은 뺀다.
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open:
		return out
	var root_node: Node = dialog_layer if dialog_layer.visible else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		if root_node == self and dialog_layer.is_ancestor_of(b):
			continue
		if clipped_rect(b).size.y <= 0.0:
			continue
		out.append(b)
	return out


## 단추의 화면 사각형(이 메뉴 기준). 끌어 내리는 영역 안이면 그 영역으로 자른 부분.
func clipped_rect(b: Control) -> Rect2:
	var r := Rect2(b.get_global_position() - get_global_position(), b.size)
	var p := b.get_parent()
	while p != null and p != self:
		if p is PartyScroll:
			var sr := Rect2((p as Control).get_global_position() - get_global_position(), (p as Control).size)
			r = r.intersection(sr)
		p = p.get_parent()
	return r


## 디버그 요청 snapshot 의 파티 메뉴 정보(07 §8.6). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
## 단추는 보이는 부분의 가운데(끌어 내리는 영역에 반쯤 걸친 줄도 누를 수 있는 곳), 트리 노드는 스킬 ID 로도 낸다.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	var nodes := {}
	var tree := state.defs.class_of(member).tree
	for b in visible_buttons():
		var r := clipped_rect(b)
		var local := r.get_center() - (b.get_global_position() - get_global_position())
		var at: Array = css.call(local, b)
		buttons[b.name] = at
		if b is SkillNode and (b as SkillNode).index < tree.size():
			nodes[str(tree[(b as SkillNode).index]["skill"])] = at
	var rows := []
	if tab == 2 and equip_tab.list_open:
		for j in equip_tab.row_items.size():
			rows.append({"item": equip_tab.row_items[j], "block": equip_tab.row_block[j], "button": equip_tab.rows[j].name})
	return {
		"open": true, "tab": TAB_KEYS[tab], "member": member, "draft": skill_tab.draft.duplicate(),
		"cursor": {"skill": skill_tab.cursor_skill(), "slot": equip_tab.cursor, "list_open": equip_tab.list_open,
			"list_row": equip_tab.list_cursor if equip_tab.list_open else -1, "items": items_tab.cursor},
		"dialog": dialog_kind, "dialog_pick": dialog_pick, "sp_line": skill_tab._sp_label.text if tab == 1 else "",
		"notice": notice, "debug": debug, "supply_open": items_tab.supply_open, "equip_rows": rows,
		"buttons": buttons, "nodes": nodes,
	}


## 바깥(디버그 요청)이 상태를 바꿨을 때 열린 메뉴를 다시 그린다.
func refresh_view() -> void:
	_refresh()
