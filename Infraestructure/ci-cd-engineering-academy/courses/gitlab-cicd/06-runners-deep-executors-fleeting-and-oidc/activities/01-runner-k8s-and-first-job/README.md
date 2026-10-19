# Actividad 01 — Runner K8s y primer job

## 1. Identificación

- **ID:** `gl-06-01-runner-k8s-and-first-job`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-06-runners-deep-executors-fleeting-and-oidc`
- **Dificultad:** intermediate
- **Duración estimada:** 70–100 min
- **Tipo:** guided-lab (independent — sin dependencia de la actividad 02)

## 2. Contexto

Te piden operar un GitLab Runner compartido en el cluster EKS del equipo platform. El equipo quiere:

- Un **runner "shared"** en el namespace `gitlab-runner` del cluster.
- Jobs **rootless y no privilegiados** por defecto.
- **Cache S3** para `node_modules` y `.gradle` usando IRSA (sin keys en el chart).
- Un pipeline de ejemplo `.gitlab-ci.yml` que tag-ea `k8s` y construye con **Kaniko** (no DinD).

No vas a levantar el cluster. Vas a producir los **artefactos de configuración** (YAML + TOML + YAML del pipeline) y a dejar en `NOTES.md` por qué eliges Kaniko sobre DinD.

**Importante**: no hay cluster real. No se despliega nada. El entregable son archivos.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Diferenciar `runnerRegistrationToken` (deprecado) de `runnerToken` (`glrt-...`).
- Escribir una sección `[runners.kubernetes]` con límites de CPU/memoria razonables.
- Elegir `privileged = false` y defender por qué.
- Enumerar 3 problemas de DinD vs Kaniko.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 2, 3 y 4).
- Haber recorrido `../../examples/01-k8s-executor-chart/`.
- Herramientas: `bash`, `jq`, `python3` (con `yaml` y `tomllib` — stdlib desde 3.11).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-06-runner-k8s
cd /tmp/gl-06-runner-k8s
```

Puedes usar otro directorio: pasa la ruta al validador (`bash tests/validate.sh /tu/ruta`).

### 5.2 Escribe `values.yaml`

Para el chart `gitlab/gitlab-runner`. Mínimo que exige el validador:

- `gitlabUrl` presente y apuntando a `https://gitlab.com/` (o self-managed).
- `runnerToken` presente y con prefijo `glrt-` (puede ser un placeholder, no un token real).
- `rbac.create: true`.
- `concurrent` entero >= 1.
- Bloque `runners.config` que contenga un `[[runners]]` con `executor = "kubernetes"` y `privileged = false`.
- `runners.tags` que incluya `k8s`.

### 5.3 Escribe `config.toml`

Versión "standalone" de la misma configuración, como la operarías en una VM con systemd. Debe:

- Ser TOML válido (parseable por `python3 -c "import tomllib; tomllib.load(open('config.toml','rb'))"`).
- Tener `concurrent` top-level.
- Tener al menos un `[[runners]]` con `name`, `url`, `token`, `executor = "kubernetes"`.
- Tener `[runners.kubernetes]` con `privileged = false` y al menos un `*_request` de recursos (`cpu_request`, `memory_request`).

### 5.4 Escribe `.gitlab-ci.yml`

Un pipeline mínimo que construya una imagen con Kaniko:

- Al menos un stage.
- Al menos un job con `tags:` que incluya `k8s`.
- Al menos un job que use una imagen que mencione `kaniko` o `buildkit`.
- Debe **no** usar `services: docker:dind` (el validador lo rechaza).

### 5.5 Escribe `NOTES.md`

Markdown corto justificando:

- Por qué `privileged = false` por defecto.
- Al menos 3 razones por las que prefieres Kaniko sobre DinD.
- Mención explícita de **IRSA** o **IAM role** del service account (para la cache S3).

Secciones (encabezados que el validador busca):

1. `## Decisión`
2. `## Por qué no DinD`
3. `## Cache S3 e IRSA`

### 5.6 Entregables

```
/tmp/gl-06-runner-k8s/
├── values.yaml
├── config.toml
├── .gitlab-ci.yml
└── NOTES.md
```

## 6. Resultado esperado

- Los 4 archivos existen.
- `values.yaml` y `.gitlab-ci.yml` son YAML válido.
- `config.toml` es TOML válido.
- `.gitlab-ci.yml` **no** contiene DinD.
- El validador pasa en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: `NOTES.md` justifica (no solo enumera).
- **Reproducibilidad**: alguien en Fase 4 podría `helm install -f values.yaml ...` sin ambigüedad.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-06-runner-k8s
```

El validador comprueba **estructura**. Compara con `solution/` para autoevaluación semántica.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `runUntagged: true` en el chart? ¿En qué escenarios lo querrías?
2. ¿Por qué `concurrent` en el chart es distinto de `capacity_per_instance` en Fleeting?
3. Si una política de seguridad te prohíbe `privileged`, ¿puedes aun así construir imágenes? ¿Cómo?
4. ¿Qué parte del `values.yaml` queda duplicada con la que iría en Terraform para el cluster y qué parte no?

## 10. Extensiones

- Añade un segundo `[[runners]]` con `tags: "dind,legacy"` y `privileged = true` para un pipeline heredado (y documenta en `NOTES.md` por qué está permitido *solo* para ese pipeline).
- Añade `node_selector` y `tolerations` para que los pods caigan en un node group spot.

## 11. Limpieza

```bash
rm -rf /tmp/gl-06-runner-k8s
```
