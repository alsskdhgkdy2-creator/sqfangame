## 게임 층 묶음(arbor: B1F~B3F) 고정 공략(data/floors/arbor_route.json)을 실제 행동으로 걸어 본다(M3 A3, 설계 노트 §8.2 R7).
## 상자·계단·열쇠 없이 막힌 잠긴 문·열쇠 상자·문 열기·B3F 관문·봉인 문 앞까지.
## 죽이는 변이: M-R7 B2F 열쇠 상자를 잠긴 문 뒤로 옮기면 공략이 깨진다(층 분석 F6 도 갇힘을 알린다).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const ROUTE_PATH := "res://data/floors/arbor_route.json"


func _route() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _count(events: Array[Dictionary], type: String, reason: String = "") -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type and (reason.is_empty() or e.get("reason") == reason)).size()


## 행동열을 걷는다. 전투 대기가 되면 해결하고 이어 간다. 체크포인트마다 층·위치를 확인한다.
func _walk(s: ExplorationState, route: Dictionary, seed_label: String) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var actions: Array = route["actions"]
	var checkpoints: Array = route["checkpoints"]
	var next_cp := 0
	for i in actions.size():
		var action := ExplorationRules.action_from_name(actions[i])
		check(action >= 0, "행동 이름 %s" % actions[i])
		var ev := ExplorationRules.apply(s, action, "full")
		check(_count(ev, "rejected") == 0, "%s: %d번째 행동 거부 %s" % [seed_label, i, str(ev)])
		all.append_array(ev)
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
		while next_cp < checkpoints.size() and int(checkpoints[next_cp]["after"]) == i + 1:
			var cp: Dictionary = checkpoints[next_cp]
			var at := Vector2i(int(cp["at"][0]), int(cp["at"][1]))
			check_eq([s.floor_def.id, s.party.at], [cp["floor"], at], "%s: 체크포인트 「%s」" % [seed_label, cp["note"]])
			next_cp += 1
	check_eq(next_cp, checkpoints.size(), "%s: 체크포인트를 모두 지남" % seed_label)
	return all


func test_route_file_shape() -> void:
	var route := _route()
	check_eq(route.get("floor"), "b1f", "시작 층 ID")
	check(typeof(route.get("actions")) == TYPE_ARRAY and route["actions"].size() > 100, "행동열")
	check(route["actions"].all(func(a: Variant) -> bool: return typeof(a) == TYPE_STRING and ExplorationRules.action_from_name(a) >= 0), "모든 행동 이름이 올바름")
	var afters: Array = route["checkpoints"].map(func(c: Dictionary) -> int: return int(c["after"]))
	var sorted := afters.duplicate()
	sorted.sort()
	check_eq(afters, sorted, "체크포인트 차례")
	check_eq(afters[-1], route["actions"].size(), "마지막 체크포인트는 행동열 끝")


func test_walkthrough() -> void:
	var defs := Fx.arbor()
	check(defs != null, "arbor 정의")
	if defs == null:
		return
	var s := ExplorationRules.new_game(defs, 31, "full")
	check_eq([s.floor_def.id, s.party.at, s.party.facing], ["b1f", Vector2i(9, 18), Dir.N], "미궁 새 게임: B1F 시작 칸 북쪽")
	var ev := _walk(s, _route(), "시드 31")
	check_eq(_count(ev, "floor_changed"), 2, "계단 두 번(B1F→B2F→B3F)")
	check(_count(ev, "blocked", "locked") >= 1, "B2F 열쇠 없이 잠긴 문에 막힘")
	check_eq(_count(ev, "lock_opened"), 2, "잠긴 문 두 곳을 연다")
	check_eq(Fx.types(ev).slice(-1), ["blocked"] as Array[String], "끝은 막힘")
	check_eq(ev[-1].get("reason"), "sealed", "봉인 문 앞")
	check(_count(ev, "chest_opened") >= 3, "상자 c1·열쇠 둘")
	check_eq(s.key_items, {"key.moss_card": true, "key.relay_fuse": true}, "열쇠 둘")
	var b2: FloorState = s.floor_states["b2f"]
	var b3: FloorState = s.floor_states["b3f"]
	check_eq([b2.world.locks_open.size(), b3.world.locks_open.size()], [1, 1], "층마다 열린 문 하나")
	check(b2.world.is_chest_opened("c1") and b3.world.is_chest_opened("c1"), "열쇠 상자를 열었다")
	check(s.floor_states["b1f"].world.is_chest_opened("c1"), "B1F 입구 상자")
	for e in b3.floor_def.edges_of_kind(FloorModel.Edge.LOCK):
		if b3.floor_def.is_sealed(e):
			check(not b3.world.is_lock_open(e), "봉인은 닫힌 채 %s" % GridKey.edge(e))
	check(not s.wiped, "전멸 없음")
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "공략 뒤 저장·읽기 해시 같음 %s" % r.error)


## 위치·문·상자는 시드와 상관없다(전투는 이겼다고 치고 넘긴다).
func test_walkthrough_does_not_depend_on_seed() -> void:
	var defs := Fx.arbor()
	if defs == null:
		check(false, "arbor 정의")
		return
	for seed_value in [1, 2, 3]:
		var s := ExplorationRules.new_game(defs, seed_value, "floor")
		_walk(s, _route(), "시드 %d" % seed_value)
		check_eq([s.floor_def.id, s.party.at, s.key_items.size()], ["b3f", Vector2i(9, 2), 2], "시드 %d: 봉인 문 앞, 열쇠 둘" % seed_value)
