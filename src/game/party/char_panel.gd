## 캠프 장비·소지품의 오른쪽 인물 판(M2.7 R2-c, 원작 상점 화면 jp_guide3_img1~3 의 인물 판): 화면 오른쪽에 붙는다(폭 W, 전체 높이).
## 위 줄(MemberHeader: 이름 칸 + 앞·다음 대원 단추 = 원작 L·R, Lv 띠, HP·TP 띠, 대원 띠 한 벌 색), 직업 문패, 큰 초상 자리표시(M3 전까지),
## 능력치 묶음(EquipTotals: 힘~행운 열 + 공격·방어 2×2), 아래 장비 넷 줄(읽기만, mark 칸은 노랑 테두리).
## 장식은 그리기만 하고, 누르는 것은 위 줄의 대원 단추 둘뿐이다(step 신호).
class_name CharPanel
extends Control

signal step(dir: int)

const W := 515.0
const CLASS_PLATE := Rect2(8, 126, 364, 40)
const TOTALS_Y := 180.0
const EQUIP_Y := 574.0
const EQUIP_PITCH := 34.0
const EQUIP_H := 30.0
const EQUIP_W := 340.0
const EQUIP_NAME_W := 88.0
const PORTRAIT_LEFT := 190.0

var top: MemberHeader
var totals: EquipTotals
## 마지막으로 그린 값(시험·디버그): name, class, class_color, equip[[칸 이름, 장비 이름, 비었는지]], mark, dim_equip.
var drawn := {}


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	focus_mode = FOCUS_NONE


func build(prefix: String) -> void:
	PartyMenu.place(self, Vector2(1, 0), Vector2(1, 1), Vector4(-W, 0, 0, 0))
	top = MemberHeader.new()
	top.name = prefix + "Top"
	add_child(top)
	top.build(prefix)
	top.step.connect(func(d: int) -> void: step.emit(d))
	totals = EquipTotals.new()
	totals.name = prefix + "Totals"
	add_child(totals)
	PartyMenu.place(totals, Vector2.ZERO, Vector2.ZERO, Vector4(8, TOTALS_Y, 8 + EquipTotals.needed_size().x, TOTALS_Y + EquipTotals.needed_size().y))
	# 판 바탕·초상은 위 줄·능력치보다 먼저 그린다(트리 순서): _draw 가 그 몫이고, 위 줄·묶음은 자식이라 그 위에 그려진다.


func prev_button() -> PartyButton:
	return top.prev_button


func next_button() -> PartyButton:
	return top.next_button


## 대원 i 의 값을 판에 놓는다. after: 견줄 GrowthRules.profile(없으면 null). mark: 노랑 테두리 장비 칸(-1 없음).
## dim_equip: 장비 줄을 흐리게(상점에서 판의 대원이 커서 줄 물건을 못 낄 때, 원작 B). 캠프·상점이 함께 쓴다(화면 노드를 모른다).
func show_member(state: ExplorationState, texts: TextDb, i: int, after: Variant, mark: int, dim_equip: bool = false) -> void:
	var defs := state.defs
	var m := state.party.members[i]
	top.name_text = PartyNames.member_name(state, texts, i)
	top.level_text = texts.t("party.level", {"level": m.level})
	top.hp_text = texts.t("party.hp", {"hp": m.hp, "max": m.max_hp})
	top.tp_text = texts.t("party.tp", {"tp": m.tp, "max": m.max_tp})
	top.queue_redraw()
	totals.show_totals(texts, GrowthRules.profile(defs, i, m), after)
	var equip := []
	for slot in BattleLimits.EQUIP_SLOTS:
		var id: String = m.equip[slot]
		equip.append([PartyNames.slot_name(texts, slot), texts.t("party.slot.empty") if id.is_empty() else PartyNames.item_name(state, texts, id),
			id.is_empty()])
	drawn = {"name": top.name_text, "class": texts.t(defs.party.class_ids[i]),
		"class_color": BattleCard.CLASS_COLORS.get(defs.party.class_ids[i], Color(0.7, 0.7, 0.7)), "equip": equip, "mark": mark,
		"dim_equip": dim_equip}
	queue_redraw()


func class_rect() -> Rect2:
	return CLASS_PLATE


func equip_rect(slot: int) -> Rect2:
	return Rect2(8, EQUIP_Y + slot * EQUIP_PITCH, EQUIP_W, EQUIP_H)


func portrait_rect() -> Rect2:
	return Rect2(PORTRAIT_LEFT, MemberHeader.H, size.x - PORTRAIT_LEFT - 8.0, size.y - MemberHeader.H)


func totals_rect() -> Rect2:
	return Rect2(totals.position, totals.size)


func _txt(pos: Vector2, s: String, fs: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(get_theme_default_font(), pos, s, align as HorizontalAlignment, w, fs, col)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([UiTheme.SHOP_PANEL_TOP, UiTheme.SHOP_PANEL_TOP, UiTheme.SHOP_PANEL_BOTTOM, UiTheme.SHOP_PANEL_BOTTOM]))
	var g := 24.0
	var x := g
	while x < r.size.x:
		draw_line(Vector2(x, MemberHeader.H), Vector2(x, r.size.y), UiTheme.SHOP_PANEL_GRID, 1.0)
		x += g
	var y := MemberHeader.H + g
	while y < r.size.y:
		draw_line(Vector2(0, y), Vector2(r.size.x, y), UiTheme.SHOP_PANEL_GRID, 1.0)
		y += g
	draw_line(Vector2(1, 0), Vector2(1, r.size.y), UiTheme.SHOP_WIN_EDGE, 2.0)
	if drawn.is_empty():
		return
	MemberPortrait.draw_silhouette(self, portrait_rect(), drawn["class_color"], str(drawn["name"]).left(1), 200)
	var cp := CLASS_PLATE
	UiTheme.fill_round(self, cp, UiTheme.ST_CLASS_PLATE, int(cp.size.y / 2.0), UiTheme.ST_CLASS_EDGE, 2)
	_txt(Vector2(cp.position.x, cp.get_center().y + 22 * 0.36), drawn["class"], 22, UiTheme.TEXT, cp.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var equip: Array = drawn["equip"]
	for slot in equip.size():
		var er := equip_rect(slot)
		draw_rect(er, UiTheme.ST_EQUIP_ROW)
		draw_rect(Rect2(er.position, Vector2(EQUIP_NAME_W, er.size.y)), UiTheme.ST_ROW_NAME)
		var ty := er.get_center().y + 16 * 0.36
		_txt(Vector2(er.position.x + 8, ty), equip[slot][0], 14, UiTheme.SUB_TEXT, EQUIP_NAME_W - 12)
		var dim: bool = equip[slot][2] or drawn.get("dim_equip", false)
		_txt(Vector2(er.position.x + EQUIP_NAME_W + 10, ty), equip[slot][1], 16, UiTheme.SUB_TEXT if dim else UiTheme.TEXT,
			er.size.x - EQUIP_NAME_W - 16)
		if slot == int(drawn["mark"]):
			UiTheme.draw_outline(self, er.grow(2.0), UiTheme.BTN_PICK, UiTheme.BTN_PICK_W, 0.0)
