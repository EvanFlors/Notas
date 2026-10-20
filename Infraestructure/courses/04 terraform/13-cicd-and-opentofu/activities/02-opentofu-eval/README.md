# Actividad 02 — Evaluación de OpenTofu + ADR

## 1. Identificación

- **ID:** `tf-13-02-opentofu-eval`
- **Tecnología:** `terraform`
- **Módulo:** `13-cicd-and-opentofu`
- **Dificultad:** advanced
- **Duración estimada:** 90–150 min
- **Tipo:** independent (ADR driven)

## 2. Contexto

OpenTofu es un fork drop-in de Terraform mantenido por la Linux Foundation bajo Apache 2.0, nacido en 2023 tras el cambio de licencia de HashiCorp a BUSL. La pregunta operacional de este módulo es: **¿tu organización debería adoptarlo?** Esta actividad te pide investigar, probar y **documentar la decisión como un ADR**.

El validator comprueba:

1. Que instalaste `tofu` localmente (si no, imprime instrucciones y **SKIP** sin fallar).
2. Que corriste `tofu` sobre un stack provisto y produjiste evidencia (`evidence/versions.txt`, `evidence/state-cross-read.txt`, `evidence/plan-diff.txt`).
3. Que escribiste `adr/0001-terraform-vs-opentofu.md` con la estructura ADR estándar y los campos obligatorios.

## 3. Objetivos

- Instalar OpenTofu y constatar su versión.
- Correr un mismo stack con `terraform` y con `tofu`; verificar que ambos leen el mismo state y el mismo lockfile sin regenerarlo.
- Comparar el `plan -json` de ambas herramientas sobre el mismo state y documentar divergencias (o su ausencia).
- Investigar y registrar al menos 3 features propias de OpenTofu que podrían influir en la decisión.
- Escribir un ADR con: contexto, opciones consideradas, criterios ponderados, decisión, consecuencias, plan de migración (o motivo de no migrar).

## 4. Prerrequisitos

- **Obligatorio para evidencia end-to-end**: binario `tofu` instalado. Instalación (elige una):
  - macOS / Linux (Homebrew): `brew install opentofu`
  - Script oficial: `curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh -s -- --install-method standalone`
  - Docs: https://opentofu.org/docs/intro/install/
- `terraform` también instalado (para comparar).
- `jq` para procesar `plan -json`.
- `bash`, `python3` para el validator.
- Si `tofu` no está instalado, el validator imprime instrucciones y **SKIP** las secciones correspondientes (no falla, pero no te da el PASS completo).

**Costos**: USD 0. El stack usa `random` + `local`, sin cloud.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/tf-tofu-eval
```

Crea `/tmp/tf-tofu-eval/project/` con:

- `stack/` — stack HCL mínimo (random_pet + local_file) para que sea gratis y rápido.
- `evidence/` — carpeta vacía donde depositarás las salidas.
- `adr/` — carpeta vacía donde escribirás el ADR.

### 5.2 Tareas

Trabaja en `/tmp/tf-tofu-eval/project/`:

1. **Verificar instalación**:

   ```bash
   cd stack
   terraform version > ../evidence/versions.txt
   tofu version      >> ../evidence/versions.txt
   ```

2. **Lockfile cross-tool** (hallazgo esperado: divergencia):

   ```bash
   terraform init
   # produce .terraform.lock.hcl con hashes de registry.terraform.io
   rm -rf .terraform
   set +e
   tofu init -lockfile=readonly
   rc=$?
   set -e
   echo "tofu init -lockfile=readonly rc=$rc" >> ../evidence/versions.txt
   ```

   **Hallazgo esperado**: desde ~2024, OpenTofu usa `registry.opentofu.org`
   mientras Terraform usa `registry.terraform.io`. El `tofu init -lockfile=readonly`
   **falla** (`rc=1`) sobre un lockfile escrito por Terraform. Eso NO rompe la
   compatibilidad del state; solo significa que cada herramienta mantiene su
   propio lockfile. Documenta esto en el ADR como *consequence*.

3. **State cross-read** (compatibilidad real):

   ```bash
   terraform apply -auto-approve
   # ahora el state existe en terraform.tfstate
   # tofu necesita init (regenera su propio lockfile apuntando a registry.opentofu.org)
   rm -rf .terraform .terraform.lock.hcl
   tofu init
   set +e
   tofu plan -detailed-exitcode -no-color > ../evidence/state-cross-read.txt 2>&1
   ec=$?
   set -e
   echo "exit=$ec" >> ../evidence/state-cross-read.txt
   ```

   El validator exige: el archivo existe, contiene `No changes` (o equivalente) y la línea `exit=0`.

4. **Plan equivalence**:

   ```bash
   # destruye y arranca limpio
   terraform destroy -auto-approve >/dev/null
   rm -rf .terraform terraform.tfstate*

   terraform init -no-color >/dev/null
   terraform plan -out=t.plan -no-color >/dev/null
   terraform show -json t.plan | jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' > ../evidence/t-changes.json

   rm -rf .terraform
   tofu init -no-color >/dev/null
   tofu plan -out=o.plan -no-color >/dev/null
   tofu show -json o.plan | jq -S '[.resource_changes[]? | {address, actions: .change.actions}]' > ../evidence/o-changes.json

   diff -u ../evidence/t-changes.json ../evidence/o-changes.json > ../evidence/plan-diff.txt || true
   ```

5. **Escribir ADR** en `adr/0001-terraform-vs-opentofu.md` con las secciones (mínimo):

   - `# ADR 0001: Terraform vs OpenTofu`
   - `## Status` (p. ej. `Proposed`, `Accepted`)
   - `## Context` — por qué estamos evaluando esto ahora.
   - `## Decision` — qué recomiendas (Terraform, OpenTofu, o mantener ambos).
   - `## Consequences` — qué pasa si se adopta.
   - `## Options considered` — al menos 2 opciones comparadas por 4 criterios: licencia, features, soporte, costo de migración.
   - `## Migration plan` (si decides migrar) o `## Why not migrate` (si no).
   - Debe mencionar explícitamente: `BUSL`, `Apache 2.0`, `Linux Foundation`, `state encryption`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/tf-tofu-eval
```

## 6. Resultado esperado

- `evidence/versions.txt` con `Terraform v...` y `OpenTofu v...` (si tofu instalado).
- `evidence/state-cross-read.txt` con "No changes" y exit 0.
- `evidence/plan-diff.txt` vacío o con solo diferencias cosméticas documentadas.
- `adr/0001-terraform-vs-opentofu.md` con las 6 secciones y las 4 menciones.
- Validator: `RESULT: ALL CHECKS PASS` (o `SKIP` controlado si no instalaste tofu, con reporte explícito).

## 7. Criterios de aceptación

- [ ] `tofu --version` instalado y evidenciado (o SKIP documentado).
- [ ] `tofu init -lockfile=readonly` acepta el lockfile de terraform.
- [ ] `tofu plan` sobre state de terraform reporta "no changes".
- [ ] Plan JSON equivalente (campo `resource_changes` idéntico).
- [ ] ADR con las 6 secciones y 4 menciones clave.
- [ ] ADR cita al menos 2 opciones y 4 criterios ponderados.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-tofu-eval
```

El validator:

1. Comprueba `tofu` en PATH (si no, SKIP + instrucciones).
2. Lee `evidence/versions.txt` y confirma menciones de `Terraform` y `OpenTofu`.
3. Lee `evidence/state-cross-read.txt` y confirma `No changes` + `exit=0`.
4. Lee `evidence/plan-diff.txt` y confirma que está vacío.
5. Lee `adr/0001-*.md` y comprueba secciones y menciones.

## 9. Preguntas de reflexión

1. Si el lockfile ya no fuera compatible entre tools (hipotético), ¿qué estrategia de migración seguirías?
2. ¿Qué significa "state encryption nativa" en OpenTofu y en qué escenario regulatorio sería decisivo?
3. Un proveedor interno te ofrece HCP Terraform gratis por 1 año. ¿Cómo pesa en tu ADR?
4. ¿Qué actores (fuera de tu equipo) deberían firmar un ADR de este tipo?
5. Si decides *no* migrar, ¿bajo qué condiciones reabrirías la decisión?

## 10. Extensiones

- **E1** — Añade una feature *solo-OpenTofu* al stack (p. ej. state encryption en bloque `encryption {}`) y documenta que ese stack **ya no** puede ser leído por `terraform`. Añade esa restricción al ADR.
- **E2** — Reemplaza el stack mínimo por tu módulo real del `tf-06` y repite la evaluación.
- **E3** — Mide tiempos (`time terraform plan` vs `time tofu plan`) sobre un stack grande; documenta en el ADR.

## 11. Limpieza

```bash
rm -rf /tmp/tf-tofu-eval
```
