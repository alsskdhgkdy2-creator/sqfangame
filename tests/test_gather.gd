## 채집 규칙(M3 A5 설계 §4·§7.2): 지점에 멈추면 묻는 gather·다 쓰면 gather_spent, 조사로 다시 묻기, GATHER(횟수 하나 쓰기·수확·공용 가방),
## 가방 가득·일부만, 거부·막힘, 숙소의 날 바뀜으로 되돌리기, 결정성(본 난수를 쓰지 않음), 채집 스킬·습격 갈고리.
## 시험마다 죽이는 변이(M-R…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const MOSS := "item.neon_moss"
const SAP := "item.lumen_sap"
const WIRE := "item.scrap_wire"
const CORE := "item.data_core"
const CRYSTAL := "item.ether_crystal"
const RAT := "item.neon_rat_tail"

## 위 줄: (0,0) 시작, (1,0) 채취 g1(하루 2), (2,0) 절단 g2(하루 1), (3,0) 상자, (4,0) 추출 g3(하루 3), (5,0) 빈 칸.
## (1,0) 아래 숨은 통로 h:1:1.
const GRID := [
	"+-+-+-+-+-+-+",
	"|. . . . . .|",
	"+-+H+-+-+-+-+",
	"|. . . . . .|",
	"+-+-+-+-+-+-+",
]
const POINTS := [
	{"id": "g1", "at": [1, 0], "kind": "take", "uses": 2, "table": "gather.fx.take"},
	{"id": "g2", "at": [2, 0], "kind": "chop", "uses": 1, "table": "gather.fx.chop"},
	{"id": "g3", "at": [4, 0], "kind": "mine", "uses": 3, "table": "gather.fx.mine"},
]
## 시험 표: 채취는 늘 이끼 3 + 수액 1(희귀 1000‰), 절단은 늘 폐배선 1(희귀 없음), 추출은 두 줄·희귀 500‰.
const TABLES := [
	{"id": "gather.fx.take", "kind": "take", "items": [{"item": MOSS, "weight": 1, "count": [3, 3]}], "rare": {"item": SAP, "permille": 1000}},
	{"id": "gather.fx.chop", "kind": "chop", "items": [{"item": WIRE, "weight": 1, "count": [1, 1]}]},
	{"id": "gather.fx.mine", "kind": "mine", "items": [{"item": CRYSTAL, "weight": 50, "count": [1, 2]}, {"item": CORE, "weight": 50, "count": [1, 1]}],
		"rare": {"item": CORE, "permille": 500}},
]

static var _defs: GameDefs


static func defs() -> GameDefs:
	if _defs == null:
		var f := FloorLoader.parse_text(JSON.stringify(Fx.floor_dict(GRID, {"gathering": POINTS, "chests": [{"id": "c", "at": [3, 0], "money": 5}]})),
			"fx.json").floor_def
		f.encounter_table = "encounter.f1_test"
		var db := Fx.battle_db(Fx.battle_files({"gathering/test.json": {"gather_tables": TABLES}}))
		var party := PartyData.read_path(Fx.PARTY_PATH)
		party.resolve(db)
		_defs = GameDefs.assemble([f] as Array[FloorModel], party, db)
		var errs := GameDefs.check_gathering([f] as Array[FloorModel], db)
		assert(errs.is_empty() and db.ok(), str(errs) + str(db.errors))
	return _defs


func _game(seed_value: int = 3) -> ExplorationState:
	return ExplorationRules.new_game(defs(), seed_value, "full")


## (x,0) 까지 동쪽으로 걷는다(시작 (0,0) 동쪽을 본다).
func _to(s: ExplorationState, x: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	while s.party.at.x < x:
		ev = ExplorationRules.apply(s, A.FORWARD, "full")
	return ev


func _do(s: ExplorationState, a: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, a, "full")


func _hash(s: ExplorationState) -> String:
	return SaveCodec.state_hash(s)


func teardown() -> void:
	GatherRules.bonus_hook = Callable()
	super()


## R1 (M-R1a 인카운트 판정보다 먼저 gather, M-R1b 다 쓴 지점에서도 물음): 멈추면 묻고, 조사로 다시 묻고, 다 쓰면 알림만.
func test_point_events() -> void:
	var s := _game()
	var ev := _to(s, 1)
	check_eq(ev[-1], {"type": "gather", "point": "g1", "kind": "take", "left": 2, "uses": 2}, "멈추면 gather(남은 2/2)")
	check_eq(ExplorationRules.question_here(s), {"kind": "gather", "point": "g1"}, "물음: gather")
	check_eq(_do(s, A.INVESTIGATE), [{"type": "gather", "point": "g1", "kind": "take", "left": 2, "uses": 2}] as Array[Dictionary], "조사로 다시 묻기")
	# 바라본 숨은 통로가 먼저다.
	Fx.face(s, Dir.S, "full")
	check_eq(Fx.types(_do(s, A.INVESTIGATE)), ["passage_found"], "바라본 숨은 통로가 먼저")
	check_eq(Fx.types(_do(s, A.INVESTIGATE)), ["gather"], "그다음 조사는 지점")
	Fx.face(s, Dir.E, "full")
	_do(s, A.GATHER)
	_do(s, A.GATHER)
	check_eq(ExplorationRules.question_here(s), {}, "다 쓰면 물음 없음")
	check_eq(_do(s, A.INVESTIGATE), [{"type": "gather_spent", "point": "g1"}] as Array[Dictionary], "조사: 다 씀")
	_do(s, A.FORWARD)
	check_eq(_do(s, A.BACK)[-1], {"type": "gather_spent", "point": "g1"}, "다시 멈추면 gather_spent")
	# 상자 칸은 상자 물음, 빈 칸은 아무것도 없다.
	check_eq(Fx.types(_to(s, 3)), ["moved", "chest"], "상자 칸은 상자")
	check_eq(Fx.types(_do(s, A.FORWARD)), ["moved", "gather"], "추출 지점")
	check_eq(Fx.types(_do(s, A.FORWARD)), ["moved"], "빈 칸")
	check_eq(Fx.types(_do(s, A.INVESTIGATE)), ["nothing_found"], "빈 칸 조사")
	# 인카운트가 나면 물음이 없다(조사가 뒤에 다시 묻는다).
	var e := _game(5)
	e.encounter.danger = e.encounter.threshold - 1
	var ee := _to(e, 1)
	check(e.encounter.pending and Fx.types(ee) == ["moved", "encounter"], "인카운트면 gather 없음 %s" % str(Fx.types(ee)))
	BattleRules.finish(e, "victory")
	check_eq(Fx.types(_do(e, A.INVESTIGATE)), ["gather"], "전투 뒤 조사로 다시 묻기")


## R2 (M-R2a 횟수를 쓰지 않음, M-R2b 희귀 굴림을 건너뜀, M-R2c 개수 범위를 무시하고 1): 받아들인 채집.
func test_gather_accepted() -> void:
	var s := _game()
	_to(s, 1)
	var ev := _do(s, A.GATHER)
	check_eq(ev, [{"type": "gathered", "point": "g1", "kind": "take", "items": [{"item": MOSS, "count": 3, "kept": 3}, {"item": SAP, "count": 1, "kept": 1}],
		"lost": 0, "left": 1, "uses": 2}] as Array[Dictionary], "gathered: 이끼 3·수액 1, 남은 1/2")
	check_eq([s.materials, s.world.gather_used, BagRules.used(s)], [{MOSS: 3, SAP: 1}, {"g1": 1}, 4], "소재·쓴 횟수·가방")
	check_eq(_do(s, A.GATHER)[0]["left"], 0, "두 번째: 남은 0")
	check_eq([s.materials, s.world.gather_used], [{MOSS: 6, SAP: 2}, {"g1": 2}], "두 번째도 더함")
	_to(s, 2)
	check_eq(_do(s, A.GATHER), [{"type": "gathered", "point": "g2", "kind": "chop", "items": [{"item": WIRE, "count": 1, "kept": 1}], "lost": 0,
		"left": 0, "uses": 1}] as Array[Dictionary], "희귀 없는 표")
	# 추출: 두 줄 가운데 하나, 개수는 표 범위 안.
	_to(s, 4)
	for i in 3:
		var g := _do(s, A.GATHER)[0]
		check_eq(g["type"], "gathered", "추출 %d" % i)
		var main: Dictionary = g["items"][0]
		check((main["item"] == CRYSTAL and main["count"] in [1, 2]) or (main["item"] == CORE and main["count"] == 1), "추출 %d 줄·개수 %s" % [i, str(main)])
		check(g["items"].size() <= 2 and (g["items"].size() == 1 or g["items"][1] == {"item": CORE, "count": 1, "kept": 1}), "추출 %d 희귀 %s" % [i, str(g["items"])])


## R3 (M-R3a 가득일 때 횟수를 씀, M-R3b BagRules 를 거치지 않고 더함): 공용 가방 60칸.
func test_bag_full_and_partial() -> void:
	var s := _game()
	_to(s, 1)
	s.materials = {RAT: 60}
	var h := _hash(s)
	check_eq(_do(s, A.GATHER), [{"type": "gather_full", "point": "g1"}] as Array[Dictionary], "60/60: gather_full")
	check_eq([_hash(s), s.world.gather_used], [h, {}], "아무것도 바뀌지 않고 횟수도 그대로")
	s.materials = {RAT: 58}
	var ev := _do(s, A.GATHER)
	check_eq(ev, [{"type": "gathered", "point": "g1", "kind": "take", "items": [{"item": MOSS, "count": 3, "kept": 2}, {"item": SAP, "count": 1, "kept": 0}],
		"lost": 2, "left": 1, "uses": 2}] as Array[Dictionary], "58/60: 이끼 2만, 2개 잃음, 횟수는 씀")
	check_eq([BagRules.used(s), s.materials], [60, {RAT: 58, MOSS: 2}], "60칸에서 멈춘다")
	var kept := 0
	for x in ev[0]["items"]:
		kept += int(x["kept"])
	check(kept >= 1, "받아들이면 적어도 하나")
	# 넘친 옛 저장(75개)도 가득이다.
	s.materials = {RAT: 75}
	h = _hash(s)
	check_eq(Fx.types(_do(s, A.GATHER)), ["gather_full"], "넘친 가방: gather_full")
	check_eq(_hash(s), h, "넘친 가방: 그대로")


## R4 (M-R4 지점 밖 GATHER 가 층의 첫 지점에서 채집): 거부·막힘은 상태를 바꾸지 않는다.
func test_rejections() -> void:
	var s := _game()
	_do(s, A.TURN_LEFT)
	_do(s, A.TURN_RIGHT)
	var h := _hash(s)
	check_eq(_do(s, A.GATHER), [{"type": "blocked", "reason": "not_gather"}] as Array[Dictionary], "지점 밖")
	check_eq(_hash(s), h, "지점 밖: 그대로")
	_to(s, 2)
	_do(s, A.GATHER)
	h = _hash(s)
	check_eq(_do(s, A.GATHER), [{"type": "blocked", "reason": "gather_spent"}] as Array[Dictionary], "다 씀")
	check_eq(_hash(s), h, "다 씀: 그대로")
	var p := _game()
	_to(p, 1)
	p.encounter.danger = p.encounter.threshold
	BattleRules.start(p, BattleRules.pick_formation(p))
	h = _hash(p)
	check_eq(_do(p, A.GATHER), [{"type": "rejected", "reason": "pending"}] as Array[Dictionary], "전투 대기")
	check_eq(_hash(p), h, "전투 대기: 그대로")
	var w := _game()
	_to(w, 1)
	w.wiped = true
	check_eq(_do(w, A.GATHER), [{"type": "rejected", "reason": "wiped"}] as Array[Dictionary], "전멸")
	var t := ExplorationRules.new_game(Fx.arbor(), 3, "full", true)
	check_eq(ExplorationRules.apply(t, A.GATHER, "full"), [{"type": "rejected", "reason": "town"}] as Array[Dictionary], "마을")
	check_eq(ExplorationRules.question_here(t), {}, "마을: 물음 없음")
	check_eq([ExplorationRules.Action.GATHER, ExplorationRules.action_from_name("gather"), ExplorationRules.Action.OPEN], [11, 11, 10], "GATHER 11, OPEN 10 그대로")


## R5 (M-R5a 지금 층만 비움, M-R5b 비콘으로 돌아와도 비움): 숙소 숙박(날 + 1)만 모든 층의 쓴 횟수를 비운다.
func test_new_day_reset() -> void:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 3, "full", true)
	var b2 := defs.floor_by_id("b2f")
	s.enter_floor(b2)
	s.world.gather_used = {"g1": 1, "g3": 2}
	s.enter_floor(defs.first_floor())
	s.world.gather_used = {"g1": 2}
	s.money = 0
	check_eq(Fx.types(TownRules.stay(s)), ["blocked"], "돈이 모자라면 막힘")
	check_eq([s.floor_states["b1f"].world.gather_used, s.floor_states["b2f"].world.gather_used], [{"g1": 2}, {"g1": 1, "g3": 2}], "막히면 그대로")
	s.money = 1000
	check_eq(Fx.types(TownRules.stay(s)), ["stayed"], "숙박")
	check_eq([s.day, s.floor_states["b1f"].world.gather_used, s.floor_states["b2f"].world.gather_used], [2, {}, {}], "모든 층이 비었다")
	# 비콘·계단·저장 왕복은 되돌리지 않는다.
	var g := ExplorationRules.new_game(defs, 3, "full")
	ExplorationRules.apply(g, A.FORWARD, "full")
	ExplorationRules.apply(g, A.STRAFE_LEFT, "full")
	ExplorationRules.apply(g, A.GATHER, "full")
	ExplorationRules.apply(g, A.GATHER, "full")
	check_eq(g.world.gather_used, {"g1": 2}, "B1F g1 두 번")
	var back := SaveCodec.decode(SaveCodec.encode(g), defs).state
	check_eq(back.world.gather_used, {"g1": 2}, "저장 왕복 뒤에도 그대로")
	g.consumables = {"use.ariadne_beacon": 1}
	var ret := ItemRules.use(g, "use.ariadne_beacon", -1)
	check(g.in_town(), "비콘으로 마을 %s" % str(ret))
	check_eq(g.floor_states["b1f"].world.gather_used, {"g1": 2}, "비콘으로 돌아와도 그대로")
	var q := ExplorationRules.apply(g, A.ENTER, "full")
	check_eq(Fx.types(q), ["entered"], "다시 들어감")
	ExplorationRules.apply(g, A.FORWARD, "full")
	check_eq(ExplorationRules.apply(g, A.STRAFE_LEFT, "full")[-1], {"type": "gather_spent", "point": "g1"}, "날이 같으면 다 쓴 채")


## R6 (M-R6a 본 난수에서 뽑음, M-R6b 씨앗에 쓴 횟수를 넣지 않음): 결정성.
func test_determinism() -> void:
	var s := _game(9)
	_to(s, 4)
	var before := [s.rng.get_state(), s.steps, s.encounter.danger, s.encounter.threshold, s.encounter.pending]
	var c := SaveCodec.decode(SaveCodec.encode(s), defs()).state
	var e1 := _do(s, A.GATHER)
	check_eq([s.rng.get_state(), s.steps, s.encounter.danger, s.encounter.threshold, s.encounter.pending], before, "난수·걸음·위험도·한계값·대기 그대로")
	check_eq(_do(c, A.GATHER), e1, "같은 상태 → 같은 수확")
	var p: FloorModel.GatherPoint = s.floor_def.points["g3"]
	check(GatherRules.roll_seed(s, p, 0) != GatherRules.roll_seed(s, p, 1), "쓴 횟수마다 씨앗이 다르다")
	check(GatherRules.roll_seed(s, p, 0) != GatherRules.roll_seed(s, s.floor_def.points["g1"], 0), "지점마다 씨앗이 다르다")
	# 두 지점의 차례를 바꿔도 지점마다 수확이 같다(사이에 전투가 없으면).
	var x := _game(11)
	var y := SaveCodec.decode(SaveCodec.encode(x), defs()).state
	_to(x, 2)
	var x2 := _do(x, A.GATHER)
	_to(x, 4)
	var x4 := _do(x, A.GATHER)
	_to(y, 4)
	var y4 := _do(y, A.GATHER)
	_do(y, A.TURN_LEFT)
	_do(y, A.TURN_LEFT)
	_do(y, A.FORWARD)
	_do(y, A.FORWARD)
	var y2 := _do(y, A.GATHER)
	check_eq([x2, x4], [y2, y4], "차례를 바꿔도 같다")
	# 같은 지점의 여러 번은 씨앗이 달라 굴림이 다르다(추출 두 줄·희귀 500‰ 를 시드 여럿으로 모아 본다).
	var kinds := {}
	for sd in 8:
		var z := _game(20 + sd)
		_to(z, 4)
		for i in 3:
			kinds[str(_do(z, A.GATHER)[0]["items"])] = true
	check(kinds.size() >= 3, "여러 결과가 나온다 %d" % kinds.size())


## R7 (M-R7 스킬 보너스를 무시): 채집 스킬 갈고리는 개수·희귀 확률을 올린다. 습격 갈고리는 지금 늘 없다.
func test_hooks() -> void:
	var s := _game()
	check_eq(GatherRules.skill_bonus(s, "take"), {"count": 0, "rare_permille": 0}, "지금 보너스 0")
	check_eq(GatherRules.ambush(s, s.floor_def.points["g1"]), "", "습격 없음")
	GatherRules.bonus_hook = func(_st: ExplorationState, kind: String) -> Dictionary:
		return {"count": 1, "rare_permille": 1000 if kind == "mine" else 0}
	_to(s, 2)
	check_eq(_do(s, A.GATHER)[0]["items"], [{"item": WIRE, "count": 2, "kept": 2}], "절단: 개수 +1, 희귀 없는 표는 그대로")
	_to(s, 4)
	for i in 3:
		var items: Array = _do(s, A.GATHER)[0]["items"]
		check(items.size() == 2 and items[1]["item"] == CORE, "추출 %d: 보너스로 늘 희귀 %s" % [i, str(items)])
		check(items[0]["count"] >= 2, "추출 %d: 개수 +1 %s" % [i, str(items)])
	check(not s.encounter.pending and s.battle == null, "채집은 전투를 열지 않는다")
