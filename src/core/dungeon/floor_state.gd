## 한 층의 기록(M3 A1): 그 층의 세계 상태·방문 기록·지도 그림. 층마다 따로 두고 섞지 않는다(05 §4).
## 층을 처음 들어갈 때 ExplorationState.enter_floor 가 만든다. 지도 그림의 실행 취소 기록도 층마다 따로다(저장하지 않는다).
## 다음 단계의 층별 상태(상자·문·열쇠 A3, 채집 A5, FOE A6, 보스 A9)도 여기에 더한다.
class_name FloorState
extends RefCounted

var floor_def: FloorModel
var world := WorldState.new()
var knowledge := ExplorationKnowledge.new()
var annotation := MapAnnotation.new()


func _init(f: FloorModel = null) -> void:
	floor_def = f
	if f != null:
		annotation = MapAnnotation.new(f.width, f.height)
