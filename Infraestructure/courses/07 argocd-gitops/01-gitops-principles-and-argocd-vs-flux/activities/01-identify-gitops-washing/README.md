# Actividad 01 — Auditar 5 escenarios: GitOps o GitOps-washing

## 1. Identificación

- **ID:** `argo-01-01-identify-gitops-washing`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-01-gitops-principles-and-argocd-vs-flux`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

El error más caro al adoptar GitOps es **llamar GitOps a algo que no lo es**: instalar Argo CD y seguir con el pipeline push, "aplicar al merge sin reconciliar", o "tener manifests en Git pero aplicarlos desde CI". Esta actividad entrena el **ojo clínico** para distinguir lo que cumple los 4 principios de OpenGitOps de lo que suena parecido pero no es.

El entregable es un **MAP.md** con la auditoría de 5 escenarios, el veredicto (GitOps / washing / parcial), el principio violado y la corrección mínima.

No se requiere cluster, ni Argo CD, ni CI. Es puramente conceptual.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Enunciar los **4 principios** OpenGitOps.
- Marcar los 4 checks (declarative / versioned / pulled / continuously reconciled) sobre cualquier pipeline arbitrario.
- Nombrar el **principio violado** y la **consecuencia operativa** cuando hay washing.
- Proponer la **corrección mínima** que repararía el principio sin reescribir todo el stack.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (especialmente §4 y §9).
- Haber recorrido `examples/01-push-vs-pull-diagram/` y `examples/02-opengitops-principles-walkthrough/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/argo-01-washing
cd /tmp/argo-01-washing
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/argo-01-washing`.)

### 5.2 Los 5 escenarios

> **Escenario A — "Acme Classic"**
> Pipeline en GitHub Actions. En cada merge a `main`: build imagen, push a GHCR, `aws eks update-kubeconfig --name prod`, `kubectl apply -f manifests/`. Los manifests YAML viven en el mismo repo, bajo `manifests/`. Branch protection en `main` con 1 reviewer requerido.

> **Escenario B — "Acme Argo"**
> Acme instaló Argo CD en prod. Lo usan como visor de estado — abren la UI para ver si todo está sano. Pero el deploy sigue siendo el pipeline anterior: GHA hace `kubectl apply` al cluster al merge. Argo CD muestra "Synced" porque el estado del cluster coincide con lo que hay en Git (ya que GHA aplicó Git al cluster). Nadie tiene configurado `syncPolicy` en los Applications.

> **Escenario C — "Acme Pull But Not Continuous"**
> Acme reconfigura: ahora el pipeline **no toca el cluster**. Hace commit del nuevo image tag a un repo de infra. Argo CD tiene configurado `syncPolicy.automated: {}` pero con `--sync-interval=0` y confía solo en webhooks de GitHub al cluster (sin polling). Cuando el webhook llega, Argo CD aplica. **No hay reconciliación periódica**: si alguien hace `kubectl edit` en el cluster, nadie lo revierte ni lo detecta hasta el próximo commit a Git.

> **Escenario D — "Acme Scripted"**
> Acme tiene un repo `infra/` con una carpeta `scripts/` que contiene `deploy-web.sh`, `deploy-db.sh`, etc. Cada script hace `kubectl create`, `kubectl set image`, `kubectl patch`. Un Argo CD "custom config management plugin" ejecuta esos scripts cuando detecta cambios en el repo. Argo CD corre dentro del cluster, hace polling, y "aplica" ejecutando los scripts.

> **Escenario E — "Acme S3 Pivot"**
> Acme migró los manifests fuera de Git: ahora un pipeline los **genera** cada noche y los sube a un bucket S3 (sin versionado habilitado — "ahorro de costos"). Argo CD lee del bucket S3 vía un plugin custom, hace polling cada 3 minutos, y reconcilia con `selfHeal: true`. El pipeline que genera los manifests sí tiene su código en Git.

### 5.3 Entregable: `MAP.md`

Produce un archivo `MAP.md` en `/tmp/argo-01-washing/` con la estructura siguiente:

#### Sección 1 — Principios (recordatorio)

Lista los **4 principios** OpenGitOps con una frase cada uno (en tus palabras):

1. **Declarative** — ...
2. **Versioned and Immutable** — ...
3. **Pulled Automatically** — ...
4. **Continuously Reconciled** — ...

#### Sección 2 — Auditoría por escenario

Para **cada uno** de los 5 escenarios (A, B, C, D, E), produce un bloque con:

```markdown
### Escenario X — <nombre>

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | SI / NO | ... |
| 2 Versioned & Immutable | SI / NO | ... |
| 3 Pulled Automatically | SI / NO | ... |
| 4 Continuously Reconciled | SI / NO | ... |

**Veredicto**: GitOps / GitOps-washing / parcial

**Principio(s) violado(s)**: ...

**Consecuencia operativa**: (qué pasa en la práctica — drift, blast radius, auditoría, rollback)

**Corrección mínima**: (el cambio más barato que haría cumplir el principio sin reescribir todo)
```

Los 5 escenarios deben aparecer explícitamente nombrados como `Escenario A`, `Escenario B`, `Escenario C`, `Escenario D`, `Escenario E`.

#### Sección 3 — Preguntas obligatorias

Numera las respuestas **del 1 al 7**:

1. ¿Cuál de los 4 principios es el **más común de violar** y por qué? Da un patrón de washing típico asociado.
2. En el escenario B, Argo CD muestra "Synced". ¿Significa que están haciendo GitOps? Justifica mencionando el principio clave.
3. Explica, en 3 líneas, por qué "aplicar al commit sin reconciliar" (escenario C) **anula el beneficio principal** de GitOps.
4. En el escenario D (scripts bash orquestados por Argo CD), ¿qué principio se rompe y por qué un script no es "declarativo" aunque viva en Git?
5. En el escenario E, los manifests están en S3 **sin versionado**. ¿Qué principio se viola y qué riesgo operativo concreto genera (nombra al menos dos)?
6. Si un auditor SOC2 pregunta "¿cómo pruebas qué cambió en prod el martes pasado?", responde brevemente **cómo** lo resuelve un GitOps bien hecho y **qué pasa** si el sistema es GitOps-washing.
7. Un compañero propone "metemos todos los secretos en el repo privado de infra; es privado, da igual". ¿Viola algún principio de OpenGitOps estrictamente? ¿Es aceptable? Argumenta.

### 5.4 Validar estructura

```bash
bash tests/validate.sh /tmp/argo-01-washing
```

Chequea que `MAP.md` exista y contenga: los 4 principios enunciados, los 5 escenarios nombrados explícitamente, mención a Argo CD / Flux / webhook / drift / reconcil, veredictos y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/MAP-reference.md`.

## 6. Resultado esperado

- Archivo `MAP.md` en `/tmp/argo-01-washing/` con las tres secciones y los 5 escenarios auditados.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/MAP-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Los **4 principios** aparecen enunciados en la Sección 1.
- [ ] Los **5 escenarios** (A, B, C, D, E) aparecen nombrados y cada uno con tabla + veredicto + corrección.
- [ ] Al menos **3 escenarios** diagnosticados como washing/parcial (los 5 no son todos GitOps).
- [ ] Las **7 preguntas** respondidas (como `1.`, `2.`, ... al inicio de línea).
- [ ] Se menciona explícitamente "drift" en al menos una respuesta.

## 8. Validación

```bash
bash tests/validate.sh /tmp/argo-01-washing
```

Estructural. **Semántica** la calibras tú con `solution/MAP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si trabajas en una organización que **declara** hacer GitOps pero el pipeline sigue haciendo `kubectl apply`, ¿cómo lo comunicarías internamente sin crear fricción política?
2. ¿Es GitOps-washing *siempre* malo? Hay patrones de migración donde durante 2–3 meses conviven push y pull. ¿Cuándo es aceptable y cuándo no?
3. ¿Qué principio sería **más caro** de corregir en un pipeline legacy: 1 (declarative), 3 (pulled) o 4 (continuous)? Argumenta.

## 10. Extensiones (opcional)

- **E1** — Diseña un **check automatizable** (p. ej. un script de bash o un workflow) que detecte violación del principio 3: busca referencias a `kubectl apply` o `helm upgrade --install` en workflows de GitHub Actions del repo de código. Documenta falsos positivos esperados.
- **E2** — Añade un sexto escenario propio **ambiguo** (ni claramente GitOps ni claramente washing) y defiende tu veredicto.
- **E3** — Reescribe el escenario A para que **cumpla** los 4 principios con **el mínimo cambio** posible (describe la secuencia de pasos de migración, no implementes nada).

## 11. Limpieza

```bash
rm -rf /tmp/argo-01-washing
```
