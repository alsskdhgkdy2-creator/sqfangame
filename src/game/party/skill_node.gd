## 스킬 트리 노드 하나(07 §9.2, M2.7 R2: 원작 HD 스킬 트리 jp_guide2_img3 의 알약): 왼쪽 이름(한 줄, 넘치면 글자를 줄인다)과 그 아래
## 상태 글자(「배움 가능」·「잠김」·「SP 부족」·「최대」), 오른쪽 Lv 상자(「Lv 2/5」). 모양은 UiTheme 「tree:*」(짙은 파랑, 커서 = 밝은 하늘색,
## 잠김·SP 부족 = 흐린 회청). 초안으로 올린 노드는 금색 테두리와 Lv 상자 왼쪽 「+1」.
## 누르기는 TouchButton 그대로(그 노드 고르기). 끌면 트리 영역을 끌어 내린다(PartyButton 과 같은 규칙).
class_name SkillNode
extends PartyButton

const NAME_FS := 18
const MIN_FS := 13
const BOX_W := 84.0

## 트리 칸 번호.
var index := -1
var level_line := ""
var status_line := ""
## learnable·locked·no_sp·max·""
var status_kind := ""
## 초안으로 더한 레벨(0 = 없음).
var draft := 0
## 마지막으로 그린 이름 글자 크기(시험용).
var name_fs := NAME_FS


## 흐리게 그리는지(「잠김」·「SP 부족」 같은 꼴).
func is_dim() -> bool:
	return status_kind == "locked" or status_kind == "no_sp"


func theme_state() -> String:
	return "tree:" + UiTheme.state_of(held, selected, false, is_dim())


## 오른쪽 Lv 상자 자리.
func box_rect() -> Rect2:
	return Rect2(size.x - 10.0 - BOX_W, (size.y - 32.0) / 2.0, BOX_W, 32.0)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# 불투명: 선행 선이 노드 면에 비치지 않는다.
	var lk := UiTheme.draw_button(self, r, theme_state())
	if draft > 0:
		UiTheme.draw_outline(self, r, UiTheme.BTN_PICK, UiTheme.BTN_PICK_W, 20.0)
	var font := get_theme_default_font()
	var fg: Color = lk["text"]
	var box := box_rect()
	UiTheme.fill_round(self, box, UiTheme.TREE_LV_BOX if not is_dim() else UiTheme.TREE_BOX_EMPTY, 16)
	draw_string(font, Vector2(box.position.x, box.get_center().y + 15 * 0.36), level_line, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 15,
		UiTheme.TREE_LV_BOX_TEXT if not is_dim() else UiTheme.TREE_BOX_EMPTY_TEXT)
	var right := box.position.x - 8.0
	if draft > 0:
		draw_string(font, Vector2(right - 36.0, size.y / 2.0 + 16 * 0.36), "+%d" % draft, HORIZONTAL_ALIGNMENT_RIGHT, 32, 16, lk["accent"])
		right -= 40.0
	var w := right - 16.0
	name_fs = NAME_FS
	while name_fs > MIN_FS and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x > w:
		name_fs -= 1
	draw_string(font, Vector2(16, 28), text, HORIZONTAL_ALIGNMENT_LEFT, w, name_fs, fg)
	var sc: Color = lk["good"]
	match status_kind:
		"locked", "no_sp":
			sc = lk["muted"]
		"max":
			sc = lk["accent"]
	draw_string(font, Vector2(16, 51), status_line, HORIZONTAL_ALIGNMENT_LEFT, w, 13, sc)
