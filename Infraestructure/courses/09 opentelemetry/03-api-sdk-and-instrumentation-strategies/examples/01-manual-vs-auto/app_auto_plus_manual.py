"""Variant B: FastAPI endpoint with auto-instrumentation plus a manual span.

Run with:
    opentelemetry-instrument --traces_exporter=console \
        --service_name=demo-manual uvicorn app_auto_plus_manual:app --port 8002
"""
from fastapi import FastAPI
from opentelemetry import trace

tracer = trace.get_tracer("checkout.domain")

app = FastAPI()


def apply_coupon(code: str) -> int:
    with tracer.start_as_current_span("apply_coupon") as span:
        span.set_attribute("coupon.code", code)
        discount = 1500 if code == "WELCOME" else 0
        span.set_attribute("coupon.discount_cents", discount)
        return discount


@app.get("/checkout")
def checkout(code: str = "WELCOME"):
    return {"discount_cents": apply_coupon(code)}
