## 시험 파티 정의(data/party/*.json, 06 §5.3). 대원마다 id·name_key·class·level·row·skills·gear. 순서가 칸 순서다.
## 최대 HP·TP 는 직업 레벨 표에서 온다: resolve(BattleDb) 가 참조를 검사하며 채운다.
class_name PartyData
extends RefCounted

const MEMBER_KEYS := ["id", "name_key", "class", "level", "row", "skills", "gear"]
const MEMBER_ID_PATTERN := "\\A[a-z0-9_]+\\z"

var ids: Array[String] = []
var name_keys: Array[String] = []
var class_ids: Array[String] = []
var levels: Array[int] = []
var rows: Array[String] = []
## 대원마다 스킬 ID → 스킬 레벨.
var skills: Array[Dictionary] = []
## 대원마다 {atk, matk, def, mdef}.
var gears: Array[Dictionary] = []
## resolve() 뒤에 채워진다.
var max_hps: Array[int] = []
var max_tps: Array[int] = []
var errors: Array[String] = []
var source := ""


## 형식만 검사해 읽는다(참조는 resolve 가 본다).
static func read_path(path: String) -> PartyData:
	return parse_text(FileAccess.get_file_as_string(path), path.get_file())


static func parse_text(text: String, src: String) -> PartyData:
	var json := JSON.new()
	if json.parse(text) != OK:
		var p := PartyData.new()
		p.source = src
		p.errors.append("%s: %d줄: JSON 읽기 실패: %s" % [src, json.get_error_line() + 1, json.get_error_message()])
		return p
	return parse_dict(json.data, src)


static func parse_dict(data: Variant, src: String) -> PartyData:
	var p := PartyData.new()
	p.source = src
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("members")) != TYPE_ARRAY:
		p.errors.append("%s: members: 배열이 없다" % src)
		return p
	for k in data:
		if k != "members":
			p._err(str(k), "모르는 필드")
	var list: Array = data["members"]
	if list.size() != BattleLimits.PARTY_SIZE:
		p._err("members", "대원은 %d명이어야 한다(지금 %d명)" % [BattleLimits.PARTY_SIZE, list.size()])
	var id_re := RegEx.create_from_string(MEMBER_ID_PATTERN)
	var per_row := {"front": 0, "back": 0}
	for i in list.size():
		var path := "members[%d]" % i
		var m: Variant = list[i]
		if typeof(m) != TYPE_DICTIONARY:
			p._err(path, "객체여야 한다")
			continue
		var missing := false
		for k in MEMBER_KEYS:
			if not m.has(k):
				p._err("%s.%s" % [path, k], "필수 필드가 없다")
				missing = true
		for k in m:
			if not MEMBER_KEYS.has(k):
				p._err("%s.%s" % [path, k], "모르는 필드")
		if missing:
			continue
		var before := p.errors.size()
		if typeof(m["id"]) != TYPE_STRING or id_re.search(m["id"]) == null:
			p._err(path + ".id", "대원 ID 형식(%s)이 아니다" % MEMBER_ID_PATTERN)
		elif p.ids.has(m["id"]):
			p._err(path + ".id", "대원 ID %s 가 중복이다" % m["id"])
		if typeof(m["name_key"]) != TYPE_STRING or m["name_key"].is_empty():
			p._err(path + ".name_key", "비지 않은 문자열이어야 한다")
		if typeof(m["class"]) != TYPE_STRING or not str(m["class"]).begins_with("class."):
			p._err(path + ".class", "class. 로 시작하는 ID 여야 한다")
		var level: Variant = SaveCodec.to_int(m["level"])
		if level == null or typeof(m["level"]) == TYPE_BOOL or not BattleLimits.in_range("level", level):
			p._err(path + ".level", "정수 %s 이어야 한다" % BattleLimits.range_text("level"))
		if not BattleDb.ROWS.has(m["row"]):
			p._err(path + ".row", "front·back 중 하나여야 한다")
		else:
			per_row[m["row"]] += 1
		var sk := {}
		if typeof(m["skills"]) != TYPE_DICTIONARY:
			p._err(path + ".skills", "객체여야 한다")
		else:
			for sid in m["skills"]:
				var lv: Variant = SaveCodec.to_int(m["skills"][sid])
				if lv == null or typeof(m["skills"][sid]) == TYPE_BOOL or not BattleLimits.in_range("level", lv):
					p._err("%s.skills.%s" % [path, sid], "스킬 레벨은 정수 %s 이어야 한다" % BattleLimits.range_text("level"))
				else:
					sk[sid] = lv
		var gear := {}
		if typeof(m["gear"]) != TYPE_DICTIONARY:
			p._err(path + ".gear", "객체여야 한다")
		else:
			for k in BattleLimits.GEAR:
				var v: Variant = SaveCodec.to_int(m["gear"].get(k))
				if v == null or typeof(m["gear"].get(k)) == TYPE_BOOL or not BattleLimits.in_range("gear", v):
					p._err("%s.gear.%s" % [path, k], "정수 %s 이어야 한다" % BattleLimits.range_text("gear"))
				else:
					gear[k] = v
			for k in m["gear"]:
				if not BattleLimits.GEAR.has(k):
					p._err("%s.gear.%s" % [path, k], "모르는 필드")
		if p.errors.size() != before:
			continue
		p.ids.append(m["id"])
		p.name_keys.append(m["name_key"])
		p.class_ids.append(m["class"])
		p.levels.append(level)
		p.rows.append(m["row"])
		p.skills.append(sk)
		p.gears.append(gear)
	for row in BattleDb.ROWS:
		if per_row[row] > BattleLimits.ROW_MAX:
			p._err("members", "%s 줄이 %d명을 넘는다" % [row, BattleLimits.ROW_MAX])
	return p


## 전투 정의와 맞춰 본다: 직업이 있음, 레벨이 직업 레벨 표에 있음, 대원 스킬은 그 직업의 스킬, 스킬 레벨 ≤ 줄 수.
## 오류는 errors 에 더하고, 오류가 없으면 max_hps·max_tps 를 채운다.
func resolve(db: BattleDb) -> void:
	var before := errors.size()
	var hps: Array[int] = []
	var tps: Array[int] = []
	for i in ids.size():
		var path := "members[%d]" % i
		var c: BattleDb.ClassDef = db.classes.get(class_ids[i])
		if c == null:
			_err(path + ".class", "없는 직업 %s" % class_ids[i])
			continue
		if not c.levels.has(levels[i]):
			_err(path + ".level", "%s 레벨 표에 %d 이 없다" % [class_ids[i], levels[i]])
			continue
		for sid in skills[i]:
			var s: BattleDb.SkillDef = db.skills.get(sid)
			if s == null or not c.skills.has(sid):
				_err("%s.skills.%s" % [path, sid], "%s 의 스킬이 아니다" % class_ids[i])
			elif skills[i][sid] > s.levels.size():
				_err("%s.skills.%s" % [path, sid], "스킬 레벨 %d 이 줄 수 %d 를 넘는다" % [skills[i][sid], s.levels.size()])
		hps.append(c.levels[levels[i]]["hp"])
		tps.append(c.levels[levels[i]]["tp"])
	if errors.size() == before:
		max_hps = hps
		max_tps = tps


## HP·TP를 가득 채운 대원 목록. 부를 때마다 새 객체다.
func make_members() -> Array[PartyState.Member]:
	var out: Array[PartyState.Member] = []
	for i in mini(ids.size(), max_hps.size()):
		out.append(PartyState.Member.new(ids[i], max_hps[i], max_hps[i], max_tps[i], max_tps[i]))
	return out


func _err(path: String, msg: String) -> void:
	errors.append("%s: %s: %s" % [source, path, msg])
