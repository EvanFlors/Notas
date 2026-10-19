# Actividad 01 — Review Apps end-to-end: `.gitlab-ci.yml` + ADR

## 1. Identificacion

- **ID:** `gl-07-01-review-apps-end-to-end`
- **Tecnologia:** `gitlab-cicd`
- **Modulo:** `gl-07-environments-deployments-and-review-apps`
- **Dificultad:** advanced
- **Duracion estimada:** 80–100 min
- **Tipo:** guided-lab (independent — sin dependencia de la actividad 02)

## 2. Contexto

Tu equipo de 6 ingenieros abre entre 10 y 20 MRs por semana en el repo `web-frontend` (Next.js). Los reviewers piden "quiero ver el cambio corriendo" en cada MR; hoy lo resuelven clonando la rama y arrancando el server en local, lo que tarda 5-10 min y rompe el flujo del reviewer. Quieres ofrecer un **Review App** por MR: un preview URL automatico, destruido cuando el MR se cierra.

Infraestructura asumida: existe un bucket S3 por entorno y un script `deploy_preview.sh <mr-id> <dist-dir>` que ya hace el `aws s3 sync` y devuelve la URL. Hay otro script `destroy_preview.sh <mr-id>` que borra. No tienes que escribir estos scripts — tienes que escribir el pipeline que los invoca correctamente como Review App.

**Importante**: no se despliega nada real. El entregable es el **`.gitlab-ci.yml` + un ADR** que justifica por que usar Review Apps nativas de GitLab y no replicar el patron a mano en, por ejemplo, GitHub Actions.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Escribir el par `review` + `stop_review` canonico con los 5 keywords clave de `environment:`.
- Entender por que `on_stop:` necesita que el nombre del environment sea identico en los dos jobs.
- Filtrar correctamente con `rules:` para que los jobs solo corran en MR events.
- Elegir un valor razonable de `auto_stop_in:` y justificarlo.
- Documentar la decision en un ADR legible por alguien que no estuvo en la discusion.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` §1-5 (modelo, Review Apps, `auto_stop_in`).
- Haber recorrido `../../examples/02-review-apps-on-mr/`.
- Haber completado `gl-04` (rules/workflow).
- Herramientas locales: `bash`, `python3` con `pyyaml` instalado (`pip install pyyaml` o `apt install python3-yaml`), editor Markdown.

**Costos**: ninguno. Todo es papel/YAML.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gl-07-01-review-apps
cd /tmp/gl-07-01-review-apps
```

Si usas otro path, pasalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `.gitlab-ci.yml`

El pipeline debe tener al menos tres jobs:

1. **`build`** — compila el frontend (puede ser `mkdir -p dist && echo ok > dist/index.html`, no importa el contenido). Produce `artifacts: paths: [dist/]`. Filtrado para correr en MRs.
2. **`review`** — despliega el preview. Debe tener:
   - `environment.name` que incluya `$CI_MERGE_REQUEST_IID`.
   - `environment.url` con la misma variable en el host.
   - `environment.on_stop: stop_review`.
   - `environment.auto_stop_in` con un valor razonable (ej. `3 days` a `1 week`).
   - `rules:` que filtre a `$CI_PIPELINE_SOURCE == "merge_request_event"`.
3. **`stop_review`** — teardown. Debe tener:
   - `environment.name` **identico** al de `review`.
   - `environment.action: stop`.
   - `rules:` con `when: manual` filtrado a MR events.
   - `allow_failure: true`.

### 5.3 Escribe `ADR-REVIEW-APPS.md`

Formato ADR estandar:

```
# ADR 001 — Review Apps por MR en GitLab

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 parrafos: que problema resuelves, cual es el flujo actual, que constraints hay)

## Decision
(La decision concreta: usar Review Apps nativas, con la estructura
del .gitlab-ci.yml, el valor elegido de auto_stop_in, y por que
el patron equivalente en GHA no justifica el esfuerzo.)

## Consecuencias
(Positivas y negativas. Debe incluir impacto en coste de infraestructura
—buckets S3 vivos— y en experiencia del reviewer.)

## Alternativas descartadas
(Al menos 2: ej. "preview manual via docker compose en la laptop del reviewer"
y "pipeline a mano en GHA equivalente".)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decision`** (o `Decision`, con o sin tilde).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2).

Contenido minimo obligatorio:

- Mencion explicita de **Review Apps** y de **`on_stop:`**.
- Mencion de **`auto_stop_in`** con el valor elegido y por que.
- Mencion de **GitHub Actions** o **GHA** como alternativa comparada.
- Mencion de **`CI_MERGE_REQUEST_IID`** como variable del dominio GitLab.
- Al menos un **bloque de codigo** (fences `` ``` ``) con un snippet de referencia.

### 5.4 Entregables

```
/tmp/gl-07-01-review-apps/
├── .gitlab-ci.yml
└── ADR-REVIEW-APPS.md
```

## 6. Resultado esperado

- `.gitlab-ci.yml` existe, parsea como YAML valido y tiene las claves correctas.
- `ADR-REVIEW-APPS.md` tiene las 6 secciones y las menciones obligatorias.
- El validador pasa en verde.

## 7. Criterios de aceptacion

- **Funcionalidad**: el `.gitlab-ci.yml` seria valido para GitLab (keys reconocidas, estructura canonica).
- **Calidad**: el ADR justifica cada decision (no solo lista).
- **Reproducibilidad**: alguien podria tomar el `.gitlab-ci.yml` y los scripts `deploy_preview.sh` / `destroy_preview.sh` y publicarlo tal cual.
- **Mantenibilidad**: YAML con indentacion consistente, Markdown valido, bloques de codigo con fences.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/gl-07-01-review-apps
```

El validador comprueba **estructura y palabras clave**, no la semantica de que el preview realmente despliegue algo. Compara con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexion

1. ¿Que pasa si `auto_stop_in` es muy corto (ej. `1 hour`)? ¿Y si es `never`?
2. Si el job `stop_review` falla (p. ej. el bucket ya no existe), ¿que pasa con el environment en la UI?
3. ¿Por que `rules: when: manual` en `stop_review` y no `always`?
4. Si tuvieras 50 MRs abiertos a la vez, ¿que limites de recursos deberian preocuparte?
5. ¿Como integrarias un smoke test post-deploy del Review App que falle el pipeline si la URL devuelve 500?

## 10. Extensiones

- Añade un job `smoke_review` que haga `curl` a `$CI_ENVIRONMENT_URL` tras `review` y falle si no responde 200.
- Documenta en el ADR como integrarias DAST (zAProxy) corriendo contra el Review App.
- Diseña una `include:` que extraiga el patron Review App como pieza reutilizable (adelanto de `gl-05` CI/CD Components).

## 11. Limpieza

```bash
rm -rf /tmp/gl-07-01-review-apps
```

No hay procesos ni infraestructura que detener.
