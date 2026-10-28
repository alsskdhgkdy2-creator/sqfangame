## 대열 바꾸기의 실제 흐름(M3 A7a, 설계 §4.1b): 게임 묶음 미궁에서 DungeonScreen.arrange_party(캠프 「대열」 판이 A7c 에서 부를 입구) →
## 자동 저장 = 화면 → 새 화면으로 다시 읽기 → 디버그 battle_start 로 연 전투의 유닛 차례·열. 창이 열렸거나 전투 중이면 거부(저장 없음).
## 시간은 가지 않는다(걸음·위험도·FOE·난수). 장면 시험 임시 폴더만 쓴다(user://saves 는 건드리지 않는다).
## 시험마다 이름 붙은 변이(설계 노트 §4.1b·§7, M-G…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()


func _prep(sc: DungeonScreen) -> void:
	sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH
	sc.url_query = "debug=1"


func _op(s: DungeonScreen, req: Dictionary) -> Dictionary:
	var r: Variant = JSON.parse_string(s._on_debug_request(JSON.stringify(req)))
	return r if r is Dictionary else {}


func _auto(s: DungeonScreen) -> SaveCodec.LoadResult:
	return SaveCodec.decode(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)), s.state.defs)


## F1 (M-G13 전투 중에도 받음, M-G14 시간이 감, M-G16 쓰기가 옛 열을 남김): 미궁 B1F 에서 대열을 바꾸면 자동 저장 = 화면이고,
## 다시 연 화면도 같은 차례·열이며, 그 뒤 연 전투의 유닛이 새 차례·열이다. 창이 열렸거나 전투 중이면 거부하고 저장하지 않는다.
func test_arrange_in_labyrinth_saves_and_drives_battle() -> void:
	timeout_sec = 120.0
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open("native", 7, "debug=1", _prep)
	s.state.encounter.threshold = 99999
	await kit.frames(2)
	check_eq([s.state.location, s.state.floor_def.id], ["labyrinth", "b1f"], "준비: 게임 묶음 B1F")
	var before := SaveCodec.state_to_dict(s.state)
	var rng0 := s.state.rng.get_state()
	var gen0 := s.state.generation
	var ev := s.arrange_party(["glyph_wizard", "nano_medic"], ["holo_knight", "blade_duelist", "blade_duelist_2"])
	check_eq(ev[0]["type"], "arranged", "대열 바꿈 %s" % str(ev[0]))
	await kit.frames(2)
	var after := SaveCodec.state_to_dict(s.state)
	for k in before:
		if k != "party":
			check_eq(after[k], before[k], "%s 그대로(시간이 가지 않는다)" % k)
	check_eq([s.state.rng.get_state(), after["party"]["at"], after["party"]["facing"]], [rng0, before["party"]["at"], before["party"]["facing"]], "난수·위치·방향 그대로")
	check(s.state.generation > gen0, "자동 저장했다(세대 +)")
	var a := _auto(s)
	check(a.ok() and SaveCodec.state_hash(a.state) == kit.hash_now(), "자동 저장 = 화면 %s" % a.error)
	# 창이 열렸으면 거부(규칙까지 가지 않는다), 저장 없음.
	var gen1 := s.state.generation
	var rows: Array[Control] = []
	s.modal.open("test", "test", rows)
	check_eq(s.arrange_party(["holo_knight"], ["glyph_wizard", "nano_medic", "blade_duelist"]), [{"type": "rejected", "reason": "busy"}], "창이 열림: busy")
	s.modal.close()
	check_eq(s.state.generation, gen1, "거부: 저장 없음")
	# 다시 연 화면: 같은 해시·차례·열.
	var h := kit.hash_now()
	s = await kit.reopen(_prep)
	await kit.frames(2)
	check_eq(kit.hash_now(), h, "새 화면: 같은 해시")
	check_eq([s.state.party.members.map(func(m: PartyState.Member) -> String: return m.id), s.state.party.members.map(func(m: PartyState.Member) -> String: return m.row)],
		[["glyph_wizard", "nano_medic", "holo_knight", "blade_duelist", "blade_duelist_2"], ["front", "front", "back", "back", "back"]], "새 화면: 차례·열")
	# 그 뒤 연 전투.
	var st := _op(s, {"op": "battle_start"})
	check_eq([st.get("ok"), st.get("open")], [true, true], "battle_start: 인카운트 전투")
	await kit.frames(2)
	if s.state.battle == null:
		return
	var b := s.state.battle
	check_eq([b.party.map(func(u: BattleUnit) -> String: return u.def_id), b.party.map(func(u: BattleUnit) -> String: return u.row)],
		[["glyph_wizard", "nano_medic", "holo_knight", "blade_duelist", "blade_duelist_2"], ["front", "front", "back", "back", "back"]], "전투 유닛 차례·열")
	var pc := s.battle_layer.party_cards
	check_eq(range(5).map(func(i: int) -> bool: return pc.top_row(i)), [true, true, false, false, false], "전투 카드: 위 줄 둘(전열), 아래 줄 셋")
	check(pc.cards[1].position.y < pc.cards[2].position.y, "그린 카드: 전열 카드가 후열 카드보다 위")
	var gen2 := s.state.generation
	check_eq(s.battle_layer.phase, "command", "준비: 명령 입력 단계(연출 없음)")
	check_eq(s.arrange_party(["holo_knight", "nano_medic"], ["glyph_wizard", "blade_duelist", "blade_duelist_2"]), [{"type": "rejected", "reason": "in_battle"}],
		"전투 중: 규칙이 in_battle 로 거부")
	check_eq(s.state.generation, gen2, "전투 중 거부: 저장 없음")
