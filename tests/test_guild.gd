## 모험가 길드 규칙(M3 A7a, 설계 §4.1·§4.1b·§4.2): 등록·이름·편성·등록 지우기·대열 바꾸기, 파티 밖 대원과 숙소·경험치, 쓰러진 파티의 입구,
## 직업·이름·열을 대원이 가지는 읽기(전투·성장·카드·이름). 값은 설계 노트의 글자 그대로 적는다(상수와 견주지 않는다, 교훈 7).
## 시험마다 이름 붙은 변이(설계 노트 §7, M-G…·M-R…)를 적는다.
extends TestCase

const Fx := preload("res://tests/fixtures.gd")

static var _real: GameDefs
static var _texts: TextDb


func _defs() -> GameDefs:
	if _real == null:
		_texts = TextDb.load_path("res://data/text/ko.json")
		var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", _texts)
		check(r.ok(), "실제 묶음 읽기 %s" % str(r.errors))
		_real = r.defs
	return _real


func _town() -> ExplorationState:
	return ExplorationRules.new_game(_defs(), 5, "full", true)


func _ids(list: Array) -> Array:
	return list.map(func(m: PartyState.Member) -> String: return m.id)


func _rows(s: ExplorationState) -> Array:
	return s.party.members.map(func(m: PartyState.Member) -> String: return m.row)


func _snap(s: ExplorationState) -> String:
	return SaveCodec.canonical_state(s)


func _reg(s: ExplorationState, cls: String, name: String, look: int = 0) -> String:
	var ev := GuildRules.register(s, "class." + cls, look, name)
	check_eq(ev[0]["type"], "registered", "준비: %s 등록" % name)
	return ev[0].get("id", "")


# ---- G1 등록 ----

## G1 (M-G1 GUILD_MAX 31, M-G2 새 대원 레벨 2·시작 스킬, M-G3 새 대원이 파티로): 새 대원은 레벨 1·스킬 없음(SP 3)·직업 시작 장비·HP·TP 가득,
## 길드(파티 밖)에 들어가고 ID 는 r<번호>. 명부 30명까지(기본 다섯 + 25), 31번째는 guild_full 이고 아무것도 바뀌지 않는다.
func test_register_and_limits() -> void:
	var s := _town()
	var ev := GuildRules.register(s, "class.nano_medic", 1, "메딕")
	check_eq(ev, [{"type": "registered", "id": "r1", "class": "class.nano_medic", "look": 1, "name": "메딕"}], "등록 이벤트")
	check_eq([s.party.members.size(), s.guild.members.size(), s.guild.serial], [5, 1, 1], "파티 다섯 그대로, 길드에 하나, 번호 1")
	var m := s.guild.members[0]
	check_eq([m.id, m.class_id, m.name, m.name_key, m.look, m.level, m.exp, m.skills, Array(m.equip)],
		["r1", "class.nano_medic", "메딕", "", 1, 1, 0, {}, ["equip.nano_rod", "equip.medic_coat", "equip.sensor_cap", ""]], "새 대원 값(07 시작 장비)")
	check_eq([m.max_hp, m.hp, m.max_tp, m.tp, GrowthRules.sp_left(s.defs, m)], [42, 42, 54, 54, 3], "Lv1 메딕 HP 42·TP 54 가득, SP 3")
	for i in 24:
		_reg(s, "holo_knight", "기사%d" % i)
	check_eq([GuildRules.roster(s).size(), s.guild.serial], [30, 25], "명부 30명(기본 다섯 + 25)")
	var before := _snap(s)
	check_eq(GuildRules.register(s, "class.holo_knight", 0, "넘침"), [{"type": "rejected", "reason": "guild_full"}], "31번째: guild_full")
	check_eq(_snap(s), before, "거부: 상태 그대로")


## G1b: 거부 이유(모르는 직업·외형 범위·미궁·전투·전멸)와 거부 때 상태 그대로.
func test_register_rejects() -> void:
	var s := _town()
	var before := _snap(s)
	for x in [["class.nope", 0, "a", "unknown_class"], ["class.nano_medic", 2, "a", "bad_look"], ["class.nano_medic", -1, "a", "bad_look"],
			["class.nano_medic", 1.0, "a", "bad_look"], ["class.nano_medic", "0", "a", "bad_look"], ["class.nano_medic", 0, "", "name_empty"]]:
		check_eq(GuildRules.register(s, x[0], x[1], x[2]), [{"type": "rejected", "reason": x[3]}], "%s %s: %s" % [x[0], str(x[1]), x[3]])
	check_eq(_snap(s), before, "거부: 상태 그대로")
	var lab := ExplorationRules.new_game(_defs(), 5, "full")
	check_eq(GuildRules.register(lab, "class.nano_medic", 0, "a")[0]["reason"], "not_town", "미궁: not_town")
	lab.wiped = true
	check_eq(GuildRules.register(lab, "class.nano_medic", 0, "a")[0]["reason"], "wiped", "전멸: wiped")


# ---- G2 이름 ----

## G2 (M-G4 NAME_MAX 9, M-G5 화면 이름 겹침을 보지 않음): 1~8자, 한글 음절·자모·영문·숫자·낱말 사이 공백 하나.
func test_name_rules() -> void:
	var cases := [["", "name_empty"], ["가", ""], ["가나다라마바사아", ""], ["가나다라마바사아자", "name_long"], ["ㄱㄴ", ""], ["Ab 12", ""],
		["a  b", "name_chars"], [" a", "name_chars"], ["a ", "name_chars"], ["a!", "name_chars"], ["가😀", "name_chars"], ["カ", "name_chars"], ["a_b", "name_chars"]]
	for c in cases:
		check_eq(GuildRules.name_problem(c[0]), c[1], "이름 「%s」" % c[0])
	var s := _town()
	_reg(s, "nano_medic", "메딕")
	check_eq(GuildRules.register(s, "class.nano_medic", 0, "메딕"), [{"type": "rejected", "reason": "name_taken"}], "등록한 이름 겹침")
	var taken := s.party.members.map(func(m: PartyState.Member) -> String: return PartyNames.display_name(_texts, m))
	check_eq(taken[0], "홀로나이트", "준비: 기본 이름은 이름 키 글")
	check_eq(GuildRules.register(s, "class.nano_medic", 0, "홀로나이트", taken), [{"type": "rejected", "reason": "name_taken"}], "기본 다섯의 화면 이름 겹침")
	check_eq(GuildRules.register(s, "class.nano_medic", 0, "듀얼리스트 C", taken)[0]["type"], "registered", "겹치지 않는 이름")


## G2b: 이름 바꾸기 — 자기 이름은 겹침이 아니고 같은 이름이면 unchanged, 기본 대원도 이름을 얻는다.
func test_rename() -> void:
	var s := _town()
	var id := _reg(s, "nano_medic", "메딕")
	_reg(s, "nano_medic", "둘째")
	check_eq(GuildRules.rename(s, id, "메딕"), [{"type": "rejected", "reason": "unchanged"}], "같은 이름: unchanged")
	check_eq(GuildRules.rename(s, id, "둘째"), [{"type": "rejected", "reason": "name_taken"}], "다른 대원 이름: name_taken")
	check_eq(GuildRules.rename(s, id, "새이름"), [{"type": "renamed", "id": id, "name": "새이름"}], "바꿈")
	check_eq(GuildRules.rename(s, "holo_knight", "기사단장")[0]["type"], "renamed", "기본 대원도 이름을 얻는다")
	check_eq(PartyNames.member_name(s, _texts, 0), "기사단장", "그 뒤 화면 이름은 등록한 이름")
	check_eq(GuildRules.rename(s, "zz", "a")[0]["reason"], "unknown_member", "모르는 대원")


# ---- G3 편성 ----

## G3 (M-G6 party_empty 를 보지 않음, M-G7 열 상한 4, M-G8 후열이 전열 앞): 거부는 모두 상태 그대로. 받으면 전열 → 후열 차례, 열 값,
## 빠진 대원은 길드로(명부 차례: 파티 차례, 그다음 길드 차례).
func test_form() -> void:
	var s := _town()
	var r1 := _reg(s, "nano_medic", "메딕")
	var before := _snap(s)
	var bad := [
		[[], [], "party_empty"],
		[["holo_knight", "blade_duelist", "blade_duelist_2", "r1"], [], "row_full"],
		[["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", "glyph_wizard", "r1"], "party_full"],
		[["holo_knight", "holo_knight"], [], "duplicate"],
		[["holo_knight"], ["zz"], "unknown_member"],
		[["holo_knight", 3], [], "bad_list"],
		[["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", "glyph_wizard"], "unchanged"],
	]
	for b in bad:
		check_eq(GuildRules.form(s, b[0], b[1]), [{"type": "rejected", "reason": b[2]}], "편성 %s / %s: %s" % [str(b[0]), str(b[1]), b[2]])
	check_eq(_snap(s), before, "거부: 상태 그대로")
	var ev := GuildRules.form(s, ["blade_duelist", "holo_knight"], [r1, "glyph_wizard"])
	check_eq(ev, [{"type": "formed", "front": ["blade_duelist", "holo_knight"], "back": [r1, "glyph_wizard"]}], "편성 이벤트")
	check_eq([_ids(s.party.members), _rows(s), _ids(s.guild.members)],
		[["blade_duelist", "holo_knight", "r1", "glyph_wizard"], ["front", "front", "back", "back"], ["blade_duelist_2", "nano_medic"]], "파티·열·길드 차례")
	var one := GuildRules.form(s, [], ["nano_medic"])
	check_eq([one[0]["type"], _ids(s.party.members), _rows(s)], ["formed", ["nano_medic"], ["back"]], "한 명 파티(후열만)도 된다")
	check_eq(_ids(s.guild.members), ["blade_duelist", "holo_knight", "r1", "glyph_wizard", "blade_duelist_2"], "길드 차례: 앞 파티 차례, 그다음 길드 차례")


## G3b: 모두 쓰러진 대원만으로는 짜지 못한다(party_down: 저장 검사의 「모두 HP 0 ⇔ 전멸」을 지킨다).
func test_form_rejects_downed_party() -> void:
	var s := _town()
	var r1 := _reg(s, "nano_medic", "메딕")
	s.guild.members[0].hp = 0
	var before := _snap(s)
	check_eq(GuildRules.form(s, [r1], []), [{"type": "rejected", "reason": "party_down"}], "쓰러진 대원 하나: party_down")
	check_eq(_snap(s), before, "상태 그대로")
	check_eq(GuildRules.form(s, [r1, "holo_knight"], [])[0]["type"], "formed", "살아 있는 대원이 있으면 된다")
	var lab := ExplorationRules.new_game(_defs(), 5, "full")
	check_eq(GuildRules.form(lab, ["holo_knight"], [])[0]["reason"], "not_town", "미궁: not_town")


# ---- G4 등록 지우기 ----

## G4 (M-G9 낀 장비를 버림, M-G10 지운 번호를 다시 씀): 파티 대원은 in_party, 길드 대원은 지우고 장비는 가방으로. 가방이 차면 bag_full.
func test_remove() -> void:
	var s := _town()
	var r1 := _reg(s, "nano_medic", "메딕")
	check_eq(GuildRules.remove(s, "holo_knight"), [{"type": "rejected", "reason": "in_party"}], "파티 대원: in_party")
	var ev := GuildRules.remove(s, r1)
	check_eq(ev, [{"type": "removed", "id": "r1", "returned": ["equip.nano_rod", "equip.medic_coat", "equip.sensor_cap"]}], "지움·돌려받은 장비")
	check_eq([s.guild.members.size(), s.gear_bag], [0, {"equip.nano_rod": 1, "equip.medic_coat": 1, "equip.sensor_cap": 1}], "길드 빔, 장비는 가방")
	check_eq(_reg(s, "nano_medic", "둘째"), "r2", "번호는 다시 쓰지 않는다(r2)")
	s.materials = {"item.neon_rat_tail": 57}
	var before := _snap(s)
	check_eq(GuildRules.remove(s, "r2"), [{"type": "rejected", "reason": "bag_full"}], "가방 빈 칸 0(57 + 3 = 60): bag_full")
	check_eq(_snap(s), before, "상태 그대로")
	s.materials = {"item.neon_rat_tail": 54}
	check_eq(GuildRules.remove(s, "r2")[0]["type"], "removed", "빈 칸 3: 된다")


# ---- G5 파티 밖 대원 ----

## G5 (M-G11 숙소가 길드 대원도 회복): 숙소는 파티만 회복하고 값은 파티 최고 레벨. 날이 바뀌어도 길드 대원은 그대로. 경험치는 살아 있는 파티 대원만.
func test_guild_members_rest_outside() -> void:
	var s := _town()
	var r1 := _reg(s, "nano_medic", "메딕")
	GuildRules.form(s, ["holo_knight", "blade_duelist", "blade_duelist_2"], [r1, "glyph_wizard"])
	var medic := GuildRules.find(s, "nano_medic")
	medic.hp = 5
	medic.tp = 1
	medic.level = 6
	medic.exp = s.defs.battle.growth.cum(6)
	GrowthRules.refresh_max(s.defs, -1, medic)
	s.party.members[0].hp = 3
	s.money = 1000
	check_eq(TownRules.inn_price(s), 10, "값 = 10 × 파티 최고 레벨 1(길드의 Lv6 은 세지 않는다)")
	var ev := TownRules.stay(s)
	check(ev.any(func(e: Dictionary) -> bool: return e["type"] == "stayed"), "묵음")
	check_eq([s.party.members[0].hp, medic.hp, medic.tp], [s.party.members[0].max_hp, 5, 1], "파티는 가득, 길드 대원은 그대로")
	ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, BattleRules.pick_formation(s))
	check_eq(s.battle.party.size(), 5, "전투 유닛은 파티 다섯")
	for u in s.battle.enemies:
		u.hp = 0
		u.kill = {"turn": 0, "element": null, "ailment": null, "binds": [], "by": "attack"}
	var exp_before := medic.exp
	var p_before := s.party.members[0].exp
	var fe: Array[Dictionary] = []
	BattleRules.finish(s, "victory", fe)
	check(s.party.members[0].exp > p_before, "파티 대원은 경험치를 받는다")
	check_eq(medic.exp, exp_before, "길드 대원은 받지 않는다")


## G6 (M-G12 막음을 없앰): 마을의 파티가 모두 쓰러져 있으면 ENTER 는 blocked party_down(미궁으로 가지 않는다).
func test_enter_needs_a_standing_member() -> void:
	var s := _town()
	for m in s.party.members:
		m.hp = 0
	check_eq(ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full"), [{"type": "blocked", "reason": "party_down"}], "모두 쓰러짐: party_down")
	check_eq(s.location, "town", "마을 그대로")
	s.party.members[4].hp = 1
	check_eq(ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")[0]["type"], "entered", "한 명이라도 서 있으면 들어간다")


# ---- 대열 바꾸기 (§4.1b) ----

## A-1..A-6 (M-G13 전투 중에도 받음, M-G14 시간이 감, M-G15 길드 대원을 받음): 미궁에서 지금 파티 대원만으로 순서·열을 바꾼다.
## 거부는 상태 그대로. 받으면 걸음·위험도·한계값·난수·FOE·위치가 그대로이고 파티 순서·열만 바뀐다.
func test_arrange_rules() -> void:
	var t := _town()
	var r1 := _reg(t, "nano_medic", "메딕")
	ExplorationRules.apply(t, ExplorationRules.Action.ENTER, "full")
	t.encounter.threshold = 99999
	ExplorationRules.apply(t, ExplorationRules.Action.FORWARD, "full")
	var before := _snap(t)
	var cases := [
		[["holo_knight", "blade_duelist"], ["nano_medic", "glyph_wizard"], "not_party"],
		[["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", r1], "not_party"],
		[["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", "glyph_wizard", r1], "not_party"],
		[["holo_knight", "blade_duelist", "blade_duelist_2", "nano_medic"], ["glyph_wizard"], "row_full"],
		[["holo_knight", "holo_knight", "blade_duelist_2"], ["nano_medic", "glyph_wizard"], "duplicate"],
		[["holo_knight", "blade_duelist", "blade_duelist_2"], ["nano_medic", "glyph_wizard"], "unchanged"],
	]
	for c in cases:
		check_eq(GuildRules.arrange(t, c[0], c[1]), [{"type": "rejected", "reason": c[2]}], "대열 %s / %s: %s" % [str(c[0]), str(c[1]), c[2]])
	check_eq(_snap(t), before, "거부: 상태 그대로")
	var d0 := SaveCodec.state_to_dict(t)
	var rng0 := t.rng.get_state()
	var ev := GuildRules.arrange(t, ["holo_knight", "blade_duelist_2"], ["nano_medic", "glyph_wizard", "blade_duelist"])
	check_eq(ev, [{"type": "arranged", "front": ["holo_knight", "blade_duelist_2"], "back": ["nano_medic", "glyph_wizard", "blade_duelist"]}], "대열 이벤트")
	check_eq([_ids(t.party.members), _rows(t)], [["holo_knight", "blade_duelist_2", "nano_medic", "glyph_wizard", "blade_duelist"],
		["front", "front", "back", "back", "back"]], "새 순서·열")
	var d1 := SaveCodec.state_to_dict(t)
	check_eq(t.rng.get_state(), rng0, "난수 그대로")
	for k in d0:
		if k != "party":
			check_eq(d1[k], d0[k], "%s 그대로" % k)
	check_eq([d1["party"]["at"], d1["party"]["facing"]], [d0["party"]["at"], d0["party"]["facing"]], "위치·방향 그대로")
	check_eq(_ids(t.guild.members), ["r1"], "길드 그대로")
	# 전투 대기·전투 중·전멸은 거부
	t.encounter.threshold = 50
	t.encounter.danger = 50
	BattleRules.start(t, BattleRules.pick_formation(t))
	var mid := _snap(t)
	check_eq(GuildRules.arrange(t, ["holo_knight", "nano_medic"], ["blade_duelist_2", "glyph_wizard", "blade_duelist"]), [{"type": "rejected", "reason": "in_battle"}], "전투 중: in_battle")
	check_eq(_snap(t), mid, "전투 중 거부: 상태 그대로")
	var w := _town()
	w.wiped = true
	check_eq(GuildRules.arrange(w, ["holo_knight"], ["blade_duelist", "blade_duelist_2", "nano_medic"])[0]["reason"], "wiped", "전멸: wiped")
	var tw := _town()
	check_eq(GuildRules.arrange(tw, ["holo_knight", "blade_duelist", "nano_medic"], ["blade_duelist_2", "glyph_wizard"])[0]["type"], "arranged", "마을에서도 된다")


## A-7: 대열을 바꾼 뒤 연 전투는 새 차례·열로 유닛을 만든다(전투 칸 = 파티 칸).
func test_battle_after_arrange_uses_new_rows() -> void:
	var t := ExplorationRules.new_game(_defs(), 5, "full")
	var ev := GuildRules.arrange(t, ["glyph_wizard", "nano_medic"], ["holo_knight", "blade_duelist", "blade_duelist_2"])
	check_eq(ev[0]["type"], "arranged", "대열 바꿈")
	t.encounter.danger = t.encounter.threshold
	BattleRules.start(t, BattleRules.pick_formation(t))
	var b := t.battle
	check_eq([b.party.map(func(u: BattleUnit) -> String: return u.def_id), b.party.map(func(u: BattleUnit) -> String: return u.row)],
		[["glyph_wizard", "nano_medic", "holo_knight", "blade_duelist", "blade_duelist_2"], ["front", "front", "back", "back", "back"]], "전투 유닛 차례·열")


# ---- G7·G8 대원이 가진 직업·이름·열을 읽는 곳 ----

## G7 (M-R1 전투 열을 정의에서 읽음, M-R2 성장 묶음의 직업을 정의 칸에서 읽음): 칸 0 이 새로 등록한 위저드인 파티.
func test_readers_follow_the_member() -> void:
	var s := _town()
	var r1 := _reg(s, "glyph_wizard", "위저드2", 1)
	GuildRules.form(s, [r1, "holo_knight"], ["nano_medic"])
	var m0 := s.party.members[0]
	check_eq([m0.max_hp, m0.max_tp], [40, 60], "칸 0 은 Lv1 위저드 HP 40·TP 60(칸 0 기본 직업 홀로나이트 60·30 이 아니다)")
	var p := GrowthRules.profile(s.defs, 0, m0)
	check_eq([p["stats"]["INT"], p["weapon"]], [21, "equip.glyph_stylus"], "성장 묶음: 위저드 INT 21, 시작 장비 무기")
	check_eq(s.class_of(0).id, "class.glyph_wizard", "ExplorationState.class_of")
	check_eq(PartyNames.class_ids(s), ["class.glyph_wizard", "class.holo_knight", "class.nano_medic"], "카드 직업 차례")
	check_eq([PartyNames.member_name(s, _texts, 0), PartyNames.member_name(s, _texts, 1)], ["위저드2", "홀로나이트"], "화면 이름")
	var d := BattleDisplay.from_party(s, _texts)
	check_eq([d.party.map(func(u: Variant) -> String: return u.row), d.party.map(func(u: Variant) -> String: return u.name)],
		[["front", "front", "back"], ["위저드2", "홀로나이트", "나노 메딕"]], "파티 카드 표시: 열·이름")
	ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, BattleRules.pick_formation(s))
	var b := s.battle
	check_eq([b.party.size(), b.party[0].name, b.party[0].name_key, b.party[1].name_key, b.party.map(func(u: BattleUnit) -> String: return u.row)],
		[3, "위저드2", "", "member.holo_knight", ["front", "front", "back"]], "전투 유닛: 셋, 이름·이름 키·열")
	check_eq(b.party[0].stats, p["stats"], "전투 유닛 능력치 = 성장 묶음")
	var shown := BattleDisplay.from_state(s, _texts)
	check_eq(shown.party[0].name, "위저드2", "전투 표시 이름")


## G8 (M-R3 전투가 대원 다섯을 요구): 두 명 파티로 전투를 열고 한 턴 제출·승리까지.
func test_two_member_battle() -> void:
	var s := _town()
	GuildRules.form(s, ["holo_knight"], ["nano_medic"])
	ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")
	s.encounter.danger = s.encounter.threshold
	var st := BattleRules.start(s, BattleRules.pick_formation(s))
	check_eq([st[0]["type"], s.battle.party.size() if s.battle != null else -1], ["battle_start", 2], "두 명 전투")
	if s.battle == null:
		return
	var ev := BattleRules.submit(s, BattlePolicy.choose(s, "default"))
	check(not ev.is_empty() and ev[0]["type"] != "rejected", "명령 둘 제출 %s" % str(ev[0]))
	var t := ExplorationRules.new_game(_defs(), 5, "full", true)
	check(BattleState.create(t.defs, [] as Array[PartyState.Member], "formation.b1.rats") == null, "대원 0명: 전투를 만들지 않는다")


## G9 (M-G17 번호 읽기가 is_valid_int 로 돌아감): 새 대원 ID 는 r 뒤에 0 으로 시작하지 않는 ASCII 숫자 1~4자리만 번호가 있다.
## 부호·앞 0·소수점·공백·다른 숫자 글자는 -1(register 가 만들 수 없는 꼴).
func test_recruit_ids_are_canonical() -> void:
	for x in [["r1", 1], ["r12", 12], ["r9999", 9999], ["r10000", -1], ["r0", -1], ["r01", -1], ["r+1", -1], ["r+01", -1], ["r-1", -1],
			["r1.0", -1], ["r 1", -1], ["r1 ", -1], ["r", -1], ["rx", -1], ["R1", -1], ["holo_knight", -1], ["r١", -1], ["r１", -1]]:
		check_eq(GuildRules.recruit_number(x[0]), x[1], "번호 %s" % x[0])
	var s := _town()
	check_eq(_reg(s, "nano_medic", "메딕"), "r1", "등록이 만드는 ID")
	check_eq(GuildRules.recruit_number(s.guild.members[0].id), 1, "만든 ID 의 번호")
