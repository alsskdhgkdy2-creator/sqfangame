## 알림 띠(부품 K, ListParts.draw_banner): 양 끝이 괄호처럼 굽은 청록 띠(원작 I HD 스킬 배움 알림 yt_eo1hd_b_04).
## 캠프 확인 창(PartyMenu.dialog_panel: 스킬의 확정·버리기, 기록의 새 게임)이 이 띠 위에 글과 단추 둘을 놓는다(07 §9.9 E2-d). 장식(누르기는 뒤로).
## 그리기 기록은 이 컨트롤의 SheetParts.record.
class_name BannerBox
extends Control


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## 글·단추가 놓이는 몸의 사각형(이 컨트롤 기준).
func body_rect() -> Rect2:
	return ListParts.banner_body_rect(Rect2(Vector2.ZERO, size))


func _draw() -> void:
	SheetParts.begin(self)
	ListParts.draw_banner(self, Rect2(Vector2.ZERO, size))
