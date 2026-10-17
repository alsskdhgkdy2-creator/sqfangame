## 칸 키 "x:y"와 경계 키 "h:x:y"·"v:x:y" 변환. 경계는 Vector3i(x, y, 0=h|1=v).
class_name GridKey
extends RefCounted

const BAD_CELL := Vector2i(-1, -1)
const BAD_EDGE := Vector3i(-1, -1, -1)


static func cell(c: Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]


static func edge(e: Vector3i) -> String:
	return "%s:%d:%d" % ["h" if e.z == 0 else "v", e.x, e.y]


## 표준 표기의 "x:y"만 받는다. 아니면 BAD_CELL.
static func parse_cell(s: String) -> Vector2i:
	var parts := s.split(":")
	if parts.size() != 2:
		return BAD_CELL
	var x := _coord(parts[0])
	var y := _coord(parts[1])
	if x < 0 or y < 0:
		return BAD_CELL
	return Vector2i(x, y)


## 표준 표기의 "h:x:y"·"v:x:y"만 받는다. 아니면 BAD_EDGE.
static func parse_edge(s: String) -> Vector3i:
	var parts := s.split(":")
	if parts.size() != 3 or not (parts[0] == "h" or parts[0] == "v"):
		return BAD_EDGE
	var x := _coord(parts[1])
	var y := _coord(parts[2])
	if x < 0 or y < 0:
		return BAD_EDGE
	return Vector3i(x, y, 0 if parts[0] == "h" else 1)


## 0 이상 정수의 표준 표기(앞자리 0·부호 없음, 6자 이하)만 받는다. 아니면 -1.
static func _coord(s: String) -> int:
	if s.is_empty() or s.length() > 6 or not s.is_valid_int():
		return -1
	var v := s.to_int()
	if v < 0 or str(v) != s:
		return -1
	return v


## 키 문자열 배열을 정렬해 돌려준다(결정성).
static func sorted(keys: Array) -> Array[String]:
	var out: Array[String] = []
	for k in keys:
		out.append(k)
	out.sort()
	return out
