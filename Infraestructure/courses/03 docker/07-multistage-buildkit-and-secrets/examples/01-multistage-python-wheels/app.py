"""Minimal Flask app used to demonstrate multi-stage builds."""
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/health")
def health():
    return jsonify(status="ok"), 200


@app.get("/")
def index():
    return jsonify(message="hello from multistage"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
