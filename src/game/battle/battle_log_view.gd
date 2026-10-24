## 전투 로그 창(06 §9.4): 지난 100줄(화면 메모리에만, 저장하지 않음). 열려 있는 동안 전투 층은 명령 입력을 막는다.
## 디버그 주소에서는 줄마다 판정 이유를 펼쳐 보인다(전투 층이 줄에 붙여 넣는다).
## 줄은 공용 끌어 내리는 영역(PartyScroll)에 둔다: 손가락·마우스 끌기·휠로 내리고, 전투 층의 포인터 취소(문맥 바뀜·바깥 창 열림/닫힘)가
## 끌기도 함께 끊는다(엔진 ScrollContainer 의 스크롤 막대 끌기는 취소할 길이 없어 바깥 창 아래에서도 움직였다, 독립 검토 2차).
## 위치는 오른쪽 가는 막대로 보인다(누르기 없음, 엔진 스크롤 막대 자리).
class_name BattleLogView
extends Control

signal close_requested

const MAX_LINES := 100
## 키보드·키패드 ↑↓ 한 번에 내리는 양, 위치 막대 폭·오른쪽 여백.
const STEP := 60.0
const BAR_W := 4.0
const BAR_GAP := 6.0

var lines: Array[String] = []
var close_button: BattleButton
var _scroll := PartyScroll.new()
var _label := Label.new()
## 지금 상태 전부(전투 층이 열 때 넣는다).
var status_label := Label.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false


func build(texts: TextDb) -> void:
	status_label.name = "LogStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	status_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(status_label)
	_scroll.name = "LogScroll"
	add_child(_scroll)
	_scroll.content.item_rect_changed.connect(queue_redraw)  # 내리면 위치 막대를 다시 그린다
	_label.name = "LogLines"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 17)
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.content.add_child(_label)
	close_button = BattleButton.new()
	close_button.name = "LogClose"
	close_button.setup("", texts.t("menu.close"))
	close_button.size = Vector2(160, 64)
	add_child(close_button)
	close_button.activated.connect(func() -> void: close_requested.emit())
	_layout()


func add_line(t: String) -> void:
	lines.append(t)
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	if visible:
		_refresh()


func clear() -> void:
	lines.clear()
	_refresh()


func open(status: String = "") -> void:
	status_label.text = status
	visible = true
	_layout()
	_refresh()


func close() -> void:
	visible = false
	close_button.cancel()
	_scroll.cancel()


func scroll_by(step: int) -> void:
	_scroll.scroll_by(step * STEP)


## 지금 내린 양(시험·디버그).
func scroll_offset() -> float:
	return _scroll.scroll


func max_scroll() -> float:
	return _scroll.max_scroll()


func _refresh() -> void:
	_label.text = "\n".join(lines)
	_fit_label()
	# 맨 아래(가장 최근)로
	_scroll.scroll_to(_scroll.max_scroll())


## 줄 글의 높이(줄 바꿈 뒤)를 내용 높이로 둔다.
func _fit_label() -> void:
	var w := maxf(10.0, _scroll.size.x - BAR_W - BAR_GAP - 4.0)
	_label.position = Vector2.ZERO
	_label.size = Vector2(w, 0)
	var h := _label.get_minimum_size().y
	_label.size = Vector2(w, h)
	_scroll.set_content_height(h)


func _layout() -> void:
	status_label.position = Vector2(16, 12)
	status_label.size = Vector2(maxf(10.0, size.x - 32), 10)
	var status_h := 0.0
	if not status_label.text.is_empty():
		status_h = status_label.get_minimum_size().y + 4.0  # 줄 간격까지(줄 수 × 줄 높이는 마지막 줄이 로그 첫 줄에 겹쳤다)
	status_label.size.y = maxf(10.0, status_h)
	var top := 16.0 + (status_h + 8.0 if status_h > 0.0 else 0.0)
	_scroll.position = Vector2(16, top)
	_scroll.size = Vector2(maxf(10.0, size.x - 32), maxf(10.0, size.y - top - 88))
	_fit_label()
	close_button.position = Vector2(size.x - 176, size.y - 80)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and close_button != null:
		_layout()


func _draw() -> void:
	UiTheme.draw_window(self, Rect2(Vector2.ZERO, size))
	var bar := scroll_bar_rect()
	if bar.has_area():
		var track := Rect2(bar.position.x, _scroll.position.y, BAR_W, _scroll.size.y)
		draw_rect(track, Color(1, 1, 1, 0.12))
		draw_rect(bar, Color(0.75, 0.92, 1.0, 0.85))


## 위치 막대(이 창 기준). 넘치지 않으면 빈 Rect2.
func scroll_bar_rect() -> Rect2:
	var m := _scroll.max_scroll()
	if m <= 0.0:
		return Rect2()
	var view := _scroll.size.y
	var h := maxf(24.0, view * view / (view + m))
	var y := _scroll.position.y + (view - h) * (_scroll.scroll / m)
	return Rect2(_scroll.position.x + _scroll.size.x - BAR_W, y, BAR_W, h)
