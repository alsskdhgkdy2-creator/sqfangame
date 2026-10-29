## 정보상 바·관리국 화면(M3 A8b, 설계 §6·§8 A8b U1~U7): 광장 줄 → 뿌리·받는 목록(표)·말 상자·받기/포기 확인·보고 목록·보고 결과.
## 실제 흐름은 누르기 → 자동 저장 = 화면 → 새 화면으로 다시 읽기까지 본다(교훈 1). 그린 글은 그리기 기록(SheetParts.record)에서 읽는다(교훈 2).
## 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다). 시험마다 이름 붙은 변이(M-U…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const HM := preload("res://tests/held_matrix.gd")
const SIZES := [Vector2(1280, 720), Vector2(1728, 720), Vector2(1280, 960)]
const FINGER := 3
const PUB_ROW := 2
const COUNCIL_ROW := 4
const M1 := "mission.permit_b2f"
const M2 := "mission.boss_seal"
const SOUP := "quest.moss_soup"
const RAM := "quest.ether_ram"
const MOTH := "quest.moth_sweep"
const MOSS := "item.neon_moss"

var kit: Kit
var host: Control
var texts: TextDb
var saves := 0
var _defs: GameDefs
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


# ---- 준비 ----

func _kit() -> void:
	if kit == null:
		kit = Kit.new(tree)
	if texts == null:
		texts = TextDb.load_path("res://data/text/ko.json")


func _window(px: Vector2) -> Vector2:
	_kit()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 게임 묶음 마을 새 게임 상태(시드 1, 기본 다섯).
func _state() -> ExplorationState:
	_kit()
	if _defs == null:
		_defs = Fx.arbor()
	return ExplorationRules.new_game(_defs, 1, "floor", true)


## 탐색 화면 없이 의뢰 화면만(창 크기 px). 동작 갈고리는 규칙을 바로 부르고 받아들인 것을 센다(탐색 화면의 quest_action 과 같은 길).
func _fresh(s: ExplorationState, giver: String, px: Vector2 = SIZES[0]) -> QuestScreen:
	timeout_sec = 150.0
	await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	saves = 0
	host = Control.new()
	host.name = "QuestHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var q := QuestScreen.new()
	host.add_child(q)
	q.build(texts)
	q.action_hook = func(kind: String, id: String, who: String) -> Array[Dictionary]:
		var ev: Array[Dictionary]
		match kind:
			"accept":
				ev = QuestRules.accept(q.state, id, who)
			"abandon":
				ev = QuestRules.abandon(q.state, id, who)
			"report":
				ev = QuestRules.report(q.state, id, who)
		if ev[0]["type"] != "rejected":
			saves += 1
		return ev
	q.open(s, giver)
	await kit.frames(2)
	return q


func _step(q: QuestScreen, kind: String, arg: Variant = null) -> bool:
	var ok := q.handle(kind, arg)
	await kit.frames(1)
	return ok


## 화면이 가진 것 전부(입력 하나가 바꿀 수 있는 것).
func _sig(q: QuestScreen) -> Array:
	return [q.is_open(), q.page, q.root_cursor, q.list_inv.cursor, q.list_ids.duplicate(), q.dialog.mode, q.dialog.pick, q.asking, q.asking_id,
		q.notice, q.result.duplicate(true), SaveCodec.state_hash(q.state), saves, q.accepted_inputs]


static func _pad_button(q: QuestScreen, k: String) -> TouchButton:
	return q.dir_pad.button(k) if k in ["up", "down", "left", "right"] else q.key_pad.button(k)


static func _texts_of(c: CanvasItem) -> Array:
	return SheetParts.record(c).filter(func(e: Dictionary) -> bool: return e["kind"] == "text").map(func(e: Dictionary) -> String: return str(e["text"]))


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


## 게임 묶음 마을(PC, 디버그 도구 없음).
func _town(query: String = "") -> DungeonScreen:
	timeout_sec = 180.0
	_kit()
	return await kit.open_town("native", 7, query, func(sc: DungeonScreen) -> void:
		sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		sc.native_debug = false)


func _reload() -> DungeonScreen:
	var s: DungeonScreen = await kit.reopen(func(sc: DungeonScreen) -> void:
		sc.start_mode = "town"
		sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		sc.native_debug = false)
	await kit.frames(2)
	return s


func _auto(s: DungeonScreen) -> SaveCodec.LoadResult:
	return SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)


## 표(오른쪽 글·흐림)를 만든 줄에서 읽는다: [의뢰 이름, 오른쪽, 흐림].
func _rows(q: QuestScreen) -> Array:
	var out := []
	for k in q.list_inv.used:
		var r := q.list_inv.rows[k] as ListButton
		out.append([r.text, r.right, r.dimmed])
	return out


func _name(id: String) -> String:
	if _defs == null:
		_defs = Fx.arbor()
	return texts.t(_defs.quests.get_def(id).name_key)


func _item(s: ExplorationState, id: String) -> String:
	return PartyNames.item_name(s, texts, id)


# ---- U7 광장 입구 ----

## U7 (M-U7 시험 묶음에서도 정보상 바가 열림): 게임 묶음 광장의 「정보상 바」·「관리국」 줄은 흐리지 않고, 누르면 그 시설 뿌리(바탕 그림도 그 시설).
## 「나간다」·Esc 는 광장(커서는 그 시설 줄). 키 5 는 관리국. 시험 묶음은 둘 다 흐리고 「아직 문을 열지 않았다」만.
func test_plaza_rows_open_on_the_game_set_only() -> void:
	var s := await _town()
	var t := s.town_screen
	check_eq([t.plaza_dim("pub"), t.plaza_dim("council"), t.debug_info(func(_a, _b): return [])["dim"]],
		[false, false, [false, false, false, false, false, false]], "게임 묶음: 정보상 바·관리국 줄이 흐리지 않다")
	await kit.tap(kit.center_of(t.plaza_list.rows[PUB_ROW]))
	await kit.frames(1)
	var q := s.quest_screen
	check(q.is_open() and q.giver == "pub" and q.page == "root", "정보상 바 줄 → 정보상 바 뿌리")
	check_eq([t.covered, s.town_backdrop.place, q.place_text()], [true, "pub", "정보상 바"], "마을 화면은 덮였고 바탕·장소는 정보상 바")
	check_eq([q.root_list.rows[0].text, q.root_list.rows[1].text, q.root_list.rows[2].text, q.root_list.rows[3].text],
		["1  의뢰를 받는다", "2  의뢰를 보고한다", "3  대화한다", "4  나간다"], "정보상 바 뿌리 줄")
	await kit.press_key(KEY_3)
	check_eq([q.page, q.notice], ["root", "주인이 자리를 비웠다"], "「대화한다」는 이유만")
	await kit.press_key(KEY_ESCAPE)
	check(not q.is_open() and t.page == "plaza" and t.plaza_cursor == PUB_ROW and not t.covered, "Esc → 광장, 커서 「정보상 바」")
	await kit.press_key(KEY_5)
	check(q.is_open() and q.giver == "council", "키 5 → 관리국")
	check_eq([q.root_list.rows[0].text, q.root_list.rows[1].text, s.town_backdrop.place], ["1  임무를 받는다", "2  임무를 보고한다", "council"],
		"관리국 뿌리 줄·바탕")
	await kit.press_key(KEY_4)
	check(not q.is_open() and t.plaza_cursor == COUNCIL_ROW, "「나간다」 → 광장, 커서 「관리국」")
	kit.dispose()
	kit = Kit.new(tree)  # 새 임시 저장 폴더(게임 묶음 자동 저장을 읽지 않는다)
	var ts: DungeonScreen = await kit.open_town("native", 7, "", func(sc: DungeonScreen) -> void: sc.native_debug = false)
	await kit.frames(2)
	var tt := ts.town_screen
	check_eq([tt.plaza_dim("pub"), tt.plaza_dim("council"), ts.state.defs.quests.is_empty()], [true, true, true], "시험 묶음: 의뢰가 없어 둘 다 흐림")
	await kit.tap(kit.center_of(tt.plaza_list.rows[PUB_ROW]))
	await kit.frames(1)
	check_eq([ts.quest_screen.is_open(), tt.page, tt.notice], [false, "plaza", "아직 문을 열지 않았다"], "시험 묶음 정보상 바 → 이유만")


# ---- U1·U2 받는 목록의 표 ----

## U1 (M-U1 잠긴 의뢰도 목록에 보임), U2 (M-U2 다시 받는 반복 의뢰에 NEW): 상태마다 만든 줄의 표와 흐림.
func test_accept_list_marks_for_each_state() -> void:
	var s := _state()
	var q := await _fresh(s, "pub")
	await _step(q, "row", 0)
	check_eq(q.page, "accept", "받는 쪽")
	check_eq(_rows(q), [[_name(SOUP), "NEW", false]], "새 게임: 이끼 수프만(잠긴 둘은 보이지 않는다), NEW")
	await _step(q, "confirm")
	await _step(q, "dialog", ["confirm", null])
	check_eq([_rows(q), saves], [[[_name(SOUP), "수락 중", false]], 1], "받기: 수락 중, 저장 하나")
	BagRules.add(s, MOSS, 3)
	q.refresh_view()
	check_eq(_rows(q), [[_name(SOUP), "달성", false]], "이끼 셋: 달성")
	check_eq(QuestRules.report(s, SOUP, "pub").back()["type"], "quest_reported", "준비: 보고")
	q.refresh_view()
	check_eq(_rows(q), [[_name(SOUP), "1일 뒤", true], [_name(RAM), "NEW", false]], "보고한 날: 1일 뒤(흐림), 에테르 숫양이 열린다")
	await _step(q, "confirm")
	check_eq([q.notice, q.dialog.is_open()], ["1일 뒤에 다시 받을 수 있다", false], "식는 줄: 이유만")
	s.day = 2
	q.refresh_view()
	check_eq(_rows(q)[0], [_name(SOUP), "", false], "다음 날: 다시 받을 수 있고 NEW 는 아니다")
	s.enter_floor(s.defs.floors["b2f"])
	s.enter_floor(s.defs.first_floor())
	s.location = ExplorationState.TOWN
	q.refresh_view()
	check_eq(_rows(q).map(func(r: Array) -> String: return r[0]), [_name(SOUP), _name(RAM), _name(MOTH)], "B2F 를 다녀오면 나방 소탕(자료 차례)")
	var c := await _fresh(_state(), "council")
	await _step(c, "row", 0)
	check_eq(_rows(c), [[_name(M1), "NEW", false]], "관리국 새 게임: 첫 임무만")
	c.state.quests.entries[M1] = QuestState.Entry.new()
	c.state.quests.entry(M1).status = QuestState.REPORTED
	c.state.quests.entry(M1).reports = 1
	c.state.quests.entry(M1).day = 1
	c.state.flags["permit.b2f"] = true
	c.refresh_view()
	check_eq(_rows(c), [[_name(M1), "완료", true]], "첫 임무 보고: 완료(흐림), 둘째는 B3F 전 잠김")
	await _step(c, "confirm")
	check_eq(c.notice, "이미 보고했다", "완료 줄: 이유만")


# ---- 말 상자 ----

## 말 상자(그리기 기록): 제목 = 의뢰인, 줄 = 설명 · 「목표: … 진행/가진 수 n/N」 · 「보수: …」(반복이면 「· 반복: 하룻밤 뒤」). 목록이 비면 이유.
func test_speech_box_lines() -> void:
	var s := _state()
	var q := await _fresh(s, "pub")
	await _step(q, "row", 0)
	BagRules.add(s, MOSS, 1)
	q.refresh_view()
	await kit.frames(1)
	var t := _texts_of(q.box)
	check(t.has("바 주방장"), "제목 = 의뢰인 %s" % str(t))
	var moss := _item(s, MOSS)
	var medica := _item(s, "use.medica")
	check(t.has("목표: %s 3개 건네기  가진 수 1/3" % moss), "목표와 가진 수 %s" % str(t))
	check(t.has("보수: 60엔 · %s 2 · 경험치 20 · 반복: 하룻밤 뒤" % medica), "보수와 반복 %s" % str(t))
	var desc := "".join(t.filter(func(x: String) -> bool: return x != "바 주방장" and not x.begins_with("목표") and not x.begins_with("보수")))
	check_eq(desc.replace(" ", ""), texts.t("quest.moss_soup.desc").replace(" ", ""), "설명은 남는 줄에 접혀 모두 들어간다")
	var c := await _fresh(_state(), "council")
	await _step(c, "row", 0)
	await kit.frames(1)
	var ct := _texts_of(c.box)
	check(ct.has("목표: B1F 아래로 내려가는 계단에 가기  진행 0/1") and ct.has("보수: 100엔 · 경험치 30 · B2F 탐사 허가"), "임무: 도착 목표와 허가 보수 %s" % str(ct))
	await _step(c, "back")
	await _step(c, "row", 1)
	await kit.frames(1)
	check(_texts_of(c.box).has("보고할 임무가 없다"), "받은 임무가 없으면 보고 쪽 상자는 이유")


# ---- U3 확인 창 ----

## U3 (M-U3 포기 확인이 「예」 먼저): 받기 확인은 「예」 먼저, 포기 확인은 「아니오」 먼저(진행이 사라진다). 받은 임무를 고르면 「임무는 포기할 수 없다」.
func test_accept_yes_first_abandon_no_first_and_missions_stay() -> void:
	var s := _state()
	var q := await _fresh(s, "pub")
	await _step(q, "row", 0)
	await _step(q, "confirm")
	check_eq([q.dialog.mode, q.dialog.pick, q.dialog.message, q.asking], ["confirm", ShopDialog.YES, "이 의뢰를 받을까?", "accept"], "받기 확인: 예 먼저")
	await _step(q, "dialog", ["confirm", null])
	check_eq([s.quests.is_accepted(SOUP), q.notice, saves], [true, "「이끼 수프 재료」 의뢰를 받았다", 1], "받았다(안내·저장 하나)")
	await _step(q, "confirm")
	check_eq([q.dialog.pick, q.dialog.message, q.asking], [ShopDialog.NO, "이 의뢰를 포기할까? 진행은 사라진다", "abandon"], "포기 확인: 아니오 먼저")
	await _step(q, "dialog", ["confirm", null])
	check_eq([s.quests.is_accepted(SOUP), saves], [true, 1], "처음 커서(아니오)로 답하면 그대로")
	await _step(q, "confirm")
	await _step(q, "dialog", ["pick", -1])
	await _step(q, "dialog", ["confirm", null])
	check_eq([s.quests.entry(SOUP), q.notice, saves, _rows(q)[0][1]], [null, "「이끼 수프 재료」 의뢰를 포기했다", 2, "NEW"],
		"「예」: 포기(기록이 지워져 다시 NEW), 저장 하나")
	var c := await _fresh(_state(), "council")
	await _step(c, "row", 0)
	await _step(c, "confirm")
	check_eq(c.dialog.message, "이 임무를 받을까?", "임무 받기 확인")
	await _step(c, "dialog", ["confirm", null])
	await _step(c, "confirm")
	check_eq([c.dialog.is_open(), c.notice, c.state.quests.is_accepted(M1)], [false, "임무는 포기할 수 없다", true], "받은 임무: 이유만, 그대로")


# ---- 보고 ----

## 보고 쪽: 받은 의뢰만, 못 이룬 줄은 흐림 「진행 n/N」이고 고르면 「아직 목표를 이루지 못했다」. 가방이 가득하면 보수를 받지 않는다(바뀌지 않음).
func test_report_list_dim_rows_and_bag_full() -> void:
	var s := _state()
	s.enter_floor(s.defs.floors["b2f"])
	s.enter_floor(s.defs.first_floor())
	s.location = ExplorationState.TOWN
	QuestRules.accept(s, SOUP, "pub")
	QuestRules.accept(s, MOTH, "pub")
	var q := await _fresh(s, "pub")
	await _step(q, "row", 1)
	check_eq(_rows(q), [[_name(SOUP), "진행 0/3", true], [_name(MOTH), "진행 0/4", true]], "못 이룬 의뢰: 흐림 진행 n/N")
	await _step(q, "confirm")
	check_eq([q.notice, q.dialog.is_open()], ["아직 목표를 이루지 못했다", false], "못 이룬 줄: 이유만")
	BagRules.add(s, MOSS, 3)
	# 가방: 소모품으로 빈 칸을 모두 채우고 메디카는 종류 상한까지(건넨 이끼 셋 자리에 메디카 둘이 들어가지 않게).
	s.consumables["use.medica"] = BagRules.kind_cap("use.medica")
	var fill := ["use.theriaca_a", "use.amrita", "use.nectar"]
	for id in fill:
		if s.defs.battle.consumables.has(id):
			var room := BagRules.SLOTS - BagRules.used(s)
			s.consumables[id] = mini(room, BagRules.kind_cap(id))
	q.refresh_view()
	check_eq(_rows(q)[0], [_name(SOUP), "달성", false], "이끼 셋: 달성")
	var before := SaveCodec.state_hash(s)
	await _step(q, "confirm")
	check_eq(q.dialog.message, "이 의뢰를 보고할까?\n%s 3개를 건넨다" % _item(s, MOSS), "보고 확인: 건넬 물건")
	await _step(q, "dialog", ["confirm", null])
	check_eq([q.notice, SaveCodec.state_hash(s), saves, q.result], ["가방이 가득해서 보수를 받을 수 없다", before, 0, {}], "가득한 가방: 이유, 바뀌지 않음")


## U4 (M-U4 결과가 레벨 업을 뺌): 관리국 실제 흐름 — 광장 줄 → 「임무를 보고한다」 → 줄 → 「예」. 결과 줄(돈·허가·경험치·레벨 업 한 줄)과
## 띠 「보고했다」, 자동 저장 하나 = 화면. 다음 입력에 결과가 사라진다. 다시 열면 받는 쪽 첫 임무는 「완료」(흐림).
func test_report_result_saves_and_reloads() -> void:
	var s := await _town()
	QuestRules.accept(s.state, M1, "council")
	s.state.quests.entry(M1).progress = 1
	s._autosave()
	await kit.tap(kit.center_of(s.town_screen.plaza_list.rows[COUNCIL_ROW]))
	await kit.frames(1)
	var q := s.quest_screen
	await kit.press_key(KEY_2)
	check_eq([q.page, _rows(q)], ["report", [[_name(M1), "달성", false]]], "보고 쪽: 첫 임무 달성")
	await kit.press_key(KEY_ENTER)
	check_eq([q.dialog.message, q.dialog.pick], ["이 임무를 보고할까?", ShopDialog.YES], "보고 확인: 예 먼저")
	var n := s.autosave_count
	var money := s.state.money
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	var names := s.state.party.members.map(func(m: PartyState.Member) -> String: return "%s 2" % PartyNames.display_name(texts, m))
	var want := ["100엔", "받은 허가: B2F 탐사 허가", "경험치 30", "레벨 업: " + ", ".join(names)]
	check_eq([q.result.get("title"), q.result.get("lines")], ["보수를 받았다", want], "결과 줄: 돈·허가·경험치·레벨 업(다섯이라 한 줄)")
	var t := _texts_of(q.box)
	check(t.has("보수를 받았다") and t.has(want[3]), "말 상자가 결과를 그린다 %s" % str(t))
	check_eq([q.notice, s.autosave_count, s.state.money, s.state.flags, s.state.party.members[0].level], ["보고했다", n + 1, money + 100,
		{"permit.b2f": true}, 2], "띠 「보고했다」, 자동 저장 하나, 돈·허가·레벨")
	var a := _auto(s)
	check(a.ok() and SaveCodec.state_hash(a.state) == kit.hash_now(), "자동 저장 = 화면 %s" % a.error)
	check_eq(_rows(q), [], "보고 쪽: 받은 임무가 없다")
	await kit.press_key(KEY_ESCAPE)
	check(q.result.is_empty() and q.page == "root", "다음 입력(취소)에 결과가 사라진다")
	await kit.press_key(KEY_2)
	check(_texts_of(q.box).has("보고할 임무가 없다"), "다시 보고 쪽: 결과 대신 보통 상자")
	s = await _reload()
	await kit.tap(kit.center_of(s.town_screen.plaza_list.rows[COUNCIL_ROW]))
	await kit.frames(1)
	q = s.quest_screen
	await kit.press_key(KEY_1)
	check_eq(_rows(q), [[_name(M1), "완료", true]], "다시 열기: 첫 임무 완료(흐림)")


## 결과 줄 준비: 첫 임무를 보고할 수 있게 하고, 대원마다 how[i] = "down"(쓰러짐) · "cap"(상한까지 경험치) · "near"(상한 1 앞) · ""(Lv1 그대로).
## 경험치는 실제 GrowthRules.gain_exp 로 준다(저장 검사를 지나는 상태).
func _result_party(s: ExplorationState, how: Array) -> void:
	QuestRules.accept(s, M1, "council")
	s.quests.entry(M1).progress = 1
	var top := s.defs.battle.growth.cum(s.defs.battle.growth.level_cap)
	var sink: Array[Dictionary] = []
	for i in how.size():
		match str(how[i]):
			"down":
				s.party.members[i].hp = 0
			"cap":
				GrowthRules.gain_exp(s, i, top, sink)
			"near":
				GrowthRules.gain_exp(s, i, top - 1, sink)


## 보고하고 결과 줄과 대원별 실제로 받은 경험치(대원 차례)를 돌려준다.
func _report_lines(s: ExplorationState) -> Array:
	var q := await _fresh(s, "council")
	var ev := QuestRules.report(s, M1, "council")
	return [q.result_lines(ev), (ev.back()["members"] as Array).map(func(r: Dictionary) -> int: return int(r["gained"]))]


## 결과 줄 넷(M-U4 결과가 레벨 업을 뺌; M-R2 합친 줄이 까닭을 뺌): 대원 0 쓰러짐, 1 상한, 2~4 레벨 업. 레벨 업은 한 줄, 못 받은 대원은 까닭별로
## 한 줄(이름마다 까닭이 남는다), 그래도 넘쳐 머리의 돈·허가가 한 줄로 합쳐진다.
func test_result_lines_fit_four() -> void:
	var s := _state()
	_result_party(s, ["down", "cap"])
	var nm := func(i: int) -> String: return PartyNames.display_name(texts, s.party.members[i])
	var got: Array = await _report_lines(s)
	check_eq(got[0], ["100엔 · 받은 허가: B2F 탐사 허가", "경험치 30", "레벨 업: %s 2, %s 2, %s 2" % [nm.call(2), nm.call(3), nm.call(4)],
		"경험치를 받지 못함: 쓰러짐 %s · 상한 %s" % [nm.call(0), nm.call(1)]], "넷: 레벨 업 한 줄, 못 받은 대원은 까닭과 함께 한 줄")
	s = _state()
	_result_party(s, ["down", "cap", "cap", "down", "cap"])
	got = await _report_lines(s)
	check_eq(got[0], ["100엔", "받은 허가: B2F 탐사 허가", "경험치 30",
		"경험치를 받지 못함: 쓰러짐 %s, %s · 상한 %s, %s, %s" % [nm.call(0), nm.call(3), nm.call(1), nm.call(2), nm.call(4)]],
		"다섯 모두 못 받음: 까닭별로 묶은 한 줄")
	s = _state()
	_result_party(s, ["down"])
	got = await _report_lines(s)
	check_eq(got[0], ["100엔 · 받은 허가: B2F 탐사 허가", "경험치 30", "레벨 업: %s 2, %s 2, %s 2, %s 2" % [nm.call(1), nm.call(2), nm.call(3), nm.call(4)],
		texts.t("quest.result.down", {"name": nm.call(0)})], "못 받은 대원이 하나면 원래 문장 그대로(머리를 합쳐 자리를 낸다)")


## M-R1 (경험치 줄이 첫 대원이 실제로 받은 값): 상한 1 앞 대원 하나(홀로나이트)와 보통 대원 넷(실제로 받은 경험치 1 과 30 넷). 경험치 줄은 의뢰
## 보수 30 이고 상한에 걸린 대원은 같은 줄에 「상한 이름 1」. 같은 대원들의 차례를 바꿔(그 대원이 맨 앞 / 넷째) 경험치 줄이 같은지 본다.
func test_result_exp_is_the_quest_reward_near_the_cap() -> void:
	var lines_by_order := []
	for at in [0, 3]:
		var s := _state()
		_result_party(s, ["near"])
		var who := PartyNames.display_name(texts, s.party.members[0])
		if at != 0:  # 대열 바꾸기(실제 규칙): 그 대원을 넷째(뒷열 첫째)로
			var ids := s.party.members.map(func(m: PartyState.Member) -> String: return m.id)
			var near_id: String = ids.pop_front()
			ids.insert(at, near_id)
			check_eq(GuildRules.arrange(s, ids.slice(0, 3), ids.slice(3))[0]["type"], "arranged", "준비: 대열 바꾸기")
		check(SaveCodec.decode(SaveCodec.encode(s), s.defs).ok(), "준비: 저장 검사를 지나는 상태")
		var got: Array = await _report_lines(s)
		var want_gain := [30, 30, 30, 30, 30]
		want_gain[at] = 1
		check_eq(got[1], want_gain, "준비: 실제로 받은 경험치(%s 가 %d 번, 상한 1 앞)" % [who, at])
		check_eq(got[0][2], "경험치 30 · 상한 %s 1" % who, "%d 번: 경험치 줄은 의뢰 보수, 상한 대원은 같은 줄에" % at)
		lines_by_order.append(got[0][2])
	check_eq(lines_by_order[0], lines_by_order[1], "대원 차례를 바꿔도 경험치 줄은 같다")


## 결과 글 폭: 여덟 글자 이름(길드 규칙이 받는 이름) 다섯으로 섞인 경우(쓰러짐·상한·레벨 업 셋), 다섯 모두 못 받음, 다섯 모두 상한 1 앞을
## 세 크기에서 실제 화면 흐름(「임무를 보고한다」 → 줄 → 「예」)으로 그리고, 그린 글마다 글꼴로 잰 폭이 줄 칸 안인지 본다(SheetParts 는 잘려도
## 원래 글을 적으므로 폭을 잰다). 잰 값은 출력에 남긴다.
func test_result_widths_with_long_names_at_three_sizes() -> void:
	for px in SIZES:
		for how in [["down", "cap"], ["down", "cap", "cap", "down", "cap"], ["near", "near", "near", "near", "near"]]:
			var s := _state()
			for i in 5:
				check_eq(GuildRules.rename(s, s.party.members[i].id, "가나다라마바사" + str(i))[0]["type"], "renamed", "준비: 여덟 글자 이름")
			_result_party(s, how)
			check(SaveCodec.decode(SaveCodec.encode(s), s.defs).ok(), "준비: 저장 검사를 지나는 상태")
			var q := await _fresh(s, "council", px)
			await _step(q, "row", 1)
			await _step(q, "confirm")
			await _step(q, "dialog", ["confirm", null])
			await kit.frames(2)
			check_eq((q.result.get("lines", []) as Array).size(), 4, "%s %s: 결과 줄 넷" % [px, how])
			for d in SheetParts.record(q.box):
				if d["kind"] != "text":
					continue
				var w := SheetParts.text_width(q.box, str(d["text"]), int(d["fs"]))
				var room: float = (d["rect"] as Rect2).size.x
				print("WIDTH %s %s fs=%d width=%.0f room=%.0f %s" % [px, ",".join(how), int(d["fs"]), w, room, d["text"]])
				check(w <= room + 0.1, "%s: 잘리지 않는다 %.0f <= %.0f %s" % [px, w, room, d["text"]])


# ---- 키패드 = 키 ----

const PAGES := {"root": [], "accept": [["row", 0]], "report": [["row", 1]], "ask": [["row", 0], ["confirm"]]}


func _to_page(q: QuestScreen, name: String) -> void:
	for st in PAGES[name]:
		await _step(q, st[0], st[1] if (st as Array).size() > 1 else null)


func _parity(cases: Array) -> void:
	for c in cases:
		var tag: String = c[0]
		var k: String = c[2]
		var q := await _fresh(_state(), "pub")
		await _to_page(q, c[1])
		var pre := _sig(q)
		var on: bool = q.pad_state()[k]
		check_eq(on, c[3], tag + ": 켜짐/흐림")
		var b := _pad_button(q, k)
		check(b.is_visible_in_tree() and b.disabled == not on, tag + ": 단추가 보이고 흐림이 상태와 같다")
		await kit.tap(kit.center_of(b), FINGER)
		var by_pad := _sig(q)
		q = await _fresh(_state(), "pub")
		await _to_page(q, c[1])
		check_eq(_sig(q), pre, tag + ": 준비가 같다")
		await kit.press_key(QuestScreen.PAD_KEYS[k])
		check_eq(by_pad, _sig(q), tag + ": 키패드 = 키")
		if not on or c[4]:
			check_eq(by_pad, pre, tag + ": 아무것도 바꾸지 않는다")
		else:
			check(int(by_pad[-1]) == int(pre[-1]) + 1, "%s: 켜진 단추는 입력 하나" % tag)


## 쪽마다 키패드(실제 누르기) = 키, 흐린 단추는 아무것도 하지 않는다.
func test_pad_matches_keys_on_every_page() -> void:
	_kit()
	await _parity([
		["뿌리 ↓", "root", "down", true, false], ["뿌리 ←", "root", "left", false, false], ["뿌리 선택", "root", "ok", true, false],
		["뿌리 취소", "root", "back", true, false],
		["받기 ↓(한 줄, 끝)", "accept", "down", true, true], ["받기 →", "accept", "right", false, false], ["받기 선택", "accept", "ok", true, false],
		["받기 취소", "accept", "back", true, false],
		["보고 선택(빈 목록)", "report", "ok", false, false], ["보고 취소", "report", "back", true, false],
		["확인 ←(예에서)", "ask", "left", true, true], ["확인 →", "ask", "right", true, false], ["확인 ↑", "ask", "up", false, false], ["확인 선택", "ask", "ok", true, false],
		["확인 취소", "ask", "back", true, false],
	])


# ---- 층 표 ----

## 층 표(설계 §6.3, 이름 붙은 차이 반영): 1280×720·1728×720·1280×960 에서 자리, 목록과 말 상자는 겹치지 않고 소지금 문패 아래,
## 말 상자는 두 패드와 겹치지 않으며, 누를 것은 모두 64 이상·화면 안.
func test_layer_boxes_and_targets_at_three_sizes() -> void:
	for px in SIZES:
		for name in PAGES:
			var s := _state()
			QuestRules.accept(s, SOUP, "pub")
			var q := await _fresh(s, "pub", px)
			await _to_page(q, name)
			var size := tree.root.get_visible_rect().size
			var tag := "%s %s" % [str(px), name]
			var screen := Rect2(Vector2.ZERO, size)
			var dpad := _rect(q.dir_pad)
			var kp := _rect(q.key_pad)
			check_eq([dpad.position, kp.position], [Vector2(8, size.y - 209), Vector2(size.x - 247, size.y - 293)], tag + ": 패드")
			check_eq(_rect(q.banner), Rect2(192, 0, size.x - 192, 100), tag + ": 띠")
			check_eq(_rect(q.money_plate), Rect2(0, 112, 340, 50), tag + ": 소지금")
			check_eq(_rect(q.npc), Rect2(size.x - 560, 0, 560, size.y), tag + ": 주인")
			for b in q.visible_buttons():
				var r := q.clipped_rect(b) if not (b.get_parent() is VirtualPad) else b.get_global_rect()
				check(b.size.y >= 64.0 and b.size.x >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str(b.size)])
				check(screen.encloses(r.grow(-0.5)), "%s: %s 가 화면 안" % [tag, b.name])
				if not (b.get_parent() is VirtualPad):
					check(not r.intersects(dpad) and not r.intersects(kp), "%s: %s 는 키패드와 겹치지 않음" % [tag, b.name])
			match name:
				"root":
					check_eq(_rect(q.root_list), Rect2(0, 166, 430, FacilityList.content_height(4, 3, 3)), tag + ": 뿌리 목록")
					check_eq(_rect(q.camp_plate), Rect2(0, 0, 176, 100), tag + ": 캠프 문패")
					check(q.cards.visible and not q.list_window.visible and not q.box.visible, tag + ": 뿌리는 카드, 목록·상자 감춤")
					check(_rect(q.root_list).end.y <= dpad.position.y + 0.5, tag + ": 뿌리 목록은 방향 패드 위")
				_:
					var lw := _rect(q.list_window)
					var bx := _rect(q.box)
					check_eq(lw, Rect2((size.x - 760) / 2.0, 172, 760, ListParts.list_height(4)), tag + ": 목록 창")
					check_eq(bx, Rect2(216, size.y - 248, size.x - 472, 232), tag + ": 말 상자")
					check(not lw.intersects(bx), tag + ": 목록과 말 상자는 겹치지 않는다")
					check(not lw.intersects(_rect(q.money_plate)) and not lw.intersects(_rect(q.banner)), tag + ": 목록은 띠·소지금과 겹치지 않는다")
					check(not bx.intersects(dpad) and not bx.intersects(kp), tag + ": 말 상자는 두 패드와 겹치지 않는다")
					check(not q.cards.visible and not q.root_list.visible and not q.camp_plate.visible, tag + ": 카드·뿌리·캠프 문패 감춤")
			if q.dialog.is_open():
				var wr := q.dialog.window_rect()
				check(screen.encloses(wr) and not wr.intersects(kp) and not wr.intersects(dpad), "%s: 창은 화면 안, 패드에 가려지지 않음" % tag)


# ---- 누르기 지킴이(A7d 규칙) ----

## 쪽마다 고름 값이 가만히 그대로이고 누르는 순간 값을 바꾸는 단추가 없다(test_press_guard 의 검사).
func test_press_guard_keys_are_stable_and_no_press_changes_them() -> void:
	var s := await _town()
	await kit.tap(kit.center_of(s.town_screen.plaza_list.rows[PUB_ROW]))
	await kit.frames(1)
	var q := s.quest_screen
	for step in [[KEY_NONE, "뿌리"], [KEY_1, "받기"], [KEY_ENTER, "받기 확인"]]:
		if step[0] != KEY_NONE:
			await kit.press_key(step[0])
		await HM.stable(self, kit, q, step[1])
		var n := await HM.press_audit(self, kit, q, step[1])
		check(n > 0, "%s: 눌러 본 단추 %d개" % [step[1], n])
		await HM.stable(self, kit, q, step[1] + " 누른 뒤")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_2)
	await HM.stable(self, kit, q, "보고")


## U5 (M-U5 sync() 가 _refresh 의 맨 끝이 아님): 바깥에서 목록이 바뀐 뒤(B2F 를 다녀와 나방 소탕이 열림) 줄을 누른 채 아무것도 바뀌지 않는
## 다시 그리기가 오면 그 누르기는 그대로이고, 떼면 받기 확인이 열린다(기억한 고름 값이 낡지 않는다).
func test_sync_last_keeps_a_fresh_key() -> void:
	var s := _state()
	var q := await _fresh(s, "pub")
	await _step(q, "row", 0)
	s.enter_floor(s.defs.floors["b2f"])
	s.enter_floor(s.defs.first_floor())
	s.location = ExplorationState.TOWN
	q.refresh_view()
	await kit.frames(1)
	check_eq(q.list_ids, [SOUP, MOTH] as Array[String], "준비: 나방 소탕이 열렸다")
	var row := q.list_inv.rows[0]
	kit.touch(FINGER, kit.center_of(row), true)
	await kit.frames(1)
	q.refresh_view()  # 아무것도 바뀌지 않은 다시 그리기
	await kit.frames(1)
	kit.touch(FINGER, kit.center_of(row), false)
	await kit.frames(2)
	check_eq([q.dialog.is_open(), q.asking, q.asking_id], [true, "accept", SOUP], "떼면 받기 확인(누르기가 버려지지 않았다)")


# ---- U6 저장 실패 안내 ----

## U6 (M-U6 의뢰 화면이 _toast_window 에 없음): 의뢰 화면에서 받기의 자동 저장이 실패하면 실패 안내는 의뢰 화면 띠에 보인다(알림 줄은 그리지 않는다).
## 받은 것은 그대로다.
func test_save_failure_shows_in_the_quest_screen() -> void:
	var s := await _town()
	await kit.tap(kit.center_of(s.town_screen.plaza_list.rows[PUB_ROW]))
	await kit.frames(1)
	var q := s.quest_screen
	await kit.press_key(KEY_1)
	await kit.press_key(KEY_ENTER)
	s.store.fail_points = ["write"]
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	check(not s.last_autosave_error.is_empty(), "준비: 저장 실패")
	check_eq([q.notice, s._toast.modulate.a], [texts.t("msg.save_failed", {"reason": s.last_autosave_error}), 0.0], "저장 실패 안내(의뢰 화면 띠)")
	check(s.state.quests.is_accepted(SOUP), "받은 것은 그대로")
	s.store.fail_points = []
