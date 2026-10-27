## 캠프 뿌리의 채집 알약(M3 A5, 07 §9.8, research 07 P7): 원작 III HD 캠프(yt_eo3hd_06)의 그림 창 오른쪽 위 둥근 판 셋.
## 차례는 원작대로 절단 · 추출 · 채취, 위에 종류 이름(20), 아래 「남음 / 하루 몫」(22). 값은 GatherRules.kind_counts(모든 층에서 서 본 지점의 합).
## 남음 0 이어도 같은 모양이다(원작에 흐린 모양이 없다). 보이기만 하고 누르기·포커스가 없다(MOUSE_FILTER_IGNORE, 64 규칙 밖).
## 그린 것은 SheetParts 기록(record)에 남는다: 시험은 깃발이 아니라 그린 사각형·색·글을 읽는다.
class_name GatherPills
extends Control

## 원작 차례(절단 · 추출 · 채취, 원작 III 의 벌채 · 채굴 · 채취).
const KINDS := ["chop", "mine", "take"]
const PILL := Vector2(136, 64)
const GAP := 16.0
## 알약 셋의 너비(136·3 + 16·2 = 440). 자리는 캠프가 오른쪽 위 앵커로 준다(오른쪽 끝 − 490 ~ − 50, y 140 ~ 204, PartyMenu.PILLS_RIGHT).
const WIDTH := 440.0
const LABEL_FS := 20
const COUNT_FS := 22
const TEXT := Color.WHITE

var texts: TextDb
## 그린 차례의 [{kind, left, max}].
var counts: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## 상태 s 의 종류별 수를 읽어 다시 그린다.
func show_state(s: ExplorationState) -> void:
	var by_kind := GatherRules.kind_counts(s)
	counts.clear()
	for k in KINDS:
		counts.append({"kind": k, "left": int(by_kind[k][0]), "max": int(by_kind[k][1])})
	queue_redraw()


## 알약 i 의 사각형(이 컨트롤 기준).
static func pill_rect(i: int) -> Rect2:
	return Rect2(Vector2(i * (PILL.x + GAP), 0), PILL)


func _draw() -> void:
	SheetParts.begin(self)
	for i in counts.size():
		var r := pill_rect(i)
		var c := counts[i]
		ListParts.draw_panel(self, r, "count")
		SheetParts._text(self, Vector2(r.position.x, r.position.y + 26.0), texts.t("gather.kind." + str(c["kind"])), LABEL_FS, TEXT,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		SheetParts._text(self, Vector2(r.position.x, r.position.y + 54.0), texts.t("gather.count", {"left": c["left"], "max": c["max"]}),
			COUNT_FS, TEXT, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
