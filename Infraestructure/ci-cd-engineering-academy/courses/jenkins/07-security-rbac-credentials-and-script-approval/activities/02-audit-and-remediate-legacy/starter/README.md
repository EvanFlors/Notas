# Starter — jk-07-02-audit-and-remediate-legacy

Entregable: `AUDIT.md` + `REMEDIATION-PLAN.md` en `/tmp/jk-07-audit/`.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio y copia el snapshot:
   ```bash
   mkdir -p /tmp/jk-07-audit
   cd /tmp/jk-07-audit
   cp -r <ruta-repo>/courses/jenkins/07-security-rbac-credentials-and-script-approval/\
   activities/02-audit-and-remediate-legacy/starter/legacy-snapshot ./legacy-snapshot
   ```
3. Explora `legacy-snapshot/`:
   - `plugins.txt` — plugins instalados con versión.
   - `jenkins-security-export.yaml` — realm + authorizationStrategy.
   - `credentials-inventory.md` — credentials sin valores.
   - `scriptApproval.xml` — firmas aprobadas tal cual del controller.
4. Escribe `AUDIT.md` con la estructura de `../README.md § 5.3`.
5. Escribe `REMEDIATION-PLAN.md` con la estructura de `../README.md § 5.4`.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/jenkins/07-security-rbac-credentials-and-script-approval/\
   activities/02-audit-and-remediate-legacy/tests/validate.sh /tmp/jk-07-audit
   ```
7. Compara con `../solution/REFERENCE.md`.

## Pistas (sin dar la solución)

- Hay **cuatro** categorías obligatorias de hallazgo (plugin con CVE crítica, credential con scope inadecuado, script approval con escape de sandbox, rol asignado a anonymous). Las cuatro están presentes en el snapshot — solo tienes que verlas.
- Hay más hallazgos (usuarios inactivos, CSRF debilitado, plugins sin uso, duplicados…) — úsalos para llenar las severidades medias y bajas.
- La matriz severidad × esfuerzo (§9.3 de la lección) ordena el `REMEDIATION-PLAN.md`.
