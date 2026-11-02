# Actividad 02 — Diagnosticar una regresión de boot

## 1. Identificación

- **ID:** `sys-07-02-debug-boot-regression`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-07-boot-process-and-systemd`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** debug

## 2. Contexto

Un compañero empujó una unidad `broken.service` al servidor y ahora `systemctl status` la marca como `failed`. Tu tarea es diagnosticar sin pedir pistas, usando solo las herramientas estándar de systemd. La solución está en `solution/README.md` — no la mires hasta tener un diagnóstico escrito.

Esta actividad entrena el *loop* real: reproducir, aislar con `systemd-analyze verify`, leer `journalctl -b`, usar `systemctl status`, proponer fix mínimo, reinstalar, re-verificar.

## 3. Objetivos

Al terminar deberías poder:

- Instalar una unidad y ver que falla.
- Usar `systemd-analyze verify` para encontrar errores de syntax o semántica.
- Leer `journalctl -u <unit> -b` para localizar el mensaje real del failure.
- Interpretar el estado y los exit codes de `systemctl status`.
- Proponer un fix mínimo (una línea cambia, no reescribir el archivo).

## 4. Prerrequisitos

- Haber completado la actividad 01.
- Linux con systemd, `sudo`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Instala el servicio roto

```bash
sudo install -m 0644 starter/broken.service /etc/systemd/system/broken.service
sudo systemctl daemon-reload
sudo systemctl start broken.service || true   # SE ESPERA QUE FALLE
```

### 5.2 Observa el síntoma

```bash
systemctl status broken.service --no-pager --full
```

Anota:

- `Loaded:` → ¿cuál es el estado?
- `Active:` → `failed` esperado. ¿Con qué `(Result: ...)`?
- `Process:` → ¿cuál es el exit code?
- Las últimas líneas del log inline.

### 5.3 Verifica la syntax

```bash
sudo systemd-analyze verify /etc/systemd/system/broken.service
```

**Lee cada warning con cuidado.** Hay al menos un problema que `verify` detecta antes de intentar arrancar nada.

### 5.4 Lee los logs completos del servicio

```bash
journalctl -u broken.service -b --no-pager
```

Correlaciona el mensaje de error con una línea específica del archivo. Un buen diagnóstico cita la línea y explica por qué está mal.

### 5.5 Formula hipótesis y escribe un fix

Edita (copia primero) el archivo:

```bash
sudo cp /etc/systemd/system/broken.service /tmp/broken.service.bak
sudo $EDITOR /etc/systemd/system/broken.service
```

Haz **la mínima** modificación posible. No reescribas el archivo, no borres directivas que no son el problema.

### 5.6 Re-verifica y re-arranca

```bash
sudo systemd-analyze verify /etc/systemd/system/broken.service
sudo systemctl daemon-reload
sudo systemctl restart broken.service
systemctl status broken.service --no-pager --full
```

Debe quedar `active (running)` o `active (exited)` según el tipo. Si no, vuelve al paso 5.3.

### 5.7 Valida

```bash
bash tests/validate.sh
```

Debe terminar `OK: broken.service está activo y verify limpio`.

## 6. Resultado esperado

- `systemctl is-active broken.service` → `active`.
- `systemd-analyze verify` sin output.
- Un breve diagnóstico escrito (puedes ponerlo en `starter/diagnostico.md`) que contenga: síntoma observado, herramienta usada, línea culpable, fix aplicado.

## 7. Criterios de aceptación

- [ ] **Funcionalidad**: servicio arranca.
- [ ] **Calidad**: fix mínimo (idealmente una sola línea cambiada).
- [ ] **Diagnóstico**: identifica línea y causa en lenguaje claro.
- [ ] **Metodología**: usaste `verify`, `status`, `journalctl` en ese orden (o justificable).

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué herramienta te dio la pista más clara: `verify`, `status`, o `journalctl`? ¿Siempre será la misma?
2. Si `systemd-analyze verify` queda limpio pero el servicio sigue fallando, ¿dónde buscas?
3. Si el `ExecStart=` apunta a un binario inexistente, ¿qué dice `status`? ¿Y `verify`?
4. ¿Qué habría pasado si el servicio estuviera habilitado al boot (`enable`) y hubieras rebooteado antes de diagnosticar?
5. ¿Cómo prevendrías esta regresión en un pipeline de CI? (pista: `systemd-analyze verify` corre sin root).

## 10. Extensiones (opcional)

- **E1** — Reproduce el flujo con `journalctl -b -1` simulando que el error ocurrió en el boot anterior.
- **E2** — Agrega el servicio al target `multi-user.target`, reboota (en VM) y verifica que el fix sobrevive.
- **E3** — Escribe un hook de pre-commit que ejecute `systemd-analyze verify` sobre todos los `.service` del repo.

## 11. Limpieza

```bash
sudo systemctl stop broken.service 2>/dev/null || true
sudo systemctl disable broken.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/broken.service
sudo systemctl daemon-reload
```
