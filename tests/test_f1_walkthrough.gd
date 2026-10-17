## f1_test 고정 공략(data/floors/f1_test_route.json)을 실제 행동으로 걸어 본다.
## 문·숨은 통로·피해 바닥·일방통행·얼음 퍼즐·지름길을 모두 지난다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const ROUTE_PATH := "res://data/floors/f1_test_route.json"


func _route() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	return d if typeof(d) == TYPE_DICTIONARY else {}


func _count(events: Array[Dictionary], type: String) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type).size()


## 행동열을 걷는다. 전투 대기가 되면 해결하고 이어 간다. 체크포인트 위치를 확인한다.
func _walk(s: ExplorationState, route: Dictionary, seed_label: String) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	var actions: Array = route["actions"]
	var checkpoints: Array = route["checkpoints"]
	var next_cp := 0
	for i in actions.size():
		var action := ExplorationRules.action_from_name(actions[i])
		check(action >= 0, "행동 이름 %s" % actions[i])
		var ev := ExplorationRules.apply(s, action, "full")
		check(_count(ev, "rejected") == 0, "%s: %d번째 행동 거부" % [seed_label, i])
		all.append_array(ev)
		if s.encounter.pending:
			ExplorationRules.resolve_battle(s)
		while next_cp < checkpoints.size() and int(checkpoints[next_cp]["after"]) == i + 1:
			var cp: Dictionary = checkpoints[next_cp]
			var at := Vector2i(int(cp["at"][0]), int(cp["at"][1]))
			check_eq(s.party.at, at, "%s: 체크포인트 「%s」" % [seed_label, cp["note"]])
			next_cp += 1
	check_eq(next_cp, checkpoints.size(), "%s: 체크포인트를 모두 지남" % seed_label)
	return all


func test_route_file_shape() -> void:
	var route := _route()
	check_eq(route.get("floor"), "f1_test", "층 ID")
	check(typeof(route.get("actions")) == TYPE_ARRAY and route["actions"].size() > 50, "행동열")
	check(route["actions"].all(func(a: Variant) -> bool: return typeof(a) == TYPE_STRING and ExplorationRules.action_from_name(a) >= 0), "모든 행동 이름이 올바름")


func test_walkthrough() -> void:
	var f := Fx.f1()
	var route := _route()
	var s := Fx.game(f, 31, "full")
	var ev := _walk(s, route, "시드 31")
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "moved" and e["door"]), "문 통과")
	check_eq(_count(ev, "passage_found"), 2, "숨은 통로 두 곳 찾기")
	check_eq(_count(ev, "shortcut_opened"), 1, "지름길 열기")
	check_eq(_count(ev, "damaged"), 3, "피해 바닥 세 칸")
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "blocked" and e["reason"] == "oneway"), "일방통행 반대 방향 막힘")
	check(ev.any(func(e: Dictionary) -> bool: return e.get("via") == "slide"), "얼음에서 미끄러짐")
	check_eq(s.party.members[0].hp, s.party.members[0].max_hp - 9, "피해 3 × 3")
	check_eq(s.party.at, f.start_at, "고리를 돌아 시작 칸")
	check(not s.wiped, "전멸 없음")
	check_eq(s.world.passages_found.size(), 2, "숨은 통로 기록")
	check_eq(s.world.shortcuts_open.size(), 1, "지름길 기록")
	for c in [Vector2i(2, 4), Vector2i(13, 17), Vector2i(18, 8), Vector2i(12, 14), Vector2i(10, 3)]:
		check(s.knowledge.is_visited(c), "칸 %s 방문(숨은 방·얼음 방·피해 바닥)" % str(c))

	var r := SaveCodec.decode(SaveCodec.encode(s), f, Fx.members())
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "공략 뒤 저장·읽기 해시 같음")
	if r.ok():
		Fx.walk(r.state, "NEEE", "full")
		check_eq(r.state.party.at, Vector2i(5, 17), "읽은 뒤에도 지름길로 바로 나감")


func test_walkthrough_does_not_depend_on_seed() -> void:
	var route := _route()
	for seed_value in [1, 2, 3]:
		var s := Fx.game(Fx.f1(), seed_value, "floor")
		_walk(s, route, "시드 %d" % seed_value)
		check_eq(s.party.at, Fx.f1().start_at, "시드 %d: 시작 칸으로 돌아옴" % seed_value)

