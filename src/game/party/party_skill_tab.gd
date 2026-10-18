## 파티 메뉴 스킬 탭(07 §9.2, §4.6): 트리 영역(자르기, 넘치면 세로로 끌어 내림)·설명 칸·조작 줄.
## 「+」「−」는 화면의 초안(스킬 → 더한 레벨)만 바꾸고(판정은 GrowthRules.learn_block·unlearn_block), 「확정」은 확정 확인 창 →
## GrowthRules.allocate 한 번(목표 레벨 사전). 초안은 저장하지 않는다.
## 노드는 트리 영역 왼쪽 위 (8, 8)부터 열 피치 152·행 피치 112(1280×720 에서 첫 노드 (308, 88)). 트리 영역은 내용 영역 가운데,
## 설명 칸은 오른쪽에 붙는다(넓은 화면비에서도).
class_name PartySkillTab
extends Control

const NODE := Vector2(136, 88)
const PITCH := Vector2(152, 112)
const FIRST := Vector2(8, 8)
const TREE_SIZE := Vector2(600, 552)
const DESC_W := 364.0
const ROW_Y := 640.0
const STEP_BUTTON := Vector2(96, 64)
const REVERT_SIZE := Vector2(160, 64)
const COMMIT_SIZE := Vector2(200, 64)
## 퍼밀(‰)로 적힌 줄 필드: 화면은 %로 보인다.
const PERMILLE := ["accuracy", "chance", "hp_permille", "value"]
const PERCENT := ["wis_pct"]

var menu: PartyMenu
## 키보드 커서·고른 노드(트리 칸 번호).
var cursor := 0
## 초안: 스킬 ID → 초안으로 더한 레벨(1 이상만 둔다).
var draft := {}
var tree_area: PartyScroll
var nodes: Array[SkillNode] = []
var desc: Control
var minus_button: PartyButton
var plus_button: PartyButton
var revert_button: PartyButton
var commit_button: PartyButton
var _desc_title := Label.new()
var _desc_body := Label.new()
var _sp_label := Label.new()
var _note_label := Label.new()
var _class_id := ""


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	tree_area = PartyScroll.new()
	tree_area.name = "TreeArea"
	tree_area.content.draw.connect(_draw_lines)
	add_child(tree_area)
	desc = Control.new()
	desc.name = "SkillDesc"
	desc.mouse_filter = MOUSE_FILTER_IGNORE
	desc.draw.connect(func() -> void: _panel(desc))
	add_child(desc)
	_desc_title.add_theme_font_size_override("font_size", 22)
	_desc_title.position = Vector2(16, 12)
	_desc_title.clip_text = true
	desc.add_child(_desc_title)
	_desc_body.add_theme_font_size_override("font_size", 17)
	_desc_body.position = Vector2(16, 48)
	_desc_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_child(_desc_body)
	minus_button = _button("SkillMinus", "", STEP_BUTTON, "minus", desc)
	minus_button.icon = "zoom_out"  # 「−」「+」 기호(글꼴 부분 집합에 U+2212 가 없다)
	plus_button = _button("SkillPlus", "", STEP_BUTTON, "plus", desc)
	plus_button.icon = "zoom_in"
	revert_button = _button("SkillRevert", menu.texts.t("party.revert"), REVERT_SIZE, "revert", self)
	commit_button = _button("SkillCommit", menu.texts.t("party.commit"), COMMIT_SIZE, "commit", self)
	_sp_label.name = "SpLine"
	_sp_label.add_theme_font_size_override("font_size", 20)
	_sp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sp_label)
	_note_label.add_theme_font_size_override("font_size", 16)
	_note_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.55))
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_label.clip_text = true
	_note_label.text = menu.texts.t("party.commit_note")
	add_child(_note_label)


func _button(n: String, label: String, sz: Vector2, kind: String, parent: Node) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.text = label
	b.size = sz
	b.activated.connect(func() -> void: menu.handle(kind))
	parent.add_child(b)
	return b


func reset() -> void:
	cursor = 0
	draft.clear()
	tree_area.scroll_to(0.0)


func member_changed() -> void:
	cursor = 0
	draft.clear()
	tree_area.scroll_to(0.0)


func context() -> String:
	return ""


func has_draft() -> bool:
	return not draft.is_empty()


func clear_draft() -> void:
	draft.clear()


## 초안이 쓰는 SP.
func draft_sp() -> int:
	return GrowthRules.sp_used(draft)


func tree_rect() -> Rect2:
	return Rect2(tree_area.position, tree_area.size)


func desc_rect() -> Rect2:
	return Rect2(desc.position, desc.size)


func node_rect(i: int) -> Rect2:
	var p := _pos(i)
	return Rect2(FIRST + Vector2(p) * PITCH, NODE)


## 지금 고른 스킬 ID(트리가 비면 "").
func cursor_skill() -> String:
	var tree := _tree()
	return str(tree[cursor]["skill"]) if cursor < tree.size() else ""


func place(s: Vector2) -> void:
	var desc_x := s.x - 8 - DESC_W
	var free_left := PartyMenu.TAB_X
	var free_w := desc_x - 8 - free_left
	tree_area.position = Vector2(roundf(free_left + maxf(0.0, (free_w - TREE_SIZE.x) / 2.0)), PartyMenu.TOP)
	tree_area.size = TREE_SIZE
	desc.position = Vector2(desc_x, PartyMenu.TOP)
	desc.size = Vector2(DESC_W, TREE_SIZE.y)
	_desc_title.size = Vector2(DESC_W - 32, 30)
	_desc_body.size = Vector2(DESC_W - 32, TREE_SIZE.y - 48 - STEP_BUTTON.y - 16)
	var by := desc.size.y - STEP_BUTTON.y - 8
	minus_button.position = Vector2(16, by)
	plus_button.position = Vector2(DESC_W - 16 - STEP_BUTTON.x, by)
	var row_mid := ROW_Y + 4
	_sp_label.position = Vector2(PartyMenu.TAB_X + 8, row_mid)
	_sp_label.size = Vector2(300, 64)
	revert_button.position = Vector2(PartyMenu.TAB_X + 316, row_mid)
	commit_button.position = Vector2(revert_button.position.x + REVERT_SIZE.x + 8, row_mid)
	var note_x := commit_button.position.x + COMMIT_SIZE.x + 12
	_note_label.position = Vector2(note_x, row_mid)
	_note_label.size = Vector2(maxf(0.0, s.x - 8 - note_x), 64)


func dispatch(kind: String, arg: Variant) -> bool:
	var tree := _tree()
	if tree.is_empty():
		return false
	match kind:
		"node":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= tree.size():
				return false
			cursor = i
			_show_cursor()
			return true
		"node_dir":
			if typeof(arg) != TYPE_VECTOR2I:
				return false
			var n := _neighbor(cursor, arg)
			if n < 0:
				return false
			cursor = n
			_show_cursor()
			return true
		"plus":
			var sid := cursor_skill()
			var why := GrowthRules.learn_block(menu.state.defs, menu.member, menu.current_member(), draft, sid)
			if not why.is_empty():
				menu.show_notice(menu.reason_text(why))
				return true
			draft[sid] = int(draft.get(sid, 0)) + 1
			return true
		"minus":
			var sid := cursor_skill()
			var why := GrowthRules.unlearn_block(menu.state.defs, menu.member, menu.current_member(), draft, sid)
			if not why.is_empty():
				menu.show_notice(menu.reason_text(why))
				return true
			draft[sid] = int(draft[sid]) - 1
			if draft[sid] <= 0:
				draft.erase(sid)
			return true
		"revert":
			if draft.is_empty():
				menu.show_notice(menu.reason_text("no_draft"))
				return true
			draft.clear()
			return true
		"commit":
			if draft.is_empty():
				menu.show_notice(menu.reason_text("no_draft"))
				return true
			menu.open_dialog("commit")
			return true
	return false


## 확정 확인 창의 「확정」: 목표 레벨 사전으로 규칙의 allocate 를 한 번 부른다. 받아들여지면 초안을 지우고, 거부면 초안 그대로.
func commit_now() -> void:
	var m := menu.current_member()
	var levels := {}
	for sid in draft:
		levels[sid] = int(m.skills.get(sid, 0)) + int(draft[sid])
	if menu.apply(GrowthRules.allocate(menu.state, menu.member, levels)):
		draft.clear()


func _tree() -> Array[Dictionary]:
	if menu.state == null:
		return []
	return menu.state.defs.class_of(menu.member).tree


func _pos(i: int) -> Vector2i:
	var p: Array = _tree()[i]["pos"]
	return Vector2i(int(p[0]), int(p[1]))


## 트리 격자에서 d 방향으로 가장 가까운 노드(같은 행·열을 먼저). 그 방향에 없으면 -1(그대로).
func _neighbor(from: int, d: Vector2i) -> int:
	var tree := _tree()
	var p := _pos(from)
	var best := -1
	var best_key := []
	for j in tree.size():
		if j == from:
			continue
		var q := _pos(j)
		var along := (q.x - p.x) * d.x + (q.y - p.y) * d.y
		if along <= 0:
			continue
		var across := absi((q.y - p.y) * d.x) + absi((q.x - p.x) * d.y)
		var key := [0 if across == 0 else 1, along + across, across, j]
		if best < 0 or key < best_key:
			best = j
			best_key = key
	return best


func _show_cursor() -> void:
	var r := node_rect(cursor)
	tree_area.ensure_visible(r.position.y - FIRST.y, r.end.y + FIRST.y)


func refresh() -> void:
	if menu.state == null:
		return
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var c := defs.class_of(i)
	var tree := c.tree
	cursor = clampi(cursor, 0, maxi(0, tree.size() - 1))
	while nodes.size() < tree.size():
		var nd := SkillNode.new()
		nd.name = "Node_%d" % nodes.size()
		nd.size = NODE
		nd.scroller = tree_area
		nd.index = nodes.size()
		nd.activated.connect(func() -> void: menu.handle("node", nd.index))
		tree_area.content.add_child(nd)
		nodes.append(nd)
	var max_row := 0
	for j in nodes.size():
		var nd := nodes[j]
		if j >= tree.size():
			if nd.visible:
				nd.cancel()
			nd.visible = false
			continue
		nd.visible = true
		var sid := str(tree[j]["skill"])
		var s := defs.battle.skill(sid)
		var now := int(m.skills.get(sid, 0)) + int(draft.get(sid, 0))
		nd.position = node_rect(j).position
		max_row = maxi(max_row, _pos(j).y)
		nd.text = menu.texts.t(s.name_key)
		nd.level_line = menu.texts.t("party.node.level", {"level": now, "max": s.max_level()})
		nd.draft = int(draft.get(sid, 0))
		nd.selected = j == cursor
		var why := GrowthRules.learn_block(defs, i, m, draft, sid)
		match why:
			"":
				nd.status_kind = "learnable"
				nd.status_line = menu.texts.t("party.node.learnable")
			"max_level":
				nd.status_kind = "max"
				nd.status_line = menu.texts.t("party.node.max")
			"requires", "min_level":
				nd.status_kind = "locked"
				nd.status_line = menu.texts.t("party.node.locked")
			"no_sp":
				nd.status_kind = "no_sp"
				nd.status_line = menu.texts.t("party.node.no_sp")
			_:
				nd.status_kind = ""
				nd.status_line = ""
		nd.queue_redraw()
	tree_area.set_content_height(FIRST.y + max_row * PITCH.y + NODE.y + FIRST.y)
	tree_area.content.queue_redraw()
	_class_id = c.id
	_refresh_desc()
	var left := GrowthRules.sp_left(defs, m)
	var used := draft_sp()
	_sp_label.text = menu.texts.t("party.sp_left_draft", {"sp": left, "used": used}) if used > 0 else menu.texts.t("party.sp_left", {"sp": left})
	revert_button.dimmed = draft.is_empty()
	commit_button.dimmed = draft.is_empty()


func _refresh_desc() -> void:
	var sid := cursor_skill()
	if sid.is_empty():
		_desc_title.text = ""
		_desc_body.text = ""
		return
	var defs := menu.state.defs
	var m := menu.current_member()
	var s := defs.battle.skill(sid)
	var e := defs.class_of(menu.member).tree_entry(sid)
	var now := int(m.skills.get(sid, 0)) + int(draft.get(sid, 0))
	_desc_title.text = menu.texts.t(s.name_key)
	var lines: Array[String] = []
	var head := menu.texts.t("party.skill.passive" if s.passive() else "party.skill.active")
	if not s.passive():
		head += "   " + menu.texts.t("party.skill.tp", {"tp": s.level_row(maxi(1, now)).get("tp", 0)})
	head += "   " + menu.texts.t("party.node.level", {"level": now, "max": s.max_level()})
	lines.append(head)
	var next := now + 1 if now < s.max_level() else 0
	if next > 0:
		lines.append(menu.texts.t("party.skill.values", {"from": now, "to": next}))
	var cur_row := s.level_row(now) if now > 0 else {}
	var next_row := s.level_row(next) if next > 0 else {}
	for f in _fields(next_row if not next_row.is_empty() else cur_row):
		var a := _field_value(cur_row, f) if not cur_row.is_empty() else "-"
		var b := _field_value(next_row, f) if not next_row.is_empty() else ""
		var label := _field_label(next_row if not next_row.is_empty() else cur_row, f)
		lines.append("%s  %s" % [label, a if b.is_empty() else "%s → %s" % [a, b]])
	var levels := m.skills.duplicate()
	for k in draft:
		levels[k] = int(levels.get(k, 0)) + int(draft[k])
	for r in e.get("requires", []):
		var ok := int(levels.get(r["skill"], 0)) >= int(r["level"])
		lines.append("%s  %s" % [menu.texts.t("party.skill.requires", {"skill": menu.texts.t(defs.battle.skill(r["skill"]).name_key), "level": r["level"]}),
			menu.texts.t("party.skill.met" if ok else "party.skill.unmet")])
	var gate := int(e.get("min_level", 1))
	if gate > 1:
		lines.append("%s  %s" % [menu.texts.t("party.skill.gate", {"level": gate}), menu.texts.t("party.skill.met" if m.level >= gate else "party.skill.unmet")])
	_desc_body.text = "\n".join(lines)
	var learn := GrowthRules.learn_block(defs, menu.member, m, draft, sid)
	plus_button.dimmed = not learn.is_empty()
	minus_button.dimmed = not GrowthRules.unlearn_block(defs, menu.member, m, draft, sid).is_empty()
	desc.queue_redraw()


## 줄에서 보일 필드(이름 순서 그대로, TP 도 「TP 4 → 3」으로): kind 는 빼고, 묶음(bind·ailment·bonus)은 「묶음.필드」로 편다.
func _fields(row: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in row:
		if k == "kind":
			continue
		if typeof(row[k]) == TYPE_DICTIONARY:
			for sub in row[k]:
				if sub == "part" or sub == "id":
					continue
				out.append("%s.%s" % [k, sub])
		else:
			out.append(k)
	return out


func _field_label(row: Dictionary, f: String) -> String:
	if not f.contains("."):
		return menu.texts.t("party.field." + f)
	var parts := f.split(".")
	var group: Dictionary = row.get(parts[0], {})
	match parts[0]:
		"bonus":
			return menu.texts.t("stat." + parts[1])
		"bind":
			return menu.texts.t("party.field.sub", {"name": menu.texts.t("bind." + str(group.get("part", ""))), "field": menu.texts.t("party.field." + parts[1])})
		"ailment":
			return menu.texts.t("party.field.sub", {"name": menu.texts.t("ailment." + str(group.get("id", ""))), "field": menu.texts.t("party.field." + parts[1])})
	return f


func _field_value(row: Dictionary, f: String) -> String:
	var v: Variant
	var key := f
	if f.contains("."):
		var parts := f.split(".")
		v = (row.get(parts[0], {}) as Dictionary).get(parts[1])
		key = parts[1]
		if parts[0] == "bonus":
			return PartyMenu.signed(int(v))
	else:
		v = row.get(f)
	if v == null:
		return "-"
	var n := int(v)
	if PERMILLE.has(key):
		return ("%d%%" % (n / 10)) if n % 10 == 0 else ("%.1f%%" % (n / 10.0))
	if PERCENT.has(key):
		return "%d%%" % n
	return str(n)


func _draw_lines() -> void:
	if menu.state == null:
		return
	var tree := _tree()
	var m := menu.current_member()
	var levels := m.skills.duplicate()
	for k in draft:
		levels[k] = int(levels.get(k, 0)) + int(draft[k])
	var c := menu.state.defs.class_of(menu.member)
	for j in tree.size():
		for r in tree[j].get("requires", []):
			var from := int(c.tree_index.get(r["skill"], -1))
			if from < 0:
				continue
			var ok := int(levels.get(r["skill"], 0)) >= int(r["level"])
			var col := Color(0.4, 0.9, 1.0, 0.9) if ok else Color(0.35, 0.42, 0.48, 0.9)
			var seg := edge_segment(node_rect(from), node_rect(j))
			tree_area.content.draw_line(seg[0], seg[1], col, 3.0)


## 두 노드의 가운데를 잇는 선을 각 노드 테두리에서 끊은 [시작, 끝](선이 노드 면 위를 지나지 않는다).
static func edge_segment(a: Rect2, b: Rect2) -> Array[Vector2]:
	var d := b.get_center() - a.get_center()
	var exit := func(r: Rect2) -> float:
		var tx := INF if is_zero_approx(d.x) else r.size.x / 2.0 / absf(d.x)
		var ty := INF if is_zero_approx(d.y) else r.size.y / 2.0 / absf(d.y)
		return minf(tx, ty)
	return [a.get_center() + d * float(exit.call(a)), b.get_center() - d * float(exit.call(b))]


func _panel(c: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.11)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.3, 0.45, 0.52)
	sb.set_corner_radius_all(10)
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))
