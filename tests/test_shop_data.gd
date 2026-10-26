extends TestCase
## 상점 정의 읽기·검사(08 §1, §5 「자료」): 장비 값·소재 판매값, 「정크 공방」 진열, §1.2 오류 갈래마다 하나, 진열에 없는 장비 경고.

const Fx := preload("res://tests/fixtures.gd")

const SH := "shop/junk_workshop.json"
const EQ := "items/equipment.json"
const MAT := "items/materials.json"
const JUNK := "shop.junk_workshop"

## 08 §1.3 표: [장비, 값, 풀림 조건, 한정], 진열 차례.
const TABLE := [
	["training_sword", 60, {}, false], ["twin_edge", 120, {}, false], ["ion_saber", 360, {"cable_scale": 3, "glow_scale": 1}, false],
	["nano_rod", 60, {}, false], ["glyph_stylus", 80, {}, false], ["tactical_baton", 220, {"drill_claw": 2}, false],
	["focus_staff", 300, {"spore_pouch": 3, "glow_scale": 1}, false], ["padded_coat", 60, {}, false], ["medic_coat", 60, {}, false],
	["glyph_robe", 60, {}, false], ["mesh_armor", 280, {"coated_scale": 3}, false], ["training_shield", 50, {}, false],
	["aegis_plate", 400, {"beetle_plate": 2, "intact_pincer": 1}, true], ["sensor_cap", 40, {}, false], ["visor", 150, {"neon_rat_tail": 3}, false],
	["grip_gloves", 40, {}, false], ["servo_gauntlet", 240, {"intact_pincer": 2}, false], ["mag_boots", 200, {"drill_claw": 3}, false],
	["signal_charm", 80, {}, false], ["antitox_chip", 320, {"spore_pouch": 2}, false], ["thermal_ring", 300, {"coated_scale": 2, "beetle_plate": 1}, true],
]
const SELL := {"neon_rat_tail": 8, "cable_scale": 12, "glow_scale": 20, "spore_pouch": 10, "coated_scale": 14, "drill_claw": 16, "beetle_plate": 18, "intact_pincer": 30}


func _errors_after(mutate: Callable) -> Array[String]:
	var files := Fx.battle_files()
	mutate.call(files)
	return Fx.battle_db(files).errors


func _rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _errors_after(mutate)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _accepts(label: String, mutate: Callable) -> void:
	check_eq(_errors_after(mutate), [] as Array[String], "%s: 오류 없음" % label)


func _index(files: Dictionary, path: String, key: String, id: String) -> int:
	var list: Array = files[path][key]
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return -1


func _eq(f: Dictionary, id: String) -> Dictionary:
	return f[EQ]["equipment"][_index(f, EQ, "equipment", id)]


func _line(f: Dictionary, i: int) -> Dictionary:
	return f[SH]["stock"][i]


func test_real_shop_data() -> void:
	var db := BattleDb.load_dir(Fx.DATA_DIR)
	check(db.ok(), "오류 0: %s" % str(db.errors))
	check_eq(db.warnings, [] as Array[String], "경고 0(모든 장비가 진열에 있다)")
	check_eq(db.shop_ids, [JUNK] as Array[String], "상점 하나")
	for id in db.equipment_ids:
		check(BattleLimits.in_range("price", db.equip(id).price), "%s: price 1~999,999" % id)
	for id in db.material_ids:
		check(BattleLimits.in_range("sell", db.material_sell[id]), "%s: sell 1~99,999" % id)
	var sh := db.shop(JUNK)
	check_eq(sh.name_key, JUNK, "name_key")
	check_eq(sh.stock.size(), TABLE.size(), "진열 21줄")
	for i in TABLE.size():
		var row: Array = TABLE[i]
		var unlock := {}
		for m in row[2]:
			unlock["item." + m] = row[2][m]
		check_eq(sh.stock[i], {"item": "equip." + row[0], "unlock": unlock, "limited": row[3]}, "진열 %d 차례·풀림·한정(08 §1.3)" % (i + 1))
		check_eq(db.equip("equip." + row[0]).price, row[1], "%s 값" % row[0])
	for m in SELL:
		check_eq(db.material_sell["item." + m], SELL[m], "%s 판매값" % m)
	check_eq(db.material_ids.size(), SELL.size(), "소재 여덟")
	var texts := TextDb.load_path("res://data/text/ko.json")
	check_eq(texts.t(JUNK), "정크 공방", "상점 이름 문구")
	check(db.name_keys().has(JUNK), "상점 name_key 도 문구 검사에 들어간다")


func test_price_and_sell_checks() -> void:
	var i_saber := _index(Fx.data_files(), EQ, "equipment", "equip.ion_saber")
	_rejects("price 없음", func(f): _eq(f, "equip.ion_saber").erase("price"), "%s: equipment[%d].price: 필수 필드가 없다" % [EQ, i_saber])
	_rejects("price 0", func(f): _eq(f, "equip.ion_saber")["price"] = 0, "equipment[%d].price: 정수 1~999999" % i_saber)
	_rejects("price 1,000,000", func(f): _eq(f, "equip.ion_saber")["price"] = 1000000, "equipment[%d].price: 정수 1~999999" % i_saber)
	_rejects("price 문자열", func(f): _eq(f, "equip.ion_saber")["price"] = "360", "equipment[%d].price: 정수" % i_saber)
	_rejects("price 소수", func(f): _eq(f, "equip.ion_saber")["price"] = 360.5, "equipment[%d].price: 정수" % i_saber)
	_accepts("price 999,999", func(f): _eq(f, "equip.ion_saber")["price"] = 999999)
	_rejects("sell 없음", func(f): f[MAT]["materials"][1].erase("sell"), "%s: materials[1].sell: 필수 필드가 없다" % MAT)
	_rejects("sell 0", func(f): f[MAT]["materials"][1]["sell"] = 0, "materials[1].sell: 정수 1~99999")
	_rejects("sell 100,000", func(f): f[MAT]["materials"][1]["sell"] = 100000, "materials[1].sell: 정수 1~99999")
	_rejects("sell 불리언", func(f): f[MAT]["materials"][1]["sell"] = true, "materials[1].sell: 정수")
	_accepts("sell 99,999", func(f): f[MAT]["materials"][1]["sell"] = 99999)


## 08 §1.2 「검사」 오류 갈래마다 하나.
func test_shop_file_checks() -> void:
	# 모르는 키
	_rejects("맨 위 모르는 키", func(f): f[SH]["owner"] = "x", "%s: owner: 모르는 필드" % SH)
	_rejects("줄 모르는 키", func(f): _line(f, 0)["count"] = 1, "%s: stock[0].count: 모르는 필드" % SH)
	_rejects("필수 키 없음", func(f): f[SH].erase("name_key"), "%s: name_key: 필수 필드가 없다" % SH)
	_rejects("줄 item 없음", func(f): _line(f, 3).erase("item"), "%s: stock[3].item: 필수 필드가 없다" % SH)
	# 모르는 장비·소재
	_rejects("모르는 장비", func(f): _line(f, 1)["item"] = "equip.nope", "%s: stock[1].item: 없는 장비 equip.nope" % SH)
	_rejects("장비 아닌 ID", func(f): _line(f, 1)["item"] = "item.neon_rat_tail", "%s: stock[1].item: equip. 로 시작" % SH)
	_rejects("모르는 소재", func(f): _line(f, 2)["unlock"]["item.nope"] = 1, "%s: stock[2].unlock.item.nope: 없는 소재 item.nope" % SH)
	_rejects("소재 아닌 ID", func(f): _line(f, 2)["unlock"]["equip.visor"] = 1, "%s: stock[2].unlock.equip.visor: item. 로 시작" % SH)
	# 같은 장비 두 줄
	_rejects("같은 장비 두 줄", func(f): _line(f, 1)["item"] = "equip.training_sword", "%s: stock[1].item: 같은 장비 equip.training_sword 가 stock[0] 에도" % SH)
	# unlock 없는 limited
	_rejects("unlock 없는 limited", func(f): _line(f, 0)["limited"] = true, "%s: stock[0].limited: 한정 줄은 unlock 이 있어야 한다" % SH)
	_accepts("limited 거짓은 unlock 없어도 된다", func(f): _line(f, 0)["limited"] = false)
	_rejects("빈 unlock", func(f): _line(f, 0)["unlock"] = {}, "%s: stock[0].unlock: 소재 ID 와 수" % SH)
	# 범위 밖 수
	_rejects("unlock 0", func(f): _line(f, 2)["unlock"]["item.cable_scale"] = 0, "%s: stock[2].unlock.item.cable_scale: 정수 1~999" % SH)
	_rejects("unlock 1000", func(f): _line(f, 2)["unlock"]["item.cable_scale"] = 1000, "%s: stock[2].unlock.item.cable_scale: 정수 1~999" % SH)
	_accepts("unlock 999", func(f): _line(f, 2)["unlock"]["item.cable_scale"] = 999)
	# 타입이 다른 값
	_rejects("unlock 배열", func(f): _line(f, 2)["unlock"] = ["item.cable_scale"], "%s: stock[2].unlock: 소재 ID 와 수" % SH)
	_rejects("unlock 수 문자열", func(f): _line(f, 2)["unlock"]["item.cable_scale"] = "3", "%s: stock[2].unlock.item.cable_scale: 정수" % SH)
	_rejects("unlock 수 소수", func(f): _line(f, 2)["unlock"]["item.cable_scale"] = 2.5, "%s: stock[2].unlock.item.cable_scale: 정수" % SH)
	_rejects("limited 문자열", func(f): _line(f, 12)["limited"] = "yes", "%s: stock[12].limited: true·false" % SH)
	_rejects("item 숫자", func(f): _line(f, 0)["item"] = 5, "%s: stock[0].item: ID 형식" % SH)
	_rejects("줄 객체 아님", func(f): f[SH]["stock"][0] = "equip.training_sword", "%s: stock[0]: 객체여야 한다" % SH)
	_rejects("stock 객체", func(f): f[SH]["stock"] = {}, "%s: stock: 줄이 하나 이상인 배열" % SH)
	_rejects("stock 빈 배열", func(f): f[SH]["stock"] = [], "%s: stock: 줄이 하나 이상인 배열" % SH)
	_rejects("name_key 숫자", func(f): f[SH]["name_key"] = 1, "%s: name_key: 비지 않은 문자열" % SH)
	# ID
	_rejects("id 접두사", func(f): f[SH]["id"] = "junk_workshop", "%s: id: shop. 로 시작" % SH)
	_rejects("id 중복", func(f): f["shop/other.json"] = f[SH].duplicate(true), "shop/other.json: id: ID shop.junk_workshop 가 중복이다(먼저 %s)" % SH)
	_rejects("맨 위 객체 아님", func(f): f[SH] = [], "%s: (맨 위): 맨 위가 객체가 아니다" % SH)


func test_shop_name_key_must_exist_in_text() -> void:
	var texts := TextDb.load_path("res://data/text/ko.json")
	var files := Fx.battle_files()
	files[SH]["name_key"] = "shop.nope"
	var r := GameDefs.from_parts(Fx.floors(), PartyData.parse_dict(Fx.party_dict(), "p.json"), Fx.battle_db(files), texts)
	check(r.errors.any(func(e: String) -> bool: return e.contains("ko.json: shop.nope: 화면 문구가 없다")), "상점 name_key: %s" % str(r.errors))


func test_unstocked_equipment_is_a_warning_not_an_error() -> void:
	var files := Fx.battle_files()
	files[SH]["stock"].remove_at(14)  # 바이저
	var db := Fx.battle_db(files)
	check_eq(db.errors, [] as Array[String], "오류 아님")
	check_eq(db.warnings, ["equip.visor: 어느 상점에도 없는 장비"] as Array[String], "경고 하나")
	files.erase(SH)
	var none := Fx.battle_db(files)
	check(none.ok() and none.shop_ids.is_empty(), "상점 파일이 없어도 읽힌다")
	check_eq(none.warnings.size(), none.equipment_ids.size(), "상점이 없으면 모든 장비가 경고")
