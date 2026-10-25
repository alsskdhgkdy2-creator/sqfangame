## M2.6 2.5단계 층 겹침 다시 배치(00 D21, docs/research/04) 시험: 층 표대로 놓였는지, 겹친 곳을 누르면 보이는 위 칸이 받는지,
## z_index 를 쓰지 않는지, 반투명 채움 위 글자 대비, 누르는 칸 크기, 대상 고르기 중 적 칸을 가리는 창이 없는지.
## 창 크기는 실제 창(1280×720, 2400×1000)으로 바꿔 늘이기 규칙(논리 1280×720, 1728×720)까지 그대로 본다.
## 저장은 장면 시험 임시 폴더에만 쓴다. 결과는 구성으로 정한다(D15).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const RATS_MOTH := "formation.f1.rats_moth"
const LEG_CUTTER := "skill.blade_duelist.leg_cutter"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
## 겹침 누르기에 쓰는 손가락 번호(0 이 아니면 흉내 마우스가 생기지 않는다).
const FINGER := 3

var kit: Kit
var host: Control
var layer: BattleLayer
var texts: TextDb
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


func _kit() -> void:
	timeout_sec = 60.0
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


## 전투 층만 논리 크기 화면에 띄운다. s 가 없으면 끝날 수 없는 편성(적은 아무것도 하지 않고 나방은 쓰러지지 않는다).
func _layer(px: Vector2, s: ExplorationState = null, speed: float = 0.0) -> BattleLayer:
	var size: Vector2 = await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "RelayoutHost"
	host.position = Vector2.ZERO
	host.size = size
	tree.root.add_child(host)
	if s == null:
		s = Fx.battle(Fx.quiet_defs({}, ["enemy.cable_moth"]), RATS_MOTH, 5)
	layer = BattleLayer.new()
	host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = speed
	layer.save_hook = func() -> void: pass
	layer.open(s)
	await kit.frames(2)
	return layer


func _step(kind: String, arg: Variant = null) -> bool:
	var ok := layer.handle(kind, arg)
	await kit.frames(1)
	return ok


## 화면(논리) 좌표의 사각형.
static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


static func _under(c: Node, n: Node) -> bool:
	return n != null and (c == n or c.is_ancestor_of(n))


## 논리 좌표 p 를 손가락으로 누를 때 처음 받는 컨트롤(엔진이 실제로 고르는 것: research 04 — 트리 뒤의 것부터,
## IGNORE 는 건너뛴다). 뗄 때는 창 밖에서 떼어 받은 단추가 일을 하지 않게 한다.
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
	var win := tree.root.get_final_transform() * p
	kit.touch(FINGER, win, true)
	kit.touch(FINGER, Vector2(-500, -500), false)
	await kit.frames(1)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Control).gui_input.is_connected(h[1]):
			(h[0] as Control).gui_input.disconnect(h[1])
	return got[0] if not got.is_empty() else null


static func _name_of(c: Control) -> String:
	return "없음" if c == null else str(c.get_path())


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ---- 층 표 ----

## M2.7 R3: 원작 HD 1868180_0e36b17e 배치(1280×720 기준 값, 앵커로 붙어 1728×720 에서도 같은 규칙).
func test_battle_layers_follow_the_table_at_both_sizes() -> void:
	for px in WINDOWS:
		await _layer(px, null, 1.0)
		var s := layer.size
		var tag := "%s(논리 %s)" % [str(px), str(s)]
		# 트리 순서 = 그리는 순서 = 누르는 순서.
		var order := [layer.enemy_area, layer.party_cards, layer.minimap, layer.portrait, layer.panel, layer.log_button, layer.log_view,
			layer.result_panel, layer.dir_pad, layer.key_pad, layer.skip_catcher]
		for i in order.size() - 1:
			check((order[i] as Node).get_index() < (order[i + 1] as Node).get_index(), "%s: %s 는 %s 아래" % [tag, order[i].name, order[i + 1].name])
		for c in [layer.enemy_area, layer.enemy_area.hp_tag, layer.party_cards, layer.minimap, layer.portrait, layer._result_title, layer.dir_pad, layer.key_pad]:
			check((c as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: 장식 %s 은 누르기를 받지 않는다" % [tag, c.name])
		# 위: 턴 문패(왼쪽 위) · 메시지 띠(x 193 → 오른쪽 끝, y 0~100) · 로그 단추(띠 안 오른쪽 끝, 사용자 결정 2026-10-25).
		var plate := layer.turn_plate_rect()
		check(plate.position.x > 0.0 and plate.position.y > 0.0 and plate.end.x <= BattleLayer.BANNER_X and plate.end.y <= BattleLayer.BANNER_H,
			"%s: 턴 문패 %s 는 띠 왼쪽" % [tag, str(plate)])
		check_eq(layer.banner_rect(), Rect2(193, 0, s.x - 193, 100), tag + ": 메시지 띠")
		var lb := _rect(layer.log_button)
		check_eq(lb, Rect2(s.x - 128, 18, 120, 64), tag + ": 로그 단추(띠 안 오른쪽 끝, 띠 높이 가운데)")
		check(layer.banner_rect().encloses(lb) and not lb.intersects(plate), tag + ": 로그 단추는 띠 안")
		# 왼쪽: 띠 바로 아래 초상(x 0~180) + 아래 TP 게이지(x 0~267), 초상 오른쪽 명령 목록(x 170~493).
		check_eq(_rect(layer.portrait), Rect2(0, 108, 267, 397), tag + ": 초상 + TP 게이지")
		check_eq(_rect(layer.panel), Rect2(170, 108, 323, 356), tag + ": 명령 목록")
		# 적 영역: 명령 목록 오른쪽 ~ 미니맵 열 왼쪽, 띠(100)와 파티 카드 위(548) 사이 가운데.
		var er := _rect(layer.enemy_area)
		check_eq(er, Rect2(500, 150, s.x - 500 - 255, EnemyArea.FRONT_TOP + EnemyArea.FRONT_SIZE), tag + ": 적 영역")
		check_eq(er.position.y - 100.0, s.y - 172.0 - er.end.y, tag + ": 적 영역은 띠와 카드 사이 가운데")
		# 가상 방향키(왼쪽 아래, TP 게이지 아래)·선택/취소(미니맵 위, 미니맵과 같은 x).
		check_eq(_rect(layer.dir_pad), Rect2(8, s.y - 209, 200, 200), tag + ": 방향키 묶음")
		var want_dirs := {"up": Rect2(76, s.y - 209, 64, 64), "left": Rect2(8, s.y - 141, 64, 64), "right": Rect2(144, s.y - 141, 64, 64),
			"down": Rect2(76, s.y - 73, 64, 64)}
		for k in want_dirs:
			check_eq(_rect(layer.dir_pad.button(k)), want_dirs[k], "%s: 방향 %s" % [tag, k])
		check_eq(_rect(layer.key_pad), Rect2(s.x - 247, s.y - 293, 227, 72), tag + ": 선택·취소 묶음")
		check_eq(_rect(layer.key_pad.button("back")), Rect2(s.x - 247, s.y - 293, 110, 72), tag + ": 취소(왼쪽)")
		check_eq(_rect(layer.key_pad.button("ok")), Rect2(s.x - 130, s.y - 293, 110, 72), tag + ": 선택(오른쪽)")
		var tp_gauge := _rect(layer.portrait)
		var pads: Array[Rect2] = []
		for vp in [layer.dir_pad, layer.key_pad]:
			for k in vp.buttons:
				var r := _rect(vp.buttons[k])
				pads.append(r)
				check(r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s 64×64 이상" % [tag, vp.buttons[k].name])
				check(Rect2(Vector2.ZERO, s).encloses(r), "%s: %s 화면 안" % [tag, vp.buttons[k].name])
				for other in [["TP 게이지", tp_gauge], ["명령 목록", _rect(layer.panel)], ["적 영역", er], ["미니맵", _rect(layer.minimap)],
						["로그 창", _rect(layer.log_view)], ["메시지 띠", layer.banner_rect()]]:
					check(not r.intersects(other[1]), "%s: %s 는 %s 와 겹치지 않는다" % [tag, vp.buttons[k].name, other[0]])
				for c in layer.party_cards.cards:
					check(not r.intersects(_rect(c)), "%s: %s 는 카드 %s 와 겹치지 않는다" % [tag, vp.buttons[k].name, c.name])
		var toast := Rect2(BattleLayer.TOAST_LEFT, BattleLayer.TOAST_Y, s.x - BattleLayer.TOAST_RIGHT - BattleLayer.TOAST_LEFT, BattleLayer.TOAST_H)
		for other in [["적 영역", er], ["명령 목록", _rect(layer.panel)], ["로그 단추", lb], ["메시지 띠", layer.banner_rect()]]:
			check(not toast.intersects(other[1]), "%s: 전투 알림 줄 %s 은 %s 와 겹치지 않는다" % [tag, str(toast), other[0]])
		for p in pads:
			check(not toast.intersects(p), "%s: 전투 알림 줄은 키패드와 겹치지 않는다" % tag)
		# 오른쪽 아래 미니맵(원작 x 1033~1260, y 507~667).
		check_eq(_rect(layer.minimap), Rect2(s.x - 247, s.y - 213, 227, 160), tag + ": 미니맵")
		check(layer.minimap.is_visible_in_tree() and layer.minimap.is_mini, tag + ": 전투 중 미니맵이 보인다")
		# 아래 가운데 파티 카드 두 줄: 윗줄 = 편성 전열 셋, 아랫줄 = 후열 둘, 줄마다 가운데, 겹치지 않는다.
		var pc := layer.party_cards
		var cards: Array[Rect2] = []
		for c in pc.cards:
			cards.append(_rect(c))
		var top_y := s.y - 8.0 - 80.0 - 4.0 - 80.0
		for i in cards.size():
			check_eq(cards[i].size, Vector2(233, 80), "%s: 카드 %d 크기" % [tag, i])
			check_eq(cards[i].position.y, top_y if i < 3 else s.y - 88.0, "%s: 카드 %d 줄(전열 = 윗줄)" % [tag, i])
			for j in i:
				check(not cards[i].intersects(cards[j]), "%s: 카드 %d·%d 겹치지 않는다" % [tag, j, i])
		check(absf((cards[0].position.x + cards[2].end.x) / 2.0 - s.x / 2.0) <= 1.0, tag + ": 윗줄 가운데")
		check(absf((cards[3].position.x + cards[4].end.x) / 2.0 - s.x / 2.0) <= 1.0, tag + ": 아랫줄 가운데(엇갈림)")
		check(er.end.y <= cards[0].position.y, tag + ": 적 영역은 카드 위")
		check(_rect(layer.panel).end.y <= cards[0].position.y and _rect(layer.portrait).end.x <= cards[0].position.x, tag + ": 목록·초상은 카드와 겹치지 않는다")
		# 적 자리는 명령·대상·연출 사이에 그대로다(결과 창까지는 test_battle_layout).
		var at_command := _enemy_rects()
		await _step("command", 0)
		check_eq(layer.sub, "target", tag + ": 대상 고르기")
		check_eq(_enemy_rects(), at_command, tag + ": 대상 고르기 중 적 자리 그대로")
		await _step("back")
		var cmds := []
		for i in 5:
			cmds.append({"kind": "guard"})
		await _step("commands", cmds)
		check_eq(layer.phase, "anim", tag + ": 연출")
		check_eq(_enemy_rects(), at_command, tag + ": 연출 중 적 자리 그대로")
		check(not layer.banner_text().is_empty() and layer.banner_lines()[0] == layer.banner_text(), tag + ": 연출 중 띠 글")


func _enemy_rects() -> Array:
	var out := []
	for i in layer.display.enemies.size():
		out.append(_rect(layer.enemy_area.card(i)))
	return out


# ---- 겹친 곳 누르기 ----

## 듀얼리스트 A 스킬 여섯(목록이 넘쳐 끌어 내리는 상태).
func _six_skills(px: Vector2) -> void:
	await _layer(px)
	var u := layer.state.battle.party[1]
	for sid in [LEG_CUTTER, "skill.blade_duelist.quick_draw", "skill.glyph_wizard.heat_glyph"]:
		u.skills[sid] = 1  # 구성: 스킬 여섯
	await _step("command", 0)
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	await _step("command", 1)
	check_eq([layer.sub, layer._skill_ids().size()], ["skills", 6], "준비: 스킬 여섯")


## 가상 키패드(사용자 제안 2026-10-25): 보이는 단추가 받고, 묶음의 빈 곳(십자 가운데·선택/취소 사이)은 바탕이 받는다.
## 연출 중에는 넘기기 받개가 위라 키패드 자리도 받개가 받는다.
func test_virtual_pad_taps_reach_the_visible_button() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _layer(px, null, 1.0)
		for vp in [layer.dir_pad, layer.key_pad]:
			for k in vp.buttons:
				var b: TouchButton = vp.buttons[k]
				var got := await _receiver_at(_rect(b).get_center())
				check(got == b, "%s: %s 자리 → 그 단추, 실제 %s" % [tag, b.name, _name_of(got)])
		var hub := await _receiver_at(_rect(layer.dir_pad).get_center())
		check(hub == layer, "%s: 십자 가운데 → 바탕, 실제 %s" % [tag, _name_of(hub)])
		var kr := _rect(layer.key_pad)
		var gap := await _receiver_at(Vector2(kr.position.x + VirtualPad.KEY.x + VirtualPad.KEY_GAP / 2.0, kr.get_center().y))
		check(gap == layer, "%s: 선택·취소 사이 → 바탕, 실제 %s" % [tag, _name_of(gap)])
		var cmds := []
		for i in 5:
			cmds.append({"kind": "guard"})
		await _step("commands", cmds)
		check_eq(layer.phase, "anim", tag + ": 연출")
		var on_pad := await _receiver_at(_rect(layer.key_pad.button("ok")).get_center())
		check(on_pad == layer.skip_catcher, "%s: 연출 중 선택 자리 → 넘기기 받개, 실제 %s" % [tag, _name_of(on_pad)])


func test_overlapping_taps_reach_the_visible_top_element_in_battle() -> void:
	for px in WINDOWS:
		var tag := str(px)
		# ① 명령 목록 ∩ 초상(목록이 초상 오른쪽 끝을 덮는다): 목록(위)이 받는다.
		await _six_skills(px)
		var ov := _rect(layer.panel).intersection(_rect(layer.portrait))
		check(ov.has_area(), "%s: 명령 목록이 초상 오른쪽 끝을 덮는다 %s" % [tag, str(ov)])
		var on_list := await _receiver_at(ov.get_center())
		check(_under(layer.panel, on_list), "%s: 목록과 초상이 겹친 곳 → 명령 목록, 실제 %s" % [tag, _name_of(on_list)])
		for b in layer.visible_buttons():
			for c in layer.party_cards.cards:
				if b != c and not layer.party_cards.is_ancestor_of(b):
					check(not _rect(b).intersects(_rect(c)), "%s: 단추 %s 는 카드 %s 와 겹치지 않는다" % [tag, b.name, c.name])
		# ② 장식(메시지 띠·턴 문패·초상·미니맵)은 누르기를 받지 않는다: 뒤에 누를 것이 없으면 바탕(층)이 받는다.
		var spots := {"메시지 띠": layer.banner_rect().get_center(), "턴 문패": layer.turn_plate_rect().get_center(),
			"초상": _rect(layer.portrait).position + Vector2(60, 120), "미니맵": _rect(layer.minimap).get_center()}
		for k in spots:
			var at := await _receiver_at(spots[k])
			check(at == layer, "%s: %s → 바탕, 실제 %s" % [tag, k, _name_of(at)])
		# ③ 대상 고르기: 적 위 HP 표(장식)와 그 아래 칸 — 표 자리를 눌러도 뒤의 적 칸·바탕이 받는다(표가 가로채지 않는다).
		await _step("back")
		await _step("back")
		await _step("command", 0)
		var tr := layer.enemy_area.tag_rect()
		check(tr.has_area(), tag + ": 대상 고르기 중 HP 표")
		tr.position += layer.enemy_area.global_position
		var on_tag := await _receiver_at(tr.get_center())
		check(on_tag == layer or on_tag is BattleCard, "%s: HP 표 자리 → 바탕·적 칸, 실제 %s" % [tag, _name_of(on_tag)])
		# ④ 결과 창 ∩ 대원 카드: 결과 창이 받는다.
		var s := Fx.battle(Fx.quiet_defs(Fx.EXACT), "formation.f1.rats", 4)
		for u in s.battle.enemies:
			u.hp = 1
		for m in s.party.members:
			m.exp = s.defs.battle.growth.cum(2) - 1  # 구성: 모두 레벨 업(결과 창이 길어져 카드 위로 내려온다)
		await _layer(px, s)
		await _step("commands", [{"kind": "attack", "target": 0}, {"kind": "attack", "target": 1}, {"kind": "attack", "target": 2},
			{"kind": "guard"}, {"kind": "guard"}])
		check_eq(layer.phase, "result", tag + ": 결과 창")
		var rr := _rect(layer.result_panel)
		var covered := 0
		for c in layer.party_cards.cards:
			var o := rr.intersection(_rect(c))
			if o.has_area():
				covered += 1
				var got := await _receiver_at(o.get_center())
				check(_under(layer.result_panel, got), "%s: 결과 창과 %s 이 겹친 곳 → 결과 창, 실제 %s" % [tag, c.name, _name_of(got)])
		check(covered > 0, "%s: 긴 결과 창이 카드 위에 겹친다(겹침 %d)" % [tag, covered])
		var tp := _rect(layer._result_title)
		check(tp.position.y < rr.position.y and tp.end.y > rr.position.y, "%s: 결과 제목 문패는 창 위 가장자리에 걸친다" % tag)
		var on_title := await _receiver_at(Vector2(tp.get_center().x, rr.position.y + 6.0))
		check(_under(layer.result_panel, on_title), "%s: 제목 문패 아래 절반 → 결과 창, 실제 %s" % [tag, _name_of(on_title)])


func test_overlapping_taps_reach_the_visible_top_element_in_menus() -> void:
	_kit()
	var s := await kit.open("native", 7)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		# ⑤ 캠프 장비·소지품(M2.7 R2-c, 상점 짜임): 보이는 맨 위가 받는다. 창·띠·문패·인물 판은 장식이라 그 빈 곳은 캠프가 받는다
		# (뒤 탐색 화면에 닿지 않는다). 캠프 → 장비 → 칸 0 대원.
		await kit.press_key(KEY_P)
		await kit.press_key(KEY_3)
		await kit.press_key(KEY_ENTER)
		var pm := s.party_menu
		check(pm.is_open() and pm.tab == 2 and pm.find_child("Tab_status", false, false) == null, tag + ": 장비 화면(앞 파티 메뉴 틀 없음)")
		var et := pm.equip_tab
		var f := et.frame
		var pr := _rect(f.panel)
		var lw := _rect(f.list_window)
		var spots := [
			["칸 0", _rect(et.slot_rows[0]).get_center(), et.slot_rows[0]],
			["뒤로", _rect(f.back_button).get_center(), f.back_button],
			["앞 대원", _rect(f.panel.prev_button()).get_center(), f.panel.prev_button()],
			["다음 대원", _rect(f.panel.next_button()).get_center(), f.panel.next_button()],
			["목록 창 빈 곳", Vector2(lw.get_center().x, lw.end.y - 8.0), pm],
			["설명 창", _rect(f.desc_window).get_center(), pm],
			["설명 띠", _rect(f.banner).get_center(), pm],
			["화면 이름 문패", _rect(f.title_plate).get_center(), pm],
			["인물 판 초상", pr.position + Vector2(pr.size.x - 40.0, 500.0), pm],
			["인물 판 장비 줄", pr.position + f.panel.equip_rect(0).get_center(), pm],
		]
		for sp in spots:
			var got := await _receiver_at(sp[1])
			check(got == sp[2], "%s 장비: %s → %s, 실제 %s" % [tag, sp[0], _name_of(sp[2]), _name_of(got)])
		await kit.press_key(KEY_ESCAPE)
		await kit.press_key(KEY_4)
		check(pm.tab == 3, tag + ": 소지품 화면")
		var it := pm.items_tab
		var iw := _rect(it.frame.list_window)
		var on_list := await _receiver_at(Vector2(iw.get_center().x, iw.position.y + 60.0))
		check(_under(it.list, on_list), "%s 소지품: 읽기만 하는 줄 → 목록(끌어 내리기), 실제 %s" % [tag, _name_of(on_list)])
		var on_panel := await _receiver_at(_rect(it.frame.panel).position + Vector2(400.0, 500.0))
		check(on_panel == pm, "%s 소지품: 인물 판 → 캠프, 실제 %s" % [tag, _name_of(on_panel)])
		for k in 3:
			if pm.is_open():
				await kit.press_key(KEY_ESCAPE)
				await kit.frames(2)
		check(not pm.is_open(), tag + ": 파티 메뉴 닫힘")
		# ⑥ 층 3 창(알림 창; 메뉴 창은 R2-d 에서 캠프 「기록」으로 옮겼다) 제목 문패 ∩ 창: 창이 받는다(문패는 장식).
		# 창 밖 절반은 어둡게 덮은 판이 받는다.
		s._alert("시험 알림")
		await kit.frames(3)
		var m := s.modal
		var panel := _rect(m._panel)
		var tr := _rect(m.title_plate)
		check(tr.position.y < panel.position.y and tr.end.y > panel.position.y, "%s: 메뉴 제목 문패는 창 위 가장자리에 걸친다 %s / %s" % [tag, str(tr), str(panel)])
		check(absf(tr.get_center().x - panel.get_center().x) <= 1.0, tag + ": 제목 문패는 가운데")
		var in_half := await _receiver_at(Vector2(tr.get_center().x, panel.position.y + 6.0))
		check(_under(m._panel, in_half), "%s: 제목 문패 아래 절반 → 메뉴 창, 실제 %s" % [tag, _name_of(in_half)])
		var out_half := await _receiver_at(Vector2(tr.get_center().x, panel.position.y - 6.0))
		check(out_half != null and _under(m, out_half) and not _under(m._panel, out_half), "%s: 제목 문패 위 절반 → 어둡게 덮은 판, 실제 %s" % [tag, _name_of(out_half)])
		m.close()
		await kit.frames(2)


# ---- z_index ----

func test_no_control_relies_on_z_index() -> void:
	# 코드: z_index·z_as_relative·top_level 을 쓰지 않는다(주석은 뺀다). 누르는 칸의 위아래는 트리 순서로만 정한다.
	# 나중에 누르지 않는 장식(IGNORE)에 z_index 가 꼭 필요하면 그 파일만 여기서 따로 허락한다(research 04 원칙 5).
	var files: Array[String] = []
	_gd_files("res://src", files)
	check(files.size() > 20, "src 스크립트 %d개" % files.size())
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var code := lines[n].split("#")[0]
			for word in ["z_index", "z_as_relative", "top_level"]:
				check(not code.contains(word), "%s:%d 에 %s" % [path, n + 1, word])
	# 실행 중: 탐색 화면·전투 층·파티 메뉴·메뉴 창을 띄운 트리의 모든 그리는 노드가 z 0, 상대 z.
	_kit()
	var s := await kit.open("native", 7)
	await kit.press_key(KEY_P)
	_check_z(tree.root, "캠프")
	await kit.press_key(KEY_5)
	_check_z(tree.root, "캠프 기록")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	s._alert("시험 알림")
	await kit.frames(2)
	_check_z(tree.root, "알림 창")
	s.modal.close()
	await _layer(Vector2(1280, 720))
	_check_z(host, "전투 층")


func _gd_files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_gd_files(dir + "/" + sub, out)


func _check_z(from: Node, tag: String) -> void:
	var bad: Array[String] = []
	for n in from.find_children("*", "CanvasItem", true, false):
		var ci := n as CanvasItem
		if ci.z_index != 0 or not ci.z_as_relative or ci.top_level:
			bad.append(str(ci.get_path()))
	check(bad.is_empty(), "%s: z_index 를 쓴 노드 %s" % [tag, str(bad)])


# ---- 반투명 채움 위 글자 대비 ----

## 반투명 채움은 가장 나쁜 바탕(흰색) 위에 겹친 색으로 본다(UiTheme.over_white).
func _check_on(fill_name: String, fills: Array, pairs: Dictionary) -> void:
	for k in pairs:
		var worst := 99.0
		for f in fills:
			worst = minf(worst, contrast(UiTheme.over_white(f), pairs[k]))
		check(worst >= 4.5, "%s 위 %s 대비 %.2f" % [fill_name, k, worst])


func test_text_on_translucent_fills_meets_contrast() -> void:
	var glass := UiTheme.look("glass")
	var fills := [glass["top"], glass["bottom"]]
	check(fills.all(func(c: Color) -> bool: return is_equal_approx(c.a, UiTheme.GLASS_ALPHA) and c.a < 1.0), "반투명 카드 채움 알파 %.2f" % UiTheme.GLASS_ALPHA)
	check(not UiTheme.STATES.has("glass"), "반투명 카드는 단추 상태가 아니다(불투명 채움 시험 밖)")
	# M2.7 R3: 전투 대원 카드는 불투명 청록 판이 되었다(대비는 test_battle_layout). 반투명 카드는 파티 메뉴 등에 남는다.
	var on_glass := {"흐린 글자": UiTheme.GLASS_DIM_TEXT, "전투 불능": UiTheme.GLASS_DOWN_TEXT, "머리 글자": UiTheme.HEAD_TEXT, "본문": UiTheme.TEXT}
	for role in UiTheme.TEXT_ROLES:
		on_glass["모양 " + role] = glass[role]
	_check_on("반투명 카드", fills, on_glass)
	_check_on("알림 띠", [UiTheme.BANNER_FILL], {"파티 메뉴 안내": PartyMenu.NOTICE_TEXT})
	_check_on("전투 메시지 띠", [UiTheme.BATTLE_BANNER_TOP, UiTheme.BATTLE_BANNER_BOTTOM], {"연출·물음 글": BattleLayer.ANNOUNCE_TEXT,
		"전투 안내": BattleLayer.NOTICE_TEXT})
	# 문패 채움은 불투명: 그 위 글자색(머리·본문).
	check(UiTheme.PLATE_TOP.a == 1.0 and UiTheme.PLATE_BOTTOM.a == 1.0, "문패 채움은 불투명")
	_check_on("문패", [UiTheme.PLATE_TOP, UiTheme.PLATE_BOTTOM], {"머리 글자": UiTheme.HEAD_TEXT, "본문 글자": UiTheme.TEXT})
	# 바탕을 어둡게 덮는 판은 글자 바탕이 아니다(그 위 글자는 모두 창·카드·문패·띠 위).
	check(UiTheme.BATTLE_DIM.a >= 0.4 and UiTheme.BATTLE_DIM.a <= 0.6, "전투 바탕 어둡게 약 50%%: %.2f" % UiTheme.BATTLE_DIM.a)


# ---- 누르는 칸 크기 ----

func _check_targets(bs: Array, tag: String) -> void:
	check(not bs.is_empty(), tag + ": 단추가 있다")
	for b in bs:
		var sz: Vector2 = (b as Control).size
		check(sz.x >= 64.0 and sz.y >= 64.0, "%s: %s 크기 %s" % [tag, b.name, str(sz)])


func test_touch_targets_stay_at_least_64() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _six_skills(px)
		_check_targets(layer.visible_buttons(), tag + " 스킬 목록")
		await _step("back")
		_check_targets(layer.visible_buttons(), tag + " 명령")
		await _step("command", 0)
		_check_targets(layer.visible_buttons(), tag + " 대상")
	_kit()
	var s := await kit.open("native", 7)
	for px in WINDOWS:
		var tag := str(px)
		await _window(px)
		for a in s.pad:
			check_eq((s.pad[a] as Control).size.y, DungeonScreen.PAD_BUTTON, "%s: 이동 단추 높이" % tag)
		for b in [s.camp_button, s.map_button]:
			check_eq((b as Control).size, Vector2(64, 64), "%s: 안내 줄 단추 %s" % [tag, b.name])
		await kit.press_key(KEY_P)
		var pm := s.party_menu
		_check_targets(pm.visible_buttons(), "%s 캠프 뿌리" % tag)
		pm.handle("camp", 0)
		await kit.frames(2)
		_check_targets(pm.visible_buttons(), "%s 대원 고르기" % tag)
		pm.handle("member", 0)
		await kit.frames(2)
		for i in PartyMenu.TAB_KEYS.size():
			pm.handle("tab", i)
			await kit.frames(2)
			_check_targets(pm.visible_buttons(), "%s 캠프 하위 화면 %s" % [tag, PartyMenu.TAB_KEYS[i]])
		pm.handle("record_new_game")
		await kit.frames(2)
		_check_targets(pm.visible_buttons(), "%s 기록 새 게임 확인 창" % tag)
		pm.handle("dialog_back")
		await kit.frames(2)
		check_eq(PartySkillTab.STEP_BUTTON, Vector2(96, 64), "스킬 +/- 단추")
		check_eq([PartyItemsTab.ROW_H, PartyEquipTab.ROW_H], [64.0, 64.0], "목록 줄 높이")
		for k in 3:
			if pm.is_open():
				await kit.press_key(KEY_ESCAPE)
				await kit.frames(2)


# ---- 대상 고르기 중 적 칸 ----

## 보이는 것(명령 목록, 초상, 로그 창, 결과 창, 메시지 띠·턴 문패·로그 단추, 대원 카드, 미니맵, 다른 적 위의 HP 표)이 고를 수 있는 적 칸을 가리지 않는다.
func _check_enemies_clear(tag: String) -> void:
	var windows := {}
	windows["명령 목록"] = _rect(layer.panel)
	if layer.portrait.visible:
		windows["초상"] = _rect(layer.portrait)
	if layer.log_view.visible:
		windows["로그 창"] = _rect(layer.log_view)
	if layer.result_panel.visible:
		windows["결과 창"] = _rect(layer.result_panel)
	windows["턴 문패"] = layer.turn_plate_rect()
	windows["메시지 띠"] = layer.banner_rect()
	windows["로그 단추"] = _rect(layer.log_button)
	windows["미니맵"] = _rect(layer.minimap)
	for c in layer.party_cards.cards:
		windows[str(c.name)] = _rect(c)
	var tr := layer.enemy_area.tag_rect()
	var tagged := layer.enemy_area.tagged()
	if tr.has_area():
		tr.position += layer.enemy_area.global_position
		tr.size.y += EnemyArea.TAG_TRI + 2.0
	var n := 0
	for i in layer.display.enemies.size():
		var e := layer.enemy_area.card(i)
		if not e.is_visible_in_tree() or e.target_mark.is_empty():
			continue
		n += 1
		var er := _rect(e)
		check(Rect2(Vector2.ZERO, layer.size).encloses(er), "%s: 적 %d 화면 안" % [tag, i])
		for k in windows:
			check(not er.intersects(windows[k]), "%s: 적 %d %s 를 %s %s 가 가린다" % [tag, i, str(er), k, str(windows[k])])
		if tr.has_area():
			check(not er.intersects(tr), "%s: 적 %d %s 를 HP 표 %s 가 가린다(표는 %s 위)" % [tag, i, str(er), str(tr), tagged.name])
	check(n > 0, "%s: 고를 수 있는 적이 있다(%d)" % [tag, n])


func test_enemy_cards_stay_uncovered_while_targetable() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _layer(px)
		await _step("command", 0)
		check_eq(layer.sub, "target", tag + ": 공격 대상")
		_check_enemies_clear(tag + " 공격 대상")
		await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
		await _step("command", 1)
		await _step("skill", HIGH_SLASH)
		check(layer.sub == "target" and layer.skill_info_shown(), tag + ": 스킬 대상(설명 띠가 보인다)")
		_check_enemies_clear(tag + " 스킬 대상")


# ---- 탐색: 지도 닫힘 (M2.7 R1: 기본 화면, 자세한 시험은 test_overlay_ui) ----

func test_closed_map_lets_the_view_fill_the_screen() -> void:
	_kit()
	var s := await kit.open("native", 7)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		check(not s._map_open, tag + ": 기본은 지도 닫힘")
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 3D 시야가 화면 전체")
		var mm := _rect(s.minimap)
		check(s.minimap.is_visible_in_tree() and mm.end.x <= size.x and mm.position.x > size.x * 0.5 and mm.position.y <= 16.0, "%s: 미니맵 %s 은 오른쪽 위" % [tag, str(mm)])
		check(not s.map_window.is_visible_in_tree(), tag + ": 지도 판 숨김")
		s._toggle_map()
		await kit.frames(3)
		check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 지도를 열어도 3D 시야는 화면 전체")
		check_eq(_rect(s.map_window), Rect2(size.x - MapWindow.WIDTH, 0, MapWindow.WIDTH, size.y), tag + ": 지도 판은 오른쪽 위에서 아래까지")
		s._toggle_map()
		await kit.frames(3)


# ---- 파티 메뉴 뒤 탐색 HUD ----

## 탐색 HUD(전투 중에 감추는 것과 같은 묶음: 지도 판·이동 단추·휴식·안내 줄 단추·층 문패·위험 보석).
## 미니맵은 지도 판이 열리면 따로 감추므로(원작) 이 묶음에 넣지 않는다.
static func _hud(s: DungeonScreen) -> Dictionary:
	var out := {"map": s.map_window, "camp": s.camp_button, "map_button": s.map_button,
		"floor": s.floor_plate, "orb": s.orb, "rest": s.rest_button}
	for a in s.pad:
		out["pad_%d" % int(a)] = s.pad[a]
	return out


static func _vis(s: DungeonScreen) -> Dictionary:
	var out := {}
	var hud := _hud(s)
	for k in hud:
		out[k] = (hud[k] as Control).visible
	return out


func _check_hidden(s: DungeonScreen, size: Vector2, tag: String) -> void:
	var hud := _hud(s)
	for k in hud:
		check(not (hud[k] as Control).is_visible_in_tree(), "%s: HUD %s 감춤" % [tag, k])
	check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 메뉴 뒤는 3D 시야 화면 전체")


func _check_restored(s: DungeonScreen, before: Dictionary, size: Vector2, tag: String) -> void:
	check(not s.party_menu.is_open(), tag + ": 파티 메뉴 닫힘")
	check_eq(_vis(s), before, tag + ": HUD 가 열기 전대로")
	check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, size), tag + ": 3D 시야는 화면 전체 그대로")


func _close_by_key(s: DungeonScreen) -> void:
	for k in 3:
		if s.party_menu.is_open():
			await kit.press_key(KEY_ESCAPE)
			await kit.frames(2)


func test_party_menu_hides_the_exploration_hud_and_restores_it() -> void:
	_kit()
	var s := await kit.open("native", 7)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		if not s._map_open:
			s._toggle_map()
			await kit.frames(3)
		var before := _vis(s)
		check(before.values().all(func(v: bool) -> bool: return v), "%s: 처음 HUD 가 모두 보인다(지도 열림, 시작 칸) %s" % [tag, str(before)])
		var spots := {}
		var hud := _hud(s)
		for k in hud:
			spots[k] = _rect(hud[k] as Control).get_center()
		var at := s.state.party.at
		var steps := s.state.steps
		# ① P 키로 열고 Esc 로 닫는다. 연 동안 감춘 HUD 자리는 파티 메뉴가 받는다(감춘 단추에 누르기가 닿지 않는다).
		await kit.press_key(KEY_P)
		check(s.party_menu.is_open(), tag + ": P → 파티 메뉴")
		_check_hidden(s, size, tag + " P")
		for k in spots:
			var got := await _receiver_at(spots[k])
			check(_under(s.party_menu, got), "%s: 감춘 %s 자리 → 파티 메뉴, 실제 %s" % [tag, k, _name_of(got)])
		await kit.tap(tree.root.get_final_transform() * spots["pad_%d" % int(ExplorationRules.Action.FORWARD)])
		check(s.state.party.at == at and s.state.steps == steps, tag + ": 앞으로 단추 자리를 실제로 눌러도 걷지 않는다")
		await _close_by_key(s)
		_check_restored(s, before, size, tag + " Esc")
		# ② 「캠프」 단추를 눌러 열고 캠프 키패드 「취소」를 눌러 닫는다(P3: 「닫기」 줄 없음).
		await kit.tap(kit.center_of(s.camp_button))
		check(s.party_menu.is_open(), tag + ": 「캠프」 단추 → 캠프")
		_check_hidden(s, size, tag + " 단추")
		await kit.tap(kit.center_of(s.party_menu.key_pad.button("back")))
		_check_restored(s, before, size, tag + " 닫기")
	# ③ 연 채로 상태가 바뀐다(가져오기): 메뉴는 알리지 않고 닫히고 HUD 가 돌아온다.
	var size: Vector2 = await _window(WINDOWS[0])
	var before := _vis(s)
	var save := SaveCodec.encode(s.state)
	await kit.press_key(KEY_P)
	_check_hidden(s, size, "가져오기 전")
	check(s.import_text(save), "탐색 저장 가져오기")
	await kit.frames(3)
	_check_restored(s, before, size, "가져오기")
	# ④ 연 채로 전투 중 저장을 가져온다: 메뉴가 닫히고 전투 층이 열린다(HUD 는 전투로 감춘 채). 다시 탐색 저장을 가져오면 돌아온다.
	await kit.press_key(KEY_P)
	check(s.import_text(FileAccess.get_file_as_string("res://tools/web_check_victory_save.json")), "전투 중 저장 가져오기")
	await kit.frames(3)
	check(not s.party_menu.is_open() and s.battle_layer.is_open(), "가져오기 → 메뉴 닫힘·전투 층")
	_check_hidden(s, size, "전투 중 저장")
	check(s.import_text(save), "다시 탐색 저장")
	await kit.frames(3)
	check(not s.battle_layer.is_open(), "전투 층 닫힘")
	_check_restored(s, before, size, "전투 뒤 탐색 저장")


# ---- 메뉴 창 단추 ----

## 메뉴 창 종류마다: 단추는 64 이상, 서로 겹치지 않고, 창과 제목 문패가 화면 안.
func _check_modal(s: DungeonScreen, size: Vector2, tag: String) -> void:
	var m := s.modal
	check(m.is_open(), tag + ": 창이 열렸다")
	var screen := Rect2(Vector2.ZERO, size)
	var panel := _rect(m._panel)
	check(screen.encloses(panel) and screen.encloses(_rect(m.title_plate)), "%s: 창 %s·제목 문패가 화면 안" % [tag, str(panel)])
	var rects: Array[Rect2] = []
	var names: Array[String] = []
	for n in m._panel.find_children("*", "Button", true, false):
		var b := n as Button
		if not b.is_visible_in_tree():
			continue
		var r := _rect(b)
		check(r.size.x >= 64.0 and r.size.y >= 64.0, "%s: %s 「%s」 크기 %s" % [tag, b.name, b.text, str(r.size)])
		check(panel.encloses(r), "%s: %s 는 창 안" % [tag, b.name])
		for i in rects.size():
			check(not rects[i].intersects(r), "%s: %s 와 %s 가 겹친다" % [tag, names[i], b.name])
		rects.append(r)
		names.append(b.name)
	check(not rects.is_empty(), tag + ": 단추가 있다")


func test_modal_buttons_are_at_least_64_and_fit() -> void:
	# 크기만 보는 단추는 트리에 넣지 않으므로 직접 지운다(남기면 실행 끝에 단추·모양 상자·글자 자원이 새어 나간다).
	var probe := ModalLayer.button("x", func() -> void: pass)
	check_eq(probe.custom_minimum_size, Vector2(240, 64), "창 단추 기본 크기")
	probe.free()
	_kit()
	var s := await kit.open("native", 7)
	s._save_slot("slot1")  # 불러오기 칸·전멸 창 「불러오기」가 누를 수 있게
	await kit.frames(2)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		s._open_wipe()
		await kit.frames(3)
		_check_modal(s, size, tag + " 전멸 창")
		s._alert("알림")
		await kit.frames(3)
		_check_modal(s, size, tag + " 알림")
		s.modal.close()
		await kit.frames(2)


# ---- 크기가 바뀌어도 고른 스킬 줄이 보인다 ----

func _cursor_row_shown(tag: String) -> void:
	var list := layer.panel.skill_list
	var row := layer.panel.skill_rows[layer.cursor]
	check(row.selected and list.shows(Rect2(row.position, row.size)), "%s: 고른 줄 %d 가 목록(높이 %d, 내림 %d) 안에 보인다" % [tag, layer.cursor, list.size.y, list.scroll])
	check(list.scroll >= 0.0 and list.scroll <= list.max_scroll() + 0.01, "%s: 내림 %.0f ≤ %.0f" % [tag, list.scroll, list.max_scroll()])


## 같은 층 인스턴스에서 화면 크기만 바꾼다(층을 다시 만들지 않는다): 줄이는 쪽·늘리는 쪽 모두.
func test_resize_keeps_the_selected_skill_row_visible() -> void:
	await _six_skills(Vector2(1280, 1000))
	var list := layer.panel.skill_list
	for i in 5:
		await _step("cursor", 1)
	check_eq(layer.cursor, 5, "커서를 마지막 줄로")
	var tall := list.size.y
	_cursor_row_shown("1280×1000")
	host.size = Vector2(1280, 720)
	await kit.frames(2)
	check(list.size.y < tall, "줄이면 목록이 낮아진다(스킬 판 아래 = 카드 위) %d → %d" % [tall, list.size.y])
	_cursor_row_shown("1000 → 720")
	check_eq([layer.sub, layer.cursor], ["skills", 5], "줄여도 스킬 고르기·커서 그대로")
	host.size = Vector2(1280, 1000)
	await kit.frames(2)
	_cursor_row_shown("720 → 1000")
	# 늘리는 쪽: 작은 화면에서 마지막 줄까지 내린 뒤 늘린다.
	host.size = Vector2(1280, 720)
	await kit.frames(2)
	check(list.scroll > 0.0, "작은 화면에서 마지막 줄이면 내려 있다")
	host.size = Vector2(1728, 720)
	await kit.frames(2)
	_cursor_row_shown("1280 → 1728 넓게")
	host.size = Vector2(1280, 1000)
	await kit.frames(2)
	_cursor_row_shown("720 → 1000 높게")
	# 같은 크기로 다시 그릴 때(로그 열고 닫기)는 손으로 내린 자리를 지킨다(1단계 규칙).
	host.size = Vector2(1280, 720)
	await kit.frames(2)
	while layer.cursor > 0:
		await _step("cursor", -1)
	list.scroll_to(list.max_scroll())
	var manual := list.scroll
	check(manual > 0.0, "손으로 끝까지 내렸다")
	await _step("log")
	await _step("log_close")
	check_eq([layer.sub, list.scroll], ["skills", manual], "같은 크기 다시 그리기는 손으로 내린 자리를 지킨다")
