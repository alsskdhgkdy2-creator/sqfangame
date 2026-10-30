## 보스 탐침(M3 A9a 설계 §4.6, 보고만): 게임 묶음 기본 파티를 Lv 8·10·12 로 올려(시작 장비·시작 스킬, SP 는 쓰지 않음 = 보수적 기준)
## 보스 무리 formation.boss.fenrir 와 기본·full 정책으로 판을 돌리고 승률·턴(중앙값·p90)·전멸률·스킬 쓰임을 찍는다.
## 합격 기준이 아니다(D15). 기본 시뮬레이션(run.gd·config.json)과 해시에 들지 않는다.
##   GODOT_SILENCE_ROOT_WARNING=1 flock /tmp/sqfangame-godot.lock timeout 300 godot --headless -s tests/sim/boss_probe.gd -- [판 수]
extends SceneTree

const Fx := preload("res://tests/fixtures.gd")
const FORMATION := "formation.boss.fenrir"
const LEVELS := [8, 10, 12]
const POLICIES := ["default", "full"]
const TURN_CAP := 60
const BASE_SEED := 20261030


func _init() -> void:
	var games := 200
	var a := OS.get_cmdline_user_args()
	if not a.is_empty() and str(a[0]).is_valid_int():
		games = int(a[0])
	var defs := Fx.arbor()
	if defs == null:
		print("BOSS 탐침: 실패 — 게임 묶음 정의")
		quit(1)
		return
	print("BOSS 탐침: %s, 판 %d, 턴 상한 %d, 파티 %s" % [FORMATION, games, TURN_CAP, ", ".join(defs.members().map(func(m): return m.id))])
	print("| Lv | 정책 | 승리 | 전멸 | 상한 | 턴 중앙값 | 턴 p90 | 보스 스킬(행동 수) | 과부하 걸림 | 충전→돌진 | 혼란 걸림 | 맹목 걸림 | 보스 남은 HP 중앙값(진 판) |")
	print("|---:|---|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|")
	for lv in LEVELS:
		for pol in POLICIES:
			var agg := {"victory": 0, "wiped": 0, "cap": 0, "turns": [], "boss_skills": {}, "overclock": 0, "lunge_after_charge": 0, "confusion": 0, "blind": 0, "left": []}
			for g in games:
				_one(defs, lv, pol, BASE_SEED + lv * 1000 + g, agg)
			var t: Array = agg["turns"]
			t.sort()
			var med: int = t[t.size() / 2] if not t.is_empty() else -1
			var p90: int = t[mini(t.size() - 1, int(t.size() * 0.9))] if not t.is_empty() else -1
			var left: Array = agg["left"]
			left.sort()
			var keys: Array = agg["boss_skills"].keys()
			keys.sort()
			var sk := " ".join(keys.map(func(k): return "%s %d" % [str(k).trim_prefix("skill.enemy."), agg["boss_skills"][k]]))
			print("| %d | %s | %.1f%% | %.1f%% | %d | %d | %d | %s | %d | %d | %d | %d | %s |" % [lv, pol, 100.0 * agg["victory"] / games, 100.0 * agg["wiped"] / games,
				agg["cap"], med, p90, sk, agg["overclock"], agg["lunge_after_charge"], agg["confusion"], agg["blind"],
				str(left[left.size() / 2]) if not left.is_empty() else "-"])
	quit()


func _one(defs: GameDefs, lv: int, pol: String, seed_value: int, agg: Dictionary) -> void:
	var s := ExplorationRules.new_game(defs, seed_value, ExplorationRules.AUTOMAP_OFF)
	var need := defs.battle.growth.cum(lv)
	for i in s.party.members.size():
		GrowthRules.grant_exp(s, i, need)
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, FORMATION)
	assert(st[0]["type"] == "battle_start", str(st))
	var turns := 0
	var charged := false
	var outcome := ""
	while s.battle != null and turns < TURN_CAP:
		var ev := BattleRules.submit(s, BattlePolicy.choose(s, pol))
		turns += 1
		for e in ev:
			match e["type"]:
				"action":
					if e["unit"]["side"] == "enemy":
						agg["boss_skills"][e["skill"]] = agg["boss_skills"].get(e["skill"], 0) + 1
						if e["skill"] == "skill.enemy.thunder_lunge" and charged:
							agg["lunge_after_charge"] += 1
				"charging":
					charged = true
				"buffed":
					if e["target"]["side"] == "enemy":
						agg["overclock"] += 1
				"ailment":
					if e["target"]["side"] == "party" and e["id"] in ["confusion", "blind"]:
						agg[e["id"]] += 1
				"battle_end":
					outcome = e["outcome"]
					if outcome != "victory":
						agg["left"].append(int(e["enemy_hp"][0]))
	if outcome == "victory":
		agg["victory"] += 1
		agg["turns"].append(turns)
	elif outcome == "wiped":
		agg["wiped"] += 1
		agg["turns"].append(turns)
	else:
		agg["cap"] += 1
		agg["left"].append(s.battle.enemies[0].hp if s.battle != null else -1)
