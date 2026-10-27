## 전투 층이 그리는 값(06 §9). 규칙 상태(BattleState)를 읽어 만들고, 연출 중에는 이벤트를 차례로 더해 바꾼다.
## 제출하면 규칙 상태는 이미 그 턴 끝이라, 연출이 보여 주는 중간 값은 여기에만 있다. 연출이 끝나면 규칙 상태로 다시 맞춘다.
## 규칙 상태는 읽기만 한다(06 §8.1).
class_name BattleDisplay
extends RefCounted

## 강화·약화 kind → 상태 딱지 글자 키.
const KIND_KEYS := {"phys_atk": "battle.chip.phys_atk", "phys_def": "battle.chip.phys_def",
	"elem_atk": "battle.chip.elem_atk", "elem_def": "battle.chip.elem_def"}
const LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H"]


## 유닛 하나의 보이는 값.
class DUnit:
	extends RefCounted
	var side := BattleUnit.PARTY
	var slot := 0
	var def_id := ""
	var name := ""
	## 정의된 열 "front" / "back".
	var row := "front"
	var hp := 0
	var max_hp := 1
	var tp := 0
	var max_tp := 0
	var ailment := ""
	var ailment_turns := 0
	var binds := {}
	var buffs: Array[Dictionary] = []
	var debuffs: Array[Dictionary] = []
	var charging := ""

	func alive() -> bool:
		return hp > 0

	func ref() -> Dictionary:
		return {"side": side, "slot": slot}

	func clear_on_down() -> void:
		ailment = ""
		ailment_turns = 0
		binds.clear()
		buffs.clear()
		debuffs.clear()
		charging = ""


var texts: TextDb
var turn := 0
var party: Array[DUnit] = []
var enemies: Array[DUnit] = []
## 편 → 후열이 실효 전열인지(정의된 전열이 모두 쓰러짐).
var promoted := {BattleUnit.PARTY: false, BattleUnit.ENEMY: false}


static func from_state(state: ExplorationState, text_db: TextDb) -> BattleDisplay:
	var d := BattleDisplay.new()
	d.texts = text_db
	d.sync(state)
	return d


## 전투 밖(캠프·시설, M2.7 R2): 탐색 상태의 파티만으로 만든다(같은 대원 카드 PartyCards·BattleCard 가 읽는다). 적은 없다.
static func from_party(state: ExplorationState, text_db: TextDb) -> BattleDisplay:
	var d := BattleDisplay.new()
	d.texts = text_db
	d.sync_party(state)
	return d


## 탐색 상태의 파티 값으로 대원 칸을 다시 맞춘다(편성 열은 파티 정의의 열).
func sync_party(state: ExplorationState) -> void:
	var defs := state.defs.party
	var fresh := party.size() != state.party.members.size()
	if fresh:
		party.clear()
	for i in state.party.members.size():
		var m := state.party.members[i]
		var u := DUnit.new() if fresh else party[i]
		u.side = BattleUnit.PARTY
		u.slot = i
		u.def_id = m.id
		u.name = texts.t(defs.name_keys[i])
		u.row = defs.rows[i] if i < defs.rows.size() else "front"
		u.hp = m.hp
		u.max_hp = m.max_hp
		u.tp = m.tp
		u.max_tp = m.max_tp
		if fresh:
			party.append(u)
	enemies.clear()
	promoted = {BattleUnit.PARTY: false, BattleUnit.ENEMY: false}


## 규칙 상태로 모두 다시 맞춘다(전투가 없으면 그대로).
func sync(state: ExplorationState) -> void:
	var b := state.battle
	if b == null:
		return
	turn = b.turn
	party.clear()
	enemies.clear()
	var counts := {}
	for u in b.enemies:
		counts[u.def_id] = int(counts.get(u.def_id, 0)) + 1
	var seen := {}
	for u in b.party:
		party.append(_unit_of(u, texts.t(u.name_key)))
	for u in b.enemies:
		var n := texts.t(u.name_key)
		if counts[u.def_id] > 1:
			var k: int = seen.get(u.def_id, 0)
			seen[u.def_id] = k + 1
			n += " " + LETTERS[mini(k, LETTERS.size() - 1)]
		enemies.append(_unit_of(u, n))
	for side in [BattleUnit.PARTY, BattleUnit.ENEMY]:
		promoted[side] = b.front_empty(side)


static func _unit_of(u: BattleUnit, display_name: String) -> DUnit:
	var d := DUnit.new()
	d.side = u.side
	d.slot = u.slot
	d.def_id = u.def_id
	d.name = display_name
	d.row = u.row
	d.hp = u.hp
	d.max_hp = u.max_hp
	d.tp = u.tp
	d.max_tp = u.max_tp
	d.ailment = u.ailment
	d.ailment_turns = u.ailment_turns
	d.binds = u.binds.duplicate()
	for e in u.buffs:
		d.buffs.append(e.duplicate())
	for e in u.debuffs:
		d.debuffs.append(e.duplicate())
	d.charging = u.charging
	return d


func unit(r: Variant) -> DUnit:
	if typeof(r) != TYPE_DICTIONARY:
		return null
	var list := party if r.get("side") == BattleUnit.PARTY else enemies
	var i := int(r.get("slot", -1))
	return list[i] if i >= 0 and i < list.size() else null


func units_of(side: String) -> Array[DUnit]:
	return party if side == BattleUnit.PARTY else enemies


## 실효 열(06 §3.5): 정의된 전열이 모두 쓰러졌으면 후열이 전열.
func effective_row(u: DUnit) -> String:
	if u.row == "back" and promoted[u.side]:
		return "front"
	return u.row


## 이벤트 하나를 보이는 값에 더한다.
func apply(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"action":
			var u := unit(ev["unit"])
			if u != null:
				if u.side == BattleUnit.PARTY:
					u.tp = maxi(0, u.tp - int(ev.get("tp", 0)))
				if not u.charging.is_empty() and u.charging == ev.get("skill"):
					u.charging = ""
		"damaged", "poison_tick", "healed", "revived":
			var t := unit(ev["target"])
			if t != null:
				t.hp = int(ev["hp"])
		"tp_healed":
			# 아미타(M3 A4): 대상의 TP 를 규칙이 정한 값으로.
			var t := unit(ev["target"])
			if t != null:
				t.tp = int(ev["tp"])
		"defeated":
			var t := unit(ev["target"])
			if t != null:
				t.hp = 0
				t.clear_on_down()
		"level_up":
			# 승리 뒤 레벨업(07 §3.4): 최대값은 새 값, 현재값은 늘어난 만큼(HP 0 대원은 HP 그대로, hp_gain 0).
			var t := unit({"side": BattleUnit.PARTY, "slot": int(ev["member"])})
			if t != null:
				t.max_hp = int(ev["max_hp"])
				t.max_tp = int(ev["max_tp"])
				t.hp += int(ev["hp_gain"])
				t.tp += int(ev["tp_gain"])
		"woke":
			var t := unit(ev["target"])
			if t != null:
				t.ailment = ""
				t.ailment_turns = 0
		"ailment":
			var t := unit(ev["target"])
			if t != null:
				t.ailment = str(ev["id"])
				t.ailment_turns = int(ev["turns"])
				if t.ailment == "sleep":
					t.charging = ""
		"bound":
			var t := unit(ev["target"])
			if t != null:
				t.binds[str(ev["part"])] = int(ev["turns"])
		"buffed":
			var t := unit(ev["target"])
			if t != null:
				var list := t.debuffs if ev["list"] == "debuffs" else t.buffs
				var e: Dictionary = ev["effect"]
				_remove_effect(list, str(e["id"]))
				if typeof(ev.get("evicted")) == TYPE_DICTIONARY:
					_remove_effect(list, str(ev["evicted"]["id"]))
				list.append(e.duplicate())
		"cured":
			var t := unit(ev["target"])
			if t != null:
				t.ailment = ""
				t.ailment_turns = 0
				t.binds.clear()
		"charging":
			var u := unit(ev["unit"])
			if u != null:
				u.charging = str(ev["skill"])
		"charge_lost":
			var u := unit(ev["unit"])
			if u != null:
				u.charging = ""
		"expired":
			var t := unit(ev["target"])
			if t != null:
				match str(ev["what"]):
					"ailment":
						t.ailment = ""
						t.ailment_turns = 0
					"bind":
						t.binds.erase(str(ev["id"]))
					"buff":
						_remove_effect(t.buffs, str(ev["id"]))
					"debuff":
						_remove_effect(t.debuffs, str(ev["id"]))
		"row_shift":
			promoted[str(ev["side"])] = bool(ev["promoted"])
		"battle_end":
			var hp: Array = ev.get("enemy_hp", [])
			for i in mini(hp.size(), enemies.size()):
				enemies[i].hp = int(hp[i])


static func _remove_effect(list: Array[Dictionary], id: String) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i]["id"] == id:
			list.remove_at(i)


# ---- 글자 ----

## 상태 딱지(06 §9.1): [{text, kind}] — kind 는 ailment·bind·buff·debuff·charging. 강화·약화는 그리는 쪽이 ▲▼ 를 벡터로 붙인다.
func chips(u: DUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not u.ailment.is_empty():
		out.append({"text": "%s %d" % [texts.t("battle.chip." + u.ailment), u.ailment_turns], "kind": "ailment"})
	for part in BattleLimits.PARTS:
		if u.binds.has(part):
			out.append({"text": "%s %d" % [texts.t("battle.chip." + part), int(u.binds[part])], "kind": "bind"})
	for e in u.buffs:
		out.append({"text": "%s %d" % [texts.t(KIND_KEYS.get(e["kind"], str(e["kind"]))), int(e["turns"])], "kind": "buff"})
	for e in u.debuffs:
		out.append({"text": "%s %d" % [texts.t(KIND_KEYS.get(e["kind"], str(e["kind"]))), int(e["turns"])], "kind": "debuff"})
	return out


## 딱지 글자만(시험 비교용).
func chip_texts(u: DUnit) -> Array[String]:
	var out: Array[String] = []
	for c in chips(u):
		out.append(("▲" if c["kind"] == "buff" else "▼" if c["kind"] == "debuff" else "") + str(c["text"]))  # font-ok: 시험 비교용, 화면은 모양으로 그린다
	return out


func name_of(r: Variant) -> String:
	var u := unit(r)
	return u.name if u != null else "?"


func skill_name(id: String) -> String:
	if id == "attack":
		return texts.t("battle.attack")
	if id == "escape":
		return texts.t("battle.cmd.escape")
	return texts.t(id)


## 로그·알림 줄 한 줄. 보일 글이 없는 이벤트는 "".
func describe(ev: Dictionary) -> String:
	var tp := str(ev.get("type", ""))
	var actor := name_of(ev.get("unit"))
	var target := name_of(ev.get("target"))
	match tp:
		"action":
			if ev.get("kind") == "escape":
				return texts.t("battle.event.try_escape", {"actor": actor})
			return texts.t("battle.event.action", {"actor": actor, "skill": skill_name(str(ev["skill"]))})
		"failed":
			return texts.t("battle.failed." + str(ev["reason"]), {"actor": actor})
		"guarding", "front_guard", "charging", "charge_lost", "idle":
			return texts.t("battle.event." + tp, {"actor": actor})
		"cover_set", "covered":
			return texts.t("battle.event." + tp, {"actor": actor, "target": target})
		"damaged":
			if ev.get("immune", false):
				return texts.t("battle.event.immune", {"target": target})
			return texts.t("battle.event.damaged", {"target": target, "amount": ev["amount"]})
		"poison_tick":
			return texts.t("battle.event.poison_tick", {"target": target, "amount": ev["amount"]})
		"missed":
			return texts.t("battle.event.missed", {"target": target})
		"defeated":
			var key := "battle.event.member_down" if ev["target"]["side"] == BattleUnit.PARTY else "battle.event.defeated"
			return texts.t(key, {"target": target})
		"woke", "cured", "revived":
			return texts.t("battle.event." + tp, {"target": target})
		"ailment", "ailment_resisted", "ailment_blocked":
			return texts.t("battle.event." + tp, {"target": target, "ailment": texts.t("ailment." + str(ev["id"]))})
		"bound", "bind_resisted":
			return texts.t("battle.event." + tp, {"target": target, "part": texts.t("bind." + str(ev["part"]))})
		"buffed":
			var line := texts.t("battle.event.buffed", {"target": target, "skill": skill_name(str(ev["effect"]["id"]))})
			if typeof(ev.get("evicted")) == TYPE_DICTIONARY:
				line += " / " + texts.t("battle.event.evicted", {"target": target, "skill": skill_name(str(ev["evicted"]["id"]))})
			return line
		"healed":
			return texts.t("battle.event.healed", {"target": target, "amount": ev["amount"]})
		"tp_healed":
			return texts.t("battle.event.tp_healed", {"target": target, "amount": ev["amount"]})
		"item_used":
			# 쓴 소모품의 남은 수(M3 A4, 「메디카 남은 수 1」). 행동 줄 「{actor}의 메디카!」 바로 뒤.
			return texts.t("battle.event.item_used", {"item": texts.t(str(ev["item"])), "left": ev["left"]})
		"expired":
			var what := str(ev["what"])
			var thing := ""
			match what:
				"ailment":
					thing = texts.t("ailment." + str(ev["id"]))
				"bind":
					thing = texts.t("bind." + str(ev["id"]))
				_:
					thing = skill_name(str(ev["id"]))
			return texts.t("battle.event.expired", {"target": target, "what": thing})
		"row_shift":
			if not ev["promoted"]:
				return ""
			return texts.t("battle.event.row_shift_" + str(ev["side"]))
		"escaped", "escape_failed":
			return texts.t("battle.event." + tp)
		"drop":
			var key := "battle.event.drop_capped" if ev.get("capped", false) else "battle.event.drop"
			return texts.t(key, {"item": texts.t(str(ev["item"]))})
		"turn_end":
			return texts.t("battle.event.turn_end", {"n": int(ev["turn"]) + 1})
		"exp":
			var who := name_of({"side": BattleUnit.PARTY, "slot": int(ev["member"])})
			return texts.t("battle.event.exp_capped" if ev.get("capped", false) else "battle.event.exp", {"member": who, "gained": ev["gained"]})
		"level_up":
			var who := name_of({"side": BattleUnit.PARTY, "slot": int(ev["member"])})
			return texts.t("battle.event.level_up", {"member": who, "from": ev["from"], "to": ev["to"]})
	return ""


## 디버그 주소의 판정 이유(06 §9.4: calc·hit_p·확률). 없으면 "".
static func debug_detail(ev: Dictionary) -> String:
	var parts: Array[String] = []
	var calc: Variant = ev.get("calc")
	if typeof(calc) == TYPE_DICTIONARY and not calc.is_empty():
		var keys: Array = calc.keys()
		keys.sort()
		for k in keys:
			parts.append("%s=%s" % [k, str(calc[k])])
	for k in ["hit_p", "hit_roll", "p"]:
		if ev.has(k) and not (typeof(calc) == TYPE_DICTIONARY and calc.has(k)):
			parts.append("%s=%s" % [k, str(ev[k])])
	return " ".join(parts)
