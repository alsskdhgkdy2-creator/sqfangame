## 전투 「아이템」 명령 화면(M3 A4c 설계 §6.2·§8.4): 다섯 줄(공격·스킬·방어·아이템·도주, 키 1~5 = 키패드), 명령 목록 170,108 → 493,534,
## 아이템 목록(스킬 판 자리, Item_k 줄, 오른쪽 상자 = 보이는 남은 수, 설명은 위 띠), 보이는 남은 수 = 가진 수 − 다른 대원의 예약(규칙
## item_block_reason·check_commands 와 같은 셈), 흐린 줄과 이유(전투에서는 쓸 수 없다·남은 수 없음·대상 없음), 「아이템」 줄 흐림(쓸 아이템이 없다),
## 대상 고르기(대리 스킬의 대상, 카드에 아이템 이름, 뒤로 = 아이템 목록), 뒤로가 그 대원 명령과 예약을 버림, 실행 뒤 수 = 상태(item_used 만큼),
## 명령 단계 저장 → 다시 읽기(예약은 저장하지 않는다), 그린 색(ListRow.drawn), 세 크기의 층·64px·노랑 하나.
## 결과는 구성으로 정한다(D15: 적은 아무것도 하지 않고 나방은 쓰러지지 않는다). 저장은 장면 시험 임시 폴더에만.
## 시험마다 죽이는 변이(M-V…)를 적는다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const Fx := preload("res://tests/fixtures.gd")
const RATS_MOTH := "formation.f1.rats_moth"
const MOTH := "enemy.cable_moth"
const MEDICA := "use.medica"
const AMRITA := "use.amrita"
const NECTAR := "use.nectar"
const THERIACA_A := "use.theriaca_a"
const THERIACA_B := "use.theriaca_b"
const BEACON := "use.ariadne_beacon"
## 1280×720 · 2400×1000(논리 1728×720) · 1280×960.
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000), Vector2(1280, 960)]

var kit: Kit
var host: Control
var layer: BattleLayer
var texts: TextDb
var saves := 0
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


func _window(px: Vector2) -> Vector2:
	timeout_sec = 90.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 끝나지 않는 rats_moth(적은 아무것도 하지 않고 나방은 쓰러지지 않는다)에 소모품을 둔다.
static func _calm(items: Dictionary) -> ExplorationState:
	var s := Fx.battle(Fx.quiet_defs({}, [MOTH]), RATS_MOTH, 5)
	s.consumables = items.duplicate()
	return s


## 전투 층만 띄운다(화면 크기 px). 저장 갈고리는 센다.
func _open(s: ExplorationState, px: Vector2 = SIZES[0]) -> BattleLayer:
	var size: Vector2 = await _window(px)
	if host != null:
		tree.root.remove_child(host)
		host.free()
	saves = 0
	host = Control.new()
	host.name = "ItemsHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(host)
	host.size = size
	layer = BattleLayer.new()
	host.add_child(layer)
	layer.build(texts)
	layer.anim_speed = 0.0
	layer.save_hook = func() -> void: saves += 1
	layer.open(s)
	await kit.frames(2)
	return layer


func _step(kind: String, arg: Variant = null) -> bool:
	var ok := layer.handle(kind, arg)
	await kit.frames(1)
	return ok


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _item_row(id: String) -> ListRow:
	for b in layer.panel.item_rows:
		if b.visible and b.get_meta("item_id", "") == id:
			return b
	return null


## 지금 대원: 「아이템」 → 소모품 id → 대상 칸 slot(아군).
func _use(id: String, slot: int) -> void:
	await _step("command", CommandPanel.CMD_ITEM)
	await _step("item", id)
	await _step("target", {"side": BattleUnit.PARTY, "slot": slot})


## 노랑으로 채워 그린 명령·아이템 줄(ListRow.drawn 의 채움 위 색).
func _yellow_rows() -> Array:
	var out := []
	for b in layer.panel.command_buttons + layer.panel.item_rows + [layer.panel.back_button, layer.panel.execute_button]:
		var r := b as ListRow
		if r.is_visible_in_tree() and not r.drawn.is_empty() and _is_yellow(r.drawn["top"]):
			out.append(str(r.name))
	return out


static func _is_yellow(c: Color) -> bool:
	return c.h >= 0.1 and c.h <= 0.19 and c.s >= 0.4 and c.v >= 0.75


static func _look(state: String) -> Array:
	var lk := UiTheme.look(state)
	return [lk["top"], lk["bottom"], lk["text"]]


static func _paint(r: ListRow) -> Array:
	return [r.drawn.get("top"), r.drawn.get("bottom"), r.drawn.get("text")]


# ---- 명령 다섯 줄·키 ----

## M-V2(키 5 가 도주에 묶이지 않음): 공격·스킬·방어·아이템·도주, 「4  아이템」「5  도주」. 키 4 = 아이템 목록, 키 5 = 도주(숫자패드도),
## 키패드 ↓·선택 = 키 ↓·Enter.
func test_five_commands_with_item_fourth_and_keys() -> void:
	await _open(_calm({MEDICA: 2}))
	var p := layer.panel
	check_eq(p.command_buttons.map(func(b: ListRow) -> String: return str(b.name)), ["Cmd_attack", "Cmd_skill", "Cmd_guard", "Cmd_item", "Cmd_escape"], "줄 다섯")
	check_eq(p.command_buttons.map(func(b: ListRow) -> String: return b.text), ["1  공격", "2  스킬", "3  방어", "4  아이템", "5  도주"], "줄 글")
	await kit.press_key(KEY_4)
	check_eq([layer.sub, layer.member], ["items", 0], "키 4 → 아이템 목록")
	await kit.press_key(KEY_ESCAPE)
	check_eq([layer.sub, layer.cursor], ["menu", CommandPanel.CMD_ITEM], "Esc → 메뉴, 커서 「아이템」")
	await kit.press_key(KEY_KP_4)
	check_eq(layer.sub, "items", "숫자패드 4 = 4")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_5)
	check_eq([layer.commands[0], layer.member], [{"kind": "escape"}, 1], "키 5 → 도주(다음 대원)")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_KP_5)
	check_eq(layer.commands[0], {"kind": "escape"}, "숫자패드 5 = 5")
	await kit.press_key(KEY_ESCAPE)
	# 키패드 = 키: 커서를 ↓ 세 번 → 「아이템」, 선택 → 목록.
	check_eq([layer.sub, layer.member, layer.cursor], ["menu", 0, 0], "준비: 첫 대원 메뉴 커서 0")
	for i in 3:
		await kit.tap(kit.center_of(layer.dir_pad.button("down")))
	check_eq(layer.cursor, CommandPanel.CMD_ITEM, "키패드 ↓×3 → 「아이템」")
	await kit.tap(kit.center_of(layer.key_pad.button("ok")))
	check_eq(layer.sub, "items", "키패드 선택 → 아이템 목록")
	await kit.press_key(KEY_DOWN)
	check_eq(layer.cursor, 0, "줄 하나: ↓ 는 감아서 그대로")
	await kit.tap(kit.center_of(layer.key_pad.button("back")))
	check_eq(layer.sub, "menu", "키패드 취소 = Esc")
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	await kit.press_key(KEY_UP)
	check_eq(layer.cursor, CommandPanel.CMD_ESCAPE, "메뉴 커서는 다섯 줄을 감는다(3 에서 ↑4 → 4)")


# ---- 층·자리 ----

## M-V4(LIST_H 356): 세 크기에서 명령 목록 170,108 → 493,534(카드 위), 줄 y 114/184/254/324/394, 「뒤로」 464~528, 어느 줄·「뒤로」도
## 방향키 단추와 겹치지 않는다. 아이템 목록은 「스킬」 줄 위 ~ 카드 위 − 8(x 470, 폭 410), 720 높이에서 다섯 줄이 보인다.
## 누를 것은 64 이상·화면 안, 노랑은 단계마다 하나.
func test_panel_box_rows_and_layers_at_three_sizes() -> void:
	var all := {MEDICA: 3, AMRITA: 1, NECTAR: 1, THERIACA_A: 1, THERIACA_B: 1, BEACON: 1}
	for px in SIZES:
		await _open(_calm(all), px)
		var size: Vector2 = tree.root.get_visible_rect().size
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var p := layer.panel
		var cards_top := _rect(layer.party_cards.cards[0]).position.y
		check_eq(_rect(p), Rect2(170, 108, 323, 426), tag + ": 명령 목록 170,108 → 493,534")
		check(_rect(p).end.y <= cards_top, tag + ": 목록은 카드 위")
		check_eq(p.command_buttons.map(func(b: ListRow) -> float: return _rect(b).position.y), [114.0, 184.0, 254.0, 324.0, 394.0], tag + ": 줄 y")
		check_eq([_rect(p.back_button).position.y, _rect(p.back_button).end.y], [464.0, 528.0], tag + ": 「뒤로」 464~528")
		var pads: Array = ["up", "down", "left", "right"].map(func(k: String) -> Rect2: return _rect(layer.dir_pad.button(k)))
		for b in p.command_buttons + [p.back_button]:
			for r in pads:
				check(not _rect(b).intersects(r), "%s: %s %s 가 방향키 %s 와 겹치지 않는다" % [tag, b.name, str(_rect(b)), str(r)])
		for step in ["menu", "items", "target"]:
			match step:
				"items":
					await _step("command", CommandPanel.CMD_ITEM)
				"target":
					await _step("item", MEDICA)
			var t := "%s %s" % [tag, step]
			check_eq(layer.sub, step, t + ": 준비")
			if step == "items":
				var sp := _rect(p.skill_panel)
				check_eq([sp.position.x, sp.size.x, sp.position.y], [470.0, 410.0, _rect(p.command_buttons[1]).position.y], t + ": 판 x 470·폭 410·위 = 「스킬」 줄 위")
				check(sp.end.y <= cards_top - 8.0 + 0.5, t + ": 판 아래 ≤ 카드 위 − 8")
				check_eq(p.item_rows.filter(func(b: ListRow) -> bool: return b.visible).size(), 6, t + ": 아이템 줄 여섯")
				var shown := p.item_rows.filter(func(b: ListRow) -> bool: return b.visible and p.skill_list.shows(Rect2(b.position, b.size))).size()
				if size.y == 720.0:
					check_eq(shown, 5, t + ": 720 높이에서 다섯 줄이 다 보인다")
				else:
					check(shown >= 5, t + ": 다섯 줄 이상 보인다(%d)" % shown)
				for c in layer.party_cards.cards:
					check(not sp.intersects(_rect(c)), t + ": 아이템 판은 카드 위")
			var bs := layer.visible_buttons()
			check(not bs.is_empty(), t + ": 누를 것이 있다")
			var screen := Rect2(Vector2.ZERO, size)
			for b in bs:
				check((b as Control).size.x >= 64.0 and (b as Control).size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [t, b.name, str((b as Control).size)])
				check(screen.encloses(_rect(b).grow(-0.5)), "%s: %s 가 화면 안" % [t, b.name])
			check(_yellow_rows().size() <= 1, "%s: 노랑 채움 줄 %s" % [t, str(_yellow_rows())])
			if step != "target":
				check_eq(_yellow_rows().size(), 1, t + ": 커서 줄 하나가 노랑")


# ---- 보이는 남은 수 = 규칙의 예약 ----

## M-V1(예약을 세지 않음)·M-V3(_back 이 명령을 남김)·M-V5(뒤로가 아이템 예약을 풀지 않음)·M-V8(예약만으로 「아이템」 줄을 흐림): 메디카 2개, 대원 1·2 가 메디카 → 대원 3 의 줄은
## 0 「남은 수 없음」(누르면 이유만). 화면 명령을 제출하면 규칙이 받는다. 대원 2 로 돌아가면(그 명령을 버린다) 대원 3 은 다시 1.
func test_shown_count_follows_reservations_and_agrees_with_rules() -> void:
	await _open(_calm({MEDICA: 2}))
	await _use(MEDICA, 0)
	check_eq([layer.commands[0], layer.member], [{"kind": "item", "item": MEDICA, "target": 0}, 1], "대원 1: 메디카 → 자기")
	await _step("command", CommandPanel.CMD_ITEM)
	check_eq(_item_row(MEDICA).right, "1", "대원 2: 남은 수 1(대원 1 의 예약을 뺀다)")
	await _step("back")
	await _use(MEDICA, 1)
	check_eq(layer.member, 2, "대원 2: 메디카")
	check_eq(layer.item_shown_count(MEDICA), 0, "대원 3: 보이는 남은 수 0")
	await kit.frames(1)
	check(not layer.panel.command_buttons[CommandPanel.CMD_ITEM].dimmed and layer.panel.command_buttons[CommandPanel.CMD_ITEM].drawn.get("state") != "cmd:disabled",
		"예약으로만 막히면 「아이템」 줄은 흐리지 않는다(목록에서 이유를 보인다)")
	await _step("command", CommandPanel.CMD_ITEM)
	var r := _item_row(MEDICA)
	check(r != null and r.dimmed and r.right == "0" and r.note == "남은 수 없음", "대원 3: 메디카 줄 흐림 「남은 수 없음」 %s" % str([r.dimmed, r.right, r.note]))
	check_eq(layer.item_reason(MEDICA), "no_item", "규칙 이유 no_item")
	var n := layer.accepted_inputs
	await _step("item", MEDICA)
	check_eq([layer.sub, layer.commands[2], layer.banner_lines()[1]], ["items", null, "남은 수 없음"], "누르면 이유만(대상 단계 없음)")
	check_eq(layer.accepted_inputs, n + 1, "이유 알림은 받아들인 입력")
	await _step("back")
	# 대원 3·4·5 방어 → 확인 단계: 화면 명령을 규칙이 받는다.
	for i in 3:
		await _step("command", 2)
	check_eq(layer.sub, "confirm", "준비: 모두 정함")
	check_eq(BattleRules.check_commands(layer.state, layer.commands), {}, "화면 명령 = 규칙이 받는 명령")
	# 뒤로: 대원 5·4·3 의 방어를 버리고, 대원 2 로(그 메디카 명령·예약을 버린다).
	for i in 4:
		await _step("back")
	check_eq([layer.member, layer.commands[1], layer.commands[2]], [1, null, null], "대원 2 로 돌아옴: 그 명령은 비었다")
	check_eq(layer.item_shown_count(MEDICA), 1, "대원 2 자리에서 남은 수 1(대원 1 의 예약만)")
	await _step("command", 2)
	check_eq(layer.member, 2, "대원 2 방어 → 대원 3")
	await _step("command", CommandPanel.CMD_ITEM)
	r = _item_row(MEDICA)
	check(r != null and not r.dimmed and r.right == "1", "대원 3: 예약이 풀려 메디카 1(고를 수 있다) %s" % str([r.dimmed, r.right]))
	check_eq(layer.item_reason(MEDICA), "", "규칙도 받는다")


## M-V6(자기 예약을 「다른 대원」으로 셈)·M-V1: 화면의 보이는 남은 수와 흐림이 규칙 item_block_reason 과 늘 같은지, 명령 배열을
## 여러 모양으로(자기 칸에 이미 그 소모품이 있는 모양 포함) 직접 맞춰 본다. 규칙은 자기 칸을 세지 않는다.
func test_shown_count_matches_the_rules_for_every_command_shape() -> void:
	await _open(_calm({MEDICA: 1, AMRITA: 2}))
	var mk := func(id: String) -> Dictionary: return {"kind": "item", "item": id, "target": 0}
	var shapes := [
		[null, null, null, null, null], [mk.call(MEDICA), null, null, null, null], [null, mk.call(MEDICA), null, null, null],
		[mk.call(AMRITA), mk.call(AMRITA), null, null, null], [mk.call(AMRITA), null, mk.call(MEDICA), null, null],
		[{"kind": "guard"}, mk.call(AMRITA), mk.call(AMRITA), mk.call(MEDICA), null]]
	for shape in shapes:
		for m in 5:
			layer.commands = (shape as Array).duplicate(true)
			layer.member = m
			for id in [MEDICA, AMRITA]:
				var owned := int(layer.state.consumables[id])
				var others := 0
				for i in 5:
					if i != m and typeof(shape[i]) == TYPE_DICTIONARY and shape[i].get("item") == id:
						others += 1
				var tag := "%s 대원 %d %s" % [str(shape.map(func(c): return "" if c == null else str(c.get("item", c["kind"])))), m, id]
				check_eq(layer.item_shown_count(id), maxi(0, owned - others), tag + ": 보이는 수 = 가진 수 − 다른 대원 예약")
				var rule := BattleRules.item_block_reason(layer.state, m, id, layer.commands)
				check_eq(layer.item_shown_count(id) >= 1, rule != "no_item", tag + ": 화면이 고를 수 있다 ⇔ 규칙이 no_item 이 아니다")
				check_eq(layer.item_reason(id), rule, tag + ": 흐림 이유 = 규칙")
	layer.commands = [null, null, null, null, null]
	layer.member = 0


# ---- 대상·카드·실행 ----

## 대상 고르기(대리 스킬 대상 = 살아 있는 아군), 「아이템」 줄은 고른 모양, 띠 「대상을 고른다 · 메디카」와 설명, 뒤로 = 아이템 목록(커서 그 줄),
## 카드에 「메디카」. 실행 → 로그 「홀로나이트의 메디카!」「메디카 남은 수 1」, 다음 턴 보이는 수 = 상태 수 = 처음 − item_used.
## 실행 전에 모든 대원을 뒤로 넘기면 아무것도 줄지 않는다.
func test_target_card_label_log_and_counts_after_the_turn() -> void:
	await _open(_calm({MEDICA: 2, AMRITA: 1}))
	layer.state.battle.party[1].hp -= 10
	await _step("command", CommandPanel.CMD_ITEM)
	check_eq(layer.banner_lines().slice(0, 2), ["메디카", texts.t("use.medica.desc")], "아이템 목록: 띠 = 커서 줄 이름·설명")
	await _step("cursor", 1)
	check_eq(layer.banner_lines()[0], texts.t(AMRITA), "커서를 옮기면 그 설명")
	await _step("cursor", -1)
	await _step("item", MEDICA)
	check_eq([layer.sub, layer.target_side, layer.target_slots], ["target", BattleUnit.PARTY, BattleRules.item_targets(layer.state, 0, MEDICA)], "대상 = 대리 스킬의 아군")
	check_eq(layer.banner_lines().slice(0, 2), [texts.t("battle.ui.choose_target", {"skill": "메디카"}), texts.t("use.medica.desc")], "대상 띠")
	check(layer.panel.command_buttons[CommandPanel.CMD_ITEM].chosen, "「아이템」 줄은 고른 모양")
	await _step("back")
	check_eq([layer.sub, layer.cursor], ["items", 0], "대상에서 뒤로 → 아이템 목록, 커서 메디카")
	await _step("item", MEDICA)
	await kit.tap(kit.center_of(layer.party_cards.card(1)))
	check_eq(layer.commands[0], {"kind": "item", "item": MEDICA, "target": 1}, "카드 누르기 → 명령")
	check_eq(layer.party_cards.card(0).command_text, "메디카", "카드에 아이템 이름")
	# 모두 뒤로 넘겼다가(예약을 모두 버림) 다시: 실행 전에는 아무것도 줄지 않는다.
	await _use(AMRITA, 1)
	for i in 3:
		await _step("command", 2)
	for i in 5:
		await _step("back")
	check_eq([layer.member, layer.commands], [0, [null, null, null, null, null]], "모든 대원을 뒤로 넘김")
	check_eq(layer.state.consumables, {MEDICA: 2, AMRITA: 1}, "실행 전: 그대로")
	await _use(MEDICA, 1)
	for i in 4:
		await _step("command", 2)
	var before: Dictionary = layer.state.consumables.duplicate()
	await _step("execute")
	await kit.frames(2)
	var used := layer.last_events.filter(func(e: Dictionary) -> bool: return e["type"] == "item_used")
	check_eq(used.size(), 1, "item_used 하나(적은 아무것도 하지 않는다)")
	check_eq(layer.state.consumables, {MEDICA: int(before[MEDICA]) - used.size(), AMRITA: 1}, "줄어든 수 = item_used 수")
	check(layer.log_view.lines.has("홀로나이트의 메디카!") and layer.log_view.lines.has("메디카 남은 수 1"), "로그 %s" % str(layer.log_view.lines.slice(0, 6)))
	check_eq(saves, 1, "제출 저장 하나")
	check_eq([layer.phase, layer.member], ["command", 0], "다음 턴")
	await _step("command", CommandPanel.CMD_ITEM)
	check_eq([_item_row(MEDICA).right, _item_row(AMRITA).right], [str(layer.state.consumables[MEDICA]), "1"], "다음 턴 보이는 수 = 상태 수")


# ---- 저장 → 다시 읽기 ----

## 명령 단계의 저장·다시 읽기(실제 저장 파일): 대원 1 이 메디카를 고른 채 화면을 다시 열면 전투는 같은 상태(소모품 그대로)이고 반쯤 만든
## 명령은 없다(예약은 저장하지 않는다). 고르기는 저장하지 않는다.
func test_reload_in_the_command_phase_keeps_counts_and_drops_reservations() -> void:
	timeout_sec = 120.0
	await _window(SIZES[0])
	var s := await kit.open("native", 7, "debug=1")
	s.state.consumables = {MEDICA: 2}
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for i in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
		if s.modal.kind == "stairs":
			await kit.press_key(KEY_ESCAPE)
	check(s.battle_layer.is_open() and s.battle_layer.phase == "command", "준비: 전투 명령 단계")
	var gen := s.state.generation
	check_eq(kit.auto_generation(), gen, "전투 시작 자동 저장 = 지금 세대")
	var bl := s.battle_layer
	bl.handle("command", CommandPanel.CMD_ITEM)
	await kit.frames(1)
	bl.handle("item", MEDICA)
	await kit.frames(1)
	bl.handle("target", {"side": BattleUnit.PARTY, "slot": 0})
	await kit.frames(1)
	check_eq([bl.commands[0], bl.member, bl.item_shown_count(MEDICA)], [{"kind": "item", "item": MEDICA, "target": 0}, 1, 1], "준비: 대원 1 메디카, 대원 2 에게 1")
	check_eq([kit.auto_generation(), s.state.generation, s.state.consumables], [gen, gen, {MEDICA: 2}], "고르기는 저장하지 않고 소모품도 그대로")
	var h := SaveCodec.state_hash(s.state)
	var l := s.store.load_slot(SaveStore.AUTO)
	check(l.ok() and SaveCodec.state_hash(l.result.state) == h and l.result.state.consumables == {MEDICA: 2}, "자동 저장 = 지금 상태(소모품 2)")
	var s2 := await kit.reopen(func(sc: DungeonScreen) -> void: sc.url_query = "debug=1")
	await kit.frames(2)
	var b2 := s2.battle_layer
	check(b2.is_open() and b2.phase == "command", "다시 읽기: 전투 명령 단계")
	check_eq([SaveCodec.state_hash(s2.state), s2.state.consumables], [h, {MEDICA: 2}], "같은 상태·소모품 2")
	check_eq([b2.member, b2.sub, b2.commands], [0, "menu", [null, null, null, null, null]], "반쯤 만든 명령 없음(첫 대원 메뉴)")
	check_eq(b2.item_shown_count(MEDICA), 2, "예약이 없어 첫 대원에게 2")
	b2.handle("command", CommandPanel.CMD_ITEM)
	await kit.frames(2)
	var row: ListRow = b2.panel.item_rows[0]
	check(row.visible and row.right == "2" and not row.dimmed, "아이템 줄 메디카 2")


# ---- 그린 모양 ----

## M-V7(「아이템」 줄이 흐려지지 않음): 그린 색으로 본다(ListRow.drawn). 커서 줄 = skill:selected(옅은 노랑), 흐린 비콘 줄 = skill:disabled + 이유 글자색,
## 대상 없는 넥타 줄도 흐림 「대상 없음」, 남색 상자. 띠 둘째 줄 = 흐린 줄의 이유. 쓸 것이 없으면 「아이템」 줄이 cmd:disabled 로 그려지고 이유 「쓸 아이템이 없다」.
func test_drawn_look_of_rows_and_the_item_command() -> void:
	await _open(_calm({MEDICA: 1, NECTAR: 1, BEACON: 1}))
	await _step("command", CommandPanel.CMD_ITEM)
	await kit.frames(1)
	var med := _item_row(MEDICA)
	var nec := _item_row(NECTAR)
	var bea := _item_row(BEACON)
	check_eq(layer.panel.item_rows.slice(0, 3).map(func(b: ListRow) -> String: return str(b.name)), ["Item_0", "Item_1", "Item_2"], "줄 이름 Item_k")
	check_eq([med.drawn.get("state"), _paint(med)], ["skill:selected", _look("skill:selected")], "커서 줄: 옅은 노랑으로 그렸다")
	check_eq(med.drawn.get("box"), UiTheme.SKILL_TP_BOX, "오른쪽 남색 상자")
	check_eq([bea.drawn.get("state"), _paint(bea), bea.drawn.get("note"), bea.note], ["skill:disabled", _look("skill:disabled"), UiTheme.look("skill:disabled")["reason"], "전투에서는 쓸 수 없다"],
		"비콘: 흐리게 그렸고 이유 「전투에서는 쓸 수 없다」")
	check_eq([nec.drawn.get("state"), nec.note], ["skill:disabled", "대상 없음"], "넥타(쓰러진 대원 없음): 흐림 「대상 없음」")
	check(_paint(bea) != _paint(med) and _paint(bea)[0] != UiTheme.look("skill:normal")["top"], "흐린 줄은 커서 줄·보통 줄과 다르게 그렸다")
	await _step("cursor", 2)
	check_eq(layer.banner_lines().slice(0, 2), ["아리아드네 비콘", "전투에서는 쓸 수 없다"], "띠: 흐린 줄은 이유")
	await kit.frames(1)
	check_eq(bea.drawn.get("state"), "skill:disabled_selected", "흐린 줄 위 커서")
	check_eq(_yellow_rows(), [], "흐린 커서는 노랑 채움이 아니다")
	# 쓸 것이 없으면 「아이템」 줄이 흐리다.
	await _open(_calm({BEACON: 1}))
	await kit.frames(1)
	var cmd: ListRow = layer.panel.command_buttons[CommandPanel.CMD_ITEM]
	check_eq([cmd.drawn.get("state"), _paint(cmd), cmd.note], ["cmd:disabled", _look("cmd:disabled"), "쓸 아이템이 없다"], "「아이템」 줄: 흐리게 그렸고 이유")
	check_eq(_paint(layer.panel.command_buttons[0]), _look("cmd:selected"), "커서 줄(공격)은 노랑")
	await kit.press_key(KEY_4)
	check_eq([layer.sub, layer.banner_lines()[1], layer.banner_lines()[2]], ["menu", "쓸 아이템이 없다", true], "키 4: 이유만(한 줄 안내)")
	await _open(_calm({}))
	await kit.frames(1)
	check_eq(layer.panel.command_buttons[CommandPanel.CMD_ITEM].drawn.get("state"), "cmd:disabled", "소모품이 없어도 흐림")
