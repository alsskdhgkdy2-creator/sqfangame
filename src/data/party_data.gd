## 시험 대원 정의(data/party/*.json): id·name_key·max_hp. 순서가 대열 순서다.
class_name PartyData
extends RefCounted

var ids: Array[String] = []
var name_keys: Array[String] = []
var max_hps: Array[int] = []
var errors: Array[String] = []


static func load_path(path: String) -> PartyData:
	return parse_text(FileAccess.get_file_as_string(path), path.get_file())


static func parse_text(text: String, source: String) -> PartyData:
	var p := PartyData.new()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("members")) != TYPE_ARRAY:
		p.errors.append("%s: members 배열이 없다" % source)
		return p
	for i in data["members"].size():
		var m: Variant = data["members"][i]
		var hp: Variant = SaveCodec.to_int(m.get("max_hp")) if typeof(m) == TYPE_DICTIONARY else null
		if hp == null or hp < 1 or typeof(m.get("id")) != TYPE_STRING or p.ids.has(m["id"]):
			p.errors.append("%s: members[%d] 의 id·max_hp 가 올바르지 않다" % [source, i])
			continue
		p.ids.append(m["id"])
		p.name_keys.append(str(m.get("name_key", "member." + m["id"])))
		p.max_hps.append(hp)
	return p


## HP를 가득 채운 대원 목록.
func make_members() -> Array[PartyState.Member]:
	var out: Array[PartyState.Member] = []
	for i in ids.size():
		out.append(PartyState.Member.new(ids[i], max_hps[i], max_hps[i]))
	return out
