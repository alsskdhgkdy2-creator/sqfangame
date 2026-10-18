extends TestCase
## 저장·연결 시험(06 §10.2): 2판 왕복·거부, 1판 이전, 인카운트 → 전투, 경계값 왕복, 휴식, 소재 상한.

const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action

const OVERCLOCK := "skill.blade_duelist.overclock"
const HOWL := "skill.enemy.rending_howl"
const REBOOT := "skill.nano_medic.reboot"

## M1 형식(1판) 문서 셋. f1_test 시작 칸, 옛 대원 표(레일 레인저 46).
const V1_NORMAL := '{"format":"sqfangame-save","generation":7,"rules":"m1","saved_at":"2026-10-01T00:00:00Z","schema":1,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:18":0},"icons":{},"memos":{}},"encounter":{"danger":0,"pending":false,"threshold":147},"floor":"f1_test","knowledge":{"edges":{"h:2:18":"open","h:2:19":"open","v:2:18":"open","v:3:18":"open"},"visited":["2:18"]},"party":{"at":[2,18],"facing":"N","members":[{"hp":30,"id":"holo_knight"},{"hp":52,"id":"blade_duelist"},{"hp":20,"id":"rail_ranger"},{"hp":0,"id":"nano_medic"},{"hp":40,"id":"glyph_wizard"}]},"rng":{"state":"35035103500997846"},"steps":0,"wiped":false,"world":{"passages_found":[],"shortcuts_open":[]}}}'
const V1_PENDING := '{"format":"sqfangame-save","generation":3,"rules":"m1","saved_at":"2026-10-02T00:00:00Z","schema":1,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:18":0},"icons":{},"memos":{}},"encounter":{"danger":147,"pending":true,"threshold":147},"floor":"f1_test","knowledge":{"edges":{"h:2:18":"open","h:2:19":"open","v:2:18":"open","v:3:18":"open"},"visited":["2:18"]},"party":{"at":[2,18],"facing":"N","members":[{"hp":60,"id":"holo_knight"},{"hp":52,"id":"blade_duelist"},{"hp":46,"id":"rail_ranger"},{"hp":42,"id":"nano_medic"},{"hp":1,"id":"glyph_wizard"}]},"rng":{"state":"-6400228123456789012"},"steps":12,"wiped":false,"world":{"passages_found":[],"shortcuts_open":[]}}}'
const V1_WIPED := '{"format":"sqfangame-save","generation":11,"rules":"m1","saved_at":"2026-10-03T00:00:00Z","schema":1,"state":{"annotation":{"auto_edges":[],"edges":{},"floors":{"2:18":0},"icons":{},"memos":{}},"encounter":{"danger":0,"pending":false,"threshold":147},"floor":"f1_test","knowledge":{"edges":{"h:2:18":"open","h:2:19":"open","v:2:18":"open","v:3:18":"open"},"visited":["2:18"]},"party":{"at":[2,18],"facing":"N","members":[{"hp":0,"id":"holo_knight"},{"hp":0,"id":"blade_duelist"},{"hp":0,"id":"rail_ranger"},{"hp":0,"id":"nano_medic"},{"hp":0,"id":"glyph_wizard"}]},"rng":{"state":"35035103500997846"},"steps":40,"wiped":true,"world":{"passages_found":[],"shortcuts_open":[]}}}'


var _quiet: GameDefs


## 이 파일의 정의: data/ 그대로에 적만 아무것도 하지 않는다(Fx.quiet_defs). 방어만 하는 턴·턴 상한 턴이 승리·전멸로 먼저 끝나지
## 않게 결과를 구성으로 정한다(D15). 쓰고 읽을 때 같은 정의를 쓴다.
func _defs() -> GameDefs:
	if _quiet == null:
		_quiet = Fx.quiet_defs()
	return _quiet


# ---- 2판 왕복 ----

## 전투 중 상태: 상태이상(독·마비)·봉인·강화·약화·누적 내성·준비·처치 기록이 모두 있다.
func _rich() -> ExplorationState:
	var s := Fx.battle(_defs(), "formation.f1.beetle_rat", 21)
	BattleRules.submit(s, Fx.cmds(s))
	var b := s.battle
	var ev: Array[Dictionary] = []
	BattleRules.damage_unit(s, b.enemies[1], b.enemies[1].hp, b.party[1], "slash", "attack", ev, {})  # 적 HP 와 상관없이 처치
	b.enemies[0].charging = "skill.enemy.crush"
	Fx.apply_effect(s, b.party[1], OVERCLOCK)
	Fx.apply_effect(s, b.party[1], HOWL)
	b.party[1].ailment = "poison"
	b.party[1].ailment_turns = 3
	b.party[1].ailment_damage = 4
	b.party[2].ailment = "paralysis"
	b.party[2].ailment_turns = 2
	b.party[0].binds["arm"] = 2
	b.party[3].resist_acc["paralysis"] = 300
	b.party[3].resist_acc["sleep"] = 600
	b.enemies[0].resist_acc["head"] = 300
	return s


func test_v2_roundtrip_mid_battle_same_hash_and_next_turn() -> void:
	var s := _rich()
	var b := s.battle
	check(b != null and b.turn == 1 and not b.enemies[1].kill.is_empty() and b.enemies[0].charging == "skill.enemy.crush", "준비: 전투 중, 처치 기록·준비 있음")
	var r := SaveCodec.decode(SaveCodec.encode(s), _defs())
	check(r.ok(), "읽기 성공 %s" % r.error)
	if not r.ok():
		return
	var c := r.state
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 해시")
	check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "같은 전투 해시")
	check_eq(JSON.stringify(c.battle.to_dict(), "", true), JSON.stringify(b.to_dict(), "", true), "같은 전투 사전")
	var cmds := {1: Fx.atk(0), 2: Fx.atk(0)}
	var e1 := BattleRules.submit(s, Fx.cmds(s, cmds))
	var e2 := BattleRules.submit(c, Fx.cmds(c, cmds))
	check_eq(Fx.events_text(e2), Fx.events_text(e1), "같은 다음 턴 이벤트")
	check_eq(SaveCodec.state_hash(c), SaveCodec.state_hash(s), "같은 다음 상태")


# ---- 2판 거부 (§8.5 표의 줄마다) ----

func _expect_reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var before := SaveCodec.state_hash(s)
	var battle_before := JSON.stringify(s.battle.to_dict(), "", true) if s.battle != null else ""
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])
	check_eq(SaveCodec.state_hash(s), before, "%s: 지금 상태 불변" % label)
	check_eq(JSON.stringify(s.battle.to_dict(), "", true) if s.battle != null else "", battle_before, "%s: 지금 전투 불변" % label)


func test_v2_rejects_each_save_table_row() -> void:
	var s := _rich()
	var cases := [
		# 명세 §10.2 가 적은 최소 목록
		["battle.turn = -1", func(d): d["battle"]["turn"] = -1, "battle.turn: 정수"],
		["battle.turn = 1.5", func(d): d["battle"]["turn"] = 1.5, "battle.turn: 정수"],
		["battle.turn = 2^31", func(d): d["battle"]["turn"] = 2147483648, "battle.turn: 정수"],
		["battle.turn = TURN_MAX + 1", func(d): d["battle"]["turn"] = 100000, "battle.turn: 정수 0~99999"],
		["battle.seq = 2^31", func(d): d["battle"]["seq"] = 2147483648, "battle.seq: 정수"],
		["kill = {}", func(d): d["battle"]["enemies"][1]["kill"] = {}, "battle.enemies[1].kill.turn: 필수 필드가 없다"],
		["kill.turn > battle.turn", func(d): d["battle"]["enemies"][1]["kill"]["turn"] = 2, "battle.enemies[1].kill.turn"],
		["kill.by 적 스킬", func(d): d["battle"]["enemies"][1]["kill"]["by"] = "skill.enemy.bite", "battle.enemies[1].kill.by"],
		["같은 id 강화 두 칸", func(d): _dup_buff(d), "battle.party[1].buffs[1].id: 같은 목록에 같은 효과가 둘이다"],
		["seq ≥ battle.seq", func(d): d["battle"]["party"][1]["buffs"][0]["seq"] = d["battle"]["seq"], "battle.party[1].buffs[0].seq"],
		["seq 중복", func(d): d["battle"]["party"][1]["debuffs"][0]["seq"] = d["battle"]["party"][1]["buffs"][0]["seq"], "seq 가 중복"],
		["독이 아닌 상태에 damage", func(d): d["battle"]["party"][2]["ailment"]["damage"] = 5, "battle.party[2].ailment.damage: 모르는 필드"],
		["resist 값 0", func(d): d["battle"]["party"][3]["resist"]["paralysis"] = 0, "battle.party[3].resist.paralysis"],
		["소재 10000", func(d): d["materials"]["item.neon_rat_tail"] = 10000, "materials.item.neon_rat_tail"],
		["모르는 소재", func(d): d["materials"]["item.nope"] = 1, "materials 의 item.nope 는 모르는 소재"],
		["수면 적의 charging", func(d): d["battle"]["enemies"][0]["ailment"] = {"id": "sleep", "turns": 2}, "battle.enemies[0].charging: 수면 중인 적"],
		["pending 인데 battle 없음", func(d): d["battle"] = null, "전투 대기(pending)와 battle 이 맞지 않다"],
		# 그 밖의 표 줄
		["대원 tp 범위", func(d): d["party"]["members"][1]["tp"] = 33, "party.members[1].tp"],
		["대원 tp 없음", func(d): d["party"]["members"][1].erase("tp"), "party.members[1].tp"],
		["소재 0개 키", func(d): d["materials"]["item.neon_rat_tail"] = 0, "materials.item.neon_rat_tail"],
		["소재 객체 아님", func(d): d["materials"] = [], "materials 가 객체가 아니다"],
		["battle 키 없음", func(d): d.erase("battle"), "battle 이 없다"],
		["battle 모르는 필드", func(d): d["battle"]["phase"] = 1, "battle.phase: 모르는 필드"],
		["편성이 출현 표에 없음", func(d): d["battle"]["formation"] = "formation.f1.nope", "battle.formation"],
		["battle.seq 0", func(d): d["battle"]["seq"] = 0, "battle.seq: 정수"],
		["battle.party 길이", func(d): d["battle"]["party"].pop_back(), "battle.party: 길이 5"],
		["battle.enemies 길이", func(d): d["battle"]["enemies"].append(d["battle"]["enemies"][0].duplicate(true)), "battle.enemies: 길이 2"],
		["ailment id", func(d): d["battle"]["party"][2]["ailment"]["id"] = "blind", "battle.party[2].ailment"],
		["ailment turns 10", func(d): d["battle"]["party"][2]["ailment"]["turns"] = 10, "battle.party[2].ailment.turns"],
		["독 damage 0", func(d): d["battle"]["party"][1]["ailment"]["damage"] = 0, "battle.party[1].ailment.damage"],
		["독 damage 없음", func(d): d["battle"]["party"][1]["ailment"].erase("damage"), "battle.party[1].ailment.damage: 필수 필드가 없다"],
		["봉인 부위", func(d): d["battle"]["party"][0]["binds"]["tail"] = 1, "battle.party[0].binds.tail"],
		["봉인 턴 0", func(d): d["battle"]["party"][0]["binds"]["arm"] = 0, "battle.party[0].binds.arm"],
		["강화 칸 넘침", func(d): _overfill_buffs(d), "battle.party[1].buffs: 길이 0~3"],
		["강화 값 방향", func(d): d["battle"]["party"][1]["buffs"][0]["value"] = 1000, "battle.party[1].buffs[0].value"],
		["강화 kind", func(d): d["battle"]["party"][1]["buffs"][0]["kind"] = "elem_def", "battle.party[1].buffs[0].kind"],
		["강화 목록에 약화 스킬", func(d): d["battle"]["party"][1]["buffs"][0]["id"] = HOWL, "battle.party[1].buffs[0].id: effect 가 buff"],
		["강화 turns 10", func(d): d["battle"]["party"][1]["buffs"][0]["turns"] = 10, "battle.party[1].buffs[0].turns"],
		["resist 값 resist_max 초과", func(d): d["battle"]["party"][3]["resist"]["sleep"] = 901, "battle.party[3].resist.sleep"],
		["resist 키", func(d): d["battle"]["party"][3]["resist"]["fire"] = 100, "battle.party[3].resist.fire"],
		["적 hp 초과", func(d): d["battle"]["enemies"][0]["hp"] = s.battle.enemies[0].max_hp + 1, "battle.enemies[0].hp: 정수 0~%d" % s.battle.enemies[0].max_hp],
		["charging 이 강공격 아님", func(d): d["battle"]["enemies"][0]["charging"] = "skill.enemy.pinch", "battle.enemies[0].charging"],
		["kill element", func(d): d["battle"]["enemies"][1]["kill"]["element"] = "dark", "battle.enemies[1].kill.element"],
		["kill ailment", func(d): d["battle"]["enemies"][1]["kill"]["ailment"] = "blind", "battle.enemies[1].kill.ailment"],
		["kill binds 순서", func(d): d["battle"]["enemies"][1]["kill"]["binds"] = ["arm", "head"], "battle.enemies[1].kill.binds"],
		["HP 0 적의 kill null", func(d): d["battle"]["enemies"][1]["kill"] = null, "battle.enemies[1].kill: HP 0 인 적"],
		["HP 있는 적의 kill", func(d): d["battle"]["enemies"][0]["kill"] = d["battle"]["enemies"][1]["kill"], "battle.enemies[0].kill: HP 가 1 이상"],
		["HP 0 적의 상태", func(d): d["battle"]["enemies"][1]["binds"] = {"leg": 1}, "battle.enemies[1]: HP 0 유닛은"],
		["HP 0 대원의 상태", func(d): _down_member_with_bind(d), "battle.party[4]: HP 0 유닛은"],
		["적 모두 HP 0", func(d): _kill_all_enemies(d), "battle.enemies: 적이 모두 HP 0"],
	]
	for c in cases:
		_expect_reject(s, c[1], c[2], c[0])


func _dup_buff(d: Dictionary) -> void:
	var b: Dictionary = d["battle"]
	var e: Dictionary = b["party"][1]["buffs"][0].duplicate()
	e["seq"] = b["seq"]
	b["seq"] += 1
	b["party"][1]["buffs"].append(e)


func _overfill_buffs(d: Dictionary) -> void:
	var b: Dictionary = d["battle"]
	for id in ["skill.holo_knight.defense_protocol", OVERCLOCK, OVERCLOCK]:
		b["party"][1]["buffs"].append({"id": id, "kind": "phys_atk", "value": 1100, "turns": 1, "seq": b["seq"]})
		b["seq"] += 1


func _down_member_with_bind(d: Dictionary) -> void:
	d["party"]["members"][4]["hp"] = 0
	d["battle"]["party"][4]["binds"] = {"leg": 1}


func _kill_all_enemies(d: Dictionary) -> void:
	var e: Dictionary = d["battle"]["enemies"][0]
	e["hp"] = 0
	e["charging"] = null
	e["resist"] = {}
	e["kill"] = d["battle"]["enemies"][1]["kill"]


# ---- 1판 이전 ----

func _hps(s: ExplorationState) -> Array:
	return s.party.members.map(func(m): return m.hp)


func _tps(s: ExplorationState) -> Array:
	return s.party.members.map(func(m): return m.tp)


func test_v1_normal_migrates_hp_ratio_and_full_tp() -> void:
	var r := SaveCodec.decode(V1_NORMAL, _defs())
	check(r.ok(), "이전 성공 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	check_eq(r.from_schema, 1, "1판에서 옮김")
	check_eq(s.party.members.map(func(m): return m.id), ["holo_knight", "blade_duelist", "blade_duelist_2", "nano_medic", "glyph_wizard"], "지금 파티 ID")
	# 레일 레인저 20/46 → 듀얼리스트 B 20 × 52 / 46 = 22.6… → 올림 23. 나머지는 최대 HP 가 같아 그대로, 0 은 0.
	check_eq(_hps(s), [30, 52, 23, 0, 40], "HP 비율 이전(올림)")
	check_eq(_tps(s), [30, 32, 32, 54, 60], "TP 최대")
	check_eq([s.materials, s.battle, s.encounter.pending, s.wiped], [{}, null, false, false], "소재 없음·전투 없음")
	check_eq([s.party.at, s.steps, s.rng.get_state()], [Vector2i(2, 18), 0, 35035103500997846], "M1 필드 그대로")


func test_v1_pending_always_opens_same_formation() -> void:
	var formations := []
	var hashes := []
	for i in 3:
		var r := SaveCodec.decode(V1_PENDING, _defs())
		check(r.ok(), "이전 성공 %s" % r.error)
		if not r.ok():
			return
		check(r.state.encounter.pending and r.state.battle != null, "전투가 열림")
		formations.append(r.state.battle.formation)
		hashes.append(SaveCodec.state_hash(r.state))
	check_eq(formations, [formations[0], formations[0], formations[0]], "늘 같은 편성: %s" % formations[0])
	check_eq(hashes, [hashes[0], hashes[0], hashes[0]], "늘 같은 해시")
	var r := SaveCodec.decode(V1_PENDING, _defs())
	check_eq(_hps(r.state), [60, 52, 52, 42, 1], "46/46 → 52/52")
	check(BattleRules.submit(r.state, Fx.cmds(r.state))[0]["type"] != "rejected", "옮긴 전투로 바로 턴을 낼 수 있음")


func test_v1_wiped_migrates_without_battle() -> void:
	var r := SaveCodec.decode(V1_WIPED, _defs())
	check(r.ok(), "이전 성공 %s" % r.error)
	if r.ok():
		check_eq([r.state.wiped, r.state.battle, _hps(r.state), _tps(r.state)], [true, null, [0, 0, 0, 0, 0], [30, 32, 32, 54, 60]], "전멸 그대로, 전투 없음")


func _v1_reject(mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(V1_NORMAL)
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), _defs())
	check(not r.ok() and r.state == null, "%s: 거부" % label)
	check(r.error.begins_with("1판 검사 실패: ") and r.error.contains(needle), "%s: 이전 전 1판 검사에서 거부, 실제 '%s'" % [label, r.error])


func test_v1_bad_original_rejected_before_migration() -> void:
	_v1_reject(func(d): d["party"]["members"][0]["hp"] = 0.1, "party.members[0].hp", "옛 HP 0.1")
	_v1_reject(func(d): d["party"]["members"][0]["hp"] = -1, "party.members[0].hp", "옛 HP -1")
	_v1_reject(func(d): d["party"]["members"][0]["hp"] = 61, "party.members[0].hp 가 0~60", "옛 HP 61(나이트)")
	_v1_reject(func(d): d["party"].erase("members"), "party.members", "members 없음")
	_v1_reject(func(d): d["party"]["members"].pop_back(), "party.members", "대원 넷")
	_v1_reject(func(d): d["party"]["members"][1]["hp"] = "52", "party.members[1].hp", "hp 문자열")
	_v1_reject(func(d): d["encounter"]["pending"] = true, "전투 대기(pending)와 위험도", "pending 참인데 danger < threshold")
	_v1_reject(func(d): d["wiped"] = true, "wiped", "wiped 인데 살아 있는 대원")
	_v1_reject(func(d): d["party"]["members"][2]["id"] = "blade_duelist_2", "party.members[2] 의 id", "모르는 1판 파티(2판 ID)")
	# 레일 레인저 47 은 옛 최대 46 을 넘는다: 새 최대(52) 로 옮기기 전에 막혀야 한다.
	_v1_reject(func(d): d["party"]["members"][2]["hp"] = 47, "party.members[2].hp 가 0~46", "옛 최대 HP 기준")


func test_v1_repeated_decode_is_independent() -> void:
	for text in [V1_NORMAL, V1_PENDING]:
		var a := SaveCodec.decode(text, _defs())
		var b := SaveCodec.decode(text, _defs())
		check(a.ok() and b.ok(), "둘 다 성공")
		if not (a.ok() and b.ok()):
			return
		var hb := SaveCodec.state_hash(b.state)
		check_eq(SaveCodec.state_hash(a.state), hb, "같은 해시")
		a.state.party.members[0].hp = 1
		a.state.materials["item.neon_rat_tail"] = 5
		if a.state.battle != null:
			a.state.battle.enemies[0].hp = 1
			a.state.battle.party[0].binds["arm"] = 1
		a.state.rng.randi_range(0, 9)
		check_eq(SaveCodec.state_hash(b.state), hb, "첫 결과를 바꿔도 둘째는 그대로")


func test_v1_header_preserved() -> void:
	for x in [[V1_NORMAL, "2026-10-01T00:00:00Z", 7], [V1_PENDING, "2026-10-02T00:00:00Z", 3], [V1_WIPED, "2026-10-03T00:00:00Z", 11]]:
		for i in 2:
			var r := SaveCodec.decode(x[0], _defs())
			check(r.ok(), "성공 %s" % r.error)
			if r.ok():
				check_eq([r.saved_at, r.generation, r.state.generation, r.from_schema], [x[1], x[2], x[2], 1], "원본 saved_at·generation 보존 (%d번째)" % (i + 1))


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _v1_with(mutate: Callable) -> String:
	var doc: Dictionary = JSON.parse_string(V1_NORMAL)
	mutate.call(doc)
	return JSON.stringify(doc)


func test_v1_candidate_recovery_reads_bak_and_leaves_files() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(_defs(), Fx.SAVE_DIR)
	var broken := _v1_with(func(d): d["state"]["party"]["members"][0]["hp"] = 61)
	var bak_path := Fx.SAVE_DIR + "/auto.bak"
	_write(store.main_path("auto"), broken)
	_write(bak_path, V1_NORMAL)
	var files_before := DirAccess.get_files_at(Fx.SAVE_DIR)
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "bak" and l.failures.size() == 1, "깨진 1판 본 파일 → 정상 1판 .bak 이전: %s" % str(l.failures))
	if l.ok():
		check_eq([l.result.from_schema, l.result.saved_at, l.result.generation, _hps(l.result.state)], [1, "2026-10-01T00:00:00Z", 7, [30, 52, 23, 0, 40]], ".bak 을 옮긴 결과")
	check_eq(FileAccess.get_file_as_string(store.main_path("auto")), broken, "본 파일 그대로")
	check_eq(FileAccess.get_file_as_string(bak_path), V1_NORMAL, ".bak 그대로(1판 글 그대로)")
	check_eq(DirAccess.get_files_at(Fx.SAVE_DIR), files_before, "파일 목록 그대로")
	Fx.clean_saves()


func test_v1_manual_slots_latest_by_original_time() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(_defs(), Fx.SAVE_DIR)
	var times := {"slot1": "2026-10-01T01:00:00Z", "slot2": "2026-10-01T03:00:00Z", "slot3": "2026-10-01T02:00:00Z"}
	# 쓰는 순서를 시각 순서와 다르게(slot2 를 먼저) 해 파일 시각에 기대지 않게 한다.
	for slot in ["slot2", "slot3", "slot1"]:
		_write(store.main_path(slot), _v1_with(func(d): d["saved_at"] = times[slot]))
	check_eq(store.latest_manual(), "slot2", "원본 saved_at 이 가장 늦은 슬롯")
	for slot in times:
		var info := store.slot_info(slot)
		check(info.ok and info.saved_at == times[slot] and info.generation == 7, "%s 머리 보존" % slot)
	check_eq(store.latest_manual(), "slot2", "두 번 읽어도 같음")
	Fx.clean_saves()


# ---- 인카운트 → 전투 ----

func test_encounter_opens_battle_and_blocks_exploration() -> void:
	# f1 시작 칸 둘레는 안전 구역이라 복도 층(출현 표는 encounter.f1_test)에서 두 걸음째 인카운트.
	var s := Fx.game(Fx.row_floor("......", "     ", {"encounter": {"danger_per_step": 10, "threshold_min": 20, "threshold_max": 20}}), 5, "floor")
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check(s.battle == null and not s.encounter.pending, "한 걸음째는 전투 없음")
	var ev := ExplorationRules.apply(s, A.FORWARD, "floor")
	var enc := Fx.of_type(ev, "encounter")
	check_eq(enc.size(), 1, "인카운트 걸음")
	check(s.battle != null and s.encounter.pending, "battle 생김")
	if s.battle == null:
		return
	check_eq(s.battle.formation, enc[0]["formation"], "이벤트의 편성으로 열림")
	check(s.defs.battle.table_formations("encounter.f1_test").has(s.battle.formation), "출현 표의 편성")
	var h := SaveCodec.state_hash(s)
	var bh := Fx.battle_hash(s)
	var rng := s.rng.get_state()
	for a in [A.FORWARD, A.BACK, A.STRAFE_LEFT, A.STRAFE_RIGHT, A.TURN_LEFT, A.TURN_RIGHT, A.INVESTIGATE, A.REST]:
		var out := ExplorationRules.apply(s, a, "floor")
		check_eq(out, [{"type": "rejected", "reason": "pending"}] as Array[Dictionary], "전투 중 행동 %d 거부" % a)
	check_eq([SaveCodec.state_hash(s), Fx.battle_hash(s), s.rng.get_state()], [h, bh, rng], "상태·전투·난수 불변")


# ---- 경계값 왕복 ----

const DEF1 := "skill.t.def1"
const ATK3000 := "skill.t.atk3000"
const WEAK1 := "skill.enemy.t_weak1"
const POISON_MAX := "skill.enemy.t_poison_max"


func _boundary_defs() -> GameDefs:
	var skills := [
		Fx.effect_skill(DEF1, false, [["phys_def", 1, 9]]),
		Fx.effect_skill(ATK3000, false, [["phys_atk", 3000, 9]]),
		Fx.effect_skill(WEAK1, true, [["phys_atk", 1, 9]]),
		Fx.enemy_skill(POISON_MAX, "ailment", "enemy_one", {"sure_hit": true}, {"ailment": {"id": "poison", "chance": 1000, "turns": 9, "damage": 9999}}),
	]
	var dropper := Fx.enemy("enemy.t_dropper", 1, [10, 10, 10, 10, 1, 10], [[{}, [[Fx.MEND, 1]]]], {"drops": [{"item": "item.neon_rat_tail", "chance": 1000}]})
	var rules := Fx.EXACT.merged({"status_luck": 0, "resist_gain": 900})
	var files := Fx.battle_files(Fx.test_files(skills, [dropper], {"d": [[Fx.DUMMY, "front"]], "drop": [["enemy.t_dropper", "front"]]}), rules)
	for sk in files["skills/nano_medic.json"]["skills"]:
		if sk["id"] == REBOOT:
			sk["levels"][0]["hp_permille"] = 1000
	return Fx.defs_from(files)


func test_boundary_values_from_definitions_roundtrip() -> void:
	var defs := _boundary_defs()
	check(defs != null, "시험 정의가 검사를 통과")
	if defs == null:
		return
	var s := Fx.battle(defs, "formation.t.d", 1)
	var b := s.battle
	s.party.members[0].hp = 0
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(REBOOT, 0)}))
	check_eq(Fx.of_type(ev, "revived").map(func(e): return e["hp"]), [60], "소생 1000‰ → 최대 HP")
	Fx.apply_effect(s, b.party[1], DEF1)
	Fx.apply_effect(s, b.party[1], ATK3000)
	Fx.apply_effect(s, b.party[2], WEAK1)
	var aev: Array[Dictionary] = []
	BattleEffects.apply_ailment(b, defs.battle.rules, s.rng, b.enemies[0], b.party[4], defs.battle.skill(POISON_MAX).levels[0]["ailment"], aev)
	check_eq([b.party[1].buffs.map(func(e): return e["value"]), b.party[2].debuffs.map(func(e): return e["value"])], [[1, 3000], [1]], "방어 강화 1·공격 강화 3000·공격 약화 1")
	check_eq([b.party[4].ailment, b.party[4].ailment_damage, b.party[4].resist_acc.get("poison")], ["poison", 9999, defs.battle.rules.resist_max], "독 피해 9999·누적 내성 resist_max")
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok(), "정의가 허용한 값으로 만든 상태는 저장 검사를 통과 %s" % r.error)
	if r.ok():
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "같은 해시")
		check_eq(Fx.battle_hash(r.state), Fx.battle_hash(s), "같은 전투 해시")


# ---- 검사된 경계값 불러오기 → 합법 명령 한 턴 → 검사된 저장 (06 §11.4 ②) ----

## 상태를 문서로 내보내고 mutate 로 고친 뒤 검사 있는 읽기로 되살린다.
func _reload(s: ExplorationState, mutate: Callable) -> ExplorationState:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc["state"])
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(r.ok(), "경계값 문서는 검사를 통과: %s" % r.error)
	return r.state if r.ok() else null


func _saves_ok(s: ExplorationState, label: String) -> void:
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok(), "%s: 한 턴 뒤 검사 있는 저장 성공 %s" % [label, r.error])
	if r.ok():
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "%s: 같은 해시" % label)


func test_turn_max_boundary_ends_as_escape_and_saves() -> void:
	var base := Fx.battle(_defs(), "formation.f1.rats", 3)
	var s := _reload(base, func(d): d["battle"]["turn"] = BattleLimits.TURN_MAX)
	if s == null:
		return
	check_eq(s.battle.turn, 99999, "불러온 turn = TURN_MAX")
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var end := Fx.of_type(ev, "battle_end")
	check_eq(end.size(), 1, "턴 끝에서 전투가 끝남")
	if end.is_empty():
		return
	check_eq([end[0]["outcome"], end[0]["reason"], end[0]["turn"], end[0]["drops"]], ["escaped", "turn_cap", 99999, []], "도주(turn_cap)·드롭 없음·turn 은 묶지 않음")
	var types := Fx.types(ev)
	check(types.find("turn_end") < types.find("battle_end"), "턴 끝 처리 뒤에 끝남")
	check_eq([s.battle, s.encounter.pending, s.wiped], [null, false, false], "탐색으로 돌아감")
	_saves_ok(s, "turn = TURN_MAX")
	# 한 턴 앞(99,998)은 99,999 로 올라 이어지고 저장된다.
	s = _reload(base, func(d): d["battle"]["turn"] = BattleLimits.TURN_MAX - 1)
	if s == null:
		return
	ev = BattleRules.submit(s, Fx.cmds(s))
	check(Fx.of_type(ev, "battle_end").is_empty() and s.battle != null and s.battle.turn == 99999, "99,998 → 99,999 로 이어짐")
	_saves_ok(s, "turn = TURN_MAX − 1")


func test_seq_max_boundary_renumbers_and_keeps_eviction() -> void:
	# 메딕 대신 나이트가 디펜스 프로토콜(아군 전체 강화)을 건다. 대원 1 은 강화 세 칸이 차 있어 하나를 밀어낸다.
	var defs := _boundary_defs()
	if defs == null:
		check(false, "시험 정의")
		return
	var base := Fx.battle(defs, "formation.t.d", 1)
	var b := base.battle
	Fx.apply_effect(base, b.party[1], DEF1)       # seq 1
	Fx.apply_effect(base, b.party[2], WEAK1)      # seq 2 (다른 유닛의 약화가 사이에 낀다)
	Fx.apply_effect(base, b.party[1], ATK3000)    # seq 3
	Fx.apply_effect(base, b.party[1], OVERCLOCK)  # seq 4
	var small := _reload(base, func(d): pass)
	var big := _reload(base, _big_seq)
	if small == null or big == null:
		return
	check_eq(big.battle.seq, 2147483647, "불러온 battle.seq = 2^31 − 1")
	var cmd := {0: Fx.use("skill.holo_knight.defense_protocol", 0)}
	var e1 := BattleRules.submit(small, Fx.cmds(small, cmd))
	var e2 := BattleRules.submit(big, Fx.cmds(big, cmd))
	var ev1 := Fx.of_type(e1, "buffed").map(func(e): return [e["target"]["slot"], e["evicted"]["id"] if e["evicted"] != null else ""])
	check_eq(Fx.of_type(e2, "buffed").map(func(e): return [e["target"]["slot"], e["evicted"]["id"] if e["evicted"] != null else ""]), ev1, "밀어내기 결과가 같음")
	check(ev1.has([1, DEF1]), "대원 1 에서 가장 오래된 DEF1 이 밀려남: %s" % str(ev1))
	# 다시 매기면 [DEF1, WEAK1, ATK3000, OVERCLOCK] → 1·2·3·4 로 작은 쪽과 같은 번호가 되어 전투 사전 전체가 같다.
	check_eq(JSON.stringify(big.battle.to_dict(), "", true), JSON.stringify(small.battle.to_dict(), "", true), "다시 매긴 순서·번호가 작은 seq 쪽과 같음")
	check_eq(big.battle.seq, 10, "battle.seq = 효과 수 4 + 1, 새로 다섯 개를 줘 10")
	_saves_ok(big, "seq = 2^31 − 1")


## 같은 순서를 큰 seq 로: DEF1 < WEAK1 < ATK3000 < OVERCLOCK, battle.seq = 2^31 − 1.
func _big_seq(d: Dictionary) -> void:
	d["battle"]["party"][1]["buffs"][0]["seq"] = 2147483000
	d["battle"]["party"][2]["debuffs"][0]["seq"] = 2147483050
	d["battle"]["party"][1]["buffs"][1]["seq"] = 2147483100
	d["battle"]["party"][1]["buffs"][2]["seq"] = 2147483200
	d["battle"]["seq"] = BattleLimits.SEQ_MAX


func test_renumber_seq_keeps_order_across_units() -> void:
	var defs := _boundary_defs()
	if defs == null:
		return
	var s := Fx.battle(defs, "formation.t.d", 1)
	var b := s.battle
	Fx.apply_effect(s, b.party[3], ATK3000)
	Fx.apply_effect(s, b.party[0], WEAK1)
	Fx.apply_effect(s, b.party[3], DEF1)
	Fx.apply_effect(s, b.party[0], DEF1)
	b.party[3].buffs[0]["seq"] = 700
	b.party[0].debuffs[0]["seq"] = 701
	b.party[3].buffs[1]["seq"] = 900
	b.party[0].buffs[0]["seq"] = 800
	b.seq = 901
	BattleEffects.renumber_seq(b)
	check_eq([b.party[3].buffs.map(func(e): return e["seq"]), b.party[0].debuffs.map(func(e): return e["seq"]), b.party[0].buffs.map(func(e): return e["seq"]), b.seq],
		[[1, 4], [2], [3], 5], "seq 오름차순(유닛 칸 순이 아님)으로 1부터")


func test_material_cap_survives_victory_and_save() -> void:
	var defs := _boundary_defs()
	if defs == null:
		check(false, "시험 정의")
		return
	var s := Fx.battle(defs, "formation.t.drop", 2)
	s.materials["item.neon_rat_tail"] = 9999
	check(Fx.battle_clone(s) != null, "9999 개는 저장 가능")
	var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.atk(0)}))
	check_eq(Fx.of_type(ev, "drop").map(func(e): return [e["amount"], e["capped"]]), [[0, true]], "넘친 드롭은 버림")
	check_eq([s.battle, s.materials["item.neon_rat_tail"]], [null, 9999], "승리, 9999 그대로")
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok(), "저장 → 읽기 %s" % r.error)
	if r.ok():
		check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "같은 해시")
		check_eq(r.state.materials, {"item.neon_rat_tail": 9999}, "소재 9999")


# ---- 휴식 ----

func test_rest_only_at_start_and_restores_everyone() -> void:
	var s := Fx.game(null, 5, "floor")
	s.party.members[0].hp = 0
	s.party.members[1].hp = 3
	s.party.members[1].tp = 0
	s.party.members[4].tp = 7
	s.encounter.danger = 40
	var before := [s.encounter.danger, s.encounter.threshold, s.steps, s.rng.get_state(), s.party.at, s.party.facing]
	var ev := ExplorationRules.apply(s, A.REST, "floor")
	check_eq(ev, [{"type": "rested"}] as Array[Dictionary], "rested")
	check_eq([_hps(s), _tps(s)], [[60, 52, 52, 42, 40], [30, 32, 32, 54, 60]], "HP·TP 최대, 쓰러진 대원도")
	check_eq([s.encounter.danger, s.encounter.threshold, s.steps, s.rng.get_state(), s.party.at, s.party.facing], before, "위험도·걸음·난수·위치 그대로")
	ExplorationRules.apply(s, A.FORWARD, "floor")
	check(s.party.at != s.floor_def.start_at and s.battle == null, "준비: 시작 칸을 떠남")
	s.party.members[1].hp = 3
	var h := SaveCodec.state_hash(s)
	check_eq(ExplorationRules.apply(s, A.REST, "floor"), [{"type": "blocked", "reason": "not_rest_point"}] as Array[Dictionary], "시작 칸이 아니면 막힘")
	check_eq(SaveCodec.state_hash(s), h, "막히면 상태 그대로")


func test_rest_rejected_in_battle_and_when_wiped() -> void:
	var s := Fx.battle(_defs(), "formation.f1.rats", 3)
	check_eq(s.party.at, s.floor_def.start_at, "준비: 시작 칸에서 전투")
	s.party.members[1].hp = 3
	var h := SaveCodec.state_hash(s)
	var rng := s.rng.get_state()
	check_eq(ExplorationRules.apply(s, A.REST, "floor"), [{"type": "rejected", "reason": "pending"}] as Array[Dictionary], "전투 중 거부")
	check_eq([SaveCodec.state_hash(s), s.rng.get_state(), s.party.members[1].hp], [h, rng, 3], "상태·난수 그대로")
	var w := Fx.game(null, 5, "floor")
	for m in w.party.members:
		m.hp = 0
	w.wiped = true
	h = SaveCodec.state_hash(w)
	check_eq(ExplorationRules.apply(w, A.REST, "floor"), [{"type": "rejected", "reason": "wiped"}] as Array[Dictionary], "전멸 중 거부")
	check_eq(SaveCodec.state_hash(w), h, "전멸 상태 그대로")
