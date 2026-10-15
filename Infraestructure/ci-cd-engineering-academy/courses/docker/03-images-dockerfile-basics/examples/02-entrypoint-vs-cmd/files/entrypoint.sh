#!/bin/sh
# Setup minimal (variables, migraciones, etc. si hiciera falta).
# exec reemplaza el shell: python toma PID 1 y recibe senales directamente.
exec python /app.py "$@"
