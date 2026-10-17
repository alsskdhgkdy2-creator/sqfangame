## 저장 파일과 따로 두는 설정(user://settings.json). 지금은 자동 지도 설정만.
class_name GameSettings
extends RefCounted

const PATH := "user://settings.json"

var automap := ExplorationRules.AUTOMAP_FLOOR


## 없거나 틀린 값은 기본값으로 둔다.
static func load_from(path: String = PATH) -> GameSettings:
	var s := GameSettings.new()
	if not FileAccess.file_exists(path):
		return s
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY and ExplorationRules.AUTOMAP_MODES.has(data.get("automap")):
		s.automap = data["automap"]
	return s


func save_to(path: String = PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"automap": automap}, "", true))
	var err := f.get_error()
	f.close()
	return err


## 바꾼 값이 올바르면 true.
func set_automap(mode: String) -> bool:
	if not ExplorationRules.AUTOMAP_MODES.has(mode):
		return false
	automap = mode
	return true
