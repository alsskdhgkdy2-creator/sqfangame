## 시험용 층·파티·상태 도우미(test_ 로 시작하지 않아 실행기가 시험으로 읽지 않는다).
extends RefCounted

const A := ExplorationRules.Action
const F1_PATH := "res://data/floors/f1_test.json"
const F2_PATH := "res://data/floors/f2_test.json"
## 실제 층 묶음(M3 A1): f1_test(B1F) · f2_test(B2F).
const LABYRINTH_PATH := "res://data/floors/labyrinth.json"
## 게임 층 묶음(M3 A3): b1f·b2f·b3f, 은퇴한 묶음 labyrinth.json.
const ARBOR_PATH := "res://data/floors/arbor.json"
const PARTY_PATH := "res://data/party/test_party.json"
const SAVE_DIR := "user://test_saves"

static var _f1: FloorModel
static var _f2: FloorModel
static var _party: PartyData
static var _db: BattleDb
static var _defs_by_floor := {}
static var _arbor: GameDefs


static func f1() -> FloorModel:
	if _f1 == null:
		_f1 = FloorLoader.load_path(F1_PATH).floor_def
	return _f1


static func f2() -> FloorModel:
	if _f2 == null:
		_f2 = FloorLoader.load_path(F2_PATH).floor_def
	return _f2


## 실제 층 묶음(깊이 차례, f1()·f2() 와 같은 객체).
static func floors() -> Array[FloorModel]:
	return [f1(), f2()] as Array[FloorModel]


## 층 f 가 든 시험 층 묶음: f1 이면 실제 묶음(계단 짝 f2 포함), 아니면 그 층 하나.
static func set_of(f: FloorModel) -> Array[FloorModel]:
	if f == f1():
		return floors()
	return [f] as Array[FloorModel]


## 시험용 정의 묶음: 그 층의 묶음(set_of) + data/ 의 파티·전투 정의(한 번 읽어 나눠 쓴다). 층에 출현 표가 없으면 encounter.f1_test 를 채운다.
## 층 객체마다 같은 GameDefs 를 돌려준다(층 사이 검사는 하지 않는다, GameDefs.assemble).
static func defs(f: FloorModel = null) -> GameDefs:
	if f == null:
		f = f1()
	if _defs_by_floor.has(f):
		return _defs_by_floor[f]
	if _db == null:
		_db = BattleDb.load_dir(DATA_DIR)
		_party = PartyData.read_path(PARTY_PATH)
		_party.resolve(_db)
	if f.encounter_table.is_empty():
		f.encounter_table = "encounter.f1_test"
	var d := GameDefs.assemble(set_of(f), _party, _db)
	_defs_by_floor[f] = d
	return d


## 게임 층 묶음 정의(arbor.json, 은퇴한 묶음 포함, 화면 문구 검사까지). 한 번 읽어 나눠 쓴다. 오류가 있으면 null.
static func arbor() -> GameDefs:
	if _arbor == null:
		_arbor = GameDefs.load_paths(ARBOR_PATH, PARTY_PATH, DATA_DIR, TextDb.load_path("res://data/text/ko.json")).defs
	return _arbor


static func members() -> Array[PartyState.Member]:
	return defs().members()


## 기본 필드를 채운 층 정의 사전. extra로 덮어쓴다.
static func floor_dict(grid: Array, extra: Dictionary = {}) -> Dictionary:
	var w := (str(grid[0]).length() - 1) / 2
	var h := (grid.size() - 1) / 2
	var d := {
		"id": "fx", "name_key": "floor.fx", "theme": "stratum1", "size": [w, h], "grid": grid,
		"start": {"at": [0, 0], "facing": "E"}, "shortcuts": [],
		"encounter": {"danger_per_step": 10, "threshold_min": 1000, "threshold_max": 1000},
		"damage_floor": {"damage": 3},
	}
	d.merge(extra, true)
	return d


static func parse(d: Dictionary) -> FloorLoader.Result:
	return FloorLoader.parse_text(JSON.stringify(d, "\t"), "fx.json")


## 5판 저장 문서(사전)의 지금 층 기록 {world, knowledge, annotation}(M3 A1). 시험이 고치면 문서가 바뀐다.
static func cur(doc: Dictionary) -> Dictionary:
	return doc["state"]["floor_states"][doc["state"]["floor"]]


## 11판 문서에서 10판 문서를 만든다(M3 A7: 머리 10·"m3o", guild 없음, 대원은 3~10판 키만). 파티가 기본 다섯(정의 칸 순서)이고 길드가 비어야 한다.
static func as_v10(doc: Dictionary) -> Dictionary:
	var d := doc.duplicate(true)
	d.merge({"schema": 10, "rules": "m3o"}, true)
	strip_guild(d)
	return d


## 문서에서 11판 길드 값을 그 자리에서 걷어 낸다(맨 위 guild, 대원의 3~10판 밖 키). 머리는 그대로(부르는 쪽이 정한다).
static func strip_guild(d: Dictionary) -> void:
	var st: Dictionary = d["state"]
	assert(st["guild"]["members"].is_empty(), "10판에는 길드가 없다")
	st.erase("guild")
	for m in st["party"]["members"]:
		for k in m.keys():
			if not SaveCodec.MEMBER_KEYS.has(k):
				m.erase(k)


## 옛 판 저장을 11판으로 옮긴 state 사전(state_to_dict)에서 M3 A7 이 더한 것(맨 위 guild, 대원의 name·class·look·row)을 빼고 돌려준다.
## 더한 것이 기본값인지 함께 본다: 길드는 비고 serial 0, 대원 칸 i 는 기본 다섯 칸 i 의 직업·열, 이름 null, 외형 0. 맞지 않으면 문자열 하나에 까닭을 담는다.
## 돌려주는 사전: {"state": 뺀 사전, "bad": "" 또는 까닭}.
## M3 A8: 12판이 더한 맨 위 quests·flags 도 먼저 뺀다(strip_v12, 옛 판에서 옮긴 기록이어야 한다).
static func strip_v11(now: Dictionary, defs: GameDefs) -> Dictionary:
	var v12 := strip_v12(now, defs)
	var d: Dictionary = v12["state"]
	var bad: String = v12["bad"]
	if d.get("guild") != {"members": [], "serial": 0}:
		bad = "guild 가 빈 길드가 아니다: %s" % str(d.get("guild"))
	d.erase("guild")
	var ms: Array = d["party"]["members"]
	for i in ms.size():
		var m: Dictionary = ms[i]
		var want := {"name": null, "class": defs.party.class_ids[i] if i < defs.party.ids.size() else "?", "look": 0,
			"row": defs.party.rows[i] if i < defs.party.ids.size() else "?"}
		for k in want:
			if bad.is_empty() and str(m.get(k)) != str(want[k]):
				bad = "party.members[%d].%s = %s, 기본값 %s 이 아니다" % [i, k, str(m.get(k)), str(want[k])]
			m.erase(k)
	return {"state": d, "bad": bad}


## 옛 판 저장을 12판으로 옮긴 state 사전에서 M3 A8 이 더한 맨 위 quests·flags 를 빼고 돌려준다. 더한 값이 옮긴 값인지 함께 본다:
## quests 는 비고, flags 는 계단 needs 가운데 도착 층 기록(floor_states)이 있는 것만(정렬, 층 자료로 셈 — 규칙 함수를 부르지 않는다).
## 돌려주는 사전: {"state": 뺀 사전, "bad": "" 또는 까닭}.
static func strip_v12(now: Dictionary, defs: GameDefs) -> Dictionary:
	var d := now.duplicate(true)
	var bad := ""
	var want: Array = []
	for fid in defs.floor_ids:
		for st in defs.floors[fid].stair_list():
			if not st.needs.is_empty() and d.get("floor_states", {}).has(st.to_floor) and not want.has(st.needs):
				want.append(st.needs)
	want.sort()
	if d.get("quests") != {}:
		bad = "quests 가 비지 않았다: %s" % str(d.get("quests"))
	elif str(d.get("flags")) != str(want):
		bad = "flags %s 가 옮긴 허가 %s 가 아니다" % [str(d.get("flags")), str(want)]
	d.erase("quests")
	d.erase("flags")
	return {"state": d, "bad": bad}


## 13판(M3 A9) 상태 사전(SaveCodec.state_to_dict 또는 읽은 JSON)에서 보스 FOE 기록만 이름으로 뺀다. 빼기 전에 그 기록이 처음 상태
## (그 층 정의의 자리·방향, idle, path_i 0, dir 1, stun 0, day 0)인지 본다. 보스 자리가 있는 층의 기록이 있으면 보스 기록도 꼭 있어야 한다.
## {state: 뺀 사본, bad: 어긋남 설명("" 이면 처음 상태)}. 보스를 만나지 않은 옛 경로·HEAD 비교(J7·J8)가 쓴다.
static func strip_v13(now: Dictionary, defs: GameDefs) -> Dictionary:
	var d := now.duplicate(true)
	var bad := ""
	for pair in defs.boss_spawns():
		var fs: Dictionary = d.get("floor_states", {})
		if not fs.has(pair[0]):
			continue
		var foes: Dictionary = fs[pair[0]]["world"]["foes"]
		var sp: FloorModel.FoeSpawn = defs.floors[pair[0]].foes[pair[1]]
		var want := {"at": [sp.at.x, sp.at.y], "facing": Dir.name_of(sp.facing), "state": "idle", "path_i": 0, "dir": 1, "stun": 0, "day": 0}
		if not foes.has(pair[1]):
			bad = "%s 에 보스 %s 기록이 없다" % [pair[0], pair[1]]
		elif JSON.stringify(JSON.parse_string(JSON.stringify(foes[pair[1]])), "", true) != JSON.stringify(JSON.parse_string(JSON.stringify(want)), "", true):
			bad = "%s 보스 %s 기록이 처음 상태가 아니다: %s" % [pair[0], pair[1], str(foes[pair[1]])]
		foes.erase(pair[1])
	return {"state": d, "bad": bad}


## 미궁 층으로 바로 옮긴다(시험 준비용, M3 A9): 장소 미궁, 층 기록(없으면 만든다), 층 들어서기의 FOE 처음 자리, 위치·방향, 위험도 0, 그 칸 기록.
## 규칙 행동이 아니다: 걸어서 가는 길이 이미 시험된 자리(공략 끝·봉인 앞)에 다시 설 때만 쓴다.
static func to_floor(s: ExplorationState, fid: String, at: Vector2i, facing: int) -> void:
	s.location = ExplorationState.LABYRINTH
	s.enter_floor(s.defs.floor_by_id(fid))
	FoeRules.enter_floor(s)
	s.party.at = at
	s.party.facing = facing
	s.encounter.danger = 0
	ExplorationRules.record_cell(s, at, "full")


## 마을로 바로 옮긴다(시험 준비용): 첫 층 시작 칸, 장소 마을, 위험도 0. 비콘·입구 문으로 돌아온 것과 같은 자리다.
static func to_town(s: ExplorationState) -> void:
	var first := s.defs.first_floor()
	s.enter_floor(first)
	s.party.at = first.start_at
	s.party.facing = first.start_facing
	s.location = ExplorationState.TOWN
	s.encounter.danger = 0


## 행동 하나(규칙 + 의뢰 관찰). 전투 대기가 되면 승리로 끝내고 그 끝도 관찰한다. 행동 이벤트를 돌려준다.
static func act(s: ExplorationState, action: int) -> Array[Dictionary]:
	var ev := ExplorationRules.apply(s, action, "full")
	QuestRules.observe(s, ev)
	if s.encounter.pending:
		var fin: Array[Dictionary] = []
		BattleRules.finish(s, "victory", fin)
		QuestRules.observe(s, fin)
	return ev


## A10 갈고리(M3 A9 설계 §4.5): 마을 새 게임 → 관리국 임무 1 받기 → 미궁 → 고정 공략 전부(B3F 봉인 앞 9:2) → 마을에서 임무 1 보고·임무 2 받기
## → B3F 10:2 에서 서쪽 한 걸음(임무 2 도착) → 마을에서 임무 2 보고(permit.boss) → 봉인 앞 9:2 서쪽. 공략 중 전투는 이겼다고 친다.
## 마을 ↔ 미궁 이동은 to_town·to_floor(이미 걸은 길을 다시 걷지 않는다). 받기·보고는 실제 의뢰 규칙이다.
static func walk_to_boss(defs: GameDefs, seed_value: int) -> ExplorationState:
	var s := ExplorationRules.new_game(defs, seed_value, "full", true)
	assert(QuestRules.accept(s, "mission.permit_b2f", "council")[0]["type"] != "rejected")
	act(s, ExplorationRules.Action.ENTER)
	var acts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/floors/arbor_route.json"))["actions"]
	for i in acts.size():
		if acts[i] == "stairs" and not s.flags.has("permit.b2f") and s.floor_def.id == "b1f":
			var back := [s.party.at, s.party.facing]
			to_town(s)
			assert(QuestRules.report(s, "mission.permit_b2f", "council")[0]["type"] != "rejected")
			to_floor(s, "b1f", back[0], back[1])
		act(s, ExplorationRules.action_from_name(acts[i]))
	assert(s.floor_def.id == "b3f" and s.party.at == Vector2i(9, 2))
	to_town(s)
	assert(QuestRules.accept(s, "mission.boss_seal", "council")[0]["type"] != "rejected")
	to_floor(s, "b3f", Vector2i(10, 2), Dir.W)
	act(s, ExplorationRules.Action.FORWARD)
	to_town(s)
	assert(QuestRules.report(s, "mission.boss_seal", "council")[0]["type"] != "rejected")
	to_floor(s, "b3f", Vector2i(9, 2), Dir.W)
	return s


## 11판 문서에서 4판 문서를 만든다(머리 4·"m3s", 지금 층 기록을 state 바로 아래로, floor_states 없음, as_v10 의 대원). 층 하나만 들어가 본 상태여야 한다.
static func as_v4(doc: Dictionary) -> Dictionary:
	var d := as_v10(doc) if int(doc["schema"]) >= 11 else doc.duplicate(true)
	d.merge({"schema": 4, "rules": "m3s"}, true)
	var st: Dictionary = d["state"]
	assert(st["floor_states"].size() == 1, "4판은 층 하나")
	st.merge(st["floor_states"][st["floor"]], true)
	st.erase("floor_states")
	return d


## 오류 없이 읽히는 층. 오류가 있으면 실행을 멈추게 null.
static func floor_of(grid: Array, extra: Dictionary = {}) -> FloorModel:
	var r := parse(floor_dict(grid, extra))
	if not r.ok():
		push_error("시험 층 오류: %s" % str(r.errors))
		return null
	return r.floor_def


## 한 줄 층. cells는 칸 문자들, inner는 칸 사이 세로 경계 문자들(길이 = 칸 수 − 1).
static func row_grid(cells: String, inner: String) -> Array:
	var border := "+" + "-+".repeat(cells.length())
	var mid := "|"
	for i in cells.length():
		mid += cells[i]
		mid += inner[i] if i < inner.length() else "|"
	return [border, mid, border]


static func row_floor(cells: String, inner: String, extra: Dictionary = {}) -> FloorModel:
	return floor_of(row_grid(cells, inner), extra)


static func game(f: FloorModel, seed_value: int = 1, automap: String = "floor") -> ExplorationState:
	return ExplorationRules.new_game(defs(f), seed_value, automap)


## 이벤트 종류만 뽑는다.
static func types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(e["type"])
	return out


## 절대 방향 문자열("NNE…")대로 실제 회전·전진 행동을 한다. 전투 대기면 해결한다. 모든 이벤트를 돌려준다.
static func walk(s: ExplorationState, dirs: String, automap: String = "floor") -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for ch in dirs:
		var want := Dir.from_name(ch)
		while s.party.facing != want:
			all.append_array(ExplorationRules.apply(s, A.TURN_RIGHT if Dir.right(s.party.facing) == want or Dir.opposite(s.party.facing) == want else A.TURN_LEFT, automap))
		all.append_array(ExplorationRules.apply(s, A.FORWARD, automap))
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
	return all


static func face(s: ExplorationState, d: int, automap: String = "floor") -> void:
	while s.party.facing != d:
		ExplorationRules.apply(s, A.TURN_RIGHT, automap)


static func clean_saves() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(SAVE_DIR)


## 실제 자료 층의 처음 FOE 기록(M3 A6, 저장 10판 world.foes). 자료(data/floors)를 옮겨 적은 고정 값이고, 시험 층은 FOE 가 없어 빈 사전이다.
const FRESH_FOES := {
	"b1f": {"f1": {"at": [12, 9], "facing": "E", "state": "patrol", "path_i": 0, "dir": 1, "stun": 0, "day": 0}},
	"b2f": {"f2": {"at": [5, 10], "facing": "W", "state": "idle", "path_i": 0, "dir": 1, "stun": 0, "day": 0}},
	"b3f": {"f3": {"at": [16, 3], "facing": "N", "state": "idle", "path_i": 0, "dir": 1, "stun": 0, "day": 0},
		"boss": {"at": [4, 2], "facing": "E", "state": "idle", "path_i": 0, "dir": 1, "stun": 0, "day": 0}},  # M3 A9 보스(처음 자리·방향, 움직이지 않음)
}


## 층 하나의 처음 world.foes(깊은 사본). 옛 판을 옮긴 결과와 견줄 때 원본 world 에 더한다.
static func fresh_foes(floor_id: String) -> Dictionary:
	return FRESH_FOES.get(floor_id, {}).duplicate(true)


# ---- 전투 시험 도우미 (06 §10.1) ----

const DATA_DIR := "res://data"
const BATTLE_KINDS := ["rules", "classes", "skills", "enemies", "encounters", "items", "shop", "gathering", "foes"]
## 난수가 끼지 않는 규칙 상수: 피해·순서 난수 1000 고정, 크리티컬 0, 명중 하한 1000.
const EXACT := {"damage_roll": [1000, 1000], "speed_roll": [1000, 1000], "crit_base": 0, "crit_luck": 0, "hit_min": 1000}

static var _data_files: Dictionary


## data/ 의 전투 정의 파일(상대 경로 → 읽은 JSON). 매번 깊은 사본.
static func data_files() -> Dictionary:
	if _data_files.is_empty():
		for kind in BATTLE_KINDS:
			var dir := DirAccess.open(DATA_DIR.path_join(kind))
			for n in dir.get_files():
				if n.ends_with(".json"):
					_data_files[kind + "/" + n] = JSON.parse_string(FileAccess.get_file_as_string(DATA_DIR.path_join(kind + "/" + n)))
	return _data_files.duplicate(true)


## 시험용 정의 파일 묶음: data/ 사본 + 규칙 상수 덮어쓰기 + 시험 파일(경로 → 사전).
static func battle_files(extra: Dictionary = {}, rules: Dictionary = {}) -> Dictionary:
	var files := data_files()
	files["rules/battle.json"].merge(rules, true)
	files.merge(extra.duplicate(true), true)
	return files


## 파일과 같은 실수 표기가 되도록 JSON 으로 한 번 돌린 뒤 BattleDb.parse.
static func battle_db(files: Dictionary) -> BattleDb:
	return BattleDb.parse(JSON.parse_string(JSON.stringify(files)))


static func party_dict() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PARTY_PATH))


## 오류 없는 GameDefs(층은 f1, 출현 표 encounter.f1_test). 오류가 있으면 push_error 뒤 null.
static func battle_defs(extra: Dictionary = {}, rules: Dictionary = {}, party: Dictionary = {}) -> GameDefs:
	return defs_from(battle_files(extra, rules), party)


## 이미 고친 파일 묶음으로 GameDefs.
static func defs_from(files: Dictionary, party: Dictionary = {}) -> GameDefs:
	var db := battle_db(files)
	var p := PartyData.parse_dict(JSON.parse_string(JSON.stringify(party if not party.is_empty() else party_dict())), "test_party.json")
	# 시험 편성(encounters/test.json)이 있으면 그 표를 쓰는 f1 사본: 저장 검사의 「이 층 출현 표의 편성」을 맞춘다.
	var f := f1()
	if files.has("encounters/test.json"):
		f = FloorLoader.load_path(F1_PATH).floor_def
		f.encounter_table = "encounter.test"
	var r := GameDefs.from_parts([f, f2()] as Array[FloorModel], p, db)
	if not r.ok():
		push_error("시험 정의 오류: %s" % str(r.errors))
		return null
	return r.defs


## 결과를 구성으로 정하는 data/ 사본 정의(D15): 적은 모두 아무것도 하지 않는 시험 스킬(MEND)만 써서 파티가 쓰러지지 않는다.
## 늘 맞는 MEND 규칙(조건 turn_mod [1, 0] = 매 턴)을 AI 맨 앞에 두고 원래 규칙은 뒤에 남긴다(고르지 않지만, 준비 스킬을 AI 표에서
## 찾는 저장 검사가 실제 상태를 그대로 받게). rules 는 규칙 상수 덮어쓰기(EXACT 면 명중 확정·난수 고정), immune 의 적 ID 는 모든 속성 무효(쓰러지지 않는다).
## 편성·열·이름·스킬은 실제 데이터 그대로라 저장·읽기 검사도 그대로 통과한다(같은 정의로 읽을 때).
static func quiet_defs(rules: Dictionary = {}, immune: Array = []) -> GameDefs:
	var files := battle_files({"skills/test.json": {"skills": [mend_skill()]}}, rules)
	for path in files:
		if str(path).begins_with("enemies/"):
			for e in files[path]["enemies"]:
				e["ai"] = [{"if": {"turn_mod": [1, 0]}, "use": [{"skill": MEND, "weight": 1, "target": "random"}]}] + e["ai"]
				if immune.has(e["id"]):
					for el in e["resist"]:
						e["resist"][el] = 0
	return defs_from(files)


## 새 탐색 상태 + 전투 시작. 저장과 맞도록 인카운트처럼 위험도를 한계값까지 채운 뒤 연다(pending ⇔ danger ≥ threshold).
static func battle(defs: GameDefs, formation: String, seed_value: int = 1) -> ExplorationState:
	var s := ExplorationRules.new_game(defs, seed_value, "floor")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, formation)
	return s


## 시험 적 스킬 사전(생략값을 채운다). top 은 스킬 위 단계, row 는 levels[0] 에 더한다.
static func enemy_skill(id: String, effect: String, target: String, top: Dictionary = {}, row: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "name_key": id, "user": "enemy", "effect": effect, "range": "ranged", "target": target, "parts": [],
		"priority": "normal", "speed": 1000}
	if effect == "damage":
		d.merge({"stat": "STR", "element": "bash", "can_crit": false, "sure_hit": true})
	d.merge(top, true)
	var lv := {"tp": 0}
	if effect == "damage":
		lv.merge({"power": 1, "accuracy": 1000})
	lv.merge(row, true)
	d["levels"] = [lv]
	return d


## 시험 강화·약화 스킬 사전(BattleDb.parse 를 거쳐 정의가 된다). 강화는 파티 스킬, 약화는 적 스킬(USER_EFFECTS).
## rows = [[kind, value, turns], …] 가 levels 줄이다(Lv n = rows[n-1]).
static func effect_skill(id: String, debuff: bool, rows: Array) -> Dictionary:
	var lv := []
	for r in rows:
		lv.append({"tp": 0 if debuff else 1, "kind": r[0], "value": r[1], "turns": r[2]})
	return {"id": id, "name_key": id, "user": "enemy" if debuff else "party", "effect": "debuff" if debuff else "buff", "range": "ranged",
		"target": "enemy_one" if debuff else "ally_one", "parts": [], "priority": "normal", "speed": 1000, "levels": lv}


## 정의된 강화·약화 스킬을 그 레벨로 건다(규칙 함수 BattleEffects.apply_effect). buffed 이벤트를 돌려준다.
static func apply_effect(s: ExplorationState, u: BattleUnit, id: String, level: int = 1) -> Dictionary:
	var ev: Array[Dictionary] = []
	BattleEffects.apply_effect(s.battle, s.defs.battle.rules, u, s.defs.battle.skill(id), level, ev)
	return ev[0] if not ev.is_empty() else {}


## 시험 적 사전. stats = [STR, INT, VIT, WIS, AGI, LUC]. ai = [[조건, [[스킬, 가중치, 대상], …]], …].
static func enemy(id: String, hp: int, stats: Array, ai: Array, extra: Dictionary = {}) -> Dictionary:
	var rules := []
	for r in ai:
		var use := []
		for c in r[1]:
			use.append({"skill": c[0], "weight": c[1], "target": c[2] if c.size() > 2 else "random"})
		rules.append({"if": r[0], "use": use})
	var d := {"id": id, "name_key": id, "max_hp": hp,
		"stats": {"STR": stats[0], "INT": stats[1], "VIT": stats[2], "WIS": stats[3], "AGI": stats[4], "LUC": stats[5]},
		"resist": {"slash": 1000, "pierce": 1000, "bash": 1000, "fire": 1000, "ice": 1000, "volt": 1000},
		"ailment_vuln": {"poison": 1000, "paralysis": 1000, "sleep": 1000, "confusion": 1000, "blind": 1000}, "bind_vuln": {"head": 1000, "arm": 1000, "leg": 1000},
		"on_bound": "fail", "exp": 0, "ai": rules, "drops": []}
	d.merge(extra, true)
	return d


## 아무것도 하지 않는 적 스킬(자기 회복 0)과 그 적. AGI 1 이라 늘 마지막에 움직인다.
const MEND := "skill.enemy.t_mend"
const DUMMY := "enemy.t_dummy"


static func mend_skill() -> Dictionary:
	return enemy_skill(MEND, "heal", "self", {}, {"base": 0, "wis_pct": 0})


static func dummy(hp: int = 999) -> Dictionary:
	return enemy(DUMMY, hp, [10, 10, 10, 10, 1, 10], [[{}, [[MEND, 1]]]])


## 시험 파일 셋(skills/test.json·enemies/test.json·encounters/test.json). formations = {편성 이름: [[적, 열], …]}.
## 편성 ID 는 formation.t.<이름>. 시험 스킬·적 목록에 MEND·DUMMY 가 늘 들어간다.
static func test_files(skills: Array, enemies: Array, formations: Dictionary) -> Dictionary:
	var sk := [mend_skill()]
	sk.append_array(skills)
	var en := [dummy()]
	for e in enemies:
		if e["id"] == DUMMY:
			en[0] = e
		else:
			en.append(e)
	var fs := []
	var table := []
	for name in formations:
		var list := []
		for x in formations[name]:
			list.append({"enemy": x[0], "row": x[1]})
		fs.append({"id": "formation.t." + name, "no_escape": false, "enemies": list})
		table.append({"formation": "formation.t." + name, "weight": 1})
	return {"skills/test.json": {"skills": sk}, "enemies/test.json": {"enemies": en},
		"encounters/test.json": {"id": "encounter.test", "formations": fs, "table": table}}


static func atk(target: int) -> Dictionary:
	return {"kind": "attack", "target": target}


static func use(skill_id: String, target: int = -1) -> Dictionary:
	var c := {"kind": "skill", "skill": skill_id}
	if target >= 0:
		c["target"] = target
	return c


const GUARD := {"kind": "guard"}


## 명령을 받는 대원은 overrides[칸] 또는 방어, 나머지는 null.
static func cmds(s: ExplorationState, overrides: Dictionary = {}) -> Array:
	var out := []
	for i in s.battle.party.size():
		if not BattleRules.can_command(s, i):
			out.append(null)
		else:
			out.append(overrides.get(i, GUARD))
	return out


static func of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["type"] == type:
			out.append(e)
	return out


## 전투 결정성 비교용 해시: 탐색 정규 상태 + 전투 상태 + 대원 TP + 소재 + 난수 상태.
static func battle_hash(s: ExplorationState) -> String:
	var tps := []
	for m in s.party.members:
		tps.append(m.tp)
	var d := {"state": SaveCodec.canonical_state(s), "battle": s.battle.to_dict() if s.battle != null else null,
		"tp": tps, "materials": s.materials, "rng": str(s.rng.get_state())}
	return JSON.stringify(d, "", true).sha256_text()


## 이벤트 열 문자열(유닛 객체가 없어 그대로 직렬화된다).
static func events_text(events: Array) -> String:
	return JSON.stringify(events, "", true)


## 전투 중 상태의 사본: 검사 있는 저장 왕복(SaveCodec.encode → decode). 실패하면 push_error 뒤 null.
static func battle_clone(s: ExplorationState) -> ExplorationState:
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	if not r.ok():
		push_error("저장 왕복 실패: %s" % r.error)
		return null
	return r.state


# ---- 성장 시험 도우미 (07 §10.7) ----

## files["rules/growth.json"] 에 덮어쓴다(level_cap 을 바꾸면 exp_next 도 함께 준다). files 를 돌려준다.
static func with_growth(files: Dictionary, overrides: Dictionary) -> Dictionary:
	files["rules/growth.json"].merge(overrides.duplicate(true), true)
	return files


## 시험 파티 사전: 스킬마다 그 스킬이 트리에 있는 첫 대원에게 그 레벨로 배우게 하고, 선행을 요구 레벨까지 채우며(거슬러 올라감),
## 대원 level 을 배운 스킬의 관문(min_level) 가운데 가장 큰 값까지 올린다. SP 는 따지지 않으므로 with_growth(…, {"initial_sp": 99}) 와 함께 쓴다.
## 이미 더 높은 레벨로 배운 스킬은 내리지 않는다.
## 시험 새 대원 파티(M3 A7): 시험 파티의 칸 3(나노 메딕)·칸 4(글리프 위저드)를 레일 레인저·헥스 해커로 바꾼 사전(ID·이름 키·열·레벨 그대로,
## 스킬 없음, 장비는 data/ 직업 파일의 start_equip). 기본 다섯에 없는 직업의 스킬을 같은 길로 시험할 때 쓴다.
static func recruit_party_dict() -> Dictionary:
	var p: Dictionary = party_dict()
	for x in [[3, "rail_ranger"], [4, "hex_hacker"]]:
		var m: Dictionary = p["members"][x[0]]
		var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes/%s.json" % x[1]))
		m["class"] = c["id"]
		m["skills"] = {}
		m["equip"] = c["start_equip"].duplicate()
	return p


static func party_with_skills(db: BattleDb, levels: Dictionary, party: Dictionary = {}) -> Dictionary:
	var p: Dictionary = (party if not party.is_empty() else party_dict()).duplicate(true)
	for sid in levels:
		for m in p["members"]:
			var c: BattleDb.ClassDef = db.classes.get(m["class"])
			if c != null and c.tree_index.has(sid):
				_learn(db, c, m, sid, levels[sid])
				break
	return p


static func _learn(db: BattleDb, c: BattleDb.ClassDef, m: Dictionary, sid: String, level: int) -> void:
	var e := c.tree_entry(sid)
	for r in e["requires"]:
		_learn(db, c, m, r["skill"], r["level"])
	m["skills"][sid] = maxi(int(m["skills"].get(sid, 0)), level)
	m["level"] = maxi(int(m["level"]), int(e["min_level"]))


## 시험 전용 스킬 정의(skill 사전)를 그 직업의 스킬 파일(skills/<직업>.json)에, 트리 항목을 직업 파일(class_file, 예 "classes/glyph_wizard.json")에 함께 더한다.
## requires = [{skill, level}, …]. files 를 돌려준다.
static func add_tree_skill(files: Dictionary, class_file: String, skill: Dictionary, pos: Array, requires: Array = [], min_level: int = 1) -> Dictionary:
	files[class_file.replace("classes/", "skills/")]["skills"].append(skill.duplicate(true))
	files[class_file]["tree"].append({"skill": skill["id"], "pos": pos.duplicate(), "requires": requires.duplicate(true), "min_level": min_level})
	return files
