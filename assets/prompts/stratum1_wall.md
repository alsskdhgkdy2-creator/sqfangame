# stratum1_wall

- 생성: 2026-10-16, Codex `image_gen` (gpt-6-astra), 1회 생성(재시도·차단 없음, 프롬프트 수정 없음), `transparent_background=false`
- 참고 이미지: 없음
- 용도: M0 이음새 시험 — 첫 계층(배선이 덩굴처럼 자란 네온 이끼 숲)의 벽. `tools/tile_check.py fix --size 512` 로 보정·축소한 판을 M0 복도에 입혔다(`assets/textures/stratum1/wall.png`)
- 결과: 1254×1254 RGB(1024×1024 요청과 다름, 도구에 크기 인수가 없다). 2×2로 이어 붙여 원본 해상도로 봐도 무늬가 끊긴 곳은 없다. 수치로는 가장자리 줄이 그림에서 가장 튀는 줄이다(이웃비 가로 1.70·세로 1.97) → 보정 뒤 0.33·0.53. 결과 정리는 `docs/design/03-production-plan.md` §2 M0

```text
Seamless tileable wall texture for a first-person grid dungeon in an unofficial Etrian Odyssey fan game (a cyber-fantasy fan sequel). The first stratum is a forest growing inside a giant mechanical world tree: cables grow through it like vines and neon moss glows on the bark.
Use case: game texture. Generate ONE image, square 1:1, exactly 1024 x 1024 pixels.
Subject: a dense, flat wall of tangled tree trunks and thick roots packed side by side; patches of the bark are fused with dark riveted metal plates; bundles of black and dark-green cables twist through the trunks like vines; scattered patches of glowing cyan-green neon moss and a few tiny luminous crystal buds.
View: straight-on orthographic view of the wall surface, filling the whole square. No perspective, no horizon, no floor, ceiling or sky, no depth fog.
Tiling: the texture must wrap seamlessly on all four edges — anything crossing an edge continues on the opposite edge. Even, uniform density across the whole square so repetition is not obvious. No border, frame, vignette, cast shadows from outside, or lighting gradient; evenly lit.
Style: hand-painted game texture that sits well beside anime cel-shaded characters with thick outlines: clear dark shapes, simplified hard-edged shading, readable when small, in the spirit of the forest labyrinth walls of the Etrian Odyssey series but cybernetic. Palette mostly deep green, dark teal and charcoal; the neon moss is the only bright accent. No text, logos, symbols, faces, creatures or characters.
```
