## 시험 파일의 공통 부모. 실패를 모아 두고 실행기가 읽는다.
class_name TestCase
extends RefCounted

var failures: Array[String] = []


func check(cond: bool, message: String) -> void:
	if not cond:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: 기대 %s, 실제 %s" % [message, str(expected), str(actual)])
