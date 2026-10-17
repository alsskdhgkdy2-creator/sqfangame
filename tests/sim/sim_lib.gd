## 전투 시뮬레이션(06 §7): 판 돌리기·집계·해시·보고. 실행기는 tests/sim/run.gd, 연기 시험은 tests/test_sim_smoke.gd.
## 정의 데이터는 게임과 같은 data/ 를 읽는다. 판마다 이벤트는 집계만 하고 버린다(원자료 줄은 해시에만 흘려 넣는다).
extends RefCounted

const CONFIG_PATH := "res://tests/sim/config.json"
const OUTCOME_CODES := {"victory": 0, "wiped": 1, "escaped": 2, "stalled": 3, "error": 4}
const OUTCOMES := ["victory", "wiped", "escaped", "stalled", "error"]
## 연전 끝 코드(06 §7.6).
const CHAIN_WIPED := 0
const CHAIN_CAP := 1
const CHAIN_STALLED := 3
const CHAIN_ERROR := 4

var config: Dictionary = {}
var db: BattleDb
var floor_def: FloorModel
var template: Dictionary = {}
## 파티 ID → GameDefs
var defs_by_party := {}
## 출현 표 순서의 [편성 ID, 가중치]
var table: Array = []
var data_files: Array[String] = []
var errors: Array[String] = []
## 참이면 판마다 매 턴 검사 있는 저장 왕복(SaveCodec.encode → decode)을 돌려 실패를 save_errors 에 센다(06 §11.4 ①).
var check_saves_every := 0


## 06 §7 이 정한 축: small·large 는 파티 셋·편성 전부·정책 셋·연전 P1·P2 를 모두 가져야 하고, probe 는 P1·첫 편성·기본·P1 연전.
const SPEC_PARTIES := ["P1", "P2", "P3"]
const SPEC_CHAIN_PARTIES := ["P1", "P2"]
const PRODUCTION_SIZES := ["small", "large"]
const REQUIRED_SIZES := ["probe", "small", "large"]
const SIZE_KEYS := ["parties", "formations", "policies", "games_per_cell", "chain_parties", "chains_per_party", "save_check_games"]
const ACCEPTANCE_RANGES := ["weighted_turns", "p1_formation_turns", "wipe_rate_border", "p1_chain_median", "small_p1_weighted_turns"]
const ACCEPTANCE_NUMBERS := ["wipe_rate_max", "full_minus_default_max"]


## 설정과 정의를 읽는다. 오류가 있으면 errors 에 쌓고 false. 설정은 필드를 쓰기 전에 모양부터 다 본다(06 §7, 3차 검토).
func load_all(config_path: String = CONFIG_PATH) -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s: 설정 JSON 을 읽지 못했다(맨 위는 객체)" % config_path)
		return false
	errors.append_array(check_config_shape(parsed))
	if not errors.is_empty():
		return false
	config = parsed
	var data_dir: String = config["data_dir"]
	db = BattleDb.load_dir(data_dir)
	errors.append_array(db.errors)
	var fr := FloorLoader.load_path(config["floor"])
	errors.append_array(fr.errors)
	floor_def = fr.floor_def
	var tp: Variant = JSON.parse_string(FileAccess.get_file_as_string(config["party_template"]))
	if typeof(tp) != TYPE_DICTIONARY or typeof(tp.get("members")) != TYPE_ARRAY:
		errors.append("%s: 파티 틀을 읽지 못했다" % config["party_template"])
	else:
		template = tp
	if not errors.is_empty():
		return false
	var enc: BattleDb.EncounterDef = db.encounters.get(floor_def.encounter_table)
	if enc == null:
		errors.append("층 출현 표 %s 가 없다" % floor_def.encounter_table)
		return false
	for t in enc.table:
		table.append([t["formation"], int(t["weight"])])
	errors.append_array(check_config_refs())
	if not errors.is_empty():
		return false
	for pid in config["parties"]:
		var r := GameDefs.from_parts(floor_def, PartyData.parse_dict(party_dict(pid), "sim:%s" % pid), db)
		if not r.ok():
			errors.append_array(r.errors)
			continue
		defs_by_party[pid] = r.defs
	data_files = _data_files(data_dir, [config["floor"], config["party_template"]])
	return errors.is_empty()


## 정수(JSON 은 실수로 읽힌다). 소수·불리언·2^53 이상은 아니다.
static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and v == floorf(v) and absf(v) < 9007199254740992.0


## 문자열 값 비교(배열과 문자열을 == 로 견주면 GDScript 실행 오류다).
static func _is_word(v: Variant, w: String) -> bool:
	return typeof(v) == TYPE_STRING and v == w


static func _str_array(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	for x in v:
		if typeof(x) != TYPE_STRING:
			return false
	return true


## 설정의 모양(자료형·정수·필수 키). 통과하면 정수 필드를 int 로 바꿔 둔다.
static func check_config_shape(c: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in ["base_seed", "stall_limit", "chain_cap"]:
		if not _is_int(c.get(k)) or c[k] < (0 if k == "base_seed" else 1):
			out.append("%s: %s 정수여야 한다" % [k, "0 이상" if k == "base_seed" else "1 이상"])
		else:
			c[k] = int(c[k])
	for k in ["floor", "party_template", "data_dir"]:
		if typeof(c.get(k)) != TYPE_STRING or str(c[k]).is_empty():
			out.append("%s: 비지 않은 문자열이어야 한다" % k)
	if typeof(c.get("parties")) != TYPE_DICTIONARY or c["parties"].is_empty():
		out.append("parties: 비지 않은 객체여야 한다")
	else:
		for pid in c["parties"]:
			var m: Variant = c["parties"][pid]
			var ok: bool = typeof(m) == TYPE_ARRAY and m.size() == BattleLimits.PARTY_SIZE
			if ok:
				for spec in m:
					ok = ok and typeof(spec) == TYPE_ARRAY and spec.size() == 2 and typeof(spec[0]) == TYPE_STRING and spec[1] in BattleDb.ROWS
			if not ok:
				out.append("parties.%s: [직업 ID, front|back] %d개의 배열이어야 한다" % [pid, BattleLimits.PARTY_SIZE])
	if typeof(c.get("sizes")) != TYPE_DICTIONARY:
		out.append("sizes: 객체여야 한다")
	else:
		for name in REQUIRED_SIZES:
			if not c["sizes"].has(name):
				out.append("sizes.%s: 필수 크기가 없다" % name)
		for name in c["sizes"]:
			var sz: Variant = c["sizes"][name]
			var path := "sizes.%s" % name
			if typeof(sz) != TYPE_DICTIONARY:
				out.append("%s: 객체여야 한다" % path)
				continue
			for k in sz:
				if not SIZE_KEYS.has(k):
					out.append("%s.%s: 모르는 필드" % [path, k])
			for k in ["parties", "policies", "chain_parties"]:
				if not _str_array(sz.get(k)):
					out.append("%s.%s: 문자열 배열이어야 한다" % [path, k])
			var f: Variant = sz.get("formations")
			if not ((typeof(f) == TYPE_STRING and f in ["first", "all"]) or (_str_array(f) and not f.is_empty())):
				out.append("%s.formations: first·all 또는 편성 ID 배열이어야 한다" % path)
			for k in ["games_per_cell", "chains_per_party", "save_check_games"]:
				var lo := 1 if k == "games_per_cell" else 0
				if k == "save_check_games" and not sz.has(k):
					sz[k] = 0
				if not _is_int(sz.get(k)) or sz[k] < lo:
					out.append("%s.%s: %d 이상 정수여야 한다" % [path, k, lo])
				else:
					sz[k] = int(sz[k])
	if typeof(c.get("acceptance")) != TYPE_DICTIONARY:
		out.append("acceptance: 객체여야 한다")
	else:
		var a: Dictionary = c["acceptance"]
		for k in ACCEPTANCE_RANGES:
			var r: Variant = a.get(k)
			if typeof(r) != TYPE_ARRAY or r.size() != 2 or not (typeof(r[0]) in [TYPE_INT, TYPE_FLOAT]) or not (typeof(r[1]) in [TYPE_INT, TYPE_FLOAT]) or r[0] > r[1]:
				out.append("acceptance.%s: [작은 값, 큰 값] 숫자 둘이어야 한다" % k)
		for k in ACCEPTANCE_NUMBERS:
			if not (typeof(a.get(k)) in [TYPE_INT, TYPE_FLOAT]):
				out.append("acceptance.%s: 숫자여야 한다" % k)
	return out


## 정의와 맞춰 보는 설정 검사: 직업·파티·편성·정책 ID, 크기마다 06 §7 이 정한 축.
func check_config_refs() -> Array[String]:
	var out: Array[String] = []
	var formations := table.map(func(x): return x[0])
	for pid in config["parties"]:
		for spec in config["parties"][pid]:
			if not db.classes.has(spec[0]) or not template["members"].any(func(m): return m.get("class") == spec[0]):
				out.append("parties.%s: 직업 %s 가 정의나 시험 파티 틀에 없다" % [pid, spec[0]])
	for pid in SPEC_PARTIES:
		if not config["parties"].has(pid):
			out.append("parties.%s: 06 §7.2 의 파티가 없다" % pid)
	for name in config["sizes"]:
		var sz: Dictionary = config["sizes"][name]
		var path := "sizes.%s" % name
		for k in ["parties", "chain_parties"]:
			var seen := {}
			for pid in sz[k]:
				if not config["parties"].has(pid):
					out.append("%s.%s: 모르는 파티 %s" % [path, k, pid])
				if seen.has(pid):
					out.append("%s.%s: %s 가 두 번 있다" % [path, k, pid])
				seen[pid] = true
		var pseen := {}
		for pol in sz["policies"]:
			if not BattlePolicy.NAMES.has(pol):
				out.append("%s.policies: 모르는 정책 %s (%s 중 하나)" % [path, pol, ", ".join(BattlePolicy.NAMES)])
			if pseen.has(pol):
				out.append("%s.policies: %s 가 두 번 있다" % [path, pol])
			pseen[pol] = true
		if typeof(sz["formations"]) == TYPE_ARRAY:
			for f in sz["formations"]:
				if not formations.has(f):
					out.append("%s.formations: 출현 표에 없는 편성 %s" % [path, f])
		if sz["save_check_games"] > sz["games_per_cell"]:
			out.append("%s.save_check_games: games_per_cell 이하여야 한다" % path)
		if name in PRODUCTION_SIZES:
			for pid in SPEC_PARTIES:
				if not sz["parties"].has(pid):
					out.append("%s.parties: 06 §7.2 의 파티 %s 가 없다" % [path, pid])
			if not _is_word(sz["formations"], "all"):
				out.append("%s.formations: all 이어야 한다(출현 표의 편성 전부)" % path)
			for pol in BattlePolicy.NAMES:
				if not sz["policies"].has(pol):
					out.append("%s.policies: 정책 %s 가 없다" % [path, pol])
			for pid in SPEC_CHAIN_PARTIES:
				if not sz["chain_parties"].has(pid):
					out.append("%s.chain_parties: 연전 파티 %s 가 없다" % [path, pid])
			if sz["chains_per_party"] < 1:
				out.append("%s.chains_per_party: 1 이상이어야 한다" % path)
		elif name == "probe":
			if sz["parties"] != ["P1"] or not _is_word(sz["formations"], "first") or sz["policies"] != [BattlePolicy.DEFAULT] or sz["chain_parties"] != ["P1"] or sz["chains_per_party"] < 1:
				out.append("%s: P1·첫 편성·기본 정책·P1 연전 1개 이상이어야 한다(06 §7.4)" % path)
	return out


## 실행 계획 검사. small·large 는 06 §7 의 칸(파티 셋 × 출현 표 편성 × 정책 셋)과 연전 P1·P2 를 모두 가져야 한다.
## 그 밖의 크기 이름(연기 시험의 smoke 등)은 일부만 도는 계획이라 ID·수만 본다.
func check_plan(plan: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var formations := table.map(func(x): return x[0])
	if typeof(plan.get("cells")) != TYPE_ARRAY or plan["cells"].is_empty():
		out.append("plan.cells: 칸이 하나 이상이어야 한다")
		return out
	for c in plan["cells"]:
		if typeof(c) != TYPE_ARRAY or c.size() != 3 or not defs_by_party.has(c[0]) or not formations.has(c[1]) or not BattlePolicy.NAMES.has(c[2]):
			out.append("plan.cells: 잘못된 칸 %s" % str(c))
	for k in ["games_per_cell", "chains_per_party", "save_check_games", "base_seed"]:
		if not _is_int(plan.get(k)) or plan[k] < (1 if k == "games_per_cell" else 0):
			out.append("plan.%s: 정수 범위 밖" % k)
	for pid in plan.get("chain_parties", []):
		if not defs_by_party.has(pid):
			out.append("plan.chain_parties: 모르는 파티 %s" % pid)
	if not out.is_empty():
		return out
	if plan.get("size") in PRODUCTION_SIZES:
		for pid in SPEC_PARTIES:
			for f in formations:
				for pol in BattlePolicy.NAMES:
					if not plan["cells"].has([pid, f, pol]):
						out.append("plan.cells: %s 에 필요한 칸 %s·%s·%s 가 없다" % [plan["size"], pid, f, pol])
		for pid in SPEC_CHAIN_PARTIES:
			if not plan["chain_parties"].has(pid):
				out.append("plan.chain_parties: %s 에 필요한 연전 파티 %s 가 없다" % [plan["size"], pid])
		if plan["chains_per_party"] < 1:
			out.append("plan.chains_per_party: 1 이상이어야 한다")
	return out


## 설정의 파티(직업·열 목록)를 파티 정의 사전으로. 대원마다 시험 파티에서 그 직업의 첫 대원을 틀로 쓴다(스킬·장비·레벨).
## ID·name_key 는 틀의 것, 같은 직업이 또 나오면 「…_2」·「…_3」. P1 은 시험 파티와 같다(시뮬레이션은 화면 문구를 보지 않는다).
func party_dict(pid: String) -> Dictionary:
	var members := []
	var seen := {}
	for spec in config["parties"][pid]:
		var base: Dictionary = {}
		for m in template["members"]:
			if m["class"] == spec[0]:
				base = m
				break
		if base.is_empty():
			members.append({"id": "missing", "class": spec[0]})
			continue
		var m: Dictionary = base.duplicate(true)
		var n: int = seen.get(spec[0], 0) + 1
		seen[spec[0]] = n
		if n > 1:
			m["id"] = "%s_%d" % [base["id"], n]
			m["name_key"] = "%s_%d" % [base["name_key"], n]
		m["row"] = spec[1]
		members.append(m)
	return {"members": members}


## 크기 이름 → 실행 계획 {size, base_seed, cells[[파티, 편성, 정책]], games_per_cell, chain_parties[], chains_per_party, save_check_games}.
## save_check_games: 칸마다 앞 판 몇 개는 매 턴 검사 있는 저장 왕복을 돈다(06 §11.4 ①, 결과 해시에는 영향 없음).
func plan_of(size: String, base_seed: int = -1) -> Dictionary:
	var sz: Dictionary = config["sizes"][size]
	var formations: Array = []
	if typeof(sz["formations"]) == TYPE_ARRAY:
		formations = sz["formations"]
	elif sz["formations"] == "first":
		formations = [table[0][0]]
	else:
		for t in table:
			formations.append(t[0])
	var cells := []
	for p in sz["parties"]:
		for f in formations:
			for pol in sz["policies"]:
				cells.append([p, f, pol])
	return {"size": size, "base_seed": base_seed if base_seed >= 0 else int(config["base_seed"]), "cells": cells,
		"games_per_cell": int(sz["games_per_cell"]), "chain_parties": sz["chain_parties"], "chains_per_party": int(sz["chains_per_party"]),
		"save_check_games": int(sz.get("save_check_games", 0))}


## config_hash 의 원문(06 §7.6): 실제로 돌린 설정을 줄 글로.
func config_text(plan: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("size,%s" % plan["size"])
	lines.append("base_seed,%d" % plan["base_seed"])
	lines.append("games_per_cell,%d" % plan["games_per_cell"])
	for i in plan["cells"].size():
		var c: Array = plan["cells"][i]
		lines.append("cell,%d,%s,%s,%s" % [i, c[0], c[1], c[2]])
	for i in plan["chain_parties"].size():
		lines.append("chain_party,%d,%s" % [i, plan["chain_parties"][i]])
	lines.append("chains_per_party,%d" % plan["chains_per_party"])
	lines.append("chain_cap,%d" % int(config["chain_cap"]))
	lines.append("stall_limit,%d" % int(config["stall_limit"]))
	lines.append("save_check_games,%d" % int(plan.get("save_check_games", 0)))
	return "\n".join(lines) + "\n"


static func hash16(text: String) -> String:
	return text.sha256_text().substr(0, 16)


func data_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p in data_files:
		ctx.update(FileAccess.get_file_as_bytes(p))
	return ctx.finish().hex_encode().substr(0, 16)


## 읽은 data/ 파일: 전투 정의 폴더의 JSON 전부 + 층·파티 틀. 경로(data/ 아래 상대 경로) 순.
static func _data_files(data_dir: String, extra: Array) -> Array[String]:
	var rel := []
	for kind in BattleDb.KINDS:
		var dir := DirAccess.open(data_dir.path_join(kind))
		if dir == null:
			continue
		for n in dir.get_files():
			if n.ends_with(".json"):
				rel.append(kind + "/" + n)
	for p in extra:
		rel.append(str(p).trim_prefix(data_dir + "/"))
	rel.sort()
	var out: Array[String] = []
	for r in rel:
		out.append(data_dir.path_join(r))
	return out


# ---- 판 하나 ----

## 상태에 전투를 연 뒤 끝날 때까지(최대 stall_limit 제출) 정책대로 싸운다. 돌려주는 기록은 모두 정수(skills 제외).
func fight(s: ExplorationState, policy: String) -> Dictionary:
	var rec := {"outcome": "", "T": 0, "tp": 0, "damage": 0, "start_hp": 0, "ailment_turns": 0, "bind_turns": 0, "skills": {}, "enemy_hp": [], "save_errors": []}
	for m in s.party.members:
		rec["start_hp"] += m.hp
	var limit: int = config["stall_limit"]
	while s.battle != null and rec["T"] < limit:
		var b := s.battle
		var pre_ail := []
		var pre_binds := []
		for u in b.party:
			pre_ail.append(u.ailment)
			pre_binds.append(u.binds.keys())
		var ev := BattleRules.submit(s, BattlePolicy.choose(s, policy))
		if not ev.is_empty() and ev[0]["type"] == "rejected":
			rec["outcome"] = "error"
			rec["error"] = str(ev[0])
			break
		rec["T"] += 1
		_tally(rec, ev, pre_ail, pre_binds)
		if check_saves_every > 0:
			var r := SaveCodec.decode(SaveCodec.encode(s, "2026-01-01T00:00:00Z", 0), s.defs)
			if not r.ok():
				rec["save_errors"].append("T%d: %s" % [rec["T"], r.error])
	if rec["outcome"].is_empty():
		if s.battle != null:
			rec["outcome"] = "stalled"
	if s.battle != null:
		for u in s.battle.enemies:
			rec["enemy_hp"].append(u.hp)
	return rec


## 이벤트 한 턴치를 기록에 더한다. 상태 턴은 턴 끝 처리 1단계 직전(turn_end 이벤트 자리)의 상태를 이벤트로 되짚어 센다.
func _tally(rec: Dictionary, ev: Array[Dictionary], pre_ail: Array, pre_binds: Array) -> void:
	var ail := pre_ail.duplicate()
	var binds := []
	for x in pre_binds:
		binds.append(x.duplicate())
	var at_turn_end := false
	for e in ev:
		match e["type"]:
			"action":
				rec["skills"][e["skill"]] = rec["skills"].get(e["skill"], 0) + 1
				if e["unit"]["side"] == "party":
					rec["tp"] += int(e["tp"])
			"damaged", "poison_tick":
				if e["target"]["side"] == "party":
					rec["damage"] += int(e["lost"])
			"battle_end":
				rec["outcome"] = e["outcome"]
				rec["enemy_hp"] = Array(e["enemy_hp"])
		if e["type"] == "turn_end":
			at_turn_end = true
			for i in ail.size():
				if ail[i] != "":
					rec["ailment_turns"] += 1
				if not binds[i].is_empty():
					rec["bind_turns"] += 1
			continue
		if at_turn_end or typeof(e.get("target")) != TYPE_DICTIONARY or e["target"].get("side") != "party":
			continue
		var i: int = e["target"]["slot"]
		match e["type"]:
			"ailment":
				ail[i] = e["id"]
			"woke":
				ail[i] = ""
			"bound":
				if not binds[i].has(e["part"]):
					binds[i].append(e["part"])
			"cured", "defeated":
				ail[i] = ""
				binds[i].clear()


## 단일 전투 한 판: 만전에서 새 GameRng(시드)로 시작.
func run_game(defs: GameDefs, formation: String, policy: String, seed_value: int) -> Dictionary:
	var s := ExplorationRules.new_game(defs, seed_value, ExplorationRules.AUTOMAP_OFF)
	s.rng = GameRng.new(seed_value)
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, formation)
	var rec := fight(s, policy)
	rec["hp"] = s.party.members.map(func(m): return m.hp)
	rec["end_hp"] = 0
	for m in s.party.members:
		rec["end_hp"] += m.hp
	rec["rng"] = s.rng.get_state()
	return rec


## 연전 하나(06 §7.3 원정 길이 L): 시드의 GameRng 하나로 편성 뽑기와 모든 전투를 잇는다. 전투 밖 회복 없음.
func run_chain(defs: GameDefs, seed_value: int) -> Dictionary:
	var s := ExplorationRules.new_game(defs, seed_value, ExplorationRules.AUTOMAP_OFF)
	s.rng = GameRng.new(seed_value)
	var out := {"L": 0, "code": CHAIN_WIPED, "battles": 0, "tp": 0, "damage": 0, "save_errors": []}
	var cap: int = config["chain_cap"]
	while true:
		if out["L"] >= cap:
			out["code"] = CHAIN_CAP
			break
		var f := BattleRules.pick_formation(s)
		s.encounter.danger = s.encounter.threshold
		var st := BattleRules.start(s, f)
		if st[0]["type"] != "battle_start":
			out["code"] = CHAIN_ERROR
			break
		var rec := fight(s, BattlePolicy.DEFAULT)
		out["battles"] += 1
		out["tp"] += rec["tp"]
		out["damage"] += rec["damage"]
		out["save_errors"].append_array(rec["save_errors"])
		match rec["outcome"]:
			"victory":
				out["L"] += 1
			"wiped":
				out["code"] = CHAIN_WIPED
				break
			"stalled":
				out["code"] = CHAIN_STALLED
				break
			_:
				out["code"] = CHAIN_ERROR
				break
	if out["code"] == CHAIN_STALLED or out["code"] == CHAIN_ERROR:
		out["L"] = -1
	out["rng"] = s.rng.get_state()
	return out


# ---- 전체 실행 ----

## 계획을 돌린다. 보고 사전(06 §7.6, commit·machine·elapsed 는 실행기가 채운다)을 돌려준다.
## line_sink 가 있으면 원자료 줄마다 부른다(시험용).
## 계획이 틀리면 돌리지 않고 {plan_errors} 만 돌려준다(실행 오류, 종료 코드 2).
func run(plan: Dictionary, line_sink: Callable = Callable()) -> Dictionary:
	var perr := check_plan(plan)
	if not perr.is_empty():
		return {"plan_errors": perr}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var base: int = plan["base_seed"]
	var n: int = plan["games_per_cell"]
	var cells := []
	var skill_use := {}
	var games := 0
	var save_errors := []
	for ci in plan["cells"].size():
		var c: Array = plan["cells"][ci]
		var defs: GameDefs = defs_by_party[c[0]]
		var agg := _new_agg(ci, c)
		for gi in n:
			var seed_value: int = base + ci * 1_000_000 + gi
			check_saves_every = 1 if (plan.get("save_check_games", 0) > gi) else 0
			var rec := run_game(defs, c[1], c[2], seed_value)
			games += 1
			for e in rec["save_errors"]:
				save_errors.append("칸 %d 판 %d %s" % [ci, gi, e])
			_add(agg, rec)
			var by_policy: Dictionary = skill_use.get(c[2], {})
			for k in rec["skills"]:
				by_policy[k] = by_policy.get(k, 0) + rec["skills"][k]
			skill_use[c[2]] = by_policy
			var line := "B,%d,%d,%d,%d,%d,%d,%d,%s,%s,%d\n" % [ci, gi, seed_value, OUTCOME_CODES[rec["outcome"]], rec["T"], rec["tp"], rec["damage"],
				",".join(rec["hp"].map(func(x): return str(x))), ",".join(rec["enemy_hp"].map(func(x): return str(x))), rec["rng"]]
			ctx.update(line.to_utf8_buffer())
			if line_sink.is_valid():
				line_sink.call(line)
		cells.append(_finish_agg(agg))
	check_saves_every = 0
	var chains := []
	var chains_run := 0
	var battles_in_chains := 0
	for pi in plan["chain_parties"].size():
		var pid: String = plan["chain_parties"][pi]
		var ls: Array[int] = []
		var codes := {}
		var battles := 0
		var tp := 0
		var dmg := 0
		for k in plan["chains_per_party"]:
			var seed_value: int = base + 900_000_000 + pi * 1_000_000 + k
			var ch := run_chain(defs_by_party[pid], seed_value)
			chains_run += 1
			battles += ch["battles"]
			tp += ch["tp"]
			dmg += ch["damage"]
			codes[ch["code"]] = codes.get(ch["code"], 0) + 1
			if ch["L"] >= 0:
				ls.append(ch["L"])
			var line := "C,%s,%d,%d,%d,%d,%d,%d\n" % [pid, pi, k, seed_value, ch["L"], ch["code"], ch["rng"]]
			ctx.update(line.to_utf8_buffer())
			if line_sink.is_valid():
				line_sink.call(line)
		battles_in_chains += battles
		chains.append(_chain_summary(pid, ls, codes, battles, tp, dmg, plan["chains_per_party"]))
	var report := {"size": plan["size"], "base_seed": base, "config_hash": hash16(config_text(plan)), "data_hash": data_hash(),
		"games": games, "chains_run": chains_run, "battles_in_chains": battles_in_chains, "cells": cells, "chains": chains,
		"skill_use": skill_use, "save_errors": save_errors.slice(0, 20), "save_error_count": save_errors.size(),
		"result_hash": ctx.finish().hex_encode().substr(0, 16)}
	report["weighted"] = _weighted(cells)
	report["checks"] = checks(report, plan)
	return report


func _new_agg(ci: int, c: Array) -> Dictionary:
	var w := 0
	for t in table:
		if t[0] == c[1]:
			w = t[1]
	return {"cell": ci, "party": c[0], "formation": c[1], "policy": c[2], "weight": w, "games": 0,
		"outcomes": {"victory": 0, "wiped": 0, "escaped": 0, "stalled": 0, "error": 0},
		"turns": [], "turns_victory": [], "tp": 0, "damage": 0, "net_loss": 0, "ailment_turns": 0, "bind_turns": 0, "errors": []}


func _add(agg: Dictionary, rec: Dictionary) -> void:
	agg["games"] += 1
	agg["outcomes"][rec["outcome"]] += 1
	if rec["outcome"] in ["victory", "wiped", "escaped"]:
		agg["turns"].append(rec["T"])
	if rec["outcome"] == "victory":
		agg["turns_victory"].append(rec["T"])
	if rec["outcome"] == "error" and agg["errors"].size() < 3:
		agg["errors"].append(rec.get("error", ""))
	agg["tp"] += rec["tp"]
	agg["damage"] += rec["damage"]
	agg["net_loss"] += rec["start_hp"] - rec["end_hp"]
	agg["ailment_turns"] += rec["ailment_turns"]
	agg["bind_turns"] += rec["bind_turns"]


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := 0
	for x in xs:
		s += x
	return float(s) / xs.size()


## 아래 중앙값: 오름차순 (n − 1) / 2 번째.
static func lower_median(xs: Array) -> int:
	if xs.is_empty():
		return -1
	var v := xs.duplicate()
	v.sort()
	return v[(v.size() - 1) / 2]


func _finish_agg(agg: Dictionary) -> Dictionary:
	var g: int = maxi(1, agg["games"])
	var dist := []
	dist.resize(11)
	dist.fill(0)
	for t in agg["turns"]:
		dist[mini(t, 11) - 1] += 1
	var out := agg.duplicate(true)
	out.erase("turns")
	out.erase("turns_victory")
	out["avg_turns"] = _mean(agg["turns"])
	out["avg_turns_victory"] = _mean(agg["turns_victory"])
	out["median_turns"] = lower_median(agg["turns"])
	out["turn_dist"] = dist
	out["wipe_rate"] = float(agg["outcomes"]["wiped"]) / g
	out["avg_tp"] = float(agg["tp"]) / g
	out["avg_damage"] = float(agg["damage"]) / g
	out["avg_net_loss"] = float(agg["net_loss"]) / g
	return out


func _chain_summary(pid: String, ls: Array[int], codes: Dictionary, battles: int, tp: int, dmg: int, planned: int) -> Dictionary:
	var v := Array(ls)
	v.sort()
	var deciles := []
	for d in range(1, 10):
		deciles.append(v[(v.size() - 1) * d / 10] if not v.is_empty() else -1)
	var dist := {}
	for x in v:
		dist[str(x)] = dist.get(str(x), 0) + 1
	return {"party": pid, "chains": planned, "counted": v.size(), "median_L": lower_median(v), "mean_L": _mean(v), "deciles": deciles,
		"min_L": v[0] if not v.is_empty() else -1, "max_L": v[-1] if not v.is_empty() else -1, "L_dist": dist,
		"codes": {"wiped": codes.get(CHAIN_WIPED, 0), "cap": codes.get(CHAIN_CAP, 0), "stalled": codes.get(CHAIN_STALLED, 0), "error": codes.get(CHAIN_ERROR, 0)},
		"battles": battles, "avg_tp_per_battle": float(tp) / maxi(1, battles), "avg_damage_per_battle": float(dmg) / maxi(1, battles)}


## (파티, 정책) → 출현 표 가중 평균 턴.
func _weighted(cells: Array) -> Dictionary:
	var acc := {}
	for c in cells:
		var key: String = "%s/%s" % [c["party"], c["policy"]]
		var a: Array = acc.get(key, [0.0, 0])
		a[0] += c["avg_turns"] * c["weight"]
		a[1] += c["weight"]
		acc[key] = a
	var out := {}
	for k in acc:
		out[k] = acc[k][0] / maxf(1.0, acc[k][1])
	return out


## 판정 목록. 판정마다 kind 가 있다:
##   exec    실행·불변 조건(교착·오류·완료·표본 저장 왕복·필수 결과). 실패하면 종료 코드 2. 늘 종료 코드에 쓴다.
##   balance 밸런스 범위. gate 가 참일 때만 종료 코드 1 을 정한다: small 은 연기 범위(06 §7.5 끝), large 는 §7.5 표.
## small 에서도 §7.5 표를 참고(gate 거짓)로 함께 적는다. probe 에는 balance 판정이 없다(종료 코드 0·2, 06 §7.4).
## small·large 에서 판정에 필요한 결과가 없으면 건너뛰지 않고 exec 실패로 적는다.
func checks(report: Dictionary, plan: Dictionary) -> Array:
	var acc: Dictionary = config["acceptance"]
	var out := []
	var size: String = plan["size"]
	var stalled := 0
	var errs := 0
	var incomplete := 0
	for c in report["cells"]:
		stalled += c["outcomes"]["stalled"]
		errs += c["outcomes"]["error"]
		if c["games"] != plan["games_per_cell"]:
			incomplete += 1
	for ch in report["chains"]:
		stalled += ch["codes"]["stalled"]
		errs += ch["codes"]["error"]
	var planned_games: int = plan["cells"].size() * plan["games_per_cell"]
	var planned_chains: int = plan["chain_parties"].size() * plan["chains_per_party"]
	out.append(_check("교착 0", stalled, "0", stalled == 0, "exec"))
	out.append(_check("오류 0", errs, "0", errs == 0, "exec"))
	out.append(_check("모든 판 완료", "%d/%d 판, %d/%d 연전" % [report["games"], planned_games, report["chains_run"], planned_chains],
		"계획 수", incomplete == 0 and report["cells"].size() == plan["cells"].size() and report["games"] == planned_games and report["chains_run"] == planned_chains, "exec"))
	if report.get("save_error_count", 0) > 0 or plan.get("save_check_games", 0) > 0:
		out.append(_check("표본 판 매 턴 저장 왕복", report.get("save_error_count", 0), "0", report.get("save_error_count", 0) == 0, "exec"))
	if not size in PRODUCTION_SIZES:
		return out
	var large := size == "large"
	var w: Dictionary = report["weighted"]
	var missing := []
	if size == "small":
		var r: Array = acc["small_p1_weighted_turns"]
		if w.has("P1/default"):
			var v: float = w["P1/default"]
			out.append(_check("P1 기본 가중 평균 턴(small 연기)", snappedf(v, 0.01), "%s~%s" % r, v >= r[0] and v <= r[1], "balance", true))
		else:
			missing.append("P1/default")
	var wt: Array = acc["weighted_turns"]
	for p in SPEC_PARTIES:
		var key: String = p + "/default"
		if not w.has(key):
			missing.append(key)
			continue
		out.append(_check("%s 기본 가중 평균 턴" % p, snappedf(w[key], 0.01), "%s~%s" % wt, w[key] >= wt[0] and w[key] <= wt[1], "balance", large))
	var ft: Array = acc["p1_formation_turns"]
	var wmax: float = acc["wipe_rate_max"]
	var border: Array = acc["wipe_rate_border"]
	for p in SPEC_PARTIES:
		for f in table.map(func(x): return x[0]):
			var c: Dictionary = {}
			for x in report["cells"]:
				if x["party"] == p and x["formation"] == f and x["policy"] == BattlePolicy.DEFAULT:
					c = x
			if c.is_empty():
				missing.append("%s/%s/default" % [p, f])
				continue
			if p == "P1":
				out.append(_check("P1 %s 평균 턴" % f, snappedf(c["avg_turns"], 0.01), "%s~%s" % ft, c["avg_turns"] >= ft[0] and c["avg_turns"] <= ft[1], "balance", large))
			var wr: float = c["wipe_rate"]
			var chk := _check("%s %s 전멸률" % [p, f], "%.1f%%" % (wr * 100.0), "≤ %.0f%%" % (wmax * 100.0), wr <= wmax, "balance", large)
			if wr >= border[0] and wr <= border[1]:
				chk["border"] = true
			out.append(chk)
	var p1_chain: Dictionary = {}
	for ch in report["chains"]:
		if ch["party"] == "P1":
			p1_chain = ch
	if p1_chain.is_empty() or p1_chain["counted"] == 0:
		missing.append("P1 연전 L")
	else:
		var mr: Array = acc["p1_chain_median"]
		out.append(_check("P1 원정 길이 L 중앙값", p1_chain["median_L"], "%d~%d" % [mr[0], mr[1]], p1_chain["median_L"] >= mr[0] and p1_chain["median_L"] <= mr[1], "balance", large))
	for p in SPEC_PARTIES:
		if not (w.has(p + "/full") and w.has(p + "/default")):
			missing.append(p + "/full")
			continue
		var d: float = w[p + "/full"] - w[p + "/default"]
		out.append(_check("%s 전력 ≤ 기본 + %s" % [p, acc["full_minus_default_max"]], snappedf(d, 0.01), "≤ %s" % acc["full_minus_default_max"], d <= acc["full_minus_default_max"], "balance", large))
	out.append(_check("판정에 필요한 결과가 모두 있음", "없음 %d" % missing.size() if missing.is_empty() else "없음: %s" % ", ".join(missing), "0", missing.is_empty(), "exec"))
	return out


## gate: exec 는 늘 참, balance 는 인자로.
static func _check(name: String, value: Variant, range_text: String, ok: bool, kind: String, gate: bool = true) -> Dictionary:
	return {"name": name, "value": value, "range": range_text, "pass": ok, "kind": kind, "gate": gate or kind == "exec"}


## 종료 코드(06 §7.6): 2 = 설정·계획·보고서 쓰기·실행·불변 조건 실패, 1 = gate 인 밸런스 범위 실패, 0 = 통과.
static func exit_code(report: Dictionary, write_error: String = "") -> int:
	if not write_error.is_empty() or report.has("plan_errors") or not report.has("checks"):
		return 2
	var balance_fail := false
	for c in report["checks"]:
		if c["pass"]:
			continue
		if c["kind"] == "exec":
			return 2
		if c["gate"]:
			balance_fail = true
	return 1 if balance_fail else 0


## 보고서를 쓴다. 폴더 만들기·열기·쓰기·다시 읽어 맞춰 보기 중 하나라도 실패하면 이유 문자열, 성공하면 "".
static func write_report(report: Dictionary, abs_path: String) -> String:
	var dir_err := DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if dir_err != OK:
		return "보고서 폴더를 만들지 못했다(%s): %s" % [error_string(dir_err), abs_path.get_base_dir()]
	var text := JSON.stringify(report, "  ", false)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return "보고서를 열지 못했다(%s): %s" % [error_string(FileAccess.get_open_error()), abs_path]
	var ok: bool = f.store_string(text)
	var err := f.get_error()
	f.close()
	if not ok or err != OK:
		return "보고서를 쓰지 못했다(%s): %s" % [error_string(err), abs_path]
	if FileAccess.get_file_as_string(abs_path) != text:
		return "보고서를 다시 읽어 보니 쓴 내용과 다르다: %s" % abs_path
	return ""
