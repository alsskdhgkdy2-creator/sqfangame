## 가방에서 목록 줄을 뽑는 곳 하나(D28): 캠프 소지품·장비 후보, 마을 상점 판매(D28-b)가 같이 쓴다. 상점 구매는 가방이 아니라
## 진열(ShopRules.catalog)이라 여기에 없다. 이름·값 글은 화면이 붙인다(여기는 ID·개수·종류·아이콘과 차례·거르기만).
class_name BagRows
extends RefCounted


## 가방 줄 [{item, count, kind, icon}, …]. kinds 차례로: "gear" = 장비(자료 차례, gear_bag 1 이상),
## "material" = 소재(1 이상). mat_order: "id" = 소재 ID 차례(캠프 소지품), "data" = 정의 자료 차례(마을 상점 판매).
static func bag(state: ExplorationState, kinds: Array = ["gear", "material"], mat_order := "id") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var defs := state.defs
	for kind in kinds:
		match str(kind):
			"gear":
				for id in defs.battle.equipment_ids:
					var n := int(state.gear_bag.get(id, 0))
					if n >= 1:
						out.append({"item": id, "count": n, "kind": defs.battle.equip(id).kind, "icon": SheetParts.kind_icon(defs, id)})
			"material":
				var ids: Array = []
				if mat_order == "data":
					ids = defs.battle.materials.keys()
				else:
					ids = state.materials.keys()
					ids.sort()
				for id in ids:
					var n := int(state.materials.get(id, 0))
					if n >= 1:
						out.append({"item": str(id), "count": n, "kind": "material", "icon": str(ShopTabs.ICONS["material"])})
	return out


## 대원 i 의 칸 slot 에 낄 후보(원작 차례): 「E」(지금 낀 것, 막힘 없음) → 그 칸 종류의 가방 장비 가운데 낄 수 있는 것 →
## 못 끼는 것(이유 = GrowthRules.equip_block) → 「빼기」(""). 칸 종류가 다른 장비(칸 0 에 무기 아닌 것·칸 1~3 에 무기)는 넣지 않는다.
## {items: Array[String], block: Array[String](""= 고를 수 있음), equipped: 「E」 줄 번호(없으면 -1)}.
static func for_slot(state: ExplorationState, i: int, slot: int) -> Dictionary:
	var defs := state.defs
	var m: PartyState.Member = state.party.members[i]
	var bag_now := state.gear_bag
	var items: Array[String] = []
	var block: Array[String] = []
	var equipped := -1
	var cur: String = m.equip[slot]
	if not cur.is_empty():
		equipped = 0
		items.append(cur)
		block.append("")
	var dim_items: Array[String] = []
	var dim_why: Array[String] = []
	for line in bag(state, ["gear"]):
		var id: String = line["item"]
		if GrowthRules.slot_block(defs.battle, defs.class_of(i), m.equip, slot, id) == "slot_kind":
			continue
		var why := GrowthRules.equip_block(defs, i, m, bag_now, slot, id)
		if why.is_empty():
			items.append(id)
			block.append("")
		else:
			dim_items.append(id)
			dim_why.append(why)
	items.append_array(dim_items)
	block.append_array(dim_why)
	items.append("")
	block.append(GrowthRules.equip_block(defs, i, m, bag_now, slot, ""))
	return {"items": items, "block": block, "equipped": equipped}
