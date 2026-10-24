## 캠프 기록 화면(07 §9.1·§9.2, M2.7 R2-d: 원작 HD 불러오기 화면 gs2_653240 짜임, 1280×720 기준 실측):
## 왼쪽 위 이름 문패(원작 「Load Game」 x 0~272 · y 38~92), 오른쪽 위 「뒤로」(원작 「Ⓧ DELETE」 안내 자리),
## 가운데 슬롯 창(원작 x 170~1110 · y 105~690, 짙은 남색 창 안에 슬롯 카드 셋: 번호 칸 + 대표 이름·Lv 띠 + 줄 둘) →
## 우리 x 가운데 ±470 · y 100~594, 카드 150 높이(번호 칸, 「대표 대원 Lv n」, 「층 · 걸음」, 저장 시각, 오른쪽에 「저장」「불러오기」).
## 아래 띠(원작에 없음): 「내보내기」「가져오기」, 「자동 지도」 끔·바닥만·바닥+벽, 「새 게임」(확인 창).
## 값·일은 바깥(탐색 화면)이 menu.records 갈고리로 준다: slots·save·load·export·import·automap·set_automap·new_game.
## 키보드: ↑↓ 줄(카드 셋 + 아래 띠), ←→ 줄 안, Enter 누름. 단추를 누르면(포인터) 커서도 그 단추로.
class_name PartyRecordsTab
extends Control

const WIN_W := 940.0
const WIN_TOP := 100.0
const PAD := 14.0
const CARD_H := 150.0
const CARD_PITCH := 158.0
const NUM_W := 58.0
const SLOT_BUTTON := Vector2(150, 64)
const BAND_TOP := 602.0
const BAND_BUTTON_Y := 636.0
const WIDE_BUTTON := Vector2(150, 64)
const AUTO_BUTTON := Vector2(130, 64)
const TITLE := Rect2(0, 36, 272, 56)
const BACK_SIZE := Vector2(120, 64)

var menu: PartyMenu
## 커서(줄, 칸): 줄 0~2 = 카드(0 저장·1 불러오기), 줄 3 = 아래 띠(내보내기·가져오기·자동 지도 셋·새 게임).
var cur_row := 0
var cur_col := 0
var back_button: PartyButton
var title_plate: Control
var window: Control
var band: Control
var save_buttons: Array[PartyButton] = []
var load_buttons: Array[PartyButton] = []
var band_buttons: Array[PartyButton] = []
## 마지막으로 읽은 슬롯 정보([{slot, ok, leader, level, where, time}]).
var slots: Array = []
var _dirty := true


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	title_plate = _deco("RecordsTitle", Vector2.ZERO, Vector2.ZERO, Vector4(TITLE.position.x, TITLE.position.y, TITLE.end.x, TITLE.end.y),
		func(c: Control) -> void: UiTheme.draw_plate(c, Rect2(Vector2.ZERO, c.size), menu.texts.t("camp.cmd.records"), 26))
	var win_bottom := WIN_TOP + 2.0 * PAD + 2.0 * CARD_PITCH + CARD_H
	window = _deco("RecordsWindow", Vector2(0.5, 0), Vector2(0.5, 0), Vector4(-WIN_W / 2.0, WIN_TOP, WIN_W / 2.0, win_bottom), _draw_window)
	band = _deco("RecordsBand", Vector2(0.5, 0), Vector2(0.5, 0), Vector4(-WIN_W / 2.0 - PAD, BAND_TOP, WIN_W / 2.0 + PAD, BAND_BUTTON_Y + 64 + 10),
		_draw_band)
	for i in 3:
		var y := WIN_TOP + PAD + i * CARD_PITCH
		var x1 := WIN_W / 2.0 - PAD - 12.0
		var sb := _button("Save_" + _slot_id(i), menu.texts.t("menu.save"), "record_save", i,
			Vector4(x1 - SLOT_BUTTON.x, y + 6.0, x1, y + 6.0 + SLOT_BUTTON.y))
		save_buttons.append(sb)
		var lb := _button("Load_" + _slot_id(i), menu.texts.t("menu.load"), "record_load", i,
			Vector4(x1 - SLOT_BUTTON.x, y + 14.0 + SLOT_BUTTON.y, x1, y + 14.0 + 2.0 * SLOT_BUTTON.y))
		load_buttons.append(lb)
	var x := -WIN_W / 2.0
	var by := BAND_BUTTON_Y
	band_buttons.append(_button("Export", menu.texts.t("menu.export"), "record_export", null, Vector4(x, by, x + WIDE_BUTTON.x, by + 64)))
	x += WIDE_BUTTON.x + 12.0
	band_buttons.append(_button("Import", menu.texts.t("menu.import"), "record_import", null, Vector4(x, by, x + WIDE_BUTTON.x, by + 64)))
	x += WIDE_BUTTON.x + 24.0
	for mode in ExplorationRules.AUTOMAP_MODES:
		band_buttons.append(_button("Automap_" + mode, menu.texts.t("menu.automap." + mode), "record_automap", mode,
			Vector4(x, by, x + AUTO_BUTTON.x, by + 64)))
		x += AUTO_BUTTON.x + 8.0
	band_buttons.append(_button("NewGame", menu.texts.t("menu.new_game"), "record_new_game", null,
		Vector4(WIN_W / 2.0 - WIDE_BUTTON.x, by, WIN_W / 2.0, by + 64)))
	back_button = PartyButton.new()
	back_button.name = "RecordsBack"
	back_button.text = menu.texts.t("camp.back")
	add_child(back_button)
	PartyMenu.place(back_button, Vector2(1, 0), Vector2(1, 0), Vector4(-8 - BACK_SIZE.x, 18, -8, 18 + BACK_SIZE.y))
	back_button.activated.connect(func() -> void: menu.handle("back"))


## 슬롯 i 의 저장 이름(SaveStore 수동 슬롯).
func _slot_id(i: int) -> String:
	return SaveStore.MANUAL_SLOTS[i]


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4, painter: Callable) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	c.draw.connect(painter.bind(c))
	return c


func _button(n: String, label: String, kind: String, arg: Variant, off: Vector4) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.text = label
	b.skin = "fac"
	add_child(b)
	PartyMenu.place(b, Vector2(0.5, 0), Vector2(0.5, 0), off)
	b.set_meta("kind", kind)
	b.set_meta("arg", arg)
	b.activated.connect(func() -> void: menu.handle(kind, arg))
	return b


func reset() -> void:
	cur_row = 0
	cur_col = 0
	_dirty = true


func member_changed() -> void:
	_dirty = true


func context() -> String:
	return ""


func place(_s: Vector2) -> void:
	if menu.state != null and visible:
		refresh()


## 커서 순서의 단추 줄(줄 0~2 카드, 줄 3 아래 띠).
func grid() -> Array:
	var out := []
	for i in 3:
		out.append([save_buttons[i], load_buttons[i]])
	out.append(band_buttons)
	return out


func cursor_button() -> PartyButton:
	var g := grid()
	return g[cur_row][cur_col]


## cursor(±1 줄)·cursor_x(±1 칸)·confirm, record_save·record_load(슬롯)·record_export·record_import·record_automap(모드)·record_new_game.
func dispatch(kind: String, arg: Variant) -> bool:
	var g := grid()
	match kind:
		"cursor":
			var to := clampi(cur_row + (int(arg) if arg != null else 1), 0, g.size() - 1)
			if to == cur_row:
				return false
			# 카드(칸 둘) ↔ 아래 띠(칸 여섯): 같은 칸 번호를 잇되 줄 길이로 자른다.
			cur_row = to
			cur_col = clampi(cur_col, 0, (g[to] as Array).size() - 1)
			return true
		"cursor_x":
			var tc := clampi(cur_col + (int(arg) if arg != null else 1), 0, (g[cur_row] as Array).size() - 1)
			if tc == cur_col:
				return false
			cur_col = tc
			return true
		"confirm":
			var b := cursor_button()
			if b.disabled:
				return false
			return dispatch(str(b.get_meta("kind")), b.get_meta("arg"))
		"record_save":
			_point(save_buttons[int(arg)])
			_dirty = true
			menu.records["save"].call(_slot_id(int(arg)))
			return true
		"record_load":
			var i := int(arg)
			_point(load_buttons[i])
			if i >= slots.size() or not slots[i]["ok"]:
				return false
			menu.records["load"].call(_slot_id(i))
			return true
		"record_export":
			_point(band_buttons[0])
			menu.records["export"].call()
			return true
		"record_import":
			_point(band_buttons[1])
			menu.records["import"].call()
			return true
		"record_automap":
			var mode := str(arg)
			var k := ExplorationRules.AUTOMAP_MODES.find(mode)
			if k < 0:
				return false
			_point(band_buttons[2 + k])
			menu.records["set_automap"].call(mode)
			return true
		"record_new_game":
			_point(band_buttons[band_buttons.size() - 1])
			var start: Callable = menu.records["new_game"]
			menu.open_dialog("new_game", start)
			return true
	return false


## 포인터로 누른 단추로 커서를 옮긴다.
func _point(b: PartyButton) -> void:
	var g := grid()
	for r in g.size():
		var c := (g[r] as Array).find(b)
		if c >= 0:
			cur_row = r
			cur_col = c
			return


func refresh() -> void:
	if menu.state == null or not menu.records.has("slots"):
		return
	if _dirty:
		slots = menu.records["slots"].call()
		_dirty = false
	for i in 3:
		var ok: bool = i < slots.size() and slots[i]["ok"]
		load_buttons[i].disabled = not ok
	var mode: String = menu.records["automap"].call()
	for k in ExplorationRules.AUTOMAP_MODES.size():
		band_buttons[2 + k].checked = ExplorationRules.AUTOMAP_MODES[k] == mode
	var cb := cursor_button()
	for b in save_buttons + load_buttons + band_buttons:
		(b as PartyButton).selected = b == cb
		(b as PartyButton).queue_redraw()
	window.queue_redraw()
	title_plate.queue_redraw()


## 카드 i 의 사각형(슬롯 창 기준).
func card_rect(i: int) -> Rect2:
	return Rect2(PAD, PAD + i * CARD_PITCH, WIN_W - 2.0 * PAD, CARD_H)


func window_rect() -> Rect2:
	return window.get_rect()


func band_rect() -> Rect2:
	return band.get_rect()


func title_rect() -> Rect2:
	return title_plate.get_rect()


## 카드 줄 글(시험·디버그): [머리, 둘째 줄, 셋째 줄].
func card_lines(i: int) -> Array[String]:
	if i >= slots.size() or not slots[i]["ok"]:
		return [menu.texts.t("menu.empty_slot"), "", ""]
	var d: Dictionary = slots[i]
	return ["%s  %s" % [d["leader"], d["level"]], str(d["where"]), str(d["time"])]


func _txt(c: Control, pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(c.get_theme_default_font(), pos, s, align as HorizontalAlignment, w, fs, col)


func _draw_window(c: Control) -> void:
	UiTheme.draw_shop_window(c, Rect2(Vector2.ZERO, c.size))
	for i in 3:
		var r := card_rect(i)
		var on := cur_row == i
		c.draw_rect(r, UiTheme.SHOP_DESC_HEAD)
		var num := Rect2(r.position, Vector2(NUM_W, r.size.y))
		c.draw_rect(num, UiTheme.BTN_PICK if on else UiTheme.SHOP_WIN_CAP)
		_txt(c, Vector2(num.position.x, num.get_center().y + 30 * 0.36), str(i + 1), 30, UiTheme.BTN_PICK_TEXT if on else UiTheme.TEXT,
			NUM_W, HORIZONTAL_ALIGNMENT_CENTER)
		var lines := card_lines(i)
		var x := r.position.x + NUM_W + 16.0
		var w := r.size.x - NUM_W - 16.0 - SLOT_BUTTON.x - 28.0
		var band_r := Rect2(x - 6.0, r.position.y + 10.0, minf(w, 420.0), 42.0)
		c.draw_rect(band_r, UiTheme.ST_INFO_TOP)
		_txt(c, Vector2(x, band_r.get_center().y + 24 * 0.36), lines[0], 24, UiTheme.TEXT, band_r.size.x - 12.0)
		_txt(c, Vector2(x, r.position.y + 90.0), lines[1], 20, UiTheme.TEXT, w)
		_txt(c, Vector2(x, r.position.y + 128.0), lines[2], 18, UiTheme.SUB_TEXT, w)
		if on:
			UiTheme.draw_outline(c, r.grow(2.0), UiTheme.BTN_PICK, UiTheme.BTN_PICK_W, 0.0)


func _draw_band(c: Control) -> void:
	UiTheme.draw_shop_window(c, Rect2(Vector2.ZERO, c.size))
	var ax := PAD + 2.0 * WIDE_BUTTON.x + 12.0 + 24.0
	_txt(c, Vector2(ax, 26), menu.texts.t("menu.automap"), 18, UiTheme.SHOP_SECTION_TEXT)
	_txt(c, Vector2(PAD, 26), menu.texts.t("camp.records.file"), 18, UiTheme.SHOP_SECTION_TEXT)
