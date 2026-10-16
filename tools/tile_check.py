"""바둑판 텍스처 이음새 검사·미리보기.
사용:
  python3 tools/tile_check.py check <그림> [<그림> ...]
      맞닿는 가장자리(오른쪽 끝↔왼쪽 끝, 아래 끝↔위 끝)의 색 차이를 안쪽 이웃 픽셀 차이와 비교한다.
      이웃 비: 가장자리 차이 / 안쪽 평균 차이. 1 근처면 이음새가 안쪽 결과 같다.
      순위: 안쪽 이웃 쌍 가운데 가장자리보다 차이가 작은 쌍의 비율. 0.99를 넘으면 그림에서 가장 튀는 줄이다.
      밝기 띠: 16칸 띠 평균 밝기로 같은 비를 잰다(양 끝 밝기·색조가 달라 바둑판 무늬가 보이는지).
  python3 tools/tile_check.py preview <그림> <출력> [--grid 2] [--tile 512]
      그림을 grid×grid로 이어 붙인 미리보기(칸 하나를 tile 픽셀로 줄인다)
  python3 tools/tile_check.py fix <그림> <출력> [--size 512]
      주기+평활 분해(Moisan 2011)의 주기 성분만 남겨 가장자리 줄을 없앤다. 바뀌는 것은 가장자리에서 안쪽으로
      옅어지는 완만한 색 보정뿐이라 무늬는 그대로다. 무늬가 끊긴 이음새(덩굴이 가장자리에서 잘림)는 못 고친다.
      size를 주면 3×3으로 이어 붙여 줄인 뒤 가운데를 잘라, 줄인 그림도 이음새가 없게 한다.
"""
import argparse
import numpy as np
from PIL import Image


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0


def axis_scores(a, axis):
    """axis=1이면 가로(왼쪽↔오른쪽 끝), axis=0이면 세로(위↔아래 끝)."""
    inner = np.abs(np.diff(a, axis=axis)).mean(axis=(1 - axis, 2))
    edge = np.abs(np.take(a, 0, axis=axis) - np.take(a, -1, axis=axis)).mean()
    bands = np.array([b.mean() for b in np.array_split(a.mean(axis=2), 16, axis=axis)])
    band_inner = np.abs(np.diff(bands)).mean()
    band_edge = abs(bands[0] - bands[-1])
    return edge / inner.mean(), (inner < edge).mean(), band_edge / max(band_inner, 1e-6)


def check(paths):
    print(f"{'그림':<44} {'크기':>11}  {'가로 이웃비':>6} {'순위':>5} {'밝기띠':>5}  {'세로 이웃비':>6} {'순위':>5} {'밝기띠':>5}")
    for p in paths:
        a = load(p)
        x = axis_scores(a, 1)
        y = axis_scores(a, 0)
        size = f"{a.shape[1]}x{a.shape[0]}"
        print(f"{p:<44} {size:>11}  {x[0]:>10.2f} {x[1]:>5.3f} {x[2]:>6.2f}  {y[0]:>10.2f} {y[1]:>5.3f} {y[2]:>6.2f}")


def preview(src, out, grid, tile):
    im = Image.open(src).convert("RGB").resize((tile, tile), Image.LANCZOS)
    sheet = Image.new("RGB", (tile * grid, tile * grid))
    for j in range(grid):
        for i in range(grid):
            sheet.paste(im, (i * tile, j * tile))
    sheet.save(out, quality=90)
    print(out, sheet.size)


def periodic_part(u):
    """u(H, W) 한 채널의 주기 성분. 평활 성분 s는 가장자리 차이로 만든 경계 그림을 이산 라플라시안으로 푼 것."""
    h, w = u.shape
    v = np.zeros((h, w))
    d = u[-1, :] - u[0, :]
    v[0, :] += d
    v[-1, :] -= d
    d = u[:, -1] - u[:, 0]
    v[:, 0] += d
    v[:, -1] -= d
    q = np.arange(h).reshape(-1, 1)
    r = np.arange(w).reshape(1, -1)
    den = 2 * np.cos(2 * np.pi * q / h) + 2 * np.cos(2 * np.pi * r / w) - 4
    den[0, 0] = 1
    s_hat = np.fft.fft2(v) / den
    s_hat[0, 0] = 0
    return u - np.real(np.fft.ifft2(s_hat))


def fix(src, out, size):
    im = Image.open(src)
    mode = "RGBA" if "A" in im.getbands() else "RGB"
    a = np.asarray(im.convert(mode), dtype=np.float64) / 255.0
    p = np.stack([periodic_part(a[..., c]) for c in range(a.shape[2])], axis=2)
    res = Image.fromarray((np.clip(p, 0, 1) * 255 + 0.5).astype(np.uint8), mode)
    if size:
        w, h = res.size
        big = Image.new(mode, (w * 3, h * 3))
        for j in range(3):
            for i in range(3):
                big.paste(res, (i * w, j * h))
        res = big.resize((size * 3, size * 3), Image.LANCZOS).crop((size, size, size * 2, size * 2))
    res.save(out)
    print(out, res.size, f"평균 변화 {np.abs(p - a).mean() * 255:.2f}/255, 최대 {np.abs(p - a).max() * 255:.1f}/255")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("images", nargs="+")
    p = sub.add_parser("preview")
    p.add_argument("image")
    p.add_argument("out")
    p.add_argument("--grid", type=int, default=2)
    p.add_argument("--tile", type=int, default=512)
    f = sub.add_parser("fix")
    f.add_argument("image")
    f.add_argument("out")
    f.add_argument("--size", type=int, default=0, help="줄일 한 변 픽셀, 0이면 원래 크기")
    a = ap.parse_args()
    if a.cmd == "check":
        check(a.images)
    elif a.cmd == "preview":
        preview(a.image, a.out, a.grid, a.tile)
    else:
        fix(a.image, a.out, a.size)


if __name__ == "__main__":
    main()
