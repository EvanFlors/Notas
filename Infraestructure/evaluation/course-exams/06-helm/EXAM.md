# Examen de certificación — Curso Helm

- **Curso:** `helm` (ver `courses/helm/ROADMAP.md`).
- **Nivel:** intermedio-avanzado. Cubre `helm-03` → `helm-10` con base en
  `helm-01..02`.
- **Dimensiones:** todas (conceptual + operativa + arquitectónica).
- **Duración:** 90–120 minutos. Reparto sugerido: 25 min conceptual, 50 min
  operativa, 35 min arquitectónica, 10 min de holgura/revisión.
- **Umbral de aprobación:** 70% ponderado. **Además**, aprobar requiere no
  disparar ninguna *red flag* (ver §6).
- **Modalidad:** take-home escrito + revisión live de 15 min para preguntas
  de seguimiento (§6). Entorno virtualizado con `helm` v3.14+ local
  (sin cluster).
- **Materiales:** `operative/` y `architectural/scenario.md` adjuntos.
  Permitido consultar `helm --help`, `helm show`, docs oficiales. **No**
  permitido copiar un chart publicado y renombrarlo (red flag).

> **SKIP operativo.** Si en el entorno no hay `helm` disponible y no se
> puede instalar en ~10 min, se omite el ejercicio operativo y el peso se
> rebalancea 50/50 entre conceptual y arquitectónica. Documentarlo en la
> hoja de corrección.

---

## 1. Matriz de competencias evaluadas

Fuente: `courses/helm/ROADMAP.md` (secciones "Competencias" por módulo).
Matriz completa en `competency-matrix.yaml`.

| ID  | Competencia (verbo + resultado observable) | Dimensión | Peso | Evaluada en |
|-----|---------------------------------------------|-----------|------|-------------|
| C1  | Explicar `values.yaml` como API del chart y `helm upgrade --install` como idiom idempotente; razonar dónde vive el estado del release. | Conceptual | 6 | Q1, Q2 |
| C2  | Diseñar anatomía de chart v2 y justificar política de `crds/` (no se upgradean). | Conceptual + Arquitectónica | 7 | Q3, OP-task-1, ARCH |
| C3  | Distinguir `template` de `include`; usar `required`/`default` para proteger el contrato de inputs. | Conceptual + Operativa | 8 | Q4, OP-task-2 |
| C4  | Diagnosticar errores de render (indent, null, scoping) desde el output de `helm template --debug`. | Operativa | 8 | OP-task-3 |
| C5  | Predecir el valor final tras `defaults → -f (en orden) → --set`; manejar scoping de subcharts, `global:` e `import-values`. | Conceptual + Operativa | 7 | Q5, OP-task-4 |
| C6  | Elegir umbrella vs chart-por-app según acoplamiento de lifecycle; defender `Chart.lock`. | Conceptual + Arquitectónica | 6 | Q6, ARCH |
| C7  | Elegir hook vs initContainer vs operator; `--atomic` + `--wait` como default en CD; `helm test` para smoke. | Conceptual + Operativa | 8 | Q7, OP-task-5 |
| C8  | Diferenciar `.prov`+GPG de cosign+OCI; publicar firmado a GHCR y verificar. | Conceptual + Arquitectónica | 7 | Q8, ARCH |
| C9  | Pipeline de validación por capas (lint → template → unittest → `ct install`) y matriz de versiones de K8s. | Operativa + Arquitectónica | 7 | Q9, OP-task-6 |
| C10 | Decidir límite Helm vs Kustomize vs operador; library/platform chart; integración con Argo CD y qué rompe (hooks). | Arquitectónica | 10 | Q10, ARCH |
| C11 | Reconocer anti-patrones de release (secretos en values, hooks mal usados, `--force` como escape). | Conceptual | 5 | Q11 |
| C12 | Diseñar contrato multi-entorno (`values-dev/stg/prod.yaml` + `values.schema.json`) y SemVer de chart interno. | Arquitectónica + Operativa | 6 | OP-task-4, ARCH |

**Reparto por dimensión:** conceptual 35% · operativa 40% · arquitectónica 25%.

---

## 2. Preguntas conceptuales

11 preguntas de respuesta corta/explicación. **Evitar múltiple opción** en
general; sólo se usa en Q5 para distinguir conceptos próximos (precedencia).

### Q1 — Estado del release (C1)

> Describes a un colega que acaba de borrar, por error y a mano, el Secret
> `sh.helm.release.v1.myapp.v3` del namespace `prod`. ¿Qué consecuencias
> concretas tiene en el próximo `helm upgrade --install myapp ./chart` y
> por qué?

**Debe aparecer:**
- El estado de las revisiones de Helm vive en Secrets del namespace del
  release (por default), nombrados `sh.helm.release.v1.<name>.v<rev>`.
- Borrar la revisión 3 hace que `helm history` deje de verla; si era la
  "deployed", el próximo `upgrade` puede fallar al comparar o tratar la
  release como corrupta/parcial. `helm rollback` a la 3 ya no es posible.
- Los **objetos de K8s** desplegados **siguen vivos** (no son parte del
  Secret); por eso el idiom `helm upgrade --install` puede re-tomar
  ownership si no se borraron todas las revisiones.

**Variantes aceptables:** mencionar `--take-ownership`, mencionar que en
Helm 2 el estado vivía en Tiller (ConfigMaps en `kube-system`).

**Parcialmente correcto:** decir "no pasa nada porque los Pods siguen" sin
hablar del historial. Falta: por qué CD futuros se rompen.

### Q2 — `helm upgrade --install` idempotente (C1)

> ¿Por qué `helm upgrade --install` se recomienda sobre `helm install` en
> un pipeline CD? Da un escenario concreto donde `helm install` solo
> rompería un deploy que `upgrade --install` sí termina correctamente.

**Debe aparecer:** idempotencia frente a reintentos de job de CD; si el
release ya existe, `install` falla con `cannot re-use a name`, mientras que
`upgrade --install` crea la primera o actualiza las siguientes. Escenario:
reintento manual de un pipeline que ya ejecutó la primera mitad.

### Q3 — CRDs en `crds/` (C2)

> ¿Por qué Helm instala las CRDs de `crds/` en `helm install` pero **no**
> las actualiza en `helm upgrade`? ¿Qué estrategia usarías tú para una
> CRD que necesita evolucionar entre versiones del chart y por qué no
> ponerla en `templates/`?

**Debe aparecer:** evita que una release rompa a *otros* consumidores de
la misma CRD (las CRDs son cluster-scoped y compartidas); modificar/eliminar
una CRD puede borrar recursos existentes de otros equipos.
Estrategia aceptable: chart dedicado de CRDs versionado aparte, o un
operador que gestione su propia CRD, o un `pre-upgrade` **documentado**
con control de versión y rollback. Poner la CRD en `templates/` la hace
"ownership del release" y la borra con `helm uninstall` — peligroso.

**Parcialmente correcto:** "porque es inseguro" sin explicar por qué.
Falta: la razón concreta (cluster-scope + consumidores externos).

### Q4 — `template` vs `include` (C3)

> ¿Por qué este fragmento no compila?
>
> ```yaml
> labels:
>   {{- template "mychart.labels" . | nindent 4 }}
> ```
>
> ¿Qué hace exactamente `include` que `template` no hace, y cuándo
> usarías `template`?

**Debe aparecer:** `template` es una **acción**, no una función; no
retorna un valor pipeable, escribe directo al output stream, por eso
`| nindent` no tiene qué consumir y Go templates falla. `include` es
función: retorna string, se puede pipear a `nindent`, `trim`, `quote`,
`b64enc`. `template` queda razonable cuando no necesitas transformar el
output (y no está en una cadena `|`).

### Q5 — Precedencia de values (C5)

> Dadas estas invocaciones **todas** sobre el mismo chart (default
> `replicaCount: 2`):
>
> ```bash
> helm upgrade --install app ./chart \
>   -f values-base.yaml \      # replicaCount: 3
>   -f values-prod.yaml \      # replicaCount: 5
>   --set replicaCount=4 \
>   --set-string replicaCount=7
> ```
>
> ¿Cuál es `replicaCount` final? Explica la regla aplicada y qué diferencia
> introduce `--set-string` respecto a `--set` cuando el valor **no** es un
> número.

**Debe aparecer:** regla "mayor precedencia gana" en orden
`defaults < -f (en el orden en que se pasan) < --set`. Entre varios `--set`
del mismo path, gana el **último**. Resultado: `replicaCount=7` (como
string `"7"` por `--set-string`, lo que puede romper el schema si éste
exige integer). Mencionar que si el chart tiene `values.schema.json`
exigiendo `integer`, `--set-string replicaCount=7` **falla el schema**.

**Parcialmente correcto:** responder 5 (olvidar `--set`), responder 4
(olvidar que gana el último `--set`).

### Q6 — Umbrella vs chart-por-app (C6)

> Un equipo propone un umbrella chart que agrupa 8 microservicios de 3
> equipos distintos para "simplificar el deploy a prod". Da **dos**
> razones concretas por las que esto puede ser una mala idea y **una**
> situación donde sí es apropiado. ¿Qué papel juega `Chart.lock`?

**Debe aparecer:** acoplamiento de lifecycle (una migración rota de un
servicio bloquea el deploy de los otros 7); una sola release ⇒ un solo
`helm rollback` revierte todo; dificulta ownership por equipo y RBAC a
nivel release. Apropiado para dev local (stack de desarrollo reproducible)
o para componentes que **sí** comparten lifecycle (DB + migrations + app
de un mismo equipo). `Chart.lock` fija versiones efectivas de las
dependencias → dos checkouts del repo producen el mismo render.

### Q7 — Hook vs initContainer vs operator (C7)

> Para una migración de schema de PostgreSQL antes de desplegar una nueva
> versión de la app, ¿elegirías `helm` hook `pre-upgrade`, `initContainer`
> en el Deployment, o un operador? Da **un criterio objetivo** por opción
> y defiende tu elección en el contexto donde el deploy lo dispara
> **Argo CD**.

**Debe aparecer:**
- `pre-upgrade` hook: corre una vez por release, aislado, con weight y
  delete-policy — pero **Argo CD renderiza** el chart y aplica manifests;
  algunos hooks (`pre-install`, `pre-upgrade`, `post-*`) se traducen a
  `argocd.argoproj.io/hook` y **cambian su semántica**: no es Helm quien
  los corre.
- `initContainer`: corre **cada vez que el Pod arranca** → migración
  idempotente obligatoria; mal para migraciones destructivas o largas.
- Operador: encapsula el flujo (snapshot + migrate + verify + rollback);
  mejor para apps con dueño single y migraciones complejas; más caro
  operacionalmente.

Elección razonable con Argo CD: `Job` nativo con
`argocd.argoproj.io/sync-wave: "-1"` (equivalente portable) o hook de
Argo, no hook de Helm; o migrar a operador si el equipo ya mantiene uno.

### Q8 — `.prov`+GPG vs cosign+OCI (C8)

> Comparas firmar un chart con `helm package --sign` (`.prov` + llave GPG)
> contra firmar con cosign+OCI (keyless, OIDC). ¿Qué garantiza cada uno y
> cuándo elegirías el modelo clásico sobre cosign?

**Debe aparecer:** `.prov` + GPG prueba integridad y origen contra una
**llave que tú administras** (web of trust / rotación manual); funciona
también con repos HTTP `index.yaml`; es portable sin OCI. cosign keyless
+ OIDC ata la firma a una **identidad de workload** (GitHub Actions,
Google, etc.) con transparency log (Rekor), elimina gestión de llaves pero
exige confiar en el emisor OIDC y en el log. Elegir clásico: entornos
air-gapped sin acceso a Fulcio/Rekor, o políticas que exigen HSM/GPG
propio. Elegir cosign+OCI: equipos cloud-native que ya emiten identidades
OIDC y quieren eliminar llaves estáticas.

### Q9 — Pipeline de validación por capas (C9)

> Diseña 4 capas de validación para un chart interno antes de publicarlo
> a GHCR OCI. Para cada capa indica: qué atrapa que las anteriores no
> atrapan.

**Debe aparecer:** 1) `helm lint`: errores sintácticos + buenas
prácticas. 2) `helm template --debug` con varios `values-*.yaml`:
atrapa errores de render en edge cases de values (null, listas vacías).
3) `helm-unittest`: asserts sobre manifests renderizados (p. ej. "si
`persistence.enabled=false`, no debe haber `kind: PersistentVolumeClaim`")
— cubre lógica condicional sin cluster. 4) `ct install` en `kind` sobre
matriz de versiones de K8s: atrapa que las API versions, discovery y
admission realmente aceptan el output.

### Q10 — Límite Helm vs Kustomize vs operador (C10)

> Un servicio stateful requiere orquestar: provisioning de volúmenes,
> snapshot pre-upgrade, migración de schema, failover de réplicas y
> self-healing. ¿Lo empaquetas con Helm, lo mueves a Kustomize, o le
> escribes un operador? Da **dos criterios objetivos** que justifiquen tu
> decisión y explica qué le pedirías ceder al equipo si eligieses operador.

**Debe aparecer:** Helm/Kustomize son "renderers": generan manifests
estáticos; no observan ni reaccionan. Un flujo con decisiones condicionadas
al estado del cluster en runtime (snapshot, failover) exige un **control
loop** → operador. Criterios: necesidad de reaccionar a estado observado
en runtime; complejidad del flujo que no es "aplicar YAML" sino "si X
observa Y, hacer Z". Cesión: el operador se vuelve el ownership del
servicio; el equipo asume mantener controller, CRDs y upgrade path.

### Q11 — Anti-patrones de release (C11)

> Describe **tres** anti-patrones que harías fallar en una code review de
> un chart Helm y explica el daño concreto de cada uno.

**Esperado (≥ 3 de):** secretos en claro en `values.yaml`; `--force` o
`uninstall && install` como "arreglo" de un upgrade fallido;
`appVersion` desalineado con la imagen desplegada; CRDs en `templates/`;
hook `pre-upgrade` que ejecuta destrucción sin backup ni `--atomic`;
umbrella chart en prod acoplando lifecycles de equipos; chart publicado a
HTTP sin firma; `install --verify` deshabilitado para "destrabar" el
pipeline.

---

## 3. Ejercicio operativo

**Ubicación:** `operative/README.md` (6 tareas, OP-task-1 a OP-task-6).

Resumen de alto nivel (detalles, materiales y validación automática en el
README):

1. **OP-task-1** — Completar `_helpers.tpl` (labels estándar; justificar por
   qué `selectorLabels` **no** incluye versión).
2. **OP-task-2** — Reemplazar `template … | nindent` por `include`.
3. **OP-task-3** — Diagnosticar y corregir render con `helm template
   --debug`: bugs de whitespace, `image.tag` vacío, `ingress.host` null.
4. **OP-task-4** — `values.schema.json` + predicción de precedencia
   multi-entorno (dev/prod + `--set`).
5. **OP-task-5** — Hook `pre-upgrade` de migración con weight,
   delete-policy y condicional; justificar `--atomic --wait` como default.
6. **OP-task-6** — Script `validate.sh` reproducible (lint + template +
   greps de aserción); describir qué atrapan las capas que no caben en
   el examen (`helm-unittest`, `ct install`).

**Validación automática del instructor** (resumen; ver `operative/README.md`):

```bash
helm lint ./entrega/fastapi-app -f values-dev.yaml
helm lint ./entrega/fastapi-app -f values-prod.yaml
helm template fastapi ./entrega/fastapi-app -f values-prod.yaml \
  | yq '[.] | map(select(.kind == "Job")) | length' | grep -q '^1$'
helm template fastapi ./entrega/fastapi-app -f values-dev.yaml \
  | grep -q 'app.kubernetes.io/version'
```

**Entregables:** chart empaquetado (`helm package`, bump obligatorio),
renders de dev y prod, `values.schema.json`, `validate.sh` con `exit 0`,
notas ≤ 1 página con justificaciones.

---

## 4. Ejercicio arquitectónico

**Ubicación:** `architectural/scenario.md`.

Escenario: diseñar la **plataforma interna de charts** para ~40
microservicios, 6 equipos, 1 clúster EKS multi-tenant, GitOps con Argo CD,
compliance a 3 meses (firma, pin por digest, air-gapped para 1 cliente).

El estudiante decide y defiende con ADR:

- **D1** Modelo de chart (library chart `platform-lib` vs golden app chart
  vs combinado) + política de umbrella.
- **D2** Contrato multi-entorno (`values*.yaml`, `values.schema.json`,
  `global:`, `import-values`) y manejo de secretos **fuera** de values.
- **D3** Distribución y firma: HTTP vs OCI, `.prov`+GPG vs cosign+OCI,
  pin por SemVer vs digest, estrategia air-gapped.
- **D4** Integración Argo CD: hooks de Helm vs sync-waves; límite con
  Kustomize (post-renderer) y con operador.
- **D5** Gobernanza SemVer y detección de deriva (vendorizar vs consumir).

**Entregables:** ADR 1–2 páginas, diagrama Mermaid/ASCII, tabla de ≥ 5
riesgos con mitigación concreta, snippets reales (`Chart.yaml` del
library chart, `Application` de Argo CD con `targetRevision` fijado,
comando `cosign verify` del pipeline de admisión).

---

## 5. Rúbricas (4 niveles)

Umbral de aprobación global: **70%**. Umbral por bloque:
≥ 50% conceptual, ≥ 60% operativa, ≥ 50% arquitectónica. **Red flag
dispara reprobación independientemente del puntaje** (ver §6).

### 5.1 Rúbrica — Preguntas conceptuales (35% del total)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Precisión técnica | Error conceptual que invalida la respuesta (p. ej. "Tiller sigue en Helm 3"). | Correcto en lo superficial, impreciso en términos (confunde `template`/`include`, "revisión" con "release"). | Correcto, usa términos del dominio con precisión. | Correcto + distingue casos límite (p. ej. `--set-string` vs `--set` con schema). |
| Razonamiento ("por qué") | Responde "qué" o cita el comando sin explicar la razón. | Razón genérica ("por seguridad"). | Razón específica y vinculada al mecanismo (cluster-scope de CRDs, idempotencia frente a reintento). | Razón + contraejemplo donde la regla no aplica. |
| Economía de la respuesta | Divaga o cita docs sin responder. | Responde pero sobra 50%+. | Responde en lo pedido con 1 ejemplo. | Responde en 3–5 líneas, con precisión quirúrgica. |

Cada pregunta se puntúa 0–3 en cada criterio; nota de la pregunta = media
redondeada. Peso de cada pregunta = peso de la competencia que evalúa
(ver matriz).

### 5.2 Rúbrica — Ejercicio operativo (40% del total)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Correctness (`helm lint` + `helm template` pasan en dev y prod) | Falla lint o falla render en algún entorno. | Pasa lint, falla render en 1 entorno. | Pasa lint y render en ambos entornos. | Idem + `values.schema.json` **rechaza** inputs inválidos documentados. |
| Completitud (6 tareas) | ≤ 2 tareas resueltas. | 3–4 tareas. | 5 tareas. | 6 tareas + script `validate.sh` reproducible con `exit 0`. |
| Diagnóstico (OP-task-3) | No identifica bugs; "arregla" copiando otra solución. | Identifica 1 bug, arregla por tanteo. | Identifica los 3 bugs y explica causa raíz (whitespace, default, null). | Idem + propone cómo el schema o `required` habría atrapado el bug en PR. |
| Seguridad / contrato | Secretos en values, chart sin schema, `host: null` en prod. | Schema parcial, hook sin delete-policy. | Schema cubre lo requerido, hook con weight y delete-policy correctos. | Idem + justifica `--atomic --wait` y explica qué daño concreto evita. |
| Mantenibilidad / idiomático | Templates copy-paste, labels inconsistentes. | Usa helpers pero sin convención estándar. | Labels K8s estándar; `include` donde corresponde; sin lógica duplicada. | Idem + `_helpers.tpl` cohesivo y chart "podable" (quita lo que no usa). |
| Justificación escrita | Ausente o receta sin razón. | Razones genéricas. | Razones específicas por tarea. | Razones + trade-off descartado por qué. |

### 5.3 Rúbrica — Ejercicio arquitectónico (25% del total)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---|---|---|---|---|
| Decisión fundamentada | No elige; enumera opciones sin tomar postura. | Elige, no justifica con trade-offs. | Elige con 2+ trade-offs explícitos. | Elige y descarta alternativas con el **por qué** del descarte. |
| Cobertura D1–D5 | ≤ 2 bloques. | 3 bloques. | 4 bloques. | 5 bloques + implicaciones cruzadas (p. ej. D3 afecta D4). |
| Realismo operativo | Diseño que no sobrevive a un fallo (sin rollback, sin mitigación). | Rollback mencionado, no probado. | Flujo de rollback diseñado + ownership claro. | Idem + ejercicio de "qué pasa si cae X" (chaos mental). |
| Snippets reales | Pseudocódigo o `TODO`. | Snippets parciales. | 3 snippets concretos y correctos. | Idem + alineados con los nombres y versiones del resto del diseño. |
| Riesgos y mitigación | Lista 2–3 riesgos genéricos ("falla el deploy"). | 5+ riesgos pero mitigación = "monitoreo". | 5+ riesgos con mitigación concreta (circuit breaker, canario, pin). | Idem + prioriza por impacto × probabilidad. |

### 5.4 Puntaje final

```
nota_total = 0.35 * nota_conceptual + 0.40 * nota_operativa + 0.25 * nota_arquitectonica
```

Umbral: `nota_total ≥ 0.70` **AND** sin red flags **AND** mínimos por
bloque cumplidos. Dos correctores independientes deberían llegar al mismo
puntaje ±1 por criterio.

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo

Ver §2 bajo cada pregunta: "Debe aparecer" (puntos clave obligatorios) y
"Parcialmente correcto" (patrones típicos de respuesta a medias).
Para el operativo, la solución de referencia es el chart `fastapi-app`
corregido descrito en `operative/README.md`; el instructor debe mantener
una versión *keyed* privada (no publicarla con el starter).

### 6.2 Errores comunes esperados

- **Confundir `template` con `include`.** El estudiante arregla el bug
  cambiando la indentación en vez de la función. Puntuar como "Básico" en
  Diagnóstico y pedir en live que explique por qué `nindent` no recibe
  nada de `template`.
- **"Arreglar" el host null con un string vacío** en vez de `required`
  o condicional. Pedir en live: "¿qué pasa si el chart se instala en un
  cluster sin ingress-controller?".
- **Schema demasiado laxo** (`"additionalProperties": true` + ningún
  `required`). El schema debe **rechazar** entradas inválidas; probar con
  `--set replicaCount=0`.
- **Hook sin `delete-policy`** → Jobs sucios tras el upgrade siguiente.
  Puntuar "Básico" en Seguridad/contrato.
- **Umbrella chart en el ADR** justificado solo con "simplicidad del
  pipeline" sin tocar acoplamiento de lifecycle: pedir en live el
  escenario "equipo A rompe migraciones, equipo B necesita hotfix".
- **ADR que elige cosign+OCI por "moderno"** sin tocar air-gapped: red
  flag conceptual si el escenario lo exige explícitamente.

### 6.3 Señales de "respondió sin entender"

- Copió-pegó un `_helpers.tpl` de un chart de internet sin ajustar el
  nombre (`<chart>.fullname` quedó como `nginx.fullname`).
- Cambió nombres de values para que "pase el lint" pero rompió el schema o
  los `-f` de entorno (no corrió `helm template` con los 3 values).
- Define `include` y lo usa en 1 sitio, pero deja `template` en otro.
- En el ADR, lista "pros/cons" simétricos sin tomar decisión → pedir en
  live "¿y tú qué firmas hoy?".
- Resuelve OP-task-5 añadiendo el Job sin la annotation `helm.sh/hook` y
  sin `if .Values.migrations.enabled` → el Job corre siempre y pierde su
  función de pre-upgrade.
- Usa `--set-string replicaCount=7` como "fix" cuando ya añadió schema
  con `integer`.

### 6.4 Red flags (invalidan la entrega aunque el puntaje numérico apruebe)

Ver `competency-matrix.yaml` → `red_flags`. En resumen:

1. **Secretos** (DB_PASSWORD, API_KEY, token de registry) hardcodeados en
   `values.yaml`, templates, `Chart.yaml` o scripts del entregable.
2. **`template` encadenado con `| nindent`** entregado como solución final
   (no compila; evidencia de que no se ejecutó `helm template` sobre el
   entregable).
3. **CRDs en `templates/`** esperando que `helm upgrade` las actualice,
   contra la política explícita de `crds/`.
4. **`--force` o `uninstall && install`** propuesto como solución a un
   upgrade fallido en el ADR o en las notas, sin ADR que lo justifique.
5. **Firma deshabilitada** (`cosign verify --insecure-ignore-tlog`,
   `helm install --verify` quitado) sin justificación de compliance.
6. **Umbrella chart en prod** sin ADR explícito que defienda el
   acoplamiento de lifecycle entre equipos.
7. **`appVersion` desalineado** con la imagen que el Deployment realmente
   despliega en el render de prod del entregable.
8. **Values del subchart modificados** desde el padre por acceso directo
   (`subchart.alguna: x` sin `global:` ni `import-values`) → no funciona
   y evidencia de no haber corrido `helm template`.
9. **Hook `pre-upgrade` destructivo** sin backup previo ni `--atomic`
   documentados.
10. **Repo HTTP sin TLS** o **sin pin** (consumidor con `targetRevision:
    "*"` o rango abierto) en el ADR.
11. **`values.schema.json` ausente** en el chart interno multi-entorno
    (contrato implícito) tras pedírselo explícitamente OP-task-4.
12. **`curl | bash` desde fuente no verificada** dentro de un hook o
    initContainer.

Cualquier red flag → **reprobado**. Documentar cuál y por qué en la hoja
de corrección y ofrecer re-sit de la sección afectada.

### 6.5 Preguntas de seguimiento (evaluación live, 10–15 min)

Diseñadas para distinguir **memorización de comprensión**. Elegir 3–4
según las respuestas débiles del escrito.

- **S1 (C1):** "Si borras *todas* las revisiones del Secret, ¿qué pasa con
  los Pods ya desplegados y qué comando usas para re-adoptarlos?"
  (Buscar: entender que los Pods viven; mención de `--take-ownership`
  o re-apply manual.)
- **S2 (C3):** Mostrar un template con `include "x.labels" .` sin
  `nindent` y preguntar: "¿Por qué este render te mete todo en una sola
  línea? Arréglalo." (Buscar: entender que `include` retorna el string
  tal cual, el `nindent` *añade* las nuevas líneas con indentación.)
- **S3 (C4):** Pasarle 3 líneas de error de `helm template --debug`
  (indentación inconsistente de 3 espacios) y pedir "¿dónde está el bug
  en el helper?". (Buscar: habilidad de leer el output, no de memorizar.)
- **S4 (C5):** "Pasa `-f prod.yaml -f dev.yaml` (en ese orden), ¿gana
  dev o prod?" (Buscar: entender que es por *orden de la línea de
  comandos*, no por el "nombre"; respuesta: gana dev.)
- **S5 (C6):** "Dame un escenario donde `Chart.lock` te salva de un
  rollback en producción." (Buscar: ejemplo concreto con subchart que
  bumpea minor con regresión.)
- **S6 (C7):** "Argo CD renderiza con `helm template`, no corre
  `helm install`. ¿Qué le pasa a tu hook `pre-install` entonces? ¿Y a
  tu `--atomic`?" (Buscar: entender que hooks de Helm se traducen a
  anotaciones Argo y `--atomic` **no existe** en el mundo Argo —
  reemplazo: sync-waves + health checks.)
- **S7 (C8):** "¿Qué pierdes si cosign firma pero Rekor cae?" (Buscar:
  entender el log de transparencia como dependencia externa; opción
  `--tlog-upload=false` + justificación.)
- **S8 (C9):** "¿Por qué `helm-unittest` **no** sustituye a `ct install`?"
  (Buscar: unittest verifica el **render**, no que K8s acepte el output
  con `--validate`.)
- **S9 (C10):** "Si Argo CD rompe tus hooks de Helm, ¿por qué no mudas
  todo a Kustomize?" (Buscar: entender que Kustomize **también** es
  renderer puro y tendría el mismo problema para flujos imperativos;
  la respuesta no es "cambiar de herramienta" sino "cambiar de modelo"
  → nativos K8s + sync-waves u operador.)
- **S10 (C11):** "Tu colega propone `helm upgrade --force` para destrabar
  un deploy. ¿Qué le preguntas antes de aceptarlo?" (Buscar:
  "¿Qué recurso está bloqueado y por qué?"; `--force` recrea recursos
  inmutables perdiendo estado.)

### 6.6 Reparto de tiempo sugerido en corrección

- Lectura y puntuación conceptual: 20 min.
- Validación automática del operativo (`validate.sh` + comandos §3): 10 min.
- Lectura del ADR y revisión de snippets: 20 min.
- Live de seguimiento: 15 min.
- Captura de puntajes y red flags: 5 min.
- **Total:** ~70 min por entrega.

---

## Checklist de calidad del examen (self-check del diseñador)

- [x] Matriz de competencias con pesos (12 competencias; §1 y YAML).
- [x] Preguntas conceptuales son "por qué" / "qué pasaría si" / "cuándo
      preferirías X sobre Y" / "diferencia entre A y B" — no definiciones.
- [x] Ejercicio operativo con validación concreta (`helm lint` +
      `helm template` + greps + `validate.sh`).
- [x] Rúbrica de 4 niveles con descriptores observables por criterio.
- [x] Umbral de aprobación explícito (70% + mínimos por bloque + red flags).
- [x] Duración realista (90–120 min para intermedio-avanzado).
- [x] Preguntas de seguimiento (S1–S10) disponibles para live.
- [x] Red flags demostrables, no juicios de estilo.
- [x] Dimensión `todas`; Spanish prose + English code.
- [x] SKIP operativo documentado para entornos sin `helm`.
- [x] Sin secretos en materiales ni expectativa de secretos en entregables.
