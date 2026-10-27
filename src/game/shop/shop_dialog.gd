## 상점 창(08 §7.5·§8.6·§8.7): 확인·수량·입하 알림·칸 고르기 공용. 화면 전체를 막는 판(누르기 막음, 어둡게) 위에 창 하나를 목록 창 가로 가운데·
## 세로 가운데(area)에 띄운다. 상점 화면의 맨 뒤 자식으로 둔다(창 층 2, 캠프 확인 창 PartyMenu.Dialog 와 같은 방식).
## - 확인(confirm): 글 한두 줄 + 「예」·「아니오」(원작 YES·NO). 창 그림은 캠프 확인 창과 같다.
## - 수량(qty): [아이콘] 이름 「N개」 / 합계 문구 / 「-10」·아래·위·「+10」 / 「예」·「아니오」. 1~최대에서 멈춘다(감기 없음).
## - 입하 알림(notice): 초록 창, 머리 두 줄, [아이콘] 이름 줄(주황, 최대 5줄, 넘치면 마지막 줄이 「외 n개」), 「확인」.
## - 칸 고르기(slots, 08 §8.7): 머리 「어느 칸에 낄까?」, 둘째 줄 = 막힌 칸을 눌렀을 때의 이유, 방어구 칸 1~3 줄(64, cmd), 「아니오」.
##   막힌 칸은 흐리고 누르면 이유만 보인다. 커서(노랑)는 칸 줄 하나이고 「아니오」는 노랑이 되지 않는다.
## 처음 커서는 「예」다(D25, 원작 YES 먼저). 확인 창은 머리에 [아이콘] 이름 줄을 둘 수 있다(창이 목록 커서 줄을 덮는다, 08 §8.6).
## 단추는 PartyButton skin "cmd"(고른 쪽 노랑 알약, 다른 쪽 청록), 64 높이. 노랑은 고른 단추 하나뿐이다(수량 단추는 커서가 없다).
## 입력은 handle(kind, arg) 하나: step(±1·±10) · pick(±1, 단추 사이 커서) · slot_move(±1, 칸 커서) · confirm(arg 가 있으면 그 단추·칸) · cancel.
## 단추 누르기도 같은 길로 온다. 떠 있는 동안 새 누르기는 화면 전체를 막는 판(MOUSE_FILTER_STOP)이 막고, 이미 눌려 있던
## 누르기는 창이 뜨거나 닫힐 때 부모(상점 화면) 아래의 모든 TouchButton·PartyScroll 을 cancel 해 버린다(07 §9.4 문맥 바뀜).
## 부모가 없으면 자기 단추만. 노랑 하나(07 §9.2)를 위해 목록 커서 모양은 화면이 ShopList.cursor_mode 로 바꾼다.
class_name ShopDialog
extends Control

signal answered(yes: bool, qty: int)
signal closed
## 칸 고르기의 답: 고른 칸(1~3), 끼지 않으면 -1.
signal slot_picked(slot: int)

const W := 480.0
const PAD := 20.0
const BUTTON := Vector2(180, 64)
const STEP := Vector2(64, 64)
const STEP_GAP := 12.0
## 「-10」·「+10」 글자 크기(64 칸 안쪽 여백 안에 든다).
const STEP_FS := 18
const BUTTON_GAP := 24.0
const TEXT_FS := 22
const HEAD_H := 40.0
const LINE_H := 32.0
const ITEM_H := 36.0
const ICON := 30.0
const CONFIRM_H := 200.0
const QTY_H := 268.0
## 칸 고르기: 이유 줄 높이, 칸 줄 사이, 칸 줄과 「아니오」 사이.
const REASON_H := 30.0
const SLOT_GAP := 8.0
const SLOT_ROWS := 3
const SLOTS_H := PAD + HEAD_H + REASON_H + SLOT_ROWS * 64.0 + (SLOT_ROWS - 1) * SLOT_GAP + 12.0 + 64.0 + PAD
const NOTICE_LINES := 5
## 「예」 = 0, 「아니오」 = 1.
const YES := 0
const NO := 1

## "" · confirm · qty · notice · slots
var mode := ""
## 창을 놓는 곳(목록 창 사각형, 이 컨트롤 기준).
var area := Rect2(0, 0, 1280, 720)
var pick := YES
var qty := 1
var max_qty := 1
var unit := 0
var item_icon := ""
var item_name := ""
var message := ""
## 알림 머리 두 줄과 보이는 물건 줄([아이콘, 이름], 넘치면 마지막 줄은 아이콘 "" + 「외 n개」).
var notice_head: Array[String] = []
var notice_rows: Array = []
## 칸 고르기: 칸 커서(1~3), 칸 줄 자료([{text, why}], why 가 비지 않으면 막힌 칸), 막힌 칸을 눌렀을 때의 이유.
var slot_cursor := 1
var slot_data: Array = []
var slot_reason := ""
var slot_buttons: Array[PartyButton] = []
var texts: TextDb
var yes_button: PartyButton
var no_button: PartyButton
var ok_button: PartyButton
## 「-10」·아래·위·「+10」.
var step_buttons: Array[PartyButton] = []
## 입력 갈고리(08 §8.11 F3): 있으면 단추 누르기를 먼저 이것(kind, arg)에 요청한다. 화면이 열림·층 3 막힘·한 프레임 한 입력을
## 통과시킨 뒤 이 창의 handle 을 부른다. 없으면(부품 혼자) 바로 handle.
var route: Callable
var _qty_key := "shop.qty.buy"
## 값 없는 수량 창(open_count, M3 A4b 캠프 버리기): 둘째 줄은 key 문구({n} = 고른 수).
var _count_only := false
var _label := Label.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP  # 떠 있는 동안 새 누르기는 뒤 화면에 닿지 않는다(눌려 있던 것은 열 때 cancel)
	focus_mode = FOCUS_NONE
	visible = false
	add_child(_label)  # 바로 자식으로: setup 전에 버려져도 함께 풀린다


func setup(text_db: TextDb) -> void:
	texts = text_db
	_label.name = "Text"
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", TEXT_FS)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	yes_button = _button("Yes", BUTTON, texts.t("shop.yes"), func() -> void: _press("confirm", YES))
	no_button = _button("No", BUTTON, texts.t("shop.no"), func() -> void: _press("cancel" if mode == "slots" else "confirm", NO))
	ok_button = _button("Ok", BUTTON, texts.t("shop.ok"), func() -> void: _press("confirm", null))
	var steps := [[-10, "Minus10", "-10", 0], [-1, "Down", "", 2], [1, "Up", "", 0], [10, "Plus10", "+10", 0]]
	for st in steps:
		var b := _button(str(st[1]), STEP, str(st[2]), func() -> void: _press("step", st[0]))
		if (st[2] as String).is_empty():
			b.icon = "arrow"
			b.icon_dir = int(st[3])
		b.font_size = STEP_FS
		step_buttons.append(b)
	for k in SLOT_ROWS:
		var slot := k + 1
		var sb := _button("Slot_%d" % slot, Vector2(W - 2.0 * PAD, 64), "", func() -> void: _press("confirm", slot))
		sb.align_left = true
		slot_buttons.append(sb)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _button(n: String, sz: Vector2, label: String, act: Callable) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.skin = "cmd"
	b.text = label
	b.size = sz
	b.activated.connect(act)
	add_child(b)
	return b


func is_open() -> bool:
	return not mode.is_empty()


## 단추 누르기: 입력 갈고리가 있으면 그쪽으로(화면이 거르고 handle 을 부른다), 없으면 바로.
func _press(kind: String, arg: Variant) -> void:
	if route.is_valid():
		route.call(kind, arg)
	else:
		handle(kind, arg)


## 창을 놓을 곳(목록 창 사각형, 이 컨트롤 기준).
func set_area(r: Rect2) -> void:
	area = r
	_layout()


## 확인 창. yes_first: 처음 커서가 「예」인지(아니면 「아니오」, D25 전 캠프 방식). icon_name·name_text 가 있으면 머리에
## [아이콘] 이름 줄(수량 창 첫 줄과 같은 그림, 08 §8.6).
func open_confirm(text: String, yes_first: bool = true, icon_name: String = "", name_text: String = "") -> void:
	message = text
	item_icon = icon_name
	item_name = name_text
	_open("confirm", yes_first)


## 칸 고르기(08 §8.7). rows: 칸 1~3 의 [{text: 「방어구 1  패딩 코트」, why: 막는 이유 글("" = 낄 수 있음)}]. first: 처음 커서 칸(1~3).
func open_slots(rows: Array, first: int) -> void:
	slot_data = rows.duplicate(true)
	slot_cursor = clampi(first, 1, SLOT_ROWS)
	slot_reason = ""
	item_icon = ""
	item_name = ""
	_open("slots", false)


## 수량 창. unit_price × 수량을 key 문구({total})로 보인다(shop.qty.buy·shop.qty.sell). 수량은 1 부터.
func open_qty(icon_name: String, name_text: String, unit_price: int, most: int, key: String = "shop.qty.buy", yes_first: bool = true) -> void:
	item_icon = icon_name
	item_name = name_text
	unit = unit_price
	max_qty = maxi(1, most)
	qty = 1
	_qty_key = key
	_count_only = false
	_open("qty", yes_first)


## 값 없는 수량 창(M3 A4b 캠프 「버리기」, D4): 첫 줄은 수량 창과 같고, 둘째 줄은 key 문구({n} = 고른 수, 예 「{n}개 버릴까?」).
## 처음 커서는 「아니오」(D25: 잃는 쪽은 아니오 먼저). 1~most.
func open_count(icon_name: String, name_text: String, most: int, key: String) -> void:
	item_icon = icon_name
	item_name = name_text
	unit = 0
	max_qty = maxi(1, most)
	qty = 1
	_qty_key = key
	_count_only = true
	_open("qty", false)


## 입하 알림. items: [{icon, name}] (진열 차례).
func open_notice(shop_name: String, items: Array) -> void:
	notice_head.assign(texts.t("shop.notice", {"shop": shop_name}).split("\n"))
	notice_rows = []
	for i in items.size():
		if items.size() > NOTICE_LINES and i == NOTICE_LINES - 1:
			notice_rows.append(["", texts.t("shop.notice.more", {"n": items.size() - (NOTICE_LINES - 1)})])
			break
		notice_rows.append([str(items[i].get("icon", "")), str(items[i].get("name", ""))])
	_open("notice", true)


func _open(m: String, yes_first: bool) -> void:
	_cancel_pointers()
	mode = m
	pick = YES if yes_first else NO
	visible = true
	_layout()


func close() -> void:
	_cancel_pointers()
	mode = ""
	visible = false


## 문맥이 바뀐다(창이 뜨거나 닫힘): 부모(상점 화면) 아래에서 눌려 있던 단추·줄·탭·끌어 내리는 영역을 모두 버린다.
func _cancel_pointers() -> void:
	var root_node: Node = get_parent() if get_parent() != null else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		(n as TouchButton).cancel()
	for n in root_node.find_children("*", "PartyScroll", true, false):
		(n as PartyScroll).cancel()


## 입력 입구. 받아들이면 true.
func handle(kind: String, arg: Variant = null) -> bool:
	if mode.is_empty():
		return false
	match kind:
		"step":
			if mode != "qty":
				return false
			var to := clampi(qty + int(arg), 1, max_qty)
			if to == qty:
				return false
			qty = to
			_refresh()
			return true
		"slot_move":
			if mode != "slots":
				return false
			var to_slot := clampi(slot_cursor + int(arg), 1, SLOT_ROWS)
			if to_slot == slot_cursor:
				return false
			slot_cursor = to_slot
			slot_reason = ""
			_refresh()
			return true
		"pick":
			if mode == "notice" or mode == "slots":
				return false
			var to := clampi(pick + int(arg), YES, NO)
			if to == pick:
				return false
			pick = to
			_refresh()
			return true
		"confirm":
			if mode == "notice":
				close()
				closed.emit()
				return true
			if mode == "slots":
				var slot := slot_cursor if arg == null else int(arg)
				if slot < 1 or slot > slot_data.size():
					return false
				slot_cursor = slot
				var why := str(slot_data[slot - 1].get("why", ""))
				if not why.is_empty():
					slot_reason = why  # 막힌 칸: 창 그대로, 둘째 줄에 이유
					_refresh()
					return true
				close()
				slot_picked.emit(slot)
				return true
			if arg != null:
				pick = clampi(int(arg), YES, NO)
			var yes := pick == YES
			var n := qty if mode == "qty" else 1
			close()
			answered.emit(yes, n)
			return true
		"cancel":
			var was := mode
			var n := qty if mode == "qty" else 1
			close()
			if was == "notice":
				closed.emit()
			elif was == "slots":
				slot_picked.emit(-1)
			else:
				answered.emit(false, n)
			return true
	return false


## 수량 창 둘째 줄(합계, 값 없는 창이면 고른 수 문구).
func total_text() -> String:
	if _count_only:
		return texts.t(_qty_key, {"n": qty})
	return texts.t(_qty_key, {"total": ShopRow.grouped(unit * qty)})


## 창 사각형(이 컨트롤 기준): 목록 창 가로 가운데·세로 가운데, 화면 안으로.
func window_rect() -> Rect2:
	var h := CONFIRM_H + (HEAD_H if has_head() else 0.0)
	match mode:
		"qty":
			h = QTY_H
		"slots":
			h = SLOTS_H
		"notice":
			h = PAD + notice_head.size() * LINE_H + 8.0 + notice_rows.size() * ITEM_H + 12.0 + BUTTON.y + PAD
	var c := area.get_center()
	var r := Rect2((c - Vector2(W, h) / 2.0).round(), Vector2(W, h))
	var s := size if size.x > 0.0 else get_viewport_rect().size
	r.position = r.position.clamp(Vector2.ZERO, (s - r.size).max(Vector2.ZERO))
	return r


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	if texts == null or step_buttons.size() < 4:
		return
	var r := window_rect()
	var by := r.end.y - PAD - BUTTON.y
	yes_button.position = Vector2(r.get_center().x - BUTTON_GAP / 2.0 - BUTTON.x, by)
	no_button.position = Vector2(r.get_center().x + BUTTON_GAP / 2.0, by)
	ok_button.position = Vector2(r.get_center().x - BUTTON.x / 2.0, by)
	var sw := 4 * STEP.x + 3 * STEP_GAP
	for i in step_buttons.size():
		step_buttons[i].position = Vector2(r.get_center().x - sw / 2.0 + i * (STEP.x + STEP_GAP), r.position.y + PAD + HEAD_H + 4.0 + LINE_H + 12.0)
	var head := HEAD_H if has_head() else 0.0
	_label.position = r.position + Vector2(PAD, PAD + head)
	_label.size = Vector2(W - 2.0 * PAD, by - 12.0 - r.position.y - PAD - head)
	for k in slot_buttons.size():
		slot_buttons[k].position = slot_row_rect(k + 1).position
	if mode == "slots":
		no_button.position = Vector2(r.get_center().x - BUTTON.x / 2.0, by)
	_refresh()


## 확인 창 머리에 [아이콘] 이름 줄이 있는지.
func has_head() -> bool:
	return mode == "confirm" and not item_name.is_empty()


## 칸 고르기 줄(칸 1~3)의 사각형(이 컨트롤 기준).
func slot_row_rect(slot: int) -> Rect2:
	var r := window_rect()
	return Rect2(r.position.x + PAD, r.position.y + PAD + HEAD_H + REASON_H + (slot - 1) * (64.0 + SLOT_GAP), W - 2.0 * PAD, 64.0)


func _refresh() -> void:
	var m := mode
	_label.visible = m == "confirm"
	_label.text = message
	yes_button.visible = m == "confirm" or m == "qty"
	no_button.visible = yes_button.visible or m == "slots"
	ok_button.visible = m == "notice"
	for b in step_buttons:
		b.visible = m == "qty"
	for k in slot_buttons.size():
		var sb := slot_buttons[k]
		sb.visible = m == "slots" and k < slot_data.size()
		if not sb.visible:
			continue
		sb.text = str(slot_data[k].get("text", ""))
		sb.dimmed = not str(slot_data[k].get("why", "")).is_empty()
		sb.selected = k + 1 == slot_cursor
	yes_button.selected = pick == YES
	no_button.selected = pick == NO and m != "slots"  # 칸 고르기의 노랑은 칸 커서 하나
	ok_button.selected = true
	if m == "qty":
		step_buttons[0].dimmed = qty <= 1
		step_buttons[1].dimmed = qty <= 1
		step_buttons[2].dimmed = qty >= max_qty
		step_buttons[3].dimmed = qty >= max_qty
	queue_redraw()


## 수량 창 첫 줄의 개수 글(「10개」).
func count_text() -> String:
	return texts.t("party.count", {"n": qty})


func _draw() -> void:
	if mode.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var r := window_rect()
	var font := get_theme_default_font()
	if mode == "notice":
		_draw_notice(r, font)
		return
	UiTheme.draw_tree_window(self, r, true)  # 캠프 확인 창과 같은 창(불투명)
	if mode == "slots":
		draw_string(font, Vector2(r.position.x, r.position.y + PAD + HEAD_H / 2.0 + TEXT_FS * 0.36), texts.t("shop.slot.ask"),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, TEXT_FS, UiTheme.TEXT)
		if not slot_reason.is_empty():
			draw_string(font, Vector2(r.position.x + PAD, r.position.y + PAD + HEAD_H + REASON_H / 2.0 + 18 * 0.36), slot_reason,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 2.0 * PAD, 18, UiTheme.BATTLE_BANNER_NOTICE)
		return
	if has_head():
		var hx := r.position.x + PAD + 4.0
		var hy := r.position.y + PAD
		if not item_icon.is_empty():
			VectorIcons.draw(self, item_icon, Rect2(hx, hy + (HEAD_H - ICON) / 2.0, ICON, ICON), UiTheme.SHOP_ICON)
		draw_string(font, Vector2(hx + ICON + 10.0, hy + HEAD_H / 2.0 + TEXT_FS * 0.36), item_name, HORIZONTAL_ALIGNMENT_LEFT,
			r.end.x - PAD - (hx + ICON + 10.0), TEXT_FS, UiTheme.TEXT)
	if mode != "qty":
		return
	var y := r.position.y + PAD
	var x := r.position.x + PAD + 4.0
	if not item_icon.is_empty():
		VectorIcons.draw(self, item_icon, Rect2(x, y + (HEAD_H - ICON) / 2.0, ICON, ICON), UiTheme.SHOP_ICON)
	var base := y + HEAD_H / 2.0 + TEXT_FS * 0.36
	var cw := font.get_string_size(count_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(font, Vector2(r.end.x - PAD - 4.0 - cw, base), count_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.TEXT)
	draw_string(font, Vector2(x + ICON + 10.0, base), item_name, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - PAD - cw - 16.0 - (x + ICON + 10.0),
		TEXT_FS, UiTheme.TEXT)
	draw_string(font, Vector2(r.position.x, y + HEAD_H + 4.0 + LINE_H / 2.0 + 20 * 0.36), total_text(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
		20, UiTheme.TEXT)


## 입하 알림(원작 guide3 img3): 초록 창, 흰 머리 두 줄, [아이콘] 주황 이름 줄.
func _draw_notice(r: Rect2, font: Font) -> void:
	var c := minf(14.0, r.size.y * 0.3)
	var pts := UiTheme.chamfer_points(r, c)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(UiTheme.SHOP_NOTICE_TOP.lerp(UiTheme.SHOP_NOTICE_BOTTOM, (p.y - r.position.y) / maxf(1.0, r.size.y)))
	draw_polygon(pts, cols)
	UiTheme.draw_outline(self, r.grow(-2.0), UiTheme.SHOP_NOTICE_EDGE, 2.0, c)
	var y := r.position.y + PAD
	for line in notice_head:
		draw_string(font, Vector2(r.position.x + PAD + 4.0, y + LINE_H / 2.0 + TEXT_FS * 0.36), line, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2.0 * PAD,
			TEXT_FS, UiTheme.TEXT)
		y += LINE_H
	y += 8.0
	for row in notice_rows:
		var x := r.position.x + PAD + 24.0
		if not str(row[0]).is_empty():
			VectorIcons.draw(self, str(row[0]), Rect2(x, y + (ITEM_H - ICON) / 2.0, ICON, ICON), UiTheme.SHOP_ICON)
		draw_string(font, Vector2(x + ICON + 10.0, y + ITEM_H / 2.0 + TEXT_FS * 0.36), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT,
			r.end.x - PAD - (x + ICON + 10.0), TEXT_FS, UiTheme.SHOP_NOTICE_ITEM)
		y += ITEM_H
