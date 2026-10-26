## 탐색 규칙 함수. 상태를 바꾸고 화면 연출용 이벤트를 차례대로 돌려준다.
## 같은 상태·행동·자동 기록 설정이면 같은 이벤트가 나온다.
class_name ExplorationRules
extends RefCounted

## STAIRS(M3 A1): 서 있는 계단으로 층을 바꾼다(화면이 확인 창 「예」 뒤에 부른다). B1F 마을 문 위면 마을로 나간다(M3 A2).
## ENTER(M3 A2): 마을에서 미궁 B1F 시작 칸으로 들어간다(아보르 입구 「탐사 시작」). 값이 바뀌지 않게 새 행동은 맨 뒤에 둔다.
## 7 은 비어 있다: 시작 칸 휴식(REST, 06 §8.8 자리표시)은 숙소 숙박(M3 A2b, TownRules.stay)으로 바뀌어 없앴고 STAIRS 는 8 그대로다.
## OPEN(M3 A3): 서 있는 칸의 닫힌 보물상자를 연다(화면이 상자 물음 「예」 뒤에 부른다).
enum Action { FORWARD, BACK, STRAFE_LEFT, STRAFE_RIGHT, TURN_LEFT, TURN_RIGHT, INVESTIGATE, STAIRS = 8, ENTER, OPEN }

## 행동 이름(공략 행동열 파일·디버그용) → Action.
const ACTION_NAMES := {
	"forward": Action.FORWARD, "back": Action.BACK, "strafe_left": Action.STRAFE_LEFT, "strafe_right": Action.STRAFE_RIGHT,
	"turn_left": Action.TURN_LEFT, "turn_right": Action.TURN_RIGHT, "investigate": Action.INVESTIGATE,
	"stairs": Action.STAIRS, "enter": Action.ENTER, "open": Action.OPEN,
}
const AUTOMAP_OFF := "off"
const AUTOMAP_FLOOR := "floor"
const AUTOMAP_FULL := "full"
const AUTOMAP_MODES := ["off", "floor", "full"]


## 새 게임: 첫 층(B1F)의 시작 칸을 방문·관찰·자동 기록하고 한계값을 처음 뽑는다. 대원은 HP·TP 가득(defs.members()), 시작 소지금, 빈 상점(08 §2).
## 층 기록은 첫 층 것 하나만 있다(M3 A1). in_town(M3 A2, 게임 화면의 새 게임)이면 마을(광장)에서 시작하고 시작 칸은 기록하지 않는다
## (ENTER 가 기록한다). 한계값은 같은 난수로 뽑으므로 난수 상태는 미궁 새 게임과 같다. 1일째.
static func new_game(defs: GameDefs, seed_value: int, automap: String, in_town: bool = false) -> ExplorationState:
	var s := ExplorationState.new()
	var floor_def := defs.first_floor()
	s.defs = defs
	s.enter_floor(floor_def)
	s.rng = GameRng.new(seed_value)
	s.party.at = floor_def.start_at
	s.party.facing = floor_def.start_facing
	s.party.members = defs.members()
	s.money = ExplorationState.START_MONEY
	s.encounter.roll_threshold(s.rng, floor_def.threshold_min, floor_def.threshold_max)
	if in_town:
		s.location = ExplorationState.TOWN
	else:
		record_cell(s, floor_def.start_at, automap)
	return s


## 새 게임용 시드(규칙 밖에서 한 번만 쓴다).
static func fresh_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi()


## 행동 이름 → Action 값. 모르는 이름이면 -1.
static func action_from_name(action_name: String) -> int:
	return ACTION_NAMES.get(action_name, -1)


## 거부 조건이 없는지(전투 대기·전멸 아님).
static func can_act(s: ExplorationState) -> bool:
	return not s.wiped and not s.encounter.pending


## 마을(M3 A2)에서는 ENTER 만 받고 나머지는 rejected town(상태 그대로). 미궁에서 ENTER 는 막힘 not_town.
static func apply(s: ExplorationState, action: int, automap: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if s.wiped or s.encounter.pending:
		events.append({"type": "rejected", "reason": "wiped" if s.wiped else "pending"})
		return events
	if s.in_town():
		if action == Action.ENTER:
			_enter(s, events, automap)
		else:
			events.append({"type": "rejected", "reason": "town"})
		return events
	match action:
		Action.TURN_LEFT, Action.TURN_RIGHT:
			s.party.facing = Dir.left(s.party.facing) if action == Action.TURN_LEFT else Dir.right(s.party.facing)
			events.append({"type": "turned", "facing": s.party.facing})
		Action.INVESTIGATE:
			_investigate(s, events, automap)
		Action.STAIRS:
			_take_stairs(s, events, automap)
		Action.ENTER:
			events.append({"type": "blocked", "reason": "not_town"})
		Action.OPEN:
			_open_chest(s, events)
		_:
			_move(s, _move_dir(s.party.facing, action), action == Action.FORWARD, events, automap)
	return events


## 지금 세계 상태에서 경계의 겉모습.
static func look_of(floor_def: FloorModel, world: WorldState, e: Vector3i) -> String:
	match floor_def.edge_kind(e):
		FloorModel.Edge.OPEN:
			return "open"
		FloorModel.Edge.DOOR:
			return "door"
		FloorModel.Edge.SHORTCUT:
			return "shortcut"
		FloorModel.Edge.ONEWAY:
			return "oneway"
		FloorModel.Edge.PASSAGE:
			return "passage" if world.is_passage_found(e) else "wall"
		FloorModel.Edge.LOCK:
			return "door" if world.is_lock_open(e) else "locked"
		_:
			return "wall"


## 칸 at에서 d 방향으로 한 칸 나갈 수 있는지. 지나가면 "", 아니면 막힘 사유.
## 닫힌 지름길은 열 수 있는 쪽이면 shortcut_closed(정면 전진·조사는 따로 연다), 반대쪽이면 shortcut_locked.
## 닫힌 잠긴 문(M3 A3)은 봉인이면 sealed, 그 열쇠를 가졌으면(keys) lock_closed(정면 전진·조사가 연다), 아니면 locked.
## 지나갈 수 있는지는 keys 와 상관없다(keys 는 사유 글만 가른다).
static func block_reason(floor_def: FloorModel, world: WorldState, at: Vector2i, d: int, keys: Dictionary = {}) -> String:
	var e := FloorModel.edge_of(at, d)
	if not floor_def.is_cell(at + Dir.vec(d)):
		return "wall"
	match floor_def.edge_kind(e):
		FloorModel.Edge.OPEN, FloorModel.Edge.DOOR:
			return ""
		FloorModel.Edge.PASSAGE:
			return "" if world.is_passage_found(e) else "wall"
		FloorModel.Edge.ONEWAY:
			return "" if floor_def.oneway_dir(e) == d else "oneway"
		FloorModel.Edge.SHORTCUT:
			if world.is_shortcut_open(e):
				return ""
			return "shortcut_closed" if floor_def.shortcut_opener(e) == at else "shortcut_locked"
		FloorModel.Edge.LOCK:
			if world.is_lock_open(e):
				return ""
			if floor_def.is_sealed(e):
				return "sealed"
			return "lock_closed" if keys.has(floor_def.lock_key(e)) else "locked"
		_:
			return "wall"


## at에서 d로 움직일 때 들어가는 칸들(미끄러짐 포함). 첫 칸부터 막히면 빈 배열.
static func move_path(floor_def: FloorModel, world: WorldState, at: Vector2i, d: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := at
	while block_reason(floor_def, world, cur, d) == "":
		cur += Dir.vec(d)
		path.append(cur)
		if floor_def.cell_kind(cur) != FloorModel.Cell.ICE:
			break
	return path


## 칸에 들어갔을 때의 기록: 방문, 네 경계 겉모습, 자동 지도.
static func record_cell(s: ExplorationState, c: Vector2i, automap: String) -> void:
	s.knowledge.visit(c)
	if automap != AUTOMAP_OFF:
		s.annotation.auto_floor(c)
	for d in 4:
		var e := FloorModel.edge_of(c, d)
		_observe(s, e, automap)


# ---- 내부 ----

static func _move_dir(facing: int, action: int) -> int:
	match action:
		Action.BACK:
			return Dir.opposite(facing)
		Action.STRAFE_LEFT:
			return Dir.left(facing)
		Action.STRAFE_RIGHT:
			return Dir.right(facing)
		_:
			return facing


static func _observe(s: ExplorationState, e: Vector3i, automap: String) -> void:
	var look := look_of(s.floor_def, s.world, e)
	s.knowledge.see_edge(e, look)
	if automap != AUTOMAP_FULL:
		return
	if look == "wall":
		s.annotation.auto_edge(e, "wall")
	elif look == "door" or look == "shortcut" or look == "locked":
		s.annotation.auto_edge(e, "door")


## 열 수 있는 쪽에서 바라본 닫힌 지름길이면 연다.
static func _try_open_shortcut(s: ExplorationState, e: Vector3i, events: Array[Dictionary], automap: String) -> bool:
	var f := s.floor_def
	if f.edge_kind(e) != FloorModel.Edge.SHORTCUT or s.world.is_shortcut_open(e) or f.shortcut_opener(e) != s.party.at:
		return false
	s.world.open_shortcut(e)
	_observe(s, e, automap)
	events.append({"type": "shortcut_opened", "edge": e})
	return true


## 바라본 닫힌 열쇠 문을 그 열쇠로 연다(M3 A3, 어느 쪽에서든). 열쇠는 남는다.
static func _try_open_lock(s: ExplorationState, e: Vector3i, events: Array[Dictionary], automap: String) -> bool:
	var f := s.floor_def
	if f.edge_kind(e) != FloorModel.Edge.LOCK or s.world.is_lock_open(e) or f.is_sealed(e) or not s.key_items.has(f.lock_key(e)):
		return false
	s.world.open_lock(e)
	_observe(s, e, automap)
	events.append({"type": "lock_opened", "edge": e, "key": f.lock_key(e)})
	return true


static func _investigate(s: ExplorationState, events: Array[Dictionary], automap: String) -> void:
	var e := FloorModel.edge_of(s.party.at, s.party.facing)
	if s.floor_def.edge_kind(e) == FloorModel.Edge.PASSAGE and not s.world.is_passage_found(e):
		s.world.find_passage(e)
		s.annotation.clear_auto_wall(e)
		_observe(s, e, automap)
		events.append({"type": "passage_found", "edge": e})
		return
	if _try_open_shortcut(s, e, events, automap):
		return
	if _try_open_lock(s, e, events, automap):
		return
	# 바라본 닫힌 잠긴 문(열쇠가 없거나 봉인)은 그 사유를 알린다(M3 A3).
	if s.floor_def.edge_kind(e) == FloorModel.Edge.LOCK and not s.world.is_lock_open(e):
		events.append({"type": "blocked", "reason": block_reason(s.floor_def, s.world, s.party.at, s.party.facing, s.key_items)})
		return
	# 상자 칸에서 조사하면 닫힌 상자는 다시 묻고, 연 상자는 「빈 상자」(M3 A3).
	var chest := s.floor_def.chest_at(s.party.at)
	if chest != null:
		if s.world.is_chest_opened(chest.id):
			events.append({"type": "chest_empty", "chest": chest.id})
		else:
			events.append({"type": "chest", "chest": chest.id})
		return
	# 계단 위에서 조사하면 계단 확인을 다시 묻는다(거절·전투·새로고침 뒤, M3 A1).
	if _stairs_event(s, events):
		return
	events.append({"type": "nothing_found"})


static func _move(s: ExplorationState, d: int, forward: bool, events: Array[Dictionary], automap: String) -> void:
	var f := s.floor_def
	if forward and _try_open_shortcut(s, FloorModel.edge_of(s.party.at, d), events, automap):
		return
	if forward and _try_open_lock(s, FloorModel.edge_of(s.party.at, d), events, automap):
		return
	var path := move_path(f, s.world, s.party.at, d)
	if path.is_empty():
		events.append({"type": "blocked", "reason": block_reason(f, s.world, s.party.at, d, s.key_items)})
		return
	for i in path.size():
		var from := s.party.at
		var to := path[i]
		var door := f.edge_kind(FloorModel.edge_of(from, d)) == FloorModel.Edge.DOOR
		s.party.at = to
		events.append({"type": "moved", "from": from, "to": to, "dir": d, "via": "step" if i == 0 else "slide", "door": door})
		_cell_effect(s, to, events)
		record_cell(s, to, automap)
	s.steps += 1
	if s.wiped:
		events.append({"type": "wiped"})
		return
	if s.encounter.add(f.danger_at(s.party.at)):
		# 같은 행동 안에서 편성을 뽑고 전투를 연다(06 §8.3).
		var formation := BattleRules.pick_formation(s)
		BattleRules.start(s, formation)
		events.append({"type": "encounter", "formation": formation})
		return
	# 계단 칸에서 멈췄으면(전멸·인카운트가 아닐 때만) 화면이 확인 창을 띄운다(M3 A1). 닫힌 상자 칸이면 상자 물음(M3 A3).
	# 계단과 상자는 한 칸에 겹치지 않는다(층 형식 검사).
	if not _stairs_event(s, events):
		var chest := f.chest_at(s.party.at)
		if chest != null and not s.world.is_chest_opened(chest.id):
			events.append({"type": "chest", "chest": chest.id})


## 서 있는 칸의 계단: {way, to}(계단이면 짝 층 ID, B1F 마을 문이면 to = "town", M3 A2). 아니면 빈 사전.
static func stair_here(s: ExplorationState) -> Dictionary:
	if s.in_town():
		return {}
	var st := s.floor_def.stair_at(s.party.at)
	if st != null:
		return {"way": st.way, "to": st.to_floor}
	if s.defs != null and s.defs.is_gate(s.floor_def, s.party.at):
		return {"way": "up", "to": ExplorationState.TOWN}
	return {}


## 서 있는 칸의 물음(M3 A3): 계단(마을 문 포함)이면 {kind: "stairs", way, to}, 닫힌 상자면 {kind: "chest", chest: id}, 아니면 빈 사전.
## 화면이 남은 물음이 아직 맞는지 볼 때 쓴다.
static func question_here(s: ExplorationState) -> Dictionary:
	var st := stair_here(s)
	if not st.is_empty():
		st["kind"] = "stairs"
		return st
	if s.in_town():
		return {}
	var chest := s.floor_def.chest_at(s.party.at)
	if chest != null and not s.world.is_chest_opened(chest.id):
		return {"kind": "chest", "chest": chest.id}
	return {}


## 서 있는 칸의 닫힌 상자를 연다(M3 A3). 상자가 없거나 이미 열었으면 막힘 not_chest. 넣을 자리가 없으면(소재 9999·가방 99·소지금 상한)
## 아무것도 바꾸지 않고 chest_full(상자는 닫힌 채 남는다, 일부만 꺼내지 않는다). 걸음·위험도·난수는 그대로다.
static func _open_chest(s: ExplorationState, events: Array[Dictionary]) -> void:
	var chest := s.floor_def.chest_at(s.party.at)
	if chest == null or s.world.is_chest_opened(chest.id):
		events.append({"type": "blocked", "reason": "not_chest"})
		return
	if chest.item.is_empty():
		if s.money + chest.money > BattleLimits.MONEY_MAX:
			events.append({"type": "chest_full", "chest": chest.id, "item": "", "money": chest.money})
			return
		s.money += chest.money
		s.world.open_chest(chest.id)
		events.append({"type": "chest_opened", "chest": chest.id, "money": chest.money})
		return
	var item := chest.item
	if item.begins_with("key."):
		s.key_items[item] = true
	elif item.begins_with("equip."):
		var have: int = s.gear_bag.get(item, 0)
		if have + chest.count > BattleLimits.BAG_MAX:
			events.append({"type": "chest_full", "chest": chest.id, "item": item})
			return
		s.gear_bag[item] = have + chest.count
	else:
		var have: int = s.materials.get(item, 0)
		if have + chest.count > BattleLimits.MATERIAL_MAX:
			events.append({"type": "chest_full", "chest": chest.id, "item": item})
			return
		s.materials[item] = have + chest.count
	s.world.open_chest(chest.id)
	events.append({"type": "chest_opened", "chest": chest.id, "item": item, "count": chest.count})


## 서 있는 칸이 계단(마을 문 포함)이면 stairs 이벤트(way·to)를 더하고 true.
static func _stairs_event(s: ExplorationState, events: Array[Dictionary]) -> bool:
	var st := stair_here(s)
	if st.is_empty():
		return false
	events.append({"type": "stairs", "way": st["way"], "to": st["to"]})
	return true


## 계단으로 층 바꾸기(M3 A1): 짝 계단이 있는 층으로 들어가 그 계단 칸에 서서 계단의 exit 쪽을 본다. 계단 칸을 방문·관찰·자동 기록한다.
## 걸음·위험도·한계값·난수는 그대로이고 인카운트 판정도 없다(위험도는 층과 상관없이 이어진다). 계단이 아니면 막힘 not_stairs.
## B1F 마을 문(M3 A2)이면 마을로 나간다: 층·칸·방향·걸음·위험도·한계값·난수는 그대로이고 이벤트 to_town.
static func _take_stairs(s: ExplorationState, events: Array[Dictionary], automap: String) -> void:
	if s.defs != null and s.defs.is_gate(s.floor_def, s.party.at):
		s.location = ExplorationState.TOWN
		events.append({"type": "to_town"})
		return
	var st := s.floor_def.stair_at(s.party.at)
	if st == null:
		events.append({"type": "blocked", "reason": "not_stairs"})
		return
	var from := s.floor_def.id
	var target := s.defs.floor_by_id(st.to_floor)
	var t := target.stair_at(st.to_at)
	s.enter_floor(target)
	s.party.at = t.at
	s.party.facing = t.exit
	record_cell(s, t.at, automap)
	events.append({"type": "floor_changed", "from": from, "to": target.id, "at": t.at, "facing": t.exit})


## 마을에서 미궁으로(M3 A2, 아보르 입구 「탐사 시작」): 첫 층의 시작 칸에 서서 시작 방향을 보고 그 칸을 기록한다.
## 새 원정이라 위험도는 0(한계값은 그대로, 난수를 쓰지 않는다). 걸음 그대로. 도착에는 계단 물음이 없다(A1 계단과 같다).
static func _enter(s: ExplorationState, events: Array[Dictionary], automap: String) -> void:
	var f := s.defs.first_floor()
	s.location = ExplorationState.LABYRINTH
	s.enter_floor(f)
	s.party.at = f.start_at
	s.party.facing = f.start_facing
	s.encounter.danger = 0
	record_cell(s, f.start_at, automap)
	events.append({"type": "entered", "floor": f.id, "at": f.start_at, "facing": f.start_facing})


static func _cell_effect(s: ExplorationState, c: Vector2i, events: Array[Dictionary]) -> void:
	if s.floor_def.cell_kind(c) != FloorModel.Cell.DAMAGE:
		return
	var amounts: Array[int] = []
	for m in s.party.members:
		var lost := mini(m.hp, s.floor_def.damage) if m.alive() else 0
		m.hp -= lost
		amounts.append(lost)
	events.append({"type": "damaged", "amounts": amounts})
	if s.party.all_down():
		s.wiped = true
