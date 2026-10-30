## 전투 정의 데이터(data/ 의 rules·classes·skills·enemies·encounters·items) 읽기·검사 → BattleDb (06 §5).
## 채집 표(data/gathering, M3 A5)도 여기서 읽는다(소재 참조를 한곳에서 본다).
## 성장 정의(성장 규칙·레벨 표·스킬 트리·패시브·장비, 07 §7)와 상점 정의(값·판매값·진열, 08 §1)도 여기서 읽는다.
## 오류는 "파일: 필드 경로: 내용". 오류가 하나라도 있으면 이 정의를 쓰지 않는다(06 §5.6).
## 값 범위는 BattleLimits 한 곳에서 온다. 모르는 필드는 거부한다(층 정의와 다르다).
class_name BattleDb
extends RefCounted

## \A·\z: 문자열 전체와 맞춘다($ 는 끝 줄바꿈 앞에서도 맞는다).
const ID_PATTERN := "\\A[a-z0-9_.]+\\z"
const KINDS := ["rules", "classes", "skills", "enemies", "encounters", "items", "shop", "gathering", "foes"]
const RULES_FILE := "rules/battle.json"
const GROWTH_FILE := "rules/growth.json"
const EFFECTS := ["damage", "ailment", "heal", "cure", "revive", "buff", "debuff", "front_guard", "cover", "charge", "passive"]
const TARGETS := ["enemy_one", "enemy_row", "enemy_all", "ally_one", "ally_dead", "ally_other", "ally_all", "ally_row", "self"]
const RANGES_KIND := ["melee", "ranged"]
const PRIORITIES := ["first", "normal", "last"]
const USERS := ["party", "enemy"]
const ON_BOUND := ["switch", "fail"]
const AI_TARGETS := ["random", "lowest_hp", "lowest_hp_ratio"]
const ROWS := ["front", "back"]
const SKILL_COMMON := ["id", "name_key", "user", "effect", "range", "target", "parts", "priority", "speed", "levels"]
## 패시브(07 §4.3·§7.4)는 이 다섯 필드만 갖는다. 대상이 없어 EFFECT_TARGETS 에 넣지 않는다.
const PASSIVE_KEYS := ["id", "name_key", "user", "effect", "levels"]
## desc_key(M3 A7): 길드 직업 고르기의 설명 글(ko.json 에 있어야 한다).
const CLASS_KEYS := ["id", "name_key", "desc_key", "levels", "attack", "resist", "ailment_vuln", "bind_vuln", "equip_kinds", "start_equip", "tree"]
const TREE_KEYS := ["skill", "pos", "requires", "min_level"]
const EQUIP_KEYS := ["id", "name_key", "kind", "price", "atk", "matk", "def", "mdef", "stats", "resist", "ailment_vuln", "bind_vuln"]
## 소재: 설명 글(desc_key)은 M3 A5부터 필수다(소지품 설명 상자).
const MATERIAL_KEYS := ["id", "name_key", "desc_key", "sell"]
## 채집 표(M3 A5, data/gathering/*.json 의 gather_tables): rare 는 선택. 줄은 {item, weight, count: [lo, hi]}.
const GATHER_TABLE_KEYS := ["id", "kind", "items"]
const GATHER_LINE_KEYS := ["item", "weight", "count"]
const GATHER_RARE_KEYS := ["item", "permille"]
## 귀중품(열쇠, M3 A3, data/items/key_items.json): 값이 없고 팔 수 없다.
const KEY_ITEM_KEYS := ["id", "name_key", "desc_key"]
## 소모품(M3 A4, data/items/consumables.json): 이 키는 모두 필수, 효과마다 더 받는 키(CONSUMABLE_EXTRA). 대상은 효과가 정한다(CONSUMABLE_TARGET).
const CONSUMABLE_KEYS := ["id", "name_key", "desc_key", "price", "effect", "where"]
const CONSUMABLE_EXTRA := {"heal": ["amount"], "tp": ["amount"], "revive": ["hp_permille"]}
const CONSUMABLE_TARGET := {
	"heal": "ally_one", "tp": "ally_one", "cure_ailment": "ally_one", "cure_bind": "ally_one", "revive": "ally_dead", "return": "",
}
## 전투 대리 스킬의 effect(규칙 BattleRules._execute 가 이 이름으로 가른다). 회복은 스킬 heal 줄(base = amount, wis_pct 0)을 그대로 쓴다.
const CONSUMABLE_SKILL_EFFECT := {
	"heal": "heal", "tp": "tp_heal", "revive": "revive", "cure_ailment": "cure_ailment", "cure_bind": "cure_bind",
}
## 상점 파일(08 §1.2): 위 단계 키는 모두 필수, 진열 줄은 item 필수·unlock·limited 선택.
const SHOP_KEYS := ["id", "name_key", "stock"]
const STOCK_KEYS := ["item"]
const STOCK_OPTIONAL := ["unlock", "limited"]
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
## 적 buff(M3 A9 보스 「과부하 구동」): 효과 규칙·저장 검사·화면 사본은 편을 가리지 않으므로 쓰는 쪽 조합만 연다(대상은 EFFECT_TARGETS 의 self·ally_*).
const USER_EFFECTS := {
	"party": ["damage", "ailment", "heal", "cure", "revive", "buff", "debuff", "front_guard", "cover", "passive"],
	"enemy": ["damage", "ailment", "debuff", "heal", "charge", "buff"],
}
## 혼란한 적의 내장 공격 스킬 id(confused_attack).
const CONFUSED := "confused"
const DROP_CONDS := ["killed_by_element", "killed_while_bound", "killed_while_ailment"]
const AI_CONDS := ["charging", "turn_mod", "hp_below", "ally_hp_below"]


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
	## 맹목(M3 A7): 명중 판정 길에서 자른 명중률에 곱한다(‰).
	var blind_hit_mult := 500
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


## 성장 규칙(07 §3.2·§7.2). 모든 직업이 같은 경험치 표를 쓴다.
class GrowthDef:
	extends RefCounted
	var level_cap := 30
	var initial_sp := 3
	var sp_per_level := 1
	## exp_next[L − 1]: 레벨 L 에서 L + 1 로 가는 데 드는 경험치(길이 level_cap − 1).
	var exp_next: Array[int] = []
	## _cum[L]: Lv1 에서 L 에 닿기까지의 누적 경험치(_cum[1] = 0). 읽을 때 한 번 만든다.
	var _cum: Array[int] = []

	## 누적 경험치 cum(L)(07 §3.2). L 은 1~level_cap 으로 자른다.
	func cum(level: int) -> int:
		return _cum[clampi(level, 1, level_cap)]

	## 그 레벨까지 얻은 SP(07 §4.1).
	func sp_total(level: int) -> int:
		return initial_sp + (level - 1) * sp_per_level

	func build_cum() -> void:
		_cum = [0, 0]
		for i in exp_next.size():
			_cum.append(_cum[-1] + exp_next[i])


## 스킬 하나. levels[레벨 − 1] 은 그 레벨의 줄(tp 와 effect 별 값, 06 §5.4). 없는 값은 키가 없다.
## 패시브(effect passive)의 줄은 {bonus: {키: 값}} 이고, 채집 보조 패시브(M3 A7)는 gather_rare(희귀 확률 ‰)도 가진다(07 §4.3).
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

	func passive() -> bool:
		return effect == "passive"

	func max_level() -> int:
		return levels.size()

	## 필드를 모두 복사한 새 정의(배열·줄 사전도 새것). 대원마다 일반 공격 사본을 만들 때 쓴다(07 §5.3).
	func copy() -> SkillDef:
		var s := SkillDef.new()
		for k in ["id", "name_key", "user", "effect", "stat", "element", "range_kind", "target", "priority", "speed", "can_crit", "sure_hit", "charges"]:
			s.set(k, get(k))
		s.parts = parts.duplicate()
		s.levels = levels.duplicate(true)
		return s


class ClassDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	## 직업 설명 글 키(M3 A7, 길드의 직업 고르기).
	var desc_key := ""
	## 레벨(int) → {hp, tp, STR, INT, VIT, WIS, AGI, LUC}
	var levels := {}
	var resist := {}
	var ailment_vuln := {}
	var bind_vuln := {}
	## 트리의 스킬 ID(트리 순서 = 화면 목록 순서, 07 §4.2).
	var skills: Array[String] = []
	## 일반 공격(06 §5.3: 속성·사거리만 직업마다, 나머지는 고정). 읽기만 한다: 대원마다 사본을 쓴다(07 §5.3).
	var attack: SkillDef
	## 끼는 장비 종류(07 §5.2).
	var equip_kinds: Array[String] = []
	## 길드에 새로 등록한 대원의 장비 칸 넷(M3 A7, 빈 칸 ""). 장착 규칙은 _check_refs 가 본다.
	var start_equip: Array[String] = ["", "", "", ""]
	## 트리 항목 [{skill, pos: [열, 행], requires: [{skill, level}], min_level}] 트리 순서.
	var tree: Array[Dictionary] = []
	## 스킬 ID → tree 의 칸 번호.
	var tree_index := {}

	func tree_entry(skill_id: String) -> Dictionary:
		return tree[tree_index[skill_id]] if tree_index.has(skill_id) else {}


## 장비 하나(07 §5.5·§7.5). 없는 보정은 키가 없다(0 은 적지 않는다).
class EquipDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	var kind := ""
	## 구매값(08 §1.1). 판매값은 price ÷ 2(버림, 최소 1).
	var price := 1
	## 무기만: 일반 공격 속성.
	var element := ""
	## atk·matk·def·mdef
	var gear := {"atk": 0, "matk": 0, "def": 0, "mdef": 0}
	## 능력치 보정(−99~99)
	var stats := {}
	## 받는 배율 더하기 보정(‰, −3000~3000)
	var resist := {}
	var ailment_vuln := {}
	var bind_vuln := {}
	## 비어 있지 않으면 종류 규칙 대신 이 직업들만 낀다.
	var only_classes: Array[String] = []

	func weapon() -> bool:
		return BattleLimits.WEAPON_KINDS.has(kind)

	func fits(c: ClassDef) -> bool:
		return only_classes.has(c.id) if not only_classes.is_empty() else c.equip_kinds.has(kind)


## 채집 표 하나(M3 A5): 지점 종류, 무게로 고르는 줄(소재 하나·개수 범위), 희귀 소재와 그 확률(천분율, 없으면 rare_item "").
class GatherTableDef:
	extends RefCounted
	var id := ""
	var kind := ""
	## [{item, weight, lo, hi}] 파일 차례.
	var items: Array[Dictionary] = []
	var rare_item := ""
	var rare_permille := 0

	func total_weight() -> int:
		var n := 0
		for x in items:
			n += int(x["weight"])
		return n


## 소모품 하나(M3 A4). where ⊆ battle·camp. skill 은 전투에서 쓰는 대리 스킬(쓰는 곳에 battle 이 있을 때만, 아니면 null):
## 대상 규칙·후보·대상 다시 보기·순서(speed 1000 = AGI 계수 1)를 스킬과 같은 함수로 돌린다. 스킬 사전(skills)에는 넣지 않는다.
class ConsumableDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	var desc_key := ""
	var price := 1
	var effect := ""
	## heal·tp 의 양, revive 의 HP 천분율(쓰지 않는 효과는 0).
	var amount := 0
	var hp_permille := 0
	var where: Array[String] = []
	var skill: SkillDef

	func target() -> String:
		return BattleDb.CONSUMABLE_TARGET.get(effect, "")

	func in_battle() -> bool:
		return where.has("battle")

	func in_camp() -> bool:
		return where.has("camp")


## 상점 하나(08 §1.2). stock 줄은 {item: 장비 또는 소모품 ID(M3 A4), unlock: {소재 ID: 수}(처음부터 팔면 빈 사전), limited: 참·거짓}, 진열 차례.
class ShopDef:
	extends RefCounted
	var id := ""
	var name_key := ""
	var stock: Array[Dictionary] = []
	## stock[i] 가 파일의 몇 번째 줄인지(참조 오류의 경로).
	var stock_at: Array[int] = []

	## 그 장비의 진열 줄. 없으면 빈 사전.
	func line(item_id: String) -> Dictionary:
		for x in stock:
			if x["item"] == item_id:
				return x
		return {}


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


## FOE 정의 하나(M3 A6, 설계 §2.2): 위협 레벨과 무리(적이 정확히 하나인 편성, 도주할 수 있다). 이름은 그 적의 이름이다.
class FoeDef:
	extends RefCounted
	var id := ""
	var level := 1
	var formation := ""
	## 계층 보스(M3 A9): 무리는 도망칠 수 없고(no_escape 참) 적 1~6. 층의 FOE 종류 boss 만 가리킨다(GameDefs.check_foes).
	var boss := false


class EncounterDef:
	extends RefCounted
	var id := ""
	var formations: Array[String] = []
	## [{formation, weight}]
	var table: Array[Dictionary] = []


var rules: Rules
var growth: GrowthDef
var classes := {}
var skills := {}
var enemies := {}
var formations := {}
var encounters := {}
## 소재 ID → name_key
var materials := {}
## 소재 ID → 판매값(08 §1.1)
var material_sell := {}
## 소재 ID → 설명 글 키(M3 A5)
var material_desc := {}
## 채집 표 ID → GatherTableDef(M3 A5)
var gather_tables := {}
## FOE 정의 ID → FoeDef(M3 A6)
var foes := {}
## 귀중품(열쇠) ID → {name_key, desc_key}(M3 A3)
var key_items := {}
## 소모품 ID → ConsumableDef(M3 A4)
var consumables := {}
## 상점 ID → ShopDef
var shops := {}
## 장비 ID → EquipDef
var equipment := {}
## 읽은 순서의 ID 목록(파일 경로 순 → 파일 안 순서). 순회는 이 배열로 한다.
var class_ids: Array[String] = []
var skill_ids: Array[String] = []
var enemy_ids: Array[String] = []
var formation_ids: Array[String] = []
var encounter_ids: Array[String] = []
var material_ids: Array[String] = []
var equipment_ids: Array[String] = []
var key_item_ids: Array[String] = []
var consumable_ids: Array[String] = []
var shop_ids: Array[String] = []
var gather_table_ids: Array[String] = []
var foe_ids: Array[String] = []
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
	for rf in [RULES_FILE, GROWTH_FILE]:
		if not files.has(rf):
			db.errors.append("%s: 파일이 없다" % rf)
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
				elif p == GROWTH_FILE:
					db._read_growth(ck, data)
				else:
					ck.err("", "규칙 파일은 %s·%s 둘이다" % [RULES_FILE, GROWTH_FILE])
			"classes":
				db._read_class(ck, data)
			"skills":
				db._read_list(ck, data, "skills", db._read_skill)
			"enemies":
				db._read_list(ck, data, "enemies", db._read_enemy)
			"encounters":
				db._read_encounter(ck, data)
			"items":
				if data.has("equipment"):
					db._read_list(ck, data, "equipment", db._read_equipment)
				elif data.has("key_items"):
					db._read_list(ck, data, "key_items", db._read_key_item)
				elif data.has("consumables"):
					db._read_list(ck, data, "consumables", db._read_consumable)
				else:
					db._read_list(ck, data, "materials", db._read_material)
			"shop":
				db._read_shop(ck, data)
			"gathering":
				db._read_list(ck, data, "gather_tables", db._read_gather_table)
			"foes":
				db._read_list(ck, data, "foes", db._read_foe)
	db._check_refs()
	return db


func skill(id: String) -> SkillDef:
	return skills.get(id)


## 혼란한 적의 공격(M3 A7 설계 §4.5): 적에게는 일반 공격이 없어 규칙이 이 내장 스킬을 쓴다. 데이터 파일에 없다(스킬 사전에 넣지 않는다).
## id "confused"(처치 기록 by 도 이 값), 타격 STR 위력 100·명중 950, 근접 적 하나, TP 0. 부위는 대원 일반 공격처럼 없다(잠금이 막지 않는다).
static var _confused: SkillDef


static func confused_attack() -> SkillDef:
	if _confused == null:
		var a := SkillDef.new()
		a.id = CONFUSED
		a.name_key = "battle.attack"
		a.user = "enemy"
		a.effect = "damage"
		a.stat = "STR"
		a.element = "bash"
		a.range_kind = "melee"
		a.target = "enemy_one"
		a.can_crit = true
		a.levels = [{"tp": 0, "power": 100, "accuracy": 950}]
		_confused = a
	return _confused


## 층의 출현 표 ID → 그 표의 편성 ID 목록(표 순서).
func table_formations(encounter_id: String) -> Array[String]:
	var out: Array[String] = []
	var e: EncounterDef = encounters.get(encounter_id)
	if e != null:
		for t in e.table:
			out.append(t["formation"])
	return out


func equip(id: String) -> EquipDef:
	return equipment.get(id)


func shop(id: String) -> ShopDef:
	return shops.get(id)


## 소모품 정의(M3 A4). 모르면 null.
func consumable(id: String) -> ConsumableDef:
	return consumables.get(id)


## 소모품의 전투 대리 스킬(M3 A4). 모르거나 전투에서 쓰지 않으면 null.
func item_skill(id: String) -> SkillDef:
	var c: ConsumableDef = consumables.get(id)
	return c.skill if c != null else null


## 모든 name_key(직업·스킬·적·소재·장비·귀중품(이름·설명)·소모품(이름·설명)·상점). GameDefs 가 ko.json 에 있는지 본다.
func name_keys() -> Array[String]:
	var out: Array[String] = []
	for id in class_ids:
		out.append(classes[id].name_key)
		out.append(classes[id].desc_key)
	for id in skill_ids:
		out.append(skills[id].name_key)
	for id in enemy_ids:
		out.append(enemies[id].name_key)
	for id in material_ids:
		out.append(materials[id])
		out.append(material_desc[id])
	for id in equipment_ids:
		out.append(equipment[id].name_key)
	for id in key_item_ids:
		out.append(key_items[id]["name_key"])
		out.append(key_items[id]["desc_key"])
	for id in consumable_ids:
		out.append(consumables[id].name_key)
		out.append(consumables[id].desc_key)
	for id in shop_ids:
		out.append(shops[id].name_key)
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


## 성장 규칙(07 §7.2): 모든 키 필수, 모르는 키 거부, exp_next 길이 = level_cap − 1.
func _read_growth(ck: _Ck, d: Dictionary) -> void:
	if not ck.keys(d, "", ["level_cap", "initial_sp", "sp_per_level", "exp_next"], []):
		return
	var cap: Variant = ck.int_of(d, "level_cap", "", "level_cap")
	var sp0: Variant = ck.int_of(d, "initial_sp", "", "initial_sp")
	var spl: Variant = ck.int_of(d, "sp_per_level", "", "sp_per_level")
	var g := GrowthDef.new()
	var ok := cap != null and sp0 != null and spl != null
	if typeof(d["exp_next"]) != TYPE_ARRAY:
		ck.err("exp_next", "배열이어야 한다")
		return
	if cap != null and d["exp_next"].size() != cap - 1:
		ck.err("exp_next", "길이가 level_cap - 1(%d)이어야 한다(지금 %d)" % [cap - 1, d["exp_next"].size()])
		ok = false
	for i in d["exp_next"].size():
		var v: Variant = SaveCodec.to_int(d["exp_next"][i])
		if v == null or typeof(d["exp_next"][i]) == TYPE_BOOL or not BattleLimits.in_range("exp_next", v):
			ck.err("exp_next[%d]" % i, "정수 %s 이어야 한다" % BattleLimits.range_text("exp_next"))
			ok = false
		else:
			g.exp_next.append(v)
	if not ok:
		return
	g.level_cap = cap
	g.initial_sp = sp0
	g.sp_per_level = spl
	g.build_cum()
	growth = g


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


func _read_key_item(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, KEY_ITEM_KEYS, []):
		return
	var id := ck.id_of(d, "id", path, "key.")
	var nk := ck.str_of(d, "name_key", path)
	var dk := ck.str_of(d, "desc_key", path)
	if id.is_empty() or not _claim(ck, id, path):
		return
	key_items[id] = {"name_key": nk, "desc_key": dk}
	key_item_ids.append(id)


## 소모품(M3 A4). 효과마다 더 받는 키가 정확히 있어야 한다. 쓰는 곳 규칙: return 은 camp 만(전투 중 귀환 없음),
## cure_ailment·cure_bind 는 camp 를 가질 수 없다(상태 이상·잠금은 전투가 끝나면 풀린다, 06 §3.17).
func _read_consumable(ck: _Ck, d: Dictionary, path: String) -> void:
	var effect: Variant = d.get("effect")
	var extra: Array = CONSUMABLE_EXTRA.get(effect, []) if typeof(effect) == TYPE_STRING else []
	if not ck.keys(d, path, CONSUMABLE_KEYS + extra, []):
		return
	var c := ConsumableDef.new()
	c.id = ck.id_of(d, "id", path, "use.")
	c.name_key = ck.str_of(d, "name_key", path)
	c.desc_key = ck.str_of(d, "desc_key", path)
	var price: Variant = ck.int_of(d, "price", path, "price")
	c.price = price if price != null else 1
	c.effect = ck.enum_of(d, "effect", path, BattleLimits.ITEM_EFFECTS)
	c.where = ck.enum_set(d, "where", path, BattleLimits.ITEM_WHERE, false)
	if extra.has("amount"):
		var a: Variant = ck.int_of(d, "amount", path, "item_amount")
		c.amount = a if a != null else 1
	if extra.has("hp_permille"):
		var h: Variant = ck.int_of(d, "hp_permille", path, "hp_permille")
		c.hp_permille = h if h != null else 1
	if c.effect == "return" and not c.where.is_empty() and not (c.where.size() == 1 and c.where[0] == "camp"):
		ck.err(path + ".where", "return 은 [\"camp\"] 만 쓸 수 있다(전투 중에는 귀환하지 않는다)")
	if c.effect.begins_with("cure_") and c.where.has("camp"):
		ck.err(path + ".where", "상태 이상·잠금은 전투가 끝나면 풀리므로 camp 에서 쓸 수 없다")
	if c.id.is_empty() or not _claim(ck, c.id, path):
		return
	if c.in_battle() and CONSUMABLE_SKILL_EFFECT.has(c.effect):
		c.skill = _item_skill_of(c)
	consumables[c.id] = c
	consumable_ids.append(c.id)


## 소모품의 전투 대리 스킬(M3 A4 설계 §2.3): 사거리 원거리·부위 없음(잠금이 막지 않는다)·보통 우선·속도 1000(AGI 계수 1)·필중, TP 0.
static func _item_skill_of(c: ConsumableDef) -> SkillDef:
	var s := SkillDef.new()
	s.id = c.id
	s.name_key = c.name_key
	s.user = "item"
	s.effect = CONSUMABLE_SKILL_EFFECT[c.effect]
	s.range_kind = "ranged"
	s.target = c.target()
	s.priority = "normal"
	s.speed = 1000
	s.sure_hit = true
	var row := {"tp": 0}
	match c.effect:
		"heal":
			row["base"] = c.amount
			row["wis_pct"] = 0
		"tp":
			row["amount"] = c.amount
		"revive":
			row["hp_permille"] = c.hp_permille
	s.levels = [row]
	return s


func _read_material(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, MATERIAL_KEYS, []):
		return
	var id := ck.id_of(d, "id", path, "item.")
	var nk := ck.str_of(d, "name_key", path)
	var dk := ck.str_of(d, "desc_key", path)
	var sell: Variant = ck.int_of(d, "sell", path, "sell")
	if id.is_empty() or not _claim(ck, id, path):
		return
	materials[id] = nk
	material_desc[id] = dk
	material_sell[id] = sell if sell != null else 1
	material_ids.append(id)


## 채집 표(M3 A5): 키가 정확히 id·kind·items(+ 선택 rare). 줄은 1~GATHER_ITEMS_MAX 개, 소재 ID(item.)·무게 1~1000·개수 [lo, hi]
## (1 ≤ lo ≤ hi ≤ GATHER_COUNT_MAX). rare 는 {item, permille 1~1000}. 소재가 있는지는 _check_refs 가 본다(파일 차례와 무관하게).
func _read_gather_table(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, GATHER_TABLE_KEYS, ["rare"]):
		return
	var g := GatherTableDef.new()
	g.id = ck.id_of(d, "id", path, "gather.")
	g.kind = ck.enum_of(d, "kind", path, BattleLimits.GATHER_KINDS)
	var ok := not g.id.is_empty() and not g.kind.is_empty()
	var list: Variant = d["items"]
	if typeof(list) != TYPE_ARRAY or list.is_empty() or list.size() > BattleLimits.GATHER_ITEMS_MAX:
		ck.err(_p(path, "items"), "줄이 1~%d 개인 배열이어야 한다" % BattleLimits.GATHER_ITEMS_MAX)
		ok = false
	else:
		for i in list.size():
			var lp := "%s[%d]" % [_p(path, "items"), i]
			var x: Variant = list[i]
			if typeof(x) != TYPE_DICTIONARY:
				ck.err(lp, "객체여야 한다")
				ok = false
				continue
			if not ck.keys(x, lp, GATHER_LINE_KEYS, []):
				ok = false
				continue
			var item := ck.id_of(x, "item", lp, "item.")
			var w: Variant = ck.int_of(x, "weight", lp, "gather_weight")
			var c: Variant = x["count"]
			var lo: Variant = null
			var hi: Variant = null
			if typeof(c) == TYPE_ARRAY and c.size() == 2 and typeof(c[0]) != TYPE_BOOL and typeof(c[1]) != TYPE_BOOL:
				lo = SaveCodec.to_int(c[0])
				hi = SaveCodec.to_int(c[1])
			if lo == null or hi == null or not BattleLimits.in_range("gather_count", lo) or not BattleLimits.in_range("gather_count", hi) or lo > hi:
				ck.err(_p(lp, "count"), "[lo, hi] 정수 쌍이어야 한다(둘 다 1~%d, lo 는 hi 이하)" % BattleLimits.GATHER_COUNT_MAX)
				ok = false
				continue
			if item.is_empty() or w == null:
				ok = false
				continue
			g.items.append({"item": item, "weight": w, "lo": lo, "hi": hi})
	if d.has("rare"):
		var rp := _p(path, "rare")
		if typeof(d["rare"]) != TYPE_DICTIONARY:
			ck.err(rp, "객체여야 한다")
			ok = false
		elif ck.keys(d["rare"], rp, GATHER_RARE_KEYS, []):
			g.rare_item = ck.id_of(d["rare"], "item", rp, "item.")
			var pm: Variant = ck.int_of(d["rare"], "permille", rp, "gather_permille")
			if g.rare_item.is_empty() or pm == null:
				ok = false
			else:
				g.rare_permille = pm
		else:
			ok = false
	if not ok or not _claim(ck, g.id, path):
		return
	gather_tables[g.id] = g
	gather_table_ids.append(g.id)


## FOE 정의(M3 A6, 설계 §2.2): {id, level, formation} + 선택 boss(M3 A9, 참·거짓). formation 은 편성 읽기(_read_formation)를 그대로 거쳐
## formations 에 들어간다. 보스가 아니면 적이 정확히 하나, no_escape 거짓(FOE 는 도망칠 수 있다). 보스면 no_escape 참, 적 1~6(편성 읽기가 본다).
## 적이 있는지는 _check_refs 가 본다.
## FOE 의 편성은 출현 표에 없어도 경고하지 않고 그 적도 쓰인 것으로 센다.
func _read_foe(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, ["id", "level", "formation"], ["boss"]):
		return
	var fd := FoeDef.new()
	fd.id = ck.id_of(d, "id", path, "foe.")
	var lv: Variant = ck.int_of(d, "level", path, "foe_level")
	fd.level = lv if lv != null else 1
	if d.has("boss"):
		fd.boss = ck.bool_of(d, "boss", path)
	var f := _read_formation(ck, d["formation"], _p(path, "formation"))
	if f == null:
		return
	if fd.boss:
		if not f.no_escape:
			ck.err(_p(path, "formation.no_escape"), "보스의 무리는 도망칠 수 없어야 한다(true)")
			return
	else:
		if f.enemies.size() != 1:
			ck.err(_p(path, "formation.enemies"), "FOE 의 무리는 적 하나여야 한다")
			return
		if f.no_escape:
			ck.err(_p(path, "formation.no_escape"), "FOE 의 무리는 도망칠 수 있어야 한다(false)")
			return
	fd.formation = f.id
	if fd.id.is_empty() or not _claim(ck, fd.id, path):
		return
	foes[fd.id] = fd
	foe_ids.append(fd.id)


## FOE 정의(M3 A6). 없으면 null.
func foe(id: String) -> FoeDef:
	return foes.get(id)


func gather_table(id: String) -> GatherTableDef:
	return gather_tables.get(id)


## 장비(07 §7.5). 무기 종류만 element(필수), 그 밖은 element 가 있으면 오류. only_classes 만 선택.
func _read_equipment(ck: _Ck, d: Dictionary, path: String) -> void:
	var weapon := BattleLimits.WEAPON_KINDS.has(d.get("kind"))
	if not weapon and d.has("element"):
		ck.err(path + ".element", "무기 종류(%s)만 element 를 가진다" % ", ".join(BattleLimits.WEAPON_KINDS))
	if not ck.keys(d, path, EQUIP_KEYS + (["element"] if weapon else []), ["only_classes", "element"]):
		return
	var e := EquipDef.new()
	e.id = ck.id_of(d, "id", path, "equip.")
	e.name_key = ck.str_of(d, "name_key", path)
	e.kind = ck.enum_of(d, "kind", path, BattleLimits.WEAPON_KINDS + BattleLimits.ARMOR_KINDS)
	var price: Variant = ck.int_of(d, "price", path, "price")
	e.price = price if price != null else 1
	if weapon:
		e.element = ck.enum_of(d, "element", path, BattleLimits.ELEMENTS)
	for g in BattleLimits.GEAR:
		var v: Variant = ck.int_of(d, g, path, "gear")
		e.gear[g] = v if v != null else 0
	e.stats = ck.delta_table(d, "stats", path, BattleLimits.STATS, "equip_stat",
		"능력치 6종(%s)만 받는다(HP·TP 보정은 없다, 설계 07의 5.3)" % ", ".join(BattleLimits.STATS))
	e.resist = ck.delta_table(d, "resist", path, BattleLimits.ELEMENTS, "equip_delta", "")
	e.ailment_vuln = ck.delta_table(d, "ailment_vuln", path, BattleLimits.AILMENTS, "equip_delta", "")
	e.bind_vuln = ck.delta_table(d, "bind_vuln", path, BattleLimits.PARTS, "equip_delta", "")
	if d.has("only_classes"):
		e.only_classes = ck.id_list(d, "only_classes", path, "class.")
		if typeof(d["only_classes"]) == TYPE_ARRAY and d["only_classes"].is_empty():
			ck.err(path + ".only_classes", "직업 ID 가 하나 이상인 배열이어야 한다(없으면 필드를 쓰지 않는다)")
	if e.id.is_empty() or not _claim(ck, e.id, path):
		return
	equipment[e.id] = e
	equipment_ids.append(e.id)


func _read_skill(ck: _Ck, d: Dictionary, path: String) -> void:
	var effect := str(d.get("effect", ""))
	if not EFFECTS.has(effect):
		ck.err(path + ".effect", "다음 중 하나여야 한다: %s" % ", ".join(EFFECTS))
		return
	if effect == "passive":
		_read_passive(ck, d, path)
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
	if _levels_ok(ck, d, path):
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


## 스킬 줄 수(= 최대 레벨) 1~10(07 §7.4, BattleLimits skill_level).
func _levels_ok(ck: _Ck, d: Dictionary, path: String) -> bool:
	if typeof(d["levels"]) != TYPE_ARRAY or not BattleLimits.in_range("skill_level", d["levels"].size()):
		ck.err(path + ".levels", "줄이 하나 이상 %d개 이하인 배열이어야 한다" % BattleLimits.RANGES["skill_level"][1])
		return false
	return true


## 패시브(07 §4.3·§7.4): 다섯 필드만, 줄은 {bonus} 만. bonus 키는 PASSIVE_KEYS 가운데 하나 이상이고 모든 줄이 같은 키,
## 값은 레벨이 오를 때 줄지 않는다(줄면 배분 때 최대 HP 가 줄어 HP 자르기가 생긴다).
func _read_passive(ck: _Ck, d: Dictionary, path: String) -> void:
	if not ck.keys(d, path, PASSIVE_KEYS, []):
		return
	var s := SkillDef.new()
	s.effect = "passive"
	s.id = ck.id_of(d, "id", path, "skill.")
	s.name_key = ck.str_of(d, "name_key", path)
	s.user = ck.enum_of(d, "user", path, USERS)
	if s.user == "enemy":
		ck.err(path + ".effect", "user enemy 에는 effect passive 를 쓸 수 없다(%s 만)" % ", ".join(USER_EFFECTS["enemy"]))
	elif not s.id.is_empty() and (s.id.begins_with("skill.enemy.") or s.id.get_slice_count(".") < 3):
		ck.err(path + ".id", "파티 스킬 ID 는 skill.<직업>.<이름> 꼴이어야 한다")
	if _levels_ok(ck, d, path):
		var first_keys: Array = []
		var rare := []  # 줄마다 gather_rare 또는 null(M3 A7 채집 보조)
		for i in d["levels"].size():
			var rp := "%s.levels[%d]" % [path, i]
			var v: Variant = d["levels"][i]
			var row := {}
			if typeof(v) != TYPE_DICTIONARY:
				ck.err(rp, "객체여야 한다")
			elif ck.keys(v, rp, ["bonus"], ["gather_rare"]):
				row = _read_bonus(ck, v["bonus"], rp + ".bonus")
				if v.has("gather_rare"):
					var gr: Variant = ck.int_of(v, "gather_rare", rp, "gather_permille")
					if gr != null:
						rare.append(gr)
				else:
					rare.append(null)
			if i == 0:
				first_keys = row.keys()
				first_keys.sort()
			elif not row.is_empty():
				var keys: Array = row.keys()
				keys.sort()
				if keys != first_keys:
					ck.err(rp + ".bonus", "모든 줄의 bonus 키가 같아야 한다(levels[0] 은 %s)" % ", ".join(first_keys))
				else:
					var prev: Dictionary = s.levels[i - 1].get("bonus", {})
					for k in keys:
						if prev.has(k) and row[k] < prev[k]:
							ck.err("%s.bonus.%s" % [rp, k], "앞 레벨보다 작다(패시브 보정은 레벨이 오를 때 줄지 않는다)")
			var lr := {"bonus": row}
			if rare.size() == i + 1 and rare[i] != null:
				lr["gather_rare"] = rare[i]
			s.levels.append(lr)
		# 채집 보조(M3 A7): gather_rare 는 모든 줄에 있거나 모든 줄에 없고, 레벨이 오를 때 줄지 않는다.
		if rare.size() == d["levels"].size() and rare.has(null) and rare.any(func(x: Variant) -> bool: return x != null):
			ck.err(path + ".levels", "gather_rare 는 모든 줄에 있거나 모든 줄에 없어야 한다")
		elif rare.size() == d["levels"].size() and not rare.has(null):
			for i in range(1, rare.size()):
				if rare[i] < rare[i - 1]:
					ck.err("%s.levels[%d].gather_rare" % [path, i], "앞 레벨보다 작다")
	if s.id.is_empty() or not _claim(ck, s.id, path):
		return
	skills[s.id] = s
	skill_ids.append(s.id)


func _read_bonus(ck: _Ck, v: Variant, path: String) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		ck.err(path, "키가 하나 이상인 객체여야 한다(%s)" % ", ".join(BattleLimits.PASSIVE_KEYS))
		return out
	for k in v:
		if not BattleLimits.PASSIVE_KEYS.has(k):
			ck.err("%s.%s" % [path, str(k)], "모르는 필드(%s 중 하나)" % ", ".join(BattleLimits.PASSIVE_KEYS))
			continue
		var n: Variant = ck.int_of(v, k, path, "passive_max" if str(k).begins_with("max_") else "passive_stat")
		if n != null:
			out[k] = n
	return out


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
	if not ck.keys(d, "", CLASS_KEYS, []):
		return
	var c := ClassDef.new()
	c.id = ck.id_of(d, "id", "", "class.")
	c.name_key = ck.str_of(d, "name_key", "")
	c.desc_key = ck.str_of(d, "desc_key", "")
	if typeof(d["levels"]) != TYPE_DICTIONARY or d["levels"].is_empty():
		ck.err("levels", "레벨이 하나 이상인 객체여야 한다")
	else:
		for lk in d["levels"]:
			var path := "levels.%s" % lk
			var lv := int(str(lk)) if str(lk).is_valid_int() else 0
			if str(lv) != str(lk) or not BattleLimits.in_range("level", lv):
				ck.err(path, "레벨 키는 \"1\"~\"level_cap\" 의 10진 정수여야 한다")
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
	c.equip_kinds = ck.enum_set(d, "equip_kinds", "", BattleLimits.WEAPON_KINDS + BattleLimits.ARMOR_KINDS, false)
	if not c.equip_kinds.is_empty() and not c.equip_kinds.any(func(k: String) -> bool: return BattleLimits.WEAPON_KINDS.has(k)):
		ck.err("equip_kinds", "무기 종류(%s)가 하나 이상 있어야 한다" % ", ".join(BattleLimits.WEAPON_KINDS))
	_read_start_equip(ck, d, c)
	_read_tree(ck, d, c)
	if c.id.is_empty() or not _claim(ck, c.id, ""):
		return
	classes[c.id] = c
	class_ids.append(c.id)


## 등록 장비(M3 A7): 길이 EQUIP_SLOTS, 칸마다 null 또는 equip. 장비 ID. 있는 장비인지·장착 규칙은 _check_refs.
func _read_start_equip(ck: _Ck, d: Dictionary, c: ClassDef) -> void:
	var v: Variant = d["start_equip"]
	if typeof(v) != TYPE_ARRAY or v.size() != BattleLimits.EQUIP_SLOTS:
		ck.err("start_equip", "길이 %d 의 배열이어야 한다(칸마다 장비 ID 또는 null)" % BattleLimits.EQUIP_SLOTS)
		return
	var out: Array[String] = []
	for i in v.size():
		if v[i] == null:
			out.append("")
		elif typeof(v[i]) != TYPE_STRING or not str(v[i]).begins_with("equip."):
			ck.err("start_equip[%d]" % i, "null 또는 equip. 로 시작하는 장비 ID 여야 한다")
			return
		else:
			out.append(v[i])
	c.start_equip = out


## 트리(07 §4.2·§7.3): 항목마다 skill·pos·requires·min_level. 참조·순서·레벨 관계는 _check_tree 가 본다.
func _read_tree(ck: _Ck, d: Dictionary, c: ClassDef) -> void:
	var v: Variant = d["tree"]
	if typeof(v) != TYPE_ARRAY or not BattleLimits.in_range("tree_size", v.size()):
		ck.err("tree", "항목 %s개의 배열이어야 한다" % BattleLimits.range_text("tree_size"))
		return
	for i in v.size():
		var p := "tree[%d]" % i
		var x: Variant = v[i]
		if typeof(x) != TYPE_DICTIONARY:
			ck.err(p, "객체여야 한다")
			continue
		if not ck.keys(x, p, TREE_KEYS, []):
			continue
		var e := {"skill": ck.id_of(x, "skill", p, "skill."), "pos": [], "requires": [], "min_level": 1}
		var pos: Variant = x["pos"]
		var col: Variant = SaveCodec.to_int(pos[0]) if typeof(pos) == TYPE_ARRAY and pos.size() == 2 and typeof(pos[0]) != TYPE_BOOL else null
		var row: Variant = SaveCodec.to_int(pos[1]) if col != null and typeof(pos[1]) != TYPE_BOOL else null
		if not BattleLimits.in_range("tree_col", col) or not BattleLimits.in_range("tree_row", row):
			ck.err(p + ".pos", "[열 %s, 행 %s] 정수 둘이어야 한다" % [BattleLimits.range_text("tree_col"), BattleLimits.range_text("tree_row")])
		else:
			e["pos"] = [col, row]
		if typeof(x["requires"]) != TYPE_ARRAY:
			ck.err(p + ".requires", "배열이어야 한다")
		else:
			for j in x["requires"].size():
				var rp := "%s.requires[%d]" % [p, j]
				var r: Variant = x["requires"][j]
				if typeof(r) != TYPE_DICTIONARY:
					ck.err(rp, "객체여야 한다")
					continue
				if not ck.keys(r, rp, ["skill", "level"], []):
					continue
				var lv: Variant = ck.int_of(r, "level", rp, "skill_level")
				e["requires"].append({"skill": ck.id_of(r, "skill", rp, "skill."), "level": lv if lv != null else 1})
		var ml: Variant = ck.int_of(x, "min_level", p, "level")
		e["min_level"] = ml if ml != null else 1
		if not e["skill"].is_empty() and not c.tree_index.has(e["skill"]):
			c.tree_index[e["skill"]] = c.tree.size()
			c.skills.append(e["skill"])
		c.tree.append(e)


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
						ck.err(cp, "[n, r] 정수, 1 <= n <= 99, 0 <= r < n 이어야 한다")
					else:
						out["if"]["turn_mod"] = [n, r]
				"hp_below":
					var h: Variant = ck.int_of(c, k, path + ".if", "hp_below")
					if h != null:
						out["if"]["hp_below"] = h
				"ally_hp_below":
					# M3 A3c: 같은 편(자기 포함) 살아 있는 유닛 중 하나라도 HP 가 이 값(‰) 미만. 범위는 hp_below 와 같다.
					var ah: Variant = ck.int_of(c, k, path + ".if", "hp_below")
					if ah != null:
						out["if"]["ally_hp_below"] = ah
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


## 상점 파일(08 §1.2). 장비·소재 참조는 _check_refs 가 본다(파일 경로 순과 무관하게).
func _read_shop(ck: _Ck, d: Dictionary) -> void:
	if not ck.keys(d, "", SHOP_KEYS, []):
		return
	var sh := ShopDef.new()
	sh.id = ck.id_of(d, "id", "", "shop.")
	sh.name_key = ck.str_of(d, "name_key", "")
	if typeof(d["stock"]) != TYPE_ARRAY or d["stock"].is_empty():
		ck.err("stock", "줄이 하나 이상인 배열이어야 한다")
	else:
		var seen := {}
		for i in d["stock"].size():
			var path := "stock[%d]" % i
			var line := _read_stock_line(ck, d["stock"][i], path)
			if line.is_empty():
				continue
			if seen.has(line["item"]):
				ck.err(path + ".item", "같은 장비 %s 가 stock[%d] 에도 있다(한 상점에 한 줄)" % [line["item"], seen[line["item"]]])
				continue
			seen[line["item"]] = i
			sh.stock.append(line)
			sh.stock_at.append(i)
	if sh.id.is_empty() or not _claim(ck, sh.id, ""):
		return
	shops[sh.id] = sh
	shop_ids.append(sh.id)


## 진열 줄 하나. 오류가 있으면 빈 사전(오류는 모두 남긴다).
func _read_stock_line(ck: _Ck, v: Variant, path: String) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		ck.err(path, "객체여야 한다")
		return {}
	if not ck.keys(v, path, STOCK_KEYS, STOCK_OPTIONAL):
		return {}
	var before := errors.size()
	var raw: Variant = v.get("item")
	var item := ck.id_of(v, "item", path, "use." if typeof(raw) == TYPE_STRING and raw.begins_with("use.") else "equip.")
	var unlock := {}
	if v.has("unlock"):
		var u: Variant = v["unlock"]
		if typeof(u) != TYPE_DICTIONARY or u.is_empty():
			ck.err(path + ".unlock", "소재 ID 와 수(%s)가 하나 이상인 객체여야 한다(처음부터 팔면 필드를 쓰지 않는다)" % BattleLimits.range_text("unlock"))
		else:
			for k in u:
				var id := ck.id_value(k, "%s.unlock.%s" % [path, str(k)], "item.")
				var n: Variant = ck.int_of(u, k, path + ".unlock", "unlock")
				if not id.is_empty() and n != null:
					unlock[id] = n
	var limited := false
	if v.has("limited"):
		limited = ck.bool_of(v, "limited", path)
		if limited and not v.has("unlock"):
			ck.err(path + ".limited", "한정 줄은 unlock 이 있어야 한다")
	if errors.size() != before or item.is_empty():
		return {}
	return {"item": item, "unlock": unlock, "limited": limited}


# ---- 파일 사이 참조 ----

func _claim(ck: _Ck, id: String, path: String) -> bool:
	if _ids.has(id):
		ck.err(_p(path, "id"), "ID %s 가 중복이다(먼저 %s)" % [id, _ids[id]])
		return false
	_ids[id] = ck.file
	return true


func _check_refs() -> void:
	var used_skills := {}
	var tree_owner := {}
	for cid in class_ids:
		var c: ClassDef = classes[cid]
		var ck := _Ck.new(self, _ids[cid])
		_check_levels(ck, c)
		_check_tree(ck, c, tree_owner)
		for sid in c.skills:
			used_skills[sid] = true
		var unknown := false
		for i in c.start_equip.size():
			if not c.start_equip[i].is_empty() and not equipment.has(c.start_equip[i]):
				ck.err("start_equip[%d]" % i, "없는 장비 %s" % c.start_equip[i])
				unknown = true
		if not unknown:
			var bad := GrowthRules.equip_problem(self, c, c.start_equip)
			if not bad.is_empty():
				ck.err("start_equip[%d]" % bad[0], bad[1])
	for id in equipment_ids:
		var e: EquipDef = equipment[id]
		var ck := _Ck.new(self, _ids[id])
		for i in e.only_classes.size():
			if not classes.has(e.only_classes[i]):
				ck.err("%s.only_classes[%d]" % [id, i], "없는 직업 %s" % e.only_classes[i])
		if not class_ids.any(func(cid: String) -> bool: return e.fits(classes[cid])):
			warnings.append("%s: 어느 직업도 낄 수 없는 장비" % id)
	var stocked := {}
	for sid in shop_ids:
		var sh: ShopDef = shops[sid]
		var ck := _Ck.new(self, _ids[sid])
		for i in sh.stock.size():
			var line: Dictionary = sh.stock[i]
			var p := "stock[%d]" % sh.stock_at[i]
			stocked[line["item"]] = true
			if line["item"].begins_with("use."):
				if not consumables.has(line["item"]):
					ck.err(p + ".item", "없는 소모품 %s" % line["item"])
			elif not equipment.has(line["item"]):
				ck.err(p + ".item", "없는 장비 %s" % line["item"])
			for m in line["unlock"]:
				if not materials.has(m):
					ck.err("%s.unlock.%s" % [p, m], "없는 소재 %s" % m)
	for id in equipment_ids:
		if not stocked.has(id):
			warnings.append("%s: 어느 상점에도 없는 장비" % id)
	for id in consumable_ids:
		if not stocked.has(id):
			warnings.append("%s: 어느 상점에도 없는 소모품" % id)
	# 채집 표의 소재(M3 A5): 줄과 희귀 소재가 정의에 있는 소재인지.
	for gid in gather_table_ids:
		var g: GatherTableDef = gather_tables[gid]
		var ck := _Ck.new(self, _ids[gid])
		for i in g.items.size():
			if not materials.has(g.items[i]["item"]):
				ck.err("%s.items[%d].item" % [gid, i], "없는 소재 %s" % g.items[i]["item"])
		if not g.rare_item.is_empty() and not materials.has(g.rare_item):
			ck.err(gid + ".rare.item", "없는 소재 %s" % g.rare_item)
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
	# FOE 의 무리(M3 A6)는 출현 표 대신 층의 FOE 가 쓴다.
	for foid in foe_ids:
		tabled[foes[foid].formation] = true
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


## 직업 레벨 표와 성장 규칙(07 §3.3·§7.8): 키가 1~level_cap 전부, hp·tp 는 레벨이 오를 때 줄지 않는다.
func _check_levels(ck: _Ck, c: ClassDef) -> void:
	if growth == null:
		return
	for lv in c.levels:
		if lv > growth.level_cap:
			ck.err("levels.%d" % lv, "level_cap %d 을 넘는 레벨이다" % growth.level_cap)
	for lv in range(1, growth.level_cap + 1):
		if not c.levels.has(lv):
			ck.err("levels", "레벨 %d 이 없다(1~level_cap %d 전부 있어야 한다)" % [lv, growth.level_cap])
			return
	for lv in range(2, growth.level_cap + 1):
		for k in ["hp", "tp"]:
			var a: Variant = c.levels[lv - 1][k]
			var b: Variant = c.levels[lv][k]
			if typeof(a) == TYPE_INT and typeof(b) == TYPE_INT and b < a:
				ck.err("levels.%d.%s" % [lv, k], "앞 레벨보다 작다(HP·TP 는 레벨이 오를 때 줄지 않는다)")


## 트리 관계(07 §4.2·§7.8): 그 직업 접두사의 파티 스킬, 트리 안 중복·칸 중복 없음, 선행은 앞에 나온 스킬·레벨 1~그 스킬 최대,
## 같은 스킬을 두 번 요구하지 않음, 관문 1~level_cap, 한 스킬이 두 트리에 없음.
func _check_tree(ck: _Ck, c: ClassDef, tree_owner: Dictionary) -> void:
	var prefix := "skill.%s." % c.id.trim_prefix("class.")
	var seen := {}
	var cells := {}
	for i in c.tree.size():
		var e: Dictionary = c.tree[i]
		var p := "%s.tree[%d]" % [c.id, i]
		var sid: String = e["skill"]
		if sid.is_empty():
			continue
		var s: SkillDef = skills.get(sid)
		if s == null:
			ck.err(p + ".skill", "없는 스킬 %s" % sid)
		elif s.user != "party":
			ck.err(p + ".skill", "%s 의 user 가 party 가 아니다" % sid)
		elif not sid.begins_with(prefix):
			ck.err(p + ".skill", "%s 는 이 직업(%s)의 스킬이 아니다" % [sid, prefix])
		if seen.has(sid):
			ck.err(p + ".skill", "트리에 %s 가 두 번 있다" % sid)
		elif tree_owner.has(sid):
			ck.err(p + ".skill", "%s 가 %s 트리에도 있다" % [sid, tree_owner[sid]])
		tree_owner[sid] = c.id
		var pos: Array = e["pos"]
		if not pos.is_empty():
			var key := "%d,%d" % [pos[0], pos[1]]
			if cells.has(key):
				ck.err(p + ".pos", "칸 [%s] 이 %s 와 겹친다" % [key, cells[key]])
			cells[key] = sid
		var asked := {}
		for j in e["requires"].size():
			var r: Dictionary = e["requires"][j]
			var rp := "%s.requires[%d]" % [p, j]
			if r["skill"].is_empty():
				continue
			if not seen.has(r["skill"]):
				ck.err(rp + ".skill", "선행 %s 는 트리에서 앞에 나온 스킬이어야 한다" % r["skill"])
			elif skills.has(r["skill"]) and r["level"] > skills[r["skill"]].max_level():
				ck.err(rp + ".level", "선행 레벨 %d 이 %s 의 최대 레벨 %d 을 넘는다" % [r["level"], r["skill"], skills[r["skill"]].max_level()])
			if asked.has(r["skill"]):
				ck.err(rp + ".skill", "같은 선행 스킬 %s 를 두 번 요구한다" % r["skill"])
			asked[r["skill"]] = true
		if growth != null and e["min_level"] > growth.level_cap:
			ck.err(p + ".min_level", "정수 1~level_cap(%d) 이어야 한다" % growth.level_cap)
		seen[sid] = true


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

	## 키 ⊆ names 인 0 이 아닌 정수 표(장비 보정, 07 §7.5). bad_key 가 있으면 모르는 키의 오류 문장.
	func delta_table(d: Dictionary, key: String, path: String, names: Array, range_name: String, bad_key: String) -> Dictionary:
		var out := {}
		var p := BattleDb._p(path, key)
		if typeof(d.get(key)) != TYPE_DICTIONARY:
			err(p, "객체여야 한다")
			return out
		for k in d[key]:
			if not names.has(k):
				err("%s.%s" % [p, str(k)], bad_key if not bad_key.is_empty() else "모르는 필드(%s 중 하나)" % ", ".join(names))
				continue
			var v: Variant = int_of(d[key], k, p, range_name)
			if v == null:
				continue
			if v == 0:
				err("%s.%s" % [p, k], "0 은 적지 않는다(보정이 없으면 키를 뺀다)")
				continue
			out[k] = v
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
