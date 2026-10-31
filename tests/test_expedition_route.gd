## 원정 전체 경로 시험(M3 A10a, 05 §24): 실제 제목 화면의 「새 게임」부터 보스 처치·클리어 이야기·마을 기록·제목 불러오기까지를
## 실제 화면(장면 키트: 누르기·키·화면 입구)으로 한 번에 걷는다. 규칙 함수만 부르는 test_boss_route 와 달리 화면·자동 저장·다시 열기를 거친다.
## 임무 UI(관리국), 공방 사기(비콘), 캠프 비콘, 숙소 숙박·기록, 보스 물음, 이야기 상자, 제목 불러오기, 길드 편성(마지막에 파티를 셋으로)을 모두 실제 화면으로 쓴다.
##
## 하강은 임무 구조상 세 번이다: 1) B3F 에 닿는다(임무 둘의 「B3F 방문」), 2) 임무 「봉인된 문」을 받은 뒤 (9,2) 에 다시 선다(목표는 받은 뒤의 걸음),
## 3) 허가(permit.boss)를 지니고 봉인까지 간다. 걷기는 data/floors/arbor_route.json(바이트 그대로)을 되풀이한다. 규칙 함수로 만든 처음 걷기 자취(_fresh_trace)와
## 걸음마다 견주고, 이미 이룬 일을 되풀이하는 걸음(열린 상자의 open, 열린 문 앞 forward)은 건너뛴다. FOE 가 길을 막아 걸음이 안 되면(부딪힘 전투) 같은 걸음을 다시 한다.
##
## 전투: 길 위의 일반 전투는 디버그 finish(승리)로 넘긴다(D15: 승패에 기대지 않는다). 그 가운데 REAL_FIGHT_AT 번째 한 판은 기본 정책 실제 명령으로 끝까지 하고
## 승리·전멸 어느 쪽이든 구조만 본다(전멸이면 전멸 창 선택지를 보고 싸우기 직전 자동 저장으로 돌아가 이어간다). 보스는 실제 명령(BattlePolicy)으로 끝까지 싸운다.
## 디버그 길(통과용, 밸런스 아님 D15): 숙박 뒤 디버그 요청 grant_exp(= 캠프 임시 보급과 같은 GrowthRules.grant_exp)로 다섯 모두 Lv LEVEL_STEP.
## Lv20 에서는 기본 정책이 보스를 이긴다(탐침: 100판 중 100승). 이기지 못하면 싸우기 직전 자동 저장으로 돌아가 다음 정책으로 다시 싸운다(BOSS_POLICIES: 기본 → 전력).
## 같은 저장에서 같은 정책으로 다시 하면 똑같이 되풀이되므로 시도마다 정책을 바꾼다. 결과가 「승리」(outcome == victory)인 것만 이긴 것으로 센다 — 도주 따위 다른 끝은 이기지 못한 것이라 다음 정책으로 간다. 모든 정책이 지면 결과를 모두 적고 실패한다.
##
## 소지금(고정): 200 → 임무 1 보고 +100 = 300 → 비콘 둘 −300 = 0 → 임무 2 보고 +300 = 300 → 비콘 하나 −150 = 150 → 숙박 −(10 × 최고 레벨).
## 이 길의 상자 셋(c1·B2F 열쇠·B3F 열쇠)은 소재·귀중품이라 돈이 변하지 않는다. 소지금은 다시 열기 지점마다 단언한다.
## 다시 열기(P1~P14)는 모두 실제 저장소에서: 닫기 전에 자동 저장 문서를 읽어 화면과 같은지(해시·세대), 제목 「이어하기」로 열어 같은 해시·세대·소지금·저장 안 함.
## 시험 층(set=test)이 아니라 실제 미궁(arbor). 시험마다 죽이는 변이(M-K…)는 05 §24 에 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const A := ExplorationRules.Action
const ROUTE := "res://data/floors/arbor_route.json"
const M1 := "mission.permit_b2f"
const M2 := "mission.boss_seal"
const BEACON := "use.ariadne_beacon"
const SEAL := Vector3i(9, 2, 1)
const LEVEL_STEP := 20
const REAL_FIGHT_AT := 2
const BOSS_POLICIES := [BattlePolicy.DEFAULT, BattlePolicy.FULL]
const MISSION_NOTE := "임무 「아보르 탐사 허가」의 목표를 이뤘다. 관리국에 보고하자"
const KEYS := {"forward": KEY_W, "back": KEY_S, "turn_left": KEY_A, "turn_right": KEY_D, "strafe_left": KEY_Q, "strafe_right": KEY_E, "investigate": KEY_SPACE}
const INVERSE := {"forward": "back", "back": "forward", "strafe_left": "strafe_right", "strafe_right": "strafe_left", "turn_left": "turn_right", "turn_right": "turn_left"}

var kit: Kit
var sc: DungeonScreen
var acts: Array = []
var trace: Array = []
var money_want := 0
var battles := 0
var real_fights := 0
var wipe_branch := ""
## 공략 행동 번호 → 처음 걷기에서 연 상자 {kind, floor, at, facing, id}. 되풀이에서 같은 상자가 같은 자리에서 이미 열려 있을 때만 건너뛴다.
var open_rec := {}
var notes: Array[String] = []
var _stop := false


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null


## 규칙 함수로 만든 처음 걷기 자취: 행동마다 [층, 칸, 방향](전투는 이겼다고 침). 시드와 상관없다(test_arbor_walkthrough).
func _fresh_trace() -> Array:
	var defs := Fx.arbor()
	var st := ExplorationRules.new_game(defs, 41, "full", true)
	st.flags["permit.b2f"] = true
	Fx.act(st, A.ENTER)
	var out := []
	for a in acts:
		Fx.act(st, ExplorationRules.action_from_name(a))
		out.append([st.floor_def.id, st.party.at, st.party.facing])
	return out


func _status(id: String) -> String:
	return QuestRules.status_of(sc.state, sc.state.defs.quests.quests[id])


func _snap() -> Array:
	return [sc.state.floor_def.id, sc.state.party.at, sc.state.party.facing]


func _auto_text() -> String:
	return FileAccess.get_file_as_string(sc.store.main_path(SaveStore.AUTO))


## 자동 저장 문서 = 화면: 문서를 읽어 해시와 세대가 지금 화면과 같다.
func _doc_is_screen() -> bool:
	var r := SaveCodec.decode(_auto_text(), sc.state.defs)
	return r.ok() and SaveCodec.state_hash(r.state) == kit.hash_now() and r.generation == sc.state.generation


func _note_hp(tag: String) -> void:
	var low := 1000
	var each: Array[String] = []
	for m in sc.state.party.members:
		low = mini(low, int(100 * m.hp / maxi(1, m.max_hp)))
		each.append("%s %d/%d" % [m.id, m.hp, m.max_hp])
	notes.append("%s: 소지금 %d, 가장 낮은 HP %d%%, 대원 %s" % [tag, sc.state.money, low, ", ".join(each)])


# ---- 열기·다시 열기 ----

func _boot(seed_value: int) -> void:
	timeout_sec = 420.0
	acts = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))["actions"]
	trace = _fresh_trace()
	kit = Kit.new(tree)
	sc = await kit.open_title("native", seed_value, "debug=1", func(s: DungeonScreen) -> void: s.labyrinth_path = DungeonScreen.LABYRINTH_PATH)
	await kit.frames(2)


## 닫았다 저장소에서 다시 연다(제목 → 「이어하기」). 닫기 전 자동 저장 = 화면, 연 뒤 같은 해시·세대·소지금, 연 것만으로는 저장하지 않는다.
func _reload(tag: String) -> void:
	var h := kit.hash_now()
	var gen := kit.auto_generation()
	check(_doc_is_screen(), "%s: 닫기 전 자동 저장 문서 = 화면(해시·세대)" % tag)
	check_eq(sc.state.money, money_want, "%s: 닫기 전 소지금" % tag)
	sc = await kit.reopen(func(s: DungeonScreen) -> void:
		s.start_mode = "title"
		s.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		s.url_query = "debug=1")
	await kit.frames(2)
	var t := sc.title_screen
	check(t.is_open() and t.rows.has("continue"), "%s: 제목에 「이어하기」" % tag)
	if not t.rows.has("continue"):
		_stop = true
		return
	await kit.tap(kit.center_of(t.menu_buttons["continue"]))
	await kit.frames(3)
	check_eq([sc.state != null, kit.hash_now() if sc.state != null else "", kit.auto_generation(), sc.autosave_count, sc.state.money if sc.state != null else -1],
		[true, h, gen, 0, money_want], "%s: 다시 열기 = 같은 해시·세대·소지금, 저장 안 함" % tag)


# ---- 도우미 ----

func _tap_modal(n: String) -> void:
	var b := sc.modal.find_child(n, true, false) as Control
	check(b != null and b.is_visible_in_tree(), "창 단추 %s" % n)
	if b != null:
		await kit.tap(kit.center_of(b))
		await kit.frames(2)


func _to_plaza() -> void:
	for k in 6:
		if sc.town_screen.page == "plaza" and not sc.quest_screen.is_open() and not sc.shop_screen.is_open() and not sc.guild_screen.is_open() and sc.modal.kind == "":
			return
		await kit.press_key(KEY_ESCAPE)
	check_eq(sc.town_screen.page, "plaza", "광장으로 돌아옴")


func _plaza(key: String) -> void:
	await _to_plaza()
	await kit.tap(kit.center_of(sc.town_screen.plaza_list.rows[TownScreen.PLAZA_KEYS.find(key)]))
	await kit.frames(2)


## 관리국: 받기(KEY_1)·보고(KEY_2) 쪽에서 줄을 눌러 확인 창 「예」(처음 커서).
func _council(page_key: int, quest: String) -> void:
	await _plaza("council")
	var q := sc.quest_screen
	check(q.is_open() and q.giver == "council", "관리국 화면")
	await kit.press_key(page_key)
	var k := q.list_ids.find(quest)
	check(k >= 0, "목록에 %s" % quest)
	if k < 0:
		_stop = true
		return
	await kit.tap(kit.center_of(q.list_inv.rows[k]))
	await kit.frames(1)
	check(q.dialog.is_open() and q.dialog.pick == ShopDialog.YES, "확인 창, 첫 커서 「예」")
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)


func _enter_lab() -> void:
	await _plaza("entrance")
	await kit.tap(kit.center_of(sc.town_screen.entrance_list.rows[0]))
	await kit.frames(3)
	check_eq([sc.state.location, sc.state.floor_def.id], [ExplorationState.LABYRINTH, "b1f"], "탐사 시작 → B1F")


## 공방 사기: 소모품 갈래에서 줄을 눌러 수량 창(↑ = 개수 +1) → 「예」.
func _buy_beacons(n: int) -> void:
	await _plaza("shop")
	var shp := sc.shop_screen
	check(shp.is_open(), "공방 열림")
	shp.handle("root", 0)
	await kit.frames(1)
	shp.handle("branch", 3)
	await kit.frames(2)
	var i := -1
	for k in shp.lines.size():
		if shp.lines[k]["item"] == BEACON:
			i = k
	check(i >= 0, "진열에 비콘")
	if i < 0:
		_stop = true
		return
	await kit.tap(kit.center_of(shp.buy_list.rows[i]))
	await kit.frames(1)
	check_eq([shp.dialog.mode, shp.dialog.qty], ["qty", 1], "수량 창")
	for k in n - 1:
		await kit.press_key(KEY_UP)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	money_want -= 150 * n


## 캠프 소지품에서 비콘을 쓴다(확인 창 → 「돌아간다」). 쓸 수 없으면 false(창이 안 뜸).
func _use_beacon() -> bool:
	var pm := sc.party_menu
	for k in 3:
		if not pm.is_open():
			await kit.press_key(KEY_P)
	check(pm.is_open(), "캠프가 열림")
	await kit.press_key(KEY_1)
	check_eq([pm.page, pm.tab, pm.items_tab.cursor_item()], ["sub", 3, BEACON], "캠프 소지품, 커서 = 비콘")
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_ENTER)
	if pm.dialog_kind != "beacon":
		return false
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(not pm.is_open() and sc.state.in_town() and sc.town_screen.page == "plaza", "비콘 → 마을 광장")
	return true


# ---- 전투 ----

func _battle_settle() -> void:
	for k in 24:
		var ph := sc.battle_layer.phase
		if ph == "closed" or ph == "command":
			return
		if ph == "anim":
			sc.battle_layer.handle("skip")
		elif ph == "result":
			return
		await kit.frames(2)


func _close_result() -> void:
	for k in 10:
		if not sc.battle_layer.is_open():
			return
		if sc.battle_layer.phase == "result":
			sc.battle_layer.handle("result_ok")
		elif sc.battle_layer.phase == "anim":
			sc.battle_layer.handle("skip")
		await kit.frames(2)


## 디버그 finish(승리) → 결과 창 「확인」.
func _finish_battle() -> void:
	if sc.battle_layer.phase == "command":
		check(sc.battle_layer.handle("finish", "victory"), "battle_finish 가 받아들여짐")
		await kit.frames(3)
	await _battle_settle()
	check_eq(sc.battle_layer.phase, "result", "battle_finish → 결과 창")
	await _close_result()


## 실제 명령 한 판(기본 정책). 승리면 결과 창 「확인」, 전멸이면 전멸 창 구조를 보고 싸우기 직전 자동 저장으로 돌아간 뒤 finish 로 넘긴다.
func _real_fight() -> void:
	real_fights += 1
	var pre := _auto_text()
	var turns := 0
	while sc.battle_layer.is_open() and sc.battle_layer.phase == "command" and turns < 40 and not sc.state.wiped:
		sc.battle_layer.handle("commands", BattlePolicy.choose(sc.state, BattlePolicy.DEFAULT))
		await kit.frames(2)
		await _battle_settle()
		turns += 1
	if sc.state.wiped:
		wipe_branch = "wiped"
		check_eq(sc.modal.kind, "wipe", "실제 전투가 전멸 → 전멸 창")
		check(sc.modal.find_child("WipeNewGame", true, false) != null and sc.modal.find_child("WipeLoad", true, false) == null,
			"수동 기록이 없으면 「처음부터」만 있다")
		var f := FileAccess.open(sc.store.main_path(SaveStore.AUTO), FileAccess.WRITE)
		f.store_string(pre)
		f.close()
		await _reload_raw()
		await _finish_battle()
		return
	wipe_branch = "result"
	check(sc.battle_layer.phase == "result" or not sc.battle_layer.is_open(), "실제 전투가 끝남(결과 창)")
	await _close_result()


## 저장소에서 그냥 다시 연다(전멸 복구용, 지점 검사 없음).
func _reload_raw() -> void:
	sc = await kit.reopen(func(s: DungeonScreen) -> void:
		s.start_mode = "title"
		s.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		s.url_query = "debug=1")
	await kit.frames(2)
	await kit.tap(kit.center_of(sc.title_screen.menu_buttons["continue"]))
	await kit.frames(3)


## 열려 있는 전투를 모두 처리한다. 처리했으면 true.
func _handle_battles() -> bool:
	var any := false
	for k in 6:
		await kit.frames(1)
		if not sc.battle_layer.is_open():
			break
		any = true
		battles += 1
		if battles == REAL_FIGHT_AT and real_fights == 0:
			await _real_fight()
		else:
			await _finish_battle()
		await kit.frames(2)
	return any


# ---- 걷기 ----

## 행동 하나(키). 전투가 열리면 처리하고, 기대한 자리가 아니면(부딪힘 전투 따위) 같은 걸음을 다시 한다.
func _exec(a: String, expect: Array, tag: String) -> bool:
	var fought := false
	for attempt in 3:
		await kit.press_key(KEYS[a])
		fought = (await _handle_battles()) or fought
		if sc.state.wiped:
			failures.append("%s: 걷다가 전멸(%s)" % [tag, a])
			return false
		if _snap() == expect:
			return true
		if not fought:
			break
	failures.append("%s: 행동 %s 뒤 기대 %s, 실제 %s" % [tag, a, str(expect), str(_snap())])
	return false


## 처음 걷기에서 안 움직인 forward(열쇠 없는 잠긴 문 앞 막힘, 문 열기)인데 지금은 길이 열려 있어 걸음이 되는 경우: 이미 이룬 일이라 건너뛴다.
func _already_done(i: int, a: String) -> bool:
	if a != "forward" or i == 0 or trace[i] != trace[i - 1]:
		return false
	return not ExplorationRules.move_path(sc.state.floor_def, sc.state.world, sc.state.party.at, sc.state.party.facing).is_empty()


## 공략의 open 행동 하나를 어떻게 할지(M3 A10a 검토 M1). 처음 걷기(open_rec 에 번호가 없다): 이 칸에 닫힌 상자가 있어야 하고, 있으면 그 상자를 적고 연다.
## 되풀이(번호가 있다): 같은 층·칸·방향에 서 있어야 하고, 적어 둔 바로 그 상자가 이 칸에 있어야 하며, 이미 열려 있어야 건너뛴다.
## 없는 목표·다른 목표·닫혀 있어야 할 때 열려 있지 않은 목표는 행동 번호를 붙인 오류다. 돌려주는 사전: {act: open|skip|fail, error}.
func _plan_open(i: int, tag: String) -> Dictionary:
	var here := sc.state.floor_def.chest_at(sc.state.party.at)
	var pos := _snap()
	if not open_rec.has(i):
		if here == null:
			return {"act": "fail", "error": "%s open: 처음 걷기인데 이 칸 %s 에 상자가 없다" % [tag, str(pos)]}
		if sc.state.world.is_chest_opened(here.id):
			return {"act": "fail", "error": "%s open: 처음 걷기인데 상자 %s 가 이미 열려 있다" % [tag, here.id]}
		open_rec[i] = {"kind": "chest", "floor": pos[0], "at": pos[1], "facing": pos[2], "id": here.id}
		return {"act": "open", "error": ""}
	var rec: Dictionary = open_rec[i]
	if pos != [rec["floor"], rec["at"], rec["facing"]]:
		return {"act": "fail", "error": "%s open: 자리가 처음 걷기와 다르다 기대 %s 실제 %s" % [tag, str([rec["floor"], rec["at"], rec["facing"]]), str(pos)]}
	if here == null:
		return {"act": "fail", "error": "%s open: 적어 둔 상자 %s 가 이 칸에 없다" % [tag, rec["id"]]}
	if here.id != rec["id"]:
		return {"act": "fail", "error": "%s open: 다른 상자다 기대 %s 실제 %s" % [tag, rec["id"], here.id]}
	if not sc.state.world.is_chest_opened(rec["id"]):
		return {"act": "fail", "error": "%s open: 열려 있어야 할 상자 %s 가 닫혀 있다" % [tag, rec["id"]]}
	return {"act": "skip", "error": ""}


## 공략 행동 [from_i, to_i) 를 화면으로 걷는다. rec 이 있으면 움직인 행동과 그 전 자리를 적는다(되돌아 걷기용).
func _walk(from_i: int, to_i: int, tag: String, rec: Array = []) -> bool:
	for i in range(from_i, to_i):
		if _stop:
			return false
		var a: String = acts[i]
		var nxt: String = acts[i + 1] if i + 1 < acts.size() else ""
		if a == "open":
			var plan := _plan_open(i, "%s #%d" % [tag, i + 1])
			if plan["act"] == "fail":
				failures.append(plan["error"])
				return false
			if plan["act"] == "open":
				if sc.modal.kind != "chest":
					await kit.press_key(KEY_SPACE)
				if sc.modal.kind != "chest":
					failures.append("%s #%d open: 상자 물음이 뜨지 않는다" % [tag, i + 1])
					return false
				await _tap_modal("ChestYes")
			continue
		if a == "stairs":
			if sc.modal.kind != "stairs":
				await kit.press_key(KEY_SPACE)
			if sc.modal.kind == "stairs":
				await _tap_modal("StairsYes")
			await _handle_battles()
			if _snap() != trace[i]:
				failures.append("%s: 계단 뒤 기대 %s, 실제 %s" % [tag, str(trace[i]), str(_snap())])
				return false
			continue
		if _already_done(i, a):
			continue
		var before := _snap()
		if not await _exec(a, trace[i], "%s #%d" % [tag, i + 1]):
			return false
		rec.append([a, before])
		if sc.modal.kind == "chest" and nxt != "open":
			await _tap_modal("ChestNo")
		elif sc.modal.kind == "stairs" and nxt != "stairs":
			await _tap_modal("StairsNo")
	return true


## rec 를 거꾸로 걷는다(마지막 걸음이 마을 문 칸이면 물음 「예」).
func _walk_back(rec: Array, tag: String) -> bool:
	for k in range(rec.size() - 1, -1, -1):
		if not await _exec(INVERSE[rec[k][0]], rec[k][1], "%s 되돌기 #%d" % [tag, k]):
			return false
	return true


# ---- 시험 ----

func test_expedition_seed_31() -> void:
	await _expedition(31)


func test_expedition_seed_41() -> void:
	await _expedition(41)


## 실제 한 판이 전멸로 끝나는 가지(길 위에서는 승리라 나오지 않는다): 새 게임의 B1F 에서 대원 모두 HP 1 로 전투를 열어 같은 도우미를 부른다.
## 전멸 창(수동 기록이 없으니 「처음부터」만), 싸우기 직전 자동 저장으로 돌아와 같은 전투가 열려 있음, finish 로 끝나고 탐색으로 돌아옴.
func test_real_fight_wipe_branch() -> void:
	await _boot(7)
	await kit.tap(kit.center_of(sc.title_screen.menu_buttons["new_game"]))
	await kit.frames(3)
	await _enter_lab()
	for m in sc.state.party.members:
		m.hp = 1
	var r: Dictionary = JSON.parse_string(sc._on_debug_request(JSON.stringify({"op": "battle_start"})))
	check_eq(r.get("ok"), true, "디버그 battle_start")
	await kit.frames(3)
	check(sc.battle_layer.is_open() and sc.state.battle != null, "전투가 열림")
	battles = REAL_FIGHT_AT - 1
	await _handle_battles()
	check_eq(wipe_branch, "wiped", "HP 1 파티의 실제 한 판은 전멸")
	check_eq([sc.battle_layer.is_open(), sc.state.wiped, sc.state.battle == null, sc.modal.kind], [false, false, true, ""], "전멸 복구 뒤 탐색: 전투 없음·전멸 아님·창 없음")


## 되풀이 걷기의 open 행동(검토 M1): 없는 목표·다른 목표·닫혀 있어야 할 때 닫힌 목표는 오류, 처음 걷기에서는 닫힌 상자만 연다.
## 옛 도우미는 상자가 없으면 말없이 지나가고 닫힌 상자는 열었다 — 이 시험 둘은 그 때 실패한다(변이 M-R1·M-R2).
func _plain_screen() -> void:
	timeout_sec = 120.0
	acts = JSON.parse_string(FileAccess.get_file_as_string(ROUTE))["actions"]
	kit = Kit.new(tree)
	sc = await kit.open_arbor("native", 7, "debug=1")
	open_rec = {}


func test_open_target_missing_fails_with_the_action_index() -> void:
	await _plain_screen()
	Fx.to_floor(sc.state, "b1f", Vector2i(9, 17), Dir.N)  # 상자가 없는 칸
	var first := _plan_open(3, "시험 #4")
	check_eq(first["act"], "fail", "처음 걷기: 이 칸에 상자가 없으면 실패")
	check(str(first["error"]).contains("#4") and str(first["error"]).contains("상자가 없다"), "오류에 행동 번호: %s" % first["error"])
	open_rec[3] = {"kind": "chest", "floor": "b1f", "at": Vector2i(9, 17), "facing": Dir.N, "id": "c1"}
	var replay := _plan_open(3, "시험 #4")
	check_eq(replay["act"], "fail", "되풀이: 적어 둔 상자가 이 칸에 없으면 실패")
	check(str(replay["error"]).contains("#4") and str(replay["error"]).contains("c1"), "오류에 행동 번호와 상자: %s" % replay["error"])
	Fx.to_floor(sc.state, "b1f", Vector2i(10, 15), Dir.N)
	check_eq(_plan_open(3, "시험 #4")["act"], "fail", "되풀이: 자리가 다르면 실패")
	Fx.to_floor(sc.state, "b1f", Vector2i(18, 9), Dir.N)  # 다른 상자(c3)
	open_rec[3] = {"kind": "chest", "floor": "b1f", "at": Vector2i(18, 9), "facing": Dir.N, "id": "c1"}
	check(str(_plan_open(3, "시험 #4")["error"]).contains("다른 상자"), "되풀이: 다른 상자면 실패")


func test_open_closed_on_replay_fails_and_open_chest_is_skipped() -> void:
	await _plain_screen()
	Fx.to_floor(sc.state, "b1f", Vector2i(10, 16), Dir.N)  # c1
	var first := _plan_open(3, "시험 #4")
	check_eq([first["act"], open_rec.has(3)], ["open", true], "처음 걷기: 닫힌 상자는 열기로 적는다")
	var closed := _plan_open(3, "시험 #4")
	check_eq(closed["act"], "fail", "되풀이: 열려 있어야 할 상자가 닫혀 있으면 실패(예전 도우미는 열었다)")
	check(str(closed["error"]).contains("#4") and str(closed["error"]).contains("닫혀"), "오류에 행동 번호: %s" % closed["error"])
	sc.state.world.open_chest("c1")
	check_eq(_plan_open(3, "시험 #4")["act"], "skip", "되풀이: 같은 상자가 같은 자리에서 열려 있으면 건너뛴다")
	check_eq(_plan_open(9, "시험 #10")["act"], "fail", "처음 걷기: 이미 열린 상자는 열 목표가 아니다")


## 승리 결과 창이 떠 있는 동안의 저장(검토 M3): 보스를 쓰러뜨린 승리는 결과 창을 닫기 전에 이미 저장돼 있어야 한다.
## 준비는 경로 상태가 아니라 B3F 보스 앞 (5,2)(봉인 열림·허가·Lv20, 시험 준비)에서 시작해 보스 물음 「예」 → 보스 HP 1 → 기본 정책 한 턴으로 이긴다.
## 결과 창이 떠 있는 채로: 자동 저장 문서 = 화면(클리어 b3f·보스 defeated·세대). 그대로 저장소에서 다시 열면: 클리어가 남고 이야기 상자는 다시 뜨지 않는다
## (A9b: 클리어 이야기는 보이기만 하고 저장하지 않는다). 변이 M-K14: 승리 저장을 결과 창을 닫을 때로 미룸.
func test_victory_is_saved_while_the_result_window_is_visible() -> void:
	timeout_sec = 180.0
	kit = Kit.new(tree)
	sc = await kit.open_arbor("native", 7, "debug=1")
	Fx.to_floor(sc.state, "b3f", Vector2i(5, 2), Dir.W)
	sc.state.encounter.threshold = 99999
	sc.state.flags["permit.boss"] = true
	sc.state.world.open_lock(SEAL)
	for i in sc.state.party.members.size():
		GrowthRules.grant_exp(sc.state, i, sc.state.defs.battle.growth.cum(LEVEL_STEP) - sc.state.party.members[i].exp)
		sc.state.party.members[i].hp = sc.state.party.members[i].max_hp
		sc.state.party.members[i].tp = sc.state.party.members[i].max_tp
	sc._set_state(sc.state)
	await kit.frames(2)
	money_want = sc.state.money
	await kit.press_key(KEY_W)
	check_eq(sc.modal.kind, "boss", "보스 물음")
	await _tap_modal("BossYes")
	await kit.frames(3)
	check(sc.battle_layer.is_open() and sc.state.battle != null and sc.state.battle.foe == "boss", "보스 전투")
	sc.state.battle.enemies[0].hp = 1
	for k in 6:
		if sc.battle_layer.phase != "command":
			break
		sc.battle_layer.handle("commands", BattlePolicy.choose(sc.state, BattlePolicy.DEFAULT))
		await kit.frames(2)
		await _battle_settle()
	check_eq(sc.battle_layer.phase, "result", "승리 결과 창이 떠 있다")
	var doc := SaveCodec.decode(_auto_text(), sc.state.defs)
	check(doc.ok(), "자동 저장 문서가 읽힌다 %s" % doc.error)
	if doc.ok():
		check_eq([FoeRules.cleared(doc.state), doc.state.world.foes["boss"].state, doc.generation, SaveCodec.state_hash(doc.state)],
			[["b3f"] as Array[String], "defeated", sc.state.generation, kit.hash_now()], "결과 창이 떠 있는 동안 자동 저장 문서 = 화면(클리어 b3f·보스 defeated·세대·해시)")
	var h := kit.hash_now()
	await _reload("결과 창이 떠 있는 채로 다시 열기")
	check_eq([kit.hash_now(), FoeRules.cleared(sc.state), sc.state.world.foes["boss"].state, sc.battle_layer.is_open(), sc.modal.kind],
		[h, ["b3f"] as Array[String], "defeated", false, ""], "다시 열기: 클리어가 남고 전투 층·이야기 상자는 없다(이야기는 저장하지 않는다)")


func _expedition(seed_value: int) -> void:
	await _boot(seed_value)
	# 1) 제목 → 새 게임(저장소가 비어 확인 창 없음) → 마을 광장.
	var t := sc.title_screen
	check(t.is_open() and t.rows.has("new_game") and not t.rows.has("continue"), "제목: 이어하기 줄 없음, 새 게임 줄 있음")
	await kit.tap(kit.center_of(t.menu_buttons["new_game"]))
	await kit.frames(3)
	check(sc.state != null and sc.state.in_town() and sc.town_screen.page == "plaza" and sc.state.day == 1 and sc.state.flags.is_empty(), "새 게임: 마을 광장·1일째·플래그 없음")
	money_want = ExplorationState.START_MONEY
	check_eq([sc.state.money, sc.autosave_count], [200, 1], "새 게임: 소지금 200, 자동 저장 하나")
	await _reload("P1 새 게임 직후")
	# 2) 관리국에서 첫 임무 받기.
	await _council(KEY_1, M1)
	check(sc.state.quests.is_accepted(M1), "첫 임무를 받음")
	check(_doc_is_screen(), "받기 자동 저장 = 화면")
	await _reload("P2 첫 임무 받은 뒤")
	# 3) 아보르 입구 → B1F 를 계단 칸(17,1)까지, 달성 안내, 마을 문까지 되돌아 마을로.
	await _enter_lab()
	var rec: Array = []
	check(await _walk(0, 28, "B1F 계단 칸까지", rec), "B1F 계단 칸까지 걸음")
	check_eq([_snap()[0], _snap()[1], sc._toast.text, sc.modal.kind, _status(M1)], ["b1f", Vector2i(17, 1), MISSION_NOTE, "", "done"], "계단 칸: 임무 달성 안내, 물음 없음, 목표 달성")
	check(await _walk_back(rec, "B1F"), "마을 문까지 되돌아 걸음")
	if sc.modal.kind == "stairs":
		await _tap_modal("StairsYes")
	await kit.frames(3)
	check(sc.state.in_town() and sc.town_screen.page == "plaza", "마을 문 「예」 → 마을 광장")
	# 4) 첫 임무 보고.
	await _council(KEY_2, M1)
	money_want += 100
	check_eq([sc.state.money, sc.state.flags.keys(), sc.state.quests.reports_of(M1)], [money_want, ["permit.b2f"], 1], "보고: 돈 +100·허가·보고 1")
	check(_doc_is_screen(), "보고 자동 저장 = 화면")
	await _reload("P3 첫 임무 보고 뒤")
	# 5) 공방에서 비콘 둘.
	await _buy_beacons(2)
	check_eq([sc.state.money, sc.state.consumables], [0, {BEACON: 2}], "비콘 둘: 소지금 0")
	check(_doc_is_screen(), "사기 자동 저장 = 화면")
	await _reload("P4 비콘을 산 뒤")
	# 6) 하강 1: B3F 봉인 앞까지.
	await _enter_lab()
	check(await _walk(0, 29, "하강1 B2F 까지"), "하강1: B2F 도착")
	check_eq(_snap()[0], "b2f", "B2F")
	_note_hp("P5 B2F 도착")
	await _reload("P5 B2F 도착")
	check(await _walk(29, 96, "하강1 B3F 까지"), "하강1: B3F 도착")
	check_eq(_snap()[0], "b3f", "B3F")
	_note_hp("P6 B3F 도착")
	await _reload("P6 B3F 도착")
	check(await _walk(96, 144, "하강1 봉인 앞까지"), "하강1: (9,2)")
	check_eq([_snap()[1], sc.state.key_items.keys().size(), sc.state.quests.is_accepted(M2)], [Vector2i(9, 2), 2, false], "(9,2), 열쇠 둘, 임무 2 아직 안 받음")
	# 7) 비콘으로 마을, 임무 2 받기.
	check(await _use_beacon(), "비콘 사용 (하강1)")
	check_eq([sc.state.consumables, sc.state.money], [{BEACON: 1}, 0], "비콘 하나 남음")
	await _reload("P7 비콘으로 돌아온 뒤")
	await _council(KEY_1, M2)
	check(sc.state.quests.is_accepted(M2), "임무 2 받음")
	await _reload("P8 임무 2 받은 뒤")
	# 8) 하강 2: (9,2) 에 다시 선다 → 목표 달성 → 비콘 → 보고.
	await _enter_lab()
	check(await _walk(0, 144, "하강2"), "하강2: (9,2)")
	check_eq([_snap()[1], sc.state.quests.is_accepted(M2)], [Vector2i(9, 2), true], "하강2 (9,2)")
	check_eq(_status(M2), "done", "임무 2 목표 달성(받은 뒤의 걸음)")
	_note_hp("P9 하강2 끝")
	check(await _use_beacon(), "비콘 사용 (하강2)")
	await _council(KEY_2, M2)
	money_want += 300
	check_eq([sc.state.money, sc.state.flags.has("permit.boss"), sc.state.quests.reports_of(M2)], [money_want, true, 1], "임무 2 보고: 돈 +300·permit.boss")
	await _reload("P9 임무 2 보고 뒤")
	# 9) 비콘 하나 더(소지금 150), 숙박(현재 레벨 값), 그다음 디버그 레벨 올리기.
	await _buy_beacons(1)
	check_eq([sc.state.money, sc.state.consumables], [150, {BEACON: 1}], "세 번째 비콘: 소지금 150")
	var price := TownRules.inn_price(sc.state)
	await _plaza("inn")
	await kit.tap(kit.center_of(sc.town_screen.inn_list.rows[0]))
	await kit.frames(1)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	money_want -= price
	check_eq([sc.state.day, sc.state.money], [2, money_want], "숙박: 2일째, 값 %d" % price)
	for i in sc.state.party.members.size():
		var m := sc.state.party.members[i]
		var n := sc.state.defs.battle.growth.cum(LEVEL_STEP) - m.exp
		var r: Dictionary = JSON.parse_string(sc._on_debug_request(JSON.stringify({"op": "grant_exp", "member": i, "n": n})))
		check_eq(r.get("ok"), true, "디버그 grant_exp 대원 %d" % i)
	var all_full := true
	var all_lv := true
	for m in sc.state.party.members:
		all_full = all_full and m.hp == m.max_hp and m.tp == m.max_tp
		all_lv = all_lv and m.level == LEVEL_STEP
	check(all_lv, "다섯 모두 Lv %d" % LEVEL_STEP)
	check(all_full, "레벨을 올린 뒤에도 HP·TP 가득")
	check(_doc_is_screen(), "레벨 올리기 자동 저장 = 화면")
	await _reload("P10 레벨 올린 뒤")
	check_eq(sc.state.party.members.map(func(m: PartyState.Member) -> int: return m.level), [20, 20, 20, 20, 20], "다시 열어도 Lv 20")
	# 10) 하강 3: 봉인 열기, 보스 물음, 보스 전투.
	await _enter_lab()
	check(await _walk(0, 144, "하강3"), "하강3: (9,2)")
	check_eq(_snap(), ["b3f", Vector2i(9, 2), Dir.W], "봉인 앞")
	await kit.press_key(KEY_W)
	check_eq([sc.state.world.is_lock_open(SEAL), _snap()[1], sc._toast.text], [true, Vector2i(9, 2), sc.texts.t("msg.seal_opened")], "봉인 열림 알림, 제자리")
	check(_doc_is_screen(), "봉인 열림 자동 저장 = 화면")
	await _reload("P11 봉인이 열린 뒤")
	check(sc.state.world.is_lock_open(SEAL), "다시 열어도 봉인 열림")
	var danger := sc.state.encounter.danger
	for k in 4:
		await kit.press_key(KEY_W)
	check_eq(_snap()[1], Vector2i(5, 2), "보스 방 (5,2)")
	check(sc.state.encounter.danger == danger and not sc.state.encounter.pending and sc.state.battle == null, "보스 방 걸음은 위험도를 더하지 않고 전투가 없다")
	await kit.press_key(KEY_W)
	check_eq(sc.modal.kind, "boss", "부딪힘 → 보스 물음")
	var h := kit.hash_now()
	await _tap_modal("BossNo")
	check_eq([sc.modal.kind, kit.hash_now(), sc.state.battle == null], ["", h, true], "「아니오」: 닫기만")
	await kit.press_key(KEY_W)
	check_eq(sc.modal.kind, "boss", "다시 부딪히면 다시 묻는다")
	await _boss_fight()
	if _stop:
		return
	# 11) 이야기 → 클리어 → 다시 열기.
	check_eq(sc.modal.kind, "clear", "승리 뒤 클리어 이야기")
	var pages := 0
	while sc.modal.kind == "clear" and pages < 6:
		pages += 1
		await kit.press_key(KEY_ENTER)
	check_eq([pages, sc.modal.kind], [3, ""], "이야기 세 쪽 뒤 닫힘")
	check_eq([FoeRules.cleared(sc.state), sc.state.world.foes["boss"].state], [["b3f"] as Array[String], "defeated"], "클리어 기록")
	check(_doc_is_screen(), "클리어 자동 저장 = 화면")
	await _reload("P13 클리어 뒤")
	check_eq([sc.modal.kind, FoeRules.cleared(sc.state)], ["", ["b3f"] as Array[String]], "다시 열어도 클리어, 이야기는 다시 안 뜬다")
	# 12) 클리어 뒤: 방 안에서는 비콘이 거부되고, 걸어 나가 비콘으로 마을.
	check(not await _use_beacon(), "보스 방 안: 비콘 거부")
	for k in 6:
		if sc.party_menu.is_open():
			await kit.press_key(KEY_ESCAPE)
	check_eq([sc.party_menu.is_open(), sc.state.consumables, sc.state.in_town()], [false, {BEACON: 1}, false], "거부: 캠프를 닫음, 비콘은 그대로, 미궁 그대로")
	for k in 2:
		await kit.press_key(KEY_A)
	for k in 5:
		await kit.press_key(KEY_W)
		await _handle_battles()
	check_eq([_snap()[0], _snap()[1]], ["b3f", Vector2i(10, 2)], "열린 봉인을 지나 방 밖 (10,2)")
	check(await _use_beacon(), "방 밖에서 비콘 → 마을")
	# 13) 숙소 기록 → 제목 불러오기 → 클리어 표.
	await _plaza("inn")
	await kit.tap(kit.center_of(sc.town_screen.inn_list.rows[1]))
	await kit.frames(1)
	var rt := sc.town_screen.records_tab
	var money_before_save := sc.state.money
	await kit.tap(kit.center_of(rt.save_buttons[0]))
	await kit.frames(2)
	check_eq(sc.state.money, money_before_save, "숙소 기록은 돈이 들지 않는다(안내문: 기록은 무료, 숙박만 유료)")
	var slot := sc.store.load_slot("slot1")
	check(slot.ok() and SaveCodec.state_hash(slot.result.state) == kit.hash_now() and slot.result.generation == sc.state.generation, "슬롯 1 = 지금 상태")
	check_eq(sc.record_slots()[0].get("clear"), true, "record_slots: 슬롯 1 클리어 표")
	var saved := kit.hash_now()
	sc = await kit.reopen(func(s: DungeonScreen) -> void:
		s.start_mode = "title"
		s.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		s.url_query = "debug=1")
	await kit.frames(2)
	t = sc.title_screen
	await kit.tap(kit.center_of(t.menu_buttons["load"]))
	await kit.frames(2)
	check_eq(sc.debug_snapshot()["title"]["records"].get("clear"), [true, false, false], "제목 불러오기 판: 슬롯 1 「제1계층 돌파」")
	await kit.tap(kit.center_of(t.records_tab.load_buttons[0]))
	await kit.frames(3)
	check_eq([kit.hash_now(), FoeRules.cleared(sc.state), sc.state.in_town()], [saved, ["b3f"] as Array[String], true], "P14 슬롯 불러오기: 같은 해시·클리어·마을")
	await _reload("P14 불러온 뒤 이어하기")
	# 14) 길드에서 파티를 셋으로 줄여 편성(작은 파티) → 탐사 시작: 5명이 아니어도 막히지 않는다.
	await _plaza("guild")
	var gd := sc.guild_screen
	check(gd.is_open(), "길드 화면")
	await kit.press_key(KEY_3)
	check_eq([gd.page, gd.form_focus], ["form", "board"], "길드 3 → 편성 판")
	for k in 2:
		await kit.tap(kit.center_of(gd.board.slots[3]))
		await kit.tap(kit.center_of(gd.roster_inv.rows[0]))
	await kit.tap(kit.center_of(gd.board.decide_button))
	await kit.frames(2)
	check_eq(sc.state.party.members.size(), 3, "편성 결정: 파티 3명")
	check(_doc_is_screen(), "편성 자동 저장 = 화면")
	await _enter_lab()
	check_eq([sc.state.party.members.size(), sc.state.location], [3, ExplorationState.LABYRINTH], "3명으로도 탐사를 시작한다")
	print("EXPEDITION seed=%d battles=%d real_fights=%d real_fight=%s" % [seed_value, battles, real_fights, wipe_branch])
	for n in notes:
		print("EXPEDITION   ", n)


## 전투 유닛마다 차지·강화·약화(규칙 상태)를 글로 모은다. 다시 열기 앞뒤 비교용.
func _unit_status() -> String:
	var b := sc.state.battle
	var out := []
	for u in b.party + b.enemies:
		out.append([u.charging, u.buffs, u.debuffs])
	return JSON.stringify(out)


## 규칙 상태에 강화·약화가 하나라도 걸려 있는지(딱지가 그려지는 상태. 차지는 딱지가 없어 상태 비교에만 든다).
func _has_status() -> bool:
	for u in sc.state.battle.party + sc.state.battle.enemies:
		if not u.buffs.is_empty() or not u.debuffs.is_empty():
			return true
	return false


## 전투 층이 실제로 그린 딱지(카드마다 글·종류, 시험 M-K…: 그린 기록으로 본다, 교훈 2).
func _drawn_chips() -> Array:
	var out := []
	for c in sc.battle_layer.party_cards.cards + sc.battle_layer.enemy_area.cards:
		out.append(c.drawn_chips().map(func(x: Dictionary) -> Array: return [x["text"], x["kind"]]))
	return out


func _chips_nonempty(chips: Array) -> bool:
	return chips.any(func(c: Array) -> bool: return not c.is_empty())


## 보스 물음 「예」 → 보스 전투를 실제 명령으로 끝까지. 승리가 아니면 싸우기 직전 자동 저장으로 돌아가 다음 정책으로 다시(BOSS_POLICIES).
## P12: 처음 시도에서 강화·약화가 규칙 상태에 걸린 첫 턴 뒤에, 그 상태와 그려진 딱지가 비어 있지 않음을 먼저 단언하고 다시 연다 —
## 다시 열기 뒤 규칙 상태(해시·턴·유닛별 차지·강화·약화)와 그려진 딱지가 앞과 같아야 한다.
func _boss_fight() -> void:
	await _tap_modal("BossYes")
	await kit.frames(3)
	check(sc.battle_layer.is_open() and sc.state.battle != null and sc.state.battle.foe == "boss", "보스 전투")
	if not sc.battle_layer.is_open():
		_stop = true
		return
	var pre := _auto_text()
	for attempt in BOSS_POLICIES.size():
		var policy: String = BOSS_POLICIES[attempt]
		var turns := 0
		var hit := false
		var reloaded := attempt > 0
		while sc.battle_layer.is_open() and sc.battle_layer.phase == "command" and turns < 60 and not sc.state.wiped:
			var low0 := _party_low()
			sc.battle_layer.handle("commands", BattlePolicy.choose(sc.state, policy))
			await kit.frames(2)
			await _battle_settle()
			turns += 1
			hit = hit or _party_low() < low0
			if not reloaded and sc.battle_layer.phase == "command" and _has_status():
				reloaded = true
				var turn := sc.state.battle.turn
				var hs := kit.hash_now()
				var st := _unit_status()
				var chips := _drawn_chips()
				check(_chips_nonempty(chips), "P12: 다시 열기 전에 그려진 딱지가 있다(차지·강화·약화가 걸린 턴 %d)" % turn)
				await _reload("P12 보스 전투, 차지·강화·약화가 걸린 턴 뒤")
				check(sc.battle_layer.is_open() and sc.battle_layer.phase == "command" and sc.state.battle != null and sc.state.battle.turn == turn,
					"다시 열기: 같은 보스 전투·턴 %d" % turn)
				check_eq(kit.hash_now(), hs, "다시 연 전투 해시")
				check_eq(_unit_status(), st, "다시 연 유닛별 차지·강화·약화")
				check_eq(_drawn_chips(), chips, "다시 연 카드의 그려진 딱지")
		if attempt == 0 and not reloaded:
			failures.append("처음 시도에서 차지·강화·약화가 걸린 턴이 없었다(P12 를 볼 수 없다): 턴 %d" % turns)
		if sc.battle_layer.phase == "result" and not sc.state.wiped and sc.battle_layer.outcome == "victory":
			check(hit and turns >= 3, "보스전은 싸움이었다(파티 HP 가 줄고 3턴 이상): 턴 %d" % turns)
			await _close_result()
			notes.append("보스: 정책 %s 시도 %d, 턴 %d" % [policy, attempt + 1, turns])
			return
		notes.append("보스: 정책 %s 시도 %d 승리 아님(전멸 %s, 결과 %s, 턴 %d)" % [policy, attempt + 1, str(sc.state.wiped), sc.battle_layer.outcome, turns])
		var f := FileAccess.open(sc.store.main_path(SaveStore.AUTO), FileAccess.WRITE)
		f.store_string(pre)
		f.close()
		await _reload_raw()
	failures.append("보스를 정책 %s 로 싸워도 이기지 못했다: %s" % [str(BOSS_POLICIES), str(notes)])
	_stop = true


func _party_low() -> int:
	var s := 0
	for m in sc.state.party.members:
		s += m.hp
	return s
