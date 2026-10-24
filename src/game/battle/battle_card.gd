## 적 칸·파티 칸 하나(06 §9.1). 누르기는 TouchButton 그대로(대상 고르기), 그림은 보이는 값(BattleDisplay.DUnit)에서.
## 적: 단색 둥근 사각형 + 이름 + 상태 딱지, 준비 중이면 「!」와 다음 행동 이름. HP 막대(숫자 없음, D13)는 대상 고르기 중
## 커서가 있는 적 위에만 뜬다(EnemyArea, 원작 jp_guide5_img1).
## 아군(원작 HD 카드 233×80): 어두운 틀의 청록 판, 머리 줄(상태 네모 + 이름 띠 + 고른 명령), 「HP n」「TP n」과 노랑 → 주황 HP 막대·시안 TP 막대.
## 지금 행동하는 대원은 밝은 시안 틀, 쓰러지면 카드 전체가 어두운 회색(이름 회색, HP 0, TP 막대는 시안 그대로, jp_guide5_img4).
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
## 대원 카드(원작 HD 1868180_0e36b17e·1810820_1f51fd75, 233×80): 틀 두께, 머리 줄 높이(네모 = 같은 크기), 「HP」「TP」 칸 사이, 막대 높이,
## 글자 크기(이름·고른 명령·이름표·수치), 네모 안 상태 글자와 「+N」 줄.
const FRAME_W := 3.0
const HEAD_H := 34.0
const STAT_GAP := 8.0
const BAR_H := 6.0
const NAME_FS := 19
const COMMAND_FS := 14
const LABEL_FS := 15
const VALUE_FS := 20
const GLYPH_FS := 16
const MORE_H := 13.0
const MORE_FS := 11
## 고른 명령 글자(이름 띠 위, 오른쪽).
const COMMAND_TEXT := Color(1.0, 0.9, 0.45)
## 못 고르는 대상의 이유 글자(검은 외곽선을 두른다).
const REASON_TEXT := Color(1.0, 0.7, 0.55)

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

## 마지막으로 그린 대원 카드 값(시험·디버그): {fill, head, name_color, frame, hp, tp, hp_bar, tp_bar}.
var drawn := {}
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
		UiTheme.fill_round(self, Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.45 * flash), 14)
	_draw_popups()


## 피해 숫자·「약점!」 등(06 §9.3). 밝은 색 + 굵은 검은 외곽선. 글자를 가리지 않는 자리에 둔다:
## 적은 이름과 HP 막대 사이의 빈 곳, 아군은 칸 위(띠·적 영역 쪽)로 떠오른다(이름·HP·TP 글자를 덮지 않게).
func _draw_popups() -> void:
	var font := get_theme_default_font()
	for p in popups:
		var t: float = p["age"] / POPUP_SEC
		var col: Color = p["color"]
		col.a = clampf(1.6 - t * 1.6, 0.0, 1.0)
		# 적: 칸 가운데 아래(이름·딱지 사이 빈 곳), 아군: 칸 위쪽 바깥.
		var base := size.y * 0.62 if is_enemy() else -8.0
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
	var fs := 20 if size.x >= 160.0 else 17
	draw_string_outline(font, Vector2(0, 34), u.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 5, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, 34), u.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, fg)
	# HP 막대는 칸 안에 없다: 대상 고르기 중 커서가 있는 적 위에 뜬다(EnemyArea 의 HP 표, 원작 jp_guide5_img1).
	_draw_chips(drawn_chips())
	if not u.charging.is_empty():
		# 준비 중: 「!」와 다음 행동 이름
		var badge := Rect2(size.x - 42, 6, 36, 36)
		UiTheme.fill_round(self, badge, Color(1.0, 0.8, 0.15), 18)
		draw_string(font, Vector2(badge.position.x, badge.position.y + 28), "!", HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 26, Color(0.15, 0.08, 0.0))
		var next := display.skill_name(u.charging)
		draw_string_outline(font, Vector2(0, 62), next, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 5, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0, 62), next, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(1.0, 0.85, 0.3))
	if dim and not reason.is_empty():
		var ry := size.y * 0.5 + 8.0
		draw_string_outline(font, Vector2(0, ry), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(0, ry), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, REASON_TEXT)


## 대원 카드 막대 색(원작 1810820_1f51fd75: HP 는 비율과 상관없이 노랑 → 주황, TP 는 시안). [왼쪽 끝, 오른쪽 끝].
func hp_bar_colors() -> Array[Color]:
	return [UiTheme.CARD_HP_FROM, UiTheme.CARD_HP_TO]


## 대원 카드 칸 나눔(카드 기준): 머리 줄의 네모(상태 표시)와 이름 띠, 아래 「HP」「TP」 두 칸.
func square_rect() -> Rect2:
	var i := FRAME_W + 2.0
	return Rect2(i, i, HEAD_H, HEAD_H)


func name_band() -> Rect2:
	var sq := square_rect()
	var x := sq.end.x + 3.0
	return Rect2(x, sq.position.y, size.x - FRAME_W - 2.0 - x, HEAD_H)


## 「HP」(0)·「TP」(1) 칸: 글자 줄과 그 아래 막대.
func stat_rect(i: int) -> Rect2:
	var x0 := FRAME_W + 4.0
	var w := (size.x - 2.0 * x0 - STAT_GAP) / 2.0
	var top := square_rect().end.y + 2.0
	return Rect2(x0 + i * (w + STAT_GAP), top, w, size.y - FRAME_W - 2.0 - top)


func bar_rect(i: int) -> Rect2:
	var s := stat_rect(i)
	return Rect2(s.position.x, s.end.y - BAR_H, s.size.x, BAR_H)


## 카드 바탕색 [위, 아래, 이름 띠, 네모, 글자](쓰러지면 카드 전체가 어두운 회색, jp_guide5_img4).
func card_colors() -> Array[Color]:
	var u := unit()
	if u != null and not u.alive():
		return [UiTheme.CARD_DOWN_TOP, UiTheme.CARD_DOWN_BOTTOM, UiTheme.CARD_DOWN_HEAD, UiTheme.CARD_DOWN_BOTTOM, UiTheme.CARD_DOWN_TEXT]
	return [UiTheme.CARD_TOP, UiTheme.CARD_BOTTOM, UiTheme.CARD_HEAD, UiTheme.CARD_SQUARE, UiTheme.CARD_TEXT]


## 지금 그린 테두리 색(지금 행동하는 대원 = 밝은 시안, 원작의 ゾディアック 카드). 시험용.
func frame_color() -> Color:
	return UiTheme.CARD_ACTIVE if current else UiTheme.CARD_FRAME


func _draw_member(u: BattleDisplay.DUnit) -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	var down := not u.alive()
	var dim := target_mark == "invalid"
	var cols := card_colors()
	# 어두운 틀 + 청록 판(위 → 아래), 머리 줄: 왼쪽 네모 + 밝은 이름 띠.
	draw_rect(r, UiTheme.CARD_FRAME)
	var inner := r.grow(-FRAME_W)
	draw_polygon(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]),
		PackedColorArray([cols[0], cols[0], cols[1], cols[1]]))
	draw_rect(square_rect(), cols[3])
	var band := name_band()
	draw_rect(band, cols[2])
	var fg: Color = cols[4]
	var cmd_w := 0.0
	if not command_text.is_empty() and not down:
		cmd_w = minf(band.size.x * 0.45, font.get_string_size(command_text, HORIZONTAL_ALIGNMENT_LEFT, -1, COMMAND_FS).x)
		draw_string(font, Vector2(band.end.x - 6.0 - cmd_w, band.get_center().y + COMMAND_FS * 0.36), command_text, HORIZONTAL_ALIGNMENT_LEFT,
			cmd_w, COMMAND_FS, COMMAND_TEXT)
	draw_string(font, Vector2(band.position.x + 8.0, band.get_center().y + NAME_FS * 0.36), u.name, HORIZONTAL_ALIGNMENT_LEFT,
		maxf(8.0, band.size.x - 16.0 - cmd_w), NAME_FS, fg)
	# 「HP 63」「TP 50」: 이름표는 왼쪽, 수치는 오른쪽, 그 아래 막대.
	var vals := [roundi(shown_hp) if not down else 0, roundi(shown_tp)]
	var maxes := [u.max_hp, u.max_tp]
	var shown := [shown_hp if not down else 0.0, shown_tp]
	for i in 2:
		var s := stat_rect(i)
		var base := s.end.y - BAR_H - 4.0
		draw_string(font, Vector2(s.position.x + 2.0, base), "HP" if i == 0 else "TP", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS, fg if down else UiTheme.CARD_LABEL)
		draw_string(font, Vector2(s.position.x, base), str(vals[i]), HORIZONTAL_ALIGNMENT_RIGHT, s.size.x - 2.0, VALUE_FS, fg)
		var ratio: float = float(shown[i]) / maxf(1.0, float(maxes[i]))
		if i == 0:
			UiTheme.draw_gauge(self, bar_rect(i), ratio, UiTheme.CARD_HP_FROM, UiTheme.CARD_HP_TO)
		else:
			UiTheme.draw_gauge(self, bar_rect(i), ratio, UiTheme.CARD_TP, UiTheme.CARD_TP)
	_draw_chips(drawn_chips())
	drawn = {"fill": cols[0], "head": cols[2], "name_color": fg, "frame": frame_color(), "hp": vals[0], "tp": vals[1],
		"hp_bar": [UiTheme.CARD_HP_FROM, UiTheme.CARD_HP_TO], "tp_bar": UiTheme.CARD_TP}
	# 테두리 표시: 누르는 중(밝은 안쪽 선) · 지금 행동하는 대원(밝은 시안 틀) · 대상(노랑) · 키보드 커서(흰 안쪽 선).
	if current:
		draw_rect(r.grow(-1.5), UiTheme.CARD_ACTIVE, false, 3.0)
	if held:
		draw_rect(r.grow(-5.0), UiTheme.BTN_HELD_BORDER, false, 2.0)
	if target_mark == "valid" or target_mark == "lit":
		var tw := 4.0 if target_mark == "lit" or cursor else 3.0
		draw_rect(r.grow(-tw * 0.5), Color(1.0, 0.95, 0.55), false, tw)
	if cursor and target_mark != "invalid":
		draw_rect(r.grow(-6.0), Color(1, 1, 1, 0.9), false, 2.0)
	if dim:
		draw_rect(r, Color(0, 0, 0, 0.45))
		if not reason.is_empty():
			draw_string_outline(font, Vector2(0, size.y * 0.5 + 6), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, 5, Color(0, 0, 0, 0.9))
			draw_string(font, Vector2(0, size.y * 0.5 + 6), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, REASON_TEXT)


## 적 자리 상자(색 상자 그대로).
func _box(r: Rect2, bg: Color, border: Color, bw: int) -> void:
	UiTheme.fill_round(self, r, bg, 14, border, bw)


func _bar(r: Rect2, ratio: float, color: Color, dim: bool) -> void:
	draw_rect(r, Color(0.05, 0.07, 0.09, 0.95))
	var c := color if not dim else color.darkened(0.55)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), c)
	draw_rect(r, Color(0.45, 0.52, 0.56), false, 1.0)


## 딱지를 놓을 자리(칸 안 좌표). 적: 칸 아래쪽 두 줄. 아군: 머리 줄 왼쪽 네모(원작 카드의 네모 자리).
func chip_area() -> Rect2:
	if is_enemy():
		var h := CHIP_H * 2.0 + CHIP_GAP
		return Rect2(8, size.y - 8.0 - h, size.x - 16, h)
	return square_rect()


## 실제로 그리는 딱지: [{text, kind, rect}]. 다 못 놓으면 마지막이 {kind: "more", text: "+N", hidden: N}.
## 아군 카드는 네모 하나에 첫 상태(글자 첫 자, 종류 색)와 그 아래 「+N」(나머지 수)만 둔다. 전체는 로그 창 위 상태 목록에서 본다.
## 쓰러진 대원은 딱지가 없다(상태가 지워진다).
func drawn_chips() -> Array[Dictionary]:
	var u := unit()
	if u == null or not u.alive():
		return []
	var chips := display.chips(u)
	if is_enemy():
		return layout_chips(chips, chip_area(), get_theme_default_font())
	var out: Array[Dictionary] = []
	if chips.is_empty():
		return out
	var sq := square_rect()
	var more := chips.size() - 1
	var first := chips[0].duplicate()
	first["rect"] = Rect2(sq.position, Vector2(sq.size.x, sq.size.y - (MORE_H if more > 0 else 0.0)))
	first["glyph"] = str(first["text"]).left(1)
	out.append(first)
	if more > 0:
		out.append({"text": "+%d" % more, "kind": "more", "hidden": more, "rect": Rect2(sq.position.x, sq.end.y - MORE_H, sq.size.x, MORE_H)})
	return out


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
		if c.has("glyph"):
			draw_rect(r, col)
			draw_string(font, Vector2(r.position.x, r.get_center().y + GLYPH_FS * 0.36), str(c["glyph"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, GLYPH_FS, Color(1, 1, 1))
			continue
		if c["kind"] == "more" and not is_enemy():
			draw_rect(r, col)
			draw_string(font, Vector2(r.position.x, r.end.y - 3.0), str(c["text"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, MORE_FS, Color(1, 1, 1))
			continue
		UiTheme.fill_round(self, r, col, 5)
		var tx := r.position.x + CHIP_PAD
		if c["kind"] == "buff" or c["kind"] == "debuff":
			var cx := r.position.x + CHIP_PAD + 4.0
			var cy := r.position.y + CHIP_H * 0.5
			var pts := PackedVector2Array([Vector2(cx - 4, cy + 4), Vector2(cx + 4, cy + 4), Vector2(cx, cy - 4)]) if c["kind"] == "buff" \
				else PackedVector2Array([Vector2(cx - 4, cy - 4), Vector2(cx + 4, cy - 4), Vector2(cx, cy + 4)])
			draw_colored_polygon(pts, Color(1, 1, 1))
			tx += CHIP_TRI
		draw_string(font, Vector2(tx, r.position.y + CHIP_H - 5.0), str(c["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FS, Color(1, 1, 1))
