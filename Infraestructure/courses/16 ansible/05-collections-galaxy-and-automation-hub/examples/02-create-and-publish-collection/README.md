# Ejemplo 02 — Crear y publicar una collection propia

> Lectura y análisis. Objetivo: ver el layout tras `ansible-galaxy collection init`, el `galaxy.yml` real que acompaña, y los dos comandos (build + publish) con sus flags.

## 1. Scaffold inicial

```bash
ansible-galaxy collection init mycorp.platform
```

Produce:

```
mycorp/
└── platform/
    ├── galaxy.yml
    ├── README.md
    ├── meta/
    │   └── runtime.yml
    ├── plugins/
    │   ├── README.md
    │   ├── modules/
    │   ├── module_utils/
    │   ├── inventory/
    │   ├── lookup/
    │   ├── filter/
    │   └── action/
    ├── roles/
    ├── playbooks/
    └── docs/
```

El scaffold inicial deja `galaxy.yml` con placeholders y `meta/runtime.yml` con un `requires_ansible` por defecto.

## 2. `galaxy.yml` real (anotado)

```yaml
---
# galaxy.yml — manifiesto de la collection mycorp.platform
namespace: mycorp                    # tu organizacion (reclamado en Galaxy o en tu Hub)
name: platform                       # nombre de la collection
version: 1.0.0                       # semver estricto; cambios breaking suben el mayor

readme: README.md
authors:
  - "Platform Team <platform@mycorp.local>"

description: >
  Roles y modulos reusables de la plataforma: bootstrap de nodos,
  bastion, baseline de observabilidad, lookup para Secrets Manager interno.

license:
  - Apache-2.0

tags:
  - platform
  - internal
  - linux
  - aws

# Collections de las que depende esta collection (resueltas por ansible-galaxy).
dependencies:
  "amazon.aws": ">=8.0.0,<9.0.0"
  "ansible.posix": ">=1.5.0,<2.0.0"

repository: https://gitlab.mycorp.local/platform/ansible-collection-platform
documentation: https://docs.mycorp.local/platform/ansible/
homepage: https://docs.mycorp.local/platform/
issues: https://gitlab.mycorp.local/platform/ansible-collection-platform/-/issues

# Archivos a excluir del tarball (regex sobre paths).
build_ignore:
  - "tests/"
  - ".github/"
  - ".gitlab-ci.yml"
  - "docs/_build/"
```

Puntos clave:

- **`namespace` + `name`** forman el identificador: `mycorp.platform`.
- **`version`** semver puro. Breaking → bump mayor. Red Hat Automation Hub **rechaza** uploads sin semver válido.
- **`dependencies`** son otras **collections** (no roles ni paquetes Python). Para Python se declara en `meta/runtime.yml` o en el README; `ansible-galaxy` no instala Python.
- **`build_ignore`** evita publicar el harness de tests y CI dentro del tarball final.

## 3. `meta/runtime.yml`

```yaml
---
requires_ansible: ">=2.17.0"

plugin_routing:
  modules:
    # Si en el futuro renombramos el modulo `bastion_setup` a `bastion_bootstrap`,
    # declaramos un alias para no romper playbooks existentes:
    bastion_setup:
      redirect: mycorp.platform.bastion_bootstrap
      deprecation:
        removal_version: 2.0.0
        warning_text: "Usa mycorp.platform.bastion_bootstrap"
```

`meta/runtime.yml` es el **contrato de compatibilidad** de la collection. Cuanto más usada, más críticos sus `plugin_routing` y `requires_ansible`.

## 4. Build

```bash
cd mycorp/platform
ansible-galaxy collection build
# Produce: mycorp-platform-1.0.0.tar.gz
```

Flags útiles:

- `--force`: sobreescribe si ya existe el tarball.
- `--output-path dist/`: donde dejar el tarball.

## 5. Publish

### A Galaxy público

```bash
ansible-galaxy collection publish \
  mycorp-platform-1.0.0.tar.gz \
  --api-key "$GALAXY_API_KEY"
```

El `GALAXY_API_KEY` se obtiene en https://galaxy.ansible.com/ui/token/ tras login con GitHub.

### A Automation Hub (interno o SaaS)

```bash
ansible-galaxy collection publish \
  mycorp-platform-1.0.0.tar.gz \
  --server https://automation-hub.mycorp.local/api/galaxy/ \
  --api-key "$AH_TOKEN"
```

El `AH_TOKEN` se saca de la consola de Automation Hub (SSO con Red Hat o LDAP interno).

### Importador asíncrono

`publish` solo **sube** el tarball; el importador del servidor lo procesa, valida el `galaxy.yml`, chequea semver y lo pone disponible. En Galaxy público puede tardar 30–120 s. En Hub local, segundos. Si falla, el import log explica el motivo (p. ej. `version 1.0.0 already exists`).

## 6. Preguntas de autocomprobación

1. Si en 1.1.0 añado un parámetro **opcional** a un módulo, ¿es breaking?
2. Si en 1.1.0 **cambio el tipo** de un parámetro de `str` a `list[str]`, ¿es breaking?
3. ¿Dónde declaro que mi módulo necesita `boto3 >= 1.34`?
4. ¿Por qué `tests/` debe ir en `build_ignore`?
5. ¿Qué pasa si subo `1.0.0` a Galaxy y segundos después me doy cuenta de un bug? (Pista: no se puede sobreescribir; publicar `1.0.1`.)
