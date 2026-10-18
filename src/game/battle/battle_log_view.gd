## 전투 로그 창(06 §9.4): 지난 100줄(화면 메모리에만, 저장하지 않음). 열려 있는 동안 전투 층은 명령 입력을 막는다.
## 디버그 주소에서는 줄마다 판정 이유를 펼쳐 보인다(전투 층이 줄에 붙여 넣는다).
class_name BattleLogView
extends Control

signal close_requested

const MAX_LINES := 100

var lines: Array[String] = []
var close_button: BattleButton
var _scroll := ScrollContainer.new()
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
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.focus_mode = FOCUS_NONE
	add_child(_scroll)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 17)
	_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_label.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.add_child(_label)
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


func scroll_by(step: int) -> void:
	_scroll.scroll_vertical += step * 60


func _refresh() -> void:
	_label.text = "\n".join(lines)
	# 맨 아래(가장 최근)로
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _layout() -> void:
	status_label.position = Vector2(16, 12)
	status_label.size = Vector2(maxf(10.0, size.x - 32), 10)
	var status_h := 0.0
	if not status_label.text.is_empty():
		status_h = status_label.get_line_count() * status_label.get_line_height() + 4.0
	status_label.size.y = maxf(10.0, status_h)
	var top := 16.0 + (status_h + 8.0 if status_h > 0.0 else 0.0)
	_scroll.position = Vector2(16, top)
	_scroll.size = Vector2(maxf(10.0, size.x - 32), maxf(10.0, size.y - top - 88))
	_label.custom_minimum_size = Vector2(_scroll.size.x - 16, 0)
	close_button.position = Vector2(size.x - 176, size.y - 80)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and close_button != null:
		_layout()


func _draw() -> void:
	UiTheme.draw_window(self, Rect2(Vector2.ZERO, size))
