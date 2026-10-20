# Ejemplo 03 — Plantilla de política de excepciones

> Lectura. Objetivo: ver qué forma tiene una **excepción bien hecha** y por qué, antes de redactar tu propia política en la actividad `02-severity-policy-draft`.

## 1. Suppression vs Exception (recap operativo)

| Dimensión     | Suppression (FP)           | Exception (riesgo aceptado)        |
|---------------|----------------------------|------------------------------------|
| Hallazgo      | no es riesgo real          | **sí** es riesgo real              |
| Decisión      | silenciar en el scanner    | aceptar temporalmente              |
| Aprobador     | autor + reviewer           | **CISO / security lead**           |
| Expiración    | opcional (re-review 90 d)  | **obligatoria** (fecha concreta)   |
| Compensating  | no aplica                  | **obligatorio** (control que mitiga) |
| Audit trail   | comentario con razón       | ticket + registro central          |

Si tu hallazgo necesita las columnas de la derecha pero lo marcas con las de la izquierda, estás escondiendo deuda.

## 2. Plantilla YAML para el registro de excepciones

Vive, idealmente, versionada en el repo (`security/exceptions.yaml`) o en un sistema de GRC. Formato mínimo auditable:

```yaml
# security/exceptions.yaml
# Registro de excepciones aceptadas. Cada entrada DEBE tener:
#   - id único, cve/finding, severity
#   - justification (por qué no se arregla ahora)
#   - compensating_control (qué mitiga mientras tanto)
#   - owner, approver (distintos)
#   - created_at, expires_at (obligatorio)

exceptions:
  - id: EXC-2026-007
    finding: CVE-2024-12345
    scanner: trivy
    severity: HIGH
    cvss: 7.8
    epss: 0.04
    kev: false
    justification: >
      Upstream fix pendiente (libfoo 2.4.1 ETA Q2 2026).
      No podemos bumpear a 2.5 por breaking changes en la API publica.
    compensating_control: >
      WAF rule 'block-foo-vector' habilitada en el edge; firma validada
      en runtime antes de llamar a la funcion afectada.
    owner: team-platform
    approver: ciso
    created_at: 2026-01-15
    expires_at: 2026-06-30
    review_cadence_days: 30

  - id: EXC-2026-012
    finding: CKV_AWS_18   # Checkov: S3 bucket logging
    scanner: checkov
    severity: MEDIUM
    justification: >
      Bucket intermedio en region sandbox-only, sin datos de cliente.
      Logging incrementaria costo sin reducir blast radius real.
    compensating_control: >
      Bucket policy restringe acceso a 1 IAM role usado por 1 pipeline.
      Alerta en CloudTrail si otro principal accede.
    owner: team-data-platform
    approver: head-security
    created_at: 2026-02-01
    expires_at: 2026-08-01
    review_cadence_days: 60
```

## 3. Plantilla de suppression (archivo del scanner)

Para FPs, cada scanner tiene su archivo. Las reglas son las mismas: **razón concreta** + **fecha de review** (aunque el scanner no la fuerce, el humano debe escribirla).

```
# .trivyignore
# Formato: CVE  # razon  (reviewed_until YYYY-MM-DD)

CVE-2023-99999  # path not reachable: fn X never called from app  (reviewed_until 2026-04-30)
CVE-2024-11111  # jar in dev-tools layer; not in runtime image     (reviewed_until 2026-05-15)
```

```python
# ejemplo in-code
value = ast.literal_eval(blob)  # nosemgrep: python.lang.security.audit.eval-detected
# ^ safe: literal_eval, not eval. Reviewed 2026-01-10.
```

```yaml
# .checkov.yaml
skip-check:
  - CKV_K8S_8   # liveness probe required: handled by istio sidecar
                # (reviewed_until 2026-07-01)
```

## 4. Proceso recomendado (flujo)

```
   hallazgo nuevo en PR
         │
         ▼
   ┿ ¿Es FP tecnico? ────► SI ───► suppression con razon + reviewed_until
         │                         (merge; archivo del scanner)
         NO
         ▼
   ┿ ¿Hay fix viable? ───► SI ───► arreglar en el PR / siguiente sprint
         │                         (no exception)
         NO
         ▼
   abrir ticket EXC-YYYY-NNN
         │
         ▼
   escribir entrada en security/exceptions.yaml
     - justification + compensating control
     - owner + approver (distintos)
     - expires_at (<= 180 dias, salvo caso excepcional)
         │
         ▼
   PR a security/exceptions.yaml ──► review de security lead
         │
         ▼
   merge; el scanner lee el registro y deja pasar
   el hallazgo HASTA expires_at
```

## 5. Anti-patrones a vetar en revisión

- `# noqa` sin texto.
- `.trivyignore` con 50 CVEs y 0 comentarios.
- Excepción **sin `expires_at`** ("hasta nuevo aviso" = indefinido = jamás).
- Excepción cuyo `owner` y `approver` son la misma persona.
- Compensating control = "lo tenemos en el roadmap" (eso **no** es un control).
- Suppression **wildcard** por severidad (`ignore_severity: HIGH` global).

## 6. Métricas que deberías mirar

- Nº total de exceptions **activas** por severidad.
- Nº de exceptions **expiradas sin renovar** (deberían ser 0 — si no, el proceso no funciona).
- **Edad media** de las exceptions (si sube con el tiempo, estás acumulando deuda).
- Nº de suppressions re-revisadas en el último trimestre.

Si estas métricas no viven en un dashboard, la política existe solo en Markdown — no en operación.
