## 상점 상태(08 §2). 상점이 하나라 상태도 하나다. 상점 규칙(ShopRules)만 바꾼다.
class_name ShopState
extends RefCounted

## 소재 ID → 누적 판 수(1~SOLD_MAX, 0이면 키를 두지 않는다). 줄지 않는다. 풀림은 이것으로 본다.
var sold := {}
## 소재 ID → 한정 물건에 아직 쓰지 않은 수(1~sold[소재], 0이면 키를 두지 않는다).
var pool := {}
## 한 번이라도 산 장비 ID → true(집합).
var bought := {}


## bought 를 정렬한 배열(저장·화면 표시용).
func bought_list() -> Array[String]:
	var out: Array[String] = []
	for id in bought:
		out.append(id)
	out.sort()
	return out
