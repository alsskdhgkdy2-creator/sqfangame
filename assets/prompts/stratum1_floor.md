# stratum1_floor

- 생성: 2026-10-16, Codex `image_gen` (gpt-6-astra), 1회 생성(재시도·차단 없음, 프롬프트 수정 없음), `transparent_background=false`
- 참고 이미지: 없음
- 용도: M0 이음새 시험 — 첫 계층 바닥. `tools/tile_check.py fix --size 512` 로 보정·축소한 판을 M0 복도에 입혔다(`assets/textures/stratum1/floor.png`)
- 결과: 1254×1254 RGB. 2×2로 이어 붙여도 이음새가 안 보인다. 이웃비 가로 1.43·세로 1.45 → 보정 뒤 0.35·0.38. 결과 정리는 03 §2 M0

```text
Seamless tileable floor texture for a first-person grid dungeon in an unofficial Etrian Odyssey fan game (a cyber-fantasy fan sequel). The first stratum is a forest growing inside a giant mechanical world tree: cables grow through it like vines and neon moss glows on the ground.
Use case: game texture. Generate ONE image, square 1:1, exactly 1024 x 1024 pixels.
Subject: forest floor seen from directly above: packed dark soil and flat interlaced roots mixed with worn metal floor panels and a section of rusted grating, thin cables snaking across like roots, scattered small patches of glowing cyan-green neon moss and a few fallen leaves.
View: top-down orthographic view filling the whole square. No perspective, no horizon, no walls.
Tiling: the texture must wrap seamlessly on all four edges — anything crossing an edge continues on the opposite edge. Even, uniform density across the whole square so repetition is not obvious. No border, frame, vignette, cast shadows from outside, or lighting gradient; evenly lit.
Style: hand-painted game texture that sits well beside anime cel-shaded characters with thick outlines: clear dark shapes, simplified hard-edged shading, readable when small, in the spirit of the forest labyrinth floors of the Etrian Odyssey series but cybernetic. Palette mostly dark brown, deep green and charcoal; the neon moss is the only bright accent. No text, logos, symbols, faces, creatures or characters.
```
