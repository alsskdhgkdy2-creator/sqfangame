## 저장 11판(M3 A7a, 설계 §3): 파티 대원의 길드 값(이름·직업·외형·열)과 guild(파티 밖 대원·등록 번호) 왕복·엄격 검사,
## 10판 고정 문서 → 11판(기본 다섯이 칸 그대로 길드 값을 얻고 길드는 빔), 전투 중 저장, 대열 바꾸기 뒤 저장. 시험마다 죽이는 변이(M-S…)를 적는다.
##
## 고정 문서 다섯은 HEAD 53cecf0 코드(A7 편집 전 깨끗한 작업 트리를 /tmp 의 git worktree 로 연 것)로 저장소 밖 생성기(/tmp/sqf_a7/gen_v10.gd)가 만들었다:
##   cd /tmp && godot --headless --path /tmp/sqf_a7/head -s /tmp/sqf_a7/gen_v10.gd
## 생성기는 Fx.arbor() 새 게임(시드 31)으로 arbor_route.json 공략을 걷는다(전투는 승리). V10_TOWN 은 레벨이 오른 대원·이온 세이버·배운 스킬,
## V10_BATTLE 은 B2F 인카운트 전투 한 턴 뒤 적 0 수면·대원 1 팔 봉인, V10_CONTACT 는 B1F 숫양 접촉 전투, V10_WIPED 는 전멸, V10_TEST 는 시험 묶음.
## SaveCodec.encode(saved_at, generation 101~105)로 쓴 뒤 같은 HEAD 코드로 다시 읽어 from_schema 10 을 확인했다. 문서를 바꾸지 말 것(10판 이전 길의 기준이다).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const V7 := preload("res://tests/test_save_v7.gd")
## 11판 대원 키(설계 §3.2, 글자 그대로 — 상수와 견주지 않는다).
const KEYS_V11 := ["class", "equip", "exp", "hp", "id", "level", "look", "name", "row", "skills", "tp"]

const V10_TOWN := '{"format":"sqfangame-save","generation":101,"rules":"m3o","saved_at":"2026-10-28T10:11:12Z","schema":10,"state":{"battle":null,"consumables":{"use.medica":3},"day":3,"encounter":{"danger":0,"pending":false,"threshold":173},"floor":"b1f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"foes":{"f1":{"at":[15,9],"day":0,"dir":1,"facing":"E","path_i":3,"state":"patrol","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:10:2","h:10:3","h:11:13","h:11:14","h:11:2","h:11:3","h:12:14","h:12:2","h:13:4","h:14:4","h:15:4","h:16:18","h:16:4","h:17:1","h:17:18","h:17:4","h:6:15","h:7:15","h:8:15","h:8:2","h:9:2","h:9:3","v:12:10","v:12:11","v:12:12","v:12:3","v:12:4","v:12:5","v:12:6","v:12:7","v:12:8","v:12:9","v:13:10","v:13:11","v:13:12","v:13:13","v:13:2","v:13:4","v:13:5","v:13:6","v:13:7","v:13:8","v:13:9","v:16:10","v:16:11","v:16:12","v:16:4","v:16:5","v:16:6","v:16:7","v:16:8","v:16:9","v:17:10","v:17:11","v:17:12","v:17:4","v:17:5","v:17:6","v:17:7","v:17:8","v:17:9","v:18:1","v:18:17","v:18:2","v:18:3","v:6:13","v:6:14","v:8:10","v:8:11","v:8:3","v:8:4","v:8:5","v:8:6","v:8:7","v:8:8","v:8:9","v:9:10","v:9:11","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7","v:9:8","v:9:9"],"edges":{"h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:14":"wall","h:12:2":"wall","h:13:4":"wall","h:14:4":"wall","h:15:4":"wall","h:16:18":"wall","h:16:4":"door","h:17:1":"wall","h:17:18":"wall","h:17:4":"wall","h:6:15":"wall","h:7:15":"wall","h:8:15":"wall","h:8:2":"wall","h:9:2":"wall","h:9:3":"wall","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"door","v:13:2":"door","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:8:10":"wall","v:8:11":"wall","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"floors":{"10:13":0,"10:2":0,"11:13":0,"11:2":0,"12:10":0,"12:11":0,"12:12":0,"12:13":0,"12:2":0,"12:3":0,"12:4":0,"12:5":0,"12:6":0,"12:7":0,"12:8":0,"12:9":0,"13:3":0,"14:3":0,"15:3":0,"16:10":0,"16:11":0,"16:12":0,"16:13":0,"16:14":0,"16:15":0,"16:16":0,"16:17":0,"16:3":0,"16:4":0,"16:5":0,"16:6":0,"16:7":0,"16:8":0,"16:9":0,"17:1":0,"17:17":0,"17:2":0,"17:3":0,"6:13":0,"6:14":0,"7:13":0,"7:14":0,"8:10":0,"8:11":0,"8:12":0,"8:13":0,"8:14":0,"8:2":0,"8:3":0,"8:4":0,"8:5":0,"8:6":0,"8:7":0,"8:8":0,"8:9":0,"9:13":0,"9:2":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:13":"open","h:10:14":"open","h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:10":"open","h:12:11":"open","h:12:12":"open","h:12:13":"open","h:12:14":"wall","h:12:2":"wall","h:12:3":"open","h:12:4":"open","h:12:5":"oneway","h:12:6":"open","h:12:7":"open","h:12:8":"open","h:12:9":"open","h:13:3":"open","h:13:4":"wall","h:14:3":"open","h:14:4":"wall","h:15:3":"open","h:15:4":"wall","h:16:10":"open","h:16:11":"open","h:16:12":"open","h:16:13":"open","h:16:14":"open","h:16:15":"open","h:16:16":"open","h:16:17":"open","h:16:18":"wall","h:16:3":"open","h:16:4":"door","h:16:5":"open","h:16:6":"open","h:16:7":"open","h:16:8":"open","h:16:9":"open","h:17:1":"wall","h:17:17":"open","h:17:18":"wall","h:17:2":"open","h:17:3":"open","h:17:4":"wall","h:6:13":"open","h:6:14":"open","h:6:15":"wall","h:7:13":"open","h:7:14":"open","h:7:15":"wall","h:8:10":"open","h:8:11":"open","h:8:12":"open","h:8:13":"open","h:8:14":"open","h:8:15":"wall","h:8:2":"wall","h:8:3":"open","h:8:4":"open","h:8:5":"oneway","h:8:6":"open","h:8:7":"open","h:8:8":"open","h:8:9":"oneway","h:9:13":"open","h:9:14":"open","h:9:2":"wall","h:9:3":"wall","v:10:13":"open","v:10:2":"open","v:11:13":"oneway","v:11:2":"open","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:13":"open","v:12:2":"open","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"shortcut","v:13:2":"door","v:13:3":"open","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:14:3":"open","v:15:3":"open","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:13":"open","v:16:14":"open","v:16:15":"open","v:16:16":"open","v:16:17":"open","v:16:3":"open","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:1":"open","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:13":"open","v:17:14":"open","v:17:15":"open","v:17:16":"open","v:17:17":"open","v:17:2":"open","v:17:3":"open","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:7:13":"open","v:7:14":"open","v:8:10":"wall","v:8:11":"wall","v:8:12":"open","v:8:13":"open","v:8:14":"open","v:8:2":"open","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:12":"open","v:9:13":"open","v:9:14":"open","v:9:2":"open","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"visited":["10:13","10:2","11:13","11:2","12:10","12:11","12:12","12:13","12:2","12:3","12:4","12:5","12:6","12:7","12:8","12:9","13:3","14:3","15:3","16:10","16:11","16:12","16:13","16:14","16:15","16:16","16:17","16:3","16:4","16:5","16:6","16:7","16:8","16:9","17:1","17:17","17:2","17:3","6:13","6:14","7:13","7:14","8:10","8:11","8:12","8:13","8:14","8:2","8:3","8:4","8:5","8:6","8:7","8:8","8:9","9:13","9:2"]},"world":{"chests_opened":["c1"],"foes":{"f2":{"at":[5,10],"day":0,"dir":1,"facing":"W","path_i":0,"state":"idle","stun":0}},"gather_used":{},"locks_open":["h:16:4"],"passages_found":[],"shortcuts_open":[]}},"b3f":{"annotation":{"auto_edges":["h:10:13","h:10:14","h:10:17","h:10:18","h:11:14","h:11:17","h:11:18","h:12:17","h:12:18","h:13:19","h:14:19","h:15:19","h:16:19","h:17:19","h:1:13","h:4:8","h:4:9","h:6:8","h:6:9","h:7:10","h:7:18","h:7:8","h:7:9","h:8:17","h:8:18","h:9:14","h:9:17","h:9:18","h:9:8","v:10:12","v:11:12","v:12:10","v:12:12","v:13:18","v:18:18","v:1:10","v:1:11","v:1:12","v:1:8","v:1:9","v:7:14","v:7:15","v:7:16","v:7:17","v:8:13","v:8:14","v:8:15","v:8:16","v:9:13"],"edges":{"h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:19":"wall","h:14:19":"wall","h:15:19":"wall","h:16:19":"wall","h:17:19":"wall","h:1:13":"wall","h:4:8":"wall","h:4:9":"wall","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:17":"wall","h:8:18":"wall","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","v:10:12":"wall","v:11:12":"wall","v:12:10":"wall","v:12:12":"wall","v:13:18":"wall","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:9:13":"wall"},"floors":{"10:10":0,"10:13":0,"10:17":0,"11:10":0,"11:11":0,"11:12":0,"11:13":0,"11:17":0,"12:17":0,"13:17":0,"13:18":0,"14:18":0,"15:18":0,"16:18":0,"17:18":0,"1:10":0,"1:11":0,"1:12":0,"1:8":0,"1:9":0,"2:8":0,"3:8":0,"4:8":0,"5:8":0,"6:8":0,"7:10":0,"7:11":0,"7:12":0,"7:13":0,"7:14":0,"7:15":0,"7:16":0,"7:17":0,"7:8":0,"8:10":0,"8:17":0,"8:8":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:17":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:10":"open","h:10:11":"open","h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:10":"open","h:11:11":"open","h:11:12":"open","h:11:13":"open","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:17":"open","h:13:18":"open","h:13:19":"wall","h:14:18":"open","h:14:19":"wall","h:15:18":"open","h:15:19":"wall","h:16:18":"open","h:16:19":"wall","h:17:18":"open","h:17:19":"wall","h:1:10":"open","h:1:11":"open","h:1:12":"open","h:1:13":"wall","h:1:8":"open","h:1:9":"open","h:2:8":"open","h:2:9":"open","h:3:8":"open","h:3:9":"open","h:4:8":"wall","h:4:9":"wall","h:5:8":"open","h:5:9":"open","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:11":"open","h:7:12":"open","h:7:13":"open","h:7:14":"open","h:7:15":"open","h:7:16":"open","h:7:17":"open","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:10":"open","h:8:11":"open","h:8:17":"wall","h:8:18":"wall","h:8:8":"open","h:8:9":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","h:9:9":"open","v:10:10":"open","v:10:11":"open","v:10:12":"wall","v:10:13":"open","v:10:17":"open","v:10:8":"open","v:10:9":"open","v:11:10":"open","v:11:11":"open","v:11:12":"wall","v:11:13":"open","v:11:17":"open","v:12:10":"wall","v:12:11":"open","v:12:12":"wall","v:12:13":"open","v:12:17":"open","v:13:17":"open","v:13:18":"wall","v:14:17":"open","v:14:18":"open","v:15:18":"open","v:16:18":"open","v:17:18":"open","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:2:10":"open","v:2:11":"open","v:2:12":"open","v:2:8":"open","v:2:9":"open","v:3:8":"open","v:4:8":"open","v:5:8":"open","v:6:8":"open","v:7:10":"open","v:7:11":"open","v:7:12":"open","v:7:13":"open","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:7:8":"open","v:8:10":"open","v:8:11":"open","v:8:12":"open","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:8:17":"open","v:8:8":"open","v:9:10":"open","v:9:11":"open","v:9:12":"open","v:9:13":"wall","v:9:17":"open","v:9:8":"open","v:9:9":"open"},"visited":["10:10","10:13","10:17","11:10","11:11","11:12","11:13","11:17","12:17","13:17","13:18","14:18","15:18","16:18","17:18","1:10","1:11","1:12","1:8","1:9","2:8","3:8","4:8","5:8","6:8","7:10","7:11","7:12","7:13","7:14","7:15","7:16","7:17","7:8","8:10","8:17","8:8","9:10","9:11","9:12","9:13","9:17","9:8","9:9"]},"world":{"chests_opened":["c1"],"foes":{"f3":{"at":[16,3],"day":0,"dir":1,"facing":"N","path_i":0,"state":"idle","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":1},"key_items":["key.moss_card","key.relay_fuse"],"location":"town","materials":{"item.neon_rat_tail":4,"item.scrap_wire":2},"money":480,"party":{"at":[9,18],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":57,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.ion_saber","equip.padded_coat","equip.grip_gloves",null],"exp":400,"hp":59,"id":"blade_duelist","level":4,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":35},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":49,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":39,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":400,"hp":44,"id":"glyph_wizard","level":4,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.glyph_mastery":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":70}]},"rng":{"state":"-5760575937976465522"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":116,"wiped":false}}'

const V10_BATTLE := '{"format":"sqfangame-save","generation":102,"rules":"m3o","saved_at":"2026-10-28T13:14:15Z","schema":10,"state":{"battle":{"enemies":[{"ailment":{"id":"sleep","turns":2},"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":132,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78,"kill":null,"resist":{}}],"formation":"formation.b2.beetles","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{"arm":2},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{"arm":2},"buffs":[],"debuffs":[],"resist":{"arm":300}},{"ailment":{"damage":6,"id":"poison","turns":2},"binds":{},"buffs":[],"debuffs":[],"resist":{"poison":300}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":1},"consumables":{"use.theriaca_a":2},"day":2,"encounter":{"danger":199,"pending":true,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"foes":{"f1":{"at":[15,9],"day":0,"dir":1,"facing":"E","path_i":3,"state":"patrol","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"foes":{"f2":{"at":[5,10],"day":0,"dir":1,"facing":"W","path_i":0,"state":"idle","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"W","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":28},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":33,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":28},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":36,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":55}]},"rng":{"state":"5648613292483269925"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":false}}'

const V10_CONTACT := '{"format":"sqfangame-save","generation":103,"rules":"m3o","saved_at":"2026-10-28T16:17:18Z","schema":10,"state":{"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":600,"kill":null,"resist":{}}],"foe":"f1","formation":"formation.foe.ether_ram","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"consumables":{},"day":5,"encounter":{"danger":0,"pending":true,"threshold":176},"floor":"b1f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:9:19"],"edges":{"h:9:19":"wall"},"floors":{"9:17":0,"9:18":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:9:17":"open","h:9:18":"open","h:9:19":"wall","v:10:17":"open","v:10:18":"open","v:9:17":"open","v:9:18":"open"},"visited":["9:17","9:18"]},"world":{"chests_opened":[],"foes":{"f1":{"at":[13,9],"day":0,"dir":1,"facing":"E","path_i":1,"state":"battle","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{},"money":200,"party":{"at":[9,17],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-7335808875235361152"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":1,"wiped":false}}'

const V10_WIPED := '{"format":"sqfangame-save","generation":104,"rules":"m3o","saved_at":"2026-10-28T19:20:21Z","schema":10,"state":{"battle":null,"consumables":{},"day":4,"encounter":{"danger":50,"pending":false,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"foes":{"f1":{"at":[15,9],"day":0,"dir":1,"facing":"E","path_i":3,"state":"patrol","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"foes":{"f2":{"at":[5,10],"day":0,"dir":1,"facing":"W","path_i":0,"state":"idle","stun":0}},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"S","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":0,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":0,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":0,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-448129683613041646"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":true}}'

const V10_TEST := '{"format":"sqfangame-save","generation":105,"rules":"m3o","saved_at":"2026-10-28T22:23:24Z","schema":10,"state":{"battle":null,"consumables":{},"day":6,"encounter":{"danger":0,"pending":false,"threshold":211},"floor":"f1_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["h:2:16"],"edges":{"h:2:16":"door"},"floors":{"2:16":0,"2:17":0,"2:18":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:3:16":"open","v:3:17":"open","v:3:18":"open"},"visited":["2:16","2:17","2:18"]},"world":{"chests_opened":[],"foes":{},"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":2},"key_items":[],"location":"labyrinth","materials":{},"money":700,"party":{"at":[2,16],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-3369913521587883864"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":2,"wiped":false}}'

static var _real: GameDefs
static var _texts: TextDb


func _defs() -> GameDefs:
	if _real == null:
		_texts = TextDb.load_path("res://data/text/ko.json")
		var r := GameDefs.load_paths(Fx.LABYRINTH_PATH, Fx.PARTY_PATH, "res://data", _texts)
		check(r.ok(), "실제 묶음 읽기 %s" % str(r.errors))
		_real = r.defs
	return _real


## 마을: 위저드(r1, 외형 1)·메딕(r2) 등록, 기본 홀로나이트 이름 바꾸기, 편성 전열 [r1, 홀로나이트] · 후열 [나노 메딕, 글리프 위저드].
func _guild_town() -> ExplorationState:
	var s := ExplorationRules.new_game(_defs(), 9, "full", true)
	GuildRules.register(s, "class.glyph_wizard", 1, "위저드2")
	GuildRules.register(s, "class.nano_medic", 0, "메딕")
	GuildRules.rename(s, "holo_knight", "기사단장")
	var ev := GuildRules.form(s, ["r1", "holo_knight"], ["nano_medic", "glyph_wizard"])
	assert(ev[0]["type"] == "formed", str(ev))
	return s


func _roundtrip(s: ExplorationState, label: String) -> SaveCodec.LoadResult:
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok(), "%s: 읽기 %s" % [label, r.error])
	if r.ok():
		check_eq([SaveCodec.state_hash(r.state), r.from_schema], [SaveCodec.state_hash(s), 12], "%s: 같은 해시, 12판" % label)
	return r


func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])


func _pm(d: Dictionary) -> Array:
	return d["state"]["party"]["members"]


func _gm(d: Dictionary) -> Array:
	return d["state"]["guild"]["members"]


## S1 (M-S1 쓰기가 look 을 빠뜨림, M-S2 읽기가 열을 정의 칸에서 가져옴): 마을 편성·이름·등록 뒤의 11판 문서 모양과 왕복.
func test_v11_roundtrip_guild() -> void:
	var s := _guild_town()
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["schema"], doc["rules"]], [12.0, "m3q"], "12판 머리")
	for list in [_pm(doc), _gm(doc)]:
		for m in list:
			var ks: Array = m.keys()
			ks.sort()
			check_eq(ks, KEYS_V11, "%s: 대원 키 열하나" % m["id"])
	var p := _pm(doc)
	check_eq(p.map(func(m: Dictionary) -> Array: return [m["id"], m["name"], m["class"], m["look"], m["row"]]), [
		["r1", "위저드2", "class.glyph_wizard", 1.0, "front"], ["holo_knight", "기사단장", "class.holo_knight", 0.0, "front"],
		["nano_medic", null, "class.nano_medic", 0.0, "back"], ["glyph_wizard", null, "class.glyph_wizard", 0.0, "back"]], "파티 넷: ID·이름·직업·외형·열")
	check_eq([doc["state"]["guild"]["serial"], _gm(doc).map(func(m: Dictionary) -> String: return m["id"])], [2.0, ["blade_duelist", "blade_duelist_2", "r2"]],
		"길드: 번호 2, 파티 밖 셋(명부 차례)")
	check_eq([_gm(doc)[0]["row"], _gm(doc)[2]["name"], _gm(doc)[2]["row"]], ["front", "메딕", "front"], "길드 대원의 열·이름")
	var r := _roundtrip(s, "마을 길드")
	if r.ok():
		var n := r.state
		check_eq([n.party.members[0].look, n.party.members[0].name, n.party.members[1].name, n.party.members[1].name_key, n.party.members[2].row],
			[1, "위저드2", "기사단장", "member.holo_knight", "back"], "읽은 외형·이름·이름 키·열")
		check_eq([n.guild.serial, n.guild.members.map(func(m: PartyState.Member) -> String: return m.id)], [2, ["blade_duelist", "blade_duelist_2", "r2"]], "읽은 길드")
		check_eq(GuildRules.register(n, "class.nano_medic", 0, "셋째")[0]["id"], "r3", "읽은 뒤 다음 번호 r3")


## S1b: 칸 0 이 새 대원인 파티의 전투 중 저장(한 턴 뒤) 왕복. 전투 유닛 이름·열.
func test_v11_battle_save_with_recruit() -> void:
	var s := _guild_town()
	ExplorationRules.apply(s, ExplorationRules.Action.ENTER, "full")
	s.encounter.danger = s.encounter.threshold
	BattleRules.start(s, BattleRules.pick_formation(s))
	BattleRules.submit(s, BattlePolicy.choose(s, "default"))
	check(s.battle != null, "준비: 한 턴 뒤에도 전투 중")
	if s.battle == null:
		return
	var r := _roundtrip(s, "전투 중")
	if r.ok() and r.state.battle != null:
		var b := r.state.battle
		check_eq([b.party.size(), b.party[0].name, b.party[0].row, b.party[2].row, b.party[0].def_id], [4, "위저드2", "front", "back", "r1"], "읽은 전투 유닛")


## S1c (M-G16 쓰기가 옛 열을 남김): 미궁에서 대열을 바꾼 뒤 저장·읽기하면 새 차례·열.
func test_v11_arrange_roundtrip() -> void:
	var s := ExplorationRules.new_game(_defs(), 9, "full")
	var ev := GuildRules.arrange(s, ["nano_medic"], ["holo_knight", "blade_duelist", "blade_duelist_2"] + ["glyph_wizard"].slice(0, 0))
	check_eq(ev[0]["reason"] if ev[0]["type"] == "rejected" else "", "not_party", "준비: 넷만 적으면 not_party")
	ev = GuildRules.arrange(s, ["nano_medic", "glyph_wizard"], ["holo_knight", "blade_duelist", "blade_duelist_2"])
	check_eq(ev[0]["type"], "arranged", "대열 바꿈")
	var r := _roundtrip(s, "대열 뒤")
	if r.ok():
		check_eq([r.state.party.members.map(func(m: PartyState.Member) -> String: return m.id), r.state.party.members.map(func(m: PartyState.Member) -> String: return m.row)],
			[["nano_medic", "glyph_wizard", "holo_knight", "blade_duelist", "blade_duelist_2"], ["front", "front", "back", "back", "back"]], "읽은 차례·열")


## S2 (M-S3 열 차례를 보지 않음, M-S4 새 대원의 이름 null 을 받음): 11판 엄격 검사.
func test_v11_rejects() -> void:
	var s := _guild_town()
	_reject(s, func(d): _pm(d).clear(), "party.members 가 1~5명", "파티 0명")
	_reject(s, func(d): _pm(d).append(_gm(d)[0].duplicate(true)); _pm(d).append(_gm(d)[1].duplicate(true)), "party.members 가 1~5명", "파티 여섯")
	_reject(s, func(d): _pm(d).reverse(), "전열 대원이 후열 대원 뒤에 있다", "후열이 전열 앞")
	_reject(s, func(d): _gm(d)[0]["id"] = "holo_knight", "명부에 둘 있다", "ID 겹침")
	_reject(s, func(d): _pm(d)[0]["class"] = "class.nope", "class 가 없는 직업", "모르는 직업")
	_reject(s, func(d): _pm(d)[0]["look"] = 2, "look 이 정수 0~1", "외형 2")
	_reject(s, func(d): _pm(d)[0]["look"] = true, "look 이 정수 0~1", "외형 true")
	_reject(s, func(d): _pm(d)[0]["row"] = "middle", "row 가 front·back", "열 middle")
	_reject(s, func(d): _pm(d)[0]["name"] = null, "등록한 대원은 이름이 있어야 한다", "새 대원 이름 null")
	_reject(s, func(d): _pm(d)[0]["name"] = "a  b", "이름 규칙", "이름 공백 둘")
	_reject(s, func(d): _pm(d)[0]["name"] = "가나다라마바사아자", "이름 규칙", "이름 아홉 자")
	_reject(s, func(d): _gm(d)[2]["name"] = "위저드2", "명부에 둘 있다", "이름 겹침")
	_reject(s, func(d): _gm(d)[2]["id"] = "r9", "r1~r2", "번호 밖 ID")
	_reject(s, func(d): _gm(d)[2]["id"] = "r01", "r1~r2", "0 으로 시작하는 번호")
	_reject(s, func(d): _gm(d)[2]["id"] = "rogue", "r1~r2", "기본도 새 대원도 아닌 ID")
	# 번호는 r 뒤 ASCII 숫자(부호·앞 0·소수점·공백 없음). r+2 는 is_valid_int 로 2 가 되지만 register 가 만들 수 없는 꼴이다(M-G17).
	for bad_id in ["r+2", "r+02", "r-2", "r2.0", "r 2", "r0"]:
		_reject(s, func(d): _gm(d)[2]["id"] = bad_id, "r1~r2", "꼴이 아닌 ID %s" % bad_id)
	_reject(s, func(d): d["state"]["guild"]["serial"] = 1, "r1~r1", "번호가 r2 보다 작다")
	for v in [-1, 10000, 1.5, true, "2"]:
		_reject(s, func(d): d["state"]["guild"]["serial"] = v, "guild.serial", "serial %s" % str(v))
	_reject(s, func(d): d["state"]["guild"]["x"] = 1, "guild.x 는 모르는 필드다", "guild 모르는 키")
	_reject(s, func(d): d["state"].erase("guild"), "guild 가 객체가 아니다", "guild 없음")
	_reject(s, func(d): _pm(d)[0].erase("row"), "party.members[0].row 가 없다", "대원 키 없음")
	_reject(s, func(d): _gm(d)[0]["x"] = 1, "guild.members[0].x 는 모르는 필드다", "길드 대원 모르는 키")
	_reject(s, func(d): _pm(d)[0]["class"] = "class.holo_knight", "party.members[0].equip", "직업을 바꾸면 그 직업의 장착 규칙으로 본다(스태프)")
	var front4 := func(d: Dictionary) -> void:
		var g: Dictionary = _gm(d)[0]
		_pm(d).insert(0, g.duplicate(true))
		_gm(d).remove_at(0)
		for m in _pm(d):
			m["row"] = "front" if _pm(d).find(m) < 4 else "back"
	_reject(s, front4, "front 열이 3명을 넘는다", "전열 넷")
	var crowd := ExplorationRules.new_game(_defs(), 9, "full", true)
	for i in 25:
		GuildRules.register(crowd, "class.nano_medic", 0, "대원%d" % i)
	_reject(crowd, func(d): _gm(d).append(_gm(d)[0].duplicate(true)); _gm(d)[-1]["id"] = "r26"; _gm(d)[-1]["name"] = "넘침"; d["state"]["guild"]["serial"] = 26,
		"30명을 넘는다", "명부 31명")


## S3 (M-S5 migrate_v10 이 칸 i+1 의 직업을 채움): HEAD 로 만든 10판 고정 문서 → 11판. 원래 필드는 모두 그대로, 더한 길드 값은 칸 i 의 기본값.
func test_fixed_v10_strings_migrate() -> void:
	for x in [["10판 마을", V10_TOWN, Fx.arbor(), "town"], ["10판 전투", V10_BATTLE, Fx.arbor(), "labyrinth"], ["10판 접촉", V10_CONTACT, Fx.arbor(), "labyrinth"],
			["10판 전멸", V10_WIPED, Fx.arbor(), "labyrinth"], ["10판 시험 층", V10_TEST, Fx.defs(), "labyrinth"]]:
		var orig: Dictionary = JSON.parse_string(x[1])
		var r := SaveCodec.decode(x[1], x[2])
		check(r.ok(), "%s: 읽기 %s" % [x[0], r.error])
		if not r.ok():
			continue
		check_eq([r.from_schema, r.relocated, r.saved_at, r.generation, r.state.location], [10, false, orig["saved_at"], int(orig["generation"]), x[3]],
			"%s: 10판·옮김 없음·saved_at·generation·장소" % x[0])
		var sv := Fx.strip_v11(SaveCodec.state_to_dict(r.state), x[2])
		check_eq(sv["bad"], "", "%s: 더한 길드 값은 칸 i 의 기본값" % x[0])
		var now: Dictionary = sv["state"]
		var o: Dictionary = orig["state"]
		for k in o:
			check_eq(V7._norm(now[k]), V7._norm(o[k]), "%s: %s 보존" % [x[0], k])
		check_eq(now.keys().filter(func(k: String) -> bool: return not o.has(k)), [], "%s: 맨 위에 더한 필드는 guild 뿐(뺀 뒤 없음)" % x[0])
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
		var again := SaveCodec.decode(JSON.stringify(doc), x[2])
		check(doc["schema"] == 12.0 and again.ok() and again.from_schema == 12 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state),
			"%s: 12판으로 쓰고 다시 읽기 같은 해시 %s" % [x[0], again.error])
	var town := SaveCodec.decode(V10_TOWN, Fx.arbor()).state
	if town != null:
		check_eq([town.party.members[1].equip[0], town.party.members[1].class_id, town.party.members[4].skills.has("skill.glyph_wizard.glyph_mastery"),
			town.party.members[1].level > 1, town.gear_bag.has("equip.twin_edge")], ["equip.ion_saber", "class.blade_duelist", true, true, true], "10판 마을: 성장·장비 그대로")
	var bat := SaveCodec.decode(V10_BATTLE, Fx.arbor()).state
	if bat != null and bat.battle != null:
		check_eq([bat.battle.enemies[0].ailment, bat.battle.party[1].binds, bat.battle.party[3].row], ["sleep", {"arm": 2}, "back"], "10판 전투: 수면·팔 봉인·열")
	var con := SaveCodec.decode(V10_CONTACT, Fx.arbor()).state
	if con != null and con.battle != null:
		check_eq([con.battle.foe, con.world.foes["f1"].state], ["f1", "battle"], "10판 접촉 전투 그대로")
	var rel := SaveCodec.decode(V10_TEST, Fx.arbor())
	check(rel.ok() and rel.relocated and rel.from_schema == 10, "10판 시험 층을 게임 묶음으로: 옮겨 읽음 %s" % rel.error)


## S3b: 10판 머리에 11판 대원 키가 있으면 10판 규칙으로 거부(「10판 검사 실패」).
func test_v10_rules_apply_to_v10() -> void:
	var s := ExplorationRules.new_game(_defs(), 9, "full", true)
	_reject(s, func(d): d.merge({"schema": 10, "rules": "m3o"}, true), "10판 검사 실패: party.members[0].class 는 모르는 필드다", "10판에 11판 대원(키 차례상 class 먼저)")
	var v10_guild := func(d: Dictionary) -> void:
		d.merge({"schema": 10, "rules": "m3o"}, true)
		for m in _pm(d):
			for k in ["name", "class", "look", "row"]:
				m.erase(k)
	var r := SaveCodec.decode(JSON.stringify(_with(s, v10_guild)), s.defs)
	check(r.ok() and r.from_schema == 10, "10판: 남은 맨 위 guild 는 보지 않는다(10판은 그 키를 읽지 않음) %s" % r.error)
	_reject(s, func(d): d["schema"] = 13, "지원하지 않는 schema 다", "13판")
	_reject(s, func(d): d["rules"] = "m3o", "규칙 판(rules)이 schema 12 와 맞지 않다", "12판 머리에 m3o")


func _with(s: ExplorationState, mutate: Callable) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	return doc


## S4 (M-S6 옮기기가 길드를 버림): 시험 묶음의 11판 저장을 게임 묶음으로 읽어 옮겨도 길드(대기 대원·장비·번호)는 그대로다.
## 대기 대원만 있는 저장(r1 대기, r2 지움 → serial 2)과 r1 이 파티 칸 0 에 있는 저장 둘 다. 옮긴 뒤 다시 쓰고 읽으면 옮김 없이 같은 해시.
func test_v11_relocation_keeps_guild() -> void:
	var defs := Fx.arbor()
	check(defs != null and defs.retired != null, "arbor 와 은퇴한 묶음")
	if defs == null or defs.retired == null:
		return
	var reserve := ExplorationRules.new_game(Fx.defs(), 9, "full", true)
	check_eq([GuildRules.register(reserve, "class.glyph_wizard", 1, "위저드2")[0]["type"], GuildRules.register(reserve, "class.nano_medic", 0, "메딕")[0]["type"],
		GuildRules.remove(reserve, "r2")[0]["type"]], ["registered", "registered", "removed"], "준비: r1 대기, r2 지움")
	reserve.guild.members[0].hp = 3
	var active := ExplorationRules.new_game(Fx.defs(), 9, "full", true)
	GuildRules.register(active, "class.glyph_wizard", 1, "위저드2")
	check_eq(GuildRules.form(active, ["r1", "holo_knight"], ["nano_medic", "glyph_wizard"])[0]["type"], "formed", "준비: r1 이 칸 0")
	for x in [["대기 r1", reserve, 2], ["파티 칸 0 의 r1", active, 1]]:
		var s: ExplorationState = x[1]
		var text := SaveCodec.encode(s, "2026-10-28T09:00:00Z", 70)
		var r := SaveCodec.decode(text, defs)
		check(r.ok() and r.relocated, "%s: 게임 묶음으로 옮겨 읽음 %s" % [x[0], r.error])
		if not r.ok():
			continue
		var od := SaveCodec.state_to_dict(s)
		var nd := SaveCodec.state_to_dict(r.state)
		check_eq([nd["guild"]["serial"], nd["guild"]["members"].size()], [x[2], od["guild"]["members"].size()], "%s: 번호·길드 수 그대로" % x[0])
		check_eq(nd["guild"], od["guild"], "%s: 길드(대원·장비·HP·번호) 그대로" % x[0])
		check_eq(nd["party"]["members"], od["party"]["members"], "%s: 파티 차례·열·이름 그대로" % x[0])
		var again := SaveCodec.decode(SaveCodec.encode(r.state), defs)
		check(again.ok() and not again.relocated and again.from_schema == 12 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state),
			"%s: 다시 쓰고 읽으면 옮김 없이 같은 해시 %s" % [x[0], again.error])
	var rr := SaveCodec.decode(SaveCodec.encode(reserve), defs)
	check(rr.ok() and rr.state.guild.members.size() == 1 and rr.state.guild.members[0].equip == reserve.guild.members[0].equip and rr.state.guild.members[0].hp == 3,
		"대기 r1: 장비·HP 를 가진 채 옮김")
