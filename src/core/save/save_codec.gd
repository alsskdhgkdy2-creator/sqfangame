## 저장 JSON 변환·검사·이전. 읽기는 새 상태 객체에서 모든 검사를 끝낸 뒤에만 돌려준다.
class_name SaveCodec
extends RefCounted

const FORMAT := "sqfangame-save"
const SCHEMA := 1
const RULES := "m1"
const MAX_SAFE_INT := 9007199254740992  # 2^53
const MAX_GENERATION := 9007199254740990  # 2^53 − 2: 다음 저장의 +1 까지 실수로 정확하다


class LoadResult:
	extends RefCounted
	var state: ExplorationState
	var error := ""
	var saved_at := ""
	var generation := 0

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


## 정규화한 state 문자열(사전 키 정렬, 집합 배열 정렬).
static func canonical_state(s: ExplorationState) -> String:
	return JSON.stringify(state_to_dict(s), "", true)


## 상태 해시: 정규화한 state 문자열의 SHA-256.
static func state_hash(s: ExplorationState) -> String:
	return canonical_state(s).sha256_text()


## 정확히 20자 "YYYY-MM-DDTHH:MM:SSZ" 꼴이고 실제 달력·시각 범위 안인지(PCRE $ 는 끝 줄바꿈 앞에서도 맞으므로 길이를 먼저 본다).
static func is_utc_time(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or v.length() != 20:
		return false
	var m := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})Z$").search(v)
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
		members.append({"id": m.id, "hp": m.hp})
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
static func decode(text: String, floor_def: FloorModel, members_def: Array[PartyState.Member]) -> LoadResult:
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
	doc = migrate(doc)
	var s := ExplorationState.new()
	r.error = _read_state(doc["state"], floor_def, members_def, s)
	if not r.error.is_empty():
		return r
	s.generation = to_int(doc["generation"])
	r.state = s
	r.saved_at = doc["saved_at"]
	r.generation = s.generation
	return r


## 이전 schema를 지금 판으로 옮긴다(지금은 1 → 1).
static func migrate(doc: Dictionary) -> Dictionary:
	return doc


static func _check_header(doc: Dictionary) -> String:
	if not _is_str(doc.get("format"), FORMAT):
		return "저장 형식(format)이 다르다"
	var schema: Variant = to_int(doc.get("schema"))
	if schema == null or schema < 1 or schema > SCHEMA:
		return "지원하지 않는 schema 다"
	if not _is_str(doc.get("rules"), RULES):
		return "규칙 판(rules)이 다르다"
	if not is_utc_time(doc.get("saved_at")):
		return "saved_at 이 YYYY-MM-DDTHH:MM:SSZ 꼴의 실제 UTC 시각이 아니다"
	var gen: Variant = to_int(doc.get("generation"))
	if gen == null or gen < 0 or gen > MAX_GENERATION:
		return "generation 이 0 ~ 2^53 − 2 정수가 아니다"
	if typeof(doc.get("state")) != TYPE_DICTIONARY:
		return "state 가 없다"
	return ""


static func _read_state(d: Dictionary, f: FloorModel, members_def: Array[PartyState.Member], s: ExplorationState) -> String:
	if not _is_str(d.get("floor"), f.id):
		return "알 수 없는 층이다: %s" % str(d.get("floor"))
	s.floor_def = f
	s.annotation = MapAnnotation.new(f.width, f.height)
	var err := _read_party(d, s, members_def)
	for part in ["world", "knowledge", "annotation", "encounter", "misc"]:
		if not err.is_empty():
			return err
		err = _read_part(part, d, s)
	return err if not err.is_empty() else _check_consistency(s)


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


static func _read_party(d: Dictionary, s: ExplorationState, members_def: Array[PartyState.Member]) -> String:
	var p := _dict(d, "party")
	var at := _cell_pair(p.get("at"), s.floor_def)
	if not s.floor_def.is_cell(at):
		return "party.at 이 층의 칸이 아니다"
	s.party.at = at
	s.party.facing = Dir.from_name(p.get("facing"))
	if s.party.facing < 0:
		return "party.facing 이 N·E·S·W 가 아니다"
	if typeof(p.get("members")) != TYPE_ARRAY or p["members"].size() != members_def.size():
		return "party.members 가 정의 데이터의 %d명과 다르다" % members_def.size()
	for i in members_def.size():
		var m: Variant = p["members"][i]
		var def := members_def[i]
		if typeof(m) != TYPE_DICTIONARY or not _is_str(m.get("id"), def.id):
			return "party.members[%d] 의 id 가 정의 데이터(%s)와 다르다" % [i, def.id]
		var hp: Variant = to_int(m.get("hp"))
		if hp == null or hp < 0 or hp > def.max_hp:
			return "party.members[%d].hp 가 0~%d 정수가 아니다" % [i, def.max_hp]
		s.party.members.append(PartyState.Member.new(def.id, def.max_hp, hp))
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
		return "전멸 상태에서 전투 대기일 수 없다"
	if s.encounter.pending != (s.encounter.danger >= s.encounter.threshold):
		return "전투 대기(pending)와 위험도 ≥ 한계값이 맞지 않다"
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
