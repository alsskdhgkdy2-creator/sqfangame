## 탐색 상태 묶음. 새 게임은 ExplorationRules.new_game, 저장은 SaveCodec.
class_name ExplorationState
extends RefCounted

## 시작 소지금(08 §2, 자체 값).
const START_MONEY := 200
## 파티가 있는 곳(M3 A2): 마을(광장·시설은 화면 쪽이고 저장하지 않는다)·미궁.
const TOWN := "town"
const LABYRINTH := "labyrinth"
const LOCATIONS := ["town", "labyrinth"]
## 날(M3 A2): 1일째부터. 여관에 묵을 때만 오른다(A2b). 저장 검사 범위의 끝.
const DAY_MAX := 99999

## 마을이면 층은 첫 층·위치는 그 시작 칸이다(규칙이 지키는 불변식, 저장 검사도 본다). 이어하기는 늘 광장으로 돌아온다.
var location := LABYRINTH
var day := 1

## 지금 층(M3 A1). 넣으면 enter_floor 와 같다(그 층의 기록으로 바뀐다).
var floor_def: FloorModel:
	get:
		return _here.floor_def
	set(f):
		enter_floor(f)
## 들어가 본 층의 기록: 층 ID → FloorState. 지금 층의 기록은 늘 있다.
var floor_states := {}
## 정의 묶음(06 §8.2). new_game·저장 읽기가 넣는다.
var defs: GameDefs
## 전투 중 상태. 전투가 없으면 null(06 §8.1). 전투 규칙(BattleRules)만 바꾼다.
var battle: BattleState
## 소재 ID → 수량(1~9999, 0개는 키를 두지 않는다).
var materials := {}
## 장비 가방(07 §5.6): 장착하지 않은 장비 ID → 개수(1~99, 0개는 키를 두지 않는다).
var gear_bag := {}
## 귀중품(열쇠, M3 A3): 열쇠 ID → true. 쓰지 않고 남는다(문을 열어도 그대로). 상자에서만 얻는다.
var key_items := {}
## 소지금(08 §2): 0~MONEY_MAX. 새 게임과 1·2·3판 이전은 START_MONEY 다.
var money := 0
## 상점 상태(08 §2). 상점 규칙(ShopRules)만 바꾼다.
var shop := ShopState.new()
## 아래 셋은 지금 층 기록(FloorState)의 것이다. 규칙·지도·시야는 지금 층만 보고 다른 층 기록은 건드리지 않는다.
var world: WorldState:
	get:
		return _here.world
	set(v):
		_here.world = v
var knowledge: ExplorationKnowledge:
	get:
		return _here.knowledge
	set(v):
		_here.knowledge = v
var annotation: MapAnnotation:
	get:
		return _here.annotation
	set(v):
		_here.annotation = v
var party := PartyState.new()
var encounter := EncounterState.new()
var rng := GameRng.new()
var steps := 0
var wiped := false
## 저장할 때마다 1씩 오른다(state 밖이라 해시에 들어가지 않는다).
var generation := 0

## 층이 정해지기 전의 빈 기록(새 상태 객체).
var _here := FloorState.new()


func in_town() -> bool:
	return location == TOWN


## 층 f 로 들어간다: 처음이면 그 층의 기록을 만들고, 지금 층 기록으로 둔다(위치·방향은 부르는 쪽이 정한다).
func enter_floor(f: FloorModel) -> FloorState:
	if not floor_states.has(f.id):
		floor_states[f.id] = FloorState.new(f)
	_here = floor_states[f.id]
	return _here
