# Actividad 02 — Añadir gate manual al deploy a `prod`

## 1. Identificación

- **ID:** `gha-09-02-add-manual-gate-to-prod`
- **Tecnología:** `github-actions`
- **Módulo:** `09-environments-approvals-and-deployment-protection`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes un workflow que ya despliega a `prod` **sin gates**: cualquier push a `main` llega a producción sin pausa, sin aprobación, sin restricción de branch. Vas a añadir tres gates al environment `prod`: *required reviewer*, *wait timer* y *branch policy* custom con `refs/heads/main`. También vas a escribir una **DECISION.md** justificando la política para un equipo con on-call.

Dos modos como en la actividad 01:

- **`MODE=local`** (default): valida el workflow (no cambia) y el sidecar `environment-prod.yaml` que describes.
- **`MODE=live`**: aplica el sidecar al environment real.

## 3. Objetivos

Al terminar:
- Sabes dónde vive la configuración de un environment (recurso API) y dónde no (YAML del workflow).
- Produces `environment-prod.yaml` con `wait_timer`, `prevent_self_review`, ≥1 reviewer y `deployment_branch_policy` restringiendo a `main`.
- Produces `DECISION.md` justificando la política de approvals para un equipo con on-call (≥10 líneas no vacías).
- El workflow original queda **sin cambios** (el gate vive en el environment, no en el YAML del workflow).

## 4. Prerrequisitos

- Actividad `gha-09-01-three-env-pipeline` completada (recomendado).
- `python3`, `pyyaml`.
- Opcional MODE=live: `gh` autenticado + repo sandbox.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha09-manual-gate
cd /tmp/gha09-manual-gate
cat .github/workflows/release.yaml   # observa: environment: prod SIN gates
cat environment-prod.yaml            # PLACEHOLDER a reemplazar
```

El starter crea un workflow **que ya existe** y un sidecar vacío que vas a completar.

### 5.2 **No** modifiques el workflow

El workflow (`.github/workflows/release.yaml`) **no** debe cambiar. Si lo editas, el validador reportará `workflow modified unexpectedly`. El objetivo es que te convenzas de que el gate vive en el recurso GitHub, no en el YAML.

### 5.3 Editar `environment-prod.yaml`

Reemplaza el placeholder con un sidecar que cumpla:

- `name: prod`.
- `wait_timer: >= 5` (minutos).
- `prevent_self_review: true`.
- `reviewers`: lista con **al menos 2 entradas** y **al menos una** de tipo `Team` (justificación: on-call rotation).
- `deployment_branch_policy`:
  - `protected_branches: false`
  - `custom_branch_policies: true`
  - `patterns: ["refs/heads/main"]` (puedes añadir `refs/heads/hotfix/*` si quieres, el validador lo acepta).

### 5.4 Escribir `DECISION.md`

Crea `/tmp/gha09-manual-gate/DECISION.md` con **al menos 10 líneas no vacías** que respondan explícitamente:

- Por qué elegiste reviewers de tipo `Team` (no `User`).
- Por qué `prevent_self_review: true`.
- Cuántos reviewers y por qué (bus factor, fatiga).
- Qué `wait_timer` elegiste y por qué.
- Qué pasa a las 3am del sábado con un hotfix urgente. Cómo lo resuelve tu política.
- Qué quedó fuera (p. ej. custom protection rules via Apps) y por qué.

### 5.5 Validar

```bash
MODE=local bash tests/validate.sh /tmp/gha09-manual-gate
```

### 5.6 Validar en live (opcional)

```bash
export GH_OWNER=your-user GH_REPO=your-sandbox-repo
MODE=live bash tests/validate.sh /tmp/gha09-manual-gate
```

## 6. Resultado esperado

- `.github/workflows/release.yaml` **sin modificar** (hash igual al del starter).
- `environment-prod.yaml` completado con los gates descritos.
- `DECISION.md` presente con contenido sustantivo.
- Validator sale 0.

## 7. Criterios de aceptación

- [ ] Workflow intacto (mismo hash que el starter).
- [ ] `environment-prod.yaml` con `wait_timer >= 5`, `prevent_self_review: true`, ≥2 reviewers (≥1 Team), branch policy custom con `refs/heads/main`.
- [ ] `DECISION.md` con ≥10 líneas no vacías.
- [ ] `validate.sh` sale 0 en MODE=local.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha09-manual-gate
MODE=live  bash tests/validate.sh /tmp/gha09-manual-gate   # opcional
```

## 9. Preguntas de reflexión

1. Si tu reviewer es un `User` concreto y se va de vacaciones, ¿qué pasa con los deploys a prod?
2. ¿Qué diferencia hay entre poner `wait_timer: 10` y pedir aprobación? ¿Cuál es más estricto?
3. Si tienes `custom_branch_policies: true` con `refs/heads/main` pero el equipo decide hacer un hotfix desde `hotfix/urgent-123`, ¿qué cambia en el sidecar para permitirlo sin abrir todo?
4. ¿Qué información queda en el `deployment_status.creator` cuando el reviewer aprueba? ¿Sirve para auditoría?
5. ¿Cómo cambiarías tu DECISION.md si el equipo tuviera 2 ingenieros en lugar de 4?

## 10. Extensiones

- **E1** — Añade un patrón `refs/heads/hotfix/*` y documenta en DECISION.md por qué sí/no.
- **E2** — Diseña (sin implementar) un *custom protection rule* vía GitHub App que verifique "no hay incidente Sev-1 activo en PagerDuty".
- **E3** — Añade `environment-staging.yaml` con una política menos estricta (solo `wait_timer: 2`, sin reviewers). Compara.
- **E4** — Escribe un `drift-check.sh` que lea el environment real y falle si no coincide con el sidecar.

## 11. Limpieza

```bash
rm -rf /tmp/gha09-manual-gate
# MODE=live:
gh api -X DELETE "repos/$GH_OWNER/$GH_REPO/environments/prod" || true
```
