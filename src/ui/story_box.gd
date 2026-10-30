## 이야기 상자(M3 A9b 설계 §5.3, 공용 부품 D28): 3D 시야 위에 말하는 사람 + 쪽 글(세 줄까지)을 쪽마다 보여 주는 상자.
## 원작 프레임(EO I HD 축하 화면): 시야 전체, 지도 감춤, 아래 가운데 글 상자, 오른쪽 초상, 상자 오른쪽 끝 넘김 표시.
## 첫 쓰임은 계층 보스 클리어(kind "clear", ModalLayer.open_part): 보이기만 하고 상태·저장을 바꾸지 않는다.
## 트리 순서 = 그리는·누르는 순서: 초상(장식) → 상자(장식, 말 상자 그림 ListParts.draw_desc) → 상자 누르기(투명) → 넘김 단추 → 키패드.
## 상자 자리는 의뢰 화면 말 상자(QuestScreen.BOX_*)와 같다: 양쪽 키패드를 비켜 간다(원작 0.18~0.83 W 와 다른 점, 이름 붙은 차이).
## 넘기기: 상자 누르기·넘김 단추·키패드 선택·취소·Enter·Space·Esc·Backspace 모두 다음 쪽. 마지막 쪽의 다음이 finished.
## 누르기 지킴이 주인(교훈 10): selection_key = ["clear", 쪽]. 쪽이 바뀌면(_refresh 끝 sync) 눌려 있던 단추는 뗄 때 일하지 않는다.
class_name StoryBox
extends Control

## 마지막 쪽에서 넘겼다(부른 쪽이 닫는다).
signal finished

const BOX_LEFT := QuestScreen.BOX_LEFT
const BOX_RIGHT := QuestScreen.BOX_RIGHT
const BOX_H := QuestScreen.BOX_H
const BOX_BOTTOM := QuestScreen.BOX_BOTTOM
## 초상 자리(B6 갈고리 clear.portrait 까지 빈 판): 오른쪽 W−520…W−40, 위 40 … 키패드 위 8px(설계는 H−200, 키패드를 덮지 않게 줄였다).
const PORTRAIT := Vector4(-520, 40, -40, QuestScreen.PAD_KEYS_AT.y - 8.0)
## 넘김 단추(상자 오른쪽 아래, 64 이상).
const NEXT_SIZE := Vector2(96, 64)
const NEXT_INSET := 8.0
const LINES := 3
const PAD_DIR := QuestScreen.PAD_DIR
const PAD_KEYS_AT := QuestScreen.PAD_KEYS_AT
const PORTRAIT_FILL := Color(0.05, 0.12, 0.2, 0.82)
const PORTRAIT_EDGE := Color(0.45, 0.78, 0.95, 0.9)

var texts: TextDb
var speaker := ""
var pages: Array[String] = []
var page := 0
var press_guard := PressGuard.new(self)
## 마지막 그리기의 글(시험·디버그, 교훈 2): 머리(말하는 사람)와 몸 줄.
var drawn_head := ""
var drawn_lines: Array[String] = []

var portrait: Control
var box: Control
var tap: TouchButton
var next_button: TouchButton
var dir_pad: VirtualPad
var key_pad: VirtualPad
var _built := false


## 투명한 누르기 칸(상자 전체 = 다음 쪽). 모양은 상자가 그린다.
class _Tap extends TouchButton:
	func _draw() -> void:
		pass


func _init() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE  # 상자 밖(시야)은 누르기를 받지 않는다: 뒤 화면은 창 층(ModalLayer)이 막는다
	focus_mode = FOCUS_NONE


func build(text_db: TextDb) -> void:
	if _built:
		return
	_built = true
	texts = text_db
	name = "StoryBox"
	portrait = _deco("StoryPortrait", Vector2(1, 0), Vector2(1, 1), PORTRAIT)
	portrait.draw.connect(_draw_portrait)
	box = _deco("StoryPanel", Vector2(0, 1), Vector2(1, 1), Vector4(BOX_LEFT, -BOX_BOTTOM - BOX_H, -BOX_RIGHT, -BOX_BOTTOM))
	box.draw.connect(_draw_box)
	tap = _Tap.new()
	tap.name = "StoryTap"
	add_child(tap)
	PartyMenu.place(tap, Vector2(0, 1), Vector2(1, 1), Vector4(BOX_LEFT, -BOX_BOTTOM - BOX_H, -BOX_RIGHT, -BOX_BOTTOM))
	tap.activated.connect(next)
	next_button = TouchButton.new().setup("", "")
	next_button.name = "StoryNext"
	add_child(next_button)
	var nx := -BOX_RIGHT - NEXT_INSET
	var ny := -BOX_BOTTOM - NEXT_INSET
	PartyMenu.place(next_button, Vector2(1, 1), Vector2(1, 1), Vector4(nx - NEXT_SIZE.x, ny - NEXT_SIZE.y, nx, ny))
	next_button.activated.connect(next)
	dir_pad = VirtualPad.new().setup_dirs()
	dir_pad.name = "DirPad"
	key_pad = VirtualPad.new().setup_keys(texts.t("battle.ui.pad_ok"), texts.t("battle.ui.pad_back"))
	key_pad.name = "KeyPad"
	for p in [dir_pad, key_pad]:
		add_child(p)
		(p as VirtualPad).pressed.connect(_on_vpad)
	dir_pad.set_enabled({})  # 방향은 하는 일이 없다(흐림)
	var ds := VirtualPad.dirs_size()
	PartyMenu.place(dir_pad, Vector2(0, 1), Vector2(0, 1), Vector4(PAD_DIR.x, PAD_DIR.y, PAD_DIR.x + ds.x, PAD_DIR.y + ds.y))
	var ks := VirtualPad.keys_size(false)
	PartyMenu.place(key_pad, Vector2(1, 1), Vector2(1, 1), Vector4(PAD_KEYS_AT.x, PAD_KEYS_AT.y, PAD_KEYS_AT.x + ks.x, PAD_KEYS_AT.y + ks.y))


func _deco(n: String, a0: Vector2, a1: Vector2, off: Vector4) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.focus_mode = FOCUS_NONE
	add_child(c)
	PartyMenu.place(c, a0, a1, off)
	return c


## 이야기를 처음 쪽부터 보인다(누르기 지킴이 새로).
func start(who: String, list: Array[String]) -> void:
	assert(_built, "build() 를 먼저 부른다")
	speaker = who
	pages = list.duplicate()
	page = 0
	press_guard.reset()
	_refresh()


## 다음 쪽(마지막 쪽이면 finished).
func next() -> void:
	if pages.is_empty():
		return
	if page >= pages.size() - 1:
		finished.emit()
		return
	page += 1
	_refresh()


func selection_key() -> Array:
	return ["clear", page]


func is_last() -> bool:
	return page >= pages.size() - 1


func _refresh() -> void:
	next_button.text = texts.t("ui.ok") if is_last() else ""
	next_button.icon = "" if is_last() else "down"
	next_button.queue_redraw()
	box.queue_redraw()
	portrait.queue_redraw()
	press_guard.sync()


## 알림 띠가 비켜 갈 사각형: 상자와 초상(띠를 둘 자리가 없으면 화면이 안내를 거둔다).
func band_rect() -> Rect2:
	return box.get_global_rect().merge(portrait.get_global_rect())


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	get_viewport().set_input_as_handled()  # 열린 동안 키는 여기서 끝난다(이동·캠프·지도 키도)
	if k.echo:
		return
	var code := k.physical_keycode
	if code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_BACKSPACE]:
		next()


func _on_vpad(kind: String, _arg: Variant) -> void:
	if kind == "ok" or kind == "back":
		next()


## 몸 줄: 쪽 글을 폭에 맞춰 낱말 단위로 LINES 줄까지 접는다(마지막 줄에 나머지, 넘치면 draw_desc 가 글씨를 줄인다).
func page_lines() -> Array[String]:
	var out: Array[String] = []
	if pages.is_empty():
		return out
	var w := ListParts.line_room(Rect2(Vector2.ZERO, box.size))
	var words := pages[page].split(" ", false)
	var cur := ""
	for word in words:
		var nxt := word if cur.is_empty() else cur + " " + word
		if out.size() < LINES - 1 and not cur.is_empty() and SheetParts.text_width(box, nxt, ListParts.DESC_FS) > w:
			out.append(cur)
			cur = word
		else:
			cur = nxt
	if not cur.is_empty():
		out.append(cur)
	return out


func _draw_box() -> void:
	SheetParts.begin(box)
	drawn_head = speaker
	drawn_lines = page_lines()
	ListParts.draw_desc(box, Rect2(Vector2.ZERO, box.size), speaker, "", drawn_lines)


## 초상 자리(빈 판, B6 가 그림을 넣는다).
func _draw_portrait() -> void:
	var r := Rect2(Vector2.ZERO, portrait.size)
	portrait.draw_rect(r, PORTRAIT_FILL)
	portrait.draw_rect(r, PORTRAIT_EDGE, false, 2.0)


## 디버그 스냅숏: 쪽·쪽 수·말하는 사람·그린 몸 줄.
func debug_info() -> Dictionary:
	return {"page": page, "pages": pages.size(), "speaker": drawn_head, "lines": drawn_lines.duplicate(), "last": is_last()}
