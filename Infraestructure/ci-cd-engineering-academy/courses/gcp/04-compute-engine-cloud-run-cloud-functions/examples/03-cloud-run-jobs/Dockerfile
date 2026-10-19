FROM python:3.12-slim-bookworm
WORKDIR /app
COPY job.py .
USER 10001
ENV BATCH_SIZE=10
CMD ["python", "job.py"]
