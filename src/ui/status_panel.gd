## 위험도 게이지와 대원 5명 레벨·HP·TP(05 §6, §9.1, 07 §9.5, M2.6 U9). 상태를 읽기만 한다.
class_name StatusPanel
extends Control

const GAUGE_COLORS := {"blue": Color(0.25, 0.55, 1.0), "yellow": Color(1.0, 0.82, 0.2), "red": Color(1.0, 0.25, 0.25)}
const X0 := 14.0
const GAUGE_Y := 14.0
const GAUGE_H := 18.0
const GAUGE_LABEL_W := 90.0
## 위험도 막대와 첫 줄 사이.
const ROWS_GAP := 12.0
const BOTTOM_PAD := 6.0
const COL_GAP := 8.0
## 막대 열이 줄 폭에서 차지하는 몫(값 열·레벨을 빼고 남는 폭이 이보다 좁으면 그 폭, 그래도 BAR_MIN_W 는 남긴다).
const BAR_SHARE := 0.3
const BAR_MIN_W := 40.0
const NAME_FS := 16
## 좁은 꼴에서 이름이 다 들어가게 줄일 수 있는 가장 작은 이름 글자.
const NAME_MIN_FS := 12
const LV_FS := 14
const HP_FS := 15
const TP_FS := 14
## 좁은 꼴에서 쌓는 HP·TP 값 글자 크기.
const STACK_FS := 12
## 넣어 둔 글꼴의 잉크 높이(기준선 위·아래, em): 숫자와 「/」, 한글 이름·「Lv」(fonttools 로 잰 값을 조금 올림).
const VALUE_INK := Vector2(0.8, 0.18)
const TEXT_INK := Vector2(0.85, 0.08)
## TP 값 글자색(TP 막대와 같은 계열, 밝게). 전투 불능 대원 줄의 글자색.
const TP_TEXT := Color(0.62, 0.8, 1.0)
const DOWN_TEXT := Color(0.7, 0.56, 0.56)

var state: ExplorationState
var texts: TextDb
var member_names: Array[String] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 180)


func set_state(s: ExplorationState, text_db: TextDb, names: Array[String]) -> void:
	state = s
	texts = text_db
	member_names = names
	queue_redraw()


func refresh() -> void:
	queue_redraw()


## 대원 칸의 「Lv n」(07 §9.5). 레벨업 뒤 refresh 로 바로 바뀐다.
func level_text(i: int) -> String:
	return texts.t("hud.level", {"level": state.party.members[i].level})


## 대원 i 의 HP 막대 색(HpColor 한 규칙).
func hp_bar_color(i: int) -> Color:
	var m: PartyState.Member = state.party.members[i]
	return HpColor.of(m.hp, m.max_hp)


## 위험도 막대 자리.
func gauge_rect() -> Rect2:
	return Rect2(X0 + GAUGE_LABEL_W, GAUGE_Y, size.x - 2.0 * X0 - GAUGE_LABEL_W, GAUGE_H)


## 대원 i 의 줄 자리(위험도 막대 아래를 대원 수로 나눈다).
func row_rect(i: int) -> Rect2:
	var top := GAUGE_Y + GAUGE_H + ROWS_GAP
	var row_h := (size.y - top - BOTTOM_PAD) / maxf(1.0, state.party.members.size())
	return Rect2(X0, top + row_h * i, size.x - 2.0 * X0, row_h)


func hp_text(i: int) -> String:
	var m: PartyState.Member = state.party.members[i]
	return "%d/%d" % [m.hp, m.max_hp]


func tp_text(i: int) -> String:
	var m: PartyState.Member = state.party.members[i]
	return "%d/%d" % [m.tp, m.max_tp]


## 모든 줄이 같이 쓰는 열 폭(글꼴로 잰다): 가장 긴 이름·「Lv n」, 값은 「최대/최대」(HP 가 줄어도 열이 흔들리지 않는다).
## 넓은 꼴은 HP_FS·TP_FS, 좁은 꼴은 STACK_FS 로 잰 값 폭도 함께. compact: 넓은 꼴로는 가장 긴 이름과 BAR_MIN_W 막대가
## 한 줄에 함께 들어가지 않는다(지도를 닫은 300px 옆 칸에 레벨 30·세 자리 HP/TP 등).
func columns() -> Dictionary:
	var font := get_theme_default_font()
	var c := {"name": 0.0, "level": 0.0, "hp": 0.0, "tp": 0.0, "stack": 0.0}
	for k in state.party.members.size():
		var m: PartyState.Member = state.party.members[k]
		var hp := "%d/%d" % [m.max_hp, m.max_hp]
		var tp := "%d/%d" % [m.max_tp, m.max_tp]
		c["name"] = maxf(c["name"], font.get_string_size(_name(k), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FS).x)
		c["level"] = maxf(c["level"], font.get_string_size(level_text(k), HORIZONTAL_ALIGNMENT_LEFT, -1, LV_FS).x)
		c["hp"] = maxf(c["hp"], font.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, HP_FS).x)
		c["tp"] = maxf(c["tp"], font.get_string_size(tp, HORIZONTAL_ALIGNMENT_LEFT, -1, TP_FS).x)
		for t in [hp, tp]:
			c["stack"] = maxf(c["stack"], font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, STACK_FS).x)
	var w := size.x - 2.0 * X0
	c["compact"] = w - c["tp"] - c["hp"] - c["level"] - c["name"] - 4.0 * COL_GAP < BAR_MIN_W
	c["name_fs"] = NAME_FS
	if c["compact"]:
		# 좁은 꼴에서도 이름이 다 들어가지 않으면 이름 글자만 NAME_MIN_FS 까지 줄인다(이름을 자르지 않는다).
		var room: float = w - c["stack"] - c["level"] - 3.0 * COL_GAP - BAR_MIN_W
		while c["name"] > room and c["name_fs"] > NAME_MIN_FS:
			c["name_fs"] -= 1
			c["name"] = 0.0
			for k in state.party.members.size():
				c["name"] = maxf(c["name"], font.get_string_size(_name(k), HORIZONTAL_ALIGNMENT_LEFT, -1, c["name_fs"]).x)
	return c


## 글자 하나의 잉크 상자(글자 칸 x·폭, 기준선 base, 위·아래 잉크 비율 ink).
static func _ink(x: float, w: float, base: float, fs: int, ink: Vector2) -> Rect2:
	return Rect2(x, base - ink.x * fs, w, (ink.x + ink.y) * fs)


## 줄 하나의 칸들(모든 줄이 같은 열을 쓴다). Rect2: name · level · hp_value · tp_value(글자의 잉크 상자: 글자 칸 폭 × 잉크 높이),
## hp_bar · tp_bar. 그리기 값: text_base(이름·레벨 기준선) · hp_base · tp_base · hp_fs · tp_fs · compact.
## 넓은 꼴: 오른쪽 끝부터 TP 값 · HP 값 · 막대(HP 아래 더 가는 TP) · 레벨, 이름은 왼쪽에서 남는 폭. 막대는 줄 폭의 BAR_SHARE 까지,
## 좁으면 가장 긴 이름이 들어갈 만큼 줄인다(BAR_MIN_W 는 남긴다).
## 좁은 꼴(columns().compact): 값 열 하나에 HP 값(위)·TP 값(아래)을 STACK_FS 로 쌓고 막대도 그 두 줄에 맞춘다. 이름은 늘 다 보인다
## (그래도 안 들어가면 이름 글자를 name_fs 로 줄인다).
func row_layout(i: int, cols: Dictionary = {}) -> Dictionary:
	var c := cols if not cols.is_empty() else columns()
	var r := row_rect(i)
	var compact: bool = c["compact"]
	var text_base := r.position.y + r.size.y * 0.7
	var hp_fs := STACK_FS if compact else HP_FS
	var tp_fs := STACK_FS if compact else TP_FS
	var right := r.end.x
	var hp_x: float
	var hp_w: float
	var tp_x: float
	var tp_w: float
	var hp_base := text_base
	var tp_base := text_base
	if compact:
		hp_w = c["stack"]
		tp_w = c["stack"]
		hp_x = right - hp_w
		tp_x = hp_x
		# 두 값 줄의 잉크를 줄 높이 안에 고르게 둔다(위 여백 · 사이 · 아래 여백이 같다).
		var ink := (VALUE_INK.x + VALUE_INK.y) * STACK_FS
		var m := maxf(0.0, (r.size.y - 2.0 * ink) / 3.0)
		hp_base = r.position.y + m + VALUE_INK.x * STACK_FS
		tp_base = hp_base + ink + m
	else:
		tp_w = c["tp"]
		hp_w = c["hp"]
		tp_x = right - tp_w
		hp_x = tp_x - COL_GAP - hp_w
	var bar_right := hp_x - COL_GAP
	var room: float = bar_right - r.position.x - c["level"] - 2.0 * COL_GAP - c["name"]
	var bar_w := maxf(BAR_MIN_W, minf(r.size.x * BAR_SHARE, room))
	var bar_x := bar_right - bar_w
	var lv_x: float = bar_x - COL_GAP - c["level"]
	var name_w := maxf(0.0, lv_x - COL_GAP - r.position.x)
	var hp_bar: Rect2
	var tp_bar: Rect2
	if compact:
		var hp_mid := hp_base - (VALUE_INK.x - VALUE_INK.y) * STACK_FS * 0.5
		var tp_mid := tp_base - (VALUE_INK.x - VALUE_INK.y) * STACK_FS * 0.5
		hp_bar = Rect2(bar_x, hp_mid - r.size.y * 0.15, bar_w, r.size.y * 0.3)
		tp_bar = Rect2(bar_x, tp_mid - r.size.y * 0.09, bar_w, r.size.y * 0.18)
	else:
		hp_bar = Rect2(bar_x, r.position.y + r.size.y * 0.2, bar_w, r.size.y * 0.36)
		tp_bar = Rect2(bar_x, r.position.y + r.size.y * 0.62, bar_w, r.size.y * 0.2)
	return {
		"name": _ink(r.position.x, name_w, text_base, c["name_fs"], TEXT_INK),
		"level": _ink(lv_x, c["level"], text_base, LV_FS, TEXT_INK),
		"hp_bar": hp_bar,
		"tp_bar": tp_bar,
		"hp_value": _ink(hp_x, hp_w, hp_base, hp_fs, VALUE_INK),
		"tp_value": _ink(tp_x, tp_w, tp_base, tp_fs, VALUE_INK),
		"text_base": text_base, "hp_base": hp_base, "tp_base": tp_base, "hp_fs": hp_fs, "tp_fs": tp_fs, "name_fs": c["name_fs"], "compact": compact,
	}


func _draw() -> void:
	UiTheme.draw_window(self, Rect2(Vector2.ZERO, size))
	if state == null:
		return
	var font := get_theme_default_font()
	var bar := gauge_rect()
	draw_string(font, Vector2(X0, bar.position.y + 14), texts.t("hud.danger"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UiTheme.SUB_TEXT)
	draw_rect(bar, Color(0.1, 0.13, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * state.encounter.gauge(), bar.size.y)), GAUGE_COLORS[state.encounter.gauge_color()])
	draw_rect(bar, Color(0.4, 0.5, 0.55), false, 1.0)
	var cols := columns()
	for i in state.party.members.size():
		var m: PartyState.Member = state.party.members[i]
		var col := UiTheme.TEXT if m.alive() else DOWN_TEXT
		var c := row_layout(i, cols)
		var ty: float = c["text_base"]
		var nr: Rect2 = c["name"]
		var lr: Rect2 = c["level"]
		var hr: Rect2 = c["hp_value"]
		var tr: Rect2 = c["tp_value"]
		draw_string(font, Vector2(nr.position.x, ty), _name(i), HORIZONTAL_ALIGNMENT_LEFT, nr.size.x, c["name_fs"], col)
		draw_string(font, Vector2(lr.position.x, ty), level_text(i), HORIZONTAL_ALIGNMENT_RIGHT, lr.size.x, LV_FS, UiTheme.ACCENT_TEXT if m.alive() else col)
		_bar(c["hp_bar"], m.hp, m.max_hp, hp_bar_color(i))
		_bar(c["tp_bar"], m.tp, m.max_tp, UiTheme.TP_BAR)
		draw_string(font, Vector2(hr.position.x, c["hp_base"]), hp_text(i), HORIZONTAL_ALIGNMENT_RIGHT, hr.size.x, c["hp_fs"], col)
		draw_string(font, Vector2(tr.position.x, c["tp_base"]), tp_text(i), HORIZONTAL_ALIGNMENT_RIGHT, tr.size.x, c["tp_fs"], TP_TEXT if m.alive() else col)


func _name(i: int) -> String:
	return member_names[i] if i < member_names.size() else state.party.members[i].id


func _bar(r: Rect2, v: int, vmax: int, col: Color) -> void:
	draw_rect(r, Color(0.1, 0.13, 0.16))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(float(v) / maxf(1.0, vmax), 0.0, 1.0), r.size.y)), col)
