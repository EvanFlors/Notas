# Starter — ans-05-01-adopt-community-aws-collection

Esta actividad es una **guided-lab**: produces un árbol de archivos (`collections/requirements.yml`, `mycorp/platform/galaxy.yml`, estructura mínima de collection y `README.md`).

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/01-requirements-yml-with-collections/` y `../../examples/02-create-and-publish-collection/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-05-01/collections /tmp/ans-05-01/mycorp/platform/plugins/modules
   mkdir -p /tmp/ans-05-01/mycorp/platform/meta
   mkdir -p /tmp/ans-05-01/mycorp/platform/roles
   mkdir -p /tmp/ans-05-01/mycorp/platform/playbooks
   cd /tmp/ans-05-01
   ```
3. Escribe `collections/requirements.yml` con al menos 3 collections (`amazon.aws`, `community.general`, `ansible.posix`) pineadas por versión y con `source: https://galaxy.ansible.com`.
4. Escribe `mycorp/platform/galaxy.yml` con los campos obligatorios (ver `../README.md` §5.4) y `mycorp/platform/meta/runtime.yml` con `requires_ansible: ">=2.17.0"`.
5. Escribe `mycorp/platform/README.md` corto (1 párrafo) describiendo la collection.
6. Escribe `README.md` del repo con las 3 secciones obligatorias: `## Collections externas`, `## Collection propia mycorp.platform`, `## Instalacion` (o `## Instalación`).
7. (Opcional, con red) Instala:
   ```bash
   ansible-galaxy collection install -r collections/requirements.yml -p ./collections --force
   ansible-galaxy collection list -p ./collections
   ```
8. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/05-collections-galaxy-and-automation-hub/activities/01-adopt-community-aws-collection/tests/validate.sh /tmp/ans-05-01
   ```
9. Compara con `../solution/` para autoevaluarte.

## Esqueletos útiles

### `collections/requirements.yml`

```yaml
---
collections:
  - name: amazon.aws
    version: "8.2.0"
    source: https://galaxy.ansible.com
  # ...
```

### `mycorp/platform/galaxy.yml`

```yaml
---
namespace: mycorp
name: platform
version: 1.0.0
readme: README.md
authors:
  - "Platform Team <platform@mycorp.local>"
description: "Roles y modulos reusables de la plataforma interna."
license:
  - Apache-2.0
tags:
  - platform
  - internal
dependencies: {}
repository: https://gitlab.mycorp.local/platform/ansible-collection-platform
issues: https://gitlab.mycorp.local/platform/ansible-collection-platform/-/issues
```

> El validador comprueba estructura y presencia de campos; no publica la collection.
