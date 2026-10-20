from fastapi import FastAPI
import os

app = FastAPI(title="fastapi-mini")


@app.get("/")
def root():
    return {"service": "fastapi-mini", "pid": os.getpid(), "uid": os.getuid()}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
