## 공용 목록 부품 시험(D28-a): InventoryList·InventoryLook·BagRows 를 화면 없이 한 번 확인한다. 최소 주인 = 시험 뿌리 아래
## ListWindow(캠프 틀, 줄 넷이 보이는 높이) 하나와 그 목록에 묶인 InventoryList. 실제 입력 경로로 누르고 끈다. 저장은 쓰지 않는다.
## 확인: 돌지 않는 ↑↓, 끝에서 가려진 커서 되돌림(한 번), 크기가 바뀔 때 한 번 되돌림·보통 다시 그리기는 손으로 내린 자리를 지킴,
## 누르기 대 끌기, 새 줄·문맥이 바뀌면 눌림 버림, 묶음 되돌림, 「선택」 막기(키패드 = 키), 노랑 하나와 커서 모양, 설명 연결 횟수,
## 줄 단추 이름·차례, 가방 줄 차례와 장비 후보 차례(지금 규칙과 같은 결과).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")

## 커서 모양을 적어 두는 모양(cursor·chosen 을 따로 본다).
class ModeLook extends InventoryLook:
	func mark(r: PartyButton, at: bool, mode: String) -> void:
		r.selected = at and mode == "cursor"
		r.set_meta("chosen", at and mode == "chosen")


var kit: Kit
var host: Control
var window: ListWindow
var inv: InventoryList
var routed: Array = []
var told := [0]


func teardown() -> void:
	if inv != null:
		# 갈고리 람다가 이 시험을 붙잡는다(시험 → inv → 람다 → 시험): 끊는다.
		for sig in [inv.changed, inv.picked]:
			for c in (sig as Signal).get_connections():
				(sig as Signal).disconnect(c["callable"])
		inv.route = Callable()
		inv.stops_hook = Callable()
		inv.group_top_hook = Callable()
		inv.confirmable = Callable()
		inv = null
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		Input.flush_buffered_events()
		kit = null


## 줄 visible 개가 다 보이는 창 하나와 그 목록(캠프 모양, Row_k).
func _host(visible_rows: int = 4, look: InventoryLook = null) -> void:
	timeout_sec = 30.0
	kit = Kit.new(tree)
	host = Control.new()
	host.name = "InvHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(host)
	window = ListWindow.new()
	window.name = "InvWindow"
	host.add_child(window)
	window.position = Vector2(100, 40)
	window.size = Vector2(507, ListParts.list_height(visible_rows))
	inv = InventoryList.new(window.list, look if look != null else InventoryLook.new())
	routed = []
	told[0] = 0
	inv.changed.connect(func() -> void: told[0] += 1)
	await kit.frames(2)


func _models(n: int, tag: String = "줄") -> Array:
	var out := []
	for i in n:
		out.append({"icon": "kind_sword", "name": "%s %d" % [tag, i], "right": "%d개" % (i + 1), "id": "%s.%d" % [tag, i]})
	return out


func _selected() -> Array:
	var out := []
	for k in inv.used:
		if inv.rows[k].selected:
			out.append(k)
	return out


func test_move_does_not_wrap_and_stops_at_the_ends() -> void:
	await _host()
	inv.set_rows(_models(10))
	check_eq(inv.cursor, 0, "처음 커서")
	check(not inv.move(-1), "첫 줄에서 ↑ = 아무 일 없음(돌지 않음)")
	check_eq(inv.cursor, 0, "첫 줄 그대로")
	for i in 9:
		check(inv.move(1), "↓ %d" % i)
	check_eq(inv.cursor, 9, "끝 줄")
	check(inv.shown_at(9), "끝 줄이 보이게 내렸다")
	check(not inv.move(1), "끝 줄에서 ↓ = 아무 일 없음(돌지 않음)")
	check_eq([inv.cursor, _selected()], [9, [9]], "커서·노랑 그대로")


func test_end_key_reveals_a_hidden_cursor_once() -> void:
	await _host()
	inv.set_rows(_models(10))
	inv.set_cursor(9)
	window.list.scroll_to(0.0)
	check(not inv.shown_at(9), "준비: 손으로 올려 끝 커서가 가려졌다")
	check(inv.move(1), "가려진 끝 커서: ↓ = 되돌림(입력 하나)")
	check_eq([inv.cursor, inv.shown_at(9)], [9, true], "커서는 그대로, 보인다")
	check(not inv.move(1), "다 보이면 ↓ 는 아무 일 없음")
	inv.set_cursor(0)
	window.list.scroll_to(window.list.max_scroll())
	check(not inv.shown_at(0), "준비: 첫 줄 커서가 가려졌다")
	check(inv.move(-1), "가려진 첫 줄 커서: ↑ = 되돌림")
	check_eq([inv.cursor, inv.shown_at(0)], [0, true], "첫 줄 커서가 보인다")
	check(not inv.move(-1), "다시 ↑ 는 아무 일 없음")


func test_resize_reveals_once_and_refresh_keeps_a_manual_scroll() -> void:
	await _host(6)
	var models := _models(10)
	var calls := [0]
	inv.watch_resize(func() -> void:
		calls[0] += 1
		inv.set_rows(models))
	inv.set_rows(models)
	for i in 9:
		inv.move(1)
	check(inv.shown_at(9), "준비: 높은 창에서 끝 줄 커서가 보인다")
	var before: int = calls[0]
	window.size = Vector2(507, ListParts.list_height(4))
	await kit.frames(2)
	check_eq(calls[0], before + 1, "실제 크기 바뀜 = 다시 그리기 한 번")
	check(inv.shown_at(9), "낮은 창이 되어도 커서 줄이 다 보인다(한 번 되돌림)")
	window.list.scroll_to(0.0)
	inv.set_rows(models)
	check_eq(window.list.scroll, 0.0, "같은 줄 다시 놓기: 손으로 내린 자리 그대로")
	inv.set_rows(_models(10, "새"))
	check_eq(window.list.scroll, 0.0, "새 줄 놓기도 손으로 내린 자리 그대로(되돌림은 크기가 바뀐 뒤 한 번만)")
	window.size = Vector2(507, ListParts.list_height(4))
	await kit.frames(2)
	check_eq([calls[0], window.list.scroll], [before + 1, 0.0], "같은 크기 = 다시 그리기·되돌림 없음")


func test_tap_routes_once_and_a_drag_only_scrolls() -> void:
	await _host()
	inv.set_rows(_models(10))
	inv.route = func(k: int) -> void: routed.append(k)
	await kit.tap(kit.center_of(inv.rows[2]))
	check_eq([routed, inv.cursor], [[2], 0], "route 가 있으면 누르기는 route(2) 하나만(커서는 화면이 옮긴다)")
	inv.route = Callable()
	var picks := []
	inv.picked.connect(func(i: int) -> void: picks.append(i))
	await kit.tap(kit.center_of(inv.rows[1]))
	check_eq([picks, inv.cursor, _selected()], [[1], 1, [1]], "route 가 없으면 커서가 그 줄로·picked 한 번")
	inv.route = func(k: int) -> void: routed.append(k)
	routed.clear()
	# 올렸다가 제자리로 끈다(창 좌표 → 그림 좌표 비율로 30px): 뗄 때 손가락이 그 줄 안이라 끌기가 누르기로 새면 잡힌다.
	window.list.scroll_to(100.0)
	var row := inv.rows[3]
	var p := kit.center_of(row)
	var d := (kit.at(row, Vector2(0, 30)) - kit.at(row, Vector2.ZERO)).y
	kit.touch(0, p, true)
	await kit.frames(1)
	kit.drag(0, p, p - Vector2(0, d))
	await kit.frames(1)
	var mid := window.list.scroll
	kit.drag(0, p - Vector2(0, d), p)
	await kit.frames(1)
	# 끌기 문턱(12px)까지는 내리지 않아 돌아온 자리가 조금 다르다: 줄 높이 절반보다 덜 움직였으면 뗄 자리는 그 줄 안이다.
	check(absf(window.list.scroll - 100.0) < ListParts.ROW_H / 2.0, "준비: 뗄 자리가 그 줄 안이다(내림 %s)" % window.list.scroll)
	kit.touch(0, p, false)
	await kit.frames(3)
	check_eq([routed, inv.cursor], [[], 1], "줄 위 끌기(뗄 때 줄 안): 누르기가 아니다")
	check(mid > 100.0, "끌기는 목록을 내렸다(%s)" % mid)


func test_new_rows_and_a_context_change_drop_a_held_press() -> void:
	await _host()
	var models := _models(6)
	inv.set_rows(models)
	inv.route = func(k: int) -> void: routed.append(k)
	var p := kit.center_of(inv.rows[1])
	kit.touch(0, p, true)
	await kit.frames(1)
	inv.set_rows(_models(6, "새"))
	kit.touch(0, p, false)
	await kit.frames(3)
	check_eq(routed, [], "새 줄이 놓이면 눌려 있던 줄은 뗄 때 아무 일 없음")
	kit.touch(0, p, true)
	await kit.frames(1)
	inv.set_rows(_models(6, "새"))
	kit.touch(0, p, false)
	await kit.frames(3)
	check_eq(routed, [1], "같은 줄을 다시 놓으면 눌림이 남는다(뗄 때 한 번)")
	routed.clear()
	kit.touch(0, p, true)
	await kit.frames(1)
	inv.cancel()
	kit.touch(0, p, false)
	await kit.frames(3)
	check_eq(routed, [], "문맥이 바뀌면(cancel) 뗄 때 아무 일 없음")


## 줄 0~5(누름) · 6 머리 줄(읽기만) · 7 줄 단추 없는 자리에 화면 단추 하나 · 8~10 읽기만(머리 줄 위로 내릴 수 있게).
## 단추의 묶음은 머리 줄부터.
func _group_host() -> PartyButton:
	await _host()
	var b := PartyButton.new()
	b.name = "Extra"
	b.scroller = window.list
	window.list.content.add_child(b)
	var lines := _models(6)
	lines.append({"name": "머리", "press": false})
	lines.append({"row": false})
	for k in 3:
		lines.append({"name": "끝 %d" % k, "press": false})
	b.position = Vector2(0, inv.line_y(7))
	b.size = Vector2(200, ListParts.ROW_H)
	inv.stops_hook = func() -> Array[Control]:
		var out: Array[Control] = []
		for k in 6:
			out.append(inv.rows[k])
		out.append(b)
		return out
	inv.group_top_hook = func(c: Control) -> float: return inv.line_y(6) if c == b else c.position.y
	inv.set_rows(lines)
	return b


func test_group_top_reveals_the_head_row_with_its_button() -> void:
	var b := await _group_host()
	inv.set_cursor(6)
	check(inv.cursor_stop() == b and b.selected, "준비: 커서는 화면 단추(칸 6), 노랑")
	check(window.list.shows(Rect2(0, inv.line_y(6), 1, ListParts.ROW_H)), "커서로 가면 머리 줄까지 보인다")
	window.list.scroll_to(inv.line_y(6) + 10.0)
	check(window.list.shows(b.get_rect()), "준비: 단추는 보이고")
	check(not inv.shown(b), "머리 줄이 가려지면 묶음은 가려진 것으로 친다")
	check(inv.move(1), "끝 키: 가려진 묶음을 되돌림")
	check(inv.shown(b) and window.list.scroll <= inv.line_y(6), "머리 줄까지 보인다")
	window.list.scroll_to(inv.line_y(6) + 10.0)
	var pressed := []
	check(inv.confirm(func(c: Control) -> bool:
		pressed.append(c)
		return true), "「선택」")
	check_eq(pressed, [b], "누른 것은 커서 단추")
	check(window.list.scroll <= inv.line_y(6), "누르기 전에 머리 줄까지 보이게 했다")
	check(not inv.rows[6].selected and inv.rows[6].mouse_filter == Control.MOUSE_FILTER_IGNORE, "머리 줄은 읽기만·노랑 아님")


func test_confirm_guard_matches_the_keypad() -> void:
	await _host()
	inv.set_rows(_models(10))
	inv.set_cursor(9)
	window.list.scroll_to(0.0)
	inv.confirmable = func(_c: Control) -> bool: return false
	var pressed := []
	var press := func(c: Control) -> bool:
		pressed.append(c)
		return true
	check(not inv.can_confirm(), "할 일 없는 칸: 키패드 「선택」 흐림")
	check(not inv.confirm(press), "Enter 도 받지 않는다(키패드 = 키)")
	check_eq([pressed, inv.cursor, window.list.scroll], [[], 9, 0.0], "아무것도 바꾸지 않는다(가려진 커서도 되돌리지 않음)")
	inv.confirmable = Callable()
	check(inv.can_confirm(), "할 일 있는 칸: 켜짐")
	check(inv.confirm(press), "Enter = 누르기")
	check_eq(pressed, [inv.rows[9]], "커서 칸을 한 번 누름")
	check(inv.shown_at(9), "누르기 전에 커서 칸을 보이게")
	var ro := _models(3)
	for m in ro:
		m["press"] = false
	inv.set_rows(ro)
	check_eq([inv.cursor, inv.can_move(), inv.can_confirm(), _selected()], [-1, false, false, []], "칸이 없으면 커서 없음·↑↓ 흐림·노랑 없음")
	check(not inv.move(1) and not inv.confirm(press), "↑↓·Enter 모두 받지 않는다")


func test_one_cursor_mark_and_cursor_modes() -> void:
	await _host(4, ModeLook.new())
	var lines := _models(5)
	lines[2]["dim"] = true
	inv.set_rows(lines)
	inv.set_cursor(2)
	check_eq(_selected(), [2], "노랑(커서 모양) 하나, 흐린 줄에도 선다")
	check(inv.rows[2].dimmed and inv.rows[2].selected, "흐린 커서 모양 = 흐림 + selected(그림은 ListParts.draw_row)")
	inv.set_cursor_mode("chosen")
	check_eq([_selected(), inv.rows[2].get_meta("chosen"), inv.rows[1].get_meta("chosen")], [[], true, false], "chosen: 노랑 없음, 그 줄만 chosen")
	inv.set_cursor_mode("none")
	check_eq([_selected(), inv.rows[2].get_meta("chosen")], [[], false], "none: 표시 없음")
	check_eq(inv.cursor, 2, "모양만 바뀌고 커서 자리는 그대로")
	inv.set_cursor_mode("cursor")
	check_eq(_selected(), [2], "cursor 로 돌아옴")


func test_description_link_fires_once_per_change() -> void:
	await _host()
	inv.set_rows(_models(6))
	check_eq(told[0], 1, "처음 줄 놓기 = 한 번")
	inv.set_rows(_models(6))
	check_eq(told[0], 1, "같은 줄 다시 놓기 = 없음")
	inv.move(1)
	check_eq(told[0], 2, "커서 한 칸 = 한 번")
	inv.set_rows(_models(6))
	check_eq(told[0], 2, "↑↓ 뒤 같은 줄 다시 놓기 = 없음")
	inv.set_cursor(1)
	inv.point(inv.rows[1])
	check_eq(told[0], 2, "같은 칸으로 다시 옮기기 = 없음")
	inv.set_cursor(5)
	window.list.scroll_to(0.0)
	inv.move(1)
	check_eq(told[0], 3, "끝 키의 되돌림은 커서가 그대로라 없음(옮긴 set_cursor 하나만)")
	var changed := _models(6)
	changed[3]["right"] = "99개"
	inv.set_rows(changed)
	check_eq(told[0], 4, "줄 하나가 바뀌어도 한 번")
	inv.set_rows(_models(4))
	check_eq([told[0], inv.cursor], [5, 3], "줄 수가 줄어 커서가 맞춰져도 한 번")


func test_pool_names_order_and_hide() -> void:
	await _host()
	var first := Control.new()
	first.name = "Before"
	window.list.content.add_child(first)
	var behind := InventoryList.new(window.list, InventoryLook.new(), "Item_")
	behind.behind = true
	behind.set_rows(_models(3))
	var names := []
	for c in window.list.content.get_children():
		names.append(str(c.name))
	check_eq(names, ["Item_2", "Item_1", "Item_0", "Before"], "behind: 새 줄은 내용 맨 앞(화면 단추 뒤에 그림), 이름 = prefix + 번호")
	inv.ensure(2)
	check_eq([inv.rows.size(), inv.rows[0].name, inv.rows[0].visible], [2, &"Row_0", false], "ensure: 미리 만든 줄은 감춰 둔다")
	inv.set_rows(_models(2))
	check(inv.rows[0].visible and inv.rows[0].selected, "set_rows 가 보이고 커서를 켠다")
	inv.route = func(k: int) -> void: routed.append(k)
	var p := kit.center_of(inv.rows[0])
	kit.touch(0, p, true)
	await kit.frames(1)
	inv.hide()
	check(not inv.rows[0].visible and not inv.rows[0].selected and not inv.rows[0].held, "hide: 감추고 노랑·눌림을 지운다")
	kit.touch(0, p, false)
	await kit.frames(2)
	check_eq(routed, [], "감춘 줄은 뗄 때 아무 일 없음")
	inv.set_rows(_models(2))
	check_eq(told[0], 2, "hide 뒤 다시 놓으면 새 줄로 친다(설명 연결)")
	check_eq([inv.used, inv.rows[0].visible, inv.rows[1].visible], [2, true, true], "hide 뒤 같은 줄을 다시 놓아도 두 줄이 다시 보인다")
	check_eq(_selected(), [inv.cursor], "노랑은 커서 줄 하나")
	await kit.tap(kit.center_of(inv.rows[1]))
	check_eq(routed, [1], "다시 보인 줄을 누르면 그 줄로 간다")


func test_reserved_room_keeps_its_width_across_a_resize() -> void:
	await _host()
	var models := [{"name": "보급 줄", "right": "3개", "press": false, "room": 104.0}, {"name": "온 줄", "right": "1개"}]
	var calls := [0]
	inv.watch_resize(func() -> void:
		calls[0] += 1
		inv.set_rows(models))
	inv.set_rows(models)
	var w := window.list.size.x
	check_eq([inv.rows[0].size.x, inv.rows[1].size.x], [w - 104.0, w], "room 104: 오른쪽 104 를 비운다, 없으면 목록 폭 전체")
	window.size = Vector2(707, window.size.y)
	await kit.frames(2)
	var w2 := window.list.size.x
	check(w2 > w + 100.0 and calls[0] >= 1, "준비: 실제로 넓어졌다(%s → %s)" % [w, w2])
	check_eq([inv.rows[0].size.x, inv.rows[1].size.x], [w2 - 104.0, w2], "같은 줄 모델로 넓어져도 비운 폭은 104 그대로")


func test_bag_rows_order_and_kinds() -> void:
	var s := ExplorationRules.new_game(Fx.defs(), 1, "floor")
	var ids := s.defs.battle.equipment_ids
	s.gear_bag.clear()
	for i in ids.size():
		s.gear_bag[ids[i]] = i % 3  # 0 개는 빠진다
	var mats: Array = s.defs.battle.materials.keys()
	s.materials.clear()
	for i in mats.size():
		s.materials[mats[i]] = (i + 1) % 4
	var want_gear := []
	for i in ids.size():
		if i % 3 >= 1:
			want_gear.append(ids[i])
	var want_mat_data := []
	for i in mats.size():
		if (i + 1) % 4 >= 1:
			want_mat_data.append(mats[i])
	var want_mat_id := want_mat_data.duplicate()
	want_mat_id.sort()
	check(want_mat_id != want_mat_data, "준비: 자료 차례와 ID 차례가 다르다")
	var got := BagRows.bag(s)
	check_eq(got.map(func(l: Dictionary) -> String: return l["item"]), want_gear + want_mat_id, "기본: 장비(자료 차례) → 소재(ID 차례), 0 개 빠짐")
	check_eq(BagRows.bag(s, ["material"], "data").map(func(l: Dictionary) -> String: return l["item"]), want_mat_data, "소재 자료 차례(상점 판매)")
	check_eq(BagRows.bag(s, ["gear"]).map(func(l: Dictionary) -> String: return l["item"]), want_gear, "장비만")
	var g: Dictionary = got[0]
	check_eq([g["count"], g["kind"], g["icon"]], [s.gear_bag[g["item"]], s.defs.battle.equip(g["item"]).kind, SheetParts.kind_icon(s.defs, g["item"])],
		"장비 줄: 개수·종류·아이콘")
	var m: Dictionary = got[want_gear.size()]
	check_eq([m["count"], m["kind"], m["icon"]], [s.materials[m["item"]], "material", "kind_material"], "소재 줄: 개수·종류·아이콘(상점과 같은 글)")


## 옛 장비 화면의 목록 만들기(D28 전 PartyEquipTab._build_rows)를 그대로 옮긴 기대값.
static func _old_rows(s: ExplorationState, i: int, slot: int) -> Dictionary:
	var defs := s.defs
	var m: PartyState.Member = s.party.members[i]
	var bag := s.gear_bag
	var items: Array[String] = []
	var block: Array[String] = []
	var eq := -1
	var cur: String = m.equip[slot]
	if not cur.is_empty():
		eq = 0
		items.append(cur)
		block.append("")
	var di: Array[String] = []
	var dw: Array[String] = []
	for id in defs.battle.equipment_ids:
		if int(bag.get(id, 0)) < 1:
			continue
		if GrowthRules.slot_block(defs.battle, defs.class_of(i), m.equip, slot, id) == "slot_kind":
			continue
		var why := GrowthRules.equip_block(defs, i, m, bag, slot, id)
		if why.is_empty():
			items.append(id)
			block.append("")
		else:
			di.append(id)
			dw.append(why)
	items.append_array(di)
	block.append_array(dw)
	items.append("")
	block.append(GrowthRules.equip_block(defs, i, m, bag, slot, ""))
	return {"items": items, "block": block, "equipped": eq}


func test_for_slot_keeps_the_equip_list_order() -> void:
	var s := ExplorationRules.new_game(Fx.defs(), 1, "floor")
	var ids := s.defs.battle.equipment_ids
	for i in ids.size():
		s.gear_bag[ids[i]] = (i % 3)
	var cases := 0
	var dims := 0
	for i in s.party.members.size():
		for slot in BattleLimits.EQUIP_SLOTS:
			var got := BagRows.for_slot(s, i, slot)
			check_eq(got, _old_rows(s, i, slot), "대원 %d 칸 %d" % [i, slot])
			var items: Array = got["items"]
			check_eq(items[items.size() - 1], "", "「빼기」는 맨 끝")
			for j in items.size() - 1:
				if j == got["equipped"]:
					continue
				var id: String = items[j]
				check(GrowthRules.slot_block(s.defs.battle, s.defs.class_of(i), s.party.members[i].equip, slot, id) != "slot_kind", "칸 종류가 같다")
				if not (got["block"][j] as String).is_empty():
					dims += 1
					check(j == items.size() - 2 or not (got["block"][j + 1] as String).is_empty(), "못 끼는 줄은 낄 수 있는 줄 뒤")
			cases += 1
	check(cases >= 20 and dims >= 1, "준비: 대원·칸 %d 경우, 못 끼는 줄 %d" % [cases, dims])
