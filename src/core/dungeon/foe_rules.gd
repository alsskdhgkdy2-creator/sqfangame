## FOE 규칙(M3 A6, 01 §3.5, 설계 §4). 노드·시간·난수를 쓰지 않는 정적 함수들이고 지금 층 기록(state.world.foes)만 바꾼다.
## 차례: 탐색 한 행동 안에서 걸음 수가 오른 뒤(05 §5.2 5단계) tick 이 모든 FOE 를 층 자료 차례로 한 번씩 움직이고, 접촉은
## 인카운트보다 먼저다(01 §3.1). 파티가 FOE 칸에 들어가려 하면 부딪힘(bump): 파티는 그 앞에 서고 전투가 난다. FOE 도 파티 칸에 들어가지
## 않는다(자기 칸에서 전투). 그래서 살아 있는 FOE 는 파티 칸에 서지 않는다(저장 검사가 보는 불변식).
## FOE 걸음(FloorModel.foe_step): 열린 경계로만, 바닥·피해 바닥 칸으로만(얼음·계단·마을 문·예약 구역은 못 든다). 문은 FOE 를 막는다.
## 거리: 목표 칸에서 거꾸로 너비 우선 탐색(다른 FOE 는 보지 않는다). 걸음은 거리가 가장 작은 이웃, 같으면 N·E·S·W 차례(난수 없음).
##
## 이벤트(탐색 행동의 이벤트 열에 붙는다):
##   {"type": "foe_moved", "foe", "from", "to", "facing"}   {"type": "foe_turned", "foe", "facing"}
##   {"type": "foe_alert", "foe"}   {"type": "foe_lost", "foe"}
##   {"type": "foe_contact", "foe", "by": "party"|"foe"|"guard", "side": "front"|"back"|"left"|"right"} → 그 뒤 encounter {formation, foe}
##   전투 끝(battle_over): {"type": "foe_defeated", "foe"}   숙박(new_day): {"type": "foe_respawned", "floor", "foe"}
##   전투 턴 끝(battle_tick, A6b): {"type": "foe_join", "foe", "n"}(한 걸음 다가옴, n = 새 거리)   {"type": "foe_joined", "foe", "slot", "row"}
class_name FoeRules
extends RefCounted

## 도주 뒤 FOE 가 쉬는 걸음 수(설계 §4.5): 그동안 움직이지 않고 접촉·문지기 발동도 없다.
const ESCAPE_STUN := 2
const SIDES := ["front", "right", "back", "left"]
## 전투 중에 다가올 수 있는 상태(설계 §4.6). battle·defeated 와 문지기는 움직이지 않는다.
const JOIN_FROM := ["idle", "patrol", "alert", "chase", "return", "join"]

## 시험 갈고리(M3 A6 설계 §7.2 R7): false 면 tick·전투 끝 처리를 하지 않는다(FOE 가 없는 것과 같은지 견주기용). 게임 코드는 쓰지 않는다.
static var enabled := true


## 지금 층에서 칸 c 에 선 살아 있는(전투에 들지 않은) FOE id. 없으면 "".
static func foe_at(s: ExplorationState, c: Vector2i) -> String:
	if s.in_town():
		return ""
	for id in s.world.foes:
		var fs: WorldState.FoeState = s.world.foes[id]
		if fs.at == c and fs.alive() and fs.state != "battle":
			return id
	return ""


## 칸 goal 까지의 FOE 걸음 거리(칸 → 걸음 수). goal 이 FOE 칸이 아니면(계단 위의 파티 등) 빈 사전: 거기로는 갈 수 없다.
static func distances(f: FloorModel, goal: Vector2i) -> Dictionary:
	var dist := {}
	if not f.is_foe_cell(goal):
		return dist
	dist[goal] = 0
	var queue: Array[Vector2i] = [goal]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in 4:
			var n := c + Dir.vec(d)
			if dist.has(n) or not f.is_foe_cell(n) or not f.foe_step(n, Dir.opposite(d)):
				continue
			dist[n] = dist[c] + 1
			queue.append(n)
	return dist


## at 에서 dist 의 목표로 가는 한 걸음 방향(가장 가까운 이웃, 같으면 N·E·S·W). 갈 곳이 없으면 -1.
static func step_toward(f: FloorModel, at: Vector2i, dist: Dictionary) -> int:
	var best := -1
	var best_d := 0
	for d in 4:
		var n := at + Dir.vec(d)
		if not dist.has(n) or not f.foe_step(at, d):
			continue
		if best < 0 or int(dist[n]) < best_d:
			best = d
			best_d = dist[n]
	return best


## 추적 FOE 의 시야(설계 §4.2): 바라보는 쪽으로 곧게 sight 칸까지, 열린 경계로만(벽·문이 막는다). 칸 종류는 막지 않는다.
static func sees(f: FloorModel, sp: FloorModel.FoeSpawn, fs: WorldState.FoeState, target: Vector2i) -> bool:
	var c := fs.at
	for i in sp.sight:
		var e := FloorModel.edge_of(c, fs.facing)
		if f.edge_kind(e) != FloorModel.Edge.OPEN or not f.is_cell(c + Dir.vec(fs.facing)):
			return false
		c += Dir.vec(fs.facing)
		if c == target:
			return true
	return false


## FOE 가 돌아갈 자리: 경로가 있으면 path[path_i], 없으면 시작 칸.
static func anchor(sp: FloorModel.FoeSpawn, fs: WorldState.FoeState) -> Vector2i:
	return sp.path[fs.path_i] if not sp.path.is_empty() else sp.at


## FOE 쪽에서 본 파티의 자리(앞·뒤·옆, 선제·기습 갈고리 §8 Q10).
static func side_of(fs: WorldState.FoeState, party: Vector2i) -> String:
	for d in 4:
		if fs.at + Dir.vec(d) == party:
			return SIDES[(d - fs.facing + 4) % 4]
	return "front"


## 탐색 한 걸음의 FOE 차례(설계 §4.3). 접촉이 났으면 {foe, by}(먼저 난 것 하나), 아니면 빈 사전.
static func tick(s: ExplorationState, events: Array[Dictionary]) -> Dictionary:
	if not enabled or s.in_town() or s.world.foes.is_empty():
		return {}
	var f := s.floor_def
	var party := s.party.at
	var hit := {}
	var party_dist := {}
	var party_dist_done := false
	var fresh_guards: Array[String] = []
	for sp in f.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if fs == null or not fs.alive() or fs.state == "battle" or fs.state == "join":
			continue
		if fs.stun > 0:
			fs.stun -= 1
			continue
		if sp.kind == "guard":
			fresh_guards.append(sp.id)
			continue
		if sp.kind == "chase" and fs.state in ["idle", "patrol", "return"] and sees(f, sp, fs, party):
			fs.state = "alert"
			events.append({"type": "foe_alert", "foe": sp.id})
			continue
		if fs.state == "alert":
			fs.state = "chase"
		if fs.state == "chase":
			if not party_dist_done:
				party_dist = distances(f, party)
				party_dist_done = true
			if not party_dist.has(fs.at) or int(party_dist[fs.at]) > sp.chase:
				fs.state = "return"
				events.append({"type": "foe_lost", "foe": sp.id})
			else:
				var d := step_toward(f, fs.at, party_dist)
				if d >= 0:
					_try_step(s, sp, fs, d, hit, events)
				continue
		if fs.state == "return":
			var home := anchor(sp, fs)
			if fs.at != home:
				var d := step_toward(f, fs.at, distances(f, home))
				if d >= 0:
					_try_step(s, sp, fs, d, hit, events)
			if fs.at == home:
				if sp.path.is_empty():
					fs.state = "idle"
					fs.facing = sp.facing
				else:
					fs.state = "patrol"
			continue
		if fs.state == "patrol":
			var next := fs.path_i + fs.dir
			if next < 0 or next >= sp.path.size():
				fs.dir = -fs.dir
				fs.facing = Dir.opposite(fs.facing)
				events.append({"type": "foe_turned", "foe": sp.id, "facing": fs.facing})
				continue
			var to: Vector2i = sp.path[next]
			for d in 4:
				if fs.at + Dir.vec(d) == to:
					if _try_step(s, sp, fs, d, hit, events):
						fs.path_i = next
	if hit.is_empty():
		for id in fresh_guards:
			var fs: WorldState.FoeState = s.world.foes[id]
			for d in 4:
				if fs.at + Dir.vec(d) == party and f.edge_kind(FloorModel.edge_of(fs.at, d)) == FloorModel.Edge.OPEN:
					hit = {"foe": id, "by": "guard"}
					break
			if not hit.is_empty():
				break
	return hit


## d 쪽으로 한 걸음: 파티 칸이면 접촉(처음이면 hit 에 적고 그 자리에서 파티를 본다, 이미 접촉이 있으면 기다린다), 다른 FOE 칸이면 기다린다
## (그쪽을 본다). 옮겼으면 true.
static func _try_step(s: ExplorationState, sp: FloorModel.FoeSpawn, fs: WorldState.FoeState, d: int, hit: Dictionary,
		events: Array[Dictionary]) -> bool:
	var to := fs.at + Dir.vec(d)
	var turned := fs.facing != d
	fs.facing = d
	if to == s.party.at:
		if hit.is_empty():
			hit["foe"] = sp.id
			hit["by"] = "foe"
		if turned:
			events.append({"type": "foe_turned", "foe": sp.id, "facing": d})
		return false
	for id in s.world.foes:
		var o: WorldState.FoeState = s.world.foes[id]
		if id != sp.id and o.alive() and o.at == to:
			if turned:
				events.append({"type": "foe_turned", "foe": sp.id, "facing": d})
			return false
	events.append({"type": "foe_moved", "foe": sp.id, "from": fs.at, "to": to, "facing": d})
	fs.at = to
	return true


## 접촉 전투를 연다(설계 §4.4 8단계): foe_contact → BattleRules.start(무리, foe) → encounter. 위험도·인카운트는 건드리지 않는다.
static func contact(s: ExplorationState, id: String, by: String, events: Array[Dictionary]) -> void:
	var fs: WorldState.FoeState = s.world.foes[id]
	var sp: FloorModel.FoeSpawn = s.floor_def.foes[id]
	var formation := s.defs.battle.foe(sp.foe).formation
	events.append({"type": "foe_contact", "foe": id, "by": by, "side": side_of(fs, s.party.at)})
	var st := BattleRules.start(s, formation, id)
	if st[0]["type"] == "battle_start":
		events.append({"type": "encounter", "formation": formation, "foe": id})


## 전투 턴 끝에 움직이는 FOE(설계 §4.6, §8 Q4): 지금 층의 살아 있는 문지기 아닌 FOE 중 JOIN_FROM 상태이고 쉬지 않으며(stun 0) join > 0 이고
## 파티 칸(전투 칸)까지 FOE 걸음 거리 d 가 join 이하인 것, 층 자료 차례. [{sp, fs, d}]. dist 는 파티 칸까지의 거리.
static func _join_candidates(s: ExplorationState, dist: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sp in s.floor_def.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if sp.kind == "guard" or sp.join <= 0 or fs == null or not fs.alive() or not JOIN_FROM.has(fs.state) or fs.stun > 0:
			continue
		if dist.has(fs.at) and int(dist[fs.at]) <= sp.join:
			out.append({"sp": sp, "fs": fs, "d": int(dist[fs.at])})
	return out


## 합류할 열(설계 §4.7): 무리의 열에 유닛이 3 미만이면 그 열, 아니면 다른 열에 자리가 있으면 그 열, 둘 다 차면 ""(기다린다).
## 쓰러진 유닛도 센다.
static func join_row(s: ExplorationState, id: String) -> String:
	var fe := BattleState.foe_enemy(s.defs, s.floor_def, id)
	if fe.is_empty():
		return ""
	var own: String = fe["row"]
	for row in [own, "back" if own == "front" else "front"]:
		if s.battle.row_count(row) < BattleLimits.ROW_MAX:
			return row
	return ""


## 전투 한 턴 끝(BattleRules._turn_end 가 b.turn 을 올린 뒤, 설계 §4.6): 후보마다 join 상태가 되고, d == 1 이면 자리가 있을 때 합류
## (battle 상태, enemies 끝에 유닛, foe_joined), 아니면 파티 쪽으로 한 걸음(foe_join, n = 새 거리; 막혔으면 그쪽을 보고 기다린다).
## 합류가 있었으면 true(그 뒤 열 바뀜을 본다). 후보가 없으면 상태·이벤트 그대로.
static func battle_tick(s: ExplorationState, events: Array[Dictionary]) -> bool:
	if not enabled or s.battle == null or s.in_town() or s.world.foes.is_empty():
		return false
	var f := s.floor_def
	var dist := distances(f, s.party.at)
	var joined := false
	for c in _join_candidates(s, dist):
		var sp: FloorModel.FoeSpawn = c["sp"]
		var fs: WorldState.FoeState = c["fs"]
		fs.state = "join"
		var d := step_toward(f, fs.at, dist)
		if d >= 0:
			fs.facing = d
		if int(c["d"]) == 1:
			var row := join_row(s, sp.id)
			if row.is_empty():
				continue
			var u := s.battle.add_joiner(s.defs, f, sp.id, row)
			fs.state = "battle"
			events.append({"type": "foe_joined", "foe": sp.id, "slot": u.slot, "row": row})
			joined = true
		elif d >= 0 and _free(s, fs.at + Dir.vec(d), sp.id):
			fs.at += Dir.vec(d)
			events.append({"type": "foe_join", "foe": sp.id, "n": int(dist[fs.at])})
	return joined


## 화면이 읽는 합류 예정(설계 §4.6, 읽기만): 후보마다 {foe, n, wait}, n = 거리(그 턴 수 뒤 끝에 합류), wait = 맞닿았는데 자리가 없음.
## 전투가 없으면 빈 배열.
static func join_eta(s: ExplorationState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not enabled or s.battle == null or s.in_town() or s.world.foes.is_empty():
		return out
	for c in _join_candidates(s, distances(s.floor_def, s.party.at)):
		var id: String = c["sp"].id
		out.append({"foe": id, "n": c["d"], "wait": c["d"] == 1 and join_row(s, id).is_empty()})
	return out


## 전투가 끝날 때(BattleRules.finish 가 battle 을 지우기 전에, 설계 §4.5). 승리면 전투의 FOE 는 쓰러짐(day), 도주면 그 자리에서
## ESCAPE_STUN 걸음 쉬고 종류대로(순회 return·추적 chase·문지기 idle). 걷던(join) FOE 는 승리·도주 모두 순회 return, 추적은 거리가
## chase 안이면 chase 아니면 return. 전멸이면 자리·방향은 그대로 두고 전투에서만 빠진다(도주와 같은 상태, 쉬지 않음): 전멸 상태도 저장되므로
## battle·join 이 전투 없이 남지 않게 한다(finish 의 「받은 끝 상태는 늘 저장할 수 있다」, 설계 §4.5 「그대로」를 고쳐 읽음).
static func battle_over(s: ExplorationState, outcome: String, events: Array[Dictionary]) -> void:
	if not enabled or s.battle == null or s.in_town():
		return
	var f := s.floor_def
	var party_dist := {}
	var have_dist := false
	for sp in f.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if fs == null:
			continue
		if outcome == "wiped":
			if fs.state == "battle" or fs.state == "join":
				fs.state = {"patrol": "return", "chase": "chase", "guard": "idle"}[sp.kind]
			continue
		if fs.state == "battle":
			if outcome == "victory":
				fs.state = "defeated"
				fs.day = s.day
				fs.stun = 0
				events.append({"type": "foe_defeated", "foe": sp.id})
			else:
				fs.stun = ESCAPE_STUN
				fs.state = {"patrol": "return", "chase": "chase", "guard": "idle"}[sp.kind]
		elif fs.state == "join":
			if sp.kind == "chase":
				if not have_dist:
					party_dist = distances(f, s.party.at)
					have_dist = true
				fs.state = "chase" if party_dist.has(fs.at) and int(party_dist[fs.at]) <= sp.chase else "return"
			else:
				fs.state = "return"


## 층에 들어설 때(계단 도착·마을에서 B1F, 설계 §4.8): 살아 있는 FOE 는 모두 처음 상태로, floor_reload 로 쓰러진 FOE 도 되살아난다.
static func enter_floor(s: ExplorationState) -> void:
	for sp in s.floor_def.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if fs == null or fs.alive() or sp.respawn == "floor_reload":
			s.world.foes[sp.id] = WorldState.FoeState.fresh(sp)


## 날이 바뀔 때(TownRules.new_day, 설계 §4.8): 모든 층 기록에서 after_days 로 쓰러진 FOE 가 날이 차면 되살아난다. 되살아난 것의 이벤트 목록.
static func new_day(s: ExplorationState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fid in s.floor_states:
		var r: FloorState = s.floor_states[fid]
		for sp in r.floor_def.foe_list():
			var fs: WorldState.FoeState = r.world.foes.get(sp.id)
			if fs != null and not fs.alive() and sp.respawn == "after_days" and s.day >= fs.day + sp.respawn_days:
				r.world.foes[sp.id] = WorldState.FoeState.fresh(sp)
				out.append({"type": "foe_respawned", "floor": fid, "foe": sp.id})
	return out


## 옛 저장(1~9판)을 읽은 뒤(설계 §3.4): 지금 층에서 파티 칸에 선 살아 있는 FOE 를 가장 가까운 빈 FOE 칸(FOE 걸음 너비 우선, N·E·S·W)으로
## 옮기고(문지기도), 파티와 맞닿은 문지기는 ESCAPE_STUN 걸음 쉬게 한다(읽자마자 첫 걸음에 전투가 나지 않게). 마을이면 하지 않는다.
static func settle(s: ExplorationState) -> void:
	if s.in_town():
		return
	var f := s.floor_def
	var party := s.party.at
	for sp in f.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if fs == null or not fs.alive():
			continue
		if fs.at == party:
			var seen := {fs.at: true}
			var queue: Array[Vector2i] = [fs.at]
			var head := 0
			var found := fs.at
			while head < queue.size() and found == fs.at:
				var c := queue[head]
				head += 1
				for d in 4:
					var n := c + Dir.vec(d)
					if seen.has(n) or not f.foe_step(c, d):
						continue
					seen[n] = true
					if n != party and _free(s, n, sp.id):
						found = n
						break
					queue.append(n)
			fs.at = found
			# 경로가 있는 FOE 는 자리를 맞춘다(리뷰 R1): 경로 위면 그 자리로 path_i 를 옮기고, 경로 밖이면 path[path_i] 로 돌아간다(return).
			# 그러지 않으면 순회가 다음 경로 칸을 찾지 못해 멈춘다. 순회 상태의 FOE 는 늘 path[path_i] 에 선다(10판 읽기가 본다).
			if not sp.path.is_empty():
				var idx := sp.path.find(found)
				if idx >= 0:
					fs.path_i = idx
				else:
					fs.state = "return"
		if sp.kind == "guard":
			for d in 4:
				if fs.at + Dir.vec(d) == party and f.edge_kind(FloorModel.edge_of(fs.at, d)) == FloorModel.Edge.OPEN:
					fs.stun = ESCAPE_STUN


static func _free(s: ExplorationState, c: Vector2i, except: String) -> bool:
	for id in s.world.foes:
		var o: WorldState.FoeState = s.world.foes[id]
		if id != except and o.alive() and o.at == c:
			return false
	return true


## 위협 색 단계(설계 §5.4): FOE 레벨 − 대원 최고 레벨이 5 이상 red, 0~4 orange, 0 미만 yellow.
static func threat(s: ExplorationState, id: String) -> String:
	var sp: FloorModel.FoeSpawn = s.floor_def.foes.get(id)
	if sp == null or s.defs == null:
		return ""
	var top := 1
	for m in s.party.members:
		top = maxi(top, m.level)
	var diff := s.defs.battle.foe(sp.foe).level - top
	if diff >= 5:
		return "red"
	return "orange" if diff >= 0 else "yellow"
