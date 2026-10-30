## 보스 규칙(M3 A9a 설계 §4·§7.2): 봉인 열기(R1), 부딪힘·조사 → boss 물음(R2), FIGHT(R3), 전투 끝(R4), 기록 유지(R5), 보스 방(R6).
## 실제 게임 묶음(arbor)의 B3F 에서 본다. 봉인 v:9:2(8,2 의 동쪽), 보스 (4,2) 동쪽을 봄, 방 3:1–8:3.
## 시험마다 죽이는 변이(M-R…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const SEAL := Vector3i(9, 2, 1)
const BOSS_AT := Vector2i(4, 2)

var _defs: GameDefs


func _arbor() -> GameDefs:
	if _defs == null:
		_defs = Fx.arbor()
	return _defs


## B3F 의 칸 at 에 facing 으로 선 미궁 상태. flag 면 permit.boss 를 가진다. open 이면 봉인이 이미 열렸다.
func _game(at: Vector2i, facing: int, flag: bool = true, open: bool = false, seed_value: int = 7) -> ExplorationState:
	var s := ExplorationRules.new_game(_arbor(), seed_value, "full")
	Fx.to_floor(s, "b3f", at, facing)
	if flag:
		s.flags["permit.boss"] = true
	if open:
		s.world.open_lock(SEAL)
	return s


func _act(s: ExplorationState, a: int) -> Array[Dictionary]:
	return ExplorationRules.apply(s, a, "full")


## 걸음·위험도·난수·위치·방향.
func _clock(s: ExplorationState) -> Array:
	return [s.steps, s.encounter.danger, s.rng.get_state(), s.party.at, s.party.facing]


func _boss_rec(s: ExplorationState) -> Array:
	var fs: WorldState.FoeState = s.world.foes["boss"]
	return [fs.at, fs.facing, fs.state, fs.stun, fs.day]


## 파티를 레벨 lv 로 올리고 HP·TP 를 채운다.
func _level(s: ExplorationState, lv: int) -> void:
	var need := s.defs.battle.growth.cum(lv)
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, need)
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp


## 전투가 끝날 때까지 정책으로 명령한다(턴 상한 limit). battle_end 이벤트(없으면 빈 사전).
func _fight_out(s: ExplorationState, policy: String, limit: int = 200) -> Dictionary:
	var n := 0
	while s.battle != null and n < limit:
		for e in BattleRules.submit(s, BattlePolicy.choose(s, policy)):
			if e["type"] == "battle_end":
				return e
		n += 1
	return {}


# ---- R1 봉인 ----

## R1 (M-R1a 플래그 없이도 연다, M-R1b 연 행동이 걸음·차례를 쓴다): 플래그가 없으면 봉인은 벽처럼 sealed(앞으로·조사·뒤·옆 모두).
func test_seal_without_flag() -> void:
	var s := _game(Vector2i(9, 2), Dir.W, false)
	var before := _clock(s)
	check_eq(_act(s, A.FORWARD), [{"type": "blocked", "reason": "sealed"}] as Array[Dictionary], "앞으로: sealed")
	check_eq(_act(s, A.INVESTIGATE), [{"type": "blocked", "reason": "sealed"}] as Array[Dictionary], "조사: sealed")
	check_eq([_clock(s), s.world.is_lock_open(SEAL)], [before, false], "그대로")
	Fx.face(s, Dir.E, "full")
	check_eq(_act(s, A.BACK), [{"type": "blocked", "reason": "sealed"}] as Array[Dictionary], "뒤로: sealed")


## R1 (M-R1c 뒤·옆으로도 연다, M-R1d seal_opened 에 걸음·FOE 차례·난수를 씀, M-R1e 연 봉인이 층 들어서기에 닫힘): 플래그가 있으면
## 바라보고 앞으로·조사로 연다(움직이지 않음). 뒤·옆으로 부딪히면 seal_closed. 연 봉인은 다시 닫히지 않는다.
func test_seal_with_flag() -> void:
	var s := _game(Vector2i(9, 2), Dir.E)
	var before := _clock(s)
	check_eq(_act(s, A.BACK), [{"type": "blocked", "reason": "seal_closed"}] as Array[Dictionary], "뒤로: seal_closed")
	Fx.face(s, Dir.N, "full")
	check_eq(_act(s, A.STRAFE_LEFT), [{"type": "blocked", "reason": "seal_closed"}] as Array[Dictionary], "옆으로: seal_closed")
	Fx.face(s, Dir.W, "full")
	before = _clock(s)
	var foes_before: Dictionary = SaveCodec.floor_state_to_dict(s.floor_states["b3f"])["world"]["foes"]
	var ev := _act(s, A.FORWARD)
	check_eq(ev, [{"type": "seal_opened", "edge": SEAL, "flag": "permit.boss"}] as Array[Dictionary], "앞으로: seal_opened 하나")
	check_eq([_clock(s), s.world.is_lock_open(SEAL), s.floor_def.is_sealed(SEAL)], [before, true, true], "움직이지 않고 걸음·위험도·난수 그대로, 열림")
	check_eq(SaveCodec.floor_state_to_dict(s.floor_states["b3f"])["world"]["foes"], foes_before, "FOE 차례 없음")
	check_eq(ExplorationRules.look_of(s.floor_def, s.world, SEAL), "door", "보이는 모양: 열린 문")
	check_eq(ExplorationRules.block_reason(s.floor_def, s.world, Vector2i(9, 2), Dir.W, {}, {}), "", "열린 봉인은 지나간다(플래그와 상관없이)")
	_act(s, A.FORWARD)
	check_eq(s.party.at, Vector2i(8, 2), "열린 봉인을 지나 방으로")
	Fx.to_floor(s, "b3f", Vector2i(9, 2), Dir.W)
	check(s.world.is_lock_open(SEAL), "층에 다시 들어서도 열린 채")
	TownRules.new_day(s)
	check(s.world.is_lock_open(SEAL), "날이 바뀌어도 열린 채")
	var t := _game(Vector2i(9, 2), Dir.W)
	check_eq(_act(t, A.INVESTIGATE), [{"type": "seal_opened", "edge": SEAL, "flag": "permit.boss"}] as Array[Dictionary], "조사로도 연다")
	var u := _game(Vector2i(8, 2), Dir.E)
	check_eq(_act(u, A.FORWARD), [{"type": "seal_opened", "edge": SEAL, "flag": "permit.boss"}] as Array[Dictionary], "안쪽에서도 연다(양쪽)")


# ---- R2 부딪힘·조사 ----

## R2 (M-R2a 보스에 부딪히면 바로 접촉 전투, M-R2b 조사가 보스를 보지 않음, M-R2c boss_near 가 벽 너머도 셈): 보스에 부딪히거나 바라보고 조사하면
## boss 이벤트 하나(움직이지 않고 걸음·위험도·난수·전투 없음). 서 있는 칸의 물음에도 남는다.
func test_bump_and_investigate() -> void:
	var s := _game(Vector2i(5, 2), Dir.W, true, true)
	var before := _clock(s)
	check_eq(_act(s, A.FORWARD), [{"type": "boss", "foe": "boss"}] as Array[Dictionary], "부딪힘: boss")
	check_eq(_act(s, A.INVESTIGATE), [{"type": "boss", "foe": "boss"}] as Array[Dictionary], "조사: boss")
	check_eq([_clock(s), s.battle == null, s.encounter.pending, _boss_rec(s)], [before, true, false, [BOSS_AT, Dir.E, "idle", 0, 0]], "그대로, 전투 없음")
	check_eq(ExplorationRules.question_here(s), {"kind": "boss", "foe": "boss"}, "서 있는 칸의 물음")
	if s.battle != null or s.encounter.pending:
		return  # 위가 이미 실패했다: 전투 대기에서는 회전도 받지 않아 아래 Fx.face 가 끝나지 않는다
	Fx.face(s, Dir.N, "full")
	check(not Fx.types(_act(s, A.INVESTIGATE)).has("boss"), "보스를 바라보지 않은 조사는 boss 가 아니다")
	check_eq(FoeRules.boss_near(s), "boss", "맞닿음(방향 없이)")
	check_eq([FoeRules.boss_near(s, Dir.W), FoeRules.boss_near(s, Dir.N)], ["boss", ""], "방향을 주면 그쪽만")
	# 옆으로 걸어 부딪혀도 boss(뒤·옆 이동도 같은 부딪힘 자리).
	var t := _game(Vector2i(4, 1), Dir.E, true, true)
	check_eq(_act(t, A.STRAFE_RIGHT), [{"type": "boss", "foe": "boss"}] as Array[Dictionary], "옆으로 부딪힘: boss")
	# 벽 너머는 맞닿지 않는다: (2,2) 는 칸이 아니고, 봉인 밖 (9,2) 와 보스는 멀다.
	var w := _game(Vector2i(9, 2), Dir.W, true, true)
	check_eq([FoeRules.boss_near(w), ExplorationRules.question_here(w)], ["", {}], "멀면 없음")
	# 벽 너머 보스는 맞닿지 않는다(열린 경계만, 시험 층: (1,0)|(2,0) 벽).
	var wf := Fx.floor_of(["+-+-+-+", "|. .|.|", "+-+-+-+"], {"foes": [{"id": "boss", "foe": "foe.fenrir", "kind": "boss", "at": [2, 0], "facing": "W", "respawn": "never"}]})
	check(wf != null, "준비: 벽 너머 보스 층")
	if wf != null:
		var ws := ExplorationRules.new_game(Fx.defs(wf), 1, "full")
		ws.party.at = Vector2i(1, 0)
		ws.party.facing = Dir.E
		check_eq([FoeRules.boss_near(ws), ExplorationRules.question_here(ws), Fx.types(ExplorationRules.apply(ws, A.INVESTIGATE, "full")).has("boss")], ["", {}, false],
			"벽 너머 보스: 맞닿음·물음·조사 없음")
	var town := _game(Vector2i(5, 2), Dir.W, true, true)
	Fx.to_town(town)
	check_eq(FoeRules.boss_near(town), "", "마을에서는 없음")


# ---- R3 FIGHT ----

## R3 (M-R3a FIGHT 가 맞닿음을 보지 않음, M-R3b FIGHT 가 걸음·위험도를 씀, M-R3c 보스 무리의 no_escape 를 무시): FIGHT 는 맞닿은 보스와
## 접촉 전투(foe_contact·encounter, 보스 battle). 맞닿지 않으면 blocked no_boss. 도망칠 수 없다.
func test_fight() -> void:
	var far := _game(Vector2i(6, 2), Dir.W, true, true)
	var before := _clock(far)
	check_eq(_act(far, A.FIGHT), [{"type": "blocked", "reason": "no_boss"}] as Array[Dictionary], "떨어져 있으면 no_boss")
	check_eq([_clock(far), far.battle == null], [before, true], "그대로")
	var s := _game(Vector2i(5, 2), Dir.N, true, true)
	before = _clock(s)
	var ev := _act(s, A.FIGHT)
	check_eq(ev, [{"type": "foe_contact", "foe": "boss", "by": "party", "side": "front"},
		{"type": "encounter", "formation": "formation.boss.fenrir", "foe": "boss"}] as Array[Dictionary], "FIGHT: 접촉 전투(보스를 바라보지 않아도)")
	check_eq([_clock(s), s.encounter.pending, s.battle.foe, s.battle.no_escape, _boss_rec(s)[2]], [before, true, "boss", true, "battle"],
		"걸음·위험도·난수 그대로, 보스 전투, 도망칠 수 없음")
	check_eq(s.battle.enemies.map(func(u: BattleUnit) -> String: return u.def_id), ["enemy.boss_fenrir"], "적: 네온 펜리르 하나")
	check_eq(BattleRules.escape_block_reason(s, 0), "no_escape", "도주 막힘")
	check_eq(FoeRules.boss_near(s), "", "전투 중인 보스는 맞닿은 보스가 아니다")
	check_eq(_act(s, A.FIGHT)[0]["type"], "rejected", "전투 대기 중 FIGHT 는 받지 않는다")
	var dead := _game(Vector2i(5, 2), Dir.W, true, true)
	dead.world.foes["boss"].state = "defeated"
	check_eq(_act(dead, A.FIGHT), [{"type": "blocked", "reason": "no_boss"}] as Array[Dictionary], "쓰러진 보스와는 싸우지 않는다")


# ---- R4 전투 끝 ----

## R4 (M-R4a 승리에 보스를 쓰러뜨리지 않음, M-R4b 승리 경험치를 주지 않음): 승리면 보스 defeated(그날), battle_end.foes_defeated, 경험치 1500, 동력핵.
func test_victory() -> void:
	var s := _game(Vector2i(5, 2), Dir.W, true, true, 11)
	_level(s, 30)
	_act(s, A.FIGHT)
	var end := _fight_out(s, "full")
	check_eq([end.get("outcome"), end.get("foes_defeated"), end.get("exp_total")], ["victory", ["boss"], 1500], "승리 끝")
	check_eq(_boss_rec(s), [BOSS_AT, Dir.E, "defeated", 0, s.day], "보스 쓰러짐(그날)")
	check_eq([FoeRules.cleared(s), s.materials.get("item.fenrir_core", 0)], [["b3f"] as Array[String], 1], "클리어 기록·동력핵")
	check_eq([FoeRules.boss_near(s), ExplorationRules.question_here(s)], ["", {}], "쓰러진 보스는 물음이 없다")
	var ev := _act(s, A.FORWARD)
	check_eq([s.party.at, Fx.types(ev).has("boss")], [BOSS_AT, false], "쓰러진 보스 칸으로 걸어 들어간다")


## R4 (M-R4c 전멸에 보스가 battle 로 남음, M-R4d 턴 상한에 쉬지 않음): 전멸이면 보스는 그 자리에서 idle(쉬지 않음), 턴 상한(도주 끝)이면 idle·stun 2.
func test_wipe_and_turn_cap() -> void:
	var s := _game(Vector2i(5, 2), Dir.W, true, true, 3)
	for m in s.party.members:
		m.hp = 1
	_act(s, A.FIGHT)
	var end := _fight_out(s, "default")
	check_eq([end.get("outcome"), s.wiped, _boss_rec(s)], ["wiped", true, [BOSS_AT, Dir.E, "idle", 0, 0]], "전멸: 보스 idle")
	check_eq(FoeRules.cleared(s), [] as Array[String], "클리어 아님")
	var t := _game(Vector2i(5, 2), Dir.W, true, true)
	_act(t, A.FIGHT)
	var fin: Array[Dictionary] = []
	check(BattleRules.finish(t, "escaped", fin, "turn_cap"), "준비: 턴 상한 끝")
	check_eq([fin[-1]["reason"], _boss_rec(t)], ["turn_cap", [BOSS_AT, Dir.E, "idle", FoeRules.ESCAPE_STUN, 0]], "턴 상한: 보스 idle, 쉼 2")
	# 검토 L1 (M-R4w 전멸이 남은 쉼을 둔다): 턴 상한(쉼 2) 바로 뒤 FIGHT → 실제 전멸이면 보스는 idle·쉼 0.
	var re := _game(Vector2i(5, 2), Dir.W, true, true, 3)
	_act(re, A.FIGHT)
	var cap: Array[Dictionary] = []
	check(BattleRules.finish(re, "escaped", cap, "turn_cap") and re.world.foes["boss"].stun == FoeRules.ESCAPE_STUN, "준비: 턴 상한, 쉼 2")
	for m in re.party.members:
		m.hp = 1
	check_eq(_act(re, A.FIGHT)[-1]["type"], "encounter", "준비: 쉬는 보스와 바로 다시 싸운다")
	check_eq([re.battle.enemies[0].hp, re.world.foes["boss"].stun], [1800, FoeRules.ESCAPE_STUN], "준비: 새 보스(HP 가득), 쉼이 남은 채 전투")
	var rend := _fight_out(re, "default")
	check_eq([rend.get("outcome"), re.wiped, _boss_rec(re)], ["wiped", true, [BOSS_AT, Dir.E, "idle", 0, 0]], "다시 싸워 전멸: 보스 idle, 쉼 0")
	_act(t, A.TURN_RIGHT)
	_act(t, A.FORWARD)
	check_eq([t.party.at, _boss_rec(t)], [Vector2i(5, 1), [BOSS_AT, Dir.E, "idle", FoeRules.ESCAPE_STUN - 1, 0]], "쉬는 걸음은 줄지만 보스는 움직이지 않는다")


# ---- R5 기록 유지 ----

## R5 (M-R5a 층 들어서기가 쓰러진 보스를 되살림, M-R5b 날 바뀜이 되살림): 쓰러진 보스는 층 들어서기·날 바뀜·저장 왕복에도 쓰러진 채.
func test_defeated_persists() -> void:
	var s := _game(Vector2i(5, 2), Dir.W, true, true)
	s.world.foes["boss"].state = "defeated"
	s.world.foes["boss"].day = 1
	Fx.to_floor(s, "b3f", Vector2i(9, 2), Dir.W)
	check_eq(_boss_rec(s)[2], "defeated", "층 들어서기")
	s.day = 50
	check_eq([TownRules.new_day(s), _boss_rec(s)[2]], [[] as Array[Dictionary], "defeated"], "날 바뀜(50일째)")
	var r := SaveCodec.decode(SaveCodec.encode(s), _arbor())
	check(r.ok(), "저장 왕복 %s" % r.error)
	if r.ok():
		check_eq([r.state.world.foes["boss"].state, FoeRules.cleared(r.state)], ["defeated", ["b3f"] as Array[String]], "읽은 기록")
	# 살아 있는 보스는 층 들어서기에 처음 자리로(다른 FOE 와 같다).
	var t := _game(Vector2i(5, 2), Dir.W, true, true)
	t.world.foes["boss"].stun = 2
	Fx.to_floor(t, "b3f", Vector2i(9, 2), Dir.W)
	check_eq(_boss_rec(t), [BOSS_AT, Dir.E, "idle", 0, 0], "살아 있는 보스는 처음 상태")


# ---- R6 보스 방 ----

## R6 (M-R6a tick 이 보스를 움직임, M-R6b 방 위험도가 층 값, M-R6c 비콘이 방에서 됨): 보스는 움직이지도 돌지도 않고 맞닿아도 전투를 열지 않는다.
## 방에서는 위험도가 오르지 않고, 귀환 비콘은 sealed.
func test_room() -> void:
	var s := _game(Vector2i(9, 2), Dir.W, true, true)
	s.encounter.danger = 0
	var walk := [A.FORWARD, A.FORWARD, A.FORWARD, A.TURN_LEFT, A.FORWARD, A.TURN_RIGHT, A.FORWARD, A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT]
	var seen: Array[String] = []
	for a in walk:
		for e in _act(s, a):
			seen.append(e["type"])
		check_eq(_boss_rec(s), [BOSS_AT, Dir.E, "idle", 0, 0], "보스 그대로 (%s)" % str(s.party.at))
	check(not seen.has("foe_contact") and not seen.has("encounter") and not seen.has("foe_moved") and not seen.has("foe_turned"), "접촉·인카운트·FOE 이동 없음 %s" % str(seen))
	check_eq([s.encounter.danger, s.battle == null, s.steps > 0], [0, true, true], "방에서 걸어도 위험도 0")
	check_eq(ItemRules.return_block(s), "sealed", "방 안: 비콘 막힘")
	# 설계 §7.2: 보스 둘레에서 무작위 200 행동(시험 난수, 규칙 난수와 따로). 보스 기록은 한 번도 바뀌지 않는다.
	# 방 안에 머물도록 이 걷기 동안만 봉인을 닫는다(규칙 행동이 아닌 시험 준비, 플래그는 없앤다: 봉인을 다시 열지 않게).
	s.world.locks_open.erase(SEAL)
	s.flags.erase("permit.boss")
	var pick := RandomNumberGenerator.new()
	pick.seed = 20261030
	var moves := [A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT, A.TURN_LEFT, A.TURN_RIGHT, A.INVESTIGATE]
	var changed := 0
	var boss_events := 0
	for i in 200:
		var ev := _act(s, moves[pick.randi_range(0, moves.size() - 1)])
		boss_events += Fx.of_type(ev, "boss").size()
		if _boss_rec(s) != [BOSS_AT, Dir.E, "idle", 0, 0]:
			changed += 1
		check(s.battle == null and s.party.at != BOSS_AT, "200 행동 %d: 전투 없음, 보스 칸에 서지 않음" % i)
	check_eq([changed, s.encounter.danger], [0, 0], "200 행동: 보스 그대로, 위험도 0")
	check(boss_events > 0, "준비: 200 행동 가운데 보스 이벤트가 있었다 (%d)" % boss_events)
	var out := _game(Vector2i(9, 2), Dir.W, true, true)
	check_eq(ItemRules.return_block(out), "", "방 밖: 비콘 됨")
