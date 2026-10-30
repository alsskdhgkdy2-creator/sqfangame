## 일반 적 둘의 전투 화면(M3 A3c 설계 §5·§7.1 U1~U5): 새 적 카드의 이름·색(자리표시, 그림은 B6), 상태·봉인·강화 딱지가 많아도 카드 안에 머문다(「+N」),
## 띠 글이 세 크기(1280×720·1728×720·1280×960)에서 방에 들어간다, 반딧불의 치료가 로그·숫자·카드 HP 로 보인다, 카드 노드의 주인.
## 층만 띄운다(저장은 쓰지 않는다). 시험마다 죽이는 변이(M-U…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const F_MIX := "formation.b3.beetle_firefly_wisp"  # 갑충 0 · 뱀 1(전열) · 반딧불 2 · 도깨비불 3(후열)
const F_SERPENTS := "formation.b2.firefly_serpents"
const SIGNAL := "skill.enemy.glow_signal"
const SIZES := [Vector2(1280, 720), Vector2(1728, 720), Vector2(1280, 960)]
## 같은 이름이 둘 이상이면 화면이 뒤에 「 A」「 B」를 붙인다(와이어 뱀 A). 두 이름 모두 그 꼴까지 잰다.
const NEW_NAMES := ["수액 반딧불", "명멸 도깨비불", "수액 반딧불 B", "명멸 도깨비불 A"]
const NEW_SKILLS := ["skill.enemy.sap_drip", "skill.enemy.glow_signal", "skill.enemy.glow_sting", "skill.enemy.will_fire", "skill.enemy.flicker_jam"]

var kit: Kit
var host: Control
var layer: BattleLayer
var texts: TextDb
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if host != null and is_instance_valid(host):
		tree.root.remove_child(host)
		host.free()
	host = null
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _open(px: Vector2, s: ExplorationState) -> BattleLayer:
	timeout_sec = 90.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host = Control.new()
	host.name = "SupportHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	host.size = tree.root.get_visible_rect().size
	layer = BattleLayer.new()
	host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = 0.0
	layer.save_hook = func() -> void: pass
	layer.open(s)
	await kit.frames(2)
	return layer


func _state(formation: String, seed_value: int = 5) -> ExplorationState:
	return Fx.battle(Fx.arbor(), formation, seed_value)


func _card(slot: int) -> BattleCard:
	return layer.enemy_area.card(slot)


## U1 (M-U1 반딧불이 나방과 같은 색, M-U2 뒤 칸 이름 글자 크기 17 → 30): 새 적 카드 둘의 이름·색, 카드 안 이름 너비(앞 160 → fs 20, 뒤 150 → fs 17), 색 구별.
func test_cards_names_colors_and_name_width() -> void:
	var font: Font = null
	for px in SIZES:
		var l := await _open(px, _state(F_MIX))
		font = l.get_theme_default_font()
		check_eq(l.enemy_area.cards.map(func(c: BattleCard) -> String: return c.unit().name), ["집게 갑충", "와이어 뱀", "수액 반딧불", "명멸 도깨비불"], "%s: 적 카드 이름" % str(px))
		var win := Rect2(Vector2.ZERO, l.size)
		for c in l.enemy_area.cards:
			var r := Rect2(c.global_position, c.size)
			check(win.encloses(r), "%s: 카드 %s 가 화면 안 %s / %s" % [str(px), c.name, str(r), str(win)])
			var fs := BattleCard.enemy_name_fs(c.size.x)
			var w := font.get_string_size(c.unit().name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			check(w <= c.size.x, "%s: %s 이름 너비 %d ≤ 카드 %d (fs %d)" % [str(px), c.unit().name, w, c.size.x, fs])
		check_eq([_card(2).size.x, _card(3).size.x, _card(0).size.x], [150.0, 150.0, 160.0], "%s: 후열 150 · 전열 160" % str(px))
		# 가장 긴 이름은 지금 있는 가장 긴 이름(잠식된 탐험가, 7자)과 같은 너비다: fs 20 → 115, fs 17 → 98.
		check_eq([int(font.get_string_size("명멸 도깨비불", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x), int(font.get_string_size("명멸 도깨비불", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x)],
			[115, 98], "%s: 명멸 도깨비불 너비 115 / 98" % str(px))
	# 색: 새 둘은 정해진 값이고, 다른 적 여섯·직업색 여섯과 RGB 거리 0.12 이상.
	var cols: Dictionary = BattleCard.ENEMY_COLORS
	check_eq(cols["enemy.sap_firefly"], Color(0.64, 0.56, 0.18), "반딧불 자리표시 색")
	check_eq(cols["enemy.flicker_wisp"], Color(0.24, 0.40, 0.52), "도깨비불 자리표시 색")
	var others: Array[Color] = []
	for k in cols:
		others.append(cols[k])
	others.append_array(BattleCard.CLASS_COLORS.values())
	check_eq(cols.size(), 8, "적 색 여덟")
	for id in ["enemy.sap_firefly", "enemy.flicker_wisp"]:
		var mine: Color = cols[id]
		var nearest := 9.0
		for o in others:
			if o != mine:
				nearest = minf(nearest, Vector3(mine.r - o.r, mine.g - o.g, mine.b - o.b).length())
		check(nearest >= 0.12, "%s: 다른 적·직업색과 RGB 거리 %.3f ≥ 0.12" % [id, nearest])


## U2: 딱지가 많은 새 적 카드(상태이상 1 + 봉인 3 + 점멸 신호 강화 1 + 약화 3 = 8)도 모든 딱지가 카드 안에 있고, 두 줄에 다 못 놓으면 「+N」이 나머지 수를 센다.
## 그려지는 딱지 기록(drawn_chips)으로 본다. 세 크기에서 같다.
func test_chips_stay_inside_the_card() -> void:
	var s := _state(F_MIX)
	var wisp := s.battle.enemies[3]
	var fly := s.battle.enemies[2]
	# 약화 셋: 종류만 다른 세 칸(딱지 글은 종류와 남은 턴으로 정해진다).
	var kinds := ["phys_def", "elem_def", "elem_atk"]
	for u in [wisp, fly]:
		u.ailment = "poison"
		u.ailment_turns = 3
		u.ailment_damage = 6
		u.binds = {"head": 3, "arm": 2, "leg": 1}
		u.buffs.assign([{"id": SIGNAL, "kind": "phys_atk", "value": 1250, "turns": 2, "seq": 1}])
		var ds: Array[Dictionary] = []
		for i in 3:
			ds.append({"id": "skill.enemy.rending_howl", "kind": kinds[i], "value": 800, "turns": 3, "seq": 2 + i})
		u.debuffs.assign(ds)
	s.battle.seq = 6
	for px in SIZES:
		var l := await _open(px, s)
		for slot in [2, 3]:
			var c := _card(slot)
			var all_chips := l.display.chips(c.unit())
			check_eq(all_chips.size(), 8, "%s 칸 %d: 딱지 여덟(상태 1 · 봉인 3 · 강화 1 · 약화 3)" % [str(px), slot])
			var drawn := c.drawn_chips()
			var area := c.chip_area()
			var hidden := 0
			var shown := 0
			for d in drawn:
				var r: Rect2 = d["rect"]
				check(area.grow(0.01).encloses(r), "%s 칸 %d: 딱지 %s 가 딱지 자리 안 %s / %s" % [str(px), slot, d["text"], str(r), str(area)])
				if d["kind"] == "more":
					hidden += int(d["hidden"])
				else:
					shown += 1
			check_eq(shown + hidden, 8, "%s 칸 %d: 그린 딱지 + 「+N」 = 여덟" % [str(px), slot])
			check(hidden > 0 and drawn[-1]["kind"] == "more", "%s 칸 %d: 두 줄에 다 못 놓아 「+N」이 맨 끝에 있다 (%d 가려짐)" % [str(px), slot, hidden])
			check(shown >= 1 and drawn.any(func(d: Dictionary) -> bool: return d["kind"] == "ailment"), "%s 칸 %d: 첫 딱지는 상태이상" % [str(px), slot])
		# 강화만 걸린 카드는 모두 놓이고 「공」 딱지가 보인다.
		var s2 := _state(F_MIX)
		s2.battle.enemies[2].buffs.assign([{"id": SIGNAL, "kind": "phys_atk", "value": 1250, "turns": 2, "seq": 1}])
		s2.battle.seq = 2
		var l2 := await _open(px, s2)
		var only := _card(2).drawn_chips()
		check_eq(only.map(func(d: Dictionary) -> Array: return [d["kind"], d["text"]]), [["buff", "공 2"]], "%s: 강화 하나 = 「공 2」 딱지 하나" % str(px))
		check(Rect2(Vector2.ZERO, _card(2).size).encloses(only[0]["rect"]), "%s: 딱지가 카드 안" % str(px))


## U3 (M-U4 가장 긴 띠 줄이 방을 넘음): 새 적 이름·스킬 이름이 들어간 띠 글이 세 크기에서 방(= 띠 너비 − 2 × 34 − 로그 단추 120 − 8)에 들어간다.
## 글 틀은 조사 「은(는)」을 풀어 쓴다. 가장 긴 줄은 혼란 줄(「명멸 도깨비불 A」 + 8자 대원 이름)이다.
func test_banner_lines_fit_at_three_sizes() -> void:
	var party8 := "가나다라마바사아"
	for px in SIZES:
		var l := await _open(px, _state(F_MIX))
		var font := l.get_theme_default_font()
		var room := l.banner_rect().size.x - 2.0 * BattleLayer.BANNER_PAD - BattleLayer.LOG_BUTTON.x - BattleLayer.LOG_RIGHT
		var worst := 0.0
		var lines: Array[String] = []
		for who in NEW_NAMES:
			lines.append(texts.t("battle.event.confused", {"actor": who, "target": party8}))
			lines.append(texts.t("battle.event.healed", {"target": who, "amount": 999}))
			lines.append(texts.t("battle.event.buffed", {"target": who, "skill": texts.t(SIGNAL)}))
			lines.append(texts.t("battle.event.damaged", {"target": who, "amount": 9999}))
			lines.append(texts.t("battle.event.defeated", {"target": who}))
			lines.append(texts.t("battle.event.ailment", {"target": party8, "ailment": texts.t("ailment.confusion")}))
			for sk in NEW_SKILLS:
				lines.append(texts.t("battle.event.action", {"actor": who, "skill": texts.t(sk)}))
		for line in lines:
			var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, BattleLayer.BANNER_FS).x
			worst = maxf(worst, w)
			check(w <= room, "%s: 「%s」 %d px ≤ 방 %d px" % [str(px), line, w, room])
		check(worst > 700.0 and worst <= 891.0, "%s: 가장 긴 줄 %d px 는 891 이하(1280 폭 방)" % [str(px), worst])
		print("WIDTH %s worst=%d room=%d" % [str(px), worst, room])


## U4 (M-U3 describe(healed) 가 대상 이름을 잃음): 반딧불의 치료가 실제 층에서 로그 줄·카드 HP·「+38」 숫자로 보인다. 점멸 신호는 적 셋의 카드에 「공」 딱지.
func test_heal_and_buff_are_visible() -> void:
	var s := _state(F_SERPENTS, 9)
	var b := s.battle
	b.enemies[0].hp = 40
	var ref := _state(F_SERPENTS, 9)
	ref.battle.enemies[0].hp = 40
	var ev_ref := BattleRules.submit(ref, Fx.cmds(ref))
	var healed: Array = ev_ref.filter(func(e: Dictionary) -> bool: return e["type"] == "healed")
	check_eq(healed.size(), 1, "준비: 규칙 한 턴에 치료 하나")
	var l := await _open(Vector2(1280, 720), s)
	l.handle("commands", Fx.cmds(s))
	await kit.frames(2)
	check_eq(l.display.enemies[0].hp, 78, "카드 쪽 HP 도 78")
	var want_line := texts.t("battle.event.healed", {"target": "와이어 뱀 A", "amount": 38})
	check(l.log_view.lines.has(want_line), "로그에 「%s」 %s" % [want_line, str(l.log_view.lines)])
	check(l.log_view.lines.any(func(t: String) -> bool: return t == texts.t("battle.event.action", {"actor": "수액 반딧불", "skill": "감로"})), "로그에 반딧불의 감로 줄")
	# 숫자: 규칙이 낸 healed 이벤트를 그대로 넣으면 대상 카드에 「+38」.
	l._popup_for(healed[0])
	check_eq(_card(0).popups.map(func(p: Dictionary) -> String: return p["text"]), ["+38"], "치료 숫자는 대상(뱀 0) 카드에 「+38」")
	# 강화: 턴 0 점멸 신호.
	var s2 := _state(F_SERPENTS, 9)
	var l2 := await _open(Vector2(1280, 720), s2)
	l2.handle("commands", Fx.cmds(s2))
	await kit.frames(2)
	for slot in 3:
		check_eq(l2.display.chip_texts(l2.display.enemies[slot]), ["▲공 1"], "턴 끝 적 칸 %d: 강화 딱지 「공 1」" % slot)
	check(l2.log_view.lines.has(texts.t("battle.event.buffed", {"target": "수액 반딧불", "skill": "점멸 신호"})), "로그에 반딧불 자신에게 건 줄도 있다")


## U5 (lesson 15: 주인): 새 카드 노드는 모두 트리 안에 있고 층을 닫으면 함께 사라진다(떠도는 노드 없음).
func test_card_nodes_are_owned_by_the_tree() -> void:
	var l := await _open(Vector2(1280, 720), _state(F_MIX))
	for c in l.enemy_area.cards:
		check(c.is_inside_tree() and l.enemy_area.is_ancestor_of(c), "%s 는 적 영역 아래에 있다" % c.name)
	var ids := l.enemy_area.cards.map(func(c: BattleCard) -> int: return c.get_instance_id())
	tree.root.remove_child(host)
	host.free()
	host = null
	await kit.frames(2)
	check(ids.all(func(i: int) -> bool: return not is_instance_id_valid(i)), "층을 지우면 카드 노드도 해제된다")
