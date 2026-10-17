## 전투 정의 데이터(data/ 의 rules·classes·skills·enemies·encounters·items) 읽기·검사 → BattleDb (06 §5).
## 오류는 "파일: 필드 경로: 내용". 오류가 하나라도 있으면 이 정의를 쓰지 않는다(06 §5.6).
## 값 범위는 BattleLimits 한 곳에서 온다. 모르는 필드는 거부한다(층 정의와 다르다).
class_name BattleDb
extends RefCounted

## \A·\z: 문자열 전체와 맞춘다($ 는 끝 줄바꿈 앞에서도 맞는다).
const ID_PATTERN := "\\A[a-z0-9_.]+\\z"
const KINDS := ["rules", "classes", "skills", "enemies", "encounters", "items"]
const RULES_FILE := "rules/battle.json"
const EFFECTS := ["damage", "ailment", "heal", "cure", "revive", "buff", "debuff", "front_guard", "cover", "charge"]
const TARGETS := ["enemy_one", "enemy_row", "enemy_all", "ally_one", "ally_dead", "ally_other", "ally_all", "ally_row", "self"]
const RANGES_KIND := ["melee", "ranged"]
const PRIORITIES := ["first", "normal", "last"]
const USERS := ["party", "enemy"]
const ON_BOUND := ["switch", "fail"]
const AI_TARGETS := ["random", "lowest_hp"]
const ROWS := ["front", "back"]
const SKILL_COMMON := ["id", "name_key", "user", "effect", "range", "target", "parts", "priority", "speed", "levels"]
const SKILL_EXTRA := {
	"damage": ["stat", "element", "can_crit", "sure_hit"], "ailment": ["sure_hit"], "charge": ["charges"],
}
const LEVEL_EXTRA := {
	"damage": ["power", "accuracy"], "ailment": ["ailment"], "heal": ["base", "wis_pct"], "revive": ["hp_permille"],
	"buff": ["kind", "value", "turns"], "debuff": ["kind", "value", "turns"], "front_guard": ["value"],
}
## effect 마다 받는 대상 규칙(명세에 없던 관계 검사: 규칙 코드가 뜻을 정할 수 있는 조합만 받는다).
const EFFECT_TARGETS := {
	"damage": ["enemy_one", "enemy_row", "enemy_all"], "ailment": ["enemy_one", "enemy_row", "enemy_all"],
	"debuff": ["enemy_one", "enemy_row", "enemy_all"],
	"heal": ["ally_one", "ally_other", "ally_all", "ally_row", "self"], "cure": ["ally_one", "ally_other", "ally_all", "ally_row", "self"],
	"buff": ["ally_one", "ally_other", "ally_all", "ally_row", "self"],
	"revive": ["ally_dead"], "cover": ["ally_other"], "front_guard": ["self"], "charge": ["self"],
}
## 쓰는 쪽마다 받는 effect(명세에 없던 관계 검사: M2 데이터·규칙이 쓰는 조합만 받는다).
## 적 revive(처치 기록을 지워야 한다)·파티 charge(예고 화면이 없다)처럼 수명 주기를 정하지 않은 조합은 읽기에서 막는다.
## 적 heal 은 시험의 「아무것도 안 하는 행동」(자기 대상 0 회복)으로 쓴다.
const USER_EFFECTS := {
	"party": ["damage", "ailment", "heal", "cure", "revive", "buff", "front_guard", "cover"],
	"enemy": ["damage", "ailment", "debuff", "heal", "charge"],
}
const DROP_CONDS := ["killed_by_element", "killed_while_bound", "killed_while_ailment"]
const AI_CONDS := ["charging", "turn_mod", "hp_below"]


## 규칙 상수(06 §5.2). 모든 값은 BattleLimits 범위 안이다.
class Rules:
	extends RefCounted
	var defense_k := 100
	var hit_min := 300
	var hit_max := 1000
	var crit_base := 50
	var crit_luck := 5
	var crit_max := 200
	var crit_mult := 1500
	var damage_roll: Array[int] = [950, 1050]
	var speed_roll: Array[int] = [900, 1100]
	var row_melee_mult := 500
	var guard_mult := 500
	var bind_stat_mult := 700
	var leg_evasion_mult := 500
	var paralysis_fail := 500
	var status_luck := 20
	var status_luck_clamp: Array[int] = [500, 1500]
	var resist_gain := 300
	var resist_max := 900
	var resist_decay := 100
	var escape_base := 600
	var escape_agi := 20
	var escape_clamp: Array[int] = [200, 950]
	var buff_slots := 3
	var debuff_slots := 3


## 스킬 하나. levels[레벨 − 1] 은 그 레벨의 줄(tp 와 effect 별 값, 06 §5.4). 없는 값은 키가 없다.
class SkillDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	var user := ""
	var effect := ""
	var stat := ""
	var element := ""
	var range_kind := ""
	var target := ""
	var parts: Array[String] = []
	var priority := "normal"
	var speed := 1000
	var can_crit := false
	var sure_hit := false
	var charges := ""
	var levels: Array[Dictionary] = []

	func level_row(level: int) -> Dictionary:
		return levels[clampi(level, 1, levels.size()) - 1]

	func physical() -> bool:
		return BattleLimits.PHYSICAL.has(element)

	func targets_allies() -> bool:
		return target.begins_with("ally_") or target == "self"


class ClassDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	## 레벨(int) → {hp, tp, STR, INT, VIT, WIS, AGI, LUC}
	var levels := {}
	var resist := {}
	var ailment_vuln := {}
	var bind_vuln := {}
	var skills: Array[String] = []
	## 일반 공격(06 §5.3: 속성·사거리만 직업마다, 나머지는 고정).
	var attack: SkillDef


class EnemyDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	var max_hp := 1
	var stats := {}
	var resist := {}
	var ailment_vuln := {}
	var bind_vuln := {}
	var on_bound := "fail"
	var exp := 0
	## [{if: {조건}, use: [{skill, weight, target}]}] 위에서부터.
	var ai: Array[Dictionary] = []
	## [{item, chance, if: {조건} 또는 빈 사전}]
	var drops: Array[Dictionary] = []


class FormationDef:
	extends RefCounted
	var id := ""
	var no_escape := false
	## [{enemy, row}] 칸 순서.
	var enemies: Array[Dictionary] = []


class EncounterDef:
	extends RefCounted
	var id := ""
	var formations: Array[String] = []
	## [{formation, weight}]
	var table: Array[Dictionary] = []


var rules: Rules
var classes := {}
var skills := {}
var enemies := {}
var formations := {}
var encounters := {}
## 소재 ID → name_key
var materials := {}
## 읽은 순서의 ID 목록(파일 경로 순 → 파일 안 순서). 순회는 이 배열로 한다.
var class_ids: Array[String] = []
var skill_ids: Array[String] = []
var enemy_ids: Array[String] = []
var formation_ids: Array[String] = []
var encounter_ids: Array[String] = []
var material_ids: Array[String] = []
var errors: Array[String] = []
var warnings: Array[String] = []

var _ids := {}  # 전체 ID → 처음 나온 파일


func ok() -> bool:
	return errors.is_empty()


## 폴더(res://data 등)의 정의 파일을 읽는다. 하위 폴더별 *.json 을 경로 순으로.
static func load_dir(data_dir: String) -> BattleDb:
	var files := {}
	var read_errors: Array[String] = []
	for kind in KINDS:
		var dir := DirAccess.open(data_dir.path_join(kind))
		if dir == null:
			continue
		var names := Array(dir.get_files()).filter(func(f): return f.ends_with(".json"))
		names.sort()
		for n in names:
			var rel: String = kind + "/" + n
			var json := JSON.new()
			if json.parse(FileAccess.get_file_as_string(data_dir.path_join(rel))) != OK:
				read_errors.append("%s: %d줄: JSON 읽기 실패: %s" % [rel, json.get_error_line() + 1, json.get_error_message()])
				continue
			files[rel] = json.data
	var db := parse(files)
	read_errors.append_array(db.errors)
	db.errors = read_errors
	return db


## 상대 경로("skills/enemy.json") → 읽은 JSON 값. 시험은 코드에서 만든 사전을 바로 넘긴다.
static func parse(files: Dictionary) -> BattleDb:
	var db := BattleDb.new()
	var paths: Array = files.keys()
	paths.sort()
	if not files.has(RULES_FILE):
		db.errors.append("%s: 파일이 없다" % RULES_FILE)
	for p in paths:
		var kind: String = str(p).get_slice("/", 0)
		if not KINDS.has(kind) or str(p).get_slice_count("/") != 2 or not str(p).ends_with(".json"):
			db.errors.append("%s: 모르는 정의 파일 경로" % p)
			continue
		var ck := _Ck.new(db, str(p))
		var data: Variant = files[p]
		if typeof(data) != TYPE_DICTIONARY:
			ck.err("", "맨 위가 객체가 아니다")
			continue
		match kind:
			"rules":
				if p == RULES_FILE:
					db._read_rules(ck, data)
				else:
					ck.err("", "규칙 상수 파일은 %s 하나다" % RULES_FILE)
			"classes":
				db._read_class(ck, data)
			"skills":
				db._read_list(ck, data, "skills", db._read_skill)
			"enemies":
				db._read_list(ck, data, "enemies", db._read_enemy)
			"encounters":
				db._read_encounter(ck, data)
			"items":
				db._read_list(ck, data, "materials", db._read_material)
	db._check_refs()
	return db


func skill(id: String) -> SkillDef:
	return skills.get(id)


## 층의 출현 표 ID → 그 표의 편성 ID 목록(표 순서).
func table_formations(encounter_id: String) -> Array[String]:
	var out: Array[String] = []
	var e: EncounterDef = encounters.get(encounter_id)
	if e != null:
		for t in e.table:
			out.append(t["formation"])
	return out


## 모든 name_key(직업·스킬·적·소재). GameDefs 가 ko.json 에 있는지 본다.
func name_keys() -> Array[String]:
	var out: Array[String] = []
	for id in class_ids:
		out.append(classes[id].name_key)
	for id in skill_ids:
		out.append(skills[id].name_key)
	for id in enemy_ids:
		out.append(enemies[id].name_key)
	for id in material_ids:
		out.append(materials[id])
	return out


# ---- 파일별 읽기 ----

func _read_rules(ck: _Ck, d: Dictionary) -> void:
	var conv := {}
	for k in d:
		var v: Variant = d[k]
		if typeof(v) == TYPE_ARRAY:
			var arr := []
			for x in v:
				arr.append(_int_or_bad(x))
			conv[k] = arr
		else:
			conv[k] = _int_or_bad(v)
	var msgs := BattleLimits.check_rules(conv)
	for m in msgs:
		ck.err(m.get_slice(":", 0), m.substr(m.find(":") + 2))
	if not msgs.is_empty():
		return
	var r := Rules.new()
	for k in BattleLimits.RULE_INTS:
		r.set(k, conv[k])
	for k in BattleLimits.RULE_PAIRS:
		var pair: Array[int] = [conv[k][0], conv[k][1]]
		r.set(k, pair)
	rules = r


## 정수로 바꿀 수 없는 값은 문자열 표시로 남겨 범위 검사에서 거부되게 한다.
static func _int_or_bad(v: Variant) -> Variant:
	var i: Variant = SaveCodec.to_int(v)
	return i if i != null and typeof(v) != TYPE_BOOL else "bad"


func _read_list(ck: _Ck, d: Dictionary, key: String, reader: Callable) -> void:
	if not ck.keys(d, "", [key], []):
		return
	if typeof(d[key]) != TYPE_ARRAY:
		ck.err(key, "배열이어야 한다")
		return
	for i in d[key].size():
		var item: Variant = d[key][i]
		var path := "%s[%d]" % [key, i]
		if typeof(item) != TYPE_DICTIONARY:
			ck.err(path, "객체여야 한다")
			continue
		reader.call(ck, item, path)


func _read_material(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, ["id", "name_key"], []):
		return
	var id := ck.id_of(d, "id", path, "item.")
	var nk := ck.str_of(d, "name_key", path)
	if id.is_empty() or not _claim(ck, id, path):
		return
	materials[id] = nk
	material_ids.append(id)


func _read_skill(ck: _Ck, d: Dictionary, path: String) -> void:
	var effect := str(d.get("effect", ""))
	if not EFFECTS.has(effect):
		ck.err(path + ".effect", "다음 중 하나여야 한다: %s" % ", ".join(EFFECTS))
		return
	if not ck.keys(d, path, SKILL_COMMON + SKILL_EXTRA.get(effect, []), []):
		return
	var s := SkillDef.new()
	s.effect = effect
	s.id = ck.id_of(d, "id", path, "skill.")
	s.name_key = ck.str_of(d, "name_key", path)
	s.user = ck.enum_of(d, "user", path, USERS)
	s.range_kind = ck.enum_of(d, "range", path, RANGES_KIND)
	s.target = ck.enum_of(d, "target", path, TARGETS)
	s.priority = ck.enum_of(d, "priority", path, PRIORITIES)
	var speed: Variant = ck.int_of(d, "speed", path, "speed")
	s.speed = speed if speed != null else 1000
	s.parts = ck.enum_set(d, "parts", path, BattleLimits.PARTS, true)
	if not s.target.is_empty() and not EFFECT_TARGETS[effect].has(s.target):
		ck.err(path + ".target", "effect %s 에는 %s 만 쓸 수 있다" % [effect, ", ".join(EFFECT_TARGETS[effect])])
	if not s.user.is_empty() and not USER_EFFECTS[s.user].has(effect):
		ck.err(path + ".effect", "user %s 에는 effect %s 를 쓸 수 없다(%s 만)" % [s.user, effect, ", ".join(USER_EFFECTS[s.user])])
	if effect == "damage":
		s.stat = ck.enum_of(d, "stat", path, ["STR", "INT"])
		s.element = ck.enum_of(d, "element", path, BattleLimits.ELEMENTS)
		s.can_crit = ck.bool_of(d, "can_crit", path)
	if effect == "damage" or effect == "ailment":
		s.sure_hit = ck.bool_of(d, "sure_hit", path)
	if effect == "charge":
		s.charges = ck.id_of(d, "charges", path, "skill.")
	if not s.id.is_empty():
		if s.user == "enemy" and not s.id.begins_with("skill.enemy."):
			ck.err(path + ".id", "적 스킬 ID 는 skill.enemy. 로 시작해야 한다")
		elif s.user == "party" and (s.id.begins_with("skill.enemy.") or s.id.get_slice_count(".") < 3):
			ck.err(path + ".id", "파티 스킬 ID 는 skill.<직업>.<이름> 꼴이어야 한다")
	if typeof(d["levels"]) != TYPE_ARRAY or d["levels"].is_empty():
		ck.err(path + ".levels", "줄이 하나 이상인 배열이어야 한다")
	else:
		for i in d["levels"].size():
			var row := _read_skill_level(ck, d["levels"][i], "%s.levels[%d]" % [path, i], s)
			# 강화·약화는 모든 줄의 kind 가 같아야 한다: 같은 효과 id 를 다시 걸 때 kind 가 바뀌지 않게(06 §5.4·§3.14).
			if (s.effect == "buff" or s.effect == "debuff") and i > 0 and row.has("kind") and not s.levels.is_empty() \
					and s.levels[0].has("kind") and row["kind"] != s.levels[0]["kind"]:
				ck.err("%s.levels[%d].kind" % [path, i], "%s 스킬은 모든 줄의 kind 가 같아야 한다(levels[0] 은 %s)" % [s.effect, s.levels[0]["kind"]])
			s.levels.append(row)
	if s.id.is_empty() or not _claim(ck, s.id, path):
		return
	skills[s.id] = s
	skill_ids.append(s.id)


func _read_skill_level(ck: _Ck, v: Variant, path: String, s: SkillDef) -> Dictionary:
	var row := {}
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return row
	var req: Array = ["tp"] + LEVEL_EXTRA.get(s.effect, [])
	var opt: Array = []
	if s.effect == "damage":
		opt = ["ailment", "bind"]
	if s.effect == "ailment" and not s.sure_hit:
		req.append("accuracy")
	if not ck.keys(v, path, req, opt):
		return row
	var tp: Variant = ck.int_of(v, "tp", path, "tp_cost")
	if tp != null:
		if s.user == "enemy" and tp != 0:
			ck.err(path + ".tp", "적 스킬의 tp 는 0 이어야 한다")
		elif s.user == "party" and tp < 1:
			ck.err(path + ".tp", "파티 스킬의 tp 는 1 이상이어야 한다")
		row["tp"] = tp
	for k in v:
		match k:
			"power":
				row[k] = ck.int_of(v, k, path, "power")
			"accuracy":
				row[k] = ck.int_of(v, k, path, "accuracy")
			"base":
				row[k] = ck.int_of(v, k, path, "heal_base")
			"wis_pct":
				row[k] = ck.int_of(v, k, path, "heal_wis_pct")
			"hp_permille":
				row[k] = ck.int_of(v, k, path, "hp_permille")
			"turns":
				row[k] = ck.int_of(v, k, path, "turns")
			"kind":
				row[k] = ck.enum_of(v, k, path, BattleLimits.EFFECT_KINDS)
			"value":
				if s.effect == "front_guard":
					row[k] = ck.int_of(v, k, path, "front_guard")
			"ailment":
				row[k] = _read_ailment_spec(ck, v[k], path + ".ailment")
			"bind":
				row[k] = _read_bind_spec(ck, v[k], path + ".bind")
	if s.effect == "buff" or s.effect == "debuff":
		var kind: String = row.get("kind", "")
		var value: Variant = SaveCodec.to_int(v["value"])
		if not kind.is_empty():
			if not BattleLimits.effect_value_ok(s.effect == "debuff", kind, value):
				ck.err(path + ".value", "%s %s 는 정수 %s 이어야 한다" % [s.effect, kind, BattleLimits.effect_value_text(s.effect == "debuff", kind)])
			else:
				row["value"] = value
	return row


func _read_ailment_spec(ck: _Ck, v: Variant, path: String) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return {}
	var id := str(v.get("id", ""))
	var req := ["id", "chance", "turns"]
	if id == "poison":
		req.append("damage")
	if not ck.keys(v, path, req, []):
		return {}
	var out := {"id": ck.enum_of(v, "id", path, BattleLimits.AILMENTS), "chance": ck.int_of(v, "chance", path, "chance"), "turns": ck.int_of(v, "turns", path, "turns")}
	if id == "poison":
		out["damage"] = ck.int_of(v, "damage", path, "poison_damage")
	return out


func _read_bind_spec(ck: _Ck, v: Variant, path: String) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return {}
	if not ck.keys(v, path, ["part", "chance", "turns"], []):
		return {}
	return {"part": ck.enum_of(v, "part", path, BattleLimits.PARTS), "chance": ck.int_of(v, "chance", path, "chance"), "turns": ck.int_of(v, "turns", path, "turns")}


func _read_class(ck: _Ck, d: Dictionary) -> void:
	if not ck.keys(d, "", ["id", "name_key", "levels", "attack", "resist", "ailment_vuln", "bind_vuln", "skills"], []):
		return
	var c := ClassDef.new()
	c.id = ck.id_of(d, "id", "", "class.")
	c.name_key = ck.str_of(d, "name_key", "")
	if typeof(d["levels"]) != TYPE_DICTIONARY or d["levels"].is_empty():
		ck.err("levels", "레벨이 하나 이상인 객체여야 한다")
	else:
		for lk in d["levels"]:
			var path := "levels.%s" % lk
			var lv := int(str(lk)) if str(lk).is_valid_int() else 0
			if str(lv) != str(lk) or not BattleLimits.in_range("level", lv):
				ck.err(path, "레벨 키는 1~99 의 10진 정수여야 한다")
				continue
			var row: Variant = d["levels"][lk]
			if typeof(row) != TYPE_DICTIONARY:
				ck.err(path, "객체여야 한다")
				continue
			if not ck.keys(row, path, ["hp", "tp"] + BattleLimits.STATS, []):
				continue
			var out := {"hp": ck.int_of(row, "hp", path, "max_hp"), "tp": ck.int_of(row, "tp", path, "max_tp")}
			for st in BattleLimits.STATS:
				out[st] = ck.int_of(row, st, path, "stat")
			c.levels[lv] = out
	if typeof(d["attack"]) != TYPE_DICTIONARY:
		ck.err("attack", "객체여야 한다")
	elif ck.keys(d["attack"], "attack", ["element", "range"], []):
		var a := SkillDef.new()
		a.id = "attack"
		a.name_key = "battle.attack"
		a.user = "party"
		a.effect = "damage"
		a.stat = "STR"
		a.element = ck.enum_of(d["attack"], "element", "attack", BattleLimits.ELEMENTS)
		a.range_kind = ck.enum_of(d["attack"], "range", "attack", RANGES_KIND)
		a.target = "enemy_one"
		a.can_crit = true
		a.levels = [{"tp": 0, "power": 100, "accuracy": 950}]
		c.attack = a
	c.resist = ck.table(d, "resist", "", BattleLimits.ELEMENTS, "resist")
	c.ailment_vuln = ck.table(d, "ailment_vuln", "", BattleLimits.AILMENTS, "vuln")
	c.bind_vuln = ck.table(d, "bind_vuln", "", BattleLimits.PARTS, "vuln")
	c.skills = ck.id_list(d, "skills", "", "skill.")
	if c.id.is_empty() or not _claim(ck, c.id, ""):
		return
	classes[c.id] = c
	class_ids.append(c.id)


func _read_enemy(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, ["id", "name_key", "max_hp", "stats", "resist", "ailment_vuln", "bind_vuln", "on_bound", "exp", "ai", "drops"], []):
		return
	var e := EnemyDef.new()
	e.id = ck.id_of(d, "id", path, "enemy.")
	e.name_key = ck.str_of(d, "name_key", path)
	var hp: Variant = ck.int_of(d, "max_hp", path, "max_hp")
	e.max_hp = hp if hp != null else 1
	e.stats = ck.table(d, "stats", path, BattleLimits.STATS, "stat")
	e.resist = ck.table(d, "resist", path, BattleLimits.ELEMENTS, "resist")
	e.ailment_vuln = ck.table(d, "ailment_vuln", path, BattleLimits.AILMENTS, "vuln")
	e.bind_vuln = ck.table(d, "bind_vuln", path, BattleLimits.PARTS, "vuln")
	e.on_bound = ck.enum_of(d, "on_bound", path, ON_BOUND)
	var xp: Variant = ck.int_of(d, "exp", path, "exp")
	e.exp = xp if xp != null else 0
	var p := _p(path, "ai")
	if typeof(d["ai"]) != TYPE_ARRAY or d["ai"].is_empty():
		ck.err(p, "규칙이 하나 이상인 배열이어야 한다")
	else:
		var n: int = d["ai"].size()
		for i in n:
			e.ai.append(_read_ai_rule(ck, d["ai"][i], "%s[%d]" % [p, i], i == n - 1))
	p = _p(path, "drops")
	if typeof(d["drops"]) != TYPE_ARRAY:
		ck.err(p, "배열이어야 한다")
	else:
		for i in d["drops"].size():
			var dp := "%s[%d]" % [p, i]
			var item: Variant = d["drops"][i]
			if typeof(item) != TYPE_DICTIONARY:
				ck.err(dp, "객체여야 한다")
				continue
			if not ck.keys(item, dp, ["item", "chance"], ["if"]):
				continue
			var drop := {"item": ck.id_of(item, "item", dp, "item."), "chance": ck.int_of(item, "chance", dp, "chance"), "if": {}}
			if item.has("if"):
				drop["if"] = _read_drop_cond(ck, item["if"], dp + ".if")
			e.drops.append(drop)
	if e.id.is_empty() or not _claim(ck, e.id, path):
		return
	enemies[e.id] = e
	enemy_ids.append(e.id)


func _read_ai_rule(ck: _Ck, v: Variant, path: String, last: bool) -> Dictionary:
	var out := {"if": {}, "use": []}
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return out
	if not ck.keys(v, path, ["if", "use"], []):
		return out
	if typeof(v["if"]) != TYPE_DICTIONARY:
		ck.err(path + ".if", "객체여야 한다")
	else:
		var c: Dictionary = v["if"]
		if last and not c.is_empty():
			ck.err(path + ".if", "마지막 규칙의 if 는 빈 객체여야 한다")
		elif not last and c.is_empty():
			ck.err(path + ".if", "마지막이 아닌 규칙은 조건이 하나 이상 있어야 한다")
		for k in c:
			var cp := "%s.if.%s" % [path, k]
			match k:
				"charging":
					if typeof(c[k]) != TYPE_BOOL:
						ck.err(cp, "true·false 여야 한다")
					else:
						out["if"]["charging"] = c[k]
				"turn_mod":
					var nr: Variant = c[k]
					var n: Variant = SaveCodec.to_int(nr[0]) if typeof(nr) == TYPE_ARRAY and nr.size() == 2 else null
					var r: Variant = SaveCodec.to_int(nr[1]) if n != null else null
					if n == null or r == null or typeof(nr[0]) == TYPE_BOOL or typeof(nr[1]) == TYPE_BOOL or not BattleLimits.in_range("turn_mod_n", n) or r < 0 or r >= n:
						ck.err(cp, "[n, r] 정수, 1 ≤ n ≤ 99, 0 ≤ r < n 이어야 한다")
					else:
						out["if"]["turn_mod"] = [n, r]
				"hp_below":
					var h: Variant = ck.int_of(c, k, path + ".if", "hp_below")
					if h != null:
						out["if"]["hp_below"] = h
				_:
					ck.err(cp, "모르는 조건(%s 중 하나)" % ", ".join(AI_CONDS))
	var up := path + ".use"
	if typeof(v["use"]) != TYPE_ARRAY or not BattleLimits.in_range("ai_candidates", v["use"].size()):
		ck.err(up, "후보 %s개의 배열이어야 한다" % BattleLimits.range_text("ai_candidates"))
		return out
	for i in v["use"].size():
		var cp := "%s[%d]" % [up, i]
		var c: Variant = v["use"][i]
		if typeof(c) != TYPE_DICTIONARY:
			ck.err(cp, "객체여야 한다")
			continue
		if not ck.keys(c, cp, ["skill", "weight", "target"], []):
			continue
		var w: Variant = ck.int_of(c, "weight", cp, "ai_weight")
		out["use"].append({"skill": ck.id_of(c, "skill", cp, "skill."), "weight": w if w != null else 1, "target": ck.enum_of(c, "target", cp, AI_TARGETS)})
	return out


func _read_drop_cond(ck: _Ck, v: Variant, path: String) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return out
	for k in v:
		match k:
			"killed_by_element":
				var els := ck.enum_set(v, k, path, BattleLimits.ELEMENTS, false)
				if not els.is_empty():
					out[k] = els
			"killed_while_bound":
				out[k] = ck.enum_of(v, k, path, BattleLimits.PARTS)
			"killed_while_ailment":
				out[k] = ck.enum_of(v, k, path, BattleLimits.AILMENTS)
			_:
				ck.err("%s.%s" % [path, k], "모르는 조건(%s 중 하나)" % ", ".join(DROP_CONDS))
	return out


func _read_encounter(ck: _Ck, d: Dictionary) -> void:
	if not ck.keys(d, "", ["id", "formations", "table"], []):
		return
	var e := EncounterDef.new()
	e.id = ck.id_of(d, "id", "", "encounter.")
	if typeof(d["formations"]) != TYPE_ARRAY:
		ck.err("formations", "배열이어야 한다")
	else:
		for i in d["formations"].size():
			var f := _read_formation(ck, d["formations"][i], "formations[%d]" % i)
			if f != null:
				e.formations.append(f.id)
	if typeof(d["table"]) != TYPE_ARRAY or not BattleLimits.in_range("table_entries", d["table"].size()):
		ck.err("table", "항목 %s개의 배열이어야 한다" % BattleLimits.range_text("table_entries"))
	else:
		for i in d["table"].size():
			var tp := "table[%d]" % i
			var t: Variant = d["table"][i]
			if typeof(t) != TYPE_DICTIONARY:
				ck.err(tp, "객체여야 한다")
				continue
			if not ck.keys(t, tp, ["formation", "weight"], []):
				continue
			var fid := ck.id_of(t, "formation", tp, "formation.")
			var w: Variant = ck.int_of(t, "weight", tp, "table_weight")
			if not fid.is_empty() and not e.formations.has(fid):
				ck.err(tp + ".formation", "%s 이 이 파일의 formations 에 없다" % fid)
			e.table.append({"formation": fid, "weight": w if w != null else 1})
	if e.id.is_empty() or not _claim(ck, e.id, ""):
		return
	encounters[e.id] = e
	encounter_ids.append(e.id)


func _read_formation(ck: _Ck, v: Variant, path: String) -> FormationDef:
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return null
	if not ck.keys(v, path, ["id", "no_escape", "enemies"], []):
		return null
	var f := FormationDef.new()
	f.id = ck.id_of(v, "id", path, "formation.")
	f.no_escape = ck.bool_of(v, "no_escape", path)
	var ep := path + ".enemies"
	if typeof(v["enemies"]) != TYPE_ARRAY or not BattleLimits.in_range("formation_enemies", v["enemies"].size()):
		ck.err(ep, "적 %s의 배열이어야 한다" % BattleLimits.range_text("formation_enemies"))
	else:
		var per_row := {"front": 0, "back": 0}
		for i in v["enemies"].size():
			var xp := "%s[%d]" % [ep, i]
			var x: Variant = v["enemies"][i]
			if typeof(x) != TYPE_DICTIONARY:
				ck.err(xp, "객체여야 한다")
				continue
			if not ck.keys(x, xp, ["enemy", "row"], []):
				continue
			var row := ck.enum_of(x, "row", xp, ROWS)
			if per_row.has(row):
				per_row[row] += 1
			f.enemies.append({"enemy": ck.id_of(x, "enemy", xp, "enemy."), "row": row})
		for row in ROWS:
			if per_row[row] > BattleLimits.ROW_MAX:
				ck.err(ep, "%s 줄의 적이 %d 을 넘는다" % [row, BattleLimits.ROW_MAX])
	if f.id.is_empty() or not _claim(ck, f.id, path):
		return null
	formations[f.id] = f
	formation_ids.append(f.id)
	return f


# ---- 파일 사이 참조 ----

func _claim(ck: _Ck, id: String, path: String) -> bool:
	if _ids.has(id):
		ck.err(_p(path, "id"), "ID %s 가 중복이다(먼저 %s)" % [id, _ids[id]])
		return false
	_ids[id] = ck.file
	return true


func _check_refs() -> void:
	var used_skills := {}
	for cid in class_ids:
		var c: ClassDef = classes[cid]
		var ck := _Ck.new(self, _ids[cid])
		for i in c.skills.size():
			var s: SkillDef = skills.get(c.skills[i])
			if s == null:
				ck.err(cid + ".skills[%d]" % i, "없는 스킬 %s" % c.skills[i])
			elif s.user != "party":
				ck.err(cid + ".skills[%d]" % i, "%s 의 user 가 party 가 아니다" % c.skills[i])
			used_skills[c.skills[i]] = true
	for eid in enemy_ids:
		var e: EnemyDef = enemies[eid]
		var ck := _Ck.new(self, _ids[eid])
		var ep := eid + "."
		var charge_skills: Array[String] = []
		for ri in e.ai.size():
			for ci in e.ai[ri]["use"].size():
				var sid: String = e.ai[ri]["use"][ci]["skill"]
				var s: SkillDef = skills.get(sid)
				used_skills[sid] = true
				if s == null:
					ck.err(ep + "ai[%d].use[%d].skill" % [ri, ci], "없는 스킬 %s" % sid)
				elif s.user != "enemy":
					ck.err(ep + "ai[%d].use[%d].skill" % [ri, ci], "%s 의 user 가 enemy 가 아니다" % sid)
				elif s.effect == "charge":
					charge_skills.append(sid)
		for ri in e.ai.size():
			if not e.ai[ri]["if"].has("charging"):
				continue
			var ok := false
			for sid in charge_skills:
				for c in e.ai[ri]["use"]:
					if c["skill"] == skills[sid].charges:
						ok = true
			if not ok:
				ck.err(ep + "ai[%d].if.charging" % ri, "이 적의 charge 스킬이 가리키는 강공격이 이 규칙 후보에 없다")
		for di in e.drops.size():
			var item: String = e.drops[di]["item"]
			if not item.is_empty() and not materials.has(item):
				ck.err(ep + "drops[%d].item" % di, "없는 소재 %s" % item)
	for sid in skill_ids:
		var s: SkillDef = skills[sid]
		if s.effect == "charge" and not s.charges.is_empty():
			var t: SkillDef = skills.get(s.charges)
			if t == null:
				_Ck.new(self, _ids[sid]).err(sid + ".charges", "없는 스킬 %s" % s.charges)
			elif t.user != s.user:
				_Ck.new(self, _ids[sid]).err(sid + ".charges", "%s 의 user 가 다르다" % s.charges)
	var tabled := {}
	var enemies_used := {}
	for fid in formation_ids:
		var f: FormationDef = formations[fid]
		for i in f.enemies.size():
			var en: String = f.enemies[i]["enemy"]
			if not en.is_empty() and not enemies.has(en):
				_Ck.new(self, _ids[fid]).err(fid + ".enemies[%d].enemy" % i, "없는 적 %s" % en)
	for encid in encounter_ids:
		for t in encounters[encid].table:
			tabled[t["formation"]] = true
	for fid in formation_ids:
		if not tabled.has(fid):
			warnings.append("%s: 어느 출현 표에도 없는 편성" % fid)
			continue
		for x in formations[fid].enemies:
			enemies_used[x["enemy"]] = true
	for eid in enemy_ids:
		if not enemies_used.has(eid):
			warnings.append("%s: 어느 출현 표의 편성에도 없는 적" % eid)
	for sid in skill_ids:
		if not used_skills.has(sid):
			warnings.append("%s: 어느 직업·적도 쓰지 않는 스킬" % sid)


static func _p(path: String, key: String) -> String:
	return key if path.is_empty() else "%s.%s" % [path, key]


## 한 파일의 검사 도우미. 오류는 "파일: 경로: 내용".
class _Ck:
	extends RefCounted
	var db: BattleDb
	var file := ""
	static var _id_re: RegEx

	func _init(target: BattleDb, source: String) -> void:
		db = target
		file = source
		if _id_re == null:
			_id_re = RegEx.create_from_string(ID_PATTERN)

	func err(path: String, msg: String) -> void:
		db.errors.append("%s: %s: %s" % [file, path if not path.is_empty() else "(맨 위)", msg])

	## 필수 키가 모두 있고 모르는 키가 없는지. 오류는 모두 남기고, 필수 키가 다 있으면 true.
	func keys(d: Dictionary, path: String, required: Array, optional: Array) -> bool:
		var ok := true
		for k in required:
			if not d.has(k):
				err(BattleDb._p(path, k), "필수 필드가 없다")
				ok = false
		for k in d:
			if not required.has(k) and not optional.has(k):
				err(BattleDb._p(path, str(k)), "모르는 필드")
		return ok

	func int_of(d: Dictionary, key: String, path: String, range_name: String) -> Variant:
		var v: Variant = SaveCodec.to_int(d.get(key))
		if v == null or typeof(d.get(key)) == TYPE_BOOL or not BattleLimits.in_range(range_name, v):
			err(BattleDb._p(path, key), "정수 %s 이어야 한다" % BattleLimits.range_text(range_name))
			return null
		return v

	func str_of(d: Dictionary, key: String, path: String) -> String:
		if typeof(d.get(key)) != TYPE_STRING or d[key].is_empty():
			err(BattleDb._p(path, key), "비지 않은 문자열이어야 한다")
			return ""
		return d[key]

	func bool_of(d: Dictionary, key: String, path: String) -> bool:
		if typeof(d.get(key)) != TYPE_BOOL:
			err(BattleDb._p(path, key), "true·false 여야 한다")
			return false
		return d[key]

	func id_of(d: Dictionary, key: String, path: String, prefix: String) -> String:
		return id_value(d.get(key), BattleDb._p(path, key), prefix)

	func id_value(v: Variant, full_path: String, prefix: String) -> String:
		if typeof(v) != TYPE_STRING or _id_re.search(v) == null:
			err(full_path, "ID 형식(%s)이 아니다" % ID_PATTERN)
			return ""
		if not v.begins_with(prefix) or v.length() == prefix.length():
			err(full_path, "%s 로 시작하는 ID 여야 한다" % prefix)
			return ""
		return v

	func enum_of(d: Dictionary, key: String, path: String, values: Array) -> String:
		var v: Variant = d.get(key)
		if typeof(v) != TYPE_STRING or not values.has(v):
			err(BattleDb._p(path, key), "다음 중 하나여야 한다: %s" % ", ".join(values))
			return ""
		return v

	## 중복 없는 열거값 배열. allow_empty 가 아니면 하나 이상.
	func enum_set(d: Dictionary, key: String, path: String, values: Array, allow_empty: bool) -> Array[String]:
		var out: Array[String] = []
		var v: Variant = d.get(key)
		if typeof(v) != TYPE_ARRAY or (v.is_empty() and not allow_empty):
			err(BattleDb._p(path, key), "배열이어야 한다" if allow_empty else "값이 하나 이상인 배열이어야 한다")
			return out
		for x in v:
			if typeof(x) != TYPE_STRING or not values.has(x) or out.has(x):
				err(BattleDb._p(path, key), "중복 없는 %s 의 배열이어야 한다" % ", ".join(values))
				return []
			out.append(x)
		return out

	func id_list(d: Dictionary, key: String, path: String, prefix: String) -> Array[String]:
		var out: Array[String] = []
		var v: Variant = d.get(key)
		if typeof(v) != TYPE_ARRAY:
			err(BattleDb._p(path, key), "배열이어야 한다")
			return out
		for i in v.size():
			var id := id_value(v[i], "%s[%d]" % [BattleDb._p(path, key), i], prefix)
			if id.is_empty():
				continue
			if out.has(id):
				err("%s[%d]" % [BattleDb._p(path, key), i], "중복 ID %s" % id)
			else:
				out.append(id)
		return out

	## 키가 정확히 names 인 정수 표(능력치·속성 배율·취약도).
	func table(d: Dictionary, key: String, path: String, names: Array, range_name: String) -> Dictionary:
		var out := {}
		var p := BattleDb._p(path, key)
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			err(p, "객체여야 한다")
			return out
		if not keys(d[key], p, names, []):
			return out
		for n in names:
			var v: Variant = int_of(d[key], n, p, range_name)
			if v != null:
				out[n] = v
		return out
