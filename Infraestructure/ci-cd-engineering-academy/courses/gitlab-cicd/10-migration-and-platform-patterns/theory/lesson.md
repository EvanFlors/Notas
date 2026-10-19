# gl-10 — Lección: migración GHA↔GitLab y operación como plataforma

> Capstone. Síntesis del curso. Asume que todos los módulos anteriores están asimilados.

## 1. Dos problemas distintos que la gente confunde

- **Migración** es un proyecto *finito*: salir de A, entrar en B, apagar A. Tiene fecha de inicio y fecha de corte.
- **Operación como plataforma** es un *producto interno continuo*: catálogo versionado, SLAs, roadmap, usuarios.

La trampa clásica es tratar la migración como un `sed s/github/gitlab/g` masivo. Falla porque la equivalencia 1:1 no existe: hay primitivas sin equivalente, hay convenciones distintas (OIDC claims, modelo de permisos), y los repos a migrar están en estados dispares. La migración exitosa reconoce las **diferencias** y las **equivalencias** con el mismo cuidado.

## 2. Mapping GHA↔GitLab (versión práctica)

| GitHub Actions | GitLab CI/CD | Nota |
|----------------|--------------|------|
| `.github/workflows/*.yml` (N archivos) | `.gitlab-ci.yml` + `include:` (1 raíz + N incluidos) | GitLab tiene **un único** entry-point por repo. |
| `on: [push, pull_request]` | `workflow:` + `rules:` con `$CI_PIPELINE_SOURCE` | `pull_request` ≈ `merge_request_event`. |
| `jobs.<name>.steps:` (lista de steps) | job `<name>:` con `script:` (lista de shell) | GitLab no tiene *steps*; es shell plano. |
| `runs-on: ubuntu-latest` | `image:` + `tags:` | `image:` fija el contenedor; `tags:` selecciona el runner. |
| `strategy.matrix:` | `parallel: matrix:` | Semántica casi idéntica. |
| `needs: [a, b]` | `needs: [a, b]` | Prácticamente igual (ambos crean DAG). |
| `environment: prod` | `environment: name: prod` | GitLab permite `url:`, `on_stop:`, `auto_stop_in:` extras. |
| `permissions:` + OIDC `id-token: write` | `id_tokens:` por job con `aud:` | **Las claims del JWT difieren**: ver §4. |
| Reusable workflow (`uses: org/repo/.github/workflows/x.yml@v1`) | **CI/CD Component** (`include: - component: $CI_SERVER_FQDN/org/catalog/x@1.0.0`) | El equivalente moderno. Antes se usaba `include: remote:`. |
| Composite action | `extends: .hidden-job` o CI/CD Component | Composite ≈ bloque de pasos reutilizable → en GitLab, extiende un hidden job. |
| Marketplace action | Script directo o Component del catálogo | GitLab no tiene marketplace: convención = publicar en el Catálogo. |
| `secrets.GITHUB_TOKEN` | `$CI_JOB_TOKEN` | Alcance similar (ver docs; GitLab permite restringir qué proyectos lo aceptan). |
| Required workflows | **Compliance pipelines** (frameworks) | Se concatenan al `.gitlab-ci.yml` del proyecto. |
| Branch protection | **Protected branches** + **Protected environments** + MR approval rules | Más granular en GitLab. |
| Environments con approvals | Protected environments con approval rules (número de approvers, grupos) | Equivalente directo. |
| GitHub-hosted runners | GitLab-hosted SaaS runners (por tier) | Comparar coste por minuto; §7. |
| ARC (Actions Runner Controller) | GitLab Runner chart K8s + Fleeting | Fleeting sucede a `docker-machine` para autoscaling fuera de K8s. |

## 3. Inventario pre-migración (checklist dura)

Antes de tocar nada, recoge para cada repo:

1. **Workflows**: cuántos, cuáles disparadores (`push`, `pull_request`, `schedule`, `workflow_dispatch`), cuáles son críticos.
2. **Secrets**: nivel (repo, env, org), uso real (grep en workflows). Los que no se usan desde hace 90 días son candidatos a rotar y no migrar.
3. **Variables** (no-secretas): nivel y uso.
4. **Environments**: cuáles tienen approvals, cuáles tienen secrets propios.
5. **Protected branches / rulesets**: patrón + required status checks + required reviewers + required workflows.
6. **OIDC trust policies** (AWS/GCP/Azure/Vault): condition keys actuales (`token.actions.githubusercontent.com:sub` con `repo:org/repo:ref:...`). Hay que preparar las nuevas con el issuer y claims de GitLab (§4).
7. **Reusable workflows y composite actions**: inventario para decidir si cada uno se convierte en **Component** o se *inline*.
8. **Caches** y **artifacts**: tamaño, política de retención, dependencias cruzadas.
9. **Dependencias externas** (Marketplace actions): cada una decide reemplazo. Un `actions/setup-node@v4` se vuelve `image: node:20`; un action de terceros exótico puede necesitar reescritura.
10. **Minutos consumidos** (coste actual) y **picos de concurrencia** (dimensionado de runners nuevos).

Una hoja de cálculo con una fila por repo y una columna por item de arriba vale más que 1000 reuniones.

## 4. OIDC: lo que más rompe en una migración

Los dos pipelines (GHA y GitLab) obtienen tokens firmados **con issuers distintos** y **claims con nombres distintos**. La trust policy en el cloud debe aceptar ambos durante el dual-run, y luego recortar el de GHA.

### 4.1 Issuer

- GHA: `https://token.actions.githubusercontent.com`
- GitLab SaaS: `https://gitlab.com`
- GitLab Self-Managed: `https://<tu-gitlab>`

### 4.2 Claim equivalente del `sub`

- GHA: `repo:<org>/<repo>:ref:refs/heads/main` (o `environment:prod`, etc.).
- GitLab: `project_path:<group>/<project>:ref_type:branch:ref:main` (y variantes con `environment`).

### 4.3 Patrón de pinning recomendado en la trust policy AWS

```json
{
  "StringEquals": {
    "gitlab.com:aud": "https://gitlab.com",
    "gitlab.com:project_path": "my-group/my-project",
    "gitlab.com:ref_type": "branch",
    "gitlab.com:ref": "main"
  }
}
```

Error típico: pinnear por `sub` literal copiado de un pipeline y romperlo en cuanto se añade un environment o una tag. Pinnea por **claims específicos** (`project_path`, `ref_type`, `ref`, `environment`), no por el `sub` completo.

### 4.4 En el `.gitlab-ci.yml`

```yaml
deploy:
  id_tokens:
    AWS_ID_TOKEN:
      aud: https://gitlab.com
  script:
    - aws sts assume-role-with-web-identity --role-arn $ROLE_ARN --web-identity-token $AWS_ID_TOKEN ...
```

El `aud:` **debe coincidir** con lo que la trust policy espera. Si no, el `AssumeRoleWithWebIdentity` falla con `InvalidIdentityToken`.

## 5. Dual-run: cómo reducir el riesgo

Un *big-bang* ("hoy apagamos GHA, mañana todo corre en GitLab") es la receta para un domingo de guardia. El patrón que funciona:

1. **Portar el pipeline a GitLab** sin apagar GHA. Ambos corren en cada push.
2. **Comparar resultados** durante 2–4 semanas: ¿mismos tests pasan? ¿misma imagen se construye? ¿mismo tag llega al registry?
3. **Hacer autoritativo GitLab** (los status checks requeridos pasan a mirar GitLab).
4. **Apagar GHA**: eliminar los workflows (dejar el repo visible por historial).

Criterios de corte:

- 2 semanas sin discrepancias funcionales.
- Pipeline GitLab con tiempo total ≤ 120% del de GHA (o justificar la regresión).
- Secretos migrados y rotados.
- OIDC trust policy soporta GitLab (y, opcionalmente, aún GHA durante el solape).

## 6. CI/CD Catalog como *golden path*

El catálogo interno es el equivalente moderno del "sharedlibrary" de Jenkins o de los "reusable workflows" de GHA. Diferencias clave:

- **Contrato explícito** con `spec:inputs:` (tipo, default, required). Un consumidor compila fallando si pasa un input incompatible.
- **Versionado SemVer** con tags Git del propio proyecto-componente.
- **Publicable al Catálogo** del grupo o de la instance, con descripción, README y métricas de adopción.
- **Nested includes** limitados (hoy ~100 includes resueltos; validar en §12 del Checklist).

Formato mínimo de un Component (`templates/<name>/template.yml`):

```yaml
spec:
  inputs:
    image:
      type: string
      default: node:20
    coverage_threshold:
      type: number
      default: 80
---
test-job:
  image: $[[ inputs.image ]]
  script:
    - npm ci
    - npm test -- --coverage
    - node scripts/check-coverage.js --min $[[ inputs.coverage_threshold ]]
```

Consumo desde cualquier `.gitlab-ci.yml`:

```yaml
include:
  - component: $CI_SERVER_FQDN/platform/ci-catalog/node-test@1.3.0
    inputs:
      coverage_threshold: 85
```

## 7. Inner-source: quién propone y quién aprueba

Un catálogo "cerrado" (solo el equipo de plataforma puede escribir) escala mal. Un catálogo "abierto a todo el mundo" se degrada. El modelo intermedio:

- **Repo del catálogo** con Code Owners por componente.
- **Issue → RFC → MR**: cualquier dev propone un cambio; el Code Owner aprueba (con approval rule de 2 revisores si es nuevo componente).
- **Tag SemVer** sólo lo hace Platform (release manager).
- **Métricas de adopción**: `include:component:` grep en todos los proyectos de la org; publicar un dashboard "componentes más usados / menos usados".

Un componente sin usos en 90 días es candidato a `@deprecated` → eliminación en la siguiente major.

## 8. Cost control: SaaS vs runners propios

Decisión que depende de volumen y perfil:

| Variable | SaaS runners (gitlab.com) | Runners propios (K8s + Fleeting) |
|----------|---------------------------|----------------------------------|
| Setup | Cero | Semanas (chart, autoscaling, monitoreo). |
| Mantenimiento | GitLab lo hace | Tu equipo lo hace (upgrades, nodos, imágenes). |
| Coste | **Minuto × tier**; sin minutos ociosos pero caro a volumen alto | **Nodo × hora**; barato si usas los nodos; caro si están ociosos. |
| Latencia (queue) | Variable, picos en horario pico | Controlable (dimensionas tú). |
| Red privada (VPC/VPN) | No sin trucos | Natural. |
| OIDC a cloud | Soportado | Soportado. |
| Imágenes personalizadas | Pull en cada job (lento) | Pre-pull / caché local. |

Regla de bolsillo: por debajo de ~10.000 minutos/mes, SaaS gana. Por encima, hazte números y considera híbrido (SaaS para proyectos pequeños, runners propios para repos grandes).

## 9. Observabilidad del CI/CD

Los 4 indicadores que debería tener cualquier dashboard de plataforma:

1. **Pipeline duration (p50, p95)**: por proyecto, por branch, por último N días.
2. **Job success rate**: por job, por semana. Un job con <95% consistente es un *flaky* que te está robando productividad.
3. **Queue time**: tiempo entre `pending` y `running`. Si crece, faltan runners o tags mal puestos.
4. **Minutos consumidos**: por grupo, por proyecto. Para FinOps y para detectar *runaway pipelines*.

Fuentes:

- **Prometheus exporter** oficial de GitLab (`gitlab-exporter` + endpoints `/metrics` en runners).
- **GraphQL API** de GitLab (`pipeline`, `job`) para históricos.
- **Audit events** para quién lanzó / canceló / retried.

Un dashboard mínimo (Grafana) con 4 paneles cubre el 80%.

## 10. CI/CD y Argo CD: la frontera que no debes cruzar

La recomendación que atraviesa todo el programa:

- **GitLab construye y publica**: tests, scanners, build de imagen, firma, push al registry, bump de versión en manifiestos.
- **Argo CD aplica**: observa el repo de manifiestos y sincroniza con el cluster.

Por qué separar:

- **Blast-radius**: un error en el pipeline de CI no desplega; un error en Argo no construye nada que no esté en el repo.
- **Permisos**: GitLab no necesita credenciales de K8s; Argo no necesita credenciales del registry.
- **Audit**: cada cambio en producción es un commit en el repo de manifiestos. Trazable sin leer logs de pipelines.
- **Rollback**: `git revert` del manifiesto, Argo re-sincroniza. No "re-corras el pipeline del tag anterior".

Un ADR final del curso debería **justificar explícitamente** por qué no se usa `gitlab deploy` directo a K8s en producción (o justificar por qué sí, si el equipo es pequeño y el coste de operar Argo no se justifica).

## 11. Alternativas y qué llevarse

- **Jenkins → GitLab**: la migración es más dolorosa que GHA→GitLab porque Jenkins es más heterogéneo (plugins, groovy, agentes exóticos). Suele requerir rediseño por *pipeline family*, no port directo.
- **GitLab → GHA**: posible pero infrecuente; la mayor pérdida es el modelo de permisos jerárquico (grupos anidables) y el catálogo versionado con `spec:inputs:`.
- **Multi-plataforma intencional**: raramente justificado. Si lo haces, el *source of truth* del contrato debe ser un **Component GitLab + Reusable Workflow GHA generados desde un mismo spec** (que escribes tú o un pequeño script en Python/Go).
- **Monorepo gigante**: GitLab con `rules:changes:` + child pipelines escala mejor que GHA (`paths-filter` + reusable). Verificar en §12.

Lo esencial que llevarte:

1. Migración = proyecto finito con inventario, dual-run y criterios de corte.
2. Operar como plataforma = producto interno con catálogo, versionado, inner-source y métricas.
3. OIDC es la fuente nº1 de bugs de migración: pinnea por claims, no por `sub` literal.
4. Frontera CI/CD limpia: GitLab construye, Argo aplica.

## 12. Fundamentos internos (lo que suele doler en producción)

- **Includes anidados** tienen tope (histórico: ~100). Un catálogo que incluye catálogos puede chocar.
- **Rules evaluation**: `rules:` evalúa en orden y para en la primera match. Un `when: never` colgado al final no sirve si una regla anterior ya dijo `on_success`.
- **Needs y DAG**: `needs:` cruza stages. Si usas `needs:` olvidar el `artifacts: true` significa que no recibes outputs del dep.
- **Child pipelines**: ven variables heredadas pero no las que define el parent *runtime*. Pásalas vía `trigger: variables:`.
- **Protected environments vs branches**: puedes proteger un environment sin proteger la branch que lo despliega — y es una fuga típica.
- **Compliance pipelines**: se concatenan antes del `.gitlab-ci.yml` del proyecto. Si un dev define una variable con el mismo nombre, el override puede o no ganar según el nivel: documéntalo.
- **Catalog publishing** requiere `.gitlab/ci/releases.yml` y tagging SemVer disciplinado.
- **Métricas del exporter**: cardinal alto si etiquetas por job name. Agrega por proyecto para no explotar Prometheus.

Con estas 7 trampas cubres la mayor parte de los sustos post-migración.
