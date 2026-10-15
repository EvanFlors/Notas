package main

# INSTRUCCIONES
# -------------
# 1. Implementa `deny[msg]` para prohibir aws_s3_bucket_acl con acl publica.
#    Lista prohibida sugerida: {"public-read", "public-read-write"}.
#
# 2. Implementa un segundo `deny[msg]` que asegure que todo aws_s3_bucket
#    tiene un aws_s3_bucket_public_access_block que lo referencia por nombre.
#
# Cuando funcione, deberia:
#   - PASS sobre tests/fixtures/plan-good.json (bucket privado + BPA)
#   - FAIL sobre tests/fixtures/plan-bad.json  (bucket public-read, sin BPA)
#
# Palabras clave que el validador espera encontrar en este archivo:
#   - "public-read"
#   - "aws_s3_bucket_public_access_block"

# TODO: regla 1 — ACL publico
# deny[msg] { ... }

# TODO: regla 2 — bucket sin BPA
# deny[msg] { ... }
