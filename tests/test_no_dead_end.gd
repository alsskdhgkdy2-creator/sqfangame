## 막힘 감사(M3 A10a, 05 §24): 슬라이스 전체를 정의 자료와 규칙 함수로 본다(화면 없음, 몇 초).
## 칸 하나하나의 갇힘은 이미 FloorLoader.analyze(test_floor_locks.gd test_real_floors)가 본다. 여기서는 그 위의 것을 본다:
##  A 슬라이스 목록: 01 §9 의 「정확한」 줄은 개수를 고정하고, 「약」 줄(소재·장비·소모품)은 개수를 찍기만 하고 출처를 단언한다(소재는 얻을 곳, 장비는 살 곳·얻을 곳).
##    출처는 정의가 아니라 「놓인 것」만 센다: 닿는 칸에 놓인 채집 지점의 표, 출현 표에 실제로 오르는 적과 놓인 FOE·보스의 드롭, 놓인 상자, B 가 보인 달성 가능한 의뢰의 보수.
##  B 관문 연쇄: 계단·봉인이 요구하는 플래그를 주는 의뢰를 실제로 받을 수 있고(풀림 조건·목표 칸 도달, 목표 칸은 닫힌 봉인 앞쪽), 그 연쇄가 세 층과 봉인까지 닿는다.
##  C 층 연결: 분석 경고 0·문지기 진행 0·계단 짝이 서로를 가리킴·나가는 곳이 있음(마을 문 = 첫 층 시작 칸).
##  D 빈털터리: 돈 0·가방 비고·HP 1 이어도 입장(ENTER)은 되고, 숙박은 돈이 모자라 막히지만 장비를 팔면 숙박이 된다(막힘 없음, 연약한 길).
##  E 작은 파티: 길드 편성이 파티 1~5 를 받고 0 만 거절한다(party_empty), 1명으로도 입장한다.
## 전멸 창 선택지(수동 기록 없음 = 「처음부터」만, 있음 = 둘, 읽기 실패 = 알림 뒤 다시 창)는 test_wipe_map 이 화면으로 본다(97·130·153 줄 근처).
## 읽기만 한다: Fx.arbor() 정의와 정적 캐시를 바꾸지 않는다. 시험마다 죽이는 변이(M-D…)는 05 §24 에 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const FLOORS := ["b1f", "b2f", "b3f"]
const JUNK := "shop.junk_workshop"


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## 층 ID → 원본 JSON(data/floors).
func _raw_floors() -> Dictionary:
	var out := {}
	for id in FLOORS:
		out[id] = _json("res://data/floors/%s.json" % id)
	return out


func _enemy_files() -> Array:
	var out := []
	for f in ["stratum1", "stratum1_foe", "stratum1_foe_boss"]:
		out.append_array(_json("res://data/enemies/%s.json" % f)["enemies"])
	return out


## 층의 출현 표에 오르는 편성의 적 ID 들. 파일 이름이 아니라 층이 가리키는 표 ID(`FloorModel.encounter_table`)를 읽어 둔 출현 표 등록부(`defs.battle`)에서 찾고,
## 그 표(table 가중치 줄)가 가리키는 편성만 센다. 어느 층도 가리키지 않는 표 정의와 표에 오르지 않는 편성 정의는 세지 않는다(검토 R2).
func _table_enemies(floor_id: String) -> Array:
	var defs := Fx.arbor()
	var f: FloorModel = defs.floors[floor_id]
	var out := []
	for fid in defs.battle.table_formations(f.encounter_table):
		for e in defs.battle.formations[fid].enemies:
			out.append(e["enemy"])
	return out


func _gather_table_items() -> Dictionary:
	var out := {}
	for t in _json("res://data/gathering/stratum1.json")["gather_tables"]:
		var ids: Array = t["items"].map(func(x: Dictionary) -> String: return x["item"])
		if t.has("rare"):
			ids.append(t["rare"]["item"])
		out[t["id"]] = ids
	return out


## 관문 연쇄(B)와 출처(A)가 함께 쓰는 세계: 층 원본·의뢰·닿는 칸·관문 연쇄의 고정점(닿는 층, 얻은 플래그, 달성할 수 있는 의뢰와 차례).
func _world() -> Dictionary:
	var defs := Fx.arbor()
	var raw := _raw_floors()
	var quests: Array = _json("res://data/quests/stratum1.json")["quests"]
	var touched := {}
	for id in FLOORS:
		var f: FloorModel = defs.floors[id]
		var g := FloorLoader._explore(f, FloorLoader.entries(f), 0, FloorLoader._world_bits(f), FloorLoader.MAX_ANALYSIS_NODES, {})
		check(g["complete"], "%s 분석 완료" % id)
		touched[id] = g["touched"]
	var flags := {}
	var floors_ok := {"b1f": true}
	var done := {}
	var order: Array[String] = []
	var changed := true
	while changed:
		changed = false
		for fid in floors_ok.keys():
			for st in raw[fid].get("stairs", []):
				var to: String = st["to"]["floor"] if typeof(st["to"]) == TYPE_DICTIONARY else ""
				if raw.has(to) and not floors_ok.has(to) and (not st.has("needs") or flags.has(st["needs"])):
					floors_ok[to] = true
					changed = true
		for q in quests:
			if done.has(q["id"]) or not _quest_possible(q, done, floors_ok, touched, raw):
				continue
			done[q["id"]] = true
			order.append(q["id"])
			for f in q["reward"]["flags"]:
				flags[f] = true
			changed = true
	return {"defs": defs, "raw": raw, "quests": quests, "touched": touched, "flags": flags, "floors_ok": floors_ok, "done": done, "order": order}


## 슬라이스에 「놓인」 출처: 아이템 → 출처 글 목록. 닿는 층의 닿는 칸에 놓인 채집 지점의 표, 출현 표에 오르는 적과 놓인 FOE·보스의 드롭, 놓인 상자,
## 달성할 수 있는 의뢰의 보수. 정의만 있고 놓이지 않은 표·적·FOE·의뢰는 세지 않는다.
func _sources(w: Dictionary) -> Dictionary:
	var out := {}
	var gt := _gather_table_items()
	var drops := {}
	for e in _enemy_files():
		drops[e["id"]] = e.get("drops", []).map(func(d: Dictionary) -> String: return d["item"])
	var foe_enemies := {}
	for file in ["stratum1", "stratum1_boss"]:
		for f in _json("res://data/foes/%s.json" % file)["foes"]:
			foe_enemies[f["id"]] = f["formation"]["enemies"].map(func(e: Dictionary) -> String: return e["enemy"])
	var add := func(item: String, why: String) -> void:
		if not out.has(item):
			out[item] = []
		out[item].append(why)
	for fid in w["floors_ok"]:
		var raw: Dictionary = w["raw"][fid]
		var seen: Dictionary = w["touched"][fid]
		for g in raw.get("gathering", []):
			if seen.has(Vector2i(int(g["at"][0]), int(g["at"][1]))):
				for item in gt.get(g["table"], []):
					add.call(item, "채집 %s %s" % [fid, g["id"]])
		for c in raw.get("chests", []):
			if c.has("item") and seen.has(Vector2i(int(c["at"][0]), int(c["at"][1]))):
				add.call(c["item"], "상자 %s %s" % [fid, c["id"]])
		for en in _table_enemies(fid):
			for item in drops.get(en, []):
				add.call(item, "드롭 %s %s" % [fid, en])
		for fo in raw.get("foes", []):
			if seen.has(Vector2i(int(fo["at"][0]), int(fo["at"][1]))):
				for en in foe_enemies.get(fo["foe"], []):
					for item in drops.get(en, []):
						add.call(item, "FOE %s %s" % [fid, fo["id"]])
	for q in w["quests"]:
		if w["done"].has(q["id"]):
			for it in q["reward"]["items"]:
				add.call(it["item"], "의뢰 %s" % q["id"])
	return out


# ---- A 슬라이스 목록 ----

func test_slice_inventory() -> void:
	var defs := Fx.arbor()
	var regular: Array = _json("res://data/enemies/stratum1.json")["enemies"]
	var foes: Array = _json("res://data/foes/stratum1.json")["foes"]
	var bosses: Array = _json("res://data/foes/stratum1_boss.json")["foes"]
	var kinds := {}
	var quests: Array = _json("res://data/quests/stratum1.json")["quests"]
	var raw := _raw_floors()
	for id in FLOORS:
		for g in raw[id]["gathering"]:
			kinds[g["kind"]] = true
	var by_giver := {"pub": 0, "council": 0}
	for q in quests:
		by_giver[q["giver"]] += 1
	# 01 §9 의 정확한 줄.
	check_eq(regular.size(), 8, "일반 적 8종")
	check_eq(foes.size(), 3, "FOE 3종")
	check_eq(bosses.size(), 1, "계층 보스 1체")
	check_eq(defs.battle.classes.size(), 6, "직업 6개")
	check_eq(by_giver, {"pub": 3, "council": 2}, "의뢰 3(정보상 바) + 주요 임무 2(관리국)")
	check_eq(kinds.keys().size(), 3, "채집 지점 종류 3(%s)" % str(kinds.keys()))
	check_eq(FLOORS.size(), 3, "미궁 3개 층")
	# 일반 적은 모두 어느 층의 출현 표에 나온다.
	var seen := {}
	for id in FLOORS:
		for e in _table_enemies(id):
			seen[e] = true
	check_eq(regular.filter(func(e: Dictionary) -> bool: return not seen.has(e["id"])).map(func(e: Dictionary) -> String: return e["id"]), [], "일반 적 8종 모두 출현 표에 있다")
	# 「약」 줄: 개수는 찍기만 한다(소재 20 / 장비 31 / 소모품 6 은 측정값, 단언하지 않는다).
	var mats: Array = _json("res://data/items/materials.json")["materials"]
	var gear: Array = _json("res://data/items/equipment.json")["equipment"]
	var uses: Array = _json("res://data/items/consumables.json")["consumables"]
	print("SLICE 소재 %d 장비 %d 소모품 %d 적 %d FOE %d 보스 %d 직업 %d" % [mats.size(), gear.size(), uses.size(), regular.size(), foes.size(), bosses.size(), defs.battle.classes.size()])
	check(mats.size() > 0 and gear.size() > 0 and uses.size() > 0, "소재·장비·소모품 목록이 비어 있지 않다")
	# 얻을 곳: 「놓인」 출처만(w 의 달성 가능한 의뢰·닿는 층). 정의만 있는 표·적은 세지 않는다.
	var w := _world()
	var src := _sources(w)
	var no_source: Array = mats.filter(func(m: Dictionary) -> bool: return not src.has(m["id"])).map(func(m: Dictionary) -> String: return m["id"])
	check_eq(no_source, [], "소재는 모두 놓인 얻을 곳이 있다(놓인 채집 지점·출현 표 적·놓인 FOE·상자·달성 가능한 의뢰)")
	# 장비는 모두 살 수 있거나(공방 진열) 놓인 상자·드롭으로 얻는다. 진열을 푸는 소재도 놓인 출처가 있다.
	var stock := {}
	var unlock_mats := {}
	for line in _json("res://data/shop/junk_workshop.json")["stock"]:
		stock[line["item"]] = true
		for m in line.get("unlock", {}):
			unlock_mats[m] = true
	var no_way: Array = gear.filter(func(g: Dictionary) -> bool: return not (stock.has(g["id"]) or src.has(g["id"]))).map(func(g: Dictionary) -> String: return g["id"])
	check_eq(no_way, [], "장비는 모두 살 곳이나 놓인 얻을 곳이 있다")
	var unlock_missing: Array = unlock_mats.keys().filter(func(m: String) -> bool: return not src.has(m))
	check_eq(unlock_missing, [], "진열을 푸는 소재는 모두 놓인 출처가 있다")
	var uses_missing: Array = uses.filter(func(u: Dictionary) -> bool: return not stock.has(u["id"])).map(func(u: Dictionary) -> String: return u["id"])
	check_eq(uses_missing, [], "소모품은 모두 공방에서 판다")


# ---- B 관문 연쇄 ----

func test_gate_chain_reaches_the_seal() -> void:
	var w := _world()
	var defs: GameDefs = w["defs"]
	var raw: Dictionary = w["raw"]
	var quests: Array = w["quests"]
	var touched: Dictionary = w["touched"]
	var flags: Dictionary = w["flags"]
	var floors_ok: Dictionary = w["floors_ok"]
	var done: Dictionary = w["done"]
	var order: Array = w["order"]
	var gates := {}
	for id in FLOORS:
		for st in raw[id].get("stairs", []):
			if st.has("needs"):
				gates[st["needs"]] = true
		for lk in raw[id].get("locks", []):
			if lk.has("needs"):
				gates[lk["needs"]] = true
	check(gates.has("permit.b2f") and gates.has("permit.boss"), "관문 플래그: 계단 permit.b2f·봉인 permit.boss (%s)" % str(gates.keys()))
	check_eq(floors_ok.keys().size(), 3, "관문을 따라 세 층 모두에 닿는다 %s" % str(floors_ok.keys()))
	check_eq(gates.keys().filter(func(g: String) -> bool: return not flags.has(g)), [], "모든 관문 플래그를 어느 의뢰가 준다")
	check_eq(done.keys().size(), quests.size(), "의뢰 %d 개 모두 풀려 달성할 수 있다 (차례 %s)" % [quests.size(), str(order)])
	check(order.find("mission.permit_b2f") < order.find("mission.boss_seal"), "주요 임무 차례: 탐사 허가 → 봉인된 문")
	# 임무의 목표 칸은 닫힌 봉인 앞쪽에 있다: 분석(touched)은 needs 봉인을 열린 것으로 치므로, 봉인을 닫았을 때 닿지 못하는 칸 묶음(behind_seal)에 들면 안 된다
	# (그 봉인을 여는 허가가 이 임무들에서 오므로, 뒤쪽 칸이 목표면 영영 달성하지 못한다).
	for q in quests:
		var o: Dictionary = q["objective"]
		if o["kind"] == "reach":
			var cell := Vector2i(int(o["at"][0]), int(o["at"][1]))
			check(touched[o["floor"]].has(cell), "%s 목표 칸 %s:%s 에 닿는다" % [q["id"], o["floor"], str(o["at"])])
			var f: FloorModel = defs.floors[o["floor"]]
			for e in f.behind_seal:
				check(not f.behind_seal[e].has(cell), "%s 목표 칸 %s:%s 는 닫힌 봉인 %s 뒤가 아니다" % [q["id"], o["floor"], str(o["at"]), str(e)])


## 의뢰 하나를 지금 받아 끝낼 수 있는지: 풀림 조건(보고한 의뢰·가 본 층)과 목표(도달 칸·건넬 소재·처치할 적·FOE)가 이 시점에 가능한가.
func _quest_possible(q: Dictionary, done: Dictionary, floors_ok: Dictionary, touched: Dictionary, raw: Dictionary) -> bool:
	for u in q["unlock"]:
		match u["kind"]:
			"reported":
				if not done.has(u["quest"]):
					return false
			"visited":
				if not floors_ok.has(u["floor"]):
					return false
			_:
				failures.append("모르는 풀림 조건 %s" % str(u))
				return false
	var o: Dictionary = q["objective"]
	match o["kind"]:
		"reach":
			return floors_ok.has(o["floor"]) and touched[o["floor"]].has(Vector2i(int(o["at"][0]), int(o["at"][1])))
		"deliver":
			var gt := _gather_table_items()
			for fid in floors_ok:
				for g in raw[fid].get("gathering", []):
					if gt.get(g["table"], []).has(o["item"]):
						return true
				for c in raw[fid].get("chests", []):
					if c.get("item", "") == o["item"]:
						return true
			return false
		"kill":
			for fid in floors_ok:
				if _table_enemies(fid).has(o["enemy"]):
					return true
			return false
		"foe":
			for fid in floors_ok:
				for f in raw[fid].get("foes", []):
					if f["foe"] == o["foe"]:
						return true
			return false
	failures.append("모르는 목표 %s" % str(o))
	return false


# ---- C 층 연결 ----

func test_floor_links_and_exits() -> void:
	var defs := Fx.arbor()
	var raw := _raw_floors()
	for id in FLOORS:
		var f: FloorModel = defs.floors[id]
		check_eq(FloorLoader.analyze(f, id), [] as Array[String], "%s 분석 경고 0(닿을 수 없는 칸·갇힘 없음)" % id)
		check_eq(FloorLoader.guard_progress(f, id), [] as Array[String], "%s 문지기가 진행을 막지 않는다" % id)
		check(not FloorLoader.exits(f).is_empty(), "%s 나가는 곳이 있다" % id)
		for st in raw[id].get("stairs", []):
			var to: Dictionary = st["to"]
			var back := (raw[to["floor"]].get("stairs", []) as Array).filter(func(s: Dictionary) -> bool:
				return s["at"] == to["at"] and s["to"]["floor"] == id and s["to"]["at"] == st["at"] and s["way"] != st["way"])
			check_eq(back.size(), 1, "%s 계단 %s → %s 의 짝이 서로를 가리킨다" % [id, str(st["at"]), str(to)])
	var b1: FloorModel = defs.floors["b1f"]
	check(FloorLoader.exits(b1).has(b1.start_at), "B1F 시작 칸이 나가는 곳(마을 문)")
	# 올라가는 계단은 어떤 플래그도 요구하지 않는다(내려갈 때만 막힌다).
	for id in FLOORS:
		for st in raw[id].get("stairs", []):
			if st["way"] == "up":
				check(not st.has("needs"), "%s 올라가는 계단 %s 은 플래그 없이 쓴다" % [id, str(st["at"])])


# ---- D 빈털터리 ----

func test_broke_party_still_has_a_way() -> void:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 5, "full", true)
	s.money = 0
	s.materials.clear()
	s.consumables.clear()
	s.gear_bag.clear()
	for m in s.party.members:
		m.hp = 1
	var price := TownRules.inn_price(s)
	check_eq(TownRules.stay(s), [{"type": "blocked", "reason": "no_money"}], "돈이 없으면 숙박은 막힘(상태 그대로)")
	check_eq([s.money, s.day], [0, 1], "막힌 숙박은 아무것도 바꾸지 않는다")
	var ev := ExplorationRules.apply(s, A.ENTER, "full")
	check(ev.size() > 0 and ev[0]["type"] == "entered", "돈 0·HP 1 이어도 입장은 된다")
	check_eq(s.location, ExplorationState.LABYRINTH, "입장함")
	Fx.to_town(s)
	# 시작 장비 하나(첫 대원의 무기)를 장착 규칙으로 빼서 빈 가방에 두고 판다(선물한 물건이 아니다).
	var weapon: String = s.party.members[0].equip[0]
	check(not weapon.is_empty(), "첫 대원은 시작 무기를 들고 있다")
	var un := GrowthRules.equip(s, 0, 0, "")
	check_eq(un[0]["type"], "equipped", "장착 규칙으로 시작 무기를 뺌")
	check_eq([s.gear_bag.get(weapon, 0), s.party.members[0].equip[0]], [1, ""], "뺀 무기가 빈 가방에 있다")
	var sold := ShopRules.sell(s, JUNK, [{"item": weapon, "qty": 1}])
	check(sold[0]["type"] != "rejected", "장비 판매가 받아들여짐 %s" % str(sold))
	check(s.money >= price, "판 돈 %d ≥ 숙박비 %d" % [s.money, price])
	var stay := TownRules.stay(s)
	check_eq(stay[-1]["type"], "stayed", "팔고 나면 숙박이 된다")
	check(s.party.members.all(func(m: PartyState.Member) -> bool: return m.hp == m.max_hp), "숙박 뒤 HP 가득")


const A := ExplorationRules.Action


# ---- E 작은 파티 ----

func test_small_parties_are_allowed() -> void:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 5, "full", true)
	var ids: Array[String] = []
	for m in s.party.members:
		ids.append(m.id)
	check_eq(GuildRules.form(s, [], []), [{"type": "rejected", "reason": "party_empty"}], "파티 0 명은 거절")
	for n in [1, 2, 3, 4, 5]:
		var pick: Array = ids.slice(0, n)
		var ev := GuildRules.form(s, pick.slice(0, mini(2, n)), pick.slice(mini(2, n)))
		check_eq(ev[0]["type"], "formed", "파티 %d 명 편성" % n)
		check_eq(s.party.members.size(), n, "파티 %d 명이 됨" % n)
	var one := GuildRules.form(s, [ids[0]], [])
	check_eq(one[0]["type"], "formed", "1명 파티")
	var enter := ExplorationRules.apply(s, A.ENTER, "full")
	check_eq(enter[0]["type"], "entered", "1명으로도 입장한다")
	# 미궁에서도 대열을 바꿀 수 있다(마을 밖에서 편성은 거절, 대열 바꾸기는 허용).
	check_eq(GuildRules.form(s, [ids[0]], [])[0].get("reason", ""), "not_town", "미궁에서 편성은 거절")
