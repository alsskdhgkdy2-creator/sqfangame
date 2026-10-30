## 보스의 화면 — M3 A9a(봉인 알림·다시 그림) + M3 A9b(설계 §5.2~§5.5·§7.2): 보스 물음 창(kind boss, 처음 커서 「아니오」) →
## 「예」 = FIGHT(전투 시작 자동 저장) → 보스 띠·알림·음악 갈고리·도주 흐림 → 승리면 클리어 이야기 상자(kind clear, 보이기만) → 표지·지도 원 없음,
## 슬롯 카드 「제1계층 돌파」. 전멸이면 전멸 창 → 슬롯 불러오기 → 보스 idle. 실제 미궁(open_arbor) B3F 봉인 앞 (9,2)·보스 앞 (5,2).
## 얻는 길은 실제 키·터치 → 자동 저장 → 문서로 본다. 시험마다 죽이는 변이(M-V… A9a, M-U… A9b)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const SEAL := Vector3i(9, 2, 1)
const FoeScreen := preload("res://tests/test_foe_screen.gd")
const HM := preload("res://tests/held_matrix.gd")
const SIZES := [Vector2i(1280, 720), Vector2i(1728, 720), Vector2i(1280, 960)]

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


## B3F 칸 at·facing 에 선 미궁 화면. flag 면 permit.boss, open 이면 봉인이 열렸다. query 는 주소 인자(예 "debug=1").
func _open(at: Vector2i, facing: int, flag: bool, open: bool = false, query: String = "") -> DungeonScreen:
	timeout_sec = maxf(timeout_sec, 90.0)  # 긴 시험은 첫 await 전에 더 크게 둔다(마감은 첫 await 에서 정해진다)
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7, query)
	Fx.to_floor(s.state, "b3f", at, facing)
	s.state.encounter.threshold = 99999
	if flag:
		s.state.flags["permit.boss"] = true
	if open:
		s.state.world.open_lock(SEAL)
	s._set_state(s.state)
	await kit.frames(2)
	return s


func _auto_doc(s: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)))


## V1 (M-V1 seal_opened 를 다시 그리지 않음, M-V2 seal_opened 알림을 지움): 플래그 없이 앞으로 → 「sealed」 알림. 플래그를 가진 채 뒤로 → seal_closed 알림,
## 앞으로 → 봉인이 열리고(움직이지 않음) 알림·다시 그림·자동 저장(13판 locks_open).
func test_seal_toasts_and_rebuild() -> void:
	var texts := TextDb.load_path("res://data/text/ko.json")
	var s := await _open(Vector2i(9, 2), Dir.W, false)
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check_eq([s._toast.text, s.state.world.is_lock_open(SEAL)], [texts.t("msg.sealed"), false], "플래그 없음: sealed 알림")
	s = await _open(Vector2i(9, 2), Dir.E, true)
	await kit.press_key(KEY_S)
	await kit.frames(2)
	check_eq([s._toast.text, s.state.party.at], [texts.t("msg.seal_closed"), Vector2i(9, 2)], "플래그 있음, 뒤로: seal_closed 알림")
	s = await _open(Vector2i(9, 2), Dir.W, true)
	var mesh0 := s.view._mesh_instance.mesh.get_instance_id()
	var saves := s.autosave_count
	await kit.press_key(KEY_W)
	await kit.frames(3)
	var snap := s.debug_snapshot()
	check_eq([s._toast.text, snap["modal"], snap["at"], s.state.world.is_lock_open(SEAL), s.autosave_count], [texts.t("msg.seal_opened"), "", [9, 2], true, saves + 1],
		"플래그 있음, 앞으로: 봉인 열림 알림, 제자리, 자동 저장 하나")
	check(s.view._mesh_instance.mesh.get_instance_id() != mesh0, "봉인 열림은 시야를 다시 만든다")
	check_eq(DungeonMeshBuilder.edge_style(s.state.floor_def, s.state.world, SEAL), "door", "그리는 모양: 열린 문")
	var doc := _auto_doc(s)
	check_eq([doc["schema"], doc["state"]["floor_states"]["b3f"]["world"]["locks_open"]], [13.0, ["v:9:2"]], "자동 저장 13판 locks_open 에 봉인")


## 보스 앞 (5,2) 서쪽을 보고 선 화면(봉인 열림, 플래그 있음). 조사(Space)로 보스 물음 창을 연다.
func _at_boss() -> DungeonScreen:
	return await _open(Vector2i(5, 2), Dir.W, true, true)


func _ask(s: DungeonScreen, key: int = KEY_SPACE) -> void:
	await kit.press_key(key)
	await kit.frames(3)


func _button(s: DungeonScreen, n: String) -> Button:
	return s.modal.find_child(n, true, false) as Button


func _marker(s: DungeonScreen, id: String) -> MeshInstance3D:
	return s.view.foes_root.get_node_or_null("Foe_" + id) as MeshInstance3D


## 보스 물음 → 「예」 터치 → 전투 층.
func _fight(s: DungeonScreen) -> BattleLayer:
	await _ask(s)
	var yes := _button(s, "BossYes")
	if yes == null:
		return s.battle_layer
	await kit.tap(kit.center_of(yes))
	await kit.frames(4)
	return s.battle_layer


## 결과 창이 닫힐 때까지 Enter(전투 층이 열린 동안만: 닫힌 뒤의 Enter 는 다음 창이 받는다).
func _close_result(layer: BattleLayer) -> void:
	for i in 8:
		if not layer.is_open():
			return
		await kit.press_key(KEY_ENTER)
		await kit.frames(3)


## 보스 HP 1 로 기본 정책 차례를 넘겨 이긴다(결과 창까지).
func _win(s: DungeonScreen, layer: BattleLayer) -> void:
	s.state.battle.enemies[0].hp = 1
	for t in 8:
		if layer.phase != "command":
			break
		layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
		await kit.frames(2)


func _focus(s: DungeonScreen) -> Control:
	return s.get_viewport().gui_get_focus_owner()


## U1 (M-U1 처음 커서 「예」) · U4-a(「아니오」·Esc·Backspace·Enter 는 닫기만): 부딪히거나 조사하면 보스 물음 창. 제목 「강대한 기척」,
## 글 「네온 펜리르가 버티고 서 있다. 싸울까?」 + 경고 색 「이 싸움에서는 도망칠 수 없다」, 단추 「예」「아니오」 차례, 포커스 「아니오」.
## 어느 닫기든 저장·상태 그대로, 제자리. 다시 부딪히면 다시 묻는다. (A9a V2 「boss 이벤트는 조용하다」를 바꾼다: 조정 목록 1)
func test_boss_question() -> void:
	var s := await _at_boss()
	var texts := s.texts
	var h := kit.hash_now()
	var closes := [[KEY_W, "bump", "no_touch"], [KEY_SPACE, "investigate", "esc"], [KEY_W, "bump", "backspace"], [KEY_SPACE, "investigate", "enter"]]
	for c in closes:
		await _ask(s, c[0])  # 부딪힘·조사는 행동이라 늘 하던 대로 자동 저장한다(상태는 그대로). 아래 「저장 없음」은 창을 연 뒤부터 센다.
		var saves := s.autosave_count
		var gen := kit.auto_generation()
		var snap := s.debug_snapshot()
		var tag := "%s → %s" % [c[1], c[2]]
		check_eq([snap["modal"], snap["modal_title"], snap["modal_text"], snap["at"], snap["boss_near"]],
			["boss", texts.t("boss.title"), texts.t("boss.ask", {"name": "네온 펜리르"}) + "\n" + texts.t("boss.no_escape"), [5, 2], "boss"], tag + ": 보스 물음 창")
		var yes := _button(s, "BossYes")
		var no := _button(s, "BossNo")
		check(yes != null and no != null and yes.get_parent() == no.get_parent() and yes.get_index() < no.get_index(), tag + ": 「예」「아니오」 차례")
		if yes == null or no == null:
			return
		check_eq([yes.text, no.text], [texts.t("ui.yes"), texts.t("ui.no")], tag + ": 단추 글")
		check_eq([_focus(s), snap["modal_focus"]], [no, "BossNo"], tag + ": 처음 커서 「아니오」(O7, D25, 스냅숏 modal_focus)")
		var warn := s.modal.find_child("BossNoEscape", true, false) as Label
		check(warn != null and warn.get_theme_color("font_color") == DungeonScreen.BOSS_WARN, tag + ": 도망 못 함 줄은 경고 색")
		match c[2]:
			"no_touch":
				await kit.tap(kit.center_of(no))
			"esc":
				await kit.press_key(KEY_ESCAPE)
			"backspace":
				await kit.press_key(KEY_BACKSPACE)
			"enter":
				await kit.press_key(KEY_ENTER)  # 포커스 「아니오」
		await kit.frames(3)
		snap = s.debug_snapshot()
		check_eq([snap["modal"], snap["at"], kit.hash_now(), s.autosave_count, kit.auto_generation(), s.battle_layer.is_open(), s.state.world.foes["boss"].state],
			["", [5, 2], h, saves, gen, false, "idle"], tag + ": 닫기만(창을 연 뒤 저장 없음, 상태 그대로, 제자리)")
	# Esc 로 닫힌 뒤 Esc 는 캠프를 열지 않았다(물음 창이 받았다).
	check(not s.party_menu.is_open(), "물음 창의 Esc 는 캠프를 열지 않는다")
	# 맞닿지 않으면 묻지 않는다(뒤로 한 칸, 조사 → 아무것도 없음).
	await kit.press_key(KEY_S)
	await kit.frames(3)
	await _ask(s)
	check_eq([s.debug_snapshot()["modal"], s.debug_snapshot()["boss_near"]], ["", ""], "한 칸 떨어지면 묻지 않는다")
	# A9a V2 에서 옮긴 것(그대로 참): FIGHT 키·단추는 없다(FIGHT 는 물음의 「예」로만).
	check(not DungeonScreen.KEY_ACTIONS.values().has(ExplorationRules.Action.FIGHT), "FIGHT 키 없음")
	check(not s.debug_snapshot()["buttons"].keys().any(func(k: String) -> bool: return k.contains("fight") or k.contains("Fight")), "FIGHT 단추 없음 %s" % str(s.debug_snapshot()["buttons"].keys()))


## U4-b(「예」 = FIGHT): 「예」 터치 → 전투 시작 자동 저장(= 화면, battle.foe boss) → 전투 층(펜리르 카드 하나). 띠 첫 줄 「네온 펜리르가 앞을 막아선다!」 +
## 알림 「봉인 너머의 주인이 깨어났다!」, 음악 갈고리 boss, 도주 줄 흐림(이유 「도망칠 수 없다」), 전투 중 3D 표지 감춤(M-U5).
## 새 화면(실제 다시 열기)은 같은 전투(해시). (A9a V3 「규칙 행동 FIGHT 는 전투 층을 연다」를 실제 「예」 터치로 넓힌다: 조정 목록 2)
func test_yes_opens_boss_battle() -> void:
	timeout_sec = 150.0
	var s := await _at_boss()
	var texts := s.texts
	await _ask(s)
	var saves := s.autosave_count  # 물음 창이 열린 뒤
	var yes := _button(s, "BossYes")
	check(yes != null, "보스 물음 창")
	if yes == null:
		return
	await kit.tap(kit.center_of(yes))
	await kit.frames(4)
	var layer := s.battle_layer
	check(layer.is_open(), "「예」 → 전투 층")
	if not layer.is_open():
		return
	check_eq([s.modal.kind, s.state.encounter.pending, s.state.battle.foe, s.state.battle.no_escape, s.state.world.foes["boss"].state, s.autosave_count],
		["", true, "boss", true, "battle", saves + 1], "보스 전투: 창 닫힘, 전투 대기(A9a V3), battle.foe boss, 도주 없음, 자동 저장 하나")
	var r := SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now(), "전투 시작 자동 저장 = 화면 %s" % r.error)
	var doc := _auto_doc(s)
	var bat: Variant = doc["state"].get("battle")
	check(bat is Dictionary and bat.get("foe") == "boss", "자동 저장 battle.foe boss")
	var cards: Array = layer.enemy_area.cards
	check_eq(cards.size(), 1, "적 카드 하나")
	if cards.size() == 1:
		var u: BattleDisplay.DUnit = cards[0].unit()
		check_eq([u.def_id, u.name, u.hp, u.max_hp], ["enemy.boss_fenrir", "네온 펜리르", 1800, 1800], "펜리르 카드")
	check_eq(layer.banner_lines(), [texts.t("battle.boss_start", {"name": "네온 펜리르"}), texts.t("msg.boss_contact"), true],
		"첫 띠: 보스 시작 줄 + 「봉인 너머의 주인이 깨어났다!」")
	var info: Dictionary = s.debug_snapshot()["battle"]
	check_eq([layer.music_cue(), info.get("music_cue"), info.get("boss")], ["boss", "boss", true], "음악 갈고리 boss(스냅숏 battle.music_cue·boss)")
	var esc: TouchButton = layer.panel.command_buttons[CommandPanel.CMD_ESCAPE]
	check_eq([esc.theme_state(), esc.dimmed, esc.note], ["cmd:disabled", true, texts.t("battle.reason.no_escape")], "도주 줄 흐림, 이유 「도망칠 수 없다」")
	# U5 (M-U5 전투 중 보스 표지를 감추지 않음).
	check_eq([s.view.foes_root.visible, _marker(s, "boss") != null, s.debug_snapshot()["foe_marks_shown"]], [false, true, false], "전투 중 보스 표지 감춤")
	# 한 차례(기본 정책) → 차례 자동 저장 → 실제 다시 열기 = 같은 전투.
	layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
	await kit.frames(3)
	for i in 30:
		if layer.phase == "command":
			break
		await kit.frames(2)
	var h := kit.hash_now()
	var turn := s.state.battle.turn
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)
	layer = s.battle_layer
	check_eq([kit.hash_now(), layer.is_open(), s.state.battle.foe if s.state.battle != null else "", s.state.battle.turn if s.state.battle != null else -1,
		layer.music_cue(), s.view.foes_root.visible], [h, true, "boss", turn, "boss", false], "새 화면: 같은 보스 전투(해시·차례), 표지 감춤")


## M-U9 (적 강화를 표시 카드로 옮기지 않음): 실제 차례에서 펜리르가 강화(오버클록, 자기 물리 공격 ↑)를 쓰면 보스 카드의 상태 딱지에 강화가 그려진다.
## 펜리르 HP 를 절반 아래로 두고(설계 §2.2 AI 3: 3의 배수 차례 = 오버클록 또는 정전 포효) 파티 HP 를 매 차례 채운다. 시드 7 의 실제 흐름.
func test_enemy_buff_on_boss_card() -> void:
	timeout_sec = 240.0
	var s := await _at_boss()
	var layer := await _fight(s)
	check(layer.is_open(), "보스 전투")
	if not layer.is_open():
		return
	var boss: BattleUnit = s.state.battle.enemies[0]
	var turns := 0
	for t in 15:
		if not boss.buffs.is_empty() or layer.phase != "command":
			break
		boss.hp = 800
		for m in s.state.battle.party:
			m.hp = m.max_hp
			m.ailment = ""
		layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
		turns += 1
		for i in 60:
			await kit.frames(1)
			if layer.phase != "anim":
				break
	check(not boss.buffs.is_empty(), "펜리르가 강화를 썼다(%d 차례)" % turns)
	if boss.buffs.is_empty():
		return
	var card: BattleCard = layer.enemy_area.cards[0]
	var kinds := card.unit().buffs.map(func(e: Dictionary) -> String: return str(e["kind"]))
	check_eq(kinds, boss.buffs.map(func(e: Dictionary) -> String: return str(e["kind"])), "보스 카드 강화 = 상태")
	var chips := card.drawn_chips().filter(func(c: Dictionary) -> bool: return c["kind"] == "buff")
	check_eq(chips.size(), 1, "보스 카드에 강화 딱지 하나 %s" % str(card.drawn_chips()))
	if chips.size() == 1:
		check(card.get_global_rect().encloses(Rect2(card.global_position + (chips[0]["rect"] as Rect2).position, (chips[0]["rect"] as Rect2).size)), "강화 딱지는 카드 안")


## 전멸 → 전멸 창 → 「마지막 기록으로 돌아간다」 → 지도 물음 → 슬롯(보스 앞, 싸우기 전): 보스 idle, 다시 물음.
func test_wipe_then_load_slot() -> void:
	timeout_sec = 240.0
	var s := await _at_boss()
	s._save_slot("slot1")
	await kit.frames(2)
	var slot_hash := kit.hash_now()
	var layer := await _fight(s)
	check(layer.is_open(), "보스 전투")
	if not layer.is_open():
		return
	for t in 40:
		if layer.phase != "command" or s.state.battle == null:
			break
		for m in s.state.battle.party:
			m.hp = mini(m.hp, 1)
		layer.handle("commands", BattlePolicy.choose(s.state, BattlePolicy.DEFAULT))
		for i in 60:
			await kit.frames(1)
			if layer.phase != "anim":
				break
	await _close_result(layer)
	await kit.frames(3)
	check_eq([s.state.wiped, s.modal.kind, s.state.world.foes["boss"].state, s.state.world.foes["boss"].stun], [true, "wipe", "idle", 0],
		"전멸: 전멸 창, 보스 idle(stun 0)")
	check_eq([s.story_box.is_visible_in_tree(), s.debug_snapshot()["story"]], [false, {}], "전멸은 이야기 상자를 열지 않는다")
	var load_b := _button(s, "WipeLoad")
	check(load_b != null, "「마지막 기록으로 돌아간다」")
	if load_b == null:
		return
	await kit.tap(kit.center_of(load_b))
	await kit.frames(2)
	check_eq(s.modal.kind, "wipe_map", "지도 물음")
	await kit.tap(kit.center_of(_button(s, "WipeMapNo")))
	await kit.frames(3)
	check_eq([s.state.wiped, kit.hash_now(), s.state.party.at, s.state.world.foes["boss"].state, s.modal.kind], [false, slot_hash, Vector2i(5, 2), "idle", ""],
		"슬롯: 보스 앞, 보스 idle")
	await _ask(s)
	check_eq(s.modal.kind, "boss", "불러온 뒤 다시 묻는다")


## U3·U4·U7·U15·U16 (M-U3 이야기 상자 아래 HUD 를 감추지 않음, M-U4 _refresh 끝에 sync 없음, M-U7 취소를 받지 않음):
## 이기면 결과 창 → 닫으면 이야기 상자(kind clear, 쪽 셋, 말하는 사람 「관리국 통신」, 첫 쪽에 보스 이름) → HUD·지도 감춤 →
## 고름 값(쪽)은 가만히 있는 동안 그대로, 넘김 단추를 누른 채 키패드 선택·Enter = 다음 쪽, 뗀 넘김 단추는 일하지 않는다(누르기 지킴이) → 마지막 쪽 「확인」 → Esc = 닫기.
## (상자 누르기·키패드 취소·Backspace 는 test_slot_clear_mark 가 넘긴다.)
## 보이기만: 해시·자동 저장 그대로. 닫히면 HUD 다시, 표지·네 지도 원 없음, cleared [b3f], FIGHT = no_boss, 조사 = 묻지 않음.
func test_victory_story_box() -> void:
	timeout_sec = 240.0
	var s := await _at_boss()
	var texts := s.texts
	var layer := await _fight(s)
	check(layer.is_open(), "보스 전투")
	if not layer.is_open():
		return
	await _win(s, layer)
	check_eq([layer.phase, layer.end_event.get("outcome"), Array(layer.end_event.get("foes_defeated", []))], ["result", "victory", ["boss"]], "승리 결과 창")
	await _close_result(layer)
	await kit.frames(3)
	var h := kit.hash_now()
	var saves := s.autosave_count
	var snap := s.debug_snapshot()
	var p1 := texts.t("clear.stratum1.1", {"name": "네온 펜리르"})
	check_eq([layer.is_open(), snap["modal"], snap["story"].is_empty()], [false, "clear", false], "승리 결과 창을 닫으면 이야기 상자(M-U15)")
	if snap["story"].is_empty():
		return
	check_eq([layer.is_open(), snap["modal"], snap["story"]["page"], snap["story"]["pages"], snap["story"]["speaker"], snap["story"]["last"]],
		[false, "clear", 0, 3, texts.t("clear.stratum1.speaker"), false], "이야기 상자: 첫 쪽")
	check_eq(" ".join(snap["story"]["lines"]), p1, "첫 쪽 글(보스 이름)")
	check(snap["story"]["lines"].size() <= StoryBox.LINES, "세 줄까지")
	# U3: HUD·지도·미니맵 감춤, 3D 시야는 보인다(어두운 판 없음).
	check_eq([s._hud_hidden(), s.hud_root.visible, s.minimap.is_visible_in_tree(), s.view_container.visible, s.modal._dim.visible],
		[true, false, false, true, false], "HUD 감춤, 시야만")
	var sb := s.story_box
	check_eq([sb.next_button.icon, sb.next_button.text], ["down", ""], "넘김 표시 ▼")
	await HM.stable(self, kit, sb, "이야기 상자")
	# U4 (누르기 지킴이, 교훈 10): 넘김 단추를 누른 채 키패드 선택(pad) → 둘째 쪽, 다시 누른 채 Enter(key) → 셋째 쪽. 뗀 넘김 단추는 일하지 않는다.
	await HM.run(self, kit, {"name": "넘김 단추", "hold": func() -> TouchButton: return sb.next_button,
		"pad": func() -> TouchButton: return sb.key_pad.button("ok"), "key": KEY_ENTER,
		"value": func() -> Variant: return sb.page,
		"observe": func() -> Array: return [sb.page, s.modal.kind, kit.hash_now(), s.autosave_count]})
	check_eq([s.debug_snapshot()["story"].get("page", -1), " ".join(sb.drawn_lines), sb.next_button.text, sb.next_button.icon],
		[2, texts.t("clear.stratum1.3"), texts.t("ui.ok"), ""], "키패드 선택·Enter → 마지막 쪽 「확인」")
	check_eq([kit.hash_now(), s.autosave_count], [h, saves], "넘기기는 상태·저장을 바꾸지 않는다")
	# U7: 마지막 쪽에서 Esc(취소) → 닫힘. 캠프는 열리지 않는다.
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(3)
	snap = s.debug_snapshot()
	check_eq([snap["modal"], snap["story"], s.party_menu.is_open(), s.story_box.is_visible_in_tree(), s.modal.part == null], ["", {}, false, false, true],
		"Esc → 닫힘(캠프 안 열림, 상자는 감춤, 창 층의 부품 없음)")  # 보완 F1: 상자는 창 층 아래 감춘 채 남는다(주인 = 창 층)
	check_eq([kit.hash_now(), s.autosave_count], [h, saves], "보이기만(해시·자동 저장 그대로)")
	check_eq([s._hud_hidden(), s.hud_root.visible], [false, true], "닫히면 HUD 다시")
	check_eq([s.state.world.foes["boss"].state, snap["cleared"], snap["boss_near"], _marker(s, "boss") == null, snap["foe_mark_list"].filter(func(m: Dictionary) -> bool: return m["id"] == "boss")],
		["defeated", ["b3f"], "", true, []], "쓰러진 보스: 표지 없음, cleared [b3f]")
	var boss_disc := func(m: MapPanel) -> bool: return m.drawn_foes.any(func(d: Dictionary) -> bool: return d["id"] == "boss")
	check(not boss_disc.call(s.minimap), "미니맵: 보스 원 없음")
	await kit.open_map()
	await kit.frames(2)
	check(not boss_disc.call(s.map) and not boss_disc.call(s.map_window.overview), "지도·층 전체: 보스 원 없음")
	check(not boss_disc.call(s.battle_layer.minimap), "전투 미니맵: 보스 원 없음")
	await kit.press_key(KEY_M)
	await kit.frames(2)
	await _ask(s)
	check_eq(s.modal.kind, "", "조사: 묻지 않는다")
	s._do_action(ExplorationRules.Action.FIGHT)
	await kit.frames(3)
	check_eq([s.battle_layer.is_open(), s.debug_snapshot()["toast"]], [false, texts.t("msg.no_boss")], "FIGHT → 싸울 상대가 없다")
	# 다시 열기(자동 저장) → 이야기 상자는 다시 뜨지 않는다(O6).
	h = kit.hash_now()
	s = await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)
	check_eq([kit.hash_now(), s.modal.kind, s.debug_snapshot()["cleared"]], [h, "", ["b3f"]], "새 화면: 같은 상태, 이야기 상자 없음")


## 보스 표지(설계 §5.4): 3D 표지는 1.25 배(그림자 포함 노드 배율), 지도 원은 큰 원 + 바깥 고리(네 지도 모두 boss true).
## M-U8 (배율 2.0): 표지가 제 칸(벽 안)과 천장 아래를 벗어난다. 카메라 거리(A6c 0.75m 훑기)도 보스 배율로 본다.
func test_boss_marker_and_rings() -> void:
	timeout_sec = 180.0
	var s := await _open(Vector2i(9, 2), Dir.W, true, true)
	var node := _marker(s, "boss")
	check(node != null, "보스 표지")
	if node == null:
		return
	check_eq(s.debug_snapshot()["foe_mark_list"].filter(func(m: Dictionary) -> bool: return m["id"] == "boss"), [{"id": "boss", "boss": true, "scale": FoeLook.BOSS_SCALE}],
		"표지 목록: 보스 1.25")
	check(node.transform.basis.get_scale().is_equal_approx(Vector3.ONE * 1.25), "노드 배율 1.25 %s" % str(node.transform.basis.get_scale()))
	check_eq(node.transform.origin, DungeonMeshBuilder.cell_center(Vector2i(4, 2)), "보스 칸 (4,2) 가운데")
	var verts := FoeScreen._mark_verts()
	var half := DungeonMeshBuilder.CELL / 2.0
	var c := DungeonMeshBuilder.cell_center(Vector2i(4, 2))
	var reach := 0.0
	var top := 0.0
	for v in verts:
		var w: Vector3 = node.transform * v
		reach = maxf(reach, maxf(absf(w.x - c.x), absf(w.z - c.z)))
		top = maxf(top, w.y)
	check(reach < half and top < DungeonMeshBuilder.WALL_H, "표지는 제 칸 안(%.3f < %.1f)·천장 아래(%.3f < %.1f)" % [reach, half, top, DungeonMeshBuilder.WALL_H])
	# 카메라 훑기: 보스는 움직이지 않는다. 파티의 모든 한 걸음 × 5×5 의 모든 칸(파티 칸·들어갈 칸 제외) × 네 바라봄, 보스 배율.
	var sc := node.transform.basis.get_scale().x
	var least := INF
	var acts := {"forward": Vector2i(1, 0), "back": Vector2i(-1, 0), "strafe_l": Vector2i(0, -1), "strafe_r": Vector2i(0, 1), "turn_l": Vector2i.ZERO, "turn_r": Vector2i.ZERO}
	for act in acts:
		for sx in range(-2, 3):
			for sy in range(-2, 3):
				var cell := Vector2i(sx, sy)
				if cell == Vector2i.ZERO or cell == acts[act]:
					continue
				for f in 4:
					least = minf(least, FoeScreen._clearance(act, cell, f, cell, f, verts, sc))
	check(least >= 0.75, "보스 배율 카메라 거리: 최소 %.4fm ≥ 0.75" % least)
	# 지도 원: 네 지도 모두 boss true(보스는 (4,2), 봉인 너머라도 그린다).
	var want := {"id": "boss", "cell": Vector2i(4, 2), "facing": Dir.E, "boss": true}
	var pick := func(m: MapPanel) -> Dictionary:
		for d in m.drawn_foes:
			if d["id"] == "boss":
				return {"id": d["id"], "cell": d["cell"], "facing": d["facing"], "boss": d["boss"]}
		return {}
	check_eq(pick.call(s.minimap), want, "미니맵: 보스 원·고리")
	check_eq(s.debug_snapshot()["minimap_foes"].filter(func(d: Dictionary) -> bool: return d["id"] == "boss").map(func(d: Dictionary) -> bool: return d["boss"]), [true], "스냅숏 minimap_foes boss")
	await kit.open_map()
	await kit.frames(2)
	check_eq([pick.call(s.map), pick.call(s.map_window.overview)], [want, want], "지도·층 전체: 보스 원·고리")
	await kit.press_key(KEY_M)
	await kit.frames(2)
	s.state.party.at = Vector2i(5, 2)
	s._set_state(s.state)
	await kit.frames(2)
	var layer := await _fight(s)
	check(layer.is_open(), "보스 전투")
	if layer.is_open():
		check_eq(pick.call(layer.minimap), want, "전투 미니맵: 보스 원·고리")


## M-U6 (클리어하지 않은 기록에도 표): 수동 슬롯 카드의 「제1계층 돌파」. 클리어 전 슬롯 1·클리어 뒤 슬롯 2 → record_slots 의 clear 는 2 에만,
## 캠프 기록 판과 타이틀 불러오기 판 모두 2 번 줄 첫째 줄에만 표 알약(그리기 기록, M3 A9b 보완 F3). 8자 대표 + Lv 99 에서도 첫째 줄은 줄이지 않고 표 앞에서 끝난다.
func test_slot_clear_mark() -> void:
	timeout_sec = 240.0
	var s := await _at_boss()
	var texts := s.texts
	s.state.party.members[0].name = "가나다라마바사아"
	s._save_slot("slot1")
	var layer := await _fight(s)
	if not layer.is_open():
		check(false, "보스 전투")
		return
	await _win(s, layer)
	await _close_result(layer)
	await kit.frames(3)
	# 이야기 상자는 다른 길로 넘긴다(M-U7: 취소도 다음 쪽): 키패드 취소 → Backspace → 상자 누르기(마지막 쪽 = 닫기).
	check_eq(s.modal.kind, "clear", "이야기 상자")
	if s.modal.kind != "clear":
		return
	await kit.tap(kit.center_of(s.story_box.key_pad.button("back")))
	await kit.frames(2)
	check_eq(s.story_box.page, 1, "키패드 취소 → 다음 쪽")
	await kit.press_key(KEY_BACKSPACE)
	await kit.frames(2)
	check_eq(s.story_box.page, 2, "Backspace → 다음 쪽")
	await kit.tap(kit.center_of(s.story_box.tap))
	await kit.frames(3)
	check_eq(s.modal.kind, "", "상자 누르기(마지막 쪽) → 이야기 상자 닫힘")
	s._save_slot("slot2")
	await kit.frames(2)
	var rows := s.record_slots()
	check_eq(rows.map(func(r: Dictionary) -> bool: return r.has("clear")), [false, true, false], "record_slots: 클리어한 슬롯 2 에만 clear")
	check_eq(rows[1].get("clear"), true, "clear = true")
	# 타이틀 불러오기 판(처음 창 크기에서 터치로 연다: 크기를 바꾼 뒤에는 키만 쓴다).
	kit.close_screen()
	await kit.frames(1)
	s = await kit.open_title("native", 7, "", func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	var t := s.title_screen
	check_eq([s.modal.kind, t.rows[0]], ["", "continue"], "타이틀: 클리어 뒤 자동 저장으로 이어하기")
	await kit.tap(kit.center_of(t.menu_buttons["load"]))
	await kit.frames(2)
	check_eq([t.page, s.debug_snapshot()["title"]["records"].get("clear")], ["load", [false, true, false]], "타이틀 불러오기 판 clear")
	for px in SIZES:
		await _resize(px)
		await _check_tags(t.records_tab, texts, "타이틀 %s" % str(px))
	tree.root.size = _root_size
	await kit.frames(2)
	# 캠프 기록 판(자동 저장 = 클리어 뒤 B3F).
	kit.close_screen()
	await kit.frames(1)
	s = await kit.open_arbor("native", 7)
	await kit.frames(2)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_6)
	await kit.frames(2)
	var pm := s.party_menu
	check_eq([pm.page, pm.tab], ["sub", 4], "캠프 기록 판")
	check_eq(s.debug_snapshot()["party_menu"]["records"]["clear"], [false, true, false], "캠프 스냅숏 clear")
	for px in SIZES:
		await _resize(px)
		await _check_tags(pm.records_tab, texts, "캠프 %s" % str(px))


func _resize(px: Vector2i) -> void:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = px
	await kit.frames(3)


## 기록 판 줄마다 표 알약(M3 A9b 보완 F3): 슬롯 2(줄 1)만 첫째 줄 오른쪽 끝에 「제1계층 돌파」(OPT_TAG_FS, 첫째 줄 글의 세로 가운데), 이름 알약 안.
## 가장 넓은 첫째 줄(8자 대표 + 「Lv 99」: 레벨 상한은 30 이라 저장으로는 못 만들어 보이는 줄 값만 바꾼다)이 OPT_LABEL_FS 그대로 표 앞에서 끝난다.
## 둘째 줄은 같은 슬롯을 클리어하지 않은 것으로 그렸을 때와 그리기 기록(글·크기·자리·색)이 같다(줄이지 않는다).
func _check_tags(rt: PartyRecordsTab, texts: TextDb, tag: String) -> void:
	rt.slots[1]["level"] = texts.t("party.level", {"level": 99})
	var row := func() -> Array:
		rt.window.queue_redraw()
		await kit.frames(2)
		var lr0 := PartyRecordsTab.label_rect(1)
		return SheetParts.record(rt.window).filter(func(e: Dictionary) -> bool:
			return lr0.encloses(Rect2(e["rect"].position, Vector2(1, 1))) or (e["kind"] == "fill" and lr0.encloses(e["rect"])))
	var rec: Array = await row.call()
	var mark := texts.t("menu.slot_clear")
	var all_marks := SheetParts.record(rt.window).filter(func(e: Dictionary) -> bool: return e["kind"] == "text" and e["text"] == mark)
	check_eq(all_marks.size(), 1, tag + ": 표 하나")
	check_eq([rt.row_tags(0), rt.row_tags(1), rt.row_tags(2)], [[], [mark], []], tag + ": 줄 표(슬롯 2 첫째 줄)")
	var lr := PartyRecordsTab.label_rect(1)
	var lines := rt.row_label_lines(1)
	check_eq(lines[0], "2  가나다라마바사아  Lv 99", tag + ": 가장 넓은 첫째 줄")
	var marks := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "text" and e["text"] == mark)
	var pills := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "fill" and e["color"] == ListParts.OPT_TAG)
	var head := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "text" and e["text"] == lines[0])
	check(marks.size() == 1 and pills.size() == 1 and head.size() == 1, tag + ": 표 글·표 알약·첫째 줄 %d %d %d" % [marks.size(), pills.size(), head.size()])
	if marks.size() != 1 or pills.size() != 1 or head.size() != 1:
		return
	var t: Rect2 = pills[0]["rect"]
	var spot: Array = ListParts.option_label_lines(lr, 2)[0]
	check(lr.encloses(t), tag + ": 표 알약은 이름 알약 안 %s ⊂ %s" % [t, lr])
	check(absf(t.get_center().y - (float(spot[1]) - int(spot[0]) * 0.36)) < 1.0, tag + ": 표는 첫째 줄 글의 세로 가운데 %s" % t)
	check_eq(marks[0]["fs"], ListParts.OPT_TAG_FS, tag + ": 표 글자 크기")
	var hw := SheetParts.text_width(rt.window, lines[0], head[0]["fs"])
	check(head[0]["fs"] == ListParts.OPT_LABEL_FS and head[0]["rect"].position.x + hw <= t.position.x - ListParts.OPT_TAG_GAP,
		tag + ": 첫째 줄(%.1f px, %d) 은 줄이지 않고 표 앞(%.1f)에서 끝난다" % [hw, head[0]["fs"], t.position.x - ListParts.OPT_TAG_GAP])
	check(head[0]["rect"].end.x <= t.position.x - ListParts.OPT_TAG_GAP + 0.01, tag + ": 첫째 줄 자르기 폭도 표 앞까지 %s" % head[0]["rect"])
	var body := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "text" and e["text"] == lines[1])
	rt.slots[1].erase("clear")
	var plain: Array = await row.call()
	rt.slots[1]["clear"] = true
	await row.call()
	var body0 := plain.filter(func(e: Dictionary) -> bool: return e["kind"] == "text" and e["text"] == lines[1])
	check(body.size() == 1 and body0.size() == 1 and body[0] == body0[0] and body[0]["fs"] == ListParts.OPT_LABEL_SUB_FS,
		tag + ": 둘째 줄 = 클리어하지 않은 줄(글·크기·자리) %s / %s" % [str(body), str(body0)])


## 세 크기의 층 상자(설계 §5.2·§5.3): 물음 창은 화면 안·가운데, 단추 64 이상, 포커스 「아니오」. 이야기 상자는 상자·초상·넘김·키패드가 화면 안,
## 상자 = 의뢰 말 상자 자리, 초상·상자·키패드가 서로 겹치지 않음, 넘김 단추는 상자 안, 누르는 칸 64 이상, 알림 줄은 보이지 않는다.
func test_layers_three_sizes() -> void:
	timeout_sec = 240.0
	for px in SIZES:
		if kit != null:
			kit.dispose()
			kit = null
		if _root_size == Vector2i.ZERO:
			_root_size = tree.root.size
		tree.root.size = px
		var s := await _at_boss()
		var tag := str(px)
		var vp := Rect2(Vector2.ZERO, s.get_viewport_rect().size)
		await _ask(s)
		var panel := s.modal._panel.get_global_rect().merge(s.modal.title_plate.get_global_rect())
		check(s.modal.kind == "boss" and vp.encloses(panel), tag + ": 물음 창은 화면 안")
		check(absf(panel.get_center().x - vp.get_center().x) <= 1.0, tag + ": 물음 창 가운데")
		for n in ["BossYes", "BossNo"]:
			var b := _button(s, n)
			check(b != null and b.size.x >= 64 and b.size.y >= 64 and panel.encloses(b.get_global_rect()), "%s: %s 64 이상, 창 안" % [tag, n])
		check_eq(_focus(s), _button(s, "BossNo"), tag + ": 포커스 「아니오」")
		await kit.press_key(KEY_ESCAPE)
		await kit.frames(2)
		s.state.world.foes["boss"].state = "defeated"
		s.state.world.foes["boss"].day = s.state.day
		s._open_clear("boss")  # 층 상자만 본다(이야기 내용·흐름은 test_victory_story_box)
		await kit.frames(3)
		var sb := s.story_box
		var box := sb.box.get_global_rect()
		var por := sb.portrait.get_global_rect()
		var nxt := sb.next_button.get_global_rect()
		var dp := sb.dir_pad.get_global_rect()
		var kp := sb.key_pad.get_global_rect()
		check_eq(box, Rect2(QuestScreen.BOX_LEFT, vp.size.y - QuestScreen.BOX_BOTTOM - QuestScreen.BOX_H, vp.size.x - QuestScreen.BOX_LEFT - QuestScreen.BOX_RIGHT, QuestScreen.BOX_H),
			tag + ": 상자 = 의뢰 말 상자 자리")
		check_eq(sb.tap.get_global_rect(), box, tag + ": 상자 누르기 = 상자")
		for r in [box, por, nxt, dp, kp]:
			check(vp.encloses(r), "%s: %s 화면 안" % [tag, r])
		check(box.encloses(nxt) and nxt.size.x >= 64 and nxt.size.y >= 64, tag + ": 넘김 단추 상자 안, 64 이상")
		check(not por.intersects(box) and not por.intersects(kp) and not por.intersects(dp), "%s: 초상 %s 은 상자·키패드와 겹치지 않는다" % [tag, por])
		check(not box.intersects(kp) and not box.intersects(dp), tag + ": 상자는 키패드와 겹치지 않는다")
		for k in sb.key_pad.buttons:
			var b: TouchButton = sb.key_pad.buttons[k]
			check(b.size.x >= 64 and b.size.y >= 64, "%s: 키패드 %s 64 이상" % [tag, k])
		check(not s._toast.is_visible_in_tree() or s._toast.modulate.a <= 0.0 or s._toast.text.is_empty(), tag + ": 알림 줄 없음")
		check_eq([s.modal._dim.visible, s.modal.title_plate.visible, s.hud_root.visible], [false, false, false], tag + ": 어두운 판·제목·HUD 없음")


## 웹 확인 J 가 찾은 것(M-U21 이야기 상자 쪽이 요약 신호에 없음): 디버그 주소에서 이야기 상자 쪽이 바뀌면 상태 요약을 다시 낸다(쪽이 바뀐 요약).
func test_story_page_publishes_debug_snapshot() -> void:
	timeout_sec = 120.0
	var s := await _open(Vector2i(5, 2), Dir.W, true, true, "debug=1")
	s.state.world.foes["boss"].state = "defeated"
	s.state.world.foes["boss"].day = s.state.day
	s._open_clear("boss")
	await kit.frames(6)
	var n := s.debug_publishes
	check(n > 0 and s.modal.kind == "clear", "준비: 디버그 주소, 이야기 상자")
	await kit.frames(4)
	check_eq(s.debug_publishes, n, "바뀐 것이 없으면 다시 내지 않는다")
	await kit.tap(kit.center_of(s.story_box.tap))
	await kit.frames(2)
	check(s.debug_publishes > n, "쪽을 넘기면 요약을 다시 낸다(%d → %d)" % [n, s.debug_publishes])
	check_eq(s.debug_snapshot()["story"]["page"], 1, "요약의 쪽 = 둘째")


## M3 A9b 보완 F1 (M-F1a 닫힌 이야기 상자를 떼어 둠, M-F1b 화면을 만들 때 창 층에 맡기지 않음): 이야기 상자는 창 층이 주인이다.
## 열고 닫은 화면 둘과 한 번도 열지 않은 화면 하나를 만들고 버린 뒤 주인 없는 노드 수가 처음과 같다(리뷰: 순환마다 13개씩 남았다).
func test_story_box_lifetime() -> void:
	timeout_sec = 180.0
	if kit != null:
		kit.dispose()
		kit = null
	await tree.process_frame
	await tree.process_frame
	var before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for i in 3:
		var s := await _open(Vector2i(5, 2), Dir.W, true, true)
		if i < 2:
			s.state.world.foes["boss"].state = "defeated"
			s.state.world.foes["boss"].day = s.state.day
			s._open_clear("boss")
			await kit.frames(2)
			check_eq([s.modal.kind, s.story_box.get_parent() == s.modal, s.story_box.visible], ["clear", true, true], "순환 %d: 이야기 상자 열림(창 층 아래)" % i)
			for k in 3:
				await kit.press_key(KEY_ENTER)
			await kit.frames(2)
			check_eq([s.modal.kind, s.modal.part == null, s.story_box.get_parent() == s.modal, s.story_box.visible], ["", true, true, false],
				"순환 %d: 닫으면 감추기만(부품 없음, 주인은 창 층)" % i)
		else:
			check_eq([s.story_box.get_parent() == s.modal, s.story_box.visible], [true, false], "열지 않은 화면: 감춘 채 창 층 아래")
		kit.dispose()
		kit = null
		await tree.process_frame
		await tree.process_frame
	check_eq(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) - before, 0.0, "화면 셋을 버린 뒤 주인 없는 노드 증가 0")


## M3 A9b 보완 F2 (M-F2 닫힌 층의 music_cue): 보스 전투 중 전투가 아닌 저장을 가져오면 층이 닫히고, 닫힌 층의 음악 갈고리는 ""(옛 상태를 말하지 않는다).
## 스냅숏 battle 도 보스를 말하지 않는다.
func test_music_cue_closed_layer() -> void:
	timeout_sec = 150.0
	var s := await _at_boss()
	var layer := await _fight(s)
	check_eq([layer.is_open(), layer.music_cue()], [true, "boss"], "준비: 보스 전투")
	check(s.import_text(FileAccess.get_file_as_string("res://tools/web_check_boss_save.json")), "전투가 아닌 저장 가져오기")
	await kit.frames(3)
	var bat: Dictionary = s.debug_snapshot()["battle"]
	check_eq([layer.is_open(), s.state.battle == null, layer.music_cue(), bat.get("music_cue", ""), bat.get("boss", false)], [false, true, "", "", false],
		"닫힌 층: music_cue \"\", 스냅숏도 보스가 아니다")


## M3 A9b 보완(웹 J 가 찾은 것, M-F4s 전투 띠가 요약 신호에 없음): 디버그 주소에서 보스 전투의 도주 줄을 누르면 띠 알림 「도망칠 수 없다」만 바뀐다
## (단계·커서 그대로). 그래도 상태 요약을 다시 낸다(웹이 이유를 본다).
func test_battle_notice_publishes_debug_snapshot() -> void:
	timeout_sec = 150.0
	var s := await _open(Vector2i(5, 2), Dir.W, true, true, "debug=1")
	var layer := await _fight(s)
	check(layer.is_open(), "준비: 보스 전투")
	if not layer.is_open():
		return
	for i in 600:
		if layer.banner_lines()[1] != s.texts.t("msg.boss_contact"):
			break
		await kit.frames(1)
	await kit.frames(6)
	var n := s.debug_publishes
	var before := [layer.phase, layer.sub, layer.member]
	await kit.tap(kit.center_of(layer.panel.command_buttons[CommandPanel.CMD_ESCAPE]))
	await kit.frames(3)
	check_eq([layer.banner_lines()[1], [layer.phase, layer.sub, layer.member]], [s.texts.t("battle.reason.no_escape"), before], "도주 줄 → 이유 알림만(단계·커서 그대로)")
	check(s.debug_publishes > n, "띠가 바뀌면 요약을 다시 낸다(%d → %d)" % [n, s.debug_publishes])
	check_eq(s.debug_snapshot()["battle"]["banner"][1], s.texts.t("battle.reason.no_escape"), "요약의 띠 = 이유")
