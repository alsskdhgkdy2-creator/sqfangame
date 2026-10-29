## 의뢰 규칙(M3 A8 설계 §4): 받기·포기·보고, 진행 세기(observe), 읽을 때 정하는 상태(잠김·받을 수 있음·목표 달성·식는 중).
## 노드·시간·엔진에 기대지 않고 난수를 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(GuildRules 와 같은 방식).
## 거부하면 {"type": "rejected", "reason": …} 하나만 내고 상태를 바꾸지 않는다. 받아들이면 부른 화면이 자동 저장한다(한 번).
##
## 이벤트:
##   {"type": "quest_accepted", "quest", "giver"}
##   {"type": "quest_abandoned", "quest"}
##   exp…·level_up…(GrowthRules.gain_exp) 다음 {"type": "quest_reported", "quest", "giver", "delivered": {item, count} | null, "money",
##     "items": [{item, count}], "flags": [플래그], "members": [{member, status: received·down·at_cap, gained, from, to}]}
##   {"type": "quest_progress", "quest", "progress", "target"}   observe: 센 목표가 올랐지만 아직 모자람
##   {"type": "quest_done", "quest"}                              observe: 목표를 이룸(deliver 는 이 묶음에 얻은 물건으로 넘었을 때)
## 거부 이유: wiped · in_battle · not_town · unknown_quest · wrong_giver · already · locked · cooling · not_accepted · no_abandon · not_done ·
##   bag_full · money_full
class_name QuestRules
extends RefCounted

const EVENT_TYPES := ["rejected", "quest_accepted", "quest_abandoned", "quest_reported", "quest_progress", "quest_done", "exp", "level_up"]
## 읽을 때 정하는 표시 상태(설계 §4.1).
const LOCKED := "locked"
const AVAILABLE := "available"
const COOLING := "cooling"
const ACCEPTED := "accepted"
const DONE := "done"
const FINISHED := "finished"


# ---- 읽기 ----

## 발급 조건이 모두 맞는지(설계 §4.2, 모두 맞아야 한다. 빈 목록은 늘 참).
static func conditions_met(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	for c in q.unlock:
		match c["kind"]:
			"reported":
				if s.quests.reports_of(c["quest"]) < 1:
					return false
			"visited":
				if not s.floor_states.has(c["floor"]):
					return false
			"day":
				if s.day < c["min"]:
					return false
			"level":
				if party_best_level(s) < c["min"]:
					return false
	return true


## 파티 대원 가운데 가장 높은 레벨(숙박비와 같은 대원들, 길드에만 있는 대원은 세지 않는다).
static func party_best_level(s: ExplorationState) -> int:
	var top := 1
	for m in s.party.members:
		top = maxi(top, m.level)
	return top


## 반복 의뢰가 다시 열리는 날(보고한 날 + days). 반복하지 않거나 보고한 적이 없으면 0.
static func opens_on(s: ExplorationState, q: QuestDb.QuestDef) -> int:
	var e := s.quests.entry(q.id)
	if e == null or e.reports < 1 or not q.repeats():
		return 0
	return e.day + q.repeat_days


## 표시 상태: locked·available·accepted·done(목표 달성)·cooling(반복 대기)·finished(반복하지 않는 보고 완료).
static func status_of(s: ExplorationState, q: QuestDb.QuestDef) -> String:
	var e := s.quests.entry(q.id)
	if e == null:
		return AVAILABLE if conditions_met(s, q) else LOCKED
	if e.status == QuestState.ACCEPTED:
		return DONE if is_done(s, q) else ACCEPTED
	if not q.repeats():
		return FINISHED
	return AVAILABLE if s.day >= opens_on(s, q) else COOLING


## 지금 받을 수 있는지.
static func available(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	return status_of(s, q) == AVAILABLE


## 한 번도 받지 않은 받을 수 있는 의뢰(목록의 NEW).
static func is_new(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	return s.quests.entry(q.id) == null and conditions_met(s, q)


## 가방에 든 item 수(소모품·끼지 않은 장비·소재. 낀 장비·귀중품은 세지 않는다).
static func owned(s: ExplorationState, item: String) -> int:
	var d: Variant = BagRules.store(s, item)
	return int(d.get(item, 0)) if d != null else 0


## 진행 값(목록·상세의 n/N): 센 목표는 기록의 progress, deliver 는 가진 수(목표 수에서 멈춤).
static func progress_of(s: ExplorationState, q: QuestDb.QuestDef) -> int:
	if q.kind == "deliver":
		return mini(owned(s, q.target), q.count)
	var e := s.quests.entry(q.id)
	return e.progress if e != null and e.status == QuestState.ACCEPTED else 0


## 받은 의뢰의 목표를 이뤘는지: 센 목표는 progress ≥ 목표(오르기만 한다), deliver 는 지금 가진 수(팔면 다시 모자랄 수 있다).
static func is_done(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	if not s.quests.is_accepted(q.id):
		return false
	if q.kind == "deliver":
		return owned(s, q.target) >= q.count
	return s.quests.entry(q.id).progress >= q.count


## 이 시설의 의뢰 ID(자료 차례).
static func ids_of(s: ExplorationState, giver: String) -> Array[String]:
	var out: Array[String] = []
	for id in s.defs.quests.order:
		if s.defs.quests.quests[id].giver == giver:
			out.append(id)
	return out


# ---- 받기·포기·보고 ----

## 의뢰를 받는다(마을, 그 의뢰를 내는 시설에서). 기록 {accepted, progress 0, reports·day 그대로}.
static func accept(s: ExplorationState, id: String, giver: String) -> Array[Dictionary]:
	var q := _def(s, id)
	var why := _common_block(s, q, giver)
	if why.is_empty():
		match status_of(s, q):
			ACCEPTED, DONE:
				why = "already"
			COOLING:
				return [{"type": "rejected", "reason": "cooling", "opens": opens_on(s, q)}]
			LOCKED, FINISHED:
				why = "locked"
	if not why.is_empty():
		return [_reject(why)]
	var e := s.quests.entry(id)
	if e == null:
		e = QuestState.Entry.new()
		s.quests.entries[id] = e
	e.status = QuestState.ACCEPTED
	e.progress = 0
	return [{"type": "quest_accepted", "quest": id, "giver": giver}]


## 받은 의뢰를 포기한다(정보상 바 의뢰만, 주요 임무는 no_abandon). 진행은 사라진다.
## 보고한 적이 없으면 기록을 지우고(다시 잠김·받을 수 있음), 있으면 reported 로 돌린다(마지막 보고 날 그대로, 반복 대기도 그대로).
static func abandon(s: ExplorationState, id: String, giver: String) -> Array[Dictionary]:
	var q := _def(s, id)
	var why := _common_block(s, q, giver)
	if why.is_empty() and q.giver == "council":
		why = "no_abandon"
	if why.is_empty() and not s.quests.is_accepted(id):
		why = "not_accepted"
	if not why.is_empty():
		return [_reject(why)]
	var e := s.quests.entry(id)
	if e.reports == 0:
		s.quests.entries.erase(id)
	else:
		e.status = QuestState.REPORTED
		e.progress = 0
	return [{"type": "quest_abandoned", "quest": id}]


## 목표를 이룬 의뢰를 보고한다(설계 §4.4): 모두 검사한 뒤 한 번에 건넴 → 돈 → 물건 → 경험치(살아 있는 파티 대원마다 전부) → 플래그 → 기록.
## 가방이 모자라면(건넨 뒤에도) 보고를 받지 않는다(bag_full, 설계 §4.5). 부른 화면이 한 번 자동 저장한다.
static func report(s: ExplorationState, id: String, giver: String) -> Array[Dictionary]:
	var q := _def(s, id)
	var why := _common_block(s, q, giver)
	if why.is_empty() and not s.quests.is_accepted(id):
		why = "not_accepted"
	if why.is_empty() and not is_done(s, q):
		why = "not_done"
	if why.is_empty() and not reward_fits(s, q):
		why = "bag_full"
	if why.is_empty() and s.money + q.money > BattleLimits.MONEY_MAX:
		why = "money_full"
	if not why.is_empty():
		return [_reject(why)]
	var events: Array[Dictionary] = []
	var delivered: Variant = null
	if q.kind == "deliver":
		BagRules.take(s, q.target, q.count)
		delivered = {"item": q.target, "count": q.count}
	s.money += q.money
	for r in q.items:
		BagRules.add(s, r["item"], r["count"])
	var cap := s.defs.battle.growth.level_cap
	var rows := []
	for i in s.party.members.size():
		var m := s.party.members[i]
		var row := {"member": i, "status": "received", "gained": 0, "from": m.level, "to": m.level}
		if not m.alive():
			row["status"] = "down"
		else:
			if m.level >= cap:
				row["status"] = "at_cap"
			if q.exp > 0:
				var got := GrowthRules.gain_exp(s, i, q.exp, events)
				row["gained"] = got["gained"]
				row["to"] = got["to"]
		rows.append(row)
	for f in q.flags:
		s.flags[f] = true
	var e := s.quests.entry(id)
	e.status = QuestState.REPORTED
	e.progress = 0
	e.reports = mini(e.reports + 1, QuestState.REPORTS_MAX)  # 상한에서 멈춘다(보고·보수는 그대로, 저장 검사와 같은 상한)
	e.day = s.day
	events.append({"type": "quest_reported", "quest": id, "giver": q.giver, "delivered": delivered, "money": q.money,
		"items": q.items.duplicate(true), "flags": q.flags.duplicate(), "members": rows})
	return events


## 보수 물건이 모두 들어가는지(건넬 물건을 뺀 뒤, 물건마다 종류 상한과 함께 쓰는 빈 칸으로). 보수는 가방 물건뿐이다(QuestDb).
static func reward_fits(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	var stores := {"use.": s.consumables.duplicate(), "equip.": s.gear_bag.duplicate(), "item.": s.materials.duplicate()}
	var used := BagRules.used(s)
	if q.kind == "deliver":
		var d: Dictionary = stores[_prefix(q.target)]
		var take := mini(q.count, int(d.get(q.target, 0)))
		d[q.target] = int(d.get(q.target, 0)) - take
		used -= take
	var free := maxi(0, BagRules.SLOTS - used)
	for r in q.items:
		var item: String = r["item"]
		var d: Dictionary = stores[_prefix(item)]
		var n: int = r["count"]
		if n > free or int(d.get(item, 0)) + n > BagRules.kind_cap(item):
			return false
		d[item] = int(d.get(item, 0)) + n
		free -= n
	return true


static func _prefix(item: String) -> String:
	for p in ["use.", "equip.", "item."]:
		if item.begins_with(p):
			return p
	return "item."


# ---- 진행 세기 (설계 §4.3) ----

## 규칙이 막 돌려준 이벤트 열과 그 뒤의 상태를 읽어 받은 의뢰의 진행을 올린다. 화면이 두 곳에서 자동 저장 전에 부른다
## (탐색 행동 뒤 · 전투 제출/끝내기 뒤). s.quests 밖은 바꾸지 않는다. 받은 의뢰가 없으면 [] 이고 아무것도 바꾸지 않는다.
## kill 은 battle_end.kills(승리만), foe 는 battle_end.foes_defeated(층의 FOE 자리 ID → 정의 ID), reach 는 이 묶음 뒤 파티가 그 층·칸에 섰는지,
## deliver 는 세지 않고(가방에서 읽는다) 이 묶음에 얻은 물건으로 목표 수를 넘었을 때만 quest_done 을 낸다.
static func observe(s: ExplorationState, events: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if s.defs == null or s.defs.quests.is_empty():
		return out
	for id in s.defs.quests.order:
		if not s.quests.is_accepted(id):
			continue
		var q: QuestDb.QuestDef = s.defs.quests.quests[id]
		if q.kind == "deliver":
			var gained := _gained(events, q.target)
			if gained > 0:
				var own := owned(s, q.target)
				if own >= q.count and own - gained < q.count:
					out.append({"type": "quest_done", "quest": id})
			continue
		var e := s.quests.entry(id)
		if e.progress >= q.count:
			continue
		var n := 0
		match q.kind:
			"kill":
				for ev in events:
					if ev["type"] == "battle_end":
						for k in ev.get("kills", []):
							if k == q.target:
								n += 1
			"foe":
				for ev in events:
					if ev["type"] == "battle_end":
						for spawn in ev.get("foes_defeated", []):
							var sp: FloorModel.FoeSpawn = s.floor_def.foes.get(spawn)
							if sp != null and sp.foe == q.target:
								n += 1
			"reach":
				if not s.in_town() and s.floor_def.id == q.floor and s.party.at == q.at:
					n = 1
		if n <= 0:
			continue
		e.progress = mini(q.count, e.progress + n)
		if e.progress >= q.count:
			out.append({"type": "quest_done", "quest": id})
		else:
			out.append({"type": "quest_progress", "quest": id, "progress": e.progress, "target": q.count})
	return out


## 이 이벤트 열에서 가방에 실제로 들어온 item 수(전투 끝 드롭·채집·상자).
static func _gained(events: Array[Dictionary], item: String) -> int:
	var n := 0
	for ev in events:
		match ev["type"]:
			"battle_end":
				for d in ev.get("drops", []):
					if d["item"] == item:
						n += int(d["amount"])
			"gathered":
				for x in ev["items"]:
					if x["item"] == item:
						n += int(x["kept"])
			"chest_opened":
				if ev.get("item", "") == item:
					n += int(ev["count"])
	return n


# ---- 진행 플래그 ----

## 옛 저장 이전 규칙(설계 §3.3): 계단 needs 플래그마다 그 계단의 도착 층 기록이 있으면 그 플래그. 이미 내려간 적이 있는 저장이 막히지 않게.
static func migrated_flags(s: ExplorationState) -> Array[String]:
	var out: Array[String] = []
	if s.defs == null:
		return out
	for fid in s.defs.floor_ids:
		for st in s.defs.floors[fid].stair_list():
			if not st.needs.is_empty() and s.floor_states.has(st.to_floor) and not out.has(st.needs):
				out.append(st.needs)
	return out


# ---- 공통 ----

static func _def(s: ExplorationState, id: String) -> QuestDb.QuestDef:
	return s.defs.quests.get_def(id) if s.defs != null else null


## 받기·포기·보고가 함께 보는 것: 전멸 → 전투 → 마을 → 모르는 의뢰 → 다른 시설.
static func _common_block(s: ExplorationState, q: QuestDb.QuestDef, giver: String) -> String:
	if s.wiped:
		return "wiped"
	if s.battle != null or s.encounter.pending:
		return "in_battle"
	if not s.in_town():
		return "not_town"
	if q == null:
		return "unknown_quest"
	if q.giver != giver:
		return "wrong_giver"
	return ""


static func _reject(reason: String) -> Dictionary:
	return {"type": "rejected", "reason": reason}
