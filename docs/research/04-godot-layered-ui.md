# Godot 층 겹침 배치 참고 (2026-10-18)

UI 작업 지시서의 기준으로 쓰려고 Godot의 그리기 순서·입력 순서 규칙과 원작의 겹침 구성을 모았다. 따로 말하지 않으면 AI 에이전트가 화면을 웹 CSS처럼 겹치지 않는 칸으로 나누는 경향이 있어서다(사용자 관찰, 2026-10-18).

엔진 사실(공식 문서·엔진 소스에서 확인)과 설계 제안(「원칙」 절)을 나눠 적는다.

## 결론

- **기준으로 쓸 수 있다.** 그리기 순서와 입력 순서가 공식 문서와 엔진 소스(4.7.2)로 분명히 정해져 있다. UI 지시서에 아래 「원칙」과 층 표를 넣어 쓴다.
- 지금 코드는 이미 컨테이너 대신 좌표로 놓고(`_layout`), 트리 순서(`add_child` 순서)로 겹친다. `CanvasLayer`·`z_index`는 쓰지 않는다(2026-10-18 `grep`). 그래서 지금 화면이 칸 나누기처럼 보이는 것은 엔진 기능이 모자라서가 아니라 **배치 설계**(서로 겹치지 않는 띠·같은 크기 상자) 때문이다. 엔진 기능만 알려 주면 같은 결과가 다시 나오므로 설계 원칙을 함께 준다.

- 적용: M2.6 2.5단계(2026-10-18)에서 전투(06 §9.8 층 표)·파티 메뉴(07 §9.2)·메뉴 창과 지도를 접은 탐색(05 §9.1)에 썼다. 시험 쪽 요령: 헤드리스에서는 `Viewport.gui_get_hovered_control()`이 비어 있어 누르기 대상은 `gui_input` 기록으로 확인한다. 헤드리스 창은 64×64로 시작하므로 누르는 시험은 `root.size`를 정하고 `get_final_transform()`으로 좌표를 바꾼다. 크기만 보려고 만들고 트리에 넣지 않은 Control은 시험에서 직접 `free()` 한다(남기면 한 프로세스 전체 실행 끝에 RID·자원 누수 줄이 나온다).

## 원작의 겹침 (조정자가 캡처를 보고 적음)

| 화면 | 구성 |
|---|---|
| I·II·III HD 설명서 전투 명령 (research 03 출처 표, 온라인 설명서 3쪽) | 전투 배경이 화면 전체. 왼쪽 가장자리 초상화 위에 굽은 명령 목록이 겹친다. 파티 카드는 배경 위 아래 가운데에 작은 반투명 카드로 떠 있고 카드 사이로 배경이 보인다. 오른쪽 아래 작은 지도, 위쪽 턴·안내 띠도 배경 위에 얹힌다 |
| V 전투 (`sq-atlus.jp/sq5/system/`) | 평행사변형 파티 카드 2줄(위 2·아래 3, 엇갈림)이 배경과 적 발치 위에 겹친다. 기울어진 시각·턴 문패가 왼쪽 위 모서리에 걸친다 |
| 지금 (M2.6 1단계 뒤 전투 명령 캡처) | 아래 전체 폭 불투명 띠(파티 줄), 오른쪽 사각 명령 패널, 적 영역이 서로 겹치지 않는 세 칸 |

## Godot 기능 (공식 문서)

| 기능 | 문서가 말하는 것 | 이 게임에서 쓸 곳 |
|---|---|---|
| 트리 순서 | 「Canvas items are drawn in tree order on their canvas layer」, 기본으로 자식이 부모 위 | 겹침의 기본 수단. 나중에 붙인 형제가 위 |
| `CanvasLayer` | 자식 전체를 따로 그리는 2D 층. 「Layers with a greater number will be drawn above those with a smaller number」. HUD·UI 예시 | 3D 시야 위 HUD·모달·알림을 층으로 묶을 때 |
| `z_index`·`z_as_relative` | 그리는 순서만 바꾼다. 「The Z index does not affect the order in which CanvasItem nodes are processed or the way input events are handled. This is especially important to keep in mind for Control nodes.」 | 누르지 않는 장식(빛·그림자·피해 숫자)에만 |
| `top_level` | 부모 변환을 따르지 않고, top_level이 아닌 것들 위에 그린다 | 떠 있는 피해 숫자·끌기 미리보기 |
| `show_behind_parent` | 부모 뒤에 그린다 | 창 뒤로 삐져나온 장식 |
| `clip_contents`(Control) / `clip_children`(CanvasItem) | 사각형 자르기 / 그린 모양으로 가리기(마스크). `clip_children`은 겹쳐 쓰거나 `CanvasGroup` 안에 넣을 수 없다 | 스크롤 목록 / 깎은 창 안 초상화 |
| `mouse_filter` | STOP(받고 멈춤)·PASS(안 쓰면 부모로)·IGNORE(마우스 입력을 받지 않음) | 장식 층은 IGNORE |
| 기준점·여백(anchors·offsets) | 여백을 음수로 하면 가장자리가 기준점 밖으로 나간다 | 문패·탭·초상화를 창 테두리에 걸치기 |
| `NinePatchRect`·`StyleBoxTexture` | 9칸 나눔으로 모서리는 두고 가장자리·가운데만 늘리거나 반복 | M3 그림 창 테두리(U10) |
| `CanvasGroup` | 자식들을 한 번에 그린다. 겹친 반투명 부분이 더 진해지지 않는다. 뒤 버퍼를 읽는 셰이더를 쓴다 | 반투명 카드 묶음을 한꺼번에 흐리게 |
| 화면 읽기 셰이더(`hint_screen_texture`·`BackBufferCopy`) | 화면 복사는 처음 한 번만 자동. 겹친 두 번째는 첫째 결과를 못 본다. 밉맵 필터면 `textureLod`로 흐린 화면을 읽는다 | 창 뒤 흐린 유리(선택) |

## 입력 순서 (엔진 소스 4.7.2에서 확인)

- `Viewport::gui_find_control`은 GUI 뿌리(부모가 Control이 아닌 Control, `top_level` Control) 목록을 `Control::CComparator`로 정렬한다. 정렬 기준은 캔버스 층 오름차순이고, 같은 층이면 트리 순서다. 고를 때는 목록 **뒤에서부터**(가장 높은 층, 트리에서 가장 뒤) 본다.
- `_gui_find_control_at_pos`는 자식을 **마지막부터 처음으로** 본다(나중에 붙인 형제 = 위에 그려진 것이 먼저). `top_level` 자식은 건너뛰고 뿌리로만 본다. `MOUSE_FILTER_IGNORE`인 Control은 고르지 않지만 그 자식은 본다. `clip_contents`면 점이 그 안일 때만 자식을 본다.
- `z_index`는 이 함수들에 나오지 않는다.
- 그래서: **보이는 위아래와 누르는 위아래를 같게** 하려면 겹침을 트리 순서나 `CanvasLayer`로 만든다. `z_index`로만 위에 올린 Control은 트리에서 뒤에 있는 형제에게 입력을 빼앗길 수 있다.

## 원칙 (제안, UI 지시서에 넣는다)

1. 화면을 칸으로 나누지 말고 **층 목록**으로 적는다. 예: 바탕(3D 시야·전투 배경, 화면 전체) → 세계 위 표시(적·피해 숫자) → HUD(파티 카드·턴 문패, 바탕 위에 뜸) → 창(명령·스킬·결과) → 모달 → 알림.
2. 바탕은 늘 화면 전체다. HUD·창은 바탕 위에 떠 있고 사이로 바탕이 보인다. 화면 전체 폭의 불투명 띠는 필요한 경우만 쓴다.
3. 문패·초상화·탭은 음수 여백으로 창 테두리에 걸친다.
4. 같은 크기 상자를 격자로 늘어놓기보다 엇갈림·기울기·크기 차이로 위계를 만든다(V·X의 평행사변형 카드, 위 2·아래 3 엇갈림).
5. 입력: 보이는 순서 = 트리 순서. `z_index`는 누르지 않는 장식에만 쓴다. 장식 층은 `mouse_filter = IGNORE`. 누르는 것은 기준 해상도에서 64px 이상(05 §9.1) 그대로다.
6. 지시서에는 층 표(층 / 내용 / 기준점과 겹치는 상대 / 입력 받음 여부)를 함께 적는다.
7. 확인: 캡처에서 HUD 사이로 바탕이 보이는지, 겹친 곳을 누르면 보이는 위 칸이 받는지(장면 시험).

## 아직 확인하지 않은 것

- `clip_children`·`CanvasGroup`·화면 읽기 셰이더의 흐림(밉맵)이 웹 빌드(Compatibility 렌더러)에서 데스크톱과 같게 보이는지. 쓰기 전에 xvfb 캡처와 `web_check`로 확인한다.
- 탐색 화면의 시야 6 : 지도 4 배치는 HD 리마스터와 같아 research 03 「그대로 둘 것」에 남긴다. 원칙은 전투·메뉴·결과 창에 먼저 쓴다.

## 출처

- Godot 문서 `CanvasItem`: https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
- Godot 문서 「Canvas layers」: https://docs.godotengine.org/en/stable/tutorials/2d/canvas_layers.html
- Godot 문서 `Control`: https://docs.godotengine.org/en/stable/classes/class_control.html
- Godot 문서 「Using InputEvent」: https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html
- Godot 문서 「Size and anchors」: https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html
- Godot 문서 `CanvasGroup`: https://docs.godotengine.org/en/stable/classes/class_canvasgroup.html
- Godot 문서 `NinePatchRect`: https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html
- Godot 문서 「Screen-reading shaders」: https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- Godot 4.7.2 소스 `scene/main/viewport.cpp`(`gui_find_control`·`_gui_find_control_at_pos`·`_gui_sort_roots`), `scene/gui/control.h`(`CComparator`): https://github.com/godotengine/godot/tree/4.7.2-stable
- 포럼 「Change input handling order for UI elements」(z_index는 입력 순서를 바꾸지 않는다는 답): https://forum.godotengine.org/t/change-input-handling-order-for-ui-elements/56601
- 원작 캡처 출처는 research 03 「출처」 표(이미지는 저장소에 넣지 않는다).
