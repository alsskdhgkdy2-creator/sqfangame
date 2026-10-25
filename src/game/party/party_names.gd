## 대원·장비 칸·장비 이름 도우미(캠프·상점이 함께 쓴다, 08 §8.5). 화면 노드를 모르고 상태와 글자 표만 받는다.
## 캠프(PartyMenu)와 상점(ShopScreen)이 서로를 가리키지 않게 인물 판(CharPanel)은 이것만 쓴다.
class_name PartyNames
extends RefCounted

## 장비 칸 이름 키(칸 0 무기, 칸 1~3 방어구).
const SLOT_KEYS := ["party.slot.weapon", "party.slot.armor", "party.slot.armor", "party.slot.armor"]


static func member_name(state: ExplorationState, texts: TextDb, i: int) -> String:
	return texts.t(state.defs.party.name_keys[i])


static func slot_name(texts: TextDb, slot: int) -> String:
	return texts.t(SLOT_KEYS[slot], {"n": slot})


static func item_name(state: ExplorationState, texts: TextDb, id: String) -> String:
	var e := state.defs.battle.equip(id)
	return texts.t(e.name_key) if e != null else texts.t(id)


## 부호 붙은 수(글꼴 부분 집합에 U+2212 가 없어 ASCII 「-」를 쓴다).
static func signed(v: int) -> String:
	return ("+%d" % v) if v > 0 else str(v)
