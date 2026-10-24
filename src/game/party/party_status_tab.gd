## 캠프 「상태」 화면(07 §9.2, M2.7 R2, 읽기만): 원작 HD 상태 화면(gs2_653218·653223·653241)을 어둡게 한 화면 전체 3D 시야 위에 옮긴다.
## 위 줄: 이름 칸(밝은 판, 양 끝 앞·다음 대원 단추 = 원작 L·R) + Lv 띠(Lv·누적 경험치·남은 SP) + 정보 띠(HP·TP, 다음 레벨까지 + 막대).
## 왼쪽 열: 직업 문패, 능력치 8줄(이름 상자 + 합계 + 노랑 막대), 공격·방어 넷(판 둘씩 두 줄), 장비 4칸.
## 원작에 자리가 없는 「기본 / 패시브 / 장비」 나눔(GrowthRules.profile 의 breakdown)은 오른쪽 아래 「내역」 단추(원작 「Ⓐ SKILL」 안내 자리,
## 키 V)로 같은 능력치 줄의 막대 칸을 세 값으로 바꿔 보인다(다시 누르면 막대). 고른 보기는 대원을 넘겨도 남고 캠프를 다시 열면 막대로.
## 오른쪽 큰 초상(원작 그림 자리: 위 띠 아래 ~ 화면 아래 끝, 받는 배율 문패 뒤. 자리표시는 직업색 모양 + 첫 글자, 그림은 M3),
## 오른쪽 아래 문패(원작 FORCE·LIMIT 자리)에 받는 배율(1000 이 아닌 것만).
## 자리는 모두 앵커: 왼쪽 묶음은 왼쪽 위, 초상·받는 배율 문패·「내역」은 오른쪽, 「뒤로」는 오른쪽 위.
class_name PartyStatusTab
extends Control

const STAT_ROWS := ["max_hp", "max_tp", "STR", "INT", "VIT", "WIS", "AGI", "LUC"]
## 직업 레벨 표의 키(막대 끝 = 상한 레벨의 기본값).
const LEVEL_KEYS := {"max_hp": "hp", "max_tp": "tp"}
const RECEIVED := [["resist", "element."], ["ailment_vuln", "ailment."], ["bind_vuln", "bind."]]
## 위 줄(원작 y 0~118): 이름 칸, Lv 띠, 정보 띠(MemberHeader).
const TOP_H := MemberHeader.H
## 왼쪽 열(원작 x 40~420): 직업 문패, 능력치 줄, 공격·방어 판, 장비 줄.
const CLASS_PLATE := Rect2(40, 130, 380, 44)
const STAT_Y := 190.0
const STAT_PITCH := 31.0
const STAT_H := 28.0
const STAT_X := 40.0
const STAT_W := 380.0
const NAME_BOX_W := 100.0
const GEAR_Y := 448.0
const GEAR_H := 34.0
const GEAR_W := 186.0
const GEAR_GAP := 8.0
const GEAR_LABEL_W := 92.0
const EQUIP_Y := 532.0
const EQUIP_PITCH := 38.0
const EQUIP_H := 34.0
const LEFT_W := 440.0
## 나눔 보기(막대 칸을 세 값으로): 칸 폭, 머리 글자 줄(직업 문패와 첫 능력치 줄 사이).
const SPLIT_COL := 60.0
const SPLIT_HEAD_Y := 187.0
## 초상(오른쪽, 위 띠 아래 ~ 아래 끝)·받는 배율 문패(「내역」 위)·「내역」(오른쪽 아래)·「뒤로」.
const PORTRAIT_W := 540.0
const PORTRAIT_RIGHT := 16.0
const SIDE_W := 240.0
const SIDE_EDGE := 24.0
const SIDE_LINE := 28.0
const HINT_SIZE := Vector2(120, 64)
const HINT_EDGE := 8.0

var menu: PartyMenu
var prev_button: PartyButton
var next_button: PartyButton
var back_button: PartyButton
## 「내역」(나눔 보기 켜고 끄기).
var split_button: PartyButton
## 막대 칸 대신 기본·패시브·장비를 보이는지(대원을 넘겨도 남고 reset 으로 끈다).
var split_view := false
## 위 줄(이름 칸·Lv 띠·정보 띠·앞/다음/뒤로 단추, 스킬 화면과 같은 부품).
var top: MemberHeader
var left: Control
var portrait: Control
var side: Control
## 마지막으로 그린 값(시험·디버그): name, class, level, exp, sp, hp, tp, next, next_ratio, stats{키: [합계, 기본, 패시브, 장비, 막대 비율]},
## gear{키: 값}, equip[[칸 이름, 장비 이름]], received[글].
var drawn := {}


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	top = MemberHeader.new()
	top.name = "StatusTop"
	add_child(top)
	top.build("Status", menu.texts.t("camp.back"))
	top.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	top.back.connect(func() -> void: menu.handle("back"))
	prev_button = top.prev_button
	next_button = top.next_button
	back_button = top.back_button
	left = _deco("StatusLeft", Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, LEFT_W, 720), _draw_left)
	# 초상은 받는 배율 문패 앞(트리 순서 = 그리는 순서: 문패가 초상 위).
	portrait = _deco("StatusPortrait", Vector2(1, 0), Vector2(1, 1), Vector4(-PORTRAIT_RIGHT - PORTRAIT_W, TOP_H, -PORTRAIT_RIGHT, 0), _draw_portrait)
	side = _deco("StatusSide", Vector2(1, 1), Vector2(1, 1), Vector4(-SIDE_EDGE - SIDE_W, -side_bottom() - 100, -SIDE_EDGE, -side_bottom()), _draw_side)
	split_button = PartyButton.new()
	split_button.name = "StatusSplit"
	split_button.text = menu.texts.t("camp.status.split")
	split_button.skin = "hint"
	add_child(split_button)
	PartyMenu.place(split_button, Vector2(1, 1), Vector2(1, 1), Vector4(-HINT_EDGE - HINT_SIZE.x, -HINT_EDGE - HINT_SIZE.y, -HINT_EDGE, -HINT_EDGE))
	split_button.activated.connect(func() -> void: menu.handle("split"))


## 받는 배율 문패 아래 끝(화면 아래에서): 「내역」 단추 위 12.
static func side_bottom() -> float:
	return HINT_EDGE + HINT_SIZE.y + 12.0


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4, painter: Callable) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	c.draw.connect(painter.bind(c))
	return c


func reset() -> void:
	split_view = false


func member_changed() -> void:
	pass


func context() -> String:
	return ""


func place(_s: Vector2) -> void:
	if menu.state != null and visible:
		refresh()


## split: 나눔 보기 켜고 끄기(「내역」·V). 한 화면에 다 들어가 내릴 것이 없다(↑·↓ 는 받되 아무것도 하지 않는다).
func dispatch(kind: String, _arg: Variant) -> bool:
	if kind == "split":
		split_view = not split_view
		return true
	return false


# ---- 자리(이 화면 기준, 시험용) ----

func name_tab_rect() -> Rect2:
	return top.name_tab_rect()


func lv_band_rect() -> Rect2:
	return top.lv_band_rect()


func info_rect() -> Rect2:
	return top.info_rect()


func class_rect() -> Rect2:
	return CLASS_PLATE


func stat_rect(i: int) -> Rect2:
	return Rect2(STAT_X, STAT_Y + i * STAT_PITCH, STAT_W, STAT_H)


func gear_rect(i: int) -> Rect2:
	return Rect2(STAT_X + (i % 2) * (GEAR_W + GEAR_GAP), GEAR_Y + (i / 2) * (GEAR_H + 6.0), GEAR_W, GEAR_H)


func equip_rect(slot: int) -> Rect2:
	return Rect2(STAT_X, EQUIP_Y + slot * EQUIP_PITCH, STAT_W, EQUIP_H)


## 나눔 보기에서 능력치 줄 i 의 칸 c(0 기본·1 패시브·2 장비). 막대 보기의 막대 자리와 같은 곳.
func split_cell(i: int, c: int) -> Rect2:
	var r := stat_rect(i)
	return Rect2(r.position.x + NAME_BOX_W + 90 + c * SPLIT_COL, r.position.y, SPLIT_COL, r.size.y)


func bar_rect(i: int) -> Rect2:
	var r := stat_rect(i)
	return Rect2(r.position.x + NAME_BOX_W + 90, r.position.y + 9, r.size.x - NAME_BOX_W - 100, 10)


func portrait_rect() -> Rect2:
	return portrait.get_rect()


func side_rect() -> Rect2:
	return side.get_rect()


# ---- 값 ----

func refresh() -> void:
	if menu.state == null:
		return
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var p := GrowthRules.profile(defs, i, m)
	var g := defs.battle.growth
	var c := defs.class_of(i)
	var t := menu.texts
	var at_cap := m.level >= g.level_cap
	var next_n := 0 if at_cap else g.cum(m.level + 1) - m.exp
	var span := 1 if at_cap else maxi(1, g.cum(m.level + 1) - g.cum(m.level))
	var stats := {}
	var cap_row: Dictionary = c.levels.get(g.level_cap, c.levels.get(m.level, {}))
	for k in STAT_ROWS:
		var b: Dictionary = p["breakdown"][k]
		var top_v := maxf(1.0, float(cap_row.get(LEVEL_KEYS.get(k, k), b["total"])))
		stats[k] = [int(b["total"]), int(b["base"]), int(b["passive"]), int(b["equip"]), clampf(float(b["total"]) / top_v, 0.0, 1.0)]
	var gear := {}
	for k in BattleLimits.GEAR:
		gear[k] = int(p["gear"][k])
	var equip := []
	for slot in m.equip.size():
		var id: String = m.equip[slot]
		equip.append([menu.slot_name(slot), menu.item_name(id) if not id.is_empty() else t.t("party.slot.empty")])
	var received: Array[String] = []
	for pair in RECEIVED:
		var table: Dictionary = p[pair[0]]
		for k in table:
			var v: int = table[k]
			if v != 1000:
				received.append(t.t("party.mult", {"name": t.t(pair[1] + k), "pct": PartyMenu.signed((v - 1000) / 10)}))
	if received.is_empty():
		received.append(t.t("party.received_none"))
	drawn = {
		"name": menu.member_name(i), "class": t.t(defs.party.class_ids[i]),
		"class_color": BattleCard.CLASS_COLORS.get(defs.party.class_ids[i], Color(0.7, 0.7, 0.7)),
		"level": t.t("party.level", {"level": m.level}), "exp": t.t("party.exp", {"exp": m.exp}),
		"sp": t.t("party.sp_left", {"sp": GrowthRules.sp_left(defs, m)}),
		"hp": t.t("party.hp", {"hp": m.hp, "max": m.max_hp}), "tp": t.t("party.tp", {"tp": m.tp, "max": m.max_tp}),
		"next": t.t("party.exp_max") if at_cap else t.t("party.exp_next", {"n": next_n}),
		"next_ratio": 1.0 if at_cap else clampf(float(m.exp - g.cum(m.level)) / span, 0.0, 1.0),
		"stats": stats, "gear": gear, "equip": equip, "received": received,
	}
	drawn["split_view"] = split_view
	top.name_text = drawn["name"]
	top.level_text = drawn["level"]
	top.level_extra = "%s    %s" % [drawn["exp"], drawn["sp"]]
	top.hp_text = drawn["hp"]
	top.tp_text = drawn["tp"]
	top.right_text = drawn["next"]
	top.right_ratio = drawn["next_ratio"]
	split_button.checked = split_view
	var side_h := 48.0 + received.size() * SIDE_LINE + 12.0
	side.offset_top = -side_bottom() - side_h
	for d in [top, left, portrait, side]:
		(d as Control).queue_redraw()


# ---- 그리기 ----

static func _txt(ci: Control, pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(ci.get_theme_default_font(), pos, s, align as HorizontalAlignment, w, fs, col)


func _draw_left(ci: Control) -> void:
	if drawn.is_empty():
		return
	var t := menu.texts
	# 직업 문패.
	UiTheme.fill_round(ci, CLASS_PLATE, UiTheme.ST_CLASS_PLATE, 22, UiTheme.ST_CLASS_EDGE, 2)
	_txt(ci, Vector2(CLASS_PLATE.position.x, CLASS_PLATE.get_center().y + 24 * 0.36), drawn["class"], 24, UiTheme.TEXT, CLASS_PLATE.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)
	# 능력치 줄: 이름 상자 | 합계 | 막대.
	for i in STAT_ROWS.size():
		var k: String = STAT_ROWS[i]
		var r := stat_rect(i)
		var v: Array = drawn["stats"][k]
		ci.draw_rect(r, UiTheme.ST_ROW)
		ci.draw_rect(Rect2(r.position, Vector2(NAME_BOX_W, r.size.y)), UiTheme.ST_ROW_NAME)
		var base := r.get_center().y + 0.36 * 18
		_txt(ci, Vector2(r.position.x + 8, base), t.t("stat." + k), 17, UiTheme.TEXT, NAME_BOX_W - 12)
		_txt(ci, Vector2(r.position.x + NAME_BOX_W, base), str(v[0]), 20, UiTheme.TEXT, 76, HORIZONTAL_ALIGNMENT_RIGHT)
		if not split_view:
			UiTheme.draw_gauge(ci, bar_rect(i), v[4], UiTheme.ST_BAR_FILL, UiTheme.ST_BAR_FILL, UiTheme.ST_BAR_TRACK)
			continue
		var vals := [str(v[1]), PartyMenu.signed(v[2]) if v[2] != 0 else "0", PartyMenu.signed(v[3]) if v[3] != 0 else "0"]
		for c in vals.size():
			var cell := split_cell(i, c)
			_txt(ci, Vector2(cell.position.x, base), vals[c], 18, UiTheme.ST_LV_TEXT if c == 0 else UiTheme.TEXT, cell.size.x - 6,
				HORIZONTAL_ALIGNMENT_RIGHT)
	if split_view:
		var cols := ["party.col.base", "party.col.passive", "party.col.equip"]
		for c in cols.size():
			var cell := split_cell(0, c)
			_txt(ci, Vector2(cell.position.x, SPLIT_HEAD_Y - 3.0), t.t(cols[c]), 13, UiTheme.SUB_TEXT, cell.size.x - 6, HORIZONTAL_ALIGNMENT_RIGHT)
	# 공격·방어 판(이름 | 값) 둘씩 두 줄.
	for i in BattleLimits.GEAR.size():
		var k: String = BattleLimits.GEAR[i]
		var r := gear_rect(i)
		ci.draw_rect(r, UiTheme.ST_GEAR_VALUE)
		ci.draw_rect(Rect2(r.position, Vector2(GEAR_LABEL_W, r.size.y)), UiTheme.ST_GEAR_LABEL)
		var base := r.get_center().y + 0.36 * 18
		_txt(ci, Vector2(r.position.x + 6, base), t.t("stat." + k), 16, UiTheme.TEXT, GEAR_LABEL_W - 10)
		_txt(ci, Vector2(r.position.x + GEAR_LABEL_W, base), str(drawn["gear"][k]), 22, UiTheme.TEXT, r.size.x - GEAR_LABEL_W - 12,
			HORIZONTAL_ALIGNMENT_RIGHT)
	# 장비 4칸(칸 이름 | 장비 이름).
	for slot in drawn["equip"].size():
		var r := equip_rect(slot)
		var e: Array = drawn["equip"][slot]
		ci.draw_rect(r, UiTheme.ST_EQUIP_ROW)
		ci.draw_rect(Rect2(r.position, Vector2(NAME_BOX_W, r.size.y)), UiTheme.ST_ROW_NAME)
		var base := r.get_center().y + 0.36 * 18
		_txt(ci, Vector2(r.position.x + 8, base), e[0], 15, UiTheme.SUB_TEXT, NAME_BOX_W - 12)
		_txt(ci, Vector2(r.position.x + NAME_BOX_W + 12, base), e[1], 18, UiTheme.TEXT, r.size.x - NAME_BOX_W - 20)


## 초상 자리표시(그림은 M3): 틀·이름 띠 없이 직업색 사람 모양(머리 + 어깨·몸, 아래로 갈수록 흐려진다)과 이름 첫 글자.
func _draw_portrait(ci: Control) -> void:
	if drawn.is_empty():
		return
	MemberPortrait.draw_silhouette(ci, Rect2(Vector2.ZERO, ci.size), drawn["class_color"], str(drawn["name"]).left(1), 220)


func _draw_side(ci: Control) -> void:
	if drawn.is_empty():
		return
	var r := Rect2(Vector2.ZERO, ci.size)
	var pts := UiTheme.chamfer_points(r, 18.0)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(UiTheme.ST_SIDE_TOP.lerp(UiTheme.ST_SIDE_BOTTOM, p.y / maxf(1.0, r.size.y)))
	ci.draw_polygon(pts, cols)
	var line := pts.duplicate()
	line.append(pts[0])
	ci.draw_polyline(line, UiTheme.ST_SIDE_EDGE, 2.0, true)
	_txt(ci, Vector2(0, 34), menu.texts.t("party.received"), 20, UiTheme.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in drawn["received"].size():
		_txt(ci, Vector2(16, 48 + (i + 1) * SIDE_LINE - 6), drawn["received"][i], 18, UiTheme.CARD_TP, r.size.x - 32)
