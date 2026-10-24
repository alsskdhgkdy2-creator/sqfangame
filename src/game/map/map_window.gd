## 지도 판(05 §7, 원작 HD guide4·nin_02·nin_04): 화면 오른쪽 가장자리에 붙어 위에서 아래까지 3D 시야 위에 덮이는 불투명 판.
## 판 안(앵커로 놓는다):
## - 위쪽 SPLIT(53.5%): 층 전체 보기(MapOverview, 구역 자 + 그리기 격자 범위). 아이콘 도구일 때는 그 자리에 아이콘 판(6열).
## - 아래쪽: 그리기 격자(MapPanel), 그 오른쪽 위에 「돌아가기」(원작 BACK, 지도를 닫는다).
## - 맨 오른쪽: 세로 도구 열(MapToolbar). 원작은 층 전체 보기 옆까지만 내려오지만 도구 일곱 개(64px)가 들어가도록
##   그리기 격자 옆 빈 띠까지 이어진다(그리기 격자 폭은 원작과 같다).
## 판 자체는 누르기를 받아 아래 3D 시야로 흘리지 않는다(MOUSE_FILTER_STOP).
class_name MapWindow
extends Control

## 「돌아가기」를 눌렀다(지도를 닫는다).
signal back_requested
## 아이콘 판에서 아이콘을 골랐다.
signal icon_chosen(icon: String)

## 판 폭(기준 해상도 px): 1280×720 에서 43%(nin_02 실측 730~1280). 넓은 화면에서도 이 폭이고 남는 폭은 시야가 쓴다.
const WIDTH := 550.0
## 층 전체 보기 : 그리기 격자 = 53.5 : 46.5(nin_02 실측 0~385 / 390~720).
const SPLIT := 0.535
const MARGIN := 4.0
const ICON_COLS := 6
const ICON_GAP := 8.0
const BACK_W := 120.0
## 그리기 격자의 기본 확대: 폭에 약 7칸(nin_02 실측: 격자 폭 ~470px 에 칸 ~66px).
const HOME_COLUMNS := 7
## 색(nin_02 에서 뽑음): 판 바탕 남색, 바깥 테두리 청록, 칸 나눔·그리기 격자 테두리 초록 청록, 도구 열 바탕 파랑.
const FILL := Color("032b4e")
const EDGE := Color("10a6c9")
const SEPARATOR := Color("18cda0")
const COLUMN_FILL := Color("2f6796")

var overview := MapOverview.new()
var map := MapPanel.new()
var toolbar := MapToolbar.new()
var icon_palette := GridContainer.new()
var back_button: TouchButton
## 아이콘 이름 → 아이콘 판 단추.
var icon_buttons := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	focus_mode = FOCUS_NONE


func build(texts: TextDb, floor_name: String) -> void:
	set_anchors_preset(PRESET_RIGHT_WIDE)
	offset_left = -WIDTH
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = 0.0

	overview.name = "MapOverview"
	overview.setup(false, map)
	_place(overview, Vector2(0, 0), Vector2(1, SPLIT), Vector4(MARGIN, MARGIN, -MapToolbar.WIDTH, -MARGIN / 2.0))
	add_child(overview)

	icon_palette.name = "IconPalette"
	icon_palette.columns = ICON_COLS
	icon_palette.add_theme_constant_override("h_separation", int(ICON_GAP))
	icon_palette.add_theme_constant_override("v_separation", int(ICON_GAP))
	icon_palette.mouse_filter = MOUSE_FILTER_IGNORE
	icon_palette.visible = false
	for t in MapAnnotation.ICONS:
		var b := TouchButton.new().setup(t)
		b.name = "Icon_" + t
		b.custom_minimum_size = Vector2(MapToolbar.BUTTON, MapToolbar.BUTTON)
		b.activated.connect(func() -> void: icon_chosen.emit(t))
		icon_palette.add_child(b)
		icon_buttons[t] = b
	_place(icon_palette, Vector2(0, 0), Vector2(1, SPLIT), Vector4(MARGIN + 12.0, MARGIN + 12.0, -MapToolbar.WIDTH, -MARGIN / 2.0))
	add_child(icon_palette)

	map.name = "MapPanel"
	map.home_columns = HOME_COLUMNS
	_place(map, Vector2(0, SPLIT), Vector2(1, 1), Vector4(MARGIN, MARGIN / 2.0, -MapToolbar.WIDTH, -MARGIN))
	add_child(map)

	back_button = TouchButton.new().setup("", texts.t("map.back"))
	back_button.name = "MapBack"
	back_button.skin = "pill"
	back_button.activated.connect(func() -> void: back_requested.emit())
	_place(back_button, Vector2(1, SPLIT), Vector2(1, SPLIT),
		Vector4(-MapToolbar.WIDTH - 6.0 - BACK_W, MARGIN / 2.0 + 6.0, -MapToolbar.WIDTH - 6.0, MARGIN / 2.0 + 6.0 + MapToolbar.BUTTON))
	add_child(back_button)

	toolbar.name = "MapToolbar"
	toolbar.build(texts, floor_name)
	_place(toolbar, Vector2(1, 0), Vector2(1, 1), Vector4(-MapToolbar.WIDTH, 0, 0, 0))
	add_child(toolbar)


## 앵커(왼쪽 위·오른쪽 아래 비율)와 여백(left, top, right, bottom).
static func _place(c: Control, a0: Vector2, a1: Vector2, off: Vector4) -> void:
	c.anchor_left = a0.x
	c.anchor_top = a0.y
	c.anchor_right = a1.x
	c.anchor_bottom = a1.y
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.z
	c.offset_bottom = off.w


func set_state(s: ExplorationState) -> void:
	map.set_state(s)
	overview.set_state(s)


## 지금 도구를 보인다: 도구 열 강조, 아이콘 도구면 층 전체 보기 대신 아이콘 판.
func show_current(tool: String, color: int, icon_type: String, can_undo: bool) -> void:
	toolbar.show_current(tool, color, icon_type, can_undo)
	var icons := tool == "icon"
	if icon_palette.visible != icons:
		icon_palette.visible = icons
		overview.visible = not icons
		if not icons:
			for t in icon_buttons:
				(icon_buttons[t] as TouchButton).cancel()
	for t in icon_buttons:
		(icon_buttons[t] as TouchButton).selected = icons and t == icon_type


func cancel_all() -> void:
	toolbar.cancel_all()
	back_button.cancel()
	for t in icon_buttons:
		(icon_buttons[t] as TouchButton).cancel()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FILL)
	draw_rect(Rect2(size.x - MapToolbar.WIDTH, 0, MapToolbar.WIDTH, size.y), COLUMN_FILL)
	draw_line(Vector2(1.5, 0), Vector2(1.5, size.y), EDGE, 3.0)
	# 그리기 격자 테두리(원작의 초록 청록 틀)와 층 전체 보기 아래 칸 나눔.
	var g := Rect2(map.position, map.size).grow(2.0)
	draw_rect(g, SEPARATOR, false, 3.0)
	var y := overview.position.y + overview.size.y + 1.0
	draw_line(Vector2(0, y), Vector2(size.x - MapToolbar.WIDTH, y), SEPARATOR, 2.0)
