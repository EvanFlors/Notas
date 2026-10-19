# Lección — Collections, Ansible Galaxy y Automation Hub

> Objetivo: salir del módulo entendiendo **qué** es una collection, **por qué** existe desde 2.10, **cómo** se consume con `requirements.yml` + lockfile, y **cuándo** decidir Galaxy público, Automation Hub o un registry propio.

Mapa de la lección:

1. De `ansible` monolítico a `ansible-core` + collections.
2. Anatomía de una collection.
3. `requirements.yml` — el `package.json` de Ansible.
4. Lockfile y reproducibilidad.
5. Namespaces canónicos y cómo encontrarlos.
6. Instalación aislada en `./collections`.
7. Crear tu propia collection (`ansible-galaxy collection init`).
8. Ansible Galaxy público vs Automation Hub vs registry privado.
9. Criterios de adopción de una collection comunitaria.
10. Patrón de rollback: fijar versión como vía de escape.

---

## 1. De `ansible` monolítico a `ansible-core` + collections

Hasta la versión 2.9, instalar `ansible` traía **el ejecutor + todos los módulos** (centenares) en un único paquete. Mantenerlo escalaba mal: un bug en el módulo `aws_s3` forzaba una release de todo Ansible, y los PRs de la comunidad se acumulaban por falta de bandwidth del core team.

Desde **2.10** se partió en dos:

- **`ansible-core`**: el ejecutor (`ansible`, `ansible-playbook`, `ansible-galaxy`, `ansible-config`), el parser YAML, el motor Jinja2 y un puñado mínimo de módulos (`ansible.builtin.*` — `copy`, `template`, `file`, `shell`, `command`, `uri`, `wait_for`...).
- **collections** (`ansible.posix`, `community.general`, `amazon.aws`, `kubernetes.core`...): el resto de módulos y plugins, cada uno con su propio ciclo de releases, su repo Git y sus mantenedores.

La distribución **`ansible`** (el metapaquete) sigue existiendo: es `ansible-core` + un conjunto curado de collections. En práctica, en un repo serio, se instala solo `ansible-core` (con `pipx install ansible-core`) y las collections necesarias se declaran en `requirements.yml` y se instalan reproduciblemente.

> **Idea clave**: `ansible-core` y las collections son ciclos de release **independientes**. Un bug fix en `community.aws` sale en días; una release de `ansible-core` tarda meses.

## 2. Anatomía de una collection

Una collection es un **paquete** (tar.gz) que contiene, bajo un namespace `<org>.<name>`:

```
mycorp.platform/
├── galaxy.yml              # manifiesto (nombre, versión, deps, authors)
├── README.md
├── LICENSE
├── meta/
│   └── runtime.yml         # redirects, compatibilidad con ansible-core
├── plugins/
│   ├── modules/            # modules Python (foo.py expone foo_module)
│   ├── module_utils/
│   ├── inventory/
│   ├── lookup/
│   ├── filter/
│   └── action/
├── roles/                  # roles reusables, misma estructura que ans-04
│   └── nginx/
├── playbooks/              # playbooks publicados como parte de la collection
└── docs/
```

Lo que importa recordar:

- **`galaxy.yml`** es el equivalente a `package.json`: nombre, versión semver, authors, `dependencies` (otras collections), `tags`, licencia, `repository`, `issues`.
- Un **module** dentro de `plugins/modules/foo.py` se invoca desde un playbook como `mycorp.platform.foo:`.
- Un **role** dentro de `roles/nginx/` se invoca como `include_role: name: mycorp.platform.nginx`.
- Es perfectamente válido empaquetar **solo roles** (ninguna module) o **solo modules**; la collection es un contenedor.

## 3. `requirements.yml` — el `package.json` de Ansible

Para consumir collections, un repo declara sus dependencias en `requirements.yml`:

```yaml
---
collections:
  - name: community.general
    version: "9.4.0"           # pin exacto (recomendado para prod)
  - name: amazon.aws
    version: ">=8.0.0,<9.0.0"  # rango compatible
  - name: ansible.posix
    version: "1.5.4"
  - name: mycorp.platform
    source: https://github.com/mycorp/ansible-collection-platform.git
    type: git
    version: v1.2.3            # tag o commit SHA
```

Campos relevantes:

- **`name`** → `namespace.collection_name`.
- **`version`** → semver, rango o tag git. En producción se recomienda **pin exacto**.
- **`source`** → URL de origen; por defecto Galaxy público.
- **`type`** → `galaxy` (default), `git`, `url`, `file`, `dir`. `git` es muy útil para collections internas de la organización.

Para instalar:

```bash
ansible-galaxy collection install -r requirements.yml -p ./collections
```

El flag `-p ./collections` instala en una ruta **local al repo** (no en `~/.ansible/collections`), lo que facilita reproducibilidad, aislamiento entre proyectos y revisar qué versiones viajan en el PR.

## 4. Lockfile y reproducibilidad

Hasta `ansible-core` 2.16 no había un **lockfile oficial** como `package-lock.json` o `poetry.lock`. La reproducibilidad se lograba *pineando* en `requirements.yml` cada versión y confiando en que Galaxy no borrara releases (nunca ha pasado, pero conceptualmente era frágil).

Desde **`ansible-core` 2.17/2.18** el flujo de lockfile está más maduro:

- `ansible-galaxy collection list` imprime el inventario instalado con versiones exactas.
- Con `--requirements-file` se puede regenerar un `requirements.yml` resuelto a partir del estado instalado (equivalente a `pip freeze`).

El patrón recomendado en 2026:

1. En `requirements.yml` declaras **rangos** o **pins** manuales (por legibilidad del PR).
2. Tras instalar, generas (o versionas) un `requirements.lock.yml` con las versiones resueltas.
3. CI instala desde `requirements.lock.yml` para builds reproducibles. Developers instalan desde `requirements.yml` para recibir updates compatibles.

Alternativa simple y robusta hoy: **solo pin exacto en `requirements.yml`**, sin lockfile adicional. Es menos ergonómico, pero elimina el riesgo de divergencia.

## 5. Namespaces canónicos y cómo encontrarlos

Los namespaces más usados a conocer:

| Namespace | Dueño | Qué cubre |
|-----------|-------|-----------|
| `ansible.builtin` | ansible-core | módulos base (`copy`, `file`, `template`, `shell`, `command`, `uri`, `service`, `systemd`, `user`, `group`, `cron`, `wait_for`). Vienen con `ansible-core`, no se instalan. |
| `ansible.posix` | Comunidad (curada) | utilidades POSIX (`sysctl`, `mount`, `firewalld`, `authorized_key`, `patch`). |
| `community.general` | Comunidad amplia | módulos de propósito general (centenares: `docker_*`, `pacman`, `ufw`, `pipx`, `homebrew`, `java_cert`...). Alta rotación. |
| `community.aws` | Comunidad AWS | módulos AWS **no** oficiales (lo que `amazon.aws` no cubre). |
| `amazon.aws` | AWS + Red Hat | módulos AWS **oficiales / certificados**: `ec2_*`, `s3_*`, `iam_*`, inventory `aws_ec2`. |
| `kubernetes.core` | Red Hat | `k8s`, `helm`, inventory `k8s`. |
| `google.cloud` | Google + comunidad | módulos GCP. |
| `azure.azcollection` | Microsoft + comunidad | módulos Azure. |

Dónde buscarlos:

- **Galaxy público**: https://galaxy.ansible.com/ui/
- **Automation Hub** (requiere subscripción Red Hat): https://console.redhat.com/ansible/automation-hub
- **GitHub**: casi todas tienen repo público bajo `ansible-collections/<name>`.

## 6. Instalación aislada en `./collections`

Hay tres rutas típicas donde `ansible-galaxy` puede instalar collections:

1. **Sistema** (`/usr/share/ansible/collections/`): si tu paquete `ansible` del SO lo trae; no tocarlo.
2. **Usuario** (`~/.ansible/collections/`): default si no pasas `-p`. Compartido entre proyectos — fuente de bugs ("en mi máquina sí").
3. **Proyecto** (`./collections/`): recomendado. Convive con `requirements.yml` en el repo. Se añade a `.gitignore` el contenido (pero no la carpeta vacía).

Para que `ansible-playbook` encuentre las collections en `./collections`, exporta:

```bash
export ANSIBLE_COLLECTIONS_PATH=./collections
```

o declara en `ansible.cfg`:

```ini
[defaults]
collections_path = ./collections
```

Esto hace que `playbook.yml` que usa `amazon.aws.ec2_instance:` resuelva contra la copia local, no contra la del usuario o la del sistema.

## 7. Crear tu propia collection

Scaffold inicial:

```bash
ansible-galaxy collection init mycorp.platform
```

Genera un directorio `mycorp/platform/` con `galaxy.yml`, `README.md`, `meta/runtime.yml`, `plugins/` (con subcarpetas y READMEs), `roles/`, `playbooks/`, `docs/`.

Luego:

1. Editas `galaxy.yml` (versión, authors, license, `tags`, `repository`).
2. Si traes roles existentes desde el módulo `ans-04`, los mueves a `roles/<role_name>/`.
3. Pruebas localmente desde un repo de ejemplo que la referencie en `requirements.yml` con `source: file:///ruta/absoluta/mycorp/platform type: dir`.
4. Para publicar, construyes el tarball:

   ```bash
   ansible-galaxy collection build          # produce mycorp-platform-1.0.0.tar.gz
   ansible-galaxy collection publish mycorp-platform-1.0.0.tar.gz --api-key <TOKEN>
   ```

5. Si publicas a Galaxy público, necesitas un namespace reclamado y un token GitHub-OIDC o un token API clásico. Si publicas a Automation Hub, usas tu token Red Hat.

## 8. Ansible Galaxy público vs Automation Hub vs registry privado

Tres destinos canónicos:

### Galaxy público (`galaxy.ansible.com`)

- **Gratis**, abierto, requiere cuenta GitHub para publicar.
- Cualquiera puede subir una collection; **no hay firma por defecto**.
- Útil para OSS y para proyectos personales.
- Riesgo: *typosquatting* (`amazom.aws`) y collections abandonadas sin indicador claro.

### Automation Hub (Red Hat)

- Parte de **Red Hat Ansible Automation Platform (AAP)**. Requiere subscripción.
- Dos tiers:
  - **Certified Collections**: mantenidas y soportadas comercialmente por el vendor (p. ej. `amazon.aws` certified, `cisco.ios` certified). Firmadas con GPG.
  - **Validated Collections**: probadas por Red Hat para escenarios de referencia (menos cobertura, más opinión).
- Un **`automation_hub`** interno (parte de AAP, basado en Pulp) permite espejar collections certificadas en la red de la empresa, lo que resuelve air-gap.

### Registry privado (Pulp, Nexus, Artifactory, GitLab Package Registry)

- La organización monta su propio registry.
- `requirements.yml` apunta a él con `source: https://pulp.mycorp.local/ api_key: ...`.
- Usual en bancos, gobierno o cualquier sitio con restricciones de egreso de red.
- Ventaja: control total, auditoría, firma propia.
- Coste: hay que mantenerlo.

### Decisión práctica

| Si eres... | Usa |
|------------|-----|
| Un developer OSS | Galaxy público. |
| Una org con AAP contratado | Automation Hub (certified) + Galaxy (community) para lo que no esté certificado. |
| Una org regulada sin AAP | Pulp interno espejando Galaxy + collections propias firmadas. |
| Una org sin regulación y sin AAP | Galaxy público + pin exacto en `requirements.yml`. |

## 9. Criterios de adopción de una collection comunitaria

Antes de depender de una collection comunitaria para prod, evalúala con estos 6 criterios:

1. **Mantenimiento activo**: ¿Hay releases en los últimos 6 meses? ¿Issues cerrados recientemente?
2. **Namespace y propietario**: ¿Está bajo `ansible-collections/` (comunidad oficial) o es un fork random? ¿Hay más de un maintainer?
3. **Cobertura de módulos**: ¿Expone los módulos que necesitas o solo parte? ¿Está la documentación completa en los `DOCUMENTATION:` blocks?
4. **Dependencias upstream**: ¿Qué SDK Python requiere (`boto3`, `kubernetes`, `google-auth`)? ¿La collection declara la versión mínima? ¿Es compatible con tu Python target?
5. **Licencia**: ¿GPL-3? ¿Apache-2? ¿Es compatible con tu política de licencias?
6. **Alternativas certificadas**: ¿Existe una collection certificada equivalente (`amazon.aws` para `community.aws`)? Si sí, pondera el salto a la certificada.

Si falla **2 o más**, no la adoptes para prod. Para sandbox o scripts puntuales, el umbral es más laxo.

## 10. Patrón de rollback: fijar versión como vía de escape

Un bug clásico: en `community.aws` 7.0.0 el módulo `s3_object` cambió el nombre del parámetro `encrypt` por `sse`. Los playbooks que usaban `encrypt: true` empezaron a fallar silenciosamente (parámetro ignorado) o ruidosamente (deprecation → error).

El patrón de respuesta:

1. **Pin** inmediato: `community.aws == 6.5.3` en `requirements.yml`.
2. Instalación limpia: `rm -rf ./collections && ansible-galaxy collection install -r requirements.yml -p ./collections`.
3. Issue upstream con repro mínima.
4. Migración planeada: PR que actualiza al nuevo nombre del parámetro + bump de la pin a `>=7.0.0`.

Sin pin, el bug se filtra a prod en el próximo deploy. Con pin, tienes semanas para migrar.

> **Moraleja**: la combinación `requirements.yml` pineado + `./collections` versionado por `requirements.lock.yml` (o pin exacto) + CI que reinstala limpio en cada run es la red mínima para que Ansible sea reproducible en 2026.

---

## Siguiente

Con las collections dominadas, el próximo módulo (`ans-06`) ataca el otro gran dolor de prod: **secretos**. `ansible-vault`, múltiples IDs, y por qué para prod serio Ansible debe *consultar* Secrets Manager / HashiCorp Vault, no almacenar secretos en el repo.
