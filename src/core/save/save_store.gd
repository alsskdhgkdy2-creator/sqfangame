## user:// 저장 슬롯. 쓰기: .tmp 쓰기 → .tmp 검사 → 정상 본 파일을 .bak 으로 → .tmp 를 본 파일로.
## 읽기: 본 파일 → .tmp → .bak 가운데 처음으로 검사를 통과한 것.
class_name SaveStore
extends RefCounted

const AUTO := "auto"
const MANUAL_SLOTS := ["slot1", "slot2", "slot3"]


## 읽기 결과: 상태(result.state), 읽은 후보, 후보가 있었는데 모두 실패했는지, 후보별 실패 사유.
class SlotLoad:
	extends RefCounted
	var result: SaveCodec.LoadResult
	var source := ""  # 읽은 파일 경로
	var source_kind := ""  # "main"·"tmp"·"bak", 못 읽었으면 ""
	var had_candidates := false  # 후보 파일이 하나라도 있었는지
	var failures: Array[String] = []  # 후보별 실패 이유

	func ok() -> bool:
		return result != null and result.ok()

	## 후보가 있었는데 모두 검사에 실패했는지(알려야 하는 경우).
	func all_failed() -> bool:
		return had_candidates and not ok()


## 슬롯 정보(메뉴 표시용).
class SlotInfo:
	extends RefCounted
	var exists := false  # 본 파일·.tmp·.bak 가운데 하나라도 있는지
	var ok := false  # 정상 후보가 있는지
	var saved_at := ""
	var generation := 0
	var source_kind := ""


## 파일 검사: 읽기 실패(read_error, 내용은 모름)와 읽었는데 내용이 틀림(error)을 나눈다.
class _FileCheck:
	extends RefCounted
	var read_error := ""
	var error := ""

	func good() -> bool:
		return read_error.is_empty() and error.is_empty()

	## 정상적으로 읽었는데 내용이 틀렸다(지워도 되는 깨진 후보).
	func broken() -> bool:
		return read_error.is_empty() and not error.is_empty()


var dir_path := "user://saves"
var floor_def: FloorModel
var members_def: Array[PartyState.Member] = []
## 시험용: 0이 아니면 쓰기 단계 ①~③ 가운데 그 단계를 마친 뒤 멈추고 실패로 돌려준다(중단 흉내).
var stop_after_step := 0
## 시험용: 들어 있는 지점마다 파일 작업이 실패한 것처럼 한다(한 번의 저장에 여러 실패를 겹칠 수 있다).
## "read_tmp"·"read_main"(쓰기 전 정리·③에서 남은 .tmp·본 파일 읽기),
## "settle_remove_tmp"·"settle_remove_main"·"settle_promote"(쓰기 전 정리), "write"(① 깨진 .tmp 를 남김),
## "move_main"(③ 시작), "after_bak_removed"(③ 이전 .bak 을 지운 뒤 본 파일을 옮기기 전), "rename_tmp"(④).
var fail_points: Array[String] = []


func _init(f: FloorModel, members: Array[PartyState.Member], path: String = "user://saves") -> void:
	floor_def = f
	members_def = members
	dir_path = path


func main_path(slot: String) -> String:
	return "%s/%s.json" % [dir_path, slot]


## 상태를 슬롯에 쓴다. 성공하면 "" 이고 상태의 generation 이 1 오른다. 실패하면 이유를 돌려주고 generation 은 그대로.
func save(slot: String, s: ExplorationState, saved_at: String = "") -> String:
	if s.generation < 0 or s.generation >= SaveCodec.MAX_GENERATION:
		return "generation 이 범위(0 ~ 2^53 − 2)를 넘어 더 저장할 수 없다"
	var why := _write_slot(slot, s, saved_at, s.generation + 1)
	if why.is_empty():
		s.generation += 1
	return why


func _write_slot(slot: String, s: ExplorationState, saved_at: String, generation: int) -> String:
	var err := DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK:
		return "저장 폴더를 만들 수 없다 (%s)" % error_string(err)
	var main := main_path(slot)
	var tmp := main.get_basename() + ".tmp"
	var bak := main.get_basename() + ".bak"
	var why := _settle_tmp(main, tmp)
	if not why.is_empty():
		return why
	why = _write_file(tmp, SaveCodec.encode(s, saved_at, generation))  # ①
	if not why.is_empty():
		return why
	if stop_after_step == 1:
		return "시험 중단: 1단계 뒤"
	var check := _check_file(tmp, "")  # ②
	if not check.good():
		DirAccess.remove_absolute(tmp)  # 정리 뒤라 이 .tmp 는 방금 쓴 것뿐이다(읽기 실패도 지운다)
		return "임시 파일 검사 실패: " + check.read_error + check.error
	if stop_after_step == 2:
		return "시험 중단: 2단계 뒤"
	if FileAccess.file_exists(main):  # ③
		if _fails("move_main"):
			return "본 파일을 옮길 수 없다 (시험 실패)"
		var main_check := _check_file(main, "read_main")
		if not main_check.read_error.is_empty():
			return main_check.read_error  # 못 읽은 본 파일은 깨진 것으로 보지 않고 그대로 둔다
		if main_check.good():
			if FileAccess.file_exists(bak):
				err = DirAccess.remove_absolute(bak)
				if err != OK:
					return "이전 .bak 을 지울 수 없다 (%s)" % error_string(err)
			if _fails("after_bak_removed"):
				return "본 파일을 .bak 으로 옮길 수 없다 (시험 실패)"
			err = DirAccess.rename_absolute(main, bak)
		else:
			err = DirAccess.remove_absolute(main)  # 깨진 본 파일은 .bak 으로 올리지 않는다
		if err != OK:
			return "본 파일을 옮길 수 없다 (%s)" % error_string(err)
	if stop_after_step == 3:
		return "시험 중단: 3단계 뒤"
	if _fails("rename_tmp"):
		return "임시 파일 이름을 바꿀 수 없다 (시험 실패)"
	err = DirAccess.rename_absolute(tmp, main)  # ④
	return "" if err == OK else "임시 파일 이름을 바꿀 수 없다 (%s)" % error_string(err)


## 쓰기 전 정리: 남은 .tmp 가 정상이고 본 파일이 없거나 깨졌으면 .tmp 를 본 파일로 올린다(깨진 본 파일은 지움).
## .tmp 가 깨졌으면 지운다. 다음 쓰기가 ①·②에서 실패해도 하나뿐인 정상 후보를 잃지 않게 한다.
## 어느 파일이든 읽기에 실패하면(내용은 모름) 아무것도 지우거나 옮기지 않고 실패로 돌려준다.
func _settle_tmp(main: String, tmp: String) -> String:
	if not FileAccess.file_exists(tmp):
		return ""
	var tmp_check := _check_file(tmp, "read_tmp")
	if not tmp_check.read_error.is_empty():
		return tmp_check.read_error
	if tmp_check.broken():
		var err := ERR_CANT_OPEN if _fails("settle_remove_tmp") else DirAccess.remove_absolute(tmp)
		return "" if err == OK else "깨진 .tmp 를 지울 수 없다 (%s)" % error_string(err)
	if not FileAccess.file_exists(main):
		return _promote(tmp, main)
	var main_check := _check_file(main, "read_main")
	if not main_check.read_error.is_empty():
		return main_check.read_error
	if main_check.good():
		return ""  # 본 파일이 정상이면 남은 .tmp 는 ①에서 덮어쓴다(읽기 순서상 본 파일이 먼저)
	var err := ERR_CANT_OPEN if _fails("settle_remove_main") else DirAccess.remove_absolute(main)
	if err != OK:
		return "깨진 본 파일을 지울 수 없다 (%s)" % error_string(err)
	return _promote(tmp, main)


func _promote(tmp: String, main: String) -> String:
	var err := ERR_CANT_OPEN if _fails("settle_promote") else DirAccess.rename_absolute(tmp, main)
	return "" if err == OK else "남은 .tmp 를 본 파일로 올릴 수 없다 (%s)" % error_string(err)


## 본 파일 → .tmp → .bak 순서로 처음 통과하는 것을 읽는다.
func load_slot(slot: String) -> SlotLoad:
	var out := SlotLoad.new()
	var main := main_path(slot)
	var kinds := ["main", "tmp", "bak"]
	var paths := [main, main.get_basename() + ".tmp", main.get_basename() + ".bak"]
	for i in paths.size():
		var path: String = paths[i]
		if not FileAccess.file_exists(path):
			continue
		out.had_candidates = true
		var r := SaveCodec.decode(FileAccess.get_file_as_string(path), floor_def, members_def)
		if r.ok():
			out.result = r
			out.source = path
			out.source_kind = kinds[i]
			return out
		out.failures.append("%s: %s" % [path.get_file(), r.error])
	out.result = SaveCodec.LoadResult.new()
	out.result.error = "읽을 수 있는 저장이 없다" if not out.had_candidates else "저장 후보가 모두 깨졌다: " + "; ".join(out.failures)
	return out


func slot_info(slot: String) -> SlotInfo:
	var l := load_slot(slot)
	var info := SlotInfo.new()
	info.exists = l.had_candidates
	info.ok = l.ok()
	if l.ok():
		info.saved_at = l.result.saved_at
		info.generation = l.result.generation
		info.source_kind = l.source_kind
	return info


## 「마지막 수동 저장」: slot1~3 가운데 검사를 통과한 것 중 saved_at 이 가장 늦은 슬롯. 없으면 "".
func latest_manual() -> String:
	var best := ""
	var best_at := ""
	for slot in MANUAL_SLOTS:
		var l := load_slot(slot)
		if l.ok() and l.result.saved_at > best_at:
			best = slot
			best_at = l.result.saved_at
	return best


## 본 파일·.tmp·.bak 을 모두 지운다.
func delete_slot(slot: String) -> void:
	var main := main_path(slot)
	for path in [main, main.get_basename() + ".tmp", main.get_basename() + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write_file(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "임시 파일을 열 수 없다 (%s)" % error_string(FileAccess.get_open_error())
	if _fails("write"):
		f.store_string(text.substr(0, text.length() / 2))
		f.close()
		return "임시 파일 쓰기 실패 (시험 실패)"
	f.store_string(text)
	var err := f.get_error()
	f.close()
	if err != OK:
		return "임시 파일 쓰기 실패 (%s)" % error_string(err)
	return ""


func _fails(point: String) -> bool:
	return fail_points.has(point)


## 파일을 읽어 검사한다. 열기·읽기 실패는 read_error, 읽었는데 내용이 틀리면 error.
func _check_file(path: String, read_point: String) -> _FileCheck:
	var c := _FileCheck.new()
	if _fails(read_point):
		c.read_error = "%s 을 읽을 수 없다 (시험 실패)" % path.get_file()
		return c
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		c.read_error = "%s 을 열 수 없다 (%s)" % [path.get_file(), error_string(FileAccess.get_open_error())]
		return c
	var text := f.get_as_text()
	var err := f.get_error()
	f.close()
	if err != OK and err != ERR_FILE_EOF:
		c.read_error = "%s 을 읽을 수 없다 (%s)" % [path.get_file(), error_string(err)]
		return c
	c.error = SaveCodec.decode(text, floor_def, members_def).error
	return c
