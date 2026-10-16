# holoknight_alpha_edit

- 생성: 2026-10-16, Codex `image_gen` (gpt-6-astra) 편집, 1회(재시도·차단 없음, 프롬프트 수정 없음), `transparent_background=true`
- 편집 대상(참고 이미지 1장): `assets/concept/holoknight_eo_b2.png`
- 용도: M0 투명 배경 시험 — 승인된 흰 배경 그림을 편집으로 투명하게. 게임에 쓰지 않는다
- 결과: 1024×1536 RGBA. 알파 0이 42.0%, 알파 최댓값 254(얼굴·옷 253). 홀로그램이 반투명으로 남는다(방패 안쪽 알파 87 ≈ 34%, 어깨 230, 정강이 192). 얼굴·머리·자세·장비 배치는 B2 그대로이고 홀로그램 금색·음영만 조금 바뀌었다. 결과 정리는 03 §2 M0

```text
Edit image 1: remove the white background so it becomes fully transparent (alpha 0). Keep the character, her colors, outlines, pose and every detail exactly as they are; do not redraw, restyle or crop anything. The gold hologram parts (pauldrons, plume, greaves and the large kite shield) must stay semi-transparent so the background shows through them. No shadow, halo or white fringe around the outline. Output size 1024 x 1536.
```
