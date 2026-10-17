## 미궁 탐색 화면(주 장면, 05 §9). 탐색 상태를 가지고 규칙 함수로만 바꾼다. 시야·지도·상태 표시는 읽기만 한다.
## 자동 저장(05 §8.4): 거부되지 않은 규칙 행동, 지도 편집 한 단계·실행 취소, 전투 해결, 새 게임, 수동 슬롯 불러오기,
## 가져오기 직후. 저장 쓰기는 한 프레임 안에서 끝낸다(웹 IndexedDB 반영, 05 §8.3).
## 입력(05 §9.3): 키보드는 _unhandled_input, 화면 단추는 TouchButton. 창이 열려 있거나 전투 대기·전멸이면 이동을 받지 않는다.
## 미리 받는 입력은 하나(나중 것이 대신)이고, 창이 열릴 때·불러올 때·포커스를 잃을 때·입력 창이 닫힌 뒤 비운다.
class_name DungeonScreen
extends Control

const FLOOR_PATH := "res://data/floors/f1_test.json"
const PARTY_PATH := "res://data/party/test_party.json"
const TEXT_PATH := "res://data/text/ko.json"
const A := ExplorationRules.Action
## InputMap 동작 → 규칙 행동. 누르고 있으면 반복하는 순서이기도 하다.
const KEY_ACTIONS := {
	"move_forward": A.FORWARD, "move_back": A.BACK, "strafe_left": A.STRAFE_LEFT, "strafe_right": A.STRAFE_RIGHT,
	"turn_left": A.TURN_LEFT, "turn_right": A.TURN_RIGHT, "investigate": A.INVESTIGATE,
}
## 누르고 있으면 반복하는 행동(조사는 반복하지 않는다).
const REPEATABLE := [A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT, A.TURN_LEFT, A.TURN_RIGHT]
const PAD_BUTTON := 80.0
const PAD_GAP := 8.0
const TOP_BAR := 64.0
const SIDE_COLLAPSED := 300.0
const STATUS_H := 190.0
const PROMPT_BLOCKED_MS := 40
## 누르고 있기 반복은 누른 지 이만큼 지나야 시작한다(연출이 없는 행동 뒤 짧은 누르기가 두 번 되지 않게).
const HOLD_REPEAT_MS := 220

# ---- 시험이 트리에 넣기 전에 바꿀 수 있는 값 ----
var save_dir := "user://saves"
## 시험용: "export_write"·"import_read" 가 들어 있으면 네이티브 내보내기 쓰기·가져오기 읽기 뒤 오류가 난 것처럼 한다.
var file_fail_points: Array[String] = []
var settings_path := GameSettings.PATH
## "" = 실제 플랫폼, "web"·"native" = 그렇게 본다.
var platform := ""
## 0 이상이면 새 게임 시드로 쓴다.
var seed_override := -1
var anim_speed := 1.0

# ---- 상태 ----
var state: ExplorationState
var floor_def: FloorModel
var party_data: PartyData
var texts: TextDb
var settings: GameSettings
var store: SaveStore
var bridge: WebBridge
## 자동 저장에 성공한 횟수와 마지막 실패 이유(시험·디버그용).
var autosave_count := 0
var last_autosave_error := ""

# ---- 화면 부품 ----
var view: DungeonView
var view_container: SubViewportContainer
var map: MapPanel
var toolbar: MapToolbar
var status: StatusPanel
var modal: ModalLayer
var pad := {}  # 규칙 행동 → TouchButton
var map_button: TouchButton
var menu_button: TouchButton
var _floor_label := Label.new()
var _steps_label := Label.new()
var _toast := Label.new()
var _toast_left := 0.0
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
var _map_open := true
var _debug := false
var _debug_dirty := false
var _debug_busy := false
var _debug_settle := 0
var _member_names: Array[String] = []
var _file_dialog: FileDialog


func _ready() -> void:
	theme = _make_theme()
	texts = TextDb.load_path(TEXT_PATH)
	var fr := FloorLoader.load_path(FLOOR_PATH)
	if not fr.ok():
		push_error("층 정의를 읽지 못했다: %s" % "; ".join(fr.errors))
		return
	floor_def = fr.floor_def
	party_data = PartyData.load_path(PARTY_PATH)
	for k in party_data.name_keys:
		_member_names.append(texts.t(k))
	settings = GameSettings.load_from(settings_path)
	store = SaveStore.new(floor_def, party_data.make_members(), save_dir)
	bridge = WebBridge.new(platform)
	bridge.on_import = _on_import_result
	_build_ui()
	_start()
	if bridge.debug_requested():
		_debug = true
		bridge.on_debug_request = _on_debug_request
		bridge.setup_debug()
		_debug_dirty = true


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
	return ExplorationRules.new_game(floor_def, party_data.make_members(), seed_value, settings.automap)


## 상태를 통째로 바꾼다(새 게임·불러오기·가져오기). 미리 받은 입력을 비우고 시야·지도를 다시 맞춘다.
func _set_state(s: ExplorationState) -> void:
	state = s
	_epoch += 1
	_clear_input()
	view.rebuild(state.world)
	view.set_pose(state.party.at, state.party.facing)
	map.set_state(state)
	status.set_state(state, texts, _member_names)
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


## 행동을 받지 않는 조건: 상태 없음, 창(메뉴·전투·전멸·메모·파일 고르기 등)이 열림, 전투 대기·전멸,
## 지도에서 진행 중인 상호작용(그리기 획·끌어 이동·핀치·아이콘·메모 누르기).
func _input_blocked() -> bool:
	return state == null or modal.is_open() or not ExplorationRules.can_act(state) or map.is_interacting()


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
	status.refresh()
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


## 전멸·전투 대기면 그 창을 띄운다(이미 떠 있으면 그대로). 띄웠으면 true.
func _check_windows() -> bool:
	if state.wiped:
		if modal.kind != "wipe":
			_open_wipe()
		return true
	if state.encounter.pending:
		if modal.kind != "battle":
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
	if event.is_action_pressed("open_menu"):
		get_viewport().set_input_as_handled()
		if modal.kind == "menu" or modal.kind == "icons":
			modal.close()
		elif not modal.is_open():
			_open_menu()
		return
	if modal.is_open():
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
	if toolbar != null:
		toolbar.cancel_all()
	if map != null:
		map.cancel_input()
	if map_button != null:
		map_button.cancel()
		menu_button.cancel()


# ---- 저장 ----

## 자동 저장. 성공하면 true. 실패하면 quiet 가 아닐 때 실패 안내를 띄운다(호출자는 이 뒤에 다른 안내를 덮지 않는다).
## 지도 획이 열려 있으면(지도 표시에 확정하지 않은 획이 들어 있다) 저장하지 않고 획이 닫힌 뒤로 미룬다.
func _autosave(quiet: bool = false) -> bool:
	if map != null and map.is_stroking():
		_autosave_pending = true
		return true
	_autosave_pending = false
	var why := store.save(SaveStore.AUTO, state)
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
	if why.is_empty():
		_show_toast(texts.t("msg.saved"))
	else:
		_alert(texts.t("msg.save_failed", {"reason": why}))
		return
	_open_menu()


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
	var r := SaveCodec.decode(text, floor_def, party_data.make_members())
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
	var win := ModalLayer.button(texts.t("battle.win"), _resolve_battle)
	win.name = "BattleWin"
	var rows: Array[Control] = [ModalLayer.label(texts.t("msg.encounter")), win]
	modal.open("battle", texts.t("battle.title"), rows)


func _resolve_battle() -> void:
	if not ExplorationRules.resolve_battle(state):
		return
	_autosave()
	modal.close()
	status.refresh()
	_refresh_hud()


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


func _open_menu() -> void:
	var save_row: Array[Control] = []
	var load_row: Array[Control] = []
	for i in SaveStore.MANUAL_SLOTS.size():
		var slot: String = SaveStore.MANUAL_SLOTS[i]
		var info := store.slot_info(slot)
		var when := _local_time(info.saved_at) if info.ok else texts.t("menu.empty_slot")
		var label := "%s\n%s" % [texts.t("menu.slot", {"n": i + 1}), when]
		var sb := ModalLayer.button(label, _save_slot.bind(slot))
		sb.name = "Save_" + slot
		sb.custom_minimum_size = Vector2(170, 64)
		sb.add_theme_font_size_override("font_size", 16)
		save_row.append(sb)
		var lb := ModalLayer.button(label, _load_slot.bind(slot), info.ok)
		lb.name = "Load_" + slot
		lb.custom_minimum_size = Vector2(170, 64)
		lb.add_theme_font_size_override("font_size", 16)
		load_row.append(lb)
	var auto_row: Array[Control] = []
	for mode in ExplorationRules.AUTOMAP_MODES:
		var mark := "● " if settings.automap == mode else ""
		var ab := ModalLayer.button(mark + texts.t("menu.automap." + mode), _set_automap.bind(mode))
		ab.name = "Automap_" + mode
		ab.custom_minimum_size = Vector2(150, 56)
		auto_row.append(ab)
	var export_b := ModalLayer.button(texts.t("menu.export"), _export)
	export_b.name = "Export"
	var import_b := ModalLayer.button(texts.t("menu.import"), _import)
	import_b.name = "Import"
	var new_b := ModalLayer.button(texts.t("menu.new_game"), _confirm_new_game)
	new_b.name = "NewGame"
	var close_b := ModalLayer.button(texts.t("menu.close"), modal.close)
	close_b.name = "Close"
	var rows: Array[Control] = [
		ModalLayer.label(texts.t("menu.save")), ModalLayer.row(save_row),
		ModalLayer.label(texts.t("menu.load")), ModalLayer.row(load_row),
		ModalLayer.row([export_b, import_b] as Array[Control]),
		ModalLayer.label(texts.t("menu.automap")), ModalLayer.row(auto_row),
		ModalLayer.row([new_b, close_b] as Array[Control]),
	]
	modal.open("menu", texts.t("menu.title"), rows)


func _set_automap(mode: String) -> void:
	if settings.set_automap(mode):
		settings.save_to(settings_path)
	_open_menu()


func _confirm_new_game() -> void:
	var yes := ModalLayer.button(texts.t("menu.new_game"), _start_new_game)
	yes.name = "ConfirmNewGame"
	var no := ModalLayer.button(texts.t("ui.cancel"), _open_menu)
	no.name = "ConfirmCancel"
	var rows: Array[Control] = [ModalLayer.label(texts.t("menu.confirm_new_game")), ModalLayer.row([yes, no] as Array[Control])]
	modal.open("confirm", texts.t("menu.new_game"), rows)


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


func _open_icon_picker() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for t in MapAnnotation.ICONS:
		var b := TouchButton.new().setup(t, texts.t("icon." + t))
		b.name = "Icon_" + t
		b.custom_minimum_size = Vector2(96, 80)
		b.selected = t == map.icon_type and map.tool == "icon"
		b.activated.connect(func() -> void:
			map.icon_type = t
			_choose_tool("icon", 0)
			modal.close())
		grid.add_child(b)
	var rows: Array[Control] = [grid, _named(ModalLayer.button(texts.t("ui.cancel"), modal.close), "IconCancel")]
	modal.open("icons", texts.t("map.icon_title"), rows)


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


func _choose_tool(tool: String, color: int) -> void:
	map.tool = tool
	if tool == "color":
		map.paint_color = color
	_refresh_toolbar()


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
		"icon_picker":
			_open_icon_picker()


func _refresh_toolbar() -> void:
	toolbar.show_current(map.tool, map.paint_color, map.icon_type, state != null and state.annotation.can_undo())
	_debug_dirty = true


func _toggle_map() -> void:
	_map_open = not _map_open
	map.cancel_input()
	_layout()


# ---- 화면 구성 ----

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	view_container = SubViewportContainer.new()
	view_container.set_script(preload("res://src/game/dungeon/view_container.gd"))
	view_container.name = "ViewContainer"
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

	_flash.color = Color(1, 0.1, 0.05, 0.0)
	_flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_flash)

	_floor_label.text = texts.t(floor_def.name_key)
	_floor_label.add_theme_font_size_override("font_size", 22)
	_floor_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_floor_label.add_theme_constant_override("outline_size", 6)
	add_child(_floor_label)
	_steps_label.add_theme_font_size_override("font_size", 18)
	_steps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_steps_label.add_theme_constant_override("outline_size", 6)
	add_child(_steps_label)
	map_button = TouchButton.new().setup("map", texts.t("map.toggle"))
	map_button.name = "MapButton"
	map_button.activated.connect(_toggle_map)
	add_child(map_button)
	menu_button = TouchButton.new().setup("menu", "")
	menu_button.name = "MenuButton"
	menu_button.activated.connect(_open_menu)
	add_child(menu_button)

	var pad_defs := [
		[A.TURN_LEFT, "turn_left", ""], [A.FORWARD, "up", ""], [A.TURN_RIGHT, "turn_right", ""],
		[A.STRAFE_LEFT, "strafe_left", ""], [A.BACK, "down", ""], [A.STRAFE_RIGHT, "strafe_right", ""],
		[A.INVESTIGATE, "investigate", texts.t("action.investigate")],
	]
	for d in pad_defs:
		var b := TouchButton.new().setup(d[1], d[2], true)
		b.name = "Pad_" + ExplorationRules.ACTION_NAMES.find_key(d[0])
		b.activated.connect(_on_pad.bind(d[0]))
		b.released.connect(func() -> void: _pad_since.erase(d[0]))  # 떼거나 취소하면 그 단추의 승인을 지운다
		add_child(b)
		pad[d[0]] = b

	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_toast)

	toolbar = MapToolbar.new()
	toolbar.name = "MapToolbar"
	toolbar.build(texts)
	toolbar.tool_chosen.connect(_choose_tool)
	toolbar.action.connect(_on_toolbar_action)
	add_child(toolbar)
	map = MapPanel.new()
	map.name = "MapPanel"
	map.edited.connect(_on_map_edited)
	map.memo_requested.connect(_on_memo_requested)
	map.view_changed.connect(func() -> void: _debug_dirty = true)
	add_child(map)
	status = StatusPanel.new()
	status.name = "StatusPanel"
	add_child(status)

	modal = ModalLayer.new()
	modal.name = "ModalLayer"
	modal.opened.connect(func(_k: String) -> void:
		_clear_input()
		_debug_dirty = true
		_debug_settle = 2)
	modal.closed.connect(func(_k: String) -> void:
		_clear_input()  # 창 안에서 누른 키·단추는 닫힌 뒤에도 승인되지 않는다
		_debug_dirty = true
		_debug_settle = 2)
	add_child(modal)
	_layout()


func _layout() -> void:
	if view_container == null:
		return
	var s := size
	if s.x <= 0.0:
		s = get_viewport_rect().size
	var side_w := roundf(s.x * 0.4) if _map_open else SIDE_COLLAPSED
	var view_w := s.x - side_w
	view_container.position = Vector2.ZERO
	view_container.size = Vector2(view_w, s.y)
	_flash.position = Vector2.ZERO
	_flash.size = Vector2(view_w, s.y)
	_floor_label.position = Vector2(18, 12)
	_steps_label.position = Vector2(18, 42)
	menu_button.size = Vector2(64, 64)
	menu_button.position = Vector2(view_w - 64 - 12, 10)
	map_button.size = Vector2(64, 64)
	map_button.position = Vector2(view_w - 2 * 64 - 20, 10)
	var pad_top := s.y - 2.0 * PAD_BUTTON - PAD_GAP - 16.0
	var order := [A.TURN_LEFT, A.FORWARD, A.TURN_RIGHT, A.STRAFE_LEFT, A.BACK, A.STRAFE_RIGHT]
	for i in order.size():
		var b: TouchButton = pad[order[i]]
		b.size = Vector2(PAD_BUTTON, PAD_BUTTON)
		b.position = Vector2(16.0 + (i % 3) * (PAD_BUTTON + PAD_GAP), pad_top + (i / 3) * (PAD_BUTTON + PAD_GAP))
	var inv: TouchButton = pad[A.INVESTIGATE]
	inv.size = Vector2(PAD_BUTTON + 16.0, PAD_BUTTON)
	inv.position = Vector2(16.0 + 3.0 * (PAD_BUTTON + PAD_GAP) + 8.0, pad_top + PAD_BUTTON + PAD_GAP)
	_toast.position = Vector2(0, pad_top - 46.0)
	_toast.size = Vector2(view_w, 36)

	var x0 := view_w
	toolbar.visible = _map_open
	map.visible = _map_open
	if _map_open:
		toolbar.position = Vector2(x0 + 12, 10)
		toolbar.size = toolbar.custom_minimum_size
		var map_top := toolbar.position.y + toolbar.size.y + 10.0
		map.position = Vector2(x0 + 8, map_top)
		map.size = Vector2(side_w - 16, s.y - STATUS_H - map_top - 8.0)
		status.position = Vector2(x0, s.y - STATUS_H)
		status.size = Vector2(side_w, STATUS_H)
	else:
		status.position = Vector2(x0, 0)
		status.size = Vector2(side_w, STATUS_H)
	map.refresh()
	_debug_dirty = true
	_debug_settle = 2


func _refresh_hud() -> void:
	_steps_label.text = texts.t("hud.steps", {"steps": state.steps})
	_refresh_toolbar()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_left = 2.0


func _flash_damage() -> void:
	_flash.color.a = 0.35


func _process(delta: float) -> void:
	if _autosave_pending and not map.is_stroking():
		_autosave()
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
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)
	if _debug:
		var busy := view.is_busy() or _queued >= 0
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
	for a in pad:
		var b: TouchButton = pad[a]
		buttons[b.name] = _css(b.size / 2.0, b)
	buttons["MenuButton"] = _css(menu_button.size / 2.0, menu_button)
	buttons["MapButton"] = _css(map_button.size / 2.0, map_button)
	if toolbar.visible:
		for key in toolbar.buttons:
			var tb: TouchButton = toolbar.buttons[key]
			buttons["Tool_" + key] = _css(tb.size / 2.0, tb)
	if modal.is_open():
		for n in modal.find_children("*", "Control", true, false):
			if (n is Button or n is TouchButton) and n.is_visible_in_tree():
				buttons[n.name] = _css(n.size / 2.0, n)
	var memo_texts := {}  # "x,y" → 글(웹 확인이 넣은 한국어 글이 그대로 저장됐는지 본다)
	for c in state.annotation.memos:
		memo_texts["%d,%d" % [c.x, c.y]] = state.annotation.memos[c]
	var map_info := {}
	if map.visible:
		var o: Array = _css(map.geo.origin, map)
		var o2: Array = _css(map.geo.origin + Vector2(map.geo.cell_px, map.geo.cell_px), map)
		map_info = {"origin": o, "cell": [o2[0] - o[0], o2[1] - o[1]]}
	return {
		"hash": SaveCodec.state_hash(state), "generation": state.generation, "autosaves": autosave_count,
		"at": [state.party.at.x, state.party.at.y], "facing": state.party.facing, "steps": state.steps,
		"pending": state.encounter.pending, "wiped": state.wiped, "danger": state.encounter.danger,
		"busy": view.is_busy() or _queued >= 0, "modal": modal.kind, "automap": settings.automap,
		"shortcuts_open": state.world.shortcuts_open.size(), "passages_found": state.world.passages_found.size(),
		"memos": state.annotation.memos.size(), "edges": state.annotation.edges.size(), "epoch": _epoch,
		"memo_texts": memo_texts,
		"user_dir": OS.get_user_data_dir(), "buttons": buttons, "map": map_info, "tool": map.tool,
		"guard_delta": view.last_guard_delta, "guard_radius": view.guard_radius,
		"plan_ms_last": view.last_plan_ms, "plan_ms_max": view.max_plan_ms,
		# 지난 연출(끝난 연출 묶음)의 계획 횟수·누적 계획 시간, 지금까지 연출 하나의 가장 큰 누적·횟수.
		"plan_count": view.last_anim_plan_count, "plan_ms_total": view.last_anim_plan_ms,
		"plan_ms_total_max": view.max_anim_plan_ms, "plan_count_max": view.max_anim_plan_count,
	}


## 요청 JSON: {"op": "snapshot"} | {"op": "simulate", "actions": ["forward", …]} | {"op": "hash_save", "text": 저장 글}
## hash_save: 저장 글을 읽어 그 상태 해시·세대를 돌려준다(웹 확인이 IndexedDB 의 자동 저장이 화면 상태와 같은지 본다).
## simulate: 지금 상태의 복사본(저장 형식으로 옮긴 것)에서 행동열을 돌려 행동마다의 해시를 돌려준다.
## 전투 대기면 다음 행동 전에 해결한다(공략 행동열 규칙과 같다). 진짜 상태는 바꾸지 않는다.
func _on_debug_request(json_text: String) -> String:
	var req: Variant = JSON.parse_string(json_text)
	if typeof(req) != TYPE_DICTIONARY:
		return JSON.stringify({"error": "bad request"})
	match str(req.get("op", "")):
		"snapshot":
			return JSON.stringify(debug_snapshot())
		"simulate":
			var copy := SaveCodec.decode(SaveCodec.encode(state), floor_def, party_data.make_members())
			if not copy.ok():
				return JSON.stringify({"error": copy.error})
			var s := copy.state
			var hashes := []
			for name in req.get("actions", []):
				if s.encounter.pending:
					ExplorationRules.resolve_battle(s)
				var a := ExplorationRules.action_from_name(str(name))
				if a < 0:
					return JSON.stringify({"error": "unknown action " + str(name)})
				ExplorationRules.apply(s, a, settings.automap)
				hashes.append(SaveCodec.state_hash(s))
			return JSON.stringify({"hashes": hashes})
		"hash_save":
			var r := SaveCodec.decode(str(req.get("text", "")), floor_def, party_data.make_members())
			if not r.ok():
				return JSON.stringify({"error": r.error})
			return JSON.stringify({"hash": SaveCodec.state_hash(r.state), "generation": r.generation})
	return JSON.stringify({"error": "unknown op"})
