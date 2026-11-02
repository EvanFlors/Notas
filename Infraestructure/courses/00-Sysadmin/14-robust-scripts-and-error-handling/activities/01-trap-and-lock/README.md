# Actividad 01 — Trap + lock: un job que sobrevive la vida real

## 1. Identificación

- **ID:** `sys-14-01-trap-and-lock`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-14-robust-scripts-and-error-handling`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes un script `job.sh` que escribe un reporte en un directorio temporal, lo copia a `OUT_DIR`, y termina. Al ponerlo en cron empiezan los problemas: a veces el cron se retrasa y lanza una segunda copia encima de la primera; a veces el operador lo mata con `Ctrl-C` y el tmpdir queda huérfano llenando `/tmp`. Toca endurecerlo.

## 3. Objetivos

Al terminar deberías poder:

- Activar `set -euo pipefail` + `IFS=$'\n\t'` con criterio.
- Registrar un `trap … EXIT` que borre el tmpdir pase lo que pase.
- Usar `flock -n` sobre un file descriptor para rechazar invocaciones concurrentes.
- Devolver exit codes semánticos (`0`, `75`, `70`).
- Pasar `shellcheck -S warning` sin findings.

## 4. Prerrequisitos

- `bash` ≥ 4.0.
- `flock` (paquete `util-linux`; viene instalado en casi todas las distros).
- `shellcheck` instalado (`brew install shellcheck` / `apt install shellcheck`).

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Lee el starter

```bash
cat starter/job.sh
```

El starter funciona en el caso feliz pero:

- No tiene `set -euo pipefail`.
- Crea un tmpdir y confía en un `rm -rf` al final del script (no corre si muere a mitad).
- No evita ejecuciones concurrentes.
- Devuelve siempre `exit 0`.

### 5.2 Prepara el entorno

```bash
mkdir -p /tmp/sys14-out
export OUT_DIR=/tmp/sys14-out
```

### 5.3 Ciclo de trabajo

Copia el starter a tu `job.sh` de trabajo y edítalo:

```bash
cp starter/job.sh job.sh
chmod +x job.sh
```

Haz estos cambios **en orden**, probando cada uno:

1. **Header duro.** Añade `set -euo pipefail` y `IFS=$'\n\t'` justo después del shebang.
2. **Logging.** Añade funciones `log_info`, `log_warn`, `log_error` que escriban a **stderr** con timestamp.
3. **Trap de cleanup.** Define `cleanup()` que haga `rm -rf "$tmpdir"` y preserve el exit code original. Regístralo con `trap cleanup EXIT`.
4. **Trap de señales.** Añade `trap … INT` y `trap … TERM` que terminen con `130` y `143` respectivamente, dejando que `EXIT` corra el cleanup.
5. **Lock.** Antes del trabajo pesado, abre `exec 9>"$LOCK_FILE"` y usa `flock -n 9`. Si falla, loguea y `exit 75` (EX_TEMPFAIL).
6. **Exit codes.** Define constantes `EX_SOFTWARE=70` y `EX_TEMPFAIL=75` al tope y úsalas.
7. **shellcheck.** Corre `shellcheck -S warning job.sh` hasta tener 0 findings.

### 5.4 Probar cleanup

```bash
./job.sh
ls /tmp | grep job-tmp || echo "ok: no quedó tmpdir"
```

### 5.5 Probar lock concurrente

En una terminal:

```bash
SLOW=5 ./job.sh
```

En otra, mientras duerme:

```bash
./job.sh; echo "exit=$?"
```

La segunda debe salir casi inmediatamente con `exit 75` y un mensaje de "otra instancia corriendo".

### 5.6 Probar cleanup bajo señal

```bash
SLOW=10 ./job.sh &
pid=$!
sleep 1
kill -INT "$pid"
wait "$pid"; echo "exit=$?"
ls /tmp | grep job-tmp || echo "ok: no quedó tmpdir tras SIGINT"
```

Debe terminar con `exit 130` y sin basura.

### 5.7 Validar

```bash
bash tests/validate.sh ./job.sh
```

Debe terminar con `OK: actividad completada correctamente.`.

## 6. Resultado esperado

- `job.sh` arranca con `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`.
- Pasa `shellcheck -S warning` sin findings.
- Ejecución normal: exit 0 y sin tmpdir residual.
- Ejecución concurrente: segunda invocación exit 75.
- Ejecución con `SIGINT`: exit 130 y sin tmpdir residual.

## 7. Criterios de aceptación

- [ ] Funcionalidad: cleanup se ejecuta en los 3 caminos (éxito, fallo, SIGINT).
- [ ] Concurrencia: `flock -n` rechaza la segunda invocación con exit 75.
- [ ] Calidad: `shellcheck -S warning` con 0 findings.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh ./job.sh
```

Chequea: shebang y flags, pasa shellcheck, cleanup tras ejecución normal, lock rechaza concurrente con exit 75, cleanup tras SIGINT.

## 9. Preguntas de reflexión

1. ¿Por qué `flock -n 9` es más seguro que `[[ -f lock ]] || touch lock` para prevenir dobles ejecuciones?
2. ¿Qué pasa si matas el proceso con `kill -9` (SIGKILL)? ¿Se libera el lock de `flock`? ¿Y el tmpdir?
3. ¿Qué exit code usarías si el `OUT_DIR` configurado no existe y no se puede crear? Justifica con `sysexits.h`.
4. En `cleanup()`, ¿por qué guardas `$?` en la primera línea y lo re-emites con `exit "$rc"` al final?

## 10. Extensiones (opcional)

- **E1** — Añade un retry con backoff para el "trabajo pesado" simulado (hasta 3 intentos).
- **E2** — Hazlo `Persistent=true`-friendly: si el job se saltó un trigger de cron por downtime, al correr debería detectarlo y loguear "ejecutando con retraso de Nm".
- **E3** — Añade un `--dry-run` que loguee lo que haría sin tocar `OUT_DIR`.

## 11. Limpieza

```bash
rm -rf /tmp/sys14-out /var/lock/sys14-job.lock 2>/dev/null || true
rm -f job.sh
```
