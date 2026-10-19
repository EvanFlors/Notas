# Lección — ans-01: CM vs IaC, setup, inventory y ad-hoc

> Lectura obligatoria antes de las actividades. Toma unos 40–60 min.

---

## 1. El par CM / IaC: no son sinónimos

**IaC (Infrastructure as Code)** declara *qué recursos deben existir* en una plataforma (VMs, redes, buckets, bases de datos). El actor es Terraform / Pulumi / CloudFormation. Habla con APIs de cloud (AWS, GCP, Azure) y mantiene un *state* del mundo.

**CM (Configuration Management)** declara *cómo debe estar configurado un host que ya existe* (paquetes instalados, archivos escritos, servicios corriendo, usuarios creados). El actor histórico es Puppet, Chef, SaltStack, y hoy Ansible como el claro líder OSS.

Ejemplo contrastado para una app Flask en 3 VMs EC2:

| Fase | Herramienta natural | Qué hace |
|------|---------------------|----------|
| Crear 3 instancias EC2 + Security Group + Route 53 record | **Terraform** | `aws_instance`, `aws_security_group`, `aws_route53_record` |
| Instalar Python, gunicorn, nginx, copiar la app, arrancar systemd | **Ansible** | módulos `apt`, `copy`, `template`, `systemd` |
| Rotar el binario cada semana y aplicar un parche de kernel | **Ansible** (Day-2) | playbook de reemplazo + reboot controlado |

La confusión aparece porque **Ansible también puede crear recursos cloud** (hay módulos `amazon.aws.ec2_instance`, `community.aws.*`, etc.) y **Terraform también puede ejecutar comandos** (`remote-exec` provisioner). Reglas prácticas:

- Para *crear/destruir* infra cloud: Terraform. El state es su superpoder.
- Para *configurar* lo que ya existe: Ansible.
- Para apps en Kubernetes: ni uno ni otro — Helm, Kustomize o GitOps (ArgoCD/Flux).
- Para configuración *dentro* de un contenedor: ninguno — se hornea en la imagen (Dockerfile) o se inyecta en runtime.

Ansible brilla en **Day-2 operations**, **legacy**, **network devices**, **bare metal** y **bootstrap** de nodos (kubeadm, por ejemplo). Fuera de ahí, el riesgo es construir una pirámide de playbooks donde una imagen inmutable sería más limpia.

---

## 2. El modelo de ejecución: push + agentless + SSH

Casi todas las CM clásicas (Puppet, Chef) usan **pull + agent**: cada host corre un demonio que periódicamente baja la configuración del master. Ansible rompió con eso:

- **Push**: tú lanzas Ansible desde una máquina (tu laptop, un runner CI, AWX). Ansible abre conexiones salientes.
- **Agentless**: no hay demonio en el target. Solo se requiere **SSH** y **Python** (2.7 o 3.5+) en el host destino. Para dispositivos de red, hay módulos que hablan NETCONF/API y no requieren Python en el aparato.
- **Transporte**: SSH por defecto en Linux; `winrm`/`psrp` en Windows; `local` para `localhost`; conectores específicos (`docker`, `kubectl`, `podman`, `community.vmware.vmware_tools`).

### 2.1 Qué pasa cuando corres `ansible all -m ping`

1. Ansible lee tu inventory, resuelve el grupo `all`.
2. Para cada host, abre una conexión SSH (o la que corresponda).
3. Serializa el **módulo** (`ping` en este caso, un pequeño script Python).
4. Lo copia al target (en `~/.ansible/tmp/` o similar), lo ejecuta como el usuario configurado.
5. El módulo imprime **JSON** en stdout.
6. Ansible parsea el JSON y agrega la respuesta a su resumen.
7. Si usas `become`, se escala a `sudo` antes de ejecutar.

Notas importantes:

- `ping` **no es ICMP**. Es un módulo que simplemente verifica "¿puedo conectarme y correr Python en este host?". Si falla, debugueas SSH y Python, no la red ICMP.
- Si el target no tiene Python, existe el módulo `raw` como escape (ejecuta shell crudo sin Python).
- La latencia es alta: cada módulo abre una sesión SSH nueva salvo que actives **ControlPersist** o **pipelining**.

### 2.2 Rendimiento

Factores de performance (lo retomaremos en `ans-07`):

- `forks` (en `ansible.cfg`): paralelismo. Default 5 — súbelo a 20–50 para flotas medianas.
- `pipelining = True`: evita el copy del módulo al disco del target.
- `ControlPersist` de SSH: reutiliza la sesión TCP (defecto activo en versiones recientes).
- `fact caching`: evita re-recolectar facts en cada run.
- Mitogen (plugin externo): acelera órdenes de magnitud; su mantenimiento ha sido irregular — verifica estado antes de depender de él.

---

## 3. Instalación

### 3.1 Ansible-core vs ansible (el paquete)

Desde Ansible 2.10, el proyecto se dividió:

- **`ansible-core`**: motor + módulos esenciales (unos ~70). Es el paquete mínimo.
- **`ansible`**: `ansible-core` + un *bundle* de **collections comunitarias** (centenares de módulos: `community.general`, `ansible.posix`, `community.docker`, etc.). Es lo que normalmente quieres como usuario.

### 3.2 Instalación recomendada (local, dev)

```bash
# macOS/Linux con pipx (aisla deps):
pipx install --include-deps ansible

ansible --version
# ansible [core 2.17.x]
#   python version = 3.11.x
#   jinja version = 3.1.x
#   libyaml = True
```

Alternativas:

- `brew install ansible` (macOS, cómodo pero menos control de versión).
- `pip install --user ansible` (OK, pero sin aislamiento).
- Paquete del SO (`apt install ansible`): suele estar atrasado — evitar en dev.
- **Execution Environment** (contenedor con `ansible-core` + collections pinned): el patrón que usa AAP; interesante en prod/CI.

### 3.3 Qué incluye tu instalación

```bash
ansible-galaxy collection list
# community.general           10.x.x
# amazon.aws                  9.x.x
# ansible.posix               1.6.x
# ...
```

Si un módulo no aparece, su collection no está instalada; se añade con `ansible-galaxy collection install <ns>.<name>`.

---

## 4. Inventory estático

El inventory es la fuente de verdad de **qué hosts existen** y **cómo agruparlos**. Admite dos formatos nativos: INI y YAML. YAML es más expresivo (soporta nested groups con `children` y variables anidadas); INI es más conciso para flotas pequeñas.

### 4.1 YAML (recomendado)

```yaml
# hosts.yml
all:
  children:
    web:
      hosts:
        web-01.example.com:
        web-02.example.com:
    db:
      hosts:
        db-01.example.com:
      vars:
        ansible_user: dba
        ansible_port: 2222
    prod:
      children:
        web:
        db:
      vars:
        env: production
```

- `all` es el grupo raíz implícito; cada host pertenece a `all` y a `ungrouped` por defecto.
- `children` permite grupos de grupos (aquí `prod` contiene a `web` y `db`).
- Las variables definidas en el grupo se aplican a todos sus hosts.

### 4.2 INI (clásico)

```ini
# hosts.ini
[web]
web-01.example.com
web-02.example.com

[db]
db-01.example.com ansible_user=dba ansible_port=2222

[prod:children]
web
db

[prod:vars]
env=production
```

### 4.3 group_vars y host_vars (preferido)

Mejor no incrustar vars en el inventory. Separa:

```
inventory/
  hosts.yml
  group_vars/
    all.yml
    web.yml
    prod.yml
  host_vars/
    db-01.example.com.yml
```

Ansible carga automáticamente estos ficheros si están junto al inventory.

### 4.4 Variables de conexión clave

| Variable | Para qué |
|----------|----------|
| `ansible_host` | IP o DNS real (si difiere del nombre del host en el inventory). |
| `ansible_user` | Usuario SSH remoto. |
| `ansible_port` | Puerto SSH. |
| `ansible_ssh_private_key_file` | Ruta a la clave privada. |
| `ansible_python_interpreter` | Ruta al Python del target (por ejemplo `/usr/bin/python3`). |
| `ansible_connection` | `ssh` (default), `local`, `docker`, `winrm`, ... |
| `ansible_become` / `ansible_become_method` | Escalación de privilegios (`sudo`, `su`, `doas`). |

Si Ansible te avisa "Discovered python interpreter...", **fija** `ansible_python_interpreter` para evitar sorpresas entre distros.

---

## 5. Inventory dinámico

Cuando la flota es efímera (autoscaling groups, instancias spot, pods, VMs creadas por Terraform), un fichero estático se vuelve obsoleto en minutos. La respuesta: **plugins de inventario dinámico**.

### 5.1 Plugins oficiales modernos

Hoy los plugins son YAML con una extensión especial (`*.aws_ec2.yml`, `*.gcp_compute.yml`, `*.azure_rm.yml`):

```yaml
# demo.aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
filters:
  tag:Env: prod
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.availability_zone
    prefix: az
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
```

Uso:

```bash
ansible-inventory -i demo.aws_ec2.yml --list
ansible -i demo.aws_ec2.yml role_web -m ping
```

Equivalentes para GCP (`google.cloud.gcp_compute`), Azure (`azure.azcollection.azure_rm`), Kubernetes (`kubernetes.core.k8s`), VMware, OpenStack, y hay plugins para fuentes genéricas (`constructed`, `generator`, `netbox`, `nmap`).

### 5.2 Scripts dinámicos (contrato legacy)

Antes de los plugins YAML, cualquier ejecutable que respetara el **contrato JSON** servía:

- Invocado con `--list` → debe imprimir un JSON con grupos, hosts y, opcionalmente, `_meta.hostvars`.
- Invocado con `--host <hostname>` → debe imprimir vars del host (o `{}` si están en `_meta`).

Formato mínimo:

```json
{
  "web": {
    "hosts": ["10.0.0.1", "10.0.0.2"],
    "vars": {"ansible_user": "ec2-user"}
  },
  "_meta": {
    "hostvars": {
      "10.0.0.1": {"role": "frontend"},
      "10.0.0.2": {"role": "frontend"}
    }
  }
}
```

Guardas el script, le das `chmod +x`, y lo pasas con `-i ./dynamic-inventory.py`. Sigue siendo útil para fuentes custom (una API interna, una CMDB rara).

### 5.3 Cuándo estático y cuándo dinámico

| Situación | Elige |
|-----------|-------|
| 3 VMs long-lived gestionadas a mano | Estático |
| Flota EC2 con autoscaling | Dinámico (plugin) |
| Mezcla legacy + cloud | Varios inventarios (`-i inv1 -i inv2`) |
| Experimentos locales | `localhost` + `ansible_connection=local` |
| CI que levanta runners efímeros | Dinámico (scripts) |

---

## 6. Comandos ad-hoc

Antes de escribir el primer playbook, familiarízate con los **ad-hoc**: una línea, un módulo, un grupo. Son el equivalente a `kubectl exec` o a `ssh host '...'` pero con la ventaja de Ansible (paralelo, output estructurado, módulos idempotentes).

Patrón: `ansible <patrón-de-hosts> -m <módulo> -a "<args>"`.

Ejemplos canónicos:

```bash
# ¿Están vivos?
ansible all -m ping

# Uptime en todos los hosts del grupo web
ansible web -m shell -a "uptime"

# Copiar un archivo (idempotente)
ansible web -m copy -a "src=./nginx.conf dest=/etc/nginx/nginx.conf owner=root mode=0644" --become

# Instalar un paquete
ansible web -m apt -a "name=htop state=present update_cache=yes" --become

# Reiniciar un servicio
ansible web -m systemd -a "name=nginx state=restarted" --become

# Ver facts de un host (JSON gigante)
ansible db-01 -m setup
```

Diferencia entre `shell` y `command`: `shell` interpreta pipes/redirecciones (`|`, `>`, `&&`); `command` no (más seguro, más predecible). Para idempotencia real, prefiere módulos específicos (`apt`, `copy`, `template`, `systemd`) sobre `shell` crudo.

---

## 7. Patrones de hosts

`all`, nombres literales (`web-01.example.com`), grupos (`web`), intersecciones (`web:&prod`), exclusiones (`web:!prod`), uniones (`web:db`), regex (`~^web-0[12]`), rangos (`web[01:03].example.com`).

---

## 8. Errores comunes del primer día

1. **`UNREACHABLE: Failed to connect to the host via ssh`**: casi siempre es `ansible_user` incorrecto o clave SSH no cargada en el agente. Prueba `ssh -i key user@host` manualmente antes de culpar a Ansible.
2. **`/usr/bin/python: not found`**: el target es Debian 12 slim o similar sin Python 2. Fija `ansible_python_interpreter=/usr/bin/python3` en group_vars.
3. **`[WARNING]: Platform ... is using the discovered Python interpreter at /usr/bin/python3.11`**: no es un error, pero fija el intérprete para evitar que un upgrade silencioso te cambie el comportamiento.
4. **`ping` dice OK pero `shell` falla**: casi siempre un sudoers mal configurado y `--become` fallando.
5. **Inventory YAML "no ve" los hosts**: olvidar los dos puntos tras `hostname:` (sintaxis YAML requiere `host.example.com:` incluso sin vars).
6. **Mezclar INI y YAML en el mismo directorio con nombres `hosts`**: Ansible toma uno u otro según la extensión; sé explícito con `-i`.

---

## 9. CM vs IaC vs Docker — una tabla

| Pregunta | Respuesta |
|----------|-----------|
| Necesito crear 10 VMs en AWS | Terraform |
| Necesito instalar nginx en 10 VMs ya creadas | Ansible |
| Necesito que mi app corra en Kubernetes | Dockerfile + Helm/GitOps, **no** Ansible |
| Necesito un parche de kernel en 200 VMs | Ansible (rolling con `serial`) |
| Necesito reemplazar la imagen base de mis Lambdas | ni uno ni otro: pipeline CI/CD |
| Necesito configurar switches Cisco | Ansible (collections de red) |
| Necesito arrancar un cluster k8s desde cero en bare metal | Ansible + kubeadm (o kubespray) |

---

## 10. Cierre y conexión con lo siguiente

Con este módulo deberías poder:

- Instalar Ansible y verificar `ansible-core` + collections.
- Escribir un inventory YAML/INI con grupos, children y vars.
- Correr comandos ad-hoc contra `localhost` y contra una pequeña flota (local, Docker o VMs reales).
- Describir el flujo push-agentless-SSH y por qué `ping` no es ICMP.
- Entender qué resuelve un plugin de inventario dinámico y cuándo justificarlo.

En `ans-02` saltamos de la línea de comandos a los **playbooks**, donde la idempotencia y los handlers se convierten en el día a día.
