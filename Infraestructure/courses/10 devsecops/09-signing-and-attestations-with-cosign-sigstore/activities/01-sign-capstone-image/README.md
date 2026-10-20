# Actividad 01 — Firmar imagen del capstone (key-based, local)

> **Independiente.** Práctica ejecutable sin necesidad de OIDC real: usa el modelo **key-based** de cosign contra un `registry:2` local. El modelo keyless se practica en producción vía CI (ver `examples/01-cosign-sign-keyless/`).

## Objetivo

Reproducir el flujo "construir → push → firmar → verificar" **íntegro** en una laptop usando solo `docker` + `cosign` + `registry:2`, dejando un script reproducible que:

1. Levanta un `registry:2` local en `localhost:5000`.
2. Construye y empuja una imagen trivial.
3. Genera un par de claves cosign (sin passphrase, uso académico).
4. Firma la imagen por digest.
5. Verifica la firma con la pub key — debe pasar.
6. Verifica con una **clave distinta** — debe **fallar**.
7. (Opcional) Firma una attestation SBOM y la verifica por `--type`.

## Entregables

Un directorio de trabajo (por defecto `/tmp/sec-09-01-sign`) con:

- `run.sh` — script ejecutable que orquesta todo el flujo anterior y deja los artefactos.
- `cosign.pub` + `cosign.key` — par generado por el script.
- `wrong.pub` + `wrong.key` — segundo par para el test negativo.
- `IMAGE_DIGEST` — fichero de texto con el digest `sha256:...` de la imagen firmada.
- `SIGN-LOG.md` — nota breve (6–10 líneas) explicando **qué garantiza y qué no** la firma key-based que acabas de producir.

## Pasos

1. Lee `theory/lesson.md §2` (modelo con claves) y `theory/lesson.md §5` (anti-patrón de verificación insegura).
2. Prepara el directorio y los binarios:
   ```bash
   mkdir -p /tmp/sec-09-01-sign && cd /tmp/sec-09-01-sign
   # Requiere: docker, cosign.
   # Si falta alguno, el validador saldrá en SKIP controlado.
   ```
3. Copia o adapta el `run.sh` de `starter/` (hay una plantilla mínima).
4. Ejecuta `bash run.sh`.
5. Escribe `SIGN-LOG.md` con tus propias palabras.
6. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/09-signing-and-attestations-with-cosign-sigstore/activities/01-sign-capstone-image/tests/validate.sh /tmp/sec-09-01-sign
   ```
7. Compara con `solution/REFERENCE.md`.

## Notas de alcance

- **No se publica nada fuera de tu máquina.** El `registry:2` es local y efímero.
- **No se usan secretos reales**. El cosign key.pass es `''` (passphrase vacía) y las claves se autogeneran en `/tmp`.
- Si no tienes `docker` o `cosign`, el validador **omite** las comprobaciones que los requieren y deja aviso.

## Advertencia

El modelo key-based que practicas aquí es útil para **aprender la mecánica** y para entornos sin OIDC. En producción, prefiere **keyless** (ver ejemplo 01 y lección §3).
