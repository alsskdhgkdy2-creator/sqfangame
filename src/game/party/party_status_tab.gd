## 파티 메뉴 상태 탭(07 §9.2, 읽기만): Lv·누적 경험치·「다음 레벨까지 n」(상한이면 「최대」)·남은 SP·HP·TP,
## 능력치 8줄을 「기본 / 패시브 / 장비 / 합계」로(GrowthRules.profile 의 breakdown), 공격·방어 넷, 받는 배율이 1000 이 아닌 것,
## 장비 4칸 이름. 넘치면 끌어·휠·↑↓로 내린다.
class_name PartyStatusTab
extends Control

const LINE_H := 34.0
const COL_W := 92.0
const STAT_ROWS := ["max_hp", "max_tp", "STR", "INT", "VIT", "WIS", "AGI", "LUC"]
const RECEIVED := [["resist", "element."], ["ailment_vuln", "ailment."], ["bind_vuln", "bind."]]

var menu: PartyMenu
var scroll_area: PartyScroll
var _labels: Array[Label] = []
var _used := 0


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	scroll_area = PartyScroll.new()
	scroll_area.name = "StatusScroll"
	add_child(scroll_area)


func reset() -> void:
	scroll_area.scroll_to(0.0)


func member_changed() -> void:
	scroll_area.scroll_to(0.0)


func context() -> String:
	return ""


func place(s: Vector2) -> void:
	scroll_area.position = Vector2(PartyMenu.TAB_X, PartyMenu.TOP)
	scroll_area.size = Vector2(s.x - PartyMenu.TAB_X - 8, s.y - PartyMenu.TOP - 8)
	if menu.state != null and visible:
		refresh()


func dispatch(kind: String, arg: Variant) -> bool:
	if kind == "cursor":
		var before := scroll_area.scroll
		scroll_area.scroll_by(LINE_H * 2.0 * (int(arg) if arg != null else 1))
		return scroll_area.scroll != before
	return false


func refresh() -> void:
	if menu.state == null:
		return
	_used = 0
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var p := GrowthRules.profile(defs, i, m)
	var g := defs.battle.growth
	var left := 0.0
	var right := maxf(520.0, scroll_area.size.x * 0.55)
	var y := 8.0
	_put(Vector2(left + 8, y), menu.member_name(i), 24)
	y += 40
	var next := menu.texts.t("party.exp_max") if m.level >= g.level_cap else menu.texts.t("party.exp_next", {"n": g.cum(m.level + 1) - m.exp})
	_put(Vector2(left + 8, y), "%s   %s   %s" % [menu.texts.t("party.level", {"level": m.level}), menu.texts.t("party.exp", {"exp": m.exp}), next])
	y += LINE_H
	_put(Vector2(left + 8, y), "%s   HP %s   TP %s" % [menu.texts.t("party.sp_left", {"sp": GrowthRules.sp_left(defs, m)}),
		menu.texts.t("party.hp", {"hp": m.hp, "max": m.max_hp}), menu.texts.t("party.tp", {"tp": m.tp, "max": m.max_tp})])
	y += LINE_H + 12
	# 능력치 표: 이름 | 기본 | 패시브 | 장비 | 합계
	var cols := ["party.col.base", "party.col.passive", "party.col.equip", "party.col.total"]
	for c in cols.size():
		_put(Vector2(left + 140 + c * COL_W, y), menu.texts.t(cols[c]), 16, Color(0.6, 0.78, 0.85), COL_W - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	y += LINE_H - 6
	for k in STAT_ROWS:
		var b: Dictionary = p["breakdown"][k]
		_put(Vector2(left + 8, y), menu.texts.t("stat." + k))
		var vals := [str(b["base"]), PartyMenu.signed(b["passive"]) if b["passive"] != 0 else "0",
			PartyMenu.signed(b["equip"]) if b["equip"] != 0 else "0", str(b["total"])]
		for c in vals.size():
			var col := Color(1.0, 0.9, 0.55) if c == 3 else Color(0.85, 0.93, 0.97)
			_put(Vector2(left + 140 + c * COL_W, y), vals[c], 18, col, COL_W - 8, HORIZONTAL_ALIGNMENT_RIGHT)
		y += LINE_H
	var bottom_left := y
	# 오른쪽 열: 공격·방어, 받는 배율, 장비
	y = 8.0
	_put(Vector2(right, y), menu.texts.t("party.gear"), 18, Color(0.6, 0.78, 0.85))
	y += LINE_H
	for k in BattleLimits.GEAR:
		_put(Vector2(right + 8, y), "%s  %d" % [menu.texts.t("stat." + k), p["gear"][k]])
		y += LINE_H
	y += 8
	_put(Vector2(right, y), menu.texts.t("party.received"), 18, Color(0.6, 0.78, 0.85))
	y += LINE_H
	var any := false
	for pair in RECEIVED:
		var table: Dictionary = p[pair[0]]
		for k in table:
			var v: int = table[k]
			if v == 1000:
				continue
			any = true
			_put(Vector2(right + 8, y), menu.texts.t("party.mult", {"name": menu.texts.t(pair[1] + k), "pct": PartyMenu.signed((v - 1000) / 10)}))
			y += LINE_H
	if not any:
		_put(Vector2(right + 8, y), menu.texts.t("party.received_none"), 18, Color(0.6, 0.7, 0.75))
		y += LINE_H
	y += 8
	_put(Vector2(right, y), menu.texts.t("party.equipped"), 18, Color(0.6, 0.78, 0.85))
	y += LINE_H
	for slot in m.equip.size():
		var id: String = m.equip[slot]
		var name := menu.item_name(id) if not id.is_empty() else menu.texts.t("party.slot.empty")
		_put(Vector2(right + 8, y), "%s  %s" % [menu.slot_name(slot), name])
		y += LINE_H
	for j in range(_used, _labels.size()):
		_labels[j].visible = false
	scroll_area.set_content_height(maxf(bottom_left, y) + 8)


func _put(pos: Vector2, t: String, fs: int = 18, col: Color = Color(0.88, 0.95, 1.0), w: float = 0.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l: Label
	if _used < _labels.size():
		l = _labels[_used]
	else:
		l = Label.new()
		l.mouse_filter = MOUSE_FILTER_IGNORE
		scroll_area.content.add_child(l)
		_labels.append(l)
	_used += 1
	l.visible = true
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align as HorizontalAlignment
	l.size = Vector2(w, 0) if w > 0.0 else Vector2.ZERO
	l.custom_minimum_size = Vector2(w, 0)
