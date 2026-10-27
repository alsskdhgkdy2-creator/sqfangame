## 채집 지점의 화면(M3 A5b, 설계 노트 §5·§7.4): 실제 미궁(open_arbor) B1F g1 (8,17) 채취 지점으로 띄운다.
## 채집 물음(층 3 kind "gather", 「예」 먼저, Esc·Backspace·「아니오」 = 닫기만, 「예」 = GATHER·안내·자동 저장), 다 쓴 지점의 알림,
## 물음의 경합, 캠프 채집 알약(그린 기록), 숙소 숙박으로 되돌아오는 횟수(실제 흐름), 가방이 찰 때, 3D 기둥 색(메시 표면), 터치·키,
## 알림 줄 폭, 소지품 소재 설명 줄(그린 글·색, 세 크기). 얻는 길은 모두 실제 행동 → 자동 저장 → 다시 읽기로 본다(A4 교훈 1).
## 시험마다 죽이는 변이(M-U…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
## B1F: 시작 칸 (9,18) 북쪽(마을 문), 그 북쪽 (9,17), 그 서쪽 g1 (8,17) 채취. g2 (16,16) 절단.
const START := Vector2i(9, 18)
const PLAIN := Vector2i(9, 17)
const G1 := Vector2i(8, 17)
const SPENT_TEXT := "오늘은 더 채집할 수 없다. 마을에서 하루를 보내면 다시 채집할 수 있다"
## 1280×720 · 2400×1000(논리 1728×720) · 1280×960.
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000), Vector2(1280, 960)]

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	GatherRules.bonus_hook = Callable()
	if kit != null:
		kit.dispose()
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _open() -> DungeonScreen:
	timeout_sec = 90.0
	if kit != null:
		kit.dispose()
	kit = Kit.new(tree)
	var s: DungeonScreen = await kit.open_arbor("native", 7)
	s.state.encounter.threshold = 99999
	return s


## 실제 미궁을 유지하는 다시 열기 준비(자동 저장을 읽는다).
static func _arbor() -> Callable:
	return func(x: DungeonScreen) -> void:
		x.labyrinth_path = DungeonScreen.LABYRINTH_PATH
		x.start_mode = "labyrinth"


func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 시작 칸에서 실제 키로 g1 에 선다(W 북쪽, Q 서쪽으로 옆걸음).
func _to_g1(s: DungeonScreen) -> void:
	check_eq([s.state.floor_def.id, s.state.party.at, s.state.party.facing], ["b1f", START, Dir.N], "준비: B1F 시작 칸 북쪽")
	await kit.press_key(KEY_W)
	await kit.press_key(KEY_Q)
	await kit.frames(3)


## (9,17) 에서 서쪽(g1 쪽)을 보고 선다.
func _beside_g1(s: DungeonScreen) -> void:
	s.state.party.at = PLAIN
	s.state.party.facing = Dir.W
	s.state.encounter.threshold = 99999
	s._set_state(s.state)
	await kit.frames(2)


func _labels(s: DungeonScreen) -> Array:
	return s.modal.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _focus(s: DungeonScreen) -> Control:
	return s.get_viewport().gui_get_focus_owner()


func _mesh_id(s: DungeonScreen) -> int:
	return s.view._mesh_instance.mesh.get_instance_id()


func _key_event(code: int, pressed: bool, echo: bool = false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	Input.parse_input_event(k)
	Input.flush_buffered_events()


func _wait_idle(s: DungeonScreen) -> void:
	for i in 120:
		if not s.view.is_busy():
			break
		await kit.frames(1)
	await kit.frames(3)


func _auto_doc(s: DungeonScreen) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(s.store.main_path(SaveStore.AUTO)))


## 지금 상태로 GATHER 하면 굴릴 것(디코드한 복사본으로 굴린다: 규칙과 같은 씨앗, 본 상태는 건드리지 않는다).
func _expected(s: DungeonScreen) -> Array[Dictionary]:
	var c := SaveCodec.decode(SaveCodec.encode(s.state), s.store.defs).state
	var p := c.floor_def.point_at(c.party.at)
	return GatherRules.roll(c, p, c.defs.battle.gather_table(p.table), int(c.world.gather_used.get(p.id, 0)))


## 얻은 것 글(「네온 이끼 2개 · 발광 수액 1개」). 소재 이름 글은 ID 키.
func _items_text(s: DungeonScreen, items: Array) -> String:
	var parts: Array[String] = []
	for x in items:
		parts.append("%s %d개" % [s.texts.t(str(x["item"])), int(x["count"])])
	return " · ".join(parts)


## 지금 시야 메시에서 칸 c 의 기둥(칸 가운데 ±0.5m, 벽 높이 아래, 바닥 위)이 쓴 표면 → 색 목록.
func _point_colors(s: DungeonScreen, c: Vector2i) -> Dictionary:
	var mesh: ArrayMesh = s.view._mesh_instance.mesh
	var o := DungeonMeshBuilder.cell_center(c)
	var out := {}
	for i in mesh.get_surface_count():
		var name := str(mesh.surface_get_name(i))
		if name in ["floor", "ceiling", "wall"]:
			continue
		var a := mesh.surface_get_arrays(i)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var cs: PackedColorArray = a[Mesh.ARRAY_COLOR]
		for j in vs.size():
			var v := vs[j]
			if absf(v.x - o.x) <= 0.5 and absf(v.z - o.z) <= 0.5 and v.y <= DungeonMeshBuilder.WALL_H - 0.01:
				if not out.has(name):
					out[name] = []
				var col := Color(snappedf(cs[j].r, 0.01), snappedf(cs[j].g, 0.01), snappedf(cs[j].b, 0.01))
				if not (out[name] as Array).has(col):
					(out[name] as Array).append(col)
	return out


static func _near(list: Array, c: Color) -> bool:
	return list.any(func(x: Color) -> bool: return absf(x.r - c.r) < 0.02 and absf(x.g - c.g) < 0.02 and absf(x.b - c.b) < 0.02)


## 그린 기록에서 알약 셋: [{rect(화면 좌표), color, label, count}](그린 차례).
static func _pills(pm: PartyMenu) -> Array:
	var g := pm.gather_pills
	var rec := SheetParts.record(g)
	var at := g.get_global_rect().position - pm.get_global_rect().position
	var out := []
	for e in rec:
		if e["kind"] == "fill":
			out.append({"rect": Rect2((e["rect"] as Rect2).position + at, (e["rect"] as Rect2).size), "color": e["color"], "texts": []})
		elif e["kind"] == "text" and not out.is_empty():
			(out[-1]["texts"] as Array).append(e["text"])
	return out


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


## U1 (M-U1a 처음 포커스 「아니오」, M-U1b GATHER 뒤 자동 저장 없음; A5a 임시 차이 끝): 새 게임 B1F 에서 실제 키로 g1 에 서면 채집 물음.
## Esc·Backspace·「아니오」는 닫기만, 조사는 다시 묻는다(「아무것도 없다」가 아니다). Enter(「예」) = 채집·안내·자동 저장, 다시 묻지 않는다.
## 다시 열어 자동 저장을 읽으면 같은 소재·쓴 횟수이고 도착에 묻지 않으며, 조사하면 「1/2」로 묻는다.
func test_gather_question_and_gather() -> void:
	var s := await _open()
	await _to_g1(s)
	check_eq([s.state.party.at, s.modal.kind], [G1, "gather"], "g1 에 멈추면 채집 물음")
	check_eq(s.modal.title_plate.text, "채취 지점", "제목 문패")
	var labels := _labels(s)
	check(labels.has("생체 소재를 채취할 수 있는 곳이다. 채집할까?") and labels.has("오늘 남은 횟수 2/2"), "물음 글 두 줄 %s" % str(labels))
	var yes := s.modal.find_child("GatherYes", true, false) as Button
	var no := s.modal.find_child("GatherNo", true, false) as Button
	check(yes != null and no != null and yes.text == "예" and no.text == "아니오" and yes.size.y >= 64.0 and no.size.y >= 64.0, "「예」「아니오」 64 이상")
	check_eq(_focus(s), yes, "처음 커서는 「예」(D25)")
	var snap := s.debug_snapshot()
	check(snap["modal"] == "gather" and snap["buttons"].has("GatherYes") and snap["buttons"].has("GatherNo"), "스냅숏 modal·단추")
	check_eq([snap["gather_here"], snap["gather_used"]], [{"point": "g1", "kind": "take", "left": 2, "uses": 2}, {}], "스냅숏 gather_here·gather_used")
	var h := kit.hash_now()
	for how in ["Esc", "Backspace", "아니오"]:
		if s.modal.kind != "gather":
			await kit.press_key(KEY_SPACE)  # 조사로 다시 묻는다(조사도 규칙 행동이라 자동 저장한다)
			check_eq([s.modal.kind, s._toast.text == s.texts.t("msg.nothing_found")], ["gather", false], "%s: 조사로 다시 묻는다(「아무것도 없다」가 아니다)" % how)
		var saves := s.autosave_count
		match how:
			"Esc":
				await kit.press_key(KEY_ESCAPE)
			"Backspace":
				await kit.press_key(KEY_BACKSPACE)
			_:
				await kit.click(kit.center_of(s.modal.find_child("GatherNo", true, false)))
		await kit.frames(2)
		check_eq([s.modal.kind, s.autosave_count, kit.hash_now(), s.party_menu.is_open(), s.state.party.at], ["", saves, h, false, G1],
			"%s: 닫기만(저장 없음, 캠프 안 열림, 지점 위)" % how)
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "gather", "준비: 조사로 다시 묻는다")
	var want := _expected(s)
	check(not want.is_empty(), "준비: 굴릴 것이 있다")
	var before := s.state.materials.duplicate()
	var saves := s.autosave_count
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s.modal.kind, "", "「예」로 닫힘")
	check_eq(s._toast.text, "%s를 얻었다 (남은 횟수 1/2)" % _items_text(s, want), "안내 줄(얻었다·남은 횟수)")
	for x in want:
		check_eq(int(s.state.materials.get(x["item"], 0)), int(before.get(x["item"], 0)) + int(x["count"]), "%s +%d" % [x["item"], x["count"]])
	check_eq(s.state.world.gather_used, {"g1": 1}, "쓴 횟수 1")
	check_eq(s.autosave_count, saves + 1, "채집 자동 저장")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), "자동 저장 = 지금 상태")
	await kit.frames(10)
	check_eq(s.modal.kind, "", "채집 뒤 다시 묻지 않는다(§8 Q6)")
	snap = s.debug_snapshot()
	check_eq([snap["gather_here"]["left"], snap["gather_used"]], [1, {"g1": 1}], "스냅숏 남음 1·쓴 횟수")
	var mats := s.state.materials.duplicate()
	var hash_now := kit.hash_now()
	s = await kit.reopen(_arbor())
	await kit.frames(3)
	check_eq([kit.hash_now(), s.state.materials, s.state.world.gather_used, s.state.party.at, s.modal.kind], [hash_now, mats, {"g1": 1}, G1, ""],
		"다시 열기: 같은 해시·소재·쓴 횟수, 도착에 묻지 않는다")
	s.state.encounter.threshold = 99999
	await kit.press_key(KEY_SPACE)
	check(s.modal.kind == "gather" and _labels(s).has("오늘 남은 횟수 1/2"), "조사 → 「오늘 남은 횟수 1/2」 %s" % str(_labels(s)))


## U2 (M-U2 다 쓴 지점에서 물음을 띄움; M-U7 다 쓴 뒤 시야를 다시 만들지 않음): 두 번 쓰면 기둥이 회색으로 바뀌고,
## 떠났다 돌아오면 묻지 않고 알림 「오늘은 더 채집할 수 없다…」, 조사도 같은 알림. 지점 밖 조사는 지금처럼 「아무것도 없다」.
func test_spent_point_notice_and_marker() -> void:
	var s := await _open()
	await _to_g1(s)
	var take: Color = DungeonMeshBuilder.POINT_COLORS["take"]
	var cols := _point_colors(s, G1)
	check(_near(cols.get("plate", []), take) and _near(cols.get("glow", []), DungeonMeshBuilder.POINT_GLOW["take"]) and not cols.has("frame"),
		"새 지점: 초록 몸통·밝은 띠 %s" % str(cols))
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s.state.world.gather_used, {"g1": 1}, "준비: 한 번")
	await kit.press_key(KEY_SPACE)
	var want := _expected(s)
	var mesh0 := _mesh_id(s)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([s.state.world.gather_used, s._toast.text], [{"g1": 2}, "%s를 얻었다 (남은 횟수 0/2)" % _items_text(s, want)], "두 번째: 남은 횟수 0/2")
	check(_mesh_id(s) != mesh0, "다 쓰면 시야를 다시 만든다")
	cols = _point_colors(s, G1)
	check(_near(cols.get("frame", []), DungeonMeshBuilder.POINT_SPENT) and not cols.has("glow") and not _near(cols.get("plate", []), take),
		"다 쓴 지점: 회색 몸통, 띠·초록 없음 %s" % str(cols))
	for k in [KEY_E, KEY_Q]:
		var saves := s.autosave_count
		await kit.press_key(k)
		await kit.frames(3)
		check_eq(s.autosave_count, saves + 1, "이동 자동 저장 그대로")
	check_eq([s.state.party.at, s.modal.kind, s._toast.text], [G1, "", SPENT_TEXT], "다 쓴 지점에 서면 묻지 않고 알림")
	s._toast.text = ""
	await kit.press_key(KEY_SPACE)
	await kit.frames(1)
	check_eq([s.modal.kind, s._toast.text], ["", SPENT_TEXT], "다 쓴 지점 조사 = 같은 알림(「아무것도 없다」가 아니다)")
	var h := kit.hash_now()
	s.request_action(DungeonScreen.A.GATHER)
	await kit.frames(1)
	check_eq([s._toast.text, s.state.world.gather_used], [SPENT_TEXT, {"g1": 2}], "다 쓴 지점 GATHER = 막힘 알림, 그대로")
	check_eq(kit.hash_now(), h, "막힌 GATHER 는 상태를 바꾸지 않는다")
	await kit.press_key(KEY_E)
	await kit.press_key(KEY_SPACE)
	await kit.frames(1)
	check_eq([s.state.party.at, s._toast.text], [PLAIN, s.texts.t("msg.nothing_found")], "지점 밖 조사는 그대로 「아무것도 없다」")
	s.request_action(DungeonScreen.A.GATHER)
	await kit.frames(1)
	check_eq(s._toast.text, "여기에는 채집할 곳이 없다", "지점 밖 GATHER = 「여기에는 채집할 곳이 없다」")


## U3 (M-U3 _open_stairs 가 gather 를 무시): 연출 중 미리 받은 행동, 누르고 있던 키, 다른 창(메모) 뒤, 가져오기.
func test_gather_question_races() -> void:
	var s := await _open()
	# (가) 연출 중 미리 받은 회전은 물음을 건너뛰지 못한다.
	await _beside_g1(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	check(s.view.is_busy() and s.state.party.at == G1, "준비: 지점으로 걷는 연출 중")
	await kit.press_key(KEY_D)
	await _wait_idle(s)
	check_eq([s.modal.kind, s.state.party.at, s.state.party.facing], ["gather", G1, Dir.W], "(가) 연출이 끝나면 채집 물음, 미리 받은 회전은 버림")
	s.view.speed = 0.0
	await kit.press_key(KEY_ESCAPE)
	# (나) 조사(Space)를 누른 채 물음 → 반복·뗌으로 고르지 않는다.
	_key_event(KEY_SPACE, true)
	await kit.frames(3)
	check_eq(s.modal.kind, "gather", "(나) 조사로 물음")
	for i in 3:
		_key_event(KEY_SPACE, true, true)
		await kit.frames(1)
	_key_event(KEY_SPACE, false)
	await kit.frames(3)
	check(s.modal.kind == "gather" and s.state.world.gather_used.is_empty(), "(나) 반복·뗌으로 고르지 않음")
	await kit.press_key(KEY_ESCAPE)
	# (다) 연출 중에 메모 창이 열리면 물음은 남고, 메모 창을 닫으면 채집 물음.
	await _beside_g1(s)
	s.view.speed = 1.0
	await kit.press_key(KEY_W)
	s._on_memo_requested(PLAIN)
	await _wait_idle(s)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "(다) 메모 창이 열린 동안 물음은 남는다")
	await kit.click(kit.center_of(s.modal.find_child("MemoCancel", true, false)))
	await kit.frames(3)
	check_eq([s.modal.kind, s.state.party.at], ["gather", G1], "(다) 메모 창을 닫으면 채집 물음")
	check_eq(_focus(s), s.modal.find_child("GatherYes", true, false), "(다) 「예」에 포커스")
	await kit.press_key(KEY_ESCAPE)
	# (라) 물음이 남은 채 가져오기(상태 바꾸기)를 하면 물음은 버린다.
	await _beside_g1(s)
	var away := SaveCodec.encode(s.state)
	await kit.press_key(KEY_W)
	s._on_memo_requested(PLAIN)
	await _wait_idle(s)
	check_eq([s.modal.kind, s._stairs_ask], ["memo", true], "(라) 준비: 메모 창 뒤에 물음")
	check(s.import_text(away), "(라) 가져오기")
	s.view.speed = 0.0
	await kit.frames(3)
	check_eq([s.modal.kind, s._stairs_ask, s.state.party.at], ["", false, PLAIN], "(라) 가져오면 물음을 버린다")


## U4 (M-U4a 서 보지 않은 지점도 셈, M-U4b 지금 층만 셈, M-U4c 판 색이 다름): 캠프 뿌리 채집 알약 셋(그린 기록).
## 세 크기에서 자리 W − 490 + 152·i, y 140, 136×64, 채움 #071E26 α 0.8, 글 절단·추출·채취 / 「n / m」. 그림 창 안,
## 알림 줄·소지금·명령 목록·카드·키패드와 겹치지 않는다. 새 게임 0 / 0, g1 에 서면 채취 2 / 2, 한 번 쓰면 1 / 2, 다른 층 지점도 더한다.
func test_camp_pills() -> void:
	var s := await _open()
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(pm.page, "root", "준비: 캠프 뿌리")
	for px in SIZES:
		var size: Vector2 = await _window(px)
		await kit.frames(2)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var w := size.x
		var pills := _pills(pm)
		check_eq(pills.size(), 3, tag + ": 알약 셋")
		for i in pills.size():
			var r: Rect2 = pills[i]["rect"]
			check_eq(r, Rect2(w - 490.0 + 152.0 * i, 140, 136, 64), "%s: 알약 %d 자리" % [tag, i])
			check_eq(pills[i]["color"], Color(0x07 / 255.0, 0x1e / 255.0, 0x26 / 255.0, 0.8), "%s: 알약 %d 채움 #071E26 α 0.8(원작 III HD)" % [tag, i])
			check_eq(pills[i]["texts"], [["절단", "추출", "채취"][i], "0 / 0"], "%s: 알약 %d 글(새 게임 0 / 0)" % [tag, i])
			for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				check(CampBackdrop.in_window(c, w), "%s: 알약 %d 모서리 %s 는 그림 창 안" % [tag, i, str(c)])
			var others := [_rect(pm.notice_line), _rect(pm.money_plate), _rect(pm.camp_list), _rect(pm.dir_pad), _rect(pm.key_pad), _rect(pm.ribbon)]
			for c in pm.cards.cards:
				others.append(_rect(c))
			check(not others.any(func(o: Rect2) -> bool: return o.intersects(r)), "%s: 알약 %d 는 알림 줄·소지금·목록·카드·키패드와 겹치지 않는다" % [tag, i])
			check(r.position.y >= PartyMenu.NOTICE_BOTTOM, "%s: 알약 %d 는 알림 줄(y ≤ 108) 아래" % [tag, i])
		check_eq(pm.gather_pills.mouse_filter, Control.MOUSE_FILTER_IGNORE, tag + ": 보이기만(누르기 없음)")
	tree.root.size = _root_size
	await kit.frames(3)
	check_eq(s.debug_snapshot()["party_menu"]["gather_pills"], [{"kind": "chop", "left": 0, "max": 0}, {"kind": "mine", "left": 0, "max": 0},
		{"kind": "take", "left": 0, "max": 0}], "스냅숏 gather_pills(그린 차례)")
	await kit.press_key(KEY_2)
	await kit.frames(1)
	check(pm.page == "pick" and pm.gather_pills.is_visible_in_tree(), "대원 고르기에도 보인다")
	await kit.press_key(KEY_ENTER)
	await kit.frames(1)
	check(pm.page == "sub" and not pm.gather_pills.is_visible_in_tree() and s.debug_snapshot()["party_menu"]["gather_pills"] == [], "하위 화면에서는 감춘다")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_ESCAPE)
	check(not pm.is_open(), "준비: 캠프 닫힘")
	# g1 에 서 본다(묻는 창은 닫는다) → 채취 2 / 2. g2(절단)는 서 보지 않았다.
	await _to_g1(s)
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(_pills(pm).map(func(p: Dictionary) -> Array: return p["texts"]), [["절단", "0 / 0"], ["추출", "0 / 0"], ["채취", "2 / 2"]],
		"g1 에 서면 채취 2 / 2, 서 보지 않은 g2 는 세지 않는다")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_SPACE)
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s.state.world.gather_used, {"g1": 1}, "준비: 한 번 채집")
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(_pills(pm)[2]["texts"], ["채취", "1 / 2"], "한 번 쓰면 채취 1 / 2")
	await kit.press_key(KEY_ESCAPE)
	# 다른 층(B2F)에서 서 본 지점도 더한다: g1(채취)·g3(추출)에 서 봤고 g3 을 한 번 썼다.
	var b2 := s.state.defs.floor_by_id("b2f")
	var here := s.state.floor_def
	s.state.enter_floor(b2)
	s.state.knowledge.visit(b2.points["g1"].at)
	s.state.knowledge.visit(b2.points["g3"].at)
	s.state.world.gather_used = {"g3": 1}
	s.state.enter_floor(here)
	await kit.press_key(KEY_P)
	await kit.frames(2)
	check_eq(_pills(pm).map(func(p: Dictionary) -> Array: return p["texts"]), [["절단", "0 / 0"], ["추출", "1 / 2"], ["채취", "3 / 4"]],
		"모든 층에서 서 본 지점을 더한다(B1F g1 1/2 + B2F g1 2/2, B2F g3 1/2)")


## U5 (M-U5 숙박이 쓴 횟수를 비우지 않음): 실제 흐름 — 두 번 채집 → 마을 문 → 마을 캠프 채취 0 / 2 → 숙박 → 마을 캠프 2 / 2,
## 숙박 자동 저장의 gather_used 가 비었다 → 탐사 시작 → g1 에 서면 「2/2」로 묻고 기둥은 다시 초록.
func test_inn_stay_restores_uses_through_the_real_flow() -> void:
	var s := await _open()
	await _to_g1(s)
	for i in 2:
		if s.modal.kind != "gather":
			await kit.press_key(KEY_SPACE)
		await kit.press_key(KEY_ENTER)
		await kit.frames(3)
	check_eq(s.state.world.gather_used, {"g1": 2}, "준비: 두 번")
	await kit.press_key(KEY_E)
	await kit.press_key(KEY_S)
	await kit.frames(3)
	check_eq([s.state.party.at, s.modal.kind], [START, "stairs"], "마을 문 물음")
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check(s.state.in_town() and s.town_screen.is_open(), "마을 광장")
	var t := s.town_screen
	var pm := s.party_menu
	await kit.tap(kit.center_of(t.find_child("CampButton", true, false)))
	await kit.frames(2)
	check(pm.is_open() and pm.page == "root", "마을 캠프")
	check_eq(_pills(pm)[2]["texts"], ["채취", "0 / 2"], "마을 캠프: 채취 0 / 2(미궁과 같다)")
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(2)
	await kit.tap(kit.center_of(t.plaza_list.rows[0]))
	await kit.frames(1)
	check_eq(t.page, "inn", "준비: 숙소")
	var saves := s.autosave_count
	await kit.tap(kit.center_of(t.inn_list.rows[0]))
	await kit.tap(kit.center_of(t.dialog.yes_button))
	await kit.frames(2)
	check_eq([s.state.day, s.autosave_count], [2, saves + 1], "숙박: 2일째, 자동 저장")
	var doc := _auto_doc(s)
	check_eq([doc["state"]["day"], doc["state"]["floor_states"]["b1f"]["world"]["gather_used"]], [2.0, {}], "숙박 자동 저장: 쓴 횟수가 비었다")
	await kit.tap(kit.center_of(t.find_child("CampButton", true, false)))
	await kit.frames(2)
	check_eq(_pills(pm)[2]["texts"], ["채취", "2 / 2"], "숙박 뒤 마을 캠프: 채취 2 / 2")
	await kit.press_key(KEY_ESCAPE)
	await kit.frames(2)
	s._enter_labyrinth()
	await kit.frames(3)
	s.state.encounter.threshold = 99999
	check(_near(_point_colors(s, G1).get("plate", []), DungeonMeshBuilder.POINT_COLORS["take"]), "다시 들어가면 기둥이 초록(다시 만든 시야)")
	await _to_g1(s)
	check(s.modal.kind == "gather" and _labels(s).has("오늘 남은 횟수 2/2"), "g1 물음 「오늘 남은 횟수 2/2」 %s" % str(_labels(s)))


## U6 (M-U6 가방이 차면 횟수를 씀): 59/60 에서 채집(스킬 갈고리로 개수 +2) → 들어가는 만큼만 넣고 「…개는 가방에 들어가지 않았다」,
## 60/60, 다시 읽어 같다. 60/60 에서 「예」 → 「가방이 가득하다…」, 쓴 횟수 그대로(자동 저장에도).
func test_bag_partial_and_full_through_the_real_flow() -> void:
	var s := await _open()
	GatherRules.bonus_hook = func(_st: ExplorationState, _k: String) -> Dictionary: return {"count": 2, "rare_permille": 0}
	s.state.materials = {"item.neon_rat_tail": 59}
	await _beside_g1(s)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq([s.modal.kind, BagRules.used(s.state)], ["gather", 59], "준비: 59/60 에서 채집 물음")
	var want := _expected(s)
	var total := 0
	for x in want:
		total += int(x["count"])
	check(total >= 3, "준비: 굴림이 3개 이상 %s" % str(want))
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq(s._toast.text, "%s를 얻었다. %d개는 가방에 들어가지 않았다" % [_items_text(s, want), total - 1], "들어가지 않은 수 알림")
	check_eq([BagRules.used(s.state), int(s.state.materials.get(want[0]["item"], 0)), s.state.world.gather_used], [60, 1, {"g1": 1}],
		"60/60, 첫 줄 하나만, 횟수는 씀")
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == kit.hash_now(), "자동 저장 = 지금 상태")
	await kit.press_key(KEY_SPACE)
	check_eq(s.modal.kind, "gather", "준비: 60/60 에서 조사로 물음")
	var h := kit.hash_now()
	var saves := s.autosave_count
	await kit.press_key(KEY_ENTER)
	await kit.frames(3)
	check_eq([s._toast.text, s.state.world.gather_used, kit.hash_now()], ["가방이 가득하다. 채집하지 않았다", {"g1": 1}, h], "가득: 알림, 그대로")
	check_eq(s.autosave_count, saves + 1, "받아들인 행동이라 자동 저장한다")
	check_eq(_auto_doc(s)["state"]["floor_states"]["b1f"]["world"]["gather_used"], {"g1": 1.0}, "자동 저장의 쓴 횟수도 그대로")
	var hash_now := kit.hash_now()
	GatherRules.bonus_hook = Callable()
	s = await kit.reopen(_arbor())
	await kit.frames(3)
	check_eq([kit.hash_now(), BagRules.used(s.state), s.state.world.gather_used], [hash_now, 60, {"g1": 1}], "다시 열기: 같은 해시·60/60·쓴 횟수")


## U8 (터치·키 = 키패드): 물음이 떠 있으면 HUD 단추는 어둠 막이 먹고, ←→ 로 포커스를 옮기고, 「조사」 단추로 다시 묻고, 「예」 터치로 채집.
func test_gather_modal_by_touch_and_keys() -> void:
	var s := await _open()
	await _beside_g1(s)
	await kit.press_key(KEY_W)
	await kit.frames(3)
	check_eq(s.modal.kind, "gather", "준비: 채집 물음")
	var h := kit.hash_now()
	for b in [s.pad[DungeonScreen.A.FORWARD], s.pad[DungeonScreen.A.INVESTIGATE], s.camp_button]:
		await kit.tap(kit.center_of(b))
		await kit.frames(2)
		check_eq([s.modal.kind, kit.hash_now(), s.party_menu.is_open()], ["gather", h, false], "물음 아래 %s 누르기는 먹힌다" % (b as Control).name)
	await kit.press_key(KEY_RIGHT)
	await kit.frames(1)
	check_eq(_focus(s), s.modal.find_child("GatherNo", true, false), "→ 「아니오」")
	await kit.press_key(KEY_LEFT)
	await kit.frames(1)
	check_eq(_focus(s), s.modal.find_child("GatherYes", true, false), "← 「예」")
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_ENTER)
	await kit.frames(2)
	check_eq([s.modal.kind, kit.hash_now()], ["", h], "「아니오」에서 Enter = 닫기만")
	await kit.tap(kit.center_of(s.pad[DungeonScreen.A.INVESTIGATE]))
	await kit.frames(3)
	check_eq(s.modal.kind, "gather", "「조사」 단추 터치로 다시 묻는다")
	await kit.tap(kit.center_of(s.modal.find_child("GatherNo", true, false)))
	await kit.frames(2)
	check_eq(s.modal.kind, "", "「아니오」 터치")
	await kit.tap(kit.center_of(s.pad[DungeonScreen.A.INVESTIGATE]))
	await kit.frames(3)
	await kit.tap(kit.center_of(s.modal.find_child("GatherYes", true, false)))
	await kit.frames(3)
	check(s.modal.kind == "" and s.state.world.gather_used == {"g1": 1}, "「예」 터치로 채집")


## 층 표(§5.1·§5.2): 채집 물음 창이 세 크기에서 화면 안이고 글·단추가 창 안. 채집 안내 글은 1280×720 알림 줄 폭 안
## (실제 글꼴, 가장 긴 소재 이름·개수·희귀·잃은 수, 새 「…다시 채집할 수 있다」 포함).
func test_question_and_notice_fit() -> void:
	var s := await _open()
	await _to_g1(s)
	check_eq(s.modal.kind, "gather", "준비: 물음")
	for px in SIZES:
		var size: Vector2 = await _window(px)
		await kit.frames(2)
		var screen := Rect2(Vector2.ZERO, size)
		var panel := s.modal._panel.get_global_rect()
		check(screen.encloses(panel), "%s: 물음 창이 화면 안 %s" % [px, str(panel)])
		for l in s.modal.find_children("*", "Label", true, false):
			var lb := l as Label
			check(panel.encloses(lb.get_global_rect()) and lb.get_visible_line_count() == lb.get_line_count(), "%s: 「%s」 창 안, 잘리지 않는다" % [px, lb.text])
		for n in ["GatherYes", "GatherNo"]:
			check(panel.encloses((s.modal.find_child(n, true, false) as Control).get_global_rect()), "%s: %s 창 안" % [px, n])
	tree.root.size = _root_size
	await kit.frames(3)
	var font := s._toast.get_theme_default_font()
	var fs := s._toast.get_theme_font_size("font_size")
	var room := s.get_viewport_rect().size.x - 2.0 * DungeonScreen.EDGE
	var db := s.state.defs.battle
	var cands: Array[String] = [SPENT_TEXT, s.texts.t("msg.gather_full"), s.texts.t("msg.not_gather")]
	for id in db.gather_table_ids:
		var t := db.gather_table(id)
		for x in t.items:
			var main := {"item": x["item"], "count": int(x["hi"]) + 2}
			var items: Array = [main] if t.rare_item.is_empty() else [main, {"item": t.rare_item, "count": 1}]
			var text := s.gather_text({"type": "gathered", "items": items, "lost": 0, "left": 9, "uses": 9})
			cands.append(text)
			cands.append(s.gather_text({"type": "gathered", "items": items, "lost": 9, "left": 0, "uses": 9}))
	check_eq(s.texts.t("msg.gather_spent"), SPENT_TEXT, "새 다 씀 글")
	for t in cands:
		check(font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= room, "알림 줄 폭 안: %s" % t)


## 소지품 소재 설명(설계 §2.6, 그린 글·색): 「설명 글 · 소재 · 판매값 n엔」, 세 크기에서 몸 안·흰 글.
func test_material_description_line() -> void:
	var s := await _open()
	s.state.materials = {"item.neon_moss": 3}
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_1)
	await kit.frames(2)
	var it := pm.items_tab
	check_eq(it.row_items, ["item.neon_moss"], "준비: 소지품 줄 = 네온 이끼")
	var want := ["빛을 머금은 이끼. 어디서나 자라지만 정크 공방이 늘 사 간다", "소재", "판매값 5엔"]
	check_eq(it.item_lines("item.neon_moss"), want, "설명 줄")
	for px in SIZES:
		var size: Vector2 = await _window(px)
		it.desc.show_desc(it.item_label("item.neon_moss"), it.item_icon("item.neon_moss"), it.item_lines("item.neon_moss"))
		await kit.frames(2)
		var tag := str(px)
		var d := it.desc
		var r := Rect2(Vector2.ZERO, d.size)
		var body_r := ListParts.body_rect(r)
		var rec := SheetParts.record(d)
		var body := rec.filter(func(e: Dictionary) -> bool:
			return e["kind"] == "text" and body_r.has_point((e["rect"] as Rect2).position + Vector2(1, int(e["fs"]) * 0.6)))
		check_eq(body.map(func(e: Dictionary) -> String: return e["text"]), want, tag + ": 그린 몸 줄")
		check(body.all(func(e: Dictionary) -> bool: return e["color"] == ListParts.DESC_TEXT and int(e["fs"]) >= ListParts.DESC_FS_MIN), tag + ": 흰 글·12px 이상")
		check(rec.any(func(e: Dictionary) -> bool: return e["kind"] == "fill" and e["rect"] == body_r and e["color"] == ListParts.DESC_BODY), tag + ": 몸 채움")
		for e in body:
			var er: Rect2 = e["rect"]
			check(SheetParts.text_width(d, e["text"], int(e["fs"])) <= er.size.x + 0.5 and body_r.encloses(Rect2(er.position, Vector2(er.size.x, 1))),
				"%s: 「%s」 몸 안에 든다" % [tag, e["text"]])
		check(Rect2(Vector2.ZERO, size).encloses(d.get_global_rect()), tag + ": 설명 상자가 화면 안")
