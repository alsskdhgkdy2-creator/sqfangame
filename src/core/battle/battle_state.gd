## 전투 중 상태(06 §8.1). ExplorationState.battle 에 있고 전투 규칙(BattleRules)만 바꾼다. 화면은 읽기만 한다.
## 저장되는 것: formation·turn·seq 와 유닛의 전투 상태(to_dict, 06 §8.4). 정의 값과 턴 한정 값은 저장하지 않는다.
class_name BattleState
extends RefCounted

var formation := ""
## 0부터. 턴 끝 처리 6단계에서 오른다(06 §3.15).
var turn := 0
## 다음 강화·약화 효과가 받을 번호(1부터, 06 §3.14).
var seq := 1
## 대원 순서(5).
var party: Array[BattleUnit] = []
## 편성 칸 순서.
var enemies: Array[BattleUnit] = []
## 편성의 no_escape.
var no_escape := false

# ---- 턴 한정 (저장하지 않음) ----
## 편 → 프론트 가드 값(그 턴 가장 센 값, 06 §6.2). 없으면 키 없음.
var front_guard := {}
## 커버: 보호받는 아군 칸 → 커버하는 아군 칸(06 §6.2).
var cover := {}
## 이번 턴 행동 큐(BattleRules 가 쓴다).
var queue: Array[Dictionary] = []
## 편 → 후열이 전열로 나와 있는지(row_shift 감지용, 매번 계산 가능한 값의 사본).
var promoted := {BattleUnit.PARTY: false, BattleUnit.ENEMY: false}


## 정의와 탐색 파티로 새 전투 상태를 만든다(적은 HP 가득). formation 이 없으면 null.
static func create(defs: GameDefs, members: Array[PartyState.Member], formation_id: String) -> BattleState:
	var f: BattleDb.FormationDef = defs.battle.formations.get(formation_id)
	if f == null or members.size() != defs.party.ids.size():
		return null
	var b := BattleState.new()
	b.formation = formation_id
	b.no_escape = f.no_escape
	for i in members.size():
		var u := BattleUnit.new()
		var c := defs.class_of(i)
		var st := defs.member_stats(i)
		u.side = BattleUnit.PARTY
		u.slot = i
		u.member = members[i]
		u.def_id = members[i].id
		u.name_key = defs.party.name_keys[i]
		u.row = defs.party.rows[i]
		for k in BattleLimits.STATS:
			u.stats[k] = st[k]
		u.gear = defs.party.gears[i].duplicate()
		u.resist = c.resist
		u.ailment_vuln = c.ailment_vuln
		u.bind_vuln = c.bind_vuln
		u.skills = defs.party.skills[i]
		u.attack = c.attack
		b.party.append(u)
	for j in f.enemies.size():
		var e: BattleDb.EnemyDef = defs.battle.enemies[f.enemies[j]["enemy"]]
		var u := BattleUnit.new()
		u.side = BattleUnit.ENEMY
		u.slot = j
		u.def_id = e.id
		u.name_key = e.name_key
		u.row = f.enemies[j]["row"]
		u.stats = e.stats.duplicate()
		u.max_hp = e.max_hp
		u.hp = e.max_hp
		u.resist = e.resist
		u.ailment_vuln = e.ailment_vuln
		u.bind_vuln = e.bind_vuln
		u.on_bound = e.on_bound
		for rule in e.ai:
			for c in rule["use"]:
				u.skills[c["skill"]] = 1
		b.enemies.append(u)
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		b.promoted[side] = b.front_empty(side)
	return b


# ---- 읽기 ----

func units_of(side: String) -> Array[BattleUnit]:
	return party if side == BattleUnit.PARTY else enemies


func allies_of(u: BattleUnit) -> Array[BattleUnit]:
	return units_of(u.side)


func opponents_of(u: BattleUnit) -> Array[BattleUnit]:
	return enemies if u.side == BattleUnit.PARTY else party


func unit(side: String, slot: int) -> BattleUnit:
	var list := units_of(side)
	return list[slot] if slot >= 0 and slot < list.size() else null


## 그 편의 정의된 전열에 살아 있는 유닛이 하나도 없는지(그러면 후열이 실효 전열, 06 §3.5).
func front_empty(side: String) -> bool:
	for u in units_of(side):
		if u.row == "front" and u.alive():
			return false
	return true


## 실효 열 "front" / "back". 저장하지 않고 매번 계산한다.
func effective_row(u: BattleUnit) -> String:
	if u.row == "back" and front_empty(u.side):
		return "front"
	return u.row


func all_down(side: String) -> bool:
	for u in units_of(side):
		if u.alive():
			return false
	return true


# ---- 저장 형식 (06 §8.4 의 battle 객체) ----

## 저장용 사전. 효과 목록은 seq 순, 처치 기록의 binds 는 head·arm·leg 순. 사전 키 정렬은 직렬화(SaveCodec)가 한다.
func to_dict() -> Dictionary:
	var p := []
	for u in party:
		p.append(_unit_dict(u))
	var e := []
	for u in enemies:
		var d := _unit_dict(u)
		d["hp"] = u.hp
		d["charging"] = u.charging if not u.charging.is_empty() else null
		d["kill"] = u.kill.duplicate(true) if not u.kill.is_empty() else null
		e.append(d)
	return {"formation": formation, "turn": turn, "seq": seq, "party": p, "enemies": e}


static func _unit_dict(u: BattleUnit) -> Dictionary:
	var ail: Variant = null
	if not u.ailment.is_empty():
		ail = {"id": u.ailment, "turns": u.ailment_turns}
		if u.ailment == "poison":
			ail["damage"] = u.ailment_damage
	var binds := {}
	for part in BattleLimits.PARTS:
		if u.binds.has(part):
			binds[part] = u.binds[part]
	var resist := {}
	for k in BattleLimits.AILMENTS + BattleLimits.PARTS:
		if u.resist_acc.has(k):
			resist[k] = u.resist_acc[k]
	return {"ailment": ail, "binds": binds, "buffs": u.buffs.duplicate(true), "debuffs": u.debuffs.duplicate(true), "resist": resist}


## to_dict 의 역. 값 검사는 하지 않는다(저장 검사 SaveCodec 이 먼저 한다). JSON 의 실수도 정수로 받는다.
static func from_dict(d: Dictionary, defs: GameDefs, members: Array[PartyState.Member]) -> BattleState:
	var b := create(defs, members, str(d["formation"]))
	if b == null:
		return null
	b.turn = int(d["turn"])
	b.seq = int(d["seq"])
	for i in b.party.size():
		_read_unit(b.party[i], d["party"][i])
	for j in b.enemies.size():
		var ed: Dictionary = d["enemies"][j]
		_read_unit(b.enemies[j], ed)
		b.enemies[j].hp = int(ed["hp"])
		b.enemies[j].charging = str(ed["charging"]) if ed["charging"] != null else ""
		if ed["kill"] != null:
			var k: Dictionary = ed["kill"]
			var kb: Array[String] = []
			for part in k["binds"]:
				kb.append(str(part))
			b.enemies[j].kill = {"turn": int(k["turn"]), "element": k["element"], "ailment": k["ailment"], "binds": kb, "by": str(k["by"])}
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		b.promoted[side] = b.front_empty(side)
	return b


static func _read_unit(u: BattleUnit, d: Dictionary) -> void:
	if d["ailment"] != null:
		u.ailment = str(d["ailment"]["id"])
		u.ailment_turns = int(d["ailment"]["turns"])
		u.ailment_damage = int(d["ailment"].get("damage", 0))
	for part in BattleLimits.PARTS:
		if d["binds"].has(part):
			u.binds[part] = int(d["binds"][part])
	for e in d["buffs"]:
		u.buffs.append(_effect(e))
	for e in d["debuffs"]:
		u.debuffs.append(_effect(e))
	for k in BattleLimits.AILMENTS + BattleLimits.PARTS:
		if d["resist"].has(k):
			u.resist_acc[k] = int(d["resist"][k])


static func _effect(e: Dictionary) -> Dictionary:
	return {"id": str(e["id"]), "kind": str(e["kind"]), "value": int(e["value"]), "turns": int(e["turns"]), "seq": int(e["seq"])}


# ---- 저장 검사 (06 §8.5) ----
# 범위는 BattleLimits 에서 온다. 정수는 SaveCodec.to_int 로 읽는다(소수·불리언·문자열 거부).
# 통과한 사전만 from_dict 에 넘긴다.

const SAVE_KEYS := ["formation", "turn", "seq", "party", "enemies"]
const UNIT_KEYS := ["ailment", "binds", "buffs", "debuffs", "resist"]
const ENEMY_KEYS := ["ailment", "binds", "buffs", "debuffs", "resist", "hp", "charging", "kill"]
const EFFECT_KEYS := ["id", "kind", "value", "turns", "seq"]
const KILL_KEYS := ["turn", "element", "ailment", "binds", "by"]


## 저장된 battle 객체를 검사한다. 문제가 없으면 "", 있으면 "battle.<경로>: 내용". members 는 이미 읽은 대원(HP).
static func check_dict(v: Variant, defs: GameDefs, members: Array[PartyState.Member]) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "battle: 객체 또는 null 이어야 한다"
	var d: Dictionary = v
	var err := _exact(d, SAVE_KEYS, "battle")
	if not err.is_empty():
		return err
	var fid: Variant = d["formation"]
	if typeof(fid) != TYPE_STRING or not defs.battle.table_formations(defs.floor_def.encounter_table).has(fid):
		return "battle.formation: 이 층 출현 표의 편성이 아니다"
	var f: BattleDb.FormationDef = defs.battle.formations[fid]
	var turn: Variant = SaveCodec.to_int(d["turn"])
	if not BattleLimits.in_range("battle_turn", turn):
		return "battle.turn: 정수 %s 이어야 한다" % BattleLimits.range_text("battle_turn")
	var seq: Variant = SaveCodec.to_int(d["seq"])
	if not BattleLimits.in_range("battle_seq", seq):
		return "battle.seq: 정수 %s 이어야 한다" % BattleLimits.range_text("battle_seq")
	if typeof(d["party"]) != TYPE_ARRAY or d["party"].size() != members.size():
		return "battle.party: 길이 %d 의 배열이어야 한다" % members.size()
	if typeof(d["enemies"]) != TYPE_ARRAY or d["enemies"].size() != f.enemies.size():
		return "battle.enemies: 길이 %d 의 배열이어야 한다(편성의 적 수)" % f.enemies.size()
	for i in members.size():
		err = _check_unit(d["party"][i], "battle.party[%d]" % i, members[i].hp, null, defs, seq, turn)
		if not err.is_empty():
			return err
	var enemies_alive := false
	for j in f.enemies.size():
		var e: BattleDb.EnemyDef = defs.battle.enemies[f.enemies[j]["enemy"]]
		var ed: Variant = d["enemies"][j]
		var path := "battle.enemies[%d]" % j
		if typeof(ed) != TYPE_DICTIONARY:
			return "%s: 객체여야 한다" % path
		var hp: Variant = SaveCodec.to_int(ed.get("hp"))
		if hp == null or hp < 0 or hp > e.max_hp:
			return "%s.hp: 정수 0~%d 이어야 한다" % [path, e.max_hp]
		enemies_alive = enemies_alive or hp > 0
		err = _check_unit(ed, path, hp, e, defs, seq, turn)
		if not err.is_empty():
			return err
	if not enemies_alive:
		return "battle.enemies: 적이 모두 HP 0 이면 전투가 끝났어야 한다"
	var party_alive := false
	for m in members:
		party_alive = party_alive or m.hp > 0
	if not party_alive:
		return "battle.party: 대원이 모두 HP 0 이면 전멸이어야 한다"
	return ""


static func _exact(d: Dictionary, keys: Array, path: String) -> String:
	for k in keys:
		if not d.has(k):
			return "%s.%s: 필수 필드가 없다" % [path, k]
	for k in d:
		if not keys.has(k):
			return "%s.%s: 모르는 필드" % [path, str(k)]
	return ""


## 유닛 하나. e 가 있으면 적(그 정의), 없으면 아군. hp 는 이미 읽은 값.
static func _check_unit(v: Variant, path: String, hp: int, e: BattleDb.EnemyDef, defs: GameDefs, battle_seq: int, battle_turn: int) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "%s: 객체여야 한다" % path
	var d: Dictionary = v
	var err := _exact(d, ENEMY_KEYS if e != null else UNIT_KEYS, path)
	if not err.is_empty():
		return err
	var rules := defs.battle.rules
	# 상태이상
	var ail: Variant = d["ailment"]
	var ail_id := ""
	if ail != null:
		if typeof(ail) != TYPE_DICTIONARY or typeof(ail.get("id")) != TYPE_STRING or not BattleLimits.AILMENTS.has(ail["id"]):
			return "%s.ailment: null 또는 {id, turns} 이고 id 는 %s 이어야 한다" % [path, ", ".join(BattleLimits.AILMENTS)]
		ail_id = ail["id"]
		err = _exact(ail, ["id", "turns", "damage"] if ail_id == "poison" else ["id", "turns"], path + ".ailment")
		if not err.is_empty():
			return err
		if not BattleLimits.in_range("turns", SaveCodec.to_int(ail["turns"])):
			return "%s.ailment.turns: 정수 %s 이어야 한다" % [path, BattleLimits.range_text("turns")]
		if ail_id == "poison" and not BattleLimits.in_range("poison_damage", SaveCodec.to_int(ail["damage"])):
			return "%s.ailment.damage: 정수 %s 이어야 한다" % [path, BattleLimits.range_text("poison_damage")]
	# 봉인
	if typeof(d["binds"]) != TYPE_DICTIONARY:
		return "%s.binds: 객체여야 한다" % path
	for k in d["binds"]:
		if not BattleLimits.PARTS.has(k) or not BattleLimits.in_range("turns", SaveCodec.to_int(d["binds"][k])):
			return "%s.binds.%s: 키는 head·arm·leg, 값은 정수 %s 이어야 한다" % [path, str(k), BattleLimits.range_text("turns")]
	# 강화·약화
	var seqs := {}
	for list in ["buffs", "debuffs"]:
		err = _check_effects(d[list], "%s.%s" % [path, list], list == "debuffs", defs, battle_seq, seqs)
		if not err.is_empty():
			return err
	# 누적 내성
	if typeof(d["resist"]) != TYPE_DICTIONARY:
		return "%s.resist: 객체여야 한다" % path
	for k in d["resist"]:
		if not (BattleLimits.AILMENTS + BattleLimits.PARTS).has(k) or not BattleLimits.resist_ok(SaveCodec.to_int(d["resist"][k]), rules.resist_max):
			return "%s.resist.%s: 키는 상태 3종·부위 3개, 값은 정수 1~%d 이어야 한다" % [path, str(k), rules.resist_max]
	var charging: Variant = null
	if e != null:
		charging = d["charging"]
		if charging != null:
			var allowed := []
			for rule in e.ai:
				for c in rule["use"]:
					var s: BattleDb.SkillDef = defs.battle.skill(c["skill"])
					if s.effect == "charge":
						allowed.append(s.charges)
			if typeof(charging) != TYPE_STRING or not allowed.has(charging):
				return "%s.charging: null 또는 이 적의 준비 스킬이 가리키는 강공격이어야 한다" % path
		err = _check_kill(d["kill"], path + ".kill", defs, battle_turn)
		if not err.is_empty():
			return err
		if hp > 0 and d["kill"] != null:
			return "%s.kill: HP 가 1 이상인 적은 null 이어야 한다" % path
		if hp == 0 and d["kill"] == null:
			return "%s.kill: HP 0 인 적은 처치 기록이 있어야 한다" % path
		if ail_id == "sleep" and charging != null:
			return "%s.charging: 수면 중인 적은 준비가 없어야 한다" % path
	if hp == 0 and (ail != null or not d["binds"].is_empty() or not d["buffs"].is_empty() or not d["debuffs"].is_empty() or charging != null):
		return "%s: HP 0 유닛은 상태이상·봉인·강화·약화·준비가 없어야 한다" % path
	return ""


static func _check_effects(v: Variant, path: String, debuff: bool, defs: GameDefs, battle_seq: int, seqs: Dictionary) -> String:
	var slots := defs.battle.rules.debuff_slots if debuff else defs.battle.rules.buff_slots
	if typeof(v) != TYPE_ARRAY or v.size() > slots:
		return "%s: 길이 0~%d 의 배열이어야 한다" % [path, slots]
	var ids := {}
	var last := 0
	for i in v.size():
		var p := "%s[%d]" % [path, i]
		if typeof(v[i]) != TYPE_DICTIONARY:
			return "%s: 객체여야 한다" % p
		var x: Dictionary = v[i]
		var err := _exact(x, EFFECT_KEYS, p)
		if not err.is_empty():
			return err
		var s: BattleDb.SkillDef = defs.battle.skill(x["id"]) if typeof(x["id"]) == TYPE_STRING else null
		if s == null or s.effect != ("debuff" if debuff else "buff"):
			return "%s.id: effect 가 %s 인 스킬이어야 한다" % [p, "debuff" if debuff else "buff"]
		if ids.has(x["id"]):
			return "%s.id: 같은 목록에 같은 효과가 둘이다" % p
		ids[x["id"]] = true
		var kinds := s.levels.map(func(row): return row["kind"])
		if typeof(x["kind"]) != TYPE_STRING or not kinds.has(x["kind"]):
			return "%s.kind: 그 스킬의 kind 여야 한다" % p
		if not BattleLimits.effect_value_ok(debuff, x["kind"], SaveCodec.to_int(x["value"])):
			return "%s.value: 정수 %s 이어야 한다" % [p, BattleLimits.effect_value_text(debuff, x["kind"])]
		if not BattleLimits.in_range("turns", SaveCodec.to_int(x["turns"])):
			return "%s.turns: 정수 %s 이어야 한다" % [p, BattleLimits.range_text("turns")]
		var sq: Variant = SaveCodec.to_int(x["seq"])
		if sq == null or sq < 1 or sq >= battle_seq:
			return "%s.seq: 정수 1 이상 battle.seq 미만이어야 한다" % p
		if sq <= last:
			return "%s.seq: seq 오름차순이어야 한다" % p
		if seqs.has(sq):
			return "%s.seq: 한 유닛의 강화·약화에서 seq 가 중복이다" % p
		seqs[sq] = true
		last = sq
	return ""


static func _check_kill(v: Variant, path: String, defs: GameDefs, battle_turn: int) -> String:
	if v == null:
		return ""
	if typeof(v) != TYPE_DICTIONARY:
		return "%s: null 또는 객체여야 한다" % path
	var k: Dictionary = v
	var err := _exact(k, KILL_KEYS, path)
	if not err.is_empty():
		return err
	var t: Variant = SaveCodec.to_int(k["turn"])
	if t == null or t < 0 or t > battle_turn:
		return "%s.turn: 정수 0~battle.turn 이어야 한다" % path
	if k["element"] != null and (typeof(k["element"]) != TYPE_STRING or not BattleLimits.ELEMENTS.has(k["element"])):
		return "%s.element: null 또는 속성 6종이어야 한다" % path
	if k["ailment"] != null and (typeof(k["ailment"]) != TYPE_STRING or not BattleLimits.AILMENTS.has(k["ailment"])):
		return "%s.ailment: null 또는 상태 3종이어야 한다" % path
	if typeof(k["binds"]) != TYPE_ARRAY:
		return "%s.binds: 배열이어야 한다" % path
	var at := -1
	for part in k["binds"]:
		var idx := BattleLimits.PARTS.find(part) if typeof(part) == TYPE_STRING else -1
		if idx <= at:
			return "%s.binds: 중복 없는 head·arm·leg 순 부위 배열이어야 한다" % path
		at = idx
	var by: Variant = k["by"]
	if typeof(by) != TYPE_STRING:
		return "%s.by: 문자열이어야 한다" % path
	if by != "attack" and by != "poison":
		var s: BattleDb.SkillDef = defs.battle.skill(by)
		if s == null or s.user != "party" or s.effect != "damage":
			return "%s.by: attack·poison 또는 파티의 피해 스킬이어야 한다" % path
	return ""
