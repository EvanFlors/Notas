FROM alpine:3.20
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app
# Entrypoint script lives in the image; it strictly checks /output ownership
# and refuses to run if the directory is not owned by UID 1000. This mirrors
# how real services (e.g. Postgres) refuse to start on wrongly-owned pgdata,
# and keeps the lab reproducible across Linux and Docker Desktop (which may
# otherwise translate UIDs on bind mounts).
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
USER 1000
WORKDIR /output
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
