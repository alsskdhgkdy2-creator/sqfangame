## 장면 시험 도구(tests/scene_kit.gd)의 임시 폴더 정리: 지울 대상만 지우고, 링크는 따라가지 않는다.
## 링크 대상은 user:// 밖 /tmp 아래에 새로 만든 폴더만 쓴다(user://saves 는 만들지도 쓰지도 지우지도 않는다).
## 시험이 만드는 user:// 이름은 시험 전에 없던 것만 자기 것으로 등록하고, teardown 은 그것만 지운다.
extends TestCase

const Kit := preload("res://tests/scene_kit.gd")

var _target := ""
## 이 시험이 실제로 새로 만든 user:// 바로 아래 이름(폴더·링크). teardown 은 이것만 지운다.
## 시험 전에 있던 이름은 등록하지 않는다(_claim 이 거절). user://saves 는 만들지도 쓰지도 지우지도 않는다.
var _owned: Array[String] = []
## 「미리 있던 폴더」를 흉내 내려고 만든 준비물(정리 대상 _owned 가 아니다). teardown 이 시험 정리 뒤 따로 걷는다.
var _fixtures: Array[String] = []


func teardown() -> void:
	_cleanup_owned()
	for name in _fixtures:
		_remove_user_entry(name)
	_fixtures.clear()
	if not _target.is_empty() and _target.begins_with("/tmp/sqfangame_kit_probe_"):
		DirAccess.remove_absolute(_target + "/keep.txt")
		DirAccess.remove_absolute(_target + "/sub/deep.txt")
		DirAccess.remove_absolute(_target + "/sub")
		DirAccess.remove_absolute(_target)


## 시험 정리: 소유 목록의 이름만 지운다(링크는 링크만, 폴더 안의 링크도 따라가지 않는다).
func _cleanup_owned() -> void:
	for name in _owned:
		_remove_user_entry(name)
	_owned.clear()


func _remove_user_entry(name: String) -> void:
	if name.is_empty() or name == "saves" or name.contains("/") or name.contains(".."):
		return
	var root := DirAccess.open("user://")
	if root == null:
		return
	if root.is_link(name):
		root.remove(name)
	elif root.dir_exists(name):
		Kit._remove_tree("user://" + name)


## user:// 바로 아래 이름이 이미 있는지(폴더·파일·링크 모두).
func _exists(name: String) -> bool:
	var root := DirAccess.open("user://")
	return root != null and (root.dir_exists(name) or root.file_exists(name) or root.is_link(name))


## 없던 이름이면 폴더(sub 경로 포함)를 만들고 소유로 등록한다. 이미 있으면 아무것도 하지 않고 false.
func _claim_dir(name: String, sub: String = "") -> bool:
	if name == "saves" or _exists(name):
		return false
	if DirAccess.make_dir_recursive_absolute("user://" + name.path_join(sub)) != OK:
		return false
	_owned.append(name)
	return true


## 고정 이름이 시험 전에 이미 있어 그 사례를 건너뛸 때 남기는 출력.
func _skip(name: String, what: String) -> void:
	print("  user://%s 가 시험 전에 이미 있어 건드리지 않고 「%s」 사례를 건너뛴다" % [name, what])


func _write(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("keep")
	f.close()


func _make_target() -> void:
	_target = "/tmp/sqfangame_kit_probe_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_target + "/sub")
	for p in [_target + "/keep.txt", _target + "/sub/deep.txt"]:
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("keep")
		f.close()


func _target_intact() -> bool:
	return FileAccess.file_exists(_target + "/keep.txt") and FileAccess.file_exists(_target + "/sub/deep.txt")


## 접두어 자체 이름(user://test_scene_)은 지울 대상이 아니다: 정리가 단언 없이 건너뛰고 다른 대상은 계속 지운다.
## 시험이 새로 만든 이름만 자기 것으로 등록한다. 고정 이름이 이미 있으면 그 사례는 건너뛴다(출력).
func test_purge_skips_bare_prefix_and_continues() -> void:
	_purge_case()


## 접두어 자체 이름 사례. 고정 이름을 이 시험이 새로 만들었으면 true, 이미 있어 건너뛰었으면 false.
func _purge_case() -> bool:
	var bare := Kit.PREFIX
	var stale := Kit.PREFIX + "skip_probe_%d" % Time.get_ticks_usec()
	var bare_ok := _claim_dir(bare)
	if not bare_ok:
		_skip(bare, "접두어 자체 이름은 남긴다")
	check(_claim_dir(stale, "saves"), "준비: 대상 폴더(새 이름)")
	Kit.purge_stale()
	if bare_ok:
		check(DirAccess.dir_exists_absolute("user://" + bare), "user://test_scene_ 그 자체는 남긴다")
	check(not DirAccess.dir_exists_absolute("user://" + stale), "그 옆의 대상 폴더는 지운다")
	return bare_ok


## 대조(검토 반례): 시험 전에 user://test_scene_/keep.txt 가 있으면 위 사례는 그 폴더를 자기 것으로 등록하지 않고 건너뛰며,
## 시험 정리 뒤에도 폴더와 파일이 그대로 남는다. 폴더가 정말 미리 있으면 그 안을 바꾸지 않고 목록이 그대로인지만 본다.
## 없으면 「미리 있던 폴더」를 준비물로 흉내 낸다(준비물은 시험 정리 대상이 아니고 teardown 이 따로 걷는다).
func test_preexisting_fixed_name_survives_cleanup() -> void:
	var bare := Kit.PREFIX
	var real := _exists(bare)
	if not real:
		DirAccess.make_dir_recursive_absolute("user://" + bare)
		_fixtures.append(bare)
		_write("user://%s/keep.txt" % bare)
	var before := _listing("user://" + bare)
	check(not _purge_case(), "미리 있던 이름이면 접두어 사례를 건너뛴다")
	check(not _owned.has(bare), "미리 있던 이름은 소유 목록에 없다")
	_cleanup_owned()
	check(DirAccess.dir_exists_absolute("user://" + bare), "시험 정리 뒤에도 미리 있던 폴더가 남는다")
	check_eq(_listing("user://" + bare), before, "미리 있던 폴더의 내용이 그대로다")
	if not real:
		check(FileAccess.file_exists("user://%s/keep.txt" % bare), "미리 있던 파일이 남는다")


func _listing(path: String) -> Array:
	var d := DirAccess.open(path)
	if d == null:
		return []
	var out := []
	for n in d.get_directories():
		out.append(n + "/")
	for n in d.get_files():
		out.append(n)
	out.sort()
	return out


## 임시 폴더 안의 링크와 임시 폴더 이름의 링크가 /tmp 의 대상 폴더를 가리켜도 대상과 그 안 파일은 남는다.
func test_purge_does_not_follow_links() -> void:
	_make_target()
	var tag := Time.get_ticks_usec()
	var holder := Kit.PREFIX + "link_holder_%d" % tag
	var root_link := Kit.PREFIX + "link_root_%d" % tag
	check(_claim_dir(holder, "inner"), "준비: 링크를 품을 새 폴더")
	if _exists(root_link):
		_skip(root_link, "임시 폴더 이름의 링크")
		return
	var user_abs := ProjectSettings.globalize_path("user://")
	var d := DirAccess.open("user://" + holder)
	var e1 := d.create_link(_target, ProjectSettings.globalize_path("user://%s/linked" % holder))
	var e2 := d.create_link(_target + "/keep.txt", ProjectSettings.globalize_path("user://%s/inner/file_link.txt" % holder))
	var e3 := DirAccess.open("user://").create_link(_target, user_abs.path_join(root_link))
	if e3 == OK:
		_owned.append(root_link)
	if e1 != OK or e2 != OK or e3 != OK:
		print("  링크를 만들 수 없는 환경이라 건너뛴다 (%s, %s, %s)" % [error_string(e1), error_string(e2), error_string(e3)])
		return
	check(d.is_link("linked") and DirAccess.open("user://").is_link(root_link), "준비: 링크 둘")
	check(d.get_directories().has("linked"), "준비: 폴더 링크가 폴더로 보인다(따라가면 대상을 지운다)")
	Kit.purge_stale()
	check(_target_intact(), "링크 대상 폴더와 그 안 파일이 남는다")
	check(DirAccess.dir_exists_absolute(_target + "/sub"), "대상의 하위 폴더도 남는다")
	check(not DirAccess.dir_exists_absolute("user://" + holder), "링크를 품은 임시 폴더는 지운다")
	check(not DirAccess.open("user://").is_link(root_link) and not DirAccess.dir_exists_absolute("user://" + root_link), "임시 폴더 이름의 링크는 링크만 지운다")
