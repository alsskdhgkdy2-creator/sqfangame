## 층 형식 M3 A3: 잠긴 문(K·locks)·보물상자(chests)·예약 구역(reserved)·모르는 맨 위 키, 상자·열쇠 참조, 열쇠·잠긴 문 도달 분석,
## 실제 미궁 묶음(arbor: b1f·b2f·b3f)과 은퇴한 묶음(retired). 시험마다 죽이는 변이(설계 노트 §8.1, M-F…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const SET_DIR := "user://test_floor_sets_a3"

## 한 줄 네 칸: (0,0) 시작, (2,0)|K|(3,0) 잠긴 문(v:3:0).
const ROW := [
	"+-+-+-+-+",
	"|. . .K.|",
	"+-+-+-+-+",
]


func _expect_error(d: Dictionary, needle: String, label: String) -> void:
	var errs := Fx.parse(d).errors
	check(not errs.is_empty(), "%s: 오류가 나야 한다" % label)
	var re := RegEx.create_from_string("^fx\\.json:\\d+:\\d+: ")
	var found := false
	for e in errs:
		check(re.search(e) != null, "%s: 위치 없는 오류 %s" % [label, e])
		found = found or e.contains(needle)
	check(found, "%s: '%s' 를 담은 오류가 없다 %s" % [label, needle, str(errs)])


func _lock(extra: Dictionary = {}) -> Dictionary:
	var d := {"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}],
		"chests": [{"id": "k", "at": [1, 0], "item": "key.moss_card"}]}
	d.merge(extra, true)
	return Fx.floor_dict(ROW, d)


## F1 (M-F1a K 에 locks 항목 없이 받음, M-F1b key·seal 둘 다/없음 받음): 잠긴 문 형식.
func test_lock_format_errors() -> void:
	var good := Fx.parse(_lock())
	check(good.ok(), "기본 잠긴 문 오류 %s" % str(good.errors))
	if good.ok():
		var e := Vector3i(3, 0, 1)
		check_eq([good.floor_def.edge_kind(e), good.floor_def.lock_key(e), good.floor_def.is_sealed(e)], [FloorModel.Edge.LOCK, "key.moss_card", false], "K 경계·열쇠")
	_expect_error(_lock({"locks": []}), "잠긴 문 K 에 맞는 locks 항목이 없다", "항목 없는 K")
	_expect_error(_lock({"locks": [{"at": [1, 0], "dir": "E", "key": "key.moss_card"}]}), "가 격자의 K 가 아니다", "K 가 아닌 경계")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}, {"at": [3, 0], "dir": "W", "key": "key.moss_card"}]}),
		"중복", "같은 경계 둘")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card", "seal": "boss"}]}), "key 와 seal 가운데 하나만", "key·seal 둘 다")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E"}]}), "key 와 seal 가운데 하나만", "key·seal 없음")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E", "key": "item.neon_rat_tail"}]}), "key. 로 시작하는 ID", "열쇠 ID 앞부분")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E", "seal": ""}]}), "seal 은 빈 문자열이 아닌", "빈 봉인")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "X", "key": "key.moss_card"}]}), "dir 는 N·E·S·W", "방향")
	_expect_error(_lock({"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card", "x": 1}]}), "locks[0].x 는 모르는 필드다", "모르는 필드")
	_expect_error(_lock({"locks": 3}), "locks는 배열이어야 한다", "배열 아님")
	var sealed := Fx.parse(_lock({"locks": [{"at": [3, 0], "dir": "W", "seal": "boss"}], "chests": []}))
	check(sealed.ok() and sealed.floor_def.is_sealed(Vector3i(3, 0, 1)) and sealed.floor_def.seal_of(Vector3i(3, 0, 1)) == "boss"
		and sealed.floor_def.lock_key(Vector3i(3, 0, 1)) == "", "봉인 문(반대쪽 칸에서 가리켜도 된다) %s" % str(sealed.errors))


func _chest(list: Array, grid: Array = ["+-+-+-+-+", "|. . = .|", "+-+-+-+-+"], extra: Dictionary = {}) -> Dictionary:
	var d := {"chests": list}
	d.merge(extra, true)
	return Fx.floor_dict(grid, d)


## F2 (M-F2a 얼음 칸 상자, M-F2b 계단 칸 상자, M-F2c 열쇠 count 검사 없음): 상자 형식.
func test_chest_format_errors() -> void:
	var ok := Fx.parse(_chest([{"id": "a", "at": [1, 0], "item": "item.neon_rat_tail", "count": 3}, {"id": "b_2", "at": [3, 0], "money": 99999}]))
	check(ok.ok(), "기본 상자 오류 %s" % str(ok.errors))
	if ok.ok():
		var a := ok.floor_def.chest_at(Vector2i(1, 0))
		check(a != null and a.id == "a" and a.item == "item.neon_rat_tail" and a.count == 3 and a.money == 0, "상자 a")
		var b: FloorModel.Chest = ok.floor_def.chests["b_2"]
		check(b.at == Vector2i(3, 0) and b.item == "" and b.money == 99999, "상자 b_2(돈)")
		check_eq(ok.floor_def.chest_list().map(func(c: FloorModel.Chest) -> String: return c.id), ["a", "b_2"], "읽은 차례")
	var one := Fx.parse(_chest([{"id": "a", "at": [1, 0], "item": "equip.visor"}]))
	check(one.ok() and one.floor_def.chests["a"].count == 1, "count 기본 1")
	_expect_error(_chest([{"id": "A", "at": [1, 0], "money": 1}]), "id 는", "id 꼴")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 1}, {"id": "a", "at": [3, 0], "money": 1}]), "id a 가 중복", "id 중복")
	_expect_error(_chest([{"id": "a", "at": [2, 0], "money": 1}]), "바닥 칸(.)이 아니다", "얼음 칸")
	_expect_error(_chest([{"id": "a", "at": [0, 0], "money": 1}]), "시작 칸이다", "시작 칸")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 1}, {"id": "b", "at": [1, 0], "money": 1}]), "상자가 이미 있다", "같은 칸 둘")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 1, "item": "item.neon_rat_tail"}]), "item 과 money 가운데 하나만", "item·money 둘 다")
	_expect_error(_chest([{"id": "a", "at": [1, 0]}]), "item 과 money 가운데 하나만", "내용 없음")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "item": "skill.x"}]), "item.·equip.·key. 로 시작하는", "물건 앞부분")
	for n in [0, 100, 2.5, true, "3"]:
		_expect_error(_chest([{"id": "a", "at": [1, 0], "item": "item.neon_rat_tail", "count": n}]), "count 는 1~99", "count %s" % str(n))
	for m in [0, 100000, 1.5, false]:
		_expect_error(_chest([{"id": "a", "at": [1, 0], "money": m}]), "money 는 1~99999", "money %s" % str(m))
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 5, "count": 2}]), "money 상자에는 count 가 없다", "돈 상자 count")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "item": "key.moss_card", "count": 2}]), "열쇠는 한 개", "열쇠 count")
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 5, "lid": 1}]), "chests[0].lid 는 모르는 필드다", "모르는 필드")
	# 계단 칸(계단은 내려설 칸 (3,0) 쪽 W).
	var st := {"stairs": [{"at": [1, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]}
	_expect_error(_chest([{"id": "a", "at": [1, 0], "money": 1}], ["+-+-+-+-+", "|. . . .|", "+-+-+-+-+"], st), "계단이 있다", "계단 칸")


## 모르는 맨 위 키는 오류(오타로 상자가 소리 없이 빠지지 않게). 지금 층 파일·시험 층은 모두 아는 키만 쓴다.
func test_unknown_top_level_key_is_error() -> void:
	_expect_error(Fx.floor_dict(ROW, {"chest": [], "locks": [{"at": [2, 0], "dir": "E", "seal": "x"}]}), "chest 는 모르는 키다", "chest 오타")
	for p in ["res://data/floors/f1_test.json", "res://data/floors/f2_test.json", "res://data/floors/b1f.json", "res://data/floors/b2f.json",
			"res://data/floors/b3f.json"]:
		check_eq(FloorLoader.load_path(p).errors, [] as Array[String], "%s 오류 없음" % p.get_file())


## F4 (M-F4 예약 칸에도 「닿을 수 없다」): 예약 구역 형식과 분석.
func test_reserved_area() -> void:
	var g := [
		"+-+-+-+-+",
		"|. . .K.|",
		"+-+-+-+-+",
	]
	var base := {"locks": [{"at": [2, 0], "dir": "E", "seal": "boss"}]}
	var r := Fx.parse(Fx.floor_dict(g, base.merged({"reserved": [[3, 0, 3, 0]]})))
	check(r.ok() and r.floor_def.is_reserved(Vector2i(3, 0)) and not r.floor_def.is_reserved(Vector2i(2, 0)), "예약 구역 %s" % str(r.errors))
	if r.ok():
		check_eq(FloorLoader.analyze(r.floor_def, "fx.json"), [] as Array[String], "봉인 너머 예약 칸은 경고 없음")
	var plain := Fx.parse(Fx.floor_dict(g, base))
	check(plain.ok() and FloorLoader.analyze(plain.floor_def, "fx.json").any(func(s: String) -> bool: return s.contains("칸 3:0 에") and s.contains("닿을 수 없다")),
		"예약하지 않으면 닿을 수 없다")
	var leak := Fx.parse(Fx.floor_dict(g, base.merged({"reserved": [[1, 0, 1, 0], [3, 0, 3, 0]]})))
	check(leak.ok() and FloorLoader.analyze(leak.floor_def, "fx.json").any(func(s: String) -> bool: return s.contains("예약 칸 1:0 에 닿는다")),
		"닿는 예약 칸은 경고")
	_expect_error(Fx.floor_dict(g, base.merged({"reserved": [[0, 0, 1, 0]]})), "시작 칸", "시작 칸을 담음")
	_expect_error(Fx.floor_dict(g, base.merged({"reserved": [[1, 0, 1, 0]], "chests": [{"id": "a", "at": [1, 0], "money": 1}]})), "상자", "상자를 담음")
	_expect_error(Fx.floor_dict(g, base.merged({"reserved": [[3, 0, 2, 0]]})), "벗어나거나 뒤집혔다", "뒤집힘")
	_expect_error(Fx.floor_dict(g, base.merged({"reserved": [[0, 0, 4, 0]]})), "벗어나거나 뒤집혔다", "층 밖")


func _db() -> BattleDb:
	return Fx.defs().battle


func _floor(grid: Array, extra: Dictionary, id: String = "fx") -> FloorModel:
	var d := Fx.floor_dict(grid, extra)
	d["id"] = id
	var r := Fx.parse(d)
	check(r.ok(), "준비 층 %s 오류 %s" % [id, str(r.errors)])
	return r.floor_def


## F3 (M-F3a 같은 층 검사 없음, M-F3b 열쇠 하나 검사 없음): 상자 물건·열쇠·잠긴 문 참조.
func test_chest_and_lock_references() -> void:
	var g := ["+-+-+-+-+", "|. . .K.|", "+-+-+-+-+"]
	var row := ["+-+-+-+", "|. . .|", "+-+-+-+"]
	var ok := _floor(g, {"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}], "chests": [{"id": "k", "at": [1, 0], "item": "key.moss_card"},
		{"id": "m", "at": [3, 0], "item": "item.glow_scale", "count": 2}]})
	var list: Array[FloorModel] = [ok]
	check_eq(GameDefs.check_chests_and_locks(list, _db()), [] as Array[String], "맞는 참조")
	for x in [["item.nope", "물건 item.nope 가 정의에 없다"], ["equip.nope", "물건 equip.nope 가 정의에 없다"], ["key.nope", "물건 key.nope 가 정의에 없다"]]:
		var f := _floor(row, {"chests": [{"id": "a", "at": [1, 0], "item": x[0]}]})
		var errs := GameDefs.check_chests_and_locks([f] as Array[FloorModel], _db())
		check(errs.any(func(e: String) -> bool: return e.contains(x[1])), "%s %s" % [x[0], str(errs)])
	# 잠긴 문의 열쇠가 귀중품이 아니다.
	var bad_key := _floor(g, {"locks": [{"at": [2, 0], "dir": "E", "key": "key.nope"}]})
	check(GameDefs.check_chests_and_locks([bad_key] as Array[FloorModel], _db()).any(func(e: String) -> bool: return e.contains("귀중품 정의에 없다")),
		"모르는 열쇠")
	# 열쇠가 다른 층 상자에 있다(같은 층에 없다).
	var lock_only := _floor(g, {"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}]}, "fa")
	var key_only := _floor(row, {"chests": [{"id": "k", "at": [1, 0], "item": "key.moss_card"}]}, "fb")
	var errs2 := GameDefs.check_chests_and_locks([lock_only, key_only] as Array[FloorModel], _db())
	check(errs2.any(func(e: String) -> bool: return e.contains("fa: locks:") and e.contains("같은 층 상자에 없다")), "다른 층 열쇠 %s" % str(errs2))
	# 열쇠가 상자 둘에 있다(다른 층이어도).
	var two := _floor(row, {"chests": [{"id": "k2", "at": [2, 0], "item": "key.moss_card"}]}, "fc")
	var errs3 := GameDefs.check_chests_and_locks([ok, two] as Array[FloorModel], _db())
	check(errs3.any(func(e: String) -> bool: return e.contains("열쇠 key.moss_card 가 상자 둘에 있다")), "열쇠 둘 %s" % str(errs3))


func _warn(grid: Array, extra: Dictionary) -> Array[String]:
	var f := _floor(grid, extra)
	return FloorLoader.analyze(f, "fx.json") if f != null else ["읽기 오류"] as Array[String]


## F5 (M-F5a 열쇠 비트 없이 잠긴 문 지나감, M-F5b 열쇠 없이 문 열기, M-F5c 열쇠 비트가 상자 칸 밖에서 켜짐): 열쇠·잠긴 문 분석.
func test_lock_key_analysis() -> void:
	var key := {"id": "k", "item": "key.moss_card"}
	# (a) 열쇠가 자기 문 뒤에 있다: 문 너머 두 칸 닿을 수 없음.
	var wa := _warn(["+-+-+-+-+", "|. .K. .|", "+-+-+-+-+"], {"locks": [{"at": [1, 0], "dir": "E", "key": "key.moss_card"}],
		"chests": [key.merged({"at": [3, 0]})]})
	check(wa.any(func(s: String) -> bool: return s.contains("칸 2:0") and s.contains("닿을 수 없다"))
		and wa.any(func(s: String) -> bool: return s.contains("칸 3:0") and s.contains("닿을 수 없다")), "(a) 열쇠가 문 뒤 %s" % str(wa))
	# (b) 일방통행 방, 나가는 길은 열쇠 문뿐인데 열쇠는 밖: 열쇠 없이 들어가면 갇힘.
	var gb := ["+-+-+-+-+", "|. .>.K.|", "+ +-+-+ +", "|. . . .|", "+-+-+-+-+"]
	var lock_b := [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}]
	var wb := _warn(gb, {"locks": lock_b, "chests": [key.merged({"at": [1, 0]})]})
	check(wb.any(func(s: String) -> bool: return s.contains("칸 2:0") and s.contains("갇힘") and not s.contains("가진 열쇠")), "(b) 열쇠 없이 들어간 방 갇힘 %s" % str(wb))
	check(not wb.any(func(s: String) -> bool: return s.contains("가진 열쇠 key.moss_card")), "(b) 열쇠를 가졌으면 갇힘 아님 %s" % str(wb))
	var fb := _floor(gb, {"locks": lock_b, "chests": [key.merged({"at": [1, 0]})]})
	check_eq(FloorLoader.can_return(fb, Vector2i(2, 0), WorldState.new()), FloorLoader.Reach.NO, "(b) can_return 열쇠 없음")
	check_eq(FloorLoader.can_return(fb, Vector2i(2, 0), WorldState.new(), FloorLoader.MAX_ANALYSIS_NODES, {"key.moss_card": true}), FloorLoader.Reach.YES, "(b) can_return 열쇠 있음")
	var opened := WorldState.new()
	opened.open_lock(Vector3i(3, 0, 1))
	check_eq(FloorLoader.can_return(fb, Vector2i(2, 0), opened), FloorLoader.Reach.YES, "(b) can_return 문이 열려 있음")
	# (c) 내려가는 계단 구역이 잠긴 문 뒤이고 열쇠 없이 돌아갈 길이 없다: 계단으로 들어온(상태 0) 칸이 갇힘.
	var st := {"at": [3, 1], "way": "down", "exit": "N", "to": {"floor": "fy", "at": [0, 0]}}
	var wc := _warn(["+-+-+-+-+", "|. . .K.|", "+-+-+-+ +", "|#|#|#|.|", "+-+-+-+-+"],
		{"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}], "chests": [key.merged({"at": [1, 0]})], "stairs": [st]})
	check(wc.any(func(s: String) -> bool: return s.contains("칸 3:1") and s.contains("갇힘") and s.contains("바뀐 경계 없음")), "(c) 계단 칸 갇힘 %s" % str(wc))
	# (d) 같은 층에 계단 쪽에서 여는 지름길이 있으면 경고 없음.
	var wd := _warn(["+-+-+-+-+", "|. . .K.|", "+ +-+-+ +", "|. . .L.|", "+-+-+-+-+"],
		{"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card"}], "chests": [key.merged({"at": [1, 0]})], "stairs": [st],
		"shortcuts": [{"at": [3, 1], "dir": "W"}]})
	check_eq(wd, [] as Array[String], "(d) 계단 쪽 지름길")
	# (e) 얼음에서 잠긴 문에 막혀 멈춘 칸: 거짓 갇힘 없음.
	var we := _warn(["+-+-+-+-+", "|. =K. .|", "+ +-+-+ +", "|. . . .|", "+-+-+-+-+"],
		{"locks": [{"at": [1, 0], "dir": "E", "key": "key.moss_card"}], "chests": [key.merged({"at": [2, 1]})]})
	check_eq(we, [] as Array[String], "(e) 얼음 앞 잠긴 문")
	# 봉인 문은 비트가 아니다(열쇠 상자가 없어도 분석 비트 0).
	var sealed := _floor(["+-+-+-+", "|. .K.|", "+-+-+-+"], {"locks": [{"at": [1, 0], "dir": "E", "seal": "boss"}], "reserved": [[2, 0, 2, 0]]})
	check_eq(FloorLoader._world_bits(sealed), [], "봉인 문은 세계 상태 비트가 아니다")


## F6 (M-F6 B2F 돌아가는 지름길을 빼면 갇힘): 실제 세 층이 깨끗이 읽히고 분석 경고 0, 노드 1만 아래, 잠긴 문·봉인·상자가 제자리.
func test_real_floors() -> void:
	var r := GameDefs.load_paths(Fx.ARBOR_PATH, Fx.PARTY_PATH, "res://data", TextDb.load_path("res://data/text/ko.json"))
	check_eq(r.errors, [] as Array[String], "arbor 오류 없음")
	if not r.ok():
		return
	var d := r.defs
	check_eq([d.floor_ids, d.entrance], [["b1f", "b2f", "b3f"] as Array[String], "b1f"], "세 층·입구")
	for id in d.floor_ids:
		var f: FloorModel = d.floors[id]
		check_eq(FloorLoader.analyze(f, id), [] as Array[String], "%s 분석 경고 0" % id)
		var g := FloorLoader._explore(f, FloorLoader.entries(f), 0, FloorLoader._world_bits(f), FloorLoader.MAX_ANALYSIS_NODES, {})
		check(g["complete"] and g["next"].size() < 10000, "%s 분석 노드 %d < 10000" % [id, g["next"].size()])
		check_eq([f.width, f.height, f.name_key, f.encounter_table], [20, 20, "floor.stratum1", "encounter." + id], "%s 크기·이름·출현 표" % id)
	var b1: FloorModel = d.floors["b1f"]
	check(b1.edges_of_kind(FloorModel.Edge.LOCK).is_empty() and b1.edges_of_kind(FloorModel.Edge.SHORTCUT).size() == 1
		and b1.edges_of_kind(FloorModel.Edge.PASSAGE).size() == 1 and b1.edges_of_kind(FloorModel.Edge.DOOR).size() >= 2, "B1F: 문·숨은 통로·지름길, 잠긴 문 없음")
	var b2: FloorModel = d.floors["b2f"]
	check_eq(b2.lock_key(Vector3i(16, 4, 0)), "key.moss_card", "B2F 잠긴 문 h:16:4")
	check(b2.edges_of_kind(FloorModel.Edge.ONEWAY).size() >= 3, "B2F 일방통행 주제")
	var b3: FloorModel = d.floors["b3f"]
	check_eq([b3.lock_key(Vector3i(12, 3, 0)), b3.is_sealed(Vector3i(9, 2, 1)), b3.seal_of(Vector3i(9, 2, 1))], ["key.relay_fuse", true, "boss"], "B3F 관문·봉인")
	# M3 A9: 예약 구역이던 보스 방 x3~8·y1~3 이 실제 칸이 되었다(05 §16.7 → §22). 봉인은 permit.boss 로 열리고, 방은 비콘이 닿지 않으며,
	# 봉인 뒤 칸(behind_seal)은 정확히 그 18칸이다.
	check(not b3.is_reserved(Vector2i(3, 1)) and not b3.is_reserved(Vector2i(8, 3)) and b3.reserved.is_empty(), "B3F 보스 방은 더 예약 칸이 아니다(M3 A9)")
	check_eq(b3.seal_needs(Vector3i(9, 2, 1)), "permit.boss", "B3F 봉인 needs")
	var room := {}
	for y in range(1, 4):
		for x in range(3, 9):
			room[Vector2i(x, y)] = true
	check_eq(b3.no_return, room, "B3F 비콘이 닿지 않는 칸 = 보스 방 18칸")
	check_eq(b3.behind_seal.keys(), [Vector3i(9, 2, 1)], "B3F 봉인 하나")
	check_eq(b3.behind_seal.get(Vector3i(9, 2, 1), {}), room, "B3F 봉인 뒤 칸 = 보스 방 18칸")
	check_eq(FloorLoader._world_bits(b3).size(), 4, "B3F 세계 비트 넷(지름길·관문·봉인·열쇠)")
	check(b3.cells().filter(func(c: Vector2i) -> bool: return b3.cell_kind(c) == FloorModel.Cell.ICE).size() >= 40, "B3F 미끄러운 바닥 주제")
	check_eq(GameDefs.check_chests_and_locks([b1, b2, b3] as Array[FloorModel], d.battle), [] as Array[String], "상자·열쇠 참조")
	check_eq([d.key_chest("key.moss_card")[0].id, d.key_chest("key.relay_fuse")[0].id], ["b2f", "b3f"], "열쇠가 든 층")
	# M-F6: B2F 의 계단 방 지름길(v:13:13)을 벽으로 바꾸면 B3F 에서 올라온 칸이 갇힌다.
	var text := FileAccess.get_file_as_string("res://data/floors/b2f.json")
	var j: Dictionary = JSON.parse_string(text)
	var grid: Array = j["grid"]
	var row: String = grid[27]
	check_eq(row[26], "L", "준비: v:13:13 은 L")
	grid[27] = row.substr(0, 26) + "|" + row.substr(27)
	j.erase("shortcuts")
	var cut := FloorLoader.parse_text(JSON.stringify(j, "\t"), "b2f.json")
	check(cut.ok() and FloorLoader.analyze(cut.floor_def, "b2f.json").any(func(s: String) -> bool: return s.contains("칸 17:17") and s.contains("갇힘")),
		"지름길이 없으면 계단 칸 갇힘")


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean_set_dir() -> void:
	var d := DirAccess.open(SET_DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(SET_DIR)


func _set_dir_with(sets: Dictionary) -> void:
	_clean_set_dir()
	DirAccess.make_dir_recursive_absolute(SET_DIR)
	for id in ["f1_test", "f2_test", "b1f", "b2f", "b3f"]:
		_write(SET_DIR + "/%s.json" % id, FileAccess.get_file_as_string("res://data/floors/%s.json" % id))
	for name in sets:
		_write(SET_DIR + "/" + name, JSON.stringify(sets[name]))


func _load(name: String) -> GameDefs.Result:
	return GameDefs.load_paths(SET_DIR + "/" + name, Fx.PARTY_PATH, "res://data", TextDb.load_path("res://data/text/ko.json"))


## F7 (M-F7 은퇴한 층 ID 겹침 검사 없음): 은퇴한 묶음 키.
func test_retired_set() -> void:
	# M3 A8a: 실제 arbor.json 처럼 의뢰 파일을 가리킨다(B1F 내려가는 계단의 needs permit.b2f 를 주는 의뢰가 있어야 묶음이 읽힌다).
	var game := {"id": "labyrinth.arbor", "floors": ["b1f", "b2f", "b3f"], "entrance": "b1f", "retired": "test.json", "quests": "res://data/quests/stratum1.json"}
	var test_set := {"id": "labyrinth.test", "floors": ["f1_test", "f2_test"], "entrance": "f1_test"}
	_set_dir_with({"arbor.json": game, "test.json": test_set})
	var ok := _load("arbor.json")
	check(ok.ok(), "은퇴한 묶음 %s" % str(ok.errors))
	if ok.ok():
		check(ok.defs.retired != null and ok.defs.retired.floor_ids == (["f1_test", "f2_test"] as Array[String]) and ok.defs.retired.retired == null,
			"retired 정의")
		check(ok.defs.retired.battle == ok.defs.battle and ok.defs.retired.party != ok.defs.party, "전투 정의는 같고 파티는 따로 읽음")
	var plain := _load("test.json")
	check(plain.ok() and plain.defs.retired == null, "retired 없는 묶음")
	for bad in [3, "", "x/test.json", "test", "arbor.json"]:
		_set_dir_with({"arbor.json": game.merged({"retired": bad}, true), "test.json": test_set})
		var r := _load("arbor.json")
		check(r.errors.any(func(e: String) -> bool: return e.contains("retired 는 같은 폴더의 다른 층 묶음 파일 이름")), "retired %s: %s" % [str(bad), str(r.errors)])
	_set_dir_with({"arbor.json": game.merged({"retired": "copy.json"}, true), "copy.json": game.merged({}, true).merged({"retired": "test.json"}, true),
		"test.json": test_set})
	var nested := _load("arbor.json")
	check(nested.errors.any(func(e: String) -> bool: return e.begins_with("retired: ") and e.contains("지금 묶음에도 있다")), "겹친 층 ID %s" % str(nested.errors))
	check(nested.errors.any(func(e: String) -> bool: return e.contains("retired 가 또 있다")), "은퇴한 묶음의 retired %s" % str(nested.errors))
	_set_dir_with({"arbor.json": game.merged({"retired": "missing.json"}, true)})
	check(not _load("arbor.json").ok(), "없는 은퇴 묶음은 오류")


func teardown() -> void:
	_clean_set_dir()
	super()
