## 정의 데이터 묶음(06 §8.2): 층·파티·전투 정의. 읽은 뒤 바뀌지 않는다.
## 읽기는 load_paths(파일) 또는 from_parts(이미 읽은 것, 시험용) 한 곳에서 파일 사이 참조까지 본다.
class_name GameDefs
extends RefCounted


class Result:
	extends RefCounted
	## 오류가 하나라도 있으면 null.
	var defs: GameDefs
	var errors: Array[String] = []
	## 실패가 아닌 분석 경고(쓰이지 않는 편성·적·스킬, 06 §5.6).
	var warnings: Array[String] = []

	func ok() -> bool:
		return errors.is_empty() and defs != null


var floor_def: FloorModel
var party: PartyData
var battle: BattleDb


## 층 파일·파티 파일·전투 정의 폴더(res://data)를 읽는다. text_db 가 있으면 name_key 가 거기 있는지 본다.
static func load_paths(floor_path: String, party_path: String, data_dir: String, text_db: TextDb) -> Result:
	var fr := FloorLoader.load_path(floor_path)
	var party := PartyData.read_path(party_path)
	var db := BattleDb.load_dir(data_dir)
	var r := from_parts(fr.floor_def, party, db, text_db)
	var errs: Array[String] = []
	errs.append_array(fr.errors)
	errs.append_array(r.errors)
	r.errors = errs
	if not r.errors.is_empty():
		r.defs = null
	return r


## 이미 읽은 조각을 묶고 참조를 본다. require_table 이 참이면(게임용) 층에 출현 표가 있어야 한다.
## party 는 이 함수가 resolve 한다(같은 PartyData 를 두 GameDefs 에 넘기지 않는다).
static func from_parts(floor_def: FloorModel, party: PartyData, db: BattleDb, text_db: TextDb = null, require_table: bool = true) -> Result:
	var r := Result.new()
	r.errors.append_array(db.errors)
	r.warnings.append_array(db.warnings)
	r.errors.append_array(party.errors)
	if floor_def == null:
		r.errors.append("층 정의가 없다")
	if db.ok() and party.errors.is_empty():
		party.resolve(db)
		r.errors.append_array(party.errors)
	if floor_def != null and db.ok():
		if floor_def.encounter_table.is_empty():
			if require_table:
				r.errors.append("%s: encounter.table: 층에 출현 표가 없다" % floor_def.id)
		elif not db.encounters.has(floor_def.encounter_table):
			r.errors.append("%s: encounter.table: 없는 출현 표 %s" % [floor_def.id, floor_def.encounter_table])
	if text_db != null and db.ok():
		var keys := db.name_keys()
		keys.append_array(party.name_keys)
		for k in keys:
			if not text_db.has(k):
				r.errors.append("ko.json: %s: 화면 문구가 없다" % k)
	if r.errors.is_empty():
		var d := GameDefs.new()
		d.floor_def = floor_def
		d.party = party
		d.battle = db
		r.defs = d
	return r


## 시작 파티 대원 목록(성장 값·시작 배분·시작 장비, 최대 HP·TP 는 성장 묶음, HP·TP 가득, 07 §8.1).
## 부를 때마다 새 Member 객체·새 사전·새 배열이다(정의·다른 상태와 공유하지 않는다).
func members() -> Array[PartyState.Member]:
	var out: Array[PartyState.Member] = []
	for i in party.ids.size():
		out.append(GrowthRules.start_member(self, i))
	return out


func class_of(member_index: int) -> BattleDb.ClassDef:
	return battle.classes[party.class_ids[member_index]]
