# REFERENCE — sec-05-02-reduce-cves-by-base-swap

> Referencia razonada. Los números concretos dependen de la versión de la Trivy DB el día que corras.

## Dockerfiles de referencia

Idénticos a los del README.md principal; la variante clave es la base:

```
v1 → python:3.12                                 (Debian "full")
v2 → python:3.12-slim                            (Debian slim)
v3 → cgr.dev/chainguard/python:latest            (distroless + hardened)
```

## Resultado típico (orden de magnitud)

Para una app Python trivial sin dependencias, en octubre 2026:

| Variante | Base image                              | CRITICAL | HIGH | MEDIUM |
|----------|-----------------------------------------|----------|------|--------|
| v1       | python:3.12                             |   3–8    | 25–50 | 60–120 |
| v2       | python:3.12-slim                        |   1–4    |  8–20 | 15–40  |
| v3       | cgr.dev/chainguard/python:latest        |     0    |   0–1 |  0–3   |

Reducción `CRITICAL+HIGH` v1 → v3 típicamente **>= 90 %**.

Los números varían con la fecha (NVD publica a diario) y con la versión de Trivy DB. Lo importante es que el **orden** se preserve: v1 ≫ v2 ≫ v3.

## COUNTS.md de referencia (con números hipotéticos)

```markdown
# COUNTS.md — CVEs por variante de base image

| Variante | Base image                              | CRITICAL | HIGH | MEDIUM |
|----------|-----------------------------------------|----------|------|--------|
| v1       | python:3.12                             |     5    |  38  |   87   |
| v2       | python:3.12-slim                        |     2    |  14  |   24   |
| v3       | cgr.dev/chainguard/python:latest        |     0    |   0  |    1   |

**Reduccion v1 -> v3 (CRITICAL+HIGH):** 100 %  ((5+38 - 0+0) / 43 * 100)
**Fecha de medicion:** 2026-10-16
**DB Trivy version:** v15 (consultar log del scan)
```

## ADR.md de referencia (abreviado)

Ver `../README.md` §5.7 — la referencia está integrada ahí. Puntos no negociables:

- **Estado** y **fecha**.
- **Contexto**: tiene que citar el conteo real (no "muchas").
- **Decision**: la acción concreta y su temporalidad (sprints, fases).
- **Alternativas**: al menos 2, con razón del descarte.
- **Consecuencias / Positivas y Negativas**: lo "negativo" obligado es la pérdida de shell en distroless/chainguard y cómo lo mitigas (imagen `-dev` o `-debug` tag para troubleshooting).
- **Metricas de exito**: criterios medibles ("reducción >= 70 %", "CI verde", "monitoreo 2 semanas sin regresión").

## Puntos a repetir hasta aburrir

1. **La reducción de CVEs más grande que puedes lograr no viene de parchar — viene de cambiar a una base image más fina.** Mismo código, menos capa.
2. **slim es la ganancia barata** (10 min de PR, compatible con todo). **chainguard/distroless es la ganancia máxima** (requiere pensar en debug tooling aparte).
3. **"No hay shell en prod"** es una **feature**, no un bug: elimina una ruta de post-exploitation común. El debug se hace con una imagen `-dev` paralela o con `kubectl debug` sidecar.
4. **Un ADR sin números es un deseo**. Mide antes y después; el número justifica la decisión en el próximo review.
5. **Chainguard "latest" es rolling** → pinea por **digest** para producción, revisa el drift con cadencia definida.
