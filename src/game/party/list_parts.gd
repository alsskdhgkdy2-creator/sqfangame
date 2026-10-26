## 캠프 하위 화면이 함께 쓰는 목록 창(부품 H)·설명 상자(부품 I)·명령 알약(부품 J)을 그리는 정적 함수(07 §9.9 E2, research 08 §4·§8,
## 원작 III HD 소지품 yt_eo3hd_05). 소지품(E2-b)이 쓰고, 장비(E2-c)가 오른쪽 목록 창·아래 설명 상자로 다시 쓴다.
## - H 목록 창: 어두운 테(#032439)의 양 끝이 괄호처럼 굽는다. 안에 줄(아이콘 칸 | 몸: 이름 왼쪽·개수 오른쪽), 오른쪽 스크롤 막대.
##   커서 줄은 뿌리 명령 커서의 노랑(CMD_PICK)에 어두운 글자: 화면의 노랑 채움 하나. 장비 화면용으로 「E」 표(낀 것, 원작처럼 줄 오른쪽 끝)·흐린 줄도 그린다.
## - I 설명 상자: 같은 굽은 끝의 테 안에 어두운 머리(이름·종류 아이콘, 장비 화면은 오른쪽에 직업 표)와 밝은 몸(글 줄 넷까지).
##   줄이 몸 폭에 안 들면 글자를 18px 에서 12px 까지 줄인다(상태 받는 배율 줄과 같은 규칙).
## - J 명령 알약: 원작 「使う」「捨てる」 자리의 청록 알약. 커서면 노랑, 켜짐(checked)이면 하늘색.
## - K 알림 띠: 양 끝이 괄호처럼 굽은 청록 띠(원작 I HD 스킬 배움 알림 yt_eo1hd_b_04). 캠프 확인 창(BannerBox)이 쓴다(07 §9.9 E2-d).
## - I 의 "tree" 모양: 스킬 트리 설명 상자(원작 yt_eo1hd_b_03). 둥근 판·청록 테, 머리에 이름·레벨 탭·「Lv n」 막대, 몸에 줄을 칸으로(E2-d).
## - 둥근 판(draw_panel): "tree" = 스킬 트리 판(E2-d, 불투명 파랑), "option" = 기록 화면 판(E2-e, 원작 OPTION 의 반투명 청록 판·테).
## - OPTION 모양(E2-e, 원작 I HD OPTION yt_eo1hd_06): 어두운 줄 길(track) 위에 이름 알약(draw_option_row)과 값 알약(draw_pill 의 look "option").
##   커서 줄의 이름 알약이 노랑(화면의 노랑 채움 하나), 다른 알약 초록, 고른 값 밝은 하늘색, 못 누름 회색. 커서 값 알약은 노란 고리만.
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
## 흐린 줄 위 커서의 노란 테(흐린 커서 모양, 채움 아님).
const CURSOR_EDGE := UiTheme.BTN_PICK
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

# ---- 둥근 판(draw_panel) ----
## "tree"(스킬 트리 판, 원작 b_03 잼 #0C6A9E, 바깥 선 #013045, E2-d).
const PANEL_TREE := Color("0c6a9e")
const PANEL_TREE_OUTER := Color("013045")
const PANEL_TREE_RADIUS := 12
## "option"(기록 판, 원작 OPTION): 바깥 밝은 선 #6AC4CA, 테 #297078, 몸은 반투명 청록. 원작 몸 #449FB4 는 흰 도움말 글자 2.84:1 이라
## #145F6C 알파 0.85 로 어둡게(뒤가 흰색이어도 5.09:1, 검정이면 8.92:1).
const PANEL_OPT := Color(0x14 / 255.0, 0x5f / 255.0, 0x6c / 255.0, 0.85)
const PANEL_OPT_RIM := Color("297078")
const PANEL_OPT_EDGE := Color("6ac4ca")
const PANEL_OPT_RADIUS := 24
const PANEL_OPT_EDGE_W := 2
const PANEL_OPT_RIM_W := 4
const PANEL_OPT_TEXT := Color.WHITE

# ---- OPTION 알약·줄(원작 잼: 초록 #0E5F53 에 #7DF1DD 5.57:1, 길 #1C3F4F) ----
const OPT_PILL := Color("0e5f53")
const OPT_PILL_PRESSED := Color("0a4a40")
const OPT_TEXT := Color("7df1dd")
const OPT_CURSOR := UiTheme.CMD_PICK
const OPT_CURSOR_PRESSED := UiTheme.CMD_PICK_PRESSED
const OPT_CURSOR_TEXT := UiTheme.CMD_PICK_TEXT
## 고른 값: 캠프의 고른 명령과 같은 밝은 하늘색(원작 #3AB7BD 근사, 노랑 아님).
const OPT_CHOSEN := UiTheme.CMD_CHOSEN
const OPT_CHOSEN_PRESSED := Color("8be3ee")
const OPT_CHOSEN_TEXT := UiTheme.CMD_CHOSEN_TEXT
## 못 누름: 원작 회색 #545859 에 #7A7E80 은 1.76:1 이라 몸을 어둡게, 글자를 밝게(6.35:1).
const OPT_OFF := Color("3a4043")
const OPT_OFF_TEXT := Color("c4cacc")
const OPT_TRACK := Color("1c3f4f")
## 커서 값 알약의 노란 고리(채움 아님).
const OPT_RING := UiTheme.CMD_PICK
const OPT_RING_W := 3
## 줄 길 안쪽 여백(알약이 길 안에 든다), 이름 알약 글: 첫 줄·둘째 줄 크기, 왼쪽 여백.
const OPT_TRACK_INSET := 3.0
const OPT_LABEL_FS := 20
const OPT_LABEL_SUB_FS := 16
const OPT_LABEL_PAD := 24.0

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
## 「E」 표: 몸 오른쪽 끝에서 안쪽 여백, 왼쪽 개수 글과의 사이.
const MARK_INSET := 8.0
const MARK_GAP := 6.0
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
## 직업 표 칸: 머리글자 한 자(shop.badge.*)가 드는 작은 칸(원작 I HD 장비 설명 머리의 직업 칸). 1280 의 486 폭 상자에서도 가장 긴 장비 이름이 든다.
const TABLE_CELL := Vector2(28, 26)
const TABLE_GAP := 4.0
const TABLE_FS := 14
const PILL_FS := 22

# ---- K 알림 띠(원작 b_04 잼: 바깥 #00020D, 굽은 끝 회청 호 #46666E, 몸 #0C5C52, 흰 글자 7.87:1) ----
const BANNER_END := 40.0
const BANNER_EDGE := Color("00020d")
const BANNER_ARC := Color("46666e")
const BANNER_BODY := Color("0c5c52")
const BANNER_TEXT := Color.WHITE
## 몸 다각형의 안쪽 여백(가로·세로)과 굽은 끝 폭.
const BANNER_BODY_INSET := Vector2(19, 10)
const BANNER_BODY_END := 30.0

# ---- I 의 "tree" 모양(스킬 설명 상자, 원작 b_03 잼) ----
## 바깥 선 #09315B, 청록 테 #1EA1DB, 몸 #174C72. 머리는 원작 #3285B1 이 흰 글자 4.10:1 이라 #2C78A6(4.83:1)으로 어둡게.
const TREE_DESC_OUTER := Color("09315b")
const TREE_DESC_EDGE := Color("1ea1db")
const TREE_DESC_BODY := Color("174c72")
const TREE_DESC_HEAD := Color("2c78a6")
const TREE_DESC_TEXT := Color.WHITE
## 첫 줄(종류·TP·Lv): 원작 「マスタリースキル」의 시안.
const TREE_DESC_ACCENT := Color("7fe6ff")
## 레벨 탭: 안 배움 #96D3F8 에 짙은 글자, 배움·초안 #184D74 에 흰 글자(초안은 금색 테, 채움 아님).
const TREE_TAB_OFF := Color("96d3f8")
const TREE_TAB_OFF_TEXT := Color("04244a")
const TREE_TAB_ON := Color("184d74")
const TREE_TAB_ON_TEXT := Color.WHITE
const TREE_TAB_DRAFT_EDGE := UiTheme.BTN_PICK
## 「Lv n」 막대: 글 칸 #346697, 길 #212861, 배운 몫 시안, 초안 몫 연하늘(노랑 아님).
const TREE_BAR_LABEL := Color("346697")
const TREE_BAR_TRACK := Color("212861")
const TREE_BAR_LEARNED := Color("21d8f0")
const TREE_BAR_DRAFT := Color("a8f0ff")
const TREE_HEAD_INSET := 6.0
const TREE_HEAD_H := 38.0
const TREE_TEXT_PAD := 16.0
const TREE_HEAD_FS := 20
const TREE_HEAD_FS_MIN := 14
const TREE_TAB := Vector2(30, 28)
const TREE_TAB_X := 300.0
const TREE_TAB_GAP := 4.0
const TREE_TAB_FS := 16
const TREE_BAR := Vector2(200, 28)
const TREE_BAR_LABEL_W := 64.0
const TREE_BAR_RIGHT := 16.0
const TREE_BAR_FS := 16
## 몸 줄: 첫 줄 자리(위에서), 기본 줄 간격·글자·칸당 줄 수·칸 수.
const TREE_BODY_Y := 50.0
const TREE_LINE_H := 22.0
const TREE_LINE_FS := 16
const TREE_PER_COL := 5
const TREE_MAX_COLS := 3


# ---- 굽은 끝 테(H·I 같이) ----

## 테 다각형: 위아래는 곧고 양 끝은 괄호처럼 바깥으로 굽는다(끝 폭 end_w 안, 기본 END_W). K 알림 띠는 더 넓은 끝으로 같은 꼴을 쓴다.
static func frame_polygon(r: Rect2, end_w: float = END_W) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(r.end.x - end_w + end_w * sin(t * PI), r.position.y + r.size.y * t))
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(r.position.x + end_w - end_w * sin(t * PI), r.end.y - r.size.y * t))
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
	draw_scroll(ci, scroll_rect(r), scroll, content_h, rows_rect(r).size.y)


## 스크롤 막대(길과 손잡이): 목록 창과 스킬 트리 판이 같이 쓴다.
static func draw_scroll(ci: CanvasItem, track: Rect2, scroll: float, content_h: float, view_h: float) -> void:
	SheetParts._fill_round(ci, track, SCROLL_TRACK, int(SCROLL_W / 2.0))
	SheetParts._fill_round(ci, thumb_rect(track, scroll, content_h, view_h), SCROLL_THUMB, int(SCROLL_W / 2.0))


## 줄 r 의 칸: icon(정사각형) · body · mark(「E」 표 자리, 원작 I HD 장비처럼 몸 오른쪽 끝에서 MARK_INSET 안, 세로 가운데).
static func row_boxes(r: Rect2) -> Dictionary:
	var icon := Rect2(r.position, Vector2(r.size.y, r.size.y))
	var body := Rect2(icon.end.x + ICON_GAP, r.position.y, maxf(0.0, r.end.x - icon.end.x - ICON_GAP), r.size.y)
	var mark := Rect2(body.end.x - MARK_INSET - MARK_BOX, body.get_center().y - MARK_BOX / 2.0, MARK_BOX, MARK_BOX)
	return {"icon": icon, "body": body, "mark": mark}


## 개수 글이 끝나는 x(오른쪽 맞춤): 보통 몸 오른쪽 − TEXT_PAD, 「E」 표가 있으면 그 왼쪽 − MARK_GAP.
static func right_edge(r: Rect2, equipped: bool) -> float:
	var b := row_boxes(r)
	return (b["mark"] as Rect2).position.x - MARK_GAP if equipped else (b["body"] as Rect2).end.x - TEXT_PAD


## 이름 글 자리의 폭: 이름은 늘 몸 왼쪽 + TEXT_PAD 에서 시작하고, 개수 글(있으면)과 「E」 표(있으면) 앞에서 끝난다.
static func name_room(c: Control, r: Rect2, right: String, equipped: bool) -> float:
	var body: Rect2 = row_boxes(r)["body"]
	var rw := SheetParts.text_width(c, right, COUNT_FS) + 12.0 if not right.is_empty() else 0.0
	return right_edge(r, equipped) - rw - body.position.x - TEXT_PAD


## 아이콘 칸 안 아이콘 자리.
static func row_icon_rect(r: Rect2) -> Rect2:
	var ib: Rect2 = row_boxes(r)["icon"]
	return ib.grow(-ICON_INSET)


## 줄 하나. icon: VectorIcons 이름(""이면 빈 칸). cursor: 노랑 커서 줄. dim: 흐린 줄(못 고름·「없음」). equipped: 「E」 표(장비 화면).
## held: 누르는 중(밝은 테두리, 채움은 그대로). 흐린 줄에 커서가 서면 흐린 커서 모양(흐린 몸 + 노란 테, 노랑 채움 없음, 07 §9.9 E2-b).
static func draw_row(ci: Control, r: Rect2, icon: String, text: String, right: String, cursor: bool, dim: bool = false,
		equipped: bool = false, held: bool = false) -> void:
	var b := row_boxes(r)
	var body: Rect2 = b["body"]
	var fill := ROW_DIM if dim else (CURSOR if cursor else ROW_BODY)
	var fg := ROW_DIM_TEXT if dim else (CURSOR_TEXT if cursor else ROW_TEXT)
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
	var base := body.get_center().y + ROW_FS * 0.36
	if not right.is_empty():
		var rw := SheetParts.text_width(ci, right, COUNT_FS)
		SheetParts._text(ci, Vector2(right_edge(r, equipped) - rw, body.get_center().y + COUNT_FS * 0.36), right, COUNT_FS, fg, rw + 1.0)
	SheetParts._text(ci, Vector2(x, base), text, ROW_FS, fg, name_room(ci, r, right, equipped))
	if cursor and dim:
		UiTheme.draw_outline(ci, r.grow(-1.0), CURSOR_EDGE, UiTheme.BTN_PICK_W, 0.0)
		SheetParts._log(ci, {"kind": "outline", "rect": r.grow(-1.0), "color": CURSOR_EDGE})
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
## opts: 화면별 선택지. 없으면(소지품·장비) 아래 "bag" 모양 그대로. look = "tree" 이면 스킬 설명 모양(draw_tree_desc).
static func draw_desc(ci: Control, r: Rect2, title: String, icon: String, lines: Array, table: Array = [], opts: Dictionary = {}) -> void:
	if str(opts.get("look", "bag")) == "tree":
		draw_tree_desc(ci, r, title, lines, opts)
		return
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


# ---- I 의 "tree" 모양(스킬 설명 상자) ----

static func tree_head_rect(r: Rect2) -> Rect2:
	return Rect2(r.position.x + 5.0, r.position.y + TREE_HEAD_INSET, r.size.x - 10.0, TREE_HEAD_H)


## 레벨 탭 k(1부터).
static func tree_tab_rect(r: Rect2, k: int) -> Rect2:
	return Rect2(r.position.x + TREE_TAB_X + (k - 1) * (TREE_TAB.x + TREE_TAB_GAP), r.position.y + 11.0, TREE_TAB.x, TREE_TAB.y)


## 「Lv n」 막대 전체(머리 오른쪽), 그 글 칸과 길.
static func tree_bar_rect(r: Rect2) -> Rect2:
	return Rect2(r.end.x - TREE_BAR_RIGHT - TREE_BAR.x, r.position.y + 11.0, TREE_BAR.x, TREE_BAR.y)


static func tree_bar_label_rect(r: Rect2) -> Rect2:
	var b := tree_bar_rect(r)
	return Rect2(b.position, Vector2(TREE_BAR_LABEL_W, b.size.y))


static func tree_bar_track_rect(r: Rect2) -> Rect2:
	var b := tree_bar_rect(r)
	return Rect2(b.position.x + TREE_BAR_LABEL_W, b.position.y, b.size.x - TREE_BAR_LABEL_W, b.size.y)


## 막대 안 채움 [배운 몫, 초안 몫](길 안쪽 4 여백, 최대 레벨에 대한 비).
static func tree_bar_fills(r: Rect2, learned: int, drafted: int, max_level: int) -> Array[Rect2]:
	var t := tree_bar_track_rect(r).grow(-4.0)
	var unit := t.size.x / maxf(1.0, float(max_level))
	var a := Rect2(t.position, Vector2(unit * clampi(learned, 0, max_level), t.size.y))
	var b := Rect2(Vector2(a.end.x, t.position.y), Vector2(unit * clampi(drafted, 0, max_level - clampi(learned, 0, max_level)), t.size.y))
	return [a, b]


## 몸 줄 칸 수(1~TREE_MAX_COLS)와 칸 폭.
static func tree_cols(n: int, opts: Dictionary) -> int:
	return clampi(ceili(n / float(opts.get("per_col", TREE_PER_COL))), 1, int(opts.get("max_cols", TREE_MAX_COLS)))


static func tree_col_width(n: int, opts: Dictionary) -> float:
	return float(opts.get("room", 400.0)) / tree_cols(n, opts)


## 몸 줄 i 의 글 시작점(기준선, 상자 r 기준이 아닌 r 과 같은 좌표계).
static func tree_line_pos(r: Rect2, i: int, n: int, opts: Dictionary) -> Vector2:
	var per := int(opts.get("per_col", TREE_PER_COL))
	var lh := float(opts.get("line_h", TREE_LINE_H))
	return Vector2(r.position.x + TREE_TEXT_PAD + (i / per) * tree_col_width(n, opts), r.position.y + TREE_BODY_Y + (i % per + 1) * lh - 5.0)


## 머리 이름 글자 크기: TREE_HEAD_FS 에서 폭에 들 때까지(가장 작게 TREE_HEAD_FS_MIN).
static func tree_title_fs(c: Control, title: String, room: float) -> int:
	var fs := TREE_HEAD_FS
	while fs > TREE_HEAD_FS_MIN and SheetParts.text_width(c, title, fs) > room:
		fs -= 1
	return fs


## 스킬 설명 상자. opts: levels [배운, 초안, 최대](레벨 탭), bar [배운, 초안, 최대](「Lv n」 막대, bar_text 가 글),
## per_col·max_cols·line_h·room(몸 줄 칸), accent_first(첫 줄 시안).
static func draw_tree_desc(ci: Control, r: Rect2, title: String, lines: Array, opts: Dictionary) -> void:
	SheetParts._fill_round(ci, r, TREE_DESC_OUTER, 12)
	SheetParts._fill_round(ci, r.grow(-2.0), TREE_DESC_EDGE, 11)
	SheetParts._fill_round(ci, r.grow(-5.0), TREE_DESC_BODY, 9)
	var h := tree_head_rect(r)
	SheetParts._fill(ci, h, TREE_DESC_HEAD)
	var levels: Array = opts.get("levels", [])
	var name_right := (tree_tab_rect(r, 1).position.x if not levels.is_empty() else tree_bar_rect(r).position.x) - 12.0
	var room := name_right - (r.position.x + TREE_TEXT_PAD)
	if not title.is_empty():
		var fs := tree_title_fs(ci, title, room)
		SheetParts._text(ci, Vector2(r.position.x + TREE_TEXT_PAD, h.get_center().y + fs * 0.36), title, fs, TREE_DESC_TEXT, room)
	if not levels.is_empty():
		var learned := int(levels[0])
		var drafted := int(levels[1])
		for k in range(1, int(levels[2]) + 1):
			var tr := tree_tab_rect(r, k)
			var on := k <= learned + drafted
			SheetParts._fill(ci, tr, TREE_TAB_ON if on else TREE_TAB_OFF)
			if k > learned and on:
				UiTheme.draw_outline(ci, tr, TREE_TAB_DRAFT_EDGE, 2.0, 0.0)
				SheetParts._log(ci, {"kind": "outline", "rect": tr, "color": TREE_TAB_DRAFT_EDGE})
			SheetParts._text(ci, Vector2(tr.position.x, tr.get_center().y + TREE_TAB_FS * 0.36), str(k), TREE_TAB_FS,
				TREE_TAB_ON_TEXT if on else TREE_TAB_OFF_TEXT, tr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var bar: Array = opts.get("bar", [])
	if not bar.is_empty():
		var lr := tree_bar_label_rect(r)
		SheetParts._fill_round(ci, lr, TREE_BAR_LABEL, 6)
		SheetParts._text(ci, Vector2(lr.position.x, lr.get_center().y + TREE_BAR_FS * 0.36), str(opts.get("bar_text", "")), TREE_BAR_FS,
			TREE_DESC_TEXT, lr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		SheetParts._fill_round(ci, tree_bar_track_rect(r), TREE_BAR_TRACK, 6)
		var fills := tree_bar_fills(r, int(bar[0]), int(bar[1]), int(bar[2]))
		if fills[0].size.x > 0.0:
			SheetParts._fill(ci, fills[0], TREE_BAR_LEARNED)
		if fills[1].size.x > 0.0:
			SheetParts._fill(ci, fills[1], TREE_BAR_DRAFT)
	var n := lines.size()
	var cw := tree_col_width(n, opts)
	var fs_line := int(opts.get("fs", TREE_LINE_FS))
	for i in n:
		var col := TREE_DESC_ACCENT if i == 0 and bool(opts.get("accent_first", false)) else TREE_DESC_TEXT
		SheetParts._text(ci, tree_line_pos(r, i, n, opts), str(lines[i]), fs_line, col, cw - 12.0)


# ---- K 알림 띠 ----

static func banner_polygon(r: Rect2) -> PackedVector2Array:
	return frame_polygon(r, BANNER_END)


## 몸(글·단추가 놓이는 청록 면)의 사각형(굽은 끝 포함 경계).
static func banner_body_rect(r: Rect2) -> Rect2:
	return r.grow_individual(-BANNER_BODY_INSET.x, -BANNER_BODY_INSET.y, -BANNER_BODY_INSET.x, -BANNER_BODY_INSET.y)


## 알림 띠: 어두운 바깥 → 굽은 끝의 회청 호 → 어두운 선 → 청록 몸. 모두 양 끝이 굽은 같은 꼴(frame_polygon).
static func draw_banner(ci: CanvasItem, r: Rect2) -> void:
	SheetParts._poly(ci, banner_polygon(r), BANNER_EDGE)
	SheetParts._poly(ci, frame_polygon(r.grow(-4.0), BANNER_END - 2.0), BANNER_ARC)
	SheetParts._poly(ci, frame_polygon(r.grow_individual(-15.0, -7.0, -15.0, -7.0), BANNER_BODY_END + 2.0), BANNER_EDGE)
	SheetParts._poly(ci, frame_polygon(banner_body_rect(r), BANNER_BODY_END), BANNER_BODY)


# ---- 둥근 판 ----

## 판 r. look "tree": 스킬 트리 판(바깥 어두운 선 + 불투명 파랑). "option": 기록 판(밝은 바깥 선 + 테 + 반투명 청록 몸).
static func draw_panel(ci: CanvasItem, r: Rect2, look: String) -> void:
	if look == "option":
		_ring(ci, r, PANEL_OPT_EDGE, PANEL_OPT_EDGE_W, PANEL_OPT_RADIUS)
		SheetParts._fill_round(ci, r.grow(-PANEL_OPT_EDGE_W), PANEL_OPT, PANEL_OPT_RADIUS - PANEL_OPT_EDGE_W, PANEL_OPT_RIM, PANEL_OPT_RIM_W)
		return
	SheetParts._fill_round(ci, r, PANEL_TREE_OUTER, PANEL_TREE_RADIUS)
	SheetParts._fill_round(ci, r.grow(-2.0), PANEL_TREE, PANEL_TREE_RADIUS - 2)


## 채움 없는 둥근 고리(판의 바깥 선, 커서 값 알약의 노란 고리). 기록에는 outline 으로 남는다(채움이 아니다).
static func _ring(ci: CanvasItem, r: Rect2, col: Color, w: int, radius: int) -> void:
	UiTheme.fill_round(ci, r, Color(0, 0, 0, 0), radius, col, w)
	SheetParts._log(ci, {"kind": "outline", "rect": r, "color": col})


# ---- OPTION 줄 ----

## 줄 길 안 이름 알약의 사각형.
static func option_label_rect(track: Rect2, label_w: float) -> Rect2:
	return Rect2(track.position + Vector2(OPT_TRACK_INSET, OPT_TRACK_INSET), Vector2(label_w, track.size.y - 2.0 * OPT_TRACK_INSET))


## 이름 알약 글 줄의 [글자 크기, 기준선 y](알약 기준이 아닌 같은 좌표계). 줄 하나면 가운데, 둘이면 위 20·아래 16.
static func option_label_lines(label: Rect2, n: int) -> Array:
	if n <= 1:
		return [[OPT_LABEL_FS, label.get_center().y + OPT_LABEL_FS * 0.36]]
	return [[OPT_LABEL_FS, label.position.y + 27.0], [OPT_LABEL_SUB_FS, label.position.y + 51.0]]


## OPTION 줄 하나의 길과 이름 알약(값 알약은 ListButton 이 길 위에 그린다). st: 이름 알약 상태(normal · selected).
static func draw_option_row(ci: Control, track: Rect2, label_w: float, lines: Array, st: String) -> void:
	SheetParts._fill_round(ci, track, OPT_TRACK, int(track.size.y / 2.0))
	var lr := option_label_rect(track, label_w)
	var cols := pill_colors(st, "option")
	SheetParts._fill_round(ci, lr, cols[0], int(lr.size.y / 2.0))
	var spots := option_label_lines(lr, lines.size())
	for i in mini(lines.size(), spots.size()):
		SheetParts._text(ci, Vector2(lr.position.x + OPT_LABEL_PAD, spots[i][1]), str(lines[i]), spots[i][0], cols[1],
			lr.size.x - 2.0 * OPT_LABEL_PAD)


# ---- J 명령 알약 ----

## st: normal · pressed · selected(커서, 노랑) · checked(켜짐, 하늘색) · checked_pressed. selected 가 checked 보다 먼저다.
## look "option"(기록, E2-e): 초록·노랑·밝은 하늘색·회색(disabled) 한 벌. 기본 "camp" 는 소지품 알약 그대로.
static func pill_colors(st: String, look: String = "camp") -> Array[Color]:
	if look == "option":
		match st:
			"selected":
				return [OPT_CURSOR, OPT_CURSOR_TEXT]
			"selected_pressed":
				return [OPT_CURSOR_PRESSED, OPT_CURSOR_TEXT]
			"checked":
				return [OPT_CHOSEN, OPT_CHOSEN_TEXT]
			"checked_pressed":
				return [OPT_CHOSEN_PRESSED, OPT_CHOSEN_TEXT]
			"pressed":
				return [OPT_PILL_PRESSED, OPT_TEXT]
			"disabled":
				return [OPT_OFF, OPT_OFF_TEXT]
		return [OPT_PILL, OPT_TEXT]
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


## ring: 커서 값 알약의 노란 고리(OPTION 줄, 채움은 그 알약 상태 그대로).
static func draw_pill(ci: Control, r: Rect2, text: String, st: String, look: String = "camp", ring: bool = false) -> void:
	var cols := pill_colors(st, look)
	SheetParts._fill_round(ci, r, cols[0], int(r.size.y / 2.0), OPT_TRACK if look == "option" else PILL_EDGE, 3)
	var room := r.size.x - r.size.y
	SheetParts._text(ci, Vector2(r.position.x + r.size.y / 2.0, r.get_center().y + PILL_FS * 0.36), text, PILL_FS, cols[1], room,
		HORIZONTAL_ALIGNMENT_CENTER)
	if ring:
		_ring(ci, r, OPT_RING, OPT_RING_W, int(r.size.y / 2.0))
