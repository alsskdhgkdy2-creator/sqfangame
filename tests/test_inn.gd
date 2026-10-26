## 숙소(M3 A2b) 규칙: 숙박비(10 × 대원 최고 레벨), 숙박(HP·TP 가득·쓰러진 대원 일어남·날 +1·new_day·소지금 − 값), 막힘(돈·날 끝)·거부(미궁).
## 시험마다 이름 붙은 변이(설계 노트 §7.4, M…)를 죽이는지 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")

static var _real: GameDefs
var _days := 0


func _defs() -> GameDefs:
	if _real == null:
		var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", TextDb.load_path("res://data/text/ko.json"))
		check(r.ok(), "실제 묶음 읽기 %s" % str(r.errors))
		_real = r.defs
	return _real


func _town() -> ExplorationState:
	return ExplorationRules.new_game(_defs(), 5, "full", true)


## new_day 를 세는 시험 갈고리(시험마다 처음에 건다, teardown 이 걷는다).
func _hook() -> void:
	_days = 0
	TownRules.new_day_hook = func() -> void: _days += 1


func teardown() -> void:
	TownRules.new_day_hook = Callable()


## I1 (Mc2 값을 대원 0 의 레벨로): 숙박비 = 10 × 대원 가운데 가장 높은 레벨(쓰러진 대원도 센다).
func test_inn_price_follows_the_top_level() -> void:
	var s := _town()
	check_eq(TownRules.inn_price(s), 10, "모두 Lv 1 → 10엔")
	s.party.members[2].level = 3
	check_eq(TownRules.inn_price(s), 30, "가장 높은 Lv 3(대원 2) → 30엔")
	s.party.members[0].level = 2
	check_eq(TownRules.inn_price(s), 30, "대원 0 이 Lv 2 여도 가장 높은 레벨")
	s.party.members[4].level = 7
	s.party.members[4].hp = 0
	check_eq(TownRules.inn_price(s), 70, "쓰러진 대원의 레벨도 센다")


## I2 (Md2 쓰러진 대원은 일어나지 않음, Me2 날이 오르지 않음): 숙박 = HP·TP 가득(쓰러진 대원도), 날 +1, 소지금 − 값, new_day 한 번.
## 위치·방향·층·위험도·한계값·걸음·난수는 그대로.
func test_stay_restores_everyone_and_advances_the_day() -> void:
	_hook()
	var s := _town()
	s.party.members[0].hp = 0
	s.party.members[1].hp = 3
	s.party.members[1].tp = 0
	s.party.members[4].tp = 7
	s.party.members[3].level = 2
	s.party.members[3].exp = 30  # 레벨 2 의 경험치 범위(저장 검사)
	s.encounter.danger = 40
	var money := s.money
	var keep := [s.party.at, s.party.facing, s.floor_def.id, s.encounter.danger, s.encounter.threshold, s.steps, SaveCodec.state_to_dict(s)["rng"]]
	var ev := TownRules.stay(s)
	check_eq(ev, [{"type": "stayed", "price": 20, "day": 2}] as Array[Dictionary], "stayed 이벤트(값 20, 2일째)")
	check(s.party.members.all(func(m: PartyState.Member) -> bool: return m.hp == m.max_hp and m.tp == m.max_tp), "모두 HP·TP 가득")
	check(s.party.members[0].alive(), "쓰러진 대원도 일어난다")
	check_eq([s.day, s.money, _days], [2, money - 20, 1], "날 +1, 소지금 − 값, new_day 한 번")
	check_eq([s.party.at, s.party.facing, s.floor_def.id, s.encounter.danger, s.encounter.threshold, s.steps, SaveCodec.state_to_dict(s)["rng"]], keep,
		"위치·방향·층·위험도·한계값·걸음·난수 그대로")
	check(s.in_town(), "마을 그대로")
	var r := SaveCodec.decode(SaveCodec.encode(s), _defs())
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s) and r.state.day == 2, "저장 → 읽기 같은 해시(2일째) %s" % r.error)
	TownRules.stay(s)
	check_eq([s.day, s.money, _days], [3, money - 40, 2], "또 묵으면 3일째")


## I3 (Mf2 막혀도 돈을 가져감): 돈이 모자라면 blocked no_money, 날이 끝(99999)이면 blocked day_max — 상태·new_day 그대로. 값과 같으면 0 이 된다.
## 미궁에서는 rejected not_town.
func test_refused_stay_changes_nothing() -> void:
	_hook()
	var s := _town()
	s.party.members[0].hp = 1
	s.money = 9
	var h := SaveCodec.state_hash(s)
	check_eq(TownRules.stay(s), [{"type": "blocked", "reason": "no_money"}] as Array[Dictionary], "9엔 < 10엔: no_money")
	check_eq([SaveCodec.state_hash(s), _days], [h, 0], "막히면 상태 그대로, new_day 없음")
	s.money = 500
	s.day = ExplorationState.DAY_MAX
	h = SaveCodec.state_hash(s)
	check_eq(TownRules.stay(s), [{"type": "blocked", "reason": "day_max"}] as Array[Dictionary], "99999일째: day_max")
	check_eq([SaveCodec.state_hash(s), s.money, s.party.members[0].hp, _days], [h, 500, 1, 0], "날 끝에서 막히면 돈·HP 그대로")
	s.day = ExplorationState.DAY_MAX - 1
	s.money = 10
	check_eq(TownRules.stay(s)[0]["type"], "stayed", "99998일째·값과 같은 돈이면 묵는다")
	check_eq([s.day, s.money], [ExplorationState.DAY_MAX, 0], "99999일째, 0엔")
	var lab := ExplorationRules.new_game(_defs(), 5, "full")
	lab.party.members[0].hp = 1
	h = SaveCodec.state_hash(lab)
	check_eq(TownRules.stay(lab), [{"type": "rejected", "reason": "not_town"}] as Array[Dictionary], "미궁: not_town")
	check_eq(SaveCodec.state_hash(lab), h, "미궁 상태 그대로")
