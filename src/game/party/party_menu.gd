## 캠프(M2.7 R2, 07 §9, research 05 §2.2): 미궁 화면 위에 덮는 전체 화면 층. 열린 동안 탐색 화면은 HUD 를 감추고
## 3D 시야만 화면 전체로 두며(DungeonScreen._hud_hidden), 캠프의 모든 화면(뿌리·대원 고르기·하위 화면·확인 창)은 그 위에 원작의 무늬 판
## (그림 창으로 시야가 비친다, CampBackdrop)을 깐다(07 §9.8 ④, §9.9 E1). 확인 창은 바로 뒤에 화면 전체를 어둡게 하는 층을 둔다.
## 뿌리는 원작 HD 캠프 실물에 맞췄다(research 07 §2, 07 §9.8 D26): 왼쪽 위 걸음 문패(원작 시계 다이얼 자리), 위 장소 띠(PlaceRibbon),
## 오른쪽 위 소지금, 장소 띠 아래 알림 줄(알림이 있을 때만), 왼쪽 명령 목록(FacilityList), 아래 파티 카드 두 줄(PartyCards).
## 쪽(page): root(캠프 뿌리: 명령 목록) → pick(상태·스킬·장비: 파티 카드에서 대원 고르기) → sub(그 대원의 하위 화면).
## 소지품·기록은 파티 전체 것이라 고르기 없이 바로, 닫기는 탐색으로. Esc·P 는 한 단계 뒤로(하위 화면 → 뿌리 → 닫힘).
## 하위 화면은 원작 화면을 옮긴 것: 상태(PartyStatusTab, 상태 화면), 스킬(PartySkillTab, 스킬 트리), 장비(PartyEquipTab,
## 원작 I HD 장비 시트: 왼쪽 상태 시트·오른쪽 목록 창·설명 상자), 소지품(PartyItemsTab, 원작 소지품 목록 창·설명 상자), 기록(PartyRecordsTab, 원작 OPTION 모양의 둥근 판과 알약 줄, E2-e). 기록의 일(저장·불러오기·내보내기·
## 가져오기·자동 지도·새 게임)은 탐색 화면이 records 갈고리로 준다.
## 값은 규칙의 읽기 함수(GrowthRules.profile·learn_block·equip_block·sp_left 등)에서 읽고 화면이 다시 계산하지 않는다(07 §11.4).
## 상태는 규칙 함수(allocate·equip·supply·grant_exp)로만 바꾸고, 받아들여지면 save_hook(자동 저장, 07 §8.5) 뒤 changed 를 낸다.
## 스킬 배분 초안은 화면 것이라 저장하지 않는다. 메뉴를 닫으면 없어지고, 열 때는 늘 상태 탭·칸 0 대원에서 시작한다(07 §9.1).
##
## 입력 입구 하나(07 §9.4, 06 §9.5): 단추·노드·목록 줄·키보드가 모두 handle() 로 온다. 확인 창이 떠 있으면 그 창 입력만,
## 한 프레임에 입력 하나만 받는다. 문맥(탭·대원·확인 창·장비 목록)이 바뀌면 눌려 있던 포인터를 모두 버린다
## (취소된 누르기는 뗄 때 아무 일도 하지 않는다). 열린 동안 키 누름은 모두 여기서 끝난다(뒤 미궁 화면으로 가지 않는다). 뗌은 그대로 둔다.
class_name PartyMenu
extends Control

signal opened
signal closed
## 캠프 명령(목록 순서, 07 §9.8 ②: 원작 ITEM · STATUS · EQUIP · CUSTOM 차례 + 원작에 없는 기록). 숫자 키 1~6. 목록 줄은 앞 다섯
## (CAMP_ROWS)이고 「6 닫기」(고르기 중 「뒤로」)는 줄 없이 키 `6`과 키패드 「취소」(= Esc·P)만 한다(P3, 사용자 결정 2026-10-25:
## 방향 십자를 왼쪽 아래 전투 자리에 두려고 줄을 뺐다). 하위 화면 번호(tab, TAB_KEYS)는 이 차례와 따로다: camp_tab·camp_index 로 잇는다(숫자 키는 어디서나 이 차례).
const CAMP_KEYS := ["items", "status", "equip", "skills", "records", "close"]
const CAMP_ROWS := 5
## 명령 목록 위(알림 줄 아래 8). 원작 III 은 y 164 지만 64 줄 다섯이 카드 위에 들게 지금 자리를 둔다(07 §9.8 층 표).
const CAMP_TOP := 116.0
## 맨 위 띠(07 §9.8 ③, 1280×720 기준. 오른쪽 것은 오른쪽 끝 기준): 걸음 문패(원작 시계 다이얼 자리), 장소 띠(x 176 → 소지금 왼쪽 끝),
## 소지금(W − 328, 16, 328×50, 상점 소지금 문패와 같은 그림), 알림 줄(x 176 → W − 16, y 70~108, 알림이 있을 때만).
const STEP_PLATE := Rect2(0, 0, 176, 66)
const RIBBON_X := 176.0
const RIBBON_H := 66.0
const MONEY_W := 328.0
const MONEY_TOP := 16.0
const MONEY_H := 50.0
const NOTICE_TOP := 70.0
const NOTICE_BOTTOM := 108.0
const NOTICE_RIGHT := 16.0
const NOTICE_FS := 20
## 규칙 함수가 상태를 바꿨다(저장 갈고리 뒤). 탐색 화면이 상태 칸을 새로 그린다.
signal changed(events: Array)

## 안내 글자(스킬 정보 띠 위, 07 §9.2).
const NOTICE_TEXT := Color(1.0, 0.85, 0.55)
## 확인 창 = 알림 띠(부품 K, BannerBox, 07 §9.9 E2-d: 원작 I HD 스킬 배움 알림 x 218~1062 · y 290~428 을 단추 둘이 들게 높였다).
## 글은 띠 왼쪽 + 120 부터 왼쪽 맞춤(두 줄까지), 단추 둘은 원작 Ⓐ 자리인 오른쪽 아래.
const DIALOG_SIZE := Vector2(844, 200)
const DIALOG_BUTTON := Vector2(200, 64)
const DIALOG_TEXT := Rect2(120, 24, 604, 76)
const DIALOG_TEXT_FS := 22
const DIALOG_BUTTONS_RIGHT := 80.0
const DIALOG_BUTTONS_TOP := 112.0
const DIALOG_BUTTON_GAP := 16.0
## 확인 창 바로 뒤에서 화면 전체를 어둡게 하는 판 색(dialog_dim).
const DIALOG_DIM := Color(0, 0, 0, 0.6)
const NOTICE_SEC := 2.5
const TAB_KEYS := ["status", "skills", "equip", "items", "records"]
## 가상 키패드 단추 → 같은 일을 하는 물리 키(키 표 key_action 을 같이 써서 키패드 = 키).
const PAD_KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "ok": KEY_ENTER, "back": KEY_ESCAPE}
## 방향 십자 자리(왼쪽 아래 앵커: 왼쪽에서 x, 아래에서 y) — 전투와 같은 엄지 자리(06 §9.10). 상태·장비 화면은 왼쪽 열(장비 줄)을
## 덮지 않게 가운데 빈 곳(x 456, 07 §9.9 E2-c).
const PAD_DIR := Vector2(8, -209)
const PAD_DIR_STATUS := Vector2(456, -209)
## 「취소」「선택」 자리(오른쪽 아래 앵커: 왼쪽 위 모서리). 가로 = 전투와 같은 자리(W − 247, 427), 스킬은 설명 띠 안 「되돌리기」 왼쪽
## (계획의 W − 667 에서 100 오른쪽: 가장 긴 설명 8 줄이 두 칸에 들게 「되돌리기」「확정」을 좁혔다, 조정자 결정 2026-10-25),
## 장비·소지품·기록은 오른쪽 좁은 칸에 세로(110×151).
const PAD_KEYS_AT := Vector2(-247, -293)
const PAD_KEYS_SKILLS := Vector2(-567, -88)
const PAD_KEYS_SHOP := Vector2(-118, -172)
const PAD_KEYS_RECORDS := Vector2(-118, -300)
## 장비 칸 이름 키(칸 0 무기, 칸 1~3 방어구).
const SLOT_KEYS := PartyNames.SLOT_KEYS

# ---- 바깥에서 정하는 값 ----
## 「기록」의 일(탐색 화면이 준다): slots() -> Array, save(slot), load(slot), export(), import(), automap() -> String,
## set_automap(mode), new_game(). 캠프는 탐색 화면을 직접 부르지 않는다.
var records := {}
## 캠프 위에 다른 창(모달)이 떠 있으면 true: 그동안 키를 받지 않는다(그 창과 탐색 화면이 받는다).
var blocked_hook: Callable
## 디버그(디버그 주소 또는 네이티브 디버그 실행): 소지품 탭에 「임시 보급(시험용)」을 보인다(07 §5.7). 열 때마다 탐색 화면이 정한다.
var debug := false
## 규칙 함수가 상태를 바꾼 직후 부른다(자동 저장).
var save_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
## root · pick · sub
var page := "root"
## 캠프 명령 목록 커서(CAMP_KEYS 차례), 대원 고르기의 명령(하위 화면 번호: 0 상태·1 스킬·2 장비)과 커서(대원 칸).
var camp_cursor := 0
var pick_cmd := 0
var pick_cursor := 0
## 0 상태 · 1 스킬 · 2 장비 · 3 소지품 · 4 기록
var tab := 0
var member := 0
## 확인 창: "" · discard · commit · new_game
var dialog_kind := ""
## 확인 창에서 고른 단추: 0 「돌아가기」 · 1 「버리기」·「확정」·「새 게임」
var dialog_pick := 0
var notice := ""
## 받아들인 입력 수(시험용).
var accepted_inputs := 0

# ---- 부품 ----
## 캠프 뿌리·대원 고르기(07 §9.8): 걸음 문패·장소 띠·소지금·알림 줄·명령 목록·파티 카드(전투와 같은 부품, 값은 탐색 상태의 파티).
## 캠프 바탕(07 §9.8 ④, §9.9 E1): 무늬 판 + 그림 창. 하위 화면도 같은 판이다(CAMP_DIM 없음).
var backdrop_board: CampBackdrop
var camp_plate: FacilityPlate
var ribbon: PlaceRibbon
var money_plate: Control
var notice_line: Control
var camp_list: FacilityList
var cards: PartyCards
var display: BattleDisplay
var status_tab: PartyStatusTab
var skill_tab: PartySkillTab
var equip_tab: PartyEquipTab
var items_tab: PartyItemsTab
var records_tab: PartyRecordsTab
var tabs: Array[Control] = []
## 확인 창 층(떠 있을 때만 보인다): 어둡게 하는 판(dialog_dim, 화면 전체) → 창(dialog_panel) → 글 → 단추 둘.
var dialog_layer: Control
var dialog_dim: ColorRect
var dialog_panel: BannerBox
var dialog_buttons: Array[PartyButton] = []
## 가상 키패드(P3, 전투와 같은 부품 VirtualPad): 방향 십자, 「취소」「선택」 가로 한 쌍과 세로 한 쌍(쪽·화면마다 하나만 보인다).
## 확인 창 층 뒤(트리 순서 = 그리는·누르는 순서)라 확인 창에서도 누를 수 있고, 층 3 창보다는 아래다.
var dir_pad: VirtualPad
var key_pad: VirtualPad
var key_pad_stacked: VirtualPad
var _dialog_text := Label.new()
var _notice_left := 0.0
## 확인 창의 둘째 단추 뒤에 할 일(버리기 뒤 탭·대원 바꾸기·닫기, 새 게임).
var _after_discard: Callable
var _built := false
var _open := false
var _input_frame := -1
var _context := ""
## 마지막 _draw 가 CAMP_DIM 을 그렸는지(시험). 캠프는 그리지 않는다(07 §9.9 E1).
var drawn_dim := false


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP  # 뒤의 지도·이동 단추에 포인터가 닿지 않게
	focus_mode = FOCUS_NONE
	visible = false


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	_build_camp()
	status_tab = PartyStatusTab.new()
	skill_tab = PartySkillTab.new()
	equip_tab = PartyEquipTab.new()
	items_tab = PartyItemsTab.new()
	records_tab = PartyRecordsTab.new()
	tabs = [status_tab, skill_tab, equip_tab, items_tab, records_tab]
	for i in tabs.size():
		var t: Control = tabs[i]
		t.name = "Tab" + TAB_KEYS[i].capitalize()
		add_child(t)
		t.call("setup", self)
	_build_dialog()
	_build_pads()
	_layout()


## 캠프 뿌리 부품(앵커로 붙인다, 07 §9.8 층 표). 트리 순서 = 그리는·누르는 순서: 무늬 판 → 카드 → 걸음 문패 → 장소 띠 → 소지금 →
## 알림 줄(판·문패·띠·소지금·알림 줄은 장식) → 명령 목록.
func _build_camp() -> void:
	backdrop_board = CampBackdrop.new()
	backdrop_board.name = "CampBackdrop"
	add_child(backdrop_board)
	cards = PartyCards.new()
	cards.name = "CampCards"
	add_child(cards)
	place(cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	camp_plate = FacilityPlate.new()
	camp_plate.name = "CampPlate"
	add_child(camp_plate)
	place(camp_plate, Vector2.ZERO, Vector2.ZERO, Vector4(STEP_PLATE.position.x, STEP_PLATE.position.y, STEP_PLATE.end.x, STEP_PLATE.end.y))
	ribbon = PlaceRibbon.new()
	ribbon.name = "CampRibbon"
	add_child(ribbon)
	place(ribbon, Vector2.ZERO, Vector2(1, 0), Vector4(RIBBON_X, 0, -MONEY_W, RIBBON_H))
	money_plate = _deco("CampMoney", Vector2(1, 0), Vector2(1, 0), Vector4(-MONEY_W, MONEY_TOP, 0, MONEY_TOP + MONEY_H))
	money_plate.draw.connect(func() -> void: ShopFrame.paint_title(money_plate, money_text(), true))
	notice_line = _deco("CampNotice", Vector2.ZERO, Vector2(1, 0), Vector4(RIBBON_X, NOTICE_TOP, -NOTICE_RIGHT, NOTICE_BOTTOM))
	notice_line.draw.connect(_draw_notice_line)
	camp_list = FacilityList.new()
	camp_list.name = "CampList"
	add_child(camp_list)
	place(camp_list, Vector2.ZERO, Vector2.ZERO,
		Vector4(0, CAMP_TOP, FacilityList.WIDTH, CAMP_TOP + FacilityList.content_height(CAMP_ROWS)))
	var items := []
	for i in CAMP_ROWS:
		items.append({"name": "Camp_" + CAMP_KEYS[i], "text": camp_label(i)})
	camp_list.set_items(items)
	camp_list.pressed.connect(func(i: int) -> void: handle("camp", i))


## 명령 줄 글: 「1  소지품」(숫자 키).
func camp_label(i: int) -> String:
	return "%d  %s" % [i + 1, texts.t("camp.cmd." + CAMP_KEYS[i])]


## 명령 줄 i 가 여는 하위 화면 번호(TAB_KEYS), 닫기는 -1.
static func camp_tab(i: int) -> int:
	return TAB_KEYS.find(CAMP_KEYS[i]) if i >= 0 and i < CAMP_KEYS.size() else -1


## 하위 화면 번호 t 의 명령 줄(CAMP_KEYS 차례).
static func camp_index(t: int) -> int:
	return CAMP_KEYS.find(TAB_KEYS[t]) if t >= 0 and t < TAB_KEYS.size() else -1


## 소지금 글(상점 소지금 문패와 같다).
func money_text() -> String:
	return texts.t("shop.money", {"money": ShopRow.grouped(state.money if state != null else 0)})


## 누르기를 받지 않는 장식 컨트롤(그림은 draw 신호로).
func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.focus_mode = FOCUS_NONE
	add_child(c)
	place(c, a0, a1, off)
	return c


## 앵커(왼쪽 위·오른쪽 아래 비율)와 여백(left, top, right, bottom).
static func place(c: Control, a0: Vector2, a1: Vector2, off: Vector4) -> void:
	c.anchor_left = a0.x
	c.anchor_top = a0.y
	c.anchor_right = a1.x
	c.anchor_bottom = a1.y
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.z
	c.offset_bottom = off.w


## 가상 키패드(P3, 07 §9.7): 확인 창 층 뒤(그 위에 그려지고 먼저 누르기를 받는다), 층 3 창 아래. 자리는 쪽·화면마다 _place_pads.
func _build_pads() -> void:
	var ok := texts.t("battle.ui.pad_ok")
	var back := texts.t("battle.ui.pad_back")
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	key_pad = VirtualPad.new().setup_keys(ok, back)
	key_pad.name = "KeyPad"
	key_pad_stacked = VirtualPad.new().setup_keys(ok, back, true)
	key_pad_stacked.name = "KeyPadStacked"
	for p in [dir_pad, key_pad, key_pad_stacked]:
		add_child(p)
		(p as VirtualPad).pressed.connect(_on_vpad)


## 지금 쪽·화면의 키패드 자리: {dir: 십자 왼쪽 위(왼쪽 아래 앵커), keys: 선택·취소 왼쪽 위(오른쪽 아래 앵커), stacked: 세로인지}.
## 확인 창은 그 화면 자리 그대로(창은 가운데라 겹치지 않는다).
func pad_spot() -> Dictionary:
	var screen: String = TAB_KEYS[tab] if page == "sub" else page
	match screen:
		"status":
			return {"dir": PAD_DIR_STATUS, "keys": PAD_KEYS_AT, "stacked": false}
		"skills":
			return {"dir": PAD_DIR, "keys": PAD_KEYS_SKILLS, "stacked": false}
		"equip":
			return {"dir": PAD_DIR_STATUS, "keys": PAD_KEYS_SHOP, "stacked": true}
		"items":
			return {"dir": PAD_DIR, "keys": PAD_KEYS_SHOP, "stacked": true}
		"records":
			return {"dir": PAD_DIR, "keys": PAD_KEYS_RECORDS, "stacked": true}
	return {"dir": PAD_DIR, "keys": PAD_KEYS_AT, "stacked": false}


## 지금 보이는 「취소」「선택」 묶음.
func active_key_pad() -> VirtualPad:
	return key_pad_stacked if bool(pad_spot()["stacked"]) else key_pad


func _place_pads() -> void:
	var spot := pad_spot()
	var d: Vector2 = spot["dir"]
	var ds := VirtualPad.dirs_size()
	place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(d.x, d.y, d.x + ds.x, d.y + ds.y))
	var stacked: bool = spot["stacked"]
	var k: Vector2 = spot["keys"]
	var ks := VirtualPad.keys_size(stacked)
	place(active_key_pad(), Vector2(1, 1), Vector2(1, 1), Vector4(k.x, k.y, k.x + ks.x, k.y + ks.y))
	key_pad.visible = not stacked
	key_pad_stacked.visible = stacked


func _build_dialog() -> void:
	dialog_layer = Control.new()
	dialog_layer.name = "Dialog"
	dialog_layer.mouse_filter = MOUSE_FILTER_STOP  # 떠 있는 동안 뒤 화면은 포인터를 받지 않는다
	dialog_layer.visible = false
	add_child(dialog_layer)
	# 창 바로 뒤에서 창 아래 화면 전체를 어둡게 하고 누르기를 막는다(07 §9.9 E1 ①, 원작 알림 띠도 뒤를 어둡게 한다: research 08 §6.1).
	dialog_dim = ColorRect.new()
	dialog_dim.name = "DialogDim"
	dialog_dim.color = DIALOG_DIM
	dialog_dim.mouse_filter = MOUSE_FILTER_STOP
	dialog_layer.add_child(dialog_dim)
	dialog_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	# 창은 양 끝이 굽은 알림 띠(불투명, 스킬의 확정·버리기와 기록의 새 게임이 같이 쓴다).
	dialog_panel = BannerBox.new()
	dialog_panel.name = "DialogPanel"
	dialog_layer.add_child(dialog_panel)
	_dialog_text.add_theme_font_size_override("font_size", DIALOG_TEXT_FS)
	_dialog_text.add_theme_color_override("font_color", ListParts.BANNER_TEXT)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_layer.add_child(_dialog_text)
	for i in 2:
		var b := PartyButton.new()
		b.name = "DialogBack" if i == 0 else "DialogOk"
		b.skin = "cmd"  # 원작 습득 확인 창(jp_guide2_img2): 커서 쪽 노랑 알약, 다른 쪽 청록
		b.size = DIALOG_BUTTON
		b.activated.connect(func() -> void: handle("dialog_pick", i))
		dialog_layer.add_child(b)
		dialog_buttons.append(b)


func reason_text(code: String) -> String:
	return texts.t("growth.reason." + code)


func member_name(i: int) -> String:
	return PartyNames.member_name(state, texts, i)


func current_member() -> PartyState.Member:
	return state.party.members[member]


func slot_name(slot: int) -> String:
	return PartyNames.slot_name(texts, slot)


## 부호 붙은 수(글꼴 부분 집합에 U+2212 가 없어 ASCII 「-」를 쓴다).
static func signed(v: int) -> String:
	return PartyNames.signed(v)


# ---- 열기·닫기 ----

func is_open() -> bool:
	return _open


func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null:
		return
	state = s
	page = "root"
	camp_cursor = 0
	pick_cmd = 0
	pick_cursor = 0
	tab = 0
	member = 0
	dialog_kind = ""
	dialog_pick = 0
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	_open = true
	visible = true
	_setup_cards()
	cancel_pointers()
	_context = ""
	_layout()
	_refresh()
	opened.emit()


## 메뉴를 닫는다. 초안·열린 목록·확인 창을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_menu(notify: bool = true) -> void:
	if not _open:
		return
	_open = false
	visible = false
	dialog_kind = ""
	_after_discard = Callable()
	_clear_notice()
	for t in tabs:
		t.call("reset")
	cancel_pointers()
	if notify:
		closed.emit()


## 눌려 있던 포인터·끌기를 모두 버린다(취소된 누르기는 뗄 때 아무 일도 하지 않는다). 안의 문맥이 바뀔 때와,
## 바깥 창(층 3: 알림·파일 고르기·메모·전멸)이 열리고 닫힐 때 탐색 화면이 부른다.
func cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


## 파티 카드를 지금 상태로 새로 만든다(열 때: 새 게임·불러오기로 파티가 바뀌었을 수 있다).
func _setup_cards() -> void:
	display = BattleDisplay.from_party(state, texts)
	cards.setup(display, state.defs.party.class_ids)
	for c in cards.cards:
		var slot := cards.cards.find(c)
		c.activated.connect(func() -> void: handle("member", slot))
		c.snap()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만. 캠프 위에 바깥 창이 떠 있으면(blocked_hook) 아무것도 받지 않는다.
## 캠프 뿌리: camp(명령 줄 0~5, CAMP_KEYS 차례)·camp_cursor(±1)·confirm·back·close. 대원 고르기: member(칸)·pick_move(Vector2i)·
##       confirm·camp(상태·장비·스킬 줄 = 고르기 바꾸기, 소지품·기록 줄 = 바로 열기, 5 = 뒤로)·back·close.
## 하위 화면: tab(0~3)·member(칸)·member_step(±1)·back(한 단계 뒤로)·to_root(캠프 뿌리로)·close(캠프 닫기)·
##       dialog_move(±1)·dialog_pick(0·1)·dialog_ok·dialog_back·
##       스킬 탭 node(트리 칸)·node_dir(Vector2i)·plus·minus·revert·commit·
##       장비 탭 slot(0~3)·row(목록 줄)·cursor(±1)·confirm·unequip·
##       상태·소지품 탭 cursor(±1)·confirm, 상태 split(「내역」), 소지품 item_row(줄: 커서만 옮김)·supply_toggle·supply(장비 ID)·
##       exp_100(대원)·exp_next(대원)
func handle(kind: String, arg: Variant = null) -> bool:
	if not _open:
		return false
	if blocked_hook.is_valid() and blocked_hook.call():
		return false  # 캠프 위에 바깥 창이 떠 있다: 키·단추·카드·목록 어느 입력도 받지 않는다
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = frame
		accepted_inputs += 1
		_refresh()
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	if not dialog_kind.is_empty():
		match kind:
			"dialog_move":
				dialog_pick = clampi(dialog_pick + int(arg), 0, 1)
				return true
			"dialog_pick":
				return _dialog_choose(int(arg))
			"dialog_ok":
				return _dialog_choose(dialog_pick)
			"dialog_back":
				return _dialog_choose(0)
		return false
	if page == "root":
		return _dispatch_root(kind, arg)
	if page == "pick":
		return _dispatch_pick(kind, arg)
	match kind:
		"tab":
			var t := int(arg) if arg != null else -1
			if t < 0 or t >= tabs.size() or t == tab:
				return false
			_guard(func() -> void: _set_tab(t))
			return true
		"member":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= state.party.members.size() or i == member or tab == 3 or tab == 4:
				return false
			_guard(func() -> void: _set_member(i))
			return true
		"member_step":
			if tab == 3 or tab == 4:
				return false  # 소지품·기록은 대원과 상관없다(E2-b: 소지품에는 대원 판이 없다)
			if tab == 2 and equip_tab.list_open:
				return false  # 장비 목록이 열려 있으면 대원을 넘기지 않는다(띠 단추·←→·Q/E, 07 §9.9 E2-c)
			var n := state.party.members.size()
			var to := wrapi(member + (int(arg) if arg != null else 1), 0, n)
			_guard(func() -> void: _set_member(to))
			return true
		"back":
			if tab == 2 and equip_tab.list_open:
				return equip_tab.dispatch("list_close", null)
			_guard(_to_root)
			return true
		"to_root":
			_guard(_to_root)
			return true
		"close":
			_guard(close_menu)
			return true
	return tabs[tab].call("dispatch", kind, arg)


func _dispatch_root(kind: String, arg: Variant) -> bool:
	match kind:
		"camp_cursor":
			camp_cursor = wrapi(camp_cursor + (int(arg) if arg != null else 1), 0, CAMP_ROWS)
			return true
		"camp":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= CAMP_KEYS.size():
				return false
			camp_cursor = i
			return _run_camp(i)
		"confirm":
			return _run_camp(camp_cursor)
		"back", "close":
			close_menu()
			return true
	return false


## 캠프 명령: 상태·스킬·장비 → 대원 고르기, 소지품·기록 → 바로, 닫기 → 탐색으로.
func _run_camp(i: int) -> bool:
	match CAMP_KEYS[i]:
		"status", "skills", "equip":
			page = "pick"
			pick_cmd = camp_tab(i)
			pick_cursor = member
			_clear_notice()
		"close":
			close_menu()
		_:
			_open_sub(camp_tab(i))  # 소지품·기록
	return true


func _dispatch_pick(kind: String, arg: Variant) -> bool:
	var n := state.party.members.size()
	match kind:
		"member":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= n:
				return false
			member = i
			_open_sub(pick_cmd)
			return true
		"confirm":
			member = pick_cursor
			_open_sub(pick_cmd)
			return true
		"pick_move":
			var to := pick_target(pick_cursor, arg as Vector2i)
			if to == pick_cursor:
				return false
			pick_cursor = to
			return true
		"camp":
			# 고르기 중에도 명령 줄은 모두 일한다: `6`(줄 없음, = 「취소」)은 고르기 취소, 상태·스킬·장비는 그 명령으로 고르기를
			# 바꾸고(커서 대원 그대로, 지금 명령이면 아무 일 없음), 소지품·기록은 바로 연다.
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= CAMP_KEYS.size() or i == camp_index(pick_cmd):
				return false
			match CAMP_KEYS[i]:
				"close":
					page = "root"
					camp_cursor = camp_index(pick_cmd)
				"status", "skills", "equip":
					camp_cursor = i
					pick_cmd = camp_tab(i)
					_clear_notice()
				_:
					camp_cursor = i
					return _run_camp(i)
			return true
		"back":
			page = "root"
			camp_cursor = camp_index(pick_cmd)
			return true
		"close":
			close_menu()
			return true
	return false


## 대원 고르기 커서 이동(파티 카드 두 줄): ←·→ 는 보이는 차례(윗줄 왼쪽 → 오른쪽, 아랫줄 왼쪽 → 오른쪽)로 앞·뒤(끝에서 돈다),
## ↑·↓ 는 다른 줄에서 가로 가운데가 가장 가까운 카드(그 쪽에 줄이 없으면 그대로).
func pick_target(from: int, dir: Vector2i) -> int:
	var order: Array[int] = []
	for top in [true, false]:
		var row: Array[int] = []
		for i in cards.cards.size():
			if cards.top_row(i) == top:
				row.append(i)
		row.sort_custom(func(a: int, b: int) -> bool: return cards.cards[a].position.x < cards.cards[b].position.x)
		order.append_array(row)
	if order.is_empty():
		return from
	if dir.x != 0:
		return order[wrapi(order.find(from) + dir.x, 0, order.size())]
	if dir.y == 0:
		return from
	var want_top := dir.y < 0
	if cards.top_row(from) == want_top:
		return from
	var cx := cards.cards[from].position.x + PartyCards.CARD.x / 2.0
	var best := from
	var best_d := INF
	for i in order:
		if cards.top_row(i) != want_top:
			continue
		var d := absf(cards.cards[i].position.x + PartyCards.CARD.x / 2.0 - cx)
		if d < best_d:
			best_d = d
			best = i
	return best


## 하위 화면 t(0 상태·1 스킬·2 장비·3 소지품·4 기록)를 지금 대원으로 연다.
func _open_sub(t: int) -> void:
	page = "sub"
	tab = t
	equip_tab.close_list()
	if t == 3:
		items_tab.enter()
	for tb in tabs:
		tb.call("member_changed")
	_clear_notice()
	_layout()


## 하위 화면에서 캠프 뿌리로(커서는 그 명령 줄).
func _to_root() -> void:
	page = "root"
	camp_cursor = camp_index(tab)
	equip_tab.close_list()
	_layout()


## 초안이 있으면 버리기 확인 창을 띄우고 「버리기」 뒤에 action 을 한다. 없으면 바로 한다.
func _guard(action: Callable) -> void:
	if skill_tab.has_draft():
		open_dialog("discard", action)
	else:
		action.call()


func _set_tab(t: int) -> void:
	tab = t
	equip_tab.close_list()  # 다른 탭에서 돌아오면 칸 줄부터
	if t == 3:
		items_tab.enter()  # 소지품은 들어올 때마다 첫 가방 줄부터(보급 줄 닫힘)
	_layout()


func _set_member(i: int) -> void:
	member = i
	for t in tabs:
		t.call("member_changed")


func open_dialog(kind: String, after: Callable = Callable()) -> void:
	dialog_kind = kind
	dialog_pick = 0  # 처음은 늘 「돌아가기」(Enter 만 눌러도 안전한 쪽, 07 §4.6)
	_after_discard = after


func _dialog_choose(i: int) -> bool:
	if i < 0 or i > 1:
		return false
	var kind := dialog_kind
	var after := _after_discard
	dialog_kind = ""
	_after_discard = Callable()
	if i == 0:
		return true  # 「돌아가기」: 창만 닫는다(초안 그대로)
	match kind:
		"discard":
			skill_tab.clear_draft()
			if after.is_valid():
				after.call()
		"commit":
			skill_tab.commit_now()
		_:
			if after.is_valid():
				after.call()
	return true


## 키보드(07 §9.4 표, 물리 키). 열린 동안 누른 키는 모두 삼킨다: 표에 없는 키·반복·Ctrl·Alt·Meta 키는 아무것도 하지 않는다.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey:
		return
	if blocked_hook.is_valid() and blocked_hook.call():
		return  # 캠프 위에 뜬 창(기록의 메뉴 창 등)과 탐색 화면이 받는다
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	var code := k.physical_keycode
	if dialog_kind.is_empty() and event.is_action_pressed("open_party"):
		code = KEY_ESCAPE  # P = Esc(한 단계 뒤로). 확인 창에서는 P 가 아무 일도 하지 않는다
	var a := key_action(code)
	if not a.is_empty():
		handle(a[0], a[1])


## 키 표 하나(07 §9.4·§9.7, P3): 물리 키 → 지금 쪽·화면·확인 창에서 그 키가 보내는 [입력 종류, 값], 하는 일이 없으면 [].
## 부작용 없음. 키보드(_unhandled_input)와 가상 키패드(_on_vpad·pad_state)가 같이 쓴다. Enter 자리는 Enter·키패드 Enter·Space.
func key_action(code: int) -> Array:
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	var dir := _arrow(code)
	if not dialog_kind.is_empty():
		if dir.x != 0:
			return ["dialog_move", dir.x]
		if code == KEY_ESCAPE:
			return ["dialog_back", null]
		return ["dialog_ok", null] if enter else []
	if code == KEY_ESCAPE:
		return ["back", null]
	var num := _number(code)
	if page != "sub":
		if num >= 0 and num < CAMP_KEYS.size():
			return ["camp", num]  # 뿌리: 그 명령. 고르기: 2~4 고르기 바꾸기, 1·5 바로 열기, 6 「뒤로」
		if enter:
			return ["confirm", null]
		if page == "pick":
			return ["pick_move", dir] if dir != Vector2i.ZERO else []
		return ["camp_cursor", dir.y] if dir.y != 0 else []
	if num >= 0 and num < CAMP_ROWS:
		return ["tab", camp_tab(num)]  # 하위 화면도 명령 줄 차례(07 §9.8: 1 소지품 · 2 상태 · 3 장비 · 4 스킬 · 5 기록)
	if (tab == 3 or (tab == 2 and equip_tab.list_open)) and (code == KEY_Q or code == KEY_E):
		return []  # 소지품에는 대원이 없다(E2-b). 장비 목록이 열려 있으면 대원을 넘기지 않는다(E2-c)
	match code:
		KEY_Q:
			return ["member_step", -1]
		KEY_E:
			return ["member_step", 1]
	match tab:
		0:  # 상태: ←→ 앞·다음 대원(= Q/E, 원작 L/R), 선택 = 「내역」(= V). 내릴 것이 없어 ↑↓ 는 없다
			if dir.x != 0:
				return ["member_step", dir.x]
			return ["split", null] if code == KEY_V or enter else []
		1:  # 스킬: 방향 = 트리 커서, 선택 = 「+」
			if dir != Vector2i.ZERO:
				return ["node_dir", dir]
			match code:
				KEY_BACKSPACE:
					return ["minus", null]
				KEY_R:
					return ["revert", null]
				KEY_F:
					return ["commit", null]
			return ["plus", null] if enter else []
		4:  # 기록: ←→ 줄 안
			if dir.x != 0:
				return ["cursor_x", dir.x]
	if dir.y != 0:
		return ["cursor", dir.y]
	if dir.x != 0:
		# 장비 칸: ←→ 앞·다음 대원(= Q/E). 장비 목록이 열려 있으면 없다(칸 바꾸기는 목록을 닫고, 07 §9.7). 소지품은 대원이 없어 없다(E2-b)
		return [] if tab == 3 or (tab == 2 and equip_tab.list_open) else ["member_step", dir.x]
	if code == KEY_BACKSPACE:
		return ["unequip", null] if tab == 2 else []
	return ["confirm", null] if enter else []


static func _arrow(code: int) -> Vector2i:
	match code:
		KEY_UP:
			return Vector2i(0, -1)
		KEY_DOWN:
			return Vector2i(0, 1)
		KEY_LEFT:
			return Vector2i(-1, 0)
		KEY_RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO


## 숫자 키(윗줄·키패드) 1~9 → 0~8, 아니면 -1.
static func _number(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_1
	return -1


## 가상 키패드 누르기 → 그 단추와 같은 키의 입력(키 표를 같이 쓴다). 흐린 단추는 눌리지 않는다(VirtualPad).
func _on_vpad(kind: String, arg: Variant) -> void:
	var code := KEY_NONE
	match kind:
		"ok":
			code = KEY_ENTER
		"back":
			code = KEY_ESCAPE
		"move":
			var d := arg as Vector2i
			for k in ["up", "down", "left", "right"]:
				if VirtualPad.DIRS[k] == d:
					code = PAD_KEYS[k]
	var a := key_action(code)
	if not a.is_empty():
		handle(a[0], a[1])


## 키패드 단추마다 켤지(이름 → 참). 그 단추의 키가 지금 아무 일도 하지 않으면 흐림: 키 표에 없거나(예: 뿌리 ←→, 확인 창 ↑↓,
## 장비 목록·소지품 ←→), 그 쪽·화면에서 늘 거부되는 것(소지품 선택이 가방 줄 위·소지품 ↑↓ 에 커서 칸이 없음, 기록 선택의 커서 단추가 흐림).
func pad_state() -> Dictionary:
	var out := {}
	for k in PAD_KEYS:
		var a := key_action(PAD_KEYS[k])
		out[k] = not a.is_empty() and _may_accept(a)
	return out


func _may_accept(a: Array) -> bool:
	if page == "sub" and dialog_kind.is_empty() and tab == 3 and a[0] == "cursor":
		return items_tab.can_move()  # 소지품: 커서 칸이 없으면(디버그 아님, 빈 가방) ↑↓ 흐림. 끝에서는 켜 둔다
	if page == "sub" and dialog_kind.is_empty() and a[0] == "confirm":
		match tab:
			3:
				return items_tab.can_confirm()
			4:
				return not records_tab.cursor_button().disabled
	return true


func _refresh_pad() -> void:
	_place_pads()
	var on := pad_state()
	for p in [dir_pad, key_pad, key_pad_stacked]:
		(p as VirtualPad).set_enabled(on)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			cancel_pointers()


# ---- 규칙 결과 ----

## 규칙 함수의 이벤트 열을 받는다. 거부면 이유를 알림 줄에 띄우고 false. 받아들여졌으면 저장 갈고리 → 알림 → changed.
func apply(events: Array[Dictionary]) -> bool:
	if events.size() == 1 and events[0]["type"] == "rejected":
		show_notice(reason_text(str(events[0]["reason"])))
		return false
	if save_hook.is_valid():
		save_hook.call()
	show_notice(events_text(events))
	changed.emit(events)
	return true


## 알림 줄 글(받아들여진 성장 이벤트). 레벨업이 있으면 그 줄을 앞에.
func events_text(events: Array[Dictionary]) -> String:
	var lines: Array[String] = []
	for ev in events:
		var who := member_name(int(ev["member"])) if ev.has("member") else ""
		match str(ev["type"]):
			"level_up":
				lines.push_front(texts.t("battle.event.level_up", {"member": who, "from": ev["from"], "to": ev["to"]}))
			"exp":
				lines.append(texts.t("battle.event.exp_capped" if ev["capped"] else "battle.event.exp", {"member": who, "gained": ev["gained"]}))
			"skills_learned":
				lines.append(texts.t("growth.event.skills_learned", {"member": who, "sp_left": ev["sp_left"]}))
			"max_changed":
				lines.append(texts.t("growth.event.max_changed", {"member": who, "max_hp": ev["max_hp"], "max_tp": ev["max_tp"]}))
			"equipped":
				if str(ev["item"]).is_empty():
					lines.append(texts.t("growth.event.unequipped", {"member": who, "item": item_name(str(ev["removed"]))}))
				else:
					lines.append(texts.t("growth.event.equipped", {"member": who, "item": item_name(str(ev["item"]))}))
			"supplied":
				lines.append(texts.t("growth.event.supplied_capped" if ev["capped"] else "growth.event.supplied", {"item": item_name(str(ev["item"])), "amount": ev["amount"]}))
	return "\n".join(lines.slice(0, 2))


func item_name(id: String) -> String:
	return PartyNames.item_name(state, texts, id)


func show_notice(t: String) -> void:
	notice = t
	_notice_left = NOTICE_SEC
	_refresh_notice()
	queue_redraw()


## 안내를 비운다(글·남은 시간): 닫았다 다시 열 때 앞 안내가 남지 않는다.
func _clear_notice() -> void:
	notice = ""
	_notice_left = 0.0
	_refresh_notice()
	queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_clear_notice()


# ---- 그리기 ----

func _refresh() -> void:
	if not _built or not _open or state == null:
		return
	# 문맥이 바뀌면(탭·대원·확인 창·장비 목록) 앞 문맥에서 시작한 누르기를 버린다: 그 손가락은 뗄 때까지 아무것도 누르지 못한다.
	var sub := page == "sub"
	var ctx := "%s|%d|%d|%d|%s|%s" % [page, pick_cmd, tab, member, dialog_kind, tabs[tab].call("context") if sub else ""]
	if ctx != _context:
		_context = ctx
		cancel_pointers()
	for i in tabs.size():
		(tabs[i] as Control).visible = sub and i == tab
	if sub:
		tabs[tab].call("refresh")
	# 기록·소지품은 뿌리의 맨 위 띠(걸음 문패·장소 띠·소지금)를 그대로 두고, 알림 줄 자리에 화면 이름을 쓴다(07 §9.9 E1 ⑥, E2-b).
	var top_band := not sub or root_band()
	for c in [camp_plate, ribbon, money_plate]:
		(c as Control).visible = top_band
	for c in [camp_list, cards]:
		(c as Control).visible = not sub
	if top_band:
		_refresh_top()
	if not sub:
		_refresh_camp()
	# 안내 자리(알림 줄·하위 화면의 띠)는 쪽·화면이 바뀔 때마다 다시 정한다(숫자 키로 바로 바꿔도). 안내 글·남은 시간은 건드리지 않는다.
	_refresh_notice()
	_refresh_dialog()
	_refresh_pad()
	queue_redraw()


## 하위 화면이 뿌리의 맨 위 띠와 띠(알림 줄 자리)를 두는지: 기록(07 §9.9 E1 ⑥)·소지품(E2-b).
func root_band() -> bool:
	return page == "sub" and (tab == 4 or tab == 3)


## 맨 위 띠: 걸음 문패·장소 띠·소지금(뿌리·고르기·기록).
func _refresh_top() -> void:
	camp_plate.show_lines(texts.t("hud.steps", {"steps": state.steps}), "")
	# 층 번호·계층 자료가 생기면(M3) 원작처럼 「계층 / B1F」로 넓힌다(07 §9.8 ③).
	ribbon.show_text(texts.t(state.floor_def.name_key))
	money_plate.queue_redraw()


func _refresh_camp() -> void:
	var pick := page == "pick"
	var live := []
	for i in CAMP_ROWS:
		camp_list.set_row_text(i, camp_label(i))
		live.append(true)  # 고르기 중에도 모든 줄을 누를 수 있다(고른 줄은 눌러도 아무 일 없음)
	camp_list.show_rows(-1 if pick else camp_cursor, camp_index(pick_cmd) if pick else -1, live)
	display.sync_party(state)
	# 고르기(원작 research 07 §2.3): 커서 카드 하나만 노란 테두리(표지 "pick", 채움 아님). 다른 카드는 표지 없음.
	for c in cards.cards:
		c.target_mark = "pick" if pick and c == cards.card(pick_cursor) else ""
		c.cursor = false
		c.current = false
		c.mouse_filter = MOUSE_FILTER_STOP if pick else MOUSE_FILTER_IGNORE
		if not pick:
			c.cancel()
		c.queue_redraw()


## 안내(거부 이유·성장 결과 등): 뿌리·고르기는 알림 줄(있을 때만 보인다), 기록은 알림 줄(늘 보이고 안내가 없으면 「기록」),
## 소지품도 알림 줄(늘 보이고 안내가 없으면 「소지품   장비 n · 소재 n」), 다른 하위 화면은 제 자리(스킬·장비 = 위 정보 띠).
func _refresh_notice() -> void:
	if notice_line == null or state == null:
		return
	notice_line.visible = root_band() or (page != "sub" and not notice.is_empty())
	notice_line.queue_redraw()
	if page == "sub" and (tabs[tab] as Object).has_method("notice_changed"):
		tabs[tab].call("notice_changed")


## 알림 줄에 쓰는 글(여러 줄 안내는 한 줄로 잇는다). 안내가 없으면 기록은 「기록」, 소지품은 「소지품   장비 n · 소재 n」.
func notice_line_text() -> String:
	if notice.is_empty() and root_band():
		return items_tab.caption() if tab == 3 else texts.t("camp.cmd.records")
	return "   ".join(notice.split("\n", false))


## 알림 줄: 장소 띠 아래 어두운 띠에 따뜻한 안내 글자(글자 대비 4.5:1 이상, 시험).
func _draw_notice_line() -> void:
	var r := Rect2(Vector2.ZERO, notice_line.size)
	notice_line.draw_rect(r, UiTheme.CAMP_NOTICE_BG)
	notice_line.draw_rect(Rect2(0, r.end.y - 2.0, r.size.x, 2.0), UiTheme.FAC_PLATE_EDGE)
	var font := notice_line.get_theme_default_font()
	notice_line.draw_string(font, Vector2(PlaceRibbon.PAD, r.get_center().y + NOTICE_FS * 0.36), notice_line_text(),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2.0 * PlaceRibbon.PAD, NOTICE_FS, UiTheme.BATTLE_BANNER_NOTICE)


func _refresh_dialog() -> void:
	dialog_layer.visible = not dialog_kind.is_empty()
	if dialog_kind.is_empty():
		return
	match dialog_kind:
		"discard":
			_dialog_text.text = texts.t("party.dialog.discard_text")
			dialog_buttons[1].text = texts.t("party.dialog.discard")
		"new_game":
			_dialog_text.text = texts.t("menu.confirm_new_game")
			dialog_buttons[1].text = texts.t("menu.new_game")
		_:
			_dialog_text.text = texts.t("party.dialog.commit_text", {"n": skill_tab.draft_sp()})
			dialog_buttons[1].text = texts.t("party.dialog.commit")
	dialog_buttons[0].text = texts.t("party.dialog.back")
	for i in 2:
		dialog_buttons[i].selected = i == dialog_pick
		dialog_buttons[i].queue_redraw()
	dialog_panel.queue_redraw()


func dialog_rect() -> Rect2:
	return Rect2(((size - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)


func _layout() -> void:
	if not _built:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	for t in tabs:
		t.call("place", s)  # 하위 화면은 모두 앵커로 화면 전체에 붙는다
	dialog_layer.position = Vector2.ZERO
	dialog_layer.size = s
	var dr := Rect2(((s - DIALOG_SIZE) / 2.0).round(), DIALOG_SIZE)
	dialog_panel.position = dr.position
	dialog_panel.size = dr.size
	_dialog_text.position = dr.position + DIALOG_TEXT.position
	_dialog_text.size = DIALOG_TEXT.size
	var by := dr.position.y + DIALOG_BUTTONS_TOP
	dialog_buttons[1].position = Vector2(dr.end.x - DIALOG_BUTTONS_RIGHT - DIALOG_BUTTON.x, by)
	dialog_buttons[0].position = Vector2(dialog_buttons[1].position.x - DIALOG_BUTTON_GAP - DIALOG_BUTTON.x, by)
	_place_pads()
	queue_redraw()


## 바탕(07 §9.8 ④, §9.9 E1): 캠프의 모든 화면이 "board"(무늬 판과 그림 창, CampBackdrop)다. 확인 창은 그 위에 어둡게 하는 판(dialog_dim)을 둔다.
func backdrop() -> String:
	return "board"


func _draw() -> void:
	drawn_dim = backdrop() == "dim"
	if drawn_dim:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.CAMP_DIM)


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 단추·노드·줄 전부(확인 창이 떠 있으면 그 창 단추만)와 켜진 키패드 단추(확인 창이 떠 있어도: 창 층 위에 있다).
## 끌어 내리는 영역 밖으로 다 나간 줄은 뺀다.
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if not _open:
		return out
	var root_node: Node = dialog_layer if dialog_layer.visible else self
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.get_parent() is VirtualPad:
			continue
		if not b.is_visible_in_tree() or b.mouse_filter == MOUSE_FILTER_IGNORE:
			continue
		if root_node == self and dialog_layer.is_ancestor_of(b):
			continue
		if clipped_rect(b).size.y <= 0.0:
			continue
		out.append(b)
	for p in [dir_pad, key_pad, key_pad_stacked]:
		var vp := p as VirtualPad
		if not vp.is_visible_in_tree():
			continue
		for k in vp.buttons:
			var b: TouchButton = vp.buttons[k]
			if not b.disabled:
				out.append(b)
	return out


## 단추의 화면 사각형(이 메뉴 기준). 끌어 내리는 영역 안이면 그 영역으로 자른 부분.
func clipped_rect(b: Control) -> Rect2:
	var r := Rect2(b.get_global_position() - get_global_position(), b.size)
	var p := b.get_parent()
	while p != null and p != self:
		if p is PartyScroll:
			var sr := Rect2((p as Control).get_global_position() - get_global_position(), (p as Control).size)
			r = r.intersection(sr)
		p = p.get_parent()
	return r


## 디버그 요청 snapshot 의 파티 메뉴 정보(07 §8.6). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
## 단추는 보이는 부분의 가운데(끌어 내리는 영역에 반쯤 걸친 줄도 누를 수 있는 곳), 트리 노드는 스킬 ID 로도 낸다.
func debug_info(css: Callable) -> Dictionary:
	if not _open or state == null:
		return {"open": false}
	var buttons := {}
	var nodes := {}
	var tree := state.defs.class_of(member).tree
	for b in visible_buttons():
		var r := clipped_rect(b)
		var local := r.get_center() - (b.get_global_position() - get_global_position())
		var at: Array = css.call(local, b)
		buttons[b.name] = at
		if b is SkillNode and (b as SkillNode).index < tree.size():
			nodes[str(tree[(b as SkillNode).index]["skill"])] = at
	var rows := []
	if tab == 2 and equip_tab.list_open:
		for j in equip_tab.row_items.size():
			rows.append({"item": equip_tab.row_items[j], "block": equip_tab.row_block[j], "button": equip_tab.rows[j].name,
				"equipped": j == equip_tab.equipped_row})
	return {
		"open": true, "page": page, "tab": TAB_KEYS[tab] if page == "sub" else "", "member": member,
		"camp_cursor": camp_cursor, "pick": TAB_KEYS[pick_cmd] if page == "pick" else "", "pick_cursor": pick_cursor,
		"backdrop": backdrop(), "ribbon": ribbon.text if ribbon.visible else "", "money": money_text() if money_plate.visible else "", "draft": skill_tab.draft.duplicate(),
		"cursor": {"skill": skill_tab.cursor_skill(), "slot": equip_tab.cursor, "list_open": equip_tab.list_open,
			"list_row": equip_tab.list_cursor if equip_tab.list_open else -1, "items": items_tab.cursor},
		"dialog": dialog_kind, "dialog_pick": dialog_pick, "sp_line": skill_tab._sp_label.text if tab == 1 else "",
		"notice": notice, "strip": notice_line_text() if notice_line.visible else "", "debug": debug, "supply_open": items_tab.supply_open, "equip_rows": rows,
		"records": {"cursor": [records_tab.cur_row, records_tab.cur_col], "cards": [0, 1, 2].map(records_tab.card_lines)} if tab == 4 else {},
		"buttons": buttons, "nodes": nodes, "pad": pad_state(),
	}


## 바깥(디버그 요청)이 상태를 바꿨을 때 열린 메뉴를 다시 그린다.
func refresh_view() -> void:
	_refresh()
