from flask import Flask

app = Flask(__name__)


@app.get("/health")
def health():
    return {"status": "ok"}, 200


@app.get("/")
def index():
    return {"message": "hello from cache-friendly python"}, 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
