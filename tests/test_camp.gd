## 캠프 시험(M2.7 R2, 07 §9, research 05 §2.2): 입구(안내 줄 「캠프」·P·Esc), 캠프 뿌리(원작 시설 짜임으로 추정한 배치 표),
## 대원 고르기(파티 카드), 상태 화면(원작 상태 화면 배치), 기록(R2-d 전까지 메뉴 창), 보이는 위아래 = 누르는 위아래, 64px, 글자 대비.
## 배치 표(1280×720 기준, 1728×720 도 같은 규칙): 문패 0,12 182×76(다이얼 자리 0~190·0~100 안), 설명 띠 x 192 → 오른쪽 끝·y 0~100,
## 명령 목록 x 0~430·y 116~542(줄 64, 간격 6), 파티 카드 아래 두 줄(윗줄 = 전열). 저장은 장면 시험 임시 폴더에만.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
const FINGER := 3

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _open() -> DungeonScreen:
	timeout_sec = 90.0
	kit = Kit.new(tree)
	var s := await kit.open("native", 7, "debug=1")
	return s


func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


static func _under(c: Node, n: Node) -> bool:
	return n != null and (c == n or c.is_ancestor_of(n))


static func _name_of(c: Control) -> String:
	return "없음" if c == null else str(c.get_path())


## 논리 좌표 p 를 손가락으로 누를 때 처음 받는 컨트롤(test_overlay_ui 와 같은 방법). 창 밖에서 떼어 받은 것이 일하지 않게 한다.
func _receiver_at(p: Vector2) -> Control:
	var got: Array[Control] = []
	var hooks: Array = []
	for n in tree.root.find_children("*", "Control", true, false):
		var c := n as Control
		var f := func(ev: InputEvent) -> void:
			if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed and got.is_empty():
				got.append(c)
		c.gui_input.connect(f)
		hooks.append([c, f])
	kit.touch(FINGER, tree.root.get_final_transform() * p, true)
	kit.touch(FINGER, Vector2(-500, -500), false)
	await kit.frames(1)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Control).gui_input.is_connected(h[1]):
			(h[0] as Control).gui_input.disconnect(h[1])
	return got[0] if not got.is_empty() else null


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


## WCAG 대비(상대 휘도).
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _check_targets(pm: PartyMenu, size: Vector2, tag: String) -> void:
	var bs := pm.visible_buttons()
	check(not bs.is_empty(), tag + ": 누를 것이 있다")
	var screen := Rect2(Vector2.ZERO, size)
	for b in bs:
		check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str(b.size)])
		check(screen.encloses(_rect(b).grow(-0.5)), "%s: %s %s 가 화면 안" % [tag, b.name, str(_rect(b))])


# ---- 입구 ----

func test_entrance_is_camp_and_map_and_p_or_esc_open_the_camp_root() -> void:
	var s := await _open()
	var pm := s.party_menu
	var shown := s.hint_row.get_children().filter(func(c: Node) -> bool: return (c as Control).visible)
	check_eq(shown, [s.camp_button, s.map_button], "안내 줄 = 「캠프」「지도」(원작 CAMP · MAP)")
	check_eq(s.camp_button.text, s.texts.t("camp.title"), "「캠프」 글")
	check(s.find_child("MenuButton", true, false) == null and s.find_child("PartyButton", true, false) == null, "「파티」「메뉴」 단추는 없다")
	for k in [KEY_P, KEY_ESCAPE]:
		await kit.press_key(k)
		check(pm.is_open() and pm.page == "root" and pm.camp_cursor == 0, "%s → 캠프 뿌리" % OS.get_keycode_string(k))
		check_eq(s.modal.kind, "", "주 메뉴는 열리지 않는다")
		await kit.press_key(KEY_ESCAPE if k == KEY_P else KEY_P)
		check(not pm.is_open(), "Esc·P → 닫힘")
	await kit.tap(kit.center_of(s.camp_button))
	check(pm.is_open() and pm.page == "root", "「캠프」 단추 → 캠프 뿌리")


# ---- 캠프 뿌리 배치 ----

func test_camp_root_follows_the_facility_table_at_both_sizes() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 3D 시야는 화면 전체")
		var dial := Rect2(0, 0, 190, 100)
		check_eq(_rect(pm.camp_plate), Rect2(0, 12, 182, 76), tag + ": 문패(층 이름·걸음)")
		check(dial.encloses(_rect(pm.camp_plate)), tag + ": 문패는 다이얼 자리 안")
		check_eq([pm.camp_plate.first, pm.camp_plate.second], [s.texts.t("floor.f1_test"), s.texts.t("hud.steps", {"steps": s.state.steps})], tag + ": 문패 글")
		check_eq(_rect(pm.banner), Rect2(192, 0, size.x - 192, 100), tag + ": 설명 띠 x 192 → 오른쪽 끝, y 0~100")
		var lr := _rect(pm.camp_list)
		check_eq(lr, Rect2(0, 116, 430, FacilityList.content_height(6)), tag + ": 명령 목록 x 0~430, y 116~")
		check(lr.end.y <= 542.0 + 0.5, tag + ": 목록 아래 끝 542 %s" % str(lr))
		var rows := pm.camp_list.rows
		check_eq(rows.size(), 6, tag + ": 명령 여섯")
		for i in rows.size():
			var r := _rect(rows[i])
			check(r.size.y >= 64.0 and r.size.x >= 64.0, "%s: 줄 %d %s ≥ 64" % [tag, i, str(r.size)])
			check(lr.encloses(r), "%s: 줄 %d 는 목록 안" % [tag, i])
			check_eq(rows[i].text, "%d  %s" % [i + 1, s.texts.t("camp.cmd." + PartyMenu.CAMP_KEYS[i])], "%s: 줄 %d 글" % [tag, i])
			var e := rows[i].right_edge()
			var to_list := rows[i].position
			check(absf(e.x + to_list.x - pm.camp_list.arc_x(to_list.y)) < 0.5, "%s: 줄 %d 오른쪽 끝이 원호 위" % [tag, i])
			if i > 0:
				check(r.position.y >= _rect(rows[i - 1]).end.y, "%s: 줄 %d 가 앞 줄 아래" % [tag, i])
		check_eq(rows[0].theme_state(), "fac:selected", tag + ": 커서 줄 = 노랑(짙은 글자)")
		check_eq(rows[1].theme_state(), "fac:normal", tag + ": 다른 줄 = 청록 + 시설 물빛 글자")
		# 파티 카드: 아래 두 줄, 윗줄 = 편성 전열, 목록과 겹치지 않는다.
		var cards := pm.cards.cards
		check_eq(cards.size(), 5, tag + ": 카드 다섯")
		var top_y := INF
		for i in cards.size():
			var cr := _rect(cards[i])
			check_eq(cr.size, PartyCards.CARD, "%s: 카드 %d 크기(전투와 같은 부품)" % [tag, i])
			var front := s.state.defs.party.rows[i] == "front"
			check_eq(cr.end.y <= size.y - PartyCards.BOTTOM - PartyCards.CARD.y - PartyCards.ROW_GAP + 0.5, front, "%s: 카드 %d 는 %s" % [tag, i, "윗줄" if front else "아랫줄"])
			check(not cr.intersects(lr), "%s: 카드 %d 와 명령 목록이 겹치지 않는다" % [tag, i])
			top_y = minf(top_y, cr.position.y)
			check_eq(cards[i].mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: 뿌리에서 카드는 누르지 않는다" % tag)
		check(lr.end.y < top_y, "%s: 목록 아래 %s < 카드 위 %s" % [tag, lr.end.y, top_y])
		for c in [pm.camp_plate, pm.banner, pm.cards]:
			check_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식(IGNORE)" % [tag, c.name])
		_check_targets(pm, size, tag + " 뿌리")
		var snap := [lr, _rect(pm.banner), _rect(cards[0]), _rect(cards[4])]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap


func test_taps_go_to_the_visible_top_in_the_camp() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := str(px)
		for spot in [_rect(pm.banner).get_center(), _rect(pm.camp_plate).get_center(), Vector2(size.x * 0.7, size.y * 0.45),
				_rect(pm.cards.cards[0]).get_center()]:
			var got := await _receiver_at(spot)
			check(got == pm, "%s: 장식·빈 곳 %s → 캠프 층(뒤 탐색 화면에 닿지 않는다), 실제 %s" % [tag, str(spot), _name_of(got)])
		for row in pm.camp_list.rows:
			var got := await _receiver_at(_rect(row).get_center())
			check(got == row, "%s: %s → 그 줄, 실제 %s" % [tag, row.name, _name_of(got)])
		# 줄 사이·뒤판은 목록이 받는다.
		var gap := Vector2(40, (_rect(pm.camp_list.rows[0]).end.y + _rect(pm.camp_list.rows[1]).position.y) / 2.0)
		var got_gap := await _receiver_at(gap)
		check(got_gap == pm.camp_list, "%s: 줄 사이 → 목록, 실제 %s" % [tag, _name_of(got_gap)])
		check_eq([pm.page, pm.is_open()], ["root", true], tag + ": 누르기 시험은 아무것도 고르지 않는다(창 밖에서 뗀다)")
		pm.handle("camp", 0)
		await kit.frames(2)
		for c in pm.cards.cards:
			var got := await _receiver_at(_rect(c).get_center())
			check(got == c, "%s 고르기: %s → 카드, 실제 %s" % [tag, c.name, _name_of(got)])
		_check_targets(pm, size, tag + " 고르기")
		pm.handle("back")
		await kit.frames(2)


# ---- 대원 고르기·명령 ----

func test_member_pick_and_every_camp_command() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_DOWN)
	check_eq(pm.camp_cursor, 1, "↓ → 스킬 줄")
	check_eq(pm.banner.head, s.texts.t("camp.desc.skills"), "설명 띠 = 커서 명령의 설명")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(pm.camp_cursor, 5, "↑ 는 끝에서 돈다(닫기)")
	await kit.press_key(KEY_1)
	check_eq([pm.page, pm.pick_cmd, pm.pick_cursor], ["pick", 0, 0], "1 → 상태 대원 고르기(커서 칸 0)")
	check_eq(pm.banner.head, s.texts.t("camp.pick.status"), "물음 「누구의 상태를 볼까?」")
	check_eq(pm.camp_list.rows[0].theme_state(), "fac:chosen", "고른 명령 = 밝은 시안")
	check_eq(pm.camp_list.rows[5].text, s.texts.t("camp.back"), "마지막 줄 = 「뒤로」")
	for i in 5:
		check_eq(pm.camp_list.rows[i].mouse_filter, Control.MOUSE_FILTER_IGNORE, "고르기 중 명령 줄 %d 는 누르지 않는다" % i)
	# 전투의 아군 대상 고르기 표시: 고를 수 있는 카드 모두 노랑, 커서 카드에 흰 안쪽 선.
	for c in pm.cards.cards:
		check_eq([c.target_mark, c.cursor, c.current], ["valid", c == pm.cards.cards[0], false], "카드 %s: 대상 표시" % c.name)
	check_eq(pm.camp_list.rows[1].theme_state(), "fac:normal", "다른 명령 줄 = 시설 청록 글자")
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.pick_cursor, 1, "→ 다음 카드")
	await kit.press_key(KEY_DOWN)
	var want := pm.pick_target(1, Vector2i(0, 1))
	check(not pm.cards.top_row(want), "↓ → 아랫줄 카드")
	check_eq(pm.pick_cursor, want, "↓ → 가로로 가장 가까운 아랫줄 카드")
	await kit.press_key(KEY_UP)
	check(pm.cards.top_row(pm.pick_cursor), "↑ → 윗줄")
	var two_left := pm.pick_target(pm.pick_target(pm.pick_cursor, Vector2i(-1, 0)), Vector2i(-1, 0))
	await kit.press_key(KEY_LEFT)
	await kit.press_key(KEY_LEFT)
	check_eq(pm.pick_cursor, two_left, "← 두 번")
	check_eq(pm.pick_target(0, Vector2i(-1, 0)), 4, "← 는 끝에서 돈다(윗줄 첫 카드 → 아랫줄 끝 카드)")
	var picked := pm.pick_cursor
	await kit.press_key(KEY_ENTER)
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, picked], "Enter → 커서 대원 상태 화면")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_1)
	await kit.tap(kit.center_of(pm.cards.cards[2]))
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, 2], "카드 누르기 → 그 대원 상태 화면")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", 0], "Esc → 캠프 뿌리(커서 상태)")
	await kit.press_key(KEY_2)
	check_eq(pm.pick_cursor, 2, "고르기 커서는 지난 대원에서")
	await kit.tap(kit.center_of(pm.cards.cards[3]))
	check_eq([pm.page, pm.tab, pm.member], ["sub", 1, 3], "카드 누르기 → 그 대원 스킬")
	await kit.press_key(KEY_P)
	check_eq([pm.page, pm.camp_cursor], ["root", 1], "P → 캠프 뿌리(커서 스킬)")
	await kit.press_key(KEY_3)
	await kit.tap(kit.center_of(pm.camp_list.rows[5]))
	check_eq(pm.page, "root", "「뒤로」 줄 → 캠프 뿌리")
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ESCAPE)
	check_eq(pm.page, "root", "고르기에서 Esc → 캠프 뿌리")
	await kit.tap(kit.center_of(pm.camp_list.rows[3]))
	check_eq([pm.page, pm.tab], ["sub", 3], "소지품 → 고르기 없이 소지품")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab, s.modal.kind], ["sub", 4, ""], "기록 → 고르기 없이 기록 화면(따로 된 메뉴 창 없음)")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", 4], "Esc → 캠프 뿌리(커서 기록)")
	await kit.tap(kit.center_of(pm.camp_list.rows[4]))
	check_eq([pm.page, pm.tab], ["sub", 4], "「기록」 줄 누르기도 기록 화면")
	await kit.tap(kit.center_of(pm.records_tab.back_button))
	check_eq([pm.page, pm.camp_cursor], ["root", 4], "기록 「뒤로」 → 캠프 뿌리")
	await kit.press_key(KEY_6)
	check(not pm.is_open(), "6 닫기 → 탐색")
	check(s.camp_button.is_visible_in_tree(), "탐색 HUD 가 돌아온다")


# ---- 상태 화면 ----

func test_status_screen_follows_the_reference_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	GrowthRules.grant_exp(s.state, 1, 120)
	GrowthRules.supply(s.state, "equip.thermal_ring", 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	var st := pm.status_tab
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, 1], "준비: 듀얼리스트 A 상태")
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var screen := Rect2(Vector2.ZERO, size)
		check_eq(_rect(s.view_container), screen, tag + ": 바탕은 줄지 않는다")
		for c in [pm.camp_list, pm.banner, pm.cards]:
			check(not (c as Control).is_visible_in_tree(), "%s: 캠프 뿌리 부품은 감춘다(%s)" % [tag, c.name])
		# 초상은 받는 배율 문패 뒤(원작 그림 자리)라 겹침 검사에서 빼고 따로 본다.
		var blocks := {"name": st.name_tab_rect(), "lv": st.lv_band_rect(), "class": st.class_rect(), "side": st.side_rect(),
			"split_button": _rect(st.split_button)}
		for i in PartyStatusTab.STAT_ROWS.size():
			blocks["stat%d" % i] = st.stat_rect(i)
		for i in 4:
			blocks["gear%d" % i] = st.gear_rect(i)
			blocks["equip%d" % i] = st.equip_rect(i)
		var keys := blocks.keys()
		for i in keys.size():
			var a: Rect2 = blocks[keys[i]]
			check(screen.encloses(a), "%s: %s %s 화면 안" % [tag, keys[i], str(a)])
			if keys[i] != "name" and keys[i] != "lv":
				check(a.position.y >= PartyStatusTab.TOP_H, "%s: %s 는 위 줄 아래" % [tag, keys[i]])
			for j in range(i + 1, keys.size()):
				check(not a.intersects(blocks[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
		check_eq(st.info_rect(), Rect2(0, 64, size.x, 54), tag + ": 정보 띠는 전체 폭")
		check_eq(st.lv_band_rect().end.x, size.x, tag + ": Lv 띠는 오른쪽 끝까지")
		var pr := st.portrait_rect()
		check_eq([pr.position.y, pr.end.y, pr.end.x], [PartyStatusTab.TOP_H, size.y, size.x - PartyStatusTab.PORTRAIT_RIGHT],
			tag + ": 초상은 오른쪽, 위 띠 아래 ~ 아래 끝(원작 그림 자리)")
		check(pr.size.x >= 500.0 and pr.position.x >= PartyStatusTab.LEFT_W, tag + ": 초상은 크고 왼쪽 열과 안 겹친다")
		check(pr.encloses(st.side_rect()) or pr.intersects(st.side_rect()), tag + ": 받는 배율 문패는 초상 위에 얹힌다")
		check(st.portrait.get_index() < st.side.get_index(), tag + ": 그리는 순서 초상 → 문패(문패가 앞)")
		check_eq(st.side_rect().end, size - Vector2(PartyStatusTab.SIDE_EDGE, PartyStatusTab.side_bottom()), tag + ": 받는 배율 문패는 「내역」 위")
		check_eq(_rect(st.split_button), Rect2(size - Vector2(8 + 120, 8 + 64), Vector2(120, 64)), tag + ": 「내역」 오른쪽 아래(원작 Ⓐ SKILL 자리)")
		check_eq(_rect(st.back_button), Rect2(size.x - 8 - 120, 0, 120, 64), tag + ": 「뒤로」 오른쪽 위")
		check_eq([_rect(st.prev_button), _rect(st.next_button)], [Rect2(0, 0, 64, 64), Rect2(266, 0, 64, 64)], tag + ": 앞·다음 대원(원작 L·R 자리)")
		for d in [st.top, st.left, st.portrait, st.side]:
			check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
		_check_targets(pm, size, tag + " 상태")
		var snap := [st.portrait_rect(), st.side_rect(), _rect(st.back_button)]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 값: 규칙의 읽기 함수에서.
	var m := s.state.party.members[1]
	var p := GrowthRules.profile(s.state.defs, 1, m)
	var d := st.drawn
	check_eq([d["name"], d["class"], d["level"]], [s.texts.t("member.blade_duelist"), s.texts.t("class.blade_duelist"), "Lv %d" % m.level], "이름·직업·Lv")
	check_eq(d["hp"], "%d/%d" % [m.hp, m.max_hp], "HP")
	check_eq(d["next"], s.texts.t("party.exp_next", {"n": s.state.defs.battle.growth.cum(m.level + 1) - m.exp}), "다음 레벨까지")
	for k in PartyStatusTab.STAT_ROWS:
		var b: Dictionary = p["breakdown"][k]
		check_eq((d["stats"][k] as Array).slice(0, 4), [b["total"], b["base"], b["passive"], b["equip"]], "능력치 %s 합계·나눔" % k)
	for k in BattleLimits.GEAR:
		check_eq(d["gear"][k], p["gear"][k], "공격·방어 " + k)
	check_eq(d["equip"][0][1], pm.item_name(m.equip[0]), "장비 칸 0 이름")
	# 대원 넘기기: E·Q·단추, 「뒤로」.
	await kit.press_key(KEY_E)
	check_eq([pm.member, st.drawn["name"]], [2, s.texts.t("member.blade_duelist_2")], "E → 다음 대원")
	await kit.tap(kit.center_of(st.prev_button))
	check_eq(pm.member, 1, "← 단추 → 앞 대원")
	await kit.tap(kit.center_of(st.next_button))
	check_eq(pm.member, 2, "→ 단추 → 다음 대원")
	# 「내역」: 같은 줄의 막대 칸이 기본·패시브·장비로 바뀐다. V·단추, 대원을 넘겨도 남고 캠프를 다시 열면 꺼진다.
	check(not st.split_view and not st.drawn["split_view"], "처음은 막대 보기(원작 그대로)")
	await kit.press_key(KEY_V)
	check(st.split_view and st.drawn["split_view"] and st.split_button.checked, "V → 내역 보기")
	for i in PartyStatusTab.STAT_ROWS.size():
		var r := st.stat_rect(i)
		for c in 3:
			check(r.encloses(st.split_cell(i, c)), "내역 칸 %d/%d 는 같은 줄 안" % [i, c])
		check(st.split_cell(i, 0).position.x == st.bar_rect(i).position.x and st.split_cell(i, 2).end.x <= r.end.x, "내역 칸은 막대 자리")
	await kit.press_key(KEY_E)
	check(st.split_view, "대원을 넘겨도 내역 보기는 남는다")
	await kit.tap(kit.center_of(st.split_button))
	check(not st.split_view, "「내역」 단추 → 막대 보기")
	await kit.tap(kit.center_of(st.split_button))
	check(st.split_view, "「내역」 단추 → 다시 내역 보기")
	await kit.tap(kit.center_of(st.back_button))
	check_eq([pm.page, pm.camp_cursor], ["root", 0], "「뒤로」 → 캠프 뿌리")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	check(pm.page == "sub" and pm.tab == 0 and not st.split_view, "캠프를 다시 열면 막대 보기")


# ---- 스킬 트리 화면(R2-b, 원작 jp_guide2_img3·img2) ----

func test_skill_screen_follows_the_reference_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	GrowthRules.grant_exp(s.state, 1, s.state.defs.battle.growth.cum(3))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	var st := pm.skill_tab
	check_eq([pm.page, pm.tab, pm.member], ["sub", 1, 1], "준비: 듀얼리스트 A 스킬")
	for n in ["Close", "Tab_status", "Member_0", "TitlePlate", "Notice"]:
		check(pm.find_child(n, false, false) == null, "앞 파티 메뉴 틀 부품 %s 은 없다(R2-d 에서 지움)" % n)
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 바탕은 줄지 않는다")
		check_eq(st.top.size, Vector2(size.x, MemberHeader.H), tag + ": 위 줄(이름 칸·Lv 띠·SKILL POINT 띠) 전체 폭")
		check_eq([_rect(st.top.prev_button), _rect(st.top.next_button), _rect(st.top.back_button)],
			[Rect2(0, 0, 64, 64), Rect2(266, 0, 64, 64), Rect2(size.x - 128, 0, 120, 64)], tag + ": 앞·다음 대원, 「뒤로」")
		var win := st.tree_window_rect()
		var desc := st.desc_rect()
		check_eq(win, Rect2(48, 150, size.x - 96, 392), tag + ": 트리 창 x 48 ~ 오른쪽 48, y 150~542(원작 138~548)")
		check_eq(desc, Rect2(48, size.y - 172, size.x - 96, 164), tag + ": 설명 띠 아래 넓게(원작 y 552~708)")
		check(win.end.y <= desc.position.y, tag + ": 트리 창은 설명 띠 위")
		var ct := st.class_tab_rect()
		check(ct.position.y >= MemberHeader.H and ct.position.y < win.position.y and ct.end.y > win.position.y, tag + ": 직업 탭은 트리 창 위 가장자리에 걸친다")
		check(win.encloses(st.tree_rect()), tag + ": 트리 영역은 창 안")
		var area := Rect2(Vector2.ZERO, st.tree_rect().size)
		for i in st.nodes.size():
			check(area.encloses(st.node_rect(i)), "%s: 노드 %d %s 가 트리 영역 안" % [tag, i, str(st.node_rect(i))])
			check_eq(st.nodes[i].size, st.node_size(), "%s: 노드 %d 크기" % [tag, i])
		check(st.node_size().x >= 240.0 and st.node_size().y >= 64.0, tag + ": 노드는 넓은 알약(원작 323×32 → 64 높이)")
		var ctrl := [st.minus_button, st.plus_button, st.revert_button, st.commit_button]
		for b in ctrl:
			check(_rect(st.desc).encloses(_rect(b)), "%s: %s 는 설명 띠 안" % [tag, b.name])
		for i in ctrl.size():
			for j in range(i + 1, ctrl.size()):
				check(not _rect(ctrl[i]).intersects(_rect(ctrl[j])), "%s: %s 와 %s 가 겹친다" % [tag, ctrl[i].name, ctrl[j].name])
		var boxes_end := st.level_box_rect(10).end.x
		check(boxes_end < st.minus_button.position.x, tag + ": 레벨 칸 1~10 은 「−」 왼쪽")
		check(st.desc_line_pos(PartySkillTab.LINES_PER_COL * 3 - 1).x + st.body_width() / 3.0 <= desc.size.x - PartySkillTab.BUTTONS_W, tag + ": 설명 줄은 단추 묶음 왼쪽")
		for d in [st.top, st.tree_window, st.class_tab, st.desc]:
			check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
		_check_targets(pm, size, tag + " 스킬")
		var snap := [win, desc, _rect(st.commit_button), st.node_rect(st.nodes.size() - 1)]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 노드 표시: 커서 = 밝은 알약, 다른 노드 = 짙은 파랑, 못 배움 = 어두운 회청.
	check_eq(st.nodes[st.cursor].theme_state(), "tree:selected", "커서 노드")
	var other := 1 if st.cursor != 1 else 0
	check(st.nodes[other].theme_state() in ["tree:normal", "tree:disabled"], "다른 노드 %s" % st.nodes[other].theme_state())
	# 초안 → 레벨 칸, 남은 SP 줄, 확정 창.
	var before := st.top.level_text
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft.size(), 1, "「+」 → 초안")
	check(st.level_boxes[1] == 1, "레벨 칸: 초안 1 칸 %s" % str(st.level_boxes))
	check(st._sp_label.text.contains("→"), "남은 SP 줄에 초안 뒤 값: %s" % st._sp_label.text)
	check_eq(st.top.level_text, before, "Lv 띠는 그대로")
	await kit.press_key(KEY_F)
	check_eq(pm.dialog_kind, "commit", "F → 확정 창")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_R)
	check_eq([pm.dialog_kind, st.draft], ["", {}], "닫고 되돌림")
	# 안내(거부 이유 등)는 정보 띠 가운데(확정 안내 자리)에 보인다(앞 틀의 알림 줄은 감춰져 있다).
	pm.show_notice(pm.reason_text("no_draft"))
	check(st._note_label.is_visible_in_tree() and st._note_label.text == pm.notice, "안내가 정보 띠에 보인다: %s" % st._note_label.text)
	pm._clear_notice()
	check_eq(st._note_label.text, s.texts.t("party.commit_note"), "안내가 지나면 확정 안내")
	# 대원 넘기기·뒤로.
	await kit.tap(kit.center_of(st.top.next_button))
	check_eq(pm.member, 2, "→ 단추 → 다음 대원")
	await kit.tap(kit.center_of(st.top.back_button))
	check_eq([pm.page, pm.camp_cursor], ["root", 1], "「뒤로」 → 캠프 뿌리(커서 스킬)")


# ---- 장비·소지품(R2-c, 원작 상점 화면 jp_guide3_img1~3) ----

## 상점 짜임의 공통 자리(1280×720 기준 실측 표, 넓은 창은 왼쪽이 넓어진다).
func _check_shop_frame(pm: PartyMenu, f: ShopFrame, size: Vector2, with_desc: bool, tag: String) -> void:
	var pw := CharPanel.W
	check_eq(_rect(f.back_button), Rect2(16, 18, 140, 64), tag + ": 「뒤로」 = 원작 다이얼 자리")
	check_eq(_rect(f.banner), Rect2(FacilityBanner.X, 0, size.x - pw - 8 - FacilityBanner.X, FacilityBanner.H), tag + ": 설명 띠 x 192 → 판 왼쪽")
	check_eq(_rect(f.title_plate), Rect2(0, 112, 340, 50), tag + ": 화면 이름 문패 = 원작 돈 문패 자리")
	var lw := _rect(f.list_window)
	var bottom := 500.0 if with_desc else size.y - 8
	check_eq(lw, Rect2(16, 172, size.x - pw - 24 - 16, bottom - 172), tag + ": 목록 창")
	check_eq(f.desc_window.is_visible_in_tree(), with_desc, tag + ": 설명 창 있음/없음")
	if with_desc:
		check_eq(_rect(f.desc_window), Rect2(16, 510, size.x - pw - 24 - 16, size.y - 8 - 510), tag + ": 설명 창 아래")
	check_eq(_rect(f.panel), Rect2(size.x - pw, 0, pw, size.y), tag + ": 인물 판 오른쪽 전체 높이")
	var parts := {"back": _rect(f.back_button), "banner": _rect(f.banner), "title": _rect(f.title_plate), "list": lw, "panel": _rect(f.panel)}
	if with_desc:
		parts["desc"] = _rect(f.desc_window)
	var keys := parts.keys()
	for i in keys.size():
		check(Rect2(Vector2.ZERO, size).encloses(parts[keys[i]]), "%s: %s 화면 안" % [tag, keys[i]])
		for j in range(i + 1, keys.size()):
			check(not (parts[keys[i]] as Rect2).intersects(parts[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
	var p := f.panel
	var pr := _rect(p)
	var inner := {"class": p.class_rect(), "totals": p.totals_rect()}
	for k in 4:
		inner["equip%d" % k] = p.equip_rect(k)
	var ik := inner.keys()
	for i in ik.size():
		var a: Rect2 = inner[ik[i]]
		check(Rect2(Vector2(0, MemberHeader.H), pr.size - Vector2(0, MemberHeader.H)).encloses(a), "%s: 판 %s 는 위 줄 아래·판 안" % [tag, ik[i]])
		for j in range(i + 1, ik.size()):
			check(not a.intersects(inner[ik[j]]), "%s: 판 %s 와 %s 가 겹친다" % [tag, ik[i], ik[j]])
	check_eq([_rect(p.prev_button()), _rect(p.next_button())], [Rect2(pr.position.x, 0, 64, 64), Rect2(pr.position.x + 266, 0, 64, 64)],
		tag + ": 판의 앞·다음 대원(원작 L·R)")
	for d in [f, f.banner, f.title_plate, f.list_window, f.desc_window, p, p.top, p.totals]:
		check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
	_check_targets(pm, size, tag)


func test_equip_screen_follows_the_shop_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	GrowthRules.supply(s.state, "equip.ion_saber", 1)
	GrowthRules.supply(s.state, "equip.nano_rod", 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	var et := pm.equip_tab
	var f := et.frame
	check_eq([pm.page, pm.tab, pm.member, et.list_open], ["sub", 2, 1, false], "준비: 듀얼리스트 A 장비")
	check(pm.find_child("Close", false, false) == null and pm.find_child("Tab_status", false, false) == null, "앞 틀 없음")
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s) 장비" % [str(px), str(size)]
		_check_shop_frame(pm, f, size, true, tag)
		var lw := _rect(f.list_window)
		for i in et.slot_rows.size():
			var r := _rect(et.slot_rows[i])
			check(lw.encloses(r) and r.size.y >= 64.0, "%s: 칸 %d %s 는 목록 창 안" % [tag, i, str(r)])
			if i > 0:
				check(not r.intersects(_rect(et.slot_rows[i - 1])), "%s: 칸 %d 와 %d 가 겹친다" % [tag, i - 1, i])
		var snap := [lw, _rect(f.panel), _rect(et.slot_rows[3])]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 닫힘: 칸 줄 = 장비 이름 + 오른쪽 칸 이름, 설명 창 = 커서 칸 장비, 띠 = 물음, 판 = 대원 값(견주지 않음), 커서 칸 표시.
	var m := s.state.party.members[1]
	check_eq([et.slot_rows[0].text, et.slot_rows[0].right], [pm.item_name(m.equip[0]), pm.slot_name(0)], "칸 줄 글")
	check_eq(f.desc_title, pm.item_name(m.equip[0]), "설명 창 = 커서 칸 장비")
	check_eq(f.banner.head, s.texts.t("camp.equip.slots"), "띠: 어느 칸을 바꿀까?")
	check_eq(f.title_text, s.texts.t("camp.cmd.equip"), "문패: 장비")
	check_eq([f.panel.drawn["name"], f.panel.drawn["mark"], et.totals.comparing], [pm.member_name(1), 0, false], "판: 이름·표시 칸·지금 값")
	check_eq((f.panel.drawn["equip"] as Array)[0][1], pm.item_name(m.equip[0]), "판 장비 줄")
	# 열림: 목록 창에 그 칸의 목록(칸 줄은 감춘다), 판은 「지금 → 바꾸면」, 설명 창 = 커서 줄.
	await kit.press_key(KEY_ENTER)
	check(et.list_open and et.list.is_visible_in_tree() and not et.slot_rows[0].is_visible_in_tree(), "Enter → 칸 0 목록(칸 줄 감춤)")
	check(_rect(f.list_window).encloses(_rect(et.list)), "목록은 목록 창 안")
	check_eq(f.banner.head, s.texts.t("camp.equip.list", {"slot": pm.slot_name(0)}), "띠: 무엇을 낄까?")
	var j := et.row_items.find("equip.ion_saber")
	for k in j:
		await kit.press_key(KEY_DOWN)
	check_eq([f.desc_title, et.totals.comparing], [pm.item_name("equip.ion_saber"), true], "설명 창 = 커서 줄, 판은 견준다")
	check(f.desc_lines.has(et.change_text(GrowthRules.profile(s.state.defs, 1, m), "equip.ion_saber")), "설명 창에 바뀌는 값: %s" % str(f.desc_lines))
	var b := et.row_items.find("equip.nano_rod")
	await kit.tap(kit.center_of(et.rows[b]))
	check_eq(f.banner.body, pm.reason_text(et.row_block[b]), "못 끼는 줄 → 띠 둘째 줄에 이유")
	check(f.banner.notice and f.desc_lines.has(pm.reason_text(et.row_block[b])), "이유는 안내 색, 설명 창에도")
	# 대원 넘기기(Q·판 단추)와 「뒤로」 두 단계.
	await kit.press_key(KEY_ESCAPE)
	check(not et.list_open and pm.page == "sub", "Esc → 목록만 닫힘")
	await kit.tap(kit.center_of(f.panel.next_button()))
	check_eq([pm.member, f.panel.drawn["name"]], [2, pm.member_name(2)], "판 → 단추 → 다음 대원")
	await kit.press_key(KEY_Q)
	check_eq(pm.member, 1, "Q → 앞 대원")
	await kit.tap(kit.center_of(f.back_button))
	check_eq([pm.page, pm.camp_cursor], ["root", 2], "「뒤로」 → 캠프 뿌리(커서 장비)")


func test_items_screen_follows_the_shop_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	GrowthRules.supply(s.state, "equip.ion_saber", 2)
	s.state.materials["item.neon_rat_tail"] = 3
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	var it := pm.items_tab
	var f := it.frame
	check_eq([pm.page, pm.tab], ["sub", 3], "준비: 소지품(대원 고르기 없음)")
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s) 소지품" % [str(px), str(size)]
		_check_shop_frame(pm, f, size, false, tag)
		check(_rect(f.list_window).encloses(_rect(it.list)), tag + ": 목록은 목록 창 안")
		check(_rect(it.list).encloses(_rect(it.supply_button)), tag + ": 「임시 보급」(디버그)은 목록 안")
	check_eq([f.banner.head, f.title_text], [s.texts.t("camp.desc.items"), s.texts.t("camp.cmd.items")], "띠·문패")
	var texts_shown := it._rows.filter(func(r: PartyButton) -> bool: return r.visible).map(func(r: PartyButton) -> String: return r.text)
	check(texts_shown.has(pm.item_name("equip.ion_saber")) and texts_shown.has(s.texts.t("item.neon_rat_tail")), "장비·소재 줄: %s" % str(texts_shown))
	for r in it._rows:
		if r.visible:
			check(r.skin == "fac" and r.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: 시설 모양, 읽기만" % r.name)
	check_eq(f.panel.drawn["name"], pm.member_name(pm.member), "판 = 지금 대원")
	await kit.press_key(KEY_E)
	check_eq(f.panel.drawn["name"], pm.member_name(1), "E → 판의 대원이 바뀐다")
	await kit.tap(kit.center_of(f.back_button))
	check_eq([pm.page, pm.camp_cursor], ["root", 3], "「뒤로」 → 캠프 뿌리(커서 소지품)")


# ---- 기록(R2-d, 원작 불러오기 화면 gs2_653240) ----

func test_records_screen_follows_the_load_screen_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	var rt := pm.records_tab
	s._save_slot("slot1")
	await kit.frames(2)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab, s.modal.kind], ["sub", 4, ""], "준비: 기록 화면")
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s) 기록" % [str(px), str(size)]
		check_eq(_rect(rt.title_plate), Rect2(0, 36, 272, 56), tag + ": 이름 문패 = 원작 「Load Game」 자리")
		check_eq(_rect(rt.back_button), Rect2(size.x - 128, 18, 120, 64), tag + ": 「뒤로」 오른쪽 위(원작 DELETE 안내 자리)")
		var win := _rect(rt.window)
		check_eq(win, Rect2(size.x / 2.0 - 470, 100, 940, 494), tag + ": 슬롯 창 가운데 940 폭, y 100~594")
		var band := _rect(rt.band)
		check(band.position.y >= win.end.y and band.end.y <= size.y, tag + ": 아래 띠는 슬롯 창 아래, 화면 안")
		var parts := {"title": _rect(rt.title_plate), "back": _rect(rt.back_button), "window": win, "band": band}
		var keys := parts.keys()
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				check(not (parts[keys[i]] as Rect2).intersects(parts[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
		for i in 3:
			var card := Rect2(win.position + rt.card_rect(i).position, rt.card_rect(i).size)
			check(win.encloses(card), "%s: 카드 %d 는 창 안" % [tag, i])
			for b in [rt.save_buttons[i], rt.load_buttons[i]]:
				check(card.encloses(_rect(b)), "%s: %s 는 카드 %d 안" % [tag, b.name, i])
			if i > 0:
				check(not card.intersects(Rect2(win.position + rt.card_rect(i - 1).position, rt.card_rect(i - 1).size)), "%s: 카드 겹침" % tag)
		for b in rt.band_buttons:
			check(band.encloses(_rect(b)), "%s: %s 는 아래 띠 안" % [tag, b.name])
		for d in [rt, rt.title_plate, rt.window, rt.band]:
			check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
		_check_targets(pm, size, tag)
		var snap := [win, band, _rect(rt.load_buttons[2])]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 카드 값(저장에 있는 값)·버튼 이름(앞 메뉴 창과 같은 이름: web_check 가 누른다).
	check_eq(rt.card_lines(0)[1], "%s · 걸음 %d" % [s.texts.t(s.state.floor_def.name_key), s.state.steps], "카드 1: 층 · 걸음")
	check_eq([str(rt.save_buttons[0].name), str(rt.load_buttons[0].name), rt.band_buttons.map(func(b: PartyButton) -> String: return str(b.name))],
		["Save_slot1", "Load_slot1", ["Export", "Import", "Automap_off", "Automap_floor", "Automap_full", "NewGame"]], "단추 이름")
	# 저장(카드 2, 포인터) → 카드가 채워지고 커서가 그 단추로.
	await kit.tap(kit.center_of(rt.save_buttons[1]))
	check(s.store.load_slot("slot2").ok() and rt.card_lines(1)[0] != s.texts.t("menu.empty_slot") and not rt.load_buttons[1].disabled, "저장 → 카드 2 채움")
	check_eq([rt.cur_row, rt.cur_col, pm.is_open(), pm.tab], [1, 0, true, 4], "저장 뒤 기록 화면 그대로, 커서는 누른 단추")
	# 자동 지도(키보드: ↓ 줄, → 칸, Enter).
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	for k in 4:
		await kit.press_key(KEY_RIGHT)
	check(rt.cursor_button().name == "Automap_full", "커서: %s" % rt.cursor_button().name)
	await kit.press_key(KEY_ENTER)
	check(s.settings.automap == "full" and rt.band_buttons[4].checked and not rt.band_buttons[3].checked, "Enter → 자동 지도 바닥+벽(켜짐 표시)")
	await kit.tap(kit.center_of(rt.band_buttons[3]))
	check_eq(s.settings.automap, "floor", "단추 → 자동 지도 바닥만")
	# 파일(네이티브): 내보내기·가져오기는 파일 고르기 창(층 3)을 캠프 위에 띄우고, 그동안 캠프는 키를 받지 않는다.
	await kit.tap(kit.center_of(rt.band_buttons[1]))
	check(s.modal.kind == "file" and pm.is_open(), "가져오기 → 파일 고르기 창(캠프는 뒤에)")
	await kit.press_key(KEY_ESCAPE)
	check(pm.is_open() and pm.tab == 4, "창이 떠 있는 동안 캠프는 키를 받지 않는다")
	s._finish_file_request()
	await kit.frames(2)
	check_eq(s.modal.kind, "", "준비: 파일 창 닫힘")
	# 새 게임: 캠프 확인 창(처음은 「돌아가기」), 확정하면 캠프를 닫고 새 상태.
	var h := kit.hash_now()
	await kit.tap(kit.center_of(rt.band_buttons[5]))
	check_eq([pm.dialog_kind, pm.dialog_pick, pm._dialog_text.text], ["new_game", 0, s.texts.t("menu.confirm_new_game")], "새 게임 → 확인 창")
	await kit.press_key(KEY_ESCAPE)
	check(pm.dialog_kind == "" and pm.is_open() and kit.hash_now() == h, "Esc = 「돌아가기」: 그대로")
	GrowthRules.grant_exp(s.state, 0, 10)
	var n := s.autosave_count
	await kit.tap(kit.center_of(rt.band_buttons[5]))
	await kit.tap(kit.center_of(pm.dialog_buttons[1]))
	check(not pm.is_open() and s.state.party.members[0].exp == 0 and s.autosave_count == n + 1, "「새 게임」 → 캠프 닫힘, 새 상태 자동 저장")
	# 불러오기: 저장 칸 1 로 돌아간다(캠프를 닫는다).
	var saved := SaveCodec.state_hash(s.store.load_slot("slot1").result.state)
	GrowthRules.grant_exp(s.state, 0, 10)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	await kit.tap(kit.center_of(rt.load_buttons[0]))
	check(not pm.is_open() and kit.hash_now() == saved, "불러오기 → 캠프 닫힘, 저장 칸 1 상태")
	# 빈 칸 불러오기는 못 누름.
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	await kit.tap(kit.center_of(rt.load_buttons[2]))
	check(pm.is_open() and pm.tab == 4, "빈 칸 불러오기: 아무 일도 없다")


# ---- 바깥 창(층 3)과 누르고 있던 캠프 단추(R2 리뷰 고침 1) ----

## 웹 가져오기의 보통 결과 경로(_on_import_result)로 오류 알림 창을 띄운다(파일 전송 자체는 흉내 내지 않는다).
func _import_error(s: DungeonScreen) -> void:
	s._import_token += 1
	s._import_epoch = s._epoch
	s._on_import_result(s._import_token, "error", "")
	await kit.frames(2)


## 저장 칸의 [상태 해시, 세대, 저장 시각](비었으면 []).
static func _slot_sig(s: DungeonScreen, slot: String) -> Array:
	var l := s.store.load_slot(slot)
	return [SaveCodec.state_hash(l.result.state), l.result.generation, l.result.saved_at] if l.ok() else []


func _dismiss_alert(s: DungeonScreen) -> void:
	await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)), 7)


## 기록의 「저장」「불러오기」를 누른 채 바깥 알림이 뜬다: 알림이 덮은 채 떼도, 다른 손가락으로 알림을 닫은 뒤 떼도 아무 일도 없다
## (있던 수동 저장을 덮어쓰거나 불러오지 않는다). 실제 손가락 누르기·떼기(scene kit), 저장은 시험 임시 폴더에만.
func test_held_records_button_does_nothing_after_an_external_alert() -> void:
	var s := await _open()
	var pm := s.party_menu
	var rt := pm.records_tab
	s._save_slot("slot1")
	await kit.frames(2)
	GrowthRules.grant_exp(s.state, 0, 10)  # 지금 진행은 저장 칸 1 과 다르다
	s._autosave(true)
	var sig := _slot_sig(s, "slot1")
	check(not sig.is_empty() and sig[0] != kit.hash_now(), "준비: 있던 수동 저장(지금과 다르다)")
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab], ["sub", 4], "준비: 기록")
	for c in [["save", true], ["save", false], ["load", true], ["load", false]]:
		var b: PartyButton = (rt.save_buttons if c[0] == "save" else rt.load_buttons)[0]
		var tag := "%s 누른 채 알림 → %s" % [b.name, "알림이 덮은 채 뗌" if c[1] else "다른 손가락으로 알림을 닫고 뗌"]
		var h := kit.hash_now()
		var gen := s.state.generation
		var n := s.autosave_count
		var p := kit.center_of(b)
		kit.touch(4, p, true)
		await kit.frames(2)
		check(b.held, tag + ": 준비: 눌림")
		await _import_error(s)
		check(s.modal.kind == "alert" and not b.held, tag + ": 알림이 뜨면 캠프 눌림을 버린다")
		check(not pm.handle("record_save", 0), tag + ": 알림이 떠 있으면 캠프 입구가 어떤 입력도 받지 않는다")
		if not c[1]:
			await _dismiss_alert(s)
			check_eq(s.modal.kind, "", tag + ": 준비: 다른 손가락으로 알림 닫음")
		kit.touch(4, p, false)
		await kit.frames(3)
		check_eq(_slot_sig(s, "slot1"), sig, tag + ": 저장 칸 1 해시·세대·시각 그대로")
		check_eq([kit.hash_now(), s.state.generation, s.autosave_count], [h, gen, n], tag + ": 상태·세대·자동 저장 그대로")
		check(pm.is_open() and pm.page == "sub" and pm.tab == 4, tag + ": 기록 화면 그대로")
		if s.modal.is_open():
			await _dismiss_alert(s)


## 다른 캠프 쪽에서도: 누르고 있던 단추는 바깥 창이 열리고 닫힌 뒤 떼도 일하지 않는다.
func test_held_camp_button_on_another_page_does_nothing_after_an_external_window() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ENTER)
	var et := pm.equip_tab
	check_eq([pm.page, pm.tab, et.list_open], ["sub", 2, false], "준비: 장비 화면")
	var h := kit.hash_now()
	var p := kit.center_of(et.slot_rows[1])
	kit.touch(4, p, true)
	await kit.frames(2)
	check(et.slot_rows[1].held, "준비: 칸 1 누름")
	s._alert("시험 알림")
	await kit.frames(2)
	check(not et.slot_rows[1].held, "바깥 창이 뜨면 눌림을 버린다")
	await _dismiss_alert(s)
	kit.touch(4, p, false)
	await kit.frames(3)
	check_eq([et.list_open, et.cursor, pm.accepted_inputs > 0], [false, 0, true], "창을 닫고 떼도 칸 1 목록이 열리지 않는다")
	check_eq(kit.hash_now(), h, "상태 그대로")
	# 캠프 뿌리의 명령 줄도(알림이 덮은 채 뗌).
	await kit.press_key(KEY_ESCAPE)
	var row := kit.center_of(pm.camp_list.rows[1])
	kit.touch(4, row, true)
	await kit.frames(2)
	s._alert("시험 알림")
	await kit.frames(2)
	kit.touch(4, row, false)
	await kit.frames(3)
	check_eq([pm.page, pm.camp_cursor], ["root", 2], "알림이 덮은 채 떼도 「스킬」 줄은 일하지 않는다")
	await _dismiss_alert(s)


# ---- 글자 대비 ----

func test_camp_and_status_colours_meet_contrast() -> void:
	var pairs := [
		["띠 글자", UiTheme.BATTLE_BANNER_TEXT, [UiTheme.FAC_BANNER_TOP, UiTheme.FAC_BANNER_BOTTOM]],
		["띠 안내", UiTheme.BATTLE_BANNER_NOTICE, [UiTheme.FAC_BANNER_TOP, UiTheme.FAC_BANNER_BOTTOM]],
		["이름 칸", UiTheme.ST_NAME_TEXT, [UiTheme.ST_NAME_TAB]],
		["Lv", UiTheme.ST_LV_TEXT, [UiTheme.ST_LV_BAND]],
		["Lv 띠 글자", UiTheme.TEXT, [UiTheme.ST_LV_BAND]],
		["정보 띠", UiTheme.TEXT, [UiTheme.ST_INFO_TOP, UiTheme.ST_INFO_BOTTOM]],
		["정보 띠 TP", UiTheme.ST_LV_TEXT, [UiTheme.ST_INFO_TOP, UiTheme.ST_INFO_BOTTOM]],
		["정보 띠 이름표", UiTheme.CARD_LABEL, [UiTheme.ST_INFO_TOP, UiTheme.ST_INFO_BOTTOM]],
		["직업 문패", UiTheme.TEXT, [UiTheme.ST_CLASS_PLATE]],
		["능력치 이름", UiTheme.TEXT, [UiTheme.ST_ROW_NAME, UiTheme.ST_ROW]],
		["공격·방어", UiTheme.TEXT, [UiTheme.ST_GEAR_LABEL, UiTheme.ST_GEAR_VALUE]],
		["장비 줄", UiTheme.TEXT, [UiTheme.ST_EQUIP_ROW]],
		["장비 칸 이름", UiTheme.SUB_TEXT, [UiTheme.ST_ROW_NAME]],
		["받는 배율 머리", UiTheme.TEXT, [UiTheme.ST_SIDE_TOP, UiTheme.ST_SIDE_BOTTOM]],
		["받는 배율 줄", UiTheme.CARD_TP, [UiTheme.ST_SIDE_TOP, UiTheme.ST_SIDE_BOTTOM]],
		["내역 머리", UiTheme.SUB_TEXT, [UiTheme.ST_ROW]],
		["시설 목록 글자", UiTheme.FAC_TEXT, [UiTheme.CMD_TOP, UiTheme.CMD_BOTTOM]],
		# 스킬 트리 화면(파랑): 위 줄, 직업 탭, 트리 창·설명 띠(반투명 창은 불투명으로 본다), 레벨 칸.
		["트리 이름 칸", UiTheme.TREE_NAME_TEXT, [UiTheme.TREE_NAME_TAB]],
		["트리 Lv", UiTheme.ST_LV_TEXT, [UiTheme.TREE_LV_BAND]],
		["트리 정보 띠", UiTheme.TEXT, [UiTheme.TREE_INFO_TOP, UiTheme.TREE_INFO_BOTTOM]],
		["트리 확정 안내", UiTheme.ST_LV_TEXT, [UiTheme.TREE_INFO_TOP, UiTheme.TREE_INFO_BOTTOM]],
		["직업 탭", UiTheme.TEXT, [UiTheme.TREE_TAB]],
		["설명 글", UiTheme.TEXT, [Color(UiTheme.TREE_WIN_TOP, 1.0), Color(UiTheme.TREE_WIN_BOTTOM, 1.0)]],
		["설명 종류 줄", UiTheme.TREE_KIND_TEXT, [Color(UiTheme.TREE_WIN_TOP, 1.0), Color(UiTheme.TREE_WIN_BOTTOM, 1.0)]],
		["레벨 칸(배움)", UiTheme.TREE_LV_BOX_TEXT, [UiTheme.TREE_BOX_LEARNED, UiTheme.TREE_LV_BOX]],
		["레벨 칸(초안)", UiTheme.TREE_LV_BOX_TEXT, [UiTheme.TREE_BOX_DRAFT]],
		["레벨 칸(빈)", UiTheme.TREE_BOX_EMPTY_TEXT, [UiTheme.TREE_BOX_EMPTY]],
		["트리 안내", PartyMenu.NOTICE_TEXT, [UiTheme.TREE_INFO_TOP, UiTheme.TREE_INFO_BOTTOM]],
		# 상점 짜임(장비·소지품): 목록·설명 창(반투명은 불투명으로 본다), 설명 머리 띠, 인물 판의 능력치·장비 줄.
		["상점 창 글", UiTheme.TEXT, [Color(UiTheme.SHOP_WIN_TOP, 1.0), Color(UiTheme.SHOP_WIN_BOTTOM, 1.0), UiTheme.SHOP_DESC_HEAD]],
		["상점 창 묶음 이름", UiTheme.SHOP_SECTION_TEXT, [Color(UiTheme.SHOP_WIN_TOP, 1.0), Color(UiTheme.SHOP_WIN_BOTTOM, 1.0)]],
		["능력치 이름", EquipTotals.NAME_COLOR, [UiTheme.ST_ROW_NAME, UiTheme.ST_GEAR_LABEL]],
		["능력치 값", EquipTotals.VALUE_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["능력치 오름", EquipTotals.UP_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["능력치 내림", EquipTotals.DOWN_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["판 장비 줄", UiTheme.TEXT, [UiTheme.ST_EQUIP_ROW]],
		["판 빈 장비", UiTheme.SUB_TEXT, [UiTheme.ST_EQUIP_ROW, UiTheme.ST_ROW_NAME]],
	]
	for p in pairs:
		for bg in p[2]:
			var c := contrast(p[1], bg)
			check(c >= 4.5, "%s: %s on %s = %.2f ≥ 4.5" % [p[0], (p[1] as Color).to_html(false), (bg as Color).to_html(false), c])
	var lk := UiTheme.look("cmd:chosen")
	check(contrast(lk["text"], lk["top"]) >= 4.5, "고른 명령 줄")
