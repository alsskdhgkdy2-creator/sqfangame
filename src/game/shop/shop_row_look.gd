## 마을 상점 목록의 줄 모양(공용 목록 InventoryList 의 모양 갈고리, D28-b). 줄 = ShopRow(64, 사이 4): 아이콘 칸 · 이름(판매는 「n개」) ·
## 「NEW」 알약 · 오른쪽 숫자(값·판매값·「품절」), 흐림(돈 모자람·품절)·고름(여러 개 팔기). 틀·빈 칸·위치 막대는 ShopList 가 둔다.
## 커서 칸 모양은 커서 모드를 따른다: "cursor" = 노랑(selected), "chosen" = 밝은 시안(그 줄에 대한 창이 떠 있다), "none" = 표시 없음.
class_name ShopRowLook
extends InventoryLook

var new_text := "NEW"


func _init() -> void:
	row_h = ShopList.ROW_H
	gap = ShopList.ROW_GAP


func make_row() -> PartyButton:
	return ShopRow.new()


## 줄 모델: icon·name·new·right·count·dim·checked.
func paint(r: PartyButton, m: Dictionary) -> void:
	var sr := r as ShopRow
	sr.kind_icon = str(m.get("icon", ""))
	sr.text = str(m.get("name", ""))
	sr.is_new = bool(m.get("new", false))
	sr.new_text = new_text
	sr.right = str(m.get("right", ""))
	sr.count = str(m.get("count", ""))
	sr.dimmed = bool(m.get("dim", false))
	sr.checked = bool(m.get("checked", false))
	sr.queue_redraw()


func mark(r: PartyButton, at: bool, mode: String) -> void:
	r.selected = at and mode == "cursor"
	(r as ShopRow).chosen = at and mode == "chosen"
