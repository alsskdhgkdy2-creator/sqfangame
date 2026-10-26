## 층 이름 글(M3 A1). 원작 장소 띠 「第1階層 / B1F」(research 07 §2.1) 꼴의 장소 글 「층 이름 / B1F」와 층 표시 「B1F」.
## 탐색 층 문패·캠프 장소 띠·기록 슬롯 줄이 장소 글을, 지도 판 층 문패(64px)가 층 표시만 쓴다.
class_name FloorNames
extends RefCounted


## 층 표시(깊이로 센다: 첫 층 B1F).
static func label(texts: TextDb, defs: GameDefs, f: FloorModel) -> String:
	return texts.t("floor.label", {"depth": defs.depth_of(f.id)})


## 장소 글 「층 이름 / B1F」.
static func place(texts: TextDb, defs: GameDefs, f: FloorModel) -> String:
	return texts.t("floor.place", {"name": texts.t(f.name_key), "label": label(texts, defs, f)})
