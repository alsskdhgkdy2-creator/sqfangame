## 일반 적 둘의 저장(M3 A3c 설계 §4·§7.1 S1~S4): 새 편성의 전투 중 저장이 실제 규칙으로 왕복되고 이어 가면 같은 사건, 적끼리 건 강화가 저장에 남고,
## HEAD(ce0ed44) 가 만든 옛 B2F/B3F 편성 전투 저장이 지금도 같은 글이며 읽히고, 새 편성 id 는 HEAD 가 깨끗한 필드 오류로 거부한다(저장 판 13 그대로).
## HEAD 값의 생성기: /tmp/sqf_a3c/gen_head_saves.gd 를 git archive 한 HEAD 에서 돌린 결과(보고서에 로그).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const F_SERPENTS := "formation.b2.firefly_serpents"
const F_WISP := "formation.b2.wisp_moles"
const F_MIX := "formation.b3.beetle_firefly_wisp"
const F_WISPS := "formation.b3.wisps_moles"
const SIGNAL := "skill.enemy.glow_signal"

## 생성기와 같은 길: 새 게임(시드 7) → 그 층 도착 칸으로 → 편성을 열고 → 파티 전원 방어 한 턴. 옛 편성 battle 글(키 정렬 JSON)의 sha256.
const HEAD_BATTLE_SHA := {
	"formation.b2.serpents_moth": "e0f4bac82cadab39cfd8c0526d386c02f6d9496097a4af1f42a122d0add4ecfe",
	"formation.b2.moles_bloom": "6cc121d378640bb4b45827376ce4fe0b66bc8e453a5381516b17a05d0dada4e3",
	"formation.b2.moths_beetle": "eb9f95464b93cb3c467aaba13670784d7ed7ba424a0ed76b83fea7e035f7c8dd",
	"formation.b2.serpent_moles": "3257fa9ef9466ebfce46de4e177f6f4c10d90eb7a3c93460fd95e38b4b8e98c6",
	"formation.b2.beetles": "de1e75a45bf962e86b9af1fcbb3040b5c9662f4bae9dab398b4dab3e491df6b0",
	"formation.b3.beetles_serpent": "f2cad5e7871576696059b7e0ae8a72103c74e9a8c6bb3bcaaafc94302a43bdb7",
	"formation.b3.moles_moths": "dd8bacf35a74ff2725640ddb63d590785b40096214ec15164c8dc2aaaf714199",
	"formation.b3.serpents_bloom": "94ee1e508eeb7babde2b9f829e71b698d61fbc686cc94dfe25d451423a65e90d",
	"formation.b3.beetle_moles": "8eadc5953b799593f1c8bf3b30b549f9c3c565b31360c76d37404917f5b8b556",
	"formation.b3.full_mix": "e8491c5d0b47a09df1f1e7c8c72fc51fa47fdfa56f226388b7e5b0d804b8cfcf"}
## HEAD 가 쓴 battle 글 둘(층마다 하나): 지금 코드가 그대로 읽는다.
const HEAD_FULL := {
	"formation.b2.moths_beetle": '{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78.0,"kill":null,"resist":{}}],"formation":"formation.b2.moths_beetle","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":{"damage":6.0,"id":"poison","turns":2.0},"binds":{},"buffs":[],"debuffs":[],"resist":{"poison":300.0}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1.0,"turn":1.0}',
	"formation.b3.full_mix": '{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":90.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":120.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":150.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78.0,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":104.0,"kill":null,"resist":{}}],"formation":"formation.b3.full_mix","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":{"id":"sleep","turns":1.0},"binds":{},"buffs":[],"debuffs":[],"resist":{"sleep":300.0}},{"ailment":{"id":"sleep","turns":1.0},"binds":{},"buffs":[],"debuffs":[],"resist":{"paralysis":200.0,"sleep":300.0}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1.0,"turn":1.0}'}
## HEAD 가 새 편성 id 를 넣은 B2F 전투 저장에 내는 오류(생성기 REJECT 줄).
const HEAD_REJECT := "battle.formation: 이 층 출현 표의 편성이 아니다"

var _defs: GameDefs


func _arbor() -> GameDefs:
	if _defs == null:
		_defs = Fx.arbor()
	return _defs


func _at_floor(formation: String) -> Array:
	return ["b2f", Vector2i(17, 1)] if formation.begins_with("formation.b2.") else ["b3f", Vector2i(17, 18)]


## 생성기(/tmp/sqf_a3c/gen_head_saves.gd)와 같은 길의 상태. turns 번 더 전원 방어를 낸다.
func _state(formation: String, extra_turns: int = 0, lv: int = 1) -> ExplorationState:
	var where := _at_floor(formation)
	var s := ExplorationRules.new_game(_arbor(), 7, "floor")
	if lv > 1:
		for i in s.party.members.size():
			GrowthRules.grant_exp(s, i, s.defs.battle.growth.cum(lv))
		for m in s.party.members:
			m.hp = m.max_hp
			m.tp = m.max_tp
	Fx.to_floor(s, where[0], where[1], Dir.N)
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, formation)
	assert(st[0]["type"] == "battle_start", str(st))
	BattleRules.submit(s, Fx.cmds(s))
	for i in extra_turns:
		if s.battle != null:
			BattleRules.submit(s, Fx.cmds(s))
	return s


func _doc(s: ExplorationState) -> Dictionary:
	return JSON.parse_string(SaveCodec.encode(s))


## S1 (M-S2 B2F 표에서 옛 편성을 뺌은 S3 가 본다): 새 편성 넷 각각 Lv 8 파티로 전원 방어 여러 턴, 매 턴 저장 → 읽기 → 읽은 쪽을 이어 간다.
## 원래 상태와 읽은 상태가 같은 해시, 이어 낸 턴의 사건 글도 같다(수액 반딧불의 치료·점멸 신호가 섞인 턴 포함).
func test_new_formations_round_trip_and_continue() -> void:
	timeout_sec = 120.0
	for fid in [F_SERPENTS, F_WISP, F_MIX, F_WISPS]:
		var s := _state(fid, 0, 8)
		var saves := 0
		for turn in 6:
			if s.battle == null:
				break
			# 둘째 턴부터 아군 하나를 다치게 해 감로가 나오게 한다(첫 턴은 모두 건강: 턴 0 점멸 신호).
			if turn == 1:
				s.battle.enemies[0].hp = maxi(1, s.battle.enemies[0].hp * 4 / 10)
			var text := SaveCodec.encode(s)
			var r := SaveCodec.decode(text, _arbor())
			check(r.ok(), "%s 턴 %d: 읽힌다 %s" % [fid, turn, r.error])
			if not r.ok():
				break
			saves += 1
			check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "%s 턴 %d: 읽은 상태 = 원래 상태 해시" % [fid, turn])
			var ev_a := BattleRules.submit(s, Fx.cmds(s))
			var ev_b := BattleRules.submit(r.state, Fx.cmds(r.state))
			check_eq(Fx.events_text(ev_b), Fx.events_text(ev_a), "%s 턴 %d: 읽은 쪽을 이어 간 사건 = 원래 사건" % [fid, turn])
			s = r.state if turn % 2 == 0 else s
		check(saves >= 3, "%s: 적어도 세 번 저장·읽기 (%d)" % [fid, saves])


## S2 (M-S1 저장 검사가 다른 유닛이 건 적의 강화를 거부): 점멸 신호가 건 강화는 적 셋 모두의 buffs 에 파일로 남고 읽힌다. 값 범위 밖은 거부.
func test_enemy_buff_from_another_unit_survives_save() -> void:
	var s := _arbor()
	var st := _state(F_SERPENTS)  # 턴 0 에 submit 한 번: 점멸 신호(턴 %3 == 0)가 나가 강화가 1턴 남았다
	var doc := _doc(st)
	var enemies: Array = doc["state"]["battle"]["enemies"]
	check_eq(enemies.size(), 3, "적 셋")
	var seqs := {}
	for e in enemies:
		check_eq(e["buffs"].size(), 1, "적마다 강화 하나")
		var b: Dictionary = e["buffs"][0]
		check_eq([b["id"], b["kind"], int(b["value"]), int(b["turns"])], [SIGNAL, "phys_atk", 1250, 1], "강화 값")
		seqs[int(b["seq"])] = true
	check_eq(seqs.size(), 3, "seq 가 겹치지 않는다")
	var r := SaveCodec.decode(JSON.stringify(doc), s)
	check(r.ok(), "다른 유닛이 건 적의 강화가 읽힌다 %s" % r.error)
	if r.ok():
		check_eq(r.state.battle.enemies.map(func(u: BattleUnit) -> int: return u.buffs.size()), [1, 1, 1], "읽은 뒤에도 적 셋의 강화")
	doc["state"]["battle"]["enemies"][1]["buffs"][0]["value"] = 99999
	check(not SaveCodec.decode(JSON.stringify(doc), s).ok(), "강화 값이 범위 밖이면 거부")


func _battle_sha(s: ExplorationState) -> String:
	return JSON.stringify(_doc(s)["state"]["battle"], "", true).sha256_text()


## S3 (M-S2 B2F 표에서 옛 편성 `beetles` 를 뺌, 옛 편성 내용을 고침): HEAD 가 같은 길로 쓴 옛 열 편성 전투 저장의 battle 글이 지금 코드의 글과 바이트까지 같고(sha256),
## HEAD 가 쓴 전체 글 둘(층마다 하나)을 지금 코드가 그대로 읽는다 = HEAD 의 합법 저장이 새 검사에 걸리지 않는다(설계 §4 역방향).
func test_head_battle_saves_stay_identical_and_load() -> void:
	timeout_sec = 120.0
	for fid in HEAD_BATTLE_SHA:
		var s := _state(fid)
		check_eq(_battle_sha(s), HEAD_BATTLE_SHA[fid], "%s: HEAD 와 같은 battle 글" % fid)
		var r := SaveCodec.decode(SaveCodec.encode(s), _arbor())
		check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "%s: 왕복 %s" % [fid, r.error])
	for fid in HEAD_FULL:
		var s := _state(fid)
		var doc := _doc(s)
		doc["state"]["battle"] = JSON.parse_string(HEAD_FULL[fid])
		var r := SaveCodec.decode(JSON.stringify(doc), _arbor())
		check(r.ok(), "%s: HEAD 가 쓴 전체 battle 글을 읽는다 %s" % [fid, r.error])
		if r.ok():
			check_eq(SaveCodec.state_hash(r.state), SaveCodec.state_hash(s), "%s: 읽은 상태 = 같은 길의 상태" % fid)


## S4: 새 편성 id 는 HEAD 의 출현 표에 없어 HEAD 가 위 문구로 거부한다(생성기 로그). 지금 코드도 표에 없는 id 를 같은 문구로 거부한다(그 검사는 바뀌지 않았다).
## 저장 판은 13 그대로, 규칙 m3b.
func test_off_table_formation_message_and_schema() -> void:
	var s := _state("formation.b2.beetles")
	var doc := _doc(s)
	check_eq([doc["schema"], doc["rules"]], [13.0, "m3b"], "저장 판 13 · m3b 그대로")
	doc["state"]["battle"]["formation"] = "formation.b3.full_mix"  # 5 칸: 길이가 맞지 않아도 표 검사가 먼저 걸린다
	var r := SaveCodec.decode(JSON.stringify(doc), _arbor())
	check(not r.ok() and r.error.contains(HEAD_REJECT), "표에 없는 편성: 「%s」 포함 %s" % [HEAD_REJECT, r.error])
	# 새 편성은 지금 표에 있다: 같은 문서의 편성만 새 id 로(칸 수 3)바꾸면 읽힌다.
	var s2 := _state(F_SERPENTS)
	var r2 := SaveCodec.decode(SaveCodec.encode(s2), _arbor())
	check(r2.ok(), "새 편성 전투 저장이 읽힌다 %s" % r2.error)
