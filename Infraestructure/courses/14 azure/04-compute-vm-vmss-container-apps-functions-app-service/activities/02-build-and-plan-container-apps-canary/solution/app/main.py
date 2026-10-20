"""Minimal FastAPI app used as the sample workload for az-04-02."""
from fastapi import FastAPI
import os

app = FastAPI(title="checkout-api")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/version")
def version():
    return {"version": os.getenv("APP_VERSION", "v1")}
