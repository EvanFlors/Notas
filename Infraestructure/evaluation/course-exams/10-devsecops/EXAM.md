# Examen de certificación — DevSecOps toolkit

- **Curso evaluado:** `devsecops` (`sec-01` … `sec-14`).
- **Nivel:** intermedio-avanzado.
- **Dimensión:** todas (conceptual + operativa + arquitectónica).
- **Duración:** 90–120 min (sugerida: 30 min conceptual, 45–60 min operativa, 20–30 min arquitectónica).
- **Umbral de aprobación:** 70% del total ponderado (**70 / 100**).
- **Entorno de evaluación:** take-home reproducible local; sin cloud; sin secretos reales (solo dummies).
- **Entregables globales:** archivos indicados en cada sección + justificaciones escritas en prosa (español).

> Convención: la **prosa va en español**, el **código, comandos, nombres de recursos, policies y mensajes** van en **inglés**. Mezclar idiomas en código es un **red flag** menor.

---

## Sección 1 — Matriz de competencias evaluadas

Ver fuente autoritativa en [`competency-matrix.yaml`](competency-matrix.yaml). Resumen:

| ID | Competencia (resultado observable) | Dimensión | Peso |
|----|-------------------------------------|-----------|------|
| C1 | Distinguir garantías SLSA L1/L2/L3 y ataque que previene cada salto | conceptual | 6 |
| C2 | Diferenciar SBOM (inventario) vs provenance (historia) | conceptual | 5 |
| C3 | Justificar por qué cosign keyless reduce blast radius | conceptual | 6 |
| C4 | Qué garantiza (y qué NO) una verificación cosign sin `--certificate-identity` | conceptual | 6 |
| C5 | Elegir Kyverno vs Gatekeeper vs policy-controller vs VAP con criterio | conceptual | 6 |
| C6 | CVSS vs EPSS vs KEV: qué responde cada una | conceptual | 5 |
| C7 | Secuencia correcta ante leak de secreto (rotar antes que reescribir) | conceptual | 5 |
| C8 | Policy-as-code en IaC vs admisión en cluster | conceptual | 5 |
| O1 | Generar SBOM CycloneDX con Syft y validar contenido | operativa | 8 |
| O2 | Escanear imagen con Trivy, SARIF, política de severidad | operativa | 7 |
| O3 | Policy Rego con Conftest sobre Terraform plan JSON | operativa | 8 |
| O4 | ClusterPolicy Kyverno exigiendo imagen firmada por OIDC concreto | operativa | 8 |
| O5 | Verify cosign keyless con dummy identity, detectar verify inseguro | operativa | 7 |
| A1 | Contrato de gates (block/warn/nightly) con trade-offs | arquitectónica | 10 |
| A2 | ADR eligiendo Kyverno vs Gatekeeper vs VAP | arquitectónica | 8 |

Total: **100 puntos**. Umbral: **70**.

---

## Sección 2 — Preguntas conceptuales (44 pts)

Formato: respuesta corta (3–8 líneas). Evita listas de bullets vacías; argumenta.

### P1 — SLSA (C1, 6 pts)

Un equipo sube una imagen con "SLSA provenance generado desde mi laptop con `slsa-github-generator` fork local y firmado con mi GPG key". ¿Qué nivel SLSA puede reclamar y por qué? Si quisiera llegar a **L3**, ¿qué dos cosas tendrían que cambiar y qué ataque previene cada cambio?

### P2 — SBOM vs provenance (C2, 5 pts)

Un ingeniero dice: "Ya publicamos SBOM, no necesitamos provenance porque sabemos qué hay dentro". Explica por qué esa afirmación es incorrecta usando un ejemplo concreto de un ataque de supply chain reciente (xz-utils, tj-actions/changed-files o SolarWinds). Qué pregunta responde el SBOM que la provenance no responde, y viceversa.

### P3 — Keyless (C3, 6 pts)

Compara el modelo keyless de Sigstore (Fulcio + Rekor + certificado efímero) con el modelo "clave privada en HSM". ¿Qué clase de incidente desaparece con keyless? ¿Qué clase nueva aparece? Argumenta por qué el *trade-off* es favorable para la mayoría de equipos.

### P4 — Verificación cosign insegura (C4, 6 pts)

Un pipeline tiene este paso de verificación:

```bash
cosign verify ghcr.io/acme/api:${TAG} \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com
```

Explica exactamente **qué garantiza** y **qué NO garantiza** este comando. ¿Qué atacante podría pasar esta verificación hoy? Da la corrección mínima y por qué cierra el hueco.

### P5 — Admission tool choice (C5, 6 pts)

Para cada escenario, elige entre `Kyverno`, `OPA/Gatekeeper`, `sigstore policy-controller` o `ValidatingAdmissionPolicy` nativo y justifica en 2–3 líneas:

- (a) Equipo con 50 reglas Rego ya en uso en IaC CI, cluster EKS 1.29, quiere consistencia entre CI y admisión.
- (b) Equipo quiere **solo** verificar firma cosign de imágenes; no quiere operar policies adicionales.
- (c) Equipo pequeño, GKE 1.30, quiere eliminar webhooks externos y acepta aprender CEL.
- (d) Equipo plataforma que necesita `validate` + `mutate` + `generate` de recursos con sintaxis YAML.

### P6 — Severidad (C6, 5 pts)

Un CVE tiene **CVSS 9.8** pero **EPSS 0.001** y no está en el **KEV catalog** de CISA. Otro CVE tiene **CVSS 6.4**, **EPSS 0.78** y **está en KEV**. ¿Cuál es más urgente parchar y por qué? ¿Qué pregunta responde cada métrica? ¿Por qué una política "fallar en todo CVSS ≥ 7" produce mal uso del tiempo del equipo?

### P7 — Leak de secreto (C7, 5 pts)

Un desarrollador commiteó una AWS access key real a un repo privado. Un revisor propone: "borrar el archivo, hacer commit, usar BFG para reescribir historia y seguir usando esa key porque el repo es privado". Critica esa secuencia paso por paso. ¿Cuál es la secuencia correcta y por qué el orden importa?

### P8 — PaC IaC vs admisión (C8, 5 pts)

¿Por qué una organización madura corre la **misma intención de policy** en **dos lugares** (Conftest sobre `terraform show -json` en CI *y* Kyverno en admisión)? Da un ejemplo de regla donde el chequeo en IaC no basta y la admisión sí lo captura, y un ejemplo contrario.

---

## Sección 3 — Ejercicio operativo (38 pts)

**Entorno:** local, sin internet obligatorio después de preparar el workspace.
**Materiales de inicio:** [`operative/README.md`](operative/README.md) y [`operative/fixtures/`](operative/fixtures/).
**Herramientas requeridas:** `trivy`, `syft`, `cosign`, `conftest`, `kyverno-cli` (CLI; no requiere cluster).
**Si una herramienta falta en tu máquina**, documenta la omisión en `operative/SKIP.md` con el comando `which <tool>` fallando como evidencia y la **ejecución manual del razonamiento** (output esperado). El SKIP justificado puntúa como **Básico (1)** máximo en la rúbrica de ese sub-ejercicio.

**Prohibido:** secretos reales, llamadas a cuentas cloud reales, descargar imágenes privadas con credenciales reales. Solo dummies.

### Tareas

1. **O1 — SBOM (8 pts).** Elige una imagen pública inocua (p. ej. `cgr.dev/chainguard/static:latest` o `alpine:3.20`). Genera un SBOM CycloneDX con `syft`, guárdalo como `operative/out/sbom.cdx.json`. Escribe en `operative/out/sbom-notes.md` **tres paquetes** incluidos y **una pregunta de inventario** (ej.: "¿tenemos openssl afectado por CVE-X?") que el SBOM responde pero un `docker inspect` **no**.
2. **O2 — Trivy + política (7 pts).** Escanea la misma imagen con `trivy image --severity HIGH,CRITICAL --format sarif --output operative/out/trivy.sarif ...`. Produce `operative/out/trivy-policy.md`: por qué fallarías el pipeline en CRITICAL pero **no** en HIGH automáticamente, y qué proceso de excepción diseñas (TTL + approver). Nota: una política debe citar EPSS/KEV; sin eso puntúa Básico máximo.
3. **O3 — Conftest sobre Terraform plan (8 pts).** Partiendo de `operative/fixtures/tfplan.json` (adjunto), escribe `operative/policy/s3.rego` con dos reglas: **deny** si un `aws_s3_bucket` tiene ACL `public-read` o `public-read-write`; **warn** si falta la etiqueta `Owner`. Añade `operative/policy/s3_test.rego` (tests `opa test`). Valida: `conftest test --policy operative/policy operative/fixtures/tfplan.json`.
4. **O4 — Kyverno verifyImages (8 pts).** Escribe `operative/policy/kyverno-verify-images.yaml` (`ClusterPolicy` `verifyImages`) que exija firma keyless para `ghcr.io/acme/*`, con `subject: "https://github.com/acme/api/.github/workflows/release.yml@refs/heads/main"` y `issuer: "https://token.actions.githubusercontent.com"`. Testea con `kyverno-cli test` o `kyverno apply --policy ... --resource operative/fixtures/pod-good.yaml` y `pod-bad.yaml`. Entrega la policy, los recursos y el output.
5. **O5 — Verify inseguro (7 pts).** En `operative/out/cosign-verify.md` escribe (a) el comando `cosign verify` **inseguro** más común que un junior copiaría de un blog (sin `--certificate-identity`); (b) por qué pasa; (c) la versión correcta usando una **dummy identity** `https://github.com/acme/api/.github/workflows/release.yml@refs/heads/main`; (d) qué devuelve en seco (`--insecure-ignore-tlog` **prohibido** salvo justificar). No se requiere firma real: el ejercicio evalúa el razonamiento, no la ejecución contra Rekor.

### Procedimiento de validación

Script `operative/validate.sh` (reproducible):

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "== O1 =="
test -s out/sbom.cdx.json
jq -e '.bomFormat == "CycloneDX"' out/sbom.cdx.json >/dev/null
test -s out/sbom-notes.md

echo "== O2 =="
test -s out/trivy.sarif
jq -e '.runs[0].tool.driver.name | test("Trivy"; "i")' out/trivy.sarif >/dev/null
test -s out/trivy-policy.md
grep -Eiq 'EPSS|KEV' out/trivy-policy.md

echo "== O3 =="
conftest test --policy policy fixtures/tfplan.json
opa test policy

echo "== O4 =="
test -s policy/kyverno-verify-images.yaml
grep -q 'verifyImages' policy/kyverno-verify-images.yaml
grep -q 'token.actions.githubusercontent.com' policy/kyverno-verify-images.yaml

echo "== O5 =="
test -s out/cosign-verify.md
grep -q 'certificate-identity' out/cosign-verify.md

echo "ALL OK"
```

El script debe salir con `exit 0`. Si una herramienta no está instalada, el ejercicio asociado se marca con `SKIP: <razón>` en `operative/SKIP.md` y el corrector aplica la cláusula de rúbrica.

---

## Sección 4 — Ejercicio arquitectónico (18 pts)

Ver escenario completo en [`architectural/scenario.md`](architectural/scenario.md). Resumen:

Una fintech de 120 ingenieros, 3 clusters EKS (dev / stg / prod), 60 microservicios, pipelines en GitHub Actions, está presionando por **merges en ≤ 15 min**. Tú diseñas:

- **A1 — Contrato de gates (10 pts).** Qué controles **bloquean merge**, cuáles **warn**, cuáles corren **nightly**. Justifica cada decisión con un trade-off velocidad vs riesgo. Diseña la **exception policy** (TTL, approver, reviewer, auditabilidad).
- **A2 — ADR Kyverno vs Gatekeeper vs VAP (8 pts).** Elige una admission tool para `prod`, escribe ADR corto (Contexto, Decisión, Consecuencias, Alternativas descartadas). La decisión debe ser **defendible**, no "la que vi en un blog".

Entregables en `architectural/`:

- `gates-contract.md`.
- `exception-policy.md`.
- `adr-0001-admission-tool.md`.

---

## Sección 5 — Rúbrica

Umbral de aprobación: **70 / 100** total. Ningún ejercicio arquitectónico puede quedar en nivel **Insuficiente (0)** aun si la suma global pasa 70 (regla de piso para A1 y A2: mínimo **Básico**).

### 5.1 Conceptuales (0–3 por pregunta, escalado al peso)

| Nivel | Descriptor observable |
|-------|-----------------------|
| Insuficiente (0) | Define término sin explicar; cita slogan; contradice el fundamento del módulo; respuesta vacía o copia literal del roadmap. |
| Básico (1) | Identifica el concepto correcto pero no justifica *por qué*; omite el contraejemplo clave o la segunda cara del trade-off. |
| Competente (2) | Explica el por qué correctamente, da ejemplo pertinente, reconoce el trade-off principal. |
| Experto (3) | Además elige entre alternativas con criterio, cita un caso real relevante (xz-utils, tj-actions, etc.) y describe cuándo cambiaría de opinión. |

Puntos por pregunta = (nivel / 3) × peso.

### 5.2 Operativa — por sub-ejercicio

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Correctness (los artefactos existen y validan) | No corre o no genera salida válida. | Salida parcial, falla en una regla. | Todas las assertions de `validate.sh` pasan. | Pasan + output limpio y comandos reproducibles documentados en el `.md`. |
| Seguridad (no secretos reales, no verifies inseguros, no `cluster-admin`) | Incluye secreto real, verify sin identity, o policy que escapa namespace. | Un lapso menor (dummy inconsistente). | Dummies consistentes y policies explícitas. | Explica además por qué cada decisión reduce blast radius. |
| Justificación (razonamiento en `.md`) | Ausente o cita el enunciado. | Correcta pero genérica. | Específica a los artefactos entregados. | Conecta con política de severidad (EPSS/KEV) y lifecycle de vuln mgmt. |
| Operabilidad / reproducibilidad | No se puede re-ejecutar. | Requiere pasos manuales no documentados. | `validate.sh` reproducible en limpio. | Documenta cómo falla y cómo se recupera. |

Peso por sub-ejercicio ya está en la matriz. Pondera cada criterio al 25% dentro del sub-ejercicio.

### 5.3 Arquitectónica

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Alineación con requisitos | Ignora alguna restricción del escenario. | Cumple requisitos pero no restricciones. | Cumple ambos. | Además propone cómo medirá éxito (KPIs: MTTR, % imágenes firmadas). |
| Trade-offs explícitos | No menciona trade-offs. | Lista trade-offs genéricos. | Trade-offs específicos al escenario. | Cuantifica (ej.: "+2 min por merge, cubre 85% CVE críticos"). |
| ADR como documento | Sin estructura. | Estructura ADR pero sin alternativas. | ADR completo con alternativas descartadas. | Incluye disparadores para revisarlo (p. ej. "revisar si VAP soporta X"). |
| Exception policy operable | Ausente o informal. | Define TTL y approver. | Define TTL + approver + reviewer + auditabilidad. | Diseña el flujo self-service con guard-rails (plantilla + revisión obligatoria). |

---

## Sección 6 — Guía de corrección (instructor-only)

### 6.1 Respuestas modelo (conceptuales)

- **P1.** Puede reclamar como mucho **L1** (hay build script). No es L2 porque el provenance no fue generado por un *hosted builder* confiable (fork local no cuenta como non-tampered). Para **L3**: (i) build en hosted builder aislado (GHA con `actions/attest-build-provenance` + runner no self-hosted sin aislamiento adecuado) → previene atacante que modifica el `provenance` desde la máquina del dev; (ii) provenance **non-forgeable** vinculada a identidad OIDC verificable (firma Fulcio/Rekor) → previene que un atacante con acceso al repo falsifique la cadena. Red flag: responder "L3" sin tocar aislamiento ni non-forgeable.
- **P2.** SBOM responde "¿qué hay dentro?". Provenance responde "¿cómo y por quién se construyó?". Ejemplo xz-utils: el SBOM lista `liblzma` pero no revela que el tarball upstream fue construido por una identidad maliciosa; el provenance (firmado por el builder legítimo desde el commit limpio) sí habría permitido detectar que la versión publicada *no corresponde* al código fuente auditado. tj-actions: SBOM no te dice que el runner ejecutó una versión mutada de una action; provenance firmada ligada al commit sí.
- **P3.** Desaparece: pérdida/exfiltración de clave privada de larga vida; rotación forzada tras incidente; custodia (HSM, acceso, backup). Aparece: dependencia operativa de Fulcio/Rekor; necesidad de pinnear identity OIDC correctamente; superficie contra el workflow (si el workflow mismo es malicioso, firma válida). Trade-off favorable: la clase que desaparece es la que ha causado más incidentes históricos (claves filtradas); la clase nueva es mitigable con pin estricto de identity y branch.
- **P4.** Garantiza: alguien con un cert emitido por GitHub Actions OIDC firmó. **NO** garantiza: que el firmante sea *tu* repo/workflow/branch. Cualquier GitHub Action pública con OIDC puede firmar y pasar esta verificación. Corrección: añadir `--certificate-identity-regexp` (o `--certificate-identity`) pinneando `https://github.com/<org>/<repo>/.github/workflows/<file>.yml@refs/heads/main`.
- **P5.** (a) OPA/Gatekeeper (reutiliza Rego, consistencia IaC↔cluster). (b) sigstore policy-controller (foco único, menos superficie). (c) ValidatingAdmissionPolicy (sin webhook, CEL nativo). (d) Kyverno (único con mutate+generate de primera clase y YAML).
- **P6.** El segundo (CVSS 6.4 + EPSS 0.78 + KEV) es más urgente: KEV = explotado activamente; EPSS alta = probabilidad real; el 9.8 teórico sin EPSS ni KEV probablemente es un *paper vuln* sin explot público. CVSS = severidad teórica si se explota; EPSS = probabilidad de explotación próxima; KEV = evidencia de explotación real. Política "fallar en todo CVSS ≥ 7" produce ruido masivo y desplaza tiempo del equipo lejos de los CVEs realmente peligrosos.
- **P7.** La propuesta es incorrecta en los tres pasos: (1) la key ya está comprometida en el momento del commit (asumir leaked siempre, repo privado o no — forks internos, backups, mirrors, logs CI, cachés de clones); (2) borrar el archivo deja la key en la historia; (3) BFG antes de rotar deja ventana explotable. Secuencia correcta: **rotar primero** (invalidar la credencial) → **comunicar** al equipo (fetch divergente) → **reescribir historia** (BFG/`git filter-repo`) → **force-push coordinado** → **auditar uso** de la key en logs cloud (CloudTrail) para detectar abuso ya ocurrido.
- **P8.** Dos lugares porque IaC scan no cubre recursos creados fuera de Terraform (manifests aplicados por `kubectl`, Helm charts externos, operadores que generan recursos) y admisión no bloquea misconfig antes de aplicar (feedback caro). Ejemplo cubierto solo por admisión: Pod creado por un Operator con `hostPath: /`. Ejemplo cubierto solo por IaC scan: bucket S3 público creado por Terraform (admisión K8s no lo ve).

### 6.2 Operativa — señales clave

- **O1.** Buscar: SBOM es válido CycloneDX JSON, lista componentes con `purl`, `version`, `type`. Respuestas de "¿qué pregunta responde?" aceptables: inventario cross-fleet, consulta "quién usa X@Y", respuesta a nuevo CVE sin re-scan. Red flag: afirmar que SBOM contiene info de *runtime* (no sin runtime SBOM).
- **O2.** Buscar: SARIF válido; política articulada; **mención explícita de EPSS o KEV** (sin eso, Básico máx.); proceso de excepción con TTL. Error común: política "ignore all `HIGH`" sin TTL ni reviewer.
- **O3.** Buscar: Rego con `package main`, `deny[msg]`, iteración sobre `input.resource_changes`, filtro por `type == "aws_s3_bucket"`; `warn` para tag ausente; tests que cubren happy + unhappy. Error común: regla sobre `input.resource[_]` que no corresponde a formato de plan JSON.
- **O4.** Buscar: `kind: ClusterPolicy`, `spec.rules[].verifyImages`, `imageReferences: ["ghcr.io/acme/*"]`, `attestors[].entries[].keyless.subject` y `.issuer`. Red flag: usar `--key` con PEM dummy en vez de keyless (demuestra que no entendió el modelo).
- **O5.** La corrección debe pinnear identity completa (workflow + branch), no solo issuer. Si el estudiante usa `--certificate-identity-regexp '.*'`, es un **red flag** equivalente a no pinnear.

### 6.3 Arquitectónica — señales clave

- **A1.** Un buen contrato bloquea: secret scan hallazgo *real* (no FP), SAST CRITICAL, SCA/container CVE CRITICAL en KEV, policy fallida en admisión (test local), firma faltante. Advertencia (warn): HIGH no-KEV, SBOM no publicado, policy drift. Nightly: scan de historia completa, re-scan de imágenes en producción, DAST. Red flag: bloquear en todo HIGH (mata DX, invita a `nosec`/supresiones masivas).
- **A2.** ADR aceptable: elige Kyverno con razones (equipo K8s nativo, requisito de `verifyImages` + `mutate`), descarta Gatekeeper (equipo no tiene Rego skills ya), descarta VAP (sin mutate hoy). O elige VAP con razones (quiere eliminar webhook, acepta carencia de mutate hoy, planea pilot). Red flag: elegir herramienta sin mencionar al menos 2 alternativas descartadas.

### 6.4 Red flags (anulan parcial o totalmente la respuesta)

- Secreto real (AWS key con formato válido, GitHub PAT real) en cualquier archivo entregado → **nota 0 global** + alerta a instructor.
- `cosign verify` sin `--certificate-identity[-regexp]` propuesto como solución válida.
- `cosign verify --insecure-ignore-tlog` sin justificar y en producción.
- Kyverno/Gatekeeper policy que exenta `kube-system` + `default` + `*` o usa `cluster-admin` como workaround.
- `curl ... | bash` desde fuente no verificada en el script de validación.
- Imagen firmada con clave custodiada presentada como "equivalente a keyless".
- Respuesta que afirma "SBOM es firma" o "provenance es inventario".
- `latest` tag en una imagen que la propia policy del estudiante prohíbe.

### 6.5 Preguntas de seguimiento (si evaluación live)

Diseñadas para distinguir memorización de comprensión:

1. "¿Qué pasaría si Rekor estuviera caído 2 horas? ¿Tu pipeline sigue firmando? ¿Verificando?"
2. "Mostrame un escenario donde tu Kyverno policy pasa pero la imagen sigue siendo peligrosa."
3. "Si bajamos el umbral de `conftest` de `deny` a `warn`, ¿quién lo nota y cuándo?"
4. "Tu CVE está en KEV pero no hay patch upstream. ¿Qué haces en las próximas 24h?"
5. "Tu equipo me dice que el gate de firma añade 90s al merge. ¿Lo quitas, lo movés a nightly o lo defendés? Argumentá."
6. "Verificar imagen en admisión + firmar en CI = defensa en profundidad. ¿Dónde más deberíamos verificar y por qué?"
7. "SBOM dice que no tenés log4j. Mañana sale un CVE en una lib transitiva que SBOM no detectó. ¿Qué falló?"
8. "¿Cuándo elegirías Gatekeeper sobre Kyverno aunque tu equipo prefiera YAML?"

Si el estudiante responde todas sin dudar y además propone matices, considerar nivel **Experto**. Si responde con slogans ("defense in depth siempre") sin ejemplo concreto, mantener **Básico** aun si la respuesta escrita era buena.

---

## Checklist de calidad del propio examen (meta)

- [x] Matriz con pesos explícitos.
- [x] Preguntas que exigen explicar *por qué* / *qué pasaría si*, no definiciones.
- [x] Ejercicio operativo con `validate.sh` reproducible y cláusula SKIP justificada.
- [x] Rúbrica con 4 niveles observables.
- [x] Guía de corrección con red flags y follow-ups.
- [x] Umbral 70% con piso por sección arquitectónica.
- [x] Duración 90–120 min realista.
- [x] Sin secretos reales; solo dummies.
