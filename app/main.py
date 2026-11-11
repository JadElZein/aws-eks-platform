import socket
import time

from flask import Flask, Response, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

app = Flask(__name__)

REQUESTS = Counter("http_requests_total", "HTTP requests", ["route", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request duration in seconds", ["route"])

MAX_WORK_MS = 500


@app.before_request
def start_timer():
    g.start = time.perf_counter()


@app.after_request
def record(response):
    route = request.url_rule.rule if request.url_rule else "unmatched"
    if route != "/metrics" and hasattr(g, "start"):
        LATENCY.labels(route).observe(time.perf_counter() - g.start)
        REQUESTS.labels(route, response.status_code).inc()
    return response


@app.get("/")
def index():
    return jsonify(message="aws-eks-platform demo", hostname=socket.gethostname())


@app.get("/healthz")
def healthz():
    return "ok", 200


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)


@app.get("/work")
def work():
    try:
        ms = int(request.args.get("ms", "100"))
    except ValueError:
        return jsonify(error="ms must be an integer"), 400
    ms = max(0, min(ms, MAX_WORK_MS))
    end = time.perf_counter() + ms / 1000
    while time.perf_counter() < end:
        pass
    return jsonify(worked_ms=ms)
