## 일반 적 둘(M3 A3c 설계 §2·§3·§7.1 D1~D5): 수액 반딧불·명멸 도깨비불의 자료 값, AI 조건 ally_hp_below·대상 정책 lowest_hp_ratio 읽기 검사,
## B2F/B3F 출현 표(새 편성 둘씩, 옛 편성·B1F·시험 표는 HEAD 와 같음). 값은 설계 노트의 리터럴이다. 시험마다 죽이는 변이(M-…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")

const EN := "enemies/stratum1.json"
const ES := "skills/enemy.json"
## data/enemies/stratum1.json 안의 자리(여섯 뒤 둘, 시험이 [5] 를 쓰는 것을 지킨다).
const FIREFLY_AT := 6
const WISP_AT := 7
## data/skills/enemy.json 안의 자리: 옛 열세 개 뒤 다섯.
const SAP_DRIP_AT := 13

var _db: BattleDb


func _battle_db() -> BattleDb:
	if _db == null:
		_db = Fx.arbor().battle
	return _db


func _errors_after(mutate: Callable) -> Array[String]:
	var files := Fx.battle_files()
	mutate.call(files)
	return Fx.battle_db(files).errors


func _has_error(errs: Array[String], needle: String) -> bool:
	return errs.any(func(e: String) -> bool: return e.contains(needle))


func _rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _errors_after(mutate)
	check(_has_error(errs, needle), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _accepts(label: String, mutate: Callable) -> void:
	check_eq(_errors_after(mutate), [] as Array[String], label)


## D1 (M-D4 반딧불 감로 base 18 → 19, M-D5 문턱 600 → 650, M-D7 도깨비불 불 내성 0 → 250, M-D2 AI_TARGETS 에서 lowest_hp_ratio 빠짐): 두 적과 다섯 스킬의 값.
func test_two_enemies_and_five_skills() -> void:
	var db := _battle_db()
	check_eq(db.enemy_ids.slice(0, 8), ["enemy.neon_rat", "enemy.cable_moth", "enemy.spore_bloom", "enemy.wire_serpent", "enemy.drill_mole",
		"enemy.clamp_beetle", "enemy.sap_firefly", "enemy.flicker_wisp"], "일반 적 여덟: 옛 여섯 뒤에 새 둘")
	var f: BattleDb.EnemyDef = db.enemies["enemy.sap_firefly"]
	check_eq([f.name_key, f.max_hp, f.exp, f.on_bound], ["enemy.sap_firefly", 72, 18, "switch"], "반딧불 머리")
	check_eq(f.stats, {"STR": 18, "INT": 22, "VIT": 8, "WIS": 20, "AGI": 17, "LUC": 12}, "반딧불 능력치")
	check_eq(f.resist, {"slash": 1000, "pierce": 1000, "bash": 1000, "fire": 1500, "ice": 1000, "volt": 500}, "반딧불 내성")
	check_eq(f.ailment_vuln, {"poison": 1000, "paralysis": 1000, "sleep": 1500, "confusion": 1000, "blind": 1000}, "반딧불 상태이상 취약")
	check_eq(f.bind_vuln, {"head": 1500, "arm": 1000, "leg": 1000}, "반딧불 봉인 취약")
	check_eq(f.ai, [
		{"if": {"ally_hp_below": 600}, "use": [{"skill": "skill.enemy.sap_drip", "weight": 1, "target": "lowest_hp_ratio"}]},
		{"if": {"turn_mod": [3, 0]}, "use": [{"skill": "skill.enemy.glow_signal", "weight": 1, "target": "random"}]},
		{"if": {}, "use": [{"skill": "skill.enemy.glow_sting", "weight": 1, "target": "random"}]}], "반딧불 AI 셋")
	check_eq(f.drops, [{"item": "item.glow_scale", "chance": 500, "if": {}}], "반딧불 드롭: 발광 인분 500‰")
	var w: BattleDb.EnemyDef = db.enemies["enemy.flicker_wisp"]
	check_eq([w.name_key, w.max_hp, w.exp, w.on_bound], ["enemy.flicker_wisp", 60, 22, "switch"], "도깨비불 머리")
	check_eq(w.stats, {"STR": 8, "INT": 30, "VIT": 6, "WIS": 16, "AGI": 20, "LUC": 14}, "도깨비불 능력치")
	check_eq(w.resist, {"slash": 700, "pierce": 700, "bash": 700, "fire": 0, "ice": 1500, "volt": 1000}, "도깨비불 내성: 불 무효, 얼음 약점")
	check_eq(w.ailment_vuln, {"poison": 500, "paralysis": 1000, "sleep": 500, "confusion": 1000, "blind": 1000}, "도깨비불 상태이상 취약")
	check_eq(w.bind_vuln, {"head": 1500, "arm": 500, "leg": 500}, "도깨비불 봉인 취약")
	check_eq(w.ai, [{"if": {}, "use": [{"skill": "skill.enemy.will_fire", "weight": 3, "target": "random"},
		{"skill": "skill.enemy.flicker_jam", "weight": 2, "target": "random"}]}], "도깨비불 AI 하나")
	check_eq(w.drops, [{"item": "item.glow_scale", "chance": 400, "if": {}}], "도깨비불 드롭: 발광 인분 400‰")
	var drip := db.skill("skill.enemy.sap_drip")
	check_eq([drip.effect, drip.range_kind, drip.target, drip.parts, drip.levels[0]], ["heal", "ranged", "ally_one", ["head"] as Array[String], {"tp": 0, "base": 18, "wis_pct": 100}], "감로")
	var sig := db.skill("skill.enemy.glow_signal")
	check_eq([sig.effect, sig.target, sig.parts, sig.levels[0]], ["buff", "ally_all", ["head"] as Array[String], {"tp": 0, "kind": "phys_atk", "value": 1250, "turns": 2}], "점멸 신호")
	var sting := db.skill("skill.enemy.glow_sting")
	check_eq([sting.effect, sting.range_kind, sting.target, sting.stat, sting.element, sting.parts, sting.levels[0]],
		["damage", "melee", "enemy_one", "STR", "pierce", [] as Array[String], {"tp": 0, "power": 70, "accuracy": 950}], "발광 침")
	var fire := db.skill("skill.enemy.will_fire")
	check_eq([fire.effect, fire.range_kind, fire.target, fire.stat, fire.element, fire.parts, fire.levels[0]],
		["damage", "ranged", "enemy_row", "INT", "fire", [] as Array[String], {"tp": 0, "power": 60, "accuracy": 950}], "불티 세례")
	var jam := db.skill("skill.enemy.flicker_jam")
	check_eq([jam.effect, jam.target, jam.parts, jam.sure_hit, jam.levels[0]],
		["ailment", "enemy_one", ["head"] as Array[String], true, {"tp": 0, "ailment": {"id": "confusion", "chance": 300, "turns": 2}}], "홀림불")


## D2 (M-D1 ally_hp_below 범위 검사가 없음): 새 AI 조건과 대상 정책의 읽기 검사.
func test_reader_checks_for_ally_hp_below_and_lowest_hp_ratio() -> void:
	var base := "%s: enemies[%d].ai[0].if.ally_hp_below: 정수 1~1000" % [EN, FIREFLY_AT]
	_rejects("ally_hp_below 0", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = 0, base)
	_rejects("ally_hp_below 1001", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = 1001, base)
	_rejects("ally_hp_below 글자", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = "600", base)
	_rejects("ally_hp_below 참거짓", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = true, base)
	_rejects("ally_hp_below 소수", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = 600.5, base)
	_accepts("ally_hp_below 1 경계", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = 1)
	_accepts("ally_hp_below 1000 경계", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"]["ally_hp_below"] = 1000)
	_rejects("마지막 규칙에 ally_hp_below", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][2]["if"] = {"ally_hp_below": 500},
		"%s: enemies[%d].ai[2].if: 마지막 규칙의 if 는 빈 객체" % [EN, FIREFLY_AT])
	_rejects("모르는 조건 이름에 새 조건이 나열됨", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["if"] = {"ally_hp": 600},
		"모르는 조건(charging, turn_mod, hp_below, ally_hp_below 중 하나)")
	_accepts("대상 정책 lowest_hp_ratio 를 단일 공격에도 쓴다", func(f): f[EN]["enemies"][0]["ai"][0]["use"][0]["target"] = "lowest_hp_ratio")
	_rejects("대상 정책 모르는 값", func(f): f[EN]["enemies"][FIREFLY_AT]["ai"][0]["use"][0]["target"] = "lowest_ratio",
		"%s: enemies[%d].ai[0].use[0].target:" % [EN, FIREFLY_AT])


## D3: 적의 heal·buff 는 ally 대상으로 읽히지만 ally_dead 소생 같은 수명 주기 없는 조합은 여전히 막힌다.
func test_enemy_heal_and_buff_targets() -> void:
	_accepts("감로 ally_other", func(f): f[ES]["skills"][SAP_DRIP_AT]["target"] = "ally_other")
	_accepts("감로 self", func(f): f[ES]["skills"][SAP_DRIP_AT]["target"] = "self")
	_rejects("감로 ally_dead", func(f): f[ES]["skills"][SAP_DRIP_AT]["target"] = "ally_dead", "%s: skills[%d].target" % [ES, SAP_DRIP_AT])
	_rejects("감로 enemy_one", func(f): f[ES]["skills"][SAP_DRIP_AT]["target"] = "enemy_one", "%s: skills[%d].target" % [ES, SAP_DRIP_AT])
	_rejects("점멸 신호 value 1000 이하(강화는 1001 이상)", func(f): f[ES]["skills"][SAP_DRIP_AT + 1]["levels"][0]["value"] = 900,
		"%s: skills[%d].levels[0].value: buff phys_atk 는" % [ES, SAP_DRIP_AT + 1])


const OLD_B1 := {
	"formation.b1.rats": "neon_rat:f neon_rat:f neon_rat:f", "formation.b1.rats_moth": "neon_rat:f neon_rat:f cable_moth:b",
	"formation.b1.mole_rat_bloom": "drill_mole:f neon_rat:f spore_bloom:b", "formation.b1.beetle_rat": "clamp_beetle:f neon_rat:f",
	"formation.b1.serpent_rat": "wire_serpent:f neon_rat:f"}
const OLD_B2 := {
	"formation.b2.serpents_moth": "wire_serpent:f wire_serpent:f cable_moth:b", "formation.b2.moles_bloom": "drill_mole:f drill_mole:f spore_bloom:b",
	"formation.b2.moths_beetle": "clamp_beetle:f cable_moth:b cable_moth:b", "formation.b2.serpent_moles": "drill_mole:f wire_serpent:f drill_mole:f",
	"formation.b2.beetles": "clamp_beetle:f clamp_beetle:f cable_moth:b"}
const OLD_B3 := {
	"formation.b3.beetles_serpent": "clamp_beetle:f clamp_beetle:f wire_serpent:f", "formation.b3.moles_moths": "drill_mole:f drill_mole:f cable_moth:b cable_moth:b",
	"formation.b3.serpents_bloom": "wire_serpent:f wire_serpent:f spore_bloom:b spore_bloom:b",
	"formation.b3.beetle_moles": "clamp_beetle:f drill_mole:f drill_mole:f spore_bloom:b",
	"formation.b3.full_mix": "neon_rat:f wire_serpent:f drill_mole:f cable_moth:b spore_bloom:b"}
const NEW_B2 := {"formation.b2.firefly_serpents": "wire_serpent:f wire_serpent:f sap_firefly:b", "formation.b2.wisp_moles": "drill_mole:f drill_mole:f flicker_wisp:b"}
const NEW_B3 := {"formation.b3.beetle_firefly_wisp": "clamp_beetle:f wire_serpent:f sap_firefly:b flicker_wisp:b",
	"formation.b3.wisps_moles": "drill_mole:f drill_mole:f flicker_wisp:b flicker_wisp:b"}
## 옛 표 순서·가중치(HEAD ce0ed44 의 파일): 새 둘은 그 뒤에 붙는다.
const OLD_B2_TABLE := [["formation.b2.serpents_moth", 25], ["formation.b2.moles_bloom", 20], ["formation.b2.moths_beetle", 20],
	["formation.b2.serpent_moles", 20], ["formation.b2.beetles", 15]]
const OLD_B3_TABLE := [["formation.b3.beetles_serpent", 25], ["formation.b3.moles_moths", 25], ["formation.b3.serpents_bloom", 20],
	["formation.b3.beetle_moles", 15], ["formation.b3.full_mix", 15]]
const OLD_B1_TABLE := [["formation.b1.rats", 30], ["formation.b1.rats_moth", 25], ["formation.b1.mole_rat_bloom", 20],
	["formation.b1.beetle_rat", 15], ["formation.b1.serpent_rat", 10]]


func _shape(f: Dictionary) -> String:
	return " ".join(f["enemies"].map(func(e: Dictionary) -> String: return "%s:%s" % [str(e["enemy"]).trim_prefix("enemy."), str(e["row"]).left(1)]))


func _encounter(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters/%s.json" % id))


func _table(d: Dictionary) -> Array:
	return d["table"].map(func(t: Dictionary) -> Array: return [t["formation"], int(t["weight"])])


## D4 (M-D3 옛 편성 가중치·내용을 고침, M-R2 새 편성을 옛 줄 앞에 끼움): B2F/B3F 는 옛 다섯 + 새 둘(뒤에 붙음, 가중치 18·12, 합 130), 옛 편성은 HEAD 와 같다.
## B1F 와 시험 표(f1_test·f2_test)는 HEAD 파일 그대로(내용 sha256).
func test_encounter_tables() -> void:
	var b1 := _encounter("b1f")
	check_eq(_table(b1), OLD_B1_TABLE, "B1F 표: HEAD 와 같다")
	check_eq(b1["formations"].map(func(f: Dictionary) -> String: return f["id"]), OLD_B1.keys(), "B1F 편성 다섯, HEAD 차례")
	for f in b1["formations"]:
		check_eq([_shape(f), f["no_escape"]], [OLD_B1[f["id"]], false], "B1F %s" % f["id"])
	for pair in [["b2f", OLD_B2, NEW_B2, OLD_B2_TABLE], ["b3f", OLD_B3, NEW_B3, OLD_B3_TABLE]]:
		var d := _encounter(pair[0])
		var want_ids: Array = pair[1].keys() + pair[2].keys()
		check_eq(d["formations"].map(func(f: Dictionary) -> String: return f["id"]), want_ids, "%s 편성: 옛 다섯 뒤에 새 둘" % pair[0])
		check_eq(_table(d), pair[3] + [[pair[2].keys()[0], 18], [pair[2].keys()[1], 12]], "%s 표: 옛 줄 그대로, 새 줄이 뒤에 18·12" % pair[0])
		var total := 0
		for t in d["table"]:
			total += int(t["weight"])
		check_eq(total, 130, "%s 가중치 합" % pair[0])
		for f in d["formations"]:
			var want: String = pair[1].get(f["id"], pair[2].get(f["id"], ""))
			check_eq([_shape(f), f["no_escape"]], [want, false], "%s %s" % [pair[0], f["id"]])
			var rows := {"front": 0, "back": 0}
			for e in f["enemies"]:
				rows[e["row"]] += 1
			check(rows["front"] <= BattleLimits.ROW_MAX and rows["back"] <= BattleLimits.ROW_MAX, "%s %s: 열마다 %d 이하" % [pair[0], f["id"], BattleLimits.ROW_MAX])
	# 시험 표 둘은 파일 바이트 그대로(HEAD ce0ed44 에서 sha256 으로 잰 값): 시뮬레이션 결과·설정 해시와 J7/J8 이 기대는 표.
	check_eq(FileAccess.get_sha256("res://data/encounters/f1_test.json"), F1_TEST_SHA, "f1_test.json 은 HEAD 와 같다")
	check_eq(FileAccess.get_sha256("res://data/encounters/f2_test.json"), F2_TEST_SHA, "f2_test.json 은 HEAD 와 같다")
	check_eq(FileAccess.get_sha256("res://data/encounters/b1f.json"), B1F_SHA, "b1f.json 은 HEAD 와 같다")


const F1_TEST_SHA := "4d31dd4ac85288f1697a14441962d965eeb7cd8d01b8a2f771831eefbc31d533"
const F2_TEST_SHA := "c727312024fd8a7174e6e7e3e0e507485b4dd57a1100cc16a51bef73ab59c3a0"
const B1F_SHA := "46133c2246a1715ebb36c433e01a3a6028720ad621f6f74aadefb9a0facf61a2"


## D5: 새 글 열쇠와 문구(설계 §5, 조정자 정정: 감로·불티 세례·홀림불).
func test_text_keys() -> void:
	var ko: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/text/ko.json"))
	var want := {
		"enemy.sap_firefly": "수액 반딧불", "enemy.flicker_wisp": "명멸 도깨비불",
		"skill.enemy.sap_drip": "감로", "skill.enemy.glow_signal": "점멸 신호", "skill.enemy.glow_sting": "발광 침",
		"skill.enemy.will_fire": "불티 세례", "skill.enemy.flicker_jam": "홀림불"}
	for k in want:
		check_eq(ko.get(k), want[k], k)
