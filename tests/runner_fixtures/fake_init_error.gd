## 실행기 자체 시험용: 객체를 만들 때(_init) 실행 오류를 낸다. 시험 함수 자체는 깨끗하다.
extends TestCase


func _init() -> void:
	var d := {}
	var _x: int = d["missing"]


func fake_clean() -> void:
	pass
