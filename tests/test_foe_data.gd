## FOE 자료(M3 A6 설계 §2·§7.1): 층의 foes 형식(D1), FOE 정의(D2), 경고 0(D3), 실제 자료의 배치·소재·공략(D4).
## 시험마다 죽이는 변이(M-D…)를 적는다. 값은 설계 노트에서 옮긴 고정 값이다(lesson 7).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const ROUTE_PATH := "res://data/floors/arbor_route.json"

## 위 줄: (0,0) 시작, (3,0)–(4,0) 사이 문, (5,0) 얼음. 아래 줄은 모두 열림. 위아래는 x=0·x=5 에서만 이어진다.
const GRID := [
	"+-+-+-+-+-+-+",
	"|. . . .D. =|",
	"+ +-+-+-+-+ +",
	"|. . . . . .|",
	"+-+-+-+-+-+-+",
]
const GOOD := {"id": "p1", "foe": "foe.ether_ram", "kind": "patrol", "at": [1, 0], "facing": "E", "path": [[1, 0], [2, 0], [3, 0]], "join": 4,
	"respawn": "never"}
const CHASER := {"id": "c1", "foe": "foe.lost_delver", "kind": "chase", "at": [2, 1], "facing": "W", "sight": 3, "chase": 4, "join": 3,
	"respawn": "floor_reload"}
const GUARD := {"id": "g1", "foe": "foe.warden", "kind": "guard", "at": [3, 1], "facing": "N", "respawn": "after_days", "respawn_days": 2}


func _foe(base: Dictionary, over: Dictionary = {}, drop: Array = []) -> Dictionary:
	var f := base.duplicate(true)
	f.merge(over, true)
	for k in drop:
		f.erase(k)
	return f


func _floor(foes: Variant, extra: Dictionary = {}, grid: Array = GRID) -> Dictionary:
	var d := {"foes": foes}
	d.merge(extra, true)
	return Fx.floor_dict(grid, d)


func _expect_error(d: Dictionary, needle: String, label: String) -> void:
	var errs := Fx.parse(d).errors
	check(not errs.is_empty(), "%s: 오류가 나야 한다" % label)
	var re := RegEx.create_from_string("^fx\\.json:\\d+:\\d+: ")
	var found := false
	for e in errs:
		check(re.search(e) != null, "%s: 위치 없는 오류 %s" % [label, e])
		found = found or e.contains(needle)
	check(found, "%s: '%s' 를 담은 오류가 없다 %s" % [label, needle, str(errs)])


## D1 (M-D1a 문 너머 경로, M-D1b 상자 칸 시작, M-D1c 계단 옆 문지기, M-D1d 경로 없는 순회): 층 foes 형식.
func test_floor_format() -> void:
	var ok := Fx.parse(_floor([GOOD, CHASER, GUARD]))
	check(ok.ok(), "기본 셋 오류 %s" % str(ok.errors))
	if ok.ok():
		var f := ok.floor_def
		check_eq(f.foe_list().map(func(x: FloorModel.FoeSpawn) -> String: return x.id), ["p1", "c1", "g1"], "읽은 차례")
		var p: FloorModel.FoeSpawn = f.foes["p1"]
		check_eq([p.foe, p.kind, p.at, p.facing, p.path, p.join, p.respawn], ["foe.ether_ram", "patrol", Vector2i(1, 0), Dir.E,
			[Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], 4, "never"], "순회 p1")
		var c: FloorModel.FoeSpawn = f.foes["c1"]
		check_eq([c.kind, c.sight, c.chase, c.join, c.path, c.respawn], ["chase", 3, 4, 3, [], "floor_reload"], "추적 c1")
		var g: FloorModel.FoeSpawn = f.foes["g1"]
		check_eq([g.kind, g.facing, g.respawn, g.respawn_days], ["guard", Dir.N, "after_days", 2], "문지기 g1")
		check_eq([f.is_foe_cell(Vector2i(0, 0)), f.is_foe_cell(Vector2i(5, 0)), f.is_foe_cell(Vector2i(4, 1))], [false, false, true], "FOE 칸: 시작·얼음 아님")
		check_eq([f.foe_step(Vector2i(3, 0), Dir.E), f.foe_step(Vector2i(2, 0), Dir.E), f.foe_step(Vector2i(1, 0), Dir.S)], [false, true, false],
			"FOE 걸음: 문·벽은 못 지난다")
	_expect_error(_floor([_foe(GOOD, {"x": 1})]), "foes[0].x 는 patrol FOE 에 쓰지 않는 필드다", "모르는 필드")
	_expect_error(_floor([_foe(GOOD, {"sight": 3})]), "foes[0].sight 는 patrol FOE 에 쓰지 않는 필드다", "순회에 시야")
	_expect_error(_floor([_foe(GOOD, {"id": "P1"})]), "foes[0].id 는", "id 꼴")
	_expect_error(_floor([GOOD, _foe(GUARD, {"id": "p1"})]), "foes[1] 의 id p1 가 중복", "id 중복")
	_expect_error(_floor([_foe(GOOD, {"kind": "boss"})]), "foes[0].kind 는", "모르는 종류")
	_expect_error(_floor([_foe(GOOD, {"foe": "enemy.ram"})]), "foes[0].foe 는 foe. 로 시작하는", "정의 ID 꼴")
	_expect_error(_floor([_foe(GOOD, {"facing": "X"})]), "foes[0].facing 은", "방향")
	_expect_error(_floor([_foe(GUARD, {"at": [5, 0]})]), "foes[0] 5:0 이 FOE 가 설 수 있는 칸이 아니다", "얼음 칸")
	_expect_error(_floor([_foe(GUARD, {"at": [2, 0]})], {}, ["+-+-+-+", "|. .|#|", "+-+-+-+"]), "foes[0] 2:0 이 FOE 가 설 수 있는 칸이 아니다", "빈 칸(#)")
	_expect_error(_floor([_foe(GUARD, {"at": [0, 0]})]), "foes[0] 0:0 이 FOE 가 설 수 있는 칸이 아니다", "시작 칸")
	var st := {"stairs": [{"at": [5, 1], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]}
	_expect_error(_floor([_foe(GUARD, {"at": [5, 1]})], st), "foes[0] 5:1 이 FOE 가 설 수 있는 칸이 아니다", "계단 칸")
	_expect_error(_floor([_foe(GUARD, {"at": [4, 1]})], {"chests": [{"id": "c", "at": [4, 1], "money": 1}]}), "foes[0] 4:1 에 상자가 있다", "상자 칸")
	_expect_error(_floor([_foe(GUARD, {"at": [4, 1]})], {"gathering": [{"id": "g1", "at": [4, 1], "kind": "take", "uses": 2, "table": "gather.x.take"}]}),
		"foes[0] 4:1 에 채집 지점이 있다", "채집 지점 칸")
	_expect_error(_floor([GUARD], {"reserved": [[3, 1, 3, 1]]}), "foes[0] 3:1 이 FOE 가 설 수 있는 칸이 아니다", "예약 구역")
	_expect_error(_floor([GOOD, _foe(GUARD, {"at": [1, 0]})]), "foes[1] 1:0 에 다른 FOE 가 이미 있다", "같은 칸 둘")
	# 경로
	_expect_error(_floor([_foe(GOOD, {"path": [[2, 0], [3, 0]]})]), "foes[0].path 의 첫 칸이 at 이 아니다", "첫 칸")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0], [3, 0]]})]), "foes[0].path[1] 가 앞 칸과 열린 경계로 이어지지 않는다", "이웃 아님")
	_expect_error(_floor([_foe(GOOD, {"at": [2, 0], "path": [[2, 0], [3, 0], [4, 0]]})]), "foes[0].path[2] 가 앞 칸과 열린 경계로", "문 너머")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0], [1, 1]]})]), "foes[0].path[1] 가 앞 칸과 열린 경계로", "벽 너머")
	var row := Fx.row_grid("....", " > ")
	check(Fx.parse(_floor([_foe(GOOD, {"path": [[1, 0], [2, 0]]})], {}, Fx.row_grid("....", "   "))).ok(), "준비: 열린 줄 경로")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0], [2, 0]]})], {}, row), "foes[0].path[1] 가 앞 칸과 열린 경계로", "일방통행 너머")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0], [2, 0]]})], {"shortcuts": [{"at": [1, 0], "dir": "E"}]}, Fx.row_grid("....", " L ")),
		"foes[0].path[1] 가 앞 칸과 열린 경계로", "지름길 너머")
	_expect_error(_floor([_foe(GOOD, {"at": [4, 0], "path": [[4, 0], [5, 0]]})]), "foes[0].path[1] 5:0 이 FOE 가 설 수 있는 칸이 아니다", "얼음 경로")
	_expect_error(_floor([_foe(GOOD, {"at": [4, 1], "path": [[4, 1], [5, 1]]})], st), "foes[0].path[1] 5:1 이 FOE 가 설 수 있는 칸이 아니다", "계단 경로")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0], [2, 0], [1, 0]]})]), "foes[0].path[2] 1:0 를 두 번 지난다", "같은 칸 두 번")
	_expect_error(_floor([_foe(GOOD, {"path": [[1, 0]]})]), "foes[0].path 는 칸 2~32 개", "경로 한 칸")
	_expect_error(_floor([_foe(GOOD, {}, ["path"])]), "foes[0].path 가 없다", "경로 없는 순회")
	_expect_error(_floor([_foe(GUARD, {"path": [[3, 1], [4, 1]]})]), "foes[0].path 는 guard FOE 에 쓰지 않는 필드다", "경로 있는 문지기")
	_expect_error(_floor([_foe(GUARD, {"join": 2})]), "foes[0].join 는 guard FOE 에 쓰지 않는 필드다", "합류 있는 문지기")
	check(Fx.parse(_floor([_foe(CHASER, {"at": [2, 1], "path": [[2, 1], [3, 1]]})])).ok(), "추적의 경로는 선택")
	# 범위
	for x in [["sight", 0, "1~9"], ["sight", 10, "1~9"], ["chase", 0, "1~20"], ["chase", 21, "1~20"], ["join", 10, "0~9"], ["join", -1, "0~9"],
			["sight", 1.5, "1~9"], ["chase", true, "1~20"]]:
		_expect_error(_floor([_foe(CHASER, {x[0]: x[1]})]), "foes[0].%s 는 정수 %s 이어야 한다" % [x[0], x[2]], "%s %s" % [x[0], str(x[1])])
	check(Fx.parse(_floor([_foe(CHASER, {"sight": 9, "chase": 20, "join": 0})])).ok(), "범위 끝값 받음")
	_expect_error(_floor([_foe(GOOD, {"respawn": "sometimes"})]), "foes[0].respawn 은", "모르는 되살아남")
	_expect_error(_floor([_foe(GOOD, {"respawn": "after_days"})]), "foes[0].respawn_days 는 respawn 이 after_days 일 때만", "날 수 없음")
	_expect_error(_floor([_foe(GOOD, {"respawn_days": 2})]), "foes[0].respawn_days 는 respawn 이 after_days 일 때만", "never 에 날 수")
	for n in [0, 100]:
		_expect_error(_floor([_foe(GUARD, {"respawn_days": n})]), "foes[0].respawn_days 는 정수 1~99", "날 수 %d" % n)
	# 문지기: 계단·시작 칸과 열린 경계로 맞닿으면 안 된다. 벽 너머는 된다.
	_expect_error(_floor([_foe(GUARD, {"at": [4, 1]})], st), "foes[0] 4:1 문지기가 계단·시작 칸과 맞닿아 있다", "계단 옆 문지기")
	_expect_error(_floor([_foe(GUARD, {"at": [1, 0]})]), "foes[0] 1:0 문지기가 계단·시작 칸과 맞닿아 있다", "시작 옆 문지기")
	_expect_error(_floor([_foe(GUARD, {"at": [0, 1]})]), "foes[0] 0:1 문지기가 계단·시작 칸과 맞닿아 있다", "시작 아래 문지기(열림)")
	check(Fx.parse(_floor([_foe(GUARD, {"at": [1, 1]})])).ok(), "시작과 벽 너머 대각 자리는 된다")
	_expect_error(_floor(3), "foes는 배열이어야 한다", "배열 아님")


func _db_errors(foes: Array) -> Array[String]:
	return Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": foes}})).errors


func _rejects(foes: Array, needle: String, label: String) -> void:
	var errs := _db_errors(foes)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


func _def(over: Dictionary = {}) -> Dictionary:
	var d := {"id": "foe.t1", "level": 5, "formation": {"id": "formation.foe.t1", "no_escape": false, "enemies": [{"enemy": "enemy.neon_rat", "row": "front"}]}}
	d.merge(over, true)
	return d


## D2 (M-D2a 적 둘인 FOE 무리를 받음, M-D2b 없는 FOE 정의를 가리키는 층을 받음): FOE 정의와 층 참조.
func test_foe_definitions() -> void:
	check_eq(_db_errors([_def()]), [] as Array[String], "기본 정의")
	var db := Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": [_def()]}}))
	var fd := db.foe("foe.t1")
	check(fd != null and [fd.level, fd.formation] == [5, "formation.foe.t1"] and db.formations.has("formation.foe.t1"), "읽은 정의·편성 등록")
	var two := _def()
	two["formation"]["enemies"].append({"enemy": "enemy.neon_rat", "row": "back"})
	_rejects([two], "foes/test.json: foes[0].formation.enemies: FOE 의 무리는 적 하나여야 한다", "적 둘")
	var ne := _def()
	ne["formation"]["no_escape"] = true
	_rejects([ne], "FOE 의 무리는 도망칠 수 있어야 한다(false)", "도주 불가")
	for lv in [0, 100, 1.5, "5"]:
		_rejects([_def({"level": lv})], "foes[0].level: 정수 1~99 이어야 한다", "레벨 %s" % str(lv))
	_rejects([_def({"x": 1})], "foes[0]", "모르는 키")
	_rejects([_def({"id": "formation.t1"})], "foes[0].id", "foe. 접두사")
	var ghost := _def()
	ghost["formation"]["enemies"][0]["enemy"] = "enemy.nope"
	_rejects([ghost], "없는 적 enemy.nope", "모르는 적")
	_rejects([_def(), _def({"formation": {"id": "formation.foe.t2", "no_escape": false, "enemies": [{"enemy": "enemy.neon_rat", "row": "front"}]}})],
		"foe.t1", "id 중복")
	# 층이 없는 정의를 가리키면 GameDefs 가 거부한다.
	var f := Fx.parse(_floor([_foe(GOOD, {"foe": "foe.nope"})])).floor_def
	check(f != null, "준비: 층은 형식상 맞다")
	if f != null:
		var errs := GameDefs.check_foes([f] as Array[FloorModel], Fx.defs().battle)
		check_eq(errs, ["fx: foes: FOE p1 의 정의 foe.nope 가 없다"] as Array[String], "없는 FOE 정의")
		var good := Fx.parse(_floor([GOOD, CHASER])).floor_def
		check_eq(GameDefs.check_foes([good] as Array[FloorModel], Fx.defs().battle), [] as Array[String], "있는 정의는 통과")


## D3 (M-D3 _check_refs 의 FOE 편성 예외를 지움): 실제 자료는 경고 0, 출현 표에 없는 시험 FOE 편성도 경고가 없다.
func test_zero_warnings() -> void:
	var real := BattleDb.load_dir(Fx.DATA_DIR)
	check_eq([real.errors, real.warnings], [[] as Array[String], [] as Array[String]], "실제 자료 오류·경고 0")
	var db := Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": [_def()]}}))
	check_eq(db.warnings, [] as Array[String], "출현 표 밖 FOE 편성도 경고 없음")


## D4 (M-D4b 경비기를 B3F (12,5) 로 옮기면 진행 검사가 막힘을 알린다): 실제 자료의 배치·정의·소재.
func test_real_placements() -> void:
	# 층 파일을 따로 읽어 문지기 진행 검사를 먼저 본다(정의 묶음은 이 오류가 있으면 만들어지지 않는다).
	for fid in ["b1f", "b2f", "b3f"]:
		var lr := FloorLoader.load_path("res://data/floors/%s.json" % fid)
		check(lr.ok(), "%s 층 읽기 %s" % [fid, str(lr.errors)])
		if lr.ok():
			check_eq(FloorLoader.guard_progress(lr.floor_def, fid), [] as Array[String], "%s: 문지기 진행 검사(층 파일)" % fid)
	var defs := Fx.arbor()
	check(defs != null, "arbor 정의")
	if defs == null:
		return
	var want := {
		"b1f": ["f1", "foe.ether_ram", "patrol", Vector2i(12, 9), Dir.E, [Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9)],
			0, 0, 2, "after_days", 1],
		"b2f": ["f2", "foe.lost_delver", "chase", Vector2i(5, 10), Dir.W, [], 3, 4, 3, "floor_reload", 0],
		"b3f": ["f3", "foe.warden", "guard", Vector2i(16, 3), Dir.N, [], 0, 0, 0, "never", 0],
	}
	for fid in want:
		var f := defs.floor_by_id(fid)
		check_eq(f.foe_list().size(), 1, "%s: FOE 하나" % fid)
		var sp: FloorModel.FoeSpawn = f.foe_list()[0]
		check_eq([sp.id, sp.foe, sp.kind, sp.at, sp.facing, sp.path, sp.sight, sp.chase, sp.join, sp.respawn, sp.respawn_days], want[fid], "%s 배치" % fid)
		check_eq(FloorLoader.guard_progress(f, fid), [] as Array[String], "%s: 문지기 진행 검사 통과" % fid)
		check_eq(FloorLoader.analyze(f, fid + ".json"), [] as Array[String], "%s: 분석 경고 0" % fid)
	var db := defs.battle
	check_eq(db.foe_ids, ["foe.ether_ram", "foe.lost_delver", "foe.warden"] as Array[String], "FOE 정의 셋")
	for x in [["foe.ether_ram", 6, "enemy.foe_ether_ram", 600, 180], ["foe.lost_delver", 10, "enemy.foe_lost_delver", 760, 260],
			["foe.warden", 14, "enemy.foe_warden", 1100, 360]]:
		var fd := db.foe(x[0])
		var form: BattleDb.FormationDef = db.formations[fd.formation]
		var en: BattleDb.EnemyDef = db.enemies[x[2]]
		check_eq([fd.level, form.enemies.size(), form.enemies[0]["enemy"], form.no_escape, en.max_hp, en.exp], [x[1], 1, x[2], false, x[3], x[4]], "%s 정의" % x[0])
	check_eq(db.material_ids.size(), 18, "소재 열여덟")
	var texts := TextDb.load_path("res://data/text/ko.json")
	for x in [["item.ether_horn", 150, "enemy.foe_ether_ram"], ["item.delver_badge", 200, "enemy.foe_lost_delver"], ["item.warden_core", 300, "enemy.foe_warden"]]:
		check_eq(db.material_sell.get(x[0]), x[1], "%s 판매값" % x[0])
		check(int(db.material_sell[x[0]]) > 60, "%s 는 가장 비싼 기존 소재(데이터 코어 60)보다 비싸다" % x[0])
		check(texts.has(x[0]) and texts.has(x[0] + ".desc"), "%s 이름·설명 문구" % x[0])
		check_eq([db.enemies[x[2]].drops[0]["item"], db.enemies[x[2]].drops[0]["chance"]], [x[0], 1000], "%s 는 %s 가 반드시 떨군다" % [x[0], x[2]])
	for id in db.material_ids:
		check(texts.has(db.materials[id]) and texts.has(db.material_desc.get(id, "")), "%s 이름·설명" % id)


## 공략 행동열을 걷는다. 전투 대기면 이겼다고 친다. all_down 이면 매 행동 뒤 모든 층의 FOE 를 쓰러진 것으로 둔다. 체크포인트를 본다.
func _walk(s: ExplorationState, all_down: bool, label: String) -> Array[Dictionary]:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	var all: Array[Dictionary] = []
	var cps: Array = route["checkpoints"]
	var next_cp := 0
	for i in route["actions"].size():
		if all_down:
			for fid in s.floor_states:
				for id in s.floor_states[fid].world.foes:
					var fs: WorldState.FoeState = s.floor_states[fid].world.foes[id]
					fs.state = "defeated"
					fs.day = s.day
		all.append_array(ExplorationRules.apply(s, ExplorationRules.action_from_name(route["actions"][i]), "full"))
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
		while next_cp < cps.size() and int(cps[next_cp]["after"]) == i + 1:
			var cp: Dictionary = cps[next_cp]
			check_eq([s.floor_def.id, s.party.at], [cp["floor"], Vector2i(int(cp["at"][0]), int(cp["at"][1]))], "%s: 체크포인트 「%s」" % [label, cp["note"]])
			next_cp += 1
	check_eq(next_cp, cps.size(), "%s: 체크포인트를 모두 지남" % label)
	return all


## D4 (M-D4a 숫양 경로를 공략이 지나는 x=9 로 옮기면 접촉이 난다): 실제 규칙으로 공략을 걸으면 FOE 와 얽히는 이벤트(접촉·발견·놓침·쓰러짐)가
## 하나도 없고 B1F 숫양의 순회(foe_moved·foe_turned)만 있다(FOE 는 모두 살아 있다). 모든 FOE 를 쓰러뜨린 채 걸어도 같은 체크포인트에 닿는다
## (진행이 살아 있는 FOE 에 기대지 않는다). 설계 노트의 「foe_* 이벤트 없음」은 순회 걸음까지 막는 글이라 이렇게 고쳐 읽는다(보고에 적음).
func test_route_meets_no_foe() -> void:
	var defs := Fx.arbor()
	if defs == null:
		check(false, "arbor 정의")
		return
	for seed_value in [31, 41]:
		var s := ExplorationRules.new_game(defs, seed_value, "full")
		var ev := _walk(s, false, "시드 %d" % seed_value)
		var foe_ev := ev.filter(func(e: Dictionary) -> bool: return str(e["type"]).begins_with("foe_"))
		var walks := foe_ev.filter(func(e: Dictionary) -> bool: return e["type"] in ["foe_moved", "foe_turned"] and e["foe"] == "f1")
		check_eq(foe_ev.size() - walks.size(), 0, "시드 %d: 숫양 순회 말고는 FOE 이벤트 없음 %s" % [seed_value, str(foe_ev.filter(func(e): return not walks.has(e)))])
		check(walks.size() > 0, "시드 %d: 숫양은 공략 동안 순회한다" % seed_value)
		check_eq(ev.filter(func(e: Dictionary) -> bool: return e["type"] == "encounter" and e.has("foe")), [], "시드 %d: 접촉 전투 없음" % seed_value)
		check_eq([s.floor_def.id, s.party.at], ["b3f", Vector2i(9, 2)], "시드 %d: 봉인 문 앞" % seed_value)
		for fid in s.floor_states:
			for id in s.floor_states[fid].world.foes:
				check(s.floor_states[fid].world.foes[id].alive(), "시드 %d: %s %s 는 살아 있다" % [seed_value, fid, id])
	var d := ExplorationRules.new_game(defs, 31, "full")
	_walk(d, true, "모두 쓰러짐")
	check_eq([d.floor_def.id, d.party.at, d.key_items.size()], ["b3f", Vector2i(9, 2), 2], "모두 쓰러져도 봉인 문 앞, 열쇠 둘")


## D1 (M-R2 문지기 검사를 들어오는 곳 모두에서 한꺼번에 걷기, 리뷰 R2): 아홉 칸 복도의 시작 (0,0)·계단 (8,0) 사이 문지기 (4,0) 는
## 시작에서 계단을 끊으므로 오류다. 곁가지 끝의 문지기는 진행을 막지 않으므로 통과.
func test_guard_progress_per_entry() -> void:
	var st := {"at": [8, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}
	var cut := Fx.parse(Fx.floor_dict(Fx.row_grid(".........", "        "), {"stairs": [st], "foes": [_foe(GUARD, {"at": [4, 0]})]}))
	check(cut.ok(), "준비: 복도 층은 형식상 맞다 %s" % str(cut.errors))
	if cut.ok():
		check_eq(FloorLoader.guard_progress(cut.floor_def, "fx"), ["fx: foes: 문지기가 막으면 0:0 에서 칸 8:0(계단·열쇠 상자·잠긴 문)에 닿을 수 없다"] as Array[String],
			"시작에서 계단이 끊긴다")
	var pocket := [
		"+-+-+-+-+-+-+-+-+-+",
		"|. . . . . . . . .|",
		"+-+-+-+ +-+-+-+-+-+",
		"|#|#|#|. . .|#|#|#|",
		"+-+-+-+-+-+-+-+-+-+",
	]
	var side := Fx.parse(Fx.floor_dict(pocket, {"stairs": [st], "foes": [_foe(GUARD, {"at": [5, 1]})]}))
	check(side.ok(), "준비: 곁가지 층 %s" % str(side.errors))
	if side.ok():
		check_eq(FloorLoader.guard_progress(side.floor_def, "fx"), [] as Array[String], "곁가지 끝 문지기는 통과")


## 고정 공략이 지나는 칸(층 → 칸 → true): 행동 뒤 자리와 미끄러짐이 지난 칸(moved 의 to). 전투는 이겼다고 친다.
func _route_cells() -> Dictionary:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	var s := ExplorationRules.new_game(Fx.arbor(), 31, "full")
	var out := {}
	out[s.floor_def.id] = {s.party.at: true}
	for a in route["actions"]:
		for e in ExplorationRules.apply(s, ExplorationRules.action_from_name(a), "full"):
			if e["type"] == "moved":
				out[s.floor_def.id][e["to"]] = true
		if s.encounter.pending:
			BattleRules.finish(s, "victory")
		if not out.has(s.floor_def.id):
			out[s.floor_def.id] = {}
		out[s.floor_def.id][s.party.at] = true
	return out


## FOE 의 합류 범위가 닿는 출발 칸: 순회는 경로 칸, 추적은 시작 칸에서 FOE 걸음으로 닿는 모든 칸(경로 포함), 문지기는 없다(합류하지 않는다).
func _join_sources(f: FloorModel, sp: FloorModel.FoeSpawn) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if sp.kind == "patrol":
		out.append_array(sp.path)
	elif sp.kind == "chase":
		for c in FoeRules.distances(f, sp.at):
			out.append(c)
	return out


## L1 (M-L1 숫양 합류 범위 4, 리뷰 L1): 고정 공략의 모든 칸은 각 FOE 의 합류 범위(join, FOE 걸음 거리)보다 멀다.
## 숫양: 경로 (12..17,9) 에서 가장 가까운 공략 칸 (9,9) 까지 3 > join 2. 탐험가: 닫힌 방이라 공략 칸에 닿지 못한다. 경비기: 합류 없음.
func test_route_outside_join_ranges() -> void:
	var defs := Fx.arbor()
	if defs == null:
		check(false, "arbor 정의")
		return
	var cells := _route_cells()
	check_eq(cells.keys(), ["b1f", "b2f", "b3f"], "준비: 공략은 세 층을 지난다")
	var nearest := {}
	for fid in ["b1f", "b2f", "b3f"]:
		var f := defs.floor_by_id(fid)
		for sp in f.foe_list():
			var best := 999
			for src in _join_sources(f, sp):
				var dist := FoeRules.distances(f, src)
				for c in cells.get(fid, {}):
					if dist.has(c):
						best = mini(best, int(dist[c]))
			nearest[sp.id] = [sp.join, best]
			if sp.kind != "guard":
				check(best > sp.join, "%s %s: 가장 가까운 공략 칸 거리 %d > join %d" % [fid, sp.id, best, sp.join])
	check_eq(nearest, {"f1": [2, 3], "f2": [3, 999], "f3": [0, 999]}, "FOE → [join, 가장 가까운 공략 칸 거리](999 = 닿지 않음)")
