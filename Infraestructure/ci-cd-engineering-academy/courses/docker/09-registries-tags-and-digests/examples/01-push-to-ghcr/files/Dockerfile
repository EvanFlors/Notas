# Imagen trivial para el ejemplo dkr-09/01.
# No tiene objetivo funcional mas alla de producir un manifest reconocible
# que podamos pushear a un registry y pulllear por tag/digest.
FROM alpine:3.20

LABEL org.opencontainers.image.title="dkr09-demo"
LABEL org.opencontainers.image.description="Demo image for dkr-09 registries lesson"
LABEL org.opencontainers.image.source="https://example.invalid/dkr-09"

COPY app.sh /app.sh
RUN chmod +x /app.sh

ENTRYPOINT ["/app.sh"]
