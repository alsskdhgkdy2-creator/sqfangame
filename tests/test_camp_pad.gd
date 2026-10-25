## 캠프 가상 키패드 시험(P3, 사용자 결정 2026-10-25, 07 §9.7): 전투와 같은 부품(VirtualPad)을 캠프 화면마다 정한 자리에 둔다.
## 배치 표(1280×720·1728×720, 앵커): 방향 십자 왼쪽 아래 (8, 511)(상태만 (456, 511)), 「취소」「선택」 가로 (W − 247, 427)
## (스킬은 설명 띠 안 「되돌리기」 왼쪽 (W − 567, 632), 조정자 결정), 장비·소지품 세로 (W − 118, 548), 기록 세로 (W − 118, 420). 누를 것과 겹치지 않고 64 이상.
## 트리 순서: 확인 창 층 뒤(창이 떠 있어도 누를 수 있다). 키패드 = 키(같은 키 표 key_action), 흐린 단추는 아무 일 없음,
## 문맥이 바뀌면·바깥 창(층 3)이 뜨면 눌림을 버린다. 저장은 장면 시험 임시 폴더에만(메뉴만 띄우는 시험은 저장 갈고리를 센다).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
const BASE := Vector2(1280, 720)
const FINGER := 3
const DUELIST_A := 1
const ION_SABER := "equip.ion_saber"
const PAD_NAMES := ["up", "down", "left", "right", "ok", "back"]
## 명령 줄 번호(07 §9.8 ②, PartyMenu.CAMP_KEYS 차례: 1 소지품 · 2 상태 · 3 장비 · 4 스킬 · 5 기록). 숫자 키는 줄 번호 + 1.
const ITEMS := 0
const STATUS := 1
const EQUIP := 2
const SKILLS := 3
const RECORDS := 4
## 화면 → 준비 입력(캠프 뿌리에서).
const SCREENS := {
	"root": [],
	"pick": [["camp", STATUS]],
	"status": [["camp", STATUS], ["member", 1]],
	"status_split": [["camp", STATUS], ["member", 1], ["split"]],
	"skills": [["camp", SKILLS], ["member", 1]],
	"skills_commit": [["camp", SKILLS], ["member", 1], ["plus"], ["commit"]],
	"equip": [["camp", EQUIP], ["member", 1]],
	"equip_list": [["camp", EQUIP], ["member", 1], ["confirm"]],
	"items": [["camp", ITEMS]],
	"items_supply": [["camp", ITEMS], ["supply_toggle"]],
	"records": [["camp", RECORDS]],
	"records_new_game": [["camp", RECORDS], ["record_new_game"]],
}

var kit: Kit
var host: Control
var texts: TextDb
var host_saves := 0
var hook_log: Array = []
var _defs: GameDefs
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


# ---- 준비 ----

func _open_screen() -> DungeonScreen:
	timeout_sec = 120.0
	kit = Kit.new(tree)
	var s := await kit.open("native", 7, "debug=1")
	GrowthRules.grant_exp(s.state, DUELIST_A, s.state.defs.battle.growth.cum(3))
	return s


func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 캠프를 새로 열고(뿌리) 화면 name 까지 간다.
func _go(s: DungeonScreen, name: String) -> void:
	var pm := s.party_menu
	if pm.is_open():
		pm.close_menu()
		await kit.frames(1)
	await kit.press_key(KEY_P)
	for st in SCREENS[name]:
		await _step(pm, st[0], st[1] if (st as Array).size() > 1 else null)


func _step(pm: PartyMenu, kind: String, arg: Variant = null) -> bool:
	var ok := pm.handle(kind, arg)
	await kit.frames(1)
	return ok


## 미궁 화면 없이 메뉴만(host 1280×720): 듀얼리스트 A Lv3·남은 SP 2, 가방에 이온 세이버, 기록 갈고리는 부른 일만 적는다.
func _fresh(debug: bool = false) -> PartyMenu:
	timeout_sec = 120.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")
	if host != null:
		tree.root.remove_child(host)
		host.free()
	host_saves = 0
	hook_log = []
	host = Control.new()
	host.name = "PadHost"
	host.size = BASE
	tree.root.add_child(host)
	var pm := PartyMenu.new()
	host.add_child(pm)
	pm.build(texts)
	pm.debug = debug
	pm.save_hook = func() -> void: host_saves += 1
	pm.records = {
		"slots": func() -> Array: return [{"ok": false}, {"ok": false}, {"ok": false}],
		"save": func(id: String) -> void: hook_log.append("save:" + id),
		"load": func(id: String) -> void: hook_log.append("load:" + id),
		"export": func() -> void: hook_log.append("export"),
		"import": func() -> void: hook_log.append("import"),
		"automap": func() -> String: return "floor",
		"set_automap": func(m: String) -> void: hook_log.append("automap:" + m),
		"new_game": func() -> void: hook_log.append("new_game"),
	}
	if _defs == null:
		_defs = GameDefs.load_paths("res://data/floors/f1_test.json", "res://data/party/test_party.json", "res://data", texts).defs
	var defs := _defs
	var st := ExplorationRules.new_game(defs, 1, "floor")
	GrowthRules.grant_exp(st, DUELIST_A, defs.battle.growth.cum(3))
	GrowthRules.supply(st, ION_SABER, 1)
	pm.open(st)
	await kit.frames(2)
	return pm


static func _pad_button(pm: PartyMenu, k: String) -> TouchButton:
	return pm.dir_pad.button(k) if k in ["up", "down", "left", "right"] else pm.active_key_pad().button(k)


static func _all_pad_buttons(pm: PartyMenu) -> Array[TouchButton]:
	var out: Array[TouchButton] = []
	for k in PAD_NAMES:
		out.append(_pad_button(pm, k))
	return out


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


static func _name_of(c: Control) -> String:
	return "없음" if c == null else str(c.get_path())


## 메뉴가 가진 것 전부(입력 하나가 바꿀 수 있는 것): 쪽·화면·대원·커서·확인 창·초안·장비 목록·소지품·기록·내역, 안내, 규칙 상태 해시,
## 저장 갈고리 수, 기록 갈고리 기록, 받아들인 입력 수.
func _sig(pm: PartyMenu) -> Array:
	return [pm.is_open(), pm.page, pm.tab, pm.member, pm.camp_cursor, pm.pick_cmd, pm.pick_cursor, pm.dialog_kind, pm.dialog_pick,
		pm.skill_tab.cursor, pm.skill_tab.draft.duplicate(), pm.equip_tab.cursor, pm.equip_tab.list_open, pm.equip_tab.list_cursor,
		pm.items_tab.cursor, pm.items_tab.supply_open, pm.items_tab.list.scroll, pm.records_tab.cur_row, pm.records_tab.cur_col,
		pm.status_tab.split_view, pm.notice, SaveCodec.state_hash(pm.state), host_saves, hook_log.duplicate(), pm.accepted_inputs]


## 논리 좌표 p 를 손가락으로 누를 때 처음 받는 컨트롤(test_camp 와 같은 방법).
func _receiver_at(p: Vector2) -> Control:
	var got: Array[Control] = []
	var hooks: Array = []
	for n in tree.root.find_children("*", "Control", true, false):
		var c := n as Control
		var f := func(ev: InputEvent) -> void:
			if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed and got.is_empty():
				got.append(c)
		c.gui_input.connect(f)
		hooks.append([c, f])
	kit.touch(FINGER, tree.root.get_final_transform() * p, true)
	kit.touch(FINGER, Vector2(-500, -500), false)
	await kit.frames(1)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Control).gui_input.is_connected(h[1]):
			(h[0] as Control).gui_input.disconnect(h[1])
	return got[0] if not got.is_empty() else null


## 화면마다 기대 자리: [십자 Rect2, 선택·취소 Rect2, 세로인지].
static func _expected(name: String, size: Vector2) -> Array:
	var screen := name.get_slice("_", 0)
	var dir := Rect2(Vector2(456 if screen == "status" else 8, 511), VirtualPad.dirs_size())
	match screen:
		"skills":
			return [dir, Rect2(Vector2(size.x - 567, 632), VirtualPad.keys_size()), false]
		"equip", "items":
			return [dir, Rect2(Vector2(size.x - 118, 548), VirtualPad.keys_size(true)), true]
		"records":
			return [dir, Rect2(Vector2(size.x - 118, 420), VirtualPad.keys_size(true)), true]
	return [dir, Rect2(Vector2(size.x - 247, 427), VirtualPad.keys_size()), false]


# ---- 배치 표 ----

func test_camp_pads_follow_the_table_on_every_screen_at_both_sizes() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	GrowthRules.supply(s.state, ION_SABER, 1)
	var kids := pm.get_children().map(func(c: Node) -> String: return c.name)
	check_eq(kids.slice(kids.size() - 4), ["Dialog", "DirPad", "KeyPad", "KeyPadStacked"],
		"트리 순서: 확인 창 층 뒤에 키패드(위에 그려지고 먼저 받는다): %s" % str(kids))
	for name in SCREENS:
		await _go(s, name)
		var first := {}
		for px in WINDOWS + [WINDOWS[0]]:
			var size: Vector2 = await _window(px)
			var tag := "%s %s(논리 %s)" % [name, str(px), str(size)]
			var want := _expected(name, size)
			check_eq(_rect(pm.dir_pad), want[0], tag + ": 방향 십자 자리")
			var kp := pm.active_key_pad()
			check_eq([kp == pm.key_pad_stacked, kp.is_visible_in_tree(), (pm.key_pad_stacked if kp == pm.key_pad else pm.key_pad).visible],
				[want[2], true, false], tag + ": 선택·취소 한 묶음만(가로/세로)")
			check_eq(_rect(kp), want[1], tag + ": 선택·취소 자리")
			check(pm.dir_pad.is_visible_in_tree(), tag + ": 십자가 보인다")
			var screen := Rect2(Vector2.ZERO, size)
			var st := pm.pad_state()
			var pads := _all_pad_buttons(pm)
			for b in pads:
				var r := pm.clipped_rect(b)
				check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s ≥ 64" % [tag, b.name, str(b.size)])
				check(screen.encloses(r), "%s: %s %s 가 화면 안" % [tag, b.name, str(r)])
			for k in PAD_NAMES:
				check_eq(_pad_button(pm, k).disabled, not st[k], "%s: %s 흐림 = 키 표" % [tag, k])
			# 누를 수 있는 것(줄·단추·노드·카드·확인 창 단추)과 겹치지 않는다. 확인 창이면 창 자체와도.
			var parts := {}
			for b in pm.visible_buttons():
				if not b.get_parent() is VirtualPad:
					parts[str(pm.get_path_to(b))] = pm.clipped_rect(b)
			if not pm.dialog_kind.is_empty():
				parts["dialog"] = pm.dialog_rect()
			check(not parts.is_empty(), tag + ": 누를 것이 있다")
			for b in pads:
				var r := pm.clipped_rect(b)
				for k in parts:
					check(not r.intersects(parts[k]), "%s: %s %s 와 %s %s 가 겹친다" % [tag, b.name, str(r), k, str(parts[k])])
			var snap := [_rect(pm.dir_pad), _rect(kp)]
			if first.has(px):
				check_eq(snap, first[px], tag + ": 크기를 바꿨다 돌아와도 같은 자리(앵커)")
			first[px] = snap
	pm.close_menu()
	await kit.frames(1)
	check(not pm.dir_pad.is_visible_in_tree() and not pm.key_pad.is_visible_in_tree(), "캠프를 닫으면 키패드도 없다")


## 보이는 위아래 = 누르는 위아래: 키패드 단추 자리를 실제로 누르면 그 단추가 받는다(확인 창이 떠 있어도). 단추 사이 빈 곳은 뒤가 받는다.
func test_camp_pad_taps_reach_the_visible_button() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	GrowthRules.supply(s.state, ION_SABER, 1)
	for px in WINDOWS:
		for name in ["root", "status", "skills", "skills_commit", "equip_list", "items_supply", "records_new_game"]:
			await _go(s, name)
			var size: Vector2 = await _window(px)
			var tag := "%s %s" % [name, str(size)]
			for b in _all_pad_buttons(pm):
				var got := await _receiver_at(_rect(b).get_center())
				check(got == b, "%s: %s 자리 → 그 단추, 실제 %s" % [tag, b.name, _name_of(got)])
			var hub := await _receiver_at(_rect(pm.dir_pad).get_center())
			var behind: Control = pm.dialog_layer if not pm.dialog_kind.is_empty() else pm
			check(hub == behind or (hub != null and behind.is_ancestor_of(hub) and not hub is TouchButton),
				"%s: 십자 가운데 → 뒤(%s), 실제 %s" % [tag, behind.name, _name_of(hub)])
	check_eq(s.state.party.members[DUELIST_A].skills.get("skill.blade_duelist.high_slash", 0), 1, "누르기 확인으로 상태가 바뀌지 않았다(배분 없음)")


## 스킬 설명 띠(조정자 결정 C): 실제 정의의 모든 직업 트리 스킬 × 레벨 0~최대(선행 미충족·충족 둘 다)의 설명 줄이 1280·1728 에서
## 칸 안에 잘리지 않고 들어간다(글자 폭 ≤ 칸 − 12, 칸 셋 이하, 줄 글 자리 끝 ≤ 키패드 「취소」 − 8). 키패드·「−」「+」·「되돌리기」「확정」은
## 서로 겹치지 않고 64 이상, 모두 설명 띠 안.
func test_every_real_skill_description_fits_its_column_at_both_sizes() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	await _go(s, "skills")
	var st := pm.skill_tab
	var font := st.desc.get_theme_default_font()
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := str(size)
		var desc := _rect(st.desc)
		var kp := _rect(pm.key_pad)
		var parts := {"취소": _rect(pm.key_pad.button("back")), "선택": _rect(pm.key_pad.button("ok")), "−": _rect(st.minus_button),
			"+": _rect(st.plus_button), "되돌리기": _rect(st.revert_button), "확정": _rect(st.commit_button)}
		var keys := parts.keys()
		for i in keys.size():
			var r: Rect2 = parts[keys[i]]
			check(r.size.x >= 64.0 and r.size.y >= 64.0 and desc.encloses(r), "%s: %s %s ≥ 64, 설명 띠 안" % [tag, keys[i], str(r)])
			for j in range(i + 1, keys.size()):
				check(not r.intersects(parts[keys[j]]), "%s: %s 와 %s 가 겹친다" % [tag, keys[i], keys[j]])
		check(desc.position.x + PartySkillTab.DESC_PAD + st.body_width() <= kp.position.x - 8.0 + 0.5, tag + ": 줄 글 자리는 키패드 왼쪽 − 8 까지")
		var seen := 0
		var widest := 0.0
		var most := 0
		for i in s.state.party.members.size():
			var m := s.state.party.members[i]
			var keep := m.skills.duplicate()
			var tree := s.state.defs.class_of(i).tree
			pm.member = i
			for j in tree.size():
				var sid := str(tree[j]["skill"])
				var sk := s.state.defs.battle.skill(sid)
				for met in [false, true]:
					for lvl in range(0, sk.max_level() + 1):
						m.skills = keep.duplicate()
						if met:
							for e in tree:
								m.skills[str(e["skill"])] = s.state.defs.battle.skill(str(e["skill"])).max_level()
						if lvl > 0:
							m.skills[sid] = lvl
						else:
							m.skills.erase(sid)
						st.cursor = j
						st.draft.clear()
						st._refresh_desc()
						var n := st.desc_lines.size()
						most = maxi(most, n)
						seen += 1
						check(n <= PartySkillTab.LINES_PER_COL * 3, "%s %s Lv%d: 줄 %d 은 세 칸 안" % [tag, sid, lvl, n])
						var cw := st.col_width()
						for k in n:
							var w := font.get_string_size(st.desc_lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
							widest = maxf(widest, w)
							if w > cw - 12.0:
								check(false, "%s %s Lv%d: 줄 「%s」 %.0f > 칸 %.0f − 12" % [tag, sid, lvl, st.desc_lines[k], w, cw])
							check(st.desc_line_pos(k).x + cw <= PartySkillTab.DESC_PAD + st.body_width() + 0.5, "%s %s: 줄 %d 칸이 줄 글 자리 안" % [tag, sid, k])
			m.skills = keep
		check(seen > 100 and most >= 8, "%s: 스킬 × 레벨 %d 경우, 가장 많은 줄 %d, 가장 긴 줄 %.0f" % [tag, seen, most, widest])
	pm.member = 0


## 좁아진 왼쪽 목록(P3 검토 수정): 1280·1728 에서 소지품(디버그 보급 줄·대원 줄·가방·소재)과 장비(칸 넷, 모든 대원 × 칸의 열린 목록)의
## 줄마다 이름·개수·바뀌는 값·이유 글자가 잘리지 않고(PartyButton.clipped_parts: 그리기와 같은 폭), 읽기만 하는 줄이 제 단추 밑에 깔리지 않는다.
## 단추는 64 이상. 다음에 목록이 좁아져도 이 시험이 잡는다.
func test_narrow_lists_show_every_row_text_unclipped_at_both_sizes() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	for id in s.state.defs.battle.equipment_ids:
		GrowthRules.supply(s.state, id, 1)
	s.state.materials["item.neon_rat_tail"] = 12
	GrowthRules.grant_exp(s.state, 0, 100000)  # 경험치 자리가 긴 대원도
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := str(size)
		# 소지품: 보급 줄을 연다.
		await _go(s, "items_supply")
		var it := pm.items_tab
		var lines := it.rows.filter(func(r: PartyButton) -> bool: return r.visible)
		var buttons: Array = (it.plus_buttons + it.exp_buttons + it.next_buttons).filter(func(b: PartyButton) -> bool: return b.visible)
		check(lines.size() >= 10 and buttons.size() >= 5 * 2, "%s 소지품: 줄 %d·단추 %d 를 본다" % [tag, lines.size(), buttons.size()])
		check(it.supply_button.clipped_parts().is_empty() and it.supply_button.size == Vector2(240, 64), "%s 소지품: 알약 글자가 잘리지 않는다" % tag)
		var w := it.list.size.x
		for r in lines + buttons:
			var b := r as PartyButton
			check(b.clipped_parts().is_empty(), "%s 소지품 %s 「%s」: 잘린 글자 %s(폭 %.0f)" % [tag, b.name, b.text, str(b.clipped_parts()), b.size.x])
			check(b.position.x >= -0.5 and b.position.x + b.size.x <= w + 0.5, "%s 소지품 %s 는 목록 폭 안" % [tag, b.name])
		for b in buttons:
			check((b as PartyButton).size.x >= 64.0 and (b as PartyButton).size.y >= 64.0, "%s 소지품 %s ≥ 64" % [tag, b.name])
			for r in lines:
				check(not Rect2(r.position, r.size).intersects(Rect2(b.position, b.size)), "%s 소지품: 줄 「%s」 이 단추 %s 밑에 깔린다" % [tag, r.text, b.name])
		for k in s.state.party.members.size():
			var row: ListButton = it.member_rows[k]
			check(row.text == pm.member_name(k) and row.right.begins_with("Lv") and row.right.contains(str(s.state.party.members[k].exp)),
				"%s 대원 줄 %d: 이름·Lv·경험치 %s" % [tag, k, [row.text, row.right]])
		# 장비: 대원마다 칸 넷, 칸마다 열린 목록.
		await _go(s, "equip")
		var et := pm.equip_tab
		for i in s.state.party.members.size():
			await _step(pm, "member", i)
			for b in et.slot_rows:
				check(b.clipped_parts().is_empty(), "%s 장비 %d %s 「%s」: 잘린 글자 %s" % [tag, i, b.name, b.text, str(b.clipped_parts())])
			for slot in et.slot_rows.size():
				await _step(pm, "slot", slot)
				check(et.list_open, "%s 장비 %d 칸 %d: 목록 열림" % [tag, i, slot])
				for j in et.row_items.size():
					var b := et.rows[j]
					check(b.clipped_parts().is_empty(), "%s 장비 %d 칸 %d 줄 「%s」: 잘린 글자 %s %s" % [tag, i, slot, b.text, str(b.clipped_parts()), [b.right, b.note]])
				await _step(pm, "list_close")


## 대원 경험치 단추는 이름 줄 아래 따로 있다(P3 검토 수정 1): 키보드·키패드로 커서를 옮길 때 고른 단추와 그 대원의 이름 줄(이름·Lv·경험치)이
## 함께 목록 보이는 곳 안에 있어야 어느 대원에게 주는지 보인다(검토 2차). 1280·1728 에서 끝까지 내려갔다가(키보드) 처음까지 올라온다(키패드·키보드 번갈아).
func test_supply_cursor_keeps_the_member_label_in_view_both_ways() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		await _go(s, "items_supply")
		var it := pm.items_tab
		var acts := it.stops()
		var last := acts.size() - 1
		check(last >= 1 + 5 * 2, "%s: 누를 단추 %d" % [str(size), acts.size()])
		var seen_members := {}
		var steps := 0
		for dir in [1, -1]:
			var guard := 0
			while (it.cursor < last if dir > 0 else it.cursor > 0) and guard < 200:
				guard += 1
				var at := it.cursor
				if dir > 0:
					await kit.press_key(KEY_DOWN)
				elif guard % 2 == 0:
					await kit.tap(kit.center_of(pm.dir_pad.button("up")), FINGER)
				else:
					await kit.press_key(KEY_UP)
				if it.cursor == at:
					continue  # ↑ 가 먼저 목록만 올린 걸음(커서 그대로)
				steps += 1
				var b: PartyButton = it.stops()[it.cursor]
				var tag := "%s %s 커서 %d %s" % [str(size), "↓" if dir > 0 else "↑", it.cursor, b.name]
				check(b.selected, tag + ": 고른 모양")
				if b == it.supply_button:
					continue  # 알약은 목록 밖
				check(it.list.shows(Rect2(b.position, b.size)), "%s: 단추 %s 가 보이는 곳 안(내림 %s)" % [tag, str(Rect2(b.position, b.size)), it.list.scroll])
				var k := it.exp_buttons.find(b)
				if k < 0:
					k = it.next_buttons.find(b)
				if k >= 0:
					var label: ListButton = it.member_rows[k]
					check(it.list.shows(Rect2(label.position, label.size)), "%s: 대원 %d 이름 줄 %s 이 보이는 곳 안(내림 %s, 높이 %s)" % [tag, k, str(Rect2(label.position, label.size)), it.list.scroll, it.list.size.y])
					check(label.position.y + label.size.y <= b.position.y, tag + ": 이름 줄은 단추 위")
					seen_members[[dir, k]] = true
			check_eq(it.cursor, last if dir > 0 else 0, "%s: %s 끝까지" % [str(size), "↓" if dir > 0 else "↑"])
		check_eq(seen_members.size(), 10, "%s: 대원 다섯 × 오르내림을 다 봤다" % str(size))
		check(steps >= 2 * last, "%s: 걸음 %d" % [str(size), steps])


# ---- 키패드 = 키 ----

## 경우: [이름, 디버그, 준비 입력, 키패드 단추, 켜짐, 가장자리(켜진 채 아무 일 없음)].
## 흐림 규칙(06 §9.10·07 §9.7, 조정자 결정 2026-10-25): 흐림은 「그 화면·창에서 그 키가 맡은 일이 없음」이다. 목록·트리·카드 줄의
## 끝에서 더 갈 곳이 없는 방향과 넘치지 않는 목록의 내리기는 켜진 채 아무 일도 하지 않는다(키와 같다). 가장자리 경우는 그것을 단언한다.
func _parity(cases: Array) -> void:
	for c in cases:
		var tag: String = c[0]
		var k: String = c[3]
		var pm := await _fresh(c[1])
		for st in c[2]:
			await _step(pm, st[0], st[1] if (st as Array).size() > 1 else null)
		var pre := _sig(pm)
		var on: bool = pm.pad_state()[k]
		check_eq(on, c[4], tag + ": 켜짐/흐림")
		var b := _pad_button(pm, k)
		check(b.is_visible_in_tree() and b.disabled == not on, tag + ": 단추가 보이고 흐림이 상태와 같다")
		await kit.tap(kit.center_of(b), FINGER)
		var by_pad := _sig(pm)
		pm = await _fresh(c[1])
		for st in c[2]:
			await _step(pm, st[0], st[1] if (st as Array).size() > 1 else null)
		check_eq(_sig(pm), pre, tag + ": 준비가 같다")
		await kit.press_key(PartyMenu.PAD_KEYS[k])
		var by_key := _sig(pm)
		check_eq(by_pad, by_key, tag + ": 키패드 = 키")
		if not on:
			check_eq(by_pad, pre, tag + ": 흐린 단추·키는 아무것도 바꾸지 않는다(받은 입력 수 포함)")
		elif c[5]:
			check_eq(by_pad, pre, tag + ": 가장자리: 켜진 채 아무것도 바꾸지 않는다(키와 같음)")
		else:
			check(int(by_pad[-1]) == int(pre[-1]) + 1, "%s: 켜진 단추는 입력 하나를 받는다 %s → %s" % [tag, pre[-1], by_pad[-1]])


func test_camp_pad_matches_keys_on_root_pick_and_status() -> void:
	var down := [["pick_move", Vector2i(0, 1)]]
	await _parity([
		["뿌리 ↑", false, [], "up", true, false], ["뿌리 ↓", false, [], "down", true, false],
		["뿌리 ←", false, [], "left", false, false], ["뿌리 →", false, [], "right", false, false],
		["뿌리 선택", false, [], "ok", true, false], ["뿌리 취소", false, [], "back", true, false],
		["고르기 ↑", false, [["camp", SKILLS]] + down, "up", true, false], ["고르기 ↓", false, [["camp", SKILLS]], "down", true, false],
		["고르기 ←", false, [["camp", SKILLS]], "left", true, false], ["고르기 →", false, [["camp", SKILLS]], "right", true, false],
		["고르기 선택", false, [["camp", SKILLS]], "ok", true, false], ["고르기 취소", false, [["camp", SKILLS]], "back", true, false],
		["고르기 윗줄 ↑(가장자리)", false, [["camp", SKILLS]], "up", true, true],
		["상태 ↑", false, [["camp", STATUS], ["member", 1]], "up", false, false], ["상태 ↓", false, [["camp", STATUS], ["member", 1]], "down", false, false],
		["상태 ←", false, [["camp", STATUS], ["member", 1]], "left", true, false], ["상태 →", false, [["camp", STATUS], ["member", 1]], "right", true, false],
		["상태 선택", false, [["camp", STATUS], ["member", 1]], "ok", true, false], ["상태 취소", false, [["camp", STATUS], ["member", 1]], "back", true, false],
	])


func test_camp_pad_matches_keys_on_skills_and_its_dialogs() -> void:
	var sk := [["camp", SKILLS], ["member", 1]]
	var dlg := sk + [["plus"], ["commit"]]
	await _parity([
		["스킬 ↑", false, sk + [["node_dir", Vector2i(0, 1)]], "up", true, false],
		["스킬 트리 맨 위 ↑(가장자리)", false, sk, "up", true, true], ["스킬 ↓", false, sk, "down", true, false],
		["스킬 ←", false, sk + [["node_dir", Vector2i(1, 0)]], "left", true, false], ["스킬 →", false, sk, "right", true, false],
		["스킬 선택(+)", false, sk, "ok", true, false], ["스킬 취소", false, sk, "back", true, false],
		["스킬 초안 뒤 취소(버리기 창)", false, sk + [["plus"]], "back", true, false],
		["확정 창 ↑", false, dlg, "up", false, false], ["확정 창 ↓", false, dlg, "down", false, false],
		["확정 창 ←", false, dlg + [["dialog_move", 1]], "left", true, false], ["확정 창 →", false, dlg, "right", true, false],
		["확정 창 선택(돌아가기)", false, dlg, "ok", true, false], ["확정 창 선택(확정)", false, dlg + [["dialog_move", 1]], "ok", true, false],
		["확정 창 취소", false, dlg, "back", true, false],
		["버리기 창 →", false, sk + [["plus"], ["back"]], "right", true, false],
		["버리기 창 선택(버리기)", false, sk + [["plus"], ["back"], ["dialog_move", 1]], "ok", true, false],
	])


func test_camp_pad_matches_keys_on_equip_and_items() -> void:
	var eq := [["camp", EQUIP], ["member", 1]]
	var lst := eq + [["confirm"]]
	var it := [["camp", ITEMS], ["supply_toggle"]]
	await _parity([
		["장비 ↑", false, eq + [["cursor", 1]], "up", true, false],
		["장비 첫 칸 ↑(가장자리)", false, eq, "up", true, true],
		["장비 목록 첫 줄 ↑(가장자리)", false, lst, "up", true, true], ["장비 ↓", false, eq, "down", true, false],
		["장비 ←", false, eq, "left", true, false], ["장비 →", false, eq, "right", true, false],
		["장비 선택(목록)", false, eq, "ok", true, false], ["장비 취소", false, eq, "back", true, false],
		["장비 목록 ↑", false, lst + [["cursor", 1]], "up", true, false], ["장비 목록 ↓", false, lst, "down", true, false],
		["장비 목록 ←", false, lst, "left", false, false], ["장비 목록 →", false, lst, "right", false, false],
		["장비 목록 선택(빼기)", false, lst, "ok", true, false], ["장비 목록 취소(닫기)", false, lst, "back", true, false],
		["소지품 ↑", true, it + [["cursor", 1]], "up", true, false], ["소지품 ↓", true, it, "down", true, false],
		["소지품 ←(대원 없음)", true, it, "left", false, false], ["소지품 →(대원 없음)", true, it, "right", false, false],
		["소지품 선택(보급 줄)", true, it, "ok", true, false], ["소지품 취소", true, it, "back", true, false],
		["소지품(디버그 아님) 선택", false, [["camp", ITEMS]], "ok", false, false],
		["소지품(디버그) 가방 줄 선택", true, [["camp", ITEMS]], "ok", false, false],
		["소지품(디버그) 가방 줄 ↑ → 알약", true, [["camp", ITEMS]], "up", true, false],
		["소지품(디버그) 알약 선택 → 보급 줄", true, [["camp", ITEMS], ["cursor", -1]], "ok", true, false],
		["소지품(디버그) 알약 ↑(가장자리)", true, [["camp", ITEMS], ["cursor", -1]], "up", true, true],
		["소지품(디버그 아님) ←", false, [["camp", ITEMS]], "left", false, false],
		["소지품(디버그 아님) 첫 줄 ↑(가장자리)", false, [["camp", ITEMS]], "up", true, true],
		["소지품(디버그 아님, 넘치지 않음) ↓(가장자리)", false, [["camp", ITEMS]], "down", true, true],
	])


func test_camp_pad_matches_keys_on_records_and_new_game() -> void:
	var rc := [["camp", RECORDS]]
	var ng := rc + [["record_new_game"]]
	await _parity([
		["기록 ↑", false, rc + [["cursor", 1]], "up", true, false], ["기록 ↓", false, rc, "down", true, false],
		["기록 ←", false, rc + [["cursor_x", 1]], "left", true, false],
		["기록 첫 칸 ←(가장자리)", false, rc, "left", true, true],
		["기록 첫 줄 ↑(가장자리)", false, rc, "up", true, true], ["기록 →", false, rc, "right", true, false],
		["기록 선택(저장)", false, rc, "ok", true, false], ["기록 취소", false, rc, "back", true, false],
		["기록 선택(흐린 불러오기)", false, rc + [["cursor_x", 1]], "ok", false, false],
		["새 게임 창 ↑", false, ng, "up", false, false], ["새 게임 창 ↓", false, ng, "down", false, false],
		["새 게임 창 ←", false, ng, "left", true, false], ["새 게임 창 →", false, ng, "right", true, false],
		["새 게임 창 선택", false, ng + [["dialog_move", 1]], "ok", true, false], ["새 게임 창 취소", false, ng, "back", true, false],
	])


## 숫자 키 차례(07 §9.8 ②): 키 표 하나(key_action)가 뿌리·고르기의 1~6(윗줄·키패드 숫자)을 명령 줄 0~5 로 보내고, 줄의 일은 새 차례
## (1 소지품 · 2 상태 · 3 장비 · 4 스킬 · 5 기록 · 6 닫기). 고르기 중 2·3·4 는 고르기 바꾸기(지금 명령이면 아무 일 없음), 1·5 는 바로 열기,
## 6 은 뒤로. 키패드 「선택」은 열 때 커서 0(소지품). 하위 화면의 숫자 키도 같은 차례다(1 소지품 … 5 기록).
func test_number_keys_follow_the_command_order() -> void:
	var pm := await _fresh()
	check_eq(PartyMenu.CAMP_KEYS, ["items", "status", "equip", "skills", "records", "close"], "명령 차례")
	for i in 6:
		check_eq([pm.key_action(KEY_1 + i), pm.key_action(KEY_KP_1 + i)], [["camp", i], ["camp", i]], "뿌리 %d → 명령 줄 %d" % [i + 1, i])
	# 뿌리: 키 → [쪽, 하위 화면 번호 또는 고르기 명령(0 상태·1 스킬·2 장비), 명령 커서]
	var root_want := {KEY_1: ["sub", 3, ITEMS], KEY_2: ["pick", 0, STATUS], KEY_3: ["pick", 2, EQUIP], KEY_4: ["pick", 1, SKILLS],
		KEY_5: ["sub", 4, RECORDS]}
	for k in root_want:
		pm = await _fresh()
		await kit.press_key(k)
		check_eq([pm.page, pm.tab if pm.page == "sub" else pm.pick_cmd, pm.camp_cursor], root_want[k], "뿌리 %s" % OS.get_keycode_string(k))
	pm = await _fresh()
	await kit.press_key(KEY_6)
	check(not pm.is_open(), "뿌리 6 → 닫기")
	pm = await _fresh()
	await kit.tap(kit.center_of(pm.key_pad.button("ok")), FINGER)
	check_eq([pm.page, pm.tab], ["sub", 3], "열자마자 키패드 「선택」 → 커서 0 = 소지품")
	# 상태 고르기 중
	var pick_want := {KEY_1: ["sub", 3, ITEMS], KEY_3: ["pick", 2, EQUIP], KEY_4: ["pick", 1, SKILLS], KEY_5: ["sub", 4, RECORDS],
		KEY_6: ["root", 0, STATUS]}
	for k in pick_want:
		pm = await _fresh()
		await _step(pm, "camp", STATUS)
		await kit.press_key(k)
		check_eq([pm.page, pm.tab if pm.page == "sub" else pm.pick_cmd, pm.camp_cursor], pick_want[k], "상태 고르기 중 %s" % OS.get_keycode_string(k))
	pm = await _fresh()
	await _step(pm, "camp", STATUS)
	var pre := _sig(pm)
	await kit.press_key(KEY_2)
	check_eq(_sig(pm), pre, "상태 고르기 중 2(지금 명령) → 아무 일 없음")
	# 하위 화면(C1 뒤 조정자 결정): 같은 숫자 = 같은 명령. 키 → 하위 화면 번호(0 상태·1 스킬·2 장비·3 소지품·4 기록).
	pm = await _fresh()
	await _step(pm, "camp", RECORDS)
	for i in 5:
		check_eq(pm.key_action(KEY_1 + i), ["tab", PartyMenu.camp_tab(i)], "하위 화면 %d → %s" % [i + 1, PartyMenu.CAMP_KEYS[i]])
	var sub_want := [[KEY_1, 3], [KEY_2, 0], [KEY_3, 2], [KEY_4, 1], [KEY_5, 4]]
	for w in sub_want:
		await kit.press_key(w[0])
		check_eq([pm.page, pm.tab], ["sub", w[1]], "하위 화면 %s → %s" % [OS.get_keycode_string(w[0]), PartyMenu.TAB_KEYS[w[1]]])
	await kit.press_key(KEY_6)
	check_eq([pm.page, pm.tab], ["sub", 4], "하위 화면 6 → 아무 일 없음")


## 새 키 뜻(사용자 결정): 상태·장비 칸·소지품의 ←→ = 앞·다음 대원(= Q/E, 물리 화살표도), 상태의 선택(Enter) = 「내역」(= V).
## 장비 목록이 열려 있으면 ←→ 는 아무 일 없음, 기록은 ←→ 가 줄 안 그대로. 키 6 은 줄이 없어도 닫기·뒤로.
func test_new_key_meanings_for_member_switch_and_split() -> void:
	var pm := await _fresh()
	await _step(pm, "camp", STATUS)
	await _step(pm, "member", 1)
	await kit.press_key(KEY_RIGHT)
	check_eq(pm.member, 2, "상태 → = 다음 대원")
	await kit.press_key(KEY_LEFT)
	await kit.press_key(KEY_LEFT)
	check_eq(pm.member, 0, "상태 ← 두 번 = 앞 대원 둘")
	await kit.press_key(KEY_LEFT)
	check_eq(pm.member, 4, "← 는 끝에서 돈다(Q 와 같다)")
	await kit.press_key(KEY_ENTER)
	check(pm.status_tab.split_view, "상태 Enter = 「내역」 켬")
	await kit.press_key(KEY_V)
	check(not pm.status_tab.split_view, "V 는 그대로 「내역」 끔")
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_RIGHT)
	check_eq([pm.tab, pm.member], [2, 0], "장비 칸 → = 다음 대원")
	await kit.press_key(KEY_ENTER)
	check(pm.equip_tab.list_open, "준비: 목록 열림")
	var n := pm.accepted_inputs
	await kit.press_key(KEY_RIGHT)
	await kit.press_key(KEY_LEFT)
	check_eq([pm.member, pm.equip_tab.list_open, pm.accepted_inputs], [0, true, n], "목록이 열려 있으면 ←→ 는 아무 일 없음")
	await kit.press_key(KEY_ESCAPE)
	check(not pm.equip_tab.list_open and pm.page == "sub", "Esc 한 번 = 목록만 닫음")
	await kit.press_key(KEY_1)
	n = pm.accepted_inputs
	for k in [KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E]:
		await kit.press_key(k)
	check_eq([pm.tab, pm.member, pm.accepted_inputs], [3, 0, n], "소지품 ←→·Q·E = 아무 일 없음(대원이 없다, E2-b)")
	await kit.press_key(KEY_5)
	await kit.press_key(KEY_RIGHT)
	check_eq([pm.tab, pm.member, pm.records_tab.cur_col], [4, 0, 1], "기록 → = 줄 안(대원 그대로)")
	await kit.press_key(KEY_ESCAPE)
	await kit.press_key(KEY_2)
	await kit.press_key(KEY_6)
	check_eq([pm.is_open(), pm.page], [true, "root"], "고르기 중 6 = 뒤로")
	await kit.press_key(KEY_6)
	check(not pm.is_open(), "뿌리 6 = 닫기")


# ---- 누르기 취소 ----

## 문맥이 바뀌면 눌린 키패드 단추를 버린다: 장비 칸에서 「선택」을 누른 채 Enter(목록 열림) → 뗌 → 줄이 골라지지 않는다.
## 스킬에서 「선택」(= 「+」)을 누른 채 F(확정 창) → 뗌 → 「+」도 창 단추도 아니다. 흐린 단추를 눌러도 아무 일 없다.
func test_camp_pad_press_is_cancelled_by_a_context_change() -> void:
	var pm := await _fresh()
	await _step(pm, "camp", EQUIP)
	await _step(pm, "member", 1)
	var ok := pm.active_key_pad().button("ok")
	var p := kit.center_of(ok)
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	check(ok.held, "준비: 「선택」 누르는 중")
	await kit.press_key(KEY_ENTER)
	check(pm.equip_tab.list_open and not ok.held, "Enter → 목록 열림, 눌림 버림")
	var pre := _sig(pm)
	kit.touch(FINGER, p, false)
	await kit.frames(3)
	check_eq(_sig(pm), pre, "뗄 때 목록 줄을 고르지 않는다(장착·저장 없음)")
	pm = await _fresh()
	await _step(pm, "camp", SKILLS)
	await _step(pm, "member", 1)
	await _step(pm, "plus")
	ok = pm.key_pad.button("ok")
	p = kit.center_of(ok)
	kit.touch(FINGER, p, true)
	await kit.frames(2)
	await kit.press_key(KEY_F)
	check(pm.dialog_kind == "commit" and not ok.held, "F → 확정 창, 눌림 버림")
	pre = _sig(pm)
	kit.touch(FINGER, p, false)
	await kit.frames(3)
	check_eq(_sig(pm), pre, "뗄 때 「+」도 창 「돌아가기」도 아니다")
	# 흐린 단추(확정 창 ↑)는 눌러도 아무것도 바꾸지 않는다.
	check(pm.dir_pad.button("up").disabled, "확정 창 ↑ 흐림")
	await kit.tap(kit.center_of(pm.dir_pad.button("up")), FINGER)
	check_eq(_sig(pm), pre, "흐린 ↑ 는 아무 일 없음")


## 바깥 창(층 3 알림)이 캠프 위에 뜨면 눌린 키패드를 버린다: 스킬 확정 창에서 「확정」을 고르고 「선택」을 누른 채 가져오기 오류 알림 →
## 알림이 덮은 채 떼도, 다른 손가락으로 알림을 닫은 뒤 떼도 배분하지 않는다. 알림 아래에서 키도 캠프에 닿지 않는다.
func test_held_camp_pad_does_nothing_after_an_external_alert() -> void:
	var s := await _open_screen()
	var pm := s.party_menu
	for under in [true, false]:
		await _go(s, "skills_commit")
		await _step(pm, "dialog_move", 1)
		check_eq([pm.dialog_kind, pm.dialog_pick], ["commit", 1], "준비: 확정 창, 「확정」 고름")
		var tag := "확정 창 「선택」 누른 채 알림 → %s" % ("알림이 덮은 채 뗌" if under else "다른 손가락으로 알림을 닫고 뗌")
		var ok := pm.key_pad.button("ok")
		var p := kit.center_of(ok)
		var skills: Dictionary = s.state.party.members[DUELIST_A].skills.duplicate()
		var sig := [kit.hash_now(), s.state.generation, s.autosave_count, pm.skill_tab.draft.duplicate(), pm.accepted_inputs]
		kit.touch(4, p, true)
		await kit.frames(2)
		check(ok.held, tag + ": 준비: 눌림")
		s._import_token += 1
		s._import_epoch = s._epoch
		s._on_import_result(s._import_token, "error", "")
		await kit.frames(2)
		check(s.modal.kind == "alert" and not ok.held, tag + ": 알림이 뜨면 키패드 눌림을 버린다")
		check(not pm.handle("dialog_ok"), tag + ": 알림이 떠 있으면 캠프 입구가 받지 않는다")
		for key in [KEY_ENTER, KEY_RIGHT]:
			kit.key(key, true)
			kit.key(key, false)
			await kit.frames(2)
			if s.modal.kind != "alert":
				break
		check_eq([pm.dialog_kind, pm.dialog_pick], ["commit", 1], tag + ": 알림 아래 키는 확정 창에 닿지 않는다")
		if not under and s.modal.kind == "alert":
			await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)), 7)
			check_eq(s.modal.kind, "", tag + ": 준비: 다른 손가락으로 알림 닫음")
		kit.touch(4, p, false)
		await kit.frames(3)
		check_eq(s.state.party.members[DUELIST_A].skills, skills, tag + ": 배분 없음")
		check_eq([kit.hash_now(), s.state.generation, s.autosave_count, pm.skill_tab.draft.duplicate(), pm.accepted_inputs], sig,
			tag + ": 상태·세대·자동 저장·초안·받은 입력 그대로")
		check_eq(pm.dialog_kind, "commit", tag + ": 확정 창 그대로")
		if s.modal.is_open():
			await kit.tap(kit.center_of(s.modal.find_child("AlertOk", true, false)), 7)
