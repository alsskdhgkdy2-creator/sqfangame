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
## 층 3 Modal 은 알림·파일 고르기·메모·전멸 창만 띄운다.
## 미리 받는 입력은 하나(나중 것이 대신)이고, 창이 열릴 때·불러올 때·포커스를 잃을 때·입력 창이 닫힌 뒤 비운다.
class_name DungeonScreen
extends Control

const FLOOR_PATH := "res://data/floors/f1_test.json"
const PARTY_PATH := "res://data/party/test_party.json"
const TEXT_PATH := "res://data/text/ko.json"
const DATA_DIR := "res://data"
## 휴식 키(06 §8.8, 물리 키). 누르고 있기 반복은 없다.
const REST_KEY := KEY_R
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
## 이동 단추 묶음(3×2 + 조사·휴식 열) 크기.
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
const SAVE_CHIP_TOP := 4.0
## 누르고 있기 반복은 누른 지 이만큼 지나야 시작한다(연출이 없는 행동 뒤 짧은 누르기가 두 번 되지 않게).
const HOLD_REPEAT_MS := 220

# ---- 시험이 트리에 넣기 전에 바꿀 수 있는 값 ----
var save_dir := "user://saves"
## 정의 데이터 경로(시험이 읽기 실패를 만들 때 바꾼다).
var floor_path := FLOOR_PATH
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

# ---- 상태 ----
var state: ExplorationState
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
var battle_layer: BattleLayer
var party_menu: PartyMenu
## 상점(08 §8, D24 임시 입구: 디버그일 때만 안내 줄 「상점」·디버그 요청 open_shop 으로 연다).
var shop_screen: ShopScreen
## 정의 읽기에 실패했을 때의 오류 화면(06 §5.6). 정상 시작이면 null.
var start_error: Control
var pad := {}  # 규칙 행동 → TouchButton
var map_button: TouchButton
## 안내 줄 「캠프」(원작 CAMP·MAP 의 CAMP).
var camp_button: TouchButton
## 안내 줄 「상점」(08 §8.1 임시 입구, 디버그 주소이거나 네이티브 디버그 실행일 때만 보인다). 마을(S4)이 생기면 없앤다.
var shop_button: TouchButton
## 휴식(06 §8.8): 층의 시작 칸에서만 보인다.
var rest_button: TouchButton
var _floor_label := Label.new()
var _steps_label := Label.new()
var _toast := Label.new()
var _toast_left := 0.0
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
var _member_names: Array[String] = []
## 지도 보기(그리기 격자·층 전체 보기·미니맵)가 마지막으로 맞춘 지도 표시와 그 판(version).
var _views_ann: MapAnnotation
var _views_version := -1
var _file_dialog: FileDialog


func _ready() -> void:
	theme = _make_theme()
	texts = TextDb.load_path(TEXT_PATH)
	var dr := GameDefs.load_paths(floor_path, party_path, data_dir, texts)
	if not dr.ok():
		push_error("정의 데이터를 읽지 못했다: %s" % "; ".join(dr.errors))
		_show_start_error(dr.errors)
		return
	floor_def = dr.defs.floor_def
	party_data = dr.defs.party
	for k in party_data.name_keys:
		_member_names.append(texts.t(k))
	settings = GameSettings.load_from(settings_path)
	store = SaveStore.new(dr.defs, save_dir)
	bridge = WebBridge.new(platform, url_query)
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
	shop_button.visible = debug_tools()
	_start()


func _start() -> void:
	var l := store.load_slot(SaveStore.AUTO)
	if l.ok():
		_set_state(l.result.state)
	else:
		_set_state(_new_state())
		_autosave()
		if l.had_candidates:
			_alert(texts.t("msg.auto_broken"))
	_check_windows()


func _new_state() -> ExplorationState:
	var seed_value := seed_override if seed_override >= 0 else ExplorationRules.fresh_seed()
	return ExplorationRules.new_game(store.defs, seed_value, settings.automap)


## 상태를 통째로 바꾼다(새 게임·불러오기·가져오기). 미리 받은 입력을 비우고 시야·지도를 다시 맞춘다.
func _set_state(s: ExplorationState) -> void:
	state = s
	_epoch += 1
	if battle_layer.is_open():
		# 다른 상태로 바뀌었다: 앞 상태의 전투 층은 알리지 않고 닫는다(새 상태의 전투는 _check_windows 가 연다).
		battle_layer.close_layer(false)
		_set_battle_view(false)
	if party_menu.is_open():
		party_menu.close_menu(false)  # 앞 상태의 초안·화면은 버린다
	if shop_screen.is_open():
		shop_screen.close_shop(false)  # 앞 상태의 상점 화면·물음은 버린다
	_clear_input()
	view.rebuild(state.world)
	view.set_pose(state.party.at, state.party.facing)
	map_window.set_state(state)
	minimap.set_state(state)
	_refresh_hud()


# ---- 행동 ----

## 화면 단추·키보드·미리 받은 입력·누르고 있기 반복이 모두 이리로 온다(05 §9.3).
## 막혀 있으면 버리고(미리 받지도 않는다). 연출 중이거나 이미 미리 받은 행동이 있으면 미리 받는 칸(하나)에 넣는다:
## 나중 입력이 미리 받은 것을 바꾸고, 행동은 늘 칸에서 꺼낸 순서로만 한다(새 요청이 칸을 앞지르지 않는다).
func request_action(action: int) -> void:
	if _input_blocked():
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
func _input_blocked() -> bool:
	return state == null or modal.is_open() or battle_layer.is_open() or party_menu.is_open() or shop_screen.is_open() \
		or not ExplorationRules.can_act(state) or map.is_interacting()


func _do_action(action: int) -> void:
	if _input_blocked():
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
	if action == A.REST:
		_pad_since.erase(A.REST)
	_action_frame = Engine.get_process_frames()
	var rebuild := false
	var slid := false
	for ev in events:
		match ev["type"]:
			"blocked":
				_show_toast(texts.t("msg." + str(ev["reason"])))
			"shortcut_opened", "passage_found":
				rebuild = true
				_show_toast(texts.t("msg." + str(ev["type"])))
			"nothing_found":
				_show_toast(texts.t("msg.nothing_found"))
			"rested":
				_show_toast(texts.t("msg.rested"))
			"damaged":
				_show_toast(texts.t("msg.damaged"))
				_flash_damage()
			"moved":
				if ev["via"] == "slide":
					slid = true
	if slid:
		_show_toast(texts.t("msg.slide"))
	# 저장 실패 안내가 위 행동 안내에 덮이지 않게 안내 뒤에 저장한다.
	_autosave()
	if rebuild:
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
	if state.wiped:
		if party_menu.is_open():
			party_menu.close_menu(false)
		if shop_screen.is_open():
			shop_screen.close_shop(false)
		if modal.kind != "wipe":
			_open_wipe()
		return true
	if state.encounter.pending:
		if not battle_layer.is_open() and not modal.is_open() and not party_menu.is_open() and not shop_screen.is_open():
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
	if shop_screen.is_open():
		return  # 상점이 키를 받는다(08 §8: 열린 동안 캠프·지도·이동은 열리거나 움직이지 않는다)
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
	if k.physical_keycode == REST_KEY and not k.ctrl_pressed and not k.alt_pressed and not k.meta_pressed:
		get_viewport().set_input_as_handled()
		request_action(A.REST)


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
		shop_button.cancel()
		rest_button.cancel()


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
		return true
	last_autosave_error = why
	if not quiet:
		_show_toast(texts.t("msg.save_failed", {"reason": why}))
	return false


func _load_slot(slot: String) -> void:
	var l := store.load_slot(slot)
	if not l.ok():
		_alert(texts.t("msg.load_failed", {"reason": l.result.error}))
		return
	modal.close()
	_set_state(l.result.state)
	if _autosave(true):
		_show_toast(texts.t("msg.loaded"))
		_check_windows()
	else:
		_alert(texts.t("msg.loaded_save_failed", {"reason": last_autosave_error}))


func _save_slot(slot: String) -> void:
	var why := store.save(slot, state)
	_note_save(slot, why.is_empty())
	if why.is_empty():
		_show_toast(texts.t("msg.saved"))
	else:
		_alert(texts.t("msg.save_failed", {"reason": why}))
		return
	party_menu.refresh_view()


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


func _start_new_game() -> void:
	modal.close()
	_set_state(_new_state())
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
	if _autosave(true):
		_show_toast(texts.t("msg.imported"))
		_check_windows()
	else:
		_alert(texts.t("msg.imported_save_failed", {"reason": last_autosave_error}))
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
	battle_layer.anim_speed = anim_speed
	battle_layer.debug = _debug
	_set_battle_view(true)
	battle_layer.open(state)


## 전투 층이 닫혔다(승리·도주 결과 창을 닫음, 또는 전멸). 탐색 화면을 되돌리고 전멸이면 전멸 창.
func _on_battle_closed(_outcome: String) -> void:
	_set_battle_view(false)
	_clear_input()
	map.refresh()
	_refresh_hud()
	_debug_dirty = true
	_check_windows()


## 전투 층이 열린 동안 HUD·지도 판을 감춘다(3D 시야는 언제나 화면 전체, 06 §9.1, M2.6 U1).
func _set_battle_view(on: bool) -> void:
	_battle_view = on
	_layout()


## 탐색 HUD(층 문패·미니맵·위험 보석·이동 단추·휴식·안내 줄)와 지도 판을 감추는지(3D 시야만 남는다).
## 전투 층이 열린 동안(06 §9.1, U1)과 파티 메뉴가 열린 동안(M2.6 2.5단계: 메뉴 뒤에는 어둡게 한 3D 시야만 보인다).
## 감춘 단추는 누르기를 받지 않는다. 파티 메뉴가 열리고 닫힐 때(어느 길로 닫혀도: 키·「닫기」·상태 바꾸기) visibility_changed 로 다시 맞춘다.
func _hud_hidden() -> bool:
	return _battle_view or (party_menu != null and party_menu.is_open()) or (shop_screen != null and shop_screen.is_open())


## 전투 층 저장 갈고리(제출 결과가 정해진 직후, 연출 전).
func _on_battle_save() -> void:
	_autosave()


## 캠프를 연다(07 §9.1): 전투·전멸이 아니고, 다른 창(메뉴·메모·파일 고르기·전멸·전투)이 없고, 연출 중이 아닐 때만.
## 열 때마다 캠프 뿌리(명령 커서 0, 대원 칸 0)에서 시작한다. 임시 보급은 디버그 주소이거나 네이티브 디버그 실행일 때만 보인다(07 §5.7).
func _open_party() -> void:
	if state == null or party_menu.is_open() or shop_screen.is_open() or battle_layer.is_open() or modal.is_open() or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	party_menu.debug = debug_tools()
	party_menu.open(state)


## 파티 메뉴가 닫혔다: 눌림·미리 받은 입력을 버리고(닫은 뒤 누르고 있던 이동 키가 걸음이 되지 않는다) 탐색 화면을 다시 맞춘다.
func _on_party_closed() -> void:
	_clear_input()
	_refresh_hud()
	_debug_dirty = true
	_debug_settle = 2
	_check_windows()


## 파티 메뉴 저장 갈고리(배분 확정·장착 변경·임시 보급이 받아들여진 직후).
func _on_party_save() -> void:
	_autosave()


## 디버그 도구(캠프 임시 보급·상점 임시 입구)를 보이는지: 디버그 주소이거나 네이티브 디버그 실행(07 §5.7, 08 §8.1).
func debug_tools() -> bool:
	return _debug or (native_debug and not bridge.is_web())


## 상점을 연다(08 §8.1): 캠프와 같은 조건(전투·전투 대기·전멸이 아니고, 다른 창이 없고, 연출 중이 아님)에 디버그일 때만.
## 열 때마다 뿌리·명령 커서 0·대원 0에서 시작한다.
func _open_shop() -> void:
	if state == null or not debug_tools() or shop_screen.is_open() or party_menu.is_open() or battle_layer.is_open() or modal.is_open() \
			or state.encounter.pending:
		return
	if not ExplorationRules.can_act(state) or _is_busy() or map.is_interacting():
		return
	shop_screen.open(state)


## 상점이 닫혔다: 캠프를 닫을 때와 같은 길(눌림·미리 받은 입력을 버리고 탐색 화면을 다시 맞춘다).
func _on_shop_closed() -> void:
	_on_party_closed()


## 상점 저장 갈고리(사기·장착이 받아들여진 직후). 실패하면 탐색 화면의 실패 토스트만 띄우고 상점은 차례를 이어 간다(08 §8.11 F6).
func _on_shop_save() -> void:
	_autosave()


func _open_wipe() -> void:
	var rows: Array[Control] = [ModalLayer.label(texts.t("msg.wiped"))]
	var slot := store.latest_manual()
	if not slot.is_empty():
		var load_b := ModalLayer.button(texts.t("wipe.load_manual"), _load_slot.bind(slot))
		load_b.name = "WipeLoad"
		rows.append(load_b)
	var new_b := ModalLayer.button(texts.t("wipe.new_game"), _start_new_game)
	new_b.name = "WipeNewGame"
	rows.append(new_b)
	modal.open("wipe", texts.t("wipe.title"), rows)


## 캠프 「기록」 화면의 슬롯 카드 값(07 §9.2): 검사를 지난 저장이면 대표 대원(파티 칸 0)·Lv, 층 · 걸음, 저장 시각(저장에 이미 있는 값).
func record_slots() -> Array:
	var out := []
	for slot in SaveStore.MANUAL_SLOTS:
		var l := store.load_slot(slot)
		if not l.ok():
			out.append({"slot": slot, "ok": false})
			continue
		var st := l.result.state
		out.append({"slot": slot, "ok": true, "leader": texts.t(st.defs.party.name_keys[0]),
			"level": texts.t("party.level", {"level": st.party.members[0].level}),
			"where": texts.t("menu.slot_where", {"floor": texts.t(st.floor_def.name_key), "steps": st.steps}),
			"time": _local_time(l.result.saved_at)})
	return out


func _set_automap(mode: String) -> void:
	if settings.set_automap(mode):
		settings.save_to(settings_path)
	party_menu.refresh_view()


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
	edit.custom_minimum_size = Vector2(420, 52)
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

	hud_root = _layer_root("Hud", LAYER_HUD)
	windows_root = _layer_root("Windows", LAYER_WINDOWS)
	var toast_root := _layer_root("Toast", LAYER_TOAST)
	_build_hud()

	# 층 2: 지도 판 → 전투 층 → 파티 메뉴(트리 순서 = 그리는·누르는 순서).
	map_window = MapWindow.new()
	map_window.name = "MapWindow"
	windows_root.add_child(map_window)
	map_window.build(texts, texts.t(floor_def.name_key))
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
	battle_layer.blocked_hook = func() -> bool: return modal.is_open()
	battle_layer.closed.connect(_on_battle_closed)
	battle_layer.opened.connect(func() -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	battle_layer.submitted.connect(func(_e: Array) -> void: _debug_dirty = true)
	party_menu = PartyMenu.new()
	party_menu.name = "PartyMenu"
	windows_root.add_child(party_menu)
	party_menu.build(texts)
	party_menu.save_hook = _on_party_save
	party_menu.records = {"slots": record_slots, "save": _save_slot, "load": _load_slot, "export": _export, "import": _import,
		"automap": func() -> String: return settings.automap, "set_automap": _set_automap, "new_game": _start_new_game}
	party_menu.blocked_hook = func() -> bool: return modal.is_open()
	party_menu.opened.connect(func() -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	party_menu.closed.connect(_on_party_closed)
	party_menu.visibility_changed.connect(_layout)
	party_menu.changed.connect(func(_e: Array) -> void: _debug_dirty = true)
	shop_screen = ShopScreen.new()
	shop_screen.name = "ShopScreen"
	windows_root.add_child(shop_screen)
	shop_screen.build(texts)
	shop_screen.save_hook = _on_shop_save
	shop_screen.blocked_hook = func() -> bool: return modal.is_open()
	shop_screen.opened.connect(func() -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	shop_screen.closed.connect(_on_shop_closed)
	shop_screen.visibility_changed.connect(_layout)
	shop_screen.changed.connect(func(_e: Array) -> void: _debug_dirty = true)

	# 층 3: 창(메뉴·알림·메모·전멸). ModalLayer 가 화면 전체 뿌리다.
	var modal_cl := CanvasLayer.new()
	modal_cl.name = "Modal"
	modal_cl.layer = LAYER_MODAL
	add_child(modal_cl)
	layers["Modal"] = modal_cl
	modal = ModalLayer.new()
	modal.name = "ModalLayer"
	modal.theme = theme
	modal.opened.connect(func(_k: String) -> void:
		_clear_input()
		party_menu.cancel_pointers()  # 캠프에서 누르고 있던 단추는 창이 덮은 뒤 떼도 일하지 않는다
		battle_layer.cancel_pointers()  # 전투도 같다(명령 줄·카드·키패드 등)
		shop_screen.cancel_pointers()  # 상점도 같다(08 §8.11: 눌린 「예」를 창이 덮으면 뗄 때 사지 않는다)
		_debug_dirty = true
		_debug_settle = 2)
	modal.closed.connect(func(_k: String) -> void:
		_clear_input()  # 창 안에서 누른 키·단추는 닫힌 뒤에도 승인되지 않는다
		party_menu.cancel_pointers()  # 창이 뜨기 전부터 캠프에서 누르고 있던 손가락도(다른 손가락으로 창을 닫은 뒤 떼기)
		battle_layer.cancel_pointers()
		shop_screen.cancel_pointers()
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
	toast_area.add_child(_toast)
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
## 미니맵·위험 보석·층 문패는 장식(IGNORE). 이동 단추·조사·휴식은 원작에 없다(휴대폰 조작): 안내 줄 바로 위에 둔다.
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
	_floor_label.text = texts.t(floor_def.name_key)
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
	shop_button = TouchButton.new().setup("", texts.t("shop.hud"))
	shop_button.name = "ShopButton"
	shop_button.activated.connect(_open_shop)
	shop_button.visible = false  # 디버그 여부는 _ready 가 정한다
	for b in [camp_button, map_button, shop_button]:
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
	rest_button = TouchButton.new().setup("", texts.t("action.rest"))
	rest_button.name = "Pad_rest"
	rest_button.activated.connect(_on_pad.bind(A.REST))
	rest_button.released.connect(func() -> void: _pad_since.erase(A.REST))
	rest_button.position = Vector2(side_x, 0)
	rest_button.size = Vector2(PAD_BUTTON + 16.0, PAD_BUTTON)
	pad_box.add_child(rest_button)


## 모드(지도 판 열림·전투·파티 메뉴)와 화면 폭에 따라 바뀌는 것만 맞춘다. 자리는 앵커가 정하고 여기서는
## 앵커로 나타낼 수 없는 것만 한다: 시야 영역·알림 영역의 오른쪽 여백(지도 판 폭), 알림 줄 자리(탐색 ↔ 전투), 보이기,
## 렌즈 이동 비율(판 폭 / 화면 폭). 3D 시야(ViewContainer)는 건드리지 않는다.
func _layout() -> void:
	if view_container == null:
		return
	var w := get_viewport_rect().size.x
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
	if _battle_view:
		# 전투 중: 전투 층 메시지 띠 아래 · 적 영역 위, 명령 목록 오른쪽(BattleLayer.TOAST_Y·TOAST_LEFT) ~ 오른쪽 − TOAST_RIGHT.
		toast_area.offset_right = 0.0
		_toast.set_anchors_preset(PRESET_TOP_WIDE)
		_toast.offset_left = BattleLayer.TOAST_LEFT
		_toast.offset_right = -BattleLayer.TOAST_RIGHT
		_toast.offset_top = BattleLayer.TOAST_Y
		_toast.offset_bottom = BattleLayer.TOAST_Y + BattleLayer.TOAST_H
	else:
		# 탐색: 시야 영역 아래쪽, 이동 단추 묶음 바로 위.
		toast_area.offset_right = -cover
		_toast.set_anchors_preset(PRESET_BOTTOM_WIDE)
		_toast.offset_left = 0.0
		_toast.offset_right = 0.0
		_toast.offset_bottom = -EDGE - HINT_H - HINT_GAP - PAD_H - 10.0
		_toast.offset_top = _toast.offset_bottom - 36.0
	view.set_lens_cover(cover / w if w > 0.0 else 0.0)
	_refresh_rest_button()
	map.refresh()
	_debug_dirty = true
	_debug_settle = 2


## 덮이지 않은 시야 영역(화면 좌표). 지도 판이 열리면 판 왼쪽까지.
func view_area_rect() -> Rect2:
	var s := get_viewport_rect().size
	var cover := MapWindow.WIDTH if _map_open and not _hud_hidden() else 0.0
	return Rect2(Vector2.ZERO, Vector2(s.x - cover, s.y))


func _refresh_hud() -> void:
	_steps_label.text = texts.t("hud.steps", {"steps": state.steps})
	orb.gauge = state.encounter.gauge()
	minimap.refresh()
	_refresh_rest_button()
	_refresh_toolbar()


## 휴식 단추는 층의 시작 칸에서, 전투·전멸이 아닐 때만 보인다(06 §8.8).
func _refresh_rest_button() -> void:
	if rest_button == null:
		return
	var show := not _hud_hidden() and state != null and ExplorationRules.can_act(state) and state.party.at == floor_def.start_at
	if rest_button.visible != show:
		rest_button.visible = show
		if not show:
			rest_button.cancel()
		_debug_dirty = true


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 2.0


func _flash_damage() -> void:
	_flash.color.a = 0.35


func _process(delta: float) -> void:
	if state == null:
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
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
	save_pending.tick(delta)
	if save_chip.visible and save_chip.modulate.a < 1.0:
		save_chip.modulate.a = minf(1.0, save_chip.modulate.a + delta / 0.15)
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)
	if _debug:
		var busy := _is_busy()
		# 전투 층·파티 메뉴가 입력을 받으면 상태 요약을 다시 낸다(메뉴 안 탭·초안·확인 창도 요약에 있다).
		var sig := "%s/%s/%d/%s/%s/%d/%s/%d" % [battle_layer.phase, battle_layer.sub, battle_layer.member, str(battle_layer.log_view.visible),
			str(party_menu.is_open()), party_menu.accepted_inputs, str(shop_screen.is_open()), shop_screen.accepted_inputs]
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
	var party := party_menu.debug_info(_css)
	var shop := shop_screen.debug_info(_css)
	if party_menu.is_open():
		buttons.merge(party["buttons"])  # 메뉴가 덮은 탐색 단추는 내지 않는다(누를 수 없다)
	elif shop_screen.is_open():
		buttons.merge(shop["buttons"])
	else:
		for b in pad.values() + [rest_button, map_button, camp_button, shop_button, map_window.back_button]:
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
	if modal.is_open():
		for n in modal.find_children("*", "Control", true, false):
			if (n is Button or n is TouchButton) and n.is_visible_in_tree():
				buttons[n.name] = _css(n.size / 2.0, n)
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
		"at": [state.party.at.x, state.party.at.y], "facing": state.party.facing, "steps": state.steps,
		"pending": state.encounter.pending, "wiped": state.wiped, "danger": state.encounter.danger,
		"busy": _is_busy(), "modal": modal.kind, "automap": settings.automap, "battle": battle,
		"materials": state.materials, "hp": state.party.members.map(func(m: PartyState.Member) -> int: return m.hp),
		"shortcuts_open": state.world.shortcuts_open.size(), "passages_found": state.world.passages_found.size(),
		"memos": state.annotation.memos.size(), "edges": state.annotation.edges.size(), "epoch": _epoch,
		"memo_texts": memo_texts,
		"user_dir": OS.get_user_data_dir(), "buttons": buttons, "map": map_info, "tool": map.tool, "map_open": _map_open, "lens_cover": view.lens_cover,
		"guard_delta": view.last_guard_delta, "guard_radius": view.guard_radius,
		"plan_ms_last": view.last_plan_ms, "plan_ms_max": view.max_plan_ms,
		# 지난 연출(끝난 연출 묶음)의 계획 횟수·누적 계획 시간, 지금까지 연출 하나의 가장 큰 누적·횟수.
		"plan_count": view.last_anim_plan_count, "plan_ms_total": view.last_anim_plan_ms,
		"plan_ms_total_max": view.max_anim_plan_ms, "plan_count_max": view.max_anim_plan_count,
		# 성장(07 §8.6): 대원마다 레벨·경험치·남은 SP·스킬·장비와 §6 묶음의 능력치·공격·방어, 가방, 파티 메뉴.
		"members": _debug_members(), "gear_bag": state.gear_bag.duplicate(), "party_menu": party,
		# 상점(08 §8.11): 소지금·상점 상태(판 소재·한정 재고·산 물건)와 상점 화면.
		"money": state.money, "shop_state": {"sold": state.shop.sold.duplicate(), "pool": state.shop.pool.duplicate(),
			"bought": state.shop.bought_list()}, "shop": shop,
		# 웹 저장 반영(05 §8.3): IndexedDB 에 아직 없는 저장(슬롯 → generation)과 「저장 중」 표시.
		"save_pending": save_pending.is_pending(), "save_pending_gens": save_pending.generations(),
		"save_watch": save_pending.enabled, "save_reads": save_pending.reads, "save_chip": save_chip.is_visible_in_tree(),
	}


func _debug_members() -> Array:
	var out := []
	for i in state.party.members.size():
		var m := state.party.members[i]
		var p := GrowthRules.profile(state.defs, i, m)
		out.append({"level": m.level, "exp": m.exp, "sp_left": GrowthRules.sp_left(state.defs, m), "skills": m.skills.duplicate(),
			"equip": Array(m.equip), "stats": p["stats"], "gear": p["gear"], "max_hp": m.max_hp, "max_tp": m.max_tp,
			"weapon": p["weapon"], "attack_element": (p["attack"] as BattleDb.SkillDef).element})
	return out


## 연출 중(시야 이동·미리 받은 행동·전투 연출).
func _is_busy() -> bool:
	return view.is_busy() or _queued >= 0 or battle_layer.is_busy()


## 요청 JSON: {"op": "snapshot"} | {"op": "simulate", "actions": ["forward", …]} | {"op": "hash_save", "text": 저장 글}
##   | {"op": "battle_auto"} | {"op": "battle_finish"} | {"op": "supply", "item": 장비 ID, "n": 개수} | {"op": "grant_exp", "member": 칸, "n": 양}
## hash_save: 저장 글을 읽어 그 상태 해시·세대를 돌려준다(웹 확인이 IndexedDB 의 자동 저장이 화면 상태와 같은지 본다).
## simulate: 지금 상태의 복사본(저장 형식으로 옮긴 것)에서 행동열을 돌려 행동마다의 해시를 돌려준다.
## 전투 중이면 다음 행동 전에 battle_finish 와 같이 규칙의 finish(승리)로 끝낸다(전투 승패와 상관없이 같은 해시). 진짜 상태는 바꾸지 않는다.
## battle_auto: 지금 턴의 명령을 기본 정책으로 만들어 전투 층의 명령 입구로 제출한다(같은 막힘 조건·저장·연출).
## battle_finish: 전투 층의 디버그 끝내기로 규칙의 finish(승리) → 저장 → 연출 → 결과 창(「확인」은 따로 누른다).
## supply·grant_exp(07 §8.6): 파티 메뉴의 임시 보급 단추와 같은 규칙 함수(GrowthRules.supply·grant_exp) → 받아들여지면 자동 저장.
## open_shop(08 §8.1): 안내 줄 「상점」과 같은 길(_open_shop)로 상점을 연다. 디버그 주소에서만.
## 상태를 바꾸는 이 네 요청은 디버그 주소(?debug=1)에서만 받는다.
func _on_debug_request(json_text: String) -> String:
	var req: Variant = JSON.parse_string(json_text)
	if typeof(req) != TYPE_DICTIONARY:
		return JSON.stringify({"error": "bad request"})
	match str(req.get("op", "")):
		"snapshot":
			return JSON.stringify(debug_snapshot())
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
				ExplorationRules.apply(s, a, settings.automap)
				hashes.append(SaveCodec.state_hash(s))
			return JSON.stringify({"hashes": hashes})
		"hash_save":
			var r := SaveCodec.decode(str(req.get("text", "")), store.defs)
			if not r.ok():
				return JSON.stringify({"error": r.error})
			return JSON.stringify({"hash": SaveCodec.state_hash(r.state), "generation": r.generation})
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
		"supply", "grant_exp":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			var events: Array[Dictionary]
			if req["op"] == "supply":
				events = GrowthRules.supply(state, str(req.get("item", "")), req.get("n"))
			else:
				var who: Variant = SaveCodec.to_int(req.get("member")) if typeof(req.get("member")) != TYPE_BOOL else null
				events = GrowthRules.grant_exp(state, who if who != null else -1, req.get("n"))
			if events.size() == 1 and events[0]["type"] == "rejected":
				return JSON.stringify({"ok": false, "reason": events[0]["reason"]})
			_autosave()
			party_menu.refresh_view()
			shop_screen.refresh_view()
			_debug_dirty = true
			return JSON.stringify({"ok": true, "events": events})
		"open_shop":
			if not _debug:
				return JSON.stringify({"error": "debug only"})
			_open_shop()
			_debug_dirty = true
			return JSON.stringify({"ok": shop_screen.is_open()})
	return JSON.stringify({"error": "unknown op"})


## 전투 중이면 battle_finish 와 같이 규칙의 finish(승리)로 끝낸다(디버그 simulate). 끝내지 못하면 false.
static func finish_battle(s: ExplorationState) -> bool:
	if not s.encounter.pending or s.battle == null:
		return true
	return BattleRules.finish(s, "victory")


# ---- 시작 오류 (06 §5.6) ----

## 정의 데이터를 읽지 못했다: 빈 화면 대신 오류 목록을 보인다(게임은 시작하지 않는다).
func _show_start_error(errors: Array) -> void:
	# 화면을 만들지 않으므로 미리 만든 부품(트리에 넣지 않음)을 치운다.
	for n in [_floor_label, _steps_label, _toast, _flash, save_chip]:
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
