"""Starter FastAPI app para el ejercicio operativo de certificación OpenTelemetry.

Objetivo: el candidato debe completar los `TODO` para emitir un span manual
`checkout.compute_total` con atributos de dominio, un evento `discount_applied`
y status/exception cuando corresponda. NO instanciar un TracerProvider aquí:
`opentelemetry-instrument` lo configura por nosotros al envolver uvicorn.
"""
from __future__ import annotations

from fastapi import FastAPI, HTTPException

# TODO: importar lo necesario de opentelemetry (trace, Status, StatusCode)

app = FastAPI()

# TODO: obtener tracer con el nombre del módulo
# tracer = ...

PRICE_PER_ITEM = 29.90


@app.get("/checkout/{order_id}")
def checkout(order_id: str, items: int = 1, payment: str = "card") -> dict:
    """Simula el cálculo de un checkout.

    - Debe crear un span manual hijo llamado `checkout.compute_total`.
    - Atributos obligatorios: `order.id`, `order.item_count`, `payment.method`.
    - Si `total > 100`, añadir evento `discount_applied` con atributo `discount.pct=10`.
    - Si `order_id == "fail"`, lanzar HTTPException(500) y antes:
        * span.record_exception(e)
        * span.set_status(Status(StatusCode.ERROR, "forced failure"))
    - NUNCA añadir `user.email` como atributo (el Collector lo filtra; pero
      emitirlo es considerado red flag para esta prueba).
    """
    # TODO: abrir span manual con start_as_current_span
    #       y rellenar los atributos.
    total = items * PRICE_PER_ITEM

    if order_id == "fail":
        # TODO: record_exception + set_status ERROR, luego raise
        raise HTTPException(status_code=500, detail="forced failure")

    if total > 100:
        # TODO: span.add_event("discount_applied", {"discount.pct": 10})
        total = total * 0.9

    return {"order_id": order_id, "total": round(total, 2), "payment": payment}
