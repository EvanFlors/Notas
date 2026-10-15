# Ejemplo 01 — Registrar un runner self-hosted a mano

> Walkthrough: qué comandos corres, qué archivos aparecen, qué pasa debajo. **No necesitas correrlo** para completar el módulo — está pensado para leerlo con atención. La actividad `01` reproduce el proceso contra un runner local real.

## Qué vas a ver

- De dónde descargas el binario del runner.
- Qué hace exactamente `config.sh`.
- Qué archivos aparecen en el filesystem.
- Cómo arranca el long-polling.
- Cómo apuntas un workflow a ese runner.
- Cómo desregistras limpiamente.

## 1. Preparación

Requisitos:

- Linux x64 (los comandos aquí); macOS/ARM tienen tarballs análogos.
- Un repo de prueba al que tengas permiso de admin: `https://github.com/<tu-user>/<repo-prueba>`.
- Un **registration token** del repo (lo generas desde la UI o la API; vive ~1 h).

Desde el repo en GitHub: *Settings → Actions → Runners → New self-hosted runner*. GitHub te enseña los comandos exactos. Son estos:

```bash
# 1. Carpeta aislada (NO en tu $HOME, por higiene)
mkdir -p /tmp/actions-runner && cd /tmp/actions-runner

# 2. Descarga del tarball (versión a verificar en la UI; aquí ilustrativo)
curl -o actions-runner-linux-x64-2.317.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz

# 3. (Opcional pero recomendado) verifica sha256
echo "<HASH-DE-LA-UI>  actions-runner-linux-x64-2.317.0.tar.gz" | sha256sum -c

# 4. Extrae
tar xzf ./actions-runner-linux-x64-2.317.0.tar.gz
ls
# bin/  config.sh  env.sh  externals/  run.sh  ...
```

## 2. Qué hace `config.sh`

```bash
./config.sh \
  --url https://github.com/<tu-user>/<repo-prueba> \
  --token <REG-TOKEN> \
  --name demo-runner \
  --labels demo,linux-local \
  --unattended \
  --ephemeral
```

Flags clave:

- `--url` — contra qué repo/org/enterprise se registra.
- `--token` — registration token *de un solo uso*, con vida corta.
- `--name` — nombre visible en la UI.
- `--labels` — labels custom (además de `self-hosted`, `linux`, `x64` que vienen por default).
- `--unattended` — no pide confirmaciones (necesario en scripts).
- `--ephemeral` — este runner acepta **un único job** y termina. Fundamental para seguridad (ver lesson §2.3).

Qué sucede debajo:

1. `config.sh` llama a la API de GitHub (`POST /repos/.../actions/runners/registration-token` *ya consumido*, luego `POST /repos/.../actions/runners`) intercambiando el reg-token por **credenciales permanentes del runner**.
2. Esas credenciales son una **clave RSA** emitida por GitHub, firmada por su CA interna.
3. Se escriben a disco:

   ```
   /tmp/actions-runner/
   ├── .runner                    # JSON: id, nombre, labels, pool
   ├── .credentials               # JSON: auth config
   ├── .credentials_rsaparams     # llave privada RSA (sensible)
   └── _diag/                     # logs
   ```

   > **Trata `.credentials_rsaparams` como un secreto.** Si lo exfiltran, pueden impersonar tu runner.

4. El runner aparece en la UI del repo como `Idle`.

## 3. Qué hace `./run.sh`

```bash
./run.sh
```

Arranca `Runner.Listener` en foreground. Logs típicos:

```
√ Connected to GitHub
Current runner version: '2.317.0'
Listening for Jobs
```

El Listener abre una conexión HTTPS saliente y hace **long-polling** (lesson §2.2). Si lo matas con Ctrl-C, el runner se marca `offline` tras ~1 min pero sigue registrado (no desaparece de la UI).

Para correrlo como servicio: `sudo ./svc.sh install && sudo ./svc.sh start` (crea una unit de systemd). En esta clase corremos foreground para ver qué pasa.

## 4. Usarlo desde un workflow

En el repo, `.github/workflows/hello-self-hosted.yml`:

```yaml
name: hello-self-hosted
on:
  workflow_dispatch:   # trigger manual para no mezclar con otros runs
jobs:
  hello:
    # Pedimos explícitamente nuestras labels. 'self-hosted' + custom.
    runs-on: [self-hosted, demo, linux-local]
    steps:
      - name: Who am I
        run: |
          echo "hostname=$(hostname)"
          echo "whoami=$(whoami)"
          echo "pwd=$(pwd)"
          echo "runner_name=$RUNNER_NAME"
          echo "runner_os=$RUNNER_OS"
      - name: Checkout
        uses: actions/checkout@v4
      - name: Fake test
        run: echo "all good"
```

Flujo:

1. Haces `gh workflow run hello-self-hosted.yml`.
2. GitHub encola un job con requisito `[self-hosted, demo, linux-local]`.
3. El Listener recibe el `JobAssignment` por su long-poll pendiente.
4. Spawnea `Runner.Worker` que:
   - crea `_work/<repo>/<repo>/`,
   - ejecuta `actions/checkout@v4` (clona el repo con un token efímero),
   - ejecuta los `run:`,
   - streamea stdout/stderr como logs.
5. Como registramos con `--ephemeral`, el Listener se autodesregistra y sale después del job. La UI muestra el runner como `Offline` → removido.

## 5. Desregistrar limpiamente (si no fue ephemeral)

```bash
cd /tmp/actions-runner
./config.sh remove --token <REMOVAL-TOKEN>
```

El removal token también se genera desde la UI (botón *Remove* → "copy script") o la API. Al terminar, `.runner`, `.credentials` y `.credentials_rsaparams` se borran. El runner desaparece del repo.

Si pierdes el runner (máquina destruida) sin desregistrar, puedes forzar la eliminación en la UI o con la API `DELETE /repos/.../actions/runners/<id>`.

## 6. Limpieza del scratch

```bash
cd /
rm -rf /tmp/actions-runner
```

(En la actividad usamos un wrapper que lo hace por ti.)

## 7. Qué quiero que leas con lupa

- **El binario del runner es open source**, pero las credenciales que `config.sh` guarda **no son un PAT tuyo** — son una llave RSA emitida por GitHub, única para ese runner.
- **El runner solo hace conexiones salientes.** Nunca GitHub inicia contra ti. Esto es lo que permite correr runners en una VPC privada sin abrir puertos.
- **`--ephemeral` es la diferencia entre "demo" y "producción decente"**. Un runner persistente te mete deuda de seguridad desde el minuto 1.
- **Las labels son el contrato con el workflow.** Un typo → el job queda esperando "indefinidamente" (en realidad hasta el timeout de 24 h).

Esto es lo mínimo mental para abordar `activities/01` sin susto.
