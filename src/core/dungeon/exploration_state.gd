## 탐색 상태 묶음. 새 게임은 ExplorationRules.new_game, 저장은 SaveCodec.
class_name ExplorationState
extends RefCounted

var floor_def: FloorModel
var world := WorldState.new()
var knowledge := ExplorationKnowledge.new()
var annotation := MapAnnotation.new()
var party := PartyState.new()
var encounter := EncounterState.new()
var rng := GameRng.new()
var steps := 0
var wiped := false
## 저장할 때마다 1씩 오른다(state 밖이라 해시에 들어가지 않는다).
var generation := 0
