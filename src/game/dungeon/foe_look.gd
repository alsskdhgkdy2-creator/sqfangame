## FOE 의 겉모습(M3 A6c, 설계 §5.4): 위협 색과 이름. 3D 표지·지도 원(네 지도)·스냅숏이 함께 쓴다(D28).
## 위협 단계는 규칙(FoeRules.threat: FOE 레벨 − 대원 최고 레벨이 5 이상 red, 0~4 orange, 0 미만 yellow)이 정하고, 색은 여기 하나다.
## red 는 원작 프레임(jp_guide5_img3)의 붉은 공, 단계 경계는 우리 것(설계 §8 Q9).
class_name FoeLook
extends RefCounted

## 보스(M3 A9b 설계 §5.4) 표지 배율: 3D 표지 전체(공·가시·차양·그림자)를 이만큼 키운다. 지도 원은 MapPanel.BOSS_RADIUS·BOSS_RING.
## 원작 프레임에 보스 모양이 없고 그림은 B6 몫이다(이름 붙은 차이).
const BOSS_SCALE := 1.25
const THREAT_COLORS := {
	"red": Color(1.0, 0.16, 0.12),
	"orange": Color(1.0, 0.55, 0.1),
	"yellow": Color(0.95, 0.85, 0.25),
}


## 지금 층 FOE id 의 위협 색. 모르면 red.
static func color(s: ExplorationState, id: String) -> Color:
	return THREAT_COLORS.get(FoeRules.threat(s, id), THREAT_COLORS["red"])


## 지금 층 FOE id 의 이름(그 무리 적 하나의 이름, 설계 §2.2). 모르면 id.
static func name_of(s: ExplorationState, texts: TextDb, id: String) -> String:
	var fe := BattleState.foe_enemy(s.defs, s.floor_def, id)
	if fe.is_empty():
		return id
	return texts.t(s.defs.battle.enemies[fe["enemy"]].name_key)


## 지금 층의 살아 있는 FOE id(층 자료 차례). 마을이면 빈 배열.
static func living(s: ExplorationState) -> Array[String]:
	var out: Array[String] = []
	if s == null or s.in_town():
		return out
	for sp in s.floor_def.foe_list():
		var fs: WorldState.FoeState = s.world.foes.get(sp.id)
		if fs != null and fs.alive():
			out.append(sp.id)
	return out


## 지금 층 FOE id 가 보스 종류인지(M3 A9b).
static func is_boss(s: ExplorationState, id: String) -> bool:
	var sp: FloorModel.FoeSpawn = s.floor_def.foes.get(id) if s != null and s.floor_def != null else null
	return sp != null and sp.kind == "boss"


## 3D 표지 배율(보스 BOSS_SCALE, 나머지 1).
static func scale_of(s: ExplorationState, id: String) -> float:
	return BOSS_SCALE if is_boss(s, id) else 1.0
