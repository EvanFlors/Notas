"""Capstone starter — a tiny checkout service without ANY OTel setup.

TODO (student):
  1. Configure a TracerProvider with a Resource (service.name=capstone-checkout, …),
     a BatchSpanProcessor, and an exporter:
        - ConsoleSpanExporter by default,
        - OTLPSpanExporter if OTEL_EXPORTER_OTLP_ENDPOINT is set.
     Call provider.shutdown() on FastAPI shutdown.

  2. Get a tracer: tracer = trace.get_tracer(__name__)

  3. Wrap the POST /checkout handler in a span named "checkout.process".
     Add attributes: checkout.cart_id, checkout.total_cents, enduser.id.

  4. Wrap reserve_inventory() in a span "inventory.reserve" with
     inventory.cart_id, inventory.items.count.

  5. Wrap charge_payment() in a span "payment.charge" with
     payment.user_id, payment.amount_cents, payment.method.
     If amount_cents > 100_000: raise ValueError("amount above limit").
     Before raising: span.record_exception(exc) + span.set_status(ERROR).

Run (after instrumenting):
    python3 -m uvicorn app:app --port 8791
"""

from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="capstone-checkout")


class CheckoutIn(BaseModel):
    cart_id: str
    user_id: str
    items_count: int
    total_cents: int


def reserve_inventory(cart_id: str, items_count: int) -> None:
    # TODO: wrap in a span "inventory.reserve".
    if items_count <= 0:
        raise HTTPException(status_code=400, detail="items_count must be > 0")


def charge_payment(user_id: str, amount_cents: int) -> str:
    # TODO: wrap in a span "payment.charge".
    # TODO: if amount_cents > 100_000 -> ValueError + record_exception + set_status(ERROR).
    if amount_cents > 100_000:
        raise ValueError("amount above limit")
    return f"pay_{user_id}_{amount_cents}"


@app.get("/health")
def health():
    return {"ok": True}


@app.post("/checkout")
def checkout(req: CheckoutIn):
    # TODO: wrap this handler body in a span "checkout.process".
    try:
        reserve_inventory(req.cart_id, req.items_count)
        payment_id = charge_payment(req.user_id, req.total_cents)
        return {"ok": True, "payment_id": payment_id}
    except ValueError as exc:
        raise HTTPException(status_code=402, detail=str(exc))
