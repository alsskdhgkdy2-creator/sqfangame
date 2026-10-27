extends TestCase
## 전투 「아이템」 명령 규칙(M3 A4 설계 §5.2): 제출 검사(unknown_item·item_not_here·예약 no_item·invalid_target), 실행 시점에만 하나 줄기
## (마비·쓰러짐·대상 없음·먼저 끝난 전투는 쓰지 않는다), 대상 다시 보기, 나눈 해제·TP 회복·봉인이 막지 않음, 순서값 = 공격, 결정성,
## 정책은 아이템을 고르지 않는다. 시험마다 죽이는 변이(설계 §8.1, M-B…)를 적는다.

const Fx := preload("res://tests/fixtures.gd")

const MEDICA := "use.medica"
const AMRITA := "use.amrita"
const NECTAR := "use.nectar"
const THERIACA_A := "use.theriaca_a"
const THERIACA_B := "use.theriaca_b"
const BEACON := "use.ariadne_beacon"
const TAP := "skill.enemy.t_tap"


## 아무것도 하지 않는 실제 편성(쥐 떼) 전투, 명중 확정·난수 고정.
func _quiet(rules: Dictionary = {}) -> ExplorationState:
	var r := Fx.EXACT.duplicate()
	r.merge(rules, true)
	return Fx.battle(Fx.quiet_defs(r), "formation.f1.rats")


## 대원보다 먼저 움직여 HP 가 가장 낮은 대원을 치는 시험 적 하나.
func _killer() -> ExplorationState:
	var tap := Fx.enemy_skill(TAP, "damage", "enemy_one")
	var killer := Fx.enemy("enemy.t_killer", 999, [999, 10, 10, 10, 250, 10], [[{}, [[TAP, 1, "lowest_hp"]]]])
	return Fx.battle(Fx.battle_defs(Fx.test_files([tap], [killer], {"k": [["enemy.t_killer", "front"]]}), Fx.EXACT), "formation.t.k")


func _item(item: String, target: int) -> Dictionary:
	return {"kind": "item", "item": item, "target": target}


func _with(cmds: Array, i: int, c: Variant) -> Array:
	var out := cmds.duplicate(true)
	out[i] = c
	return out


## 대원 i 의 action 이벤트(없으면 {}).
func _action_of(ev: Array[Dictionary], i: int) -> Dictionary:
	for e in ev:
		if e["type"] == "action" and e["unit"] == {"side": "party", "slot": i}:
			return e
	return {}


# ---- 제출 검사 ----

## M-B2(예약을 한 칸만 셈): 마지막 하나를 두 대원이 고를 수 없다. 거부는 상태를 바꾸지 않는다.
func test_check_reasons_and_reservation() -> void:
	var s := _quiet()
	s.consumables = {MEDICA: 1, NECTAR: 1, BEACON: 1}
	s.party.members[3].hp = 0
	var h := Fx.battle_hash(s)
	var ok := Fx.cmds(s)
	var cases := [
		["unknown_item", _with(ok, 0, _item("use.nope", 0)), 0],
		["unknown_item: 소재", _with(ok, 0, _item("item.neon_rat_tail", 0)), 0],
		["item_not_here: 비콘", _with(ok, 0, _item(BEACON, 0)), 0],
		["no_item: 가지지 않음", _with(ok, 0, _item(AMRITA, 0)), 0],
		["no_item: 예약(둘째 칸)", _with(_with(ok, 0, _item(MEDICA, 1)), 2, _item(MEDICA, 1)), 2],
		["invalid_target: 없는 칸", _with(ok, 0, _item(MEDICA, 7)), 0],
		["invalid_target: 쓰러진 대원에 메디카", _with(ok, 0, _item(MEDICA, 3)), 0],
		["invalid_target: 산 대원에 넥타", _with(ok, 0, _item(NECTAR, 1)), 0],
		["invalid_target: 대상 빠짐", _with(ok, 0, {"kind": "item", "item": MEDICA}), 0],
		["unknown_command: 모르는 키", _with(ok, 0, {"kind": "item", "item": MEDICA, "target": 1, "skill": "x"}), 0],
	]
	for x in cases:
		var reason: String = x[0].get_slice(":", 0)
		var ev := BattleRules.submit(s, x[1])
		check_eq([ev.size(), ev[0]["type"], ev[0].get("reason"), ev[0].get("slot")], [1, "rejected", reason, x[2]], x[0])
	check_eq(Fx.battle_hash(s), h, "거부는 상태를 바꾸지 않는다")
	check_eq(s.consumables, {MEDICA: 1, NECTAR: 1, BEACON: 1}, "물건 그대로")
	check_eq([BattleRules.item_block_reason(s, 0, MEDICA), BattleRules.item_block_reason(s, 2, MEDICA, _with(ok, 0, _item(MEDICA, 1))),
		BattleRules.item_block_reason(s, 0, MEDICA, _with(ok, 0, _item(MEDICA, 1))), BattleRules.item_block_reason(s, 0, BEACON), BattleRules.item_block_reason(s, 0, "use.nope")],
		["", "no_item", "", "item_not_here", "unknown_item"], "item_block_reason: 다른 대원의 예약만 뺀다")
	check_eq([BattleRules.item_targets(s, 0, NECTAR), BattleRules.item_targets(s, 0, MEDICA).has(3), BattleRules.item_targets(s, 0, BEACON)], [[3], false, []], "item_targets")
	check_eq(BattleRules.items_reserved(_with(_with(ok, 0, _item(MEDICA, 1)), 2, _item(MEDICA, 1)), MEDICA), 2, "items_reserved: 모든 칸")


# ---- 실행 시점에만 줄기 ----

## M-B1(제출 때 줄임): 마비로 실패한 대원은 쓰지 않는다.
func test_paralysis_keeps_the_item() -> void:
	var s := _quiet({"paralysis_fail": 1000})
	s.consumables = {MEDICA: 2}
	s.party.members[0].hp -= 20
	s.battle.party[1].ailment = "paralysis"
	s.battle.party[1].ailment_turns = 5
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: _item(MEDICA, 0)}))
	check(Fx.of_type(ev, "failed").any(func(e): return e["unit"] == {"side": "party", "slot": 1} and e["reason"] == "paralysis"), "마비로 실패 %s" % Fx.events_text(Fx.of_type(ev, "failed")))
	check_eq([s.consumables, Fx.of_type(ev, "item_used").size()], [{MEDICA: 2}, 0], "줄지 않는다")


## 쓰러진 대원은 쓰지 않는다. 대상이 먼저 쓰러지면 메디카는 HP 비율이 가장 낮은 산 대원에게 간다(하나 줄어든다).
func test_down_user_keeps_the_item_and_medica_retargets() -> void:
	var s := _killer()
	s.consumables = {MEDICA: 2}
	s.party.members[2].hp = 1
	var ev := BattleRules.submit(s, Fx.cmds(s, {2: _item(MEDICA, 0)}))
	check(not s.party.members[2].alive(), "준비: 쓰는 대원이 먼저 쓰러졌다")
	check_eq([s.consumables, Fx.of_type(ev, "item_used").size()], [{MEDICA: 2}, 0], "쓰러진 대원은 쓰지 않는다")
	var t := _killer()
	t.consumables = {MEDICA: 2}
	t.party.members[3].hp = 1
	t.party.members[4].hp = t.party.members[4].max_hp - 20
	ev = BattleRules.submit(t, Fx.cmds(t, {1: _item(MEDICA, 3)}))
	check(not t.party.members[3].alive(), "준비: 대상이 먼저 쓰러졌다")
	check_eq(Fx.of_type(ev, "healed").filter(func(e): return e["unit"]["side"] == "party").map(func(e): return [e["target"]["slot"], e["amount"]]), [[4, 20]], "HP 비율이 가장 낮은 산 대원(4)으로")
	check_eq([t.consumables, Fx.of_type(ev, "item_used")[0]["left"]], [{MEDICA: 1}, 1], "하나 줄었다")


## M-B5(소생이 대상을 다시 고름)·M-B7(대상 없음에도 줄임): 둘이 같은 대원에 넥타를 쓰면 둘째는 no_target, 줄지 않고 다른 쓰러진 대원도 그대로.
func test_second_nectar_on_the_same_member_is_not_used() -> void:
	var s := _quiet()
	s.consumables = {NECTAR: 2}
	s.party.members[3].hp = 0
	s.party.members[4].hp = 0
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: _item(NECTAR, 3), 2: _item(NECTAR, 3)}))
	check_eq(Fx.of_type(ev, "revived").map(func(e): return e["target"]["slot"]), [3], "한 번만 되살린다")
	check_eq(Fx.of_type(ev, "failed").map(func(e): return e["reason"]), ["no_target"], "둘째는 no_target")
	check_eq([s.consumables, s.party.members[4].alive()], [{NECTAR: 1}, false], "하나만 줄고 대원 4 는 그대로")


## 대원 하나가 쓰기 전에 전투가 끝나면(앞의 공격으로 승리) 쓰지 않는다.
func test_battle_that_ends_first_keeps_the_item() -> void:
	var s := _quiet()
	s.consumables = {MEDICA: 1}
	s.party.members[0].hp -= 10
	var slow := 0
	for i in range(1, 5):
		if s.battle.party[i].stats["AGI"] < s.battle.party[slow].stats["AGI"]:
			slow = i
	var over := {slow: _item(MEDICA, 0)}
	var target := 0
	for i in 5:
		if i != slow and target < s.battle.enemies.size():
			s.battle.enemies[target].hp = 1
			over[i] = Fx.atk(target)
			target += 1
	for j in range(target, s.battle.enemies.size()):
		s.battle.enemies[j].hp = 0
	var ev := BattleRules.submit(s, Fx.cmds(s, over))
	check_eq(Fx.of_type(ev, "battle_end").size(), 1, "준비: 이 턴에 이겼다")
	check_eq([s.consumables, Fx.of_type(ev, "item_used").size()], [{MEDICA: 1}, 0], "느린 대원(%d)은 쓰지 않았다" % slow)


# ---- 효과 ----

## M-B3(테리아카 A 가 봉인까지 푼다).
func test_theriaca_cures_split_and_amrita_clips() -> void:
	var s := _quiet()
	s.consumables = {THERIACA_A: 1, THERIACA_B: 1, AMRITA: 1}
	for i in [1, 2]:
		var u := s.battle.party[i]
		u.ailment = "poison"
		u.ailment_turns = 3
		u.ailment_damage = 1
		u.binds = {"arm": 3}
	s.party.members[3].tp = s.party.members[3].max_tp - 5
	var ev := BattleRules.submit(s, Fx.cmds(s, {0: _item(THERIACA_A, 1), 3: _item(THERIACA_B, 2), 4: _item(AMRITA, 3)}))
	var cured := Fx.of_type(ev, "cured")
	check_eq(cured.map(func(e): return [e["target"]["slot"], e["removed"]]), [[1, ["poison"]], [2, ["arm"]]] if cured[0]["target"]["slot"] == 1 else [[2, ["arm"]], [1, ["poison"]]], "A 는 상태 이상만, B 는 봉인만")
	check_eq([s.battle.party[1].binds.keys(), s.battle.party[2].ailment], [["arm"], "poison"], "남은 쪽은 그대로")
	check_eq(Fx.of_type(ev, "tp_healed").map(func(e): return [e["target"]["slot"], e["amount"], e["tp"]]), [[3, 5, s.party.members[3].max_tp]], "아므리타: 모자란 5 만")
	check_eq(s.consumables, {}, "셋 다 썼다")


## M-B6(대리 스킬에 부위 arm): 머리·팔·다리가 모두 봉인되어도 아이템은 쓴다.
func test_binds_never_block_items() -> void:
	var s := _quiet()
	s.consumables = {MEDICA: 1}
	s.party.members[0].hp -= 30
	s.battle.party[1].binds = {"head": 3, "arm": 3, "leg": 3}
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: _item(MEDICA, 0)}))
	check_eq(Fx.of_type(ev, "failed").size(), 0, "실패 없음")
	check_eq(Fx.of_type(ev, "healed").filter(func(e): return e["unit"]["side"] == "party").map(func(e): return [e["target"], e["amount"]]),
		[[{"side": "party", "slot": 0}, 30]], "회복 30(적의 0 회복 MEND 는 뺀다)")
	check_eq(_action_of(ev, 1).get("kind"), "item", "action 의 kind = item")


# ---- 순서·결정성·정책 ----

## M-B4(대리 스킬 속도 2000): 같은 시드에서 아이템과 공격의 순서값이 같다(AGI 계수 1, 순서 난수 하나).
func test_order_equals_attack_and_same_seed_same_events() -> void:
	var a := _quiet({"speed_roll": [900, 1100]})
	var b := _quiet({"speed_roll": [900, 1100]})
	for s in [a, b]:
		s.consumables = {MEDICA: 1}
		s.party.members[0].hp -= 10
	var ea := BattleRules.submit(a, Fx.cmds(a, {2: Fx.atk(0)}))
	var eb := BattleRules.submit(b, Fx.cmds(b, {2: _item(MEDICA, 0)}))
	check(not _action_of(ea, 2).is_empty() and not _action_of(eb, 2).is_empty(), "준비: 둘 다 움직였다")
	check_eq(_action_of(eb, 2)["order"], _action_of(ea, 2)["order"], "순서값 = 공격")
	var c := _quiet({"speed_roll": [900, 1100]})
	c.consumables = {MEDICA: 1}
	c.party.members[0].hp -= 10
	var ec := BattleRules.submit(c, Fx.cmds(c, {2: _item(MEDICA, 0)}))
	check_eq(Fx.events_text(ec), Fx.events_text(eb), "같은 시드·같은 명령 → 같은 이벤트")
	check_eq(Fx.battle_hash(c), Fx.battle_hash(b), "같은 상태")


func test_policies_never_choose_items() -> void:
	for p in BattlePolicy.NAMES:
		var s := _quiet()
		s.consumables = {MEDICA: 9, AMRITA: 9, NECTAR: 9, THERIACA_A: 9, THERIACA_B: 9}
		s.party.members[3].hp = 0
		for m in s.party.members:
			if m.alive():
				m.hp = 1
				m.tp = 0
		var cmds := BattlePolicy.choose(s, p)
		check(cmds.all(func(c): return c == null or c["kind"] != "item"), "%s: 아이템 없음 %s" % [p, str(cmds)])
