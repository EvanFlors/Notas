# syntax=docker/dockerfile:1
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
# COPY . . copia TODO lo que no este en .dockerignore
COPY . .
CMD ["python", "app.py"]
