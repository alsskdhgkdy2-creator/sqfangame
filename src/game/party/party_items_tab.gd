## 캠프 소지품 화면(07 §9.2, §5.6, M2.7 R2-c: 원작 상점 팔기 화면 jp_guide3_img2 짜임, ShopFrame 설명 창 없이 목록 창이 아래까지).
## 목록 창: 「장비」(가방 개수, 낄 수 있는 직업)·「소재」(개수, 읽기만) 두 묶음, 줄 64. 오른쪽 인물 판은 지금 대원(Q·E·판 단추로 넘김).
## 디버그일 때만 맨 위에 「임시 보급(시험용)」(07 §5.7): 누르면 장비마다 「+1」, 대원마다 「경험치 +100」「다음 레벨까지」 줄이 열린다.
## 보급은 GrowthRules.supply·grant_exp → 자동 저장. ↑↓ 는 디버그면 누를 수 있는 단추 사이 커서(Enter 로 누름)이고, 마지막 단추에서
## ↓ 를 더 누르면 아래 읽기만 하는 목록을 내리며(↑ 는 커서 단추가 다시 보일 때까지 올린 뒤 커서를 옮긴다), 디버그가 아니면 내리기만.
## 단추를 누르면(포인터) 커서도 그 단추로 옮긴다: 이어서 Enter 는 같은 단추를 다시 누른다(07 §9.4).
class_name PartyItemsTab
extends Control

const ROW_H := 64.0
const ROW_GAP := 4.0
const SUPPLY_SIZE := Vector2(240, 64)
const PLUS_SIZE := Vector2(96, 64)
## 대원 줄(디버그 보급): 위에 이름·Lv·경험치 줄(목록 폭 전체), 그 아래에 「경험치 +100」「다음 레벨까지」를 반씩(P3 검토 수정:
## 좁아진 목록(1280 에서 481)에서 이름이 단추 뒤로 숨지 않게 두 줄로 나눴다). 단추 높이는 64, 폭은 (목록 폭 − 8) / 2.
const EXP_SIZE := Vector2(200, 64)
const EXP_STEP := 100

var menu: PartyMenu
var frame: ShopFrame
var list: PartyScroll
## 보급 줄이 열려 있는지.
var supply_open := false
## 누를 수 있는 단추 사이 커서(디버그).
var cursor := 0
var supply_button: PartyButton
## 읽기만 하는 줄(그림만, 포인터를 받지 않는다).
var _rows: Array[PartyButton] = []
var _used := 0
## 보급 「+1」 단추(장비 ID 순) · 대원별 「경험치 +100」·「다음 레벨까지」.
var plus_buttons: Array[PartyButton] = []
var exp_buttons: Array[PartyButton] = []
var next_buttons: Array[PartyButton] = []
var _labels: Array[Label] = []
var _label_used := 0


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame = ShopFrame.new()
	frame.name = "ItemsFrame"
	add_child(frame)
	frame.build("Items", menu.texts.t("camp.back"), false, ShopFrame.PAD_SIDE)
	frame.back.connect(func() -> void: menu.handle("back"))
	frame.panel.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	list = PartyScroll.new()
	list.name = "ItemsList"
	add_child(list)
	var la: Array = frame.list_anchor()
	PartyMenu.place(list, la[0], la[1], la[2])
	list.resized.connect(func() -> void:
		if menu.state != null and visible:
			refresh())
	supply_button = _press_button("SupplyToggle", SUPPLY_SIZE, "supply_toggle", null)


func _press_button(n: String, sz: Vector2, kind: String, arg: Variant) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.size = sz
	b.scroller = list
	b.activated.connect(func() -> void: menu.handle(kind, arg))
	list.content.add_child(b)
	return b


func reset() -> void:
	supply_open = false
	cursor = 0
	list.scroll_to(0.0)


func member_changed() -> void:
	pass


func context() -> String:
	return ""


func place(_s: Vector2) -> void:
	if menu.state != null and visible:
		refresh()


## 지금 누를 수 있는 단추(커서 순서).
func actionable() -> Array[PartyButton]:
	var out: Array[PartyButton] = []
	if not menu.debug:
		return out
	out.append(supply_button)
	if supply_open:
		out.append_array(plus_buttons.filter(func(b: PartyButton) -> bool: return b.visible))
		for j in exp_buttons.size():
			if exp_buttons[j].visible:
				out.append(exp_buttons[j])
				out.append(next_buttons[j])
	return out


func dispatch(kind: String, arg: Variant) -> bool:
	var ids := menu.state.defs.battle.equipment_ids
	match kind:
		"cursor":
			return _move(int(arg) if arg != null else 1)
		"confirm":
			var acts := actionable()
			if acts.is_empty():
				return false
			cursor = clampi(cursor, 0, acts.size() - 1)
			_show(acts[cursor])
			return _press(acts[cursor])
	if not menu.debug:
		return false
	match kind:
		"supply_toggle":
			supply_open = not supply_open
			cursor = 0
			return true
		"supply":
			if not supply_open or not ids.has(str(arg)):
				return false
			_point(plus_buttons[ids.find(str(arg))])
			menu.apply(GrowthRules.supply(menu.state, str(arg), 1))
			return true
		"exp_100":
			var i := int(arg)
			if not supply_open or i < 0 or i >= menu.state.party.members.size():
				return false
			_point(exp_buttons[i])
			menu.apply(GrowthRules.grant_exp(menu.state, i, EXP_STEP))
			return true
		"exp_next":
			if not supply_open:
				return false
			var i := int(arg)
			if i < 0 or i >= menu.state.party.members.size():
				return false
			_point(next_buttons[i])
			var m := menu.state.party.members[i]
			var g := menu.state.defs.battle.growth
			if m.level >= g.level_cap:
				menu.show_notice(menu.texts.t("party.exp_max"))
				return true
			menu.apply(GrowthRules.grant_exp(menu.state, i, g.cum(m.level + 1) - m.exp))
			return true
	return false


## ↑↓ 하나. 누를 수 있는 단추가 없으면 목록을 한 줄 내리거나 올린다. 있으면 단추 사이를 옮기되, 마지막 단추에서 ↓ 는 목록을
## 내리고(읽기만 하는 소지품까지 키보드로 본다), ↑ 는 커서 단추 위쪽이 가려져 있으면 먼저 목록을 올린다.
func _move(d: int) -> bool:
	var acts := actionable()
	var before := list.scroll
	if acts.is_empty():
		list.scroll_by(ROW_H * d)
		return list.scroll != before
	cursor = clampi(cursor, 0, acts.size() - 1)
	var b := acts[cursor]
	if d > 0:
		if cursor < acts.size() - 1:
			cursor += 1
			_show(acts[cursor])
			return true
		list.scroll_by(ROW_H)
		return list.scroll != before
	var top := group_top(b)
	if top < list.scroll:
		list.scroll_to(maxf(top, list.scroll - ROW_H))
		return list.scroll != before
	if cursor > 0:
		cursor -= 1
		_show(acts[cursor])
		return true
	return false


## 포인터로 누른 단추로 커서를 옮긴다(보급 줄 안의 단추만).
func _point(b: PartyButton) -> void:
	var k := actionable().find(b)
	if k >= 0:
		cursor = k


## 키보드 Enter: 커서 단추가 하는 일을 한다(단추 누르기와 같은 일, 입력은 이 하나로 센다).
func _press(b: PartyButton) -> bool:
	if b == supply_button:
		return dispatch("supply_toggle", null)
	var k := plus_buttons.find(b)
	if k >= 0:
		return dispatch("supply", menu.state.defs.battle.equipment_ids[k])
	k = exp_buttons.find(b)
	if k >= 0:
		return dispatch("exp_100", k)
	k = next_buttons.find(b)
	if k >= 0:
		return dispatch("exp_next", k)
	return false


## 커서 단추를 보이게: 대원의 「경험치 +100」「다음 레벨까지」는 위의 그 대원 이름 줄까지 함께(어느 대원에게 주는지 보이게,
## P3 검토 2차). 다른 단추는 그 단추만.
func _show(b: Control) -> void:
	list.ensure_visible(group_top(b), b.position.y + b.size.y)


## 단추가 속한 묶음의 위 끝(목록 내용 좌표): 대원 경험치 단추면 그 대원 이름 줄 위, 아니면 단추 위.
func group_top(b: Control) -> float:
	if exp_buttons.has(b) or next_buttons.has(b):
		return b.position.y - ROW_H - ROW_GAP
	return b.position.y


func refresh() -> void:
	if menu.state == null:
		return
	_used = 0
	_label_used = 0
	var defs := menu.state.defs
	frame.show_title(menu.texts.t("camp.cmd.items"))
	_refresh_banner()
	frame.panel.show_member(menu, menu.member, null, -1)
	var w := list.size.x
	var y := 0.0
	supply_button.visible = menu.debug
	if menu.debug:
		supply_button.position = Vector2(0, y)
		supply_button.text = menu.texts.t("party.supply")
		supply_button.checked = supply_open
		y += SUPPLY_SIZE.y + ROW_GAP * 3
	var ids := defs.battle.equipment_ids
	while plus_buttons.size() < ids.size():
		var k := plus_buttons.size()
		plus_buttons.append(_press_button("Supply_%d" % k, PLUS_SIZE, "supply", ids[k]))
	var n := menu.state.party.members.size()
	while exp_buttons.size() < n:
		var k := exp_buttons.size()
		exp_buttons.append(_press_button("Exp_%d" % k, EXP_SIZE, "exp_100", k))
		next_buttons.append(_press_button("ExpNext_%d" % k, EXP_SIZE, "exp_next", k))
	var show_supply := menu.debug and supply_open
	for k in plus_buttons.size():
		var b := plus_buttons[k]
		b.visible = show_supply and k < ids.size()
		if not b.visible:
			continue
		var bag := int(menu.state.gear_bag.get(ids[k], 0))
		_row(Vector2(0, y), Vector2(w - PLUS_SIZE.x - 8, ROW_H), menu.item_name(ids[k]), menu.texts.t("party.count", {"n": bag}), _fits_text(defs.battle.equip(ids[k])))
		b.position = Vector2(w - PLUS_SIZE.x, y)
		b.text = menu.texts.t("party.supply.plus")
		y += ROW_H + ROW_GAP
	for k in exp_buttons.size():
		var vis := show_supply and k < n
		exp_buttons[k].visible = vis
		next_buttons[k].visible = vis
		if not vis:
			continue
		var m := menu.state.party.members[k]
		_row(Vector2(0, y), Vector2(w, ROW_H), menu.member_name(k), menu.texts.t("party.level", {"level": m.level}), menu.texts.t("party.exp", {"exp": m.exp}))
		y += ROW_H + ROW_GAP
		var bw := floorf((w - 8.0) / 2.0)
		exp_buttons[k].position = Vector2(0, y)
		exp_buttons[k].size = Vector2(bw, EXP_SIZE.y)
		exp_buttons[k].text = menu.texts.t("party.supply.exp")
		next_buttons[k].position = Vector2(w - bw, y)
		next_buttons[k].size = Vector2(bw, EXP_SIZE.y)
		next_buttons[k].text = menu.texts.t("party.supply.next")
		next_buttons[k].dimmed = m.level >= defs.battle.growth.level_cap
		y += EXP_SIZE.y + ROW_GAP * 3
	if show_supply:
		y += ROW_GAP * 4
	# 장비 가방
	_label(Vector2(8, y), menu.texts.t("party.items.gear"))
	y += 40
	var any := false
	for id in ids:
		var c := int(menu.state.gear_bag.get(id, 0))
		if c < 1:
			continue
		any = true
		_row(Vector2(0, y), Vector2(w, ROW_H), menu.item_name(id), menu.texts.t("party.count", {"n": c}), _fits_text(defs.battle.equip(id)))
		y += ROW_H + ROW_GAP
	if not any:
		_row(Vector2(0, y), Vector2(w, ROW_H), menu.texts.t("party.items.none"), "", "", true)
		y += ROW_H + ROW_GAP
	y += 12
	# 소재
	_label(Vector2(8, y), menu.texts.t("party.items.materials"))
	y += 40
	var mats: Array = menu.state.materials.keys()
	mats.sort()
	for id in mats:
		_row(Vector2(0, y), Vector2(w, ROW_H), menu.texts.t(str(id)), menu.texts.t("party.count", {"n": int(menu.state.materials[id])}), "")
		y += ROW_H + ROW_GAP
	if mats.is_empty():
		_row(Vector2(0, y), Vector2(w, ROW_H), menu.texts.t("party.items.none"), "", "", true)
		y += ROW_H + ROW_GAP
	for j in range(_used, _rows.size()):
		_rows[j].visible = false
	for j in range(_label_used, _labels.size()):
		_labels[j].visible = false
	list.set_content_height(y + 8)
	var acts := actionable()
	cursor = clampi(cursor, 0, maxi(0, acts.size() - 1))
	for b in [supply_button] + plus_buttons + exp_buttons + next_buttons:
		(b as PartyButton).selected = false
	for k in acts.size():
		acts[k].selected = k == cursor


## 설명 띠: 화면 설명 + 안내(경험치 최대 등).
func _refresh_banner() -> void:
	frame.banner.show_lines(menu.texts.t("camp.desc.items"), menu.notice, not menu.notice.is_empty())


func notice_changed() -> void:
	if menu.state != null:
		_refresh_banner()


## 낄 수 있는 직업(지금 파티의 직업 가운데, 파티 순서).
func _fits_text(e: BattleDb.EquipDef) -> String:
	var names: Array[String] = []
	var seen := {}
	for cid in menu.state.defs.party.class_ids:
		if seen.has(cid):
			continue
		seen[cid] = true
		var c: BattleDb.ClassDef = menu.state.defs.battle.classes.get(cid)
		if c != null and e.fits(c):
			names.append(menu.texts.t(c.name_key))
	return "·".join(names)


func _row(pos: Vector2, sz: Vector2, main: String, right_text: String, note_text: String, dim: bool = false) -> void:
	var r: PartyButton
	if _used < _rows.size():
		r = _rows[_used]
	else:
		r = PartyButton.new()
		r.name = "Line_%d" % _rows.size()
		r.align_left = true
		r.skin = "fac"
		r.mouse_filter = MOUSE_FILTER_IGNORE  # 읽기만: 누르기·끌기는 뒤의 목록 영역이 받는다
		list.content.add_child(r)
		list.content.move_child(r, 0)
		_rows.append(r)
	_used += 1
	r.visible = true
	r.position = pos
	r.size = sz
	r.show_row(main, right_text, note_text, dim)


func _label(pos: Vector2, t: String) -> void:
	var l: Label
	if _label_used < _labels.size():
		l = _labels[_label_used]
	else:
		l = Label.new()
		l.mouse_filter = MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", UiTheme.SHOP_SECTION_TEXT)
		list.content.add_child(l)
		_labels.append(l)
	_label_used += 1
	l.visible = true
	l.position = pos
	l.text = t
