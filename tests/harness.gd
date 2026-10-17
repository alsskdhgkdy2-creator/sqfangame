## 시험 실행 공통부(실행기 run.gd 와 실행기 자체 시험이 같이 쓴다). test_ 로 시작하지 않아 시험으로 읽히지 않는다.
## 시험 하나를 돌리고 끝·실행 오류·시간 초과를 기다린다. 실행 오류(ERROR_TYPE_SCRIPT)가 하나라도 나면 그 시험은 실패다.
## 엔진 오류(ERROR_TYPE_ERROR, push_error 포함)는 세지 않는다: 일부러 쓰기 실패를 내는 저장 시험이 있다.
class_name TestHarness
extends RefCounted


## 엔진이 내는 오류를 받아 실행 오류만 모은다. 다른 스레드에서 올 수 있어 잠근다.
class ErrorCounter:
	extends Logger
	var _lock := Mutex.new()
	var _messages: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		_lock.lock()
		_messages.append("실행 오류 %s:%d %s — %s" % [file.get_file(), line, function, rationale if not rationale.is_empty() else code])
		_lock.unlock()

	func size() -> int:
		_lock.lock()
		var n := _messages.size()
		_lock.unlock()
		return n

	## from 번째부터의 오류. absorb 면 목록에서 빼서 바깥 시험의 오류로 세지 않게 한다.
	func take_from(from: int, absorb: bool) -> Array[String]:
		_lock.lock()
		var out: Array[String] = _messages.slice(from)
		if absorb:
			_messages.resize(from)
		_lock.unlock()
		return out


static var _counter: ErrorCounter


static func counter() -> ErrorCounter:
	if _counter == null:
		_counter = ErrorCounter.new()
		OS.add_logger(_counter)
	return _counter


## 스크립트에서 시험 객체를 만들고 돌린다. 오류 집계는 객체 생성(_init)부터 이 시험 몫이다.
## 결과 {failures, timed_out, script_errors}. 생성 실패도 실패다.
static func run_named(tree: SceneTree, script: GDScript, name: String, absorb: bool = false) -> Dictionary:
	var start := counter().size()
	var obj: Variant = script.new() if script != null and script.can_instantiate() else null
	var case := obj as TestCase
	if case == null:
		case = TestCase.new()
		case.failures.append("시험 객체를 만들 수 없다")
		var errors := counter().take_from(start, absorb)
		case.failures.append_array(errors)
		return {"failures": case.failures, "timed_out": false, "script_errors": errors.size()}
	case.tree = tree
	var r := await _run(tree, case, name, absorb, start)
	r["failures"] = case.failures
	return r


## 이미 만든 시험 객체를 돌린다(집계는 여기서 시작). 결과 {timed_out, script_errors}.
static func run_case(tree: SceneTree, case: TestCase, name: String, absorb: bool = false) -> Dictionary:
	return await _run(tree, case, name, absorb, counter().size())


## case.call(name) 을 돌리고 끝날 때까지 기다린다. 실패 이유(시간 초과·실행 오류)는 case.failures 에 넣는다.
## absorb = 이 시험의 실행 오류를 바깥 시험에 넘기지 않는다.
static func _run(tree: SceneTree, case: TestCase, name: String, absorb: bool, start: int) -> Dictionary:
	var c := counter()
	var done := [false]
	var runner := func() -> void:
		await case.call(name)
		done[0] = true
	runner.call()
	if not done[0]:
		var deadline := Time.get_ticks_msec() + int(case.timeout_sec * 1000.0)
		while not done[0] and Time.get_ticks_msec() < deadline:
			await tree.process_frame
	# 대기가 끝난 시점에 고정한다(정리 뒤 한 프레임 사이에 끝나도 시간 초과는 시간 초과다).
	var timed_out: bool = not done[0]
	var errors := c.take_from(start, absorb)
	var mark := start if absorb else start + errors.size()
	if timed_out:
		case.failures.append("시간 초과 (%.1f초)" % case.timeout_sec)
	for e in errors:
		case.failures.append(e)
	case.teardown()
	# 한 프레임 더 기다린 뒤 집계를 닫는다: queue_free 된 노드의 마지막 _process·call_deferred 에서 난 오류도
	# 다음 시험이 아니라 이 시험의 실패로 잡히고, 마지막 시험의 오류도 빠지지 않는다.
	await tree.process_frame
	var late := c.take_from(mark, absorb)
	for e in late:
		case.failures.append(e)
	errors.append_array(late)
	return {"timed_out": timed_out, "script_errors": errors.size()}
