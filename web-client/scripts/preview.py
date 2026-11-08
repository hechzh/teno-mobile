"""Loopback-only preview, forwarding the unchanged Teno API. Never logs bodies/tokens."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import requests

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8787)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1] / 'build' / 'web'

class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root), **kwargs)

    def do_GET(self):
        if self.path.startswith('/api/') or self.path.startswith('/health/'):
            return self.proxy()
        if self.path == '/app':
            self.send_response(302); self.send_header('Location', '/app/'); self.end_headers(); return
        if not self.path.startswith('/app/'):
            self.send_error(404); return
        self.path = '/' + self.path[len('/app/'):]
        super().do_GET()

    def proxy(self):
        if not (self.path.startswith('/api/v1/') or self.path.startswith('/health/')):
            self.send_error(404); return
        body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
        headers = {k: self.headers[k] for k in ('Content-Type', 'Authorization', 'Range') if k in self.headers}
        session = requests.Session(); session.trust_env = False
        try:
            r = session.request(self.command, 'https://54-214-180-183.sslip.io' + self.path,
                data=body or None, headers=headers, timeout=300, allow_redirects=False)
            self.send_response(r.status_code)
            for k in ('Content-Type', 'Content-Disposition', 'Content-Range', 'Accept-Ranges'):
                if k in r.headers: self.send_header(k, r.headers[k])
            self.send_header('Content-Length', str(len(r.content)))
            self.send_header('Cache-Control', 'no-store'); self.end_headers(); self.wfile.write(r.content)
        except requests.RequestException:
            self.send_error(502, 'Teno API unavailable')

    do_POST = do_PUT = do_PATCH = do_DELETE = proxy

print(f'Teno preview: http://127.0.0.1:{args.port}/app/', flush=True)
ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
