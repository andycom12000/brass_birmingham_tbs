#!/usr/bin/env python3
"""Local HTTP server for TTS asset development.
Run this, then load the TTS save file. Images will load from localhost.
Usage: python scripts/serve_assets.py [port]
Default port: 8080
"""
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ASSETS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")

os.chdir(ASSETS_DIR)
handler = http.server.SimpleHTTPRequestHandler
with http.server.HTTPServer(("", PORT), handler) as httpd:
    print(f"Serving assets from: {ASSETS_DIR}")
    print(f"URL: http://localhost:{PORT}/")
    print(f"Example: http://localhost:{PORT}/cards/location_Birmingham.png")
    print("Press Ctrl+C to stop")
    httpd.serve_forever()
