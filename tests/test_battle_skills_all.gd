## 모든 스킬 작동 시험(D16, 06 §3·§5): data/ 에 정의된 모든 스킬을 데이터에서 읽어 돌며(아군 직업 스킬은 1레벨과 최고 레벨,
## 적 스킬은 전부) 실제 규칙 경로(BattleRules.submit — 적 스킬은 그 적의 AI 가 그 스킬만 고르게 고친 정의)로 한 번씩 쓰고,
## 정의가 선언한 효과마다 맞는 이벤트와 상태 변화를 본다: 피해(HP 감소·빗나감·면역), 회복, 해제, 소생, 강화·약화(칸·턴),
## 상태이상·봉인(걸림·버팀·막힘), 전열 방어·커버(같은 턴 적 공격에서), 준비(다음 턴 풀기), 대상 범위(단일·열·전체·자기), TP 소모.
## 모든 경우를 두 번 쓴다: 정의 그대로의 능력치(확률 효과는 걸림·버팀·빗나감 어느 쪽이든 그에 맞는 상태인지만 본다, D15 —
## 특정 시드의 성공에 기대지 않는다)와, 구성으로 결과를 정한 상태(받는 쪽 AGI 1·취약 배율 크게 → 명중·상태 확률 1000,
## 강화·약화 칸은 미리 가득). 전투가 일찍 끝나지 않게 적 HP 를 크게 두고(적 스킬 시험은 대원 HP 도), 적은 아무것도 하지 않는다
## (구성. 움직이는 적은 적 스킬 시험의 그 적과, 전열 방어·커버 시험에서 공격하는 적 하나뿐).
## 시험이 모르는 효과·대상·레벨 줄 키가 정의에 나오면 실패한다(새 스킬이 확인 없이 빠지지 않게).
## 패시브(effect passive, 07 §4.3)는 전투 명령이 아니라 이 파일의 반복에서 빼고 test_growth_rules 의 패시브 시험이 맡는다(07 §10.7).
## 쓰는 대원은 시험 파티에서 그 스킬이 트리에 있는 첫 대원이고, 선행·관문까지 채워 그 레벨로 배운다(Fx.party_with_skills, SP 99).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")

## 시험이 확인할 줄 아는 효과·대상·레벨 줄 키. 정의(BattleDb)에 새 값이 생기면 확인과 함께 늘린다.
const EFFECT_CHECKS := ["damage", "ailment", "heal", "cure", "revive", "buff", "debuff", "front_guard", "cover", "charge", "passive"]
const TARGET_CHECKS := ["enemy_one", "enemy_row", "enemy_all", "ally_one", "ally_dead", "ally_other", "ally_all", "ally_row", "self"]
const LEVEL_KEYS := {
	"damage": ["tp", "power", "accuracy", "ailment", "bind"], "ailment": ["tp", "ailment", "accuracy"],
	"heal": ["tp", "base", "wis_pct"], "cure": ["tp"], "revive": ["tp", "hp_permille"],
	"buff": ["tp", "kind", "value", "turns"], "debuff": ["tp", "kind", "value", "turns"],
	"front_guard": ["tp", "value"], "cover": ["tp"], "charge": ["tp"], "passive": ["bonus"],
}
## 구성: 받는 쪽 취약 배율(상태 확률이 상한 1000 에 닿는다)과 전투가 끝나지 않을 HP.
const SURE_VULN := 1000000
const TOUGH_HP := 100000
const PARTY_FORMATION := "formation.t.party"
const USER_FORMATION := "formation.t.user"

var _base: BattleDb
## 확인표(환경 변수 SQF_SKILL_TABLE=1 이면 시험 끝에 찍는다): 경우 → 확인한 이벤트 종류.
var _table: Array[String] = []


## data/ 그대로의 정의(스킬 목록·자연 사용자 찾기용).
func _db() -> BattleDb:
	if _base == null:
		_base = BattleDb.load_dir(Fx.DATA_DIR)
	return _base


# ---- 정의 ----

func test_every_definition_is_known() -> void:
	var db := _db()
	check(db.ok(), "data/ 전투 정의: %s" % str(db.errors))
	for e in BattleDb.EFFECTS:
		check(EFFECT_CHECKS.has(e), "효과 %s 를 확인하는 시험이 없다" % e)
	for t in BattleDb.TARGETS:
		check(TARGET_CHECKS.has(t), "대상 %s 를 확인하는 시험이 없다" % t)
	var party_classes: Array = Fx.party_dict()["members"].map(func(m: Dictionary) -> String: return m["class"])
	for sid in db.skill_ids:
		var s := db.skill(sid)
		check(EFFECT_CHECKS.has(s.effect), "%s: 시험이 모르는 효과 %s" % [sid, s.effect])
		check(TARGET_CHECKS.has(s.target) or (s.passive() and s.target.is_empty()), "%s: 시험이 모르는 대상 %s" % [sid, s.target])
		for i in s.levels.size():
			for k in s.levels[i]:
				check(LEVEL_KEYS.get(s.effect, []).has(k), "%s levels[%d]: 시험이 모르는 키 %s" % [sid, i, k])
		if s.user == "party":
			var owners := db.class_ids.filter(func(c: String) -> bool: return db.classes[c].tree_index.has(sid))
			check(owners.any(func(c: String) -> bool: return party_classes.has(c)), "%s: 시험 파티에 이 스킬을 가진 직업이 없다" % sid)


# ---- 아군 스킬 ----

func test_party_skills_every_level() -> void:
	timeout_sec = 120.0
	var db := _db()
	var done: Array[String] = []
	for sid in db.skill_ids:
		var s := db.skill(sid)
		if s.user != "party" or s.passive():
			continue
		var levels := [1] if s.levels.size() == 1 else [1, s.levels.size()]
		for level in levels:
			for fixed in [false, true]:
				_party_case(sid, level, fixed)
		done.append(sid)
	var want := db.skill_ids.filter(func(id: String) -> bool: return db.skill(id).user == "party" and not db.skill(id).passive())
	check_eq(str(done), str(want), "아군 액티브 스킬 전부")
	_print_table()


## 아군 스킬 하나: 쓰는 대원(그 스킬을 가진 첫 대원)이 쓰고 나머지는 방어. 적은 아무것도 하지 않는다(전열 방어·커버만 한 적이 공격).
func _party_case(sid: String, level: int, fixed: bool) -> void:
	var db := _db()
	var sk := db.skill(sid)
	var label := "%s Lv%d%s" % [sid, level, " [구성]" if fixed else ""]
	var row := sk.level_row(level)
	var trio := _enemy_trio()
	var ai := _all_passive()
	var hit_skill := ""
	if sk.effect == "cover" or sk.effect == "front_guard":
		hit_skill = _physical_single_enemy_skill()
		check(not hit_skill.is_empty(), "%s: 확인에 쓸 물리 단일 적 스킬이 없다" % label)
		ai[trio[0]] = [{"if": {}, "use": [{"skill": hit_skill, "weight": 1, "target": "lowest_hp"}]}]
	var defs := _defs({"party": [[trio[0], "front"], [trio[1], "front"], [trio[2], "back"]]}, ai, {sid: level})
	if defs == null:
		check(false, label + ": 시험 정의")
		return
	var s := Fx.battle(defs, PARTY_FORMATION, 1)
	var b := s.battle
	_make_tough(b.enemies)
	var ui := _member_with(s, sid)
	if ui < 0:
		check(false, label + ": 이 스킬을 가진 대원이 없다")
		return
	var u := b.party[ui]
	var chosen := -1
	var prefilled := {}
	match sk.effect:
		"heal", "cover":
			chosen = _other_member(b, ui)
			b.party[chosen].hp = 1  # 회복량이 보이게 / 적 공격(lowest_hp)이 이 대원을 노리게
			if sk.target in ["ally_all", "ally_row"]:
				for t in b.party:
					t.hp = 1  # 범위 회복: 받는 대원 모두 회복량이 보이게
		"cure":
			chosen = _other_member(b, ui)
			var t := b.party[chosen]
			t.ailment = "poison"
			t.ailment_turns = 3
			t.ailment_damage = 5
			t.binds = {"arm": 3}
		"revive":
			chosen = _other_member(b, ui)
			b.party[chosen].hp = 0
		"front_guard":
			var y := _front_member_other(b, ui)
			b.party[y].hp = 1  # 적 공격(lowest_hp)이 이 전열 대원을 노리게
			if fixed:
				b.party[y].stats["AGI"] = 1
		"damage", "ailment":
			chosen = 0
			if fixed:
				_make_sure_targets(b.enemies)
		"buff":
			if sk.target == "ally_one" or sk.target == "ally_other":
				chosen = _other_member(b, ui)
			if fixed:
				prefilled = _prefill(s, b.party, false, row["kind"])
		_:
			check(false, "%s: 시험이 모르는 효과 %s" % [label, sk.effect])
			return
	if sk.effect == "cover" and fixed:
		u.stats["AGI"] = 1  # 커버한 기사가 대신 받는 공격도 반드시 맞는다
	var before := _snap(b)
	var tp0 := u.tp
	var cmd := {"kind": "skill", "skill": sid}
	if chosen >= 0 and not (sk.target in ["self", "enemy_all", "ally_all"]):
		cmd["target"] = chosen
	var events := BattleRules.submit(s, Fx.cmds(s, {ui: cmd}))
	if not _used(label, events, u.ref(), sid):
		return
	var at := _action_at(events, u.ref(), sid)
	var act: Dictionary = events[at]
	check(act["tp"] == row["tp"] and tp0 - u.tp == row["tp"], "%s: TP %d 소모(%d → %d)" % [label, row["tp"], tp0, u.tp])
	_check_targets(label, s, sk, u, act["targets"], chosen, before)
	_check_effect(label, s, sk, row, u, act["targets"], events, at, before, fixed, prefilled, hit_skill)
	_note(label, sk, act, events, at, hit_skill)


# ---- 적 스킬 ----

func test_enemy_skills_all() -> void:
	timeout_sec = 120.0
	var db := _db()
	var done: Array[String] = []
	for sid in db.skill_ids:
		if db.skill(sid).user != "enemy":
			continue
		for fixed in [false, true]:
			_enemy_case(sid, fixed)
		done.append(sid)
	var want := db.skill_ids.filter(func(id: String) -> bool: return db.skill(id).user == "enemy")
	check_eq(str(done), str(want), "적 스킬 전부")
	_print_table()


## 적 스킬 하나: 그 스킬을 AI 에 둔 적(없으면 첫 적) 하나가 AI 로 그 스킬만 고른다. 대원은 모두 방어.
## 준비 스킬은 다음 턴에 준비한 스킬을 쓰는지(준비 중이면 그 스킬)까지 본다.
func _enemy_case(sid: String, fixed: bool) -> void:
	var db := _db()
	var sk := db.skill(sid)
	var label := "%s%s" % [sid, " [구성]" if fixed else ""]
	var row := sk.level_row(1)
	var user_id := _natural_user(sid)
	var use := [{"skill": sid, "weight": 1, "target": "random"}]
	var rules := [{"if": {}, "use": use}]
	if sk.effect == "charge":
		rules = [{"if": {"charging": true}, "use": [{"skill": sk.charges, "weight": 1, "target": "random"}]}, {"if": {}, "use": use}]
	var ai := _all_passive()
	ai[user_id] = rules
	var defs := _defs({"user": [[user_id, "front"]]}, ai)
	if defs == null:
		check(false, label + ": 시험 정의")
		return
	var s := Fx.battle(defs, USER_FORMATION, 1)
	var b := s.battle
	var e := b.enemies[0]
	_make_tough(b.enemies)
	_make_tough(b.party)
	var prefilled := {}
	if fixed:
		_make_sure_targets(b.party)
		if sk.effect == "debuff":
			prefilled = _prefill(s, b.party, true, row["kind"])
	if sk.effect == "heal":
		e.hp = 1
	var before := _snap(b)
	var events := BattleRules.submit(s, Fx.cmds(s))
	if not _used(label, events, e.ref(), sid):
		return
	var at := _action_at(events, e.ref(), sid)
	var act: Dictionary = events[at]
	check(act["tp"] == row["tp"] and row["tp"] == 0, "%s: 적 스킬 TP 0" % label)
	_check_targets(label, s, sk, e, act["targets"], -1, before)
	_check_effect(label, s, sk, row, e, act["targets"], events, at, before, fixed, prefilled, "")
	_note(label, sk, act, events, at, "")
	if sk.effect == "charge" and s.battle != null:
		var events2 := BattleRules.submit(s, Fx.cmds(s))
		var at2 := _action_at(events2, e.ref(), sk.charges)
		check(at2 >= 0, "%s: 다음 턴에 준비한 %s 를 쓴다: %s" % [label, sk.charges, _types(events2)])
		check(e.charging == "", "%s: 준비한 스킬을 쓰면 준비가 풀린다" % label)


# ---- 기본 명령 ----

func test_basic_commands() -> void:
	timeout_sec = 60.0
	for fixed in [false, true]:
		var tag := " [구성]" if fixed else ""
		var trio := _enemy_trio()
		var defs := _defs({"party": [[trio[0], "front"], [trio[1], "front"], [trio[2], "back"]]}, _all_passive())
		var s := Fx.battle(defs, PARTY_FORMATION, 1)
		var b := s.battle
		_make_tough(b.enemies)
		if fixed:
			_make_sure_targets(b.enemies)
		# 공격: 모든 대원이 적 0 을 일반 공격
		var before := _snap(b)
		var over := {}
		for i in b.party.size():
			over[i] = {"kind": "attack", "target": 0}
		var events := BattleRules.submit(s, Fx.cmds(s, over))
		for i in b.party.size():
			var u := b.party[i]
			var label := "일반 공격 대원 %d%s" % [i, tag]
			if not _used(label, events, u.ref(), u.attack.id):
				continue
			var at := _action_at(events, u.ref(), u.attack.id)
			var act: Dictionary = events[at]
			check(act["kind"] == "attack" and act["tp"] == 0 and act["targets"] == [{"side": "enemy", "slot": 0}], "%s: %s" % [label, str(act)])
			var hp0: int = _hp_before_action(events, at, {"side": "enemy", "slot": 0}, before)
			_check_damage(label, s, u.attack, u.attack.level_row(1), u.ref(), {"side": "enemy", "slot": 0}, hp0, _effects_after(events, at), events, fixed, before)
		# 방어: 모두 방어 → guarding 이벤트, 턴 끝에 풀린다
		events = BattleRules.submit(s, Fx.cmds(s))
		for i in b.party.size():
			check(events.any(func(e: Dictionary) -> bool: return e["type"] == "guarding" and e["unit"] == b.party[i].ref()), "방어 대원 %d%s" % [i, tag])
			check(not b.party[i].guarding, "방어는 턴 끝에 풀린다 %d%s" % [i, tag])
		# 도주: 대원 0 이 도주, 나머지 방어 → 도주 성공(전투 끝) 또는 실패(전투 계속). 도주 확률은 상한이 1000 보다 작아 구성으로 정하지 않는다.
		events = BattleRules.submit(s, Fx.cmds(s, {0: {"kind": "escape"}}))
		var at := _action_at(events, b.party[0].ref(), "escape")
		check(at >= 0 and events[at]["kind"] == "escape", "도주 행동%s: %s" % [tag, _types(events)])
		var fx := _effects_after(events, at)
		var ok := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "escaped")
		var fail := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "escape_failed")
		check(ok.size() + fail.size() == 1, "도주 성공 또는 실패 하나%s: %s" % [tag, _types(fx)])
		if not ok.is_empty():
			var end := events.filter(func(e: Dictionary) -> bool: return e["type"] == "battle_end")
			check(s.battle == null and not s.encounter.pending and end.size() == 1 and end[0]["outcome"] == "escaped", "도주 성공 → 전투 끝(escaped)%s" % tag)
		else:
			check(s.battle != null and s.encounter.pending, "도주 실패 → 전투 계속%s" % tag)


# ---- 효과 확인 ----

func _check_effect(label: String, s: ExplorationState, sk: BattleDb.SkillDef, row: Dictionary, u: BattleUnit, targets: Array,
		events: Array[Dictionary], at: int, before: Dictionary, fixed: bool, prefilled: Dictionary, hit_skill: String) -> void:
	var fx := _effects_after(events, at)
	var b := s.battle
	match sk.effect:
		"damage":
			for t in targets:
				_check_damage(label, s, sk, row, u.ref(), t, _hp_before_action(events, at, t, before), fx, events, fixed, before)
		"ailment":
			for t in targets:
				var miss := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "missed" and e["target"] == t)
				if not miss.is_empty():
					check(not fixed and not sk.sure_hit, "%s: %s 빗나감은 필중·구성에서 없다" % [label, _key(t)])
					check(_unit(s, t).ailment == before[_key(t)]["ailment"], "%s: 빗나가면 상태 그대로" % label)
					continue
				_check_status(label, s, "ailment", row["ailment"], t, fx, events, before, fixed)
		"heal":
			for t in targets:
				var tu := _unit(s, t)
				var hp0: int = before[_key(t)]["hp"]
				var want := mini(int(row["base"]) + u.stats["WIS"] * int(row["wis_pct"]) / 100, tu.max_hp - hp0)
				var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "healed" and e["target"] == t)
				check(got.size() == 1 and got[0]["amount"] == want and got[0]["hp"] == hp0 + want, "%s: %s 회복 %d: %s" % [label, _key(t), want, str(got)])
				check(want > 0 and tu.hp == hp0 + want, "%s: %s HP %d → %d" % [label, _key(t), hp0, tu.hp])
		"cure":
			for t in targets:
				var tu := _unit(s, t)
				var want: Array = [before[_key(t)]["ailment"]] if before[_key(t)]["ailment"] != "" else []
				for part in BattleLimits.PARTS:
					if before[_key(t)]["binds"].has(part):
						want.append(part)
				var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "cured" and e["target"] == t)
				check(got.size() == 1 and got[0]["removed"] == want and not want.is_empty(), "%s: %s 해제 %s: %s" % [label, _key(t), str(want), str(got)])
				check(tu.ailment == "" and tu.binds.is_empty(), "%s: %s 상태이상·봉인이 지워졌다" % [label, _key(t)])
		"revive":
			for t in targets:
				var tu := _unit(s, t)
				var want := mini(tu.max_hp, maxi(1, BattleCalc.mul(tu.max_hp, int(row["hp_permille"]))))
				var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "revived" and e["target"] == t)
				check(before[_key(t)]["hp"] == 0 and got.size() == 1 and got[0]["hp"] == want, "%s: %s 소생 HP %d: %s" % [label, _key(t), want, str(got)])
				check(tu.alive() and tu.hp == want, "%s: %s 살아났다(HP %d)" % [label, _key(t), tu.hp])
		"buff", "debuff":
			_check_buffs(label, s, sk, row, targets, fx, events, prefilled)
		"front_guard":
			var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "front_guard" and e["unit"] == u.ref())
			check(got.size() == 1 and got[0]["value"] == row["value"], "%s: 전열 방어 %d: %s" % [label, row["value"], str(got)])
			var hits := _enemy_hits(events, hit_skill)
			check(not hits.is_empty(), "%s: 같은 턴 적의 물리 공격이 있었다: %s" % [label, _types(events)])
			for h in hits:
				if h["type"] == "missed":
					check(not fixed, "%s: 구성에서는 빗나가지 않는다" % label)
					continue
				var calc: Dictionary = h["calc"]
				var want: int = BattleCalc.mul(calc["guard"], int(row["value"])) if int(row["value"]) > 0 else calc["guard"]
				check(_unit(s, h["target"]).row == "front" and calc["front_guard"] == want, "%s: 전열 대원이 받는 물리 피해에 전열 방어 배율: %s" % [label, str(calc)])
			check(b != null and b.front_guard.is_empty(), "%s: 전열 방어는 턴 끝에 풀린다" % label)
		"cover":
			var protected: Dictionary = targets[0]
			var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "cover_set" and e["unit"] == u.ref() and e["target"] == protected)
			check(got.size() == 1, "%s: 커버 설정: %s" % [label, _types(fx)])
			var covered := events.filter(func(e: Dictionary) -> bool: return e["type"] == "covered" and e["unit"] == u.ref() and e["target"] == protected)
			check(covered.size() >= 1, "%s: 보호받는 대원을 노린 적 공격을 기사가 대신 받는다: %s" % [label, _types(events)])
			var hits := _enemy_hits(events, hit_skill)
			check(not hits.is_empty() and hits.all(func(h: Dictionary) -> bool: return h["target"] == u.ref()), "%s: 그 공격의 대상은 기사: %s" % [label, str(hits)])
			if fixed:
				check(hits.all(func(h: Dictionary) -> bool: return h["type"] == "damaged"), "%s: 구성에서는 맞는다" % label)
			check(b != null and b.cover.is_empty(), "%s: 커버는 턴 끝에 풀린다" % label)
		"charge":
			var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "charging" and e["unit"] == u.ref())
			check(got.size() == 1 and got[0]["skill"] == sk.charges, "%s: 준비 %s: %s" % [label, sk.charges, str(got)])
			check(u.charging == sk.charges, "%s: 준비 상태 %s" % [label, u.charging])
		_:
			check(false, "%s: 시험이 모르는 효과 %s" % [label, sk.effect])


## 피해 한 대상: damaged(면역이면 0) 또는 빗나감 하나. 맞았으면 HP 가 줄고, 살아 있으면 부가 상태이상·봉인이 걸리거나 버틴다.
func _check_damage(label: String, s: ExplorationState, sk: BattleDb.SkillDef, row: Dictionary, user: Dictionary, t: Dictionary, hp0: int,
		fx: Array[Dictionary], events: Array[Dictionary], fixed: bool, before: Dictionary) -> void:
	var hit := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "damaged" and e["target"] == t and e.get("unit") == user)
	var miss := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "missed" and e["target"] == t)
	check(hit.size() + miss.size() == 1, "%s: %s 에 피해 또는 빗나감 하나: %s" % [label, _key(t), _types(fx)])
	if hit.is_empty():
		check(not fixed and not sk.sure_hit, "%s: %s 빗나감은 필중·구성에서 없다" % [label, _key(t)])
		return
	var d: Dictionary = hit[0]
	var tu := _unit(s, t)
	if d["immune"]:
		check(d["amount"] == 0 and d["lost"] == 0 and tu.resist[sk.element] == 0, "%s: 면역은 속성 배율 0 일 때만: %s" % [label, str(d)])
		return
	check(d["amount"] >= 1 and d["lost"] == mini(hp0, d["amount"]) and d["hp"] == hp0 - d["lost"], "%s: %s HP %d → %d(피해 %d)" % [label, _key(t), hp0, d["hp"], d["amount"]])
	check(tu.hp == _last_hp(events, t, d["hp"]), "%s: %s 상태의 HP = 그 턴 마지막 HP 이벤트 %d(지금 %d)" % [label, _key(t), _last_hp(events, t, d["hp"]), tu.hp])
	if d["hp"] == 0:
		check(events.any(func(e: Dictionary) -> bool: return e["type"] == "defeated" and e["target"] == t), "%s: HP 0 → 쓰러짐" % label)
		return
	for kind in ["ailment", "bind"]:
		if row.has(kind):
			_check_status(label, s, kind, row[kind], t, fx, events, before, fixed)


## 상태이상(kind ailment)·봉인(kind bind) 한 대상: 걸림·버팀(·막힘) 하나. 걸렸으면 정의의 턴으로 걸렸고(턴 끝에 하나 줄었거나
## 1턴이면 풀렸다), 버티거나 막히면 상태가 그대로. 구성(fixed)이면 반드시 걸린다.
func _check_status(label: String, s: ExplorationState, kind: String, spec: Dictionary, t: Dictionary, fx: Array[Dictionary],
		events: Array[Dictionary], before: Dictionary, fixed: bool) -> void:
	var tu := _unit(s, t)
	var types := ["ailment", "ailment_resisted", "ailment_blocked"] if kind == "ailment" else ["bound", "bind_resisted"]
	var got := fx.filter(func(e: Dictionary) -> bool: return types.has(e["type"]) and e["target"] == t)
	check(got.size() == 1, "%s: %s 에 %s 걸림 또는 버팀 하나: %s" % [label, _key(t), kind, _types(fx)])
	if got.size() != 1:
		return
	var e: Dictionary = got[0]
	var what: String = spec["id"] if kind == "ailment" else spec["part"]
	check((e["id"] if kind == "ailment" else e["part"]) == what, "%s: %s 종류 %s" % [label, kind, what])
	if fixed:
		check(e["type"] == types[0], "%s: 구성(확률 1000)에서는 %s 가 걸린다: %s" % [label, what, str(e)])
	var expired := events.any(func(x: Dictionary) -> bool: return x["type"] == "expired" and x["target"] == t and x["id"] == what)
	if e["type"] == types[0]:
		check(e["turns"] == spec["turns"], "%s: %s %d턴" % [label, what, spec["turns"]])
		var woke := events.any(func(x: Dictionary) -> bool: return x["type"] == "woke" and x["target"] == t)
		if int(spec["turns"]) <= 1 or woke:
			check(expired or woke, "%s: 1턴 %s 는 턴 끝에 풀린다" % [label, what])
		elif kind == "ailment":
			check(tu.ailment == what and tu.ailment_turns == int(spec["turns"]) - 1, "%s: %s 상태 %s %d턴 남음(지금 %s %d)" % [label, _key(t), what, int(spec["turns"]) - 1, tu.ailment, tu.ailment_turns])
			if what == "poison":
				check(events.any(func(x: Dictionary) -> bool: return x["type"] == "poison_tick" and x["target"] == t and x["amount"] == spec["damage"]), "%s: 독 피해 %d" % [label, spec["damage"]])
		else:
			check(tu.binds.get(what, 0) == int(spec["turns"]) - 1, "%s: %s 봉인 %s %d턴 남음(지금 %s)" % [label, _key(t), what, int(spec["turns"]) - 1, str(tu.binds)])
	else:
		var was: Dictionary = before[_key(t)]
		if kind == "ailment":
			check(tu.ailment == was["ailment"], "%s: 버티면 상태이상 그대로" % label)
		else:
			check(tu.binds.has(what) == was["binds"].has(what), "%s: 버티면 봉인 그대로" % label)


## 강화·약화: 대상마다 buffed 하나(정의의 kind·value·turns, 같은 스킬 ID), 칸이 차 있었으면 가장 오래된 효과를 밀어낸다.
## 턴 끝 상태: 그 효과가 turns − 1 로 남거나(1턴이면 풀림), 칸 수를 넘지 않는다.
func _check_buffs(label: String, s: ExplorationState, sk: BattleDb.SkillDef, row: Dictionary, targets: Array, fx: Array[Dictionary],
		events: Array[Dictionary], prefilled: Dictionary) -> void:
	var debuff := sk.effect == "debuff"
	var rules := s.defs.battle.rules
	var slots := rules.debuff_slots if debuff else rules.buff_slots
	for t in targets:
		var got := fx.filter(func(e: Dictionary) -> bool: return e["type"] == "buffed" and e["target"] == t)
		check(got.size() == 1, "%s: %s 에 %s 하나: %s" % [label, _key(t), sk.effect, _types(fx)])
		if got.size() != 1:
			continue
		var e: Dictionary = got[0]
		var eff: Dictionary = e["effect"]
		check(e["list"] == ("debuffs" if debuff else "buffs") and eff["id"] == sk.id and eff["kind"] == row["kind"] and eff["value"] == row["value"]
			and eff["turns"] == row["turns"] and not e["refreshed"], "%s: %s 효과 %s" % [label, _key(t), str(e)])
		var oldest: Variant = prefilled.get(_key(t))
		if oldest != null:
			check(typeof(e["evicted"]) == TYPE_DICTIONARY and e["evicted"]["id"] == oldest, "%s: %s 칸이 차 있으면 가장 오래된 효과(%s)를 밀어낸다: %s" % [label, _key(t), oldest, str(e["evicted"])])
		else:
			check(e["evicted"] == null, "%s: 빈 칸이면 밀어내지 않는다" % label)
		var list: Array[Dictionary] = _unit(s, t).debuffs if debuff else _unit(s, t).buffs
		var mine := list.filter(func(x: Dictionary) -> bool: return x["id"] == sk.id)
		check(list.size() <= slots, "%s: %s 칸 %d 이하(지금 %d)" % [label, _key(t), slots, list.size()])
		if int(row["turns"]) <= 1:
			check(mine.is_empty() and events.any(func(x: Dictionary) -> bool: return x["type"] == "expired" and x["target"] == t and x["id"] == sk.id), "%s: 1턴 효과는 턴 끝에 풀린다" % label)
		else:
			check(mine.size() == 1 and mine[0]["turns"] == int(row["turns"]) - 1, "%s: %s %s 가 %d턴 남음: %s" % [label, _key(t), sk.id, int(row["turns"]) - 1, str(list)])


## 대상 범위: 자기는 쓰는 유닛, 단일은 고른(또는 AI 가 고른) 하나, 열은 그 대상과 같은 열의 살아 있는 유닛 전부,
## 전체는 그 편의 살아 있는 유닛 전부(근접은 닿는 유닛만). 행동 직전 생사는 턴 시작 상태로 본다.
func _check_targets(label: String, s: ExplorationState, sk: BattleDb.SkillDef, u: BattleUnit, got: Array, chosen: int, before: Dictionary) -> void:
	var b := s.battle
	var side := u.side if sk.targets_allies() else (BattleUnit.ENEMY if u.side == BattleUnit.PARTY else BattleUnit.PARTY)
	var pool: Array[BattleUnit] = b.party if side == BattleUnit.PARTY else b.enemies
	var alive := func(t: BattleUnit) -> bool: return before[_key(t.ref())]["hp"] > 0
	var reach := func(t: BattleUnit) -> bool: return sk.range_kind != "melee" or u.row == "front" or t.row == "front"
	var want: Array = []
	match sk.target:
		"self":
			want = [u.ref()]
		"enemy_one", "ally_one", "ally_other", "ally_dead":
			if chosen >= 0:
				want = [{"side": side, "slot": chosen}]
			elif got.size() == 1:
				want = got  # AI 가 고른 하나: 아래에서 생사·편을 본다
			check(got.size() == 1 and got[0]["side"] == side, "%s: 단일 대상 하나(%s): %s" % [label, side, str(got)])
			if got.size() == 1:
				var t := pool[got[0]["slot"]]
				var was_alive: bool = alive.call(t)
				check(was_alive == (sk.target != "ally_dead") and (sk.target != "ally_other" or t != u) and reach.call(t), "%s: 대상 규칙 %s 에 맞는 대상: %s" % [label, sk.target, str(got)])
		"enemy_row", "ally_row":
			var pick: int = chosen if chosen >= 0 else (int(got[0]["slot"]) if not got.is_empty() else 0)
			var r := pool[pick].row
			for t in pool:
				if alive.call(t) and reach.call(t) and t.row == r:
					want.append(t.ref())
		"enemy_all", "ally_all":
			for t in pool:
				if alive.call(t) and reach.call(t):
					want.append(t.ref())
		_:
			check(false, "%s: 시험이 모르는 대상 %s" % [label, sk.target])
	check_eq(got, want, "%s: 대상 범위 %s" % [label, sk.target])


# ---- 도우미 ----

func _note(label: String, sk: BattleDb.SkillDef, act: Dictionary, events: Array[Dictionary], at: int, hit_skill: String) -> void:
	var seen := {}
	for e in _effects_after(events, at):
		seen[e["type"]] = seen.get(e["type"], 0) + 1
	var extra := ""
	if not hit_skill.is_empty():
		var hits := _enemy_hits(events, hit_skill)
		extra = " | 적 공격 %s" % str(hits.map(func(h: Dictionary) -> String: return h["type"]))
		if events.any(func(e: Dictionary) -> bool: return e["type"] == "covered"):
			extra += " covered"
	_table.append("SKILL|%s|%s|%s|tp %d|대상 %d|%s%s" % [label, sk.effect, sk.target, act["tp"], act["targets"].size(), str(seen), extra])


func _print_table() -> void:
	if OS.get_environment("SQF_SKILL_TABLE") == "1":
		for line in _table:
			print(line)

## data/ 사본 정의. formations = {이름: [[적 ID, 열], …]}(편성 ID formation.t.<이름>), ai = {적 ID: AI 규칙},
## levels = {스킬 ID: 그 스킬이 트리에 있는 첫 대원이 배울 레벨}(선행·관문은 Fx.party_with_skills 가 채운다, SP 는 initial_sp 99).
## 오류면 null(defs_from 이 push_error).
func _defs(formations: Dictionary, ai: Dictionary, levels: Dictionary = {}) -> GameDefs:
	var files := Fx.with_growth(Fx.battle_files(Fx.test_files([], [], formations)), {"initial_sp": 99})
	for path in files:
		if str(path).begins_with("enemies/"):
			for e in files[path]["enemies"]:
				if ai.has(e["id"]):
					e["ai"] = ai[e["id"]]
	return Fx.defs_from(files, Fx.party_with_skills(_db(), levels))


## data/ 의 모든 적이 아무것도 하지 않는 AI(자기 0 회복).
func _all_passive() -> Dictionary:
	var out := {}
	for id in _db().enemy_ids:
		out[id] = [{"if": {}, "use": [{"skill": Fx.MEND, "weight": 1, "target": "random"}]}]
	return out


## 아군 스킬을 받는 적 셋(앞 둘은 전열, 셋째는 후열): data/ 의 적 앞에서부터(모자라면 되풀이).
func _enemy_trio() -> Array[String]:
	var ids := _db().enemy_ids
	return [ids[0], ids[1 % ids.size()], ids[2 % ids.size()]]


## 그 스킬을 AI 에 둔 첫 적(없으면 data/ 의 첫 적).
func _natural_user(sid: String) -> String:
	var db := _db()
	for id in db.enemy_ids:
		for rule in db.enemies[id].ai:
			for c in rule["use"]:
				if c["skill"] == sid:
					return id
	return db.enemy_ids[0]


## 전열 방어·커버 확인에 쓰는 적 스킬: 단일 대상 물리 피해(커버·전열 방어가 걸리는 공격).
func _physical_single_enemy_skill() -> String:
	var db := _db()
	for sid in db.skill_ids:
		var s := db.skill(sid)
		if s.user == "enemy" and s.effect == "damage" and s.target == "enemy_one" and s.physical():
			return sid
	return ""


func _member_with(s: ExplorationState, sid: String) -> int:
	for i in s.battle.party.size():
		if s.battle.party[i].skills.has(sid):
			return i
	return -1


## 쓰는 대원이 아닌 대원(뒤에서부터: 전열이 비지 않게).
func _other_member(b: BattleState, ui: int) -> int:
	for i in range(b.party.size() - 1, -1, -1):
		if i != ui:
			return i
	return -1


func _front_member_other(b: BattleState, ui: int) -> int:
	for i in b.party.size():
		if i != ui and b.party[i].row == "front":
			return i
	return -1


## 전투가 일찍 끝나지 않게 HP 를 크게(구성). 아군은 대원 상태의 최대 HP 도 함께.
func _make_tough(units: Array[BattleUnit]) -> void:
	for u in units:
		if u.member != null:
			u.member.max_hp = TOUGH_HP
		else:
			u.max_hp = TOUGH_HP
		u.hp = TOUGH_HP


## 받는 쪽을 명중·상태 확률 1000 으로(구성): AGI 1(회피 최소), 상태이상·봉인 취약 배율 크게. 정의 사전은 공유라 사본에 쓴다.
func _make_sure_targets(units: Array[BattleUnit]) -> void:
	for u in units:
		u.stats["AGI"] = 1
		var av := {}
		for k in BattleLimits.AILMENTS:
			av[k] = SURE_VULN
		var bv := {}
		for k in BattleLimits.PARTS:
			bv[k] = SURE_VULN
		u.ailment_vuln = av
		u.bind_vuln = bv


## 강화(또는 약화) 칸을 미리 가득 채운다(남은 턴 9, 다른 ID). 유닛 키 → 가장 오래된 효과 ID.
func _prefill(s: ExplorationState, units: Array[BattleUnit], debuff: bool, kind: String) -> Dictionary:
	var out := {}
	var b := s.battle
	var n: int = s.defs.battle.rules.debuff_slots if debuff else s.defs.battle.rules.buff_slots
	for u in units:
		var list: Array[Dictionary] = u.debuffs if debuff else u.buffs
		list.clear()
		for i in n:
			list.append({"id": "skill.t.fill_%d" % i, "kind": kind, "value": 1000, "turns": 9, "seq": b.seq})
			b.seq += 1
		out[_key(u.ref())] = list[0]["id"]
	return out


## 유닛 키 → 턴 시작 상태(HP·TP·상태이상·봉인·준비).
func _snap(b: BattleState) -> Dictionary:
	var out := {}
	for u in b.party + b.enemies:
		out[_key(u.ref())] = {"hp": u.hp, "tp": u.tp, "ailment": u.ailment, "binds": u.binds.duplicate(), "charging": u.charging}
	return out


func _key(r: Dictionary) -> String:
	return "%s%d" % [r["side"], r["slot"]]


func _unit(s: ExplorationState, r: Dictionary) -> BattleUnit:
	return s.battle.unit(r["side"], r["slot"])


func _types(events: Array) -> String:
	return str(events.map(func(e: Dictionary) -> String: return e["type"]))


## 그 유닛이 그 스킬로 행동했는지(거부·실패가 아닌지). 아니면 실패를 남기고 false.
func _used(label: String, events: Array[Dictionary], who: Dictionary, sid: String) -> bool:
	var rejected := events.filter(func(e: Dictionary) -> bool: return e["type"] == "rejected")
	check(rejected.is_empty(), "%s: 명령 거부 %s" % [label, str(rejected)])
	var failed := events.filter(func(e: Dictionary) -> bool: return e["type"] == "failed" and e["unit"] == who)
	check(failed.is_empty(), "%s: 행동 실패 %s" % [label, str(failed)])
	var ok := _action_at(events, who, sid) >= 0
	check(ok, "%s: %s 행동이 없다: %s" % [label, sid, _types(events)])
	return ok and rejected.is_empty()


func _action_at(events: Array[Dictionary], who: Dictionary, sid: String) -> int:
	for i in events.size():
		var e := events[i]
		if e["type"] == "action" and e["unit"] == who and e["skill"] == sid:
			return i
	return -1


## 행동 이벤트 뒤 그 행동이 낸 이벤트(다음 행동·실패·턴 끝·전투 끝 전까지).
func _effects_after(events: Array[Dictionary], at: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(at + 1, events.size()):
		if events[i]["type"] in ["action", "failed", "turn_end", "battle_end"]:
			break
		out.append(events[i])
	return out


## 그 행동 직전 대상의 HP: 턴 시작 HP 에서 앞선 피해·회복 이벤트를 따라간다.
func _hp_before_action(events: Array[Dictionary], at: int, t: Dictionary, before: Dictionary) -> int:
	var hp: int = before[_key(t)]["hp"]
	for i in at:
		var e := events[i]
		if e.get("target") == t and e["type"] in ["damaged", "healed", "revived", "poison_tick"]:
			hp = e["hp"]
	return hp


## 그 턴에 그 대상의 HP 를 바꾼 마지막 이벤트의 HP(피해·회복·소생·독). 없으면 fallback.
func _last_hp(events: Array[Dictionary], t: Dictionary, fallback: int) -> int:
	var hp := fallback
	for e in events:
		if e.get("target") == t and e["type"] in ["damaged", "healed", "revived", "poison_tick"]:
			hp = e["hp"]
	return hp


## 그 적 스킬 행동이 낸 피해·빗나감(커버·전열 방어 확인).
func _enemy_hits(events: Array[Dictionary], sid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in events.size():
		if events[i]["type"] == "action" and events[i]["skill"] == sid and events[i]["unit"]["side"] == BattleUnit.ENEMY:
			for e in _effects_after(events, i):
				if e["type"] == "damaged" or e["type"] == "missed":
					out.append(e)
	return out
