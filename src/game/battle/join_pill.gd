## 전투 합류 알약(M3 A6c, 설계 §5.5): 미니맵 아래 「FOE {n}턴 뒤 합류」(가장 가까운 FOE) 또는 「FOE 합류 대기」(그 FOE 가 자리를 기다린다).
## 합류할 FOE 가 없으면 숨는다. 원작에 이 표시의 프레임이 없다(이름 붙인 다른 점: 01 §3.5 「n턴 뒤 합류」를 알약으로 보인다).
## 모양은 A5 공용 판 ListParts.draw_panel(…, "count")(#071E26 α 0.8 알약, D28). 보이기만 하고 누르기·포커스가 없다(MOUSE_FILTER_IGNORE).
## 그린 것은 SheetParts 기록(record)에 남는다: 시험은 깃발이 아니라 그린 사각형·색·글을 읽는다.
class_name JoinPill
extends Control

const SIZE := Vector2(227, 40)
const FS := 20
const TEXT := Color.WHITE

var texts: TextDb
## 지금 보이는 글(숨었으면 "").
var text := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE
	visible = false


## 상태 s 의 합류 예정(FoeRules.join_eta)으로 글을 정한다. 가장 작은 n(같으면 층 자료 차례 앞)이 기다리면 대기 글.
func show_state(s: ExplorationState) -> void:
	text = ""
	if s != null and s.battle != null:
		var best := {}
		for e in FoeRules.join_eta(s):
			if best.is_empty() or int(e["n"]) < int(best["n"]):
				best = e
		if not best.is_empty():
			text = texts.t("battle.join_wait") if best["wait"] else texts.t("battle.join_eta", {"n": best["n"]})
	visible = not text.is_empty()
	queue_redraw()


func _draw() -> void:
	SheetParts.begin(self)
	if text.is_empty():
		return
	ListParts.draw_panel(self, Rect2(Vector2.ZERO, size), "count")
	SheetParts._text(self, Vector2(0, roundf(size.y / 2.0 + FS * 0.36)), text, FS, TEXT, size.x, HORIZONTAL_ALIGNMENT_CENTER)
