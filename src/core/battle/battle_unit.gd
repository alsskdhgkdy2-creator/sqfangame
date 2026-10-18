## 전투 유닛 하나(아군 또는 적). 화면은 읽기만 한다(06 §8.1).
## 아군의 HP·TP는 탐색 파티 상태(PartyState.Member)에 있고 이 객체는 그것을 가리킨다.
## 정의에서 오는 값(능력치·장비·배율·스킬)은 전투를 열거나 저장을 읽을 때 정의로 다시 채운다(저장하지 않는다).
class_name BattleUnit
extends RefCounted

const PARTY := "party"
const ENEMY := "enemy"

## "party" / "enemy"
var side := PARTY
## 그 편 안의 칸 번호(아군 = 대원 순서, 적 = 편성 순서).
var slot := 0
## 대원 ID 또는 적 ID(enemy.…).
var def_id := ""
var name_key := ""
## 정의된 열 "front" / "back". 실효 열은 BattleState.effective_row.
var row := "front"

# ---- 정의에서 (저장하지 않음) ----
## STR·INT·VIT·WIS·AGI·LUC
var stats := {}
## atk·matk·def·mdef (적은 모두 0)
var gear := {"atk": 0, "matk": 0, "def": 0, "mdef": 0}
## 속성 → 받는 피해 배율(‰)
var resist := {}
var ailment_vuln := {}
var bind_vuln := {}
## 아는 스킬 ID → 스킬 레벨(아군: 배운 액티브 스킬, 성장 묶음 07 §4.7. 적: AI 후보 스킬 모두 1)
var skills := {}
## 아군 일반 공격(직업 정의의 대원별 사본, 속성은 무기 것, 07 §5.3). 적은 null.
var attack: BattleDb.SkillDef
## 적만: on_bound "switch"/"fail"
var on_bound := "fail"
## 아군만: 탐색 상태의 대원. HP·TP는 여기에 있다.
var member: PartyState.Member
var _hp := 0
var _max_hp := 1

# ---- 전투 상태 (저장한다, 06 §8.4) ----
## 일반 상태이상 "" / poison / paralysis / sleep
var ailment := ""
var ailment_turns := 0
## 독의 턴당 피해(독일 때만 1 이상)
var ailment_damage := 0
## 부위 → 남은 턴(키 ⊆ head·arm·leg)
var binds := {}
## 강화·약화 칸: [{id, kind, value, turns, seq}] 늘 seq 오름차순
var buffs: Array[Dictionary] = []
var debuffs: Array[Dictionary] = []
## 누적 내성: 상태·부위 → 1~resist_max(0이면 키 없음)
var resist_acc := {}
## 적만: 준비 중인 강공격 스킬 ID("" 이면 없음)
var charging := ""
## 적만: 처치 기록 {turn, element, ailment, binds, by}. 비어 있으면 없음.
var kill := {}

# ---- 턴 한정 (저장하지 않음, 턴 끝에 지움) ----
var guarding := false


var hp: int:
	get:
		return member.hp if member != null else _hp
	set(v):
		if member != null:
			member.hp = v
		else:
			_hp = v

var max_hp: int:
	get:
		return member.max_hp if member != null else _max_hp
	set(v):
		_max_hp = v

var tp: int:
	get:
		return member.tp if member != null else 0
	set(v):
		if member != null:
			member.tp = v

var max_tp: int:
	get:
		return member.max_tp if member != null else 0


func is_party() -> bool:
	return side == PARTY


func alive() -> bool:
	return hp > 0


func asleep() -> bool:
	return ailment == "sleep"


func bound(part: String) -> bool:
	return binds.has(part)


## 스킬이 쓰는 부위 가운데 봉인된 첫 부위(head·arm·leg 순). 없으면 "".
func bound_part_of(s: BattleDb.SkillDef) -> String:
	for part in BattleLimits.PARTS:
		if s.parts.has(part) and binds.has(part):
			return part
	return ""


## 처치 기록·화면용: 걸린 봉인 부위 배열(head·arm·leg 순).
func bind_list() -> Array[String]:
	var out: Array[String] = []
	for part in BattleLimits.PARTS:
		if binds.has(part):
			out.append(part)
	return out


## 공격 능력치(봉인 반영): STR 은 팔 봉인, INT 는 머리 봉인이면 bind_stat_mult.
func attack_stat(stat: String, rules: BattleDb.Rules) -> int:
	var v: int = stats[stat]
	if (stat == "STR" and binds.has("arm")) or (stat == "INT" and binds.has("head")):
		v = BattleCalc.mul(v, rules.bind_stat_mult)
	return v


## 회피용 AGI(다리 봉인이면 leg_evasion_mult, 1 이상).
func evasion_agi(rules: BattleDb.Rules) -> int:
	var v: int = stats["AGI"]
	if binds.has("leg"):
		v = BattleCalc.mul(v, rules.leg_evasion_mult)
	return maxi(1, v)


## 그 kind 의 강화·약화 효과 전부(곱 순서는 BattleCalc.effect_order).
func effects_of(kind: String) -> Array:
	var out := []
	for e in buffs:
		if e["kind"] == kind:
			out.append(e)
	for e in debuffs:
		if e["kind"] == kind:
			out.append(e)
	return out


## 전투 불능이 될 때: 상태이상·봉인·강화·약화·준비를 지운다(누적 내성은 남는다).
func clear_on_down() -> void:
	ailment = ""
	ailment_turns = 0
	ailment_damage = 0
	binds.clear()
	buffs.clear()
	debuffs.clear()
	charging = ""


## 이벤트에 넣는 유닛 표시.
func ref() -> Dictionary:
	return {"side": side, "slot": slot}
