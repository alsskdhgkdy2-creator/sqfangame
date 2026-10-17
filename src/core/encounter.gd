## 위험도와 이번 한계값. 위험도가 한계값 이상이면 전투 대기.
class_name EncounterState
extends RefCounted

var danger := 0
var threshold := 1
var pending := false


## [lo, hi]에서 한계값을 새로 뽑는다(새 게임·전투 해결 때).
func roll_threshold(rng: GameRng, lo: int, hi: int) -> void:
	threshold = rng.randi_range(lo, hi)


## 위험도를 더하고, 한계값에 닿으면 대기로 바꾼다. 이번에 대기가 되었으면 true.
func add(amount: int) -> bool:
	danger += amount
	if danger >= threshold:
		pending = true
		return true
	return false


## 화면 게이지 값(0~1).
func gauge() -> float:
	return clampf(float(danger) / threshold, 0.0, 1.0)


## 게이지 색: 0.5 미만 blue, 0.85 미만 yellow, 그 이상 red.
func gauge_color() -> String:
	var g := gauge()
	if g < 0.5:
		return "blue"
	if g < 0.85:
		return "yellow"
	return "red"
