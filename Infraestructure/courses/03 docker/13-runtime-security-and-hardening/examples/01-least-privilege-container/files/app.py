"""Minimal HTTP server. Stdlib only; no writes to disk."""
import os
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (
            f"ok uid={os.getuid()} gid={os.getgid()} pid={os.getpid()}\n"
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):  # noqa: A002
        pass  # Silence default access log; stdout stays clean.


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    srv = HTTPServer(("0.0.0.0", port), Handler)
    print(f"listening on :{port} as uid={os.getuid()}", flush=True)
    srv.serve_forever()
