## 가상 키패드(사용자 제안 2026-10-25, 전투 먼저·캠프에서 다시 쓴다): 방향 십자(setup_dirs) 또는 「선택」·「취소」 한 쌍(setup_keys).
## 두 묶음을 따로 만들어 화면마다 다른 자리에 앵커로 붙인다(전투: 방향 = 왼쪽 아래, 선택·취소 = 미니맵 위).
## 모양은 탐색 이동 단추와 같은 TouchButton(기본 모양, 방향은 VectorIcons up·down·left·right). 단추마다 64×64 이상.
## 누르기는 pressed 하나로 보낸다: ("move", Vector2i) · ("ok", null) · ("back", null). 받는 화면이 같은 키 입력 입구(handle)로 넘긴다.
## 방향은 누르는 순간(탐색 이동 단추와 같음), 선택·취소는 단추 안에서 뗄 때(목록 줄과 같음). 누르고 있기 반복은 없다.
## 흐린 단추(set_enabled 로 끈 것)는 눌러도 아무 일도 하지 않는다(TouchButton.disabled). 포인터 소유권·취소는 TouchButton 규칙 그대로:
## 화면이 문맥을 바꿀 때 모든 TouchButton 을 cancel 하면 이 단추들도 함께 취소된다. 어느 화면도 가리키지 않는다(전투·캠프가 같이 쓴다).
class_name VirtualPad
extends Control

## kind: "move"(arg Vector2i) · "ok" · "back"
signal pressed(kind: String, arg: Variant)

## 방향 단추 한 변·간격. 십자 전체 = 3 × BUTTON + 2 × GAP.
const BUTTON := 64.0
const GAP := 4.0
const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
## 선택·취소 단추 크기와 사이(가로: 왼쪽 취소·오른쪽 선택, 전체 폭 = 2 × KEY.x + KEY_GAP = 전투 미니맵 폭 227.
## 세로: 위 취소·아래 선택, 폭 KEY.x — 캠프의 좁은 오른쪽 칸용).
const KEY := Vector2(110, 72)
const KEY_GAP := 7.0

## "dirs" · "keys"
var mode := ""
## 선택·취소를 세로로 쌓았는지.
var vertical := false
## 이름(up·down·left·right·ok·back) → 단추.
var buttons := {}


## 부모가 스크립트가 아닌 Control(엔진 클래스)이라 super() 를 부르지 않는다: Godot 4.7 은 부모 스크립트에 _init 이 없으면
## 「Cannot call the parent class' virtual function "_init()" because it hasn't been defined」 로 읽기를 거부한다.
## 「_init 은 super() 먼저」 규칙은 스크립트 부모(TouchButton·MapPanel 등)를 이을 때의 것이다.
func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE  # 묶음 자체는 누르기를 받지 않는다(단추 사이 빈 곳은 뒤 화면이 받는다)
	focus_mode = FOCUS_NONE


static func dirs_size() -> Vector2:
	return Vector2.ONE * (3.0 * BUTTON + 2.0 * GAP)


static func keys_size(stacked: bool = false) -> Vector2:
	return Vector2(KEY.x, 2.0 * KEY.y + KEY_GAP) if stacked else Vector2(2.0 * KEY.x + KEY_GAP, KEY.y)


## 방향 십자: 위 · 왼쪽 · 오른쪽 · 아래(가운데 칸은 비운다).
func setup_dirs() -> VirtualPad:
	mode = "dirs"
	size = dirs_size()
	var step := BUTTON + GAP
	var at := {"up": Vector2(step, 0), "left": Vector2(0, step), "right": Vector2(2 * step, step), "down": Vector2(step, 2 * step)}
	for k in ["up", "left", "right", "down"]:
		var b := _add(k, TouchButton.new().setup(k, "", true))
		b.position = at[k]
		b.size = Vector2(BUTTON, BUTTON)
		var dir: Vector2i = DIRS[k]
		b.activated.connect(func() -> void: pressed.emit("move", dir))
	return self


## 「선택」·「취소」 한 쌍(글은 화면이 준다: 이 부품은 문구 표를 모른다).
func setup_keys(ok_text: String, back_text: String, stacked: bool = false) -> VirtualPad:
	mode = "keys"
	vertical = stacked
	size = keys_size(stacked)
	var back := _add("back", TouchButton.new().setup("", back_text))
	back.position = Vector2.ZERO
	back.size = KEY
	back.activated.connect(func() -> void: pressed.emit("back", null))
	var ok := _add("ok", TouchButton.new().setup("", ok_text))
	ok.position = Vector2(0, KEY.y + KEY_GAP) if stacked else Vector2(KEY.x + KEY_GAP, 0)
	ok.size = KEY
	ok.activated.connect(func() -> void: pressed.emit("ok", null))
	return self


func _add(k: String, b: TouchButton) -> TouchButton:
	b.name = "VPad_" + k
	add_child(b)
	buttons[k] = b
	return b


func button(k: String) -> TouchButton:
	return buttons.get(k)


## 켤 단추: 이름 → 참(없는 이름은 끈다 = 흐림). 끄는 단추의 눌림은 버린다.
func set_enabled(on: Dictionary) -> void:
	for k in buttons:
		var b: TouchButton = buttons[k]
		var want := not bool(on.get(k, false))
		if b.disabled != want:
			b.disabled = want


func cancel() -> void:
	for k in buttons:
		(buttons[k] as TouchButton).cancel()
