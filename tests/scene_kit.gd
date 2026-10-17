## 장면 시험 도구: 탐색 화면을 임시 저장 폴더로 띄우고, 실제 입력 경로(Input.parse_input_event)로 누르고 끌고 뗀다.
## 파일 이름이 test_ 로 시작하지 않아 실행기가 직접 돌리지 않는다.
extends RefCounted

const SCREEN := preload("res://src/game/dungeon/dungeon_screen.tscn")
## 장면 시험이 만드는 임시 폴더 이름의 접두어. 이 접두어의 user:// 바로 아래 폴더만 지운다(user://saves 등은 절대 아님).
const PREFIX := "test_scene_"

var tree: SceneTree
var dir := ""
var screen: DungeonScreen


func _init(t: SceneTree) -> void:
	tree = t
	purge_stale()
	dir = "user://%s%d" % [PREFIX, Time.get_ticks_usec() % 100000000]


## 지난 실행이 남긴 임시 폴더를 지운다(시간 초과로 끊긴 실행은 teardown 을 못 한다).
## 시험은 서버에서 한 번에 하나만 돌므로 시작할 때 지워도 다른 실행의 폴더를 건드리지 않는다.
## 대상은 is_scene_dir 를 지나는 이름만이다(user://test_scene_ 그 자체 같은 이름은 단언 없이 건너뛴다).
static func purge_stale() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for sub in d.get_directories():
		if is_scene_dir("user://" + sub):
			remove_scene_dir("user://" + sub)


## user:// 바로 아래의 PREFIX 폴더인지(지워도 되는 대상인지).
static func is_scene_dir(path: String) -> bool:
	var rest := path.trim_prefix("user://")
	return path.begins_with("user://") and rest.begins_with(PREFIX) and rest.length() > PREFIX.length() \
		and not rest.contains("/") and not rest.contains("\\") and not rest.contains("..")


## 화면을 만들어 트리에 넣는다. 시드는 고정, 연출은 즉시, 플랫폼은 PC 로 본다.
func open(platform: String = "native", seed_value: int = 7) -> DungeonScreen:
	screen = SCREEN.instantiate()
	screen.save_dir = dir + "/saves"
	screen.settings_path = dir + "/settings.json"
	screen.platform = platform
	screen.seed_override = seed_value
	screen.anim_speed = 0.0
	tree.root.add_child(screen)
	await frames(2)
	return screen


## 같은 저장 폴더로 화면을 다시 연다(앞 화면은 지운다).
func reopen() -> DungeonScreen:
	close_screen()
	await frames(1)
	return await open()


func close_screen() -> void:
	if screen != null and is_instance_valid(screen):
		tree.root.remove_child(screen)
		screen.free()
	screen = null
	Input.flush_buffered_events()
	for a in InputMap.get_actions():
		Input.action_release(a)


## 화면과 임시 폴더를 치운다(teardown 에서 부른다).
func dispose() -> void:
	close_screen()
	remove_scene_dir(dir)


## 장면 시험 임시 폴더를 통째로 지운다. 다른 경로면 단언 실패(그리고 아무것도 지우지 않는다).
## 링크는 따라가지 않는다: 폴더 자체가 링크면 링크만, 안의 링크(폴더·파일)도 링크만 지운다.
## (Godot 의 get_directories 는 폴더를 가리키는 링크도 폴더로 내놓고, DirAccess.open 은 링크를 따라 연다.)
static func remove_scene_dir(path: String) -> void:
	assert(is_scene_dir(path), "장면 시험 임시 폴더가 아닌 것을 지우려 했다: " + path)
	if not is_scene_dir(path):
		return
	var parent := DirAccess.open("user://")
	if parent == null:
		return
	var name := path.trim_prefix("user://")
	if parent.is_link(name):
		parent.remove(name)
		return
	_remove_tree(path)


static func _remove_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		if d.is_link(sub):
			d.remove(sub)
		else:
			_remove_tree(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)  # 파일 링크도 링크만 지운다
	DirAccess.remove_absolute(path)


func frames(n: int) -> void:
	for i in n:
		await tree.process_frame


# ---- 좌표 ----

## 컨트롤 안의 점 → 창 좌표.
func at(c: CanvasItem, local: Vector2) -> Vector2:
	return c.get_viewport().get_screen_transform() * c.get_global_transform_with_canvas() * local


func center_of(c: Control) -> Vector2:
	return at(c, c.size / 2.0)


func map_cell(cell: Vector2i) -> Vector2:
	return at(screen.map, screen.map.geo.to_screen(Vector2(cell) + Vector2(0.5, 0.5)))


## 지도 칸 cell 의 dir 쪽 변 가운데(창 좌표).
func map_edge(cell: Vector2i, d: int) -> Vector2:
	var off := {Dir.N: Vector2(0.5, 0.0), Dir.E: Vector2(1.0, 0.5), Dir.S: Vector2(0.5, 1.0), Dir.W: Vector2(0.0, 0.5)}
	return at(screen.map, screen.map.geo.to_screen(Vector2(cell) + off[d]))


# ---- 입력 (실제 입력 경로) ----

func _send(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	_send(t)


func drag(index: int, from: Vector2, to: Vector2, steps: int = 6) -> void:
	for i in range(1, steps + 1):
		var d := InputEventScreenDrag.new()
		d.index = index
		d.position = from.lerp(to, float(i) / steps)
		d.relative = (to - from) / steps
		_send(d)


## 같은 프레임 안에서 누르고 뗀다(즉시 연출이라 프레임을 끼우면 누르고 있기 반복이 일어난다).
func tap(pos: Vector2, index: int = 0) -> void:
	touch(index, pos, true)
	touch(index, pos, false)
	await frames(3)


func mouse(pos: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var m := InputEventMouseButton.new()
	m.position = pos
	m.global_position = pos
	m.button_index = button
	m.pressed = pressed
	if pressed:
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
	_send(m)


func click(pos: Vector2) -> void:
	mouse(pos, true)
	mouse(pos, false)
	await frames(3)


func key(physical: int, pressed: bool, ctrl: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = physical
	k.keycode = physical
	k.pressed = pressed
	k.ctrl_pressed = ctrl
	_send(k)


func press_key(physical: int, ctrl: bool = false) -> void:
	key(physical, true, ctrl)
	key(physical, false, ctrl)
	await frames(3)


# ---- 상태 ----

## 열린 창 안에서 글자가 text 인 Button.
func modal_button(text: String) -> Button:
	for n in screen.modal.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n
	return null


func hash_now() -> String:
	return SaveCodec.state_hash(screen.state)


## 화면이 가진 실제 상태 묶음: 상태 해시, 시야 메시 꼭짓점 수와 위치, 지도가 보는 상태.
func fingerprint() -> Dictionary:
	return {
		"hash": hash_now(),
		"view_vertices": screen.view.vertex_count(),
		"view_pose": screen.view.camera_transform(),
		"view_mesh": screen.view._mesh_instance.mesh.get_instance_id(),
		"map_state": screen.map.state == screen.state,
		"map_edges": screen.state.annotation.edges.duplicate(),
		"undo_depth": screen.state.annotation.undo_depth(),
		"epoch": screen._epoch,
	}


## 자동 저장 파일에 적힌 세대.
func auto_generation() -> int:
	var info := screen.store.slot_info(SaveStore.AUTO)
	return info.generation if info.ok else -1
