## 시험 파일의 공통 부모. 실패를 모아 두고 실행기가 읽는다.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
## 실행기가 넣는다. 프레임을 기다리는 시험은 `await tree.process_frame` 으로 기다린다.
var tree: SceneTree
## 이 시험의 시간 한도(초). 실행기가 넘으면 실패로 센다.
var timeout_sec := 10.0


func check(cond: bool, message: String) -> void:
	if not cond:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: 기대 %s, 실제 %s" % [message, str(expected), str(actual)])


## 시험이 끝난 뒤(시간 초과 포함) 실행기가 부른다. 장면·임시 파일을 치운다.
func teardown() -> void:
	pass
