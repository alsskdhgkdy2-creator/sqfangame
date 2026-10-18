## 성장 규칙 함수(07 §3~§6): 대원 능력치 묶음, 경험치·레벨업, SP 배분, 장착, 임시 보급.
## 노드·시간·엔진에 기대지 않고 난수를 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(06 §3.2 방식).
## 거부하면 {"type": "rejected", "reason": …} 하나만 내고 상태를 바꾸지 않는다.
## 판정(배운 스킬·장비가 규칙을 지키는지)은 여기 한 곳에 있고 파티 정의 읽기(PartyData)·저장 검사(SaveCodec)도 이 함수를 부른다.
##
## 이벤트:
##   {"type": "exp", "member", "gained", "exp", "capped"}
##   {"type": "level_up", "member", "from", "to", "sp_gained", "max_hp", "max_tp", "hp_gain", "tp_gain", "stats"}
##   {"type": "skills_learned", "member", "changes": [{"skill", "from", "to"}](트리 순), "sp_left"}
##   {"type": "max_changed", "member", "max_hp", "max_tp", "hp_gain", "tp_gain"}
##   {"type": "equipped", "member", "slot", "item", "removed"}   item·removed 는 장비 ID, 없으면 ""
##   {"type": "supplied", "item", "amount", "capped"}
class_name GrowthRules
extends RefCounted

const EVENT_TYPES := ["rejected", "exp", "level_up", "skills_learned", "max_changed", "equipped", "supplied"]


# ---- 능력치 묶음 (07 §6) ----

## 대원 하나의 능력치 묶음(새 사전. 부를 때마다 새 사전·새 일반 공격 사본).
## {stats, max_hp, max_tp, gear, resist, ailment_vuln, bind_vuln, attack: SkillDef, skills: {액티브 스킬 → 레벨}(트리 순),
##  weapon: 무기 장비 ID 또는 "", breakdown: {STR…LUC·max_hp·max_tp → {base, passive, equip, total}}}
static func profile(defs: GameDefs, i: int, member: PartyState.Member) -> Dictionary:
	var db := defs.battle
	var c := defs.class_of(i)
	var row: Dictionary = c.levels[member.level]
	var passive := {}
	var skills := {}
	for sid in c.skills:
		var lv: int = member.skills.get(sid, 0)
		if lv <= 0:
			continue
		var s := db.skill(sid)
		if s.passive():
			var bonus: Dictionary = s.levels[lv - 1]["bonus"]
			for k in bonus:
				passive[k] = passive.get(k, 0) + bonus[k]
		else:
			skills[sid] = lv
	var eq_stats := {}
	var gear := {}
	for g in BattleLimits.GEAR:
		gear[g] = 0
	var deltas := {"resist": {}, "ailment_vuln": {}, "bind_vuln": {}}
	var weapon: BattleDb.EquipDef = null
	for id in member.equip:
		if id.is_empty():
			continue
		var e := db.equip(id)
		if e.weapon():
			weapon = e
		for g in BattleLimits.GEAR:
			gear[g] += e.gear[g]
		for k in e.stats:
			eq_stats[k] = eq_stats.get(k, 0) + e.stats[k]
		for table in deltas:
			var src: Dictionary = e.get(table)
			for k in src:
				deltas[table][k] = deltas[table].get(k, 0) + src[k]
	var out := {"stats": {}, "gear": {}, "resist": {}, "ailment_vuln": {}, "bind_vuln": {}, "skills": skills, "breakdown": {}}
	for k in BattleLimits.STATS:
		var total := _clamp("stat", row[k] + passive.get(k, 0) + eq_stats.get(k, 0))
		out["stats"][k] = total
		out["breakdown"][k] = {"base": row[k], "passive": passive.get(k, 0), "equip": eq_stats.get(k, 0), "total": total}
	for k in ["max_hp", "max_tp"]:
		var base: int = row["hp" if k == "max_hp" else "tp"]
		var total := _clamp(k, base + passive.get(k, 0))
		out[k] = total
		out["breakdown"][k] = {"base": base, "passive": passive.get(k, 0), "equip": 0, "total": total}
	for g in BattleLimits.GEAR:
		out["gear"][g] = _clamp("gear", gear[g])
	for k in c.resist:
		out["resist"][k] = _clamp("resist", c.resist[k] + deltas["resist"].get(k, 0))
	for k in c.ailment_vuln:
		out["ailment_vuln"][k] = _clamp("vuln", c.ailment_vuln[k] + deltas["ailment_vuln"].get(k, 0))
	for k in c.bind_vuln:
		out["bind_vuln"][k] = _clamp("vuln", c.bind_vuln[k] + deltas["bind_vuln"].get(k, 0))
	var attack := c.attack.copy()
	if weapon != null:
		attack.element = weapon.element
	out["attack"] = attack
	out["weapon"] = weapon.id if weapon != null else ""
	return out


static func _clamp(range_name: String, v: int) -> int:
	var r: Array = BattleLimits.RANGES[range_name]
	return clampi(v, r[0], r[1])


## 대원의 max_hp·max_tp 를 묶음 값으로 둔다(HP·TP 현재값은 건드리지 않는다).
static func refresh_max(defs: GameDefs, i: int, member: PartyState.Member) -> void:
	var p := profile(defs, i, member)
	member.max_hp = p["max_hp"]
	member.max_tp = p["max_tp"]


## 시작 파티 정의의 성장 값으로 만든 새 대원(07 §8.1): 레벨, exp = cum(레벨), 시작 배분, 시작 장비, 묶음의 최대 HP·TP, HP·TP 가득.
## 새 게임(GameDefs.members)과 저장 이전이 같은 시작 값을 쓴다. 부를 때마다 새 객체·새 사전·새 배열.
static func start_member(defs: GameDefs, i: int) -> PartyState.Member:
	var m := PartyState.Member.new(defs.party.ids[i])
	m.level = defs.party.levels[i]
	m.exp = defs.battle.growth.cum(m.level)
	m.skills = defs.party.skills[i].duplicate()
	m.equip = defs.party.equips[i].duplicate()
	refresh_max(defs, i, m)
	m.hp = m.max_hp
	m.tp = m.max_tp
	return m


# ---- SP (07 §4.1) ----

static func sp_total(defs: GameDefs, level: int) -> int:
	return defs.battle.growth.sp_total(level)


static func sp_used(skills: Dictionary) -> int:
	var n := 0
	for sid in skills:
		n += skills[sid]
	return n


static func sp_left(defs: GameDefs, member: PartyState.Member) -> int:
	return sp_total(defs, member.level) - sp_used(member.skills)


# ---- 경험치·레벨업 (07 §3) ----

## 한 사람 몫 = 총량 ÷ 살아 있는 인원(정수 버림). 살아 있는 인원이 0 이면 0(07 §3.1).
static func exp_share(total: int, alive: int) -> int:
	return total / alive if alive > 0 else 0


## 대원 i 에게 경험치 amount 를 더한다(07 §3.4). 전투 승리와 디버그 보급이 함께 쓴다. 살아 있는지는 보지 않는다.
## exp 이벤트 하나와, 레벨이 오르면 level_up 하나를 events 에 더한다. 돌려주는 사전:
## {gained, capped(= gained < amount), from, to, sp_gained, hp_gain, tp_gain}
static func gain_exp(state: ExplorationState, i: int, amount: int, events: Array[Dictionary]) -> Dictionary:
	var defs := state.defs
	var g := defs.battle.growth
	var m := state.party.members[i]
	var out := {"gained": 0, "capped": false, "from": m.level, "to": m.level, "sp_gained": 0, "hp_gain": 0, "tp_gain": 0}
	if m.level >= g.level_cap:
		out["capped"] = amount > 0
	else:
		var total := m.exp + amount
		var lv := m.level
		while lv < g.level_cap and total >= g.cum(lv + 1):
			lv += 1
		if lv >= g.level_cap:
			total = g.cum(g.level_cap)
		out["gained"] = total - m.exp
		out["capped"] = out["gained"] < amount
		m.exp = total
		if lv != m.level:
			var old_hp := m.max_hp
			var old_tp := m.max_tp
			m.level = lv
			var p := profile(defs, i, m)
			m.max_hp = p["max_hp"]
			m.max_tp = p["max_tp"]
			# 늘어난 만큼만 더한다(가득 채우지 않음). HP 0 대원은 HP 를 그대로 둔다(07 §3.4 4단계).
			var hp_gain := m.max_hp - old_hp if m.alive() else 0
			var tp_gain := m.max_tp - old_tp
			m.hp += hp_gain
			m.tp += tp_gain
			out["to"] = lv
			out["sp_gained"] = (lv - out["from"]) * g.sp_per_level
			out["hp_gain"] = hp_gain
			out["tp_gain"] = tp_gain
	events.append({"type": "exp", "member": i, "gained": out["gained"], "exp": m.exp, "capped": out["capped"]})
	if out["to"] != out["from"]:
		events.append({"type": "level_up", "member": i, "from": out["from"], "to": out["to"], "sp_gained": out["sp_gained"],
			"max_hp": m.max_hp, "max_tp": m.max_tp, "hp_gain": out["hp_gain"], "tp_gain": out["tp_gain"],
			"stats": profile(defs, i, m)["stats"]})
	return out


## 승리의 경험치 분배(07 §3.1·§3.4·§3.5). finish 의 승리 갈래가 드롭 다음에 부른다. 난수를 쓰지 않는다.
## 돌려주는 사전은 battle_end 에 더할 성장 필드 {exp_total, exp_alive, exp_share, members}.
static func victory_exp(state: ExplorationState, b: BattleState, events: Array[Dictionary]) -> Dictionary:
	var total := 0
	for u in b.enemies:
		if not u.kill.is_empty():
			total += state.defs.battle.enemies[u.def_id].exp
	var alive := 0
	for m in state.party.members:
		if m.alive():
			alive += 1
	var share := exp_share(total, alive)
	var cap := state.defs.battle.growth.level_cap
	var rows := []
	for i in state.party.members.size():
		var m := state.party.members[i]
		var r := {"member": i, "status": "received", "gained": 0, "capped": false, "from": m.level, "to": m.level, "sp_gained": 0, "hp_gain": 0, "tp_gain": 0}
		if not m.alive():
			r["status"] = "down"
		else:
			if m.level >= cap:
				r["status"] = "at_cap"
				r["capped"] = share > 0
			if total > 0:
				var got := gain_exp(state, i, share, events)
				for k in ["gained", "capped", "from", "to", "sp_gained", "hp_gain", "tp_gain"]:
					r[k] = got[k]
		rows.append(r)
	return {"exp_total": total, "exp_alive": alive, "exp_share": share, "members": rows}


## 디버그 경험치 보급(07 §5.7): gain_exp 를 그대로 부른다. n 은 1~999,999.
static func grant_exp(state: ExplorationState, i: int, n: Variant) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if _busy(state):
		return [_reject("not_now")]
	if i < 0 or i >= state.party.members.size():
		return [_reject("unknown_member")]
	var amount: Variant = SaveCodec.to_int(n) if typeof(n) != TYPE_BOOL else null
	if not BattleLimits.in_range("exp_grant", amount):
		return [_reject("bad_amount")]
	gain_exp(state, i, amount, events)
	return events


# ---- 스킬 배분 (07 §4.2·§4.6) ----

## 첫 레벨(0 → 1)을 배울 때의 조건(07 §4.2): 선행을 levels(스킬 → 레벨, 목표로 본 값)로, 관문을 대원 레벨로. "" | requires | min_level.
static func first_learn_block(c: BattleDb.ClassDef, member_level: int, levels: Dictionary, skill_id: String) -> String:
	var e := c.tree_entry(skill_id)
	for r in e["requires"]:
		if levels.get(r["skill"], 0) < r["level"]:
			return "requires"
	if member_level < e["min_level"]:
		return "min_level"
	return ""


## 배운 스킬 사전이 직업 트리·최대 레벨·선행·관문·SP 를 지키는지(07 §7.6 시작 배분, §8.3 저장 검사).
## 문제가 없으면 [], 있으면 [스킬 ID(전체에 대한 것이면 ""), 내용]. 레벨 값은 정수여야 한다(읽는 쪽이 바꾼다).
static func skills_problem(db: BattleDb, c: BattleDb.ClassDef, member_level: int, skills: Dictionary) -> Array:
	for sid in skills:
		if typeof(sid) != TYPE_STRING or not c.tree_index.has(sid):
			return [str(sid), "%s 트리에 없는 스킬이다" % c.id]
	for sid in c.skills:
		if not skills.has(sid):
			continue
		var lv: Variant = skills[sid]
		var top := db.skill(sid).max_level()
		if typeof(lv) != TYPE_INT or lv < 1 or lv > top:
			return [sid, "스킬 레벨 %s 이 1~최대 레벨 %d 이 아니다" % [str(lv), top]]
		match first_learn_block(c, member_level, skills, sid):
			"requires":
				var need := ", ".join(c.tree_entry(sid)["requires"].map(func(r: Dictionary) -> String: return "%s Lv%d" % [r["skill"], r["level"]]))
				return [sid, "선행(%s)을 채우지 않았다" % need]
			"min_level":
				return [sid, "대원 레벨 %d 이상이어야 배울 수 있다(지금 %d)" % [c.tree_entry(sid)["min_level"], member_level]]
	var used := sp_used(skills)
	var got := db.growth.sp_total(member_level)
	if used > got:
		return ["", "배운 스킬 레벨의 합 %d 이 얻은 SP %d 을 넘는다(레벨 %d)" % [used, got, member_level]]
	return []


## 배분 확정(07 §4.6). levels = {스킬 ID: 목표 레벨}. 한 번에 모두 바꾸거나 rejected 하나.
static func allocate(state: ExplorationState, i: int, levels: Dictionary) -> Array[Dictionary]:
	if _busy(state):
		return [_reject("not_now")]
	if i < 0 or i >= state.party.members.size():
		return [_reject("unknown_skill")]
	var defs := state.defs
	var c := defs.class_of(i)
	var m := state.party.members[i]
	var target := m.skills.duplicate()
	for sid in levels:
		if typeof(sid) != TYPE_STRING or not c.tree_index.has(sid):
			return [_reject("unknown_skill")]
	for sid in levels:
		var v: Variant = SaveCodec.to_int(levels[sid]) if typeof(levels[sid]) != TYPE_BOOL else null
		if v == null or v < m.skills.get(sid, 0):
			return [_reject("lower")]
		target[sid] = v
	for sid in levels:
		if target[sid] > defs.battle.skill(sid).max_level():
			return [_reject("max_level")]
	var added := 0
	for sid in levels:
		added += target[sid] - m.skills.get(sid, 0)
	if added == 0:
		return [_reject("unchanged")]
	for sid in c.skills:
		if levels.has(sid) and m.skills.get(sid, 0) == 0 and target[sid] > 0:
			var why := first_learn_block(c, m.level, target, sid)
			if not why.is_empty():
				return [_reject(why)]
	if added > sp_left(defs, m):
		return [_reject("no_sp")]
	var changes := []
	for sid in c.skills:
		if levels.has(sid) and target[sid] != m.skills.get(sid, 0):
			changes.append({"skill": sid, "from": m.skills.get(sid, 0), "to": target[sid]})
			m.skills[sid] = target[sid]
	var events: Array[Dictionary] = [{"type": "skills_learned", "member": i, "changes": changes, "sp_left": sp_left(defs, m)}]
	_refresh_with_gain(defs, i, m, events)
	return events


## 화면 「+」 판정(07 §4.6): 초안(draft = 스킬 → 초안으로 더한 레벨)에 그 스킬 1 레벨을 더할 수 있는지.
## "" | unknown_skill | max_level | requires | min_level | no_sp. 확정 때 allocate 가 다시 본다.
static func learn_block(defs: GameDefs, i: int, member: PartyState.Member, draft: Dictionary, skill: String) -> String:
	var c := defs.class_of(i)
	if not c.tree_index.has(skill):
		return "unknown_skill"
	var now: int = member.skills.get(skill, 0) + draft.get(skill, 0)
	if now + 1 > defs.battle.skill(skill).max_level():
		return "max_level"
	if now == 0:
		var why := first_learn_block(c, member.level, _with_draft(member, draft), skill)
		if not why.is_empty():
			return why
	if sp_used(draft) + 1 > sp_left(defs, member):
		return "no_sp"
	return ""


## 화면 「−」 판정(07 §4.6): 초안으로 올린 레벨만 내린다. 그 스킬을 선행으로 삼는 다른 초안 스킬이 첫 레벨을 초안으로 배우는 중이고
## 내린 뒤 선행이 깨지면 막는다. "" | no_draft | requires.
static func unlearn_block(defs: GameDefs, i: int, member: PartyState.Member, draft: Dictionary, skill: String) -> String:
	if draft.get(skill, 0) <= 0:
		return "no_draft"
	var c := defs.class_of(i)
	var less := draft.duplicate()
	less[skill] -= 1
	var levels := _with_draft(member, less)
	for sid in c.skills:
		if sid != skill and less.get(sid, 0) > 0 and member.skills.get(sid, 0) == 0:
			if first_learn_block(c, member.level, levels, sid) == "requires":
				return "requires"
	return ""


static func _with_draft(member: PartyState.Member, draft: Dictionary) -> Dictionary:
	var out := member.skills.duplicate()
	for sid in draft:
		out[sid] = out.get(sid, 0) + draft[sid]
	return out


## 최대 HP·TP 를 다시 계산하고, 바뀌었으면 늘어난 만큼 더한 뒤 max_changed 를 낸다(HP 0 대원은 HP 그대로, 07 §3.4 4단계).
static func _refresh_with_gain(defs: GameDefs, i: int, m: PartyState.Member, events: Array[Dictionary]) -> void:
	var old_hp := m.max_hp
	var old_tp := m.max_tp
	refresh_max(defs, i, m)
	if m.max_hp == old_hp and m.max_tp == old_tp:
		return
	var hp_gain := m.max_hp - old_hp if m.alive() else 0
	var tp_gain := m.max_tp - old_tp
	m.hp += hp_gain
	m.tp += tp_gain
	events.append({"type": "max_changed", "member": i, "max_hp": m.max_hp, "max_tp": m.max_tp, "hp_gain": hp_gain, "tp_gain": tp_gain})


# ---- 장비 (07 §5) ----

## 칸 slot 에 장비 item_id 를 둘 수 있는지(가방은 보지 않는다). equip 은 대원의 칸 넷(빈 칸 ""), 바꿀 칸의 지금 장비는 빼고 센다.
## "" | unknown_item | slot_kind | class | kind_limit
static func slot_block(db: BattleDb, c: BattleDb.ClassDef, equip: Array, slot: int, item_id: String) -> String:
	var e := db.equip(item_id)
	if e == null:
		return "unknown_item"
	if (slot == 0) != e.weapon():
		return "slot_kind"
	if not e.fits(c):
		return "class"
	if not e.weapon():
		var same := 0
		for j in equip.size():
			if j != slot and not str(equip[j]).is_empty():
				var o := db.equip(equip[j])
				if o != null and o.kind == e.kind:
					same += 1
		if same + 1 > BattleLimits.KIND_LIMIT[e.kind]:
			return "kind_limit"
	return ""


const SLOT_TEXT := {
	"unknown_item": "없는 장비다",
	"slot_kind": "칸 0 은 무기, 칸 1~3 은 무기가 아닌 장비만 둔다",
	"class": "이 직업은 낄 수 없다",
	"kind_limit": "같은 종류 제한(방패·몸·머리·손·발 하나, 장신구 둘)을 넘는다",
}


## 칸 넷 전체가 장착 규칙(칸 종류·직업·같은 종류 제한)을 지키는지(07 §7.6 시작 장비, §8.3 저장 검사).
## equip 은 길이 EQUIP_SLOTS 의 문자열 배열(빈 칸 ""). 문제가 없으면 [], 있으면 [칸, 내용].
static func equip_problem(db: BattleDb, c: BattleDb.ClassDef, equip: Array) -> Array:
	for slot in equip.size():
		var id: String = equip[slot]
		if id.is_empty():
			continue
		var why := slot_block(db, c, equip, slot, id)
		if not why.is_empty():
			return [slot, "%s: %s" % [id, SLOT_TEXT[why]]]
	return []


## 화면이 부르는 장착 판정(07 §5.7, 가방 포함). item_id "" 은 빼기.
## "" | bad_slot | unchanged | unknown_item | not_in_bag | slot_kind | class | kind_limit | bag_full
static func equip_block(defs: GameDefs, i: int, member: PartyState.Member, bag: Dictionary, slot: int, item_id: String) -> String:
	if slot < 0 or slot >= BattleLimits.EQUIP_SLOTS:
		return "bad_slot"
	var cur: String = member.equip[slot]
	if item_id.is_empty():
		if cur.is_empty():
			return "unchanged"
		return "bag_full" if bag.get(cur, 0) >= BattleLimits.BAG_MAX else ""
	if defs.battle.equip(item_id) == null:
		return "unknown_item"
	if item_id == cur:
		return "unchanged"
	if bag.get(item_id, 0) < 1:
		return "not_in_bag"
	var why := slot_block(defs.battle, defs.class_of(i), member.equip, slot, item_id)
	if not why.is_empty():
		return why
	if not cur.is_empty() and bag.get(cur, 0) >= BattleLimits.BAG_MAX:
		return "bag_full"
	return ""


## 장착·빼기(07 §5.7). item_id 가 "" 이면 빼기. 칸의 지금 장비는 가방 +1, 새 장비는 가방 −1(0 이면 키를 지움).
static func equip(state: ExplorationState, i: int, slot: int, item_id: String) -> Array[Dictionary]:
	if _busy(state):
		return [_reject("not_now")]
	if i < 0 or i >= state.party.members.size():
		return [_reject("unknown_member")]
	var m := state.party.members[i]
	var why := equip_block(state.defs, i, m, state.gear_bag, slot, item_id)
	if not why.is_empty():
		return [_reject(why)]
	var cur: String = m.equip[slot]
	if not cur.is_empty():
		state.gear_bag[cur] = state.gear_bag.get(cur, 0) + 1
	if not item_id.is_empty():
		state.gear_bag[item_id] -= 1
		if state.gear_bag[item_id] == 0:
			state.gear_bag.erase(item_id)
	m.equip[slot] = item_id
	var events: Array[Dictionary] = [{"type": "equipped", "member": i, "slot": slot, "item": item_id, "removed": cur}]
	# M2.5 장비에는 HP·TP 보정이 없어 최대값이 바뀌지 않는다(07 §5.3). 묶음 한 곳의 값을 그대로 담아 둔다.
	refresh_max(state.defs, i, m)
	return events


## 디버그 장비 보급(07 §5.7): 가방에 n(1~99)개 더하고 99 에서 멈춘다.
static func supply(state: ExplorationState, item_id: String, n: Variant) -> Array[Dictionary]:
	if _busy(state):
		return [_reject("not_now")]
	if state.defs.battle.equip(item_id) == null:
		return [_reject("unknown_item")]
	var amount: Variant = SaveCodec.to_int(n) if typeof(n) != TYPE_BOOL else null
	if not BattleLimits.in_range("bag", amount):
		return [_reject("bad_amount")]
	var have: int = state.gear_bag.get(item_id, 0)
	var now := mini(BattleLimits.BAG_MAX, have + amount)
	state.gear_bag[item_id] = now
	return [{"type": "supplied", "item": item_id, "amount": now - have, "capped": have + amount > BattleLimits.BAG_MAX}]


# ---- 공통 ----

## 성장 조작을 막는 때: 전투 중·전멸(07 §4.6·§5.7).
static func _busy(state: ExplorationState) -> bool:
	return state.battle != null or state.encounter.pending or state.wiped


static func _reject(reason: String) -> Dictionary:
	return {"type": "rejected", "reason": reason}
