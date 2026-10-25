## 탐색 상태 묶음. 새 게임은 ExplorationRules.new_game, 저장은 SaveCodec.
class_name ExplorationState
extends RefCounted

## 시작 소지금(08 §2, 자체 값).
const START_MONEY := 200

var floor_def: FloorModel
## 정의 묶음(06 §8.2). new_game·저장 읽기가 넣는다.
var defs: GameDefs
## 전투 중 상태. 전투가 없으면 null(06 §8.1). 전투 규칙(BattleRules)만 바꾼다.
var battle: BattleState
## 소재 ID → 수량(1~9999, 0개는 키를 두지 않는다).
var materials := {}
## 장비 가방(07 §5.6): 장착하지 않은 장비 ID → 개수(1~99, 0개는 키를 두지 않는다).
var gear_bag := {}
## 소지금(08 §2): 0~MONEY_MAX. 새 게임과 1·2·3판 이전은 START_MONEY 다.
var money := 0
## 상점 상태(08 §2). 상점 규칙(ShopRules)만 바꾼다.
var shop := ShopState.new()
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
