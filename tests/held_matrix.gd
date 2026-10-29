## 누르기 지킴이 시험 묶음(M3 A7d, PressGuard): 화면(주인)의 고름 값이 바뀌는 동안 누르고 있던 단추 — 키패드 「선택」·줄·카드·창 단추 —
## 를 실제 터치(손가락 3)로 누른 채 값을 바꾸고(pad: 손가락 4 로 방향 패드, key: 키보드) 뗀다. 값이 바뀌었는지, 누르기가 풀렸는지,
## 뗄 때 아무 일도 없는지(관찰 값 그대로: 상태 해시·저장 수·화면 쪽 등) 본다. 시험 파일이 preload 해서 쓴다(test_ 파일이 아니다).
extends RefCounted

const FINGER := 3


## 한 경우를 pad·key 두 가지로. c:
##   name: 이름, hold: Callable() -> TouchButton(누를 단추), pad: Callable() -> TouchButton(값을 바꿀 방향 패드 단추), key: 키 코드,
##   value: Callable() -> Variant(바뀌어야 할 고름 값), observe: Callable() -> Array(뗄 때 그대로여야 할 것),
##   reset: Callable(코루틴 가능, 경우마다 처음 값으로 되돌림, 없으면 안 함), variants: ["pad", "key"](기본).
static func run(t: TestCase, kit: RefCounted, c: Dictionary) -> void:
	for v in c.get("variants", ["pad", "key"]):
		if c.has("reset"):
			await (c["reset"] as Callable).call()
			await kit.frames(1)
		var tag := "%s(%s)" % [c["name"], v]
		var b: TouchButton = (c["hold"] as Callable).call()
		if b == null or not b.is_visible_in_tree():
			t.check(false, tag + ": 누를 단추가 보인다")
			continue
		var p: Vector2 = kit.center_of(b)
		var v0: Variant = (c["value"] as Callable).call()
		kit.touch(FINGER, p, true)
		await kit.frames(1)
		t.check(b.held, tag + ": 준비: 누르는 중")
		if v == "pad":
			await kit.tap(kit.center_of((c["pad"] as Callable).call()), FINGER + 1)
		else:
			await kit.press_key(int(c["key"]))
		var v1: Variant = (c["value"] as Callable).call()
		t.check(v1 != v0, "%s: 값이 바뀌었다 %s → %s" % [tag, str(v0), str(v1)])
		t.check(not b.held, tag + ": 값이 바뀌면 누르기 취소")
		var seen: Array = (c["observe"] as Callable).call()
		kit.touch(FINGER, p, false)
		await kit.frames(3)
		t.check_eq((c["observe"] as Callable).call(), seen, tag + ": 뗄 때 아무 일 없음")


## 가만히 있는 동안(누르기 없음) 주인의 고름 값이 frames 프레임 동안 그대로인지(값에 매 프레임 바뀌는 것이 들어 있으면 모든 누르기가
## 거부된다). 주인이 selection_key 를 가져야 한다.
static func stable(t: TestCase, kit: RefCounted, host: Node, tag: String, frames: int = 12) -> void:
	t.check(host.has_method("selection_key"), tag + ": 주인이 selection_key 를 가진다")
	var k0: Array = host.call("selection_key")
	t.check(not k0.is_empty(), tag + ": 열린 주인의 고름 값은 비어 있지 않다")
	for i in frames:
		await kit.frames(1)
		var k: Array = host.call("selection_key")
		if k != k0:
			t.check_eq(k, k0, "%s: 가만히 있는 동안 고름 값 그대로(%d 프레임째)" % [tag, i + 1])
			return
	t.check(true, tag + ": 고름 값 그대로")


## 주인 아래 보이는 단추를 하나씩 눌러(손가락 3, 누르기만) 주인의 고름 값이 누르는 순간 바뀌지 않는지 본다(누른 순간 고르는 단추 금지).
## 누르는 순간 일하는 방향 단추(fire_on_press)와 흐린 단추는 뺀다. 누른 단추는 cancel 한 뒤 떼서 아무 일도 하지 않게 한다.
## 돌려주는 값: 눌러 본 단추 수.
static func press_audit(t: TestCase, kit: RefCounted, host: Node, tag: String) -> int:
	var n := 0
	for node in host.find_children("*", "TouchButton", true, false):
		var b := node as TouchButton
		if not b.is_visible_in_tree() or b.fire_on_press or b.disabled or b.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if PressGuard.scope_of(b) != host:
			continue
		var p: Vector2 = kit.center_of(b)
		var k0: Array = host.call("selection_key")
		kit.touch(FINGER, p, true)
		await kit.frames(1)
		var k1: Array = host.call("selection_key")
		PressGuard.cancel_under(host)
		kit.touch(FINGER, p, false)
		await kit.frames(1)
		t.check_eq(k1, k0, "%s: %s 를 누르는 순간 고름 값이 바뀌지 않는다" % [tag, b.name])
		n += 1
	return n


## 값 get 이 want 가 될 때까지 키 code 를 누른다(누르기 없음, 최대 8번).
static func key_until(kit: RefCounted, get: Callable, want: Variant, code: int) -> void:
	for i in 8:
		if get.call() == want:
			return
		await kit.press_key(code)


## 기록 시험 준비: 시험 임시 저장 폴더(kit)의 슬롯 1·2 에 소지금 111·222 인 새 게임을 둔다(사용자 저장은 건드리지 않는다).
static func make_slots(s: DungeonScreen) -> void:
	for pair in [["slot1", 111], ["slot2", 222]]:
		var v := ExplorationRules.new_game(s.state.defs, 7, "full", true)
		v.money = pair[1]
		s.store.save(pair[0], v)


## 슬롯의 소지금(없거나 못 읽으면 -1).
static func slot_money(s: DungeonScreen, id: String) -> int:
	var l := s.store.load_slot(id)
	return l.result.state.money if l.ok() else -1
