# Starter — sec-09-01-sign-capstone-image

## Preparación

```bash
mkdir -p /tmp/sec-09-01-sign
cd /tmp/sec-09-01-sign
cp <ruta-repo>/courses/devsecops/09-signing-and-attestations-with-cosign-sigstore/activities/01-sign-capstone-image/starter/run.sh .
chmod +x run.sh
```

## Requisitos

- `docker` corriendo (para `registry:2` y el build).
- `cosign` ≥ 2.x en el `PATH`.

Si falta alguno, instala siguiendo:

- cosign: `https://docs.sigstore.dev/cosign/system_config/installation/`

## Ejecutar

```bash
bash run.sh
```

El script es idempotente: si `localhost:5000` ya tiene algo escuchando, lo reusa; si no, levanta un `registry:2` con nombre `sec09-registry`.

## Validar

```bash
bash <ruta-repo>/courses/devsecops/09-signing-and-attestations-with-cosign-sigstore/activities/01-sign-capstone-image/tests/validate.sh /tmp/sec-09-01-sign
```

## Entregable manual

Escribe `SIGN-LOG.md` (6–10 líneas) explicando con tus propias palabras:

- Qué garantiza esta firma key-based (integridad + autenticidad respecto a la pub key).
- Qué **no** garantiza (no-repudio sin un log tipo Rekor; no vincula a una identidad humana / de workflow).

## Limpieza

```bash
docker rm -f sec09-registry 2>/dev/null || true
rm -rf /tmp/sec-09-01-sign
```
