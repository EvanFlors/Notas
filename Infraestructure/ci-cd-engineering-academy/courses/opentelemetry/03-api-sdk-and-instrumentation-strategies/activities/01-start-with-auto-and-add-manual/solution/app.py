"""Solution for otel-03-01.

Run with:
    opentelemetry-instrument --traces_exporter=console \
        --service_name=lab-otel-03 \
        uvicorn app:app --host 127.0.0.1 --port 8765
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


def reserve_inventory(sku: str) -> bool:
    with tracer.start_as_current_span("reserve_inventory") as span:
        span.set_attribute("inventory.sku", sku)
        reserved = sku.startswith("ABC-")
        span.set_attribute("inventory.reserved", reserved)
        return reserved


@app.get("/checkout")
def checkout(code: str = "WELCOME", sku: str = "ABC-1"):
    discount = apply_coupon(code)
    reserved = reserve_inventory(sku)
    return {"discount_cents": discount, "reserved": reserved}
