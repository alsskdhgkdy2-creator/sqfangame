## 파티 메뉴 장면 시험(07 §10.4, 05 §11.2 실행기 경로): 실제 입력 경로(Input.parse_input_event)로 누르고 끌고 떼며,
## 메뉴가 가진 초안·커서·확인 창과 규칙 상태·자동 저장을 본다. 저장은 장면 시험 임시 폴더에만 쓴다.
## 결과는 구성으로 정한다(D15): 성장 준비는 규칙 함수(grant_exp·supply)로 만들고 전투는 battle_finish 로 끝낸다.
## 미궁 화면 없이 메뉴만 띄우는 시험(시험용 트리·배치)은 host 아래에 메뉴를 둔다(화면비 2.4 는 host 크기로 본다).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const START := Vector2i(2, 18)
const DUELIST_A := 1
const KNIGHT := 0
const WIZARD := 4
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const CROSS_SWEEP := "skill.blade_duelist.cross_sweep"
const LEG_CUTTER := "skill.blade_duelist.leg_cutter"
const QUICK_DRAW := "skill.blade_duelist.quick_draw"
const ION_SABER := "equip.ion_saber"
const TWIN_EDGE := "equip.twin_edge"
const EDGE_LEFT := "skill.glyph_wizard.edge_left"
const EDGE_RIGHT := "skill.glyph_wizard.edge_right"
const WIDE := Vector2(1728, 720)
const BASE := Vector2(1280, 720)

var kit: Kit
var host: Control
var texts: TextDb
var host_saves := 0


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()


func _open(query: String = "", native_debug: bool = false) -> DungeonScreen:
	timeout_sec = 40.0
	kit = Kit.new(tree)
	texts = TextDb.load_path("res://data/text/ko.json")
	var s := await kit.open("native", 7, query)
	s.native_debug = native_debug  # 시험 실행은 디버그 빌드라 일반 실행을 보려면 끈다(07 §5.7)
	return s


## 준비(규칙 함수로): 듀얼리스트 A 를 Lv3·남은 SP 2 로, bag 의 장비를 가방에.
func _prep_duelist(s: DungeonScreen, bag: Dictionary = {}) -> void:
	var defs := s.state.defs
	var m := s.state.party.members[DUELIST_A]
	GrowthRules.grant_exp(s.state, DUELIST_A, defs.battle.growth.cum(3) - m.exp)
	check(m.level == 3 and GrowthRules.sp_left(defs, m) == 2, "준비: 듀얼리스트 A Lv3·남은 SP 2 (Lv %d, SP %d)" % [m.level, GrowthRules.sp_left(defs, m)])
	for id in bag:
		GrowthRules.supply(s.state, id, bag[id])


func _skill_tab_on_duelist(s: DungeonScreen) -> PartyMenu:
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_E)
	var pm := s.party_menu
	check(pm.is_open() and pm.tab == 1 and pm.member == DUELIST_A, "준비: 스킬 탭·듀얼리스트 A")
	return pm


func _equip_tab_on(s: DungeonScreen, member_steps: int) -> PartyMenu:
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	for i in member_steps:
		await kit.press_key(KEY_E)
	var pm := s.party_menu
	check(pm.is_open() and pm.tab == 2 and pm.member == member_steps, "준비: 장비 탭·칸 %d 대원" % member_steps)
	return pm


## 자동 저장 파일이 지금 상태와 같은 세대·같은 상태인지.
func _check_auto_matches(s: DungeonScreen, label: String) -> void:
	check_eq(kit.auto_generation(), s.state.generation, label + ": 자동 저장 세대")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), label + ": 자동 저장 내용 = 지금 상태")


func _annotation_json(s: DungeonScreen) -> String:
	return JSON.stringify(SaveCodec.state_to_dict(s.state)["annotation"])


## 위험도를 한계 바로 밑에 두고 북쪽으로 (2,15)까지 → 안전 구역을 벗어난 첫 걸음에 전투.
func _walk_into_battle(s: DungeonScreen) -> void:
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for i in 6:
		if s.state.party.at.y <= 15 or s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)


## 구성으로 정해지는 승리: 디버그 요청 battle_finish → 결과 창 → Enter. 화면은 디버그 주소로 연 것이어야 한다.
func _finish_battle(s: DungeonScreen) -> void:
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "battle_finish"})))
	check(typeof(r) == TYPE_DICTIONARY and r.get("ok", false), "battle_finish: %s" % str(r))
	await kit.frames(2)
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)


func _wait_sec(sec: float) -> void:
	await tree.create_timer(sec).timeout


## 미궁 화면 없이 메뉴만 띄운다(host 크기 = 화면 크기). debug 면 임시 보급을 보인다.
func _host_menu(defs: GameDefs, sz: Vector2, debug: bool = false, bag: Dictionary = {}) -> PartyMenu:
	timeout_sec = 40.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "PartyHost"
	host.position = Vector2.ZERO
	host.size = sz
	tree.root.add_child(host)
	var pm := PartyMenu.new()
	host.add_child(pm)
	pm.build(texts)
	pm.debug = debug
	pm.save_hook = func() -> void: host_saves += 1
	var st := ExplorationRules.new_game(defs, 1, "floor")
	for id in bag:
		GrowthRules.supply(st, id, bag[id])
	pm.open(st)
	await kit.frames(2)
	return pm


func _step(pm: PartyMenu, kind: String, arg: Variant = null) -> bool:
	var ok := pm.handle(kind, arg)
	await kit.frames(1)
	return ok


# ---- 여는 곳·막는 때 (07 §9.1) ----

func test_opens_by_button_and_key_on_status_tab_member_0() -> void:
	var s := await _open()
	var pm := s.party_menu
	check(s.party_button.is_visible_in_tree(), "탐색 중 「파티」 단추가 보인다")
	check(s.party_button.get_parent() == s.hint_row and s.party_button.get_index() < s.map_button.get_index(), "자리: 왼쪽 아래 안내 줄, 지도 단추 왼쪽")
	check_eq(s.party_button.size, Vector2(64, 64), "64×64")
	check(not s.party_button.get_global_rect().intersects(s.map_button.get_global_rect()), "지도 단추와 겹치지 않는다")
	await kit.tap(kit.center_of(s.party_button))
	check(pm.is_open(), "단추로 열림")
	check_eq([pm.tab, pm.member, pm.dialog_kind], [0, 0, ""], "상태 탭·칸 0 대원·확인 창 없음")
	await kit.tap(kit.center_of(pm.close_button))
	check(not pm.is_open(), "「닫기」로 닫힘")
	await kit.press_key(KEY_P)
	check(pm.is_open(), "P 로 열림")
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_E)
	await kit.press_key(KEY_RIGHT)
	check_eq([pm.tab, pm.member, pm.skill_tab.cursor], [1, 1, 1], "준비: 스킬 탭·대원 1·커서 1")
	await kit.press_key(KEY_P)
	check(not pm.is_open(), "P 로 닫힘")
	await kit.press_key(KEY_P)
	check_eq([pm.tab, pm.member, pm.skill_tab.cursor, pm.equip_tab.cursor], [0, 0, 0, 0], "다시 열면 상태 탭·칸 0·커서 처음")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "Esc 로 닫힘")
	check_eq(s.modal.kind, "", "Esc 는 주 메뉴를 열지 않는다")


func test_not_opened_with_window_moving_battle_or_wipe() -> void:
	var s := await _open("debug=1")
	var pm := s.party_menu
	# 다른 창
	await kit.press_key(KEY_ESCAPE)
	check_eq(s.modal.kind, "menu", "준비: 주 메뉴")
	await kit.press_key(KEY_P)
	check(not pm.is_open(), "주 메뉴가 떠 있으면 P 를 무시한다")
	s._open_party()
	check(not pm.is_open(), "창이 열려 있으면 열지 않는다")
	await kit.press_key(KEY_ESCAPE)
	check_eq(s.modal.kind, "", "준비: 주 메뉴 닫힘")
	# 이동 연출 중
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	check(s.view.is_busy(), "준비: 이동 연출 중")
	await kit.press_key(KEY_P)
	check(not pm.is_open(), "이동 연출 중에는 P 로 열리지 않는다")
	await kit.tap(kit.center_of(s.party_button))
	check(not pm.is_open(), "이동 연출 중에는 단추로도 열리지 않는다")
	for i in 40:
		if not s.view.is_busy():
			break
		await _wait_sec(0.05)
	s.view.speed = 0.0
	check(not s.view.is_busy(), "준비: 연출 끝")
	# 전투
	await _walk_into_battle(s)
	check(s.battle_layer.is_open(), "준비: 전투")
	check(not s.party_button.is_visible_in_tree(), "전투 중에는 「파티」 단추를 숨긴다")
	await kit.press_key(KEY_P)
	check(not pm.is_open(), "전투 중 P 무시")
	s._open_party()
	check(not pm.is_open(), "전투 중에는 열지 않는다")
	await _finish_battle(s)
	check(not s.battle_layer.is_open() and s.party_button.is_visible_in_tree(), "전투가 끝나면 단추가 다시 보인다")
	# 전멸
	for m in s.state.party.members:
		m.hp = 0
	s.state.wiped = true
	s._check_windows()
	check_eq(s.modal.kind, "wipe", "준비: 전멸 창")
	await kit.press_key(KEY_P)
	check(not pm.is_open(), "전멸이면 P 무시")
	s._open_party()
	check(not pm.is_open(), "전멸이면 열지 않는다")


func test_open_menu_blocks_moves_pad_and_map_edits() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.open_map()
	s.map.tool = "color"
	s.map.paint_color = 3
	var cell_pos := kit.map_cell(Vector2i(1, 18))
	var fwd_pos := kit.center_of(s.pad[A.FORWARD])
	var inv_pos := kit.center_of(s.pad[A.INVESTIGATE])
	await kit.press_key(KEY_P)
	check(pm.is_open(), "준비: 메뉴")
	var h := kit.hash_now()
	var n := s.autosave_count
	var ann := _annotation_json(s)
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	await kit.tap(fwd_pos)
	await kit.tap(inv_pos)
	await kit.tap(cell_pos)
	s.request_action(A.FORWARD)
	await kit.frames(3)
	check(pm.is_open(), "메뉴는 열린 채")
	check_eq(s.state.party.at, START, "이동 없음")
	check_eq(kit.hash_now(), h, "상태 해시 그대로(이동·조사·지도 편집 없음)")
	check_eq(_annotation_json(s), ann, "지도 데이터 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	check_eq(s._queued, -1, "미리 받은 이동 없음")


func test_held_move_key_after_close_does_not_step() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	kit.key(KEY_W, true)  # 메뉴가 열린 동안 누르고 있는 이동 키
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "준비: 닫힘")
	await _wait_sec(0.4)  # 누르고 있기 반복 시작(220ms)보다 길게
	await kit.frames(3)
	check_eq(s.state.party.at, START, "닫은 뒤 누르고 있던 이동 키는 걸음이 되지 않는다")
	kit.key(KEY_W, false)
	await kit.frames(2)
	await kit.press_key(KEY_W)
	check_eq(s.state.party.at, START + Vector2i(0, -1), "다시 누르면 한 걸음")


# ---- 스킬 (07 §4.6, §9.2) ----

func test_plus_changes_only_the_draft() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var h := kit.hash_now()
	var n := s.autosave_count
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft, {HIGH_SLASH: 1}, "「+」 → 초안 +1")
	check_eq(kit.hash_now(), h, "상태 해시 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	check_eq(s.state.party.members[DUELIST_A].skills[HIGH_SLASH], 1, "배운 레벨 그대로")
	check_eq(st.nodes[0].draft, 1, "노드에 초안 표시")
	check_eq(st.nodes[0].level_line, "Lv 2/5", "노드 레벨은 초안을 넣은 값")
	check_eq(st._sp_label.text, "남은 SP 2 → 1", "초안이 있으면 「남은 SP 지금 → 확정 뒤」")
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st._sp_label.text, "남은 SP 2 → 0", "초안 둘")
	await kit.tap(kit.center_of(st.revert_button))
	check_eq(st._sp_label.text, "남은 SP 2", "초안이 없으면 남은 SP 만")


func test_commit_dialog_back_keeps_draft_and_confirm_allocates_once() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	await kit.tap(kit.center_of(st.plus_button))
	var h := kit.hash_now()
	var n := s.autosave_count
	await kit.tap(kit.center_of(st.commit_button))
	check_eq([pm.dialog_kind, pm.dialog_pick], ["commit", 0], "「확정」 → 확정 확인 창(처음 고른 쪽 「돌아가기」)")
	check(pm.dialog_layer.is_visible_in_tree(), "확인 창이 보인다")
	check(pm._dialog_text.text.contains("SP 1"), "확인 글: %s" % pm._dialog_text.text)
	await kit.tap(kit.center_of(pm.dialog_buttons[0]))
	check_eq(pm.dialog_kind, "", "「돌아가기」 → 창만 닫힘")
	check_eq(st.draft, {HIGH_SLASH: 1}, "초안 그대로")
	check_eq(kit.hash_now(), h, "상태 해시 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	await kit.tap(kit.center_of(st.commit_button))
	await kit.tap(kit.center_of(pm.dialog_buttons[1]))
	check_eq(pm.dialog_kind, "", "「확정」 → 창 닫힘")
	check_eq(s.state.party.members[DUELIST_A].skills[HIGH_SLASH], 2, "하이 슬래시 Lv2")
	check_eq(st.draft, {}, "초안을 지운다")
	check_eq(s.autosave_count, n + 1, "자동 저장 1회")
	_check_auto_matches(s, "배분 확정")
	check(pm.notice.contains(texts.t("member.blade_duelist")), "알림 줄: %s" % pm.notice)


func test_minus_lowers_draft_only_and_is_blocked_by_prerequisite_and_revert_clears() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var h := kit.hash_now()
	var n := s.autosave_count
	await kit.tap(kit.center_of(st.minus_button))
	check_eq(pm.notice, texts.t("growth.reason.no_draft"), "초안이 없으면 「−」는 이유만")
	await kit.tap(kit.center_of(st.plus_button))
	await kit.press_key(KEY_DOWN)
	check_eq(st.cursor_skill(), LEG_CUTTER, "↓ → 레그 커터(같은 열)")
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft, {HIGH_SLASH: 1, LEG_CUTTER: 1}, "선행을 초안으로 채우고 다음 스킬도 초안")
	await kit.press_key(KEY_UP)
	check_eq(st.cursor_skill(), HIGH_SLASH, "↑ → 하이 슬래시")
	await kit.tap(kit.center_of(st.minus_button))
	check_eq(st.draft, {HIGH_SLASH: 1, LEG_CUTTER: 1}, "선행이 깨지는 「−」는 막는다")
	check_eq(pm.notice, texts.t("growth.reason.requires"), "막은 이유를 알린다")
	await kit.press_key(KEY_DOWN)
	await kit.tap(kit.center_of(st.minus_button))
	check_eq(st.draft, {HIGH_SLASH: 1}, "「−」는 초안만 내린다")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_BACKSPACE)
	check_eq(st.draft, {}, "Backspace = 「−」")
	await kit.tap(kit.center_of(st.minus_button))
	check_eq(s.state.party.members[DUELIST_A].skills[HIGH_SLASH], 1, "확정한 레벨 아래로는 내리지 않는다")
	await kit.tap(kit.center_of(st.plus_button))
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft, {HIGH_SLASH: 2}, "준비: 초안 +2")
	await kit.tap(kit.center_of(st.revert_button))
	check_eq(st.draft, {}, "「되돌리기」 → 초안 전체를 지운다")
	check_eq(kit.hash_now(), h, "상태 해시 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")


func test_draft_then_member_tab_or_close_asks_to_discard() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var h := kit.hash_now()
	var n := s.autosave_count
	await kit.tap(kit.center_of(st.plus_button))
	await kit.press_key(KEY_Q)
	check_eq([pm.dialog_kind, pm.dialog_pick], ["discard", 0], "초안 중 대원 바꾸기 → 버리기 확인 창(「돌아가기」)")
	check(pm._dialog_text.text == texts.t("party.dialog.discard_text"), "확인 글")
	check_eq(pm.member, DUELIST_A, "아직 대원 그대로")
	await kit.tap(kit.center_of(pm.dialog_buttons[0]))
	check_eq([pm.dialog_kind, pm.member, st.draft], ["", DUELIST_A, {HIGH_SLASH: 1}], "「돌아가기」 → 초안 유지·대원 그대로")
	await kit.tap(kit.center_of(pm.cells[3]))
	check_eq(pm.dialog_kind, "discard", "대원 칸 누르기도 확인 창")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.dialog_kind, pm.member, st.draft], ["", DUELIST_A, {HIGH_SLASH: 1}], "확인 창 Esc = 「돌아가기」")
	await kit.press_key(KEY_1)
	check_eq(pm.dialog_kind, "discard", "탭 바꾸기 → 확인 창")
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.dialog_kind, pm.tab, st.draft], ["", 0, {}], "「버리기」 → 초안이 사라지고 탭이 바뀐다")
	check_eq(kit.hash_now(), h, "상태 해시 그대로")
	await kit.press_key(KEY_2)
	await kit.tap(kit.center_of(st.plus_button))
	await kit.tap(kit.center_of(pm.close_button))
	check_eq(pm.dialog_kind, "discard", "「닫기」 → 확인 창")
	await kit.tap(kit.center_of(pm.dialog_buttons[1]))
	check(not pm.is_open(), "「버리기」 → 메뉴 닫힘")
	check_eq(kit.hash_now(), h, "버린 뒤 상태 해시 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")


func test_presses_behind_dialog_do_nothing() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	await kit.tap(kit.center_of(st.plus_button))
	await kit.press_key(KEY_F)
	check_eq(pm.dialog_kind, "commit", "준비: 확정 확인 창")
	var acc := pm.accepted_inputs
	# 확인 창 사각형 밖에 보이는 뒤 화면의 것만 누른다(시험 창은 1280×1280 으로 늘어나 창이 조작 줄 위에 올 수 있다).
	var panel := Rect2(pm.get_global_transform_with_canvas() * pm.dialog_rect().position, pm.dialog_rect().size)
	var behind := 0
	for c in [st.nodes[1], pm.tab_buttons[0], pm.cells[3], pm.close_button, st.plus_button, st.revert_button, st.commit_button]:
		if panel.has_point((c as Control).get_global_rect().get_center()):
			continue
		behind += 1
		await kit.tap(kit.center_of(c))
	await kit.tap(kit.at(pm, pm.dialog_rect().position + Vector2(20, 20)))  # 창 안의 빈 곳
	check(behind >= 5, "준비: 뒤 화면 누를 곳 %d 개" % behind)
	for k in [KEY_1, KEY_Q, KEY_E, KEY_BACKSPACE, KEY_R, KEY_UP, KEY_P]:
		await kit.press_key(k)
	check_eq(pm.accepted_inputs, acc, "뒤의 노드·탭·대원·닫기·키는 받지 않는다")
	check_eq([pm.dialog_kind, pm.tab, pm.member, st.cursor, st.draft], ["commit", 1, DUELIST_A, 0, {HIGH_SLASH: 1}], "아무 일 없음")
	check(pm.is_open(), "메뉴는 열린 채")


func test_locked_node_plus_shows_reason_without_change() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var j: int = s.state.defs.class_of(DUELIST_A).tree_index[QUICK_DRAW]
	await kit.tap(kit.center_of(st.nodes[j]))
	check_eq(st.cursor, j, "노드 누르기 → 그 노드")
	check_eq(st._desc_title.text, texts.t(QUICK_DRAW), "설명 칸이 그 스킬")
	check_eq([st.nodes[j].status_kind, st.nodes[j].status_line], ["locked", "잠김"], "잠긴 노드")
	check(st._desc_body.text.contains("미충족") and st._desc_body.text.contains("Lv 5 이상"), "선행·관문 줄: %s" % st._desc_body.text)
	var why := GrowthRules.learn_block(s.state.defs, DUELIST_A, s.state.party.members[DUELIST_A], {}, QUICK_DRAW)
	var h := kit.hash_now()
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(pm.notice, texts.t("growth.reason." + why), "잠긴 노드 「+」 → 이유 알림")
	check_eq(st.draft, {}, "초안 변화 없음")
	check_eq(kit.hash_now(), h, "상태 그대로")


## 스킬 설명의 레벨 줄에 TP 도 「지금 → 다음」으로 나온다(07 §9.2·§4.5).
func test_skill_preview_shows_tp_change_only_and_increase() -> void:
	var defs := Fx.defs()
	var pm := await _host_menu(defs, BASE)
	var medic := 3
	var refresh := "skill.nano_medic.refresh_patch"
	var m := pm.state.party.members[medic]
	GrowthRules.grant_exp(pm.state, medic, defs.battle.growth.cum(3) - m.exp)
	var ev := GrowthRules.allocate(pm.state, medic, {refresh: 2})
	check(ev.is_empty() or ev[0]["type"] != "rejected", "준비: 리프레시 패치 Lv2 (%s)" % str(ev))
	check(GrowthRules.sp_left(defs, m) > 0, "준비: 남은 SP 있음")
	pm.refresh_view()
	await kit.press_key(KEY_2)
	await _step(pm, "member", medic)
	var st := pm.skill_tab
	await kit.tap(kit.center_of(st.nodes[defs.class_of(medic).tree_index[refresh]]))
	check_eq(st.cursor_skill(), refresh, "준비: 리프레시 패치")
	var lines := st._desc_body.text.split("\n")
	check(lines.has("Lv 2 → Lv 3"), "Lv 2 → Lv 3: %s" % str(lines))
	check(lines.has("TP  4 → 3"), "TP 만 바뀌는 스킬: 「TP  4 → 3」")
	await _step(pm, "member", DUELIST_A)
	var d := pm.state.party.members[DUELIST_A]
	GrowthRules.grant_exp(pm.state, DUELIST_A, defs.battle.growth.cum(3) - d.exp)
	pm.refresh_view()
	await kit.tap(kit.center_of(st.nodes[defs.class_of(DUELIST_A).tree_index[HIGH_SLASH]]))
	lines = st._desc_body.text.split("\n")
	check(lines.has("TP  4 → 4"), "하이 슬래시 Lv1 → 2: TP 그대로도 보인다: %s" % str(lines))
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft, {HIGH_SLASH: 1}, "「+」 → 초안 Lv2")
	lines = st._desc_body.text.split("\n")
	check(lines.has("Lv 2 → Lv 3") and lines.has("TP  4 → 5"), "초안 Lv2 → 3: TP 가 오른다 「TP  4 → 5」: %s" % str(lines))
	check(lines.has("위력  160 → 170"), "다른 값 줄도 그대로")


func test_notice_does_not_survive_close_and_reopen() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	check_eq(GrowthRules.sp_left(s.state.defs, s.state.party.members[pm.member]), 0, "준비: 남은 SP 0")
	await kit.press_key(KEY_ENTER)
	check_eq(pm.notice, "SP가 부족하다", "준비: 알림")
	check_eq(pm._notice_label.text, "SP가 부족하다", "알림 줄 글")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "닫힘")
	await kit.press_key(KEY_P)
	check(pm.is_open() and pm.tab == 0, "곧바로 다시 열림(상태 탭)")
	check_eq([pm.notice, pm._notice_label.text], ["", ""], "앞 알림이 남지 않는다")
	await _wait_sec(0.3)
	check_eq(pm._notice_label.text, "", "조금 지나도 비어 있다")
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	check_eq(pm._notice_label.text, "SP가 부족하다", "새 알림은 그대로 뜬다")
	check_eq(pm._notice_label.modulate.a, 1.0, "흐림 없이")


func test_no_sp_node_is_dimmed_like_locked_and_plus_does_nothing() -> void:
	var s := await _open()
	var defs := s.state.defs
	var m := s.state.party.members[DUELIST_A]
	check_eq([m.level, GrowthRules.sp_left(defs, m)], [1, 0], "준비: 새 게임 듀얼리스트 A Lv1·남은 SP 0")
	check_eq(GrowthRules.learn_block(defs, DUELIST_A, m, {}, HIGH_SLASH), "no_sp", "준비: 규칙 판정이 SP 부족")
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var j: int = defs.class_of(DUELIST_A).tree_index[HIGH_SLASH]
	await kit.tap(kit.center_of(st.nodes[j]))
	check_eq(st.cursor, j, "노드 누르기 → 그 노드")
	var nd := st.nodes[j]
	check_eq([nd.status_kind, nd.status_line], ["no_sp", "SP 부족"], "SP 부족 노드")
	var locked := st.nodes[defs.class_of(DUELIST_A).tree_index[QUICK_DRAW]]
	check_eq(locked.status_kind, "locked", "준비: 퀵 드로는 잠김")
	check(nd.is_dim() and locked.is_dim(), "SP 부족도 잠김과 같이 흐리게")
	check(st.plus_button.dimmed, "「+」 흐림")
	var sp_line := st._sp_label.text
	check_eq(sp_line, "남은 SP 0", "남은 SP 줄")
	var h := kit.hash_now()
	var g := s.state.generation
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(pm.notice, texts.t("growth.reason.no_sp"), "「+」 → SP 부족 알림")
	check_eq(st.draft, {}, "초안 변화 없음")
	check_eq(st._sp_label.text, sp_line, "남은 SP 줄 그대로")
	check_eq(nd.draft, 0, "노드에 「+k」 없음")
	await _step(pm, "plus")
	check_eq(st.draft, {}, "키보드 「+」도 초안 변화 없음")
	check_eq([kit.hash_now(), s.state.generation], [h, g], "상태·세대 그대로(저장 없음)")


# ---- 트리 영역 끝 (07 §9.2) ----

func _edge_defs() -> GameDefs:
	var files := Fx.battle_files()
	var base: Dictionary = files["skills/glyph_wizard.json"]["skills"][0]
	for spec in [[EDGE_LEFT, [0, 4]], [EDGE_RIGHT, [3, 4]]]:
		var sk := base.duplicate(true)
		sk["id"] = spec[0]
		sk["name_key"] = spec[0]
		Fx.add_tree_skill(files, "classes/glyph_wizard.json", sk, spec[1])
	return Fx.defs_from(files)


func test_tree_area_edge_nodes_are_inside_and_pressable() -> void:
	kit = Kit.new(tree)
	texts = TextDb.load_path("res://data/text/ko.json")
	var defs := _edge_defs()
	check(defs != null, "준비: 열 0·행 4 와 열 3·행 4 노드가 있는 시험 트리")
	if defs == null:
		return
	for sz in [BASE, WIDE]:
		var pm := await _host_menu(defs, sz)
		await _step(pm, "tab", 1)
		await _step(pm, "member", WIZARD)
		var st := pm.skill_tab
		var area := st.tree_rect()
		var row := Rect2(PartyMenu.TAB_X, PartySkillTab.ROW_Y, sz.x - PartyMenu.TAB_X, 72)
		if sz == BASE:
			check_eq(area, Rect2(300, 80, 600, 552), "1280×720 트리 영역 x 300~900, y 80~632")
		check(area.end.x <= st.desc_rect().position.x and area.position.x >= PartyMenu.TAB_X, "%s: 트리 영역은 설명 칸 왼쪽" % str(sz))
		for sid in [EDGE_LEFT, EDGE_RIGHT]:
			var j: int = defs.class_of(WIZARD).tree_index[sid]
			var nd := st.nodes[j]
			var full := Rect2(nd.get_global_position() - pm.get_global_position(), nd.size)
			check(area.encloses(full), "%s %s: 노드 %s 가 트리 영역 %s 안" % [str(sz), sid, str(full), str(area)])
			check(not full.intersects(row), "%s %s: 조작 줄과 겹치지 않는다" % [str(sz), sid])
			check_eq(pm.clipped_rect(nd), full, "%s %s: 잘리지 않는다" % [str(sz), sid])
			if sz == BASE:
				var want := Rect2(308, 536, 136, 88) if sid == EDGE_LEFT else Rect2(764, 536, 136, 88)
				check_eq(full, want, "1280×720 %s 자리" % sid)
			await kit.tap(kit.center_of(nd))
			check_eq(st.cursor, j, "%s %s: 가운데 누르기 → 그 노드" % [str(sz), sid])
			check_eq(st._desc_title.text, texts.t(sid), "%s %s: 설명 칸이 그 스킬" % [str(sz), sid])


# ---- 장비 (07 §5.7, §9.2) ----

func test_equip_from_list_autosaves_and_unequip_row_removes() -> void:
	var s := await _open()
	_prep_duelist(s, {ION_SABER: 1})
	var pm := await _equip_tab_on(s, DUELIST_A)
	var et := pm.equip_tab
	var m := s.state.party.members[DUELIST_A]
	check_eq(m.equip[0], TWIN_EDGE, "준비: 칸 0 트윈 엣지")
	await kit.tap(kit.center_of(et.slot_rows[0]))
	check(et.list_open and et.list.is_visible_in_tree(), "칸 누르기 → 그 칸 목록")
	check_eq(et.row_items, ["", ION_SABER], "목록: 맨 위 「빼기」, 낄 수 있는 가방 장비")
	check_eq(et.rows[0].text, "빼기", "「빼기」 줄")
	check(et.rows[1].note.contains("공격 +8"), "바뀌는 값 글자: %s" % et.rows[1].note)
	check(et.rows[0].note.contains("공격 -14"), "빼기의 바뀌는 값: %s" % et.rows[0].note)
	check_eq(et.rows[1].right, "1개", "개수")
	var n := s.autosave_count
	await kit.tap(kit.center_of(et.rows[1]))
	check_eq(m.equip[0], ION_SABER, "줄 누르기 → 장착")
	check_eq(s.state.gear_bag, {TWIN_EDGE: 1}, "가방: 벗긴 장비 +1, 낀 장비 −1")
	check_eq(s.autosave_count, n + 1, "자동 저장 1회")
	_check_auto_matches(s, "장착")
	check(not et.list_open and et.cursor == 0, "목록을 닫고 커서는 그 칸")
	check(et.slot_rows[0].text == texts.t("equip.ion_saber"), "칸 줄이 새 장비")
	await kit.tap(kit.center_of(et.slot_rows[0]))
	await kit.tap(kit.center_of(et.rows[0]))
	check_eq(m.equip[0], "", "「빼기」 → 칸이 빈다")
	check_eq(s.state.gear_bag, {TWIN_EDGE: 1, ION_SABER: 1}, "가방에 돌아온다")
	check_eq(s.autosave_count, n + 2, "빼기도 자동 저장")


func test_unequippable_rows_are_dimmed_with_reason_and_cannot_be_chosen() -> void:
	var s := await _open()
	_prep_duelist(s, {"equip.focus_staff": 1, "equip.tactical_baton": 1, "equip.medic_coat": 1})
	var pm := await _equip_tab_on(s, DUELIST_A)
	var et := pm.equip_tab
	var m := s.state.party.members[DUELIST_A]
	await kit.tap(kit.center_of(et.slot_rows[0]))
	check_eq(et.row_items, ["", "equip.focus_staff", "equip.tactical_baton"], "칸 0: 무기만, 못 끼는 것은 아래(칸 종류가 다른 몸 장비는 없음)")
	check_eq(et.row_block, ["", "class", "class"], "못 끼는 이유")
	check(et.rows[1].dimmed and et.rows[1].note == "이 직업은 못 낀다", "흐리게·이유: %s" % et.rows[1].note)
	var h := kit.hash_now()
	var n := s.autosave_count
	await kit.tap(kit.center_of(et.rows[2]))
	check_eq(m.equip[0], TWIN_EDGE, "못 끼는 줄 누르기 → 장착 없음")
	check_eq(pm.notice, "이 직업은 못 낀다", "이유 알림")
	check(et.list_open, "목록 그대로")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq(m.equip[0], TWIN_EDGE, "키보드로 골라도 장착 없음")
	check_eq(kit.hash_now(), h, "상태 그대로")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	await kit.tap(kit.center_of(et.slot_rows[3]))
	check_eq(et.row_items, ["", "equip.medic_coat"], "칸 3: 몸 장비는 같은 종류 제한")
	check_eq(et.row_block, ["unchanged", "kind_limit"], "빈 칸 빼기·같은 종류")
	check_eq(et.rows[1].note, "같은 종류가 이미 있다", "같은 종류 이유")
	await kit.tap(kit.center_of(et.rows[1]))
	check_eq(m.equip[3], "", "장착 없음")


# ---- 소지품·임시 보급 (07 §5.6·§5.7) ----

func test_supply_is_hidden_in_a_normal_run() -> void:
	var s := await _open()
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	var pm := s.party_menu
	var it := pm.items_tab
	check_eq(pm.tab, 3, "준비: 소지품 탭")
	check(not pm.debug, "일반 실행(디버그 주소 아님, 네이티브 디버그 아님)")
	check(not it.supply_button.is_visible_in_tree(), "「임시 보급」 단추 없음")
	check(pm.visible_buttons().filter(func(b: TouchButton) -> bool: return b.name.begins_with("Supply") or b.name.begins_with("Exp")).is_empty(), "보급 단추 없음")
	check(not pm.handle("supply_toggle"), "보급 입력도 받지 않는다")


func test_supply_and_exp_buttons_with_debug_flag() -> void:
	var s := await _open("debug=1")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	var pm := s.party_menu
	var it := pm.items_tab
	check(pm.debug and it.supply_button.is_visible_in_tree(), "디버그 주소 → 「임시 보급(시험용)」")
	check_eq(it.supply_button.size, Vector2(240, 64), "240×64")
	await kit.tap(kit.center_of(it.supply_button))
	check(it.supply_open, "누르면 보급 줄이 열린다")
	var k := s.state.defs.battle.equipment_ids.find(ION_SABER)
	var b := it.plus_buttons[k]
	check_eq(b.size, Vector2(96, 64), "「+1」 96×64")
	it.list.ensure_visible(b.position.y, b.position.y + b.size.y)
	await kit.frames(1)
	var n := s.autosave_count
	await kit.tap(kit.center_of(b))
	check_eq(int(s.state.gear_bag.get(ION_SABER, 0)), 1, "「+1」 → 가방 +1")
	check_eq(s.autosave_count, n + 1, "자동 저장")
	_check_auto_matches(s, "임시 보급")
	var e := it.exp_buttons[KNIGHT]
	check_eq(e.size, Vector2(200, 64), "「경험치 +100」 200×64")
	it.list.ensure_visible(e.position.y, e.position.y + e.size.y)
	await kit.frames(1)
	var m := s.state.party.members[KNIGHT]
	await kit.tap(kit.center_of(e))
	check_eq([m.level, m.exp], [2, 100], "「경험치 +100」 → 레벨이 오른다")
	check_eq(s.autosave_count, n + 2, "자동 저장")
	await kit.tap(kit.center_of(it.next_buttons[KNIGHT]))
	check_eq([m.level, m.exp], [3, s.state.defs.battle.growth.cum(3)], "「다음 레벨까지」 → 다음 레벨 바로")
	check_eq(s.autosave_count, n + 3, "자동 저장")


func test_native_debug_build_shows_supply() -> void:
	var s := await _open("", true)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	check(s.party_menu.debug and s.party_menu.items_tab.supply_button.is_visible_in_tree(), "네이티브 디버그 실행 → 보급 단추")


func _full_bag_items_tab(debug: bool) -> PartyMenu:
	var defs := Fx.defs()
	var bag := {}
	for id in defs.battle.equipment_ids:
		bag[id] = 1
	var pm := await _host_menu(defs, BASE, debug, bag)
	for id in ["item.neon_rat_tail", "item.cable_scale", "item.glow_scale", "item.spore_pouch"]:
		pm.state.materials[id] = 2
	pm.refresh_view()
	await kit.press_key(KEY_4)
	check_eq(pm.tab, 3, "준비: 소지품 탭")
	check(pm.items_tab.list.max_scroll() > 200.0, "준비: 소지품이 넘친다(%.0f)" % pm.items_tab.list.max_scroll())
	return pm


func test_items_keyboard_reaches_read_only_inventory_in_debug() -> void:
	var pm := await _full_bag_items_tab(true)
	var it := pm.items_tab
	var list := it.list
	check_eq(it.actionable(), [it.supply_button] as Array[PartyButton], "보급을 닫으면 누를 단추는 「임시 보급」 하나")
	await kit.press_key(KEY_DOWN)
	check(list.scroll > 0.0, "마지막 단추에서 ↓ → 목록을 내린다")
	check_eq(it.cursor, 0, "커서는 그대로")
	for k in 40:
		await kit.press_key(KEY_DOWN)
	check_eq(list.scroll, list.max_scroll(), "↓ 를 이어 누르면 소지품 끝까지")
	for k in 40:
		await kit.press_key(KEY_UP)
	check_eq(list.scroll, 0.0, "↑ 로 맨 위까지 돌아온다")
	await kit.press_key(KEY_ENTER)
	check(it.supply_open, "Enter → 보급 줄 열림")
	var acts := it.actionable()
	for k in acts.size() - 1:
		await kit.press_key(KEY_DOWN)
	check_eq(it.cursor, acts.size() - 1, "↓ 로 마지막 보급 단추까지")
	var last := acts[acts.size() - 1]
	check(list.shows(Rect2(last.position, last.size)), "마지막 단추가 보인다")
	var before := list.scroll
	for k in 40:
		await kit.press_key(KEY_DOWN)
	check(list.scroll > before and list.scroll == list.max_scroll(), "보급 단추 뒤 ↓ → 읽기만 하는 소지품까지 내린다")
	check_eq(it.cursor, acts.size() - 1, "커서는 마지막 단추 그대로")
	var ups := 0
	while it.cursor == acts.size() - 1 and ups < 40:
		await kit.press_key(KEY_UP)
		ups += 1
	check(ups > 1, "↑ 는 먼저 목록을 올린다(%d번)" % ups)
	check_eq(it.cursor, acts.size() - 2, "커서 단추가 다시 보인 뒤 ↑ → 앞 단추")
	var cur := acts[it.cursor]
	check(list.shows(Rect2(cur.position, cur.size)), "커서 단추가 보인다")


func test_items_keyboard_scrolls_without_debug() -> void:
	var pm := await _full_bag_items_tab(false)
	var it := pm.items_tab
	check(it.actionable().is_empty(), "일반 실행: 누를 단추 없음")
	await kit.press_key(KEY_DOWN)
	check(it.list.scroll > 0.0, "↓ → 내린다")
	await kit.press_key(KEY_UP)
	check_eq(it.list.scroll, 0.0, "↑ → 올린다")


func test_items_click_moves_cursor_so_enter_repeats_that_button() -> void:
	var s := await _open("debug=1")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	var pm := s.party_menu
	var it := pm.items_tab
	await kit.tap(kit.center_of(it.supply_button))
	check(it.supply_open, "준비: 보급 줄 열림")
	var first: String = s.state.defs.battle.equipment_ids[0]
	var b := it.plus_buttons[0]
	await kit.tap(kit.center_of(b))
	check_eq(int(s.state.gear_bag.get(first, 0)), 1, "첫 「+1」 누르기 → 가방 1")
	check_eq(it.cursor, it.actionable().find(b), "커서가 누른 단추로")
	check(b.selected, "누른 단추에 커서 테두리")
	await kit.press_key(KEY_ENTER)
	check_eq(int(s.state.gear_bag.get(first, 0)), 2, "Enter → 같은 「+1」 한 번 더")
	check(it.supply_open, "보급 줄은 열린 채")
	var e := it.exp_buttons[KNIGHT]
	it.list.ensure_visible(e.position.y, e.position.y + e.size.y)
	await kit.frames(1)
	var m := s.state.party.members[KNIGHT]
	await kit.tap(kit.center_of(e))
	check_eq(m.exp, 100, "「경험치 +100」 누르기")
	await kit.press_key(KEY_ENTER)
	check_eq(m.exp, 200, "Enter → 「경험치 +100」 한 번 더")
	var nx := it.next_buttons[KNIGHT]
	await kit.tap(kit.center_of(nx))
	var lv := m.level
	check_eq(it.cursor, it.actionable().find(nx), "「다음 레벨까지」 누르기 → 커서도 그 단추")
	await kit.press_key(KEY_ENTER)
	check_eq(m.level, lv + 1, "Enter → 「다음 레벨까지」 한 번 더")
	check(it.supply_open, "보급 줄은 열린 채")


# ---- 키보드만으로 끝까지 (07 §10.4) ----

func test_keyboard_only_full_path() -> void:
	var s := await _open()
	_prep_duelist(s, {ION_SABER: 1})
	var pm := s.party_menu
	var st := pm.skill_tab
	var et := pm.equip_tab
	var m := s.state.party.members[DUELIST_A]
	var n0 := s.autosave_count
	await kit.press_key(KEY_P)
	check(pm.is_open(), "P 열기")
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_E)
	check_eq([pm.tab, pm.member, st.cursor_skill()], [1, DUELIST_A, HIGH_SLASH], "스킬 탭·듀얼리스트 A·커서는 트리 첫 항목")
	await kit.press_key(KEY_RIGHT)
	check_eq(st.cursor_skill(), CROSS_SWEEP, "→ 크로스 스윕")
	await kit.press_key(KEY_LEFT)
	check_eq(st.cursor_skill(), HIGH_SLASH, "← 하이 슬래시")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	check_eq(st.draft, {HIGH_SLASH: 2}, "Enter 두 번 → 초안 +2")
	await kit.press_key(KEY_BACKSPACE)
	check_eq(st.draft, {HIGH_SLASH: 1}, "Backspace → 초안 +1")
	var h0 := kit.hash_now()
	await kit.press_key(KEY_F)
	check_eq([pm.dialog_kind, pm.dialog_pick], ["commit", 0], "F → 확정 확인 창(「돌아가기」)")
	await kit.press_key(KEY_ENTER)
	check_eq([pm.dialog_kind, st.draft], ["", {HIGH_SLASH: 1}], "Enter → 창 닫힘·초안 +1")
	check_eq(kit.hash_now(), h0, "상태 해시 그대로")
	check_eq(s.autosave_count, n0, "자동 저장 0")
	await kit.press_key(KEY_F)
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.dialog_pick, 1, "→ 「확정」")
	await kit.press_key(KEY_ENTER)
	check_eq(m.skills[HIGH_SLASH], 2, "하이 슬래시 Lv2")
	check_eq(s.autosave_count, n0 + 1, "자동 저장 1회")
	var h1 := kit.hash_now()
	await kit.press_key(KEY_ENTER)
	check_eq(st.draft, {HIGH_SLASH: 1}, "Enter → 새 초안")
	await kit.press_key(KEY_R)
	check_eq(st.draft, {}, "R → 초안 없음")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.dialog_kind, pm.dialog_pick], ["discard", 0], "Esc → 버리기 확인 창")
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	check(not pm.is_open(), "→ Enter → 메뉴 닫힘")
	check_eq(kit.hash_now(), h1, "상태 해시가 확정 직후와 같다")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_E)
	check_eq([pm.tab, pm.member, et.cursor], [2, DUELIST_A, 0], "장비 탭·듀얼리스트 A·칸 0")
	await kit.press_key(KEY_ENTER)
	check(et.list_open, "Enter → 칸 0 목록")
	await kit.press_key(KEY_DOWN)
	check_eq(et.row_items[et.list_cursor], ION_SABER, "↓ → 이온 세이버 줄")
	await kit.press_key(KEY_ENTER)
	check_eq(m.equip[0], ION_SABER, "Enter → 장착")
	check_eq(s.autosave_count, n0 + 2, "자동 저장")
	check(not et.list_open and et.cursor == 0, "목록 닫힘·커서 칸 0")
	await kit.press_key(KEY_BACKSPACE)
	check_eq(m.equip[0], "", "Backspace → 빼기")
	check_eq(s.autosave_count, n0 + 3, "자동 저장")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "Esc 닫기")
	var at := s.state.party.at
	await kit.press_key(KEY_W)
	await kit.frames(5)
	check_eq(s.state.party.at, at + Vector2i(0, -1), "닫은 뒤 이동 키 한 번 = 정확히 한 걸음")


# ---- 메뉴 뒤로 새는 키 없음 (07 §9.4) ----

func test_keys_do_not_leak_behind_menu() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.open_map()
	s.map.tool = "color"
	s.map.paint_color = 3
	await kit.tap(kit.map_cell(Vector2i(1, 18)))
	check_eq(s.state.annotation.undo_depth(), 1, "준비: 지도 편집 하나(되돌리기 기록 1)")
	var map_open := s._map_open
	var ann := _annotation_json(s)
	var h := kit.hash_now()
	var at := s.state.party.at
	var facing := s.state.party.facing
	var n := s.autosave_count
	await kit.press_key(KEY_P)
	check(pm.is_open(), "준비: 메뉴")
	for k in [KEY_M, KEY_R, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
		await kit.press_key(k)
	await kit.press_key(KEY_Z, true)
	check_eq([pm.tab, pm.member], [0, 0], "메뉴 안에서도 아무 일 없음")
	await kit.press_key(KEY_E)
	check_eq(pm.member, 1, "E → 다음 대원만")
	await kit.press_key(KEY_Q)
	check_eq(pm.member, 0, "Q → 앞 대원만")
	await kit.press_key(KEY_E, true)
	await kit.press_key(KEY_2, true)
	check_eq([pm.tab, pm.member], [0, 0], "Ctrl 이 눌린 키는 아무 일 없음")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_E
	echo.keycode = KEY_E
	echo.pressed = true
	echo.echo = true
	kit._send(echo)
	kit.key(KEY_E, false)
	await kit.frames(3)
	check_eq(pm.member, 0, "키 반복은 아무 일 없음")
	check(pm.is_open(), "메뉴는 열린 채")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "Esc → 메뉴만 닫힘")
	check_eq(s.modal.kind, "", "주 메뉴는 열리지 않는다")
	check_eq(s._map_open, map_open, "지도 패널 열림 상태 그대로(M 이 새지 않음)")
	check_eq(_annotation_json(s), ann, "지도 데이터 그대로(Ctrl+Z 가 새지 않음)")
	check(s.state.annotation.can_undo() and s.state.annotation.undo_depth() == 1, "되돌리기 기록 그대로")
	check_eq([s.state.party.at, s.state.party.facing], [at, facing], "이동·회전 없음")
	check_eq(kit.hash_now(), h, "상태 해시 그대로(휴식·조사 없음)")
	check_eq(s.autosave_count, n, "자동 저장 없음")


# ---- 포인터 소유권·문맥 취소 (07 §9.4) ----

func test_drag_from_list_released_on_tab_changes_nothing() -> void:
	var s := await _open("debug=1")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	var pm := s.party_menu
	var it := pm.items_tab
	await kit.tap(kit.center_of(it.supply_button))
	check(it.supply_open and it.list.max_scroll() > 0.0, "준비: 넘치는 보급 목록")
	var bag := s.state.gear_bag.duplicate()
	var n := s.autosave_count
	var from := kit.center_of(it.plus_buttons[0])
	var to := kit.center_of(pm.tab_buttons[0])
	kit.touch(0, from, true)
	await kit.frames(1)
	kit.drag(0, from, to)
	await kit.frames(1)
	kit.touch(0, to, false)
	await kit.frames(3)
	check_eq(pm.tab, 3, "목록에서 끌다가 탭 위에서 떼도 탭 그대로")
	check_eq(s.state.gear_bag, bag, "끌기는 「+1」 누르기가 아니다")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	check(it.list.scroll > 0.0, "끌기가 목록을 내렸다 (%s)" % it.list.scroll)
	var before := it.list.scroll
	var w := InputEventMouseButton.new()
	w.position = kit.center_of(it.list)
	w.global_position = w.position
	w.button_index = MOUSE_BUTTON_WHEEL_DOWN
	w.pressed = true
	kit._send(w)
	await kit.frames(2)
	check(it.list.scroll > before or it.list.scroll == it.list.max_scroll(), "휠로도 내린다")


func test_emulated_mouse_is_not_a_second_press_and_hold_counts_once() -> void:
	var s := await _open()
	_prep_duelist(s)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	var p := kit.center_of(st.plus_button)
	await kit.tap(p)
	check_eq(st.draft, {HIGH_SLASH: 1}, "터치 한 번 = 한 번(흉내 낸 마우스와 두 번 처리하지 않음)")
	for pressed in [true, false]:
		var m := InputEventMouseButton.new()
		m.device = InputEvent.DEVICE_ID_EMULATION
		m.position = p
		m.global_position = p
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = pressed
		kit._send(m)
		await kit.frames(2)
	check_eq(st.draft, {HIGH_SLASH: 1}, "흉내 낸 마우스 누르기는 버린다")
	await kit.click(p)
	check_eq(st.draft, {HIGH_SLASH: 2}, "실제 마우스는 받는다")
	await kit.press_key(KEY_R)
	kit.touch(0, p, true)
	await _wait_sec(0.4)
	await kit.frames(20)
	kit.touch(0, p, false)
	await kit.frames(3)
	check_eq(st.draft, {HIGH_SLASH: 1}, "「+」를 길게 눌러도 한 번")


func test_context_change_cancels_pressed_pointer() -> void:
	var s := await _open()
	_prep_duelist(s)
	GrowthRules.supply(s.state, ION_SABER, 1)
	var pm := await _skill_tab_on_duelist(s)
	var st := pm.skill_tab
	# ① 「+」를 누른 채 F → 확정 창 → 뗌
	await kit.tap(kit.center_of(st.plus_button))
	var plus := kit.center_of(st.plus_button)
	kit.touch(0, plus, true)
	await kit.frames(2)
	await kit.press_key(KEY_F)
	check_eq(pm.dialog_kind, "commit", "준비: 누른 채 확정 창")
	kit.touch(0, plus, false)
	await kit.frames(3)
	check_eq(st.draft, {HIGH_SLASH: 1}, "취소된 「+」는 뗄 때 아무 일도 하지 않는다")
	check_eq([pm.dialog_kind, pm.dialog_pick], ["commit", 0], "창 단추도 눌리지 않았다")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_R)
	check_eq([pm.dialog_kind, st.draft], ["", {}], "준비: 창 닫고 초안 없음")
	# ② 대원 칸을 누른 채 Q → 뗌
	var cell := kit.center_of(pm.cells[3])
	kit.touch(0, cell, true)
	await kit.frames(2)
	await kit.press_key(KEY_Q)
	check_eq(pm.member, 0, "Q → 앞 대원")
	kit.touch(0, cell, false)
	await kit.frames(3)
	check_eq(pm.member, 0, "누르고 있던 칸의 대원은 골라지지 않는다")
	# ③ 장비 목록 줄을 누른 채 Esc → 뗌
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_E)
	var et := pm.equip_tab
	await kit.tap(kit.center_of(et.slot_rows[0]))
	check_eq(et.row_items, ["", ION_SABER], "준비: 듀얼리스트 A 칸 0 목록")
	var row := kit.center_of(et.rows[1])
	var n := s.autosave_count
	kit.touch(0, row, true)
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)
	check(not et.list_open and pm.is_open(), "Esc → 목록만 닫힘")
	kit.touch(0, row, false)
	await kit.frames(3)
	check_eq(s.state.party.members[DUELIST_A].equip[0], TWIN_EDGE, "장착 없음")
	check_eq(s.autosave_count, n, "자동 저장 없음")
	# 메뉴를 닫을 때도: 「닫기」를 누른 채 Esc 로 닫고 뗀 뒤 다시 열면 아무것도 눌려 있지 않다
	var close := kit.center_of(pm.close_button)
	kit.touch(0, close, true)
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "Esc 로 닫힘")
	kit.touch(0, close, false)
	await kit.frames(3)
	check(not pm.close_button.held, "닫을 때 눌림을 버렸다")


# ---- 다시 열기 (07 §10.4) ----

func test_new_screen_from_same_save_has_menu_closed_and_same_growth() -> void:
	var s := await _open()
	_prep_duelist(s, {ION_SABER: 1})
	var pm := await _skill_tab_on_duelist(s)
	await kit.tap(kit.center_of(pm.skill_tab.plus_button))
	await kit.press_key(KEY_F)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_3)
	await kit.tap(kit.center_of(pm.equip_tab.slot_rows[0]))
	await kit.tap(kit.center_of(pm.equip_tab.rows[1]))
	check_eq(s.state.party.members[DUELIST_A].equip[0], ION_SABER, "준비: 장착")
	var want := s.state.party.members.map(func(m: PartyState.Member) -> Array: return [m.level, m.exp, m.skills.duplicate(), m.equip.duplicate()])
	var bag := s.state.gear_bag.duplicate()
	var s2 := await kit.reopen()
	s2.native_debug = false
	check(not s2.party_menu.is_open(), "새 화면에서 메뉴는 닫혀 있다")
	var got := s2.state.party.members.map(func(m: PartyState.Member) -> Array: return [m.level, m.exp, m.skills.duplicate(), m.equip.duplicate()])
	check_eq(got, want, "대원 레벨·경험치·스킬·장비가 같다")
	check_eq(s2.state.gear_bag, bag, "가방이 같다")


# ---- 배치 (07 §9.2) ----

## 지금 누를 수 있는 것: 64px 이상, 서로 겹치지 않고 화면 안.
func _check_layout(pm: PartyMenu, sz: Vector2, label: String) -> void:
	var bs := pm.visible_buttons()
	check(not bs.is_empty(), label + ": 누를 것이 있다")
	var rects: Array[Rect2] = []
	for b in bs:
		check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [label, b.name, str(b.size)])
		var r := pm.clipped_rect(b)
		check(Rect2(Vector2.ZERO, sz).encloses(r), "%s: %s %s 가 화면 안" % [label, b.name, str(r)])
		rects.append(r)
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			check(not rects[i].intersects(rects[j]), "%s: %s 와 %s 가 겹친다 (%s, %s)" % [label, bs[i].name, bs[j].name, str(rects[i]), str(rects[j])])


func test_layout_no_overlap_and_min_size_per_tab() -> void:
	var bag := {ION_SABER: 2, "equip.mesh_armor": 1, "equip.visor": 1, "equip.servo_gauntlet": 1, "equip.mag_boots": 1,
		"equip.thermal_ring": 1, "equip.antitox_chip": 1, "equip.focus_staff": 1, "equip.tactical_baton": 1, "equip.aegis_plate": 1}
	for sz in [BASE, WIDE]:
		var pm := await _host_menu(Fx.defs(), sz, true, bag)
		var tag := "%dx%d" % [sz.x, sz.y]
		_check_layout(pm, sz, tag + " 상태")
		await _step(pm, "tab", 1)
		GrowthRules.grant_exp(pm.state, DUELIST_A, pm.state.defs.battle.growth.cum(3))  # 초안을 만들 SP
		await _step(pm, "member", DUELIST_A)
		_check_layout(pm, sz, tag + " 스킬")
		var st := pm.skill_tab
		check(st.tree_rect().end.y <= PartySkillTab.ROW_Y and st.desc_rect().end.y <= PartySkillTab.ROW_Y, tag + ": 트리·설명 칸은 조작 줄 위")
		check_eq(st.desc_rect().end.x, sz.x - 8, tag + ": 설명 칸은 오른쪽에 붙는다")
		await _step(pm, "plus")
		await _step(pm, "commit")
		check_eq(pm.dialog_kind, "commit", tag + " 준비: 확정 창")
		check_eq(pm.dialog_rect().size, Vector2(560, 240), tag + ": 확인 창 560×240")
		_check_layout(pm, sz, tag + " 확인 창")
		await _step(pm, "dialog_back")
		await _step(pm, "revert")
		await _step(pm, "tab", 2)
		_check_layout(pm, sz, tag + " 장비")
		await _step(pm, "slot", 0)
		check(pm.equip_tab.list_open, tag + " 준비: 목록")
		_check_layout(pm, sz, tag + " 장비 목록")
		await _step(pm, "back")
		await _step(pm, "tab", 3)
		_check_layout(pm, sz, tag + " 소지품")
		await _step(pm, "supply_toggle")
		_check_layout(pm, sz, tag + " 임시 보급")
		await _step(pm, "member", 4)
		check_eq(pm.member, 4, tag + ": 대원 칸 5 개가 화면 안")
		check(pm.cells[4].get_global_rect().end.y <= sz.y, tag + ": 마지막 대원 칸이 화면 안")

