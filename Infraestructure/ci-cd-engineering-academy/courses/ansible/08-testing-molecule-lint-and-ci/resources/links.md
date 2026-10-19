# Recursos — ans-08

Referencias oficiales y lecturas de apoyo. Verificar en Fase 4 del curso (los proyectos de Molecule y ansible-lint evolucionan rápido).

## Oficiales

- **Ansible Molecule — User Guide**: `https://ansible.readthedocs.io/projects/molecule/`
- **Molecule plugins (Docker, Podman, etc.)**: `https://github.com/ansible-collections/molecule_plugins`
- **ansible-lint — docs**: `https://ansible.readthedocs.io/projects/lint/`
- **ansible-lint — rules**: `https://ansible.readthedocs.io/projects/lint/rules/`
- **ansible-lint — profiles**: `https://ansible.readthedocs.io/projects/lint/profiles/`
- **yamllint — docs**: `https://yamllint.readthedocs.io/`
- **Testinfra — docs**: `https://testinfra.readthedocs.io/`
- **Ansible Galaxy — publishing roles**: `https://galaxy.ansible.com/docs/contributing/creating_role.html`

## GitHub Actions

- **`actions/checkout`**: `https://github.com/actions/checkout`
- **`actions/setup-python`**: `https://github.com/actions/setup-python`
- **`actions/cache`**: `https://github.com/actions/cache`
- **Reference workflow (ansible-community)**: `https://github.com/ansible-community/molecule/blob/main/.github/workflows/`

## Imágenes de Docker para Molecule

- **`geerlingguy/docker-*-ansible`** (Ubuntu, Debian, Rocky, Alma, Fedora): `https://hub.docker.com/u/geerlingguy`
- **Imágenes propias**: usar `pre_build_image: false` y un `Dockerfile.j2` en el scenario.

## Lecturas

- Jeff Geerling — "Ansible for DevOps" (capítulos de testing).
- Blog oficial de Ansible — artículos sobre Molecule y lint (varias ediciones por año).
- Red Hat Developer — "Testing roles with Molecule" (serie).

## Checklist de verificación requerida en Fase 4

- Versión actual de `ansible-core` (serie 2.17.x / 2.18.x) y matriz de soporte.
- Estado de `molecule-plugins` (el repo se separó del core de Molecule).
- Imágenes `geerlingguy/*` vigentes (Rocky 9, Debian 12, Ubuntu 22.04/24.04).
- Si `podman` es ya ciudadano de primera en Molecule (vs Docker).
- Si Galaxy acepta ya **collections** firmadas (sigstore) como para roles.
- Reemplazos: Testinfra sigue vivo; otros (goss, serverspec) perdieron tracción.
