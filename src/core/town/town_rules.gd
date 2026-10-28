## 마을 규칙 함수(M3 A2b): 숙소(캡슐 숙소) 숙박·값, 날 바뀜, 전멸 뒤 지도 남기기.
## 노드·시간·엔진에 기대지 않고 난수·걸음을 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(ShopRules 와 같은 방식).
## 거부·막힘이면 그 이벤트 하나만 내고 상태를 바꾸지 않는다. 받아들이면 부른 화면이 자동 저장한다(05 §8.4).
##
## 이벤트:
##   {"type": "rejected", "reason": "not_town"}
##   {"type": "blocked", "reason": "no_money" | "day_max"}
##   {"type": "foe_respawned", "floor", "foe"}…(M3 A6, 그날 되살아난 FOE) 다음 {"type": "stayed", "price", "day"}
class_name TownRules
extends RefCounted

## 숙박비 = 이 값 × 대원 가운데 가장 높은 레벨(01 §6: 값은 파티 최고 레벨을 따라 오른다. 기능 우선 값, D15).
const INN_PER_LEVEL := 10

## 날이 바뀔 때 부르는 시험 갈고리(new_day 가 부를 때마다 한 번, 인자 없음). 게임 코드는 쓰지 않는다.
static var new_day_hook := Callable()


## 숙박비: INN_PER_LEVEL × 파티 대원 최고 레벨(쓰러진 대원도 센다, M3 A7: 길드에만 있는 대원은 세지 않는다).
static func inn_price(s: ExplorationState) -> int:
	var top := 1
	for m in s.party.members:
		top = maxi(top, m.level)
	return INN_PER_LEVEL * top


## 하룻밤 묵는다: 마을에서만. 돈이 모자라거나 날이 끝이면 막힘(아무것도 바꾸지 않는다).
## 받아들이면 소지금 − 값, 파티 대원 모두 HP·TP 가득(쓰러진 대원도 일어난다, M3 A7: 길드에만 있는 대원은 그대로), 날 +1, new_day.
static func stay(s: ExplorationState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not s.in_town():
		events.append({"type": "rejected", "reason": "not_town"})
		return events
	var price := inn_price(s)
	if s.money < price:
		events.append({"type": "blocked", "reason": "no_money"})
		return events
	if s.day >= ExplorationState.DAY_MAX:
		events.append({"type": "blocked", "reason": "day_max"})
		return events
	s.money -= price
	for m in s.party.members:
		m.hp = m.max_hp
		m.tp = m.max_tp
	s.day += 1
	events.append_array(new_day(s))
	events.append({"type": "stayed", "price": price, "day": s.day})
	return events


## 날이 바뀔 때 한 번(지금은 숙박만 부른다). 들어가 본 모든 층의 오늘 쓴 채집 횟수를 비운다(M3 A5, 01 §3.6: 지금 층만이 아니다).
## 모든 층에서 날이 찬 after_days FOE 를 되살린다(M3 A6, FoeRules.new_day: 되살아난 FOE 의 foe_respawned 이벤트를 돌려준다).
## 밖에서 고칠 상태 이상은 없다(전투가 끝나면 지운다, 06 §3.17).
static func new_day(s: ExplorationState) -> Array[Dictionary]:
	for id in s.floor_states:
		s.floor_states[id].world.gather_used.clear()
	var out := FoeRules.new_day(s)
	if new_day_hook.is_valid():
		new_day_hook.call()
	return out


## 전멸 뒤 「지도를 남긴다」(01 §4.10, research 01: 그린 지도와 방문 기록은 따로다). wiped 의 층마다 지도 그림(annotation: 색·경계 표시·
## 자동 경계·아이콘·메모)이 target 의 것을 바꾼다(전멸 쪽이 마지막 그림이라 합치지 않는다: 지운 표시가 되살아나지 않게).
## target 에만 있는 층은 그대로, wiped 에만 있는 층은 빈 세계·방문 기록에 그 그림만 가진 기록으로 더한다(지금 층은 바꾸지 않는다).
## 세계(연 지름길·찾은 통로)와 방문 기록(칸·경계 관찰)은 target 것만 쓴다. 그림은 SaveCodec 의 층 기록 쓰기·읽기를 거쳐 복사하므로
## 저장 검사를 늘 지난다. 실행 취소 기록은 비어서 시작한다.
static func keep_map(target: ExplorationState, wiped: ExplorationState) -> void:
	for id in wiped.floor_states:
		var w: FloorState = wiped.floor_states[id]
		var t: FloorState = target.floor_states.get(id)
		if t == null:
			t = FloorState.new(w.floor_def)
			target.floor_states[id] = t
		t.annotation = MapAnnotation.new(w.floor_def.width, w.floor_def.height)
		var err := SaveCodec._read_annotation(SaveCodec.floor_state_to_dict(w), t)
		assert(err.is_empty(), "지도 그림 복사: " + err)
