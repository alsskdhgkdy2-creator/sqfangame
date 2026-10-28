## 모험가 길드 상태(M3 A7 설계 §3.1): 등록했지만 파티에 없는 대원(등록 차례)과 마지막 등록 번호(줄지 않는다, 새 대원 ID 는 r<번호>).
## 파티 대원은 ExplorationState.party.members 에 있다. 등록 명부 = 파티 + 길드. GuildRules 만 바꾼다.
class_name GuildState
extends RefCounted

var members: Array[PartyState.Member] = []
var serial := 0
