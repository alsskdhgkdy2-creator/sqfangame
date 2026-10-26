## 스킬 트리 노드 하나(07 §9.9 E2-d: 원작 I HD 스킬 트리 yt_eo1hd_b_03 의 알약): 왼쪽 이름(한 줄, 넘치면 글자를 줄인다)과 그 아래
## 상태 글자(「배움 가능」·「잠김」·「SP 부족」·「최대」), 오른쪽 Lv 상자(「Lv 2/5」). 색은 UiTheme 「tree:*」(보통 남색 #044C76, 커서 하늘색 #3EC0CC,
## 잠김·SP 부족 회색 #24333C, 그 위 커서는 회색에 하늘색 테. 노랑 채움 없음). 초안으로 올린 노드는 금색 테두리와 Lv 상자 왼쪽 「+1」(채움 아님).
## 그리기는 SheetParts 기록 함수를 거쳐 이 노드의 기록(SheetParts.record)에 남는다(시험이 그린 색을 읽는다).
## 누르기는 TouchButton 그대로(그 노드 고르기). 끌면 트리 영역을 끌어 내린다(PartyButton 과 같은 규칙).
class_name SkillNode
extends PartyButton

const NAME_FS := 18
const MIN_FS := 13
const BOX_W := 84.0
## 알약 끝 둥글기(64 높이에서 둘째 줄 글자가 굽은 끝에 걸리지 않게 반원이 아닌 24).
const RADIUS := 24

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
	SheetParts.begin(self)
	var r := Rect2(Vector2.ZERO, size)
	var lk := UiTheme.look(theme_state())
	# 불투명 평평한 알약(원작처럼 그라데이션 없음): 선행 선이 노드 면에 비치지 않는다. 바깥 테는 모양의 outer(잠긴 노드 위 커서는 하늘색).
	var ow := int(lk["outer_w"])
	SheetParts._fill_round(self, r, lk["bottom"], RADIUS, lk["outer"], ow)
	SheetParts._log(self, {"kind": "outline", "rect": r, "color": lk["outer"], "width": ow})
	if draft > 0:
		UiTheme.fill_round(self, r, Color(0, 0, 0, 0), RADIUS, UiTheme.BTN_PICK, int(UiTheme.BTN_PICK_W))
		SheetParts._log(self, {"kind": "outline", "rect": r, "color": UiTheme.BTN_PICK, "width": int(UiTheme.BTN_PICK_W)})
	var font := get_theme_default_font()
	var fg: Color = lk["text"]
	var box := box_rect()
	SheetParts._fill_round(self, box, UiTheme.TREE_LV_BOX if not is_dim() else UiTheme.TREE_LV_BOX_OFF, 16)
	SheetParts._text(self, Vector2(box.position.x, box.get_center().y + 15 * 0.36), level_line, 15,
		UiTheme.TREE_LV_BOX_TEXT if not is_dim() else UiTheme.TREE_LV_BOX_OFF_TEXT, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var right := box.position.x - 8.0
	if draft > 0:
		SheetParts._text(self, Vector2(right - 36.0, size.y / 2.0 + 16 * 0.36), "+%d" % draft, 16, lk["accent"], 32, HORIZONTAL_ALIGNMENT_RIGHT)
		right -= 40.0
	var w := right - 16.0
	name_fs = NAME_FS
	while name_fs > MIN_FS and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs).x > w:
		name_fs -= 1
	SheetParts._text(self, Vector2(16, 28), text, name_fs, fg, w)
	var sc: Color = lk["good"]
	match status_kind:
		"locked", "no_sp":
			sc = lk["muted"]
		"max":
			sc = lk["accent"]
	SheetParts._text(self, Vector2(16, 51), status_line, 13, sc, w)
