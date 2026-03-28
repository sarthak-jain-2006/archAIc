"""
Payment Service — archAIc Layer 1
Port: 8004
"""

import os
import time
import json
import logging
import asyncio
import uuid
import random
import threading
from datetime import datetime, timezone
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException, Header, Query, Request
import stripe

# ─── Observability ────────────────────────────────────────────────────────────
from prometheus_fastapi_instrumentator import Instrumentator
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor


# ─── Logger ───────────────────────────────────────────────────────────────────

class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return json.dumps({
            "service": "payment-service",
            "level": record.levelname,
            "message": record.getMessage(),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "trace_id": getattr(record, "trace_id", "N/A"),
        })


handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger = logging.getLogger("payment-service")
logger.addHandler(handler)
logger.setLevel(logging.INFO)
logger.propagate = False


def _log(level: str, message: str, trace_id: str = "N/A"):
    getattr(logger, level.lower())(message, extra={"trace_id": trace_id})


# ─── App ──────────────────────────────────────────────────────────────────────

app = FastAPI(title="Payment Service")

# ─── Observability Setup ──────────────────────────────────────────────────────
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "").rstrip("/")
resource = Resource(attributes={"service.name": "payment-service"})
provider = TracerProvider(resource=resource)

if OTEL_ENDPOINT:
    processor = BatchSpanProcessor(
        OTLPSpanExporter(endpoint=f"{OTEL_ENDPOINT}/v1/traces")
    )
    provider.add_span_processor(processor)

trace.set_tracer_provider(provider)

FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()
Instrumentator().instrument(app).expose(app)

# ─── Config ───────────────────────────────────────────────────────────────────

AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8001")
DB_SERVICE_URL   = os.getenv("DB_SERVICE_URL",   "http://db-service:8002")
REQUEST_TIMEOUT  = float(os.getenv("REQUEST_TIMEOUT", "5"))

stripe.api_key = os.getenv("STRIPE_API_KEY", "sk_test_dummy")

failure_config = {
    "enabled": False,
    "type": None,
    "intensity": 1,
    "probability": 1.0,
    "duration": None,
}
failure_start_time = None


# ─── Failure Injection ────────────────────────────────────────────────────────

async def _apply_failure(trace_id: str):
    global failure_start_time

    if not failure_config["enabled"]:
        return

    if failure_config["duration"]:
        if not failure_start_time:
            failure_start_time = time.time()
        elif time.time() - failure_start_time > failure_config["duration"]:
            failure_config["enabled"] = False
            return

    if random.random() > failure_config["probability"]:
        return

    ftype = failure_config["type"]

    if ftype == "timeout":
        await asyncio.sleep(2)
    elif ftype == "error":
        raise HTTPException(500, "Simulated failure")
    elif ftype == "cpu":
        threading.Thread(target=lambda: sum(range(10**7)), daemon=True).start()
    elif ftype == "crash":
        os._exit(1)


# ─── Middleware ───────────────────────────────────────────────────────────────

@app.middleware("http")
async def trace_middleware(request: Request, call_next):
    trace_id = request.headers.get("X-Trace-ID", str(uuid.uuid4()))
    request.state.trace_id = trace_id

    start = time.time()
    response = await call_next(request)

    latency = round((time.time() - start) * 1000, 2)
    response.headers["X-Trace-ID"] = trace_id

    _log("info", f"{request.method} {request.url.path} → {response.status_code} [{latency}ms]", trace_id)

    return response


# ─── Helpers ──────────────────────────────────────────────────────────────────

async def _validate_token(auth: str, trace_id: str):
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            res = await client.get(
                f"{AUTH_SERVICE_URL}/validate",
                headers={"Authorization": auth, "X-Trace-ID": trace_id},
            )

        if res.status_code != 200:
            raise HTTPException(401, "Unauthorized")

        return res.json().get("email")

    except httpx.TimeoutException:
        raise HTTPException(504, "Auth timeout")
    except httpx.RequestError:
        raise HTTPException(503, "Auth unreachable")


async def _db_get_cart(user_id: str, trace_id: str):
    try:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            res = await client.get(
                f"{DB_SERVICE_URL}/cart/{user_id}",
                headers={"X-Trace-ID": trace_id},
            )

        if res.status_code != 200:
            raise HTTPException(502, "DB error")

        return res.json()

    except httpx.TimeoutException:
        raise HTTPException(504, "DB timeout")
    except httpx.RequestError:
        raise HTTPException(503, "DB unreachable")


def _extract_total(cart: dict):
    """Robust total extraction"""
    total = (
        cart.get("total")
        or cart.get("total_price")
        or cart.get("amount")
        or 0
    )

    if not total and "items" in cart:
        total = sum(float(i.get("price", 0)) for i in cart.get("items", []))

    try:
        return float(total)
    except:
        return 0.0


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.post("/create-checkout-session")
async def create_checkout_session(request: Request, authorization: str = Header(...)):
    trace_id = request.state.trace_id
    await _apply_failure(trace_id)

    _log("info", "Checkout started", trace_id)

    email = await _validate_token(authorization, trace_id)
    user_id = email  # safer than splitting

    cart = await _db_get_cart(user_id, trace_id)

    _log("info", f"Cart response: {cart}", trace_id)

    total = _extract_total(cart)

    if total <= 0:
        raise HTTPException(400, "Cart is empty")

    # ─── MOCK MODE ─────────────────────────────────────
    if not stripe.api_key or stripe.api_key == "sk_test_dummy":
        return {
            "checkout_url": f"https://mock.stripe.com/{uuid.uuid4()}",
            "amount": total,
            "trace_id": trace_id,
        }

    # ─── REAL STRIPE ───────────────────────────────────
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "usd",
                    "product_data": {"name": "archAIc Checkout"},
                    "unit_amount": int(total * 100),
                },
                "quantity": 1,
            }],
            mode="payment",
            success_url="http://localhost:8004/success",
            cancel_url="http://localhost:8004/cancel",
        )

        return {"checkout_url": session.url, "trace_id": trace_id}

    except Exception as e:
        _log("error", f"Stripe error: {e}", trace_id)
        raise HTTPException(500, "Stripe failure")


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "service": "payment-service",
        "failure": failure_config.get("type"),
    }


# ─── Failure Control ──────────────────────────────────────────────────────────

@app.post("/inject-failure")
async def inject_failure(type: str = Query(...)):
    failure_config["enabled"] = True
    failure_config["type"] = type
    return {"status": "failure injected"}


@app.post("/reset")
async def reset():
    failure_config["enabled"] = False
    failure_config["type"] = None
    return {"status": "reset"}