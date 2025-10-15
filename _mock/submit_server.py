from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('content-length', 0))
        body = self.rfile.read(length)
        response = {"id": "test-12345", "status": "received"}
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())
    def log_message(self, format, *args): pass

print('Mock submit server: http://127.0.0.1:8002')
HTTPServer(('127.0.0.1', 8002), Handler).serve_forever()
