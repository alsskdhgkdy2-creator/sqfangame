## 일반 적 둘의 규칙(M3 A3c 설계 §2·§7.1 A1~A7): ally_hp_below 경계, lowest_hp_ratio 대상, 수액 반딧불의 감로·점멸 신호·발광 침, 머리 봉인,
## 명멸 도깨비불의 불티 세례(INT·열 공격)·불 무효, 처치 드롭. 실제 게임 묶음(Fx.arbor())의 새 편성을 쓴다. 시험마다 죽이는 변이(M-…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const F_SERPENTS := "formation.b2.firefly_serpents"  # 뱀 0 · 뱀 1(전열) · 반딧불 2(후열)
const F_WISP := "formation.b2.wisp_moles"  # 두더지 0 · 두더지 1 · 도깨비불 2
const F_MIX := "formation.b3.beetle_firefly_wisp"  # 갑충 0 · 뱀 1 · 반딧불 2 · 도깨비불 3
const DRIP := "skill.enemy.sap_drip"
const SIGNAL := "skill.enemy.glow_signal"
const STING := "skill.enemy.glow_sting"
const FIRE := "skill.enemy.will_fire"
const JAM := "skill.enemy.flicker_jam"

var _defs: GameDefs


func _arbor() -> GameDefs:
	if _defs == null:
		_defs = Fx.arbor()
	return _defs


## 게임 묶음 새 게임에서 formation 을 연다(파티 Lv lv, HP·TP 가득, 적 HP 가득).
func _battle(formation: String, seed_value: int = 1, lv: int = 1) -> ExplorationState:
	var s := ExplorationRules.new_game(_arbor(), seed_value, "floor")
	var need := s.defs.battle.growth.cum(lv)
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, need)
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, formation)
	assert(st[0]["type"] == "battle_start", str(st))
	return s


func _choice(s: ExplorationState, slot: int) -> Variant:
	return EnemyAi.choose(s, s.battle.enemies[slot], [] as Array[Dictionary])


func _skill_of(c: Variant) -> String:
	return c["skill"].id if c != null else "idle"


func _actions(events: Array[Dictionary], side: String, slot: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == "action" and e["unit"] == {"side": side, "slot": slot})


## A1 (M-A1 경계를 <= 로, M-A2 자기 자신을 세지 않음, M-A3 쓰러진 아군을 셈): ally_hp_below 600 은 살아 있는 아군(자기 포함)이 HP 600‰ 미만일 때만.
func test_ally_hp_below_boundary() -> void:
	var s := _battle(F_SERPENTS)
	var b := s.battle
	var fly := b.enemies[2]
	var cond := {"ally_hp_below": 600}
	check(not EnemyAi.matches(cond, fly, b), "모두 가득: 아님")
	b.enemies[0].hp = 72  # 72/120 = 600‰ 딱: 미만이 아니다
	check(not EnemyAi.matches(cond, fly, b), "뱀 72/120 = 600‰ 경계는 미만이 아니다")
	b.enemies[0].hp = 71
	check(EnemyAi.matches(cond, fly, b), "뱀 71/120 = 591‰ 는 미만")
	b.enemies[0].hp = 120
	fly.hp = 44  # 44/72 = 611‰
	check(not EnemyAi.matches(cond, fly, b), "자기 44/72 = 611‰ 는 아님")
	fly.hp = 43  # 43/72 = 597‰
	check(EnemyAi.matches(cond, fly, b), "자기 43/72 = 597‰ 는 미만: 자기도 센다")
	fly.hp = 72
	b.enemies[1].hp = 0
	check(not EnemyAi.matches(cond, fly, b), "쓰러진 아군(HP 0)은 세지 않는다")
	b.enemies[1].hp = 100
	b.enemies[0].hp = 50
	b.enemies[0].ailment = "sleep"
	b.enemies[0].ailment_turns = 2
	check(EnemyAi.matches(cond, fly, b), "수면 중인 아군도 센다")
	b.enemies[0].ailment = ""
	b.enemies[0].binds["leg"] = 2
	check(EnemyAi.matches(cond, fly, b), "봉인된 아군도 센다")
	# 조건은 행동하는 유닛의 같은 편만 본다. 적 0 이 다친 채(50/120)라도 파티 유닛은 파티가 건강하면 아니고, 파티의 다른 대원이 다치면(1/최대) 맞는다.
	check(not EnemyAi.matches(cond, b.party[0], b), "파티 유닛: 파티는 건강하고 다친 쪽은 적 편이라 아니다")
	b.party[1].hp = 1
	check(EnemyAi.matches(cond, b.party[0], b), "파티 유닛: 같은 편(파티)의 다른 대원이 다쳤으면 맞는다")
	b.party[0].hp = 1
	b.enemies[0].hp = 120
	check(not EnemyAi.matches(cond, fly, b), "적 유닛: 파티가 다친 것은 세지 않는다(적 편은 모두 건강)")


## A2 (M-A4 대상 정책이 절대 HP, M-A5 같은 비율일 때 큰 칸, M-A6 난수를 뽑음): lowest_hp_ratio 는 HP 비율이 가장 낮은 유닛, 같으면 작은 칸, 난수 없음.
func test_lowest_hp_ratio_target() -> void:
	var s := _battle(F_MIX)
	var b := s.battle
	# 갑충 90/208(43 %), 뱀 120/120, 반딧불 72/72, 도깨비불 60/60: 절대 HP 최소는 도깨비불(60), 비율 최소는 갑충.
	b.enemies[0].hp = 90
	var fly := b.enemies[2]
	var st := s.rng.get_state()
	var c: Variant = _choice(s, 2)
	check_eq([_skill_of(c), c["target"]], [DRIP, 0], "감로는 비율이 가장 낮은 갑충(칸 0)")
	check_eq(s.rng.get_state(), st, "대상 정책 lowest_hp_ratio 와 후보 하나: 난수를 뽑지 않는다")
	check_eq(EnemyAi.choose_target(s, fly, s.defs.battle.skill(DRIP), "lowest_hp"), 3, "대조: 옛 lowest_hp 는 절대 HP 최소(도깨비불 칸 3)")
	check_eq(EnemyAi.choose_target(s, fly, s.defs.battle.skill(DRIP), "lowest_hp_ratio"), 0, "lowest_hp_ratio 직접")
	# 같은 비율이면 작은 칸: 뱀 60/120 = 갑충 104/208 = 50 %.
	b.enemies[0].hp = 104
	b.enemies[1].hp = 60
	check_eq(EnemyAi.choose_target(s, fly, s.defs.battle.skill(DRIP), "lowest_hp_ratio"), 0, "같은 50 %: 작은 칸(갑충 칸 0)")
	b.enemies[0].hp = 105
	check_eq(EnemyAi.choose_target(s, fly, s.defs.battle.skill(DRIP), "lowest_hp_ratio"), 1, "갑충 105/208 = 50.5 % > 뱀 50 %: 뱀 칸 1")
	# 쓰러진 유닛은 후보가 아니다.
	b.enemies[1].hp = 0
	check_eq(EnemyAi.choose_target(s, fly, s.defs.battle.skill(DRIP), "lowest_hp_ratio"), 0, "HP 0 인 뱀은 대상이 아니다")


## A3 (M-D4 감로 base, M-D5 문턱, M-D6 대상 ally_other): 반딧불의 세 규칙. 아군(자기 포함)이 600‰ 미만이면 감로, 아니면 턴 %3 == 0 에 점멸 신호, 나머지는 발광 침.
func test_firefly_rules_and_heal_amount() -> void:
	var s := _battle(F_SERPENTS, 3)
	var b := s.battle
	for t in 7:
		b.turn = t
		var want := SIGNAL if t % 3 == 0 else STING
		var got := {}
		for sd in 12:
			s.rng.set_state(100 + sd)
			got[_skill_of(_choice(s, 2))] = true
		check_eq(got.keys(), [want], "모두 건강한 턴 %d: %s" % [t, want])
	b.turn = 0
	b.enemies[0].hp = 71
	check_eq(_skill_of(_choice(s, 2)), DRIP, "아군 591‰: 턴 0(점멸 신호 차례)이어도 감로가 점멸 신호보다 앞선다")
	b.enemies[0].hp = 72
	check_eq(_skill_of(_choice(s, 2)), SIGNAL, "600‰ 딱이면 감로가 아니다")
	# 실제 턴: 뱀 0 이 40/120 이면 반딧불이 38(= 18 + WIS 20 × 100 %)을 채운다. 파티는 모두 방어.
	b.enemies[0].hp = 40
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var acts := _actions(ev, "enemy", 2)
	check_eq(acts.map(func(a: Dictionary) -> String: return a["skill"]), [DRIP], "반딧불 행동 하나: 감로")
	check_eq(acts[0]["targets"], [{"side": "enemy", "slot": 0}], "감로 대상: 비율이 가장 낮은 뱀 0")
	var healed := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "healed")
	check_eq(healed.map(func(e: Dictionary) -> Array: return [e["unit"], e["target"], e["amount"], e["hp"]]),
		[[{"side": "enemy", "slot": 2}, {"side": "enemy", "slot": 0}, 38, 78]], "회복 이벤트: 38 → HP 78")
	check_eq(b.enemies[0].hp, 78, "뱀 0 의 HP 78")
	# 회복량은 빠진 만큼으로 잘린다.
	b.enemies[0].hp = 100
	b.enemies[1].hp = 50
	b.enemies[2].hp = 72
	ev = BattleRules.submit(s, Fx.cmds(s))
	var h2 := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "healed")
	check_eq(h2.map(func(e: Dictionary) -> Array: return [e["target"]["slot"], e["amount"]]), [[1, 38]], "뱀 1(50/120)에게 38")
	b.enemies[1].hp = 100
	b.enemies[0].hp = 50
	b.turn = 4
	# 고른 대상이 같은 턴에 쓰러졌으면 살아 있는 비율 최소 아군으로 다시 고른다(옛 retarget).
	b.enemies[0].hp = 0
	b.enemies[1].hp = 30
	var tg := BattleRules._resolve_targets(b, b.enemies[2], s.defs.battle.skill(DRIP), 0)
	check_eq(tg.map(func(u: BattleUnit) -> int: return u.slot), [1], "쓰러진 대상 대신 비율 최소 아군")


## A4 (M-D6 ally_all → ally_other, M-D8 turns 2 → 3): 점멸 신호(턴 %3 == 0)는 살아 있는 적 전원(자기 포함)에 phys_atk 1250, 2턴. 한 턴 뒤 1턴, 두 턴 뒤 풀린다.
func test_glow_signal_buffs_every_enemy_ally() -> void:
	var s := _battle(F_SERPENTS, 5)
	var b := s.battle
	b.turn = 0
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var buffed := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "buffed")
	check_eq(buffed.map(func(e: Dictionary) -> int: return e["target"]["slot"]), [0, 1, 2], "점멸 신호: 적 셋 전원(반딧불 자신 포함), 칸 차례")
	check(buffed.all(func(e: Dictionary) -> bool: return e["target"]["side"] == "enemy" and e["list"] == "buffs"), "적 편의 강화 칸")
	for u in b.enemies:
		check_eq(u.buffs.map(func(x: Dictionary) -> Array: return [x["id"], x["kind"], x["value"], x["turns"]]), [[SIGNAL, "phys_atk", 1250, 1]],
			"적 %d: 강화 1250, 이 턴 끝에 2 → 1" % u.slot)
	check_eq(b.party[0].buffs, [] as Array[Dictionary], "파티는 걸리지 않는다")
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq(ev.filter(func(e: Dictionary) -> bool: return e["type"] == "expired" and e["what"] == "buff").size(), 3, "다음 턴 끝에 셋 모두 풀린다")
	for u in b.enemies:
		check_eq(u.buffs, [] as Array[Dictionary], "풀림 %d" % u.slot)
	# 같은 효과를 다시 걸면 남은 턴이 새로 시작한다(refreshed).
	b.turn = 3
	b.enemies[1].buffs.append({"id": SIGNAL, "kind": "phys_atk", "value": 1250, "turns": 1, "seq": 1})
	b.seq = 2
	ev = BattleRules.submit(s, Fx.cmds(s))
	var again := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "buffed" and e["target"]["slot"] == 1)
	check_eq(again.map(func(e: Dictionary) -> bool: return e["refreshed"]), [true], "이미 걸린 칸 1 은 refreshed")
	# 강화는 실제로 적의 물리 피해를 키운다: 강화 칸이 있으면 atk_muls 에 1250.
	var s2 := _battle(F_SERPENTS, 5)
	s2.battle.enemies[0].buffs.append({"id": SIGNAL, "kind": "phys_atk", "value": 1250, "turns": 2, "seq": 1})
	var u := s2.battle.enemies[0]
	var coil := s2.defs.battle.skill("skill.enemy.coil")  # 물리(타격). 번개 물기는 속성이라 elem_atk 를 본다.
	var inputs := BattleRules.damage_inputs(s2.battle, s2.defs.battle.rules, u, coil, coil.level_row(1), s2.battle.party[0], false, 1000)
	check_eq(inputs["atk_muls"], [1250], "강화한 뱀의 공격 곱 1250")


## A5 (M-D9 감로·점멸 신호의 parts 를 비움): 머리 봉인된 반딧불은 두 보조 스킬을 쓰지 못한다(행동은 실패), 발광 침은 쓴다. 머리 봉인된 도깨비불은 홀림불을 고르지 않는다.
func test_head_bind() -> void:
	var s := _battle(F_SERPENTS, 7)
	var b := s.battle
	var fly := b.enemies[2]
	fly.binds["head"] = 3
	b.turn = 0
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq(_actions(ev, "enemy", 2), [], "머리 봉인: 행동 이벤트 없음(실패)")
	var failed := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "failed" and e["unit"] == fly.ref())
	check_eq(failed.map(func(e: Dictionary) -> Array: return [e["reason"], e["skill"]]), [["bound_head", SIGNAL]],
		"규칙 2 는 점멸 신호를 고르고(대체할 스킬이 그 규칙에 없다) 연산부 잠금으로 실패")
	check_eq(b.enemies[0].buffs, [] as Array[Dictionary], "아무도 강화받지 않았다")
	b.turn = 1
	fly.binds["head"] = 3
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq(_actions(ev, "enemy", 2).map(func(a: Dictionary) -> String: return a["skill"]), [STING], "턴 1: 발광 침은 머리를 쓰지 않아 쓴다")
	# 도깨비불: 머리 봉인이면 홀림불을 고르지 않는다(on_bound switch).
	var w := _battle(F_WISP, 9)
	var wisp := w.battle.enemies[2]
	var free := {}
	var plain := {}
	for sd in 24:
		w.rng.set_state(500 + sd)
		plain[_skill_of(_choice(w, 2))] = true
		wisp.binds["head"] = 2
		w.rng.set_state(500 + sd)
		free[_skill_of(_choice(w, 2))] = true
		wisp.binds.clear()
	var p := plain.keys()
	p.sort()
	check_eq([p, free.keys()], [[JAM, FIRE], [FIRE]], "봉인 없으면 둘 다(홀림불, 불티 세례), 머리 봉인이면 불티 세례만")


## A6 (M-D7 불 내성 0 → 250): 도깨비불. 불티 세례는 INT 30 · 위력 60 · 불, 한 열 전체에 닿는다. 불 무효, 얼음 약점.
func test_wisp_fire_row_and_resists() -> void:
	# Lv 1 파티의 방어 = WIS + 장비 마법방어: 기사 13+4, 검객 10+2, 의무병 20+5, 술사 17+6 → base = 30·30·60 / (100·(30 + D)) 의 몫.
	var d_by_slot := {0: [17, 11], 1: [12, 12], 2: [12, 12], 3: [25, 9], 4: [23, 10]}
	var rows := {}
	for sd in 60:
		var w := _battle(F_WISP, 200 + sd)
		var wisp := w.battle.enemies[2]
		w.battle.enemies[0].hp = 150
		var ev := BattleRules.submit(w, Fx.cmds(w))
		if _actions(ev, "enemy", 2).map(func(a: Dictionary) -> String: return a["skill"]) != [FIRE]:
			continue
		var hits := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "damaged" and e["unit"] == wisp.ref())
		var missed := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "missed" and e["unit"] == wisp.ref())
		var slots: Array = (hits + missed).map(func(e: Dictionary) -> int: return e["target"]["slot"])
		slots.sort()
		rows[str(slots)] = true
		check(slots == [0, 1, 2] or slots == [3, 4], "불티 세례는 한 열 전체: %s" % str(slots))
		for h in hits:
			var want: Array = d_by_slot[h["target"]["slot"]]
			check_eq([h["calc"]["A"], h["calc"]["D"], h["calc"]["base"], h["element"]], [30, want[0], want[1], "fire"],
				"칸 %d: A = 도깨비불 INT 30, D = 지혜 + 마법방어, base" % h["target"]["slot"])
	check_eq(rows.keys().size(), 2, "60 판에서 앞줄·뒷줄 둘 다 맞혔다 %s" % str(rows.keys()))
	# 내성: 불 무효, 얼음 ×1.5, 베기 ×0.7.
	var s := _battle(F_WISP, 11)
	var wisp := s.battle.enemies[2]
	var db := s.defs.battle
	var wiz := s.battle.party[4]
	var fire_skill: BattleDb.SkillDef = null
	var ice_skill: BattleDb.SkillDef = null
	for sid in db.skill_ids:
		var sk := db.skill(sid)
		if sk.user == "party" and sk.effect == "damage" and sk.target == "enemy_one" and sk.stat == "INT":
			if sk.element == "fire" and fire_skill == null:
				fire_skill = sk
			if sk.element == "ice" and ice_skill == null:
				ice_skill = sk
	check(fire_skill != null and ice_skill != null, "준비: 파티의 불·얼음 단일 술식")
	var ev1: Array[Dictionary] = []
	BattleRules._hit(s, wiz, fire_skill, fire_skill.level_row(1), wisp, ev1)
	check_eq([ev1[0]["type"], ev1[0]["immune"], ev1[0]["amount"], wisp.hp], ["damaged", true, 0, 60], "불: 무효, HP 그대로")
	var ev2: Array[Dictionary] = []
	BattleRules._hit(s, wiz, ice_skill, ice_skill.level_row(1), wisp, ev2)
	var dmg := ev2.filter(func(e: Dictionary) -> bool: return e["type"] == "damaged")
	check(not dmg.is_empty() and dmg[0]["weak"] == true and dmg[0]["calc"]["element"] == 1500 * dmg[0]["calc"]["base"] / 1000, "얼음: 약점 ×1.5 %s" % str(dmg))


## A7 (M-S3 처치하지 않은 적의 드롭을 굴림): 실제 승리 정산. 쓰러진 반딧불만 500‰ 로, 도깨비불은 400‰ 로 발광 인분을 굴린다. 가방에 들어간다.
func test_drops_through_real_finish() -> void:
	var drops_seen := {}
	for sd in 60:
		var s := _battle(F_SERPENTS, 300 + sd)
		var fly := s.battle.enemies[2]
		var ev: Array[Dictionary] = []
		BattleRules.damage_unit(s, fly, fly.hp, s.battle.party[0], "ice", "test", ev, {})
		var probe := GameRng.new(0)
		probe.set_state(s.rng.get_state())
		var hit := probe.randi_range(0, 999) < 500
		var before := int(s.materials.get("item.glow_scale", 0))
		var fin: Array[Dictionary] = []
		check(BattleRules.finish(s, "victory", fin), "승리 정산 %d" % sd)
		var got := fin.filter(func(e: Dictionary) -> bool: return e["type"] == "drop")
		check_eq(got.map(func(e: Dictionary) -> Array: return [e["item"], e["amount"], e["enemy"]]), [["item.glow_scale", 1, 2]] if hit else [], "시드 %d: 반딧불 500‰ 한 번만(뱀은 살아 있어 굴리지 않는다)" % sd)
		check_eq(int(s.materials.get("item.glow_scale", 0)) - before, 1 if hit else 0, "시드 %d: 가방" % sd)
		drops_seen[hit] = true
	check_eq(drops_seen.keys().size(), 2, "60 시드에 얻음·못 얻음이 모두 있다")
	var wisp_hits := 0
	for sd in 60:
		var s := _battle(F_WISP, 400 + sd)
		var wisp := s.battle.enemies[2]
		BattleRules.damage_unit(s, wisp, wisp.hp, s.battle.party[0], "ice", "test", [] as Array[Dictionary], {})
		var probe := GameRng.new(0)
		probe.set_state(s.rng.get_state())
		var hit := probe.randi_range(0, 999) < 400
		var fin: Array[Dictionary] = []
		BattleRules.finish(s, "victory", fin)
		var got := fin.filter(func(e: Dictionary) -> bool: return e["type"] == "drop").size()
		check_eq(got, 1 if hit else 0, "도깨비불 시드 %d: 400‰" % sd)
		wisp_hits += 1 if hit else 0
	check(wisp_hits > 0 and wisp_hits < 60, "도깨비불 드롭도 얻음·못 얻음이 모두 있다 (%d / 60)" % wisp_hits)
