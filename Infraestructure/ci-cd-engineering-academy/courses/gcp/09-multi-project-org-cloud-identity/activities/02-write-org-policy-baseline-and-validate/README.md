# Actividad 02 — Escribir Org Policies del baseline y perímetro VPC-SC

## 1. Identificación

- **ID:** `gcp-09-02-write-org-policy-baseline-and-validate`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-09-multi-project-org-cloud-identity`
- **Dificultad:** advanced
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de Security te pide escribir el **baseline de Org Policies** de la organización y un **perímetro VPC-SC** para los projects regulados. Son cinco archivos YAML que todas las cuentas de la org tendrán aplicados cuando Fase 4 los lance con Terraform. No vas a adjuntarlos a nada: estás **escribiéndolos**. Deben ser YAML válido, respetar el schema de Org Policy v2 (resource-oriented), y venir acompañados de un documento que explique qué declara cada uno, dónde se adjuntará y qué excepciones contempla.

**Importante**: no hay organización GCP. No se aplica nada. El entregable son 4 YAMLs de Org Policy + 1 YAML de VPC-SC perimeter + 1 README. **Nunca** uses números de organization, folder ni project reales — todos los identificadores son placeholders.

## 3. Objetivos

Al terminar deberías poder:

- Escribir una Org Policy sintácticamente correcta usando `name`, `spec`, `rules`, `enforce`, `allowedValues`, `inheritFromParent`.
- Distinguir constraints **boolean** vs **list** y aplicar el formato correcto en YAML.
- Diseñar un perímetro VPC Service Controls con `restrictedServices`, `resources` y `accessLevels`.
- Justificar por escrito dónde adjuntar cada policy (Organization vs Folder vs Project) y por qué.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§6 Org Policy, §8 VPC-SC, §9 Org Policy vs IAM) y recorrido `../../examples/02-org-policy-anatomy/`.
- Herramientas: `bash`, `python3` (3.9+ con módulo `yaml` — `pip install pyyaml` si no lo tienes), un editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-09-org-policy
cd /tmp/gcp-09-org-policy
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 4 YAMLs de Org Policy

Nombres **exactos** (el validador los busca):

1. `org-policy-disable-sa-key-creation.yaml`
2. `org-policy-vm-external-ip.yaml`
3. `org-policy-storage-public-access-prevention.yaml`
4. `org-policy-allowed-member-domains.yaml`

Requisitos por archivo:

#### `org-policy-disable-sa-key-creation.yaml`

- `name` que empiece por `organizations/` y termine en `/policies/iam.disableServiceAccountKeyCreation`.
- `spec.rules[0].enforce == true`.
- `spec.inheritFromParent` definido (false si es root).

#### `org-policy-vm-external-ip.yaml`

- `name` con constraint `compute.vmExternalIpAccess`.
- `spec.rules[0]` debe tener `denyAll: true` **o** `values.deniedValues`.
- `spec.inheritFromParent` definido.

#### `org-policy-storage-public-access-prevention.yaml`

- `name` con constraint `storage.publicAccessPrevention`.
- `spec.rules[0].enforce == true`.

#### `org-policy-allowed-member-domains.yaml`

- `name` con constraint `iam.allowedPolicyMemberDomains`.
- `spec.rules[0].values.allowedValues` debe listar al menos un customer ID placeholder (p. ej. `C01abc234` — formato de 10 caracteres `C` + 9 alfanuméricos).

**Todos** deben ser YAML válido (parseable por `python3 -c "import yaml; yaml.safe_load(open('fichero'))"`).

### 5.3 Escribe el perímetro VPC-SC

Archivo: `vpc-sc-perimeter.yaml`.

Requisitos:

- `name` que empiece por `accessPolicies/` y termine en `/servicePerimeters/<nombre>` (puedes usar `prod_data_perimeter`).
- `title` descriptivo.
- `status.resources` con al menos 2 projects (formato `projects/<project-number-of-...>` como placeholder — **nunca** un número real).
- `status.restrictedServices` con al menos 3 servicios (de los habituales: `storage.googleapis.com`, `bigquery.googleapis.com`, `cloudkms.googleapis.com`, `secretmanager.googleapis.com`).
- `status.accessLevels` con al menos un access level (formato `accessPolicies/<id>/accessLevels/<name>`).

### 5.4 Escribe `README-INTENT.md`

Un documento que explique, para cada archivo:

- **Qué declara** (en lenguaje humano, no copiando el YAML).
- **A qué punto de la jerarquía se adjuntará** y por qué (Organization, Folder, Project).
- **Qué excepciones** hay (p. ej. `Sandbox` con `enforce=false`) o por qué no las hay.
- Para `vpc-sc-perimeter.yaml`, mención explícita de **dry-run mode** y de **Access Context Manager**.
- Para `org-policy-allowed-member-domains.yaml`, mención explícita del **customer ID** y de qué pasaría si no se restringe.

Secciones obligatorias (el validador las busca):

- `## org-policy-disable-sa-key-creation`
- `## org-policy-vm-external-ip`
- `## org-policy-storage-public-access-prevention`
- `## org-policy-allowed-member-domains`
- `## vpc-sc-perimeter`

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.5 Entregables

```
/tmp/gcp-09-org-policy/
├── org-policy-disable-sa-key-creation.yaml
├── org-policy-vm-external-ip.yaml
├── org-policy-storage-public-access-prevention.yaml
├── org-policy-allowed-member-domains.yaml
├── vpc-sc-perimeter.yaml
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 5 YAMLs parsean con `python3 + pyyaml`.
- El validador pasa en verde:
  - sintaxis YAML de cada archivo,
  - presencia de `name`, `spec.rules`, `enforce` o `denyAll` / `allowedValues` según corresponda,
  - para VPC-SC: `restrictedServices` con ≥3, `resources` con ≥2, `accessLevels` con ≥1,
  - presencia del `README-INTENT.md` con las 5 secciones.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud sintáctica**: YAML válido, indentación correcta.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **No fugas de identificadores reales**: ni organizations, ni folders, ni project numbers reales. Solo placeholders.
- **Mantenibilidad**: comentarios cortos opcionales explicando el intent.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-09-org-policy
```

El validador comprueba sintaxis YAML y presencia de claves/valores mínimos. **No** comprueba que la Org Policy, aplicada a una organización real, haga exactamente lo que dice el README. Esa validación semántica se hace en Fase 4 con `gcloud org-policies describe` contra una org real.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `enforce: false` en `org-policy-disable-sa-key-creation.yaml` y adjuntas la policy a Organization?
2. ¿Puedes aplicar `iam.allowedPolicyMemberDomains` sin conocer tu customer ID? ¿Dónde lo obtendrías en una org real?
3. ¿Por qué el perímetro VPC-SC debe arrancar en **dry-run mode** antes de `enforce`?
4. ¿Qué servicios NO se pueden poner en `restrictedServices` de un perímetro VPC-SC? (pista: hay una lista oficial).
5. Si un developer necesita trabajar temporalmente creando una VM con IP pública en `sandbox-shared`, ¿cómo le concedes acceso sin desactivar la Org Policy en Organization?
6. Traduce la SCP AWS `deny-regions` (bloquea todo fuera de `eu-west-1`/`eu-central-1`) a su equivalente GCP: ¿qué constraint usarías y con qué valores?

## 10. Extensiones

- Añade una quinta Org Policy: `org-policy-require-os-login.yaml` con `compute.requireOsLogin=enforced` adjunta a Folder `Workloads/Prod`.
- Añade un **custom constraint** en YAML (`custom-constraint-require-cost-center.yaml`) usando CEL para exigir label `cost_center` en VMs.
- Escribe un pequeño script `verify-policies.sh` que corra `python3 -c 'import yaml; ...'` + comprobaciones adicionales (p. ej. que todas las policies tengan `spec.inheritFromParent` definido).

## 11. Limpieza

```bash
rm -rf /tmp/gcp-09-org-policy
```

No hay infraestructura que detener.
