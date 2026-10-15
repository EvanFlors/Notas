# syntax=docker/dockerfile:1
FROM alpine:3.20

# Scenario A: COPY — plain source, no special behavior needed.
# "Prefer COPY over ADD" (official guidance): COPY does one thing clearly.
COPY src/ /app/

# Scenario B: ADD — legitimate use of ADD's auto-extraction of a LOCAL tar.
# Avoids an extra RUN tar + rm, keeps intent explicit.
RUN mkdir -p /opt/assets
ADD dist/app-dist.tar.gz /opt/assets/

# Scenario C: NOT ADD <url>. We stage the file with COPY and verify its sha256
# in a RUN. In production the equivalent is `RUN curl -fsSL <url> -o /opt/payload`
# followed by the same checksum check. ADD <url> is avoided because it does not
# verify checksum by default and caches poorly.
COPY assets/remote-sample.txt /opt/payload
COPY assets/checksum.txt /tmp/checksum.txt
RUN cd / \
 && sha256sum -c /tmp/checksum.txt \
 && rm /tmp/checksum.txt

CMD ["cat", "/opt/payload"]
