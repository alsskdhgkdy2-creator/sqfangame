"""웹 빌드(build/web)를 휴대폰 확인용으로 이 기기 안에서만(127.0.0.1) 띄운다. 큰 파일은 gzip으로 줄여 보낸다(wasm 39.5MB → 약 10MB).
사용: python3 tools/serve_web.py [포트, 기본 8765]
휴대폰에서 열 때는 cloudflared 임시 주소로 잠깐 연다(docs/CLOUD_TESTS.md 「이 기기에서 바로 확인」).
"""
import gzip
import http.server
import io
import pathlib
import sys
from functools import partial

ROOT = pathlib.Path(__file__).resolve().parent.parent / "build" / "web"
GZIP_SUFFIXES = {".wasm", ".pck", ".js", ".html"}
cache = {}


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def send_head(self):
        path = pathlib.Path(self.translate_path(self.path))
        if path.is_dir():
            path = path / "index.html"
        if path.suffix in GZIP_SUFFIXES and path.is_file() and "gzip" in self.headers.get("Accept-Encoding", ""):
            key = (path, path.stat().st_mtime)
            if key not in cache:
                cache[key] = gzip.compress(path.read_bytes(), 6)
            body = cache[key]
            self.send_response(200)
            self.send_header("Content-Type", self.guess_type(str(path)))
            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            return io.BytesIO(body)
        return super().send_head()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    if not (ROOT / "index.html").is_file():
        sys.exit(f"{ROOT}/index.html 이 없습니다. 먼저 tools/export_web.sh")
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=str(ROOT)))
    print(f"http://localhost:{port}/ ({ROOT})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
