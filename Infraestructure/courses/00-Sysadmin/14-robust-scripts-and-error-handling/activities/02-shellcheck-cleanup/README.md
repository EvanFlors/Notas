# Actividad 02 — Limpieza con `shellcheck`

## 1. Identificación

- **ID:** `sys-14-02-shellcheck-cleanup`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-14-robust-scripts-and-error-handling`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** debug

## 2. Contexto

Heredaste `starter/dirty.sh`: funciona *a veces*. Un operador lo pasó por `shellcheck` y aparecieron una docena de findings. Tu trabajo es dejarlo pasando `shellcheck -S warning` sin findings, sin cambiar su semántica externa (recorre un directorio y reporta un resumen).

## 3. Objetivos

Al terminar deberías poder:

- Leer la salida de `shellcheck` y mapear cada código `SC####` a un problema concreto.
- Arreglar quoting (`SC2086`, `SC2046`) con criterio, no "por silenciar".
- Separar `local` de la asignación (`SC2155`) para preservar exit codes.
- Reemplazar `cd foo` por `cd foo || exit` o un chequeo explícito (`SC2164`).
- Justificar cada `# shellcheck disable=` que decidas dejar.

## 4. Prerrequisitos

- `bash` ≥ 4.0.
- `shellcheck` (`brew install shellcheck` / `apt install shellcheck`).

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Reproducir el problema

```bash
shellcheck -S warning starter/dirty.sh
```

Lee todos los findings. Cuenta cuántos distintos códigos `SC####` aparecen y haz una lista.

### 5.2 Ciclo de trabajo

```bash
cp starter/dirty.sh clean.sh
chmod +x clean.sh
```

Edita `clean.sh` arreglando los findings. Ciclo:

```bash
shellcheck -S warning clean.sh
# arregla el primer finding
# vuelve a correr
```

### 5.3 Reglas de limpieza

- **No cambies** lo que el script *hace* externamente (mismo output, mismos efectos).
- **No silencies** findings sin arreglarlos salvo que sea genuinamente intencional, y en ese caso añade un comentario adjunto:

  ```bash
  # shellcheck disable=SC2016  # queremos el literal $PATH en el patrón de grep
  grep '$PATH' /etc/environment
  ```

- Añade `set -euo pipefail` y `IFS=$'\n\t'` como parte del endurecimiento.

### 5.4 Verifica semántica

Prueba antes y después que la salida es equivalente:

```bash
bash starter/dirty.sh /etc >/tmp/before.out 2>/tmp/before.err || true
bash clean.sh         /etc >/tmp/after.out  2>/tmp/after.err  || true
diff /tmp/before.out /tmp/after.out || echo "(stdout cambió — revisa)"
```

(Los stderr pueden diferir; interesa stdout.)

### 5.5 Validar

```bash
bash tests/validate.sh ./clean.sh
```

Debe pasar con `OK: actividad completada correctamente.`.

## 6. Resultado esperado

- `clean.sh` arranca con `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`.
- `shellcheck -S warning clean.sh` termina con exit 0 y sin findings.
- La salida de stdout de `clean.sh DIR` es equivalente a la del starter.

## 7. Criterios de aceptación

- [ ] Calidad: 0 findings de `shellcheck -S warning`.
- [ ] Semántica: diff de stdout vs starter es vacío (para un directorio con contenido típico).
- [ ] Hygiene: cada `# shellcheck disable=` tiene comentario explicando por qué.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh ./clean.sh
```

Chequea: shebang y flags, `shellcheck -S warning` sin findings, equivalencia de stdout con el starter en un directorio generado para test.

## 9. Preguntas de reflexión

1. ¿Qué pasa realmente con `cd foo` cuando `foo` no existe y el script sigue? ¿Qué comando se ejecuta después y dónde?
2. `SC2155` dice: no uses `local x=$(cmd)`. Da un ejemplo donde ignorar este consejo te muerde en producción.
3. `SC2086` (quoting) ignorado: enumera **dos** formas en que una expansión no citada rompe tu script (una por word-splitting, otra por glob).
4. ¿Cuándo es legítimo silenciar un finding de shellcheck? Da un ejemplo real.

## 10. Extensiones (opcional)

- **E1** — Añade un modo `--json` que emita un resumen JSON por archivo.
- **E2** — Añade `set -o functrace` + `trap … DEBUG` detrás de `DEBUG=1` para instrumentar sin editar.
- **E3** — Pasa `shellcheck -S style`: ¿qué findings adicionales aparecen? ¿Vale la pena arreglarlos todos?

## 11. Limpieza

```bash
rm -f clean.sh /tmp/before.out /tmp/before.err /tmp/after.out /tmp/after.err
```
