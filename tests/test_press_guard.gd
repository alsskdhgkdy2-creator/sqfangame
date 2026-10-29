## 누르기 지킴이(PressGuard, M3 A7d): 누르기는 시작할 때와 뗄 때 주인(selection_key 를 가진 가장 가까운 조상)의 고름 값이 같을 때만
## 일한다. 부품 시험(작은 주인) — 같은 값이면 일함, 주인이 맞추지 않은 바뀜도 뗄 때 막음, sync 의 버리기, 부품(key_part 쪽)은 주인을
## 찾아 올라감, 주인이 없는 단추는 예전 그대로 — 과 실제 화면 시험 — 모든 주인의 값은 가만히 있는 동안 그대로(전투 연출 포함),
## 누르는 순간 주인의 값을 바꾸는 단추가 없다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const HM := preload("res://tests/held_matrix.gd")
const FINGER := 3


## 작은 주인: 값 하나(v)와 단추 둘, 부품 하나(그 안의 단추 하나).
class Host:
	extends Control
	var v := 0
	var guard: PressGuard

	func selection_key() -> Array:
		return [v]


var kit: Kit
var root_host: Control
var hits: Array = []


func teardown() -> void:
	if root_host != null and is_instance_valid(root_host):
		tree.root.remove_child(root_host)
		root_host.free()
	root_host = null
	if kit != null:
		kit.dispose()
		kit = null


func _button(parent: Node, n: String, at: Vector2) -> TouchButton:
	var b := TouchButton.new()
	b.name = n
	b.position = at
	b.size = Vector2(80, 80)
	parent.add_child(b)
	b.activated.connect(func() -> void: hits.append(n))
	return b


## 주인(Host)·단추 A·B·부품(Part, 주인 아님) 안의 단추 C, 그리고 주인 밖의 단추 D.
func _small() -> Array:
	timeout_sec = 30.0
	if kit == null:
		kit = Kit.new(tree)
	hits = []
	root_host = Control.new()
	root_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(root_host)
	var h := Host.new()
	h.name = "Host"
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_host.add_child(h)
	h.guard = PressGuard.new(h)
	var part := Control.new()
	part.name = "Part"
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(part)
	var a := _button(h, "A", Vector2(100, 100))
	var b := _button(h, "B", Vector2(300, 100))
	var c := _button(part, "C", Vector2(500, 100))
	var d := _button(root_host, "D", Vector2(700, 100))
	await kit.frames(2)
	return [h, a, b, c, d]


## M-D2(뗄 때 확인이 빠짐): 같은 값이면 일하고, 누른 뒤 값이 바뀌면(주인이 sync 하지 않아도 = 타이머·연출 같은 길) 뗄 때 일하지 않고
## 주인 아래 다른 눌림도 버린다. 부품 안의 단추도 주인을 찾아 같은 규칙. 주인 밖의 단추는 값과 상관없이 예전 그대로.
func test_release_commits_only_on_the_same_key() -> void:
	var o := await _small()
	var h: Host = o[0]
	var a: TouchButton = o[1]
	var b: TouchButton = o[2]
	var c: TouchButton = o[3]
	var d: TouchButton = o[4]
	check_eq([PressGuard.scope_of(a), PressGuard.scope_of(c), PressGuard.scope_of(d)], [h, h, null], "주인 = selection_key 를 가진 가장 가까운 조상")
	await kit.tap(kit.center_of(a), FINGER)
	check_eq(hits, ["A"], "값이 그대로면 일한다")
	hits.clear()
	# A·B 를 함께 누른 채 값을 바꾼다(sync 없음) → A 를 떼면 일하지 않고 B 도 풀린다 → B 를 떼도 일하지 않는다.
	kit.touch(FINGER, kit.center_of(a), true)
	kit.touch(FINGER + 1, kit.center_of(b), true)
	await kit.frames(1)
	check(a.held and b.held, "준비: A·B 누르는 중")
	h.v = 1
	kit.touch(FINGER, kit.center_of(a), false)
	await kit.frames(1)
	check_eq(hits, [], "값이 바뀐 뒤 뗀 A 는 일하지 않는다(주인이 맞추지 않았어도)")
	check(not b.held, "다른 눌림(B)도 버린다")
	kit.touch(FINGER + 1, kit.center_of(b), false)
	await kit.frames(1)
	check_eq(hits, [], "B 를 떼도 일하지 않는다")
	# 부품 안의 C 도 같다.
	kit.touch(FINGER, kit.center_of(c), true)
	await kit.frames(1)
	h.v = 2
	kit.touch(FINGER, kit.center_of(c), false)
	await kit.frames(1)
	check_eq(hits, [], "부품 안의 단추도 주인 값으로 막는다")
	await kit.tap(kit.center_of(c), FINGER)
	check_eq(hits, ["C"], "새 값에서 시작한 누르기는 일한다")
	# 주인 밖 D: 값이 바뀌어도 일한다(예전 그대로).
	hits.clear()
	kit.touch(FINGER, kit.center_of(d), true)
	await kit.frames(1)
	h.v = 3
	kit.touch(FINGER, kit.center_of(d), false)
	await kit.frames(1)
	check_eq(hits, ["D"], "주인이 없는 단추는 예전 그대로")


## M-D1(sync 가 버리지 않음): sync 는 처음과 값이 바뀔 때만 주인 아래 눌림(단추·끌어 내리는 영역)을 버리고 true, 그대로면 false 이고
## 눌림을 두며 그 누르기는 뗄 때 일한다. reset 뒤 sync 는 다시 버린다(화면을 새로 열 때).
func test_sync_cancels_only_on_a_change() -> void:
	var o := await _small()
	var h: Host = o[0]
	var a: TouchButton = o[1]
	check(h.guard.sync(), "처음 sync = 바뀜")
	kit.touch(FINGER, kit.center_of(a), true)
	await kit.frames(1)
	check(not h.guard.sync(), "값이 그대로면 false")
	check(a.held, "그대로면 눌림을 둔다")
	h.v = 5
	check(h.guard.sync(), "값이 바뀌면 true")
	check(not a.held, "값이 바뀌면 눌림을 버린다")
	kit.touch(FINGER, kit.center_of(a), false)
	await kit.frames(1)
	check_eq(hits, [], "버린 누르기는 뗄 때 일하지 않는다")
	await kit.tap(kit.center_of(a), FINGER)
	check_eq(hits, ["A"], "새 값에서 시작한 누르기는 일한다")
	kit.touch(FINGER, kit.center_of(a), true)
	await kit.frames(1)
	h.guard.reset()
	check(h.guard.sync() and not a.held, "reset 뒤 sync 는 값이 같아도 버린다")
	kit.touch(FINGER, kit.center_of(a), false)
	await kit.frames(1)


# ---- 실제 화면 ----

func _town() -> DungeonScreen:
	timeout_sec = 240.0
	if kit == null:
		kit = Kit.new(tree)
	return await kit.open_town("native", 7, "", func(sc: DungeonScreen) -> void: sc.native_debug = false)


## 화면 열린 쪽마다: 값이 가만히 그대로이고(stable), 누르는 순간 값을 바꾸는 단추가 없다(press_audit). 쪽 이름을 돌려준다.
func _audit(host: Node, tag: String) -> void:
	await HM.stable(self, kit, host, tag)
	var n := await HM.press_audit(self, kit, host, tag)
	check(n > 0, "%s: 눌러 본 단추 %d개" % [tag, n])
	await HM.stable(self, kit, host, tag + " 누른 뒤")


## 모든 주인의 고름 값은 가만히 있는 동안 그대로이고(매 프레임 바뀌는 것이 없다), 누르는 순간 주인의 값을 바꾸는 단추가 없다:
## 마을(광장·숙소·숙소 기록), 상점(뿌리·갈래·목록·확인 창), 길드(뿌리·직업), 캠프(뿌리·고르기·소지품·장비 목록·스킬·기록·대열),
## 타이틀(메뉴·불러오기).
func test_screen_keys_are_stable_and_no_press_changes_them() -> void:
	var s := await _town()
	var t := s.town_screen
	await _audit(t, "광장")
	await kit.press_key(KEY_1)
	check_eq(t.page, "inn", "준비: 숙소")
	await _audit(t, "숙소")
	await kit.press_key(KEY_2)
	check_eq(t.page, "inn_save", "준비: 숙소 기록")
	await _audit(t, "숙소 기록")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	s.state.money = 1000
	s._open_shop()
	await kit.frames(2)
	var sc := s.shop_screen
	check(sc.is_open(), "준비: 상점")
	await _audit(sc, "상점 뿌리")
	await kit.press_key(KEY_1)
	await _audit(sc, "상점 갈래")
	await kit.press_key(KEY_1)
	check_eq(sc.page, "buy", "준비: 구매 목록")
	await _audit(sc, "상점 목록")
	await kit.press_key(KEY_ENTER)
	check(sc.dialog.is_open(), "준비: 확인 창")
	await HM.stable(self, kit, sc, "상점 확인 창")
	await kit.press_key(KEY_ESCAPE)
	for i in 3:
		await kit.press_key(KEY_ESCAPE)
	check(not sc.is_open(), "준비: 상점 닫음")
	await kit.tap(kit.center_of(t.plaza_list.rows[3]))
	await kit.frames(1)
	var g := s.guild_screen
	check(g.is_open(), "준비: 길드")
	await _audit(g, "길드 뿌리")
	await kit.press_key(KEY_1)
	await _audit(g, "길드 직업")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_P)
	var pm := s.party_menu
	check(pm.is_open(), "준비: 캠프")
	await _audit(pm, "캠프 뿌리")
	for step in [[KEY_2, "캠프 고르기(상태)"], [KEY_ENTER, "캠프 상태"]]:
		await kit.press_key(step[0])
		await HM.stable(self, kit, pm, step[1])
	await kit.press_key(KEY_1)
	await _audit(pm, "캠프 소지품")
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	await _audit(pm, "캠프 장비 목록")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_4)
	await _audit(pm, "캠프 스킬")
	await kit.press_key(KEY_5)
	await _audit(pm, "캠프 대열")
	await kit.press_key(KEY_6)
	await _audit(pm, "캠프 기록")
	kit.close_screen()
	await kit.frames(1)
	var ts := (await kit.open_title()).title_screen
	await _audit(ts, "타이틀 메뉴")
	await kit.press_key(KEY_2)
	await _audit(ts, "타이틀 불러오기")


## 전투 층: 명령·스킬·대상·연출(띠 연출·자동 넘김 중)에서 고름 값이 가만히 그대로이고, 명령·대상 쪽에서 누르는 순간 값을 바꾸는
## 단추가 없다.
func test_battle_key_is_stable_through_the_animation() -> void:
	timeout_sec = 120.0
	if kit == null:
		kit = Kit.new(tree)
	var texts := TextDb.load_path("res://data/text/ko.json")
	var s := Fx.battle(Fx.quiet_defs({}, ["enemy.cable_moth"]), "formation.f1.rats_moth", 5)
	root_host = Control.new()
	root_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(root_host)
	var layer := BattleLayer.new()
	root_host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = 0.1
	layer.open(s)
	await kit.frames(2)
	await _audit(layer, "전투 명령")
	await kit.press_key(KEY_2)
	check_eq(layer.sub, "skills", "준비: 스킬")
	await HM.stable(self, kit, layer, "전투 스킬")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_1)
	check_eq(layer.sub, "target", "준비: 대상")
	await _audit(layer, "전투 대상")
	await kit.press_key(KEY_ESCAPE)
	for i in 5:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.phase, "anim", "준비: 연출 중")
	await HM.stable(self, kit, layer, "전투 연출", 30)
	check_eq(layer.phase, "anim", "표본 내내 연출 중")
