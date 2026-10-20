# Examen de certificación — Curso Jenkins

- **Nivel:** intermedio-avanzado (cubre `jk-03` a `jk-08`, con base implícita en `jk-01..02`).
- **Dimensiones:** `todas` (conceptual, operativa, arquitectónica).
- **Duración:** 90–120 minutos.
- **Umbral de aprobación:** 70% ponderado sobre las tres dimensiones.
- **Entorno de evaluación:** take-home con validación local (no se requiere servidor Jenkins; la validación es estructural sobre `Jenkinsfile` + `jenkins.yaml`).
- **Materiales permitidos:** documentación oficial de Jenkins, JCasC y plugins; prohibido copiar literalmente desde cursos, bootcamps o repos públicos (se detecta en revisión).

> Convención del examen: la **prosa** se responde en español; los **nombres de ficheros, snippets de código, pipelines, YAML y comandos** se escriben en inglés y con los IDs/nombres canónicos (`Jenkinsfile`, `jenkins.yaml`, `withCredentials`, `agent { kubernetes { yaml ... } }`).

---

## Distribución de puntos

| Dimensión       | Peso  | Secciones                 |
|-----------------|-------|---------------------------|
| Conceptual      | 35%   | Preguntas Q1–Q10          |
| Operativa       | 35%   | OP-task-1 + OP-task-2     |
| Arquitectónica  | 30%   | ARCH (escenario + ADR)    |

El examen se aprueba con **≥ 70%** del total ponderado **y** con al menos **50%** en cada dimensión individual (evita que alguien apruebe únicamente por una dimensión).

---

## Sección 1 — Preguntas conceptuales (35%)

Responder en español, con prosa breve y precisa. Cada pregunta vale lo indicado entre paréntesis; el peso relativo se usa para prorratear.

### Q1 (C1) — Declarative vs Scripted vs Freestyle

Un lead de plataforma te dice: "estamos escribiendo todos los pipelines nuevos en Scripted porque Declarative es demasiado restrictivo". ¿Qué le respondes? Enumera **tres garantías concretas** que aporta Declarative Pipeline que Scripted/Freestyle no aportan por defecto, y explica **cuándo sí es legítimo escapar a `script { }`** dentro de un Declarative Pipeline.

### Q2 (C2) — `agent none` a nivel pipeline

¿Por qué, en un pipeline con un gate de aprobación manual (`input`) a mitad del flujo, declarar `agent any` a nivel `pipeline { }` es un anti-patrón, y cómo lo arreglas usando `agent none` + `agent` por stage? Describe **qué recurso del controller se libera** y qué pasa si no lo haces en una organización con 500 pipelines concurrentes.

### Q3 (C3) — Shared Libraries y versionado

¿Qué diferencia conceptual existe entre `@Library('platform-lib')` y `@Library('platform-lib@v1.4.2')` desde el punto de vista de **reproducibilidad de un build de hace seis meses**? ¿Por qué la primera forma es equivalente a `:latest` en una imagen Docker y qué implicaciones tiene para auditoría y rollback?

### Q4 (C4) — Hardening de una Shared Library legacy

Heredas una Shared Library con 40 steps globales (`vars/*.groovy`), sin tests, sin tags, cargada por default (`implicit: true`) desde la rama `master`. Lista **cuatro medidas** de hardening ordenadas por impacto/esfuerzo y justifica el orden. Al menos una debe mencionar `JenkinsPipelineUnit` y otra `CODEOWNERS`/PR obligatorio.

### Q5 (C5) — Agents efímeros K8s vs permanentes

Explica **por qué** un agent efímero en Kubernetes (Pod por build) elimina clases enteras de bug "funcionó ayer, no hoy" que los agents permanentes no eliminan. Da un ejemplo concreto de **contamination** y uno de **privilege leak** entre equipos. ¿Qué equivalente conceptual existe en GitHub Actions (ARC) y en qué se parece/diferencia?

### Q6 (C7) — Jenkins sin JCasC = snowflake

Un compañero afirma: "tengo backup del `JENKINS_HOME`, con eso me basta para reproducir el controller". Explica por qué **no** es suficiente para operación empresarial y qué cinco secciones mínimas debe cubrir `jenkins.yaml` (JCasC) para que un controller sea tratable como cualquier otra app (Git → PR → CI → deploy).

### Q7 (C8) — Pinning y update de plugins

Diseña una **estrategia de upgrade de plugins** en una página. Debe cubrir: criterio para instalar (o no) un plugin nuevo, cómo se pinnea la versión, cada cuánto se actualizan, dónde se prueba antes de prod y cómo se decide un rollback. Justifica por qué "install latest" en el UI no es aceptable en 2026.

### Q8 (C9) — RBAC + script approval

En un Jenkins compartido entre 6 equipos, ¿qué estrategia de autorización usarías y por qué (comparando `Logged-in users can do anything`, `Matrix-based security` y `Role Strategy` con global + project roles)? Explica **para qué sirve** el *in-process script approval* y por qué deshabilitar la Groovy sandbox "porque genera fricción" es un red flag.

### Q9 (C10) — `credentials()` vs `withCredentials` vs OIDC

Diferencia los tres mecanismos (`environment { TOKEN = credentials('id') }`, `withCredentials([usernamePassword(...)]) { }`, OIDC federation al cloud) en términos de: (a) scope del secreto, (b) riesgo de filtrado a logs, (c) rotación. ¿Cuál preferirías para un deploy a AWS desde un pipeline moderno y por qué?

### Q10 (C12) — HA y SPOF del controller

El controller de Jenkins es *single-point-of-failure por diseño* en la edición OSS. ¿Qué significa esto operacionalmente y qué patrón de activo-pasivo se puede implementar sin CloudBees CI? ¿Por qué escalar agents no resuelve la caída del controller y qué métricas vigilarías (nombra tres) para anticipar saturación?

---

## Sección 2 — Ejercicio operativo (35%)

> **No se requiere servidor Jenkins.** La validación es **estructural** sobre los artefactos entregados usando los scripts incluidos en `operative/validate/`.

### Contexto

Eres la nueva persona de plataforma en una empresa que opera un controller Jenkins snowflake (configurado por UI durante años). Tu primera entrega consta de **dos artefactos**:

- **OP-task-1 (C1, C2, C6, C10):** un `Jenkinsfile` **Declarative** del pipeline del servicio `payments-api` que porta un workflow equivalente de GitHub Actions.
- **OP-task-2 (C7, C9):** un `jenkins.yaml` (JCasC) mínimo que reproduce el controller desde cero con hardening baseline.

### Materiales de inicio

Partes del fixture en `operative/starter/`:

- `starter/workflow-reference.yml` — el workflow GHA original (referencia de lo que el pipeline debe hacer).
- `starter/service-context.md` — contexto del servicio `payments-api` (lenguaje, test runner, registry destino).

### Entregables esperados

Entregar en `operative/submission/`:

```
operative/submission/
  Jenkinsfile
  jenkins.yaml
  NOTES.md        # 1 página: decisiones de diseño y trade-offs
```

#### OP-task-1 — `Jenkinsfile` Declarative

Requisitos obligatorios (cada uno es verificado por `validate/check-jenkinsfile.sh`):

1. Comienza con `pipeline {` y declara `agent none` a nivel pipeline.
2. Declara al menos un stage con `agent { kubernetes { yaml ... } }` que incluya **al menos dos containers** (uno `jnlp` y uno de build; p. ej. `maven` o `node`).
3. Define stages mínimos: `Lint`, `Test`, `Build`, `Publish`, `Deploy` (los nombres pueden variar, pero deben aparecer esos cinco pasos conceptuales).
4. Usa `parallel` para correr `Lint` y `Test` en paralelo.
5. Usa `when` para gatear `Deploy` sólo cuando `branch == 'main'`.
6. Usa `post { always { } success { } failure { } }` con al menos `archiveArtifacts` o `junit` en `always`.
7. Introduce un `input` para aprobación manual **antes** de `Deploy` y **sin** mantener un executor ocupado del controller (es decir, el `input` vive en un stage con `agent none` o fuera de un `node { }`).
8. Usa `withCredentials` (o `environment { X = credentials('id') }`) para inyectar credenciales de registry y de deploy. **No** debe aparecer ningún valor literal de token/password.
9. Carga una Shared Library versionada: `@Library('platform-lib@v1.4.2') _` (con pin explícito).

#### OP-task-2 — `jenkins.yaml` (JCasC)

Requisitos obligatorios (verificados por `validate/check-jcasc.sh`):

1. YAML válido (parseable con `yq`/`python -c yaml.safe_load`).
2. Sección `jenkins:` con `securityRealm:` definido (no `local` con admin trivial; LDAP/OIDC/SAML o `local` con usuarios declarados).
3. `authorizationStrategy:` basado en `roleBased` (Role Strategy) **o** `projectMatrix`. Prohibido `loggedInUsersCanDoAnything` y `unsecured`.
4. `remotingSecurity: enabled: true`.
5. Sección `credentials:` referenciando `${...}` desde variables de entorno o `secretText:` con placeholder (p. ej. `${REGISTRY_TOKEN}`). **Ningún valor literal.**
6. Sección `unclassified:` con `globalLibraries:` que declare `platform-lib` con `defaultVersion:` **fijado a un tag/sha**, no a `master`.
7. Sección `jobs:` con al menos un `pipelineJob` o `multibranchPipelineJob` seed.
8. Opcional pero puntúa en rúbrica: `tool:` para `jdk`, `maven` o `nodejs`; `clouds:` con `kubernetes:` configurado.

### Procedimiento de validación automática

Desde `operative/`:

```bash
bash validate/check-jenkinsfile.sh submission/Jenkinsfile
bash validate/check-jcasc.sh       submission/jenkins.yaml
bash validate/check-no-secrets.sh  submission/
```

Los tres scripts deben salir con exit code 0. Imprimen un reporte legible con PASS/FAIL por regla. Los scripts no requieren Jenkins; solo `bash`, `grep`, `yq` (o `python3` con `pyyaml`).

### Rúbrica OP-task-1 (Jenkinsfile)

| Criterio                                   | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|--------------------------------------------|------------------|------------|----------------|-------------|
| Estructura Declarative correcta            | No parsea / Scripted puro | Pipeline parsea pero sin `agent none` ni stages claros | Cumple reglas 1–3 del checklist | Cumple + nombres de stages consistentes con lenguaje de dominio |
| Agent K8s multi-container                  | Ausente | `agent { kubernetes }` pero sin yaml multi-container | Multi-container con jnlp + build | Multi-container con resources/limits y labels de workload |
| Parallel + when + post                     | Ninguno | 1 de los 3 | 2 de los 3 | Los 3 bien usados y con rationale en `NOTES.md` |
| Manejo de credenciales                     | Secreto literal en el fichero | `credentials()` pero expuesto en `environment` global | `withCredentials` correcto | `withCredentials` + mención de OIDC como siguiente paso en `NOTES.md` |
| Input manual sin bloquear executor         | `input` dentro de `node { }` o con agent asignado | `input` presente pero mantiene agent | Stage dedicado con `agent none` | Stage dedicado + timeout en el input |
| Shared library pinneada                    | Sin `@Library` o con `@Library('x')` sin pin | `@Library('x@master')` | `@Library('x@vN.N.N')` | Pin + comentario de política de upgrade |

Peso dentro de OP-task-1: 60% del operativo total.

### Rúbrica OP-task-2 (JCasC)

| Criterio                        | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---------------------------------|------------------|------------|----------------|-------------|
| YAML válido y estructurado      | No parsea | Parsea pero sin secciones mínimas | Cumple reglas 1–3 | Cumple + comentarios por sección |
| Authorization & remoting        | `loggedInUsers...` o `unsecured` | Matrix sin granularidad | `roleBased` con global + project roles | Role Strategy + justificación por rol |
| Credentials sin literales       | Secreto literal en YAML | Mezcla literales + placeholders | Todos como `${VAR}` | `${VAR}` + referencia a secret manager externo documentada |
| Global library pinneada         | No declarada | Declarada con `defaultVersion: master` | `defaultVersion: v1.x.x` | Pinneada + `implicit: false` + política |
| Reproducibilidad end-to-end     | Faltan jobs seed o tools | Jobs seed pero sin tools/clouds | Jobs seed + tools **o** clouds | Jobs seed + tools + clouds + comentario sobre backup/restore |

Peso dentro de OP-task-2: 40% del operativo total.

---

## Sección 3 — Ejercicio arquitectónico (30%)

Ver `architectural/scenario.md`. Entregar en `architectural/submission/ADR.md` siguiendo la plantilla MADR.

Rúbrica resumida (ver detalle en `architectural/scenario.md`):

| Criterio                        | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|---------------------------------|------------------|------------|----------------|-------------|
| Inventario y clasificación      | Falta o es cualitativo sin criterios | Lista jobs pero sin criterios de clasificación | Clasifica migrar/consolidar/retirar con criterios | + prioriza por riesgo × valor |
| Elección de target              | Dogma ("todo a GHA") sin análisis | Elige target pero sin trade-offs | Elige con trade-offs claros vs alternativas | + diferentes targets por tipo de workload con rationale |
| Plan de dual-run                | Ausente | Mencionado sin criterios | Define ventana, criterios de paridad y de retiro | + plan de rollback y criterios de abort |
| Seguridad en la migración       | No menciona credenciales ni plugins | Menciona credenciales genérico | `withCredentials` → OIDC + plugin audit | + rotación obligatoria durante la migración |
| ADR completo (MADR)             | Faltan secciones | Decisión sin consecuencias ni rollback | Secciones completas | + métricas de éxito observables post-corte |

---

## Preguntas de seguimiento (sólo evaluación live)

Si el examen se corrige con el candidato presente, usar éstas para distinguir memorización de comprensión. **No se envían por adelantado.**

- F1 (sobre Q2 / OP-task-1): "Si eliminara el `input` y pusiera el gate manual como webhook externo que dispara otro pipeline, ¿qué ganás y qué perdés?"
- F2 (sobre Q3 / Q4): "Mostrame cómo testearías el step `standardBuild()` de la Shared Library con JenkinsPipelineUnit — no quiero el código, quiero el enfoque y qué assertions pondrías."
- F3 (sobre Q5 / OP-task-1): "Tu pod agent se queda `Pending` durante 10 minutos y luego el build falla por timeout. ¿Dónde mirás primero y en qué orden?"
- F4 (sobre Q6 / OP-task-2): "¿Qué pasa con la configuración definida por UI *después* de aplicar un JCasC? ¿Se preserva, se sobreescribe, se mergea?"
- F5 (sobre Q8 / Q9): "Me acabás de decir que preferís OIDC. En este Jenkins on-prem aislado sin acceso a cloud ¿cuál es el siguiente mejor patrón y por qué?"
- F6 (sobre ARCH): "Tu CFO lee tu ADR y dice: 'si funciona no lo toques, cancelá la migración'. Defendé el plan en tres frases."
- F7 (sobre ARCH): "Mitad de la migración se filtra que un pipeline crítico se rompió y pasó inadvertido 3 semanas. ¿Cómo rediseñás el proceso para que no vuelva a pasar?"

---

## Red flags (invalidan la respuesta correspondiente)

Ver lista canónica en `competency-matrix.yaml → red_flags`. Resumen: secretos literales, `@Library` sin pin, sandbox desactivada, `loggedInUsers can do anything` en prod, `docker.sock` montado en agent, migración sin dual-run, `curl | bash` en steps, `install latest` sin pinning.

---

## Guía de corrección (instructor-only)

> No compartir con el candidato antes de corregir. La guía detallada por pregunta y por ejercicio (respuestas modelo, errores frecuentes, cómo puntuar respuestas parciales) vive junto a cada artefacto:
>
> - Conceptual: ver bloque "Respuesta esperada" al final de este documento.
> - Operativo: `operative/validate/*.sh` imprime PASS/FAIL por regla; la rúbrica cualitativa se aplica sobre lo que los scripts no cubren (naming, comentarios, `NOTES.md`).
> - Arquitectónico: ver "Guía de corrección" dentro de `architectural/scenario.md`.

### Respuesta modelo — preguntas conceptuales

**Q1.** Garantías de Declarative: (1) DSL restringido validable estáticamente (`jenkins-cli declarative-linter`), (2) estructura obligatoria `pipeline { agent, stages, post }` que fuerza mantenibilidad y onboarding, (3) chequeos de seguridad del sandbox más estrictos y menor superficie para RCE comparado con Scripted. Escape legítimo a `script {}`: lógica Groovy puntual que no puede expresarse con los steps declarativos (p. ej. construir dinámicamente una lista de stages a partir de un `Map`), y siempre encapsulada en un step de Shared Library testeado. *Puntúa parcial si menciona dos garantías; falla si defiende Scripted por "más poder" sin reconocer el costo.*

**Q2.** `agent any` a nivel pipeline reserva un executor del controller/agent durante todo el pipeline, incluido el tiempo de espera del `input` (que puede ser horas). Con `agent none` + `agent` por stage, cada stage ocupa su agent solo durante su ejecución y el stage de `input` no ocupa ninguno. Con 500 pipelines concurrentes esperando aprobación, lo primero mata la capacidad útil del fleet. *Red flag si no identifica que el `input` dentro de un `node { }` bloquea el executor.*

**Q3.** `@Library('platform-lib')` resuelve a `defaultVersion` global (típicamente `master`), por lo que un build de hace seis meses se re-ejecuta hoy con **código distinto** de la library. `@Library('...@v1.4.2')` pinnea por tag y es reproducible. Equivalente a `:latest` en Docker: cómodo, irresponsable, rompe auditoría forense y rollback.

**Q4.** Orden sugerido: (1) tagear la rama actual como `v0.1.0` y pinnear todos los Jenkinsfiles a ese tag (congela el estado para poder iterar); (2) introducir CI de la library con `JenkinsPipelineUnit` cubriendo los 5–10 steps más críticos; (3) `CODEOWNERS` + PR obligatorio para `vars/` y `src/`; (4) deprecar `implicit: true` y migrar consumidores a `@Library` explícito versionado. Puntúa parcial si lista las medidas pero no las ordena por riesgo.

**Q5.** Contamination: un build deja `node_modules/` o un `.m2/` corrupto; el siguiente build en el mismo agent falla con un error que no se reproduce localmente. Privilege leak: equipo A deja credenciales en env del agent; pipeline del equipo B las lee. Agent efímero = Pod nuevo por build → entorno limpio, sin estado residual, sin acceso a secretos de otros equipos. Equivalente GHA: ARC (Actions Runner Controller) con ephemeral runners en K8s; el patrón es idéntico, cambia el controller.

**Q6.** Backup de `JENKINS_HOME` restaura el *estado binario* pero no es *leído* como código: no hay PR, no hay diff, no hay revisión. Secciones mínimas de `jenkins.yaml`: `jenkins:` (security realm + authorization + remoting), `credentials:` (referenciadas, no literales), `jobs:` (seed jobs o multibranch), `tool:` (jdk/maven/node), `unclassified:` (globalLibraries, SCM, notifiers) y opcional `clouds:` para K8s. *Puntúa parcial si menciona cuatro de las cinco.*

**Q7.** Criterios: necesidad justificada por caso de uso (no "por si acaso"), mantenido activamente, sin CVE crítico abierto. Pinning por versión exacta en JCasC. Upgrade mensual revisando advisories de la fundación; staging controller idéntico que recibe el upgrade primero; smoke tests sobre pipelines canary; rollback = re-pin a la versión anterior y restart. "Install latest" en UI no es trazable, no es revisable y rompe reproducibilidad.

**Q8.** Role Strategy con global roles (`admin`, `developer`, `reader`) + project roles por folder/equipo. Matrix sin granularidad escala mal; `logged in can do anything` es equivalente a no tener autorización. Script approval: cada API Groovy nueva usada fuera del sandbox requiere aprobación manual de admin — es fricción deliberada que evita RCE desde Jenkinsfile. Desactivar sandbox = cualquier commit al Jenkinsfile puede ejecutar código arbitrario en el JVM del controller (RCE directo).

**Q9.** `environment { X = credentials('id') }` expone el secreto como variable de entorno durante **todo** el pipeline y es fácil que un `sh "echo $X"` lo filtre; su scope es amplio. `withCredentials { }` limita el scope al bloque y Jenkins enmascara el valor en logs si se imprime accidentalmente. OIDC federation emite un token efímero por run — no hay secreto en reposo que rotar, no hay nada que filtrar más allá del TTL del token. Para deploy a AWS: OIDC federation (`aws-actions/configure-aws-credentials` equivalente para Jenkins vía plugin OIDC) es la respuesta correcta.

**Q10.** Controller caído = no se disparan builds, no se procesan webhooks, no se renderiza UI; los agents efímeros no sirven de nada sin alguien que les dé trabajo. Patrón activo-pasivo sin CloudBees: backup frecuente de `JENKINS_HOME` (Velero si está en K8s), controller pasivo apagado con el mismo `JENKINS_HOME` montado, DNS/LB que se puede repuntar manual o por script. RTO típico: minutos. Métricas: build queue depth, controller heap usage, executor saturation, disk I/O del `JENKINS_HOME`. *Puntúa parcial si menciona HA sólo mediante CloudBees sin alternativa OSS.*

### Señales de "respondió sin entender"

- Copia la respuesta de Q1/Q5 de documentación oficial sin adaptar al escenario.
- En OP-task-1 define `agent any` a nivel pipeline y pone el `input` dentro de un stage con agent (bloquea executor pero "funciona en el ejemplo pequeño").
- En OP-task-2 declara `authorizationStrategy: loggedInUsersCanDoAnything` "porque es más simple".
- En ARCH propone *big-bang migration* sin dual-run, o lo contrario: dual-run indefinido sin criterios de retiro.
- Confunde Shared Library (`@Library`) con Jenkins plugin (`plugin: X`); indica que no entendió el modelo de extensión.
- Usa `credentials()` como respuesta a todo sin diferenciar scope o rotación.
