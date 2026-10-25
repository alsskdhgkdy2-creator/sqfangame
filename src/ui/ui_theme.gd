## 공용 창·단추 모양 한 곳(M2.6 U6, 원작의 홀로 창처럼): 색과 그리기 규칙은 여기서만 정한다(StyleBoxFlat 도 여기서만 만든다).
## 창: 어두운 바깥 테두리 + 안쪽으로 들인 밝은 선(옅은 빛 번짐), 위 짙은 청록 → 아래 남색 세로 그라데이션, 모서리는 비스듬히 깎는다.
## 단추·줄: 같은 계열의 상태 모양(look). 평소는 어두운 채움 + 밝은 안쪽 선, 고른 것(커서)은 따뜻한 채움 + 어두운 글자에
## 더 굵은 바깥 테두리와 왼쪽 표시 막대(색 말고도 보이는 표시), 누름은 더 밝게, 켜진 것(지금 고른 설정·탭)은 청록 채움 + 어두운 글자,
## 못 누름은 흐린 채움 + 흐린 글자(커서가 오면 채움은 그대로 두고 따뜻한 테두리·표시 막대만).
## 색 견본·직업색 띠·HP 막대처럼 안의 색이 뜻을 가진 단추는 채움을 바꾸지 않는 테두리 모양(marked·checked_marked)을 쓴다.
## 글자 대비는 각 모양의 채움 위·아래 색과 그 모양의 글자색 짝마다 4.5:1 이상(시험이 이 상수로 본다). 채움은 모두 불투명이라
## 뒤에 무엇이 있어도 그 대비 그대로다.
## Godot Button·PanelContainer 는 Box(StyleBox)로, 직접 그리는 단추·창은 draw_button·draw_window 로 같은 paint 를 쓴다.
class_name UiTheme
extends RefCounted

## TP 막대 색(전투 대원 칸·탐색 상태 칸·파티 메뉴 대원 칸).
const TP_BAR := Color(0.4, 0.65, 1.0)

# ---- 창 ----
const WIN_TOP := Color(0.05, 0.15, 0.18)
const WIN_BOTTOM := Color(0.025, 0.05, 0.1)
const WIN_OUTER := Color(0.0, 0.015, 0.03)
const WIN_INNER := Color(0.38, 0.85, 0.95)
const WIN_GLOW := Color(0.38, 0.85, 0.95, 0.16)
const WIN_CHAMFER := 12.0
## 층 겹침(M2.6 2.5단계, research 04): 바탕 위에 뜬 반투명 카드(glass)·알림 띠·바탕 어둡게·문패.
## 반투명 채움 위 글자는 가장 나쁜 바탕(흰색) 위에 겹친 색(over_white)과 4.5:1 이상(시험).
const GLASS_ALPHA := 0.88
## 연출 알림·안내 띠(위쪽, 누르기를 받지 않는다).
const BANNER_FILL := Color(0.0, 0.02, 0.04, 0.8)
## 전투 바탕(3D 시야)을 어둡게(장면이 보이게 절반).
const BATTLE_DIM := Color(0, 0, 0, 0.5)
## 파티 메뉴 뒤 3D 시야를 어둡게(탐색 HUD 는 메뉴가 열린 동안 감춘다: 장면이 보이게 전투와 비슷하게).
const MENU_DIM := Color(0.0, 0.01, 0.02, 0.55)
## 문패(창 테두리에 걸치는 이름표): 높이·기울기·채움.
const PLATE_H := 30.0
const PLATE_SLANT := 12.0
const PLATE_PAD := 22.0
const PLATE_TOP := Color(0.09, 0.26, 0.31)
const PLATE_BOTTOM := Color(0.04, 0.12, 0.17)
## 반투명 카드 위 흐린 글자(전투 불능·못 고르는 대상).
const GLASS_DIM_TEXT := Color(0.7, 0.7, 0.72)
## 반투명 카드 위 「전투 불능」 글자.
const GLASS_DOWN_TEXT := Color(1.0, 0.58, 0.52)
## 창 위에 쓰는 글자: 머리(제목·묶음 머리), 본문, 흐린 본문.
const HEAD_TEXT := Color(1.0, 0.88, 0.5)
const TEXT := Color(0.9, 0.96, 1.0)
const SUB_TEXT := Color(0.7, 0.85, 0.9)

# ---- 단추 ----
const BTN_TOP := Color(0.1, 0.18, 0.22)
const BTN_BG := Color(0.06, 0.11, 0.15)
const BTN_OUTER := Color(0.0, 0.02, 0.04)
const BTN_BORDER := Color(0.36, 0.62, 0.7)
const BTN_TEXT := Color(0.9, 0.96, 1.0)
const BTN_SUB := Color(0.62, 0.82, 0.9)
const BTN_HELD_TOP := Color(0.18, 0.34, 0.42)
const BTN_HELD := Color(0.12, 0.25, 0.31)
const BTN_HELD_BORDER := Color(0.5, 0.9, 1.0)
const BTN_PICK_TOP := Color(1.0, 0.87, 0.47)
const BTN_PICK := Color(1.0, 0.8, 0.34)
const BTN_PICK_PRESSED_TOP := Color(1.0, 0.94, 0.68)
const BTN_PICK_PRESSED := Color(1.0, 0.9, 0.55)
const BTN_PICK_EDGE := Color(0.42, 0.26, 0.04)
const BTN_PICK_LINE := Color(1.0, 0.96, 0.82)
const BTN_PICK_TEXT := Color(0.1, 0.07, 0.02)
const BTN_PICK_SUB := Color(0.3, 0.19, 0.04)
const BTN_CHECKED_TOP := Color(0.64, 0.93, 0.98)
const BTN_CHECKED := Color(0.55, 0.88, 0.95)
const BTN_CHECKED_PRESSED_TOP := Color(0.78, 0.97, 1.0)
const BTN_CHECKED_PRESSED := Color(0.68, 0.94, 0.99)
const BTN_CHECKED_BORDER := Color(0.18, 0.42, 0.5)
const BTN_CHECKED_SUB := Color(0.07, 0.2, 0.25)
const BTN_DISABLED_BG := Color(0.06, 0.08, 0.1)
const BTN_DISABLED_BORDER := Color(0.22, 0.3, 0.34)
const BTN_DISABLED_TEXT := Color(0.52, 0.57, 0.62)
## 못 고르는 줄의 이유 글자(누름 채움 위에서는 더 밝게).
const BTN_REASON := Color(1.0, 0.62, 0.45)
const BTN_REASON_LIGHT := Color(1.0, 0.78, 0.62)
## 강조 글자(레벨·최대·초안 +n)와 좋음 글자(배울 수 있음 등). 어두운 채움 위 색이고, 밝은 채움 위에서는 그 모양의 어두운 글자.
const ACCENT_TEXT := Color(1.0, 0.86, 0.45)
const GOOD_TEXT := Color(0.55, 1.0, 0.7)
## 흐린 안내 글자(SP 모자람 등, 평소 채움 위).
const MUTED_TEXT := Color(0.62, 0.67, 0.72)
const BTN_CHAMFER := 8.0
const BTN_OUTER_W := 2.0
## 고른 것의 굵은 바깥 테두리.
const BTN_PICK_W := 3.0
## 왼쪽 표시 막대 폭.
const MARK_W := 5.0
## 바깥 테두리와 안쪽 선 사이.
const INNER_GAP := 2.0

## 단추 상태 이름. 직접 그리는 단추는 state_of 로 고르고, Godot Button 은 style_button 이 상태 상자로 나눠 둔다.
const STATES := ["normal", "pressed", "selected", "selected_pressed", "checked", "checked_pressed", "disabled", "disabled_selected",
	"marked", "marked_pressed", "checked_marked", "checked_marked_pressed"]

## 부품별 모양(「부품:상태」). 없는 상태는 공용 모양을 쓴다(고른 도구는 공용 따뜻한 커서 그대로).
## 지도 판 도구 열(원작 HD nin_02 의 파란 도구 칸)·「돌아가기」 밝은 알약.
const SKIN_LOOKS := ["tool:normal", "tool:pressed", "pill:normal", "pill:pressed",
	"cmd:normal", "cmd:pressed", "cmd:selected", "cmd:selected_pressed", "cmd:disabled", "cmd:disabled_selected",
	"hint:normal", "hint:pressed", "cmd:chosen",
	"skill:normal", "skill:pressed", "skill:selected", "skill:selected_pressed", "skill:disabled", "skill:disabled_selected",
	"fac:normal", "fac:pressed", "fac:selected", "fac:selected_pressed", "fac:disabled", "fac:disabled_selected", "fac:chosen",
	"tree:normal", "tree:pressed", "tree:selected", "tree:selected_pressed", "tree:disabled", "tree:disabled_selected",
	"shoptab:normal", "shoptab:pressed"]
## 전투 명령 목록(원작 HD 1868180_0e36b17e): 줄은 청록, 커서 줄은 노랑 + 어두운 글자, 못 고르는 줄은 어두운 초록 + 회색 글자.
const CMD_TOP := Color("00644c")
const CMD_BOTTOM := Color("00573f")
const CMD_PRESSED_TOP := Color("00785c")
const CMD_PRESSED := Color("006a51")
const CMD_TEXT := Color("e6fff6")
const CMD_PICK_TOP := Color("fcff50")
const CMD_PICK := Color("eef03c")
const CMD_PICK_PRESSED := Color("fdff8a")
const CMD_PICK_TEXT := Color("1a1a00")
const CMD_OFF := Color("1a3121")
const CMD_OFF_TEXT := Color("a8b4ac")
const CMD_EDGE := Color("06132e")
## 고른 명령(스킬 고르기·대상 고르기 동안, 원작 III HD gs2_653224 의 SKILL 줄): 밝은 시안 + 어두운 파랑 글자. 노랑은 「커서가 여기」.
const CMD_CHOSEN := Color("52d4e5")
const CMD_CHOSEN_TEXT := Color("0a1f5c")
## 스킬 목록 판(gs2_653224: 명령 목록 오른쪽의 남색 판, 가는 밝은 테두리). 줄은 청록(원작 #0c859f → #5eb1c1 는 흰 글자 대비가 4.5 아래라
## 어둡게 맞췄다), 커서 줄은 옅은 노랑 + 어두운 글자, TP 는 오른쪽 남색 상자에 흰 숫자.
const SKILL_PANEL := Color("03132d")
const SKILL_PANEL_EDGE := Color("8fb8d8")
const SKILL_TOP := Color("0c7d95")
const SKILL_BOTTOM := Color("0a6b80")
const SKILL_PRESSED_TOP := Color("08596b")
const SKILL_PRESSED := Color("0a6b80")
const SKILL_PICK_TOP := Color("ffff8d")
const SKILL_PICK := Color("eef182")
const SKILL_PICK_PRESSED := Color("fdffb8")
const SKILL_TP_BOX := Color("02142c")
## 명령 목록 뒤판(오른쪽이 굽은 남색 판)과 초상 틀.
const CMD_PLATE := Color("0b1a3a")
const CMD_PLATE_EDGE := Color("2a4f9a")
## 위 메시지 띠(전체 폭 오른쪽 끝까지): 파랑 그라데이션, 밝은 큰 글자. 안내 줄 알약(어두운 남색).
const BATTLE_BANNER_TOP := Color("183a9c")
const BATTLE_BANNER_BOTTOM := Color("03184d")
const BATTLE_BANNER_TEXT := Color("eef4ff")
const BATTLE_BANNER_NOTICE := Color("ffd9a0")
const HINT_PILL := Color("000128")
const HINT_PILL_PRESSED := Color("0d1c5c")
const HINT_EDGE := Color("2a4f9a")
## 턴 문패.
const TURN_FILL := Color("10307e")
## 전투 대원 카드(1810820_1f51fd75·jp_guide5_img4): 청록 판·어두운 틀·밝은 이름 띠, 쓰러지면 카드 전체가 어두운 회색.
const CARD_TOP := Color("144f57")
const CARD_BOTTOM := Color("0e4353")
const CARD_HEAD := Color("1f6873")
const CARD_FRAME := Color("06232b")
const CARD_SQUARE := Color("0b3a44")
const CARD_TEXT := Color("eaffff")
const CARD_LABEL := Color("7fe6ff")
const CARD_ACTIVE := Color("8ff4ff")
const CARD_DOWN_TOP := Color("2c3133")
const CARD_DOWN_BOTTOM := Color("23282a")
const CARD_DOWN_HEAD := Color("3a4043")
const CARD_DOWN_TEXT := Color("b4bcbf")
## HP 막대(노랑 → 주황 그라데이션, 모든 비율에서 같은 색), TP 막대(시안), 막대 빈 곳.
const CARD_HP_FROM := Color("fff043")
const CARD_HP_TO := Color("ffa62b")
const CARD_TP := Color("4dffff")
const CARD_BAR_BG := Color("0a2a30")
## 시설·캠프(M2.7 R2, 원작 HD gs2_653222·653235·jp_facility_img1): 위 설명 띠(짙은 청록 그라데이션, 밝은 두 줄 글자),
## 명령 목록 뒤판(거의 검은 판, 청록 테두리). 줄은 전투와 같은 「cmd:*」. 띠 색은 원작(#32725a → #236251)을 안내 글자(BATTLE_BANNER_NOTICE)
## 대비 4.5 이상이 되게 조금 어둡게 했다.
const FAC_BANNER_TOP := Color("246c58")
const FAC_BANNER_BOTTOM := Color("1a5546")
const FAC_BANNER_EDGE := Color("06231d")
const FAC_PLATE := Color("010d10")
## 시설·캠프 명령 줄 글자(원작 시설 화면의 청록 줄 위 물빛 글자, #00644c 위 5.3:1). 커서 줄·고른 줄·누름은 전투 「cmd:*」 그대로.
const FAC_TEXT := Color("6ff3db")
const FAC_PLATE_EDGE := Color("1f6d63")
## 캠프 뒤 3D 시야를 어둡게(전투와 같게).
const CAMP_DIM := BATTLE_DIM
## 캠프 맨 위 장소 띠(07 §9.8 ③, 원작 HD III 「第1階層 / B1F」 띠): 밝은 하늘색 판에 남색 글자(원작 근사, 대비 11:1 남짓), 아래 가는 선.
const RIBBON_FILL := Color("a8f6fa")
const RIBBON_TEXT := Color("0a323a")
const RIBBON_EDGE := Color("1f6d63")
## 캠프 알림 줄 바탕(장소 띠 아래, 거의 불투명한 짙은 청록: 안내 글자 BATTLE_BANNER_NOTICE 대비 4.5:1 이상).
const CAMP_NOTICE_BG := Color(0.02, 0.1, 0.11, 0.92)
## 상태 화면(원작 HD gs2_653218·653223·653241): 위 이름 칸(밝은 판 + 짙은 글자), Lv 띠(짙은 초록), 정보 띠(청록, 흰 글자 대비로 원작
## #1d8761 보다 어둡게), 직업 문패, 능력치 줄(이름 상자 + 값 + 노랑 막대), 공격·방어 판, 장비 줄, 오른쪽 아래 문패(원작 FORCE 자리).
const ST_NAME_TAB := Color("e1ffef")
const ST_NAME_TEXT := Color("0a3b26")
const ST_LV_BAND := Color("0a3b26")
const ST_LV_TEXT := Color("fff0a0")
const ST_INFO_TOP := Color("1f6352")
const ST_INFO_BOTTOM := Color("17604f")
const ST_CLASS_PLATE := Color("1f6352")
const ST_CLASS_EDGE := Color("8fe0c8")
const ST_ROW := Color("0b3a2e")
const ST_ROW_NAME := Color("021d16")
const ST_BAR_TRACK := Color("155d47")
const ST_BAR_FILL := Color("dff07e")
const ST_GEAR_LABEL := Color("005132")
const ST_GEAR_VALUE := Color("01361f")
const ST_EQUIP_ROW := Color("0f4c3c")
const ST_SIDE_TOP := Color("185d7a")
const ST_SIDE_BOTTOM := Color("002036")
const ST_SIDE_EDGE := Color("4fb6d8")
## 캠프 장비·소지품(원작 상점 화면 jp_guide3_img1~3): 왼쪽 목록·설명 창(짙은 남색 반투명, 청록 테두리·양 끝 마개, 설명 머리 띠),
## 오른쪽 인물 판(청록 반투명 + 옅은 모눈), 판의 장비 줄.
const SHOP_WIN_TOP := Color(0.03, 0.12, 0.26, 0.92)
const SHOP_WIN_BOTTOM := Color(0.02, 0.08, 0.19, 0.94)
const SHOP_WIN_EDGE := Color("3fb6c8")
const SHOP_WIN_CAP := Color("1f6d8f")
const SHOP_DESC_HEAD := Color("06142a")
const SHOP_PANEL_TOP := Color(0.05, 0.33, 0.37, 0.86)
const SHOP_PANEL_BOTTOM := Color(0.03, 0.22, 0.26, 0.9)
const SHOP_PANEL_GRID := Color(0.45, 0.95, 1.0, 0.1)
const SHOP_SECTION_TEXT := Color("6ff3db")
## 상점 부품(08 §7, 원작 HD 상점 jp_guide3_img1·2): 종류 탭(고르지 않은 칸은 어두운 남색, 고른 칸은 공용 checked 하늘색),
## 줄 왼쪽 아이콘 칸·빈 칸(어두운 남색), 「NEW」 주황 알약, 입하 알림 초록 창과 주황 물건 이름.
const SHOP_TAB := Color("0a1f4a")
const SHOP_TAB_PRESSED := Color("16357a")
const SHOP_TAB_EDGE := Color("3a5fa8")
const SHOP_TAB_TEXT := Color("d8e8ff")
const SHOP_ICON_CELL := Color("0a1838")
const SHOP_ICON_EDGE := Color("2a4f9a")
const SHOP_ICON := Color("cfe6ff")
const SHOP_EMPTY_ROW := Color(0.02, 0.06, 0.13, 0.85)
const SHOP_NEW_PILL := Color("c03c0c")
const SHOP_NEW_TEXT := Color(1, 1, 1)
const SHOP_NOTICE_TOP := Color("0a4c39")
const SHOP_NOTICE_BOTTOM := Color("083e2f")
const SHOP_NOTICE_EDGE := Color("8fe0c8")
const SHOP_NOTICE_ITEM := Color("ffa04a")
## 설명 창 직업 머리글자 칸(08 §8.5, 원작 B·C: 낄 수 있는 직업 밝게).
const SHOP_BADGE_ON := Color("7fe3f0")
const SHOP_BADGE_ON_TEXT := Color("06142a")
const SHOP_BADGE_OFF := Color("0a1838")
const SHOP_BADGE_OFF_TEXT := Color("5a6f90")
## 스킬 트리 화면(원작 HD jp_guide2_img2·img3, gw_14): 파랑 계열. 위 줄(이름 칸·Lv 띠·SKILL POINT 띠), 직업 폴더 탭,
## 반투명 파랑 창(트리·아래 설명 띠·확인 창), 노드 알약(짙은 파랑 + 밝은 글자, 커서는 밝은 하늘색 + 짙은 글자, 오른쪽 Lv 상자),
## 설명 띠의 레벨 칸(배운 레벨 시안·초안 노랑·남은 칸 짙은 파랑).
const TREE_NAME_TAB := Color("e3f4ff")
const TREE_NAME_TEXT := Color("0b2a4a")
const TREE_LV_BAND := Color("12364e")
const TREE_INFO_TOP := Color("05599f")
const TREE_INFO_BOTTOM := Color("044a86")
const TREE_TAB := Color("0f3f54")
const TREE_WIN_TOP := Color(0.03, 0.27, 0.5, 0.9)
const TREE_WIN_BOTTOM := Color(0.02, 0.18, 0.37, 0.92)
const TREE_WIN_EDGE := Color("6fd0ff")
const TREE_WIN_OUTER := Color("021a33")
const TREE_NODE_TOP := Color("063a76")
const TREE_NODE := Color("02336e")
const TREE_NODE_PRESSED := Color("0a4c94")
const TREE_PRESSED_MUTED := Color("c3ccd6")
const TREE_NODE_TEXT := Color("bff3ff")
const TREE_NODE_EDGE := Color("3f8fd0")
const TREE_PICK_TOP := Color("e2f6ff")
const TREE_PICK := Color("aae0fe")
const TREE_PICK_TEXT := Color("04244a")
const TREE_OFF := Color("142c47")
const TREE_OFF_TEXT := Color("93a9bd")
const TREE_LV_BOX := Color("56e6e0")
const TREE_LV_BOX_TEXT := Color("04244a")
const TREE_BOX_LEARNED := Color("21d8f0")
const TREE_BOX_DRAFT := Color("ffe066")
const TREE_BOX_EMPTY := Color("104779")
const TREE_BOX_EMPTY_TEXT := Color("cfe8ff")
const TREE_KIND_TEXT := Color("7fe6ff")
## 트리 연결선(선행을 채움 / 못 채움).
const TREE_LINE_MET := Color("8ff4ff")
const TREE_LINE_UNMET := Color("4d6a85")
const TOOL_TOP := Color("0f7aab")
const TOOL_BOTTOM := Color("0b6593")
const TOOL_PRESSED_TOP := Color("0a5a82")
const TOOL_PRESSED := Color("084a6c")
const TOOL_EDGE := Color("01274b")
const TOOL_LINE := Color("5fc3e6")
const TOOL_TEXT := Color(1, 1, 1)
const PILL_TOP := Color("a5d9ef")
const PILL_BOTTOM := Color("8ccbe6")
const PILL_PRESSED_TOP := Color("8ccbe6")
const PILL_PRESSED := Color("76bddc")
const PILL_TEXT := Color("01274b")

static var _looks := {}


## 상태 모양: fill(채우는지) · top/bottom(세로 그라데이션) · outer/outer_w(바깥 테두리) · inner/inner_w(안쪽 선) · glow(번짐)
## · marker(왼쪽 표시 막대, 알파 0 이면 없음) · chamfer · text(본 글자) · sub(작은 글자: 바뀌는 값·칸 이름) · reason(이유 글자).
static func has_look(state: String) -> bool:
	if _looks.is_empty():
		_looks = _build_looks()
	return _looks.has(state)


static func look(state: String) -> Dictionary:
	if _looks.is_empty():
		_looks = _build_looks()
	if not _looks.has(state):
		push_error("UiTheme: 모르는 단추 상태 %s" % state)
		return _looks["normal"]
	return _looks[state]


## 글자 몫(text·sub·reason·accent·good·muted)은 모두 이 모양의 채움 위·아래 색과 4.5:1 이상이어야 한다(시험).
const TEXT_ROLES := ["text", "sub", "reason", "accent", "good", "muted"]


static func _btn(top: Color, bottom: Color, outer: Color, outer_w: float, inner: Color, inner_w: float, marker: Color,
		text: Color, sub: Color, reason: Color) -> Dictionary:
	var dark := text.get_luminance() < 0.5
	return {"fill": true, "top": top, "bottom": bottom, "outer": outer, "outer_w": outer_w, "inner": inner, "inner_w": inner_w,
		"glow": Color(0, 0, 0, 0), "marker": marker, "chamfer": BTN_CHAMFER, "text": text, "sub": sub, "reason": reason,
		"accent": text if dark else ACCENT_TEXT, "good": sub if dark else GOOD_TEXT, "muted": sub if dark else MUTED_TEXT}


static func _build_looks() -> Dictionary:
	var none := Color(0, 0, 0, 0)
	var d := {}
	d["normal"] = _btn(BTN_TOP, BTN_BG, BTN_OUTER, BTN_OUTER_W, BTN_BORDER, 1.0, none, BTN_TEXT, BTN_SUB, BTN_REASON)
	d["pressed"] = _btn(BTN_HELD_TOP, BTN_HELD, BTN_OUTER, BTN_OUTER_W, BTN_HELD_BORDER, 1.0, none, BTN_TEXT, BTN_SUB, BTN_REASON_LIGHT)
	d["selected"] = _btn(BTN_PICK_TOP, BTN_PICK, BTN_PICK_EDGE, BTN_PICK_W, BTN_PICK_LINE, 1.0, BTN_PICK_TEXT, BTN_PICK_TEXT, BTN_PICK_SUB, BTN_PICK_SUB)
	d["selected_pressed"] = _btn(BTN_PICK_PRESSED_TOP, BTN_PICK_PRESSED, BTN_PICK_EDGE, BTN_PICK_W, BTN_PICK_LINE, 1.0, BTN_PICK_TEXT,
		BTN_PICK_TEXT, BTN_PICK_SUB, BTN_PICK_SUB)
	d["checked"] = _btn(BTN_CHECKED_TOP, BTN_CHECKED, BTN_OUTER, BTN_OUTER_W, BTN_CHECKED_BORDER, 2.0, none, BTN_PICK_TEXT, BTN_CHECKED_SUB, BTN_CHECKED_SUB)
	d["checked_pressed"] = _btn(BTN_CHECKED_PRESSED_TOP, BTN_CHECKED_PRESSED, BTN_OUTER, BTN_OUTER_W, BTN_CHECKED_BORDER, 2.0, none,
		BTN_PICK_TEXT, BTN_CHECKED_SUB, BTN_CHECKED_SUB)
	d["disabled"] = _btn(BTN_DISABLED_BG, BTN_DISABLED_BG, BTN_OUTER, BTN_OUTER_W, BTN_DISABLED_BORDER, 1.0, none, BTN_DISABLED_TEXT,
		BTN_DISABLED_TEXT, BTN_REASON)
	d["disabled_selected"] = _btn(BTN_DISABLED_BG, BTN_DISABLED_BG, BTN_PICK, BTN_PICK_W, BTN_DISABLED_BORDER, 1.0, BTN_PICK,
		BTN_DISABLED_TEXT, BTN_DISABLED_TEXT, BTN_REASON)
	for k in ["disabled", "disabled_selected"]:
		for role in ["accent", "good", "muted"]:
			d[k][role] = BTN_DISABLED_TEXT
	d["marked"] = _btn(BTN_TOP, BTN_BG, BTN_PICK, BTN_PICK_W, BTN_PICK_LINE, 1.0, BTN_PICK, BTN_TEXT, BTN_SUB, BTN_REASON)
	d["marked_pressed"] = _btn(BTN_HELD_TOP, BTN_HELD, BTN_PICK, BTN_PICK_W, BTN_PICK_LINE, 1.0, BTN_PICK, BTN_TEXT, BTN_SUB, BTN_REASON_LIGHT)
	d["checked_marked"] = _btn(BTN_TOP, BTN_BG, BTN_CHECKED, BTN_PICK_W, BTN_CHECKED, 1.0, BTN_CHECKED, BTN_TEXT, BTN_SUB, BTN_REASON)
	d["checked_marked_pressed"] = _btn(BTN_HELD_TOP, BTN_HELD, BTN_CHECKED, BTN_PICK_W, BTN_CHECKED, 1.0, BTN_CHECKED, BTN_TEXT, BTN_SUB,
		BTN_REASON_LIGHT)
	# 누름 채움(더 밝다) 위의 흐린 글자는 BTN_SUB 로.
	for k in ["pressed", "marked_pressed", "checked_marked_pressed"]:
		d[k]["muted"] = BTN_SUB
	# Godot 가 못 누르는 단추 위에 덮는 focus 상자: 채움·안쪽 선 없이 따뜻한 테두리와 표시 막대만(글자는 font_disabled_color 그대로).
	var df := (d["disabled_selected"] as Dictionary).duplicate()
	df["fill"] = false
	df["inner_w"] = 0.0
	d["disabled_focus"] = df
	var win := _btn(WIN_TOP, WIN_BOTTOM, WIN_OUTER, 3.0, WIN_INNER, 1.5, none, TEXT, SUB_TEXT, BTN_REASON)
	win["glow"] = WIN_GLOW
	win["chamfer"] = WIN_CHAMFER
	d["window"] = win
	# 바탕 위에 뜬 반투명 카드(전투 대원 칸·스킬 설명 띠): 창과 같은 모양, 채움만 GLASS_ALPHA.
	var glass := win.duplicate()
	glass["top"] = Color(WIN_TOP, GLASS_ALPHA)
	glass["bottom"] = Color(WIN_BOTTOM, GLASS_ALPHA)
	glass["muted"] = GLASS_DIM_TEXT
	glass["reason"] = GLASS_DOWN_TEXT
	d["glass"] = glass
	d["tool:normal"] = _plain(_btn(TOOL_TOP, TOOL_BOTTOM, TOOL_EDGE, BTN_OUTER_W, TOOL_LINE, 1.0, none, TOOL_TEXT, TOOL_TEXT, TOOL_TEXT))
	d["tool:pressed"] = _plain(_btn(TOOL_PRESSED_TOP, TOOL_PRESSED, TOOL_EDGE, BTN_OUTER_W, TOOL_LINE, 1.0, none, TOOL_TEXT, TOOL_TEXT, TOOL_TEXT))
	d["cmd:normal"] = _plain(_btn(CMD_TOP, CMD_BOTTOM, CMD_EDGE, BTN_OUTER_W, CMD_PRESSED_TOP, 1.0, none, CMD_TEXT, CMD_TEXT, CMD_TEXT))
	d["cmd:pressed"] = _plain(_btn(CMD_PRESSED_TOP, CMD_PRESSED, CMD_EDGE, BTN_OUTER_W, CMD_TEXT, 1.0, none, CMD_TEXT, CMD_TEXT, CMD_TEXT))
	d["cmd:selected"] = _plain(_btn(CMD_PICK_TOP, CMD_PICK, CMD_EDGE, BTN_OUTER_W, CMD_PICK_PRESSED, 1.0, none, CMD_PICK_TEXT, CMD_PICK_TEXT, CMD_PICK_TEXT))
	d["cmd:selected_pressed"] = _plain(_btn(CMD_PICK_PRESSED, CMD_PICK_TOP, CMD_EDGE, BTN_OUTER_W, CMD_PICK, 1.0, none, CMD_PICK_TEXT, CMD_PICK_TEXT,
		CMD_PICK_TEXT))
	d["cmd:disabled"] = _plain(_btn(CMD_OFF, CMD_OFF, CMD_EDGE, BTN_OUTER_W, CMD_OFF, 1.0, none, CMD_OFF_TEXT, CMD_OFF_TEXT, CMD_OFF_TEXT))
	d["cmd:disabled_selected"] = _plain(_btn(CMD_OFF, CMD_OFF, CMD_PICK_TOP, BTN_PICK_W, CMD_OFF, 1.0, none, CMD_OFF_TEXT, CMD_OFF_TEXT, CMD_OFF_TEXT))
	d["cmd:chosen"] = _plain(_btn(CMD_CHOSEN, CMD_CHOSEN, CMD_EDGE, BTN_OUTER_W, CMD_CHOSEN, 1.0, none, CMD_CHOSEN_TEXT, CMD_CHOSEN_TEXT, CMD_CHOSEN_TEXT))
	d["skill:normal"] = _plain(_btn(SKILL_TOP, SKILL_BOTTOM, CMD_EDGE, BTN_OUTER_W, SKILL_TOP, 1.0, none, CMD_TEXT, CMD_TEXT, CMD_TEXT))
	d["skill:pressed"] = _plain(_btn(SKILL_PRESSED_TOP, SKILL_PRESSED, CMD_EDGE, BTN_OUTER_W, CMD_TEXT, 1.0, none, CMD_TEXT, CMD_TEXT, CMD_TEXT))
	d["skill:selected"] = _plain(_btn(SKILL_PICK_TOP, SKILL_PICK, CMD_EDGE, BTN_OUTER_W, SKILL_PICK_TOP, 1.0, none, CMD_PICK_TEXT, CMD_PICK_TEXT, CMD_PICK_TEXT))
	d["skill:selected_pressed"] = _plain(_btn(SKILL_PICK_PRESSED, SKILL_PICK_TOP, CMD_EDGE, BTN_OUTER_W, SKILL_PICK, 1.0, none, CMD_PICK_TEXT, CMD_PICK_TEXT,
		CMD_PICK_TEXT))
	# 시설·캠프 명령 줄(「fac:*」): 평소 줄만 물빛 글자, 나머지는 전투 명령 줄과 같다(누름 채움 위 물빛은 4.5 아래라 흰 글자 그대로).
	for st in ["pressed", "selected", "selected_pressed", "disabled", "disabled_selected", "chosen"]:
		d["fac:" + st] = d["cmd:" + st]
	d["fac:normal"] = _plain(_btn(CMD_TOP, CMD_BOTTOM, CMD_EDGE, BTN_OUTER_W, CMD_PRESSED_TOP, 1.0, none, FAC_TEXT, FAC_TEXT, FAC_TEXT))
	# 스킬 트리 노드(「tree:*」): 짙은 파랑 알약(밝은 글자), 커서 = 밝은 하늘색(짙은 글자), 못 배움 = 어두운 회청(흐린 글자).
	d["tree:normal"] = _btn(TREE_NODE_TOP, TREE_NODE, TREE_WIN_OUTER, BTN_OUTER_W, TREE_NODE_EDGE, 1.0, none, TREE_NODE_TEXT, TREE_NODE_TEXT,
		BTN_REASON)
	d["tree:pressed"] = _btn(TREE_NODE_PRESSED, TREE_NODE_TOP, TREE_WIN_OUTER, BTN_OUTER_W, TREE_WIN_EDGE, 1.0, none, TREE_NODE_TEXT,
		TREE_NODE_TEXT, TREE_NODE_TEXT)
	d["tree:selected"] = _btn(TREE_PICK_TOP, TREE_PICK, TREE_WIN_OUTER, BTN_PICK_W, Color(1, 1, 1, 0.8), 1.0, none, TREE_PICK_TEXT,
		TREE_PICK_TEXT, TREE_PICK_TEXT)
	d["tree:selected_pressed"] = _btn(TREE_PICK, TREE_PICK_TOP, TREE_WIN_OUTER, BTN_PICK_W, Color(1, 1, 1, 0.8), 1.0, none, TREE_PICK_TEXT,
		TREE_PICK_TEXT, TREE_PICK_TEXT)
	d["tree:disabled"] = _plain(_btn(TREE_OFF, TREE_OFF, TREE_WIN_OUTER, BTN_OUTER_W, TREE_NODE_EDGE, 1.0, none, TREE_OFF_TEXT, TREE_OFF_TEXT,
		TREE_OFF_TEXT))
	d["tree:disabled_selected"] = _plain(_btn(TREE_OFF, TREE_OFF, TREE_PICK, BTN_PICK_W, TREE_PICK_TOP, 1.0, none, TREE_OFF_TEXT, TREE_OFF_TEXT,
		TREE_OFF_TEXT))
	d["tree:pressed"]["muted"] = TREE_PRESSED_MUTED  # 누른 채움이 밝아 공용 흐린 글자는 4.5:1 미만
	for k in ["tree:normal", "tree:pressed", "tree:selected", "tree:selected_pressed", "tree:disabled", "tree:disabled_selected"]:
		d[k]["chamfer"] = 20.0
	# 상점 종류 탭(「shoptab:*」): 어두운 남색 칸. 고른 칸은 공용 checked(하늘색), 노랑 커서는 쓰지 않는다(08 §7.3).
	d["shoptab:normal"] = _plain(_btn(SHOP_TAB, SHOP_TAB, CMD_EDGE, BTN_OUTER_W, SHOP_TAB_EDGE, 1.0, none, SHOP_TAB_TEXT, SHOP_TAB_TEXT,
		SHOP_TAB_TEXT))
	d["shoptab:pressed"] = _plain(_btn(SHOP_TAB_PRESSED, SHOP_TAB_PRESSED, CMD_EDGE, BTN_OUTER_W, SHOP_TAB_TEXT, 1.0, none, SHOP_TAB_TEXT,
		SHOP_TAB_TEXT, SHOP_TAB_TEXT))
	d["skill:disabled"] = d["cmd:disabled"]
	d["skill:disabled_selected"] = d["cmd:disabled_selected"]
	d["hint:normal"] = _plain(_btn(HINT_PILL, HINT_PILL, HINT_EDGE, BTN_OUTER_W, HINT_PILL, 1.0, none, BATTLE_BANNER_TEXT, BATTLE_BANNER_TEXT,
		BATTLE_BANNER_TEXT))
	d["hint:pressed"] = _plain(_btn(HINT_PILL_PRESSED, HINT_PILL_PRESSED, HINT_EDGE, BTN_OUTER_W, BATTLE_BANNER_TEXT, 1.0, none, BATTLE_BANNER_TEXT,
		BATTLE_BANNER_TEXT, BATTLE_BANNER_TEXT))
	for k in ["pill:normal", "pill:pressed"]:
		var top := PILL_TOP if k == "pill:normal" else PILL_PRESSED_TOP
		var bottom := PILL_BOTTOM if k == "pill:normal" else PILL_PRESSED
		var p := _plain(_btn(top, bottom, TOOL_EDGE, BTN_OUTER_W, Color(1, 1, 1, 0.6), 1.0, none, PILL_TEXT, PILL_TEXT, PILL_TEXT))
		p["chamfer"] = 32.0
		d[k] = p
	return d


## 글자 몫을 모두 본 글자색으로(밝은 파랑·밝은 알약 위에서는 따뜻한 강조색이 대비를 못 지킨다).
static func _plain(lk: Dictionary) -> Dictionary:
	for role in TEXT_ROLES:
		lk[role] = lk["text"]
	return lk


## 직접 그리는 단추의 상태. color_content: 안의 색이 뜻을 가진 단추(견본·직업색) → 채움을 바꾸지 않는 테두리 모양.
static func state_of(held: bool, selected: bool, checked: bool = false, disabled: bool = false, color_content: bool = false) -> String:
	if disabled:
		return "disabled_selected" if selected else "disabled"
	var base := "normal"
	if checked:
		base = "checked_marked" if color_content else "checked"
	if selected:
		base = "marked" if color_content else "selected"
	if held:
		return "pressed" if base == "normal" else base + "_pressed"
	return base


static func draw_window(ci: CanvasItem, r: Rect2) -> void:
	paint(ci.get_canvas_item(), r, look("window"))


## 바탕 위에 뜬 반투명 카드(창과 같은 모양).
static func draw_glass(ci: CanvasItem, r: Rect2) -> void:
	paint(ci.get_canvas_item(), r, look("glass"))


## 흰 바탕 위에 겹친 색(반투명 채움 위 글자 대비를 가장 나쁜 바탕으로 볼 때).
static func over_white(c: Color) -> Color:
	return Color(1, 1, 1).lerp(Color(c, 1.0), c.a)


## 스킬 트리 화면의 반투명 파랑 창(트리 창·설명 띠·확인 창): 위 → 아래 그라데이션, 어두운 바깥 선 + 밝은 안쪽 선, 모서리 깎음.
static func draw_tree_window(ci: CanvasItem, r: Rect2, opaque: bool = false) -> void:
	var c := minf(14.0, minf(r.size.x, r.size.y) * 0.3)
	var pts := chamfer_points(r, c)
	var cols := PackedColorArray()
	for p in pts:
		var col := TREE_WIN_TOP.lerp(TREE_WIN_BOTTOM, (p.y - r.position.y) / maxf(1.0, r.size.y))
		cols.append(Color(col, 1.0) if opaque else col)
	ci.draw_polygon(pts, cols)
	_outline(ci.get_canvas_item(), r.grow(-1.5), c, TREE_WIN_OUTER, 3.0)
	_outline(ci.get_canvas_item(), r.grow(-5.0), maxf(0.0, c - 3.0), TREE_WIN_EDGE, 1.5)


## 상점 짜임의 목록·설명 창(원작 jp_guide3_img1~3): 짙은 남색 반투명 그라데이션, 모서리 깎음, 청록 테두리, 왼쪽·오른쪽 끝 마개.
## head_h > 0 이면 위에 그 높이의 머리 띠(설명 창의 이름 줄).
static func draw_shop_window(ci: CanvasItem, r: Rect2, head_h: float = 0.0) -> void:
	var c := minf(12.0, minf(r.size.x, r.size.y) * 0.3)
	var pts := chamfer_points(r, c)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(SHOP_WIN_TOP.lerp(SHOP_WIN_BOTTOM, (p.y - r.position.y) / maxf(1.0, r.size.y)))
	ci.draw_polygon(pts, cols)
	if head_h > 0.0:
		ci.draw_rect(Rect2(r.position.x + 6.0, r.position.y + 6.0, r.size.x - 12.0, head_h), SHOP_DESC_HEAD)
	var cap := 8.0
	for x in [r.position.x + 3.0, r.end.x - 3.0 - cap]:
		ci.draw_rect(Rect2(x, r.position.y + c, cap, r.size.y - 2.0 * c), SHOP_WIN_CAP)
	_outline(ci.get_canvas_item(), r.grow(-1.0), c, SHOP_WIN_EDGE, 2.0)


## 위쪽 알림·연출 띠(반투명, 모서리 깎음, 테두리 없음).
static func draw_banner(ci: CanvasItem, r: Rect2) -> void:
	var c := minf(WIN_CHAMFER, minf(r.size.x, r.size.y) * 0.3)
	ci.draw_colored_polygon(chamfer_points(r, c), BANNER_FILL)


## 문패 하나의 크기(글자 폭 + 좌우 여백 + 기울기).
static func plate_size(font: Font, text: String, fs: int) -> Vector2:
	return Vector2(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0 * PLATE_PAD + PLATE_SLANT), PLATE_H)


## 기울어진 평행사변형(위는 오른쪽으로 slant 만큼 밀린다).
static func plate_points(r: Rect2, slant: float = PLATE_SLANT) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r.position.x + slant, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x - slant, r.end.y), Vector2(r.position.x, r.end.y)])


## 문패: 기울어진 판(위 → 아래 그라데이션, 어두운 바깥 선 + 밝은 안쪽 선)과 가운데 글자. 누르기를 받지 않는 장식이다.
static func draw_plate(ci: Control, r: Rect2, text: String, fs: int, col: Color = HEAD_TEXT) -> void:
	var rid := ci.get_canvas_item()
	var pts := plate_points(r)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(PLATE_TOP.lerp(PLATE_BOTTOM, (p.y - r.position.y) / maxf(1.0, r.size.y)))
	RenderingServer.canvas_item_add_polygon(rid, pts, cols)
	var outer := plate_points(r.grow(-1.0))
	outer.append(outer[0])
	RenderingServer.canvas_item_add_polyline(rid, outer, PackedColorArray([WIN_OUTER]), 2.0, true)
	var inner := plate_points(r.grow(-4.0), PLATE_SLANT * 0.8)
	inner.append(inner[0])
	RenderingServer.canvas_item_add_polyline(rid, inner, PackedColorArray([WIN_INNER]), 1.2, true)
	var font: Font = ci.get_theme_default_font()
	ci.draw_string(font, Vector2(r.position.x + PLATE_SLANT * 0.5, r.get_center().y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x - PLATE_SLANT, fs, col)


## 상태 모양으로 칸을 그리고 그 모양을 돌려준다(글자색은 그 모양의 몫에서 고른다).
static func draw_button(ci: CanvasItem, r: Rect2, state: String) -> Dictionary:
	var lk := look(state)
	paint(ci.get_canvas_item(), r, lk)
	return lk


## 채움 없는 비스듬한 테두리 하나(지금 행동하는 대원·대상 표시·초안처럼 모양 위에 덧그리는 표시).
static func draw_outline(ci: CanvasItem, r: Rect2, col: Color, w: float, chamfer: float = BTN_CHAMFER) -> void:
	var c := minf(chamfer, minf(r.size.x, r.size.y) * 0.3)
	_outline(ci.get_canvas_item(), r.grow(-w * 0.5), c, col, w)


## 비스듬히 깎은 모서리의 팔각형(시계 방향).
static func chamfer_points(r: Rect2, c: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])


## 모양 하나를 칸 r 에 그린다(직접 그리기와 Box 가 같이 쓴다).
static func paint(ci: RID, r: Rect2, lk: Dictionary) -> void:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var c := minf(float(lk["chamfer"]), minf(r.size.x, r.size.y) * 0.3)
	if lk["fill"]:
		var pts := chamfer_points(r, c)
		var cols := PackedColorArray()
		for p in pts:
			cols.append((lk["top"] as Color).lerp(lk["bottom"], (p.y - r.position.y) / r.size.y))
		RenderingServer.canvas_item_add_polygon(ci, pts, cols)
	var ow: float = lk["outer_w"]
	if ow > 0.0:
		_outline(ci, r.grow(-ow * 0.5), c, lk["outer"], ow)
	var iw: float = lk["inner_w"]
	var inset := ow + INNER_GAP + iw * 0.5
	if (lk["glow"] as Color).a > 0.0:
		_outline(ci, r.grow(-inset), maxf(0.0, c - inset * 0.4), lk["glow"], iw + 4.0)
	if iw > 0.0:
		_outline(ci, r.grow(-inset), maxf(0.0, c - inset * 0.4), lk["inner"], iw)
	if (lk["marker"] as Color).a > 0.0:
		RenderingServer.canvas_item_add_rect(ci, marker_rect(r, ow), lk["marker"])


## 왼쪽 표시 막대 자리(바깥 테두리 안쪽).
static func marker_rect(r: Rect2, outer_w: float = BTN_PICK_W) -> Rect2:
	return Rect2(r.position.x + outer_w + 2.0, r.position.y + r.size.y * 0.22, MARK_W, r.size.y * 0.56)


static func _outline(ci: RID, r: Rect2, c: float, col: Color, w: float) -> void:
	var pts := chamfer_points(r, c)
	pts.append(pts[0])
	RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), w, true)


## 가로 막대(전투 대원 카드·TP 게이지·적 HP 표): 빈 곳 bg, 채운 곳은 왼쪽 from → 오른쪽 끝 to 그라데이션(막대 전체 폭 기준).
static func draw_gauge(ci: CanvasItem, r: Rect2, ratio: float, from: Color, to: Color, bg: Color = CARD_BAR_BG) -> void:
	ci.draw_rect(r, bg)
	var w := r.size.x * clampf(ratio, 0.0, 1.0)
	if w <= 0.0:
		return
	var mid := from.lerp(to, w / maxf(1.0, r.size.x))
	var pts := PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, r.size.y), r.position + Vector2(0, r.size.y)])
	ci.draw_polygon(pts, PackedColorArray([from, mid, mid, from]))


## 둥근 채움 하나(상태 칩·준비 표시·번쩍임·직업색 띠·적 자리 상자처럼 창·단추가 아닌 작은 면).
static func fill_round(ci: CanvasItem, r: Rect2, col: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	ci.draw_style_box(sb, r)


## 위 두 모서리만 둥근 띠(전투 대원 칸의 직업색 띠).
static func fill_top_round(ci: CanvasItem, r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	ci.draw_style_box(sb, r)


## Godot Button·PanelContainer 용 상자: 같은 paint 로 그린다.
class Box:
	extends StyleBox
	var look: Dictionary

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		UiTheme.paint(to_canvas_item, rect, look)


static func box(state: String, margin: float = 8.0) -> Box:
	var b := Box.new()
	b.look = look(state)
	b.set_content_margin_all(margin)
	return b


static func window_box(margin: float = 22.0) -> Box:
	return box("window", margin)


## Godot Button 에 상태 상자와 글자색을 둔다. Godot 는 상태 상자(normal·hover·pressed·disabled) 위에 포커스면 focus 상자를
## 덮고, 못 누르면 글자를 font_disabled_color 로 그린다: 못 누르는 단추의 focus 는 채움 없는 테두리만(disabled_focus).
## checked: 켜진 단추(지금 고른 설정). 고른 것(포커스·포인터 위) 표시는 그 위에 그대로 덮인다.
static func style_button(b: Button, checked: bool) -> void:
	b.add_theme_stylebox_override("normal", box("checked" if checked else "normal"))
	b.add_theme_stylebox_override("hover", box("selected"))
	b.add_theme_stylebox_override("pressed", box("selected_pressed"))
	b.add_theme_stylebox_override("hover_pressed", box("selected_pressed"))
	b.add_theme_stylebox_override("focus", box("disabled_focus" if b.disabled else "selected"))
	b.add_theme_stylebox_override("disabled", box("disabled"))
	b.add_theme_color_override("font_color", look("checked" if checked else "normal")["text"])
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, BTN_PICK_TEXT)
	b.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
