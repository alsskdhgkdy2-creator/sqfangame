# 세계수의 미궁 조사 01 — 탐색·던전·마을·진행 구조

조사 기준일: 2026-10-16  
대상: I~V, 신 세계수의 미궁 1·2(Untold, 이하 U1·U2), X(Nexus), I·II·III HD REMASTER(2023).

전투·직업별 스킬·수치 공식은 별도 조사 범위이며, 이 문서는 탐색과 연결되는 부분만 다룬다. 후반 지역·보스·진행 구조에 관한 스포일러가 포함된다.

**확인 상태의 의미**

- **직접 읽음:** 해당 웹 문서의 관련 본문 또는 PDF 추출 텍스트를 읽었다. 게임 실행 검증을 의미하지 않는다.
- **검색 결과 요약만 봄:** 검색 발췌는 확인했지만 관련 원문을 충분히 열람하지 못했다.
- **미확인:** 채택할 근거가 부족하다.
- **추정:** 커뮤니티 관찰이나 내부 처리 방식에 대한 설명이며 공식적으로 확인한 규칙이 아니다.

본문의 출처 링크는 개별 문서로 연결된다. 마지막 출처 목록에도 원문 URL과 확인 범위를 기록했다. 설계 제안은 원작 사실과 구분한다.

## 1. 요약 — 팬게임에 우선 반영할 것

핵심 반복은 **준비 → 탐색·지도 작성 → 위험 판단 → 지름길 확보 → 귀환 → 소재 판매·회복·보고 → 재진입**이다. 공식 소개에서 설명하는 탐험과 마을 정비의 반복을 기획 관점으로 정리했다. [Origins 공식 소개][P03] — 직접 읽음.

- **반드시 넣을 것:** 1칸 이동·90도 회전, 고정 지도, 벽·문·지름길, 편집 지도와 오토맵, 위험도 표시, 회피 가능한 FOE, 소재 판매 해금, 마을 정비, 귀환·저장.
- **선택:** 낮밤, 식재료·야영·요리, 자동 이동, 지도 보고와 층 이동, 탐색 패시브, 그리모어·서브클래스.
- **빼도 되는 것:** 항해·대공 지도·도시 경영의 동시 구현, 고정 주인공과 자유 길드 모드의 동시 제작, 통신 기능, 반복 은퇴를 전제로 한 최대 성장.
- **주의할 차이:** 서브클래스는 **III에서 도입**되었다. II부터 모든 후속작에 있는 기능이 아니다. [III 시스템][W14] — 직접 읽음.
- **판본 구분:** Untold는 재구성한 리메이크이고, HD는 DS I·II·III 기반 리마스터다. HD에 Untold의 추가 던전·스토리가 포함된 것으로 취급하면 안 된다. [U1 공식 소개][P06], [I/HD FAQ][W06] — 직접 읽음.

위 우선순위는 첫 Godot 웹 버전을 위한 **설계 제안**이다.

## 2. 범위별 상세

### 2.1. 1인칭 그리드 탐색과 지형

#### 이동·회전·통로

기본 탐색은 사각 격자의 한 칸 이동과 직각 방향 전환이다. U1 공식 조작표는 전진·후진, 좌우 회전, L/R 평행 이동, 조사, 캠프, 지도 확대를 구분한다. **DS I에는 평행 이동이 없고 II 이후와 I HD에는 있다.** 이동 연출 속도와 격자 위치 판정은 별개로 보아야 한다. [U1 조작표][P05], [I/HD FAQ][W06] — 직접 읽음.

문은 일반 문, 열쇠로 잠긴 문, 장치로 여는 문을 구분한다. 숨은 통로는 벽처럼 보이는 곳을 조사하여 발견하는 지름길이다. 반대편에서 먼저 개방해야 하는 통로와 계속 한 방향으로만 통과하는 통로가 있으므로, “문이 보인다”와 “양방향으로 통과할 수 있다”는 별개다. [II HD 공식 지형 안내][P17], [I 시스템][W01], [II 던전 공략][W09] — 직접 읽음.

I FAQ는 던전 구조가 무작위 생성이 아니며 보물상자·대부분의 이벤트가 일회성이라고 설명한다. 따라서 원작식 탐색의 기준은 설계된 지도와 그 지식을 축적하는 진행이다. [I/HD FAQ][W06] — 직접 읽음.

#### 작품별 기믹 사례

| 작품 | 확인한 지형·기믹 | 출처·확인 |
|---|---|---|
| I | B26·B29 워프, B27 낙하 구멍, B28 피해 바닥. 여러 층을 오가며 연결을 추론하는 후반 구조 | [I 후반 던전][W05] — 직접 읽음 |
| II / II HD | 얼음 위에서 진행 방향으로 강제 이동, 피해 바닥, 장치식 문 | [SEGA II HD 소개][P17] — 직접 읽음 |
| II | 15F의 낮에는 통과할 수 없고 밤에 얼어 통과 가능한 구간. 같은 지역 FOE의 낮밤 활동 변화 | [II 15F][W10] — 직접 읽음 |
| II | 17~18F 낙하와 일방통행 통로를 결합한 동선 | [II 던전 공략][W09] — 직접 읽음 |
| III | B6의 수류에 의한 강제 이동. 대항해에서도 해류·장애물·식량이 항로를 제한 | [III 전반 던전][W17], [III 시스템][W14] — 직접 읽음 |
| IV | 제3미궁 지저호의 온도 장치가 얼음·수면·FOE 활동에 영향을 주는 사례 | [IV 지저호][W24] — 검색 결과 요약만 봄 |
| U1 | Gladsheim의 빛/어둠에 반응하는 FOE 사례 | [U1 FOE 공략][U05] — 검색 결과 요약만 봄 |
| U2 | Ginnungagap B1의 스위치식 도개교. 연결을 끊어 추적 FOE의 접근을 막으며, 교량 상태는 던전 밖으로 나가도 유지된다는 공략 설명 | [U2 Ginnungagap B1][U10] — 직접 읽음 |
| V | 제4계층의 결정 파괴·결정 사이 이동. 18F의 이동선과 착지 위치를 읽는 퍼즐 | [V 제4계층][W29] — 직접 읽음 |
| V | 제5계층의 부유 상태와 착지 장치 | [V 25F 공략][W30b] — 검색 결과 요약만 봄 |
| X | 사당의 높낮이, 제13미궁의 이동 바닥, 제11미궁의 일방통행 구간 | [X 미궁 안내][W37] — 직접 읽음 |

**구별할 것:** 미끄러운 얼음과 밤에 얼어 통행 가능해지는 얼음은 다른 규칙이다. 조사해서 작동하는 스위치와 밟고 있는 동안 작동하는 압력판도 구분해야 한다.

**미확인:** 전 작품의 압력판·무게 스위치·FOE가 대신 밟는 판의 존재와 세부 동작은 확인하지 못했다. 스위치 기믹이 있다는 사실만으로 이러한 기능까지 원작 공통 규칙으로 확장하지 않는다.

**설계 제안:** 벽·문·일방통행은 칸 사이의 경계 데이터로, 피해·미끄러짐·낙하·워프는 칸의 속성으로 분리한다.

### 2.2. 지도 작성·오토맵·터치 UX

#### 편집 도구

U1 공식 조작표에서 확인되는 기능은 벽 그리기·지우기, 바닥 색칠, 아이콘 끌어 놓기·삭제, 메모, 지도 확대, 자동 이동 경로다. 탐색 화면을 보며 아래 지도를 수정하고, 확대 지도에서 정밀 편집하는 구조다. [U1 조작표][P05] — 직접 읽음.

도구는 다음 기능군으로 정리할 수 있다.

| 기능군 | 기록 대상 | 주의점 |
|---|---|---|
| 벽·바닥·지우개 | 통로 윤곽, 탐색한 칸, 위험 구역 | 벽은 경계, 바닥은 칸에 입력 |
| 이동 아이콘 | 문, 계단, 워프, 낙하, 방향 화살표 | 아이콘 배치가 실제 통로 개방을 뜻하지 않음 |
| 탐색 아이콘 | 상자, 채집, 이벤트, 적 | 후속작에는 사용 전후 상태를 바꾸는 아이콘이 있음 |
| 메모 | 열쇠·시간 조건, 미해결 단서, 위험 | 작품별 배치 방법과 수량 제한이 다름 |
| 경로 도구 | 반복 이동용 경로 | 아이콘 배치 방식과 선 그리기 방식이 존재 |

위 분류는 [I 시스템][W01], [II 시스템][W07], [U2 시스템][U07], [V 시스템][W27]의 기능을 묶은 것이다. 모두 직접 읽음. 어느 한 작품의 완전한 아이콘 목록은 아니다.

#### 작품별 차이

| 작품 | 확인한 기능·차이 | 출처·확인 |
|---|---|---|
| DS I | 지나간 바닥 자동 색칠 선택. 벽·상자·계단 등은 수동 | [I/HD FAQ][W06] — 직접 읽음 |
| DS II | 바닥 3색, 아이콘 20종, 독립 메모 등 편집 도구 확대 | [II 시스템][W07] — 직접 읽음 |
| DS III | 바닥·아이콘 편집과 자동 이동. 후속작의 벽 자동 기록과 혼동하지 않을 것 | [III 시스템][W14] — 직접 읽음 |
| IV | 바닥 자동 기록은 있으나 벽은 수동이라는 플레이 기록 확인. 옵션 전체의 공식 대조는 미완료 | [IV 지도 기록][W26] — 검색 결과 요약만 봄 |
| U1 | OFF / ON / FULL. FULL에서 이동한 바닥과 주변 벽을 함께 기록 | [U1 시스템][U01] — 직접 읽음 |
| U2 | 바닥 8색, 상태 변경 아이콘, 선으로 자동 이동 경로를 그리는 기능 | [U2 시스템][U07], [U2 공식 안내][P12] — 직접 읽음 |
| V | OFF / ON / FULL, 바닥 8색·아이콘 40종, 팔레트 편집과 경로 그리기 | [V 시스템][W27] — 직접 읽음 |
| X | 터치 지도와 자동 매핑 공식 확인. 모든 아이콘·옵션 수는 별도 미확인 | [X 공식 시스템][P15] — 직접 읽음 |
| HD I·II·III | OFF 없음 / ON 바닥 / FULL 바닥·벽. Switch 터치·컨트롤러, Steam 마우스·키보드·컨트롤러. 좌우 배치와 커서 조정 | [HD 공식 Q&A][P01] — 직접 읽음 |

FULL은 미탐색 층 전체를 공개하는 기능이 아니다. HD에서도 상자·계단 같은 아이콘은 별도 기록이 남는다. [I/HD FAQ][W06] — 직접 읽음.

지도에 직접 그린 내용과 실제 통과 이력도 구별해야 한다. I의 전멸 후 지도 보존 설명에서도 지도 기록과 방문 판정의 차이가 드러난다. [I/HD FAQ][W06] — 직접 읽음.

#### 웹·모바일 설계 제안

- PC: 탐색 화면과 지도를 나란히 배치하고 키보드는 이동, 마우스는 지도 편집에 배정한다.
- 모바일: 지도 확대 편집과 탐색 버튼의 입력 영역을 분리한다.
- 벽 선은 넓은 선택 영역과 경계 스냅, 아이콘은 칸 스냅, 편집에는 실행 취소를 제공한다.
- 지도 이동·벽 그리기·아이콘 이동이 같은 드래그에 겹치지 않도록 활성 도구를 명확히 표시한다.
- 메모 입력 중 탐색 단축키를 막고, 색 외에 기호·무늬·이름으로도 지형을 구별한다.
- 자동 이동은 위험·새 이벤트·전투에서 중단하도록 한다.

위 항목은 자체 설계 제안이다. HD 개발자 인터뷰는 DS 화면·터치를 다른 입력 장치로 옮기는 과정에서 시제품과 조정이 필요했음을 설명한다. [HD 개발자 인터뷰][P16] — 직접 읽음.

### 2.3. 랜덤 인카운트

| 근거 수준 | 확인 내용 | 출처·확인 |
|---|---|---|
| 공식 설명 | U1의 적 출현 위험 표시는 파랑에서 빨강으로 갈수록 조우가 가까움을 알린다 | [U1 조작표][P05] — 직접 읽음 |
| 공략 설명 | V 위키는 단계별 색과 다음 조우까지의 보행량을 연결해 설명한다 | [V 시스템][W27] — 직접 읽음 |
| 관찰·추정 | II DS의 구역별 출현 편성 차이, 특정 지름길 통과 시 위험도·FOE 갱신 차이를 관찰한 자료가 있다. 확률 검증은 불완전하다고 명시 | [II 인카운트 관찰][W11] — 직접 읽음 |
| 미확인 | 모든 작품의 난수 초기화, 매 걸음 확률 판정인지 선추첨 보행 한도인지, 정확한 누적식·색 경계·보정 | 검증 가능한 통합 근거 미확보 |

“정확히 N걸음마다 전투”, “빨간색이면 다음 걸음에 반드시 전투”를 공통 사실로 쓰지 않는다. V 위키의 설명도 내부 구현까지 공식적으로 증명한 자료는 아니므로 **알고리즘 해석은 추정**으로 취급한다.

FOE 위협 색과 랜덤 인카운트 위험도는 다른 정보다. 전자는 보이는 특정 강적의 위협, 후자는 보이지 않는 일반 조우의 위험을 나타낸다. [V FOE][W28], [U1 조작표][P05] — 직접 읽음.

**설계 제안:** 이동 이벤트와 조우 판정을 분리하고, 자체 규칙의 위험도 표시가 실제 위험에 대응하도록 만든다. 원작의 미확인 난수식을 재현했다고 주장하지 않는다.

### 2.4. FOE

공식 소개에서 FOE는 필드에 보이는 강적이며, 행동을 관찰하여 피하는 대상이다. U2 공식 설명은 플레이어의 한 걸음과 FOE 이동이 연동되는 기본 관계를 설명한다. [I HD 공식 소개][P04], [U2 Nintendo 소개][P07] — 직접 읽음.

| 행동 유형 | 플레이어가 읽는 정보 |
|---|---|
| 고정·문지기 | 막고 있는 위치, 추적 시작 범위 |
| 순회·왕복 | 경로, 방향 전환점, 통과할 틈 |
| 시야·영역 추적 | 전방 시야, 같은 행·열, 추적 영역의 경계 |
| 지형·장치 반응 | 교량 연결, 장애물, 물·높이 |
| 시간·환경 반응 | 낮밤, 빛, 수면 상태 |
| 특수 주기·속도 | 격턴 이동, 이동 후 휴식, 회전 행동, 여러 칸 이동 |
| 잠복·전투 반응 | 출현 조건, 주변 전투에 대한 접근 |

이는 여러 작품을 묶은 분석 분류다. 종별 사례는 [I FOE][W04], [X FOE][W36], [II 15F][W10], [U2 B1][U10]에서 직접 읽었다.

**한 걸음당 한 행동의 예외**

행동 한 번은 반드시 한 칸 이동을 뜻하지 않는다. FOE가 제자리에서 방향만 바꾸거나 기다릴 수 있고, 일부는 빠르게 움직이거나 지형을 무시한다. “방향 전환에 한 턴”이라는 설명은 **FOE 자신의 회전**을 말하며 플레이어의 제자리 회전 비용으로 읽으면 안 된다. [X FOE][W36] — 직접 읽음.

**전투 중 난입**

접근한 FOE가 전투 위치에 접촉하여 합류할 수 있다. 합류 시점은 거리·경로·행동 주기·반응 조건에 좌우된다. **공통된 고정 ‘3턴 후 난입’ 규칙은 확인하지 못했다.** X에는 적 배치 공간이 부족하면 기다리거나, 기존 적을 지우고 들어오는 예외도 있다. [I FOE][W04], [X FOE][W36] — 직접 읽음.

전투 담당과 공유할 정보는 FOE 위치, 행동 갱신 시점, 합류 요청, 배치 가능 여부다. 종별 전투 기술은 별도 범위다.

**보상·재출현**

- II 및 II HD의 일반 FOE는 경험치를 주지 않는 예외다. 계층 보스는 예외이며 소재 보상은 남는다. [HD 공식 Q&A][P01] — 직접 읽음.
- V·X 공략은 기본 재출현을 7일로 설명하지만, 퍼즐용 개체에는 빠른 재출현·층 이동 재출현이 있다. U1에는 7일·14일 등 종별 차이가 정리되어 있다. [V FOE][W28], [X FOE][W36], [U1 Q&A][U03] — 직접 읽음.
- 따라서 재출현을 전 작품·전 개체 하나의 상수로 두지 않는다.

**설계 제안:** 패턴 관찰 → 유도와 추적 해제 → 지형과 결합 순서로 학습시키고, FOE를 처치해도 진행 퍼즐이 막히지 않도록 대체 경로·재출현을 설계한다.

### 2.5. 채집과 소재 경제

채취(Take)·벌채(Chop)·채굴(Mine)은 기본 분류지만, 일일 예산·지점 횟수·추가 수확은 작품마다 다르다.

| 작품 | 확인한 차이 | 출처·확인 |
|---|---|---|
| I | 파티 스킬로 산출하는 하루 가능량과 그날 이미 사용한 양을 비교. 파티 교체만으로 사용량이 초기화되지 않음 | [I/HD FAQ][W06] — 직접 읽음 |
| II | 채집 중 습격 존재. 지점 공략에 습격 편성이 별도로 기재됨 | [II 15F][W10] — 직접 읽음 |
| III | 채집 공통 스킬과 탐색 특화 직업을 활용. 위험 경고 후 계속할지 선택하는 구조 | [III 용어집][W16] — 직접 읽음 |
| IV | 스킬 없이 채집 가능. 지점별 하루 이용량과 스킬의 추가·희귀 수확 효과. 무작위 채집 습격 제거 | [IV 탐색 안내][W22] — 직접 읽음 |
| U1 | 지점별 하루 한 번의 채집, 스킬에 따른 수확량 증가. 채집 습격 재등장 | [U1 Q&A][U03] — 직접 읽음 |
| U2 | 일반 소재 외에 요리용 식재료. 채집 표에 습격 적도 구분 | [U2 공식 요리][P09] — 직접 읽음; [채집 표][U09] — 검색 결과 요약만 봄 |
| V | 낚시·식재료·모닥불 조리를 추가. 종족 스킬과 탐색 이벤트가 연결 | [V 공식 시스템][P13] — 직접 읽음 |
| X | 일부 채집 스킬은 서브클래스로 얻을 수 없음. 인접 FOE와 채집 중 접촉하는 사건도 있어 무작위 습격과 구분 필요 | [X 시스템][W35], [X FOE][W36] — 직접 읽음 |

소재는 상점에 **판매하여** 장비·소모품 입고에 기여한다. 획득 즉시 제작되는 구조와 다르다. 해금 뒤 계속 살 수 있는 품목과 추가 소재 공급에 따라 재고가 생기는 품목을 구별해야 한다. III 소비품 표는 품절 여부를 별도 열로 표시한다. [I HD 시설 소개][P04], [III 소비 아이템][W40] — 직접 읽음.

**전투와의 연결:** 전리품 생성·조건부 드롭은 전투 쪽, 판매 누적·해금 조건·재고는 마을 쪽에서 담당한다. 채집 확률·스킬 합산식·희귀 소재 확률은 이 문서에서 확정하지 않는다.

### 2.6. 계층·층·보스·귀환

계층(Stratum)은 테마와 탐색 규칙의 큰 구획, 층은 개별 지도와 연결의 단위다. IV·X는 하나의 30층 미궁 모델로 묶기 어렵다.

| 작품 | 구조·테마·보스 사례 | 출처·확인 |
|---|---|---|
| I | 6계층·30층. 제5계층 유적 도시, 제6계층 복합 함정. 본편 이후 탐색이 남음 | [I 시스템][W01], [후반 던전][W05] — 직접 읽음 |
| II | 계층별 5층 구조. 빙설 테마의 제3계층 15F에 Scylla 배치 | [II 던전][W09], [15F][W10] — 직접 읽음 |
| III | 6계층으로 해저를 탐색하고 B25에 제6계층 보스 배치. 별도 항해와 해도·해저도시 진행 축 | [III B25][W41] — 직접 읽음; [미궁 개요][F02] — 검색 결과 요약만 봄 |
| IV | 대공 지도에서 여러 미궁·소미궁으로 진입. 숲·안개·화산/빙결 등 지역별 관문 | [IV 시스템][W21] — 직접 읽음; [진행 공략][W25], [보스 목록][F01] — 검색 결과 요약만 봄 |
| U1 | 원작 미궁 재구성과 Story 전용 Gladsheim | [U1 공식 소개][P06] — 직접 읽음 |
| U2 | 원작 II 재구성과 Ginnungagap. 추가 던전은 Classic에서도 탐색 가능. B1에 Basilisk | [Classic 공식][P08], [B1 공략][U10] — 직접 읽음 |
| V | 6계층·30층으로 나무를 오름. 결정 동굴 20F의 Crystal Dragon은 필드 접근 퍼즐과 연결 | [V 제4계층][W29] — 직접 읽음; [전 층표][W32] — 검색 결과 요약만 봄 |
| X | 번호 붙은 미궁 14개와 소미궁 10개. 과거 지역 테마와 새 사당을 엮음 | [X 미궁 안내][W37] — 직접 읽음 |
| HD | 각 DS 작품의 기본 구조 유지. Untold의 추가 던전 합본이 아님 | [HD 공식 소개][P02], [II/HD FAQ][W08] — 직접 읽음 |

이 표는 전체 계층·보스 도감이 아니라 진행 설계를 이해하기 위한 대표 사례다.

#### 이동 수단의 역할 차이

| 수단 | 기능·차이 | 출처·확인 |
|---|---|---|
| 지름길 | 다음 원정의 이동·소모 감소. 개방 방향과 지속 여부가 중요 | [I 시스템][W01] — 직접 읽음 |
| 수해자축·자축 거점 | 마을과 미궁을 연결. II HD 공식 안내는 조사 후 마을로 돌아오면 해당 거점으로 전송 가능하다고 설명 | [II HD 소개][P17] — 직접 읽음 |
| II 자축 배치 | 각 계층 첫 층의 자축과 세 번째·다섯 번째 층의 자축 기둥을 구별 | [II 던전][W09] — 직접 읽음 |
| 아리아드네의 실 | 마을 귀환 소모품. III에서는 초기 임무 후 판매 해금 | [III 소비 아이템][W40] — 직접 읽음 |
| 변위자석 | III에서는 직전에 이용한 계단·자축 등에 복귀. 실과 다른 기능 | [III 소비 아이템][W40] — 직접 읽음 |
| U1 Floor Jump | 지도 작성·계단 도달로 해금한 층 사이 빠른 이동. 미해금 층 어디서나 쓰는 탈출 기능이 아님 | [U1 조작표][P05], [Q&A][U03] — 직접 읽음 |
| V Floor Jump | 지도 보고에 따라 다음 원정의 진입 지점 확대. 마을에서 진입할 때 이용하는 방식 | [V 시스템][W27] — 직접 읽음 |

**설계 해석:** 지름길은 공간의 영구 진전, 거점은 출발 위치 갱신, 실은 현재 원정 철수, Floor Jump는 재방문 편의다.

### 2.7. 마을 시설

#### 공통 역할

길드는 캐릭터 생성·등록·파티 편성, 상점은 소재 판매·장비와 소모품 구매, 여관은 회복·저장, 주점은 선택 의뢰와 정보, 통치 기관은 주요 임무를 담당하는 구성이 반복된다. 다만 치료·약품 판매·보관 기능이 어느 시설에 속하는지는 작품마다 바뀐다. [I HD 시설 소개][P04], [II HD 시설 소개][P17], [V 공식 시스템][P13] — 직접 읽음.

| 작품·도시 | 주요 시설과 차이 | 출처·확인 |
|---|---|---|
| I / Etria | 길드, Rooster Inn, Shilleka’s Goods, Golden Deer Pub, Radha Hall, **Ceft Apothecary**. 시약원에서 치료·회복품을 취급 | [I HD 공식 소개][P04] — 직접 읽음 |
| II / High Lagaard | 길드, Flaus Inn, Sitoth Trading, Stickleback Bar, Ducal Palace, **Lagaard Hospital**. 전투불능·석화 치료 시설이 별도로 존재 | [II HD 공식 소개][P17] — 직접 읽음 |
| III / Armoroad | 길드, Aman’s Inn, Napier’s Firm, Butterfly Bistro, Senatus, Inver Port. 치료 기능이 여관으로 통합되고 항구가 별도 탐색 축 제공 | [III 시스템][W14] — 직접 읽음 |
| IV / Tharsis | 길드, Saehrimnir Inn, Berund Atelier, Dancing Peacock, Cargo Wharf, Outland Count의 의뢰처. 대공 탐험·교역 준비가 추가됨 | [IV 시설·UI 텍스트][W23] — 직접 읽음 |
| U1 / Etria | 여관에서 치료, 상점에서 회복품. 원작의 독립 시약원 구조가 바뀌고 길드하우스가 추가됨 | [U1 시스템][U01], [U1 조작표][P05] — 직접 읽음 |
| U2 / High Lagaard | 여관·상점·주점·공궁 외에 요리·식당·도시 개발이 중요한 별도 기능 | [U2 공식 안내][P12], [요리][P09], [도시 개발][P10] — 직접 읽음 |
| V / Iorys | 길드, 시장, Twilight Tavern, Jenetta’s Inn, Council. 시장의 소재·강화, 여관의 보관·가축 산물, 평의회의 임무·지도 보고 | [V 공식 시스템][P13] — 직접 읽음 |
| X / Maginia | 길드, Lady of the Lake Inn, Napier’s Firm, Kvasir’s Tavern, Expedition HQ | [Maginia 시설 목록][W38] — 검색 결과 요약만 봄 |
| HD | 원작별 시설 구분 유지. I HD에는 원작 I에 없던 여관 보관 기능이 추가됨 | [I 시스템][W01], [I HD 공식 소개][P04] — 직접 읽음 |

**캐릭터 생성·초상화:** 직업과 외형을 선택하여 길드원을 등록한다. V·X는 머리·눈·피부색과 음성 설정을 제공한다. HD는 초상화 추가와 외형 선택 편의를 제공하지만 V·X의 색상·음성 편집과 동일하지 않다. [X 공식 시스템][P15], [HD 공식 소개][P02], [II HD 변경점][W42] — 직접 읽음.

**숙박비:** 고정 요금 하나로 통일되지 않는다. II·IV 공략에는 파티 최고 레벨에 연동되는 숙박비가 정리되어 있다. 치료비·보관료·시간 진행은 별도 상태로 다루어야 한다. [II 시스템][W07], [IV 시스템][W21] — 직접 읽음.

**대성당:** 조사한 공식 시설 안내에서 전 작품 공통의 독립 “대성당 부활 시설”은 확인하지 못했다. 세계관 속 교회·종교 조직의 존재와 실제 마을 메뉴 시설을 혼동하면 안 된다. 치료 역할은 위 표의 시약원·병원·여관을 기준으로 한다.

### 2.8. 퀘스트·미션·텍스트 이벤트

- **퀘스트:** 주점 등을 통해 받는 선택 의뢰. 소재 조달, 특정 적 처치, 사람·장소 조사 등으로 구성되며 돈·아이템 등을 보상으로 받는다. [I HD 공식 시설 소개][P04], [II HD 공식 시설 소개][P17] — 직접 읽음.
- **미션:** 통치 기관에서 받는 주요 임무. 탐색 허가, 지도 작성, 계층 관문 돌파 등 이야기 진행과 연결된다. 보스를 처치하는 것과 임무를 보고해 다음 진행을 여는 것은 구분해야 한다. [II HD 공식 소개][P17], [III 전반 던전][W17] — 직접 읽음.
- **이벤트 칸:** 특정 칸 진입·조사에서 선택지가 나온다. 같은 장소도 시간·파티 직업·진행 상태에 따라 결과가 달라질 수 있다. II 공략에는 낮밤에 따라 획득물·전투 여부가 달라지는 사건과 특정 직업이 필요한 통로가 있다. [II 던전][W09] — 직접 읽음.
- **V Adventure Episode:** 선택과 파티의 종족 스킬 등이 탐색 사건의 결과에 관여하고 경험치 보상도 연결된다. 지도 이벤트가 전투 외 성장 경로가 되는 사례다. [V 시스템][W27], [V 제4계층][W29] — 직접 읽음.
- **III 분기:** 해도·해저도시 측 진행과 선택에 따른 시나리오 분기가 존재한다. 분기 조건 전체는 이번 조사에서 원문 대조하지 못했다. [III 미션 목록][F03] — 검색 결과 요약만 봄.

**설계 제안:** 의뢰 수락 상태, 현장 목표 달성, 보고 완료, 보상 수령을 각각 기록한다. 이벤트는 “한 번 봄”, “선택함”, “보상 받음”, “다시 이용 가능”을 하나의 불리언으로 합치지 않는다.

### 2.9. 레벨 상한·휴양·은퇴·고유 성장

휴양(Rest)은 스킬 재분배를 위한 레벨 비용, 은퇴(Retire)는 후계자 생성과 보너스를 통한 재육성이다. 은퇴 보너스를 반복해서 무한 누적하는 구조로 일반화하면 안 된다.

| 작품 | 상한·휴양·은퇴의 핵심 | 출처·확인 |
|---|---|---|
| I DS | 상한 70. 휴양은 레벨 10 감소, 사용 조건 있음. 은퇴 후 신입은 레벨 1 | [I 육성 팁][W02] — 직접 읽음 |
| I HD | 휴양 감소량이 5로 완화. 낮은 레벨에서는 감소 없이 재분배 가능 | [I 육성 팁][W02] — 직접 읽음 |
| II | 초기 상한 70. 현재 상한에서 은퇴하면 후계자 상한이 1씩 늘어 최대 99. 휴양 5 감소 | [II FAQ][W08] — 직접 읽음 |
| III | 초기 70에서 후반 상한 99까지 해금. 휴양 5 감소, 서브클래스 재설정과 연결 | [III 육성][W15] — 직접 읽음 |
| IV | 초기 70에서 99까지. 휴양 2 감소. 은퇴는 레벨 30 이상 | [IV 시스템][W21] — 직접 읽음 |
| U1 | 70에서 삼룡 관련 진행으로 99까지. 휴양 2 감소. Classic 은퇴와 Story의 캐릭터 유지형 재육성을 구분 | [U1 시스템][U01], [U1 Q&A][U03] — 직접 읽음 |
| U2 | 70에서 99까지. 휴양 2 감소. Classic의 은퇴에 대응하는 Story의 수련. 전직은 별도 비용 | [U2 시스템][U07], [은퇴·수련 안내][U08] — 직접 읽음 |
| V | 70→80→90→99 해금. 휴양 2 감소, 전직 5 감소. 종족과 직업을 분리하며 이명 선택이 성장 축 | [V 육성 안내][W31] — 직접 읽음 |
| X | 99→109→119→130 해금. 휴양 2 감소, 은퇴는 30 이상 | [X 시스템][W35] — 직접 읽음 |

II·III·IV·V·X의 은퇴 후 신입 레벨은 대체로 이전 레벨의 절반을 올림하고 최대 30으로 제한하는 방식이다. 보너스는 직전 은퇴 조건에 따라 정해지며 이전 보너스를 계속 더하는 방식은 아니다. 각 작품의 상세 능력치·SP 표는 전투·성장 담당 조사로 넘긴다. [II FAQ][W08], [III 육성][W15], [IV 시스템][W21], [V 시스템][W27], [X 시스템][W35] — 직접 읽음.

**서브클래스**

- 도입작은 III이며 IV·X에서도 사용한다.
- U1·U2의 그리모어, V의 종족·이명은 서브클래스와 다른 구조다.
- X는 채집 관련 일부 스킬을 서브클래스에서 배제하므로 “보조 직업으로 채집 능력을 모두 확보”한다고 가정하면 안 된다.

근거: [III 시스템][W14], [IV 시스템][W21], [X 공식 시스템][P15], [X 시스템][W35] — 직접 읽음.

**탐색과 연결되는 고유 시스템**

| 작품 | 시스템 | 탐색상의 의미 |
|---|---|---|
| III | 항해·파머 계열 지원 | 육상 원정 외 수집·교역·탐색 준비 |
| IV | 대공 지도 식재료·미끼 | 다음 원정의 효과와 대공 FOE 동선 조작 |
| U1 | 길드하우스·그리모어 | 원정 준비와 다른 직업·적 스킬의 활용 |
| U2 | 그리모어 교환·요리·식당 | 식재료 수집, 효과 선택, 자금과 도시 개발 |
| V | 종족 스킬·이명·Adventure Episode | 파티 구성에 따라 탐색 사건의 선택지·성과 변화 |
| X | 서브클래스와 외형 편집 | 탐색 역할 조합과 캐릭터 표현 |

근거: [III 시스템][W14], [IV 시스템][W21], [U1 공식 소개][P06], [U2 그리모어][P11], [요리][P09], [도시 개발][P10], [V 시스템][W27], [X 공식 시스템][P15] — 직접 읽음.

요청에 포함된 “노하우”는 이 자료만으로 전 작품에 공통된 독립 시스템명으로 특정하지 못했다. 개별 탐색 패시브와 별도 시스템을 혼합하지 않고 **용어 확인 필요**로 남긴다.

### 2.10. Story·Classic과 난이도

#### Untold의 모드

| 작품 | Story | Classic | 근거 |
|---|---|---|---|
| U1 | 고정된 주요 인물 5명, 음성·연출, Gladsheim을 포함한 이야기 | 자유롭게 길드를 구성하며 재구성한 원작 미궁 탐색 | [Nintendo 공식 소개][P06] — 직접 읽음 |
| U2 | 고정 인물과 Fafnir 중심 이야기 | 자유 길드 구성. Ginnungagap·요리·그리모어도 이용 가능 | [Nintendo 공식 소개][P07], [Classic 공식][P08] — 직접 읽음 |

Classic을 “DS판 규칙을 그대로 실행하는 모드”로 보면 안 된다. 지도·편의·육성 시스템이 바뀐 리메이크 안의 자유 편성 모드다.

#### 난이도

| 작품 | 선택지·제약 | 출처·확인 |
|---|---|---|
| DS I·II·III | HD처럼 선택형 난이도를 기본 제공하는 판본이 아님 | [I/HD FAQ][W06], [II FAQ][W08], [HD Q&A][P01] — 직접 읽음 |
| IV | Casual / Normal. 마을에서 변경 | [IV 시설·UI 텍스트][W23] — 직접 읽음 |
| U1 | Picnic / Standard / Expert. 마을에서 변경 | [U1 시스템][U01] — 직접 읽음 |
| U2 | Picnic / Standard / Expert | [U2 시스템][U07] — 직접 읽음 |
| V | Basic / Advanced | [V 시작 안내][W33] — 검색 결과 요약만 봄 |
| X | Picnic / Basic / Expert / Heroic | [X 시스템][W35] — 직접 읽음 |
| HD | Picnic / Basic / Expert. Expert가 DS판에 대응하며 마을에서 변경 | [HD 공식 Q&A][P01] — 직접 읽음 |

X의 Heroic은 Expert와 전투 조건이 같지만 새 게임에서만 선택하고, 낮추면 다시 올릴 수 없는 제약이 있다. Picnic으로 변경한 뒤 다른 난이도로 돌아갈 수 없는 제약도 있다. 이러한 제한을 다른 작품의 Picnic·Expert에 그대로 적용하면 안 된다. [X 시스템][W35] — 직접 읽음.

**설계 제안:** 피해 배율뿐 아니라 재도전, 귀환 아이템 소비, 지도 보조, 난이도 변경 제한을 별도 옵션으로 설계하되 원작과 다른 조합임을 명시한다.

### 2.11. 화면·메뉴·사운드·저장

#### 화면과 메뉴 흐름

DS·3DS에서는 위쪽의 1인칭 탐색·이벤트·전투 화면과 아래쪽 지도 편집이 역할을 나눈다. U1 공식 조작표는 캠프 진입, 지도 확대, 조사와 취소를 별도 조작으로 설명한다. [U1 조작표][P05] — 직접 읽음.

대표 흐름은 다음과 같다.

`마을 시설 선택 → 파티·장비·소모품 준비 → 미궁 진입 → 탐색/지도 → 캠프에서 아이템·스킬·상태 확인 → 귀환 → 판매·보고·회복·저장`

이는 여러 작품의 메뉴 역할을 묶은 정리다. 시설별 하위 메뉴와 버튼 배치는 동일하지 않다. [I HD 시설][P04], [U2 공식 안내][P12], [V 공식 시스템][P13] — 직접 읽음.

#### 사운드

- U1은 새 편곡과 원래 계열 음악을 선택하는 기능을 공식 소개에서 확인했다. [U1 Nintendo 소개][P06] — 직접 읽음.
- U2 공식 안내는 제품판의 새 음원·FM 음원 선택을 설명한다. 체험판과 제품판의 지원 차이를 혼동하지 않는다. [U2 공식 안내][P12] — 직접 읽음.
- HD는 PC-88 계열 음원을 바탕으로 정비한 음악이며 DS판·3DS판 음악을 자유롭게 전환하는 합본 옵션은 아니다. III 후반 일반전 신규 곡도 공식 Q&A에서 설명한다. [HD 공식 Q&A][P01] — 직접 읽음.

**설계 제안:** 마을·계층·위험·전투·메뉴 효과음을 상태에 따라 전환하되, 원작 음악이나 효과음을 추출해 사용하지 않는다. 웹에서는 첫 사용자 입력 뒤 오디오를 활성화하는 흐름을 고려한다. [Godot 웹 내보내기 문서][C05] — 직접 읽음.

#### 저장

| 작품·판본 | 확인한 내용 | 출처·확인 |
|---|---|---|
| DS I | 일반 저장과 중단 저장을 구분해야 함. 원작에는 중단 저장이 없고 HD에 추가 | [I/HD FAQ][W06] — 직접 읽음 |
| DS II | 중단 데이터는 재개 시 삭제되는 구조 | [II 시스템][W07] — 직접 읽음 |
| DS III | 기본 저장 슬롯 1개 | [III 시스템][W14] — 직접 읽음 |
| U2 | **총 9개: 게임 카드 1개 + SD 8개.** 체험판은 1개 | [U2 공식 안내][P12] — 직접 읽음 |
| V | 9개 슬롯이라는 공략 안내 | [V 시작 안내][W33] — 검색 결과 요약만 봄 |
| X | 9개 슬롯 | [X 시스템][W35] — 직접 읽음 |
| HD | 9개 슬롯. 중단 저장은 재개만으로 삭제하지 않는 방향으로 변경 | [HD 공식 소개][P02], [개발자 인터뷰][P16] — 직접 읽음 |

II HD 변경점은 Continue와 일반 Load가 중단 데이터에 미치는 차이도 설명한다. 따라서 “중단 데이터가 어떤 경우에도 영구히 남는다”라고 표현하지 않는다. [II HD 변경점][W42] — 직접 읽음.

여관 자동 저장 옵션과 브라우저처럼 언제든 종료해도 되는 연속 자동 저장은 같은 개념이 아니다. 전 작품의 자동 저장 지점·전멸 후 지도 보존 정책은 개별 검증이 필요하다.

### 2.12. ATLUS·SEGA의 공개 이용 지침

이 절은 공개 문서의 요약이며 법률 자문이 아니다.

**조사 결과:** 팬사이트용 이미지 이용과 게임 플레이 영상 공개 지침은 확인했다. 그러나 조사한 공식 자료에서 **세계수의 미궁 팬게임의 제작·배포를 포괄적으로 허용하는 지침은 확인하지 못했다.** 검색 범위에서 찾지 못했다는 뜻이며, 모든 지역·개별 허가의 부재를 증명하는 주장은 아니다.

| 공식 문서 | 확인한 대상·조건 | 팬게임과의 관계 |
|---|---|---|
| [ATLUS 이미지 이용 안내][R01] | 공식 사이트의 다운로드 가능한 이미지에 관한 개인·비영리 팬사이트 이용 조건. 저작권 표기, 수정·가공 제한, 허용 범위 밖 이용·재배포 제한 | 게임 안의 그림·캐릭터 에셋으로 자유롭게 재사용하는 허가로 확장할 수 없음 |
| [세계수 HD 플레이 영상 안내][R02] | 개인의 비영리 플레이 이미지·영상 공개, 스포일러·권리 표기, 출시 전 공개·음악 단독 이용 등 제한. 플랫폼 부수 수익의 예외 | 플레이 영상 공개 조건이며 별도 게임 제작 허가가 아님 |
| [SEGA 플레이 영상 가이드라인][R03] | 적법한 이용자, 제3자 권리, 개별 작품 지침 우선, 공식으로 오인시키는 표현 금지, 영상과 분리한 소재 이용 제한 등 | 독립 팬게임·모드·에셋 패키지의 포괄 허가로 해석하지 않음 |

세 문서 모두 직접 읽음. SEGA 문서는 열람 시 2026-05-22 개정 표기를 확인했다. 지역별 문서와 개별 타이틀 지침의 적용 범위는 배포 전 다시 대조할 필요가 있다.

**공개 자료에서 도출하는 제작상의 구분**

- 무료 배포와 비공식 표기만으로 이용 허가가 생긴다고 볼 근거는 없다.
- 원작에서 추출한 초상화·배경·몬스터·음악·음성·효과음·UI 그림을 프로젝트에 포함하지 않는 방향이 적절하다.
- 원작 지도 배치·이벤트 문장·대사를 그대로 옮기지 않고 시스템을 분석해 새로운 표현으로 제작한다.
- 공식 로고·상표를 자신의 게임 로고나 공식 배급 표지처럼 사용하지 않는다.
- 외부 에셋의 라이선스와 권리 출처는 코드 라이선스와 별도로 기록한다.
- 직접 만든 그래픽이나 “비공식” 고지가 원작과 관련된 모든 권리 문제를 해결한다는 보장은 하지 않는다.

이는 위 공개 지침을 바탕으로 한 **제작 범위 제안**이다. ATLUS 이미지 지침을 “모든 팬아트가 금지됨”이라고 확대 해석하는 것 역시 부정확하다.

### 2.13. 웹·모바일·오픈소스 참고 사례

| 사례 | 참고할 점 | 제한·라이선스·확인 |
|---|---|---|
| **The Quest** | iPhone·iPad에서 격자 이동·턴 기반 탐험·퀘스트를 제공하는 상용 사례. 작은 화면의 이동·메뉴 구성 참고 | EO 팬게임이나 오픈소스가 아님. [개발사 App Store 등록][C04] — 직접 읽음 |
| **Dungeon Crawl Stone Soup / WebTiles** | 브라우저에서 장시간 턴 기반 탐색을 운영하는 사례. 입력·상태·UI 구조 참고 | 2D 로그라이크이며 EO식 파티 1인칭 게임과 다름. 저장소는 GPL 계열 조건 확인 필요. [공식 저장소][C03] — 직접 읽음 |
| **BastiaanOlij/godot_dungeon** | 작은 3D 던전 데모의 구성과 자산 배치 참고 | README 기준 Godot 3.2.4. Godot 4에 바로 넣는 템플릿이 아님. 작성 코드 MIT, 외부 자산·애드온은 별도 조건. [저장소][C01] — 직접 읽음 |
| **Godot A-Star Pathfinding for Gridmaps** | GridMap의 통행 가능 칸과 경로 탐색, 좌표 변환, 디버그 표시 참고 | MIT. EO 전체 게임·FOE 행동 규칙 구현이 아님. [저장소][C02] — 직접 읽음 |

이번 조사에서는 위 프로젝트를 내려받거나 실행하지 않았다. 웹·모바일 동작 검증을 완료했다고 주장하지 않는다.

**Godot 웹 조건**

열람한 공식 stable 문서는 WebAssembly·WebGL 2와 Compatibility 렌더러를 설명한다. Godot 4 C# 프로젝트의 웹 내보내기 제한, 단일 스레드 내보내기, 사용자 동작이 필요한 오디오, 비활성 탭의 정지, 브라우저 저장소의 지속성 제약도 확인했다. [Godot 웹 내보내기][C05] — 직접 읽음.

따라서 초기 버전은 GDScript·Compatibility를 기준으로 검토하고, 저장 파일 내보내기·가져오기와 모바일 터치 동작을 실제 브라우저에서 별도로 확인하는 것을 제안한다.

## 3. 작품별 차이 종합표

세부 근거와 확인 상태는 위 절을 따른다. 이 표는 구현 기준을 선택할 때 섞기 쉬운 차이를 요약한다.

| 작품 | 탐색·진행의 특징 | 마을·성장의 특징 | 판본 혼동 주의 |
|---|---|---|---|
| I DS | 고정 미궁, 수동 지도 중심, 후반 워프·낙하 | 별도 시약원, 휴양 비용 큼 | HD의 보관·평행 이동·중단 저장을 원작에 소급하지 않음 |
| II DS | 낮밤·얼음·낙하·일방통행, 지도 도구 확대 | 별도 병원, 은퇴로 상한 단계 상승 | 일반 FOE 무경험치, 서브클래스 없음 |
| III DS | 해저 미궁과 별도 항해, 시나리오 분기 | 항구·해저도시, 서브클래스 도입 | 모든 계층을 5층으로 계산하지 않음 |
| IV | 대공 지도와 여러 미궁·소미궁, 음식·미끼 | 교역 준비, 서브클래스, 휴양 부담 감소 | 무작위 채집 습격 제거와 FOE 접촉은 별개 |
| U1 | 원작 재구성, FULL 오토맵, Floor Jump | Story/Classic, 길드하우스·그리모어 | Gladsheim은 Story 차이 |
| U2 | 재설계한 미궁과 Ginnungagap | 요리·식당·도시 개발, 그리모어, 9슬롯 | 추가 던전·요리가 Classic에도 존재 |
| V | 나무를 오르는 탐색, 종족 조건 이벤트·식재료 | 종족·이명, 지도 보고 | Floor Jump는 마을 진입 편의로 구분 |
| X | 다수 미궁·소미궁, 과거 테마와 사당 | 서브클래스, 상한 130, 4난이도 | Heroic·Picnic 전환 제약 |
| HD | I·II·III 각각의 구조에 입력·지도·저장 편의 추가 | 9슬롯, 3난이도, 초상화·NG+ 관련 편의 | Untold 콘텐츠 합본이 아님 |

추가로 HD의 I→II 계승은 길드명·일부 아이템·이벤트 변화에 관한 것으로, 파티의 레벨·육성을 그대로 넘기는 기능과 구분한다. HD의 New Game+와 작품 간 계승도 다른 기능이다. [HD 공식 Q&A][P01] — 직접 읽음.

## 4. 구현 관점 메모

이 절은 원작 내부 코드나 데이터 형식을 복원한 것이 아니라 조사 결과를 바탕으로 한 **Godot 팬게임 설계 제안**이다.

### 4.1. 정적 정의와 플레이 상태

| 데이터 | 필요한 필드 예시 | 분리 이유 |
|---|---|---|
| DungeonDefinition | ID, 테마, 층 목록, 진입 조건, 연결 거점 | IV·X처럼 여러 미궁 지원 |
| FloorDefinition | 크기, 칸, 경계, 출현 구역, 조명·음악, 연결 | 한 층 안의 구역별 규칙 |
| CellDefinition | 좌표, 지형 종류, 높이, 피해·강제 이동, 트리거 ID | 밟는 효과와 통행 경계 분리 |
| EdgeDefinition | 벽/문/통로, 허용 방향, 열쇠·스위치 조건 | 일방통행·반대편 개방 지원 |
| WorldState | 개방 통로, 장치 상태, 상자, 보스, 임무 플래그 | 원정 후에도 남는 실제 변화 |
| ExplorationKnowledge | 실제 방문, 관찰, 지도 보고 상태 | 지도 그림과 방문 판정 분리 |
| MapAnnotation | 색, 벽 선, 아이콘·상태, 메모, 경로 | 사용자가 틀리게 적어도 세계는 바뀌지 않음 |
| PartyState | 위치·방향, 인벤토리, 원정 효과, 귀환 지점 | 전투·마을과 공유하는 상태 |

경계 양쪽에 서로 다른 벽 정보를 중복 저장하기보다 하나의 경계 객체와 통과 방향으로 표현하면 불일치를 줄일 수 있다.

### 4.2. 탐색 행동의 처리 순서

권장하는 자체 순서는 다음과 같다.

1. 입력과 이동 가능 여부 판단.
2. 이동·상호작용 확정.
3. 진입 지형·강제 이동 처리.
4. 발견·지도 자동 기록 갱신.
5. 탐색 시간과 FOE 행동 갱신.
6. 접촉·이벤트·일반 인카운트의 우선순위 결정.
7. 저장 가능한 일관된 상태 확정.

회전, 벽에 부딪힘, 문 통과, 미끄러짐의 각 중간 칸, 낙하, 워프, 채집, 메뉴 조작이 시간을 소비하는지는 **행동별 정책**으로 둔다. 원작의 미확인 예외를 기본값으로 숨겨 넣지 않는다.

동시에 FOE 접촉과 랜덤 전투가 발생할 수 있는 경우 어느 쪽을 우선할지도 명시해야 한다.

### 4.3. FOE 상태기계

상태 예:

`Dormant → Idle/Patrol → Alert → Chase → Return`

별도 상태:

`ScriptedMovement`, `BattleJoinPending`, `Defeated`, `RespawnPending`

필요 데이터:

- 현재 칸·방향, 순회 경로·경로 인덱스
- 시야 모양, 감지 조건, 추적 영역
- 행동 주기, 대기 횟수, 회전 비용, 한 행동의 이동량
- 지형별 통과 능력, 다른 FOE와의 충돌 정책
- 장치·낮밤·전투에 대한 반응
- 처치 시각과 재출현 정책
- 전투 위치, 합류 대기, 적 배치 공간 부족 시 처리

재출현 정책은 `Never`, `AfterGameDays`, `OnFloorReload`, `QuestControlled`처럼 구별한다. 원작의 7일·14일은 특정 데이터 사례이며 엔진 공통 상수가 아니다.

### 4.4. 채집·상점·퀘스트

채집에는 지점 이용 횟수, 파티 일일 예산, 수확 테이블, 추가 수확 효과, 경고·습격 조건, 일자별 초기화를 분리한다.

상점에는 다음을 구별한다.

- 누적 판매 소재 수
- 영구 해금 여부
- 현재 재고
- 추가 재고에 필요한 소재
- 퀘스트·진행 조건

소재 판매, 판매 대금 지급, 해금 갱신을 한 묶음으로 처리하여 중간 저장으로 소재나 돈이 중복되지 않게 한다.

퀘스트는 `Locked → Available → Accepted → ObjectiveComplete → Reported`로 두고, 취소·재수락·분기·보상 수령을 별도 관리한다.

### 4.5. 시간과 저장

시간은 현실 시계와 게임 내 시계를 분리한다. 낮밤·채집 초기화·FOE 재출현이 실제 브라우저를 닫아 둔 시간만큼 자동 진행할지는 별도 기획 결정이다.

저장 데이터에는 최소한 다음이 필요하다.

- 스키마 버전과 콘텐츠 버전
- 길드·파티·장비·인벤토리
- 위치·방향·귀환 지점
- 세계 변화·장치·FOE·상점·임무
- 지도 기록·실제 방문·보고 상태
- 게임 내 날짜·원정 효과
- 난이도와 변경 제한
- 필요하다면 난수 상태

브라우저 저장은 영구 보존을 보장한다고 안내하지 않는다. 자동 저장과 수동 슬롯, 내보내기·가져오기, 이전 정상 저장 복구를 제공하는 편이 적절하다. Godot 문서는 브라우저 저장소의 지속성 확인에도 한계가 있음을 설명한다. [Godot 웹 내보내기][C05] — 직접 읽음.

### 4.6. 첫 구현 범위와 수용 기준

**제안 범위:** 마을 1개, 작은 미궁 1개, 3개 층, 지형 규칙 2개, FOE 행동 3종, 채집 3종, 보스 관문 1개.

수용 기준:

- 같은 입력열에서 이동·FOE 위치·이벤트 순서가 일관된다.
- 자동 지도와 수동 지도 기록이 실제 세계 상태를 훼손하지 않는다.
- 한 방향 통로·개방 지름길·장치 상태가 저장 후 유지된다.
- 채집 초기화와 재출현이 정해진 게임 시간에만 일어난다.
- 소재 판매·보고 보상이 중복되지 않는다.
- 마우스·키보드·터치에서 지도 편집과 이동이 서로 오작동하지 않는다.
- 새로고침·저장 가져오기 후 원정을 복구할 수 있다.

이는 제안이며 이번 조사에서 구현하거나 테스트한 항목이 아니다.

## 5. 미확인·논쟁·추가 조사 항목

1. **인카운트 내부 공식:** 난수 소비, 보행 한도·누적식, 색 경계, 레벨·시간·지형 보정.
2. **특수 행동의 시간 비용:** 제자리 회전, 실패 이동, 문·지름길, 강제 이동의 중간 칸, 채집의 작품별 처리.
3. **FOE 난입 순서:** 전투 턴의 어느 시점에 갱신·접촉·합류하는지와 종별 예외.
4. **재출현 전체 표:** 일반 FOE·퍼즐 FOE·보스·이벤트 개체의 조건과 날짜 계산.
5. **지도 완성 판정:** Floor Jump·지도 보고의 정확한 임계값과 제외 구역. 커뮤니티의 특정 비율을 확정 수치로 채택하지 않음.
6. **지도 도구 전체 비교:** IV·X의 모든 옵션·아이콘 수·메모 제한, 지역판 차이.
7. **지형 세부 규칙:** IV 온도 장치, U1 조명, V 부유의 원문 대조; 압력판·무게 스위치 사례.
8. **채집 수치:** 희귀 확률, 스킬 합산, 습격 확률. 표본 실험과 데이터 마이닝을 구분할 추가 자료 필요.
9. **성장 판본 차이:** HD II·III의 은퇴·상한 관련 모든 세부 차이, “노하우”의 정확한 지칭.
10. **저장 전체 표:** IV·U1의 슬롯·중단·자동 저장, 전멸 시 지도 보존 정책의 전 작품 대조.
11. **전체 계층·보스 목록:** 본문은 대표 사례이며 전 작품의 모든 층·보스를 열거한 데이터베이스는 아님.
12. **팬게임 허용 범위:** 포괄적 제작·배포 허용 문서는 확인하지 못함. 영상·이미지 이용 지침으로 대체하지 않음.
13. **참고 프로젝트 실행:** 소개·README·라이선스는 읽었으나 Godot 4 이식·웹 빌드·모바일 실행은 미검증.

## 6. 출처 목록

### 공식·설명서·개발자 인터뷰

- **P01 — 직접 읽음:** [ATLUS, HD 리마스터 Q&A](https://www.atlus.co.jp/news/20995/). 오토맵·입력·난이도·FOE 경험치·음악·계승.
- **P02 — 직접 읽음:** [HD 공식 사이트의 추가 요소 안내](https://sq-atlus.jp/sq123/). 저장 슬롯·초상화·편의 기능.
- **P03 — 직접 읽음:** [Origins 공식 영문 게임 소개](https://www.atlus.com/etrianorigins/index.html?lang=en). 탐험·소재 판매·파티 정비.
- **P04 — 직접 읽음:** [SEGA, I HD 상세 소개](https://www.sega.jp/topics/detail/230320_2/). FOE·지도·Etria 시설.
- **P05 — 직접 읽음:** [Nintendo, U1 공식 조작표 PDF](https://www.nintendo.com/hk/3ds/ssq/pdf/ssq_3ds_op-nsheet.pdf). 이동·지도·위험도·Floor Jump. 추출 텍스트 확인이며 PDF 시각 검증은 아님.
- **P06 — 직접 읽음:** [Nintendo, U1 소개](https://www.nintendo.com/en-gb/Games/Nintendo-3DS-games/Etrian-Odyssey-Untold-The-Millennium-Girl-879400.html). Story/Classic·Gladsheim·음악·길드하우스.
- **P07 — 직접 읽음:** [Nintendo, U2 소개](https://www.nintendo.com/en-gb/Games/Nintendo-3DS-games/Etrian-Odyssey-2-Untold-The-Fafnir-Knight-1084480.html). FOE·지도·모드·요리.
- **P08 — 직접 읽음:** [U2 공식 Classic 모드](https://sq-atlus.jp/ssq2/system/system03.html). Classic의 Ginnungagap·요리·그리모어.
- **P09 — 직접 읽음:** [U2 공식 요리](https://sq-atlus.jp/ssq2/system/system01.html). 식재료·레시피·효과.
- **P10 — 직접 읽음:** [U2 공식 도시 개발](https://sq-atlus.jp/ssq2/system/system02.html). 광고·판매·투자·발전.
- **P11 — 직접 읽음:** [U2 공식 그리모어](https://sq-atlus.jp/ssq2/system/system05.html). 스킬석·교환 관련 기능.
- **P12 — 직접 읽음:** [U2 공식 체험판·플레이 안내](https://sq-atlus.jp/ssq2/trial/). 제품판 9슬롯, 음악, 시설·지도.
- **P13 — 직접 읽음:** [V 공식 시스템](https://sq-atlus.jp/sq5/system/). 탐색·채집·음식·시설.
- **P15 — 직접 읽음:** [X 공식 시스템](https://sq-atlus.jp/sqx/system/). 지도·외형 편집·서브클래스.
- **P16 — 직접 읽음:** [Everyeye, Origins 개발자 인터뷰](https://www.everyeye.it/articoli/intervista-segreti-etrian-odyssey-origins-collection-raccontati-atlus-61266.html). 입력 이식·저장 개선.
- **P17 — 직접 읽음:** [SEGA, II HD 상세 소개](https://www.sega.jp/topics/detail/230421_2/). 얼음·피해 바닥·문·자축·시설.

### 위키·공략·관찰 자료

- **W01 — 직접 읽음:** [I 시스템](https://w.atwiki.jp/sekaiju_maze/pages/9.html).
- **W02 — 직접 읽음:** [I 육성·탐색 팁](https://w.atwiki.jp/sekaiju_maze/pages/99.html).
- **W04 — 직접 읽음:** [I FOE 공략](https://w.atwiki.jp/sekaiju_maze/pages/78.html).
- **W05 — 직접 읽음:** [I 제5계층 이후](https://w.atwiki.jp/sekaiju_maze/pages/236.html).
- **W06 — 직접 읽음:** [I 및 HD FAQ](https://w.atwiki.jp/sekaiju_maze/pages/57.html).
- **W07 — 직접 읽음:** [II 시스템](https://w.atwiki.jp/sekaiju_maze2/pages/52.html).
- **W08 — 직접 읽음:** [II FAQ](https://w.atwiki.jp/sekaiju_maze2/pages/51.html).
- **W09 — 직접 읽음:** [II 던전](https://w.atwiki.jp/sekaiju_maze2/pages/58.html).
- **W10 — 직접 읽음:** [Privespa, II 15F](https://privespa.org/sekaiju2/maze3/map15.html).
- **W11 — 직접 읽음·관찰/추정:** [II 인카운트 지도 조사](https://wildancer.blog.jp/sq2encmap.html).
- **W14 — 직접 읽음:** [III 시스템](https://w.atwiki.jp/sekaiju_maze3/pages/59.html).
- **W15 — 직접 읽음:** [III 육성](https://w.atwiki.jp/sekaiju_maze3/pages/83.html).
- **W16 — 직접 읽음:** [III 용어집](https://w.atwiki.jp/sekaiju_maze3/pages/17.html).
- **W17 — 직접 읽음:** [III 제1~4계층](https://w.atwiki.jp/sekaiju_maze3/pages/125.html).
- **W21 — 직접 읽음:** [IV 시스템](https://w.atwiki.jp/sekaiju_mazeiv/pages/45.html).
- **W22 — 직접 읽음:** [Privespa, IV 탐색 안내](https://privespa.org/sekaiju4/tebiki/tebiki2.html).
- **W23 — 직접 읽음:** [IV 시설·UI 텍스트](https://w.atwiki.jp/sekaiju_mazeiv/pages/81.html). 인용하지 않고 기능만 요약.
- **W24 — 검색 결과 요약만 봄:** [IV 지저호](https://privespa.org/sekaiju4/map/maze3/chiteiko.html).
- **W25 — 검색 결과 요약만 봄:** [IV 진행 공략](https://privespa.org/sekaiju4/story/story.html).
- **W26 — 검색 결과 요약만 봄:** [IV 지도 플레이 기록](https://mochior.blog.fc2.com/blog-entry-364.html).
- **W27 — 직접 읽음:** [V 시스템](https://w.atwiki.jp/sekaiju_mazev/pages/5.html).
- **W28 — 직접 읽음:** [V FOE](https://w.atwiki.jp/sekaiju_mazev/pages/54.html).
- **W29 — 직접 읽음:** [V 제4계층](https://w.atwiki.jp/sekaiju_mazev/pages/106.html).
- **W30b — 검색 결과 요약만 봄:** [V 25F](https://ds-can.com/sekaiju5/story/a25.html).
- **W31 — 직접 읽음:** [V 육성·전직](https://ds-can.com/sekaiju5/class/class_about.html).
- **W32 — 검색 결과 요약만 봄:** [V 전 층표](https://gamesp.net/sq5/capture/allmisson.html).
- **W33 — 검색 결과 요약만 봄:** [V 시작 안내](https://gamesp.net/sq5/capture/c001.html).
- **W35 — 직접 읽음:** [X 시스템](https://w.atwiki.jp/sekaiju_mazex/pages/85.html).
- **W36 — 직접 읽음:** [X FOE](https://w.atwiki.jp/sekaiju_mazex/pages/104.html).
- **W37 — 직접 읽음:** [X 미궁 안내](https://w.atwiki.jp/sekaiju_mazex/pages/89.html).
- **W38 — 검색 결과 요약만 봄:** [Etrian Odyssey Wiki, Maginia](https://etrian.fandom.com/wiki/Maginia).
- **W40 — 직접 읽음:** [III 소비 아이템](https://w.atwiki.jp/sekaiju_maze3/pages/87.html).
- **W41 — 직접 읽음:** [Privespa, III B25](https://privespa.org/sekaiju3/maze6/map25.html).
- **W42 — 직접 읽음:** [II HD 변경점](https://w.atwiki.jp/sekaiju_maze2/pages/209.html).
- **U01 — 직접 읽음:** [U1 시스템](https://w.atwiki.jp/shinsekaiju_maze/pages/21.html).
- **U03 — 직접 읽음:** [Privespa, U1 Q&A](https://privespa.org/shin_sekaiju1/memo/qamemo.html).
- **U05 — 검색 결과 요약만 봄:** [U1 FOE](https://w.atwiki.jp/shinsekaiju_maze/pages/44.html).
- **U07 — 직접 읽음:** [U2 시스템](https://w.atwiki.jp/ssekaiju_maze2/pages/51.html).
- **U08 — 직접 읽음:** [Privespa, U2 은퇴·수련](https://privespa.org/shinsekaiju2/memo/intai.html).
- **U09 — 검색 결과 요약만 봄:** [U2 채집 표](https://w.atwiki.jp/ssekaiju_maze2/pages/33.html).
- **U10 — 직접 읽음:** [Privespa, U2 Ginnungagap B1](https://privespa.org/shinsekaiju2/map1/g01.html).
- **F01 — 검색 결과 요약만 봄:** [Etrian Odyssey Wiki, Stratum Boss](https://etrian.fandom.com/wiki/Stratum_Boss).
- **F02 — 검색 결과 요약만 봄:** [Etrian Odyssey Wiki, III 미궁](https://etrian.fandom.com/wiki/Yggdrasil_Labyrinth_%28Etrian_Odyssey_III%29).
- **F03 — 검색 결과 요약만 봄:** [Etrian Odyssey Wiki, III 미션](https://etrian.fandom.com/wiki/Missions_%28Etrian_Odyssey_III%29).

### 권리 안내

- **R01 — 직접 읽음:** [ATLUS 이미지 이용 안내](https://www.atlus.co.jp/copyright/).
- **R02 — 직접 읽음:** [ATLUS 세계수 HD 플레이 영상 안내](https://www.atlus.co.jp/news/21478/).
- **R03 — 직접 읽음:** [SEGA 게임 플레이 영상 가이드라인](https://www.sega.co.jp/streaming_guideline/).

### 참고 프로젝트·기술 문서

- **C01 — 직접 읽음:** [BastiaanOlij/godot_dungeon](https://github.com/BastiaanOlij/godot_dungeon).
- **C02 — 직접 읽음:** [Godot A-Star Pathfinding for Gridmaps](https://github.com/antzGames/Godot-A-Star-Pathfinding-for-Gridmaps).
- **C03 — 직접 읽음:** [Dungeon Crawl Stone Soup 공식 저장소](https://github.com/crawl/crawl).
- **C04 — 직접 읽음:** [The Quest, App Store](https://apps.apple.com/us/app/the-quest/id1135197236).
- **C05 — 직접 읽음:** [Godot 공식 웹 내보내기 문서](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

[P01]: https://www.atlus.co.jp/news/20995/
[P02]: https://sq-atlus.jp/sq123/
[P03]: https://www.atlus.com/etrianorigins/index.html?lang=en
[P04]: https://www.sega.jp/topics/detail/230320_2/
[P05]: https://www.nintendo.com/hk/3ds/ssq/pdf/ssq_3ds_op-nsheet.pdf
[P06]: https://www.nintendo.com/en-gb/Games/Nintendo-3DS-games/Etrian-Odyssey-Untold-The-Millennium-Girl-879400.html
[P07]: https://www.nintendo.com/en-gb/Games/Nintendo-3DS-games/Etrian-Odyssey-2-Untold-The-Fafnir-Knight-1084480.html
[P08]: https://sq-atlus.jp/ssq2/system/system03.html
[P09]: https://sq-atlus.jp/ssq2/system/system01.html
[P10]: https://sq-atlus.jp/ssq2/system/system02.html
[P11]: https://sq-atlus.jp/ssq2/system/system05.html
[P12]: https://sq-atlus.jp/ssq2/trial/
[P13]: https://sq-atlus.jp/sq5/system/
[P15]: https://sq-atlus.jp/sqx/system/
[P16]: https://www.everyeye.it/articoli/intervista-segreti-etrian-odyssey-origins-collection-raccontati-atlus-61266.html
[P17]: https://www.sega.jp/topics/detail/230421_2/
[W01]: https://w.atwiki.jp/sekaiju_maze/pages/9.html
[W02]: https://w.atwiki.jp/sekaiju_maze/pages/99.html
[W04]: https://w.atwiki.jp/sekaiju_maze/pages/78.html
[W05]: https://w.atwiki.jp/sekaiju_maze/pages/236.html
[W06]: https://w.atwiki.jp/sekaiju_maze/pages/57.html
[W07]: https://w.atwiki.jp/sekaiju_maze2/pages/52.html
[W08]: https://w.atwiki.jp/sekaiju_maze2/pages/51.html
[W09]: https://w.atwiki.jp/sekaiju_maze2/pages/58.html
[W10]: https://privespa.org/sekaiju2/maze3/map15.html
[W11]: https://wildancer.blog.jp/sq2encmap.html
[W14]: https://w.atwiki.jp/sekaiju_maze3/pages/59.html
[W15]: https://w.atwiki.jp/sekaiju_maze3/pages/83.html
[W16]: https://w.atwiki.jp/sekaiju_maze3/pages/17.html
[W17]: https://w.atwiki.jp/sekaiju_maze3/pages/125.html
[W21]: https://w.atwiki.jp/sekaiju_mazeiv/pages/45.html
[W22]: https://privespa.org/sekaiju4/tebiki/tebiki2.html
[W23]: https://w.atwiki.jp/sekaiju_mazeiv/pages/81.html
[W24]: https://privespa.org/sekaiju4/map/maze3/chiteiko.html
[W25]: https://privespa.org/sekaiju4/story/story.html
[W26]: https://mochior.blog.fc2.com/blog-entry-364.html
[W27]: https://w.atwiki.jp/sekaiju_mazev/pages/5.html
[W28]: https://w.atwiki.jp/sekaiju_mazev/pages/54.html
[W29]: https://w.atwiki.jp/sekaiju_mazev/pages/106.html
[W30b]: https://ds-can.com/sekaiju5/story/a25.html
[W31]: https://ds-can.com/sekaiju5/class/class_about.html
[W32]: https://gamesp.net/sq5/capture/allmisson.html
[W33]: https://gamesp.net/sq5/capture/c001.html
[W35]: https://w.atwiki.jp/sekaiju_mazex/pages/85.html
[W36]: https://w.atwiki.jp/sekaiju_mazex/pages/104.html
[W37]: https://w.atwiki.jp/sekaiju_mazex/pages/89.html
[W38]: https://etrian.fandom.com/wiki/Maginia
[W40]: https://w.atwiki.jp/sekaiju_maze3/pages/87.html
[W41]: https://privespa.org/sekaiju3/maze6/map25.html
[W42]: https://w.atwiki.jp/sekaiju_maze2/pages/209.html
[U01]: https://w.atwiki.jp/shinsekaiju_maze/pages/21.html
[U03]: https://privespa.org/shin_sekaiju1/memo/qamemo.html
[U05]: https://w.atwiki.jp/shinsekaiju_maze/pages/44.html
[U07]: https://w.atwiki.jp/ssekaiju_maze2/pages/51.html
[U08]: https://privespa.org/shinsekaiju2/memo/intai.html
[U09]: https://w.atwiki.jp/ssekaiju_maze2/pages/33.html
[U10]: https://privespa.org/shinsekaiju2/map1/g01.html
[F01]: https://etrian.fandom.com/wiki/Stratum_Boss
[F02]: https://etrian.fandom.com/wiki/Yggdrasil_Labyrinth_%28Etrian_Odyssey_III%29
[F03]: https://etrian.fandom.com/wiki/Missions_%28Etrian_Odyssey_III%29
[R01]: https://www.atlus.co.jp/copyright/
[R02]: https://www.atlus.co.jp/news/21478/
[R03]: https://www.sega.co.jp/streaming_guideline/
[C01]: https://github.com/BastiaanOlij/godot_dungeon
[C02]: https://github.com/antzGames/Godot-A-Star-Pathfinding-for-Gridmaps
[C03]: https://github.com/crawl/crawl
[C04]: https://apps.apple.com/us/app/the-quest/id1135197236
[C05]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
