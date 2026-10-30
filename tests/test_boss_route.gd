## 보스 공략(M3 A9a 설계 §4.5·§8, A10 갈고리): 마을 새 게임 → 관리국 임무 둘(실제 의뢰 규칙) → arbor_route.json → arbor_boss_route.json
## → 봉인 열기 → 보스에 부딪힘(boss) → FIGHT → 승리 → 클리어(T1). HEAD 와 같은 공략 걷기(조정자 조건 4, T2). 시험마다 죽이는 변이(M-T…)를 적는다.
##
## T2 의 기준 값은 HEAD 77190fd 코드(git archive → /tmp/sqf_a9/head, 먼저 --import)로 저장소 밖 생성기가 만들었다(M3 A3c 에서 다시 만듦):
##   cd /tmp && GODOT_SILENCE_ROOT_WARNING=1 flock /tmp/sqfangame-godot.lock timeout 300 godot --headless --path /tmp/sqf_a9/head -s /tmp/sqf_a3c/gen_route_head_a3c.gd
## 미궁 새 게임(시드 31·41)으로 arbor_route.json 행동마다 이벤트 글(전투 대기면 승리로 끝낸 이벤트, battle_end.kills 는 뺌)과 상태 사전 해시를 이은 글의
## sha256·길이다. 지금 코드는 상태 사전에서 B3F 보스 기록만 이름으로 빼고(Fx.strip_v13, 처음 상태인지 본다) 같은 글을 만든다.
## M3 A3c: B2F/B3F 출현 표에 새 편성이 늘어 같은 난수가 다른 편성을 뽑는다. 편성에서 오는 세 사건 필드(Fx.strip_picks)만 양쪽에서 이름으로 빼고 해시를 다시 만들었다
## (사건 나머지와 상태 해시, 난수는 HEAD 와 바이트까지 같다). 새 뽑기 열은 NEW_PICKS 에 리터럴로 따로 박았다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const BOSS_ROUTE := "res://data/floors/arbor_boss_route.json"
const ROUTE := "res://data/floors/arbor_route.json"
const HEAD_ROUTE := {31: ["57858354f07c65b0687010e1550ae05eb9690bada41de6f5da43e5b8dbb25b4e", 31527],
	41: ["2debc3e124a7ce22068e7b05c84cc0cca2fcd1c6bde69ef1513d594a4d331e85", 32230]}
## 고정 공략의 새 뽑기(M3 A3c, 출현 표 B1F 100 그대로, B2F·B3F 130): 시드 31·41 의 encounter 사건 편성 열. B1F 뽑기(첫 칸)는 HEAD 와 같다.
const NEW_PICKS := {
	31: ["formation.b1.serpent_rat", "formation.b2.serpent_moles", "formation.b2.serpent_moles", "formation.b2.moths_beetle", "formation.b2.moths_beetle",
		"formation.b3.beetle_moles", "formation.b3.moles_moths", "formation.b3.wisps_moles"],
	41: ["formation.b1.rats_moth", "formation.b2.moles_bloom", "formation.b2.serpent_moles", "formation.b2.moles_bloom", "formation.b2.firefly_serpents",
		"formation.b2.wisp_moles", "formation.b3.wisps_moles", "formation.b3.moles_moths", "formation.b3.beetle_moles"]}

var _defs: GameDefs


func _arbor() -> GameDefs:
	if _defs == null:
		_defs = Fx.arbor()
	return _defs


## T0: 보스 공략 파일 형식(설계 §8, 조정자 후속: 부딪힘 한 번 뒤 fight).
func test_route_file() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOSS_ROUTE))
	check_eq(d.keys().filter(func(k: String) -> bool: return not ["note", "from", "needs_flags", "actions", "checkpoints"].has(k)), [], "아는 키만")
	check_eq([d["from"], d["needs_flags"], d["actions"]], [{"floor": "b3f", "at": [9.0, 2.0], "facing": "W"}, ["permit.boss"],
		["forward", "forward", "forward", "forward", "forward", "forward", "fight"]], "출발·필요 플래그·행동")
	for a in d["actions"]:
		check(ExplorationRules.ACTION_NAMES.has(a), "아는 행동 %s" % a)
	check_eq(d["checkpoints"].map(func(c: Dictionary) -> Array: return [int(c["after"]), c["floor"], c["at"]]),
		[[1, "b3f", [9.0, 2.0]], [5, "b3f", [5.0, 2.0]], [6, "b3f", [5.0, 2.0]], [7, "b3f", [5.0, 2.0]]], "체크포인트")
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))
	var last: Dictionary = route["checkpoints"][-1]
	check_eq([last["floor"], last["at"]], [d["from"]["floor"], d["from"]["at"]], "보스 공략은 arbor_route.json 끝(봉인 앞)에서 시작한다")


## T1 (M-T1 보스 부딪힘이 바로 전투, M-T2 봉인이 needs 없이 열림은 R1 이 본다): 마을 새 게임에서 클리어까지(시드 셋). 공략 전투는 이겼다고 친다.
func test_full_route_to_clear() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOSS_ROUTE))
	var acts: Array = d["actions"]
	var cps := {}
	for c in d["checkpoints"]:
		cps[int(c["after"])] = Vector2i(int(c["at"][0]), int(c["at"][1]))
	var want_types := {1: "seal_opened", 2: "moved", 5: "moved", 6: "boss", 7: "encounter"}
	for sd in [31, 41, 7]:
		var s := Fx.walk_to_boss(_arbor(), sd)
		check_eq([s.floor_def.id, s.party.at, s.party.facing, s.flags.keys().has("permit.boss"), s.location], ["b3f", Vector2i(9, 2), Dir.W, true, ExplorationState.LABYRINTH],
			"시드 %d: 봉인 앞, 허가 있음" % sd)
		check_eq([QuestRules.status_of(s, s.defs.quests.quests["mission.permit_b2f"]), QuestRules.status_of(s, s.defs.quests.quests["mission.boss_seal"])],
			["finished", "finished"], "시드 %d: 임무 둘 보고" % sd)
		for i in acts.size():
			var ev := ExplorationRules.apply(s, ExplorationRules.action_from_name(acts[i]), "full")
			QuestRules.observe(s, ev)
			var n := i + 1
			if want_types.has(n):
				check(Fx.types(ev).has(want_types[n]), "시드 %d 행동 %d: %s %s" % [sd, n, want_types[n], str(Fx.types(ev))])
			if cps.has(n):
				check_eq([s.floor_def.id, s.party.at], ["b3f", cps[n]], "시드 %d 체크포인트 %d" % [sd, n])
			if n == 6:
				check(s.battle == null and not s.encounter.pending, "시드 %d: 부딪힘은 전투가 아니다" % sd)
		check(s.battle != null and s.battle.foe == "boss" and s.battle.no_escape, "시드 %d: 보스 전투" % sd)
		var fin: Array[Dictionary] = []
		check(BattleRules.finish(s, "victory", fin), "시드 %d: 승리로 끝냄" % sd)
		QuestRules.observe(s, fin)
		check_eq([FoeRules.cleared(s), s.world.foes["boss"].state, s.world.foes["boss"].day], [["b3f"] as Array[String], "defeated", s.day], "시드 %d: 클리어" % sd)
		var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
		check(r.ok() and FoeRules.cleared(r.state) == (["b3f"] as Array[String]), "시드 %d: 클리어 저장 왕복 %s" % [sd, r.error])


## T2 (조정자 조건 4, M-T3 보스가 tick 에서 돈다·움직인다): HEAD 와 같은 공략 걷기. 이벤트는 바이트까지 같고 상태는 B3F 보스 기록(처음 상태)만 다르다.
func test_route_matches_head() -> void:
	var acts: Array = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))["actions"]
	for sd in HEAD_ROUTE:
		var defs := Fx.arbor()
		var s := ExplorationRules.new_game(defs, sd, "full")
		var text := ""
		var bad := ""
		var picks: Array[String] = []
		for a in acts:
			var step := ExplorationRules.apply(s, ExplorationRules.action_from_name(a), "full")
			for e in step:
				if e["type"] == "encounter":
					picks.append(e["formation"])
			text += Fx.events_text(Fx.strip_picks(step))
			if s.encounter.pending:
				var fe: Array[Dictionary] = []
				BattleRules.finish(s, "victory", fe)
				for ev in fe:
					if ev["type"] == "battle_end":
						ev.erase("kills")
				text += Fx.events_text(Fx.strip_picks(fe))
			var st := Fx.strip_v13(SaveCodec.state_to_dict(s), defs)
			if bad.is_empty() and not st["bad"].is_empty():
				bad = st["bad"]
			text += "|%s|" % JSON.stringify(st["state"], "", true).sha256_text()
		check_eq(bad, "", "시드 %d: 보스 기록은 늘 처음 상태" % sd)
		check_eq([text.sha256_text(), text.length()], HEAD_ROUTE[sd], "시드 %d: HEAD 77190fd 와 같은 이벤트·상태(편성에서 오는 세 필드만 뺌)" % sd)
		check_eq(picks, NEW_PICKS[sd], "시드 %d: 새 표의 뽑기 열(리터럴)" % sd)
		for p in picks:
			check(s.defs.battle.table_formations("encounter." + p.split(".")[1] + "f").has(p), "시드 %d: %s 는 그 층 출현 표의 편성" % [sd, p])


## T4 (M-T4 고정 저장이 봉인 앞이 아님, M-T5 한 값이 어긋남): 웹 확인 J 의 고정 저장(tools/web_check_boss_save.json, tools/make_boss_save.gd 가 실제 공략으로 만든다)이
## 지금 정의로 읽히고(13판), B3F (9,2) 서쪽 = 봉인 앞, 봉인 임무 보고(permit.boss), 봉인 닫힘, 보스 idle, 대원 모두 Lv 10 이다(조용히 낡지 않게).
## 파일 전체가 만드는 쪽(tools/make_boss_save.gd)이 지금 코드로 다시 만든 글과 바이트까지 같다(HP·TP·경험치·돈·가방 등이 어긋나지 않게).
func test_web_boss_fixture() -> void:
	timeout_sec = 60.0
	var defs := _arbor()
	var text := FileAccess.get_file_as_string("res://tools/web_check_boss_save.json")
	var r := SaveCodec.decode(text, defs)
	check(r.ok(), "고정 저장이 읽힌다 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	var doc: Dictionary = JSON.parse_string(text)
	check_eq([doc["schema"], doc["rules"], r.from_schema], [13.0, "m3b", 13], "13판 m3b")
	check_eq([s.location, s.floor_def.id, s.party.at, s.party.facing], [ExplorationState.LABYRINTH, "b3f", Vector2i(9, 2), Dir.W], "B3F (9,2) 서쪽 = 봉인 앞")
	check_eq([s.flags.has("permit.boss"), s.quests.reports_of("mission.boss_seal"), s.world.is_lock_open(Vector3i(9, 2, 1))], [true, 1, false],
		"봉인 임무 보고, 봉인 닫힘")
	check_eq([s.world.foes["boss"].state, s.world.foes["boss"].stun, FoeRules.cleared(s)], ["idle", 0, []], "보스 idle, 클리어 없음")
	check_eq(s.party.members.map(func(m: PartyState.Member) -> int: return m.level), [10, 10, 10, 10, 10], "대원 모두 Lv 10")
	# M3 A9b 보완 F5 (M-T5 고정 저장의 한 값이 만드는 쪽과 어긋남): 파일 전체 = 만드는 쪽(tools/make_boss_save.gd)이 지금 코드로 다시 만든 글(바이트).
	# 뺀 칸 없음: 저장 시각·세대도 만드는 쪽이 고정한다.
	var maker: GDScript = load("res://tools/make_boss_save.gd")
	var again: String = maker.save_text()
	check(again == text, "고정 저장 = 다시 만든 글(%d / %d 바이트). 다르면 다시 만든다: %s" % [text.length(), again.length(), maker.COMMAND])
