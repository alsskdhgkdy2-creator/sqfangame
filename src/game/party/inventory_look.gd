## 공용 목록(InventoryList, D28)의 화면별 모양 갈고리. 이 기본은 캠프 모양이다: 줄 = ListButton(부품 H, ListParts.draw_row), 간격 6.
## 마을 상점은 D28-b 에서 이것을 이어 ShopRow 줄·간격 4·chosen 을 쓴다. 틀(굽은 끝 ListWindow, 상점 ShopList)은 모양이 아니라 화면이 둔다.
## 흐린 줄에 선 커서(흐린 커서 모양)는 줄이 스스로 그린다(ListParts.draw_row: selected + dimmed).
class_name InventoryLook
extends RefCounted

var row_h := ListParts.ROW_H
var gap := ListParts.ROW_GAP


## 새 줄 단추(이름·scroller·입력 연결은 InventoryList 가 한다).
func make_row() -> PartyButton:
	return ListButton.new()


## 줄 자료(InventoryList 줄 모델)를 줄에 쓴다. 캠프: 아이콘·이름·오른쪽 글(개수)·흐림·「E」 표.
func paint(r: PartyButton, m: Dictionary) -> void:
	var lb := r as ListButton
	lb.icon_name = str(m.get("icon", ""))
	lb.equipped = bool(m.get("equipped", false))
	lb.show_row(str(m.get("name", "")), str(m.get("right", "")), "", bool(m.get("dim", false)))


## 커서 표시: at = 이 칸이 커서 칸. 캠프는 "cursor" 모양(노랑, 흐린 줄이면 흐린 커서 모양)만 쓴다.
func mark(r: PartyButton, at: bool, mode: String) -> void:
	r.selected = at and mode == "cursor"
