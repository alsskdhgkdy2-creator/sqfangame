## 의뢰 상태(M3 A8 설계 §3.1): 받거나 보고한 의뢰만 기록을 가진다. 잠김·받을 수 있음·목표 달성은 저장하지 않고 읽을 때 정한다(QuestRules).
## 한 번도 받지 않았거나, 첫 보고 전에 포기한 의뢰는 기록이 없다. QuestRules 만 바꾼다.
class_name QuestState
extends RefCounted

const ACCEPTED := "accepted"
const REPORTED := "reported"
const STATUSES := ["accepted", "reported"]
## 보고 수 상한(M3 A8a 검토): 규칙은 여기서 멈추고(보고는 그대로 받고 보수도 준다) 저장 검사도 같은 상한을 쓴다.
const REPORTS_MAX := 9999


## 의뢰 하나의 기록. progress 는 kill·foe 의 센 수·reach 의 0/1(deliver 와 reported 는 늘 0), reports 는 보고한 횟수,
## day 는 마지막으로 보고한 날(보고한 적이 없으면 0).
class Entry:
	extends RefCounted
	var status := ACCEPTED
	var progress := 0
	var reports := 0
	var day := 0

	func copy() -> Entry:
		var e := Entry.new()
		e.status = status
		e.progress = progress
		e.reports = reports
		e.day = day
		return e


## 의뢰 ID → Entry.
var entries := {}


func entry(id: String) -> Entry:
	return entries.get(id)


func reports_of(id: String) -> int:
	var e: Entry = entries.get(id)
	return e.reports if e != null else 0


func is_accepted(id: String) -> bool:
	var e: Entry = entries.get(id)
	return e != null and e.status == ACCEPTED
