## 채집 규칙(M3 A5, 01 §3.6): 지점 이벤트, GATHER 행동, 수확 굴림, 채집 스킬·습격 갈고리. 노드에 기대지 않는다.
## 지점마다 하루 횟수(uses)가 있고 숙소에서 날이 바뀌면 되돌아온다(TownRules.new_day). 걸음·위험도·인카운트가 없다(원작 IV 처럼, 설계 §4.5).
## 수확은 공용 가방(D31)의 입구 BagRules.add 로만 넣는다: 다 들어가지 않으면 들어가는 만큼 넣고 나머지는 잃는다(전투 드롭과 같다).
## 가방이 가득(빈 칸 0, 넘친 옛 저장 포함)이면 아무것도 바꾸지 않는다(횟수도 쓰지 않는다).
##
## 수확 난수는 본 난수(s.rng)에서 뽑지 않는다: 층·지점·날·그 지점에서 오늘 쓴 횟수·본 난수의 지금 상태(읽기만)로 씨앗을 만들어
## 새 GameRng 로 굴린다. 그래서 인카운트 한계값·편성·전투·드롭·시뮬레이션은 채집과 상관없이 같은 난수를 보고, 같은 저장은 같은 수확을 낸다.
## 씨앗은 String.hash(32비트)이다. 엔진이 그 해시를 바꾸면 그 뒤의 수확만 달라진다(저장에는 결과만 남는다).
##
## 이벤트(ExplorationRules.apply 가 돌려준다):
##   {"type": "gather", "point", "kind", "left", "uses"}   지점에 멈춤·조사, 오늘 남은 횟수가 있다(화면이 묻는다)
##   {"type": "gather_spent", "point"}                     지점에 멈춤·조사, 오늘은 다 썼다(알림만)
##   {"type": "gathered", "point", "kind", "items": [{"item", "count", "kept"}], "lost", "left", "uses"}
##   {"type": "gather_full", "point"}                      가방 60/60: 아무것도 바꾸지 않는다
##   {"type": "blocked", "reason": "not_gather" | "gather_spent"}
class_name GatherRules
extends RefCounted

## 시험 갈고리: 채집 스킬 보너스를 대신 정한다((s, kind) → {count, rare_permille}). 게임 코드는 쓰지 않는다.
static var bonus_hook := Callable()


## 채집 스킬 보너스(01 §3.6: 수확량·희귀 확률). M3 A7: 희귀 확률은 살아 있는 파티 대원(길드 대원은 빼고)이 배운 패시브의
## gather_rare(레인저 「포리지 센스」) 가운데 가장 큰 값이다(더하지 않는다). 세 종류에 모두 같다(원작 채취·벌채·채굴 스킬을 하나로, 설계 §4.3).
## 수확량 보너스는 아직 없다(0). 난수를 뽑지 않는다.
static func skill_bonus(s: ExplorationState, kind: String) -> Dictionary:
	if bonus_hook.is_valid():
		return bonus_hook.call(s, kind)
	var rare := 0
	for m in s.party.members:
		if m.hp <= 0:
			continue
		for id in m.skills:
			var sk: BattleDb.SkillDef = s.defs.battle.skill(id)
			if sk != null and sk.passive():
				rare = maxi(rare, int(sk.level_row(int(m.skills[id])).get("gather_rare", 0)))
	return {"count": 0, "rare_permille": rare}


## 채집 습격 갈고리(슬라이스 뒤, R1 §2.5): 습격할 편성 ID, 없으면 "". 지금은 늘 "". 넣을 때는 화면이 GATHER 전에 「계속할까?」를 묻고,
## 수확 뒤 같은 행동 안에서 BattleRules.start 로 전투를 연다(이벤트 차례: 수확 → 습격).
static func ambush(_s: ExplorationState, _p: FloorModel.GatherPoint) -> String:
	return ""


## 지점 p 의 used 번째(0부터) 채집의 씨앗. 본 난수를 읽기만 한다.
static func roll_seed(s: ExplorationState, p: FloorModel.GatherPoint, used: int) -> int:
	return ("gather|%s|%s|%d|%d|%d" % [s.floor_def.id, p.id, s.day, used, s.rng.get_state()]).hash()


## 수확 굴림: 무게로 줄 하나를 고르고 개수 [lo, hi](+ 스킬 보너스), 표에 희귀 소재가 있으면 천분율로 하나 더. [{item, count}] 굴린 차례.
static func roll(s: ExplorationState, p: FloorModel.GatherPoint, table: BattleDb.GatherTableDef, used: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := GameRng.new(roll_seed(s, p, used))
	var bonus := skill_bonus(s, p.kind)
	var pick := rng.randi_range(1, table.total_weight())
	for x in table.items:
		pick -= int(x["weight"])
		if pick <= 0:
			out.append({"item": x["item"], "count": rng.randi_range(int(x["lo"]), int(x["hi"])) + int(bonus["count"])})
			break
	if not table.rare_item.is_empty():
		if rng.randi_range(1, 1000) <= mini(1000, table.rare_permille + int(bonus["rare_permille"])):
			out.append({"item": table.rare_item, "count": 1})
	return out


## 서 있는 칸이 채집 지점이면 gather(남은 횟수가 있을 때) 또는 gather_spent 를 더하고 true. 마을이면 false.
static func point_event(s: ExplorationState, events: Array[Dictionary]) -> bool:
	if s.in_town():
		return false
	var p := s.floor_def.point_at(s.party.at)
	if p == null:
		return false
	var left := s.world.gather_left(p)
	if left > 0:
		events.append({"type": "gather", "point": p.id, "kind": p.kind, "left": left, "uses": p.uses})
	else:
		events.append({"type": "gather_spent", "point": p.id})
	return true


## GATHER(ExplorationRules 가 전멸·전투 대기·마을을 먼저 거른다). 거부 차례: 지점 없음 → 오늘 다 씀 → 가방 가득 → 받아들임.
static func gather(s: ExplorationState, events: Array[Dictionary]) -> void:
	var p := s.floor_def.point_at(s.party.at)
	if p == null:
		events.append({"type": "blocked", "reason": "not_gather"})
		return
	if s.world.gather_left(p) <= 0:
		events.append({"type": "blocked", "reason": "gather_spent"})
		return
	if BagRules.free_slots(s) == 0:
		events.append({"type": "gather_full", "point": p.id})
		return
	var table := s.defs.battle.gather_table(p.table)
	assert(table != null, "채집 표가 없다: " + p.table)
	var used := int(s.world.gather_used.get(p.id, 0))
	s.world.take_gather(p.id)
	var items: Array[Dictionary] = []
	var lost := 0
	for x in roll(s, p, table, used):
		var kept := BagRules.add(s, str(x["item"]), int(x["count"]))
		items.append({"item": x["item"], "count": x["count"], "kept": kept})
		lost += int(x["count"]) - kept
	ambush(s, p)
	events.append({"type": "gathered", "point": p.id, "kind": p.kind, "items": items, "lost": lost,
		"left": s.world.gather_left(p), "uses": p.uses})


## 캠프 알약(07 §9.8, 설계 §5.3): 종류마다 [오늘 남은 횟수 합, 하루 횟수 합]. 모든 층에서 파티가 서 본 지점만 센다(지도에 없는 곳은 알리지 않는다).
## 원작 III 은 파티 전체의 하루 몫이지만 여기는 지점마다라 서 본 지점을 더한다(이름 붙은 차이). 마을과 미궁에서 같다.
static func kind_counts(s: ExplorationState) -> Dictionary:
	var out := {}
	for k in BattleLimits.GATHER_KINDS:
		out[k] = [0, 0]
	for id in s.floor_states:
		var fs: FloorState = s.floor_states[id]
		for p in fs.floor_def.point_list():
			if not fs.knowledge.is_visited(p.at):
				continue
			out[p.kind][0] += fs.world.gather_left(p)
			out[p.kind][1] += p.uses
	return out
