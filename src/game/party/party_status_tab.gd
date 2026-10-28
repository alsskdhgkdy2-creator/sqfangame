## 캠프 「상태」 화면(07 §9.2·§9.9 E2-a, 읽기만): 원작 III HD 상태 시트(research 08 §3.1, yt_eo3hd_b_05)를 캠프 무늬 판(CampBackdrop) 위에 옮긴다.
## 층(뒤 → 앞, 1280×720): 가운데 큰 초상(직업색 실루엣, 그림은 M3) → 위 대원 띠(MemberHeader: 이름 탭 + 「Lv n」 + HP·TP·다음 레벨 막대)
## → 왼쪽 열(SheetParts: 잎 장식 직업 문패 92~410·y 190~235, 능력치 여섯 줄 x 66~385·y 297~490, 공격·방어 두 줄 x 66~440·y 505~577,
## 장비 네 줄 아이콘 칸 + 이름 x 80~375·y 590~708) → 오른쪽 받는 배율 문패(원작 LIMIT 자리, 아래 끝 y 645) → 「내역」(원작 「Ⓐ SKILL」 자리).
## 원작에 자리가 없는 「기본 / 패시브 / 장비」 나눔(GrowthRules.profile 의 breakdown)은 「내역」·V 로 같은 능력치 줄의 막대 칸을 세 값으로 바꿔
## 보인다(칸은 x 440 까지, 머리 줄은 첫 줄 바로 위). 고른 보기는 대원을 넘겨도 남고 캠프를 다시 열면 막대로.
## 노랑 채움은 없다(원작처럼 읽기만 하는 화면: 노랑은 글자와 짧은 막대뿐). 「뒤로」 단추는 없다(키패드 「취소」·Esc·P, 07 §9.9 E1 ⑤).
## 자리는 앵커: 왼쪽 열은 왼쪽 위, 초상은 가운데(왼쪽 열과 겹치지 않게 자른다), 받는 배율 문패·「내역」은 오른쪽 아래. 키패드만 초상 앞에 겹친다.
class_name PartyStatusTab
extends Control

## 능력치 여섯 줄(07 §9.9 E1 ④: 최대 HP·TP 줄은 없다, HP·TP 는 위 띠에). 막대 끝 = 상한 레벨의 기본값.
const STAT_ROWS := ["STR", "INT", "VIT", "WIS", "AGI", "LUC"]
const RECEIVED := [["resist", "element."], ["ailment_vuln", "ailment."], ["bind_vuln", "bind."]]
## 위 줄(원작 y 0~118): 이름 칸, Lv 띠, 정보 띠(MemberHeader).
const TOP_H := MemberHeader.H
## 직업 문패 알약(잎은 양옆 SheetParts.LEAF_OUT).
const CLASS_PLATE := Rect2(92, 190, 318, 45)
## 능력치 줄(원작 66~385, 줄 28·간격 33).
const STAT_X := 66.0
const STAT_W := 319.0
const STAT_Y := 297.0
const STAT_PITCH := 33.0
const STAT_H := 28.0
## 「내역」 칸의 오른쪽 끝과 머리 줄 높이(첫 줄 바로 위).
const SPLIT_RIGHT := 440.0
const SPLIT_HEAD_H := 22.0
## 공격·방어 두 줄(공격·방어 / 마법 공격·마법 방어), x 66~440.
const GEAR_X := 66.0
const GEAR_W := 374.0
const GEAR_Y := 505.0
const GEAR_H := 34.0
const GEAR_PITCH := 38.0
## 장비 네 줄(아이콘 칸 80~120, 이름 칸 123~375).
const EQUIP_X := 80.0
const EQUIP_W := 295.0
const EQUIP_Y := 590.0
const EQUIP_PITCH := 30.0
const EQUIP_H := 28.0
## 왼쪽 열 장식 컨트롤 폭(오른쪽 잎 끝 458 까지 든다).
const LEFT_W := 464.0
## 초상: 가운데(원작 x 420~900 의 가운데 660 = W/2 + 20), 반폭 240. 왼쪽 열 끝(LEFT_W)과 겹치지 않게 왼쪽을 자른다.
const PORTRAIT_HALF := 240.0
const PORTRAIT_SHIFT := 20.0
## 받는 배율 문패: 오른쪽 끝 W − 28, 아래 끝 H − 75(1280×720 에서 645), 폭 240, 높이는 줄 수로. 위 끝은 「취소」「선택」 아래 + 8
## (H − 213, 720 에서 507) 보다 위로 가지 않는다.
const SIDE_W := 240.0
const SIDE_EDGE := 28.0
const SIDE_BOTTOM := 75.0
const SIDE_TOP_MIN := 213.0
const SIDE_HEAD_H := 40.0
const SIDE_LINE := 26.0
const SIDE_PAD := 10.0
const SIDE_FS := 18
const SIDE_FS_MIN := 12
const SIDE_TEXT_PAD := 16.0
const HINT_SIZE := Vector2(120, 64)
const HINT_EDGE := 8.0

var menu: PartyMenu
var prev_button: PartyButton
var next_button: PartyButton
## 「내역」(나눔 보기 켜고 끄기).
var split_button: PartyButton
## 막대 칸 대신 기본·패시브·장비를 보이는지(대원을 넘겨도 남고 reset 으로 끈다).
var split_view := false
## 위 줄(이름 칸·Lv 띠·정보 띠·앞/다음 단추, 스킬 화면과 같은 부품).
var top: MemberHeader
var left: Control
var portrait: Control
var side: Control
## 마지막으로 그린 값(시험·디버그): name, class, level, hp, tp, next, next_ratio, stats{키: [합계, 기본, 패시브, 장비, 막대 비율]},
## gear{키: 값}, equip[[아이콘, 장비 이름, 비었는지]], received[글], received_fs[글자 크기].
var drawn := {}


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# 트리 순서 = 그리는 순서(층 표): 초상 → 위 띠 → 왼쪽 열 → 받는 배율 문패 → 「내역」.
	portrait = _deco("StatusPortrait", Vector2(0.5, 0), Vector2(0.5, 1), Vector4(-PORTRAIT_HALF, TOP_H, PORTRAIT_HALF, 0), _draw_portrait)
	top = MemberHeader.new()
	top.name = "StatusTop"
	add_child(top)
	top.build("Status")
	top.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	prev_button = top.prev_button
	next_button = top.next_button
	left = _deco("StatusLeft", Vector2.ZERO, Vector2.ZERO, Vector4(0, 0, LEFT_W, 720), _draw_left)
	side = _deco("StatusSide", Vector2(1, 1), Vector2(1, 1), Vector4(-SIDE_EDGE - SIDE_W, -SIDE_BOTTOM - 100, -SIDE_EDGE, -SIDE_BOTTOM), _draw_side)
	split_button = PartyButton.new()
	split_button.name = "StatusSplit"
	split_button.text = menu.texts.t("camp.status.split")
	split_button.skin = "hint"
	add_child(split_button)
	PartyMenu.place(split_button, Vector2(1, 1), Vector2(1, 1), Vector4(-HINT_EDGE - HINT_SIZE.x, -HINT_EDGE - HINT_SIZE.y, -HINT_EDGE, -HINT_EDGE))
	split_button.activated.connect(func() -> void: menu.handle("split"))


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


## 초상 가로 자리(화면 폭 w): 가운데 W/2 + 20 ± 240, 왼쪽 끝은 왼쪽 열(LEFT_W) 오른쪽.
static func portrait_span(w: float) -> Vector2:
	var cx := w / 2.0 + PORTRAIT_SHIFT
	return Vector2(maxf(cx - PORTRAIT_HALF, LEFT_W), cx + PORTRAIT_HALF)


func place(s: Vector2) -> void:
	var span := portrait_span(s.x)
	portrait.offset_left = span.x - s.x / 2.0
	portrait.offset_right = span.y - s.x / 2.0
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


## 직업 문패 알약.
func class_rect() -> Rect2:
	return CLASS_PLATE


## 잎까지 포함한 직업 문패.
func class_extent() -> Rect2:
	return SheetParts.class_plate_extent(CLASS_PLATE)


func stat_rect(i: int) -> Rect2:
	return Rect2(STAT_X, STAT_Y + i * STAT_PITCH, STAT_W, STAT_H)


## 「내역」 보기의 줄 i(막대 칸 대신 세 칸이 SPLIT_RIGHT 까지).
func split_row_rect(i: int) -> Rect2:
	var r := stat_rect(i)
	return Rect2(r.position, Vector2(SPLIT_RIGHT - r.position.x, r.size.y))


## 「내역」 머리 줄(첫 줄 바로 위).
func split_head_rect() -> Rect2:
	return SheetParts.split_head_rect(stat_rect(0), SPLIT_RIGHT, SPLIT_HEAD_H)


## 공격·방어 줄 r(0 = 공격·방어, 1 = 마법 공격·마법 방어).
func gear_row_rect(row: int) -> Rect2:
	return Rect2(GEAR_X, GEAR_Y + row * GEAR_PITCH, GEAR_W, GEAR_H)


## 공격·방어 칸(BattleLimits.GEAR 차례 atk · matk · def · mdef): 공격·방어가 첫 줄, 마법 공격·마법 방어가 둘째 줄.
func gear_rect(i: int) -> Rect2:
	var k: String = BattleLimits.GEAR[i]
	var row := 0 if k in ["atk", "def"] else 1
	var col := 0 if k in ["atk", "matk"] else 1
	return SheetParts.gear_cells(gear_row_rect(row))[col]["cell"]


func equip_rect(slot: int) -> Rect2:
	return Rect2(EQUIP_X, EQUIP_Y + slot * EQUIP_PITCH, EQUIP_W, EQUIP_H)


## 나눔 보기에서 능력치 줄 i 의 칸 c(0 기본·1 패시브·2 장비). 막대 보기의 막대 칸 자리부터 SPLIT_RIGHT 까지.
func split_cell(i: int, c: int) -> Rect2:
	return SheetParts.split_cells(stat_rect(i), SPLIT_RIGHT)[c]


func bar_rect(i: int) -> Rect2:
	return SheetParts.stat_boxes(stat_rect(i))["bar"]


func portrait_rect() -> Rect2:
	return portrait.get_rect()


func side_rect() -> Rect2:
	return side.get_rect()


## 받는 배율 줄: 갈래(속성·상태 이상·결박)마다 한 줄, 보통이 아닌 것만 이어 쓴다. 모두 보통이면 「모두 보통」 한 줄.
static func received_lines(t: TextDb, p: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for pair in RECEIVED:
		var table: Dictionary = p[pair[0]]
		var parts: Array[String] = []
		for k in table:
			var v: int = table[k]
			if v != 1000:
				parts.append(t.t("party.mult", {"name": t.t(pair[1] + k), "pct": PartyMenu.signed((v - 1000) / 10)}))
		if not parts.is_empty():
			out.append("  ".join(parts))
	if out.is_empty():
		out.append(t.t("party.received_none"))
	return out


## 받는 배율 문패 높이(줄 n).
static func side_height(n: int) -> float:
	return SIDE_HEAD_H + n * SIDE_LINE + SIDE_PAD


## 줄 글자 크기: SIDE_FS 에서 문패 안 폭에 들 때까지 줄인다(가장 작게 SIDE_FS_MIN).
static func side_font_size(c: Control, line: String) -> int:
	var fs := SIDE_FS
	while fs > SIDE_FS_MIN and SheetParts.text_width(c, line, fs) > SIDE_W - 2.0 * SIDE_TEXT_PAD:
		fs -= 1
	return fs


# ---- 값 ----

func refresh() -> void:
	if menu.state == null:
		return
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var p := GrowthRules.profile(defs, i, m)
	var g := defs.battle.growth
	var c := defs.class_def(m)
	var t := menu.texts
	var at_cap := m.level >= g.level_cap
	var next_n := 0 if at_cap else g.cum(m.level + 1) - m.exp
	var span := 1 if at_cap else maxi(1, g.cum(m.level + 1) - g.cum(m.level))
	var stats := {}
	var cap_row: Dictionary = c.levels.get(g.level_cap, c.levels.get(m.level, {}))
	for k in STAT_ROWS:
		var b: Dictionary = p["breakdown"][k]
		var top_v := maxf(1.0, float(cap_row.get(k, b["total"])))
		stats[k] = [int(b["total"]), int(b["base"]), int(b["passive"]), int(b["equip"]), clampf(float(b["total"]) / top_v, 0.0, 1.0)]
	var gear := {}
	for k in BattleLimits.GEAR:
		gear[k] = int(p["gear"][k])
	var equip := []
	for slot in m.equip.size():
		var id: String = m.equip[slot]
		equip.append([SheetParts.kind_icon(defs, id), menu.item_name(id) if not id.is_empty() else t.t("party.slot.empty"), id.is_empty()])
	var received := received_lines(t, p)
	var received_fs: Array[int] = []
	for line in received:
		received_fs.append(side_font_size(side, line))
	drawn = {
		"name": menu.member_name(i), "class": t.t(m.class_id),
		"class_color": BattleCard.CLASS_COLORS.get(m.class_id, Color(0.7, 0.7, 0.7)),
		"level": t.t("party.level", {"level": m.level}),
		"hp": t.t("party.hp", {"hp": m.hp, "max": m.max_hp}), "tp": t.t("party.tp", {"tp": m.tp, "max": m.max_tp}),
		"next": t.t("party.exp_max") if at_cap else t.t("party.exp_next", {"n": next_n}),
		"next_ratio": 1.0 if at_cap else clampf(float(m.exp - g.cum(m.level)) / span, 0.0, 1.0),
		"stats": stats, "gear": gear, "equip": equip, "received": received, "received_fs": received_fs,
	}
	drawn["split_view"] = split_view
	top.name_text = drawn["name"]
	top.level_text = drawn["level"]
	top.hp_text = drawn["hp"]
	top.tp_text = drawn["tp"]
	top.right_text = drawn["next"]
	top.right_ratio = drawn["next_ratio"]
	split_button.checked = split_view
	side.offset_top = -SIDE_BOTTOM - minf(side_height(received.size()), SIDE_TOP_MIN - SIDE_BOTTOM)
	for d in [top, left, portrait, side]:
		(d as Control).queue_redraw()


# ---- 그리기 ----

static func _txt(ci: Control, pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(ci.get_theme_default_font(), pos, s, align as HorizontalAlignment, w, fs, col)


func _draw_left(ci: Control) -> void:
	SheetParts.begin(ci)  # 이번 그리기의 기록(시험이 본다)
	if drawn.is_empty():
		return
	var t := menu.texts
	SheetParts.draw_class_plate(ci, CLASS_PLATE, drawn["class"])
	# 능력치 줄(이름 칸 | 값 칸 | 막대), 「내역」 보기면 막대 칸 대신 기본·패시브·장비.
	for i in STAT_ROWS.size():
		var k: String = STAT_ROWS[i]
		var v: Array = drawn["stats"][k]
		if split_view:
			SheetParts.draw_split_row(ci, stat_rect(i), t.t("stat." + k), str(v[0]), split_values(v), SPLIT_RIGHT)
		else:
			SheetParts.draw_stat_row(ci, stat_rect(i), t.t("stat." + k), str(v[0]), v[4])
	if split_view:
		SheetParts.draw_split_head(ci, stat_rect(0), [t.t("party.col.base"), t.t("party.col.passive"), t.t("party.col.equip")], SPLIT_RIGHT,
			SPLIT_HEAD_H)
	# 공격·방어 / 마법 공격·마법 방어.
	var g: Dictionary = drawn["gear"]
	SheetParts.draw_gear_row(ci, gear_row_rect(0), [[t.t("stat.atk"), str(g["atk"])], [t.t("stat.def"), str(g["def"])]])
	SheetParts.draw_gear_row(ci, gear_row_rect(1), [[t.t("stat.matk"), str(g["matk"])], [t.t("stat.mdef"), str(g["mdef"])]])
	# 장비 네 줄(종류 아이콘 | 이름, 칸 이름 글 없음).
	for slot in drawn["equip"].size():
		var e: Array = drawn["equip"][slot]
		SheetParts.draw_equip_row(ci, equip_rect(slot), e[0], e[1], e[2])


## 「내역」 칸 글: 기본, 패시브(부호), 장비(부호). 0 은 「0」.
static func split_values(v: Array) -> Array[String]:
	return [str(v[1]), PartyMenu.signed(v[2]) if v[2] != 0 else "0", PartyMenu.signed(v[3]) if v[3] != 0 else "0"]


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
	_txt(ci, Vector2(0, 30), menu.texts.t("party.received"), 20, UiTheme.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in drawn["received"].size():
		var fs: int = drawn["received_fs"][i]
		_txt(ci, Vector2(SIDE_TEXT_PAD, SIDE_HEAD_H + i * SIDE_LINE + SIDE_LINE / 2.0 + fs * 0.36), drawn["received"][i], fs, UiTheme.CARD_TP,
			r.size.x - 2.0 * SIDE_TEXT_PAD)
