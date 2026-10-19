# Minimal FastAPI image to exercise build + push against a local registry.
FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir "fastapi==0.111.0" "uvicorn==0.30.1"

COPY app.py /app/app.py

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
