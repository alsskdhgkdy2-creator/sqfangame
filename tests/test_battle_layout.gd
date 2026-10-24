## M2.7 R3 전투 화면(원작 HD 1868180_0e36b17e·1810820_1f51fd75·jp_guide5_img1·img4 를 옮김) 시험:
## 앵커(창 크기를 바꾼 뒤), 단계마다 같은 적 자리, 메시지 띠 글, HP 표, 명령 목록 원호, 대원 카드(지금 대원 시안 틀·쓰러짐 회색·HP 노랑 → 주황),
## 초상·TP 게이지, 전투 중 미니맵, 새 색의 글자 대비. 배치 표와 겹친 곳 누르기는 test_ui_relayout.
## 저장은 쓰지 않는다(save_hook 은 빈 함수). 결과는 구성으로 정한다(D15).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const RATS_MOTH := "formation.f1.rats_moth"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]

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


func _window(px: Vector2) -> Vector2:
	timeout_sec = 60.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 전투 층만 띄운다. s 가 없으면 끝나지 않는 편성(나방은 쓰러지지 않는다).
func _layer(px: Vector2, s: ExplorationState = null, speed: float = 0.0) -> BattleLayer:
	var size: Vector2 = await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "LayoutHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	host.size = size
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


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _enemy_rects() -> Array:
	var out := []
	for c in layer.enemy_area.cards:
		out.append(_rect(c))
	return out


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# ---- 앵커 ----

## 같은 층에서 창 크기를 바꿔도 앵커로 붙은 부품이 새 크기의 자리에 있다(_layout 이 다시 계산하지 않아도).
func test_parts_follow_anchors_after_resize() -> void:
	await _layer(WINDOWS[0])
	for px in [WINDOWS[1], WINDOWS[0], WINDOWS[1]]:
		var s: Vector2 = await _window(px)
		host.size = s
		await kit.frames(2)
		var tag := "%s(논리 %s)" % [str(px), str(s)]
		check_eq(layer.size, s, tag + ": 층 크기")
		check_eq(layer.banner_rect(), Rect2(BattleLayer.BANNER_X, 0, s.x - BattleLayer.BANNER_X, BattleLayer.BANNER_H), tag + ": 메시지 띠는 오른쪽 끝까지")
		check_eq(_rect(layer.minimap).end, s - Vector2(BattleLayer.MINIMAP_RIGHT, BattleLayer.MINIMAP_BOTTOM), tag + ": 미니맵은 오른쪽 아래")
		check_eq(_rect(layer.enemy_area).end.x, s.x - BattleLayer.ENEMY_RIGHT, tag + ": 적 영역 오른쪽 끝")
		check_eq(_rect(layer.party_cards).end.y, s.y, tag + ": 카드 판은 아래")
		var c3 := _rect(layer.party_cards.cards[3])
		var c4 := _rect(layer.party_cards.cards[4])
		check(absf((c3.position.x + c4.end.x) / 2.0 - s.x / 2.0) <= 1.0, tag + ": 아랫줄 가운데")
		check_eq(_rect(layer.panel), Rect2(BattleLayer.LIST_X, BattleLayer.LIST_TOP, BattleLayer.LIST_W, BattleLayer.LIST_H), tag + ": 명령 목록은 왼쪽 그대로")
		# 적 칸은 적 영역 안 가운데.
		var er := _rect(layer.enemy_area)
		var front: Array[Rect2] = []
		for i in layer.display.enemies.size():
			var r := _rect(layer.enemy_area.card(i))
			check(er.encloses(r), "%s: 적 %d 는 적 영역 안" % [tag, i])
			if layer.display.enemies[i].row == "front":
				front.append(r)
		check(absf((front[0].position.x + front[-1].end.x) / 2.0 - er.get_center().x) <= 1.0, tag + ": 전열 적은 영역 가운데")


# ---- 적 자리 ----

func test_enemy_positions_identical_in_every_phase() -> void:
	for px in WINDOWS:
		var tag := str(px)
		var s := Fx.battle(Fx.quiet_defs(Fx.EXACT), "formation.f1.rats", 4)
		for u in s.battle.enemies:
			u.hp = 1
		await _layer(px, s, 1.0)
		var at := _enemy_rects()
		await _step("command", 0)
		check_eq(layer.sub, "target", tag + ": 대상")
		check_eq(_enemy_rects(), at, tag + ": 대상 고르기")
		await _step("back")
		await _step("commands", [{"kind": "attack", "target": 0}, {"kind": "attack", "target": 1}, {"kind": "attack", "target": 2},
			{"kind": "guard"}, {"kind": "guard"}])
		check_eq(layer.phase, "anim", tag + ": 연출")
		check_eq(_enemy_rects(), at, tag + ": 연출")
		await _step("skip")
		check_eq(layer.phase, "result", tag + ": 결과 창")
		check_eq(_enemy_rects(), at, tag + ": 결과 창")


# ---- 메시지 띠 ----

func test_banner_text_per_phase() -> void:
	await _layer(WINDOWS[0], null, 1.0)
	var name0 := layer.display.party[0].name
	check_eq(layer.banner_lines(), [texts.t("battle.ui.prompt", {"member": name0}), texts.t("msg.encounter"), true], "첫 턴: 물음 + 「적이 나타났다」 안내")
	layer._notice = ""
	check_eq(layer.banner_lines(), [texts.t("battle.ui.prompt", {"member": name0}), "", false], "명령: 물음(대원 이름)")
	await _step("command", 0)
	check_eq(layer.banner_lines()[0], texts.t("battle.ui.choose_target", {"skill": layer.display.skill_name("attack")}), "공격 대상 안내")
	check_eq(layer.banner_lines()[1], "", "공격 대상: 설명 없음")
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	await _step("command", 1)
	check_eq(layer.banner_lines().slice(0, 2), [layer.skill_info_title, layer.skill_info_text], "스킬 목록: 커서 스킬 설명")
	check(not layer.skill_info_title.is_empty(), "설명 머리")
	await _step("skill", HIGH_SLASH)
	check_eq(layer.sub, "target", "스킬 대상")
	check_eq(layer.banner_lines()[0], texts.t("battle.ui.choose_target", {"skill": layer.display.skill_name(HIGH_SLASH)}), "스킬 대상 안내")
	check_eq(layer.banner_lines()[1], layer.skill_info_text, "스킬 대상: 둘째 줄 = 스킬 설명")
	await _step("log")
	check_eq(layer.banner_lines()[0], texts.t("battle.ui.log"), "로그 창")
	await _step("log_close")
	await _step("back")
	await _step("back")
	# 못 고르는 명령: 둘째 줄이 안내(첫 줄은 그대로).
	layer.state.battle.party[1].binds["leg"] = 2
	layer._refresh()
	await _step("command", 3)
	var bl := layer.banner_lines()
	check_eq(bl, [texts.t("battle.ui.prompt", {"member": layer.display.party[1].name}), texts.t("battle.reason.bound_leg"), true], "안내는 둘째 줄")
	layer.state.battle.party[1].binds.erase("leg")
	layer._notice = ""
	for i in 4:
		await _step("command", 2)
	check_eq(layer.sub, "confirm", "모두 고름")
	check_eq(layer.banner_lines()[0], texts.t("battle.ui.ready"), "준비 끝")
	check(not layer.portrait.visible, "모두 고른 뒤 초상 없음")
	await _step("execute")
	check_eq(layer.phase, "anim", "연출")
	await kit.frames(2)
	check(not str(layer.banner_lines()[0]).is_empty() and layer.banner_lines()[0] == layer._announce, "연출: 행동 글 %s" % str(layer.banner_lines()))


func test_result_banner_shows_result_title() -> void:
	var s := Fx.battle(Fx.quiet_defs(Fx.EXACT), "formation.f1.rats", 4)
	for u in s.battle.enemies:
		u.hp = 1
	await _layer(WINDOWS[0], s)
	await _step("commands", [{"kind": "attack", "target": 0}, {"kind": "attack", "target": 1}, {"kind": "attack", "target": 2},
		{"kind": "guard"}, {"kind": "guard"}])
	check_eq(layer.phase, "result", "결과 창")
	check_eq(layer.banner_lines()[0], texts.t("battle.result.victory"), "띠 = 결과 제목")
	check(layer.minimap.is_visible_in_tree(), "결과 창에서도 미니맵")


# ---- HP 표 ----

func test_hp_tag_floats_above_the_cursor_enemy() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _layer(px)
		check(layer.enemy_area.tagged() == null and not layer.enemy_area.tag_rect().has_area(), tag + ": 명령 고르기에는 HP 표 없음")
		await _step("command", 0)
		var seen := []
		for k in layer.target_slots.size():
			var c := layer.enemy_area.tagged()
			check(c != null and c.cursor, "%s: 커서 적에 HP 표" % tag)
			var tr := layer.enemy_area.tag_rect()
			check(tr.end.y + EnemyArea.TAG_TRI <= c.position.y, "%s: 표는 %s 위 %s" % [tag, c.name, str(tr)])
			check(absf(tr.get_center().x - (c.position.x + c.size.x / 2.0)) <= 1.0, "%s: 표는 %s 가운데" % [tag, c.name])
			check(Rect2(Vector2.ZERO, layer.enemy_area.size).encloses(tr) or tr.position.y >= -EnemyArea.TAG_SPACE, "%s: 표 자리 %s" % [tag, str(tr)])
			seen.append(c.name)
			await _step("target_cursor", 1)
		check_eq(seen.size(), layer.target_slots.size(), tag + ": 커서를 옮기면 표도 옮긴다 %s" % str(seen))
		check(seen.size() == 1 or seen[0] != seen[1], tag + ": 다른 적")
		await _step("back")
		check(layer.enemy_area.tagged() == null, tag + ": 뒤로 → 표 없음")


# ---- 명령 목록 ----

func test_command_list_rows_follow_the_curved_edge() -> void:
	await _layer(WINDOWS[0])
	var p := layer.panel
	check_eq(p.mode, "menu", "명령 목록")
	var h := p.size.y
	check_eq(p.arc_x(h / 2.0), p.size.x - CommandPanel.RIM, "원호 가장 오른쪽은 가운데 높이")
	check(is_equal_approx(p.arc_x(0.0), p.size.x - CommandPanel.RIM - CommandPanel.BULGE), "위 끝은 BULGE 만큼 안쪽")
	check(is_equal_approx(p.arc_x(h), p.arc_x(0.0)), "위·아래 대칭")
	var rows: Array[ListRow] = []
	rows.append_array(p.command_buttons)
	rows.append(p.back_button)
	var right := []
	for r in rows:
		check(r.visible and r.size.y >= 64.0 and r.size.x >= 64.0, "%s 줄 64 이상 %s" % [r.name, str(r.size)])
		var poly := r.polygon()
		var y0 := r.position.y
		check(is_equal_approx(poly[1].x + r.position.x, p.arc_x(y0)), "%s: 위 오른쪽 끝이 원호 위" % r.name)
		check(is_equal_approx(poly[2].x + r.position.x, p.arc_x(y0 + r.size.y)), "%s: 아래 오른쪽 끝이 원호 위" % r.name)
		right.append(maxf(poly[1].x, poly[2].x) + r.position.x)
	check(right[2] > right[0] and right[2] > right[4], "가운데 줄이 가장 오른쪽으로 나온다 %s" % str(right))
	# 모양: 커서 줄 노랑, 나머지 청록, 못 고르는 줄 어두운 초록(UiTheme cmd:*).
	check_eq(p.command_buttons[0].theme_state(), "cmd:selected", "커서 줄")
	check_eq(p.command_buttons[1].theme_state(), "cmd:normal", "보통 줄")
	await _step("cursor", 1)
	check(p.command_buttons[1].theme_state() == "cmd:selected" and p.command_buttons[0].theme_state() == "cmd:normal", "커서가 옮긴다")
	layer.state.battle.party[0].binds["leg"] = 2
	layer._refresh()
	await kit.frames(1)
	check_eq(p.command_buttons[3].theme_state(), "cmd:disabled", "못 고르는 도주 줄")
	layer.state.battle.party[0].binds.erase("leg")
	layer._refresh()
	# 대상 고르기: 명령 줄을 보인 채 고른 명령만 「고른」 모양(gs2_653224), 줄은 누르기 없음, 「뒤로」만 누른다.
	await _step("command", 0)
	check_eq(p.mode, "target", "대상 고르기 목록")
	for i in p.command_buttons.size():
		var b := p.command_buttons[i]
		check(b.visible and b.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: 보이고 누르기 없음" % b.name)
		check_eq(b.theme_state(), "cmd:chosen" if i == 0 else "cmd:normal", "%s 모양(고른 명령 = 밝은 시안, 노랑은 커서)" % b.name)
	check(p.back_button.visible and p.back_button.mouse_filter == Control.MOUSE_FILTER_STOP, "뒤로")
	check(not layer.visible_buttons().has(p.command_buttons[0]), "대상 고르기 중 명령 줄은 누를 단추가 아니다")


## 원작 III HD gs2_653224: 스킬 목록은 명령 목록 오른쪽의 따로 된 판, 첫 줄 위 = 「스킬」 줄 위, 「스킬」 줄은 밝은 시안.
func test_skill_panel_sits_right_of_the_command_list() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _layer(px)
		await _step("command", 0)
		await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
		var u := layer.state.battle.party[1]
		for sid in ["skill.blade_duelist.leg_cutter", "skill.blade_duelist.quick_draw", "skill.glyph_wizard.heat_glyph"]:
			u.skills[sid] = 1  # 구성: 스킬 여섯(넘쳐 끌어 내린다)
		await _step("command", 1)
		var p := layer.panel
		check_eq(p.mode, "skills", tag + ": 스킬 목록")
		var sp := _rect(p.skill_panel)
		var cmd := _rect(p.command_buttons[1])
		check(p.skill_panel.is_visible_in_tree(), tag + ": 스킬 판")
		check_eq(sp.position.x, BattleLayer.SKILL_X, tag + ": 판 x")
		check_eq(sp.size.x, BattleLayer.SKILL_W, tag + ": 판 폭")
		check_eq(sp.position.y, cmd.position.y, tag + ": 판 위 = 「스킬」 줄 위")
		var cap := _rect(layer.party_cards.cards[0]).position.y - 8.0
		var want_end := minf(cap, sp.position.y + 6.0 * (64.0 + CommandPanel.SKILL_GAP) - CommandPanel.SKILL_GAP + 2.0 * CommandPanel.SKILL_PAD)
		check_eq(sp.end.y, want_end, tag + ": 긴 목록: 판 아래 = min(줄 + 여백, 카드 위 − 8)")
		check_eq(sp.end.y, cap, tag + ": 여섯 줄은 넘쳐 카드 위 − 8 까지")
		var first := _rect(p.skill_rows[0])
		check(absf(first.position.y - (cmd.position.y + CommandPanel.SKILL_PAD)) <= 0.5, "%s: 첫 줄 위 %s ≈ 「스킬」 줄 위 + 여백" % [tag, str(first)])
		# 명령 줄: 보이고 누르기 없음, 「스킬」 = 고른 모양, 「뒤로」 는 명령 목록 아래에서 누른다.
		for i in p.command_buttons.size():
			var b := p.command_buttons[i]
			check(b.visible and b.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: %s 보이고 누르기 없음" % [tag, b.name])
			check_eq(b.theme_state(), "cmd:chosen" if i == 1 else "cmd:normal", "%s: %s 모양" % [tag, b.name])
		check(p.back_button.visible and _rect(p).encloses(_rect(p.back_button)), tag + ": 「뒤로」는 명령 목록 안")
		check(not _rect(p.back_button).intersects(sp), tag + ": 「뒤로」는 스킬 판과 겹치지 않는다")
		# 스킬 줄: 64 이상, 판 안, 모양(커서 노랑 / 보통 청록), TP 상자.
		var shown := 0
		for b in p.skill_rows:
			if not b.visible:
				continue
			check(b.size.y >= 64.0 and b.size.x >= 64.0, "%s: %s 크기 %s" % [tag, b.name, str(b.size)])
			check(b.boxed_right and b.skin == "skill", "%s: %s TP 상자·스킬 모양" % [tag, b.name])
			if p.skill_list.shows(Rect2(b.position, b.size)):
				shown += 1
				check(sp.encloses(_rect(b)), "%s: %s 는 판 안" % [tag, b.name])
		check(shown >= 3 and shown < 6, "%s: 다 보이지 않아 끌어 내린다(보이는 줄 %d)" % [tag, shown])
		check_eq(p.skill_rows[0].theme_state(), "skill:selected", tag + ": 커서 줄")
		check_eq(p.skill_rows[1].theme_state(), "skill:normal", tag + ": 보통 줄")
		# 판이 적 칸을 덮어도 누를 수 있는 것은 판의 줄이다(적은 이때 고를 수 없다).
		for b in layer.visible_buttons():
			if b is BattleCard:
				check(not _rect(b).intersects(sp), "%s: 판이 덮은 적 %s 은 누를 단추가 아니다" % [tag, b.name])
		# 커서를 마지막으로: 그 줄이 보이게 내려간다.
		for k in 5:
			await _step("cursor", 1)
		check(p.skill_list.scroll > 0.0 and p.skill_list.shows(Rect2(p.skill_rows[5].position, p.skill_rows[5].size)), tag + ": 커서 줄이 보이게 끌어 내림")
		# 대상 고르기에 들어가면 판이 닫힌다(고를 적을 덮지 않는다).
		await _step("cursor", 1)
		var hs := layer._skill_ids().find(HIGH_SLASH)
		while layer.cursor != hs:
			await _step("cursor", 1)
		await _step("confirm")
		check_eq(layer.sub, "target", tag + ": 스킬 대상")
		check(not p.skill_panel.is_visible_in_tree(), tag + ": 대상 고르기 → 스킬 판 닫힘")
		check_eq(p.command_buttons[1].theme_state(), "cmd:chosen", tag + ": 대상 고르기 중에도 「스킬」 = 고른 모양")
		await _step("back")
		check(layer.sub == "skills" and p.skill_panel.is_visible_in_tree(), tag + ": 뒤로 → 스킬 판 다시")


## 짧은 목록: 판은 줄을 감싼다(빈 남색 판이 남지 않는다), 끌어 내리지 않는다.
func test_short_skill_list_panel_wraps_its_rows() -> void:
	for px in WINDOWS:
		var tag := str(px)
		await _layer(px)
		await _step("command", 0)
		await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
		await _step("command", 1)
		var p := layer.panel
		var n := layer._skill_ids().size()
		check(n >= 1 and n <= 3, "%s: 준비: 짧은 목록(%d)" % [tag, n])
		var sp := _rect(p.skill_panel)
		var cap := _rect(layer.party_cards.cards[0]).position.y - 8.0
		var content := n * (64.0 + CommandPanel.SKILL_GAP) - CommandPanel.SKILL_GAP + 2.0 * CommandPanel.SKILL_PAD
		check_eq(sp.size.y, minf(content, cap - sp.position.y), "%s: 판 높이 = min(줄 + 여백, 카드 위 − 8)" % tag)
		check(sp.end.y < cap, "%s: 짧은 목록은 카드 위까지 내려오지 않는다" % tag)
		var last := _rect(p.skill_rows[n - 1])
		check(absf(sp.end.y - CommandPanel.SKILL_PAD - last.end.y) <= 0.5, "%s: 마지막 줄 아래 = 판 아래 − 여백" % tag)
		check_eq(p.skill_list.max_scroll(), 0.0, tag + ": 다 들어가면 끌어 내리지 않는다")


## 스킬 줄을 누르면 그 줄이 받는다(아래 적 칸이 아니다). 받는 컨트롤은 엔진이 실제로 고르는 것(test_ui_relayout 과 같은 방법).
func test_taps_on_skill_rows_reach_the_rows() -> void:
	await _layer(WINDOWS[0])
	await _step("command", 0)
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	await _step("command", 1)
	var p := layer.panel
	var hit := 0
	for b in p.skill_rows:
		if not b.visible or not p.skill_list.shows(Rect2(b.position, b.size)):
			continue
		for e in layer.enemy_area.cards:
			var o := _rect(b).intersection(_rect(e))
			if not o.has_area():
				continue
			hit += 1
			var got := await _receiver_at(o.get_center())
			check(got == b, "%s 와 %s 가 겹친 곳 → 스킬 줄, 실제 %s" % [b.name, e.name, str(got.get_path()) if got != null else "없음"])
	check(hit > 0, "스킬 판이 적 칸 위에 겹친다(겹침 %d)" % hit)
	var pressed := []
	p.pressed.connect(func(kind: String, arg: Variant) -> void: pressed.append([kind, arg]))
	await kit.tap(kit.center_of(p.skill_rows[1]))
	check_eq(pressed, [["skill", p.skill_rows[1].get_meta("skill_id")]], "누른 스킬 줄이 그 스킬을 낸다")


## 논리 좌표 p 를 손가락으로 누를 때 처음 받는 컨트롤(엔진이 고르는 것). 뗄 때는 창 밖에서 뗀다.
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
	kit.touch(3, win, true)
	kit.touch(3, Vector2(-500, -500), false)
	await kit.frames(1)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Control).gui_input.is_connected(h[1]):
			(h[0] as Control).gui_input.disconnect(h[1])
	return got[0] if not got.is_empty() else null


# ---- 대원 카드 ----

func test_acting_member_has_bright_cyan_frame() -> void:
	await _layer(WINDOWS[0])
	for k in 2:
		for i in layer.party_cards.cards.size():
			var c := layer.party_cards.cards[i]
			var want := UiTheme.CARD_ACTIVE if i == layer.member else UiTheme.CARD_FRAME
			check_eq(c.frame_color(), want, "대원 %d 차례 %d: 카드 %d 틀" % [layer.member, k, i])
			check_eq(c.drawn.get("frame"), want, "그린 틀 %d" % i)
		await _step("command", 2)
		await kit.frames(1)


func test_knocked_out_card_is_dark_grey_with_cyan_tp() -> void:
	var s := Fx.battle(Fx.quiet_defs({}, ["enemy.cable_moth"]), RATS_MOTH, 5)
	s.battle.party[3].hp = 0
	s.battle.party[3].tp = 7
	await _layer(WINDOWS[0], s)
	await kit.frames(1)
	var ko := layer.party_cards.cards[3]
	var ok := layer.party_cards.cards[4]
	check_eq(ko.drawn.get("fill"), UiTheme.CARD_DOWN_TOP, "쓰러진 카드: 어두운 회색 판")
	check_eq(ko.drawn.get("head"), UiTheme.CARD_DOWN_HEAD, "이름 띠도 회색")
	check_eq(ko.drawn.get("name_color"), UiTheme.CARD_DOWN_TEXT, "이름 회색")
	check_eq([ko.drawn.get("hp"), ko.drawn.get("tp")], [0, 7], "HP 0, TP 그대로")
	check_eq(ko.drawn.get("tp_bar"), UiTheme.CARD_TP, "TP 막대는 시안 그대로")
	check(ko.drawn_chips().is_empty(), "상태 표시 없음")
	check_eq(ok.drawn.get("fill"), UiTheme.CARD_TOP, "산 카드: 청록 판")
	check_eq(ok.drawn.get("name_color"), UiTheme.CARD_TEXT, "산 카드 이름")
	# HP 막대는 비율과 상관없이 노랑 → 주황.
	for hp in [1, 20, ok.unit().max_hp]:
		layer.state.battle.party[4].hp = hp
		layer.display.sync(layer.state)
		ok.snap()
		await kit.frames(1)
		check_eq(ok.drawn.get("hp_bar"), [UiTheme.CARD_HP_FROM, UiTheme.CARD_HP_TO], "HP %d: 노랑 → 주황" % hp)


func test_card_text_and_new_battle_colours_meet_contrast() -> void:
	var pairs := [
		["카드 이름", UiTheme.CARD_TEXT, [UiTheme.CARD_HEAD]],
		["카드 수치", UiTheme.CARD_TEXT, [UiTheme.CARD_TOP, UiTheme.CARD_BOTTOM]],
		["HP·TP 이름표", UiTheme.CARD_LABEL, [UiTheme.CARD_TOP, UiTheme.CARD_BOTTOM]],
		["고른 명령", BattleCard.COMMAND_TEXT, [UiTheme.CARD_HEAD]],
		["쓰러진 카드 글자", UiTheme.CARD_DOWN_TEXT, [UiTheme.CARD_DOWN_TOP, UiTheme.CARD_DOWN_BOTTOM, UiTheme.CARD_DOWN_HEAD]],
		["못 고르는 이유", BattleCard.REASON_TEXT, [UiTheme.CARD_TOP.lerp(Color.BLACK, 0.45), UiTheme.CARD_DOWN_TOP.lerp(Color.BLACK, 0.45)]],
		["띠 글", BattleLayer.ANNOUNCE_TEXT, [UiTheme.BATTLE_BANNER_TOP, UiTheme.BATTLE_BANNER_BOTTOM]],
		["띠 안내", BattleLayer.NOTICE_TEXT, [UiTheme.BATTLE_BANNER_TOP, UiTheme.BATTLE_BANNER_BOTTOM]],
		["턴 문패", UiTheme.BATTLE_BANNER_TEXT, [UiTheme.TURN_FILL]],
		["안내 알약·TP 게이지·HP 표", UiTheme.BATTLE_BANNER_TEXT, [UiTheme.HINT_PILL, UiTheme.HINT_PILL_PRESSED]],
		["초상 이름", UiTheme.CARD_TEXT, [UiTheme.CMD_PLATE]],
	]
	for p in pairs:
		for bg in p[2]:
			var c := contrast(p[1], bg)
			check(c >= 4.5, "%s: %s 위 대비 %.2f" % [p[0], (bg as Color).to_html(false), c])
	# 명령 줄 모양은 UiTheme.SKIN_LOOKS 대비 시험(test_ui_polish2)에 들어 있다.
	for k in ["cmd:normal", "cmd:selected", "cmd:disabled", "hint:normal", "hint:pressed"]:
		check(UiTheme.SKIN_LOOKS.has(k), "대비 시험에 " + k)


# ---- 초상·미니맵 ----

func test_portrait_shows_the_acting_member_and_tp() -> void:
	await _layer(WINDOWS[0])
	for k in 2:
		var u := layer.display.party[layer.member]
		check(layer.portrait.visible, "초상")
		check_eq([layer.portrait.unit_name, layer.portrait.tp, layer.portrait.max_tp], [u.name, u.tp, u.max_tp], "초상 = 지금 대원 %d" % layer.member)
		await _step("command", 2)
	await _step("log")
	check(not layer.portrait.visible, "로그 창이 열리면 감춘다")


func test_minimap_shows_the_party_map_in_battle() -> void:
	_kit_open()
	var s := await kit.open("native", 7)
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for k in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	check(s.battle_layer.is_open(), "준비: 전투")
	await kit.frames(3)
	var mm := s.battle_layer.minimap
	check(mm.is_visible_in_tree() and mm.is_mini, "전투 중 미니맵")
	check(mm.state == s.state, "같은 지도(탐색 상태)")
	check(int(mm.drawn["count"]) > 0 and int(mm.drawn["version"]) == s.state.annotation.version, "그렸다: %s" % str(mm.drawn))
	check(not s.minimap.is_visible_in_tree(), "탐색 HUD 미니맵은 감춤(전투 층 것 하나)")


func _kit_open() -> void:
	timeout_sec = 60.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")


# ---- 연출 중 행동하는 대원 ----

## 원작 1810820_1f51fd75: 연출 중 지금 행동하는 대원 카드에 시안 틀. 적이 행동할 때·독·턴 끝에는 틀이 없다.
func test_playback_frames_the_acting_member() -> void:
	await _layer(WINDOWS[0], null, 1.0)
	await _step("commands", BattlePolicy.choose(layer.state, BattlePolicy.DEFAULT))
	check_eq(layer.phase, "anim", "연출")
	var party_seen := 0
	var enemy_seen := 0
	for f in 4000:
		if layer.phase != "anim":
			break
		var want := -1
		if layer._step_i < layer._steps.size():
			var st: Dictionary = layer._steps[layer._step_i]
			var head: Dictionary = st["head"]
			if st["started"] and BattleLayer.ACTOR_HEADS.has(head.get("type", "")):
				if head["unit"]["side"] == BattleUnit.PARTY:
					want = int(head["unit"]["slot"])
					party_seen += 1
				else:
					enemy_seen += 1
		var framed := []
		for c in layer.party_cards.cards:
			if c.current:
				framed.append(c.unit_ref["slot"])
		check_eq(framed, [] if want < 0 else [want], "프레임 %d: 시안 틀 = 행동하는 대원" % f)
		await kit.frames(1)
	check(party_seen > 0 and enemy_seen > 0, "대원·적 행동을 모두 보았다(%d·%d)" % [party_seen, enemy_seen])
	await kit.frames(2)
	check_eq(layer.phase, "command", "다음 턴")
	for c in layer.party_cards.cards:
		check_eq(c.current, c.unit_ref["slot"] == layer.member, "명령 단계: 틀은 고르는 대원")


# ---- 부모 _init(GDScript 는 저절로 부르지 않는다) ----

## 지도 그림은 clip_contents 로 틀 안에서만 보인다(MapPanel._init). MapOverview 가 super() 를 빼면 꺼진다(R3 검토).
func test_map_views_clip_their_contents() -> void:
	var made: Array[Control] = [MapPanel.new(), MapOverview.new().setup(true), MapOverview.new().setup(false)]
	for c in made:
		check(c.clip_contents, "%s 새 부품 clip_contents" % c.get_class())
	for c in made:
		c.free()
	_kit_open()
	var s := await kit.open("native", 7)
	for c in [s.map, s.map_window.overview, s.minimap, s.battle_layer.minimap]:
		check((c as Control).clip_contents, "화면의 %s clip_contents" % c.name)


## 명령 줄(ListRow)도 TouchButton 의 가장 작은 크기 64×64 를 지킨다.
func test_list_rows_keep_the_touch_minimum() -> void:
	var r := ListRow.new()
	check(r.custom_minimum_size.x >= 64.0 and r.custom_minimum_size.y >= 64.0, "새 ListRow 최소 %s" % str(r.custom_minimum_size))
	check(r.focus_mode == Control.FOCUS_NONE and r.mouse_filter == Control.MOUSE_FILTER_STOP, "포커스 없음·누르기 받음")
	r.free()
	await _layer(WINDOWS[0])
	await _step("command", 1)
	var rows: Array[ListRow] = []
	rows.append_array(layer.panel.command_buttons)
	rows.append_array(layer.panel.skill_rows)
	rows.append_array([layer.panel.back_button, layer.panel.execute_button])
	for b in rows:
		check(b.custom_minimum_size.x >= 64.0 and b.custom_minimum_size.y >= 64.0, "%s 최소 %s" % [b.name, str(b.custom_minimum_size)])
