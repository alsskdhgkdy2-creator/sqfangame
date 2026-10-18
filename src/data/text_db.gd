## 화면 문구(data/text/ko.json). 없는 키는 키 그대로 돌려준다.
## 자리표시 바로 뒤의 조사 묶음(은(는)·이(가)·을(를)·과(와)·(으)로·아(야))은 채운 값의 끝 글자로 고른다:
## 한글은 받침, 로마자·숫자는 한국어 읽기(B 비 → 「는」, L 엘 → 「은」). 끝 글자로 정할 수 없으면 원래 표기를 남긴다.
class_name TextDb
extends RefCounted

## 조사 묶음 → [받침 있을 때, 받침 없을 때]. (으)로는 ㄹ 받침도 「로」.
const PARTICLES := {"은(는)": ["은", "는"], "이(가)": ["이", "가"], "을(를)": ["을", "를"], "과(와)": ["과", "와"],
	"(으)로": ["으로", "로"], "아(야)": ["아", "야"]}
## 로마자 읽기의 받침: 0 없음, 1 있음, 2 ㄹ 받침(엘·알).
const LATIN := {"A": 0, "B": 0, "C": 0, "D": 0, "E": 0, "F": 0, "G": 0, "H": 0, "I": 0, "J": 0, "K": 0, "L": 2, "M": 1,
	"N": 1, "O": 0, "P": 0, "Q": 0, "R": 2, "S": 0, "T": 0, "U": 0, "V": 0, "W": 0, "X": 0, "Y": 0, "Z": 0}
## 숫자 읽기(영 일 이 삼 사 오 육 칠 팔 구).
const DIGITS := [1, 2, 0, 1, 0, 0, 1, 2, 2, 0]

var _texts := {}


static func load_path(path: String) -> TextDb:
	var db := TextDb.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			if typeof(data[k]) == TYPE_STRING:
				db._texts[k] = data[k]
	return db


func has(key: String) -> bool:
	return _texts.has(key)


## 문구. args가 있으면 "{name}" 자리를 채우고, 자리표시 바로 뒤의 조사 묶음을 고른다.
func t(key: String, args: Dictionary = {}) -> String:
	var s: String = _texts.get(key, key)
	if args.is_empty():
		return s
	return fill(s, args)


## 틀 글의 자리표시를 채운다(조사 고르기 포함).
static func fill(template: String, args: Dictionary) -> String:
	var s := template
	for k in args:
		var holder := "{%s}" % str(k)
		if not s.contains(holder):
			continue
		var value := str(args[k])
		for group in PARTICLES:
			var pat: String = holder + group
			if s.contains(pat):
				var j := final_kind(value)
				var pick: String = group if j < 0 else PARTICLES[group][0 if (j == 1 or (j == 2 and group != "(으)로")) else 1]
				s = s.replace(pat, holder + pick)
	return s.format(args)


## 끝 글자의 받침: 0 없음, 1 있음(ㄹ 아님), 2 ㄹ 받침, -1 정할 수 없음.
static func final_kind(value: String) -> int:
	if value.is_empty():
		return -1
	var c := value.unicode_at(value.length() - 1)
	if c >= 0xAC00 and c <= 0xD7A3:
		var jong := (c - 0xAC00) % 28
		return 0 if jong == 0 else (2 if jong == 8 else 1)
	if c >= 0x30 and c <= 0x39:
		return DIGITS[c - 0x30]
	var ch := String.chr(c).to_upper()
	if LATIN.has(ch):
		return LATIN[ch]
	return -1
