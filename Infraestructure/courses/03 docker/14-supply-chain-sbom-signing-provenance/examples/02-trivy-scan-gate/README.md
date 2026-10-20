# Ejemplo 02 — Trivy scan como gate de CI

## Concepto que demuestra

Usar `trivy image` con `--severity CRITICAL --exit-code 1` para convertir el escaneo de vulnerabilidades en un **gate binario**: si hay CVEs CRITICAL, el proceso sale con código ≠ 0 y el step de CI falla (y por tanto no se publica ni se firma).

## Contexto

El error #1 operacional con trivy es tratarlo como un reporte informativo (`trivy image img` siempre sale 0). Para que corte el pipeline hay que invocarlo con `--exit-code 1`.

Flags clave (ver `theory/lesson.md` §4.2):

- `--severity CRITICAL[,HIGH]` — qué cuenta.
- `--exit-code 1` — el gate.
- `--ignore-unfixed` — ignora CVEs sin parche (útil para no bloquear por ruido inarreglable).
- `--format sarif` — output para GitHub Security tab.
- `--scanners vuln,secret,misconfig` — qué tipos.

## Archivos

- `Dockerfile.sample` — imagen basada en una Alpine antigua para *garantizar* hallazgos sin red (la DB de trivy identificará CVEs del paquete `openssl` antiguo).
- `run.sh` — build + dos ejecuciones de trivy: una informativa, una como gate.

## Ejecución

```bash
bash run.sh
```

Flujo:

1. Build de la imagen demo.
2. `trivy image --severity CRITICAL,HIGH` **sin** `--exit-code` → reporte, sale 0.
3. `trivy image --severity CRITICAL --exit-code 1` → **gate**: sale 1 si hay CRITICAL.

El script captura el exit code y lo imprime para que veas que efectivamente cortó.

## Qué mirar

```bash
# Reporte informativo (siempre sale 0 incluso con hallazgos)
trivy image dkr-14-ex02-demo:v1 --severity HIGH,CRITICAL

# Gate (sale 1 si hay CRITICAL)
trivy image dkr-14-ex02-demo:v1 --severity CRITICAL --exit-code 1
echo "exit code: $?"

# Gate + ignore-unfixed (más laxo, útil cuando no hay parche upstream)
trivy image dkr-14-ex02-demo:v1 --severity CRITICAL --exit-code 1 --ignore-unfixed

# SARIF para upload a GitHub Security
trivy image --format sarif --output trivy.sarif dkr-14-ex02-demo:v1
```

## Lectura dirigida

1. ¿Cuál es la **primera CVE CRITICAL** que reporta? Verifica en NVD (<https://nvd.nist.gov/vuln/detail/CVE-...>).
2. ¿Cambia el resultado si usas `--ignore-unfixed`?
3. Si cambias la base a `alpine:3.19` (más nueva), ¿quedan CRITICAL?

## Limpieza

```bash
docker image rm dkr-14-ex02-demo:v1 2>/dev/null || true
rm -rf /tmp/dkr-14-ex02
```

## Referencias

- `theory/lesson.md` §4.2 (Trivy mecánica + flags).
- `resources/links.md` → trivy.
