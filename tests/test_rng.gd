extends TestCase


func test_same_seed_same_sequence() -> void:
	var a := GameRng.new(42)
	var b := GameRng.new(42)
	for i in 100:
		check_eq(a.randi_range(0, 1000), b.randi_range(0, 1000), "%d번째 값" % i)


func test_state_restore_replays() -> void:
	var r := GameRng.new(7)
	r.randi_range(0, 10)
	var saved := r.get_state()
	var first := [r.randi_range(0, 1000), r.randi_range(0, 1000), r.randi_range(0, 1000)]
	r.set_state(saved)
	var again := [r.randi_range(0, 1000), r.randi_range(0, 1000), r.randi_range(0, 1000)]
	check_eq(again, first, "상태 복원 뒤 같은 수열")
