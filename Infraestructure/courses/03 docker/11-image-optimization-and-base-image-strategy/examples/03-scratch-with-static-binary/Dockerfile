# syntax=docker/dockerfile:1

# ---- builder ----
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY main.go .
# CGO_ENABLED=0 forces a fully static binary (no dynamic linker, no libc).
# -ldflags "-s -w" strips the symbol table and DWARF info to shrink the binary.
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /out/app ./main.go

# ---- runtime: literally nothing ----
FROM scratch
COPY --from=builder /out/app /app
ENTRYPOINT ["/app"]
