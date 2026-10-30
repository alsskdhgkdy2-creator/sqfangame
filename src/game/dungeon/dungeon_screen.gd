## 미궁 탐색 화면(주 장면, 05 §9). 탐색 상태를 가지고 규칙 함수로만 바꾼다. 시야·지도·상태 표시는 읽기만 한다.
## 자동 저장(05 §8.4, 06 §8.7): 거부되지 않은 규칙 행동, 지도 편집 한 단계·실행 취소, 전투 턴 제출(전투 끝 포함, 전투 층이
## 연출 전에 부른다), 새 게임, 수동 슬롯 불러오기, 가져오기 직후, 파티 메뉴의 배분 확정·장착 변경·임시 보급(07 §8.5).
## 저장 쓰기는 한 프레임 안에서 끝낸다(웹 IndexedDB 반영, 05 §8.3).
## 입력(05 §9.3): 키보드는 _unhandled_input, 화면 단추는 TouchButton. 창이 열려 있거나 전투 중·전멸이면 이동을 받지 않는다.
## 화면 짜임(M2.7 R1, research 05 §1.2·§2.2): 3D 시야는 언제나 화면 전체이고 UI 는 그 위 CanvasLayer 에 뜬다.
##   층 0 ViewContainer(시야, 크기를 바꾸지 않는다)·피해 번쩍임 → 층 1 Hud(층 문패·미니맵·위험 보석·이동 단추·안내 줄)
##   → 층 2 Windows(지도 판·전투 층·파티 메뉴) → 층 3 Modal → 층 4 Toast. 보이는 위아래 = 누르는 위아래.
##   층마다 화면 전체 뿌리 Control(IGNORE), 부품은 앵커 + 여백으로 가장자리·모서리에 붙인다.
##   지도 판은 오른쪽을 덮고 시야는 렌즈를 밀어 소실점을 덮이지 않은 영역 가운데로 옮긴다(DungeonView.set_lens_cover).
## 전투(06 §9): 전투 중이면 전투 층(BattleLayer)을 덮는다. HUD·지도 판을 감춘다.
## 캠프(07 §9, M2.7 R2): 안내 줄 「캠프」 단추·P·Esc 로 여는 층 2 의 창(PartyMenu). 열린 동안은 창이 열린 것과 같다(이동·지도·메뉴 키를 막는다).
## 저장·불러오기·내보내기·가져오기·자동 지도·새 게임은 캠프 「기록」 화면이 records 갈고리로 부른다(따로 된 메뉴 창은 없다, R2-d).
## 층 3 Modal 은 알림·파일 고르기·메모·전멸·계단 확인 창만 띄운다.
## 계단(M3 A1): 계단 칸에 멈추거나 계단 위에서 조사하면 연출이 끝난 뒤 계단 확인 창(「예」 먼저, Esc·Backspace = 「아니오」)을 띄우고,
##   「예」면 규칙 행동 STAIRS 로 층을 바꾼 뒤 시야·지도·층 문패를 그 층으로 다시 맞추고 자동 저장한다. 위험도·걸음은 그대로다.
## 미리 받는 입력은 하나(나중 것이 대신)이고, 창이 열릴 때·불러올 때·포커스를 잃을 때·입력 창이 닫힌 뒤 비운다.
## 마을(M3 A2): 시작은 타이틀(TitleScreen, 층 2 맨 위)이다. 상태가 마을에 있으면 마을 화면(TownScreen, 층 2)과 층 0 마을 바탕
##   (TownBackdrop)을 띄우고 3D 시야·HUD·지도를 감춘다. 타이틀·마을에서는 시야 SubViewport 를 그리지 않고(UPDATE_DISABLED)
##   시야 노드의 처리(연출·카메라 보정)도 멈춘다. 미궁에 들어가면(ENTER) 되살린다. B1F 시작 칸이 마을 문이다(계단 물음과 같은 창).
class_name DungeonScreen
extends Control

## 층 묶음(미궁 하나, M3 A1): 층 차례가 깊이(B1F, B2F, …). 게임은 실제 미궁(arbor, M3 A3)이다.
const LABYRINTH_PATH := "res://data/floors/arbor.json"
## 시험 층 묶음(f1_test·f2_test, M3 A3): 장면 시험 도구(scene_kit.open)와 디버그 주소 &set=test 가 쓴다.
const TEST_LABYRINTH_PATH := "res://data/floors/labyrinth.json"
## 저장 폴더. 시험 층 묶음으로 띄운 디버그 실행(&set=test)은 따로 된 폴더를 써서 두 묶음이 서로의 저장을 읽거나 옮기거나 지우지 않는다.
const SAVE_DIR := "user://saves"
const TEST_SAVE_DIR := "user://saves_test"
const PARTY_PATH := "res://data/party/test_party.json"
const TEXT_PATH := "res://data/text/ko.json"
const DATA_DIR := "res://data"
const A := ExplorationRules.Action
## InputMap 동작 → 규칙 행동. 누르고 있으면 반복하는 순서이기도 하다.
const KEY_ACTIONS := {
	"move_forward": A.FORWARD, "move_back": A.BACK, "strafe_left": A.STRAFE_LEFT, "strafe_right": A.STRAFE_RIGHT,
	"turn_left": A.TURN_LEFT, "turn_right": A.TURN_RIGHT, "investigate": A.INVESTIGATE,
}
## 누르고 있으면 반복하는 행동(조사는 반복하지 않는다).
const REPEATABLE := [A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT, A.TURN_LEFT, A.TURN_RIGHT]
const PAD_BUTTON := 80.0
## 메뉴의 저장 칸 단추 높이(세 줄: 슬롯·층과 걸음·시각).
const PAD_GAP := 8.0
## 화면 가장자리 여백(HUD 부품).
const EDGE := 12.0
## 안내 줄(원작 왼쪽 아래 CAMP·MAP 안내 자리) 단추 크기와 간격.
const HINT_H := 64.0
const HINT_GAP := 8.0
## 이동 단추 묶음(3×2 + 조사 열) 크기(휴식 칸은 M3 A2b 에서 없앴고 자리는 비워 둔다).
const PAD_W := 3.0 * (PAD_BUTTON + PAD_GAP) + 8.0 + PAD_BUTTON + 16.0
const PAD_H := 2.0 * PAD_BUTTON + PAD_GAP
## 미니맵 크기(원작 III HD gw_28: 16:9 화면의 가로 약 17%·세로 약 20%).
const MINI_SIZE := Vector2(218, 144)
## 층 문패(원작 왼쪽 위 다이얼 자리) 크기.
const PLATE_SIZE := Vector2(250, 76)
## CanvasLayer 번호.
const LAYER_HUD := 1
const LAYER_WINDOWS := 2
const LAYER_MODAL := 3
const LAYER_TOAST := 4
const PROMPT_BLOCKED_MS := 40
## 「저장 중」 표시의 글자 크기·높이와 화면 위 가장자리 여백.
const SAVE_CHIP_FONT := 15
const SAVE_CHIP_H := 26.0
## 알림 줄 높이, 창 판과 띄우는 틈(창이 열린 동안 판 위·아래 빈 띠에 둔다).
const TOAST_H := 36.0
const TOAST_GAP := 8.0
## 보스 물음의 둘째 줄(「이 싸움에서는 도망칠 수 없다」) 경고 색(M3 A9b, 공용 경고 색).
const BOSS_WARN := UiTheme.CAMP_NOTICE_WARN
## 저장 실패 안내가 보이는 시간(알림 줄 한 번과 같다), 탐색 중 그 띠와 일반 알림 줄 사이 틈.
const WARN_SEC := 2.0
const WARN_GAP := 4.0
## 탐색 중 일반 알림 줄의 아래 끝(화면 아래에서): 이동 단추 묶음 바로 위.
const TOAST_ROW_BOTTOM := -EDGE - HINT_H - HINT_GAP - PAD_H - 10.0
const SAVE_CHIP_TOP := 4.0
## 누르고 있기 반복은 누른 지 이만큼 지나야 시작한다(연출이 없는 행동 뒤 짧은 누르기가 두 번 되지 않게).
const HOLD_REPEAT_MS := 220

# ---- 시험이 트리에 넣기 전에 바꿀 수 있는 값 ----
var save_dir := SAVE_DIR
## 정의 데이터 경로(시험이 읽기 실패를 만들 때 바꾼다).
var labyrinth_path := LABYRINTH_PATH
var party_path := PARTY_PATH
var data_dir := DATA_DIR
## 시험용: "export_write"·"import_read" 가 들어 있으면 네이티브 내보내기 쓰기·가져오기 읽기 뒤 오류가 난 것처럼 한다.
var file_fail_points: Array[String] = []
var settings_path := GameSettings.PATH
## "" = 실제 플랫폼, "web"·"native" = 그렇게 본다.
var platform := ""
## 0 이상이면 새 게임 시드로 쓴다(디버그 주소의 &seed=N 도 여기에 들어간다).
var seed_override := -1
## 시험용 저장 반영 읽기(SavePending.reader 꼴). 비어 있지 않으면 웹 연결 대신 이것을 쓴다.
var save_reader: Callable
## 시험용: -1 = 실제(OS.is_userfs_persistent), 0·1 = user:// 가 IndexedDB 에 이어져 있지 않음·있음으로 본다.
var userfs_persistent := -1
## 시험용 주소 인자 글("debug=1&seed=5"): 비어 있지 않으면 브라우저 주소 대신 이것을 본다.
var url_query := ""
var anim_speed := 1.0
## 네이티브 디버그 실행인지(파티 메뉴의 임시 보급, 07 §5.7). 시험은 일반 실행을 보려고 false 로 바꾼다.
var native_debug := OS.is_debug_build()
## 시작 방식(M3 A2): "title" = 타이틀(실제 게임), "labyrinth" = 자동 저장을 읽거나 B1F 에서 새 게임(장면 시험 기본),
## "town" = 자동 저장을 읽거나 마을에서 새 게임(시험).
var start_mode := "title"

# ---- 상태 ----
var state: ExplorationState
## 시야·지도가 지금 보이는 층(층이 바뀌면 _show_floor 가 맞춘다).
var floor_def: FloorModel
var party_data: PartyData
var texts: TextDb
var settings: GameSettings
var store: SaveStore
var bridge: WebBridge
## 웹 저장의 IndexedDB 반영 기다림(05 §8.3). 기다리는 동안 「저장 중」 표시.
var save_pending := SavePending.new()
## 자동 저장에 성공한 횟수와 마지막 실패 이유(시험·디버그용).
var autosave_count := 0
var last_autosave_error := ""
## 마지막 의뢰 진행 세기(QuestRules.observe, M3 A8)가 낸 의뢰 이벤트(탐색 행동 또는 전투 제출). A8b 의 알림이 읽는다.
var quest_events: Array[Dictionary] = []
## 전투 제출이 센 의뢰의 안내(M3 A8b 설계 §6.5): 전투 동안 들고 있다가 전투 층이 닫힐 때(전멸이 아니면) 띄운다.
var _battle_quest_note := ""
## 디버그 상태 요약을 낸 횟수(시험: 타이틀에서도 입력마다 다시 내는지).
var debug_publishes := 0

# ---- 화면 부품 ----
var view: DungeonView
var view_container: SubViewportContainer
## 지도 판(층 2)과 그 안의 그리기 격자·도구 열.
var map_window: MapWindow
var map: MapPanel
var toolbar: MapToolbar
## HUD(층 1): 뿌리(화면 전체), 시야 영역(지도 판이 덮지 않는 곳), 미니맵·위험 보석·층 문패·이동 단추 묶음·안내 줄.
var hud_root: Control
var view_area: Control
var minimap: MapOverview
var orb: DangerOrb
var floor_plate: Control
var pad_box: Control
var hint_row: HBoxContainer
## 창 층(층 2)의 뿌리와 알림 층(층 4)의 알림 영역.
var windows_root: Control
var toast_area: Control
var layers := {}  # 이름 → CanvasLayer
var modal: ModalLayer
## 클리어 이야기 상자(M3 A9b 설계 §5.3): 창 층이 kind "clear" 로 띄우는 공용 부품(StoryBox). 보이기만 하고 저장하지 않는다.
var story_box: StoryBox
## 이번 전투가 쓰러뜨린 보스 FOE id(전투 제출 갈고리가 적고, 승리로 전투 층이 닫히면 이야기 상자를 연다). 없으면 "".
var _clear_foe := ""
var battle_layer: BattleLayer
var party_menu: PartyMenu
## 상점(08 §8): 마을 광장 「정크 공방」으로 연다(M3 A2, R4 S4).
var shop_screen: ShopScreen
## 모험가 길드(M3 A7c, 층 2 상점 뒤): 광장 「모험가 길드」에서 연다.
var guild_screen: GuildScreen
var quest_screen: QuestScreen
## 마을 화면·타이틀(층 2)과 마을 바탕(층 0, 3D 시야 위·HUD 아래).
var town_screen: TownScreen
var title_screen: TitleScreen
var town_backdrop: TownArt.TownBackdrop
## 정의 읽기에 실패했을 때의 오류 화면(06 §5.6). 정상 시작이면 null.
var start_error: Control
var pad := {}  # 규칙 행동 → TouchButton
var map_button: TouchButton
## 안내 줄 「캠프」(원작 CAMP·MAP 의 CAMP).
var camp_button: TouchButton
var _floor_label := Label.new()
var _steps_label := Label.new()
var _toast := Label.new()
var _toast_left := 0.0
## 지금 알림 줄이 저장 실패 안내인지: 계단·마을 문 물음이 떠도 이것은 남긴다(05 §8.4, 다른 안내는 물음 띠와 겹치므로 지운다).
## 저장 실패 안내(05 §8.4)는 일반 알림 줄과 따로 이 화면이 가진다(검토 R1~R4): 글과 남은 시간 하나, 자기 글줄(_warn_label).
## 보일 곳은 매 프레임 정한다(_warn_sync): 창(층 3) 둘레 빈 띠 → 화면 창 안내 줄 → 전투 띠 → 탐색 띠(알림 줄 바로 위).
var _warn_text := ""
var _warn_left := 0.0
var _warn_at: Object = null  # 지금 띄운 곳: 화면 창, _warn_label, null(창 둘레에 자리가 없어 들고만 있다)
var _warn_label := Label.new()
## 전멸 뒤 지도 물음에 답하면 들어갈 상태(읽은 수동 저장 또는 마을 새 게임)와, 그것이 읽은 저장인지(안내·저장 실패 알림이 다르다).
var _wipe_target: ExplorationState
var _wipe_loaded := false
## 그 읽은 저장이 시험 층에서 옮긴 것인지(M3 A3: 답한 뒤 옮김 알림).
var _wipe_relocated := false
## 「저장 중」 표시(층 4, 화면 위 가운데). 대기가 있으면 보이고 없으면 바로 감춘다(나타날 때만 짧게 밝아진다).
var save_chip := Control.new()
var _flash := ColorRect.new()

var _queued := -1
## 이동 단추를 누른 시각(행동 → 밀리초). 누르고 있기 반복의 기준.
var _pad_since := {}
## 승인된 키(InputMap 동작 이름 → 누른 시각): 막히지 않은 상태에서 _unhandled_input 으로 눌림을 받은 키만.
## 창이 열리고 닫힐 때·포커스를 잃을 때·불러오기·가져오기 때 지운다. 지운 키는 뗐다가 다시 눌러야 반복한다.
var _key_since := {}
## 연출은 끝났지만 반복 시작 시각이 아직 아니라 기다리는 중.
var _repeat_wait := false
## 마지막 행동을 한 프레임. 같은 프레임의 두 번째 행동은 미리 받는 칸으로 미룬다.
var _action_frame := -1
## 지도 획이 열려 있어 미룬 자동 저장(획이 끝나거나 취소된 뒤 저장한다).
var _autosave_pending := false
## 이번 행동이 계단 칸에서 끝났다(stairs 이벤트): 연출이 끝나면 계단 확인 창을 띄운다(M3 A1).
## 창을 띄울 수 없는 동안(다른 창이 열림)에는 남겨 두고 그 창이 닫힐 때 다시 본다. 띄우거나 상태가 바뀌면 지운다.
var _stairs_ask := false
## 네이티브 파일 고르기 요청 번호(창마다 오른다). 낡은 요청의 콜백을 가린다.
var _file_req := 0
## 불러오기·가져오기·새 게임마다 오른다. 늦게 온 가져오기 결과를 가린다.
var _epoch := 0
var _import_token := 0
var _import_epoch := -1
## 지도 판이 열렸는지. 기본은 닫힘(원작 탐색 기본 화면: 시야 전체 + 다이얼·미니맵·위험 보석·안내 줄).
var _map_open := false
## 전투 층이 덮고 있어 탐색 부품을 감춘 상태.
var _battle_view := false
## 디버그 상태 요약을 다시 낼지 보려고 기억하는 전투 층 모습(단계·명령 단계·대원).
var _debug_battle_sig := ""
var _debug := false
var _debug_dirty := false
var _debug_busy := false
var _debug_settle := 0
## 지도 보기(그리기 격자·층 전체 보기·미니맵)가 마지막으로 맞춘 지도 표시와 그 판(version).
var _views_ann: MapAnnotation
var _views_version := -1
var _file_dialog: FileDialog
## 시야 SubViewport 와 그 원래 갱신 방식. _view_on 이 거짓이면 그리지 않고 시야 노드도 멈춘다(타이틀·마을).
var _view_sv: SubViewport
var _view_sv_mode := SubViewport.UPDATE_WHEN_VISIBLE
var _view_on := true
## 시야를 끈 뒤 아직 층 메시를 다시 만들지 않았다.
var _view_floor_stale := false


func _ready() -> void:
	theme = _make_theme()
	texts = TextDb.load_path(TEXT_PATH)
	# 주소 인자는 정의를 읽기 전에 본다: 디버그 주소의 &set=test 면 시험 층 묶음과 그 저장 폴더(M3 A3).
	bridge = WebBridge.new(platform, url_query)
	_apply_set_query()
	var dr := GameDefs.load_paths(labyrinth_path, party_path, data_dir, texts)
	if not dr.ok():
		push_error("정의 데이터를 읽지 못했다: %s" % "; ".join(dr.errors))
		_show_start_error(dr.errors)
		return
	floor_def = dr.defs.first_floor()
	party_data = dr.defs.party
	settings = GameSettings.load_from(settings_path)
	store = SaveStore.new(dr.defs, save_dir)
	bridge.on_import = _on_import_result
	_setup_save_pending()
	_build_ui()
	# 디버그 주소는 시작(저장 복구·새 게임) 전에 본다: 복구된 전투 층도 판정 상세를 쓰고, &seed=N 이면 새 게임 시드가 N.
	if bridge.debug_requested():
		_debug = true
		var debug_seed := bridge.debug_seed()
		if debug_seed >= 0:
			seed_override = debug_seed
		bridge.on_debug_request = _on_debug_request
		bridge.setup_debug()
		_debug_dirty = true
	_boot()


## 디버그 주소(?debug=1)의 &set=test(M3 A3): 시험 층 묶음과 시험 저장 폴더로 바꾼다. 시험이 이미 바꾼 경로·폴더는 그대로 둔다.
## 디버그 주소가 아니면 set 인자는 보지 않는다(실제 게임은 늘 실제 미궁과 user://saves).
func _apply_set_query() -> void:
	if not bridge.debug_requested() or bridge.url_param("set") != "test":
		return
	if labyrinth_path == LABYRINTH_PATH:
		labyrinth_path = TEST_LABYRINTH_PATH
	if save_dir == SAVE_DIR:
		save_dir = TEST_SAVE_DIR


## 시작 방식대로 시작한다(M3 A2).
func _boot() -> void:
	match start_mode:
		"labyrinth":
			_start()
		"town":
			_start(true)
		_:
			_open_title()


## 타이틀을 띄운다: 자동 저장을 읽을 수 있으면 「이어하기」가 첫 줄. 읽을 후보가 있는데 모두 깨졌으면 알림을 띄운다.
func _open_title() -> void:
	var l := store.load_slot(SaveStore.AUTO)
	title_screen.open(l.ok())
	_layout()
	if not l.ok() and l.had_candidates:
		_alert(texts.t("title.auto_broken"))
	_debug_dirty = true


## 타이틀 「이어하기」: 자동 저장을 읽는다(저장하지 않는다, 05 §8.4). 그사이 깨졌으면 알림만.
func _continue_game() -> void:
	var l := store.load_slot(SaveStore.AUTO)
	if not l.ok():
		_alert(texts.t("msg.load_failed", {"reason": l.result.error}))
		return
	_set_state(l.result.state)
	_after_load(l.result.relocated)


## 자동 저장을 읽거나(있으면) 새 게임으로 시작한다. in_town 이면 새 게임은 마을에서(시험의 "town" 시작).
func _start(in_town: bool = false) -> void:
	var l := store.load_slot(SaveStore.AUTO)
	if l.ok():
		_set_state(l.result.state)
		_after_load(l.result.relocated)
		return
	_set_state(_new_state(in_town))
	_autosave()
	if l.had_candidates:
		_alert(texts.t("msg.auto_broken"))
	_check_windows()


## 저장을 읽어 상태를 바꾼 뒤: 시험 층 저장을 옮겼으면(M3 A3) 알림을 띄우고(head = 안내 줄이 있으면 그 줄을 알림 첫 줄로),
## 전멸·전투 창은 알림을 닫은 뒤 연다(_close_alert). 아니면 안내 줄을 띄우고 바로 창을 본다.
## 옮김 알림 때는 안내 줄을 알림 첫 줄로 옮긴다(창이 열린 동안 알림 줄은 그리지 않는다: _show_toast).
func _after_load(relocated: bool, head: String = "") -> void:
	if relocated:
		_alert(texts.t("msg.relocated") if head.is_empty() else head + "\n" + texts.t("msg.relocated"))
		return
	if not head.is_empty():
		_show_toast(head)
	_check_windows()


## 읽거나 가져온 상태로 바꾸고 자동 저장한 뒤의 안내(불러오기·가져오기·전멸 뒤 기록으로 돌아가기). 옮긴 저장이면(M3 A3) 안내 글과
## 옮김을 한 알림에 적는다. 자동 저장에 실패했으면 실패와 옮김을 한 알림에 함께 적는다(둘 다 알린다). 전멸·전투 창은 알림을 닫은 뒤.
func _after_load_save(relocated: bool, done_key: String, failed_key: String) -> void:
	if _autosave(true):
		_after_load(relocated, texts.t(done_key))
		return
	var why := texts.t(failed_key, {"reason": last_autosave_error})
	_alert(why + "\n" + texts.t("msg.relocated") if relocated else why)


func _new_state(in_town: bool = false) -> ExplorationState:
	var seed_value := seed_override if seed_override >= 0 else ExplorationRules.fresh_seed()
	return ExplorationRules.new_game(store.defs, seed_value, settings.automap, in_town)


## 상태를 통째로 바꾼다(새 게임·불러오기·가져오기). 미리 받은 입력을 비우고 시야·지도를 다시 맞춘다.
func _set_state(s: ExplorationState) -> void:
	state = s
	_epoch += 1
	_clear_foe = ""  # 앞 상태의 보스 승리는 이야기 상자를 열지 않는다
	if battle_layer.is_open():
		# 다른 상태로 바뀌었다: 앞 상태의 전투 층은 알리지 않고 닫는다(새 상태의 전투는 _check_windows 가 연다).
		battle_layer.close_layer(false)
		_set_battle_view(false)
	if party_menu.is_open():
		party_menu.close_menu(false)  # 앞 상태의 초안·화면은 버린다
	if shop_screen.is_open():
		shop_screen.close_shop(false)  # 앞 상태의 상점 화면·물음은 버린다
	if guild_screen.is_open():
		guild_screen.close_guild(false)  # 앞 상태의 길드 화면·물음·편성 초안은 버린다
	if quest_screen.is_open():
		quest_screen.close_quest(false)  # 앞 상태의 의뢰 화면·물음은 버린다(M3 A8b)
	_clear_input()
	_stairs_ask = false
	if _view_on and not state.in_town():
		_sync_view()
	map_window.set_state(state)
	minimap.set_state(state)
	_refresh_floor_text()
	_refresh_hud()
	_apply_location()


## 시야를 지금 상태(층·세계·자세)에 맞춘다. 층이 같으면 메시만 다시 만든다.
func _sync_view() -> void:
	if floor_def != state.floor_def or _view_floor_stale:
		floor_def = state.floor_def
		view.setup(floor_def, state.world)
	else:
		view.rebuild(state.world)
	_view_floor_stale = false
	view.set_pose(state.party.at, state.party.facing)
	view.sync_foes(state)


## 장소에 맞게 화면을 바꾼다(M3 A2): 마을이면 타이틀을 닫고 광장을 연다(지도 판은 닫는다). 미궁이면 마을 화면을 닫는다.
## 3D 시야·HUD·바탕은 _layout 이 장소대로 보이고 감춘다(마을·타이틀에서는 시야를 그리지 않는다).
func _apply_location() -> void:
	if state == null:
		return
	if title_screen.is_open():
		title_screen.close_title(false)
	if state.in_town():
		_map_open = false
		town_screen.open(state)
	elif town_screen.is_open():
		town_screen.close_town(false)
	_layout()


func _in_town() -> bool:
	return state != null and state.in_town()


func _title_open() -> bool:
	return title_screen != null and title_screen.is_open()


## 3D 시야를 켜고 끈다. 끄면 SubViewport 를 그리지 않고(UPDATE_DISABLED) 시야 노드의 처리(연출·카메라 보정)를 멈춘다.
## 켜면 원래 갱신 방식으로 되돌리고 지금 상태에 시야를 맞춘다.
func _set_view_active(on: bool) -> void:
	if on == _view_on:
		return
	_view_on = on
	view_container.visible = on
	_view_sv.render_target_update_mode = _view_sv_mode if on else SubViewport.UPDATE_DISABLED
	view.process_mode = PROCESS_MODE_INHERIT if on else PROCESS_MODE_DISABLED
	if on and state != null:
		_sync_view()
	elif not on:
		_view_floor_stale = true  # 꺼진 동안 층이 바뀔 수 있다(불러오기): 켤 때 메시를 다시 만든다


## 층이 바뀌었다(계단, M3 A1): 시야를 그 층으로 다시 만들고 지도 판(열려 있으면 그대로 열린 채)·미니맵·층 문패를 맞춘다.
func _show_floor() -> void:
	if _view_on:
		floor_def = state.floor_def
		view.setup(floor_def, state.world)
		view.set_pose(state.party.at, state.party.facing)
		view.sync_foes(state)
	map_window.set_state(state)
	minimap.set_state(state)
	_refresh_floor_text()


## 층 문패(장소 글)·지도 판 층 문패(층 표시).
func _refresh_floor_text() -> void:
	_floor_label.text = FloorNames.place(texts, state.defs, state.floor_def)
	map_window.set_floor_label(FloorNames.label(texts, state.defs, state.floor_def))


## 물건 이름(소재·장비·귀중품, M3 A3). 모르는 ID 는 그 ID 의 글.
func item_text(id: String) -> String:
	var key: Dictionary = store.defs.battle.key_items.get(id, {})
	return texts.t(key["name_key"]) if not key.is_empty() else PartyNames.item_name(state, texts, id)


## 상자 이벤트의 안내 글(M3 A3, 원작의 메시지 창 대신 알림 줄, 이름 붙은 차이): chest_opened·chest_full·chest_empty.
func chest_text(ev: Dictionary) -> String:
	match str(ev["type"]):
		"chest_empty":
			return texts.t("msg.chest_empty")
		"chest_full":
			if str(ev.get("item", "")).is_empty():
				return texts.t("msg.chest_full_money")
			return texts.t("msg.chest_full", {"item": item_text(str(ev["item"]))})
	if ev.has("money"):
		return texts.t("msg.chest_money", {"money": ShopRow.grouped(int(ev["money"]))})
	var n := int(ev.get("count", 1))
	var item := item_text(str(ev["item"]))
	return texts.t("msg.chest_item", {"item": item, "count": n}) if n > 1 else texts.t("msg.chest_one", {"item": item})


## 채집 이벤트의 안내 글(M3 A5, 상자처럼 원작의 메시지 창 대신 알림 한 줄, 이름 붙은 차이): gathered·gather_full·gather_spent.
## 얻은 것은 「이름 n개」를 「 · 」로 잇는다(늘 「n개」라 조사는 「를」). 가방에 못 넣은 것이 있으면 남은 횟수 대신 그 수를 쓴다.
func gather_text(ev: Dictionary) -> String:
	match str(ev["type"]):
		"gather_full":
			return texts.t("msg.gather_full")
		"gather_spent":
			return texts.t("msg.gather_spent")
	var parts: Array[String] = []
	for x in ev["items"]:
		parts.append(texts.t("gather.item", {"item": item_text(str(x["item"])), "count": int(x["count"])}))
	var items := " · ".join(parts)
	if int(ev["lost"]) > 0:
		return texts.t("msg.gathered_lost", {"items": items, "lost": int(ev["lost"])})
	return texts.t("msg.gathered", {"items": items, "left": int(ev["left"]), "uses": int(ev["uses"])})


# ---- 행동 ----

## 화면 단추·키보드·미리 받은 입력·누르고 있기 반복이 모두 이리로 온다(05 §9.3).
## 막혀 있으면 버리고(미리 받지도 않는다). 연출 중이거나 이미 미리 받은 행동이 있으면 미리 받는 칸(하나)에 넣는다:
## 나중 입력이 미리 받은 것을 바꾸고, 행동은 늘 칸에서 꺼낸 순서로만 한다(새 요청이 칸을 앞지르지 않는다).
## 남은 계단 물음이 먼저다: 연출이 끝났는데 물음이 남아 있으면(막은 창이 닫힌 뒤 미뤄 둔 _retry_stairs 전 틈 포함)
## 이 요청 대신 계단 창을 띄우고 요청은 버린다. 물음이 낡았으면(계단 밖·전투 대기·전멸) 물음만 버리고 요청을 잇는다.
func request_action(action: int) -> void:
	if _input_blocked():
		return
	if _stairs_ask and not view.is_busy():
		_try_stairs()
		if _stairs_ask or modal.is_open():
			return
	if view.is_busy() or _queued >= 0:
		_queued = action
		return
	_do_action(action)


## 단추 누르기마다 승인을 새로 받는다. 막힌 동안의 누르기는 승인을 만들지도, 앞 누르기의 승인을 남기지도 않는다.
func _on_pad(action: int) -> void:
	if _input_blocked():
		_pad_since.erase(action)
		return
	_pad_since[action] = Time.get_ticks_msec()
	request_action(action)


## 행동을 받지 않는 조건: 상태 없음, 창(메뉴·전멸·메모·파일 고르기 등)·전투 층·파티 메뉴가 열림, 전투 중·전멸,
## 지도에서 진행 중인 상호작용(그리기 획·끌어 이동·핀치·아이콘·메모 누르기).
## 마을·타이틀에서도 받지 않는다(M3 A2: 마을의 입력은 마을 화면이 받고, 미궁에 들어가는 ENTER 는 _enter_labyrinth 가 따로 부른다).
func _input_blocked() -> bool:
	return state == null or state.in_town() or _title_open() or modal.is_open() or battle_layer.is_open() or party_menu.is_open() \
		or shop_screen.is_open() or guild_screen.is_open() or quest_screen.is_open() or not ExplorationRules.can_act(state) or map.is_interacting()


## 마을 화면 「탐사 시작」(M3 A2): 마을에 있고 다른 창이 없을 때 규칙 행동 ENTER.
func _enter_labyrinth() -> void:
	if not _town_free():
		return
	_do_action(A.ENTER)


## 마을에서 창(알림·캠프·상점·타이틀)이 없는지.
func _town_free() -> bool:
	return _in_town() and not _title_open() and not modal.is_open() and not party_menu.is_open() and not shop_screen.is_open() \
		and not guild_screen.is_open() and not quest_screen.is_open() \
		and not battle_layer.is_open()


func _do_action(action: int) -> void:
	if (not _town_free()) if action == A.ENTER else _input_blocked():
		return
	# 한 프레임에 행동 하나: 같은 프레임의 두 번째 행동은 미리 받는 칸에 넣어 다음 프레임 이후에 한다.
	if Engine.get_process_frames() == _action_frame:
		_queued = action
		return
	var move_dir := -1
	match action:
		A.FORWARD:
			move_dir = state.party.facing
		A.BACK:
			move_dir = Dir.opposite(state.party.facing)
		A.STRAFE_LEFT:
			move_dir = Dir.left(state.party.facing)
		A.STRAFE_RIGHT:
			move_dir = Dir.right(state.party.facing)
	var events := ExplorationRules.apply(state, action, settings.automap)
	if events.size() == 1 and events[0]["type"] == "rejected":
		return
	# 의뢰 진행(M3 A8 설계 §4.3): 행동 이벤트와 그 뒤 상태를 읽어 받은 의뢰를 센다. 아래 자동 저장에 함께 실린다.
	quest_events = QuestRules.observe(state, events)
	_action_frame = Engine.get_process_frames()
	_stairs_ask = false  # 새 행동이 받아들여졌으면 앞의 물음은 낡았다(이 행동의 이벤트가 다시 세운다)
	var rebuild := false
	var slid := false
	var changed := false
	var located := false
	for ev in events:
		match ev["type"]:
			"stairs", "chest", "gather", "boss":
				_stairs_ask = true  # 보스(M3 A9b): 부딪힘·조사 뒤에만 묻는다(남은 물음 규칙은 계단·상자와 같다)
			"floor_changed":
				changed = true
			"to_town", "entered":
				located = true
			"blocked":
				_show_toast(texts.t("msg." + str(ev["reason"])))
			"shortcut_opened", "passage_found":
				rebuild = true
				_show_toast(texts.t("msg." + str(ev["type"])))
			"lock_opened":
				rebuild = true
				_show_toast(texts.t("msg.lock_opened", {"key": item_text(str(ev["key"]))}))
			"seal_opened":
				rebuild = true  # 봉인 문(M3 A9): 빨간 봉인 → 문
				_show_toast(texts.t("msg.seal_opened"))
			"chest_opened":
				rebuild = true  # 상자 겉모습(닫힘 → 열림)
				_show_toast(chest_text(ev))
			"chest_full", "chest_empty":
				_show_toast(chest_text(ev))
			"gathered":
				if int(ev["left"]) <= 0:
					rebuild = true  # 지점 겉모습(남음 → 다 씀)
				_show_toast(gather_text(ev))
			"gather_full", "gather_spent":
				_show_toast(gather_text(ev))
			"nothing_found":
				_show_toast(texts.t("msg.nothing_found"))
			"damaged":
				_show_toast(texts.t("msg.damaged"))
				_flash_damage()
			"foe_alert":
				# M3 A6c(설계 §5.3): 추적 FOE 가 파티를 알아챘다. 알림 줄 한 줄(뒤 안내가 바꾼다, 쌓지 않는다).
				_show_toast(texts.t("msg.foe_alert", {"name": FoeLook.name_of(state, texts, str(ev["foe"]))}))
			"moved":
				if ev["via"] == "slide":
					slid = true
	if slid:
		_show_toast(texts.t("msg.slide"))
	if changed:
		_show_toast(FloorNames.place(texts, state.defs, state.floor_def))
	if located:
		_show_toast(texts.t("town.name") if state.in_town() else FloorNames.place(texts, state.defs, state.floor_def))
	# 의뢰 안내(M3 A8b 설계 §6.5)는 이 묶음의 다른 안내 뒤: 안내는 바뀌어 들어가므로 마지막이 남는다(탐사 허가 계단에서도 임무 안내가 이긴다).
	var note := quest_note(quest_events)
	if not note.is_empty():
		_show_toast(note)
	# 저장 실패 안내가 위 행동 안내에 덮이지 않게 안내 뒤에 저장한다.
	_autosave()
	if located:
		_apply_location()  # 마을: 광장을 열고 시야를 끈다. 미궁: 마을 화면을 닫고 시야를 켜 시작 칸에 맞춘다
		if state.in_town():
			_refresh_hud()
			_debug_dirty = true
			return  # 마을에는 연출이 없다(시야는 멈춰 있다)
	if changed:
		_show_floor()
	elif rebuild:
		view.rebuild(state.world)
	view.play(events, move_dir)
	map.refresh()
	_refresh_hud()


## 연출이 끝났다: 전멸·전투 창, 미리 받은 입력, 누르고 있는 단추·키 순서로 다음을 정한다.
func _on_animation_finished() -> void:
	_debug_dirty = true
	if state == null or view.is_busy():
		return
	if _check_windows():
		_stairs_ask = false
		return
	if _stairs_ask:
		# 물음이 남아 있으면 미리 받은 입력·누르고 있기 반복으로 넘어가지 않는다(물음을 건너뛰지 않는다).
		# 띄우면 창이 지도 손짓·입력을 취소하고, 못 띄우면 막은 창이 닫힐 때 _retry_stairs 가 다시 본다.
		_try_stairs()
		return
	if _queued >= 0:
		var a := _queued
		_queued = -1
		request_action(a)
		return
	_try_repeat()


## 누르고 있는 단추·승인된 키가 있으면 반복한다. 누른 지 HOLD_REPEAT_MS 전이거나 이번 프레임에 이미 행동했으면 기다린다.
func _try_repeat() -> void:
	_repeat_wait = false
	var held := _held_action()
	if held.is_empty():
		return
	if Time.get_ticks_msec() - int(held[1]) >= HOLD_REPEAT_MS and Engine.get_process_frames() != _action_frame:
		request_action(held[0])
	else:
		_repeat_wait = true


## 반복할 [행동, 누른 시각]. 없으면 빈 배열. 키는 승인된 것만 본다(창 안에서 누른 키는 반복하지 않는다).
func _held_action() -> Array:
	if _input_blocked():
		return []
	for a in REPEATABLE:
		var b: TouchButton = pad.get(a)
		if b != null and b.held and _pad_since.has(a):
			return [a, _pad_since[a]]
	for name in KEY_ACTIONS:
		if REPEATABLE.has(KEY_ACTIONS[name]) and _key_since.has(name) and Input.is_action_pressed(name):
			return [KEY_ACTIONS[name], _key_since[name]]
	return []


## 전멸이면 전멸 창, 전투 중이면 전투 층을 띄운다(이미 떠 있으면 그대로). 띄웠으면 true.
## 전투 중에 다른 창(알림·파티 메뉴)이 떠 있으면 그 창이 닫힌 뒤 전투 층을 연다(_close_alert·_on_party_closed 가 다시 부른다).
## 전멸 창은 파티 메뉴를 닫고 띄운다(전멸이면 성장 조작을 받지 않는다).
func _check_windows() -> bool:
	if state == null:
		return false
	if state.wiped:
		if party_menu.is_open():
			party_menu.close_menu(false)
		if shop_screen.is_open():
			shop_screen.close_shop(false)
		if guild_screen.is_open():
			guild_screen.close_guild(false)
		if quest_screen.is_open():
			quest_screen.close_quest(false)
		if modal.kind != "wipe":
			_open_wipe()
		return true
	if state.encounter.pending:
		if not battle_layer.is_open() and not modal.is_open() and not party_menu.is_open() and not shop_screen.is_open() \
				and not guild_screen.is_open() and not quest_screen.is_open():
			_open_battle()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var k := event as InputEventKey
	if not k.pressed:
		for name in KEY_ACTIONS:
			if event.is_action_released(name):
				_key_since.erase(name)
		return
	if k.echo:
		get_viewport().set_input_as_handled()
		return
	if battle_layer == null or battle_layer.is_open():
		return  # 전투 층이 키를 받는다(메뉴도 열지 않는다, 06 §8.7)
	if party_menu.is_open():
		# 캠프가 키를 받는다(07 §9.4: 아래 Esc·Ctrl+Z·M·R·이동 키 갈래는 _input_blocked 를 보지 않는다).
		# 캠프 위에 창(알림·파일 고르기)이 떠 있으면 캠프는 키를 받지 않는다(그 창이 받는다).
		return
	if shop_screen.is_open() or guild_screen.is_open() or quest_screen.is_open():
		return  # 상점·길드·의뢰 화면이 키를 받는다(08 §8: 열린 동안 캠프·지도·이동은 열리거나 움직이지 않는다)
	if _title_open() or _in_town():
		return  # 타이틀·마을 화면이 키를 받는다(마을에서는 이동·지도·Esc 캠프가 없다, P 는 마을 화면이 캠프로)
	if modal.kind in ["stairs", "chest", "gather", "boss"]:
		# 계단 확인·상자 물음(M3 A3)·채집 물음(M3 A5)·보스 물음(M3 A9b): Esc·Backspace = 「아니오」. Enter·Space·방향 키는 창 안의 포커스 단추가 받는다(05 §9.3).
		if event.is_action_pressed("open_menu") or k.keycode == KEY_BACKSPACE or k.physical_keycode == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			if modal.kind == "chest":
				_answer_chest(false)
			elif modal.kind == "gather":
				_answer_gather(false)
			elif modal.kind == "boss":
				_answer_boss(false)
			else:
				_answer_stairs(false)
		return
	if event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		if not modal.is_open():
			_open_party()  # Esc 도 캠프를 연다(M2.7 R2, 원작 CAMP)
		return
	if modal.is_open():
		return
	if event.is_action_pressed("open_party"):
		get_viewport().set_input_as_handled()
		_open_party()
		return
	if event.is_action_pressed("map_undo"):
		get_viewport().set_input_as_handled()
		map.undo()
		return
	if event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_toggle_map()
		return
	for name in KEY_ACTIONS:
		if event.is_action_pressed(name):
			get_viewport().set_input_as_handled()
			if _input_blocked():
				return  # 막힌 동안 누른 키는 승인하지 않는다(뗐다가 다시 눌러야 한다)
			_key_since[name] = Time.get_ticks_msec()
			request_action(KEY_ACTIONS[name])
			return


## 화면이 사라질 때 웹 전역 콜백(window.sqfImportResult·sqfDebug)을 걷는다.
func _exit_tree() -> void:
	if bridge != null:
		bridge.dispose()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_clear_input()


## 미리 받은 입력과 눌림·그리기 상태를 버린다.
func _clear_input() -> void:
	_queued = -1
	_repeat_wait = false
	_key_since.clear()
	_pad_since.clear()
	for a in pad:
		(pad[a] as TouchButton).cancel()
	if map_window != null:
		map_window.cancel_all()
	if map != null:
		map.cancel_input()
	if map_button != null:
		map_button.cancel()
		camp_button.cancel()


# ---- 저장 ----

## 자동 저장. 성공하면 true. 실패하면 quiet 가 아닐 때 실패 안내를 띄운다(호출자는 이 뒤에 다른 안내를 덮지 않는다).
## 지도 획이 열려 있으면(지도 표시에 확정하지 않은 획이 들어 있다) 저장하지 않고 획이 닫힌 뒤로 미룬다.
func _autosave(quiet: bool = false) -> bool:
	if map != null and map.is_stroking():
		_autosave_pending = true
		return true
	_autosave_pending = false
	var why := store.save(SaveStore.AUTO, state)
	_note_save(SaveStore.AUTO, why.is_empty())
	_debug_dirty = true
	if why.is_empty():
		autosave_count += 1
		last_autosave_error = ""
		_warn_end()  # 다시 저장했다: 저장하지 못했다는 안내는 더 맞지 않는다(그다음 안내가 바로 보인다)
		return true
	last_autosave_error = why
	if not quiet:
		_warn(texts.t("msg.save_failed", {"reason": why}))
	return false


func _load_slot(slot: String) -> void:
	var l := store.load_slot(slot)
	if not l.ok():
		_alert(texts.t("msg.load_failed", {"reason": l.result.error}))
		return
	modal.close()
	_set_state(l.result.state)
	_after_load_save(l.result.relocated, "msg.loaded", "msg.loaded_save_failed")


func _save_slot(slot: String) -> void:
	var why := store.save(slot, state)
	_note_save(slot, why.is_empty())
	if why.is_empty():
		_show_toast(texts.t("msg.saved"))
	else:
		_alert(texts.t("msg.save_failed", {"reason": why}))
		return
	party_menu.refresh_view()
	town_screen.refresh_view()


## 숙소 숙박(M3 A2b): 규칙(TownRules.stay)이 받아들였으면 자동 저장한다(05 §8.4). 이벤트 열을 숙소 화면에 돌려준다(안내는 그쪽).
## 받아들인 숙박은 stayed 앞에 FOE 되살아남(foe_respawned, M3 A6)이 붙을 수 있다.
func _inn_stay() -> Array[Dictionary]:
	if state == null:
		return []
	var events := TownRules.stay(state)
	if events.any(func(e: Dictionary) -> bool: return e["type"] == "stayed"):
		_autosave()
		_debug_dirty = true
	return events


## 의뢰 받기·포기·보고 입구(M3 A8 설계 §4.4·§4.6): A8b 의 정보상 바·관리국 화면과 시험·디버그 요청이 부른다. kind = accept·abandon·report.
## 창(물음 포함)이 열렸거나 연출 중이면 busy 로 거부하고, 규칙(QuestRules)이 받아들이면 자동 저장을 한 번 한다(보고의 모든 보수가 이 저장 하나에 실린다).
func quest_action(kind: String, id: String, giver: String) -> Array[Dictionary]:
	if state == null or modal.is_open() or _is_busy():
		return [{"type": "rejected", "reason": "busy"}]
	var events: Array[Dictionary]
	match kind:
		"accept":
			events = QuestRules.accept(state, id, giver)
		"abandon":
			events = QuestRules.abandon(state, id, giver)
		"report":
			events = QuestRules.report(state, id, giver)
		_:
			return [{"type": "rejected", "reason": "bad_kind"}]
	if events[0]["type"] != "rejected":
		_autosave()
		_debug_dirty = true
	return events


## 대열 바꾸기 입구(M3 A7 설계 §4.1b): 캠프 「대열」 판(A7c)과 시험이 부른다. 창(물음 포함)이 열렸거나 연출 중이면 busy 로 거부하고,
## 규칙(GuildRules.arrange)이 받아들이면 자동 저장한다. 시간은 가지 않는다(걸음·위험도·FOE 그대로).
func arrange_party(front: Array, back: Array) -> Array[Dictionary]:
	if state == null or modal.is_open() or _is_busy():
		return [{"type": "rejected", "reason": "busy"}]
	var events := GuildRules.arrange(state, front, back)
	if events[0]["type"] == "arranged":
		_autosave()
		_debug_dirty = true
	return events


## 저장 반영 기다림을 켠다: 진짜 웹이고 user:// 가 IndexedDB 에 이어져 있을 때만(시험은 save_reader·userfs_persistent).
func _setup_save_pending() -> void:
	var persistent := OS.is_userfs_persistent() if userfs_persistent < 0 else userfs_persistent == 1
	if save_reader.is_valid():
		save_pending.reader = save_reader
		save_pending.enabled = persistent
	else:
		save_pending.reader = bridge.read_idb_files
		save_pending.enabled = persistent and bridge.can_read_idb()
	save_pending.changed.connect(_refresh_save_chip)
	# 메모리에 이미 있는 슬롯도 올린다: 화면을 다시 만들었으면 앞 화면의 저장이 아직 IndexedDB 에 없을 수 있다.
	# 보통의 페이지 열기라면 그 파일은 IndexedDB 에서 온 것이라 첫 읽기에서 내린다(시작할 때 잠깐 보일 수 있다).
	if save_pending.enabled:
		for slot in [SaveStore.AUTO] + SaveStore.MANUAL_SLOTS:
			var files := _slot_files(slot)
			if files.values().any(func(t: Variant) -> bool: return t != null):
				save_pending.note(slot, _file_generation(files[ProjectSettings.globalize_path(store.main_path(slot))]), files)


## 상태 요약에 낼 본 파일의 generation(검사 전 바이트). 없거나 읽을 수 없거나 정수가 아니면 -1(깨진 파일도 묶음은 올린다).
static func _file_generation(bytes: Variant) -> int:
	if typeof(bytes) != TYPE_PACKED_BYTE_ARRAY:
		return -1
	var json := JSON.new()
	if json.parse((bytes as PackedByteArray).get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return -1
	var g: Variant = SaveCodec.to_int((json.data as Dictionary).get("generation"))
	return g if g != null else -1


## 저장을 시도한 뒤(성공·실패 모두) 부른다: 그 슬롯의 메모리 파일 묶음(본 파일·.tmp·.bak)을 반영 대기에 올린다.
## 쓰기와 같은 프레임이라 쓴 바이트 그대로다. generation 은 이번 저장이 쓴(실패면 쓰려던) 값.
func _note_save(slot: String, ok: bool) -> void:
	if save_pending.enabled:
		save_pending.note(slot, state.generation if ok else state.generation + 1, _slot_files(slot))


## 슬롯의 후보 파일(본 파일·.tmp·.bak): IndexedDB 열쇠(전역 경로) → 바이트(없으면 null).
func _slot_files(slot: String) -> Dictionary:
	var out := {}
	for path in store.candidate_paths(slot):
		out[ProjectSettings.globalize_path(path)] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return out


func _refresh_save_chip() -> void:
	var on := save_pending.is_pending()
	if on and not save_chip.visible:
		save_chip.modulate.a = 0.0
	save_chip.visible = on
	_debug_dirty = true


## 새 게임(타이틀·캠프 기록·전멸): 늘 마을에서 시작한다(M3 A2 고름 3).
func _start_new_game() -> void:
	modal.close()
	_set_state(_new_state(true))
	_autosave()


# ---- 내보내기·가져오기 (05 §8.5) ----

func _export() -> void:
	var text := SaveCodec.encode(state)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var file_name := "sqfangame-%s.json" % stamp
	if bridge.is_web():
		# 단추를 누른 처리 안에서 바로 내려받게 한다(await 없음).
		bridge.download(text.to_utf8_buffer(), file_name, "application/json")
		_show_toast(texts.t("msg.exported"))
		return
	_open_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, file_name, func(path: String) -> void:
		var why := write_export(path, text)
		if why.is_empty():
			_show_toast(texts.t("msg.exported"))
		else:
			_alert(texts.t("msg.save_failed", {"reason": why})))


## 내보낸 글을 파일에 쓴다. 쓰기 뒤 오류를 확인한다(SaveStore._write_file 과 같은 판정). 성공하면 "".
func write_export(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return error_string(FileAccess.get_open_error())
	f.store_string(text)
	f.flush()
	var err := ERR_FILE_CANT_WRITE if file_fail_points.has("export_write") else f.get_error()
	f.close()
	if err != OK:
		return error_string(err)
	return ""


## 가져올 파일을 읽는다. 읽기 뒤 오류를 확인한다(SaveStore._check_file 과 같은 판정: EOF 는 정상).
## 결과 {"text": 글, "error": ""·"too_large"·"read"}.
func read_import(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"text": "", "error": "read"}
	if f.get_length() > WebBridge.IMPORT_LIMIT:
		f.close()
		return {"text": "", "error": "too_large"}
	var text := f.get_as_text()
	var err := ERR_FILE_CANT_READ if file_fail_points.has("import_read") else f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		return {"text": "", "error": "read"}
	return {"text": text, "error": ""}


func _import() -> void:
	if bridge.is_web():
		_import_token += 1
		_import_epoch = _epoch
		bridge.start_import(_import_token)
		return
	_open_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "", func(path: String) -> void:
		var r := read_import(path)
		if r["error"] == "too_large":
			_alert(texts.t("msg.import_too_large"))
		elif r["error"] == "read":
			_alert(texts.t("msg.import_error"))
		else:
			import_text(r["text"]))


## 웹 가져오기 결과. 그사이 다른 가져오기·불러오기·새 게임이 있었으면(늦게 온 결과) 버린다.
func _on_import_result(token: int, result: String, text: String) -> void:
	if token != _import_token or _import_epoch != _epoch:
		return
	_import_epoch = -1
	match result:
		"ok":
			import_text(text)
		"too_large":
			_alert(texts.t("msg.import_too_large"))
		"error":
			_alert(texts.t("msg.import_error"))
		_:
			pass


## 가져온 글을 검사하고, 통과하면 지금 상태와 바꾼다. 실패하면 지금 상태를 건드리지 않는다.
func import_text(text: String) -> bool:
	if text.to_utf8_buffer().size() > WebBridge.IMPORT_LIMIT:
		_alert(texts.t("msg.import_too_large"))
		return false
	var r := SaveCodec.decode(text, store.defs)
	if not r.ok():
		_alert(texts.t("msg.load_failed", {"reason": r.error}))
		return false
	modal.close()
	_set_state(r.state)
	_after_load_save(r.relocated, "msg.imported", "msg.imported_save_failed")
	return true


## 네이티브 파일 고르기 창. 요청마다 번호와 시작 epoch 를 잡고, 고르기·취소 콜백은 둘 다 맞을 때만 일한다.
## 낡은 요청(다른 창이 새로 열렸거나 그사이 상태가 바뀜)의 콜백은 아무것도 바꾸지 않고 지금 창도 닫지 않는다.
func _open_file_dialog(mode: int, file_name: String, on_path: Callable) -> void:
	if _file_dialog != null:
		_file_dialog.hide()  # 숨기지 않으면 새 창을 띄울 수 없다(배타 창은 하나)
		_file_dialog.queue_free()
		_file_dialog = null
	_file_req += 1
	var req := _file_req
	var ep := _epoch
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = mode
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.json"])
	_file_dialog.current_file = file_name
	_file_dialog.use_native_dialog = true
	add_child(_file_dialog)
	modal.open("file", texts.t("menu.choosing_file"), [])
	_file_dialog.file_selected.connect(func(path: String) -> void:
		if not _file_request_current(req, ep):
			return
		_finish_file_request()
		on_path.call(path))
	_file_dialog.canceled.connect(func() -> void:
		if not _file_request_current(req, ep):
			return
		_finish_file_request())
	_file_dialog.popup_centered_ratio(0.7)


func _file_request_current(req: int, ep: int) -> bool:
	return req == _file_req and ep == _epoch and modal.kind == "file"


## 지금 요청을 끝낸다: 번호를 올려 같은 요청의 콜백을 다시 받지 않고, 파일 창을 숨겨 치우고 기다림 창을 닫는다.
func _finish_file_request() -> void:
	_file_req += 1
	if _file_dialog != null:
		_file_dialog.hide()
		_file_dialog.queue_free()
		_file_dialog = null
	modal.close()


# ---- 창 ----

func _open_battle() -> void:
	_battle_quest_note = ""  # 앞 전투의 의뢰 안내는 남기지 않는다
	battle_layer.anim_speed = anim_speed
	battle_layer.debug = _debug
	_set_battle_view(true)
	battle_layer.open(state)


## 전투 층이 닫혔다(승리·도주 결과 창을 닫음, 또는 전멸). 탐색 화면을 되돌리고 전멸이면 전멸 창.
func _on_battle_closed(outcome: String) -> void:
	_set_battle_view(false)
	_clear_input()
	var note := _battle_quest_note
	_battle_quest_note = ""
	if not note.is_empty() and not state.wiped:
		_show_toast(note)  # 전투가 센 의뢰 안내(M3 A8b 설계 §6.5): 전투 층이 닫힌 뒤에, 전멸이면 띄우지 않는다
	if _view_on and not state.in_town():
		view.sync_foes(state)  # 쓰러진 FOE 표지를 지우고 위협 색(레벨)을 다시 본다(M3 A6c)
	map.refresh()
	_refresh_hud()
	_debug_dirty = true
	# 클리어 이야기 상자는 다른 창보다 먼저(의뢰 안내 뒤, 설계 §4.5). 승리로 닫혔을 때만, 보이기만 한다(저장 없음, O6).
	var cleared := _clear_foe
	_clear_foe = ""
	if not cleared.is_empty() and outcome == "victory" and not state.wiped:
		_open_clear(cleared)
	_check_windows()


## 클리어 이야기 상자(M3 A9b 설계 §5.3, kind "clear"): 말하는 사람 「관리국 통신」, 쪽 셋(첫 쪽에 보스 이름). 층 주제마다 글 키 clear.<theme>.*.
func _open_clear(foe: String) -> void:
	var prefix := "clear." + state.floor_def.theme
	var boss_name := FoeLook.name_of(state, texts, foe)
	var list: Array[String] = [texts.t(prefix + ".1", {"name": boss_name}), texts.t(prefix + ".2"), texts.t(prefix + ".3")]
	story_box.start(texts.t(prefix + ".speaker"), list)
	modal.open_part("clear", story_box)
	_layout()


## 이야기 상자의 마지막 쪽을 넘겼다: 닫기만 한다(상태 그대로).
func _on_story_finished() -> void:
	if modal.kind == "clear":
		modal.close()


## 전투 층이 열린 동안 HUD·지도 판을 감춘다(3D 시야는 언제나 화면 전체, 06 §9.1, M2.6 U1).
func _set_battle_view(on: bool) -> void:
	if on and not _battle_view:
		_hide_toast()  # 전투가 열리면 보이던 일반 안내(전투를 연 행동의 결과)는 지운다: 화면 이동이다(A3b 재확인 3, R5)
	_battle_view = on
	# FOE 3D 표지는 전투 동안 감춘다(M3 A6c seq=7): 카드 뒤에 멈춘 공이 합류를 잘못 읽게 한다. 닫힐 때 _on_battle_closed 가 다시 맞춘다.
	view.foes_root.visible = not on
	_layout()


## 탐색 HUD(층 문패·미니맵·위험 보석·이동 단추·안내 줄)와 지도 판을 감추는지(3D 시야만 남는다).
## 전투 층이 열린 동안(06 §9.1, U1)과 파티 메뉴가 열린 동안(M2.6 2.5단계: 메뉴 뒤에는 어둡게 한 3D 시야만 보인다).
## 감춘 단추는 누르기를 받지 않는다. 파티 메뉴가 열리고 닫힐 때(어느 길로 닫혀도: 키·「닫기」·상태 바꾸기) visibility_changed 로 다시 맞춘다.
func _hud_hidden() -> bool:
	return _battle_view or (party_menu != null and party_menu.is_open()) or (shop_screen != null and shop_screen.is_open()) \
		or (guild_screen != null and guild_screen.is_open()) or (quest_screen != null and quest_screen.is_open()) \
		or _in_town() or _title_open() or (modal != null and modal.kind == "clear")  # 클리어 이야기 상자(M3 A9b): 원작처럼 시야만


## 전투 층 저장 갈고리(제출 결과가 정해진 직후, 연출 전).
func _on_battle_save() -> void:
	_autosave()


## 전투 층 제출 갈고리(M3 A8): 저장 갈고리보다 먼저, 전투 끝(kills·foes_defeated)으로 받은 의뢰를 센다(설계 §4.3).
func _on_battle_commit(events: Array[Dictionary]) -> void:
	quest_events = QuestRules.observe(state, events)
	# 클리어(M3 A9b 설계 §4.5): 승리한 battle_end 의 foes_defeated 에 보스 종류 FOE 가 있으면 전투 층이 닫힐 때 이야기 상자를 연다.
	for ev in events:
		if ev["type"] == "battle_end" and ev["outcome"] == "victory":
			for id in ev.get("foes_defeated", []):
				var sp: FloorModel.FoeSpawn = state.floor_def.foes.get(str(id))
				if sp != null and sp.kind == "boss":
					_clear_foe = str(id)
	var note := quest_note(quest_events)
	if not note.is_empty():
		_battle_quest_note = note  # 전투 동안은 띄우지 않는다(전투 층이 안내를 지운다): 닫힐 때 _on_battle_closed 가 띄운다


## 의뢰 이벤트 열의 안내 글(05 §16.9 표, M3 A8b): 달성이 진행보다 앞서고, 같은 종류는 마지막 것. 없으면 "".
func quest_note(events: Array[Dictionary]) -> String:
	var pick: Dictionary = {}
	for ev in events:
		if ev["type"] == "quest_done" or (ev["type"] == "quest_progress" and (pick.is_empty() or pick["type"] != "quest_done")):
			pick = ev
	if pick.is_empty():
		return ""
	var q := state.defs.quests.get_def(str(pick["quest"]))
	if q == null:
		return ""
	var title := texts.t(q.name_key)
	if pick["type"] == "quest_done":
		return texts.t("quest.note.done." + q.giver, {"quest": title})
	return texts.t("quest.note.progress", {"quest": title, "n": pick["progress"], "target": pick["target"]})


## 캠프를 연다(07 §9.1): 전투·전멸이 아니고, 다른 창(메뉴·메모·파일 고르기·전멸·전투)이 없고, 연출 중이 아닐 때만.
## 열 때마다 캠프 뿌리(명령 커서 0, 대원 칸 0)에서 시작한다. 임시 보급은 디버그 주소이거나 네이티브 디버그 실행일 때만 보인다(07 §5.7).
func _open_party() -> void:
	if state == null or party_menu.is_open() or shop_screen.is_open() or battle_layer.is_open() or modal.is_open() or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	party_menu.debug = debug_tools()
	party_menu.open(state)
	if party_menu.is_open():
		town_screen.set_covered(true)  # 캠프의 그림 창에는 마을 바탕만 보인다(research 07 §2.2)
		guild_screen.set_covered(true)  # 길드 뿌리에서 연 캠프(M3 A7c): 길드도 덮는다(닫히면 길드로 돌아온다)
		quest_screen.set_covered(true)  # 정보상 바·관리국 뿌리에서 연 캠프(M3 A8b)도 같다


## 파티 메뉴가 닫혔다: 눌림·미리 받은 입력을 버리고(닫은 뒤 누르고 있던 이동 키가 걸음이 되지 않는다) 탐색 화면을 다시 맞춘다.
func _on_party_closed() -> void:
	if guild_screen.is_open():
		guild_screen.set_covered(false)  # 길드에서 연 캠프: 길드로(마을 화면은 길드가 덮은 채)
	elif quest_screen.is_open():
		quest_screen.set_covered(false)  # 의뢰 화면에서 연 캠프(M3 A8b): 그 화면으로
	elif not shop_screen.is_open():
		town_screen.set_covered(false)
	_clear_input()
	_refresh_hud()
	_debug_dirty = true
	_debug_settle = 2
	_check_windows()
	_retry_stairs.call_deferred()


## 파티 메뉴가 규칙 결과를 받아들였다(저장 갈고리 뒤). 귀환 비콘(M3 A4b §5.3·§6.3)이면 관문 도착(_step 의 located)과 같은 차례:
## 캠프를 닫고(눌림·남은 물음을 버린다, _on_party_closed) 장소 안내 「뿌리마을」 → 층 문패·지도를 첫 층으로 → 광장을 연다.
## 광장이 열리며 그 안내는 지워진다(_settle_toast "window"): 광장 장소 문패 「뿌리마을 광장」이 이미 있어 관문 도착도 같은 안내를 내지 않는다.
## 자동 저장은 이미 한 번 했다(save_hook). 실패했으면 그 안내는 _warn_sync 가 05 §16.9 차례로 마을 안내 줄에 옮긴다.
func _on_party_changed(events: Array) -> void:
	_debug_dirty = true
	if not events.any(func(e: Dictionary) -> bool: return e["type"] == "returned"):
		return
	_stairs_ask = false
	party_menu.close_menu()
	_show_toast(texts.t("town.name"))
	_show_floor()
	_apply_location()
	_refresh_hud()


## 파티 메뉴 저장 갈고리(배분 확정·장착 변경·임시 보급·소모품 쓰기·버리기가 받아들여진 직후).
func _on_party_save() -> void:
	_autosave()


## 디버그 도구(캠프 임시 보급)를 보이는지: 디버그 주소이거나 네이티브 디버그 실행(07 §5.7).
func debug_tools() -> bool:
	return _debug or (native_debug and not bridge.is_web())


## 상점을 연다(08 §8.1, M3 A2 S4): 마을 광장 「정크 공방」에서만, 캠프와 같은 조건(전투·전투 대기·전멸이 아니고, 다른 창이 없고,
## 연출 중이 아님). 열 때마다 뿌리·명령 커서 0·대원 0에서 시작한다. 열린 동안 마을 화면을 감추고 바탕은 상점 그림이다.
func _open_shop() -> void:
	if not _in_town() or shop_screen.is_open() or guild_screen.is_open() or quest_screen.is_open() or party_menu.is_open() or battle_layer.is_open() \
			or modal.is_open() or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	shop_screen.open(state)
	if shop_screen.is_open():
		town_screen.set_covered(true)
		town_backdrop.show_place("shop")


## 모험가 길드를 연다(M3 A7c, 설계 §5): 광장 「모험가 길드」에서만, 상점과 같은 조건. 열린 동안 마을 화면을 덮고 바탕은 길드 그림이다.
## 닫히면 상점처럼 _on_party_closed 로 마을 화면을 걷는다(커서는 그대로 「모험가 길드」).
func _open_guild() -> void:
	if not _in_town() or guild_screen.is_open() or quest_screen.is_open() or shop_screen.is_open() or party_menu.is_open() or battle_layer.is_open() \
			or modal.is_open() or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	guild_screen.open(state)
	if guild_screen.is_open():
		town_screen.set_covered(true)
		town_backdrop.show_place("guild")


## 정보상 바·관리국을 연다(M3 A8b, 설계 §6.1): 광장 줄에서만, 길드와 같은 조건. 열린 동안 마을 화면을 덮고 바탕은 그 시설 그림이다.
## 닫히면 길드처럼 _on_party_closed 로 마을 화면을 걷는다(커서는 그대로 그 시설 줄).
func _open_quest(giver: String) -> void:
	if not _in_town() or quest_screen.is_open() or guild_screen.is_open() or shop_screen.is_open() or party_menu.is_open() or battle_layer.is_open() \
			or modal.is_open() or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	quest_screen.open(state, giver)
	if quest_screen.is_open():
		town_screen.set_covered(true)
		town_backdrop.show_place(giver)


## 길드 이름 입력(설계 §4.2·§5.4): 웹은 브라우저 입력 창(메모와 같은 길, 너무 빨리 돌아오면 막힌 것으로 본다), PC 는 LineEdit 창
## (NameEdit, 8자까지, NameOk·NameCancel). 결과(취소 = null)를 길드 화면에 돌려준다.
func _on_guild_name(default_name: String) -> void:
	if bridge.is_web():
		var t0 := Time.get_ticks_msec()
		var v: Variant = bridge.prompt(texts.t("guild.name_prompt"), default_name)
		var quick := Time.get_ticks_msec() - t0 < PROMPT_BLOCKED_MS
		_clear_input()  # 입력 창이 막는 동안 놓친 떼기·키 입력 상태를 버린다
		if v == null and quick:
			_show_toast(texts.t("msg.prompt_blocked"))
		guild_screen.name_entered(v)
		return
	var edit := LineEdit.new()
	edit.name = "NameEdit"
	edit.max_length = GuildRules.NAME_MAX
	edit.text = default_name
	edit.custom_minimum_size = Vector2(420, 64)  # 누르는 칸 64 이상(05 §9.1)
	edit.add_theme_font_size_override("font_size", 20)
	var ok_b := ModalLayer.button(texts.t("ui.ok"), func() -> void:
		modal.close()
		guild_screen.name_entered(edit.text))
	ok_b.name = "NameOk"
	edit.text_submitted.connect(func(_t: String) -> void: ok_b.pressed.emit())
	var cancel_b := ModalLayer.button(texts.t("ui.cancel"), func() -> void:
		modal.close()
		guild_screen.name_entered(null))
	cancel_b.name = "NameCancel"
	var rows: Array[Control] = [ModalLayer.label(texts.t("guild.name_prompt"), 16), edit, ModalLayer.row([ok_b, cancel_b] as Array[Control])]
	modal.open("name", texts.t("guild.name_title"), rows)
	edit.grab_focus.call_deferred()
	edit.select_all.call_deferred()


## 상점이 닫혔다: 캠프를 닫을 때와 같은 길(눌림·미리 받은 입력을 버리고 탐색 화면을 다시 맞춘다).
func _on_shop_closed() -> void:
	_on_party_closed()  # 마을 화면을 걷고(커서 그대로 「정크 공방」) 바탕을 광장으로 되돌린다(TownScreen._refresh)


## 상점 저장 갈고리(사기·장착이 받아들여진 직후). 실패하면 탐색 화면의 실패 토스트만 띄우고 상점은 차례를 이어 간다(08 §8.11 F6).
func _on_shop_save() -> void:
	_autosave()


## 남은 물음(계단·마을 문, M3 A3 부터 닫힌 상자도, M3 A5 부터 남은 채집 지점도)을 띄울 수 있으면 띄운다. 전멸·전투 대기거나 물을 것이 없으면(question_here) 물음을 버린다.
## 창(알림·메모·전투·캠프·상점)이 열려 있거나 연출 중이면 남겨 둔다. 지도 손짓은 막지 않는다: 창이 열리며 취소한다(05 §9.3).
func _try_stairs() -> void:
	if not _stairs_ask:
		return
	if state == null or state.wiped or state.encounter.pending or ExplorationRules.question_here(state).is_empty():
		_stairs_ask = false
		return
	if view.is_busy() or modal.is_open() or battle_layer.is_open() or party_menu.is_open() or shop_screen.is_open() or guild_screen.is_open() \
			or quest_screen.is_open() or not ExplorationRules.can_act(state):
		return
	_stairs_ask = false
	_open_stairs()


## 다른 창이 닫힌 뒤(다음 프레임): 전투·전멸 창이 먼저이고, 그다음 남은 계단 물음.
func _retry_stairs() -> void:
	if state == null or not _stairs_ask:
		return
	if state.wiped or state.encounter.pending:
		_stairs_ask = false
		return
	_try_stairs()


## 계단 확인 창(M3 A1). 원작 프레임을 찾지 못해 알림·전멸 창과 같은 층 3 창으로 띄운다(원작과 다른 점).
## 처음 커서(키보드 포커스)는 「예」다(D25: 되돌릴 수 있는 물음은 원작처럼 YES 먼저). 행동할 수 있고 계단 위일 때만 띄우고, 띄웠으면 true.
## 지도에서 진행 중인 손짓은 막지 않는다: 창이 열리면(modal.opened → _clear_input) 다른 창처럼 지도 입력을 취소한다.
func _open_stairs() -> bool:
	if state == null or modal.is_open() or battle_layer.is_open() or party_menu.is_open() or shop_screen.is_open() or guild_screen.is_open() \
			or quest_screen.is_open() or not ExplorationRules.can_act(state):
		return false
	var q := ExplorationRules.question_here(state)
	if q.get("kind") == "chest":
		_open_chest_question()
		return true
	if q.get("kind") == "gather":
		_open_gather_question()
		return true
	if q.get("kind") == "boss":
		_open_boss_question(str(q["foe"]))
		return true
	var st := ExplorationRules.stair_here(state)
	if st.is_empty():
		return false
	# 마을 문(B1F 시작 칸, M3 A2)은 같은 창에 마을 글(「아보르 입구」 / 마을로 돌아갈까?).
	var gate := str(st["to"]) == ExplorationState.TOWN
	var yes := _named(ModalLayer.button(texts.t("ui.yes"), _answer_stairs.bind(true)), "StairsYes")
	var no := _named(ModalLayer.button(texts.t("ui.no"), _answer_stairs.bind(false)), "StairsNo")
	var ask := texts.t("stairs.ask_town") if gate else texts.t("stairs.ask_" + str(st["way"]))
	var rows: Array[Control] = [ModalLayer.label(ask), ModalLayer.row([yes, no] as Array[Control])]
	_open_question("stairs", texts.t("stairs.title_town" if gate else "stairs.title"), rows)
	yes.grab_focus.call_deferred()
	return true


## 보물상자 물음(M3 A3, 층 3 kind "chest"). 원작 프레임을 찾지 못해 계단 물음과 같은 창이다(이름 붙은 차이).
## 처음 커서는 「예」(D25). 「예」면 규칙 행동 OPEN(자동 저장·안내), 「아니오」·Esc 면 닫기만(상자 위에 그대로, 저장 없음).
func _open_chest_question() -> void:
	var yes := _named(ModalLayer.button(texts.t("ui.yes"), _answer_chest.bind(true)), "ChestYes")
	var no := _named(ModalLayer.button(texts.t("ui.no"), _answer_chest.bind(false)), "ChestNo")
	var rows: Array[Control] = [ModalLayer.label(texts.t("chest.ask")), ModalLayer.row([yes, no] as Array[Control])]
	_open_question("chest", texts.t("chest.title"), rows)
	yes.grab_focus.call_deferred()


func _answer_chest(yes: bool) -> void:
	if modal.kind != "chest":
		return
	modal.close()
	if yes:
		request_action(A.OPEN)


## 채집 물음(M3 A5, 층 3 kind "gather"). 원작 프레임을 찾지 못해 상자·계단 물음과 같은 창이다(이름 붙은 차이, 설계 §5.1).
## 제목은 종류(채취·절단·추출 지점), 글 두 줄(종류의 물음 · 「오늘 남은 횟수 n/m」), 처음 커서는 「예」(D25).
## 「예」면 규칙 행동 GATHER(안내·자동 저장), 「아니오」·Esc 면 닫기만(지점 위에 그대로, 저장 없음). 채집 뒤에 다시 묻지 않는다(조사로 묻는다).
func _open_gather_question() -> void:
	var p := state.floor_def.point_at(state.party.at)
	var yes := _named(ModalLayer.button(texts.t("ui.yes"), _answer_gather.bind(true)), "GatherYes")
	var no := _named(ModalLayer.button(texts.t("ui.no"), _answer_gather.bind(false)), "GatherNo")
	var rows: Array[Control] = [ModalLayer.label(texts.t("gather.ask." + p.kind)),
		ModalLayer.label(texts.t("gather.left", {"left": state.world.gather_left(p), "uses": p.uses})),
		ModalLayer.row([yes, no] as Array[Control])]
	_open_question("gather", texts.t("gather.title." + p.kind), rows)
	yes.grab_focus.call_deferred()


func _answer_gather(yes: bool) -> void:
	if modal.kind != "gather":
		return
	modal.close()
	if yes:
		request_action(A.GATHER)


## 보스 물음(M3 A9b 설계 §5.2, 층 3 kind "boss"). 원작에 보스 물음 프레임이 없어 계단·상자 물음과 같은 창이다(이름 붙은 차이, D28 물음 창 하나).
## 글 두 줄: 「{name}이(가) 버티고 서 있다. 싸울까?」 · 경고 색 「이 싸움에서는 도망칠 수 없다」. 처음 커서는 「아니오」(O7: 도망칠 수 없는 싸움은
## 되돌릴 수 없는 행동, D25). 「예」면 규칙 행동 FIGHT(전투 시작 자동 저장 → 전투 층), 「아니오」·Esc·Backspace 면 닫기만(저장 없음). 다시 부딪히면 다시 묻는다.
func _open_boss_question(foe: String) -> void:
	var yes := _named(ModalLayer.button(texts.t("ui.yes"), _answer_boss.bind(true)), "BossYes")
	var no := _named(ModalLayer.button(texts.t("ui.no"), _answer_boss.bind(false)), "BossNo")
	var warn := ModalLayer.label(texts.t("boss.no_escape"))
	warn.name = "BossNoEscape"
	warn.add_theme_color_override("font_color", BOSS_WARN)
	var rows: Array[Control] = [ModalLayer.label(texts.t("boss.ask", {"name": FoeLook.name_of(state, texts, foe)})), warn,
		ModalLayer.row([yes, no] as Array[Control])]
	_open_question("boss", texts.t("boss.title"), rows)
	no.grab_focus.call_deferred()


func _answer_boss(yes: bool) -> void:
	if modal.kind != "boss":
		return
	modal.close()
	if yes:
		request_action(A.FIGHT)


## 층 3 물음 창(계단·마을 문·상자·전멸·지도 물음)을 연다. 알림 줄과 창의 규칙은 modal.opened 한곳에 있다(_on_modal_toast).
func _open_question(kind: String, title: String, rows: Array[Control]) -> void:
	modal.open(kind, title, rows)


## 계단 확인 창의 답: 「예」면 규칙 행동 STAIRS(층 바꾸기·자동 저장), 「아니오」면 닫기만(계단 위에 그대로 선다, 저장 없음).
func _answer_stairs(yes: bool) -> void:
	if modal.kind != "stairs":
		return
	modal.close()
	if yes:
		request_action(A.STAIRS)


## 전멸 창(01 §4.10, M3 A2b): 「마지막 기록으로 돌아간다」(검사를 지난 가장 새 수동 저장이 있을 때만) · 「처음부터」(마을 새 게임).
## 어느 쪽이든 지도 물음(wipe_map)이 뒤따른다. 두 창 모두 Esc 로 닫히지 않는다(고르기가 필요하다).
func _open_wipe() -> void:
	_wipe_target = null
	var rows: Array[Control] = [ModalLayer.label(texts.t("msg.wiped"))]
	var slot := store.latest_manual()
	if not slot.is_empty():
		var load_b := ModalLayer.button(texts.t("wipe.load_manual"), _wipe_load.bind(slot))
		load_b.name = "WipeLoad"
		rows.append(load_b)
	var new_b := ModalLayer.button(texts.t("wipe.new_game"), _wipe_new_game)
	new_b.name = "WipeNewGame"
	rows.append(new_b)
	_open_question("wipe", texts.t("wipe.title"), rows)


## 「마지막 기록으로 돌아간다」: 슬롯을 먼저 읽어 검사한다(실패하면 알림, 상태 그대로 → 알림을 닫으면 전멸 창). 그다음 지도 물음.
func _wipe_load(slot: String) -> void:
	if modal.kind != "wipe":
		return
	var l := store.load_slot(slot)
	if not l.ok():
		_alert(texts.t("msg.load_failed", {"reason": l.result.error}))
		return
	_wipe_relocated = l.result.relocated
	_ask_wipe_map(l.result.state, true)


## 「처음부터」: 마을 새 게임(1일째). 그다음 지도 물음(남기면 새 게임에 합친다, §8 고름 10).
func _wipe_new_game() -> void:
	if modal.kind != "wipe":
		return
	_wipe_relocated = false
	_ask_wipe_map(_new_state(true), false)


## 지도 물음(「이번 원정에서 그린 지도를 남길까?」, 처음 포커스 「예」 §8 고름 11). 답하기 전에는 상태를 바꾸지 않는다:
## 그사이 새로 고치면 자동 저장(전멸)이 그대로라 타이틀 → 이어하기 → 전멸 창이 다시 뜬다.
func _ask_wipe_map(target: ExplorationState, loaded: bool) -> void:
	_wipe_target = target
	_wipe_loaded = loaded
	var yes := _named(ModalLayer.button(texts.t("ui.yes"), _answer_wipe_map.bind(true)), "WipeMapYes")
	var no := _named(ModalLayer.button(texts.t("ui.no"), _answer_wipe_map.bind(false)), "WipeMapNo")
	var rows: Array[Control] = [ModalLayer.label(texts.t("wipe.map_ask")), ModalLayer.row([yes, no] as Array[Control])]
	_open_question("wipe_map", texts.t("wipe.map_title"), rows)
	yes.grab_focus.call_deferred()


## 지도 물음의 답: 남기면 전멸한 상태의 지도 그림을 새 상태에 합친다(TownRules.keep_map). 그다음 상태 바꾸기 → 자동 저장 → 안내.
## 수동 저장은 숙소에서 하므로 돌아가면 보통 마을 광장이다(마을 저장이면 _set_state 가 광장을 연다).
func _answer_wipe_map(keep: bool) -> void:
	if modal.kind != "wipe_map" or _wipe_target == null or state == null:
		return
	var target := _wipe_target
	_wipe_target = null
	if keep:
		TownRules.keep_map(target, state)
	modal.close()
	_set_state(target)
	if not _wipe_loaded:
		_autosave()
		return
	_after_load_save(_wipe_relocated, "msg.loaded", "msg.loaded_save_failed")


## 캠프 「기록」 화면의 슬롯 카드 값(07 §9.2): 검사를 지난 저장이면 대표 대원(파티 칸 0)·Lv, 층 · 걸음, 저장 시각(저장에 이미 있는 값).
func record_slots() -> Array:
	var out := []
	for slot in SaveStore.MANUAL_SLOTS:
		var l := store.load_slot(slot)
		if not l.ok():
			out.append({"slot": slot, "ok": false})
			continue
		var st := l.result.state
		out.append({"slot": slot, "ok": true, "leader": PartyNames.member_name(st, texts, 0),
			"level": texts.t("party.level", {"level": st.party.members[0].level}),
			"where": texts.t("menu.slot_where", {"floor": _place_of(st), "steps": st.steps}),
			"time": _local_time(l.result.saved_at)})
		if not FoeRules.cleared(st).is_empty():
			out[-1]["clear"] = true  # 클리어 표(M3 A9b 설계 §5.5): 클리어한 기록만 키가 있다(아닌 줄은 그대로)
	return out


## 저장된 상태의 장소 글: 마을이면 「뿌리마을 광장」(M3 A2), 미궁이면 「층 이름 / B1F」.
func _place_of(st: ExplorationState) -> String:
	return texts.t("town.plaza") if st.in_town() else FloorNames.place(texts, st.defs, st.floor_def)


func _set_automap(mode: String) -> void:
	if settings.set_automap(mode):
		settings.save_to(settings_path)
	party_menu.refresh_view()
	title_screen.refresh_view()


static func _named(c: Control, n: String) -> Control:
	c.name = n
	return c


func _alert(message: String) -> void:
	var ok_b := ModalLayer.button(texts.t("ui.ok"), _close_alert)
	ok_b.name = "AlertOk"
	var rows: Array[Control] = [ModalLayer.label(message), ok_b]
	modal.open("alert", texts.t("ui.notice"), rows)


func _close_alert() -> void:
	modal.close()
	if state != null:
		_check_windows()


# ---- 메모 (05 §9.3: 웹은 브라우저 입력 창, PC 는 LineEdit 창) ----

func _on_memo_requested(c: Vector2i) -> void:
	var old: String = state.annotation.memos.get(c, "")
	if bridge.is_web():
		var t0 := Time.get_ticks_msec()
		var v: Variant = bridge.prompt(texts.t("map.memo_prompt"), old)
		var quick := Time.get_ticks_msec() - t0 < PROMPT_BLOCKED_MS
		_clear_input()  # 입력 창이 막는 동안 놓친 떼기·키 입력 상태를 버린다
		if v == null:
			if quick:
				_show_toast(texts.t("msg.prompt_blocked"))
			return
		apply_memo(c, v)
		return
	var edit := LineEdit.new()
	edit.name = "MemoEdit"
	edit.max_length = MapAnnotation.MEMO_MAX
	edit.text = old
	edit.custom_minimum_size = Vector2(420, 64)  # 누르는 칸 64 이상(05 §9.1, NameEdit 과 같다)
	edit.add_theme_font_size_override("font_size", 20)
	var ok_b := ModalLayer.button(texts.t("ui.ok"), func() -> void:
		modal.close()
		apply_memo(c, edit.text))
	ok_b.name = "MemoOk"
	edit.text_submitted.connect(func(_t: String) -> void: ok_b.pressed.emit())
	var rows: Array[Control] = [
		ModalLayer.label(texts.t("map.memo_prompt"), 16), edit,
		ModalLayer.row([ok_b, _named(ModalLayer.button(texts.t("ui.cancel"), modal.close), "MemoCancel")] as Array[Control]),
	]
	modal.open("memo", texts.t("map.tool.memo"), rows)
	edit.grab_focus.call_deferred()


## 메모 한 단계(40자 넘으면 자른다, 비우면 지운다).
func apply_memo(c: Vector2i, text: String) -> void:
	var t := text.strip_edges()
	if t.length() > MapAnnotation.MEMO_MAX:
		t = t.substr(0, MapAnnotation.MEMO_MAX)
		_show_toast(texts.t("msg.memo_cut"))
	var ann := state.annotation
	ann.begin_stroke()
	ann.set_memo(c, t)
	var changed := ann.end_stroke()
	map.queue_redraw()
	_on_map_edited(changed)


# ---- 지도 ----

func _on_map_edited(changed: bool) -> void:
	if changed:
		_autosave()
	_refresh_toolbar()


## 도구를 고른다. 바닥 색은 견본(1~4)이면 그 색, 도구 열의 바닥 색 단추(0)면 지금 색 그대로.
func _choose_tool(tool: String, color: int) -> void:
	map.tool = tool
	if tool == "color" and color > 0:
		map.paint_color = color
	_refresh_toolbar()


## 아이콘 판에서 고른 아이콘으로 아이콘 도구를 쓴다(판은 아이콘 도구인 동안 층 전체 보기 자리에 남는다, 원작 nin_04).
func _choose_icon(icon: String) -> void:
	map.icon_type = icon
	_choose_tool("icon", 0)


func _on_toolbar_action(name: String) -> void:
	match name:
		"undo":
			map.undo()
		"to_party":
			map.to_party()
		"zoom_in":
			map.zoom(1.25)
		"zoom_out":
			map.zoom(0.8)


func _refresh_toolbar() -> void:
	map_window.show_current(map.tool, map.paint_color, map.icon_type, state != null and state.annotation.can_undo())
	_debug_dirty = true


func _toggle_map() -> void:
	_set_map_open(not _map_open)


## 지도 판을 열거나 닫는다(지도 단추·M 키는 바꾸기, 「돌아가기」는 닫기). 어느 길이든 판 안에서 누르고 있던 것
## (그리기 획·「돌아가기」·도구·견본·아이콘 판)을 취소한다: 숨긴 단추의 떼기가 뒤늦게 일하지 않는다.
## 열 때마다 그리기 격자는 파티를 따라가는 기본 확대(약 7칸)로 돌아간다.
func _set_map_open(open: bool) -> void:
	if open == _map_open:
		return
	_map_open = open
	map.cancel_input()
	map_window.cancel_all()
	_layout()
	if _map_open:
		map.to_party()


## 지도 표시가 바뀌었으면(편집·되돌리기·메모·자동 기록·상태 바꾸기) 지도 보기 셋을 다시 그린다. 한 곳에서 판(version)을 본다.
func _sync_map_views() -> void:
	var ann := state.annotation
	if ann == _views_ann and ann.version == _views_version:
		return
	_views_ann = ann
	_views_version = ann.version
	map.queue_redraw()
	map_window.overview.queue_redraw()
	minimap.queue_redraw()


# ---- 화면 구성 ----

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	# 층 0: 3D 시야(화면 전체, 어느 모드에서도 크기를 바꾸지 않는다)와 피해 번쩍임(시야 위, HUD 아래).
	view_container = SubViewportContainer.new()
	view_container.set_script(preload("res://src/game/dungeon/view_container.gd"))
	view_container.name = "ViewContainer"
	view_container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(view_container)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.handle_input_locally = true
	sv.gui_disable_input = true
	view_container.add_child(sv)
	_view_sv = sv
	_view_sv_mode = sv.render_target_update_mode
	view = DungeonView.new()
	view.speed = anim_speed
	sv.add_child(view)
	view.setup(floor_def, WorldState.new())
	view.animation_finished.connect(_on_animation_finished)

	_flash.name = "DamageFlash"
	_flash.color = Color(1, 0.1, 0.05, 0.0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_flash)
	# 마을 바탕(M3 A2): 시야·번쩍임 위, 모든 UI 층 아래. 마을에 있는 동안만 보인다(누르기 없음).
	town_backdrop = TownArt.TownBackdrop.new()
	town_backdrop.name = "TownBackdrop"
	add_child(town_backdrop)

	hud_root = _layer_root("Hud", LAYER_HUD)
	windows_root = _layer_root("Windows", LAYER_WINDOWS)
	var toast_root := _layer_root("Toast", LAYER_TOAST)
	_build_hud()

	# 층 2: 지도 판 → 전투 층 → 파티 메뉴(트리 순서 = 그리는·누르는 순서).
	map_window = MapWindow.new()
	map_window.name = "MapWindow"
	windows_root.add_child(map_window)
	map_window.build(texts, FloorNames.label(texts, store.defs, floor_def))
	map = map_window.map
	toolbar = map_window.toolbar
	toolbar.tool_chosen.connect(_choose_tool)
	toolbar.action.connect(_on_toolbar_action)
	map_window.icon_chosen.connect(_choose_icon)
	map_window.back_requested.connect(_set_map_open.bind(false))
	map.edited.connect(_on_map_edited)
	map.memo_requested.connect(_on_memo_requested)
	map.view_changed.connect(func() -> void: _debug_dirty = true)
	# 실행 취소·확대·축소·파티로는 안내 줄(지도 판이 열린 동안만, 원작 UNDO 안내 자리).
	for b in toolbar.action_buttons():
		hint_row.add_child(b)

	battle_layer = BattleLayer.new()
	battle_layer.name = "BattleLayer"
	windows_root.add_child(battle_layer)
	battle_layer.build(texts)
	battle_layer.save_hook = _on_battle_save
	battle_layer.commit_hook = _on_battle_commit
	battle_layer.blocked_hook = func() -> bool: return modal.is_open()
	battle_layer.closed.connect(_on_battle_closed)
	battle_layer.opened.connect(func() -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	battle_layer.submitted.connect(func(_e: Array) -> void: _debug_dirty = true)
	# 마을 화면(M3 A2): 전투 층 뒤, 캠프·상점 앞(캠프·상점이 열리면 감춘다).
	town_screen = TownScreen.new()
	town_screen.name = "TownScreen"
	windows_root.add_child(town_screen)
	town_screen.build(texts)
	town_screen.backdrop = town_backdrop
	town_screen.blocked_hook = func() -> bool: return modal.is_open()
	town_screen.camp_requested.connect(_open_party)
	town_screen.shop_requested.connect(_open_shop)
	town_screen.guild_requested.connect(_open_guild)
	town_screen.quest_requested.connect(_open_quest)
	town_screen.enter_requested.connect(_enter_labyrinth)
	town_screen.stay_hook = _inn_stay
	town_screen.opened.connect(func() -> void:
		_settle_toast("window")
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	town_screen.visibility_changed.connect(func() -> void:
		_debug_dirty = true
		_debug_settle = 2)
	party_menu = PartyMenu.new()
	party_menu.name = "PartyMenu"
	windows_root.add_child(party_menu)
	party_menu.build(texts)
	party_menu.save_hook = _on_party_save
	party_menu.records = {"slots": record_slots, "save": _save_slot, "load": _load_slot, "export": _export, "import": _import,
		"automap": func() -> String: return settings.automap, "set_automap": _set_automap, "new_game": _start_new_game}
	# 수동 저장은 숙소에서(D30 = R-B): 캠프 「기록」의 「저장」은 숙소 쪽(숙소·숙소 기록)에서 연 캠프에서만 받는다.
	party_menu.records["can_save"] = func() -> bool: return _in_town() and town_screen.page in ["inn", "inn_save"]
	town_screen.records = party_menu.records.duplicate()
	town_screen.records["can_save"] = func() -> bool: return true  # 숙소 「기록한다」 쪽
	party_menu.blocked_hook = func() -> bool: return modal.is_open()
	# 마을에서 연 캠프(research 07 §2.2): 장소 띠는 그 장소 이름, 문패는 날(「n일째」). 미궁에서는 빈 글(층 이름·걸음 그대로).
	party_menu.place_hook = func() -> String:
		if not _in_town():
			return ""
		if quest_screen.is_open():
			return quest_screen.place_text()
		return guild_screen.place_text() if guild_screen.is_open() else town_screen.place_text()
	party_menu.plate_hook = func() -> String: return town_screen.day_text() if _in_town() else ""
	party_menu.opened.connect(func() -> void:
		_settle_toast("window")
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	party_menu.closed.connect(_on_party_closed)
	party_menu.visibility_changed.connect(_layout)
	party_menu.changed.connect(_on_party_changed)
	party_menu.arrange_hook = arrange_party
	shop_screen = ShopScreen.new()
	shop_screen.name = "ShopScreen"
	windows_root.add_child(shop_screen)
	shop_screen.build(texts)
	shop_screen.save_hook = _on_shop_save
	shop_screen.blocked_hook = func() -> bool: return modal.is_open()
	shop_screen.opened.connect(func() -> void:
		_settle_toast("window")
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	shop_screen.closed.connect(_on_shop_closed)
	shop_screen.visibility_changed.connect(_layout)
	shop_screen.changed.connect(func(_e: Array) -> void: _debug_dirty = true)
	# 모험가 길드(M3 A7c): 상점 바로 뒤(트리 순서). 상점과 같은 길로 열고 닫는다(마을 화면을 덮고, 닫으면 광장 「모험가 길드」 줄로).
	guild_screen = GuildScreen.new()
	guild_screen.name = "GuildScreen"
	windows_root.add_child(guild_screen)
	guild_screen.build(texts)
	guild_screen.backdrop = town_backdrop
	guild_screen.save_hook = _autosave
	guild_screen.blocked_hook = func() -> bool: return modal.is_open()
	guild_screen.opened.connect(func() -> void:
		_settle_toast("window")
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	guild_screen.closed.connect(_on_party_closed)
	guild_screen.visibility_changed.connect(func() -> void:
		_layout()
		_debug_dirty = true
		_debug_settle = 2)
	guild_screen.changed.connect(func(_e: Array) -> void: _debug_dirty = true)
	guild_screen.camp_requested.connect(_open_party)
	guild_screen.name_requested.connect(_on_guild_name)
	# 정보상 바·관리국(M3 A8b, 설계 §6.1): 길드 바로 뒤(트리 순서: 길드 위에 그리고 먼저 눌린다). 길드와 같은 길로 열고 닫는다.
	# 상태는 quest_action(받아들이면 자동 저장 한 번)으로만 바꾼다.
	quest_screen = QuestScreen.new()
	quest_screen.name = "QuestScreen"
	windows_root.add_child(quest_screen)
	quest_screen.build(texts)
	quest_screen.backdrop = town_backdrop
	quest_screen.action_hook = quest_action
	quest_screen.blocked_hook = func() -> bool: return modal.is_open()
	quest_screen.opened.connect(func() -> void:
		_settle_toast("window")
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	quest_screen.closed.connect(_on_party_closed)
	quest_screen.visibility_changed.connect(func() -> void:
		_layout()
		_debug_dirty = true
		_debug_settle = 2)
	quest_screen.changed.connect(func(_e: Array) -> void: _debug_dirty = true)
	quest_screen.camp_requested.connect(_open_party)
	# 타이틀(M3 A2): 층 2 의 맨 끝(모든 창 위, 불투명 바탕). 기록 판은 캠프와 같은 부품(불러오기·가져오기·자동 지도만).
	title_screen = TitleScreen.new()
	title_screen.name = "TitleScreen"
	windows_root.add_child(title_screen)
	title_screen.build(texts)
	title_screen.blocked_hook = func() -> bool: return modal.is_open()
	title_screen.actions = {"continue": _continue_game, "new_game": _start_new_game}
	title_screen.records = {"slots": record_slots, "load": _load_slot, "import": _import,
		"automap": func() -> String: return settings.automap, "set_automap": _set_automap}
	title_screen.opened.connect(func() -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	title_screen.visibility_changed.connect(_layout)

	# 층 3: 창(메뉴·알림·메모·전멸). ModalLayer 가 화면 전체 뿌리다.
	var modal_cl := CanvasLayer.new()
	modal_cl.name = "Modal"
	modal_cl.layer = LAYER_MODAL
	add_child(modal_cl)
	layers["Modal"] = modal_cl
	modal = ModalLayer.new()
	modal.name = "ModalLayer"
	modal.theme = theme
	story_box = StoryBox.new()
	story_box.theme = theme
	story_box.build(texts)
	story_box.finished.connect(_on_story_finished)
	modal.adopt_part(story_box)  # 주인 = 창 층(감춘 채): 화면과 함께 사라진다
	modal.opened.connect(func(_k: String) -> void:
		if _k == "clear":
			_layout()  # 이야기 상자: HUD·지도 판을 감춘다(_hud_hidden)
		_settle_toast("modal")
		_clear_input()
		party_menu.cancel_pointers()  # 캠프에서 누르고 있던 단추는 창이 덮은 뒤 떼도 일하지 않는다
		battle_layer.cancel_pointers()  # 전투도 같다(명령 줄·카드·키패드 등)
		shop_screen.cancel_pointers()  # 상점도 같다(08 §8.11: 눌린 「예」를 창이 덮으면 뗄 때 사지 않는다)
		guild_screen.cancel_pointers()
		quest_screen.cancel_pointers()
		town_screen.cancel_pointers()
		title_screen.cancel_pointers()
		_debug_dirty = true
		_debug_settle = 2)
	modal.closed.connect(func(_k: String) -> void:
		if _k == "clear":
			_layout()  # 이야기 상자가 닫혔다(마지막 쪽·불러오기·새 게임): HUD 를 되돌린다
			_refresh_hud()
		_settle_toast()
		_clear_input()  # 창 안에서 누른 키·단추는 닫힌 뒤에도 승인되지 않는다
		_retry_stairs.call_deferred()  # 이 창 때문에 띄우지 못한 계단 물음
		party_menu.cancel_pointers()  # 창이 뜨기 전부터 캠프에서 누르고 있던 손가락도(다른 손가락으로 창을 닫은 뒤 떼기)
		battle_layer.cancel_pointers()
		shop_screen.cancel_pointers()
		guild_screen.cancel_pointers()
		quest_screen.cancel_pointers()
		town_screen.cancel_pointers()
		title_screen.cancel_pointers()
		_debug_dirty = true
		_debug_settle = 2)
	modal_cl.add_child(modal)

	# 층 4: 알림 줄(전투 중 저장 실패 알림도 전투 층·창에 가리지 않는다).
	toast_area = Control.new()
	toast_area.name = "ToastArea"
	toast_area.mouse_filter = MOUSE_FILTER_IGNORE
	toast_area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	toast_root.add_child(toast_area)
	_toast.name = "Toast"
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0  # 아직 띄운 안내가 없다
	toast_area.add_child(_toast)
	# 저장 실패 안내 글줄(알림 줄과 같은 모양, 따로 놓인다: _warn_sync).
	_warn_label.name = "SaveWarning"
	_warn_label.add_theme_font_size_override("font_size", 22)
	_warn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_warn_label.add_theme_constant_override("outline_size", 8)
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.mouse_filter = MOUSE_FILTER_IGNORE
	_warn_label.modulate.a = 0.0
	toast_area.add_child(_warn_label)
	_build_save_chip(toast_root)
	_layout()


## 「저장 중」 표시(05 §8.3, 원작에 없음): 화면 위 가운데 가장자리. 어느 화면(탐색·지도·전투·캠프·창)에서도 그 자리에는
## 누르는 것이 없다(위쪽은 층 문패·전투 머리 띠·캠프 안내 띠 같은 장식, 단추는 양 끝). 높이 32 이하, 누르기를 받지 않는다.
func _build_save_chip(toast_root: Control) -> void:
	save_chip.name = "SaveChip"
	save_chip.mouse_filter = MOUSE_FILTER_IGNORE
	save_chip.visible = save_pending.is_pending()  # 시작할 때 올린 슬롯(_setup_save_pending)
	toast_root.add_child(save_chip)
	var label := Label.new()
	label.name = "SaveChipText"
	label.text = texts.t("hud.saving")
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", SAVE_CHIP_FONT)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	save_chip.add_child(label)
	var w := ceilf(label.get_minimum_size().x) + 24.0
	save_chip.set_anchors_preset(PRESET_CENTER_TOP)
	save_chip.offset_left = -w / 2.0
	save_chip.offset_right = w / 2.0
	save_chip.offset_top = SAVE_CHIP_TOP
	save_chip.offset_bottom = SAVE_CHIP_TOP + SAVE_CHIP_H
	# 지도 판 남색 바탕(반투명)에 판 테두리 색 얇은 선.
	save_chip.draw.connect(func() -> void:
		UiTheme.fill_round(save_chip, Rect2(Vector2.ZERO, save_chip.size), Color(MapPanel.BG, 0.82), 6, MapWindow.EDGE, 1))


## CanvasLayer 하나와 그 화면 전체 뿌리 Control(IGNORE: 빈 곳 누르기는 아래 층으로 간다). 테마는 층을 건너 이어지지 않아 다시 준다.
func _layer_root(layer_name: String, n: int) -> Control:
	var cl := CanvasLayer.new()
	cl.name = layer_name
	cl.layer = n
	add_child(cl)
	layers[layer_name] = cl
	var root := Control.new()
	root.name = layer_name + "Root"
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.theme = theme
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cl.add_child(root)
	return root


## 층 1 HUD(원작 탐색 화면 gw_28·gs_683213·nin_02). 부품은 시야 영역(view_area: 지도 판이 덮지 않는 곳)의 모서리에 앵커로 붙는다.
## 미니맵·위험 보석·층 문패는 장식(IGNORE). 이동 단추·조사는 원작에 없다(휴대폰 조작): 안내 줄 바로 위에 둔다.
func _build_hud() -> void:
	view_area = Control.new()
	view_area.name = "ViewArea"
	view_area.mouse_filter = MOUSE_FILTER_IGNORE
	view_area.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hud_root.add_child(view_area)

	# 위험 보석: 오른쪽 아래 모서리, 일부가 화면(지도 판이 열리면 판) 밖으로 잘린다.
	orb = DangerOrb.new()
	orb.name = "DangerOrb"
	view_area.add_child(orb)

	# 미니맵: 오른쪽 위, 파티 둘레 반투명(지도 판이 열리면 감춘다).
	minimap = MapOverview.new().setup(true)
	minimap.name = "MiniMap"
	minimap.set_anchors_preset(PRESET_TOP_RIGHT)
	minimap.offset_left = -EDGE - MINI_SIZE.x
	minimap.offset_right = -EDGE
	minimap.offset_top = EDGE
	minimap.offset_bottom = EDGE + MINI_SIZE.y
	view_area.add_child(minimap)

	# 층 문패: 왼쪽 위(원작 시각 다이얼 자리), 층 이름 + 걸음.
	floor_plate = HudPlate.new()
	floor_plate.name = "FloorPlate"
	floor_plate.set_anchors_preset(PRESET_TOP_LEFT)
	floor_plate.offset_right = PLATE_SIZE.x
	floor_plate.offset_bottom = PLATE_SIZE.y
	view_area.add_child(floor_plate)
	_floor_label.name = "FloorName"
	_floor_label.text = FloorNames.place(texts, store.defs, floor_def)
	_floor_label.add_theme_font_size_override("font_size", 22)
	_floor_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_floor_label.add_theme_constant_override("outline_size", 6)
	_floor_label.position = Vector2(26, 8)
	_floor_label.mouse_filter = MOUSE_FILTER_IGNORE
	floor_plate.add_child(_floor_label)
	_steps_label.name = "Steps"
	_steps_label.add_theme_font_size_override("font_size", 18)
	_steps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_steps_label.add_theme_constant_override("outline_size", 6)
	_steps_label.position = Vector2(26, 40)
	_steps_label.mouse_filter = MOUSE_FILTER_IGNORE
	floor_plate.add_child(_steps_label)

	# 안내 줄: 왼쪽 아래 가장자리(원작 CAMP·MAP). 캠프·지도(+ 지도 판이 열리면 실행 취소·확대·축소·파티로).
	hint_row = HBoxContainer.new()
	hint_row.name = "HintRow"
	hint_row.mouse_filter = MOUSE_FILTER_IGNORE
	hint_row.add_theme_constant_override("separation", int(HINT_GAP))
	hint_row.anchor_top = 1.0
	hint_row.anchor_bottom = 1.0
	hint_row.offset_left = EDGE
	hint_row.offset_right = EDGE
	hint_row.offset_top = -EDGE - HINT_H
	hint_row.offset_bottom = -EDGE
	hint_row.grow_horizontal = GROW_DIRECTION_END
	view_area.add_child(hint_row)
	camp_button = TouchButton.new().setup("", texts.t("camp.title"))
	camp_button.name = "CampButton"
	camp_button.activated.connect(_open_party)
	map_button = TouchButton.new().setup("map", texts.t("map.toggle"))
	map_button.name = "MapButton"
	map_button.activated.connect(_toggle_map)
	for b in [camp_button, map_button]:
		hint_row.add_child(b)

	# 이동 단추 묶음: 안내 줄 바로 위(겹치지 않는다). 안의 배치는 고정 크기 단추의 칸.
	pad_box = Control.new()
	pad_box.name = "Pad"
	pad_box.mouse_filter = MOUSE_FILTER_IGNORE
	pad_box.anchor_top = 1.0
	pad_box.anchor_bottom = 1.0
	pad_box.offset_left = EDGE
	pad_box.offset_right = EDGE + PAD_W
	pad_box.offset_bottom = -EDGE - HINT_H - HINT_GAP
	pad_box.offset_top = pad_box.offset_bottom - PAD_H
	view_area.add_child(pad_box)
	var pad_defs := [
		[A.TURN_LEFT, "turn_left", ""], [A.FORWARD, "up", ""], [A.TURN_RIGHT, "turn_right", ""],
		[A.STRAFE_LEFT, "strafe_left", ""], [A.BACK, "down", ""], [A.STRAFE_RIGHT, "strafe_right", ""],
		[A.INVESTIGATE, "investigate", texts.t("action.investigate")],
	]
	for i in pad_defs.size():
		var d: Array = pad_defs[i]
		var b := TouchButton.new().setup(d[1], d[2], true)
		b.name = "Pad_" + ExplorationRules.ACTION_NAMES.find_key(d[0])
		b.activated.connect(_on_pad.bind(d[0]))
		b.released.connect(func() -> void: _pad_since.erase(d[0]))  # 떼거나 취소하면 그 단추의 승인을 지운다
		pad_box.add_child(b)
		pad[d[0]] = b
		if i < 6:
			b.position = Vector2((i % 3) * (PAD_BUTTON + PAD_GAP), (i / 3) * (PAD_BUTTON + PAD_GAP))
			b.size = Vector2(PAD_BUTTON, PAD_BUTTON)
	var side_x := 3.0 * (PAD_BUTTON + PAD_GAP) + 8.0
	var inv: TouchButton = pad[A.INVESTIGATE]
	inv.position = Vector2(side_x, PAD_BUTTON + PAD_GAP)
	inv.size = Vector2(PAD_BUTTON + 16.0, PAD_BUTTON)


## 모드(지도 판 열림·전투·파티 메뉴)와 화면 폭에 따라 바뀌는 것만 맞춘다. 자리는 앵커가 정하고 여기서는
## 앵커로 나타낼 수 없는 것만 한다: 시야 영역·알림 영역의 오른쪽 여백(지도 판 폭), 알림 줄 자리(탐색 ↔ 전투), 보이기,
## 렌즈 이동 비율(판 폭 / 화면 폭). 3D 시야(ViewContainer)는 건드리지 않는다.
func _layout() -> void:
	if view_container == null:
		return
	var w := get_viewport_rect().size.x
	# 타이틀·마을(M3 A2): 3D 시야를 감추고 그리지 않는다. 마을에서는 그 자리에 마을 바탕.
	_set_view_active(not (_in_town() or _title_open()))
	town_backdrop.visible = _in_town()
	var explore := not _hud_hidden()
	var open := _map_open and explore
	hud_root.visible = explore
	map_window.visible = open
	var cover := MapWindow.WIDTH if open else 0.0
	if not open:
		map_window.cancel_all()  # 숨긴 판의 단추는 누름을 남기지 않는다(전투·파티 메뉴로 감출 때도)
	view_area.offset_right = -cover
	minimap.visible = not _map_open
	for b in toolbar.action_buttons():
		b.visible = _map_open
		if not _map_open:
			b.cancel()
	toast_area.offset_right = 0.0 if _battle_view else -cover
	_place_toast()
	if _view_on:
		view.set_lens_cover(cover / w if w > 0.0 else 0.0)
	map.refresh()
	_debug_dirty = true
	_debug_settle = 2


## 알림 줄 자리. 창(층 3)이 열려 있으면 창 둘레(_place_toast_by_modal), 아니면 전투·탐색 자리.
func _place_toast() -> void:
	if _battle_view:
		# 전투 중: 전투 층 메시지 띠 아래 · 적 영역 위, 명령 목록 오른쪽(BattleLayer.TOAST_Y·TOAST_LEFT) ~ 오른쪽 − TOAST_RIGHT.
		_toast.set_anchors_preset(PRESET_TOP_WIDE)
		_toast.offset_left = BattleLayer.TOAST_LEFT
		_toast.offset_right = -BattleLayer.TOAST_RIGHT
		_toast.offset_top = BattleLayer.TOAST_Y
		_toast.offset_bottom = BattleLayer.TOAST_Y + BattleLayer.TOAST_H
	else:
		# 탐색: 시야 영역 아래쪽, 이동 단추 묶음 바로 위.
		_toast.set_anchors_preset(PRESET_BOTTOM_WIDE)
		_toast.offset_left = 0.0
		_toast.offset_right = 0.0
		_toast.offset_bottom = TOAST_ROW_BOTTOM
		_toast.offset_top = _toast.offset_bottom - TOAST_H
	if modal != null and modal.is_open():
		_place_toast_by_modal()


## 덮이지 않은 시야 영역(화면 좌표). 지도 판이 열리면 판 왼쪽까지.
func view_area_rect() -> Rect2:
	var s := get_viewport_rect().size
	var cover := MapWindow.WIDTH if _map_open and not _hud_hidden() else 0.0
	return Rect2(Vector2.ZERO, Vector2(s.x - cover, s.y))


func _refresh_hud() -> void:
	_steps_label.text = texts.t("hud.steps", {"steps": state.steps})
	orb.gauge = state.encounter.gauge()
	minimap.refresh()
	_refresh_toolbar()


## 일반 안내(알림 줄, HEAD 그대로: 새 안내가 앞 안내를 바꾸고 2초 뒤 사라진다). 화면 창·창과의 규칙은 _settle_toast.
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 2.0
	_place_toast()
	if _warn_in_battle_band():
		_hide_toast()  # 전투 띠는 한 줄: 실패 안내가 있는 동안 일반 안내는 그리지 않는다(R5)
	# 화면 창으로 옮길지는 이 프레임의 처리가 끝난 뒤 본다: 같은 처리에서 마을을 닫거나(미궁 들어가기) 여는(마을 돌아오기) 일이 뒤따른다.
	_settle_toast.call_deferred("show")


## 알림 줄을 바로 지운다(남은 시간 0).
func _hide_toast() -> void:
	_toast_left = 0.0
	_toast.modulate.a = 0.0


## 일반 안내의 규칙(알림 줄은 층 4 라 창(층 3)·화면 창(층 2)의 단추를 가린다: 1280×720·1728×720 에서 y 422..458 이 창 아래 단추 줄·
## 기록 「내보내기」·광장 줄 끝과 겹쳤다):
## - 화면 창(캠프·상점·마을)이 열려 있으면(전투 밖) 그 창이 열린 동안 나온 안내는 그 창의 안내 줄(show_notice)로 옮기고,
##   창이 열리기 전부터 보이던 안내는 지운다(이동하면 사라지는 안내, 옮겨 다니지 않는다).
## - 창(층 3)이 열리면 보이던 안내는 지우고 다시 띄우지 않는다. 창이 열린 동안 나온 안내는 창 판 둘레 빈 띠에 둔다.
## why: "show" = 막 띄운 안내, "modal" = 창이 막 열렸다, "window" = 화면 창이 막 열렸다, "" = 그 밖(창 닫힘).
func _settle_toast(why: String = "") -> void:
	if _toast_left > 0.0 and why in ["show", "window"]:
		var w := _toast_window()
		if w != null:
			if why == "show":
				w.call("show_notice", _toast.text)
			_hide_toast()
	elif _toast_left > 0.0 and why == "modal":
		_hide_toast()
	else:
		_place_toast()
	_warn_sync()


## 저장 실패 안내를 새로 든다(새 2초, 앞 실패 안내를 바꾼다).
func _warn(text: String) -> void:
	_warn_end()
	_warn_text = text
	_warn_left = WARN_SEC
	_warn_sync()


## 저장 실패 안내를 끝낸다(다 보였을 때, 자동 저장이 성공했을 때): 띄운 곳에서 거둔다. 일반 안내는 건드리지 않는다.
func _warn_end() -> void:
	_warn_leave()
	_warn_text = ""
	_warn_left = 0.0


## 지금 띄운 곳에서 저장 실패 안내를 거둔다(화면 창은 그 창이 아직 그 글을 보이고 있을 때만).
func _warn_leave() -> void:
	if _warn_at == _warn_label:
		_warn_label.modulate.a = 0.0
	elif _warn_at != null and is_instance_valid(_warn_at) and str(_warn_at.get("notice")) == _warn_text:
		_warn_at.call("clear_notice")
	_warn_at = null


## 매 프레임(그리고 창·화면 창이 열리고 닫힐 때) 저장 실패 안내를 놓는다. 차례:
## 1) 창(층 3)이 열려 있으면 판 둘레 빈 띠(위, 없으면 아래). 둘 다 없으면 들고만 있고 시간을 멈춘다.
## 2) 아니면 캠프 > 상점 > 마을(전투 밖)의 안내 줄(매번 다시 쓴다: 창 안 이동으로 지워져도 돌아온다).
## 3) 아니면 전투 띠(HEAD 의 전투 중 알림 줄 자리). 4) 아니면 탐색 띠(일반 알림 줄 바로 위, HUD·지도·이동 단추와 겹치지 않는다).
## 놓인 동안(1~4) 시간이 준다. 남은 시간이 0 이하가 되면 이 호출에서 끝낸다(프레임 시간과 상관없이). 투명도는 남은 시간에서만 나온다.
func _warn_sync(delta: float = 0.0) -> void:
	if _warn_left <= 0.0:
		return
	var at: Object = _warn_label
	var y := 0.0
	if modal != null and modal.is_open():
		y = _modal_band_y(0)
		if y < 0.0:
			at = null
	else:
		var w := _toast_window()
		if w != null:
			at = w
	if at != _warn_at:
		_warn_leave()
		_warn_at = at
	if at == null:
		return
	_warn_left -= delta
	if _warn_left <= 0.0:
		_warn_end()
		return
	if at == _warn_label:
		_warn_label.text = _warn_text
		if modal != null and modal.is_open():
			_put_label(_warn_label, y)
		else:
			_place_warn_label()
		_warn_label.modulate.a = clampf(_warn_left / 0.5, 0.0, 1.0)
		if _warn_in_battle_band() and _toast_left > 0.0:
			_hide_toast()  # 전투 띠는 한 줄이고 실패 안내가 앞선다(화면 창 안내 줄과 같다, R5)
	elif str(at.get("notice")) != _warn_text:
		at.call("show_notice", _warn_text, _warn_left)


## 저장 실패 안내가 지금 전투 띠에 놓였는지(전투 띠는 메시지 띠와 적 영역 사이 한 줄뿐이라 일반 안내와 함께 둘 수 없다).
func _warn_in_battle_band() -> bool:
	return _battle_view and _warn_left > 0.0 and _warn_at == _warn_label and not (modal != null and modal.is_open())


## 저장 실패 안내 글줄의 제자리(창이 없을 때): 전투 중이면 전투 띠, 탐색이면 일반 알림 줄 바로 위 띠.
func _place_warn_label() -> void:
	if _battle_view:
		_warn_label.set_anchors_preset(PRESET_TOP_WIDE)
		_warn_label.offset_left = BattleLayer.TOAST_LEFT
		_warn_label.offset_right = -BattleLayer.TOAST_RIGHT
		_warn_label.offset_top = BattleLayer.TOAST_Y
		_warn_label.offset_bottom = BattleLayer.TOAST_Y + BattleLayer.TOAST_H
	else:
		_warn_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
		_warn_label.offset_left = 0.0
		_warn_label.offset_right = 0.0
		_warn_label.offset_bottom = TOAST_ROW_BOTTOM - TOAST_H - WARN_GAP
		_warn_label.offset_top = _warn_label.offset_bottom - TOAST_H


## 지금 보이는 저장 실패 안내 글(글줄 또는 화면 창 안내 줄). 없거나 들고만 있으면 "".
func warning_shown() -> String:
	if _warn_at == _warn_label and _warn_label.modulate.a > 0.0:
		return _warn_text
	if _warn_at != null and _warn_at != _warn_label and str(_warn_at.get("notice")) == _warn_text:
		return _warn_text
	return ""


## 알림 줄 대신 안내를 받을 화면 창(층 2). 전투 중에는 전투 자리(_place_toast)를 쓴다.
func _toast_window() -> Control:
	if _battle_view or party_menu == null:
		return null
	for w in [party_menu, shop_screen, guild_screen, quest_screen, town_screen]:
		if w.is_open():
			return w
	return null


## 창 판(제목 문패 포함) 둘레 빈 띠의 화면 y: n = 0 은 판 바로 위(저장 실패 안내), 1 은 그 위(창이 열린 동안 나온 일반 안내).
## 위쪽 한계는 저장 칩 아래. 위에 자리가 없으면 판 아래부터, 그것도 없으면 -1. 판 크기는 컨테이너 정렬 뒤에 맞으므로 매 프레임 다시 잰다.
func _modal_band_y(n: int) -> float:
	var area := toast_area.get_global_rect()
	var panel: Rect2 = modal.band_rect()
	var top_min := SAVE_CHIP_TOP + SAVE_CHIP_H + TOAST_GAP
	var bottom_max := area.end.y - EDGE
	var above := panel.position.y - (n + 1) * (TOAST_GAP + TOAST_H)
	if above >= top_min:
		return above
	var below := panel.end.y + TOAST_GAP + n * (TOAST_H + TOAST_GAP)
	if below + TOAST_H <= bottom_max:
		return below
	return -1.0


## 글줄을 화면 y 에 둔다(알림 영역 폭 전체).
func _put_label(l: Label, y: float) -> void:
	var area := toast_area.get_global_rect()
	l.set_anchors_preset(PRESET_TOP_WIDE)
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = y - area.position.y
	l.offset_bottom = l.offset_top + TOAST_H


## 창이 열린 동안의 일반 안내: 판 둘레 빈 띠(저장 실패 안내가 판 바로 위 띠에 있으면 그다음 띠). 자리가 없으면 지운다.
func _place_toast_by_modal() -> void:
	var y := _modal_band_y(1 if _warn_at == _warn_label else 0)
	if y < 0.0:
		_hide_toast()
		return
	_put_label(_toast, y)


func _flash_damage() -> void:
	_flash.color.a = 0.35


func _process(delta: float) -> void:
	if state == null:
		# 타이틀(M3 A2): 상태가 없어도 저장 반영 기다림·알림 줄·디버그 요약은 돈다.
		save_pending.tick(delta)
		_fade_toast(delta)
		if _debug:
			_debug_publish()
		return
	if _autosave_pending and not map.is_stroking():
		_autosave()
	_sync_map_views()
	if state != null and not view.is_busy() and Engine.get_process_frames() != _action_frame:
		if _queued >= 0:
			# 같은 프레임이라 미뤘던 행동(연출이 없는 행동 뒤): 다시 막힘을 보고 한다.
			var a := _queued
			_queued = -1
			request_action(a)
		elif _repeat_wait:
			_try_repeat()
	_fade_toast(delta)
	save_pending.tick(delta)
	if save_chip.visible and save_chip.modulate.a < 1.0:
		save_chip.modulate.a = minf(1.0, save_chip.modulate.a + delta / 0.15)
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)
	if _debug:
		_debug_publish()


## 디버그 상태 요약을 낼 때가 되면 낸다(층·창이 입력을 받았거나 바쁨이 바뀌었거나 _debug_dirty). 타이틀(상태 없음)에서도 돈다.
func _debug_publish() -> void:
	var busy := _is_busy() if state != null else false
	# 전투 층·파티 메뉴가 입력을 받으면 상태 요약을 다시 낸다(메뉴 안 탭·초안·확인 창도 요약에 있다).
	# 캠프 안내가 시간으로 사라질 때도(M3 A4b: 소지품 띠가 결과 안내 → 「소지품   n/60」로 돌아온다).
	var sig := "%s/%s/%d/%s/%s/%d/%s/%d/%s/%d/%s/%d/%s" % [battle_layer.phase, battle_layer.sub, battle_layer.member,
		str(battle_layer.log_view.visible), str(party_menu.is_open()), party_menu.accepted_inputs, str(shop_screen.is_open()),
		shop_screen.accepted_inputs, str(town_screen.is_open()), town_screen.accepted_inputs, str(title_screen.is_open()),
		title_screen.accepted_inputs, party_menu.notice + "|" + guild_screen.notice + "|%s|%d|%s" % [str(guild_screen.is_open()),
		guild_screen.accepted_inputs, str(guild_screen.covered)] + "|%s|%d|%s|%s" % [str(quest_screen.is_open()), quest_screen.accepted_inputs,
		str(quest_screen.covered), quest_screen.notice]]
	sig += "|%d" % (story_box.page if modal.kind == "clear" else -1)  # 이야기 상자 쪽(M3 A9b, 웹 J: 쪽이 바뀐 요약)
	# 전투 띠(M3 A9b 보완, 웹 J 가 찾은 것): 못 고르는 명령의 이유 같은 알림은 단계·커서를 바꾸지 않아도 띠를 바꾼다(바뀐 띠의 요약).
	sig += "|" + "/".join(battle_layer.banner_lines().map(str)) if battle_layer.is_open() else ""
	if sig != _debug_battle_sig:
		_debug_battle_sig = sig
		_debug_dirty = true
		_debug_settle = 2
	if busy != _debug_busy:
		_debug_busy = busy
		_debug_dirty = true
	if _debug_dirty:
		# 창·배치가 바뀐 프레임에는 컨테이너 정렬이 아직이라 단추 위치가 틀릴 수 있다: 두 프레임 더 낸다.
		_debug_dirty = _debug_settle > 0
		_debug_settle = maxi(0, _debug_settle - 1)
		bridge.publish(JSON.stringify(debug_snapshot()))
		debug_publishes += 1


func _fade_toast(delta: float) -> void:
	_warn_sync(delta)  # 저장 실패 안내는 자기 시간으로 따로(일반 안내의 사라짐과 묶이지 않는다)
	if _toast_left > 0.0 and modal.is_open():
		_place_toast_by_modal()  # 창 판 크기는 컨테이너 정렬 뒤에 맞는다
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	return t


static func _local_time(utc: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(utc)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d-%02d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


# ---- 디버그 (?debug=1 일 때만 window.sqfDebug, 05 §11.3) ----

## 화면 위치(이 컨트롤 기준) → 브라우저 CSS 픽셀.
func _css(local_point: Vector2, from: CanvasItem) -> Array:
	var p := get_viewport().get_screen_transform() * from.get_global_transform_with_canvas() * local_point
	var dpr := bridge.device_pixel_ratio()
	return [snappedf(p.x / dpr, 0.1), snappedf(p.y / dpr, 0.1)]


func debug_snapshot() -> Dictionary:
	var buttons := {}
	var title := title_screen.debug_info(_css)
	if state == null:
		# 타이틀(M3 A2): 상태가 없다. 타이틀·창 단추와 저장 반영만.
		if title_screen.is_open() and not modal.is_open():
			buttons.merge(title["buttons"])
		_merge_modal_buttons(buttons)
		return {
			"hash": "", "title": title, "buttons": buttons, "modal": modal.kind, "modal_title": _modal_title(), "busy": false,
			"user_dir": OS.get_user_data_dir(),
			"autosaves": autosave_count, "epoch": _epoch, "automap": settings.automap,
			"save_pending": save_pending.is_pending(), "save_pending_gens": save_pending.generations(),
			"save_watch": save_pending.enabled, "save_reads": save_pending.reads, "save_chip": save_chip.is_visible_in_tree(),
			"set": _set_name(), "save_dir": save_dir,
		}
	var party := party_menu.debug_info(_css)
	var shop := shop_screen.debug_info(_css)
	var town := town_screen.debug_info(_css)
	var guild_info := guild_screen.debug_info(_css)
	var quest_info := quest_screen.debug_info(_css)
	if party_menu.is_open():
		buttons.merge(party["buttons"])  # 메뉴가 덮은 탐색 단추는 내지 않는다(누를 수 없다)
	elif shop_screen.is_open():
		buttons.merge(shop["buttons"])
	elif guild_screen.is_open():
		buttons.merge(guild_info["buttons"])  # 길드(M3 A7c): 마을 화면은 덮였다
	elif quest_screen.is_open():
		buttons.merge(quest_info["buttons"])  # 정보상 바·관리국(M3 A8b): 마을 화면은 덮였다
	elif town_screen.is_open():
		buttons.merge(town["buttons"])  # 마을: 탐색 HUD 는 감췄다
	else:
		for b in pad.values() + [map_button, camp_button, map_window.back_button]:
			if (b as TouchButton).is_visible_in_tree():
				buttons[b.name] = _css(b.size / 2.0, b)
		for key in toolbar.buttons:
			var tb: TouchButton = toolbar.buttons[key]
			if tb.is_visible_in_tree():
				buttons["Tool_" + key] = _css(tb.size / 2.0, tb)
		for t in map_window.icon_buttons:
			var ib: TouchButton = map_window.icon_buttons[t]
			if ib.is_visible_in_tree():
				buttons[ib.name] = _css(ib.size / 2.0, ib)
	var battle := battle_layer.debug_info(_css)
	if battle_layer.is_open() and not modal.is_open():
		buttons.merge(battle["buttons"])
	_merge_modal_buttons(buttons)
	var memo_texts := {}  # "x,y" → 글(웹 확인이 넣은 한국어 글이 그대로 저장됐는지 본다)
	for c in state.annotation.memos:
		memo_texts["%d,%d" % [c.x, c.y]] = state.annotation.memos[c]
	var map_info := {}
	if map.is_visible_in_tree():
		var o: Array = _css(map.geo.origin, map)
		var o2: Array = _css(map.geo.origin + Vector2(map.geo.cell_px, map.geo.cell_px), map)
		map_info = {"origin": o, "cell": [o2[0] - o[0], o2[1] - o[1]]}
	return {
		"hash": SaveCodec.state_hash(state), "generation": state.generation, "autosaves": autosave_count, "seed": seed_override,
		"location": state.location, "day": state.day, "town": town, "title": title, "guild_screen": guild_info, "quest_screen": quest_info,
		"floor": state.floor_def.id, "at": [state.party.at.x, state.party.at.y], "facing": state.party.facing, "steps": state.steps,
		"pending": state.encounter.pending, "wiped": state.wiped, "danger": state.encounter.danger,
		"busy": _is_busy(), "modal": modal.kind, "modal_title": _modal_title(), "modal_text": _modal_text(), "automap": settings.automap, "battle": battle,
		"materials": state.materials, "hp": state.party.members.map(func(m: PartyState.Member) -> int: return m.hp),
		"shortcuts_open": state.world.shortcuts_open.size(), "passages_found": state.world.passages_found.size(),
		"memos": state.annotation.memos.size(), "edges": state.annotation.edges.size(), "epoch": _epoch,
		"memo_texts": memo_texts,
		# 상자·잠긴 문·귀중품(M3 A3): 지금 층의 연 상자·연 문 수, 귀중품 ID(정렬), 발밑의 닫힌 상자 ID, 지금 알림 줄 글(사라졌으면 "").
		"chests_opened": state.world.chests_opened.size(), "locks_open": state.world.locks_open.size(),
		"key_items": _sorted_keys(state.key_items), "chest_here": _chest_here(),
		# 채집(M3 A5): 발밑 지점(남은 횟수가 있든 없든)과 지금 층의 오늘 쓴 횟수.
		"gather_here": _gather_here(), "gather_used": state.world.gather_used.duplicate(),
		# FOE(M3 A6c 설계 §5.7): 지금 층의 FOE [{id, kind, at, facing, state, stun, threat}](쓰러진 것도, 층 자료 차례)와
		# 미니맵이 마지막으로 그린 FOE 원 [{id, cell, color, facing, boss}](쓰러진 것은 그리지 않는다), 3D 표지 수, 표지가 보이는지(전투 중 감춤).
		"foes": _debug_foes(), "minimap_foes": minimap.foes_info(), "foe_marks": view.foe_marks().size() if _view_on else 0,
		"foe_marks_shown": view.foes_root.visible,
		# 보스(M3 A9b 설계 §5.6): 맞닿은 살아 있는 보스 id(""), 보스를 쓰러뜨린 층(정렬), 3D 표지 목록 [{id, boss, scale}], 이야기 상자(열렸을 때).
		"boss_near": FoeRules.boss_near(state), "cleared": FoeRules.cleared(state), "foe_mark_list": view.foe_mark_list() if _view_on else [],
		"story": story_box.debug_info() if modal.kind == "clear" else {},
		# 창 안 키보드 포커스 단추 이름(M3 A9b, 웹 J: 보스 물음의 처음 커서 「아니오」). 창이 없거나 포커스가 창 밖이면 "".
		"modal_focus": _modal_focus(),
		# 소모품·공용 가방(M3 A4b): 소모품 ID → 개수, 가방 칸 수(BagRules.used).
		"consumables": state.consumables, "bag_used": BagRules.used(state), "toast": _toast.text if _toast.modulate.a > 0.0 else "", "warning": warning_shown(),
		"set": _set_name(), "save_dir": save_dir,
		"user_dir": OS.get_user_data_dir(), "buttons": buttons, "map": map_info, "tool": map.tool, "map_open": _map_open, "lens_cover": view.lens_cover,
		"guard_delta": view.last_guard_delta, "guard_radius": view.guard_radius,
		"plan_ms_last": view.last_plan_ms, "plan_ms_max": view.max_plan_ms,
		# 지난 연출(끝난 연출 묶음)의 계획 횟수·누적 계획 시간, 지금까지 연출 하나의 가장 큰 누적·횟수.
		"plan_count": view.last_anim_plan_count, "plan_ms_total": view.last_anim_plan_ms,
		"plan_ms_total_max": view.max_anim_plan_ms, "plan_count_max": view.max_anim_plan_count,
		# 성장(07 §8.6): 대원마다 레벨·경험치·남은 SP·스킬·장비와 §6 묶음의 능력치·공격·방어, 가방, 파티 메뉴.
		"members": _debug_members(), "guild": _debug_guild(), "gear_bag": state.gear_bag.duplicate(), "party_menu": party,
		# 의뢰(M3 A8): 의뢰마다 표시 상태·진행·목표·보고 수·마지막 보고 날, 진행 플래그(정렬), 마지막 observe 의 의뢰 이벤트.
		"quests": _debug_quests(), "flags": SaveCodec._str_set(state.flags), "quest_events": quest_events.duplicate(true),
		# 상점(08 §8.11): 소지금·상점 상태(판 소재·한정 재고·산 물건)와 상점 화면.
		"money": state.money, "shop_state": {"sold": state.shop.sold.duplicate(), "pool": state.shop.pool.duplicate(),
			"bought": state.shop.bought_list()}, "shop": shop,
		# 웹 저장 반영(05 §8.3): IndexedDB 에 아직 없는 저장(슬롯 → generation)과 「저장 중」 표시.
		"save_pending": save_pending.is_pending(), "save_pending_gens": save_pending.generations(),
		"save_watch": save_pending.enabled, "save_reads": save_pending.reads, "save_chip": save_chip.is_visible_in_tree(),
	}


## 디버그 battle_commands 의 JSON 명령 배열: 칸마다 사전이면, 값이 유한한 정수 값 float(JSON 수)인 칸을 int 로 바꾼다.
## 소수(0.5)·참거짓·너무 큰 수·사전이 아닌 칸은 그대로 둔다(규칙 BattleRules.check_commands 가 거부한다). 배열이 아니면 그대로.
static func _json_commands(v: Variant) -> Variant:
	if typeof(v) != TYPE_ARRAY:
		return v
	var out := []
	for c in v:
		if typeof(c) != TYPE_DICTIONARY:
			out.append(c)
			continue
		var d := {}
		for k in c:
			var x: Variant = c[k]
			if typeof(x) == TYPE_FLOAT and is_finite(x) and absf(x) < 1e9 and x == floorf(x):
				x = int(x)
			d[k] = x
		out.append(d)
	return out


func _debug_foes() -> Array:
	var out := []
	if state.in_town():
		return out
	for sp in state.floor_def.foe_list():
		var fs: WorldState.FoeState = state.world.foes.get(sp.id)
		if fs == null:
			continue
		out.append({"id": sp.id, "kind": sp.kind, "at": [fs.at.x, fs.at.y], "facing": fs.facing, "state": fs.state, "stun": fs.stun,
			"threat": FoeRules.threat(state, sp.id)})
	return out


## 화면이 띄운 층 묶음: "game"(실제 미궁) · "test"(시험 층, &set=test·장면 시험) · 그 밖의 경로면 "other".
func _set_name() -> String:
	match labyrinth_path:
		LABYRINTH_PATH:
			return "game"
		TEST_LABYRINTH_PATH:
			return "test"
	return "other"


static func _sorted_keys(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(d.keys())
	out.sort()
	return out


## 발밑의 채집 지점(M3 A5): {point, kind, left, uses}. 남은 횟수가 없어도 돌려준다. 지점이 아니거나 마을이면 {}.
func _gather_here() -> Dictionary:
	if state.in_town():
		return {}
	var p := state.floor_def.point_at(state.party.at)
	if p == null:
		return {}
	return {"point": p.id, "kind": p.kind, "left": state.world.gather_left(p), "uses": p.uses}


## 발밑의 닫힌 상자 ID(없으면 "").
func _chest_here() -> String:
	if state == null or state.in_town():
		return ""
	var c := state.floor_def.chest_at(state.party.at)
	return c.id if c != null and not state.world.is_chest_opened(c.id) else ""


## 떠 있는 층 3 창의 글(제목 문패를 뺀 Label 들, 줄바꿈으로 잇는다, M3 A3: 옮김 알림 확인).
func _modal_text() -> String:
	if not modal.is_open():
		return ""
	var out: Array[String] = []
	for l in modal.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and not modal.title_plate.is_ancestor_of(l) and l != modal.title_plate:
			out.append((l as Label).text)
	return "\n".join(out)


## 창 안에서 키보드 포커스를 가진 단추 이름(스냅숏 modal_focus). 창이 없거나 포커스가 창 밖이면 "".
func _modal_focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return str(f.name) if modal.is_open() and f != null and modal.is_ancestor_of(f) else ""


## 떠 있는 층 3 창의 제목(계단·마을 문 물음을 가른다, M3 A2).
func _modal_title() -> String:
	return modal.title_plate.text if modal.is_open() else ""


func _merge_modal_buttons(buttons: Dictionary) -> void:
	if modal.is_open():
		for n in modal.find_children("*", "Control", true, false):
			if (n is Button or n is TouchButton) and n.is_visible_in_tree():
				buttons[n.name] = _css(n.size / 2.0, n)


func _debug_members() -> Array:
	var out := []
	for i in state.party.members.size():
		var m := state.party.members[i]
		var p := GrowthRules.profile(state.defs, i, m)
		out.append({"id": m.id, "name": PartyNames.display_name(texts, m), "class": m.class_id, "row": m.row, "look": m.look,
			"level": m.level, "exp": m.exp, "sp_left": GrowthRules.sp_left(state.defs, m), "skills": m.skills.duplicate(),
			"equip": Array(m.equip), "stats": p["stats"], "gear": p["gear"], "max_hp": m.max_hp, "max_tp": m.max_tp,
			"weapon": p["weapon"], "attack_element": (p["attack"] as BattleDb.SkillDef).element})
	return out


## 길드(M3 A7): 등록 번호와 파티 밖 대원(등록 차례).
func _debug_guild() -> Dictionary:
	var list := []
	for m in state.guild.members:
		list.append({"id": m.id, "name": PartyNames.display_name(texts, m), "class": m.class_id, "row": m.row, "look": m.look,
			"level": m.level, "hp": m.hp, "tp": m.tp})
	return {"serial": state.guild.serial, "members": list}


## 의뢰(M3 A8): 의뢰 ID → {giver, status, progress, target, reports, day, opens}(자료 차례).
func _debug_quests() -> Dictionary:
	var out := {}
	for id in state.defs.quests.order:
		var q: QuestDb.QuestDef = state.defs.quests.quests[id]
		var e := state.quests.entry(id)
		out[id] = {"giver": q.giver, "status": QuestRules.status_of(state, q), "progress": QuestRules.progress_of(state, q), "target": q.count,
			"reports": e.reports if e != null else 0, "day": e.day if e != null else 0, "opens": QuestRules.opens_on(state, q)}
	return out


## 디버그 진행 플래그(M3 A8, 웹 확인 D·F 의 준비 한 단계): 묶음의 의뢰가 주는 플래그 하나를 더한다(의뢰 기록·다른 보수는 그대로) → 자동 저장.
## 마을이나 미궁 어디서든, 창·전투·연출이 없을 때만. 거부: 모르는 플래그 unknown_flag, 이미 있음 already, 바쁨 busy. 받으면 {"ok": true}.
func _debug_quest_flag(flag: Variant) -> Dictionary:
	if typeof(flag) != TYPE_STRING or not state.defs.quests.knows_flag(flag):
		return {"ok": false, "reason": "unknown_flag"}
	if state.flags.has(flag):
		return {"ok": false, "reason": "already"}
	if state.wiped or state.encounter.pending or state.battle != null or modal.is_open() or _is_busy():
		return {"ok": false, "reason": "busy"}
	state.flags[flag] = true
	_autosave()
	_debug_dirty = true
	return {"ok": true}


## 연출 중(시야 이동·미리 받은 행동·전투 연출).
func _is_busy() -> bool:
	return view.is_busy() or _queued >= 0 or battle_layer.is_busy()


## 요청 JSON: {"op": "snapshot"} | {"op": "simulate", "actions": ["forward", …]} | {"op": "hash_save", "text": 저장 글}
##   | {"op": "battle_auto"} | {"op": "battle_finish"} | {"op": "supply", "item": 장비·소모품 ID(M3 A4)·소재 ID(M3 A8b), "n": 개수} | {"op": "grant_exp", "member": 칸, "n": 양}
## hash_save: 저장 글을 읽어 그 상태 해시·세대를 돌려준다(웹 확인이 IndexedDB 의 자동 저장이 화면 상태와 같은지 본다).
## simulate: 지금 상태의 복사본(저장 형식으로 옮긴 것)에서 행동열을 돌려 행동마다의 해시를 돌려준다.
## 전투 중이면 다음 행동 전에 battle_finish 와 같이 규칙의 finish(승리)로 끝낸다(전투 승패와 상관없이 같은 해시). 진짜 상태는 바꾸지 않는다.
## battle_auto: 지금 턴의 명령을 기본 정책으로 만들어 전투 층의 명령 입구로 제출한다(같은 막힘 조건·저장·연출).
## battle_finish: 전투 층의 디버그 끝내기로 규칙의 finish(승리) → 저장 → 연출 → 결과 창(「확인」은 따로 누른다).
## supply·grant_exp(07 §8.6): 파티 메뉴의 임시 보급 단추와 같은 규칙 함수(GrowthRules.supply·grant_exp) → 받아들여지면 자동 저장.
## battle_start(M3 A6c, 설계 §5.7): 지금 층의 인카운트를 바로 연다(위험도를 한계값으로 → 출현 표에서 무리 고르기 → 전투 시작, 시뮬레이션과 같다) →
##   자동 저장 → 전투 층. 탐색 중이고 창·전투·연출이 없을 때만. {"op": "battle_start"}
## battle_commands(M3 A6c): {"op": "battle_commands", "commands": [대원 칸마다 명령 또는 null]} 을 전투 층의 명령 입구로 제출한다(같은 검사·저장·연출).
##   JSON 수의 정수 값(표적 등)은 int 로 바꾼다. 명령 입력 단계에서만 받고, 규칙이 거부하면 {"ok": false, "reason", "slot"}(턴·저장은 그대로).
## quest_flag(M3 A8): {"op": "quest_flag", "flag": 진행 플래그} 그 플래그만 더한다(웹 확인 D·F 의 준비).
## quest(M3 A8): {"op": "quest", "action": accept·abandon·report, "quest": 의뢰 ID, "giver": pub·council} → quest_action. 거부면 {"ok": false, "reason"}.
##   모르는 플래그·이미 있음·바쁨은 {"ok": false, "reason"}.
## 상태를 바꾸는 요청(battle_auto·battle_finish·battle_start·battle_commands·supply·grant_exp·quest_flag·quest)은 디버그 주소(?debug=1)에서만 받는다.
## 타이틀(상태 없음)에서는 snapshot·hash_save 만 받는다. 상점은 마을 광장으로 연다(M3 A2: open_shop 요청은 없앴다).
func _on_debug_request(json_text: String) -> String:
	var req: Variant = JSON.parse_string(json_text)
	if typeof(req) != TYPE_DICTIONARY:
		return JSON.stringify({"error": "bad request"})
	match str(req.get("op", "")):
		"snapshot":
			return JSON.stringify(debug_snapshot())
		"hash_save":
			var r := SaveCodec.decode(str(req.get("text", "")), store.defs)
			if not r.ok():
				return JSON.stringify({"error": r.error})
			return JSON.stringify({"hash": SaveCodec.state_hash(r.state), "generation": r.generation})
	if state == null:
		return JSON.stringify({"error": "no state"})
	match str(req.get("op", "")):
		"simulate":
			var copy := SaveCodec.decode(SaveCodec.encode(state), store.defs)
			if not copy.ok():
				return JSON.stringify({"error": copy.error})
			var s := copy.state
			var hashes := []
			for name in req.get("actions", []):
				if not finish_battle(s):
					return JSON.stringify({"error": "battle did not end"})
				var a := ExplorationRules.action_from_name(str(name))
				if a < 0:
					return JSON.stringify({"error": "unknown action " + str(name)})
				QuestRules.observe(s, ExplorationRules.apply(s, a, settings.automap))
				hashes.append(SaveCodec.state_hash(s))
			return JSON.stringify({"hashes": hashes})
		"battle_auto", "battle_finish":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			if not battle_layer.is_open() or state.battle == null:
				return JSON.stringify({"error": "no battle"})
			var ok := false
			if req["op"] == "battle_auto":
				ok = battle_layer.handle("commands", BattlePolicy.choose(state, BattlePolicy.DEFAULT))
			else:
				ok = battle_layer.handle("finish", "victory")
			_debug_dirty = true
			return JSON.stringify({"ok": ok, "phase": battle_layer.phase})
		"battle_start":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			if state.in_town() or state.wiped or state.encounter.pending or state.battle != null or modal.is_open() or party_menu.is_open() \
					or shop_screen.is_open() or guild_screen.is_open() or quest_screen.is_open() or _is_busy():
				return JSON.stringify({"error": "cannot start"})
			state.encounter.danger = state.encounter.threshold
			var formation := BattleRules.pick_formation(state)
			var st := BattleRules.start(state, formation)
			if st[0]["type"] != "battle_start":
				return JSON.stringify({"error": str(st[0].get("reason", "rejected"))})
			_autosave()
			_check_windows()
			_debug_dirty = true
			return JSON.stringify({"ok": true, "formation": formation, "open": battle_layer.is_open()})
		"battle_commands":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			if not battle_layer.is_open() or state.battle == null:
				return JSON.stringify({"error": "no battle"})
			if battle_layer.phase != "command":
				return JSON.stringify({"error": "not command phase", "phase": battle_layer.phase})
			# JSON 의 수는 float 다: 정수 값인 칸(target 등)은 int 로 바꿔 규칙에 넘긴다(검토 R1). 소수·참거짓·범위 밖은 그대로 두어 규칙이 거부한다.
			var ok := battle_layer.handle("commands", _json_commands(req.get("commands")))
			_debug_dirty = true
			if ok and not battle_layer.last_rejected.is_empty():
				# 규칙이 거부한 제출은 턴·저장이 나아가지 않았다: ok 가 아니다(층은 「명령을 받지 못했다」를 보인다).
				var rej: Dictionary = battle_layer.last_rejected
				return JSON.stringify({"ok": false, "reason": str(rej.get("reason", "")), "slot": rej.get("slot", -1), "phase": battle_layer.phase})
			return JSON.stringify({"ok": ok, "phase": battle_layer.phase})
		"quest_flag":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			return JSON.stringify(_debug_quest_flag(req.get("flag")))
		"quest":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			var qe := quest_action(str(req.get("action", "")), str(req.get("quest", "")), str(req.get("giver", "")))
			if qe[0]["type"] == "rejected":
				return JSON.stringify({"ok": false, "reason": qe[0]["reason"]})
			return JSON.stringify({"ok": true, "events": qe})
		"supply", "grant_exp":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			var events: Array[Dictionary]
			if req["op"] == "supply":
				var item := str(req.get("item", ""))
				if state.defs.battle.materials.has(item):
					events = _debug_supply_material(item, req.get("n"))  # 소재(M3 A8b 웹 I): 디버그 요청에서만, 캠프 임시 보급은 그대로
				else:
					events = GrowthRules.supply(state, item, req.get("n"))
			else:
				var who: Variant = SaveCodec.to_int(req.get("member")) if typeof(req.get("member")) != TYPE_BOOL else null
				events = GrowthRules.grant_exp(state, who if who != null else -1, req.get("n"))
			if events.size() == 1 and events[0]["type"] == "rejected":
				return JSON.stringify({"ok": false, "reason": events[0]["reason"]})
			_autosave()
			party_menu.refresh_view()
			shop_screen.refresh_view()
			guild_screen.refresh_view()
			quest_screen.refresh_view()
			_debug_dirty = true
			return JSON.stringify({"ok": true, "events": events})
	return JSON.stringify({"error": "unknown op"})


## 디버그 supply 요청의 소재(M3 A8b, 조정자 답: 웹 I 의 이끼 수프 준비). GrowthRules.supply(캠프 임시 보급)는 소재를 받지 않으므로 이 요청에서만
## 보통 가방 규칙(BagRules.add: 종류 상한·함께 쓰는 빈 칸)으로 넣는다. 전투·전멸 중 not_now, 개수 범위 밖 bad_amount, 하나도 못 넣으면 bag_full.
func _debug_supply_material(item: String, n: Variant) -> Array[Dictionary]:
	if GrowthRules._busy(state):
		return [{"type": "rejected", "reason": "not_now"}]
	var amount: Variant = SaveCodec.to_int(n) if typeof(n) != TYPE_BOOL else null
	if not BattleLimits.in_range("bag", amount):
		return [{"type": "rejected", "reason": "bad_amount"}]
	var got := BagRules.add(state, item, amount)
	if got == 0:
		return [{"type": "rejected", "reason": "bag_full"}]
	return [{"type": "supplied", "item": item, "amount": got, "capped": got < amount}]


## 전투 중이면 battle_finish 와 같이 규칙의 finish(승리)로 끝낸다(디버그 simulate). 끝내지 못하면 false.
## 전투 끝 이벤트로 받은 의뢰도 센다(M3 A8, 진짜 화면의 전투 제출 갈고리와 같은 해시가 되게).
static func finish_battle(s: ExplorationState) -> bool:
	if not s.encounter.pending or s.battle == null:
		return true
	var events: Array[Dictionary] = []
	var ok := BattleRules.finish(s, "victory", events)
	QuestRules.observe(s, events)
	return ok


# ---- 시작 오류 (06 §5.6) ----

## 정의 데이터를 읽지 못했다: 빈 화면 대신 오류 목록을 보인다(게임은 시작하지 않는다).
func _show_start_error(errors: Array) -> void:
	# 화면을 만들지 않으므로 미리 만든 부품(트리에 넣지 않음)을 치운다.
	for n in [_floor_label, _steps_label, _toast, _warn_label, _flash, save_chip]:
		(n as Node).free()
	set_process(false)
	set_process_unhandled_input(false)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	start_error = ColorRect.new()
	start_error.name = "StartError"
	(start_error as ColorRect).color = Color(0.04, 0.05, 0.07)
	start_error.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(start_error)
	var title := Label.new()
	title.name = "StartErrorTitle"
	title.text = texts.t("msg.start_error") if texts.has("msg.start_error") else "정의 데이터를 읽지 못해 시작할 수 없다"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	title.position = Vector2(32, 24)
	start_error.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.offset_left = 32
	scroll.offset_top = 80
	scroll.offset_right = -32
	scroll.offset_bottom = -24
	start_error.add_child(scroll)
	var body := Label.new()
	body.name = "StartErrorList"
	var lines: Array[String] = []
	for e in errors:
		lines.append("- " + str(e))  # 웹 글꼴에 「•」가 없다
	body.text = "\n".join(lines)
	body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 17)
	scroll.add_child(body)


## 층 문패 판(원작 왼쪽 위 다이얼 자리): 기울어진 판만 그리고 글자는 자식 Label 이 맡는다. 장식이라 누르기를 받지 않는다.
class HudPlate:
	extends Control

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiTheme.draw_plate(self, Rect2(Vector2(-UiTheme.PLATE_SLANT, 0), size + Vector2(UiTheme.PLATE_SLANT, 0)), "", 1)
