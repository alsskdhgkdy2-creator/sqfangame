## 스킬 설명(전투 스킬 설명 칸, M2.6 U2). head = 「이름  Lv n  TP t」, line = 대상 범위·사거리·속성·위력과 명중
## (또는 상태이상·회복·소생·해제·강화·약화·프론트 가드·감싸기·모으기)·덧붙는 상태이상·봉인의 확률과 턴·행동 순서.
## 패시브는 「패시브」와 보정 값(전투 스킬 목록에는 나오지 않지만 같은 규칙으로 글을 만든다).
## 숫자는 모두 스킬 정의의 그 레벨 줄에서 읽는다(글 사전에는 숫자가 없다). 정의에 있어야 할 값이 없거나 모르는 effect 면
## 값을 지어내지 않는다: push_error 를 남기고 그 자리에 MISSING(「?」)을 보인다.
class_name SkillSummary
extends RefCounted

const MISSING := "?"
## ‰ 로 적힌 필드(「40%」처럼 보인다).
const PERMILLE := ["accuracy", "chance", "value", "hp_permille"]


static func head(texts: TextDb, s: BattleDb.SkillDef, level: int) -> String:
	if s == null:
		push_error("SkillSummary: 스킬 정의가 없다")
		return MISSING
	var row := s.level_row(level)
	if s.passive():
		return texts.t("battle.ui.passive_head", {"skill": texts.t(s.name_key), "level": level})
	return texts.t("battle.ui.skill_head", {"skill": texts.t(s.name_key), "level": level, "tp": _num(row, "tp", s, level)})


## 설명 조각들(차례대로 「 · 」로 잇는다).
static func parts(texts: TextDb, s: BattleDb.SkillDef, level: int) -> Array[String]:
	var out: Array[String] = []
	if s == null:
		push_error("SkillSummary: 스킬 정의가 없다")
		out.append(MISSING)
		return out
	var row := s.level_row(level)
	if s.passive():
		out.append(texts.t("battle.info.passive"))
		var bonus: Variant = row.get("bonus")
		if typeof(bonus) != TYPE_DICTIONARY or (bonus as Dictionary).is_empty():
			out.append(_missing(s, level, "bonus"))
			return out
		for k in bonus:
			var v: Variant = bonus[k]
			out.append("%s %s" % [texts.t("stat." + str(k)), _signed(int(v)) if _is_num(v) else _missing(s, level, "bonus." + str(k))])
		return out
	out.append(texts.t("battle.scope." + s.target) if not s.target.is_empty() else _missing(s, level, "target"))
	match s.effect:
		"damage":
			out.append(texts.t("battle.info.melee" if s.range_kind == "melee" else "battle.info.ranged"))
			out.append(texts.t("element." + s.element) if not s.element.is_empty() else _missing(s, level, "element"))
			out.append(texts.t("battle.info.power", {"n": _num(row, "power", s, level)}))
			out.append(texts.t("battle.info.accuracy", {"pct": _num(row, "accuracy", s, level)}))
		"ailment":
			if not row.has("ailment"):
				out.append(_missing(s, level, "ailment"))
		"heal":
			out.append(texts.t("battle.info.heal", {"base": _num(row, "base", s, level), "pct": _num(row, "wis_pct", s, level)}))
		"revive":
			out.append(texts.t("battle.info.revive", {"pct": _num(row, "hp_permille", s, level)}))
		"cure":
			out.append(texts.t("battle.info.cure"))
		"buff", "debuff":
			var kind := str(row.get("kind", ""))
			out.append(texts.t("battle.info.buff", {"kind": texts.t("battle.buff." + kind) if not kind.is_empty() else _missing(s, level, "kind"),
				"pct": _num(row, "value", s, level), "turns": _num(row, "turns", s, level)}))
		"front_guard":
			out.append(texts.t("battle.info.front_guard", {"pct": _num(row, "value", s, level)}))
		"cover":
			out.append(texts.t("battle.info.cover"))
		"charge":
			out.append(texts.t("battle.info.charge", {"skill": texts.t(s.charges) if not s.charges.is_empty() else _missing(s, level, "charges")}))
		_:
			out.append(_missing(s, level, "effect " + s.effect))
	if row.has("ailment"):
		var a: Variant = row["ailment"]
		var t := _inflict(texts, a, "id", "ailment.", s, level)
		if typeof(a) == TYPE_DICTIONARY and (a as Dictionary).has("damage"):
			t += " " + texts.t("battle.info.poison_damage", {"n": _num(a, "damage", s, level)})
		out.append(t)
	if row.has("bind"):
		out.append(_inflict(texts, row["bind"], "part", "bind.", s, level))
	match s.priority:
		"first":
			out.append(texts.t("battle.info.first"))
		"last":
			out.append(texts.t("battle.info.last"))
	return out


static func line(texts: TextDb, s: BattleDb.SkillDef, level: int) -> String:
	return " · ".join(parts(texts, s, level))


## ‰ → 「40%」「32.5%」
static func pct(permille: int) -> String:
	return ("%d%%" % (permille / 10)) if permille % 10 == 0 else ("%.1f%%" % (permille / 10.0))


## 상태이상·봉인 한 조각: 「이동부 잠금 40% · 3턴」
static func _inflict(texts: TextDb, d: Variant, name_field: String, prefix: String, s: BattleDb.SkillDef, level: int) -> String:
	if typeof(d) != TYPE_DICTIONARY:
		return _missing(s, level, prefix.trim_suffix("."))
	var who := str((d as Dictionary).get(name_field, ""))
	return texts.t("battle.info.inflict", {"name": texts.t(prefix + who) if not who.is_empty() else _missing(s, level, prefix + name_field),
		"chance": _num(d, "chance", s, level), "turns": _num(d, "turns", s, level)})


## 줄의 숫자 하나를 보이는 글로(‰ 필드는 「%」). 없으면 push_error 와 MISSING.
static func _num(d: Dictionary, key: String, s: BattleDb.SkillDef, level: int) -> String:
	var v: Variant = d.get(key)
	if not _is_num(v):
		return _missing(s, level, key)
	return pct(int(v)) if PERMILLE.has(key) else str(int(v))


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


static func _signed(v: int) -> String:
	return "+%d" % v if v >= 0 else str(v)


static func _missing(s: BattleDb.SkillDef, level: int, what: String) -> String:
	push_error("SkillSummary: %s Lv%d 에 %s 가 없다(또는 모르는 값)" % [s.id, level, what])
	return MISSING
