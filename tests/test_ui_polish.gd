## M2.6 UI 다듬기 1단계(00 D20, docs/research/03 U1~U5) 시험: 전투 배경 배치, 전투 스킬 설명·연출 중 명령 칸,
## 스킬 트리 꺾은선, 창 단추 상태, 대원 HP 막대 색. 저장은 장면 시험 임시 폴더에만 쓴다. 결과는 구성으로 정한다(D15).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const RATS_MOTH := "formation.f1.rats_moth"
const HIGH_SLASH := "skill.blade_duelist.high_slash"
const CROSS_SWEEP := "skill.blade_duelist.cross_sweep"
const LEG_CUTTER := "skill.blade_duelist.leg_cutter"
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000)]

var kit: Kit
var host: Control
var layer: BattleLayer
var texts: TextDb


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()
		kit = null


func _kit() -> void:
	timeout_sec = 40.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")


## 전투 층만 size 크기의 host 에 띄운다(끝날 수 없는 편성: 적은 아무것도 하지 않고 나방은 쓰러지지 않는다).
func _layer(size: Vector2, speed: float = 0.0) -> BattleLayer:
	_kit()
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "PolishHost"
	host.position = Vector2.ZERO
	host.size = size
	tree.root.add_child(host)
	var s := Fx.battle(Fx.quiet_defs({}, ["enemy.cable_moth"]), RATS_MOTH, 5)
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


func _rect(c: Control) -> Rect2:
	return Rect2(c.get_global_position() - host.get_global_position(), c.size)


# ---- U1 전투 배경·배치 ----

func test_battle_parts_stay_inside_and_apart_at_both_sizes() -> void:
	for sz in SIZES:
		await _layer(sz)
		var screen := Rect2(Vector2.ZERO, sz)
		var enemy := _rect(layer.enemy_area)
		var panel := _rect(layer.panel)
		var info := _rect(layer.skill_info)
		var cards := _rect(layer.party_cards)
		for pair in [["적 영역", enemy], ["명령 칸", panel], ["설명 칸", info], ["대원 칸", cards], ["로그 단추", _rect(layer.log_button)], ["로그 창", _rect(layer.log_view)]]:
			check(screen.encloses(pair[1]), "%s: %s %s 이 화면 안" % [str(sz), pair[0], str(pair[1])])
		check(not enemy.intersects(panel) and not info.intersects(panel), "%s: 적 영역·설명 칸은 명령 칸과 겹치지 않는다" % str(sz))
		check(not info.intersects(enemy) and not info.intersects(cards), "%s: 설명 칸은 적 영역과 대원 칸 사이" % str(sz))
		var toast := Rect2(0, BattleLayer.TOAST_Y, sz.x, BattleLayer.TOAST_H)
		check(screen.encloses(toast) and toast.end.y <= info.position.y, "%s: 알림 줄은 화면 안, 설명 칸 위" % str(sz))
		for c in layer.enemy_area.get_children():
			if c is BattleCard:
				check(enemy.encloses(_rect(c)), "%s: 적 칸 %s 은 적 영역 안" % [str(sz), c.name])


# ---- U2 스킬 설명·연출 중 명령 칸 ----

func test_summary_examples() -> void:
	_kit()
	var db := Fx.defs().battle
	var line := func(sid: String, lv: int = 1) -> String: return SkillSummary.line(texts, db.skill(sid), lv)
	check_eq(line.call(HIGH_SLASH), "적 단일 · 근접 · 베기 · 위력 150 · 명중 95%", "하이 슬래시 Lv1")
	check_eq(line.call(LEG_CUTTER), "적 단일 · 근접 · 베기 · 위력 100 · 명중 95% · 이동부 잠금 40% · 3턴", "레그 커터 Lv1: 봉인과 확률")
	check_eq(line.call(CROSS_SWEEP), "적 한 열 · 근접 · 베기 · 위력 110 · 명중 90%", "크로스 스윕: 한 열")
	check_eq(line.call("skill.blade_duelist.overclock"), "자신 · 물리 공격 130% · 3턴", "오버클럭: 강화")
	check_eq(line.call("skill.nano_medic.nano_repair"), "아군 단일 · 회복 15 + 지혜의 100%", "나노 리페어: 회복")
	check_eq(line.call("skill.nano_medic.refresh_patch"), "아군 단일 · 상태이상·봉인 모두 해제 · 먼저 행동", "리프레시 패치")
	check_eq(line.call("skill.nano_medic.reboot"), "전투 불능 아군 단일 · 되살림 · HP 25%", "리부트")
	check_eq(line.call("skill.glyph_wizard.corrode_glyph"), "적 단일 · 부식 나노 70% · 3턴 (턴마다 15)", "부식 글리프: 상태이상")
	check_eq(line.call("skill.holo_knight.defense_protocol"), "아군 전체 · 받는 물리 피해 75% · 3턴", "디펜스 프로토콜")
	check_eq(line.call("skill.holo_knight.front_guard"), "자신 · 그 턴 전열이 받는 물리 피해 60% · 먼저 행동", "프론트 가드")
	check_eq(line.call("skill.holo_knight.aegis_cover"), "다른 아군 단일 · 그 턴 그 아군 대신 단일 물리 공격을 받는다 · 먼저 행동", "이지스 커버")
	check_eq(line.call("skill.enemy.raise_pincers"), "자신 · 힘을 모아 다음 턴 압쇄", "적 charge: 모으는 스킬 이름")
	check_eq(line.call("skill.enemy.rending_howl"), "적 전체 · 받는 물리 피해 125% · 3턴", "적 debuff")
	check_eq(line.call("skill.blade_duelist.blade_mastery"), "패시브 · 힘 +1 · 민첩 +0", "패시브: 보정 값")
	check_eq(SkillSummary.head(texts, db.skill(HIGH_SLASH), 3), "하이 슬래시  Lv 3  TP 5", "머리: 그 레벨 TP")
	check_eq(SkillSummary.head(texts, db.skill("skill.blade_duelist.blade_mastery"), 1), "블레이드 마스터리  Lv 1", "패시브 머리(TP 없음)")


## 레벨 줄 필드 → 설명(머리 + 줄)에 보여야 할 조각. 줄에 새 필드가 생기면 여기에 없어서 시험이 실패한다(빠뜨림을 막는다).
func _tokens(s: BattleDb.SkillDef, row: Dictionary) -> Array:
	var out := []
	for k in row:
		var v: Variant = row[k]
		match k:
			"tp":
				out.append("TP %d" % int(v))
			"power":
				out.append("위력 %d" % int(v))
			"accuracy":
				out.append("명중 " + SkillSummary.pct(int(v)))
			"base":
				out.append("회복 %d" % int(v))
			"wis_pct":
				out.append("지혜의 %d%%" % int(v))
			"hp_permille":
				out.append("HP " + SkillSummary.pct(int(v)))
			"kind":
				out.append(texts.t("battle.buff." + str(v)))
			"value":
				out.append(SkillSummary.pct(int(v)))
			"turns":
				out.append("%d턴" % int(v))
			"ailment":
				out.append("%s %s · %d턴" % [texts.t("ailment." + str(v["id"])), SkillSummary.pct(int(v["chance"])), int(v["turns"])])
				if (v as Dictionary).has("damage"):
					out.append("턴마다 %d" % int(v["damage"]))
				for sub in v:
					if not ["id", "chance", "turns", "damage"].has(sub):
						out.append("<모르는 ailment 필드 %s>" % sub)
			"bind":
				out.append("%s %s · %d턴" % [texts.t("bind." + str(v["part"])), SkillSummary.pct(int(v["chance"])), int(v["turns"])])
				for sub in v:
					if not ["part", "chance", "turns"].has(sub):
						out.append("<모르는 bind 필드 %s>" % sub)
			"bonus":
				for st in v:
					out.append("%s %s" % [texts.t("stat." + str(st)), ("+%d" % int(v[st])) if int(v[st]) >= 0 else str(int(v[st]))])
			_:
				out.append("<규칙 없는 필드 %s (%s)>" % [k, s.id])
	return out


func test_every_skill_level_shows_every_number_of_its_row() -> void:
	_kit()
	var db := Fx.defs().battle
	var n := 0
	for sid in db.skills:
		var s: BattleDb.SkillDef = db.skills[sid]
		for lv in range(1, s.max_level() + 1):
			var t := SkillSummary.head(texts, s, lv) + "\n" + SkillSummary.line(texts, s, lv)
			n += 1
			check(not t.contains(SkillSummary.MISSING), "%s Lv%d: 빠진 값 없음: %s" % [sid, lv, t])
			if not s.passive():
				check(SkillSummary.line(texts, s, lv).begins_with(texts.t("battle.scope." + s.target)), "%s Lv%d: 대상 범위 먼저" % [sid, lv])
			for tok in _tokens(s, s.level_row(lv)):
				check(t.contains(tok), "%s Lv%d: 「%s」 이 보인다: %s" % [sid, lv, tok, t])
	check(n > 100, "대원·적 스킬 모든 레벨(%d줄)" % n)


func _bare_skill(effect: String, row: Dictionary, target: String = "enemy_one") -> BattleDb.SkillDef:
	var s := BattleDb.SkillDef.new()
	s.id = "skill.test." + effect
	s.name_key = s.id
	s.user = "party"
	s.effect = effect
	s.target = target
	s.range_kind = "melee"
	s.element = "slash"
	s.levels.append(row)
	return s


func test_missing_fields_and_unknown_effects_show_a_marker() -> void:
	_kit()
	var m := SkillSummary.MISSING
	var dmg := SkillSummary.line(texts, _bare_skill("damage", {"tp": 3}), 1)
	check(dmg.contains("위력 " + m) and dmg.contains("명중 " + m), "위력·명중 없는 damage → 「?」(위력 0 을 지어내지 않는다): %s" % dmg)
	check(not dmg.contains("위력 0"), "0 을 지어내지 않는다")
	var buff := SkillSummary.line(texts, _bare_skill("buff", {"tp": 3, "kind": "phys_atk", "turns": 3}, "self"), 1)
	check(buff.contains(m) and not buff.contains("100%"), "value 없는 buff → 「?」(100%% 를 지어내지 않는다): %s" % buff)
	var odd := SkillSummary.line(texts, _bare_skill("explode", {"tp": 3}), 1)
	check(odd.contains(m), "모르는 effect → 「?」: %s" % odd)
	var bind := SkillSummary.line(texts, _bare_skill("damage", {"tp": 3, "power": 90, "accuracy": 900, "bind": {"part": "leg"}}), 1)
	check(bind.contains("이동부 잠금 %s · %s턴" % [m, m]), "확률·턴 없는 봉인 → 「?」: %s" % bind)
	var heal := SkillSummary.line(texts, _bare_skill("heal", {"tp": 3, "base": 10}, "ally_one"), 1)
	check(heal.contains("지혜의 %s%%" % m), "wis_pct 없는 heal: %s" % heal)
	var p := _bare_skill("passive", {})
	check(SkillSummary.line(texts, p, 1).contains(m), "bonus 없는 패시브 → 「?」")
	check(SkillSummary.head(texts, _bare_skill("damage", {"power": 90}), 1).contains("TP " + m), "TP 없는 줄의 머리 → 「TP ?」")
	check_eq(SkillSummary.line(texts, null, 1), m, "정의 없음 → 「?」")


func test_highlighted_skill_shows_description_and_target_keeps_it() -> void:
	var l := await _layer(Vector2(1280, 720))
	var u := l.state.battle.party[1]
	u.skills[LEG_CUTTER] = 2  # 구성: 레벨 2 레그 커터를 가진 듀얼리스트 A
	await _step("command", 0)
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	check_eq([l.member, l.sub], [1, "menu"], "준비: 듀얼리스트 A 명령")
	check(not l.skill_info.visible, "명령 고르기에는 설명 칸이 없다")
	await _step("command", 1)
	check_eq(l.sub, "skills", "스킬 목록")
	check(l.skill_info.visible, "스킬 목록 → 설명 칸")
	var s := l.state.defs.battle.skill(HIGH_SLASH)
	check_eq(l.skill_info_title, "하이 슬래시  Lv 1  TP %d" % int(s.level_row(1)["tp"]), "머리: 이름·레벨·TP")
	check_eq(l.skill_info_text, SkillSummary.line(texts, s, 1), "설명은 SkillSummary 한 곳에서")
	var ids := l._skill_ids()
	var k := ids.find(LEG_CUTTER)
	for i in k:
		await _step("cursor", 1)
	check_eq(l.skill_info_text, SkillSummary.line(texts, l.state.defs.battle.skill(LEG_CUTTER), 2), "커서를 옮기면 그 스킬(레벨 2 줄): %s" % l.skill_info_text)
	check(l.skill_info_text.contains("이동부 잠금 45%"), "레벨 2 봉인 확률이 정의에서")
	await _step("confirm")
	check_eq(l.sub, "target", "대상 고르기")
	check(l.skill_info.visible and l.skill_info_title.begins_with("레그 커터"), "목록에서 고른 스킬의 대상 고르기 동안 설명 그대로")
	await _step("log")
	check(not l.skill_info.visible, "로그 창이 열리면 감춘다")
	await _step("log_close")
	await _step("back")
	await _step("back")
	check_eq(l.sub, "menu", "명령으로 돌아옴")
	await _step("command", 0)
	check(l.sub == "target" and not l.skill_info.visible, "일반 공격의 대상 고르기에는 설명 칸이 없다")
	var dbg: Dictionary = l.debug_info(func(_p, _c): return [0, 0])
	check_eq(dbg["skill_info"], [], "디버그 정보도 비어 있음")


## 스킬이 여섯이어도 목록은 「뒤로」 위 영역 안: 넘치는 줄은 커서·끌기로 내려 본다(전에는 「뒤로」와 패널 밖으로 넘쳤다).
func test_long_skill_list_scrolls_above_back_button() -> void:
	var l := await _layer(Vector2(1280, 720))
	var u := l.state.battle.party[1]
	for sid in [LEG_CUTTER, "skill.blade_duelist.quick_draw", "skill.glyph_wizard.heat_glyph"]:
		u.skills[sid] = 1  # 구성: 스킬 여섯
	await _step("command", 0)
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	await _step("command", 1)
	var p := l.panel
	var n := l._skill_ids().size()
	check_eq(n, 6, "준비: 스킬 여섯")
	var list := _rect(p.skill_list)
	check(list.end.y <= _rect(p.back_button).position.y, "목록은 「뒤로」 위에서 끝난다")
	check(_rect(p).encloses(list), "목록은 패널 안")
	check(p.skill_list.max_scroll() > 0.0, "넘치면 내릴 수 있다")
	for i in n - 1:
		await _step("cursor", 1)
	var last := p.skill_rows[n - 1]
	check(last.selected and p.skill_list.shows(Rect2(last.position, last.size)), "커서를 마지막으로 → 마지막 줄이 보인다")
	await _step("cursor", -1)
	await _step("cursor", -1)
	check(p.skill_list.scroll > 0.0, "위로 조금 옮겨도 끌어 내린 자리는 지킨다")
	while l.cursor > 0:
		await _step("cursor", -1)
	check_eq(p.skill_list.scroll, 0.0, "맨 위 줄로 돌아오면 처음 자리")
	await _step("back")
	await _step("command", 1)
	var c := kit.center_of(p.skill_rows[1])
	kit.touch(0, c, true)
	kit.drag(0, c, c - Vector2(0, 150))
	kit.touch(0, c - Vector2(0, 150), false)
	await kit.frames(3)
	check(p.skill_list.scroll > 0.0, "줄을 끌면 목록이 내려간다")
	check_eq(l.sub, "skills", "끌기는 스킬 고르기가 아니다")
	var vis := p.skill_rows[n - 1]
	if not p.skill_list.shows(Rect2(vis.position, vis.size)):
		p.skill_list.scroll_to(p.skill_list.max_scroll())  # 끌기가 덜 내렸으면 끝까지(누르기는 건너뛰지 않는다)
		await kit.frames(1)
	check(p.skill_list.shows(Rect2(vis.position, vis.size)), "마지막 줄이 보인다")
	await kit.tap(kit.center_of(vis))
	check(l.sub == "target" and l.target_skill == l._skill_ids()[n - 1], "내려서 보인 마지막 줄을 누르면 그 스킬")


func _six_skill_list() -> BattleLayer:
	var l := await _layer(Vector2(1280, 720))
	var u := l.state.battle.party[1]
	for sid in [LEG_CUTTER, "skill.blade_duelist.quick_draw", "skill.glyph_wizard.heat_glyph"]:
		u.skills[sid] = 1  # 구성: 스킬 여섯
	await _step("command", 0)
	await _step("target", {"side": BattleUnit.ENEMY, "slot": 0})
	await _step("command", 1)
	check_eq([l.sub, l._skill_ids().size()], ["skills", 6], "준비: 듀얼리스트 A 스킬 여섯")
	return l


## 커서가 그대로인 다시 그리기(로그 열고 닫기)는 손으로 내린 자리를 지킨다. 커서를 옮길 때만 그 줄로 맞춘다.
func test_redraw_keeps_manual_scroll_until_cursor_moves() -> void:
	var l := await _six_skill_list()
	var p := l.panel
	check_eq([l.cursor, p.skill_list.scroll], [0, 0.0], "준비: 커서 0, 맨 위")
	var c := kit.center_of(p.skill_rows[2])
	kit.touch(0, c, true)
	kit.drag(0, c, c - Vector2(0, 100))
	kit.touch(0, c - Vector2(0, 100), false)
	await kit.frames(3)
	var dragged := p.skill_list.scroll
	check(dragged > 0.0 and l.sub == "skills", "끌어서 내렸다(%.0f)" % dragged)
	await _step("log")
	await _step("log_close")
	check_eq(l.sub, "skills", "로그 닫으면 스킬 목록")
	check_eq(p.skill_list.scroll, dragged, "커서 0 그대로: 다시 그려도 내린 자리 그대로")
	check_eq(l.cursor, 0, "커서 그대로")
	await _step("cursor", 1)
	await _step("cursor", -1)
	check_eq(p.skill_list.scroll, 0.0, "커서를 옮기면 그 줄(커서 0)이 보이게 맞춘다")


## 못 쓰는 줄을 누르면 커서가 그 줄로 가고 설명 칸이 그 스킬을 보인 뒤 이유를 알린다.
func test_tapping_blocked_row_moves_cursor_and_description() -> void:
	var l := await _six_skill_list()
	var p := l.panel
	var u := l.state.battle.party[1]
	u.tp = 4  # 구성: TP 4 → 크로스 스윕(TP 6)은 못 쓴다
	l._refresh()
	await kit.frames(1)
	var k := l._skill_ids().find(CROSS_SWEEP)
	var row := p.skill_rows[k]
	check(row.dimmed and not row.note.is_empty(), "준비: 크로스 스윕 줄은 못 씀(이유: %s)" % row.note)
	check_eq(l.cursor, 0, "준비: 커서 0")
	await kit.tap(kit.center_of(row))
	check_eq(l.sub, "skills", "못 쓰는 줄 누르기 → 목록 그대로")
	check_eq(l.cursor, k, "커서가 누른 줄로")
	check(p.skill_rows[k].selected, "그 줄에 커서 테두리")
	check_eq(l.skill_info_text, SkillSummary.line(texts, l.state.defs.battle.skill(CROSS_SWEEP), 1), "설명 칸이 그 스킬")
	check(l.skill_info_title.begins_with("크로스 스윕"), "설명 머리도")
	check_eq(l._notice, row.note, "이유 알림")
	await _step("confirm")
	check_eq([l.sub, l.cursor], ["skills", k], "이어서 Enter 도 같은 줄(다시 이유만)")


func test_playback_hides_command_panel_and_description() -> void:
	var l := await _layer(Vector2(1280, 720), 1.0)
	await _step("command", 1)
	check(l.panel.visible and l.skill_info.visible, "준비: 스킬 목록·설명")
	await _step("back")
	l.handle("commands", BattlePolicy.choose(l.state, BattlePolicy.DEFAULT))
	await kit.frames(2)
	check_eq(l.phase, "anim", "연출 중")
	check(not l.panel.visible, "연출 중에는 명령 칸이 없다")
	check(not l.skill_info.visible, "설명 칸도 없다")
	check(l.enemy_area.visible and l.party_cards.visible, "무대(적)·대원 칸은 보인다")
	check(l.visible_buttons().is_empty(), "누를 단추 없음(건너뛰기는 화면 누르기)")
	check_eq(l.debug_info(func(_p, _c): return [0, 0])["panel"], false, "디버그 정보: panel false")
	await _step("skip")
	await kit.frames(2)
	if l.phase == "command":
		check(l.panel.visible, "다음 턴 명령에서 다시 보인다")


# ---- U3 스킬 트리 꺾은선 ----

## path 가 a 테두리에서 b 테두리로 가는 가로·세로 꺾은선이고 nodes 의 어느 면도 지나지 않는지.
func _check_path(path: PackedVector2Array, a: Rect2, b: Rect2, nodes: Array, label: String) -> void:
	check(path.size() >= 2, label + ": 점 둘 이상")
	for k in path.size() - 1:
		var d := path[k + 1] - path[k]
		check(is_zero_approx(d.x) != is_zero_approx(d.y), "%s: 토막 %d 은 가로 또는 세로 %s" % [label, k, str(d)])
	var on_edge := func(r: Rect2, p: Vector2) -> bool:
		return r.grow(0.01).has_point(p) and not r.grow(-0.01).has_point(p)
	check(on_edge.call(a, path[0]), "%s: 선행 노드 테두리에서 시작 %s" % [label, str(path[0])])
	check(on_edge.call(b, path[path.size() - 1]), "%s: 뒤 노드 테두리에서 끝 %s" % [label, str(path[path.size() - 1])])
	var crossed := []
	for k in path.size() - 1:
		var n := int(ceil(path[k].distance_to(path[k + 1])))
		for t in n + 1:
			var p := path[k].lerp(path[k + 1], float(t) / maxf(1.0, n))
			for r in nodes:
				if (r as Rect2).grow(-0.5).has_point(p):
					crossed.append(p)
	check(crossed.is_empty(), "%s: 노드 면을 지나지 않는다 %s" % [label, str(crossed.slice(0, 3))])
	var tri := PartySkillTab.arrow_points(path)
	var tip := path[path.size() - 1]
	check_eq(tri[0], tip, label + ": 화살표 끝 = 선 끝")
	var dir := (tip - path[path.size() - 2]).normalized()
	check(b.has_point(tip + dir * 2.0), label + ": 화살표는 뒤 노드 안을 가리킨다")
	check(not b.grow(-0.5).has_point(tri[1]) and not b.grow(-0.5).has_point(tri[2]), label + ": 화살표 밑변은 노드 밖")


func test_connectors_are_orthogonal_with_arrows_and_skip_node_faces() -> void:
	var gap := PartySkillTab.PITCH - PartySkillTab.NODE
	var grid := []
	for col in 4:
		for row in 4:
			grid.append(Rect2(PartySkillTab.FIRST + Vector2(col, row) * PartySkillTab.PITCH, PartySkillTab.NODE))
	var at := func(c: int, r: int) -> Rect2: return grid[c * 4 + r]
	var cases := [[[0, 0], [0, 1], "바로 아래"], [[3, 0], [2, 1], "아래 왼쪽 열"], [[3, 0], [0, 1], "세 열 건너"], [[2, 0], [2, 2], "두 줄 아래"],
		[[0, 0], [3, 3], "멀리"], [[1, 2], [1, 0], "위로"], [[0, 1], [1, 1], "같은 줄 옆"], [[0, 1], [3, 1], "같은 줄 멀리"], [[3, 1], [0, 1], "같은 줄 왼쪽"]]
	for c in cases:
		var a: Rect2 = at.call(c[0][0], c[0][1])
		var b: Rect2 = at.call(c[1][0], c[1][1])
		_check_path(PartySkillTab.connector_path(a, b, gap), a, b, grid, c[2])
	var straight := PartySkillTab.connector_path(at.call(0, 0), at.call(0, 1), gap)
	check_eq(straight.size(), 2, "같은 열 바로 아래는 곧은 선")
	# 실제 직업 트리 넷: 모든 선행 연결
	var defs := Fx.defs()
	for cid in defs.battle.classes:
		var cls: BattleDb.ClassDef = defs.battle.classes[cid]
		var rects := []
		for e in cls.tree:
			rects.append(Rect2(PartySkillTab.FIRST + Vector2(e["pos"][0], e["pos"][1]) * PartySkillTab.PITCH, PartySkillTab.NODE))
		for j in cls.tree.size():
			for r in cls.tree[j].get("requires", []):
				var i := int(cls.tree_index[r["skill"]])
				_check_path(PartySkillTab.connector_path(rects[i], rects[j], gap), rects[i], rects[j], rects, "%s → %s" % [r["skill"], cls.tree[j]["skill"]])


# ---- U4 창 단추 ----

static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func test_menu_buttons_have_borders_and_clear_checked_and_selected_states() -> void:
	_kit()
	var s := await kit.open("native", 7)
	s._save_slot("slot1")
	await kit.frames(2)
	s._open_menu()
	await kit.frames(3)
	check_eq(s.modal.kind, "menu", "준비: 메뉴")
	var buttons: Array = s.modal.find_children("*", "Button", true, false)
	check(buttons.size() >= 12, "단추 %d개" % buttons.size())
	var warm := func(c: Color) -> bool: return c.r > 0.9 and c.g > 0.7 and c.b < 0.5
	var disabled_seen := 0
	for bb in buttons:
		var b := bb as Button
		var sb := (b.get_theme_stylebox("normal") as UiTheme.Box).look
		var focus := (b.get_theme_stylebox("focus") as UiTheme.Box).look
		var dis := (b.get_theme_stylebox("disabled") as UiTheme.Box).look
		check(sb["inner_w"] >= 1.0 and minf(contrast(sb["inner"], sb["top"]), contrast(sb["inner"], sb["bottom"])) >= 1.8, "%s: 보이는 테두리(안쪽 선)" % b.name)
		check(dis["inner_w"] >= 1.0 and contrast(dis["inner"], dis["bottom"]) >= 1.5, "%s: 못 누름도 칸 테두리" % b.name)
		# Godot 가 실제로 겹쳐 그리는 짝: 상태 채움(위·아래 색, + 포커스면 그 위 focus 상자, 채움이 있으면 그 색) 과 그 상태의 글자색
		var under := dis if b.disabled else sb
		var focus_fill: Dictionary = focus if focus["fill"] else under
		var pairs := []
		if b.disabled:
			disabled_seen += 1
			pairs = [[dis, b.get_theme_color("font_disabled_color"), "못 누름"], [focus_fill, b.get_theme_color("font_disabled_color"), "못 누름 + 포커스"]]
			check(not focus["fill"] and focus["outer_w"] >= 3.0 and warm.call(focus["outer"]) and warm.call(focus["marker"]),
				"%s: 못 누르는 단추도 포커스는 따뜻한 굵은 테두리 + 표시 막대" % b.name)
		else:
			pairs = [[sb, b.get_theme_color("font_color"), "평소"], [focus_fill, b.get_theme_color("font_focus_color"), "포커스"],
				[(b.get_theme_stylebox("hover") as UiTheme.Box).look, b.get_theme_color("font_hover_color"), "포인터 위"],
				[(b.get_theme_stylebox("pressed") as UiTheme.Box).look, b.get_theme_color("font_pressed_color"), "누름"]]
			check(focus["fill"] and warm.call(focus["bottom"]) and warm.call(focus["top"]), "%s: 고른 것은 따뜻한 채움" % b.name)
			check(focus["outer_w"] > sb["outer_w"] and (focus["marker"] as Color).a > 0.0, "%s: 고른 것은 색 말고도 굵은 테두리 + 표시 막대" % b.name)
		for p in pairs:
			var c := minf(contrast(p[0]["top"], p[1]), contrast(p[0]["bottom"], p[1]))
			check(c >= 4.5, "%s %s: 글자 대비 %.1f" % [b.name, p[2], c])
	check(disabled_seen >= 2, "못 누르는 단추(빈 불러오기 칸)도 보았다(%d)" % disabled_seen)
	var mode: String = s.settings.automap
	for m in ExplorationRules.AUTOMAP_MODES:
		var ab: Button = s.modal.find_child("Automap_" + m, true, false)
		check_eq(ModalLayer.is_checked(ab), m == mode, "자동 지도 %s 켜짐 = 지금 설정" % m)
		var nb := (ab.get_theme_stylebox("normal") as UiTheme.Box).look
		if m == mode:
			check(nb["bottom"] == UiTheme.BTN_CHECKED and contrast(nb["bottom"], ab.get_theme_color("font_color")) >= 4.5, "켜진 단추: 밝은 채움 + 어두운 글자")
	var load1: Button = s.modal.find_child("Load_slot1", true, false)
	load1.grab_focus()
	await kit.frames(1)
	check(load1.has_focus(), "키보드 포커스")
	var lines := load1.text.split("\n")
	check_eq(lines.size(), 3, "채운 저장 칸 세 줄: %s" % str(lines))
	check_eq(lines[0], "슬롯 1", "슬롯 번호")
	check_eq(lines[1], "%s · 걸음 %d" % [texts.t(s.floor_def.name_key), s.state.steps], "층·걸음(저장에 있는 값)")
	check(not load1.disabled, "채운 칸은 불러올 수 있다")
	var load2: Button = s.modal.find_child("Load_slot2", true, false)
	check(load2.disabled and load2.text == "슬롯 2\n비어 있음", "빈 칸: 「비어 있음」, 못 누름")
	load2.grab_focus()
	await kit.frames(1)
	check(load2.has_focus(), "빈 칸도 키보드 포커스는 받는다(이동이 건너뛰지 않는다)")
	check(load2.custom_minimum_size.y >= 64.0, "저장 칸 높이 64 이상")


# ---- U5 대원 HP 막대 색 ----

func test_hp_color_thresholds() -> void:
	var cases := [[100, 100, "green"], [51, 100, "green"], [50, 100, "orange"], [31, 100, "orange"], [30, 100, "red"], [0, 100, "red"],
		[26, 52, "orange"], [27, 52, "green"], [16, 52, "orange"], [15, 50, "red"], [12, 40, "red"], [13, 40, "orange"], [1, 0, "red"]]
	for c in cases:
		check_eq(HpColor.level(c[0], c[1]), c[2], "%d/%d" % [c[0], c[1]])
	check_eq(HpColor.of(50.5, 100.0), HpColor.GREEN, "연출 중 소수 HP: 50% 넘음")
	check_eq(HpColor.of(30.0, 100.0), HpColor.RED, "정확히 30%")


func test_every_member_hp_bar_uses_the_rule() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	var hp := [31, 26, 16, 12, 12]
	for i in hp.size():
		s.state.party.members[i].hp = hp[i]
	s.status.refresh()
	for i in hp.size():
		var m := s.state.party.members[i]
		check_eq(s.status.hp_bar_color(i), HpColor.of(m.hp, m.max_hp), "탐색 상태 칸 %d (%d/%d)" % [i, m.hp, m.max_hp])
	check_eq(s.status.hp_bar_color(1), HpColor.ORANGE, "26/52 = 50% → 주황")
	check_eq(s.status.hp_bar_color(4), HpColor.RED, "12/40 = 30% → 빨강")
	await kit.press_key(KEY_P)
	var pm := s.party_menu
	for i in hp.size():
		check_eq(pm.cells[i].hp_bar_color(), s.status.hp_bar_color(i), "파티 메뉴 대원 칸 %d" % i)
	await kit.press_key(KEY_ESCAPE)
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for k in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	check(s.battle_layer.is_open(), "준비: 전투")
	await kit.frames(3)
	for c in s.battle_layer.party_cards.cards:
		var u := c.unit()
		check_eq(c.hp_bar_color(), HpColor.of(u.hp, u.max_hp), "전투 대원 칸 %s (%d/%d)" % [u.name, u.hp, u.max_hp])
	check_eq(s.battle_layer.party_cards.cards[2].hp_bar_color(), HpColor.ORANGE, "16/52 = 30.8% → 주황")
	check_eq(s.battle_layer.party_cards.cards[3].hp_bar_color(), HpColor.RED, "12/42 = 28.6% → 빨강")


# ---- 글꼴: 화면 문구의 모든 글자가 넣어 둔 글꼴에 있다 ----

func test_every_text_character_is_in_the_bundled_font() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom_font"))
	var font := load(path) as Font
	check(font != null, "글꼴 %s" % path)
	var f := FileAccess.open("res://data/text/ko.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var missing := {}
	for k in d:
		var v := str(d[k])
		for i in v.length():
			var code := v.unicode_at(i)
			if code < 32:
				continue  # 줄바꿈 등
			if not font.has_char(code):
				missing["U+%04X %s" % [code, v[i]]] = k
	check(missing.is_empty(), "글꼴에 없는 글자: %s" % str(missing))
	check(not font.has_char(0x00D7), "확인: 이 글꼴에는 「×」가 없다(문구에 쓰면 위 검사가 잡는다)")
