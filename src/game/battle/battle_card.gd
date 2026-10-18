## 적 칸·파티 칸 하나(06 §9.1). 누르기는 TouchButton 그대로(대상 고르기), 그림은 보이는 값(BattleDisplay.DUnit)에서.
## 적: 단색 둥근 사각형 + 이름 + HP 막대(숫자 없음, D13) + 상태 딱지, 준비 중이면 「!」와 다음 행동 이름.
## 아군: 직업색 띠, 이름, HP 막대·「HP 50/60」, TP 막대·수치, 상태 딱지, 고른 명령, 지금 고르는 대원 강조.
class_name BattleCard
extends TouchButton

## 직업색(04 §3.1).
const CLASS_COLORS := {
	"class.holo_knight": Color(1.0, 0.78, 0.25), "class.blade_duelist": Color(0.25, 0.9, 1.0),
	"class.nano_medic": Color(0.75, 0.92, 1.0), "class.glyph_wizard": Color(0.72, 0.45, 1.0),
}
## 적 자리표시 색: 직업색(금·시안·흰·하늘·보라)과 겹치지 않는 단색.
const ENEMY_COLORS := {
	"enemy.neon_rat": Color(0.62, 0.27, 0.22), "enemy.cable_moth": Color(0.47, 0.5, 0.2),
	"enemy.spore_bloom": Color(0.28, 0.46, 0.27), "enemy.wire_serpent": Color(0.7, 0.42, 0.14),
	"enemy.drill_mole": Color(0.45, 0.33, 0.24), "enemy.clamp_beetle": Color(0.36, 0.38, 0.42),
}
const ENEMY_DEFAULT := Color(0.5, 0.3, 0.3)
const POPUP_SEC := 0.9
const HP_GLIDE := 3.0
const POPUP_SIZE := 32
## 상태 딱지(06 §9.1): 작은 글자 딱지를 줄을 바꿔 가며 놓는다. 아군 칸은 세 줄(상태이상 1 + 봉인 3 + 강화·약화 칸 3·3 =
## 최대 10개가 1280×720 에서도 다 들어간다), 적 칸은 두 줄(적은 강화·약화를 받지 않아 최대 4개).
## 그래도 넘치면(규칙 상수의 칸 수를 늘린 경우 등) 마지막 자리에 「+N」을 두고, 전체는 로그 창 위 상태 목록에서 본다.
const CHIP_FS := 13
const CHIP_H := 21.0
const CHIP_GAP := 3.0
const CHIP_PAD := 4.0
const CHIP_TRI := 10.0
const MEMBER_CHIP_TOP := 102.0
const ENEMY_BAR_FROM_BOTTOM := 64.0

var display: BattleDisplay
var unit_ref := {}
var class_id := ""
## 대상 고르기 표시: "" (평소) / "valid" / "invalid"(흐리게 + reason) / "lit"(줄 대상 강조).
var target_mark := "":
	set(v):
		target_mark = v
		queue_redraw()
var reason := ""
## 키보드 커서가 이 칸에 있음.
var cursor := false:
	set(v):
		cursor = v
		queue_redraw()
## 아군: 지금 명령을 고르는 대원.
var current := false:
	set(v):
		current = v
		queue_redraw()
## 아군: 고른 명령 글자.
var command_text := "":
	set(v):
		command_text = v
		queue_redraw()
## 아군: 띠 아래 열 표시는 PartyCards 가 그린다.

var flash := 0.0
var popups: Array[Dictionary] = []
## 막대가 보이는 비율(연출 중 줄어든다).
var shown_hp := -1.0
var shown_tp := -1.0


func unit() -> BattleDisplay.DUnit:
	return display.unit(unit_ref) if display != null else null


func is_enemy() -> bool:
	return unit_ref.get("side") == BattleUnit.ENEMY


## 보이는 값으로 막대를 바로 맞춘다(건너뛰기·연출 끝·새로 열기).
func snap() -> void:
	var u := unit()
	if u != null:
		shown_hp = u.hp
		shown_tp = u.tp
	flash = 0.0
	popups.clear()
	queue_redraw()


## 숫자 하나(sub = 위에 붙는 작은 글자: 「약점!」「치명!」). 앞 단계의 숫자는 지운다(겹쳐 쌓이면 이름을 덮는다).
func pop(t: String, color: Color, sub: String = "") -> void:
	popups = popups.filter(func(p: Dictionary) -> bool: return p["age"] < 0.12)
	popups.append({"text": t, "color": color, "sub": sub, "age": 0.0, "row": popups.size()})
	queue_redraw()


func _process(delta: float) -> void:
	var u := unit()
	if u == null:
		return
	var dirty := false
	if shown_hp < 0.0:
		shown_hp = u.hp
		shown_tp = u.tp
	if absf(shown_hp - u.hp) > 0.01:
		shown_hp = move_toward(shown_hp, u.hp, maxf(1.0, absf(shown_hp - u.hp)) * HP_GLIDE * delta + 0.5)
		dirty = true
	if absf(shown_tp - u.tp) > 0.01:
		shown_tp = move_toward(shown_tp, u.tp, maxf(1.0, absf(shown_tp - u.tp)) * HP_GLIDE * delta + 0.5)
		dirty = true
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 3.0)
		dirty = true
	if not popups.is_empty():
		for p in popups:
			p["age"] += delta
		popups = popups.filter(func(p: Dictionary) -> bool: return p["age"] < POPUP_SEC)
		dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	var u := unit()
	if u == null:
		return
	if is_enemy():
		_draw_enemy(u)
	else:
		_draw_member(u)
	if flash > 0.0:
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = Color(1, 1, 1, 0.45 * flash)
		fsb.set_corner_radius_all(14)
		draw_style_box(fsb, Rect2(Vector2.ZERO, size))
	_draw_popups()


## 피해 숫자·「약점!」 등(06 §9.3). 밝은 색 + 굵은 검은 외곽선. 글자를 가리지 않는 자리에 둔다:
## 적은 이름과 HP 막대 사이의 빈 곳, 아군은 칸 위(띠·적 영역 쪽)로 떠오른다(이름·HP·TP 글자를 덮지 않게).
func _draw_popups() -> void:
	var font := get_theme_default_font()
	for p in popups:
		var t: float = p["age"] / POPUP_SEC
		var col: Color = p["color"]
		col.a = clampf(1.6 - t * 1.6, 0.0, 1.0)
		# 적: HP 막대 바로 위(이름 아래 빈 곳), 아군: 칸 위쪽 바깥.
		var base := size.y - ENEMY_BAR_FROM_BOTTOM - 6.0 if is_enemy() else -8.0
		var y := base - 12.0 * t - float(p["row"]) * 34.0
		var outline := Color(0, 0, 0, col.a)
		draw_string_outline(font, Vector2(0, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, size.x, POPUP_SIZE, 12, outline)
		draw_string(font, Vector2(0, y), p["text"], HORIZONTAL_ALIGNMENT_CENTER, size.x, POPUP_SIZE, col)
		if not str(p["sub"]).is_empty():
			var sc := Color(1.0, 0.85, 0.35, col.a)
			draw_string_outline(font, Vector2(0, y - 32.0), p["sub"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 8, outline)
			draw_string(font, Vector2(0, y - 32.0), p["sub"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, sc)


func _draw_enemy(u: BattleDisplay.DUnit) -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	if not u.alive():
		if not popups.is_empty() or flash > 0.0:
			_box(r, Color(0.2, 0.2, 0.22, 0.35), Color(0.4, 0.4, 0.42, 0.5), 1)
		return
	var base: Color = ENEMY_COLORS.get(u.def_id, ENEMY_DEFAULT)
	var dim := target_mark == "invalid"
	var body := base if not dim else base.darkened(0.6)
	var border := base.lightened(0.35)
	var bw := 2
	if target_mark == "valid" or target_mark == "lit":
		border = Color(1.0, 0.95, 0.55)
		bw = 4 if target_mark == "lit" or cursor else 3
	if held:
		body = body.lightened(0.15)
	_box(r, body, border, bw)
	if cursor and target_mark != "invalid":
		_box(r.grow(-7), Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2)
	var fg := Color(0.96, 0.96, 0.96) if not dim else Color(0.6, 0.6, 0.6)
	var fs := 20 if size.x >= 180.0 else 17
	draw_string_outline(font, Vector2(0, 34), u.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, 34), u.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, fg)
	# HP 막대(숫자 없음, D13)
	var bar := Rect2(14, size.y - ENEMY_BAR_FROM_BOTTOM, size.x - 28, 12)
	_bar(bar, shown_hp / maxf(1.0, u.max_hp), Color(0.95, 0.35, 0.3), dim)
	_draw_chips(drawn_chips())
	if not u.charging.is_empty():
		# 준비 중: 「!」와 다음 행동 이름
		var badge := Rect2(size.x - 42, 6, 36, 36)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(1.0, 0.8, 0.15)
		bsb.set_corner_radius_all(18)
		draw_style_box(bsb, badge)
		draw_string(font, Vector2(badge.position.x, badge.position.y + 28), "!", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 26, Color(0.15, 0.08, 0.0))
		var next := display.skill_name(u.charging)
		draw_string_outline(font, Vector2(0, 62), next, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 5, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0, 62), next, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1.0, 0.85, 0.3))
	if dim and not reason.is_empty():
		var ry := size.y - ENEMY_BAR_FROM_BOTTOM - 10.0
		draw_string_outline(font, Vector2(0, ry), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, ry), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(1.0, 0.7, 0.55))


## 대원 칸 HP 막대 색(HpColor 한 규칙, 보이는 HP 기준: 깎이는 연출 중에도 막대 길이와 맞는다).
func hp_bar_color() -> Color:
	var u := unit()
	return HpColor.of(shown_hp if shown_hp >= 0.0 else float(u.hp), u.max_hp)


func _draw_member(u: BattleDisplay.DUnit) -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	var cc: Color = CLASS_COLORS.get(class_id, Color(0.7, 0.7, 0.7))
	var down := not u.alive()
	var dim := target_mark == "invalid"
	var body := Color(0.06, 0.09, 0.12, 0.95)
	if held:
		body = Color(0.12, 0.2, 0.26, 0.97)
	var border := Color(0.3, 0.42, 0.5)
	var bw := 1
	if current:
		border = cc
		bw = 4
	if target_mark == "valid" or target_mark == "lit":
		border = Color(1.0, 0.95, 0.55)
		bw = 4 if target_mark == "lit" or cursor else 3
	_box(r, body, border, bw)
	# 직업색 띠
	var band := StyleBoxFlat.new()
	band.bg_color = cc if not down else cc.darkened(0.6)
	band.corner_radius_top_left = 10
	band.corner_radius_top_right = 10
	draw_style_box(band, Rect2(bw, bw, size.x - 2 * bw, 10))
	if cursor and target_mark != "invalid":
		_box(r.grow(-7), Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2)
	var fg := Color(0.92, 0.97, 1.0)
	if down or dim:
		fg = Color(0.55, 0.55, 0.58)
	var x0 := 14.0
	var w := size.x - 28.0
	draw_string(font, Vector2(x0, 35), u.name, HORIZONTAL_ALIGNMENT_LEFT, w * 0.62, 19, fg)
	if not command_text.is_empty():
		draw_string(font, Vector2(x0 + w * 0.5, 35), command_text, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, 16, Color(1.0, 0.9, 0.45))
	draw_string(font, Vector2(x0, 55), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, fg)
	draw_string(font, Vector2(x0, 55), "%d/%d" % [roundi(shown_hp), u.max_hp], HORIZONTAL_ALIGNMENT_RIGHT, w, 17, fg)
	_bar(Rect2(x0, 60, w, 9), shown_hp / maxf(1.0, u.max_hp), hp_bar_color(), down)
	draw_string(font, Vector2(x0, 85), "TP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fg)
	draw_string(font, Vector2(x0, 85), "%d/%d" % [roundi(shown_tp), u.max_tp], HORIZONTAL_ALIGNMENT_RIGHT, w, 15, fg)
	_bar(Rect2(x0, 90, w, 6), shown_tp / maxf(1.0, u.max_tp), Color(0.4, 0.65, 1.0), down)
	if down:
		draw_string(font, Vector2(x0, MEMBER_CHIP_TOP + 18), display.texts.t("battle.ui.down"), HORIZONTAL_ALIGNMENT_LEFT, w, 16, Color(1.0, 0.45, 0.4))
	else:
		_draw_chips(drawn_chips())
	if dim and not reason.is_empty():
		draw_string_outline(font, Vector2(0, size.y * 0.5 + 6), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, size.y * 0.5 + 6), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(1.0, 0.7, 0.55))


func _box(r: Rect2, bg: Color, border: Color, bw: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(bw)
	sb.border_color = border
	draw_style_box(sb, r)


func _bar(r: Rect2, ratio: float, color: Color, dim: bool) -> void:
	draw_rect(r, Color(0.05, 0.07, 0.09, 0.95))
	var c := color if not dim else color.darkened(0.55)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), c)
	draw_rect(r, Color(0.45, 0.52, 0.56), false, 1.0)


## 딱지를 놓을 자리(칸 안 좌표).
func chip_area() -> Rect2:
	if is_enemy():
		return Rect2(8, size.y - ENEMY_BAR_FROM_BOTTOM + 16.0, size.x - 16, CHIP_H * 2.0 + CHIP_GAP)
	return Rect2(10, MEMBER_CHIP_TOP, size.x - 20, size.y - MEMBER_CHIP_TOP - 4.0)


## 실제로 그리는 딱지: [{text, kind, rect}]. 다 못 놓으면 마지막이 {kind: "more", text: "+N", hidden: N}.
## 쓰러진 대원은 딱지가 없다(상태가 지워진다).
func drawn_chips() -> Array[Dictionary]:
	var u := unit()
	if u == null or not u.alive():
		return []
	return layout_chips(display.chips(u), chip_area(), get_theme_default_font())


static func chip_width(font: Font, c: Dictionary) -> float:
	var tri: bool = c["kind"] == "buff" or c["kind"] == "debuff"
	return ceilf(font.get_string_size(str(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS).x) + 2.0 * CHIP_PAD + (CHIP_TRI if tri else 0.0)


## 왼쪽 위부터 줄을 바꿔 가며 놓는다. 자리가 모자라면 뒤에서부터 빼고 「+N」(뺀 개수)을 둔다(조용히 버리지 않는다).
static func layout_chips(chips: Array[Dictionary], area: Rect2, font: Font) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var x := area.position.x
	var y := area.position.y
	for c in chips:
		var w := chip_width(font, c)
		if x > area.position.x and x + w > area.end.x:
			x = area.position.x
			y += CHIP_H + CHIP_GAP
		if y + CHIP_H > area.end.y + 0.01 or w > area.size.x:
			break
		var d := c.duplicate()
		d["rect"] = Rect2(x, y, w, CHIP_H)
		out.append(d)
		x += w + CHIP_GAP
	if out.size() == chips.size():
		return out
	while true:
		var hidden := chips.size() - out.size()
		var more := {"text": "+%d" % hidden, "kind": "more", "hidden": hidden}
		var mw := chip_width(font, more)
		var at := area.position
		if not out.is_empty():
			var last: Rect2 = out[-1]["rect"]
			at = Vector2(last.end.x + CHIP_GAP, last.position.y)
			if at.x + mw > area.end.x and last.position.y + 2.0 * CHIP_H + CHIP_GAP <= area.end.y + 0.01:
				at = Vector2(area.position.x, last.position.y + CHIP_H + CHIP_GAP)
		if at.x + mw <= area.end.x + 0.01 or out.is_empty():
			more["rect"] = Rect2(at, Vector2(mw, CHIP_H))
			out.append(more)
			return out
		out.pop_back()
	return out


func _draw_chips(chips: Array[Dictionary]) -> void:
	var font := get_theme_default_font()
	for c in chips:
		var r: Rect2 = c["rect"]
		var col := Color(0.55, 0.25, 0.6)
		match c["kind"]:
			"ailment":
				col = Color(0.6, 0.22, 0.5)
			"bind":
				col = Color(0.65, 0.4, 0.12)
			"buff":
				col = Color(0.15, 0.45, 0.3)
			"debuff":
				col = Color(0.5, 0.2, 0.2)
			"more":
				col = Color(0.3, 0.33, 0.38)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(5)
		draw_style_box(sb, r)
		var tx := r.position.x + CHIP_PAD
		if c["kind"] == "buff" or c["kind"] == "debuff":
			var cx := r.position.x + CHIP_PAD + 4.0
			var cy := r.position.y + CHIP_H * 0.5
			var pts := PackedVector2Array([Vector2(cx - 4, cy + 4), Vector2(cx + 4, cy + 4), Vector2(cx, cy - 4)]) if c["kind"] == "buff" \
				else PackedVector2Array([Vector2(cx - 4, cy - 4), Vector2(cx + 4, cy - 4), Vector2(cx, cy + 4)])
			draw_colored_polygon(pts, Color(1, 1, 1))
			tx += CHIP_TRI
		draw_string(font, Vector2(tx, r.position.y + CHIP_H - 5.0), str(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS, Color(1, 1, 1))
