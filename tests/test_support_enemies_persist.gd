## 새 일반 적 둘의 전투가 실제 저장 길을 지난다(M3 A3c 검토 F1, 교훈 1): 실제 미궁 화면(DungeonScreen)에서 새 편성의 전투를 열고 BattleLayer 로 실제 한 턴을 내면
## 화면이 자동 저장을 하고(세대·파일), 같은 저장 폴더로 화면을 다시 열면 같은 전투가 이어진다(해시·턴·적 HP·점멸 신호 강화·감로 치료),
## 이겨서 정산하면 승리(전투 닫힘·가방의 발광 인분)가 저장에 남는다. 일반 적의 처치 기록은 저장하지 않는다(FOE·보스 기록과 의뢰 세기만 남는다):
## 처치 목록은 그 턴의 battle_end 사건에서만 보고, 다시 연 뒤에는 전투 닫힘과 가방만 본다. 저장 갈고리를 비우는 시험이 아니다.
## 시험마다 죽이는 변이(M-S4: 새 편성일 때만 save_hook 을 부르지 않음)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const SIGNAL := "skill.enemy.glow_signal"
const GLOW := "item.glow_scale"
## 편성 → [층, 도착 칸, 반딧불이 있는가, 처치 기록에 오를 새 적].
const CASES := {
	"formation.b2.firefly_serpents": ["b2f", Vector2i(17, 1), true, "enemy.sap_firefly"],
	"formation.b2.wisp_moles": ["b2f", Vector2i(17, 1), false, "enemy.flicker_wisp"],
	"formation.b3.beetle_firefly_wisp": ["b3f", Vector2i(17, 18), true, "enemy.sap_firefly"],
	"formation.b3.wisps_moles": ["b3f", Vector2i(17, 18), false, "enemy.flicker_wisp"],
}

var kit: Kit


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null


## 실제 미궁 화면(시드 seed_value)에서 Lv 8 파티로 formation 의 전투를 연다. 화면이 새 상태를 알도록 _set_state 를 부른다.
func _enter(fid: String, seed_value: int) -> DungeonScreen:
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var screen: DungeonScreen = await kit.open_arbor("native", seed_value)
	var s := screen.state
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, s.defs.battle.growth.cum(8))
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	var where: Array = CASES[fid]
	Fx.to_floor(s, where[0], where[1], Dir.N)
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, fid)
	assert(st[0]["type"] == "battle_start", str(st))
	screen._set_state(s)
	screen._check_windows()
	await kit.frames(2)
	return screen


func _reopen() -> DungeonScreen:
	return await kit.reopen(func(sc: DungeonScreen) -> void: sc.labyrinth_path = DungeonScreen.LABYRINTH_PATH)


func _auto_doc(screen: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(screen.store.main_path(SaveStore.AUTO)))


## 실제 턴 하나(전원 방어 또는 주어진 명령): 화면의 자동 저장이 정확히 한 번 늘고 오류가 없다. 그 저장 문서를 돌려준다.
func _turn(screen: DungeonScreen, fid: String, label: String, commands: Array) -> Dictionary:
	var saves := screen.autosave_count
	var gen := kit.auto_generation()
	screen.battle_layer.handle("commands", commands)
	await kit.frames(2)
	check_eq([screen.autosave_count, screen.last_autosave_error], [saves + 1, ""], "%s %s: 턴 하나에 자동 저장 하나, 오류 없음" % [fid, label])
	check_eq(kit.auto_generation(), gen + 1, "%s %s: 저장 파일 세대가 하나 늘었다" % [fid, label])
	return _auto_doc(screen)


## P1 (M-S4 새 편성일 때 save_hook 을 부르지 않음): 새 편성 넷 각각 — 실제 턴 둘(둘째 턴 앞에 적 0 을 다치게 해 반딧불이 있으면 감로)을 내고 매번 화면을 다시 연다.
## 다시 연 화면은 같은 해시·턴·적 HP, 반딧불이 있으면 점멸 신호 강화가 적 전원에게(저장 문서에도), 감로 회복이 HP 에 남는다.
func test_new_battles_use_the_real_autosave_and_reopen() -> void:
	timeout_sec = 240.0
	for fid in CASES:
		var has_fly: bool = CASES[fid][2]
		var screen := await _enter(fid, 7)
		check(screen.battle_layer.is_open() and screen.state.battle.formation == fid, "%s: 전투 층이 열려 있다" % fid)
		# 턴 0: 모두 건강. 반딧불이 있으면 점멸 신호(턴 %3 == 0)가 적 전원에 걸린다.
		var doc := await _turn(screen, fid, "턴 0", Fx.cmds(screen.state))
		check_eq([doc["state"]["battle"]["formation"], int(doc["state"]["battle"]["turn"])], [fid, 1], "%s: 저장 문서의 편성·턴" % fid)
		var hash0 := kit.hash_now()
		var hp0: Array = screen.state.battle.enemies.map(func(u: BattleUnit) -> int: return u.hp)
		if has_fly:
			for e in doc["state"]["battle"]["enemies"]:
				check_eq(e["buffs"].map(func(b: Dictionary) -> Array: return [b["id"], b["kind"], int(b["value"]), int(b["turns"])]), [[SIGNAL, "phys_atk", 1250, 1]],
					"%s: 저장 문서의 적 강화(점멸 신호)" % fid)
		screen = await _reopen()
		check(screen.battle_layer.is_open() and screen.state.battle != null, "%s 턴 0: 다시 연 화면에 전투가 이어진다" % fid)
		check_eq([kit.hash_now(), screen.state.battle.turn, screen.state.battle.enemies.map(func(u: BattleUnit) -> int: return u.hp)], [hash0, 1, hp0],
			"%s 턴 0: 다시 연 해시·턴·적 HP 가 같다" % fid)
		if has_fly:
			check(screen.state.battle.enemies.all(func(u: BattleUnit) -> bool: return u.buffs.size() == 1 and u.buffs[0]["id"] == SIGNAL), "%s: 다시 연 뒤에도 적 전원에 점멸 신호" % fid)
		# 턴 1: 적 0 을 다치게 한다(시험 준비). 반딧불이 있으면 감로가 그 적을 38 채운다.
		screen.state.battle.enemies[0].hp = 20
		doc = await _turn(screen, fid, "턴 1", Fx.cmds(screen.state))
		var healed := screen.battle_layer.last_events.filter(func(e: Dictionary) -> bool: return e["type"] == "healed")
		if has_fly:
			check_eq(healed.map(func(e: Dictionary) -> Array: return [e["target"]["slot"], e["amount"]]), [[0, 38]], "%s 턴 1: 감로가 적 0 에게 38" % fid)
			check_eq(screen.state.battle.enemies[0].hp, 58, "%s 턴 1: 적 0 의 HP 20 → 58" % fid)
		else:
			check_eq(healed, [] as Array[Dictionary], "%s 턴 1: 반딧불이 없으니 치료가 없다" % fid)
		var hash1 := kit.hash_now()
		var hp1: Array = screen.state.battle.enemies.map(func(u: BattleUnit) -> int: return u.hp)
		check_eq(doc["state"]["battle"]["enemies"].map(func(e: Dictionary) -> int: return int(e["hp"])), hp1, "%s 턴 1: 저장 문서의 적 HP" % fid)
		screen = await _reopen()
		check_eq([kit.hash_now(), screen.state.battle.turn, screen.state.battle.enemies.map(func(u: BattleUnit) -> int: return u.hp)], [hash1, 2, hp1],
			"%s 턴 1: 다시 연 해시·턴·적 HP(치료가 남았다)가 같다" % fid)


## 이겨서 정산한다: 실제 턴으로 적을 쓰러뜨리고(시험 준비로 적 HP 1), 화면 흐름의 battle_end 사건(battle_layer.last_events)에 새 적의 처치가 있고, 같은 상태를 읽어 만든
## 복사본에 같은 명령을 규칙으로 직접 낸 결과(기준)와 화면의 처치 목록·드롭·상태가 같으며, 화면을 다시 열어도 승리가 저장에 남는다: 전투 닫힘, 발광 인분 개수.
## (일반 적의 처치 목록은 저장되지 않는다: 그 턴 사건에서만 본다.) 편성마다 드롭이 한 번이라도 나는 시드(7부터)를 찾는다.
func test_victory_and_drops_survive_reopen() -> void:
	timeout_sec = 300.0
	for fid in CASES:
		var new_enemy: String = CASES[fid][3]
		var dropped := false
		for seed_value in range(7, 15):
			var screen := await _enter(fid, seed_value)
			for u in screen.state.battle.enemies:
				u.hp = 1
			var rule_copy := SaveCodec.decode(SaveCodec.encode(screen.state), screen.state.defs)
			check(rule_copy.ok(), "%s 시드 %d: 복사본이 읽힌다 %s" % [fid, seed_value, rule_copy.error])
			var twin := rule_copy.state
			var kills: Array = []
			var screen_kills: Array = []
			var drops_by_rules := 0
			var turns := 0
			while screen.state.battle != null and turns < 8:
				var cmds := BattlePolicy.choose(screen.state, BattlePolicy.DEFAULT)
				var saves := screen.autosave_count
				var ev_twin := BattleRules.submit(twin, cmds.duplicate(true))
				screen.battle_layer.handle("commands", cmds)
				await kit.frames(2)
				check_eq([screen.autosave_count, screen.last_autosave_error], [saves + 1, ""], "%s 시드 %d: 턴 %d 자동 저장 하나" % [fid, seed_value, turns])
				for e in screen.battle_layer.last_events:
					if e["type"] == "battle_end" and e.has("kills"):
						screen_kills = e["kills"]
				for e in ev_twin:
					if e["type"] == "drop" and e["item"] == GLOW:
						drops_by_rules += int(e["amount"])
					if e["type"] == "battle_end" and e.has("kills"):
						kills = e["kills"]
				turns += 1
			check_eq(screen.state.battle, null, "%s 시드 %d: 전투가 끝났다" % [fid, seed_value])
			check_eq(twin.battle, null, "%s 시드 %d: 규칙 복사본도 끝났다" % [fid, seed_value])
			check_eq(kit.hash_now(), SaveCodec.state_hash(twin), "%s 시드 %d: 화면 상태 = 같은 명령을 규칙에 바로 낸 상태" % [fid, seed_value])
			check(screen_kills.has(new_enemy), "%s 시드 %d: 화면 흐름의 battle_end 처치 목록에 %s %s" % [fid, seed_value, new_enemy, str(screen_kills)])
			check_eq(screen_kills, kills, "%s 시드 %d: 화면의 처치 목록 = 규칙 복사본의 처치 목록" % [fid, seed_value])
			var shown_glow := int(screen.state.materials.get(GLOW, 0))
			check_eq(shown_glow, drops_by_rules, "%s 시드 %d: 가방의 발광 인분 = 규칙이 낸 드롭" % [fid, seed_value])
			var doc := _auto_doc(screen)
			check_eq([doc["state"]["battle"], int(doc["state"]["materials"].get(GLOW, 0))], [null, shown_glow], "%s 시드 %d: 저장 문서에 전투 없음, 발광 인분 %d" % [fid, seed_value, shown_glow])
			var hash_end := kit.hash_now()
			screen = await _reopen()
			check_eq([kit.hash_now(), screen.state.battle, int(screen.state.materials.get(GLOW, 0)), screen.state.encounter.pending],
				[hash_end, null, shown_glow, false], "%s 시드 %d: 다시 열어도 승리·드롭이 남는다" % [fid, seed_value])
			if shown_glow > 0:
				dropped = true
				break
		check(dropped, "%s: 시드 7~14 가운데 발광 인분이 떨어진 판이 있다(저장에 남은 개수를 봄)" % fid)
