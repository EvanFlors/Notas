# Starter — gl-10-02-platform-adr-final

Esta actividad es **independiente**. Entregas un único archivo escrito por ti: `PLATFORM-ADR.md`.

## Pasos

1. Lee `../README.md` completo y recorre los `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-10-platform
   cd /tmp/gl-10-platform
   ```
3. Crea `PLATFORM-ADR.md` con las 6 secciones obligatorias (`ADR`, `Estado`, `Contexto`, `Decisión`, `Consecuencias`, `Alternativas`).
4. Cubre, dentro de `Decisión`:
   - **Catálogo** (inner-source, Code Owners, SemVer, deprecation policy).
   - **Runners / Cost** (SaaS vs K8s/Fleeting).
   - **Observabilidad** (4 métricas con nombres).
   - **Argo CD** (frontera CI/CD).
   - **GHA vs GitLab** para 3 organizaciones (startup, scaleup, enterprise).
   - Mención de **Compliance Framework**.
   - Al menos 1 fenced code block (PromQL, YAML, JSON — tú eliges).
5. Lista al menos **2 alternativas descartadas**.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/10-migration-and-platform-patterns/activities/02-platform-adr-final/tests/validate.sh /tmp/gl-10-platform
   ```
7. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueleto sugerido

```markdown
# ADR 011 — GitLab como plataforma de CI/CD de la org

## Estado
Propuesto

## Contexto
<300 ingenieros, 120 repos, migración piloto completada, qué piden>

## Decisión

### 1. CI/CD Catalog interno
- inner-source: ...
- Code Owners por componente.
- SemVer y deprecation (`@deprecated` + 90 días).

### 2. Runners y cost control
- SaaS vs K8s + Fleeting: criterios.

### 3. Observabilidad
- 4 métricas: pipeline duration, job success rate, queue time, minutos consumidos.
- Fuentes: Prometheus exporter + GraphQL.
- Ejemplo PromQL:

```promql
histogram_quantile(0.95, sum(rate(gitlab_runner_job_duration_seconds_bucket[15m])) by (le))
```

### 4. Frontera CI/CD ↔ Argo CD
- GitLab construye y publica; Argo aplica.

### 5. Compliance Framework
- ...

### 6. GHA vs GitLab por organización
| Org | Elección | Por qué |
|-----|----------|---------|
| Startup 20 personas | ... | ... |
| Scaleup 300 | ... | ... |
| Enterprise 5000 | ... | ... |

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A — Catálogo "cerrado" (solo Platform escribe)
- Por qué no: ...
### Alt B — Despliegue directo desde GitLab a prod (sin Argo)
- Por qué no: ...
```
