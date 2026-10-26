## 확인 창 층(부품 K, 07 §9.9 E2-d): 화면 전체를 어둡게 하는 판 → 양 끝이 굽은 알림 띠(BannerBox) → 글 → 단추 둘(「돌아가기」·다음 일).
## 캠프 확인 창(PartyMenu.dialog_layer)과 같은 자리·크기·이름이다(PartyMenu 의 상수를 그대로 쓴다). M3 A2 타이틀의 새 게임 확인이 쓴다.
## 단추·키는 놓는 쪽의 handle 로 보낸다(route: 고른 단추 번호 0·1). 처음 커서는 0(「돌아가기」, D25 되돌릴 수 없는 물음).
class_name ConfirmBand
extends Control

## 단추 누르기 → 놓는 쪽 입력 입구(번호 0 「돌아가기」 · 1 다음 일).
var route: Callable
var pick := 0
var dim: ColorRect
var panel: BannerBox
var label := Label.new()
var buttons: Array[PartyButton] = []


func _init() -> void:
	name = "Dialog"
	mouse_filter = MOUSE_FILTER_STOP  # 떠 있는 동안 뒤 화면은 포인터를 받지 않는다
	focus_mode = FOCUS_NONE
	visible = false
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim = ColorRect.new()
	dim.name = "DialogDim"
	dim.color = PartyMenu.DIALOG_DIM
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	panel = BannerBox.new()
	panel.name = "DialogPanel"
	add_child(panel)
	label.name = "DialogText"
	label.add_theme_font_size_override("font_size", PartyMenu.DIALOG_TEXT_FS)
	label.add_theme_color_override("font_color", ListParts.BANNER_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	for i in 2:
		var b := PartyButton.new()
		b.name = "DialogBack" if i == 0 else "DialogOk"
		b.skin = "cmd"
		b.size = PartyMenu.DIALOG_BUTTON
		b.activated.connect(func() -> void:
			if route.is_valid():
				route.call(i))
		add_child(b)
		buttons.append(b)


func is_open() -> bool:
	return visible


## 띄운다: 글, 둘째 단추 글, 첫째 단추 글. 커서는 「돌아가기」.
func open(text: String, ok_label: String, back_label: String) -> void:
	label.text = text
	buttons[0].text = back_label
	buttons[1].text = ok_label
	pick = 0
	visible = true
	refresh()


func close() -> void:
	visible = false
	cancel()


func cancel() -> void:
	for b in buttons:
		b.cancel()


func move(d: int) -> void:
	pick = clampi(pick + d, 0, 1)
	refresh()


func refresh() -> void:
	for i in 2:
		buttons[i].selected = i == pick
		buttons[i].queue_redraw()
	panel.queue_redraw()


## 띠 자리(화면 가운데, PartyMenu.dialog_rect 와 같다).
func band_rect() -> Rect2:
	var s := size if size.x > 0.0 else get_viewport_rect().size
	return Rect2(((s - PartyMenu.DIALOG_SIZE) / 2.0).round(), PartyMenu.DIALOG_SIZE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	var dr := band_rect()
	panel.position = dr.position
	panel.size = dr.size
	label.position = dr.position + PartyMenu.DIALOG_TEXT.position
	label.size = PartyMenu.DIALOG_TEXT.size
	var by := dr.position.y + PartyMenu.DIALOG_BUTTONS_TOP
	buttons[1].position = Vector2(dr.end.x - PartyMenu.DIALOG_BUTTONS_RIGHT - PartyMenu.DIALOG_BUTTON.x, by)
	buttons[0].position = Vector2(buttons[1].position.x - PartyMenu.DIALOG_BUTTON_GAP - PartyMenu.DIALOG_BUTTON.x, by)
