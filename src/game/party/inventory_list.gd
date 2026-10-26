## 공용 목록(D28): 여러 화면이 같이 쓰는 목록 동작 하나. 캠프 소지품·장비(D28-a), 마을 상점 구매·판매(D28-b)가 자기 자리에 끼워 부른다.
## 노드를 만들지 않고 화면이 둔 끌어 내리는 영역(PartyScroll)에 묶인다(틀·스크롤 막대는 화면 몫: 캠프 ListWindow, 상점 ShopList).
## 맡는 일: 줄 단추 모으기(이름 prefix + 번호), 줄 자료(줄 모델) → 그림(InventoryLook), 줄 자리(한 칸 높이씩), 커서와 그 모양,
## 끝에서 돌지 않는 ↑↓(가려진 커서 되돌림), 크기가 바뀔 때 한 번 되돌림, 누르기 입구, 「선택」 막기, 새 줄에서 눌림 버리기,
## 설명 상자 연결(changed). 화면은 줄 모델을 만들어 set_rows 를 부르고, 화면만의 칸(소지품 알약·보급 단추)은 갈고리로 더한다.
##
## 줄 모델(사전 하나 = 한 칸 높이의 줄 자리 하나):
##   icon·name·right(캠프 개수·상점 값)·count(상점 판매 「n개」)·dim·equipped(「E」)·checked(여러 개 팔기)·new(NEW) = 그림(InventoryLook).
##   press(참): 거짓이면 읽기만 하는 줄(누르기를 받지 않고 커서 칸이 아니다). room(0): 줄 오른쪽에 비워 둘 폭(화면 단추 자리).
##   row(참): 거짓이면 줄 단추가 없는 줄 자리(화면 단추만 놓인다). 그 밖의 키(id·block 등)는 그리지 않고 「줄이 바뀌었는지」에만 쓴다.
## 줄 단추는 row 가 참인 줄만 차례로 쓰므로 줄 단추 번호 = 줄 번호(Row_k 이름이 화면마다 그대로).
class_name InventoryList
extends RefCounted

## 줄 k 를 눌렀다(route 가 없을 때, 커서는 이미 그 줄).
signal picked(i: int)
## 설명 상자 연결: 커서 칸이 바뀌었거나 줄이 바뀌었다(같은 줄을 다시 놓기만 하면 내지 않는다).
signal changed

var scroll: PartyScroll
var look: InventoryLook
## 줄 단추 이름 앞부분.
var prefix := "Row_"
## 새 줄 단추를 내용의 맨 앞(뒤에 그림)에 둔다(화면 단추가 줄 위에 그려지게).
var behind := false
## 있으면 줄 누르기는 route(k) 만 부른다(받을지는 화면 입구가 정하고, 받은 뒤 커서를 옮긴다).
var route: Callable
## 커서 칸 목록 () -> Array[Control]. 없으면 누를 수 있는 보이는 줄 차례.
var stops_hook: Callable
## 칸이 속한 묶음의 위 끝 (Control) -> float(내용 좌표). 없으면 그 칸의 위.
var group_top_hook: Callable
## 「선택」이 할 일이 있는 칸인지 (Control) -> bool. 없으면 늘 참.
var confirmable: Callable
## 줄 단추(앞 used 개를 쓴다).
var rows: Array[PartyButton] = []
var used := 0
## 지금 놓인 줄 모델(깊은 사본).
var data: Array = []
## 커서 칸 번호(stops 차례). 칸이 없으면 -1.
var cursor := 0
## "cursor"(노랑) · "chosen"(그 줄에 대한 창이 떠 있다) · "none"(표시 없음, 커서 자리는 그대로).
var cursor_mode := "cursor"
## 참이면 set_rows 가 다른 줄을 놓을 때마다 커서 칸을 보이게 한다(마을 상점: 진열·값이 바뀌면 커서 줄로, D28-b).
## 거짓(기본, 캠프)이면 보통 다시 그리기는 손으로 내린 자리를 그대로 둔다. 같은 줄을 다시 놓으면 어느 쪽이든 내리지 않는다.
var reveal_on_change := false
var _lines := 0
var _reveal := false
var _view_size := Vector2.ZERO
var _told_stop: Control = null
var _told_cursor := -2


func _init(sc: PartyScroll, lk: InventoryLook, name_prefix: String = "Row_") -> void:
	scroll = sc
	look = lk
	prefix = name_prefix


func pitch() -> float:
	return look.row_h + look.gap


## 줄 자리 k 의 위 끝(내용 좌표). set_rows 전에도 쓴다(화면이 자기 단추를 놓는다).
func line_y(k: int) -> float:
	return k * pitch()


## 줄 단추를 n 개까지 미리 만든다(만들 때부터 있어야 하는 줄: 장비 칸 줄).
func ensure(n: int) -> void:
	while rows.size() < n:
		var r := look.make_row()
		var k := rows.size()
		r.name = prefix + str(k)
		r.scroller = scroll
		r.visible = false
		r.activated.connect(func() -> void: _on_row(k))
		scroll.content.add_child(r)
		if behind:
			scroll.content.move_child(r, 0)
		rows.append(r)


## 보이는 곳 크기가 실제로 바뀌면 refresh 를 부르고, 다음 set_rows 가 커서 칸(묶음)을 한 번 보이게 한다.
## refresh 는 화면이 그릴 수 있는지(상태가 있고 보이는지)를 스스로 본다. 보통 다시 그리기는 손으로 내린 자리를 그대로 둔다.
func watch_resize(refresh: Callable) -> void:
	scroll.resized.connect(func() -> void: _on_resized(refresh))


func _on_resized(refresh: Callable) -> void:
	if scroll.size == _view_size:
		return
	_view_size = scroll.size
	_reveal = true
	refresh.call()


## 줄을 놓는다. 자료가 바뀌었으면 눌려 있던 줄·끌기를 버리고(07 §9.4) 다시 그리고, 같으면 그림은 그대로 둔다.
## 자리·내용 높이·커서 맞춤·커서 표시는 늘 다시 하고, 크기가 바뀐 뒤라면(reveal_on_change 면 줄이 바뀌어도) 커서 칸을 한 번 보이게 한다.
func set_rows(models: Array) -> void:
	var fresh := models != data
	if fresh:
		cancel()
		data = models.duplicate(true)
	_lines = data.size()
	var k := 0
	var w := scroll.size.x
	for i in _lines:
		var m: Dictionary = data[i]
		if not bool(m.get("row", true)):
			continue
		ensure(k + 1)
		var r := rows[k]
		if fresh:
			r.visible = true
			look.paint(r, m)
			var press := bool(m.get("press", true))
			r.mouse_filter = Control.MOUSE_FILTER_STOP if press else Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(0, line_y(i))
		r.size = Vector2(w - float(m.get("room", 0.0)), look.row_h)
		k += 1
	used = k
	for j in range(used, rows.size()):
		_hide_row(rows[j])
	scroll.set_content_height(maxf(0.0, _lines * pitch() - look.gap))
	var st := stops()
	cursor = -1 if st.is_empty() else clampi(cursor, 0, st.size() - 1)
	_mark(st)
	if (_reveal or (reveal_on_change and fresh)) and cursor >= 0:
		show(st[cursor])
	_reveal = false
	_tell(fresh)


## 다른 목록이 같은 자리를 쓴다(장비 칸 줄 ↔ 후보 줄): 줄을 모두 감추고 눌림·표시를 지운다. 다음 set_rows 는 새 줄로 친다.
func hide() -> void:
	for r in rows:
		_hide_row(r)
	used = 0
	data = []
	_lines = 0
	_told_stop = null
	_told_cursor = -2


func _hide_row(r: PartyButton) -> void:
	if r.visible:
		r.cancel()
	r.visible = false
	look.mark(r, false, cursor_mode)


## 줄 k 가 누를 수 있는 줄인지(읽기만 하는 줄이 아님).
func pressable(k: int) -> bool:
	return k >= 0 and k < used and rows[k].mouse_filter != Control.MOUSE_FILTER_IGNORE


func stops() -> Array[Control]:
	if stops_hook.is_valid():
		return stops_hook.call()
	var out: Array[Control] = []
	for k in used:
		if pressable(k):
			out.append(rows[k])
	return out


func cursor_stop() -> Control:
	var st := stops()
	return st[cursor] if cursor >= 0 and cursor < st.size() else null


## ↑↓ 가 갈 칸이 있는지(칸이 없으면 흐림, 끝에서는 켜 둔다).
func can_move() -> bool:
	return not stops().is_empty()


## 「선택」이 할 일이 있는지(키패드 「선택」 = 키).
func can_confirm() -> bool:
	var c := cursor_stop()
	return c != null and (not confirmable.is_valid() or bool(confirmable.call(c)))


## ↑↓ 하나: 칸 사이(돌지 않음), 커서 칸(묶음)이 다 보이게 내린다. 끝에서는 옮기지 않는다: 커서 칸이 손으로 내려 가려져 있으면
## 보이게만 하고(입력 하나로 센다), 다 보이면 아무 일 없다.
func move(d: int) -> bool:
	var st := stops()
	if st.is_empty() or cursor < 0:
		return false
	var to := cursor + d
	if to < 0 or to >= st.size():
		if shown(st[cursor]):
			return false
		show(st[cursor])
		return true
	cursor = to
	show(st[cursor])
	_mark(st)
	_tell(false)
	return true


## 커서를 칸 c 로(누른 칸). reveal 이면 그 묶음이 보이게 내린다. c 가 칸이 아니면 false.
func point(c: Control, reveal: bool = true) -> bool:
	var st := stops()
	var k := st.find(c)
	if k < 0:
		return false
	cursor = k
	if reveal:
		show(c)
	_mark(st)
	_tell(false)
	return true


## 커서를 칸 k 로(칸 수 안으로 맞추고 보이게).
func set_cursor(k: int) -> void:
	var st := stops()
	cursor = -1 if st.is_empty() else clampi(k, 0, st.size() - 1)
	if cursor >= 0:
		show(st[cursor])
	_mark(st)
	_tell(false)


## 커서 칸 k, 목록 맨 위(화면에 들어올 때·목록을 열고 닫을 때·탭을 바꿀 때).
func reset(k: int = 0) -> void:
	cursor = k
	scroll.scroll_to(0.0)


## 「선택」: 할 일이 없으면(칸 없음·confirmable 거짓) 아무것도 바꾸지 않고 false(가려진 커서도 되돌리지 않는다).
## 있으면 커서 칸(묶음)을 보이게 한 뒤 press(칸) 의 결과.
func confirm(press: Callable) -> bool:
	if not can_confirm():
		return false
	var c := cursor_stop()
	show(c)
	return bool(press.call(c))


func set_cursor_mode(m: String) -> void:
	cursor_mode = m
	_mark(stops())


## 칸이 속한 묶음의 위 끝(내용 좌표).
func group_top(c: Control) -> float:
	return float(group_top_hook.call(c)) if group_top_hook.is_valid() else c.position.y


## 칸(묶음)을 다 보이게 내린다. 목록 밖 칸(소지품 알약)은 그대로.
func show(c: Control) -> void:
	if c == null or c.get_parent() != scroll.content:
		return
	scroll.ensure_visible(group_top(c), c.position.y + c.size.y)


## 칸(묶음)이 보이는 곳 안에 다 있는지. 목록 밖 칸은 늘 참.
func shown(c: Control) -> bool:
	if c == null or c.get_parent() != scroll.content:
		return true
	var top := group_top(c)
	return scroll.shows(Rect2(0, top, 1, c.position.y + c.size.y - top))


func show_at(k: int) -> void:
	var st := stops()
	if k >= 0 and k < st.size():
		show(st[k])


func shown_at(k: int) -> bool:
	var st := stops()
	return k < 0 or k >= st.size() or shown(st[k])


## 눌려 있던 포인터를 모두 버린다(줄이 바뀔 때·문맥이 바뀔 때, 07 §9.4).
func cancel() -> void:
	scroll.cancel()
	for r in rows:
		r.cancel()


func _on_row(k: int) -> void:
	if k >= used:
		return
	if route.is_valid():
		route.call(k)
		return
	if point(rows[k]):
		picked.emit(k)


## 커서 표시: 줄 단추와 칸 모두, 커서 칸 하나만.
func _mark(st: Array[Control]) -> void:
	var at: Control = st[cursor] if cursor >= 0 and cursor < st.size() else null
	for k in used:
		look.mark(rows[k], rows[k] == at, cursor_mode)
	for c in st:
		if c is PartyButton:
			look.mark(c as PartyButton, c == at, cursor_mode)


func _tell(fresh: bool) -> void:
	var at := cursor_stop()
	if not fresh and at == _told_stop and cursor == _told_cursor:
		return
	_told_stop = at
	_told_cursor = cursor
	changed.emit()
