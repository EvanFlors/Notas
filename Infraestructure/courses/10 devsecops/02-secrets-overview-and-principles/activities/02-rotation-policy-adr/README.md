# Actividad 02 — ADR de política de rotación de secretos

## 1. Identificación

- **ID:** `sec-02-02-rotation-policy-adr`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-02-secrets-overview-and-principles`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Las políticas "rotamos cada 90 días todo" **no sobreviven** al contacto con la realidad. Diferentes familias de secretos tienen diferentes mecanismos de rotación, diferentes costes y diferentes consecuencias si se saltan. Un **ADR** (Architecture Decision Record) es la herramienta mínima para que esa política quede escrita, revisada y refutable.

Este ejercicio es escribir ese ADR para el modelo del capstone (o el proyecto que tengas en marcha). No es largo — un ADR bueno cabe en 2–4 páginas — pero debe cubrir todas las aristas: TTL por familia, mecanismo de rotación por familia, proceso de break-glass con SoD, y una sección de **consecuencias** honesta (coste operativo que estás asumiendo).

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dar un **TTL razonable y defendible** por cada familia de secreto.
- Elegir el **mecanismo de rotación** adecuado a cada familia (TTL expiration, dual-write, blue-green, reemplazo atómico, manual con runbook).
- Describir un proceso de **break-glass** que respete separation of duties.
- Enumerar **alternativas consideradas** y por qué las descartas.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md`, especialmente §5, §6, §9, §10, §11.
- Haber recorrido los dos `examples/` del módulo.
- Haber completado `sec-01`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-02-adr
cd /tmp/sec-02-adr
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador:
`bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-rotation.md` con la estructura canónica de un ADR

El documento debe tener **al menos** estas seis secciones (los títulos son los que busca el validador):

#### Status

Una línea: `Status: Proposed` | `Status: Accepted` | `Status: Draft`.

#### Context

5–10 líneas explicando el proyecto, los sistemas externos relevantes y por qué se necesita esta política ahora.

#### Decision

Núcleo del ADR. **Dos sub-secciones obligatorias**:

**(a) Tabla de TTL por familia** (≥5 filas, una por familia relevante):

```
| familia      | TTL objetivo | mecanismo de rotacion     | detectability | owner      |
|--------------|--------------|---------------------------|---------------|------------|
| api-key      | 90d          | reemplazo atomico         | medio         | platform   |
| db-cred      | 1h           | TTL expiration (dynamic)  | alto          | data       |
| oauth-access | 15m          | TTL expiration            | alto          | platform   |
| oauth-refresh| 30d          | reemplazo atomico         | medio         | platform   |
| cert         | 60d          | ACME auto-renew           | alto          | platform   |
| ssh          | 24h          | SSH CA + short cert       | medio         | platform   |
| signing      | 10m          | sigstore keyless          | alto          | security   |
| encryption   | 1a           | dual-write + versioning   | n/a           | data       |
```

**(b) Proceso de break-glass**: 5–10 líneas con roles distintos (quien aprueba ≠ quien ejecuta), TTL cortísimo (minutos), rotación post-uso obligatoria, revisión posterior obligatoria. Debe mencionar `break-glass`, `separation of duties` (o `SoD`), y `audit`.

#### Consequences

5–10 líneas honestas con **lo que estás pagando** por la decisión: coste operativo, complejidad para el equipo, riesgos residuales. Un ADR sin consequences realistas es un wish list.

#### Alternatives considered

Al menos **tres** alternativas que descartaste, con 1–2 líneas por qué:

- `Alternativa A: rotar todo cada 90 días` → por qué no.
- `Alternativa B: no rotar nada, confiar en scanning` → por qué no.
- `Alternativa C: ...` (algo propio) → por qué no.

#### References

Enlaces a la lección, al ejemplo 02, a docs oficiales (NIST SP 800-57, OWASP Secrets Management Cheat Sheet, docs de Vault/AWS/GCP).

### 5.3 Entregable

Un archivo:

```
/tmp/sec-02-adr/ADR-rotation.md
```

con las seis secciones anteriores.

## 6. Resultado esperado

- `ADR-rotation.md` existe.
- Las seis secciones existen con sus títulos canónicos.
- Tabla de TTL con ≥5 filas y las columnas requeridas.
- Proceso de break-glass con `separation of duties`.
- ≥3 alternativas consideradas y descartadas.
- `bash tests/validate.sh /tmp/sec-02-adr` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada TTL está defendido por el blast radius de la familia, no "porque sí".
- **Reproducibilidad**: alguien que lea tu ADR puede implementar los runbooks de rotación.
- **Mantenibilidad**: Markdown válido, tabla legible, enlaces estables.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-02-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho.

## 9. Preguntas de reflexión

1. ¿Qué familia tiene el TTL **más corto** en tu tabla? ¿Es porque el mecanismo es gratis (TTL expiration) o porque el blast radius lo exige?
2. ¿Qué familia tiene el TTL **más largo**? ¿Qué pasa si la rotación se salta un ciclo?
3. ¿Qué pasa si el servicio del secret manager está caído durante 2 horas? ¿Tu break-glass cubre ese caso o fuerza un downtime?
4. ¿Qué métrica expondrías para saber si la política se está cumpliendo? (p. ej. `% secrets with TTL < policy_max`).
5. ¿Qué cambia en tu ADR si el proyecto es B2B regulado (SOC 2 / HIPAA) vs. interno?

## 10. Extensiones

- Añade una sección `Monitoring & SLOs` con 2–3 métricas y sus umbrales.
- Añade un diagrama ASCII del flujo de rotación de **una** familia (p. ej. `db-cred` con Vault dynamic).
- Añade un runbook de 10 líneas para el break-glass.

## 11. Limpieza

```bash
rm -rf /tmp/sec-02-adr
```

Nada más que detener.
