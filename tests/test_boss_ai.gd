## 보스 AI(M3 A9a 설계 §2.2·§7.3): 단계 1 순환(A1), hp_below 500 경계 899/900(A2), 단계 2 순환(A3), 충전 → 뇌광 돌진(A4),
## 과부하 구동 강화와 저장 왕복(A5), 머리 봉인 → 할퀴기로 바꿈(A6), 누적 내성(A7), 파티에 거는 혼란·맹목(A8).
## 실제 게임 묶음의 formation.boss.fenrir(HP 1800). 시험마다 죽이는 변이(M-A…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const FORMATION := "formation.boss.fenrir"
const FANG := "skill.enemy.fenrir_fang"
const REND := "skill.enemy.fenrir_rend"
const HOWL := "skill.enemy.static_howl"
const GLARE := "skill.enemy.neon_glare"
const OVERCLOCK := "skill.enemy.overclock"
const COIL := "skill.enemy.coil_charge"
const LUNGE := "skill.enemy.thunder_lunge"

var _defs: GameDefs


func _arbor() -> GameDefs:
	if _defs == null:
		_defs = Fx.arbor()
	return _defs


## 보스 전투(파티 레벨 lv, HP·TP 가득): B3F 봉인을 연 보스 방 (5,2) 에서 FIGHT(실제 접촉 전투, 저장할 수 있는 상태).
func _battle(seed_value: int = 1, lv: int = 12) -> ExplorationState:
	var s := ExplorationRules.new_game(_arbor(), seed_value, "floor")
	var need := s.defs.battle.growth.cum(lv)
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, need)
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	Fx.to_floor(s, "b3f", Vector2i(5, 2), Dir.W)
	s.flags["permit.boss"] = true
	s.world.open_lock(Vector3i(9, 2, 1))
	var ev := ExplorationRules.apply(s, ExplorationRules.Action.FIGHT, "floor")
	assert(ev[-1]["type"] == "encounter" and ev[-1]["formation"] == FORMATION)
	return s


func _boss(s: ExplorationState) -> BattleUnit:
	return s.battle.enemies[0]


## 턴 turn·보스 HP hp 에서 보스가 고르는 스킬을 seeds 마다 모은다(정렬, 겹침 없음).
func _picks(turn: int, hp: int, seeds: int = 24, charging: String = "", bound: String = "") -> Array:
	var got := {}
	for sd in seeds:
		var s := _battle(100 + sd)
		var u := _boss(s)
		s.battle.turn = turn
		u.hp = hp
		u.charging = charging
		if not bound.is_empty():
			u.binds[bound] = 2
		var ev: Array[Dictionary] = []
		var c: Variant = EnemyAi.choose(s, u, ev)
		got[c["skill"].id if c != null else "idle"] = true
	var out := got.keys()
	out.sort()
	return out


## 보스의 행동 이벤트 스킬(이 턴).
func _boss_skill(ev: Array[Dictionary]) -> String:
	for e in ev:
		if e["type"] == "action" and e["unit"]["side"] == "enemy":
			return e["skill"]
	return ""


## A1 (M-A1 규칙 차례를 바꿔 charging 이 첫 규칙이 아님은 A4 가 본다): 단계 1(HP 50% 이상) 다섯 턴 순환:
## 턴 %5 == 2 섬광·하울링, == 4 코일 충전, 나머지 송곳니·할퀴기.
func test_phase1_cycle() -> void:
	for t in 10:
		var want: Array = [COIL] if t % 5 == 4 else ([GLARE, HOWL] if t % 5 == 2 else [FANG, REND])
		want.sort()
		check_eq(_picks(t, 1800, 12), want, "단계 1 턴 %d" % t)


## A2 (M-A2 hp_below 경계를 <= 로): HP 899/1800 은 단계 2, 900/1800 은 단계 1(500‰ 미만만).
func test_hp_threshold() -> void:
	check_eq(_picks(4, 900), [COIL], "900: 단계 1 턴 4 코일")
	var p1 := [GLARE, HOWL]
	p1.sort()
	check_eq(_picks(2, 900), p1, "900: 단계 1 턴 2 섬광·하울링")
	check_eq(_picks(2, 899), [FANG, REND], "899: 단계 2 턴 2 송곳니·할퀴기")
	var p2 := [HOWL, OVERCLOCK]
	p2.sort()
	check_eq(_picks(3, 899), p2, "899: 단계 2 턴 3 과부하·하울링")
	check_eq(_picks(3, 900), [FANG, REND], "900: 단계 1 턴 3 송곳니·할퀴기")


## A3: 단계 2 세 턴 순환: 턴 %3 == 1 코일, == 0 과부하·하울링, == 2 송곳니·할퀴기. 단계 2 의 송곳니는 HP 가장 낮은 대원을 노린다.
func test_phase2_cycle() -> void:
	var p2 := [HOWL, OVERCLOCK]
	p2.sort()
	for t in range(1, 7):
		var want: Array = [COIL] if t % 3 == 1 else (p2 if t % 3 == 0 else [FANG, REND])
		check_eq(_picks(t, 600, 12), want, "단계 2 턴 %d" % t)
	var s := _battle(5)
	s.battle.party[3].hp = 1
	var u := _boss(s)
	u.hp = 600
	s.battle.turn = 2
	for i in 20:
		var c: Variant = EnemyAi.choose(s, u, [] as Array[Dictionary])
		if c["skill"].id == FANG:
			check_eq(c["target"], 3, "단계 2 송곳니: HP 가장 낮은 대원")


## A4 (M-A1 charging 규칙이 첫 규칙이 아님): 턴 4 코일 충전(charging 이벤트, 보스 charging) → 턴 5 뇌광 돌진(단계와 상관없이 첫 규칙).
func test_charge_then_lunge() -> void:
	var s := _battle(9)
	s.battle.turn = 4
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check_eq([_boss_skill(ev), Fx.of_type(ev, "charging").map(func(e): return e["skill"]), _boss(s).charging], [COIL, [LUNGE], LUNGE], "턴 4: 충전")
	check_eq(s.battle.turn, 5, "준비: 턴 5")
	_boss(s).hp = 600
	ev = BattleRules.submit(s, Fx.cmds(s))
	check_eq([_boss_skill(ev), _boss(s).charging], [LUNGE, ""], "턴 5: 뇌광 돌진(단계 2 HP 에서도)")
	check_eq(_picks(3, 600, 6, LUNGE), [LUNGE], "충전 중이면 늘 돌진(단계 2 턴 3)")
	check_eq(_picks(2, 1800, 6, LUNGE), [LUNGE], "충전 중이면 늘 돌진(단계 1 턴 2)")


## A5 (M-A5 적 buff 를 막음은 test_boss_data 가 본다): 과부하 구동은 보스 자신에게 phys_atk 1300 3턴 강화이고, 저장 왕복에도 남는다.
func test_overclock_buff_and_save() -> void:
	var landed := 0
	for sd in 16:
		var s := _battle(200 + sd)
		_boss(s).hp = 600
		s.battle.turn = 3
		var ev := BattleRules.submit(s, Fx.cmds(s))
		if _boss_skill(ev) != OVERCLOCK:
			continue
		landed += 1
		var bf := Fx.of_type(ev, "buffed")
		check_eq([bf.size(), bf[0]["target"]["side"], bf[0]["list"], bf[0]["effect"]["kind"], bf[0]["effect"]["value"]], [1, "enemy", "buffs", "phys_atk", 1300], "강화 이벤트")
		var u := _boss(s)
		check_eq([u.buffs.size(), u.buffs[0]["id"], u.buffs[0]["kind"], u.buffs[0]["value"]], [1, OVERCLOCK, "phys_atk", 1300], "보스의 강화 칸")
		check(u.buffs[0]["turns"] >= 2 and u.buffs[0]["turns"] <= 3, "남은 턴 %s" % str(u.buffs[0]["turns"]))
		var c := Fx.battle_clone(s)
		check(c != null, "저장 왕복(적 buff 가 든 전투)")
		if c != null:
			check_eq([c.battle.enemies[0].buffs, Fx.battle_hash(c)], [u.buffs, Fx.battle_hash(s)], "읽은 강화 칸·전투 해시")
	check(landed > 0, "준비: 시드 열여섯 가운데 과부하 구동이 한 번은 나온다 (%d)" % landed)


## A6 (M-A3 on_bound fail): 머리가 봉인되면 머리 스킬(송곳니·하울링·섬광)을 피해 할퀴기·과부하로 바꾼다(switch). 다 머리면 그대로 고른다.
func test_head_bind_switches() -> void:
	check_eq(_picks(0, 1800, 16, "", "head"), [REND], "단계 1 기본 턴: 할퀴기만")
	check_eq(_picks(3, 600, 16, "", "head"), [OVERCLOCK], "단계 2 턴 3: 과부하만")
	var p1 := [GLARE, HOWL]
	p1.sort()
	check_eq(_picks(2, 1800, 16, "", "head"), p1, "턴 2: 둘 다 머리면 그대로(switch 는 고를 것이 있을 때만)")
	check_eq(_picks(0, 1800, 16, "", "arm"), [FANG], "팔 봉인: 송곳니만")


## A7 (M-A4 적에게 누적 내성을 쌓지 않음): 혼란이 한 번 걸리면 보스의 혼란 내성이 300 쌓여 같은 난수에서 두 번째 혼란은 막힌다.
func test_accumulating_resistance() -> void:
	var s := _battle(1)
	var b := s.battle
	var rules := s.defs.battle.rules
	var hero := b.party[0]
	var u := _boss(s)
	check_eq([u.ailment_vuln["confusion"], u.ailment_vuln["sleep"], u.bind_vuln["head"]], [300, 300, 700], "보스의 낮은 취약")
	var spec := {"id": "confusion", "chance": 1000, "turns": 2}
	var p1 := BattleCalc.status_p(rules, 1000, hero.stats["LUC"], u.stats["LUC"], 300, 0)
	var p2 := BattleCalc.status_p(rules, 1000, hero.stats["LUC"], u.stats["LUC"], 300, rules.resist_gain)
	check(p2 < p1, "준비: 내성이 확률을 낮춘다 %d < %d" % [p2, p1])
	# 첫 판정이 되고 두 번째(같은 난수 상태, 내성 300)가 안 되는 상태를 찾는다.
	var state := -1
	for sd in 400:
		var r := GameRng.new(sd)
		var st := r.get_state()
		var a := BattleCalc.roll(r, p1)
		r.set_state(st)
		if a and not BattleCalc.roll(r, p2):
			state = st
			break
	check(state != -1, "준비: 가르는 난수 상태")
	if state == -1:
		return
	var ev: Array[Dictionary] = []
	s.rng.set_state(state)
	BattleEffects.apply_ailment(b, rules, s.rng, hero, u, spec, ev)
	check_eq([Fx.types(ev), u.ailment, u.resist_acc], [["ailment"], "confusion", {"confusion": rules.resist_gain}], "첫 혼란: 걸리고 내성 300")
	u.ailment = ""
	u.ailment_turns = 0
	ev.clear()
	s.rng.set_state(state)
	BattleEffects.apply_ailment(b, rules, s.rng, hero, u, spec, ev)
	check_eq([Fx.types(ev), u.ailment, ev[0]["p"]], [["ailment_resisted"], "", p2], "같은 난수의 두 번째 혼란: 막힘")


## A8: 보스의 하울링(혼란, 전체)·섬광(맹목, 한 줄)이 파티에 걸린다(턴 2, 시드 여럿).
func test_confusion_and_blind_on_party() -> void:
	var seen := {}
	for sd in 30:
		var s := _battle(300 + sd)
		s.battle.turn = 2
		var ev := BattleRules.submit(s, Fx.cmds(s))
		var sk := _boss_skill(ev)
		check([GLARE, HOWL].has(sk), "턴 2 는 섬광·하울링 (%s)" % sk)
		for e in Fx.of_type(ev, "ailment"):
			if e["target"]["side"] == "party":
				check_eq(e["id"], "blind" if sk == GLARE else "confusion", "스킬과 상태 이상")
				check_eq(e["turns"], 3 if sk == GLARE else 2, "남은 턴")
				seen[e["id"]] = true
	check_eq(seen.keys().size(), 2, "혼란·맹목 둘 다 걸린 적이 있다 %s" % str(seen.keys()))
