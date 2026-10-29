## 누르기 지킴이(M3 A7d): 화면(주인)마다 고름 값 하나 — 주인의 selection_key() — 가 있고, 누르기는 시작할 때의 값과 뗄 때의 값이
## 같을 때만 일한다(고름 값 = 쪽·탭·대원·모든 커서와 그 대상 ID·창의 답·수량·고른 칸).
## 두 곳에서 지킨다:
## - 주인 _refresh 끝(sync): 값이 바뀌었으면 주인 아래의 눌린 단추·끌어 내리는 영역을 모두 버린다(눌림 모양이 바로 사라진다).
## - 뗄 때(TouchButton._up): 누를 때 적어 둔 값과 지금 값이 다르면 일하지 않고 주인 아래 눌림을 모두 버린다(_refresh 를 거치지 않은
##   바뀜 — 타이머·연출 — 도 막는다).
## 주인 = selection_key 를 가진 가장 가까운 조상. 탭·창·판 같은 부품은 selection_key 를 두지 않고 key_part() 를 주인 값에 넣는다
## (selection_key 는 주인의 표시다). 주인이 없는 단추(미궁 이동 단추 등)는 예전 그대로다.
## 값에는 고름만 넣는다: 끌어 내린 자리·안내 글·돈·연출 시간처럼 아무것도 누르지 않아도 바뀌는 것은 넣지 않는다(바뀌면 모든 누르기가 거부된다).
class_name PressGuard
extends RefCounted

var host: Node
var _last: Array = []
var _synced := false


func _init(h: Node) -> void:
	host = h


## 주인 _refresh 끝에서 부른다. 값이 바뀌었으면(처음 포함) 주인 아래 눌림을 모두 버리고 true.
func sync() -> bool:
	var k := key_of(host)
	if _synced and k == _last:
		return false
	_synced = true
	_last = k
	cancel_under(host)
	return true


## 화면을 새로 열 때: 다음 sync 는 값과 상관없이 눌림을 버린다(예전 문맥 문자열을 비우던 것과 같다).
func reset() -> void:
	_synced = false
	_last = []


## n 의 주인: selection_key 를 가진 가장 가까운 조상(없으면 null).
static func scope_of(n: Node) -> Node:
	var p := n.get_parent()
	while p != null:
		if p.has_method("selection_key"):
			return p
		p = p.get_parent()
	return null


## 주인의 지금 고름 값(주인이 없거나 풀렸으면 빈 배열).
static func key_of(scope: Node) -> Array:
	if scope == null or not is_instance_valid(scope):
		return []
	return scope.call("selection_key")


## root 아래에서 눌려 있던 단추·줄·탭·끌어 내리는 영역을 모두 버린다(그 손가락은 뗄 때까지 아무것도 누르지 못한다).
static func cancel_under(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	for n in root.find_children("*", "TouchButton", true, false):
		(n as TouchButton).cancel()
	for n in root.find_children("*", "PartyScroll", true, false):
		(n as PartyScroll).cancel()
