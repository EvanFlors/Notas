# Examen de certificación — Git & GitHub

- **Curso:** `git-and-github` (módulos `gh-01` a `gh-13`).
- **Nivel:** intermedio-avanzado.
- **Dimensión:** todas (conceptual + operativa + arquitectónica).
- **Duración:** 90–120 min take-home + 30 min live defense.
- **Umbral de aprobación:** 70% (nivel *Competente*).
- **Entorno:** local (Git ≥ 2.38, Python 3, bash). Sin cloud, sin secretos reales.
- **Entrega:** repo con la solución del ejercicio operativo + respuestas en Markdown + ADR del ejercicio arquitectónico.

---

## 1. Matriz de competencias evaluadas

| ID  | Competencia (verbo + resultado observable) | Dimensión | Peso | Evaluada en |
|-----|---------------------------------------------|-----------|------|-------------|
| C1  | Explicar por qué rebase reescribe hashes y qué garantías pierde/mantiene vs. merge; decidir cuándo rebasar. | conceptual | 8 | Q1, OP |
| C2  | Describir el modelo de objetos (blob/tree/commit) y predecir qué objetos crea una operación (amend, rebase, cherry-pick). | conceptual | 7 | Q2 |
| C3  | Reescribir historia local con rebase interactivo (reorder + fixup + reword) con resultado atómico y revisable. | operativa | 15 | OP |
| C4  | Recuperar trabajo tras un reset destructivo via reflog; explicar la ventana de supervivencia de objetos huérfanos. | conceptual | 6 | Q3 |
| C5  | Elegir estrategia de merge y modelo de ramificación justificándolo contra equipo, release cadence y auditoría. | arquitectónica | 12 | Q4, AR |
| C6  | Diseñar un juego de hooks (local vs. servidor, framework `pre-commit`) alineado al riesgo que mitigan. | conceptual | 6 | Q5 |
| C7  | Diseñar branch protection (Rulesets + CODEOWNERS + environments) articulando cada regla contra un riesgo. | arquitectónica | 12 | AR |
| C8  | Elegir método de autenticación (SSH / PAT classic / fine-grained / GitHub App / OIDC) por blast radius y rotación. | conceptual | 8 | Q6, AR |
| C9  | Explicar qué garantiza (y qué no) una attestation SLSA de GHA y una firma de commit verificada. | conceptual | 7 | Q7 |
| C10 | Diseñar la cadena de controles de supply chain priorizándolos por costo/beneficio frente a un modelo de amenaza. | arquitectónica | 10 | AR |
| C11 | Localizar el commit introductor de una regresión con bisect y pickaxe (`-S/-G`). | conceptual | 5 | Q8 |
| C12 | Explicar la diferencia entre `push --force` y `push --force-with-lease` y el modo de falla que mitiga. | conceptual | 4 | Q1, OP |

**Total:** 100 pts. Distribución por bloque: conceptual 45 / operativo 30 / arquitectónico 25.

---

## 2. Preguntas conceptuales

> Formato: respuesta corta (3–8 frases). Evitar listas enciclopédicas; se evalúa comprensión. Peso indicado al final de cada enunciado.

### Q1 — Rebase vs. merge sobre historia pública (C1, C12) — 7 pts

Tu rama `feature/x` ya está pusheada y ha sido revisada por dos personas. Antes de mergear, decides hacer `git rebase main && git push --force-with-lease`.

**(a)** ¿Por qué `--force-with-lease` es preferible a `--force`? Describe el modo de falla concreto que *solo* `--force-with-lease` evita.
**(b)** ¿En qué situación esa decisión de rebase+force-push es defendible y en cuál es un abuso? Da un criterio objetivo (no "depende del equipo").

### Q2 — Internals: ¿qué objetos crea cada operación? (C2) — 7 pts

Partes de un commit `C` con un único archivo `a.txt`. Explica, para cada operación, **qué objetos nuevos aparecen** en `.git/objects/` y **cuál es el padre** del commit resultante:

- **(a)** `git commit --amend` cambiando el mensaje (sin tocar `a.txt`).
- **(b)** `git cherry-pick C'` donde `C'` toca `b.txt`.
- **(c)** `git rebase` de `C` sobre otra base que no modifica `a.txt`.

### Q3 — Reflog como red de seguridad (C4) — 6 pts

Un compañero hizo `git reset --hard HEAD~5` y perdió 5 commits locales que nunca pusheó. Vino a pedirte ayuda **8 días después**.

**(a)** ¿Qué hay que mirar antes de tocar nada? **(b)** ¿Qué puede haber hecho `git gc` en el ínterin y qué configuraciones del lado del cliente definen esa ventana? **(c)** ¿En qué escenario la recuperación es definitivamente imposible?

### Q4 — Elección de estrategia de merge (C5) — 6 pts

Equipos A y B tienen políticas distintas:

- A: "squash and merge" obligatorio, main lineal, sin merge commits.
- B: "merge commit" obligatorio (no fast-forward), preserva topología.

Para cada uno, da **un escenario concreto donde el modelo falla** (una pregunta que la historia no puede responder, un bug que es más caro de encontrar, una auditoría que no cuadra, etc.). No basta decir "pierde contexto" o "es ruidoso".

### Q5 — Hooks: cliente vs. servidor (C6) — 6 pts

Un equipo propone usar un `pre-commit` que corre `pytest` completo, scanea secretos, verifica licencias y rechaza mensajes que no sigan Conventional Commits.

**(a)** ¿Qué de esto *no debería* estar en el hook del cliente y por qué? **(b)** ¿Qué controles son críticos y deberían estar también —o solo— en el servidor (ruleset o `pre-receive`)? **(c)** ¿Cómo cambia el análisis si el equipo trabaja en GitHub-hosted vs. GitHub Enterprise self-hosted?

### Q6 — Autenticación: PAT fine-grained vs. GitHub App vs. OIDC (C8) — 7 pts

Para un pipeline de GitHub Actions que debe (i) escribir en una rama de otro repo de la misma organización y (ii) desplegar a AWS:

**(a)** ¿Qué método de autenticación eliges para cada acción y por qué?
**(b)** Un reviewer propone usar un PAT classic almacenado como secret del repo. Da **dos razones técnicas** (no "las mejores prácticas") por las que es una decisión mala, y qué incidente concreto hace probable.

### Q7 — Firmas y attestations: alcance real (C9) — 6 pts

**(a)** Un commit aparece como "Verified" en GitHub. ¿Qué puedes concluir con certeza y qué **no** puedes concluir? Da un ejemplo de un ataque que la firma no detecta.
**(b)** Una attestation SLSA de build provenance generada por `actions/attest-build-provenance`. ¿Qué atestigua exactamente? ¿Protege contra un maintainer malicioso del repo? Justifica.

### Q8 — Bisect vs. pickaxe (C11) — 5 pts

Reportan que la función `calculate_tax` empezó a devolver resultados erróneos "en algún momento del último mes". No hay test que falle de forma determinista, pero sí un caso de datos que reproduce el bug a mano.

**(a)** ¿Usarías `git bisect` o `git log -S` / `-G`? Elige **una** y justifica qué tipo de evidencia aporta.
**(b)** ¿En qué caso el otro habría sido mejor? Describe el escenario.

---

## 3. Ejercicio operativo (OP) — 30 pts

### 3.1 Enunciado

Te entregan un repo con una rama `feature/payments` que contiene **1 commit base** + **5 commits sucios** encima (`wip`, `typo`, `add tests`, `oops forgot header`, `fix typo again`). Debes dejar **exactamente 2 commits** sobre la base, con separación atómica de responsabilidades:

1. `feat(payments): add refund processor` — solo código de producción (`payments.py`), incluyendo header de licencia y typo corregido.
2. `test(payments): cover refund processor` — solo tests (`tests/test_payments.py`).

El contenido final debe ser funcionalmente equivalente al estado actual del HEAD sucio (los tests pasan).

### 3.2 Materiales de inicio

Starter autocontenido en `operative/starter/build-messy-branch.sh` (adaptado de la actividad `gh-06-01-squash-and-reorder`). Para construir el repo de examen:

```bash
bash operative/starter/build-messy-branch.sh /tmp/exam-op
cd /tmp/exam-op
git log --oneline
```

### 3.3 Entregables

1. El directorio `/tmp/exam-op` tras tu rebase (working tree limpio, 2 commits sobre la base).
2. `operative/ANSWER.md` con **tu procedimiento** (plan del todo-file o script `solve.sh`) y respuesta a estas preguntas:
   - ¿Por qué el **orden** de las líneas en el todo-file es relevante aquí? ¿Qué pasaría si pusieras un `fixup` *antes* de su `pick` target?
   - ¿Diferencia entre `fixup` y `squash`? ¿Cuándo preferirías cada uno?
   - Si esta rama ya estuviera pusheada y revisada, ¿harías `push --force`, `push --force-with-lease`, o abandonarías el rebase? Justifica contra la política de rebase pública (ver Q1).
3. Opcional (puntúa en *Experto*): un `solve.sh` reproducible usando `GIT_SEQUENCE_EDITOR` para que el rebase sea no-interactivo.

### 3.4 Validación automática

Ejecuta localmente:

```bash
bash operative/tests/validate.sh /tmp/exam-op
```

El script verifica:
- HEAD en `feature/payments`, working tree limpio.
- Exactamente 2 commits sobre `init: payments module scaffold`.
- Subjects **exactos** (`feat(payments): add refund processor`, `test(payments): cover refund processor`).
- El commit `feat(...)` toca `payments.py` y **no** `tests/`.
- El commit `test(...)` toca únicamente `tests/test_payments.py`.
- `payments.py` incluye `# Copyright` en línea 1 y `def refund(` corregido, devuelve `"accepted"`.
- Si Git < 2.30 o `python3` ausente: el script **salta con SKIP** señalando el requisito ausente, no falla.

Puntuación: criterios en la rúbrica (§5.1).

---

## 4. Ejercicio arquitectónico (AR) — 25 pts

### 4.1 Escenario

Escenario completo en `architectural/scenario.md`. Resumen:

> Tu equipo (6 ingenieros + 1 compliance officer) migra desde GitLab self-hosted a GitHub Enterprise Cloud. El producto es una API financiera que despliega a AWS 10–20 veces por semana. Hay auditoría SOC 2 anual. Debes diseñar: (1) workflow de ramificación, (2) estrategia de merge, (3) controles de gobernanza del repo (Rulesets + CODEOWNERS + environments), (4) método de autenticación GHA → AWS, (5) cadena de controles de supply chain priorizada.

### 4.2 Entregables

En `architectural/ANSWER.md` (o un ADR separado):

1. **Decisión** por cada uno de los 5 puntos.
2. **Trade-offs**: para cada decisión, qué alternativas descartaste y por qué (en términos de **blast radius**, **velocidad de integración**, **costo de auditoría** y **blast radius de un secreto comprometido**).
3. **ADR** (formato Nygard) de la decisión más controvertida.
4. **Diagrama** (ASCII o Mermaid) mostrando: ramas → PRs → required checks → environments → deploy → attestation.
5. **Modelo de amenaza mínimo**: 3 amenazas priorizadas y qué control(es) de tu diseño las mitiga.

Puntuación: rúbrica §5.2.

---

## 5. Rúbrica

### 5.1 Rúbrica del ejercicio operativo (OP)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|----------|------------------|------------|----------------|-------------|------|
| **Correctness** (validate.sh) | Falla ≥3 checks o no ejecuta. | Pasa estructura pero falla scope (feat toca tests/ o viceversa). | Pasa todos los checks de validate.sh. | Pasa + `solve.sh` reproducible (no-interactivo con `GIT_SEQUENCE_EDITOR`). | 3 |
| **Atomicidad del commit** | Commits mezclados o residuales. | Separación parcial (p. ej. header en commit de tests). | Scope limpio: feat solo prod, test solo tests. | Scope limpio + mensajes conforme a Conventional Commits en subject y body. | 3 |
| **Justificación de orden** | No contesta o afirma que el orden es irrelevante. | Dice que importa pero no explica por qué. | Explica que `fixup` aplica al pick inmediatamente anterior en el plan. | Lo anterior + demuestra el modo de falla concreto (header queda en commit de tests). | 2 |
| **Fixup vs squash** | Confunde o no distingue. | Nombra diferencia de mensaje pero no criterio de uso. | Distingue correctamente mensaje y uso típico. | Añade cuándo `--autosquash` + `commit --fixup=<sha>` reduce fricción. | 1 |
| **Política de push público** | Diría `--force` sin matices. | Menciona `--force-with-lease` sin explicar qué evita. | Explica la race condition que `--force-with-lease` detecta. | Lo anterior + distingue "rama de autor único" vs. "rama compartida" como criterio. | 1 |

**Total OP:** 30 pts (sumatorio 10 × ponderación × 3 niveles ≈ normalizado a 30).

### 5.2 Rúbrica del ejercicio arquitectónico (AR)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) | Peso |
|----------|------------------|------------|----------------|-------------|------|
| **Coherencia end-to-end** | Decisiones aisladas o contradictorias (p. ej. squash-only + required signed merges). | Coherente en 3 de 5 puntos. | Las 5 decisiones encajan sin contradicción. | Lo anterior + anticipa 1 modo de falla no obvio (p. ej. CODEOWNERS como bypass accidental). | 3 |
| **Trade-offs explícitos** | "Es la mejor práctica" sin alternativas. | Nombra alternativas sin dimensionar costos. | Articula trade-offs en los 4 ejes pedidos (blast radius, velocidad, auditoría, blast radius de secreto). | Lo anterior + cuantifica (p. ej. "con PAT org-wide, 180 repos expuestos vs. 1 con GitHub App scoped"). | 3 |
| **ADR** | Falta o es un bullet list. | Formato Nygard presente pero sin alternativas rechazadas. | ADR completo con contexto, decisión, consecuencias, alternativas rechazadas. | Lo anterior + revisión de cuándo revisar la decisión y métrica para hacerlo. | 2 |
| **Diseño de auth y supply chain** | PAT classic en secrets, sin firmas, sin Dependabot. | OIDC presente pero sin trust policy correcto (sub claim ancho). | OIDC + sub claim por rama/environment + firmas + Dependabot + secret scanning. | Lo anterior + attestations SLSA verificadas por el deployer, no solo generadas. | 3 |
| **Modelo de amenaza** | Ausente o genérico ("hackers"). | 3 amenazas listadas sin mapeo a controles. | 3 amenazas priorizadas + mapeo 1:1 a controles. | Lo anterior + 1 control explícitamente **no** adoptado con justificación de costo/beneficio. | 2 |

**Total AR:** 25 pts (normalizado).

### 5.3 Rúbrica del bloque conceptual (Q1–Q8)

Cada pregunta tiene su peso en §1. Por pregunta:

| Nivel | Descriptor |
|-------|------------|
| Insuficiente (0 pts) | No responde, responde una pregunta distinta, o afirma algo demostrablemente falso. |
| Básico (0.5× peso) | Responde parcialmente, nombra el concepto pero no el mecanismo o el *por qué*. |
| Competente (0.8× peso) | Responde con el mecanismo correcto; faltan matices secundarios o un ejemplo. |
| Experto (1.0× peso) | Responde con mecanismo + ejemplo concreto + explicita límites de la respuesta. |

### 5.4 Umbral y bandas

- **Insuficiente:** 0–49% → no aprueba.
- **Básico:** 50–69% → no certifica; feedback dirigido + repetición parcial.
- **Competente (aprueba):** 70–84% → certifica.
- **Experto:** 85–100% → certifica con distinción.

Dos correctores independientes deben coincidir ±5 pts; si no, tercer corrector.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo — preguntas conceptuales

#### Q1
- **(a)** `--force-with-lease` compara el ref remoto esperado contra el ref remoto real **antes** de sobreescribir. Si alguien pusheó en el ínterin (p. ej. otro reviewer rebasó y pusheó), el push se rechaza y evitas destruir sus commits. `--force` ciego los pisa. El modo de falla concreto: **race condition multi-colaborador** sobre la misma rama de PR.
- **(b)** Defendible: rama de autor único, aún no mergeada, para limpiar historia antes del merge. Abuso: rama compartida con commits de otros, o rama ya mergeada (reescribirla afecta a todo el que la haya basado localmente). Criterio objetivo: **"solo yo soy el único autor y el único con copia local reciente"**.
- *Parcial*: menciona `--force-with-lease` sin el mecanismo del ref expected.
- *Red flag*: recomienda `--force` como alternativa equivalente.

#### Q2
- **(a)** `amend` sin tocar `a.txt`: **mismo blob**, **mismo tree**, **nuevo commit** (hash distinto por mensaje). Padre = padre del commit original.
- **(b)** `cherry-pick`: **nuevo blob** para `b.txt`, **nuevo tree** (ahora incluye `b.txt`), **nuevo commit** cuyo padre es HEAD actual (no el padre original de `C'`).
- **(c)** `rebase`: **mismo blob** `a.txt` (contenido idéntico), **nuevo tree** si la base contiene otros archivos distintos, **nuevo commit** con padre = nueva base. Hash cambia aunque el diff sea el mismo.
- *Puntos clave*: deduplicación por contenido (mismo contenido ⇒ mismo blob), árbol como snapshot completo, commit como "árbol + padres + metadata".
- *Parcial*: dice "crea un commit nuevo" sin distinguir blob/tree.

#### Q3
- **(a)** `git reflog` (local) y `git reflog <branch>` si el reset tocó una rama con nombre. Nunca `git gc` manual ni `git reset` adicional.
- **(b)** `git gc` corre automáticamente cuando `gc.auto` acumula objetos sueltos o reflog expira. Defaults: `gc.reflogExpire=90 days`, `gc.reflogExpireUnreachable=30 days`. A 8 días los objetos huérfanos aún deben estar presentes salvo que corrieron `gc --prune=now` o `reflog expire --expire=now --all`.
- **(c)** Imposible si: (i) corrieron `git gc --prune=now`, (ii) clonaron el repo descartando el reflog, (iii) `gc.reflogExpireUnreachable` fue bajado agresivamente.
- *Red flag*: propone recuperar desde el remoto (los commits nunca se pushearon, según enunciado) → no leyó el enunciado.

#### Q4
- **A (squash-only):** falla cuando necesitas **bisect fino** dentro de una feature grande; cada commit squasheado es un blob monolítico, bisect te apunta al PR entero pero no al cambio ofensor dentro. También: perder la atribución de cambios individuales en auditoría regulatoria.
- **B (merge commit obligatorio):** falla cuando `git log main` se vuelve ilegible y bisect debe navegar merges; `git log --first-parent main` ayuda pero no si la gente mergeó main *dentro* de la feature. Pregunta que no responde: "¿qué entró en el release de ayer?" sin tooling.
- *Parcial*: generalidades sobre "pierde contexto" sin pregunta concreta.

#### Q5
- **(a)** No en el pre-commit cliente: suite completa de `pytest` (lento, matará adopción; el cliente lo saltará con `--no-verify`). Verificación de licencias de dependencias (mejor en CI con base de datos actualizada).
- **(b)** En servidor (Ruleset required status check o pre-receive en Enterprise): verificación de secretos (push protection de GitHub), firma de commits, Conventional Commits si es política, tests pasando en CI. Un hook cliente es "cortesía"; el control autoritativo vive en el servidor porque `--no-verify` existe.
- **(c)** GitHub-hosted: no tienes `pre-receive`, tu única palanca son Rulesets + required status checks. Enterprise self-hosted: puedes añadir `pre-receive` para bloquear incluso antes del push aceptado.
- *Red flag*: propone pre-commit como único control de seguridad.

#### Q6
- **(a-i)** Rama en otro repo de la org: **GitHub App** con permisos finos al repo destino, instalada en la org, token de instalación de corta vida. Alternativa aceptable: fine-grained PAT scoped al repo, pero con rotación manual.
- **(a-ii)** AWS: **OIDC federation** (OIDC trust policy en IAM con `sub` claim restringido a `repo:org/repo:ref:refs/heads/main` o environment específico). Sin credenciales de larga vida.
- **(b)** PAT classic: (i) alcance mínimo = user-wide, cualquier compromiso filtra TODOS los repos del usuario incluyendo privados personales. (ii) sin expiración obligatoria y sin binding a repo/environment → rotación olvidable. Incidente concreto: un contributor sale del equipo, su PAT sigue activo en el secret del repo hasta que alguien lo note.
- *Red flag*: propone almacenar credenciales AWS largas como secret en lugar de OIDC.

#### Q7
- **(a)** "Verified" ⇒ el commit fue firmado con una clave que GitHub reconoce como asociada a esa cuenta. **No** garantiza: que esa cuenta no esté comprometida, que el autor haya revisado el diff, que el código sea seguro, ni que la clave privada no esté filtrada. Ataque no detectado: atacante con la clave privada firma commits maliciosos; aparecerán "Verified".
- **(b)** Attestation SLSA de build-provenance: atestigua **que el artefacto X se construyó en el workflow Y, con el ref Z, en el runner W, con esos inputs**. **No** protege contra maintainer malicioso que pushea código malicioso al repo (el build será "legítimamente" malicioso con attestation válida). Protege contra: artefactos subidos manualmente, builds en runners no autorizados, confusión de origen.
- *Red flag*: dice que attestation garantiza que el código es seguro.

#### Q8
- **(a) bisect** si tienes un comando/predicado determinista (incluso manual con `git bisect good/bad`); aporta evidencia **temporal** (en qué commit entre dos puntos). **Pickaxe `-S`/`-G`** si sabes **qué cadena o patrón** cambió; aporta evidencia **semántica** (qué commit tocó esa expresión).
- Para tax function con un dato manual reproducible: bisect con `--run` encapsulando el caso.
- **(b)** Pickaxe sería mejor si el bug fuera "en algún momento se eliminó la validación de X" y supieras exactamente qué línea existió y dejó de existir; bisect sería innecesariamente caro.

### 6.2 Guía de corrección — OP

- **Solución de referencia:** la actividad `courses/git-and-github/06-rebase-vs-merge-and-interactive/activities/01-squash-and-reorder/solution/` contiene un `solve.sh` canónico (usa `GIT_SEQUENCE_EDITOR` + `GIT_EDITOR`). No se la des al estudiante.
- **Errores comunes:**
  - `pick` → `fixup` sin reordenar: header de licencia queda en el commit de tests. **Validate.sh detecta esto (scope check).** Punteo: Básico.
  - Olvidar `reword`: subjects quedan como `wip` / `add tests`. Punteo: Insuficiente en correctness.
  - `squash` en vez de `fixup`: funcional, pero el mensaje combinado contiene fragmentos ("wip\n\ntypo\n\n…"). Puntúa Competente si el subject final es correcto, no Experto.
  - Resuelve con `git reset --soft` + recommit: válido operativamente, pero no demuestra la competencia C3 (rebase interactivo). **Puntúa Básico** y pídele que lo repita con `rebase -i` en la defensa live.
- **Señales de "respondió sin entender":**
  - Copia-pega del README de la actividad original. Preguntar en live: "¿qué pasa si cambias el orden de los `fixup`?".
  - No puede explicar por qué el hash de los commits finales es distinto al de los sucios.
  - Afirma que `--amend` modifica el commit — señal clara de que no interiorizó inmutabilidad.

### 6.3 Guía de corrección — AR

- **Solución canónica aceptable:**
  - Workflow: trunk-based con ramas efímeras (<48h).
  - Merge: squash-and-merge (historia lineal auditable + bisect por PR aceptable para 10–20 deploys/semana).
  - Rulesets en `main`: required PR, required review 1 (CODEOWNERS cuando toca `infra/` o `security/`), required status checks (lint, test, secret-scan, codeql), required signed commits, bloquear force push, bloquear deleción, dismiss stale reviews on new push.
  - Environments: `prod` con required reviewers (compliance officer + senior) y wait timer 10 min.
  - Auth GHA→AWS: OIDC federation, trust policy con `sub` restringido a `repo:org/repo:environment:prod` para prod, `repo:org/repo:ref:refs/heads/main` para staging.
  - Supply chain priorizado: (1) push protection + secret scanning (barato, enorme ROI), (2) Dependabot security updates (automático), (3) CodeQL en PR, (4) attestations SLSA verificadas por el deployer AWS vía Sigstore cosign.
- **Alternativas aceptables:** GitHub Flow en vez de trunk-based si argumentan < 5 deploys/día. GitFlow **no** es aceptable para 10–20 deploys/semana — señal de que no leyó restricciones.
- **Red flags:**
  - PAT classic como secret del repo.
  - OIDC trust policy con `sub` = `repo:org/*` o sin claim condition.
  - `cluster-admin` o IAM role con `*:*` para el deployer.
  - "No necesitamos CODEOWNERS porque confiamos en el equipo" (contradice SOC 2).
  - Firma de commits como único control de supply chain (no cubre dependencias).
  - Bypass de Rulesets a todo el equipo "por si acaso".
  - Secretos reales en el ADR o ejemplos.
- **Señales de "respondió sin entender":**
  - Enumera controles sin priorizar ni mapear a amenazas.
  - No menciona ni una vez "blast radius" aunque la rúbrica lo pide.
  - ADR sin alternativas rechazadas.

### 6.4 Red flags transversales (invalidan la respuesta)

Patrones demostrables que, si aparecen, bajan automáticamente a **Insuficiente** la sección afectada:

- Secretos reales (tokens, llaves privadas, passwords) en cualquier artefacto entregado.
- `git push --force` recomendado sobre `main` o rama protegida.
- `curl https://... | bash` desde fuente no verificada en el `solve.sh` o hooks.
- IAM/role `cluster-admin` o `AdministratorAccess` sin justificación explícita.
- PAT classic almacenado como secret cuando OIDC es viable (en AR).
- Afirmar que una firma "Verified" garantiza que el código es seguro.
- `--no-verify` como estrategia recomendada para saltar hooks.
- Attestation SLSA presentada como protección contra maintainer malicioso.

### 6.5 Preguntas de seguimiento (live defense, 30 min)

Elige 3–5 según respuestas:

1. **(OP)** Me enseñas tu rebase: ¿qué pasa si introduzco un conflicto artificial entre los commits `wip` y `oops forgot header`? Resuélvelo ahora. — *distingue memorización del flujo vs. comprensión del 3-way merge.*
2. **(Q2)** Si hago `git cat-file -p HEAD` del commit `feat(payments)...` final, ¿qué veo? Dibuja el objeto en pizarra. — *valida C2 en vivo.*
3. **(AR)** Tu diseño incluye OIDC. Diseña el `sub` claim exacto para que `prod` solo pueda ser desplegado desde la rama `main` protegida con approval del environment. ¿Qué pasa si olvidas el `environment:prod` en el claim? — *distingue "sabe OIDC existe" de "sabe el trust policy".*
4. **(Q4/AR)** Si mañana tu CFO exige "quiero saber qué commits entraron en el release de ayer y quién los aprobó", ¿cómo responde tu diseño? ¿Hay huecos? — *valida auditoría end-to-end.*
5. **(Q3)** Simulemos: tu compañero ya corrió `git gc --prune=now`. ¿Qué dices? ¿Hay algún truco? — *valida que entiende los límites, no solo el happy path.*

---

## Anexos

- `competency-matrix.yaml`: versión estructurada de §1.
- `operative/starter/build-messy-branch.sh`: constructor del repo del ejercicio.
- `operative/tests/validate.sh`: validador local (gracefully skip si Git < 2.30 o `python3` ausente).
- `architectural/scenario.md`: enunciado largo del ejercicio arquitectónico con restricciones completas.
