## 전투 값 범위의 유일한 출처(06 §5.6 공통 값 범위, §5.2 규칙 상수 범위).
## 정의 읽기(BattleDb)·규칙 실행(BattleRules)·저장 검사(SaveCodec)가 모두 이 함수들을 부른다. 범위를 다른 곳에 따로 적지 않는다.
## 범위를 넓히면 06 §3.1 산술 상한 표를 다시 계산하고 tests/test_battle_rules_calc.gd 「산술 경계」를 고친다.
class_name BattleLimits
extends RefCounted

const STATS := ["STR", "INT", "VIT", "WIS", "AGI", "LUC"]
const GEAR := ["atk", "matk", "def", "mdef"]
const ELEMENTS := ["slash", "pierce", "bash", "fire", "ice", "volt"]
const PHYSICAL := ["slash", "pierce", "bash"]
const AILMENTS := ["poison", "paralysis", "sleep"]
const PARTS := ["head", "arm", "leg"]
## 상태이상 우선순위(06 §3.11): 새 상태가 지금 것 이상이면 덮어쓴다.
const AILMENT_PRIORITY := {"sleep": 3, "paralysis": 2, "poison": 1}
const EFFECT_KINDS := ["phys_atk", "elem_atk", "phys_def", "elem_def"]

## 턴 상한(06 §3.15 6단계·§8.5): 턴 끝에서 turn 이 이 값이면 도주(turn_cap)로 끝낸다.
const TURN_MAX := 99999
## 효과 seq 상한(06 §3.14): 새로 줄 battle.seq 가 여기 닿으면 모든 효과 seq 를 순서대로 다시 매긴다.
const SEQ_MAX := 2147483647

## 공통 값 범위 [최소, 최대] (06 §5.6 표와 같은 값. 「그 밖에」 범위도 여기 둔다).
const RANGES := {
	"max_hp": [1, 9999], "max_tp": [1, 9999],
	"stat": [1, 999], "gear": [0, 999],
	"resist": [0, 3000], "vuln": [0, 3000],
	"chance": [0, 1000], "accuracy": [0, 1000],
	"power": [1, 2000],
	"turns": [1, 9],
	"poison_damage": [1, 9999],
	"effect_value": [1, 3000],
	"front_guard": [1, 1000],
	"heal_base": [0, 999], "heal_wis_pct": [0, 1000],
	"hp_permille": [1, 1000],
	"speed": [100, 3000],
	"material": [1, 9999],
	"ai_weight": [1, 1000], "ai_candidates": [1, 8],
	"table_weight": [1, 1000], "table_entries": [1, 32],
	"turn_mod_n": [1, 99], "hp_below": [1, 1000],
	"formation_enemies": [1, 6],
	"exp": [0, 99999],
	"level": [1, 99],
	"tp_cost": [0, 9999],
	# 성장(07 §7.7). level 은 형식 범위이고 대원 레벨은 관계 검사로 level_cap 까지.
	"level_cap": [2, 99],
	"skill_level": [1, 10],
	"initial_sp": [0, 99], "sp_per_level": [0, 9],
	"exp_next": [1, 999999],
	"exp_total": [0, 99999999],
	"exp_grant": [1, 999999],
	"tree_size": [1, 15],
	"tree_col": [0, 3], "tree_row": [0, 4],
	"passive_stat": [0, 99], "passive_max": [0, 999],
	"equip_stat": [-99, 99],
	"equip_delta": [-3000, 3000],
	"bag": [1, 99],
	"battle_turn": [0, TURN_MAX], "battle_seq": [1, SEQ_MAX],
}
const MATERIAL_MAX := 9999
## 장비(07 §5.1·§5.2·§5.6): 대원마다 칸 넷(칸 0 은 무기만), 종류, 같은 종류 제한, 가방 한 장비 상한.
const EQUIP_SLOTS := 4
const WEAPON_KINDS := ["sword", "staff"]
const ARMOR_KINDS := ["shield", "body", "head", "hands", "feet", "accessory"]
const KIND_LIMIT := {"shield": 1, "body": 1, "head": 1, "hands": 1, "feet": 1, "accessory": 2}
const BAG_MAX := 99
## 패시브 bonus 키(07 §4.3).
const PASSIVE_KEYS := ["STR", "INT", "VIT", "WIS", "AGI", "LUC", "max_hp", "max_tp"]
const PARTY_SIZE := 5
const ROW_MAX := 3

## 규칙 상수 범위(06 §5.2). 정수 키는 [최소, 최대], 구간 키는 [lo 최소, lo 최대, hi 최소, hi 최대].
const RULE_INTS := {
	"defense_k": [50, 200],
	"hit_min": [0, 1000], "hit_max": [0, 1000],
	"crit_base": [0, 1000], "crit_luck": [0, 100], "crit_max": [0, 1000], "crit_mult": [1000, 3000],
	"row_melee_mult": [0, 1000], "guard_mult": [0, 1000], "bind_stat_mult": [0, 1000], "leg_evasion_mult": [0, 1000],
	"paralysis_fail": [0, 1000],
	"status_luck": [0, 100],
	"resist_gain": [0, 1000], "resist_max": [0, 999], "resist_decay": [0, 1000],
	"escape_base": [0, 1000], "escape_agi": [0, 100],
	"buff_slots": [1, 5], "debuff_slots": [1, 5],
}
const RULE_PAIRS := {
	"damage_roll": [500, 1000, 1000, 1500],
	"speed_roll": [500, 1000, 1000, 1500],
	"status_luck_clamp": [0, 1000, 1000, 3000],
	"escape_clamp": [0, 1000, 0, 1000],
}


## v 가 정수이고 이름 붙은 공통 범위 안인지.
static func in_range(name: String, v: Variant) -> bool:
	var r: Array = RANGES[name]
	return typeof(v) == TYPE_INT and v >= r[0] and v <= r[1]


static func range_text(name: String) -> String:
	var r: Array = RANGES[name]
	return "%d~%d" % [r[0], r[1]]


## 강화·약화 효과 값의 방향 범위(06 §5.6): 강화 *_atk 1001~3000·*_def 1~999, 약화는 반대.
static func effect_value_ok(debuff: bool, kind: String, value: Variant) -> bool:
	if not in_range("effect_value", value) or not EFFECT_KINDS.has(kind):
		return false
	var raises := kind.ends_with("_atk") != debuff  # 강화 atk·약화 def 는 1000 초과
	return value > 1000 if raises else value < 1000


static func effect_value_text(debuff: bool, kind: String) -> String:
	var raises := kind.ends_with("_atk") != debuff
	return "1001~3000" if raises else "1~999"


## 런타임·저장의 누적 내성 값(06 §5.6): 1~resist_max(0이면 키를 지운다).
static func resist_ok(v: Variant, resist_max: int) -> bool:
	return typeof(v) == TYPE_INT and v >= 1 and v <= resist_max


## 규칙 상수 사전 검사. 오류 문장 목록("키: 내용"). 모든 키 필수, 모르는 키 거부, 정수·범위·구간 lo ≤ hi.
## d 의 정수 값은 이미 to_int 로 바꾼 것이어야 한다(소수·불리언·문자열은 여기서 정수가 아니라 거부된다).
static func check_rules(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in d:
		if not RULE_INTS.has(k) and not RULE_PAIRS.has(k):
			out.append("%s: 모르는 키" % str(k))
	for k in RULE_INTS:
		var r: Array = RULE_INTS[k]
		if not d.has(k):
			out.append("%s: 필수 키가 없다" % k)
		elif typeof(d[k]) != TYPE_INT or d[k] < r[0] or d[k] > r[1]:
			out.append("%s: 정수 %d~%d 이어야 한다" % [k, r[0], r[1]])
	for k in RULE_PAIRS:
		var r: Array = RULE_PAIRS[k]
		if not d.has(k):
			out.append("%s: 필수 키가 없다" % k)
			continue
		var v: Variant = d[k]
		if typeof(v) != TYPE_ARRAY or v.size() != 2 or typeof(v[0]) != TYPE_INT or typeof(v[1]) != TYPE_INT:
			out.append("%s: 정수 두 개 [lo, hi] 이어야 한다" % k)
		elif v[0] < r[0] or v[0] > r[1] or v[1] < r[2] or v[1] > r[3]:
			out.append("%s: lo %d~%d, hi %d~%d 이어야 한다" % [k, r[0], r[1], r[2], r[3]])
		elif v[0] > v[1]:
			out.append("%s: lo ≤ hi 이어야 한다" % k)
	if typeof(d.get("hit_min")) == TYPE_INT and typeof(d.get("hit_max")) == TYPE_INT and d["hit_min"] > d["hit_max"]:
		out.append("hit_min: hit_min ≤ hit_max 이어야 한다")
	return out
