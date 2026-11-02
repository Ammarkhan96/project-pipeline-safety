import os
import random
from flask import Flask, jsonify, Response

app = Flask(__name__)

VERSION = os.getenv("APP_VERSION", "v1")
DEGRADED = os.getenv("DEGRADED", "false").lower() == "true"
FAILURE_RATE = float(os.getenv("FAILURE_RATE", "0.20"))

REQUESTS_TOTAL = {"200": 0, "500": 0}


@app.get("/")
def home():
    return jsonify(
        application="pipeline-safety-demo",
        version=VERSION,
        degraded=DEGRADED,
    )


@app.get("/health")
def health():
    return jsonify(status="healthy", version=VERSION), 200


@app.get("/ready")
def ready():
    return jsonify(status="ready", version=VERSION), 200


@app.get("/api")
def api():
    if DEGRADED and random.random() < FAILURE_RATE:
        REQUESTS_TOTAL["500"] += 1
        return jsonify(
            status="error",
            version=VERSION,
            message="simulated failure",
        ), 500

    REQUESTS_TOTAL["200"] += 1
    return jsonify(status="ok", version=VERSION), 200


@app.get("/metrics")
def metrics():
    body = (
        "# HELP demo_http_requests_total Total demo HTTP requests.\n"
        "# TYPE demo_http_requests_total counter\n"
        f'demo_http_requests_total{{version="{VERSION}",code="200"}} '
        f'{REQUESTS_TOTAL["200"]}\n'
        f'demo_http_requests_total{{version="{VERSION}",code="500"}} '
        f'{REQUESTS_TOTAL["500"]}\n'
    )
    return Response(body, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
