# ans-08 — Lección: testing con Molecule, lint y CI

> 9 secciones. Prerrequisito: `ans-04` (roles).

---

## 1. Por qué testear playbooks y roles

El mito más caro de Ansible es "si corre, está probado". Los roles rompen de tres formas típicas:

1. **La próxima distro**: funcionaba en Ubuntu 22.04; en Debian 12 el nombre del paquete cambia o el servicio arranca de otra forma.
2. **La próxima versión de `ansible-core`**: un argumento se vuelve obligatorio, un módulo cambia de collection, un filtro Jinja se deprecated.
3. **El próximo colaborador**: añade una tarea `shell:` sin `creates:` y la segunda ejecución reporta `changed`, aunque *parezca* funcionar.

Sin tests, estos defectos salen en producción. Con tests, salen en CI antes del merge. La disciplina es la misma que en cualquier código: **lint + test unitarios + CI matrix**. En Ansible, los nombres son:

- **Lint estático** → `ansible-lint`, `yamllint`.
- **Test funcional** → `molecule test` (ciclo con contenedor efímero + verifier).
- **Matriz** → GitHub Actions (o GitLab CI, Drone, etc.) corriendo las dos capas anteriores contra N distros y M versiones de `ansible-core`.

> **Idea clave:** sin **idempotencia probada automáticamente**, un role no es más que un script Bash con sintaxis YAML.

---

## 2. `ansible-lint`: la red mínima

`ansible-lint` recorre playbooks, roles y collections buscando antipatterns conocidos. Reglas típicas:

- **`name[missing]`**: toda tarea debe tener `name:`.
- **`no-changed-when`**: `command:` / `shell:` sin `changed_when:` reporta `changed` siempre.
- **`risky-shell-pipe`**: pipes en `shell:` sin `set -o pipefail`.
- **`fqcn[action-core]`**: usa el nombre completo `ansible.builtin.copy` en vez de `copy`.
- **`yaml[*]`**: delega al linter YAML las reglas de estilo.

Config típica (`.ansible-lint`):

```yaml
---
profile: production
exclude_paths:
  - .cache/
  - .github/
  - molecule/
skip_list:
  - experimental
warn_list:
  - fqcn[action-core]  # mientras migras todo a FQCN
```

Los **perfiles** (`min`, `basic`, `moderate`, `safety`, `shared`, `production`) activan progresivamente más reglas. `production` es el techo razonable para un role que vas a publicar.

El criterio: **falla el CI si `ansible-lint` reporta cualquier violación de nivel `error`**. Las `warning` las toleras temporalmente mientras limpias deuda.

---

## 3. `yamllint`: estilo YAML

Config (`.yamllint`):

```yaml
---
extends: default
rules:
  line-length:
    max: 160
  truthy:
    allowed-values: ["true", "false"]
  comments:
    min-spaces-from-content: 1
```

`ansible-lint` corre `yamllint` por detrás si lo encuentra. Mantener los dos linters alineados evita falsos positivos (un error en `yamllint` que `ansible-lint` repite).

---

## 4. Molecule: anatomía del scenario

Un **scenario** vive en `molecule/<nombre>/` dentro del role. El layout mínimo:

```
molecule/default/
├── molecule.yml      # define driver, platforms, provisioner, verifier
├── converge.yml      # el playbook que aplica el role bajo test
└── verify.yml        # asserts tras la convergencia
```

`molecule.yml` típico con driver Docker:

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        app_port: 8080
verifier:
  name: ansible
```

Puntos de dolor comunes:

- **Imágenes `pre_build_image: true`**: evita que Molecule intente instalar Python/Ansible dentro del contenedor en cada run. Las imágenes de `geerlingguy/*` ya vienen listas.
- **`systemd` en Docker**: para probar servicios reales (`systemctl status nginx`) la imagen necesita `init: true` y `/sbin/init` + `/sys/fs/cgroup`. Las `geerlingguy/*` lo hacen por defecto.
- **Collections**: declara dependencies en `requirements.yml` dentro del scenario, no asumas que están instaladas globalmente.

---

## 5. El ciclo `molecule test`

`molecule test` encadena 7 fases. Las esenciales:

1. **`destroy`**: elimina cualquier instancia previa (idempotencia del propio test).
2. **`create`**: levanta la(s) plataforma(s) definidas en `platforms:`.
3. **`prepare`**: si existe `prepare.yml`, lo corre (p. ej. instalar dependencias de sistema).
4. **`converge`**: aplica el role bajo test (equivale al `playbook.yml` real).
5. **`idempotence`**: vuelve a correr `converge.yml` y falla si **cualquier** tarea reporta `changed`.
6. **`verify`**: ejecuta `verify.yml` (asserts) o pytest/Testinfra.
7. **`destroy`**: limpia.

Comandos típicos durante el desarrollo:

- `molecule converge` — levanta y aplica, pero deja el contenedor vivo para iterar.
- `molecule login` — entra al contenedor para debuggear.
- `molecule verify` — vuelve a correr solo los asserts.
- `molecule destroy` — limpia manualmente.
- `molecule test` — ciclo completo (lo que debe correr CI).

> **Trampa**: si trabajas con `converge` y luego cambias el role, debes `destroy` y `test` de nuevo para probar la **idempotencia real** desde cero.

---

## 6. Verifier: Ansible asserts vs Testinfra

**Ansible asserts** (default, `verify.yml`):

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  tasks:
    - name: Nginx service is running
      ansible.builtin.service_facts:

    - name: Assert nginx is active
      ansible.builtin.assert:
        that:
          - "'nginx.service' in services"
          - services['nginx.service'].state == 'running'
```

Pros: mismo lenguaje que el role, acceso a módulos de Ansible, cero dependencias extra.
Contras: cuando los asserts se vuelven complejos (parsear JSON, iterar sobre N recursos), se vuelve verboso.

**Testinfra** (verifier `testinfra`, archivos pytest en `molecule/default/tests/`):

```python
def test_nginx_running(host):
    nginx = host.service("nginx")
    assert nginx.is_running
    assert nginx.is_enabled

def test_port_80_listening(host):
    assert host.socket("tcp://0.0.0.0:80").is_listening
```

Pros: expresivo, API rica (`host.file`, `host.socket`, `host.user`, `host.package`), encaja si tu equipo ya hace Python.
Contras: una dependencia más (pytest + pytest-testinfra), curva de aprendizaje.

**Recomendación práctica**: asserts para el 80% de los roles; Testinfra cuando ya tengas pytest y quieras asertar cosas que Ansible no modela cómodamente (p. ej. "este socket responde en N ms").

---

## 7. Elegir driver: Docker vs Podman vs otros

| Driver | Cuándo usarlo | Notas |
|--------|---------------|-------|
| **Docker** | Default práctico. CI de GitHub viene con Docker. | Requiere daemon. Problema de licensing en Docker Desktop para empresas grandes. |
| **Podman** | Alternativa rootless. Compat API con Docker. | Mejor huella de seguridad, soporte systemd nativo. En CI de GitHub pide instalación extra. |
| **Vagrant** | Cuando necesitas probar en VMs reales (networking complejo, kernel modules). | Lento. Usar solo cuando Docker/Podman no basten. |
| **EC2 / GCE / Azure** | Pruebas de aprovisionamiento real contra cloud. | Caro y lento. Reservar para suites de release, no para cada PR. |
| **Delegated** | Correr contra `localhost` del runner. | Útil para roles que configuran el propio runner (raro). |

Para `ans-08` usamos **Docker** por simplicidad y porque GH Actions lo trae de serie.

---

## 8. CI con GitHub Actions: matriz y gate

Un workflow mínimo pero correcto:

```yaml
---
name: role-ci

on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install ansible-core==2.17.* ansible-lint yamllint
      - run: ansible-lint
      - run: yamllint .

  molecule:
    needs: lint
    runs-on: ubuntu-22.04
    strategy:
      fail-fast: false
      matrix:
        distro:
          - geerlingguy/docker-ubuntu2204-ansible:latest
          - geerlingguy/docker-debian12-ansible:latest
          - geerlingguy/docker-rockylinux9-ansible:latest
        ansible-core:
          - '2.16.*'
          - '2.17.*'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install "ansible-core==${{ matrix.ansible-core }}" molecule molecule-plugins[docker] docker
      - env:
          MOLECULE_DISTRO: ${{ matrix.distro }}
        run: molecule test

  publish:
    needs: molecule
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install ansible-core
      - run: ansible-galaxy role import --api-key "${{ secrets.GALAXY_API_KEY }}" "${{ github.repository_owner }}" "${{ github.event.repository.name }}"
```

Observaciones de diseño:

- **`lint` como gate previo**: no gastes minutos de matriz si el lint falla.
- **`fail-fast: false`**: quieres ver los 6 fallos a la vez, no abortar al primero.
- **Matriz pequeña (3×2)**: 6 jobs es manejable; 5×4 son 20 y empiezas a sufrir.
- **`publish` condicionada a tag SemVer**: `if: startsWith(github.ref, 'refs/tags/v')`.
- **Secreto `GALAXY_API_KEY`**: configurado en el repo, nunca en el YAML.

---

## 9. Qué va *mal* en la práctica

- **Molecule verde en tu laptop, rojo en CI**: casi siempre es una imagen con cache local que no está en GH; forzar `pre_build_image: true` y pin de tag.
- **`idempotence` falla por `shell:`**: la raíz del 80% de fallos. Si no puedes migrar a un módulo nativo, pon `creates:`/`removes:` o `changed_when: false`.
- **Lint falla solo en CI**: tienes versiones distintas de `ansible-lint` local vs CI. Fija versión en `requirements.txt` del role.
- **Tests que pasan en Ubuntu pero rompen en Rocky**: nombre del paquete (`apache2` vs `httpd`), ruta de configs (`/etc/nginx/sites-enabled/` no existe en Rocky), systemd unit distinta. Es *exactamente* el tipo de bug que la matriz te ahorra en producción.
- **CI sin cache**: cada job reinstala collections. Añade `actions/cache@v4` para `~/.ansible/collections` y `~/.cache/pip`.

> **Resumen operativo**: lint estricto + Molecule con idempotencia probada + matriz CI pequeña y honesta. Con eso, un role sobrevive al próximo colaborador.
