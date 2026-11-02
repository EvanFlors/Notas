# Preguntas — Triage de `access.log`

Para cada pregunta, deja la pipeline que usaste en la función correspondiente
de `answers.sh`. Imprime encabezado `--- Q<n> ---` antes de la salida.

1. **Q1** — ¿Cuántas peticiones hay en total en `access.log`?

2. **Q2** — Distribución por **método HTTP** (`GET`, `POST`, `PUT`, `DELETE`, `HEAD`).
   Formato: `<count> <method>` ordenado desc.

3. **Q3** — Distribución por **código de estado** (200, 301, 304, 403, 404, 500, 502, 503, 504), ordenado desc por conteo.

4. **Q4** — **Top 10 IPs** por número de peticiones.

5. **Q5** — **Top 10 URLs** que devolvieron un 5xx (cualquiera 500–599).

6. **Q6** — User-agents con **más de 50** peticiones. Formato: `<count> <user-agent>`.

7. **Q7** — IPs que **solo** recibieron 403 (nunca ningún otro código).
   Útil para detectar scanners bloqueados sistemáticamente.

8. **Q8** — **Hora del día** (00..23) con más errores 5xx. Formato: `<count> <HH>`.

9. **Q9** — Peticiones a cualquier ruta bajo `/api/v1/` y su **tasa de error** (`4xx+5xx` sobre el total de `/api/v1/`). Formato: `total=<N> errors=<N> rate=<pct>%`.

10. **Q10** — **Rutas únicas** bajo `/api/v1/users/` (sin tener en cuenta query string).
    Ordenadas alfabéticamente, una por línea.

## Notas

- El formato del log es nginx **combined**:
  `IP - - [FECHA] "VERB PATH HTTP/1.1" STATUS BYTES "REFERRER" "USER-AGENT"`
- Si eliges `awk`, el campo `$1` es la IP, `$6` es `"VERB`, `$7` es la ruta,
  `$9` es el status, `$10` son los bytes.
- Para el user-agent (que contiene espacios) usa `awk -F'"'` y recuerda que
  cada tramo entre comillas desplaza los índices.
