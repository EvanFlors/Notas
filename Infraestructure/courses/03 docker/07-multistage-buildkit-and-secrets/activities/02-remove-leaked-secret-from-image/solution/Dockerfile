# syntax=docker/dockerfile:1
FROM alpine:3.20

WORKDIR /app
COPY fetch.sh ./

# Mount the secret ONLY for this RUN. It is not baked into the layer, is
# not visible in `docker history`, and `/run/secrets/github_token` does
# not exist in the final image.
RUN --mount=type=secret,id=github_token \
    TOKEN="$(cat /run/secrets/github_token)" \
 && ./fetch.sh "$TOKEN" > /app/receipt.txt

CMD ["sh", "-c", "cat /app/receipt.txt"]
