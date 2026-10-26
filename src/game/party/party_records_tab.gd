## 캠프 기록 화면(07 §9.7 「기록」, §9.9 E2-e). 원작에 기록 화면이 없어 원작 I HD OPTION 화면(yt_eo1hd_06) 모양을 빌린다:
## 맨 위는 캠프 뿌리의 띠 그대로(걸음 문패·장소 띠·소지금, 알림 줄 자리에 「기록」: PartyMenu 가 그린다, D27 ④). 「뒤로」·EXIT 는 없다(D27 ①).
## 반투명 청록 둥근 판 하나(RecordsWindow, 900 폭, y 116 ~ H − 8, 1280 에서는 방향 십자를 비켜 x 224 부터, 넓으면 가운데).
## 판 위쪽 도움말 줄(커서 단추가 할 일), 그 아래 OPTION 줄 다섯: 어두운 길 위에 이름 알약(왼쪽 380)과 값 알약(누르는 단추).
##   줄 0~2 슬롯: 이름 알약 두 줄(「n  대표 대원 Lv k」, 「층 · 걸음   저장 시각」, 빈 칸은 「n  비어 있음」), 값 「저장」「불러오기」(빈 칸은 회색).
##   줄 3 「파일」: 「내보내기」「가져오기」. 줄 4 「자동 지도」: 끔·바닥만·바닥+벽(지금 것은 밝은 하늘색).
##   줄 5: 「새 게임」 알약 하나(원작 EXIT 자리, 판 오른쪽 아래. 누르면 캠프 확인 창).
## 노랑 채움은 하나: 커서 줄의 이름 알약(새 게임 줄은 그 알약). 커서 값 알약은 제 채움 그대로 노란 고리만. 그림은 공용 ListParts(판·줄·알약).
## 값·일은 바깥(탐색 화면)이 menu.records 갈고리로 준다: slots·save·load·export·import·automap·set_automap·new_game.
## 키보드: ↑↓ 줄(여섯, 줄을 바꾸면 칸 번호는 줄 길이로 자른다), ←→ 줄 안, Enter 누름. 단추를 누르면(포인터) 커서도 그 단추로.
## M3 A2(D28): 판을 여러 화면이 같이 쓴다. 주인(host)은 texts·records·state·handle(kind, arg)·open_dialog(kind, after)를 가진
## 아무 Control(캠프 PartyMenu, 타이틀 TitleScreen)이고, 줄 묶음(row_set)이 보일 줄과 줄마다의 알약을 정한다:
##   camp = 위 여섯 줄 그대로, title_load = 슬롯 셋(「불러오기」만)·파일(「가져오기」만), title_settings = 자동 지도만.
## 줄은 판 위에서부터 채운다. 단추 이름·입력 종류는 줄 묶음과 상관없이 같다(보이지 않는 단추는 누르기를 받지 않는다).
class_name PartyRecordsTab
extends Control

const PANEL_W := 900.0
## 판 왼쪽 끝의 최소(P3, 사용자 결정 2026-10-25): 왼쪽 아래 방향 십자(x 8~208) 오른쪽 + 16. 넓은 화면은 가운데 그대로.
const LEFT_MIN := 224.0
## 판 위(알림 줄 y 108 아래 + 8)와 아래 여백(화면 아래 끝에서).
const PANEL_TOP := 116.0
const PANEL_BOTTOM := 8.0
## 판 안 자리(판 기준): 도움말 줄, 줄 길(x·폭·높이·첫 줄 위·피치), 이름 알약 폭, 알약 높이·사이.
const HELP := Rect2(24, 10, 852, 40)
const HELP_FS := 20
const TRACK_X := 24.0
const TRACK_W := 852.0
const TRACK_H := 70.0
const TRACK_TOP := 58.0
const TRACK_PITCH := 78.0
const ROWS := 5
const LABEL_W := 380.0
const PILL_H := 64.0
const PILL_GAP := 4.0
## 값 알약 자리(판 기준 x, 폭): 이름 알약 오른쪽 + 사이부터 길 안쪽 끝까지.
const VALUE_X := TRACK_X + ListParts.OPT_TRACK_INSET + LABEL_W + PILL_GAP
const VALUE_W := TRACK_X + TRACK_W - ListParts.OPT_TRACK_INSET - VALUE_X
## 「새 게임」: 오른쪽 열(두 알약 줄의 둘째 칸)과 같은 x·폭, 판 아래 끝에서 16 위.
const NEW_GAME_BOTTOM := 16.0
## 줄 묶음 → 줄 종류 차례(slot0~2 · file · automap · new_game). new_game 은 길이 아니라 판 오른쪽 아래 알약 하나다.
const ROW_SETS := {
	"camp": ["slot0", "slot1", "slot2", "file", "automap", "new_game"],
	"title_load": ["slot0", "slot1", "slot2", "file"],
	"title_settings": ["automap"],
}

## 주인(PartyMenu·TitleScreen: texts·records·state·handle·open_dialog 를 가진 Control). 타입은 일부러 두지 않는다.
var menu
## 지금 줄 묶음(ROW_SETS 열쇠).
var row_set := "camp"
## 커서(줄, 칸): 줄 0~2 = 슬롯(0 저장·1 불러오기), 줄 3 = 파일(내보내기·가져오기), 줄 4 = 자동 지도 셋, 줄 5 = 새 게임.
var cur_row := 0
var cur_col := 0
var window: Control
var save_buttons: Array[ListButton] = []
var load_buttons: Array[ListButton] = []
## 내보내기·가져오기·자동 지도 셋·새 게임(차례 그대로).
var band_buttons: Array[ListButton] = []
## 마지막으로 읽은 슬롯 정보([{slot, ok, leader, level, where, time}]).
var slots: Array = []
var _dirty := true
## 가운데 앵커로 붙인 부품과 [앵커 a0, a1, 기본 여백]: 좁은 화면에서 place 가 함께 오른쪽으로 민다.
var _centred: Array = []
## 지금 민 양.
var shift := 0.0


func setup(m: Control, rows: String = "camp") -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	window = Control.new()
	window.name = "RecordsWindow"
	window.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(window)
	_anchor(window, Vector2(0.5, 0), Vector2(0.5, 1), Vector4(-PANEL_W / 2.0, PANEL_TOP, PANEL_W / 2.0, -PANEL_BOTTOM))
	window.draw.connect(_draw_window)
	for i in 3:
		var p := pill_rects(i, 2)
		save_buttons.append(_button("Save_" + _slot_id(i), menu.texts.t("menu.save"), "record_save", i, p[0]))
		load_buttons.append(_button("Load_" + _slot_id(i), menu.texts.t("menu.load"), "record_load", i, p[1]))
	var fp := pill_rects(3, 2)
	band_buttons.append(_button("Export", menu.texts.t("menu.export"), "record_export", null, fp[0]))
	band_buttons.append(_button("Import", menu.texts.t("menu.import"), "record_import", null, fp[1]))
	var ap := pill_rects(4, ExplorationRules.AUTOMAP_MODES.size())
	for k in ExplorationRules.AUTOMAP_MODES.size():
		var mode: String = ExplorationRules.AUTOMAP_MODES[k]
		band_buttons.append(_button("Automap_" + mode, menu.texts.t("menu.automap." + mode), "record_automap", mode, ap[k]))
	# 「새 게임」: 판 아래 끝에 붙는다(높은 화면에서도 원작 EXIT 처럼 판 오른쪽 아래).
	var ng := new_game_rect()
	var bottom := -PANEL_BOTTOM - NEW_GAME_BOTTOM
	var b := _button("NewGame", menu.texts.t("menu.new_game"), "record_new_game", null, Rect2())
	b.cursor_ring = false
	_anchor(b, Vector2(0.5, 1), Vector2(0.5, 1),
		Vector4(-PANEL_W / 2.0 + ng.position.x, bottom - PILL_H, -PANEL_W / 2.0 + ng.end.x, bottom))
	band_buttons.append(b)
	set_rows(rows)


## 줄 묶음을 바꾼다: 보일 단추만 보이고, 길 k 의 알약을 그 줄의 단추 수로 다시 나눈다(위에서부터 채움). 커서는 맨 위.
func set_rows(rows: String) -> void:
	assert(ROW_SETS.has(rows), "모르는 줄 묶음: " + rows)
	row_set = rows
	var shown := {}
	var k := 0
	for kind in row_kinds():
		var bs := row_buttons(kind)
		for b in bs:
			shown[b] = true
		if kind == "new_game":
			continue
		var pr := pill_rects(k, bs.size())
		for i in bs.size():
			var r: Rect2 = pr[i]
			_anchor(bs[i], Vector2(0.5, 0), Vector2(0.5, 0),
				Vector4(-PANEL_W / 2.0 + r.position.x, PANEL_TOP + r.position.y, -PANEL_W / 2.0 + r.end.x, PANEL_TOP + r.end.y))
		k += 1
	for b in save_buttons + load_buttons + band_buttons:
		(b as ListButton).visible = shown.has(b)
		if not shown.has(b):
			(b as ListButton).cancel()
	reset()


## 지금 줄 묶음의 줄 종류 차례.
func row_kinds() -> Array:
	return ROW_SETS[row_set]


## 줄 종류 kind 의 알약(지금 줄 묶음에서 보이는 것만, 왼쪽부터).
func row_buttons(kind: String) -> Array:
	var title := row_set != "camp"
	if kind.begins_with("slot"):
		var i := int(kind.substr(4))
		return [load_buttons[i]] if title else [save_buttons[i], load_buttons[i]]
	match kind:
		"file":
			return [band_buttons[1]] if title else band_buttons.slice(0, 2)
		"automap":
			return band_buttons.slice(2, 2 + ExplorationRules.AUTOMAP_MODES.size())
	return [band_buttons[band_buttons.size() - 1]]


## 길로 그리는 줄 수(new_game 알약 줄은 빼고).
func track_count() -> int:
	return row_kinds().filter(func(k: String) -> bool: return k != "new_game").size()


## 슬롯 i 의 저장 이름(SaveStore 수동 슬롯).
func _slot_id(i: int) -> String:
	return SaveStore.MANUAL_SLOTS[i]


## 가운데 앵커 부품을 놓고 기억한다(place 가 shift 만큼 함께 민다).
func _anchor(c: Control, a0: Vector2, a1: Vector2, off: Vector4) -> void:
	PartyMenu.place(c, a0, a1, off + Vector4(shift, 0, shift, 0))
	for e in _centred:
		if e[0] == c:
			e[3] = off
			return
	_centred.append([c, a0, a1, off])


## 값 알약 하나. r: 판 기준 자리(위 앵커). 빈 r 이면 부르는 쪽이 놓는다.
func _button(n: String, label: String, kind: String, arg: Variant, r: Rect2) -> ListButton:
	var b := ListButton.new()
	b.name = n
	b.text = label
	b.style = "pill"
	b.look = "option"
	b.cursor_ring = true
	add_child(b)
	if r.size != Vector2.ZERO:
		_anchor(b, Vector2(0.5, 0), Vector2(0.5, 0),
			Vector4(-PANEL_W / 2.0 + r.position.x, PANEL_TOP + r.position.y, -PANEL_W / 2.0 + r.end.x, PANEL_TOP + r.end.y))
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


## 좁은 화면(1280)에서는 판이 x LEFT_MIN 에서 시작하게 가운데 묶음(판·알약)을 오른쪽으로 민다. 넓으면 가운데.
func place(s: Vector2) -> void:
	shift = maxf(0.0, LEFT_MIN - (s.x - PANEL_W) / 2.0)
	for e in _centred:
		var off: Vector4 = e[3]
		PartyMenu.place(e[0], e[1], e[2], off + Vector4(shift, 0, shift, 0))
	if visible and _can_read():
		refresh()


# ---- 자리(판 기준) ----

## 줄 k(0~4)의 길.
static func track_rect(k: int) -> Rect2:
	return Rect2(TRACK_X, TRACK_TOP + k * TRACK_PITCH, TRACK_W, TRACK_H)


static func label_rect(k: int) -> Rect2:
	return ListParts.option_label_rect(track_rect(k), LABEL_W)


## 줄 k 의 값 알약 n 개 자리(길 안, 사이 PILL_GAP).
static func pill_rects(k: int, n: int) -> Array[Rect2]:
	var w := (VALUE_W - (n - 1) * PILL_GAP) / n
	var y := track_rect(k).position.y + ListParts.OPT_TRACK_INSET
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(VALUE_X + i * (w + PILL_GAP), y, w, PILL_H))
	return out


## 「새 게임」 자리(판 높이 h 의 판 기준, 기본은 1280×720 의 판 높이).
func new_game_rect(h: float = -1.0) -> Rect2:
	var right: Rect2 = pill_rects(0, 2)[1]
	var ph := h if h >= 0.0 else (window.size.y if window != null and window.size.y > 0.0 else 720.0 - PANEL_TOP - PANEL_BOTTOM)
	return Rect2(right.position.x, ph - NEW_GAME_BOTTOM - PILL_H, right.size.x, PILL_H)


func window_rect() -> Rect2:
	return window.get_rect()


# ---- 커서 ----

## 커서 순서의 단추 줄(camp: 줄 0~2 슬롯, 3 파일, 4 자동 지도, 5 새 게임. 다른 묶음은 ROW_SETS 차례).
func grid() -> Array:
	var out := []
	for kind in row_kinds():
		out.append(row_buttons(kind))
	return out


func cursor_button() -> ListButton:
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
			# 줄 길이가 다르면(둘·셋·하나) 같은 칸 번호를 잇되 줄 길이로 자른다.
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
			return dispatch(str(b.get_meta("kind")), _arg(b))
		"record_save":
			if not _shown(save_buttons, arg):
				return false
			_point(save_buttons[int(arg)])
			_dirty = true
			menu.records["save"].call(_slot_id(int(arg)))
			return true
		"record_load":
			if not _shown(load_buttons, arg):
				return false
			var i := int(arg)
			_point(load_buttons[i])
			if i >= slots.size() or not slots[i]["ok"]:
				return false
			menu.records["load"].call(_slot_id(i))
			return true
		"record_export":
			if not band_buttons[0].visible:
				return false
			_point(band_buttons[0])
			menu.records["export"].call()
			return true
		"record_import":
			if not band_buttons[1].visible:
				return false
			_point(band_buttons[1])
			menu.records["import"].call()
			return true
		"record_automap":
			var mode := str(arg)
			var k := ExplorationRules.AUTOMAP_MODES.find(mode)
			if k < 0 or not band_buttons[2 + k].visible:
				return false
			_point(band_buttons[2 + k])
			menu.records["set_automap"].call(mode)
			return true
		"record_new_game":
			if not band_buttons[band_buttons.size() - 1].visible:
				return false
			_point(band_buttons[band_buttons.size() - 1])
			var start: Callable = menu.records["new_game"]
			menu.open_dialog("new_game", start)
			return true
	return false


## 슬롯 단추 줄 bs 의 arg 번 단추가 있고 지금 줄 묶음에서 보이는지(타이틀에서 「저장」·「내보내기」·「새 게임」은 일하지 않는다).
static func _shown(bs: Array[ListButton], arg: Variant) -> bool:
	var i := int(arg) if arg != null else -1
	return i >= 0 and i < bs.size() and bs[i].visible


## 알약의 값(슬롯 번호·자동 지도 모드). 값이 null 이면(내보내기·가져오기·새 게임) set_meta 가 열쇠를 지우므로 열쇠가 없으면 null.
static func _arg(b: ListButton) -> Variant:
	return b.get_meta("arg") if b.has_meta("arg") else null


## 포인터로 누른 단추로 커서를 옮긴다.
func _point(b: ListButton) -> void:
	var g := grid()
	for r in g.size():
		var c := (g[r] as Array).find(b)
		if c >= 0:
			cur_row = r
			cur_col = c
			return


## 값을 읽을 수 있는지: 갈고리가 있고, 캠프는 탐색 상태도 있어야 한다(타이틀은 상태 없이 읽는다).
func _can_read() -> bool:
	return menu != null and menu.records.has("slots") and (row_set != "camp" or menu.state != null)


func refresh() -> void:
	if not _can_read():
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
		(b as ListButton).selected = b == cb and (b as ListButton).visible
		(b as ListButton).queue_redraw()
	window.queue_redraw()


# ---- 글 ----

## 슬롯 i 의 줄 글(시험·디버그 스냅숏 cards): [머리, 둘째 줄, 셋째 줄].
func card_lines(i: int) -> Array[String]:
	if i >= slots.size() or not slots[i]["ok"]:
		return [menu.texts.t("menu.empty_slot"), "", ""]
	var d: Dictionary = slots[i]
	return ["%s  %s" % [d["leader"], d["level"]], str(d["where"]), str(d["time"])]


## 길 k 의 이름 알약 글 줄. 슬롯: 「n  대표 Lv k」와 「층 · 걸음   저장 시각」(빈 칸은 「n  비어 있음」 한 줄).
func row_label_lines(k: int) -> Array[String]:
	var kind: String = row_kinds()[k]
	if kind.begins_with("slot"):
		var i := int(kind.substr(4))
		var c := card_lines(i)
		var head := "%d  %s" % [i + 1, c[0]]
		if c[1].is_empty():
			return [head]
		return [head, "%s   %s" % [c[1], c[2]]]
	if kind == "file":
		return [menu.texts.t("camp.records.file")]
	return [menu.texts.t("menu.automap")]


## 줄 k 이름 알약의 상태: 커서 줄이면 노랑(selected), 아니면 초록.
func label_state(k: int) -> String:
	return "selected" if cur_row == k else "normal"


## 도움말 줄: 커서 단추가 할 일(camp.records.help.*).
func help_text() -> String:
	var b := cursor_button()
	var kind := str(b.get_meta("kind"))
	match kind:
		"record_save":
			return menu.texts.t("camp.records.help.save", {"n": int(_arg(b)) + 1})
		"record_load":
			if b.disabled:
				return menu.texts.t("camp.records.help.load_empty")
			return menu.texts.t("camp.records.help.load", {"n": int(_arg(b)) + 1})
		"record_export":
			return menu.texts.t("camp.records.help.export")
		"record_import":
			return menu.texts.t("camp.records.help.import")
		"record_automap":
			return menu.texts.t("camp.records.help.automap")
	return menu.texts.t("camp.records.help.new_game")


func _draw_window() -> void:
	SheetParts.begin(window)
	ListParts.draw_panel(window, Rect2(Vector2.ZERO, window.size), "option")
	SheetParts._text(window, Vector2(HELP.position.x, HELP.get_center().y + HELP_FS * 0.36), help_text(), HELP_FS, ListParts.PANEL_OPT_TEXT,
		HELP.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for k in track_count():
		ListParts.draw_option_row(window, track_rect(k), LABEL_W, row_label_lines(k), label_state(k))
