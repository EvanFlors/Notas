# syntax=docker/dockerfile:1
# Intentionally bloated image to inspect with dive.
FROM python:3.12-slim
WORKDIR /app
# Anti-pattern: pip cache is kept, THEN deleted in a later layer.
# The deletion is a whiteout in overlayfs; original bytes still ship.
COPY requirements.txt .
RUN pip install -r requirements.txt
RUN rm -rf /root/.cache/pip
COPY app.py .
CMD ["python", "app.py"]
