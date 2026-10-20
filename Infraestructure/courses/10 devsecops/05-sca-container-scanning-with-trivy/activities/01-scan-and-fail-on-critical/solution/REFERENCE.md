# REFERENCE — sec-05-01-scan-and-fail-on-critical

> Una referencia razonada. No es la única respuesta correcta.

## Dockerfile de referencia

```dockerfile
# Base image VIEJA a proposito: alpine 3.14 (EOL, muchas CVEs)
FROM alpine:3.14

RUN apk add --no-cache python3 py3-pip

# Dependencia Python antigua a proposito
RUN pip3 install --no-cache-dir "requests==2.19.0"

CMD ["python3", "-c", "import requests; print(requests.__version__)"]
```

Decisiones:

- `alpine:3.14` está EOL (desde mayo 2023) y arrastra `openssl 1.1.1x` con parches viejos, `musl` con CVEs públicas y un `apk-tools` desactualizado. Garantiza al menos un puñado de `CRITICAL` con fix al correr Trivy.
- `requests==2.19.0` (de 2018) arrastra `urllib3<1.25` con `CVE-2020-26137` (HTTP header injection, CRITICAL en algunos tracking feeds). Garantiza al menos una vuln de **capa de lenguaje**, para que la actividad cubra las dos capas que `trivy image` escanea.
- `CMD python3 -c "import requests..."`: ejecuta algo trivial. No pedimos conectividad real; es solo para que la imagen sea "funcional".

## Scan 1 (exit=1) — comando y salida esperada abreviada

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$HOME/.cache/trivy:/root/.cache/trivy" \
  aquasec/trivy:0.56.2 image \
    --severity CRITICAL \
    --exit-code 1 \
    --ignore-unfixed \
    sec05-badimage:local
```

Salida esperada (resumida; los números varían con la DB):

```
sec05-badimage:local (alpine 3.14.X)
====================================
Total: N (CRITICAL: N)

Library    Vulnerability    Severity    Installed    Fixed      Title
openssl    CVE-2022-XXXX    CRITICAL    1.1.1l-r0    1.1.1w-r2  ...
libcrypto  CVE-2022-XXXX    CRITICAL    1.1.1l-r0    1.1.1w-r2  ...
libssl     CVE-2022-XXXX    CRITICAL    1.1.1l-r0    1.1.1w-r2  ...

sec05-badimage:local (python-pkg)
=================================
Total: M (CRITICAL: M)

Library    Vulnerability    Severity    Installed    Fixed      Title
urllib3    CVE-2020-26137   CRITICAL    1.22         1.25.9     ...
```

Y `echo "exit=$?"` → `exit=1`.

## `.trivyignore.yaml` de referencia

```yaml
# Excepciones de Trivy — cada entrada DEBE tener id, statement, expired_at.
vulnerabilities:
  - id: CVE-2022-XXXX
    statement: |
      CVE en openssl/libcrypto 1.1.1l en Alpine 3.14. En este lab la
      imagen solo corre un cliente HTTP de prueba — la ruta vulnerable
      (SSL/TLS server-side) no se ejecuta jamas. Aprobado por
      @security-lead unicamente a efectos pedagogicos. Fix real:
      subir a alpine:3.20 en la actividad 02.
    expired_at: 2026-12-31
```

Las tres claves obligatorias: `id`, `statement`, `expired_at`. Sin alguna de ellas el ignore es **technical debt silencioso** — nadie sabe por qué está, nadie sabe cuándo revisarlo.

## Scan 2 — cualquiera de los dos resultados es válido

- Si solo había esa `CRITICAL` → `exit=0`.
- Si quedan más `CRITICAL` → `exit=1`. Documéntalo en `POLICY.md` como "el ignore cubre una parte; el resto se arregla con el swap de base image del siguiente lab".

El punto pedagógico es que el `.trivyignore.yaml` **se consume** por Trivy (`--ignorefile`), no es un artefacto decorativo.

## POLICY.md de referencia (abreviado)

```markdown
# POLICY.md — gate de container scanning con Trivy

## Seccion A — Que bloquea el merge

- Severidad: `CRITICAL` con fix disponible (`--ignore-unfixed`).
- Fuente: `trivy image` sobre la imagen construida en el PR.
- Overrides permitidos: entradas en `.trivyignore.yaml` con `id`, `statement`, `expired_at`.
- La ausencia de `expired_at` convierte la entrada en invalida (pre-commit hook).

## Seccion B — Que NO bloquea (de momento)

- `HIGH` CVSS: warn via SARIF a Code Scanning, no bloquea.
- `CRITICAL` sin fix (`will_not_fix` upstream): trackeada aparte via nightly
  scan + ticket; no bloquea porque el developer del PR no puede arreglarla.
- `MEDIUM`/`LOW`: inventario, no bloquea.

## Seccion C — Cuando subir el gate a HIGH

- Si la CVE `HIGH` aparece en el catalogo **KEV** de CISA → bloquear inmediatamente.
- Si la CVE `HIGH` tiene **EPSS > 0.5** → bloquear.
- Si una auditoria externa (SOC2, PCI, cliente enterprise) exige "0 HIGH" → bloquear por scope de auditoria durante la ventana.

### Anti-patron

> "Fallamos en MEDIUM para 'estar seguros'" — insostenible: el ruido
> de la DB diaria lo rompe en una semana y el equipo lo deshabilita
> silenciosamente. Mejor subir el estandar por EPSS/KEV que por severidad bruta.
```

## Puntos a repetir hasta aburrir

1. **`--ignore-unfixed` no es "no me importa"** — es "no castigo a quien no puede arreglarlo". El tracking lo hace el nightly scan y el ticket.
2. **CVSS no es prioridad**: EPSS + KEV lo son. Subir el gate por severidad bruta genera ruido; subirlo por **señales de explotación real** genera acción.
3. **Toda excepción debe caducar**. Si tu `.trivyignore.yaml` nunca cambia, nadie lo mira.
4. **El gate es contrato, no capricho**. `POLICY.md` versionado en el repo cierra la discusión en PRs futuros ("¿por qué el gate es CRITICAL y no HIGH? → mira la sección C").
