## 공용 가방(D31, M3 A4): 소모품·가방 장비(끼지 않은 것)·소재가 한 개에 한 칸씩 60칸을 같이 쓴다. 귀중품·낀 장비는 세지 않는다.
## 가방에 물건이 들어오는 길(전투 드롭·보물상자·상점 사기·장비 빼기·임시 보급, A5 채집)은 모두 여기서 「n 개 가운데 몇 개가 들어가나」(fit)를 묻는다.
## 종류 상한(소모품·장비 99, 소재 9999)은 저장 검사 범위로 남고 fit 의 위 끝으로도 쓴다(60칸 안에서는 닿지 않는다. 옛 저장만 넘을 수 있다).
## 옛 저장(1~7판·옮긴 저장)이 60을 넘으면 지우거나 거부하지 않는다: 그대로 두고 free 가 0 이라 새로 얻는 길이 모두 막힌다(설계 §3.3).
## 노드·난수에 기대지 않는다.
class_name BagRules
extends RefCounted

const SLOTS := 60


## 가방에 든 물건 수(소모품 + 가방 장비 + 소재, 개수 합).
static func used(s: ExplorationState) -> int:
	var n := 0
	for d in [s.consumables, s.gear_bag, s.materials]:
		for k in d:
			n += int(d[k])
	return n


## 빈 칸 수. 넘쳤으면 0(음수가 아니다).
static func free_slots(s: ExplorationState) -> int:
	return maxi(0, SLOTS - used(s))


## 물건 ID 가 드는 곳(use. → 소모품, equip. → 가방 장비, item. → 소재). 다른 ID 면 null.
static func store(s: ExplorationState, item: String) -> Variant:
	if item.begins_with("use."):
		return s.consumables
	if item.begins_with("equip."):
		return s.gear_bag
	if item.begins_with("item."):
		return s.materials
	return null


## 종류 상한(저장 검사 범위와 같다). 모르는 ID 면 0.
static func kind_cap(item: String) -> int:
	if item.begins_with("use."):
		return BattleLimits.CONSUMABLE_MAX
	if item.begins_with("equip."):
		return BattleLimits.BAG_MAX
	if item.begins_with("item."):
		return BattleLimits.MATERIAL_MAX
	return 0


## 지금 item 을 n 개 넣으려 할 때 들어가는 수(0~n): 빈 칸과 종류 상한 가운데 작은 쪽. 귀중품(key.)은 세지 않으므로 n,
## 정의에 없는 ID 는 0. n 이 0 이하면 0.
static func fit(s: ExplorationState, item: String, n: int) -> int:
	if n <= 0:
		return 0
	if item.begins_with("key."):
		return n if s.defs != null and s.defs.battle.key_items.has(item) else 0
	if not known(s, item):
		return 0
	var d: Dictionary = store(s, item)
	return clampi(mini(free_slots(s), kind_cap(item) - int(d.get(item, 0))), 0, n)


## fit 만큼 넣고 넣은 수를 돌려준다(드롭, A5 채집 입구). 귀중품은 여기로 넣지 않는다(상자 규칙이 따로 넣는다).
static func add(s: ExplorationState, item: String, n: int) -> int:
	if item.begins_with("key."):
		return 0
	var k := fit(s, item, n)
	if k > 0:
		var d: Dictionary = store(s, item)
		d[item] = int(d.get(item, 0)) + k
	return k


## 정의에 있는 가방 물건(소모품·장비·소재)인지.
static func known(s: ExplorationState, item: String) -> bool:
	if s.defs == null:
		return false
	var b := s.defs.battle
	return b.consumables.has(item) or b.equipment.has(item) or b.materials.has(item)
