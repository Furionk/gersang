"""Local-only browser acceptance server: interrupt one chunk, corrupt another once."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json
import socket
import sys
from threading import Lock

folder = Path(sys.argv[1]).resolve()
lock = Lock()
counts = {}
faults = {}
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(folder), **kwargs)
    def do_GET(self):
        if self.path == '/diagnosis.json':
            with lock:
                body = json.dumps({'requests': counts, 'faults': faults}).encode()
            self.send_response(200); self.send_header('Content-Type', 'application/json'); self.send_header('Content-Length', len(body)); self.end_headers(); self.wfile.write(body); return
        self.path = self.path.removeprefix('/gersang')
        with lock:
            counts[self.path] = counts.get(self.path, 0) + 1
            first = counts[self.path] == 1
        if first and self.path.endswith(('index.pck.0000.bin', 'index.wasm.0000.bin')):
            data = Path(self.translate_path(self.path)).read_bytes()
            self.send_response(200); self.send_header('Content-Type', 'application/octet-stream'); self.send_header('Content-Length', len(data)); self.end_headers()
            if 'index.pck.' in self.path:
                with lock: faults[self.path] = 'connection_closed'
                self.wfile.write(data[:8192]); self.wfile.flush(); self.connection.shutdown(socket.SHUT_RDWR); self.connection.close()
            else:
                with lock: faults[self.path] = 'corrupted_once'
                self.wfile.write(bytes([data[0] ^ 1]) + data[1:])
            return
        super().do_GET()
ThreadingHTTPServer(('127.0.0.1', 18764), Handler).serve_forever()
