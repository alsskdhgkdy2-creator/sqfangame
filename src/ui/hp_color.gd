## 대원 HP 막대 색 한 규칙(전투 대원 칸·탐색 상태 칸·파티 메뉴 대원 칸이 같이 쓴다, 원작처럼 세 단계).
## 50% 넘으면 초록, 50% 이하 주황, 30% 이하 빨강. 비율을 나누지 않고 곱으로 견주어 정확히 50%·30% 인 경계가 흔들리지 않는다.
class_name HpColor
extends RefCounted

const GREEN := Color(0.35, 0.9, 0.5)
const ORANGE := Color(1.0, 0.64, 0.2)
const RED := Color(1.0, 0.38, 0.3)


## "green" / "orange" / "red". 최대가 0 이하면 빨강.
static func level(hp: float, max_hp: float) -> String:
	if max_hp <= 0.0 or hp * 10.0 <= max_hp * 3.0:
		return "red"
	if hp * 2.0 <= max_hp:
		return "orange"
	return "green"


static func of(hp: float, max_hp: float) -> Color:
	match level(hp, max_hp):
		"red":
			return RED
		"orange":
			return ORANGE
	return GREEN
