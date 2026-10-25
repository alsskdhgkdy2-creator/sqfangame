## 웹 저장 반영 기다림과 「저장 중」 표시(05 §8.3) 시험. IndexedDB 는 가짜 읽기(FakeIdb)로 바꿔 넣는다.
## 표시는 IndexedDB 에 쓴 글이 실제로 들어간 것을 읽은 뒤에만 사라진다(시간으로 사라지지 않는다).
## 화면 시험의 저장은 장면 시험 임시 폴더에만 쓴다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")
const WINDOWS := [Vector2(1280, 720), Vector2(2400, 1000)]
const PATH := "/userfs/sqfangame/saves/auto.json"
const PATH1 := "/userfs/sqfangame/saves/slot1.json"

var kit: Kit
var _root_size := Vector2i.ZERO


func teardown() -> void:
	if kit != null:
		kit.dispose()
		kit = null
	if _root_size != Vector2i.ZERO:
		tree.root.size = _root_size


## 가짜 IndexedDB: files(경로 → 글·바이트, false = 기록은 있는데 내용을 읽을 수 없음)를 진짜 연결처럼 바이트로 읽어 준다. answer 가 false 면 결과를 내지 않고 held 에 쌓는다.
class FakeIdb:
	extends RefCounted
	var files := {}
	var answer := true
	var calls := 0
	var last_paths := PackedStringArray()
	var held: Array = []

	func read(paths: PackedStringArray, done: Callable) -> void:
		calls += 1
		last_paths = paths
		if answer:
			done.call(result(paths))
		else:
			held.append([paths, done])

	func result(paths: PackedStringArray) -> Dictionary:
		var out := {}
		for p in paths:
			var v: Variant = files.get(p)
			out[p] = (v as String).to_utf8_buffer() if typeof(v) == TYPE_STRING else v
		return out

	func release(i: int) -> void:
		var h: Array = held[i]
		(h[1] as Callable).call(result(h[0]))


static func _doc(generation: int, body: String = "") -> String:
	return JSON.stringify({"format": "sqfangame-save", "generation": generation, "state": {"steps": generation, "note": body}})


func _pending(fake: FakeIdb) -> SavePending:
	var sp := SavePending.new()
	sp.enabled = true
	sp.reader = fake.read
	return sp


## 파일 하나짜리 묶음으로 올린다.
static func _note(sp: SavePending, slot: String, path: String, generation: int, text: String) -> void:
	sp.note(slot, generation, {path: text.to_utf8_buffer()})


## 정해진 시간을 작은 걸음으로 흘린다(프레임마다 부르는 것과 같게).
static func _run(sp: SavePending, sec: float) -> void:
	var t := 0.0
	while t < sec - 0.0001:
		sp.tick(0.05)
		t += 0.05


# ---- 대기 판정(가짜 읽기) ----

func test_a_save_sets_pending_and_nothing_is_read_while_idle() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	var emits := [0]
	sp.changed.connect(func() -> void: emits[0] += 1)
	_run(sp, 2.0)
	check_eq(fake.calls, 0, "대기가 없으면 읽지 않는다")
	_note(sp, "auto", PATH, 5, _doc(5))
	check(sp.is_pending(), "저장하면 대기")
	check_eq(sp.generations(), {"auto": 5}, "대기 generation")
	check_eq(emits[0], 1, "올리면 changed")
	sp.tick(0.1)
	check_eq(fake.calls, 0, "동기화는 다음 프레임에 시작: 바로 읽지 않는다")
	_run(sp, 0.2)
	check_eq(fake.calls, 1, "POLL_SEC 뒤 첫 읽기")
	check_eq(fake.last_paths, PackedStringArray([PATH]), "그 슬롯의 경로를 읽는다")
	_run(sp, 1.0)
	check(fake.calls >= 4 and fake.calls <= 5, "대기 중에는 약 POLL_SEC 마다 읽는다: %d" % fake.calls)


func test_an_older_generation_in_idb_keeps_it_pending_with_no_timer() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	fake.files[PATH] = _doc(4)
	_note(sp, "auto", PATH, 5, _doc(5))
	_run(sp, 60.0)
	check(sp.is_pending(), "IndexedDB 가 낡은 generation 이면 1분이 지나도 대기(시간으로 내리지 않는다)")
	fake.files.erase(PATH)
	_run(sp, 1.0)
	check(sp.is_pending(), "IndexedDB 에 파일이 없어도 대기")
	var emits := [0]
	sp.changed.connect(func() -> void: emits[0] += 1)
	fake.files[PATH] = _doc(5)
	_run(sp, 0.3)
	check(not sp.is_pending(), "쓴 글(같은 generation)이 들어가면 내린다")
	check_eq(sp.generations(), {}, "대기 없음")
	check_eq(emits[0], 1, "내리면 changed")
	var n := fake.calls
	_run(sp, 2.0)
	check_eq(fake.calls, n, "내린 뒤에는 읽지 않는다")


func test_two_quick_saves_need_the_newer_one() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	_note(sp, "auto", PATH, 5, _doc(5))
	_note(sp, "auto", PATH, 6, _doc(6))
	check_eq(sp.generations(), {"auto": 6}, "같은 슬롯은 마지막 저장을 기다린다")
	fake.files[PATH] = _doc(5)
	_run(sp, 1.0)
	check(sp.is_pending(), "앞 저장만 들어갔으면 대기")
	fake.files[PATH] = _doc(6)
	_run(sp, 0.3)
	check(not sp.is_pending(), "새 저장(더 큰 generation)이 들어가면 내린다")


## 수동 슬롯을 불러오면 generation 이 그 파일 값으로 돌아간다(05 §8.1): IndexedDB 의 낡은 자동 저장이 방금 쓴 것보다
## 큰 generation 을 가질 수 있다. 그래서 generation 크기가 아니라 쓴 글 그대로를 본다.
func test_a_stale_save_with_a_larger_generation_does_not_clear_it() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	fake.files[PATH] = _doc(50, "before load")
	_note(sp, "auto", PATH, 11, _doc(11, "after load"))
	_run(sp, 1.0)
	check(sp.is_pending(), "다른 글이면 generation 이 더 커도 대기")
	fake.files[PATH] = _doc(11, "after load")
	_run(sp, 0.3)
	check(not sp.is_pending(), "쓴 글이 들어가면 내린다")


func test_slots_are_tracked_separately() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	_note(sp, "auto", PATH, 5, _doc(5))
	_note(sp, "slot1", PATH1, 6, _doc(6, "slot"))
	_run(sp, 0.3)
	check_eq(Array(fake.last_paths), [PATH, PATH1], "두 슬롯을 한 번에 읽는다")
	fake.files[PATH] = _doc(5)
	_run(sp, 0.3)
	check_eq(sp.generations(), {"slot1": 6}, "자동 저장만 들어가면 slot1 은 남는다")
	check_eq(Array(fake.last_paths), [PATH, PATH1], "")
	_run(sp, 0.3)
	check_eq(Array(fake.last_paths), [PATH1], "남은 슬롯만 읽는다")
	fake.files[PATH1] = _doc(6, "slot")
	_run(sp, 0.3)
	check(not sp.is_pending(), "slot1 도 들어가면 내린다")


func test_one_read_at_a_time_and_late_results_are_dropped() -> void:
	var fake := FakeIdb.new()
	fake.answer = false
	var sp := _pending(fake)
	_note(sp, "auto", PATH, 5, _doc(5))
	_run(sp, 3.0)
	check_eq(fake.calls, 1, "결과가 오기 전에는 다시 읽지 않는다")
	fake.files[PATH] = _doc(5)
	_run(sp, 2.5)
	check_eq(fake.calls, 2, "READ_TIMEOUT_SEC 가 지나도 안 오면 다시 읽는다")
	fake.release(0)
	check(sp.is_pending(), "버린 읽기의 늦은 결과는 쓰지 않는다")
	fake.release(1)
	check(not sp.is_pending(), "지금 읽기의 결과로 내린다")
	check_eq(fake.calls, 2, "")


## 묶음 전체를 본다: 마지막 이름 바꾸기가 실패하면 본 파일은 없고 .tmp 에 새 글, .bak 에 앞 글이 남는다.
## IndexedDB 가 그 묶음(없는 본 파일 포함)을 그대로 담아야 내린다. 읽기가 실패하면(빈 결과) 「모두 없음」으로 보지 않는다.
func test_the_whole_file_set_must_be_mirrored_including_absent_files() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	var tmp := PATH.get_basename() + ".tmp"
	var bak := PATH.get_basename() + ".bak"
	sp.note("auto", 6, {PATH: null, tmp: _doc(6).to_utf8_buffer(), bak: _doc(5).to_utf8_buffer()})
	fake.files[PATH] = _doc(5)
	_run(sp, 1.0)
	check(sp.is_pending(), "IndexedDB 에 앞 본 파일만 있으면 대기")
	check_eq(Array(fake.last_paths), [PATH, tmp, bak], "본 파일·.tmp·.bak 을 함께 읽는다")
	fake.files[tmp] = _doc(6)
	fake.files[bak] = _doc(5)
	_run(sp, 1.0)
	check(sp.is_pending(), "메모리에 없는 본 파일이 IndexedDB 에 남아 있으면 대기(읽기 순서상 그것을 고른다)")
	fake.files.erase(PATH)
	_run(sp, 0.3)
	check(not sp.is_pending(), "묶음이 그대로 들어가면 내린다")
	sp.note("slot1", 0, {PATH1: null})
	sp.reader = func(_paths: PackedStringArray, done: Callable) -> void: done.call({})
	_run(sp, 1.0)
	check(sp.is_pending(), "읽기 실패(빈 결과)는 「없음」으로 보지 않는다")


## 기록은 있는데 내용을 읽을 수 없으면(연결이 false 로 알린다) 「없음」으로도 「같은 내용」으로도 보지 않는다.
## 비교는 바이트 그대로라 UTF-8 이 아닌 파일도 같은 바이트가 들어가면 내린다.
func test_unreadable_records_never_match_and_bytes_compare_exactly() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	var tmp := PATH.get_basename() + ".tmp"
	var raw := PackedByteArray([0xff, 0xfe, 0x00, 0x41])
	sp.note("auto", 7, {PATH: raw, tmp: null})
	fake.files[PATH] = raw
	fake.files[tmp] = false
	_run(sp, 1.0)
	check(sp.is_pending(), "메모리에 없는 .tmp 가 IndexedDB 에 읽을 수 없는 기록으로 있으면 대기")
	fake.files.erase(tmp)
	fake.files[PATH] = false
	_run(sp, 1.0)
	check(sp.is_pending(), "본 파일 기록을 읽을 수 없으면 대기")
	fake.files[PATH] = PackedByteArray([0xff, 0xfe, 0x00, 0x42])
	_run(sp, 1.0)
	check(sp.is_pending(), "바이트가 하나라도 다르면 대기")
	fake.files[PATH] = raw
	_run(sp, 0.3)
	check(not sp.is_pending(), "UTF-8 이 아닌 파일도 같은 바이트가 들어가면 내린다")


func test_disabled_tracking_does_nothing() -> void:
	var fake := FakeIdb.new()
	var sp := _pending(fake)
	sp.enabled = false
	var emits := [0]
	sp.changed.connect(func() -> void: emits[0] += 1)
	_note(sp, "auto", PATH, 5, _doc(5))
	_run(sp, 1.0)
	check(not sp.is_pending() and fake.calls == 0 and emits[0] == 0, "웹이 아니거나 user:// 가 IndexedDB 에 이어지지 않으면 아무것도 하지 않는다")


# ---- 화면 ----

func _open(reader: Callable, persistent: int, platform: String = "native") -> DungeonScreen:
	timeout_sec = 120.0
	kit = Kit.new(tree)
	return await kit.open(platform, 7, "debug=1", func(s: DungeonScreen) -> void:
		s.save_reader = reader
		s.userfs_persistent = persistent)


func _wait(sec: float) -> void:
	await tree.create_timer(sec).timeout
	await kit.frames(1)


## 표시 = 대기, 상태 요약도 같다.
func _check_chip(s: DungeonScreen, want: bool, tag: String) -> void:
	var snap := s.debug_snapshot()
	check(s.save_pending.is_pending() == want and s.save_chip.is_visible_in_tree() == want and snap["save_pending"] == want
		and snap["save_chip"] == want, "%s: 대기·표시·상태 요약 = %s (대기 %s, 표시 %s)" % [tag, str(want),
		str(s.save_pending.is_pending()), str(s.save_chip.is_visible_in_tree())])


## 슬롯의 파일 묶음(본 파일·.tmp·.bak)을 가짜 IndexedDB 에 옮긴다(동기화가 끝난 것처럼: 없는 파일은 지운다).
static func _sync(s: DungeonScreen, fake: FakeIdb, slot: String) -> void:
	for path in s.store.candidate_paths(slot):
		var key := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			fake.files[key] = FileAccess.get_file_as_string(path)
		else:
			fake.files.erase(key)


func test_screen_shows_saving_until_idb_holds_the_written_save() -> void:
	var fake := FakeIdb.new()
	var s := await _open(fake.read, 1)
	check(s.save_pending.enabled, "가짜 읽기 + IndexedDB 이어짐 → 켜짐")
	_check_chip(s, true, "새 게임 자동 저장 직후")
	check_eq(s.debug_snapshot()["save_pending_gens"], {"auto": s.state.generation}, "상태 요약의 대기 generation")
	await _wait(0.6)
	check(fake.calls >= 1, "대기 중에 읽는다")
	_check_chip(s, true, "IndexedDB 가 비어 있으면")
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "자동 저장이 들어간 뒤")
	var old_text: String = fake.files[ProjectSettings.globalize_path(s.store.main_path("auto"))]
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check(JSON.parse_string(old_text)["generation"] < s.state.generation, "행동이 자동 저장")
	_check_chip(s, true, "행동 직후")
	check_eq(s.debug_snapshot()["save_pending_gens"], {"auto": s.state.generation}, "새 generation 을 기다린다")
	await _wait(0.6)
	_check_chip(s, true, "IndexedDB 에 앞 저장만 있으면")
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "새 저장이 들어간 뒤")
	# 수동 저장은 그 슬롯을 따로 기다린다
	s._save_slot("slot1")
	await kit.frames(1)
	_check_chip(s, true, "수동 저장 직후")
	check_eq(s.debug_snapshot()["save_pending_gens"], {"slot1": s.state.generation}, "slot1 만 기다린다")
	_sync(s, fake, "slot1")
	await _wait(0.5)
	_check_chip(s, false, "slot1 이 들어간 뒤")
	var idle := fake.calls
	await _wait(0.6)
	check_eq(fake.calls, idle, "대기가 없으면 읽지 않는다")
	# slot1 을 불러오면 generation 이 돌아간다: IndexedDB 의 자동 저장이 더 큰 generation 이어도 다른 글이면 기다린다
	await kit.press_key(KEY_W)
	await kit.frames(2)
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "한 걸음 더(들어감)")
	var stale_gen := s.state.generation
	s._load_slot("slot1")
	await kit.frames(1)
	# 새 게임 1 → 걸음 2 → slot1 3 → 걸음 4 → slot1 불러오기(3) → 자동 저장 4: IndexedDB 의 낡은 자동 저장과 generation 이 같다
	check(s.state.generation <= stale_gen, "불러오면 generation 이 slot1 값으로 돌아간다(%d <= %d)" % [s.state.generation, stale_gen])
	await _wait(0.6)
	_check_chip(s, true, "불러온 뒤 자동 저장: IndexedDB 의 낡은 글(generation 이 같거나 크다)로는 내리지 않는다")
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "불러온 뒤 자동 저장이 들어간 뒤")


## 마지막 이름 바꾸기(④)가 실패한 저장(실제 SaveStore 의 실패 지점): 본 파일은 .bak 으로 갔고 .tmp 에 새 글이 있다.
## IndexedDB 가 그 묶음을 담으면 내린다(본 파일 열쇠를 영영 기다리지 않는다). 담기 전에는 대기.
func test_failed_final_rename_clears_once_idb_mirrors_the_remaining_files() -> void:
	var fake := FakeIdb.new()
	var s := await _open(fake.read, 1)
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "새 게임 저장이 들어간 뒤")
	var g := s.state.generation
	s.store.fail_points.append("rename_tmp")
	await kit.press_key(KEY_W)
	await kit.frames(2)
	var main := s.store.main_path("auto")
	var paths := s.store.candidate_paths("auto")
	check(s.last_autosave_error != "" and s.state.generation == g, "자동 저장 실패(generation 그대로)")
	check(not FileAccess.file_exists(main) and FileAccess.file_exists(paths[1]) and FileAccess.file_exists(paths[2]), "본 파일 없음, .tmp·.bak 있음")
	_check_chip(s, true, "실패한 저장 직후")
	check_eq(s.debug_snapshot()["save_pending_gens"], {"auto": g + 1}, "쓰려던 generation")
	await _wait(0.6)
	_check_chip(s, true, "IndexedDB 에 앞 본 파일만 있으면")
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "남은 .tmp·.bak(본 파일 없음)이 그대로 들어간 뒤")
	s.store.fail_points.clear()
	await kit.press_key(KEY_W)
	await kit.frames(2)
	check(s.last_autosave_error == "" and FileAccess.file_exists(main), "다음 자동 저장은 성공")
	_check_chip(s, true, "다음 저장 직후")
	_sync(s, fake, "auto")
	await _wait(0.5)
	_check_chip(s, false, "다음 저장이 들어간 뒤")


## 화면을 다시 만들어도(같은 메모리 파일) IndexedDB 에 없는 저장은 기다린다: 시작할 때 메모리의 슬롯을 모두 올린다.
func test_recreated_screen_keeps_waiting_for_saves_not_in_idb() -> void:
	var fake := FakeIdb.new()
	var s := await _open(fake.read, 1)
	s._save_slot("slot1")
	await kit.frames(1)
	check_eq(s.save_pending.generations().keys(), ["auto", "slot1"], "다시 만들기 전 대기: 자동 저장·slot1")
	kit.close_screen()
	await kit.frames(1)
	s = await kit.open("native", 7, "debug=1", func(d: DungeonScreen) -> void:
		d.save_reader = fake.read
		d.userfs_persistent = 1)
	await kit.frames(2)
	var gens: Dictionary = s.debug_snapshot()["save_pending_gens"]
	check(gens.keys() == ["auto", "slot1"] and int(gens["auto"]) == 1 and int(gens["slot1"]) == 2,
		"다시 만든 화면도 두 슬롯을 기다린다(파일의 generation): %s" % str(gens))
	_check_chip(s, true, "다시 만든 직후")
	await _wait(0.6)
	check(fake.calls >= 1, "다시 만든 화면이 읽는다")
	_check_chip(s, true, "IndexedDB 가 비어 있으면")
	_sync(s, fake, "auto")
	await _wait(0.5)
	check_eq(s.save_pending.generations().keys(), ["slot1"], "자동 저장만 들어가면 slot1 이 남는다")
	_sync(s, fake, "slot1")
	await _wait(0.5)
	_check_chip(s, false, "둘 다 들어간 뒤")


## 본 파일이 깨진 채로(generation 이 정수가 아님) 시작해도 슬롯을 모두 올린다: 깨진 본 파일은 generation -1 로,
## 게임은 .bak 으로 이어 하고, IndexedDB 가 묶음을 담을 때까지 기다린다.
func test_corrupt_main_at_start_still_registers_every_slot() -> void:
	var fake := FakeIdb.new()
	var s := await _open(fake.read, 1)
	await kit.press_key(KEY_W)
	await kit.frames(2)
	s._save_slot("slot1")
	await kit.frames(1)
	var bak := s.store.candidate_paths("auto")[2]
	check(FileAccess.file_exists(bak), "자동 저장의 .bak 이 있다")
	kit.close_screen()
	await kit.frames(1)
	var f := FileAccess.open(kit.dir + "/saves/auto.json", FileAccess.WRITE)  # 앞 화면(s)은 이미 풀렸다
	f.store_string('{"generation": {"bad": true}}')
	f.close()
	s = await kit.open("native", 7, "debug=1", func(d: DungeonScreen) -> void:
		d.save_reader = fake.read
		d.userfs_persistent = 1)
	await kit.frames(2)
	check(s.state != null and s.state.generation == 1, "깨진 본 파일 대신 .bak(generation 1)으로 이어 한다: %d" % (s.state.generation if s.state else -9))
	var gens: Dictionary = s.debug_snapshot()["save_pending_gens"]
	check(gens.keys() == ["auto", "slot1"] and int(gens["auto"]) == -1 and int(gens["slot1"]) == 3,
		"깨진 본 파일의 슬롯(generation -1)과 그 뒤 슬롯을 모두 기다린다: %s" % str(gens))
	await _wait(0.6)
	_check_chip(s, true, "IndexedDB 가 비어 있으면")
	_sync(s, fake, "auto")
	_sync(s, fake, "slot1")
	await _wait(0.5)
	_check_chip(s, false, "두 묶음이 들어간 뒤")


func test_screen_shows_nothing_without_web_or_persistent_userfs() -> void:
	for c in [["native", -1, false], ["web", -1, false], ["native", 0, true]]:
		var fake := FakeIdb.new()
		var tag := "플랫폼 %s, 이어짐 %d, 가짜 읽기 %s" % [c[0], c[1], str(c[2])]
		var s := await _open(fake.read if c[2] else Callable(), c[1], c[0])
		await kit.press_key(KEY_W)
		await _wait(0.4)
		check(not s.save_pending.enabled and s.autosave_count >= 2, tag + ": 꺼짐(저장은 된다)")
		_check_chip(s, false, tag)
		check(fake.calls == 0 and s.debug_snapshot()["save_reads"] == 0, tag + ": 읽지 않는다")
		kit.dispose()
		kit = null


# ---- 표시 자리 ----

## 실제 창 크기를 바꾸고 논리 크기를 돌려준다(2400×1000 → 1728×720).
func _window(px: Vector2) -> Vector2:
	if _root_size == Vector2i.ZERO:
		_root_size = tree.root.size
	tree.root.size = Vector2i(px)
	await kit.frames(3)
	return tree.root.get_visible_rect().size


## 두 창 크기에서: 보이고, 누르기를 받지 않고, 높이 32 이하, 화면 안, 보이는 누르는 것(단추·카드·목록 줄)과 겹치지 않는다.
func _check_spot(s: DungeonScreen, what: String) -> void:
	for px in WINDOWS:
		var size: Vector2 = await _window(px)
		var tag := "%s %s" % [what, str(px)]
		var r := s.save_chip.get_global_rect()
		check(s.save_chip.is_visible_in_tree() and s.save_chip.modulate.a > 0.99, tag + ": 표시가 보인다")
		check(s.save_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, tag + ": 누르기를 받지 않는다")
		check(r.size.y <= 32.0 and r.size.y >= 16.0, "%s: 높이 %.1f" % [tag, r.size.y])
		check(Rect2(Vector2.ZERO, size).encloses(r), "%s: 화면 안 %s" % [tag, str(r)])
		check(absf(r.get_center().x - size.x / 2.0) < 1.0 and r.position.y <= 8.0, "%s: 위 가운데 %s" % [tag, str(r)])
		var hits: Array[String] = []
		for n in s.find_children("*", "Control", true, false):
			var c := n as Control
			if not (c is TouchButton or c is BaseButton) or not c.is_visible_in_tree() or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			if c.get_global_rect().intersects(r):
				hits.append("%s %s" % [c.name, str(c.get_global_rect())])
		check(hits.is_empty(), "%s: 겹치는 누르는 것 %s" % [tag, str(hits)])


func test_saving_chip_spot_is_free_on_every_screen() -> void:
	var fake := FakeIdb.new()
	fake.answer = false  # 결과가 오지 않는다: 표시가 계속 보인다
	var s := await _open(fake.read, 1)
	await _wait(0.3)
	await _check_spot(s, "탐색")
	s._toggle_map()
	await kit.frames(3)
	await _check_spot(s, "지도 펼침")
	s._toggle_map()
	await kit.frames(3)
	s._alert("시험")
	await kit.frames(3)
	await _check_spot(s, "알림 창")
	s.modal.close()
	await kit.frames(2)
	var pm := s.party_menu
	await kit.press_key(KEY_P)
	check(pm.is_open() and pm.page == "root", "캠프 뿌리")
	await _check_spot(s, "캠프 뿌리")
	pm.handle("camp", 0)
	await kit.frames(3)
	check_eq(pm.page, "pick", "대원 고르기")
	await _check_spot(s, "캠프 대원 고르기")
	pm.handle("member", 1)
	await kit.frames(3)
	for t in 5:
		if t > 0:
			pm.handle("tab", t)
			await kit.frames(3)
		check(pm.page == "sub" and pm.tab == t, "캠프 하위 화면 %d" % t)
		await _check_spot(s, "캠프 하위 화면 %d" % t)
	pm.handle("close")
	await kit.frames(3)
	s.state.encounter.danger = s.state.encounter.threshold - 1
	for k in 6:
		if s.battle_layer.is_open():
			break
		await kit.press_key(KEY_W)
	await kit.frames(3)
	check(s.battle_layer.is_open(), "전투")
	await _check_spot(s, "전투 명령")
	s.battle_layer.handle("command", 0)
	await kit.frames(3)
	check_eq(s.battle_layer.sub, "target", "대상 고르기")
	await _check_spot(s, "전투 대상")
	s.battle_layer.handle("back")
	await kit.frames(2)
	s.battle_layer.handle("log")
	await kit.frames(3)
	check(s.battle_layer.log_view.visible, "전투 로그")
	await _check_spot(s, "전투 로그")
