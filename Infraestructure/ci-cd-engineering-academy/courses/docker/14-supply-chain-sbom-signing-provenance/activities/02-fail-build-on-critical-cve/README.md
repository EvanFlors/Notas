# dkr-14-02 — Fail build on CRITICAL CVE (trivy gate)

## 1. Identificación

- **ID:** `dkr-14-02-fail-build-on-critical-cve`
- **Tecnología:** docker
- **Módulo:** `14-supply-chain-sbom-signing-provenance`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Un escaneo de vulnerabilidades que **informa** sirve de poco: en CI debe ser un **gate binario**. `trivy image` **sale 0 siempre** salvo que le pases `--exit-code 1`. Este es el error #1 que se ve en pipelines reales: hay un step llamado "trivy scan" verde, nadie lee el log, y la imagen vulnerable se publica.

En esta actividad:

1. Partes de una imagen **deliberadamente antigua** (`alpine:3.14` o similar) que la DB de trivy marca con hallazgos CRITICAL.
2. Escribes `scan.sh` con el flag `--exit-code 1` y la severidad correcta.
3. Demuestras que el script **falla** cuando hay hallazgos y **pasa** cuando los filtras adecuadamente.

## 3. Objetivos

Ver `activity.yaml`.

## 4. Prerrequisitos

- `docker` + daemon.
- `trivy` instalado (si falta, el validator estructuralmente verifica tu `scan.sh` pero no corre el gate real; instrucciones de instalación en `theory/lesson.md` §2.1).

## 5. Instrucciones

### 5.1 Setup

```bash
bash starter/bootstrap.sh         # crea /tmp/dkr-14-02 con Dockerfile vulnerable + scan.sh stub
cd /tmp/dkr-14-02
cat NOTES.md
```

El scaffolding deja:

```
/tmp/dkr-14-02/
├── Dockerfile       # intencionalmente viejo (alpine:3.14 + openssl)
├── scan.sh          # STUB — tú lo completas
└── NOTES.md
```

### 5.2 Qué tienes que escribir

Completa `scan.sh` para que:

1. Haga `docker build -t dkr-14-02-vuln:v1 .` si la imagen no existe.
2. Ejecute `trivy image` con:
   - `--severity CRITICAL` (y opcionalmente `HIGH`).
   - `--exit-code 1`.
   - `--no-progress` para CI.
3. Capture el exit code de trivy y lo propague como exit code del script.
4. Imprima un mensaje claro `GATE: FAIL` o `GATE: OK`.

### 5.3 Variantes a probar (al menos dos)

- **Variante estricta**: `--severity CRITICAL --exit-code 1`.
- **Variante con `--ignore-unfixed`**: para no bloquear por CVEs sin parche upstream.

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/dkr-14-02
```

El validator:

- Chequea que `scan.sh` existe, es ejecutable, contiene `--severity CRITICAL` **y** `--exit-code 1`.
- Rechaza si tiene `set -o pipefail` combinado con `grep -q` (anti-patrón del curso).
- Si `docker` + `trivy` están instalados, ejecuta `scan.sh` y espera que **salga ≠ 0** (porque la imagen es deliberadamente vulnerable).

## 6. Resultado esperado

```
$ bash scan.sh
...
Total: 7 (CRITICAL: 7)
GATE: FAIL — CRITICAL vulnerabilities present. Blocking release.
$ echo $?
1
```

## 7. Criterios de aceptación

- **Funcional**: `scan.sh` sale 1 cuando hay CRITICAL, 0 cuando no.
- **Correcto**: ambos flags presentes (`--severity`, `--exit-code 1`).
- **Explícito**: imprime GATE OK / FAIL claramente.
- **Portable**: no asume rutas absolutas específicas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/dkr-14-02
```

## 9. Preguntas de reflexión

1. ¿Por qué `trivy image` sale 0 por default aunque haya CVEs CRITICAL?
2. Cuándo es **correcto** usar `--ignore-unfixed` y cuándo **no**?
3. Trivy tiene un *vulnerability DB* local que se actualiza automáticamente. ¿Qué pasa si corres el gate en un runner offline?
4. ¿Qué ganas scaneando también `--scanners misconfig,secret` además de `vuln`?
5. ¿Dónde deberías correr el gate: antes de firmar, después de firmar, o ambos?

## 10. Extensiones

- Añade `--format sarif --output trivy.sarif` y súbelo al GitHub Security tab (`github/codeql-action/upload-sarif@v3`).
- Añade un `.trivyignore` con una CVE específica y documenta por qué la ignoras.
- Encapsula el gate en un step de GHA que falle el workflow.

## 11. Limpieza

```bash
docker image rm dkr-14-02-vuln:v1 2>/dev/null || true
rm -rf /tmp/dkr-14-02
```
