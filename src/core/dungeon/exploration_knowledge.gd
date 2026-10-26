## 실제 방문 기록과 칸에 서서 본 경계 겉모습. 규칙이 자동으로 쓰고, 지도 그림과 섞지 않는다.
class_name ExplorationKnowledge
extends RefCounted

## locked(M3 A3): 닫힌 잠긴 문(열쇠 문·봉인 문). 연 열쇠 문은 door.
const LOOKS := ["wall", "open", "door", "shortcut", "oneway", "passage", "locked"]

var visited := {}  # Vector2i → true
var edges := {}  # Vector3i → 겉모습 문자열


func visit(c: Vector2i) -> void:
	visited[c] = true


func is_visited(c: Vector2i) -> bool:
	return visited.has(c)


func see_edge(e: Vector3i, look: String) -> void:
	edges[e] = look


## 본 적 없는 경계면 "".
func look_of(e: Vector3i) -> String:
	return edges.get(e, "")
