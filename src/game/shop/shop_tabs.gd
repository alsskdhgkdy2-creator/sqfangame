## 상점 종류 탭 줄(08 §7.3, 원작 HD 「ALL」 + 종류 아이콘): 64×64 TouchButton 칸(뗄 때 한 번, 손가락 소유, cancel()), 사이 4.
## 「전체」 칸은 글자, 나머지는 종류 아이콘(VectorIcons). 고른 칸은 checked(하늘색), 나머지는 어두운 남색(「shoptab」).
## 노랑 커서는 쓰지 않는다(노랑은 목록 줄 커서 하나, 07 §9.2). 칸 차례는 갈래마다 차례 표 하나(08 §1.3 진열 차례와 같다).
## 원작의 ZL·ZR 그림 칸은 없다(키는 S3 키 표).
class_name ShopTabs
extends Control

signal picked(index: int)

const CELL := 64.0
const GAP := 4.0
## 상점 화면에서 탭 줄의 위·아래(1280×720 기준, 08 §7.1). 왼쪽 끝은 ShopFrame.left.
const TOP := 166.0
## 갈래 → 칸 차례(종류 이름, "all" = 전체).
const SETS := {
	"weapon": ["all", "sword", "staff"],
	"armor": ["all", "body", "shield", "head", "hands", "feet"],
	"sell": ["material", "gear", "consumable"],
}
## 칸 종류 → 아이콘. 판매 「장비」 칸은 원작처럼 검 아이콘.
const ICONS := {
	"sword": "kind_sword", "staff": "kind_staff", "body": "kind_body", "shield": "kind_shield", "head": "kind_head",
	"hands": "kind_hands", "feet": "kind_feet", "accessory": "kind_accessory",
	"material": "kind_material", "gear": "kind_sword", "consumable": "kind_consumable",
}

var kinds: Array[String] = []
var buttons: Array[TouchButton] = []
var current := 0
## 입력 입구(08 §7.4·§8.11, ShopDialog.route 와 같은 방식): 있으면 칸 누르기는 route(i) 만 부르고 고른 칸도 picked 도 그대로다.
## 받을지 정하는 화면(S3)이 받은 뒤 select 한다. 비어 있으면 S2 그대로.
var route: Callable


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


## set_name: SETS 의 갈래. all_label: 「전체」 글(shop.tab.all).
func setup(set_name: String, all_label: String) -> void:
	kinds.assign(SETS.get(set_name, []))
	for b in buttons:
		remove_child(b)
		b.queue_free()
	buttons.clear()
	for i in kinds.size():
		var b := TouchButton.new()
		var k := kinds[i]
		b.name = "Tab_" + k
		b.skin = "shoptab"
		if k == "all":
			b.text = all_label
		else:
			b.icon = ICONS.get(k, "")
		b.position = Vector2(i * (CELL + GAP), 0)
		b.size = Vector2(CELL, CELL)
		b.activated.connect(func() -> void: _on_tab(i))
		add_child(b)
		buttons.append(b)
	custom_minimum_size = needed_size()
	size = needed_size()
	select(0)


func needed_size() -> Vector2:
	var n := kinds.size()
	return Vector2(maxf(0.0, n * CELL + (n - 1) * GAP), CELL)


## 칸 i 를 고른 칸으로(신호 없음). 범위 밖이면 그대로.
func select(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	current = i
	for j in buttons.size():
		buttons[j].checked = j == i


func kind() -> String:
	return kinds[current] if current < kinds.size() else ""


func _on_tab(i: int) -> void:
	if route.is_valid():
		route.call(i)
		return
	select(i)
	picked.emit(i)


## 눌려 있던 포인터를 모두 버린다(문맥이 바뀔 때, 07 §9.4).
func cancel() -> void:
	for b in buttons:
		b.cancel()
