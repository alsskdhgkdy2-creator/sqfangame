## 상점 규칙 함수(08 §3): 진열·모자란 소재·값 읽기, 사기, 팔기.
## 노드·시간·엔진에 기대지 않고 난수·걸음을 쓰지 않는다. 상태를 바꾸는 함수는 이벤트 사전 목록을 돌려준다(GrowthRules 와 같은 방식).
## 거부하면 {"type": "rejected", "reason": …} 하나만 내고 상태를 바꾸지 않는다. 받아들이면 부른 화면이 자동 저장한다(07 §8.5).
##
## 이벤트:
##   {"type": "bought", "item", "qty", "cost", "money"}
##   {"type": "sold", "lines": [{"item", "qty", "gain"}](받은 줄 차례), "gain", "money"}
##   {"type": "unlocked", "shop", "items"}   items 는 이 판매로 처음 풀린 줄의 장비 ID(진열 차례)
class_name ShopRules
extends RefCounted

const EVENT_TYPES := ["rejected", "bought", "sold", "unlocked"]
const SELL_LINE_KEYS := ["item", "qty"]


# ---- 읽기 (08 §3.1) ----

## 풀린 줄만 진열 차례로: {item, price, limited, stock(한정이면 남은 수, 아니면 −1), new(아직 사지 않음), affordable(소지금 ≥ 값)}.
## 모르는 상점이면 빈 배열. 부를 때마다 새 사전.
static func catalog(defs: GameDefs, state: ExplorationState, shop_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sh := defs.battle.shop(shop_id)
	if sh == null:
		return out
	for line in sh.stock:
		if not unlocked(state.shop, line):
			continue
		var item: String = line["item"]
		var price := buy_price(defs, item)
		out.append({
			"item": item, "price": price, "limited": line["limited"],
			"stock": stock_of(state.shop, line) if line["limited"] else -1,
			"new": not state.shop.bought.has(item), "affordable": state.money >= price,
		})
	return out


## 한정 줄을 하나 더 사려면 모자란 소재 → 수(unlock 차례). 살 수 있거나·한정이 아니거나·모르는 물건이면 빈 사전.
## 잠긴 한정 줄도 pool 로 센다(진열에 보이지 않으므로 화면은 부르지 않는다).
static func shortage(defs: GameDefs, state: ExplorationState, shop_id: String, item_id: String) -> Dictionary:
	var sh := defs.battle.shop(shop_id)
	if sh == null:
		return {}
	var line := sh.line(item_id)
	if line.is_empty() or not line["limited"] or stock_of(state.shop, line) >= 1:
		return {}
	var out := {}
	for m in line["unlock"]:
		var lack: int = line["unlock"][m] - state.shop.pool.get(m, 0)
		if lack > 0:
			out[m] = lack
	return out


## 장비·소모품(M3 A4)의 구매값. 모르면 0.
static func buy_price(defs: GameDefs, item_id: String) -> int:
	var e := defs.battle.equip(item_id)
	if e != null:
		return e.price
	var c := defs.battle.consumable(item_id)
	return c.price if c != null else 0


## 판매값: 장비·소모품 = price ÷ 2(버림, 최소 1), 소재 = sell, 모르면 0.
static func sell_price(defs: GameDefs, item_id: String) -> int:
	var e := defs.battle.equip(item_id)
	if e != null:
		return maxi(1, e.price / 2)
	var c := defs.battle.consumable(item_id)
	if c != null:
		return maxi(1, c.price / 2)
	return defs.battle.material_sell.get(item_id, 0)


## 진열 줄이 풀렸는지(08 §2): unlock 의 소재가 모두 sold 에 그 수 이상. 처음부터 파는 줄은 늘 참.
static func unlocked(shop: ShopState, line: Dictionary) -> bool:
	for m in line["unlock"]:
		if shop.sold.get(m, 0) < line["unlock"][m]:
			return false
	return true


## 한정 줄의 남은 수(08 §2): 소재마다 pool ÷ unlock(버림) 가운데 가장 작은 값. 한정 줄은 unlock 이 비지 않는다.
static func stock_of(shop: ShopState, line: Dictionary) -> int:
	var n := -1
	for m in line["unlock"]:
		var k: int = shop.pool.get(m, 0) / line["unlock"][m]
		n = k if n < 0 else mini(n, k)
	return maxi(n, 0)


# ---- 사기 (08 §3.2) ----

## 판정 순서: not_now → unknown_shop → unknown_item(그 상점 진열에 없음) → locked → bad_amount(1~99 정수) → sold_out → no_money → bag_full.
## bag_full: 공용 가방 60칸에 qty 가 다 들어가지 않는다(D31, BagRules.fit). 장비는 가방 장비, 소모품(M3 A4)은 소모품 묶음에 넣는다.
static func buy(state: ExplorationState, shop_id: String, item_id: String, qty: Variant) -> Array[Dictionary]:
	if _busy(state):
		return [_reject("not_now")]
	var defs := state.defs
	var sh := defs.battle.shop(shop_id)
	if sh == null:
		return [_reject("unknown_shop")]
	var line := sh.line(item_id)
	if line.is_empty():
		return [_reject("unknown_item")]
	if not unlocked(state.shop, line):
		return [_reject("locked")]
	var n: Variant = _amount(qty)
	if not BattleLimits.in_range("buy_qty", n):
		return [_reject("bad_amount")]
	if line["limited"] and stock_of(state.shop, line) < n:
		return [_reject("sold_out")]
	var cost: int = buy_price(defs, item_id) * n
	if state.money < cost:
		return [_reject("no_money")]
	if BagRules.fit(state, item_id, n) < n:
		return [_reject("bag_full")]
	state.money -= cost
	BagRules.add(state, item_id, n)
	if line["limited"]:
		for m in line["unlock"]:
			var left: int = state.shop.pool[m] - line["unlock"][m] * n
			if left > 0:
				state.shop.pool[m] = left
			else:
				state.shop.pool.erase(m)
	state.shop.bought[item_id] = true
	return [{"type": "bought", "item": item_id, "qty": n, "cost": cost, "money": state.money}]


# ---- 팔기 (08 §3.3) ----

## lines = [{item, qty}]. 판정 순서: not_now → unknown_shop → bad_lines → 줄마다 unknown_item·bad_amount(1~9,999 정수)·not_owned → money_full.
## 소모품(M3 A4)도 판다(판매값 price ÷ 2). 통과하면 한 묶음으로 처리한다. 소재만 sold·pool 에 더하고(SOLD_MAX 에서 멈춤) 이 판매로 처음 풀린 줄이 있으면 unlocked 를 잇는다.
static func sell(state: ExplorationState, shop_id: String, lines: Variant) -> Array[Dictionary]:
	if _busy(state):
		return [_reject("not_now")]
	var defs := state.defs
	var sh := defs.battle.shop(shop_id)
	if sh == null:
		return [_reject("unknown_shop")]
	if typeof(lines) != TYPE_ARRAY or lines.is_empty():
		return [_reject("bad_lines")]
	var seen := {}
	for x in lines:
		if typeof(x) != TYPE_DICTIONARY or x.size() != SELL_LINE_KEYS.size() or not SELL_LINE_KEYS.all(func(k: String) -> bool: return x.has(k)):
			return [_reject("bad_lines")]
		var key := var_to_str(x["item"])  # 자료형까지 같은 값만 같은 물건으로 센다
		if seen.has(key):
			return [_reject("bad_lines")]
		seen[key] = true
	var rows := []
	var gain := 0
	for x in lines:
		var item: Variant = x["item"]
		var known := typeof(item) == TYPE_STRING and BagRules.known(state, item)
		if not known:
			return [_reject("unknown_item")]
		var n: Variant = _amount(x["qty"])
		if not BattleLimits.in_range("sell_qty", n):
			return [_reject("bad_amount")]
		var bag: Dictionary = BagRules.store(state, item)
		if n > bag.get(item, 0):
			return [_reject("not_owned")]
		var g: int = sell_price(defs, item) * n
		rows.append({"item": item, "qty": n, "gain": g})
		gain += g
	if state.money + gain > BattleLimits.MONEY_MAX:
		return [_reject("money_full")]
	var shop := state.shop
	var was := {}
	for line in sh.stock:
		if unlocked(shop, line):
			was[line["item"]] = true
	for r in rows:
		var item: String = r["item"]
		var material: bool = defs.battle.materials.has(item)
		var bag: Dictionary = BagRules.store(state, item)
		bag[item] -= r["qty"]
		if bag[item] == 0:
			bag.erase(item)
		if material:
			shop.sold[item] = mini(BattleLimits.SOLD_MAX, shop.sold.get(item, 0) + r["qty"])
			shop.pool[item] = mini(BattleLimits.SOLD_MAX, shop.pool.get(item, 0) + r["qty"])
	state.money += gain
	var events: Array[Dictionary] = [{"type": "sold", "lines": rows, "gain": gain, "money": state.money}]
	var fresh := []
	for line in sh.stock:
		if not was.has(line["item"]) and unlocked(shop, line):
			fresh.append(line["item"])
	if not fresh.is_empty():
		events.append({"type": "unlocked", "shop": shop_id, "items": fresh})
	return events


# ---- 공통 ----

## 상점 조작을 막는 때: 전투 중·전투 대기·전멸(GrowthRules 와 같은 때).
static func _busy(state: ExplorationState) -> bool:
	return state.battle != null or state.encounter.pending or state.wiped


## 수량 → 정수(정수와 같은 실수도 받는다). 참·거짓·정수가 아닌 실수·문자열은 null.
static func _amount(v: Variant) -> Variant:
	return SaveCodec.to_int(v) if typeof(v) != TYPE_BOOL else null


static func _reject(reason: String) -> Dictionary:
	return {"type": "rejected", "reason": reason}
