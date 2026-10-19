# Repo de plataforma — dependencias de collections

Este repo consume collections externas (una certified AWS, una comunitaria general y una POSIX) y empaqueta roles propios bajo la collection `mycorp.platform`.

## Collections externas

- **`amazon.aws` 8.2.0** (certified, mantenida por AWS + Red Hat). Pin exacto porque la migracion 7.x → 8.x renombro parametros de `ec2_vpc_net`. Fuente: Galaxy publico.
- **`community.general` 9.4.0** (comunitaria). Pin exacto para evitar rotacion inesperada; la collection es amplia y las breaking son frecuentes.
- **`ansible.posix` 1.5.4` (POSIX). Pin exacto por conservadurismo; la collection evoluciona poco.

## Collection propia mycorp.platform

Agrupa los roles y modulos reusables de la plataforma interna. Namespaced bajo `mycorp.platform` para evitar colisiones con upstream. Publicada al Private Automation Hub de mycorp y pineada por tag git en los repos que la consumen (ver `galaxy.yml` para `repository` y `issues`).

Estructura (ver `mycorp/platform/`):

- `galaxy.yml` — manifiesto con namespace, version, authors, license, tags, dependencies, repository.
- `meta/runtime.yml` — requiere `ansible-core >= 2.17`.
- `plugins/modules/` — modulos Python propios (vacio en v1.0.0, se llenara en siguientes releases).
- `roles/` — roles reusables.
- `playbooks/` — playbooks de referencia que la collection publica.

## Instalación

```bash
# Dependencias externas, instaladas al path local del repo.
ansible-galaxy collection install -r collections/requirements.yml -p ./collections --force

# Verifica:
ansible-galaxy collection list -p ./collections

# Para que ansible-playbook las resuelva, exporta la ruta:
export ANSIBLE_COLLECTIONS_PATH=./collections:./mycorp
```

El contenido de `./collections/` se añade a `.gitignore`; `collections/requirements.yml` y `mycorp/platform/` **sí** se versionan.
