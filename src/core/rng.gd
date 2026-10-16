## 게임 규칙이 쓰는 유일한 난수원. 상태를 저장·복원해 같은 입력이면 같은 결과가 나오게 한다.
class_name GameRng
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## 확률 p(0~1)로 참.
func chance(p: float) -> bool:
	return _rng.randf() < p


func get_state() -> int:
	return _rng.state


func set_state(value: int) -> void:
	_rng.state = value
