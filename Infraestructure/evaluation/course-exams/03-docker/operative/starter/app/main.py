from fastapi import FastAPI

app = FastAPI(title="pricing-api")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/price/{sku}")
def price(sku: str) -> dict[str, float | str]:
    # Dummy pricing: deterministic hash → price.
    base = sum(ord(c) for c in sku) % 1000
    return {"sku": sku, "price": round(base + 0.99, 2)}
