#!/usr/bin/env python3
import ssl, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

_ctx = ssl.create_default_context()
_ctx.check_hostname = False
_ctx.verify_mode = ssl.CERT_NONE

SCHEME = 'https'
HOST = '127.0.0.1'
PORT = 5000

class ProxyHandler(BaseHTTPRequestHandler):
    def proxy(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else None
        hdrs = {k: v for k, v in self.headers.items()
                if k.lower() not in ('host', 'content-length')}
        url = f'{SCHEME}://{HOST}:{PORT}{self.path}'
        try:
            req = urllib.request.Request(url, data=body, method=self.command, headers=hdrs)
            with urllib.request.urlopen(req, context=_ctx, timeout=15) as resp:
                self.send_response(resp.status)
                for k, v in resp.headers.items():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(resp.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            print(f'Proxy error: {e}', flush=True)
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())
    def log_message(self, *a): pass
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = proxy

print('Proxy listening on 8080', flush=True)
HTTPServer(('0.0.0.0', 8080), ProxyHandler).serve_forever()
