## 실행기 자체 시험: 실행 오류로 멈춘 시험·장면 시험의 오류·시간 초과가 실패로 세어지는지.
## 가짜 시험(runner_fixtures/fake_cases.gd)의 오류는 이 시험의 오류로 넘기지 않는다(absorb).
extends TestCase

const FAKE := preload("res://tests/runner_fixtures/fake_cases.gd")
const FAKE_INIT := preload("res://tests/runner_fixtures/fake_init_error.gd")
const Harness := preload("res://tests/harness.gd")


func _run_fake(name: String, script: GDScript = FAKE) -> Dictionary:
	return await Harness.run_named(tree, script, name, true)


func test_sync_script_error_fails() -> void:
	var r := await _run_fake("fake_sync_script_error")
	check(r["script_errors"] >= 1, "실행 오류를 세지 못함")
	check(not r["failures"].is_empty(), "실행 오류로 멈춘 시험을 통과로 셈")


func test_async_script_error_fails() -> void:
	var r := await _run_fake("fake_async_script_error")
	check(not r["timed_out"], "실행 오류 뒤 코루틴이 끝나야 함")
	check(not r["failures"].is_empty(), "await 뒤 실행 오류를 통과로 셈")


func test_scene_script_error_fails() -> void:
	var r := await _run_fake("fake_scene_script_error")
	check(not r["failures"].is_empty(), "장면 노드의 실행 오류를 통과로 셈")


func test_engine_error_is_not_failure() -> void:
	var r := await _run_fake("fake_engine_error_only")
	check(r["failures"].is_empty(), "push_error(엔진 오류 종류)는 실패로 세지 않음: %s" % [r["failures"]])


func test_clean_case_passes() -> void:
	var r := await _run_fake("fake_clean_pass")
	check_eq(r["failures"].size(), 0, "깨끗한 시험")


func test_timeout_fails() -> void:
	var r := await _run_fake("fake_hang")
	check(r["timed_out"], "시간 초과를 잡지 못함")
	check(not r["failures"].is_empty(), "시간 초과를 통과로 셈")


func test_queue_free_errors_stay_with_their_case() -> void:
	var r := await _run_fake("fake_scene_queue_free_only")
	check(not r["failures"].is_empty(), "queue_free 직전 프레임의 실행 오류를 그 시험 몫으로 잡지 못함")
	var next := await _run_fake("fake_clean_pass")
	check(next["failures"].is_empty(), "앞 시험의 오류가 다음 시험에 묻음: %s" % [next["failures"]])


func test_init_script_error_fails() -> void:
	var r := await _run_fake("fake_clean", FAKE_INIT)
	check(not r["failures"].is_empty(), "객체 생성(_init) 중 실행 오류를 통과로 셈")


func test_zero_timeout_stays_timed_out() -> void:
	var r := await _run_fake("fake_zero_timeout")
	check(r["timed_out"], "시간 한도 0 인데 timed_out 이 false")
	check(not r["failures"].is_empty(), "시간 한도 0 을 통과로 셈")
