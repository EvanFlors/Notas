# Examen de certificación — GitLab CI/CD

- **Curso:** `gitlab-cicd`
- **Nivel:** intermedio-avanzado (módulos `gl-04` a `gl-10`, base en `gl-01..03`)
- **Dimensiones evaluadas:** conceptual + operativa + arquitectónica (`todas`)
- **Duración objetivo:** 90–120 min (bloquea 2 h en calendario)
- **Umbral de aprobación:** **70 %** global, con mínimos por sección (ver «Puntaje»)
- **Modalidad:** take-home. **Sin servidor GitLab necesario**: la validación es estructural (parseo YAML + `grep`/`yq` sobre el repo entregable).
- **Prerrequisito:** haber completado el curso `github-actions` (este examen asume el mapping GHA↔GitLab).

---

## Instrucciones generales

1. Entregar un único directorio `entrega/` con la siguiente estructura (ver detalle en cada sección):

   ```
   entrega/
     answers.md              # Sección A (conceptual) + ADR (sección C)
     .gitlab-ci.yml          # Pipeline principal (sección B)
     .gitlab/
       ci/
         jobs.yml            # Jobs reutilizados (include local)
       components/
         scan/template.yml   # Mini CI/CD Component (sección B, parte 5)
     README.md               # Cómo validar localmente
   ```

2. **Prosa en español, código/YAML/comandos en inglés.** No traducir claves de GitLab.
3. **No se evalúan trivia** (nombres de flags, puertos default). Se evalúa **comprensión** y **decisión fundamentada**.
4. **Red flags** (ver `competency-matrix.yaml`) **invalidan la respuesta afectada** y pueden invalidar la sección entera.
5. Las preguntas marcadas *why* / *what-if* exigen causa-efecto, no definición.

### Puntaje

| Sección | Peso | Mínimo |
|---------|------|--------|
| A — Conceptual (Q1–Q11)        | 35 % | 50 % de la sección |
| B — Operativa (`.gitlab-ci.yml` + componente) | 40 % | 60 % de la sección |
| C — Arquitectónica (`architectural/scenario.md` + ADR) | 25 % | 50 % de la sección |

**Aprueba** quien suma ≥ 70 % **y** cumple los tres mínimos. **Un red flag demostrable** reduce la sección afectada a `Insuficiente` sin importar el resto.

---

## A. Preguntas conceptuales (35 %)

Respuestas en `entrega/answers.md`, 4–10 líneas cada una salvo que se indique otra cosa. **Prohibido pegar documentación**; se evalúa razonamiento con tus palabras.

### Q1 — Mapping GHA↔GitLab y rol del Group (C1)

Describe en 6–8 líneas **por qué** `Group` en GitLab no es simplemente «la Org de GitHub con otro nombre», qué habilita que **no** tiene equivalente directo en GHA, y mapea **sin tabla** los siguientes conceptos GHA a su equivalente GitLab más cercano, señalando una diferencia relevante en cada uno:

- `reusable workflow`
- `org runner`
- `environment` con `required reviewers`
- `OIDC token` (GitHub) para asumir rol en AWS

### Q2 — Job `pending` indefinido (*what-if*) (C2)

Un job tiene `tags: [k8s, prod]` y queda en `pending` 30 min. Enumera las **tres causas más probables en orden de frecuencia** y, para cada una, el **comando/UI check** que la confirma. Explica **por qué** `rules:` no es la causa aquí aunque sea un contrato de scheduling.

### Q3 — Variable `protected` vs `masked` (*why*) (C3)

Un compañero propone «mascar todas las variables para no tener que pensar en qué proteger». Explica **qué garantiza `masked:` y qué NO**, **qué garantiza `protected:` y qué NO**, y da **un ejemplo concreto** de un secreto que, mascado pero no protegido, se filtra a un atacante con permiso `Developer` sobre el repo.

### Q4 — `workflow:` vs `rules:` por job (*cuándo preferir*) (C4)

Para cada escenario di si la decisión correcta es **`workflow:`**, **`rules:` por job** o **ambas** y por qué:

a. «No quiero que corra pipeline en commits de documentación (`docs/**`)».
b. «Quiero que el job `deploy_prod` solo corra en `main` tras MR mergeado».
c. «Quiero que un push a una branch con `[skip ci]` en el mensaje no abra pipeline».
d. «Quiero que `test` corra siempre pero `publish` solo si hay tag SemVer».

### Q5 — DAG con `needs:` (*por qué*) (C4)

Dado un pipeline lineal `build → test → package → deploy` con duraciones `3m / 7m / 2m / 4m`, el candidato debe **predecir** el wall-clock antes y después de introducir `needs:` **suponiendo que `package` solo depende de `build`** y `deploy` depende de `test` y `package`. Muestra el cálculo y explica **por qué** el modelo stage-serial pierde tiempo aquí.

### Q6 — `include` vs `extends` vs CI/CD Component (*trade-off*) (C6)

Para los tres casos siguientes elige **el mecanismo** (include local / include project / extends / CI/CD Component) y **justifica en 2–3 líneas** por qué los otros dos no encajan:

a. «Mismo job base de `test` con 4 variantes de versión de Python, dentro del mismo repo.»
b. «Pipeline de 'golden path' compartido por 60 projects del grupo, con `inputs` tipados y versión SemVer.»
c. «Un fragmento de `rules:` reutilizado en 3 jobs del mismo `.gitlab-ci.yml`.»

### Q7 — Elección de executor (*cuándo preferir*) (C7)

Para cada workload di el executor que elegirías (`shell`, `docker`, `kubernetes`, `fleeting`) y la **razón principal + principal trade-off**:

a. Build de imagen OCI reproducible, picos de 50 jobs en paralelo, presupuesto justo.
b. Pipeline de infra que corre `terraform apply` contra una VPN privada on-prem.
c. Suite GPU con drivers CUDA específicos.
d. Pipeline de un sitio estático con 2 jobs/día.

### Q8 — OIDC/ID Token: pinning de trust policy (*what-if*) (C8)

Un pipeline usa `id_tokens:` para asumir un rol en AWS. La trust policy valida solo `aud` y `iss`. Explica **qué ataque concreto** permite esa configuración, qué **claims adicionales** (`sub`, `project_path`, `ref`, `environment`, …) hay que pinnear y **por qué** pinnear solo `project_path` sin `ref` no basta para proteger `production`.

### Q9 — Review Apps y `on_stop:` (*qué garantiza*) (C9)

Explica qué significa `environment:action: start|stop|prepare` y **por qué** omitir `on_stop:` en un Review App no es solo «un residuo cosmético». Da **un ejemplo** de recurso real que queda huérfano y cómo detectarlo.

### Q10 — Scanners nativos (*qué garantiza, qué no*) (C10)

Habilitar `Jobs/SAST.gitlab-ci.yml` y `Jobs/Secret-Detection.gitlab-ci.yml` ¿reduce el riesgo de credencial filtrada en el repo? Explica **qué detecta, qué no**, por qué ninguno **sustituye** `pre-commit` + rotación, y por qué un `allow_failure: true` global sobre los scanners es una red flag.

### Q11 — Compliance Pipeline (*por qué no se puede omitir*) (C11)

Explica el modelo mental de un **Compliance Pipeline / Framework** aplicado a un grupo: por qué un project puede **extenderlo** pero no **omitirlo**, qué pasa si el project redefine un job con el mismo nombre, y por qué este patrón es «pipeline injection controlada» y no «dependency injection».

---

## B. Ejercicio operativo (40 %)

Entregar `.gitlab-ci.yml` + archivos auxiliares (ver estructura arriba). **No se necesita GitLab server**; se valida con los scripts de `operative/` (ver `operative/README.md`).

### Enunciado

Tienes un repositorio de aplicación Python (ficticio) con tests + Dockerfile. Escribe un pipeline que cumpla **todos** los requisitos siguientes. **Es intencional** que el repositorio no exista: la evaluación es estructural sobre el YAML.

1. **Stages:** `build`, `test`, `scan`, `package`, `deploy` (en ese orden).

2. **`workflow:`** top-level que:
   - Permita pipeline en MRs (`merge_request_event`).
   - Permita pipeline en `main` tras merge.
   - **Bloquee** cualquier pipeline con `[skip ci]` en el commit message.

3. **`variables:` globales** que declaren `PYTHON_IMAGE: python:3.12-slim` **con digest pin** (puede ser un digest ficticio `sha256:deadbeef...` — se evalúa el patrón, no el hash real).

4. **DAG con `needs:`**: `test_unit` y `test_lint` corren en paralelo tras `build`, y `package` espera solo a `test_unit` (no a `test_lint`). `deploy_review` solo corre en MRs; `deploy_prod` solo en `main`.

5. **`parallel: matrix:`** en `test_unit` sobre `PY_VERSION: ["3.11", "3.12"]` y `SHARD: ["1/2", "2/2"]`.

6. **Variables y secretos (`gl-03`):**
   - Declarar que `AWS_ROLE_TO_ASSUME` **viene de Group variable protegida** (comentario `# source: group var (protected, masked)` arriba de donde se consume; no inventes el valor).
   - **No** colocar ningún secreto como `variables:` en el YAML.
   - Usar `id_tokens:` para emitir un JWT con `aud: https://sts.amazonaws.com` consumido por `deploy_prod`.

7. **Review Apps (`gl-07`):**
   - `deploy_review` crea `environment: name: review/$CI_MERGE_REQUEST_IID, url: https://$CI_MERGE_REQUEST_IID.review.example.com, on_stop: stop_review, auto_stop_in: 1 week`.
   - `stop_review` con `environment:action: stop` y `rules:` que lo marquen `when: manual`.

8. **Prod protegido:** `deploy_prod` apunta a `environment: name: production` y usa `when: manual` con `allow_failure: false`.

9. **Security scanners (`gl-08`):** incluir **al menos tres** templates nativos vía `include:template:` dentro de `stage: scan` (p. ej. `Jobs/SAST.gitlab-ci.yml`, `Jobs/Secret-Detection.gitlab-ci.yml`, `Jobs/Container-Scanning.gitlab-ci.yml`).

10. **Reutilización (`gl-05`):**
    - `.gitlab-ci.yml` debe usar **`include: local: .gitlab/ci/jobs.yml`** para un job base `.python_defaults` con `image:` + `before_script:` + `cache:` y aplicarlo con `extends:`.
    - Debe existir un **CI/CD Component** mínimo en `.gitlab/components/scan/template.yml` con `spec: inputs:` declarando al menos un input tipado (ej. `severity_threshold`) y consumible vía `include: - component: $CI_SERVER_FQDN/$CI_PROJECT_PATH/scan@~latest`.

11. **Anti-patrones prohibidos** (equivalente a red flags; cualquiera invalida la sección):
    - `only:` / `except:` en vez de `rules:`.
    - Secretos en `variables:` planos.
    - `image:` o `services:` sin tag o con `:latest`.
    - `curl ... | bash` dentro de `script:` o `before_script:`.
    - DinD `privileged: true` sin TLS/justificación.

### Validación

Dentro del directorio del examen, el instructor ejecuta:

```bash
cd evaluation/course-exams/15-gitlab-cicd/operative
./validate.sh ../entrega
```

El script:

- Parsea `.gitlab-ci.yml` con `yq` (o Python+PyYAML) para validar sintaxis.
- Hace `grep`/`yq` estructural para cada requisito (stages, workflow rules, needs, matrix, id_tokens, environment, include:template, include:local, componente).
- Marca red flags (`only:`, `latest`, `curl | bash`, `privileged: true`, AWS keys literales).
- Imprime `PASS` / `FAIL` por check y un score agregado.

**No requiere runner, ni GitLab, ni red.** Solo `yq` o `python3 -c "import yaml"`.

### Rúbrica operativa (resumen)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Sintaxis YAML válida + stages correctos | No parsea | Parsea pero stages mal ordenados | Correcto | Correcto + comentarios de intent |
| `workflow:` filtra MR/main + bloquea `[skip ci]` | Falta | 2 de 3 reglas | 3 de 3 | 3 de 3 + razona `$CI_PIPELINE_SOURCE` en comentario |
| DAG con `needs:` y paralelismo correctos | Lineal | `needs` presente pero mal | DAG como spec | DAG + explica wall-clock en comentario |
| `parallel: matrix:` con sharding | Ausente | Matrix sin shard | Matrix + shard | Matrix + shard + usa `CI_NODE_INDEX` en `script:` |
| OIDC/ID Token sin keys estáticas | Keys hardcoded (RED FLAG) | ID Token sin `aud` correcto | `id_tokens:` con `aud` + Group var | Lo anterior + comentario de pinning por `sub` |
| Review App con `on_stop:` | Falta `on_stop:` (RED FLAG) | `on_stop:` pero sin `action: stop` | Correcto | Correcto + `auto_stop_in` + rules manuales |
| Scanners (≥3 includes template) | 0 | 1–2 | 3 | ≥3 + comentario de triage |
| Reutilización (`include:local` + `extends` + Component) | Nada | Uno de tres | Dos de tres | Los tres y Component con `spec:inputs:` tipado |

**Peso de la sección:** 40 %. Mínimo para aprobar la sección: **60 %**.

---

## C. Ejercicio arquitectónico (25 %)

Resolver `architectural/scenario.md`. Entregar **ADR** dentro de `entrega/answers.md` bajo encabezado `## ADR — <título>`, con secciones estándar: *Contexto*, *Decisión*, *Alternativas consideradas*, *Trade-offs*, *Consecuencias*, *Revisión*.

### Rúbrica arquitectónica (resumen)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Entendimiento del problema | No separa requisitos de restricciones | Lo intenta | Correcto | Correcto + explicita no-goals |
| Alternativas consideradas | 0–1 | 2 sin trade-offs | 2+ con trade-offs reales | 3+, incluye una descartada con razón explícita |
| Decisión fundamentada | Opinión sin anclaje | Justifica una dimensión | Correctness + coste + mantenibilidad | Lo anterior + evolución (`v2`) |
| Seguridad y gobernanza | Ignora OIDC/compliance | Menciona | Aplica OIDC + compliance | Lo anterior + pinning OIDC + Compliance Framework |
| Frontera CI vs CD | Confunde ambos | Separa pero sin razonar | Separa y justifica | Lo anterior + ADR de dónde para CI (publish) y empieza CD (Argo CD) |

**Peso:** 25 %. Mínimo para aprobar la sección: **50 %**.

---

## Preguntas de seguimiento (solo instructor, modalidad live)

Usar para distinguir **memorización** de **comprensión** si una respuesta escrita parece copiada:

- *Q3 follow-up:* «Si una branch no protegida ejecuta un job que hace `echo $SECRET | base64`, ¿`masked:` lo bloquea? ¿Y si lo manda vía `curl` a un webhook externo?»
- *Q5 follow-up:* «Si `test_unit` falla intermitentemente al 20 %, ¿`needs:` lo empeora, mejora o es neutro frente al modelo lineal?»
- *Q8 follow-up:* «Si pinneas `sub` con `project_path:group/proj:ref_type:branch:ref:main`, ¿qué pasa cuando alguien renombra la branch default a `trunk`? ¿Falla seguro o abre un hueco?»
- *OP follow-up:* «Si quito `needs:` entre `package` y `test_unit`, ¿qué cambia en wall-clock? ¿Y si `package` fallara, qué pasa con `deploy_prod` protegido?»
- *ARCH follow-up:* «¿Dónde pondrías el límite entre lo que hace GitLab y lo que hace Argo CD en este diseño? ¿Qué pasa si el equipo rechaza Argo CD?»

---

## Guía de corrección (instructor-only)

Ver detalle completo en `operative/CORRECTION.md` (sección B) y `architectural/scenario.md` (sección C). Resumen de **señales de "respondió sin entender"**:

- Pega la plantilla de GitLab Docs tal cual sin adaptar nombres de jobs/stages.
- Usa `only:` / `except:` «porque es más corto» (indica no leyó `gl-04` o lo leyó sin asimilar).
- Confunde `environment:` con «un string arbitrario»: no modela `on_stop:` ni `auto_stop_in:`.
- Menciona OIDC pero deja keys estáticas en `variables:` «por si acaso».
- En el ADR elige CI/CD Components «porque es lo nuevo» sin trade-off vs `extends` para un caso intra-repo.
- Diseña Compliance Pipeline como «un `include:` opcional» (no entendió el modelo).

**Red flags demostrables** (ver `competency-matrix.yaml`) **invalidan** la sección afectada.
