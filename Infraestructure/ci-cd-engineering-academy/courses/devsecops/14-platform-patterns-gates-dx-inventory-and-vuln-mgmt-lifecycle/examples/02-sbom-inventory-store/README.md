# Ejemplo 02 — SBOM inventory store (CMDB-lite)

> Lectura y análisis. No se ejecuta (no se levanta base de datos).

Un **SBOM store** convierte la pregunta "¿quién corre log4j 2.14?" en una query.

Este ejemplo documenta:

- Un **schema SQL mínimo** (3 tablas) suficiente para responder las 6 preguntas canónicas.
- Las **6 queries canónicas** que deberían resolverse en milisegundos.
- La **integración CI → store** vía un endpoint HTTP (o directo a Postgres).
- Alternativas industriales: **OWASP Dependency-Track** y **GUAC**.

Ver `REFERENCE.md` para el detalle.

## Qué pregunta responde cada herramienta

| Pregunta                                      | Herramienta sugerida            |
|-----------------------------------------------|---------------------------------|
| ¿Qué servicios usan `openssl 3.0.x`?          | SQL directo o Dependency-Track  |
| ¿Qué CVEs afectan a `payments-api` hoy?       | Dependency-Track (join con NVD) |
| ¿Qué servicio fue firmado por qué identity?   | GUAC (grafo SBOM+provenance+sig)|
| ¿Qué paquetes nuevos aparecen esta semana?    | diff `last_seen` en el store    |

## No incluye

- Despliegue real de Dependency-Track (fuera del scope conceptual).
- Fetch de NVD/EPSS/KEV (asumido como data externa periódica).
