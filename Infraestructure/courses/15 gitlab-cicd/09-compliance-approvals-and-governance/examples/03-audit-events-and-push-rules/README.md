# Ejemplo 03 — Audit events y Push rules

> Lectura y análisis. Objetivo: ver un **audit event** real (anonimizado) y un conjunto de **push rules** típicas, y entender dónde se corta cada cosa.

## 1. Un audit event tal como lo recibe un SIEM

GitLab emite audit events en formato JSON. Ejemplo (streaming → Splunk HEC) de un cambio en protected branch:

```json
{
  "id": 1024789,
  "author_id": 42,
  "entity_id": 931,
  "entity_type": "Project",
  "entity_path": "workloads/checkout",
  "details": {
    "custom_message": "Updated protected branch 'main'",
    "change": "code_owner_approval_required",
    "from": false,
    "to": true,
    "author_name": "alice.ops",
    "author_email": "alice.ops@corp.example.com",
    "target_type": "ProtectedBranch",
    "target_details": "main",
    "ip_address": "10.42.0.17",
    "entity_path": "workloads/checkout"
  },
  "created_at": "2026-10-15T12:04:33.112Z"
}
```

Qué lee un auditor:

- **Quién**: `alice.ops`.
- **Qué**: activó `code_owner_approval_required=true` en `main`.
- **Dónde**: project `workloads/checkout`.
- **Cuándo**: timestamp.
- **Desde dónde**: IP corporativa.

Si alguien hubiera **desactivado** la protección, el `from/to` se vería invertido y debería **alertar** al SOC.

## 2. Eventos clave para alertar

- `protected_branch_removed` sobre `main` o `release/*` → **crítico** (alguien bajó un guardrail).
- `compliance_framework_unassigned_from_project` → **crítico** (alguien quitó la etiqueta de compliance).
- `deploy_token_created` con scope `write_repository` → **alto**.
- `project_visibility_changed` de `private` a `public` → **alto**.
- `user_access_granted_to_project` con role `Owner` → **medio** (puede ser legítimo pero merece revisión).
- `pipeline_schedule_created` que corre a las 03:00 UTC → **medio** (horarios inusuales = investigar).

## 3. Push rules del baseline (como se verían en settings)

```
Reject unsigned commits:            YES
Reject unverified users:            YES
Max file size:                      50 MB
Commit message regex:               ^(JIRA|SEC|OPS)-\d+:
Deny commit message regex:          (?i)(wip|fixup!|do +not +merge)
Branch name regex:                  ^(feature|fix|chore|release)/[a-z0-9-]+$
Author email regex:                 ^[a-z.]+@corp\.example\.com$
Prevent pushing secret files:       YES  (built-in list: *.pem, id_rsa, *.key, .env)
Prohibited file names (custom):     ^(credentials|secrets)\.(json|yml|yaml)$
```

Cada regla rechaza en `pre-receive`. Pros:

- No consume minutos de runner.
- Da feedback inmediato al developer en `git push`.
- Imposible evadir desde CI (es a nivel git server).

Contras:

- No puede validar contenido semántico (p. ej. "la función `charge()` tiene test"). Para eso necesitas pipeline.
- Regex mal escritas se vuelven dolor crónico para el equipo. Siempre probar en Sandbox primero.

## 4. Mapa mental

```
   git push
      │
      ▼
┌─────────────────────┐
│ pre-receive hook    │   ← push rules (sin runner)
│ - commit msg regex  │
│ - deny secrets      │
│ - signed commits    │
└──────┬──────────────┘
       │ (si pasa)
       ▼
┌─────────────────────┐
│ Pipeline            │   ← compliance pipeline (framework)
│ - SAST / Secret     │
│ - tests del project │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│ Approvals           │   ← MR approval rules
│ - N approvers       │
│ - code owners       │
│ - security findings │
└──────┬──────────────┘
       │
       ▼
     Merge
       │
       ▼
┌─────────────────────┐
│ Audit event emitted │   ← stream a SIEM
└─────────────────────┘
```

Cada capa es independiente. Si una falla, hay otras. "Defense in depth" aplicado a CI/CD.
