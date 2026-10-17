## 헤드리스 시험 실행기: godot --headless -s tests/run.gd
## tests/ 안의 test_*.gd 파일에서 test_ 로 시작하는 함수를 모두 실행한다. 실패가 있으면 종료 코드 1.
## 프레임을 기다리는 시험(장면 시험, 코루틴)도 같은 경로로 돈다: 끝·실행 오류·시간 초과(기본 10초)를 기다린 뒤 판정한다
## (tests/harness.gd). 실행 오류로 멈춘 시험은 failures 가 비어 있어도 실패다.
## 걸러 돌리기: godot --headless -s tests/run.gd -- <파일 이름 일부>
extends SceneTree

const Harness := preload("res://tests/harness.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Harness.counter()
	var total := 0
	var failed := 0
	var only := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = args[0]
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for file in files:
		if not only.is_empty() and not file.contains(only):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			printerr("FAIL %s — 스크립트를 읽을 수 없다" % file)
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var r: Dictionary = await Harness.run_named(self, script, name)
			if r["failures"].is_empty():
				print("PASS %s::%s" % [file, name])
			else:
				failed += 1
				for f in r["failures"]:
					printerr("FAIL %s::%s — %s" % [file, name, f])
	print("결과: %d개 중 %d개 실패" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
