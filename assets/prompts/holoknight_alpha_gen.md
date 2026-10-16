# holoknight_alpha_gen

- 생성: 2026-10-16, Codex `image_gen` (gpt-6-astra), 1회 생성(재시도·차단 없음), `transparent_background=true`
- 프롬프트: `holoknight_eo_b2.md` 전문에서 `Scene/backdrop:` 한 줄만 투명 배경 문장으로 바꿈
- 참고 이미지(이 순서): `artstyle_reference/styles/thick-lineart-hard-cel/` 의 `reference/ref1_purple_jacket_grin.png`, `reference/ref3_crimson_hair_dark_dress.png`, `reference/ref5_purple_robe_mage.png`, `generated/eo05_landsknecht.png`, `generated/eo06_medic.png` (B2와 같음, 모두 스타일 참고)
- 용도: M0 투명 배경 시험 — 투명 배경으로 바로 생성. 게임에 쓰지 않는다
- 결과: 1024×1536 RGBA. 알파 0이 37.4%, 알파 최댓값 254(255 없음, 얼굴·옷도 253). 홀로그램이 거의 불투명하다(방패 안쪽 알파 250 ≈ 98%) — 어두운 배경 위에서 금속 갑옷처럼 보인다. 새 생성이라 B2와 얼굴·문장·검 모양이 다르다. 결과 정리는 03 §2 M0

```text
Original character for an unofficial Etrian Odyssey fan game: a cyber-fantasy fan sequel in which explorer guilds descend a giant mechanical world-tree labyrinth. 2D anime-style full-body character stand art, clearly a drawn illustration, not a real person, not photorealistic.
Use case: stylized-concept.
Asset type: class concept art, revision of the balanced cyber-fantasy variant. Generate ONE image, portrait 2:3, exactly 1024 x 1536 pixels.
Input images 1–5 are STYLE REFERENCES ONLY: use all five for the linework, hard shadow shapes, face drawing, proportions and the classic Etrian Odyssey class-portrait finish; do not copy any reference character's face, hairstyle, costume, weapon or identity. This is a NEW class design, as if from a new numbered entry of the series.

Scene/backdrop: fully transparent background (alpha 0). No backdrop color, floor, ground/contact shadow or glow haze outside the character; the hologram parts stay semi-transparent so the background shows through them.

Class: Holo Knight, the party's front-row shield defender, a cyber-fantasy take on the series' classic paladin-type shield class.
Character identity: one adult woman, steady and protective, with a confident slight smile. Glossy black hair with a deep navy sheen in a short layered cut, chunky clumps with spiky split tips, no braid. Both eyes clearly visible, amber irises. A slim cybernetic headset wraps around her ears with small swept-back fin guards, and a small translucent gold monocle HUD lens sits over her left eye only. Color scheme: deep navy, gunmetal and off-white, with gold as the only glow color. Original heraldic crest: a hollow diamond crossed by one vertical bar, with three short rays above it. A compact circular force-field emitter on her LEFT forearm projects a very large translucent gold kite-shaped shield bearing the crest. Her right hand holds a short broad one-handed sword low at her side, gunmetal blade with a thin gold edge glow.
Composition/framing: full body, front view turned slightly into three-quarter view, feet planted wide in a braced guarding stance. Left forearm held forward presenting the shield, on the viewer's right; the shield sits beside the torso so the body stays legible. Keep the whole silhouette, hair, boots, sword and shield comfortably inside the canvas with clear white margin.

Balanced cyber-fantasy treatment: the physical body is a sleek armored cyber-suit — navy and gunmetal segmented plates, exposed mechanical elbow and knee joints, short visible cable bundles, both forearms cybernetic. Classic adventurer cloth stays real and opaque over it: an off-white tabard showing the crest in navy, a belt with two navy pouches, a short navy shoulder cape. Over and just outside the body floats a transparent GOLD fantasy-knight projection: luminous contours of broad pauldrons, a helmet crest with a swept-back plume rising above the headset (her face stays uncovered), clearly visible projected greaves over both shins, and the large kite shield.

Hologram rendering: gold parts read as emitted light and transparent volume, never solid gold metal or opaque yellow armor. Fine horizontal scanlines, a few small rectangular glitch fragments at their edges, sparse abstract rune marks (nonlinguistic ornament, not readable text). Crisp restrained glow, no fog or background wash. The hologram may use thin luminous gold contours instead of black outlines.

Style/medium: full-body anime character illustration in the vein of Etrian Odyssey character designs: thick bold black outlines, hard two-tone cel shading, flat colors, sharp-edged angular shadows, large near-black shadow masses (spot blacks) in hair and deep folds, small white planar highlights on metal and boots. Face with small pupils, thick upper eyelashes and small blush dots. Stocky stylized proportions about 4.5–5 heads tall: big head, short torso, thick thighs, wide stance, chunky boots. Hair in chunky clumps with sharp, spiky split tips. Practical adventurer gear in the series' tradition, with purposeful details rather than clutter.
Rendering priority: bold thick black outer contours on all physical parts, simple flat two-tone fills, graphic spot blacks, stocky anatomy with crown-to-chin head height about 21–23% of standing height (excluding the plume). Body anatomically continuous in correct perspective; hands and the sword grip coherent and legible. Avoid white or silver hair, blindfolds or eye-covering visors, intricate micro-patterns, excessive stacked buckles and belts, soft gradients, painterly rendering, extra weapons and extra characters. No text, labels, watermark or signature.
```
