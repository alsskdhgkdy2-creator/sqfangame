extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const OPS := 260
const GAME_SEED := 2024


## 시드로 정한 조작 열: 규칙 행동(전진 많이), 자동 기록 설정 바꾸기, 지도 편집.
func _ops(seed_value: int) -> Array:
	var r := GameRng.new(seed_value)
	var out := []
	for i in OPS:
		var roll := r.randi_range(0, 99)
		if roll < 6:
			out.append(["automap", ExplorationRules.AUTOMAP_MODES[r.randi_range(0, 2)]])
		elif roll < 16:
			out.append(["edit", r.randi_range(0, 5), r.randi_range(1, 4)])
		elif roll < 60:
			out.append(["act", A.FORWARD])
		else:
			out.append(["act", r.randi_range(0, 6)])
	return out


## 조작 열을 실행한다. reload_at 번째 조작 앞에서 저장·읽기를 끼운다(store 가 있으면 슬롯 파일로).
func _run(ops: Array, reload_at: int = -1, store: SaveStore = null) -> Dictionary:
	var s := Fx.game(Fx.f1(), GAME_SEED, "floor")
	var automap := "floor"
	var log: Array[String] = []
	for i in ops.size():
		if i == reload_at:
			s = _reload(s, store)
			if s == null:
				return {}
		var op: Array = ops[i]
		match op[0]:
			"automap":
				automap = op[1]
			"edit":
				_edit(s, op[1], op[2])
			_:
				for e in ExplorationRules.apply(s, op[1], automap):
					log.append(var_to_str(e))
				if s.encounter.pending:
					ExplorationRules.resolve_battle(s)
					log.append("battle_resolved")
	return {"log": log, "hash": SaveCodec.state_hash(s), "steps": s.steps, "visited": s.knowledge.visited.size()}


func _reload(s: ExplorationState, store: SaveStore) -> ExplorationState:
	if store == null:
		var r := SaveCodec.decode(SaveCodec.encode(s), Fx.f1(), Fx.members())
		check(r.ok(), "중간 읽기 %s" % r.error)
		return r.state
	check_eq(store.save("auto", s), "", "중간 저장")
	var l := store.load_slot("auto")
	check(l.ok(), "중간 슬롯 읽기")
	return l.result.state if l.ok() else null


## 파티 주변 지도 편집. 실행 취소는 같은 조작 안에서만 쓴다(실행 취소 기록은 저장하지 않으므로).
func _edit(s: ExplorationState, kind: int, n: int) -> void:
	var m := s.annotation
	var at := s.party.at
	match kind:
		0:
			m.paint_floor(at, n)
		1:
			m.toggle_edge(FloorModel.edge_of(at, s.party.facing), "wall" if n % 2 == 0 else "door")
		2:
			m.set_icon(at, "arrow" if n == 1 else MapAnnotation.ICONS[n], Dir.E)
		3:
			m.set_memo(at, "메모 %d" % n)
		4:
			m.begin_stroke()
			for d in 4:
				m.paint_floor(at + Dir.vec(d), n)
			m.end_stroke()
		_:
			m.erase_cell(at)
			m.paint_floor(at, n)
			m.undo()


func test_same_seed_same_events_and_hash() -> void:
	var ops := _ops(11)
	var acts := ops.filter(func(o: Array) -> bool: return o[0] == "act").size()
	check(acts >= 200, "규칙 행동 200개 이상 (%d)" % acts)
	check(ops.any(func(o: Array) -> bool: return o[0] == "automap") and ops.any(func(o: Array) -> bool: return o[0] == "edit"), "설정 바꾸기·지도 편집 포함")
	var a := _run(ops)
	var b := _run(ops)
	check_eq(b["log"], a["log"], "같은 이벤트 열")
	check_eq(b["hash"], a["hash"], "같은 최종 해시")
	check(a["steps"] > 50 and a["visited"] > 10, "실제로 돌아다님 (걸음 %d, 방문 %d)" % [a["steps"], a["visited"]])
	check(_run(_ops(12))["hash"] != a["hash"], "다른 조작 열은 다른 해시")


func test_reload_in_middle_keeps_hash() -> void:
	var ops := _ops(11)
	var straight := _run(ops)
	var codec := _run(ops, 130)
	check_eq(codec["hash"], straight["hash"], "중간 저장·읽기(변환) 뒤 같은 최종 해시")
	check_eq(codec["log"], straight["log"], "중간 저장·읽기 뒤 같은 이벤트 열")
	Fx.clean_saves()
	var slot := _run(ops, 70, SaveStore.new(Fx.f1(), Fx.members(), Fx.SAVE_DIR))
	check_eq(slot.get("hash"), straight["hash"], "중간 슬롯 저장·읽기 뒤 같은 최종 해시")
	Fx.clean_saves()
