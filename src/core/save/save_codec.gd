## 저장 JSON 변환·검사·이전(06 §8.4~§8.6, 3판 07 §8, 4판 08 §4, 5판 05 §8 M3 A1, 6판 M3 A2, 7판 M3 A3, 8판 M3 A4, 9판 M3 A5, 10판 M3 A6, 11판 M3 A7). 읽기는 새 상태 객체에서 모든 검사를 끝낸 뒤에만 돌려준다.
class_name SaveCodec
extends RefCounted

const FORMAT := "sqfangame-save"
const SCHEMA := 12
const RULES := "m3q"
## 받는 (schema, rules) 쌍(06 §8.5, 07 §8.2, 08 §4). 1~10판은 읽을 때 11판으로 바로 옮긴다(07 §8.4, 08 §4, M3 A1~A7).
## 가방 합계(공용 60칸, D31)는 어느 판에서도 검사하지 않는다: 옛 저장이 60을 넘어도 그대로 읽고(지우지 않는다), 새로 얻는 길만
## BagRules 가 막는다(M3 A4 설계 §3.3). 종류마다의 범위(소모품·장비 1~99, 소재 1~9999)만 본다.
const ACCEPTED := {1: "m1", 2: "m2", 3: "m2g", 4: "m3s", 5: "m3f", 6: "m3t", 7: "m3k", 8: "m3i", 9: "m3g", 10: "m3o", 11: "m3r", 12: "m3q"}
## 7·8판 층 기록의 world 키(M3 A3: 연 잠긴 문·연 보물상자가 더해졌다). 6판까지는 앞의 둘만 보고 다른 키는 보지 않는다.
const WORLD_KEYS_V7 := ["shortcuts_open", "passages_found", "locks_open", "chests_opened"]
## 9판 층 기록의 world 키(M3 A5: 오늘 쓴 채집 횟수 gather_used 가 더해졌다). 정확히 이 다섯이다.
const WORLD_KEYS_V9 := ["shortcuts_open", "passages_found", "locks_open", "chests_opened", "gather_used"]
## 10판 층 기록의 world 키(M3 A6: FOE 상태 foes 가 더해졌다). 정확히 이 여섯이다.
const WORLD_KEYS := ["shortcuts_open", "passages_found", "locks_open", "chests_opened", "gather_used", "foes"]
## 10판 world.foes 의 FOE 하나(M3 A6 설계 §3.3): 정확히 이 일곱 키. 종류마다 받는 state.
const FOE_KEYS := ["at", "facing", "state", "path_i", "dir", "stun", "day"]
const FOE_STATES := {
	"patrol": ["patrol", "return", "join", "battle", "defeated"],
	"chase": ["idle", "patrol", "alert", "chase", "return", "join", "battle", "defeated"],
	"guard": ["idle", "battle", "defeated"],
}
## 5판 층 기록(floor_states.<층 ID>)의 키. 1~4판은 이 셋이 state 바로 아래에 있다(층 하나).
const FLOOR_STATE_KEYS := ["world", "knowledge", "annotation"]
## 1판 검사에 쓰는 옛 대원 표(06 §8.6 2단계): [id, 최대 HP], 칸 순서.
const V1_MEMBERS := [["holo_knight", 60], ["blade_duelist", 52], ["rail_ranger", 46], ["nano_medic", 42], ["glyph_wizard", 40]]
## 2판 검사에 쓰는 고정 대원 표(07 §8.4 2단계): [id, 최대 HP, 최대 TP], 칸 순서(06 §6.1). 정의에서 읽지 않는다.
const V2_MEMBERS := [["holo_knight", 60, 30], ["blade_duelist", 52, 32], ["blade_duelist_2", 52, 32], ["nano_medic", 42, 54], ["glyph_wizard", 40, 60]]
## 3~10판 대원 객체의 키(07 §8.3).
const MEMBER_KEYS := ["id", "hp", "tp", "level", "exp", "skills", "equip"]
## 11판 대원 객체의 키(M3 A7 설계 §3.2): 길드 값(이름·직업·외형·열)이 더해졌다. 파티와 길드가 같은 모양이다.
const MEMBER_KEYS_V11 := ["id", "name", "class", "look", "row", "hp", "tp", "level", "exp", "skills", "equip"]
## 11판 guild 객체의 키.
const GUILD_KEYS := ["members", "serial"]
## 12판 quests 의 의뢰 기록 하나(M3 A8 설계 §3.2): 정확히 이 넷.
const QUEST_ENTRY_KEYS := ["status", "progress", "reports", "day"]
const QUEST_REPORTS_MAX := QuestState.REPORTS_MAX
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
	## 읽은 원본의 schema(1~6 이면 이전한 결과다).
	var from_schema := 0
	## 은퇴한 층(시험 층)에 있던 저장을 새 미궁으로 옮겼는지(M3 A3, 화면이 한 번 알린다).
	var relocated := false

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


## 5판 state(M3 A1): 지금 층(floor)·위치는 전체 몫이고, 세계 상태·방문 기록·지도 그림은 들어가 본 층마다 floor_states.<층 ID> 에 둔다.
## 6판(M3 A2): 파티가 있는 곳(location: town·labyrinth)과 날(day)을 더한다. 7판(M3 A3): 귀중품(key_items, 정렬한 집합 배열).
## 8판(M3 A4): 소모품(consumables, ID → 개수).
static func state_to_dict(s: ExplorationState) -> Dictionary:
	var members: Array = []
	for m in s.party.members:
		members.append(member_to_dict(m))
	var guild: Array = []
	for m in s.guild.members:
		guild.append(member_to_dict(m))
	var floor_states := {}
	for id in s.floor_states:
		floor_states[id] = floor_state_to_dict(s.floor_states[id])
	return {
		"location": s.location,
		"day": s.day,
		"floor": s.floor_def.id,
		"party": {"at": [s.party.at.x, s.party.at.y], "facing": Dir.name_of(s.party.facing), "members": members},
		"guild": {"members": guild, "serial": s.guild.serial},
		"floor_states": floor_states,
		"encounter": {"danger": s.encounter.danger, "threshold": s.encounter.threshold, "pending": s.encounter.pending},
		"materials": s.materials.duplicate(),
		"gear_bag": s.gear_bag.duplicate(),
		"key_items": _str_set(s.key_items),
		"consumables": s.consumables.duplicate(),
		"money": s.money,
		"shop": {"sold": s.shop.sold.duplicate(), "pool": s.shop.pool.duplicate(), "bought": s.shop.bought_list()},
		"battle": s.battle.to_dict() if s.battle != null else null,
		"rng": {"state": str(s.rng.get_state())},
		"steps": s.steps,
		"wiped": s.wiped,
		"quests": quests_to_dict(s),
		"flags": _str_set(s.flags),
	}


## 12판 quests(M3 A8): 의뢰 ID → {status, progress, reports, day}.
static func quests_to_dict(s: ExplorationState) -> Dictionary:
	var out := {}
	for id in s.quests.entries:
		var e: QuestState.Entry = s.quests.entries[id]
		out[id] = {"status": e.status, "progress": e.progress, "reports": e.reports, "day": e.day}
	return out


## 11판 대원 하나(M3 A7). 이름은 등록한 이름, 없으면 null(기본 다섯의 이름 키는 정의에서 온다).
static func member_to_dict(m: PartyState.Member) -> Dictionary:
	var equip := []
	for id in m.equip:
		equip.append(id if not id.is_empty() else null)
	return {"id": m.id, "name": m.name if not m.name.is_empty() else null, "class": m.class_id, "look": m.look, "row": m.row,
		"hp": m.hp, "tp": m.tp, "level": m.level, "exp": m.exp, "skills": m.skills.duplicate(), "equip": equip}


## 한 층 기록 → {world, knowledge, annotation}(4판까지의 같은 이름 객체와 모양이 같다). 7판 world 는 연 잠긴 문·연 상자 id 도,
## 9판 world 는 오늘 쓴 채집 횟수(지점 id → 횟수, 키 정렬)도 쓴다.
static func floor_state_to_dict(r: FloorState) -> Dictionary:
	var k_edges := {}
	for e in r.knowledge.edges:
		k_edges[GridKey.edge(e)] = r.knowledge.edges[e]
	var a := r.annotation
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
		"world": {"shortcuts_open": _edge_set(r.world.shortcuts_open), "passages_found": _edge_set(r.world.passages_found),
			"locks_open": _edge_set(r.world.locks_open), "chests_opened": _str_set(r.world.chests_opened),
			"gather_used": _sorted_counts(r.world.gather_used), "foes": _foe_records(r.world.foes)},
		"knowledge": {"visited": _cell_set(r.knowledge.visited), "edges": k_edges},
		"annotation": {"floors": a_floors, "edges": a_edges, "auto_edges": _edge_set(a.auto_edges), "icons": icons, "memos": memos},
	}


## FOE 상태(M3 A6): id → {at, facing, state, path_i, dir, stun, day}(키 정렬은 직렬화가 한다).
static func _foe_records(foes: Dictionary) -> Dictionary:
	var out := {}
	for id in foes:
		var fs: WorldState.FoeState = foes[id]
		out[id] = {"at": [fs.at.x, fs.at.y], "facing": Dir.name_of(fs.facing), "state": fs.state, "path_i": fs.path_i, "dir": fs.dir,
			"stun": fs.stun, "day": fs.day}
	return out


## 이름 → 정수 사전을 키 차례로(채집 횟수, M3 A5).
static func _sorted_counts(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort()
	var out := {}
	for k in keys:
		out[k] = int(d[k])
	return out


static func _edge_set(d: Dictionary) -> Array[String]:
	return GridKey.sorted(d.keys().map(func(e: Vector3i) -> String: return GridKey.edge(e)))


static func _str_set(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(d.keys())
	out.sort()
	return out


static func _cell_set(d: Dictionary) -> Array[String]:
	return GridKey.sorted(d.keys().map(func(c: Vector2i) -> String: return GridKey.cell(c)))


# ---- 읽기 ----

## 저장 문서를 읽어 새 상태를 만든다. 실패하면 error만 있고 state는 null.
## 입력 글과 defs 만 읽고 공유 상태를 바꾸지 않는다. 1~5판은 07 §8.4·08 §4·M3 A1·A2 순서로 옮긴 뒤 6판 검사를 다시 거친다.
static func decode(text: String, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		r.error = "JSON 읽기 실패 (%d줄): %s" % [json.get_error_line() + 1, json.get_error_message()]
		return r
	if typeof(json.data) != TYPE_DICTIONARY:
		r.error = "맨 위가 객체가 아니다"
		return r
	return _decode_doc(json.data, defs)


## 머리 검사부터 끝까지(decode 의 몸). 옛 저장이 은퇴한 층을 가리키면 새 미궁으로 옮긴다(M3 A3, _relocate).
static func _decode_doc(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	r.error = _check_header(doc)
	if not r.error.is_empty():
		return r
	if _names_retired(doc, defs):
		return _relocate(doc, defs)
	var moved := _migrate(doc, defs)
	if moved != null:
		# M3 A8(설계 §3.3): 옛 판에서 옮긴 저장은 이미 내려가 본 층의 계단 허가를 받는다(진행이 막히지 않게).
		if moved.ok():
			for f in QuestRules.migrated_flags(moved.state):
				moved.state.flags[f] = true
		return moved
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


## 옛 판(1~11)이면 그 판의 이전 결과, 지금 판이면 null.
static func _migrate(doc: Dictionary, defs: GameDefs) -> LoadResult:
	match to_int(doc["schema"]):
		1:
			return migrate_v1(doc, defs)
		2:
			return migrate_v2(doc, defs)
		3:
			return migrate_v3(doc, defs)
		4:
			return migrate_v4(doc, defs)
		5:
			return migrate_v5(doc, defs)
		6:
			return migrate_v6(doc, defs)
		7:
			return migrate_v7(doc, defs)
		8:
			return migrate_v8(doc, defs)
		9:
			return migrate_v9(doc, defs)
		10:
			return migrate_v10(doc, defs)
		11:
			return migrate_v11(doc, defs)
	return null


## 1판 → 5판(07 §8.4·08 §4·M3 A1, 2~4판 문서를 거치지 않는다). doc 은 머리 검사를 통과한 1판 문서.
## ① 1판 원본을 옛 대원 표로 다 검사 ② 통과한 임시 상태에서만 대원 ID·성장 기본값·최대치·HP 비율을 옮기고 시작 소지금·빈 상점을 넣는다
## ③ pending 이면 성장 값이 들어간 임시 상태의 난수로 전투를 정확히 한 번 연다 ④ 원본 saved_at·generation 으로 5판 encode
## ⑤ 5판 읽기를 그대로 거친 결과만 돌려준다.
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


## 2판 → 5판(07 §8.4·08 §4·M3 A1, 3·4판 문서를 거치지 않는다). doc 은 머리 검사를 통과한 2판 문서.
## ① 2판 원본을 고정 2판 대원 표로 다 검사(battle 은 check_dict 로 검사만) ② 대원을 성장 기본값으로 옮기고 HP·TP 는 새 최대로 자름,
## 시작 소지금·빈 상점 ③ 2판 battle 이 있으면 옮긴 대원으로 from_dict(난수 없음, 전투를 새로 열지 않는다) ④ 원본 saved_at·generation 으로 5판 encode
## ⑤ 5판 읽기를 그대로 거친 결과만 돌려준다. 시작 배분에 없는 스킬(글리프 위저드의 부식 글리프)은 잃는다(07 §8.4 이전 정책).
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


## 4판 → 5판(M3 A1). doc 은 머리 검사를 통과한 4판 문서.
## ① 4판 원본을 4판 규칙(층 하나, world·knowledge·annotation 이 state 바로 아래)으로 다 검사 — 그 셋은 그 층(state.floor)의 기록이 된다
## ② 원본 saved_at·generation 으로 5판 encode ③ 5판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v4(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 4, old)
	if not err.is_empty():
		r.error = "4판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "4판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 4
	return again


## 5판 → 6판(M3 A2). doc 은 머리 검사를 통과한 5판 문서. ① 5판 규칙으로 다 검사 ② 원본 saved_at·generation 으로 6판 encode
## (5판 저장은 모두 미궁 안이다: location labyrinth, day 1) ③ 6판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v5(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 5, old)
	if not err.is_empty():
		r.error = "5판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "5판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 5
	return again


## 6판 → 7판(M3 A3). doc 은 머리 검사를 통과한 6판 문서. ① 6판 규칙으로 다 검사 ② 원본 saved_at·generation 으로 7판 encode
## (6판 저장에는 열쇠·잠긴 문·상자가 없다: 빈 key_items·빈 locks_open·chests_opened) ③ 7판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v6(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 6, old)
	if not err.is_empty():
		r.error = "6판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "6판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 6
	return again


## 7판 → 지금 판(M3 A4 에서 8판, A5 부터 9판). doc 은 머리 검사를 통과한 7판 문서. ① 7판 규칙으로 다 검사 ② 원본 saved_at·generation 으로 지금 판 encode
## (7판 저장에는 소모품이 없다: 빈 consumables. 60칸을 넘은 가방도 그대로) ③ 지금 판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v7(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 7, old)
	if not err.is_empty():
		r.error = "7판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "7판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 7
	return again


## 8판 → 9판(M3 A5). doc 은 머리 검사를 통과한 8판 문서. ① 8판 규칙으로 다 검사 ② 원본 saved_at·generation 으로 9판 encode
## (8판 저장에는 채집 기록이 없다: 층 기록마다 빈 gather_used. 60칸을 넘은 가방도 그대로) ③ 9판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v8(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 8, old)
	if not err.is_empty():
		r.error = "8판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "8판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 8
	return again


## 9판 → 10판(M3 A6 설계 §3.4): 9판 규칙으로 다 검사(FOE 는 처음 상태, 파티 칸의 FOE 는 FoeRules.settle 이 비킨다) → 원본 saved_at·generation 으로
## 10판 encode → 10판 읽기를 그대로 거친 결과만 돌려준다. 전투 대기는 인카운트 전투(foe 없음)로 읽힌다.
static func migrate_v9(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 9, old)
	if not err.is_empty():
		r.error = "9판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "9판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 9
	return again


## 10판 → 11판(M3 A7 설계 §3.3): 10판 규칙으로 다 검사(대원은 정의 칸 순서, 길드 값은 기본 다섯의 칸 i 값으로 채운다, 길드는 빔) →
## 원본 saved_at·generation 으로 11판 encode → 11판 읽기를 그대로 거친 결과만 돌려준다.
static func migrate_v10(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 10, old)
	if not err.is_empty():
		r.error = "10판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "10판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 10
	return again


## 11판 → 12판(M3 A8 설계 §3.3): 11판 규칙으로 다 검사 → 원본 saved_at·generation 으로 12판 encode(빈 quests·flags) →
## 12판 읽기를 그대로 거친 결과만 돌려준다. 이미 내려가 본 층의 계단 허가는 _decode_doc 이 이전 결과 모두에 붙인다.
static func migrate_v11(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := ExplorationState.new()
	var err := _read_state(doc["state"], defs, [], 11, old)
	if not err.is_empty():
		r.error = "11판 검사 실패: " + err
		return r
	var again := decode(encode(old, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "11판 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = 11
	return again


## 문서의 지금 층이 지금 묶음에는 없고 은퇴한 묶음(defs.retired)에 있는지(M3 A3). 두 묶음의 층 ID 는 겹치지 않는다(GameDefs 가 본다).
static func _names_retired(doc: Dictionary, defs: GameDefs) -> bool:
	if defs.retired == null:
		return false
	var fv: Variant = doc["state"].get("floor")
	return typeof(fv) == TYPE_STRING and defs.floor_by_id(fv) == null and defs.retired.floor_by_id(fv) != null


## 은퇴한 층(시험 층)의 저장을 새 미궁으로 옮긴다(M3 A3, 설계 §4.3).
## ① 은퇴한 묶음의 정의로 그 판의 길(1~6판 이전 포함)을 그대로 다 검사한다 — 실패하면 「옛 시험 층 저장 검사 실패」, 아무것도 바꾸지 않는다.
## ② 새 상태: 대원(레벨·경험치·스킬·장비·HP·TP)·길드(대기 대원·번호, M3 A7)·소지금·소재·가방·상점·귀중품·날·난수·걸음·한계값은 그대로, 위험도 0, 전투 대기는 버린다.
##    소모품(M3 A4)도 그대로 옮긴다(60칸을 넘은 가방도 지우지 않는다). 마을(첫 층 시작 칸)에 둔다. 전멸한 저장은 첫 층 시작 칸에서 전멸 그대로(전멸 창이 뜬다). 층 기록은 첫 층의 빈 것 하나 —
##    시험 층의 세계·방문 기록·지도 그림은 남지 않는다(화면이 알린다).
## ③ 원본 saved_at·generation 으로 지금 판 encode → 지금 정의로 다시 읽은 결과만 돌려준다(from_schema 는 원본 판, relocated 참).
static func _relocate(doc: Dictionary, defs: GameDefs) -> LoadResult:
	var r := LoadResult.new()
	var old := _decode_doc(doc, defs.retired)
	if not old.ok():
		r.error = "옛 시험 층 저장 검사 실패: " + old.error
		return r
	var o := old.state
	var n := ExplorationState.new()
	var first := defs.first_floor()
	n.defs = defs
	n.enter_floor(first)
	n.party.at = first.start_at
	n.party.facing = first.start_facing
	n.party.members = o.party.members
	n.guild = o.guild
	n.materials = o.materials.duplicate()
	n.gear_bag = o.gear_bag.duplicate()
	n.money = o.money
	n.shop = o.shop
	n.key_items = o.key_items.duplicate()
	n.consumables = o.consumables.duplicate()
	n.day = o.day
	n.rng.set_state(o.rng.get_state())
	n.steps = o.steps
	n.encounter.threshold = o.encounter.threshold
	n.wiped = o.wiped
	n.location = ExplorationState.LABYRINTH if o.wiped else ExplorationState.TOWN
	var again := decode(encode(n, doc["saved_at"], to_int(doc["generation"])), defs)
	if not again.ok():
		r.error = "옛 시험 층 저장 이전 결과 검사 실패: " + again.error
		return r
	again.from_schema = old.from_schema
	again.relocated = true
	return again


## 3판 → 5판(08 §4, 4판 문서를 거치지 않는다). doc 은 머리 검사를 통과한 3판 문서.
## ① 3판 원본을 3판 규칙으로 다 검사(전투 객체도 만든다) ② 통과한 임시 상태에 시작 소지금·빈 상점
## ③ 원본 saved_at·generation 으로 5판 encode ④ 5판 읽기를 그대로 거친 결과만 돌려준다.
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
## schema 5: 층 기록이 floor_states.<층 ID> 에 있다(M3 A1). 1~4판은 state 바로 아래의 world·knowledge·annotation 이 state.floor 층의 기록이다.
## schema 6: location·day(M3 A2). 마을이면 층이 첫 층·위치가 그 시작 칸이고 전투 대기·전투·전멸이 아니다. 5판 이하는 미궁·1일째.
## schema 7: key_items(M3 A3), 층 기록 world 의 locks_open·chests_opened(키가 정확히 WORLD_KEYS), 열쇠·상자·잠긴 문 맞물림(_check_keys).
## schema 8: consumables(M3 A4). 가방 합계(60칸)는 보지 않는다(옛 저장을 지우지 않는다, 설계 §3.3).
## schema 9: 층 기록 world 의 gather_used(M3 A5, 키가 정확히 WORLD_KEYS_V9 다섯). 7·8판 world 는 정확히 WORLD_KEYS_V7 넷이다.
## schema 10: 층 기록 world 의 foes(M3 A6, 키가 정확히 WORLD_KEYS 여섯), battle.foe(접촉 전투). 9판 이하는 FOE 가 처음 상태이고
## 다 읽은 뒤 FoeRules.settle 이 파티 칸의 FOE 를 비킨다. 10판은 FOE 와 파티·전투의 맞물림(_check_foes)을 본다.
## 위치(party.at)와 전투 편성은 지금 층(state.floor)으로, 층 기록은 각자 그 층으로 검사한다.
## schema 2 의 battle 은 검사만 하고 만들지 않는다(옮긴 대원으로 migrate_v2 가 만든다).
static func _read_state(d: Dictionary, defs: GameDefs, table: Array, schema: int, s: ExplorationState) -> String:
	var f: FloorModel = defs.floor_by_id(d["floor"]) if typeof(d.get("floor")) == TYPE_STRING else null
	if f == null:
		return "알 수 없는 층이다: %s" % str(d.get("floor"))
	s.defs = defs
	s.enter_floor(f)
	var err := _read_location(d, s) if schema >= 6 else ""
	if err.is_empty():
		err = _read_party(d, s, table, schema)
	if err.is_empty():
		err = _read_floor_states(d, s, schema)
	for part in ["encounter", "misc"]:
		if not err.is_empty():
			return err
		err = _read_part(part, d, s)
	if not err.is_empty():
		return err
	err = _check_consistency(s, schema, _is_contact(d, schema))
	if not err.is_empty():
		return err
	if schema == 1:
		FoeRules.settle(s)  # M3 A6: 1판도 9판 이하처럼 파티 칸의 FOE 를 비킨다(아래 schema < 10 과 같다)
		return ""
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
	if schema >= 7:
		err = _read_key_items(d, defs, s)
		if err.is_empty():
			err = _check_keys(s)
		if not err.is_empty():
			return err
	if schema >= 8:
		err = _read_consumables(d, defs, s)
		if not err.is_empty():
			return err
	if not d.has("battle"):
		return "battle 이 없다(전투가 없으면 null)"
	if d["battle"] != null:
		err = BattleState.check_dict(d["battle"], defs, s.party.members, s.floor_def, schema)
		if not err.is_empty():
			return err
		if schema >= 3:
			s.battle = BattleState.from_dict(d["battle"], defs, s.party.members, s.floor_def)
	if s.encounter.pending != (d["battle"] != null):
		return "전투 대기(pending)와 battle 이 맞지 않다"
	if s.in_town():
		if s.floor_def != defs.first_floor() or s.party.at != s.floor_def.start_at:
			return "마을에 있으면 층은 첫 층(%s), 위치는 그 시작 칸이어야 한다" % defs.first_floor().id
		if s.encounter.pending or s.wiped:
			return "마을에서는 전투 대기·전멸일 수 없다"
	if schema < 10:
		FoeRules.settle(s)
		return ""
	err = _check_foes(s)
	if err.is_empty() and schema >= 12:
		err = _read_quests(d, s)
	return err


## 12판 quests·flags(M3 A8 설계 §3.2). 의뢰 ID 는 묶음 정의의 것만(엄격), 수는 정수(1.0 은 1). 기록 사이 맞물림:
## reported 면 reports ≥ 1, 반복하지 않으면 reports ≤ 1(받은 채면 0), day 는 0~state.day 이고 0 ⇔ reports 0, progress 는 0~목표
## (deliver·reported 는 0, reach 는 0~1), 처음 받은 의뢰(reports 0)는 발급 조건이 맞아야 한다(level 조건은 보지 않는다: 편성으로 내려갈 수 있다).
## flags 는 겹치지 않는 아는 플래그(묶음의 의뢰가 주는 것)다. 주는 의뢰를 보고했는지는 보지 않는다: 미궁 안에서 시작한 새 게임과
## 옛 저장 이전은 보고 없이 허가를 가진다(설계 §5.3·§3.3, A8a 에서 설계 §3.2 의 「보고한 의뢰」 검사를 뺐다).
static func _read_quests(d: Dictionary, s: ExplorationState) -> String:
	if not d.has("quests"):
		return "quests 가 없다"
	if typeof(d["quests"]) != TYPE_DICTIONARY:
		return "quests 는 사전이어야 한다"
	if not d.has("flags"):
		return "flags 가 없다"
	if typeof(d["flags"]) != TYPE_ARRAY:
		return "flags 는 배열이어야 한다"
	var qdb := s.defs.quests
	for id in d["quests"]:
		var q: QuestDb.QuestDef = qdb.get_def(id) if typeof(id) == TYPE_STRING else null
		if q == null:
			return "quests 의 %s 는 모르는 의뢰다" % str(id)
		var rec: Variant = d["quests"][id]
		var label := "quests.%s" % id
		if typeof(rec) != TYPE_DICTIONARY:
			return "%s 는 객체여야 한다" % label
		var err := _exact_keys(rec, QUEST_ENTRY_KEYS, label)
		if not err.is_empty():
			return err
		if typeof(rec["status"]) != TYPE_STRING or not QuestState.STATUSES.has(rec["status"]):
			return "%s.status 는 accepted·reported 가운데 하나여야 한다" % label
		var hi := 0 if q.kind == "deliver" or rec["status"] == QuestState.REPORTED else q.count
		var progress: Variant = _int_field(rec["progress"], 0, hi)
		if progress == null:
			return "%s.progress 는 정수 0~%d 이어야 한다" % [label, hi]
		var reports: Variant = _int_field(rec["reports"], 0, QUEST_REPORTS_MAX if q.repeats() else (0 if rec["status"] == QuestState.ACCEPTED else 1))
		if reports == null or (rec["status"] == QuestState.REPORTED and reports < 1):
			return "%s.reports 가 상태·반복과 맞지 않다" % label
		var day: Variant = _int_field(rec["day"], 0, s.day)
		if day == null or (day == 0) != (reports == 0):
			return "%s.day 는 정수 0~%d 이고 보고한 적이 없을 때만 0 이어야 한다" % [label, s.day]
		var e := QuestState.Entry.new()
		e.status = rec["status"]
		e.progress = progress
		e.reports = reports
		e.day = day
		s.quests.entries[id] = e
	for id in s.quests.entries:
		var e: QuestState.Entry = s.quests.entries[id]
		var q := qdb.get_def(id)
		if e.status == QuestState.ACCEPTED and e.reports == 0 and not _unlock_met(s, q):
			return "quests.%s 를 받았는데 발급 조건이 맞지 않다" % id
		# 반복 의뢰를 다시 받은 기록은 다시 열린 날(마지막 보고 날 + days) 이후여야 한다(M3 A8a 검토).
		if e.status == QuestState.ACCEPTED and e.reports > 0 and q.repeats() and s.day < e.day + q.repeat_days:
			return "quests.%s 를 다시 받았는데 아직 다시 열리지 않았다(%d일째부터)" % [id, e.day + q.repeat_days]
	for f in d["flags"]:
		if typeof(f) != TYPE_STRING or not qdb.knows_flag(f):
			return "flags 의 %s 는 모르는 플래그다" % str(f)
		if s.flags.has(f):
			return "flags 에 %s 가 두 번 있다" % f
		s.flags[f] = true
	# 보고한 적이 있는 의뢰의 보수 플래그는 있어야 한다(M3 A8a 검토). 반대(보고 없는 플래그: 미궁 시작·옛 저장 이전)는 받는다.
	for id in s.quests.entries:
		var q := qdb.get_def(id)
		if s.quests.entries[id].reports > 0:
			for f in q.flags:
				if not s.flags.has(f):
					return "quests.%s 를 보고했는데 보수 플래그 %s 가 없다" % [id, f]
	return ""


## 발급 조건(level 은 빼고, 편성으로 내려갈 수 있다): 저장 검사용.
static func _unlock_met(s: ExplorationState, q: QuestDb.QuestDef) -> bool:
	for c in q.unlock:
		if c["kind"] == "level":
			continue
		var one := QuestDb.QuestDef.new()
		one.unlock.append(c)
		if not QuestRules.conditions_met(s, one):
			return false
	return true


## 정수 lo~hi(정수와 같은 실수도 받는다, 참·거짓은 아니다). 아니면 null.
static func _int_field(v: Variant, lo: int, hi: int) -> Variant:
	if typeof(v) == TYPE_BOOL:
		return null
	var n: Variant = to_int(v)
	if n == null or n < lo or n > hi:
		return null
	return n


## 10판 battle 이 접촉 전투(foe 가 있다)인지(M3 A6). 위험도가 한계값 아래여도 전투 대기다(접촉은 위험도를 더하지 않는다).
static func _is_contact(d: Dictionary, schema: int) -> bool:
	return schema >= 10 and typeof(d.get("battle")) == TYPE_DICTIONARY and d["battle"].has("foe")


## 10판 FOE 맞물림(M3 A6 설계 §3.1): join·battle 은 지금 층에서 전투가 있을 때만이고 battle 인 FOE 는 정확히 battle.foe 다.
## 지금 층(미궁)의 살아 있는 FOE 는 파티 칸에 서지 않고, 살아 있는 FOE 둘이 한 칸에 서지 않는다.
static func _check_foes(s: ExplorationState) -> String:
	for fid in s.floor_states:
		var r: FloorState = s.floor_states[fid]
		var here: bool = r == s.floor_states[s.floor_def.id]
		var cells := {}
		var in_battle: Array[String] = []
		for id in r.world.foes:
			var fs: WorldState.FoeState = r.world.foes[id]
			var path := "floor_states.%s.world.foes.%s" % [fid, id]
			if fs.state == "join" or fs.state == "battle":
				if not here or s.battle == null:
					return "%s.state: %s 는 지금 층의 전투 중에만 있을 수 있다" % [path, fs.state]
				if fs.state == "battle":
					in_battle.append(id)
			if not fs.alive():
				if fs.day > s.day:
					return "%s.day: 쓰러진 날 %d 이 지금 날 %d 보다 뒤다" % [path, fs.day, s.day]
				continue
			if cells.has(fs.at):
				return "%s.at: FOE %s 와 같은 칸이다" % [path, cells[fs.at]]
			cells[fs.at] = id
			if here and not s.in_town() and fs.at == s.party.at:
				return "%s.at: 파티가 선 칸이다" % path
		if here and s.battle != null:
			var want: Array[String] = []
			if not s.battle.foe.is_empty():
				want.append(s.battle.foe)
			for j in s.battle.joined:
				want.append(str(j["foe"]))  # 합류한 FOE 도 battle 상태다(M3 A6b)
			in_battle.sort()
			want.sort()
			if in_battle != want:
				return "floor_states.%s.world.foes: battle 상태인 FOE %s 가 전투의 FOE %s 와 맞지 않다" % [fid, str(in_battle), str(want)]
	return ""


## 6판 location·day(M3 A2).
static func _read_location(d: Dictionary, s: ExplorationState) -> String:
	if typeof(d.get("location")) != TYPE_STRING or not ExplorationState.LOCATIONS.has(d["location"]):
		return "location 이 town·labyrinth 가 아니다"
	var day: Variant = to_int(d.get("day")) if typeof(d.get("day")) != TYPE_BOOL else null
	if day == null or day < 1 or day > ExplorationState.DAY_MAX:
		return "day 가 1~%d 정수가 아니다" % ExplorationState.DAY_MAX
	s.location = d["location"]
	s.day = day
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
## bought 는 서로 겹치지 않는 아는 장비·소모품 ID 문자열의 배열(차례는 보지 않는다. 쓸 때 정렬한다. 소모품은 M3 A4: 상점 「아이템」 NEW 표시).
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
		if typeof(id) != TYPE_STRING or (defs.battle.equip(id) == null and defs.battle.consumable(id) == null):
			return "shop.bought 의 %s 는 모르는 장비·소모품이다" % str(id)
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
		"encounter":
			return _read_encounter(d, s)
		_:
			return _read_misc(d, s)


## 층 기록 읽기. schema < 5 는 state 바로 아래 셋이 지금 층 기록이다. 5판은 floor_states: 키는 묶음의 층 ID, 지금 층이 꼭 있고,
## 값은 키가 정확히 world·knowledge·annotation 인 객체이며 각자 그 층 정의로 검사한다.
static func _read_floor_states(d: Dictionary, s: ExplorationState, schema: int) -> String:
	if schema < 5:
		return _read_floor_state(d, s.floor_states[s.floor_def.id], schema)
	var v: Variant = d.get("floor_states")
	if typeof(v) != TYPE_DICTIONARY:
		return "floor_states 가 객체가 아니다"
	if not v.has(s.floor_def.id):
		return "floor_states 에 지금 층 %s 가 없다" % s.floor_def.id
	for id in v:
		var g: FloorModel = s.defs.floor_by_id(id) if typeof(id) == TYPE_STRING else null
		if g == null:
			return "floor_states 의 %s 는 모르는 층이다" % str(id)
		var rv: Variant = v[id]
		if typeof(rv) != TYPE_DICTIONARY:
			return "floor_states.%s 가 객체가 아니다" % id
		for k in FLOOR_STATE_KEYS:
			if not rv.has(k):
				return "floor_states.%s.%s 가 없다" % [id, k]
		for k in rv:
			if not FLOOR_STATE_KEYS.has(k):
				return "floor_states.%s.%s 는 모르는 필드다" % [id, str(k)]
		if not s.floor_states.has(id):
			s.floor_states[id] = FloorState.new(g)
		var err := _read_floor_state(rv, s.floor_states[id], schema)
		if not err.is_empty():
			return "floor_states.%s.%s" % [id, err]
	return ""


static func _read_floor_state(d: Dictionary, r: FloorState, schema: int = SCHEMA) -> String:
	var err := _read_world(d, r, schema)
	if err.is_empty():
		err = _read_knowledge(d, r)
	if err.is_empty():
		err = _read_annotation(d, r)
	return err


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
	if schema >= 11:
		return _read_members_v11(p, d, s)
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
		var mem := PartyState.Member.new(def["id"], def["max_hp"], hp, def["max_tp"], tp)
		if i < s.defs.party.ids.size():
			GrowthRules.fill_default(s.defs, i, mem)  # M3 A7: 1·2판 임시 대원도 칸 i 의 직업·열(이전이 새 대원으로 바꾼다)
		s.party.members.append(mem)
	return ""


## 3~10판 대원(07 §8.3): 키가 정확히 MEMBER_KEYS, 정의 칸 순서의 ID. 길드 값은 기본 다섯의 칸 i 값(M3 A7). 성장 필드는 _read_growth.
static func _read_members_v3(p: Dictionary, s: ExplorationState) -> String:
	var defs := s.defs
	var n := defs.party.ids.size()
	if typeof(p.get("members")) != TYPE_ARRAY or p["members"].size() != n:
		return "party.members 가 정의 데이터의 %d명과 다르다" % n
	for i in n:
		var m: Variant = p["members"][i]
		var path := "party.members[%d]" % i
		if typeof(m) != TYPE_DICTIONARY or not _is_str(m.get("id"), defs.party.ids[i]):
			return "%s 의 id 가 정의 데이터(%s)와 다르다" % [path, defs.party.ids[i]]
		var err := _exact_keys(m, MEMBER_KEYS, path)
		if not err.is_empty():
			return err
		var mem := PartyState.Member.new(defs.party.ids[i])
		GrowthRules.fill_default(defs, i, mem)
		err = _read_growth(m, path, defs, mem)
		if not err.is_empty():
			return err
		s.party.members.append(mem)
	return ""


## 11판 파티·길드(M3 A7 설계 §3.2). 파티 1~5명(전열 먼저, 열마다 ROW_MAX 까지), 길드 대원은 같은 모양, ID 는 명부 전체에서 하나,
## 기본 다섯의 ID 이거나 r<번호>(번호 ≤ serial), 명부 GuildRules.GUILD_MAX 까지, 등록한 이름은 이름 규칙을 지키고 서로 다르다.
static func _read_members_v11(p: Dictionary, d: Dictionary, s: ExplorationState) -> String:
	var g: Variant = d.get("guild")
	if typeof(g) != TYPE_DICTIONARY:
		return "guild 가 객체가 아니다"
	var err := _exact_keys(g, GUILD_KEYS, "guild")
	if not err.is_empty():
		return err
	var serial: Variant = to_int(g["serial"])
	if serial == null or typeof(g["serial"]) == TYPE_BOOL or serial < 0 or serial > GuildRules.SERIAL_MAX:
		return "guild.serial 이 정수 0~%d 가 아니다" % GuildRules.SERIAL_MAX
	s.guild.serial = serial
	var pm: Variant = p.get("members")
	if typeof(pm) != TYPE_ARRAY or pm.is_empty() or pm.size() > BattleLimits.PARTY_SIZE:
		return "party.members 가 1~%d명의 배열이 아니다" % BattleLimits.PARTY_SIZE
	if typeof(g["members"]) != TYPE_ARRAY:
		return "guild.members 가 배열이 아니다"
	if pm.size() + g["members"].size() > GuildRules.GUILD_MAX:
		return "등록한 대원이 %d명을 넘는다" % GuildRules.GUILD_MAX
	var ids := {}
	var names := {}
	for part in [["party.members", pm, s.party.members], ["guild.members", g["members"], s.guild.members]]:
		var list: Array = part[1]
		for i in list.size():
			var path := "%s[%d]" % [part[0], i]
			var mem := PartyState.Member.new()
			err = _read_member_v11(list[i], path, s, mem)
			if not err.is_empty():
				return err
			if ids.has(mem.id):
				return "%s.id %s 가 명부에 둘 있다" % [path, mem.id]
			ids[mem.id] = true
			if not mem.name.is_empty():
				if names.has(mem.name):
					return "%s.name 「%s」 이 명부에 둘 있다" % [path, mem.name]
				names[mem.name] = true
			part[2].append(mem)
	var per_row := {"front": 0, "back": 0}
	for i in s.party.members.size():
		var row := s.party.members[i].row
		per_row[row] += 1
		if row == "front" and per_row["back"] > 0:
			return "party.members[%d] 전열 대원이 후열 대원 뒤에 있다" % i
		if per_row[row] > BattleLimits.ROW_MAX:
			return "party.members: %s 열이 %d명을 넘는다" % [row, BattleLimits.ROW_MAX]
	return ""


## 11판 대원 하나: 키가 정확히 MEMBER_KEYS_V11. 길드 값을 먼저 읽고(직업이 성장 검사의 기준) 성장 필드는 _read_growth.
static func _read_member_v11(m: Variant, path: String, s: ExplorationState, mem: PartyState.Member) -> String:
	var defs := s.defs
	if typeof(m) != TYPE_DICTIONARY:
		return "%s 가 객체가 아니다" % path
	var err := _exact_keys(m, MEMBER_KEYS_V11, path)
	if not err.is_empty():
		return err
	if typeof(m["id"]) != TYPE_STRING:
		return "%s.id 가 문자열이 아니다" % path
	var id: String = m["id"]
	var di := defs.party.ids.find(id)
	var n := GuildRules.recruit_number(id)
	if di < 0 and (n < 1 or n > s.guild.serial):
		return "%s.id %s 가 기본 대원도 r1~r%d 도 아니다" % [path, id, s.guild.serial]
	mem.id = id
	if di >= 0:
		mem.name_key = defs.party.name_keys[di]
	if m["name"] == null:
		if di < 0:
			return "%s.name 이 없다(등록한 대원은 이름이 있어야 한다)" % path
	elif typeof(m["name"]) != TYPE_STRING or not GuildRules.name_problem(m["name"]).is_empty():
		return "%s.name 이 이름 규칙(1~%d자, 한글·영문·숫자, 낱말 사이 공백 하나)에 맞지 않다" % [path, GuildRules.NAME_MAX]
	else:
		mem.name = m["name"]
	if typeof(m["class"]) != TYPE_STRING or not defs.battle.classes.has(m["class"]):
		return "%s.class 가 없는 직업이다: %s" % [path, str(m["class"])]
	mem.class_id = m["class"]
	var look: Variant = to_int(m["look"])
	if look == null or typeof(m["look"]) == TYPE_BOOL or look < 0 or look >= GuildRules.LOOKS:
		return "%s.look 이 정수 0~%d 가 아니다" % [path, GuildRules.LOOKS - 1]
	mem.look = look
	if not BattleDb.ROWS.has(m["row"]):
		return "%s.row 가 front·back 이 아니다" % path
	mem.row = m["row"]
	return _read_growth(m, path, defs, mem)


static func _exact_keys(m: Dictionary, keys: Array, path: String) -> String:
	for k in keys:
		if not m.has(k):
			return "%s.%s 가 없다" % [path, k]
	for k in m:
		if not keys.has(k):
			return "%s.%s 는 모르는 필드다" % [path, str(k)]
	return ""


## 대원 성장 필드(3판부터, 07 §8.3): 레벨·누적 경험치·배운 스킬·장비를 대원 직업(mem.class_id)으로 검사해 넣고, 최대 HP·TP 를 정한 뒤 hp·tp.
## 배운 스킬·장비 판정은 배분·장착 규칙과 같은 함수(GrowthRules.skills_problem·equip_problem)다.
static func _read_growth(m: Dictionary, path: String, defs: GameDefs, mem: PartyState.Member) -> String:
	var db := defs.battle
	var g := db.growth
	var c := defs.class_def(mem)
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
	mem.level = level
	mem.exp = xp
	mem.skills = skills
	mem.equip = equip
	GrowthRules.refresh_max(defs, -1, mem)
	var hp: Variant = to_int(m["hp"])
	if hp == null or hp < 0 or hp > mem.max_hp:
		return "%s.hp 가 0~%d 정수가 아니다" % [path, mem.max_hp]
	var tp: Variant = to_int(m["tp"])
	if tp == null or tp < 0 or tp > mem.max_tp:
		return "%s.tp 가 0~%d 정수가 아니다" % [path, mem.max_tp]
	mem.hp = hp
	mem.tp = tp
	return ""


static func _read_world(d: Dictionary, s: FloorState, schema: int = SCHEMA) -> String:
	var w := _dict(d, "world")
	if schema >= 7:
		if typeof(d.get("world")) != TYPE_DICTIONARY:
			return "world 가 객체가 아니다"
		var wkeys: Array = WORLD_KEYS if schema >= 10 else (WORLD_KEYS_V9 if schema >= 9 else WORLD_KEYS_V7)
		for k in wkeys:
			if not w.has(k):
				return "world.%s 가 없다" % k
		for k in w:
			if not wkeys.has(k):
				return "world.%s 는 모르는 필드다" % str(k)
	var err := _read_edge_set(w.get("shortcuts_open"), s.floor_def, FloorModel.Edge.SHORTCUT, s.world.shortcuts_open)
	if not err.is_empty():
		return "world.shortcuts_open: " + err
	err = _read_edge_set(w.get("passages_found"), s.floor_def, FloorModel.Edge.PASSAGE, s.world.passages_found)
	if not err.is_empty() or schema < 7:
		return "" if err.is_empty() else "world.passages_found: " + err
	err = _read_edge_set(w["locks_open"], s.floor_def, FloorModel.Edge.LOCK, s.world.locks_open)
	if not err.is_empty():
		return "world.locks_open: " + err
	for e in s.world.locks_open:
		if s.floor_def.is_sealed(e):
			return "world.locks_open: %s 는 봉인 문이라 열릴 수 없다" % GridKey.edge(e)
	if typeof(w["chests_opened"]) != TYPE_ARRAY:
		return "world.chests_opened: 배열이 아니다"
	for id in w["chests_opened"]:
		if typeof(id) != TYPE_STRING or not s.floor_def.chests.has(id):
			return "world.chests_opened: %s 는 이 층의 상자가 아니다" % str(id)
		if s.world.chests_opened.has(id):
			return "world.chests_opened: %s 가 두 번 있다" % id
		s.world.chests_opened[id] = true
	if schema >= 9:
		err = _read_gather_used(w["gather_used"], s)
	if err.is_empty() and schema >= 10:
		err = _read_foes(w["foes"], s)
	return err


## 10판 world.foes(M3 A6 설계 §3.3): 이 층 FOE id(엄격) → 정확히 FOE_KEYS 일곱. 없는 id 는 처음 상태로 둔다(자료에 FOE 가 늘어도 읽힌다).
## at 은 그 층 FOE 칸, facing N·E·S·W, state 는 종류가 받는 값, path_i 는 경로 안(경로가 없으면 0), dir ±1, stun 0~2(쓰러지면 0),
## day 는 쓰러졌으면 1~DAY_MAX(지금 날 이하인지는 _check_foes 가 본다), 아니면 0.
static func _read_foes(v: Variant, s: FloorState) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "world.foes: 객체가 아니다"
	for id in v:
		if typeof(id) != TYPE_STRING or not s.floor_def.foes.has(id):
			return "world.foes: %s 는 이 층의 FOE 가 아니다" % str(id)
		var sp: FloorModel.FoeSpawn = s.floor_def.foes[id]
		var path := "world.foes.%s" % id
		var rv: Variant = v[id]
		if typeof(rv) != TYPE_DICTIONARY:
			return "%s: 객체가 아니다" % path
		for k in FOE_KEYS:
			if not rv.has(k):
				return "%s.%s 가 없다" % [path, k]
		for k in rv:
			if not FOE_KEYS.has(k):
				return "%s.%s 는 모르는 필드다" % [path, str(k)]
		var fs := WorldState.FoeState.new()
		fs.at = _cell_pair(rv["at"], s.floor_def)
		if fs.at == GridKey.BAD_CELL or not s.floor_def.is_foe_cell(fs.at):
			return "%s.at: 이 층에서 FOE 가 설 수 있는 칸이 아니다" % path
		fs.facing = Dir.from_name(rv["facing"])
		if fs.facing < 0:
			return "%s.facing: N·E·S·W 가운데 하나여야 한다" % path
		if typeof(rv["state"]) != TYPE_STRING or not FOE_STATES[sp.kind].has(rv["state"]) \
				or (rv["state"] == "patrol" and sp.path.is_empty()):
			return "%s.state: %s FOE 가 가질 수 없는 상태다" % [path, sp.kind]
		fs.state = rv["state"]
		var pi: Variant = to_int(rv["path_i"]) if typeof(rv["path_i"]) != TYPE_BOOL else null
		if pi == null or pi < 0 or pi > maxi(0, sp.path.size() - 1):
			return "%s.path_i: 정수 0~%d 이어야 한다" % [path, maxi(0, sp.path.size() - 1)]
		fs.path_i = pi
		var dv: Variant = to_int(rv["dir"]) if typeof(rv["dir"]) != TYPE_BOOL else null
		if dv != 1 and dv != -1:
			return "%s.dir: 1 또는 -1 이어야 한다" % path
		fs.dir = dv
		if fs.state == "patrol" and fs.at != sp.path[fs.path_i]:
			return "%s.at: 순회 중인 FOE 는 경로 자리 path[%d] %d:%d 에 서야 한다" % [path, fs.path_i, sp.path[fs.path_i].x, sp.path[fs.path_i].y]
		var st: Variant = to_int(rv["stun"]) if typeof(rv["stun"]) != TYPE_BOOL else null
		if not BattleLimits.in_range("foe_stun", st) or (fs.state == "defeated" and st != 0):
			return "%s.stun: 정수 %s 이어야 한다(쓰러졌으면 0)" % [path, BattleLimits.range_text("foe_stun")]
		fs.stun = st
		var dy: Variant = to_int(rv["day"]) if typeof(rv["day"]) != TYPE_BOOL else null
		if fs.state == "defeated":
			if dy == null or dy < 1 or dy > ExplorationState.DAY_MAX:
				return "%s.day: 쓰러진 FOE 는 정수 1~%d 이어야 한다" % [path, ExplorationState.DAY_MAX]
		elif dy != 0:
			return "%s.day: 쓰러지지 않은 FOE 는 0 이어야 한다" % path
		fs.day = dy
		s.world.foes[id] = fs
	return ""


## 9판 world.gather_used(M3 A5): 이 층의 채집 지점 id → 오늘 쓴 횟수 정수 1~GATHER_USES_MAX(0 은 적지 않는다).
## 지점의 지금 uses 와는 견주지 않는다: 자료를 고쳐 횟수가 줄어도 저장은 읽히고 그 지점은 다 쓴 것으로 보인다(설계 §3.2). id 는 엄격하다.
static func _read_gather_used(v: Variant, s: FloorState) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "world.gather_used: 객체가 아니다"
	for id in v:
		if typeof(id) != TYPE_STRING or not s.floor_def.points.has(id):
			return "world.gather_used: %s 는 이 층의 채집 지점이 아니다" % str(id)
		var n: Variant = to_int(v[id]) if typeof(v[id]) != TYPE_BOOL else null
		if n == null or not BattleLimits.in_range("gather_uses", n):
			return "world.gather_used.%s: 정수 1~%d 이어야 한다" % [id, BattleLimits.GATHER_USES_MAX]
		s.world.gather_used[id] = n
	return ""


## 8판 consumables(M3 A4): 아는 소모품 ID → 정수 1~99(0개는 키를 두지 않는다). 가방 합계는 보지 않는다.
static func _read_consumables(d: Dictionary, defs: GameDefs, s: ExplorationState) -> String:
	if typeof(d.get("consumables")) != TYPE_DICTIONARY:
		return "consumables 가 객체가 아니다"
	for k in d["consumables"]:
		if typeof(k) != TYPE_STRING or defs.battle.consumable(k) == null:
			return "consumables 의 %s 는 모르는 소모품이다" % str(k)
		var v: Variant = d["consumables"][k]
		var n: Variant = to_int(v) if typeof(v) != TYPE_BOOL else null
		if not BattleLimits.in_range("consumable", n):
			return "consumables.%s 가 정수 %s 가 아니다" % [k, BattleLimits.range_text("consumable")]
		s.consumables[k] = n
	return ""


## 7판 key_items(M3 A3): 서로 겹치지 않는 아는 귀중품 ID 문자열의 배열(차례는 보지 않는다. 쓸 때 정렬한다).
static func _read_key_items(d: Dictionary, defs: GameDefs, s: ExplorationState) -> String:
	if typeof(d.get("key_items")) != TYPE_ARRAY:
		return "key_items 가 배열이 아니다"
	for id in d["key_items"]:
		if typeof(id) != TYPE_STRING or not defs.battle.key_items.has(id):
			return "key_items 의 %s 는 모르는 귀중품이다" % str(id)
		if s.key_items.has(id):
			return "key_items 에 %s 가 두 번 있다" % id
		s.key_items[id] = true
	return ""


## 열쇠·상자·잠긴 문 맞물림(M3 A3, 규칙이 늘 지키므로 손으로 고친 저장만 걸린다): ① 열쇠를 가졌다 ⇔ 그 열쇠가 든 상자를 열었다
## (그 층 기록이 없으면 연 것이 아니다) ② 연 잠긴 문의 열쇠를 가졌다.
static func _check_keys(s: ExplorationState) -> String:
	for k in s.key_items:
		var home := s.defs.key_chest(k)
		if home.is_empty():
			return "key_items 의 %s 가 든 상자가 묶음에 없다" % k
		var rec: FloorState = s.floor_states.get(home[0].id)
		if rec == null or not rec.world.is_chest_opened(home[1].id):
			return "key_items 에 %s 가 있는데 그 상자 %s:%s 를 열지 않았다" % [k, home[0].id, home[1].id]
	for id in s.floor_states:
		var rec: FloorState = s.floor_states[id]
		for cid in rec.world.chests_opened:
			var c: FloorModel.Chest = rec.floor_def.chests[cid]
			if c.item.begins_with("key.") and not s.key_items.has(c.item):
				return "floor_states.%s.world.chests_opened 의 %s 를 열었는데 열쇠 %s 가 없다" % [id, cid, c.item]
		for e in rec.world.locks_open:
			var k := rec.floor_def.lock_key(e)
			if not s.key_items.has(k):
				return "floor_states.%s.world.locks_open 의 %s 가 열렸는데 열쇠 %s 가 없다" % [id, GridKey.edge(e), k]
	return ""


static func _read_knowledge(d: Dictionary, s: FloorState) -> String:
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


static func _read_annotation(d: Dictionary, s: FloorState) -> String:
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


## 층 기록의 경로는 문서 꼴을 따른다: 5판은 floor_states.<층 ID>. 를 붙이고(기록이 하나여도), 4판 이하(평평한 꼴)는 붙이지 않는다.
## contact(M3 A6): 10판 접촉 전투면 위험도는 한계값 아래여야 한다(접촉은 위험도를 더하지 않는다). 그 밖에는 pending == (위험도 >= 한계값).
static func _check_consistency(s: ExplorationState, schema: int, contact: bool = false) -> String:
	if s.party.all_down() != s.wiped:
		return "모든 대원 HP 0 과 wiped 가 맞지 않다"
	if s.wiped and s.encounter.pending:
		return "전멸 상태에서 전투 대기일 수 없다(전멸이면 battle 도 없다)"
	if contact:
		if s.encounter.danger >= s.encounter.threshold:
			return "FOE 접촉 전투인데 위험도가 한계값 이상이다"
	elif s.encounter.pending != (s.encounter.danger >= s.encounter.threshold):
		return "전투 대기(pending)와 위험도 >= 한계값이 맞지 않다"
	for id in s.floor_states:
		var r: FloorState = s.floor_states[id]
		for e in r.knowledge.edges:
			if r.knowledge.edges[e] != ExplorationRules.look_of(r.floor_def, r.world, e):
				return "%sknowledge.edges 의 %s 겉모습이 세계 상태와 맞지 않다" % ["" if schema < 5 else "floor_states.%s." % id, GridKey.edge(e)]
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
