## 의뢰·주요 임무 정의(M3 A8 설계 §2): data/quests/*.json. 층 묶음 파일의 "quests" 키가 가리키는 파일 하나만 읽는다(게임 묶음만, 시험 묶음은 없다).
## parse_* 가 형식을, resolve 가 전투 정의·층·화면 문구 참조를 본다. 오류는 「파일: 의뢰 ID: 필드: 내용」.
## 의뢰 하나: id(정보상 바 quest.*, 관리국 mission.*)·giver·글 키·발급 조건(unlock, 모두 맞아야 한다)·목표 하나·보수·반복(선택).
class_name QuestDb
extends RefCounted

const GIVERS := ["pub", "council"]
const QUEST_KEYS := ["id", "giver", "name_key", "desc_key", "client_key", "unlock", "objective", "reward"]
const QUEST_OPTIONAL := ["repeat"]
## 목표 종류(설계 §4.3, 닫힌 넷)와 종류마다 정확한 키.
const OBJECTIVE_KEYS := {
	"kill": ["kind", "enemy", "count"],
	"foe": ["kind", "foe", "count"],
	"deliver": ["kind", "item", "count"],
	"reach": ["kind", "floor", "at", "where_key"],
}
## 발급 조건 종류(설계 §4.2, 닫힌 넷)와 정확한 키.
const UNLOCK_KEYS := {
	"reported": ["kind", "quest"],
	"visited": ["kind", "floor"],
	"day": ["kind", "min"],
	"level": ["kind", "min"],
}
const REWARD_KEYS := ["money", "exp", "items", "flags"]
const REWARD_ITEM_KEYS := ["item", "count"]
const COUNT_MAX := 99
const FOE_COUNT_MAX := 9
const MONEY_MAX := 99999
const EXP_MAX := 9999
const REWARD_ITEMS_MAX := 4
const REPEAT_DAYS_MAX := 99
const ID_PATTERNS := {"pub": "\\Aquest\\.[a-z0-9_]+\\z", "council": "\\Amission\\.[a-z0-9_]+\\z"}
## 진행 플래그 꼴(설계 §2.3): 점으로 나뉜 두 조각 이상. 층 계단의 needs 도 같은 꼴이다(FloorLoader).
const FLAG_PATTERN := "\\A[a-z0-9_]+\\.[a-z0-9_.]+\\z"


class QuestDef:
	extends RefCounted
	var id := ""
	var giver := ""
	var name_key := ""
	var desc_key := ""
	var client_key := ""
	## [{kind, quest | floor | min}]
	var unlock: Array[Dictionary] = []
	## kill · foe · deliver · reach
	var kind := ""
	## kill: 적 ID, foe: FOE 정의 ID, deliver: 물건 ID. reach 는 "".
	var target := ""
	## 목표 수(reach 는 1).
	var count := 1
	var floor := ""
	var at := Vector2i.ZERO
	var where_key := ""
	var money := 0
	var exp := 0
	## [{item, count}]
	var items: Array[Dictionary] = []
	var flags: Array[String] = []
	## 다시 받을 수 있게 되는 날 수(보고한 날 + days). 반복하지 않으면 −1.
	var repeat_days := -1

	func repeats() -> bool:
		return repeat_days >= 0

	## 진행 칸이 세는 목표(kill·foe·reach)인지. deliver 는 가방에서 그때그때 읽는다.
	func counted() -> bool:
		return kind != "deliver"


## 의뢰 ID → QuestDef, 파일 차례의 ID 목록.
var quests := {}
var order: Array[String] = []
## 진행 플래그 → 그 플래그를 주는 의뢰 ID(플래그마다 하나).
var flag_source := {}
var errors: Array[String] = []
var source := ""


static func load_path(path: String) -> QuestDb:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and FileAccess.get_open_error() != OK:
		var q := QuestDb.new()
		q.source = path.get_file()
		q.errors.append("%s: 파일을 읽을 수 없다 (%s)" % [path, error_string(FileAccess.get_open_error())])
		return q
	return parse_text(text, path.get_file())


static func parse_text(text: String, src: String) -> QuestDb:
	var json := JSON.new()
	if json.parse(text) != OK:
		var q := QuestDb.new()
		q.source = src
		q.errors.append("%s: %d줄: JSON 읽기 실패: %s" % [src, json.get_error_line() + 1, json.get_error_message()])
		return q
	return parse_dict(json.data, src)


## 형식 검사(참조는 resolve).
static func parse_dict(data: Variant, src: String) -> QuestDb:
	var q := QuestDb.new()
	q.source = src
	if typeof(data) != TYPE_DICTIONARY or data.size() != 1 or typeof(data.get("quests")) != TYPE_ARRAY:
		q.errors.append("%s: 맨 위는 {\"quests\": [...]} 하나여야 한다" % src)
		return q
	var list: Array = data["quests"]
	if list.is_empty():
		q.errors.append("%s: quests 가 비었다" % src)
		return q
	for i in list.size():
		q._read_quest(list[i], "quests[%d]" % i)
	return q


func ok() -> bool:
	return errors.is_empty()


func is_empty() -> bool:
	return order.is_empty()


func get_def(id: String) -> QuestDef:
	return quests.get(id)


## 이 시설(pub·council)이 내는 의뢰가 있는지(광장 줄이 열리는지, 설계 §5.4).
func has_giver(giver: String) -> bool:
	return order.any(func(id: String) -> bool: return quests[id].giver == giver)


## 어느 의뢰가 주는 진행 플래그인지.
func knows_flag(flag: String) -> bool:
	return flag_source.has(flag)


func _err(where: String, msg: String) -> void:
	errors.append("%s: %s: %s" % [source, where, msg])


## v 가 정수(정수와 같은 실수 포함)이고 lo~hi 안이면 그 값, 아니면 null.
static func _int_in(v: Variant, lo: int, hi: int) -> Variant:
	if typeof(v) == TYPE_BOOL:
		return null
	var n: Variant = SaveCodec.to_int(v)
	if n == null or n < lo or n > hi:
		return null
	return n


## d 의 키가 정확히 keys(+ optional)인지. 아니면 오류를 남기고 false.
func _exact(d: Variant, keys: Array, where: String, optional: Array = []) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		_err(where, "객체여야 한다")
		return false
	var good := true
	for k in keys:
		if not d.has(k):
			_err("%s.%s" % [where, k], "필수 필드가 없다")
			good = false
	for k in d:
		if not keys.has(k) and not optional.has(k):
			_err("%s.%s" % [where, str(k)], "모르는 필드")
			good = false
	return good


func _key_text(d: Dictionary, k: String, where: String) -> String:
	if typeof(d.get(k)) != TYPE_STRING or str(d[k]).is_empty():
		_err("%s.%s" % [where, k], "비지 않은 문자열이어야 한다")
		return ""
	return d[k]


func _read_quest(d: Variant, path: String) -> void:
	if typeof(d) == TYPE_DICTIONARY and typeof(d.get("id")) == TYPE_STRING:
		path = str(d["id"])
	if not _exact(d, QUEST_KEYS, path, QUEST_OPTIONAL):
		return
	var before := errors.size()
	var q := QuestDef.new()
	var giver: Variant = d["giver"]
	if typeof(giver) != TYPE_STRING or not GIVERS.has(giver):
		_err(path + ".giver", "pub·council 가운데 하나여야 한다")
	else:
		q.giver = giver
		if typeof(d["id"]) != TYPE_STRING or RegEx.create_from_string(ID_PATTERNS[giver]).search(d["id"]) == null:
			_err(path + ".id", "%s 의 ID 는 %s 꼴이어야 한다" % [giver, ID_PATTERNS[giver]])
		elif quests.has(d["id"]):
			_err(path + ".id", "ID 가 중복이다")
		else:
			q.id = d["id"]
	q.name_key = _key_text(d, "name_key", path)
	q.desc_key = _key_text(d, "desc_key", path)
	q.client_key = _key_text(d, "client_key", path)
	_read_unlock(d["unlock"], path + ".unlock", q)
	_read_objective(d["objective"], path + ".objective", q)
	_read_reward(d["reward"], path + ".reward", q)
	if d.has("repeat"):
		if q.giver == "council":
			_err(path + ".repeat", "주요 임무는 반복하지 않는다")
		elif _exact(d["repeat"], ["days"], path + ".repeat"):
			var days: Variant = _int_in(d["repeat"]["days"], 0, REPEAT_DAYS_MAX)
			if days == null:
				_err(path + ".repeat.days", "정수 0~%d 이어야 한다" % REPEAT_DAYS_MAX)
			else:
				q.repeat_days = days
	if errors.size() == before:
		quests[q.id] = q
		order.append(q.id)


func _read_unlock(v: Variant, path: String, q: QuestDef) -> void:
	if typeof(v) != TYPE_ARRAY:
		_err(path, "배열이어야 한다")
		return
	for i in v.size():
		var c: Variant = v[i]
		var where := "%s[%d]" % [path, i]
		var kind: Variant = c.get("kind") if typeof(c) == TYPE_DICTIONARY else null
		if typeof(kind) != TYPE_STRING or not UNLOCK_KEYS.has(kind):
			_err(where + ".kind", "reported·visited·day·level 가운데 하나여야 한다")
			continue
		if not _exact(c, UNLOCK_KEYS[kind], where):
			continue
		match kind:
			"reported":
				var id := _key_text(c, "quest", where)
				if not id.is_empty():
					q.unlock.append({"kind": kind, "quest": id})
			"visited":
				var fl := _key_text(c, "floor", where)
				if not fl.is_empty():
					q.unlock.append({"kind": kind, "floor": fl})
			"day", "level":
				var hi := ExplorationState.DAY_MAX if kind == "day" else BattleLimits.RANGES["level"][1]
				var n: Variant = _int_in(c["min"], 1, hi)
				if n == null:
					_err(where + ".min", "정수 1~%d 이어야 한다" % hi)
				else:
					q.unlock.append({"kind": kind, "min": n})


func _read_objective(v: Variant, path: String, q: QuestDef) -> void:
	var kind: Variant = v.get("kind") if typeof(v) == TYPE_DICTIONARY else null
	if typeof(kind) != TYPE_STRING or not OBJECTIVE_KEYS.has(kind):
		_err(path + ".kind", "kill·foe·deliver·reach 가운데 하나여야 한다")
		return
	if not _exact(v, OBJECTIVE_KEYS[kind], path):
		return
	q.kind = kind
	if kind == "reach":
		q.floor = _key_text(v, "floor", path)
		q.where_key = _key_text(v, "where_key", path)
		var at: Variant = v["at"]
		var x: Variant = _int_in(at[0], 0, 255) if typeof(at) == TYPE_ARRAY and at.size() == 2 else null
		var y: Variant = _int_in(at[1], 0, 255) if typeof(at) == TYPE_ARRAY and at.size() == 2 else null
		if x == null or y == null:
			_err(path + ".at", "[x, y] 정수 둘이어야 한다")
		else:
			q.at = Vector2i(x, y)
		q.count = 1
		return
	var field: String = {"kill": "enemy", "foe": "foe", "deliver": "item"}[kind]
	q.target = _key_text(v, field, path)
	var hi := FOE_COUNT_MAX if kind == "foe" else COUNT_MAX
	var n: Variant = _int_in(v["count"], 1, hi)
	if n == null:
		_err(path + ".count", "정수 1~%d 이어야 한다" % hi)
	else:
		q.count = n


func _read_reward(v: Variant, path: String, q: QuestDef) -> void:
	if not _exact(v, REWARD_KEYS, path):
		return
	var money: Variant = _int_in(v["money"], 0, MONEY_MAX)
	if money == null:
		_err(path + ".money", "정수 0~%d 이어야 한다" % MONEY_MAX)
	else:
		q.money = money
	var exp: Variant = _int_in(v["exp"], 0, EXP_MAX)
	if exp == null:
		_err(path + ".exp", "정수 0~%d 이어야 한다" % EXP_MAX)
	else:
		q.exp = exp
	var items: Variant = v["items"]
	if typeof(items) != TYPE_ARRAY or items.size() > REWARD_ITEMS_MAX:
		_err(path + ".items", "줄 %d개 이하의 배열이어야 한다" % REWARD_ITEMS_MAX)
	else:
		var seen := {}
		for i in items.size():
			var where := "%s.items[%d]" % [path, i]
			if not _exact(items[i], REWARD_ITEM_KEYS, where):
				continue
			var id := _key_text(items[i], "item", where)
			var n: Variant = _int_in(items[i]["count"], 1, COUNT_MAX)
			if n == null:
				_err(where + ".count", "정수 1~%d 이어야 한다" % COUNT_MAX)
			elif seen.has(id):
				_err(where + ".item", "물건 %s 가 두 줄이다" % id)
			elif not id.is_empty():
				seen[id] = true
				q.items.append({"item": id, "count": n})
	var flags: Variant = v["flags"]
	if typeof(flags) != TYPE_ARRAY:
		_err(path + ".flags", "배열이어야 한다")
		return
	var re := RegEx.create_from_string(FLAG_PATTERN)
	for f in flags:
		if typeof(f) != TYPE_STRING or re.search(f) == null:
			_err(path + ".flags", "플래그 %s 가 %s 꼴이 아니다" % [str(f), FLAG_PATTERN])
		elif q.flags.has(f):
			_err(path + ".flags", "플래그 %s 가 두 번 있다" % f)
		elif flag_source.has(f):
			_err(path + ".flags", "플래그 %s 는 이미 %s 가 준다(플래그마다 의뢰 하나)" % [f, flag_source[f]])
		else:
			q.flags.append(f)
			if not q.id.is_empty():
				flag_source[f] = q.id


## 참조 검사(설계 §2.3): 전투 정의·묶음 층·화면 문구. text_db 가 null 이면 문구는 보지 않는다.
func resolve(db: BattleDb, floor_list: Array[FloorModel], text_db: TextDb) -> void:
	var floors := {}
	var table_enemies := {}
	var placed_foes := {}
	for f in floor_list:
		floors[f.id] = f
		for fid in db.table_formations(f.encounter_table):
			var fm: BattleDb.FormationDef = db.formations.get(fid)
			if fm != null:
				for e in fm.enemies:
					table_enemies[e["enemy"]] = true
		for s in f.foe_list():
			placed_foes[s.foe] = true
	for id in order:
		var q: QuestDef = quests[id]
		var keys := [q.name_key, q.desc_key, q.client_key]
		if q.kind == "reach":
			keys.append(q.where_key)
		if text_db != null:
			for k in keys:
				if not text_db.has(k):
					_err(id, "ko.json 에 %s 가 없다" % k)
		match q.kind:
			"kill":
				if not db.enemies.has(q.target):
					_err(id + ".objective.enemy", "적 %s 가 정의에 없다" % q.target)
				elif not table_enemies.has(q.target):
					_err(id + ".objective.enemy", "적 %s 가 묶음 층의 출현 표에 없다(FOE 는 foe 목표)" % q.target)
			"foe":
				if db.foe(q.target) == null:
					_err(id + ".objective.foe", "FOE %s 가 정의에 없다" % q.target)
				elif not placed_foes.has(q.target):
					_err(id + ".objective.foe", "FOE %s 가 묶음 층에 놓이지 않았다" % q.target)
			"deliver":
				if q.target.begins_with("key."):
					_err(id + ".objective.item", "귀중품은 건넬 수 없다")
				elif not _bag_item(db, q.target):
					_err(id + ".objective.item", "물건 %s 가 가방 물건(소모품·장비·소재) 정의에 없다" % q.target)
			"reach":
				var f: FloorModel = floors.get(q.floor)
				if f == null:
					_err(id + ".objective.floor", "층 %s 가 묶음에 없다" % q.floor)
				elif not f.in_bounds(q.at) or f.cell_kind(q.at) == FloorModel.Cell.VOID:
					_err(id + ".objective.at", "%s %d:%d 가 설 수 있는 칸이 아니다" % [q.floor, q.at.x, q.at.y])
				elif f.is_reserved(q.at):
					_err(id + ".objective.at", "%s %d:%d 가 비워 둔 자리(reserved) 안이다" % [q.floor, q.at.x, q.at.y])
		for r in q.items:
			var it: String = r["item"]
			if it.begins_with("key."):
				_err(id + ".reward.items", "귀중품 %s 는 상자에서만 얻는다(저장 검사가 열쇠와 상자를 맞물려 본다)" % it)
			elif not _bag_item(db, it):
				_err(id + ".reward.items", "물건 %s 가 가방 물건 정의에 없다" % it)
		for c in q.unlock:
			match c["kind"]:
				"reported":
					if c["quest"] == id:
						_err(id + ".unlock", "자기 자신을 조건으로 둘 수 없다")
					elif not quests.has(c["quest"]):
						_err(id + ".unlock", "의뢰 %s 가 없다" % c["quest"])
				"visited":
					if not floors.has(c["floor"]):
						_err(id + ".unlock", "층 %s 가 묶음에 없다" % c["floor"])
				"level":
					if c["min"] > db.growth.level_cap:
						_err(id + ".unlock", "레벨 %d 가 상한 %d 보다 높다" % [c["min"], db.growth.level_cap])
	_check_cycles()


static func _bag_item(db: BattleDb, id: String) -> bool:
	return db.consumables.has(id) or db.equipment.has(id) or db.materials.has(id)


## reported 조건의 고리(깊이 우선): 고리 안의 의뢰는 영영 열리지 않는다.
func _check_cycles() -> void:
	var mark := {}  # id → 1 방문 중, 2 끝
	for id in order:
		_visit(id, mark, [])


func _visit(id: String, mark: Dictionary, stack: Array) -> void:
	if mark.get(id, 0) == 2 or not quests.has(id):
		return
	if mark.get(id, 0) == 1:
		_err(id + ".unlock", "reported 조건이 고리다: %s" % " → ".join(stack + [id]))
		return
	mark[id] = 1
	for c in quests[id].unlock:
		if c["kind"] == "reported":
			_visit(c["quest"], mark, stack + [id])
	mark[id] = 2
