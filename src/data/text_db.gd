## 화면 문구(data/text/ko.json). 없는 키는 키 그대로 돌려준다.
class_name TextDb
extends RefCounted

var _texts := {}


static func load_path(path: String) -> TextDb:
	var db := TextDb.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			if typeof(data[k]) == TYPE_STRING:
				db._texts[k] = data[k]
	return db


func has(key: String) -> bool:
	return _texts.has(key)


## 문구. args가 있으면 "{name}" 자리를 채운다.
func t(key: String, args: Dictionary = {}) -> String:
	var s: String = _texts.get(key, key)
	return s.format(args) if not args.is_empty() else s
