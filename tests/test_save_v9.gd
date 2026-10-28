## 저장 9판(M3 A5 설계 §3·§7.3): 층 기록 world 의 gather_used(오늘 쓴 채집 횟수) 왕복·검사, 8판 고정 문서 넷 → 9판, 1~7판도 9판으로,
## 시험 층 8판 저장 옮기기(채집 기록은 빈 채로 시작), 8판 .bak 되살림, 자료를 고쳐 횟수가 줄어도 읽힘. 시험마다 죽이는 변이(M-S…)를 적는다.
##
## 고정 문서 넷은 HEAD 725d8ed 코드(A5 편집 전 깨끗한 작업 트리)로 저장소 밖 생성기(/tmp/sqf_a5/gen_v8.gd)가 만들었다:
##   cd /tmp && godot --headless --path <저장소> -s /tmp/sqf_a5/gen_v8.gd
## 생성기는 Fx.arbor() 새 게임(시드 31)으로 arbor_route.json 공략을 걷고(전투는 승리), V8_TEST 는 시험 묶음 새 게임(시드 7)이다.
## SaveCodec.encode(saved_at, generation 91~94)로 쓴 뒤 같은 HEAD 코드로 다시 읽어 from_schema 8·옮김 없음을 확인했다(V8_TEST 는 게임 묶음으로
## 읽으면 옮겨진다). 문서를 바꾸지 말 것(8판 이전 길의 기준이다).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const V7 := preload("res://tests/test_save_v7.gd")
const V8 := preload("res://tests/test_save_v8.gd")
const BS := preload("res://tests/test_battle_save.gd")
const GS := preload("res://tests/test_growth_save.gd")
const V5 := preload("res://tests/test_save_v5.gd")
const V6 := preload("res://tests/test_save_v6.gd")
const TG := preload("res://tests/test_gather.gd")
const A := ExplorationRules.Action

## 8판 마을: 공략 124 행동 뒤 마을(B1F 시작 칸), 열쇠 둘·세 층 기록·메모 둘, 3일째, 소지금 480·소재 둘·가방 장비 하나·소모품 둘(메디카 3·비콘 1)·상점.
const V8_TOWN := '{"format":"sqfangame-save","generation":91,"rules":"m3i","saved_at":"2026-10-28T10:11:12Z","schema":8,"state":{"battle":null,"consumables":{"use.ariadne_beacon":1,"use.medica":3},"day":3,"encounter":{"danger":0,"pending":false,"threshold":173},"floor":"b1f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{"9:18":"입구"}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:10:2","h:10:3","h:11:13","h:11:14","h:11:2","h:11:3","h:12:14","h:12:2","h:13:4","h:14:4","h:15:4","h:16:18","h:16:4","h:17:1","h:17:18","h:17:4","h:6:15","h:7:15","h:8:15","h:8:2","h:9:2","h:9:3","v:12:10","v:12:11","v:12:12","v:12:3","v:12:4","v:12:5","v:12:6","v:12:7","v:12:8","v:12:9","v:13:10","v:13:11","v:13:12","v:13:13","v:13:2","v:13:4","v:13:5","v:13:6","v:13:7","v:13:8","v:13:9","v:16:10","v:16:11","v:16:12","v:16:4","v:16:5","v:16:6","v:16:7","v:16:8","v:16:9","v:17:10","v:17:11","v:17:12","v:17:4","v:17:5","v:17:6","v:17:7","v:17:8","v:17:9","v:18:1","v:18:17","v:18:2","v:18:3","v:6:13","v:6:14","v:8:10","v:8:11","v:8:3","v:8:4","v:8:5","v:8:6","v:8:7","v:8:8","v:8:9","v:9:10","v:9:11","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7","v:9:8","v:9:9"],"edges":{"h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:14":"wall","h:12:2":"wall","h:13:4":"wall","h:14:4":"wall","h:15:4":"wall","h:16:18":"wall","h:16:4":"door","h:17:1":"wall","h:17:18":"wall","h:17:4":"wall","h:6:15":"wall","h:7:15":"wall","h:8:15":"wall","h:8:2":"wall","h:9:2":"wall","h:9:3":"wall","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"door","v:13:2":"door","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:8:10":"wall","v:8:11":"wall","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"floors":{"10:13":0,"10:2":0,"11:13":0,"11:2":0,"12:10":0,"12:11":0,"12:12":0,"12:13":0,"12:2":0,"12:3":0,"12:4":0,"12:5":0,"12:6":0,"12:7":0,"12:8":0,"12:9":0,"13:3":0,"14:3":0,"15:3":0,"16:10":0,"16:11":0,"16:12":0,"16:13":0,"16:14":0,"16:15":0,"16:16":0,"16:17":0,"16:3":0,"16:4":0,"16:5":0,"16:6":0,"16:7":0,"16:8":0,"16:9":0,"17:1":0,"17:17":0,"17:2":0,"17:3":0,"6:13":0,"6:14":0,"7:13":0,"7:14":0,"8:10":0,"8:11":0,"8:12":0,"8:13":0,"8:14":0,"8:2":0,"8:3":0,"8:4":0,"8:5":0,"8:6":0,"8:7":0,"8:8":0,"8:9":0,"9:13":0,"9:2":0},"icons":{},"memos":{"1:1":"문 앞"}},"knowledge":{"edges":{"h:10:13":"open","h:10:14":"open","h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:10":"open","h:12:11":"open","h:12:12":"open","h:12:13":"open","h:12:14":"wall","h:12:2":"wall","h:12:3":"open","h:12:4":"open","h:12:5":"oneway","h:12:6":"open","h:12:7":"open","h:12:8":"open","h:12:9":"open","h:13:3":"open","h:13:4":"wall","h:14:3":"open","h:14:4":"wall","h:15:3":"open","h:15:4":"wall","h:16:10":"open","h:16:11":"open","h:16:12":"open","h:16:13":"open","h:16:14":"open","h:16:15":"open","h:16:16":"open","h:16:17":"open","h:16:18":"wall","h:16:3":"open","h:16:4":"door","h:16:5":"open","h:16:6":"open","h:16:7":"open","h:16:8":"open","h:16:9":"open","h:17:1":"wall","h:17:17":"open","h:17:18":"wall","h:17:2":"open","h:17:3":"open","h:17:4":"wall","h:6:13":"open","h:6:14":"open","h:6:15":"wall","h:7:13":"open","h:7:14":"open","h:7:15":"wall","h:8:10":"open","h:8:11":"open","h:8:12":"open","h:8:13":"open","h:8:14":"open","h:8:15":"wall","h:8:2":"wall","h:8:3":"open","h:8:4":"open","h:8:5":"oneway","h:8:6":"open","h:8:7":"open","h:8:8":"open","h:8:9":"oneway","h:9:13":"open","h:9:14":"open","h:9:2":"wall","h:9:3":"wall","v:10:13":"open","v:10:2":"open","v:11:13":"oneway","v:11:2":"open","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:13":"open","v:12:2":"open","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"shortcut","v:13:2":"door","v:13:3":"open","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:14:3":"open","v:15:3":"open","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:13":"open","v:16:14":"open","v:16:15":"open","v:16:16":"open","v:16:17":"open","v:16:3":"open","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:1":"open","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:13":"open","v:17:14":"open","v:17:15":"open","v:17:16":"open","v:17:17":"open","v:17:2":"open","v:17:3":"open","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:7:13":"open","v:7:14":"open","v:8:10":"wall","v:8:11":"wall","v:8:12":"open","v:8:13":"open","v:8:14":"open","v:8:2":"open","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:12":"open","v:9:13":"open","v:9:14":"open","v:9:2":"open","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"visited":["10:13","10:2","11:13","11:2","12:10","12:11","12:12","12:13","12:2","12:3","12:4","12:5","12:6","12:7","12:8","12:9","13:3","14:3","15:3","16:10","16:11","16:12","16:13","16:14","16:15","16:16","16:17","16:3","16:4","16:5","16:6","16:7","16:8","16:9","17:1","17:17","17:2","17:3","6:13","6:14","7:13","7:14","8:10","8:11","8:12","8:13","8:14","8:2","8:3","8:4","8:5","8:6","8:7","8:8","8:9","9:13","9:2"]},"world":{"chests_opened":["c1"],"locks_open":["h:16:4"],"passages_found":[],"shortcuts_open":[]}},"b3f":{"annotation":{"auto_edges":["h:10:13","h:10:14","h:10:17","h:10:18","h:11:14","h:11:17","h:11:18","h:12:17","h:12:18","h:13:19","h:14:19","h:15:19","h:16:19","h:17:19","h:1:13","h:4:8","h:4:9","h:6:8","h:6:9","h:7:10","h:7:18","h:7:8","h:7:9","h:8:17","h:8:18","h:9:14","h:9:17","h:9:18","h:9:8","v:10:12","v:11:12","v:12:10","v:12:12","v:13:18","v:18:18","v:1:10","v:1:11","v:1:12","v:1:8","v:1:9","v:7:14","v:7:15","v:7:16","v:7:17","v:8:13","v:8:14","v:8:15","v:8:16","v:9:13"],"edges":{"h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:19":"wall","h:14:19":"wall","h:15:19":"wall","h:16:19":"wall","h:17:19":"wall","h:1:13":"wall","h:4:8":"wall","h:4:9":"wall","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:17":"wall","h:8:18":"wall","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","v:10:12":"wall","v:11:12":"wall","v:12:10":"wall","v:12:12":"wall","v:13:18":"wall","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:9:13":"wall"},"floors":{"10:10":0,"10:13":0,"10:17":0,"11:10":0,"11:11":0,"11:12":0,"11:13":0,"11:17":0,"12:17":0,"13:17":0,"13:18":0,"14:18":0,"15:18":0,"16:18":0,"17:18":0,"1:10":0,"1:11":0,"1:12":0,"1:8":0,"1:9":0,"2:8":0,"3:8":0,"4:8":0,"5:8":0,"6:8":0,"7:10":0,"7:11":0,"7:12":0,"7:13":0,"7:14":0,"7:15":0,"7:16":0,"7:17":0,"7:8":0,"8:10":0,"8:17":0,"8:8":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:17":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:10":"open","h:10:11":"open","h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:10":"open","h:11:11":"open","h:11:12":"open","h:11:13":"open","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:17":"open","h:13:18":"open","h:13:19":"wall","h:14:18":"open","h:14:19":"wall","h:15:18":"open","h:15:19":"wall","h:16:18":"open","h:16:19":"wall","h:17:18":"open","h:17:19":"wall","h:1:10":"open","h:1:11":"open","h:1:12":"open","h:1:13":"wall","h:1:8":"open","h:1:9":"open","h:2:8":"open","h:2:9":"open","h:3:8":"open","h:3:9":"open","h:4:8":"wall","h:4:9":"wall","h:5:8":"open","h:5:9":"open","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:11":"open","h:7:12":"open","h:7:13":"open","h:7:14":"open","h:7:15":"open","h:7:16":"open","h:7:17":"open","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:10":"open","h:8:11":"open","h:8:17":"wall","h:8:18":"wall","h:8:8":"open","h:8:9":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","h:9:9":"open","v:10:10":"open","v:10:11":"open","v:10:12":"wall","v:10:13":"open","v:10:17":"open","v:10:8":"open","v:10:9":"open","v:11:10":"open","v:11:11":"open","v:11:12":"wall","v:11:13":"open","v:11:17":"open","v:12:10":"wall","v:12:11":"open","v:12:12":"wall","v:12:13":"open","v:12:17":"open","v:13:17":"open","v:13:18":"wall","v:14:17":"open","v:14:18":"open","v:15:18":"open","v:16:18":"open","v:17:18":"open","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:2:10":"open","v:2:11":"open","v:2:12":"open","v:2:8":"open","v:2:9":"open","v:3:8":"open","v:4:8":"open","v:5:8":"open","v:6:8":"open","v:7:10":"open","v:7:11":"open","v:7:12":"open","v:7:13":"open","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:7:8":"open","v:8:10":"open","v:8:11":"open","v:8:12":"open","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:8:17":"open","v:8:8":"open","v:9:10":"open","v:9:11":"open","v:9:12":"open","v:9:13":"wall","v:9:17":"open","v:9:8":"open","v:9:9":"open"},"visited":["10:10","10:13","10:17","11:10","11:11","11:12","11:13","11:17","12:17","13:17","13:18","14:18","15:18","16:18","17:18","1:10","1:11","1:12","1:8","1:9","2:8","3:8","4:8","5:8","6:8","7:10","7:11","7:12","7:13","7:14","7:15","7:16","7:17","7:8","8:10","8:17","8:8","9:10","9:11","9:12","9:13","9:17","9:8","9:9"]},"world":{"chests_opened":["c1"],"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":1},"key_items":["key.moss_card","key.relay_fuse"],"location":"town","materials":{"item.glow_scale":2,"item.neon_rat_tail":4},"money":480,"party":{"at":[9,18],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":57,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":49,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":49,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":39,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":37,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-5760575937976465522"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":116,"wiped":false}}'
## 8판 전투: B2F 에 처음 선 칸(17,1)에서 전투 대기, 2일째, 테리아카 A 둘.
const V8_BATTLE := '{"format":"sqfangame-save","generation":92,"rules":"m3i","saved_at":"2026-10-28T13:14:15Z","schema":8,"state":{"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78,"kill":null,"resist":{}}],"formation":"formation.b2.beetles","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"consumables":{"use.theriaca_a":2},"day":2,"encounter":{"danger":199,"pending":true,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"W","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"1428040076817465289"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":false}}'
## 8판 전멸: 공략 30 행동 뒤 그 자리에서 전멸, 4일째.
const V8_WIPED := '{"format":"sqfangame-save","generation":93,"rules":"m3i","saved_at":"2026-10-28T16:17:18Z","schema":8,"state":{"battle":null,"consumables":{},"day":4,"encounter":{"danger":50,"pending":false,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"S","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":0,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":0,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":0,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-448129683613041646"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":true}}'
## 8판 시험 층(f1_test): 두 걸음, 6일째, 소지금 700, 소재 50·장비 2·메디카 18 = 70개(넘친 가방).
const V8_TEST := '{"format":"sqfangame-save","generation":94,"rules":"m3i","saved_at":"2026-10-28T19:20:21Z","schema":8,"state":{"battle":null,"consumables":{"use.medica":18},"day":6,"encounter":{"danger":0,"pending":false,"threshold":211},"floor":"f1_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["h:2:16"],"edges":{"h:2:16":"door"},"floors":{"2:16":0,"2:17":0,"2:18":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:3:16":"open","v:3:17":"open","v:3:18":"open"},"visited":["2:16","2:17","2:18"]},"world":{"chests_opened":[],"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":2},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":50},"money":700,"party":{"at":[2,16],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-3369913521587883864"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":2,"wiped":false}}'


## 지금 판 문서를 mutate 로 고쳐 읽으면 needle 을 담은 오류로 거부되는지(상태는 만들지 않는다).
func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])


## B1F g1 에서 두 번, B2F 기록에는 g3 를 한 번 쓴 미궁 상태(B1F (8,17)).
func _gathered() -> ExplorationState:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 31, "full")
	for a in [A.FORWARD, A.STRAFE_LEFT, A.GATHER, A.GATHER]:
		ExplorationRules.apply(s, a, "full")
	s.enter_floor(defs.floor_by_id("b2f"))
	s.world.gather_used = {"g3": 1}
	s.enter_floor(defs.first_floor())
	return s


## S1 (M-S1 floor_state_to_dict 가 gather_used 를 빠뜨림): 채집 기록이 두 층에 있는 상태를 쓰고 읽으면 같은 해시, world 키는 정확히 다섯.
func test_v9_roundtrip() -> void:
	var s := _gathered()
	check_eq(s.floor_states["b1f"].world.gather_used, {"g1": 2}, "B1F g1 두 번")
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "11판 머리")
	for id in doc["state"]["floor_states"]:
		var keys: Array = doc["state"]["floor_states"][id]["world"].keys()
		keys.sort()
		check_eq(keys, ["chests_opened", "foes", "gather_used", "locks_open", "passages_found", "shortcuts_open"], "%s: world 키 정확히 여섯(10판)" % id)
	check_eq([doc["state"]["floor_states"]["b1f"]["world"]["gather_used"], doc["state"]["floor_states"]["b2f"]["world"]["gather_used"]],
		[{"g1": 2.0}, {"g3": 1.0}], "쓴 횟수가 문서에 있다")
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(r.ok(), "읽기 %s" % r.error)
	if r.ok():
		check_eq([SaveCodec.state_hash(r.state), r.from_schema, r.relocated], [SaveCodec.state_hash(s), 11, false], "같은 해시, 11판, 옮김 없음")
		check_eq([r.state.floor_states["b1f"].world.gather_used, r.state.floor_states["b2f"].world.gather_used], [{"g1": 2}, {"g3": 1}], "읽은 쓴 횟수")
		var p: FloorModel.GatherPoint = r.state.floor_def.points["g1"]
		check_eq(r.state.world.gather_left(p), 0, "읽은 뒤에도 다 쓴 채")


## S2 (M-S2a 값 0 을 받음, M-S2b 9판 world 에 gather_used 가 없어도 받음): 9판 거부(상태를 만들지 않는다).
func test_v9_rejects() -> void:
	var s := _gathered()
	var gu := func(d: Dictionary, id: String) -> Dictionary: return d["state"]["floor_states"][id]["world"]
	_reject(s, func(d): gu.call(d, "b1f")["gather_used"]["zz"] = 1, "floor_states.b1f.world.gather_used: zz 는 이 층의 채집 지점이 아니다", "모르는 지점")
	_reject(s, func(d): gu.call(d, "b2f")["gather_used"]["g9"] = 1, "floor_states.b2f.world.gather_used: g9 는 이 층의 채집 지점이 아니다", "다른 층 지점")
	for v in [0, 10, 1.5, true, "1", null]:
		_reject(s, func(d): gu.call(d, "b1f")["gather_used"]["g1"] = v, "floor_states.b1f.world.gather_used.g1: 정수 1~9", "값 %s" % str(v))
	_reject(s, func(d): gu.call(d, "b1f")["gather_used"] = [], "floor_states.b1f.world.gather_used: 객체가 아니다", "배열")
	_reject(s, func(d): gu.call(d, "b1f").erase("gather_used"), "floor_states.b1f.world.gather_used 가 없다", "9판에 키 없음")
	_reject(s, func(d): gu.call(d, "b1f")["x"] = [], "floor_states.b1f.world.x 는 모르는 필드다", "모르는 world 키")
	# 8판 머리에 gather_used 가 있으면 8판 규칙(world 넷)으로 거부된다. 10판(M3 A6)의 foes 는 걷어 내고 gather_used 만 남긴다.
	var v8_head := func(d: Dictionary) -> void:
		d.merge({"schema": 8, "rules": "m3i"}, true)
		Fx.strip_guild(d)  # M3 A7: 11판 길드 값도 걷어 낸다
		for id in d["state"]["floor_states"]:
			d["state"]["floor_states"][id]["world"].erase("foes")
	_reject(s, v8_head, "8판 검사 실패: floor_states.b1f.world.gather_used 는 모르는 필드다", "8판 world 에 gather_used")
	_reject(s, func(d): d.merge({"schema": 8, "rules": "m3g"}, true), "규칙 판(rules)이 schema 8 와 맞지 않다", "8판 머리에 m3g")
	_reject(s, func(d): d["rules"] = "m3i", "규칙 판(rules)이 schema 11 와 맞지 않다", "11판 머리에 m3i")
	_reject(s, func(d): d["schema"] = 12, "지원하지 않는 schema 다", "12판")


## 8판 문서가 담은 필드는 9판으로 옮긴 뒤에도 같고, 더해진 것은 층 기록 world 의 빈 gather_used 뿐인지.
func _check_kept(label: String, text: String, defs: GameDefs) -> SaveCodec.LoadResult:
	var orig: Dictionary = JSON.parse_string(text)
	var r := SaveCodec.decode(text, defs)
	check(r.ok(), "%s: 읽기 %s" % [label, r.error])
	if not r.ok():
		return r
	check_eq([r.from_schema, r.relocated, r.saved_at, r.generation], [8, false, orig["saved_at"], int(orig["generation"])], "%s: 8판·옮김 없음·saved_at·generation" % label)
	var sv := Fx.strip_v11(SaveCodec.state_to_dict(r.state), r.state.defs)  # M3 A7: 11판이 더한 길드 값은 기본값이어야 하고, 견주기에서는 뺀다
	check_eq(sv["bad"], "", "%s: 11판 길드 값은 기본값" % label)
	var now: Dictionary = sv["state"]
	var o: Dictionary = orig["state"]
	for id in o["floor_states"]:
		check(not o["floor_states"][id]["world"].has("gather_used"), "%s: 원본 %s 에는 채집 기록이 없다" % [label, id])
		o["floor_states"][id]["world"]["gather_used"] = {}
		o["floor_states"][id]["world"]["foes"] = Fx.fresh_foes(id)  # 10판(M3 A6)의 처음 FOE 기록
	for k in o:
		check_eq(V7._norm(now[k]), V7._norm(o[k]), "%s: %s 보존" % [label, k])
	check_eq(now.keys().filter(func(k: String) -> bool: return not o.has(k)), [], "%s: 맨 위에 더해진 필드 없음" % label)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
	check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판으로 쓴다" % label)
	var again := SaveCodec.decode(JSON.stringify(doc), defs)
	check(again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 11판 다시 읽기 같은 해시 %s" % [label, again.error])
	return r


## S3 (M-S3 migrate_v8 가 소모품을 버림): HEAD 코드로 만든 8판 고정 문서 셋을 게임 묶음으로 읽으면 9판, 원래 필드는 그대로.
func test_fixed_v8_strings_migrate() -> void:
	var defs := Fx.arbor()
	var town := _check_kept("8판 마을", V8_TOWN, defs)
	if town.ok():
		check_eq([town.state.consumables, town.state.day, town.state.location, town.state.key_items.size()],
			[{"use.medica": 3, "use.ariadne_beacon": 1}, 3, "town", 2], "8판 마을: 소모품·날·마을·열쇠")
	var battle := _check_kept("8판 전투", V8_BATTLE, defs)
	if battle.ok():
		check(battle.state.encounter.pending and battle.state.battle != null and battle.state.consumables == {"use.theriaca_a": 2}, "8판 전투: 전투 대기·소모품")
	var wiped := _check_kept("8판 전멸", V8_WIPED, defs)
	if wiped.ok():
		check(wiped.state.wiped and wiped.state.day == 4, "8판 전멸")
	_check_kept("8판 시험 층", V8_TEST, Fx.defs())
	var bad: Dictionary = JSON.parse_string(V8_TOWN)
	bad["state"]["consumables"]["use.medica"] = 0
	var rb := SaveCodec.decode(JSON.stringify(bad), defs)
	check(not rb.ok() and rb.state == null and rb.error.begins_with("8판 검사 실패: "), "깨진 8판 %s" % rb.error)


## S4: 1~7판 고정 문서도 모두 9판이 된다(머리 보존, 다시 읽으면 같은 해시, 층 기록마다 빈 채집 기록).
func test_every_old_schema_migrates_to_v9() -> void:
	var test_set := [["1판 보통", BS.V1_NORMAL, 1], ["1판 전투 대기", BS.V1_PENDING, 1], ["1판 전멸", BS.V1_WIPED, 1],
			["2판 보통", GS.V2_NORMAL, 2], ["2판 전투", GS.V2_BATTLE, 2], ["2판 전멸", GS.V2_WIPED, 2],
			["3판 웹 승리 고정 문서", FileAccess.get_file_as_string(V5.VICTORY_V3), 3],
			["4판 웹 상점 고정 문서", FileAccess.get_file_as_string(V5.SHOP_V4), 4],
			["4판 장치", V5.V4_DEVICES, 4], ["4판 전투", V5.V4_BATTLE, 4],
			["5판 두 층", V6.V5_TWO_FLOORS, 5], ["5판 전투", V6.V5_BATTLE, 5],
			["6판 마을", V7.V6_TOWN, 6], ["6판 전투", V7.V6_BATTLE, 6], ["6판 전멸", V7.V6_WIPED, 6]]
	var game_set := [["7판 마을", V8.V7_TOWN, 7], ["7판 전투", V8.V7_BATTLE, 7], ["7판 전멸", V8.V7_WIPED, 7], ["7판 넘친 가방", V8.V7_OVER, 7]]
	for pair in [[test_set, Fx.defs()], [game_set, Fx.arbor()]]:
		for x in pair[0]:
			var orig: Dictionary = JSON.parse_string(x[1])
			var r := SaveCodec.decode(x[1], pair[1])
			check(r.ok(), "%s: 이전 성공 %s" % [x[0], r.error])
			if not r.ok():
				continue
			check_eq([r.from_schema, r.saved_at, r.generation, r.relocated], [x[2], orig["saved_at"], int(orig["generation"]), false],
				"%s: from_schema·saved_at·generation" % x[0])
			for id in r.state.floor_states:
				check_eq(r.state.floor_states[id].world.gather_used, {}, "%s: %s 빈 채집 기록" % [x[0], id])
			var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
			check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판으로 쓴다" % x[0])
			var again := SaveCodec.decode(JSON.stringify(doc), pair[1])
			check(again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 다시 읽기 같은 해시" % x[0])


## S5 (M-S5 옮길 때 소모품을 버림): 8판 시험 층 저장을 게임 묶음으로 읽으면 새 미궁으로 옮기고, 채집 기록은 빈 B1F 하나로 시작한다.
func test_relocation_starts_empty() -> void:
	var defs := Fx.arbor()
	var r := SaveCodec.decode(V8_TEST, defs)
	check(r.ok() and r.relocated and r.from_schema == 8, "옮겨 읽음 %s" % r.error)
	if not r.ok():
		return
	var n := r.state
	check_eq([n.floor_states.keys(), n.floor_states["b1f"].world.gather_used, n.location, n.day], [["b1f"], {}, "town", 6], "B1F 기록 하나, 빈 채집 기록, 마을, 6일째")
	check_eq([n.consumables, n.materials, n.gear_bag, BagRules.used(n), n.money], [{"use.medica": 18}, {"item.neon_rat_tail": 50}, {"equip.twin_edge": 2}, 70, 700],
		"소모품·소재·가방(70, 넘친 채)·돈 그대로")
	var again := SaveCodec.decode(SaveCodec.encode(n), defs)
	check(again.ok() and not again.relocated and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(n), "11판으로 다시 쓰고 읽음 %s" % again.error)


## S6: 8판 본 파일을 읽어 자동 저장하면 .bak 은 8판 원본 그대로, 본 파일은 9판. 본 파일이 깨지면 8판 .bak 을 옮겨 읽는다.
func test_v8_bak() -> void:
	Fx.clean_saves()
	var store := SaveStore.new(Fx.arbor(), Fx.SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(Fx.SAVE_DIR)
	var main := store.main_path("auto")
	var bak := main.get_basename() + ".bak"
	var f := FileAccess.open(main, FileAccess.WRITE)
	f.store_string(V8_TOWN)
	f.close()
	var l := store.load_slot("auto")
	check(l.ok() and l.source_kind == "main" and l.result.from_schema == 8, "8판 본 파일 읽음 %s" % str(l.failures))
	if not l.ok():
		Fx.clean_saves()
		return
	check_eq(store.save("auto", l.result.state), "", "자동 저장")
	check_eq(FileAccess.get_file_as_string(bak), V8_TOWN, ".bak 은 8판 원본")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main))
	check_eq([doc["schema"], doc["rules"], doc["generation"]], [11.0, "m3r", 92.0], "본 파일은 11판(세대 + 1)")
	f = FileAccess.open(main, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	var rb := store.load_slot("auto")
	check(rb.ok() and rb.source_kind == "bak" and rb.result.from_schema == 8, ".bak(8판)을 옮겨 읽음 %s" % str(rb.failures))
	Fx.clean_saves()


## S7 (M-S7 쓴 횟수를 지점의 지금 uses 와 견줌): 자료를 고쳐 하루 횟수가 줄어도(g2 하루 1) 저장의 더 큰 값(5)은 읽히고, 그 지점은 다 쓴 것이다.
func test_tuning_tolerance() -> void:
	var defs := TG.defs()
	var s := ExplorationRules.new_game(defs, 3, "full")
	s.world.gather_used = {"g2": 5, "g1": 1}
	var r := SaveCodec.decode(SaveCodec.encode(s), defs)
	check(r.ok(), "uses 보다 큰 값도 읽힘 %s" % r.error)
	if r.ok():
		check_eq([r.state.world.gather_used, r.state.world.gather_left(r.state.floor_def.points["g2"]), r.state.world.gather_left(r.state.floor_def.points["g1"])],
			[{"g2": 5, "g1": 1}, 0, 1], "g2 는 다 씀, g1 은 하나 남음")


func teardown() -> void:
	Fx.clean_saves()
	super()
