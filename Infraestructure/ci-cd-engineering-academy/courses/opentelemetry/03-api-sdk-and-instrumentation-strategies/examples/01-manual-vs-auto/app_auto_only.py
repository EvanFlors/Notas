"""Variant A: FastAPI endpoint with auto-instrumentation only.

Run with:
    opentelemetry-instrument --traces_exporter=console \
        --service_name=demo-auto uvicorn app_auto_only:app --port 8001
"""
from fastapi import FastAPI

app = FastAPI()


def apply_coupon(code: str) -> int:
    return 1500 if code == "WELCOME" else 0


@app.get("/checkout")
def checkout(code: str = "WELCOME"):
    discount = apply_coupon(code)
    return {"discount_cents": discount}
