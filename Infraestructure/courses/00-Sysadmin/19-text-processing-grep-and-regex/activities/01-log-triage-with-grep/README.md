# Actividad 01 — Triage de un `access.log` con `grep` y amigos

## 1. Identificación

- **ID:** `sys-19-01-log-triage-with-grep`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-19-text-processing-grep-and-regex`
- **Dificultad:** advanced
- **Duración estimada:** 75 min
- **Tipo:** guided

## 2. Contexto

Son las 03:14 AM. PagerDuty te saca de la cama: "spike de 5xx en el edge". Lo único que tienes para operar en los primeros 10 minutos es un `access.log` de nginx recién bajado a `/tmp/`. **No hay Kibana, no hay Grafana, no hay Python disponible**. Solo tu shell.

Esta actividad simula ese momento. Dado un log sintético (~1200 líneas, formato nginx combined), vas a responder **10 preguntas** usando exclusivamente `grep`, `awk`, `sed`, `cut`, `sort`, `uniq`, `wc`.

## 3. Objetivos

- Elegir con criterio entre `grep -c`, `wc -l`, `awk 'END{print NR}'`.
- Combinar `sort | uniq -c | sort -rn | head` sin pensarlo.
- Reconocer qué preguntas se contestan **sin** regex (basta con columnas de `awk`) y cuáles necesitan patrones.
- Dejar las respuestas en un script `answers.sh` ejecutable y reproducible.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` (al menos §4, §7, §9).
- Shell POSIX, `grep`, `awk`, `sed`, `sort`, `uniq`, `wc`, `cut`, `tr`.
- `LC_ALL=C` recomendado para resultados deterministas.

**Costos**: ninguno. Todo local.

## 5. Instrucciones

### 5.1 Dataset

El archivo `starter/access.log` ya está en el repo. Es un log de nginx **sintético** con formato combined:

```
<ip> - - [<fecha>] "<verb> <path> HTTP/1.1" <status> <bytes> "<referrer>" "<user-agent>"
```

Cubre un rango de 24 h con mezcla de 2xx, 3xx, 4xx y un pico de 5xx concentrado en 2 horas.

### 5.2 Preguntas

Están en `starter/questions.md`. Son 10:

1. **Total de peticiones** en el log.
2. **Peticiones por método HTTP** (`GET`, `POST`, ...).
3. **Distribución por código de estado** (200, 304, 404, 500, ...), ordenada desc.
4. **Top 10 IPs** por número de peticiones.
5. **Top 10 URLs con 5xx**.
6. **User-agents** con más de 50 peticiones.
7. **IPs que recibieron solo 403** (nunca 2xx).
8. **Hora** (del día) con más 5xx.
9. **Peticiones a `/api/v1/*`** y su tasa de error (`4xx+5xx` sobre total).
10. **Rutas únicas** bajo `/api/v1/users/` (sin query string).

### 5.3 Entregable

Un script `starter/answers.sh` ejecutable. Por cada pregunta, imprime:

```
--- Q<n> ---
<pipeline(s) usados — pueden ser más de uno>
<salida>
```

Esqueleto ya listo en `starter/answers.sh` con `#!/usr/bin/env bash` + `set -euo pipefail` y 10 funciones `q1` .. `q10` vacías. Rellena cada una.

### 5.4 Validar

```bash
bash tests/validate.sh starter/answers.sh
```

El validador:

- Verifica que el script es ejecutable y pasa `shellcheck` (si está instalado).
- Lo ejecuta y comprueba que **imprime los 10 bloques** `--- Q1 --- ... --- Q10 ---`.
- Compara **cifras clave** (total de peticiones, número total de 5xx, IP top) contra valores conocidos del dataset.
- No valida al byte el formato de salida de cada pregunta — eso lo haces tú contra `solution/answers.sh`.

## 6. Resultado esperado

- `starter/answers.sh` produce las 10 respuestas.
- `tests/validate.sh` pasa.
- Puedes explicar por qué elegiste `grep` vs `awk` en cada una.

## 7. Criterios de aceptación

- [ ] Script ejecutable con `set -euo pipefail`.
- [ ] Shellcheck limpio (nivel por defecto).
- [ ] Las 10 preguntas respondidas.
- [ ] Al menos una respuesta usa `awk` con arreglo asociativo.
- [ ] Al menos una respuesta usa `grep -oE` para extraer parte de la línea.
- [ ] Pipeline Q7 (IPs que **solo** 403) usa dos pasadas o un `awk` de dos fases, **no** `grep -v 2`.

## 8. Validación

```bash
bash tests/validate.sh starter/answers.sh
```

## 9. Preguntas de reflexión

1. ¿En qué pregunta estuviste tentado de usar `cat | grep | grep | awk | awk`? ¿Cómo lo colapsarías en un solo `awk`?
2. Para Q8 (hora pico de 5xx) consideraste `substr` de `awk` o `cut -c` sobre el timestamp. ¿Cuál es más robusto frente a un cambio de formato de fecha?
3. Si el log tuviera 10 GB en lugar de 100 KB, ¿cuál de tus pipelines sería el más lento? ¿Por qué?

## 10. Extensiones (opcional)

- **E1** — Reescribe Q10 (rutas únicas) usando `grep -oP` con lookaround. Comenta las diferencias.
- **E2** — Añade una Q11: "p99 de bytes servidos por respuesta". ¿Puedes hacerlo en `awk`? ¿Hasta dónde?
- **E3** — Convierte `answers.sh` en un script que acepte el log como argumento (`$1`) y detecte si el formato cambia.

## 11. Limpieza

Ninguna. Todo vive dentro del directorio de la actividad.
