# Actividad 01 — Añadir IaC scan al pipeline Terraform

## 1. Identificación

- **ID:** `sec-07-01-add-iac-scan-to-tf-pipeline`
- **Tecnología:** `devsecops`
- **Módulo:** `sec-07-iac-scanning-checkov-trivy-config-tfsec`
- **Dificultad:** intermediate
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes una carpeta Terraform (HCL puro, **sin `terraform apply`**) con misconfigs intencionales, más un par de manifests K8s. Vas a construir un `scan.sh` que:

1. Corra **Checkov** sobre el HCL.
2. Corra **Trivy config** sobre los manifests K8s.
3. Produzca un **`REPORT.md`** con un resumen clasificado.
4. Falle con exit code != 0 si hay findings `CRITICAL`/`HIGH` **salvo** que estén en el allowlist (`.suppressions`).

No se instancia nada en la nube. No hay credenciales. Solo HCL + YAML en disco.

## 3. Objetivos

- Combinar Checkov y Trivy config en un único script.
- Clasificar findings por severidad.
- Implementar un allowlist estructurado (CSV con razón + fecha de expiración) y usarlo para filtrar.
- Generar un `REPORT.md` reproducible.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` y los 3 `examples/`.
- Herramientas:
  - `bash`, `python3`, `jq` (requerido).
  - **Opcionales** (si no están, el script y el validador degradan graciosamente): `checkov`, `trivy`, `tfsec`. El lab **enseña** la lógica aunque no estén instalados; con ellos puedes verificar los findings reales.

Instalación rápida (opcional):

```bash
pip install checkov
# brew install trivy    # macOS
# brew install tfsec    # macOS
```

**Costos**: ninguno (no se hace `terraform apply`).

## 5. Instrucciones

### 5.1 Preparar workspace

```bash
mkdir -p /tmp/sec-07-iac-pipeline
cp -r starter/* /tmp/sec-07-iac-pipeline/
cd /tmp/sec-07-iac-pipeline
```

Puedes usar otro directorio: pásalo al validador con `bash tests/validate.sh /tu/ruta`.

### 5.2 Explorar el starter

```
starter/
├── terraform/           # HCL con misconfigs intencionales (sin apply)
│   ├── main.tf
│   └── variables.tf
├── k8s/
│   └── bad-pod.yaml     # pod con privileged, runAsRoot, etc.
├── suppressions.csv     # allowlist (vacío al principio)
└── scan.sh              # script a completar (hay TODOs)
```

### 5.3 Leer y correr `scan.sh`

Abre `scan.sh`. El script está dividido en 4 **Steps** comentados:

1. **Step 1**: ejecuta `checkov -d terraform/ -o json` y guarda en `checkov.json` (o escribe `{}` si Checkov no está instalado, con mensaje `SKIP`).
2. **Step 2**: ejecuta `trivy config k8s/ -f json -o trivy.json` (o `{}` si no está, con `SKIP`).
3. **Step 3**: aplica el allowlist (`suppressions.csv`) para excluir findings cuya regla esté listada.
4. **Step 4**: escribe `REPORT.md` con secciones **Resumen**, **Checkov**, **Trivy config**, **Suprimidos**.

Lee cada bloque. Comprende por qué `|| true` tras cada scanner (exit 1 cuando hay findings; no queremos que `set -e` corte el flujo). Luego:

```bash
chmod +x scan.sh
./scan.sh         # produce REPORT.md
```

El script debe:

- Ser idempotente (reescribir `REPORT.md` cada vez).
- Terminar con exit code **0** si no quedan findings `CRITICAL`/`HIGH` después del allowlist.
- Terminar con exit code **1** si queda al menos uno.
- **No** usar `set -o pipefail` (SIGPIPE con `jq | grep` daría falsos positivos).

### 5.4 Añadir una excepción justificada

Edita `suppressions.csv` para suprimir **una** regla específica (p. ej. una de las de HCL que has decidido que es intencional). Formato:

```csv
rule_id,reason,expires
CKV_AWS_20,bucket público intencional (static docs site) - ADR-0007,2026-06-01
```

Vuelve a correr `./scan.sh` y comprueba que:

- El `REPORT.md` lista la regla en **Suprimidos** con su razón.
- El exit code puede bajar a 0 si esa era la única regla bloqueante.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/sec-07-iac-pipeline
```

El validador comprueba estructura: existencia de `REPORT.md`, secciones requeridas, formato de `suppressions.csv`, `scan.sh` ejecutable y sin `pipefail`.

## 6. Resultado esperado

- `scan.sh` ejecutable (`chmod +x`) y corrido al menos una vez.
- `REPORT.md` existe y tiene las 4 secciones.
- `suppressions.csv` tiene al menos una entrada con razón y fecha.
- `bash tests/validate.sh /tmp/sec-07-iac-pipeline` → `OK: estructura valida`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador verde; `scan.sh` corre dos veces seguidas sin ensuciar estado.
- **Degradación graciosa**: `scan.sh` funciona (con mensajes `SKIP`) si Checkov o Trivy no están instalados.
- **Calidad**: cada supresión tiene razón + expiración.
- **Reproducibilidad**: borrar `/tmp/sec-07-iac-pipeline` y repetir desde `starter/` produce el mismo resultado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-07-iac-pipeline
```

## 9. Preguntas de reflexión

1. ¿Por qué no corremos `terraform apply` en este lab? ¿Qué perdemos y qué ganamos?
2. ¿Por qué el allowlist exige fecha de expiración? ¿Qué pasa si no la exiges?
3. Si Checkov y Trivy config detectan el mismo `privileged: true`, ¿cuál cuenta como el finding "oficial"? ¿Importa?
4. ¿Cuándo preferirías escanear el **plan JSON** y no HCL en este pipeline?
5. ¿Qué pasaría si cambias la política a "fallar también en MEDIUM"? ¿Es sostenible?

## 10. Extensiones

- Añade un tercer paso que corra `tfsec terraform/` si el binario existe y añada su sección al reporte.
- Añade salida SARIF (`checkov -o sarif`) y súbela a GitHub Code Scanning en tu capstone.
- Implementa la validación de expiración: `scan.sh` falla si una excepción expiró.

## 11. Limpieza

```bash
rm -rf /tmp/sec-07-iac-pipeline
```

No hay procesos ni contenedores corriendo.
