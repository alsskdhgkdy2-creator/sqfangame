## 전투 층(06 §9): 미궁 화면 위에 덮는 전체 화면 Control. 바탕은 화면 전체 3D 시야(U1)를 UiTheme.BATTLE_DIM 으로 어둡게 한 것.
## 배치(M2.7 R3, 원작 HD 1868180_0e36b17e 를 1280×720 으로 옮김, 앵커로 붙인다. 논리 높이는 늘 720):
##   왼쪽 위 턴 문패 · 위 메시지 띠(x 193 → 오른쪽 끝, y 0~100: 명령 단계 물음·스킬 설명·대상 안내·연출 글·안내, 오른쪽 끝에 로그 단추) ·
##   띠 바로 아래 왼쪽 초상(지금 대원) + 그 아래 TP 게이지 · 초상 오른쪽 명령 목록(오른쪽이 굽은 줄) ·
##   명령 목록 오른쪽 영역 가운데 적 칸 · 아래 가운데 파티 카드 두 줄(윗줄 전열) · 오른쪽 아래 미니맵.
##   사용자 결정(2026-10-25, 원작과 다름): 로그 단추를 띠 안으로 옮겨 왼쪽을 한 줄 올리고, 빈 왼쪽 아래에 가상 방향키,
##   미니맵 위에 선택·취소(VirtualPad, 캠프도 같은 부품을 쓴다).
## 층 겹침(research 04): 트리 순서 = 그리는 순서 = 누르는 순서(z_index 를 쓰지 않는다).
##   바탕(어둡게 + 메시지 띠 + 턴 문패, _draw) · 적 칸(enemy_area, 그 위 HP 표) · 파티 카드 · 미니맵 · 초상 · 명령 목록 · 로그 단추 ·
##   로그 창 · 결과 창 · 방향키 · 선택·취소 · 건너뛰기 받개. 띠·문패·초상·미니맵·HP 표·키패드 묶음은 누르기를 받지 않는다(키패드 단추는 받는다).
## 상태는 규칙 함수(BattleRules)로만 바꾸고, 그리는 값은 BattleDisplay 에서 읽는다(06 §8.1).
##
## 입력 입구 하나(06 §9.5, 05 §9.3): 명령 단추·스킬 목록·대상 누르기·키보드·가상 키패드·「실행」·「뒤로」·건너뛰기·로그·결과 확인이
## 모두 handle() 로 온다. 조건(연출 중·로그 창·결과 창·전투 단계 아님)에 맞지 않으면 버리고, 한 프레임에 입력 하나만 받는다.
## 연출 중에는 건너뛰기만 받는다(미리 받지 않는다). 전투 명령은 누르고 있기 반복이 없다.
##
## 제출 순서(06 §8.7): 「실행」 → BattleRules.submit(그 턴이 끝남) → save_hook(자동 저장) → 연출.
## 그래서 연출 중 새로고침해도 저장된 것은 그 턴이 끝난 상태다. 고르던 명령은 저장하지 않는다.
class_name BattleLayer
extends Control

signal opened
## 전투가 끝나 층이 닫혔다. outcome: victory·escaped·wiped(전멸은 결과 창 없이 바로, 06 §9.3).
signal closed(outcome: String)
## 제출이 받아들여졌다(저장 갈고리 뒤, 연출 전). 시험·디버그용.
signal submitted(events: Array)

## 위 메시지 띠: 왼쪽 끝 x(그 왼쪽은 턴 문패), 높이, 글자 크기(첫 줄·둘째 줄), 글자 왼쪽 여백.
const BANNER_X := 193.0
const BANNER_H := 100.0
const BANNER_FS := 30
const BANNER_SUB_FS := 20
const BANNER_PAD := 34.0
## 턴 문패(원작은 시계 다이얼 아래, 다이얼이 없어 그 자리까지 올렸다): 큰 숫자 + 「턴」.
const TURN_PLATE := Rect2(16, 10, 164, 84)
const TURN_FS := 40
const TURN_LABEL_FS := 18
## 로그 단추: 메시지 띠 안 오른쪽 끝(사용자 결정 2026-10-25: 원작은 띠 아래 안내 줄이지만 그 줄이 왼쪽 목록을 한 줄 내려
## 자리를 많이 차지했다). 띠 높이 가운데, 오른쪽 여백 LOG_RIGHT. 띠 글은 그 왼쪽에서 끝난다.
const LOG_BUTTON := Vector2(120, 64)
const LOG_RIGHT := 8.0
## 초상(왼쪽, MemberPortrait)·명령 목록(초상 오른쪽, 초상 오른쪽 끝을 조금 덮는다): 위 y(띠 바로 아래), 목록 x·폭·높이.
const LIST_TOP := BANNER_H + 8.0
const LIST_X := 170.0
const LIST_W := 323.0
const LIST_H := 356.0
## 미니맵(오른쪽 아래, 원작 x 1033~1260 · y 507~667): 크기, 오른쪽·아래 여백.
const MINIMAP := Vector2(227, 160)
const MINIMAP_RIGHT := 20.0
const MINIMAP_BOTTOM := 53.0
## 스킬 판(원작 III HD gs2_653224): 명령 목록 원호 오른쪽, 위는 「스킬」 줄 위, 아래는 파티 카드 위 − 8. x·폭.
const SKILL_X := 470.0
const SKILL_W := 410.0
## 적 영역: 명령 목록 오른쪽 ~ 미니맵 열 왼쪽(적 칸이 미니맵·선택/취소 열과 겹치지 않는다).
## 위는 띠 아래 ~ 파티 카드 위(논리 높이는 늘 720) 사이의 가운데: 100 + (448 − 348) / 2 = 150.
const ENEMY_LEFT := LIST_X + LIST_W + 7.0
const ENEMY_RIGHT := MINIMAP_RIGHT + MINIMAP.x + 8.0
const ENEMY_TOP := BANNER_H + (720.0 - PartyCards.HEIGHT - BANNER_H - (EnemyArea.FRONT_TOP + EnemyArea.FRONT_SIZE)) / 2.0
## 가상 방향키(VirtualPad 십자, 왼쪽 아래: TP 게이지 아래 ~ 화면 아래, 파티 카드 왼쪽)·선택/취소(미니맵 바로 위, 미니맵과 같은 x).
## 원작에 없는 것(사용자 제안 2026-10-25). 왼쪽·아래 여백, 선택/취소와 미니맵 사이.
const PAD_LEFT := 8.0
const PAD_BOTTOM := 9.0
const KEYS_GAP := 8.0
## 연출 알림 글자 · 안내(못 고르는 이유 등) 글자(메시지 띠 위).
const ANNOUNCE_TEXT := UiTheme.BATTLE_BANNER_TEXT
const NOTICE_TEXT := UiTheme.BATTLE_BANNER_NOTICE
const NOTICE_SEC := 2.0
## 연출 한 단계의 길이(초, anim_speed 1). 행동 하나 약 0.6초, 독 한 번 약 0.3초(06 §9.3).
const STEP_SEC := {"action": 0.6, "failed": 0.5, "idle": 0.4, "guarding": 0.35, "poison_tick": 0.3, "turn_end": 0.15, "": 0.3}
## 새 연출 단계를 여는 이벤트. 나머지는 앞 단계에 붙는다.
const HEADS := ["action", "failed", "idle", "guarding", "poison_tick", "turn_end"]
## 행동하는 쪽이 있는 단계(그 대원 카드에 시안 틀). 독·턴 끝은 행동이 아니다.
const ACTOR_HEADS := ["action", "failed", "idle", "guarding"]
## 상세 이벤트를 단계 안 어느 시점에 보이는지(단계 길이의 비율).
const DETAIL_AT := 0.35
## 대상이 정해진 대상 규칙(06 §9.2): 고르지 않고, 정해진 대상을 모두 밝힌 확인 단계에서 확정한다(원작의 전체 스킬 확인).
const AUTO_TARGETS := ["self", "enemy_all", "ally_all"]
const REASON_KEYS := ["no_tp", "bound_head", "bound_arm", "bound_leg", "no_target", "no_escape", "unknown_skill"]
## 결과 창: 폭, 가장 작은 높이, 본문 시작(제목 아래), 본문과 「확인」 사이, 「확인」 아래 여백.
const RESULT_W := 560.0
## 결과 본문 글자 크기와 묶음 머리 글자 크기.
const RESULT_FS := 20
const RESULT_HEAD_FS := 24
const RESULT_MIN_H := 340.0
## 결과 창 제목 문패 글자 크기(문패는 창 위 가장자리에 걸친다), 본문 시작(창 위에서).
const RESULT_TITLE_FS := 26
const RESULT_TOP := 40.0
const RESULT_GAP := 12.0
const RESULT_BOTTOM := 20.0
## 탐색 화면이 전투 중 알림 줄(저장 실패 등)을 띄우는 자리: 메시지 띠 아래 · 적 영역 위(적 영역 위 150 보다 위),
## 명령 목록 오른쪽(x ENEMY_LEFT) ~ 오른쪽 − TOAST_RIGHT, 높이 TOAST_H. 결과 창은 이 줄 아래에 둔다.
const TOAST_Y := BANNER_H + 6.0
const TOAST_LEFT := ENEMY_LEFT
const TOAST_RIGHT := 8.0
const TOAST_H := 36.0

# ---- 바깥에서 정하는 값 ----
## 0 이면 연출을 바로 끝 상태로 맞춘다(시험).
var anim_speed := 1.0
## 디버그 주소: 로그에 판정 이유를 펼친다(06 §9.4). 디버그 끝내기("finish")도 이때만 받는다.
var debug := false
## 제출 결과가 정해진 직후, 연출 전에 부른다(자동 저장).
var save_hook: Callable
## 전투 층 위에 다른 창(층 3: 알림·파일 고르기·메모·전멸)이 떠 있으면 true: 그동안 키·단추·카드·키패드 어느 입력도 받지 않는다
## (캠프 PartyMenu.blocked_hook 과 같은 규칙, 07 §9.7 「바깥 창과 누르기」).
var blocked_hook: Callable

# ---- 상태 ----
var state: ExplorationState
var texts: TextDb
var display: BattleDisplay
## closed / command / anim / result
var phase := "closed"
## 명령 단계 안: menu / skills / target / confirm
var sub := "menu"
## 지금 명령을 고르는 대원 칸(-1 = 없음: 모두 찼거나 닫힘).
var member := -1
## 대원 순서 5칸. 고르지 않았거나 명령을 받지 않는 대원은 null.
var commands: Array = []
## 키보드 커서(메뉴 0~3, 스킬 줄 번호, 대상 목록 번호).
var cursor := 0
## 대상을 고르는 중인 스킬 ID("attack" = 일반 공격).
var target_skill := ""
var target_side := ""
var target_slots: Array[int] = []
## 대상이 정해진 스킬(AUTO_TARGETS)의 확인 단계인지: target_slots 전부를 밝히고, 그중 아무 칸·Enter 로 확정한다.
var target_fixed := false
## 스킬 목록에서 대상 고르기로 왔는지(뒤로 갈 곳).
var target_from_skills := false
var outcome := ""
var end_event := {}
## 마지막으로 받아들인 제출의 이벤트 열.
var last_events: Array[Dictionary] = []
## 받아들인 입력 수(시험용).
var accepted_inputs := 0

# ---- 부품 ----
var enemy_area: EnemyArea
var party_cards: PartyCards
var panel: CommandPanel
## 지금 대원의 초상 + TP 게이지(누르기 없음).
var portrait: MemberPortrait
## 오른쪽 아래 미니맵(탐색 화면과 같은 부품·같은 지도, 누르기 없음).
var minimap: MapOverview
## 스킬 설명(메시지 띠에 보인다): 머리(이름·Lv·TP)와 설명 한 줄(SkillSummary). 비어 있으면 설명 없음.
var skill_info_title := ""
var skill_info_text := ""
var log_button: BattleButton
## 가상 방향키(왼쪽 아래)와 선택·취소(미니맵 위). 키와 같은 입구(handle)로 간다.
var dir_pad: VirtualPad
var key_pad: VirtualPad
var log_view: BattleLogView
var result_panel: Control
var result_ok: BattleButton
var skip_catcher: Control
## 결과 창 제목 문패(창 위 가장자리에 걸친다).
var _result_title := UiPlate.new()
var _result_body := RichTextLabel.new()
## 결과 본문(넘치면 끌어 내린다, 07 §9.6).
var result_scroll: PartyScroll
## 결과 창 본문 줄(드롭·경험치·레벨업). 디버그 상태 요약도 이것을 낸다(07 §8.6).
var result_lines: Array[String] = []
## result_lines 와 같은 차례의 줄 종류(M2.6 U6): "head"(묶음 머리 드롭·경험치·레벨 업, 더 크고 따뜻한 색) ·
## "item"(머리 아래 줄) · "line"(머리 없는 한 줄: 「경험치 +7」·「드롭 없음」 등).
var result_kinds: Array[String] = []
var _built := false
var _input_frame := -1
var _notice := ""
var _notice_left := 0.0
var _announce := ""
## 연출 중 지금 행동하는 대원 칸(-1 = 없음·적 차례). 그 카드에 지금 대원과 같은 시안 틀(원작 1810820_1f51fd75).
var _actor := -1
## 입력 문맥(단계·명령 단계·대원·대상 스킬·로그·결과 창). 바뀌면 눌려 있던 포인터를 모두 버린다.
var _context := ""

# ---- 연출 ----
var _steps: Array[Dictionary] = []
var _step_i := 0
var _step_t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE
	visible = false


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	enemy_area = EnemyArea.new()
	enemy_area.name = "EnemyArea"
	add_child(enemy_area)
	_place(enemy_area, Vector2(0, 0), Vector2(1, 0), Vector4(ENEMY_LEFT, ENEMY_TOP, -ENEMY_RIGHT, ENEMY_TOP + EnemyArea.FRONT_TOP + EnemyArea.FRONT_SIZE))
	party_cards = PartyCards.new()
	party_cards.name = "PartyCards"
	add_child(party_cards)
	_place(party_cards, Vector2(0, 1), Vector2(1, 1), Vector4(0, -PartyCards.HEIGHT, 0, 0))
	minimap = MapOverview.new().setup(true)
	minimap.name = "MiniMap"
	add_child(minimap)
	_place(minimap, Vector2(1, 1), Vector2(1, 1), Vector4(-MINIMAP_RIGHT - MINIMAP.x, -MINIMAP_BOTTOM - MINIMAP.y, -MINIMAP_RIGHT, -MINIMAP_BOTTOM))
	portrait = MemberPortrait.new()
	portrait.name = "Portrait"
	add_child(portrait)
	_place(portrait, Vector2.ZERO, Vector2.ZERO, Vector4(0, LIST_TOP, MemberPortrait.SIZE.x, LIST_TOP + MemberPortrait.SIZE.y))
	panel = CommandPanel.new()
	panel.name = "CommandPanel"
	add_child(panel)
	_place(panel, Vector2.ZERO, Vector2.ZERO, Vector4(LIST_X, LIST_TOP, LIST_X + LIST_W, LIST_TOP + LIST_H))
	panel.build(texts)
	panel.pressed.connect(_on_panel)
	log_button = BattleButton.new()
	log_button.name = "LogButton"
	log_button.setup("", texts.t("battle.ui.log"))
	log_button.skin = "hint"
	log_button.font_size = 20
	add_child(log_button)
	var log_y := roundf((BANNER_H - LOG_BUTTON.y) / 2.0)
	_place(log_button, Vector2(1, 0), Vector2(1, 0), Vector4(-LOG_RIGHT - LOG_BUTTON.x, log_y, -LOG_RIGHT, log_y + LOG_BUTTON.y))
	log_button.activated.connect(func() -> void: handle("log"))
	log_view = BattleLogView.new()
	log_view.name = "BattleLog"
	add_child(log_view)
	log_view.build(texts)
	log_view.close_requested.connect(func() -> void: handle("log_close"))
	_build_result()
	# 가상 키패드: 결과 창 위(겹치지 않지만 차례를 정해 둔다), 넘기기 받개 아래(연출 중 누르기는 넘기기).
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	add_child(dir_pad)
	var ds := VirtualPad.dirs_size()
	_place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_LEFT, -PAD_BOTTOM - ds.y, PAD_LEFT + ds.x, -PAD_BOTTOM))
	dir_pad.pressed.connect(_on_vpad)
	key_pad = VirtualPad.new().setup_keys(texts.t("battle.ui.pad_ok"), texts.t("battle.ui.pad_back"))
	key_pad.name = "KeyPad"
	add_child(key_pad)
	var ks := VirtualPad.keys_size()
	var kb := MINIMAP_BOTTOM + MINIMAP.y + KEYS_GAP
	_place(key_pad, Vector2(1, 1), Vector2(1, 1), Vector4(-MINIMAP_RIGHT - ks.x, -kb - ks.y, -MINIMAP_RIGHT, -kb))
	key_pad.pressed.connect(_on_vpad)
	skip_catcher = Control.new()
	skip_catcher.name = "SkipCatcher"
	skip_catcher.mouse_filter = MOUSE_FILTER_STOP
	skip_catcher.visible = false
	skip_catcher.gui_input.connect(_on_catcher_input)
	add_child(skip_catcher)
	skip_catcher.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_layout()


## 앵커(왼쪽 위·오른쪽 아래 비율)와 여백(left, top, right, bottom).
static func _place(c: Control, a0: Vector2, a1: Vector2, off: Vector4) -> void:
	c.anchor_left = a0.x
	c.anchor_top = a0.y
	c.anchor_right = a1.x
	c.anchor_bottom = a1.y
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.z
	c.offset_bottom = off.w


func _build_result() -> void:
	result_panel = Control.new()
	result_panel.name = "ResultPanel"
	result_panel.mouse_filter = MOUSE_FILTER_STOP
	result_panel.visible = false
	result_panel.draw.connect(func() -> void: UiTheme.draw_window(result_panel, Rect2(Vector2.ZERO, result_panel.size)))
	add_child(result_panel)
	_result_title.name = "ResultTitle"
	_result_title.font_size = RESULT_TITLE_FS
	_result_title.color = UiTheme.TEXT
	result_panel.add_child(_result_title)
	result_scroll = PartyScroll.new()
	result_scroll.name = "ResultBody"
	result_panel.add_child(result_scroll)
	_result_body.bbcode_enabled = true
	_result_body.fit_content = true
	_result_body.scroll_active = false
	_result_body.selection_enabled = false
	_result_body.add_theme_font_size_override("normal_font_size", RESULT_FS)
	_result_body.add_theme_color_override("default_color", UiTheme.TEXT)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_body.mouse_filter = MOUSE_FILTER_IGNORE
	result_scroll.content.add_child(_result_body)
	result_ok = BattleButton.new()
	result_ok.name = "ResultOk"
	result_ok.setup("", texts.t("ui.ok"))
	result_ok.size = Vector2(240, 64)
	result_panel.add_child(result_ok)
	result_ok.activated.connect(func() -> void: handle("result_ok"))


# ---- 열기·닫기 ----

func is_open() -> bool:
	return phase != "closed"


## 연출 중인지.
func is_busy() -> bool:
	return phase == "anim"


## 전투 중인 상태로 층을 연다. 늘 그 턴 명령 입력 처음에서 시작한다(06 §8.7: 고르던 명령은 저장하지 않는다).
func open(s: ExplorationState) -> void:
	assert(_built, "build() 를 먼저 부른다")
	if s == null or s.battle == null:
		return
	state = s
	display = BattleDisplay.from_state(s, texts)
	enemy_area.setup(display)
	party_cards.setup(display, s.defs.party.class_ids)
	minimap.set_state(s)
	minimap.refresh()
	for c in _all_cards():
		c.activated.connect(_on_card.bind(c.unit_ref))
		c.snap()
	log_view.clear()
	log_view.close()
	result_panel.visible = false
	skip_catcher.visible = false
	outcome = ""
	end_event = {}
	last_events.clear()
	result_lines.clear()
	result_kinds.clear()
	_steps.clear()
	_notice = ""
	_announce = ""
	visible = true
	phase = "command"
	_cancel_pointers()
	_begin_turn()
	if s.battle.turn == 0:
		_show_notice(texts.t("msg.encounter"))
	_layout()
	opened.emit()


## 층을 닫는다(전투 끝). 결과 창·연출을 버린다. notify 가 거짓이면 closed 를 내지 않는다(상태를 통째로 바꿀 때).
func close_layer(notify: bool = true) -> void:
	if phase == "closed":
		return
	phase = "closed"
	visible = false
	skip_catcher.visible = false
	result_panel.visible = false
	log_view.close()
	_cancel_pointers()
	if notify:
		closed.emit(outcome)


## 눌려 있던 포인터·끌기를 모두 버린다(취소된 누르기는 뗄 때 아무 일도 하지 않는다): 명령 줄·스킬 줄·카드·적·키패드·로그·결과·
## 넘기기 단추와 스킬 목록·결과 본문 끌기. 안의 문맥이 바뀔 때와, 바깥 창(층 3)이 열리고 닫힐 때 탐색 화면이 부른다.
func cancel_pointers() -> void:
	_cancel_pointers()


func _cancel_pointers() -> void:
	if not _built:
		return
	for b in find_children("*", "TouchButton", true, false):
		(b as TouchButton).cancel()
	for sc in find_children("*", "PartyScroll", true, false):
		(sc as PartyScroll).cancel()


# ---- 입력 입구 ----

## 모든 입력이 여기로 온다. 받아들였으면 true. 한 프레임에 하나만.
## kind: command(0~3)·skill(ID)·target({side, slot})·cursor(±1)·target_cursor(±1)·confirm·back·execute·log·log_close·
##       skip·result_ok·commands(명령 배열: 디버그 자동 명령, 같은 조건으로 제출)
func handle(kind: String, arg: Variant = null) -> bool:
	if phase == "closed":
		return false
	if blocked_hook.is_valid() and blocked_hook.call():
		return false  # 전투 층 위에 바깥 창이 떠 있다
	var frame := Engine.get_process_frames()
	if frame == _input_frame:
		return false
	var ok := _dispatch(kind, arg)
	if ok:
		_input_frame = frame
		accepted_inputs += 1
	return ok


func _dispatch(kind: String, arg: Variant) -> bool:
	match phase:
		"anim":
			if kind == "skip" or kind == "confirm":
				_skip()
				return true
			return false
		"result":
			if kind == "result_ok" or kind == "confirm":
				close_layer()
				return true
			return false
	# 명령 단계
	if log_view.visible:
		match kind:
			"log", "log_close", "back":
				log_view.close()
				_refresh()
				return true
			"cursor":
				log_view.scroll_by(int(arg))
				return true
		return false
	match kind:
		"log":
			log_view.open(status_columns())
			_refresh()
			return true
		"command":
			return _choose_command(int(arg))
		"skill":
			return _choose_skill(str(arg))
		"target":
			return _choose_target(arg)
		"cursor":
			return _move_cursor(int(arg))
		"target_cursor":
			return _move_target_cursor(int(arg))
		"confirm":
			return _confirm()
		"back":
			return _back()
		"execute":
			if sub != "confirm":
				return false
			_submit()
			return true
		"commands":
			if typeof(arg) != TYPE_ARRAY:
				return false
			commands = (arg as Array).duplicate(true)
			_submit()
			return true
		"finish":
			return _debug_finish(str(arg) if arg != null else "victory")
	return false


func _on_panel(kind: String, arg: Variant) -> void:
	handle(kind, arg)


## 가상 키패드 = 키(_unhandled_input 과 같은 입구): ↑↓ cursor, ←→ target_cursor, 선택 = Enter(confirm), 취소 = Esc(back).
func _on_vpad(kind: String, arg: Variant) -> void:
	match kind:
		"move":
			var d := arg as Vector2i
			if d.y != 0:
				handle("cursor", d.y)
			elif d.x != 0:
				handle("target_cursor", d.x)
		"ok":
			handle("confirm")
		"back":
			handle("back")


## 가상 키패드의 켤 단추(이름 → 참). 그 단추에 맞는 키가 지금 무언가를 할 때만 켠다(꺼진 단추 = 흐림, 눌러도 아무 일 없음).
## 연출 중에는 모두 끈다(화면 아무 곳 누르기가 넘기기다: 넘기기 받개가 키패드 위에 있다).
func pad_state() -> Dictionary:
	var on := {}
	match phase:
		"result":
			on["ok"] = true
		"command":
			if log_view.visible:
				on = {"up": true, "down": true, "back": true}
			else:
				match sub:
					"menu":
						on = {"up": true, "down": true, "ok": true, "back": _prev_commandable(member) >= 0}
					"skills":
						var any := not _skill_ids().is_empty()
						on = {"up": any, "down": any, "ok": any, "back": true}
					"target":
						var lr := not target_slots.is_empty() and not target_fixed
						on = {"left": lr, "right": lr, "ok": not target_slots.is_empty(), "back": true}
					"confirm":
						on = {"ok": true, "back": _prev_commandable(state.battle.party.size()) >= 0}
	return on


func _refresh_pad() -> void:
	var on := pad_state()
	dir_pad.set_enabled(on)
	key_pad.set_enabled(on)


func _on_card(r: Dictionary) -> void:
	handle("target", r)


## 연출 중 화면 아무 곳 누르기 = 건너뛰기. 흉내 낸 마우스는 버린다(원래 터치와 두 번 처리하지 않는다).
func _on_catcher_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if (ev as InputEventScreenTouch).pressed:
			handle("skip")
		skip_catcher.accept_event()
	elif ev is InputEventMouseButton:
		var m := ev as InputEventMouseButton
		if m.pressed and m.device != InputEvent.DEVICE_ID_EMULATION and m.button_index == MOUSE_BUTTON_LEFT:
			handle("skip")
		skip_catcher.accept_event()


## 키보드(06 §9.2): 1~4 명령, ↑↓ 목록, ←→ 대상, Enter·Space 확정·실행·건너뛰기, Esc·Backspace 뒤로, L 로그. 물리 키.
## 층이 열려 있으면 누른 키는 모두 여기서 끝난다(뒤 미궁 화면의 이동·메뉴·조사로 가지 않는다). 떼기는 그대로 둔다.
func _unhandled_input(event: InputEvent) -> void:
	if phase == "closed" or not event is InputEventKey:
		return
	if blocked_hook.is_valid() and blocked_hook.call():
		return  # 바깥 창과 탐색 화면이 받는다(L 로그 등 전투 키가 창 아래에서 일하지 않는다)
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()
	if k.echo or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	match k.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			handle("command", k.physical_keycode - KEY_1)
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4:
			handle("command", k.physical_keycode - KEY_KP_1)
		KEY_UP:
			handle("cursor", -1)
		KEY_DOWN:
			handle("cursor", 1)
		KEY_LEFT:
			handle("target_cursor", -1)
		KEY_RIGHT:
			handle("target_cursor", 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			handle("confirm")
		KEY_ESCAPE, KEY_BACKSPACE:
			handle("back")
		KEY_L:
			handle("log")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_cancel_pointers()


# ---- 명령 고르기 (06 §9.2) ----

func _begin_turn() -> void:
	commands.clear()
	for i in state.battle.party.size():
		commands.append(null)
	member = _next_commandable(0)
	sub = "menu" if member >= 0 else "confirm"
	cursor = 0
	target_skill = ""
	target_fixed = false
	_refresh()


func _next_commandable(from: int) -> int:
	for i in range(from, state.battle.party.size()):
		if BattleRules.can_command(state, i):
			return i
	return -1


func _prev_commandable(before: int) -> int:
	for i in range(mini(before, state.battle.party.size()) - 1, -1, -1):
		if BattleRules.can_command(state, i):
			return i
	return -1


func _choose_command(i: int) -> bool:
	if sub != "menu" or i < 0 or i > 3:
		return false
	match i:
		0:
			var why := BattleRules.skill_block_reason(state, member, "attack")
			if not why.is_empty():
				_show_notice(_reason_text(why))
				return true
			_enter_target("attack", false)
		1:
			sub = "skills"
			cursor = 0
			_refresh()
		2:
			commands[member] = {"kind": "guard"}
			_advance()
		3:
			var why := BattleRules.escape_block_reason(state, member)
			if not why.is_empty():
				_show_notice(_reason_text(why))
				return true
			commands[member] = {"kind": "escape"}
			_advance()
	return true


func _skill_ids() -> Array[String]:
	var out: Array[String] = []
	if member < 0:
		return out
	for sid in state.battle.party[member].skills:
		out.append(str(sid))
	return out


func _choose_skill(sid: String) -> bool:
	if sub != "skills" or not _skill_ids().has(sid):
		return false
	# 누른 줄로 커서를 옮긴다: 못 쓰는 스킬이어도 설명 칸이 그 스킬을 보이고 이유를 알린다(이어서 Enter 는 같은 줄).
	cursor = _skill_ids().find(sid)
	var why := BattleRules.skill_block_reason(state, member, sid)
	if not why.is_empty():
		_refresh()
		_show_notice(_reason_text(why))
		return true
	# 정해진 대상(자신·아군 전체·적 전체)도 대상 단계로 간다: 그 대상을 모두 밝히고 띠에 스킬 설명을 둔 채 확인을 받는다
	# (터치는 줄을 누르면 바로 정해져 설명을 읽을 수 없었다. 키보드도 같은 단계를 지난다).
	_enter_target(sid, true)
	return true


func _enter_target(sid: String, from_skills: bool) -> void:
	var u := state.battle.party[member]
	var s := BattleRules.skill_of(state, member, sid)
	target_skill = sid
	target_from_skills = from_skills
	target_side = BattleRules.target_side(u, s)
	target_slots = BattleRules.valid_targets(state, member, sid)
	target_fixed = AUTO_TARGETS.has(s.target)
	sub = "target"
	cursor = 0
	_refresh()


func _choose_target(r: Variant) -> bool:
	if sub != "target" or typeof(r) != TYPE_DICTIONARY:
		return false
	if r.get("side") != target_side:
		return false
	var slot := int(r.get("slot", -1))
	if not target_slots.has(slot):
		var du := display.unit(r)
		if du != null and (du.alive() or target_side == BattleUnit.PARTY):
			_show_notice(texts.t("battle.reason.unreachable" if target_side == BattleUnit.ENEMY else "battle.reason.not_target"))
			return true
		return false
	if target_skill == "attack":
		commands[member] = {"kind": "attack", "target": slot}
	elif target_fixed:
		commands[member] = {"kind": "skill", "skill": target_skill}  # 규칙이 대상을 정한다(제출 형식은 바로 확정하던 때와 같다)
	else:
		commands[member] = {"kind": "skill", "skill": target_skill, "target": slot}
	_advance()
	return true


func _advance() -> void:
	member = _next_commandable(member + 1)
	sub = "menu" if member >= 0 else "confirm"
	cursor = 0
	target_skill = ""
	target_fixed = false
	_refresh()


func _back() -> bool:
	match sub:
		"target":
			sub = "skills" if target_from_skills else "menu"
			cursor = maxi(0, _skill_ids().find(target_skill)) if target_from_skills else 0
			target_skill = ""
			target_fixed = false
		"skills":
			sub = "menu"
			cursor = 1
		"menu", "confirm":
			var prev := _prev_commandable(member if sub == "menu" else state.battle.party.size())
			if prev < 0:
				return false
			commands[prev] = null
			member = prev
			sub = "menu"
			cursor = 0
	_refresh()
	return true


func _confirm() -> bool:
	match sub:
		"menu":
			return _choose_command(cursor)
		"skills":
			var ids := _skill_ids()
			return _choose_skill(ids[cursor]) if cursor < ids.size() else false
		"target":
			if target_slots.is_empty():
				return false
			return _choose_target({"side": target_side, "slot": target_slots[cursor]})
		"confirm":
			_submit()
			return true
	return false


func _move_cursor(d: int) -> bool:
	match sub:
		"menu":
			cursor = wrapi(cursor + d, 0, 4)
		"skills":
			var n := _skill_ids().size()
			if n == 0:
				return false
			cursor = wrapi(cursor + d, 0, n)
		_:
			return false
	_refresh()
	return true


func _move_target_cursor(d: int) -> bool:
	if sub != "target" or target_slots.is_empty() or target_fixed:
		return false
	cursor = wrapi(cursor + d, 0, target_slots.size())
	_refresh()
	return true


func _reason_text(code: String) -> String:
	return texts.t("battle.reason." + code) if REASON_KEYS.has(code) else code


func _show_notice(t: String) -> void:
	_notice = t
	_notice_left = NOTICE_SEC
	_redraw_hud()


# ---- 제출 (06 §8.7) ----

func _submit() -> void:
	var events := BattleRules.submit(state, commands.duplicate(true))
	if events.size() == 1 and events[0]["type"] == "rejected":
		_begin_turn()
		_show_notice(texts.t("battle.ui.rejected", {"reason": str(events[0].get("reason", ""))}))
		return
	_commit(events)


## 디버그 주소에서만(웹 확인의 battle_finish): 지금 전투를 규칙의 finish 로 끝내고 제출과 같은 길(저장 → 연출 → 결과 창)로 보인다.
## 전투 승패(밸런스)와 상관없이 전투를 넘기는 확인용. 규칙이 거부하면(전멸이 아닌데 wiped 등) false.
func _debug_finish(how: String) -> bool:
	if not debug:
		return false
	var events: Array[Dictionary] = []
	if not BattleRules.finish(state, how, events):
		return false
	_commit(events)
	return true


## 결과가 정해진 이벤트 열(제출·디버그 끝내기): 연출보다 먼저 저장한다(연출 중 새로고침해도 같은 결과).
func _commit(events: Array[Dictionary]) -> void:
	last_events = events
	if save_hook.is_valid():
		save_hook.call()
	submitted.emit(events)
	_start_anim(events)


# ---- 연출 (06 §9.3) ----

func _start_anim(events: Array[Dictionary]) -> void:
	phase = "anim"
	member = -1
	_cancel_pointers()
	_steps = _make_steps(events)
	_step_i = 0
	_step_t = 0.0
	_announce = ""
	_notice = ""
	_actor = -1
	skip_catcher.visible = true
	_refresh()
	if anim_speed <= 0.0:
		_skip()


static func _make_steps(events: Array[Dictionary]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for ev in events:
		var t: String = ev["type"]
		var merge_guard: bool = t == "guarding" and not steps.is_empty() and steps[-1]["head"].get("type") == "guarding"
		if HEADS.has(t) and not merge_guard:
			steps.append({"head": ev, "details": [], "started": false, "applied": false, "dur": float(STEP_SEC.get(t, 0.3))})
		elif steps.is_empty():
			steps.append({"head": {}, "details": [ev], "started": false, "applied": false, "dur": float(STEP_SEC[""])})
		else:
			steps[-1]["details"].append(ev)
	return steps


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
			_redraw_hud()
	if phase != "anim":
		return
	_step_t += delta * anim_speed
	var guard := 0
	while phase == "anim" and _step_i < _steps.size() and guard < 64:
		guard += 1
		var st: Dictionary = _steps[_step_i]
		if not st["started"]:
			_begin_step(st, true)
		if not st["applied"] and _step_t >= st["dur"] * DETAIL_AT:
			_apply_details(st, true)
		if _step_t < st["dur"]:
			break
		_step_t -= st["dur"]
		_step_i += 1
	if phase == "anim" and _step_i >= _steps.size():
		_end_anim()


func _begin_step(st: Dictionary, animate: bool) -> void:
	st["started"] = true
	var head: Dictionary = st["head"]
	if head.is_empty():
		return
	display.apply(head)
	_log(head)
	var line := display.describe(head)
	if not line.is_empty() and head["type"] != "turn_end":
		_announce = line
	var actor: Variant = head.get("unit")
	_actor = int(actor["slot"]) if ACTOR_HEADS.has(head["type"]) and typeof(actor) == TYPE_DICTIONARY and actor.get("side") == BattleUnit.PARTY else -1
	if animate:
		var who: Variant = head.get("unit", head.get("target"))
		var c := _card_of(who)
		if c != null:
			c.flash = 1.0
		if head["type"] == "poison_tick" and c != null:
			c.pop(str(head["amount"]), Color(0.95, 0.72, 1.0))
	_refresh_cards()
	_redraw_hud()


func _apply_details(st: Dictionary, animate: bool) -> void:
	st["applied"] = true
	for ev in st["details"]:
		display.apply(ev)
		_log(ev)
		if animate:
			_popup_for(ev)
	_refresh_cards()


func _popup_for(ev: Dictionary) -> void:
	var c := _card_of(ev.get("target"))
	if c == null:
		return
	match str(ev["type"]):
		"damaged":
			if ev.get("immune", false):
				c.pop(texts.t("battle.popup.immune"), Color(0.9, 0.9, 0.9))
				return
			var party_hit: bool = ev["target"]["side"] == BattleUnit.PARTY
			var subs: Array[String] = []
			if ev.get("weak", false):
				subs.append(texts.t("battle.popup.weak"))
			if ev.get("crit", false):
				subs.append(texts.t("battle.popup.crit"))
			c.pop(str(ev["amount"]), Color(1.0, 0.62, 0.5) if party_hit else Color(1.0, 1.0, 0.92), " ".join(subs))
		"missed":
			c.pop(texts.t("battle.popup.miss"), Color(0.88, 0.92, 0.96))
		"healed", "revived":
			c.pop("+" + str(ev.get("amount", ev.get("hp", 0))), Color(0.55, 1.0, 0.62))


## 남은 연출을 끝 상태로 바로 맞춘다.
func _skip() -> void:
	while _step_i < _steps.size():
		var st: Dictionary = _steps[_step_i]
		if not st["started"]:
			_begin_step(st, false)
		if not st["applied"]:
			_apply_details(st, false)
		_step_i += 1
	for c in _all_cards():
		c.snap()
	_end_anim()


func _end_anim() -> void:
	skip_catcher.visible = false
	_announce = ""
	_actor = -1
	end_event = {}
	for ev in last_events:
		if ev["type"] == "battle_end":
			end_event = ev
	for c in _all_cards():
		c.snap()
	if end_event.is_empty():
		display.sync(state)
		phase = "command"
		_begin_turn()
		for c in _all_cards():
			c.snap()
		return
	outcome = str(end_event["outcome"])
	if outcome == "wiped":
		close_layer()
		return
	phase = "result"
	_show_result()


func _show_result() -> void:
	var lines: Array[String] = []
	var kinds: Array[String] = []
	if outcome == "victory":
		_result_title.text = texts.t("battle.result.victory")
		var drops: Array = end_event.get("drops", [])
		if drops.is_empty():
			lines.append(texts.t("battle.result.no_drops"))
			kinds.append("line")
		else:
			lines.append(texts.t("battle.result.drops"))
			kinds.append("head")
			# 같은 소재는 한 줄로 모은다(드롭은 한 번에 1개씩, 06 §3.17).
			var order: Array[String] = []
			var sums := {}
			var capped := {}
			for d in drops:
				var item := str(d["item"])
				if not sums.has(item):
					order.append(item)
					sums[item] = 0
				sums[item] += int(d["amount"])
				if d.get("capped", false):
					capped[item] = true
			for item in order:
				var line := texts.t("battle.result.drop", {"item": texts.t(item), "n": sums[item]}) if sums[item] > 0 else ""
				if capped.has(item):
					line = texts.t("battle.result.drop_capped", {"item": texts.t(item)}) if line.is_empty() else line + " " + texts.t("battle.result.capped")
				lines.append(line)
				kinds.append("item")
		for r in growth_rows(end_event):
			lines.append(r["text"])
			kinds.append(r["kind"])
	elif end_event.get("reason", "") == "turn_cap":
		_result_title.text = texts.t("battle.result.ended")
		lines.append(texts.t("battle.result.turn_cap"))
		kinds.append("line")
	else:
		_result_title.text = texts.t("battle.result.escaped")
		lines.append(texts.t("battle.event.escaped"))
		kinds.append("line")
	result_lines = lines
	result_kinds = kinds
	_result_body.text = result_bbcode(lines, kinds)
	result_scroll.scroll_to(0.0)
	result_panel.visible = true
	panel.show_none()
	_cancel_pointers()
	_layout()
	_refresh()


## 승리 battle_end 의 경험치·레벨업 줄(07 §3.5). 성장 필드가 없거나(도주·전멸·턴 상한) exp_total 이 0 이면 경험치 줄이 없다.
## 모두 받았고 같은 양·상한 없음이면 「경험치 +7」 한 줄, 그 밖에는 머리 「경험치」 아래 대원마다 한 줄(칸 순).
## 레벨이 오른 대원이 있으면 머리 「레벨 업」 아래 그 대원마다 「Lv 1 → 2  SP +1」.
func growth_lines(end_ev: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for r in growth_rows(end_ev):
		out.append(r["text"])
	return out


## growth_lines 의 줄과 그 종류([{text, kind}], kind 는 result_kinds 와 같다).
func growth_rows(end_ev: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rows: Array = end_ev.get("members", [])
	if int(end_ev.get("exp_total", 0)) <= 0 or rows.is_empty():
		return out
	var same := true
	for r in rows:
		if r["status"] != "received" or r["capped"] or int(r["gained"]) != int(rows[0]["gained"]):
			same = false
	if same:
		out.append({"text": texts.t("battle.result.exp", {"n": rows[0]["gained"]}), "kind": "line"})
	else:
		out.append({"text": texts.t("battle.result.exp_head"), "kind": "head"})
		for r in rows:
			var who := _member_name(int(r["member"]))
			var t := ""
			match str(r["status"]):
				"down":
					t = texts.t("battle.result.exp_down", {"member": who})
				"at_cap":
					t = texts.t("battle.result.exp_at_cap", {"member": who})
				_:
					var key := "battle.result.exp_member_capped" if r["capped"] else "battle.result.exp_member"
					t = texts.t(key, {"member": who, "n": r["gained"]})
			out.append({"text": t, "kind": "item"})
	var head := true
	for r in rows:
		if int(r["to"]) > int(r["from"]):
			if head:
				out.append({"text": texts.t("battle.result.level_up_head"), "kind": "head"})
				head = false
			var args := {"member": _member_name(int(r["member"])), "from": r["from"], "to": r["to"], "sp": r["sp_gained"]}
			out.append({"text": texts.t("battle.result.level_up_sp" if int(r["sp_gained"]) > 0 else "battle.result.level_up", args), "kind": "item"})
	return out


## 결과 본문 BBCode: 머리 줄은 더 크고(RESULT_HEAD_FS) 따뜻한 색(UiTheme.HEAD_TEXT), 그 밖은 본문 크기·색. 가운데 정렬.
static func result_bbcode(lines: Array[String], kinds: Array[String]) -> String:
	var out: Array[String] = []
	for i in lines.size():
		var t := lines[i].replace("[", "[lb]")
		if i < kinds.size() and kinds[i] == "head":
			out.append("[font_size=%d][color=#%s]%s[/color][/font_size]" % [RESULT_HEAD_FS, UiTheme.HEAD_TEXT.to_html(false), t])
		else:
			out.append(t)
	return "[center]%s[/center]" % "\n".join(out)


func _member_name(i: int) -> String:
	return texts.t(state.defs.party.name_keys[i]) if state != null and i < state.defs.party.name_keys.size() else str(i)


func _log(ev: Dictionary) -> void:
	var line := display.describe(ev)
	if line.is_empty():
		return
	if debug:
		var d := BattleDisplay.debug_detail(ev)
		if not d.is_empty():
			line += "\n    [" + d + "]"
	log_view.add_line(line)


# ---- 그리기 상태 ----

func _all_cards() -> Array[BattleCard]:
	var out: Array[BattleCard] = []
	if enemy_area != null:
		out.append_array(enemy_area.cards)
	if party_cards != null:
		out.append_array(party_cards.cards)
	return out


func _card_of(r: Variant) -> BattleCard:
	if typeof(r) != TYPE_DICTIONARY:
		return null
	var slot := int(r.get("slot", -1))
	return enemy_area.card(slot) if r.get("side") == BattleUnit.ENEMY else party_cards.card(slot)


func _refresh() -> void:
	if not _built or display == null:
		return
	# 문맥이 바뀌면(로그 열기·닫기, 대상·대원·단계 전환, 연출 시작·끝, 결과 창) 앞 문맥에서 시작한 누르기를 버린다:
	# 그 손가락은 뗄 때까지 아무 단추·칸도 누르지 못한다(누른 때와 뗀 때의 문맥이 같아야 한다).
	var ctx := "%s|%s|%d|%s|%s|%s" % [phase, sub, member, target_skill, str(log_view.visible), str(result_panel.visible)]
	if ctx != _context:
		_context = ctx
		_cancel_pointers()
		# 앞 문맥의 안내(「적이 나타났다」·못 고르는 이유)는 메시지 띠에서 지운다: 띠는 새 문맥의 물음·설명을 보인다.
		_notice = ""
		_notice_left = 0.0
	_refresh_cards()
	_refresh_panel()
	_refresh_skill_info()
	_refresh_portrait()
	_refresh_pad()
	_redraw_hud()


func _refresh_cards() -> void:
	var lit_row := ""
	var row_target := false
	if sub == "target" and phase == "command" and not target_slots.is_empty():
		var s := BattleRules.skill_of(state, member, target_skill)
		row_target = s != null and s.target.ends_with("_row")
		if row_target and not target_fixed:
			lit_row = display.effective_row(display.unit({"side": target_side, "slot": target_slots[cursor]}))
	for c in _all_cards():
		var u := c.unit()
		c.cursor = false
		c.reason = ""
		var mark := ""
		if sub == "target" and phase == "command" and c.unit_ref["side"] == target_side:
			if target_slots.has(c.unit_ref["slot"]):
				mark = "valid"
				if target_fixed or (row_target and display.effective_row(u) == lit_row):
					mark = "lit"
				# 정해진 대상은 하나를 가리키지 않는다(커서 없음 → 적 HP 표도 없음: HP 표는 커서 한 대상의 것이다).
				c.cursor = not target_fixed and target_slots[cursor] == c.unit_ref["slot"]
			elif u.alive() or target_side == BattleUnit.PARTY:
				mark = "invalid"
				c.reason = texts.t("battle.reason.unreachable" if target_side == BattleUnit.ENEMY else "battle.reason.not_target")
		c.target_mark = mark
		c.mouse_filter = MOUSE_FILTER_STOP if (u.alive() or not c.is_enemy()) else MOUSE_FILTER_IGNORE
		# 칸은 대상 고르기 중(로그 창이 닫혀 있고 그 편이 대상 쪽)에만 누르기를 받는다.
		c.disabled = not (phase == "command" and sub == "target" and not log_view.visible and c.unit_ref["side"] == target_side)
		if not c.is_enemy():
			var i: int = c.unit_ref["slot"]
			c.current = (phase == "command" and i == member) or (phase == "anim" and i == _actor)
			c.command_text = _command_label(commands[i]) if phase == "command" and i < commands.size() else ""
		c.queue_redraw()
	party_cards.refresh()
	enemy_area.refresh_tag()


func _command_label(c: Variant) -> String:
	if typeof(c) != TYPE_DICTIONARY:
		return ""
	match str(c["kind"]):
		"attack":
			return texts.t("battle.cmd.attack")
		"guard":
			return texts.t("battle.cmd.guard")
		"escape":
			return texts.t("battle.cmd.escape")
		"skill":
			return texts.t(str(c["skill"]))
	return ""


func _refresh_panel() -> void:
	panel.visible = phase == "command"
	if phase != "command":
		panel.show_none()
		return
	if sub == "confirm":
		panel.show_confirm()
		return
	var title := display.party[member].name
	match sub:
		"menu":
			var blocked := {}
			var why := BattleRules.skill_block_reason(state, member, "attack")
			if not why.is_empty():
				blocked[0] = _reason_text(why)
			why = BattleRules.escape_block_reason(state, member)
			if not why.is_empty():
				blocked[3] = _reason_text(why)
			panel.show_menu(title, cursor, _prev_commandable(member) >= 0, blocked)
		"skills":
			var rows := []
			for sid in _skill_ids():
				var s := BattleRules.skill_of(state, member, sid)
				var why := BattleRules.skill_block_reason(state, member, sid)
				rows.append({"id": sid, "name": texts.t(s.name_key), "tp": BattleRules.tp_cost(state.battle.party[member], s),
					"reason": _reason_text(why) if not why.is_empty() else ""})
			panel.show_skills(title, rows, cursor)
		"target":
			panel.show_target(title, 1 if target_from_skills else 0)


## 초상·TP 게이지: 명령을 고르는 대원이 있을 때만(연출·결과·모두 고른 뒤에는 감춘다, 원작 1810820_1f51fd75).
func _refresh_portrait() -> void:
	var on := phase == "command" and member >= 0 and not log_view.visible
	portrait.visible = on
	if on:
		var u := display.party[member]
		var cid: String = party_cards.cards[member].class_id
		portrait.show_member(u.name, BattleCard.CLASS_COLORS.get(cid, Color(0.7, 0.7, 0.7)), u.tp, u.max_tp)


## 스킬 목록에서 커서가 있는 스킬, 또는 목록에서 고른 스킬의 대상 고르기 동안 그 스킬 설명(06 §9.2, M2.6 U2).
## 숫자는 SkillSummary 가 스킬 정의에서 읽는다. 메시지 띠에 보인다(원작에 스킬 목록 화면이 없어 가장 가까운 메시지 자리). 로그 창이 열리면 감춘다.
func _refresh_skill_info() -> void:
	var sid := ""
	if phase == "command" and not log_view.visible:
		if sub == "skills":
			var ids := _skill_ids()
			if cursor >= 0 and cursor < ids.size():
				sid = ids[cursor]
		elif sub == "target" and target_from_skills:
			sid = target_skill
	if sid.is_empty():
		skill_info_title = ""
		skill_info_text = ""
		return
	var s := BattleRules.skill_of(state, member, sid)
	var level := int(state.battle.party[member].skills.get(sid, 1))
	skill_info_title = SkillSummary.head(texts, s, level)
	skill_info_text = SkillSummary.line(texts, s, level)


## 스킬 설명이 보이는지(메시지 띠).
func skill_info_shown() -> bool:
	return not skill_info_title.is_empty()


## 앵커가 못 하는 것만: 로그 창·결과 창 크기와 자리(결과 본문 높이에 맞춘다).
func _layout() -> void:
	if not _built:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	# 스킬 판: 「스킬」 줄 위 ~ 파티 카드 위 − 8(화면 높이를 따른다).
	var skill_top := CommandPanel.row_y(1)
	panel.set_skill_area(Rect2(SKILL_X - LIST_X, skill_top, SKILL_W, s.y - PartyCards.HEIGHT - 8.0 - LIST_TOP - skill_top))
	# 로그 창: 띠 아래 ~ 방향키 위, 왼쪽 16 ~ 선택·취소 열 왼쪽(키패드는 로그 창이 열린 동안에도 누른다: ↑↓ 내리기, 취소 닫기).
	var log_bottom := minf(s.y - PartyCards.HEIGHT, s.y - PAD_BOTTOM - VirtualPad.dirs_size().y) - 8.0
	log_view.position = Vector2(16, LIST_TOP)
	log_view.size = Vector2(s.x - ENEMY_RIGHT - 16.0, log_bottom - LIST_TOP)
	# 결과 창: 본문 줄이 많으면 높이를 늘리되 알림 줄 아래부터 화면 아래 8 안에 둔다(메시지 띠·알림 줄을 가리지 않는다).
	# 그래도 넘치면 본문을 끌어 내린다(07 §9.6).
	var body_w := RESULT_W - 40.0
	_result_body.size = Vector2(body_w, 0)
	var body_h := maxf(1.0, float(_result_body.get_content_height()))
	var chrome := RESULT_TOP + RESULT_GAP + result_ok.size.y + RESULT_BOTTOM
	# 제목 문패가 창 위로 반 나온다: 문패도 알림 줄 아래에.
	var clear_top := TOAST_Y + TOAST_H + 4.0 + _result_title.size.y / 2.0
	var rp := Vector2(RESULT_W, clampf(chrome + body_h, RESULT_MIN_H, maxf(RESULT_MIN_H, s.y - 8.0 - clear_top)))
	result_panel.size = rp
	var party_top := s.y - PartyCards.HEIGHT
	var py := roundf((party_top - LIST_TOP - rp.y) / 2.0 + LIST_TOP)
	var low := maxf(8.0, s.y - 8.0 - rp.y)
	result_panel.position = Vector2(roundf((s.x - rp.x) / 2.0), clampf(py, minf(clear_top, low), low))
	_result_title.position = Vector2(roundf((rp.x - _result_title.size.x) / 2.0), -_result_title.size.y / 2.0)
	result_scroll.position = Vector2(20, RESULT_TOP)
	result_scroll.size = Vector2(body_w, rp.y - chrome)
	_result_body.position = Vector2.ZERO
	_result_body.size = Vector2(body_w, body_h)
	result_scroll.set_content_height(body_h)
	result_ok.position = Vector2((rp.x - result_ok.size.x) / 2.0, rp.y - result_ok.size.y - RESULT_BOTTOM)
	_redraw_hud()


## 턴 문패 자리.
func turn_plate_rect() -> Rect2:
	return TURN_PLATE


## 위 메시지 띠 자리(턴 문패 오른쪽 ~ 화면 오른쪽 끝).
func banner_rect() -> Rect2:
	return Rect2(BANNER_X, 0, maxf(0.0, size.x - BANNER_X), BANNER_H)


## 메시지 띠의 두 줄 [첫 줄, 둘째 줄, 둘째 줄이 안내인지]. 연출 중 = 행동 글, 명령 단계 = 물음·스킬 설명·대상 안내·준비 끝,
## 결과 창 = 결과 제목. 안내(못 고르는 이유·제출 거부 등)가 있으면 둘째 줄을 안내로 바꾼다(첫 줄은 그대로).
func banner_lines() -> Array:
	var head := ""
	var body := ""
	match phase:
		"anim":
			head = _announce
		"result":
			head = _result_title.text
		"command":
			if log_view.visible:
				head = texts.t("battle.ui.log")
			elif skill_info_shown() and sub == "skills":
				head = skill_info_title
				body = skill_info_text
			else:
				match sub:
					"menu", "skills":
						head = texts.t("battle.ui.prompt", {"member": display.party[member].name})
					"target":
						if target_fixed:
							var scope := texts.t("battle.scope." + BattleRules.skill_of(state, member, target_skill).target)
							head = texts.t("battle.ui.fixed_target", {"scope": scope, "skill": display.skill_name(target_skill)})
						else:
							head = texts.t("battle.ui.choose_target", {"skill": display.skill_name(target_skill)})
						body = skill_info_text
					"confirm":
						head = texts.t("battle.ui.ready")
	if phase != "anim" and not _notice.is_empty():
		return [head, _notice, true]
	return [head, body, false]


## 지금 띠에 보일 글(연출 중 알림, 아니면 안내).
func banner_text() -> String:
	return _announce if phase == "anim" else _notice


func _redraw_hud() -> void:
	queue_redraw()


## 바탕: 어둡게 한 3D 시야, 위 메시지 띠(파랑 그라데이션, 왼쪽 아래 모서리를 깎는다), 턴 문패.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BATTLE_DIM)
	if display == null:
		return
	var font := get_theme_default_font()
	var b := banner_rect()
	var cut := 28.0
	var pts := PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x + cut, b.end.y),
		Vector2(b.position.x, b.end.y - cut)])
	var cols := PackedColorArray()
	for p in pts:
		cols.append(UiTheme.BATTLE_BANNER_TOP.lerp(UiTheme.BATTLE_BANNER_BOTTOM, p.y / BANNER_H))
	draw_polygon(pts, cols)
	draw_line(Vector2(b.position.x, b.end.y - 1.5), Vector2(b.end.x, b.end.y - 1.5), UiTheme.CMD_PLATE_EDGE, 3.0)
	var lines := banner_lines()
	var tw := b.size.x - 2.0 * BANNER_PAD - LOG_BUTTON.x - LOG_RIGHT  # 글은 로그 단추 왼쪽에서 끝난다
	var head_y := 44.0 if not str(lines[1]).is_empty() else b.get_center().y + BANNER_FS * 0.36
	draw_string(font, Vector2(b.position.x + BANNER_PAD, head_y), lines[0], HORIZONTAL_ALIGNMENT_LEFT, tw, BANNER_FS, ANNOUNCE_TEXT)
	if not str(lines[1]).is_empty():
		draw_string(font, Vector2(b.position.x + BANNER_PAD, 80.0), lines[1], HORIZONTAL_ALIGNMENT_LEFT, tw, BANNER_SUB_FS,
			NOTICE_TEXT if lines[2] else ANNOUNCE_TEXT)
	# 턴 문패: 둥근 남색 판, 큰 숫자, 아래 「턴」.
	var t := TURN_PLATE
	UiTheme.fill_round(self, t, UiTheme.TURN_FILL, 18, UiTheme.CMD_PLATE_EDGE, 2)
	draw_string(font, Vector2(t.position.x, t.position.y + 44.0), str(display.turn + 1), HORIZONTAL_ALIGNMENT_CENTER, t.size.x, TURN_FS,
		UiTheme.BATTLE_BANNER_TEXT)
	draw_string(font, Vector2(t.position.x, t.end.y - 12.0), texts.t("battle.ui.turn_word"), HORIZONTAL_ALIGNMENT_CENTER, t.size.x,
		TURN_LABEL_FS, UiTheme.BATTLE_BANNER_TEXT)


## 로그 창 위에 보이는 지금 상태 전부(06 §9.1 상태 표의 전체 보기). 적 HP 숫자는 쓰지 않는다(D13).
func status_text() -> String:
	return "\n".join(status_columns())


## 상태 목록 두 칸: [아군 줄들, 적 줄들]. 로그 창이 왼쪽·오른쪽에 나눠 그린다(06 §9.4).
func status_columns() -> Array[String]:
	var party: Array[String] = []
	var foes: Array[String] = []
	for u in display.party:
		party.append(_status_line(u))
	for u in display.enemies:
		foes.append(_status_line(u))
	return ["\n".join(party), "\n".join(foes)] as Array[String]


func _status_line(u: Variant) -> String:
	var parts: Array[String] = [u.name]
	if u.side == BattleUnit.PARTY:
		parts.append("HP %d/%d  TP %d/%d" % [u.hp, u.max_hp, u.tp, u.max_tp])
	if not u.alive():
		parts.append(texts.t("battle.ui.down"))
	for c in display.chips(u):
		var mark := "↑" if c["kind"] == "buff" else "↓" if c["kind"] == "debuff" else ""
		parts.append(mark + str(c["text"]))
	if not u.charging.is_empty():
		parts.append("! " + display.skill_name(u.charging))
	return " · ".join(parts)


# ---- 시험·디버그 읽기 ----

## 지금 누를 수 있는 전투 층 단추 전부(로그 창·결과 창이 덮은 단추는 빼고, 연출 중이면 없음). 가상 키패드는 켜진 단추만.
func visible_buttons() -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	if phase == "anim" or phase == "closed":
		return out
	for vp in [dir_pad, key_pad]:
		for k in (vp as VirtualPad).buttons:
			var pb: TouchButton = vp.buttons[k]
			if pb.is_visible_in_tree() and not pb.disabled:
				out.append(pb)
	var root_node: Node = self
	if result_panel.visible:
		root_node = result_panel
	elif log_view.visible:
		root_node = log_view
		out.append(log_button)
	for n in root_node.find_children("*", "TouchButton", true, false):
		var b := n as TouchButton
		if b.is_visible_in_tree() and b.mouse_filter != MOUSE_FILTER_IGNORE and not out.has(b) and not (b.get_parent() is VirtualPad):
			# 스킬 판이 덮은 칸(적)은 누를 수 없다(판이 받는다).
			if b is BattleCard and panel.skill_panel.is_visible_in_tree() and panel.skill_panel.get_global_rect().intersects(b.get_global_rect()):
				continue
			# 스킬 목록 줄은 목록 안에 다 보일 때만(잘려 안 보이는 줄의 가운데는 다른 것 위다)
			if b is PartyButton and (b as PartyButton).scroller != null and not (b as PartyButton).scroller.shows(Rect2(b.position, b.size)):
				continue
			out.append(b)
	return out


## 디버그 요청 snapshot 의 전투 정보(06 §8.9). css 는 (컨트롤 안 점, 컨트롤) → [x, y] 브라우저 좌표.
func debug_info(css: Callable) -> Dictionary:
	if phase == "closed" or state == null:
		return {"open": false}
	var buttons := {}
	for b in visible_buttons():
		buttons[b.name] = css.call(b.size / 2.0, b)
	var enemy_hp := []
	var charging := []
	if state.battle != null:
		for u in state.battle.enemies:
			enemy_hp.append(u.hp)
			charging.append(u.charging)
	return {"open": true, "phase": phase, "sub": sub, "member": member, "turn": display.turn,
		"targets": target_slots if sub == "target" else [], "target_side": target_side if sub == "target" else "",
		"target_fixed": target_fixed if sub == "target" else false,
		"enemy_hp": enemy_hp, "charging": charging, "log": log_view.visible, "log_lines": log_view.lines.size(), "outcome": outcome,
		"result_lines": result_lines if phase == "result" else [], "panel": panel.visible,
		"skill_info": [skill_info_title, skill_info_text] if skill_info_shown() else [], "banner": banner_lines().slice(0, 2), "buttons": buttons}
