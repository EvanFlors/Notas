# Measurements — reference run (your numbers will differ)

Host: macOS 14, Docker Desktop 4.33, red doméstica ~100 Mbps.
App: `starter/app.py` + `cryptography==43.0.1`.

| base                                       | size (MB) | cold-start (s) | CVEs C / H (trivy) | shell | build time (first) |
|--------------------------------------------|-----------|----------------|--------------------|-------|--------------------|
| python:3.12-slim                           | 193       | 2.4            | 1 / 6              | yes   | 22 s               |
| python:3.12-alpine (compile cryptography)  | 128       | 2.3            | 0 / 2              | yes   | 4 min 50 s         |
| distroless/python3-debian12 (multi-stage)  | 87        | 2.1            | 0 / 0              | no    | 25 s               |
| cgr.dev/chainguard/python (multi-stage)    | 94        | 2.1            | 0 / 0              | no    | 30 s               |

Notes:
- Cold-start measured with `time docker run --rm <tag> python -c 'print(1)'` after `docker rmi` + `docker image prune -f`.
- Sizes from `docker image inspect <tag> --format '{{.Size}}'` divided by 1024*1024.
- CVE counts from `trivy image --severity CRITICAL,HIGH --format json`.
