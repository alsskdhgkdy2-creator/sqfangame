## 스킬 트리 노드 하나(07 §9.2): 이름(두 줄까지), 「Lv 2/5」, 상태 글자(「배움 가능」 밝게·「잠김」 흐리게·「최대」).
## 초안으로 올린 노드는 금색 테두리와 레벨 줄 오른쪽 「+1」, 키보드 커서가 있는 노드는 안쪽에 따로 테두리(selected).
## 누르기는 TouchButton 그대로(그 노드 고르기). 끌면 트리 영역을 끌어 내린다(PartyButton 과 같은 규칙).
class_name SkillNode
extends PartyButton

const NAME_FS := 16

## 트리 칸 번호.
var index := -1
var level_line := ""
var status_line := ""
## learnable·locked·no_sp·max·""
var status_kind := ""
## 초안으로 더한 레벨(0 = 없음).
var draft := 0


## 이름을 두 줄까지 나눈다: 한 줄에 안 들어가면 띄어쓰기에서 나누고(낱말 가운데서 끊지 않는다), 그래도 넘치는 줄은 잘라 그린다.
static func name_lines(font: Font, t: String, width: float, fs: int) -> Array[String]:
	if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width or not t.contains(" "):
		return [t]
	var words := t.split(" ")
	var first := words[0]
	var k := 1
	while k < words.size() - 1 and font.get_string_size(first + " " + words[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		first += " " + words[k]
		k += 1
	return [first, " ".join(words.slice(k))]


## 흐리게 그리는지(「잠김」·「SP 부족」 같은 꼴).
func is_dim() -> bool:
	return status_kind == "locked" or status_kind == "no_sp"


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var locked := is_dim()
	var sb := StyleBoxFlat.new()
	# 불투명: 선행 선이 노드 면에 비치지 않는다.
	sb.bg_color = Color(0.16, 0.32, 0.4) if held else (Color(0.05, 0.08, 0.1) if locked else Color(0.08, 0.13, 0.17))
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3 if draft > 0 else 1)
	sb.border_color = Color(1.0, 0.8, 0.3) if draft > 0 else Color(0.3, 0.45, 0.52)
	draw_style_box(sb, r)
	if selected:
		var cur := StyleBoxFlat.new()
		cur.draw_center = false
		cur.set_corner_radius_all(8)
		cur.set_border_width_all(2)
		cur.border_color = Color(0.45, 0.95, 1.0)
		draw_style_box(cur, r.grow(-3))
	var font := get_theme_default_font()
	var fg := Color(0.45, 0.5, 0.55) if locked else Color(0.9, 0.97, 1.0)
	var lines := name_lines(font, text, size.x - 16, NAME_FS)
	var y := 26.0 if lines.size() == 1 else 22.0
	for line in lines:
		draw_string(font, Vector2(8, y), line, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, NAME_FS, fg)
		y += 19.0
	draw_string(font, Vector2(0, 62), level_line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, fg)
	var sc := Color(0.55, 1.0, 0.7)
	match status_kind:
		"locked", "no_sp":
			sc = Color(0.45, 0.5, 0.55)
		"max":
			sc = Color(1.0, 0.86, 0.45)
	draw_string(font, Vector2(0, 79), status_line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, sc)
	if draft > 0:
		draw_string(font, Vector2(size.x - 44, 62), "+%d" % draft, HORIZONTAL_ALIGNMENT_RIGHT, 36, 16, Color(1.0, 0.85, 0.35))
