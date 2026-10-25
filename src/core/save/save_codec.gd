## 저장 JSON 변환·검사·이전(06 §8.4~§8.6, 3판 07 §8, 4판 08 §4). 읽기는 새 상태 객체에서 모든 검사를 끝낸 뒤에만 돌려준다.
class_name SaveCodec
extends RefCounted

const FORMAT := "sqfangame-save"
const SCHEMA := 4
const RULES := "m3s"
## 받는 (schema, rules) 쌍(06 §8.5, 07 §8.2, 08 §4). 1·2·3판은 읽을 때 4판으로 바로 옮긴다(07 §8.4, 08 §4).
const ACCEPTED := {1: "m1", 2: "m2", 3: "m2g", 4: "m3s"}
## 1판 검사에 쓰는 옛 대원 표(06 §8.6 2단계): [id, 최대 HP], 칸 순서.
const V1_MEMBERS := [["holo_knight", 60], ["blade_duelist", 52], ["rail_ranger", 46], ["nano_medic", 42], ["glyph_wizard", 40]]
## 2판 검사에 쓰는 고정 대원 표(07 §8.4 2단계): [id, 최대 HP, 최대 TP], 칸 순서(06 §6.1). 정의에서 읽지 않는다.
const V2_MEMBERS := [["holo_knight", 60, 30], ["blade_duelist", 52, 32], ["blade_duelist_2", 52, 32], ["nano_medic", 42, 54], ["glyph_wizard", 40, 60]]
## 3판 대원 객체의 키(07 §8.3).
const MEMBER_KEYS := ["id", "hp", "tp", "level", "exp", "skills", "equip"]
## 4판 shop 객체의 키(08 §4).
const SHOP_KEYS := ["sold", "pool", "bought"]
const MAX_SAFE_INT := 9007199254740992  # 2^53
const MAX_GENERATION := 9007199254740990  # 2^53 − 2: 다음 저장의 +1 까지 실수로 정확하다


class LoadResult:
	extends RefCounted
	var state: ExplorationState
	var error := ""
	var saved_at := ""
	var generation := 0
	## 읽은 원본의 schema(1·2·3 이면 이전한 결과다).
	var from_schema := 0

	func ok() -> bool:
		return error.is_empty() and state != null


# ---- 숫자 ----

## JSON 값 → 정수. 정수와 같은 실수만 받고(2.9·true·문자열 거부) 아니면 null.
static func to_int(v: Variant) -> Variant:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) != TYPE_FLOAT or not is_finite(v) or v != floorf(v) or absf(v) > MAX_SAFE_INT:
		return null
	return int(v)


## 부호 있는 64비트 10진 표준 표기 → 정수. 실수를 거치지 않는다. 아니면 null.
static func parse_int64(s: Variant) -> Variant:
	if typeof(s) != TYPE_STRING:
		return null
	var digits: String = s.trim_prefix("-")
	if digits.is_empty() or digits.length() > 19 or not s.is_valid_int():
		return null
	if digits.length() == 19:
		var limit := "9223372036854775808" if s.begins_with("-") else "9223372036854775807"
		if digits > limit:
			return null
	var v: int = s.to_int()
	return v if str(v) == s else null


# ---- 쓰기 ----

## 저장 문서 전체(JSON 문자열). generation 을 주지 않으면 상태의 값을 그대로 쓴다(내보내기는 올리지 않는다).
static func encode(s: ExplorationState, saved_at: String = "", generation: int = -1) -> String:
	var doc := {
		"format": FORMAT, "schema": SCHEMA, "rules": RULES,
		"saved_at": saved_at if not saved_at.is_empty() else now_utc(),
		"generation": generation if generation >= 0 else s.generation,
		"state": state_to_dict(s),
	}
	return JSON.stringify(doc, "", true)


## 정규화한 state 문자열(사전 키 정렬, 집합 배열 정렬. shop.bought 도 정렬한 배열).
static func canonical_state(s: ExplorationState) -> String:
	return JSON.stringify(state_to_dict(s), "", true)


## 상태 해시: 정규화한 state 문자열의 SHA-256.
static func state_hash(s: ExplorationState) -> String:
	return canonical_state(s).sha256_text()


## 정확히 20자 "YYYY-MM-DDTHH:MM:SSZ" 꼴이고 실제 달력·시각 범위 안인지(PCRE $ 는 끝 줄바꿈 앞에서도 맞으므로 길이를 먼저 본다).
static func is_utc_time(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or v.length() != 20:
		return false
	var m := RegEx.create_from_string("\\A(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})Z\\z").search(v)
	if m == null:
		return false
	var y := m.get_string(1).to_int()
	var mo := m.get_string(2).to_int()
	var d := m.get_string(3).to_int()
	if mo < 1 or mo > 12 or d < 1 or d > _days_in_month(y, mo):
		return false
	return m.get_string(4).to_int() < 24 and m.get_string(5).to_int() < 60 and m.get_string(6).to_int() < 60


static func _days_in_month(y: int, mo: int) -> int:
	if mo == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if mo in [4, 6, 9, 11] else 31


static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


static func state_to_dict(s: ExplorationState) -> Dictionary:
	var members: Array = []
	for m in s.party.members:
		var equip := []
		for id in m.equip:
			equip.append(id if not id.is_empty() else null)
		members.append({"id": m.id, "hp": m.hp, "tp": m.tp, "level": m.level, "exp": m.exp, "skills": m.skills.duplicate(), "equip": equip})
	var k_edges := {}
	for e in s.knowledge.edges:
		k_edges[GridKey.edge(e)] = s.knowledge.edges[e]
	var a := s.annotation
	var a_floors := {}
	for c in a.floors:
		a_floors[GridKey.cell(c)] = a.floors[c]
	var a_edges := {}
	for e in a.edges:
		a_edges[GridKey.edge(e)] = a.edges[e]
	var icons := {}
	for c in a.icons:
		var icon: Dictionary = a.icons[c]
		icons[GridKey.cell(c)] = {"type": icon["type"], "dir": Dir.name_of(icon["dir"])} if icon["type"] == "arrow" else {"type": icon["type"]}
	var memos := {}
	for c in a.memos:
		memos[GridKey.cell(c)] = a.memos[c]
	return {
		"floor": s.floor_def.id,
		"party": {"at": [s.party.at.x, s.party.at.y], "facing": Dir.name_of(s.party.facing), "members": members},
		"world": {"shortcuts_open": _edge_set(s.world.shortcuts_open), "passages_found": _edge_set(s.world.passages_found)},
		"knowledge": {"visited": _cell_set(s.knowledge.visited), "edges": k_edges},
		"annotation": {"floors": a_floors, "edges": a_edges, "auto_edges": _edge_set(a.auto_edges), "icons": icons, "memos": memos},
		"encounter": {"danger": s.encounter.danger, "threshold": s.encounter.threshold, "pending": s.encounter.pending},
		"materials": s.materials.duplicate(),
		"gear_bag": s.gear_bag.duplicate(),
		"money": s.money,
		"shop": {"sold": s.shop.sold.duplicate(), "pool": s.shop.pool.duplicate(), "bought": s.shop.bought_list()},
		"battle": s.battle.to_dict() if s.battle != null else null,
		"rng": {"state": str(s.rng.get_state())},
		"steps": s.steps,
		"wiped": s.wiped,
	}


static func _edge_set(d: Dictionary) -> Array[String]:
	return GridKey.sorted(d.keys().map(func(e: Vector3i) -> String: return GridKey.edge(e)))


static func _cell_set(d: Dictionary) -> Array[String]:
	return GridKey.sorted(d.keys().map(func(c: Vector2i) -> String: return GridKey.cell(c)))


# ---- 읽기 ----

## 저장 문서를 읽어 새 상태를 만든다. 실패하면 error만 있고 state는 null.
## 입력 글과 defs 만 읽고 공유 상태를 바꾸지 않는다. 1·2·3판은 07 §8.4·08 §4 순서로 옮긴 뒤 4판 검사를 다시 거친다.
static func decode(text: String, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		r.error = "JSON 읽기 실패 (%d줄): %s" % [json.get_error_line() + 1, json.get_error_message()]
		return r
	if typeof(json.data) != TYPE_DICTIONARY:
		r.error = "맨 위가 객체가 아니다"
		return r
	var doc: Dictionary = json.data
	r.error = _check_header(doc)
	if not r.error.is_empty():
		return r
	match to_int(doc["schema"]):
		1:
			return migrate_v1(doc, defs)
		2:
			return migrate_v2(doc, defs)
		3:
			return migrate_v3(doc, defs)
	var s := ExplorationState.new()
	r.error = _read_state(doc["state"], defs, [], SCHEMA, s)
	if not r.error.is_empty():
		return r
	s.generation = to_int(doc["generation"])
	r.state = s
	r.saved_at = doc["saved_at"]
	r.generation = s.generation
	r.from_schema = SCHEMA
	return r


## 1판 → 4판(07 §8.4·08 §4, 2·3판 문서를 거치지 않는다). doc 은 머리 검사를 통과한 1판 문서.
## ① 1판 원본을 옛 대원 표로 다 검사 ② 통과한 임시 상태에서만 대원 ID·성장 기본값·최대치·HP 비율을 옮기고 시작 소지금·빈 상점을 넣는다
## ③ pending 이면 성장 값이 들어간 임시 상태의 난수로 전투를 정확히 한 번 연다 ④ 원본 saved_at·generation 으로 4판 encode
## ⑤ 4판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v1(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var table := []
	for x in V1_MEMBERS:
		table.append({"id": x[0], "max_hp": x[1], "max_tp": 0})
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, table, 1, old)
	if not err.is_empty():
		r.error = "1판 검사 실패: " + err
		return r
	if defs.party.ids.size() != V1_MEMBERS.size():
		r.error = "1판 이전 실패: 지금 파티가 %d명이 아니다" % V1_MEMBERS.size()
		return r
	var members: Array[PartyState.Member] = []
	for i in V1_MEMBERS.size():
		var hp := old.party.members[i].hp
		var old_max: int = V1_MEMBERS[i][1]
		var m := GrowthRules.start_member(defs, i)
		m.hp = (hp * m.max_hp + old_max - 1) / old_max
		members.append(m)
	old.party.members = members
	old.defs = defs
	old.materials = {}
	old.gear_bag = {}
	_fill_shop(old)
	old.battle = null
	if old.encounter.pending:
		var ev := BattleRules.start(old, BattleRules.pick_formation(old))
		if ev[0]["type"] != "battle_start":
			r.error = "1판 이전 실패: 전투를 열 수 없다 (%s)" % ev[0].get("reason", "")
			return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "1판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 1
	return again


## 2판 → 4판(07 §8.4·08 §4, 3판 문서를 거치지 않는다). doc 은 머리 검사를 통과한 2판 문서.
## ① 2판 원본을 고정 2판 대원 표로 다 검사(battle 은 check_dict 로 검사만) ② 대원을 성장 기본값으로 옮기고 HP·TP 는 새 최대로 자름,
## 시작 소지금·빈 상점 ③ 2판 battle 이 있으면 옮긴 대원으로 from_dict(난수 없음, 전투를 새로 열지 않는다) ④ 원본 saved_at·generation 으로 4판 encode
## ⑤ 4판 읽기를 그대로 거친 결과만 돌려준다. 시작 배분에 없는 스킬(글리프 위저드의 부식 글리프)은 잃는다(07 §8.4 이전 정책).
static func migrate_v2(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var table := []
	for x in V2_MEMBERS:
		table.append({"id": x[0], "max_hp": x[1], "max_tp": x[2]})
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, table, 2, old)
	if not err.is_empty():
		r.error = "2판 검사 실패: " + err
		return r
	if Array(defs.party.ids) != V2_MEMBERS.map(func(x: Array) -> String: return x[0]):
		r.error = "2판 이전 실패: 지금 파티가 2판 파티(%d명)와 다르다" % V2_MEMBERS.size()
		return r
	var members: Array[PartyState.Member] = []
	for i in V2_MEMBERS.size():
		var m := GrowthRules.start_member(defs, i)
		m.hp = mini(old.party.members[i].hp, m.max_hp)
		m.tp = mini(old.party.members[i].tp, m.max_tp)
		members.append(m)
	old.party.members = members
	old.gear_bag = {}
	_fill_shop(old)
	var bd: Variant = doc["state"]["battle"]
	if bd != null:
		old.battle = BattleState.from_dict(bd, defs, members)
		if old.battle == null:
			r.error = "2판 이전 실패: 전투를 옮길 수 없다"
			return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "2판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 2
	return again


## 3판 → 4판(08 §4). doc 은 머리 검사를 통과한 3판 문서.
## ① 3판 원본을 3판 규칙으로 다 검사(전투 객체도 만든다) ② 통과한 임시 상태에 시작 소지금·빈 상점
## ③ 원본 saved_at·generation 으로 4판 encode ④ 4판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v3(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 3, old)
	if not err.is_empty():
		r.error = "3판 검사 실패: " + err
		return r
	_fill_shop(old)
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "3판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 3
	return again


## 이전한 상태의 상점 몫(08 §4 2단계): 시작 소지금, 빈 상점.
static func _fill_shop(s: ExplorationState) -> void:
	s.money = ExplorationState.START_MONEY
	s.shop = ShopState.new()


static func _check_header(doc: Dictionary) -> String:
	if not _is_str(doc.get("format"), FORMAT):
		return "저장 형식(format)이 다르다"
	var schema: Variant = to_int(doc.get("schema"))
	if schema == null or not ACCEPTED.has(schema):
		return "지원하지 않는 schema 다"
	if not _is_str(doc.get("rules"), ACCEPTED[schema]):
		return "규칙 판(rules)이 schema %d 와 맞지 않다" % schema
	if not is_utc_time(doc.get("saved_at")):
		return "saved_at 이 YYYY-MM-DDTHH:MM:SSZ 꼴의 실제 UTC 시각이 아니다"
	var gen: Variant = to_int(doc.get("generation"))
	if gen == null or gen < 0 or gen > MAX_GENERATION:
		return "generation 이 0 ~ 2^53 - 2 정수가 아니다"
	if typeof(doc.get("state")) != TYPE_DICTIONARY:
		return "state 가 없다"
	return ""


## schema 1·2: table 은 대원마다 {id, max_hp, max_tp}(고정 표). schema 2 부터 대원 tp·materials·battle 도 읽는다.
## schema 3: 대원 성장 필드를 먼저 읽어 최대 HP·TP 를 정한 뒤 hp·tp·battle 을 본다(07 §8.3). gear_bag 도 읽는다.
## schema 4: gear_bag 다음에 money·shop 을 읽는다(08 §4).
## schema 2 의 battle 은 검사만 하고 만들지 않는다(옮긴 대원으로 migrate_v2 가 만든다).
static func _read_state(d: Dictionary, defs: GameDefs, table: Array, schema: int, s: ExplorationState) -> String:
	var f := defs.floor_def
	if not _is_str(d.get("floor"), f.id):
		return "알 수 없는 층이다: %s" % str(d.get("floor"))
	s.floor_def = f
	s.annotation = MapAnnotation.new(f.width, f.height)
	s.defs = defs
	var err := _read_party(d, s, table, schema)
	for part in ["world", "knowledge", "annotation", "encounter", "misc"]:
		if not err.is_empty():
			return err
		err = _read_part(part, d, s)
	if not err.is_empty():
		return err
	err = _check_consistency(s)
	if not err.is_empty() or schema == 1:
		return err
	err = _read_materials(d, defs, s)
	if not err.is_empty():
		return err
	if schema >= 3:
		err = _read_gear_bag(d, defs, s)
		if not err.is_empty():
			return err
	if schema >= 4:
		err = _read_money(d, s)
		if err.is_empty():
			err = _read_shop(d, defs, s)
		if not err.is_empty():
			return err
	if not d.has("battle"):
		return "battle 이 없다(전투가 없으면 null)"
	if d["battle"] != null:
		err = BattleState.check_dict(d["battle"], defs, s.party.members)
		if not err.is_empty():
			return err
		if schema >= 3:
			s.battle = BattleState.from_dict(d["battle"], defs, s.party.members)
	if s.encounter.pending != (d["battle"] != null):
		return "전투 대기(pending)와 battle 이 맞지 않다"
	return ""


static func _read_gear_bag(d: Dictionary, defs: GameDefs, s: ExplorationState) -> String:
	if typeof(d.get("gear_bag")) != TYPE_DICTIONARY:
		return "gear_bag 이 객체가 아니다"
	for k in d["gear_bag"]:
		if typeof(k) != TYPE_STRING or defs.battle.equip(k) == null:
			return "gear_bag 의 %s 는 모르는 장비다" % str(k)
		var n: Variant = to_int(d["gear_bag"][k])
		if not BattleLimits.in_range("bag", n):
			return "gear_bag.%s 가 정수 %s 가 아니다" % [k, BattleLimits.range_text("bag")]
		s.gear_bag[k] = n
	return ""


static func _read_money(d: Dictionary, s: ExplorationState) -> String:
	var n: Variant = to_int(d.get("money"))
	if not BattleLimits.in_range("money", n):
		return "money 가 정수 %s 가 아니다" % BattleLimits.range_text("money")
	s.money = n
	return ""


## 4판 shop(08 §4): 키가 정확히 sold·pool·bought. sold·pool 은 아는 소재 → 범위 안 정수, pool 의 키는 sold 에도 있고 pool ≤ sold.
## bought 는 서로 겹치지 않는 아는 장비 ID 문자열의 배열(차례는 보지 않는다. 쓸 때 정렬한다).
static func _read_shop(d: Dictionary, defs: GameDefs, s: ExplorationState) -> String:
	var v: Variant = d.get("shop")
	if typeof(v) != TYPE_DICTIONARY:
		return "shop 이 객체가 아니다"
	for k in SHOP_KEYS:
		if not v.has(k):
			return "shop.%s 가 없다" % k
	for k in v:
		if not SHOP_KEYS.has(k):
			return "shop.%s 는 모르는 필드다" % str(k)
	var shop := ShopState.new()
	for part in ["sold", "pool"]:
		if typeof(v[part]) != TYPE_DICTIONARY:
			return "shop.%s 가 객체가 아니다" % part
		var out: Dictionary = shop.get(part)
		for k in v[part]:
			if typeof(k) != TYPE_STRING or not defs.battle.materials.has(k):
				return "shop.%s 의 %s 는 모르는 소재다" % [part, str(k)]
			var n: Variant = to_int(v[part][k])
			if not BattleLimits.in_range("sold", n):
				return "shop.%s.%s 가 정수 %s 가 아니다" % [part, k, BattleLimits.range_text("sold")]
			out[k] = n
	for k in shop.pool:
		if not shop.sold.has(k):
			return "shop.pool.%s 가 shop.sold 에 없다" % k
		if shop.pool[k] > shop.sold[k]:
			return "shop.pool.%s 가 shop.sold.%s(%d)보다 크다" % [k, k, shop.sold[k]]
	if typeof(v["bought"]) != TYPE_ARRAY:
		return "shop.bought 가 배열이 아니다"
	for id in v["bought"]:
		if typeof(id) != TYPE_STRING or defs.battle.equip(id) == null:
			return "shop.bought 의 %s 는 모르는 장비다" % str(id)
		if shop.bought.has(id):
			return "shop.bought 에 %s 가 두 번 있다" % id
		shop.bought[id] = true
	s.shop = shop
	return ""


static func _read_materials(d: Dictionary, defs: GameDefs, s: ExplorationState) -> String:
	if typeof(d.get("materials")) != TYPE_DICTIONARY:
		return "materials 가 객체가 아니다"
	for k in d["materials"]:
		if typeof(k) != TYPE_STRING or not defs.battle.materials.has(k):
			return "materials 의 %s 는 모르는 소재다" % str(k)
		var n: Variant = to_int(d["materials"][k])
		if not BattleLimits.in_range("material", n):
			return "materials.%s 가 정수 %s 가 아니다" % [k, BattleLimits.range_text("material")]
		s.materials[k] = n
	return ""


static func _read_part(part: String, d: Dictionary, s: ExplorationState) -> String:
	match part:
		"world":
			return _read_world(d, s)
		"knowledge":
			return _read_knowledge(d, s)
		"annotation":
			return _read_annotation(d, s)
		"encounter":
			return _read_encounter(d, s)
		_:
			return _read_misc(d, s)


## 자료형이 다른 값끼리 == 를 쓰지 않도록 문자열인지 먼저 본다.
static func _is_str(v: Variant, expected: String) -> bool:
	return typeof(v) == TYPE_STRING and v == expected


static func _dict(d: Dictionary, key: String) -> Dictionary:
	return d[key] if typeof(d.get(key)) == TYPE_DICTIONARY else {}


static func _read_party(d: Dictionary, s: ExplorationState, table: Array, schema: int) -> String:
	var p := _dict(d, "party")
	var at := _cell_pair(p.get("at"), s.floor_def)
	if not s.floor_def.is_cell(at):
		return "party.at 이 층의 칸이 아니다"
	s.party.at = at
	s.party.facing = Dir.from_name(p.get("facing"))
	if s.party.facing < 0:
		return "party.facing 이 N·E·S·W 가 아니다"
	if schema >= 3:
		return _read_members_v3(p, s)
	if typeof(p.get("members")) != TYPE_ARRAY or p["members"].size() != table.size():
		return "party.members 가 정의 데이터의 %d명과 다르다" % table.size()
	for i in table.size():
		var m: Variant = p["members"][i]
		var def: Dictionary = table[i]
		if typeof(m) != TYPE_DICTIONARY or not _is_str(m.get("id"), def["id"]):
			return "party.members[%d] 의 id 가 정의 데이터(%s)와 다르다" % [i, def["id"]]
		var hp: Variant = to_int(m.get("hp"))
		if hp == null or hp < 0 or hp > def["max_hp"]:
			return "party.members[%d].hp 가 0~%d 정수가 아니다" % [i, def["max_hp"]]
		var tp: Variant = 0
		if schema >= 2:
			tp = to_int(m.get("tp"))
			if tp == null or tp < 0 or tp > def["max_tp"]:
				return "party.members[%d].tp 가 0~%d 정수가 아니다" % [i, def["max_tp"]]
		s.party.members.append(PartyState.Member.new(def["id"], def["max_hp"], hp, def["max_tp"], tp))
	return ""


## 3판 대원(07 §8.3): 키가 정확히 MEMBER_KEYS, 성장 필드를 먼저 읽고 검사한 뒤(최대 HP·TP 가 여기서 정해진다) hp·tp.
## 배운 스킬·장비 판정은 배분·장착 규칙과 같은 함수(GrowthRules.skills_problem·equip_problem)다.
static func _read_members_v3(p: Dictionary, s: ExplorationState) -> String:
	var defs := s.defs
	var db := defs.battle
	var g := db.growth
	var n := defs.party.ids.size()
	if typeof(p.get("members")) != TYPE_ARRAY or p["members"].size() != n:
		return "party.members 가 정의 데이터의 %d명과 다르다" % n
	for i in n:
		var m: Variant = p["members"][i]
		var path := "party.members[%d]" % i
		if typeof(m) != TYPE_DICTIONARY or not _is_str(m.get("id"), defs.party.ids[i]):
			return "%s 의 id 가 정의 데이터(%s)와 다르다" % [path, defs.party.ids[i]]
		for k in MEMBER_KEYS:
			if not m.has(k):
				return "%s.%s 가 없다" % [path, k]
		for k in m:
			if not MEMBER_KEYS.has(k):
				return "%s.%s 는 모르는 필드다" % [path, str(k)]
		var c := defs.class_of(i)
		var level: Variant = to_int(m["level"])
		if level == null or level < 1 or level > g.level_cap:
			return "%s.level 이 정수 1~%d 가 아니다" % [path, g.level_cap]
		var xp: Variant = to_int(m["exp"])
		if not BattleLimits.in_range("exp_total", xp):
			return "%s.exp 가 정수 %s 가 아니다" % [path, BattleLimits.range_text("exp_total")]
		if level < g.level_cap and (xp < g.cum(level) or xp >= g.cum(level + 1)):
			return "%s.exp 가 레벨 %d 의 범위(%d 이상 %d 미만)가 아니다" % [path, level, g.cum(level), g.cum(level + 1)]
		if level == g.level_cap and xp != g.cum(level):
			return "%s.exp 가 레벨 상한의 누적 경험치 %d 이 아니다" % [path, g.cum(level)]
		if typeof(m["skills"]) != TYPE_DICTIONARY:
			return "%s.skills 가 객체가 아니다" % path
		var skills := {}
		for sid in m["skills"]:
			var lv: Variant = to_int(m["skills"][sid])
			if lv == null:
				return "%s.skills.%s 가 정수가 아니다" % [path, str(sid)]
			skills[sid] = lv
		var bad := GrowthRules.skills_problem(db, c, level, skills)
		if not bad.is_empty():
			return "%s.skills%s: %s" % [path, "" if bad[0].is_empty() else "." + bad[0], bad[1]]
		var ev: Variant = m["equip"]
		if typeof(ev) != TYPE_ARRAY or ev.size() != BattleLimits.EQUIP_SLOTS:
			return "%s.equip 이 길이 %d 의 배열이 아니다" % [path, BattleLimits.EQUIP_SLOTS]
		var equip: Array[String] = []
		for j in ev.size():
			if ev[j] == null:
				equip.append("")
			elif typeof(ev[j]) != TYPE_STRING or db.equip(ev[j]) == null:
				return "%s.equip[%d] 가 null 또는 장비 ID 가 아니다" % [path, j]
			else:
				equip.append(ev[j])
		bad = GrowthRules.equip_problem(db, c, equip)
		if not bad.is_empty():
			return "%s.equip[%d]: %s" % [path, bad[0], bad[1]]
		var mem := PartyState.Member.new(defs.party.ids[i])
		mem.level = level
		mem.exp = xp
		mem.skills = skills
		mem.equip = equip
		GrowthRules.refresh_max(defs, i, mem)
		var hp: Variant = to_int(m["hp"])
		if hp == null or hp < 0 or hp > mem.max_hp:
			return "%s.hp 가 0~%d 정수가 아니다" % [path, mem.max_hp]
		var tp: Variant = to_int(m["tp"])
		if tp == null or tp < 0 or tp > mem.max_tp:
			return "%s.tp 가 0~%d 정수가 아니다" % [path, mem.max_tp]
		mem.hp = hp
		mem.tp = tp
		s.party.members.append(mem)
	return ""


static func _read_world(d: Dictionary, s: ExplorationState) -> String:
	var w := _dict(d, "world")
	var err := _read_edge_set(w.get("shortcuts_open"), s.floor_def, FloorModel.Edge.SHORTCUT, s.world.shortcuts_open)
	if not err.is_empty():
		return "world.shortcuts_open: " + err
	err = _read_edge_set(w.get("passages_found"), s.floor_def, FloorModel.Edge.PASSAGE, s.world.passages_found)
	return "" if err.is_empty() else "world.passages_found: " + err


static func _read_knowledge(d: Dictionary, s: ExplorationState) -> String:
	var k := _dict(d, "knowledge")
	if typeof(k.get("visited")) != TYPE_ARRAY or typeof(k.get("edges")) != TYPE_DICTIONARY:
		return "knowledge 에 visited·edges 가 없다"
	for key in k["visited"]:
		var c := GridKey.parse_cell(key) if typeof(key) == TYPE_STRING else GridKey.BAD_CELL
		if not s.floor_def.is_cell(c):
			return "knowledge.visited 의 %s 가 층의 칸이 아니다" % str(key)
		s.knowledge.visit(c)
	for key in k["edges"]:
		var e := GridKey.parse_edge(key)
		var look: Variant = k["edges"][key]
		if not s.floor_def.edge_in_range(e) or not ExplorationKnowledge.LOOKS.has(look):
			return "knowledge.edges 의 %s 가 올바르지 않다" % key
		s.knowledge.see_edge(e, look)
	return ""


static func _read_annotation(d: Dictionary, s: ExplorationState) -> String:
	var a := _dict(d, "annotation")
	var m := s.annotation
	for name in ["floors", "edges", "icons", "memos"]:
		if typeof(a.get(name)) != TYPE_DICTIONARY:
			return "annotation.%s 가 없다" % name
	for key in a["floors"]:
		var c := GridKey.parse_cell(key)
		var color: Variant = to_int(a["floors"][key])
		if not m._cell_ok(c) or color == null or color < 0 or color > 4:
			return "annotation.floors 의 %s 가 올바르지 않다" % key
		m.floors[c] = color
	for key in a["edges"]:
		var e := GridKey.parse_edge(key)
		if not m._edge_ok(e) or not MapAnnotation.EDGE_MARKS.has(a["edges"][key]):
			return "annotation.edges 의 %s 가 올바르지 않다" % key
		m.edges[e] = a["edges"][key]
	if typeof(a.get("auto_edges")) != TYPE_ARRAY:
		return "annotation.auto_edges 가 없다"
	for key in a["auto_edges"]:
		var e := GridKey.parse_edge(key) if typeof(key) == TYPE_STRING else GridKey.BAD_EDGE
		if not m.edges.has(e):
			return "annotation.auto_edges 의 %s 에 경계 표시가 없다" % str(key)
		m.auto_edges[e] = true
	for key in a["icons"]:
		var err := _read_icon(m, key, a["icons"][key])
		if not err.is_empty():
			return err
	for key in a["memos"]:
		var c := GridKey.parse_cell(key)
		var text: Variant = a["memos"][key]
		if not m._cell_ok(c) or typeof(text) != TYPE_STRING or text.is_empty() or text.length() > MapAnnotation.MEMO_MAX:
			return "annotation.memos 의 %s 가 올바르지 않다(1~%d자)" % [key, MapAnnotation.MEMO_MAX]
		m.memos[c] = text
	return ""


static func _read_icon(m: MapAnnotation, key: String, v: Variant) -> String:
	var c := GridKey.parse_cell(key)
	if not m._cell_ok(c) or typeof(v) != TYPE_DICTIONARY or not MapAnnotation.ICONS.has(v.get("type")):
		return "annotation.icons 의 %s 가 올바르지 않다" % key
	var dir := -1
	if v["type"] == "arrow":
		dir = Dir.from_name(v.get("dir"))
		if dir < 0:
			return "annotation.icons 의 %s 화살표 방향이 없다" % key
	m.icons[c] = {"type": v["type"], "dir": dir}
	return ""


static func _read_encounter(d: Dictionary, s: ExplorationState) -> String:
	var e := _dict(d, "encounter")
	var danger: Variant = to_int(e.get("danger"))
	var threshold: Variant = to_int(e.get("threshold"))
	if danger == null or danger < 0:
		return "encounter.danger 가 0 이상 정수가 아니다"
	if threshold == null or threshold < 1:
		return "encounter.threshold 가 1 이상 정수가 아니다"
	if typeof(e.get("pending")) != TYPE_BOOL:
		return "encounter.pending 이 참·거짓이 아니다"
	s.encounter.danger = danger
	s.encounter.threshold = threshold
	s.encounter.pending = e["pending"]
	return ""


static func _read_misc(d: Dictionary, s: ExplorationState) -> String:
	var rng_state: Variant = parse_int64(_dict(d, "rng").get("state"))
	if rng_state == null:
		return "rng.state 가 64비트 정수 10진 문자열이 아니다"
	s.rng.set_state(rng_state)
	var steps: Variant = to_int(d.get("steps"))
	if steps == null or steps < 0:
		return "steps 가 0 이상 정수가 아니다"
	s.steps = steps
	if typeof(d.get("wiped")) != TYPE_BOOL:
		return "wiped 가 참·거짓이 아니다"
	s.wiped = d["wiped"]
	return ""


static func _check_consistency(s: ExplorationState) -> String:
	if s.party.all_down() != s.wiped:
		return "모든 대원 HP 0 과 wiped 가 맞지 않다"
	if s.wiped and s.encounter.pending:
		return "전멸 상태에서 전투 대기일 수 없다(전멸이면 battle 도 없다)"
	if s.encounter.pending != (s.encounter.danger >= s.encounter.threshold):
		return "전투 대기(pending)와 위험도 >= 한계값이 맞지 않다"
	for e in s.knowledge.edges:
		if s.knowledge.edges[e] != ExplorationRules.look_of(s.floor_def, s.world, e):
			return "knowledge.edges 의 %s 겉모습이 세계 상태와 맞지 않다" % GridKey.edge(e)
	return ""


## [x, y] → 칸. 정수 그대로 층 범위를 본 뒤에 Vector2i 로 바꾼다(32비트로 잘리지 않게).
static func _cell_pair(v: Variant, f: FloorModel) -> Vector2i:
	if typeof(v) != TYPE_ARRAY or v.size() != 2:
		return GridKey.BAD_CELL
	var x: Variant = to_int(v[0])
	var y: Variant = to_int(v[1])
	if x == null or y == null or x < 0 or y < 0 or x >= f.width or y >= f.height:
		return GridKey.BAD_CELL
	return Vector2i(x, y)


static func _read_edge_set(v: Variant, f: FloorModel, kind: int, out: Dictionary) -> String:
	if typeof(v) != TYPE_ARRAY:
		return "배열이 아니다"
	for key in v:
		var e := GridKey.parse_edge(key) if typeof(key) == TYPE_STRING else GridKey.BAD_EDGE
		if f.edge_kind(e) != kind or not f.edge_in_range(e):
			return "%s 가 그 종류의 경계가 아니다" % str(key)
		out[e] = true
	return ""
