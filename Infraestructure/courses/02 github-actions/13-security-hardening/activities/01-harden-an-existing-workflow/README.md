# Actividad 01 — Harden an existing insecure workflow (+ ADR)

## 1. Identificación

- **ID:** `gha-13-01-harden-an-existing-workflow`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-13-security-hardening`
- **Dificultad:** advanced
- **Duración estimada:** 60–120 min
- **Tipo:** **independent** (no se te revela la lista exacta de fallas; tú las descubres)

## 2. Contexto

Un equipo nuevo entra a un repo heredado con workflows "que funcionan" pero no han sido auditados nunca. Tu trabajo como ingeniero senior es: **recibir el workflow, encontrar los problemas, endurecerlo y documentar las decisiones en un ADR**. Esto es el 80% del trabajo de seguridad de CI/CD en organizaciones reales — remediar deuda, no diseñar greenfield.

El starter te entrega un workflow realista con **al menos cinco anti-patrones de seguridad** (puede haber más — búscalos todos). No se te dice cuáles son por diseño: forma parte del ejercicio reconocerlos sin pista.

El entregable son dos archivos:
1. `.github/workflows/release.yml` — tu versión endurecida.
2. `docs/adr/0001-ci-security-hardening.md` — un **Architecture Decision Record** siguiendo el formato *Context / Decision / Consequences*, con una entrada por cada clase de cambio aplicado.

## 3. Objetivos

- Auditar sin pista: identificar al menos **cinco** categorías de problema de seguridad en el workflow starter.
- Reescribir aplicando los controles de `gha-13` §2–§6: permissions mínimos, pin a SHA, `env:` para datos no confiables, uso correcto de `pull_request_target`, scope apropiado de secrets.
- Escribir un ADR que, para cada cambio: cite el anti-patrón, el riesgo materializado (p. ej. qué incidente real lo ejemplifica), y la defensa elegida con alternativa descartada.
- Pasar el validator automático que comprueba el baseline.

## 4. Prerrequisitos

- `bash`, `python3` con `pyyaml`.
- Haber hecho **primero** `activities/02-detect-script-injection/` (fija el patrón `env:` + `"$VAR"`).
- Haber leído `theory/lesson.md` completo (en particular §2.3, §2.4, §10).

**Costos**: USD 0, 100% local.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/harden-workflow
cd /tmp/harden-workflow/project
```

Verás un repo scratch con:
- `.github/workflows/release.yml` — el workflow a endurecer.
- `src/` — carpeta vacía representativa.
- `README.md` — descripción del repo imaginario.

### 5.2 Fase 1 — Auditoría

Lee el workflow y **lista en un papel** (o en el ADR directamente) todos los problemas que encuentres. Pistas de alto nivel sobre qué mirar:

- Bloque `permissions:` — ¿existe? ¿es mínimo?
- Cada `uses:` — ¿pin a SHA o a tag?
- Cada `run:` — ¿interpola valores controlables por el actor del evento?
- Triggers — ¿usa `pull_request_target`? Si sí, ¿checkout del head del PR? ¿ejecuta código del PR?
- Secrets — ¿usa `AKIA` / `AWS_ACCESS_KEY_ID` cuando debería usar OIDC?
- Scope de secrets — ¿están a nivel repo cuando deberían estar en environment?

Hay **al menos 5** problemas, y potencialmente más. No te detengas en el quinto.

### 5.3 Fase 2 — Reescritura

Reescribe `/tmp/harden-workflow/project/.github/workflows/release.yml` aplicando:

1. **`permissions:` top-level** restrictivo (`{}` o `contents: read`). **Escalada por job**.
2. **Pin a SHA** (40 hex) para toda `uses:`, con comentario `# vX.Y.Z`. Ejemplos de SHAs reales que puedes usar:
   - `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2`
   - `actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0`
   - `aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2`
   - `softprops/action-gh-release@c062e08bd532815e2082a85e87e3ef29c3e6d191  # v2.0.8`
   - Para la action de tercero (`shady-vendor/scan-everything`): investiga/sustituye por una legítima equivalente y pínnea, o elimina si no es imprescindible.
3. **`env:` + `"$VAR"`** para cualquier dato del evento que acabe en un `run:`.
4. **`pull_request_target`**: elimínalo si no es necesario (si solo tests, usa `pull_request`); si es necesario para una operación que requiere secrets, aíslalo en un workflow separado o cambia a `pull_request` para la parte que ejecuta código del PR.
5. **OIDC a AWS** en vez de secrets `AKIA`.
6. **Scope de secrets de prod a environment** (`environment: production`).

### 5.4 Fase 3 — ADR

Crea `/tmp/harden-workflow/project/docs/adr/0001-ci-security-hardening.md` con el formato:

```markdown
# ADR 0001 — CI security hardening of release.yml

## Status
Accepted — <fecha>

## Context
<Describe el workflow original, los riesgos materializados, el objetivo del hardening.>

## Decision
Para cada cambio aplicado, una subsección:

### D1 — Pin all actions to SHA
- Antipatrón: `uses: actions/checkout@v4` (tag mutable).
- Riesgo materializado: incidente `tj-actions/changed-files` (marzo 2025).
- Decisión: todas las actions a SHA de 40 hex, con comentario `# vX.Y.Z`.
- Alternativa descartada: pinnear a `@v4` + confiar en Dependabot.

### D2 — Minimum GITHUB_TOKEN permissions
### D3 — Env-var hardening of run blocks
### D4 — Replace pull_request_target with safe pattern
### D5 — OIDC instead of long-lived AWS keys
<... una por cada clase de cambio>

## Consequences
Positivas: ...
Negativas / costos operativos: ...
Pendiente (fuera de scope de este ADR): ...
```

Mínimo: **5 subsecciones D1–Dn**, un `## Status`, un `## Context`, un `## Consequences`.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/harden-workflow
```

Debe reportar `RESULT: ALL CHECKS PASS`.

## 6. Resultado esperado

- `.github/workflows/release.yml` YAML válido que pasa todos los checks del validator.
- `docs/adr/0001-ci-security-hardening.md` con las secciones requeridas y al menos 5 decisiones (D1…D5+).

## 7. Criterios de aceptación

- [ ] Todas las `uses:` pinneadas a SHA de 40 hex (no `@v*`, no `@main`, no `@master`).
- [ ] `permissions:` top-level presente y no equivalente a `write-all`.
- [ ] Cero interpolaciones `${{ github.event.* }}` / `${{ github.actor }}` / `${{ github.head_ref }}` dentro de `run:`.
- [ ] `pull_request_target` ausente, o presente **sin** `ref: ${{ github.event.pull_request.head.sha }}`.
- [ ] Sin uso de `secrets.AWS_ACCESS_KEY_ID` / `secrets.AWS_SECRET_ACCESS_KEY` ni cadenas `AKIA...`.
- [ ] ADR existe con `## Status`, `## Context`, al menos 5 subsecciones `### D` dentro de `## Decision`, y `## Consequences`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/harden-workflow
```

El validator:

1. Parsea YAML del workflow.
2. Chequea cada `uses:` contra regex `@[a-f0-9]{40}\b`.
3. Chequea `permissions:` presente y no `write-all`.
4. Recorre cada `run:` buscando interpolaciones peligrosas (lista cerrada).
5. Chequea ausencia de `pull_request_target` + `ref: ${{ github.event.pull_request.head.sha }}`.
6. Grep ausencia de `secrets.AWS_ACCESS_KEY_ID` / `secrets.AWS_SECRET_ACCESS_KEY` / `AKIA[0-9A-Z]+`.
7. Lee el ADR y comprueba secciones + número mínimo de decisiones.

## 9. Preguntas de reflexión

1. ¿Qué pasaría si **solo** aplicas pin a SHA pero mantienes `permissions: write-all`? Describe un escenario de ataque realista.
2. En el ADR, para cada decisión escribiste una "alternativa descartada". Si tu equipo decide revertir una por fricción de developer experience (p. ej. "pin a SHA es ilegible"), ¿cuál es tu respuesta estructurada?
3. El validator **no comprueba** `harden-runner`, approval de PRs externos, ni OIDC. ¿Por qué estos controles son más difíciles de validar automáticamente en una actividad local?
4. ¿Qué controles de los que aplicaste requieren configuración **fuera del YAML** (settings del repo, environment, OIDC provider en AWS)? ¿Cómo los documentarías para que el próximo ingeniero no los descarte?
5. Si fueras *platform engineer* a nivel org, ¿cuáles de estos controles convertirías en **required workflow** (`gha-15`) y cuáles dejarías como "best practice"?

## 10. Extensiones

- **E1** — Añade un segundo workflow `ci.yml` (tests + lint en PR) también endurecido, y actualiza el ADR con una decisión transversal "default hardening para todos los workflows nuevos".
- **E2** — Añade `.github/dependabot.yml` con `github-actions` ecosystem (ver `examples/03`) y menciónalo en el ADR como "control continuo que cubre D1".
- **E3** — Añade `step-security/harden-runner@<SHA>` en `audit` mode al inicio de cada job y una decisión D6 en el ADR explicando defensa en profundidad.
- **E4** — Convierte el workflow para que **suba una attestation SLSA** del artefacto del release (preview de `gha-14`).

## 11. Limpieza

```bash
rm -rf /tmp/harden-workflow
```
