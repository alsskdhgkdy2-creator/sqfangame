## 의뢰 규칙(M3 A8a, 설계 §4): 발급 조건·받기·포기·보고(한 번에)·반복·진행 세기(observe)·탐사 허가 계단·전투 끝 kills·결정성 J8.
## 실제 게임 묶음(Fx.arbor) 상태에서 실제 규칙 함수(ExplorationRules·BattleRules·TownRules)가 낸 이벤트를 observe 에 넘긴다.
## 시험마다 죽이는 변이(M-Q…)를 적는다. 기대값은 설계 §5.1·조정자 조건 1~5 의 글자 그대로다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const M1 := "mission.permit_b2f"
const M2 := "mission.boss_seal"
const SOUP := "quest.moss_soup"
const RAM := "quest.ether_ram"
const MOTH := "quest.moth_sweep"
const MOSS := "item.neon_moss"
## B1F 내려가는 계단(needs permit.b2f)과 그 앞 칸(계단의 exit W 쪽).
const STAIR := Vector2i(17, 1)
const BEFORE_STAIR := Vector2i(16, 1)
## J8: HEAD(cab5dd7) 코드로 /tmp/sqf_a8/gen_events.gd 가 만든 해시(A8 편집 전, git archive cab5dd7 → /tmp/sqf_a8/head).
## 시험 묶음·게임 묶음 × 시드 31·41, 전투 셋(J7 과 같은 길) + 전투마다 정규화한 state 의 sha256. [sha256, 길이].
const J8 := {
	"test 31": ["343071730cf28129bdcd34265adbe674c694102355d10241e2f846173371c74a", 41876],
	"test 41": ["fd712499cbc9af8e3ed015a95c697a5c019e0f88993b8a2a10f65707627f0f5a", 39037],
	"game 31": ["3263c53e32603663055c6f5e055be0b2e5a92310fefc090f86c71deb4d9ccbf5", 34115],
	"game 41": ["7e5c0efebc4e5ad38efde8200e3386fddca00ad170982d4fefea275dd90efc61", 38915],
}


func _defs() -> GameDefs:
	return Fx.arbor()


## 마을 새 게임(화면의 진짜 새 게임과 같은 길): 플래그 없음, 위험도 한계값은 멀리.
func _town(seed_value: int = 7) -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), seed_value, "full", true)
	s.encounter.threshold = 99999
	return s


func _q(id: String) -> QuestDb.QuestDef:
	return _defs().quests.quests[id]


## 마을에서 미궁 B1F 로 들어가 칸 c 에 방향 d 로 선다(시험 준비: 걸어가는 길은 걷기 시험이 본다).
func _enter_at(s: ExplorationState, c: Vector2i, d: int) -> void:
	var ev := ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")
	assert(ev[0]["type"] == "entered", str(ev))
	s.party.at = c
	s.party.facing = d


## 미궁에서 마을로(시험 준비: 마을 문 길은 test_town 이 본다).
func _to_town(s: ExplorationState) -> void:
	var first := s.defs.first_floor()
	s.enter_floor(first)
	s.party.at = first.start_at
	s.party.facing = first.start_facing
	s.location = ExplorationState.TOWN


func _types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])


func _of(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


## 의뢰 목록을 바꾼 새 게임 묶음 정의(fixture 의뢰를 쓰는 시험용, 공유 Fx.arbor 를 건드리지 않는다).
func _defs_with(list: Array) -> GameDefs:
	var r := GameDefs.load_paths(DungeonScreen.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", null)
	var q := QuestDb.parse_dict({"quests": list}, "fx.json")
	var floors: Array[FloorModel] = []
	for id in r.defs.floor_ids:
		floors.append(r.defs.floors[id])
	q.resolve(r.defs.battle, floors, null)
	assert(q.ok(), str(q.errors))
	# 계단 needs 는 실제 의뢰의 플래그라 fixture 목록에도 permit.b2f 를 주는 의뢰를 둔다(_fx_permit).
	r.defs.quests = q
	return r.defs


func _fx(id: String, objective: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "giver": "pub", "name_key": "quest.moss_soup", "desc_key": "quest.moss_soup.desc", "client_key": "quest.client.cook",
		"unlock": [], "objective": objective, "reward": {"money": 5, "exp": 0, "items": [], "flags": []}}
	d.merge(extra, true)
	return d


func _fx_permit() -> Dictionary:
	return {"id": "mission.fx_permit", "giver": "council", "name_key": "quest.permit_b2f", "desc_key": "quest.permit_b2f.desc", "client_key": "quest.client.council",
		"unlock": [], "objective": {"kind": "reach", "floor": "b1f", "at": [17, 1], "where_key": "quest.permit_b2f.where"},
		"reward": {"money": 0, "exp": 0, "items": [], "flags": ["permit.b2f"]}}


## 지금 층의 인카운트 전투를 formation 으로 열고, kill 칸의 적을 실제 피해로 쓰러뜨린다(처치 기록이 생긴다). 남은 적은 그대로.
func _battle_kill(s: ExplorationState, formation: String, kill: Array, foe: String = "") -> void:
	var st := BattleRules.start(s, formation, foe)
	assert(st[0]["type"] == "battle_start", str(st))
	var ev: Array[Dictionary] = []
	for i in kill:
		var u: BattleUnit = s.battle.enemies[i]
		BattleRules.damage_unit(s, u, u.hp, s.battle.party[0], "bash", "attack", ev, {})


# ---- 발급 조건 ----

## Q1 (M-Q1 reported 조건을 보지 않음, M-Q2 visited 가 지금 층을 봄, M-Q3 조건을 하나만 맞아도 됨): 실제 의뢰의 처음 상태와 열리는 때.
func test_unlock_conditions() -> void:
	var s := _town()
	check_eq([QuestRules.status_of(s, _q(M1)), QuestRules.status_of(s, _q(SOUP)), QuestRules.status_of(s, _q(RAM)), QuestRules.status_of(s, _q(MOTH)),
		QuestRules.status_of(s, _q(M2))], ["available", "available", "locked", "locked", "locked"], "새 게임: 첫 임무·이끼 수프만 받을 수 있다")
	check(QuestRules.is_new(s, _q(SOUP)) and not QuestRules.is_new(s, _q(RAM)), "받을 수 있고 처음인 것만 NEW")
	s.enter_floor(s.defs.floors["b2f"])  # b2f 기록을 만든다(다녀옴)
	_to_town(s)
	check_eq([QuestRules.status_of(s, _q(MOTH)), QuestRules.status_of(s, _q(M2))], ["available", "locked"], "B2F 를 다녀오면 나방 소탕이 열린다(지금 층은 B1F·마을)")
	s.enter_floor(s.defs.floors["b3f"])
	_to_town(s)
	check_eq(QuestRules.status_of(s, _q(M2)), "locked", "B3F 를 다녀와도 첫 임무를 보고하지 않았으면 봉인된 문은 잠김(조건 둘 다)")
	var e := QuestState.Entry.new()
	e.status = QuestState.REPORTED
	e.reports = 1
	e.day = 1
	s.quests.entries[M1] = e
	check_eq(QuestRules.status_of(s, _q(M2)), "available", "첫 임무 보고 + B3F 다녀옴: 봉인된 문이 열린다")
	check_eq(QuestRules.status_of(s, _q(RAM)), "locked", "이끼 수프를 보고하지 않았으면 에테르 램은 잠김")
	var t := _town()
	t.enter_floor(t.defs.floors["b3f"])
	_to_town(t)
	t.quests.entries[M1] = e.copy()
	t.floor_states.erase("b3f")
	check_eq(QuestRules.status_of(t, _q(M2)), "locked", "첫 임무만 보고, B3F 기록 없음: 잠김")


## Q1b (M-Q4 level 이 길드까지 셈, M-Q4b day 조건을 보지 않음): level·day 조건(실제 자료에는 없어 정의를 바로 만든다).
func test_level_and_day_conditions() -> void:
	var s := _town()
	var q := QuestDb.QuestDef.new()
	q.unlock = [{"kind": "level", "min": 2}]
	check(not QuestRules.conditions_met(s, q), "모두 Lv1: level 2 조건은 아니다")
	GrowthRules.grant_exp(s, 1, 30)
	check(s.party.members[1].level == 2 and QuestRules.conditions_met(s, q), "파티 칸 1 이 Lv2: 맞다")
	var ev := GuildRules.form(s, ["holo_knight", "blade_duelist_2"], ["nano_medic", "glyph_wizard"])
	check_eq(ev[0]["type"], "formed", "준비: Lv2 대원을 길드로 뺀다")
	check(not QuestRules.conditions_met(s, q), "Lv2 대원이 길드에만 있으면 아니다(파티만 센다)")
	var d := QuestDb.QuestDef.new()
	d.unlock = [{"kind": "day", "min": 3}]
	s.day = 2
	check(not QuestRules.conditions_met(s, d), "2일째: day 3 조건은 아니다")
	s.day = 3
	check(QuestRules.conditions_met(s, d), "3일째: 맞다")


# ---- 받기·포기 ----

## Q2 (M-Q24 시설을 보지 않음, M-Q21 임무 포기를 받음): 받기·포기 거부 이유와 받은 기록.
func test_accept_and_abandon_rules() -> void:
	var s := _town()
	check_eq(QuestRules.accept(s, SOUP, "council"), [{"type": "rejected", "reason": "wrong_giver"}] as Array[Dictionary], "정보상 바 의뢰를 관리국에서")
	check_eq(QuestRules.accept(s, "quest.nope", "pub"), [{"type": "rejected", "reason": "unknown_quest"}] as Array[Dictionary], "모르는 의뢰")
	check_eq(QuestRules.accept(s, RAM, "pub"), [{"type": "rejected", "reason": "locked"}] as Array[Dictionary], "잠긴 의뢰")
	check_eq(QuestRules.accept(s, SOUP, "pub"), [{"type": "quest_accepted", "quest": SOUP, "giver": "pub"}] as Array[Dictionary], "이끼 수프 받기")
	check_eq(QuestRules.accept(s, SOUP, "pub"), [{"type": "rejected", "reason": "already"}] as Array[Dictionary], "두 번 받기")
	check_eq(QuestRules.accept(s, M1, "council")[0]["type"], "quest_accepted", "첫 임무 받기")
	check_eq(QuestRules.abandon(s, M1, "council"), [{"type": "rejected", "reason": "no_abandon"}] as Array[Dictionary], "임무는 포기할 수 없다")
	check_eq(QuestRules.abandon(s, MOTH, "pub"), [{"type": "rejected", "reason": "not_accepted"}] as Array[Dictionary], "받지 않은 의뢰 포기")
	check_eq(QuestRules.abandon(s, SOUP, "pub"), [{"type": "quest_abandoned", "quest": SOUP}] as Array[Dictionary], "이끼 수프 포기")
	check(s.quests.entry(SOUP) == null and QuestRules.status_of(s, _q(SOUP)) == "available", "보고한 적 없이 포기: 기록이 지워지고 다시 받을 수 있다")
	_enter_at(s, Vector2i(9, 17), Dir.N)
	check_eq(QuestRules.accept(s, SOUP, "pub"), [{"type": "rejected", "reason": "not_town"}] as Array[Dictionary], "미궁에서 받기")
	check_eq(QuestRules.report(s, M1, "council"), [{"type": "rejected", "reason": "not_town"}] as Array[Dictionary], "미궁에서 보고")


# ---- 진행 세기 ----

## Q3 (M-Q5 받지 않은 의뢰도 셈, M-Q6 도주에도 셈, M-Q7 목표 위로 셈, M-Q29 kills 가 독으로 쓰러진 적을 뺌): 나방 소탕 kill.
func test_kill_counting() -> void:
	var s := _town()
	_enter_at(s, Vector2i(9, 17), Dir.N)
	var ev: Array[Dictionary] = []
	_battle_kill(s, "formation.b1.rats_moth", [0, 1, 2])
	BattleRules.finish(s, "victory", ev)
	check_eq(_of(ev, "battle_end")[0].get("kills"), ["enemy.neon_rat", "enemy.neon_rat", "enemy.cable_moth"], "kills: 쓰러뜨린 적의 정의 ID, 칸 차례")
	check_eq(QuestRules.observe(s, ev), [] as Array[Dictionary], "받은 의뢰가 없으면 아무것도 세지 않는다")
	_to_town(s)
	s.enter_floor(s.defs.floors["b2f"])
	_to_town(s)
	QuestRules.accept(s, MOTH, "pub")
	_enter_at(s, Vector2i(9, 17), Dir.N)
	check_eq(QuestRules.progress_of(s, _q(MOTH)), 0, "받기 전 나방은 세지 않았다")
	# 도주: 나방을 쓰러뜨렸어도 kills 가 없다.
	ev.clear()
	_battle_kill(s, "formation.b1.rats_moth", [2])
	BattleRules.finish(s, "escaped", ev)
	check(not _of(ev, "battle_end")[0].has("kills"), "도주의 battle_end 에는 kills 가 없다")
	check_eq([QuestRules.observe(s, ev), QuestRules.progress_of(s, _q(MOTH))], [[] as Array[Dictionary], 0], "도주: 세지 않는다")
	# 독으로 쓰러진 적(처치 기록이 있다)도 승리면 센다.
	ev.clear()
	BattleRules.start(s, "formation.b1.rats_moth")
	var moth: BattleUnit = s.battle.enemies[2]
	BattleRules.damage_unit(s, moth, moth.hp, null, "", "poison", ev, {})
	for i in [0, 1]:
		BattleRules.damage_unit(s, s.battle.enemies[i], s.battle.enemies[i].hp, s.battle.party[0], "bash", "attack", ev, {})
	ev.clear()
	BattleRules.finish(s, "victory", ev)
	var q := QuestRules.observe(s, ev)
	check_eq(q, [{"type": "quest_progress", "quest": MOTH, "progress": 1, "target": 4}] as Array[Dictionary], "독으로 쓰러진 나방 하나: 1/4")
	for k in 3:
		ev.clear()
		_battle_kill(s, "formation.b1.rats_moth", [0, 1, 2])
		BattleRules.finish(s, "victory", ev)
		q = QuestRules.observe(s, ev)
	check_eq([q, QuestRules.status_of(s, _q(MOTH))], [[{"type": "quest_done", "quest": MOTH}] as Array[Dictionary], "done"], "넷째 나방: 목표 달성")
	ev.clear()
	_battle_kill(s, "formation.b1.rats_moth", [0, 1, 2])
	BattleRules.finish(s, "victory", ev)
	check_eq([QuestRules.observe(s, ev), s.quests.entry(MOTH).progress], [[] as Array[Dictionary], 4], "달성 뒤에는 더 세지 않는다(4 에서 멈춤)")
	# 한 묶음이 목표를 넘어가도 목표 수에서 멈춘다(3/4 에서 나방 둘을 쓰러뜨린 battle_end 하나).
	s.quests.entry(MOTH).progress = 3
	var two: Array[Dictionary] = [{"type": "battle_end", "outcome": "victory", "kills": ["enemy.cable_moth", "enemy.cable_moth"]}]
	check_eq([QuestRules.observe(s, two), s.quests.entry(MOTH).progress], [[{"type": "quest_done", "quest": MOTH}] as Array[Dictionary], 4], "3/4 에서 둘: 달성, 4 에서 멈춤")


## Q4 (M-Q8 foe 가 FOE 자리 ID 를 정의 ID 와 견줌): 에테르 램 사냥(접촉 전투 승리 → foes_defeated f1 → foe.ether_ram).
func test_foe_counting() -> void:
	var s := _town()
	var e := QuestState.Entry.new()
	e.status = QuestState.REPORTED
	e.reports = 1
	e.day = 1
	s.quests.entries[SOUP] = e
	check_eq(QuestRules.accept(s, RAM, "pub")[0]["type"], "quest_accepted", "이끼 수프 보고 뒤 에테르 램 받기")
	_enter_at(s, Vector2i(11, 9), Dir.E)
	var ev: Array[Dictionary] = []
	_battle_kill(s, "formation.foe.ether_ram", [0], "f1")
	BattleRules.finish(s, "victory", ev)
	var end: Dictionary = _of(ev, "battle_end")[0]
	check_eq([end.get("foes_defeated"), end.get("kills")], [["f1"], ["enemy.foe_ether_ram"]], "battle_end: FOE 자리 f1, 적 정의")
	check_eq(QuestRules.observe(s, ev), [{"type": "quest_done", "quest": RAM}] as Array[Dictionary], "숫양 하나: 목표 달성")


## Q5 (M-Q9 reach 가 층을 보지 않음): 같은 x·y 라도 다른 층이면 세지 않는다. 받기 전 도착은 세지 않는다.
func test_reach_counting() -> void:
	var s := _town()
	_enter_at(s, BEFORE_STAIR, Dir.E)
	var ev := ExplorationRules.apply(s, ExplorationRules.Action.FORWARD, "full")
	check_eq(QuestRules.observe(s, ev), [] as Array[Dictionary], "받기 전 계단 칸 도착: 세지 않는다")
	_to_town(s)
	QuestRules.accept(s, M1, "council")
	_enter_at(s, Vector2i(9, 17), Dir.N)
	s.flags["permit.b2f"] = true
	s.enter_floor(s.defs.floors["b2f"])
	s.party.at = BEFORE_STAIR
	s.party.facing = Dir.E
	ev = ExplorationRules.apply(s, ExplorationRules.Action.FORWARD, "full")
	check(s.floor_def.id == "b2f" and s.party.at == STAIR, "준비: B2F 17:1(올라가는 계단)")
	check_eq([QuestRules.observe(s, ev), QuestRules.progress_of(s, _q(M1))], [[] as Array[Dictionary], 0], "B2F 의 17:1 은 B1F 목표가 아니다")


## Q6 (M-Q25 이미 넘은 deliver 가 얻을 때마다 달성을 다시 냄): deliver 는 세지 않고 가방에서 읽는다. 얻은 물건으로 넘을 때만 quest_done.
func test_deliver_progress() -> void:
	var s := _town()
	QuestRules.accept(s, SOUP, "pub")
	_enter_at(s, Vector2i(9, 17), Dir.N)
	BagRules.add(s, MOSS, 2)
	check_eq([QuestRules.progress_of(s, _q(SOUP)), QuestRules.status_of(s, _q(SOUP))], [2, "accepted"], "이끼 둘: 2/3")
	BagRules.add(s, MOSS, 2)
	var gathered: Array[Dictionary] = [{"type": "gathered", "point": "g1", "kind": "take", "items": [{"item": MOSS, "count": 2, "kept": 2}], "lost": 0, "left": 1, "uses": 2}]
	check_eq(QuestRules.observe(s, gathered), [{"type": "quest_done", "quest": SOUP}] as Array[Dictionary], "채집으로 2 → 4: 달성 알림")
	check_eq(QuestRules.observe(s, [] as Array[Dictionary]), [] as Array[Dictionary], "얻은 것이 없는 묶음: 다시 알리지 않는다")
	check_eq([QuestRules.progress_of(s, _q(SOUP)), s.quests.entry(SOUP).progress], [3, 0], "진행 표시는 목표 수에서 멈추고 기록은 0")
	BagRules.add(s, MOSS, 1)
	var more: Array[Dictionary] = [{"type": "gathered", "point": "g1", "kind": "take", "items": [{"item": MOSS, "count": 1, "kept": 1}], "lost": 0, "left": 0, "uses": 1}]
	check_eq(QuestRules.observe(s, more), [] as Array[Dictionary], "이미 넘은 뒤 더 얻음(4 → 5): 다시 알리지 않는다")
	BagRules.take(s, MOSS, 1)
	BagRules.take(s, MOSS, 2)
	check_eq(QuestRules.status_of(s, _q(SOUP)), "accepted", "둘을 버리면 다시 모자람(목표 달성이 풀린다)")
	BagRules.add(s, MOSS, 1)
	var drop: Array[Dictionary] = [{"type": "battle_end", "outcome": "victory", "drops": [{"item": MOSS, "amount": 1, "capped": false, "enemy": 0}]}]
	check_eq(QuestRules.observe(s, drop), [{"type": "quest_done", "quest": SOUP}] as Array[Dictionary], "드롭으로 다시 넘음: 달성 알림")


# ---- 탐사 허가 계단 (조정자 조건 1·2) ----

## Q7 (M-Q26 허가 없는 계단을 막지 않음, M-Q27 미궁 시작이 허가를 받지 않음, M-Q28 마을 새 게임이 허가를 받음):
## 마을 새 게임은 플래그가 없고, 계단 칸에 설 수 있고 첫 임무의 도착은 세지만 물음 대신 blocked no_permit, STAIRS 도 막힌다.
## 보고하면 같은 칸이 보통 계단 물음을 낸다. 미궁 시작 새 게임은 처음부터 허가가 있다.
func test_permit_gate_and_reach() -> void:
	var s := _town()
	check_eq(s.flags, {}, "마을 새 게임: 플래그 없음")
	var lab := ExplorationRules.new_game(_defs(), 7, "full")
	check_eq(lab.flags, {"permit.b2f": true}, "미궁 시작 새 게임: 계단 허가를 처음부터")
	check_eq(ExplorationRules.new_game(Fx.defs(), 7, "full").flags, {}, "시험 묶음 미궁 시작: 막힌 계단이 없어 플래그 없음")
	QuestRules.accept(s, M1, "council")
	_enter_at(s, BEFORE_STAIR, Dir.E)
	var ev := ExplorationRules.apply(s, ExplorationRules.Action.FORWARD, "full")
	check_eq(s.party.at, STAIR, "계단 칸에 선다")
	check(_of(ev, "stairs").is_empty() and _of(ev, "blocked") == [{"type": "blocked", "reason": "no_permit"}], "물음 대신 no_permit %s" % str(ev))
	check(ExplorationRules.stair_here(s).is_empty() and ExplorationRules.question_here(s).is_empty(), "화면 물음 입구도 비었다")
	check_eq(QuestRules.observe(s, ev), [{"type": "quest_done", "quest": M1}] as Array[Dictionary], "첫 임무 도착은 센다")
	ev = ExplorationRules.apply(s, ExplorationRules.Action.STAIRS, "full")
	check_eq([ev, s.floor_def.id], [[{"type": "blocked", "reason": "no_permit"}] as Array[Dictionary], "b1f"], "STAIRS 도 막힌다")
	ev = ExplorationRules.apply(s, ExplorationRules.Action.INVESTIGATE, "full")
	check_eq(ev, [{"type": "blocked", "reason": "no_permit"}] as Array[Dictionary], "조사해도 no_permit")
	_to_town(s)
	var rep := QuestRules.report(s, M1, "council")
	check_eq([_of(rep, "quest_reported").size(), s.flags], [1, {"permit.b2f": true}], "보고: 허가 플래그")
	_enter_at(s, STAIR, Dir.W)
	ev = ExplorationRules.apply(s, ExplorationRules.Action.INVESTIGATE, "full")
	check_eq(ev, [{"type": "stairs", "way": "down", "to": "b2f"}] as Array[Dictionary], "보고 뒤 같은 칸: 보통 계단 물음")
	ev = ExplorationRules.apply(s, ExplorationRules.Action.STAIRS, "full")
	check_eq([_types(ev), s.floor_def.id], [["floor_changed"], "b2f"], "내려간다")


# ---- 보고 (조정자 조건 4) ----

## Q8 (M-Q14 경험치를 나눔, M-Q15 쓰러진 대원에게도, M-Q16 레벨업 이벤트가 없음, M-Q17 플래그를 주지 않음, M-Q18 reports 를 올리지 않음):
## 첫 임무 보고: 살아 있는 파티 대원마다 경험치 30 전부(Lv1 → Lv2), 쓰러진 대원·상한 대원·길드 대원은 받지 않는다.
func test_report_rewards() -> void:
	var s := _town()
	GuildRules.register(s, "class.nano_medic", 0, "길드메딕")
	QuestRules.accept(s, M1, "council")
	var e := s.quests.entry(M1)
	e.progress = 1
	s.party.members[3].hp = 0
	var cap := s.defs.battle.growth.level_cap
	GrowthRules.grant_exp(s, 4, 999999)
	check_eq(s.party.members[4].level, cap, "준비: 칸 4 는 상한")
	var money := s.money
	var ev := QuestRules.report(s, M1, "council")
	var rep: Dictionary = _of(ev, "quest_reported")[0]
	check_eq(rep["members"].map(func(r: Dictionary) -> Array: return [r["member"], r["status"], r["gained"], r["from"], r["to"]]),
		[[0, "received", 30, 1, 2], [1, "received", 30, 1, 2], [2, "received", 30, 1, 2], [3, "down", 0, 1, 1], [4, "at_cap", 0, cap, cap]],
		"살아 있는 대원마다 30 전부·레벨 2, 쓰러진 대원 0, 상한 대원 0")
	check_eq(_of(ev, "level_up").map(func(x: Dictionary) -> Array: return [x["member"], x["from"], x["to"]]), [[0, 1, 2], [1, 1, 2], [2, 1, 2]], "레벨업 이벤트 셋")
	check_eq([s.party.members[3].exp, s.guild.members[0].exp, s.guild.members[0].level], [0, 0, 1], "쓰러진 대원·길드 대원은 그대로")
	check_eq([s.money, s.flags, e.status, e.reports, e.day, e.progress], [money + 100, {"permit.b2f": true}, "reported", 1, 1, 0], "돈 +100·허가·보고 기록")
	check_eq(_types(ev).back(), "quest_reported", "quest_reported 가 마지막(경험치 이벤트 뒤)")
	check_eq([QuestRules.report(s, M1, "council"), QuestRules.status_of(s, _q(M1))], [[{"type": "rejected", "reason": "not_accepted"}] as Array[Dictionary], "finished"],
		"두 번 보고하지 않는다, 반복 없음")


## Q9 (M-Q11 not_done 을 보지 않음, M-Q12 건네기 전에 가방을 봄, M-Q13 가방이 모자라도 일부 보수, M-Q13b money_full 을 보지 않음):
## 가방·돈 거부는 아무것도 바꾸지 않는다(상태 해시 그대로).
func test_report_bag_and_money() -> void:
	var s := _town()
	QuestRules.accept(s, SOUP, "pub")
	check_eq(QuestRules.report(s, SOUP, "pub"), [{"type": "rejected", "reason": "not_done"}] as Array[Dictionary], "이끼가 없으면 not_done")
	BagRules.add(s, MOSS, 3)
	BagRules.add(s, "item.scrap_wire", BagRules.SLOTS - BagRules.used(s))
	check_eq(BagRules.used(s), 60, "준비: 60/60(이끼 3 포함)")
	var ev := QuestRules.report(s, SOUP, "pub")
	check(_of(ev, "quest_reported").size() == 1, "건넨 3 칸에 보수 메디카 2 가 들어간다 %s" % str(ev))
	check_eq([s.materials.get(MOSS, 0), s.consumables.get("use.medica", 0), BagRules.used(s)], [0, 2, 59], "이끼 0·메디카 2·59 칸")
	var t := _town()
	t.enter_floor(t.defs.floors["b2f"])
	_to_town(t)
	QuestRules.accept(t, MOTH, "pub")
	t.quests.entry(MOTH).progress = 4
	BagRules.add(t, "item.scrap_wire", BagRules.SLOTS - 1)
	var before := SaveCodec.state_hash(t)
	check_eq(QuestRules.report(t, MOTH, "pub"), [{"type": "rejected", "reason": "bag_full"}] as Array[Dictionary], "빈 칸 1 에 테리아카 2: bag_full")
	check_eq(SaveCodec.state_hash(t), before, "bag_full: 아무것도 바뀌지 않았다")
	BagRules.take(t, "item.scrap_wire", 1)
	t.money = BattleLimits.MONEY_MAX - 149
	before = SaveCodec.state_hash(t)
	check_eq(QuestRules.report(t, MOTH, "pub"), [{"type": "rejected", "reason": "money_full"}] as Array[Dictionary], "돈 +150 이 상한을 넘으면 money_full")
	check_eq(SaveCodec.state_hash(t), before, "money_full: 아무것도 바뀌지 않았다")


## Q10 (조정자 조건 4, M-Q30 보고가 저장 왕복 뒤 되풀이됨): 보고 전 저장은 목표 달성·물건 그대로, 보고 뒤 저장은 다시 보수를 주지 않는다.
func test_report_atomic_with_save() -> void:
	var s := _town()
	QuestRules.accept(s, SOUP, "pub")
	BagRules.add(s, MOSS, 3)
	var pre := SaveCodec.encode(s)
	QuestRules.report(s, SOUP, "pub")
	var post := SaveCodec.encode(s)
	var a := SaveCodec.decode(pre, s.defs)
	check(a.ok() and QuestRules.status_of(a.state, _q(SOUP)) == "done" and a.state.materials.get(MOSS, 0) == 3 and a.state.consumables.is_empty(),
		"보고 전 저장: 목표 달성·이끼 3·보수 없음 %s" % a.error)
	var b := SaveCodec.decode(post, s.defs)
	check(b.ok(), "보고 뒤 저장 읽기 %s" % b.error)
	if b.ok():
		var money := b.state.money
		check_eq([QuestRules.report(b.state, SOUP, "pub"), b.state.money, b.state.consumables, b.state.materials.get(MOSS, 0)],
			[[{"type": "rejected", "reason": "not_accepted"}] as Array[Dictionary], money, {"use.medica": 2}, 0], "보고 뒤 읽은 상태: 다시 보고·보수 없음")


## Q13 (M-Q31 보고 수가 상한을 넘음): 보고 수 9999 인 이끼 수프를 실제 보고 길로 다시 보고하면 보고·보수는 그대로 받고 보고 수는 9999 에서 멈춘다.
## 그 상태를 SaveStore 로 쓰고 다시 읽을 수 있다(검토 M3 A8a 2: 10000 번째 보고 뒤 저장할 수 없게 되지 않는다).
func test_report_count_saturates() -> void:
	var s := _town()
	s.day = 10000
	var e := QuestState.Entry.new()
	e.reports = QuestState.REPORTS_MAX
	e.day = 9999
	s.quests.entries[SOUP] = e
	BagRules.add(s, MOSS, 3)
	var money := s.money
	var rep := QuestRules.report(s, SOUP, "pub")
	check_eq([rep.back()["type"], s.money, s.consumables.get("use.medica", 0), s.materials.get(MOSS, 0)], ["quest_reported", money + 60, 2, 0],
		"보고 9999 번 뒤의 보고: 받고 보수도 준다")
	check_eq([e.status, e.reports, e.day], ["reported", 9999, 10000], "보고 수는 9999 에서 멈추고 날은 오늘")
	Fx.clean_saves()
	var store := SaveStore.new(s.defs, Fx.SAVE_DIR)
	check_eq(store.save(SaveStore.AUTO, s), "", "SaveStore 쓰기")
	var l := store.load_slot(SaveStore.AUTO)
	check(l.ok(), "SaveStore 다시 읽기 %s" % str(l.failures))
	if l.ok():
		var r := l.result.state.quests.entry(SOUP)
		check_eq([r.status, r.reports, r.day, SaveCodec.state_hash(l.result.state)], ["reported", 9999, 10000, SaveCodec.state_hash(s)], "읽은 기록: 9999 그대로, 같은 해시")
	Fx.clean_saves()


# ---- 반복 (조정자 조건 3) ----

## Q11 (M-Q19 반복이 같은 날 열림, M-Q20 다시 받아도 진행이 남음, M-Q23 반복 의뢰 포기가 보고 수를 지움):
## 이끼 수프: 보고 → cooling(여는 날 2) → 여관 하룻밤 → 받을 수 있음(NEW 아님) → 진행 0 으로 다시 받기. 첫 보고 뒤 포기는 reported·날 그대로·식는 날 그대로.
func test_repeat_cycle() -> void:
	var s := _town()
	QuestRules.accept(s, SOUP, "pub")
	BagRules.add(s, MOSS, 3)
	QuestRules.report(s, SOUP, "pub")
	check_eq([QuestRules.status_of(s, _q(SOUP)), QuestRules.opens_on(s, _q(SOUP)), s.day], ["cooling", 2, 1], "보고한 날: 식는 중, 2일째에 연다")
	check_eq(QuestRules.accept(s, SOUP, "pub"), [{"type": "rejected", "reason": "cooling", "opens": 2}] as Array[Dictionary], "식는 중에는 cooling(여는 날)")
	check_eq(QuestRules.status_of(s, _q(RAM)), "available", "이끼 수프 보고로 에테르 램이 열린다")
	s.money = 1000
	var stay := TownRules.stay(s)
	check_eq([_types(stay).back(), s.day, QuestRules.status_of(s, _q(SOUP)), QuestRules.is_new(s, _q(SOUP))], ["stayed", 2, "available", false],
		"여관 하룻밤: 2일째, 다시 받을 수 있다(NEW 아님)")
	check_eq(QuestRules.accept(s, SOUP, "pub")[0]["type"], "quest_accepted", "다시 받기")
	var e := s.quests.entry(SOUP)
	check_eq([e.status, e.progress, e.reports, e.day, QuestRules.progress_of(s, _q(SOUP))], ["accepted", 0, 1, 1, 0], "진행 0·보고 1·마지막 보고 1일째")
	check_eq(QuestRules.abandon(s, SOUP, "pub"), [{"type": "quest_abandoned", "quest": SOUP}] as Array[Dictionary], "첫 보고 뒤 포기")
	check_eq([e.status, e.reports, e.day, QuestRules.opens_on(s, _q(SOUP)), QuestRules.status_of(s, _q(SOUP))], ["reported", 1, 1, 2, "available"],
		"포기: reported, 보고 1·날 1 그대로, 여는 날 2 그대로")
	check(s.quests.entry(SOUP) == e, "기록은 지우지 않는다")


## Q12 (M-Q22 포기가 진행을 남김, M-Q20 다시 받아도 진행이 남음): 반복하는 kill 의뢰(fixture)의 진행은 포기·다시 받기에서 0.
func test_abandon_and_reaccept_reset_progress() -> void:
	var d := _defs_with([_fx_permit(), _fx("quest.fx_moth", {"kind": "kill", "enemy": "enemy.cable_moth", "count": 3}, {"repeat": {"days": 0}})])
	var s := ExplorationRules.new_game(d, 7, "full", true)
	s.encounter.threshold = 99999
	QuestRules.accept(s, "quest.fx_moth", "pub")
	_enter_at(s, Vector2i(9, 17), Dir.N)
	var ev: Array[Dictionary] = []
	_battle_kill(s, "formation.b1.rats_moth", [0, 1, 2])
	BattleRules.finish(s, "victory", ev)
	QuestRules.observe(s, ev)
	check_eq(s.quests.entry("quest.fx_moth").progress, 1, "나방 하나: 1")
	_to_town(s)
	QuestRules.abandon(s, "quest.fx_moth", "pub")
	QuestRules.accept(s, "quest.fx_moth", "pub")
	check_eq(s.quests.entry("quest.fx_moth").progress, 0, "포기 → 다시 받기: 0")
	s.quests.entry("quest.fx_moth").progress = 3
	QuestRules.report(s, "quest.fx_moth", "pub")
	check_eq(QuestRules.status_of(s, s.defs.quests.quests["quest.fx_moth"]), "available", "days 0: 보고하자마자 다시 받을 수 있다")
	QuestRules.accept(s, "quest.fx_moth", "pub")
	check_eq([s.quests.entry("quest.fx_moth").progress, s.quests.entry("quest.fx_moth").reports], [0, 1], "다시 받기: 진행 0, 보고 1")
	# 보고한 적이 있는 의뢰의 포기: 기록은 reported 로 남고 진행은 0, 다시 받아도 0.
	_enter_at(s, Vector2i(9, 17), Dir.N)
	ev.clear()
	_battle_kill(s, "formation.b1.rats_moth", [2])
	BattleRules.finish(s, "victory", ev)
	QuestRules.observe(s, ev)
	_to_town(s)
	var e := s.quests.entry("quest.fx_moth")
	check_eq(e.progress, 1, "다시 받은 뒤 나방 하나: 1")
	QuestRules.abandon(s, "quest.fx_moth", "pub")
	check_eq([e.status, e.progress, e.reports], ["reported", 0, 1], "보고한 적 있는 포기: reported, 진행 0, 보고 1")
	QuestRules.accept(s, "quest.fx_moth", "pub")
	check_eq([e.status, e.progress], ["accepted", 0], "포기 → 다시 받기: 0")


# ---- 결정성 J8 (조정자 조건 5) ----

## J8 (M-J8 kills 를 위해 난수를 더 뽑음 / 다른 이벤트를 바꿈): 의뢰를 받지 않은 전투는 HEAD 와 사건·난수·상태가 같다.
## battle_end 의 kills 만 빼고 견주고(조정자 답 seq=3), kills 는 따로 본다: 승리에만, 처치 기록이 있는 적의 정의 ID 칸 차례.
func test_j8_events_match_head() -> void:
	timeout_sec = 120.0
	for pair in [["test", Fx.defs()], ["game", Fx.arbor()]]:
		for sd in [31, 41]:
			var t := _j8_text(pair[1], sd)
			var key := "%s %d" % [pair[0], sd]
			check_eq([t.sha256_text(), t.length()], J8[key], "J8 %s: HEAD 사건·상태 해시·길이(kills 뺌)" % key)


## /tmp/sqf_a8/gen_events.gd 와 같은 길. 제출 전 적 유닛을 잡아 두고, battle_end 의 kills 를 견준 뒤 빼고 잇는다. state 는 quests·flags 를 뺀 사전.
func _j8_text(defs: GameDefs, seed_value: int) -> String:
	var s := ExplorationRules.new_game(defs, seed_value, "full")
	s.location = ExplorationState.LABYRINTH
	var text := ""
	for k in 3:
		s.encounter.danger = s.encounter.threshold
		var st := BattleRules.start(s, BattleRules.pick_formation(s))
		text += Fx.events_text(st)
		var turns := 0
		while s.battle != null and turns < 60:
			var units := s.battle.enemies.duplicate()
			text += Fx.events_text(_strip_kills(BattleRules.submit(s, BattlePolicy.choose(s, "default")), units))
			turns += 1
		if s.battle != null:
			var units := s.battle.enemies.duplicate()
			var fe: Array[Dictionary] = []
			BattleRules.finish(s, "escaped", fe)
			text += Fx.events_text(_strip_kills(fe, units))
		var sd := SaveCodec.state_to_dict(s)
		sd.erase("quests")
		sd.erase("flags")
		text += "|rng=%s|wiped=%s|state=%s|" % [str(s.rng.get_state()), str(s.wiped), JSON.stringify(sd, "", true).sha256_text()]
		if s.wiped:
			break
		for m in s.party.members:
			m.hp = m.max_hp
			m.tp = m.max_tp
	return text


## 이벤트 열의 사본에서 battle_end.kills 를 뺀다. 빼기 전에 kills 가 승리에만 있고 units(제출 전 적, 합류한 적 포함은 제출 뒤 battle 에서) 의
## 처치 기록 있는 적의 정의 ID(칸 차례)와 같은지 본다.
func _strip_kills(events: Array[Dictionary], units: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in events:
		if ev["type"] != "battle_end":
			out.append(ev)
			continue
		var want: Array = []
		if ev["outcome"] == "victory":
			for u in units:
				if not u.kill.is_empty():
					want.append(u.def_id)
		if want.is_empty():
			check(not ev.has("kills"), "kills 없음(%s, 처치 없음 또는 승리 아님)" % ev["outcome"])
		else:
			check_eq(ev.get("kills"), want, "kills = 처치 기록 있는 적의 정의 ID(칸 차례)")
		var c: Dictionary = ev.duplicate(true)
		c.erase("kills")
		out.append(c)
	return out
