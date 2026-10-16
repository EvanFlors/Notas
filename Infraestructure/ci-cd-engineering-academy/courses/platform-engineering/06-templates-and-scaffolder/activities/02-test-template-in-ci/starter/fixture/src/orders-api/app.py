"""Entry point for orders-api."""
from fastapi import FastAPI

app = FastAPI(title="orders-api")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
