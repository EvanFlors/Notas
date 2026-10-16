# sec-07 — Lección: IaC scanning con Checkov, Trivy config y tfsec

> 10 secciones. Prerrequisito: `sec-03`, curso **terraform** ≥ `tf-04`.

---

## 1. Qué es "IaC scanning" y qué no es

**IaC scanning** = análisis estático de la **declaración** de infraestructura (Terraform HCL, CloudFormation YAML, manifests K8s, Dockerfile, ARM, Helm charts) para detectar **misconfigs** antes de aplicar.

No es:

- **SAST** sobre código de aplicación (eso es `sec-06`).
- **CSPM** sobre la cuenta cloud en vivo (p. ej. Prowler) — eso detecta drift **después** de aplicar.
- **Admission control** en el cluster — eso es `sec-11` (Kyverno, OPA/Gatekeeper, policy-controller).

> **Idea clave:** IaC scanning intenta mover el error de "lo apliqué y descubrí que mi S3 estaba público" a "fallé el PR porque la propiedad `acl = public-read` dispara CKV_AWS_20".

El coste de arreglar una misconfig **antes** de `terraform apply` es trivial. El coste **después** incluye investigación, rotación de credenciales si hubo filtración, y notificación.

---

## 2. Las herramientas del mercado (y sus solapamientos)

| Herramienta       | Formatos                            | Policy language                         | Estado                                   |
|-------------------|-------------------------------------|-----------------------------------------|------------------------------------------|
| **Checkov**       | TF, CFN, K8s, Dockerfile, ARM, Helm, Serverless, Kustomize, GH Actions | Python o Rego (OPA)             | Activo, Bridgecrew/Prisma (Palo Alto)    |
| **Trivy config**  | TF, CFN, K8s, Dockerfile, Helm      | Rego (reusa reglas tfsec/misconfig)     | Activo, Aqua Security                    |
| **tfsec**         | TF, HCL                             | Rego / Go-based                         | **Mantenimiento**: fusionado con Trivy   |
| **Terrascan**     | TF, K8s, Helm, Kustomize            | Rego                                    | Activo (Tenable)                         |
| **KICS**          | TF, CFN, K8s, Dockerfile, Helm, Ansible | queries propias (YAML + Rego)       | Activo (Checkmarx)                       |

**Qué elegir** (regla de pulgar):

- **Checkov**: default sensato cuando quieres **una** herramienta que cubra TF + K8s + Dockerfile + Helm. Policies custom en **Python** son más cómodas que en Rego si tu equipo no usa Rego en otros sitios.
- **Trivy config**: ya tienes Trivy para CVEs — añadir `trivy config` es prácticamente gratis (mismo binario, mismo cache). Muy rápido.
- **tfsec** como CLI directo: solo si quieres el binario pequeño sin el resto de Trivy. Camino oficial = Trivy.
- **Terrascan / KICS**: menciónalos; úsalos si tu organización ya los tiene.

**Combinación realista**: Checkov como `must-pass` + Trivy config como **segunda opinión rápida**. Dos scanners dan señal cruzada y detectan reglas que uno solo no cubre.

---

## 3. HCL crudo vs plan JSON — la diferencia que importa

Un bloque HCL puede ser **inseguro en apariencia** y correcto en producción (variable con default seguro sobreescrito en `.tfvars`), o al revés: un bloque "limpio" puede volverse inseguro cuando un `data` source resuelve a un valor peligroso.

```hcl
# ¿Es seguro este bucket? Depende de la variable.
resource "aws_s3_bucket" "data" {
  bucket = "my-bucket"
  acl    = var.bucket_acl  # ← aquí el HCL no te dice nada
}
```

**Escanear el plan** resuelve esta ambigüedad:

```bash
terraform init
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json
checkov -f tfplan.json
```

Checkov detecta el formato automáticamente. El plan contiene **todos los valores resueltos**: variables aplicadas, data sources evaluados, locals computados. **Menos falsos positivos**, y **más findings legítimos** (regresiones por cambios en data sources no se ven en HCL).

> **Idea clave:** HCL es *intento*; plan es *resultado*. IaC scanning sobre plan detecta lo que vas a crear, no lo que escribiste. Haz **ambos** en CI: HCL en pre-commit (rápido, local), plan en pipeline (preciso, requiere `terraform init`).

---

## 4. Checkov en 5 minutos

```bash
pip install checkov
# o: docker run --rm -v "$PWD:/tf" bridgecrew/checkov -d /tf

checkov -d .                         # escanea cwd en todos los formatos
checkov -d terraform/                # solo esa carpeta
checkov -f tfplan.json               # un plan
checkov -d . --framework terraform   # restringe a TF
checkov -d . --check CKV_AWS_20      # solo una regla
checkov -d . --skip-check CKV_AWS_52 # excluye una regla globalmente
checkov -d . -o sarif -o cli         # dos salidas en una pasada
```

**Config** vía `.checkov.yaml` en la raíz del repo:

```yaml
framework:
  - terraform
  - kubernetes
skip-check:
  - CKV_AWS_52  # SSE-S3 vs KMS — todavía no migrado, ADR-0042
soft-fail: false  # queremos exit code 1 en findings
output:
  - cli
  - sarif
```

**Supresión in-line** (justificación obligatoria):

```hcl
#checkov:skip=CKV_AWS_20:bucket público intencional, es un endpoint estático; ADR-0007
resource "aws_s3_bucket" "static_site" {
  bucket = "docs.example.com"
}
```

Regla operativa: **toda supresión lleva (a) el ID de la regla, (b) una razón corta, (c) un enlace a ADR o ticket**. Sin eso, no hay excepción.

---

## 5. Trivy config en 5 minutos

```bash
trivy config .                              # escanea el cwd
trivy config terraform/                     # carpeta
trivy config --severity HIGH,CRITICAL k8s/  # política
trivy config --format sarif -o out.sarif .  # SARIF
trivy config --skip-dirs node_modules/ .    # exclusiones
```

Trivy config usa internamente las reglas de **tfsec** (migradas) + reglas Rego propias. Es **mucho más rápido** que Checkov (binario Go, sin interprete Python).

**No tiene policies Python**. Para custom rules, Trivy usa **Rego** (`--config-policy` apuntando a un dir con `.rego`). Si quieres Python → Checkov.

---

## 6. tfsec (y por qué está en modo mantenimiento)

tfsec fue adquirido por Aqua Security en 2021. En 2023 Aqua anunció que la base de reglas se fusiona con Trivy config. El CLI `tfsec` sigue funcionando y recibe actualizaciones de reglas vía Trivy, pero **ningún esfuerzo nuevo va ahí**.

```bash
tfsec .           # escanea TF en cwd
tfsec --soft-fail .
```

Si ves `tfsec` en pipelines antiguos, puedes dejarlo o migrarlo a `trivy config`. Lo que no debes hacer es escribir reglas custom nuevas para tfsec.

---

## 7. Policies custom en Checkov (Python)

Dos formas: **Python classes** heredando de `BaseResourceCheck` o **Rego** vía `--external-checks-dir`.

### Python — más común para equipos sin Rego

```python
# checks/BucketMustHaveClassification.py
from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class BucketMustHaveClassification(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="S3 bucket must have data_classification tag",
            id="CKV_CUSTOM_1",
            categories=[CheckCategories.CONVENTION],
            supported_resources=["aws_s3_bucket"],
        )

    def scan_resource_conf(self, conf):
        tags = conf.get("tags", [{}])[0]
        if isinstance(tags, dict) and "data_classification" in tags:
            return CheckResult.PASSED
        return CheckResult.FAILED

check = BucketMustHaveClassification()
```

Correrla:

```bash
checkov -d . --external-checks-dir ./checks
```

**Convenciones**:

- ID con prefijo `CKV_<ORG>_` (p. ej. `CKV_ACME_1`) para no colisionar.
- Categorías existentes: `CONVENTION`, `IAM`, `ENCRYPTION`, `NETWORKING`, `LOGGING`, `SECRETS`.
- Siempre un **test fixture** `good.tf` y `bad.tf`: la policy sin tests es una policy rota en 6 meses.

### Rego vía Checkov

```bash
checkov -d . --external-checks-dir ./policies_rego
```

Dentro de `policies_rego/` ponés `.rego` con `metadata.yaml`. Más adelante en `sec-10` se cubre Rego directamente con Conftest/OPA.

---

## 8. Mapping a benchmarks (CIS, PCI-DSS, HIPAA, SOC2)

Checkov etiqueta cada regla con los benchmarks que cubre. Filtra:

```bash
checkov -d . --check "CKV_AWS_*" --output cli
checkov -d . --use-enforcement-rules   # usa la política de la org
# Filtrar por framework de compliance:
checkov -d . --check CIS_AWS_1.2
```

**Caveat**: un pipeline que pase "100% CIS" no es un pipeline seguro — es un pipeline que no viola **esas** reglas. Benchmarks son un **mínimo**, no un objetivo.

---

## 9. CI: política de severidad y excepciones

Patrón recomendado:

1. **Pre-commit** (local): `checkov -d . --framework terraform --quiet` sobre HCL. Rápido, no requiere `terraform init`.
2. **CI job "iac-scan-hcl"**: igual que pre-commit, pero obligatorio en PR.
3. **CI job "iac-scan-plan"**: `terraform init && terraform plan -out=tfplan.binary && terraform show -json tfplan.binary > tfplan.json && checkov -f tfplan.json`. Más lento, más preciso.
4. **CI job "iac-scan-k8s"**: `trivy config k8s/ --severity HIGH,CRITICAL --exit-code 1`.
5. **Upload SARIF** a GitHub Code Scanning (`-o sarif`) para visualizar en el PR.

**Política de severidad** (ejemplo mínimo):

- `CRITICAL` → bloquea PR, no hay excepción sin ADR.
- `HIGH` → bloquea PR, excepción con `skip-check` + razón + fecha de expiración.
- `MEDIUM` → warn, visible en PR.
- `LOW` → warn, no visible por defecto.

**Excepciones con expiración**: anota en el `.checkov.yaml` o en el in-line `skip` un comentario con fecha (`# expires: 2026-12-31`). Un check de CI puede fallar cuando una excepción expiró — eso es *la* manera de evitar que las excepciones se vuelvan permanentes.

---

## 10. Checklist operativo

Antes de merger de un cambio de infra:

- [ ] HCL pasa `checkov -d .` (o la carpeta afectada).
- [ ] Plan JSON pasa `checkov -f tfplan.json`.
- [ ] Si hay manifests K8s, `trivy config k8s/` sale limpio en `HIGH,CRITICAL`.
- [ ] Si hay Dockerfile, `trivy config Dockerfile` sale limpio.
- [ ] Toda supresión in-line tiene razón + ADR/ticket.
- [ ] El `.checkov.yaml` tiene cada `skip-check` justificado y, idealmente, con expiración.

Si cualquiera falla, **no se mergea**. Si la regla es equivocada para tu contexto, se discute en el PR y se añade excepción justificada en vez de bajar la severidad globalmente.

---

## Punto a repetir hasta que suene aburrido

> **IaC scanning sobre plan es más preciso que sobre HCL** porque el plan resuelve variables, data sources y locals. Haz ambos: HCL en pre-commit (rápido), plan en CI (preciso).
