extends TestCase
## 소모품 규칙(M3 A4 설계 §5.1·§5.3·§5.4): 캠프에서 쓰기(모자란 만큼만, 거부는 물건을 남긴다, 0 이면 키를 지운다),
## 귀환 비콘(마을 거부·no_return 갈고리·옮긴 뒤 상태 전체 비교·마을 불변식 저장), 버리기(소모품·가방 장비·소재, 귀중품·낀 장비는 안 된다).
## 거부는 rejected 하나이고 정규화 상태가 그대로다. 시험마다 죽이는 변이(설계 §8.1, M-I…)를 적는다.

const Fx := preload("res://tests/fixtures.gd")
const ROUTE_PATH := "res://data/floors/arbor_route.json"

const MEDICA := "use.medica"
const AMRITA := "use.amrita"
const NECTAR := "use.nectar"
const THERIACA_A := "use.theriaca_a"
const BEACON := "use.ariadne_beacon"
const RAT := "item.neon_rat_tail"
const TWIN := "equip.twin_edge"
const MOSS := "key.moss_card"


func _game() -> ExplorationState:
	return ExplorationRules.new_game(Fx.defs(), 3, "floor")


## 게임 층 묶음에서 공략 행동 n 개 뒤(전투는 이긴 것으로).
func _arbor(n: int) -> ExplorationState:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	var s := ExplorationRules.new_game(Fx.arbor(), 31, "full")
	for i in n:
		ExplorationRules.apply(s, ExplorationRules.action_from_name(route["actions"][i]), "full")
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
	return s


func _busy_states() -> Array:
	var battle := Fx.battle(Fx.defs(), "formation.f1.rats")
	var pending := _game()
	pending.encounter.danger = pending.encounter.threshold
	pending.encounter.pending = true
	var wiped := _game()
	for m in wiped.party.members:
		m.hp = 0
	wiped.wiped = true
	return [["전투 중", battle], ["전투 대기", pending], ["전멸", wiped]]


## 거부 하나이고 정규화 상태(소모품·가방·대원 포함)가 그대로인지.
func _rejected(label: String, s: ExplorationState, act: Callable, reason: String) -> void:
	var before := SaveCodec.canonical_state(s)
	var ev: Array[Dictionary] = act.call()
	check(ev.size() == 1 and ev[0] == {"type": "rejected", "reason": reason}, "%s: rejected{%s} 기대, 실제 %s" % [label, reason, str(ev)])
	check_eq(SaveCodec.canonical_state(s), before, "%s: 정규화 상태 그대로" % label)


# ---- 캠프에서 쓰기 ----

## M-I1(회복을 자르지 않음)·M-I7(0 이 되어도 키를 남김).
func test_heal_and_tp_restore_only_what_is_missing() -> void:
	var s := _game()
	var m := s.party.members[1]
	s.consumables = {MEDICA: 2, AMRITA: 1}
	m.hp = m.max_hp - 10
	check_eq(ItemRules.use_block(s, MEDICA, 1), "", "use_block: 쓸 수 있다")
	check_eq(ItemRules.use(s, MEDICA, 1), [{"type": "used", "item": MEDICA, "member": 1, "left": 1},
		{"type": "healed", "member": 1, "amount": 10, "hp": m.max_hp}] as Array[Dictionary], "메디카: 모자란 10 만")
	check(m.max_hp > 51, "준비: 최대 HP %d > 51" % m.max_hp)
	m.hp = 1
	check_eq(ItemRules.use(s, MEDICA, 1)[1], {"type": "healed", "member": 1, "amount": 50, "hp": 51}, "메디카: 50")
	check_eq(s.consumables, {AMRITA: 1}, "다 쓴 메디카는 키를 지운다")
	m.tp = m.max_tp - 5
	check_eq(ItemRules.use(s, AMRITA, 1), [{"type": "used", "item": AMRITA, "member": 1, "left": 0},
		{"type": "tp_restored", "member": 1, "amount": 5, "tp": m.max_tp}] as Array[Dictionary], "아므리타: 모자란 5 만")
	check_eq(s.consumables, {}, "0 이면 키가 없다")


## M-I2(hp_full 검사를 없앰): 거부 갈래마다 하나, 물건은 남는다.
func test_use_rejections_keep_the_item() -> void:
	for x in _busy_states():
		var b: ExplorationState = x[1]
		b.consumables = {MEDICA: 1}
		_rejected("not_now: %s" % x[0], b, func(): return ItemRules.use(b, MEDICA, 0), "not_now")
		_rejected("not_now 가 물건보다 먼저: %s" % x[0], b, func(): return ItemRules.use(b, "use.nope", 0), "not_now")
	var s := _game()
	s.consumables = {MEDICA: 1, AMRITA: 1, NECTAR: 1, THERIACA_A: 1}
	s.party.members[1].hp -= 5
	s.party.members[3].hp = 0
	_rejected("unknown_item", s, func(): return ItemRules.use(s, "use.nope", 1), "unknown_item")
	_rejected("unknown_item: 소재", s, func(): return ItemRules.use(s, RAT, 1), "unknown_item")
	_rejected("not_owned", s, func(): return ItemRules.use(s, BEACON, -1), "not_owned")
	_rejected("battle_only", s, func(): return ItemRules.use(s, THERIACA_A, 1), "battle_only")
	_rejected("bad_member -1", s, func(): return ItemRules.use(s, MEDICA, -1), "bad_member")
	_rejected("bad_member 5", s, func(): return ItemRules.use(s, MEDICA, 5), "bad_member")
	_rejected("down: 메디카", s, func(): return ItemRules.use(s, MEDICA, 3), "down")
	_rejected("down: 아므리타", s, func(): return ItemRules.use(s, AMRITA, 3), "down")
	_rejected("not_down: 넥타", s, func(): return ItemRules.use(s, NECTAR, 1), "not_down")
	_rejected("hp_full", s, func(): return ItemRules.use(s, MEDICA, 0), "hp_full")
	_rejected("tp_full", s, func(): return ItemRules.use(s, AMRITA, 0), "tp_full")
	check_eq([ItemRules.use_block(s, MEDICA, 0), ItemRules.use_block(s, MEDICA, 1), ItemRules.use_block(s, NECTAR, 3)], ["hp_full", "", ""], "use_block 은 use 와 같은 판정")


func test_revive_sets_permille_hp_with_minimum_one() -> void:
	var s := _game()
	s.consumables = {NECTAR: 2}
	var m := s.party.members[3]
	m.hp = 0
	m.tp = 3
	check_eq(ItemRules.use(s, NECTAR, 3), [{"type": "used", "item": NECTAR, "member": 3, "left": 1},
		{"type": "revived", "member": 3, "hp": BattleCalc.mul(m.max_hp, 100)}] as Array[Dictionary], "넥타: 최대 HP 의 100‰")
	check(m.alive() and m.tp == 3, "되살아나고 TP 는 그대로")
	var w := s.party.members[4]
	w.max_hp = 5
	w.hp = 0
	check_eq(ItemRules.use(s, NECTAR, 4)[1], {"type": "revived", "member": 4, "hp": 1}, "5 의 100‰ = 0 → 최소 1")


# ---- 귀환 비콘 ----

## M-I5(마을에서도 쓴다)·M-I6(no_return 을 보지 않음).
func test_beacon_refused_in_town_and_on_sealed_cells() -> void:
	var t := _arbor(124)
	t.consumables = {BEACON: 1}
	var first := t.defs.first_floor()
	t.enter_floor(first)
	t.party.at = first.start_at
	t.party.facing = first.start_facing
	t.location = ExplorationState.TOWN
	check_eq(ItemRules.return_block(t), "town", "return_block: 마을")
	_rejected("마을에서 비콘", t, func(): return ItemRules.use(t, BEACON, -1), "town")
	var s := _arbor(60)
	s.consumables = {BEACON: 1}
	check_eq([s.location, ItemRules.return_block(s)], [ExplorationState.LABYRINTH, ""], "준비: 미궁, 막힘 없음")
	s.floor_def.no_return[s.party.at] = true
	check_eq(ItemRules.return_block(s), "sealed", "return_block: 막힌 칸")
	_rejected("막힌 칸에서 비콘", s, func(): return ItemRules.use(s, BEACON, -1), "sealed")
	s.floor_def.no_return.erase(s.party.at)
	check(s.floor_def.no_return.is_empty(), "공유 층 정의를 되돌렸다")


## M-I3(첫 층으로 들어가지 않음)·M-I4(위험도를 0 으로): 옮긴 뒤 상태 전체를 비교한다. 마을 불변식으로 저장·읽기.
func test_beacon_returns_to_town_and_keeps_everything_else() -> void:
	var s := _arbor(124)
	check(s.floor_def.id != "b1f" and s.location == ExplorationState.LABYRINTH, "준비: B1F 밖의 미궁(%s)" % s.floor_def.id)
	s.consumables = {BEACON: 2, MEDICA: 1}
	s.encounter.danger = 37
	s.day = 4
	var before := SaveCodec.state_to_dict(s)
	var rng_before := str(s.rng.get_state())
	var ev := ItemRules.use(s, BEACON, -1)
	check_eq(ev, [{"type": "used", "item": BEACON, "member": -1, "left": 1}, {"type": "returned"}] as Array[Dictionary], "used(대원 -1)·returned")
	var first := s.defs.first_floor()
	check_eq([s.location, s.floor_def.id, s.party.at, s.party.facing], [ExplorationState.TOWN, first.id, first.start_at, first.start_facing], "마을: 첫 층 시작 칸·방향")
	var after := SaveCodec.state_to_dict(s)
	check_eq(after["consumables"], {BEACON: 1, MEDICA: 1}, "비콘 하나만 줄었다")
	check_eq([s.encounter.danger, after["encounter"]["threshold"], str(s.rng.get_state()), s.steps, s.day], [37, before["encounter"]["threshold"], rng_before, before["steps"], 4],
		"위험도·한계값·난수·걸음·날 그대로")
	for k in before:
		if k in ["floor", "party", "location", "consumables"]:
			continue
		check_eq(after[k], before[k], "%s 그대로" % k)
	check_eq(after["party"]["members"], before["party"]["members"], "대원 그대로")
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok() and r.state.in_town(), "마을 불변식으로 저장·읽기 %s" % r.error)
	_rejected("돌아온 뒤 마을에서 다시", s, func(): return ItemRules.use(s, BEACON, -1), "town")


# ---- 버리기 ----

## M-I8(가진 수보다 많이 버림)·M-I9(귀중품을 버림)·M-I10(낀 장비를 버림).
func test_discard_every_bag_kind_but_not_keys_or_equipped() -> void:
	var s := _game()
	s.consumables = {MEDICA: 3}
	s.gear_bag = {TWIN: 2}
	s.materials = {RAT: 9999}
	s.key_items = {MOSS: true}
	check_eq(ItemRules.discard(s, MEDICA, 2), [{"type": "discarded", "item": MEDICA, "qty": 2, "left": 1}] as Array[Dictionary], "소모품 2")
	check_eq(ItemRules.discard(s, TWIN, 2.0), [{"type": "discarded", "item": TWIN, "qty": 2, "left": 0}] as Array[Dictionary], "가방 장비 2(정수와 같은 실수)")
	check_eq(ItemRules.discard(s, RAT, 9999)[0]["left"], 0, "소재 9,999(옛 저장의 큰 수도 한 번에)")
	check_eq([s.consumables, s.gear_bag, s.materials, BagRules.used(s)], [{MEDICA: 1}, {}, {}, 1], "버린 만큼 칸이 빈다, 0 이면 키를 지운다")
	_rejected("not_owned: 가진 수보다 많이", s, func(): return ItemRules.discard(s, MEDICA, 2), "not_owned")
	_rejected("key_item", s, func(): return ItemRules.discard(s, MOSS, 1), "key_item")
	var equipped: String = s.party.members[0].equip[2]
	_rejected("낀 장비(가방에 없음)", s, func(): return ItemRules.discard(s, equipped, 1), "not_owned")
	check_eq(s.party.members[0].equip[2], equipped, "낀 장비 그대로")
	for bad in [0, 10000, 1.5, true, "1", null]:
		_rejected("bad_amount %s" % str(bad), s, func(): return ItemRules.discard(s, MEDICA, bad), "bad_amount")
	for bad in ["use.nope", "x", 5, null]:
		_rejected("unknown_item %s" % str(bad), s, func(): return ItemRules.discard(s, bad, 1), "unknown_item")
	_rejected("key_item 이 수보다 먼저", s, func(): return ItemRules.discard(s, MOSS, 0), "key_item")
	for x in _busy_states():
		var b: ExplorationState = x[1]
		b.consumables = {MEDICA: 1}
		_rejected("not_now: %s" % x[0], b, func(): return ItemRules.discard(b, MEDICA, 1), "not_now")
