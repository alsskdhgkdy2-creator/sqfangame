## M2.6 UI 다듬기 2단계(00 D20 ②, docs/research/03 U6~U9) 시험: 공용 창 모양, 지도 모눈·좌표, 장비 합계 표,
## 탐색 상태 칸 TP. 저장은 장면 시험 임시 폴더에만 쓴다. 결과는 구성으로 정한다(D15).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000)]

var kit: Kit
var texts: TextDb


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null


func _kit() -> void:
	timeout_sec = 40.0
	if kit == null:
		kit = Kit.new(tree)
		texts = TextDb.load_path("res://data/text/ko.json")


## 화면 전체를 size 로(앵커를 풀고 크기를 정한다).
func _resize(s: DungeonScreen, size: Vector2) -> void:
	s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	s.position = Vector2.ZERO
	s.size = size
	await kit.frames(3)


static func _source(sc: Script) -> String:
	return FileAccess.get_file_as_string(sc.resource_path)


static func _inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.grow(0.01).encloses(inner)


# ---- U9 탐색 상태 칸 TP ----

## 데이터가 허락하는 가장 큰 값: 레벨 상한, 직업 트리 스킬을 모두 최대로 배운 묶음의 최대 HP·TP(패시브 보정 포함), HP·TP 가득.
func _max_party(s: DungeonScreen) -> void:
	var defs := s.state.defs
	for i in s.state.party.members.size():
		var m := s.state.party.members[i]
		var c := defs.class_of(i)
		m.level = defs.battle.growth.level_cap
		for sid in c.skills:
			m.skills[sid] = defs.battle.skill(sid).levels.size()
		var p := GrowthRules.profile(defs, i, m)
		m.max_hp = p["max_hp"]
		m.max_tp = p["max_tp"]
		m.hp = m.max_hp
		m.tp = m.max_tp


func _check_status_rows(s: DungeonScreen, tag: String) -> bool:
	var st := s.status
	var font := st.get_theme_default_font()
	var panel := Rect2(Vector2.ZERO, st.size)
	var gauge := st.gauge_rect()
	check(_inside(gauge, panel), tag + ": 위험도 막대 안")
	var prev_bottom := gauge.end.y
	var cols := st.columns()
	for i in s.state.party.members.size():
		var m := s.state.party.members[i]
		var row := st.row_rect(i)
		var l := st.row_layout(i, cols)
		var who := "%s 줄 %d" % [tag, i]
		check(_inside(row, panel), who + ": 칸 안")
		check(row.position.y >= prev_bottom, who + ": 위 줄(또는 위험도 막대)과 겹치지 않는다")
		prev_bottom = row.end.y
		var keys := ["name", "level", "hp_bar", "tp_bar", "hp_value", "tp_value"]
		for k in keys:
			check(_inside(l[k], row), "%s: %s 이 줄 안 %s ⊄ %s" % [who, k, str(l[k]), str(row)])
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				check(not (l[keys[a]] as Rect2).intersects(l[keys[b]]), "%s: %s 와 %s 가 겹치지 않는다" % [who, keys[a], keys[b]])
		var hb: Rect2 = l["hp_bar"]
		var tb: Rect2 = l["tp_bar"]
		check(tb.size.y < hb.size.y and tb.size.y >= 4.0, "%s: TP 막대가 더 가늘다(%.1f < %.1f)" % [who, tb.size.y, hb.size.y])
		check(tb.position.y >= hb.end.y, who + ": TP 막대는 HP 막대 아래")
		check(hb.size.x >= StatusPanel.BAR_MIN_W, "%s: 막대 폭 %.0f" % [who, hb.size.x])
		var name: String = st.member_names[i]
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, l["name_fs"]).x
		check(l["name_fs"] == StatusPanel.NAME_FS or (l["compact"] and l["name_fs"] >= StatusPanel.NAME_MIN_FS), "%s: 이름 글자 %d" % [who, l["name_fs"]])
		check(nw <= (l["name"] as Rect2).size.x + 0.5, "%s: 이름 「%s」 이 다 보인다(%.1f ≤ %.1f)" % [who, name, nw, (l["name"] as Rect2).size.x])
		check(font.get_string_size(st.level_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, StatusPanel.LV_FS).x <= (l["level"] as Rect2).size.x + 0.5, who + ": 레벨")
		check(font.get_string_size(st.hp_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, l["hp_fs"]).x <= (l["hp_value"] as Rect2).size.x + 0.5, who + ": HP 값")
		check(font.get_string_size(st.tp_text(i), HORIZONTAL_ALIGNMENT_LEFT, -1, l["tp_fs"]).x <= (l["tp_value"] as Rect2).size.x + 0.5, who + ": TP 값")
		check_eq(st.hp_text(i), "%d/%d" % [m.hp, m.max_hp], who + ": HP 값 글")
		check_eq(st.tp_text(i), "%d/%d" % [m.tp, m.max_tp], who + ": TP 값 글")
		check_eq(st.hp_bar_color(i), HpColor.of(m.hp, m.max_hp), who + ": HP 색 = HpColor")
	return cols["compact"]


func test_status_rows_show_hp_and_thinner_tp_without_overlap() -> void:
	_kit()
	var s := await kit.open("native", 7)
	var hp := [31, 26, 16, 12, 12]
	var tp := [30, 20, 10, 54, 0]
	for i in hp.size():
		s.state.party.members[i].hp = hp[i]
		s.state.party.members[i].tp = tp[i]
	var party_names := s._member_names.duplicate()
	var class_names: Array[String] = []
	for i in s.state.party.members.size():
		class_names.append(texts.t(s.state.defs.class_of(i).name_key))
	var compact_seen := 0
	for values in ["레벨 1", "최대"]:
		if values == "최대":
			_max_party(s)
			check_eq(s.state.party.members[0].level, 30, "준비: 레벨 30")
			check(s.state.party.members.any(func(m: PartyState.Member) -> bool: return m.max_hp >= 100 and m.max_tp >= 100), "준비: 세 자리 HP·TP")
		for sz in SIZES:
			for open in [true, false]:
				if s._map_open != open:
					s._toggle_map()
				await _resize(s, sz)
				var st := s.status
				var tag := "%s %dx%d %s" % [values, sz.x, sz.y, "지도" if open else "지도 닫음"]
				check_eq(st.size, Vector2(roundf(sz.x * 0.4) if open else DungeonScreen.SIDE_COLLAPSED, DungeonScreen.STATUS_H), tag + ": 상태 칸 크기 그대로")
				for names in [party_names, class_names]:
					st.member_names.assign(names)
					var compact := _check_status_rows(s, "%s %s" % [tag, "대원 이름" if names == party_names else "직업 이름"])
					if compact:
						compact_seen += 1
					if open:
						check(not compact, tag + ": 지도를 열면 넓은 꼴")
				st.member_names.assign(party_names)
	check(compact_seen >= 2, "좁은 꼴(값 쌓기)도 보았다(%d)" % compact_seen)
	check_eq(UiTheme.TP_BAR, Color(0.4, 0.65, 1.0), "TP 색 = 전투 대원 칸 TP 색")
	for sc in [BattleCard, MemberCell, StatusPanel]:
		check(_source(sc).contains("UiTheme.TP_BAR"), "%s: 같은 TP 색 상수를 쓴다" % (sc as Script).resource_path)


# ---- U8 장비 합계 표 ----

## 이온 세이버 하나를 가방에 넣고 파티 메뉴 → 듀얼리스트 A → 장비 탭.
func _equip_tab(s: DungeonScreen) -> PartyEquipTab:
	s._on_debug_request(JSON.stringify({"op": "supply", "item": "equip.ion_saber", "n": 1}))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_E)
	await kit.press_key(KEY_3)
	return s.party_menu.equip_tab


## 시험이 따로 만든 사본으로 읽은 GrowthRules.profile(화면 도움 함수와 견준다).
func _profile_with(s: DungeonScreen, i: int, slot: int, item: String) -> Dictionary:
	var m := s.state.party.members[i]
	var copy := PartyState.Member.new(m.id, m.max_hp, m.hp, m.max_tp, m.tp)
	copy.level = m.level
	copy.exp = m.exp
	copy.skills = m.skills.duplicate()
	copy.equip = m.equip.duplicate()
	copy.equip[slot] = item
	return GrowthRules.profile(s.state.defs, i, copy)


func _check_totals(t: EquipTotals, now: Dictionary, after: Variant, tag: String) -> void:
	check_eq(t.lines.size(), BattleLimits.GEAR.size() + BattleLimits.STATS.size(), tag + ": 줄 수")
	check_eq(t.comparing, after != null, tag + ": 견주는지")
	for g in BattleLimits.GEAR:
		var l := t.line_of(g)
		check_eq(l["name"], texts.t("stat." + g), "%s %s: 이름" % [tag, g])
		check_eq(l["now"], now["gear"][g], "%s %s: 지금" % [tag, g])
		check_eq(l["after"], after["gear"][g] if after != null else null, "%s %s: 바꾸면" % [tag, g])
	for k in BattleLimits.STATS:
		var l := t.line_of(k)
		check_eq(l["now"], now["stats"][k], "%s %s: 지금" % [tag, k])
		check_eq(l["after"], after["stats"][k] if after != null else null, "%s %s: 바꾸면" % [tag, k])
	for l in t.lines:
		var d: int = int(l["after"]) - int(l["now"]) if l["after"] != null else 0
		var dt := EquipTotals.delta_text(l)
		if d > 0:
			check(dt == "+%d" % d and EquipTotals.delta_color(l) == EquipTotals.UP_COLOR, "%s %s: 오름 = 「+」 + 색" % [tag, l["key"]])
		elif d < 0:
			check(dt == "-%d" % -d and EquipTotals.delta_color(l) == EquipTotals.DOWN_COLOR, "%s %s: 내림 = 「-」 + 색" % [tag, l["key"]])
		else:
			check(dt.is_empty() and EquipTotals.delta_color(l) == EquipTotals.VALUE_COLOR, "%s %s: 같음 = 표시 없음" % [tag, l["key"]])


func test_equip_totals_show_profile_and_compare_the_highlighted_row() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	var et := await _equip_tab(s)
	var pm := s.party_menu
	var i := pm.member
	var t := et.totals
	check(et.is_visible_in_tree() and t.is_visible_in_tree(), "준비: 장비 탭과 합계 표")
	var now := GrowthRules.profile(s.state.defs, i, s.state.party.members[i])
	_check_totals(t, now, null, "목록 닫힘")
	await kit.press_key(KEY_ENTER)
	check(et.list_open and et.row_items[0] == "" and et.row_block[0].is_empty(), "준비: 무기 칸 목록, 맨 위 「빼기」")
	_check_totals(t, now, _profile_with(s, i, 0, ""), "빼기 줄")
	check(t.line_of("atk")["after"] < t.line_of("atk")["now"], "무기를 빼면 공격이 준다")
	await kit.press_key(KEY_DOWN)
	check_eq(et.row_items[et.list_cursor], "equip.ion_saber", "준비: 이온 세이버 줄")
	var after := _profile_with(s, i, 0, "equip.ion_saber")
	_check_totals(t, now, after, "이온 세이버 줄")
	# 목록 줄의 바뀌는 값과 표가 같은 도움 함수에서 나온다
	var note := et.rows[et.list_cursor].note
	var changed := 0
	for l in t.lines:
		var dt := EquipTotals.delta_text(l)
		if not dt.is_empty():
			changed += 1
			check(note.contains("%s %s" % [l["name"], dt]), "줄 글 「%s」에 %s %s" % [note, l["name"], dt])
	check(changed > 0, "바뀌는 값이 있다(%d)" % changed)
	check_eq(note, et.change_text(now, "equip.ion_saber"), "줄 글 = change_text")
	check_eq(FileAccess.get_file_as_string((PartyEquipTab as Script).resource_path).count("PartyState.Member.new("), 1, "사본 만드는 곳은 한 군데")
	check_eq(s.state.party.members[i].equip[0], now["weapon"], "견주기만 했고 장비는 그대로")
	await kit.press_key(KEY_ESCAPE)
	check(not et.list_open, "목록 닫음")
	_check_totals(t, now, null, "다시 닫힘")
	# 빈 칸(방어구 3)의 「빼기」는 못 고르는 줄: 견주지 않는다
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check(et.list_open and et.cursor == 3 and not et.row_block[0].is_empty(), "준비: 빈 칸 목록의 못 고르는 「빼기」")
	_check_totals(t, now, null, "못 고르는 줄")


func test_equip_totals_fit_under_slots_at_both_sizes() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	var et := await _equip_tab(s)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_DOWN)
	var t := et.totals
	var font := t.get_theme_default_font()
	for sz in SIZES:
		await _resize(s, sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		check(t.comparing, tag + ": 준비: 견주는 중")
		var tr := Rect2(t.position, t.size)
		check(_inside(tr, Rect2(Vector2.ZERO, sz)), tag + ": 화면 안")
		check(t.size.y >= EquipTotals.needed_height() - 0.01, "%s: 줄이 다 들어가는 높이(%.0f)" % [tag, t.size.y])
		for b in et.slot_rows:
			check(not Rect2(b.position, b.size).intersects(tr), "%s: %s 와 겹치지 않는다" % [tag, b.name])
		check(not Rect2(et.list.position, et.list.size).intersects(tr), tag + ": 목록과 겹치지 않는다")
		var head_w := font.get_string_size(t.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + font.get_string_size(t.compare_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		check(head_w + 2.0 * EquipTotals.PAD <= t.size.x, tag + ": 머리 글자")
		for j in t.lines.size():
			var l := t.lines[j]
			var c := t.line_layout(j)
			var who := "%s %s" % [tag, l["key"]]
			check(_inside(c["line"], Rect2(Vector2.ZERO, t.size)), who + ": 표 안")
			for k in ["name", "now", "arrow", "after", "delta"]:
				check(_inside(c[k], c["line"]), "%s: %s 이 줄 안" % [who, k])
			var order := ["name", "now", "arrow", "after", "delta"]
			for q in order.size() - 1:
				check((c[order[q]] as Rect2).end.x <= (c[order[q + 1]] as Rect2).position.x + 0.01, "%s: %s 다음 %s" % [who, order[q], order[q + 1]])
			check(font.get_string_size(l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.NAME_FS).x <= (c["name"] as Rect2).size.x + 0.5, who + ": 이름")
			check(font.get_string_size(str(l["after"]), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (c["after"] as Rect2).size.x + 0.5, who + ": 바꾸면 값")
			check(font.get_string_size(EquipTotals.delta_text(l), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (c["delta"] as Rect2).size.x + 0.5, who + ": 차이")
			if j > 0 and j != BattleLimits.GEAR.size():
				check((t.line_layout(j - 1)["line"] as Rect2).end.y <= (c["line"] as Rect2).position.y + 0.01, who + ": 위 줄과 겹치지 않는다")
		check((t.line_layout(0)["line"] as Rect2).end.x <= (t.line_layout(BattleLimits.GEAR.size())["line"] as Rect2).position.x, tag + ": 두 묶음이 나란히")


# ---- U7 지도 모눈·좌표 ----

func _check_labels(map: MapPanel, tag: String) -> Dictionary:
	var font := map.get_theme_default_font()
	var out := {}
	for vertical in [false, true]:
		var labels: Array[Dictionary] = map.row_labels() if vertical else map.column_labels()
		var kind := "행" if vertical else "열"
		check(not labels.is_empty(), "%s: %s 머리가 보인다" % [tag, kind])
		var prev := Rect2()
		for j in labels.size():
			var l := labels[j]
			var i: int = l["index"]
			var r: Rect2 = l["rect"]
			var who := "%s %s %s" % [tag, kind, l["text"]]
			check(i >= 0 and i < (map.geo.height if vertical else map.geo.width), who + ": 층 칸 번호 안")
			check_eq(l["text"], MapPanel.row_name(i) if vertical else MapPanel.column_name(i), who + ": 이름 = 칸 번호")
			var cell := map.geo.cell_rect(Vector2i(0, i) if vertical else Vector2i(i, 0)).get_center()
			check(font.get_string_size(l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MapPanel.HEAD_FS).x <= r.size.x, who + ": 글자 폭")
			check(font.get_height(MapPanel.HEAD_FS) * 0.8 <= r.size.y + 0.01, who + ": 글자 높이")
			if vertical:
				check(absf(r.get_center().y - cell.y) < 0.01, who + ": 그 행 가운데")
				check(r.position.x >= 0.0 and r.end.x <= MapPanel.HEAD_W + 0.01 and r.position.y >= MapPanel.HEAD_H - 0.01 and r.end.y <= map.size.y + 0.01, who + ": 왼쪽 띠 안")
			else:
				check(absf(r.get_center().x - cell.x) < 0.01, who + ": 그 열 가운데")
				check(r.position.y >= -0.01 and r.end.y <= MapPanel.HEAD_H + 0.01 and r.position.x >= MapPanel.HEAD_W - 0.01 and r.end.x <= map.size.x + 0.01, who + ": 위 띠 안")
			if j > 0:
				check(not prev.intersects(r), who + ": 앞 머리와 겹치지 않는다")
			prev = r
			out["%s%d" % [kind, i]] = r.get_center()
	return out


func test_map_headers_follow_cells_at_every_zoom_and_pan() -> void:
	_kit()
	var s := await kit.open("native", 7)
	var map := s.map
	await kit.frames(2)
	var base := _check_labels(map, "기본")
	check_eq(map.header_step(false), 1, "기본 확대: 열 머리 모두")
	var at := s.state.party.at
	check(base.has("열%d" % at.x) and absf((base["열%d" % at.x] as Vector2).x - map.cell_point(at).x) < 0.01, "파티 열의 머리 = 파티 칸 가운데")
	check(base.has("행%d" % at.y) and absf((base["행%d" % at.y] as Vector2).y - map.cell_point(at).y) < 0.01, "파티 행의 머리 = 파티 칸 가운데")
	# 끌어 옮기면 같은 칸의 머리가 같은 만큼 따라간다
	map.follow = false
	map.geo.pan(Vector2(37, -23))
	map.queue_redraw()
	var moved := _check_labels(map, "옮김")
	var same := 0
	for k in base:
		if moved.has(k):
			same += 1
			var d: Vector2 = moved[k] - base[k]
			check(absf(d.x - (37.0 if k.begins_with("열") else 0.0)) < 0.01 and absf(d.y - (-23.0 if k.begins_with("행") else 0.0)) < 0.01, "%s: 옮긴 만큼 따라간다(%s)" % [k, str(d)])
	check(same > 4, "같이 보이는 머리 %d개" % same)
	map.to_party()
	map.zoom(10.0)
	check_eq(map.geo.cell_px, MapGeometry.MAX_CELL_PX, "준비: 가장 크게")
	_check_labels(map, "가장 크게")
	map.zoom(0.01)
	check_eq(map.geo.cell_px, MapGeometry.MIN_CELL_PX, "준비: 가장 작게")
	_check_labels(map, "가장 작게")
	check(map.header_step(false) > 1, "가장 작게: 열 머리를 솎는다(%d칸마다)" % map.header_step(false))
	check(map.header_step(true) > 1, "가장 작게: 행 머리를 솎는다(%d칸마다)" % map.header_step(true))


## 여러 글자 열 이름(AA…·AAA…)이 있는 층 폭을 확대 중간값마다 본다: 보이는 열 머리가 서로(좌우 2px 여백 포함) 겹치지 않는다.
## 지도 패널만 따로 띄우고 geo 를 직접 둔다(층 그림은 없다: 머리 자리만 본다).
func test_map_headers_never_overlap_with_multi_letter_columns() -> void:
	var map := MapPanel.new()
	map.size = Vector2(496, 360)
	tree.root.add_child(map)
	var font := map.get_theme_default_font()
	# 이 층(35열, 끝 「AI」)은 셀 15px 에서 「AG」「AH」가 마지막 열보다 넓다: 가장 넓은 이름으로 솎아야 한다.
	map.geo.width = 35
	map.geo.height = 12
	map.geo.cell_px = 15.0
	var widest := 0.0
	for i in 35:
		widest = maxf(widest, font.get_string_size(MapPanel.column_name(i), HORIZONTAL_ALIGNMENT_LEFT, -1, MapPanel.HEAD_FS).x)
	var last := font.get_string_size(MapPanel.column_name(34), HORIZONTAL_ALIGNMENT_LEFT, -1, MapPanel.HEAD_FS).x
	check(widest > last + 2.0, "준비: 가장 넓은 열 이름(%.1f)이 마지막 「AI」(%.1f)보다 넓다" % [widest, last])
	check_eq(map.header_need(false), widest + 4.0, "열 머리 폭 = 가장 넓은 이름 + 여백")
	check(map.header_step(false) * 15.0 >= widest + 4.0, "15px 칸: %d칸마다" % map.header_step(false))
	var cases := 0
	for width in [20, 35, 60, 730]:
		map.geo.width = width
		map.geo.height = 12
		for px in [10.0, 12.0, 14.0, 15.0, 16.0, 18.0, 21.0, 24.0, 30.0, 40.0, 72.0]:
			map.geo.cell_px = px
			# 왼쪽 끝(A…)·두 글자 시작(AA…)·끝(마지막 열)이 보이게 세 곳으로 옮겨 본다.
			for from in [0, 26, width - 1]:
				if from >= width:
					continue
				map.geo.origin = Vector2(MapPanel.HEAD_W + 2.0 - from * px, MapPanel.HEAD_H)
				if from == width - 1:
					map.geo.origin.x = map.size.x - width * px
				var labels := map.column_labels()
				var tag := "%d열 %.0fpx %s부터" % [width, px, MapPanel.column_name(from)]
				var k := map.header_step(false)
				if k > 0:
					check(not labels.is_empty(), tag + ": 머리가 보인다")
				for j in labels.size():
					var r: Rect2 = labels[j]["rect"]
					var tw := font.get_string_size(labels[j]["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MapPanel.HEAD_FS).x
					check(tw + 4.0 <= r.size.x + 0.01, "%s %s: 글자 + 여백" % [tag, labels[j]["text"]])
					if j > 0:
						var p: Rect2 = labels[j - 1]["rect"]
						check(p.end.x <= r.position.x + 0.01, "%s: %s 와 %s 가 겹치지 않는다(%.1f > %.1f)" % [tag, labels[j - 1]["text"], labels[j]["text"], p.end.x, r.position.x])
						check_eq(int(labels[j]["index"]) - int(labels[j - 1]["index"]), k, tag + ": 같은 간격으로 솎는다")
				cases += 1
	check(cases > 100, "본 경우 %d" % cases)
	tree.root.remove_child(map)
	map.free()


func test_map_marks_draw_above_headers_and_grid_is_dimmer_outside() -> void:
	var order := MapPanel.LAYERS
	var head := order.find("headers")
	check(head >= 0, "머리 층이 있다")
	for mark in ["floors", "edges", "icons", "memos", "party"]:
		check(order.find(mark) > head, "%s 는 머리 위에 그린다(머리가 덮지 않는다)" % mark)
	for under in ["blueprint", "grid"]:
		check(order.find(under) < head, "%s 는 머리 아래" % under)
	check_eq(order[order.size() - 1], "party", "파티 표시는 맨 위")
	check(MapPanel.GRID_OUT.a < MapPanel.GRID.a and MapPanel.GRID_MAJOR_OUT.a < MapPanel.GRID_MAJOR_IN.a, "층 밖 모눈은 더 흐리다")
	check(_lum(MapPanel.FLOOR_BG) > _lum(MapPanel.BG), "층 칸 안 바탕이 밖보다 밝다")
	# 머리 띠는 반투명: 그 아래에 올 수 있는 가장 밝은 것(층 칸 바탕 위의 굵은 모눈선) 위에 겹친 색과 견준다.
	var under := MapPanel.FLOOR_BG.lerp(Color(MapPanel.GRID_MAJOR_IN, 1.0), MapPanel.GRID_MAJOR_IN.a)
	var band := under.lerp(Color(MapPanel.HEAD_BG, 1.0), MapPanel.HEAD_BG.a)
	check(contrast(MapPanel.HEAD_TEXT, band) >= 4.5, "머리 글자 대비 %.1f(겹친 바탕)" % contrast(MapPanel.HEAD_TEXT, band))


func test_map_header_names_and_glyphs() -> void:
	var cases := [[0, "A"], [1, "B"], [19, "T"], [25, "Z"], [26, "AA"], [27, "AB"], [51, "AZ"], [52, "BA"], [701, "ZZ"], [702, "AAA"]]
	for c in cases:
		check_eq(MapPanel.column_name(c[0]), c[1], "열 %d" % c[0])
	check_eq(MapPanel.row_name(0), "1", "행 0 → 1")
	check_eq(MapPanel.row_name(19), "20", "행 19 → 20")
	var font := load(str(ProjectSettings.get_setting("gui/theme/custom_font"))) as Font
	var missing := {}
	for i in 100:
		for t in [MapPanel.column_name(i), MapPanel.row_name(i)]:
			for j in t.length():
				if not font.has_char(t.unicode_at(j)):
					missing[t[j]] = true
	check(missing.is_empty(), "좌표 글자가 글꼴에 있다: 없는 글자 %s" % str(missing.keys()))


## WCAG 상대 휘도 대비.
static func contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


# ---- U6 공용 창·단추 모양 ----

func test_theme_text_pairs_meet_contrast_on_every_fill() -> void:
	for st in UiTheme.STATES + ["window"]:
		var lk := UiTheme.look(st)
		check(lk["fill"], "%s: 채움" % st)
		check(lk["top"].a == 1.0 and lk["bottom"].a == 1.0, "%s: 불투명 채움(뒤에 무엇이 있어도 대비 그대로)" % st)
		for role in UiTheme.TEXT_ROLES:
			var c := minf(contrast(lk["top"], lk[role]), contrast(lk["bottom"], lk[role]))
			check(c >= 4.5, "%s %s 글자 대비 %.2f" % [st, role, c])
	# 창 위에 직접 쓰는 글자색(공용 창 채움 위·아래 모두)
	var win := UiTheme.look("window")
	var on_window := {"HEAD_TEXT": UiTheme.HEAD_TEXT, "TEXT": UiTheme.TEXT, "SUB_TEXT": UiTheme.SUB_TEXT, "ACCENT_TEXT": UiTheme.ACCENT_TEXT,
		"합계 이름": EquipTotals.NAME_COLOR, "합계 값": EquipTotals.VALUE_COLOR, "합계 오름": EquipTotals.UP_COLOR, "합계 내림": EquipTotals.DOWN_COLOR,
		"상태 TP 값": StatusPanel.TP_TEXT, "상태 전투 불능": StatusPanel.DOWN_TEXT}
	for k in on_window:
		var c := minf(contrast(win["top"], on_window[k]), contrast(win["bottom"], on_window[k]))
		check(c >= 4.5, "창 위 %s 대비 %.2f" % [k, c])
	# 못 누르는 단추의 focus 상자는 채움이 없다: 글자는 못 누름 채움 위
	var df := UiTheme.look("disabled_focus")
	check(not df["fill"] and df["inner_w"] == 0.0, "못 누름 + 포커스: 채움·안쪽 선 없음")


func test_theme_states_and_non_colour_cues() -> void:
	var cases := [[[false, false], "normal"], [[true, false], "pressed"], [[false, true], "selected"], [[true, true], "selected_pressed"],
		[[false, false, true], "checked"], [[true, false, true], "checked_pressed"], [[false, true, true], "selected"],
		[[false, false, false, true], "disabled"], [[true, true, false, true], "disabled_selected"],
		[[false, true, false, false, true], "marked"], [[true, true, false, false, true], "marked_pressed"],
		[[false, false, true, false, true], "checked_marked"], [[false, false, false, false, true], "normal"]]
	for c in cases:
		var a: Array = c[0]
		var got := UiTheme.state_of(a[0], a[1], a[2] if a.size() > 2 else false, a[3] if a.size() > 3 else false, a[4] if a.size() > 4 else false)
		check_eq(got, c[1], "state_of %s" % str(a))
	var normal := UiTheme.look("normal")
	var warm := func(c: Color) -> bool: return c.r > 0.9 and c.g > 0.7 and c.b < c.g - 0.25
	for st in ["selected", "selected_pressed"]:
		var lk := UiTheme.look(st)
		check(warm.call(lk["top"]) and warm.call(lk["bottom"]) and lk["text"].get_luminance() < 0.2, "%s: 따뜻한 채움 + 어두운 글자" % st)
	for st in ["selected", "selected_pressed", "marked", "marked_pressed", "disabled_selected", "checked_marked", "checked_marked_pressed"]:
		var lk := UiTheme.look(st)
		check(lk["outer_w"] > normal["outer_w"] and (lk["marker"] as Color).a > 0.0, "%s: 색 말고도 굵은 테두리 + 표시 막대" % st)
	for st in ["marked", "checked_marked"]:
		var lk := UiTheme.look(st)
		check(lk["top"] == normal["top"] and lk["bottom"] == normal["bottom"], "%s: 채움은 평소 그대로(안의 색이 보인다)" % st)
	check(UiTheme.look("disabled_selected")["bottom"] == UiTheme.look("disabled")["bottom"] and warm.call(UiTheme.look("disabled_selected")["outer"]),
		"못 누름 + 커서: 채움은 못 누름 그대로, 따뜻한 테두리")
	check(UiTheme.look("checked")["bottom"] == UiTheme.BTN_CHECKED and not warm.call(UiTheme.look("checked")["bottom"]), "켜짐: 청록 채움(고른 것과 다르다)")
	var win := UiTheme.look("window")
	check(win["outer"].get_luminance() < 0.05 and win["inner"].get_luminance() > 0.5 and win["inner_w"] > 0.0, "창: 어두운 바깥 + 밝은 안쪽 선")
	check(win["top"] != win["bottom"] and win["top"].g > win["bottom"].g and win["bottom"].b >= win["bottom"].g, "창: 위 청록 → 아래 남색")
	check(win["chamfer"] > 0.0 and normal["chamfer"] > 0.0, "모서리를 깎는다")
	var pts := UiTheme.chamfer_points(Rect2(0, 0, 100, 50), 10)
	check_eq(pts.size(), 8, "깎은 모서리 팔각형")
	check(not pts.has(Vector2(0, 0)) and pts.has(Vector2(10, 0)) and pts.has(Vector2(0, 10)), "모서리 점 대신 깎은 두 점")


func test_widgets_use_theme_states() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	# 지도 도구: 색 견본은 고르면 테두리만, 다른 도구는 따뜻한 채움
	s.map.tool = "color"
	s.map.paint_color = 2
	s._refresh_toolbar()
	await kit.frames(1)
	var sw: TouchButton = s.toolbar.buttons["color2"]
	check(sw != null and sw.selected and sw.theme_state() == "marked", "고른 색 견본: marked(%s)" % (sw.theme_state() if sw != null else "-"))
	s.map.tool = "wall"
	s._refresh_toolbar()
	await kit.frames(1)
	var wall: TouchButton = s.toolbar.buttons["wall"]
	check(wall != null and wall.theme_state() == "selected", "고른 벽 도구: selected")
	check(sw.theme_state() == "normal", "고르지 않은 견본: normal")
	# 파티 메뉴: 지금 탭 = 켜짐, 지금 대원 = 켜짐 테두리, 목록이 열린 칸 = 켜짐, 목록 커서 = 고름
	var et := await _equip_tab(s)
	var pm := s.party_menu
	check_eq(pm.tab_buttons[2].theme_state(), "checked", "지금 탭")
	check_eq(pm.tab_buttons[0].theme_state(), "normal", "다른 탭")
	check_eq(pm.cells[pm.member].theme_state(), "checked_marked", "지금 대원 칸")
	check_eq(et.slot_rows[0].theme_state(), "selected", "목록 닫힘: 칸 커서")
	await kit.press_key(KEY_ENTER)
	check_eq(et.slot_rows[0].theme_state(), "checked", "목록이 열린 칸")
	check_eq(et.rows[0].theme_state(), "selected", "목록 커서 줄")
	await kit.press_key(KEY_ESCAPE)
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check(not et.row_block[0].is_empty(), "준비: 못 고르는 줄")
	check_eq(et.rows[0].theme_state(), "disabled_selected", "못 고르는 줄에 커서")
	for k in 3:
		if pm.is_open():
			await kit.press_key(KEY_ESCAPE)
	# 전투 명령: 커서 = 고름
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for k in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	check(s.battle_layer.is_open(), "준비: 전투")
	await kit.frames(3)
	var cp := s.battle_layer.panel
	check_eq(cp.command_buttons[0].theme_state(), "selected", "명령 커서")
	check_eq(cp.command_buttons[1].theme_state(), "normal", "다른 명령")


func test_no_stylebox_flat_outside_theme() -> void:
	# 허용 목록: 없음(작은 면 채움도 UiTheme.fill_round 를 쓴다).
	const ALLOW := []
	var found := []
	var dirs := ["res://src"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"):
				continue
			var path := d + "/" + f
			if path == (UiTheme as Script).resource_path or ALLOW.has(path):
				continue
			if FileAccess.get_file_as_string(path).contains("StyleBoxFlat"):
				found.append(path)
	check(found.is_empty(), "UiTheme 밖에서 StyleBoxFlat: %s" % str(found))
	check(FileAccess.get_file_as_string((ModalLayer as Script).resource_path).find("const BTN_") < 0, "창 단추 색을 따로 두지 않는다(UiTheme)")


func test_result_window_heads_differ_from_lines() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	s.import_text(FileAccess.get_file_as_string("res://tools/web_check_victory_save.json"))
	await kit.frames(3)
	for i in s.state.party.members.size():
		s.state.party.members[i].exp = s.state.defs.battle.growth.cum(2) - 4
	s.state.battle.party[3].hp = 0  # 전투 불능 하나: 대원마다 줄
	s._on_debug_request(JSON.stringify({"op": "battle_finish"}))
	await kit.frames(4)
	var bl := s.battle_layer
	if bl.phase == "anim":
		await kit.press_key(KEY_ENTER)
	check_eq(bl.phase, "result", "준비: 결과 창")
	var lines := bl.result_lines
	var kinds := bl.result_kinds
	check_eq(kinds.size(), lines.size(), "줄마다 종류")
	var heads := [texts.t("battle.result.drops"), texts.t("battle.result.exp_head"), texts.t("battle.result.level_up_head")]
	var seen_heads := 0
	for i in lines.size():
		var is_head := heads.has(lines[i])
		check_eq(kinds[i] == "head", is_head, "「%s」 종류 %s" % [lines[i], kinds[i]])
		if is_head:
			seen_heads += 1
			check(i + 1 < lines.size() and kinds[i + 1] == "item", "「%s」 아래에 줄" % lines[i])
	check(seen_heads >= 2, "머리 줄이 보인다(%d): %s" % [seen_heads, str(lines)])
	check(BattleLayer.RESULT_HEAD_FS > BattleLayer.RESULT_FS and UiTheme.HEAD_TEXT != UiTheme.TEXT, "머리: 더 큰 글자 + 다른 색")
	var bb: String = bl._result_body.text
	var head_tag := "[font_size=%d][color=#%s]" % [BattleLayer.RESULT_HEAD_FS, UiTheme.HEAD_TEXT.to_html(false)]
	for i in lines.size():
		var tagged := bb.contains(head_tag + lines[i] + "[/color]")
		check_eq(tagged, kinds[i] == "head", "「%s」 본문 꾸밈" % lines[i])
	var body_h: float = bl._result_body.get_content_height()
	check(body_h > 0.0, "본문 높이 %.0f" % body_h)
	check(bl._result_body.size.y >= body_h - 0.5, "본문이 잘리지 않는다(%.0f ≥ %.0f)" % [bl._result_body.size.y, body_h])
