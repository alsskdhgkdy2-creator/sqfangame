## 소모품 규칙(M3 A4): 캠프에서 쓰기(마을·미궁), 귀환 비콘, 버리기. 전투의 「아이템」은 BattleRules 가 한다.
## 노드·시간·엔진에 기대지 않고 난수·걸음을 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(ShopRules 와 같은 방식).
## 거부하면 {"type": "rejected", "reason": …} 하나만 내고 상태를 바꾸지 않는다. 받아들이면 부른 화면이 자동 저장한다.
##
## 이벤트:
##   {"type": "used", "item", "member"(귀환은 -1), "left"}   쓴 뒤 남은 수
##   {"type": "healed", "member", "amount", "hp"} · {"type": "tp_restored", "member", "amount", "tp"} · {"type": "revived", "member", "hp"}
##   {"type": "returned"}   귀환 비콘: 마을(첫 층 시작 칸)로 옮겼다
##   {"type": "discarded", "item", "qty", "left"}
class_name ItemRules
extends RefCounted

const EVENT_TYPES := ["rejected", "used", "healed", "tp_restored", "revived", "returned", "discarded"]


# ---- 읽기 ----

## 귀환 비콘을 지금 쓸 수 없는 이유: town(마을에 있다) · sealed(그 칸이 귀환을 막는다, A9 보스 방 갈고리 FloorModel.no_return) · "".
static func return_block(s: ExplorationState) -> String:
	if s.in_town():
		return "town"
	if s.floor_def != null and s.floor_def.no_return.has(s.party.at):
		return "sealed"
	return ""


## 캠프에서 item 을 대원 member 에게(귀환은 member 를 보지 않는다) 지금 쓸 수 없는 이유. 쓸 수 있으면 "".
## 차례: not_now → unknown_item → not_owned → battle_only → (귀환) town·sealed → (대상) bad_member → down·not_down → hp_full·tp_full.
static func use_block(s: ExplorationState, item: String, member: int) -> String:
	if _busy(s):
		return "not_now"
	var c := s.defs.battle.consumable(item) if s.defs != null else null
	if c == null:
		return "unknown_item"
	if int(s.consumables.get(item, 0)) < 1:
		return "not_owned"
	if not c.in_camp():
		return "battle_only"
	if c.effect == "return":
		return return_block(s)
	if member < 0 or member >= s.party.members.size():
		return "bad_member"
	var m := s.party.members[member]
	if c.effect == "revive":
		return "not_down" if m.alive() else ""
	if not m.alive():
		return "down"
	if c.effect == "heal" and m.hp >= m.max_hp:
		return "hp_full"
	if c.effect == "tp" and m.tp >= m.max_tp:
		return "tp_full"
	return ""


# ---- 쓰기 ----

## 캠프에서 쓴다. 받아들이면 하나 줄이고(0 이면 키를 지운다) used 와 효과 이벤트를 낸다.
## 회복은 모자란 만큼만(HP·TP), 소생은 최대 HP 의 hp_permille(최소 1). 밖에는 상태 이상이 없어 소생은 HP 만 바꾼다(06 §3.17).
## 귀환: 마을로(층은 첫 층, 시작 칸·시작 방향). 위험도·한계값·걸음·날·난수와 모든 층 기록(지도·방문·세계)은 그대로다(마을 문과 같다, 05 §15).
static func use(s: ExplorationState, item: String, member: int) -> Array[Dictionary]:
	var why := use_block(s, item, member)
	if not why.is_empty():
		return [_reject(why)]
	var c := s.defs.battle.consumable(item)
	var left := _take(s.consumables, item, 1)
	var events: Array[Dictionary] = [{"type": "used", "item": item, "member": member if c.effect != "return" else -1, "left": left}]
	if c.effect == "return":
		var first := s.defs.first_floor()
		s.location = ExplorationState.TOWN
		s.enter_floor(first)
		s.party.at = first.start_at
		s.party.facing = first.start_facing
		events.append({"type": "returned"})
		return events
	var m := s.party.members[member]
	match c.effect:
		"heal":
			var amount := mini(c.amount, m.max_hp - m.hp)
			m.hp += amount
			events.append({"type": "healed", "member": member, "amount": amount, "hp": m.hp})
		"tp":
			var amount := mini(c.amount, m.max_tp - m.tp)
			m.tp += amount
			events.append({"type": "tp_restored", "member": member, "amount": amount, "tp": m.tp})
		"revive":
			m.hp = clampi(BattleCalc.mul(m.max_hp, c.hp_permille), 1, m.max_hp)
			events.append({"type": "revived", "member": member, "hp": m.hp})
	return events


# ---- 버리기 ----

## 가방 물건(소모품·끼지 않은 장비·소재)을 qty 개 버린다(원작 捨てる). 귀중품은 버리지 않는다.
## 차례: not_now → key_item → unknown_item → bad_amount(1~9,999 정수, 옛 저장의 큰 수도 버릴 수 있게 판매 수량 범위) → not_owned.
static func discard(s: ExplorationState, item: Variant, qty: Variant) -> Array[Dictionary]:
	if _busy(s):
		return [_reject("not_now")]
	if typeof(item) != TYPE_STRING:
		return [_reject("unknown_item")]
	if s.defs != null and s.defs.battle.key_items.has(item):
		return [_reject("key_item")]
	if not BagRules.known(s, item):
		return [_reject("unknown_item")]
	var n: Variant = SaveCodec.to_int(qty) if typeof(qty) != TYPE_BOOL else null
	if not BattleLimits.in_range("sell_qty", n):
		return [_reject("bad_amount")]
	var bag: Dictionary = BagRules.store(s, item)
	if n > int(bag.get(item, 0)):
		return [_reject("not_owned")]
	var left := _take(bag, item, n)
	return [{"type": "discarded", "item": item, "qty": n, "left": left}]


# ---- 공통 ----

## 캠프 조작을 막는 때: 전투 중·전투 대기·전멸(GrowthRules·ShopRules 와 같은 때).
static func _busy(s: ExplorationState) -> bool:
	return s.battle != null or s.encounter.pending or s.wiped


## bag[item] 에서 n 을 빼고 남은 수(0 이면 키를 지운다).
static func _take(bag: Dictionary, item: String, n: int) -> int:
	var left: int = int(bag.get(item, 0)) - n
	if left > 0:
		bag[item] = left
	else:
		bag.erase(item)
	return maxi(left, 0)


static func _reject(reason: String) -> Dictionary:
	return {"type": "rejected", "reason": reason}
