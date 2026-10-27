## 문구 조사 고르기(TextDb.fill): 자리표시 바로 뒤의 은(는)·이(가)·을(를)·과(와)·(으)로·아(야).
extends TestCase

const PATTERNS := ["은(는)", "이(가)", "을(를)", "과(와)", "(으)로", "아(야)"]


func _f(template: String, v: String) -> String:
	return TextDb.fill(template, {"x": v})


func test_hangul_final_consonant() -> void:
	check_eq(_f("{x}은(는)", "홀로나이트"), "홀로나이트는", "받침 없음")
	check_eq(_f("{x}은(는)", "네온 쥐 꼬리"), "네온 쥐 꼬리는", "받침 없음 2")
	check_eq(_f("{x}이(가)", "나노 메딕"), "나노 메딕이", "받침 있음")
	check_eq(_f("{x}을(를)", "부식 나노"), "부식 나노를", "을(를) 받침 없음")
	check_eq(_f("{x}을(를)", "구동부 잠금"), "구동부 잠금을", "을(를) 받침 있음")
	check_eq(_f("{x}과(와)", "갑충"), "갑충과", "과")
	check_eq(_f("{x}과(와)", "나방"), "나방과", "과 2")
	check_eq(_f("{x}과(와)", "쥐"), "쥐와", "와")
	check_eq(_f("{x}아(야)", "준"), "준아", "아")
	check_eq(_f("{x}아(야)", "레이"), "레이야", "야")
	check_eq(_f("{x}(으)로", "집"), "집으로", "으로")
	check_eq(_f("{x}(으)로", "바다"), "바다로", "로")
	check_eq(_f("{x}(으)로", "레일"), "레일로", "ㄹ 받침은 로")
	check_eq(_f("{x}은(는)", "레일"), "레일은", "ㄹ 받침도 받침")


func test_latin_and_digit_readings() -> void:
	check_eq(_f("{x}은(는)", "듀얼리스트 B"), "듀얼리스트 B는", "B 비")
	check_eq(_f("{x}이(가)", "듀얼리스트 A"), "듀얼리스트 A가", "A 에이")
	check_eq(_f("{x}이(가)", "네온 쥐 C"), "네온 쥐 C가", "C 씨")
	for ch in ["L", "M", "N", "R", "l", "m"]:
		check_eq(_f("{x}은(는)", "기계 " + ch), "기계 %s은" % ch, ch + " 받침 있음")
	check_eq(_f("{x}(으)로", "구역 L"), "구역 L로", "L 엘 → 로")
	check_eq(_f("{x}(으)로", "구역 R"), "구역 R로", "R 알 → 로")
	check_eq(_f("{x}(으)로", "구역 M"), "구역 M으로", "M 엠 → 으로")
	check_eq(_f("{x}(으)로", "구역 B"), "구역 B로", "B 비 → 로")
	var want := {"0": "은", "1": "은", "2": "는", "3": "은", "4": "는", "5": "는", "6": "은", "7": "은", "8": "은", "9": "는"}
	for d in want:
		check_eq(_f("{x}은(는)", "턴 " + d), "턴 %s%s" % [d, want[d]], "숫자 " + d)
	for d in ["1", "7", "8"]:
		check_eq(_f("{x}(으)로", "층 " + d), "층 %s로" % d, "ㄹ 숫자 " + d + " → 로")
	for d in ["0", "3", "6"]:
		check_eq(_f("{x}(으)로", "층 " + d), "층 %s으로" % d, "숫자 " + d + " → 으로")
	check_eq(_f("{x}(으)로", "층 2"), "층 2로", "숫자 2 → 로")


func test_unknown_final_keeps_original() -> void:
	check_eq(_f("{x}은(는)", "기계!"), "기계!은(는)", "기호 끝")
	check_eq(_f("{x}이(가)", ""), "이(가)", "빈 값")
	check_eq(_f("{x}을(를)", "テスト"), "テスト을(를)", "다른 문자")
	check_eq(_f("{x}의 은(는)", "쥐"), "쥐의 은(는)", "자리표시 바로 뒤가 아니면 그대로")


func test_several_holders_and_plain_format() -> void:
	check_eq(TextDb.fill("{actor}이(가) {target}을(를) 감싼다", {"actor": "홀로나이트", "target": "나노 메딕"}),
		"홀로나이트가 나노 메딕을 감싼다", "자리표시 둘")
	check_eq(TextDb.fill("{a}{a}은(는)", {"a": "쥐"}), "쥐쥐는", "같은 자리표시 여러 번")
	check_eq(TextDb.fill("걸음 {steps}", {"steps": 12}), "걸음 12", "조사 없는 문구는 format 그대로")


## 실제 문구: 조사 묶음은 전투 문구(자리표시 바로 뒤)에만 있고, 다른 문구는 고르기 전과 같은 글이다.
## 전투·상점 밖에서 조사 고르기를 쓰는 안내(M3 A3: 전투 드롭 「{item}을(를) 얻었다」와 같은 말씨). 정확한 키만 더한다.
const PARTICLE_MSG_KEYS := ["msg.chest_one", "msg.chest_full", "msg.lock_opened"]


func test_real_texts_only_battle_lines_change() -> void:
	var db := TextDb.load_path("res://data/text/ko.json")
	var holder := RegEx.create_from_string("\\{(\\w+)\\}")
	for key in db._texts:
		var tpl: String = db._texts[key]
		var args := {}
		for m in holder.search_all(tpl):
			args[m.get_string(1)] = "쥐"
		var has_pattern := false
		for name in args:
			for p in PATTERNS:
				if tpl.contains("{%s}%s" % [name, p]):
					has_pattern = true
		if has_pattern:
			check(str(key).begins_with("battle.") or str(key).begins_with("shop.") or PARTICLE_MSG_KEYS.has(key),
				"조사 고르기는 전투·상점 문구와 상자·잠긴 문 안내에만(08 §7.6 shop.confirm.buy_unfit, M3 A3): " + str(key))
			for p in PATTERNS:
				check(not db.t(key, args).contains(p), "%s: 묶음이 남지 않는다 (%s)" % [key, db.t(key, args)])
		elif not args.is_empty():
			check_eq(db.t(key, args), tpl.format(args), "조사 묶음 없는 문구는 그대로: " + str(key))
	check_eq(db.t("battle.event.guarding", {"actor": "듀얼리스트 B"}), "듀얼리스트 B는 방어 자세를 취했다", "로그 예")
	check_eq(db.t("battle.event.ailment_resisted", {"target": "듀얼리스트 B", "ailment": "부식 나노"}),
		"듀얼리스트 B는 부식 나노를 버텼다", "로그 예 2")
