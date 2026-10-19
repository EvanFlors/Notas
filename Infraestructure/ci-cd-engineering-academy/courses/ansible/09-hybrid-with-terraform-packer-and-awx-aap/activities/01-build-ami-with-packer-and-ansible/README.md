# Actividad 01 — Plantilla Packer + playbook Ansible (validación local)

## 1. Identificación

- **ID:** `ans-09-01-build-ami-with-packer-and-ansible`
- **Tecnología:** `ansible`
- **Módulo:** `ans-09-hybrid-with-terraform-packer-and-awx-aap`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab

## 2. Contexto

Tu equipo acaba de aprobar migrar del patrón mutable (TF crea → Ansible configura) al patrón inmutable (Packer + Ansible → AMI → TF usa AMI) para la nueva **webapp**. Antes de tocar una cuenta AWS real, tienes que:

1. Escribir la **plantilla Packer HCL2** con el provisioner `ansible`.
2. Escribir el **playbook** que hornea nginx + usuario de servicio + CloudWatch Agent.
3. Documentar la intención en un `README-INTENT.md`.
4. **Validar todo localmente**: `packer validate`, `packer fmt -check`, `ansible-playbook --syntax-check`. Si tu máquina no tiene alguna de las herramientas, el validador la marca como **SKIP** y continúa — el objetivo del laboratorio es la escritura, no la instalación.

**Importante**: no se construye una AMI real (eso cuesta y requiere credenciales). Todo se valida en local.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir el bloque `required_plugins` para `amazon` y `ansible`.
- Escribir `source "amazon-ebs"` con `source_ami_filter` y `ssh_username`.
- Escribir `build { ... provisioner "ansible" { ... } }` con `playbook_file`, `user`, `use_proxy`, `extra_arguments`.
- Escribir un playbook idempotente (sin `shell` sueltos, con `become`, con módulos nativos).
- Explicar por qué `provisioner "ansible"` y no `ansible-local` por defecto.
- Explicar cómo Terraform consume el `ami_id` resultante.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 3, 4 y 5) y recorrido `../../examples/02-packer-ansible-ami/`.
- Herramientas (opcionales — el validador las chequea y hace SKIP si faltan):
  - `packer` ≥ 1.9 (`packer --version`)
  - `ansible-core` ≥ 2.14 (`ansible --version`)
  - `jq` (parser JSON — opcional, útil para extraer `ami_id` del manifest).

**No se requiere cuenta AWS. No se construye nada.**

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-09-01
cd /tmp/ans-09-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `webapp.pkr.hcl`

Nombre **exacto** (el validador lo busca). Requisitos:

- Bloque `packer { required_plugins { ... } }` con los plugins `amazon` (`github.com/hashicorp/amazon`) y `ansible` (`github.com/hashicorp/ansible`).
- Variable `region` tipo `string` con default (p. ej. `"eu-west-1"`).
- Variable `app_version` tipo `string` con `description`.
- Al menos un `source "amazon-ebs" "<nombre>"` con:
  - `region = var.region`
  - `instance_type` (p. ej. `"t3.micro"`)
  - `ami_name` que incorpore `var.app_version`
  - `source_ami_filter { ... owners = ["amazon"] }`
  - `ssh_username = "ec2-user"`
- Al menos un `build { sources = [...] provisioner "ansible" { ... } }` con:
  - `playbook_file = "./playbook.yml"`
  - `user = "ec2-user"`
  - `use_proxy = false`
  - `extra_arguments` (lista) que mencione `--extra-vars` y `app_version`.

### 5.3 Escribe `playbook.yml`

Requisitos:

- `hosts: all` (Packer inyecta un inventario de 1 host).
- `become: true`.
- Al menos 3 tasks usando módulos nativos (`ansible.builtin.dnf` / `apt` / `yum`, `user`, `copy`, `systemd`, `template`).
- Debe instalar `nginx` (string literal `nginx` presente).
- Debe crear un usuario de servicio (uso del módulo `user` o `ansible.builtin.user`).
- Debe habilitar nginx (`systemd` o `service` con `enabled: true`).
- **Sin `shell:` ni `command:` sin `creates:`/`changed_when: false`** — queremos idempotencia real.

### 5.4 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## Que se hornea`
- `## Que NO se hornea`
- `## Provisioner ansible vs ansible-local`
- `## Como consume Terraform el ami_id`

Contenido mínimo:

- Mencionar explícitamente **nginx** y **cloudwatch** (o `cloudwatch-agent`).
- Mencionar **secretos** y **user-data** / **Secrets Manager** / **Parameter Store** en la sección "Que NO se hornea".
- Mencionar **packer-manifest.json** o **artifact_id** en la sección de consumo por Terraform.

### 5.5 Entregables

```
/tmp/ans-09-01/
├── webapp.pkr.hcl
├── playbook.yml
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 3 archivos existen y cumplen requisitos estructurales.
- Si `packer` está instalado: `packer validate` pasa en el directorio (previo `packer init`).
- Si `ansible-playbook` está instalado: `--syntax-check` pasa.
- Si alguna herramienta falta: el validador reporta **SKIP** y continúa, sin fallar.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde (o con SKIPs justificados por herramientas ausentes).
- **Correctitud estructural**: HCL válido, YAML válido, Markdown con las 4 secciones.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/` (los tres archivos de referencia están ahí).
- **Mantenibilidad**: nombres claros, variables tipadas, módulos nativos de Ansible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-09-01
```

El validador comprueba:

- Presencia de los 3 archivos.
- Que `webapp.pkr.hcl` contiene los bloques y campos mínimos (grep estructural).
- Que `playbook.yml` tiene `hosts`, `become`, mencionar `nginx` y usuario, y **no** usa `shell`/`command` sin salvaguarda.
- Que `README-INTENT.md` tiene las 4 secciones y las menciones mínimas.
- Si `packer` está disponible: `packer fmt -check` + `packer validate` (previa `packer init`).
- Si `ansible-playbook` está disponible: `--syntax-check`.
- Si una herramienta falta: imprime `SKIP: packer no instalado` (o equivalente) y **no** falla el run.

## 9. Preguntas de reflexión

1. ¿Qué cambia si el `source_ami_filter` baja una AMI base distinta mañana? ¿Es reproducible?
2. ¿Por qué `use_proxy = false`? ¿En qué red falla si lo quitas?
3. ¿Qué pasa con secretos que la webapp necesita (DB password)? ¿Dónde los metes y por qué no en la AMI?
4. Diferencia operativa entre `provisioner "ansible"` y `provisioner "ansible-local"`.
5. ¿Cómo haces rollback a la AMI anterior tras un despliegue malo?

## 10. Extensiones

- Añadir un `post-processor "manifest"` que escriba `packer-manifest.json` con el `ami_id`.
- Añadir un segundo `source` para `arm64` (Graviton) usando el mismo build (`sources = ["source.amazon-ebs.al2023", "source.amazon-ebs.al2023-arm64"]`).
- Añadir un **role** Ansible aparte (`roles/webapp/`) y que el playbook lo use (en vez de tasks sueltos).
- Añadir una task de verificación con `ansible.builtin.uri` que compruebe que nginx responde en `localhost:80` **durante** el build (fail-fast).

## 11. Limpieza

```bash
rm -rf /tmp/ans-09-01
```

No hay procesos ni infraestructura que detener (nada se levantó en la nube).
