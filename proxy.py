#!/usr/bin/env python3
import ssl, http.client
from http.server import BaseHTTPRequestHandler, HTTPServer

_ctx = ssl.create_default_context()
_ctx.check_hostname = False
_ctx.verify_mode = ssl.CERT_NONE

class ProxyHandler(BaseHTTPRequestHandler):
    def proxy(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else None
        hdrs = {k: v for k, v in self.headers.items()
                if k.lower() not in ('host', 'content-length')}
        try:
            conn = http.client.HTTPSConnection('127.0.0.1', 5000, context=_ctx)
            conn.request(self.command, self.path, body, hdrs)
            resp = conn.getresponse()
            self.send_response(resp.status)
            for k, v in resp.getheaders():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(resp.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())
    def log_message(self, *a): pass
    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = proxy

print('Proxy listening on 8080', flush=True)
HTTPServer(('0.0.0.0', 8080), ProxyHandler).serve_forever()
