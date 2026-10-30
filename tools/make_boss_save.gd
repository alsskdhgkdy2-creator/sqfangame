## 웹 확인 J 의 고정 저장(tools/web_check_boss_save.json, M3 A9b 설계 §7.3)을 실제 공략으로 만든다: 마을 새 게임(시드 41) → 관리국 임무 둘
## (실제 의뢰 규칙) → arbor_route.json → 봉인 임무 보고 → B3F (9,2) 서쪽(봉인 앞) = Fx.walk_to_boss. 대원마다 디버그 경험치 보급과 같은 규칙
## (GrowthRules.grant_exp)으로 Lv 10 까지. 저장 시각·세대는 고정이라 같은 코드·자료면 같은 파일이 나온다. test_boss_route T4 가 파일 전체를
## save_text() 와 견준다(고정 저장이 만드는 쪽과 어긋나면 실패).
##   GODOT_SILENCE_ROOT_WARNING=1 flock /tmp/sqfangame-godot.lock timeout 300 godot --headless -s tools/make_boss_save.gd
extends SceneTree

const OUT := "res://tools/web_check_boss_save.json"
const SEED := 41
const LEVEL := 10
const SAVED_AT := "2026-10-30T00:00:00Z"
const COMMAND := "GODOT_SILENCE_ROOT_WARNING=1 flock /tmp/sqfangame-godot.lock timeout 300 godot --headless -s tools/make_boss_save.gd"


func _init() -> void:
	var text := save_text()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote %s (%d bytes)" % [OUT, text.length()])
	quit()


## 고정 저장의 글(공략 상태를 고정 시각·세대로 저장 형식으로).
static func save_text() -> String:
	return SaveCodec.encode(build_state(), SAVED_AT, 0)


static func build_state() -> ExplorationState:
	var fx: GDScript = load("res://tests/fixtures.gd")
	var s: ExplorationState = fx.walk_to_boss(fx.arbor(), SEED)
	for i in s.party.members.size():
		while s.party.members[i].level < LEVEL:
			var ev := GrowthRules.grant_exp(s, i, 10)
			assert(ev[0]["type"] != "rejected", str(ev))
	return s
