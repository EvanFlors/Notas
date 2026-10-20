# gl-07 — Leccion: Environments, Deployments y Review Apps en GitLab

> 10 secciones. Mayoritariamente conceptual + YAML. Prerrequisito: `gl-04` (rules/workflow/needs).

---

## 1. Por que `environment:` es un objeto, no un side effect

En un pipeline naive, "desplegar a staging" es una linea mas del `script:` de un job:

```yaml
deploy_staging:
  script:
    - ./deploy.sh https://staging.example.com
```

Funciona. Pero GitLab no sabe nada de ese deployment: no aparece en la UI "Environments / Deployments", no hay historial, no hay rollback con un boton, no hay URL clickable desde el MR, no hay proteccion por rama ni approval, y no hay forma automatica de **detener** el environment cuando el MR cierra.

El salto conceptual es declarar el deployment:

```yaml
deploy_staging:
  stage: deploy
  script:
    - ./deploy.sh https://staging.example.com
  environment:
    name: staging
    url: https://staging.example.com
```

Ahora GitLab materializa un objeto **Environment** llamado `staging` y, por cada ejecucion exitosa de este job, un objeto **Deployment** con `sha`, `ref`, `status`, `created_at`, `finished_at`, `user`. La UI muestra "staging — deployed by @alice 3h ago — view app". El MR muestra "View app" apuntando a esa URL. La API `GET /projects/:id/deployments` lo lista.

> **Idea clave:** `environment:` convierte un deployment en un **objeto de dominio**. A partir de ahi, todas las piezas de gobierno (approval rules, protecciones, auto-stop, rollback) se enganchan al objeto, no al script.

El contraste con GitHub Actions es directo: en GHA tambien existen Environments y Deployments como objetos, pero el modelo es menos denso y las Review Apps son un **patron** que montas tu, no un primitivo.

---

## 2. Anatomia de `environment:` — las 5 `action:` validas

El keyword `environment:` acepta un objeto con los siguientes campos (los mas usados):

| Campo | Que hace | Ejemplo |
|-------|----------|---------|
| `name` | Nombre canonico del environment. Admite variables (`review/$CI_MERGE_REQUEST_IID`). | `staging` |
| `url` | URL publicada del environment. Se vuelve clickable en la UI y en el MR. | `https://staging.example.com` |
| `action` | Que tipo de operacion registra este job (ver abajo). Default: `start`. | `start` |
| `on_stop` | Nombre de otro job (en el mismo pipeline) que apaga este environment. | `stop_review` |
| `auto_stop_in` | Despues de X tiempo sin nuevos deployments, se dispara `on_stop`. | `1 day` |
| `deployment_tier` | Hint para la UI y para analiticas: `production`, `staging`, `testing`, `development`, `other`. | `production` |

Los **5 valores validos de `action:`**:

1. **`start`** — crea o actualiza un deployment (es el default). Es lo que registra "este commit esta corriendo en staging".
2. **`stop`** — marca el environment como detenido. El job que ejecuta `on_stop:` debe declarar `action: stop`.
3. **`prepare`** — reserva el environment sin crear deployment. Util para pre-flight (p. ej. aplicar migraciones antes del release real).
4. **`verify`** — registra una verificacion post-deploy (smoke tests externos). No cambia el deployment "ganador".
5. **`access`** — registra que alguien accedio al environment (p. ej. abrio una sesion SSH via el runner). Rara vez usado.

El error mas comun: olvidar `action: stop` en el job de teardown de Review Apps. Sin eso, GitLab no sabe que el environment debe marcarse como `stopped` y lo deja "activo" para siempre.

---

## 3. Deployments como historia versionada

Cada vez que un job con `environment: { name: X, action: start }` termina en verde, GitLab crea un `Deployment` con un `iid` incremental dentro del environment. La UI `Deployments > Environments > X` muestra la pila. Cada entrada tiene:

- **Re-deploy** (vuelve a ejecutar el job con el mismo sha).
- **Rollback** (ejecuta el job del deployment anterior).
- Link al pipeline y al commit.

Esto importa porque **el rollback deja de ser un ritual manual** ("busca el sha, lanza el pipeline con un override, cruza los dedos"). Es un boton que ejecuta el job del deployment previo con el mismo input. No es magia: no deshace cambios de base de datos ni restaura data; **re-ejecuta la receta anterior**. Si tu `script:` es idempotente y tus migraciones son forward-compatible, el rollback funciona. Si no, no.

> **Trampa:** rollback de GitLab = re-run del job anterior. **No** es un git revert ni un snapshot. Tu `deploy.sh` tiene que soportar "aplicar esta version X otra vez" sin romperse.

El objeto `Deployment` tambien es util para **downstream automation**: webhooks, metricas (`deployment_frequency`, uno de los DORA), gates de release.

---

## 4. Review Apps: preview per MR como objeto de primera clase

El patron "preview environment por Pull Request" es antiguo: montar una instancia efimera para cada MR, dejarla viva mientras el MR este abierto, destruirla al merge o close. En GitHub Actions se implementa a mano (jobs + labels + cleanup workflow). En GitLab es **un primitivo del dominio** llamado **Review App**.

Un Review App no es un tipo especial de environment: es un **environment dinamico** cuyo `name` incluye `$CI_MERGE_REQUEST_IID` (u otra variable estable por MR). La convencion:

```yaml
review:
  stage: review
  script:
    - ./deploy_preview.sh "mr-$CI_MERGE_REQUEST_IID"
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    url: https://mr-$CI_MERGE_REQUEST_IID.preview.example.com
    on_stop: stop_review
    auto_stop_in: 7 days
    deployment_tier: development
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

stop_review:
  stage: review
  script:
    - ./destroy_preview.sh "mr-$CI_MERGE_REQUEST_IID"
  environment:
    name: review/mr-$CI_MERGE_REQUEST_IID
    action: stop
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: manual
  allow_failure: true
```

Lo que GitLab aporta encima de "lanzar un script":

- **Agrupacion en la UI** — todos los `review/mr-*` se agrupan bajo el "folder" `review/`.
- **MR widget** — el MR muestra "View app" apuntando a la URL del Review App vivo.
- **Auto-stop** — si pasa `auto_stop_in` sin re-deploys, GitLab ejecuta `stop_review` automaticamente.
- **Stop on close** — cuando el MR se cierra o se mergea, GitLab dispara el job `on_stop`.

> **Idea clave:** `on_stop:` es el gancho para destruir recursos del environment. **Sin `on_stop:`, un Review App puede quedar vivo indefinidamente**, acumulando coste (cluster namespaces, DNS records, discos).

El job `on_stop` tiene restricciones:

- Debe declarar `environment: { name: ..., action: stop }` con el **mismo `name`** que el job que creo el environment.
- Debe tener `when: manual` o estar enganchado como stop handler (no se ejecuta automaticamente en el pipeline normal; se dispara por evento del environment).
- Si el job de teardown falla, el environment queda en `failed_to_stop` y hay que intervenir manualmente.
- Buena practica: `allow_failure: true` para que un fallo de teardown no bloquee el flujo principal.

---

## 5. `auto_stop_in` — el killer feature de FinOps en Review Apps

Un Review App olvidado es un bucket o un namespace vivo cobrando por horas. `auto_stop_in: <duration>` resuelve esto declarativamente. Admite valores humanos:

- `30 minutes`, `2 hours`, `1 day`, `3 days`, `1 week`, `never`.

El reloj se reinicia con cada nuevo deployment al mismo environment. Si el MR tiene actividad diaria, el environment sobrevive; si queda abandonado 7 dias, se dispara el teardown. El default (si no se declara) es `never` — explicito es mejor.

Trade-off: si pones `auto_stop_in: 1 hour`, cada vez que el reviewer entre despues de almuerzo el environment estara apagado. Un rango razonable para flujo humano es `2 days` a `1 week`.

---

## 6. Protected environments y approval rules

Un **protected environment** es un environment al que **solo roles o usuarios autorizados pueden desplegar**. Se configura en `Settings > CI/CD > Protected environments`. Dos capas de proteccion:

1. **Deploy access** — quien (role, grupo, usuarios) puede ejecutar un job que apunte a este environment. Por defecto, `production` deberia restringirse a `Maintainers` o a un grupo especifico `platform-admins`.
2. **Approval rules** (Premium+) — antes de que el deployment avance, requiere X aprobaciones de miembros especificos. Un approval rule tiene:
   - `required_approvals`: numero minimo de aprobadores.
   - `group_id` / `user_id`: quien puede aprobar.
   - `access_level`: alternativamente, un role (Maintainer, Developer).

Modelo mental:

```
job deploy_prod → environment: production (protected)
                  │
                  ├── check: ¿el pipeline corre en una ref protegida?  (si no → bloqueado)
                  ├── check: ¿el user tiene deploy access a production? (si no → bloqueado)
                  └── gate: deployment approval → requiere N aprobaciones
                                                   del grupo @sre o del user @oncall
                                                   antes de que el job arranque
```

El flujo UI: el job queda en estado `blocked` o `waiting for approval`, aparece en el MR un widget "Deployment waiting for approval", los aprobadores lo revisan y aprueban/rechazan. Al llegar al minimo, el job arranca.

> **Idea clave:** approval rules no son `rules:` del pipeline. `rules:` filtra **cuando se incluye el job**; approval rules controla **si el deployment puede ejecutarse** una vez el job ya esta programado. Son dos planos distintos.

Comparacion con GitHub Actions Environments: GHA tiene "required reviewers" por environment, con el mismo modelo mental; GitLab aporta mas granularidad (approval multi-grupo, numeros minimos distintos por environment).

---

## 7. Blue/green y canary en GitLab

GitLab **no** tiene un primitivo "blue/green" ni "canary" nativo tipo Argo Rollouts. Lo que ofrece es:

- Multiples environments (`prod-blue`, `prod-green`) con jobs que apuntan a cada uno.
- `environment: { deployment_tier: production }` para que la UI los agrupe correctamente.
- Jobs manuales (`when: manual`) para cambiar el trafico (ejecutar el script que apunta el load balancer a green).
- Progressive deployment: multiples jobs `deploy_canary_5pct`, `deploy_canary_25pct`, `deploy_canary_100pct`, cada uno manual y protegido.

Es un patron, no un objeto. Si quieres canary serio con metricas de salud y rollback automatico, la respuesta son **Argo Rollouts** o **Flagger**, no GitLab environments. GitLab es el **orquestador** (el pipeline que invoca el rollout); el controller de K8s hace el trabajo.

---

## 8. GitLab Agent for Kubernetes (`kas`)

Historicamente, GitLab se conectaba a clusters K8s guardando el kubeconfig en una variable y ejecutando `kubectl` desde el runner. Esto requeria exponer el `kube-apiserver` publicamente (o via VPN) y guardar credenciales de larga vida — ambos malos.

El **GitLab Agent for Kubernetes** (comunmente llamado `kas`, por "kubernetes agent server") invierte la direccion:

- Instalas el agente **dentro** del cluster (via Helm). El agente abre una conexion saliente a GitLab (`kas.gitlab.com` para SaaS; tu `kas` self-hosted en Self-Managed).
- GitLab usa esa conexion para enviar comandos al cluster. **El cluster no expone nada** publicamente.
- Autenticacion por el token del agente — no necesitas kubeconfig en variables.

Dos modos de operacion:

1. **CI/CD tunnel** — tu pipeline usa `kubectl` apuntando al agente, el agente proxea al apiserver. Modelo "push" con la seguridad resuelta.
2. **GitOps mode** — el agente **observa** un repo con manifests y los aplica en el cluster (modelo "pull" tipo Flux). GitLab es la fuente de verdad; el cluster converge.

**Comparacion con Argo CD / Flux**:

- **Argo CD** sigue siendo el estandar GitOps mas adoptado, con mejor UI, `ApplicationSet`, waves, hooks, metricas. Si GitOps es un pilar de tu plataforma, probablemente quieres Argo CD aunque uses GitLab.
- **Flux** es mas minimalista, mejor integrado con Kustomize/Helm.
- **GitLab Agent GitOps** es "lo suficientemente bueno" si estas 100% en GitLab y quieres evitar añadir una pieza mas. Menos features (no `ApplicationSet`, UI menos rica), mas integrado.

> **Regla practica para el programa:** cuando se habla de GitOps serio, se recomienda Argo CD por fuera; GitLab Agent para casos pequeños-medios o cuando la organizacion ya evito acoplar CD con el cluster via Argo.

---

## 9. Patron recomendado: pipeline → environments en 4 niveles

Una politica de environments que escala para una org pequeña o media:

```
┌─────────────────────────────────────────────────────────────────┐
│  Nivel        │ Trigger             │ Protegido │ Approvals     │
├───────────────┼─────────────────────┼───────────┼───────────────┤
│  review/*     │ MR event            │ no        │ no            │
│  development  │ push a main         │ no        │ no            │
│  staging      │ push a main (post)  │ si        │ no            │
│  production   │ manual o tag        │ si        │ 1-2 (SRE)     │
└─────────────────────────────────────────────────────────────────┘
```

Caracteristicas:

- **Review App** vive mientras el MR este abierto; `auto_stop_in: 7 days`; `on_stop: stop_review`.
- **Development** se re-despliega en cada push a `main`; sin aprobaciones; `deployment_tier: development`.
- **Staging** se despliega automaticamente tras un deploy exitoso a development (via `needs:`); protegido para que solo el pipeline pueda desplegar; sin aprobaciones humanas pero con gates de smoke tests.
- **Production** manual (`when: manual`) o por tag (`rules: - if: $CI_COMMIT_TAG`); protegido con deploy access limitado a `platform-admins`; approval rule requiere 1 aprobador del grupo `@sre` o `@oncall`.

**Hotfix**: se modela como un pipeline que corre en una rama `hotfix/*` con reglas que saltan review y staging y van directo a production, pero mantiene la approval rule (porque un hotfix mal hecho es la causa #1 de incidentes).

---

## 10. Mapping conceptual GitLab ↔ GitHub Actions

| GitLab                                      | GitHub Actions                                   |
|---------------------------------------------|--------------------------------------------------|
| `environment: { name, url }`                | `environment: { name, url }` (en el job)         |
| Deployment object + UI "Deployments"        | Deployment object + UI "Deployments"             |
| Protected environment + deploy access       | Environment + protection rules                   |
| Approval rule (Premium)                     | Required reviewers                                |
| Review App (nativo)                         | PR preview (patron: deploy en PR + cleanup)      |
| `on_stop:` + `action: stop`                 | Workflow con `on: pull_request: closed`          |
| `auto_stop_in:`                             | No existe nativo (requiere scheduled workflow)   |
| GitLab Agent for Kubernetes                 | `azure/k8s-deploy` + OIDC o ARC                  |
| GitOps mode del Agent                       | Argo CD / Flux (externos)                        |

El punto de inflexion: **Review Apps + `auto_stop_in:`** son el diferencial de UX mas visible frente a GHA. En GHA estos patrones existen pero cuestan 50-150 lineas de workflow + un cron job de limpieza; en GitLab son 10 lineas en `.gitlab-ci.yml`.

---

## Resumen operativo

- `environment:` convierte scripts en objetos de dominio con UI, API, rollback y proteccion.
- Las 5 `action:` validas son `start | stop | prepare | verify | access`.
- Review Apps = environment dinamico por MR + `on_stop:` + `auto_stop_in:`.
- Protected environments + approval rules = gate humano antes del deployment, independiente de `rules:`.
- GitLab Agent for Kubernetes = conexion segura cluster → GitLab sin exponer apiserver; modo GitOps compite (parcialmente) con Argo CD.
- La politica estandar: 4 niveles (review/dev/stg/prod) con proteccion y approvals crecientes.
