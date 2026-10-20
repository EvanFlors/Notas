"""Starter: FastAPI app without any OTel code.

Your task: wrap `apply_coupon` and `reserve_inventory` in manual spans using the
OTel API, then run the whole thing under `opentelemetry-instrument` so FastAPI
gets auto-instrumented and your manual spans nest under the SERVER span.
"""
from fastapi import FastAPI

app = FastAPI()


def apply_coupon(code: str) -> int:
    # TODO: wrap in a manual span "apply_coupon"
    #       and set an attribute "coupon.code".
    return 1500 if code == "WELCOME" else 0


def reserve_inventory(sku: str) -> bool:
    # TODO: wrap in a manual span "reserve_inventory"
    #       and set an attribute "inventory.sku".
    return sku.startswith("ABC-")


@app.get("/checkout")
def checkout(code: str = "WELCOME", sku: str = "ABC-1"):
    discount = apply_coupon(code)
    reserved = reserve_inventory(sku)
    return {"discount_cents": discount, "reserved": reserved}
