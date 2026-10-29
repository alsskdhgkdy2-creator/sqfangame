extends TestCase
## 저장 4판 시험(08 §4, §5 「저장」): 소지금·상점 상태 왕복, bought 정렬, 1·2·3판 이전(시작 소지금·빈 상점), 4판 검사 거부 갈래마다 하나.

const Fx := preload("res://tests/fixtures.gd")
const BS := preload("res://tests/test_battle_save.gd")
const GS := preload("res://tests/test_growth_save.gd")

const JUNK := "shop.junk_workshop"
const RAT := "item.neon_rat_tail"
const BEETLE := "item.beetle_plate"
const PINCER := "item.intact_pincer"
const AEGIS := "equip.aegis_plate"
const EMPTY_SHOP := {"sold": {}, "pool": {}, "bought": []}


func _game() -> ExplorationState:
	return ExplorationRules.new_game(Fx.defs(), 6, "floor")


## 규칙으로 만든 상점 상태: 소재를 팔아 한정 줄을 풀고 하나 사서 pool < sold, 일반 줄도 산다.
func _shopped() -> ExplorationState:
	var s := _game()
	s.materials = {RAT: 4, BEETLE: 5, PINCER: 2}
	ShopRules.sell(s, JUNK, [{"item": BEETLE, "qty": 4}, {"item": PINCER, "qty": 2}, {"item": RAT, "qty": 3}])
	s.money = 1000
	ShopRules.buy(s, JUNK, AEGIS, 1)
	ShopRules.buy(s, JUNK, "equip.visor", 1)
	ShopRules.buy(s, JUNK, "equip.sensor_cap", 2)
	return s


func test_v4_roundtrip_with_money_and_shop() -> void:
	var s := _shopped()
	check_eq([s.money, s.shop.sold, s.shop.pool], [1000 - 400 - 150 - 80, {BEETLE: 4, PINCER: 2, RAT: 3}, {BEETLE: 2, PINCER: 1, RAT: 3}], "준비: 소지금·sold·pool")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["schema"], doc["rules"]], [12.0, "m3q"], "12판 머리(M3 A4)")
	check_eq(doc["state"]["money"], 370.0, "money")
	check_eq(doc["state"]["shop"], {"sold": {BEETLE: 4.0, PINCER: 2.0, RAT: 3.0}, "pool": {BEETLE: 2.0, PINCER: 1.0, RAT: 3.0}, "bought": [AEGIS, "equip.sensor_cap", "equip.visor"]}, "shop(bought 는 정렬한 배열)")
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok(), "읽기 %s" % r.error)
	if not r.ok():
		return
	var c := r.state
	check_eq([r.from_schema, c.money, c.shop.sold, c.shop.pool, c.shop.bought], [12, s.money, s.shop.sold, s.shop.pool, s.shop.bought], "읽은 소지금·상점 상태")
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 해시")
	check_eq(ShopRules.catalog(c.defs, c, JUNK), ShopRules.catalog(s.defs, s, JUNK), "같은 진열(풀림·재고·NEW)")
	check_eq(ShopRules.buy(c, JUNK, AEGIS, 1), ShopRules.buy(s, JUNK, AEGIS, 1), "같은 다음 사기")
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 다음 상태")


func test_bought_order_does_not_change_hash() -> void:
	var a := _game()
	var b := _game()
	for id in ["equip.visor", AEGIS, "equip.grip_gloves"]:
		a.shop.bought[id] = true
	for id in ["equip.grip_gloves", "equip.visor", AEGIS]:
		b.shop.bought[id] = true
	check_eq(SaveCodec.canonical_state(a), SaveCodec.canonical_state(b), "넣은 차례가 달라도 같은 정규화 문자열")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(a))
	doc["state"]["shop"]["bought"].reverse()
	var r := SaveCodec.decode(JSON.stringify(doc), a.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(a), "정렬하지 않은 bought 도 읽고 같은 해시 %s" % r.error)


func test_boundary_values_roundtrip() -> void:
	for money in [0, BattleLimits.MONEY_MAX]:
		var s := _game()
		s.money = money
		s.shop.sold = {RAT: BattleLimits.SOLD_MAX, BEETLE: 1}
		s.shop.pool = {RAT: BattleLimits.SOLD_MAX, BEETLE: 1}
		var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
		check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "소지금 %d·sold 상한 왕복 %s" % [money, r.error])


# ---- 이전 ----

func _check_start_shop(r: SaveCodec.LoadResult, from: int, label: String) -> void:
	check(r.ok(), "%s: 이전 %s" % [label, r.error])
	if not r.ok():
		return
	check_eq([r.from_schema, r.state.money, SaveCodec.state_to_dict(r.state)["shop"]], [from, ExplorationState.START_MONEY, EMPTY_SHOP], "%s: from_schema·시작 소지금·빈 상점" % label)
	check_eq(JSON.parse_string(SaveCodec.encode(r.state))["schema"], 12.0, "%s: 12판으로 쓴다" % label)
	var again := SaveCodec.decode(SaveCodec.encode(r.state), r.state.defs)
	check(again.ok() and again.from_schema == 12 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 12판 다시 읽기 같은 해시" % label)


func test_v1_v2_v3_migrate_to_start_money_and_empty_shop() -> void:
	var defs := Fx.defs()
	for x in [["1판 보통", BS.V1_NORMAL, 1], ["1판 전투 대기", BS.V1_PENDING, 1], ["1판 전멸", BS.V1_WIPED, 1],
			["2판 보통", GS.V2_NORMAL, 2], ["2판 전투 중", GS.V2_BATTLE, 2], ["2판 전멸", GS.V2_WIPED, 2]]:
		_check_start_shop(SaveCodec.decode(x[1], defs), x[2], x[0])
	# 3판: 소지금·상점 상태가 있는 4판 상태에서 두 키를 뺀 문서 → 시작 값으로 채운다.
	var s := _shopped()
	var v3: Dictionary = GS.as_v3(JSON.parse_string(SaveCodec.encode(s, "2026-10-20T01:02:03Z", 41)))
	var r := SaveCodec.decode(JSON.stringify(v3), defs)
	_check_start_shop(r, 3, "3판")
	if r.ok():
		check_eq([r.saved_at, r.generation, r.state.generation], ["2026-10-20T01:02:03Z", 41, 41], "3판: 원본 saved_at·generation 보존")
		check_eq([r.state.gear_bag, r.state.materials], [s.gear_bag, s.materials], "3판: 가방·소재 보존")
		r.state.money = s.money
		r.state.shop = s.shop
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "3판: 소지금·상점 말고는 같은 상태")
	var mid := Fx.battle(Fx.quiet_defs(), "formation.f1.rats")
	var rb := SaveCodec.decode(JSON.stringify(GS.as_v3(JSON.parse_string(SaveCodec.encode(mid)))), mid.defs)
	_check_start_shop(rb, 3, "3판 전투 중")
	if rb.ok():
		check_eq([SaveCodec.state_hash(rb.state), Fx.battle_hash(rb.state)], [SaveCodec.state_hash(mid), Fx.battle_hash(mid)], "3판 전투 중: 같은 상태·전투")


func test_v3_bad_original_rejected_before_migration() -> void:
	var s := _game()
	var v3: Dictionary = GS.as_v3(JSON.parse_string(SaveCodec.encode(s)))
	v3["state"]["gear_bag"]["equip.visor"] = 100
	var r := SaveCodec.decode(JSON.stringify(v3), s.defs)
	check(not r.ok() and r.state == null and r.error.begins_with("3판 검사 실패: ") and r.error.contains("gear_bag.equip.visor"), "3판 규칙으로 먼저 거부: %s" % r.error)


# ---- 4판 거부 (08 §4 검사마다) ----

func _expect_reject(mutate: Callable, needle: String, label: String) -> void:
	var s := _shopped()
	var before := SaveCodec.state_hash(s)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)


func test_v4_rejects_each_check() -> void:
	var cases := [
		["money 없음", func(d): d.erase("money"), "money 가 정수 0~9999999"],
		["money 음수", func(d): d["money"] = -1, "money 가 정수 0~9999999"],
		["money 10,000,000", func(d): d["money"] = 10000000, "money 가 정수 0~9999999"],
		["money 소수", func(d): d["money"] = 1.5, "money 가 정수"],
		["money 문자열", func(d): d["money"] = "370", "money 가 정수"],
		["money 불리언", func(d): d["money"] = true, "money 가 정수"],
		["shop 없음", func(d): d.erase("shop"), "shop 이 객체가 아니다"],
		["shop 배열", func(d): d["shop"] = [], "shop 이 객체가 아니다"],
		["shop 키 없음", func(d): d["shop"].erase("pool"), "shop.pool 가 없다"],
		["shop 모르는 키", func(d): d["shop"]["new"] = [], "shop.new 는 모르는 필드다"],
		["sold 배열", func(d): d["shop"]["sold"] = [], "shop.sold 가 객체가 아니다"],
		["pool 배열", func(d): d["shop"]["pool"] = [], "shop.pool 가 객체가 아니다"],
		["sold 모르는 소재", func(d): d["shop"]["sold"]["item.nope"] = 1, "shop.sold 의 item.nope 는 모르는 소재다"],
		["sold 장비 ID", func(d): d["shop"]["sold"][AEGIS] = 1, "shop.sold 의 %s 는 모르는 소재다" % AEGIS],
		["sold 0", func(d): d["shop"]["sold"]["item.glow_scale"] = 0, "shop.sold.item.glow_scale 가 정수 1~9999999"],
		["sold 상한 초과", func(d): d["shop"]["sold"][RAT] = 10000000, "shop.sold.%s 가 정수 1~9999999" % RAT],
		["sold 문자열", func(d): d["shop"]["sold"][RAT] = "3", "shop.sold.%s 가 정수" % RAT],
		["pool 모르는 소재", func(d): d["shop"]["pool"]["item.nope"] = 1, "shop.pool 의 item.nope 는 모르는 소재다"],
		["pool 0", func(d): d["shop"]["pool"][RAT] = 0, "shop.pool.%s 가 정수 1~9999999" % RAT],
		["pool 소수", func(d): d["shop"]["pool"][RAT] = 2.5, "shop.pool.%s 가 정수" % RAT],
		["pool 키가 sold 에 없음", func(d): d["shop"]["pool"]["item.glow_scale"] = 1, "shop.pool.item.glow_scale 가 shop.sold 에 없다"],
		["pool > sold", func(d): d["shop"]["pool"][BEETLE] = 5, "shop.pool.%s 가 shop.sold.%s(4)보다 크다" % [BEETLE, BEETLE]],
		["bought 객체", func(d): d["shop"]["bought"] = {}, "shop.bought 가 배열이 아니다"],
		["bought 모르는 장비", func(d): d["shop"]["bought"].append("equip.nope"), "shop.bought 의 equip.nope 는 모르는 장비·소모품이다"],
		["bought 소재 ID", func(d): d["shop"]["bought"].append(RAT), "shop.bought 의 %s 는 모르는 장비·소모품이다" % RAT],
		["bought 모르는 소모품", func(d): d["shop"]["bought"].append("use.nope"), "shop.bought 의 use.nope 는 모르는 장비·소모품이다"],
		["bought 숫자", func(d): d["shop"]["bought"].append(3), "shop.bought 의 3"],
		["bought 겹침", func(d): d["shop"]["bought"].append(AEGIS), "shop.bought 에 %s 가 두 번 있다" % AEGIS],
	]
	for c in cases:
		_expect_reject(c[1], c[2], c[0])
	# 경계 안은 받는다.
	var s := _shopped()
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	doc["state"]["shop"]["pool"][BEETLE] = 4
	doc["state"]["money"] = BattleLimits.MONEY_MAX
	check(SaveCodec.decode(JSON.stringify(doc), s.defs).ok(), "pool = sold·소지금 상한은 받는다")
