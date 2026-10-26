## 캠프 상태 시트의 함께 쓰는 부품(07 §9.9 E2, research 08 §8 D·E·F·G, 원작 III HD 상태 yt_eo3hd_b_05): 그리기만 하는 정적 함수.
## 상태 화면(E2-a)이 쓰고, 장비 화면(E2-c, 같은 왼쪽 열)이 「바꾸면」 값·↑↓ 화살표·바꾸는 칸 표지를 더해 다시 쓴다.
## - D 직업 문패: 둥근 파랑 알약 + 양 끝 잎 장식(벡터, 어두운 청록).
## - E 능력치 줄: 이름 칸 | 값 칸 | 막대 칸(노란 짧은 막대). 「내역」 보기는 막대 칸 자리부터 오른쪽 끝(split_right)까지 세 칸, 머리 줄에는 어두운 받침.
## - F 공격·방어 줄: 칸마다 이름 상자 | 값 상자, 한 줄에 둘.
## - G 장비 줄: 아이콘 칸(종류 아이콘, 상점 줄과 같은 VectorIcons) | 이름 칸. 칸 이름 글은 없다. 빈 칸은 빈 아이콘 칸과 흐린 「비어 있음」.
## - 「바꾸면」(장비 화면): 원작 I HD 장비 시트(research 08 §5.1, 「攻撃 ↑ 23」)처럼 값 칸에 새 값만 오른쪽 맞춤, 왼쪽에 ↑·↓.
## 칸 자리는 *_boxes·*_cells 함수가 정하고 그리기와 시험이 같이 쓴다(글이 잘리지 않는지 = 글 폭 ≤ text_room).
## 그리기는 모두 _fill·_fill_round·_poly·_icon·_text 를 거친다: 그리는 그 호출이 캔버스 항목마다 기록(record)을 남기고, 시험은 그 기록을 본다
## (그리기를 빼면 기록도 빠지고, 색을 바꾸면 기록의 색도 바뀐다). 기록은 그리기 처음에 begin(ci) 로 비운다.
class_name SheetParts
extends RefCounted

# ---- 색(원작 잼 근사, research 08 §3.1. 글자 대비 4.5:1 이상은 test_camp) ----
const CLASS_FILL := Color("1873a9")
const CLASS_EDGE := Color("8fd8f0")
const CLASS_TEXT := UiTheme.TEXT
const LEAF := Color("0b3f46")
const LEAF_VEIN := Color("2a7f86")
const STAT_NAME_BOX := Color("032335")
const STAT_VALUE_BOX := Color("01658e")
const STAT_TRACK := Color("225675")
## 막대 칸 안쪽(노란 막대 뒤).
const STAT_BAR_BG := Color("16384d")
const STAT_BAR := Color("f0e060")
const STAT_TEXT := UiTheme.TEXT
## 「내역」 머리 줄 받침과 글자(그림 창 위에서도 대비 4.5:1).
const SPLIT_HEAD_BOX := STAT_NAME_BOX
const SPLIT_HEAD_TEXT := UiTheme.SUB_TEXT
const GEAR_LABEL_BOX := Color("022238")
const GEAR_VALUE_BOX := Color("02668e")
const ICON_BOX := Color("0a3968")
const ICON := Color("cfe6ff")
const EQUIP_NAME_BOX := Color("012339")
const EQUIP_EMPTY_TEXT := UiTheme.SUB_TEXT
const UP_COLOR := Color("8cffb0")
const DOWN_COLOR := Color("ffd0c4")
const MARK := UiTheme.BTN_PICK

# ---- 글자 크기·여백 ----
const CLASS_FS := 24
const STAT_NAME_FS := 17
const STAT_VALUE_FS := 20
const SPLIT_FS := 18
const SPLIT_HEAD_FS := 13
const GEAR_LABEL_FS := 16
const GEAR_VALUE_FS := 22
const EQUIP_FS := 17
const TEXT_PAD := 8.0
## 「바꾸면」 화살표: 값 칸 왼쪽 여백·칸 한 변(화살 모양 높이 = ARROW_GLYPH × 한 변 ≥ 14)·화살표와 값 사이.
const ARROW_LEFT := 6.0
const ARROW_BOX := 22.0
const ARROW_GAP := 2.0
## VectorIcons 화살 모양의 높이 비율(머리 −0.35 ~ 꼬리 +0.3).
const ARROW_GLYPH := 0.65

const RECORD := "sheet_drawn"


# ---- 그리기 기록 ----

## 이 캔버스 항목의 기록을 비운다(그리기 처음에 부른다).
static func begin(ci: CanvasItem) -> void:
	ci.set_meta(RECORD, [])


## 마지막 그리기의 기록: [{kind: fill|poly|icon|text|outline, rect, color, name?, text?, fs?}].
static func record(ci: CanvasItem) -> Array:
	return ci.get_meta(RECORD, [])


static func _log(ci: CanvasItem, e: Dictionary) -> void:
	if not ci.has_meta(RECORD):
		ci.set_meta(RECORD, [])
	(ci.get_meta(RECORD) as Array).append(e)


static func _fill(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r, col)
	_log(ci, {"kind": "fill", "rect": r, "color": col})


static func _fill_round(ci: CanvasItem, r: Rect2, col: Color, radius: int, edge: Color = Color(0, 0, 0, 0), edge_w: int = 0) -> void:
	UiTheme.fill_round(ci, r, col, radius, edge, edge_w)
	# 테두리가 있을 때만 그 색·굵기를 남긴다(테 없는 채움 기록은 그대로).
	if edge_w > 0:
		_log(ci, {"kind": "fill", "rect": r, "color": col, "edge": edge, "edge_w": edge_w})
	else:
		_log(ci, {"kind": "fill", "rect": r, "color": col})


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	_log(ci, {"kind": "poly", "rect": _bounds(pts), "color": col})


static func _icon(ci: CanvasItem, name: String, r: Rect2, col: Color) -> void:
	VectorIcons.draw(ci, name, r, col)
	_log(ci, {"kind": "icon", "rect": r, "color": col, "name": name})


static func _text(ci: CanvasItem, pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(_font(ci), pos, s, align as HorizontalAlignment, w, fs, col)
	_log(ci, {"kind": "text", "rect": Rect2(pos.x, pos.y - fs, w, fs * 1.3), "color": col, "text": s, "fs": fs})


static func _font(ci: CanvasItem) -> Font:
	return (ci as Control).get_theme_default_font() if ci is Control else ThemeDB.fallback_font


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


# ---- D 직업 문패 ----
## 잎 장식이 알약 밖으로 나가는 폭(원작 왼쪽 45~92, 오른쪽 410~460).
const LEAF_OUT := 48.0


## 잎 넷의 다각형(왼쪽 위·아래, 오른쪽 위·아래). 그리기와 class_plate_extent 가 같이 쓴다.
static func leaf_polygons(pill: Rect2) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var reach := LEAF_OUT - 2.0
	var h := pill.size.y / 2.0
	for side in [-1.0, 1.0]:
		var base := Vector2(pill.position.x if side < 0.0 else pill.end.x, pill.get_center().y)
		for up in [-1.0, 1.0]:
			var tip := base + Vector2(side * reach, up * h * 0.85)
			var nrm := Vector2(-(tip - base).y, (tip - base).x).normalized() * h * 0.62
			var pts := PackedVector2Array()
			for i in 9:
				var t := i / 8.0
				pts.append(base.lerp(tip, t) + nrm * sin(t * PI))
			for i in range(7, 0, -1):
				var t := i / 8.0
				pts.append(base.lerp(tip, t) - nrm * sin(t * PI) * 0.75)
			out.append(pts)
	return out


## 잎까지 포함한 문패 전체 자리(그리는 잎 꼭짓점과 알약을 모두 덮는다).
static func class_plate_extent(pill: Rect2) -> Rect2:
	var r := pill
	for pts in leaf_polygons(pill):
		r = r.merge(_bounds(pts))
	return r


## 문패 글이 들어가는 자리(둥근 끝 안쪽).
static func class_text_rect(pill: Rect2) -> Rect2:
	return pill.grow_individual(-pill.size.y / 2.0, 0, -pill.size.y / 2.0, 0)


static func draw_class_plate(ci: CanvasItem, pill: Rect2, text: String) -> void:
	for pts in leaf_polygons(pill):
		_poly(ci, pts, LEAF)
		ci.draw_line(pts[0], pts[0].lerp(pts[8], 0.8), LEAF_VEIN, 1.5, true)
	_fill_round(ci, pill, CLASS_FILL, int(pill.size.y / 2.0), CLASS_EDGE, 2)
	var tr := class_text_rect(pill)
	_text(ci, Vector2(tr.position.x, tr.get_center().y + CLASS_FS * 0.36), text, CLASS_FS, CLASS_TEXT, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ---- E 능력치 줄 ----
const STAT_NAME_W := 70.0
const STAT_VALUE_W := 89.0
## 값 칸과 막대 칸 사이(원작 225 → 236).
const STAT_BAR_GAP := 11.0
const STAT_BAR_H := 12.0


## 줄 r 의 칸: name · value · track(막대 칸 전체) · bar(막대가 그려지는 안쪽).
static func stat_boxes(r: Rect2) -> Dictionary:
	var name := Rect2(r.position, Vector2(STAT_NAME_W, r.size.y))
	var value := Rect2(name.end.x, r.position.y, STAT_VALUE_W, r.size.y)
	var tx := value.end.x + STAT_BAR_GAP
	var track := Rect2(tx, r.position.y, maxf(0.0, r.end.x - tx), r.size.y)
	var bar := Rect2(track.position.x + 4.0, r.get_center().y - STAT_BAR_H / 2.0, maxf(0.0, track.size.x - 8.0), STAT_BAR_H)
	return {"name": name, "value": value, "track": track, "bar": bar}


## 「내역」 보기의 세 칸(기본·패시브·장비): 막대 칸 자리부터 split_right 까지 고르게.
static func split_cells(r: Rect2, split_right: float) -> Array[Rect2]:
	var x0: float = stat_boxes(r)["track"].position.x
	var w := (split_right - x0) / 3.0
	var out: Array[Rect2] = []
	for c in 3:
		out.append(Rect2(x0 + c * w, r.position.y, w, r.size.y))
	return out


## 「내역」 머리 줄 받침(첫 줄 바로 위, 세 칸 폭).
static func split_head_rect(first_row: Rect2, split_right: float, head_h: float) -> Rect2:
	var x0: float = split_cells(first_row, split_right)[0].position.x
	return Rect2(x0, first_row.position.y - head_h, split_right - x0, head_h)


## after·dir 는 장비 화면(E2-c)용: after 가 있으면 값 칸에 그 새 값만, dir 이 ±1 이면 값 칸 왼쪽에 ↑·↓(arrow_rect).
static func draw_stat_row(ci: CanvasItem, r: Rect2, name: String, value: String, ratio: float, after: String = "", dir: int = 0) -> void:
	var b := stat_boxes(r)
	_fill(ci, b["name"], STAT_NAME_BOX)
	_fill(ci, b["value"], STAT_VALUE_BOX)
	_fill_round(ci, b["track"], STAT_TRACK, int(r.size.y / 2.0))
	_text(ci, _base(b["name"], STAT_NAME_FS, TEXT_PAD), name, STAT_NAME_FS, STAT_TEXT, (b["name"] as Rect2).size.x - 2.0 * TEXT_PAD)
	_draw_value(ci, b["value"], value, STAT_VALUE_FS, after, dir)
	var bar: Rect2 = b["bar"]
	_fill(ci, bar, STAT_BAR_BG)
	var fw := bar.size.x * clampf(ratio, 0.0, 1.0)
	if fw > 0.0:
		_fill(ci, Rect2(bar.position, Vector2(fw, bar.size.y)), STAT_BAR)


## 「내역」 보기 줄: 이름·값 칸은 같고, 막대 칸 대신 세 값(첫 칸은 노란 글자).
static func draw_split_row(ci: CanvasItem, r: Rect2, name: String, value: String, cells: Array, split_right: float) -> void:
	var b := stat_boxes(r)
	_fill(ci, b["name"], STAT_NAME_BOX)
	_fill(ci, b["value"], STAT_VALUE_BOX)
	var cs := split_cells(r, split_right)
	_fill_round(ci, Rect2(cs[0].position, Vector2(cs[2].end.x - cs[0].position.x, r.size.y)), STAT_TRACK, int(r.size.y / 2.0))
	_text(ci, _base(b["name"], STAT_NAME_FS, TEXT_PAD), name, STAT_NAME_FS, STAT_TEXT, (b["name"] as Rect2).size.x - 2.0 * TEXT_PAD)
	_draw_value(ci, b["value"], value, STAT_VALUE_FS, "", 0)
	for c in mini(cells.size(), 3):
		var cell: Rect2 = cs[c]
		_text(ci, _base(cell, SPLIT_FS, 0.0), str(cells[c]), SPLIT_FS, UiTheme.ST_LV_TEXT if c == 0 else STAT_TEXT, cell.size.x - TEXT_PAD,
			HORIZONTAL_ALIGNMENT_RIGHT)


## 「내역」 머리(첫 줄 바로 위): 어두운 받침(SPLIT_HEAD_BOX, 그림 창 위에서도 글자 대비) 위에 칸마다 오른쪽 맞춤.
static func draw_split_head(ci: CanvasItem, first_row: Rect2, heads: Array, split_right: float, head_h: float) -> void:
	var hb := split_head_rect(first_row, split_right, head_h)
	_fill_round(ci, hb, SPLIT_HEAD_BOX, int(head_h / 2.0))
	var cs := split_cells(first_row, split_right)
	for c in mini(heads.size(), 3):
		var cell: Rect2 = cs[c]
		_text(ci, Vector2(cell.position.x, hb.end.y - 5.0), str(heads[c]), SPLIT_HEAD_FS, SPLIT_HEAD_TEXT, cell.size.x - TEXT_PAD,
			HORIZONTAL_ALIGNMENT_RIGHT)


## 값 칸의 화살표 자리(왼쪽, 세로 가운데).
static func arrow_rect(box: Rect2) -> Rect2:
	return Rect2(box.position.x + ARROW_LEFT, box.get_center().y - ARROW_BOX / 2.0, ARROW_BOX, ARROW_BOX)


## 값 글이 쓸 수 있는 폭(dir 이 있으면 화살표 자리를 뺀다).
static func value_room(box: Rect2, dir: int) -> float:
	var left := ARROW_LEFT + ARROW_BOX + ARROW_GAP if dir != 0 else TEXT_PAD
	return box.size.x - left - TEXT_PAD


## 값 칸: after 가 있으면 새 값만(오른쪽 맞춤), dir 이 ±1 이면 왼쪽에 ↑·↓ 와 그 색.
static func _draw_value(ci: CanvasItem, box: Rect2, value: String, fs: int, after: String, dir: int) -> void:
	var col := STAT_TEXT if dir == 0 else (UP_COLOR if dir > 0 else DOWN_COLOR)
	var s := value if after.is_empty() else after
	var room := value_room(box, dir)
	_text(ci, Vector2(box.end.x - TEXT_PAD - room, box.get_center().y + fs * 0.36), s, fs, col, room, HORIZONTAL_ALIGNMENT_RIGHT)
	if dir != 0:
		_icon(ci, "up" if dir > 0 else "down", arrow_rect(box), col)


# ---- F 공격·방어 줄 ----
const GEAR_COL_GAP := 4.0
## 칸 안 이름 상자 비율(나머지가 값 상자).
const GEAR_LABEL_RATIO := 0.52


## 줄 r 을 cols 칸으로: [{cell, label, value}].
static func gear_cells(r: Rect2, cols: int = 2) -> Array[Dictionary]:
	var w := (r.size.x - (cols - 1) * GEAR_COL_GAP) / cols
	var out: Array[Dictionary] = []
	for c in cols:
		var cell := Rect2(r.position.x + c * (w + GEAR_COL_GAP), r.position.y, w, r.size.y)
		var lw := roundf(w * GEAR_LABEL_RATIO)
		out.append({"cell": cell, "label": Rect2(cell.position, Vector2(lw, r.size.y)),
			"value": Rect2(cell.position.x + lw, r.position.y, w - lw, r.size.y)})
	return out


## pairs: [[이름, 값(, 바꾸면, dir)], …] 칸 차례. 바꾸면이 있으면 값 상자에 새 값만, dir 이면 왼쪽에 ↑·↓.
static func draw_gear_row(ci: CanvasItem, r: Rect2, pairs: Array) -> void:
	var cs := gear_cells(r, pairs.size())
	for c in pairs.size():
		var p: Array = pairs[c]
		var lb: Rect2 = cs[c]["label"]
		var vb: Rect2 = cs[c]["value"]
		_fill(ci, lb, GEAR_LABEL_BOX)
		_fill(ci, vb, GEAR_VALUE_BOX)
		_text(ci, _base(lb, GEAR_LABEL_FS, TEXT_PAD), str(p[0]), GEAR_LABEL_FS, STAT_TEXT, lb.size.x - 2.0 * TEXT_PAD)
		var after: String = str(p[2]) if p.size() > 2 and p[2] != null else ""
		var dir: int = int(p[3]) if p.size() > 3 else 0
		_draw_value(ci, vb, str(p[1]), GEAR_VALUE_FS, after, dir)


# ---- G 장비 줄 ----
const ICON_W := 40.0
const ICON_GAP := 3.0
const ICON_INSET := 5.0


## 줄 r 의 칸: icon · name.
static func equip_boxes(r: Rect2) -> Dictionary:
	var icon := Rect2(r.position, Vector2(ICON_W, r.size.y))
	return {"icon": icon, "name": Rect2(icon.end.x + ICON_GAP, r.position.y, r.end.x - icon.end.x - ICON_GAP, r.size.y)}


## 아이콘 칸 안 아이콘 자리.
static func icon_rect(r: Rect2) -> Rect2:
	var ib: Rect2 = equip_boxes(r)["icon"]
	var s := minf(ib.size.x, ib.size.y) - 2.0 * ICON_INSET
	return Rect2(ib.get_center() - Vector2(s, s) / 2.0, Vector2(s, s))


## icon: VectorIcons 종류 아이콘 이름(빈 칸은 ""). empty 면 이름 칸에 흐린 글. mark 면 줄에 노란 테두리(장비 화면의 바꾸는 칸, 채움 아님).
static func draw_equip_row(ci: CanvasItem, r: Rect2, icon: String, text: String, empty: bool, mark: bool = false) -> void:
	var b := equip_boxes(r)
	var nb: Rect2 = b["name"]
	_fill(ci, b["icon"], ICON_BOX)
	_fill(ci, nb, EQUIP_NAME_BOX)
	if not empty and not icon.is_empty():
		_icon(ci, icon, icon_rect(r), ICON)
	_text(ci, _base(nb, EQUIP_FS, TEXT_PAD), text, EQUIP_FS, EQUIP_EMPTY_TEXT if empty else STAT_TEXT, equip_text_room(r))
	if mark:
		UiTheme.draw_outline(ci, r.grow(2.0), MARK, UiTheme.BTN_PICK_W, 0.0)
		_log(ci, {"kind": "outline", "rect": r.grow(2.0), "color": MARK})


## 장비 이름이 쓸 수 있는 폭.
static func equip_text_room(r: Rect2) -> float:
	return (equip_boxes(r)["name"] as Rect2).size.x - 2.0 * TEXT_PAD


## 장비 ID 의 종류 아이콘(상점 줄·종류 탭과 같은 ShopTabs.ICONS). 빈 ID·모르는 ID 는 "".
static func kind_icon(defs: GameDefs, item: String) -> String:
	if item.is_empty():
		return ""
	var e := defs.battle.equip(item)
	return str(ShopTabs.ICONS.get(e.kind, "")) if e != null else ""


# ---- 글 ----

static func _base(box: Rect2, fs: int, pad: float) -> Vector2:
	return Vector2(box.position.x + pad, box.get_center().y + fs * 0.36)


## 글 폭(시험·자리 계산).
static func text_width(c: Control, s: String, fs: int) -> float:
	return c.get_theme_default_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
