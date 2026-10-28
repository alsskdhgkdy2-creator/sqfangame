## 혼란·맹목(M3 A7b, 설계 §2.5·§4.5): 우선순위, 혼란한 대원(명령 없음·양쪽 가운데 고른 대상·아군은 명중 판정 없음),
## 혼란한 적(규칙·난수 없이 내장 공격, 처치 기록 by "confused" 저장), 맹목(자른 명중률 × 500, 필중·수면·아군은 그대로),
## 해제·만료·쓰러짐, 결정성 J7(HEAD 53cecf0 의 전투 사건 해시), 화면(딱지 글·띠 한 줄).
## 시험마다 이름 붙은 변이(설계 노트 §7 A7b, M-A…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const NUMB := "skill.hex_hacker.numb_hex"
const HEAT := "skill.glyph_wizard.heat_glyph"
const SURE_VULN := 1000000
## 턴 가운데 혼란 걸기·풀기(seq=5) 시험 스킬·적. 걸기는 우선 「first」라 늘 먼저 돈다.
const CONF_E := "skill.enemy.t_conf"
const CONF_P := "skill.blade_duelist.t_conf"
const CRUSH := "skill.enemy.t_crush"
const READY := "skill.enemy.t_ready"
const PATCH := "skill.nano_medic.refresh_patch"
const MEDICA := "use.medica"
## J7: HEAD(53cecf0) 코드로 /tmp/sqf_a7/gen_events.gd 가 만든 해시(A7 편집 전, 깨끗한 작업 트리). 시험 묶음·게임 묶음 × 시드 31·41,
## 전투 셋을 기본 정책으로 끝까지(턴 60 상한) 돌린 사건 글과 전투마다의 난수 상태(아래 _j7_text 와 같은 길).
const J7 := {
	"test 31": ["a07813d668d81e96f15b81fab2585bd30abf9f1d3255edc8f8a773a8820337b7", 41663],
	"test 41": ["1255063e1491a91154176349447c5e89a107db6090990262a3ec918bde1e04df", 38824],
	"game 31": ["a5b078bbaa06caebf3f0dcaf2a892e040a5aae95c96d3e61dc99efdc81d37acc", 33902],
	"game 41": ["b6009ab150315901349e63e38b279162701dab8f7f726576131885b49c504538", 38702],
}

var kit: Kit
var host: Control
static var _quiet: GameDefs
static var _mid_defs: GameDefs


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()


## 적이 아무것도 하지 않는(자기 0 회복) 시험 정의. 편성: solo(쥐 하나 전열), pair(쥐 둘 전열).
static func _defs() -> GameDefs:
	if _quiet == null:
		var files := Fx.battle_files(Fx.test_files([], [], {"solo": [["enemy.neon_rat", "front"]], "pair": [["enemy.neon_rat", "front"], ["enemy.neon_rat", "front"]]}))
		for path in files:
			if str(path).begins_with("enemies/"):
				for e in files[path]["enemies"]:
					e["ai"] = [{"if": {}, "use": [{"skill": Fx.MEND, "weight": 1, "target": "random"}]}]
		_quiet = Fx.defs_from(files)
	return _quiet


## 턴 가운데 혼란 시험 정의(Fx.EXACT: 속도·피해 고정, 속도 굴림이 난수를 쓰지 않는다). 듀얼리스트는 CONF_P(적 하나 혼란, 필중),
## 메딕은 리프레시 패치를 배운다. 편성: conf(걸기 적: AGI 999·우선 first 로 HP 가장 낮은 대원 혼란), conf_brute(걸기 적 + 느린 CRUSH 적),
## charger(AGI 1, 준비 중이면 CRUSH, 아니면 준비 READY), dummy(MEND 만, 고를 것이 하나라 난수 없음).
static func _mid() -> GameDefs:
	if _mid_defs == null:
		var conf := Fx.enemy_skill(CONF_E, "ailment", "enemy_one", {"sure_hit": true, "priority": "first"}, {"ailment": {"id": "confusion", "chance": 1000, "turns": 3}})
		var crush := Fx.enemy_skill(CRUSH, "damage", "enemy_one", {}, {"power": 100})
		var ready := Fx.enemy_skill(READY, "charge", "self", {"charges": CRUSH})
		var enemies := [
			Fx.enemy("enemy.t_confuser", 999, [10, 10, 10, 10, 999, 10], [[{}, [[CONF_E, 1, "lowest_hp"]]]]),
			Fx.enemy("enemy.t_brute", 999, [60, 10, 10, 10, 2, 10], [[{}, [[CRUSH, 1, "lowest_hp"]]]]),
			Fx.enemy("enemy.t_charger", 999, [60, 10, 10, 10, 1, 10], [[{"charging": true}, [[CRUSH, 1, "lowest_hp"]]], [{}, [[READY, 1]]]]),
		]
		var files := Fx.battle_files(Fx.test_files([conf, crush, ready], enemies, {"conf": [["enemy.t_confuser", "front"]],
			"conf_brute": [["enemy.t_confuser", "front"], ["enemy.t_brute", "front"]], "charger": [["enemy.t_charger", "front"]],
			"dummy": [[Fx.DUMMY, "front"]]}), Fx.EXACT)
		Fx.add_tree_skill(files, "classes/blade_duelist.json", {"id": CONF_P, "name_key": CONF_P, "user": "party", "effect": "ailment",
			"range": "ranged", "target": "enemy_one", "parts": [], "priority": "normal", "speed": 1000, "sure_hit": true,
			"levels": [{"tp": 3, "ailment": {"id": "confusion", "chance": 1000, "turns": 3}}]}, [1, 1])
		Fx.with_growth(files, {"initial_sp": 99})
		_mid_defs = Fx.defs_from(files, Fx.party_with_skills(Fx.battle_db(files), {CONF_P: 1, PATCH: 1}))
	return _mid_defs


## _mid 의 그 편성 전투. 모든 유닛의 상태이상 취약을 크게(걸면 늘 걸린다).
func _mid_battle(formation: String, seed_value: int = 3) -> ExplorationState:
	var s := Fx.battle(_mid(), "formation.t." + formation, seed_value)
	check(s.battle != null, "준비: %s 전투" % formation)
	if s.battle != null:
		for u in s.battle.party + s.battle.enemies:
			_sure(u)
	return s


## 마을에서 front·back 으로 짠 파티(기본 다섯 ID)로 그 편성 전투를 연다.
func _battle(front: Array, back: Array, formation: String, seed_value: int) -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), seed_value, "floor", true)
	if front.size() + back.size() < 5:
		var ev := GuildRules.form(s, front, back)
		check_eq(ev[0]["type"], "formed", "준비: 편성 %s / %s" % [str(front), str(back)])
	s.location = ExplorationState.LABYRINTH
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, "formation.t." + formation)
	return s


func _full(seed_value: int = 5) -> ExplorationState:
	return _battle(["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", "glyph_wizard"], "pair", seed_value)


func _sure(u: BattleUnit) -> void:
	var av := {}
	for k in BattleLimits.AILMENTS:
		av[k] = SURE_VULN
	u.ailment_vuln = av


func _ail(u: BattleUnit, id: String, turns: int = 3) -> void:
	u.ailment = id
	u.ailment_turns = turns
	u.ailment_damage = 5 if id == "poison" else 0


func _actions(events: Array[Dictionary], who: Dictionary) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == "action" and e["unit"] == who)


## A1 (M-A1 혼란 우선순위 2): 「수면 > 혼란 > 마비 > 독 > 맹목」. 혼란은 마비·독·맹목을 덮고 수면은 못 덮는다. 맹목은 아무것도 덮지 못한다.
func test_priority() -> void:
	check_eq(BattleLimits.AILMENT_PRIORITY, {"sleep": 5, "confusion": 4, "paralysis": 3, "poison": 2, "blind": 1}, "우선순위 값")
	check_eq(BattleLimits.AILMENTS, ["poison", "paralysis", "sleep", "confusion", "blind"], "상태 차례(옛 셋이 앞)")
	var s := _full()
	var b := s.battle
	var u := b.party[1]
	var t := b.enemies[0]
	_sure(t)
	for x in [["paralysis", "confusion", true], ["poison", "confusion", true], ["blind", "confusion", true], ["sleep", "confusion", false],
			["confusion", "sleep", true], ["confusion", "paralysis", false], ["confusion", "confusion", true], ["poison", "blind", false],
			["", "blind", true], ["blind", "poison", true], ["blind", "blind", true], ["", "confusion", true]]:
		_ail(t, x[0])
		if x[0].is_empty():
			t.ailment = ""
			t.ailment_turns = 0
		var ev: Array[Dictionary] = []
		BattleEffects.apply_ailment(b, s.defs.battle.rules, s.rng, u, t, {"id": x[1], "chance": 1000, "turns": 3}, ev)
		var label := "%s 위에 %s" % [x[0] if not x[0].is_empty() else "없음", x[1]]
		if x[2]:
			check_eq([Fx.types(ev), t.ailment, t.ailment_turns], [["ailment"], x[1], 3], label + ": 걸린다")
		else:
			check_eq([Fx.types(ev), t.ailment], [["ailment_blocked"], x[0]], label + ": 막힌다(판정 없음)")


## A2 (M-A2 혼란해도 명령을 받음): 혼란한 대원은 명령을 받지 않고(정책 null, 명령을 주면 not_commandable),
## 그 턴에 kind confused 행동(일반 공격, 대상 하나)을 한다.
func test_confused_member_acts_alone() -> void:
	var s := _full()
	var b := s.battle
	_ail(b.party[1], "confusion")
	check_eq(range(5).map(func(i: int) -> bool: return BattleRules.can_command(s, i)), [true, false, true, true, true], "명령을 받는 대원")
	check_eq(BattlePolicy.choose(s, "default")[1], null, "자동 정책도 null")
	var bad := Fx.cmds(s)
	bad[1] = {"kind": "guard"}
	var h0 := Fx.battle_hash(s)
	check_eq(BattleRules.submit(s, bad), [{"type": "rejected", "reason": "not_commandable", "slot": 1}] as Array[Dictionary], "혼란 대원에게 명령: 거부")
	check_eq(Fx.battle_hash(s), h0, "거부: 상태·난수 그대로")
	var ev := BattleRules.submit(s, Fx.cmds(s))
	var acts := _actions(ev, {"side": "party", "slot": 1})
	check(acts.size() == 1 and acts[0]["kind"] == "confused" and acts[0]["skill"] == "attack" and acts[0]["targets"].size() == 1 and acts[0]["tp"] == 0,
		"혼란 행동 하나(일반 공격, 대상 하나, TP 0): %s" % str(acts))
	if s.battle != null:
		check_eq([s.battle.party[1].ailment, s.battle.party[1].ailment_turns], ["confusion", 2], "턴 끝에 하나 줄어 2턴 남음")


## A2b (M-A3 대상 후보에서 아군을 뺌, M-A4 후보가 하나여도 뽑음): 대상은 쓰는 유닛을 뺀 양쪽의 살아 있고 닿는 유닛(대원 칸 → 적 칸)에서
## 하나뿐이면 뽑지 않고, 둘 이상이면 randi_range(0, n − 1) 한 번. 아군을 치면 명중 판정이 없다.
func test_confused_target_pick() -> void:
	var s := _full()
	var b := s.battle
	var u := b.party[1]
	_ail(u, "confusion")
	var want: Array[BattleUnit] = []
	for t in b.party + b.enemies:
		if t != u and t.alive():
			want.append(t)
	check_eq(want.size(), 6, "준비: 전열 듀얼리스트에서 닿는 후보 여섯(대원 넷 + 적 둘)")
	var allies := 0
	for sd in range(1, 13):
		s.rng.set_state(sd * 7919)
		var c := GameRng.new(0)
		c.set_state(s.rng.get_state())
		var exp := want[c.randi_range(0, want.size() - 1)]
		var got := BattleRules.confused_target(s, u, u.attack)
		check(got == exp, "상태 %d: 후보[%d] 를 고른다(%s)" % [sd, want.find(exp), str(got.ref() if got != null else null)])
		check_eq(s.rng.get_state(), c.get_state(), "상태 %d: 한 번만 뽑는다" % sd)
		if got != null and got.side == u.side:
			allies += 1
	check(allies > 0, "아군도 고른다(%d번)" % allies)
	# 후보 하나: 한 명 파티 대 쥐 하나 → 뽑지 않는다.
	var one := _battle(["blade_duelist"], [], "solo", 5)
	var v := one.battle.party[0]
	_ail(v, "confusion")
	var st := one.rng.get_state()
	check_eq(BattleRules.confused_target(one, v, v.attack), one.battle.enemies[0], "후보 하나: 그 적")
	check_eq(one.rng.get_state(), st, "후보 하나: 난수를 뽑지 않는다")
	# 근접 닿기: 후열 메딕(근접)은 전열이 있는 동안 상대 후열·아군 후열에 닿지 않는다(아군 후열 위저드는 후보가 아니다).
	var m := b.party[3]
	_ail(m, "confusion")
	var reach: Array = []
	for sd in range(1, 40):
		s.rng.set_state(sd)
		var t := BattleRules.confused_target(s, m, m.attack)
		if t != null and not reach.has(t):
			reach.append(t)
	check(not reach.has(b.party[4]) and reach.has(b.party[0]), "후열 근접: 아군 후열 위저드는 닿지 않고 전열 기사는 닿는다")
	# 아군을 치면 명중 판정이 없다: 두 명 파티(혼란 듀얼리스트 + 기사) 대 쥐 하나, 시드를 바꿔 가며 기사를 친 경우를 본다.
	var hit_ally := 0
	for sd in range(1, 41):
		var p := _battle(["holo_knight", "blade_duelist"], [], "solo", sd)
		var d := p.battle.party[1]
		_ail(d, "confusion")
		p.battle.party[0].stats["AGI"] = 999  # 판정을 하면 거의 빗나갈 회피
		var ev := BattleRules.submit(p, Fx.cmds(p))
		var act := _actions(ev, {"side": "party", "slot": 1})
		if act.size() != 1 or act[0]["targets"] != [{"side": "party", "slot": 0}]:
			continue
		hit_ally += 1
		var dm := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "damaged" and e["target"] == {"side": "party", "slot": 0} and e.get("unit") == {"side": "party", "slot": 1})
		var ms := ev.filter(func(e: Dictionary) -> bool: return e["type"] == "missed" and e["target"] == {"side": "party", "slot": 0})
		check(dm.size() == 1 and ms.is_empty() and not (dm[0]["calc"] as Dictionary).has("hit_p"), "시드 %d: 아군 기사에게 판정 없이 맞는다: %s" % [sd, str(dm)])
		check(ev.filter(func(e: Dictionary) -> bool: return e["type"] == "covered").is_empty(), "시드 %d: 커버는 쓰지 않는다" % sd)
	check(hit_ally > 0, "준비: 아군을 친 시드가 있다(%d번)" % hit_ally)


## A3 (M-A5 저장 검사가 by "confused" 를 거부): 혼란한 적은 AI 규칙을 보지 않고(난수 없음) 내장 공격(confused)을 쓴다.
## 그 공격에 쓰러진 적의 처치 기록 by 는 "confused" 이고 저장 왕복에서 그대로 남는다.
func test_confused_enemy() -> void:
	var s := _battle(["blade_duelist"], [], "pair", 3)
	var e := s.battle.enemies[0]
	_ail(e, "confusion")
	var st := s.rng.get_state()
	var ev: Array[Dictionary] = []
	var ch: Variant = EnemyAi.choose(s, e, ev)
	check(typeof(ch) == TYPE_DICTIONARY and ch["kind"] == "confused" and ch["skill"] == BattleDb.confused_attack() and ch["target"] == -1, "혼란한 적: 내장 공격 %s" % str(ch))
	check_eq([s.rng.get_state(), ev], [st, [] as Array[Dictionary]], "AI 규칙 난수·이벤트 없음")
	var a := BattleDb.confused_attack()
	check_eq([a.id, a.element, a.stat, a.range_kind, a.target, a.level_row(1)], ["confused", "bash", "STR", "melee", "enemy_one", {"tp": 0, "power": 100, "accuracy": 950}], "내장 공격 정의")
	# 쓰러뜨림: 시드를 바꿔 가며 혼란한 적 0 이 HP 1 인 적 1 을 친 경우를 찾는다.
	var found := 0
	for sd in range(1, 41):
		var p := _battle(["blade_duelist"], [], "pair", sd)
		_ail(p.battle.enemies[0], "confusion")
		p.battle.enemies[1].hp = 1
		p.battle.party[0].hp = p.battle.party[0].max_hp
		var out := BattleRules.submit(p, Fx.cmds(p))
		var dead := out.filter(func(x: Dictionary) -> bool: return x["type"] == "defeated" and x["target"] == {"side": "enemy", "slot": 1})
		var by_confused := _actions(out, {"side": "enemy", "slot": 0}).any(func(x: Dictionary) -> bool: return x["kind"] == "confused" and x["targets"] == [{"side": "enemy", "slot": 1}])
		if dead.is_empty() or not by_confused or p.battle == null:
			continue
		found += 1
		check_eq(dead[0]["kill"]["by"], "confused", "시드 %d: 처치 기록 by confused" % sd)
		var r := SaveCodec.decode(SaveCodec.encode(p), p.defs)
		check(r.ok(), "시드 %d: 전투 중 저장 왕복 %s" % [sd, r.error])
		if r.ok():
			check_eq([r.state.battle.enemies[1].kill["by"], SaveCodec.state_hash(r.state)], ["confused", SaveCodec.state_hash(p)], "시드 %d: by 그대로, 같은 해시" % sd)
		break
	check(found > 0, "준비: 혼란한 적이 다른 적을 쓰러뜨린 시드가 있다")


## seq=5 적 (M-A10 큐를 만들 때만 혼란을 봄, M-A11 바뀐 적의 준비가 남음): 큐를 만든 뒤 혼란에 걸린 적은 고른 행동(준비 READY·준비된 CRUSH) 대신
## 그 자리에서 혼란 공격을 한다. 순서 값은 큐 때 정한 그대로이고, 준비는 혼란한 적의 길처럼 charge_lost(no_target) 로 풀린다.
func test_confused_before_turn_enemy() -> void:
	for charging in [false, true]:
		var label := "준비 중" if charging else "보통"
		var s := _mid_battle("charger")
		if s.battle == null:
			return
		var e := s.battle.enemies[0]
		if charging:
			e.charging = CRUSH
		var ev := BattleRules.submit(s, Fx.cmds(s, {1: Fx.use(CONF_P, 0)}))
		check(ev.any(func(x: Dictionary) -> bool: return x["type"] == "ailment" and x["target"] == e.ref() and x["id"] == "confusion"), "%s: 듀얼리스트가 적 0 을 혼란에 건다" % label)
		var acts := _actions(ev, e.ref())
		check_eq(acts.map(func(x: Dictionary) -> Array: return [x["kind"], x["skill"]]), [["confused", "confused"]], "%s: 적 0 은 고른 행동 대신 혼란 공격 하나" % label)
		if acts.size() == 1:
			check_eq(acts[0]["order"], BattleCalc.order_value(e.stats["AGI"], 1000, 1000), "%s: 큐 때 정한 순서 그대로" % label)
		var lost := Fx.of_type(ev, "charge_lost")
		check_eq([lost.map(func(x: Dictionary) -> Array: return [x["unit"], x["skill"], x["reason"]]), e.charging],
			[[[e.ref(), CRUSH, "no_target"]] if charging else [], ""], "%s: 준비는 풀린다(charge_lost no_target)" % label)


## seq=5 대원 (M-A10, M-A12 바뀐 행동의 TP 를 냄, M-A13 맡긴 아이템을 씀): 걸기 적(first)이 HP 가 가장 낮은 대원을 먼저 혼란에 걸면,
## 그 대원의 스킬·아이템·도주는 혼란 공격이 된다. TP 를 내지 않고, 아이템은 그대로이며, 도주 판정도 없다.
## 이어서 전투 중 저장 왕복: 다음 턴(혼란한 대원은 명령 없이 혼란 공격)을 원본과 사본에서 돌려 사건·상태가 같다.
func test_confused_before_turn_party() -> void:
	for spec in [[1, Fx.use(CONF_P, 0), "스킬"], [0, {"kind": "item", "item": MEDICA, "target": 0}, "아이템"], [2, {"kind": "escape"}, "도주"]]:
		var i: int = spec[0]
		var label: String = spec[2]
		var s := _mid_battle("conf")
		if s.battle == null:
			return
		var u := s.battle.party[i]
		u.hp = 5
		s.consumables[MEDICA] = 2
		var tp0 := u.tp
		var ev := BattleRules.submit(s, Fx.cmds(s, {i: spec[1]}))
		check(ev.any(func(x: Dictionary) -> bool: return x["type"] == "ailment" and x["target"] == u.ref() and x["id"] == "confusion"), "%s: 걸기 적이 칸 %d 을 먼저 혼란에 건다" % [label, i])
		var acts := _actions(ev, u.ref())
		check_eq(acts.map(func(x: Dictionary) -> Array: return [x["kind"], x["skill"], x["tp"]]), [["confused", "attack", 0]], "%s: 혼란 공격 하나(TP 0)" % label)
		check_eq(u.tp, tp0, "%s: TP 그대로" % label)
		check_eq([s.consumables.get(MEDICA, 0), Fx.of_type(ev, "item_used")], [2, [] as Array[Dictionary]], "%s: 아이템 그대로" % label)
		check(Fx.of_type(ev, "escaped").is_empty() and Fx.of_type(ev, "escape_failed").is_empty(), "%s: 도주 판정 없음" % label)
		check(ev.all(func(x: Dictionary) -> bool: return not (x["type"] == "ailment" and x["target"] == {"side": "enemy", "slot": 0})), "%s: 스킬 효과 없음" % label)
		if i != 1 or s.battle == null:
			continue
		var c := Fx.battle_clone(s)
		check(c != null, "저장 왕복")
		if c == null:
			continue
		check_eq(Fx.battle_hash(c), Fx.battle_hash(s), "저장 왕복: 같은 상태")
		for x in c.battle.party + c.battle.enemies:
			_sure(x)  # 시험이 덮어쓴 취약 배율은 저장하지 않는다(읽을 때 정의에서 다시 만든다): 사본에도 같게 둔다
		var a := Fx.events_text(BattleRules.submit(s, Fx.cmds(s)))
		var b := Fx.events_text(BattleRules.submit(c, Fx.cmds(c)))
		check(a.contains('"kind":"confused"'), "다음 턴: 혼란한 대원은 혼란 공격")
		check_eq([b, Fx.battle_hash(c) if c.battle != null else "", c.rng.get_state()], [a, Fx.battle_hash(s) if s.battle != null else "", s.rng.get_state()], "저장 왕복 뒤 다음 턴 사건·상태·난수가 같다")


## seq=5 풀림 (M-A14 풀린 대원에게도 대상을 뽑음, M-A10 큐 때만 봄): 혼란으로 큐에 든 대원이 차례 전에 풀리면(빠른 메딕의 리프레시 패치)
## 그 행동은 없어진다: failed recovered 하나, 공격·대상 뽑기 없음. 이 전투의 다른 행동도 난수를 쓰지 않으므로 난수 상태는 그대로다.
func test_cured_before_turn_loses_the_action() -> void:
	var s := _mid_battle("dummy")
	if s.battle == null:
		return
	var b := s.battle
	_ail(b.party[1], "confusion")
	b.party[1].stats["AGI"] = 1
	b.party[3].stats["AGI"] = 999
	var st := s.rng.get_state()
	var ev := BattleRules.submit(s, Fx.cmds(s, {3: Fx.use(PATCH, 1)}))
	check(ev.any(func(x: Dictionary) -> bool: return x["type"] == "cured" and x["target"] == {"side": "party", "slot": 1} and x["removed"] == ["confusion"]), "메딕이 먼저 혼란을 푼다")
	check_eq(_actions(ev, {"side": "party", "slot": 1}), [] as Array[Dictionary], "풀린 대원: 행동 없음")
	var f := Fx.of_type(ev, "failed").filter(func(x: Dictionary) -> bool: return x["unit"] == {"side": "party", "slot": 1})
	check_eq(f.map(func(x: Dictionary) -> String: return x["reason"]), ["recovered"], "failed recovered 하나")
	check(ev.all(func(x: Dictionary) -> bool: return x["type"] != "damaged" or x.get("unit") != {"side": "party", "slot": 1}), "공격 없음")
	check_eq(s.rng.get_state(), st, "대상 뽑기·마비 판정 없음(난수 그대로)")
	var line := BattleDisplay.from_state(s, TextDb.load_path("res://data/text/ko.json")).describe(f[0]) if not f.is_empty() and s.battle != null else ""
	check(line.contains("신호 교란이 풀려"), "띠 한 줄: %s" % line)


## seq=5 방어 (M-A15 혼란에 걸리면 방어가 풀림): 방어는 큐 전에 걸리고 행동이 없다. 방어 중에 혼란에 걸린 대원은 그 턴 방어를 지키고
## 혼란 공격도 하지 않는다(뒤에 오는 적 CRUSH 의 피해식에서 방어 단계가 줄인다).
func test_guarding_unit_confused_keeps_guard() -> void:
	var s := _mid_battle("conf_brute")
	if s.battle == null:
		return
	var k := s.battle.party[0]
	k.hp = 20
	var ev := BattleRules.submit(s, Fx.cmds(s))
	check(ev.any(func(x: Dictionary) -> bool: return x["type"] == "ailment" and x["target"] == k.ref() and x["id"] == "confusion"), "방어 중인 기사가 혼란에 걸린다")
	check_eq(_actions(ev, k.ref()), [] as Array[Dictionary], "기사: 혼란 공격 없음")
	var dm := ev.filter(func(x: Dictionary) -> bool: return x["type"] == "damaged" and x["target"] == k.ref() and x.get("skill") == CRUSH)
	check(dm.size() == 1 and int(dm[0]["calc"]["guard"]) < int(dm[0]["calc"]["def_mul"]), "뒤의 CRUSH: 방어 단계가 줄인다 %s" % str(dm))


## 커버 (M-A16 혼란 공격이 커버를 거침): 혼란한 적이 커버 받는 대원(기사가 듀얼리스트를 커버)을 치면 커버로 돌리지 않는다.
func test_confused_enemy_ignores_cover() -> void:
	var found := 0
	for sd in range(1, 41):
		var s := _battle(["holo_knight", "blade_duelist"], [], "solo", sd)
		var b := s.battle
		_ail(b.enemies[0], "confusion")
		b.cover[b.party[1]] = b.party[0]
		var ev := BattleRules.submit(s, Fx.cmds(s))
		var acts := _actions(ev, {"side": "enemy", "slot": 0})
		if acts.size() != 1 or acts[0]["targets"] != [{"side": "party", "slot": 1}]:
			continue
		found += 1
		check(Fx.of_type(ev, "covered").is_empty(), "시드 %d: covered 없음" % sd)
		var hit := ev.filter(func(x: Dictionary) -> bool: return x["type"] in ["damaged", "missed"] and x.get("unit") == {"side": "enemy", "slot": 0})
		check(hit.size() == 1 and hit[0]["target"] == {"side": "party", "slot": 1}, "시드 %d: 듀얼리스트에게 판정(맞거나 빗나감) %s" % [sd, str(hit)])
	check(found > 0, "준비: 혼란한 적이 커버 받는 듀얼리스트를 고른 시드가 있다")


## A4 (M-A6 자르기 전에 곱함, M-A7 필중에도 곱함): 맹목이면 판정하는 길에서 자른 명중률 × 500. 필중은 그대로(판정·난수 없음),
## 필중이 아닌 상태이상 스킬도 줄어든다.
func test_blind_hit() -> void:
	var s := _full(4)
	var b := s.battle
	var rules := s.defs.battle.rules
	check_eq(rules.blind_hit_mult, 500, "규칙 blind_hit_mult 500")
	var u := b.party[1]
	var t := b.enemies[0]
	var row := u.attack.level_row(1)
	for x in [[999, 1, "높은 명중(자르면 1000)"], [1, 999, "낮은 명중(자르면 hit_min)"]]:
		u.stats["AGI"] = x[0]
		t.stats["AGI"] = x[1]
		var clamped := BattleCalc.hit_p(rules, row["accuracy"], u.stats["AGI"], t.evasion_agi(rules))
		_ail(u, "blind")
		var calc := {}
		BattleRules._hits(s, u, u.attack, row, t, [] as Array[Dictionary], calc)
		check_eq(calc.get("hit_p"), BattleCalc.mul(clamped, 500), "%s: 맹목 = 자른 %d × 0.5" % [x[2], clamped])
		u.ailment = ""
		calc = {}
		BattleRules._hits(s, u, u.attack, row, t, [] as Array[Dictionary], calc)
		check_eq(calc.get("hit_p"), clamped, "%s: 맹목 아니면 자른 값 그대로" % x[2])
	check_eq(BattleCalc.hit_p(rules, 950, 999, 1), 1000, "준비: 높은 쪽은 1000 으로 잘린다")
	# 필중(열 글리프): 맹목이어도 판정하지 않는다.
	var w := b.party[4]
	_ail(w, "blind")
	var heat := s.defs.battle.skill(HEAT)
	var st := s.rng.get_state()
	var calc2 := {}
	check(heat.sure_hit and BattleRules._hits(s, w, heat, heat.level_row(1), t, [] as Array[Dictionary], calc2), "필중은 맞는다")
	check_eq([calc2, s.rng.get_state()], [{}, st], "필중: 판정·난수 없음")
	# 필중이 아닌 상태이상 스킬(넘 헥스)도 줄어든다.
	var numb := s.defs.battle.skill(NUMB)
	u.stats["AGI"] = 999
	t.stats["AGI"] = 1
	_ail(u, "blind")
	var calc3 := {}
	BattleRules._hits(s, u, numb, numb.level_row(1), t, [] as Array[Dictionary], calc3)
	check(not numb.sure_hit and calc3.get("hit_p") == 500, "넘 헥스(명중 950): 맹목이면 500: %s" % str(calc3))
	# 아군·수면 대상은 그대로 판정 없음.
	var calc4 := {}
	check(BattleRules._hits(s, u, u.attack, row, b.party[0], [] as Array[Dictionary], calc4) and calc4.is_empty(), "아군 대상: 판정 없음")
	_ail(t, "sleep")
	var calc5 := {}
	check(BattleRules._hits(s, u, u.attack, row, t, [] as Array[Dictionary], calc5) and calc5.is_empty(), "수면 대상: 판정 없음")


## A5: 해제(리프레시 패치의 cure, 테리아카 A 의 cure_ailment)는 둘을 지우고, 턴 끝에 만료되고, 쓰러지면 지워진다.
## 혼란은 피해로 풀리지 않는다(수면과 다르다).
func test_cure_expiry_and_down() -> void:
	var s := _full()
	var b := s.battle
	var u := b.party[0]
	_ail(u, "confusion")
	check_eq(BattleEffects.cure(u), ["confusion"] as Array[String], "cure: 혼란")
	_ail(u, "blind")
	check_eq(BattleEffects.cure_ailment(u), ["blind"] as Array[String], "cure_ailment: 맹목")
	_ail(u, "confusion")
	var ev: Array[Dictionary] = []
	BattleRules.damage_unit(s, u, 1, b.enemies[0], "bash", "x", ev, {})
	check_eq([u.ailment, Fx.types(ev)], ["confusion", ["damaged"]], "혼란은 피해로 풀리지 않는다")
	for id in ["confusion", "blind"]:
		_ail(u, id, 1)
		ev.clear()
		BattleEffects.tick_durations(b, ev)
		check(u.ailment.is_empty() and ev.any(func(e: Dictionary) -> bool: return e["type"] == "expired" and e["id"] == id), "%s 1턴: 턴 끝에 풀린다" % id)
		_ail(u, id)
		ev.clear()
		BattleRules.damage_unit(s, u, u.hp, b.enemies[0], "bash", "x", ev, {})
		check(not u.alive() and u.ailment.is_empty(), "%s: 쓰러지면 지운다" % id)
		u.hp = u.max_hp


## J7 (M-A8 혼란이 없어도 submit 이 난수를 하나 더 뽑음): 혼란·맹목이 없는 전투는 HEAD 와 사건·난수가 같다.
func test_j7_events_match_head() -> void:
	timeout_sec = 120.0
	for pair in [["test", Fx.defs()], ["game", Fx.arbor()]]:
		for sd in [31, 41]:
			var t := _j7_text(pair[1], sd)
			var key := "%s %d" % [pair[0], sd]
			check_eq([t.sha256_text(), t.length()], J7[key], "J7 %s: HEAD 사건 해시·길이" % key)


## /tmp/sqf_a7/gen_events.gd 와 같은 길: 새 게임 → 전투 셋(위험도를 한계값으로 → 출현 표 편성 → 기본 정책, 턴 60 상한, 남으면 도주로 끝),
## 전투 사이에 대원 HP·TP 를 채운다. 사건 글(JSON)과 전투마다 「|rng=…|wiped=…|」를 잇는다.
func _j7_text(defs: GameDefs, seed_value: int) -> String:
	var s := ExplorationRules.new_game(defs, seed_value, "full")
	s.location = ExplorationState.LABYRINTH
	var text := ""
	for k in 3:
		s.encounter.danger = s.encounter.threshold
		var st := BattleRules.start(s, BattleRules.pick_formation(s))
		text += Fx.events_text(st)
		var turns := 0
		while s.battle != null and turns < 60:
			text += Fx.events_text(BattleRules.submit(s, BattlePolicy.choose(s, "default")))
			turns += 1
		if s.battle != null:
			var fe: Array[Dictionary] = []
			BattleRules.finish(s, "escaped", fe)
			text += Fx.events_text(fe)
		text += "|rng=%s|wiped=%s|" % [str(s.rng.get_state()), str(s.wiped)]
		if s.wiped:
			break
		for m in s.party.members:
			m.hp = m.max_hp
			m.tp = m.max_tp
	return text


## A6 (M-A9 띠가 혼란 줄 대신 행동 줄): 전투 층의 카드 딱지(그린 칸)와 띠 한 줄. 혼란 대원은 「교란 3」, 맹목은 「차단 3」,
## 혼란 행동은 「…은(는) 신호가 교란되어 …을(를) 공격했다!」 한 줄(행동 줄 「…의 공격!」은 없다).
func test_display_chips_and_band() -> void:
	timeout_sec = 60.0
	kit = Kit.new(tree)
	var texts := TextDb.load_path("res://data/text/ko.json")
	var s := _full(6)
	_ail(s.battle.party[1], "confusion")
	_ail(s.battle.party[2], "blind")
	s = Fx.battle_clone(s)
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	var layer := BattleLayer.new()
	host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = 1.0
	layer.open(s)
	await kit.frames(2)
	var pc := layer.party_cards
	check_eq(pc.cards[1].drawn_chips().map(func(c: Dictionary) -> String: return str(c["text"])), ["교란 3"], "혼란 대원 카드 딱지")
	check_eq(pc.cards[2].drawn_chips().map(func(c: Dictionary) -> String: return str(c["text"])), ["차단 3"], "맹목 대원 카드 딱지")
	check_eq([texts.t("ailment.confusion"), texts.t("ailment.blind")], ["신호 교란", "센서 차단"], "상태 이름")
	check_eq(layer.member, 0, "명령은 칸 0 부터")
	check(layer.handle("commands", Fx.cmds(s)), "제출(혼란 대원 칸은 null)")
	var seen: Array[String] = []
	var t0 := Time.get_ticks_msec()
	while layer.phase == "anim" and Time.get_ticks_msec() - t0 < 30000:
		var line := layer.banner_text()
		if not line.is_empty() and (seen.is_empty() or seen[-1] != line):
			seen.append(line)
		await kit.frames(1)
	var actor := layer.display.party[1].name
	var conf := seen.filter(func(t: String) -> bool: return t.begins_with(texts.t("battle.event.confused", {"actor": actor, "target": "\u0001"}).get_slice("\u0001", 0)))
	check(conf.size() == 1 and conf[0].contains("신호가 교란되어") and conf[0].ends_with("공격했다!"), "띠: 혼란 줄 하나 %s" % str(seen))
	check(not seen.has(texts.t("battle.event.action", {"actor": actor, "skill": texts.t("battle.attack")})), "띠: 혼란 대원의 「공격!」 행동 줄은 없다 %s" % str(seen))
	check(layer.log_view.lines.any(func(t: String) -> bool: return conf.has(t)), "로그에도 같은 줄")
