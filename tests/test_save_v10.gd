## 저장 10판(M3 A6 설계 §3·§7.4): 층 기록 world 의 foes(FOE 상태)·battle.foe(접촉 전투) 왕복·검사, 9판 고정 문서 → 10판(FOE 는 처음 상태,
## 파티 칸의 FOE 는 비킨다), 1~8판도 10판으로, 시험 층 9판 저장 옮기기, 빠진 FOE 기록은 처음 상태로 읽기. 시험마다 죽이는 변이(M-S…)를 적는다.
##
## 고정 문서 다섯은 HEAD a9346cb 코드(A6 편집 전 깨끗한 작업 트리)로 저장소 밖 생성기(/tmp/sqf_a6/gen_v9.gd)가 만들었다:
##   cd /tmp && godot --headless --path <저장소> -s /tmp/sqf_a6/gen_v9.gd
## 생성기는 Fx.arbor() 새 게임(시드 31)으로 arbor_route.json 공략을 걷고(전투는 승리), V9_TEST 는 시험 묶음 새 게임이다.
## SaveCodec.encode(saved_at, generation 91~95)로 쓴 뒤 같은 HEAD 코드로 다시 읽어 from_schema 9·옮김 없음을 확인했다(V9_TEST 는 게임 묶음으로
## 읽으면 옮겨진다). 문서를 바꾸지 말 것(9판 이전 길의 기준이다).
extends TestCase

const Fx := preload("res://tests/fixtures.gd")
const V7 := preload("res://tests/test_save_v7.gd")
const V8 := preload("res://tests/test_save_v8.gd")
const V9 := preload("res://tests/test_save_v9.gd")
const A := ExplorationRules.Action
const REC_KEYS := ["at", "day", "dir", "facing", "path_i", "state", "stun"]

## 9판 마을: 공략 뒤 마을(B1F 시작 칸), 세 층 기록, 3일째, 채집 기록(b1f g1:1, b2f g3:2), 소재·소모품.
const V9_TOWN := '{"format":"sqfangame-save","generation":91,"rules":"m3g","saved_at":"2026-10-28T10:11:12Z","schema":9,"state":{"battle":null,"consumables":{"use.ariadne_beacon":1,"use.medica":3},"day":3,"encounter":{"danger":0,"pending":false,"threshold":173},"floor":"b1f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{"9:18":"입구"}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"gather_used":{"g1":1},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:10:2","h:10:3","h:11:13","h:11:14","h:11:2","h:11:3","h:12:14","h:12:2","h:13:4","h:14:4","h:15:4","h:16:18","h:16:4","h:17:1","h:17:18","h:17:4","h:6:15","h:7:15","h:8:15","h:8:2","h:9:2","h:9:3","v:12:10","v:12:11","v:12:12","v:12:3","v:12:4","v:12:5","v:12:6","v:12:7","v:12:8","v:12:9","v:13:10","v:13:11","v:13:12","v:13:13","v:13:2","v:13:4","v:13:5","v:13:6","v:13:7","v:13:8","v:13:9","v:16:10","v:16:11","v:16:12","v:16:4","v:16:5","v:16:6","v:16:7","v:16:8","v:16:9","v:17:10","v:17:11","v:17:12","v:17:4","v:17:5","v:17:6","v:17:7","v:17:8","v:17:9","v:18:1","v:18:17","v:18:2","v:18:3","v:6:13","v:6:14","v:8:10","v:8:11","v:8:3","v:8:4","v:8:5","v:8:6","v:8:7","v:8:8","v:8:9","v:9:10","v:9:11","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7","v:9:8","v:9:9"],"edges":{"h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:14":"wall","h:12:2":"wall","h:13:4":"wall","h:14:4":"wall","h:15:4":"wall","h:16:18":"wall","h:16:4":"door","h:17:1":"wall","h:17:18":"wall","h:17:4":"wall","h:6:15":"wall","h:7:15":"wall","h:8:15":"wall","h:8:2":"wall","h:9:2":"wall","h:9:3":"wall","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"door","v:13:2":"door","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:8:10":"wall","v:8:11":"wall","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"floors":{"10:13":0,"10:2":0,"11:13":0,"11:2":0,"12:10":0,"12:11":0,"12:12":0,"12:13":0,"12:2":0,"12:3":0,"12:4":0,"12:5":0,"12:6":0,"12:7":0,"12:8":0,"12:9":0,"13:3":0,"14:3":0,"15:3":0,"16:10":0,"16:11":0,"16:12":0,"16:13":0,"16:14":0,"16:15":0,"16:16":0,"16:17":0,"16:3":0,"16:4":0,"16:5":0,"16:6":0,"16:7":0,"16:8":0,"16:9":0,"17:1":0,"17:17":0,"17:2":0,"17:3":0,"6:13":0,"6:14":0,"7:13":0,"7:14":0,"8:10":0,"8:11":0,"8:12":0,"8:13":0,"8:14":0,"8:2":0,"8:3":0,"8:4":0,"8:5":0,"8:6":0,"8:7":0,"8:8":0,"8:9":0,"9:13":0,"9:2":0},"icons":{},"memos":{"1:1":"문 앞"}},"knowledge":{"edges":{"h:10:13":"open","h:10:14":"open","h:10:2":"wall","h:10:3":"wall","h:11:13":"wall","h:11:14":"wall","h:11:2":"wall","h:11:3":"wall","h:12:10":"open","h:12:11":"open","h:12:12":"open","h:12:13":"open","h:12:14":"wall","h:12:2":"wall","h:12:3":"open","h:12:4":"open","h:12:5":"oneway","h:12:6":"open","h:12:7":"open","h:12:8":"open","h:12:9":"open","h:13:3":"open","h:13:4":"wall","h:14:3":"open","h:14:4":"wall","h:15:3":"open","h:15:4":"wall","h:16:10":"open","h:16:11":"open","h:16:12":"open","h:16:13":"open","h:16:14":"open","h:16:15":"open","h:16:16":"open","h:16:17":"open","h:16:18":"wall","h:16:3":"open","h:16:4":"door","h:16:5":"open","h:16:6":"open","h:16:7":"open","h:16:8":"open","h:16:9":"open","h:17:1":"wall","h:17:17":"open","h:17:18":"wall","h:17:2":"open","h:17:3":"open","h:17:4":"wall","h:6:13":"open","h:6:14":"open","h:6:15":"wall","h:7:13":"open","h:7:14":"open","h:7:15":"wall","h:8:10":"open","h:8:11":"open","h:8:12":"open","h:8:13":"open","h:8:14":"open","h:8:15":"wall","h:8:2":"wall","h:8:3":"open","h:8:4":"open","h:8:5":"oneway","h:8:6":"open","h:8:7":"open","h:8:8":"open","h:8:9":"oneway","h:9:13":"open","h:9:14":"open","h:9:2":"wall","h:9:3":"wall","v:10:13":"open","v:10:2":"open","v:11:13":"oneway","v:11:2":"open","v:12:10":"wall","v:12:11":"wall","v:12:12":"wall","v:12:13":"open","v:12:2":"open","v:12:3":"wall","v:12:4":"wall","v:12:5":"wall","v:12:6":"wall","v:12:7":"wall","v:12:8":"wall","v:12:9":"wall","v:13:10":"wall","v:13:11":"wall","v:13:12":"wall","v:13:13":"shortcut","v:13:2":"door","v:13:3":"open","v:13:4":"wall","v:13:5":"wall","v:13:6":"wall","v:13:7":"wall","v:13:8":"wall","v:13:9":"wall","v:14:3":"open","v:15:3":"open","v:16:10":"wall","v:16:11":"wall","v:16:12":"wall","v:16:13":"open","v:16:14":"open","v:16:15":"open","v:16:16":"open","v:16:17":"open","v:16:3":"open","v:16:4":"wall","v:16:5":"wall","v:16:6":"wall","v:16:7":"wall","v:16:8":"wall","v:16:9":"wall","v:17:1":"open","v:17:10":"wall","v:17:11":"wall","v:17:12":"wall","v:17:13":"open","v:17:14":"open","v:17:15":"open","v:17:16":"open","v:17:17":"open","v:17:2":"open","v:17:3":"open","v:17:4":"wall","v:17:5":"wall","v:17:6":"wall","v:17:7":"wall","v:17:8":"wall","v:17:9":"wall","v:18:1":"wall","v:18:17":"wall","v:18:2":"wall","v:18:3":"wall","v:6:13":"wall","v:6:14":"wall","v:7:13":"open","v:7:14":"open","v:8:10":"wall","v:8:11":"wall","v:8:12":"open","v:8:13":"open","v:8:14":"open","v:8:2":"open","v:8:3":"wall","v:8:4":"wall","v:8:5":"wall","v:8:6":"wall","v:8:7":"wall","v:8:8":"wall","v:8:9":"wall","v:9:10":"wall","v:9:11":"wall","v:9:12":"open","v:9:13":"open","v:9:14":"open","v:9:2":"open","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"wall","v:9:9":"wall"},"visited":["10:13","10:2","11:13","11:2","12:10","12:11","12:12","12:13","12:2","12:3","12:4","12:5","12:6","12:7","12:8","12:9","13:3","14:3","15:3","16:10","16:11","16:12","16:13","16:14","16:15","16:16","16:17","16:3","16:4","16:5","16:6","16:7","16:8","16:9","17:1","17:17","17:2","17:3","6:13","6:14","7:13","7:14","8:10","8:11","8:12","8:13","8:14","8:2","8:3","8:4","8:5","8:6","8:7","8:8","8:9","9:13","9:2"]},"world":{"chests_opened":["c1"],"gather_used":{"g3":2},"locks_open":["h:16:4"],"passages_found":[],"shortcuts_open":[]}},"b3f":{"annotation":{"auto_edges":["h:10:13","h:10:14","h:10:17","h:10:18","h:11:14","h:11:17","h:11:18","h:12:17","h:12:18","h:13:19","h:14:19","h:15:19","h:16:19","h:17:19","h:1:13","h:4:8","h:4:9","h:6:8","h:6:9","h:7:10","h:7:18","h:7:8","h:7:9","h:8:17","h:8:18","h:9:14","h:9:17","h:9:18","h:9:8","v:10:12","v:11:12","v:12:10","v:12:12","v:13:18","v:18:18","v:1:10","v:1:11","v:1:12","v:1:8","v:1:9","v:7:14","v:7:15","v:7:16","v:7:17","v:8:13","v:8:14","v:8:15","v:8:16","v:9:13"],"edges":{"h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:19":"wall","h:14:19":"wall","h:15:19":"wall","h:16:19":"wall","h:17:19":"wall","h:1:13":"wall","h:4:8":"wall","h:4:9":"wall","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:17":"wall","h:8:18":"wall","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","v:10:12":"wall","v:11:12":"wall","v:12:10":"wall","v:12:12":"wall","v:13:18":"wall","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:9:13":"wall"},"floors":{"10:10":0,"10:13":0,"10:17":0,"11:10":0,"11:11":0,"11:12":0,"11:13":0,"11:17":0,"12:17":0,"13:17":0,"13:18":0,"14:18":0,"15:18":0,"16:18":0,"17:18":0,"1:10":0,"1:11":0,"1:12":0,"1:8":0,"1:9":0,"2:8":0,"3:8":0,"4:8":0,"5:8":0,"6:8":0,"7:10":0,"7:11":0,"7:12":0,"7:13":0,"7:14":0,"7:15":0,"7:16":0,"7:17":0,"7:8":0,"8:10":0,"8:17":0,"8:8":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:17":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:10":"open","h:10:11":"open","h:10:13":"wall","h:10:14":"wall","h:10:17":"wall","h:10:18":"wall","h:11:10":"open","h:11:11":"open","h:11:12":"open","h:11:13":"open","h:11:14":"wall","h:11:17":"wall","h:11:18":"wall","h:12:17":"wall","h:12:18":"wall","h:13:17":"open","h:13:18":"open","h:13:19":"wall","h:14:18":"open","h:14:19":"wall","h:15:18":"open","h:15:19":"wall","h:16:18":"open","h:16:19":"wall","h:17:18":"open","h:17:19":"wall","h:1:10":"open","h:1:11":"open","h:1:12":"open","h:1:13":"wall","h:1:8":"open","h:1:9":"open","h:2:8":"open","h:2:9":"open","h:3:8":"open","h:3:9":"open","h:4:8":"wall","h:4:9":"wall","h:5:8":"open","h:5:9":"open","h:6:8":"wall","h:6:9":"wall","h:7:10":"wall","h:7:11":"open","h:7:12":"open","h:7:13":"open","h:7:14":"open","h:7:15":"open","h:7:16":"open","h:7:17":"open","h:7:18":"wall","h:7:8":"wall","h:7:9":"wall","h:8:10":"open","h:8:11":"open","h:8:17":"wall","h:8:18":"wall","h:8:8":"open","h:8:9":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"wall","h:9:17":"wall","h:9:18":"wall","h:9:8":"wall","h:9:9":"open","v:10:10":"open","v:10:11":"open","v:10:12":"wall","v:10:13":"open","v:10:17":"open","v:10:8":"open","v:10:9":"open","v:11:10":"open","v:11:11":"open","v:11:12":"wall","v:11:13":"open","v:11:17":"open","v:12:10":"wall","v:12:11":"open","v:12:12":"wall","v:12:13":"open","v:12:17":"open","v:13:17":"open","v:13:18":"wall","v:14:17":"open","v:14:18":"open","v:15:18":"open","v:16:18":"open","v:17:18":"open","v:18:18":"wall","v:1:10":"wall","v:1:11":"wall","v:1:12":"wall","v:1:8":"wall","v:1:9":"wall","v:2:10":"open","v:2:11":"open","v:2:12":"open","v:2:8":"open","v:2:9":"open","v:3:8":"open","v:4:8":"open","v:5:8":"open","v:6:8":"open","v:7:10":"open","v:7:11":"open","v:7:12":"open","v:7:13":"open","v:7:14":"wall","v:7:15":"wall","v:7:16":"wall","v:7:17":"wall","v:7:8":"open","v:8:10":"open","v:8:11":"open","v:8:12":"open","v:8:13":"wall","v:8:14":"wall","v:8:15":"wall","v:8:16":"wall","v:8:17":"open","v:8:8":"open","v:9:10":"open","v:9:11":"open","v:9:12":"open","v:9:13":"wall","v:9:17":"open","v:9:8":"open","v:9:9":"open"},"visited":["10:10","10:13","10:17","11:10","11:11","11:12","11:13","11:17","12:17","13:17","13:18","14:18","15:18","16:18","17:18","1:10","1:11","1:12","1:8","1:9","2:8","3:8","4:8","5:8","6:8","7:10","7:11","7:12","7:13","7:14","7:15","7:16","7:17","7:8","8:10","8:17","8:8","9:10","9:11","9:12","9:13","9:17","9:8","9:9"]},"world":{"chests_opened":["c1"],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":1},"key_items":["key.moss_card","key.relay_fuse"],"location":"town","materials":{"item.glow_scale":2,"item.neon_moss":3,"item.neon_rat_tail":4},"money":480,"party":{"at":[9,18],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":57,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":49,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":49,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":39,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":37,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-5760575937976465522"},"shop":{"bought":[],"pool":{"item.neon_rat_tail":2},"sold":{"item.neon_rat_tail":3}},"steps":116,"wiped":false}}'

## 9판 전투: B2F (17,1) 에서 인카운트 전투 대기(formation.b2.beetles), 2일째, 두 층 기록.
const V9_BATTLE := '{"format":"sqfangame-save","generation":92,"rules":"m3g","saved_at":"2026-10-28T13:14:15Z","schema":9,"state":{"battle":{"enemies":[{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":208,"kill":null,"resist":{}},{"ailment":null,"binds":{},"buffs":[],"charging":null,"debuffs":[],"hp":78,"kill":null,"resist":{}}],"formation":"formation.b2.beetles","party":[{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}},{"ailment":null,"binds":{},"buffs":[],"debuffs":[],"resist":{}}],"seq":1,"turn":0},"consumables":{"use.theriaca_a":2},"day":2,"encounter":{"danger":199,"pending":true,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"W","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"1428040076817465289"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":false}}'

## 9판 전멸: B2F (17,1), 4일째.
const V9_WIPED := '{"format":"sqfangame-save","generation":93,"rules":"m3g","saved_at":"2026-10-28T16:17:18Z","schema":9,"state":{"battle":null,"consumables":{},"day":4,"encounter":{"danger":50,"pending":false,"threshold":199},"floor":"b2f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:10:16","h:10:2","h:10:3","h:11:2","h:11:3","h:12:2","h:12:3","h:13:1","h:14:1","h:15:1","h:16:1","h:17:1","h:9:16","h:9:19","h:9:2","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:10:3","v:10:4","v:10:5","v:10:6","v:10:7","v:11:16","v:13:1","v:13:2","v:18:1","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15","v:9:2","v:9:3","v:9:4","v:9:5","v:9:6","v:9:7"],"edges":{"h:10:16":"wall","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:14:1":"wall","h:15:1":"wall","h:16:1":"wall","h:17:1":"wall","h:9:16":"door","h:9:19":"wall","h:9:2":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:11:16":"wall","v:13:1":"wall","v:13:2":"door","v:18:1":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall"},"floors":{"10:16":0,"10:2":0,"11:2":0,"12:2":0,"13:1":0,"13:2":0,"14:1":0,"15:1":0,"16:1":0,"17:1":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:2":0,"9:3":0,"9:4":0,"9:5":0,"9:6":0,"9:7":0,"9:8":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:16":"wall","h:10:17":"open","h:10:2":"wall","h:10:3":"wall","h:11:2":"wall","h:11:3":"wall","h:12:2":"wall","h:12:3":"wall","h:13:1":"wall","h:13:2":"open","h:13:3":"open","h:14:1":"wall","h:14:2":"open","h:15:1":"wall","h:15:2":"open","h:16:1":"wall","h:16:2":"open","h:17:1":"wall","h:17:2":"open","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:2":"wall","h:9:3":"open","h:9:4":"open","h:9:5":"open","h:9:6":"open","h:9:7":"open","h:9:8":"open","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:2":"open","v:10:3":"wall","v:10:4":"wall","v:10:5":"wall","v:10:6":"wall","v:10:7":"wall","v:10:8":"open","v:10:9":"open","v:11:16":"wall","v:11:2":"open","v:12:2":"open","v:13:1":"wall","v:13:2":"door","v:14:1":"open","v:14:2":"open","v:15:1":"open","v:16:1":"open","v:17:1":"open","v:18:1":"wall","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:2":"wall","v:9:3":"wall","v:9:4":"wall","v:9:5":"wall","v:9:6":"wall","v:9:7":"wall","v:9:8":"open","v:9:9":"open"},"visited":["10:16","10:2","11:2","12:2","13:1","13:2","14:1","15:1","16:1","17:1","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:2","9:3","9:4","9:5","9:6","9:7","9:8","9:9"]},"world":{"chests_opened":["c1"],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}},"b2f":{"annotation":{"auto_edges":["h:17:1","v:18:1"],"edges":{"h:17:1":"wall","v:18:1":"wall"},"floors":{"17:1":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:17:1":"wall","h:17:2":"open","v:17:1":"open","v:18:1":"wall"},"visited":["17:1"]},"world":{"chests_opened":[],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":3},"money":200,"party":{"at":[17,1],"facing":"S","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":0,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":0,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":0,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":0,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-448129683613041646"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":27,"wiped":true}}'

## 9판 시험 층(f1_test) 저장, 6일째: 게임 묶음으로 읽으면 옮긴다.
const V9_TEST := '{"format":"sqfangame-save","generation":94,"rules":"m3g","saved_at":"2026-10-28T19:20:21Z","schema":9,"state":{"battle":null,"consumables":{"use.medica":18},"day":6,"encounter":{"danger":0,"pending":false,"threshold":211},"floor":"f1_test","floor_states":{"f1_test":{"annotation":{"auto_edges":["h:2:16"],"edges":{"h:2:16":"door"},"floors":{"2:16":0,"2:17":0,"2:18":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:2:16":"door","h:2:17":"open","h:2:18":"open","h:2:19":"open","v:2:16":"open","v:2:17":"open","v:2:18":"open","v:3:16":"open","v:3:17":"open","v:3:18":"open"},"visited":["2:16","2:17","2:18"]},"world":{"chests_opened":[],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{"equip.twin_edge":2},"key_items":[],"location":"labyrinth","materials":{"item.neon_rat_tail":50},"money":700,"party":{"at":[2,16],"facing":"N","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-3369913521587883864"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":2,"wiped":false}}'

## 9판 미궁: 파티가 B1F (12,9)(숫양의 시작 칸)에 동쪽을 보고 선다, 5일째. 읽으면 숫양이 비켜야 한다(settle).
const V9_ON_FOE := '{"format":"sqfangame-save","generation":95,"rules":"m3g","saved_at":"2026-10-28T22:23:24Z","schema":9,"state":{"battle":null,"consumables":{},"day":5,"encounter":{"danger":100,"pending":false,"threshold":176},"floor":"b1f","floor_states":{"b1f":{"annotation":{"auto_edges":["h:12:10","h:12:9","h:9:16","h:9:19","v:10:11","v:10:12","v:10:13","v:10:14","v:10:15","v:9:11","v:9:12","v:9:13","v:9:14","v:9:15"],"edges":{"h:12:10":"wall","h:12:9":"wall","h:9:16":"door","h:9:19":"wall","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall"},"floors":{"10:9":0,"11:9":0,"12:9":0,"9:10":0,"9:11":0,"9:12":0,"9:13":0,"9:14":0,"9:15":0,"9:16":0,"9:17":0,"9:18":0,"9:9":0},"icons":{},"memos":{}},"knowledge":{"edges":{"h:10:10":"open","h:10:9":"open","h:11:10":"open","h:11:9":"open","h:12:10":"wall","h:12:9":"wall","h:9:10":"open","h:9:11":"open","h:9:12":"open","h:9:13":"open","h:9:14":"open","h:9:15":"open","h:9:16":"door","h:9:17":"open","h:9:18":"open","h:9:19":"wall","h:9:9":"open","v:10:10":"open","v:10:11":"wall","v:10:12":"wall","v:10:13":"wall","v:10:14":"wall","v:10:15":"wall","v:10:16":"open","v:10:17":"open","v:10:18":"open","v:10:9":"open","v:11:9":"open","v:12:9":"open","v:13:9":"open","v:9:10":"open","v:9:11":"wall","v:9:12":"wall","v:9:13":"wall","v:9:14":"wall","v:9:15":"wall","v:9:16":"open","v:9:17":"open","v:9:18":"open","v:9:9":"open"},"visited":["10:9","11:9","12:9","9:10","9:11","9:12","9:13","9:14","9:15","9:16","9:17","9:18","9:9"]},"world":{"chests_opened":[],"gather_used":{},"locks_open":[],"passages_found":[],"shortcuts_open":[]}}},"gear_bag":{},"key_items":[],"location":"labyrinth","materials":{},"money":200,"party":{"at":[12,9],"facing":"E","members":[{"equip":["equip.training_sword","equip.training_shield","equip.padded_coat",null],"exp":0,"hp":60,"id":"holo_knight","level":1,"skills":{"skill.holo_knight.aegis_cover":1,"skill.holo_knight.defense_protocol":1,"skill.holo_knight.front_guard":1},"tp":30},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.twin_edge","equip.padded_coat","equip.grip_gloves",null],"exp":0,"hp":52,"id":"blade_duelist_2","level":1,"skills":{"skill.blade_duelist.cross_sweep":1,"skill.blade_duelist.high_slash":1,"skill.blade_duelist.overclock":1},"tp":32},{"equip":["equip.nano_rod","equip.medic_coat","equip.sensor_cap",null],"exp":0,"hp":42,"id":"nano_medic","level":1,"skills":{"skill.nano_medic.nano_repair":1,"skill.nano_medic.reboot":1,"skill.nano_medic.refresh_patch":1},"tp":54},{"equip":["equip.glyph_stylus","equip.glyph_robe","equip.signal_charm",null],"exp":0,"hp":40,"id":"glyph_wizard","level":1,"skills":{"skill.glyph_wizard.frost_glyph":1,"skill.glyph_wizard.heat_glyph":1,"skill.glyph_wizard.shock_glyph":1},"tp":60}]},"rng":{"state":"-7335808875235361152"},"shop":{"bought":[],"pool":{},"sold":{}},"steps":12,"wiped":false}}'

## 지금 판 문서를 mutate 로 고쳐 읽으면 needle 을 담은 오류로 거부되는지(상태는 만들지 않는다).
func _reject(s: ExplorationState, mutate: Callable, needle: String, label: String) -> void:
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	mutate.call(doc)
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(not r.ok() and r.state == null, "%s: 거부되어야 한다" % label)
	check(r.error.contains(needle), "%s: 이유 '%s' 기대, 실제 '%s'" % [label, needle, r.error])


## 세 층 기록이 있는 미궁 상태(B1F 지금 층, 파티 (13,9) 서쪽). 숫양은 경로 가운데(14,9)에서 서쪽으로 걷고 한 걸음 쉰다,
## 탐험가는 추적, 경비기는 3일째에 쓰러졌다. 4일째.
func _three_floors() -> ExplorationState:
	var defs := Fx.arbor()
	var s := ExplorationRules.new_game(defs, 31, "full")
	s.enter_floor(defs.floor_by_id("b2f"))
	s.enter_floor(defs.floor_by_id("b3f"))
	s.enter_floor(defs.floor_by_id("b1f"))
	s.day = 4
	s.party.at = Vector2i(13, 9)
	s.party.facing = Dir.W
	var ram: WorldState.FoeState = s.floor_states["b1f"].world.foes["f1"]
	ram.at = Vector2i(14, 9)
	ram.facing = Dir.W
	ram.path_i = 2
	ram.dir = -1
	ram.stun = 1
	var delver: WorldState.FoeState = s.floor_states["b2f"].world.foes["f2"]
	delver.at = Vector2i(3, 10)
	delver.state = "chase"
	var warden: WorldState.FoeState = s.floor_states["b3f"].world.foes["f3"]
	warden.state = "defeated"
	warden.day = 3
	return s


func _w(d: Dictionary, id: String) -> Dictionary:
	return d["state"]["floor_states"][id]["world"]


## S1 (M-S1 쓰는 쪽이 stun 을 빠뜨림): 세 층의 FOE 기록(순회 경로 가운데·추적·돌아감·쓰러짐·쉼)을 쓰고 읽으면 같은 해시, world 키 여섯·기록 키 일곱.
func test_v10_roundtrip() -> void:
	var s := _three_floors()
	for variant in ["as built", "return"]:
		if variant == "return":
			s.floor_states["b1f"].world.foes["f1"].state = "return"
			s.floor_states["b2f"].world.foes["f2"].state = "return"
		var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
		check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판 머리" % variant)
		for id in ["b1f", "b2f", "b3f"]:
			var keys: Array = _w(doc, id).keys()
			keys.sort()
			check_eq(keys, ["chests_opened", "foes", "gather_used", "locks_open", "passages_found", "shortcuts_open"], "%s: %s world 키 여섯" % [variant, id])
			for fid in _w(doc, id)["foes"]:
				var rk: Array = _w(doc, id)["foes"][fid].keys()
				rk.sort()
				check_eq(rk, REC_KEYS, "%s: %s.%s 기록 키 일곱" % [variant, id, fid])
		if variant == "as built":
			check_eq(_w(doc, "b1f")["foes"], {"f1": {"at": [14.0, 9.0], "facing": "W", "state": "patrol", "path_i": 2.0, "dir": -1.0, "stun": 1.0, "day": 0.0}}, "숫양 기록")
			check_eq(_w(doc, "b2f")["foes"]["f2"]["state"], "chase", "탐험가 추적")
			check_eq(_w(doc, "b3f")["foes"], {"f3": {"at": [16.0, 3.0], "facing": "N", "state": "defeated", "path_i": 0.0, "dir": 1.0, "stun": 0.0, "day": 3.0}}, "경비기 쓰러짐")
		var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
		check(r.ok(), "%s: 읽기 %s" % [variant, r.error])
		if r.ok():
			check_eq([SaveCodec.state_hash(r.state), r.from_schema, r.relocated], [SaveCodec.state_hash(s), 11, false], "%s: 같은 해시, 11판" % variant)
			var ram: WorldState.FoeState = r.state.floor_states["b1f"].world.foes["f1"]
			check_eq([ram.at, ram.facing, ram.path_i, ram.dir, ram.stun], [Vector2i(14, 9), Dir.W, 2, -1, 1], "%s: 읽은 숫양" % variant)


## 접촉 전투 대기 상태: B1F (11,9) 에서 동쪽 처음 칸의 숫양에 부딪힌다.
func _contact() -> ExplorationState:
	var s := ExplorationRules.new_game(Fx.arbor(), 31, "full")
	s.party.at = Vector2i(11, 9)
	s.party.facing = Dir.E
	ExplorationRules.apply(s, A.FORWARD, "full")
	assert(s.battle != null and s.battle.foe == "f1")
	return s


## S2 (M-S2a 파티 칸의 FOE 를 받음, M-S2b 전투 없이 battle 상태를 받음, M-R1b' 순회 자리 ≠ path[path_i] 를 받음): 10판 거부(상태를 만들지 않는다).
func test_v10_rejects() -> void:
	var s := _three_floors()
	var defs := s.defs
	var foe := func(d: Dictionary, id: String, fid: String) -> Dictionary: return _w(d, id)["foes"][fid]
	_reject(s, func(d): _w(d, "b1f")["foes"]["zz"] = foe.call(d, "b1f", "f1").duplicate(), "floor_states.b1f.world.foes: zz 는 이 층의 FOE 가 아니다", "모르는 id")
	_reject(s, func(d): _w(d, "b1f")["foes"]["f2"] = foe.call(d, "b2f", "f2").duplicate(), "floor_states.b1f.world.foes: f2 는 이 층의 FOE 가 아니다", "다른 층 id")
	_reject(s, func(d): _w(d, "b1f")["foes"] = [], "floor_states.b1f.world.foes: 객체가 아니다", "배열")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["state"] = "idle", "floor_states.b1f.world.foes.f1.state: patrol FOE 가 가질 수 없는 상태다", "순회에 idle")
	_reject(s, func(d): foe.call(d, "b3f", "f3")["state"] = "chase", "floor_states.b3f.world.foes.f3.state: guard FOE 가 가질 수 없는 상태다", "문지기에 chase")
	_reject(s, func(d): foe.call(d, "b2f", "f2")["state"] = "patrol", "floor_states.b2f.world.foes.f2.state: chase FOE 가 가질 수 없는 상태다", "경로 없는 추적에 patrol")
	var ice := Vector2i(-1, -1)
	var b3 := defs.floor_by_id("b3f")
	for y in b3.height:
		for x in b3.width:
			if ice.x < 0 and b3.cell_kind(Vector2i(x, y)) == FloorModel.Cell.ICE:
				ice = Vector2i(x, y)
	var stair := defs.floor_by_id("b1f").stair_list()[0].at
	var gate := defs.floor_by_id("b1f").start_at
	for x in [["얼음", "b3f", "f3", ice], ["계단", "b1f", "f1", stair], ["마을 문(시작 칸)", "b1f", "f1", gate], ["밖", "b1f", "f1", Vector2i(99, 0)]]:
		var c: Vector2i = x[3]
		_reject(s, func(d): foe.call(d, x[1], x[2])["at"] = [c.x, c.y], "floor_states.%s.world.foes.%s.at: 이 층에서 FOE 가 설 수 있는 칸이 아니다" % [x[1], x[2]], "%s 칸" % x[0])
	_reject(s, func(d): foe.call(d, "b1f", "f1").merge({"at": [13, 9], "path_i": 1}, true), "floor_states.b1f.world.foes.f1.at: 파티가 선 칸이다", "파티 칸(경로 자리 맞춤)")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["at"] = [15, 9], "floor_states.b1f.world.foes.f1.at: 순회 중인 FOE 는 경로 자리 path[2] 14:9 에 서야 한다", "순회 자리 ≠ path[path_i]")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["path_i"] = 3, "floor_states.b1f.world.foes.f1.at: 순회 중인 FOE 는 경로 자리 path[3] 15:9 에 서야 한다", "path_i ≠ 자리")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["facing"] = "X", "floor_states.b1f.world.foes.f1.facing: N·E·S·W", "방향")
	for v in [6, -1, 1.5, true]:
		_reject(s, func(d): foe.call(d, "b1f", "f1")["path_i"] = v, "floor_states.b1f.world.foes.f1.path_i: 정수 0~5 이어야 한다", "path_i %s" % str(v))
	_reject(s, func(d): foe.call(d, "b2f", "f2")["path_i"] = 1, "floor_states.b2f.world.foes.f2.path_i: 정수 0~0 이어야 한다", "경로 없는 path_i 1")
	for v in [0, 2, true]:
		_reject(s, func(d): foe.call(d, "b1f", "f1")["dir"] = v, "floor_states.b1f.world.foes.f1.dir: 1 또는 -1", "dir %s" % str(v))
	_reject(s, func(d): foe.call(d, "b1f", "f1")["stun"] = 3, "floor_states.b1f.world.foes.f1.stun: 정수 0~2 이어야 한다(쓰러졌으면 0)", "stun 3")
	_reject(s, func(d): foe.call(d, "b3f", "f3")["stun"] = 1, "floor_states.b3f.world.foes.f3.stun: 정수 0~2 이어야 한다(쓰러졌으면 0)", "쓰러졌는데 stun 1")
	_reject(s, func(d): foe.call(d, "b3f", "f3")["day"] = 0, "floor_states.b3f.world.foes.f3.day: 쓰러진 FOE 는 정수 1~99999", "쓰러진 날 0")
	_reject(s, func(d): foe.call(d, "b3f", "f3")["day"] = 5, "floor_states.b3f.world.foes.f3.day: 쓰러진 날 5 이 지금 날 4 보다 뒤다", "쓰러진 날이 앞날")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["day"] = 2, "floor_states.b1f.world.foes.f1.day: 쓰러지지 않은 FOE 는 0", "살아 있는데 날")
	_reject(s, func(d): foe.call(d, "b1f", "f1").erase("stun"), "floor_states.b1f.world.foes.f1.stun 가 없다", "키 없음")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["x"] = 1, "floor_states.b1f.world.foes.f1.x 는 모르는 필드다", "모르는 키")
	_reject(s, func(d): foe.call(d, "b1f", "f1")["state"] = "battle", "floor_states.b1f.world.foes.f1.state: battle 는 지금 층의 전투 중에만", "전투 없이 battle")
	_reject(s, func(d): foe.call(d, "b2f", "f2")["state"] = "join", "floor_states.b2f.world.foes.f2.state: join 는 지금 층의 전투 중에만", "다른 층의 join")
	_reject(s, func(d): _w(d, "b1f").erase("foes"), "floor_states.b1f.world.foes 가 없다", "10판에 foes 없음")
	var v9_head := func(d: Dictionary) -> void:
		d.merge({"schema": 9, "rules": "m3g"}, true)
		Fx.strip_guild(d)  # M3 A7: 11판 길드 값은 걷어 내고 world 의 foes 만 남긴다
	_reject(s, v9_head, "9판 검사 실패: floor_states.b1f.world.foes 는 모르는 필드다", "9판 world 에 foes")
	_reject(s, func(d): d["rules"] = "m3g", "규칙 판(rules)이 schema 11 와 맞지 않다", "11판 머리에 m3g")
	_reject(s, func(d): d.merge({"schema": 9, "rules": "m3o"}, true), "규칙 판(rules)이 schema 9 와 맞지 않다", "9판 머리에 m3o")
	_reject(s, func(d): d["schema"] = 12, "지원하지 않는 schema 다", "12판")


## S2: 한 층에서 살아 있는 FOE 둘이 한 칸에 서면 거부(시험 층, FOE 둘).
func test_two_foes_on_one_cell() -> void:
	var f := Fx.floor_of(Fx.row_grid("......", "     "), {"foes": [
		{"id": "a", "foe": "foe.ether_ram", "kind": "patrol", "at": [2, 0], "facing": "E", "path": [[2, 0], [3, 0]], "join": 4, "respawn": "never"},
		{"id": "b", "foe": "foe.warden", "kind": "guard", "at": [5, 0], "facing": "W", "respawn": "never"}]})
	var s := ExplorationRules.new_game(Fx.defs(f), 3, "full")
	var r := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s), "준비: 두 FOE 층 왕복 %s" % r.error)
	_reject(s, func(d): _w(d, "fx")["foes"]["b"]["at"] = [2, 0], "floor_states.fx.world.foes.b.at: FOE a 와 같은 칸이다", "같은 칸 둘(문지기를 순회 칸으로)")
	var ok: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	_w(ok, "fx")["foes"]["a"].merge({"at": [5, 0], "state": "defeated", "day": 1}, true)
	check(SaveCodec.decode(JSON.stringify(ok), s.defs).ok(), "쓰러진 FOE 는 칸을 차지하지 않는다")


## S2: 접촉 전투(battle.foe)는 위험도가 한계값 아래여야 하고, 인카운트 전투는 예전대로 위험도 >= 한계값. battle.foe 는 이 층 FOE·그 무리.
func test_contact_battle_checks() -> void:
	var s := _contact()
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	check_eq([doc["state"]["battle"]["foe"], doc["state"]["battle"]["formation"], _w(doc, "b1f")["foes"]["f1"]["state"]], ["f1", "formation.foe.ether_ram", "battle"], "접촉 전투 문서")
	check(doc["state"]["encounter"]["danger"] < doc["state"]["encounter"]["threshold"], "준비: 위험도는 한계값 아래")
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(r.ok() and SaveCodec.state_hash(r.state) == SaveCodec.state_hash(s) and r.state.battle.foe == "f1", "접촉 전투 왕복 %s" % r.error)
	_reject(s, func(d): d["state"]["encounter"]["danger"] = d["state"]["encounter"]["threshold"], "FOE 접촉 전투인데 위험도가 한계값 이상이다", "접촉인데 위험도 >= 한계")
	_reject(s, func(d): d["state"]["battle"]["foe"] = "f9", "battle.foe: 이 층의 FOE 가 아니다", "모르는 FOE")
	_reject(s, func(d): d["state"]["battle"]["formation"] = "formation.foe.warden", "battle.formation: 접촉한 FOE f1 의 무리가 아니다", "다른 무리")
	_reject(s, func(d): _w(d, "b1f")["foes"]["f1"]["state"] = "patrol", "battle 상태인 FOE [] 가 전투의 FOE [\"f1\"] 와 맞지 않다", "battle 상태 아님")
	var no_foe := func(d: Dictionary) -> void:
		d["state"]["battle"].erase("foe")
		d["state"]["encounter"]["danger"] = d["state"]["encounter"]["threshold"]  # 인카운트 전투로 맞춘다
	_reject(s, no_foe, "battle.formation", "foe 없는 FOE 무리(출현 표에 없다)")
	# 인카운트 전투(9판 고정 문서)는 battle 에 foe 키가 없고, 위험도 < 한계값이면 거부.
	var b := SaveCodec.decode(V9_BATTLE, Fx.arbor())
	check(b.ok() and b.state.battle.foe.is_empty(), "9판 인카운트 전투 %s" % b.error)
	if b.ok():
		var bd: Dictionary = JSON.parse_string(SaveCodec.encode(b.state))
		check(not bd["state"]["battle"].has("foe"), "인카운트 battle 에 foe 키 없음")
		_reject(b.state, func(d): d["state"]["encounter"]["danger"] = d["state"]["encounter"]["threshold"] - 1, "전투 대기(pending)와 위험도 >= 한계값이 맞지 않다", "인카운트인데 위험도 < 한계")
		var add_foe := func(d: Dictionary) -> void:
			d["state"]["battle"]["foe"] = "f2"
			d["state"]["encounter"]["danger"] = d["state"]["encounter"]["threshold"] - 1  # 접촉 전투로 맞춘다
		_reject(b.state, add_foe, "battle.formation: 접촉한 FOE f2 의 무리가 아니다", "인카운트 무리에 foe")


## 9판 문서가 담은 필드는 10판으로 옮긴 뒤에도 같고, 더해진 것은 층 기록 world 의 처음 FOE 기록뿐인지. moved 는 settle 이 바꾼 FOE 필드(층 → id → {필드: 값}).
func _check_kept(label: String, text: String, defs: GameDefs, moved: Dictionary = {}) -> SaveCodec.LoadResult:
	var orig: Dictionary = JSON.parse_string(text)
	var r := SaveCodec.decode(text, defs)
	check(r.ok(), "%s: 읽기 %s" % [label, r.error])
	if not r.ok():
		return r
	check_eq([r.from_schema, r.relocated, r.saved_at, r.generation], [9, false, orig["saved_at"], int(orig["generation"])], "%s: 9판·옮김 없음·saved_at·generation" % label)
	var sv := Fx.strip_v11(SaveCodec.state_to_dict(r.state), r.state.defs)  # M3 A7: 11판이 더한 길드 값은 기본값이어야 하고, 견주기에서는 뺀다
	check_eq(sv["bad"], "", "%s: 11판 길드 값은 기본값" % label)
	var now: Dictionary = sv["state"]
	var o: Dictionary = orig["state"]
	for id in o["floor_states"]:
		check(not o["floor_states"][id]["world"].has("foes"), "%s: 원본 %s 에는 FOE 기록이 없다" % [label, id])
		var fresh := Fx.fresh_foes(id)
		for fid in moved.get(id, {}):
			fresh[fid].merge(moved[id][fid], true)
		o["floor_states"][id]["world"]["foes"] = fresh
	for k in o:
		check_eq(V7._norm(now[k]), V7._norm(o[k]), "%s: %s 보존" % [label, k])
	check_eq(now.keys().filter(func(k: String) -> bool: return not o.has(k)), [], "%s: 맨 위에 더해진 필드 없음" % label)
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
	check_eq([doc["schema"], doc["rules"]], [11.0, "m3r"], "%s: 11판으로 쓴다" % label)
	var again := SaveCodec.decode(JSON.stringify(doc), defs)
	check(again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state), "%s: 11판 다시 읽기 같은 해시 %s" % [label, again.error])
	return r


## S3 (M-S3 옛 저장을 읽은 뒤 settle 하지 않음, M-R1a' 비킨 칸에 경로 자리를 맞추지 않음): HEAD 코드로 만든 9판 고정 문서를 게임 묶음으로 읽으면 10판, 원래 필드는 그대로.
## 파티가 숫양의 시작 칸 (12,9) 에 선 문서는 숫양이 (13,9) 로 비킨다(FOE 걸음 너비 우선, N·E·S·W: (12,8) 은 FOE 칸이 아니고 동쪽 (13,9) 가 처음).
func test_fixed_v9_strings_migrate() -> void:
	var defs := Fx.arbor()
	var town := _check_kept("9판 마을", V9_TOWN, defs)
	if town.ok():
		check_eq([town.state.day, town.state.location, town.state.floor_states.keys(), town.state.floor_states["b1f"].world.gather_used],
			[3, "town", ["b1f", "b2f", "b3f"], {"g1": 1}], "9판 마을: 날·마을·세 층·채집 기록")
	var battle := _check_kept("9판 전투", V9_BATTLE, defs)
	if battle.ok():
		check(battle.state.encounter.pending and battle.state.battle != null and battle.state.battle.foe.is_empty()
			and battle.state.battle.formation == "formation.b2.beetles", "9판 전투: 인카운트 전투 대기 그대로")
	var wiped := _check_kept("9판 전멸", V9_WIPED, defs)
	if wiped.ok():
		check(wiped.state.wiped and wiped.state.day == 4, "9판 전멸")
	var on := _check_kept("9판 숫양 칸", V9_ON_FOE, defs, {"b1f": {"f1": {"at": [13, 9], "path_i": 1}}})
	if on.ok():
		check_eq([on.state.party.at, _rec(on.state, "f1"), FoeRules.foe_at(on.state, Vector2i(12, 9))], [Vector2i(12, 9), [Vector2i(13, 9), Dir.E, 1, "patrol", 0], ""],
			"파티는 (12,9), 숫양은 (13,9) 로 비킴(경로 자리 path_i 1 로 맞춤, 리뷰 R1)")
		var ev := ExplorationRules.apply(on.state, A.FORWARD, "full")
		check_eq([Fx.types(ev), on.state.party.at], [["foe_contact", "encounter"] as Array[String], Vector2i(12, 9)], "읽은 뒤 동쪽으로 걸으면 비킨 숫양과 부딪힌다")
	var bad: Dictionary = JSON.parse_string(V9_TOWN)
	bad["state"]["consumables"]["use.medica"] = 0
	var rb := SaveCodec.decode(JSON.stringify(bad), defs)
	check(not rb.ok() and rb.state == null and rb.error.begins_with("9판 검사 실패: "), "깨진 9판 %s" % rb.error)


## R1 (리뷰): 9판 숫양 칸 문서를 읽으면 비킨 숫양이 순회를 잇는다. 실제 걸음 열둘, 걸음마다 저장 → 읽기. 칸은 고정 값.
## 파티 (12,9) 동쪽 → 뒤로 (11,9) → 뒤로 (10,9) → 앞뒤로 (11,9)·(10,9). 숫양 (13,9) path_i 1 에서: 14·15·16·17, 돌기, 16·15·14·13·12, 돌기, 13.
func test_v9_on_foe_resumes_patrol() -> void:
	var defs := Fx.arbor()
	var r := SaveCodec.decode(V9_ON_FOE, defs)
	check(r.ok(), "읽기 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	var cells: Array[Vector2i] = []
	var party: Array[Vector2i] = []
	for i in 12:
		ExplorationRules.apply(s, A.BACK if i < 2 or i % 2 == 1 else A.FORWARD, "full")
		if s.encounter.pending:
			check(s.battle.foe.is_empty(), "%d: 인카운트 전투만(숫양과 접촉 없음)" % i)
			BattleRules.finish(s, "victory")
		var again := SaveCodec.decode(SaveCodec.encode(s), defs)
		check(again.ok() and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(s), "%d: 저장 → 읽기 %s" % [i, again.error])
		if not again.ok():
			return
		s = again.state
		cells.append(s.world.foes["f1"].at)
		party.append(s.party.at)
	check_eq(party, [Vector2i(11, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 9),
		Vector2i(11, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 9), Vector2i(11, 9), Vector2i(10, 9)] as Array[Vector2i], "준비: 파티 자리 열둘")
	check_eq(cells, [Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9), Vector2i(17, 9), Vector2i(16, 9),
		Vector2i(15, 9), Vector2i(14, 9), Vector2i(13, 9), Vector2i(12, 9), Vector2i(12, 9), Vector2i(13, 9)] as Array[Vector2i], "숫양 칸 열둘(왕복)")
	check_eq([s.world.foes["f1"].state, s.world.foes["f1"].path_i, s.world.foes["f1"].dir], ["patrol", 1, 1], "순회 그대로")


## R1 (리뷰): 경로 밖으로 비킨 순회는 return 이 되어 path[path_i] 로 돌아간 뒤 순회한다. 시험 층 9판 문서(지금 판 문서를 9판 머리로 고치고 foes 를 지움).
func test_off_path_settle_returns() -> void:
	var grid := ["+-+-+-+-+-+", "|. . . . .|", "+ + + + + +", "|. . . . .|", "+-+-+-+-+-+"]
	var f := Fx.floor_of(grid, {"foes": [{"id": "p", "foe": "foe.ether_ram", "kind": "patrol", "at": [2, 1], "facing": "E", "path": [[2, 1], [3, 1]],
		"join": 2, "respawn": "never"}]})
	var t := ExplorationRules.new_game(Fx.defs(f), 3, "full")
	t.party.at = Vector2i(2, 1)
	t.party.facing = Dir.W
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(t))
	doc.merge({"schema": 9, "rules": "m3g"}, true)
	Fx.strip_guild(doc)  # M3 A7
	for id in doc["state"]["floor_states"]:
		doc["state"]["floor_states"][id]["world"].erase("foes")
	var r := SaveCodec.decode(JSON.stringify(doc), t.defs)
	check(r.ok() and r.from_schema == 9, "9판으로 읽음 %s" % r.error)
	if not r.ok():
		return
	var s := r.state
	check_eq(_rec(s, "p"), [Vector2i(2, 0), Dir.E, 0, "return", 0], "북쪽 (2,0)(경로 밖)으로 비키고 return")
	ExplorationRules.apply(s, A.FORWARD, "full")
	check_eq([s.party.at, _rec(s, "p")], [Vector2i(1, 1), [Vector2i(2, 1), Dir.S, 0, "patrol", 0]], "파티가 비키자 path[0] (2,1) 로 돌아와 순회")
	var again := SaveCodec.decode(SaveCodec.encode(s), s.defs)
	check(again.ok(), "돌아온 순회는 10판으로 저장·읽기 %s" % again.error)


## R3 (M-R3 1판에서 settle 을 건너뜀, 리뷰 R3): 1판 꼴 문서(B1F, 파티 (12,9))도 읽히고 숫양은 (13,9)·path_i 1 로 비킨다.
func test_v1_on_foe_settles() -> void:
	var d: Dictionary = JSON.parse_string(V9.BS.V1_NORMAL)
	d["state"]["floor"] = "b1f"
	d["state"]["party"]["at"] = [12, 9]
	d["state"]["world"] = {"shortcuts_open": [], "passages_found": []}
	d["state"]["knowledge"] = {"visited": [], "edges": {}}
	d["state"]["annotation"] = {"floors": {}, "edges": {}, "auto_edges": [], "icons": {}, "memos": {}}
	var r := SaveCodec.decode(JSON.stringify(d), Fx.arbor())
	check(r.ok() and r.from_schema == 1, "1판 숫양 칸 문서 읽힘 %s" % r.error)
	if r.ok():
		check_eq([r.state.party.at, _rec(r.state, "f1")], [Vector2i(12, 9), [Vector2i(13, 9), Dir.E, 1, "patrol", 0]], "숫양은 (13,9)·path_i 1")


func _rec(s: ExplorationState, id: String) -> Array:
	var fs: WorldState.FoeState = s.world.foes[id]
	return [fs.at, fs.facing, fs.path_i, fs.state, fs.stun]


## S4: 1~8판 고정 문서도 모두 10판이 되고 층 기록마다 처음 FOE 기록이다(시험 층은 빈 기록).
func test_every_old_schema_has_fresh_foes() -> void:
	var test_set := [["1판 보통", V9.BS.V1_NORMAL], ["2판 전투", V9.GS.V2_BATTLE], ["4판 장치", V9.V5.V4_DEVICES], ["5판 두 층", V9.V6.V5_TWO_FLOORS],
		["6판 전멸", V7.V6_WIPED]]
	var game_set := [["7판 마을", V8.V7_TOWN], ["7판 전투", V8.V7_BATTLE], ["8판 마을", V9.V8_TOWN], ["8판 전투", V9.V8_BATTLE], ["8판 전멸", V9.V8_WIPED]]
	for pair in [[test_set, Fx.defs()], [game_set, Fx.arbor()]]:
		for x in pair[0]:
			var r := SaveCodec.decode(x[1], pair[1])
			check(r.ok(), "%s: 이전 성공 %s" % [x[0], r.error])
			if not r.ok():
				continue
			var now := SaveCodec.state_to_dict(r.state)
			for id in now["floor_states"]:
				check_eq(V7._norm(now["floor_states"][id]["world"]["foes"]), V7._norm(Fx.fresh_foes(id)), "%s: %s 처음 FOE 기록" % [x[0], id])
			var doc: Dictionary = JSON.parse_string(SaveCodec.encode(r.state))
			var again := SaveCodec.decode(JSON.stringify(doc), pair[1])
			check(doc["schema"] == 11.0 and again.ok() and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(r.state),
				"%s: 10판으로 쓰고 다시 읽기 같은 해시" % x[0])


## S5: 9판 시험 층 저장을 게임 묶음으로 읽으면 마을로 옮기고, B1F 기록 하나에 처음 FOE 기록.
func test_relocation_fresh_foes() -> void:
	var defs := Fx.arbor()
	var r := SaveCodec.decode(V9_TEST, defs)
	check(r.ok() and r.relocated and r.from_schema == 9, "옮겨 읽음 %s" % r.error)
	if not r.ok():
		return
	var n := r.state
	check_eq([n.floor_states.keys(), n.location, n.day, _rec(n, "f1")], [["b1f"], "town", 6, [Vector2i(12, 9), Dir.E, 0, "patrol", 0]], "B1F 기록 하나, 마을, 6일째, 처음 숫양")
	var again := SaveCodec.decode(SaveCodec.encode(n), defs)
	check(again.ok() and not again.relocated and again.from_schema == 11 and SaveCodec.state_hash(again.state) == SaveCodec.state_hash(n), "11판으로 다시 쓰고 읽음 %s" % again.error)


## S6 (M-S6 모든 FOE id 를 요구): 10판 world.foes 에 없는 FOE 는 처음 상태로 읽는다(자료에 FOE 가 늘어도 옛 10판이 읽힌다).
func test_missing_record_reads_fresh() -> void:
	var s := _three_floors()
	var doc: Dictionary = JSON.parse_string(SaveCodec.encode(s))
	_w(doc, "b1f")["foes"] = {}
	_w(doc, "b2f")["foes"].erase("f2")
	var r := SaveCodec.decode(JSON.stringify(doc), s.defs)
	check(r.ok(), "빠진 기록도 읽힘 %s" % r.error)
	if r.ok():
		var ram: WorldState.FoeState = r.state.floor_states["b1f"].world.foes["f1"]
		var delver: WorldState.FoeState = r.state.floor_states["b2f"].world.foes["f2"]
		check_eq([ram.at, ram.state, ram.path_i, ram.stun, delver.at, delver.state], [Vector2i(12, 9), "patrol", 0, 0, Vector2i(5, 10), "idle"], "처음 상태로")
		check_eq(r.state.floor_states["b3f"].world.foes["f3"].state, "defeated", "있는 기록은 그대로")


func teardown() -> void:
	Fx.clean_saves()
	super()
