extends TestCase
## 성장 규칙 시험(07 §10.1): 경험치 나누기(D19)·끝 거부·끝 상태 저장·대원별 결과·레벨업·SP·배분·장착·능력치 묶음·보급.
## 모두 기능 확인이다(D15): 승패·시드에 기대지 않고, 결과가 필요한 곳은 상태를 구성으로 만든다(적 HP 0·처치 기록, 06 §10.1 방식).

const Fx := preload("res://tests/fixtures.gd")

const RATS := "formation.f1.rats"
const HS := "skill.blade_duelist.high_slash"
const CROSS := "skill.blade_duelist.cross_sweep"
const OVERCLOCK := "skill.blade_duelist.overclock"
const BLADE_M := "skill.blade_duelist.blade_mastery"
const LEG := "skill.blade_duelist.leg_cutter"
const QUICK := "skill.blade_duelist.quick_draw"
const FG := "skill.holo_knight.front_guard"
const SHIELD_M := "skill.holo_knight.shield_mastery"
const HEAT := "skill.glyph_wizard.heat_glyph"
const CORRODE := "skill.glyph_wizard.corrode_glyph"
const GLYPH_M := "skill.glyph_wizard.glyph_mastery"
const ION := "equip.ion_saber"

var _q: GameDefs


# ---- 도우미 ----

## data/ 사본에 적만 아무것도 하지 않는 파일 묶음(Fx.quiet_defs 와 같은 구성). mutate 로 더 고친다.
func _quiet_files(rules: Dictionary = {}) -> Dictionary:
	var files := Fx.battle_files({"skills/test.json": {"skills": [Fx.mend_skill()]}}, rules)
	for path in files:
		if str(path).begins_with("enemies/"):
			for e in files[path]["enemies"]:
				e["ai"] = [{"if": {"turn_mod": [1, 0]}, "use": [{"skill": Fx.MEND, "weight": 1, "target": "random"}]}] + e["ai"]
	return files


func _quiet() -> GameDefs:
	if _q == null:
		_q = Fx.defs_from(_quiet_files())
	return _q


## 적 exp 를 바꾼 조용한 정의.
func _quiet_exp(enemy_exp: int, growth: Dictionary = {}) -> GameDefs:
	var files := _quiet_files()
	for path in files:
		if str(path).begins_with("enemies/"):
			for e in files[path]["enemies"]:
				e["exp"] = enemy_exp
	return Fx.defs_from(Fx.with_growth(files, growth))


func _cum(defs: GameDefs, level: int) -> int:
	return defs.battle.growth.cum(level)


## 대원을 그 레벨·누적 경험치로 두고 HP·TP 를 가득 채운다(시험 준비).
func _set_level(s: ExplorationState, i: int, level: int, xp: int) -> void:
	var m := s.party.members[i]
	m.level = level
	m.exp = xp
	GrowthRules.refresh_max(s.defs, i, m)
	m.hp = m.max_hp
	m.tp = m.max_tp


## 전투를 연 상태(인카운트처럼 위험도 = 한계값). prep 은 전투를 열기 전에 상태를 고친다.
func _battle(defs: GameDefs, prep: Callable = Callable(), formation: String = RATS, seed_value: int = 3) -> ExplorationState:
	var s := ExplorationRules.new_game(defs, seed_value, "floor")
	if prep.is_valid():
		prep.call(s)
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, formation)
	return s


## 적을 모두 처치(처치 기록 있음)하고 down 칸 대원을 쓰러뜨린 전투 상태. 끝 판정은 하지 않는다(finish 를 시험이 부른다).
func _won(defs: GameDefs, down: Array = [], prep: Callable = Callable()) -> ExplorationState:
	var s := _battle(defs, prep)
	var ev: Array[Dictionary] = []
	for u in s.battle.enemies:
		BattleRules.damage_unit(s, u, u.hp, s.battle.party[0], "slash", "attack", ev, {})
	for i in down:
		s.party.members[i].hp = 0
	return s


func _end(events: Array[Dictionary]) -> Dictionary:
	var e := Fx.of_type(events, "battle_end")
	return e[0] if e.size() == 1 else {}


## 상태 해시·난수·전투 사전·위험도·소재를 한 묶음으로(거부 시험의 「불변」).
func _snap(s: ExplorationState) -> String:
	return JSON.stringify([SaveCodec.state_hash(s), str(s.rng.get_state()), s.battle.to_dict() if s.battle != null else null,
		s.encounter.danger, s.encounter.pending, s.materials, s.gear_bag, s.wiped], "", true)


func _reject(label: String, s: ExplorationState, call: Callable, reason: String) -> void:
	var before := _snap(s)
	var ev: Array = call.call()
	check(ev.size() == 1 and ev[0]["type"] == "rejected" and ev[0]["reason"] == reason, "%s: rejected{%s} 하나: %s" % [label, reason, str(ev)])
	check_eq(_snap(s), before, "%s: 상태·난수 불변" % label)


func _saves_same(s: ExplorationState, label: String) -> void:
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok(), "%s: 저장 → 읽기 성공 %s" % [label, r.error])
	if r.ok():
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "%s: 같은 해시" % label)


func _new(defs: GameDefs = null) -> ExplorationState:
	return ExplorationRules.new_game(defs if defs != null else Fx.defs(), 1, "floor")


func _sp99() -> GameDefs:
	return Fx.defs_from(Fx.with_growth(Fx.battle_files(), {"initial_sp": 99}))


# ---- 경험치 나누기 (D19) ----

func test_exp_split_by_alive_members() -> void:
	var want := {5: 7, 4: 9, 3: 12, 2: 18, 1: 36}
	for n in [5, 4, 3, 2, 1]:
		var s := _won(_quiet(), range(n, 5))
		var ev: Array[Dictionary] = []
		check(BattleRules.finish(s, "victory", ev), "살아 있는 %d: 승리" % n)
		var end := _end(ev)
		check_eq([end.get("exp_total"), end.get("exp_alive"), end.get("exp_share")], [36, n, want[n]], "살아 있는 %d: E 36 ÷ %d" % [n, n])
		for i in 5:
			var r: Dictionary = end["members"][i]
			if i < n:
				check_eq([r["member"], r["status"], r["gained"], r["capped"]], [i, "received", want[n], false], "살아 있는 %d: 대원 %d 받음" % [n, i])
				check_eq(s.party.members[i].exp, want[n], "살아 있는 %d: 대원 %d exp" % [n, i])
			else:
				check_eq([r["status"], r["gained"], r["capped"], r["from"], r["to"]], ["down", 0, false, 1, 1], "살아 있는 %d: 대원 %d 전투 불능" % [n, i])
				check_eq(s.party.members[i].exp, 0, "살아 있는 %d: 쓰러진 대원 exp 그대로" % n)
		check_eq(Fx.of_type(ev, "exp").map(func(e): return e["member"]), range(n), "살아 있는 %d: exp 이벤트는 살아 있는 대원마다" % n)


func test_exp_cap_member_counts_and_share_not_redistributed() -> void:
	var s := _won(_quiet(), [], func(st): _set_level(st, 2, 30, _cum(st.defs, 30)))
	var ev: Array[Dictionary] = []
	check(BattleRules.finish(s, "victory", ev), "승리")
	var end := _end(ev)
	check_eq([end["exp_alive"], end["exp_share"]], [5, 7], "분모는 상한 대원 포함 살아 있는 인원")
	check_eq([end["members"][2]["status"], end["members"][2]["gained"], end["members"][2]["capped"]], ["at_cap", 0, true], "상한 대원")
	for i in [0, 1, 3, 4]:
		check_eq(end["members"][i]["gained"], 7, "대원 %d 몫 그대로(다시 나누지 않음)" % i)
	check_eq(Fx.of_type(ev, "exp").size(), 5, "상한 대원도 exp 이벤트(gained 0)")


func test_exp_without_kill_records_and_other_outcomes() -> void:
	# 처치 기록 없는 강제 승리: E 0, 성장 필드는 있고 모든 gained 0, exp 이벤트 없음.
	var s := _battle(_quiet())
	var ev: Array[Dictionary] = []
	check(BattleRules.finish(s, "victory", ev), "적이 살아 있는 강제 승리는 받는다")
	var end := _end(ev)
	check_eq([end["exp_total"], end["exp_share"], end["members"].map(func(r): return r["gained"])], [0, 0, [0, 0, 0, 0, 0]], "E 0")
	check(Fx.of_type(ev, "exp").is_empty() and Fx.of_type(ev, "level_up").is_empty(), "exp 이벤트 없음")
	# 도주·턴 상한·전멸: 성장 필드·이벤트 없음, exp 그대로.
	for c in [["escaped", ""], ["escaped", "turn_cap"], ["wiped", ""]]:
		var t := _won(_quiet(), [0, 1, 2, 3, 4] if c[0] == "wiped" else [])
		var ev2: Array[Dictionary] = []
		check(BattleRules.finish(t, c[0], ev2, c[1]), "%s%s 받음" % c)
		var e2 := _end(ev2)
		check(not e2.has("exp_total") and not e2.has("members"), "%s%s: 성장 필드 없음 %s" % [c[0], c[1], str(e2.keys())])
		check(Fx.of_type(ev2, "exp").is_empty(), "%s: exp 이벤트 없음" % c[0])
		check_eq(t.party.members.map(func(m): return m.exp), [0, 0, 0, 0, 0], "%s: exp 그대로" % c[0])


func test_exp_uses_no_random_numbers() -> void:
	var a := _won(_quiet())
	var b := _won(_quiet_exp(0))
	check_eq(str(a.rng.get_state()), str(b.rng.get_state()), "준비: 같은 난수 상태")
	BattleRules.finish(a, "victory")
	BattleRules.finish(b, "victory")
	check_eq(str(a.rng.get_state()), str(b.rng.get_state()), "경험치 있음·없음이 같은 난수 소비")
	check(a.party.members[0].exp == 7 and b.party.members[0].exp == 0, "경험치는 한쪽만")


# ---- 살아 있는 아군 0·끝 거부 ----

func test_exp_share_pure_function() -> void:
	check_eq(GrowthRules.exp_share(36, 0), 0, "살아 있는 0 → 0(나누기 0 방어)")
	check_eq([1, 2, 3, 4, 5].map(func(n): return GrowthRules.exp_share(36, n)), [36, 18, 12, 9, 7], "36 ÷ 1~5")


func test_finish_refuses_outcome_that_mismatches_party_down() -> void:
	var s := _battle(_quiet())
	for m in s.party.members:
		m.hp = 0
	check(s.battle != null and s.encounter.pending and not s.wiped, "준비: 전투 중·pending·wiped 거짓·아군 전원 HP 0")
	var before := _snap(s)
	for c in [["victory", ""], ["escaped", ""], ["escaped", "turn_cap"]]:
		var ev: Array[Dictionary] = []
		check(not BattleRules.finish(s, c[0], ev, c[1]), "살아 있는 아군 없는 %s%s 거부" % c)
		check(ev.is_empty(), "%s: events 그대로" % c[0])
		check_eq(_snap(s), before, "%s%s: 상태·난수·전투·위험도·소재 불변" % c)
		check(not s.wiped and s.battle != null, "%s: 전멸로 바꾸지 않음" % c[0])
	var t := _battle(_quiet())
	t.party.members[0].hp = 0
	var b2 := _snap(t)
	check(not BattleRules.finish(t, "wiped"), "살아 있는 대원이 있으면 전멸 거부(M2 그대로)")
	check_eq(_snap(t), b2, "불변")
	check(BattleRules.finish(t, "victory"), "적이 살아 있는 강제 승리(살아 있는 대원 있음)는 받음")


func test_every_accepted_end_state_can_be_saved() -> void:
	var cases := []
	for n in [1, 2, 3, 4, 5]:
		cases.append(["승리 살아 있는 %d" % n, _won(_quiet(), range(n, 5)), "victory", ""])
	cases.append(["승리 레벨업·상한", _won(_quiet(), [], _prep_up_and_cap), "victory", ""])
	cases.append(["처치 기록 없는 강제 승리", _battle(_quiet()), "victory", ""])
	var partial := _battle(_quiet())
	BattleRules.damage_unit(partial, partial.battle.enemies[0], partial.battle.enemies[0].hp, partial.battle.party[0], "slash", "attack", [] as Array[Dictionary], {})
	cases.append(["적이 살아 있는 강제 승리(처치 기록 하나)", partial, "victory", ""])
	cases.append(["도주", _battle(_quiet()), "escaped", ""])
	cases.append(["턴 상한", _battle(_quiet()), "escaped", "turn_cap"])
	cases.append(["강제 전멸", _won(_quiet(), [0, 1, 2, 3, 4]), "wiped", ""])
	for c in cases:
		var s: ExplorationState = c[1]
		check(BattleRules.finish(s, c[2], [] as Array[Dictionary], c[3]), "%s: finish 받음" % c[0])
		_saves_same(s, c[0])
	# 자연 전멸: 모두 HP 1·독 → 턴 끝 독으로 쓰러짐 → 끝 판정이 전멸.
	var w := _battle(_quiet())
	for u in w.battle.party:
		u.hp = 1
		u.ailment = "poison"
		u.ailment_turns = 3
		u.ailment_damage = 5
	var ev := BattleRules.submit(w, Fx.cmds(w))
	check(w.wiped and w.battle == null and _end(ev).get("outcome") == "wiped", "자연 전멸: %s" % str(Fx.types(ev)))
	_saves_same(w, "자연 전멸")


## 대원 1 Lv29(상한 7 앞), 대원 2 Lv30.
func _prep_up_and_cap(st: ExplorationState) -> void:
	_set_level(st, 1, 29, _cum(st.defs, 30) - 7)
	_set_level(st, 2, 30, _cum(st.defs, 30))


# ---- 대원별 결과 ----

## capped 의 네 경우(몫 7): 대원 1 cum(30) − 7, 대원 2 cum(30) − 3, 대원 3 Lv30, 대원 0·4 Lv1.
func _prep_four_cases(st: ExplorationState) -> void:
	var cap := _cum(st.defs, 30)
	_set_level(st, 1, 29, cap - 7)
	_set_level(st, 2, 29, cap - 3)
	_set_level(st, 3, 30, cap)


func test_battle_end_members_and_four_capped_cases() -> void:
	var defs := _quiet()
	var cap := _cum(defs, 30)
	var s := _won(defs, [], _prep_four_cases)
	var before := s.party.members.map(func(m): return [m.level, m.exp, m.hp, m.tp, m.max_hp, m.max_tp])
	var ev: Array[Dictionary] = []
	BattleRules.finish(s, "victory", ev)
	var rows: Array = _end(ev)["members"]
	var want := [
		["received", 7, false, 1, 1, 0], ["received", 7, false, 29, 30, 1], ["received", 3, true, 29, 30, 1],
		["at_cap", 0, true, 30, 30, 0], ["received", 7, false, 1, 1, 0],
	]
	for i in 5:
		var r: Dictionary = rows[i]
		var m := s.party.members[i]
		check_eq([r["status"], r["gained"], r["capped"], r["from"], r["to"], r["sp_gained"]], want[i], "대원 %d 결과" % i)
		check_eq([m.level, m.exp - before[i][1]], [r["to"], r["gained"]], "대원 %d: 결과 = 상태 변화(레벨·exp)" % i)
		check_eq([m.hp - before[i][2], m.tp - before[i][3]], [r["hp_gain"], r["tp_gain"]], "대원 %d: hp_gain·tp_gain = 현재값 변화" % i)
		check_eq([r["hp_gain"], r["tp_gain"]], [m.max_hp - before[i][4], m.max_tp - before[i][5]], "대원 %d: 늘어난 최대만큼" % i)
	check_eq([s.party.members[1].exp, s.party.members[2].exp], [cap, cap], "상한에 닿으면 exp = cum(30)")
	check(rows[1]["hp_gain"] > 0, "Lv29 → 30 에 HP 가 늘었다(레벨 표)")
	var ups := Fx.of_type(ev, "level_up")
	check_eq(ups.map(func(e): return [e["member"], e["from"], e["to"]]), [[1, 29, 30], [2, 29, 30]], "level_up 둘")
	check_eq(ups[0]["stats"], GrowthRules.profile(defs, 1, s.party.members[1])["stats"], "level_up.stats = 새 능력치")
	check_eq([ups[0]["max_hp"], ups[0]["max_tp"]], [s.party.members[1].max_hp, s.party.members[1].max_tp], "level_up 새 최대")
	# battle 이 지워진 뒤에도 이벤트 값은 복사본이다.
	s.party.members[1].level = 5
	s.party.members[1].hp = 1
	check_eq([rows[1]["to"], ups[0]["to"], ups[0]["max_hp"]], [30, 30, GrowthRules.profile(defs, 1, _lv30(s, 1))["max_hp"]], "이벤트 값 그대로")


func _lv30(s: ExplorationState, i: int) -> PartyState.Member:
	var m := PartyState.Member.new(s.party.members[i].id)
	m.class_id = s.party.members[i].class_id  # M3 A7: 직업은 대원이 가진다
	m.level = 30
	m.skills = s.party.members[i].skills
	m.equip = s.party.members[i].equip
	return m


func test_zero_share_and_sp_per_level() -> void:
	# E 3, 살아 있는 5 → 몫 0: 모두 gained 0·capped 거짓(상한 대원도).
	var defs := _quiet_exp(1)
	var s := _won(defs, [], func(st): _set_level(st, 3, 30, _cum(st.defs, 30)))
	var ev: Array[Dictionary] = []
	BattleRules.finish(s, "victory", ev)
	var end := _end(ev)
	check_eq([end["exp_total"], end["exp_share"]], [3, 0], "E 3 ÷ 5 = 0")
	check_eq(end["members"].map(func(r): return [r["gained"], r["capped"]]), [[0, false], [0, false], [0, false], [0, false], [0, false]], "모두 0·거짓")
	check_eq(end["members"][3]["status"], "at_cap", "상한 대원 상태")
	check_eq(Fx.of_type(ev, "exp").size(), 5, "E > 0 이면 몫 0 이어도 exp 이벤트")
	# sp_per_level 2: 두 레벨 오르면 sp_gained 4(레벨 차이 2 와 다름).
	var t := _won(_quiet_exp(40, {"sp_per_level": 2}), [1, 2, 3, 4])
	var ev2: Array[Dictionary] = []
	BattleRules.finish(t, "victory", ev2)
	var r: Dictionary = _end(ev2)["members"][0]
	check_eq([r["gained"], r["from"], r["to"], r["sp_gained"]], [120, 1, 3, 4], "120 받아 Lv3, SP +4")
	check_eq(GrowthRules.sp_left(t.defs, t.party.members[0]), 3 + 2 * 2 - 3, "남은 SP 가 자동으로 는다")


# ---- 레벨업 ----

func test_gain_exp_levels_caps_and_partial_hp() -> void:
	var s := _new()
	var cap := _cum(s.defs, 30)
	var ev: Array[Dictionary] = []
	s.party.members[0].exp = 29
	var r := GrowthRules.gain_exp(s, 0, 1, ev)
	check_eq([r["from"], r["to"], r["gained"], r["capped"]], [1, 2, 1, false], "cum(2) − 1 에서 1 → 한 레벨")
	check_eq(Fx.types(ev), ["exp", "level_up"] as Array[String], "exp 다음 level_up")
	ev.clear()
	r = GrowthRules.gain_exp(s, 1, 300, ev)
	check_eq([r["from"], r["to"], s.party.members[1].exp], [1, 4, 300], "큰 양 → 여러 레벨 한 번에")
	check_eq(Fx.of_type(ev, "level_up").map(func(e): return [e["from"], e["to"]]), [[1, 4]], "level_up 하나")
	_set_level(s, 2, 29, cap - 5)
	ev.clear()
	r = GrowthRules.gain_exp(s, 2, 1000, ev)
	check_eq([r["to"], r["gained"], r["capped"], s.party.members[2].exp], [30, 5, true, cap], "상한을 넘기는 양 → exp = cum(30)·capped")
	_set_level(s, 3, 29, cap - 7)
	r = GrowthRules.gain_exp(s, 3, 7, ev)
	check_eq([r["to"], r["gained"], r["capped"]], [30, 7, false], "정확히 cum(30) 까지 → capped 거짓")
	ev.clear()
	r = GrowthRules.gain_exp(s, 3, 5, ev)
	check_eq([r["to"], r["gained"], r["capped"], s.party.members[3].exp], [30, 0, true, cap], "상한 대원이 더 받음 → 그대로·capped")
	check_eq(Fx.types(ev), ["exp"] as Array[String], "level_up 없음")
	var g := GrowthRules.grant_exp(s, 3, 5)
	check_eq([g.size(), g[0]["type"], g[0]["gained"], g[0]["capped"]], [1, "exp", 0, true], "grant_exp 도 같은 함수")


func test_level_up_max_is_table_plus_passive_and_adds_only_gain() -> void:
	var s := _new()
	var m := s.party.members[0]
	m.skills[SHIELD_M] = 1  # 시험 준비: 패시브(최대 HP +3)를 배운 상태
	GrowthRules.refresh_max(s.defs, 0, m)
	check_eq(m.max_hp, 63, "Lv1 60 + 패시브 3")
	m.hp = 50
	m.tp = 20
	var ev: Array[Dictionary] = []
	var r := GrowthRules.gain_exp(s, 0, 30, ev)
	check_eq([m.level, m.max_hp, m.max_tp], [2, 64 + 3, 31], "Lv2 최대 = 레벨 표 + 패시브")
	check_eq([m.hp, m.tp, r["hp_gain"], r["tp_gain"]], [54, 21, 4, 1], "현재 HP·TP 는 늘어난 만큼만(가득 채우지 않음)")
	# HP 0 대원(나노 메딕 Lv1 HP 42·TP 54 표)에게 grant_exp → 레벨이 오르고 HP 0 그대로, TP 는 늘어난 최대만큼(Lv2 TP 56, +2).
	var md := s.party.members[3]
	md.hp = 0
	md.tp = 10
	var g := GrowthRules.grant_exp(s, 3, 30)
	var up := Fx.of_type(g, "level_up")
	check_eq([md.level, md.max_hp, md.max_tp], [2, 44, 56], "메딕 Lv2 최대(레벨 표)")
	check_eq([md.hp, up[0]["hp_gain"]], [0, 0], "HP 0 은 그대로")
	check_eq([md.tp, up[0]["tp_gain"]], [12, 2], "HP 0 대원도 TP 는 늘어난 만큼(10 → 12)")
	# HP 0 대원의 패시브 배분(나노 마스터리 Lv1: 최대 TP +2) → max_changed 의 hp_gain 0·tp_gain 2, TP 12 → 14.
	var ev3 := GrowthRules.allocate(s, 3, {"skill.nano_medic.nano_mastery": 1})
	check_eq(Fx.types(ev3), ["skills_learned", "max_changed"] as Array[String], "패시브가 최대 TP 를 바꿈")
	check_eq(ev3[1], {"type": "max_changed", "member": 3, "max_hp": 44, "max_tp": 58, "hp_gain": 0, "tp_gain": 2}, "max_changed 양")
	check_eq([md.hp, md.tp, md.max_tp], [0, 14, 58], "HP 0 그대로·TP 는 늘어난 만큼")


## 허용 범위 끝의 시험용 성장 규칙(level_cap 2, exp_next [999999])과 홀로나이트 Lv1·Lv2 줄.
func _cap2_files(lv1: int, lv2: int) -> Dictionary:
	var files := Fx.with_growth(Fx.battle_files(), {"level_cap": 2, "exp_next": [999999]})
	for path in files:
		if str(path).begins_with("classes/"):
			var c: Dictionary = files[path]
			c["levels"] = {"1": c["levels"]["1"], "2": c["levels"]["1"].duplicate()}
			for e in c["tree"]:
				e["min_level"] = mini(int(e["min_level"]), 2)
	var hk: Dictionary = files["classes/holo_knight.json"]["levels"]
	hk["1"]["hp"] = lv1
	hk["1"]["tp"] = lv1
	hk["2"]["hp"] = lv2
	hk["2"]["tp"] = lv2
	return files


func test_level_table_boundaries_and_save() -> void:
	var defs := Fx.defs_from(_cap2_files(1, 9999))
	var s := ExplorationRules.new_game(defs, 1, "floor")
	var m := s.party.members[0]
	check_eq([m.max_hp, m.hp, m.max_tp], [1, 1, 1], "Lv1 HP·TP 1")
	m.exp = _cum(defs, 2) - 1
	var r := GrowthRules.gain_exp(s, 0, 1, [] as Array[Dictionary])
	check_eq([m.level, m.hp, m.tp, r["hp_gain"]], [2, 9999, 9999, 9998], "Lv2·HP·TP 9999")
	Fx.clean_saves()
	var store := SaveStore.new(defs, Fx.SAVE_DIR)
	check_eq(store.save(SaveStore.AUTO, s), "", "자동 저장 경로로 저장")
	var l := store.load_slot(SaveStore.AUTO)
	check(l.result != null and l.result.ok(), "읽기 성공")
	if l.result != null and l.result.ok():
		check_eq(SaveCodec.state_hash(l.result.state), SaveCodec.state_hash(s), "같은 해시")
	Fx.clean_saves()
	var flat := Fx.defs_from(_cap2_files(5, 5))
	var t := ExplorationRules.new_game(flat, 1, "floor")
	t.party.members[0].exp = _cum(flat, 2) - 1
	check_eq(GrowthRules.gain_exp(t, 0, 1, [] as Array[Dictionary])["hp_gain"], 0, "Lv1 = Lv2 표도 받음(hp_gain 0)")
	var errs := Fx.battle_db(_cap2_files(9, 8)).errors
	check(errs.any(func(e: String) -> bool: return e.contains("classes/holo_knight.json: levels.2.hp: 앞 레벨보다 작다")), "Lv2 HP < Lv1 → 읽기 오류: %s" % str(errs))


# ---- SP ----

func test_sp_formula() -> void:
	var defs := Fx.defs()
	check_eq([GrowthRules.sp_total(defs, 1), GrowthRules.sp_total(defs, 5), GrowthRules.sp_total(defs, 30)], [3, 7, 32], "얻은 SP")
	var s := _new()
	check_eq(s.party.members.map(func(m): return GrowthRules.sp_left(defs, m)), [0, 0, 0, 0, 0], "시작 배분은 SP 3 을 다 쓴다")
	GrowthRules.grant_exp(s, 1, _cum(defs, 5))
	check_eq(GrowthRules.sp_left(defs, s.party.members[1]), 7 - 3, "Lv5 남은 SP = 7 − 3")


# ---- 배분 ----

## 듀얼리스트 A 를 Lv3(남은 SP 2)으로 둔 새 게임.
func _lv3(defs: GameDefs = null) -> ExplorationState:
	var s := _new(defs)
	GrowthRules.grant_exp(s, 1, _cum(s.defs, 3))
	return s


func test_allocate_accepts_prerequisite_in_same_draft_and_passive_max() -> void:
	var s := _lv3()
	var ev := GrowthRules.allocate(s, 1, {LEG: 1, HS: 2})
	check_eq(Fx.types(ev), ["skills_learned"] as Array[String], "max_changed 없음(패시브 없음)")
	check_eq(ev[0]["changes"], [{"skill": HS, "from": 1, "to": 2}, {"skill": LEG, "from": 0, "to": 1}], "트리 순 changes")
	check_eq([ev[0]["member"], ev[0]["sp_left"], s.party.members[1].skills.get(LEG), s.party.members[1].skills.get(HS)], [1, 0, 1, 2], "한 초안에서 선행과 다음 스킬")
	var t := _new()
	GrowthRules.grant_exp(t, 0, 30)
	var hp := t.party.members[0].hp
	var ev2 := GrowthRules.allocate(t, 0, {SHIELD_M: 1})
	check_eq(Fx.types(ev2), ["skills_learned", "max_changed"] as Array[String], "패시브로 최대 HP 오름")
	check_eq([ev2[1]["max_hp"], ev2[1]["hp_gain"], ev2[1]["tp_gain"], t.party.members[0].hp], [67, 3, 0, hp + 3], "max_changed 와 현재 HP")


func test_allocate_rejections_keep_state() -> void:
	var s := _lv3()
	var b := _battle(Fx.defs())
	_reject("전투 중", b, func(): return GrowthRules.allocate(b, 1, {HS: 2}), "not_now")
	var w := _lv3()
	w.wiped = true
	_reject("전멸", w, func(): return GrowthRules.allocate(w, 1, {HS: 2}), "not_now")
	_reject("다른 직업 스킬", s, func(): return GrowthRules.allocate(s, 1, {FG: 1}), "unknown_skill")
	_reject("모르는 ID", s, func(): return GrowthRules.allocate(s, 1, {"skill.blade_duelist.nope": 1}), "unknown_skill")
	_reject("칸 밖", s, func(): return GrowthRules.allocate(s, 5, {HS: 2}), "unknown_skill")
	_reject("칸 밖(음수)", s, func(): return GrowthRules.allocate(s, -1, {HS: 2}), "unknown_skill")
	_reject("낮은 목표", s, func(): return GrowthRules.allocate(s, 1, {HS: 0}), "lower")
	_reject("최대 레벨 초과", s, func(): return GrowthRules.allocate(s, 1, {HS: 6}), "max_level")
	_reject("바뀌는 것 없음", s, func(): return GrowthRules.allocate(s, 1, {HS: 1}), "unchanged")
	_reject("빈 배분", s, func(): return GrowthRules.allocate(s, 1, {}), "unchanged")
	_reject("선행 레벨 부족", s, func(): return GrowthRules.allocate(s, 1, {LEG: 1}), "requires")
	_reject("AND 중 하나만 충족", s, func(): return GrowthRules.allocate(s, 1, {QUICK: 1}), "requires")
	var r := _new(_sp99())
	_reject("관문 미달", r, func(): return GrowthRules.allocate(r, 1, {BLADE_M: 3, QUICK: 1}), "min_level")
	_reject("SP 정확히 1 넘침", s, func(): return GrowthRules.allocate(s, 1, {HS: 2, CROSS: 3}), "no_sp")
	for bad in [1.5, "2", true]:
		_reject("정수 아닌 목표 %s" % str(bad), s, func(): return GrowthRules.allocate(s, 1, {HS: bad}), "lower")
	check_eq(GrowthRules.allocate(s, 1, {HS: 2.0})[0]["type"], "skills_learned", "JSON 의 2.0 은 정수로 받는다")


func test_prerequisite_checked_only_for_first_level() -> void:
	var s := _lv3()
	s.party.members[1].skills[LEG] = 1  # 시험 준비: 선행(하이 슬래시 2)을 채우지 않은 채 배운 상태
	var ev := GrowthRules.allocate(s, 1, {LEG: 2})
	check_eq(Fx.types(ev), ["skills_learned"] as Array[String], "레벨 올리기에는 선행을 다시 보지 않는다")


func test_learn_block_and_unlearn_block_follow_draft() -> void:
	var s := _lv3()
	var d := s.defs
	var m := s.party.members[1]
	check_eq(GrowthRules.learn_block(d, 1, m, {}, LEG), "requires", "선행 부족")
	check_eq(GrowthRules.learn_block(d, 1, m, {HS: 1}, LEG), "", "초안이 선행을 채움")
	check_eq(GrowthRules.learn_block(d, 1, m, {HS: 1, LEG: 1}, CROSS), "no_sp", "SP 없음")
	check_eq(GrowthRules.learn_block(d, 1, m, {HS: 4}, HS), "max_level", "최대 레벨")
	check_eq(GrowthRules.learn_block(d, 1, m, {BLADE_M: 3}, QUICK), "min_level", "관문")
	check_eq(GrowthRules.learn_block(d, 1, m, {}, FG), "unknown_skill", "다른 직업")
	check_eq(GrowthRules.unlearn_block(d, 1, m, {HS: 1, LEG: 1}, HS), "requires", "−: 초안 선행이 깨짐")
	check_eq(GrowthRules.unlearn_block(d, 1, m, {HS: 1, LEG: 1}, LEG), "", "−: 다음 스킬은 내림")
	check_eq(GrowthRules.unlearn_block(d, 1, m, {HS: 1}, CROSS), "no_draft", "−: 초안 아닌 레벨은 못 내림")


# ---- 전투가 배운 스킬·레벨을 쓴다 ----

func _heat_defs(level: int) -> GameDefs:
	var files := Fx.with_growth(_quiet_files(Fx.EXACT), {"initial_sp": 99})
	return Fx.defs_from(files, Fx.party_with_skills(Fx.defs().battle, {HEAT: level}))


func test_battle_uses_learned_skill_level() -> void:
	for level in [1, 5]:
		var s := _battle(_heat_defs(level))
		var u := s.battle.party[4]
		var t := s.battle.enemies[0]
		var row := s.defs.battle.skill(HEAT).level_row(level)
		var ev := BattleRules.submit(s, Fx.cmds(s, {4: Fx.use(HEAT, 0)}))
		var act := ev.filter(func(e): return e["type"] == "action" and e["skill"] == HEAT)
		check(act.size() == 1 and act[0]["tp"] == row["tp"], "Lv%d: action.tp = 그 줄 %d" % [level, row["tp"]])
		var hit := ev.filter(func(e): return e["type"] == "damaged" and e.get("skill") == HEAT)
		var a: int = u.stats["INT"] + int(u.gear["matk"])
		var dd := int(t.stats["WIS"]) + int(t.gear["mdef"])
		var want := BattleCalc.damage_base(a, dd, row["power"], s.defs.battle.rules.defense_k)
		check(hit.size() == 1 and hit[0]["calc"]["base"] == want, "Lv%d: calc.base = 손 계산 %d(power %d): %s" % [level, want, row["power"], str(hit)])
	var s2 := _battle(Fx.defs())
	var u2 := s2.battle.party[4]
	check(not u2.skills.has(CORRODE) and not u2.skills.has(GLYPH_M), "배우지 않은 스킬·패시브는 전투 스킬 목록에 없다")
	_reject("배우지 않은 스킬", s2, func(): return BattleRules.submit(s2, Fx.cmds(s2, {4: Fx.use(CORRODE, 0)})), "unknown_skill")
	_reject("패시브 ID", s2, func(): return BattleRules.submit(s2, Fx.cmds(s2, {4: Fx.use(GLYPH_M, 0)})), "unknown_skill")


func test_quick_draw_acts_before_fast_normal_enemy() -> void:
	var fast := Fx.enemy("enemy.t_fast", 9999, [10, 10, 10, 10, 999, 10], [[{}, [[Fx.MEND, 1]]]])
	var files := Fx.with_growth(Fx.battle_files(Fx.test_files([], [fast], {"f": [["enemy.t_fast", "front"]]}), Fx.EXACT), {"initial_sp": 99})
	var defs := Fx.defs_from(files, Fx.party_with_skills(Fx.defs().battle, {QUICK: 1}))
	for c in [[QUICK, true], [HS, false]]:
		var s := Fx.battle(defs, "formation.t.f", 1)
		var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(c[0], 0)}))
		var mine := -1
		var theirs := -1
		for i in ev.size():
			if ev[i]["type"] == "action":
				if ev[i]["unit"] == {"side": "party", "slot": 1}:
					mine = i
				elif ev[i]["unit"]["side"] == "enemy" and theirs < 0:
					theirs = i
		check(mine >= 0 and theirs >= 0, "%s: 두 행동이 있다 %s" % [c[0], str(Fx.types(ev))])
		check_eq(mine < theirs, c[1], "%s: AGI 999 적보다 %s" % [c[0], "먼저(first)" if c[1] else "나중(normal)"])


# ---- 패시브 (데이터 주도) ----

func test_every_passive_raises_profile_and_stays_out_of_battle() -> void:
	var defs := _sp99()
	var db := defs.battle
	var n := 0
	for sid in db.skill_ids:
		var sk := db.skill(sid)
		if not sk.passive():
			continue
		n += 1
		var i := -1
		for j in defs.party.ids.size():
			if defs.class_of(j).tree_index.has(sid):
				i = j
				break
		check(i >= 0, "%s: 트리에 이 패시브가 있는 대원" % sid)
		for level in [1, sk.max_level()]:
			var label := "%s Lv%d" % [sid, level]
			var s := _new(defs)
			var m := s.party.members[i]
			m.hp -= 5  # 현재값이 늘어난 만큼만 오르는지 보이게
			var p0 := GrowthRules.profile(defs, i, m)
			var hp0 := m.hp
			var tp0 := m.tp
			var ev := GrowthRules.allocate(s, i, {sid: level})
			var p1 := GrowthRules.profile(defs, i, m)
			var bonus: Dictionary = sk.levels[level - 1]["bonus"]
			for k in bonus:
				if k.begins_with("max_"):
					check_eq(p1[k], p0[k] + bonus[k], "%s: %s +%d" % [label, k, bonus[k]])
				else:
					check_eq(p1["stats"][k], p0["stats"][k] + bonus[k], "%s: %s +%d" % [label, k, bonus[k]])
			var dhp: int = bonus.get("max_hp", 0)
			var dtp: int = bonus.get("max_tp", 0)
			var mc := Fx.of_type(ev, "max_changed")
			if bonus.has("max_hp") or bonus.has("max_tp"):
				check(mc.size() == 1 and mc[0]["hp_gain"] == dhp and mc[0]["tp_gain"] == dtp, "%s: max_changed 하나 %s" % [label, str(mc)])
				check_eq([m.hp - hp0, m.tp - tp0, m.max_hp - p0["max_hp"], m.max_tp - p0["max_tp"]], [dhp, dtp, dhp, dtp], "%s: 현재·최대 HP·TP" % label)
			else:
				check_eq(Fx.types(ev), ["skills_learned"] as Array[String], "%s: max_changed 없음" % label)
				check_eq([m.hp, m.tp, m.max_hp, m.max_tp], [hp0, tp0, p0["max_hp"], p0["max_tp"]], "%s: HP·TP 그대로" % label)
			s.encounter.danger = s.encounter.threshold
			BattleRules.start(s, RATS)
			check(not s.battle.party[i].skills.has(sid), "%s: 전투 유닛 skills 에 패시브 없음" % label)
			_reject("%s 제출" % label, s, func(): return BattleRules.submit(s, Fx.cmds(s, {i: Fx.use(sid, 0)})), "unknown_skill")
	check_eq(n, 4, "패시브 넷")


# ---- 장비 ----

func _equip(s: ExplorationState, i: int, slot: int, id: String) -> Array[Dictionary]:
	return GrowthRules.equip(s, i, slot, id)


func test_equip_moves_items_between_bag_and_slots() -> void:
	var s := _new()
	GrowthRules.supply(s, "equip.visor", 1)
	var ev := _equip(s, 0, 3, "equip.visor")
	check_eq(ev, [{"type": "equipped", "member": 0, "slot": 3, "item": "equip.visor", "removed": ""}] as Array[Dictionary], "빈 칸에 끼기")
	check(not s.gear_bag.has("equip.visor") and s.party.members[0].equip[3] == "equip.visor", "가방 −1(0 이면 키 없음)")
	GrowthRules.supply(s, "equip.aegis_plate", 1)
	ev = _equip(s, 0, 1, "equip.aegis_plate")
	check_eq([ev[0]["removed"], s.gear_bag, s.party.members[0].equip[1]], ["equip.training_shield", {"equip.training_shield": 1}, "equip.aegis_plate"], "바꾸기(옛 장비 가방 +1)")
	ev = _equip(s, 0, 3, "")
	check_eq([ev[0]["item"], ev[0]["removed"], s.gear_bag.get("equip.visor"), s.party.members[0].equip[3]], ["", "equip.visor", 1, ""], "빼기")
	_saves_same(s, "장착 뒤")


func test_equip_rejections_keep_state() -> void:
	var s := _new()
	for id in ["equip.padded_coat", ION, "equip.servo_gauntlet", "equip.focus_staff", "equip.aegis_plate", "equip.thermal_ring", "equip.antitox_chip", "equip.mesh_armor", "equip.tactical_baton"]:
		GrowthRules.supply(s, id, 1)
	var b := _battle(Fx.defs())
	_reject("전투 중", b, func(): return _equip(b, 0, 3, ""), "not_now")
	var w := _new()
	w.wiped = true
	_reject("전멸", w, func(): return _equip(w, 0, 2, ""), "not_now")
	_reject("칸 4", s, func(): return _equip(s, 0, 4, ION), "bad_slot")
	_reject("칸 −1", s, func(): return _equip(s, 0, -1, ION), "bad_slot")
	_reject("모르는 장비", s, func(): return _equip(s, 0, 3, "equip.nope"), "unknown_item")
	_reject("가방에 없음", s, func(): return _equip(s, 0, 3, "equip.visor"), "not_in_bag")
	_reject("칸 0 에 방어구", s, func(): return _equip(s, 0, 0, "equip.padded_coat"), "slot_kind")
	_reject("칸 1 에 무기", s, func(): return _equip(s, 1, 1, ION), "slot_kind")
	_reject("위저드 + 서보 건틀릿", s, func(): return _equip(s, 4, 3, "equip.servo_gauntlet"), "class")
	_reject("홀로나이트 + 포커스 스태프", s, func(): return _equip(s, 0, 0, "equip.focus_staff"), "class")
	_reject("방패 둘", s, func(): return _equip(s, 0, 3, "equip.aegis_plate"), "kind_limit")
	_reject("메시 아머는 메딕이 못 낌", s, func(): return _equip(s, 3, 1, "equip.mesh_armor"), "class")
	_reject("빈 칸 빼기", s, func(): return _equip(s, 0, 3, ""), "unchanged")
	check_eq(_equip(s, 4, 3, "equip.thermal_ring")[0]["type"], "equipped", "장신구 둘은 받음")
	_reject("장신구 셋", s, func(): return _equip(s, 4, 1, "equip.antitox_chip"), "kind_limit")
	check_eq(_equip(s, 0, 0, "equip.tactical_baton")[0]["type"], "equipped", "택티컬 배턴은 홀로나이트가 낀다(종류 규칙 밖 예외)")
	var f := _new()
	GrowthRules.supply(f, "equip.padded_coat", 99)
	check_eq(BagRules.used(f), BagRules.SLOTS, "보급 99 는 공용 60칸에서 멈춘다(D31)")
	_reject("가방 60/60 에 벗기기", f, func(): return _equip(f, 0, 2, ""), "bag_full")
	f.gear_bag["equip.padded_coat"] = BattleLimits.BAG_MAX  # 60칸을 넘은 옛 저장만 종류 상한 99 에 닿는다
	f.gear_bag["equip.medic_coat"] = 1
	_reject("옛 저장: 가방 99 장비를 바꿔 벗기기", f, func(): return _equip(f, 0, 2, "equip.medic_coat"), "bag_full")


## 장착의 대원 칸 밖(unknown_member)·같은 장비 다시 끼기(unchanged), 경험치 보급의 대원 칸 밖: rejected 하나, 상태 해시·가방·장비 칸 그대로.
func test_equip_unknown_member_and_same_item_unchanged() -> void:
	var s := _new()
	GrowthRules.supply(s, "equip.training_sword", 1)  # 같은 장비가 가방에도 있어야 not_in_bag 이 아닌 unchanged 갈래를 지난다
	var equips := func() -> String: return Fx.events_text(s.party.members.map(func(m): return m.equip))
	var cases := [
		["장착 대원 −1", func(): return _equip(s, -1, 0, ION), "unknown_member"],
		["장착 대원 5", func(): return _equip(s, 5, 0, ION), "unknown_member"],
		["빼기 대원 5", func(): return _equip(s, 5, 2, ""), "unknown_member"],
		["같은 장비 다시 끼기(가방에도 있음)", func(): return _equip(s, 0, 0, "equip.training_sword"), "unchanged"],
		["같은 장비 다시 끼기(가방에 없음)", func(): return _equip(s, 0, 1, "equip.training_shield"), "unchanged"],
		["경험치 대원 −1", func(): return GrowthRules.grant_exp(s, -1, 10), "unknown_member"],
		["경험치 대원 5", func(): return GrowthRules.grant_exp(s, 5, 10), "unknown_member"],
	]
	for c in cases:
		var bag := s.gear_bag.duplicate()
		var eq: String = equips.call()
		_reject(c[0], s, c[1], c[2])
		check_eq([s.gear_bag, equips.call()], [bag, eq], "%s: 가방·장비 칸 그대로" % c[0])
	check_eq(GrowthRules.equip_block(s.defs, 0, s.party.members[0], s.gear_bag, 0, "equip.training_sword", BagRules.free_slots(s)), "unchanged", "읽기 함수도 unchanged")


# ---- 능력치 묶음 ----

func _stat_defs() -> GameDefs:
	var files := _quiet_files(Fx.EXACT)
	files["items/test_equip.json"] = {"equipment": [
		{"id": "equip.t_lead", "name_key": "equip.t_lead", "kind": "accessory", "price": 1, "atk": 0, "matk": 0, "def": 0, "mdef": 0,
			"stats": {"AGI": -99}, "resist": {"fire": 3000}, "ailment_vuln": {}, "bind_vuln": {"leg": -3000}},
	]}
	return Fx.defs_from(files)


func test_profile_sums_table_passive_equipment_and_clamps() -> void:
	var defs := _stat_defs()
	var s := _new(defs)
	var m := s.party.members[0]
	for id in ["equip.mesh_armor", "equip.t_lead", "equip.antitox_chip"]:
		GrowthRules.supply(s, id, 1)
	m.skills[SHIELD_M] = 2  # 시험 준비: VIT +1·최대 HP +6
	_equip(s, 0, 2, "equip.mesh_armor")
	_equip(s, 0, 3, "equip.t_lead")
	var p := GrowthRules.profile(defs, 0, m)
	check_eq(p["breakdown"]["VIT"], {"base": 19, "passive": 1, "equip": 0, "total": 20}, "VIT = 표 + 패시브")
	check_eq(p["breakdown"]["AGI"], {"base": 11, "passive": 0, "equip": -101, "total": 1}, "음수 보정(메시 −2·납 −99) → 1 로 자름")
	check_eq([p["max_hp"], p["breakdown"]["max_hp"]["passive"]], [66, 6], "최대 HP = 표 + 패시브")
	check_eq(p["gear"], {"atk": 8, "matk": 0, "def": 6 + 9, "mdef": 2 + 3}, "gear = 장비 합(검·방패·메시)")
	check_eq([p["resist"]["fire"], p["bind_vuln"]["leg"]], [3000, 0], "배율 3000 위 → 3000, 0 아래 → 0")
	var t := _new(defs)
	GrowthRules.supply(t, "equip.antitox_chip", 1)
	_equip(t, 0, 3, "equip.antitox_chip")
	check_eq(GrowthRules.profile(defs, 0, t.party.members[0])["ailment_vuln"]["poison"], 0, "해독 칩: 독 1000 → 0(면역)")
	# 전투 유닛이 묶음 값과 같고, 한 턴 뒤 damaged.calc 의 A·D 가 그 값.
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, RATS)
	var u := s.battle.party[0]
	for k in ["stats", "gear", "resist", "ailment_vuln", "bind_vuln", "skills"]:
		check_eq(u.get(k), p[k], "전투 유닛 %s = 묶음" % k)
	var e := s.battle.enemies[0]
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: Fx.atk(0)}))
	var hit := ev.filter(func(x): return x["type"] == "damaged" and x.get("unit") == u.ref())
	check(hit.size() == 1 and hit[0]["calc"]["A"] == u.stats["STR"] + 8 and hit[0]["calc"]["D"] == int(e.stats["VIT"]), "A = STR + atk, D = 적 VIT: %s" % str(hit))


func test_weapon_element_and_attack_copies() -> void:
	var defs := Fx.defs_from(_quiet_files(Fx.EXACT))
	var s := _new(defs)
	var cls: BattleDb.ClassDef = defs.battle.classes["class.blade_duelist"]
	GrowthRules.supply(s, ION, 1)
	_equip(s, 1, 0, ION)
	check_eq([GrowthRules.profile(defs, 1, s.party.members[1])["attack"].element, GrowthRules.profile(defs, 1, s.party.members[1])["weapon"]], ["volt", ION], "무기 속성")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, RATS)
	var a := s.battle.party[1]
	var b := s.battle.party[2]
	check(a.attack != b.attack and a.attack != cls.attack and b.attack != cls.attack, "A·B·정의의 일반 공격은 서로 다른 객체")
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0), 2: Fx.atk(1)}))
	var el := func(unit: BattleUnit) -> Array: return ev.filter(func(x): return x["type"] == "damaged" and x.get("unit") == unit.ref()).map(func(x): return x["element"])
	check_eq([el.call(a), el.call(b)], [["volt"], ["slash"]], "A 전격·B 베기")
	check_eq(cls.attack.element, "slash", "정의의 attack.element 그대로")
	BattleRules.finish(s, "escaped")
	_equip(s, 1, 0, "")
	check_eq([GrowthRules.profile(defs, 1, s.party.members[1])["attack"].element, GrowthRules.profile(defs, 1, s.party.members[1])["weapon"]], ["slash", ""], "무기를 빼면 직업 값")
	check_eq(cls.attack.element, "slash", "장비를 바꾼 뒤에도 정의 그대로")


func test_profile_and_battle_skills_are_independent() -> void:
	var defs := Fx.defs()
	var s := _new()
	var m := s.party.members[0]
	var p1 := GrowthRules.profile(defs, 0, m)
	var p2 := GrowthRules.profile(defs, 0, m)
	p1["stats"]["STR"] = 999
	p1["skills"][FG] = 5
	p1["gear"]["atk"] = 999
	p1["resist"]["fire"] = 0
	p1["attack"].element = "fire"
	check_eq([p2["stats"]["STR"], p2["skills"][FG], p2["gear"]["atk"], p2["resist"]["fire"], p2["attack"].element], [15, 1, 8, 1000, "slash"], "다른 묶음 그대로")
	check_eq([m.skills[FG], defs.class_of(0).attack.element, defs.class_of(0).resist["fire"]], [1, "slash", 1000], "대원·정의 그대로")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, RATS)
	s.battle.party[0].skills[FG] = 5
	check_eq(m.skills[FG], 1, "전투 유닛 skills 를 바꿔도 Member.skills 그대로")


func test_start_party_matches_m2_values() -> void:
	var defs := Fx.defs()
	var gear := [[8, 0, 10, 4], [14, 0, 6, 2], [14, 0, 6, 2], [6, 6, 5, 5], [4, 12, 3, 6]]
	var attack := ["slash", "slash", "slash", "bash", "bash"]
	var members := defs.members()
	for i in members.size():
		var m := members[i]
		var c := defs.class_of(i)
		var p := GrowthRules.profile(defs, i, m)
		var row: Dictionary = c.levels[1]
		for k in BattleLimits.STATS:
			check_eq(p["stats"][k], row[k], "대원 %d %s = Lv1 줄" % [i, k])
		check_eq([p["gear"]["atk"], p["gear"]["matk"], p["gear"]["def"], p["gear"]["mdef"]], gear[i], "대원 %d gear = 06 §6.1" % i)
		check_eq([p["resist"], p["ailment_vuln"], p["bind_vuln"], p["attack"].element], [c.resist, c.ailment_vuln, c.bind_vuln, attack[i]], "대원 %d 배율·일반 공격 속성" % i)
		check_eq([m.level, m.exp, m.hp, m.max_hp, m.tp, m.max_tp], [1, 0, row["hp"], row["hp"], row["tp"], row["tp"]], "대원 %d 시작 값" % i)
		check_eq(GrowthRules.skills_problem(defs.battle, c, m.level, m.skills), [], "대원 %d 시작 배분 규칙" % i)
		check_eq(GrowthRules.equip_problem(defs.battle, c, m.equip), [], "대원 %d 시작 장비 규칙" % i)
	check(not members[4].skills.has(CORRODE), "위저드 시작 배분에 부식 글리프 없음")
	var again := defs.members()
	members[0].skills[FG] = 5
	members[0].equip[3] = "x"
	check_eq([again[0].skills[FG], again[0].equip[3], defs.party.skills[0][FG], defs.party.equips[0][3]], [1, "", 1, ""], "members() 는 새 사전·새 배열")


# ---- 임시 보급 ----

func test_supply_and_grant_exp() -> void:
	var s := _new()
	check_eq(GrowthRules.supply(s, ION, 3), [{"type": "supplied", "item": ION, "amount": 3, "capped": false}] as Array[Dictionary], "더함")
	check_eq(GrowthRules.supply(s, ION, 99)[0], {"type": "supplied", "item": ION, "amount": 57, "capped": true}, "공용 60칸 포화(D31): 빈 칸 57 만")
	check_eq([GrowthRules.supply(s, ION, 1)[0]["amount"], s.gear_bag[ION]], [0, 60], "이미 60/60")
	for bad in [0, 100, 1.5, true, "3"]:
		_reject("보급 개수 %s" % str(bad), s, func(): return GrowthRules.supply(s, ION, bad), "bad_amount")
	_reject("모르는 장비", s, func(): return GrowthRules.supply(s, "equip.nope", 1), "unknown_item")
	var b := _battle(Fx.defs())
	_reject("전투 중 보급", b, func(): return GrowthRules.supply(b, ION, 1), "not_now")
	_reject("전투 중 경험치", b, func(): return GrowthRules.grant_exp(b, 0, 10), "not_now")
	_reject("경험치 0", s, func(): return GrowthRules.grant_exp(s, 0, 0), "bad_amount")
	_reject("경험치 1,000,000", s, func(): return GrowthRules.grant_exp(s, 0, 1000000), "bad_amount")
	_reject("없는 대원", s, func(): return GrowthRules.grant_exp(s, 5, 10), "unknown_member")
	var x := _new()
	var y := _new()
	var ev := GrowthRules.grant_exp(x, 1, 300)
	var ev2: Array[Dictionary] = []
	GrowthRules.gain_exp(y, 1, 300, ev2)
	check_eq(Fx.events_text(ev), Fx.events_text(ev2), "grant_exp = gain_exp")
	check_eq(SaveCodec.state_hash(x), SaveCodec.state_hash(y), "같은 상태")


# ---- 범위 공유 ----

func test_boundary_growth_state_roundtrips() -> void:
	var defs := _stat_defs()
	var s := _new(defs)
	_set_level(s, 0, 30, _cum(defs, 30))
	check_eq(GrowthRules.allocate(s, 0, {SHIELD_M: 10})[0]["type"], "skills_learned", "패시브 Lv10(스킬 레벨 상한)")
	GrowthRules.supply(s, "equip.t_lead", 1)
	_equip(s, 0, 3, "equip.t_lead")  # equip_delta 경계 ±3000
	s.gear_bag[ION] = BattleLimits.BAG_MAX  # 종류 상한 99(저장 범위 경계): 60칸을 넘은 옛 저장의 값(D31)
	check_eq([s.party.members[0].level, s.party.members[0].exp, s.party.members[0].skills[SHIELD_M], s.gear_bag[ION]], [30, _cum(defs, 30), 10, 99], "경계 상태")
	_saves_same(s, "경계값 상태")
