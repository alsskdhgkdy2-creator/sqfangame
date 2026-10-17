## 전투 정수 계산(06 §3.1). 실수를 쓰지 않는다. 배율은 천분율(1000 = 1.0배).
## 난수는 GameRng.randi_range 만 쓴다. roll·pick 은 결과가 정해져 있으면 뽑지 않는다.
class_name BattleCalc
extends RefCounted

const ISQRT_MAX := 999 * 1_000_000


## x × p / 1000(버림). 두 값 모두 0 이상이어야 한다.
static func mul(x: int, p: int) -> int:
	assert(x >= 0 and p >= 0, "mul 은 0 이상만 받는다")
	return x * p / 1000


## 확률 판정(p 는 ‰). p ≤ 0 이면 거짓, p ≥ 1000 이면 참이고 둘 다 뽑지 않는다.
static func roll(rng: GameRng, p: int) -> bool:
	if p <= 0:
		return false
	if p >= 1000:
		return true
	return rng.randi_range(0, 999) < p


## 후보 n 개 가운데 하나(0부터). 하나면 뽑지 않는다.
static func pick(rng: GameRng, n: int) -> int:
	return 0 if n <= 1 else rng.randi_range(0, n - 1)


## 가중치 고르기: 합 W 에서 randi_range(0, W − 1) 한 번 뒤 누적 합으로 찾는다. 하나면 뽑지 않는다.
static func pick_weighted(rng: GameRng, weights: Array[int]) -> int:
	if weights.size() <= 1:
		return 0
	var total := 0
	for w in weights:
		total += w
	var r := rng.randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return weights.size() - 1


## 정수 제곱근(뉴턴법, 06 §3.1). n ≥ 0.
static func isqrt(n: int) -> int:
	assert(n >= 0 and n <= ISQRT_MAX, "isqrt 입력 범위")
	if n < 2:
		return n
	var x := n
	var y := (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


## 순서 값 S = AGI × speed × roll(06 §3.4).
static func order_value(agi: int, speed: int, roll_value: int) -> int:
	return agi * speed * roll_value


## 명중 확률(‰, 06 §3.8). agi_t 는 다리 봉인 반영 뒤 값.
static func hit_p(rules: BattleDb.Rules, accuracy: int, agi_a: int, agi_t: int) -> int:
	var ratio := isqrt(agi_a * 1_000_000 / maxi(1, agi_t))
	return clampi(mul(accuracy, ratio), rules.hit_min, rules.hit_max)


## 크리티컬 확률(‰).
static func crit_p(rules: BattleDb.Rules, luc_a: int, luc_t: int) -> int:
	return clampi(rules.crit_base + (luc_a - luc_t) * rules.crit_luck, 0, rules.crit_max)


## 상태이상·봉인 걸림 확률(‰, 06 §3.11). resist 는 그 상태·부위의 누적 내성.
static func status_p(rules: BattleDb.Rules, chance: int, luc_a: int, luc_t: int, vuln: int, resist: int) -> int:
	var p := chance
	p = mul(p, clampi(1000 + (luc_a - luc_t) * rules.status_luck, rules.status_luck_clamp[0], rules.status_luck_clamp[1]))
	p = mul(p, vuln)
	p = mul(p, 1000 - resist)
	return clampi(p, 0, 1000)


## 도주 확률(‰, 06 §3.17). 평균은 정수 나눗셈.
static func escape_p(rules: BattleDb.Rules, party_agi_avg: int, enemy_agi_avg: int) -> int:
	return clampi(rules.escape_base + (party_agi_avg - enemy_agi_avg) * rules.escape_agi, rules.escape_clamp[0], rules.escape_clamp[1])


## 피해 기본값 base = A × A × power / (100 × (A + D × k / 100)).
static func damage_base(a: int, d: int, power: int, k: int) -> int:
	return a * a * power / (100 * (a + d * k / 100))


## 피해 파이프라인(06 §3.9, 속성 배율이 0 이 아닐 때). 입력 p:
##   A, D, power, element(속성 배율), row(근접 후열 보정 여부), atk_muls·def_muls(이미 정해진 곱 순서),
##   guard(방어 중), front_guard(0 이면 없음), crit(크리티컬), roll(피해 난수 값).
## 돌려주는 calc 는 단계마다의 중간값이다: A, D, base, element, row, atk_mul, def_mul, guard, front_guard, crit, roll, final.
static func damage(rules: BattleDb.Rules, p: Dictionary) -> Dictionary:
	var calc := {"A": p["A"], "D": p["D"]}
	var x := damage_base(p["A"], p["D"], p["power"], rules.defense_k)
	calc["base"] = x
	x = mul(x, p["element"])
	calc["element"] = x
	if p["row"]:
		x = mul(x, rules.row_melee_mult)
	calc["row"] = x
	for m in p["atk_muls"]:
		x = mul(x, m)
	calc["atk_mul"] = x
	for m in p["def_muls"]:
		x = mul(x, m)
	calc["def_mul"] = x
	if p["guard"]:
		x = mul(x, rules.guard_mult)
	calc["guard"] = x
	if p["front_guard"] > 0:
		x = mul(x, p["front_guard"])
	calc["front_guard"] = x
	if p["crit"]:
		x = mul(x, rules.crit_mult)
	calc["crit"] = x
	calc["roll"] = p["roll"]
	x = mul(x, p["roll"])
	calc["final"] = maxi(1, x)
	return calc


## 강화·약화 효과 목록 → 곱 순서(06 §3.9): value 오름차순, 같으면 id 문자열 오름차순.
static func effect_order(effects: Array) -> Array[int]:
	var list := effects.duplicate()
	list.sort_custom(func(a, b): return a["value"] < b["value"] or (a["value"] == b["value"] and a["id"] < b["id"]))
	var out: Array[int] = []
	for e in list:
		out.append(e["value"])
	return out
