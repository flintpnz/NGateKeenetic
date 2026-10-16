# Имитация RCI прошивки на 127.0.0.1:79: POST {"parse": "..."} -> ndmc, GET .../layer -> conf.
import json, subprocess, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

STATE = "/var/lib/ndm-sim.conf-layer"   # "running" | "disabled"


class H(BaseHTTPRequestHandler):
    def _send(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        req = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        cmd = req["parse"]
        subprocess.run(["/usr/local/bin/ndmc", "-c", cmd])
        self._send({"parse": {"status": [{"status": "message", "message": "ok: " + cmd}]}})

    def do_GET(self):
        try:
            conf = open(STATE).read().strip()
        except OSError:
            conf = "running"
        self._send({"conf": conf, "link": "running"})

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", 79), H).serve_forever()
