# Lección — sec-05: SCA y container scanning con Trivy

> Lectura profunda. ~45–60 min. Pensada para leerla **antes** de tocar los ejemplos y las actividades.

---

## 1. El problema: dos capas de dependencias ajenas

Toda aplicación productiva depende de **dos capas** de código que no controlas:

1. **Dependencias de lenguaje** (`requirements.txt`, `package-lock.json`, `go.sum`, `Cargo.lock`): librerías de 3P que compilas o instalas con tu app. Esto es **SCA — Software Composition Analysis**.
2. **La base image**: todo lo que viene en `FROM python:3.12`. Entre el sistema operativo mínimo y el runtime hay **cientos** de paquetes (`openssl`, `libc`, `curl`, `coreutils`, `perl`, `python-stdlib`…) de los que no sabes nada. Esto es **container scanning**.

Un scanner serio tiene que atacar **ambas** capas con la misma herramienta y la misma política, porque un CVE crítico en `openssl` dentro de la base image no es cualitativamente distinto a un CVE crítico en `requests` dentro de `requirements.txt`: ambos corren en el mismo proceso, ambos pueden ser el vector de entrada.

Trivy nace precisamente de esta observación.

## 2. ¿Qué es Trivy?

**Trivy** (de Aqua Security) es un **scanner multi-propósito, open source, de un solo binario**, que cubre:

- **Vulnerabilidades en paquetes de SO** (Alpine `apk`, Debian/Ubuntu `apt`, RHEL/CentOS `rpm`, Amazon Linux, Oracle, Rocky, SUSE, Mariner, etc.).
- **Vulnerabilidades en paquetes de lenguaje** (Python PyPI, Node npm, Go modules, Java Maven/Gradle, .NET NuGet, Ruby Gems, Rust Cargo, PHP Composer, etc.) leyendo los **lockfiles**.
- **Misconfigs IaC**: Dockerfile, Terraform (HCL), Kubernetes manifests, Helm, CloudFormation, Ansible — con reglas built-in (Appshield / Aqua), antes se llamaba `tfsec` cuando era un proyecto aparte; hoy está fusionado.
- **Secretos filtrados** (reglas built-in para AWS keys, GitHub tokens, Slack webhooks, etc.) — complementa a `gitleaks`, no lo reemplaza.
- **Licencias** (detecta GPL, AGPL, etc. en dependencias — útil para compliance legal).
- **Generación de SBOM** en CycloneDX y SPDX (pre-ejemplo del `sec-08`).

Un solo binario. Ejecuta sin daemon ni servicio corriendo. **Golang, 60 MB**, portable. Esa simplicidad es su principal valor operativo: cabe en cualquier pipeline, cualquier contenedor builder, cualquier laptop, sin dependencias.

## 3. Los cinco modos de escaneo

Trivy expone **cinco verbos** principales. Memorizarlos ahorra tiempo:

| Modo | Entrada típica | Qué detecta |
|------|----------------|-------------|
| `trivy fs <dir>` | Un repo clonado o un directorio local | Lockfiles de lenguaje + Dockerfile misconfig + secretos + licencias |
| `trivy image <ref>` | Una imagen OCI (local, Docker Hub, GHCR, ECR, GCR, Harbor) | Paquetes OS + paquetes de lenguaje embebidos en capas + secretos + misconfigs del Dockerfile histórico |
| `trivy repo <url>` | URL remota de un repo Git | Clona y hace `fs` — útil para scan one-shot sin checkout |
| `trivy config <dir>` | Directorio con HCL / YAML / JSON | **Solo misconfigs IaC**; sin vulns. Equivalente a lo que hacía `tfsec` suelto. |
| `trivy k8s <cluster>` | Un cluster accesible con `kubectl` config | Enumera workloads, saca imágenes, escanea, reporta por namespace |

Los cuatro primeros son **puntuales** (lo que corre un developer o CI). El quinto es la antesala del **Trivy Operator** (§9).

## 4. Formatos de salida

Trivy sale a:

- **`--format table`** (default): humano, para terminal.
- **`--format json`**: para procesar con `jq`, `python`, o pipeline downstream.
- **`--format sarif`**: **SARIF** (Static Analysis Results Interchange Format) es el estándar que **GitHub Code Scanning** espera. Subir SARIF enciende alerts en la pestaña *Security* del repo, con fix suggestions y tracking de reaperturas.
- **`--format cyclonedx` / `--format spdx`**: SBOMs. Entraremos en detalle en `sec-08`.
- **`--format template --template "@contrib/html.tpl"`**: para dashboards custom.

En CI real quieres **dos salidas** del mismo scan: `table` para que el log sea legible y `sarif` para que GitHub lo ingiera. Trivy soporta `--format table` por defecto y repites el scan con `--format sarif --output trivy-results.sarif`, o usas el action oficial `aquasecurity/trivy-action` que te hace ambas en una pasada.

## 5. Severidad: CVSS, EPSS y KEV

Un scanner devuelve, para cada vulnerabilidad, al menos **tres números distintos** que la gente confunde:

### 5.1 CVSS — Common Vulnerability Scoring System

Una **puntuación estática** de 0.0 a 10.0 que mide la *severidad teórica*: qué daño podría causar si fuera explotada, considerando vector (red / local), complejidad, privilegios requeridos, impacto en C/I/A. Lo publica el **NVD** (National Vulnerability Database, operado por NIST).

- `CRITICAL`: 9.0 – 10.0
- `HIGH`: 7.0 – 8.9
- `MEDIUM`: 4.0 – 6.9
- `LOW`: 0.1 – 3.9

**Problema de CVSS solo**: muchas vulns `CRITICAL` en CVSS **nunca han sido explotadas** porque requieren condiciones improbables en tu stack. Y muchas vulns `MEDIUM` **sí están siendo explotadas activamente** por botnets. CVSS **sobre-prioriza** y produce fatiga.

### 5.2 EPSS — Exploit Prediction Scoring System

Un **modelo probabilístico**, mantenido por **FIRST**, que predice la **probabilidad de explotación en los próximos 30 días** basándose en features observables (POCs públicos, menciones en dark web, exploit kits, menciones en Twitter / Mastodon, categoría de CWE, edad). Rango 0.0 – 1.0.

- EPSS 0.95 → casi seguro que será explotada en el mes próximo. Prioriza.
- EPSS 0.001 → ignórala por ahora salvo que esté en KEV.

### 5.3 KEV — Known Exploited Vulnerabilities (CISA)

Un **catálogo** mantenido por **CISA** (US Cybersecurity and Infrastructure Security Agency) de vulnerabilidades **que han sido explotadas en el mundo real**, con observación forense. Pequeño (~1 200 entradas), muy curado. Si una CVE está en KEV, **para ya lo que estás haciendo y párchala**, independientemente de CVSS o EPSS.

### 5.4 Política razonable

Para una org naciente:

- **Gate que bloquea merge**: `CRITICAL` CVSS **o** cualquier CVE presente en KEV.
- **Warn (comment en PR, no bloquea)**: `HIGH` CVSS con EPSS > 0.1.
- **Nightly scan + ticket semanal**: `HIGH` restantes y `MEDIUM`.
- **Ignorar en gate (pero inventariar)**: `LOW` y `MEDIUM` con EPSS < 0.01.

Para una org madura: baja el gate a `HIGH` con EPSS > X% o entrada en KEV, y sé estricto con las excepciones.

**Lo que NO quieres**: `--severity MEDIUM,HIGH,CRITICAL --exit-code 1` sin triage. Rompe el pipeline todos los lunes cuando el NVD publica el batch semanal, cada equipo deshabilita el gate "temporalmente", y a los 3 meses nadie lo mira.

## 6. Suppressions: `.trivyignore` con razón y expiración

A veces un CVE **no aplica** a tu caso (función no llamada, feature desactivada, mitigado por reverse proxy). O no hay fix upstream y hay que esperar. Trivy acepta ignores vía:

- **`.trivyignore`** en la raíz del repo: una CVE por línea, soporta comentarios con `#`.
- **`--ignorefile <path>`** para pasar otro archivo.
- **`.trivyignore.yaml`** (recomendado): formato estructurado con **expiración** y razón.

```yaml
# .trivyignore.yaml
vulnerabilities:
  - id: CVE-2024-12345
    paths:
      - "usr/lib/x86_64-linux-gnu/libfoo.so*"
    expired_at: 2026-12-31
    statement: |
      La función vulnerable (foo_parse_url) no se llama desde nuestra app;
      pedimos fix upstream. Revisar en diciembre 2026.
```

**Regla operativa**: toda entrada en `.trivyignore` debe tener **razón escrita + fecha de expiración + aprobador**. Si no la tiene, es un *technical debt silencioso*. Un pre-commit o CI check puede exigir el formato YAML con los tres campos obligatorios.

## 7. Caché de la base de datos de vulnerabilidades

Trivy mantiene una **DB local** (`~/.cache/trivy/db/trivy.db`) con todos los CVEs y sus mapeos a paquetes. La descarga de esa DB es la operación más lenta — en CI corres cientos de scans al día contra la **misma** DB y descargarla cada vez es un abuso del endpoint y añade minutos innecesarios.

Opciones:

- **GitHub Actions**: el action `aquasecurity/trivy-action` cachea con `actions/cache` por defecto; verifica que `TRIVY_CACHE_DIR` esté estable entre runs.
- **Self-hosted runners / local**: monta `~/.cache/trivy` como volumen persistente.
- **Air-gapped**: `trivy image --download-db-only` en un bastión y copia la DB; en el runner, `--skip-db-update --cache-dir /mnt/trivy-db`.
- **DB registry**: desde Trivy 0.50+ la DB se distribuye como una **imagen OCI** (`ghcr.io/aquasecurity/trivy-db`); puedes mirroirarla a tu registry interno para no depender de GHCR en el pipeline crítico.

## 8. SARIF y GitHub Code Scanning

Subir SARIF enciende dos ventajas:

1. **Alerts persistentes**: cada CVE se convierte en una *security alert* con estado (open / dismissed / fixed), fix suggestion si existe, link al Dockerfile y la línea exacta.
2. **PR annotations**: las nuevas CVEs introducidas en el PR aparecen como comentarios inline, no solo en un job log sepultado.

Flujo típico (GHA):

```yaml
- uses: aquasecurity/trivy-action@0.24.0  # pinear por SHA ideal
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: sarif
    output: trivy-results.sarif
    severity: CRITICAL,HIGH
    exit-code: '0'   # no fallar aquí; el merge-gate es el siguiente step
- uses: github/codeql-action/upload-sarif@v3
  with: { sarif_file: trivy-results.sarif }
- name: Fail on CRITICAL unignored
  run: |
    docker run --rm -v $PWD:/w aquasec/trivy:0.56.2 image \
      --severity CRITICAL --exit-code 1 --ignore-unfixed \
      ghcr.io/${{ github.repository }}:${{ github.sha }}
```

Observa:

- La subida de SARIF corre con `exit-code: 0` — no quieres que un hallazgo mate el upload de SARIF, pierdes la trazabilidad.
- El **gate** de bloqueo es un step separado que corre `trivy image` otra vez con `--exit-code 1` solo en `CRITICAL`.
- `--ignore-unfixed`: no bloquees por CVEs que no tienen fix upstream — no puedes arreglarlas y es injusto para el developer. Trackéalas por otra vía (nightly scan + ticket).

## 9. Trivy Operator en Kubernetes

En CI escaneas en el **build**. Pero el cluster se actualiza con imágenes que ya habías escaneado hace semanas, y cada día NVD publica CVEs nuevas. Lo que estaba limpio el martes puede tener un `CRITICAL` el jueves. Para visibilidad continua existe el **Trivy Operator** (Aqua, open source):

- Se instala vía Helm en el namespace `trivy-system`.
- **Watchea** cada Deployment / StatefulSet / DaemonSet / CronJob / Pod.
- Para cada workload, lanza un **job efímero** que escanea la imagen y escribe un **Custom Resource**:
  - `VulnerabilityReport`: CVEs encontradas, con severidad.
  - `ConfigAuditReport`: misconfigs del PodSpec (hostPID, privileged, etc.).
  - `ExposedSecretReport`: secretos filtrados en la imagen.
  - `ClusterSbomReport`: SBOM del cluster.
  - `KubeBenchReport` (opcional): CIS Benchmark para K8s.
- Reescanea con la cadencia que configures (default: cada 24 h, al cambiar el workload, al cambiar la DB).

Preguntas que resuelve el Operator:

> "¿Qué workloads en prod corren una imagen con CVE **recién publicada** hoy?"

Un `kubectl get vulnerabilityreports -A -o json | jq '.items[] | select(...)'` responde en segundos. En CI puro, esa pregunta requiere re-escanear todas las imágenes manualmente.

## 10. Fuentes de datos de CVEs

Trivy consulta **múltiples** fuentes y las normaliza:

| Fuente | Qué aporta | Dónde |
|--------|------------|-------|
| **NVD** | Baseline oficial US de CVEs con CVSS v3.1 | `nvd.nist.gov` |
| **GitHub Advisory Database** (GHSA) | Cobertura superior para ecosistemas de lenguaje (npm, PyPI, Maven, RubyGems); a veces publica días antes que NVD; incluye advisories privadas que no llegan a NVD | `github.com/advisories` |
| **GitLab Advisory DB** | Alternativa comparable | `gitlab.com/gitlab-org/security-products/advisory-database` |
| **OSV — Open Source Vulnerabilities** | Google-sponsored; esquema único; cubre OSS más ampliamente, incluye Linux kernel y Debian/Alpine tracking | `osv.dev` |
| **Red Hat Security Data** | Mapeo preciso de CVEs a RPMs de RHEL/UBI; a veces una CVE "CRITICAL" en NVD aparece como **not-affected** en RHEL porque el código vulnerable no se compila | `access.redhat.com/security/data` |
| **Alpine secdb**, **Debian Security Tracker**, **Ubuntu Security Notices** | Idem para su distro | respectivos |

**Consecuencia práctica**: la misma CVE puede aparecer en la tabla de Trivy con severidad `CRITICAL` (según NVD) y a la vez con `will_not_fix` en la fuente del distribuidor (porque esa distro decidió no backportear el fix por bajo impacto real). Trivy lo marca pero no lo filtra automáticamente — lo filtras tú con `--ignore-unfixed`.

## 11. Decisiones de diseño del scanner y de la política

Puntos de altitud para cerrar:

1. **Un solo scanner multi-tool vs varios especializados**. Trivy gana en operatividad (un binario, un formato, una DB). Grype (Anchore) es específicamente SCA + container, con filosofía similar. Snyk y Veracode son comerciales con bases de datos propietarias enriquecidas y mejor UX de dashboards. Para empezar, Trivy. Si creces, consideras Snyk/Prisma como complemento, no reemplazo.
2. **Base image slim/distroless reduce CVEs sin tocar código**. `python:3.12` arrastra ~400 paquetes Debian. `python:3.12-slim` ~100. `cgr.dev/chainguard/python:latest` prácticamente ninguno (distroless + hardening + mantenida continuamente). Mismo código, misma lógica — la medición de la actividad `02` lo demuestra numéricamente.
3. **`--ignore-unfixed` no es "ignorar la vuln"**, es "no bloquear el pipeline por algo que no puedo arreglar". El inventario separado (nightly + ticket + presión al upstream) sigue existiendo.
4. **El gate es contrato, no capricho**. Si el gate es `CRITICAL only`, documenta por qué (política SLO: "no queremos arriesgar un deploy por una `HIGH` que no está en KEV"); si subes a `HIGH`, documenta el trigger (más auditoría, nuevo cliente, incidente). Sin documento, los developers que ven el gate romperlos interpretan arbitrariedad.
5. **CVSS como filtro grueso, EPSS/KEV como ranking fino**. Un dashboard que ordena por EPSS reporta mejor prioridad que uno que ordena por CVSS.
6. **El Operator no reemplaza a CI, lo complementa**. CI atrapa en build. Operator atrapa en runtime y detecta "la DB tiene un CVE nuevo contra una imagen que ya está en prod".
7. **Trivy Operator también sirve de pre-adopción del admission**: antes de empezar a bloquear deployments por falta de firma (`sec-11`), tener los `VulnerabilityReport` encendidos durante un mes genera la línea base y los diffs necesarios para presentar el cambio al equipo sin sorpresas.

---

### Qué leer después

- `sec-08` — SBOM formal + SLSA provenance. Trivy `sbom` ya es un pre-ejemplo pero `sec-08` lo mete en el pipeline con **attestations**.
- `sec-09` — firmar la imagen escaneada con **cosign keyless**.
- `sec-11` — rechazar en el **admission controller** del cluster toda imagen que no venga firmada y con attestation de scan limpio.
- `sec-14` — operar todo esto como contrato de plataforma con **vuln management lifecycle** y métricas (MTTR, mean time to patch, % imágenes firmadas).
