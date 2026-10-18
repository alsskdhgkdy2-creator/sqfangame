## 전투 층 장면 시험(06 §10.3, 05 §11.2 실행기 경로): 실제 입력 경로(Input.parse_input_event)로 누르고, 층이 만든 명령·
## 규칙 상태·저장 파일을 본다. 층만 띄운다(미궁 화면 연결은 M2-B2 시험). 저장은 장면 시험 임시 폴더에만 쓴다.
## 편성 rats_moth: 적 0·1 네온 쥐(전열), 2 케이블 나방(후열). 메딕·위저드는 후열 근접 공격이라 나방에 닿지 않는다.
## 턴 결과에 기대는 시험은 결과를 구성으로 정한다(D15: 승패·시드·능력치에 기대지 않는다): 다음 턴이 와야 하면 _calm_state
## (끝날 수 없는 편성), 그 턴에 이겨야 하면 _sure_state(명중 확정, 적은 아무것도 하지 않음) + 적 HP 1 + 적마다 하나씩 겨눈 공격.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const RATS_MOTH := "formation.f1.rats_moth"
const MOTH := "enemy.cable_moth"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const CROSS_SWEEP := "skill.blade_duelist.cross_sweep"
const OVERCLOCK := "skill.blade_duelist.overclock"
const HEAT := "skill.glyph_wizard.heat_glyph"
const REPAIR := "skill.nano_medic.nano_repair"

var kit: Kit
var host: Control
var layer: BattleLayer
var store: SaveStore
var texts: TextDb
## 저장 갈고리가 불릴 때의 층 모습(제출 → 저장 → 연출 순서 확인).
var hook_log: Array[Dictionary] = []
var closed_with: Array[String] = []


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()


func _state(formation: String = RATS_MOTH, seed_value: int = 5) -> ExplorationState:
	return Fx.battle(Fx.defs(), formation, seed_value)


## 끝날 수 없는 rats_moth: 적이 아무것도 하지 않아 전멸이 없고, 나방은 모든 속성 무효라 쓰러지지 않아 승리도 없다(쥐는 그대로
## 맞는다). 장비·레벨·시드가 바뀌어도 몇 턴을 넘겨도 전투가 이어진다.
func _calm_state(seed_value: int = 5) -> ExplorationState:
	var s := Fx.battle(Fx.quiet_defs({}, [MOTH]), RATS_MOTH, seed_value)
	check(s.battle.enemies.any(func(u: BattleUnit) -> bool: return u.resist.values().all(func(v): return v == 0)), "구성: 모든 속성 무효인 적(나방)이 있다")
	return s


## 맞히면 결과가 정해지는 전투: 규칙 상수 Fx.EXACT(명중 1000, 피해·순서 난수 고정, 크리티컬 0)이고 적은 아무것도 하지 않는다.
## 공격은 반드시 맞고 피해는 1 이상이며, 대원은 쓰러지지 않아 고른 행동을 모두 한다.
func _sure_state(formation: String, seed_value: int = 4) -> ExplorationState:
	return Fx.battle(Fx.quiet_defs(Fx.EXACT), formation, seed_value)


## 층을 새로 띄운다(앞 층은 지운다). size 가 있으면 그 크기의 화면으로 본다(입력은 쓰지 않는 배치 시험용).
func _open(s: ExplorationState, speed: float = 0.0, size: Vector2 = Vector2.ZERO) -> BattleLayer:
	timeout_sec = 30.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if store == null:
		store = SaveStore.new(s.defs, kit.dir + "/saves")
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "BattleHost"
	if size == Vector2.ZERO:
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		host.position = Vector2.ZERO
		host.size = size
	tree.root.add_child(host)
	layer = BattleLayer.new()
	host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = speed
	layer.save_hook = _on_save
	layer.closed.connect(func(o: String) -> void: closed_with.append(o))
	layer.open(s)
	await kit.frames(2)
	return layer


func _on_save() -> void:
	var enemy_hp := []
	for u in layer.display.enemies:
		enemy_hp.append(u.hp)
	# battle_hash 는 전투가 끝나 battle == null 이어도 계산된다(끝난 턴의 저장도 실제 해시로 비교한다).
	hook_log.append({"phase": layer.phase, "shown_enemy_hp": enemy_hp, "state_hash": Fx.battle_hash(layer.state),
		"why": store.save(SaveStore.AUTO, layer.state)})


func _btn(n: String) -> TouchButton:
	return layer.find_child(n, true, false) as TouchButton


func _skill_row(sid: String) -> TouchButton:
	for b in layer.panel.skill_rows:
		if b.visible and b.get_meta("skill_id", "") == sid:
			return b
	return null


func _tap(c: Control) -> void:
	await kit.tap(kit.center_of(c))


func _tap_btn(n: String) -> void:
	var b := _btn(n)
	check(b != null and b.is_visible_in_tree(), "보이는 단추 " + n)
	if b != null:
		await _tap(b)


func _enemy(i: int) -> BattleCard:
	return layer.enemy_area.card(i)


func _member(i: int) -> BattleCard:
	return layer.party_cards.card(i)


## 기준 경로(누르기): 나이트 공격→쥐 0, 듀얼 A 방어, 듀얼 B 하이 슬래시→쥐 1, 메딕 공격(나방은 닿지 않아 거부)→쥐 0,
## 위저드 열 글리프→나방.
const EXPECTED := [
	{"kind": "attack", "target": 0}, {"kind": "guard"}, {"kind": "skill", "skill": HIGH_SLASH, "target": 1},
	{"kind": "attack", "target": 0}, {"kind": "skill", "skill": HEAT, "target": 2},
]


func _tap_path() -> void:
	await _tap_btn("Cmd_attack")
	check_eq(layer.sub, "target", "공격 → 대상 고르기")
	await _tap(_enemy(0))
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_skill")
	check_eq(layer.sub, "skills", "스킬 목록")
	await _tap(_skill_row(HIGH_SLASH))
	await _tap(_enemy(1))
	check_eq(layer.member, 3, "메딕 차례")
	await _tap_btn("Cmd_attack")
	await _tap(_enemy(2))
	check_eq(layer.sub, "target", "닿지 않는 나방은 고를 수 없다")
	check(layer.commands[3] == null, "메딕 명령 없음")
	check_eq(layer._notice, texts.t("battle.reason.unreachable"), "알림 줄 이유")
	await _tap(_enemy(0))
	await _tap_btn("Cmd_skill")
	await _tap(_skill_row(HEAT))
	await _tap(_enemy(2))


func test_taps_build_commands_and_execute_submits() -> void:
	var s := _calm_state()
	await _open(s)
	await _tap_path()
	check_eq(layer.sub, "confirm", "모든 명령이 차면 실행 단계")
	check_eq(layer.commands, EXPECTED, "누르기로 만든 명령")
	check_eq(s.battle.turn, 0, "실행 전에는 제출하지 않는다")
	check(_btn("Execute").is_visible_in_tree(), "실행 단추")
	var ref := _calm_state()
	BattleRules.submit(ref, EXPECTED.duplicate(true))
	await _tap_btn("Execute")
	check_eq(hook_log.size(), 1, "제출 한 번에 자동 저장 한 번")
	check_eq(Fx.battle_hash(s), Fx.battle_hash(ref), "같은 명령을 규칙에 바로 낸 결과와 같다")
	check_eq(layer.phase, "command", "연출(즉시) 뒤 다음 턴 명령 입력")
	check_eq(layer.member, 0, "다음 턴은 첫 대원부터")
	check_eq(layer.display.turn, 1, "턴 2")


func test_keyboard_path_gives_same_result() -> void:
	var s := _state()
	await _open(s)
	await kit.press_key(KEY_1)  # 공격
	await kit.press_key(KEY_ENTER)  # 첫 유효 대상 = 쥐 0
	await kit.press_key(KEY_3)  # 방어
	await kit.press_key(KEY_2)  # 스킬
	await kit.press_key(KEY_ENTER)  # 첫 줄 = 하이 슬래시
	await kit.press_key(KEY_RIGHT)  # 쥐 1
	await kit.press_key(KEY_SPACE)
	await kit.press_key(KEY_DOWN)  # 메뉴 커서: 공격 → 스킬
	await kit.press_key(KEY_UP)  # 다시 공격
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_LEFT)
	await kit.press_key(KEY_ENTER)  # 쥐 0 (나방은 목록에 없어 커서가 가지 않는다)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)  # 열 글리프
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_RIGHT)  # 쥐 0 → 쥐 1 → 나방
	check_eq(layer.target_slots, [0, 1, 2] as Array[int], "원거리 글리프는 셋 다 닿는다")
	await kit.press_key(KEY_ENTER)
	check_eq(layer.commands, EXPECTED, "키보드로 만든 명령 = 누르기 경로")
	await kit.press_key(KEY_ESCAPE)
	check_eq(layer.member, 4, "Esc: 마지막 대원으로 돌아간다")
	check(layer.commands[4] == null, "그 대원의 명령을 지운다")
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_BACKSPACE)
	check_eq(layer.sub, "skills", "대상 고르기 중 Backspace → 스킬 목록")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_LEFT)  # 0 → 2(돌아감)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.commands, EXPECTED, "다시 고른 명령")
	var ref := _state()
	BattleRules.submit(ref, EXPECTED.duplicate(true))
	await kit.press_key(KEY_ENTER)  # 실행
	check_eq(Fx.battle_hash(s), Fx.battle_hash(ref), "키보드 실행 결과 = 규칙 직접 제출")


func test_back_steps() -> void:
	await _open(_state())
	check(_btn("Back").disabled, "첫 대원 메뉴에서는 뒤로 갈 곳이 없다")
	await _tap_btn("Cmd_guard")
	check_eq(layer.member, 1, "방어 → 다음 대원")
	await _tap_btn("Cmd_skill")
	await _tap(_skill_row(HIGH_SLASH))
	check_eq(layer.sub, "target", "하이 슬래시 대상")
	await _tap_btn("Back")
	check_eq(layer.sub, "skills", "대상 → 스킬 목록")
	await _tap_btn("Back")
	check_eq(layer.sub, "menu", "스킬 목록 → 메뉴")
	await _tap_btn("Cmd_attack")
	await _tap_btn("Back")
	check_eq(layer.sub, "menu", "공격 대상 → 메뉴")
	check_eq(layer.member, 1, "같은 대원")
	await _tap_btn("Back")
	check_eq(layer.member, 0, "메뉴에서 뒤로 → 앞 대원")
	check(layer.commands[0] == null, "앞 대원 명령을 지운다")


func test_blocked_skill_and_escape_cannot_be_chosen() -> void:
	var s := _state()
	s.battle.party[0].binds["leg"] = 2
	s.battle.party[1].binds["arm"] = 2
	s.battle.party[4].tp = 0
	await _open(s)
	check(_btn("Cmd_escape").get("dimmed"), "다리 잠금이면 도주가 흐리다")
	await _tap_btn("Cmd_escape")
	check(layer.commands[0] == null and layer.member == 0, "다리 잠금 도주는 고르지 않는다")
	check_eq(layer._notice, texts.t("battle.reason.bound_leg"), "도주 이유")
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_skill")
	var row := _skill_row(HIGH_SLASH)
	check(row.get("dimmed") and row.get("note") == texts.t("battle.reason.bound_arm"), "팔 잠금 스킬은 흐리게 이유와 함께")
	await _tap(row)
	check_eq(layer.sub, "skills", "못 쓰는 스킬은 고르지 않는다")
	check_eq(layer._notice, texts.t("battle.reason.bound_arm"), "알림 줄 이유")
	await _tap(_skill_row(OVERCLOCK))
	check_eq(layer.commands[1], {"kind": "skill", "skill": OVERCLOCK}, "자기 대상 스킬은 확인 없이 확정")
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_skill")
	await _tap(_skill_row(HEAT))
	check_eq(layer._notice, texts.t("battle.reason.no_tp"), "TP 부족")
	check(layer.commands[4] == null, "TP 가 모자란 스킬은 고르지 않는다")


func test_ally_target_and_invalid_member() -> void:
	var s := _state()
	s.battle.party[2].hp = 0
	await _open(s)
	for i in 2:
		await _tap_btn("Cmd_guard")
	check_eq(layer.member, 3, "쓰러진 듀얼 B 는 건너뛴다")
	await _tap_btn("Cmd_skill")
	await _tap(_skill_row(REPAIR))
	check_eq(layer.target_side, BattleUnit.PARTY, "회복은 파티 칸을 고른다")
	check_eq(_member(2).target_mark, "invalid", "쓰러진 대원은 흐리게")
	await _tap(_member(2))
	check(layer.commands[3] == null, "쓰러진 대원은 회복 대상이 아니다")
	await _tap(_enemy(0))
	check(layer.commands[3] == null, "적 칸은 아군 대상이 아니다")
	await _tap(_member(1))
	check_eq(layer.commands[3], {"kind": "skill", "skill": REPAIR, "target": 1}, "파티 칸 누르기")


func test_row_target_lights_row() -> void:
	await _open(_state())
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_skill")
	await _tap(_skill_row(CROSS_SWEEP))
	check_eq(_enemy(0).target_mark, "lit", "줄 전체 강조: 쥐 0")
	check_eq(_enemy(1).target_mark, "lit", "줄 전체 강조: 쥐 1")
	check_eq(_enemy(2).target_mark, "valid", "후열 나방: 닿지만 다른 줄이라 강조하지 않는다")
	await _tap(_enemy(1))
	check_eq(layer.commands[1], {"kind": "skill", "skill": CROSS_SWEEP, "target": 1}, "그 줄의 아무 적")


func test_animation_accepts_only_skip() -> void:
	var s := _calm_state()
	await _open(s, 0.1)
	for i in 5:
		await kit.press_key(KEY_3)
	var turn_hash := Fx.battle_hash(s)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.phase, "anim", "실행 뒤 연출 중")
	check(Fx.battle_hash(s) != turn_hash, "규칙 상태는 이미 그 턴 끝")
	var n := layer.accepted_inputs
	await kit.press_key(KEY_1)
	await kit.press_key(KEY_L)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_LEFT)
	check_eq(layer.accepted_inputs, n, "연출 중 다른 키는 버린다")
	check(not layer.log_view.visible, "연출 중 로그는 열리지 않는다")
	check_eq(layer.phase, "anim", "아직 연출 중")
	await kit.press_key(KEY_SPACE)
	check_eq(layer.phase, "command", "Space = 건너뛰기")
	check_eq(layer.member, 0, "다음 턴 첫 대원")
	check_eq(layer.commands, [null, null, null, null, null], "연출 중 누른 키가 명령으로 남지 않는다")
	# 누르기로 건너뛰기: 연출 중 단추 자리를 눌러도 단추는 받지 않는다(덮개가 받는다)
	for i in 5:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.phase, "anim", "두 번째 턴 연출")
	await kit.tap(kit.center_of(layer.panel))
	check_eq(layer.phase, "command", "누르기 = 건너뛰기")
	check(layer.commands[0] == null, "건너뛴 누르기가 명령이 되지 않는다")


func test_one_input_per_frame() -> void:
	await _open(_state())
	kit.key(KEY_3, true)
	kit.key(KEY_3, false)
	kit.key(KEY_3, true)
	kit.key(KEY_3, false)
	await kit.frames(3)
	check_eq(layer.member, 1, "같은 프레임 두 번째 입력은 버린다")
	check(layer.commands[1] == null, "두 번째 대원은 그대로")
	# 누르기와 키가 같은 프레임
	var c := kit.center_of(_btn("Cmd_guard"))
	kit.touch(0, c, true)
	kit.touch(0, c, false)
	kit.key(KEY_3, true)
	await kit.frames(3)
	kit.key(KEY_3, false)
	check_eq(layer.member, 2, "한 프레임 한 입력(누르기 먼저)")


func test_pointer_ownership() -> void:
	await _open(_state())
	await _tap_btn("Cmd_attack")
	# 적 칸에서 누르고 뒤로 단추 위에서 뗀다
	kit.touch(0, kit.center_of(_enemy(0)), true)
	await kit.frames(1)
	kit.drag(0, kit.center_of(_enemy(0)), kit.center_of(_btn("Back")))
	kit.touch(0, kit.center_of(_btn("Back")), false)
	await kit.frames(3)
	check_eq(layer.sub, "target", "적 칸에서 시작한 누르기는 뒤로가 되지 않는다")
	check(layer.commands[0] == null, "대상도 고르지 않는다(칸 밖에서 뗌)")
	await _tap_btn("Back")
	# 명령 단추에서 누르고 적 칸 위에서 뗀다
	var from := kit.center_of(_btn("Cmd_guard"))
	kit.touch(0, from, true)
	await kit.frames(1)
	kit.drag(0, from, kit.center_of(_enemy(0)))
	kit.touch(0, kit.center_of(_enemy(0)), false)
	await kit.frames(3)
	check(layer.commands[0] == null and layer.member == 0, "명령 단추 밖에서 뗀 누르기는 없음")
	# 마우스도 같다
	kit.mouse(kit.center_of(_btn("Cmd_guard")), true)
	await kit.frames(1)
	kit.mouse(kit.center_of(_enemy(1)), false)
	await kit.frames(3)
	check(layer.commands[0] == null, "마우스: 단추 밖에서 뗌")


func test_emulated_mouse_is_ignored() -> void:
	await _open(_state())
	var c := kit.center_of(_btn("Cmd_guard"))
	for pressed in [true, false]:
		var m := InputEventMouseButton.new()
		m.device = InputEvent.DEVICE_ID_EMULATION
		m.position = c
		m.global_position = c
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = pressed
		Input.parse_input_event(m)
		Input.flush_buffered_events()
	await kit.frames(3)
	check(layer.commands[0] == null, "흉내 낸 마우스만으로는 누르지 않는다")
	var n := layer.accepted_inputs
	await kit.tap(c)
	check_eq(layer.accepted_inputs, n + 1, "터치 한 번 = 입력 한 번(흉내 마우스 중복 없음)")
	check_eq(layer.member, 1, "방어 한 번")
	check(layer.commands[1] == null, "다음 대원에게 넘어가지 않는다")


func test_save_happens_after_submit_before_animation() -> void:
	var s := _state()
	await _open(s, 0.1)
	var before_hp := []
	for u in s.battle.enemies:
		before_hp.append(u.hp)
	for i in 4:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)  # 위저드 열 글리프 → 쥐 0
	await kit.press_key(KEY_ENTER)  # 실행
	check_eq(hook_log.size(), 1, "저장 한 번")
	var h: Dictionary = hook_log[0]
	check_eq(h["why"], "", "저장 성공")
	check_eq(h["phase"], "command", "저장할 때 연출은 아직 시작 전")
	check_eq(h["shown_enemy_hp"], before_hp, "저장할 때 화면은 아직 제출 전 값")
	check_eq(h["state_hash"], Fx.battle_hash(s), "저장할 때 규칙 상태는 이미 그 턴 끝")
	var l := store.load_slot(SaveStore.AUTO)
	check(l.ok() and Fx.battle_hash(l.result.state) == Fx.battle_hash(s), "자동 저장 = 제출 뒤 상태")
	check_eq(layer.phase, "anim", "저장 뒤 연출")


func test_reload_during_animation_resumes_next_turn() -> void:
	var s := _calm_state()
	var pre := Fx.battle_clone(s)
	await _open(s, 0.1)
	for i in 5:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.phase, "anim", "연출 중")
	var after := Fx.battle_hash(s)
	# 새로고침: 화면을 버리고 저장에서 다시
	var l := store.load_slot(SaveStore.AUTO)
	check(l.ok(), "자동 저장 읽기")
	await _open(l.result.state)
	check_eq(Fx.battle_hash(layer.state), after, "다시 연 상태 = 제출 뒤 상태(연출 중 새로고침해도 같은 결과)")
	check_eq(layer.phase, "command", "명령 입력 처음")
	check_eq(layer.member, 0, "첫 대원")
	check_eq(layer.display.turn, 1, "다음 턴")
	# 제출 전 저장에서 같은 명령 → 같은 결과(새로고침으로 다시 굴릴 수 없다)
	BattleRules.submit(pre, Fx.cmds(pre))
	check_eq(Fx.battle_hash(pre), after, "제출 전 상태 + 같은 명령 = 같은 결과")


func _status_state() -> ExplorationState:
	var s := _state("formation.f1.beetle_rat", 3)
	var b := s.battle
	b.enemies[0].charging = "skill.enemy.crush"
	b.enemies[1].binds["leg"] = 2
	b.enemies[1].ailment = "poison"
	b.enemies[1].ailment_turns = 3
	b.enemies[1].ailment_damage = 5
	b.party[1].binds["arm"] = 2
	b.party[3].ailment = "paralysis"
	b.party[3].ailment_turns = 2
	Fx.apply_effect(s, b.party[2], OVERCLOCK)
	Fx.apply_effect(s, b.party[2], "skill.holo_knight.defense_protocol")
	return Fx.battle_clone(s)


func _display_sig(l: BattleLayer) -> Array:
	var out := []
	for u in l.display.party + l.display.enemies:
		out.append([u.name, u.hp, u.tp, u.charging, l.display.chip_texts(u)])
	return out


func test_reopen_from_same_save_shows_same_turn_start() -> void:
	var s := _status_state()
	var text := SaveCodec.encode(s)
	await _open(s)
	var sig := _display_sig(layer)
	check_eq(layer.display.chip_texts(layer.display.party[2]), ["▲공 3", "▲방 3"] as Array[String], "강화 딱지")
	check_eq(layer.display.chip_texts(layer.display.enemies[1]), ["부식 3", "다리 2"] as Array[String], "적 상태 딱지")
	check_eq(layer.display.enemies[0].charging, "skill.enemy.crush", "준비 표시")
	await _tap_btn("Cmd_guard")
	await _tap_btn("Cmd_attack")
	var r := SaveCodec.decode(text, s.defs)
	check(r.ok(), "저장 읽기")
	await _open(r.state)
	check_eq(_display_sig(layer), sig, "같은 저장 → 같은 상태 표·준비 표시")
	check_eq(layer.member, 0, "명령 입력 처음")
	check_eq(layer.commands, [null, null, null, null, null], "고르던 명령은 남지 않는다")


func test_victory_result_then_close() -> void:
	var s := _sure_state("formation.f1.rats")
	for u in s.battle.enemies:
		u.hp = 1
	await _open(s)
	# HP 1 쥐 셋(모두 전열)마다 하나씩 겨눈 공격: 순서와 상관없이 셋 다 맞아 그 턴에 승리(구성).
	layer.handle("commands", [{"kind": "attack", "target": 0}, {"kind": "attack", "target": 1}, {"kind": "attack", "target": 2},
		{"kind": "guard"}, {"kind": "guard"}])
	check_eq(layer.phase, "result", "승리 결과 창")
	check(s.battle == null and not s.encounter.pending, "전투가 끝났다")
	check(_btn("ResultOk").is_visible_in_tree(), "확인 단추")
	check_eq(layer.outcome, "victory", "결과")
	await kit.press_key(KEY_3)
	check_eq(layer.phase, "result", "결과 창에서 다른 키는 버린다")
	await _tap_btn("ResultOk")
	check_eq(closed_with, ["victory"] as Array[String], "닫히며 승리를 알린다")
	check(not layer.visible and not layer.is_open(), "층이 닫혔다")


func test_wipe_closes_without_result() -> void:
	var s := _state()
	var b := s.battle
	for i in 4:
		b.party[i].hp = 0
	b.party[4].hp = 1
	b.party[4].ailment = "poison"
	b.party[4].ailment_turns = 3
	b.party[4].ailment_damage = 5
	s = Fx.battle_clone(s)
	await _open(s)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check(s.wiped, "전멸")
	check_eq(closed_with, ["wiped"] as Array[String], "결과 창 없이 바로 닫힌다(미궁 화면이 전멸 창)")
	check(not layer.result_panel.visible, "결과 창 없음")


func test_turn_cap_result() -> void:
	var s := _calm_state()  # 그 턴에 승리·전멸이 먼저 오지 않는다(구성): 턴 상한만 끝을 정한다
	s.battle.turn = BattleLimits.TURN_MAX
	s = Fx.battle_clone(s)
	await _open(s)
	for i in 5:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.phase, "result", "턴 상한 결과 창")
	check_eq(layer.end_event.get("reason"), "turn_cap", "battle_end.reason")
	check_eq(layer._result_title.text, texts.t("battle.result.ended"), "제목")
	check(layer._result_body.text.contains(texts.t("battle.result.turn_cap")), "턴 상한 안내")
	await kit.press_key(KEY_ENTER)
	check_eq(closed_with, ["escaped"] as Array[String], "도주로 끝")


func test_log_window_blocks_commands() -> void:
	var s := _state()
	await _open(s)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_L)
	check(layer.log_view.visible, "L: 로그 창")
	await kit.press_key(KEY_3)
	await kit.tap(kit.center_of(layer.panel))
	check_eq(layer.member, 1, "로그 창이 열려 있는 동안 명령 입력은 막힌다")
	await _tap_btn("LogClose")
	check(not layer.log_view.visible, "닫기")
	await _tap_btn("LogButton")
	check(layer.log_view.visible, "로그 단추")
	await kit.press_key(KEY_ESCAPE)
	check(not layer.log_view.visible, "Esc 로 닫힘")
	check_eq(layer.member, 1, "Esc 는 로그만 닫는다")


func test_log_lines_and_debug_detail() -> void:
	var s := _sure_state(RATS_MOTH, 5)  # 나이트 공격이 반드시 맞아 피해 계산(final=)이 로그에 붙는다
	await _open(s)
	layer.debug = true
	layer.handle("commands", [{"kind": "attack", "target": 0}, {"kind": "guard"}, {"kind": "guard"}, {"kind": "guard"}, {"kind": "guard"}])
	var lines := layer.log_view.lines
	check(lines.size() >= 3, "로그 줄")
	var action := texts.t("battle.event.action", {"actor": layer.display.party[0].name, "skill": texts.t("battle.attack")})
	check(lines.has(action), "행동 줄: " + action)
	check(lines.any(func(t: String) -> bool: return t.contains("[") and t.contains("final=")), "디버그: 판정 이유")
	for i in 120:
		layer.log_view.add_line("x")
	check_eq(layer.log_view.lines.size(), BattleLogView.MAX_LINES, "지난 100줄")


func test_party_band_follows_effective_row() -> void:
	var s := _state()
	await _open(s)
	check_eq(layer.party_cards.band_of(3), texts.t("battle.ui.back_row"), "후열 띠")
	for i in 3:
		s.battle.party[i].hp = 0
	var s2 := Fx.battle_clone(s)
	await _open(s2)
	check_eq(layer.party_cards.band_of(3), texts.t("battle.ui.front"), "전열이 모두 쓰러지면 뒤 둘의 띠가 「전열」")
	check_eq(layer.member, 3, "명령은 살아 있는 대원부터")


## 모든 보이는 단추가 64×64 이상, 적 칸 150 이상, 서로 겹치지 않는다.
func _check_layout(label: String) -> void:
	var bs := layer.visible_buttons()
	check(not bs.is_empty(), label + ": 단추가 있다")
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for b in bs:
		var r := b.get_global_rect()
		check(r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s 크기 %s" % [label, b.name, str(r.size)])
		if b is BattleCard and (b as BattleCard).is_enemy():
			check(r.size.x >= 150.0 and r.size.y >= 150.0, "%s: 적 칸 %s" % [label, str(r.size)])
		check(Rect2(Vector2.ZERO, layer.size).encloses(r), "%s: %s 화면 안" % [label, b.name])
		for i in rects.size():
			check(not rects[i].intersects(r), "%s: %s 와 %s 가 겹친다" % [label, names[i], b.name])
		rects.append(r)
		names.append(b.name)


func test_layout_sizes_at_base_and_wide() -> void:
	for size in [Vector2(1280, 720), Vector2(1728, 720)]:
		var s := _state()
		s.battle.party[3].hp = 0  # 대상 줄에 쓰러진 칸도 둔다
		s = Fx.battle_clone(s)
		await _open(s, 0.0, size)
		var tag := "%dx%d" % [size.x, size.y]
		check_eq(layer.size, size, tag + ": 층 크기")
		_check_layout(tag + " 메뉴")
		layer.handle("command", 1)
		await kit.frames(1)
		_check_layout(tag + " 스킬")
		layer.handle("back")
		await kit.frames(1)
		layer.handle("command", 0)
		await kit.frames(1)
		_check_layout(tag + " 대상")
		layer.handle("back")
		for i in 4:
			await kit.frames(1)
			if layer.member == 4:
				layer.handle("command", 1)
				await kit.frames(1)
				_check_layout(tag + " 위저드 스킬 넷")
				layer.handle("back")
				await kit.frames(1)
			layer.handle("command", 2)
		await kit.frames(1)
		check_eq(layer.sub, "confirm", tag + ": 실행 단계")
		_check_layout(tag + " 실행")
		layer.handle("log")
		await kit.frames(1)
		_check_layout(tag + " 로그")


# ---- 미궁 화면 연결 (06 §8·§9.1·§10.3, M2-B2) ----

var screen: DungeonScreen


func _screen() -> DungeonScreen:
	timeout_sec = 30.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	screen = await kit.open()
	return screen


## 위험도를 한계 바로 밑에 두고 북쪽으로 (2,15)까지 → 안전 구역을 벗어난 첫 걸음에 전투.
func _walk_into_battle(s: DungeonScreen) -> void:
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for i in 6:
		if s.state.party.at.y <= 15 or s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)


## 결과가 구성으로 정해지는 승리(전투 승패·밸런스와 무관): 디버그 요청 battle_finish(전투 층 → 규칙의 finish → 저장 → 연출 →
## 결과 창) 뒤 결과 창을 Enter 로 닫는다. 화면은 디버그 주소로 연 것이어야 한다.
func _finish_battle(s: DungeonScreen) -> void:
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
	check(typeof(r) == TYPE_DICTIONARY and r.get("ok", false), "battle_finish: %s" % str(r))
	await kit.frames(2)
	check_eq(s.battle_layer.phase, "result", "battle_finish → 결과 창")
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)


func _explore_ui_visible(s: DungeonScreen) -> Array[Control]:
	var out: Array[Control] = []
	for c in [s.map, s.toolbar, s.status, s.menu_button, s.map_button, s.rest_button] + s.pad.values():
		if (c as Control).is_visible_in_tree():
			out.append(c)
	return out


func test_encounter_opens_layer_and_hides_explore_ui() -> void:
	var s := await _screen_with_query("debug=1")
	var rect := s.view_container.get_global_rect()
	var sv_size := (s.view_container.get_child(0) as SubViewport).size
	await _walk_into_battle(s)
	check(s.state.encounter.pending and s.battle_layer.is_open(), "인카운트 → 전투 층")
	check_eq(s.modal.kind, "", "M1 자리표시 전투 창은 없다")
	check(_explore_ui_visible(s).is_empty(), "지도·도구 줄·이동 단추·메뉴·상태 표시를 감춘다: %s" % str(_explore_ui_visible(s).map(func(c): return c.name)))
	var cam := s.view.camera_transform()
	check_eq(s.view_container.get_global_rect(), rect, "3D 시야 사각형은 그대로")
	check_eq((s.view_container.get_child(0) as SubViewport).size, sv_size, "시야 해상도 그대로")
	check(s.battle_layer.get_index() < s._toast.get_index() and s._toast.get_index() < s.modal.get_index(), "층 순서: 전투 층 < 알림 줄 < 창")
	await _finish_battle(s)
	check(not s.battle_layer.is_open() and not s.state.encounter.pending, "전투 끝 → 탐색")
	check_eq(s.view_container.get_global_rect(), rect, "전투 뒤에도 시야 사각형 그대로")
	check_eq(s.view.camera_transform(), cam, "카메라 자세는 전투 전후 같다")
	check(s.map.is_visible_in_tree() and s.menu_button.is_visible_in_tree() and s.pad[A_FORWARD].is_visible_in_tree(), "탐색 부품이 다시 보인다")

const A_FORWARD := ExplorationRules.Action.FORWARD


func test_victory_resumes_movement_and_held_key_does_not_step() -> void:
	var s := await _screen_with_query("debug=1")
	await _walk_into_battle(s)
	check(s.battle_layer.is_open(), "전투")
	var at := s.state.party.at
	kit.key(KEY_W, true)  # 전투 중 누르고 있는 이동 키
	await kit.frames(2)
	await _finish_battle(s)
	check_eq(s.battle_layer.outcome, "victory", "battle_finish 로 승리(구성으로 정해짐)")
	check(not s.battle_layer.is_open(), "결과 창을 닫아 층이 닫혔다")
	for i in 20:
		await kit.frames(1)
	check_eq(s.state.party.at, at, "누르고 있던 이동 키가 걸음으로 이어지지 않는다")
	kit.key(KEY_W, false)
	await kit.frames(1)
	await kit.press_key(KEY_W)
	check(s.state.party.at != at, "다시 누르면 이동한다")


## 미궁 화면보다 늦게 _unhandled_input 을 받는 노드(트리 맨 앞). 전투 중 키가 여기까지 오면 전투 층이 키를 놓친 것이다.
func _key_probe() -> Node:
	var gd := GDScript.new()
	gd.source_code = "extends Node\nvar seen := 0\nfunc _unhandled_input(e: InputEvent) -> void:\n\tif e is InputEventKey and e.pressed:\n\t\tseen += 1\n"
	gd.reload()
	var probe := Node.new()
	probe.set_script(gd)
	probe.name = "KeyProbe"
	tree.root.add_child(probe)
	tree.root.move_child(probe, 0)
	return probe


func test_menu_is_blocked_during_battle() -> void:
	var s := await _screen()
	var probe := _key_probe()
	await kit.press_key(KEY_M)
	check_eq(probe.get("seen"), 0, "탐색 중 지도 키는 미궁 화면이 받는다")
	await kit.press_key(KEY_F9)
	check_eq(probe.get("seen"), 1, "미궁 화면이 받지 않는 키는 뒤로 간다(탐지 노드 확인)")
	await _walk_into_battle(s)
	var seen: int = probe.get("seen")
	for k in [KEY_F9, KEY_W, KEY_M, KEY_ESCAPE, KEY_SPACE]:
		await kit.press_key(k)
	check_eq(probe.get("seen"), seen, "전투 중 누른 키는 전투 층에서 끝난다")
	tree.root.remove_child(probe)
	probe.free()
	await kit.press_key(KEY_ESCAPE)
	check_eq(s.modal.kind, "", "Esc 로 메뉴가 열리지 않는다")
	s._open_menu()
	check_eq(s.modal.kind, "", "메뉴 함수도 열지 않는다")
	check(not s.menu_button.is_visible_in_tree(), "메뉴 단추 없음")
	await kit.press_key(KEY_SPACE)
	await kit.press_key(KEY_R)
	check(s.state.encounter.pending, "조사·휴식 키도 전투 층이 받는다")


func test_wipe_opens_m1_wipe_window() -> void:
	var s := await _screen()
	var copy := SaveCodec.decode(SaveCodec.encode(s.state), s.store.defs).state
	copy.encounter.danger = copy.encounter.threshold
	BattleRules.start(copy, "formation.f1.rats")
	for i in 4:
		copy.party.members[i].hp = 0
	copy.party.members[4].hp = 1
	var w := copy.battle.party[4]
	w.ailment = "poison"
	w.ailment_turns = 3
	w.ailment_damage = 5
	check(s.import_text(SaveCodec.encode(copy)), "준비한 저장 가져오기(전투 중, 넷 쓰러짐, 하나 HP 1 독)")
	check(s.battle_layer.is_open() and s.battle_layer.member == 4, "가져오면 전투 층, 남은 대원부터")
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	check(s.state.wiped, "그 턴 안에 전멸")
	check(not s.battle_layer.is_open(), "전투 층 닫힘")
	check_eq(s.modal.kind, "wipe", "M1 전멸 창")


func test_rest_button_only_on_start_cell() -> void:
	var s := await _screen()
	check(s.rest_button.is_visible_in_tree(), "시작 칸에서 휴식 단추")
	for m in s.state.party.members:
		m.hp = 1
		m.tp = 0
	s.state.party.members[0].hp = 0
	var n := s.autosave_count
	var danger := s.state.encounter.danger
	var rng := s.state.rng.get_state()
	await kit.tap(kit.center_of(s.rest_button))
	check(s.state.party.members.all(func(m: PartyState.Member) -> bool: return m.hp == m.max_hp and m.tp == m.max_tp), "HP·TP 최대(쓰러진 대원도)")
	check_eq(s.autosave_count, n + 1, "휴식은 자동 저장")
	check(s.state.encounter.danger == danger and s.state.rng.get_state() == rng, "위험도·난수 그대로")
	await kit.press_key(KEY_W)
	check(not s.rest_button.is_visible_in_tree(), "시작 칸이 아니면 단추 없음")
	s.state.party.members[1].hp = 3
	await kit.press_key(KEY_R)
	check_eq(s.state.party.members[1].hp, 3, "시작 칸 밖 R 은 쉬지 않는다")
	check_eq(s._toast.text, texts.t("msg.not_rest_point"), "쉴 수 없다는 알림")
	await kit.press_key(KEY_S)
	await kit.press_key(KEY_R)
	check_eq(s.state.party.members[1].hp, s.state.party.members[1].max_hp, "시작 칸에서 R")
	await _walk_into_battle(s)
	check(not s.rest_button.is_visible_in_tree(), "전투 중 휴식 단추 없음")


func test_save_failure_notice_shows_over_battle() -> void:
	var s := await _screen()
	await _walk_into_battle(s)
	s.store.fail_points.append("write")
	s.battle_layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
	await kit.frames(2)
	check(s.last_autosave_error != "", "저장 실패")
	check(s._toast.text.begins_with(texts.t("msg.save_failed", {"reason": ""})), "저장 실패 알림")
	check(s._toast.is_visible_in_tree() and s._toast.get_global_rect().position.y >= BattleLayer.TOP_H, "알림 줄은 전투 층 위·알림 줄 아래에 보인다")


func test_reload_during_battle_animation_restores_layer() -> void:
	var s := await _screen()
	await _walk_into_battle(s)
	s.battle_layer.anim_speed = 0.1
	s.battle_layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
	await kit.frames(1)
	var h := kit.hash_now()
	check(s.battle_layer.is_busy(), "연출 중")
	check_eq(kit.auto_generation(), s.state.generation, "연출 전에 이미 저장했다")
	s = await kit.reopen()
	check_eq(kit.hash_now(), h, "새로고침 뒤 같은 상태")
	if s.state.encounter.pending:
		check(s.battle_layer.is_open() and s.battle_layer.phase == "command" and s.battle_layer.member >= 0, "전투 층 명령 입력 처음")
	else:
		check(not s.battle_layer.is_open(), "전투가 그 턴에 끝났으면 탐색")


## 디버그 battle_auto: 기본 정책 명령을 전투 층의 명령 입구로 낸다(같은 저장·연출). 자연 전투라 몇 턴에 어떻게 끝날지는 단언하지
## 않는다(D15): 많아야 AUTO_TURNS 턴 내고, 아직 전투 중이면 battle_finish 로 끝낸다. 끝난 결과에 맞는 길(승리·도주·턴 상한 → 결과 창
## 「확인」 → 탐색, 전멸 → 결과 창 없이 전멸 창)과 입력 수·자동 저장 = 화면 상태를 본다.
const AUTO_TURNS := 3
func test_debug_battle_auto_plays_to_an_end() -> void:
	var s := await _screen_with_query("debug=1")
	await _walk_into_battle(s)
	var snap := s.debug_snapshot()
	check(snap["battle"]["open"] and snap["buttons"].has("Cmd_attack") and snap["buttons"].has("Enemy_0"), "상태 요약에 전투 정보·단추 좌표")
	check(not snap["buttons"].has("MenuButton") and not snap["buttons"].has("Pad_forward"), "감춘 단추는 요약에 없다")
	var hash_before := kit.hash_now()
	var sim: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "simulate", "actions": ["back"]})))
	check(typeof(sim) == TYPE_DICTIONARY and sim.get("hashes", []).size() == 1, "전투 중 simulate: %s" % str(sim))
	check_eq(kit.hash_now(), hash_before, "simulate 는 진짜 상태를 바꾸지 않는다")
	var inputs := s.battle_layer.accepted_inputs
	var saves := s.autosave_count
	var submits := 0
	var results := 0
	for i in AUTO_TURNS:
		if not s.battle_layer.is_open() or s.battle_layer.phase != "command":
			break
		var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_auto"})))
		check(r.get("ok", false), "battle_auto 받아들임")
		submits += 1
		await kit.frames(2)
	check(submits >= 1 and s.autosave_count == saves + submits, "battle_auto 한 번마다 자동 저장 한 번(%d번)" % submits)
	if s.battle_layer.is_open() and s.battle_layer.phase == "command":
		var f: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
		check(f.get("ok", false), "아직 전투 중이면 battle_finish 로 끝낸다")
		submits += 1
		await kit.frames(2)
	if s.battle_layer.is_open() and s.battle_layer.phase == "result":
		results += 1
		await kit.press_key(KEY_ENTER)
	check(not s.state.encounter.pending and not s.battle_layer.is_open(), "전투가 끝났다")
	var outcome := s.battle_layer.outcome
	check(["victory", "escaped", "wiped"].has(outcome), "끝난 결과: " + outcome)
	if outcome == "wiped":
		check(results == 0 and s.state.wiped and s.modal.kind == "wipe", "전멸 → 결과 창 없이 전멸 창")
	else:
		check(results == 1 and not s.state.wiped and s.modal.kind == "", "%s → 결과 창 「확인」 → 탐색" % outcome)
	check_eq(s.battle_layer.accepted_inputs - inputs, submits + results, "명령 입구가 받은 입력 = 제출 + 결과 확인")
	_check_auto_matches_screen(s)
	var r2: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_auto"})))
	check(r2.has("error"), "전투가 없으면 battle_auto 는 오류")


## simulate 는 전투를 battle_finish 와 같은 규칙의 finish(승리)로 넘긴다: battle_finish 로 넘긴 실제의 행동마다 해시 = simulate
## (전투 승패·밸런스와 상관없이 같다).
func test_simulate_resolves_battles_like_battle_finish() -> void:
	var s := await _screen_with_query("debug=1")
	s.state.encounter.danger = s.state.encounter.threshold - 1
	var actions := ["forward", "forward", "forward", "turn_right", "turn_left", "back"]
	var sim: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "simulate", "actions": actions})))
	check(typeof(sim) == TYPE_DICTIONARY and sim.get("hashes", []).size() == actions.size(), "simulate: %s" % str(sim))
	var real := []
	var battles := 0
	for a in actions:
		if s.battle_layer.is_open():
			battles += 1
			await _finish_battle(s)
		var before := s.state.generation
		s.request_action(ExplorationRules.action_from_name(a))
		await kit.frames(3)
		check(s.state.generation > before, "행동 " + a)
		real.append(kit.hash_now())
	check(battles >= 1, "사이에 전투가 있었다")
	check_eq(real, sim.get("hashes", []), "행동마다의 해시: battle_finish 로 넘긴 실제 = simulate")


func test_start_error_is_shown() -> void:
	timeout_sec = 20.0
	kit = Kit.new(tree)
	screen = Kit.SCREEN.instantiate()
	screen.save_dir = kit.dir + "/saves"
	screen.settings_path = kit.dir + "/settings.json"
	screen.platform = "native"
	screen.party_path = "res://data/party/does_not_exist.json"
	kit.screen = screen
	tree.root.add_child(screen)
	await kit.frames(3)
	check(screen.state == null, "게임은 시작하지 않는다")
	check(screen.start_error != null and screen.start_error.is_visible_in_tree(), "오류 화면")
	var list := screen.find_child("StartErrorList", true, false) as Label
	check(list != null and list.text.contains("does_not_exist"), "오류 목록에 파일 경로: %s" % (list.text if list != null else "없음"))
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(2)
	check(not DirAccess.dir_exists_absolute(kit.dir + "/saves"), "저장하지 않는다")


## 피해 숫자(06 §9.3): 앞 단계 숫자는 지우고 쌓지 않는다. 약점·치명은 숫자에 붙는 작은 글자.
func test_damage_popups_do_not_pile_up() -> void:
	var s := _state()
	await _open(s, 1.0)
	var c := _enemy(0)
	c.pop("36", Color.WHITE, "치명!")
	await tree.create_timer(0.2).timeout
	c.pop("24", Color.WHITE)
	check_eq(c.popups.size(), 1, "앞 단계 숫자는 지운다")
	check_eq(c.popups[0]["row"], 0, "새 숫자는 첫 줄")
	c.pop("+5", Color.GREEN)
	check_eq(c.popups.size(), 2, "같은 순간의 숫자 둘은 함께")
	var ev := {"type": "damaged", "target": {"side": "enemy", "slot": 1}, "amount": 12, "weak": true, "crit": true, "immune": false}
	layer._popup_for(ev)
	var p: Dictionary = _enemy(1).popups[0]
	check(_enemy(1).popups.size() == 1 and p["text"] == "12" and str(p["sub"]).contains(texts.t("battle.popup.weak")) and str(p["sub"]).contains(texts.t("battle.popup.crit")),
		"피해 한 번 = 숫자 하나 + 약점·치명 작은 글자: %s" % str(_enemy(1).popups))


func _check_auto_matches_screen(s: DungeonScreen) -> void:
	check_eq(kit.auto_generation(), s.state.generation, "자동 저장 세대 = 화면")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), "자동 저장 내용 = 화면 상태")


# ---- 독립 검토 B1 고친 뒤 시험 ----

## 메딕(칸 3)의 나노 리페어 대상 고르기까지.
func _medic_repair_target() -> void:
	for i in 3:
		await kit.press_key(KEY_3)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	check_eq(layer.sub, "target", "메딕 회복 대상 고르기")
	check_eq(layer.target_skill, REPAIR, "나노 리페어")


## 검토 1: 로그 창이 열린 동안(또는 열기 전) 시작한 카드 누르기가 창을 닫은 뒤 대상을 확정하지 않는다.
func test_card_press_does_not_survive_log_window() -> void:
	await _open(_state())
	await _medic_repair_target()
	var p := kit.center_of(_member(1))
	# ① 로그가 열린 동안 누르기 시작 → 닫고 → 칸 안에서 뗌
	await kit.press_key(KEY_L)
	check(layer.log_view.visible and _member(1).disabled, "로그 창 중 칸은 누르기를 받지 않는다")
	kit.touch(0, p, true)
	await kit.frames(2)
	await kit.press_key(KEY_L)
	check(not layer.log_view.visible and layer.sub == "target", "로그 닫음, 대상 고르기 그대로")
	kit.touch(0, p, false)
	await kit.frames(3)
	check(layer.commands[3] == null, "로그 창 중 시작한 누르기는 대상이 되지 않는다")
	# ② 대상 고르기 중 누르기 시작 → 로그 열고 닫음 → 뗌
	kit.touch(0, p, true)
	await kit.frames(2)
	check(_member(1).held, "칸이 눌림")
	await kit.press_key(KEY_L)
	check(not _member(1).held, "로그를 열면 눌림을 버린다")
	await kit.press_key(KEY_L)
	kit.touch(0, p, false)
	await kit.frames(3)
	check(layer.commands[3] == null, "문맥이 바뀌기 전에 시작한 누르기는 대상이 되지 않는다")
	# 마우스도 같다
	kit.mouse(p, true)
	await kit.frames(1)
	await kit.press_key(KEY_L)
	await kit.press_key(KEY_L)
	kit.mouse(p, false)
	await kit.frames(3)
	check(layer.commands[3] == null, "마우스 누르기도 같다")
	# 새 누르기는 된다
	await kit.tap(p)
	check_eq(layer.commands[3], {"kind": "skill", "skill": REPAIR, "target": 1}, "새 누르기는 대상 확정")


## 검토 1: 대상·대원이 바뀌는 사이 이어진 누르기는 새 문맥의 대상이 되지 않는다.
func test_card_press_across_member_change() -> void:
	await _open(_state())
	await kit.press_key(KEY_3)  # 나이트 방어
	await kit.press_key(KEY_1)  # 듀얼 A 공격 → 대상
	check(not _enemy(0).disabled, "대상 고르기 중 적 칸은 누를 수 있다")
	check(_member(0).disabled, "적 대상일 때 파티 칸은 누르지 않는다")
	var p := kit.center_of(_enemy(0))
	kit.touch(0, p, true)
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)  # 대상 → 메뉴
	check(_enemy(0).disabled and not _enemy(0).held, "메뉴에서 적 칸은 누르지 않고 눌림도 버린다")
	await kit.press_key(KEY_ESCAPE)  # 메뉴 → 나이트
	await kit.press_key(KEY_1)  # 나이트 공격 → 대상
	check(layer.member == 0 and layer.sub == "target", "나이트 대상 고르기")
	kit.touch(0, p, false)
	await kit.frames(3)
	check(layer.commands[0] == null and layer.sub == "target", "앞 대원 때 시작한 누르기는 나이트의 대상이 되지 않는다")
	# 대상 확정으로 대원이 넘어가는 사이: 다른 손가락으로 누른 채 첫 손가락이 확정
	var q := kit.center_of(_enemy(1))
	kit.touch(1, q, true)
	await kit.frames(1)
	await kit.tap(kit.center_of(_enemy(0)))
	check_eq(layer.commands[0], {"kind": "attack", "target": 0}, "나이트 대상 확정")
	check_eq(layer.member, 1, "듀얼 A 차례")
	await kit.press_key(KEY_1)  # 듀얼 A 공격 → 대상
	kit.touch(1, q, false)
	await kit.frames(3)
	check(layer.commands[1] == null, "나이트 문맥에서 시작한 둘째 손가락은 듀얼 A 의 대상이 되지 않는다")


## 검토 2용: 규칙상 동시에 가질 수 있는 최대 상태(상태이상 1 + 봉인 3 + 강화 칸 3 + 약화 칸 3). 폭이 가장 넓은 글자(속공·속방, 남은 턴 9).
func _max_status_state() -> ExplorationState:
	var s := _state()
	var b := s.battle
	var rules := s.defs.battle.rules
	check_eq([rules.buff_slots, rules.debuff_slots], [3, 3], "M2 규칙: 강화·약화 칸 3·3")
	var seq := 1
	for u in [b.party[2], b.party[4]]:
		u.ailment = "paralysis"
		u.ailment_turns = 9
		for part in BattleLimits.PARTS:
			u.binds[part] = 9
		u.buffs.clear()
		u.debuffs.clear()
		for k in ["elem_atk", "elem_def", "phys_atk"].slice(0, rules.buff_slots):
			u.buffs.append({"id": "skill.t.b_" + k, "kind": k, "value": 1300, "turns": 9, "seq": seq})
			seq += 1
		for k in ["elem_def", "elem_atk", "phys_def"].slice(0, rules.debuff_slots):
			u.debuffs.append({"id": "skill.t.d_" + k, "kind": k, "value": 700, "turns": 9, "seq": seq})
			seq += 1
	# 적은 강화·약화를 받지 않는다(USER_EFFECTS): 상태이상 1 + 봉인 3 이 최대.
	for u in [b.enemies[0], b.enemies[2]]:
		u.ailment = "poison"
		u.ailment_turns = 9
		u.ailment_damage = 9999
		for part in BattleLimits.PARTS:
			u.binds[part] = 9
	return s


func _check_chips_drawn(c: BattleCard, label: String) -> void:
	var u := c.unit()
	var want := layer.display.chips(u)
	var drawn := c.drawn_chips()
	check_eq(drawn.size(), want.size(), label + ": 그려지는 딱지 수 = 상태 수")
	var area := c.chip_area()
	var card := Rect2(Vector2.ZERO, c.size)
	for i in drawn.size():
		var d: Dictionary = drawn[i]
		check(d["kind"] != "more", label + ": 넘침 없음")
		if i < want.size():
			check_eq(d["text"], want[i]["text"], label + ": 딱지 %d 글자" % i)
		var r: Rect2 = d["rect"]
		check(area.encloses(r) and card.encloses(r), "%s: 딱지 %s 가 칸 안 %s" % [label, d["text"], str(r)])
		for j in i:
			check(not (drawn[j]["rect"] as Rect2).intersects(r), "%s: 딱지 %d·%d 겹침" % [label, j, i])


## 검토 2: 최대 상태가 1280×720·화면비 2.4 모두에서 빠짐없이 그려진다(실제 배치 rect 로 확인).
func test_max_status_chips_all_drawn() -> void:
	for size in [Vector2(1280, 720), Vector2(1728, 720)]:
		await _open(_max_status_state(), 0.0, size)
		var tag := "%dx%d" % [size.x, size.y]
		check_eq(layer.display.chips(layer.display.party[2]).size(), 10, tag + ": 아군 최대 10")
		_check_chips_drawn(_member(2), tag + " 듀얼 B")
		_check_chips_drawn(_member(4), tag + " 위저드")
		_check_chips_drawn(_enemy(0), tag + " 전열 적(200)")
		_check_chips_drawn(_enemy(2), tag + " 후열 적(150)")
		check(_member(2).chip_area().position.y >= 97.0, tag + ": 딱지는 TP 막대 아래")
		var st := layer.status_text()
		for t in layer.display.chip_texts(layer.display.party[2]):
			check(st.contains(t.replace("▲", "↑").replace("▼", "↓")), tag + ": 로그 창 상태 목록에 " + t)
		var enemy_line: String = st.split("\n")[5]
		check(not enemy_line.contains("HP"), tag + ": 적 줄에 HP 숫자 없음(D13): " + enemy_line)


## 검토 2: 자리보다 많으면 「+N」으로 남은 개수를 보인다(조용히 버리지 않는다).
func test_chip_overflow_shows_count() -> void:
	await _open(_state())
	var font := layer.get_theme_default_font()
	var chips: Array[Dictionary] = []
	for i in 14:
		chips.append({"text": "속공 %d" % (i % 10), "kind": "buff" if i % 2 == 0 else "debuff"})
	var area := Rect2(10, 100, 200, BattleCard.CHIP_H * 2.0 + BattleCard.CHIP_GAP)
	var out := BattleCard.layout_chips(chips, area, font)
	var last: Dictionary = out[-1]
	check_eq(last["kind"], "more", "마지막은 +N")
	check_eq(int(last["hidden"]) + out.size() - 1, chips.size(), "보인 수 + 숨긴 수 = 전체")
	check_eq(last["text"], "+%d" % int(last["hidden"]), "+N 글자")
	for d in out:
		check(area.encloses(d["rect"]), "자리 안: %s" % str(d["rect"]))
	# 「+N」 자리가 없으면 앞 딱지를 하나 더 빼서라도 둔다.
	var one := Rect2(0, 0, BattleCard.chip_width(font, chips[0]), BattleCard.CHIP_H)
	var tight := BattleCard.layout_chips(chips.slice(0, 3), one, font)
	check_eq(tight.size(), 1, "딱지 하나 폭: +N 만")
	check_eq([tight[0]["kind"], tight[0]["hidden"], tight[0]["text"]], ["more", 3, "+3"], "+3")
	check(one.encloses(tight[0]["rect"]), "+N 도 자리 안")
	var fit := BattleCard.layout_chips(chips.slice(0, 2), area, font)
	check(fit.size() == 2 and fit.all(func(d: Dictionary) -> bool: return d["kind"] != "more"), "들어가면 +N 없음")


## 검토 3 ①③: 건너뛰지 않은 연출이 입력 없이 끝나 다음 턴 명령 입력이 되고, 화면 전체 = 규칙 상태.
func test_animation_finishes_on_its_own() -> void:
	var s := _calm_state()
	s.battle.party[0].hp = 1  # 적이 때리지 않으니 리페어로 오르는 파티 막대를 만든다
	await _open(s, 4.0)
	layer.handle("commands", [{"kind": "attack", "target": 0}, {"kind": "skill", "skill": OVERCLOCK}, {"kind": "attack", "target": 1},
		{"kind": "skill", "skill": REPAIR, "target": 0}, {"kind": "skill", "skill": HEAT, "target": 2}])
	check_eq(layer.phase, "anim", "연출 시작")
	var n := layer.accepted_inputs
	var t0 := Time.get_ticks_msec()
	while layer.phase == "anim" and Time.get_ticks_msec() - t0 < 15000:
		await kit.frames(1)
	check_eq(layer.phase, "command", "입력 없이 연출이 끝났다")
	check_eq(layer.accepted_inputs, n, "건너뛰기 입력 없음")
	check(layer.skip_catcher.visible == false, "건너뛰기 덮개 치움")
	var fresh := BattleDisplay.from_state(s, texts)
	check_eq(_sig_of(layer.display), _sig_of(fresh), "턴 끝 화면 전체(HP·TP·딱지·준비·턴) = 규칙 상태")
	for c in layer._all_cards():
		check(is_equal_approx(c.shown_hp, c.unit().hp) and is_equal_approx(c.shown_tp, c.unit().tp), "%s 막대 = 값" % c.name)


func _sig_of(d: BattleDisplay) -> Array:
	var out: Array = [d.turn, d.promoted.duplicate()]
	for u in d.party + d.enemies:
		out.append([u.name, u.hp, u.tp, u.ailment, u.ailment_turns, u.binds.duplicate(), d.chip_texts(u), u.charging])
	return out


## 검토 3 ②: 이벤트마다 화면 값이 그 이벤트 결과로 바뀐다(피해·TP·회복·소생·상태 걸림·풀림·봉인·강화·준비·해제·쓰러짐).
## 연출을 손으로 조금씩 진행하며, 지금까지 보인 이벤트로 따로 계산한 값과 화면 값을 매번 비교한다.
func test_animation_shows_each_event_result() -> void:
	var s := _state()
	s.battle.party[1].hp = 0
	s.battle.enemies[2].charging = ""
	s.battle.party[0].hp = 30
	await _open(s, 1.0)
	layer.set_process(false)
	var P := func(i: int) -> Dictionary: return {"side": "party", "slot": i}
	var E := func(i: int) -> Dictionary: return {"side": "enemy", "slot": i}
	var buff := {"id": OVERCLOCK, "kind": "phys_atk", "value": 1300, "turns": 3, "seq": 1}
	var hp0: int = s.battle.enemies[0].hp
	var evs: Array[Dictionary] = [
		{"type": "action", "unit": P.call(0), "kind": "attack", "skill": "attack", "tp": 0, "targets": [E.call(0)]},
		{"type": "damaged", "unit": P.call(0), "target": E.call(0), "amount": 20, "lost": 20, "hp": hp0 - 20, "weak": true, "crit": false, "immune": false},
		{"type": "action", "unit": P.call(2), "kind": "skill", "skill": OVERCLOCK, "tp": 4, "targets": [P.call(2)]},
		{"type": "buffed", "target": P.call(2), "list": "buffs", "effect": buff, "refreshed": false, "evicted": null},
		{"type": "action", "unit": E.call(2), "kind": "skill", "skill": "skill.enemy.corrode_powder", "tp": 0, "targets": [P.call(0)]},
		{"type": "ailment", "target": P.call(0), "id": "poison", "turns": 3, "p": 500},
		{"type": "bound", "target": P.call(0), "part": "arm", "turns": 2, "p": 500},
		{"type": "bound", "target": E.call(1), "part": "leg", "turns": 2, "p": 500},
		{"type": "bound", "target": E.call(1), "part": "head", "turns": 3, "p": 500},
		{"type": "ailment", "target": E.call(1), "id": "poison", "turns": 3, "p": 500},
		{"type": "charging", "unit": E.call(2), "skill": "skill.enemy.crush"},
		{"type": "action", "unit": P.call(3), "kind": "skill", "skill": "skill.nano_medic.reboot", "tp": 10, "targets": [P.call(1)]},
		{"type": "revived", "unit": P.call(3), "target": P.call(1), "hp": 13},
		{"type": "action", "unit": P.call(4), "kind": "skill", "skill": HEAT, "tp": 5, "targets": [E.call(0)]},
		{"type": "damaged", "unit": P.call(4), "target": E.call(0), "amount": 30, "lost": 30, "hp": hp0 - 50, "weak": false, "crit": true, "immune": false},
		{"type": "charge_lost", "unit": E.call(2), "skill": "skill.enemy.crush", "reason": "asleep"},
		{"type": "action", "unit": P.call(3), "kind": "skill", "skill": REPAIR, "tp": 5, "targets": [P.call(0)]},
		{"type": "cured", "unit": P.call(3), "target": P.call(0), "removed": ["poison"]},
		{"type": "healed", "unit": P.call(3), "target": P.call(0), "amount": 5, "hp": 35},
		{"type": "turn_end", "turn": 0},
		{"type": "poison_tick", "target": E.call(1), "amount": 7, "lost": 7, "hp": 1},
		{"type": "expired", "target": E.call(1), "what": "bind", "id": "leg"},
		{"type": "expired", "target": P.call(2), "what": "buff", "id": OVERCLOCK},
		{"type": "action", "unit": P.call(0), "kind": "attack", "skill": "attack", "tp": 0, "targets": [E.call(1)]},
		{"type": "damaged", "unit": P.call(0), "target": E.call(1), "amount": 9, "lost": 1, "hp": 0, "weak": false, "crit": false, "immune": false},
		{"type": "defeated", "target": E.call(1), "kill": {}},
	]
	var start := _expect_init(layer.display)
	layer.last_events = evs
	layer._start_anim(evs)
	var seen_mid := false
	var ticks := 0
	var most := 0
	while layer.phase == "anim" and ticks < 2000:
		layer._process(0.02)
		ticks += 1
		if layer.phase != "anim":
			break  # 끝나면 sync(state) 로 규칙 상태가 된다(만든 이벤트와 다르다)
		var applied := _applied_events()
		most = maxi(most, applied.size())
		var want := _expect(start, applied)
		for key in want:
			var u := layer.display.unit(want[key]["ref"])
			var got := {"hp": u.hp, "tp": u.tp, "ailment": u.ailment, "binds": u.binds.keys(), "buffs": u.buffs.map(func(e): return e["id"]), "charging": u.charging}
			for f in got:
				if f == "ref":
					continue
				if got[f] != want[key][f]:
					failures.append("이벤트 %d개 뒤 %s.%s: 기대 %s, 실제 %s" % [applied.size(), key, f, str(want[key][f]), str(got[f])])
		if layer.display.enemies[0].hp == hp0 - 20:
			seen_mid = true
		if failures.size() > 12:
			break
	check(seen_mid, "중간 값(첫 피해 뒤, 둘째 피해 전)이 화면에 보였다")
	check_eq(most, evs.size(), "연출 중에 모든 이벤트가 하나씩 화면에 반영됐다")
	check_eq(layer.phase, "command", "연출이 _process 로 끝까지 진행")


func _applied_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st in layer._steps:
		if st["started"] and not st["head"].is_empty():
			out.append(st["head"])
		if st["applied"]:
			out.append_array(st["details"])
	return out


func _expect_init(d: BattleDisplay) -> Dictionary:
	var out := {}
	for u in d.party + d.enemies:
		out["%s%d" % [u.side, u.slot]] = {"ref": u.ref(), "hp": u.hp, "tp": u.tp, "ailment": u.ailment, "binds": u.binds.keys(),
			"buffs": u.buffs.map(func(e): return e["id"]), "charging": u.charging}
	return out


## 화면과 따로 계산한 기대 값(이벤트 뜻: 06 §3 이벤트 형식).
func _expect(start: Dictionary, applied: Array[Dictionary]) -> Dictionary:
	var w := {}
	for k in start:
		w[k] = start[k].duplicate(true)
	var key := func(r: Dictionary) -> String: return "%s%d" % [r["side"], r["slot"]]
	for ev in applied:
		match str(ev["type"]):
			"action":
				var x: Dictionary = w[key.call(ev["unit"])]
				x["tp"] -= int(ev["tp"])
				if x["charging"] == ev["skill"]:
					x["charging"] = ""
			"damaged", "poison_tick", "healed", "revived":
				w[key.call(ev["target"])]["hp"] = ev["hp"]
			"defeated":
				var x: Dictionary = w[key.call(ev["target"])]
				x["hp"] = 0
				x["ailment"] = ""
				x["binds"] = []
				x["buffs"] = []
				x["charging"] = ""
			"ailment":
				w[key.call(ev["target"])]["ailment"] = ev["id"]
			"woke":
				w[key.call(ev["target"])]["ailment"] = ""
			"cured":
				w[key.call(ev["target"])]["ailment"] = ""
				w[key.call(ev["target"])]["binds"] = []
			"bound":
				var b: Array = w[key.call(ev["target"])]["binds"]
				if not b.has(ev["part"]):
					b.append(ev["part"])
			"buffed":
				var b: Array = w[key.call(ev["target"])]["buffs"]
				b.erase(ev["effect"]["id"])
				b.append(ev["effect"]["id"])
			"charging":
				w[key.call(ev["unit"])]["charging"] = ev["skill"]
			"charge_lost":
				w[key.call(ev["unit"])]["charging"] = ""
			"expired":
				var x: Dictionary = w[key.call(ev["target"])]
				match str(ev["what"]):
					"ailment":
						x["ailment"] = ""
					"bind":
						x["binds"].erase(ev["id"])
					"buff":
						x["buffs"].erase(ev["id"])
	return w


## 검토 3 ④: 건너뛰지 않은 승리 연출 끝(battle == null) 뒤의 HP·TP·적 HP·결과 창.
func test_battle_end_display_after_natural_finish() -> void:
	var s := _sure_state("formation.f1.rats")
	for u in s.battle.enemies:
		u.hp = 1
	await _open(s, 4.0)
	# HP 1 쥐마다 하나씩 겨눈 공격 셋(TP 스킬 둘 포함): 마지막 쥐가 쓰러질 때 승리이므로 셋 모두 실행된다(순서와 상관없음, 구성).
	layer.handle("commands", [{"kind": "attack", "target": 0}, {"kind": "skill", "skill": HIGH_SLASH, "target": 1}, {"kind": "guard"},
		{"kind": "guard"}, {"kind": "skill", "skill": HEAT, "target": 2}])
	var t0 := Time.get_ticks_msec()
	while layer.phase == "anim" and Time.get_ticks_msec() - t0 < 15000:
		await kit.frames(1)
	check_eq(layer.phase, "result", "입력 없이 결과 창")
	check(s.battle == null, "전투 상태는 지워졌다")
	for i in s.party.members.size():
		var m: PartyState.Member = s.party.members[i]
		var u := layer.display.party[i]
		check(u.hp == m.hp and u.tp == m.tp, "대원 %d 화면 HP·TP = 규칙 (%d/%d vs %d/%d)" % [i, u.hp, u.tp, m.hp, m.tp])
		check(is_equal_approx(_member(i).shown_hp, m.hp) and is_equal_approx(_member(i).shown_tp, m.tp), "대원 %d 막대" % i)
	check(s.party.members[1].tp < s.party.members[1].max_tp and s.party.members[4].tp < s.party.members[4].max_tp, "스킬 TP 가 화면에도 빠졌다")
	var hp: Array = layer.end_event["enemy_hp"]
	for j in hp.size():
		check_eq(layer.display.enemies[j].hp, hp[j], "적 %d 화면 HP = battle_end.enemy_hp" % j)
	for d in layer.end_event["drops"]:
		check(layer._result_body.text.contains(texts.t(str(d["item"]))), "결과 창 드롭: " + str(d["item"]))


# ---- 독립 검토 2차(Low)·웹 확인 고정 시드 ----

## 주소 인자 글(url_query, 브라우저의 ?debug=1&seed=N 대신)을 준 화면. kit 임시 폴더를 그대로 쓴다(앞 화면은 지운다 = 새로 고침).
func _screen_with_query(query: String) -> DungeonScreen:
	timeout_sec = 30.0
	if kit == null:
		kit = Kit.new(tree)
	if texts == null:
		texts = TextDb.load_path("res://data/text/ko.json")
	kit.close_screen()
	await kit.frames(1)
	var sc: DungeonScreen = Kit.SCREEN.instantiate()
	sc.save_dir = kit.dir + "/saves"
	sc.settings_path = kit.dir + "/settings.json"
	sc.platform = "native"
	sc.seed_override = 7
	sc.anim_speed = 0.0
	sc.url_query = query
	kit.screen = sc
	tree.root.add_child(sc)
	await kit.frames(2)
	screen = sc
	return sc


## 디버그 주소의 &seed=N 만 새 게임 시드를 정한다(debug=1 이 없거나 값이 틀리면 무시).
func test_debug_address_fixes_new_game_seed() -> void:
	var cases := [["debug=1&seed=41", 41, true], ["?debug=1&seed=0", 0, true], ["seed=41", 7, false], ["debug=0&seed=41", 7, false],
		["debug=1&seed=-3", 7, true], ["debug=1&seed=4x", 7, true], ["debug=1", 7, true], ["", 7, false],
		["debug=1&seed=4294967295", 4294967295, true], ["debug=1&seed=4294967296", 7, true],
		["debug=1&seed=99999999999999999999", 7, true], ["debug=1&seed=-99999999999999999999", 7, true]]
	for c in cases:
		if kit != null:
			kit.dispose()
		kit = Kit.new(tree)  # 빈 저장 폴더: 새 게임
		var s := await _screen_with_query(c[0])
		var want := SaveCodec.state_hash(ExplorationRules.new_game(s.store.defs, c[1], s.settings.automap))
		check_eq(SaveCodec.state_hash(s.state), want, "「%s」: 새 게임 시드 %d" % [c[0], c[1]])
		check_eq(s._debug, c[2], "「%s」: 디버그" % c[0])
		check_eq(s.debug_snapshot()["seed"], c[1], "「%s」: 상태 요약의 seed" % c[0])


## 시드 범위(검토 3차 Low): 0..SEED_MAX(새 게임 시드 fresh_seed 의 32비트 범위)만 받는다. 범위는 바꾸기 전에 글로 보므로
## int64 를 넘는 글도 상한값으로 바뀌지 않고 버린다.
func test_debug_seed_range() -> void:
	check_eq(WebBridge.SEED_MAX, 4294967295, "상한 = 2^32 - 1")
	var want := {"0": 0, "41": 41, "0041": 41, "000": 0, "4294967295": 4294967295, "04294967295": 4294967295,
		"4294967294": 4294967294, "4294967296": -1, "4294967300": -1, "9999999999": -1, "10000000000": -1,
		"99999999999999999999": -1, "9223372036854775807": -1, "9223372036854775808": -1,
		"-1": -1, "-99999999999999999999": -1, "+41": -1, " 41": -1, "41 ": -1, "4 1": -1, "41.0": -1, "1e3": -1,
		"0x29": -1, "": -1, "abc": -1, "٤١": -1}
	for t in want:
		check_eq(WebBridge.parse_seed(t), want[t], "parse_seed(「%s」)" % t)
	for q in ["debug=1&seed=4294967295", "debug=1&seed=4294967296", "debug=1&seed=99999999999999999999", "seed=4294967295"]:
		var b := WebBridge.new("native", q)
		var expect := 4294967295 if q == "debug=1&seed=4294967295" else -1
		check_eq(b.debug_seed(), expect, "debug_seed(%s)" % q)


## 디버그 요청 battle_finish: 전투 층의 입력 입구 → 규칙의 finish(승리) → 저장(연출 전) → 연출 → 결과 창 → 「확인」 → 탐색.
## 결과가 구성으로 정해진다(전투 승패·밸런스와 무관). 디버그 주소가 아니면 화면도 전투 층도 받지 않는다.
func test_debug_battle_finish_goes_through_layer() -> void:
	var plain := await _screen_with_query("")
	await _walk_into_battle(plain)
	check(plain.battle_layer.is_open() and not plain.battle_layer.debug, "디버그 주소가 아닌 전투")
	for op in ["battle_finish", "battle_auto"]:
		var r0: Variant = JSON.parse_string(plain._on_debug_request(JSON.stringify({"op": op})))
		check(r0.has("error") and plain.state.encounter.pending and plain.battle_layer.phase == "command", "디버그 주소가 아니면 %s 거부: %s" % [op, str(r0)])
	check(not plain.battle_layer.handle("finish", "victory"), "디버그가 아닌 전투 층은 끝내기 입력을 받지 않는다")
	var s := await _screen_with_query("debug=1")
	check(s.battle_layer.is_open() and s.battle_layer.debug and s.battle_layer.phase == "command", "디버그 주소로 다시 연 전투")
	s.battle_layer.anim_speed = 1.0
	var seen := []
	s.battle_layer.submitted.connect(func(ev: Array) -> void:
		seen.append({"phase": s.battle_layer.phase, "saved": kit.auto_generation() == s.state.generation, "types": ev.map(func(e: Dictionary) -> String: return e["type"])}))
	var n := s.autosave_count
	var inputs := s.battle_layer.accepted_inputs
	await kit.frames(1)
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
	check(r.get("ok", false), "battle_finish 받아들임: %s" % str(r))
	check_eq(s.battle_layer.accepted_inputs, inputs + 1, "전투 층의 입력 입구를 거쳤다")
	check(s.state.battle == null and not s.state.encounter.pending and not s.state.wiped, "규칙의 finish: 전투가 끝났다")
	check_eq(s.autosave_count, n + 1, "자동 저장 한 번")
	check(seen.size() == 1 and seen[0]["saved"] and seen[0]["types"].has("battle_end"), "제출과 같은 길: 저장 뒤 이벤트 열을 알린다: %s" % str(seen))
	check_eq(s.battle_layer.phase, "anim", "연출을 거친다")
	var t0 := Time.get_ticks_msec()
	while s.battle_layer.phase == "anim" and Time.get_ticks_msec() - t0 < 10000:
		await kit.frames(1)
	check_eq(s.battle_layer.phase, "result", "결과 창")
	check_eq(s.battle_layer.outcome, "victory", "승리")
	var ok_button := s.battle_layer.find_child("ResultOk", true, false) as TouchButton
	check(ok_button != null and ok_button.is_visible_in_tree(), "「확인」 단추")
	var r2: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
	check(r2.has("error") and s.battle_layer.phase == "result", "결과 창에서 다시 battle_finish 는 오류(전투 없음)")
	await kit.tap(kit.center_of(ok_button))
	check(not s.battle_layer.is_open() and s.modal.kind == "" and _explore_ui_visible(s).size() > 0, "「확인」 → 탐색")
	_check_auto_matches_screen(s)


## 디버그 주소에서 전투 중 새로 고침: 복구된 전투 층도 판정 상세(calc·hit_p)를 로그에 붙인다(디버그 여부를 시작 전에 정한다).
func test_restored_battle_keeps_debug_detail() -> void:
	var s := await _screen_with_query("debug=1")
	await _walk_into_battle(s)
	check(s.battle_layer.is_open() and s.battle_layer.debug, "디버그 주소: 전투 층 디버그")
	var h := kit.hash_now()
	s = await _screen_with_query("debug=1")
	check_eq(kit.hash_now(), h, "새로 고침 뒤 같은 상태")
	check(s.battle_layer.is_open() and s.battle_layer.phase == "command", "복구된 전투 층")
	check(s.battle_layer.debug, "복구된 전투 층도 디버그")
	s = await _screen_with_query("")
	check(s.battle_layer.is_open() and not s.battle_layer.debug, "디버그 주소가 아니면 상세 없음")
	s = await _screen_with_query("debug=1")
	check(s.battle_layer.is_open() and s.battle_layer.debug, "다시 디버그 주소로 복구")
	# 자연 정책 한 턴은 마지막에 둔다: 그 턴에 이어지든 끝나든(승리 결과 창·전멸로 닫힘) 그 턴의 로그 줄은 남는다.
	s.battle_layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
	await kit.frames(2)
	var lines := s.battle_layer.log_view.lines
	check(lines.any(func(t: String) -> bool: return t.contains("\n    [")), "복구된 전투의 로그에 판정 상세: %s" % str(lines.slice(0, 3)))


func _press_at(how: String, p: Vector2, pressed: bool) -> void:
	if how == "touch":
		kit.touch(0, p, pressed)
	else:
		kit.mouse(p, pressed)


## 검토 2차: 로그를 여닫는 문맥 전환은 그 전에 시작한 「로그」 단추 누르기도 버린다(카드 disabled·패널 _hide_all·로그 창 close 어느
## 쪽에도 걸리지 않는 단추). 닫힌 로그 → 「로그」를 누른 채 → 키보드 L 로 열기 → 단추 안에서 뗌 → 새로 열린 로그가 그대로.
func test_log_button_press_does_not_survive_log_toggle() -> void:
	await _open(_state())
	var lb := _btn("LogButton")
	var p := kit.center_of(lb)
	for how in ["touch", "mouse"]:
		check(not layer.log_view.visible, how + ": 로그 닫힘에서 시작")
		_press_at(how, p, true)
		await kit.frames(2)
		check(lb.held, how + ": 「로그」 눌림")
		await kit.press_key(KEY_L)
		check(layer.log_view.visible and not lb.held, how + ": L 로 열면 앞 문맥의 눌림을 버린다")
		_press_at(how, p, false)
		await kit.frames(3)
		check(layer.log_view.visible, how + ": 열기 전에 시작한 누르기를 떼도 새로 열린 로그가 닫히지 않는다")
		# 반대 방향: 열린 로그에서 누른 채 L 로 닫고 뗌 → 다시 열리지 않는다
		_press_at(how, p, true)
		await kit.frames(2)
		await kit.press_key(KEY_L)
		check(not layer.log_view.visible, how + ": L 로 닫힘")
		_press_at(how, p, false)
		await kit.frames(3)
		check(not layer.log_view.visible, how + ": 닫기 전에 시작한 누르기를 떼도 로그가 다시 열리지 않는다")
	await kit.tap(p)
	check(layer.log_view.visible, "새 누르기는 연다")


# ---- 결과 창의 경험치·레벨업 줄 (07 §3.5·§9.6·§10.4, G-B2) ----
# 성장 필드를 넣은 battle_end 를 층의 입구(_commit: 저장 갈고리 → 연출 → 결과 창)로 보낸다. 결과는 구성으로 정한다(D15).

const ITEMS := ["item.neon_rat_tail", "item.cable_scale", "item.glow_scale", "item.spore_pouch", "item.coated_scale",
	"item.drill_claw", "item.beetle_plate", "item.intact_pincer"]


func _exp_row(i: int, status: String = "received", gained: int = 7, capped: bool = false, from: int = 1, to: int = 1, sp: int = 0) -> Dictionary:
	return {"member": i, "status": status, "gained": gained, "capped": capped, "from": from, "to": to, "sp_gained": sp, "hp_gain": 0, "tp_gain": 0}


func _growth(rows: Array, total: int = 36) -> Dictionary:
	return {"exp_total": total, "exp_alive": 5, "exp_share": 7, "members": rows}


func _mname(i: int) -> String:
	return texts.t(Fx.defs().party.name_keys[i])


## 승리 결과 창을 띄운다. end 는 battle_end 에 더할 필드, before 는 그 앞 이벤트.
func _result_with(end: Dictionary, size: Vector2 = Vector2.ZERO, before: Array = [], outcome: String = "victory") -> void:
	var s := _calm_state()
	await _open(s, 0.0, size)
	var ev := {"type": "battle_end", "outcome": outcome, "drops": [], "enemy_hp": [0, 0, 0]}
	ev.merge(end, true)
	var events: Array[Dictionary] = []
	for e in before:
		events.append(e)
	events.append(ev)
	layer._commit(events)
	await kit.frames(2)
	check_eq(layer.phase, "result", "준비: 결과 창")


func test_result_exp_one_line_when_all_received_the_same() -> void:
	await _result_with(_growth([_exp_row(0), _exp_row(1), _exp_row(2), _exp_row(3), _exp_row(4)]))
	var lines := layer.result_lines
	check(lines.has("경험치 +7"), "한 줄 「경험치 +7」: %s" % str(lines))
	check_eq(lines.filter(func(l: String) -> bool: return l.contains("+7")).size(), 1, "대원마다 줄을 따로 내지 않는다")
	check(layer._result_body.text.contains("경험치 +7"), "본문 글")
	check(not lines.has("경험치") and not lines.has("레벨 업"), "한 줄 꼴에는 머리 줄이 없다(레벨업도 없다)")


func test_result_exp_per_member_lines_when_mixed() -> void:
	var rows := [_exp_row(0, "received", 9), _exp_row(1, "received", 3, true), _exp_row(2, "down", 0),
		_exp_row(3, "at_cap", 0, true, 30, 30), _exp_row(4, "received", 7)]
	await _result_with(_growth(rows))
	var want: Array[String] = ["%s +9" % _mname(0), "%s +3(레벨 상한)" % _mname(1), "%s 받지 못함(전투 불능)" % _mname(2),
		"%s 받지 못함(레벨 상한)" % _mname(3), "%s +7" % _mname(4)]
	var got := layer.result_lines.filter(func(l: String) -> bool: return want.has(l))
	check_eq(got, want, "대원마다 한 줄, 칸 순, §3.5 문구")
	check(not layer.result_lines.has("경험치 +7"), "한 줄 요약은 없다")
	check_eq(layer.result_lines.find("경험치"), layer.result_lines.find(want[0]) - 1, "대원별 줄 바로 위에 머리 「경험치」")
	check(not layer.result_lines.has("레벨 업"), "오른 대원이 없으면 「레벨 업」 머리도 없다")


func test_result_has_no_exp_line_when_total_is_zero() -> void:
	await _result_with(_growth([_exp_row(0, "received", 0), _exp_row(1, "received", 0), _exp_row(2, "received", 0),
		_exp_row(3, "received", 0), _exp_row(4, "received", 0)], 0))
	check_eq(layer.result_lines, [texts.t("battle.result.no_drops")] as Array[String], "드롭 줄만, 경험치 줄 없음")


func test_result_level_up_lines_with_and_without_sp() -> void:
	var rows := [_exp_row(0, "received", 30, false, 1, 2, 0), _exp_row(1, "received", 30, false, 1, 3, 2), _exp_row(2, "received", 30),
		_exp_row(3, "received", 30), _exp_row(4, "received", 30)]
	await _result_with(_growth(rows))
	var lines := layer.result_lines
	check(lines.has("%s  Lv 1 → 2" % _mname(0)), "sp_gained 0 이면 「SP」 없음: %s" % str(lines))
	check(lines.has("%s  Lv 1 → 3  SP +2" % _mname(1)), "sp_gained 2 → 「SP +2」")
	check_eq(lines.filter(func(l: String) -> bool: return l.contains("Lv ")).size(), 2, "오른 대원만")
	check_eq(lines.find("경험치 +30"), lines.size() - 4, "경험치 줄 다음에 레벨업 머리와 줄: %s" % str(lines))
	check_eq(lines.find("레벨 업"), lines.size() - 3, "레벨업 줄 바로 위에 머리 「레벨 업」(한 번)")
	check_eq(lines.count("레벨 업"), 1, "머리는 한 번")


func test_result_without_growth_fields_has_no_exp_lines() -> void:
	await _result_with({}, Vector2.ZERO, [], "escaped")
	check_eq(layer.result_lines, [texts.t("battle.event.escaped")] as Array[String], "도주: 경험치 줄 없음")
	check(layer.growth_lines({"type": "battle_end", "outcome": "wiped"}).is_empty(), "전멸 battle_end(성장 필드 없음)도 경험치 줄 없음")
	check(layer.growth_lines({"type": "battle_end", "outcome": "escaped", "reason": "turn_cap"}).is_empty(), "턴 상한도")


func test_result_many_lines_keep_ok_on_screen_and_body_scrolls() -> void:
	var rows := []
	for i in 5:
		rows.append(_exp_row(i, "received", 30 + i, i == 2, 1, 2 + i % 2, 1 + i % 2))
	var drops := []
	for item in ITEMS:
		drops.append({"item": item, "amount": 1, "capped": false})
	for sz in [Vector2(1280, 720), Vector2(1728, 720)]:
		var end := _growth(rows)
		end["drops"] = drops
		await _result_with(end, sz)
		var ok := _btn("ResultOk")
		var r := Rect2(ok.get_global_position() - layer.get_global_position(), ok.size)
		check(Rect2(Vector2.ZERO, sz).encloses(r), "%s: 「확인」 %s 이 화면 안" % [str(sz), str(r)])
		check(ok.size.x >= 64 and ok.size.y >= 64, "「확인」 64px 이상")
		var pr := Rect2(layer.result_panel.position, layer.result_panel.size)
		check(Rect2(Vector2.ZERO, sz).encloses(pr), "%s: 결과 창 %s 이 화면 안" % [str(sz), str(pr)])
		check(pr.position.y >= BattleLayer.TOAST_Y + BattleLayer.TOAST_H, "%s: 결과 창 위 %d 이 알림 줄 아래" % [str(sz), pr.position.y])
		check_eq(layer.result_lines.size(), 1 + ITEMS.size() + 1 + 5 + 1 + 5, "드롭 머리 + 드롭 8 + 경험치 머리 + 대원 5 + 레벨업 머리 + 레벨업 5")
		check(layer.result_scroll.max_scroll() > 0.0, "%s: 줄이 넘치면 본문을 끌어 내릴 수 있다" % str(sz))
		var c := kit.center_of(layer.result_scroll)
		kit.touch(0, c, true)
		kit.drag(0, c, c - Vector2(0, 120))
		kit.touch(0, c - Vector2(0, 120), false)
		await kit.frames(3)
		check(layer.result_scroll.scroll > 0.0, "%s: 끌어서 내렸다" % str(sz))
		check_eq(layer.phase, "result", "끌기는 「확인」이 아니다")
		await _tap_btn("ResultOk")
		check(not layer.is_open(), "%s: 「확인」으로 닫힌다" % str(sz))


func test_log_and_cards_show_exp_and_level_up() -> void:
	var lv := {"type": "level_up", "member": 1, "from": 1, "to": 2, "sp_gained": 1, "max_hp": 61, "max_tp": 35, "hp_gain": 3, "tp_gain": 1,
		"stats": {"STR": 19, "INT": 8, "VIT": 13, "WIS": 10, "AGI": 18, "LUC": 13}}
	var ex := {"type": "exp", "member": 1, "gained": 4, "exp": 30, "capped": false}
	var s := _calm_state()
	var hp_before := s.battle.party[1].hp
	await _open(s)
	var events: Array[Dictionary] = [ex, lv, {"type": "battle_end", "outcome": "victory", "drops": [], "enemy_hp": [0, 0, 0]}]
	layer._commit(events)
	await kit.frames(2)
	var lines: Array = layer.log_view.lines
	check(lines.has("%s 경험치 +4" % _mname(1)), "로그: 경험치 줄 %s" % str(lines.slice(-3)))
	check(lines.has("%s Lv 1 → 2" % _mname(1)), "로그: 레벨업 줄")
	var u := layer.display.party[1]
	check_eq([u.max_hp, u.max_tp, u.hp], [61, 35, hp_before + 3], "레벨업이 칸의 최대·현재 HP 에 반영")
