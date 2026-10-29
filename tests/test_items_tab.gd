## 캠프 소지품의 쓰기·버리기(M3 A4b 설계 §6.1·§6.3·§8.2): 소모품이 앞인 줄, 줄 종류마다의 알약(「쓰기」 자리는 비고 「버리기」는 제자리),
## 목록 → 알약 → 고르기 쪽(키 = 키패드, 누르기는 커서 줄에 대해), 「쓰기」 메디카(설명 상자 대신 카드, 받아들이면 저장 한 번·목록으로, 가득하면 고르기 그대로),
## 테리아카 흐림, 종류마다 1개 버리기(확인 창 「돌아가기」 먼저)·n개 버리기(수량 창 「아니오」 먼저), 비콘(마을 흐림, 미궁 확인 창 → 마을·캠프 닫힘·
## 저장 한 번·남은 물음 버림), 띠 「소지품   n/60」·넘친 가방 경고, 세 크기의 층·64px·노랑 하나. 시험마다 죽이는 변이(M-C…)를 적는다.
## 저장은 장면 시험 임시 폴더에만.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Camp := preload("res://tests/test_camp.gd")
const HM := preload("res://tests/held_matrix.gd")
## 1280×720 · 1728×720(논리, 2400×1000 창) · 1280×960.
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000), Vector2(1280, 960)]

const MEDICA := "use.medica"
const NECTAR := "use.nectar"
const THERIACA_A := "use.theriaca_a"
const BEACON := "use.ariadne_beacon"
const TWIN := "equip.twin_edge"
const RAT := "item.neon_rat_tail"
const MOSS := "key.moss_card"

var kit: Kit
var texts: TextDb
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


## 미궁(시험 층) 새 게임, 디버그 주소. bag 을 넣은 뒤 캠프 소지품을 연다(창 1280×720).
func _items(bag: Dictionary, debug: bool = true, px: Vector2 = SIZES[0]) -> DungeonScreen:
	timeout_sec = 120.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	texts = TextDb.load_path("res://data/text/ko.json")
	var s := await kit.open("native", 7, "debug=1" if debug else "")
	s.native_debug = debug
	await _window(px)
	_put(s, bag)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(1)
	check_eq([s.party_menu.page, s.party_menu.tab], ["sub", 3], "준비: 소지품")
	return s


func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## bag: {consumables, gear_bag, materials, key_items} 의 일부.
static func _put(s: DungeonScreen, bag: Dictionary) -> void:
	s.state.consumables = (bag.get("consumables", {}) as Dictionary).duplicate()
	s.state.gear_bag = (bag.get("gear_bag", {}) as Dictionary).duplicate()
	s.state.materials = (bag.get("materials", {}) as Dictionary).duplicate()
	s.state.key_items = (bag.get("key_items", {}) as Dictionary).duplicate()


## 커서를 가방 줄 k 로(목록 쪽에서 ↑↓).
func _to_row(it: PartyItemsTab, k: int) -> void:
	while it.mode != "list":
		await kit.press_key(KEY_ESCAPE)
	var at := it.row_items.find(it.cursor_item())
	for i in absi(k - at):
		await kit.press_key(KEY_DOWN if k > at else KEY_UP)
	check_eq(it.cursor_item(), it.row_items[k], "준비: 커서 줄 %d" % k)


## 줄 k 의 그린 모양 [몸 채움 색, 글자색](SheetParts 기록: 아이콘 칸 다음 채움이 몸, 글은 몸 위).
static func _row_paint(it: PartyItemsTab, k: int) -> Array:
	var rec := SheetParts.record(it.rows[k])
	var fills := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "fill")
	var words := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "text")
	return [fills[1]["color"], words[0]["color"]] if fills.size() > 1 and not words.is_empty() else []


## 고른 줄(chosen) 모양 = 상점 줄 chosen 과 같은 테마 항목 「cmd:chosen」.
static func _chosen_paint() -> Array:
	var lk := UiTheme.look("cmd:chosen")
	return [lk["top"], lk["text"]]


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


## 소지품에서 노랑으로 채운 것(줄·알약·카드 표지는 테두리라 빼고, 창 단추는 PartyButton 모양).
func _yellow(pm: PartyMenu) -> Array:
	var it := pm.items_tab
	var out := Camp._items_yellow(it)
	for b in [it.qty.yes_button, it.qty.no_button] + pm.dialog_buttons:
		var pb := b as PartyButton
		if pb.is_visible_in_tree() and pb.selected:
			out.append(str(pb.name))
	return out


## 지금 보이는 알약 [(이름, 자리)].
static func _pills(it: PartyItemsTab) -> Array:
	var out := []
	for b in [it.use_button, it.drop_button]:
		if (b as Control).is_visible_in_tree():
			out.append([str(b.name), _rect(b)])
	return out


func _check_saved(s: DungeonScreen, label: String) -> void:
	check_eq(kit.auto_generation(), s.state.generation, label + ": 자동 저장 세대")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), label + ": 자동 저장 내용 = 지금 상태")


# ---- 줄·알약 ----

## M-C1(장비 줄에 「쓰기」)·M-C7(장비·소재 줄에서 「버리기」가 위로 올라감): 소모품 → 장비 → 소재 → 귀중품, 알약은 설계 §6.1 표대로.
func test_rows_put_consumables_first_and_pills_follow_the_row_kind() -> void:
	var s := await _items({"consumables": {MEDICA: 2, BEACON: 1}, "gear_bag": {TWIN: 1}, "materials": {RAT: 3}, "key_items": {MOSS: true}})
	var it := s.party_menu.items_tab
	check_eq(it.row_items, [MEDICA, BEACON, TWIN, RAT, MOSS], "줄: 소모품(정의 차례) → 장비 → 소재 → 귀중품")
	var m: Dictionary = it.inv.data[0]
	check_eq([m["icon"], m["name"], m["right"]], ["kind_consumable", "메디카", "2개"], "소모품 줄: 아이콘·이름·「n개」")
	var use := Rect2(735, 278, 240, 64)
	var drop := Rect2(735, 350, 240, 64)
	var want := [[MEDICA, [["ItemUse", use], ["ItemDrop", drop]]], [BEACON, [["ItemUse", use], ["ItemDrop", drop]]],
		[TWIN, [["ItemDrop", drop]]], [RAT, [["ItemDrop", drop]]], [MOSS, []]]
	for k in want.size():
		await _to_row(it, k)
		check_eq([it.cursor_item(), _pills(it)], want[k], "%s 줄의 알약(자리 그대로)" % want[k][0])
		check(not it.use_button.visible or not it.use_button.dimmed, "%s: 미궁에서 「쓰기」는 켜짐(메디카는 대원을 고르기 전, 비콘은 미궁)" % want[k][0])
		check(not it.use_button.selected and not it.drop_button.selected, "%s: 목록 쪽에서 알약은 노랑이 아니다(원작 III HD 05)" % want[k][0])
	check_eq(_rect(it.supply_button), Rect2(735, 430, 240, 64), "디버그 「임시 보급」은 「버리기」 아래(D5)")
	await _to_row(it, 0)
	check_eq([it.desc.title, it.desc.lines], ["메디카", ["정크 공방이 찍어 내는 나노 회복 앰플. HP가 조금 회복된다", "소모품", "판매값 10엔"]], "소모품 설명: 글 · 「소모품」 · 판매값")


## Enter → 알약 쪽(소모품 = 「쓰기」, 장비·소재 = 「버리기」), ↑↓ 보이는 알약 사이, Esc → 목록. 귀중품 줄 Enter 는 아무 일 없음.
## 키패드 = 키, 노랑은 하나(알약 쪽이면 목록 커서는 chosen).
func test_enter_opens_pills_and_keypad_equals_keys() -> void:
	var s := await _items({"consumables": {MEDICA: 1}, "gear_bag": {TWIN: 1}, "key_items": {MOSS: true}})
	var pm := s.party_menu
	var it := pm.items_tab
	await kit.press_key(KEY_ENTER)
	check_eq([it.mode, it.pill, it.target_item], ["pills", 0, MEDICA], "소모품 줄 Enter → 「쓰기」")
	check_eq(_yellow(pm), ["ItemUse"], "노랑은 「쓰기」 하나(목록 커서 줄은 chosen)")
	# M-C11(chosen → none)·M-C12(chosen 을 보통 줄로 그림)·M-C13(모양 갈고리가 chosen 을 넘기지 않음): 그린 색으로 본다.
	check_eq(_row_paint(it, 0), _chosen_paint(), "알약 쪽: 커서 줄은 밝은 시안 chosen(상점 줄과 같은 「cmd:chosen」)")
	check_eq(_row_paint(it, 1), [ListParts.ROW_BODY, ListParts.ROW_TEXT], "다른 줄은 보통 모양")
	check(_chosen_paint()[0] != ListParts.ROW_BODY and not Camp._is_yellow(_chosen_paint()[0]), "chosen 은 보통 줄과 다르고 노랑이 아니다")
	await kit.press_key(KEY_DOWN)
	check_eq(it.pill, 1, "↓ → 「버리기」")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq([it.pill, pm.accepted_inputs], [1, n], "끝에서 ↓ 는 아무 일 없음")
	await kit.press_key(KEY_ESCAPE)
	check_eq([it.mode, pm.page, pm.tab], ["list", "sub", 3], "Esc → 목록(소지품 그대로)")
	check_eq(_yellow(pm), [str(it.rows[0].name)], "목록: 노랑은 커서 줄 하나")
	check_eq(_row_paint(it, 0), [ListParts.CURSOR, ListParts.CURSOR_TEXT], "목록 쪽: 커서 줄은 노랑(chosen 아님)")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq([it.mode, it.pill, it.target_item], ["pills", 1, TWIN], "장비 줄 Enter → 「버리기」")
	check(not pm.pad_state()["down"] and not pm.pad_state()["up"], "알약 하나: ↑↓ 흐림")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_DOWN)
	check_eq([it.cursor_item(), pm.pad_state()["ok"]], [MOSS, false], "귀중품 줄: 「선택」 흐림")
	var h := SaveCodec.state_hash(s.state)
	n = pm.accepted_inputs
	await kit.press_key(KEY_ENTER)
	check_eq([it.mode, pm.accepted_inputs, SaveCodec.state_hash(s.state)], ["list", n, h], "귀중품 줄 Enter: 아무 일 없음")
	# 키패드 = 키: 같은 차례를 키패드로.
	await kit.tap(kit.center_of(it.rows[0]))
	var ok := pm.key_pad_stacked.button("ok")
	await kit.tap(kit.center_of(ok), 3)
	check_eq([it.mode, it.pill], ["pills", 0], "키패드 「선택」 = Enter")
	await kit.tap(kit.center_of(pm.dir_pad.button("down")), 3)
	check_eq(it.pill, 1, "키패드 ↓ = ↓")
	await kit.tap(kit.center_of(pm.key_pad_stacked.button("back")), 3)
	check_eq(it.mode, "list", "키패드 「취소」 = Esc")
	# 누르기: 줄을 누르면 목록 쪽으로, 알약을 누르면 커서 줄에 대해.
	await kit.press_key(KEY_ENTER)
	await kit.tap(kit.center_of(it.rows[1]))
	check_eq([it.mode, it.cursor_item()], ["list", TWIN], "알약 쪽에서 줄 누르기 → 목록 쪽, 커서는 그 줄")
	await kit.tap(kit.center_of(it.drop_button))
	check_eq([pm.dialog_kind, it.target_item], ["drop", TWIN], "「버리기」 누르기 → 커서 줄(트윈 엣지) 버리기 창")


# ---- 쓰기 ----

## M-C5(고르기에도 설명 상자가 남음)·M-C6(거부된 쓰기가 고르기를 떠남): 메디카 「쓰기」 → 카드 고르기, 가득한 대원은 이유만·고르기 그대로,
## 다친 대원은 회복·저장 한 번·목록 쪽(커서는 메디카).
func test_use_medica_picks_a_card_and_saves_once() -> void:
	var s := await _items({"consumables": {MEDICA: 2}, "materials": {RAT: 1}})
	var pm := s.party_menu
	var it := pm.items_tab
	var m := s.state.party.members[1]
	m.hp = m.max_hp - 10
	pm.refresh_view()
	var saves := s.autosave_count
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	check_eq([it.mode, pm.pick_cursor], ["pick", 1], "「쓰기」 → 고르기, 커서는 쓸 수 있는 첫 대원")
	check(not it.desc.is_visible_in_tree() and pm.cards.is_visible_in_tree(), "고르기: 설명 상자 대신 파티 카드")
	check_eq([_row_paint(it, 0), _row_paint(it, 1)], [_chosen_paint(), [ListParts.ROW_BODY, ListParts.ROW_TEXT]], "고르기: 메디카 줄은 chosen, 다른 줄은 보통")
	check_eq(pm.notice_line_text(), "메디카: 누구에게 쓸까?", "띠: 물음")
	for c in pm.cards.cards:
		for r in [_rect(it.window), _rect(it.use_button), _rect(it.drop_button), _rect(it.supply_button)]:
			check(not _rect(c).intersects(r), "카드 %s 가 %s 와 겹치지 않는다" % [str(_rect(c)), str(r)])
	check_eq([pm.cards.card(1).target_mark, pm.cards.card(0).target_mark], ["pick", ""], "노란 테두리는 커서 카드 하나")
	await kit.tap(kit.center_of(pm.cards.card(0)))
	check_eq([it.mode, s.state.consumables, s.autosave_count], ["pick", {MEDICA: 2}, saves], "가득한 대원: 고르기 그대로·물건 그대로·저장 없음")
	check_eq(pm.notice, "HP가 가득하다", "이유만")
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.pick_cursor, 1, "→ 다음 카드")
	await kit.press_key(KEY_ENTER)
	check_eq([m.hp, s.state.consumables, s.autosave_count], [m.max_hp, {MEDICA: 1}, saves + 1], "회복·하나 줄고 저장 한 번")
	check_eq([it.mode, it.cursor_item()], ["list", MEDICA], "목록 쪽, 커서는 메디카")
	check(it.desc.is_visible_in_tree() and not pm.cards.is_visible_in_tree(), "설명 상자가 돌아오고 카드는 숨는다")
	check(pm.notice.contains("HP가 10 회복"), "결과는 알림 줄(D2): %s" % pm.notice)
	_check_saved(s, "메디카")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ESCAPE)
	check_eq([it.mode, it.pill], ["pills", 0], "고르기에서 Esc → 알약 쪽")


## M-C9(캠프 알약이 흐림을 그리지 않음): 테리아카는 전투 전용 — 「쓰기」는 흐린 줄 모양, 누르면 이유만, 커서가 서면 노란 테만.
func test_battle_only_items_are_dim() -> void:
	var s := await _items({"consumables": {THERIACA_A: 1}})
	var pm := s.party_menu
	var it := pm.items_tab
	check(it.use_button.is_visible_in_tree() and it.use_button.dimmed, "테리아카 A: 「쓰기」 흐림")
	check_eq([it.use_button.pill_state(), it.drop_button.pill_state()], ["dim", "normal"], "흐린 「쓰기」는 흐린 줄 모양(「버리기」는 보통)")
	check_eq(ListParts.pill_colors("dim"), [ListParts.ROW_DIM, ListParts.ROW_DIM_TEXT], "흐린 알약 색 = 흐린 줄 색")
	var h := SaveCodec.state_hash(s.state)
	await kit.tap(kit.center_of(it.use_button))
	check_eq([pm.notice, it.mode, SaveCodec.state_hash(s.state), pm.dialog_kind], ["전투에서만 쓸 수 있다", "pills", h, ""], "누르면 이유만")
	# 흐린 알약에 커서: 노랑 채움 없이 노란 테(흐린 줄 커서와 같다, 07 §9.9 E2-b).
	check_eq(it.use_button.pill_state(), "dim_selected", "커서가 선 흐린 「쓰기」")
	check_eq(_yellow(pm), [], "노랑 채움 없음")
	var rings := SheetParts.record(it.use_button).filter(func(e: Dictionary) -> bool: return e["kind"] == "outline" and e["color"] == ListParts.CURSOR_EDGE)
	check_eq(rings.size(), 1, "노란 테 하나")


# ---- 버리기 ----

## M-C3(수량 창이 「예」 먼저): 종류마다 1개는 확인 창(「돌아가기」 먼저), n개는 수량 창(「아니오」 먼저, ↑ 로 늘림, Enter = 고른 쪽).
func test_discard_one_and_many_of_each_bag_kind() -> void:
	for x in [[MEDICA, "consumables"], [TWIN, "gear_bag"], [RAT, "materials"]]:
		var id: String = x[0]
		for n in [1, 3]:
			var bag := {str(x[1]): {id: n}}
			var s := await _items(bag)
			var pm := s.party_menu
			var it := pm.items_tab
			var tag := "%s %d개" % [id, n]
			check_eq(it.cursor_item(), id, tag + ": 준비")
			var saves := s.autosave_count
			await kit.tap(kit.center_of(it.drop_button))
			if n == 1:
				check_eq([pm.dialog_kind, pm.dialog_pick], ["drop", 0], tag + ": 확인 창, 첫 커서 「돌아가기」")
				check_eq([pm._dialog_text.text, pm.dialog_buttons[0].text, pm.dialog_buttons[1].text],
					[texts.t("party.items.drop_ask", {"item": it.item_label(id)}), "돌아가기", "버리기"], tag + ": 창 글·단추")
				check_eq(_yellow(pm), ["DialogBack"], tag + ": 노랑은 「돌아가기」 하나")
				await kit.press_key(KEY_ENTER)
				check_eq([pm.dialog_kind, s.autosave_count, BagRules.used(s.state)], ["", saves, 1], tag + ": 「돌아가기」 → 그대로")
				await kit.tap(kit.center_of(it.drop_button))
				await kit.press_key(KEY_RIGHT)
				await kit.press_key(KEY_ENTER)
			else:
				check(it.qty.is_open() and it.qty.mode == "qty", tag + ": 수량 창")
				check_eq([it.qty.pick, it.qty.qty, it.qty.max_qty, it.qty.total_text()], [ShopDialog.NO, 1, n, "1개 버릴까?"], tag + ": 첫 커서 「아니오」, 1~가진 수")
				check_eq(_yellow(pm), ["No"], tag + ": 노랑은 「아니오」 하나")
				check_eq(_row_paint(it, 0), _chosen_paint(), tag + ": 수량 창 뒤 커서 줄은 chosen")
				await kit.press_key(KEY_UP)
				check_eq([it.qty.qty, it.qty.total_text()], [2, "2개 버릴까?"], tag + ": ↑ → 2")
				await kit.press_key(KEY_ENTER)
				check_eq([it.qty.is_open(), s.autosave_count, BagRules.used(s.state)], [false, saves, n], tag + ": 「아니오」 → 그대로")
				await kit.tap(kit.center_of(it.drop_button))
				await kit.press_key(KEY_UP)
				await kit.press_key(KEY_LEFT)
				await kit.press_key(KEY_ENTER)
			var left: int = 0 if n == 1 else n - 2
			check_eq([BagRules.used(s.state), s.autosave_count, it.mode], [left, saves + 1, "list"], tag + ": 버림·저장 한 번·목록 쪽")
			check(pm.notice.contains("버렸다"), tag + ": 알림 %s" % pm.notice)
			_check_saved(s, tag)


## M-H9·M-H11·M-H12·M-H13(검토 seq=9): 캠프 「버리기」 확인 창(1개: 공용 확인 띠 ConfirmBand, 고름은 캠프 dialog_pick)과 수량 창(3개: 공용 창
## ShopDialog, 키패드는 캠프 화면에 있다)에서 키패드 「선택」·창 단추 둘을 손가락 3 으로 누른 채 답을 옮기면(손가락 4 방향 패드·방향키)
## 누르기가 풀리고, 떼도 버리지 않고 저장하지 않는다. 옮기지 않고 누른 「버리기」·「예」는 버리고 자동 저장한다.
func test_answer_change_drops_held_presses() -> void:
	for n in [1, 3]:
		var s := await _items({"consumables": {MEDICA: n}})
		var pm := s.party_menu
		var it := pm.items_tab
		await kit.tap(kit.center_of(it.drop_button))
		var band: bool = n == 1
		var pick := func() -> int: return pm.dialog_pick if band else it.qty.pick
		# 창 단추는 왼쪽부터 [0, 1](띠: 「돌아가기」·「버리기」, 수량 창: 「예」·「아니오」). 고름 번호도 같다.
		var buttons: Array = pm.dialog_buttons if band else [it.qty.yes_button, it.qty.no_button]
		check_eq([pm.dialog_kind if band else it.qty.mode, pick.call()], ["drop", 0] if band else ["qty", ShopDialog.NO], "%d개: 준비: 창" % n)
		var used := BagRules.used(s.state)
		var saves := s.autosave_count
		var h := kit.hash_now()
		var ok := pm.active_key_pad().button("ok")
		for c in [["「선택」", ok], ["왼쪽 단추", buttons[0]], ["오른쪽 단추", buttons[1]]]:
			for v in ["pad", "key"]:
				var tag := "%d개 %s(%s)" % [n, c[0], v]
				var b: TouchButton = c[1]
				var p := kit.center_of(b)
				var pick0: int = pick.call()
				kit.touch(3, p, true)
				await kit.frames(1)
				check(b.held, tag + ": 준비: 누르는 중")
				if v == "pad":
					await kit.tap(kit.center_of(pm.dir_pad.button("right" if pick0 == 0 else "left")), 4)
				else:
					await kit.press_key(KEY_RIGHT if pick0 == 0 else KEY_LEFT)
				check_eq(pick.call(), 1 - pick0, tag + ": 답이 옮겨졌다")
				check(not b.held, tag + ": 답이 바뀌면 누르기 취소")
				kit.touch(3, p, false)
				await kit.frames(2)
				check_eq([pm.dialog_kind if band else it.qty.mode, pick.call(), BagRules.used(s.state), s.autosave_count, kit.hash_now()],
					["drop" if band else "qty", 1 - pick0, used, saves, h], tag + ": 뗄 때 아무 일 없음(버리기·저장 없음)")
		# 보통 흐름: 답을 옮기지 않고 일하는 단추(띠 「버리기」, 수량 창 「예」)를 누른다.
		await kit.tap(kit.center_of(buttons[1] if band else buttons[0]))
		await kit.frames(2)
		check_eq([BagRules.used(s.state), s.autosave_count], [used - 1, saves + 1], "%d개: 보통 누르기 → 하나 버리고 자동 저장" % n)
		_check_saved(s, "%d개 버리기" % n)


## M-H14(수량이 바뀌어도 누르기를 버리지 않음, 검토 seq=10): 캠프 「버리기」 수량 창(메디카 3개)에서 답을 「예」로 옮긴 뒤 키패드 「선택」·「예」를
## 손가락 3 으로 누른 채 수량을 바꾸면(손가락 4 방향 패드 ↑↓·방향키) 누르기가 풀리고, 떼도 버리지 않고 저장하지 않는다.
## 바뀐 수량에서 누른 보통 「예」는 그 수량을 한 번 버리고 자동 저장한다.
func test_quantity_change_drops_held_presses() -> void:
	var s := await _items({"consumables": {MEDICA: 3}})
	var pm := s.party_menu
	var it := pm.items_tab
	await kit.tap(kit.center_of(it.drop_button))
	await kit.press_key(KEY_LEFT)
	check_eq([it.qty.mode, it.qty.pick, it.qty.qty, it.qty.max_qty], ["qty", ShopDialog.YES, 1, 3], "준비: 수량 창 1~3, 「예」")
	var saves := s.autosave_count
	var h := kit.hash_now()
	var ok := pm.active_key_pad().button("ok")
	for c in [["「선택」", ok], ["「예」", it.qty.yes_button]]:
		for v in ["pad", "key"]:
			var tag := "%s(%s)" % [c[0], v]
			var b: TouchButton = c[1]
			var p := kit.center_of(b)
			var q0 := it.qty.qty
			var up := q0 < it.qty.max_qty
			var q1 := q0 + (1 if up else -1)
			kit.touch(3, p, true)
			await kit.frames(1)
			check(b.held, tag + ": 준비: 누르는 중")
			if v == "pad":
				await kit.tap(kit.center_of(pm.dir_pad.button("up" if up else "down")), 4)
			else:
				await kit.press_key(KEY_UP if up else KEY_DOWN)
			check_eq(it.qty.qty, q1, tag + ": 수량이 바뀌었다")
			check(not b.held, tag + ": 수량이 바뀌면 누르기 취소")
			kit.touch(3, p, false)
			await kit.frames(2)
			check_eq([it.qty.mode, it.qty.qty, BagRules.used(s.state), s.autosave_count, kit.hash_now()], ["qty", q1, 3, saves, h],
				tag + ": 뗄 때 아무 일 없음(버리기·저장 없음)")
	if it.qty.qty == 1:
		await kit.press_key(KEY_UP)
	var q := it.qty.qty
	await kit.tap(kit.center_of(it.qty.yes_button))
	await kit.frames(2)
	check_eq([BagRules.used(s.state), s.autosave_count], [3 - q, saves + 1], "보통 「예」 → 수량 %d 을 한 번 버리고 자동 저장" % q)
	_check_saved(s, "수량 %d 버리기" % q)


## 값 get 이 want 가 될 때까지 키 code 를 누른다(누르기 없음, 최대 8번).
func _key_until(get: Callable, want: Variant, code: int) -> void:
	for i in 8:
		if get.call() == want:
			return
		await kit.press_key(code)


## M-D4(소지품 key_part 에 커서 물건·알약이 없음)·M-D5(캠프 값에 pick_cursor 가 없음), M3 A7d: 가방 줄(메디카 → 넥타)·알약(쓰기 → 버리기)·
## 받을 대원(대원 0 → 1)을 키패드 「선택」(줄·알약은 그 단추도)을 손가락 3 으로 누른 채 옮기면(손가락 4 방향 패드·방향키) 누르기가 풀리고,
## 떼도 쪽·대상·HP·물건·저장이 그대로다. 이름 붙은 해(검토 표): 메디카가 새로 고른 대원 1 을 고치지 않는다(HP 10 그대로, 메디카 3개, 자동
## 저장 없음). 옮기지 않은 보통 「선택」은 고른 대원 0 을 한 번 고치고 자동 저장한다.
func test_selection_change_drops_held_presses() -> void:
	var s := await _items({"consumables": {MEDICA: 3, NECTAR: 1}}, false)
	var pm := s.party_menu
	var it := pm.items_tab
	s.state.party.members[0].hp = 20
	s.state.party.members[1].hp = 10
	var ok := func() -> TouchButton: return pm.active_key_pad().button("ok")
	var pad := func(k: String) -> Callable: return func() -> TouchButton: return pm.dir_pad.button(k)
	var hp := func() -> Array: return s.state.party.members.map(func(m: PartyState.Member) -> int: return m.hp)
	var obs := func() -> Array:
		return [it.mode, it.cursor_item(), it.pill, it.target_item, it.qty_open(), pm.page, pm.pick_cursor, hp.call(),
			int(s.state.consumables.get(MEDICA, 0)), kit.hash_now(), s.autosave_count, pm.selection_key()]
	var item := func() -> String: return it.cursor_item()
	var saves0 := s.autosave_count
	check_eq([it.mode, item.call()], ["list", MEDICA], "준비: 가방 줄 메디카")
	for hold in [["「선택」", ok], ["커서 줄", func() -> TouchButton: return it.rows[0]]]:
		await HM.run(self, kit, {"name": "가방 줄 " + hold[0], "hold": hold[1], "pad": pad.call("down"), "key": KEY_DOWN, "value": item,
			"observe": obs, "reset": _key_until.bind(item, MEDICA, KEY_UP)})
	await _key_until(item, MEDICA, KEY_UP)
	await kit.press_key(KEY_ENTER)
	var pill := func() -> int: return it.pill
	check_eq([it.mode, pill.call(), it.target_item], ["pills", 0, MEDICA], "준비: 알약(쓰기)")
	for hold in [["「선택」", ok], ["쓰기 알약", func() -> TouchButton: return it.use_button]]:
		await HM.run(self, kit, {"name": "알약 " + hold[0], "hold": hold[1], "pad": pad.call("down"), "key": KEY_DOWN, "value": pill,
			"observe": obs, "reset": _key_until.bind(pill, 0, KEY_UP)})
	await _key_until(pill, 0, KEY_UP)
	await kit.tap(kit.center_of(it.use_button))
	var who := func() -> int: return pm.pick_cursor
	check_eq([it.mode, who.call()], ["pick", 0], "준비: 받을 대원 고르기(대원 0)")
	await HM.run(self, kit, {"name": "받을 대원 「선택」", "hold": ok, "pad": pad.call("right"), "key": KEY_RIGHT, "value": who,
		"observe": obs, "reset": _key_until.bind(who, 0, KEY_LEFT)})
	check_eq([hp.call().slice(0, 2), int(s.state.consumables.get(MEDICA, 0)), s.autosave_count, it.mode], [[20, 10], 3, saves0, "pick"],
		"이름 붙은 해: 메디카가 새 대원 1 을 고치지 않았다(HP 10, 메디카 3개, 자동 저장 없음)")
	await _key_until(who, 0, KEY_LEFT)
	await kit.tap(kit.center_of(pm.active_key_pad().button("ok")), 3)
	check(s.state.party.members[0].hp > 20 and s.state.party.members[1].hp == 10, "보통 「선택」 → 고른 대원 0 만 고친다")
	check_eq([int(s.state.consumables.get(MEDICA, 0)), s.autosave_count], [2, saves0 + 1], "메디카 하나, 자동 저장 한 번")
	_check_saved(s, "메디카 쓰기")


## M-D13(캠프가 줄을 다시 만들기 전에 sync, 검토 seq=13): 키패드 「선택」을 누른 채 같은 커서 칸의 물건이 넥타 → 메디카로 바뀌면(디버그 보급,
## 다시 만든 줄) 그 새로 고침에서 바로 누르기가 풀리고, 떼도 아무 일 없다. 그 뒤 새로 시작한 누르기는 바뀐 것이 없는 새로 고침에서
## 풀리지 않고 떼면 한 번 일한다(메디카의 알약 쪽).
func test_same_index_replacement_cancels_at_once_and_a_fresh_press_survives() -> void:
	var s := await _items({"consumables": {NECTAR: 2}}, true)
	var pm := s.party_menu
	var it := pm.items_tab
	var c0 := it.cursor
	check_eq([it.mode, it.cursor_item()], ["list", NECTAR], "준비: 커서 칸 %d 넥타" % c0)
	var ok := pm.active_key_pad().button("ok")
	var p := kit.center_of(ok)
	kit.touch(3, p, true)
	await kit.frames(1)
	check(ok.held, "준비: 「선택」 누르는 중")
	var r: Dictionary = JSON.parse_string(s._on_debug_request(JSON.stringify({"op": "supply", "item": MEDICA, "n": 1})))
	await kit.frames(1)
	check(bool(r.get("ok", false)), "준비: 디버그 보급 메디카")
	check_eq([it.cursor, it.cursor_item()], [c0, MEDICA], "같은 커서 칸의 물건이 메디카로 바뀌었다")
	check(not ok.held, "그 새로 고침에서 바로 「선택」 누르기가 풀린다")
	var saves := s.autosave_count
	var n := pm.accepted_inputs
	kit.touch(3, p, false)
	await kit.frames(2)
	check_eq([it.mode, pm.accepted_inputs, s.autosave_count], ["list", n, saves], "뗄 때 아무 일 없음")
	kit.touch(3, p, true)
	await kit.frames(1)
	pm.refresh_view()
	await kit.frames(1)
	check(ok.held, "새 누르기는 바뀐 것이 없는 새로 고침에서 풀리지 않는다")
	kit.touch(3, p, false)
	await kit.frames(2)
	check_eq([it.mode, it.target_item, pm.accepted_inputs], ["pills", MEDICA, n + 1], "떼면 한 번 일한다(메디카 알약 쪽)")


# ---- 귀환 비콘 ----

## 마을에서는 흐림(누르면 「마을에서는 쓸 수 없다」).
func test_beacon_is_dim_in_town() -> void:
	timeout_sec = 120.0
	kit = Kit.new(tree)
	texts = TextDb.load_path("res://data/text/ko.json")
	var s := await kit.open("native", 7, "debug=1")
	await _window(SIZES[0])
	s._start_new_game()
	await kit.frames(2)
	check(s.state.in_town(), "준비: 마을")
	s.state.consumables = {BEACON: 1}
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var pm := s.party_menu
	var it := pm.items_tab
	check_eq([pm.tab, it.cursor_item()], [3, BEACON], "준비: 소지품, 커서 = 비콘")
	check(it.use_button.dimmed, "마을: 「쓰기」 흐림")
	await kit.tap(kit.center_of(it.use_button))
	check_eq([pm.notice, pm.dialog_kind, s.state.consumables], ["마을에서는 쓸 수 없다", "", {BEACON: 1}], "이유만")


## M-C2(비콘 창 첫 커서가 「돌아간다」)·M-C4(returned 가 캠프를 닫지 않음)·M-C10(비콘이 광장 안내 줄에 「뿌리마을」을 냄):
## 미궁에서 비콘 → 확인 창 → 「돌아간다」 → 마을 광장, 캠프 닫힘, 저장 한 번(내용 = 화면), 날·걸음·지도 메모 그대로, 남은 물음은 버린다.
## 「돌아가기」는 아무 일 없음. 도착 모습(광장 안내 줄·토스트·장소 문패)은 관문 도착(문 물음 「예」)과 같다(설계 §6.3).
func test_beacon_returns_to_town_from_the_labyrinth() -> void:
	var s := await _items({"consumables": {BEACON: 2}})
	var pm := s.party_menu
	var it := pm.items_tab
	check(not s.state.in_town() and not it.use_button.dimmed, "준비: 미궁, 「쓰기」 켜짐")
	var start := s.state.defs.first_floor().start_at
	s.state.annotation.set_memo(start, "입구")
	var day := s.state.day
	var steps := s.state.steps
	var saves := s.autosave_count
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.dialog_kind, pm.dialog_pick], ["beacon", 0], "확인 창, 첫 커서 「돌아가기」")
	check_eq([pm._dialog_text.text, pm.dialog_buttons[0].text, pm.dialog_buttons[1].text], ["아리아드네 비콘을 써서 마을로 돌아갈까?", "돌아가기", "돌아간다"], "창 글·단추")
	await kit.press_key(KEY_ENTER)
	check_eq([pm.dialog_kind, s.state.in_town(), s.autosave_count, s.state.consumables], ["", false, saves, {BEACON: 2}], "「돌아가기」 → 아무 일 없음")
	await kit.press_key(KEY_ENTER)
	s._stairs_ask = true  # 남은 물음(계단·상자): 마을에서는 버린다
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(not pm.is_open(), "캠프가 닫혔다")
	check(s.state.in_town() and s.town_screen.is_open() and s.town_screen.page == "plaza", "마을 광장")
	check_eq([s.state.floor_def.id, s.state.party.at, s.state.day, s.state.steps], [s.state.defs.first_floor().id, start, day, steps], "첫 층 시작 칸·날·걸음 그대로")
	check_eq([s.state.consumables, s.autosave_count], [{BEACON: 1}, saves + 1], "하나 줄고 저장 한 번")
	_check_saved(s, "비콘")
	check_eq(s.state.floor_states[s.state.defs.first_floor().id].annotation.memos.get(start), "입구", "지도 메모 그대로")
	check(not s._stairs_ask and not s.modal.is_open(), "남은 물음은 버렸다")
	var beacon := _arrival(s)
	check_eq(beacon, ["", 0.0, "뿌리마을 광장", ""], "비콘 도착: 광장 안내 줄 비었음·토스트 없음·장소 문패 「뿌리마을 광장」·저장 실패 안내 없음")
	# 같은 도착을 관문(시작 칸 문 물음 「예」)으로: 새 장면에서 문 밖 한 칸 → 돌아옴 → 「예」.
	kit.dispose()
	kit = Kit.new(tree)
	var g := await kit.open("native", 7, "debug=1")
	await kit.frames(2)
	g.state.encounter.threshold = 99999
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_S)
	check_eq(g.modal.kind, "stairs", "준비: 관문 물음")
	await kit.tap(kit.center_of(g.modal.find_child("StairsYes", true, false)))
	await kit.frames(3)
	check(g.state.in_town() and g.town_screen.is_open() and g.town_screen.page == "plaza", "준비: 관문 → 광장")
	check_eq(beacon, _arrival(g), "비콘 도착 = 관문 도착")


## 도착 뒤 보이는 것: [광장 안내 줄, 토스트 불투명도, 장소 문패 글, 저장 실패 안내].
static func _arrival(s: DungeonScreen) -> Array:
	return [s.town_screen.notice, s._toast.modulate.a, s.town_screen.place_text(), s.warning_shown()]


# ---- 띠·층 ----

## M-C8(띠가 소재를 세지 않음): 「소지품   12/60」(소모품 2 + 장비 3 + 소재 7), 넘친 가방은 「75/60 · 가방이 넘쳤다」 경고 색(대비 4.5 이상).
func test_strip_counts_the_shared_bag() -> void:
	var s := await _items({"consumables": {MEDICA: 2}, "gear_bag": {TWIN: 3}, "materials": {RAT: 7}, "key_items": {MOSS: true}})
	var pm := s.party_menu
	check_eq([pm.notice_line_text(), s.debug_snapshot()["party_menu"]["strip"]], ["소지품   12/60", "소지품   12/60"], "띠 = 공용 가방 칸 수")
	check_eq(pm.notice_line_color(), UiTheme.BATTLE_BANNER_NOTICE, "보통 색")
	check_eq([s.debug_snapshot()["bag_used"], s.debug_snapshot()["consumables"]], [12, {MEDICA: 2}], "스냅숏 bag_used·consumables")
	s.state.materials = {RAT: 70}
	pm.refresh_view()
	await kit.frames(1)
	check_eq(pm.notice_line_text(), "소지품   75/60 · 가방이 넘쳤다", "넘친 가방: 글로도 알린다")
	check_eq(pm.notice_line_color(), UiTheme.CAMP_NOTICE_WARN, "경고 색")
	check(Camp.contrast(UiTheme.CAMP_NOTICE_WARN, UiTheme.CAMP_NOTICE_BG) >= 4.5, "경고 글자 대비 4.5 이상")


## 세 크기(1280×720 · 1728×720 · 1280×960)에서 목록·알약·고르기·수량 창·확인 창 쪽마다: 누를 것은 64 이상·화면 안, 알약은 목록 창·설명 상자·키패드와
## 겹치지 않고, 고르기의 카드는 목록 창·알약·키패드와 겹치지 않는다. 노랑은 쪽마다 하나.
func test_layers_targets_and_one_yellow_at_three_sizes() -> void:
	for px in SIZES:
		var s := await _items({"consumables": {MEDICA: 3, BEACON: 1}, "materials": {RAT: 2}}, true, px)
		var pm := s.party_menu
		var it := pm.items_tab
		s.state.party.members[0].hp -= 5
		pm.refresh_view()
		var size: Vector2 = tree.root.get_visible_rect().size
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var pads := [_rect(pm.dir_pad), _rect(pm.key_pad_stacked)]
		for step in ["list", "pills", "pick", "qty", "dialog"]:
			match step:
				"pills":
					await kit.press_key(KEY_ENTER)
				"pick":
					await kit.press_key(KEY_ENTER)
				"qty":
					await kit.press_key(KEY_ESCAPE)
					await kit.press_key(KEY_DOWN)
					await kit.press_key(KEY_ENTER)
				"dialog":
					await kit.press_key(KEY_ESCAPE)
					await kit.press_key(KEY_ESCAPE)
					await kit.press_key(KEY_DOWN)
					await kit.press_key(KEY_ENTER)
					await kit.press_key(KEY_ENTER)
			await kit.frames(1)
			var t := "%s %s" % [tag, step]
			var want := {"list": ["list", ""], "pills": ["pills", ""], "pick": ["pick", ""], "qty": ["pills", ""], "dialog": ["pills", "beacon"]}
			check_eq([it.mode, pm.dialog_kind], want[step], t + ": 준비")
			if step == "qty":
				check(it.qty.is_open(), t + ": 준비: 수량 창")
			_targets(pm, size, t)
			for b in [it.use_button, it.drop_button]:
				if not (b as Control).is_visible_in_tree():
					continue
				for r in [_rect(it.window), _rect(it.desc)] + pads:
					check(not _rect(b).intersects(r), "%s: %s 가 %s 와 겹치지 않는다" % [t, b.name, str(r)])
			if step == "pick":
				for c in pm.cards.cards:
					for r in [_rect(it.window), _rect(it.use_button), _rect(it.drop_button), _rect(it.supply_button)] + pads:
						check(not _rect(c).intersects(r), "%s: 카드 %s 가 %s 와 겹치지 않는다" % [t, str(_rect(c)), str(r)])
			var ys := _yellow(pm)
			check_eq(ys.size(), 0 if step == "pick" else 1, "%s: 노랑 채움 %s" % [t, str(ys)])
		await kit.press_key(KEY_ESCAPE)


## 누를 것(캠프의 visible_buttons: 창이 떠 있으면 창 단추 + 키패드)은 64 이상·화면 안. 수량 창이 떠 있으면 그 창 단추도.
func _targets(pm: PartyMenu, size: Vector2, tag: String) -> void:
	var bs: Array = pm.visible_buttons()
	var it := pm.items_tab
	if it.qty_open():
		bs = bs.filter(func(b: TouchButton) -> bool: return b.get_parent() is VirtualPad or it.qty.is_ancestor_of(b))
		check(bs.any(func(b: TouchButton) -> bool: return it.qty.is_ancestor_of(b)), tag + ": 수량 창 단추가 있다")
	check(not bs.is_empty(), tag + ": 누를 것이 있다")
	var screen := Rect2(Vector2.ZERO, size)
	for b in bs:
		check((b as Control).size.x >= 64.0 and (b as Control).size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str((b as Control).size)])
		check(screen.encloses(_rect(b).grow(-0.5)), "%s: %s %s 가 화면 안" % [tag, b.name, str(_rect(b))])
