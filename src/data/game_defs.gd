## 정의 데이터 묶음(06 §8.2): 층 묶음(미궁 하나, M3 A1)·파티·전투 정의. 읽은 뒤 바뀌지 않는다.
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


## 층 ID → FloorModel, 그리고 깊이 차례(첫 층 = B1F). 지금 층은 ExplorationState.floor_def 다.
var floors := {}
var floor_ids: Array[String] = []
## 마을과 이어진 층 ID(M3 A2, 층 묶음의 "entrance"): 그 층의 시작 칸이 마을로 나가는 문이다. 없으면 ""(시험 묶음은 마을 문이 없다).
var entrance := ""
var party: PartyData
var battle: BattleDb
## 은퇴한 층 묶음(M3 A3, 층 묶음의 "retired"): 옛 저장이 가리키는 층(f1_test 등)을 읽어 새 미궁으로 옮길 때만 쓴다(SaveCodec). 없으면 null.
var retired: GameDefs


## 층 묶음 파일·파티 파일·전투 정의 폴더(res://data)를 읽는다. text_db 가 있으면 name_key 가 거기 있는지 본다.
static func load_paths(labyrinth_path: String, party_path: String, data_dir: String, text_db: TextDb) -> Result:
	var fr := FloorLoader.load_set(labyrinth_path)
	var party := PartyData.read_path(party_path)
	var db := BattleDb.load_dir(data_dir)
	var r := from_parts(fr.floors, party, db, text_db, true, fr.entrance)
	var errs: Array[String] = []
	errs.append_array(fr.errors)
	if fr.ok():
		errs.append_array(r.errors)
	else:
		errs.append_array(r.errors.filter(func(e: String) -> bool: return e != "층 정의가 없다"))
	r.errors = errs
	if not fr.retired.is_empty():
		var rr := _load_retired(fr.retired, party_path, db, text_db, fr.floors)
		r.errors.append_array(rr.errors)
		if r.defs != null and rr.ok():
			r.defs.retired = rr.defs
	if not r.errors.is_empty():
		r.defs = null
	return r


## 은퇴한 층 묶음을 읽는다(M3 A3): 같은 전투 정의·새로 읽은 파티로 묶고, 층 ID 가 지금 묶음과 겹치지 않고 그 묶음에 retired 가 없어야 한다.
static func _load_retired(path: String, party_path: String, db: BattleDb, text_db: TextDb, game_floors: Array[FloorModel]) -> Result:
	var fr := FloorLoader.load_set(path)
	var r := from_parts(fr.floors, PartyData.read_path(party_path), db, text_db, true, fr.entrance) if fr.ok() else Result.new()
	var errs: Array[String] = []
	errs.append_array(fr.errors)
	errs.append_array(r.errors)
	if not fr.retired.is_empty():
		errs.append("retired: 은퇴한 묶음 %s 에 retired 가 또 있다" % path.get_file())
	for f in fr.floors:
		if game_floors.any(func(g: FloorModel) -> bool: return g.id == f.id):
			errs.append("retired: 은퇴한 층 %s 가 지금 묶음에도 있다" % f.id)
	r.errors.assign(errs.map(func(e: String) -> String: return e if e.begins_with("retired: ") else "retired: " + e))
	if not r.errors.is_empty():
		r.defs = null
	return r


## 이미 읽은 조각을 묶고 참조를 본다. floors 는 깊이 차례의 층 묶음(층 사이 검사 check_set 도 여기서 한다).
## require_table 이 참이면(게임용) 층마다 출현 표가 있어야 한다. party 는 이 함수가 resolve 한다(같은 PartyData 를 두 GameDefs 에 넘기지 않는다).
## entrance(M3 A2)는 마을 문이 있는 층 ID 이고, 있으면 첫 층이어야 한다.
static func from_parts(floor_list: Array[FloorModel], party: PartyData, db: BattleDb, text_db: TextDb = null, require_table: bool = true,
		entrance: String = "") -> Result:
	var r := Result.new()
	r.errors.append_array(db.errors)
	r.warnings.append_array(db.warnings)
	r.errors.append_array(party.errors)
	if floor_list.is_empty():
		r.errors.append("층 정의가 없다")
	else:
		r.errors.append_array(FloorLoader.check_set(floor_list))
		if not entrance.is_empty() and entrance != floor_list[0].id:
			r.errors.append("entrance: 마을 문은 첫 층(%s)에 있어야 하는데 %s 다" % [floor_list[0].id, entrance])
	if db.ok() and party.errors.is_empty():
		party.resolve(db)
		r.errors.append_array(party.errors)
	if db.ok():
		for f in floor_list:
			if f.encounter_table.is_empty():
				if require_table:
					r.errors.append("%s: encounter.table: 층에 출현 표가 없다" % f.id)
			elif not db.encounters.has(f.encounter_table):
				r.errors.append("%s: encounter.table: 없는 출현 표 %s" % [f.id, f.encounter_table])
	if db.ok():
		r.errors.append_array(check_chests_and_locks(floor_list, db))
		r.errors.append_array(check_gathering(floor_list, db))
		r.errors.append_array(check_foes(floor_list, db))
	if text_db != null and db.ok():
		var keys := db.name_keys()
		keys.append_array(party.name_keys)
		for f in floor_list:
			keys.append(f.name_key)
		for k in keys:
			if not text_db.has(k):
				r.errors.append("ko.json: %s: 화면 문구가 없다" % k)
	if r.errors.is_empty():
		var d := GameDefs.new()
		for f in floor_list:
			d.floors[f.id] = f
			d.floor_ids.append(f.id)
		d.entrance = entrance
		d.party = party
		d.battle = db
		r.defs = d
	return r


## FOE 참조(M3 A6, 설계 §2.3): 층 FOE 의 정의가 있는지, 문지기가 진행(계단·열쇠 상자·잠긴 문)을 막지 않는지.
static func check_foes(floor_list: Array[FloorModel], db: BattleDb) -> Array[String]:
	var out: Array[String] = []
	for f in floor_list:
		for s in f.foe_list():
			if db.foe(s.foe) == null:
				out.append("%s: foes: FOE %s 의 정의 %s 가 없다" % [f.id, s.id, s.foe])
		out.append_array(FloorLoader.guard_progress(f, f.id))
	return out


## 채집 지점 참조(M3 A5): 지점의 표가 정의에 있고, 표의 종류가 지점 종류와 같은지.
static func check_gathering(floor_list: Array[FloorModel], db: BattleDb) -> Array[String]:
	var out: Array[String] = []
	for f in floor_list:
		for p in f.point_list():
			var g := db.gather_table(p.table)
			if g == null:
				out.append("%s: gathering: 지점 %s 의 표 %s 가 없다" % [f.id, p.id, p.table])
			elif g.kind != p.kind:
				out.append("%s: gathering: 지점 %s 의 종류 %s 와 표 %s 의 종류 %s 가 다르다" % [f.id, p.id, p.kind, p.table, g.kind])
	return out


## 상자·잠긴 문 참조(M3 A3): 상자의 물건이 있는 소재·장비·귀중품인지, 열쇠는 묶음 전체에서 한 상자에만 있는지,
## 열쇠 문의 열쇠가 귀중품이고 같은 층 상자에 있는지(층마다의 도달 분석이 실제와 같으려면 열쇠와 그 문이 한 층에 있어야 한다).
static func check_chests_and_locks(floor_list: Array[FloorModel], db: BattleDb) -> Array[String]:
	var out: Array[String] = []
	var key_home := {}  # 열쇠 ID → "층:상자"
	for f in floor_list:
		for c in f.chest_list():
			if c.item.is_empty():
				continue
			var known: bool
			if c.item.begins_with("key."):
				known = db.key_items.has(c.item)
			elif c.item.begins_with("equip."):
				known = db.equip(c.item) != null
			else:
				known = db.materials.has(c.item)
			if not known:
				out.append("%s: chests: 상자 %s 의 물건 %s 가 정의에 없다" % [f.id, c.id, c.item])
			elif c.item.begins_with("key."):
				if key_home.has(c.item):
					out.append("%s: chests: 열쇠 %s 가 상자 둘에 있다(%s, %s:%s)" % [f.id, c.item, key_home[c.item], f.id, c.id])
				else:
					key_home[c.item] = "%s:%s" % [f.id, c.id]
	for f in floor_list:
		for e in f.edges_of_kind(FloorModel.Edge.LOCK):
			var k := f.lock_key(e)
			if k.is_empty():
				continue
			if not db.key_items.has(k):
				out.append("%s: locks: 잠긴 문 %s 의 열쇠 %s 가 귀중품 정의에 없다" % [f.id, GridKey.edge(e), k])
			elif not f.chest_list().any(func(c: FloorModel.Chest) -> bool: return c.item == k):
				out.append("%s: locks: 잠긴 문 %s 의 열쇠 %s 가 같은 층 상자에 없다" % [f.id, GridKey.edge(e), k])
	return out


## 열쇠 k 가 든 상자의 [층, 상자](묶음 전체에서 하나). 없으면 [].
func key_chest(k: String) -> Array:
	for id in floor_ids:
		for c in floors[id].chest_list():
			if c.item == k:
				return [floors[id], c]
	return []


## 시험용: 검사 없이 묶는다(층 사이 검사·참조를 보지 않는다). 시험 정의(tests/fixtures.gd)만 쓴다.
static func assemble(floor_list: Array[FloorModel], party: PartyData, db: BattleDb) -> GameDefs:
	var d := GameDefs.new()
	for f in floor_list:
		d.floors[f.id] = f
		d.floor_ids.append(f.id)
	d.party = party
	d.battle = db
	return d


## 첫 층(B1F, 미궁 입구가 있는 층). 마을에서 들어오면 여기 시작 칸에 선다.
func first_floor() -> FloorModel:
	return floors[floor_ids[0]]


## 층 ID → FloorModel. 묶음에 없으면 null.
func floor_by_id(id: String) -> FloorModel:
	return floors.get(id)


## 층 f 의 칸 c 가 마을로 나가는 문인지(M3 A2): 묶음의 entrance 층의 시작 칸.
func is_gate(f: FloorModel, c: Vector2i) -> bool:
	return not entrance.is_empty() and f != null and f.id == entrance and f.has_start() and c == f.start_at


## 깊이(첫 층 1). 묶음에 없으면 0.
func depth_of(id: String) -> int:
	return floor_ids.find(id) + 1


## 시작 파티 대원 목록(성장 값·시작 배분·시작 장비, 최대 HP·TP 는 성장 묶음, HP·TP 가득, 07 §8.1).
## 부를 때마다 새 Member 객체·새 사전·새 배열이다(정의·다른 상태와 공유하지 않는다).
func members() -> Array[PartyState.Member]:
	var out: Array[PartyState.Member] = []
	for i in party.ids.size():
		out.append(GrowthRules.start_member(self, i))
	return out


func class_of(member_index: int) -> BattleDb.ClassDef:
	return battle.classes[party.class_ids[member_index]]
