# Entrevista mock — Senior / Staff Platform / CI-CD Engineer

Protocolo para ejecutar una entrevista técnica realista de 90–120 min al final del programa. Cierra el ciclo: la defensa del capstone evalúa el trabajo **propio** del estudiante; esta entrevista evalúa cómo responde a **problemas que no vio antes**.

El entrevistador debe ser alguien que **no participó** en la academia del estudiante (ideal: colega senior externo).

---

## Estructura (120 min)

| Bloque | Minutos | Objetivo |
|--------|--------:|----------|
| 0 — Warmup | 5 | Presentación mutua. Fijar expectativas (modo entrevista real). |
| 1 — System design | 35 | Diseño de un sistema CI/CD + delivery para un escenario dado. |
| 2 — Debug session | 25 | Diagnosticar y proponer fix sobre manifests fallando. |
| 3 — Code review | 25 | Revisar un Jenkinsfile y un bundle de YAML Kubernetes con defectos plantados. |
| 4 — Behavioral | 20 | Preguntas conductuales mapeadas a Team Topologies + SPACE. |
| 5 — Student Q&A + wrap | 10 | El estudiante pregunta. Se cierra sin devolver puntuación. |

La deliberación y devolución se hace **offline**, dentro de 24 h, con la rúbrica §5.

---

## Bloque 1 — System design (35 min)

### Enunciado (al estudiante)

> Diseña, en pizarra o papel compartido, la plataforma de delivery para una empresa fintech de ~200 desarrolladores en 25 equipos. Hoy tienen Jenkins monolítico, SSH a VMs, cero IaC, y presión regulatoria de evidencia de supply-chain. Objetivos:
> - Tiempo del commit a producción: horas, no días.
> - Evidencia auditable: toda imagen en prod tiene SBOM y firma verificada en admisión.
> - Equipos de producto autosuficientes para su stream.
> - Un equipo de plataforma de **6 personas** sostiene esto.
>
> Decide y justifica: cloud, orquestación, GitOps tool, estrategia de secretos, observability stack, policy stack, estrategia de ambientes. Dibuja arquitectura y organización. Explica qué construyes **primero** y por qué.

### Lo que el entrevistador busca

- Clarifica antes de dibujar (al menos 3 preguntas de restricciones: multi-región, residencia, ventanas de cambio, nivel de MFA, workloads stateful).
- Separa **plano de datos** (apps en producción) de **plano de control** (CI, repos, backstage).
- Nombra Team Topologies explícita o implícitamente: platform team vs stream-aligned.
- Prioriza por **impacto / esfuerzo**, no por "primero infra, después apps".
- No sobre-ingeniería: no mete service mesh en el día 1.
- Hace trade-offs explícitos — "si el regulador exige residencia en X, elegiría Y, no Z".

### Follow-ups si queda tiempo

- "El CFO corta el presupuesto 30 %. ¿Qué recortas sin bajar la seguridad?"
- "El equipo de plataforma pierde 2 personas. ¿Qué se vuelve roadmap vs qué se vuelve self-service?"

---

## Bloque 2 — Debug session (25 min)

El entrevistador entrega **estos manifests** (fallan por diseño). Ver `fixtures/` abajo (crear antes de la entrevista).

### Escenario (al estudiante)

> Tienes una Application de Argo CD apuntando a un repo que contiene un Deployment, un Service y una NetworkPolicy. En el cluster, el Pod arranca pero la Application queda `Progressing` para siempre y las requests externas no llegan. Tienes acceso a `kubectl` y a la UI de Argo CD. Diagnostica.

### Manifests provistos (resumen; los archivos completos van en `fixtures/`)

Defectos **plantados** (el entrevistador los conoce; el estudiante no):

| # | Defecto | Severidad | Pista si se traba |
|---|---------|:---------:|-------------------|
| D1 | `readinessProbe.httpGet.path: /healthz` pero la app sirve `/health` | alta | "Mira los eventos del Pod." |
| D2 | `Service.spec.selector` tiene `app: web` pero el Deployment pone `app.kubernetes.io/name: web` | alta | "¿Cuántos endpoints tiene el Service?" |
| D3 | `NetworkPolicy` default-deny sin regla para el `ingress-nginx` namespace | alta | "¿Qué pasa si curl desde dentro del cluster vs desde fuera?" |
| D4 | `Application.spec.syncPolicy.automated.selfHeal: true` + un mutating webhook que inyecta labels → sync loop | media | "Mira el history de syncs." |
| D5 | `resources.requests.memory: 10Gi` en cluster con nodos de 8Gi → Pending enmascarado como "progressing" | media | "¿Está el Pod Running o Pending?" |

### Lo que el entrevistador busca

- Metodología visible: `kubectl get pod -o wide`, `describe`, `logs`, `get events`, luego Service/Endpoints, luego NetworkPolicy, luego Argo CD.
- No parchea en caliente: propone **fix en el repo** y espera a que Argo reconcilie.
- Al menos **3 de 5** defectos encontrados en los 25 min = Competente.
- Encontrar los 5 + explicar por qué el selfHeal + webhook es un patrón peligroso = Experto.

---

## Bloque 3 — Code review (25 min)

Entregar al estudiante un `Jenkinsfile` y un bundle YAML (Deployment + Service + ServiceAccount + Role). Pedirle **revisión como PR**: comentarios de bloqueo, sugerencias, preguntas.

### Defectos plantados — `Jenkinsfile`

| # | Defecto | Severidad |
|---|---------|:---------:|
| J1 | `agent any` sin label — corre en el controller | alta |
| J2 | Credenciales inyectadas con `withCredentials` pero luego `echo $PASSWORD` para "debug" | **crítica** |
| J3 | `sh "docker build -t app:latest ."` + `docker push` sin tag inmutable | alta |
| J4 | `sh "curl https://example.com/install.sh | bash"` en un stage | **crítica** |
| J5 | Sin `timeout {}` en stage de deploy — puede quedar colgado para siempre | media |
| J6 | `when { branch 'main' }` pero el pipeline publica a prod sin aprobación manual | alta |
| J7 | `post { always { cleanWs() } }` ausente — workspace crece sin control | baja |
| J8 | Shared library importada con `@Library('mylib') _` sin versión fija → ejecución mutante | alta |

### Defectos plantados — YAML Kubernetes

| # | Defecto | Severidad |
|---|---------|:---------:|
| K1 | ServiceAccount con `ClusterRoleBinding` a `cluster-admin` | **crítica** |
| K2 | Imagen `nginx:latest` sin digest | alta |
| K3 | `runAsUser: 0`, `allowPrivilegeEscalation: true`, no `readOnlyRootFilesystem` | alta |
| K4 | Sin `livenessProbe` ni `readinessProbe` | alta |
| K5 | Secreto inline en `env.value` en vez de `secretKeyRef` | **crítica** |
| K6 | `resources` ausente → sin requests/limits | alta |
| K7 | `hostNetwork: true` sin justificación | **crítica** |
| K8 | `imagePullPolicy: Always` + `:latest` → sorpresa en restart | media |
| K9 | Service con `type: LoadBalancer` sin anotaciones de WAF/scheme internal/external explícito | media |

### Rúbrica rápida de este bloque

- Detectar las **4 críticas** (J2, J4, K1, K5, K7 → 5 críticas, exigir mínimo 4) = Competente.
- Detectar críticas + 60 % del resto + priorizar por severidad = Experto.
- No detectar alguna crítica = Insuficiente para este bloque, independientemente de lo demás.

### Guía de corrección (entrevistador)

Para cada defecto, el estudiante debe:

1. Nombrarlo.
2. Explicar el **impacto real** (qué pasa en producción, no "no es buena práctica").
3. Proponer el fix concreto.

Si solo nombra sin impacto → medio punto. Si inventa un defecto que no existe → neutral (no penaliza salvo que sea obvio que no lee).

### `fixtures/` esperado

El entrevistador prepara, antes de la entrevista:

```
fixtures/
├─ debug/
│  ├─ application.yaml
│  ├─ deployment.yaml
│  ├─ service.yaml
│  └─ networkpolicy.yaml
└─ review/
   ├─ Jenkinsfile
   └─ k8s-bundle.yaml
```

El contenido vive **fuera** de este repo (es material cerrado del entrevistador) — este README lista los defectos a plantar y su severidad, suficiente para construir los fixtures sin filtrarlos al estudiante.

---

## Bloque 4 — Behavioral (20 min)

Mapeadas a **Team Topologies** (TT) y **SPACE** (S=Satisfaction, P=Performance, A=Activity, C=Communication, E=Efficiency).

Elegir 4–5. Buscar **STAR** (Situation, Task, Action, Result) y auto-conciencia.

1. **(TT – Platform vs Stream)** Un equipo de producto se queja de que tu "golden path" los frena. Describe cómo investigas si tienen razón, y qué cambios en el path considerarías.
2. **(TT – Enabling)** Te piden ayudar temporalmente a un equipo a adoptar Kubernetes. ¿Cómo evitas quedarte como su on-call permanente?
3. **(TT – Complicated-subsystem)** La plataforma depende de un componente que solo tú entiendes. ¿Qué haces en los próximos 30 días?
4. **(SPACE – Satisfaction)** ¿Cuándo fue la última vez que un cambio tuyo degradó la DevEx de otros? ¿Cómo te enteraste y qué hiciste?
5. **(SPACE – Performance)** Cuéntame un cambio que mejoró una métrica DORA. ¿Cómo la mediste antes y después?
6. **(SPACE – Communication)** Describe una decisión técnica donde convenciste al equipo de **no** hacer algo que querían. ¿Qué funcionó?
7. **(SPACE – Efficiency)** ¿Qué parte de tu día-a-día te produce más flow? ¿Qué te lo rompe?
8. **(TT – Cognitive load)** Diseñaste un sistema que un sucesor tiene que mantener. ¿Qué dejas por escrito y qué no vale la pena documentar?

### Red flags conductuales

- "Nunca he tenido un desacuerdo técnico" / "siempre tengo razón".
- Culpar a usuarios/equipos de producto por "no entender la plataforma".
- Métricas sin método ("subimos la deployment frequency un 500 %" sin decir cómo).
- Describe a sí mismo como "héroe" en incidentes.

---

## Bloque 5 — Student Q&A (10 min)

El estudiante pregunta al entrevistador. Esto **también** evalúa: qué pregunta un candidato dice mucho de su nivel. Buenas señales:

- Pregunta por procesos de incidentes, no por "cultura" vaga.
- Pregunta por el estado del golden path, qué deuda hay, cómo se prioriza.
- Pregunta por on-call: rotación, compensación, carga.

Malas señales:

- Solo preguntas de HR (vacaciones, remoto).
- Ninguna pregunta.
- Preguntas de obvio copy-paste.

---

## 5. Rúbrica y decisión Hire / No-Hire

Puntuación por bloque, escala 0–3 (ver `../README.md` global):

| Bloque | Peso |
|--------|-----:|
| 1 System design | 30 % |
| 2 Debug | 20 % |
| 3 Code review | 20 % |
| 4 Behavioral | 20 % |
| 5 Q&A | 10 % |

### Umbrales

| Score global | Dictamen | Nivel |
|-------------:|----------|-------|
| ≥ 2.5 | **Strong hire** | Staff |
| 2.0 – 2.49 | **Hire** | Senior |
| 1.6 – 1.99 | **Hire con reservas** | Mid-senior; devolución específica |
| < 1.6 | **No hire** | Devolución de qué remediar |

### Vetos

Cualquiera **baja el dictamen a No-Hire** independientemente del score:

- No detectó alguna de las 4 críticas de code review (J2, J4, K1, K5, K7).
- En debug, nunca miró **eventos**/**logs** y propuso cambios al azar.
- En behavioral, red flag no mitigado.
- En system design, metió sin justificar un elemento que viola requisitos (p. ej. secretos en Git para una fintech).

### Devolución al estudiante (24 h)

Documento con:

- Dictamen y nivel.
- Score por bloque + 2 fortalezas + 2 áreas a trabajar.
- 1 recurso recomendado por área (link a módulo de la academia).
- **Preguntas que el entrevistador haría distintas** si entrevistase para Staff vs Senior — útil si el estudiante quiere crecer.
