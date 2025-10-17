from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('content-length', 0))
        body = self.rfile.read(length)
        
        # Mock response
        response = {
            "id": "test-12345",
            "status": "received"
        }
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())
    
    def log_message(self, format, *args):
        pass  # Sessiz mod

if __name__ == '__main__':
    server = HTTPServer(('127.0.0.1', 8002), Handler)
    print('Mock submit server running on http://127.0.0.1:8002')
    server.serve_forever()
