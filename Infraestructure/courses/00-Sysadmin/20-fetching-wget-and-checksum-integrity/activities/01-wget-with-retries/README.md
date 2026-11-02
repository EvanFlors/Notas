# Actividad 01 — Descarga con resume, timeouts y reintentos

## 1. Identificación

- **ID:** `sys-20-01-wget-with-retries`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-20-fetching-wget-and-checksum-integrity`
- **Dificultad:** advanced
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Un pipeline de deploy necesita bajar un tarball antes de instalarlo. La red puede fallar; el servidor puede estar reiniciando; el link puede cortarse a mitad. El script debe sobrevivir a todo eso o **fallar claro** y rápido.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `wget` con `--continue`, `--tries`, `--waitretry`, `--connect-timeout`, `--read-timeout` y `--retry-connrefused`.
- Fallar con exit code semántico no-cero cuando se agotan reintentos.
- **No** usar `--no-check-certificate` ni ninguna variante que silencie TLS.
- Loggear a `stderr` con timestamp cada intento y resultado.
- Pasar `shellcheck -S warning` sin findings.

## 4. Prerrequisitos

- `wget` ≥ 1.20, `bash` ≥ 4, `shellcheck` instalado.
- Conectividad a Internet (el test usa un recurso público pequeño).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
cd activities/01-wget-with-retries
cp starter/fetch.sh fetch.sh      # trabaja sobre copia
```

### 5.2 Completar `fetch.sh`

Debe aceptar dos argumentos:

```bash
./fetch.sh <URL> <OUT_PATH>
```

Requisitos:

1. `#!/usr/bin/env bash` + `set -euo pipefail` + `IFS=$'\n\t'`.
2. Validar que recibió exactamente **2** argumentos; si no, salir con **exit 2** y mensaje a `stderr`.
3. Crear el directorio padre de `OUT_PATH` si no existe.
4. Invocar `wget` con **todas** estas opciones:
   - `--continue`
   - `--tries=5`
   - `--waitretry=10`
   - `--connect-timeout=10`
   - `--read-timeout=30`
   - `--retry-connrefused`
   - `--output-document=<OUT_PATH>`
5. Si `wget` falla, salir con **exit 69** (`EX_UNAVAILABLE`) y mensaje de error a `stderr` con URL y OUT_PATH.
6. Loggear a `stderr` con prefijo `[timestamp-ISO8601] INFO|OK|ERROR` cada paso relevante.
7. **Prohibido**: `--no-check-certificate`, `-k`, `--insecure`, `curl`.

### 5.3 Correr `shellcheck`

```bash
shellcheck -S warning fetch.sh
```

Debe salir sin findings.

### 5.4 Prueba manual

```bash
./fetch.sh https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz /tmp/sys20-act1/hello.tar.gz
echo "exit code: $?"
```

### 5.5 Validar

```bash
bash tests/validate.sh
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `fetch.sh` baja el artefacto; con URL inválida falla con exit `69`.
- Con 0 o 1 argumentos, falla con exit `2`.
- `shellcheck -S warning` limpio.
- Nunca aparece texto que silencie TLS.

## 7. Criterios de aceptación

- [ ] Funcionalidad: descarga exitosa + fallo claro ante URL rota.
- [ ] Calidad: `shellcheck -S warning` sin findings.
- [ ] Seguridad: ninguna flag inseguridad TLS.
- [ ] Reproducibilidad: `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

Chequea: shebang y `set -euo pipefail`, presencia de todas las flags requeridas, ausencia de flags prohibidas, exit `2` sin args, exit `69` ante URL inexistente, descarga exitosa de recurso real, `shellcheck -S warning` limpio.

## 9. Preguntas de reflexión

1. ¿Por qué `--read-timeout` y `--connect-timeout` separados en vez de `--timeout` genérico?
2. ¿En qué escenario `--retry-connrefused` cambia el resultado?
3. ¿Qué pasa si usás `--tries=0`? ¿Por qué es mala idea para un script invocado por `cron`?
4. Un compañero propone agregar `--no-check-certificate` "para staging". Argumentá por qué no.

## 10. Extensiones (opcional)

- **E1** — Agregá un `trap` que, ante `SIGINT`, borre descargas parciales (`.wget` o `OUT_PATH`) si no se completaron.
- **E2** — Parametrizá `--tries` y `--waitretry` vía variables de entorno con defaults.
- **E3** — Agregá soporte para loggear a un archivo además de `stderr` (sin perder `stderr`).

## 11. Limpieza

```bash
rm -rf /tmp/sys20-act1 fetch.sh
```
