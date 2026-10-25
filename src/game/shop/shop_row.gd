## 상점 목록 한 줄(08 §7.4, 원작 HD 상점 jp_guide3_img1·2): 왼쪽 어두운 아이콘 칸(종류 아이콘) │ 이름(판매는 뒤에 작은 「12개」)
## │ 「NEW」 주황 알약(줄마다 같은 x) │ 오른쪽 맞춤 숫자(값·판매값, 품절이면 「품절」).
## PartyButton 의 입력(뗄 때 한 번, 손가락 소유, 끌기 = 목록 내리기, 휠)과 상태(커서 = 노랑 selected, 흐림 = dimmed,
## 고름 = checked 하늘색)를 그대로 쓰고 그림만 더한다. 캠프 줄 그림(PartyButton._draw)은 바꾸지 않는다.
class_name ShopRow
extends PartyButton

## 왼쪽 아이콘 칸(정사각형, 줄 높이)과 이름 막대 사이.
const ICON_GAP := 4.0
## 아이콘 칸 안 여백(64 칸 → 아이콘 36).
const ICON_INSET := 14.0
## 이름 칸 폭(이름 막대 왼쪽 여백부터 「NEW」 앞까지, 넓은 화면). 좁으면 숫자 칸 앞에서 멈춘다.
const NAME_COL := 232.0
const PILL_W := 56.0
const PILL_H := 26.0
const PILL_FS := 14
## 오른쪽 숫자 칸 폭(「999,999」·「품절」).
const RIGHT_W := 80.0
const COUNT_FS := 15
## 이름과 개수, 이름 칸과 알약, 알약과 숫자 칸 사이.
const SPACE := 8.0

## 종류 아이콘(VectorIcons 이름, "" 이면 빈 아이콘 칸).
var kind_icon := ""
var is_new := false
var new_text := "NEW"
## 판매 줄의 개수 글(「12개」, "" 이면 없음).
var count := ""
## 이 줄에 대한 창이 떠 있다(노랑 커서는 창 단추로 옮겨 갔다): 밝은 시안 「cmd:chosen」(전투 ListRow.chosen 과 같다, 07 §9.2).
var chosen := false:
	set(v):
		chosen = v
		queue_redraw()


func _init() -> void:
	super()
	align_left = true
	skin = "cmd"


func theme_state() -> String:
	if chosen and UiTheme.has_look(skin + ":chosen"):
		return skin + ":chosen"
	return super()


## 아이콘 칸 테두리 [색, 굵기]: 고른 줄(checked)은 굵은 하늘색이라 커서(노랑)·chosen 이어도 고른 것이 보인다.
func icon_edge() -> Array:
	return [UiTheme.BTN_CHECKED, 3.0] if checked else [UiTheme.SHOP_ICON_EDGE, 1.5]


## 이름 막대(아이콘 칸 오른쪽).
func bar_rect() -> Rect2:
	var x := size.y + ICON_GAP
	return Rect2(x, 0, maxf(0.0, size.x - x), size.y)


func icon_rect() -> Rect2:
	return Rect2(0, 0, size.y, size.y)


## 「NEW」 알약 왼쪽 x(이 줄 기준). 같은 폭의 줄은 모두 같은 값이다.
func pill_x() -> float:
	var bar := bar_rect()
	return minf(bar.position.x + PAD + NAME_COL, bar.end.x - PAD - RIGHT_W - SPACE - PILL_W)


func pill_rect() -> Rect2:
	return Rect2(pill_x(), (size.y - PILL_H) / 2.0, PILL_W, PILL_H)


## 이름 + 개수가 쓸 수 있는 폭.
func name_room() -> float:
	return pill_x() - SPACE - bar_rect().position.x - PAD


## 오른쪽 숫자 칸(오른쪽 맞춤).
func right_rect() -> Rect2:
	var bar := bar_rect()
	return Rect2(bar.end.x - PAD - RIGHT_W, 0, RIGHT_W, size.y)


func _count_w(font: Font) -> float:
	return 0.0 if count.is_empty() else font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FS).x + SPACE


## 글자마다 [글, 글자 크기, 그릴 폭](그리기와 같은 값, PartyButton.clipped_parts 가 읽는다).
func text_parts() -> Dictionary:
	var font := get_theme_default_font()
	var out := {"main": [text, font_size, name_room() - _count_w(font)]}
	if not count.is_empty():
		out["count"] = [count, COUNT_FS, _count_w(font) - SPACE]
	if not right.is_empty():
		out["right"] = [right, font_size, RIGHT_W]
	if is_new:
		out["new"] = [new_text, PILL_FS, PILL_W - 8.0]
	return out


func _draw() -> void:
	var font := get_theme_default_font()
	var ir := icon_rect()
	draw_rect(ir, UiTheme.SHOP_ICON_CELL)
	var edge := icon_edge()
	UiTheme.draw_outline(self, ir, edge[0], edge[1], 0.0)
	if not kind_icon.is_empty():
		var icol := UiTheme.SHOP_ICON if not dimmed else UiTheme.BTN_DISABLED_TEXT
		VectorIcons.draw(self, kind_icon, ir.grow(-ICON_INSET), icol)
	var bar := bar_rect()
	var lk := UiTheme.draw_button(self, bar, theme_state())
	var fg: Color = lk["text"]
	var y := size.y / 2.0 + font_size * 0.36
	var cw := _count_w(font)
	var name_w := name_room() - cw
	var x := bar.position.x + PAD
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, name_w, font_size, fg)
	if not count.is_empty():
		var nx := x + minf(name_w, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) + SPACE
		draw_string(font, Vector2(nx, size.y / 2.0 + COUNT_FS * 0.36 + 2.0), count, HORIZONTAL_ALIGNMENT_LEFT, cw - SPACE, COUNT_FS, lk["sub"])
	if is_new:
		var pr := pill_rect()
		UiTheme.fill_round(self, pr, UiTheme.SHOP_NEW_PILL, int(PILL_H / 2.0))
		draw_string(font, Vector2(pr.position.x, pr.get_center().y + PILL_FS * 0.36), new_text, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x,
			PILL_FS, UiTheme.SHOP_NEW_TEXT)
	if not right.is_empty():
		var rr := right_rect()
		draw_string(font, Vector2(rr.position.x, y), right, HORIZONTAL_ALIGNMENT_RIGHT, rr.size.x, font_size, fg)


## 세 자리 쉼표(「1,480」, 08 §7.1). 음수는 ASCII 「-」.
static func grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out
