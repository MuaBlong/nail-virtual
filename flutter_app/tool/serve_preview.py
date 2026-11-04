"""Serve a compiled Flutter preview locally without retaining stale app files."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PreviewHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1] / 'build' / 'web'
    if not (root / 'main.dart.js').is_file():
        raise SystemExit('Build Flutter web before starting the preview.')
    server = ThreadingHTTPServer(('127.0.0.1', 8766), partial(PreviewHandler, directory=str(root)))
    print('Nail Virtual: http://127.0.0.1:8766/', flush=True)
    server.serve_forever()
