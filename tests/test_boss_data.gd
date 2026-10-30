## 보스 자료(M3 A9a 설계 §2·§3·§7.1): 층 형식(보스 FOE·봉인 needs·no_return, B1), 봉인 뒤 칸(behind_seal, 조건 1의 바탕, B2),
## 묶음 검사(보스 정의 ↔ 종류, 봉인 needs 의뢰, B3), 보스 정의·적 buff(B4), 실제 자료(B3F 배치·펜리르·문구, B5).
## 시험마다 죽이는 변이(M-B…)를 적는다. 값은 설계 노트·최종 문구(a9_copy_final.md)에서 옮긴 고정 값이다(lesson 7).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")

## 한 줄 다섯 칸: (0,0) 시작(동쪽), (2,0)|K|(3,0) 잠긴 문(v:3:0), 방 (3,0)·(4,0).
const ROOM := [
	"+-+-+-+-+-+",
	"|. . .K. .|",
	"+-+-+-+-+-+",
]
const SEAL_E := Vector3i(3, 0, 1)
const SEAL := {"at": [2, 0], "dir": "E", "seal": "boss", "needs": "permit.boss"}
const BOSS := {"id": "boss", "foe": "foe.fenrir", "kind": "boss", "at": [4, 0], "facing": "W", "respawn": "never"}
## 2×4: 봉인 (1,0)|K|(2,0) 너머 (2,0)·(3,0) 은 아래 줄로도 이어진다(봉인 뒤 칸이 없다).
const LOOP := [
	"+-+-+-+-+",
	"|. .K. .|",
	"+ +-+-+ +",
	"|. . . .|",
	"+-+-+-+-+",
]
## 최종 문구(a9_copy_final.md, 조정자 승인). A9a 가 넣은 키 스물다섯 모두.
const COPY := {
	"enemy.boss_fenrir": "네온 펜리르",
	"skill.enemy.fenrir_fang": "배선 송곳니",
	"skill.enemy.fenrir_rend": "방전 할퀴기",
	"skill.enemy.static_howl": "교란 하울링",
	"skill.enemy.neon_glare": "네온 섬광",
	"skill.enemy.overclock": "과부하 구동",
	"skill.enemy.coil_charge": "코일 충전",
	"skill.enemy.thunder_lunge": "뇌광 돌진",
	"item.fenrir_core": "펜리르 동력핵",
	"item.fenrir_core.desc": "네온 펜리르의 심장부. 아직 미약하게 맥동한다",
	"item.fenrir_fang": "온전한 배선 송곳니",
	"item.fenrir_fang.desc": "전류가 살아 있는 송곳니. 머리를 봉인한 채 쓰러뜨려야 얻는다",
	"msg.seal_opened": "관리국의 허가 신호에 봉인이 풀렸다",
	"msg.seal_closed": "허가 신호가 반응한다. 문을 마주 보고 열자",
	"msg.no_boss": "싸울 상대가 없다",
	"msg.boss_contact": "봉인 너머의 주인이 깨어났다!",
	"boss.title": "강대한 기척",
	"boss.ask": "{name}이(가) 버티고 서 있다. 싸울까?",
	"boss.no_escape": "이 싸움에서는 도망칠 수 없다",
	"battle.boss_start": "{name}이(가) 앞을 막아선다!",
	"clear.stratum1.speaker": "관리국 통신",
	"clear.stratum1.1": "{name}의 신호가 끊겼다. 숲을 뒤덮던 배선의 맥동이 잦아든다.",
	"clear.stratum1.2": "「탐사대, 응답하라. 제1계층의 주인이 쓰러진 것을 확인했다. 잘 해냈다.」",
	"clear.stratum1.3": "「더 아래로 이어지는 길은 아직 열리지 않았다. 마을로 돌아와 쉬어라. 관리국은 그대들의 귀환을 기다린다.」",
	"menu.slot_clear": "제1계층 돌파",
}


func _room(extra: Dictionary = {}, grid: Array = ROOM) -> Dictionary:
	var d := {"locks": [SEAL], "foes": [BOSS], "no_return": [[3, 0, 4, 0]]}
	d.merge(extra, true)
	return Fx.floor_dict(grid, d)


func _boss(over: Dictionary = {}) -> Dictionary:
	var b := BOSS.duplicate(true)
	b.merge(over, true)
	return b


func _expect_error(d: Dictionary, needle: String, label: String) -> void:
	var errs := Fx.parse(d).errors
	check(not errs.is_empty(), "%s: 오류가 나야 한다" % label)
	var re := RegEx.create_from_string("^fx\\.json:\\d+:\\d+: ")
	var found := false
	for e in errs:
		check(re.search(e) != null, "%s: 위치 없는 오류 %s" % [label, e])
		found = found or e.contains(needle)
	check(found, "%s: '%s' 를 담은 오류가 없다 %s" % [label, needle, str(errs)])


func _cells(list: Array) -> Dictionary:
	var out := {}
	for c in list:
		out[c] = true
	return out


## B1 (M-B1a 보스 respawn 검사를 지움, M-B1b 맞닿은 칸 검사를 지움, M-B1c needs 를 열쇠 문에도 받음, M-B1d no_return 의 시작 칸 검사를 지움):
## 보스 FOE·봉인 needs·no_return 형식.
func test_floor_format() -> void:
	var ok := Fx.parse(_room())
	check(ok.ok(), "기본 보스 방 오류 %s" % str(ok.errors))
	if ok.ok():
		var f := ok.floor_def
		var sp: FloorModel.FoeSpawn = f.foes["boss"]
		check_eq([sp.foe, sp.kind, sp.at, sp.facing, sp.respawn, sp.path, sp.join], ["foe.fenrir", "boss", Vector2i(4, 0), Dir.W, "never", [], 0], "보스 FOE")
		check_eq([f.is_sealed(SEAL_E), f.seal_of(SEAL_E), f.seal_needs(SEAL_E), f.needs_seals()], [true, "boss", "permit.boss", [SEAL_E] as Array[Vector3i]],
			"needs 봉인")
		check_eq(f.no_return, _cells([Vector2i(3, 0), Vector2i(4, 0)]), "no_return 사각형")
	var plain := Fx.parse(_room({"locks": [{"at": [2, 0], "dir": "E", "seal": "boss"}], "foes": []}))
	check(plain.ok() and plain.floor_def.seal_needs(SEAL_E) == "" and plain.floor_def.needs_seals().is_empty(), "needs 없는 봉인은 그대로 %s" % str(plain.errors))
	_expect_error(_room({"foes": [_boss({"respawn": "floor_reload"})]}), "foes[0] 4:0 보스의 respawn 은 never 여야 한다", "되살아나는 보스")
	_expect_error(_room({"foes": [BOSS, _boss({"id": "boss2", "at": [3, 0]})]}), "foes[1] 3:0 보스가 층에 둘이다", "보스 둘")
	_expect_error(_room({"foes": [_boss({"sight": 3})]}), "foes[0].sight 는 boss FOE 에 쓰지 않는 필드다", "보스에 시야")
	_expect_error(_room({"chests": [{"id": "c", "at": [3, 0], "money": 1}]}), "foes[0] 4:0 보스와 맞닿은 칸 3:0 에 계단·시작 칸·상자·채집 지점이 있다", "보스 옆 상자")
	_expect_error(_room({"gathering": [{"id": "g1", "at": [3, 0], "kind": "take", "uses": 2, "table": "gather.x.take"}]}),
		"보스와 맞닿은 칸 3:0 에", "보스 옆 채집 지점")
	_expect_error(_room({"foes": [_boss({"at": [1, 0]})], "no_return": []}), "보스와 맞닿은 칸 0:0 에", "보스 옆 시작 칸")
	_expect_error(_room({"foes": [_boss({"at": [3, 0]})], "no_return": [], "stairs": [{"at": [4, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]}),
		"보스와 맞닿은 칸 4:0 에", "보스 옆 계단")
	# 벽 너머(열린 경계가 아님)는 맞닿은 칸이 아니다: 봉인 너머 (2,0) 의 상자는 받는다.
	var behind_wall := Fx.parse(_room({"foes": [_boss({"at": [3, 0]})], "chests": [{"id": "c", "at": [2, 0], "money": 1}]}))
	check(behind_wall.ok(), "봉인 너머 상자는 맞닿지 않는다 %s" % str(behind_wall.errors))
	_expect_error(_room({"locks": [{"at": [2, 0], "dir": "E", "key": "key.moss_card", "needs": "permit.boss"}]}), "locks[0].needs 는 봉인 문(seal)에만 쓴다", "열쇠 문 needs")
	_expect_error(_room({"locks": [{"at": [2, 0], "dir": "E", "seal": "boss", "needs": "Permit"}]}), "locks[0].needs 는 진행 플래그", "needs 꼴")
	_expect_error(_room({"locks": [{"at": [2, 0], "dir": "E", "seal": "boss", "needs": 3}]}), "locks[0].needs 는 진행 플래그", "needs 숫자")
	_expect_error(_room({"no_return": [[0, 0, 1, 0]]}), "no_return[0] 의 칸 0:0 가 빈 곳·계단·시작 칸이다", "no_return 시작 칸")
	_expect_error(_room({"no_return": [[3, 0, 4, 0]], "foes": [], "stairs": [{"at": [4, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]}),
		"no_return[0] 의 칸 4:0 가", "no_return 계단")
	_expect_error(_room({"no_return": [[3, 0, 4, 0]], "foes": []}, ["+-+-+-+-+-+", "|. . .K.|#|", "+-+-+-+-+-+"]), "no_return[0] 의 칸 4:0 가", "no_return 빈 곳")
	_expect_error(_room({"no_return": [[3, 0, 9, 0]]}), "no_return[0] 가 층 범위를 벗어나거나 뒤집혔다", "no_return 범위 밖")
	_expect_error(_room({"no_return": [[4, 0, 3, 0]]}), "no_return[0] 가 층 범위를 벗어나거나 뒤집혔다", "no_return 뒤집힘")
	_expect_error(_room({"no_return": 3}), "no_return는 배열이어야 한다", "no_return 배열 아님")


## B2 (M-B2a needs 봉인을 세계 비트에서 뺌, M-B2b 봉인 뒤 칸 세기에서 skip 을 무시, M-B2c needs 봉인을 한쪽 칸에서만 연다고 봄):
## needs 봉인은 분석에서 열 수 있는 문이고, 그 봉인만 닫았을 때 닿지 못하는 칸이 behind_seal 이다.
func test_behind_seal() -> void:
	var f := Fx.parse(_room()).floor_def
	check(f != null, "준비: 보스 방")
	if f == null:
		return
	check_eq(FloorLoader.analyze(f, "fx.json"), [] as Array[String], "needs 봉인 너머 방은 닿는다(분석 경고 0)")
	check_eq(FloorLoader._world_bits(f), [SEAL_E], "세계 비트: needs 봉인 하나")
	check_eq(FloorLoader._world_bits(f, SEAL_E), [], "skip 한 봉인은 비트가 아니다")
	check_eq(f.behind_seal, {SEAL_E: _cells([Vector2i(3, 0), Vector2i(4, 0)])}, "봉인 뒤 칸: 방 두 칸")
	var plain := Fx.parse(_room({"locks": [{"at": [2, 0], "dir": "E", "seal": "boss"}], "foes": []})).floor_def
	check(plain != null and not FloorLoader.analyze(plain, "fx.json").is_empty() and plain.behind_seal.is_empty(),
		"needs 없는 봉인은 벽: 너머 방은 닿지 못하고(경고) 봉인 뒤 칸 세기도 없다")
	var loop := Fx.parse(Fx.floor_dict(LOOP, {"locks": [{"at": [1, 0], "dir": "E", "seal": "boss", "needs": "permit.boss"}]})).floor_def
	check(loop != null, "준비: 고리 층")
	if loop != null:
		check_eq(loop.behind_seal, {Vector3i(2, 0, 1): {}}, "다른 길로 닿으면 봉인 뒤 칸이 없다")
	# 봉인 뒤에 들어오는 곳(계단)이 있으면 그 칸들은 봉인 뒤가 아니다(양쪽에서 연다).
	var two := Fx.parse(_room({"foes": [], "no_return": [], "stairs": [{"at": [4, 0], "way": "down", "exit": "W", "to": {"floor": "fy", "at": [0, 0]}}]})).floor_def
	check(two != null and two.behind_seal == {SEAL_E: {}}, "봉인 너머 계단: 봉인 뒤 칸 없음")
	if two != null:
		check_eq(FloorLoader.analyze(two, "fx.json"), [] as Array[String], "계단 쪽에서도 연다(경고 0)")


## B3 (M-B3a check_foes 의 보스 ↔ 정의 검사를 지움, M-B3b check_needs 의 봉인 needs 를 지움): 묶음 검사.
func test_bundle_checks() -> void:
	var defs := Fx.arbor()
	check(defs != null, "arbor 정의")
	if defs == null:
		return
	var f := Fx.parse(_room()).floor_def
	check_eq(GameDefs.check_foes([f] as Array[FloorModel], defs.battle), [] as Array[String], "보스 종류 → 보스 정의")
	var wrong := Fx.parse(_room({"foes": [_boss({"foe": "foe.warden"})]})).floor_def
	check_eq(GameDefs.check_foes([wrong] as Array[FloorModel], defs.battle), ["fx: foes: FOE boss(boss)의 정의 foe.warden 는 보스 정의여야 한다"] as Array[String],
		"보스 종류 → 문지기 정의")
	var guard := Fx.parse(_room({"foes": [{"id": "g", "foe": "foe.fenrir", "kind": "guard", "at": [4, 0], "facing": "W", "respawn": "never"}]})).floor_def
	# 문지기는 방 입구를 막아 진행 검사 오류도 나므로 정의 오류만 고른다.
	var gerrs := GameDefs.check_foes([guard] as Array[FloorModel], defs.battle).filter(func(e: String) -> bool: return e.contains("의 정의 "))
	check_eq(gerrs, ["fx: foes: FOE g(guard)의 정의 foe.fenrir 는 보스 정의가 아니어야 한다"], "문지기 종류 → 보스 정의")
	check_eq(GameDefs.check_needs([f] as Array[FloorModel], defs.quests), [] as Array[String], "permit.boss 는 임무 2 가 준다")
	var nope := Fx.parse(_room({"locks": [{"at": [2, 0], "dir": "E", "seal": "boss", "needs": "permit.nope"}]})).floor_def
	check_eq(GameDefs.check_needs([nope] as Array[FloorModel], defs.quests), ["fx: locks v:3:0: needs permit.nope 를 주는 의뢰가 없다"] as Array[String],
		"주는 의뢰가 없는 needs")
	check_eq(defs.boss_spawns(), [["b3f", "boss"]], "묶음의 보스 자리")
	check_eq(defs.gate_flags(), ["permit.b2f"] as Array[String], "gate_flags 는 계단만(O11)")


func _db_errors(foes: Array) -> Array[String]:
	return Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": foes}})).errors


func _boss_def(over: Dictionary = {}, enemies: int = 1, no_escape: bool = true) -> Dictionary:
	var list := []
	for i in enemies:
		list.append({"enemy": "enemy.neon_rat", "row": "front" if i < 3 else "back"})
	var d := {"id": "foe.tb", "level": 9, "boss": true, "formation": {"id": "formation.boss.tb", "no_escape": no_escape, "enemies": list}}
	d.merge(over, true)
	return d


func _rejects(foes: Array, needle: String, label: String) -> void:
	var errs := _db_errors(foes)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 오류에 「%s」 가 없다: %s" % [label, needle, str(errs)])


## B4 (M-B4a 보스도 적 하나만 받음, M-B4b 보스의 no_escape 거짓을 받음, M-B4c 적 buff 를 다시 막음): 보스 정의(O10 적 1~6)와 적 buff.
func test_boss_definitions() -> void:
	check_eq(_db_errors([_boss_def()]), [] as Array[String], "보스 정의 하나")
	var db := Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": [_boss_def({}, 6)]}}))
	check_eq(db.errors, [] as Array[String], "보스 무리 적 여섯")
	var fd := db.foe("foe.tb")
	check(fd != null and fd.boss and db.formations["formation.boss.tb"].enemies.size() == 6 and db.formations["formation.boss.tb"].no_escape, "읽은 보스 정의")
	_rejects([_boss_def({}, 1, false)], "foes/test.json: foes[0].formation.no_escape: 보스의 무리는 도망칠 수 없어야 한다(true)", "도망칠 수 있는 보스")
	_rejects([_boss_def({"boss": "yes"})], "foes[0].boss", "boss 꼴")
	var plain := _boss_def({"boss": false}, 2, false)
	_rejects([plain], "FOE 의 무리는 적 하나여야 한다", "보스 아님(boss 거짓): 적 둘")
	var nb := Fx.battle_db(Fx.battle_files({"foes/test.json": {"foes": [_boss_def({"boss": false}, 1, false)]}}))
	check(nb.errors.is_empty() and not nb.foe("foe.tb").boss, "boss 거짓은 보통 FOE %s" % str(nb.errors))
	# 적 buff(O9): 자기 강화 사본이 받아들여지고 실제 과부하 구동이 읽힌다.
	var buff := Fx.enemy_skill("skill.enemy.tbuff", "buff", "self", {"range": "ranged"}, {"kind": "phys_atk", "value": 1300, "turns": 3})
	check_eq(Fx.battle_db(Fx.battle_files({"skills/tbuff.json": {"skills": [buff]}})).errors, [] as Array[String], "적 buff 사본")
	var real := Fx.arbor().battle
	var oc: BattleDb.SkillDef = real.skills["skill.enemy.overclock"]
	check_eq([oc.user, oc.effect, oc.target, oc.levels[0]["kind"], oc.levels[0]["value"], oc.levels[0]["turns"]], ["enemy", "buff", "self", "phys_atk", 1300, 3],
		"과부하 구동")


## B5 (M-B5a 보스 칸을 (5,2) 로, M-B5b 방 위험도를 1 로, M-B5c 머리 묶음 송곳니 조건을 지움, M-B5d 문구 한 글자): 실제 자료.
func test_real_data() -> void:
	var defs := Fx.arbor()
	check(defs != null, "arbor 정의")
	if defs == null:
		return
	var f := defs.floor_by_id("b3f")
	var sp: FloorModel.FoeSpawn = f.foes["boss"]
	check_eq([sp.foe, sp.kind, sp.at, sp.facing, sp.respawn], ["foe.fenrir", "boss", Vector2i(4, 2), Dir.E, "never"], "B3F 보스 자리")
	var room := {}
	for y in range(1, 4):
		for x in range(3, 9):
			room[Vector2i(x, y)] = true
	var seal := FloorModel.edge_of(Vector2i(8, 2), Dir.E)
	check_eq([f.seal_needs(seal), f.needs_seals(), f.no_return, f.behind_seal], ["permit.boss", [seal] as Array[Vector3i], room, {seal: room}], "봉인·no_return·봉인 뒤 칸")
	for c in room:
		check_eq(f.danger_at(c), 0, "보스 방 %s 위험도 0" % str(c))
	check_eq([f.danger_at(Vector2i(9, 2)), f.danger_at(Vector2i(10, 6))], [12, 8], "방 밖은 층·얼음 구역 그대로")
	check_eq(FloorLoader.analyze(f, "b3f.json"), [] as Array[String], "B3F 분석 경고 0")
	var db := defs.battle
	var fd := db.foe("foe.fenrir")
	var form: BattleDb.FormationDef = db.formations[fd.formation]
	check_eq([fd.level, fd.boss, fd.formation, form.no_escape, form.enemies], [12, true, "formation.boss.fenrir", true, [{"enemy": "enemy.boss_fenrir", "row": "front"}]],
		"펜리르 정의")
	var en: BattleDb.EnemyDef = db.enemies["enemy.boss_fenrir"]
	check_eq([en.max_hp, en.exp, en.on_bound, en.ai.size()], [1800, 1500, "switch", 7], "펜리르 적")
	check_eq(en.drops, [{"item": "item.fenrir_core", "chance": 1000, "if": {}}, {"item": "item.fenrir_fang", "chance": 1000, "if": {"killed_while_bound": "head"}}], "떨굼")
	check_eq([db.material_sell.get("item.fenrir_core"), db.material_sell.get("item.fenrir_fang")], [500, 800], "보스 소재 판매값")
	var used := {}
	for rule in en.ai:
		for u in rule["use"]:
			used[u["skill"]] = true
	var sk := used.keys()
	sk.sort()
	check_eq(sk, ["skill.enemy.coil_charge", "skill.enemy.fenrir_fang", "skill.enemy.fenrir_rend", "skill.enemy.neon_glare", "skill.enemy.overclock",
		"skill.enemy.static_howl", "skill.enemy.thunder_lunge"], "AI 가 쓰는 스킬 일곱")
	check_eq(db.skills["skill.enemy.coil_charge"].charges, "skill.enemy.thunder_lunge", "충전 → 뇌광 돌진")
	var texts := TextDb.load_path("res://data/text/ko.json")
	for k in COPY:
		check_eq(texts.t(k), COPY[k], "문구 %s" % k)
