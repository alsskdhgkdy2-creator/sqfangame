## 시험용 층·파티·상태 도우미(test_ 로 시작하지 않아 실행기가 시험으로 읽지 않는다).
extends RefCounted

const A := ExplorationRules.Action
const F1_PATH := "res://data/floors/f1_test.json"
const PARTY_PATH := "res://data/party/test_party.json"
const SAVE_DIR := "user://test_saves"

static var _f1: FloorModel
static var _party: PartyData
static var _db: BattleDb
static var _defs_by_floor := {}


static func f1() -> FloorModel:
	if _f1 == null:
		_f1 = FloorLoader.load_path(F1_PATH).floor_def
	return _f1


## 시험용 정의 묶음: 그 층 + data/ 의 파티·전투 정의(한 번 읽어 나눠 쓴다). 층에 출현 표가 없으면 encounter.f1_test 를 채운다.
## 층 객체마다 같은 GameDefs 를 돌려준다.
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
	var d := GameDefs.new()
	d.floor_def = f
	d.party = _party
	d.battle = _db
	_defs_by_floor[f] = d
	return d


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


# ---- 전투 시험 도우미 (06 §10.1) ----

const DATA_DIR := "res://data"
const BATTLE_KINDS := ["rules", "classes", "skills", "enemies", "encounters", "items"]
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
	var r := GameDefs.from_parts(f, p, db)
	if not r.ok():
		push_error("시험 정의 오류: %s" % str(r.errors))
		return null
	return r.defs


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
		"ailment_vuln": {"poison": 1000, "paralysis": 1000, "sleep": 1000}, "bind_vuln": {"head": 1000, "arm": 1000, "leg": 1000},
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
