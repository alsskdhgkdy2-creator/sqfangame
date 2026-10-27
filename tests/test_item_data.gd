extends TestCase
## 소모품 정의 읽기·검사(M3 A4 설계 §2): 실제 여섯, 효과마다 키·쓰는 곳 규칙·범위·접두사·중복, 이름·설명 키, 전투 대리 스킬,
## 상점 진열의 use. 줄. 시험마다 죽이는 변이(설계 §8.1, M-D…)를 적는다.

const Fx := preload("res://tests/fixtures.gd")

const CON := "items/consumables.json"
const SH := "shop/junk_workshop.json"

## 설계 §2.2 표: [ID 꼬리, 값, 효과, 양, HP 천분율, 쓰는 곳, 대리 스킬 대상(전투에서 쓰지 않으면 "")]
const TABLE := [
	["medica", 20, "heal", 50, 0, ["battle", "camp"], "ally_one"],
	["amrita", 100, "tp", 20, 0, ["battle", "camp"], "ally_one"],
	["nectar", 150, "revive", 0, 100, ["battle", "camp"], "ally_dead"],
	["theriaca_a", 40, "cure_ailment", 0, 0, ["battle"], "ally_one"],
	["theriaca_b", 40, "cure_bind", 0, 0, ["battle"], "ally_one"],
	["ariadne_beacon", 150, "return", 0, 0, ["camp"], ""],
]


func _errors_after(mutate: Callable) -> Array[String]:
	var files := Fx.battle_files()
	mutate.call(files)
	return Fx.battle_db(files).errors


func _rejects(label: String, mutate: Callable, needle: String) -> void:
	var errs := _errors_after(mutate)
	check(errs.any(func(e: String) -> bool: return e.begins_with(CON) or e.begins_with(SH)) and errs.any(func(e: String) -> bool: return e.contains(needle)),
		"%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _accepts(label: String, mutate: Callable) -> void:
	check_eq(_errors_after(mutate), [] as Array[String], "%s: 오류 없음" % label)


## files 의 소모품 id 줄 사전.
static func _c(files: Dictionary, id: String) -> Dictionary:
	for c in files[CON]["consumables"]:
		if c["id"] == "use." + id:
			return c
	return {}


# ---- 실제 자료 ----

func test_real_consumables() -> void:
	var db := Fx.battle_db(Fx.battle_files())
	check_eq(db.errors, [] as Array[String], "실제 자료 오류 없음")
	check_eq(db.consumable_ids, TABLE.map(func(r: Array) -> String: return "use." + r[0]), "여섯, 파일 차례")
	for r in TABLE:
		var c := db.consumable("use." + r[0])
		check_eq([c.price, c.effect, c.amount, c.hp_permille, c.where, c.name_key, c.desc_key],
			[r[1], r[2], r[3], r[4], r[5], "use." + r[0], "use." + r[0] + ".desc"], "%s 값" % r[0])
		check_eq(c.target(), "" if r[2] == "return" else r[6], "%s 대상" % r[0])
	check_eq([db.consumable("use.nope"), db.item_skill("use.nope"), db.item_skill("use.ariadne_beacon")], [null, null, null], "모르는 ID·귀환은 대리 스킬 없음")


## M-D2(설명 키를 name_keys 에서 빠뜨림).
func test_name_keys_include_names_and_descs() -> void:
	var keys := Fx.battle_db(Fx.battle_files()).name_keys()
	for r in TABLE:
		check(keys.has("use." + r[0]) and keys.has("use." + r[0] + ".desc"), "%s 이름·설명 키" % r[0])


## M-D4(대리 스킬 속도 1500): 원거리·부위 없음·보통 우선·속도 1000·필중·TP 0, 효과 이름과 줄.
func test_item_skill_shim() -> void:
	var db := Fx.battle_db(Fx.battle_files())
	for r in TABLE:
		var s := db.item_skill("use." + r[0])
		if r[6].is_empty():
			check(s == null, "%s: 대리 스킬 없음" % r[0])
			continue
		check_eq([s.id, s.name_key, s.user, s.range_kind, s.parts, s.priority, s.speed, s.sure_hit, s.target, s.levels.size(), s.levels[0]["tp"]],
			["use." + r[0], "use." + r[0], "item", "ranged", [], "normal", 1000, true, r[6], 1, 0], "%s: 대리 스킬 틀" % r[0])
		check(not db.skills.has(s.id), "%s: 스킬 사전에는 넣지 않는다" % r[0])
	var heal := db.item_skill("use.medica")
	check_eq([heal.effect, heal.levels[0]["base"], heal.levels[0]["wis_pct"]], ["heal", 50, 0], "메디카 = heal 줄 base 50·WIS 0")
	check_eq([db.item_skill("use.amrita").effect, db.item_skill("use.amrita").levels[0]["amount"]], ["tp_heal", 20], "아므리타 = tp_heal 20")
	check_eq([db.item_skill("use.nectar").effect, db.item_skill("use.nectar").levels[0]["hp_permille"]], ["revive", 100], "넥타 = revive 100‰")
	check_eq([db.item_skill("use.theriaca_a").effect, db.item_skill("use.theriaca_b").effect], ["cure_ailment", "cure_bind"], "테리아카 A·B 는 나눈 해제")


# ---- 오류 갈래 ----

func test_keys_per_effect() -> void:
	_rejects("heal 에 amount 없음", func(f): _c(f, "medica").erase("amount"), "consumables[0].amount: 필수 필드가 없다")
	_rejects("heal 에 hp_permille", func(f): _c(f, "medica")["hp_permille"] = 100, "consumables[0].hp_permille: 모르는 필드")
	_rejects("revive 에 amount", func(f): _c(f, "nectar")["amount"] = 5, "consumables[2].amount: 모르는 필드")
	_rejects("return 에 amount", func(f): _c(f, "ariadne_beacon")["amount"] = 1, "consumables[5].amount: 모르는 필드")
	_rejects("desc_key 없음", func(f): _c(f, "amrita").erase("desc_key"), "consumables[1].desc_key: 필수 필드가 없다")
	_rejects("모르는 효과", func(f): _c(f, "medica")["effect"] = "poison", "consumables[0].effect")


## M-D1(return 이 battle 을 가질 수 있음)·M-D5(cure 가 camp 를 가질 수 있음).
func test_where_rules() -> void:
	for w in [["battle", "camp"], ["battle"], ["camp", "battle"]]:
		_rejects("return where %s" % str(w), func(f): _c(f, "ariadne_beacon")["where"] = w, "return 은 [\"camp\"] 만 쓸 수 있다")
	for id in ["theriaca_a", "theriaca_b"]:
		_rejects("%s where camp" % id, func(f): _c(f, id)["where"] = ["battle", "camp"], "camp 에서 쓸 수 없다")
		_rejects("%s where camp 하나" % id, func(f): _c(f, id)["where"] = ["camp"], "camp 에서 쓸 수 없다")
	_rejects("빈 where", func(f): _c(f, "medica")["where"] = [], "consumables[0].where: 값이 하나 이상인 배열이어야 한다")
	_rejects("겹친 where", func(f): _c(f, "medica")["where"] = ["camp", "camp"], "consumables[0].where: 중복 없는")
	_rejects("모르는 where", func(f): _c(f, "medica")["where"] = ["town"], "consumables[0].where: 중복 없는")
	_accepts("메디카는 camp 만도 된다", func(f): _c(f, "medica")["where"] = ["camp"])
	_accepts("넥타는 battle 만도 된다", func(f): _c(f, "nectar")["where"] = ["battle"])


func test_ranges_prefix_and_duplicates() -> void:
	_rejects("값 0", func(f): _c(f, "medica")["price"] = 0, "consumables[0].price: 정수")
	_rejects("양 0", func(f): _c(f, "medica")["amount"] = 0, "consumables[0].amount: 정수 1~999")
	_rejects("양 1000", func(f): _c(f, "amrita")["amount"] = 1000, "consumables[1].amount: 정수 1~999")
	_rejects("양 1.5", func(f): _c(f, "amrita")["amount"] = 1.5, "consumables[1].amount: 정수")
	_rejects("천분율 0", func(f): _c(f, "nectar")["hp_permille"] = 0, "consumables[2].hp_permille: 정수")
	_rejects("천분율 1001", func(f): _c(f, "nectar")["hp_permille"] = 1001, "consumables[2].hp_permille: 정수")
	_accepts("천분율 1000", func(f): _c(f, "nectar")["hp_permille"] = 1000)
	_rejects("접두사 item.", func(f): _c(f, "medica")["id"] = "item.medica", "use. 로 시작하는 ID 여야 한다")
	_rejects("접두사 equip.", func(f): _c(f, "medica")["id"] = "equip.medica", "use. 로 시작하는 ID 여야 한다")
	_rejects("중복", func(f): _c(f, "amrita")["id"] = "use.medica", "ID use.medica 가 중복이다")


# ---- 상점 진열 ----

## M-D3(진열 줄이 equip. 만 받음): use. 줄은 소모품을 찾고, 없으면 「없는 소모품」, 장비 줄은 그대로 「없는 장비」.
func test_stock_lines_take_consumables() -> void:
	var db := Fx.battle_db(Fx.battle_files())
	check(db.shop("shop.junk_workshop").line("use.medica").has("item"), "실제 진열에 메디카 줄")
	_rejects("없는 소모품 줄", func(f): f[SH]["stock"].append({"item": "use.nope"}), "없는 소모품 use.nope")
	_rejects("없는 장비 줄", func(f): f[SH]["stock"].append({"item": "equip.nope"}), "없는 장비 equip.nope")
	_rejects("소재 줄", func(f): f[SH]["stock"].append({"item": "item.neon_rat_tail"}), "equip. 로 시작하는 ID 여야 한다")
	var files := Fx.battle_files()
	files[SH]["stock"] = files[SH]["stock"].filter(func(l: Dictionary) -> bool: return l["item"] != "use.amrita")
	var w := Fx.battle_db(files)
	check(w.errors.is_empty() and w.warnings.has("use.amrita: 어느 상점에도 없는 소모품"), "진열에 없는 소모품은 경고 %s" % str(w.warnings))
