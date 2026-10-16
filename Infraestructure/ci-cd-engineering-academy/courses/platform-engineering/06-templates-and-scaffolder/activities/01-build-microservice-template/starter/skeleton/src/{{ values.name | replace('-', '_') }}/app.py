# TODO: use ${{ values.name }} as the FastAPI title
"""Entry point for TODO."""
from fastapi import FastAPI

app = FastAPI(title="TODO")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
