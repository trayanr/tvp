import argparse
import gzip
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import ssl

parser = argparse.ArgumentParser()
parser.add_argument('--port-file', required=True)
parser.add_argument('--zstd')
parser.add_argument('--certificate')
parser.add_argument('--key')
args = parser.parse_args()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'42'
        encoding = None
        if self.path == '/gzip':
            body = gzip.compress(body)
            encoding = 'gzip'
        elif self.path == '/zstd':
            body = Path(args.zstd).read_bytes()
            encoding = 'zstd'
        self.send_response(200)
        if encoding:
            self.send_header('Content-Encoding', encoding)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

server = HTTPServer(('127.0.0.1', 0), Handler)
if args.certificate:
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(args.certificate, args.key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
Path(args.port_file).write_text(str(server.server_port))
server.serve_forever()
