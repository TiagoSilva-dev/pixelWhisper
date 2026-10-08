#!/usr/bin/env python3
"""Offline stand-in for the PixelLab v2 API, so the game's AI flow can be developed and
tested without spending generations.

    python3 tools/mock_pixellab_server.py                 # happy path on :8787
    python3 tools/mock_pixellab_server.py --mode 402      # "out of credits"
    PIXELLAB_BASE_URL=http://127.0.0.1:8787/v2 godot --path .

Implements the subset the game uses, with the same shapes as the real OpenAPI spec:
  POST   /v2/create-image-pixflux-background -> 202 {"background_job_id", "status"}
  GET    /v2/background-jobs/{id}            -> processing x N, then completed with
                                               last_response.image.base64 (a real 64x64 PNG)
  DELETE /v2/background-jobs/{id}            -> 200
Modes: ok | 401 | 402 | 429 | fail (job ends "failed") | slow (never completes)
"""
import argparse
import base64
import glob
import json
import os
import random
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LEVELS = sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "levels", "*.png")))
JOBS = {}  # id -> {"polls": int, "png": bytes}
ARGS = None


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=None):
        raw = json.dumps(body or {}).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        # CORS, so a browser (Web export) build can talk to the mock too.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS")
        self.end_headers()
        self.wfile.write(raw)

    def do_OPTIONS(self):
        self._send(204)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        if self.path.endswith("/create-image-pixflux-background"):
            if ARGS.mode in ("401", "402", "429"):
                return self._send(int(ARGS.mode), {"detail": f"mock {ARGS.mode}"})
            if not body.get("description") or "image_size" not in body:
                return self._send(422, {"detail": "description and image_size are required"})
            job = f"mock-{len(JOBS) + 1}"
            png = open(random.choice(LEVELS), "rb").read()
            JOBS[job] = {"polls": 0, "png": png, "prompt": body["description"]}
            print(f"  job {job}: {body['description']!r} size={body['image_size']}")
            return self._send(202, {"background_job_id": job, "status": "processing"})
        self._send(404, {"detail": "not found"})

    def do_GET(self):
        m = re.search(r"/background-jobs/([\w-]+)$", self.path)
        if not m or m.group(1) not in JOBS:
            return self._send(404, {"detail": "Job not found"})
        job = JOBS[m.group(1)]
        job["polls"] += 1
        if ARGS.mode == "slow" or job["polls"] <= ARGS.processing_polls:
            return self._send(200, {"id": m.group(1), "status": "processing", "created_at": "now",
                                    "last_response": {"queue_position": 0, "estimated_wait_seconds": 5}})
        if ARGS.mode == "fail":
            return self._send(200, {"id": m.group(1), "status": "failed", "created_at": "now",
                                    "last_response": {"error": "mock failure"}})
        b64 = base64.b64encode(job["png"]).decode()
        self._send(200, {"id": m.group(1), "status": "completed", "created_at": "now",
                         "last_response": {"image": {"type": "base64", "base64": b64, "format": "png"}}})

    def do_DELETE(self):
        self._send(200, {"cancelled": True})

    def log_message(self, fmt, *a):
        print("  " + fmt % a)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--mode", default="ok", choices=["ok", "401", "402", "429", "fail", "slow"])
    ap.add_argument("--processing-polls", type=int, default=2, help="polls that answer 'processing' before completing")
    ARGS = ap.parse_args()
    print(f"mock PixelLab on http://127.0.0.1:{ARGS.port}/v2  mode={ARGS.mode}")
    ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler).serve_forever()
