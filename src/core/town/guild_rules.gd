## 모험가 길드 규칙(M3 A7 설계 §4.1·§4.1b·§4.2): 등록·이름 바꾸기·등록 지우기·편성(파티 넣고 빼기, 마을만)·대열 바꾸기(파티 안 순서·열, 마을·미궁).
## 노드·시간·엔진에 기대지 않고 난수를 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(06 §3.2 방식).
## 거부하면 {"type": "rejected", "reason": …} 하나만 내고 상태를 바꾸지 않는다.
##
## 이벤트:
##   {"type": "registered", "id", "class", "look", "name"}
##   {"type": "renamed", "id", "name"}
##   {"type": "removed", "id", "returned": [장비 ID]}   낀 장비는 공용 가방으로 간다
##   {"type": "formed", "front": [ID], "back": [ID]}
##   {"type": "arranged", "front": [ID], "back": [ID]}
## 거부 이유: not_town · in_battle · wiped · guild_full · unknown_class · bad_look · name_empty · name_long · name_chars · name_taken ·
##   unknown_member · in_party · bag_full · bad_list · duplicate · party_empty · party_full · party_down · row_full · not_party · unchanged
class_name GuildRules
extends RefCounted

const EVENT_TYPES := ["rejected", "registered", "renamed", "removed", "formed", "arranged"]
## 등록 명부(파티 + 길드) 상한. 원작 정원은 확인하지 못한 기능 값(D15).
const GUILD_MAX := 30
## 직업마다 외형 수(04 §2.4 「직업마다 외형 2종」). 그림 전(B6)에는 자리표시다.
const LOOKS := 2
## 이름 글자 수 상한(앞뒤 공백을 뺀 글자 수).
const NAME_MAX := 8
## 등록 번호 상한(저장 검사 범위). 새 대원 ID 는 RECRUIT_PREFIX + 번호.
const SERIAL_MAX := 9999
const RECRUIT_PREFIX := "r"


# ---- 읽기 ----

## 등록 명부: 파티(칸 순) 다음 길드(등록 차례). 새 배열이고 대원 객체는 같다.
static func roster(s: ExplorationState) -> Array[PartyState.Member]:
	var out: Array[PartyState.Member] = []
	out.append_array(s.party.members)
	out.append_array(s.guild.members)
	return out


## ID 로 대원 찾기(파티·길드). 없으면 null.
static func find(s: ExplorationState, id: String) -> PartyState.Member:
	for m in roster(s):
		if m.id == id:
			return m
	return null


## 새 대원 ID 의 번호(r12 → 12). 새 대원 ID 꼴(r 뒤에 0 으로 시작하지 않는 ASCII 숫자 1~4자리)이 아니면 -1.
## 부호·앞 0·소수점·공백(r+1·r01·r-1·r1.0·r 1)은 register 가 만들지 않으므로 받지 않는다.
static func recruit_number(id: String) -> int:
	if not id.begins_with(RECRUIT_PREFIX):
		return -1
	var rest := id.substr(RECRUIT_PREFIX.length())
	if rest.is_empty() or rest.length() > 4 or rest.begins_with("0"):
		return -1
	for ch in rest:
		if ch < "0" or ch > "9":
			return -1
	return rest.to_int()


## 이름 규칙(§4.2): "" | name_empty | name_long | name_chars. 앞뒤 공백·겹친 공백도 name_chars 다(화면이 strip_edges 한 뒤 묻는다).
## 받는 글자: 한글 음절(U+AC00~D7A3), 한글 호환 자모(U+3131~318E), ASCII 영문·숫자, 낱말 사이 공백 하나.
static func name_problem(name: String) -> String:
	if name.is_empty():
		return "name_empty"
	if name.length() > NAME_MAX:
		return "name_long"
	if name != name.strip_edges() or name.contains("  "):
		return "name_chars"
	for i in name.length():
		var c := name.unicode_at(i)
		var ok := (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3131 and c <= 0x318E) or (c >= 0x30 and c <= 0x39) \
			or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or c == 0x20
		if not ok:
			return "name_chars"
	return ""


## 그 이름을 쓸 수 있는지(규칙 + 겹침). taken 은 부르는 쪽이 넘기는 화면 이름들(기본 다섯의 이름 키 글 포함, 자기 자신은 뺀다).
## 등록한 이름(literal)끼리의 겹침은 여기서도 본다(except_id 대원은 뺀다).
static func name_block(s: ExplorationState, name: String, taken: Array = [], except_id: String = "") -> String:
	var why := name_problem(name)
	if not why.is_empty():
		return why
	if taken.has(name):
		return "name_taken"
	for m in roster(s):
		if m.id != except_id and m.name == name:
			return "name_taken"
	return ""


# ---- 바꾸기 ----

## 등록(§4.1): 레벨 1, 스킬 없음(SP 3), 직업 시작 장비(새로 생긴다), HP·TP 가득. 길드(파티 밖)에 들어간다.
static func register(s: ExplorationState, class_id: String, look: Variant, name: String, taken: Array = []) -> Array[Dictionary]:
	var why := _town_block(s)
	if why.is_empty() and (roster(s).size() >= GUILD_MAX or s.guild.serial >= SERIAL_MAX):
		why = "guild_full"
	var c: BattleDb.ClassDef = s.defs.battle.classes.get(class_id) if why.is_empty() else null
	if why.is_empty() and c == null:
		why = "unknown_class"
	if why.is_empty() and (typeof(look) != TYPE_INT or look < 0 or look >= LOOKS):
		why = "bad_look"
	if why.is_empty():
		why = name_block(s, name, taken)
	if not why.is_empty():
		return [_reject(why)]
	var m := PartyState.Member.new("%s%d" % [RECRUIT_PREFIX, s.guild.serial + 1])
	m.class_id = class_id
	m.name = name
	m.look = look
	m.row = "front"
	m.level = 1
	m.exp = s.defs.battle.growth.cum(1)
	m.skills = {}
	m.equip = c.start_equip.duplicate()
	GrowthRules.refresh_max(s.defs, -1, m)
	m.hp = m.max_hp
	m.tp = m.max_tp
	s.guild.serial += 1
	s.guild.members.append(m)
	return [{"type": "registered", "id": m.id, "class": class_id, "look": look, "name": name}]


## 이름 바꾸기(§4.2): 같은 이름 규칙. 기본 다섯도 이름을 얻을 수 있다(그 뒤로는 등록한 이름을 쓴다).
static func rename(s: ExplorationState, id: String, name: String, taken: Array = []) -> Array[Dictionary]:
	var why := _town_block(s)
	var m := find(s, id) if why.is_empty() else null
	if why.is_empty() and m == null:
		why = "unknown_member"
	if why.is_empty():
		why = name_block(s, name, taken, id)
	if why.is_empty() and m.name == name:
		why = "unchanged"
	if not why.is_empty():
		return [_reject(why)]
	m.name = name
	return [{"type": "renamed", "id": id, "name": name}]


## 등록 지우기(§4.1): 길드 대원만. 낀 장비는 공용 가방으로(모두 들어가야 한다, 아니면 bag_full). 등록 번호는 다시 쓰지 않는다.
## 은퇴(이후)의 자리: 이 함수가 길드를 떠나는 유일한 길이다.
static func remove(s: ExplorationState, id: String) -> Array[Dictionary]:
	var why := _town_block(s)
	var m := find(s, id) if why.is_empty() else null
	if why.is_empty() and m == null:
		why = "unknown_member"
	if why.is_empty() and s.party.members.has(m):
		why = "in_party"
	var gear: Array[String] = []
	if why.is_empty():
		var count := {}
		for e in m.equip:
			if not e.is_empty():
				gear.append(e)
				count[e] = int(count.get(e, 0)) + 1
		if BagRules.free_slots(s) < gear.size():
			why = "bag_full"
		for e in count:
			if int(s.gear_bag.get(e, 0)) + int(count[e]) > BattleLimits.BAG_MAX:
				why = "bag_full"
	if not why.is_empty():
		return [_reject(why)]
	for e in gear:
		s.gear_bag[e] = int(s.gear_bag.get(e, 0)) + 1
	s.guild.members.erase(m)
	return [{"type": "removed", "id": id, "returned": gear}]


## 편성(§4.1, 마을만): front·back 의 ID 로 파티를 새로 짠다(앞 열 다음 뒷열). 들지 않은 대원은 길드로(명부 차례: 파티 차례, 그다음 길드 차례).
static func form(s: ExplorationState, front: Variant, back: Variant) -> Array[Dictionary]:
	var why := _town_block(s)
	var picked: Array[PartyState.Member] = []
	if why.is_empty():
		why = _lists(s, front, back, picked)
	if why.is_empty() and picked.is_empty():
		why = "party_empty"
	if why.is_empty() and picked.size() > BattleLimits.PARTY_SIZE:
		why = "party_full"
	if why.is_empty() and not picked.any(func(m: PartyState.Member) -> bool: return m.alive()):
		why = "party_down"  # 모두 쓰러진 파티는 전멸 상태와 같아진다(저장 검사: 모두 HP 0 ⇔ wiped)
	if why.is_empty() and _same(s, picked, front):
		why = "unchanged"
	if not why.is_empty():
		return [_reject(why)]
	var rest: Array[PartyState.Member] = []
	for m in roster(s):
		if not picked.has(m):
			rest.append(m)
	_place(s, picked, front.size())
	s.guild.members = rest
	return [{"type": "formed", "front": Array(front).duplicate(), "back": Array(back).duplicate()}]


## 대열 바꾸기(§4.1b, 마을·미궁): 지금 파티 대원만으로 순서·열을 바꾼다. 시간이 가지 않는다(걸음·위험도·FOE·난수 그대로).
## 전투 중(대기 포함)·전멸이면 거부. 물음·창이 열렸을 때는 화면이 막는다.
static func arrange(s: ExplorationState, front: Variant, back: Variant) -> Array[Dictionary]:
	var why := _busy_block(s)
	var picked: Array[PartyState.Member] = []
	if why.is_empty():
		why = _lists(s, front, back, picked)
	if why.is_empty() and (picked.size() != s.party.members.size() or picked.any(func(m: PartyState.Member) -> bool: return not s.party.members.has(m))):
		why = "not_party"
	if why.is_empty() and _same(s, picked, front):
		why = "unchanged"
	if not why.is_empty():
		return [_reject(why)]
	_place(s, picked, front.size())
	return [{"type": "arranged", "front": Array(front).duplicate(), "back": Array(back).duplicate()}]


# ---- 도우미 ----

static func _town_block(s: ExplorationState) -> String:
	var why := _busy_block(s)
	if why.is_empty() and not s.in_town():
		why = "not_town"
	return why


static func _busy_block(s: ExplorationState) -> String:
	if s.wiped:
		return "wiped"
	if s.battle != null or s.encounter.pending:
		return "in_battle"
	return ""


## front·back 이 ID 문자열 배열이고, 명부에 있고, 겹치지 않고, 열마다 ROW_MAX 이하인지. 통과하면 picked 에 차례대로 담는다.
static func _lists(s: ExplorationState, front: Variant, back: Variant, picked: Array[PartyState.Member]) -> String:
	for list in [front, back]:
		if typeof(list) != TYPE_ARRAY:
			return "bad_list"
		for id in list:
			if typeof(id) != TYPE_STRING:
				return "bad_list"
	for list in [front, back]:
		for id in list:
			var m := find(s, id)
			if m == null:
				return "unknown_member"
			if picked.has(m):
				return "duplicate"
			picked.append(m)
	if front.size() > BattleLimits.ROW_MAX or back.size() > BattleLimits.ROW_MAX:
		return "row_full"
	return ""


## 지금 파티와 순서·열이 모두 같은지.
static func _same(s: ExplorationState, picked: Array[PartyState.Member], front: Array) -> bool:
	if picked.size() != s.party.members.size():
		return false
	for i in picked.size():
		if picked[i] != s.party.members[i] or picked[i].row != ("front" if i < front.size() else "back"):
			return false
	return true


static func _place(s: ExplorationState, picked: Array[PartyState.Member], n_front: int) -> void:
	for i in picked.size():
		picked[i].row = "front" if i < n_front else "back"
	s.party.members = picked


static func _reject(reason: String) -> Dictionary:
	return {"type": "rejected", "reason": reason}
