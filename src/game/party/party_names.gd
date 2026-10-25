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


## 장비 값 줄(상점 설명 창·캠프 소지품 설명 상자가 같이 쓴다): 공격·방어 값, 능력치 보정, 무기 속성. 모르는 ID 는 "".
static func values_text(state: ExplorationState, texts: TextDb, item: String) -> String:
	var e := state.defs.battle.equip(item)
	if e == null:
		return ""
	var parts: Array[String] = []
	for g in BattleLimits.GEAR:
		if int(e.gear[g]) != 0:
			parts.append(texts.t("party.delta", {"name": texts.t("stat." + g), "value": signed(int(e.gear[g]))}))
	for k in BattleLimits.STATS:
		if e.stats.has(k):
			parts.append(texts.t("party.delta", {"name": texts.t("stat." + k), "value": signed(int(e.stats[k]))}))
	if e.weapon() and not e.element.is_empty():
		parts.append(texts.t("element." + e.element))
	return " · ".join(parts)


## 장비의 받는 배율 보정 줄: 상태 화면 받는 배율 줄과 같은 글(「이름 ±n%」, 두 칸 띄어 잇는다), 갈래(속성·상태 이상·결박) 차례.
## 보정이 없으면 "".
static func received_text(state: ExplorationState, texts: TextDb, item: String) -> String:
	var e := state.defs.battle.equip(item)
	if e == null:
		return ""
	var parts: Array[String] = []
	for pair in [[e.resist, "element."], [e.ailment_vuln, "ailment."], [e.bind_vuln, "bind."]]:
		var table: Dictionary = pair[0]
		for k in table:
			if int(table[k]) != 0:
				parts.append(texts.t("party.mult", {"name": texts.t(str(pair[1]) + str(k)), "pct": signed(int(table[k]) / 10)}))
	return "  ".join(parts)
