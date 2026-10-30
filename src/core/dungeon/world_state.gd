## 원정 뒤에도 남는 세계 변화(한 층): 열린 지름길, 찾은 숨은 통로, 연 잠긴 문·연 보물상자(M3 A3), 오늘 쓴 채집 횟수(M3 A5,
## 숙소에서 날이 바뀌면 TownRules.new_day 가 비운다), FOE 마다의 상태(M3 A6, FoeRules). 규칙 함수만 바꾼다.
class_name WorldState
extends RefCounted

var shortcuts_open := {}  # Vector3i → true
var passages_found := {}  # Vector3i → true
var locks_open := {}  # Vector3i → true (열쇠 문, M3 A9 부터 needs 플래그로 연 봉인 문도. 다시 닫히지 않는다)
var chests_opened := {}  # 상자 id String → true
var gather_used := {}  # 채집 지점 id String → 오늘 쓴 횟수(1~9, 0 이면 키가 없다)
var foes := {}  # FOE id String → FoeState(M3 A6). 층 기록을 만들 때(FloorState) 층의 모든 FOE 가 처음 상태로 들어간다.


## FOE 하나의 상태(M3 A6, 설계 §3.1). state: idle·patrol·alert·chase·return·join(전투로 가는 중)·battle(지금 전투에 있다)·defeated(day = 쓰러진 날).
## path_i·dir 은 경로의 자리와 방향(+1·−1), stun 은 남은 기절 걸음(도주 뒤 0~2).
class FoeState:
	extends RefCounted
	var at := Vector2i.ZERO
	var facing := 0
	var state := "idle"
	var path_i := 0
	var dir := 1
	var stun := 0
	var day := 0

	func alive() -> bool:
		return state != "defeated"

	func copy() -> FoeState:
		var c := FoeState.new()
		c.at = at
		c.facing = facing
		c.state = state
		c.path_i = path_i
		c.dir = dir
		c.stun = stun
		c.day = day
		return c

	## 배치의 처음 상태: 시작 칸·방향, 경로가 있으면 patrol 아니면 idle.
	static func fresh(s: FloorModel.FoeSpawn) -> FoeState:
		var c := FoeState.new()
		c.at = s.at
		c.facing = s.facing
		c.state = "patrol" if not s.path.is_empty() else "idle"
		return c


func is_shortcut_open(e: Vector3i) -> bool:
	return shortcuts_open.has(e)


func open_shortcut(e: Vector3i) -> void:
	shortcuts_open[e] = true


func is_passage_found(e: Vector3i) -> bool:
	return passages_found.has(e)


func find_passage(e: Vector3i) -> void:
	passages_found[e] = true


func is_lock_open(e: Vector3i) -> bool:
	return locks_open.has(e)


func open_lock(e: Vector3i) -> void:
	locks_open[e] = true


func is_chest_opened(id: String) -> bool:
	return chests_opened.has(id)


func open_chest(id: String) -> void:
	chests_opened[id] = true


## 지점 p 의 오늘 남은 채집 횟수(0 아래로 내려가지 않는다: 자료를 고쳐 횟수가 줄어도 저장은 읽힌다).
func gather_left(p: FloorModel.GatherPoint) -> int:
	return maxi(0, p.uses - int(gather_used.get(p.id, 0)))


func take_gather(id: String) -> void:
	gather_used[id] = int(gather_used.get(id, 0)) + 1


func copy() -> WorldState:
	var w := WorldState.new()
	w.shortcuts_open = shortcuts_open.duplicate()
	w.passages_found = passages_found.duplicate()
	w.locks_open = locks_open.duplicate()
	w.chests_opened = chests_opened.duplicate()
	w.gather_used = gather_used.duplicate()
	for id in foes:
		w.foes[id] = foes[id].copy()
	return w
