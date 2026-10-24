## M2.7 R1 화면 위에 뜨는 UI(research 05 §1.2·§2.2) 시험: 3D 시야는 어느 모드에서도 화면 전체이고, HUD·창은 CanvasLayer 의
## 화면 전체 뿌리(IGNORE) 안에 앵커로 붙는다. 지도 판은 오른쪽을 덮고 렌즈를 밀어 소실점을 덮이지 않은 영역 가운데로 옮긴다.
## 창 크기는 실제 창(1280×720, 2400×1000)으로 바꿔 늘이기 규칙(논리 1280×720, 1728×720)까지 그대로 본다.
## 저장은 장면 시험 임시 폴더에만 쓴다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
## 겹침 누르기에 쓰는 손가락 번호(0 이 아니면 흉내 마우스가 생기지 않는다).
const FINGER := 3

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


func _open() -> DungeonScreen:
	timeout_sec = 90.0
	kit = Kit.new(tree)
	return await kit.open("native", 7, "debug=1")


## 실제 창 크기를 바꾸고 논리 크기를 돌려준다(2400×1000 → 1728×720).
func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


static func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


static func _under(c: Node, n: Node) -> bool:
	return n != null and (c == n or c.is_ancestor_of(n))


static func _name_of(c: Control) -> String:
	return "없음" if c == null else str(c.get_path())


## 논리 좌표 p 를 손가락으로 누를 때 처음 받는 컨트롤(엔진이 실제로 고르는 것, test_ui_relayout 과 같은 방법:
## 헤드리스에서는 hover 가 없어 gui_input 기록으로 본다). 뗄 때는 창 밖에서 떼어 받은 단추가 일을 하지 않게 한다.
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
	var win := tree.root.get_final_transform() * p
	kit.touch(FINGER, win, true)
	kit.touch(FINGER, Vector2(-500, -500), false)
	await kit.frames(1)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Control).gui_input.is_connected(h[1]):
			(h[0] as Control).gui_input.disconnect(h[1])
	return got[0] if not got.is_empty() else null


func _set_map(s: DungeonScreen, open: bool) -> void:
	if s._map_open != open:
		s._toggle_map()
	await kit.frames(3)


## 소실점(앞 방향 먼 점)의 화면 x(논리 px).
static func _vanishing_x(s: DungeonScreen) -> float:
	var cam := s.view.camera()
	var fwd := -cam.global_transform.basis.z
	var sv := s.view_container.get_child(0) as SubViewport
	var px := cam.unproject_position(cam.global_position + fwd * 60.0).x
	return px * s.view_container.size.x / float(sv.size.x)


func _walk_into_battle(s: DungeonScreen) -> void:
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for k in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	await kit.frames(3)


# ---- 층 짜임 ----

func test_layers_are_canvas_layers_with_full_rect_ignore_roots() -> void:
	var s := await _open()
	check_eq([s.layers["Hud"].layer, s.layers["Windows"].layer, s.layers["Modal"].layer, s.layers["Toast"].layer], [1, 2, 3, 4], "층 번호")
	for root in [s.hud_root, s.windows_root, s.view_area, s.toast_area, s.hint_row, s.pad_box]:
		check_eq((root as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 는 누르기를 받지 않는다" % root.name)
	check(s.view_container.get_parent() == s and s.view_container.get_index() < s._flash.get_index(), "층 0: 시야 → 번쩍임")
	check(s.map_window.get_parent() == s.windows_root and s.battle_layer.get_parent() == s.windows_root and s.party_menu.get_parent() == s.windows_root, "창 층: 지도 판·전투 층·파티 메뉴")
	check(s.map_window.get_index() < s.battle_layer.get_index() and s.battle_layer.get_index() < s.party_menu.get_index(), "창 층 안 순서")
	check(s.modal.get_parent() == s.layers["Modal"] and _under(s.layers["Toast"], s._toast), "모달 층·알림 층")
	for c in [s.minimap, s.orb, s.floor_plate, s._flash, s._toast, s.map_window.overview, s.toolbar, s.toolbar.floor_plate]:
		check_eq((c as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "장식 %s 은 누르기를 받지 않는다" % c.name)
	for n in s.find_children("*", "CanvasItem", true, false):
		if n is Control and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			check_eq((n as CanvasItem).z_index, 0, "누르는 %s 에 z_index 없음" % n.name)
	check(s.find_children("*", "StatusPanel", true, false).is_empty(), "탐색 화면에 상태 칸이 없다")
	check(not s._map_open, "기본은 지도 닫힘")


func test_view_fills_the_screen_in_every_mode() -> void:
	var s := await _open()
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var full := Rect2(Vector2.ZERO, size)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		for root in [s.hud_root, s.windows_root, s.layers["Toast"].get_child(0), s.modal]:
			check_eq(_rect(root), full, "%s: %s 는 화면 전체" % [tag, root.name])
		check_eq(_rect(s.toast_area), _rect(s.view_area), tag + ": 알림 영역 = 덮이지 않은 시야 영역")
		await _set_map(s, false)
		check_eq(_rect(s.view_container), full, tag + " 지도 닫힘")
		await _set_map(s, true)
		check_eq(_rect(s.view_container), full, tag + " 지도 열림")
		check_eq(Vector2((s.view_container.get_child(0) as SubViewport).size), size, tag + ": 시야 해상도도 화면 전체")
		await kit.tap(kit.center_of(s.menu_button))
		check_eq(s.modal.kind, "menu", tag + ": 준비: 메뉴 창")
		check_eq(_rect(s.view_container), full, tag + " 메뉴 창")
		s.modal.close()
		await kit.frames(2)
		await kit.press_key(KEY_P)
		check(s.party_menu.is_open(), tag + ": 준비: 파티 메뉴")
		check_eq(_rect(s.view_container), full, tag + " 파티 메뉴")
		check(not s.map_window.is_visible_in_tree() and not s.hud_root.visible, tag + ": 파티 메뉴 뒤 HUD·지도 판 감춤")
		check_eq(s.view.lens_cover, 0.0, tag + ": 파티 메뉴 뒤 렌즈는 가운데")
		await kit.press_key(KEY_ESCAPE)
		await kit.frames(2)
		check(s.map_window.is_visible_in_tree(), tag + ": 닫으면 지도 판이 돌아온다")
	await _window(WINDOWS[0])
	await _walk_into_battle(s)
	check(s.battle_layer.is_open(), "준비: 전투")
	check_eq(_rect(s.view_container), Rect2(Vector2.ZERO, tree.root.get_visible_rect().size), "전투 중")
	check(not s.map_window.is_visible_in_tree() and not s.hud_root.visible, "전투 중 HUD·지도 판 감춤")
	check_eq(s.view.lens_cover, 0.0, "전투 중 렌즈는 가운데")


# ---- 렌즈 이동·카메라 보정 ----

func test_vanishing_point_sits_in_the_middle_of_the_uncovered_view() -> void:
	var s := await _open()
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		await _set_map(s, false)
		var x0 := _vanishing_x(s)
		check(absf(x0 - size.x / 2.0) <= 2.0, "%s 지도 닫힘: 소실점 x %.1f = 화면 가운데 %.1f" % [tag, x0, size.x / 2.0])
		var r0 := s.view.guard_radius
		await _set_map(s, true)
		var p := MapWindow.WIDTH / size.x
		check(is_equal_approx(s.view.lens_cover, p), "%s: 덮인 비율 %.3f = 판 폭 / 화면 폭 %.3f" % [tag, s.view.lens_cover, p])
		var want := (size.x - MapWindow.WIDTH) / 2.0
		var x1 := _vanishing_x(s)
		check(absf(x1 - want) <= 2.0, "%s 지도 열림: 소실점 x %.1f = 덮이지 않은 영역 가운데 %.1f" % [tag, x1, want])
		check_eq(s.view.camera().projection, Camera3D.PROJECTION_FRUSTUM, tag + ": 렌즈 이동(PROJECTION_FRUSTUM)")
		check(absf(s.view.camera().h_offset) < 1e-6, tag + ": 카메라를 옮기지 않는다(h_offset 0)")
		# 같은 세로 시야: 화면 위·아래 끝 방향의 각이 fov 75 와 같다
		var cam := s.view.camera()
		var sv := s.view_container.get_child(0) as SubViewport
		var top := cam.project_ray_normal(Vector2(sv.size.x / 2.0, 0))
		var bottom := cam.project_ray_normal(Vector2(sv.size.x / 2.0, sv.size.y))
		check(absf(rad_to_deg(top.angle_to(bottom)) - DungeonView.FOV) < 0.5, "%s: 세로 시야각 %.2f° = 75°" % [tag, rad_to_deg(top.angle_to(bottom))])
		# 카메라 보정 반경: 넓은 쪽 반폭으로 잰 화면비
		var aspect := size.x / size.y
		check(is_equal_approx(s.view.effective_aspect(), aspect * (1.0 + p)), "%s: 유효 화면비 %.3f = 화면비·(1 + p)" % [tag, s.view.effective_aspect()])
		var left := -1.0 + p
		var right := 1.0 + p
		check(is_equal_approx(s.view.effective_aspect(), aspect * maxf(absf(left), absf(right))), tag + ": = 2·max(|left|, |right|)/높이")
		var r1 := s.view.guard_radius
		check(is_equal_approx(r1, CameraGuard.reach(s.view._max_triangle, DungeonView.FOV, aspect * (1.0 + p))), "%s: 보정 반경 = reach(넓은 쪽 화면비) %.3f" % [tag, r1])
		check(r1 >= r0, "%s: 지도를 열면 반경이 줄지 않는다(%.3f ≥ %.3f)" % [tag, r1, r0])
		check(s.view.effective_aspect() <= CameraGuard.MAX_ASPECT + 1e-6, "%s: 유효 화면비 %.3f ≤ MAX_ASPECT %.2f" % [tag, s.view.effective_aspect(), CameraGuard.MAX_ASPECT])
		# 열린 상태에서 정지 자세의 보정이 새 반경의 정점 집합에서 다시 구한 값과 같다
		var t := s.view.camera_transform()
		var eye := DungeonMeshBuilder.cell_center(s.state.party.at) + Vector3.UP * DungeonView.EYE_HEIGHT
		var fwd := -t.basis.z
		var d := CameraGuard.solve(s.view._index.near(eye, r1), eye, fwd)
		check(absf(d - s.view.last_guard_delta) < 1e-6, "%s: 정지 보정 δ 를 새 반경으로 다시 구했다" % tag)
		await _set_map(s, false)
		check(is_equal_approx(s.view.guard_radius, r0), tag + ": 닫으면 반경이 돌아온다")


func test_max_aspect_is_the_widest_effective_aspect_of_target_screens() -> void:
	var widest := (CameraGuard.MAX_SCREEN_ASPECT * 720.0 + MapWindow.WIDTH) / 720.0
	check(CameraGuard.MAX_ASPECT >= widest and CameraGuard.MAX_ASPECT - widest < 0.01, "MAX_ASPECT %.3f = (1728 + 550)/720 %.3f 올림" % [CameraGuard.MAX_ASPECT, widest])
	check(is_equal_approx(CameraGuard.MAX_SCREEN_ASPECT, 1728.0 / 720.0), "MAX_SCREEN_ASPECT = 2400×1000 의 논리 1728×720")


# ---- 앵커: 크기를 바꿔도 가장자리·모서리 ----

func test_hud_and_panel_follow_edges_after_resize() -> void:
	var s := await _open()
	await _set_map(s, true)
	for px in WINDOWS + [Vector2(1280, 720)]:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		var vw := size.x - MapWindow.WIDTH
		check_eq(_rect(s.map_window), Rect2(vw, 0, MapWindow.WIDTH, size.y), tag + ": 지도 판은 오른쪽 가장자리, 위에서 아래까지")
		check_eq(_rect(s.view_area), Rect2(0, 0, vw, size.y), tag + ": 시야 영역 = 판 왼쪽")
		var ov := _rect(s.map_window.overview)
		var mp := _rect(s.map)
		check(absf(ov.end.y - size.y * MapWindow.SPLIT) <= 4.0, "%s: 층 전체 보기 아래 끝 %.0f ≈ 53.5%%" % [tag, ov.end.y])
		check(mp.position.y >= ov.end.y and absf(mp.end.y - size.y) <= 4.0, tag + ": 그리기 격자는 그 아래 바닥까지")
		var col := _rect(s.toolbar)
		check(col.end.x == size.x and col.position.x >= mp.end.x and col.position.x >= ov.end.x, tag + ": 도구 열은 맨 오른쪽")
		var back := _rect(s.map_window.back_button)
		check(mp.encloses(back) and back.end.x >= mp.end.x - 12.0 and back.position.y <= mp.position.y + 12.0, "%s: 「돌아가기」는 그리기 격자 오른쪽 위 %s" % [tag, str(back)])
		var plate := _rect(s.floor_plate)
		check(plate.position == Vector2.ZERO, tag + ": 층 문패 왼쪽 위")
		var hint := _rect(s.hint_row)
		check(hint.position.x == DungeonScreen.EDGE and absf(hint.end.y - (size.y - DungeonScreen.EDGE)) < 0.01, "%s: 안내 줄 왼쪽 아래 %s" % [tag, str(hint)])
		check(hint.end.x <= vw, tag + ": 안내 줄은 판에 가리지 않는다")
		var pad := _rect(s.pad_box)
		check(pad.end.y <= hint.position.y and pad.position.x == DungeonScreen.EDGE and pad.end.x <= vw, "%s: 이동 단추는 안내 줄 위 %s" % [tag, str(pad)])
		var orb := _rect(s.orb)
		var c := orb.get_center()
		check(c.x > vw - DangerOrb.RADIUS and c.x < vw and c.y > size.y * 0.75, "%s: 위험 보석은 시야 영역 오른쪽 아래, 판 왼쪽 끝에 반쯤 가려진다 %s" % [tag, str(c)])
		check(orb.end.x > vw, tag + ": 보석이 판 아래로 들어간다")
		check(not s.minimap.is_visible_in_tree(), tag + ": 지도 판이 열리면 미니맵 감춤")
	await _set_map(s, false)
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s 닫힘" % str(px)
		check_eq(_rect(s.view_area), Rect2(Vector2.ZERO, size), tag + ": 시야 영역 = 화면 전체")
		var mm := _rect(s.minimap)
		check_eq(mm, Rect2(size.x - DungeonScreen.EDGE - DungeonScreen.MINI_SIZE.x, DungeonScreen.EDGE, DungeonScreen.MINI_SIZE.x, DungeonScreen.MINI_SIZE.y), tag + ": 미니맵 오른쪽 위")
		check(absf(DungeonScreen.MINI_SIZE.x / 1280.0 - 0.17) < 0.01 and absf(DungeonScreen.MINI_SIZE.y / 720.0 - 0.2) < 0.01, "미니맵 약 17%×20%")
		var c := _rect(s.orb).get_center()
		check(c.x > size.x - DangerOrb.RADIUS and _rect(s.orb).end.x > size.x, tag + ": 보석이 화면 모서리에 잘린다")


# ---- 누르는 순서(보이는 위아래 = 누르는 위아래) ----

func test_input_goes_to_the_visible_top_at_every_overlap() -> void:
	var s := await _open()
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		await _set_map(s, false)
		var got := await _receiver_at(_rect(s.minimap).get_center())
		check(got == s.view_container, "%s: 미니맵 자리 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.orb).get_center() + Vector2(-20, 0))
		check(got == s.view_container, "%s: 위험 보석 자리 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.floor_plate).get_center())
		check(got == s.view_container, "%s: 층 문패 자리 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(Vector2(size.x * 0.5, size.y * 0.4))
		check(got == s.view_container, "%s: 빈 시야 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		var fwd: TouchButton = s.pad[ExplorationRules.Action.FORWARD]
		got = await _receiver_at(_rect(fwd).get_center())
		check(got == fwd, "%s: 이동 단추(시야 위) → 단추, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.pad_box).position + Vector2(PadGapProbe.X, PadGapProbe.Y))
		check(got == s.view_container, "%s: 이동 단추 사이 틈 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		for b in [s.party_button, s.map_button, s.menu_button]:
			got = await _receiver_at(_rect(b).get_center())
			check(got == b, "%s: 안내 줄 %s, 실제 %s" % [tag, b.name, _name_of(got)])
		await kit.tap(kit.center_of(s.map_button))
		await kit.frames(2)
		check(s._map_open, tag + ": 지도 단추를 누르면 지도 판이 열린다")
		# 판이 시야 위에 덮인다: 판 안은 판이, 판 왼쪽은 시야가 받는다
		got = await _receiver_at(Vector2(size.x - MapWindow.WIDTH + 2.0, 2.0))
		check(_under(s.map_window, got), "%s: 판 왼쪽 위 모서리 → 판, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(Vector2(size.x - MapWindow.WIDTH - 3.0, size.y * 0.4))
		check(got == s.view_container, "%s: 판 바로 왼쪽 → 3D 시야, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.orb).get_center() + Vector2(DangerOrb.RADIUS * 0.6, 0))
		check(_under(s.map_window, got), "%s: 판에 가린 보석 자리 → 판, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.map).get_center())
		check(got == s.map, "%s: 그리기 격자, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.map_window.overview).get_center())
		check(got == s.map_window, "%s: 층 전체 보기(읽기 전용) → 판이 받아 시야로 새지 않는다, 실제 %s" % [tag, _name_of(got)])
		got = await _receiver_at(_rect(s.map_window.back_button).get_center())
		check(got == s.map_window.back_button, "%s: 그리기 격자 위 「돌아가기」, 실제 %s" % [tag, _name_of(got)])
		for k in MapToolbar.TOOL_KEYS:
			var tb: TouchButton = s.toolbar.buttons[k]
			got = await _receiver_at(_rect(tb).get_center())
			check(got == tb, "%s: 도구 %s, 실제 %s" % [tag, k, _name_of(got)])
		for k in MapToolbar.ACTION_KEYS:
			var ab: TouchButton = s.toolbar.buttons[k]
			check(ab.get_parent() == s.hint_row and ab.is_visible_in_tree(), "%s: %s 는 안내 줄(지도 열림)" % [tag, k])
			got = await _receiver_at(_rect(ab).get_center())
			check(got == ab, "%s: 안내 줄 %s, 실제 %s" % [tag, k, _name_of(got)])
		# 바닥 색: 견본 줄이 층 전체 보기 위에 뜬다
		await kit.tap(kit.center_of(s.toolbar.buttons["color"]))
		check(s.toolbar.palette.is_visible_in_tree() and s.map.tool == "color", tag + ": 바닥 색 → 견본 줄")
		var sw: TouchButton = s.toolbar.buttons["color3"]
		check(_rect(s.map_window.overview).encloses(_rect(sw)), tag + ": 견본은 층 전체 보기 위(도구 왼쪽)")
		got = await _receiver_at(_rect(sw).get_center())
		check(got == sw, "%s: 견본, 실제 %s" % [tag, _name_of(got)])
		await kit.tap(kit.center_of(sw))
		check_eq(s.map.paint_color, 3, tag + ": 견본으로 색 고름")
		# 아이콘: 층 전체 보기 자리에 아이콘 판
		await kit.tap(kit.center_of(s.toolbar.buttons["icon"]))
		check(s.map.tool == "icon" and s.map_window.icon_palette.is_visible_in_tree() and not s.map_window.overview.is_visible_in_tree(), tag + ": 아이콘 도구 → 아이콘 판이 층 전체 보기 자리")
		check(not s.toolbar.palette.is_visible_in_tree(), tag + ": 견본 줄은 닫힌다")
		check_eq(s.map_window.icon_buttons.size(), MapAnnotation.ICONS.size(), "아이콘 판에 아이콘 12개 모두")
		var chest: TouchButton = s.map_window.icon_buttons["chest"]
		got = await _receiver_at(_rect(chest).get_center())
		check(got == chest, "%s: 아이콘 판 단추, 실제 %s" % [tag, _name_of(got)])
		await kit.tap(kit.center_of(chest))
		check(s.map.icon_type == "chest" and s.map.tool == "icon" and chest.selected, tag + ": 상자 아이콘 고름(판은 남는다)")
		check(_rect(s.map_window).encloses(_rect(s.map_window.icon_palette)) and _rect(s.map_window.icon_palette).end.y <= _rect(s.map).position.y + 0.01, tag + ": 아이콘 판은 위쪽 영역 안")
		var n := s.state.annotation.icons.size()
		await kit.tap(kit.map_cell(s.state.party.at))
		check_eq(s.state.annotation.icons.size(), n + 1, tag + ": 그리기 격자를 누르면 아이콘을 둔다")
		await kit.tap(kit.center_of(s.toolbar.buttons["wall"]))
		check(s.map_window.overview.is_visible_in_tree() and not s.map_window.icon_palette.is_visible_in_tree(), tag + ": 다른 도구 → 층 전체 보기가 돌아온다")
		await kit.tap(kit.center_of(s.map_window.back_button))
		await kit.frames(2)
		check(not s._map_open and not s.map_window.is_visible_in_tree(), tag + ": 「돌아가기」로 지도 판을 닫는다")
		for k in MapToolbar.ACTION_KEYS:
			check(not (s.toolbar.buttons[k] as Control).is_visible_in_tree(), "%s: 지도를 닫으면 안내 줄의 %s 감춤" % [tag, k])


## 이동 단추 묶음 안의 틈(앞으로·오른쪽 회전 단추 사이 세로 틈 가운데, 묶음 기준).
class PadGapProbe:
	const X := 2.0 * DungeonScreen.PAD_BUTTON + DungeonScreen.PAD_GAP + DungeonScreen.PAD_GAP / 2.0
	const Y := DungeonScreen.PAD_BUTTON / 2.0


# ---- 누르는 칸 크기 ----

func test_every_tap_target_is_at_least_64() -> void:
	var s := await _open()
	await _window(WINDOWS[0])
	var seen := {}
	for open in [false, true]:
		await _set_map(s, open)
		for tool in ["wall", "color", "icon"]:
			if open:
				s._choose_tool(tool, 0)
				await kit.frames(2)
			for n in s.find_children("*", "TouchButton", true, false):
				var b := n as TouchButton
				if not b.is_visible_in_tree() or _under(s.party_menu, b) or _under(s.battle_layer, b):
					continue
				seen[b.name] = true
				check(b.size.x >= 64.0 and b.size.y >= 64.0, "%s: %s 크기 %s" % ["지도 열림" if open else "지도 닫힘", b.name, str(b.size)])
			if not open:
				break
	for k in ["Pad_forward", "PartyButton", "MapButton", "MenuButton", "MapBack", "Tool_wall", "Tool_color2", "Icon_chest", "Tool_undo", "Tool_to_party"]:
		check(seen.has(k), "본 단추에 %s" % k)


# ---- 미니맵·위험 보석 ----

func test_minimap_and_danger_orb_follow_the_state() -> void:
	var s := await _open()
	await _window(WINDOWS[0])
	check(s.minimap.is_mini and s.minimap.modulate.a < 1.0, "미니맵은 반투명")
	var mm := s.minimap
	check(absf(mm.cell_point(s.state.party.at).x - mm.size.x / 2.0) < 0.01 and absf(mm.cell_point(s.state.party.at).y - mm.size.y / 2.0) < 0.01, "미니맵 가운데 = 파티 칸")
	check(s.state.annotation == mm.state.annotation, "미니맵은 플레이어 지도 그림을 그린다")
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check(absf(mm.cell_point(s.state.party.at).y - mm.size.y / 2.0) < 0.01, "걸으면 미니맵이 파티를 따라간다")
	s.state.encounter.danger = 0
	s._refresh_hud()
	check_eq(s.orb.gauge, 0.0, "보석 게이지 0")
	var safe := DangerOrb.color_of(0.0)
	check(safe.b > safe.r and safe.b > safe.g, "안전 = 파랑")
	var yellow := DangerOrb.color_of(0.5)
	check(yellow.r > 0.8 and yellow.g > 0.7 and yellow.b < 0.4, "중간 = 노랑")
	var orange := DangerOrb.color_of(0.75)
	check(orange.r > 0.9 and orange.g > 0.4 and orange.g < 0.7, "높음 = 주황")
	var red := DangerOrb.color_of(1.0)
	check(red.r > 0.9 and red.g < 0.3, "가득 = 빨강")
	s.state.encounter.danger = s.state.encounter.threshold - 1
	s._refresh_hud()
	check(is_equal_approx(s.orb.gauge, s.state.encounter.gauge()), "보석 게이지 = 위험도")


# ---- 그리기 격자 기본 확대 (원작: 격자 폭에 약 7칸) ----

func test_drawing_grid_opens_close_up_about_seven_columns() -> void:
	var s := await _open()
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s(논리 %s)" % [str(px), str(size)]
		await _set_map(s, true)
		var home := s.map.geo.cell_px
		var cols := s.map.size.x / home
		check(cols >= 6.5 and cols < 8.0 and home >= 60.0, "%s: 열면 칸 %.0fpx, 폭에 %.1f칸" % [tag, home, cols])
		check(absf(s.map.cell_point(s.state.party.at).x - s.map.size.x / 2.0) < 0.01, tag + ": 파티 칸이 가운데")
		var vr := s.map_window.overview.view_rect()
		check(absf(vr.size.x / s.map_window.overview.geo.cell_px - cols) < 0.01, "%s: 층 전체 보기의 점선 범위도 %.1f칸" % [tag, cols])
		await kit.tap(kit.center_of(s.toolbar.buttons["zoom_out"]))
		check(s.map.geo.cell_px < home, tag + ": 축소는 된다")
		await _window(px)
		check(s.map.geo.cell_px < home, tag + ": 크기가 바뀌어도 사용자 확대는 그대로")
		await kit.tap(kit.center_of(s.toolbar.buttons["zoom_in"]))
		await kit.tap(kit.center_of(s.toolbar.buttons["zoom_in"]))
		check(s.map.geo.cell_px > home, tag + ": 확대도 된다")
		await kit.tap(kit.center_of(s.toolbar.buttons["to_party"]))
		check_eq(s.map.geo.cell_px, home, tag + ": 「파티로」는 기본 확대로")
		s.map.zoom(0.5)
		await _set_map(s, false)
		await _set_map(s, true)
		check_eq(s.map.geo.cell_px, home, tag + ": 다시 열면 기본 확대로")
		await _set_map(s, false)


# ---- 끊긴 누름: 지도 판을 감추면 판 안의 누름을 취소한다 (리뷰 R1-1) ----

func test_closing_the_map_cancels_held_window_buttons() -> void:
	var s := await _open()
	await _window(WINDOWS[0])
	# (a) 손가락 A 가 「돌아가기」를 누른 채, 손가락 B 가 「지도」로 닫고, A 를 뗀다 → 닫힌 채
	await _set_map(s, true)
	var back := s.map_window.back_button
	var bp := kit.center_of(back)
	kit.touch(1, bp, true)
	await kit.frames(1)
	check(back.held, "준비: 「돌아가기」를 누르고 있다")
	await kit.tap(kit.center_of(s.map_button), 2)
	await kit.frames(1)
	check(not s._map_open, "다른 손가락의 「지도」로 닫힘")
	check(not back.held and back._owner == TouchButton.NONE, "닫으면 「돌아가기」 누름을 취소한다")
	kit.touch(1, bp, false)
	await kit.frames(2)
	check(not s._map_open, "누르던 손가락을 떼도 다시 열리지 않는다")
	# 「돌아가기」는 바꾸기가 아니라 닫기
	s._set_map_open(false)
	s.map_window.back_requested.emit()
	check(not s._map_open, "「돌아가기」는 닫힌 판을 열지 않는다")
	# (b) 마우스로 도구를 누른 채 판이 감춰지고(M 키·파티 메뉴), 뗀다 → 아무 일 없음, 누름이 남지 않는다
	for how in ["M", "P"]:
		await _set_map(s, true)
		s._choose_tool("wall", 0)
		var door: TouchButton = s.toolbar.buttons["door"]
		var dp := kit.center_of(door)
		kit.mouse(dp, true)
		await kit.frames(1)
		check(door.held, how + ": 준비: 문 도구를 누르고 있다")
		await kit.press_key(KEY_M if how == "M" else KEY_P)
		check(not s.map_window.is_visible_in_tree(), how + ": 판이 감춰졌다")
		check(not door.held and door._owner == TouchButton.NONE, how + ": 감추면 도구 누름을 취소한다")
		kit.mouse(dp, false)
		await kit.frames(2)
		check_eq(s.map.tool, "wall", how + ": 뗀 뒤에도 도구가 바뀌지 않는다")
		for n in s.map_window.find_children("*", "TouchButton", true, false):
			var b := n as TouchButton
			check(not b.held and b._owner == TouchButton.NONE, "%s: %s 에 누름이 남지 않는다" % [how, b.name])
		if s.party_menu.is_open():
			await kit.press_key(KEY_ESCAPE)
			await kit.frames(2)


# ---- 지도 보기 셋이 지도 표시를 따라 다시 그린다 (리뷰 R1-2) ----

func test_overview_and_minimap_redraw_on_every_annotation_change() -> void:
	var s := await _open()
	await _window(WINDOWS[0])
	var mini := s.minimap
	var ov := s.map_window.overview
	# (a) 아이콘을 두고 지도를 닫은 뒤 Ctrl+Z → 미니맵이 다시 그려 아이콘이 없다
	await _set_map(s, true)
	s._choose_icon("chest")
	var at := s.state.party.at
	await kit.tap(kit.map_cell(at + Vector2i(0, 1)))
	await kit.frames(2)
	check_eq(s.state.annotation.icons.size(), 1, "준비: 상자 아이콘")
	s._choose_tool("wall", 0)  # 아이콘 판을 걷어 층 전체 보기를 보인다
	await kit.frames(2)
	check_eq(int(ov.drawn["icons"]), 1, "층 전체 보기가 아이콘을 그렸다")
	await _set_map(s, false)
	await kit.frames(2)
	check_eq(int(mini.drawn["icons"]), 1, "미니맵이 아이콘을 그렸다")
	var n0 := int(mini.drawn["count"])
	await kit.press_key(KEY_Z, true)
	await kit.frames(2)
	check_eq(s.state.annotation.icons.size(), 0, "Ctrl+Z 로 아이콘 되돌림")
	check(int(mini.drawn["count"]) > n0 and int(mini.drawn["icons"]) == 0, "닫힌 채 되돌려도 미니맵이 다시 그려 아이콘이 없다 %s" % str(mini.drawn))
	check_eq(int(mini.drawn["version"]), s.state.annotation.version, "미니맵이 그린 판 = 지금 판")
	# (b) 층 전체 보기가 보이는 채 메모를 확정·지운다
	await _set_map(s, true)
	await kit.frames(2)
	var m0 := int(ov.drawn["count"])
	s.apply_memo(at, "상자 앞")
	await kit.frames(2)
	check(int(ov.drawn["count"]) > m0 and int(ov.drawn["memos"]) == 1, "메모 확정 → 층 전체 보기가 다시 그린다 %s" % str(ov.drawn))
	s.apply_memo(at, "")
	await kit.frames(2)
	check_eq(int(ov.drawn["memos"]), 0, "메모 지움 → 층 전체 보기에서도 사라진다")
	# 자동 기록(걸음)과 상태 바꾸기(가져오기)도 같은 길
	await _set_map(s, false)
	var f0 := int(mini.drawn["floors"])
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check(int(mini.drawn["floors"]) > f0, "걸으면 자동 기록한 바닥을 미니맵이 그린다(%d → %d)" % [f0, int(mini.drawn["floors"])])
	var save := SaveCodec.encode(s.state)
	s.state.annotation.set_memo(at, "가져오기 전")
	await kit.frames(2)
	check(s.import_text(save), "가져오기")
	await kit.frames(3)
	check_eq(int(mini.drawn["memos"]), 0, "가져오기 뒤 미니맵은 새 상태의 표시를 그린다")
	check_eq(int(mini.drawn["version"]), s.state.annotation.version, "가져오기 뒤 판")
