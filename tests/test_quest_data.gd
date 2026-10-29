## 의뢰 정의 읽기(M3 A8a, 설계 §2): 실제 파일(정보상 바 셋·관리국 둘), 형식·참조 검사, 층 계단 needs 와 그것을 주는 의뢰.
## 시험마다 죽이는 변이(M-QD…)를 적는다. 기대값은 설계 §5.1 의 글자 그대로다(상수와 견주지 않는다).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")


func _floors(d: GameDefs) -> Array[FloorModel]:
	var out: Array[FloorModel] = []
	for id in d.floor_ids:
		out.append(d.floors[id])
	return out


## 오류 없는 정보상 바 납품 의뢰 하나(fixture). over 로 덮는다.
func _q(over: Dictionary = {}) -> Dictionary:
	var d := {
		"id": "quest.fx_a", "giver": "pub", "name_key": "quest.moss_soup", "desc_key": "quest.moss_soup.desc", "client_key": "quest.client.cook",
		"unlock": [], "objective": {"kind": "deliver", "item": "item.neon_moss", "count": 3},
		"reward": {"money": 10, "exp": 0, "items": [], "flags": []},
	}
	d.merge(over, true)
	return d


## 의뢰 목록을 읽고 게임 묶음 정의로 참조까지 본 오류 목록.
func _errors(list: Array) -> Array[String]:
	var d := Fx.arbor()
	var q := QuestDb.parse_dict({"quests": list}, "fx.json")
	if q.ok():
		q.resolve(d.battle, _floors(d), null)
	return q.errors


func _expect(list: Array, needle: String, label: String) -> void:
	var errs := _errors(list)
	check(errs.any(func(e: String) -> bool: return e.contains(needle)), "%s: 「%s」 오류 %s" % [label, needle, str(errs)])


## D1: 실제 파일. 정보상 바 셋·관리국 둘, 반복·납품·FOE 사냥이 하나 이상, 첫 임무가 B2F 허가를 준다(설계 §5.1 글자 그대로).
func test_real_file() -> void:
	var d := Fx.arbor()
	check(d != null, "게임 묶음 읽기")
	if d == null:
		return
	var q := d.quests
	check_eq(q.order, ["mission.permit_b2f", "mission.boss_seal", "quest.moss_soup", "quest.ether_ram", "quest.moth_sweep"] as Array[String], "의뢰 다섯, 자료 차례")
	check_eq([q.order.filter(func(id: String) -> bool: return q.quests[id].giver == "pub").size(),
		q.order.filter(func(id: String) -> bool: return q.quests[id].giver == "council").size()], [3, 2], "정보상 바 셋·관리국 둘")
	var m1: QuestDb.QuestDef = q.quests["mission.permit_b2f"]
	check_eq([m1.kind, m1.floor, m1.at, m1.money, m1.exp, m1.flags, m1.repeat_days], ["reach", "b1f", Vector2i(17, 1), 100, 30, ["permit.b2f"] as Array[String], -1],
		"첫 임무: B1F 17:1 도착, 100엔, 경험치 30, permit.b2f, 반복 없음")
	var m2: QuestDb.QuestDef = q.quests["mission.boss_seal"]
	check_eq([m2.kind, m2.floor, m2.at, m2.flags, m2.unlock], ["reach", "b3f", Vector2i(9, 2), ["permit.boss"] as Array[String],
		[{"kind": "reported", "quest": "mission.permit_b2f"}, {"kind": "visited", "floor": "b3f"}]], "둘째 임무: B3F 9:2(봉인 앞), permit.boss, 조건 둘")
	var soup: QuestDb.QuestDef = q.quests["quest.moss_soup"]
	check_eq([soup.kind, soup.target, soup.count, soup.repeat_days, soup.items], ["deliver", "item.neon_moss", 3, 1, [{"item": "use.medica", "count": 2}]],
		"이끼 수프: 네온 이끼 3 납품, 하루 뒤 반복, 메디카 2")
	check_eq([q.quests["quest.ether_ram"].kind, q.quests["quest.ether_ram"].target, q.quests["quest.moth_sweep"].kind, q.quests["quest.moth_sweep"].target,
		q.quests["quest.moth_sweep"].count], ["foe", "foe.ether_ram", "kill", "enemy.cable_moth", 4], "FOE 사냥·나방 넷")
	check_eq([q.flag_source, d.gate_flags()], [{"permit.b2f": "mission.permit_b2f", "permit.boss": "mission.boss_seal"}, ["permit.b2f"] as Array[String]],
		"플래그의 출처, 계단이 요구하는 플래그는 permit.b2f 하나")
	check_eq([d.floors["b1f"].stair_at(Vector2i(17, 1)).needs, d.floors["b2f"].stair_at(Vector2i(17, 1)).needs, d.floors["b2f"].stair_at(Vector2i(17, 17)).needs],
		["permit.b2f", "", ""], "B1F 내려가는 계단만 막힌다")
	check(Fx.defs().quests.is_empty() and not Fx.defs().quests.has_giver("pub"), "시험 묶음은 의뢰가 없다")
	check(q.has_giver("pub") and q.has_giver("council"), "게임 묶음은 두 시설 모두 의뢰가 있다")


## D2 (M-QD1 정확한 키를 보지 않음, M-QD9 수 0 을 받음, M-QD10 ID 꼴을 보지 않음): 형식 검사.
func test_format_rejects() -> void:
	check_eq(_errors([_q()]), [] as Array[String], "fixture 는 오류가 없다")
	_expect([_q({"extra": 1})], "extra: 모르는 필드", "모르는 키")
	_expect([_q({"objective": {"kind": "deliver", "item": "item.neon_moss", "count": 3, "x": 1}})], "objective.x: 모르는 필드", "목표의 모르는 키")
	_expect([_q({"objective": {"kind": "deliver", "item": "item.neon_moss", "count": 0}})], "objective.count", "수 0")
	_expect([_q({"objective": {"kind": "deliver", "item": "item.neon_moss", "count": 2.5}})], "objective.count", "수 2.5")
	_expect([_q({"objective": {"kind": "gather", "point": "take", "count": 1}})], "kill·foe·deliver·reach", "모르는 목표 종류")
	_expect([_q({"id": "mission.fx_a"})], "pub 의 ID 는", "정보상 바 의뢰가 mission. ID")
	_expect([_q({"unlock": [{"kind": "owned", "item": "item.neon_moss"}]})], "reported·visited·day·level", "모르는 조건 종류")
	_expect([_q(), _q()], "ID 가 중복이다", "같은 ID 둘")
	_expect([_q({"reward": {"money": 10, "exp": 0, "items": [{"item": "use.medica", "count": 1}, {"item": "use.medica", "count": 2}], "flags": []}})], "두 줄이다", "보수 물건 두 줄")
	var many := []
	for i in 5:
		many.append({"item": ["use.medica", "use.amrita", "use.nectar", "use.theriaca_a", "use.theriaca_b"][i], "count": 1})
	_expect([_q({"reward": {"money": 10, "exp": 0, "items": many, "flags": []}})], "줄 4개 이하", "보수 물건 다섯 줄")
	var q := QuestDb.parse_dict({"quests": [_q()], "more": 1}, "fx.json")
	check(not q.ok(), "맨 위 키가 하나가 아니면 오류")


## D3 (M-QD2 관리국 반복을 받음, M-QD3 고리를 보지 않음, M-QD5 귀중품 납품을 받음, M-QD6 플래그 출처 둘을 받음): 관계 검사.
func test_relation_rejects() -> void:
	_expect([_q({"id": "mission.fx_a", "giver": "council", "repeat": {"days": 1}})], "주요 임무는 반복하지 않는다", "관리국 반복")
	var a := _q({"id": "quest.fx_a", "unlock": [{"kind": "reported", "quest": "quest.fx_b"}]})
	var b := _q({"id": "quest.fx_b", "unlock": [{"kind": "reported", "quest": "quest.fx_a"}]})
	_expect([a, b], "reported 조건이 고리다", "둘 사이 고리")
	_expect([_q({"unlock": [{"kind": "reported", "quest": "quest.fx_a"}]})], "자기 자신을", "자기 조건")
	_expect([_q({"unlock": [{"kind": "reported", "quest": "quest.nope"}]})], "의뢰 quest.nope 가 없다", "없는 의뢰 조건")
	_expect([_q({"objective": {"kind": "deliver", "item": "key.moss_card", "count": 1}})], "귀중품은 건넬 수 없다", "귀중품 납품")
	var f1 := _q({"id": "quest.fx_a", "reward": {"money": 0, "exp": 0, "items": [], "flags": ["permit.fx"]}})
	var f2 := _q({"id": "quest.fx_b", "reward": {"money": 0, "exp": 0, "items": [], "flags": ["permit.fx"]}})
	_expect([f1, f2], "이미 quest.fx_a 가 준다", "플래그 출처 둘")
	_expect([_q({"reward": {"money": 0, "exp": 0, "items": [{"item": "key.moss_card", "count": 1}], "flags": []}})], "상자에서만 얻는다", "귀중품 보수")
	_expect([_q({"reward": {"money": 0, "exp": 0, "items": [], "flags": ["Permit"]}})], "꼴이 아니다", "플래그 꼴")


## D4 (M-QD4 비워 둔 자리를 받음, M-QD8 출현 표에 없는 적을 받음): 목표 참조.
func test_objective_refs() -> void:
	_expect([_q({"objective": {"kind": "reach", "floor": "b3f", "at": [4, 2], "where_key": "quest.boss_seal.where"}})], "비워 둔 자리", "B3F 보스 방 안")
	_expect([_q({"objective": {"kind": "reach", "floor": "b1f", "at": [0, 0], "where_key": "quest.boss_seal.where"}})], "설 수 있는 칸이 아니다", "벽 칸")
	_expect([_q({"objective": {"kind": "reach", "floor": "f1_test", "at": [1, 1], "where_key": "quest.boss_seal.where"}})], "층 f1_test 가 묶음에 없다", "묶음 밖 층")
	_expect([_q({"objective": {"kind": "kill", "enemy": "enemy.foe_ether_ram", "count": 1}})], "출현 표에 없다", "FOE 적을 kill 로")
	_expect([_q({"objective": {"kind": "kill", "enemy": "enemy.nope", "count": 1}})], "정의에 없다", "없는 적")
	_expect([_q({"objective": {"kind": "foe", "foe": "foe.nope", "count": 1}})], "정의에 없다", "없는 FOE")
	_expect([_q({"unlock": [{"kind": "level", "min": 31}]})], "상한 30", "레벨 상한 위")
	_expect([_q({"unlock": [{"kind": "visited", "floor": "f2_test"}]})], "층 f2_test 가 묶음에 없다", "묶음 밖 층 조건")
	check_eq(_errors([_q({"objective": {"kind": "reach", "floor": "b3f", "at": [9, 2], "where_key": "quest.boss_seal.where"}})]), [] as Array[String], "봉인 앞 9:2 는 된다")


## D5 (M-QD7 needs 를 주는 의뢰를 보지 않음): 층 계단 needs 와 묶음 정의. 의뢰 없이 needs 가 있으면 오류, 있으면 정의가 생긴다.
func test_needs_need_a_quest() -> void:
	var fr := FloorLoader.load_set(DungeonScreen.LABYRINTH_PATH)
	check(fr.ok() and fr.quests == "res://data/quests/stratum1.json", "게임 묶음의 quests 키 %s" % str(fr.errors))
	var db := BattleDb.load_dir("res://data")
	var none := GameDefs.from_parts(fr.floors, PartyData.read_path(Fx.PARTY_PATH), db, null, true, fr.entrance, null)
	check(not none.ok() and none.errors.any(func(e: String) -> bool: return e.contains("needs permit.b2f 를 주는 의뢰가 없다")), "의뢰 없는 needs: %s" % str(none.errors))
	var with := GameDefs.from_parts(fr.floors, PartyData.read_path(Fx.PARTY_PATH), db, null, true, fr.entrance, QuestDb.load_path(fr.quests))
	check(with.ok() and with.defs.quests.order.size() == 5, "의뢰가 있으면 된다 %s" % str(with.errors))


## D6 (M-QD11 needs 꼴을 보지 않음, M-QD12 올라가는 계단 needs 를 받음): 층 파일의 stairs.needs 형식.
func test_needs_format() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/floors/b1f.json"))
	var bad := base.duplicate(true)
	bad["stairs"][0]["needs"] = 3
	var r := FloorLoader.parse_text(JSON.stringify(bad), "b1f.json")
	check(r.errors.any(func(e: String) -> bool: return e.contains("needs 는 진행 플래그")), "needs 가 글이 아니다 %s" % str(r.errors))
	for word in ["permit", "Permit.b2f", "permit.", "permit b2f"]:
		bad["stairs"][0]["needs"] = word
		r = FloorLoader.parse_text(JSON.stringify(bad), "b1f.json")
		check(r.errors.any(func(e: String) -> bool: return e.contains("needs 는 진행 플래그")), "needs 꼴이 아니다(%s) %s" % [word, str(r.errors)])
	var up := base.duplicate(true)
	up["stairs"][0]["way"] = "up"
	r = FloorLoader.parse_text(JSON.stringify(up), "b1f.json")
	check(r.errors.any(func(e: String) -> bool: return e.contains("needs 는 내려가는 계단에만")), "올라가는 계단의 needs %s" % str(r.errors))
	r = FloorLoader.parse_text(JSON.stringify(base), "b1f.json")
	check(r.ok() and r.floor_def.stair_at(Vector2i(17, 1)).needs == "permit.b2f", "실제 B1F 는 된다 %s" % str(r.errors))
