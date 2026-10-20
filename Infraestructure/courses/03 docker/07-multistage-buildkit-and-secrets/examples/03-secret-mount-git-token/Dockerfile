# syntax=docker/dockerfile:1
FROM alpine:3.20

# No real network/git clone here — we only need to prove the secret is
# available during the RUN and absent from the resulting image.
RUN --mount=type=secret,id=github_token \
    TOKEN="$(cat /run/secrets/github_token)" \
 && echo "token-length-at-build-time:${#TOKEN}" > /tmp/receipt \
 && echo "last4:$(printf '%s' "$TOKEN" | tail -c 4)" >> /tmp/receipt \
 && cp /tmp/receipt /receipt \
 && rm -f /tmp/receipt
# Note: /receipt stores ONLY the length and last 4 chars — never the full
# token. The real secret is never written to the filesystem of the image.

CMD ["cat", "/receipt"]
