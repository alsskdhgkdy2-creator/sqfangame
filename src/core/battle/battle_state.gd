## 전투 중 상태(06 §8.1). ExplorationState.battle 에 있고 전투 규칙(BattleRules)만 바꾼다. 화면은 읽기만 한다.
## 저장되는 것: formation·turn·seq 와 유닛의 전투 상태(to_dict, 06 §8.4). 정의 값과 턴 한정 값은 저장하지 않는다.
class_name BattleState
extends RefCounted

var formation := ""
## 0부터. 턴 끝 처리 6단계에서 오른다(06 §3.15).
var turn := 0
## 다음 강화·약화 효과가 받을 번호(1부터, 06 §3.14).
var seq := 1
## 파티 칸 순서(1~5, M3 A7).
var party: Array[BattleUnit] = []
## 편성 칸 순서.
var enemies: Array[BattleUnit] = []
## 편성의 no_escape.
var no_escape := false
## 접촉으로 이 전투를 연 FOE 의 id(M3 A6, 지금 층). 인카운트 전투면 "". 저장은 있을 때만 "foe" 키로 쓴다.
var foe := ""
## 싸움 중에 합류한 FOE(M3 A6b, 설계 §3.2): {foe, row} 합류 차례. 하나마다 enemies 끝에 유닛이 하나 붙는다(편성 칸 뒤, 칸 번호 그대로).
## 저장은 비어 있지 않을 때만 "joined" 키로 쓴다.
var joined: Array[Dictionary] = []

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
	if f == null or members.is_empty() or members.size() > BattleLimits.PARTY_SIZE:
		return null
	var b := BattleState.new()
	b.formation = formation_id
	b.no_escape = f.no_escape
	for i in members.size():
		var u := BattleUnit.new()
		# 능력치·장비·배율·배운 액티브 스킬·일반 공격(무기 속성 사본)은 성장 묶음 한 곳에서(07 §6). 모두 새 사전·새 객체다.
		var p := GrowthRules.profile(defs, i, members[i])
		u.side = BattleUnit.PARTY
		u.slot = i
		u.member = members[i]
		u.def_id = members[i].id
		u.name_key = members[i].name_key
		u.name = members[i].name
		u.row = members[i].row
		u.stats = p["stats"]
		u.gear = p["gear"]
		u.resist = p["resist"]
		u.ailment_vuln = p["ailment_vuln"]
		u.bind_vuln = p["bind_vuln"]
		u.skills = p["skills"]
		u.attack = p["attack"]
		b.party.append(u)
	for j in f.enemies.size():
		b.enemies.append(_enemy_unit(defs.battle.enemies[f.enemies[j]["enemy"]], j, f.enemies[j]["row"]))
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		b.promoted[side] = b.front_empty(side)
	return b


## 적 유닛 하나(HP 가득). 편성 칸과 합류 칸이 같이 쓴다.
static func _enemy_unit(e: BattleDb.EnemyDef, slot: int, row: String) -> BattleUnit:
	var u := BattleUnit.new()
	u.side = BattleUnit.ENEMY
	u.slot = slot
	u.def_id = e.id
	u.name_key = e.name_key
	u.row = row
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
	return u


## FOE 무리(적이 하나인 편성, 설계 §2.2)의 그 적 {enemy, row}. 층 FOE·정의가 없으면 빈 사전.
static func foe_enemy(defs: GameDefs, floor_def: FloorModel, foe_id: String) -> Dictionary:
	var sp: FloorModel.FoeSpawn = floor_def.foes.get(foe_id) if floor_def != null else null
	var fd: BattleDb.FoeDef = defs.battle.foe(sp.foe) if sp != null else null
	var f: BattleDb.FormationDef = defs.battle.formations.get(fd.formation) if fd != null else null
	if f == null or f.enemies.size() != 1:
		return {}
	return f.enemies[0]


## 합류(M3 A6b, 설계 §4.6): FOE foe_id 의 적을 row 열의 다음 칸(enemies 끝)에 붙이고 joined 에 적는다. 붙인 유닛(못 붙이면 null).
func add_joiner(defs: GameDefs, floor_def: FloorModel, foe_id: String, row: String) -> BattleUnit:
	var fe := foe_enemy(defs, floor_def, foe_id)
	if fe.is_empty():
		return null
	var u := _enemy_unit(defs.battle.enemies[fe["enemy"]], enemies.size(), row)
	enemies.append(u)
	joined.append({"foe": foe_id, "row": row})
	return u


## 그 열의 유닛 수(쓰러진 유닛도 센다: 칸 자리는 그대로, 설계 §4.7).
func row_count(row: String) -> int:
	var n := 0
	for u in enemies:
		if u.row == row:
			n += 1
	return n


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
	var out := {"formation": formation, "turn": turn, "seq": seq, "party": p, "enemies": e}
	if not foe.is_empty():
		out["foe"] = foe  # M3 A6: 인카운트 전투의 객체는 9판과 같게 둔다(설계 §3.3)
	if not joined.is_empty():
		out["joined"] = joined.duplicate(true)  # M3 A6b: 합류가 없으면 키도 없다
	return out


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
## floor_def 는 합류 유닛(joined)의 적을 찾는 층(저장의 지금 층). joined 가 없으면 쓰지 않는다.
static func from_dict(d: Dictionary, defs: GameDefs, members: Array[PartyState.Member], floor_def: FloorModel = null) -> BattleState:
	var b := create(defs, members, str(d["formation"]))
	if b == null:
		return null
	b.turn = int(d["turn"])
	b.seq = int(d["seq"])
	b.foe = str(d.get("foe", ""))
	for jd in d.get("joined", []):
		if b.add_joiner(defs, floor_def, str(jd["foe"]), str(jd["row"])) == null:
			return null
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
## 10판(M3 A6)부터 더 받는 키: 접촉 전투의 FOE id(있을 때만).
## joined(M3 A6b): 싸움 중에 합류한 FOE [{foe, row}](비어 있지 않을 때만).
const SAVE_KEYS_OPTIONAL := ["foe", "joined"]
const JOINED_KEYS := ["foe", "row"]
const UNIT_KEYS := ["ailment", "binds", "buffs", "debuffs", "resist"]
const ENEMY_KEYS := ["ailment", "binds", "buffs", "debuffs", "resist", "hp", "charging", "kill"]
const EFFECT_KEYS := ["id", "kind", "value", "turns", "seq"]
const KILL_KEYS := ["turn", "element", "ailment", "binds", "by"]


## 저장된 battle 객체를 검사한다. 문제가 없으면 "", 있으면 "battle.<경로>: 내용". members 는 이미 읽은 대원(HP).
## floor_def 는 전투가 난 층(저장의 지금 층): 편성이 그 층 출현 표에 있어야 한다(M3 A1).
## 10판(M3 A6)은 접촉 전투의 foe(그 층 FOE id)를 더 받고, 그때 편성은 그 FOE 의 무리여야 한다. schema 가 9 이하면 9판 키만 받는다.
## 10판 joined(A6b, 설계 §3.3): 비어 있지 않은 [{foe, row}], FOE 는 이 층 FOE 이고 서로 다르며 접촉 FOE 가 아니다. enemies 는 편성 칸 + 합류 칸이고
## 열마다 3 이하(쓰러진 유닛도 센다), 편성 뒤 칸 j 는 그 합류 FOE 의 적 정의로 본다.
static func check_dict(v: Variant, defs: GameDefs, members: Array[PartyState.Member], floor_def: FloorModel, schema: int = 10) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "battle: 객체 또는 null 이어야 한다"
	var d: Dictionary = v
	var err := _exact(d, SAVE_KEYS, "battle", SAVE_KEYS_OPTIONAL if schema >= 10 else [])
	if not err.is_empty():
		return err
	var fid: Variant = d["formation"]
	if d.has("foe"):
		var sp: FloorModel.FoeSpawn = floor_def.foes.get(d["foe"]) if typeof(d["foe"]) == TYPE_STRING else null
		if sp == null:
			return "battle.foe: 이 층의 FOE 가 아니다"
		if typeof(fid) != TYPE_STRING or defs.battle.foe(sp.foe) == null or fid != defs.battle.foe(sp.foe).formation:
			return "battle.formation: 접촉한 FOE %s 의 무리가 아니다" % sp.id
	elif typeof(fid) != TYPE_STRING or not defs.battle.table_formations(floor_def.encounter_table).has(fid):
		return "battle.formation: 이 층 출현 표의 편성이 아니다"
	var f: BattleDb.FormationDef = defs.battle.formations[fid]
	# 칸마다 {enemy, row}: 편성 칸 뒤에 합류 칸.
	var slots: Array[Dictionary] = []
	slots.append_array(f.enemies)
	if d.has("joined"):
		var jv: Variant = d["joined"]
		if typeof(jv) != TYPE_ARRAY or jv.is_empty():
			return "battle.joined: 비어 있지 않은 배열이어야 한다(합류가 없으면 키가 없다)"
		var seen := {}
		for i in jv.size():
			var jp := "battle.joined[%d]" % i
			if typeof(jv[i]) != TYPE_DICTIONARY:
				return "%s: 객체여야 한다" % jp
			err = _exact(jv[i], JOINED_KEYS, jp)
			if not err.is_empty():
				return err
			var jf: Variant = jv[i]["foe"]
			var fe := foe_enemy(defs, floor_def, jf) if typeof(jf) == TYPE_STRING else {}
			if fe.is_empty():
				return "%s.foe: 이 층의 FOE 가 아니다" % jp
			if seen.has(jf):
				return "%s.foe: 합류 FOE %s 가 둘이다" % [jp, jf]
			if jf == d.get("foe"):
				return "%s.foe: 접촉한 FOE %s 는 합류하지 않는다" % [jp, jf]
			seen[jf] = true
			if typeof(jv[i]["row"]) != TYPE_STRING or not ["front", "back"].has(jv[i]["row"]):
				return "%s.row: front 또는 back 이어야 한다" % jp
			slots.append({"enemy": fe["enemy"], "row": jv[i]["row"]})
		var per_row := {"front": 0, "back": 0}
		for x in slots:
			per_row[x["row"]] += 1
		for r in ["front", "back"]:
			if per_row[r] > BattleLimits.ROW_MAX:
				return "battle.joined: %s 열이 %d 칸이다(열마다 %d 이하)" % [r, per_row[r], BattleLimits.ROW_MAX]
	var turn: Variant = SaveCodec.to_int(d["turn"])
	if not BattleLimits.in_range("battle_turn", turn):
		return "battle.turn: 정수 %s 이어야 한다" % BattleLimits.range_text("battle_turn")
	var seq: Variant = SaveCodec.to_int(d["seq"])
	if not BattleLimits.in_range("battle_seq", seq):
		return "battle.seq: 정수 %s 이어야 한다" % BattleLimits.range_text("battle_seq")
	if typeof(d["party"]) != TYPE_ARRAY or d["party"].size() != members.size():
		return "battle.party: 길이 %d 의 배열이어야 한다" % members.size()
	if typeof(d["enemies"]) != TYPE_ARRAY or d["enemies"].size() != slots.size():
		return "battle.enemies: 길이 %d 의 배열이어야 한다(편성의 적 수 + 합류 수)" % slots.size()
	for i in members.size():
		err = _check_unit(d["party"][i], "battle.party[%d]" % i, members[i].hp, null, defs, seq, turn)
		if not err.is_empty():
			return err
	var enemies_alive := false
	for j in slots.size():
		var e: BattleDb.EnemyDef = defs.battle.enemies[slots[j]["enemy"]]
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


static func _exact(d: Dictionary, keys: Array, path: String, optional: Array = []) -> String:
	for k in keys:
		if not d.has(k):
			return "%s.%s: 필수 필드가 없다" % [path, k]
	for k in d:
		if not keys.has(k) and not optional.has(k):
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
		return "%s.ailment: null 또는 상태 %d종이어야 한다" % [path, BattleLimits.AILMENTS.size()]
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
	# confused(M3 A7): 혼란한 적의 내장 공격이 쓰러뜨린 적. 혼란한 대원의 일반 공격은 attack 이다.
	if by != "attack" and by != "poison" and by != BattleDb.CONFUSED:
		var s: BattleDb.SkillDef = defs.battle.skill(by)
		if s == null or s.user != "party" or s.effect != "damage":
			return "%s.by: attack·poison·confused 또는 파티의 피해 스킬이어야 한다" % path
	return ""
