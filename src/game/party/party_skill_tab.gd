## 캠프 「스킬」 화면(07 §9.2, §4.6, §9.9 E2-d: 원작 I HD 스킬 트리 yt_eo1hd_b_03). 캠프 무늬 판(CampBackdrop) 위에:
## 위 줄(MemberHeader: 이름 칸 + 앞·다음 대원, Lv 띠, 정보 띠 = 오른쪽 「남은 SP」(원작 SKILL POINT 자리)와 안내),
## 직업 탭(원작처럼 트리 판 윗변에 붙고 띠의 빈 왼쪽 끝 앞에 걸친다), 화면 폭 거의 전체 불투명 파랑 트리 판(#0C6A9E, 오른쪽 스크롤 막대,
## 자르기, 넘치면 세로로 끌어 내림, 노드는 알약 + Lv 상자, 직각 연결선과 그 선의 작은 「Lv n」(선행 레벨)),
## 아래 설명 상자(공용 DescBox 의 "tree" 모양: 머리에 이름·레벨 탭 1~최대·오른쪽 「Lv n」 막대, 몸에 종류·TP 줄과 다음 레벨 값·선행 줄을
## 세로 다섯 줄씩 칸으로, 오른쪽에 「−」「+」와 「되돌리기」「확정」, 그 왼쪽에 캠프의 가상 키패드 「취소」「선택」).
## 왼쪽 아래는 방향 십자 자리라 설명 상자는 x 216 부터(원작 48), 트리 판은 H − 217 에서 끝난다(원작 546). 높은 화면에서는 트리 판이 아래로 늘어난다.
## 원작은 노드마다 바로 배우고 알림 띠를 띄우지만 우리는 초안 → 「확정」 → 확인 창(캠프 공용 알림 띠 모양) 한 번(07 §4.6).
## 「+」「−」는 화면의 초안(스킬 → 더한 레벨)만 바꾸고(판정은 GrowthRules.learn_block·unlearn_block), 「확정」은 확정 확인 창 →
## GrowthRules.allocate 한 번(목표 레벨 사전). 초안은 저장하지 않는다.
## 노드 칸: 4 열 × 5 행까지, 노드 높이 64(원작 36, 누르는 칸 64 이상), 행 피치 100(노드 사이 36: 선의 「Lv n」 자리),
## 열 피치 = (트리 영역 폭 − 8 + 열 틈 36) / 4(1280 에서 294, 노드 258: 스크롤 막대 자리를 이름 자리 대신 열 틈에서 냈다, E2-d 검토 M1).
## 실제 트리는 세 행까지라 1280×720 에 다 들고, 다섯 행이면 끌어 내린다.
class_name PartySkillTab
extends Control

## 1280×720 의 노드 크기·피치(열 피치는 트리 영역 폭을 따라 늘어난다, node_rect)와 첫 노드 자리(트리 영역 기준).
const NODE := Vector2(258, 64)
const PITCH := Vector2(294, 100)
const FIRST := Vector2(4, 4)
const COLS := 4
## 트리 판(원작 x 48~1232·y 137~546): 왼쪽·오른쪽 여백, 위, 아래(화면 아래 끝에서: 방향 십자 위 H − 209 에서 8 위).
## 직업 탭(원작 x 73~287·y 100~137): 판 윗변에 붙고(아래 끝 = 판 위), 위 15 는 띠 왼쪽 빈 곳(x 72~292, y 103~118) 앞에 걸친다.
## 트리 영역(끌어 내리는 곳)은 판 안 왼쪽 12·오른쪽 24(스크롤 막대)·위아래 4. 스크롤 막대는 판 오른쪽 끝에서 18~8 안(트리 영역과 사이 6).
const WIN_SIDE := 48.0
const WIN_TOP := 137.0
const WIN_BOTTOM_GAP := 217.0
const AREA_INSET := Vector4(12, 4, 24, 4)
const SCROLL_RIGHT := 18.0
const CLASS_TAB := Rect2(72, 103, 220, 34)
## 트리 판(원작 잼 #0C6A9E, 바깥 선 #013045)·직업 탭(#1C3B4A).
const PANEL := Color("0c6a9e")
const PANEL_OUTER := Color("013045")
const PANEL_RADIUS := 12
## 선의 「Lv n」: 글자 크기, 글 상자 높이, 선과의 사이, 색(트리 판 위 5.10:1).
const LABEL_FS := 12
const LABEL_H := 15.0
const LABEL_GAP := 4.0
const LABEL_COLOR := UiTheme.ST_LV_TEXT
## 설명 상자(원작 x 48~1216·y 546~708): 왼쪽 끝(방향 십자 x 8~208 오른쪽 + 8), 아래 여백·높이(y 511~712), 안 여백, 줄.
## 머리(이름·레벨 탭·「Lv n」 막대)와 몸 줄 자리는 ListParts 의 "tree" 모양 함수가 정한다.
const DESC_LEFT := 216.0
const DESC_BOTTOM := 8.0
const DESC_H := 201.0
const DESC_PAD := ListParts.TREE_TEXT_PAD
const LINES_PER_COL := ListParts.TREE_PER_COL
const STEP_BUTTON := Vector2(96, 64)
## 「−」「+」 줄의 위(머리 아래, 머리 오른쪽은 「Lv n」 막대).
const STEP_TOP := 52.0
## 「되돌리기」「확정」(P3: 160·200 → 120·140, 그 왼쪽 키패드 「취소」「선택」 자리와 설명 두 칸(칸마다 230 이상)을 내려고).
const REVERT_SIZE := Vector2(120, 64)
const COMMIT_SIZE := Vector2(140, 64)
## 오른쪽 단추 묶음 폭(되돌리기 + 확정 줄).
const BUTTONS_W := REVERT_SIZE.x + 8.0 + COMMIT_SIZE.x
## 퍼밀(‰)로 적힌 줄 필드: 화면은 %로 보인다.
## 선행 연결선: 굵기, 들어가는 쪽 화살표 길이·너비.
const LINE_W := 3.0
const ARROW := Vector2(9, 10)
const PERMILLE := ["accuracy", "chance", "hp_permille", "value"]
const PERCENT := ["wis_pct"]

var menu: PartyMenu
## 키보드 커서·고른 노드(트리 칸 번호).
var cursor := 0
## 초안: 스킬 ID → 초안으로 더한 레벨(1 이상만 둔다).
var draft := {}
var top: MemberHeader
var tree_window: Control
var class_tab: Control
var tree_area: PartyScroll
var nodes: Array[SkillNode] = []
var desc: DescBox
var minus_button: PartyButton
var plus_button: PartyButton
var revert_button: PartyButton
var commit_button: PartyButton
## 설명 줄(첫 줄 = 종류·TP·Lv, 다음 레벨 값, 선행·관문). 설명 띠에 세로 다섯 줄씩 칸으로 그린다.
var desc_lines: Array[String] = []
## 설명 상자 레벨 탭·「Lv n」 막대 [배운 레벨, 초안, 최대].
var level_boxes := [0, 0, 0]
## 선의 「Lv n」(마지막으로 그린 것): [{rect, text, from, to}](트리 영역 내용 기준).
var condition_labels: Array[Dictionary] = []
## 마지막으로 본 트리 영역 크기: 실제로 바뀐 뒤 한 번만 커서 노드를 보이게 한다(보통 다시 그리기는 손으로 내린 자리를 지킨다, 캠프 목록과 같은 규칙).
var _seen_area := Vector2.ZERO
var _sp_label := Label.new()
var _note_label := Label.new()
var _class_name := ""


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	top = MemberHeader.new()
	top.name = "SkillTop"
	top.show_vitals = false  # 띠에는 남은 SP 만(07 §9.9 E1 ③)
	add_child(top)
	top.build("Skill")
	top.step.connect(func(d: int) -> void: menu.handle("member_step", d))
	tree_window = Control.new()
	tree_window.name = "TreeWindow"
	tree_window.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(tree_window)
	PartyMenu.place(tree_window, Vector2(0, 0), Vector2(1, 1), Vector4(WIN_SIDE, WIN_TOP, -WIN_SIDE, -WIN_BOTTOM_GAP))
	tree_window.draw.connect(_draw_tree_panel)
	class_tab = Control.new()
	class_tab.name = "ClassTab"
	class_tab.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(class_tab)
	PartyMenu.place(class_tab, Vector2.ZERO, Vector2.ZERO, Vector4(CLASS_TAB.position.x, CLASS_TAB.position.y, CLASS_TAB.end.x, CLASS_TAB.end.y))
	class_tab.draw.connect(_draw_class_tab)
	tree_area = PartyScroll.new()
	tree_area.name = "TreeArea"
	tree_area.content.draw.connect(_draw_lines)
	tree_area.scrolled.connect(tree_window.queue_redraw)
	add_child(tree_area)
	PartyMenu.place(tree_area, Vector2(0, 0), Vector2(1, 1),
		Vector4(WIN_SIDE + AREA_INSET.x, WIN_TOP + AREA_INSET.y, -WIN_SIDE - AREA_INSET.z, -WIN_BOTTOM_GAP - AREA_INSET.w))
	tree_area.resized.connect(func() -> void:
		if menu.state != null and visible:
			refresh())
	desc = DescBox.new()
	desc.name = "SkillDesc"
	desc.look = "tree"
	add_child(desc)
	PartyMenu.place(desc, Vector2(0, 1), Vector2(1, 1), Vector4(DESC_LEFT, -DESC_BOTTOM - DESC_H, -WIN_SIDE, -DESC_BOTTOM))
	plus_button = _button("SkillPlus", "", "plus", desc, Vector4(-DESC_PAD - STEP_BUTTON.x, STEP_TOP, -DESC_PAD, STEP_TOP + STEP_BUTTON.y))
	plus_button.icon = "zoom_in"  # 「−」「+」 기호(글꼴 부분 집합에 U+2212 가 없다)
	minus_button = _button("SkillMinus", "", "minus", desc,
		Vector4(-DESC_PAD - 2.0 * STEP_BUTTON.x - 8, STEP_TOP, -DESC_PAD - STEP_BUTTON.x - 8, STEP_TOP + STEP_BUTTON.y))
	minus_button.icon = "zoom_out"
	var by := DESC_H - 8 - COMMIT_SIZE.y
	commit_button = _button("SkillCommit", menu.texts.t("party.commit"), "commit", desc, Vector4(-DESC_PAD - COMMIT_SIZE.x, by, -DESC_PAD, by + COMMIT_SIZE.y))
	revert_button = _button("SkillRevert", menu.texts.t("party.revert"), "revert", desc,
		Vector4(-DESC_PAD - BUTTONS_W, by, -DESC_PAD - COMMIT_SIZE.x - 8, by + REVERT_SIZE.y))
	# 「남은 SP」는 정보 띠 오른쪽(원작 SKILL POINT 자리), 안내(거부 이유 등)는 그 왼쪽. 확정 안내는 확정 창 글에 있다(07 §9.9 E1 ③).
	_sp_label.name = "SpLine"
	_sp_label.add_theme_font_size_override("font_size", 22)
	_sp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sp_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_sp_label)
	PartyMenu.place(_sp_label, Vector2(1, 0), Vector2(1, 0), Vector4(-420, MemberHeader.INFO_Y, -20, MemberHeader.INFO_Y + MemberHeader.INFO_H))
	_note_label.name = "CommitNote"
	_note_label.add_theme_font_size_override("font_size", 18)
	_note_label.add_theme_color_override("font_color", MemberHeader.STRIP_ACCENT)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note_label.clip_text = true
	_note_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_note_label)
	PartyMenu.place(_note_label, Vector2(0, 0), Vector2(1, 0), Vector4(400, MemberHeader.INFO_Y, -440, MemberHeader.INFO_Y + MemberHeader.INFO_H))


func _button(n: String, label: String, kind: String, parent: Control, off: Vector4) -> PartyButton:
	var b := PartyButton.new()
	b.name = n
	b.text = label
	b.activated.connect(func() -> void: menu.handle(kind))
	parent.add_child(b)
	PartyMenu.place(b, Vector2(1, 0), Vector2(1, 0), off)
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


## 정보 띠 가운데: 안내(거부 이유 등)가 있을 때만 노란 글자로(띠 대비 4.5:1). 없으면 비운다.
func notice_changed() -> void:
	_note_label.text = menu.notice


## 초안이 쓰는 SP.
func draft_sp() -> int:
	return GrowthRules.sp_used(draft)


func tree_rect() -> Rect2:
	return Rect2(tree_area.position, tree_area.size)


func tree_window_rect() -> Rect2:
	return Rect2(tree_window.position, tree_window.size)


func desc_rect() -> Rect2:
	return Rect2(desc.position, desc.size)


func class_tab_rect() -> Rect2:
	return Rect2(class_tab.position, class_tab.size)


## 열 피치(트리 영역 폭을 4 열로 나눈다. 열 틈은 PITCH.x − NODE.x 그대로).
func pitch() -> Vector2:
	var w := tree_area.size.x if tree_area.size.x > 0.0 else 1160.0
	return Vector2((w - 2.0 * FIRST.x + (PITCH.x - NODE.x)) / COLS, PITCH.y)


func node_size() -> Vector2:
	return Vector2(pitch().x - (PITCH.x - NODE.x), NODE.y)


func node_rect(i: int) -> Rect2:
	var p := _pos(i)
	return Rect2(FIRST + Vector2(p) * pitch(), node_size())


## 트리 판 안 스크롤 막대 자리(트리 판 기준).
func scroll_rect() -> Rect2:
	return Rect2(tree_window.size.x - SCROLL_RIGHT, AREA_INSET.y + 4.0, ListParts.SCROLL_W,
		tree_window.size.y - 2.0 * (AREA_INSET.y + 4.0))


func _desc_box() -> Rect2:
	return Rect2(Vector2.ZERO, desc.size)


## 설명 상자 레벨 탭 k(1부터, 설명 상자 기준).
func level_box_rect(k: int) -> Rect2:
	return ListParts.tree_tab_rect(_desc_box(), k)


## 설명 상자 「Lv n」 막대(설명 상자 기준).
func lv_bar_rect() -> Rect2:
	return ListParts.tree_bar_rect(_desc_box())


## 설명 상자 몸 줄 선택지(DescBox opts 의 칸 부분).
func _cols_opts() -> Dictionary:
	return {"per_col": LINES_PER_COL, "max_cols": 3, "room": body_width()}


## 설명 줄 i 의 자리(설명 상자 기준): 다섯 줄씩 칸, 칸 폭 = 줄 글 자리(body_width)를 쓰는 칸 수(1~3)로 나눈 것.
func desc_line_pos(i: int) -> Vector2:
	return ListParts.tree_line_pos(_desc_box(), i, desc_lines.size(), _cols_opts())


func desc_cols() -> int:
	return ListParts.tree_cols(desc_lines.size(), _cols_opts())


func col_width() -> float:
	return ListParts.tree_col_width(desc_lines.size(), _cols_opts())


## 줄 글 자리 폭: 안 여백부터 캠프 키패드 「취소」「선택」 왼쪽 − 8 까지(키패드는 오른쪽 아래 앵커, 띠 오른쪽 끝 = 화면 − WIN_SIDE).
func body_width() -> float:
	var pad_left := desc.size.x + WIN_SIDE + PartyMenu.PAD_KEYS_SKILLS.x
	return maxf(120.0, pad_left - 8.0 - DESC_PAD)


## 설명 줄 전부(시험·디버그용, 줄바꿈으로 잇는다).
func desc_text() -> String:
	return "\n".join(desc_lines)


## 지금 고른 스킬 ID(트리가 비면 "").
func cursor_skill() -> String:
	var tree := _tree()
	return str(tree[cursor]["skill"]) if cursor < tree.size() else ""


func place(_s: Vector2) -> void:
	if menu.state != null and visible:
		refresh()


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
	notice_changed()
	var defs := menu.state.defs
	var i := menu.member
	var m := menu.current_member()
	var c := defs.class_of(i)
	var tree := c.tree
	cursor = clampi(cursor, 0, maxi(0, tree.size() - 1))
	while nodes.size() < tree.size():
		var nd := SkillNode.new()
		nd.name = "Node_%d" % nodes.size()
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
		nd.size = node_size()
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
	if tree_area.size != _seen_area:
		_seen_area = tree_area.size
		_show_cursor()
	tree_window.queue_redraw()
	_class_name = menu.texts.t(defs.party.class_ids[i])
	class_tab.queue_redraw()
	top.name_text = menu.member_name(i)
	top.level_text = menu.texts.t("party.level", {"level": m.level})
	top.queue_redraw()
	tree_area.content.queue_redraw()
	_refresh_desc()
	var left := GrowthRules.sp_left(defs, m)
	var used := draft_sp()
	# 초안이 있으면 「남은 SP 2 → 0」(확정하면 남는 SP), 없으면 「남은 SP 2」.
	_sp_label.text = menu.texts.t("party.sp_left_draft", {"sp": left, "after": left - used}) if used > 0 else menu.texts.t("party.sp_left", {"sp": left})
	revert_button.dimmed = draft.is_empty()
	commit_button.dimmed = draft.is_empty()


func _refresh_desc() -> void:
	var sid := cursor_skill()
	if sid.is_empty():
		desc_lines = []
		level_boxes = [0, 0, 0]
		desc.show_desc("", "", desc_lines)
		return
	var defs := menu.state.defs
	var m := menu.current_member()
	var s := defs.battle.skill(sid)
	var e := defs.class_of(menu.member).tree_entry(sid)
	var now := int(m.skills.get(sid, 0)) + int(draft.get(sid, 0))
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
	desc_lines = lines
	level_boxes = [int(m.skills.get(sid, 0)), int(draft.get(sid, 0)), s.max_level()]
	var op := _cols_opts()
	op["levels"] = level_boxes
	op["bar"] = level_boxes
	op["bar_text"] = menu.texts.t("party.level", {"level": now})
	op["accent_first"] = true
	desc.show_desc(menu.texts.t(s.name_key), "", desc_lines, [], op)
	var learn := GrowthRules.learn_block(defs, menu.member, m, draft, sid)
	plus_button.dimmed = not learn.is_empty()
	minus_button.dimmed = not GrowthRules.unlearn_block(defs, menu.member, m, draft, sid).is_empty()


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
	var canvas := tree_area.content
	SheetParts.begin(canvas)
	var unmet: Array[PackedVector2Array] = []
	var met: Array[PackedVector2Array] = []
	var all_paths: Array[PackedVector2Array] = []
	var reqs: Array = []
	for j in tree.size():
		for r in tree[j].get("requires", []):
			var from := int(c.tree_index.get(r["skill"], -1))
			if from < 0:
				continue
			var path := connector_path(node_rect(from), node_rect(j), pitch() - node_size())
			(met if int(levels.get(r["skill"], 0)) >= int(r["level"]) else unmet).append(path)
			all_paths.append(path)
			reqs.append([from, j, int(r["level"])])
	# 갖춘 선을 나중에 그린다: 두 선행이 한 노드로 들어가 겹치는 끝 토막은 갖춘 쪽 색으로 보인다.
	for path in unmet:
		_draw_connector(canvas, path, UiTheme.TREE_LINE_UNMET)
	for path in met:
		_draw_connector(canvas, path, UiTheme.TREE_LINE_MET)
	# 선마다 선행 레벨 「Lv n」(원작 「Lv1」「Lv3」): 가장 긴 토막 옆, 노드·다른 글·다른 선에 걸리지 않는 쪽.
	var font := canvas.get_theme_default_font()
	var blocks: Array[Rect2] = []
	for j in tree.size():
		blocks.append(node_rect(j))
	condition_labels = []
	for k in all_paths.size():
		var text := menu.texts.t("party.level", {"level": reqs[k][2]})
		var lr := label_rect(all_paths[k], Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS).x, LABEL_H), blocks,
			all_paths, k)
		blocks.append(lr)
		condition_labels.append({"rect": lr, "text": text, "from": reqs[k][0], "to": reqs[k][1]})
		SheetParts._text(canvas, Vector2(lr.position.x, lr.end.y - 3.0), text, LABEL_FS, LABEL_COLOR, lr.size.x + 1.0)


static func _draw_connector(canvas: CanvasItem, path: PackedVector2Array, col: Color) -> void:
	var tri := arrow_points(path)
	var stop := tri[1].lerp(tri[2], 0.5)  # 화살표 밑변 가운데에서 선을 멈춘다(끝이 화살표 밖으로 비치지 않는다)
	for k in path.size() - 1:
		var a := path[k]
		var b := stop if k == path.size() - 2 else path[k + 1]
		# 가로·세로 토막을 굵기만큼 늘린 사각형으로: 꺾이는 곳이 비지 않는다.
		SheetParts._fill(canvas, Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(LINE_W, LINE_W) / 2.0, (b - a).abs() + Vector2(LINE_W, LINE_W)), col)
	SheetParts._poly(canvas, tri, col)


## 선행 노드 a 에서 뒤 노드 b 로 가는 직각 꺾은선(원작 트리처럼). 점은 a 테두리에서 시작해 b 테두리에서 끝나고, 토막은 모두
## 가로·세로이며 노드 사이 틈(gap = 칸 간격 − 노드 크기)으로만 지난다: 어느 노드 면도 가로지르지 않는다.
## 아래 줄로: a 아래 가운데 → b 바로 위 틈 → b 위 가운데. 한 줄 넘게 내려가면 a 옆 세로 틈으로 내려간다. 위 줄로는 거꾸로.
## 같은 줄: 바로 옆이면 옆 가장자리끼리, 떨어져 있으면 아래 틈으로 돌아 b 아래로 들어간다.
static func connector_path(a: Rect2, b: Rect2, gap: Vector2) -> PackedVector2Array:
	var ac := a.get_center()
	var bc := b.get_center()
	var pts := PackedVector2Array()
	if b.position.y >= a.end.y or b.end.y <= a.position.y:
		var down := b.position.y >= a.end.y
		var a_y := a.end.y if down else a.position.y
		var b_y := b.position.y if down else b.end.y
		var step := gap.y / 2.0 if down else -gap.y / 2.0
		var b_mid := b_y - step
		pts.append(Vector2(ac.x, a_y))
		if absf(b_y - a_y) > gap.y + 0.5:
			# 사이에 줄이 있다: a 바로 아래(위) 틈 → a 옆 세로 틈 → b 바로 위(아래) 틈
			var side_x := a.end.x + gap.x / 2.0 if bc.x >= ac.x else a.position.x - gap.x / 2.0
			pts.append(Vector2(ac.x, a_y + step))
			pts.append(Vector2(side_x, a_y + step))
			pts.append(Vector2(side_x, b_mid))
			pts.append(Vector2(bc.x, b_mid))
		elif not is_equal_approx(ac.x, bc.x):
			pts.append(Vector2(ac.x, b_mid))
			pts.append(Vector2(bc.x, b_mid))
		pts.append(Vector2(bc.x, b_y))
		return pts
	var right := bc.x >= ac.x
	var gap_x := b.position.x - a.end.x if right else a.position.x - b.end.x
	if gap_x <= gap.x + 0.5 and is_equal_approx(ac.y, bc.y):
		pts.append(Vector2(a.end.x if right else a.position.x, ac.y))
		pts.append(Vector2(b.position.x if right else b.end.x, bc.y))
		return pts
	var under := maxf(a.end.y, b.end.y) + gap.y / 2.0
	pts.append(Vector2(ac.x, a.end.y))
	pts.append(Vector2(ac.x, under))
	pts.append(Vector2(bc.x, under))
	pts.append(Vector2(bc.x, b.end.y))
	return pts


## 선 path 의 「Lv n」 글 상자(크기 sz). 가장 긴 토막의 가운데 옆: 가로 토막이면 위·아래, 세로 토막이면 왼쪽·오른쪽 가운데.
## 앞 후보가 blocks(노드·앞서 놓은 글)나 다른 선(paths 의 k 밖)과 겹치면 다음 후보, 모두 겹치면 첫 후보.
static func label_rect(path: PackedVector2Array, sz: Vector2, blocks: Array[Rect2], paths: Array[PackedVector2Array], k: int) -> Rect2:
	var best := 0
	for i in path.size() - 1:
		if path[i].distance_to(path[i + 1]) > path[best].distance_to(path[best + 1]) + 0.5:
			best = i
	var a := path[best]
	var b := path[best + 1]
	var mid := a.lerp(b, 0.5)
	var cands: Array[Rect2] = []
	if is_equal_approx(a.y, b.y):
		cands.append(Rect2(mid.x - sz.x / 2.0, mid.y - LABEL_GAP / 2.0 - sz.y, sz.x, sz.y))
		cands.append(Rect2(mid.x - sz.x / 2.0, mid.y + LABEL_GAP / 2.0, sz.x, sz.y))
	else:
		cands.append(Rect2(mid.x - LABEL_GAP - sz.x, mid.y - sz.y / 2.0, sz.x, sz.y))
		cands.append(Rect2(mid.x + LABEL_GAP, mid.y - sz.y / 2.0, sz.x, sz.y))
	for r in cands:
		var clear := true
		for bl in blocks:
			if bl.intersects(r):
				clear = false
		for j in paths.size():
			if j != k and path_hits(paths[j], r):
				clear = false
		if clear:
			return r
	return cands[0]


## 꺾은선이 사각형 r 을 지나는지(선 굵기 포함).
static func path_hits(path: PackedVector2Array, r: Rect2) -> bool:
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var seg := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(LINE_W, LINE_W) / 2.0, (b - a).abs() + Vector2(LINE_W, LINE_W))
		if seg.intersects(r):
			return true
	return false


## 꺾은선 끝(b 테두리)의 화살표 세모 [끝, 밑변 한쪽, 밑변 다른 쪽]: 마지막 토막 방향으로 b 안을 가리킨다.
static func arrow_points(path: PackedVector2Array) -> PackedVector2Array:
	var tip := path[path.size() - 1]
	var dir := (tip - path[path.size() - 2]).normalized()
	var side := Vector2(-dir.y, dir.x) * ARROW.y / 2.0
	var base := tip - dir * ARROW.x
	return PackedVector2Array([tip, base + side, base - side])


## 트리 판(원작 b_03): 바깥 어두운 선과 불투명 파랑, 둥근 모서리. 오른쪽 안에 스크롤 막대(목록 창과 같은 그림, 넘치지 않으면 손잡이가 길 전체).
func _draw_tree_panel() -> void:
	SheetParts.begin(tree_window)
	var r := Rect2(Vector2.ZERO, tree_window.size)
	SheetParts._fill_round(tree_window, r, PANEL_OUTER, PANEL_RADIUS)
	SheetParts._fill_round(tree_window, r.grow(-2.0), PANEL, PANEL_RADIUS - 2)
	ListParts.draw_scroll(tree_window, scroll_rect(), tree_area.scroll, tree_area.content_height, tree_area.size.y)


## 직업 탭(원작 트리 판 위 가장자리에 붙은 탭, 직업이 하나라 탭도 하나): 어두운 청회색 판 + 흰 글자. 장식.
func _draw_class_tab() -> void:
	SheetParts.begin(class_tab)
	var r := Rect2(Vector2.ZERO, class_tab.size)
	var pts := PackedVector2Array([Vector2(0, r.end.y), Vector2(6, 0), Vector2(r.end.x - 6, 0), r.end])
	SheetParts._poly(class_tab, pts, UiTheme.TREE_TAB)
	class_tab.draw_polyline(pts, UiTheme.TREE_WIN_EDGE, 1.5, true)
	SheetParts._text(class_tab, Vector2(0, r.get_center().y + 18 * 0.36), _class_name, 18, UiTheme.TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
