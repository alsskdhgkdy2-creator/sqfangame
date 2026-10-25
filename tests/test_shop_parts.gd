## 상점 S2 부품 시험(08 §7.7): 종류 아이콘 10개, 탭(고르기·checked·cancel·뗄 때 한 번), 칸 목록(줄 수와 빈 칸 수, 커서를 맞추면
## 화면 안, 흐림·고름, 끌기는 고르기가 아님, 64px·글자 잘림), 상점 창(수량 1~최대에서 멈춤·±1·±10, 예·아니오 신호, 알림 줄 넘침),
## 1280×720·1728×720(창 2400×1000)에서 화면 안·캐릭터 판과 겹치지 않음. 실제 입력 경로로 누른다. 저장은 쓰지 않는다.
## 진열은 새 게임 상태 + 판 소재(규칙 함수 ShopRules.sell)로 만든 실데이터다(D15 구성).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const JUNK := "shop.junk_workshop"
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]

var kit: Kit
var host: Control
var texts: TextDb
var frame: ShopFrame
var tabs: ShopTabs
var list: ShopList
var dialog: ShopDialog
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		Input.flush_buffered_events()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _kit() -> void:
	timeout_sec = 40.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")


## 실제 창 크기를 바꾸고 논리 크기를 돌려준다(2400×1000 → 1728×720).
func _window(px: Vector2) -> Vector2:
	_kit()
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 상점 구매 화면 짜임(08 §7.1 층 표): 장식(ShopFrame, left = PAD_SIDE) · 목록 · 탭 줄 · 상점 창(맨 뒤).
## set_name 이 ""이면 탭 줄 없이 목록 창 위 끝 172(캠프와 같다).
func _compose(set_name: String, px: Vector2 = WINDOWS[0]) -> Vector2:
	var size: Vector2 = await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "ShopHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree.root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame = ShopFrame.new()
	frame.name = "ShopFrame"
	host.add_child(frame)
	frame.build("Shop", texts.t("camp.back"), true, ShopFrame.PAD_SIDE, ShopFrame.TABS_LIST_TOP if not set_name.is_empty() else ShopFrame.LIST_TOP)
	frame.show_title(texts.t("shop.money", {"money": ShopRow.grouped(1480)}), true)
	list = ShopList.new()
	list.name = "ShopList"
	list.new_text = texts.t("shop.new")
	host.add_child(list)
	var la: Array = frame.list_anchor()
	PartyMenu.place(list, la[0], la[1], la[2])
	tabs = ShopTabs.new()
	tabs.name = "ShopTabs"
	host.add_child(tabs)
	if not set_name.is_empty():
		tabs.setup(set_name, texts.t("shop.tab.all"))
		tabs.position = Vector2(frame.left, ShopTabs.TOP)
	tabs.visible = not set_name.is_empty()
	dialog = ShopDialog.new()
	dialog.name = "ShopDialog"
	host.add_child(dialog)
	dialog.setup(texts)
	await kit.frames(2)
	dialog.set_area(frame.list_window_rect())
	return size


func _rect(c: Control) -> Rect2:
	return Rect2(c.get_global_position() - host.get_global_position(), c.size)


## 새 게임 + 소재를 팔아 풀린 줄·NEW·한정 품절 줄이 있는 상태, 소지금은 일부 줄이 흐리게(300: 이온 세이버 360 이 흐림).
func _shop_state() -> ExplorationState:
	var s := ExplorationRules.new_game(Fx.defs(), 3, "floor")
	s.materials = {"item.cable_scale": 3, "item.glow_scale": 1, "item.beetle_plate": 2, "item.intact_pincer": 1, "item.drill_claw": 5,
		"item.neon_rat_tail": 7}
	var ev := ShopRules.sell(s, JUNK, [{"item": "item.cable_scale", "qty": 3}, {"item": "item.glow_scale", "qty": 1},
		{"item": "item.beetle_plate", "qty": 2}, {"item": "item.intact_pincer", "qty": 1}])
	check(ev.size() == 2 and ev[1]["type"] == "unlocked", "준비: 팔아서 풀림 %s" % str(ev))
	# 이지스 플레이트(한정)를 하나 사서 재고 0, 훈련용 홀로 블레이드를 사서 NEW 아님.
	s.money = 2000
	check(ShopRules.buy(s, JUNK, "equip.aegis_plate", 1)[0]["type"] == "bought", "준비: 한정 줄 사기")
	check(ShopRules.buy(s, JUNK, "equip.training_sword", 1)[0]["type"] == "bought", "준비: 사기")
	s.money = 300
	return s


## 구매 줄(갈래·탭 종류로 거른 진열, ALL 은 탭 차례로 묶고 묶음 안은 진열 차례).
func _buy_rows(s: ExplorationState, set_name: String, kind: String) -> Array:
	var cat := ShopRules.catalog(s.defs, s, JUNK)
	var order: Array = ShopTabs.SETS[set_name].slice(1)
	var out := []
	for k in order:
		if kind != "all" and k != kind:
			continue
		for line in cat:
			var e := s.defs.battle.equip(line["item"])
			if e.kind != k:
				continue
			var sold_out: bool = line["limited"] and int(line["stock"]) < 1
			out.append({"icon": ShopTabs.ICONS[e.kind], "name": texts.t(e.name_key), "new": line["new"],
				"right": texts.t("shop.sold_out") if sold_out else ShopRow.grouped(line["price"]), "count": "",
				"dim": sold_out or not line["affordable"], "checked": false})
	return out


func _sell_rows(s: ExplorationState) -> Array:
	var out := []
	var ids: Array = s.materials.keys()
	ids.sort()
	for id in ids:
		out.append({"icon": "kind_material", "name": texts.t(str(id)), "new": false, "right": ShopRow.grouped(ShopRules.sell_price(s.defs, str(id))),
			"count": texts.t("party.count", {"n": int(s.materials[id])}), "dim": false, "checked": false})
	return out


func _many_rows(n: int) -> Array:
	var out := []
	for i in n:
		out.append({"icon": "kind_sword", "name": "줄 %d" % i, "new": i % 3 == 0, "right": str(10 * i), "count": "", "dim": false, "checked": false})
	return out


# ---- 아이콘 ----

func test_ten_kind_icons_are_drawn_inside_and_tell_apart() -> void:
	check_eq(VectorIcons.KIND_ICONS.size(), 10, "종류 아이콘 10개")
	for side in [28.0, 40.0]:
		var rect := Rect2(Vector2(5, 7), Vector2(side, side))
		var sigs := {}
		for n in VectorIcons.KIND_ICONS:
			var shapes := VectorIcons.kind_shapes(n, rect)
			check(not shapes.is_empty(), "%s %dpx: 도형이 있다" % [n, side])
			var sig := []
			for sh in shapes:
				var b := _bounds(sh)
				check(rect.grow(side * 0.1).encloses(b), "%s %dpx: %s %s 가 아이콘 칸 안" % [n, side, sh["type"], str(b)])
				var nb := Rect2((b.position - rect.position) / side, b.size / side)
				var pts: int = (sh["points"] as PackedVector2Array).size() if sh["type"] == "poly" else 0
				sig.append("%s%d:%s:%s" % [sh["type"], pts, str(nb.position.snapped(Vector2(0.05, 0.05))), str(nb.size.snapped(Vector2(0.05, 0.05)))])
			var key := ",".join(sig)
			check(not sigs.has(key), "%s %dpx: %s 와 모양이 같다" % [n, side, sigs.get(key, "")])
			sigs[key] = n
	check(VectorIcons.kind_shapes("kind_nothing", Rect2(0, 0, 40, 40)).is_empty(), "모르는 이름은 도형 없음")
	# 실제로 그려 본다(실행 오류 없음): 탭 줄의 아이콘 칸.
	await _compose("armor")
	for set_name in ShopTabs.SETS:
		tabs.setup(set_name, texts.t("shop.tab.all"))
		await kit.frames(1)
	list.set_rows(VectorIcons.KIND_ICONS.map(func(n: String) -> Dictionary: return {"icon": n, "name": n, "right": "1"}))
	await kit.frames(2)
	check_eq(list.row_count, 10, "아이콘 줄 10")


func _bounds(sh: Dictionary) -> Rect2:
	match str(sh["type"]):
		"poly":
			var pts: PackedVector2Array = sh["points"]
			var r := Rect2(pts[0], Vector2.ZERO)
			for q in pts:
				r = r.expand(q)
			return r
		"line":
			return Rect2(sh["from"], Vector2.ZERO).expand(sh["to"]).grow(float(sh["width"]) / 2.0)
		"circle":
			return Rect2(sh["center"] - Vector2.ONE * float(sh["radius"]), Vector2.ONE * 2.0 * float(sh["radius"]))
		"arc":
			return Rect2(sh["center"] - Vector2.ONE * float(sh["radius"]), Vector2.ONE * 2.0 * float(sh["radius"])).grow(float(sh["width"]) / 2.0)
		"rect":
			return sh["rect"]
	return Rect2()


# ---- 탭 ----

func test_tabs_pick_on_release_mark_checked_and_cancel() -> void:
	await _compose("weapon")
	var got: Array[int] = []
	tabs.picked.connect(func(i: int) -> void: got.append(i))
	check_eq(tabs.kinds, ["all", "sword", "staff"] as Array[String], "무기: 전체 · 검 · 지팡이")
	check_eq([tabs.buttons[0].text, tabs.buttons[0].icon], [texts.t("shop.tab.all"), ""], "「전체」는 글자")
	check_eq([tabs.buttons[1].text, tabs.buttons[1].icon, tabs.buttons[2].icon], ["", "kind_sword", "kind_staff"], "나머지는 아이콘")
	for i in tabs.buttons.size():
		var b := tabs.buttons[i]
		check_eq(_rect(b), Rect2(ShopFrame.PAD_SIDE + i * 68.0, 166, 64, 64), "탭 %d 자리 64×64 사이 4" % i)
		check_eq(b.focus_mode, Control.FOCUS_NONE, "탭 %d 포커스 없음" % i)
	check_eq(tabs.buttons.map(func(b: TouchButton) -> bool: return b.checked), [true, false, false], "처음은 「전체」 checked")
	# 누르기만으로는 고르지 않는다(뗄 때 한 번).
	var c2 := kit.center_of(tabs.buttons[2])
	kit.touch(0, c2, true)
	await kit.frames(1)
	check(got.is_empty() and tabs.buttons[2].held, "누른 동안은 신호 없음")
	kit.touch(0, c2, false)
	await kit.frames(2)
	check_eq(got, [2] as Array[int], "뗄 때 picked(2) 한 번")
	check_eq([tabs.current, tabs.kind()], [2, "staff"], "고른 칸 = 지팡이")
	check_eq(tabs.buttons.map(func(b: TouchButton) -> bool: return b.checked), [false, false, true], "고른 칸만 checked")
	for b in tabs.buttons:
		check(not b.selected, "%s: 탭에는 노랑 커서가 없다" % b.name)
		check(not b.theme_state().contains("selected"), "%s: 모양 %s" % [b.name, b.theme_state()])
	check_eq(tabs.buttons[2].theme_state(), "checked", "고른 탭 = 하늘색 checked")
	check_eq(tabs.buttons[0].theme_state(), "shoptab:normal", "나머지 = 어두운 남색")
	# 누른 채 문맥이 바뀌면(cancel) 뗄 때 아무 일도 없다.
	var c1 := kit.center_of(tabs.buttons[1])
	kit.touch(0, c1, true)
	await kit.frames(1)
	tabs.cancel()
	kit.touch(0, c1, false)
	await kit.frames(2)
	check_eq(got, [2] as Array[int], "cancel 뒤 떼도 신호 없음")
	check_eq(tabs.current, 2, "cancel 뒤 고른 칸 그대로")
	# 누른 채 밖으로 끌어 떼면 고르지 않는다(손가락 소유).
	kit.touch(0, c1, true)
	kit.drag(0, c1, c1 + Vector2(0, 200))
	kit.touch(0, c1 + Vector2(0, 200), false)
	await kit.frames(2)
	check_eq(got, [2] as Array[int], "칸 밖에서 떼면 신호 없음")
	# 갈래마다 차례 표.
	tabs.setup("armor", texts.t("shop.tab.all"))
	check_eq(tabs.kinds, ["all", "body", "shield", "head", "hands", "feet"] as Array[String], "방어구: 전체 · 몸 · 방패 · 머리 · 손 · 다리")
	tabs.setup("sell", texts.t("shop.tab.all"))
	check_eq(tabs.kinds, ["material", "gear", "consumable"] as Array[String], "판매: 소재 · 장비 · 소모품(전체 없음)")
	check(tabs.buttons.all(func(b: TouchButton) -> bool: return b.text.is_empty() and not b.icon.is_empty()), "판매 탭은 모두 아이콘")
	await kit.frames(1)
	check_eq([tabs.current, tabs.buttons[0].checked], [0, true], "다시 짜면 첫 칸")
	await kit.tap(kit.center_of(tabs.buttons[1]))
	check_eq(got, [2, 1] as Array[int], "판매 「장비」 탭")


# ---- 목록 ----

func test_list_fills_the_window_with_rows_and_empty_slots() -> void:
	for set_name in ["armor", ""]:
		await _compose(set_name)
		var lw := frame.list_window_rect()
		check_eq(lw.position.y, 236.0 if not set_name.is_empty() else 172.0, "%s: 목록 창 위 끝" % set_name)
		var slots := list.visible_slots()
		check(slots * ShopList.PITCH - ShopList.ROW_GAP <= list.scroll.size.y, "%s: %d 칸이 다 보인다" % [set_name, slots])
		check((slots + 1) * ShopList.PITCH - ShopList.ROW_GAP > list.scroll.size.y, "%s: %d 칸이 보이는 전부" % [set_name, slots])
		check(_rect(list).grow(0.5).position.y >= lw.position.y and lw.encloses(_rect(list)), "%s: 목록이 목록 창 안" % set_name)
		for n in [0, 2, slots, slots + 5]:
			list.set_rows(_many_rows(n))
			await kit.frames(1)
			check_eq(list.empty_count(), maxi(0, slots - n), "%s: 줄 %d → 빈 칸" % [set_name, n])
			var shown := 0
			for r in list.rows:
				shown += 1 if r.visible else 0
			check_eq(shown, n, "%s: 보이는 줄 %d" % [set_name, n])
			var bar := list.scroll_bar_rect()
			check_eq(bar.has_area(), n > slots, "%s: 줄 %d 위치 막대 있음/없음" % [set_name, n])
			if bar.has_area():
				check(Rect2(Vector2.ZERO, list.size).encloses(bar), "%s: 위치 막대가 목록 안 %s" % [set_name, str(bar)])
				check(bar.position.x >= list.row_width(), "%s: 위치 막대는 줄 오른쪽" % set_name)
		# 빈 칸은 누르기를 받지 않는다(장식): 빈 칸 자리를 눌러도 신호 없음.
		list.set_rows(_many_rows(1))
		await kit.frames(1)
		var got: Array[int] = []
		list.picked.connect(func(i: int) -> void: got.append(i))
		var empty_at := kit.at(list.scroll.content, list.slot_rect(slots - 1).get_center())
		await kit.tap(empty_at)
		check(got.is_empty(), "%s: 빈 칸을 눌러도 고르지 않는다" % set_name)


func test_cursor_brings_the_row_into_view_and_only_it_is_yellow() -> void:
	await _compose("weapon")
	list.set_rows(_many_rows(21))
	await kit.frames(1)
	for i in [20, 7, 0, 13]:
		list.set_cursor(i)
		await kit.frames(1)
		check_eq(list.cursor, i, "커서 %d" % i)
		check(list.scroll.shows(list.slot_rect(i)), "커서 %d 줄이 보인다(내림 %.0f)" % [i, list.scroll.scroll])
		var yellow := list.rows.filter(func(r: ShopRow) -> bool: return r.visible and r.selected)
		check(yellow.size() == 1 and yellow[0] == list.rows[i], "노랑은 커서 줄 하나")
	list.set_cursor(99)
	check_eq(list.cursor, 20, "범위 밖은 끝으로")
	list.set_cursor(-3)
	check_eq(list.cursor, 0, "음수는 처음으로")
	list.set_rows(_many_rows(3))
	check_eq(list.cursor, 0, "줄이 줄어도 범위 안")
	list.set_cursor(2)
	list.set_rows(_many_rows(2))
	check_eq(list.cursor, 1, "줄이 줄면 커서도 줄 안으로")


func test_dimmed_and_checked_rows_show_their_state() -> void:
	await _compose("weapon")
	var rows := _many_rows(4)
	rows[1]["dim"] = true
	rows[2]["checked"] = true
	rows[3]["checked"] = true
	list.set_rows(rows)
	list.set_cursor(3)
	await kit.frames(1)
	check_eq(list.rows[0].theme_state(), "cmd:normal", "평소 줄 = 청록")
	check_eq(list.rows[1].theme_state(), "cmd:disabled", "흐린 줄(돈 모자람·품절)")
	check_eq(list.rows[2].theme_state(), "checked", "고른 줄 = 하늘색")
	check_eq(list.rows[3].theme_state(), "cmd:selected", "커서 줄 = 노랑")
	check(list.rows[3].checked, "커서가 와도 고른 줄은 checked(아이콘 칸 테두리)")
	list.set_cursor(1)
	check_eq(list.rows[1].theme_state(), "cmd:disabled_selected", "흐린 줄의 커서")
	# 흐린 줄도 누르기는 받는다(이유는 S3 가 알림 줄에).
	var got: Array[int] = []
	list.picked.connect(func(i: int) -> void: got.append(i))
	list.set_cursor(0)
	await kit.tap(kit.center_of(list.rows[1]))
	check_eq(got, [1] as Array[int], "흐린 줄 누르기 → picked(1)")
	check_eq(list.cursor, 1, "누른 줄로 커서")


func test_dragging_the_list_scrolls_and_never_picks() -> void:
	await _compose("weapon")
	list.set_rows(_many_rows(21))
	await kit.frames(1)
	var got: Array[int] = []
	list.picked.connect(func(i: int) -> void: got.append(i))
	var from := kit.center_of(list.rows[2])
	kit.touch(0, from, true)
	kit.drag(0, from, from - Vector2(0, 150))
	kit.touch(0, from - Vector2(0, 150), false)
	await kit.frames(2)
	check(got.is_empty(), "끌기는 고르기가 아니다")
	check(list.scroll.scroll > 100.0, "끌어서 내렸다(%.0f)" % list.scroll.scroll)
	check_eq(list.cursor, 0, "커서 그대로")
	# 휠도 내린다.
	var before := list.scroll.scroll
	var w := InputEventMouseButton.new()
	w.position = kit.center_of(list.scroll)
	w.button_index = MOUSE_BUTTON_WHEEL_DOWN
	w.pressed = true
	Input.parse_input_event(w)
	Input.flush_buffered_events()
	await kit.frames(2)
	check(list.scroll.scroll > before, "휠로 내린다")
	# 누른 채 cancel → 떼도 아무 일 없음.
	var r := list.rows.filter(func(x: ShopRow) -> bool: return list.scroll.shows(Rect2(x.position, x.size)))[0] as ShopRow
	var at := kit.center_of(r)
	kit.touch(0, at, true)
	await kit.frames(1)
	list.cancel()
	kit.touch(0, at, false)
	await kit.frames(2)
	check(got.is_empty(), "cancel 뒤 떼도 고르지 않는다")
	await kit.tap(at)
	check_eq(got, [list.rows.find(r)] as Array[int], "그 줄 누르기 → picked")


## 실데이터 줄(구매 무기·방어구, 판매 소재)이 64 이상이고 글자가 잘리지 않는다. 1280·1728.
func test_real_rows_are_64_and_text_is_not_clipped_at_both_sizes() -> void:
	_kit()
	var s := _shop_state()
	var cases := [["weapon", "all"], ["armor", "all"], ["armor", "shield"], ["sell", ""]]
	for px in WINDOWS:
		for c in cases:
			var size := await _compose(c[0], px)
			var data := _sell_rows(s) if c[0] == "sell" else _buy_rows(s, c[0], c[1])
			check(not data.is_empty(), "%s %s: 줄이 있다" % c)
			list.set_rows(data)
			await kit.frames(1)
			var pill_xs := {}
			for i in list.row_count:
				var r := list.rows[i]
				var tag := "%s %s %s 줄 %d 「%s」" % [str(size), c[0], c[1], i, r.text]
				check(r.size.y >= 64.0 and r.size.x >= 64.0, "%s: 크기 %s ≥ 64" % [tag, str(r.size)])
				check(r.clipped_parts().is_empty(), "%s: 잘린 글자 %s" % [tag, str(r.clipped_parts())])
				pill_xs[r.pill_x()] = true
			check_eq(pill_xs.size(), 1, "%s %s: NEW 알약은 줄마다 같은 x" % [str(size), c[0]])
			for b in tabs.buttons:
				check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: 탭 %s ≥ 64" % [str(size), b.name])
	# 진열 내용(실데이터): 무기 ALL 은 검 → 지팡이, NEW·흐림·품절이 있다.
	var weapons := _buy_rows(s, "weapon", "all")
	check_eq(weapons.map(func(d: Dictionary) -> String: return d["icon"]).slice(0, 3), ["kind_sword", "kind_sword", "kind_sword"], "무기 ALL: 검 묶음 먼저")
	check(weapons.any(func(d: Dictionary) -> bool: return d["new"]), "NEW 줄이 있다")
	check(weapons.any(func(d: Dictionary) -> bool: return d["dim"]), "흐린 줄이 있다")
	var shields := _buy_rows(s, "armor", "shield")
	check(shields.any(func(d: Dictionary) -> bool: return d["right"] == texts.t("shop.sold_out") and d["dim"]), "방패: 품절 줄(흐림·「품절」)")


# ---- 상점 창 ----

func test_quantity_window_steps_stop_at_the_ends_and_answer() -> void:
	await _compose("weapon")
	var answers := []
	dialog.answered.connect(func(yes: bool, q: int) -> void: answers.append([yes, q]))
	dialog.open_qty("kind_consumable", "메디카", 20, 12)
	await kit.frames(1)
	check(dialog.is_open() and dialog.visible and dialog.qty == 1, "수량 창: 1 부터")
	check_eq(dialog.count_text(), "1개", "첫 줄 개수 「1개」")
	check_eq(dialog.total_text(), "20엔이다. 살까?", "합계 문구")
	check(not dialog.handle("step", -1), "1 에서 -1 은 멈춘다")
	check(not dialog.handle("step", -10), "1 에서 -10 은 멈춘다")
	check(dialog.step_buttons[0].dimmed and dialog.step_buttons[1].dimmed, "1 이면 줄이는 단추 흐림")
	check(dialog.handle("step", 10), "+10")
	check_eq(dialog.qty, 11, "1 + 10 = 11")
	check(dialog.handle("step", 10), "+10 은 최대에서 멈춘다")
	check_eq(dialog.qty, 12, "최대 12")
	check(not dialog.handle("step", 1), "최대에서 +1 은 멈춘다")
	check(dialog.step_buttons[3].dimmed and dialog.step_buttons[2].dimmed, "최대면 늘리는 단추 흐림")
	check(dialog.handle("step", -10) and dialog.qty == 2, "-10 → 2")
	check(dialog.handle("step", -1) and dialog.qty == 1, "-1 → 1")
	# 단추 누르기도 같은 길(실제 입력).
	await kit.tap(kit.center_of(dialog.step_buttons[3]))
	check_eq(dialog.qty, 11, "「+10」 단추")
	await kit.tap(kit.center_of(dialog.step_buttons[1]))
	check_eq(dialog.qty, 10, "아래 화살표 단추")
	await kit.tap(kit.center_of(dialog.step_buttons[2]))
	check_eq(dialog.qty, 11, "위 화살표 단추")
	await kit.tap(kit.center_of(dialog.step_buttons[0]))
	check_eq(dialog.qty, 1, "「-10」 단추")
	check_eq([dialog.step_buttons[1].icon, dialog.step_buttons[1].icon_dir, dialog.step_buttons[2].icon_dir], ["arrow", 2, 0], "화살표는 벡터")
	check_eq([dialog.step_buttons[0].text, dialog.step_buttons[3].text], ["-10", "+10"], "빼기는 ASCII")
	for b in dialog.step_buttons:
		check(not b.selected, "%s: 수량 단추는 노랑이 아니다" % b.name)
	# 처음 커서는 「아니오」(yes_first 가 없으면), pick 으로 옮긴다. 노랑은 고른 단추 하나.
	check_eq(dialog.pick, ShopDialog.NO, "처음 커서 = 아니오")
	check(dialog.no_button.selected and not dialog.yes_button.selected, "노랑 = 아니오")
	check(dialog.handle("pick", -1) and dialog.pick == ShopDialog.YES, "pick ← 예")
	check(not dialog.handle("pick", -1), "끝에서 멈춘다")
	check(dialog.yes_button.selected and not dialog.no_button.selected, "노랑 = 예")
	dialog.handle("step", 3)
	check(dialog.handle("confirm"), "confirm")
	check_eq(answers, [[true, 4]], "answered(예, 4)")
	check(not dialog.is_open() and not dialog.visible, "닫힘")
	check(not dialog.handle("step", 1), "닫힌 뒤 입력 없음")
	# 「아니오」 단추·cancel.
	dialog.open_qty("kind_consumable", "메디카", 20, 5, "shop.qty.sell", true)
	check_eq(dialog.total_text(), "20엔이다. 팔까?", "판매 합계 문구")
	await kit.frames(1)
	await kit.tap(kit.center_of(dialog.no_button))
	check_eq(answers.back(), [false, 1], "「아니오」 → answered(false)")
	dialog.open_qty("kind_consumable", "메디카", 600, 99, "shop.qty.buy", true)
	dialog.handle("step", 10)
	check_eq(dialog.total_text(), "6,600엔이다. 살까?", "합계 세 자리 쉼표")
	dialog.handle("cancel")
	check_eq(answers.back(), [false, 11], "cancel → answered(false)")
	dialog.open_qty("kind_consumable", "메디카", 20, 5, "shop.qty.buy", true)
	await kit.frames(1)
	await kit.tap(kit.center_of(dialog.yes_button))
	check_eq(answers.back(), [true, 1], "「예」 단추 → answered(true, 1)")


func test_confirm_window_answers_and_blocks_the_screen_behind() -> void:
	await _compose("weapon")
	list.set_rows(_many_rows(3))
	var answers := []
	var picks: Array[int] = []
	dialog.answered.connect(func(yes: bool, q: int) -> void: answers.append([yes, q]))
	list.picked.connect(func(i: int) -> void: picks.append(i))
	dialog.open_confirm(texts.t("shop.confirm.buy_unfit", {"price": ShopRow.grouped(1200), "member": "듀얼리스트 A"}))
	await kit.frames(1)
	check_eq(dialog._label.text, "1,200엔이다. 듀얼리스트 A는 낄 수 없다. 살까?", "확인 글(조사)")
	check(dialog.yes_button.visible and dialog.no_button.visible and not dialog.ok_button.visible, "예·아니오")
	check(dialog.step_buttons.all(func(b: PartyButton) -> bool: return not b.visible), "수량 단추 없음")
	# 뒤의 목록 줄 자리를 눌러도 막힌다.
	await kit.tap(kit.center_of(list.rows[0]))
	check(picks.is_empty() and answers.is_empty(), "창이 뜬 동안 뒤 화면은 눌리지 않는다")
	check(not dialog.handle("step", 1), "확인 창에 수량 없음")
	dialog.handle("confirm")
	check_eq(answers, [[false, 1]], "처음 커서(아니오)로 confirm → answered(false)")
	# 창이 뜨면 눌려 있던 단추를 버린다(문맥이 바뀜).
	dialog.open_confirm("A", true)
	await kit.frames(1)
	var at := kit.center_of(dialog.yes_button)
	kit.touch(0, at, true)
	await kit.frames(1)
	dialog.open_confirm("B", true)
	kit.touch(0, at, false)
	await kit.frames(2)
	check_eq(answers.size(), 1, "다시 뜬 창에서 앞 누르기는 버린다")
	await kit.tap(at)
	check_eq(answers.back(), [true, 1], "「예」 → answered(true)")
	check(dialog.mouse_filter == Control.MOUSE_FILTER_STOP and host.get_child(host.get_child_count() - 1) == dialog, "창은 맨 뒤 자식·누르기 막음")


func test_notice_lists_up_to_five_lines_and_closes() -> void:
	await _compose("sell")
	var closes := [0]
	var answers := []
	dialog.closed.connect(func() -> void: closes[0] += 1)
	dialog.answered.connect(func(yes: bool, q: int) -> void: answers.append([yes, q]))
	var items := func(n: int) -> Array:
		var out := []
		for i in n:
			out.append({"icon": "kind_sword", "name": "물건 %d" % i})
		return out
	var shop := texts.t(JUNK)
	dialog.open_notice(shop, items.call(3))
	await kit.frames(1)
	check_eq(dialog.notice_head, ["%s에서" % shop, "새 물건을 살 수 있게 되었다!"] as Array[String], "머리 두 줄")
	check_eq(dialog.notice_rows.map(func(r: Array) -> String: return r[1]), ["물건 0", "물건 1", "물건 2"], "줄 셋")
	check(dialog.ok_button.visible and dialog.ok_button.selected and not dialog.yes_button.visible, "「확인」 하나(노랑)")
	check(not dialog.handle("pick", 1) and not dialog.handle("step", 1), "알림에 커서·수량 없음")
	await kit.tap(kit.center_of(dialog.ok_button))
	check_eq(closes[0], 1, "「확인」 → closed")
	check(answers.is_empty(), "알림은 answered 를 내지 않는다")
	dialog.open_notice(shop, items.call(5))
	check_eq(dialog.notice_rows.size(), 5, "다섯 줄은 그대로")
	check_eq(dialog.notice_rows[4], ["kind_sword", "물건 4"], "다섯째 줄 그대로")
	dialog.handle("cancel")
	check_eq(closes[0], 2, "cancel → closed")
	dialog.open_notice(shop, items.call(8))
	check_eq(dialog.notice_rows.size(), 5, "넘치면 다섯 줄")
	check_eq(dialog.notice_rows[3], ["kind_sword", "물건 3"], "넷째까지 물건")
	check_eq(dialog.notice_rows[4], ["", "외 4개"], "마지막 줄 「외 n개」")
	dialog.handle("confirm")
	check_eq(closes[0], 3, "confirm → closed")
	await kit.frames(1)


# ---- 배치 ----

## 1280×720·1728×720: 소지금 문패·탭 줄·목록 창·상점 창(셋)이 화면 안이고 캐릭터 판과 겹치지 않는다. 노랑은 하나.
func test_parts_stay_inside_and_clear_of_the_panel_at_both_sizes() -> void:
	for px in WINDOWS:
		for set_name in ["weapon", "armor", "sell"]:
			var size := await _compose(set_name, px)
			var tag := "%s %s" % [str(size), set_name]
			var screen := Rect2(Vector2.ZERO, size)
			var panel := _rect(frame.panel)
			check_eq(panel, Rect2(size.x - CharPanel.W, 0, CharPanel.W, size.y), tag + ": 캐릭터 판 = 캠프와 같다")
			check_eq(_rect(frame.title_plate), Rect2(0, 112, 340, 50), tag + ": 소지금 문패 0,112 340×50")
			check(frame.title_right and frame.title_text == "1,480엔", tag + ": 「1,480엔」 오른쪽 맞춤")
			var tr := Rect2(tabs.position, tabs.size)
			check_eq([tr.position.x, tr.position.y, tr.end.y], [ShopFrame.PAD_SIDE, 166.0, 230.0], tag + ": 탭 줄 x left · y 166~230")
			var lw := frame.list_window_rect()
			check_eq([lw.position.x, lw.position.y, lw.end.y], [ShopFrame.PAD_SIDE, 236.0, 500.0], tag + ": 목록 창 236~500")
			check(tr.end.y < lw.position.y and tr.position.y > _rect(frame.title_plate).end.y, tag + ": 탭 줄은 문패와 목록 창 사이")
			for r in [tr, lw, _rect(list), frame.desc_rect(), _rect(frame.title_plate)]:
				check(screen.encloses(r), "%s: %s 화면 안" % [tag, str(r)])
				check(not (r as Rect2).intersects(panel), "%s: %s 가 캐릭터 판과 겹친다" % [tag, str(r)])
			check(not tr.intersects(_rect(frame.back_button)) and not tr.intersects(frame.banner_rect()), tag + ": 탭 줄은 「뒤로」·설명 띠와 떨어져 있다")
			list.set_rows(_many_rows(9))
			list.set_cursor(4)
			for m in ["confirm", "qty", "notice"]:
				match m:
					"confirm":
						dialog.open_confirm("가")
					"qty":
						dialog.open_qty("kind_sword", "가", 10, 9)
					"notice":
						dialog.open_notice("가", [{"icon": "kind_sword", "name": "1"}, {"icon": "kind_sword", "name": "2"}, {"icon": "kind_sword", "name": "3"},
							{"icon": "kind_sword", "name": "4"}, {"icon": "kind_sword", "name": "5"}, {"icon": "kind_sword", "name": "6"}])
				await kit.frames(1)
				var wr := dialog.window_rect()
				check(screen.encloses(wr) and not wr.intersects(panel), "%s %s: 창 %s 화면 안·판과 안 겹침" % [tag, m, str(wr)])
				check(absf(wr.get_center().x - lw.get_center().x) <= 1.0, "%s %s: 창은 목록 창 가로 가운데" % [tag, m])
				for b in [dialog.yes_button, dialog.no_button, dialog.ok_button] + dialog.step_buttons:
					var pb := b as PartyButton
					if not pb.visible:
						continue
					check(wr.encloses(_rect(pb)), "%s %s: %s 가 창 안" % [tag, m, pb.name])
					check(pb.size.y >= 64.0 and pb.size.x >= 64.0, "%s %s: %s ≥ 64" % [tag, m, pb.name])
					check(pb.clipped_parts().is_empty(), "%s %s: %s 잘린 글자" % [tag, m, pb.name])
				var yellow := dialog.find_children("*", "PartyButton", true, false).filter(func(b: Node) -> bool: return (b as PartyButton).visible and (b as PartyButton).selected)
				check_eq(yellow.size(), 1, "%s %s: 창의 노랑은 하나" % [tag, m])
				dialog.close()


## 캠프는 그대로다: 매개변수 없이 짜면 목록 창 172·문패 가운데.
func test_shop_frame_defaults_keep_the_camp_look() -> void:
	await _compose("")
	var f := ShopFrame.new()
	host.add_child(f)
	f.build("Camp", "뒤로", true, ShopFrame.PAD_SIDE)
	await kit.frames(1)
	check_eq(f.list_top, ShopFrame.LIST_TOP, "캠프 목록 창 위 끝 172")
	check_eq(f.list_window_rect().position.y, 172.0, "캠프 목록 창 자리")
	f.show_title("장비")
	check(not f.title_right, "캠프 문패는 가운데")


func test_money_and_numbers_use_grouped_digits() -> void:
	_kit()
	check_eq([ShopRow.grouped(0), ShopRow.grouped(999), ShopRow.grouped(1000), ShopRow.grouped(1480), ShopRow.grouped(9999999), ShopRow.grouped(-1234)],
		["0", "999", "1,000", "1,480", "9,999,999", "-1,234"], "세 자리 쉼표")
	check_eq(texts.t("shop.money", {"money": ShopRow.grouped(1480)}), "1,480엔", "소지금 문패 글")


# ---- 독립 검토 고침 1차(F1~F4) ----

## F1: 줄을 누른 채 다른 줄이 놓이면(탭·진열 바뀜) 그 누르기·끌기는 버린다. 같은 줄을 다시 놓으면 그대로 고를 수 있다.
func test_rebuilding_rows_drops_held_presses_unless_the_data_is_the_same() -> void:
	await _compose("weapon")
	var got: Array[int] = []
	list.picked.connect(func(i: int) -> void: got.append(i))
	list.set_rows(_many_rows(5))
	await kit.frames(1)
	var p := kit.center_of(list.rows[0])
	kit.touch(0, p, true)
	await kit.frames(1)
	var other := _many_rows(5)
	other[0]["name"] = "새 줄"
	list.set_rows(other)
	check(not list.rows[0].held, "다른 줄이 놓이면 눌림이 풀린다")
	kit.touch(0, p, false)
	await kit.frames(2)
	check(got.is_empty(), "다른 줄을 놓은 뒤 떼도 고르지 않는다")
	kit.touch(0, p, true)
	await kit.frames(1)
	list.set_rows(other.duplicate(true))
	check(list.rows[0].held, "같은 줄을 다시 놓으면 누르기 그대로")
	kit.touch(0, p, false)
	await kit.frames(2)
	check_eq(got, [0] as Array[int], "같은 줄이면 떼서 picked(0)")
	# 끌던 손가락: 다른 줄이 놓인 뒤 더 끌어도 내려가지 않는다.
	list.set_rows(_many_rows(21))
	list.set_cursor(0)
	await kit.frames(1)
	var from := kit.center_of(list.rows[2])
	kit.touch(0, from, true)
	kit.drag(0, from, from - Vector2(0, 40))
	check(list.rows[2].dragging and list.scroll.scroll > 0.0, "준비: 줄을 끌어 내리는 중(%.0f)" % list.scroll.scroll)
	var more := _many_rows(21)
	more[3]["name"] = "바뀐 줄"
	list.set_rows(more)
	var after := list.scroll.scroll
	kit.drag(0, from - Vector2(0, 40), from - Vector2(0, 160))
	kit.touch(0, from - Vector2(0, 160), false)
	await kit.frames(2)
	check_eq(list.scroll.scroll, after, "다른 줄이 놓인 뒤 끌어도 내려가지 않는다")
	check_eq(got, [0] as Array[int], "끌기는 고르기가 아니다")


## F2: 창이 뜨기 전에 눌려 있던 뒤 화면 누르기(줄·탭·끌기)는 창이 뜰 때 버려진다. 닫은 뒤 떼도 아무 일 없다.
func test_opening_a_dialog_cancels_held_presses_behind_it() -> void:
	await _compose("weapon")
	list.set_rows(_many_rows(21))
	await kit.frames(1)
	var picks: Array[int] = []
	var tab_picks: Array[int] = []
	list.picked.connect(func(i: int) -> void: picks.append(i))
	tabs.picked.connect(func(i: int) -> void: tab_picks.append(i))
	var p := kit.center_of(list.rows[0])
	# 1. 줄을 누른 채 창 → 떼기.
	kit.touch(0, p, true)
	await kit.frames(1)
	dialog.open_confirm("A")
	kit.touch(0, p, false)
	await kit.frames(2)
	check(picks.is_empty() and dialog.is_open(), "창 아래에서 떼도 고르지 않고 창은 그대로")
	dialog.close()
	# 2. 줄을 누른 채 창 → 끌기.
	kit.touch(0, p, true)
	await kit.frames(1)
	dialog.open_confirm("B")
	var before := list.scroll.scroll
	kit.drag(0, p, p - Vector2(0, 150))
	kit.touch(0, p - Vector2(0, 150), false)
	await kit.frames(2)
	check_eq(list.scroll.scroll, before, "창이 뜬 뒤 끌어도 뒤 목록은 내려가지 않는다")
	check(picks.is_empty(), "끌고 떼도 고르지 않는다")
	dialog.close()
	# 3. 줄을 누른 채 창을 열고 닫은 뒤 떼기.
	kit.touch(0, p, true)
	await kit.frames(1)
	dialog.open_confirm("C")
	dialog.close()
	kit.touch(0, p, false)
	await kit.frames(2)
	check(picks.is_empty(), "창을 열고 닫은 뒤 떼도 고르지 않는다")
	# 4. 탭을 누른 채 창 → 떼기.
	var tp := kit.center_of(tabs.buttons[1])
	kit.touch(0, tp, true)
	await kit.frames(1)
	dialog.open_qty("kind_sword", "가", 10, 3)
	kit.touch(0, tp, false)
	await kit.frames(2)
	check(tab_picks.is_empty() and tabs.current == 0, "창 아래에서 탭을 떼도 고르지 않는다")
	# 5. 창이 뜬 동안 새로 누르기도 막힌다.
	await kit.tap(p)
	await kit.tap(tp)
	check(picks.is_empty() and tab_picks.is_empty(), "창이 뜬 동안 새 누르기는 뒤에 닿지 않는다")
	dialog.close()
	await kit.tap(kit.center_of(list.rows[0]))
	check_eq(picks, [0] as Array[int], "창을 닫은 뒤 새 누르기는 된다")


## F3: 창이 뜬 동안 노랑은 하나(창 단추). 목록 커서 줄은 「chosen」(밝은 시안) 또는 「none」, 닫으면 다시 노랑(같은 커서·내림).
func test_cursor_mode_keeps_a_single_yellow_while_a_dialog_is_open() -> void:
	await _compose("weapon")
	list.set_rows(_many_rows(21))
	list.set_cursor(10)
	await kit.frames(1)
	var scroll_before := list.scroll.scroll
	var yellow := func() -> Array:
		return host.find_children("*", "TouchButton", true, false).filter(func(b: Node) -> bool:
			return (b as TouchButton).is_visible_in_tree() and (b as TouchButton).selected).map(func(b: Node) -> String: return str(b.get_path()))
	check_eq(yellow.call(), [str(list.rows[10].get_path())], "창 없음: 노랑 = 커서 줄")
	dialog.open_confirm(texts.t("shop.confirm.buy", {"price": "120"}))
	list.set_cursor_mode("chosen")
	await kit.frames(1)
	check_eq(yellow.call(), [str(dialog.no_button.get_path())], "창 + chosen: 노랑은 창 단추 하나")
	check_eq(list.rows[10].theme_state(), "cmd:chosen", "커서 줄 = 밝은 시안 chosen")
	check_eq([list.cursor, list.scroll.scroll], [10, scroll_before], "모양을 바꿔도 커서·내림 그대로")
	list.set_cursor_mode("none")
	check(list.rows.all(func(r: ShopRow) -> bool: return not r.selected and not r.chosen), "none: 커서 줄 표시 없음")
	check_eq(yellow.call(), [str(dialog.no_button.get_path())], "none: 노랑은 창 단추 하나")
	dialog.close()
	list.set_cursor_mode("cursor")
	await kit.frames(1)
	check_eq(yellow.call(), [str(list.rows[10].get_path())], "닫고 cursor: 다시 노랑 = 커서 줄")
	check_eq([list.cursor, list.scroll.scroll], [10, scroll_before], "닫은 뒤 같은 커서·내림")
	check_eq(list.rows[10].theme_state(), "cmd:selected", "커서 줄 노랑")
	# 고른 줄 표시(아이콘 칸 테두리)는 chosen·노랑이어도 남는다.
	var rows := _many_rows(3)
	rows[1]["checked"] = true
	list.set_rows(rows)
	list.set_cursor(1)
	check_eq(list.rows[1].icon_edge(), [UiTheme.BTN_CHECKED, 3.0], "고른 줄의 아이콘 칸 테두리(커서 줄)")
	list.set_cursor_mode("chosen")
	check_eq(list.rows[1].icon_edge(), [UiTheme.BTN_CHECKED, 3.0], "고른 줄의 아이콘 칸 테두리(chosen)")
	check_eq(list.rows[0].icon_edge(), [UiTheme.SHOP_ICON_EDGE, 1.5], "고르지 않은 줄의 테두리")
	list.set_cursor_mode("cursor")


## F4: setup 전에 버린 창은 글자 칸까지 풀린다.
func test_a_dialog_freed_before_setup_leaves_nothing() -> void:
	var d := ShopDialog.new()
	var id := d._label.get_instance_id()
	d.free()
	check(not is_instance_id_valid(id), "setup 전에 버린 창의 글자 칸도 풀린다")


## 상점 색 대비(test_ui_polish2 와 같은 계산): NEW 알약 흰 글자, 알림 머리·물건 이름(창 위·아래 끝).
func test_shop_colours_meet_contrast() -> void:
	var P := preload("res://tests/test_ui_polish2.gd")
	check(P.contrast(UiTheme.SHOP_NEW_PILL, UiTheme.SHOP_NEW_TEXT) >= 4.5, "NEW 알약 %.2f" % P.contrast(UiTheme.SHOP_NEW_PILL, UiTheme.SHOP_NEW_TEXT))
	for bg in [UiTheme.SHOP_NOTICE_TOP, UiTheme.SHOP_NOTICE_BOTTOM]:
		for fg in [UiTheme.SHOP_NOTICE_ITEM, UiTheme.TEXT]:
			check(P.contrast(bg, fg) >= 4.5, "알림 %s 위 %s %.2f" % [bg.to_html(false), fg.to_html(false), P.contrast(bg, fg)])
	check(P.contrast(UiTheme.SHOP_ICON_CELL, UiTheme.SHOP_ICON) >= 4.5, "아이콘 칸 위 아이콘")
