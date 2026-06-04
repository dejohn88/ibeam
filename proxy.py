#!/usr/bin/env python3
import ssl, urllib.request, urllib.error
from http.server import BaseHTTPRequestHandler, HTTPServer

TARGET = '<https://127.0.0.1:5000>'
_ctx = ssl.create_default_context()
_ctx.check_hostname = False
_ctx.verify_mode = ssl.CERT_NONE

class ProxyHandler(BaseHTTPRequestHandler):
    def proxy(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(TARGET + self.path, data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in ('host', 'content-length'):
                req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, context=_ctx, timeout=60) as r:
                self.send_response(r.status)
                for k, v in r.headers.items():
                    self.send_header(k, v)
                self.end_headers()
                self.wfile.write(r.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())
    def log_message(self, *a): pass
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = proxy

HTTPServer(('0.0.0.0', 8080), ProxyHandler).serve_forever()
