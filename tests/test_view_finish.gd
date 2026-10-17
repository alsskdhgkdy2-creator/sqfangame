## 연출 끝 신호(05 §9.2): 미뤄 낸 끝 신호는 그 재생이 살아 있을 때만 온다.
## set_pose(불러오기·새 게임·가져오기)나 새 play 가 앞 재생을 취소하면 예약된 끝 신호도 무효다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const Kit := preload("res://tests/scene_kit.gd")
const A := ExplorationRules.Action

var _sv: SubViewport
var _count := 0
var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()
	if _sv != null and is_instance_valid(_sv):
		if _sv.get_parent() != null:
			_sv.get_parent().remove_child(_sv)
		_sv.free()


func _make_view() -> DungeonView:
	_sv = SubViewport.new()
	_sv.size = Vector2i(768, 720)
	_sv.own_world_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(_sv)
	var v := DungeonView.new()
	_sv.add_child(v)
	v.setup(Fx.f1(), WorldState.new())
	v.set_pose(Vector2i(2, 18), Dir.N)
	v.animation_finished.connect(func() -> void: _count += 1)
	return v


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func test_set_pose_cancels_scheduled_finish() -> void:
	var v := _make_view()
	var none: Array[Dictionary] = []
	var turn: Array[Dictionary] = [{"type": "turned", "facing": Dir.E}]
	# 대조: 연출 없는 재생은 다음 차례에 한 번 끝 신호.
	_count = 0
	v.play(none)
	check_eq(_count, 0, "끝 신호는 미뤄 낸다")
	await _frames(2)
	check_eq(_count, 1, "연출 없는 재생 = 끝 신호 하나")
	# 연출 없는 재생 뒤 같은 프레임에 set_pose.
	_count = 0
	v.play(none)
	v.set_pose(Vector2i(2, 17), Dir.S)
	await _frames(2)
	check_eq(_count, 0, "set_pose 가 취소한 재생의 끝 신호는 오지 않는다")
	# 즉시 연출(speed 0 → _finish_all) 뒤 같은 프레임에 set_pose.
	_count = 0
	v.speed = 0.0
	v.play(turn)
	v.set_pose(Vector2i(2, 18), Dir.N)
	await _frames(2)
	check_eq(_count, 0, "즉시 끝난 재생도 set_pose 뒤에는 끝 신호 없음")
	# 미뤄 둔 끝 신호가 있는데 새 재생: 끝 신호는 새 재생의 것 하나.
	_count = 0
	v.play(none)
	v.play(turn)
	await _frames(2)
	check_eq(_count, 1, "앞 재생의 미뤄 둔 끝 신호는 새 재생의 끝 신호 하나로 바뀐다")
	# 정상 속도: 진행 중 set_pose 는 연출과 끝 신호를 모두 취소한다.
	_count = 0
	v.speed = 1.0
	v.play(turn)
	check(v.is_busy(), "준비: 연출 중")
	v.set_pose(Vector2i(2, 18), Dir.N)
	check(not v.is_busy(), "set_pose 는 연출을 지운다")
	await _frames(20)
	check_eq(_count, 0, "취소한 연출의 끝 신호 없음")


## 화면: 연출 없는 행동(조사)·즉시 연출(회전) 바로 뒤 같은 프레임에 불러오기 → 옛 끝 신호가 새 상태에서
## 미리 받은 입력·반복 대기·행동을 일으키지 않는다.
func test_load_right_after_action_ignores_old_finish() -> void:
	timeout_sec = 20.0
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open()
	check(s.store.save("slot1", s.state).is_empty(), "준비: 슬롯 1")
	var slot_hash := SaveCodec.state_hash(s.store.load_slot("slot1").result.state)
	var heard := [0]
	s.view.animation_finished.connect(func() -> void: heard[0] += 1)
	for k in [KEY_SPACE, KEY_D]:
		heard[0] = 0
		var saves := s.autosave_count
		kit.key(k, true)
		kit.key(k, false)
		s._load_slot("slot1")
		check_eq(kit.hash_now(), slot_hash, "%s: 불러온 상태" % OS.get_keycode_string(k))
		await kit.frames(3)
		check_eq(heard[0], 0, "%s: 불러오기 전 행동의 끝 신호가 새 상태에 오지 않는다" % OS.get_keycode_string(k))
		check(not s._repeat_wait, "%s: 반복 대기 없음" % OS.get_keycode_string(k))
		check_eq(s._queued, -1, "%s: 미리 받은 입력 없음" % OS.get_keycode_string(k))
		check_eq(kit.hash_now(), slot_hash, "%s: 새 상태에서 행동하지 않았다" % OS.get_keycode_string(k))
		check_eq(s.autosave_count, saves + 2, "%s: 행동 하나 + 불러오기 하나만 저장" % OS.get_keycode_string(k))
	# 대조: 불러오기가 없으면 끝 신호는 온다.
	heard[0] = 0
	await kit.press_key(KEY_D)
	check_eq(heard[0], 1, "대조: 끝 신호 하나")
