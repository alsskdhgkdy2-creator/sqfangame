extends TestCase
## 공용 가방 60칸(D31, M3 A4 설계 §3): 세기(소모품·가방 장비·소재 한 개 = 한 칸, 귀중품·낀 장비는 세지 않는다)·빈 칸·fit·add,
## 얻는 길마다(전투 드롭·보물상자·상점 사기·장비 빼기·바꾸기·임시 보급) 60칸에서 멈춤, 넘친 옛 가방은 0 칸, 가방이 차도 드롭 난수는 같다.
## 시험마다 죽이는 변이(설계 §8.1, M-G…)를 적는다. M-G12(저장 읽기의 합계 검사)는 test_save_v8.gd 가 죽인다.

const Fx := preload("res://tests/fixtures.gd")
const Chests := preload("res://tests/test_chests.gd")

const RAT := "item.neon_rat_tail"
const TWIN := "equip.twin_edge"
const MEDICA := "use.medica"
const MOSS := "key.moss_card"
const JUNK := "shop.junk_workshop"


func _game() -> ExplorationState:
	return ExplorationRules.new_game(Fx.defs(), 3, "floor")


## 드롭이 확률 chance(천분율)인 시험 적 셋(앞줄)과 그 편성.
func _drop_defs(chance: int) -> GameDefs:
	var dropper := Fx.enemy("enemy.t_dropper", 999, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]], {"drops": [{"item": RAT, "chance": chance}]})
	return Fx.battle_defs(Fx.test_files([], [dropper], {"d3": [["enemy.t_dropper", "front"], ["enemy.t_dropper", "front"], ["enemy.t_dropper", "front"]]}), Fx.EXACT)


## 적 셋을 HP 1 로 두고 앞 세 대원이 하나씩 쳐서 이 턴에 이긴다. 그 턴의 이벤트.
func _kill_all(s: ExplorationState) -> Array[Dictionary]:
	for e in s.battle.enemies:
		e.hp = 1
	return BattleRules.submit(s, Fx.cmds(s, {0: Fx.atk(0), 1: Fx.atk(1), 2: Fx.atk(2)}))


# ---- 세기 ----

## M-G1(소재를 세지 않음)·M-G10(귀중품을 셈)·M-G11(낀 장비를 셈).
func test_used_counts_each_kind_per_item_but_not_keys_or_equipped() -> void:
	var s := _game()
	check_eq([BagRules.used(s), BagRules.free_slots(s)], [0, 60], "새 게임: 대원이 장비를 끼고 있어도 0칸(낀 장비는 세지 않는다)")
	check(s.party.members[0].equip.any(func(id: String) -> bool: return not id.is_empty()), "준비: 낀 장비가 있다")
	s.consumables = {MEDICA: 2, "use.amrita": 1}
	s.gear_bag = {TWIN: 3}
	s.materials = {RAT: 5, "item.glow_scale": 4}
	check_eq([BagRules.used(s), BagRules.free_slots(s)], [15, 45], "소모품 3 + 장비 3 + 소재 9 = 15")
	s.key_items = {MOSS: true, "key.relay_fuse": true}
	check_eq(BagRules.used(s), 15, "귀중품은 세지 않는다")
	check_eq([BagRules.store(s, MEDICA) == s.consumables, BagRules.store(s, TWIN) == s.gear_bag, BagRules.store(s, RAT) == s.materials, BagRules.store(s, MOSS)],
		[true, true, true, null], "store: use.·equip.·item. 은 제 묶음, 그 밖은 null")
	check_eq([BagRules.kind_cap(MEDICA), BagRules.kind_cap(TWIN), BagRules.kind_cap(RAT), BagRules.kind_cap("x")], [99, 99, 9999, 0], "종류 상한")
	check_eq([BagRules.known(s, MEDICA), BagRules.known(s, TWIN), BagRules.known(s, RAT), BagRules.known(s, MOSS), BagRules.known(s, "use.nope")],
		[true, true, true, false, false], "known: 가방 물건만")


## M-G2(fit 이 빈 칸을 보지 않음)·M-G13(빈 칸이 음수가 됨).
func test_fit_and_add_stop_at_free_slots_and_over_capacity_is_zero() -> void:
	var s := _game()
	s.materials = {RAT: 58}
	check_eq([BagRules.fit(s, RAT, 5), BagRules.fit(s, MEDICA, 1), BagRules.fit(s, TWIN, 2), BagRules.fit(s, TWIN, 0)], [2, 1, 2, 0], "58칸: 둘까지")
	check_eq([BagRules.fit(s, MOSS, 3), BagRules.fit(s, "equip.nope", 1), BagRules.fit(s, "key.nope", 1)], [3, 0, 0], "귀중품은 세지 않고 모르는 ID 는 0")
	check_eq(BagRules.add(s, MEDICA, 5), 2, "add 는 들어간 수")
	check_eq([s.consumables, BagRules.used(s), BagRules.free_slots(s)], [{MEDICA: 2}, 60, 0], "딱 60")
	check_eq([BagRules.add(s, RAT, 1), BagRules.add(s, MOSS, 1), s.materials[RAT], s.key_items], [0, 0, 58, {}], "가득: 하나도 들지 않고, add 는 귀중품을 넣지 않는다")
	s.materials = {RAT: 70}
	check_eq([BagRules.used(s), BagRules.free_slots(s), BagRules.fit(s, MEDICA, 5), BagRules.fit(s, RAT, 1)], [72, 0, 0, 0], "넘친 가방: 빈 칸 0(음수가 아니다), 어느 것도 0")


# ---- 전투 드롭 ----

## M-G4(뒤 드롭을 남기고 앞 드롭을 버림): 58칸에 셋이 떨어지면 앞 둘(적 칸 차례)만 들고 셋째는 amount 0·capped.
func test_drops_fill_in_order_and_later_ones_are_lost() -> void:
	var s := Fx.battle(_drop_defs(1000), "formation.t.d3")
	s.materials = {RAT: 50}
	s.gear_bag = {TWIN: 8}
	var ev := _kill_all(s)
	var d := Fx.of_type(ev, "drop")
	check_eq(d.map(func(e): return [e["enemy"], e["amount"], e["capped"]]), [[0, 1, false], [1, 1, false], [2, 0, true]], "앞 둘은 들고 셋째는 버린다")
	check_eq([s.materials[RAT], BagRules.used(s)], [52, 60], "가방 60")
	check_eq(Fx.of_type(ev, "battle_end")[0]["drops"].map(func(e): return e["capped"]), [false, false, true], "끝 이벤트의 드롭에도 capped(결과 창의 「가방이 가득하다」 근거)")


## M-G3(가방이 차면 드롭 난수를 뽑지 않음): 60칸 가방과 빈 가방이 같은 승리를 끝내면 난수 상태·한계값·드롭 판정이 같다.
func test_drops_roll_the_same_rng_when_the_bag_is_full() -> void:
	var defs := _drop_defs(500)
	var full := Fx.battle(defs, "formation.t.d3", 7)
	var empty := Fx.battle(defs, "formation.t.d3", 7)
	full.materials = {RAT: 60}
	var a := _kill_all(full)
	var b := _kill_all(empty)
	check(Fx.of_type(a, "battle_end").size() == 1 and Fx.of_type(b, "battle_end").size() == 1, "준비: 둘 다 이 턴에 끝난다")
	check(Fx.of_type(b, "drop").size() >= 1, "준비: 빈 가방 쪽에 드롭이 있다(%d)" % Fx.of_type(b, "drop").size())
	check_eq(Fx.of_type(a, "drop").map(func(e): return e["enemy"]), Fx.of_type(b, "drop").map(func(e): return e["enemy"]), "같은 적이 떨어뜨린다")
	check_eq(Fx.of_type(a, "drop").map(func(e): return e["amount"]), Fx.of_type(a, "drop").map(func(_e): return 0), "가득한 쪽은 하나도 들지 않는다")
	check_eq([str(full.rng.get_state()), full.encounter.threshold], [str(empty.rng.get_state()), empty.encounter.threshold], "같은 난수 상태·한계값")


# ---- 보물상자 ----

## M-G5(상자가 일부만 꺼냄): 소재 3 상자는 58칸에서 닫힌 채·상태 그대로, 열쇠 상자는 60/60 에서도 연다.
func test_chest_takes_all_or_nothing_and_key_chest_opens_when_full() -> void:
	var s := Fx.game(Chests.floor_def(), 3, "full")
	s.materials = {RAT: 50}
	s.consumables = {MEDICA: 8}
	s.party.at = Vector2i(1, 0)
	var before := SaveCodec.state_hash(s)
	check_eq(ExplorationRules.apply(s, ExplorationRules.Action.OPEN, "full"), [{"type": "chest_full", "chest": "m", "item": RAT}] as Array[Dictionary], "58 + 3: chest_full")
	check_eq([SaveCodec.state_hash(s), s.materials[RAT]], [before, 50], "일부도 꺼내지 않는다")
	s.consumables = {MEDICA: 10}
	s.party.at = Vector2i(4, 0)
	check_eq(ExplorationRules.apply(s, ExplorationRules.Action.OPEN, "full")[0]["type"], "chest_opened", "60/60 에서도 열쇠 상자는 연다")
	check_eq([s.key_items, BagRules.used(s)], [{MOSS: true}, 60], "열쇠는 칸을 쓰지 않는다")


# ---- 상점 ----

## M-G8(상점 사기가 빈 칸을 보지 않음).
func test_shop_buy_needs_room_for_every_piece() -> void:
	var s := _game()
	s.money = 10000
	s.materials = {RAT: 57}
	var before := SaveCodec.canonical_state(s)
	check_eq(ShopRules.buy(s, JUNK, MEDICA, 4), [{"type": "rejected", "reason": "bag_full"}] as Array[Dictionary], "57 + 4: bag_full")
	check_eq(SaveCodec.canonical_state(s), before, "거부는 상태 그대로")
	check_eq(ShopRules.buy(s, JUNK, MEDICA, 3)[0]["type"], "bought", "57 + 3 = 60 은 받는다")
	check_eq(ShopRules.buy(s, JUNK, TWIN, 1), [{"type": "rejected", "reason": "bag_full"}] as Array[Dictionary], "60 + 장비 1: bag_full")


# ---- 장비 ----

## M-G6(60/60 에서 빼기를 받음)·M-G7(60/60 에서 바꾸기를 거부): 빼기는 한 칸이 있어야 하고, 바꾸기는 칸 수가 그대로라 받는다.
## 빈 칸에 끼면 한 칸이 빈다.
func test_equip_at_full_bag() -> void:
	var s := _game()
	s.materials = {RAT: 59}
	s.gear_bag = {"equip.medic_coat": 1}
	check_eq(s.party.members[0].equip[2], "equip.padded_coat", "준비: 홀로나이트 칸 2 = 패디드 코트")
	var before := SaveCodec.canonical_state(s)
	check_eq(GrowthRules.equip(s, 0, 2, ""), [{"type": "rejected", "reason": "bag_full"}] as Array[Dictionary], "60/60 빼기: bag_full")
	check_eq(SaveCodec.canonical_state(s), before, "거부는 상태 그대로")
	check_eq(GrowthRules.equip(s, 0, 2, "equip.medic_coat")[0]["type"], "equipped", "60/60 바꾸기는 받는다")
	check_eq([s.party.members[0].equip[2], s.gear_bag, BagRules.used(s)], ["equip.medic_coat", {"equip.padded_coat": 1}, 60], "바꾼 뒤에도 60")
	var t := _game()
	t.materials = {RAT: 59}
	t.gear_bag = {"equip.thermal_ring": 1}
	check_eq(t.party.members[4].equip[3], "", "준비: 위저드 칸 3 은 비었다")
	check_eq(GrowthRules.equip(t, 4, 3, "equip.thermal_ring")[0]["type"], "equipped", "빈 칸에 끼기")
	check_eq([t.gear_bag, BagRules.used(t)], [{}, 59], "한 칸이 빈다")
	check_eq(GrowthRules.equip(t, 4, 3, "")[0], {"type": "equipped", "member": 4, "slot": 3, "item": "", "removed": "equip.thermal_ring"}, "빈 칸이 생기면 다시 뺄 수 있다")


# ---- 임시 보급 ----

## M-G9(보급이 빈 칸을 넘어 더함): 소모품·장비 모두 빈 칸만큼, capped.
func test_supply_saturates_at_free_slots() -> void:
	var s := _game()
	s.materials = {RAT: 55}
	check_eq(GrowthRules.supply(s, MEDICA, 3), [{"type": "supplied", "item": MEDICA, "amount": 3, "capped": false}] as Array[Dictionary], "소모품 보급 3")
	check_eq(GrowthRules.supply(s, TWIN, 5), [{"type": "supplied", "item": TWIN, "amount": 2, "capped": true}] as Array[Dictionary], "장비 보급: 빈 칸 2 만")
	check_eq(GrowthRules.supply(s, MEDICA, 1), [{"type": "supplied", "item": MEDICA, "amount": 0, "capped": true}] as Array[Dictionary], "60/60: 0, capped")
	check_eq([s.consumables, s.gear_bag, BagRules.used(s)], [{MEDICA: 3}, {TWIN: 2}, 60], "가방 60")
	check_eq(GrowthRules.supply(s, "use.nope", 1), [{"type": "rejected", "reason": "unknown_item"}] as Array[Dictionary], "모르는 소모품")
	check_eq(GrowthRules.supply(s, RAT, 1), [{"type": "rejected", "reason": "unknown_item"}] as Array[Dictionary], "소재는 보급하지 않는다")
