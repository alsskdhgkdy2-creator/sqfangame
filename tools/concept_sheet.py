"""컨셉 그림 비교 시트: 그림을 나란히 놓고, 아랫줄에 게임 화면 크기로 줄인 판을 붙인다.

사용: python3 tools/concept_sheet.py <출력.png|.jpg> <이름=그림> [<이름=그림> ...] [--height 720] [--small 192]
"""
import argparse
import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT = ROOT / "assets/fonts/NotoSansKR-Regular-subset.otf"
GAP = 16
LABEL_H = 48


def fit(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("out")
    ap.add_argument("items", nargs="+", help="이름=그림 경로")
    ap.add_argument("--height", type=int, default=720)
    ap.add_argument("--small", type=int, default=192, help="게임 화면 크기 줄의 높이, 0이면 뺀다")
    a = ap.parse_args()

    font = ImageFont.truetype(str(FONT), 30)
    items = [s.split("=", 1) for s in a.items]
    big = [fit(Image.open(p).convert("RGB"), a.height) for _, p in items]
    width = sum(im.width for im in big) + GAP * (len(big) + 1)
    height = LABEL_H + a.height + GAP + (a.small + GAP if a.small else 0)
    sheet = Image.new("RGB", (width, height), (225, 225, 225))
    draw = ImageDraw.Draw(sheet)
    x = GAP
    for (name, _), im in zip(items, big):
        draw.text((x, 6), name, font=font, fill=(20, 20, 20))
        sheet.paste(im, (x, LABEL_H))
        if a.small:
            sheet.paste(fit(im, a.small), (x, LABEL_H + a.height + GAP))
        x += im.width + GAP
    sheet.save(a.out, quality=88)
    print(a.out, sheet.size)


if __name__ == "__main__":
    main()
