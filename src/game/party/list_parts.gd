## 캠프 하위 화면이 함께 쓰는 목록 창(부품 H)·설명 상자(부품 I)·명령 알약(부품 J)을 그리는 정적 함수(07 §9.9 E2, research 08 §4·§8,
## 원작 III HD 소지품 yt_eo3hd_05). 소지품(E2-b)이 쓰고, 장비(E2-c)가 오른쪽 목록 창·아래 설명 상자로 다시 쓴다.
## - H 목록 창: 어두운 테(#032439)의 양 끝이 괄호처럼 굽는다. 안에 줄(아이콘 칸 | 몸: 이름 왼쪽·개수 오른쪽), 오른쪽 스크롤 막대.
##   커서 줄은 뿌리 명령 커서의 노랑(CMD_PICK)에 어두운 글자: 화면의 노랑 채움 하나. 장비 화면용으로 「E」 표(낀 것)·흐린 줄도 그린다.
## - I 설명 상자: 같은 굽은 끝의 테 안에 어두운 머리(이름·종류 아이콘, 장비 화면은 오른쪽에 직업 표)와 밝은 몸(글 줄 넷까지).
##   줄이 몸 폭에 안 들면 글자를 18px 에서 12px 까지 줄인다(상태 받는 배율 줄과 같은 규칙).
## - J 명령 알약: 원작 「使う」「捨てる」 자리의 청록 알약. 커서면 노랑, 켜짐(checked)이면 하늘색.
## 그리기는 모두 SheetParts 의 기록 함수(_fill·_fill_round·_poly·_icon·_text)를 거쳐 같은 기록(SheetParts.record)에 남는다.
## 시험은 그 기록으로 노랑·아이콘·머리 채움·글자 크기를 본다. 자리 함수(*_rect·row_boxes)는 그리기와 시험이 같이 쓴다.
class_name ListParts
extends RefCounted

# ---- 색(원작 잼 근사, research 08 §4.1. 글자 대비 4.5:1 이상은 test_camp) ----
const FRAME := Color("032439")
## 굽은 끝의 밝은 선(괄호 모양이 보이게).
const FRAME_LINE := Color("2a7f86")
const ROW_BODY := Color("1a7e92")
## 줄 글자: 원작 흰 글자. #1A7E92 위 4.73:1(UiTheme.TEXT 는 4.24:1 이라 순백을 쓴다).
const ROW_TEXT := Color.WHITE
const ROW_DIM := Color("12596a")
const ROW_DIM_TEXT := UiTheme.SUB_TEXT
const CURSOR := UiTheme.CMD_PICK
const CURSOR_TEXT := UiTheme.CMD_PICK_TEXT
const ICON_CELL := SheetParts.ICON_BOX
const ICON := SheetParts.ICON
## 장비 화면의 「E」 표(낀 것): 어두운 남색 칸에 흰 글자(노랑 채움이 아니다).
const EQUIP_MARK := Color("001f37")
const EQUIP_MARK_TEXT := Color.WHITE
const SCROLL_TRACK := Color("0b2f45")
const SCROLL_THUMB := Color("39c3d6")
## 설명 상자: 머리 #001F37, 몸 #006797(원작 잼).
const DESC_HEAD := Color("001f37")
const DESC_BODY := Color("006797")
const DESC_TEXT := Color.WHITE
## 장비 화면 직업 표 칸(낄 수 있음 / 없음).
const TABLE_ON := SheetParts.CLASS_FILL
const TABLE_ON_TEXT := Color.WHITE
const TABLE_OFF := Color("0b2a3d")
const TABLE_OFF_TEXT := UiTheme.SUB_TEXT
## 알약: 원작 #228D9E 는 흰 글자 3.9:1 이라 4.5:1 이 될 때까지 어둡게(#1C7F90, 4.68:1). 누름은 더 어둡게, 테는 어두운 남색.
const PILL := Color("1c7f90")
const PILL_PRESSED := Color("145f6c")
const PILL_EDGE := Color("06232d")
const PILL_TEXT := Color.WHITE
## 알약 켜짐(보급 줄이 열림): 공용 checked 하늘색과 어두운 글자(노랑 아님).
const PILL_ON := UiTheme.BTN_CHECKED
const PILL_ON_PRESSED := UiTheme.BTN_CHECKED_PRESSED
const PILL_ON_TEXT := UiTheme.BTN_PICK_TEXT

# ---- 크기 ----
## 굽은 끝 폭(테 양쪽).
const END_W := 24.0
## 줄: 높이·간격, 창 안 위아래 여백, 왼쪽(굽은 끝 + 4)·오른쪽(굽은 끝 + 스크롤 막대 + 사이) 여백.
const ROW_H := 64.0
const ROW_GAP := 6.0
const PAD := 8.0
const ROWS_LEFT := 28.0
const SCROLL_W := 10.0
const SCROLL_GAP := 6.0
const SCROLL_RIGHT := 26.0
## 아이콘 칸(줄 높이 정사각형)과 몸 사이.
const ICON_GAP := 4.0
const ICON_INSET := 14.0
const ROW_FS := 20
const COUNT_FS := 18
const TEXT_PAD := 14.0
const MARK_BOX := 24.0
const MARK_FS := 16
## 설명 상자: 머리 높이, 테 안 위·아래 여백, 머리와 몸 사이, 줄 간격, 글자 크기(가장 작게 DESC_FS_MIN).
const HEAD_H := 38.0
const DESC_INSET := 6.0
const HEAD_GAP := 2.0
const LINE_H := 30.0
const HEAD_FS := 20
const DESC_FS := 18
const DESC_FS_MIN := 12
const DESC_TEXT_PAD := 16.0
const DESC_LINES := 4
const HEAD_ICON := 26.0
const TABLE_CELL := Vector2(56, 26)
const TABLE_GAP := 4.0
const TABLE_FS := 14
const PILL_FS := 22


# ---- 굽은 끝 테(H·I 같이) ----

## 테 다각형: 위아래는 곧고 양 끝은 괄호처럼 바깥으로 굽는다(끝 폭 END_W 안).
static func frame_polygon(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(r.end.x - END_W + END_W * sin(t * PI), r.position.y + r.size.y * t))
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(r.position.x + END_W - END_W * sin(t * PI), r.end.y - r.size.y * t))
	return pts


static func draw_frame(ci: CanvasItem, r: Rect2) -> void:
	var pts := frame_polygon(r)
	SheetParts._poly(ci, pts, FRAME)
	var half := pts.size() / 2
	for si in 2:
		var side := pts.slice(0, half) if si == 0 else pts.slice(half)
		var inner := PackedVector2Array()
		for p in side:
			inner.append(p + Vector2(-3.0 if si == 0 else 3.0, 0.0))
		ci.draw_polyline(inner, FRAME_LINE, 2.0, true)
		SheetParts._log(ci, {"kind": "line", "rect": SheetParts._bounds(inner), "color": FRAME_LINE})


# ---- H 목록 창 ----

## 줄 n 개가 다 보이는 창 높이(위아래 여백 포함).
static func list_height(n: int) -> float:
	return n * ROW_H + maxi(0, n - 1) * ROW_GAP + 2.0 * PAD


## 높이 h 안에 다 보이는 줄 수(가장 적게 1).
static func rows_for(h: float) -> int:
	return maxi(1, int(floor((h - 2.0 * PAD + ROW_GAP) / (ROW_H + ROW_GAP))))


## 창 r 안 줄 자리(끌어 내리는 영역).
static func rows_rect(r: Rect2) -> Rect2:
	var x0 := r.position.x + ROWS_LEFT
	var x1 := r.end.x - SCROLL_RIGHT - SCROLL_W - SCROLL_GAP
	return Rect2(x0, r.position.y + PAD, x1 - x0, r.size.y - 2.0 * PAD)


## 창 r 안 스크롤 막대 자리(오른쪽 굽은 끝 안쪽).
static func scroll_rect(r: Rect2) -> Rect2:
	return Rect2(r.end.x - SCROLL_RIGHT - SCROLL_W, r.position.y + PAD, SCROLL_W, r.size.y - 2.0 * PAD)


## 스크롤 막대의 손잡이(보이는 몫·위치). 넘치지 않으면 막대 전체.
static func thumb_rect(track: Rect2, scroll: float, content_h: float, view_h: float) -> Rect2:
	if content_h <= view_h + 0.5 or view_h <= 0.0:
		return track
	var h := maxf(24.0, track.size.y * view_h / content_h)
	var y := track.position.y + (track.size.y - h) * clampf(scroll / (content_h - view_h), 0.0, 1.0)
	return Rect2(track.position.x, y, track.size.x, h)


static func draw_list_window(ci: CanvasItem, r: Rect2, scroll: float, content_h: float) -> void:
	draw_frame(ci, r)
	var track := scroll_rect(r)
	SheetParts._fill_round(ci, track, SCROLL_TRACK, int(SCROLL_W / 2.0))
	SheetParts._fill_round(ci, thumb_rect(track, scroll, content_h, rows_rect(r).size.y), SCROLL_THUMB, int(SCROLL_W / 2.0))


## 줄 r 의 칸: icon(정사각형) · body · mark(「E」 표 자리, 몸 왼쪽).
static func row_boxes(r: Rect2) -> Dictionary:
	var icon := Rect2(r.position, Vector2(r.size.y, r.size.y))
	var body := Rect2(icon.end.x + ICON_GAP, r.position.y, maxf(0.0, r.end.x - icon.end.x - ICON_GAP), r.size.y)
	var mark := Rect2(body.position.x + 8.0, body.get_center().y - MARK_BOX / 2.0, MARK_BOX, MARK_BOX)
	return {"icon": icon, "body": body, "mark": mark}


## 이름 글 자리의 폭(개수 글과 「E」 표 자리를 뺀다).
static func name_room(c: Control, r: Rect2, right: String, equipped: bool) -> float:
	var body: Rect2 = row_boxes(r)["body"]
	var rw := SheetParts.text_width(c, right, COUNT_FS) + 12.0 if not right.is_empty() else 0.0
	return body.size.x - 2.0 * TEXT_PAD - rw - (MARK_BOX + 6.0 if equipped else 0.0)


## 아이콘 칸 안 아이콘 자리.
static func row_icon_rect(r: Rect2) -> Rect2:
	var ib: Rect2 = row_boxes(r)["icon"]
	return ib.grow(-ICON_INSET)


## 줄 하나. icon: VectorIcons 이름(""이면 빈 칸). cursor: 노랑 커서 줄. dim: 흐린 줄(못 고름·「없음」). equipped: 「E」 표(장비 화면).
## held: 누르는 중(밝은 테두리, 채움은 그대로).
static func draw_row(ci: Control, r: Rect2, icon: String, text: String, right: String, cursor: bool, dim: bool = false,
		equipped: bool = false, held: bool = false) -> void:
	var b := row_boxes(r)
	var body: Rect2 = b["body"]
	var fill := CURSOR if cursor else (ROW_DIM if dim else ROW_BODY)
	var fg := CURSOR_TEXT if cursor else (ROW_DIM_TEXT if dim else ROW_TEXT)
	SheetParts._fill(ci, b["icon"], ICON_CELL)
	SheetParts._fill(ci, body, fill)
	if not icon.is_empty():
		SheetParts._icon(ci, icon, row_icon_rect(r), ICON)
	var x := body.position.x + TEXT_PAD
	if equipped:
		var mk: Rect2 = b["mark"]
		SheetParts._fill(ci, mk, EQUIP_MARK)
		SheetParts._text(ci, Vector2(mk.position.x, mk.get_center().y + MARK_FS * 0.36), "E", MARK_FS, EQUIP_MARK_TEXT, mk.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		x = mk.end.x + 6.0
	var base := body.get_center().y + ROW_FS * 0.36
	if not right.is_empty():
		var rw := SheetParts.text_width(ci, right, COUNT_FS)
		SheetParts._text(ci, Vector2(body.end.x - TEXT_PAD - rw, body.get_center().y + COUNT_FS * 0.36), right, COUNT_FS, fg, rw + 1.0)
	SheetParts._text(ci, Vector2(x, base), text, ROW_FS, fg, name_room(ci, r, right, equipped))
	if held:
		UiTheme.draw_outline(ci, r, Color(1, 1, 1, 0.8), 2.0, 0.0)
		SheetParts._log(ci, {"kind": "outline", "rect": r, "color": Color(1, 1, 1, 0.8)})


# ---- I 설명 상자 ----

static func head_rect(r: Rect2) -> Rect2:
	return Rect2(r.position.x + END_W, r.position.y + DESC_INSET, r.size.x - 2.0 * END_W, HEAD_H)


static func body_rect(r: Rect2) -> Rect2:
	var top := r.position.y + DESC_INSET + HEAD_H + HEAD_GAP
	return Rect2(r.position.x + END_W, top, r.size.x - 2.0 * END_W, r.end.y - DESC_INSET - top)


## 몸 줄 글이 쓸 수 있는 폭.
static func line_room(r: Rect2) -> float:
	return body_rect(r).size.x - 2.0 * DESC_TEXT_PAD


## 줄 글자 크기: DESC_FS 에서 폭 w 에 들 때까지 줄인다(가장 작게 DESC_FS_MIN).
static func line_fs(c: Control, line: String, w: float) -> int:
	var fs := DESC_FS
	while fs > DESC_FS_MIN and SheetParts.text_width(c, line, fs) > w:
		fs -= 1
	return fs


## 직업 표 칸 자리(머리 오른쪽, 오른쪽에서 왼쪽으로 cells 개).
static func table_rects(r: Rect2, n: int) -> Array[Rect2]:
	var h := head_rect(r)
	var out: Array[Rect2] = []
	var x := h.end.x - 8.0 - n * TABLE_CELL.x - maxi(0, n - 1) * TABLE_GAP
	for i in n:
		out.append(Rect2(x + i * (TABLE_CELL.x + TABLE_GAP), h.get_center().y - TABLE_CELL.y / 2.0, TABLE_CELL.x, TABLE_CELL.y))
	return out


## 머리 이름이 쓸 수 있는 폭(아이콘과 직업 표 자리를 뺀다).
static func head_room(r: Rect2, table_n: int) -> float:
	var h := head_rect(r)
	var right := h.end.x
	if table_n > 0:
		right = table_rects(r, table_n)[0].position.x - 8.0
	return right - h.position.x - DESC_TEXT_PAD - HEAD_ICON - 16.0


## 설명 상자. title·icon: 머리(빈 title 이면 머리 글 없음). lines: 몸 줄(넷까지, 줄마다 폭에 맞춰 글자를 줄인다).
## table: 장비 화면 직업 표 [[글, 낄 수 있는지], …](머리 오른쪽).
static func draw_desc(ci: Control, r: Rect2, title: String, icon: String, lines: Array, table: Array = []) -> void:
	draw_frame(ci, r)
	var h := head_rect(r)
	var b := body_rect(r)
	SheetParts._fill(ci, h, DESC_HEAD)
	SheetParts._fill(ci, b, DESC_BODY)
	var room := head_room(r, table.size())
	if not title.is_empty():
		var tw := minf(SheetParts.text_width(ci, title, HEAD_FS), room)
		SheetParts._text(ci, Vector2(h.position.x + DESC_TEXT_PAD, h.get_center().y + HEAD_FS * 0.36), title, HEAD_FS, DESC_TEXT, room)
		if not icon.is_empty():
			var ix := h.position.x + DESC_TEXT_PAD + tw + 16.0
			SheetParts._icon(ci, icon, Rect2(ix, h.get_center().y - HEAD_ICON / 2.0, HEAD_ICON, HEAD_ICON), ICON)
	var cells := table_rects(r, table.size())
	for i in table.size():
		var on := bool(table[i][1])
		SheetParts._fill_round(ci, cells[i], TABLE_ON if on else TABLE_OFF, 4)
		SheetParts._text(ci, Vector2(cells[i].position.x, cells[i].get_center().y + TABLE_FS * 0.36), str(table[i][0]), TABLE_FS,
			TABLE_ON_TEXT if on else TABLE_OFF_TEXT, cells[i].size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var w := line_room(r)
	for i in mini(lines.size(), DESC_LINES):
		var s := str(lines[i])
		var fs := line_fs(ci, s, w)
		SheetParts._text(ci, Vector2(b.position.x + DESC_TEXT_PAD, b.position.y + 6.0 + (i + 1) * LINE_H - 8.0), s, fs, DESC_TEXT, w)


# ---- J 명령 알약 ----

## st: normal · pressed · selected(커서, 노랑) · checked(켜짐, 하늘색) · checked_pressed. selected 가 checked 보다 먼저다.
static func pill_colors(st: String) -> Array[Color]:
	match st:
		"selected", "selected_pressed":
			return [CURSOR, CURSOR_TEXT]
		"checked":
			return [PILL_ON, PILL_ON_TEXT]
		"checked_pressed":
			return [PILL_ON_PRESSED, PILL_ON_TEXT]
		"pressed":
			return [PILL_PRESSED, PILL_TEXT]
	return [PILL, PILL_TEXT]


static func draw_pill(ci: Control, r: Rect2, text: String, st: String) -> void:
	var cols := pill_colors(st)
	SheetParts._fill_round(ci, r, cols[0], int(r.size.y / 2.0), PILL_EDGE, 3)
	var room := r.size.x - r.size.y
	SheetParts._text(ci, Vector2(r.position.x + r.size.y / 2.0, r.get_center().y + PILL_FS * 0.36), text, PILL_FS, cols[1], room,
		HORIZONTAL_ALIGNMENT_CENTER)
