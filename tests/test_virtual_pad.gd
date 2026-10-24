## 가상 키패드 부품(VirtualPad, 사용자 제안 2026-10-25): 전투가 쓰고 캠프가 그대로 다시 쓴다. 화면을 모르는 부품이라 따로 띄워 본다.
## 배치(십자·선택/취소 가로·세로), 단추 64×64 이상, 누르기 → pressed 종류, 흐린 단추는 아무 일 없음, 방향은 누르는 순간·선택은 뗄 때,
## 취소(cancel) 뒤 떼기는 아무 일 없음.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")

var kit: Kit
var host: Control
var got: Array = []


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()
		kit = null


func _pads() -> Array:
	kit = Kit.new(tree)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	var dirs := VirtualPad.new().setup_dirs()
	dirs.position = Vector2(8, 300)
	var keys := VirtualPad.new().setup_keys("선택", "취소")
	keys.position = Vector2(600, 300)
	var tall := VirtualPad.new().setup_keys("선택", "취소", true)
	tall.position = Vector2(900, 200)
	for vp in [dirs, keys, tall]:
		host.add_child(vp)
		vp.pressed.connect(func(k: String, a: Variant) -> void: got.append([k, a]))
		vp.set_enabled({"up": true, "down": true, "left": true, "right": true, "ok": true, "back": true})
	await kit.frames(2)
	return [dirs, keys, tall]


func test_layouts_and_sizes() -> void:
	var p := await _pads()
	var dirs: VirtualPad = p[0]
	check_eq(dirs.size, Vector2(200, 200), "십자 200×200")
	check_eq([dirs.button("up").position, dirs.button("left").position, dirs.button("right").position, dirs.button("down").position],
		[Vector2(68, 0), Vector2(0, 68), Vector2(136, 68), Vector2(68, 136)], "위·왼쪽·오른쪽·아래, 가운데 칸 비움")
	check_eq((p[1] as VirtualPad).size, Vector2(227, 72), "선택·취소 가로 227×72")
	check_eq((p[2] as VirtualPad).size, Vector2(110, 151), "선택·취소 세로 110×151")
	check((p[1] as VirtualPad).button("back").position.x < (p[1] as VirtualPad).button("ok").position.x, "가로: 왼쪽 취소, 오른쪽 선택")
	check((p[2] as VirtualPad).button("back").position.y < (p[2] as VirtualPad).button("ok").position.y, "세로: 위 취소, 아래 선택")
	for vp in p:
		check_eq((vp as VirtualPad).mouse_filter, Control.MOUSE_FILTER_IGNORE, "묶음은 누르기를 받지 않는다")
		for k in vp.buttons:
			var b: TouchButton = vp.buttons[k]
			check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s 64×64 이상" % b.name)
			check_eq(b.focus_mode, Control.FOCUS_NONE, "%s 포커스 없음" % b.name)


func test_presses_report_kinds_and_dimmed_do_nothing() -> void:
	var p := await _pads()
	var dirs: VirtualPad = p[0]
	var keys: VirtualPad = p[1]
	for k in ["up", "down", "left", "right"]:
		await kit.tap(kit.center_of(dirs.button(k)))
	await kit.tap(kit.center_of(keys.button("ok")))
	await kit.tap(kit.center_of(keys.button("back")))
	await kit.tap(kit.center_of((p[2] as VirtualPad).button("ok")))
	check_eq(got, [["move", Vector2i(0, -1)], ["move", Vector2i(0, 1)], ["move", Vector2i(-1, 0)], ["move", Vector2i(1, 0)],
		["ok", null], ["back", null], ["ok", null]], "누르기 → 종류")
	got.clear()
	dirs.set_enabled({"up": true})
	keys.set_enabled({"back": true})
	check(dirs.button("down").disabled and keys.button("ok").disabled and not dirs.button("up").disabled, "켤 것만 켜고 나머지는 흐림")
	await kit.tap(kit.center_of(dirs.button("down")))
	await kit.tap(kit.center_of(keys.button("ok")))
	check_eq(got, [], "흐린 단추는 아무 일 없음")
	# 방향은 누르는 순간, 선택은 뗄 때. 누른 채 cancel 하면 떼도 아무 일 없음.
	kit.touch(2, kit.center_of(dirs.button("up")), true)
	await kit.frames(2)
	check_eq(got, [["move", Vector2i(0, -1)]], "방향은 누르는 순간")
	kit.touch(2, kit.center_of(dirs.button("up")), false)
	await kit.frames(2)
	got.clear()
	keys.set_enabled({"ok": true, "back": true})
	kit.touch(3, kit.center_of(keys.button("ok")), true)
	await kit.frames(2)
	check_eq(got, [], "선택은 누르는 동안 아직")
	keys.cancel()
	kit.touch(3, kit.center_of(keys.button("ok")), false)
	await kit.frames(2)
	check_eq(got, [], "취소된 선택은 떼도 아무 일 없음")
	await kit.tap(kit.center_of(keys.button("ok")))
	check_eq(got, [["ok", null]], "다음 누르기는 그대로")
