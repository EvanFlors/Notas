# Actividad 01 — Ejecutar un job en un runner self-hosted

## 1. Identificación

- **ID:** `gha-10-01-run-job-on-self-hosted`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-10-self-hosted-runners-and-arc`
- **Dificultad:** advanced
- **Duración estimada:** 45–75 min
- **Tipo:** guided-lab

## 2. Contexto

Quieres **ejecutar un workflow** en un runner que tú controlas, no en los hosted de GitHub. Esta actividad simula el registro + ejecución en modo **local**: no necesitas una cuenta GitHub de pruebas ni descargar el binario `actions-runner` para completarla. Modelamos los **artefactos** que el proceso real produce (el directorio del runner, `.runner`, `.credentials`, el workflow YAML) y los validamos.

Dos modos:

- **`MODE=local`** (default): simulación — produces los mismos archivos y YAML que generaría un registro real, con tokens dummy. **Esto es lo que valida el CI del curso.**
- **`MODE=live`**: si tienes un repo de pruebas tuyo + el binario descargado, puedes repetir contra GitHub real (opcional, documentado).

Ambos validan la misma estructura. El objetivo es que entiendas **qué deja el proceso en el filesystem** y **cómo se referencia desde un workflow**, no que descargues 300 MB.

## 3. Objetivos

Al terminar:

- Reproduces la estructura de archivos de un runner registrado (`.runner`, `.credentials`, labels).
- Escribes un workflow YAML que seleccione tu runner por labels custom.
- Explicas por qué `--ephemeral` es la opción de seguridad correcta.
- Pasas el validador automatizado.

## 4. Prerrequisitos

- `gha-01` completado.
- `bash`, `jq` (opcional, el validador no lo exige).
- **Modo `local`**: nada más.
- **Modo `live`** (opcional): docker/VM Linux x64, repo de pruebas tuyo, PAT con permisos de registration token.

**Costos:** $0 en ambos modos.

## 5. Instrucciones

### 5.1 Preparar

```bash
# Modo local (lo que valida el CI del curso)
MODE=local bash starter/bootstrap.sh /tmp/sh-runner

# Verás:
# [ok] directorio /tmp/sh-runner creado
# [ok] layout actions-runner simulado creado
# siguiente paso: completar runner-config.env, .runner y el workflow YAML
```

El starter deja un árbol:

```
/tmp/sh-runner/
├── actions-runner/
│   ├── bin/              # placeholders (no son binarios reales)
│   ├── externals/
│   ├── config.sh         # placeholder: imprime qué haría
│   ├── run.sh            # placeholder: imprime qué haría
│   ├── .runner.template  # te muestra el formato esperado
│   └── runner-config.env.template  # variables a definir
└── workflows/
    └── hello-self-hosted.yml.template
```

### 5.2 Tu tarea

Produce **tres archivos** a partir de los templates:

1. **`actions-runner/runner-config.env`** — exporta las variables que `config.sh` usaría:

   ```bash
   RUNNER_URL=https://github.com/<tu-user>/<repo-prueba>
   RUNNER_NAME=demo-runner
   RUNNER_LABELS=demo,linux-local
   RUNNER_EPHEMERAL=true
   RUNNER_WORK_FOLDER=_work
   ```

   El validador exige:
   - `RUNNER_URL` empieza con `https://github.com/`.
   - `RUNNER_NAME` no vacío.
   - `RUNNER_LABELS` contiene al menos una label custom (p. ej. `demo` o `linux-local`).
   - `RUNNER_EPHEMERAL=true`.

2. **`actions-runner/.runner`** — JSON que `config.sh` escribiría (puedes copiar del template `.runner.template` y rellenar):

   ```json
   {
     "agentId": 42,
     "agentName": "demo-runner",
     "poolId": 1,
     "serverUrl": "https://pipelines.actions.githubusercontent.com/...",
     "gitHubUrl": "https://github.com/<tu-user>/<repo-prueba>",
     "workFolder": "_work",
     "labels": [
       {"name": "self-hosted", "type": "system"},
       {"name": "linux",       "type": "system"},
       {"name": "x64",         "type": "system"},
       {"name": "demo",        "type": "user"},
       {"name": "linux-local", "type": "user"}
     ],
     "ephemeral": true
   }
   ```

   El validador exige: JSON válido, `ephemeral: true`, labels incluye `self-hosted` **y** al menos una `type: "user"`.

3. **`workflows/hello-self-hosted.yml`** — workflow que seleccione tu runner por labels custom. Mínimo:

   ```yaml
   name: hello-self-hosted
   on:
     workflow_dispatch:
   jobs:
     hello:
       runs-on: [self-hosted, demo, linux-local]
       steps:
         - name: Who am I
           run: |
             echo "runner_name=$RUNNER_NAME"
             echo "hostname=$(hostname)"
         - name: Checkout
           uses: actions/checkout@v4
   ```

   El validador exige:
   - YAML parseable.
   - `on` incluye `workflow_dispatch` (trigger manual, no `push`, para no mezclar con otros runs).
   - `runs-on` es una **lista** (array) y contiene `self-hosted` **y** al menos una label custom que esté también en `.runner`.
   - Al menos un step `run:` o `uses:`.

### 5.3 (Opcional) ejecutar los placeholders

```bash
cd /tmp/sh-runner/actions-runner
bash ./config.sh --help | head -3
# "simulated config.sh — would register against $RUNNER_URL as $RUNNER_NAME ..."
bash ./run.sh | head -3
# "simulated run.sh — would start Runner.Listener (long-polling) ..."
```

Esto solo refuerza que estos scripts, en real, hacen el trabajo. No ejecutan nada peligroso.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/sh-runner
```

Debe terminar con `OK: actividad completada correctamente.`.

### 5.5 Modo `live` (opcional, no requerido para el curso)

Si quieres hacerlo contra GitHub real:

1. Crea un repo de pruebas tuyo (private).
2. Desde la UI → *Settings → Actions → Runners → New self-hosted runner* copia los comandos reales.
3. Ejecútalos en una VM Linux (nunca en tu workstation si no te sientes 100% cómodo con lo que leíste en §5 de la lección).
4. Añade `--ephemeral` al `config.sh` manualmente.
5. Añade el workflow `hello-self-hosted.yml` en el repo, triggerea con `gh workflow run hello-self-hosted.yml`.
6. Al terminar el job, el runner se autodesregistra y el proceso sale.

No hay validador para `MODE=live` — es una extensión personal.

## 6. Resultado esperado

- `/tmp/sh-runner/actions-runner/runner-config.env` presente y correcto.
- `/tmp/sh-runner/actions-runner/.runner` JSON válido con `ephemeral: true` y labels incluyendo `self-hosted` + ≥1 custom.
- `/tmp/sh-runner/workflows/hello-self-hosted.yml` YAML válido con `runs-on: [self-hosted, <label-custom>, ...]`.
- `tests/validate.sh` pasa.

## 7. Criterios de aceptación

- [ ] `runner-config.env` presente con todas las vars requeridas.
- [ ] `.runner` JSON válido, `ephemeral=true`, labels con `self-hosted` + custom.
- [ ] `workflows/hello-self-hosted.yml` YAML válido, `runs-on` es lista con `self-hosted` + custom coincidente.
- [ ] `on:` incluye `workflow_dispatch`.
- [ ] `validate.sh` pasa en `MODE=local`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sh-runner
```

Checa (en orden):

1. Directorio existe y layout del starter está.
2. `runner-config.env` tiene las 5 vars y `RUNNER_EPHEMERAL=true`.
3. `.runner` es JSON válido (parseado con `python3 -c 'import json...'`), tiene `ephemeral: true`, y las labels contienen `self-hosted` + ≥1 label custom.
4. `hello-self-hosted.yml` es YAML válido (parseado con `python3 -c 'import yaml...'` si está disponible, si no un check estructural con grep).
5. `runs-on` del workflow contiene `self-hosted` y al menos una label custom que **también esté** en el `.runner` (contrato real).

## 9. Preguntas de reflexión

1. ¿Por qué `--ephemeral` es la opción de seguridad correcta? Da un escenario concreto donde un runner persistente filtre datos entre jobs.
2. ¿Por qué el workflow usa `workflow_dispatch` y no `push` en este lab? ¿Qué pasaría si fuese `push: branches: [main]` y alguien hiciera 50 pushes?
3. ¿Dónde vive la **clave privada RSA** del runner (`.credentials_rsaparams`)? ¿Qué pasa si la copias a otra máquina?
4. ¿Qué respondería `curl -v https://api.github.com` desde una máquina sin internet? ¿Por qué el runner no funcionaría allí?
5. Si cambiaras `RUNNER_LABELS` quitando `linux-local` pero dejas el workflow pidiendo `[self-hosted, demo, linux-local]`, ¿qué pasaría con el job? ¿Cuánto tiempo esperaría GitHub?

## 10. Extensiones (opcional)

- **E1** — Añade un segundo workflow con `runs-on: [self-hosted, gpu]` y verifica (mentalmente) que *no* lo picaría tu runner por falta de la label `gpu`.
- **E2** — Lee `_diag/Runner_*.log` de un runner real (si corres `MODE=live`) e identifica el long-polling en los logs.
- **E3** — Investiga `svc.sh install` y describe qué unit de systemd produce (en 3 líneas).
- **E4** — Diseña un runner group `oss-fork-safe` para una org con 2 repos públicos y escribe la justificación de por qué ningún secret live va en él.

## 11. Limpieza

```bash
rm -rf /tmp/sh-runner
```
