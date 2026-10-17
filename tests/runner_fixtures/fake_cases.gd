## 실행기 자체 시험(test_runner.gd)이 돌리는 가짜 시험. tests/ 바로 아래가 아니라 실행 목록에 들어가지 않는다.
## 일부러 실행 오류·시간 초과를 낸다.
extends TestCase


## _process 에서 실행 오류를 내는 노드(장면 시험 흉내).
class BadNode:
	extends Node

	func _process(_delta: float) -> void:
		var d := {}
		var _x: int = d["missing"]


var _node: Node


func fake_sync_script_error() -> void:
	var d := {}
	var _x: int = d["missing"]


func fake_async_script_error() -> void:
	await tree.process_frame
	var d := {}
	var _x: int = d["missing"]


func fake_scene_script_error() -> void:
	_node = BadNode.new()
	tree.root.add_child(_node)
	for i in 3:
		await tree.process_frame


## queue_free 로만 정리한다: 지워지기 전 마지막 _process 의 오류가 이 시험 몫으로 잡혀야 한다.
func fake_scene_queue_free_only() -> void:
	var node := BadNode.new()
	node.set_process(false)
	tree.root.add_child(node)
	await tree.process_frame
	node.set_process(true)
	node.queue_free()


func fake_engine_error_only() -> void:
	push_error("일부러 낸 엔진 오류(시험 실패로 세지 않음)")
	await tree.process_frame


func fake_clean_pass() -> void:
	await tree.process_frame


## 시간 한도 0: 대기 루프가 돌기 전에 시간 초과다. 정리 뒤 한 프레임에 끝나도 시간 초과로 남아야 한다.
func fake_zero_timeout() -> void:
	timeout_sec = 0.0
	await tree.process_frame


func fake_hang() -> void:
	timeout_sec = 0.3
	await tree.create_timer(60.0).timeout


## 즉시 지운다. queue_free 는 그 프레임의 _process 가 한 번 더 돌아 오류가 다음 시험에 묻는다.
func teardown() -> void:
	if is_instance_valid(_node):
		_node.get_parent().remove_child(_node)
		_node.free()
