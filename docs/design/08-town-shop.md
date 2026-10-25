# 마을·상점 (M3 R4)

원작 HD 상점 짜임(research 06 §2)을 옮긴다.

사용자 결정(D24, 2026-10-25):
- 가방은 지금처럼 쌓는다(07 §5.6).
- 소모품 갈래는 두되 빈 목록이다.
- 상점 화면을 먼저 만들고, 마을 골격 전에는 디버그 주소에서만 보이는 임시 입구로 연다.

단계는 S1 자료·규칙 → S2 부품 → S3 화면 → S4 마을에서 열기다. 이 문서는 지금 S1을 정한다. S2~S4는 그 단계 전에 더하고, 그때까지는 research 06 §4가 제안이다.

값(값·판매값·시작 소지금·풀림 조건)은 모두 자체 값이고 밸런스는 나중이다. 원작 수치는 조사하지 못했다(research 06 §6).

## 1. 상점 정의(자료)

### 1.1. 장비 값·소재 판매값

- `data/items/equipment.json`: 장비마다 필수 `price`(구매값, 1~999,999 정수).
- 장비 판매값 = `price` ÷ 2(버림, 최소 1).
- `data/items/materials.json`: 소재마다 필수 `sell`(판매값, 1~99,999 정수).

### 1.2. 상점 파일 `data/shop/<이름>.json`

```json
{
  "id": "shop.junk_workshop",
  "name_key": "shop.junk_workshop",
  "stock": [
    {"item": "equip.training_sword"},
    {"item": "equip.ion_saber", "unlock": {"item.cable_scale": 3, "item.glow_scale": 1}},
    {"item": "equip.aegis_plate", "unlock": {"item.beetle_plate": 2, "item.intact_pincer": 1}, "limited": true}
  ]
}
```

키:
- `id`: `shop.` 접두. 다른 정의 ID와 겹치면 안 된다.
- `name_key`: 글자 표에 있어야 한다.
- `stock`: 줄이 1개 이상인 배열.

줄:
- `item`: 필수, 장비 ID. 소모품은 다음 단계다.
- `unlock`: 선택. 소재 ID → 1~999 정수. 없으면 처음부터 판다. 빈 사전이면 오류다.
- `limited`: 선택, 참·거짓. 참이면 `unlock`이 있어야 한다.

검사:
- 오류: 모르는 키, 모르는 장비·소재, 한 상점에 같은 장비 두 줄, `unlock` 없는 `limited`, 범위 밖 수, 타입이 다른 값.
- 경고(실패 아님): 어느 상점에도 없는 장비.

읽기:
- 정의 폴더(`res://data`) 종류에 `shop`을 더한다.
- 다른 정의와 같은 방식이다: 파일 경로 순, 키 검사, 파일 사이 참조 검사(`BattleDb`).

### 1.3. 첫 상점 「정크 공방」 진열

세계관의 상점 이름이다(04 §2.2 「마을 시설」). 진열 차례가 목록 차례다(research 06 §2.2): 무기(검 → 지팡이), 방어구(몸 → 방패 → 머리 → 손 → 다리), 장신구.

| 차례 | 장비 | 값 | 풀림 조건(누적 판 소재) | 한정 |
|---|---|---|---|---|
| 1 | `training_sword` | 60 | 처음부터 | |
| 2 | `twin_edge` | 120 | 처음부터 | |
| 3 | `ion_saber` | 360 | 케이블 인분 3 · 발광 인분 1 | |
| 4 | `nano_rod` | 60 | 처음부터 | |
| 5 | `glyph_stylus` | 80 | 처음부터 | |
| 6 | `tactical_baton` | 220 | 드릴 발톱 2 | |
| 7 | `focus_staff` | 300 | 포자 주머니 3 · 발광 인분 1 | |
| 8 | `padded_coat` | 60 | 처음부터 | |
| 9 | `medic_coat` | 60 | 처음부터 | |
| 10 | `glyph_robe` | 60 | 처음부터 | |
| 11 | `mesh_armor` | 280 | 피복 비늘 3 | |
| 12 | `training_shield` | 50 | 처음부터 | |
| 13 | `aegis_plate` | 400 | 갑충 장갑판 2 · 온전한 집게 1 | 한정 |
| 14 | `sensor_cap` | 40 | 처음부터 | |
| 15 | `visor` | 150 | 네온 쥐 꼬리 3 | |
| 16 | `grip_gloves` | 40 | 처음부터 | |
| 17 | `servo_gauntlet` | 240 | 온전한 집게 2 | |
| 18 | `mag_boots` | 200 | 드릴 발톱 3 | |
| 19 | `signal_charm` | 80 | 처음부터 | |
| 20 | `antitox_chip` | 320 | 포자 주머니 2 | |
| 21 | `thermal_ring` | 300 | 피복 비늘 2 · 갑충 장갑판 1 | 한정 |

- 소재 판매값: 네온 쥐 꼬리 8, 케이블 인분 12, 발광 인분 20, 포자 주머니 10, 피복 비늘 14, 드릴 발톱 16, 갑충 장갑판 18, 온전한 집게 30.
- 장비의 「얻는 길」(07 §5.5 표)은 상점이 들어가면 「상점」·「상점(풀림)」으로 바뀐다. 임시 보급(디버그)은 그대로 둔다.

## 2. 상태

- `ExplorationState.money`: 소지금, 0~9,999,999 정수. 새 게임은 시작 소지금 200이다.
- `ExplorationState.shop`(`ShopState`):
  - `sold`: 소재 ID → 누적 판 수(1~9,999,999, 0이면 키를 두지 않는다). 줄지 않는다. 풀림은 이것으로 본다.
  - `pool`: 소재 ID → 한정 물건에 아직 쓰지 않은 수(1~`sold[소재]`, 0이면 키를 두지 않는다). 소재를 팔면 늘고, 한정 물건을 사면 준다.
  - `bought`: 한 번이라도 산 장비 ID의 집합.
- 상점이 하나라 상점 상태도 하나다. 상점이 여럿이 되면 상점 ID별로 나눈다.
- **풀림**: 진열 줄의 `unlock`에 적힌 소재가 모두 `sold`에 그 수 이상이면 풀린 것이다. 처음부터 파는 줄은 늘 풀려 있다. `sold`가 줄지 않으므로 한 번 풀리면 계속 풀려 있다.
- **한정 재고**(research 06 §2.6, 원작 「売った材料分しか買えず」): 풀린 한정 줄의 남은 수 = 소재마다 `pool[소재] ÷ unlock[소재]`(버림) 가운데 가장 작은 값.
- **NEW**: 풀렸고 아직 사지 않은 물건이다(`bought`에 없음). 원작 그림에서 추정했다(research 06 §2.3).

## 3. 규칙 함수 `ShopRules`

`src/core/shop/shop_rules.gd`(상태는 `src/core/shop/shop_state.gd`).

공통:
- 난수·시간·걸음을 쓰지 않는다.
- 거부하면 상태는 그대로이고, 사건 하나 `{type: "rejected", reason}`를 돌려준다.
- 받아들이면 부른 화면이 자동 저장한다(07 §8.5와 같다).
- 전투 중·전투 대기·전멸이면 `not_now`다(`GrowthRules`와 같은 때).

### 3.1. 읽기

- `catalog(defs, state, shop_id) -> Array[Dictionary]`
  - 풀린 줄만, 진열 차례로 돌려준다.
  - 줄: `{item, price, limited, stock, new, affordable}`. `stock`은 한정이면 남은 수, 아니면 −1이다.
  - 모르는 상점이면 빈 배열이다.
- `shortage(defs, state, shop_id, item_id) -> Dictionary`
  - 한정 줄을 하나 더 사려면 모자란 소재 → 수를 돌려준다.
  - 살 수 있거나, 한정이 아니거나, 모르는 물건이면 빈 사전이다. 원작 「…が足りません」 자리다.
- `buy_price(defs, item_id) -> int`
  - 장비의 `price`, 모르면 0이다.
- `sell_price(defs, item_id) -> int`
  - 장비 = `price ÷ 2`(최소 1), 소재 = `sell`, 모르면 0이다.

### 3.2. 사기 `buy(state, shop_id, item_id, qty) -> Array[Dictionary]`

판정 순서:
1. `not_now`
2. `unknown_shop`
3. `unknown_item`: 그 상점 진열에 없다.
4. `locked`
5. `bad_amount`: `qty`가 1~99 정수가 아니다. 참·거짓과 정수가 아닌 실수는 거부한다.
6. `sold_out`: 한정인데 남은 수가 `qty`보다 적다.
7. `no_money`: 소지금이 값 × `qty`보다 적다.
8. `bag_full`: 가방 개수 + `qty`가 99를 넘는다.

통과하면:
- 소지금에서 값 × `qty`를 빼고, 가방에 `qty`를 더한다.
- 한정이면 `pool`에서 `unlock × qty`를 뺀다(0이면 키를 지운다).
- `bought`에 더한다.
- 사건은 `{type: "bought", item, qty, cost, money}`다.

화면은 원작처럼 장비를 한 번에 하나씩 산다(S3). 규칙은 수량을 받는다(시험, 다음 단계 소모품).

### 3.3. 팔기 `sell(state, shop_id, lines) -> Array[Dictionary]`

`lines`는 `[{item, qty}]`다. 소재 또는 가방에 있는 장비를 판다. 장착한 장비는 가방에 없으므로 팔 수 없다(07 §5.6, research 06 §2.6).

판정 순서:
1. `not_now`
2. `unknown_shop`
3. `bad_lines`: 배열이 아니거나, 비었거나, 줄이 사전이 아니거나, 줄의 키가 `item`·`qty`가 아니거나, 같은 물건이 두 줄이다.
4. 줄마다 차례로:
   - `unknown_item`: 소재도 장비도 아니다.
   - `bad_amount`: 1~9,999 정수가 아니다.
   - `not_owned`: 가진 수보다 많다.
5. `money_full`: 소지금 + 판 값이 9,999,999를 넘는다.

통과하면 한 묶음으로 처리한다(research 01 §4.4):
- 물건을 뺀다(0이면 키를 지운다).
- 소지금에 판 값의 합을 더한다.
- 소재는 `sold`·`pool`에 판 수를 더한다(9,999,999에서 멈춘다).
- 사건 `{type: "sold", lines: [{item, qty, gain}], gain, money}`를 돌려준다.
- 이 판매로 처음 풀린 줄이 있으면 이어서 `{type: "unlocked", shop, items}`를 돌려준다. `items`는 진열 차례다.

장비를 팔아도 풀림·재고에는 들어가지 않는다. 원작은 소재를 팔아 풀린다(research 06 §2.6).

## 4. 저장 4판

- 머리: `schema` 4, `rules` `"m3s"`. 받는 쌍에 `4: "m3s"`를 더한다.
- `state`에 두 키를 더한다. 둘 다 정규화 문자열(해시)에 들어간다.
  - `money`: 정수.
  - `shop`: `{"sold": {}, "pool": {}, "bought": []}`. `bought`는 정렬한 배열로 쓴다.
- 검사:
  - `money`: 0~9,999,999 정수.
  - `shop`: 키가 정확히 셋이다.
  - `sold`·`pool`: 아는 소재 → 범위 안 정수.
  - `pool`의 키는 `sold`에도 있어야 하고 `pool[소재] ≤ sold[소재]`다.
  - `bought`: 서로 겹치지 않는 아는 장비 ID 문자열이다.
- 이전(07 §8.4와 같은 방식):
  1. 1·2·3판은 지금처럼 그 판 규칙으로 다 검사한다.
  2. 통과한 상태에 `money` = 시작 소지금, `shop` = 빈 상태를 넣는다.
  3. 원본 `saved_at`·`generation`으로 4판을 쓴다.
  4. 4판 읽기를 그대로 거친 결과만 돌려준다.
  - `from_schema`는 원본 판이다.

## 5. 시험(S1)

- **자료**:
  - 모든 장비에 `price`, 모든 소재에 `sell`이 범위 안에 있다.
  - 상점 파일 참조가 맞다.
  - §1.2 오류 갈래마다 하나씩 거부된다.
- **규칙**:
  - 진열: 잠긴 줄은 숨고, 처음부터 파는 줄은 보인다. NEW는 사기 전까지다. `affordable`.
  - 사기: 통과, 그리고 §3.2 거부 갈래마다 하나. 가방 99 경계, 한정 소모·바닥.
  - 팔기: 소재·가방 장비 통과, 장착한 장비는 `not_owned`, §3.3 거부 갈래마다 하나.
  - 풀림: 처음 한 번만 `unlocked`가 나고 진열 차례다. 여러 번에 나눠 판 소재도 누적된다. 한정 재고는 `pool`으로 다시 찬다.
  - 거부하면 정규화 상태가 그대로다.
- **저장**:
  - 4판 왕복(소지금·상점 상태 포함).
  - 1·2·3판 이전: 소지금 = 시작 소지금, 빈 상점.
  - 4판 검사 거부 갈래마다 하나.
  - 기존 저장 시험의 강도를 그대로 둔다.
- **새 게임**: 소지금 200, 빈 상점.

## 6. 구현 메모(S1, 2026-10-25)

명세가 정하지 않아 구현이 정한 것이다. 코드가 기준이다.

- **범위 이름**(`BattleLimits.RANGES`):
  - `price` 1~999,999, `sell` 1~99,999, `unlock` 1~999.
  - `money` 0~9,999,999.
  - `sold` 1~9,999,999: `sold`·`pool` 둘 다의 형식 범위다. `pool ≤ sold`는 따로 검사한다.
  - `buy_qty` 1~99, `sell_qty` 1~9,999.
  - 상수 `MONEY_MAX` = `SOLD_MAX` = 9,999,999.
- **시작 소지금** `ExplorationState.START_MONEY`(200):
  - `ShopRules`가 아니라 상태에 둔다. `ShopRules`는 이미 `SaveCodec.to_int`를 쓰는데, 이전(`SaveCodec`)이 시작 소지금을 쓰므로 `ShopRules`에 두면 서로 가리키게 된다.
- **자료 읽기**:
  - 상점 파일의 `id`·`name_key`·`stock`은 모두 필수다.
  - 접두는 `item` = `equip.`, `unlock` 키 = `item.`, `id` = `shop.`이다.
  - `limited: false`는 `unlock` 없이도 받는다.
  - 소재 판매값은 `BattleDb.material_sell`, 장비 값은 `EquipDef.price`, 진열은 `ShopDef`(`stock`·`stock_at`·`line()`)에 둔다.
  - 장비·소재 참조와 「어느 상점에도 없는 장비」 경고는 `_check_refs`가 본다.
- **4판 읽기 차례**: 대원 → 세계·지식·지도·조우·기타 → 일관성 → `materials` → `gear_bag` → `money` → `shop` → `battle`.
  - `bought`는 읽을 때 차례를 보지 않는다. 쓸 때 정렬하므로 해시는 차례와 상관없다.
  - 3판 파일에 섞인 `money` 같은 모르는 위 키는 전처럼 무시한다. 그때도 소지금은 시작 소지금이 된다.
  - 3판 검사 실패는 「3판 검사 실패: 」로, 다시 읽기 실패는 「3판 이전 결과 검사 실패: 」로 시작한다.
- **`ShopRules` 세부**:
  - `buy`·`sell`은 `defs`를 받지 않고 `state.defs`를 쓴다(§3.2·§3.3 꼴 그대로).
  - 공개 도움 함수 `unlocked(shop, line)`·`stock_of(shop, line)`가 있다.
  - `affordable`은 한 개 값 기준이다(재고·가방은 보지 않는다).
  - `shortage`는 잠긴 한정 줄에도 `pool`로 센다. 잠긴 줄은 진열에 없으므로 화면은 부르지 않는다.
  - 팔기 줄의 키는 정확히 `item`·`qty`다.
    - 같은 물건은 자료형까지 같은 값으로 가린다.
    - 문자열이 아닌 `item`은 `unknown_item`이다.
    - 줄 안의 판정 순서는 `unknown_item` → `bad_amount` → `not_owned`다.
  - `sold` 사건의 `lines`는 받은 차례이고, `qty`는 바꾼 정수다.
  - 수량은 정수와 같은 실수(`2.0`)도 받는다(`GrowthRules.supply`와 같다). 참·거짓, 정수가 아닌 실수, 문자열은 거부한다.
  - `sold`·`pool`은 같은 만큼 더하고 상한에서 멈추므로 `pool ≤ sold`가 유지된다. 소지금은 판 값을 다 받는다(넘으면 `money_full`로 거부).
  - `bought`는 「한 번이라도 산」 집합이라 팔아도 NEW가 돌아오지 않는다.
