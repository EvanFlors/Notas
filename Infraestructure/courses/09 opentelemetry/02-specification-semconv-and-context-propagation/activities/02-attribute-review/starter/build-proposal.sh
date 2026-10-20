#!/usr/bin/env bash
# Generate the attribute proposal that the student must review.
# Output: /tmp/otel-02-02-review/{proposal.md,review.md}
set -eu

OUT="${OUT_DIR:-/tmp/otel-02-02-review}"
rm -rf "$OUT"
mkdir -p "$OUT"

cat > "$OUT/proposal.md" <<'MD'
# Proposed attributes for `checkout-api`

The team wants to attach the following 15 attributes to every HTTP span
produced by `checkout-api`. Review and classify each one.

 1. service.name = "checkout-api"
 2. service.version = "2.1.0"
 3. deployment.environment = "production"
 4. k8s.pod.name = "checkout-api-7f9c-abc12"
 5. http.request.method = "POST"
 6. http.response.status_code = 200
 7. url.full = "https://api.acme.com/checkout?token=abc123"
 8. server.address = "api.acme.com"
 9. userEmail = "alice@example.com"
10. request_id = "r-9f3e8c1a-7b2d-4f0e-9c3b-8d4a1e2f3b4c"
11. acme.cart.item_count = 7
12. acme.cart.total_cents = 15499
13. password = "hunter2"
14. http.method = "POST"
15. timestampMs = 1734567890123
MD

cat > "$OUT/review.md" <<'MD'
# My attribute review

Format: `<name>: <RESOURCE|SEMCONV|CUSTOM_OK|REJECT> -- <reason>`

1. service.name: ...
2. service.version: ...
3. deployment.environment: ...
4. k8s.pod.name: ...
5. http.request.method: ...
6. http.response.status_code: ...
7. url.full: ...
8. server.address: ...
9. userEmail: ...
10. request_id: ...
11. acme.cart.item_count: ...
12. acme.cart.total_cents: ...
13. password: ...
14. http.method: ...
15. timestampMs: ...

## Final clean list

- ...
MD

echo "Proposal written to $OUT/proposal.md"
echo "Fill in your review at $OUT/review.md"
