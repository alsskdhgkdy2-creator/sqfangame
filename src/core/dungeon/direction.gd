## 방향 N=0, E=1, S=2, W=3. 오른쪽 회전은 +1 mod 4.
class_name Dir
extends RefCounted

const N := 0
const E := 1
const S := 2
const W := 3
const NAMES := ["N", "E", "S", "W"]
const VECTORS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


static func vec(d: int) -> Vector2i:
	return VECTORS[d]


static func right(d: int) -> int:
	return (d + 1) % 4


static func left(d: int) -> int:
	return (d + 3) % 4


static func opposite(d: int) -> int:
	return (d + 2) % 4


static func name_of(d: int) -> String:
	return NAMES[d]


## "N"·"E"·"S"·"W" → 방향 값. 다른 값이면 -1.
static func from_name(s: Variant) -> int:
	if typeof(s) != TYPE_STRING:
		return -1
	return NAMES.find(s)
