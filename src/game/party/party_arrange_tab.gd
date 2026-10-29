## 캠프 「대열」(M3 A7c, 설계 §4.1b, 원작 캠프 PARTY 「전열·후열 바꾸기」, research 07 §2.5): 지금 파티의 순서·열만 바꾼다.
## 길드 「편성과 순서」와 같은 편성 판(FormBoard, D28)을 쓰고 등록부 목록은 없다(편성 = 넣고 빼기는 길드에서만).
## 칸 하나를 고르고(고른 칸 = 밝은 시안) 다른 칸을 고르면 두 칸을 바꾼다(빈칸이면 그 열 끝으로 옮긴다). 「결정」 = 탐색 화면 입구
## (DungeonScreen.arrange_party: 창·연출 중이면 busy, 규칙 GuildRules.arrange, 받아들이면 자동 저장). 취소 = 고른 칸을 놓고, 없으면 캠프 뿌리로
## (초안은 버린다). 시간은 들지 않는다.
class_name PartyArrangeTab
extends Control

## 편성 판 자리(왼쪽 위 앵커, 1280×720 기준): 길드 편성 판과 같은 x, 알림 줄 아래.
const BOARD_AT := Vector2(420, 112)

var menu: PartyMenu
var board: FormBoard


func setup(m: PartyMenu) -> void:
	menu = m
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	board = FormBoard.new()
	board.name = "ArrangeBoard"
	add_child(board)
	board.setup(m.texts)
	board.route = func(kind: String, arg: Variant) -> void: menu.handle(kind, arg)
	PartyMenu.place(board, Vector2.ZERO, Vector2.ZERO, Vector4(BOARD_AT.x, BOARD_AT.y, BOARD_AT.x + FormBoard.SIZE.x, BOARD_AT.y + FormBoard.SIZE.y))


## 메뉴를 열 때·뿌리에서 들어올 때: 지금 파티로 초안을 다시 만든다.
func reset() -> void:
	if menu != null and menu.state != null:
		load_party()
	board.cursor = 0


func member_changed() -> void:
	reset()


## 캠프 문맥에 더하는 값: 고른 칸과 판 커서(커서가 바뀌면 누르고 있던 키패드 「선택」을 버린다).
## 이 탭의 고름 값(PressGuard, M3 A7d): 캠프 주인 값에 들어간다. 바뀌면 누르고 있던 단추는 뗄 때 일하지 않는다.
func key_part() -> Array:
	return [board.held, board.cursor]


func place(_s: Vector2) -> void:
	pass


## 지금 파티(칸 순)로 초안을 채운다.
func load_party() -> void:
	var f: Array[String] = []
	var b: Array[String] = []
	for m in menu.state.party.members:
		(f if m.row == "front" else b).append(m.id)
	board.load_draft(f, b)
	board.info = member_info(menu.state, menu.texts)


## 대원 ID → 판 글(이름·HP·TP·직업색·주무기 아이콘). 파티·길드 모두.
static func member_info(s: ExplorationState, texts: TextDb) -> Dictionary:
	var out := {}
	for m in GuildRules.roster(s):
		out[m.id] = {"name": PartyNames.display_name(texts, m), "hp": m.hp, "max_hp": m.max_hp, "tp": m.tp, "max_tp": m.max_tp,
			"class": m.class_id, "color": BattleCard.CLASS_COLORS.get(m.class_id, Color.WHITE), "icon": weapon_icon(s, m.class_id)}
	return out


## 직업 주무기 종류 아이콘(목록 줄 아이콘 칸, 상점 줄과 같은 VectorIcons kind_*). 길드 등록부·직업 목록도 쓴다.
static func weapon_icon(s: ExplorationState, cid: String) -> String:
	var c: BattleDb.ClassDef = s.defs.battle.classes.get(cid) if s != null else null
	if c == null:
		return ""
	for k in c.equip_kinds:
		if BattleLimits.WEAPON_KINDS.has(k):
			return "kind_" + k
	return ""


## 입력: slot(칸)·cursor(±1)·confirm·decide·unhold. 칸 고르기: 고른 칸이 없으면 그 칸을 고르고(빈칸은 고르지 않는다),
## 있으면 두 칸을 바꾼다(같은 칸이면 놓는다).
func dispatch(kind: String, arg: Variant) -> bool:
	match kind:
		"slot":
			var i := int(arg) if arg != null else -1
			if i < 0 or i >= FormBoard.SLOTS:
				return false
			board.cursor = i
			return _pick(i)
		"cursor":
			board.cursor = wrapi(board.cursor + (int(arg) if arg != null else 1), 0, FormBoard.SLOTS + 1)
			return true
		"confirm":
			if board.cursor == FormBoard.DECIDE_AT:
				return _decide()
			return _pick(board.cursor)
		"decide":
			board.cursor = FormBoard.DECIDE_AT
			return _decide()
		"unhold":
			if board.held < 0:
				return false
			board.held = -1
			return true
	return false


func _pick(i: int) -> bool:
	if board.held < 0:
		if board.id_at(i).is_empty():
			menu.show_notice(menu.texts.t("guild.why.pick_member"))
			return true
		board.held = i
		return true
	if board.held == i:
		board.held = -1
		return true
	if not board.swap(board.held, i):
		menu.show_notice(menu.texts.t("guild.why.row_full"))
	board.held = -1
	return true


## 「결정」: 탐색 화면 입구(arrange_hook)로 대열을 바꾼다. 거부면 이유, 받아들이면 「대열을 바꿨다」(자동 저장은 입구가 했다).
func _decide() -> bool:
	board.held = -1
	if not menu.arrange_hook.is_valid():
		return false
	var events: Array = menu.arrange_hook.call(board.front.duplicate(), board.back.duplicate())
	if events.size() == 1 and events[0]["type"] == "rejected":
		menu.show_notice(menu.texts.t("guild.why." + str(events[0]["reason"])))
		return true
	load_party()
	menu.party_rearranged()
	menu.show_notice(menu.texts.t("guild.arranged"))
	return true


func refresh() -> void:
	board.info = member_info(menu.state, menu.texts)
	board.refresh()


## 디버그 snapshot 의 대열 정보.
func debug_info() -> Dictionary:
	return {"front": board.front.duplicate(), "back": board.back.duplicate(), "cursor": board.cursor, "held": board.held}
