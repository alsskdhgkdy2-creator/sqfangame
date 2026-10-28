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
	# 상점(08 §1·§2·§3). sold 는 누적 판 수와 한정 재고 pool 의 형식 범위(pool 은 관계 검사로 sold 까지).
	"price": [1, 999999], "sell": [1, 99999],
	"unlock": [1, 999],
	"money": [0, 9999999],
	"sold": [1, 9999999],
	"buy_qty": [1, 99], "sell_qty": [1, 9999],
	# 소모품(M3 A4): 한 종류 개수(저장 범위)·회복량.
	"consumable": [1, 99], "item_amount": [1, 999],
	# 채집(M3 A5): 지점의 하루 횟수, 표 한 줄의 무게·개수, 희귀 확률(천분율). 저장의 하루 쓴 횟수도 gather_uses 범위다.
	"gather_uses": [1, 9], "gather_weight": [1, 1000], "gather_count": [1, 5], "gather_permille": [1, 1000],
	# FOE(M3 A6): 위협 레벨, 추적의 시야·추적 거리, 합류 거리, 경로 칸 수, 되살아나는 날 수, 저장의 기절 걸음.
	"foe_level": [1, 99], "foe_sight": [1, 9], "foe_chase": [1, 20], "foe_join": [0, 9], "foe_path": [2, 32], "respawn_days": [1, 99],
	"foe_stun": [0, 2],
	"battle_turn": [0, TURN_MAX], "battle_seq": [1, SEQ_MAX],
}
const MATERIAL_MAX := 9999
## 장비(07 §5.1·§5.2·§5.6): 대원마다 칸 넷(칸 0 은 무기만), 종류, 같은 종류 제한, 가방 한 장비 상한.
const EQUIP_SLOTS := 4
const WEAPON_KINDS := ["sword", "staff"]
const ARMOR_KINDS := ["shield", "body", "head", "hands", "feet", "accessory"]
const KIND_LIMIT := {"shield": 1, "body": 1, "head": 1, "hands": 1, "feet": 1, "accessory": 2}
const BAG_MAX := 99
## 소모품(M3 A4, 01 §9): 한 종류 상한(저장 범위). 공용 가방 60칸(D31, BagRules) 안에서는 새로 얻어 닿지 않는다.
const CONSUMABLE_MAX := 99
## 소모품 효과 종류와 쓰는 곳(M3 A4).
const ITEM_EFFECTS := ["heal", "tp", "revive", "cure_ailment", "cure_bind", "return"]
const ITEM_WHERE := ["battle", "camp"]
## 채집(M3 A5, 01 §3.6·04 §2.2): 지점 종류(채취 take·절단 chop·추출 mine, 원작 Take·Chop·Mine), 하루 횟수 상한, 표 한 줄의 개수 상한, 표의 줄 수 상한.
const GATHER_KINDS := ["take", "chop", "mine"]
const GATHER_USES_MAX := 9
const GATHER_COUNT_MAX := 5
const GATHER_ITEMS_MAX := 8
## FOE(M3 A6, 01 §3.5): 종류(순회 patrol·추적 chase·문지기 guard)와 되살아남(Never·AfterDays(n)·OnFloorReload).
const FOE_KINDS := ["patrol", "chase", "guard"]
const FOE_RESPAWN := ["never", "after_days", "floor_reload"]
## 상점(08 §2): 소지금 상한, 누적 판 수(sold·pool) 상한.
const MONEY_MAX := 9999999
const SOLD_MAX := 9999999
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
			out.append("%s: lo <= hi 이어야 한다" % k)
	if typeof(d.get("hit_min")) == TYPE_INT and typeof(d.get("hit_max")) == TYPE_INT and d["hit_min"] > d["hit_max"]:
		out.append("hit_min: hit_min <= hit_max 이어야 한다")
	return out
