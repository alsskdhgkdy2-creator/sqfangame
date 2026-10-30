## 일반 적 탐침(M3 A3c 설계 §7.4, 보고만): 게임 묶음 기본 파티를 Lv 5·7·9 로 올려(시작 장비·시작 스킬, SP 는 쓰지 않음 = 보수적 기준)
## B2F·B3F 편성(옛 다섯 + 새 둘)을 기본·full 정책으로 돌려 승률·전멸률·턴(중앙값·p90)·남은 파티 HP 비율, 새 스킬 쓰임(감로·점멸 신호·불티 세례·홀림불)을 찍는다.
## 합격 기준이 아니다(D15). 기본 시뮬레이션(run.gd·config.json)과 해시에 들지 않는다. tests/ 아래라 내보내기에서 빠지고 tests/run.gd 는 test_ 로 시작하는 파일만 읽는다.
##   GODOT_SILENCE_ROOT_WARNING=1 flock /tmp/sqfangame-godot.lock timeout 300 godot --headless -s tests/sim/enemy_probe.gd -- [판 수] [b2f|b3f]
extends SceneTree

const Fx := preload("res://tests/fixtures.gd")
const FLOORS := {
	"b2f": {"at": Vector2i(17, 1), "levels": [5, 7], "formations": ["serpents_moth", "moles_bloom", "moths_beetle", "serpent_moles", "beetles", "firefly_serpents", "wisp_moles"]},
	"b3f": {"at": Vector2i(17, 18), "levels": [7, 9], "formations": ["beetles_serpent", "moles_moths", "serpents_bloom", "beetle_moles", "full_mix", "beetle_firefly_wisp", "wisps_moles"]},
}
const POLICIES := ["default", "full"]
const TURN_CAP := 60
const BASE_SEED := 20261030
const NEW_SKILLS := ["skill.enemy.sap_drip", "skill.enemy.glow_signal", "skill.enemy.glow_sting", "skill.enemy.will_fire", "skill.enemy.flicker_jam"]


func _init() -> void:
	var games := 200
	var a := OS.get_cmdline_user_args()
	if not a.is_empty() and str(a[0]).is_valid_int():
		games = int(a[0])
	var only := str(a[1]) if a.size() > 1 else ""
	var defs := Fx.arbor()
	if defs == null:
		print("ENEMY 탐침: 실패 — 게임 묶음 정의")
		quit(1)
		return
	print("ENEMY 탐침: 판 %d, 턴 상한 %d, 파티 %s" % [games, TURN_CAP, ", ".join(defs.members().map(func(m): return m.id))])
	print("| 층 | Lv | 편성 | 정책 | 승리 | 전멸 | 상한 | 턴 중앙값 | 턴 p90 | 남은 파티 HP 중앙값(이긴 판) | 새 스킬 행동 수 | 반딧불 죽은 턴 중앙값 | 점멸 신호 켜진 턴 비율 | 혼란 걸림/홀림불 |")
	print("|---|---:|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---|")
	for fl in FLOORS:
		if not only.is_empty() and only != fl:
			continue
		var info: Dictionary = FLOORS[fl]
		for lv in info["levels"]:
			for f in info["formations"]:
				for pol in POLICIES:
					var agg := {"victory": 0, "wiped": 0, "cap": 0, "turns": [], "hp_left": [], "skills": {}, "fly_dead": [], "buff_turns": 0, "all_turns": 0, "jam": 0, "confused": 0}
					for g in games:
						_one(defs, fl, info["at"], lv, "formation.%s.%s" % [fl.left(2), f], pol, BASE_SEED + lv * 1000 + g, agg)
					var t: Array = agg["turns"]
					t.sort()
					var med: int = t[t.size() / 2] if not t.is_empty() else -1
					var p90: int = t[mini(t.size() - 1, int(t.size() * 0.9))] if not t.is_empty() else -1
					var h: Array = agg["hp_left"]
					h.sort()
					var keys: Array = agg["skills"].keys()
					keys.sort()
					var sk := " ".join(keys.map(func(k): return "%s %d" % [str(k).trim_prefix("skill.enemy."), agg["skills"][k]]))
					var fl_dead: Array = agg["fly_dead"]
					fl_dead.sort()
					var fd := str(fl_dead[fl_dead.size() / 2]) if not fl_dead.is_empty() else "-"
					var bu := "%.0f%%" % (100.0 * agg["buff_turns"] / maxi(1, agg["all_turns"])) if agg["skills"].has("skill.enemy.glow_signal") else "-"
					var cj := ("%d/%d" % [agg["confused"], agg["jam"]]) if agg["skills"].has("skill.enemy.flicker_jam") else "-"
					print("| %s | %d | %s | %s | %.1f%% | %.1f%% | %d | %d | %d | %s | %s | %s | %s | %s |" % [fl, lv, f, pol, 100.0 * agg["victory"] / games, 100.0 * agg["wiped"] / games,
						agg["cap"], med, p90, ("%.0f%%" % (100.0 * h[h.size() / 2])) if not h.is_empty() else "-", sk, fd, bu, cj])
	quit()


func _one(defs: GameDefs, fl: String, at: Vector2i, lv: int, formation: String, pol: String, seed_value: int, agg: Dictionary) -> void:
	var s := ExplorationRules.new_game(defs, seed_value, ExplorationRules.AUTOMAP_OFF)
	var need := defs.battle.growth.cum(lv)
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, need)
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	Fx.to_floor(s, fl, at, Dir.N)
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, formation)
	assert(st[0]["type"] == "battle_start", str(st))
	var turns := 0
	var outcome := ""
	var fly_slots: Array[int] = []
	for u in s.battle.enemies:
		if u.def_id == "enemy.sap_firefly":
			fly_slots.append(u.slot)
	while s.battle != null and turns < TURN_CAP:
		# 턴 시작에 점멸 신호 강화를 가진 살아 있는 적이 있으면 켜진 턴(강화 가동률 = 켜진 턴 / 전체 턴).
		if s.battle.enemies.any(func(u: BattleUnit) -> bool: return u.alive() and u.buffs.any(func(x: Dictionary) -> bool: return x["id"] == "skill.enemy.glow_signal")):
			agg["buff_turns"] += 1
		agg["all_turns"] += 1
		var ev := BattleRules.submit(s, BattlePolicy.choose(s, pol))
		turns += 1
		for e in ev:
			if e["type"] == "action" and e["unit"]["side"] == "enemy" and NEW_SKILLS.has(e["skill"]):
				agg["skills"][e["skill"]] = agg["skills"].get(e["skill"], 0) + 1
				if e["skill"] == "skill.enemy.flicker_jam":
					agg["jam"] += 1
			elif e["type"] == "ailment" and e["id"] == "confusion" and e["target"]["side"] == "party":
				agg["confused"] += 1
			elif e["type"] == "defeated" and e["target"]["side"] == "enemy" and fly_slots.has(int(e["target"]["slot"])):
				agg["fly_dead"].append(turns)
			elif e["type"] == "battle_end":
				outcome = e["outcome"]
	if outcome == "victory":
		agg["victory"] += 1
		agg["turns"].append(turns)
		var cur := 0
		var mx := 0
		for m in s.party.members:
			cur += m.hp
			mx += m.max_hp
		agg["hp_left"].append(float(cur) / float(mx))
	elif outcome == "wiped":
		agg["wiped"] += 1
		agg["turns"].append(turns)
	else:
		agg["cap"] += 1
