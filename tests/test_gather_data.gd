## 채집 자료(M3 A5 설계 §2·§7.1): 층의 채집 지점(gathering) 형식, 채집 표(data/gathering) 형식, 지점·표 참조, 실제 자료(지점 여덟·표 여덟·
## 소재 열다섯과 설명 글·새 장비 넷), 고정 공략이 지점에 멈추지 않음. 시험마다 죽이는 변이(M-F…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const ROUTE_PATH := "res://data/floors/arbor_route.json"
const GT := "gathering/stratum1.json"

## 한 줄 다섯 칸: (0,0) 시작, (1,0) 바닥, (2,0) 얼음, (3,0) 피해 바닥, (4,0) 바닥.
const ROW := [
	"+-+-+-+-+-+",
	"|. . = ~ .|",
	"+-+-+-+-+-+",
]
const GOOD := {"id": "g1", "at": [1, 0], "kind": "take", "uses": 2, "table": "gather.b1f.take"}

## 실제 지점(설계 §2.3): 층 → [[id, 칸, 종류, 표]].
const POINTS := {
	"b1f": [["g1", Vector2i(8, 17), "take"], ["g2", Vector2i(16, 16), "chop"]],
	"b2f": [["g1", Vector2i(4, 10), "take"], ["g2", Vector2i(3, 6), "chop"], ["g3", Vector2i(14, 16), "mine"]],
	"b3f": [["g1", Vector2i(2, 7), "take"], ["g2", Vector2i(14, 16), "chop"], ["g3", Vector2i(14, 1), "mine"]],
}
const NEW_MATERIALS := ["item.neon_moss", "item.lumen_sap", "item.frost_lichen", "item.scrap_wire", "item.copper_coil", "item.ether_crystal", "item.data_core"]


func _expect_error(d: Dictionary, needle: String, label: String) -> void:
	var errs := Fx.parse(d).errors
	check(not errs.is_empty(), "%s: 오류가 나야 한다" % label)
	var re := RegEx.create_from_string("^fx\\.json:\\d+:\\d+: ")
	var found := false
	for e in errs:
		check(re.search(e) != null, "%s: 위치 없는 오류 %s" % [label, e])
		found = found or e.contains(needle)
	check(found, "%s: '%s' 를 담은 오류가 없다 %s" % [label, needle, str(errs)])


func _pt(over: Dictionary = {}) -> Dictionary:
	var p := GOOD.duplicate(true)
	p.merge(over, true)
	return p


func _floor(points: Variant, extra: Dictionary = {}, grid: Array = ROW) -> Dictionary:
	var d := {"gathering": points}
	d.merge(extra, true)
	return Fx.floor_dict(grid, d)


## F1 (M-F1a 얼음 칸 지점, M-F1b 상자 칸 지점, M-F1c 횟수 범위 없음, M-F1d 모르는 종류): 지점 형식.
func test_point_format_errors() -> void:
	var ok := Fx.parse(_floor([GOOD, _pt({"id": "g_2", "at": [4, 0], "kind": "mine", "uses": 9, "table": "gather.b2f.mine"})]))
	check(ok.ok(), "기본 지점 오류 %s" % str(ok.errors))
	if ok.ok():
		var p := ok.floor_def.point_at(Vector2i(1, 0))
		check(p != null and [p.id, p.kind, p.uses, p.table] == ["g1", "take", 2, "gather.b1f.take"], "지점 g1")
		check_eq(ok.floor_def.point_list().map(func(x: FloorModel.GatherPoint) -> String: return x.id), ["g1", "g_2"], "읽은 차례")
		check(ok.floor_def.point_at(Vector2i(0, 0)) == null, "지점 없는 칸은 null")
	_expect_error(_floor([_pt({"id": "G1"})]), "gathering[0].id 는", "id 꼴")
	_expect_error(_floor([GOOD, _pt({"at": [4, 0]})]), "id g1 가 중복", "id 중복")
	_expect_error(_floor([_pt({"x": 1})]), "gathering[0].x 는 모르는 필드다", "모르는 필드")
	var no_uses := _pt()
	no_uses.erase("uses")
	_expect_error(_floor([no_uses]), "gathering[0].uses 가 없다", "횟수 없음")
	_expect_error(_floor([_pt({"kind": "cut"})]), "gathering[0].kind 는", "모르는 종류")
	for n in [0, 10, 1.5, true, "2"]:
		_expect_error(_floor([_pt({"uses": n})]), "gathering[0].uses 는 1~9 정수", "횟수 %s" % str(n))
	for tb in ["encounter.b1f", "gather.", "gather.B1F", 3]:
		_expect_error(_floor([_pt({"table": tb})]), "table 은 gather. 로 시작하는", "표 %s" % str(tb))
	_expect_error(_floor([_pt({"at": [2, 0]})]), "바닥 칸(.)이 아니다", "얼음 칸")
	_expect_error(_floor([_pt({"at": [3, 0]})]), "바닥 칸(.)이 아니다", "피해 바닥 칸")
	_expect_error(_floor([_pt({"at": [0, 0]})]), "시작 칸이다", "시작 칸")
	_expect_error(_floor([_pt({"at": [4, 0]})], {"chests": [{"id": "c", "at": [4, 0], "money": 1}]}), "상자가 있다", "상자 칸")
	_expect_error(_floor([GOOD, _pt({"id": "g2"})]), "채집 지점이 이미 있다", "같은 칸 둘")
	_expect_error(_floor([GOOD], {"reserved": [[1, 0, 1, 0]]}), "채집 지점", "예약 구역이 지점을 담음")
	_expect_error(_floor(3), "gathering은 배열이어야 한다", "배열 아님")
	var st := {"stairs": [{"at": [1, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]}
	_expect_error(_floor([GOOD], st, ["+-+-+-+-+", "|. . . .|", "+-+-+-+-+"]), "계단이 있다", "계단 칸")


func _table(over: Dictionary = {}) -> Dictionary:
	var t := {"id": "gather.t1", "kind": "take", "items": [{"item": "item.neon_moss", "weight": 70, "count": [1, 2]}],
		"rare": {"item": "item.lumen_sap", "permille": 80}}
	t.merge(over, true)
	return t


func _db_errors(tables: Array) -> Array[String]:
	return Fx.battle_db(Fx.battle_files({"gathering/test.json": {"gather_tables": tables}})).errors


func _rejects(tables: Array, needle: String, label: String) -> void:
	var errs := _db_errors(tables)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


## F3 (M-F3a 장비 ID 를 받음, M-F3b lo > hi 를 받음, M-F3c 확률 0 을 받음): 채집 표 형식과 소재 참조.
func test_table_format_errors() -> void:
	check_eq(_db_errors([_table(), _table({"id": "gather.t2", "kind": "mine"})]), [] as Array[String], "기본 표 둘")
	var no_rare := _table({"id": "gather.t3"})
	no_rare.erase("rare")
	check_eq(_db_errors([_table(), no_rare]), [] as Array[String], "rare 는 선택")
	var db := Fx.battle_db(Fx.battle_files({"gathering/test.json": {"gather_tables": [_table()]}}))
	var g := db.gather_table("gather.t1")
	check(g != null and g.kind == "take" and g.items == [{"item": "item.neon_moss", "weight": 70, "lo": 1, "hi": 2}] and g.rare_item == "item.lumen_sap"
		and g.rare_permille == 80 and g.total_weight() == 70, "읽은 표")
	_rejects([_table({"items": [{"item": "equip.twin_edge", "weight": 1, "count": [1, 1]}]})], "item. 로 시작하는 ID", "장비 줄")
	_rejects([_table({"items": [{"item": "item.nothing", "weight": 1, "count": [1, 1]}]})], "없는 소재 item.nothing", "모르는 소재")
	_rejects([_table({"rare": {"item": "item.nothing", "permille": 5}})], "없는 소재 item.nothing", "모르는 희귀 소재")
	_rejects([_table({"items": [{"item": "item.neon_moss", "weight": 0, "count": [1, 1]}]})], "weight: 정수", "무게 0")
	for c in [[2, 1], [1, 6], [0, 1], [1], "1-2", [1.5, 2], [true, 2]]:
		_rejects([_table({"items": [{"item": "item.neon_moss", "weight": 1, "count": c}]})], "count: [lo, hi]", "개수 %s" % str(c))
	for pm in [0, 1001, 0.5]:
		_rejects([_table({"rare": {"item": "item.lumen_sap", "permille": pm}})], "permille: 정수", "희귀 확률 %s" % str(pm))
	_rejects([_table({"items": []})], "줄이 1~8 개인 배열", "빈 줄")
	var many := []
	for i in 9:
		many.append({"item": "item.neon_moss", "weight": 1, "count": [1, 1]})
	_rejects([_table({"items": many})], "줄이 1~8 개인 배열", "줄 아홉")
	_rejects([_table({"kind": "dig"})], "kind: 다음 중 하나", "모르는 종류")
	_rejects([_table({"id": "encounter.t1"})], "gather. 로 시작하는 ID", "ID 앞부분")
	_rejects([_table({"x": 1})], "x: 모르는 필드", "모르는 필드")
	_rejects([_table(), _table()], "ID gather.t1 가 중복", "ID 중복")
	_rejects([_table({"items": [{"item": "item.neon_moss", "weight": 1, "count": [1, 1], "w": 2}]})], "w: 모르는 필드", "줄의 모르는 필드")


## F2 (M-F2a 표 종류 검사 없음, M-F2b 없는 표를 받음): 지점 → 표 참조(GameDefs.check_gathering).
func test_point_table_references() -> void:
	var db := Fx.defs().battle
	var f := Fx.parse(_floor([GOOD, _pt({"id": "g2", "at": [4, 0], "table": "gather.b1f.chop"})])).floor_def
	check_eq(GameDefs.check_gathering([f] as Array[FloorModel], db), ["fx: gathering: 지점 g2 의 종류 take 와 표 gather.b1f.chop 의 종류 chop 가 다르다"], "종류가 다른 표")
	var f2 := Fx.parse(_floor([_pt({"table": "gather.nowhere"})])).floor_def
	check_eq(GameDefs.check_gathering([f2] as Array[FloorModel], db), ["fx: gathering: 지점 g1 의 표 gather.nowhere 가 없다"], "없는 표")
	var f3 := Fx.parse(_floor([GOOD])).floor_def
	check_eq(GameDefs.check_gathering([f3] as Array[FloorModel], db), [] as Array[String], "맞는 표")
	# from_parts 가 부른다(게임 정의를 읽을 때 걸린다).
	var r := GameDefs.from_parts([f2] as Array[FloorModel], PartyData.read_path(Fx.PARTY_PATH), db, null, false)
	check(not r.ok() and r.errors.has("fx: gathering: 지점 g1 의 표 gather.nowhere 가 없다"), "from_parts 오류 %s" % str(r.errors))


## F4 (M-F4 B1F g1 을 공략이 멈추는 (9,17)로 옮김): 실제 층의 지점·표·분석, 고정 공략은 지점 칸에 멈추지 않는다(웹 D·공략 시험이 그대로).
func test_real_points_and_route() -> void:
	var defs := Fx.arbor()
	check(defs != null, "arbor 정의")
	if defs == null:
		return
	for fid in POINTS:
		var f := defs.floor_by_id(fid)
		var got: Array = f.point_list().map(func(p: FloorModel.GatherPoint) -> Array: return [p.id, p.at, p.kind])
		check_eq(got, POINTS[fid], "%s 지점" % fid)
		for p in f.point_list():
			check_eq([p.uses, p.table], [2, "gather.%s.%s" % [fid, p.kind]], "%s %s: 하루 2번·표" % [fid, p.id])
			check(defs.battle.gather_table(p.table) != null and defs.battle.gather_table(p.table).kind == p.kind, "%s %s: 표가 있고 종류가 같다" % [fid, p.id])
		check_eq(FloorLoader.analyze(f, fid), [] as Array[String], "%s 분석 경고 0" % fid)
	check_eq(defs.battle.gather_table_ids.size(), 8, "표 여덟")
	# 고정 공략이 멈추는 칸(이동이 끝난 칸)에 지점이 없다: 공략 중 gather·gather_spent 이벤트가 하나도 없다.
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	var s := ExplorationRules.new_game(defs, 31, "full")
	var stops := {}
	var hits: Array = []
	for a in route["actions"]:
		var ev := ExplorationRules.apply(s, ExplorationRules.action_from_name(a), "full")
		if ev.any(func(e: Dictionary) -> bool: return e["type"] == "moved"):
			stops["%s:%d:%d" % [s.floor_def.id, s.party.at.x, s.party.at.y]] = true
		for e in ev:
			if e["type"] in ["gather", "gather_spent"]:
				hits.append([s.floor_def.id, s.party.at])
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
	check_eq(hits, [], "공략 중 채집 이벤트 없음")
	for fid in POINTS:
		for p in POINTS[fid]:
			check(not stops.has("%s:%d:%d" % [fid, p[1].x, p[1].y]), "%s %s 는 공략이 멈추는 칸이 아니다" % [fid, p[0]])
	check(stops.size() > 100, "공략이 멈춘 칸 %d" % stops.size())


## F5 (M-F5 소재 설명 글을 선택으로 두고 하나 뺌): 소재 열다섯, 모두 설명 글이 ko.json 에 있다. 새 소재마다 얻는 곳(표)과 쓰는 곳(상점 풀림)이 있다.
func test_real_materials_and_unlocks() -> void:
	var defs := Fx.arbor()
	if defs == null:
		check(false, "arbor 정의")
		return
	var db := defs.battle
	var texts := TextDb.load_path("res://data/text/ko.json")
	check_eq(db.material_ids.size(), 20, "소재 스물(D29 ②, M3 A6 FOE 소재 셋, M3 A9 보스 소재 둘)")
	for id in db.material_ids:
		check_eq(db.material_desc.get(id), id + ".desc", "%s 설명 키" % id)
		check(texts.has(id + ".desc") and texts.has(db.materials[id]), "%s 이름·설명 문구" % id)
		check(db.name_keys().has(id + ".desc"), "%s 설명도 문구 검사에 들어간다" % id)
	var sources := {}
	for gid in db.gather_table_ids:
		var g := db.gather_table(gid)
		for x in g.items:
			sources[x["item"]] = true
		sources[g.rare_item] = true
	var unlocks := {}
	for line in db.shop("shop.junk_workshop").stock:
		for m in line["unlock"]:
			unlocks[m] = true
	for id in NEW_MATERIALS:
		check(db.materials.has(id), "%s 정의" % id)
		check(sources.has(id), "%s 는 채집 표에서 나온다" % id)
		check(unlocks.has(id), "%s 는 상점 풀림 줄에 쓰인다" % id)
	var bad := Fx.battle_files()
	bad["items/materials.json"]["materials"][0].erase("desc_key")
	var errs := Fx.battle_db(bad).errors
	check(errs.any(func(e: String) -> bool: return e.contains("materials[0].desc_key: 필수 필드가 없다")), "설명 글 없는 소재는 오류 %s" % str(errs))
	# 새 장비 넷(설계 §2.7)과 숫자.
	var cb := db.equip("equip.coil_blade")
	check(cb != null and [cb.kind, cb.element, cb.gear["atk"], cb.price] == ["sword", "volt", 18, 300], "코일 블레이드")
	var lc := db.equip("equip.lichen_charm")
	check(lc != null and lc.kind == "accessory" and lc.resist.get("ice") == -300 and lc.gear["mdef"] == 2, "서리 지의 부적")
	var el := db.equip("equip.ether_lens")
	check(el != null and el.kind == "head" and el.stats.get("INT") == 2, "에테르 렌즈")
	var mw := db.equip("equip.moss_weave")
	check(mw != null and mw.kind == "body" and [mw.gear["def"], mw.gear["mdef"]] == [6, 4], "이끼 짜임 외투")
	# 적 드롭은 그대로다(시뮬레이션 결과 해시를 지킨다): 드롭 소재는 앞 여덟뿐. FOE 셋(M3 A6, enemy.foe_*)은 시뮬레이션이 만나지 않고
	# 조건 드롭으로 채집 소재를 주므로 뺀다. 본 적은 일반 적 여덟이다(M3 A3c: 수액 반딧불·명멸 도깨비불은 앞 여덟 소재 중 발광 인분만 떨어뜨린다).
	var normal := 0
	for eid in db.enemy_ids:
		if eid.begins_with("enemy.foe_") or eid.begins_with("enemy.boss_"):
			continue  # M3 A9: 보스 적(enemy.boss_*)도 일반 적이 아니다(자기 소재를 떨어뜨린다)
		normal += 1
		for d in db.enemies[eid].drops:
			check(not NEW_MATERIALS.has(d["item"]), "%s 드롭에 새 소재가 없다" % eid)
	check_eq(normal, 8, "드롭을 본 일반 적 여덟")
