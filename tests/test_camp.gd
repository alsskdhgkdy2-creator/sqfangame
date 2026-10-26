## 캠프 시험(M2.7 R2, 07 §9, research 05 §2.2·07 §2): 입구(안내 줄 「캠프」·P·Esc), 캠프 뿌리(원작 HD 실물에 맞춘 층 표, 07 §9.8 D26),
## 바탕(뿌리·고르기 = 무늬 판과 그림 창, 하위 화면 = CAMP_DIM), 대원 고르기(파티 카드, 커서 카드만 노란 테두리), 상태 화면(원작 상태 화면 배치), 기록, 보이는 위아래 = 누르는 위아래, 64px, 글자 대비.
## 층 표(1280×720 기준, 1728×720 도 같은 규칙, 오른쪽 것은 오른쪽 끝 기준): 걸음 문패 0,0 176×66(원작 시계 다이얼 자리),
## 장소 띠 x 176 → W − 328·y 0~66, 소지금 (W − 328, 16) 328×50, 알림 줄 x 176 → W − 16·y 70~108(알림이 있을 때만),
## 명령 목록 x 0~430·y 116~472(줄 64, 간격 6, 1 소지품 · 2 상태 · 3 장비 · 4 스킬 · 5 기록), 파티 카드 아래 두 줄(윗줄 = 전열).
## 저장은 장면 시험 임시 폴더에만.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fixtures := preload("res://tests/fixtures.gd")
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
const FINGER := 3
## 명령 줄 번호(07 §9.8 ②, PartyMenu.CAMP_KEYS 차례). 숫자 키는 줄 번호 + 1.
const ITEMS := 0
const STATUS := 1
const EQUIP := 2
const SKILLS := 3
const RECORDS := 4

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


## 지금 보이는 노랑 채움(커서 줄·고른 단추: selected 인 TouchButton) 이름.
static func _yellow(pm: PartyMenu) -> Array:
	return pm.find_children("*", "TouchButton", true, false).filter(
		func(b: Node) -> bool: return (b as TouchButton).selected and (b as TouchButton).is_visible_in_tree()).map(
		func(b: Node) -> String: return str(b.name))


## 글이 폭 w 안에 다 들어가는지(잘리지 않음).
static func _fits(c: Control, t: String, fs: int, w: float) -> bool:
	return c.get_theme_default_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w


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
	# 디버그 실행이라 상점 임시 입구(08 §8.1, D24)가 끝에 붙는다. 디버그가 아니면 「캠프」「지도」 둘(test_shop_screen).
	check_eq(shown, [s.camp_button, s.map_button, s.shop_button], "안내 줄 = 「캠프」「지도」(원작 CAMP · MAP) + 디버그 「상점」")
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

func test_camp_root_follows_the_layer_table_at_both_sizes() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	var first := {}
	for px in WINDOWS + [WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var w := size.x
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 3D 시야는 화면 전체")
		# 맨 위 띠(07 §9.8 ③): 설명 띠 대신 걸음 문패·장소 띠·소지금·알림 줄.
		check(pm.get_children().filter(func(c: Node) -> bool: return c is FacilityBanner).is_empty(), tag + ": 설명 띠(FacilityBanner)가 없다")
		var plate := _rect(pm.camp_plate)
		var ribbon := _rect(pm.ribbon)
		var money := _rect(pm.money_plate)
		check_eq(plate, Rect2(0, 0, 176, 66), tag + ": 걸음 문패 = 원작 시계 다이얼 자리 0,0 176×66")
		check_eq([pm.camp_plate.first, pm.camp_plate.second], [s.texts.t("hud.steps", {"steps": s.state.steps}), ""], tag + ": 걸음 문패 글")
		check_eq(ribbon, Rect2(176, 0, w - 176 - 328, 66), tag + ": 장소 띠 x 176 → 소지금 왼쪽 끝, y 0~66")
		check_eq(pm.ribbon.text, s.texts.t(s.state.floor_def.name_key), tag + ": 장소 띠 글 = 층 이름")
		check_eq(money, Rect2(w - 328, 16, 328, 50), tag + ": 소지금 (W − 328, 16) 328×50")
		check_eq(pm.money_text(), s.texts.t("shop.money", {"money": ShopRow.grouped(s.state.money)}), tag + ": 소지금 글 = 상점과 같은 「n엔」")
		check(not ribbon.intersects(money) and not plate.intersects(ribbon) and not plate.intersects(money), tag + ": 걸음 문패·장소 띠·소지금이 겹치지 않는다")
		check(_fits(pm.ribbon, pm.ribbon.text, PlaceRibbon.FS, pm.ribbon.text_width()), tag + ": 장소 띠 글이 잘리지 않는다")
		check(_fits(pm.money_plate, pm.money_text(), ShopFrame.TITLE_FS, money.size.x - ShopFrame.TITLE_RIGHT_PAD - UiTheme.PLATE_SLANT),
			tag + ": 소지금 글이 잘리지 않는다")
		check(_fits(pm.camp_plate, pm.camp_plate.first, 22, plate.size.x - 32.0), tag + ": 걸음 글이 잘리지 않는다")
		check(not pm.notice_line.visible, tag + ": 알림이 없으면 알림 줄은 감춘다")
		check_eq(_rect(pm.notice_line), Rect2(176, 70, w - 192, 38), tag + ": 알림 줄 x 176 → W − 16, y 70~108")
		var lr := _rect(pm.camp_list)
		check_eq(lr, Rect2(0, 116, 430, FacilityList.content_height(5)), tag + ": 명령 목록 x 0~430, y 116~472(P3: 「6 닫기」 줄 없음)")
		check(lr.end.y <= 472.0 + 0.5, tag + ": 목록 아래 끝 472 %s" % str(lr))
		check(lr.position.y >= _rect(pm.notice_line).end.y and not lr.intersects(plate), tag + ": 목록은 맨 위 띠·알림 줄 아래")
		var rows := pm.camp_list.rows
		check_eq(rows.size(), 5, tag + ": 명령 다섯(닫기는 「취소」·Esc·P·6)")
		check_eq(PartyMenu.CAMP_KEYS.slice(0, 5), ["items", "status", "equip", "skills", "records"], tag + ": 차례 1 소지품 · 2 상태 · 3 장비 · 4 스킬 · 5 기록")
		for i in rows.size():
			var r := _rect(rows[i])
			check(r.size.y >= 64.0 and r.size.x >= 64.0, "%s: 줄 %d %s ≥ 64" % [tag, i, str(r.size)])
			check(lr.encloses(r), "%s: 줄 %d 는 목록 안" % [tag, i])
			check_eq(rows[i].text, "%d  %s" % [i + 1, s.texts.t("camp.cmd." + PartyMenu.CAMP_KEYS[i])], "%s: 줄 %d 글" % [tag, i])
			check(_fits(rows[i], rows[i].text, 30, r.size.x - 40.0), "%s: 줄 %d 글이 잘리지 않는다" % [tag, i])
			var e := rows[i].right_edge()
			var to_list := rows[i].position
			check(absf(e.x + to_list.x - pm.camp_list.arc_x(to_list.y)) < 0.5, "%s: 줄 %d 오른쪽 끝이 원호 위" % [tag, i])
			if i > 0:
				check(r.position.y >= _rect(rows[i - 1]).end.y, "%s: 줄 %d 가 앞 줄 아래" % [tag, i])
		check_eq(rows[ITEMS].theme_state(), "fac:selected", tag + ": 커서 줄(열 때 0 = 소지품) = 노랑(짙은 글자)")
		check_eq(rows[STATUS].theme_state(), "fac:normal", tag + ": 다른 줄 = 청록 + 시설 물빛 글자")
		check_eq(_yellow(pm), [str(rows[ITEMS].name)], tag + ": 뿌리의 노랑 채움은 커서 줄 하나")
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
			check_eq(cards[i].target_mark, "", "%s: 뿌리에서 카드 %d 는 표지 없음" % [tag, i])
		check(lr.end.y < top_y, "%s: 목록 아래 %s < 카드 위 %s" % [tag, lr.end.y, top_y])
		# 키패드: 화면 안, 목록·카드·맨 위 띠와 겹치지 않는다.
		for p in [pm.dir_pad, pm.key_pad]:
			var pr := _rect(p)
			check(Rect2(Vector2.ZERO, size).encloses(pr), "%s: %s 는 화면 안" % [tag, p.name])
			var hit := [lr, ribbon, money, plate].any(func(o: Rect2) -> bool: return pr.intersects(o))
			hit = hit or cards.any(func(c: Control) -> bool: return pr.intersects(_rect(c)))
			check(not hit, "%s: %s %s 는 목록·카드·맨 위 띠와 겹치지 않는다" % [tag, p.name, str(pr)])
		for c in [pm.camp_plate, pm.ribbon, pm.money_plate, pm.notice_line, pm.cards]:
			check_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식(IGNORE)" % [tag, c.name])
		_check_targets(pm, size, tag + " 뿌리")
		var snap := [lr, ribbon, money, _rect(pm.notice_line), _rect(cards[0]), _rect(cards[4])]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap


## 알림 줄(07 §9.8 ③): 알림이 있을 때만 장소 띠 아래에 뜨고, 규칙(남는 시간·고르기·하위 화면·다시 열기에서 비움)은 그대로다.
func test_notice_line_shows_and_clears_by_the_notice_rules() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	pm.show_notice("첫 줄\n둘째 줄")
	await kit.frames(1)
	check(pm.notice_line.is_visible_in_tree(), "알림 → 알림 줄이 보인다")
	check_eq(pm.notice_line_text(), "첫 줄   둘째 줄", "두 줄 알림은 한 줄로 잇는다")
	var snap: Dictionary = s.debug_snapshot()["party_menu"]
	check_eq([snap["notice"], snap["ribbon"], snap["money"]], ["첫 줄\n둘째 줄", pm.ribbon.text, pm.money_text()], "스냅숏 notice·ribbon·money")
	check(not snap.has("banner"), "스냅숏에 banner 가 없다")
	check(_rect(pm.notice_line).end.y <= _rect(pm.camp_list).position.y and not _rect(pm.notice_line).intersects(_rect(pm.money_plate)),
		"알림 줄은 소지금·목록과 겹치지 않는다")
	pm._process(PartyMenu.NOTICE_SEC + 0.1)
	await kit.frames(1)
	check(pm.notice.is_empty() and not pm.notice_line.visible, "남는 시간이 지나면 사라진다")
	pm.show_notice("고르기 전 알림")
	await kit.press_key(KEY_2)
	check(pm.page == "pick" and pm.notice.is_empty() and not pm.notice_line.visible, "대원 고르기로 가면 비운다(지금 규칙)")
	pm.show_notice("고르기 중 알림")
	await kit.frames(1)
	check(pm.notice_line.is_visible_in_tree(), "고르기 중 알림도 알림 줄에")
	await kit.press_key(KEY_ENTER)
	check(pm.page == "sub" and not pm.notice_line.is_visible_in_tree(), "하위 화면은 제 자리에 알림을 보이고 알림 줄은 감춘다")
	pm.show_notice("하위 화면 알림")
	await kit.press_key(KEY_ESCAPE)
	check(pm.page == "root" and pm.notice_line.is_visible_in_tree() and pm.notice_line_text() == "하위 화면 알림",
		"뿌리로 돌아오면 남은 알림이 알림 줄에(지금 규칙: 돌아올 때 비우지 않는다)")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_P)
	check(pm.notice.is_empty() and not pm.notice_line.visible, "다시 열면 비어 있다")


func test_taps_go_to_the_visible_top_in_the_camp() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	pm.show_notice("알림 줄 누르기 시험")
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := str(px)
		for spot in [_rect(pm.ribbon).get_center(), _rect(pm.money_plate).get_center(), _rect(pm.camp_plate).get_center(),
				_rect(pm.notice_line).get_center(), Vector2(size.x * 0.7, size.y * 0.45), _rect(pm.cards.cards[0]).get_center()]:
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
		pm.handle("camp", STATUS)
		await kit.frames(2)
		for c in pm.cards.cards:
			var got := await _receiver_at(_rect(c).get_center())
			check(got == c, "%s 고르기: %s → 카드, 실제 %s" % [tag, c.name, _name_of(got)])
		_check_targets(pm, size, tag + " 고르기")
		pm.handle("back")
		await kit.frames(2)


# ---- 바탕: 무늬 판과 그림 창(07 §9.8 ④, C2) ----

## 뿌리·대원 고르기는 무늬 판(CAMP_DIM 없음), 하위 화면은 CAMP_DIM(판 없음). 판은 트리 맨 뒤(다른 캠프 부품이 모두 앞), 장식(IGNORE).
## 바탕(07 §9.8 ④, §9.9 E1 ①): 캠프의 모든 화면(뿌리·고르기·하위 화면 다섯·확인 창 셋)이 무늬 판이고 CAMP_DIM 을 그리지 않는다.
func _check_board(s: DungeonScreen, tag: String) -> void:
	var pm := s.party_menu
	await kit.frames(2)
	check_eq(pm.backdrop(), "board", tag + ": 바탕 board")
	check_eq([pm.backdrop_board.is_visible_in_tree(), pm.drawn_dim], [true, false], tag + ": 판 보임·CAMP_DIM 그리지 않음")
	check_eq(s.debug_snapshot()["party_menu"]["backdrop"], "board", tag + ": 스냅숏 backdrop")
	check_eq(pm.dialog_dim.is_visible_in_tree(), not pm.dialog_kind.is_empty(), tag + ": 어둡게 하는 판은 확인 창이 있을 때만")


## 확인 창(07 §9.9 E1 ①): 창 바로 뒤에 화면 전체를 어둡게 하는 판(ColorRect dialog_dim). 하위 화면 앞, 창·키패드 뒤, 빈 곳 누르기를 받는다.
func _check_dialog_dim(pm: PartyMenu, size: Vector2, tag: String) -> void:
	await kit.frames(2)
	var dim := pm.dialog_dim
	check(dim.is_visible_in_tree(), tag + ": 어둡게 하는 판이 보인다")
	check_eq(_rect(dim), Rect2(Vector2.ZERO, size), tag + ": 어둡게 하는 판은 화면 전체")
	check(dim.color.a >= 0.5 and dim.color == PartyMenu.DIALOG_DIM, tag + ": 어둡게(색 %s)" % str(dim.color))
	check_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP, tag + ": 어둡게 하는 판은 누르기를 막는다")
	var dl := pm.dialog_layer
	for t in pm.tabs:
		check(t.get_index() < dl.get_index(), "%s: %s 는 어둡게 하는 판 뒤" % [tag, t.name])
	check(pm.backdrop_board.get_index() < dl.get_index() and dl.get_index() < pm.dir_pad.get_index(), tag + ": 판 → 확인 창 층 → 키패드")
	check(dim.get_index() < pm.dialog_panel.get_index() and pm.dialog_panel.get_index() < pm.dialog_buttons[0].get_index(),
		tag + ": 층 안에서 어둡게 → 창 → 단추")
	check(Rect2(Vector2.ZERO, size).encloses(_rect(pm.dialog_panel)) and pm.dialog_panel.is_visible_in_tree(), tag + ": 창은 화면 안")
	var got := await _receiver_at(Vector2(20, 20))
	check(got == dim, "%s: 빈 곳(20, 20) 누르기 → 어둡게 하는 판, 실제 %s" % [tag, _name_of(got)])


func test_backdrop_is_the_board_on_every_camp_screen_and_dialogs_dim_behind() -> void:
	var s := await _open()
	var pm := s.party_menu
	var board := pm.backdrop_board
	GrowthRules.grant_exp(s.state, 0, s.state.defs.battle.growth.cum(3))
	var size: Vector2 = await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(pm.get_child(0), board, "판은 캠프 트리 맨 뒤")
	for c in [pm.cards, pm.camp_plate, pm.ribbon, pm.money_plate, pm.notice_line, pm.camp_list, pm.dir_pad, pm.key_pad] + pm.tabs:
		check(board.get_index() < (c as Control).get_index(), "%s 는 판 앞" % c.name)
	check_eq(board.mouse_filter, Control.MOUSE_FILTER_IGNORE, "판은 장식(IGNORE)")
	var steps := [["뿌리", []], ["대원 고르기", [KEY_2]], ["상태 화면", [KEY_ENTER]], ["뿌리로", [KEY_ESCAPE]],
		["소지품", [KEY_1]], ["뿌리로", [KEY_ESCAPE]], ["장비 고르기", [KEY_3]], ["장비 칸", [KEY_ENTER]], ["장비 목록", [KEY_ENTER]],
		["장비 칸으로", [KEY_ESCAPE]], ["뿌리로", [KEY_ESCAPE]], ["스킬", [KEY_4, KEY_ENTER]], ["뿌리로", [KEY_ESCAPE]], ["기록", [KEY_5]]]
	for st in steps:
		for k in st[1]:
			await kit.press_key(k)
		await _check_board(s, st[0])
	check_eq([pm.page, pm.tab], ["sub", 4], "준비: 기록")
	# 확인 창 셋: 새 게임(기록), 확정·버리기(스킬 초안).
	await kit.tap(kit.center_of(pm.records_tab.band_buttons[5]))
	check_eq(pm.dialog_kind, "new_game", "준비: 새 게임 확인 창")
	await _check_board(s, "새 게임 창")
	await _check_dialog_dim(pm, size, "새 게임 창")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_4)
	await kit.tap(kit.center_of(pm.skill_tab.plus_button))
	await kit.press_key(KEY_F)
	check_eq(pm.dialog_kind, "commit", "준비: 확정 창")
	await _check_board(s, "확정 창")
	await _check_dialog_dim(pm, size, "확정 창")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check_eq(pm.dialog_kind, "discard", "준비: 버리기 창")
	await _check_board(s, "버리기 창")
	await _check_dialog_dim(pm, size, "버리기 창")
	for px in [Vector2(2400, 1000), Vector2(1280, 960)]:
		var sz: Vector2 = await _window(px)
		await _check_dialog_dim(pm, sz, "버리기 창 %s(논리 %s)" % [str(px), str(sz)])
	await kit.press_key(KEY_ESCAPE)
	await _check_board(s, "버리기 창 닫음")
	check(not board.drawn.is_empty() and int(board.drawn["leaves"]) > 0, "판을 그렸다(덩굴 잎 포함)")


## 그림 창 시험의 표본 점 [창 안, 창 밖](폭 w·높이 h). 모두 창 경계에서 8px 넘게 떨어져 있다(가장 가까운 것 10px, 굽은 끝 W − 308 기준).
static func _window_samples(w: float, h: float) -> Array:
	var inside := [Vector2(600, 300), Vector2(10, 130), Vector2(w - 50, 130), Vector2(w - 420, 495), Vector2(200, 495), Vector2(w - 300, 480)]
	var outside := [Vector2(600, 100), Vector2(600, 520), Vector2(w - 20, 300), Vector2(w - 150, 480), Vector2(w - 20, 130), Vector2(100, h - 20),
		Vector2(w - 5, 10), Vector2(w - 150, 500)]
	return [inside, outside]


## 원작 대조(조정자 측정): III HD 캠프 뿌리 프레임 yt_eo3hd_02_town_camp_root_custom_cursor.png(1280×720)에서 줄마다 무늬 판이
## 시작하는 x(/tmp/sqf_coord/camp/orig_edge_points.txt). 폭 1280 의 window_right 는 y 250~450 에서 그 값의 4px 안이다.
func test_window_curve_follows_the_measured_original() -> void:
	var measured := {250: 1229.5, 300: 1212.5, 350: 1190.5, 400: 1160.5, 450: 1115.5}
	for y in measured:
		var x := CampBackdrop.window_right(float(y), 1280.0)
		check(absf(x - float(measured[y])) <= 4.0, "y %d: 창 오른쪽 끝 %.1f, 원작 %.1f(차 4 이하)" % [y, x, measured[y]])


## 그림 창(III HD 모양): 위 끝 y 118(x 0 → W − 35), 굽은 끝 → (W − 308, 508), 아래 끝 y 508. 창 안은 판이 덮지 않고(시야), 밖은 덮는다.
## 1280·1728 폭에서 순수 함수로, 그리고 실제 화면의 판 크기·누르기(창 안·판 위 모두 캠프 층이 받는다)로 본다.
func test_picture_window_is_uncovered_and_the_board_covers_the_rest_at_both_widths() -> void:
	for w in [1280.0, 1728.0]:
		var tag := "폭 %d" % w
		var o := CampBackdrop.window_outline(w)
		check_eq([o[0], o[1], o[o.size() - 2], o[o.size() - 1]], [Vector2(0, 118), Vector2(w - 35, 118), Vector2(w - 308, 508), Vector2(0, 508)],
			tag + ": 창 외곽 (0,118) → (W−35,118) → … → (W−308,508) → (0,508)")
		for i in range(1, o.size() - 2):
			check(o[i + 1].y >= o[i].y and o[i + 1].x <= o[i].x + 0.01, "%s: 굽은 끝은 아래·왼쪽으로만 간다(점 %d)" % [tag, i])
		check(CampBackdrop.window_right(300.0, w) > w - 100.0 and CampBackdrop.window_right(480.0, w) < w - 150.0, tag + ": 오른쪽 아래로 크게 굽는다")
		var samples := _window_samples(w, 720.0)
		for p in samples[0]:
			check(not CampBackdrop.covered(p, w, 720.0) and CampBackdrop.in_window(p, w), "%s: %s 는 창 안(판이 덮지 않음)" % [tag, str(p)])
		for p in samples[1]:
			check(CampBackdrop.covered(p, w, 720.0), "%s: %s 는 판이 덮음" % [tag, str(p)])
		check(not CampBackdrop.covered(Vector2(-1, 300), w, 720.0) and not CampBackdrop.covered(Vector2(w + 1, 300), w, 720.0), tag + ": 화면 밖은 덮임 아님")
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := str(px)
		check_eq(_rect(pm.backdrop_board), Rect2(Vector2.ZERO, size), tag + ": 판은 화면 전체")
		check_eq((pm.backdrop_board.drawn["size"] as Vector2), size, tag + ": 그린 크기 = 화면")
		# 목록은 창 왼쪽을 가리고(원작처럼 창이 목록 뒤로 들어간다), 카드는 판 위.
		check(CampBackdrop.in_window(_rect(pm.camp_list).get_center(), size.x), tag + ": 명령 목록 가운데는 창 자리(창이 목록 뒤로 들어간다)")
		for c in pm.cards.cards:
			check(CampBackdrop.covered(_rect(c).get_center(), size.x, size.y), "%s: 카드 %s 는 판 위" % [tag, c.name])
		for spot in [Vector2(size.x * 0.6, 300), Vector2(size.x - 15, 300), Vector2(size.x * 0.5, 530)]:
			var got := await _receiver_at(spot)
			check(got == pm, "%s: 창 안·판 위 빈 곳 %s → 캠프 층(뒤 탐색 화면에 닿지 않는다), 실제 %s" % [tag, str(spot), _name_of(got)])
		check_eq([pm.page, pm.is_open()], ["root", true], tag + ": 누르기 시험은 아무것도 고르지 않는다")


## 그린 판(07 §9.8 ④, 리뷰 F3): _draw 가 그린 판 다각형(drawn.board)·창 물빛(drawn.tint)·테두리(drawn.edges)를 읽는다. 창 안의 점은
## 어느 판 다각형에도 없고, 밖의 점은 하나 이상에 있다. 창 물빛은 옅다(알파 0.2 이하). 1280×720·1728×720·1280×960(늘어난 높이).
func test_drawn_board_leaves_the_window_open_at_three_sizes() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	for px in [Vector2(1280, 720), Vector2(2400, 1000), Vector2(1280, 960)]:
		var size: Vector2 = await _window(px)
		await kit.frames(2)
		var w := size.x
		var h := size.y
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var d: Dictionary = pm.backdrop_board.drawn
		check_eq(d["size"], size, tag + ": 그린 크기 = 화면")
		var board: Array = d["board"]
		check_eq(board, CampBackdrop.board_polygons(w, h), tag + ": 그린 판 = board_polygons")
		check_eq(d["edges"], CampBackdrop.edge_lines(w), tag + ": 그린 테두리 = edge_lines")
		check((d["tint"] as Color).a <= 0.2, "%s: 창 물빛 알파 %.2f ≤ 0.2" % [tag, (d["tint"] as Color).a])
		var samples := _window_samples(w, h)
		for p in samples[0]:
			check(CampBackdrop.in_window(p, w) and not board.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, poly)),
				"%s: 창 안 %s 는 그린 판 다각형 밖" % [tag, str(p)])
		for p in samples[1]:
			check(not CampBackdrop.in_window(p, w) and board.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, poly)),
				"%s: 창 밖 %s 는 그린 판 다각형 안" % [tag, str(p)])


## 창 테두리(리뷰 F1): 하늘색 선은 흰 선 바깥(판 쪽) 6px 에 있고 창 안으로 들어가지 않으며, 두 선은 만나지 않는다. 위 끝과 굽은 끝이 만나는
## 모서리는 곧은 모서리 (W − 29, 112). 1280·1728 폭.
func test_window_edge_cyan_line_runs_outside_the_white_line() -> void:
	for w in [1280.0, 1728.0]:
		var tag := "폭 %d" % w
		var e := CampBackdrop.edge_lines(w)
		var white: PackedVector2Array = e["white"]
		var cyan: PackedVector2Array = e["cyan"]
		check_eq([white[0], white[1], white[white.size() - 1]], [Vector2(0, 118), Vector2(w - 35, 118), Vector2(w - 308, 508)], tag + ": 흰 선 = 위 끝 + 굽은 끝")
		check_eq([cyan[0], cyan[1]], [Vector2(0, 112), Vector2(w - 29, 112)], tag + ": 하늘색 위 끝과 곧은 모서리 (W − 29, 112)")
		var bad_in := []
		var bad_gap := []
		for i in cyan.size():
			var p := cyan[i]
			if CampBackdrop.in_window(p, w):
				bad_in.append(p)
			if i == 1:
				continue  # 모서리는 흰 모서리에서 6√2
			var best := INF
			for j in white.size() - 1:
				best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, white[j], white[j + 1])))
			if absf(best - CampBackdrop.EDGE_GAP) > 1.0:
				bad_gap.append([p, snappedf(best, 0.01)])
		check(bad_in.is_empty(), "%s: 하늘색 점은 모두 창 밖(판 쪽) %s" % [tag, str(bad_in.slice(0, 4))])
		check(bad_gap.is_empty(), "%s: 하늘색 점은 흰 선에서 6 ± 1px %s" % [tag, str(bad_gap.slice(0, 4))])
		var crossings := 0
		for i in cyan.size() - 1:
			for j in white.size() - 1:
				if Geometry2D.segment_intersects_segment(cyan[i], cyan[i + 1], white[j], white[j + 1]) != null:
					crossings += 1
		check_eq(crossings, 0, tag + ": 하늘색 선과 흰 선은 만나지 않는다")


## 굽은 끝(조정자 F4): 타원 각도로 나눠 긴 직선 토막이 없다(토막 ≤ 30px), 토막 가운데는 곡선에서 1.5px 안. 두 끝은 정확하다.
func test_window_curve_has_no_long_chords() -> void:
	for w in [1280.0, 1728.0]:
		var tag := "폭 %d" % w
		var c := CampBackdrop.curve_points(w)
		check_eq([c[0], c[c.size() - 1]], [Vector2(w - 35, 118), Vector2(w - 308, 508)], tag + ": 두 끝")
		var longest := 0.0
		var worst := 0.0
		for i in c.size() - 1:
			longest = maxf(longest, c[i].distance_to(c[i + 1]))
			var m := (c[i] + c[i + 1]) / 2.0
			var dev := minf(absf(m.x - CampBackdrop.window_right(m.y, w)), absf(m.y - CampBackdrop.curve_y_at(m.x, w)))
			worst = maxf(worst, dev)
		check(longest <= 30.0, "%s: 가장 긴 토막 %.1f ≤ 30" % [tag, longest])
		check(worst <= 1.5, "%s: 토막 가운데와 곡선의 차 %.2f ≤ 1.5" % [tag, worst])


## 걸음 문패(리뷰 F2): 긴 걸음 수는 글자를 줄여 판 안에 다 든다(가장 작게 14). 이미 드는 글은 그대로 22(상점 이름 문패도 같은 부품).
func test_step_plate_shrinks_long_step_counts_to_fit() -> void:
	var s := await _open()
	var pm := s.party_menu
	var plate := pm.camp_plate
	var font := plate.get_theme_default_font()
	var tw := plate.size.x - FacilityPlate.TEXT_INSET
	check_eq(FacilityPlate.fit_size(font, "걸음 0", 22, 144.0), 22, "드는 글은 크기 그대로")
	s.state.steps = 999999999
	await kit.press_key(KEY_P)
	await kit.frames(2)
	tw = plate.size.x - FacilityPlate.TEXT_INSET
	var t := plate.first
	check_eq(t, s.texts.t("hud.steps", {"steps": 999999999}), "준비: 걸음 999999999")
	check(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > tw, "준비: 22 로는 넘친다")
	var fs: int = plate.drawn_sizes[0]
	check(fs < 22 and fs >= FacilityPlate.MIN_FS, "줄인 크기 %d" % fs)
	check(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= tw, "줄인 크기로는 판 폭 %.0f 안" % tw)
	await kit.press_key(KEY_ESCAPE)
	s.state.steps = 12
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(plate.drawn_sizes, [22], "짧은 걸음은 22 그대로")
	await kit.press_key(KEY_ESCAPE)
	await kit.tap(kit.center_of(s.shop_button))
	await kit.frames(2)
	check(s.shop_screen.is_open(), "준비: 상점")
	check_eq(s.shop_screen.plate.drawn_sizes, [22], "상점 이름 문패는 그대로 22")


# ---- 대원 고르기·명령 ----

## 대원 고르기 표시(07 §9.8 ①, research 07 §2.3): 커서 카드 하나만 노란 테두리(표지 "pick"), 다른 카드는 표지 없음, 노랑 채움 0개.
func _check_pick_marks(pm: PartyMenu, tag: String) -> void:
	for c in pm.cards.cards:
		var on := c == pm.cards.card(pm.pick_cursor)
		check_eq([c.target_mark, c.cursor, c.current], ["pick" if on else "", false, false], "%s: 카드 %s 표지" % [tag, c.name])
	check_eq(_yellow(pm), [], tag + ": 대원 고르기의 노랑 채움은 0개(카드 테두리는 표지)")


func test_member_pick_and_every_camp_command() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.page, pm.tab], ["sub", 3], "열자마자 Enter → 커서 0 = 소지품")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", ITEMS], "Esc → 뿌리(커서 소지품)")
	await kit.press_key(KEY_DOWN)
	check_eq(pm.camp_cursor, STATUS, "↓ → 상태 줄")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(pm.camp_cursor, RECORDS, "↑ 는 끝에서 돈다(기록, 닫기 줄은 없다)")
	await kit.press_key(KEY_2)
	check_eq([pm.page, pm.pick_cmd, pm.pick_cursor, pm.camp_cursor], ["pick", 0, 0, STATUS], "2 → 상태 대원 고르기(커서 칸 0)")
	check_eq(pm.camp_list.rows[STATUS].theme_state(), "fac:chosen", "고른 명령 = 밝은 시안")
	check_eq(pm.camp_list.rows.size(), 5, "「뒤로」 줄은 없다(키패드 「취소」·Esc·P·6)")
	for i in 5:
		check_eq(pm.camp_list.rows[i].mouse_filter, Control.MOUSE_FILTER_STOP, "고르기 중에도 명령 줄 %d 를 누를 수 있다" % i)
	_check_pick_marks(pm, "고르기 처음")
	check_eq(pm.camp_list.rows[ITEMS].theme_state(), "fac:normal", "다른 명령 줄 = 시설 청록 글자")
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.pick_cursor, 1, "→ 다음 카드")
	_check_pick_marks(pm, "→ 뒤")
	await kit.press_key(KEY_DOWN)
	var want := pm.pick_target(1, Vector2i(0, 1))
	check(not pm.cards.top_row(want), "↓ → 아랫줄 카드")
	check_eq(pm.pick_cursor, want, "↓ → 가로로 가장 가까운 아랫줄 카드")
	_check_pick_marks(pm, "↓ 뒤")
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
	await kit.press_key(KEY_2)
	await kit.tap(kit.center_of(pm.cards.cards[2]))
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, 2], "카드 누르기 → 그 대원 상태 화면")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", STATUS], "Esc → 캠프 뿌리(커서 상태)")
	check(pm.cards.cards.all(func(c: BattleCard) -> bool: return c.target_mark == ""), "뿌리로 돌아오면 카드 표지 없음")
	await kit.press_key(KEY_4)
	check_eq([pm.page, pm.pick_cmd, pm.pick_cursor], ["pick", 1, 2], "4 → 스킬 고르기, 커서는 지난 대원에서")
	await kit.tap(kit.center_of(pm.cards.cards[3]))
	check_eq([pm.page, pm.tab, pm.member], ["sub", 1, 3], "카드 누르기 → 그 대원 스킬")
	await kit.press_key(KEY_P)
	check_eq([pm.page, pm.camp_cursor], ["root", SKILLS], "P → 캠프 뿌리(커서 스킬)")
	await kit.press_key(KEY_3)
	check_eq([pm.page, pm.pick_cmd], ["pick", 2], "3 → 장비 고르기")
	await kit.tap(kit.center_of(pm.key_pad.button("back")))
	check_eq([pm.page, pm.camp_cursor], ["root", EQUIP], "키패드 「취소」 → 캠프 뿌리(커서 장비)")
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_ESCAPE)
	check_eq(pm.page, "root", "고르기에서 Esc → 캠프 뿌리")
	await kit.tap(kit.center_of(pm.camp_list.rows[ITEMS]))
	check_eq([pm.page, pm.tab], ["sub", 3], "소지품 → 고르기 없이 소지품")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", ITEMS], "Esc → 캠프 뿌리(커서 소지품)")
	await kit.press_key(KEY_1)
	check_eq([pm.page, pm.tab], ["sub", 3], "1 → 소지품")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab, s.modal.kind], ["sub", 4, ""], "5 → 고르기 없이 기록 화면(따로 된 메뉴 창 없음)")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", RECORDS], "Esc → 캠프 뿌리(커서 기록)")
	await kit.tap(kit.center_of(pm.camp_list.rows[RECORDS]))
	check_eq([pm.page, pm.tab], ["sub", 4], "「기록」 줄 누르기도 기록 화면")
	await kit.tap(kit.center_of(pm.key_pad_stacked.buttons["back"]))
	check_eq([pm.page, pm.camp_cursor], ["root", RECORDS], "기록 「뒤로」 → 캠프 뿌리")
	await kit.press_key(KEY_6)
	check(not pm.is_open(), "6 닫기 → 탐색(줄은 없어도 키는 그대로)")
	check(s.camp_button.is_visible_in_tree(), "탐색 HUD 가 돌아온다")
	await kit.press_key(KEY_P)
	check_eq(pm.camp_cursor, ITEMS, "다시 열면 커서 0(소지품)")
	await kit.tap(kit.center_of(pm.key_pad.button("back")))
	check(not pm.is_open(), "뿌리에서 키패드 「취소」 → 닫기")


## 휴대폰 확인(2026-10-25): 고르기 중에도 명령 줄이 모두 일한다. 상태·장비·스킬은 고르기를 그 명령으로 바꾸고(고른 모양이 따라감,
## 커서 대원 그대로, 지금 명령은 아무 일 없음), 소지품·기록은 바로 열고, 키 6·키패드 「취소」는 고르기 취소(P3 에서 「뒤로」 줄을 뺐다).
## 숫자 키도 같은 줄(07 §9.8 ②: 2·3·4 고르기 바꾸기, 1·5 바로 열기).
func test_member_pick_keeps_every_command_row_working() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.tap(kit.center_of(pm.camp_list.rows[SKILLS]))
	check_eq([pm.page, pm.pick_cmd], ["pick", 1], "준비: 스킬 대원 고르기")
	await kit.press_key(KEY_RIGHT)
	var n := pm.accepted_inputs
	await kit.tap(kit.center_of(pm.camp_list.rows[SKILLS]))
	check_eq([pm.page, pm.pick_cmd, pm.accepted_inputs], ["pick", 1, n], "지금 명령 줄을 다시 누르면 아무 일 없음")
	await kit.tap(kit.center_of(pm.camp_list.rows[EQUIP]))
	check_eq([pm.page, pm.pick_cmd, pm.pick_cursor], ["pick", 2, 1], "고르기 중 「장비」 줄 → 장비 고르기(커서 대원 그대로)")
	check_eq([pm.camp_list.rows[EQUIP].theme_state(), pm.camp_list.rows[SKILLS].theme_state()], ["fac:chosen", "fac:normal"], "고른 모양이 장비 줄로")
	_check_pick_marks(pm, "장비로 바꾼 뒤")
	await kit.tap(kit.center_of(pm.cards.cards[3]))
	check_eq([pm.page, pm.tab, pm.member], ["sub", 2, 3], "카드 → 그 대원 장비")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", EQUIP], "Esc → 뿌리(커서 장비)")
	await kit.press_key(KEY_2)
	await kit.tap(kit.center_of(pm.camp_list.rows[ITEMS]))
	check_eq([pm.page, pm.tab], ["sub", 3], "고르기 중 「소지품」 줄 → 바로 소지품")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", ITEMS], "소지품에서 Esc → 뿌리(커서 소지품)")
	await kit.press_key(KEY_2)
	await kit.tap(kit.center_of(pm.camp_list.rows[RECORDS]))
	check_eq([pm.page, pm.tab, s.modal.kind], ["sub", 4, ""], "고르기 중 「기록」 줄 → 바로 기록")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_4)
	await kit.tap(kit.center_of(pm.key_pad.button("back")))
	check_eq([pm.page, pm.camp_cursor], ["root", SKILLS], "키패드 「취소」 → 고르기 취소, 뿌리(커서 스킬)")
	# 키보드: 고르기 중 2·3·4 는 고르기 바꾸기, 1·5 는 바로 열기, 6 은 「뒤로」. ←→ 와 Enter 는 그대로.
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_3)
	check_eq([pm.page, pm.pick_cmd, pm.camp_cursor], ["pick", 2, EQUIP], "고르기 중 3 → 장비 고르기")
	await kit.press_key(KEY_4)
	check_eq([pm.page, pm.pick_cmd], ["pick", 1], "고르기 중 4 → 스킬 고르기")
	await kit.press_key(KEY_2)
	check_eq([pm.page, pm.pick_cmd], ["pick", 0], "고르기 중 2 → 상태 고르기")
	n = pm.accepted_inputs
	await kit.press_key(KEY_2)
	check_eq([pm.pick_cmd, pm.accepted_inputs], [0, n], "지금 명령 키는 아무 일 없음")
	await kit.press_key(KEY_4)
	var next := pm.pick_target(pm.pick_cursor, Vector2i(1, 0))
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.page, pm.tab, pm.member], ["sub", 1, next], "→·Enter 는 그대로: 다음 카드 대원의 스킬 화면")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_1)
	check_eq([pm.page, pm.tab], ["sub", 3], "고르기 중 1 → 소지품")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_5)
	check_eq([pm.page, pm.tab], ["sub", 4], "고르기 중 5 → 기록")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_6)
	check_eq([pm.page, pm.camp_cursor, pm.is_open()], ["root", EQUIP, true], "고르기 중 6 → 뒤로(캠프는 열린 채)")
	# 명령이 바뀌면 문맥이 바뀐다: 눌려 있던 카드는 취소되어 뗄 때 아무 일도 하지 않는다.
	await kit.press_key(KEY_2)
	var p := kit.center_of(pm.cards.cards[2])
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	check(pm.cards.cards[2].held, "카드 2 누르는 중")
	await kit.press_key(KEY_4)
	check_eq(pm.pick_cmd, 1, "누른 채 4 → 스킬 고르기")
	check(not pm.cards.cards[2].held, "명령이 바뀌면 누르기 취소")
	kit.touch(FINGER, p, false)
	await kit.frames(3)
	check_eq([pm.page, pm.pick_cmd], ["pick", 1], "취소된 카드 누르기는 뗄 때 대원을 고르지 않는다")
	# 줄로 바꿀 때도 같다(다른 손가락이 카드를 누르는 동안 「상태」 줄).
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	await kit.tap(kit.center_of(pm.camp_list.rows[STATUS]))
	check_eq(pm.pick_cmd, 0, "누른 채 「상태」 줄 → 상태 고르기")
	kit.touch(FINGER, p, false)
	await kit.frames(3)
	check_eq([pm.page, pm.pick_cmd], ["pick", 0], "줄로 바꾼 뒤에도 앞 누르기는 고르지 않는다")


# ---- 상태 화면 ----

## 상태 화면 층 표(07 §9.9 E2-a, research 08 §3.1, 1280×720 기준. 왼쪽 열은 왼쪽 위, 초상은 가운데, 받는 배율·「내역」·「취소」「선택」은 오른쪽 아래,
## 방향 십자는 왼쪽 아래 x 456). 겹쳐도 되는 것은 키패드가 초상 앞에 오는 것뿐이다.
func _check_status_layers(pm: PartyMenu, size: Vector2, tag: String) -> void:
	var st := pm.status_tab
	var screen := Rect2(Vector2.ZERO, size)
	var w := size.x
	var h := size.y
	# 왼쪽 열: 원작 자리.
	check_eq(st.class_rect(), Rect2(92, 190, 318, 45), tag + ": 직업 문패 알약 x 92~410 · y 190~235")
	var ext := st.class_extent()
	for pts in SheetParts.leaf_polygons(st.class_rect()):
		for pt in pts:
			check(ext.grow(0.01).has_point(pt), "%s: 문패 자리 %s 가 잎 꼭짓점 %s 를 덮는다" % [tag, str(ext), str(pt)])
	check(ext.encloses(st.class_rect()) and ext.position.x >= 40.0 and ext.end.x <= 462.0 and ext.position.y < 190.0 and ext.end.y > 235.0,
		tag + ": 잎 장식은 왼쪽 45 근처 ~ 오른쪽 460 근처, 알약보다 위아래로 조금 나온다 %s" % str(ext))
	for i in 6:
		check_eq(st.stat_rect(i), Rect2(66, 297 + 33 * i, 319, 28), "%s: 능력치 줄 %d" % [tag, i])
	var sb := SheetParts.stat_boxes(st.stat_rect(0))
	check_eq([(sb["name"] as Rect2).end.x, (sb["value"] as Rect2).end.x, (sb["track"] as Rect2).position.x, (sb["track"] as Rect2).end.x],
		[136.0, 225.0, 236.0, 385.0], tag + ": 능력치 칸 이름 66~136 · 값 136~225 · 막대 236~385")
	check_eq([st.gear_row_rect(0), st.gear_row_rect(1)], [Rect2(66, 505, 374, 34), Rect2(66, 543, 374, 34)], tag + ": 공격·방어 두 줄 y 505~539 · 543~577, x 66~440")
	check_eq([st.gear_rect(0).position.y, st.gear_rect(2).position.y, st.gear_rect(1).position.y], [505.0, 505.0, 543.0],
		tag + ": 첫 줄 = 공격·방어, 둘째 줄 = 마법 공격(·마법 방어)")
	for i in 4:
		var er := st.equip_rect(i)
		check_eq(er, Rect2(80, 590 + 30 * i, 295, 28), "%s: 장비 줄 %d" % [tag, i])
		var eb := SheetParts.equip_boxes(er)
		check_eq([(eb["icon"] as Rect2).position.x, (eb["icon"] as Rect2).end.x, (eb["name"] as Rect2).position.x, (eb["name"] as Rect2).end.x],
			[80.0, 120.0, 123.0, 375.0], "%s: 장비 줄 %d 아이콘 칸 80~120 · 이름 칸 123~375" % [tag, i])
	# 초상: 가운데(W/2 + 20 ± 240), 위 띠 아래 ~ 아래 끝, 왼쪽 열과 겹치지 않게 왼쪽을 자른다.
	var pr := st.portrait_rect()
	var cx := w / 2.0 + 20.0
	check_eq([pr.position.x, pr.end.x, pr.position.y, pr.end.y], [maxf(cx - 240.0, 464.0), cx + 240.0, 118.0, h], tag + ": 초상 가운데")
	# 오른쪽: 받는 배율(오른쪽 끝 W − 28, 아래 끝 H − 75, 폭 240, 위 끝 ≥ H − 213), 「내역」, 키패드.
	var sr := st.side_rect()
	check_eq([sr.end.x, sr.end.y, sr.size.x], [w - 28.0, h - 75.0, 240.0], tag + ": 받는 배율 문패 오른쪽 아래(원작 LIMIT 자리)")
	check(sr.position.y >= h - 213.0, "%s: 받는 배율 문패 위 끝 %.0f ≥ 「취소」「선택」 아래 + 8" % [tag, sr.position.y])
	check_eq(_rect(st.split_button), Rect2(w - 128, h - 72, 120, 64), tag + ": 「내역」 오른쪽 아래(원작 Ⓐ SKILL 자리)")
	check_eq(_rect(pm.dir_pad), Rect2(456, h - 209, 200, 200), tag + ": 방향 십자 (456, H − 209)")
	check_eq(_rect(pm.key_pad), Rect2(w - 247, h - 293, 227, 72), tag + ": 「취소」「선택」 (W − 247, H − 293)")
	# 겹침: 키패드가 초상 앞에 오는 것만 된다.
	var blocks := {"name": st.name_tab_rect(), "lv": st.lv_band_rect(), "class": st.class_extent(), "side": sr, "split_button": _rect(st.split_button),
		"split_head": st.split_head_rect(), "dir_pad": _rect(pm.dir_pad), "keys": _rect(pm.key_pad), "portrait": pr}
	for i in 6:
		blocks["stat%d" % i] = st.split_row_rect(i)
	for r in 2:
		blocks["gear%d" % r] = st.gear_row_rect(r)
	for i in 4:
		blocks["equip%d" % i] = st.equip_rect(i)
	var allowed := [["dir_pad", "portrait"], ["keys", "portrait"]]
	var keys := blocks.keys()
	for i in keys.size():
		var a: Rect2 = blocks[keys[i]]
		check(screen.encloses(a), "%s: %s %s 화면 안" % [tag, keys[i], str(a)])
		if not keys[i] in ["name", "lv"]:
			check(a.position.y >= PartyStatusTab.TOP_H, "%s: %s 는 위 줄 아래" % [tag, keys[i]])
		for j in range(i + 1, keys.size()):
			if [keys[i], keys[j]] in allowed or [keys[j], keys[i]] in allowed:
				continue
			check(not a.intersects(blocks[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
	check(st.gear_row_rect(0).end.x <= _rect(pm.dir_pad).position.x - 16.0, tag + ": 공격·방어는 방향 십자 왼쪽에서 끝난다")
	# 트리 순서(층 표): 초상 → 위 띠 → 왼쪽 열 → 받는 배율 → 「내역」 → (캠프) 키패드.
	check(st.portrait.get_index() < st.top.get_index() and st.top.get_index() < st.left.get_index() and st.left.get_index() < st.side.get_index()
		and st.side.get_index() < st.split_button.get_index(), tag + ": 그리는 순서 초상 → 위 띠 → 왼쪽 열 → 받는 배율 → 「내역」")


func test_status_screen_follows_the_reference_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	GrowthRules.grant_exp(s.state, 1, 120)
	GrowthRules.supply(s.state, "equip.thermal_ring", 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	var st := pm.status_tab
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, 1], "준비: 듀얼리스트 A 상태")
	var first := {}
	for px in WINDOWS + [Vector2(1280, 960), WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var screen := Rect2(Vector2.ZERO, size)
		check_eq(_rect(s.view_container), screen, tag + ": 바탕은 줄지 않는다")
		for c in [pm.camp_list, pm.ribbon, pm.money_plate, pm.cards]:
			check(not (c as Control).is_visible_in_tree(), "%s: 캠프 뿌리 부품은 감춘다(%s)" % [tag, c.name])
		_check_status_layers(pm, size, tag)
		check_eq(st.info_rect(), Rect2(0, 64, size.x, 54), tag + ": 정보 띠는 전체 폭")
		check_eq(st.lv_band_rect().end.x, size.x, tag + ": Lv 띠는 오른쪽 끝까지")
		check(pm.find_child("StatusBack", true, false) == null and not s.debug_snapshot()["buttons"].has("StatusBack"), tag + ": 「뒤로」 단추 없음(E1 ⑤)")
		check_eq(PartyStatusTab.STAT_ROWS.size(), 6, tag + ": 능력치 여섯 줄(최대 HP·TP 줄 없음, E1 ④)")
		check_eq(st.top.drawn["lv"], ["Lv %d" % s.state.party.members[1].level], tag + ": Lv 띠의 글은 「Lv n」뿐(E1 ③)")
		check_eq([_rect(st.prev_button), _rect(st.next_button)], [Rect2(0, 0, 64, 64), Rect2(266, 0, 64, 64)], tag + ": 앞·다음 대원(원작 L·R 자리)")
		for d in [st.top, st.left, st.portrait, st.side]:
			check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
		_check_targets(pm, size, tag + " 상태")
		var snap := [st.portrait_rect(), st.side_rect(), _rect(st.split_button)]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 값: 규칙의 읽기 함수에서.
	var m := s.state.party.members[1]
	var p := GrowthRules.profile(s.state.defs, 1, m)
	var d := st.drawn
	check_eq([d["name"], d["class"], d["level"]], [s.texts.t("member.blade_duelist"), s.texts.t("class.blade_duelist"), "Lv %d" % m.level], "이름·직업·Lv")
	check_eq(d["hp"], "%d/%d" % [m.hp, m.max_hp], "HP")
	check_eq(st.top.drawn["strip"], ["HP", d["hp"], "TP", d["tp"], d["next"]], "띠: 왼쪽 HP·TP, 오른쪽 다음 레벨까지(그대로)")
	check(not PartyStatusTab.STAT_ROWS.has("max_hp") and not PartyStatusTab.STAT_ROWS.has("max_tp"), "최대 HP·TP 줄은 없다")
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
		var r := st.split_row_rect(i)
		for c in 3:
			check(r.encloses(st.split_cell(i, c)), "내역 칸 %d/%d 는 같은 줄(x 440 까지) 안" % [i, c])
		check(st.split_cell(i, 0).position.x == st.bar_rect(i).position.x - 4.0 and st.split_cell(i, 2).end.x == 440.0, "내역 칸은 막대 칸 자리 ~ x 440")
	await kit.press_key(KEY_E)
	check(st.split_view, "대원을 넘겨도 내역 보기는 남는다")
	await kit.tap(kit.center_of(st.split_button))
	check(not st.split_view, "「내역」 단추 → 막대 보기")
	await kit.tap(kit.center_of(st.split_button))
	check(st.split_view, "「내역」 단추 → 다시 내역 보기")
	await kit.tap(kit.center_of(pm.key_pad.buttons["back"]))
	check_eq([pm.page, pm.camp_cursor], ["root", STATUS], "키패드 「취소」 → 캠프 뿌리")
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.page, pm.tab], ["sub", 0], "다시 상태")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", STATUS], "Esc → 캠프 뿌리")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	check(pm.page == "sub" and pm.tab == 0 and not st.split_view, "캠프를 다시 열면 막대 보기")


## 노랑으로 보이는 색(채움 검사): 색상 0.1~0.19, 채도·밝기 높음.
static func _is_yellow(c: Color) -> bool:
	return c.h >= 0.1 and c.h <= 0.19 and c.s >= 0.4 and c.v >= 0.75


## SheetParts 그리기 기록(그리는 호출이 남긴 것, 07 §9.9 E2-a 고침): 종류별 항목.
static func _drawn_entries(ci: CanvasItem, kind: String) -> Array:
	return SheetParts.record(ci).filter(func(e: Dictionary) -> bool: return e["kind"] == kind)


## 자리 r 안에 그린 아이콘 이름들.
static func _drawn_icons_in(ci: CanvasItem, r: Rect2) -> Array:
	return _drawn_entries(ci, "icon").filter(func(e: Dictionary) -> bool: return r.encloses(e["rect"])).map(func(e: Dictionary) -> String: return e["name"])


## 줄 r 안(글 바닥이 줄 안)에 그린 글들.
static func _drawn_text_in(ci: CanvasItem, r: Rect2) -> Array:
	return _drawn_entries(ci, "text").filter(func(e: Dictionary) -> bool:
		return r.has_point(Vector2(e["rect"].position.x + 1.0, e["rect"].end.y - 6.0))).map(func(e: Dictionary) -> String: return e["text"])


## 기록된 채움·다각형에 노랑이 없다(능력치 막대 칸 안의 노란 짧은 막대만 된다).
func _check_no_yellow_fill(st: PartyStatusTab, tag: String) -> void:
	var fills := _drawn_entries(st.left, "fill") + _drawn_entries(st.left, "poly")
	check(fills.size() > 20, "%s: 채움 기록이 있다(%d)" % [tag, fills.size()])
	for e in fills:
		if not _is_yellow(e["color"]):
			continue
		var in_bar := false
		for i in 6:
			if st.bar_rect(i).encloses(e["rect"]):
				in_bar = true
		check(in_bar and e["color"] == SheetParts.STAT_BAR and not st.split_view, "%s: 노랑 채움 %s %s 는 막대 보기의 막대 칸 안 짧은 막대뿐" % [tag, e["color"], str(e["rect"])])


## 상태 시트(07 §9.9 E2-a): 글이 잘리지 않는다(긴 직업·장비 이름, 「내역」 수, 받는 배율 세 갈래), 장비 줄의 종류 아이콘과 빈 칸,
## 「내역」 보기가 x 440 안, 노랑 채움 0.
func test_status_sheet_fits_text_shows_kind_icons_and_has_no_yellow_fill() -> void:
	var s := await _open()
	var pm := s.party_menu
	var defs := s.state.defs
	var t := s.texts
	# 대원 0: 받는 배율 세 갈래가 모두 보통이 아니게 한다(이지스 플레이트 = 열, 해독 칩 = 부식 나노, 마그 부츠 = 이동부, 표시 시험이라 규칙을 거치지 않는다).
	var m0 := s.state.party.members[0]
	var gear_ids := ["equip.training_sword", "equip.aegis_plate", "equip.antitox_chip", "equip.mag_boots"]
	for slot in 4:
		m0.equip[slot] = gear_ids[slot]
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	var st := pm.status_tab
	await kit.frames(2)
	check_eq([pm.page, pm.tab, pm.member], ["sub", 0, 0], "준비: 대원 0 상태")
	var c: Control = st.left
	# 직업 문패: 가장 긴 직업 이름.
	var longest_class := ""
	for id in defs.battle.class_ids:
		if t.t(id).length() > longest_class.length():
			longest_class = t.t(id)
	check(SheetParts.text_width(c, longest_class, SheetParts.CLASS_FS) <= SheetParts.class_text_rect(st.class_rect()).size.x,
		"가장 긴 직업 이름 「%s」 이 문패에 든다" % longest_class)
	# 장비 이름: 가장 넓은 것.
	var widest := ""
	for id in defs.battle.equipment_ids:
		if SheetParts.text_width(c, t.t(id), SheetParts.EQUIP_FS) > SheetParts.text_width(c, widest, SheetParts.EQUIP_FS):
			widest = t.t(id)
	check(SheetParts.text_width(c, widest, SheetParts.EQUIP_FS) <= SheetParts.equip_text_room(st.equip_rect(0)),
		"가장 넓은 장비 이름 「%s」 이 장비 줄에 든다" % widest)
	# 능력치·공격·방어 이름과 값.
	var sb := SheetParts.stat_boxes(st.stat_rect(0))
	for k in PartyStatusTab.STAT_ROWS:
		check(SheetParts.text_width(c, t.t("stat." + k), SheetParts.STAT_NAME_FS) <= (sb["name"] as Rect2).size.x - 2.0 * SheetParts.TEXT_PAD,
			"능력치 이름 %s 이 든다" % k)
	check(SheetParts.text_width(c, "999", SheetParts.STAT_VALUE_FS) <= (sb["value"] as Rect2).size.x - 2.0 * SheetParts.TEXT_PAD, "능력치 값 999 가 든다")
	var gc := SheetParts.gear_cells(st.gear_row_rect(1))
	for k in BattleLimits.GEAR:
		check(SheetParts.text_width(c, t.t("stat." + k), SheetParts.GEAR_LABEL_FS) <= (gc[0]["label"] as Rect2).size.x - 2.0 * SheetParts.TEXT_PAD,
			"공격·방어 이름 %s 이 든다" % k)
	check(SheetParts.text_width(c, "999", SheetParts.GEAR_VALUE_FS) <= (gc[0]["value"] as Rect2).size.x - 2.0 * SheetParts.TEXT_PAD, "공격·방어 값 999 가 든다")
	# 장비 줄: 종류 아이콘(상점과 같은 ShopTabs.ICONS), 빈 칸은 빈 아이콘과 흐린 「비어 있음」.
	for slot in 4:
		var id: String = m0.equip[slot]
		var want := str(ShopTabs.ICONS[defs.battle.equip(id).kind])
		check_eq(st.drawn["equip"][slot], [want, t.t(id), false], "장비 줄 %d = 종류 아이콘 %s + 이름" % [slot, want])
		check(want in VectorIcons.KIND_ICONS, "아이콘 %s 은 상점 종류 아이콘" % want)
		check_eq(_drawn_icons_in(st.left, SheetParts.equip_boxes(st.equip_rect(slot))["icon"]), [want], "장비 줄 %d 아이콘 칸에 %s 를 그렸다" % [slot, want])
		check(_drawn_text_in(st.left, st.equip_rect(slot)) == [t.t(id)], "장비 줄 %d 에 이름을 그렸다" % slot)
	m0.equip[3] = ""
	pm.refresh_view()
	await kit.frames(2)
	check_eq(st.drawn["equip"][3], ["", t.t("party.slot.empty"), true], "빈 칸: 아이콘 없음 + 「비어 있음」(흐림)")
	check_eq(_drawn_icons_in(st.left, SheetParts.equip_boxes(st.equip_rect(3))["icon"]), [], "빈 칸 아이콘 칸에는 아이콘을 그리지 않는다")
	var empty_txt := _drawn_entries(st.left, "text").filter(func(e: Dictionary) -> bool: return e["text"] == t.t("party.slot.empty"))
	check(empty_txt.size() == 1 and empty_txt[0]["color"] == SheetParts.EQUIP_EMPTY_TEXT and SheetParts.EQUIP_EMPTY_TEXT != SheetParts.STAT_TEXT,
		"빈 칸 「비어 있음」을 흐린 색으로 그렸다")
	m0.equip[3] = "equip.mag_boots"
	pm.refresh_view()
	await kit.frames(1)
	# 받는 배율: 실제 세 갈래 + 줄마다 두 값인 긴 경우. 줄이 문패 안에 들고, 문패는 「취소」「선택」 아래 + 8 보다 내려와 있다.
	var size := pm.size
	check_eq(st.drawn["received"].size(), 3, "받는 배율 세 갈래: %s" % str(st.drawn["received"]))
	var long := PartyStatusTab.received_lines(t, {"resist": {"fire": 450, "ice": 750}, "ailment_vuln": {"poison": 0, "paralysis": 1500},
		"bind_vuln": {"head": 500, "leg": 500}})
	check_eq(long.size(), 3, "긴 경우도 세 줄")
	for line in st.drawn["received"] + long:
		var fs := PartyStatusTab.side_font_size(st.side, line)
		check(SheetParts.text_width(c, line, fs) <= PartyStatusTab.SIDE_W - 2.0 * PartyStatusTab.SIDE_TEXT_PAD and fs >= PartyStatusTab.SIDE_FS_MIN,
			"받는 배율 줄 「%s」 이 %dpx 로 든다" % [line, fs])
	check(PartyStatusTab.side_height(3) <= PartyStatusTab.SIDE_TOP_MIN - PartyStatusTab.SIDE_BOTTOM, "세 줄 문패 높이가 키패드 아래에 든다")
	check(st.side_rect().position.y >= size.y - 213.0 and is_equal_approx(st.side_rect().size.y, PartyStatusTab.side_height(3)),
		"그린 문패 %s 는 세 줄 높이, 위 끝 ≥ H − 213" % str(st.side_rect()))
	# 노랑 채움 0(막대 보기·「내역」 보기), 「내역」 켜짐도 노랑 아님.
	check_eq(_yellow(pm), [], "상태의 노랑 채움은 0개")
	_check_no_yellow_fill(st, "막대 보기")
	for col in [SheetParts.CLASS_FILL, SheetParts.LEAF, SheetParts.STAT_NAME_BOX, SheetParts.STAT_VALUE_BOX, SheetParts.STAT_TRACK,
			SheetParts.GEAR_LABEL_BOX, SheetParts.GEAR_VALUE_BOX, SheetParts.ICON_BOX, SheetParts.EQUIP_NAME_BOX, UiTheme.ST_SIDE_TOP, UiTheme.ST_SIDE_BOTTOM]:
		check(not _is_yellow(col), "칸 색 %s 는 노랑 채움이 아니다" % col.to_html(false))
	await kit.press_key(KEY_V)
	check(st.split_view and st.split_button.checked, "V → 「내역」 보기")
	check_eq(_yellow(pm), [], "「내역」 보기도 노랑 채움 0개")
	await kit.frames(2)
	_check_no_yellow_fill(st, "「내역」 보기")
	# 머리 줄 받침: 대비 표가 쓰는 색(SPLIT_HEAD_BOX)으로 머리 줄 자리를 채우고, 머리 글은 그 위에 SPLIT_HEAD_TEXT 로.
	var head_fills := _drawn_entries(st.left, "fill").filter(func(e: Dictionary) -> bool: return e["rect"] == st.split_head_rect())
	check(head_fills.size() == 1 and head_fills[0]["color"] == SheetParts.SPLIT_HEAD_BOX, "「내역」 머리 줄 받침을 그렸다: %s" % str(head_fills))
	var heads := _drawn_entries(st.left, "text").filter(func(e: Dictionary) -> bool:
		return e["text"] in [t.t("party.col.base"), t.t("party.col.passive"), t.t("party.col.equip")])
	check_eq(heads.size(), 3, "머리 글 셋을 그렸다")
	for e in heads:
		check(e["color"] == SheetParts.SPLIT_HEAD_TEXT and st.split_head_rect().grow(1.0).has_point(Vector2(e["rect"].position.x, e["rect"].end.y - 6.0)),
			"머리 글 %s 은 받침 위, 대비 표의 글자색" % e["text"])
	var on_top: Color = UiTheme.look(st.split_button.theme_state())["top"]
	check(not _is_yellow(on_top), "「내역」 켜짐 모양 %s (%s) 은 노랑 채움이 아니다" % [st.split_button.theme_state(), on_top.to_html(false)])
	# 「내역」 보기: 세 칸이 줄 안·x 440 안, 머리 줄은 첫 줄 바로 위·문패 아래, 큰 수도 든다.
	for i in 6:
		var row := st.split_row_rect(i)
		check(row.end.x <= 440.0 and row.end.x < pm.dir_pad.get_global_rect().position.x, "내역 줄 %d 은 x 440 안" % i)
		for k in 3:
			check(row.encloses(st.split_cell(i, k)), "내역 칸 %d/%d 은 줄 안" % [i, k])
		check(st.split_cell(i, 0).position.x == st.bar_rect(i).position.x - 4.0, "내역 칸은 막대 칸 자리부터")
	var hr := st.split_head_rect()
	check(hr.end.y == st.stat_rect(0).position.y and hr.position.y >= st.class_extent().end.y, "머리 줄 %s 은 첫 줄 바로 위, 문패 아래" % str(hr))
	var cw := st.split_cell(0, 0).size.x - SheetParts.TEXT_PAD
	for v in ["999", "+99", "-99"]:
		check(SheetParts.text_width(c, v, SheetParts.SPLIT_FS) <= cw, "내역 수 %s 가 칸에 든다" % v)
	for hk in ["party.col.base", "party.col.passive", "party.col.equip"]:
		check(SheetParts.text_width(c, t.t(hk), SheetParts.SPLIT_HEAD_FS) <= cw, "내역 머리 %s 가 칸에 든다" % hk)


# ---- 스킬 트리 화면(07 §9.9 E2-d, research 08 §6.1: 원작 I HD 스킬 트리 yt_eo1hd_b_03, 알림 띠 b_04) ----

## 스킬 화면 준비: 듀얼리스트 A(칸 1, Lv 3: 초안을 만들 SP).
func _skills_open() -> DungeonScreen:
	var s := await _open()
	GrowthRules.grant_exp(s.state, 1, s.state.defs.battle.growth.cum(3))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_4)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	return s


## 층 표(E2-d 설계 §2.1·§2.2): 자리·앵커·허용한 겹침만·화면 안·트리 차례.
func _check_skill_layers(pm: PartyMenu, size: Vector2, tag: String) -> void:
	var st := pm.skill_tab
	await kit.frames(1)
	var band := _rect(st.top)
	var win := st.tree_window_rect()
	var area := st.tree_rect()
	var ct := st.class_tab_rect()
	var desc := st.desc_rect()
	var dir := _rect(pm.dir_pad)
	var keys := _rect(pm.key_pad)
	check_eq(band, Rect2(0, 0, size.x, MemberHeader.H), tag + ": 대원 띠 전체 폭")
	check_eq(win, Rect2(48, 137, size.x - 96, size.y - 217 - 137), tag + ": 트리 판 x 48 ~ W − 48, y 137(원작) ~ H − 217(방향 십자 위 8)")
	check_eq(area, Rect2(60, 141, size.x - 132, size.y - 221 - 141), tag + ": 트리 영역은 판 안(왼쪽 12, 오른쪽 24 = 스크롤 막대, 위아래 4)")
	check_eq(ct, Rect2(72, 103, 220, 34), tag + ": 직업 탭 x 72~292, y 103~137(원작 100~137)")
	check_eq(ct.end.y, win.position.y, tag + ": 직업 탭 아래 끝 = 트리 판 위(붙는다, 겹치지 않음)")
	check_eq(desc, Rect2(216, size.y - 209, size.x - 264, 201), tag + ": 설명 상자 x 216 ~ W − 48, y H − 209 ~ H − 8")
	check_eq([dir, keys], [Rect2(8, size.y - 209, 200, 200), Rect2(size.x - 567, size.y - 88, 227, 72)], tag + ": 키패드(07 §9.7 그대로)")
	check(desc.position.x >= dir.end.x + 8.0, tag + ": 설명 상자는 방향 십자 오른쪽 + 8 부터(원작 48 에서 비킴)")
	check(win.end.y + 8.0 <= dir.position.y + 0.5 and win.end.y <= desc.position.y, tag + ": 트리 판은 방향 십자·설명 상자 위에서 끝난다")
	var sb := st.scroll_rect()
	var sbg := Rect2(win.position + sb.position, sb.size)
	check(win.encloses(sbg) and not sbg.intersects(area), tag + ": 스크롤 막대 %s 는 판 안, 트리 영역 밖(오른쪽)" % str(sbg))
	# 겹침: 허용한 것만. (c) 직업 탭이 띠의 빈 왼쪽 끝 앞, (a) 「취소」「선택」이 설명 상자 안(07 §9.7).
	var parts := {"band": band, "class_tab": ct, "panel": win, "desc": desc, "dir": dir, "keys": keys}
	var names := parts.keys()
	for i in names.size():
		check(Rect2(Vector2.ZERO, size).encloses(parts[names[i]]), "%s: %s %s 가 화면 안" % [tag, names[i], str(parts[names[i]])])
		for j in range(i + 1, names.size()):
			var inter: Rect2 = (parts[names[i]] as Rect2).intersection(parts[names[j]])
			if not inter.has_area():
				continue
			var pair := [names[i], names[j]]
			if pair == ["band", "class_tab"]:
				check_eq(inter, Rect2(72, 103, 220, 15), tag + ": 직업 탭 ∩ 띠 = 띠 왼쪽 빈 곳(x 72~292, y 103~118)만")
			elif pair == ["desc", "keys"]:
				check(desc.encloses(keys), tag + ": 「취소」「선택」은 설명 상자 안")
			else:
				check(false, "%s: 허용하지 않은 겹침 %s %s" % [tag, str(pair), str(inter)])
	# 직업 탭은 띠의 안내(x 400~)와 남은 SP 글에 닿지 않는다.
	var note := _rect(st._note_label)
	var sp := _rect(st._sp_label)
	check(note.position.x >= 400.0 and ct.end.x < note.position.x and ct.end.x < sp.position.x, tag + ": 직업 탭 %s 은 안내 %s·남은 SP %s 왼쪽" % [str(ct), str(note), str(sp)])
	# 설명 상자 안: 레벨 탭 → 「Lv n」 막대(머리 오른쪽), 그 아래 「−」「+」, 아래 줄 「되돌리기」「확정」, 그 왼쪽 「취소」「선택」.
	var ctrl := {"−": _rect(st.minus_button), "+": _rect(st.plus_button), "되돌리기": _rect(st.revert_button), "확정": _rect(st.commit_button),
		"취소": _rect(pm.key_pad.button("back")), "선택": _rect(pm.key_pad.button("ok"))}
	var cn := ctrl.keys()
	for i in cn.size():
		var r: Rect2 = ctrl[cn[i]]
		check(desc.encloses(r) and r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s %s 는 설명 상자 안, 64 이상" % [tag, cn[i], str(r)])
		for j in range(i + 1, cn.size()):
			check(not r.intersects(ctrl[cn[j]]), "%s: %s 와 %s 가 겹친다" % [tag, cn[i], cn[j]])
	var head := ListParts.tree_head_rect(Rect2(desc.position, desc.size))
	var bar := Rect2(desc.position + st.lv_bar_rect().position, st.lv_bar_rect().size)
	check(head.encloses(bar) and bar.end.y <= ctrl["−"].position.y and bar.position.x >= desc.position.x + st.level_box_rect(10).end.x,
		tag + ": 「Lv n」 막대 %s 는 머리 안 오른쪽, 레벨 탭 10 오른쪽, 「−」 위" % str(bar))
	check(ctrl["−"].position.y >= head.end.y, tag + ": 「−」「+」 는 머리 아래")
	var body_end := desc.position.x + PartySkillTab.DESC_PAD + st.body_width()
	check(body_end <= keys.position.x - 8.0 + 0.5, "%s: 설명 줄 자리 끝 %s 는 키패드 「취소」 왼쪽 − 8" % [tag, body_end])
	check_eq([ctrl["되돌리기"].size, ctrl["확정"].size], [Vector2(120, 64), Vector2(140, 64)], tag + ": 「되돌리기」 120·「확정」 140")
	# 노드: 트리 영역 안, 넓은 알약(원작 36 → 64), 행 피치 100(선의 「Lv n」 자리).
	var inner := Rect2(Vector2.ZERO, area.size)
	for i in st.nodes.size():
		if st.nodes[i].visible:
			check(inner.encloses(st.node_rect(i)), "%s: 노드 %d %s 가 트리 영역 안" % [tag, i, str(st.node_rect(i))])
			check_eq(st.nodes[i].size, st.node_size(), "%s: 노드 %d 크기" % [tag, i])
	check(st.node_size().x >= 240.0 and st.node_size().y >= 64.0 and st.pitch().y == 100.0, tag + ": 노드 ≥ 240×64, 행 피치 100")
	# 트리 차례(뒤 → 앞): 판 → 하위 화면(띠 → 트리 판 → 직업 탭 → 트리 영역 → 설명 상자) → 확인 창 층 → 키패드.
	var order := [st.top, st.tree_window, st.class_tab, st.tree_area, st.desc]
	for i in order.size() - 1:
		check((order[i] as Control).get_index() < (order[i + 1] as Control).get_index(), "%s: %s 는 %s 뒤" % [tag, order[i].name, order[i + 1].name])
	check(pm.backdrop_board.get_index() < st.get_index() and st.get_index() < pm.dialog_layer.get_index() and pm.dialog_layer.get_index() < pm.dir_pad.get_index(),
		tag + ": 판 → 스킬 → 확인 창 층 → 키패드")
	for d in [st.top, st.tree_window, st.class_tab, st.desc]:
		check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
	_check_targets(pm, size, tag + " 스킬")


func test_skill_screen_follows_the_reference_table() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	check_eq([pm.page, pm.tab, pm.member], ["sub", 1, 1], "준비: 듀얼리스트 A 스킬")
	for n in ["Close", "Tab_status", "Member_0", "TitlePlate", "Notice"]:
		check(pm.find_child(n, false, false) == null, "앞 파티 메뉴 틀 부품 %s 은 없다(R2-d 에서 지움)" % n)
	var first := {}
	for px in WINDOWS + [Vector2(1280, 960), WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 바탕은 줄지 않는다")
		check_eq([_rect(st.top.prev_button), _rect(st.top.next_button)], [Rect2(0, 0, 64, 64), Rect2(266, 0, 64, 64)], tag + ": 앞·다음 대원")
		check(pm.find_child("SkillBack", true, false) == null and not s.debug_snapshot()["buttons"].has("SkillBack"), tag + ": 「뒤로」 단추 없음(E1 ⑤)")
		await _check_skill_layers(pm, size, tag)
		var snap := [st.tree_window_rect(), st.desc_rect(), _rect(st.commit_button), st.node_rect(st.nodes.size() - 1)]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 높은 화면(1280×960): 트리 판이 아래로 늘어 설명 상자 위 8 까지, 설명 상자·키패드는 아래.
	var tall: Vector2 = await _window(Vector2(1280, 960))
	check_eq([st.tree_window_rect().end.y, st.desc_rect().end.y, _rect(pm.dir_pad).end.y], [tall.y - 217.0, tall.y - 8.0, tall.y - 9.0], "1280×960: 트리 판이 늘어난다")
	await _window(WINDOWS[0])
	# 노드 표시: 커서 = 하늘색 알약, 다른 노드 = 남색, 못 배움 = 회색.
	check_eq(st.nodes[st.cursor].theme_state(), "tree:selected", "커서 노드")
	var other := 1 if st.cursor != 1 else 0
	check(st.nodes[other].theme_state() in ["tree:normal", "tree:disabled"], "다른 노드 %s" % st.nodes[other].theme_state())
	# 초안 → 레벨 탭, 남은 SP 줄, 확정 창.
	var before := st.top.level_text
	await kit.tap(kit.center_of(st.plus_button))
	check_eq(st.draft.size(), 1, "「+」 → 초안")
	check(st.level_boxes[1] == 1, "레벨 칸: 초안 1 칸 %s" % str(st.level_boxes))
	check(st._sp_label.text.contains("→"), "남은 SP 줄에 초안 뒤 값: %s" % st._sp_label.text)
	check_eq(st.top.level_text, before, "Lv 띠는 그대로")
	# 띠(E1 ③): HP·TP 없음, 오른쪽 남은 SP 만. 확정 안내는 확정 창 글에.
	await kit.frames(1)
	check(not st.top.show_vitals and st.top.drawn["strip"].is_empty(), "스킬 띠에 HP·TP 가 없다: %s" % str(st.top.drawn["strip"]))
	var m1 := s.state.party.members[1]
	check_eq(st._sp_label.text, s.texts.t("party.sp_left_draft", {"sp": GrowthRules.sp_left(s.state.defs, m1), "after": GrowthRules.sp_left(s.state.defs, m1) - 1}),
		"띠 오른쪽 남은 SP n → m")
	check(st._sp_label.is_visible_in_tree() and _rect(st._sp_label).end.x <= pm.size.x and _rect(st._sp_label).position.y >= MemberHeader.INFO_Y, "남은 SP 는 띠 안 오른쪽")
	check_eq(st._note_label.text, "", "안내가 없으면 띠 가운데는 비어 있다(확정 안내 없음)")
	await kit.press_key(KEY_F)
	check_eq(pm.dialog_kind, "commit", "F → 확정 창")
	check(pm._dialog_text.text.contains("확정하면 되돌릴 수 없다"), "확정 창에 확정 안내: %s" % pm._dialog_text.text)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_R)
	check_eq([pm.dialog_kind, st.draft], ["", {}], "닫고 되돌림")
	# 안내(거부 이유 등)는 정보 띠 가운데(확정 안내 자리)에 보인다(앞 틀의 알림 줄은 감춰져 있다).
	pm.show_notice(pm.reason_text("no_draft"))
	check(st._note_label.is_visible_in_tree() and st._note_label.text == pm.notice, "안내가 정보 띠에 보인다: %s" % st._note_label.text)
	pm._clear_notice()
	check_eq(st._note_label.text, "", "안내가 지나면 비운다")
	# 대원 넘기기·뒤로(키패드 「취소」).
	await kit.tap(kit.center_of(st.top.next_button))
	check_eq(pm.member, 2, "→ 단추 → 다음 대원")
	await kit.tap(kit.center_of(pm.key_pad.buttons["back"]))
	check_eq([pm.page, pm.camp_cursor], ["root", SKILLS], "키패드 「취소」 → 캠프 뿌리(커서 스킬)")


## 노드 nd 의 그린 채움(알약 전체)과 바깥 테들(그리기 기록).
static func _node_fill(nd: SkillNode) -> Variant:
	for e in SheetParts.record(nd):
		if e["kind"] == "fill" and e["rect"] == Rect2(Vector2.ZERO, nd.size):
			return e["color"]
	return null


static func _node_outlines(nd: SkillNode) -> Array:
	return _drawn_entries(nd, "outline").map(func(e: Dictionary) -> Array: return [e["color"], int(e.get("width", 0))])


## 노드 색은 그린 것으로 본다(원작 잼): 보통 #044C76, 잠김·SP 부족 #24333C, 커서 하늘색 #3EC0CC(노랑 채움 아님), 잠긴 노드 위 커서는 회색에 하늘색 테,
## 초안 노드는 어느 모양이든 금색 테와 「+n」(채움은 그대로).
func test_skill_node_colours_are_read_from_what_is_drawn() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	GrowthRules.grant_exp(s.state, 1, s.state.defs.battle.growth.cum(4) - s.state.defs.battle.growth.cum(3))  # 초안 둘 뒤에도 SP 가 남게
	pm.refresh_view()
	var tree := s.state.defs.class_of(1).tree
	var normal := -1
	var locked := -1
	for j in tree.size():
		var k := st.nodes[j].status_kind
		if k == "learnable" and normal < 0 and j != st.cursor:
			normal = j
		if k == "locked" and locked < 0:
			locked = j
	check(normal >= 0 and locked >= 0 and st.cursor != locked, "준비: 보통 노드 %d·잠긴 노드 %d(커서 %d)" % [normal, locked, st.cursor])
	await kit.frames(2)
	check_eq(_node_fill(st.nodes[normal]), Color("044c76"), "보통 노드 채움 #044C76(원작)")
	check_eq(_node_fill(st.nodes[locked]), Color("24333c"), "잠긴 노드 채움 회색 #24333C(원작, 남색 아님)")
	var cur := st.cursor
	check_eq(_node_fill(st.nodes[cur]), Color("3ec0cc"), "커서 노드 채움 하늘색 #3EC0CC(원작)")
	check(not _is_yellow(_node_fill(st.nodes[cur])), "커서 채움은 노랑이 아니다")
	check(_node_outlines(st.nodes[normal]).all(func(o: Array) -> bool: return o[0] != UiTheme.BTN_PICK), "초안 없는 노드에 금색 테가 없다")
	# 잠긴 노드 위 커서: 회색 그대로, 하늘색 테 3.
	await kit.tap(kit.center_of(st.nodes[locked]))
	await kit.frames(2)
	check_eq(st.cursor, locked, "잠긴 노드 누르기 → 커서")
	check_eq(st.nodes[locked].theme_state(), "tree:disabled_selected", "잠긴 노드 위 커서 모양")
	check_eq(_node_fill(st.nodes[locked]), Color("24333c"), "잠긴 노드 위 커서: 채움은 회색 그대로")
	check(_node_outlines(st.nodes[locked]).has([Color("3ec0cc"), 3]), "잠긴 노드 위 커서: 하늘색 테 3 %s" % str(_node_outlines(st.nodes[locked])))
	# 초안: 커서가 있는 노드와 없는 노드 모두 금색 테와 「+1」, 채움은 그대로.
	await kit.tap(kit.center_of(st.nodes[normal]))
	await kit.tap(kit.center_of(st.plus_button))
	await kit.tap(kit.center_of(st.nodes[cur]))
	await kit.tap(kit.center_of(st.plus_button))
	await kit.frames(2)
	check(st.draft.size() == 2 and not st.nodes[normal].is_dim() and not st.nodes[cur].is_dim(), "준비: 초안 둘 %s, 두 노드 모두 배울 수 있음" % str(st.draft))
	for j in [normal, cur]:
		var nd := st.nodes[j]
		var want := Color("3ec0cc") if j == st.cursor else Color("044c76")
		check_eq(_node_fill(nd), want, "초안 노드 %d 채움은 그대로" % j)
		check(_node_outlines(nd).has([UiTheme.BTN_PICK, int(UiTheme.BTN_PICK_W)]), "초안 노드 %d 에 금색 테 %s" % [j, str(_node_outlines(nd))])
		check(_drawn_entries(nd, "text").any(func(e: Dictionary) -> bool: return e["text"] == "+1"), "초안 노드 %d 에 「+1」" % j)
		_check_drawn_text(nd, "초안 노드 %d" % j)
	_check_drawn_text(st.nodes[locked], "잠긴 노드")


## 노드 이름은 초안 「+n」과 함께여도 잘리지 않는다(E2-d 검토 M1): 실제 다섯 대원(네 직업)의 모든 노드 × 초안 1 과 그 노드가 보일 수 있는 가장 큰 「+n」
## (최대 − 배운 레벨), 1280·1728 에서. 그린 글자 크기로 잰 폭 ≤ 그린 폭(이름·「+n」·상태·Lv 상자 글 모두).
func test_skill_node_names_fit_with_every_real_draft() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	var seen := 0
	var tightest := 1e9
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		for i in s.state.party.members.size():
			st.draft = {}  # 초안이 남아 있으면 대원 바꾸기가 버리기 창을 띄운다
			pm.handle("member", i)
			await kit.frames(2)
			check_eq([pm.member, pm.dialog_kind], [i, ""], "준비: 대원 %d" % i)
			var m := s.state.party.members[i]
			var tree := s.state.defs.class_of(i).tree
			for j in tree.size():
				var sid := str(tree[j]["skill"])
				var room := s.state.defs.battle.skill(sid).max_level() - int(m.skills.get(sid, 0))
				for d in ([1, room] if room > 1 else [room]):
					if d <= 0:
						continue
					st.draft = {sid: d}
					st.refresh()
					await kit.frames(1)
					var nd := st.nodes[j]
					var tag := "%s 대원 %d %s +%d" % [str(size), i, sid, d]
					var texts := _drawn_entries(nd, "text")
					check(texts.any(func(e: Dictionary) -> bool: return e["text"] == "+%d" % d), tag + ": 「+n」 을 그렸다")
					for e in texts:
						var w := SheetParts.text_width(nd, e["text"], e["fs"])
						if e["text"] == nd.text:
							tightest = minf(tightest, e["rect"].size.x - w)
						check(w <= e["rect"].size.x + 0.5, "%s: 「%s」 %dpx 폭 %.1f ≤ 그린 폭 %.1f" % [tag, e["text"], e["fs"], w, e["rect"].size.x])
					seen += 1
	st.draft = {}
	st.refresh()
	check(seen >= 40, "본 경우 %d, 이름 여유 가장 작은 것 %.1f px" % [seen, tightest])
	pm.handle("member", 1)


## 누르고 있는 보통 노드(커서 아님)는 누름 채움 #0A5E8E 로 그린다(E2-d 검토 L1, 그린 기록).
func test_held_skill_node_draws_the_pressed_fill() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	var j := -1
	for k in st.nodes.size():
		if st.nodes[k].visible and k != st.cursor and st.nodes[k].status_kind == "learnable":
			j = k
			break
	check(j >= 0, "준비: 커서가 아닌 배울 수 있는 노드")
	var nd := st.nodes[j]
	kit.touch(FINGER, kit.center_of(nd), true)
	await kit.frames(2)
	check_eq([nd.held, nd.selected, nd.theme_state()], [true, false, "tree:pressed"], "누르는 중, 커서 아님")
	check_eq(_node_fill(nd), Color("0a5e8e"), "누름 채움 #0A5E8E(보통 #044C76 과 다르다)")
	_check_drawn_text(nd, "누른 노드")
	kit.touch(FINGER, Vector2(-500, -500), false)
	await kit.frames(2)
	check_eq(_node_fill(nd), Color("044c76"), "뗀 뒤 보통 채움")


## 설명 상자 머리(공용 DescBox "tree" 모양): 머리 #2C78A6 에 이름, 레벨 탭(배움·초안 = 짙은 탭, 초안은 금색 테, 노랑 채움 없음), 오른쪽 「Lv n」 막대(n = 배움 + 초안,
## 채움 폭 = 비 × 길). 몸 줄은 스킬 줄 그대로(첫 줄 시안).
func test_skill_desc_head_shows_level_tabs_and_lv_bar() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	check(st.desc is DescBox and st.desc.look == "tree", "설명 상자는 공용 DescBox 의 tree 모양")
	var box := Rect2(Vector2.ZERO, st.desc.size)
	for step in 3:
		await kit.frames(2)
		var sid := st.cursor_skill()
		var learned: int = st.level_boxes[0]
		var drafted: int = st.level_boxes[1]
		var mx: int = st.level_boxes[2]
		var tag := "%s 배움 %d 초안 %d" % [sid, learned, drafted]
		check_eq([learned, drafted, mx], [int(s.state.party.members[1].skills.get(sid, 0)), int(st.draft.get(sid, 0)), s.state.defs.battle.skill(sid).max_level()], tag + ": 레벨 칸 값")
		var fills := _drawn_entries(st.desc, "fill")
		var at := func(r: Rect2) -> Array: return fills.filter(func(e: Dictionary) -> bool: return e["rect"] == r).map(func(e: Dictionary) -> Color: return e["color"])
		check_eq(at.call(ListParts.tree_head_rect(box)), [Color("2c78a6")], tag + ": 머리 채움 #2C78A6")
		var texts := _drawn_entries(st.desc, "text").map(func(e: Dictionary) -> String: return e["text"])
		check(texts.has(s.texts.t(s.state.defs.battle.skill(sid).name_key)), tag + ": 머리에 이름")
		for k in range(1, mx + 1):
			var want := ListParts.TREE_TAB_ON if k <= learned + drafted else ListParts.TREE_TAB_OFF
			check_eq(at.call(ListParts.tree_tab_rect(box, k)), [want], "%s: 레벨 탭 %d" % [tag, k])
			var edged := _drawn_entries(st.desc, "outline").any(func(e: Dictionary) -> bool: return e["rect"] == ListParts.tree_tab_rect(box, k))
			check_eq(edged, k > learned and k <= learned + drafted, "%s: 레벨 탭 %d 금색 테는 초안 칸만" % [tag, k])
		check(at.call(ListParts.tree_tab_rect(box, mx + 1)).is_empty(), tag + ": 최대 레벨 다음 탭은 없다")
		# 「Lv n」 막대.
		check(texts.has(s.texts.t("party.level", {"level": learned + drafted})), tag + ": 막대 글 「Lv %d」" % (learned + drafted))
		check_eq(at.call(ListParts.tree_bar_label_rect(box)), [ListParts.TREE_BAR_LABEL], tag + ": 막대 글 칸")
		check_eq(at.call(ListParts.tree_bar_track_rect(box)), [ListParts.TREE_BAR_TRACK], tag + ": 막대 길")
		var t := ListParts.tree_bar_track_rect(box).grow(-4.0)
		var lw := fills.filter(func(e: Dictionary) -> bool: return e["color"] == ListParts.TREE_BAR_LEARNED)
		var dw := fills.filter(func(e: Dictionary) -> bool: return e["color"] == ListParts.TREE_BAR_DRAFT)
		check_eq(lw.size(), 1 if learned > 0 else 0, tag + ": 배운 몫 채움")
		check_eq(dw.size(), 1 if drafted > 0 else 0, tag + ": 초안 몫 채움")
		if learned > 0:
			check(is_equal_approx(lw[0]["rect"].size.x, t.size.x * learned / mx) and lw[0]["rect"].position.x == t.position.x, "%s: 배운 몫 폭 %s = %d/%d" % [tag, str(lw[0]["rect"]), learned, mx])
		if drafted > 0:
			check(is_equal_approx(dw[0]["rect"].size.x, t.size.x * drafted / mx), "%s: 초안 몫 폭 %s = %d/%d" % [tag, str(dw[0]["rect"]), drafted, mx])
		for e in fills:
			check(not _is_yellow(e["color"]), "%s: 설명 상자에 노랑 채움 없음(%s)" % [tag, (e["color"] as Color).to_html(false)])
		# 몸 줄: 스킬 줄 그대로, 첫 줄 시안.
		var head_end := ListParts.tree_head_rect(box).end.y
		var body := _drawn_entries(st.desc, "text").filter(func(e: Dictionary) -> bool: return e["rect"].position.y + e["fs"] > head_end)
		check_eq(body.map(func(e: Dictionary) -> String: return e["text"]), st.desc_lines, tag + ": 몸 줄")
		if not body.is_empty():
			check_eq(body[0]["color"], ListParts.TREE_DESC_ACCENT, tag + ": 첫 줄 시안")
			check_eq(Vector2(body[0]["rect"].position.x, body[0]["rect"].position.y + body[0]["fs"]), st.desc_line_pos(0), tag + ": 첫 줄 자리")
		_check_drawn_text(st.desc, tag)
		await kit.tap(kit.center_of(st.plus_button))


## 소지품·장비의 설명 상자("bag", 선택지 없음)는 E2-b·E2-c 그대로 그린다: 굽은 끝 테, 머리·몸 채움, 줄 간격 30 에 넷까지, 18px. tree 모양의 것은 하나도 없다.
func test_desc_box_bag_look_is_unchanged() -> void:
	var s := await _open()
	var pm := s.party_menu
	var d := DescBox.new()
	s.add_child(d)
	d.position = Vector2(300, 300)
	d.size = Vector2(702, 182)
	var ls: Array[String] = ["첫째 줄", "둘째 줄", "셋째 줄", "넷째 줄", "다섯째 줄"]
	d.show_desc("이름", "", ls)
	await kit.frames(2)
	check_eq(d.look, "bag", "기본 모양은 bag")
	var r := Rect2(Vector2.ZERO, d.size)
	var rec := SheetParts.record(d)
	var fp := ListParts.frame_polygon(r)
	check_eq([rec[0]["kind"], rec[0]["rect"], rec[0]["color"]], ["poly", SheetParts._bounds(fp), ListParts.FRAME], "테 다각형(END_W 24)")
	check(fp[6].x == r.end.x and fp[0].x == r.end.x - ListParts.END_W, "테 오른쪽 끝은 END_W 24 로 굽는다")
	var fills := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "fill")
	check_eq(fills.map(func(e: Dictionary) -> Array: return [e["rect"], e["color"]]),
		[[ListParts.head_rect(r), ListParts.DESC_HEAD], [ListParts.body_rect(r), ListParts.DESC_BODY]], "머리·몸 채움")
	var texts := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "text")
	check_eq(texts.map(func(e: Dictionary) -> String: return e["text"]), ["이름", "첫째 줄", "둘째 줄", "셋째 줄", "넷째 줄"], "이름과 줄 넷까지")
	check_eq([texts[0]["fs"], texts[0]["rect"].position.x], [ListParts.HEAD_FS, r.position.x + ListParts.END_W + ListParts.DESC_TEXT_PAD], "이름 20px, 테 + 16")
	var b := ListParts.body_rect(r)
	for i in 4:
		var e: Dictionary = texts[i + 1]
		check_eq([e["fs"], e["rect"].position.x, e["rect"].position.y + e["fs"]], [18, b.position.x + 16.0, b.position.y + 6.0 + (i + 1) * 30.0 - 8.0],
			"줄 %d: 18px, 몸 + 16, 간격 30" % i)
	var tree_cols := [ListParts.TREE_DESC_OUTER, ListParts.TREE_DESC_EDGE, ListParts.TREE_DESC_BODY, ListParts.TREE_DESC_HEAD, ListParts.TREE_TAB_ON,
		ListParts.TREE_TAB_OFF, ListParts.TREE_BAR_LABEL, ListParts.TREE_BAR_TRACK]
	check(rec.all(func(e: Dictionary) -> bool: return not tree_cols.has(e["color"]) and e["kind"] != "outline"), "tree 모양의 칠·테가 없다")
	# 실제 소지품·장비 설명 상자도 bag 이고 같은 꼴(테·머리·몸)로 시작한다.
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(2)
	var idesc: DescBox = pm.items_tab.desc
	var ir := Rect2(Vector2.ZERO, idesc.size)
	var irec := SheetParts.record(idesc)
	check(idesc.look == "bag" and idesc.opts.is_empty(), "소지품 설명 상자: bag, 선택지 없음")
	check_eq([irec[0]["kind"], irec[0]["rect"], irec[0]["color"]], ["poly", SheetParts._bounds(ListParts.frame_polygon(ir)), ListParts.FRAME], "소지품 설명 상자 테")
	check(irec.any(func(e: Dictionary) -> bool: return e["kind"] == "fill" and e["rect"] == ListParts.head_rect(ir) and e["color"] == ListParts.DESC_HEAD), "소지품 머리")
	d.queue_free()


## 캠프 확인 창 = 알림 띠(부품 K, BannerBox): 스킬의 확정·버리기와 기록의 새 게임. 844×200 가운데, 양 끝이 굽은 꼴, 몸 #0C5C52 에 흰 글자(두 줄까지),
## 단추 둘은 몸 안 오른쪽(원작 Ⓐ 자리), 키패드에 닿지 않는다. 처음 고른 쪽은 「돌아가기」.
func _check_banner(pm: PartyMenu, size: Vector2, tag: String) -> void:
	await kit.frames(2)
	var bp := pm.dialog_panel
	check(bp is BannerBox and bp.is_visible_in_tree(), tag + ": 창은 BannerBox")
	var br := _rect(bp)
	check_eq(br, Rect2(((size - Vector2(844, 200)) / 2.0).round(), Vector2(844, 200)), tag + ": 알림 띠 844×200 가운데")
	var local := Rect2(Vector2.ZERO, bp.size)
	var rec := SheetParts.record(bp)
	var polys := rec.filter(func(e: Dictionary) -> bool: return e["kind"] == "poly")
	check(polys.size() == 4, tag + ": 알림 띠 다각형 넷(바깥·호·선·몸) %d" % polys.size())
	if polys.size() == 4:
		check_eq([polys[0]["rect"], polys[0]["color"]], [local, ListParts.BANNER_EDGE], tag + ": 바깥 다각형 = 띠 전체")
		check_eq([polys[3]["rect"], polys[3]["color"]], [ListParts.banner_body_rect(local), Color("0c5c52")], tag + ": 몸 #0C5C52")
	var bpts := ListParts.banner_polygon(local)
	check(bpts.size() > 8 and is_equal_approx(bpts[0].x, local.end.x - ListParts.BANNER_END) and is_equal_approx(bpts[6].x, local.end.x)
		and is_equal_approx(bpts[19].x, local.position.x), tag + ": 양 끝이 괄호처럼 굽는다(위아래 끝은 40 안, 가운데는 바깥 끝)")
	var body := Rect2(br.position + ListParts.banner_body_rect(local).position, ListParts.banner_body_rect(local).size)
	var tx := _rect(pm._dialog_text)
	check(body.encloses(tx), tag + ": 글 %s 은 몸 %s 안" % [str(tx), str(body)])
	var lt := pm._dialog_text
	check(lt.get_line_count() <= 2 and lt.get_line_count() * lt.get_line_height() <= tx.size.y + 0.5,
		"%s: 글 「%s」 두 줄 안(%d 줄 × %d ≤ %.0f)" % [tag, lt.text, lt.get_line_count(), lt.get_line_height(), tx.size.y])
	var fg: Color = pm._dialog_text.get_theme_color("font_color")
	check(contrast(fg, polys[3]["color"] if polys.size() == 4 else Color.BLACK) >= 4.5, tag + ": 글자 %s 대비 ≥ 4.5" % fg.to_html(false))
	var pads := [_rect(pm.dir_pad), _rect(pm.active_key_pad())]
	for b in pm.dialog_buttons:
		var r := _rect(b)
		check(body.encloses(r) and r.size.x >= 64.0 and r.size.y >= 64.0 and not r.intersects(tx), "%s: %s %s 는 몸 안, 글 밖, 64 이상" % [tag, b.name, str(r)])
	check(_rect(pm.dialog_buttons[0]).end.x <= _rect(pm.dialog_buttons[1]).position.x and _rect(pm.dialog_buttons[1]).end.x > br.get_center().x,
		tag + ": 「돌아가기」 → 둘째 단추, 오른쪽(Ⓐ 자리)")
	for p in pads:
		check(not br.intersects(p), "%s: 알림 띠 %s 는 키패드 %s 에 닿지 않는다" % [tag, str(br), str(p)])
	check_eq(pm.dialog_pick, 0, tag + ": 처음 고른 쪽 「돌아가기」")


## 노랑 채움(07 §9.9 노랑 하나): 스킬 화면이 그린 채움·다각형과 보이는 단추 모양의 채움. 확인 창이 떠 있으면 창 층 밖은 어둡게 하는 판과 겹친 색으로 센다.
func _camp_yellow(pm: PartyMenu) -> Array:
	var out := []
	var dim := pm.dialog_layer.is_visible_in_tree()
	var dimmed := func(c: Color, behind: bool) -> Color: return c.lerp(Color(0, 0, 0), PartyMenu.DIALOG_DIM.a) if dim and behind else c
	var cs: Array = []
	if pm.tab == 1 and pm.page == "sub":
		var st := pm.skill_tab
		cs = [st.tree_window, st.class_tab, st.tree_area.content, st.desc]
		for nd in st.nodes:
			if nd.is_visible_in_tree():
				cs.append(nd)
	if dim:
		cs.append(pm.dialog_panel)
	for ci in cs:
		for e in SheetParts.record(ci):
			if (e["kind"] == "fill" or e["kind"] == "poly") and _is_yellow(dimmed.call(e["color"], not pm.dialog_layer.is_ancestor_of(ci))):
				out.append(str((ci as Node).name))
	for n in pm.find_children("*", "PartyButton", true, false):
		var b := n as PartyButton
		if b is SkillNode or not b.is_visible_in_tree():
			continue
		var lk := UiTheme.look(b.theme_state())
		if lk["fill"] and _is_yellow(dimmed.call(lk["bottom"], not pm.dialog_layer.is_ancestor_of(b))):
			out.append(str(b.name))
	return out


func test_camp_dialog_is_the_banner_for_skills_and_records() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	for px in WINDOWS + [Vector2(1280, 960)]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		await kit.tap(kit.center_of(st.plus_button))
		await kit.press_key(KEY_F)
		check_eq(pm.dialog_kind, "commit", tag + ": 확정 창")
		await _check_banner(pm, size, tag + " 확정")
		check_eq(_camp_yellow(pm), ["DialogBack"], tag + " 확정: 노랑 채움은 창의 커서 단추 하나(트리 0)")
		await kit.press_key(KEY_RIGHT)
		check_eq(pm.dialog_pick, 1, tag + ": → 둘째 단추")
		await kit.press_key(KEY_ESCAPE)
		check_eq([pm.dialog_kind, st.draft.size()], ["", 1], tag + ": Esc = 돌아가기, 초안 그대로")
		await kit.press_key(KEY_ESCAPE)
		check_eq(pm.dialog_kind, "discard", tag + ": 초안 중 뒤로 → 버리기 창")
		await _check_banner(pm, size, tag + " 버리기")
		await kit.press_key(KEY_ESCAPE)
		await kit.press_key(KEY_R)
	# 가장 긴 실제 글이 두 줄 안: 확정 창 SP 두 자리(99), 버리기, 새 게임.
	await _window(WINDOWS[0])
	await kit.tap(kit.center_of(st.plus_button))
	await kit.press_key(KEY_F)
	for t in [s.texts.t("party.dialog.commit_text", {"n": 99}), s.texts.t("party.dialog.discard_text"), s.texts.t("menu.confirm_new_game")]:
		pm._dialog_text.text = t
		await kit.frames(2)
		var lt := pm._dialog_text
		check(lt.get_line_count() <= 2 and lt.get_line_count() * lt.get_line_height() <= lt.size.y + 0.5 and lt.get_visible_line_count() == lt.get_line_count(),
			"가장 긴 글 「%s」 두 줄 안(%d 줄 × %d)" % [t, lt.get_line_count(), lt.get_line_height()])
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_R)
	# 기록의 새 게임 창도 같은 띠. 기록의 커서 단추는 뒤에서 고른 그대로이고 어둡게 하는 판과 겹쳐 노랑이 아니다.
	await kit.press_key(KEY_5)
	for px in WINDOWS + [Vector2(1280, 960)]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s) 기록" % [str(px), str(size)]
		pm.handle("record_new_game")
		await kit.frames(1)
		check_eq(pm.dialog_kind, "new_game", tag + ": 새 게임 창")
		await _check_banner(pm, size, tag + " 새 게임")
		check_eq(_camp_yellow(pm), ["DialogBack"], tag + " 새 게임: 어둡게 하는 판 앞의 노랑은 창의 커서 단추 하나")
		await kit.press_key(KEY_ESCAPE)
		check_eq([pm.dialog_kind, pm.tab], ["", 4], tag + ": Esc = 돌아가기(기록 그대로)")
	await _window(WINDOWS[0])


## 노랑 채움은 스킬 트리에 없고, 확정·버리기 창이 뜨면 창의 커서 단추 하나다(커서 노드·초안 노드·레벨 탭·막대 모두 채움 노랑 아님).
func test_skill_screen_has_at_most_one_yellow_fill() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	await kit.frames(2)
	check_eq(_camp_yellow(pm), [], "트리(초안 없음): 노랑 채움 0")
	await kit.tap(kit.center_of(st.plus_button))
	await kit.press_key(KEY_RIGHT)
	await kit.tap(kit.center_of(st.plus_button))
	await kit.frames(2)
	check(not st.draft.is_empty(), "준비: 초안")
	check_eq(_camp_yellow(pm), [], "트리(초안·커서): 노랑 채움 0")
	for j in st.nodes.size():
		if st.nodes[j].visible and st.nodes[j].status_kind == "locked":
			await kit.tap(kit.center_of(st.nodes[j]))
			break
	await kit.frames(2)
	check_eq(_camp_yellow(pm), [], "트리(잠긴 노드 위 커서): 노랑 채움 0")
	await kit.press_key(KEY_F)
	await kit.frames(2)
	check_eq(_camp_yellow(pm), ["DialogBack"], "확정 창: 노랑 채움 하나(창의 커서 단추)")
	await kit.press_key(KEY_RIGHT)
	await kit.frames(1)
	check_eq(_camp_yellow(pm), ["DialogOk"], "확정 창 → : 노랑 채움 하나(옮긴 커서 단추)")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(1)
	check_eq(pm.dialog_kind, "discard", "준비: 버리기 창")
	check_eq(_camp_yellow(pm), ["DialogBack"], "버리기 창: 노랑 채움 하나")


## 선의 「Lv n」(원작 「Lv1」「Lv3」): 실제 네 직업 트리 × 세 크기에서 선행마다 하나, 그 레벨, 트리 영역 안, 노드·다른 글·다른 선에 걸리지 않고, 판 위 대비 4.5 이상.
func test_condition_labels_name_the_required_level() -> void:
	var s := await _skills_open()
	var pm := s.party_menu
	var st := pm.skill_tab
	var seen := 0
	for px in WINDOWS + [Vector2(1280, 960)]:
		var size: Vector2 = await _window(px)
		for i in s.state.party.members.size():
			pm.handle("member", i)
			await kit.frames(2)
			var tag := "%s 대원 %d" % [str(size), i]
			var c := s.state.defs.class_of(i)
			var want := []
			for j in c.tree.size():
				for r in c.tree[j].get("requires", []):
					want.append([int(c.tree_index[r["skill"]]), j, s.texts.t("party.level", {"level": r["level"]})])
			var got := st.condition_labels.map(func(l: Dictionary) -> Array: return [l["from"], l["to"], l["text"]])
			check_eq(got, want, tag + ": 선행마다 「Lv n」 하나")
			var content := Rect2(0, 0, st.tree_rect().size.x, st.tree_area.content_height)
			var paths: Array[PackedVector2Array] = []
			for l in st.condition_labels:
				paths.append(PartySkillTab.connector_path(st.node_rect(l["from"]), st.node_rect(l["to"]), st.pitch() - st.node_size()))
			for k in st.condition_labels.size():
				var lr: Rect2 = st.condition_labels[k]["rect"]
				seen += 1
				check(content.encloses(lr), "%s: 「%s」 %s 는 트리 영역 안" % [tag, st.condition_labels[k]["text"], str(lr)])
				for j in c.tree.size():
					check(not lr.intersects(st.node_rect(j)), "%s: 「%s」 %s 가 노드 %d 에 걸린다" % [tag, st.condition_labels[k]["text"], str(lr), j])
				for k2 in st.condition_labels.size():
					if k2 != k:
						check(not lr.intersects(st.condition_labels[k2]["rect"]), "%s: 「Lv」 글 %d 와 %d 가 겹친다" % [tag, k, k2])
						check(not PartySkillTab.path_hits(paths[k2], lr), "%s: 「Lv」 글 %d 가 다른 선 %d 에 걸린다" % [tag, k, k2])
			var drawn := _drawn_entries(st.tree_area.content, "text")
			check_eq(drawn.map(func(e: Dictionary) -> String: return e["text"]), want.map(func(w: Array) -> String: return w[2]), tag + ": 그린 「Lv n」")
			for e in drawn:
				check(contrast(e["color"], PartySkillTab.PANEL) >= 4.5, "%s: 「%s」 %s on 판 대비" % [tag, e["text"], (e["color"] as Color).to_html(false)])
				check(SheetParts.text_width(st.tree_area.content, e["text"], e["fs"]) <= e["rect"].size.x + 0.5, "%s: 「%s」 가 글 상자에 든다" % [tag, e["text"]])
	check(seen >= 24, "본 「Lv n」 %d 개" % seen)
	# 판 채움은 그린 것으로 #0C6A9E(원작).
	await _window(WINDOWS[0])
	await kit.frames(2)
	var panel := _drawn_entries(st.tree_window, "fill").filter(func(e: Dictionary) -> bool: return e["color"] == Color("0c6a9e"))
	check_eq(panel.size(), 1, "트리 판 채움 #0C6A9E 를 그렸다")
	pm.handle("member", 1)


# ---- 장비(07 §9.9 E2-c, D27 ③, research 08 §5.1: 원작 I HD 장비 yt_eo1hd_04 를 좌우 그대로) ----

const SERVO := "equip.servo_gauntlet"
const MESH := "equip.mesh_armor"
const NANO_ROD := "equip.nano_rod"


## 장비 화면 준비: 듀얼리스트 A(칸 0 트윈 엣지 · 1 패딩 코트 · 2 그립 장갑 · 3 빈 칸), 가방에 이온 세이버(낄 수 있음)·나노 로드(직업이 못 낌)·
## 서보 건틀릿(힘 +3)·메시 아머(민첩 -2).
func _equip_open() -> DungeonScreen:
	var s := await _open()
	for id in ["equip.ion_saber", NANO_ROD, SERVO, MESH]:
		GrowthRules.supply(s.state, id, 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	return s


func _check_equip_layers(pm: PartyMenu, size: Vector2, tag: String) -> void:
	var et := pm.equip_tab
	var screen := Rect2(Vector2.ZERO, size)
	var w := size.x
	var h := size.y
	# 왼쪽 열: 상태와 같은 자리(왼쪽 위 앵커).
	check_eq(et.class_rect(), Rect2(92, 190, 318, 45), tag + ": 직업 문패 = 상태 자리")
	for i in 6:
		check_eq(et.stat_rect(i), Rect2(66, 297 + 33 * i, 319, 28), "%s: 능력치 줄 %d = 상태 자리" % [tag, i])
	check_eq([et.gear_row_rect(0), et.gear_row_rect(1)], [Rect2(66, 505, 374, 34), Rect2(66, 543, 374, 34)], tag + ": 공격·방어 두 줄 = 상태 자리")
	for i in 4:
		check_eq(et.equip_rect(i), Rect2(80, 590 + 30 * i, 295, 28), "%s: 장비 줄 %d = 상태 자리" % [tag, i])
	check_eq(_rect(et.left).position, Vector2.ZERO, tag + ": 왼쪽 열은 왼쪽 위")
	# 위 띠(MemberHeader): 화면 폭 전체, 오른쪽 위는 비어 있다.
	check_eq(_rect(et.top), Rect2(0, 0, w, 118), tag + ": 대원 띠 0,0 W×118")
	# 목록 창: 오른쪽 앵커 x W − 440 ~ W − 8, y 130 부터 줄 단위, 설명 상자 위 23 이상 떨어져 한 줄 더 들지 않는 높이.
	var lw := _rect(et.window)
	var dr := _rect(et.desc)
	check_eq([lw.position.x, lw.end.x, lw.position.y], [w - 440.0, w - 8.0, 130.0], tag + ": 목록 창 x W − 440 ~ W − 8, y 130")
	var n := ListParts.rows_for(lw.size.y)
	check_eq(lw.size.y, ListParts.list_height(n), tag + ": 목록 창 높이는 줄 단위 %d 줄" % n)
	check(dr.position.y - lw.end.y >= 23.0 and dr.position.y - (lw.position.y + ListParts.list_height(n + 1)) < 23.0,
		"%s: 목록 창은 설명 상자 위 23 이상, 한 줄 더는 들지 않는다 (아래 %.0f, 상자 %.0f)" % [tag, lw.end.y, dr.position.y])
	check(n >= 5, "%s: 줄 다섯 이상(%d)" % [tag, n])
	if h == 720.0:
		check_eq(n, 5, tag + ": 720 높이에서 다섯 줄(y 130~490)")
	# 설명 상자: 오른쪽 끝 W − 130, 왼쪽 끝 max(664, W − 863), y H − 197 ~ H − 8.
	check_eq(dr, Rect2(maxf(664.0, w - 863.0), h - 197.0, w - 130.0 - maxf(664.0, w - 863.0), 189.0), tag + ": 설명 상자")
	# 초상: 상태와 같은 가운데를 왼쪽 열 끝 464 ~ 목록 창 왼쪽 − 8 로 자른다.
	var pr := et.portrait_rect()
	var cx := w / 2.0 + 20.0
	check_eq([pr.position.x, pr.end.x, pr.position.y, pr.end.y], [maxf(cx - 240.0, 464.0), minf(cx + 240.0, lw.position.x - 8.0), 118.0, h], tag + ": 초상")
	# 키패드: 방향 십자 (456, H − 209)(왼쪽 열 장비 줄을 덮지 않게), 세로 「취소」「선택」 (W − 118, H − 172).
	var dp := _rect(pm.dir_pad)
	var kp := _rect(pm.key_pad_stacked)
	check_eq(dp, Rect2(456, h - 209, 200, 200), tag + ": 방향 십자 (456, H − 209)")
	check(pm.key_pad_stacked.is_visible_in_tree() and not pm.key_pad.is_visible_in_tree(), tag + ": 세로 「취소」「선택」")
	check_eq(kp, Rect2(w - 118, h - 172, 110, 151), tag + ": 「취소」「선택」 (W − 118, H − 172)")
	if w == 1280.0:
		check_eq([dr.position.x - dp.end.x, kp.position.x - dr.end.x], [8.0, 12.0], tag + ": 설명 상자와 키패드 사이 8 · 12")
	# 겹침: 키패드와 설명 상자가 초상 앞에 오는 것만 된다.
	var blocks := {"name": et.top.name_tab_rect(), "class": et.class_extent(), "list": lw, "desc": dr, "dir_pad": dp, "keys": kp, "portrait": pr}
	for i in 6:
		blocks["stat%d" % i] = et.stat_rect(i)
	for r in 2:
		blocks["gear%d" % r] = et.gear_row_rect(r)
	for i in 4:
		blocks["equip%d" % i] = et.equip_rect(i)
	var allowed := [["dir_pad", "portrait"], ["keys", "portrait"], ["desc", "portrait"]]
	var keys := blocks.keys()
	for i in keys.size():
		var a: Rect2 = blocks[keys[i]]
		check(screen.encloses(a), "%s: %s %s 화면 안" % [tag, keys[i], str(a)])
		if keys[i] != "name":
			check(a.position.y >= MemberHeader.H, "%s: %s 는 위 띠 아래" % [tag, keys[i]])
		for j in range(i + 1, keys.size()):
			if [keys[i], keys[j]] in allowed or [keys[j], keys[i]] in allowed:
				continue
			check(not a.intersects(blocks[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
	# 줄은 목록 창 줄 자리 안(보이는 것), 64 이상.
	var rr := ListParts.rows_rect(lw)
	for b in et.slot_rows + et.rows:
		if b.is_visible_in_tree():
			check(rr.encloses(pm.clipped_rect(b).grow(-0.5)) and b.size.y >= 64.0, "%s: %s 는 목록 창 줄 자리 안" % [tag, b.name])
	# 트리 순서(층 표): 초상 → 띠 → 왼쪽 열 → 목록 창 → 설명 상자 → 띠 안내 → (캠프) 키패드. 장식은 누르기를 뒤로.
	var order: Array = [et.portrait, et.top, et.left, et.window, et.desc, et.note_label].map(func(c: Control) -> int: return c.get_index())
	var sorted := order.duplicate()
	sorted.sort()
	check(order == sorted, tag + ": 그리는 순서 초상 → 띠 → 왼쪽 열 → 목록 창 → 설명 상자 → 안내 %s" % str(order))
	for d in [et, et.portrait, et.top, et.left, et.window, et.desc, et.note_label]:
		check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
	# 상점 틀은 캠프 어디에도 없다(마을 상점만 쓴다, 08 §8).
	var shop_parts := pm.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n is ShopFrame or n is CharPanel or n is EquipTotals)
	check_eq(shop_parts.map(func(n: Node) -> String: return str(n.name)), [], tag + ": 캠프에 ShopFrame·CharPanel·EquipTotals 가 없다")
	_check_targets(pm, size, tag)


func test_equip_screen_follows_the_reference_table() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	check_eq([pm.page, pm.tab, pm.member, et.list_open], ["sub", 2, 1, false], "준비: 듀얼리스트 A 장비")
	var first := {}
	for px in WINDOWS + [Vector2(1280, 960), WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		for open in [false, true]:
			if open != et.list_open:
				await kit.press_key(KEY_ENTER if open else KEY_ESCAPE)
				await kit.frames(1)
			var tag := "%s(논리 %s) 장비 %s" % [str(px), str(size), "목록" if open else "칸"]
			_check_equip_layers(pm, size, tag)
		var snap := [_rect(et.window), _rect(et.desc), _rect(pm.dir_pad), et.portrait_rect()]
		if first.has(px):
			check_eq(snap, first[px], "%s: 크기를 바꿨다 돌아와도 같은 자리(앵커)" % str(px))
		first[px] = snap
	# 넓은 화면(1728): 왼쪽 열·방향 십자는 왼쪽, 목록 창·설명 상자·「취소」「선택」은 오른쪽 앵커.
	var wide: Vector2 = await _window(WINDOWS[1])
	check_eq([_rect(et.window).end.x, _rect(et.desc).end.x, _rect(pm.key_pad_stacked).end.x, _rect(pm.dir_pad).position.x, et.stat_rect(0).position.x],
		[wide.x - 8.0, wide.x - 130.0, wide.x - 8.0, 456.0, 66.0], "1728: 앵커")
	# 높은 화면(1280×960): 목록 창은 줄 단위로 늘어 여덟 줄, 설명 상자·키패드는 아래.
	var tall: Vector2 = await _window(Vector2(1280, 960))
	check_eq([ListParts.rows_for(_rect(et.window).size.y), _rect(et.desc).end.y, _rect(pm.dir_pad).end.y], [8, tall.y - 8.0, tall.y - 9.0], "1280×960: 여덟 줄, 아래 앵커")
	await _window(WINDOWS[0])


## 칸 고르기·목록을 키·키패드·누르기로(07 §9.7 키 표, E2-c): 목록 차례, 커서 시작, 장착·빼기·「E」 닫기, 못 끼는 줄 안내, 대원 바꾸기, ←→·Q/E.
func test_equip_slot_and_list_modes_by_keys_keypad_and_taps() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	var m := s.state.party.members[1]
	var kp := pm.key_pad_stacked
	# 칸 고르기: 줄 넷 = 종류 아이콘 + 이름(빈 칸은 빈 아이콘 + 「비어 있음」). ↑↓ 칸 커서(돌지 않음).
	check_eq(et.slot_rows.map(func(b: ListButton) -> String: return b.name), ["Slot_0", "Slot_1", "Slot_2", "Slot_3"], "칸 줄 이름")
	check_eq(et.slot_rows.map(func(b: ListButton) -> Array: return [b.icon_name, b.text]),
		[["kind_sword", pm.item_name(m.equip[0])], ["kind_body", pm.item_name(m.equip[1])], ["kind_hands", pm.item_name(m.equip[2])], ["", s.texts.t("party.slot.empty")]],
		"칸 줄: 아이콘 + 이름, 빈 칸")
	check(et.slot_rows.all(func(b: ListButton) -> bool: return b.is_visible_in_tree()) and et.rows.all(func(b: ListButton) -> bool: return not b.is_visible_in_tree()), "칸 줄만 보인다")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_UP)
	check_eq([et.cursor, pm.accepted_inputs], [0, n], "첫 칸 ↑ = 아무 일 없음(돌지 않음)")
	for k in 4:
		await kit.press_key(KEY_DOWN)
	check_eq(et.cursor, 3, "↓ 넷 → 마지막 칸(돌지 않음)")
	await kit.tap(kit.center_of(pm.dir_pad.buttons["up"]))
	check_eq(et.cursor, 2, "키패드 ↑ = ↑")
	# ←→·Q/E = 대원.
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.member, 2, "칸 고르기 → = 다음 대원")
	await kit.press_key(KEY_Q)
	check_eq(pm.member, 1, "Q = 앞 대원")
	await kit.tap(kit.center_of(pm.dir_pad.buttons["left"]))
	await kit.press_key(KEY_E)
	check_eq(pm.member, 1, "키패드 ← · E")
	check(pm.pad_state()["left"] and pm.pad_state()["right"], "칸 고르기: 키패드 ←→ 켜짐")
	# 「선택」 = 커서 칸 목록. 목록 차례: 「E」 → 낄 수 있는 가방 장비 → 흐린 못 끼는 것 → 「빼기」.
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(et.cursor, 0, "준비: 칸 0")
	await kit.press_key(KEY_ENTER)
	check(et.list_open and et.slot_rows.all(func(b: ListButton) -> bool: return not b.is_visible_in_tree()), "Enter → 칸 0 목록(칸 줄 감춤)")
	check_eq([et.row_items, et.row_block, et.equipped_row, et.list_cursor], [["equip.twin_edge", "equip.ion_saber", NANO_ROD, ""], ["", "", "class", ""], 0, 0],
		"목록 차례 E · 낄 수 있음 · 흐림 · 빼기, 커서는 「E」 줄")
	check_eq(et.rows.slice(0, 4).map(func(b: ListButton) -> Array: return [str(b.name), b.icon_name, b.equipped, b.dimmed, b.right]),
		[["Row_0", "kind_sword", true, false, ""], ["Row_1", "kind_sword", false, false, "1개"], ["Row_2", "kind_staff", false, true, "1개"], ["Row_3", "", false, false, ""]],
		"줄: 「E」 표, 가방 줄 「n개」, 흐린 줄, 빈 아이콘 「빼기」")
	check_eq(et.rows[3].text, s.texts.t("party.unequip"), "「빼기」 글")
	var info := pm.debug_info(func(p: Vector2, _c: Control) -> Array: return [p.x, p.y])
	check_eq((info["equip_rows"] as Array).map(func(r: Dictionary) -> Array: return [r["item"], r["block"], str(r["button"]), r["equipped"]]),
		[["equip.twin_edge", "", "Row_0", true], ["equip.ion_saber", "", "Row_1", false], [NANO_ROD, "class", "Row_2", false], ["", "", "Row_3", false]], "스냅숏 equip_rows 에 equipped")
	# ←→ 흐림, Q/E 없음, ↑ 첫 줄 = 아무 일 없음.
	n = pm.accepted_inputs
	for k in [KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E, KEY_UP]:
		await kit.press_key(k)
	check_eq([pm.member, et.list_open, et.list_cursor, pm.accepted_inputs], [1, true, 0, n], "목록: ←→·Q/E·첫 줄 ↑ = 아무 일 없음")
	check(not pm.pad_state()["left"] and not pm.pad_state()["right"] and et.top.prev_button.disabled and et.top.next_button.disabled,
		"목록: 키패드 ←→ 흐림, 띠의 대원 단추도 받지 않음")
	await kit.tap(kit.center_of(et.top.next_button))
	check_eq([pm.member, et.list_open], [1, true], "목록: 띠 → 단추 = 아무 일 없음")
	# 「E」 줄에서 「선택」 = 바꾸지 않고 닫기(규칙을 부르지 않는다: 상태·저장·안내 그대로).
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.tap(kit.center_of(kp.buttons["ok"]))
	check_eq([et.list_open, et.cursor, kit.hash_now(), s.autosave_count, pm.notice], [false, 0, h, saves, ""], "「E」 줄 「선택」 → 닫힘만")
	# 낄 수 있는 줄: 키패드 ↓ + 「선택」 = 장착 → 자동 저장 → 목록 닫힘, 커서는 그 칸.
	await kit.press_key(KEY_ENTER)
	await kit.tap(kit.center_of(pm.dir_pad.buttons["down"]))
	check_eq(et.row_items[et.list_cursor], "equip.ion_saber", "키패드 ↓ → 이온 세이버")
	await kit.tap(kit.center_of(kp.buttons["ok"]))
	check_eq([m.equip[0], s.autosave_count, et.list_open, et.cursor], ["equip.ion_saber", saves + 1, false, 0], "「선택」 → 장착·자동 저장·닫힘·커서 칸 0")
	check(et.note_label.text.contains(pm.item_name("equip.ion_saber")), "장착 안내는 띠 오른쪽: %s" % et.note_label.text)
	# 못 끼는 줄 누르기 = 이유 안내(띠 오른쪽), 목록 그대로.
	await kit.tap(kit.center_of(et.slot_rows[0]))
	check_eq(et.row_items, ["equip.ion_saber", "equip.twin_edge", NANO_ROD, ""], "칸 줄 누르기 → 목록, 새 장비가 「E」")
	await kit.tap(kit.center_of(et.rows[2]))
	check_eq([et.list_open, et.list_cursor, m.equip[0], pm.notice], [true, 2, "equip.ion_saber", pm.reason_text("class")], "못 끼는 줄 → 이유만, 목록 그대로")
	check(et.note_label.is_visible_in_tree() and et.note_label.text == pm.reason_text("class"), "이유는 띠 오른쪽")
	check(_rect(et.note_label).position.y >= MemberHeader.INFO_Y and _rect(et.note_label).end.x <= pm.size.x, "안내는 띠 안")
	# 「빼기」(맨 끝): ↓ 끝에서 멈춘다, 누르면 빼기.
	await kit.press_key(KEY_DOWN)
	n = pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq([et.list_cursor, pm.accepted_inputs], [3, n], "마지막 줄 ↓ = 아무 일 없음(돌지 않음)")
	await kit.tap(kit.center_of(et.rows[3]))
	check_eq([m.equip[0], s.autosave_count, et.list_open], ["", saves + 2, false], "「빼기」 → 칸이 빈다·자동 저장·닫힘")
	# 대원이 바뀌면 목록을 닫는다(member 입력). 「취소」 = 목록만 닫기, 한 번 더 = 뿌리.
	await kit.press_key(KEY_ENTER)
	check(et.list_open, "준비: 목록")
	check(pm.handle("member", 2), "member 입력은 받는다")
	check_eq([pm.member, et.list_open], [2, false], "대원 바뀜 → 목록 닫힘")
	await kit.frames(1)
	await kit.press_key(KEY_ENTER)
	check(et.list_open, "준비: 목록 다시 열림")
	await kit.tap(kit.center_of(kp.buttons["back"]))
	check_eq([pm.page, et.list_open], ["sub", false], "키패드 「취소」 → 목록만 닫힘")
	await kit.press_key(KEY_ESCAPE)
	check_eq([pm.page, pm.camp_cursor], ["root", EQUIP], "Esc → 캠프 뿌리(커서 장비)")


## 왼쪽 열이 그린 것(그리기 기록, 07 §9.9 E2-c): 표지 테두리는 칸 고르기 = 커서 칸, 목록 = 연 칸. 목록 커서 줄로 바꾼 뒤 값은
## 바뀐 칸만 ↑·↓ 와 새 값(오름·내림 실제 후보), 「E」 줄·못 끼는 줄은 지금 값만.
func _check_sheet_drawn(et: PartyEquipTab, now: Dictionary, then: Dictionary, tag: String) -> int:
	var arrows := 0
	var cells := []
	for i in PartyStatusTab.STAT_ROWS.size():
		var k: String = PartyStatusTab.STAT_ROWS[i]
		cells.append([k, SheetParts.stat_boxes(et.stat_rect(i))["value"], int(now["stats"][k]), int(then["stats"][k])])
	for gi in BattleLimits.GEAR.size():
		var g: String = BattleLimits.GEAR[gi]
		var row := 0 if g in ["atk", "def"] else 1
		var col := 0 if g in ["atk", "matk"] else 1
		cells.append([g, SheetParts.gear_cells(et.gear_row_rect(row))[col]["value"], int(now["gear"][g]), int(then["gear"][g])])
	for c in cells:
		var box: Rect2 = c[1]
		var icons := _drawn_icons_in(et.left, box)
		var texts := _drawn_text_in(et.left, box)
		var want := [] if c[2] == c[3] else (["up"] if c[3] > c[2] else ["down"])
		check_eq(icons, want, "%s %s: 화살표 %d → %d" % [tag, c[0], c[2], c[3]])
		check_eq(texts, [str(c[3])], "%s %s: 값 칸 글 = 바꾸면 값만" % [tag, c[0]])
		if not want.is_empty():
			arrows += 1
			var ar := SheetParts.arrow_rect(box)
			check(_drawn_entries(et.left, "icon").any(func(e: Dictionary) -> bool: return e["rect"] == ar), "%s %s: 화살표는 값 칸 왼쪽" % [tag, c[0]])
	return arrows


func _check_mark(et: PartyEquipTab, slot: int, tag: String) -> void:
	var outs := _drawn_entries(et.left, "outline")
	check_eq(outs.map(func(e: Dictionary) -> Array: return [e["rect"], e["color"]]), [[et.equip_rect(slot).grow(2.0), SheetParts.MARK]],
		"%s: 표지(노란 테두리)는 장비 줄 %d 하나" % [tag, slot])


func test_equip_sheet_draws_after_values_arrows_and_the_mark() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	var defs := s.state.defs
	var m := s.state.party.members[1]
	var now := GrowthRules.profile(defs, 1, m)
	await kit.frames(1)
	_check_mark(et, 0, "칸 고르기 칸 0")
	check_eq(_check_sheet_drawn(et, now, now, "칸 고르기"), 0, "칸 고르기: 화살표 없음")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	_check_mark(et, 2, "칸 고르기 칸 2")
	# 칸 2(손): 「E」 그립 장갑 → 서보 건틀릿(힘 +3, 오름).
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	check_eq(et.row_items[et.list_cursor], m.equip[2], "준비: 커서는 「E」 줄")
	_check_mark(et, 2, "목록 칸 2(「E」 줄)")
	check_eq(_check_sheet_drawn(et, now, now, "「E」 줄"), 0, "「E」 줄: 지금 값만")
	var j := et.row_items.find(SERVO)
	for k in j:
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	var up := et.profile_if(SERVO)
	check(up["stats"]["STR"] > now["stats"]["STR"], "준비: 서보 건틀릿은 힘이 오른다")
	check(_check_sheet_drawn(et, now, up, "서보 건틀릿") >= 1, "서보 건틀릿: 화살표가 있다")
	_check_mark(et, 2, "목록 칸 2(서보)")
	check_eq(_drawn_text_in(et.left, et.equip_rect(2)), [pm.item_name(m.equip[2])], "장비 줄은 지금 장비 그대로(표시만)")
	await kit.press_key(KEY_ESCAPE)
	# 칸 1(몸): 메시 아머(민첩 -2, 내림).
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	for k in et.row_items.find(MESH):
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	var down := et.profile_if(MESH)
	check(down["stats"]["AGI"] < now["stats"]["AGI"] and et.row_block[et.list_cursor].is_empty(), "준비: 메시 아머는 민첩이 준다(낄 수 있음)")
	check(_check_sheet_drawn(et, now, down, "메시 아머") >= 1, "메시 아머: 내림 화살표")
	_check_mark(et, 1, "목록 칸 1")
	await kit.press_key(KEY_ESCAPE)
	# 칸 0(무기): 이온 세이버(공격 오름), 못 끼는 나노 로드(지금 값만), 「빼기」(공격 내림).
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check(_check_sheet_drawn(et, now, et.profile_if("equip.ion_saber"), "이온 세이버") >= 1, "이온 세이버: 화살표")
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check(not et.row_block[et.list_cursor].is_empty(), "준비: 못 끼는 나노 로드")
	check_eq(_check_sheet_drawn(et, now, now, "못 끼는 줄"), 0, "못 끼는 줄: 지금 값만")
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	var bare := et.profile_if("")
	check(bare["gear"]["atk"] < now["gear"]["atk"], "준비: 빼면 공격이 준다")
	check(_check_sheet_drawn(et, now, bare, "빼기") >= 1, "빼기: 내림 화살표")
	_check_mark(et, 0, "목록 칸 0")


## 설명 상자(부품 I): 머리 = 이름 + 종류 아이콘 + 파티 직업 표(shop.badge.*, 낄 수 있으면 켜짐), 몸 = 값·받는 배율(못 끼면 이유),
## 「빼기」 = 하는 일 한 줄, 빈 칸 = 머리 「비어 있음」만.
func _check_equip_desc(et: PartyEquipTab, title: String, icon: String, lines: Array, table: Array, tag: String) -> void:
	await kit.frames(1)
	check_eq([et.desc.title, et.desc.icon, Array(et.desc.lines), et.desc.table], [title, icon, lines, table], tag + ": 설명 상자 내용")
	var r := Rect2(Vector2.ZERO, et.desc.size)
	var cells := ListParts.table_rects(r, table.size())
	var fills := _drawn_entries(et.desc, "fill").filter(func(e: Dictionary) -> bool: return cells.has(e["rect"]))
	check_eq(fills.map(func(e: Dictionary) -> Color: return e["color"]), table.map(func(t: Array) -> Color: return ListParts.TABLE_ON if t[1] else ListParts.TABLE_OFF),
		tag + ": 직업 표 칸 켜짐·꺼짐(그린 색)")
	var texts := _drawn_entries(et.desc, "text").map(func(e: Dictionary) -> String: return e["text"])
	for t in table:
		check(texts.has(t[0]), "%s: 직업 표 글 %s" % [tag, t[0]])
	check_eq(_drawn_icons_in(et.desc, ListParts.head_rect(r)), [icon] if not icon.is_empty() else [], tag + ": 머리 아이콘")
	_check_drawn_text(et.desc, tag)


func test_equip_description_box_shows_items_class_table_and_rows() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	var t := s.texts
	var m := s.state.party.members[1]
	var classes := ["holo_knight", "blade_duelist", "nano_medic", "glyph_wizard"]
	var table_of := func(id: String) -> Array:
		var e := s.state.defs.battle.equip(id)
		return classes.map(func(k: String) -> Array: return [t.t("shop.badge." + k), e.fits(s.state.defs.battle.classes["class." + k])])
	check_eq(et.class_table("equip.ion_saber").map(func(x: Array) -> String: return x[0]), ["홀", "블", "나", "글"], "직업 표 = 파티 직업 차례(겹치면 한 번)")
	var lines_of := func(id: String) -> Array:
		return [PartyNames.values_text(s.state, t, id), PartyNames.received_text(s.state, t, id)].filter(func(x: String) -> bool: return not x.is_empty())
	await _check_equip_desc(et, pm.item_name(m.equip[0]), "kind_sword", lines_of.call(m.equip[0]), table_of.call(m.equip[0]), "칸 0 트윈 엣지")
	var nano: Array = table_of.call(NANO_ROD)
	check(nano.any(func(x: Array) -> bool: return x[1]) and nano.any(func(x: Array) -> bool: return not x[1]), "준비: 나노 로드 표에 켜짐·꺼짐이 섞인다")
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await _check_equip_desc(et, t.t("party.slot.empty"), "", [], [], "빈 칸 3")
	for k in 3:
		await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_DOWN)
	await _check_equip_desc(et, pm.item_name("equip.ion_saber"), "kind_sword", lines_of.call("equip.ion_saber"), table_of.call("equip.ion_saber"), "낄 수 있는 줄")
	await kit.press_key(KEY_DOWN)
	await _check_equip_desc(et, pm.item_name(NANO_ROD), "kind_staff", lines_of.call(NANO_ROD) + [pm.reason_text("class")], nano, "못 끼는 줄")
	await kit.press_key(KEY_DOWN)
	await _check_equip_desc(et, t.t("party.unequip"), "", [t.t("party.equip.unequip_desc")], [], "빼기 줄")
	# 빈 칸의 「빼기」는 막힌 줄: 하는 일과 이유.
	await kit.press_key(KEY_ESCAPE)
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	var last := et.row_items.size() - 1
	for k in last:
		await kit.press_key(KEY_DOWN)
	check_eq([et.row_items[et.list_cursor], et.row_block[et.list_cursor]], ["", "unchanged"], "준비: 빈 칸 「빼기」")
	await _check_equip_desc(et, t.t("party.unequip"), "", [t.t("party.equip.unequip_desc"), pm.reason_text("unchanged")], [], "빈 칸 빼기")


## 가장 긴 실제 내용이 1280 의 설명 상자(486 폭)에 든다: 모든 장비의 이름(직업 표 넷과 함께 머리에)과 값·받는 배율·가장 긴 이유 줄.
func test_equip_longest_description_content_fits() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	await _window(WINDOWS[0])
	var r := Rect2(Vector2.ZERO, et.desc.size)
	check_eq(r.size.x, 486.0, "준비: 1280 의 설명 상자 폭")
	var room := ListParts.line_room(r)
	var reasons := ["slot_kind", "class", "kind_limit", "bag_full", "unchanged", "not_in_bag"].map(func(c: String) -> String: return pm.reason_text(c))
	var widest := ""
	for id in s.state.defs.battle.equipment_ids:
		check(SheetParts.text_width(et.desc, pm.item_name(id), ListParts.HEAD_FS) <= ListParts.head_room(r, 4), "%s: 이름이 직업 표와 함께 머리에 든다" % id)
		var lines := et.item_lines(id)
		check(lines.size() + 1 <= ListParts.DESC_LINES, "%s: 이유까지 넷 이하" % id)
		for l in lines + reasons + [s.texts.t("party.equip.unequip_desc")]:
			var fs := ListParts.line_fs(et.desc, l, room)
			check(fs >= ListParts.DESC_FS_MIN and SheetParts.text_width(et.desc, l, fs) <= room, "%s: 「%s」 %dpx 가 %.0f 안" % [id, l, fs, room])
			if SheetParts.text_width(et.desc, l, ListParts.DESC_FS) > SheetParts.text_width(et.desc, widest, ListParts.DESC_FS):
				widest = l
	# 실제로 그려 본다: 가장 긴 이름 + 직업 표 + 가장 긴 줄.
	var longest := ""
	for id in s.state.defs.battle.equipment_ids:
		if SheetParts.text_width(et.desc, pm.item_name(id), 20) > SheetParts.text_width(et.desc, pm.item_name(longest) if not longest.is_empty() else "", 20):
			longest = id
	et.desc.show_desc(pm.item_name(longest), SheetParts.kind_icon(s.state.defs, longest), [widest, widest, widest] as Array[String], et.class_table(longest))
	await kit.frames(1)
	check(_check_drawn_text(et.desc, "가장 긴 설명") >= 8, "가장 긴 설명 글을 그렸다")


## 줄 맞춤(E2-b 검토 L1): 432 폭 목록 창(줄 362)에서 모든 실제 장비 이름이 「E」 표와 가장 큰 개수(「99개」)와 함께 그린 크기(20px)에 든다.
func test_equip_rows_fit_with_the_e_mark_and_the_largest_count() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	var row := et.rows[0]
	check_eq(_rect(et.window).size.x, 432.0, "준비: 목록 창 432 폭")
	var r := Rect2(Vector2.ZERO, row.size)
	var count := s.texts.t("party.count", {"n": BattleLimits.BAG_MAX})
	for id in s.state.defs.battle.equipment_ids:
		var name := pm.item_name(id)
		check(SheetParts.text_width(row, name, ListParts.ROW_FS) <= ListParts.name_room(row, r, count, true),
			"%s: 「%s」 %.0f ≤ 「E」·「%s」 옆 자리 %.0f" % [id, name, SheetParts.text_width(row, name, ListParts.ROW_FS), count, ListParts.name_room(row, r, count, true)])
	# 실제로 그려 본다: 가장 긴 이름 + 「E」 + 「99개」.
	row.show_row(pm.item_name("equip.training_sword"), count, "", false)
	row.equipped = true
	await kit.frames(1)
	check(row.clipped_parts().is_empty(), "가장 긴 줄이 잘리지 않는다 %s" % str(row.clipped_parts()))
	check(_check_drawn_text(row, "가장 긴 줄") == 3, "이름·개수·「E」를 그렸다")
	# 「E」 와 개수를 함께 그리면 개수는 「E」 왼쪽, 이름은 개수 왼쪽에서 끝난다(겹치지 않는다).
	var parts := _row_parts(row)
	check(parts["count_end"] <= (parts["mark"] as Rect2).position.x and parts["name_end"] <= parts["count_x"],
		"이름 끝 %.0f ≤ 개수 %.0f~%.0f ≤ 「E」 %.0f" % [parts["name_end"], parts["count_x"], parts["count_end"], (parts["mark"] as Rect2).position.x])


## 넘치는 장비 목록(E2-c 검토 L1): 가방에 장비를 모두 넣어 빈 칸 3 목록이 줄 열넷 이상 → 높은 화면에서 마지막 줄에 커서를 두고
## 1280×960 → 1280×720 이면 커서 줄이 다 보인다. 손으로 내려 끝 커서를 가리면 끝 키 한 번(입력 하나)이 되돌리고, 보이는 끝에서 한 번 더는
## 아무 일 없다. 줄 위 끌기는 내리기만 한다(장착·커서 그대로).
func test_equip_overflowing_list_keeps_the_cursor_visible_on_resize_ends_and_drags() -> void:
	var s := await _open()
	var pm := s.party_menu
	var et := pm.equip_tab
	for id in s.state.defs.battle.equipment_ids:
		GrowthRules.supply(s.state, id, 1)
	await _window(Vector2(1280, 960))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	var last := et.row_items.size() - 1
	var tall_rows := ListParts.rows_for(_rect(et.window).size.y)
	check(et.list_open and et.cursor == 3 and last >= 2 * tall_rows - 3, "준비: 빈 칸 3 목록 %d 줄이 보이는 %d 줄보다 훨씬 많다" % [last + 1, tall_rows])
	for k in last:
		await kit.press_key(KEY_DOWN)
	check(et.list_cursor == last and et.shown(last) and et.list.scroll > 0.0, "높은 화면: 마지막 줄 커서가 보인다(내림 %.0f)" % et.list.scroll)
	var tall_scroll := et.list.scroll
	await _window(WINDOWS[0])
	await kit.frames(2)
	check_eq(ListParts.rows_for(_rect(et.window).size.y), 5, "준비: 낮은 화면 다섯 줄")
	check(et.list_cursor == last and et.shown(last), "1280×960 → 1280×720: 커서 줄이 다 보인다(내림 %.0f → %.0f)" % [tall_scroll, et.list.scroll])
	check_eq(et.list.scroll, et.list.max_scroll(), "끝 줄이면 끝까지 내린다")
	# 손으로 맨 위로 올려 끝 커서를 가린다 → ↓ 한 번이 되돌리고(입력 하나, 커서 그대로), 보이는 끝의 ↓ 는 아무 일 없다.
	et.list.scroll_to(0.0)
	await kit.frames(1)
	check(not et.shown(last), "준비: 커서 줄이 가려졌다")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq([et.list_cursor, et.shown(last), pm.accepted_inputs], [last, true, n + 1], "가려진 끝 커서: ↓ 한 번 = 되돌림(입력 하나)")
	await kit.press_key(KEY_DOWN)
	check_eq([et.list_cursor, pm.accepted_inputs], [last, n + 1], "보이는 끝: ↓ 는 아무 일 없음")
	# 첫 줄도 같다: 맨 위로 가서 손으로 끝까지 내려 가리면 ↑ 한 번이 되돌린다.
	for k in last:
		await kit.press_key(KEY_UP)
	check(et.list_cursor == 0 and et.shown(0), "준비: 첫 줄 커서")
	et.list.scroll_to(et.list.max_scroll())
	await kit.frames(1)
	n = pm.accepted_inputs
	await kit.press_key(KEY_UP)
	check_eq([et.list_cursor, et.shown(0), pm.accepted_inputs], [0, true, n + 1], "가려진 첫 줄 커서: ↑ 한 번 = 되돌림")
	await kit.press_key(KEY_UP)
	check_eq(pm.accepted_inputs, n + 1, "보이는 첫 줄: ↑ 는 아무 일 없음")
	# 줄 위 끌기: 내리기만(장착·저장·커서 그대로).
	var h := kit.hash_now()
	var saves := s.autosave_count
	var from := kit.center_of(et.rows[2])
	var to := from - Vector2(0, 150)
	kit.touch(FINGER, from, true)
	await kit.frames(1)
	kit.drag(FINGER, from, to)
	await kit.frames(1)
	kit.touch(FINGER, to, false)
	await kit.frames(2)
	check(et.list.scroll > 0.0, "끌기 → 내림 %.0f" % et.list.scroll)
	check_eq([et.list_open, et.list_cursor, kit.hash_now(), s.autosave_count], [true, 0, h, saves], "끌기는 장착·커서를 바꾸지 않는다")


## 줄 하나의 그린 자리(그리기 기록): mark(「E」 칸, 없으면 빈 Rect2), body, name_x·name_end(이름 글), count_x·count_end(개수 글, 없으면 -1).
static func _row_parts(row: ListButton) -> Dictionary:
	var body: Rect2 = ListParts.row_boxes(Rect2(Vector2.ZERO, row.size))["body"]
	var out := {"mark": Rect2(), "body": body, "name_x": -1.0, "name_end": -1.0, "count_x": -1.0, "count_end": -1.0}
	for e in SheetParts.record(row):
		if e["kind"] == "fill" and e["color"] == ListParts.EQUIP_MARK:
			out["mark"] = e["rect"]
		elif e["kind"] == "text" and e["text"] == row.text:
			out["name_x"] = (e["rect"] as Rect2).position.x
			out["name_end"] = out["name_x"] + SheetParts.text_width(row, row.text, int(e["fs"]))
		elif e["kind"] == "text" and not row.right.is_empty() and e["text"] == row.right:
			out["count_x"] = (e["rect"] as Rect2).position.x
			out["count_end"] = out["count_x"] + SheetParts.text_width(row, row.right, int(e["fs"]))
	return out


## 「E」 표는 원작 I HD 장비(yt_eo1hd_04)처럼 줄 오른쪽 끝(몸 오른쪽에서 8 안, 세로 가운데)이고, 이름은 「E」 가 있든 없든 같은 x 에서 시작한다.
func test_equip_e_mark_sits_at_the_right_end_and_names_align() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	check(et.rows[0].equipped and not et.rows[1].equipped, "준비: Row_0 이 「E」 줄")
	var e := _row_parts(et.rows[0])
	var mk: Rect2 = e["mark"]
	var body: Rect2 = e["body"]
	check(mk.has_area(), "「E」 칸을 그렸다")
	check(mk.end.x <= body.end.x and body.end.x - mk.end.x <= 8.5, "「E」 칸 오른쪽 끝 %.0f 은 몸 오른쪽 %.0f 에서 8 안" % [mk.end.x, body.end.x])
	check(absf(mk.get_center().y - body.get_center().y) <= 0.5, "「E」 칸은 세로 가운데")
	check(mk.position.x > e["name_end"], "「E」 칸 %.0f 은 그린 이름 끝 %.0f 오른쪽" % [mk.position.x, e["name_end"]])
	for j in range(1, et.row_items.size()):
		var o := _row_parts(et.rows[j])
		check_eq(o["name_x"], e["name_x"], "%s 이름 x = 「E」 줄 이름 x" % et.rows[j].name)
	check_eq(e["name_x"], body.position.x + ListParts.TEXT_PAD, "이름은 몸 왼쪽 + TEXT_PAD")


## 노랑(07 §9.9 E2-c): 채움은 지금 단계의 커서 줄 하나. 못 끼는 줄에 커서면 흐린 커서 모양(흐린 몸 + 노란 테, 채움 0). 왼쪽 표지는 테두리.
## 그린 글은 모두 그 밑 채움과 4.5:1 이상.
func _equip_yellow(et: PartyEquipTab) -> Array:
	var out := []
	var cs: Array = [et.left, et.window, et.desc]
	for b in et.slot_rows + et.rows:
		if b.is_visible_in_tree():
			cs.append(b)
	for ci in cs:
		for e in SheetParts.record(ci):
			if (e["kind"] == "fill" or e["kind"] == "poly") and _is_yellow(e["color"]):
				var in_bar := false
				if ci == et.left:
					for i in 6:
						if SheetParts.stat_boxes(et.stat_rect(i))["bar"].encloses(e["rect"]):
							in_bar = true
				if not in_bar:
					out.append(str((ci as Node).name))
	return out


func _check_equip_drawn(et: PartyEquipTab, tag: String) -> void:
	await kit.frames(1)
	for ci in [et.left, et.desc]:
		_check_drawn_text(ci, tag)
	for b in et.slot_rows + et.rows:
		if b.is_visible_in_tree():
			_check_drawn_text(b, tag)


func test_equip_yellow_is_one_fill_or_the_dimmed_cursor_look() -> void:
	var s := await _equip_open()
	var pm := s.party_menu
	var et := pm.equip_tab
	await _check_equip_drawn(et, "칸 고르기")
	check_eq(_equip_yellow(et), ["Slot_0"], "칸 고르기: 노랑 채움은 커서 칸 줄 하나")
	await kit.press_key(KEY_ENTER)
	await _check_equip_drawn(et, "목록 「E」")
	check_eq(_equip_yellow(et), ["Row_0"], "목록: 노랑 채움은 커서 줄(「E」) 하나")
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_DOWN)
	await _check_equip_drawn(et, "못 끼는 줄")
	var row := et.rows[et.list_cursor]
	check(row.dimmed and row.selected, "준비: 못 끼는 줄에 커서")
	check_eq(_equip_yellow(et), [], "못 끼는 줄: 노랑 채움 0")
	var rec := SheetParts.record(row)
	check(rec.any(func(e: Dictionary) -> bool: return e["kind"] == "fill" and e["color"] == ListParts.ROW_DIM), "흐린 커서 모양: 흐린 몸")
	check(rec.any(func(e: Dictionary) -> bool: return e["kind"] == "outline" and _is_yellow(e["color"])), "흐린 커서 모양: 노란 테")
	await kit.press_key(KEY_DOWN)
	await _check_equip_drawn(et, "빼기")
	check_eq(_equip_yellow(et), ["Row_3"], "「빼기」: 노랑 채움 하나")
	# 높은 화면에서도 같다.
	await _window(Vector2(1280, 960))
	await _check_equip_drawn(et, "1280×960 빼기")
	check_eq(_equip_yellow(et), ["Row_3"], "1280×960: 노랑 채움 하나")
	await _window(WINDOWS[0])


# ---- 소지품(07 §9.9 E2-b, research 08 §4.1: 원작 III HD 소지품 yt_eo3hd_05) ----

## 소지품 화면 준비: 가방에 장비 모두(bag 개씩)와 소재(mat 개씩, ids 가 비면 정의의 소재 모두).
static func _fill_bag(s: DungeonScreen, bag: int, mat: int, mat_ids: Array = []) -> void:
	for id in s.state.defs.battle.equipment_ids:
		s.state.gear_bag[id] = bag
	for id in (mat_ids if not mat_ids.is_empty() else Array(s.state.defs.battle.material_ids)):
		s.state.materials[id] = mat


## 일반 실행(디버그 주소 아님, 네이티브 디버그 끔).
func _open_plain() -> DungeonScreen:
	timeout_sec = 90.0
	kit = Kit.new(tree)
	var s := await kit.open("native", 7, "")
	s.native_debug = false
	return s


## 소지품 층 표(1280×720 기준, 넓은 화면은 왼쪽 앵커, 높은 화면은 목록 창이 줄 단위로 늘고 설명 상자·키패드는 아래):
## 띠 x 176~W−16 · y 70~108, 목록 창 x 135~642 · y 178~(설명 상자 위 − 62 안에서 줄 단위), 알약 x 735~975 · y 278~342(디버그),
## 설명 상자 x 288~990 · y H−190~H−8, 방향 십자 (8, H−209), 세로 「취소」「선택」 (W−118, H−172).
func _check_items_layers(pm: PartyMenu, size: Vector2, debug: bool, tag: String) -> void:
	var it := pm.items_tab
	var want_rows := 4 if size.y < 960.0 else 7
	var lw := _rect(it.window)
	check_eq(lw, Rect2(135, 178, 507, ListParts.list_height(want_rows)), tag + ": 목록 창 x 135~642, 줄 %d 높이" % want_rows)
	check_eq(it.list.size.y, ListWindow.content_height(want_rows), tag + ": 줄 %d 개가 꼭 다 보인다" % want_rows)
	var desc := _rect(it.desc)
	check_eq(desc, Rect2(288, size.y - 190, 702, 182), tag + ": 설명 상자 x 288~990 · 아래 끝 H − 8")
	check(desc.position.y - lw.end.y >= 62.0 - 0.5, "%s: 목록 창 아래 끝 %.0f 은 설명 상자 위 %.0f 에서 62 이상 떨어진다" % [tag, lw.end.y, desc.position.y])
	check(desc.position.y - lw.end.y < 62.0 + ListParts.ROW_H + ListParts.ROW_GAP, tag + ": 한 줄 더 들어갈 자리는 남기지 않는다(줄 단위로 늘어난다)")
	check(lw.encloses(Rect2(it.list.get_global_position(), it.list.size)), tag + ": 줄 자리는 목록 창 안")
	var sb := ListParts.scroll_rect(Rect2(Vector2.ZERO, lw.size))
	sb.position += lw.position
	check(lw.encloses(sb) and sb.position.x >= it.list.get_global_position().x + it.list.size.x, tag + ": 스크롤 막대는 창 안 오른쪽, 줄 자리 오른쪽")
	check_eq(it.supply_button.is_visible_in_tree(), debug, tag + ": 「임시 보급」은 디버그만")
	if debug:
		check_eq(_rect(it.supply_button), Rect2(735, 278, 240, 64), tag + ": 알약 x 735~975 · y 278~342")
	check(pm.notice_line.is_visible_in_tree(), tag + ": 띠(알림 줄 자리)가 보인다")
	check_eq(_rect(pm.notice_line), Rect2(176, 70, size.x - 16 - 176, 38), tag + ": 띠 x 176~W−16 · y 70~108")
	check([pm.camp_plate, pm.ribbon, pm.money_plate].all(func(c: Control) -> bool: return c.is_visible_in_tree()), tag + ": 뿌리의 맨 위 띠(걸음·장소·소지금)")
	check_eq(_rect(pm.dir_pad), Rect2(Vector2(8, size.y - 209), VirtualPad.dirs_size()), tag + ": 방향 십자 (8, H − 209)")
	check_eq(_rect(pm.key_pad_stacked), Rect2(Vector2(size.x - 118, size.y - 172), VirtualPad.keys_size(true)), tag + ": 세로 「취소」「선택」 (W − 118, H − 172)")
	var parts := {"plate": _rect(pm.camp_plate), "ribbon": _rect(pm.ribbon), "money": _rect(pm.money_plate), "strip": _rect(pm.notice_line),
		"list": lw, "desc": desc, "dir": _rect(pm.dir_pad), "keys": _rect(pm.key_pad_stacked)}
	if debug:
		parts["pill"] = _rect(it.supply_button)
	var keys := parts.keys()
	for i in keys.size():
		check(Rect2(Vector2.ZERO, size).encloses(parts[keys[i]]), "%s: %s %s 화면 안" % [tag, keys[i], str(parts[keys[i]])])
		for j in range(i + 1, keys.size()):
			var a: Rect2 = parts[keys[i]]
			check(not a.intersects(parts[keys[j]]), "%s: %s %s 와 %s %s 가 겹친다" % [tag, keys[i], str(a), keys[j], str(parts[keys[j]])])
	check(it.window.get_index() < it.supply_button.get_index() and it.supply_button.get_index() < it.desc.get_index(),
		tag + ": 트리 차례 목록 창 → 알약 → 설명 상자")
	check(pm.notice_line.get_index() < it.get_index() and it.get_index() < pm.dir_pad.get_index(), tag + ": 띠 → 소지품 → 키패드")
	check(it.find_children("*", "CharPanel", true, false).is_empty() and it.find_children("*", "ShopFrame", true, false).is_empty(),
		tag + ": 대원 판·상점 틀 없음")
	for d in [it.window, it.desc]:
		check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
	for ci in _items_canvases(it):
		_check_drawn_text(ci, tag)
	_check_targets(pm, size, tag)


## 소지품이 그린 캔버스(목록 창·보이는 줄·알약·설명 상자).
static func _items_canvases(it: PartyItemsTab) -> Array:
	var out: Array = [it.window, it.desc]
	if it.supply_button.is_visible_in_tree():
		out.append(it.supply_button)
	for r in it.rows:
		if r.is_visible_in_tree():
			out.append(r)
	return out


## 노랑 채움(그린 기록의 채움·다각형, 테마로 그린 보급 단추는 그 모양의 채움 색): 캔버스 이름 목록.
static func _items_yellow(it: PartyItemsTab) -> Array:
	var out := []
	for ci in _items_canvases(it):
		for e in SheetParts.record(ci):
			if (e["kind"] == "fill" or e["kind"] == "poly") and _is_yellow(e["color"]):
				out.append(str((ci as Node).name))
	for b in it.plus_buttons + it.exp_buttons + it.next_buttons:
		if b.is_visible_in_tree():
			var lk := UiTheme.look(b.theme_state())
			if lk["fill"] and (_is_yellow(lk["top"]) or _is_yellow(lk["bottom"])):
				out.append(str(b.name))
	return out


## 그린 글마다: 글 자리(왼쪽·가운데·오른쪽)의 밑에 그 글보다 먼저 그린 마지막 채움과 4.5:1 이상, 그린 크기에서 그린 폭 안에 든다.
func _check_drawn_text(ci: Control, tag: String) -> int:
	var rec := SheetParts.record(ci)
	var n := 0
	for i in rec.size():
		var e: Dictionary = rec[i]
		if e["kind"] != "text" or str(e["text"]).is_empty():
			continue
		n += 1
		var r: Rect2 = e["rect"]
		var fs := int(e["fs"])
		check(SheetParts.text_width(ci, e["text"], fs) <= r.size.x + 0.5, "%s %s: 「%s」 %dpx 폭 %.0f ≤ %.0f" % [tag, ci.name, e["text"], fs,
			SheetParts.text_width(ci, e["text"], fs), r.size.x])
		for x in [r.position.x + 1.0, r.get_center().x, r.end.x - 1.0]:
			var p := Vector2(x, r.position.y + fs * 0.6)
			var under: Variant = null
			for j in range(i - 1, -1, -1):
				var f: Dictionary = rec[j]
				if (f["kind"] == "fill" or f["kind"] == "poly") and (f["rect"] as Rect2).has_point(p):
					under = f["color"]
					break
			check(under != null, "%s %s: 「%s」 밑에 그린 채움이 있다(%s)" % [tag, ci.name, e["text"], str(p)])
			if under != null:
				var c := contrast(e["color"], under)
				check(c >= 4.5, "%s %s: 「%s」 %s on %s = %.2f ≥ 4.5" % [tag, ci.name, e["text"], (e["color"] as Color).to_html(false),
					(under as Color).to_html(false), c])
	return n


func test_items_screen_follows_the_reference_table() -> void:
	var s := await _open()
	var pm := s.party_menu
	_fill_bag(s, 1, 2)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	check_eq([pm.page, pm.tab], ["sub", 3], "준비: 소지품(대원 고르기 없음)")
	var first := {}
	for px in WINDOWS + [Vector2(1280, 960), WINDOWS[0]]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s) 소지품" % [str(px), str(size)]
		_check_items_layers(pm, size, true, tag)
		var snap := [_rect(it.window), _rect(it.supply_button), _rect(it.desc)]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 띠: 「소지품   장비 n · 소재 n」(가진 종류 수), 알림이 뜨면 알림이 대신하고 지나면 돌아온다. 스냅숏 strip 도 같다.
	var n_gear := s.state.defs.battle.equipment_ids.size()
	var n_mat := s.state.defs.battle.material_ids.size()
	var caption := s.texts.t("party.items.strip", {"gear": n_gear, "materials": n_mat})
	check_eq([pm.notice_line_text(), s.debug_snapshot()["party_menu"]["strip"]], [caption, caption], "띠 글 = 종류 수")
	s.state.gear_bag[s.state.defs.battle.equipment_ids[0]] = 0
	s.state.materials[s.state.defs.battle.material_ids[0]] = 0
	pm.refresh_view()
	caption = s.texts.t("party.items.strip", {"gear": n_gear - 1, "materials": n_mat - 1})
	check_eq(s.debug_snapshot()["party_menu"]["strip"], caption, "개수 0 은 세지 않는다")
	pm.show_notice("시험 안내 B")
	await kit.frames(1)
	check_eq(s.debug_snapshot()["party_menu"]["strip"], "시험 안내 B", "알림이 띠를 대신한다")
	pm._clear_notice()
	await kit.frames(1)
	check_eq(s.debug_snapshot()["party_menu"]["strip"], caption, "알림이 지나면 띠 글이 돌아온다")
	# 대원이 없다: ←→ 흐림, Q·E·member 는 아무 일 없음.
	var pad := pm.pad_state()
	check(not pad["left"] and not pad["right"], "←→ 흐림")
	var mb := pm.member
	for k in [KEY_Q, KEY_E, KEY_LEFT, KEY_RIGHT]:
		await kit.press_key(k)
	check(not pm.handle("member", 2) and not pm.handle("member_step", 1), "member·member_step 을 받지 않는다")
	check_eq([pm.member, pm.tab], [mb, 3], "Q·E·←→ 뒤에도 대원·화면 그대로")
	await kit.tap(kit.center_of(pm.key_pad_stacked.buttons["back"]))
	check_eq([pm.page, pm.camp_cursor], ["root", ITEMS], "키패드 「취소」 → 캠프 뿌리(커서 소지품)")


func test_items_rows_show_kind_icons_and_fit_with_the_largest_counts() -> void:
	var s := await _open()
	var pm := s.party_menu
	_fill_bag(s, BattleLimits.BAG_MAX, BattleLimits.MATERIAL_MAX)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	var defs := s.state.defs
	var want_ids: Array[String] = []
	want_ids.append_array(defs.battle.equipment_ids)
	var mats: Array = Array(defs.battle.material_ids)
	var by_id := mats.duplicate()
	by_id.sort()
	check(by_id != mats, "준비: 정의 자료 차례와 ID 차례가 다르다")
	for id in mats:
		want_ids.append(str(id))
	check_eq(it.row_items, want_ids, "장비(자료 차례) 다음 소재(정의 자료 차례, D28-b), 묶음 머리 줄 없음")
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var seen := 0
		for k in it.row_items.size():
			var r := it.rows[k]
			it.list.ensure_visible(r.position.y, r.position.y + r.size.y)
			await kit.frames(1)
			var id := it.row_items[k]
			var want_icon := SheetParts.kind_icon(defs, id) if defs.battle.equip(id) != null else "kind_material"
			var box: Rect2 = ListParts.row_boxes(Rect2(Vector2.ZERO, r.size))["icon"]
			var icons := _drawn_icons_in(r, box)
			check_eq(icons, [want_icon], "%s 줄 %d %s: 아이콘 칸에 종류 아이콘을 그렸다" % [tag, k, id])
			var texts := _drawn_entries(r, "text").map(func(e: Dictionary) -> String: return e["text"])
			check(texts.has(pm.item_name(id)) and texts.has(s.texts.t("party.count", {"n": it.item_count(id)})), "%s 줄 %d: 이름·개수 %s" % [tag, k, str(texts)])
			seen += _check_drawn_text(r, "%s 줄 %d" % [tag, k])
			check(r.clipped_parts().is_empty(), "%s 줄 %d 「%s」: 잘림 %s" % [tag, k, r.text, str(r.clipped_parts())])
		check(seen >= 2 * want_ids.size(), "%s: 글 %d 개를 봤다" % [tag, seen])
	# 보급 줄(디버그): 장비 줄은 「+1」 자리만큼 좁다. 가장 긴 이름 + 「99개」가 든다.
	await _window(WINDOWS[0])
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	check(it.supply_open, "준비: 보급 줄")
	await kit.frames(1)
	for r in it.rows:
		if r.is_visible_in_tree():
			_check_drawn_text(r, "보급 줄 " + r.text)
			check(r.clipped_parts().is_empty(), "보급 줄 「%s」 잘림 %s" % [r.text, str(r.clipped_parts())])


func test_items_empty_bag_shows_one_dim_none_row() -> void:
	var s := await _open_plain()
	var pm := s.party_menu
	s.state.gear_bag.clear()
	s.state.materials.clear()
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(1)
	var it := pm.items_tab
	check(not pm.debug, "준비: 일반 실행")
	_check_items_layers(pm, await _window(WINDOWS[0]), false, "빈 가방")
	var vis := it.rows.filter(func(r: ListButton) -> bool: return r.is_visible_in_tree())
	check_eq(vis.size(), 1, "줄 하나")
	var row: ListButton = vis[0]
	check_eq([row.text, row.dimmed, row.mouse_filter, it.row_items], [s.texts.t("party.items.none"), true, Control.MOUSE_FILTER_IGNORE, [] as Array[String]],
		"흐린 「없음」 줄(커서 칸 아님)")
	var fills := _drawn_entries(row, "fill").map(func(e: Dictionary) -> Color: return e["color"])
	check(fills.has(ListParts.ROW_DIM) and not fills.has(ListParts.ROW_BODY), "흐린 줄 색으로 그렸다: %s" % str(fills))
	_check_drawn_text(row, "없음 줄")
	check_eq([it.cursor, it.stops().size(), _items_yellow(it), _yellow(pm)], [-1, 0, [], []], "커서 없음, 노랑 채움 없음")
	var heads := _drawn_entries(it.desc, "text")
	check(heads.is_empty(), "설명 상자는 비었다: %s" % str(heads))
	var pad := pm.pad_state()
	check(not pad["up"] and not pad["down"] and not pad["ok"], "칸이 없어 ↑↓·선택 흐림")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.accepted_inputs, it.cursor], [n, -1], "↑↓·Enter 아무 일 없음")


func test_items_cursor_walks_scrolls_taps_and_drags() -> void:
	var s := await _open_plain()
	var pm := s.party_menu
	_fill_bag(s, 2, 3)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	var list := it.list
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		await kit.press_key(KEY_ESCAPE)
		await kit.press_key(KEY_1)
		await kit.frames(1)
		var last := it.row_items.size() - 1
		check(last > 8 and list.max_scroll() > 0.0, tag + ": 준비: 넘치는 가방(%d 줄)" % (last + 1))
		check_eq([it.cursor, list.scroll], [0, 0.0], tag + ": 들어오면 커서는 첫 줄, 맨 위")
		check(not pm.pad_state()["ok"], tag + ": 가방 줄에서 「선택」 흐림")
		for k in last:
			await kit.press_key(KEY_DOWN)
			await kit.frames(1)
			var r := it.rows[it.cursor]
			check(list.shows(Rect2(r.position, r.size)), "%s ↓ %d: 커서 줄이 다 보인다" % [tag, it.cursor])
			check_eq(_items_yellow(it), [str(r.name)], "%s ↓ %d: 노랑 채움은 커서 줄 하나" % [tag, it.cursor])
		check_eq([it.cursor, list.scroll], [last, list.max_scroll()], tag + ": 마지막 줄, 목록 끝")
		var n := pm.accepted_inputs
		await kit.press_key(KEY_DOWN)
		check_eq([it.cursor, pm.accepted_inputs, pm.pad_state()["down"]], [last, n, true], tag + ": 끝에서 ↓ → 아무 일 없음(키는 켜진 채)")
		for k in last:
			await kit.press_key(KEY_UP)
			var r := it.rows[it.cursor]
			check(list.shows(Rect2(r.position, r.size)), "%s ↑ %d: 커서 줄이 다 보인다" % [tag, it.cursor])
		check_eq([it.cursor, list.scroll], [0, 0.0], tag + ": ↑ 로 첫 줄, 맨 위")
		await kit.press_key(KEY_UP)
		check_eq(it.cursor, 0, tag + ": 첫 줄에서 ↑ → 그대로(돌지 않음)")
		# 누르기: 커서가 그 줄로(다른 일 없음). 끌기: 내리기만, 커서 그대로.
		var h := SaveCodec.state_hash(s.state)
		await kit.tap(kit.center_of(it.rows[2]))
		check_eq(it.cursor, 2, tag + ": 줄 누르기 → 커서가 그 줄로")
		check_eq(SaveCodec.state_hash(s.state), h, tag + ": 상태는 그대로")
		await kit.frames(1)
		check_eq(_items_yellow(it), [str(it.rows[2].name)], tag + ": 노랑은 누른 줄 하나")
		var from := kit.center_of(it.rows[1])
		var to := from - Vector2(0, 150)
		kit.touch(FINGER, from, true)
		await kit.frames(1)
		kit.drag(FINGER, from, to)
		await kit.frames(1)
		kit.touch(FINGER, to, false)
		await kit.frames(2)
		check(list.scroll > 0.0, tag + ": 줄 위 끌기 → 목록을 내린다(%.0f)" % list.scroll)
		check_eq(it.cursor, 2, tag + ": 끌기는 커서를 옮기지 않는다")
		list.scroll_to(0.0)


func test_items_description_box_shows_the_cursor_item() -> void:
	var s := await _open()
	var pm := s.party_menu
	var defs := s.state.defs
	_fill_bag(s, 1, 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(1)
	var it := pm.items_tab
	var t := s.texts
	# 장비: 머리 = 이름 + 종류 아이콘, 몸 = 값 · 받는 배율 · 낄 수 있는 직업 · 판매값(빈 줄 없음).
	var gear := "equip.aegis_plate"
	var k := it.row_items.find(gear)
	for j in k:
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check_eq(it.cursor_stop(), it.rows[k], "준비: 커서 = 이지스 플레이트")
	var lines := it.item_lines(gear)
	var want: Array[String] = [PartyNames.values_text(s.state, t, gear), PartyNames.received_text(s.state, t, gear)]
	check(not want[0].is_empty() and not want[1].is_empty(), "준비: 값과 받는 배율이 있는 장비 %s" % str(want))
	check(lines.slice(0, 2) == want and lines[2].begins_with(t.t("party.items.fits", {"classes": ""})) and
		lines[3] == t.t("party.items.sell", {"money": ShopRules.sell_price(defs, gear)}), "장비 설명 줄 %s" % str(lines))
	check_eq(lines[1], PartyStatusTab.received_lines(t, {"resist": _received_of(defs, gear, "resist"), "ailment_vuln": _received_of(defs, gear, "ailment_vuln"),
		"bind_vuln": _received_of(defs, gear, "bind_vuln")}).filter(func(l: String) -> bool: return l != t.t("party.received_none")).reduce(
		func(a: String, b: String) -> String: return b if a.is_empty() else a + "  " + b, ""), "받는 배율 줄 = 상태 화면과 같은 글")
	_check_desc(it, pm.item_name(gear), SheetParts.kind_icon(defs, gear), lines, "장비")
	# 소재: 「소재」 · 판매값. 상점에서 무엇을 푸는지는 쓰지 않는다.
	var mat: String = it.row_items[it.row_items.size() - 1]
	for j in it.row_items.size():
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check_eq(it.cursor_stop(), it.rows[it.row_items.size() - 1], "준비: 커서 = 마지막 소재")
	var mlines := it.item_lines(mat)
	check_eq(mlines, [t.t("party.items.materials"), t.t("party.items.sell", {"money": ShopRules.sell_price(defs, mat)})] as Array[String], "소재 설명 줄")
	_check_desc(it, t.t(mat), "kind_material", mlines, "소재")
	check(_items_yellow(it).size() == 1 and _yellow(pm) == [str(it.rows[it.row_items.size() - 1].name)], "노랑은 커서 줄 하나")
	# 디버그 보급: 알약 = 보급 설명 한 줄, 「+1」 = 그 장비, 대원 단추 = 이름·Lv·경험치·다음 레벨까지.
	for j in it.row_items.size() + 1:
		await kit.press_key(KEY_UP)
	await kit.frames(1)
	check_eq(it.cursor_stop(), it.supply_button, "준비: 커서 = 알약")
	_check_desc(it, t.t("party.supply"), "", [t.t("party.supply.desc")], "알약")
	check_eq(_items_yellow(it), ["SupplyToggle"], "알약이 노랑 하나")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	var first: String = defs.battle.equipment_ids[0]
	check_eq(it.cursor_stop(), it.plus_buttons[0], "준비: 커서 = 첫 「+1」")
	_check_desc(it, pm.item_name(first), SheetParts.kind_icon(defs, first), it.item_lines(first), "보급 「+1」")
	check(_items_yellow(it) == ["Supply_0"] and it.supply_button.checked, "노랑은 「+1」 하나, 알약은 켜짐(하늘색)")
	var pill_fill := _drawn_entries(it.supply_button, "fill")
	check(pill_fill.size() == 1 and pill_fill[0]["color"] == ListParts.PILL_ON, "켜진 알약은 하늘색으로 그렸다: %s" % str(pill_fill))
	var e := it.exp_buttons[2]
	it.list.ensure_visible(it.group_top(e), e.position.y + e.size.y)
	await kit.frames(1)
	await kit.tap(kit.center_of(e))
	await kit.frames(1)
	check_eq(it.cursor_stop(), e, "준비: 커서 = 대원 2 「경험치 +100」")
	_check_desc(it, pm.member_name(2), "", it.member_lines(2), "대원 단추")
	var m := s.state.party.members[2]
	check_eq(it.member_lines(2), [t.t("party.level", {"level": m.level}), t.t("party.exp", {"exp": m.exp}),
		t.t("party.exp_next", {"n": defs.battle.growth.cum(m.level + 1) - m.exp})] as Array[String], "대원 줄: Lv·경험치·다음 레벨까지")


## 장비 item 의 받는 배율 표(키 → 1000 + 보정, 상태 화면 표 꼴).
static func _received_of(defs: GameDefs, item: String, key: String) -> Dictionary:
	var out := {}
	var table: Dictionary = defs.battle.equip(item).get(key)
	for k in table:
		out[k] = 1000 + int(table[k])
	return out


## 설명 상자가 그린 것: 머리 채움(DESC_HEAD, head_rect)·몸 채움, 머리 글 = title, 아이콘 = icon(머리 안), 몸 줄 = lines(그 차례), 글은 폭 안·대비.
func _check_desc(it: PartyItemsTab, title: String, icon: String, lines: Array, tag: String) -> void:
	var d := it.desc
	var r := Rect2(Vector2.ZERO, d.size)
	var fills := _drawn_entries(d, "fill")
	check(fills.any(func(e: Dictionary) -> bool: return e["rect"] == ListParts.head_rect(r) and e["color"] == ListParts.DESC_HEAD), tag + ": 머리를 #001F37 로 채웠다")
	check(fills.any(func(e: Dictionary) -> bool: return e["rect"] == ListParts.body_rect(r) and e["color"] == ListParts.DESC_BODY), tag + ": 몸을 #006797 로 채웠다")
	var texts := _drawn_entries(d, "text")
	var head := texts.filter(func(e: Dictionary) -> bool: return ListParts.head_rect(r).has_point((e["rect"] as Rect2).position + Vector2(1, int(e["fs"]) * 0.6)))
	var body := texts.filter(func(e: Dictionary) -> bool: return ListParts.body_rect(r).has_point((e["rect"] as Rect2).position + Vector2(1, int(e["fs"]) * 0.6)))
	check_eq(head.map(func(e: Dictionary) -> String: return e["text"]), [title], tag + ": 머리 글")
	check_eq(body.map(func(e: Dictionary) -> String: return e["text"]), lines, tag + ": 몸 줄")
	check(body.all(func(e: Dictionary) -> bool: return int(e["fs"]) >= ListParts.DESC_FS_MIN), tag + ": 줄 글자 12px 이상")
	check_eq(_drawn_icons_in(d, ListParts.head_rect(r)), [icon] if not icon.is_empty() else [], tag + ": 머리 아이콘")
	_check_drawn_text(d, tag + " 설명 상자")


## 가장 긴 실제 내용: 모든 장비·소재의 설명 줄이 몸 폭에 12px 이상으로 들고, 이름이 머리에 든다(그리는 함수와 같은 폭·크기).
func test_items_longest_description_content_fits() -> void:
	var s := await _open()
	var pm := s.party_menu
	_fill_bag(s, 1, 1)
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(1)
	var it := pm.items_tab
	var r := Rect2(Vector2.ZERO, it.desc.size)
	var room := ListParts.line_room(r)
	var widest := 0.0
	var most := 0
	for id in it.row_items:
		var lines := it.item_lines(id)
		most = maxi(most, lines.size())
		check(lines.size() <= ListParts.DESC_LINES, "%s: 줄 %d ≤ 4" % [id, lines.size()])
		for l in lines:
			var fs := ListParts.line_fs(it.desc, l, room)
			widest = maxf(widest, SheetParts.text_width(it.desc, l, ListParts.DESC_FS))
			check(fs >= ListParts.DESC_FS_MIN and SheetParts.text_width(it.desc, l, fs) <= room, "%s: 「%s」 %dpx 가 %.0f 안" % [id, l, fs, room])
		check(SheetParts.text_width(it.desc, it.item_label(id), ListParts.HEAD_FS) <= ListParts.head_room(r, 0), "%s: 이름이 머리에 든다" % id)
	check(most == 4, "네 줄인 장비가 있다(%d)" % most)
	# 실제로 그려 본다: 가장 긴 줄의 장비.
	var best := ""
	var bw := 0.0
	for id in it.row_items:
		for l in it.item_lines(id):
			var w := SheetParts.text_width(it.desc, l, ListParts.DESC_FS)
			if w > bw:
				bw = w
				best = id
	it.desc.show_desc(it.item_label(best), it.item_icon(best), it.item_lines(best))
	await kit.frames(1)
	check(_check_drawn_text(it.desc, "가장 긴 설명 " + best) >= 3, "가장 긴 설명 글을 그렸다")
	# 직업 표(장비 화면 E2-c 용): 머리 오른쪽 칸, 이름 자리를 줄인다. 그린 칸 색과 글 대비.
	it.desc.show_desc(it.item_label(best), it.item_icon(best), it.item_lines(best), [["홀", true], ["블", false], ["나", true], ["글", false]])
	await kit.frames(1)
	var cells := ListParts.table_rects(r, 4)
	var fills := _drawn_entries(it.desc, "fill").filter(func(e: Dictionary) -> bool: return cells.has(e["rect"]))
	check_eq(fills.map(func(e: Dictionary) -> Color: return e["color"]), [ListParts.TABLE_ON, ListParts.TABLE_OFF, ListParts.TABLE_ON, ListParts.TABLE_OFF],
		"직업 표 칸 넷")
	check(cells[0].position.x > ListParts.head_rect(r).position.x + ListParts.DESC_TEXT_PAD + ListParts.head_room(r, 4), "표는 이름 자리 오른쪽")
	_check_drawn_text(it.desc, "직업 표")
	_check_drawn_text(it.window, "목록 창")


## 목록 줄의 장비 화면 선택지(E2-c 가 쓴다): 「E」 표(어두운 칸, 노랑 아님)·흐린 줄·빈 아이콘 줄(빼기)을 그려 본다.
func test_list_rows_draw_equipped_mark_dim_and_remove_rows() -> void:
	kit = Kit.new(tree)
	var host := Control.new()
	host.size = Vector2(437, 64)
	tree.root.add_child(host)
	var row := ListButton.new()
	row.size = Vector2(437, 64)
	host.add_child(row)
	# [아이콘, 이름, 개수, 흐림, 「E」, 커서]
	for c in [["kind_sword", "트윈 엣지", "1개", false, true, false], ["kind_body", "패딩 코트", "", true, false, false],
			["", "빼기", "", false, false, false], ["kind_sword", "트윈 엣지", "99개", false, true, true]]:
		row.icon_name = c[0]
		row.show_row(c[1], c[2], "", c[3])
		row.equipped = c[4]
		row.selected = c[5]
		await kit.frames(1)
		var tag := "줄 %s" % str(c)
		var fills := _drawn_entries(row, "fill")
		var marks := fills.filter(func(e: Dictionary) -> bool: return e["color"] == ListParts.EQUIP_MARK)
		check_eq(marks.size(), 1 if c[4] else 0, tag + ": 「E」 칸")
		if c[4]:
			check(_drawn_entries(row, "text").any(func(e: Dictionary) -> bool: return e["text"] == "E"), tag + ": 「E」 글")
		check(fills.any(func(e: Dictionary) -> bool: return e["color"] == (ListParts.CURSOR if row.selected else (ListParts.ROW_DIM if c[3] else ListParts.ROW_BODY))), tag + ": 몸 색")
		check_eq(_drawn_icons_in(row, ListParts.row_boxes(Rect2(Vector2.ZERO, row.size))["icon"]), [c[0]] if not c[0].is_empty() else [], tag + ": 아이콘")
		check_eq(fills.filter(func(e: Dictionary) -> bool: return _is_yellow(e["color"])).size(), 1 if row.selected else 0, tag + ": 노랑은 커서일 때만")
		_check_drawn_text(row, tag)
	tree.root.remove_child(host)
	host.free()


# ---- 소지품 고침(E2-b 독립 검토 M1·M2·M3) ----

## 커서 칸이 노랑을 어떻게 보이는지 경우마다 밝힌다(07 §9.9 E2-b 메모, 조정자 결정 M3): 보통 칸이면 노랑 채움이 그 칸 하나,
## 흐린 칸(최대 레벨의 「다음 레벨까지」)이면 노랑 채움 0 개이고 그 칸은 흐린 커서 모양(disabled_selected: 어두운 채움 + 노란 테).
func _check_cursor_yellow(it: PartyItemsTab, tag: String) -> void:
	var c := it.cursor_stop() as PartyButton
	check(c != null, tag + ": 커서 칸이 있다")
	if c == null:
		return
	var ys := _items_yellow(it)
	if c.dimmed:
		var lk := UiTheme.look(c.theme_state())
		check_eq([c.theme_state(), ys], ["disabled_selected", []], tag + ": 흐린 커서 칸 → 흐린 커서 모양, 노랑 채움 0개")
		check(not _is_yellow(lk["top"]) and not _is_yellow(lk["bottom"]) and _is_yellow(lk["outer"]) and float(lk["outer_w"]) > 0.0,
			tag + ": 흐린 커서 모양 = 어두운 채움 + 노란 테")
	else:
		check_eq(ys, [str(c.name)], tag + ": 노랑 채움은 커서 칸 하나")


## M1: 높은 화면(목록 일곱 줄)에서 마지막 줄에 커서를 두고 낮은 화면(넷)으로 바꾸면 커서 줄이 다시 보인다. 대원 보급 단추면 이름 줄까지.
func test_items_cursor_stays_in_view_after_a_tall_to_short_resize() -> void:
	var s := await _open()
	var pm := s.party_menu
	_fill_bag(s, 1, 2)
	await _window(Vector2(1280, 960))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	var last := it.stops().size() - 1
	while it.cursor < last:
		await kit.press_key(KEY_DOWN)
	var row := it.cursor_stop()
	check(it.list.size.y > 400.0 and it.shown(row) and it.list.scroll > 0.0, "준비: 960 에서 마지막 줄, 내림 %.0f" % it.list.scroll)
	await _window(Vector2(1280, 720))
	await kit.frames(2)
	check(it.list.size.y < 300.0, "준비: 목록이 넷으로 줄었다")
	check_eq(it.cursor_stop(), row, "커서는 그대로")
	check(it.list.shows(Rect2(row.position, row.size)), "줄어든 뒤에도 커서 줄이 다 보인다(내림 %.0f, 줄 %s)" % [it.list.scroll, str(Rect2(row.position, row.size))])
	_check_cursor_yellow(it, "줄어든 뒤")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq([it.cursor, pm.accepted_inputs], [last, n], "끝에서 ↓ 는 그대로(다 보이니 아무 일 없음)")
	# 보급 줄: 마지막 대원의 「경험치 +100」 → 줄이고 나서 이름 줄과 단추가 함께 보인다.
	await _window(Vector2(1280, 960))
	await kit.frames(2)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_1)
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	check(it.supply_open, "준비: 보급 줄")
	var k := s.state.party.members.size() - 1
	var e := it.exp_buttons[k]
	while it.cursor_stop() != e and it.cursor < it.stops().size() - 1:
		await kit.press_key(KEY_DOWN)
	check(it.cursor_stop() == e and it.shown(e), "준비: 960 에서 마지막 대원 「경험치 +100」")
	await _window(Vector2(1280, 720))
	await kit.frames(2)
	var label := it.member_rows[k]
	check(it.list.shows(Rect2(label.position, label.size)) and it.list.shows(Rect2(e.position, e.size)),
		"줄어든 뒤 대원 %d 이름 줄과 단추가 보인다(내림 %.0f)" % [k, it.list.scroll])
	_check_cursor_yellow(it, "보급 줄어든 뒤")


## M1: 손으로 끌어 커서 칸을 가린 뒤, 끝에서 ↓(↑) 는 커서를 옮기지 않고 커서 칸을 다시 보이게 한다. 보통 refresh(보급 누르기·다시 그리기)는
## 커서 칸이 보이는 한 손으로 내린 자리를 그대로 둔다.
func test_items_end_key_reveals_the_cursor_and_refresh_keeps_manual_scroll() -> void:
	var s := await _open()
	var pm := s.party_menu
	_fill_bag(s, 1, 2)
	await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	var last := it.stops().size() - 1
	while it.cursor < last:
		await kit.press_key(KEY_DOWN)
	var row := it.cursor_stop()
	var from := kit.center_of(it.list) - Vector2(0, 80)
	kit.touch(FINGER, from, true)
	await kit.frames(1)
	kit.drag(FINGER, from, from + Vector2(0, 400))
	await kit.frames(1)
	kit.touch(FINGER, from + Vector2(0, 400), false)
	await kit.frames(2)
	check(not it.shown(row) and it.cursor == last, "준비: 끌어 내려 마지막 줄을 가렸다(내림 %.0f), 커서 그대로" % it.list.scroll)
	var n := pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq(it.cursor, last, "끝에서 ↓ → 커서는 그대로")
	check(it.shown(row) and pm.accepted_inputs == n + 1, "끝에서 ↓ → 가려진 커서 줄을 다시 보인다(입력 하나)")
	n = pm.accepted_inputs
	await kit.press_key(KEY_DOWN)
	check_eq(pm.accepted_inputs, n, "다 보이면 끝에서 ↓ 는 아무 일 없음")
	# 보통 refresh 는 손으로 내린 자리를 그대로: 보급 「+1」(커서 칸)이 보이는 채 조금 내린 뒤 누르기·Enter·다시 그리기.
	while it.cursor > 0:
		await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	check(it.supply_open, "준비: 보급 줄")
	for j in 4:
		await kit.press_key(KEY_DOWN)
	var b := it.cursor_stop()
	check(b == it.plus_buttons[3], "준비: 커서 = 넷째 「+1」")
	it.list.scroll_to(it.list.scroll + 20.0 if b.position.y - it.list.scroll > 40.0 else it.list.scroll - 20.0)
	await kit.frames(1)
	var keep := it.list.scroll
	check(it.shown(b), "준비: 손으로 조금 내렸고 커서 칸은 보인다(내림 %.0f)" % keep)
	var id: String = s.state.defs.battle.equipment_ids[3]
	var bag := int(s.state.gear_bag.get(id, 0))
	await kit.press_key(KEY_ENTER)
	await kit.tap(kit.center_of(b))
	pm.refresh_view()
	await kit.frames(1)
	check_eq(int(s.state.gear_bag.get(id, 0)), mini(bag + 2, BattleLimits.BAG_MAX), "Enter·누르기 → 「+1」 두 번")
	check_eq(it.list.scroll, keep, "보급 누르기·다시 그리기 뒤에도 손으로 내린 자리 그대로")


## M1: 일반 실행에서 첫 칸(첫 가방 줄)에서 ↑ 도 같다: 손으로 내려 가린 뒤 ↑ → 커서 그대로, 다시 보인다.
func test_items_first_row_up_reveals_the_cursor_in_a_normal_build() -> void:
	var s := await _open_plain()
	var pm := s.party_menu
	_fill_bag(s, 1, 2)
	await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	check_eq([it.cursor, it.cursor_stop(), pm.debug], [0, it.rows[0], false], "준비: 일반 실행, 커서 = 첫 줄")
	it.list.scroll_to(it.list.max_scroll())
	await kit.frames(1)
	check(not it.shown(it.cursor_stop()), "준비: 첫 줄을 가렸다")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_UP)
	check(it.cursor == 0 and it.shown(it.cursor_stop()) and pm.accepted_inputs == n + 1, "첫 칸에서 ↑ → 커서 그대로, 다시 보인다")
	await kit.press_key(KEY_UP)
	check_eq(pm.accepted_inputs, n + 1, "다 보이면 첫 칸 ↑ 는 아무 일 없음")
	_check_cursor_yellow(it, "첫 줄")


## 검토 2차 R2-1: 일반 실행에서 가방 줄은 「선택」이 흐리다. 커서 줄을 손으로 내려 가린 뒤 Enter·Space·키패드 「선택」은 모두 아무 일도
## 하지 않는다(내림·커서·상태 그대로, 받은 입력 없음: 키패드 = 키).
func test_items_dimmed_confirm_on_a_bag_row_changes_nothing() -> void:
	var s := await _open_plain()
	var pm := s.party_menu
	_fill_bag(s, 1, 2)
	await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	check_eq([pm.debug, it.cursor_stop(), pm.pad_state()["ok"]], [false, it.rows[0], false], "준비: 일반 실행, 커서 = 첫 가방 줄, 「선택」 흐림")
	it.list.scroll_to(it.list.max_scroll())
	await kit.frames(1)
	var scroll := it.list.scroll
	check(scroll > 0.0 and not it.shown(it.cursor_stop()), "준비: 커서 줄을 손으로 가렸다(내림 %.0f)" % scroll)
	var h := SaveCodec.state_hash(s.state)
	var n := pm.accepted_inputs
	for k in [KEY_ENTER, KEY_SPACE]:
		await kit.press_key(k)
		check_eq([it.list.scroll, it.cursor, SaveCodec.state_hash(s.state), pm.accepted_inputs], [scroll, 0, h, n], "%s: 아무 일 없음" % OS.get_keycode_string(k))
	var ok := pm.key_pad_stacked.button("ok")
	check(ok.is_visible_in_tree() and ok.disabled, "키패드 「선택」은 흐림")
	await kit.tap(kit.center_of(ok))
	check_eq([it.list.scroll, it.cursor, SaveCodec.state_hash(s.state), pm.accepted_inputs], [scroll, 0, h, n], "키패드 「선택」: 아무 일 없음")


## M2: 보급 대원 단추를 누르거나 Enter 로 누르면 그 대원 이름 줄과 단추가 함께 보인다(끌기만으로는 커서도 일도 없다).
func test_supply_click_and_confirm_show_the_member_group() -> void:
	var s := await _open()
	var pm := s.party_menu
	await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	await kit.tap(kit.center_of(it.supply_button))
	check(it.supply_open, "준비: 보급 줄")
	var e := it.exp_buttons[0]
	var label := it.member_rows[0]
	it.list.scroll_to(e.position.y)
	await kit.frames(1)
	check(it.list.shows(Rect2(e.position, e.size)) and not it.list.shows(Rect2(label.position, label.size)), "준비: 단추는 보이고 이름 줄은 위로 가려졌다")
	var m := s.state.party.members[0]
	var exp0 := m.exp
	await kit.tap(kit.center_of(e))
	check_eq([it.cursor_stop(), m.exp], [e, exp0 + 100], "누르기 → 커서가 그 단추로, 경험치 +100")
	check(it.list.shows(Rect2(label.position, label.size)) and it.list.shows(Rect2(e.position, e.size)), "누른 뒤 이름 줄과 단추가 함께 보인다(내림 %.0f)" % it.list.scroll)
	it.list.scroll_to(it.list.max_scroll())
	await kit.frames(1)
	check(not it.list.shows(Rect2(e.position, e.size)), "준비: 손으로 내려 단추를 가렸다")
	await kit.press_key(KEY_ENTER)
	check_eq(m.exp, exp0 + 200, "Enter → 같은 단추 한 번 더")
	check(it.list.shows(Rect2(label.position, label.size)) and it.list.shows(Rect2(e.position, e.size)), "Enter 뒤 이름 줄과 단추가 다시 보인다(내림 %.0f)" % it.list.scroll)
	_check_cursor_yellow(it, "Enter 뒤")


## M3(조정자 결정): 최대 레벨의 「다음 레벨까지」도 커서 칸이다. 그 칸에 커서가 있으면 흐린 커서 모양(어두운 채움 + 노란 테)이고 노랑 채움은 없다.
## Lv 29 → 누르기 → Lv 30(커서 그대로, 모양이 바뀐다) → Enter 는 최대 안내만. 이미 최대인 대원의 단추로 ↓ 로 가도 같다.
func test_capped_next_level_cursor_shows_the_dimmed_cursor_look() -> void:
	var s := await _open()
	var pm := s.party_menu
	var g := s.state.defs.battle.growth
	var k := 1
	GrowthRules.grant_exp(s.state, k, g.cum(g.level_cap - 1))
	GrowthRules.grant_exp(s.state, 3, g.cum(g.level_cap))
	var m := s.state.party.members[k]
	check_eq([m.level, s.state.party.members[3].level], [g.level_cap - 1, g.level_cap], "준비: 대원 %d Lv %d, 대원 3 최대" % [k, g.level_cap - 1])
	await _window(Vector2(1280, 720))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	var it := pm.items_tab
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	var nx := it.next_buttons[k]
	while it.cursor_stop() != nx and it.cursor < it.stops().size() - 1:
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check(it.cursor_stop() == nx and not nx.dimmed, "준비: 커서 = 대원 %d 「다음 레벨까지」(아직 최대 아님)" % k)
	_check_cursor_yellow(it, "Lv 29 커서")
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	check_eq([m.level, it.cursor_stop(), nx.dimmed], [g.level_cap, nx, true], "Enter → 최대 레벨, 커서 그대로, 칸은 흐림")
	_check_cursor_yellow(it, "Lv 30 이 된 칸")
	var h := SaveCodec.state_hash(s.state)
	var saves := s.autosave_count
	await kit.press_key(KEY_ENTER)
	check_eq([pm.notice, SaveCodec.state_hash(s.state), s.autosave_count], [s.texts.t("party.exp_max"), h, saves], "다시 Enter → 최대 안내만(상태·저장 그대로)")
	var capped := it.next_buttons[3]
	while it.cursor_stop() != capped and it.cursor < it.stops().size() - 1:
		await kit.press_key(KEY_DOWN)
	await kit.frames(1)
	check(it.cursor_stop() == capped and capped.dimmed, "↓ 로 이미 최대인 대원 3 「다음 레벨까지」")
	_check_cursor_yellow(it, "이미 최대인 칸")
	await kit.press_key(KEY_UP)
	await kit.frames(1)
	check(it.cursor_stop() == it.exp_buttons[3] and not it.exp_buttons[3].dimmed, "↑ → 대원 3 「경험치 +100」(흐리지 않음)")
	_check_cursor_yellow(it, "흐리지 않은 칸으로 돌아옴")


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
		# 맨 위(E1 ⑥): 뿌리의 걸음 문패·장소 띠·소지금 그대로, 알림 줄 자리에 「기록」. 「기록」 문패·「뒤로」 단추는 없다.
		for c in [pm.camp_plate, pm.ribbon, pm.money_plate, pm.notice_line]:
			check((c as Control).is_visible_in_tree(), "%s: 맨 위 띠 %s 가 보인다" % [tag, c.name])
		for c in [pm.camp_list, pm.cards]:
			check(not (c as Control).is_visible_in_tree(), "%s: 뿌리의 %s 는 감춘다" % [tag, c.name])
		check_eq([_rect(pm.camp_plate), _rect(pm.ribbon), _rect(pm.money_plate), _rect(pm.notice_line)],
			[Rect2(0, 0, 176, 66), Rect2(176, 0, size.x - 328 - 176, 66), Rect2(size.x - 328, 16, 328, 50), Rect2(176, 70, size.x - 16 - 176, 38)],
			tag + ": 맨 위 띠는 뿌리와 같은 자리")
		check_eq(pm.notice_line_text(), s.texts.t("camp.cmd.records"), tag + ": 띠에 「기록」")
		check_eq(s.debug_snapshot()["party_menu"]["strip"], s.texts.t("camp.cmd.records"), tag + ": 스냅숏 strip")
		for n in ["RecordsTitle", "RecordsBack"]:
			check(pm.find_child(n, true, false) == null, "%s: %s 없음" % [tag, n])
		var win := _rect(rt.window)
		var wx := maxf(size.x / 2.0 - 430.0, 224.0)
		check_eq(win, Rect2(wx, 116, 860, 482), tag + ": 슬롯 창 860 폭, y 116~598(띠 아래 + 8), 가운데(1280 은 방향 십자를 비켜 x 224)")
		var band := _rect(rt.band)
		check_eq([band.position.x, band.size.x], [wx - 10.0, 880.0], tag + ": 아래 띠 880 폭, 슬롯 창 양옆 10")
		for i in rt.band_buttons.size():
			for j in range(i + 1, rt.band_buttons.size()):
				check(not _rect(rt.band_buttons[i]).intersects(_rect(rt.band_buttons[j])), "%s: %s 와 %s 가 겹친다" % [tag, rt.band_buttons[i].name, rt.band_buttons[j].name])
		check(band.position.y >= win.end.y and band.end.y <= size.y - 8.0, tag + ": 아래 띠는 슬롯 창 아래, 화면 안(아래 여백 8)")
		var parts := {"step": _rect(pm.camp_plate), "ribbon": _rect(pm.ribbon), "money": _rect(pm.money_plate), "strip": _rect(pm.notice_line),
			"window": win, "band": band, "dir_pad": _rect(pm.dir_pad), "keys": _rect(pm.key_pad_stacked)}
		check(pm.dir_pad.is_visible_in_tree() and pm.key_pad_stacked.is_visible_in_tree(), tag + ": 키패드 둘이 보인다")
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
		for d in [rt, rt.window, rt.band, pm.notice_line]:
			check_eq((d as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s: %s 는 장식" % [tag, d.name])
		_check_targets(pm, size, tag)
		var snap := [win, band, _rect(rt.load_buttons[2])]
		if first.has(px):
			check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
		first[px] = snap
	# 노랑(E1 ⑦): 채움은 커서 단추 하나, 커서 카드의 번호 칸은 밝은 하늘색(노랑 아님).
	check_eq(_yellow(pm), [str(rt.cursor_button().name)], "기록의 노랑 채움은 커서 단추 하나")
	check_eq([rt.cur_row, rt.num_fill(0), rt.num_fill(1)], [0, UiTheme.CMD_CHOSEN, UiTheme.SHOP_WIN_CAP], "커서 카드 번호 칸 = 밝은 하늘색, 다른 칸 = 마개 색")
	check(rt.num_fill(0) != UiTheme.BTN_PICK and contrast(rt.num_text_color(0), rt.num_fill(0)) >= 4.5, "번호 칸은 노랑 채움이 아니고 글자 대비 4.5:1")
	# 알림이 있으면 띠의 「기록」을 잠시 대신한다(알림 규칙 그대로).
	pm.show_notice("시험 안내")
	check_eq([pm.notice_line_text(), pm.notice_line.is_visible_in_tree()], ["시험 안내", true], "알림이 「기록」을 대신한다")
	pm._clear_notice()
	check_eq([pm.notice_line_text(), pm.notice_line.is_visible_in_tree()], [s.texts.t("camp.cmd.records"), true], "알림이 지나면 「기록」")
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


## 전투도 캠프와 같다(독립 검토 P1·P2 Medium): 전투 층 위에 바깥 창(층 3 알림)이 뜨면 전투 입구는 어떤 입력도 받지 않고,
## 창이 열리고 닫힐 때 눌려 있던 전투 포인터를 모두 버린다. 명령 줄(메뉴)·적 칸(대상)·키패드 「선택」(정해진 대상 확인)을 누른 채
## 알림이 뜬다 → 알림이 덮은 채 떼도, 다른 손가락으로 알림을 닫은 뒤 떼도 명령·상태 그대로. 알림 아래에서 L·숫자·방향·Enter·Esc 도.
func _battle_sig(s: DungeonScreen) -> Array:
	var l := s.battle_layer
	return [l.phase, l.sub, l.member, l.cursor, l.commands.duplicate(true), l.target_skill, l.target_fixed, l.log_view.visible,
		l.log_view.scroll_offset(), Fixtures.battle_hash(s.state), l.accepted_inputs]


func test_held_battle_input_does_nothing_after_an_external_alert() -> void:
	var s := await _open()
	s.state = Fixtures.battle(Fixtures.defs(), "formation.f1.rats_moth", 5)
	s._open_battle()
	await kit.frames(3)
	var l := s.battle_layer
	check_eq([l.phase, l.sub, l.member], ["command", "menu", 0], "준비: 전투 명령 입력")
	var cases := [
		["명령 줄 「방어」", [], func() -> TouchButton: return l.find_child("Cmd_guard", true, false) as TouchButton, "menu"],
		["적 칸(공격 대상)", [["command", 0]], func() -> TouchButton: return l.enemy_area.card(0), "target"],
		["키패드 「선택」(정해진 대상 확인)", [["back"], ["command", 1], ["skill", "skill.holo_knight.defense_protocol"]],
			func() -> TouchButton: return l.key_pad.button("ok"), "target"],
	]
	for c in cases:
		for st in c[1]:
			l.handle(st[0], st[1] if st.size() > 1 else null)
			await kit.frames(1)
		check_eq(l.sub, c[3], "%s: 준비 단계" % c[0])
		for under in [true, false]:
			var b: TouchButton = (c[2] as Callable).call()
			var tag := "%s 누른 채 알림 → %s" % [c[0], "알림이 덮은 채 뗌" if under else "다른 손가락으로 알림을 닫고 뗌"]
			var sig := _battle_sig(s)
			var p := kit.center_of(b)
			kit.touch(4, p, true)
			await kit.frames(2)
			check(b.held, tag + ": 준비: 눌림")
			await _import_error(s)
			check(s.modal.kind == "alert" and not b.held, tag + ": 알림이 뜨면 전투 눌림을 버린다")
			check(not l.handle("confirm") and not l.handle("log") and not l.handle("command", 2), tag + ": 알림이 떠 있으면 전투 입구가 받지 않는다")
			if not under:
				await _dismiss_alert(s)
				check_eq(s.modal.kind, "", tag + ": 준비: 다른 손가락으로 알림 닫음")
			kit.touch(4, p, false)
			await kit.frames(3)
			check_eq(_battle_sig(s), sig, tag + ": 명령·단계·커서·규칙 상태·받은 입력 그대로")
			if s.modal.is_open():
				await _dismiss_alert(s)
	# 알림 아래의 키: 전투 키는 아무 일도 하지 않는다(알림을 닫는 키는 알림이 받는다 → 다시 띄우고 이어서).
	var sig := _battle_sig(s)
	await _import_error(s)
	for k in [KEY_L, KEY_1, KEY_2, KEY_3, KEY_4, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_BACKSPACE]:
		if not s.modal.is_open():
			await _import_error(s)
		await kit.press_key(k)
		check_eq(_battle_sig(s), sig, "알림 아래 %s: 전투 그대로(로그 열리지 않음)" % OS.get_keycode_string(k))
	if s.modal.is_open():
		await _dismiss_alert(s)
	await kit.press_key(KEY_L)
	check(l.log_view.visible, "알림이 닫히면 L 은 다시 로그를 연다")


## 전투 로그 끌기도 같은 취소 규칙(독립 검토 2차 Medium): 로그를 손가락·마우스로 끄는 중에 바깥 알림이 뜨면 그 끌기는 끊긴다.
## 알림 아래에서 더 끌어도, 다른 손가락으로 알림을 닫은 뒤 더 끌어도 로그 위치가 그대로다. 보통 끌기·휠·↑↓ 는 그대로 내린다.
func _log_mouse_move(p: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func test_battle_log_drag_is_cut_by_an_external_alert() -> void:
	var s := await _open()
	await _window(WINDOWS[0])  # 실제 창 1280×720: 끄는 거리(창 좌표) = 논리 좌표
	s.state = Fixtures.battle(Fixtures.defs(), "formation.f1.rats_moth", 5)
	s._open_battle()
	await kit.frames(3)
	var l := s.battle_layer
	var lv := l.log_view
	for i in 100:
		lv.add_line("시험 로그 줄 %d — 넘치도록 충분히 긴 글" % i)
	await kit.press_key(KEY_L)
	await kit.frames(2)
	check(lv.visible and lv.max_scroll() > 400.0, "준비: 로그가 넘친다(최대 %d)" % int(lv.max_scroll()))
	check_eq(lv.scroll_offset(), lv.max_scroll(), "열면 맨 아래(가장 최근 줄)")
	check(lv.scroll_bar_rect().has_area(), "위치 막대가 보인다")
	var bar0 := lv.scroll_bar_rect()
	# 보통 끌기·휠·↑↓ 는 내린다.
	var mid := kit.center_of(lv._scroll)
	kit.touch(4, mid, true)
	kit.drag(4, mid, mid + Vector2(0, 120))
	kit.touch(4, mid + Vector2(0, 120), false)
	await kit.frames(2)
	check_eq(lv.scroll_offset(), lv.max_scroll() - 120.0, "손가락으로 아래로 끌면 위(앞 줄)로 120")
	check(lv.scroll_bar_rect().position.y < bar0.position.y, "위치 막대가 따라 올라간다")
	var at := lv.scroll_offset()
	kit.mouse(mid, true, MOUSE_BUTTON_WHEEL_UP)
	kit.mouse(mid, false, MOUSE_BUTTON_WHEEL_UP)
	await kit.frames(2)
	check_eq(lv.scroll_offset(), at - PartyScroll.WHEEL_STEP, "휠 위 → 한 칸 위로")
	at = lv.scroll_offset()
	await kit.press_key(KEY_UP)
	check_eq(lv.scroll_offset(), at - BattleLogView.STEP, "↑ → 60 위로(키패드 ↑ 와 같은 길)")
	kit.mouse(mid, true)
	_log_mouse_move(mid + Vector2(0, -30), Vector2(0, -30))
	kit.mouse(mid + Vector2(0, -30), false)
	await kit.frames(2)
	check_eq(lv.scroll_offset(), at - BattleLogView.STEP + 30.0, "마우스로 위로 끌면 아래로 30")
	# 끄는 중에 알림: 손가락(알림 아래에서 계속 끎 / 다른 손가락으로 닫고 계속 끎), 마우스(같은 둘).
	for way in ["touch", "mouse"]:
		for under in [true, false]:
			var tag := "%s 끌기 중 알림 → %s" % [way, "알림 아래에서 계속 끎" if under else "다른 손가락으로 닫고 계속 끎"]
			lv.scroll_by(-100)
			await kit.frames(1)
			var pre := lv.scroll_offset()
			var p := mid
			if way == "touch":
				kit.touch(4, p, true)
				kit.drag(4, p, p + Vector2(0, -40), 2)
			else:
				kit.mouse(p, true)
				_log_mouse_move(p + Vector2(0, -40), Vector2(0, -40))
			await kit.frames(2)
			var moved := lv.scroll_offset()
			check(absf(moved - pre - 40.0) < 0.01, "%s: 준비: 알림 전 끌기가 내렸다(%.1f → %.1f)" % [tag, pre, moved])
			var sig := _battle_sig(s)
			await _import_error(s)
			check_eq(s.modal.kind, "alert", tag + ": 준비: 알림")
			if not under:
				await _dismiss_alert(s)
				check_eq(s.modal.kind, "", tag + ": 준비: 다른 손가락으로 알림 닫음")
			if way == "touch":
				kit.drag(4, p + Vector2(0, -40), p + Vector2(0, -160), 4)
			else:
				_log_mouse_move(p + Vector2(0, -160), Vector2(0, -120))
			await kit.frames(2)
			check_eq(lv.scroll_offset(), moved, tag + ": 로그 위치 그대로")
			check_eq(_battle_sig(s), sig, tag + ": 전투 모습(로그 위치 포함) 그대로")
			if way == "touch":
				kit.touch(4, p + Vector2(0, -160), false)
			else:
				kit.mouse(p + Vector2(0, -160), false)
			await kit.frames(2)
			if s.modal.is_open():
				await _dismiss_alert(s)
	# 알림이 닫힌 뒤 새 끌기는 다시 내린다.
	at = lv.scroll_offset()
	kit.touch(4, mid, true)
	kit.drag(4, mid, mid + Vector2(0, -50))
	kit.touch(4, mid + Vector2(0, -50), false)
	await kit.frames(2)
	check(absf(lv.scroll_offset() - minf(lv.max_scroll(), at + 50.0)) < 0.01, "새 끌기는 그대로 내린다(%.1f → %.1f)" % [at, lv.scroll_offset()])


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
	var row := kit.center_of(pm.camp_list.rows[SKILLS])
	kit.touch(4, row, true)
	await kit.frames(2)
	s._alert("시험 알림")
	await kit.frames(2)
	kit.touch(4, row, false)
	await kit.frames(3)
	check_eq([pm.page, pm.camp_cursor], ["root", EQUIP], "알림이 덮은 채 떼도 「스킬」 줄은 일하지 않는다")
	await _dismiss_alert(s)


# ---- 글자 대비 ----

func test_camp_and_status_colours_meet_contrast() -> void:
	var pairs := [
		["띠 글자", UiTheme.BATTLE_BANNER_TEXT, [UiTheme.FAC_BANNER_TOP, UiTheme.FAC_BANNER_BOTTOM]],
		["띠 안내", UiTheme.BATTLE_BANNER_NOTICE, [UiTheme.FAC_BANNER_TOP, UiTheme.FAC_BANNER_BOTTOM]],
		# 캠프 맨 위 띠(07 §9.8 ③): 장소 띠, 알림 줄(반투명 바탕은 불투명으로 본다), 소지금·걸음 문패(상점 소지금 문패와 같은 판).
		["장소 띠", UiTheme.RIBBON_TEXT, [UiTheme.RIBBON_FILL]],
		["알림 줄", UiTheme.BATTLE_BANNER_NOTICE, [Color(UiTheme.CAMP_NOTICE_BG, 1.0)]],
		["소지금", UiTheme.HEAD_TEXT, [UiTheme.PLATE_TOP, UiTheme.PLATE_BOTTOM]],
		["걸음 문패", UiTheme.TEXT, [UiTheme.PLATE_TOP, UiTheme.PLATE_BOTTOM]],
		# 대원 띠 한 벌(07 §9.9 E1 ②): 상태·스킬·인물 판 위 줄. 정보 띠는 두 끝 색 모두.
		["이름 칸", UiTheme.MEMBER_NAME_TEXT, [UiTheme.MEMBER_NAME_TAB]],
		["Lv", UiTheme.ST_LV_TEXT, [UiTheme.MEMBER_LV_BAND]],
		["정보 띠", MemberHeader.STRIP_TEXT, [UiTheme.MEMBER_STRIP_TOP, UiTheme.MEMBER_STRIP_BOTTOM]],
		["정보 띠 TP·안내", MemberHeader.STRIP_ACCENT, [UiTheme.MEMBER_STRIP_TOP, UiTheme.MEMBER_STRIP_BOTTOM]],
		["정보 띠 이름표", MemberHeader.STRIP_LABEL, [UiTheme.MEMBER_STRIP_TOP, UiTheme.MEMBER_STRIP_BOTTOM]],
		["직업 문패", UiTheme.TEXT, [UiTheme.ST_CLASS_PLATE]],
		# 상태 시트 부품(07 §9.9 E2-a, SheetParts): 잎 문패, 능력치 줄, 「내역」, 공격·방어, 장비 줄, 받는 배율.
		["시트 직업 문패", SheetParts.CLASS_TEXT, [SheetParts.CLASS_FILL]],
		["시트 능력치 이름·값", SheetParts.STAT_TEXT, [SheetParts.STAT_NAME_BOX, SheetParts.STAT_VALUE_BOX]],
		["시트 내역 값", SheetParts.STAT_TEXT, [SheetParts.STAT_TRACK]],
		["시트 내역 기본", UiTheme.ST_LV_TEXT, [SheetParts.STAT_TRACK]],
		["시트 내역 머리", SheetParts.SPLIT_HEAD_TEXT, [SheetParts.SPLIT_HEAD_BOX]],
		["시트 공격·방어", SheetParts.STAT_TEXT, [SheetParts.GEAR_LABEL_BOX, SheetParts.GEAR_VALUE_BOX]],
		["시트 장비 이름", SheetParts.STAT_TEXT, [SheetParts.EQUIP_NAME_BOX]],
		["시트 빈 장비", SheetParts.EQUIP_EMPTY_TEXT, [SheetParts.EQUIP_NAME_BOX]],
		["시트 바꾸면 오름", SheetParts.UP_COLOR, [SheetParts.STAT_VALUE_BOX, SheetParts.GEAR_VALUE_BOX]],
		["시트 바꾸면 내림", SheetParts.DOWN_COLOR, [SheetParts.STAT_VALUE_BOX, SheetParts.GEAR_VALUE_BOX]],
		["능력치 이름", UiTheme.TEXT, [UiTheme.ST_ROW_NAME, UiTheme.ST_ROW]],
		["공격·방어", UiTheme.TEXT, [UiTheme.ST_GEAR_LABEL, UiTheme.ST_GEAR_VALUE]],
		["장비 줄", UiTheme.TEXT, [UiTheme.ST_EQUIP_ROW]],
		["장비 칸 이름", UiTheme.SUB_TEXT, [UiTheme.ST_ROW_NAME]],
		["받는 배율 머리", UiTheme.TEXT, [UiTheme.ST_SIDE_TOP, UiTheme.ST_SIDE_BOTTOM]],
		["받는 배율 줄", UiTheme.CARD_TP, [UiTheme.ST_SIDE_TOP, UiTheme.ST_SIDE_BOTTOM]],
		["내역 머리", UiTheme.SUB_TEXT, [UiTheme.ST_ROW]],
		["시설 목록 글자", UiTheme.FAC_TEXT, [UiTheme.CMD_TOP, UiTheme.CMD_BOTTOM]],
		# 스킬 트리 화면(파랑): 위 줄, 직업 탭, 트리 창·설명 띠(반투명 창은 불투명으로 본다), 레벨 칸.
		["직업 탭", UiTheme.TEXT, [UiTheme.TREE_TAB]],
		["설명 글", UiTheme.TEXT, [Color(UiTheme.TREE_WIN_TOP, 1.0), Color(UiTheme.TREE_WIN_BOTTOM, 1.0)]],
		# 스킬 트리(E2-d, 원작 b_03): 설명 상자 tree 모양(머리는 원작 #3285B1 → #2C78A6), 레벨 탭, 「Lv n」 막대, 노드 Lv 상자, 선의 「Lv n」, 알림 띠.
		["스킬 설명 머리", ListParts.TREE_DESC_TEXT, [ListParts.TREE_DESC_HEAD]],
		["스킬 설명 몸", ListParts.TREE_DESC_TEXT, [ListParts.TREE_DESC_BODY]],
		["스킬 설명 첫 줄", ListParts.TREE_DESC_ACCENT, [ListParts.TREE_DESC_BODY]],
		["레벨 탭(안 배움)", ListParts.TREE_TAB_OFF_TEXT, [ListParts.TREE_TAB_OFF]],
		["레벨 탭(배움·초안)", ListParts.TREE_TAB_ON_TEXT, [ListParts.TREE_TAB_ON]],
		["Lv 막대 글", ListParts.TREE_DESC_TEXT, [ListParts.TREE_BAR_LABEL]],
		["노드 Lv 상자", UiTheme.TREE_LV_BOX_TEXT, [UiTheme.TREE_LV_BOX]],
		["흐린 노드 Lv 상자", UiTheme.TREE_LV_BOX_OFF_TEXT, [UiTheme.TREE_LV_BOX_OFF]],
		["선의 Lv", PartySkillTab.LABEL_COLOR, [PartySkillTab.PANEL]],
		["알림 띠 글", ListParts.BANNER_TEXT, [ListParts.BANNER_BODY]],
		# 상점 짜임(장비·소지품): 목록·설명 창(반투명은 불투명으로 본다), 설명 머리 띠, 인물 판의 능력치·장비 줄.
		["상점 창 글", UiTheme.TEXT, [Color(UiTheme.SHOP_WIN_TOP, 1.0), Color(UiTheme.SHOP_WIN_BOTTOM, 1.0), UiTheme.SHOP_DESC_HEAD]],
		["상점 창 묶음 이름", UiTheme.SHOP_SECTION_TEXT, [Color(UiTheme.SHOP_WIN_TOP, 1.0), Color(UiTheme.SHOP_WIN_BOTTOM, 1.0)]],
		["능력치 이름", EquipTotals.NAME_COLOR, [UiTheme.ST_ROW_NAME, UiTheme.ST_GEAR_LABEL]],
		["능력치 값", EquipTotals.VALUE_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["능력치 오름", EquipTotals.UP_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["능력치 내림", EquipTotals.DOWN_COLOR, [UiTheme.ST_ROW, UiTheme.ST_GEAR_VALUE]],
		["판 장비 줄", UiTheme.TEXT, [UiTheme.ST_EQUIP_ROW]],
		["판 빈 장비", UiTheme.SUB_TEXT, [UiTheme.ST_EQUIP_ROW, UiTheme.ST_ROW_NAME]],
		# 소지품(07 §9.9 E2-b, ListParts 부품 H·I·J): 목록 줄·흐린 줄·커서 줄·「E」 표, 설명 머리·몸·직업 표, 알약(보통·누름·켜짐·커서),
		# 띠 글(「소지품   장비 n · 소재 n」은 알림 줄 글자색).
		["목록 줄", ListParts.ROW_TEXT, [ListParts.ROW_BODY]],
		["목록 흐린 줄", ListParts.ROW_DIM_TEXT, [ListParts.ROW_DIM]],
		["목록 커서 줄", ListParts.CURSOR_TEXT, [ListParts.CURSOR]],
		["목록 「E」 표", ListParts.EQUIP_MARK_TEXT, [ListParts.EQUIP_MARK]],
		["설명 머리", ListParts.DESC_TEXT, [ListParts.DESC_HEAD]],
		["설명 몸", ListParts.DESC_TEXT, [ListParts.DESC_BODY]],
		["설명 직업 표", ListParts.TABLE_ON_TEXT, [ListParts.TABLE_ON]],
		["설명 직업 표(못 낌)", ListParts.TABLE_OFF_TEXT, [ListParts.TABLE_OFF]],
		["알약", ListParts.PILL_TEXT, [ListParts.PILL, ListParts.PILL_PRESSED]],
		["알약 켜짐", ListParts.PILL_ON_TEXT, [ListParts.PILL_ON, ListParts.PILL_ON_PRESSED]],
		["알약 커서", ListParts.CURSOR_TEXT, [ListParts.CURSOR]],
		["소지품 띠", UiTheme.BATTLE_BANNER_NOTICE, [Color(UiTheme.CAMP_NOTICE_BG, 1.0)]],
	]
	for p in pairs:
		for bg in p[2]:
			var c := contrast(p[1], bg)
			check(c >= 4.5, "%s: %s on %s = %.2f ≥ 4.5" % [p[0], (p[1] as Color).to_html(false), (bg as Color).to_html(false), c])
	var lk := UiTheme.look("cmd:chosen")
	check(contrast(lk["text"], lk["top"]) >= 4.5, "고른 명령 줄")


## 대원 띠 한 벌(07 §9.9 E1 ②): 상태·스킬의 위 줄과 장비 인물 판의 띠가 같은 III 근사 색이고, 글자 대비 4.5:1 이상.
func test_member_bands_share_one_iii_palette() -> void:
	var s := await _open()
	var pm := s.party_menu
	var want: Array[Color] = [Color("9ceddb"), Color("1f2861"), Color("1f2861")]
	await kit.press_key(KEY_P)
	var got := {}
	for st in [["상태", KEY_2, pm.status_tab.top], ["스킬", KEY_4, pm.skill_tab.top], ["장비", KEY_3, pm.equip_tab.top]]:
		await kit.press_key(st[1])
		await kit.press_key(KEY_ENTER)
		await kit.frames(2)
		var top: MemberHeader = st[2]
		check(top.is_visible_in_tree() and not top.drawn.is_empty(), "%s: 위 줄을 그렸다" % st[0])
		var c: Array = top.drawn["colors"]
		got[st[0]] = c
		check_eq(c.slice(0, 3), want, "%s: 이름 탭 #9CEDDB · 이름 남색 · Lv 띠 #1F2861" % st[0])
		check(contrast(c[1], c[0]) >= 4.5, "%s: 이름 글자 대비 %.2f" % [st[0], contrast(c[1], c[0])])
		check(contrast(UiTheme.ST_LV_TEXT, c[2]) >= 4.5, "%s: Lv 글자 대비" % st[0])
		for bg in [c[3], c[4]]:
			for fg in [MemberHeader.STRIP_TEXT, MemberHeader.STRIP_LABEL, MemberHeader.STRIP_ACCENT]:
				check(contrast(fg, bg) >= 4.5, "%s: 띠 글자 %s on %s = %.2f" % [st[0], (fg as Color).to_html(false), (bg as Color).to_html(false), contrast(fg, bg)])
			# 띠는 원작 #127FAD 근사(대비를 위해 조금 어둡게): 색상·채도는 거의 같고 밝기만 낮다.
			check(absf(bg.h - Color("127fad").h) < 0.02 and bg.v <= Color("127fad").v and bg.v >= Color("127fad").v * 0.8, "%s: 띠 %s 는 #127FAD 근사" % [st[0], bg.to_html(false)])
		await kit.press_key(KEY_ESCAPE)
	check(got["상태"] == got["스킬"] and got["스킬"] == got["장비"], "세 화면 띠 색이 한 벌")
	check_eq(pm.skill_tab._note_label.get_theme_color("font_color"), MemberHeader.STRIP_ACCENT, "스킬 띠 안내 글자 = 띠 노랑(대비 4.5:1)")
	check_eq(pm.equip_tab.note_label.get_theme_color("font_color"), MemberHeader.STRIP_ACCENT, "장비 띠 안내 글자 = 띠 노랑(대비 4.5:1)")


## 하위 화면 tab 의 띠 글(알림이 없을 때): 소지품은 「소지품   장비 n · 소재 n」(E2-b), 기록이 아닌 다른 화면은 없음("").
static func _strip_of(s: DungeonScreen, t: int) -> String:
	return s.party_menu.items_tab.caption() if t == 3 else ""


## 기록의 띠(07 §9.9 E1 ⑥)가 숫자 키로 바로 바꾼 화면에서도 맞다: 기록·소지품에서는 늘 보이고(알림 또는 화면 글), 다른 하위 화면에서는 감춘다.
func _check_strip(s: DungeonScreen, want: String, tag: String) -> void:
	var pm := s.party_menu
	await kit.frames(1)
	var on := not want.is_empty()
	check_eq([pm.notice_line.is_visible_in_tree(), s.debug_snapshot()["party_menu"]["strip"]], [on, want], tag + ": 띠 보임·글")
	check_eq([pm.camp_plate.is_visible_in_tree(), pm.ribbon.is_visible_in_tree(), pm.money_plate.is_visible_in_tree()], [on, on, on],
		tag + ": 맨 위 띠(걸음·장소·소지금)는 기록에서만")


func test_records_strip_follows_direct_tab_changes() -> void:
	var s := await _open()
	var pm := s.party_menu
	var caption := s.texts.t("camp.cmd.records")
	GrowthRules.grant_exp(s.state, 0, s.state.defs.battle.growth.cum(3))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.page, pm.tab], ["sub", 0], "준비: 상태")
	# 기록으로 들어가기(1 소지품 · 2 상태 · 3 장비 · 4 스킬 → 5) 와 나가기(5 → 각 화면).
	for k in [[KEY_2, 0, "상태"], [KEY_4, 1, "스킬"], [KEY_3, 2, "장비"], [KEY_1, 3, "소지품"]]:
		await kit.press_key(k[0])
		check_eq([pm.page, pm.tab], ["sub", k[1]], "%s 화면" % k[2])
		await _check_strip(s, _strip_of(s, k[1]), "기록 → %s" % k[2])
		await kit.press_key(KEY_5)
		check_eq(pm.tab, 4, "%s → 5 → 기록" % k[2])
		await _check_strip(s, caption, "%s → 기록" % k[2])
	# 뿌리에서 연 기록(띠가 보이는 채) → 숫자 키로 각 화면: 띠·맨 위 띠를 감춘다.
	for k in [[KEY_2, 0, "상태"], [KEY_4, 1, "스킬"], [KEY_3, 2, "장비"], [KEY_1, 3, "소지품"]]:
		await kit.press_key(KEY_ESCAPE)
		await kit.press_key(KEY_5)
		check_eq([pm.page, pm.tab], ["sub", 4], "뿌리 → 5 → 기록")
		await _check_strip(s, caption, "뿌리 → 기록")
		await kit.press_key(k[0])
		check_eq(pm.tab, k[1], "기록 → %s" % k[2])
		await _check_strip(s, _strip_of(s, k[1]), "뿌리에서 연 기록 → %s" % k[2])
	# 살아 있는 알림은 화면을 바꿔도 지우지 않는다(알림 규칙 그대로): 상태에서 뜬 알림이 기록 띠에, 기록에서 뜬 알림은 상태에서 감춰졌다가 돌아오면 다시.
	await kit.press_key(KEY_2)
	pm.show_notice("시험 안내 A")
	await kit.press_key(KEY_5)
	await _check_strip(s, "시험 안내 A", "상태에서 뜬 알림 → 기록 띠")
	await kit.press_key(KEY_4)
	await _check_strip(s, "", "기록 → 스킬(알림 중)")
	check(pm.notice == "시험 안내 A" and pm.skill_tab._note_label.text == "시험 안내 A", "알림은 남아 스킬 띠에 보인다")
	await kit.press_key(KEY_5)
	await _check_strip(s, "시험 안내 A", "스킬 → 기록(알림 중)")
	pm._clear_notice()
	await _check_strip(s, caption, "알림이 지나면 「기록」")
	# 초안 → 5 → 버리기 창 → 「버리기」 → 기록(띠 「기록」).
	await kit.press_key(KEY_4)
	await kit.tap(kit.center_of(pm.skill_tab.plus_button))
	check(pm.skill_tab.has_draft(), "준비: 초안")
	await kit.press_key(KEY_5)
	check_eq([pm.dialog_kind, pm.tab], ["discard", 1], "5 → 버리기 창(아직 스킬)")
	await _check_strip(s, "", "버리기 창(스킬 위)")
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	check_eq([pm.dialog_kind, pm.tab, pm.skill_tab.has_draft()], ["", 4, false], "「버리기」 → 기록")
	await _check_strip(s, caption, "버리기 뒤 기록")
	# 기록 → Esc → 뿌리: 알림이 없으면 알림 줄은 감추고, 맨 위 띠는 보인다.
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(1)
	check_eq([pm.page, pm.notice_line.is_visible_in_tree(), pm.ribbon.is_visible_in_tree()], ["root", false, true], "뿌리: 알림 줄 없음, 장소 띠 보임")


## 「바꾸면」 값(장비 화면 E2-c 가 쓸 SheetParts API, research 08 §5.1 「攻撃 ↑ 23」): 값 칸에 새 값만 오른쪽 맞춤, 왼쪽에 ↑·↓(모양 높이 14 이상),
## 「999」가 화살표 옆에 든다. 능력치 줄과 공격·방어 칸, dir −1 · 0 · +1. 그리는 호출의 기록을 본다.
func test_sheet_after_values_show_the_new_value_beside_a_readable_arrow() -> void:
	kit = Kit.new(tree)
	var host := Control.new()
	host.size = Vector2(500, 200)
	tree.root.add_child(host)
	var stat_r := Rect2(66, 20, 319, 28)
	var gear_r := Rect2(66, 80, 374, 34)
	var cases := [[0, "18", "", "18"], [1, "25", "28", "28"], [-1, "10", "8", "8"], [1, "99", "999", "999"], [-1, "999", "998", "998"]]
	for cs in cases:
		var dir: int = cs[0]
		host.draw.connect(func() -> void:
			SheetParts.begin(host)
			SheetParts.draw_stat_row(host, stat_r, "힘", cs[1], 0.5, cs[2], dir)
			SheetParts.draw_gear_row(host, gear_r, [["공격", cs[1], cs[2] if not str(cs[2]).is_empty() else null, dir], ["방어", "5"]]),
			CONNECT_ONE_SHOT)
		host.queue_redraw()
		await kit.frames(2)
		var tag := "dir %d, %s → %s" % [dir, cs[1], cs[2]]
		var col := SheetParts.STAT_TEXT if dir == 0 else (SheetParts.UP_COLOR if dir > 0 else SheetParts.DOWN_COLOR)
		var boxes := [[SheetParts.stat_boxes(stat_r)["value"], SheetParts.STAT_VALUE_FS, "능력치"],
			[SheetParts.gear_cells(gear_r)[0]["value"], SheetParts.GEAR_VALUE_FS, "공격"]]
		for bx in boxes:
			var vb: Rect2 = bx[0]
			var fs: int = bx[1]
			var texts := _drawn_entries(host, "text").filter(func(e: Dictionary) -> bool: return vb.grow(0.5).has_point(e["rect"].position + Vector2(1, fs * 0.8)))
			check_eq(texts.map(func(e: Dictionary) -> String: return e["text"]), [cs[3]], "%s %s: 값 칸에는 새 값만" % [tag, bx[2]])
			if texts.size() != 1:
				continue
			var tx: Dictionary = texts[0]
			check_eq(tx["color"], col, "%s %s: 값 색" % [tag, bx[2]])
			check(is_equal_approx(tx["rect"].end.x, vb.end.x - SheetParts.TEXT_PAD), "%s %s: 오른쪽 맞춤(값 칸 오른쪽 − 8)" % [tag, bx[2]])
			var room := SheetParts.value_room(vb, dir)
			check(is_equal_approx(tx["rect"].size.x, room) and SheetParts.text_width(host, "999", fs) <= room,
				"%s %s: 「999」(%.0f) 가 화살표 옆 자리 %.0f 에 든다" % [tag, bx[2], SheetParts.text_width(host, "999", fs), room])
			var icons := _drawn_entries(host, "icon").filter(func(e: Dictionary) -> bool: return vb.encloses(e["rect"]))
			if dir == 0:
				check_eq(icons.size(), 0, "%s %s: 화살표 없음" % [tag, bx[2]])
				continue
			check(icons.size() == 1 and icons[0]["name"] == ("up" if dir > 0 else "down") and icons[0]["color"] == col, "%s %s: 화살표 %s" % [tag, bx[2], str(icons)])
			if icons.size() != 1:
				continue
			var ar: Rect2 = icons[0]["rect"]
			check(ar.size.y * SheetParts.ARROW_GLYPH >= 14.0, "%s %s: 화살 모양 높이 %.1f ≥ 14" % [tag, bx[2], ar.size.y * SheetParts.ARROW_GLYPH])
			check(ar.position.x < vb.position.x + 10.0 and ar.end.x <= tx["rect"].position.x + 0.5, "%s %s: 화살표는 값 칸 왼쪽, 값 글 자리 앞" % [tag, bx[2]])
	host.queue_free()
	await kit.frames(1)


## 받는 배율 줄이 앞으로 자료가 바뀌어도 잘리지 않는다(07 §9.9 E2-a 고침, 조정자 결정): 갈래마다 자료(직업 기본값·장비 보정)에서 보통이 아닐 수 있는
## 항목 수 n 과 가장 넓은 항목 글(값 범위 끝 −100%·+200%)로, n × 가장 넓은 것 + (n − 1) × 사이 가 12px 로 문패 안 폭에 든다.
func test_received_lines_fit_for_any_data_combination() -> void:
	var s := await _open()
	var pm := s.party_menu
	var defs := s.state.defs
	var t := s.texts
	var c: Control = pm.status_tab.left
	var room := PartyStatusTab.SIDE_W - 2.0 * PartyStatusTab.SIDE_TEXT_PAD
	var lo := (BattleLimits.RANGES["resist"][0] - 1000) / 10
	var hi := (BattleLimits.RANGES["resist"][1] - 1000) / 10
	for pair in PartyStatusTab.RECEIVED:
		var cat: String = pair[0]
		var keys := {}
		for cid in defs.battle.class_ids:
			var cl: BattleDb.ClassDef = defs.battle.classes[cid]
			var base: Dictionary = cl.get(cat)
			for k in base:
				if int(base[k]) != 1000:
					keys[k] = true
		for id in defs.battle.equipment_ids:
			var e := defs.battle.equip(id)
			var d: Dictionary = e.get(cat)
			for k in d:
				if int(d[k]) != 0:
					keys[k] = true
		var widest := 0.0
		for k in keys:
			for pct in [lo, hi]:
				var entry := t.t("party.mult", {"name": t.t(pair[1] + k), "pct": PartyMenu.signed(pct)})
				widest = maxf(widest, SheetParts.text_width(c, entry, PartyStatusTab.SIDE_FS_MIN))
		var n := keys.size()
		var bound := n * widest + maxi(0, n - 1) * SheetParts.text_width(c, "  ", PartyStatusTab.SIDE_FS_MIN)
		check(bound <= room, "%s: 항목 %d 개(%s), 가장 넓은 %.0f → 최악 폭 %.0f ≤ %.0f(12px)" % [cat, n, str(keys.keys()), widest, bound, room])
