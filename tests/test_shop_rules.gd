extends TestCase
## 상점 규칙 시험(08 §3, §5 「규칙」·「새 게임」): 진열·NEW·affordable, 사기·팔기 통과와 거부 갈래마다 하나, 공용 가방 60칸 경계(D31),
## 한정 재고 소모·바닥·다시 참, 풀림(처음 한 번, 진열 차례, 나눠 판 소재 누적). 거부하면 정규화 상태가 그대로다.
## 모두 기능 확인이다(D15): 준비에 필요한 소재·소지금은 상태에 바로 넣는다.

const Fx := preload("res://tests/fixtures.gd")

const JUNK := "shop.junk_workshop"
const SWORD := "equip.training_sword"
const SHIELD := "equip.training_shield"
const SABER := "equip.ion_saber"
const FOCUS := "equip.focus_staff"
const AEGIS := "equip.aegis_plate"
const SERVO := "equip.servo_gauntlet"
const RAT := "item.neon_rat_tail"
const CABLE := "item.cable_scale"
const GLOW := "item.glow_scale"
const SPORE := "item.spore_pouch"
const BEETLE := "item.beetle_plate"
const PINCER := "item.intact_pincer"
const MEDICA := "use.medica"
const AMRITA := "use.amrita"
const NECTAR := "use.nectar"
## 처음부터 파는 줄(08 §1.3), 진열 차례. 장비 뒤에 늘 파는 소모품 넷(M3 A4 설계 §2.4, 풀림 없는 줄).
const OPEN := ["training_sword", "twin_edge", "nano_rod", "glyph_stylus", "padded_coat", "medic_coat", "glyph_robe",
	"training_shield", "sensor_cap", "grip_gloves", "signal_charm", "use.medica", "use.theriaca_a", "use.theriaca_b", "use.ariadne_beacon",
	"rail_bow", "hex_pistol", "scout_hood", "hex_mask"]  # 끝 넷: M3 A7 레인저·해커 장비(풀림 없는 줄)


func _game() -> ExplorationState:
	return ExplorationRules.new_game(Fx.defs(), 3, "floor")


func _items(rows: Array) -> Array:
	return rows.map(func(r: Dictionary) -> String: return r["item"].trim_prefix("equip."))


func _row(s: ExplorationState, item: String) -> Dictionary:
	for r in ShopRules.catalog(s.defs, s, JUNK):
		if r["item"] == item:
			return r
	return {}


## 거부 하나이고 정규화 상태(소지금·상점·가방·소재 포함)가 그대로인지.
func _rejected(label: String, s: ExplorationState, act: Callable, reason: String) -> void:
	var before := SaveCodec.canonical_state(s)
	var ev: Array[Dictionary] = act.call()
	check(ev.size() == 1 and ev[0] == {"type": "rejected", "reason": reason}, "%s: rejected{%s} 기대, 실제 %s" % [label, reason, str(ev)])
	check_eq(SaveCodec.canonical_state(s), before, "%s: 정규화 상태 그대로" % label)


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


# ---- 새 게임 ----

func test_new_game_has_start_money_and_empty_shop() -> void:
	var s := _game()
	check_eq([s.money, s.shop.sold, s.shop.pool, s.shop.bought], [200, {}, {}, {}], "소지금 200·빈 상점")
	var d := SaveCodec.state_to_dict(s)
	check_eq([d["money"], d["shop"]], [200, {"sold": {}, "pool": {}, "bought": []}], "저장 사전에도")
	check_eq(ExplorationState.START_MONEY, 200, "시작 소지금 상수")


# ---- 읽기 ----

func test_catalog_shows_open_lines_hides_locked_and_marks_new_and_affordable() -> void:
	var s := _game()
	var rows := ShopRules.catalog(s.defs, s, JUNK)
	check_eq(_items(rows), OPEN, "처음부터 파는 줄만, 진열 차례(잠긴 줄은 숨는다)")
	check_eq(rows[0], {"item": SWORD, "price": 60, "limited": false, "stock": -1, "new": true, "affordable": true}, "줄 모양")
	check_eq(ShopRules.catalog(s.defs, s, "shop.nope"), [] as Array[Dictionary], "모르는 상점은 빈 배열")
	s.money = 60
	check_eq([_row(s, SWORD)["affordable"], _row(s, "equip.twin_edge")["affordable"]], [true, false], "affordable: 소지금 = 값이면 참, 모자라면 거짓")
	s.money = 200
	ShopRules.buy(s, JUNK, SWORD, 1)
	check_eq([_row(s, SWORD)["new"], _row(s, "equip.twin_edge")["new"]], [false, true], "NEW 는 사기 전까지")
	s.gear_bag.erase(SWORD)
	check_eq(_row(s, SWORD)["new"], false, "판 뒤에도 NEW 가 다시 켜지지 않는다(bought 는 한 번이라도 산 것)")


func test_prices() -> void:
	var defs := Fx.defs()
	check_eq([ShopRules.buy_price(defs, SABER), ShopRules.buy_price(defs, RAT), ShopRules.buy_price(defs, "equip.nope")], [360, 0, 0], "buy_price: 장비 price, 아니면 0")
	check_eq([ShopRules.sell_price(defs, SABER), ShopRules.sell_price(defs, "equip.signal_charm"), ShopRules.sell_price(defs, PINCER), ShopRules.sell_price(defs, "x")],
		[180, 40, 30, 0], "sell_price: 장비 ÷ 2·소재 sell·모르면 0")
	var files := Fx.battle_files()
	for e in files["items/equipment.json"]["equipment"]:
		if e["id"] == "equip.sensor_cap":
			e["price"] = 1
		if e["id"] == "equip.visor":
			e["price"] = 151
	var low := Fx.defs_from(files)
	check_eq([ShopRules.sell_price(low, "equip.sensor_cap"), ShopRules.sell_price(low, "equip.visor")], [1, 75], "값 1 → 판매 1(최소 1), 151 → 75(버림)")


# ---- 사기 ----

func test_buy_passes_and_fills_bag() -> void:
	var s := _game()
	var ev := ShopRules.buy(s, JUNK, SWORD, 2)
	check_eq(ev, [{"type": "bought", "item": SWORD, "qty": 2, "cost": 120, "money": 80}] as Array[Dictionary], "bought 사건")
	check_eq([s.money, s.gear_bag.get(SWORD), s.shop.bought], [80, 2, {SWORD: true}], "소지금 −120·가방 +2·bought")
	check_eq(ShopRules.buy(s, JUNK, "equip.sensor_cap", 1.0)[0]["type"], "bought", "정수와 같은 실수 수량은 받는다")
	check_eq([s.shop.sold, s.shop.pool], [{}, {}], "한정이 아니면 pool 을 건드리지 않는다")


## 공용 가방 60칸(D31): 소재 55 + 장비 3 = 58 칸에서 셋은 거부, 둘은 받아 딱 60, 그 뒤 하나도 거부.
## 종류 상한 99 는 60칸을 넘은 옛 저장에서만 닿는다: 장비 99 개 가방은 넘친 가방이라 하나도 못 산다.
func test_buy_bag_shared_60_boundary() -> void:
	var s := _game()
	s.money = 100000
	s.materials[RAT] = 55
	s.gear_bag[SWORD] = 3
	_rejected("58 + 3", s, func(): return ShopRules.buy(s, JUNK, SWORD, 3), "bag_full")
	check_eq(ShopRules.buy(s, JUNK, SWORD, 2)[0]["type"], "bought", "58 + 2 = 60 은 받는다")
	_rejected("60 + 1", s, func(): return ShopRules.buy(s, JUNK, SWORD, 1), "bag_full")
	_rejected("60 + 소모품 1", s, func(): return ShopRules.buy(s, JUNK, MEDICA, 1), "bag_full")
	check_eq([s.gear_bag[SWORD], BagRules.used(s)], [5, 60], "장비 5·가방 60")
	var old := _game()
	old.money = 100000
	old.gear_bag[SWORD] = 99
	_rejected("옛 저장 장비 99 + 1", old, func(): return ShopRules.buy(old, JUNK, SWORD, 1), "bag_full")


## 08 §3.2 거부 갈래마다 하나 + 판정 순서.
func test_buy_rejections() -> void:
	for x in _busy_states():
		var b: ExplorationState = x[1]
		_rejected("not_now: %s" % x[0], b, func(): return ShopRules.buy(b, JUNK, SWORD, 1), "not_now")
		_rejected("not_now 가 상점보다 먼저: %s" % x[0], b, func(): return ShopRules.buy(b, "shop.nope", SWORD, 1), "not_now")
	var s := _game()
	_rejected("unknown_shop", s, func(): return ShopRules.buy(s, "shop.nope", SWORD, 1), "unknown_shop")
	_rejected("unknown_shop 이 물건보다 먼저", s, func(): return ShopRules.buy(s, "shop.nope", "equip.nope", 0), "unknown_shop")
	_rejected("unknown_item: 없는 장비", s, func(): return ShopRules.buy(s, JUNK, "equip.nope", 1), "unknown_item")
	_rejected("unknown_item: 소재", s, func(): return ShopRules.buy(s, JUNK, RAT, 1), "unknown_item")
	_rejected("locked", s, func(): return ShopRules.buy(s, JUNK, SABER, 1), "locked")
	_rejected("locked 가 수량보다 먼저", s, func(): return ShopRules.buy(s, JUNK, SABER, 0), "locked")
	for q in [0, 100, -1, true, false, 1.5, "1", null]:
		_rejected("bad_amount %s" % var_to_str(q), s, func(): return ShopRules.buy(s, JUNK, SWORD, q), "bad_amount")
	s.money = 59
	_rejected("no_money", s, func(): return ShopRules.buy(s, JUNK, SWORD, 1), "no_money")
	s.money = 119
	_rejected("no_money: 값 × 수량", s, func(): return ShopRules.buy(s, JUNK, SWORD, 2), "no_money")
	s.gear_bag[SWORD] = 99
	_rejected("no_money 가 bag_full 보다 먼저", s, func(): return ShopRules.buy(s, JUNK, SWORD, 2), "no_money")
	s.money = 1000
	_rejected("bag_full", s, func(): return ShopRules.buy(s, JUNK, SWORD, 1), "bag_full")
	# sold_out: 한정 줄이 풀렸고(sold) 재고(pool)가 모자란다.
	var t := _game()
	t.money = 100
	t.shop.sold = {BEETLE: 2, PINCER: 1}
	t.shop.pool = {BEETLE: 2, PINCER: 1}
	_rejected("sold_out: 남은 1, 2 사기", t, func(): return ShopRules.buy(t, JUNK, AEGIS, 2), "sold_out")
	_rejected("bad_amount 가 sold_out 보다 먼저", t, func(): return ShopRules.buy(t, JUNK, AEGIS, 100), "bad_amount")
	_rejected("sold_out 이 no_money 보다 먼저", t, func(): return ShopRules.buy(t, JUNK, AEGIS, 2), "sold_out")
	_rejected("no_money: 한정 1", t, func(): return ShopRules.buy(t, JUNK, AEGIS, 1), "no_money")
	t.shop.pool = {BEETLE: 2}
	_rejected("sold_out: pool 바닥", t, func(): return ShopRules.buy(t, JUNK, AEGIS, 1), "sold_out")


# ---- 한정 재고 ----

func test_limited_stock_is_consumed_runs_out_and_refills_from_sales() -> void:
	var s := _game()
	s.money = 5000
	s.materials = {BEETLE: 9, PINCER: 5}
	check_eq(_row(s, AEGIS), {}, "준비 전에는 잠김")
	check_eq(ShopRules.shortage(s.defs, s, JUNK, AEGIS), {BEETLE: 2, PINCER: 1}, "잠긴 한정 줄도 pool 로 모자란 수를 센다")
	var ev := ShopRules.sell(s, JUNK, [{"item": BEETLE, "qty": 4}, {"item": PINCER, "qty": 1}])
	check_eq(Fx.types(ev), ["sold", "unlocked"] as Array[String], "팔아서 풀림")
	check_eq(_row(s, AEGIS), {"item": AEGIS, "price": 400, "limited": true, "stock": 1, "new": true, "affordable": true}, "남은 수 = min(4 ÷ 2, 1 ÷ 1) = 1")
	check_eq(ShopRules.shortage(s.defs, s, JUNK, AEGIS), {}, "살 수 있으면 빈 사전")
	check_eq(ShopRules.buy(s, JUNK, AEGIS, 1), [{"type": "bought", "item": AEGIS, "qty": 1, "cost": 400, "money": 5000 + 4 * 18 + 30 - 400}] as Array[Dictionary], "한정 사기")
	check_eq([s.shop.pool, s.shop.sold], [{BEETLE: 2}, {BEETLE: 4, PINCER: 1}], "pool 에서 unlock × 1 을 빼고 0 은 지운다. sold 는 그대로")
	check_eq(_row(s, AEGIS)["stock"], 0, "바닥: 줄은 보이고 남은 수 0(풀림은 sold 로 본다)")
	check_eq(ShopRules.shortage(s.defs, s, JUNK, AEGIS), {PINCER: 1}, "모자란 소재만")
	_rejected("바닥이면 sold_out", s, func(): return ShopRules.buy(s, JUNK, AEGIS, 1), "sold_out")
	ShopRules.sell(s, JUNK, [{"item": PINCER, "qty": 3}, {"item": BEETLE, "qty": 4}])
	check_eq([s.shop.pool, _row(s, AEGIS)["stock"]], [{BEETLE: 6, PINCER: 3}, 3], "다시 팔면 다시 찬다: min(6 ÷ 2, 3 ÷ 1)")
	ShopRules.buy(s, JUNK, AEGIS, 2)
	check_eq([s.shop.pool, _row(s, AEGIS)["stock"], s.gear_bag[AEGIS]], [{BEETLE: 2, PINCER: 1}, 1, 3], "수량 2 는 unlock × 2 를 뺀다")
	check_eq([ShopRules.shortage(s.defs, s, JUNK, SWORD), ShopRules.shortage(s.defs, s, JUNK, "equip.nope"), ShopRules.shortage(s.defs, s, "shop.nope", AEGIS)],
		[{}, {}, {}], "shortage: 한정 아님·모르는 물건·모르는 상점은 빈 사전")


# ---- 팔기 ----

func test_sell_materials_and_bag_gear_in_one_batch() -> void:
	var s := _game()
	s.materials = {RAT: 2, GLOW: 3}
	s.gear_bag = {SHIELD: 2}
	var ev := ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 2}, {"item": SHIELD, "qty": 1}, {"item": GLOW, "qty": 1.0}])
	check_eq(ev, [{"type": "sold", "lines": [{"item": RAT, "qty": 2, "gain": 16}, {"item": SHIELD, "qty": 1, "gain": 25}, {"item": GLOW, "qty": 1, "gain": 20}],
		"gain": 61, "money": 261}] as Array[Dictionary], "sold 사건(받은 줄 차례)")
	check_eq([s.materials, s.gear_bag, s.money], [{GLOW: 2}, {SHIELD: 1}, 261], "0 이면 키를 지우고 소지금에 합을 더한다")
	check_eq([s.shop.sold, s.shop.pool], [{RAT: 2, GLOW: 1}, {RAT: 2, GLOW: 1}], "소재만 sold·pool 에 더한다(장비는 들지 않는다)")
	ShopRules.sell(s, JUNK, [{"item": SHIELD, "qty": 1}])
	check_eq([s.shop.sold, s.gear_bag], [{RAT: 2, GLOW: 1}, {}], "장비만 팔면 sold 그대로")


func test_equipped_gear_cannot_be_sold() -> void:
	var s := _game()
	check_eq(s.party.members[0].equip[0], SWORD, "준비: 나이트가 훈련용 블레이드를 낀다")
	check(not s.gear_bag.has(SWORD), "준비: 가방에는 없다")
	_rejected("장착한 장비", s, func(): return ShopRules.sell(s, JUNK, [{"item": SWORD, "qty": 1}]), "not_owned")
	check_eq(s.party.members[0].equip[0], SWORD, "장착 그대로")


## 08 §3.3 거부 갈래마다 하나 + 판정 순서.
func test_sell_rejections() -> void:
	for x in _busy_states():
		var b: ExplorationState = x[1]
		b.materials[RAT] = 1
		_rejected("not_now: %s" % x[0], b, func(): return ShopRules.sell(b, JUNK, [{"item": RAT, "qty": 1}]), "not_now")
	var s := _game()
	s.materials = {RAT: 3}
	s.gear_bag = {SHIELD: 1}
	var line := {"item": RAT, "qty": 1}
	_rejected("unknown_shop", s, func(): return ShopRules.sell(s, "shop.nope", [line]), "unknown_shop")
	_rejected("unknown_shop 이 줄보다 먼저", s, func(): return ShopRules.sell(s, "shop.nope", []), "unknown_shop")
	var bad_lines := [
		["배열 아님", line], ["빈 배열", []], ["줄이 사전 아님", [RAT]], ["qty 없음", [{"item": RAT}]],
		["모르는 키", [{"item": RAT, "qty": 1, "x": 1}]], ["키 이름 다름", [{"id": RAT, "qty": 1}]],
		["같은 물건 두 줄", [line, {"item": RAT, "qty": 2}]], ["같은 물건 두 줄이 줄 검사보다 먼저", [{"item": "item.nope", "qty": 1}, {"item": "item.nope", "qty": 1}]],
	]
	for b in bad_lines:
		var lines: Variant = b[1]
		_rejected("bad_lines: %s" % b[0], s, func(): return ShopRules.sell(s, JUNK, lines), "bad_lines")
	for item in ["item.nope", 5, JUNK, null]:
		_rejected("unknown_item %s" % var_to_str(item), s, func(): return ShopRules.sell(s, JUNK, [{"item": item, "qty": 1}]), "unknown_item")
	for q in [0, 10000, -1, true, 1.5, "1"]:
		_rejected("bad_amount %s" % var_to_str(q), s, func(): return ShopRules.sell(s, JUNK, [{"item": RAT, "qty": q}]), "bad_amount")
	_rejected("not_owned: 소재", s, func(): return ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 4}]), "not_owned")
	_rejected("not_owned: 없는 소재", s, func(): return ShopRules.sell(s, JUNK, [{"item": CABLE, "qty": 1}]), "not_owned")
	_rejected("not_owned: 가방 장비", s, func(): return ShopRules.sell(s, JUNK, [{"item": SHIELD, "qty": 2}]), "not_owned")
	_rejected("줄 차례: 앞 줄의 bad_amount", s, func(): return ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 0}, {"item": "item.nope", "qty": 1}]), "bad_amount")
	_rejected("줄 차례: 앞 줄의 unknown_item", s, func(): return ShopRules.sell(s, JUNK, [{"item": "item.nope", "qty": 0}, {"item": RAT, "qty": 9}]), "unknown_item")
	_rejected("한 줄 안: unknown_item → bad_amount → not_owned", s, func(): return ShopRules.sell(s, JUNK, [line, {"item": CABLE, "qty": 0}]), "bad_amount")
	_rejected("뒤 줄이 거부되면 앞 줄도 팔지 않는다", s, func(): return ShopRules.sell(s, JUNK, [line, {"item": SHIELD, "qty": 2}]), "not_owned")
	s.money = BattleLimits.MONEY_MAX - 23
	_rejected("money_full", s, func(): return ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 3}]), "money_full")
	_rejected("not_owned 가 money_full 보다 먼저", s, func(): return ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 4}]), "not_owned")
	check_eq(ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 2}])[0]["money"], BattleLimits.MONEY_MAX - 23 + 16, "상한 아래는 받는다")
	s.money = BattleLimits.MONEY_MAX - 8
	check_eq(ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 1}])[0]["money"], BattleLimits.MONEY_MAX, "소지금 = 상한은 받는다")


# ---- 풀림 ----

func test_unlock_fires_once_in_stock_order_and_accumulates() -> void:
	var s := _game()
	s.materials = {CABLE: 9, GLOW: 9, SPORE: 9}
	check_eq(Fx.types(ShopRules.sell(s, JUNK, [{"item": CABLE, "qty": 2}])), ["sold"] as Array[String], "케이블 2: 아직(3 필요)")
	check_eq(Fx.types(ShopRules.sell(s, JUNK, [{"item": CABLE, "qty": 1}])), ["sold"] as Array[String], "케이블 누적 3: 발광 인분이 아직")
	var ev := ShopRules.sell(s, JUNK, [{"item": SPORE, "qty": 3}, {"item": GLOW, "qty": 1}])
	check_eq(ev[1], {"type": "unlocked", "shop": JUNK, "items": [SABER, FOCUS, "equip.antitox_chip", AMRITA]}, "한 번에 넷이 풀리고 진열 차례(받은 줄 차례가 아니다, 포자 3 → 아므리타 M3 A4)")
	check_eq(_items(ShopRules.catalog(s.defs, s, JUNK)).slice(0, 4), ["training_sword", "twin_edge", "ion_saber", "nano_rod"], "풀린 줄은 진열 차례 자리에 보인다")
	check(_row(s, SABER)["new"], "풀린 줄은 NEW")
	ev = ShopRules.sell(s, JUNK, [{"item": GLOW, "qty": 1}, {"item": CABLE, "qty": 1}])
	check_eq(Fx.types(ev), ["sold", "unlocked"] as Array[String], "발광 누적 2 → 넥타가 풀린다(M3 A4)")
	check_eq(ev[1]["items"], [NECTAR], "이미 풀린 줄은 다시 unlocked 에 들지 않는다(넥타 하나만)")
	s.shop.sold[PINCER] = 1
	s.materials[PINCER] = 1
	ev = ShopRules.sell(s, JUNK, [{"item": PINCER, "qty": 1}])
	check_eq(ev[1]["items"], [SERVO], "누적 2(상태 1 + 이번 1)로 풀림")


# ---- 소모품(M3 A4) ----

## 소모품을 사면 소모품 묶음에 들고(가방 장비가 아니다, M-H1), 팔면 price ÷ 2(M-H3), sold·pool 은 그대로(M-H2).
func test_consumable_buy_and_sell() -> void:
	var s := _game()
	check_eq([ShopRules.buy_price(s.defs, MEDICA), ShopRules.sell_price(s.defs, MEDICA), ShopRules.sell_price(s.defs, NECTAR)], [20, 10, 75], "소모품 값·판매값(÷ 2)")
	var ev := ShopRules.buy(s, JUNK, MEDICA, 3)
	check_eq(ev, [{"type": "bought", "item": MEDICA, "qty": 3, "cost": 60, "money": 140}] as Array[Dictionary], "메디카 3 사기")
	check_eq([s.consumables, s.gear_bag, s.materials, BagRules.used(s)], [{MEDICA: 3}, {}, {}, 3], "소모품 묶음에만 들고 가방 3칸")
	check_eq(s.shop.bought, {MEDICA: true}, "bought 에 남는다(NEW 끄기)")
	ev = ShopRules.sell(s, JUNK, [{"item": MEDICA, "qty": 2}])
	check_eq(ev, [{"type": "sold", "lines": [{"item": MEDICA, "qty": 2, "gain": 20}], "gain": 20, "money": 160}] as Array[Dictionary], "메디카 2 팔기 = 10 × 2")
	check_eq([s.consumables, s.shop.sold, s.shop.pool], [{MEDICA: 1}, {}, {}], "소모품 판매는 sold·pool 에 들지 않는다")
	ShopRules.sell(s, JUNK, [{"item": MEDICA, "qty": 1}])
	check_eq(s.consumables, {}, "0 이 되면 키를 지운다")
	_rejected("not_owned: 소모품", s, func(): return ShopRules.sell(s, JUNK, [{"item": MEDICA, "qty": 1}]), "not_owned")
	_rejected("locked: 아므리타", s, func(): return ShopRules.buy(s, JUNK, AMRITA, 1), "locked")
	s.materials = {SPORE: 3}
	ShopRules.sell(s, JUNK, [{"item": SPORE, "qty": 3}])
	s.money = 1000
	check_eq(ShopRules.buy(s, JUNK, AMRITA, 2)[0]["type"], "bought", "포자 3 판매 뒤 아므리타를 산다")
	check_eq([s.consumables, s.shop.pool], [{AMRITA: 2}, {SPORE: 3}], "한정이 아니라 pool 을 쓰지 않는다")


func test_sold_and_pool_stop_at_cap() -> void:
	var s := _game()
	var near := BattleLimits.SOLD_MAX - 2
	s.shop.sold = {RAT: near}
	s.shop.pool = {RAT: near - 1}
	s.materials = {RAT: 5}
	ShopRules.sell(s, JUNK, [{"item": RAT, "qty": 5}])
	check_eq([s.shop.sold[RAT], s.shop.pool[RAT], s.money], [BattleLimits.SOLD_MAX, BattleLimits.SOLD_MAX, 200 + 40], "sold·pool 은 9,999,999 에서 멈추고 소지금은 다 받는다")
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok(), "멈춘 값도 저장 검사를 지난다 %s" % r.error)
