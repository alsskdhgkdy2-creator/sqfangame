## 시작 파티 정의(data/party/*.json, 3판 형식 07 §7.6). 대원마다 id·name_key·class·level·row·skills·equip. 순서가 칸 순서다.
## skills 는 시작 배분(스킬 ID → 스킬 레벨), equip 은 칸 넷(장비 ID 또는 null).
## resolve(BattleDb) 가 참조와 트리·SP·장착 규칙을 검사한다. 최대 HP·TP 는 대원 상태에서 성장 묶음으로 계산한다(GrowthRules.profile).
class_name PartyData
extends RefCounted

const MEMBER_KEYS := ["id", "name_key", "class", "level", "row", "skills", "equip"]
const MEMBER_ID_PATTERN := "\\A[a-z0-9_]+\\z"

var ids: Array[String] = []
var name_keys: Array[String] = []
var class_ids: Array[String] = []
var levels: Array[int] = []
var rows: Array[String] = []
## 대원마다 시작 배분: 스킬 ID → 스킬 레벨.
var skills: Array[Dictionary] = []
## 대원마다 시작 장비 칸 넷(빈 칸 "").
var equips: Array[Array] = []
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
	var equip_re := RegEx.create_from_string(BattleDb.ID_PATTERN)
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
				if lv == null or typeof(m["skills"][sid]) == TYPE_BOOL or not BattleLimits.in_range("skill_level", lv):
					p._err("%s.skills.%s" % [path, sid], "스킬 레벨은 정수 %s 이어야 한다" % BattleLimits.range_text("skill_level"))
				else:
					sk[sid] = lv
		var eq: Array[String] = []
		var ev: Variant = m["equip"]
		if typeof(ev) != TYPE_ARRAY or ev.size() != BattleLimits.EQUIP_SLOTS:
			p._err(path + ".equip", "길이 %d 의 배열이어야 한다(칸마다 장비 ID 또는 null)" % BattleLimits.EQUIP_SLOTS)
		else:
			for j in ev.size():
				if ev[j] == null:
					eq.append("")
				elif typeof(ev[j]) != TYPE_STRING or equip_re.search(ev[j]) == null or not str(ev[j]).begins_with("equip."):
					p._err("%s.equip[%d]" % [path, j], "null 또는 equip. 로 시작하는 장비 ID 여야 한다")
				else:
					eq.append(ev[j])
		if p.errors.size() != before:
			continue
		p.ids.append(m["id"])
		p.name_keys.append(m["name_key"])
		p.class_ids.append(m["class"])
		p.levels.append(level)
		p.rows.append(m["row"])
		p.skills.append(sk)
		p.equips.append(eq)
	for row in BattleDb.ROWS:
		if per_row[row] > BattleLimits.ROW_MAX:
			p._err("members", "%s 줄이 %d명을 넘는다" % [row, BattleLimits.ROW_MAX])
	return p


## 전투·성장 정의와 맞춰 본다(07 §7.8 「파티」): 직업이 있음, 레벨 1~level_cap, 시작 배분이 그 직업 트리·최대 레벨·선행·관문·SP 를
## 지킴, 시작 장비가 있고 장착 규칙(칸 종류·직업·같은 종류 제한)을 지킴. 판정은 GrowthRules 의 같은 함수(저장 검사와 같다).
func resolve(db: BattleDb) -> void:
	for i in ids.size():
		var path := "members[%d]" % i
		var c: BattleDb.ClassDef = db.classes.get(class_ids[i])
		if c == null:
			_err(path + ".class", "없는 직업 %s" % class_ids[i])
			continue
		if levels[i] > db.growth.level_cap:
			_err(path + ".level", "레벨 %d 이 level_cap %d 을 넘는다" % [levels[i], db.growth.level_cap])
			continue
		var bad := GrowthRules.skills_problem(db, c, levels[i], skills[i])
		if not bad.is_empty():
			_err("%s.skills%s" % [path, "" if bad[0].is_empty() else "." + bad[0]], bad[1])
		var unknown := false
		for j in equips[i].size():
			if not equips[i][j].is_empty() and db.equip(equips[i][j]) == null:
				_err("%s.equip[%d]" % [path, j], "없는 장비 %s" % equips[i][j])
				unknown = true
		if not unknown:
			bad = GrowthRules.equip_problem(db, c, equips[i])
			if not bad.is_empty():
				_err("%s.equip[%d]" % [path, bad[0]], bad[1])


func _err(path: String, msg: String) -> void:
	errors.append("%s: %s: %s" % [source, path, msg])
