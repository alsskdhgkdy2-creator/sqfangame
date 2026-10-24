## M2.6 UI 다듬기 2단계(00 D20 ②, docs/research/03 U6~U9) 시험: 공용 창 모양, 지도 모눈·좌표, 장비 합계 표,
## 탐색 상태 칸 TP. 저장은 장면 시험 임시 폴더에만 쓴다. 결과는 구성으로 정한다(D15).
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const SIZES := [Vector2(1280, 720), Vector2(2400, 1000)]
## 상태 칸 부품의 두 폭(M2.6 의 탐색 배치에서 쓰던 넓은 꼴 = 화면 40%, 좁은 꼴 300)과 높이.
## 탐색 화면에는 이제 상태 칸이 없고(M2.7 R1) 캠프·전투에서 다시 쓸 부품으로 시험한다.
const STATUS_WIDE := 0.4
const STATUS_NARROW := 300.0
const STATUS_H := 190.0

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


## 탐색 화면 아래에 붙인 상태 칸 부품(화면 상태·글을 그대로 쓴다). 화면이 지울 때 함께 지워진다.
func _status_panel(s: DungeonScreen) -> StatusPanel:
	var st := StatusPanel.new()
	st.name = "TestStatusPanel"
	st.set_state(s.state, s.texts, s._member_names.duplicate())
	s.add_child(st)
	return st


func _check_status_rows(s: DungeonScreen, st: StatusPanel, tag: String) -> bool:
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
	var st := _status_panel(s)
	for values in ["레벨 1", "최대"]:
		if values == "최대":
			_max_party(s)
			check_eq(s.state.party.members[0].level, 30, "준비: 레벨 30")
			check(s.state.party.members.any(func(m: PartyState.Member) -> bool: return m.max_hp >= 100 and m.max_tp >= 100), "준비: 세 자리 HP·TP")
		for sz in SIZES:
			for open in [true, false]:
				await _resize(s, sz)
				st.size = Vector2(roundf(s.size.x * STATUS_WIDE) if open else STATUS_NARROW, STATUS_H)
				st.refresh()
				var tag := "%s %dx%d %s" % [values, sz.x, sz.y, "넓은 꼴" if open else "좁은 꼴"]
				for names in [party_names, class_names]:
					st.member_names.assign(names)
					var compact := _check_status_rows(s, st, "%s %s" % [tag, "대원 이름" if names == party_names else "직업 이름"])
					if compact:
						compact_seen += 1
					if open:
						check(not compact, tag + ": 넓은 폭이면 넓은 꼴")
				st.member_names.assign(party_names)
	check(compact_seen >= 2, "좁은 꼴(값 쌓기)도 보았다(%d)" % compact_seen)
	check_eq(UiTheme.TP_BAR, Color(0.4, 0.65, 1.0), "TP 색(파티 메뉴·상태 칸)")
	check(_source(StatusPanel).contains("UiTheme.TP_BAR"), "탐색 상태 칸: 같은 TP 색 상수를 쓴다")
	# M2.7 R3·R2: 전투 카드는 원작 색(시안 TP 막대 UiTheme.CARD_TP)이고 캠프 대원 카드도 같은 부품(PartyCards/BattleCard)이다.
	check(_source(BattleCard).contains("UiTheme.CARD_TP") and not _source(BattleCard).contains("UiTheme.TP_BAR"), "전투 카드 TP 막대 = CARD_TP")
	check(_source(PartyMenu).contains("PartyCards.new()"), "캠프 대원 카드 = 전투 카드 부품")


# ---- U8 장비 합계 표 ----

## 이온 세이버 하나를 가방에 넣고 캠프 → 장비 → 듀얼리스트 A.
func _equip_tab(s: DungeonScreen) -> PartyEquipTab:
	s._on_debug_request(JSON.stringify({"op": "supply", "item": "equip.ion_saber", "n": 1}))
	await kit.press_key(KEY_P)
	await kit.press_key(KEY_3)
	await kit.press_key(KEY_RIGHT)  # 캠프 대원 고르기: 듀얼리스트 A
	await kit.press_key(KEY_ENTER)
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


## 인물 판의 능력치 묶음(원작 상점 인물 판의 STR~LUC 열 + 攻撃·防御 판): 두 크기에서 판 안, 다른 판 부품·목록과 겹치지 않고, 글자가 칸에 든다.
func test_equip_totals_fit_in_the_character_panel_at_both_sizes() -> void:
	_kit()
	var s := await kit.open("native", 7, "debug=1")
	var et := await _equip_tab(s)
	await kit.press_key(KEY_ENTER)
	await kit.press_key(KEY_DOWN)
	var t := et.totals
	var panel := et.frame.panel
	var font := t.get_theme_default_font()
	for sz in SIZES:
		await _resize(s, sz)
		var tag := "%dx%d" % [sz.x, sz.y]
		check(t.comparing, tag + ": 준비: 견주는 중")
		var tr := t.get_global_rect()
		var pr := panel.get_global_rect()
		check(_inside(tr, pr) and _inside(pr, et.menu.get_global_rect()), "%s: 판 안·캠프 안 %s %s" % [tag, str(tr), str(pr)])
		check_eq(t.size, EquipTotals.needed_size(), tag + ": 줄이 다 들어가는 크기")
		var cp := Rect2(pr.position + panel.class_rect().position, panel.class_rect().size)
		check(tr.position.y >= cp.end.y and tr.end.y <= pr.position.y + panel.equip_rect(0).position.y, tag + ": 직업 문패와 장비 줄 사이")
		check(not et.list.get_global_rect().intersects(tr), tag + ": 목록과 겹치지 않는다")
		for j in t.lines.size():
			var l := t.lines[j]
			var c := t.line_layout(j)
			var who := "%s %s" % [tag, l["key"]]
			check(_inside(c["line"], Rect2(Vector2.ZERO, t.size)), who + ": 묶음 안")
			for k in ["box", "name", "now", "arrow", "after", "delta"]:
				check(_inside(c[k], c["line"]), "%s: %s 이 줄 안" % [who, k])
			var order := ["name", "now", "arrow", "after", "delta"]
			for q in order.size() - 1:
				check((c[order[q]] as Rect2).end.x <= (c[order[q + 1]] as Rect2).position.x + 0.01, "%s: %s 다음 %s" % [who, order[q], order[q + 1]])
			check(font.get_string_size(l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.NAME_FS).x <= (c["name"] as Rect2).size.x + 0.5, who + ": 이름")
			check(font.get_string_size(str(l["after"]), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (c["after"] as Rect2).size.x + 0.5, who + ": 바꾸면 값")
			check(font.get_string_size(EquipTotals.delta_text(l), HORIZONTAL_ALIGNMENT_LEFT, -1, EquipTotals.VALUE_FS).x <= (c["delta"] as Rect2).size.x + 0.5, who + ": 차이")
			for q in range(j + 1, t.lines.size()):
				check(not (c["line"] as Rect2).intersects(t.line_layout(q)["line"]), "%s: %s 와 겹치지 않는다" % [who, t.lines[q]["key"]])
		# 원작 짜임: 능력치(힘~행운)가 한 열로 위, 공격·방어 판이 그 아래 2×2.
		var last_stat: Rect2 = t.line_layout(t.lines.size() - 1)["line"]
		for g in BattleLimits.GEAR.size():
			check((t.line_layout(g)["line"] as Rect2).position.y >= last_stat.end.y, tag + ": 공격·방어 판은 능력치 열 아래")
		check((t.line_layout(0)["line"] as Rect2).end.x <= (t.line_layout(1)["line"] as Rect2).position.x, tag + ": 공격 | 마법 공격 나란히")


# ---- U7 지도 모눈·구역 자 (M2.7 R1: 원작 HD 처럼 자는 층 전체 보기에만, 5×5 칸 구역마다 하나) ----

func test_overview_sector_ruler_matches_major_grid() -> void:
	_kit()
	var s := await kit.open("native", 7)
	await kit.open_map()
	var ov := s.map_window.overview
	check(ov.is_visible_in_tree(), "준비: 층 전체 보기")
	var font := ov.get_theme_default_font()
	var w := s.state.floor_def.width
	var h := s.state.floor_def.height
	for vertical in [false, true]:
		var labels := ov.sector_labels(vertical)
		var n := h if vertical else w
		check_eq(labels.size(), ceili(float(n) / MapPanel.GRID_MAJOR), "%s 구역 수" % ("세로" if vertical else "가로"))
		for l in labels:
			var i: int = l["index"]
			var r: Rect2 = l["rect"]
			var who := "%s 구역 %s" % ["세로" if vertical else "가로", l["text"]]
			check_eq(l["text"], MapOverview.sector_name(i, vertical), who + ": 이름")
			# 자 칸의 양 끝 = 밝은 5칸 모눈 선(구역 경계)
			var a := ov.geo.to_screen(Vector2(0, i * MapPanel.GRID_MAJOR) if vertical else Vector2(i * MapPanel.GRID_MAJOR, 0))
			check(absf((r.position.y if vertical else r.position.x) - (a.y if vertical else a.x)) < 0.01, who + ": 구역 시작 선에 맞춘다")
			check(font.get_string_size(l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, MapOverview.RULER_FS).x <= (r.size.y if vertical else r.size.x), who + ": 글자가 칸 안")
			check(Rect2(Vector2.ZERO, ov.size).grow(0.01).encloses(r), who + ": 보기 안")
	check_eq([MapOverview.sector_name(0, false), MapOverview.sector_name(3, false)], ["1", "4"], "가로는 번호")
	check_eq([MapOverview.sector_name(0, true), MapOverview.sector_name(3, true), MapOverview.sector_name(26, true)], ["A", "D", "AA"], "세로는 글자")
	check(contrast(MapOverview.RULER_TEXT, MapOverview.RULER_BG) >= 4.5, "자 글자 대비 %.1f" % contrast(MapOverview.RULER_TEXT, MapOverview.RULER_BG))
	check(contrast(UiTheme.TEXT, MapPanel.BG) >= 4.5, "층 문패(도구 열) 글자 대비 %.1f" % contrast(UiTheme.TEXT, MapPanel.BG))
	# 원작 색(nin_02): 도구 열 단추는 파란 모양, 고른 도구는 공용 따뜻한 커서, 「돌아가기」는 밝은 알약
	var wall: TouchButton = s.toolbar.buttons["wall"]
	s._choose_tool("door", 0)
	check_eq(wall.theme_state(), "tool:normal", "고르지 않은 도구: 파란 도구 칸")
	s._choose_tool("wall", 0)
	check_eq(wall.theme_state(), "selected", "고른 도구: 따뜻한 커서")
	check_eq(s.map_window.back_button.theme_state(), "pill:normal", "「돌아가기」: 밝은 알약")
	check(MapPanel.FLOOR_COLORS.slice(1).all(func(c: Color) -> bool: return absf(c.h - MapPanel.FLOOR_COLORS[0].h) > 0.06 or absf(c.v - MapPanel.FLOOR_COLORS[0].v) > 0.25), "플레이어 바닥 색 1~4 는 자동 파랑과 다르다")
	# 층 전체가 보기 안에 들어온다
	var fr := ov.floor_rect()
	check(ov.map_area().grow(0.01).encloses(fr), "층 전체가 보인다 %s ⊂ %s" % [str(fr), str(ov.map_area())])
	# 그리기 격자의 보이는 범위(점선 사각형)는 그리기 격자를 옮기면 따라간다
	var v0 := ov.view_rect()
	check(v0.size.x > 0.0 and v0.size.y > 0.0, "보이는 범위 사각형")
	s.map.follow = false
	s.map.geo.pan(Vector2(-s.map.geo.cell_px * 3.0, 0))
	var v1 := ov.view_rect()
	check(absf(v1.position.x - v0.position.x - 3.0 * ov.geo.cell_px) < 0.01, "그리기 격자를 오른쪽으로 세 칸 옮기면 범위도 세 칸")
	check(MapPanel.LAYERS.find("headers") < 0, "그리기 격자에는 좌표 자가 없다")


func test_map_marks_order_and_grid_is_dimmer_outside() -> void:
	var order := MapPanel.LAYERS
	for under in ["blueprint", "grid"]:
		check(order.find(under) < order.find("floors"), "%s 는 지도 표시 아래" % under)
	check_eq(order[order.size() - 1], "party", "파티 표시는 맨 위")
	check(MapPanel.GRID_OUT.a < MapPanel.GRID.a and MapPanel.GRID_MAJOR_OUT.a < MapPanel.GRID_MAJOR_IN.a, "층 밖 모눈은 더 흐리다")
	check(_lum(MapPanel.FLOOR_BG) > _lum(MapPanel.BG), "층 칸 안 바탕이 밖보다 밝다")


func test_sector_ruler_glyphs_are_in_the_font() -> void:
	var font := load(str(ProjectSettings.get_setting("gui/theme/custom_font"))) as Font
	var missing := {}
	for i in 60:
		for t in [MapOverview.sector_name(i, false), MapOverview.sector_name(i, true)]:
			for j in t.length():
				if not font.has_char(t.unicode_at(j)):
					missing[t[j]] = true
	check(missing.is_empty(), "자 글자가 글꼴에 있다: 없는 글자 %s" % str(missing.keys()))


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
	for st in UiTheme.STATES + ["window"] + UiTheme.SKIN_LOOKS:
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
	# 캠프 장비(상점 짜임, 시설 「fac:*」 모양): 칸 커서 = 고름, 목록이 열린 칸 = 인물 판 장비 줄 노랑 테두리, 목록 커서 = 고름
	var et := await _equip_tab(s)
	var pm := s.party_menu
	check_eq(et.slot_rows[0].theme_state(), "fac:selected", "목록 닫힘: 칸 커서")
	check_eq(et.slot_rows[1].theme_state(), "fac:normal", "목록 닫힘: 다른 칸")
	await kit.press_key(KEY_ENTER)
	check_eq(et.frame.panel.drawn["mark"], 0, "목록이 열린 칸 = 판의 장비 줄 표시")
	check_eq(et.rows[0].theme_state(), "fac:selected", "목록 커서 줄")
	await kit.press_key(KEY_ESCAPE)
	for k in 3:
		await kit.press_key(KEY_DOWN)
	await kit.press_key(KEY_ENTER)
	check(not et.row_block[0].is_empty(), "준비: 못 고르는 줄")
	check_eq(et.rows[0].theme_state(), "fac:disabled_selected", "못 고르는 줄에 커서")
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
	check_eq(cp.command_buttons[0].theme_state(), "cmd:selected", "명령 커서(원작 명령 목록 모양)")
	check_eq(cp.command_buttons[1].theme_state(), "cmd:normal", "다른 명령")


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
