## 헤드리스 시험 실행기: godot --headless -s tests/run.gd
## tests/ 안의 test_*.gd 파일에서 test_ 로 시작하는 함수를 모두 실행한다. 실패가 있으면 종료 코드 1.
extends SceneTree


func _init() -> void:
	var total := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.call(name)
			total += 1
			if case.failures.is_empty():
				print("PASS %s::%s" % [file, name])
			else:
				failed += 1
				for f in case.failures:
					printerr("FAIL %s::%s — %s" % [file, name, f])
	print("결과: %d개 중 %d개 실패" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
