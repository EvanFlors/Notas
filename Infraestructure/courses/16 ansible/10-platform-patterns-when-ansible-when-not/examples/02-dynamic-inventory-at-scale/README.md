# Ejemplo 02 — Inventory dinámico a escala

> Lectura y análisis. Sin ejecución. Objetivo: entender la anatomía de un `aws_ec2.yml` real, su caching, y cómo degrada cuando el fleet crece.

## 1. Un `aws_ec2.yml` comentado

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2

# 1. Regiones: siempre acotar explícitamente. Sin esto, el plugin itera por
#    TODAS las regiones habilitadas en la cuenta — latencia inútil.
regions:
  - eu-west-1
  - eu-central-1

# 2. Filtros server-side: la API filtra antes de devolver. Cualquier filtro
#    que puedas poner aquí ahorra tiempo frente a filtrar client-side con `compose`.
filters:
  tag:Environment: prod
  instance-state-name: running
  tag:ManagedBy: ansible   # convencion: solo lo que explicitamente marcamos

# 3. Grupos derivados de tags. `role_app`, `role_db`, etc. aparecen automaticamente.
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.availability_zone
    prefix: az
  - key: tags.Team
    prefix: team

# 4. Hostname: preferimos el tag Name; si no existe, caemos a la IP privada.
hostnames:
  - tag:Name
  - private-ip-address

# 5. ansible_host: siempre IP privada (asumimos acceso via bastion/VPN).
compose:
  ansible_host: private_ip_address
  ec2_instance_type: instance_type
  ec2_launch_time: launch_time

# 6. Cache: critico a escala. Sin cache, cada `--list` llama a la API.
cache: true
cache_plugin: ansible.builtin.jsonfile
cache_timeout: 300             # 5 minutos; subir si el fleet cambia poco
cache_connection: /var/tmp/ansible-ec2-cache
cache_prefix: aws_ec2_prod
```

Puntos clave:

- Los **filtros server-side** (`filters:`) usan la API de EC2 (`DescribeInstances` con `Filter`). Cuanto más estrictos, menos datos cruzan la red.
- Los **`keyed_groups`** se construyen client-side a partir de la respuesta. No cuestan API calls pero sí RAM si el fleet es enorme.
- El **cache** es la diferencia entre un run de 2 segundos y uno de 2 minutos. En CI con 50 jobs concurrentes, sin cache se come el rate limit de la cuenta.

## 2. Qué devuelve `ansible-inventory --list`

Fragmento recortado:

```json
{
  "_meta": {
    "hostvars": {
      "web-prod-01": {
        "ansible_host": "10.42.3.17",
        "ec2_instance_type": "m6i.large",
        "ec2_launch_time": "2026-09-30T04:12:11+00:00"
      },
      "web-prod-02": { "...": "..." }
    }
  },
  "all": { "children": ["aws_ec2", "role_app", "role_db", "az_eu_west_1a", "..."] },
  "aws_ec2": { "hosts": ["web-prod-01", "web-prod-02", "..."] },
  "role_app": { "hosts": ["web-prod-01", "web-prod-02"] },
  "role_db": { "hosts": ["db-prod-01"] },
  "az_eu_west_1a": { "hosts": ["web-prod-01", "db-prod-01"] }
}
```

Ejecución típica:

```bash
# Lista cruda.
ansible-inventory -i inventory/aws_ec2.yml --list

# Lista en forma de arbol legible.
ansible-inventory -i inventory/aws_ec2.yml --graph

# Comando ad-hoc solo contra el grupo derivado.
ansible -i inventory/aws_ec2.yml role_app -m ping
```

## 3. Dónde empieza a doler

### 3.1 Latencia

- 500 instancias: `--list` sin cache ≈ **1–3 s**.
- 5 000 instancias: ≈ **10–20 s**.
- 20 000 instancias con filtros amplios: **minutos**, y la API empieza a devolver `ThrottlingException`.

Mitigación: cache compartido (p. ej. `cache_connection` en un volumen montado desde los runners), filtros más estrictos, split por región.

### 3.2 Rate limits

- `DescribeInstances` tiene un *bucket* por cuenta/región. En CI con muchos pipelines concurrentes se agota.
- Síntoma: `botocore.exceptions.ClientError: ... RequestLimitExceeded`.
- Mitigación: cache, backoff, o publicar un **CMDB intermedio** (NetBox, Backstage) que la red interna consulta.

### 3.3 Hosts "fantasma"

Entre `--list` y la ejecución del task puede pasar que una instancia se termine (autoscaling, spot interrupt). El play falla con `UNREACHABLE`.

Mitigación en el play:

```yaml
- hosts: role_app
  gather_facts: false
  ignore_unreachable: true
  tasks:
    - ansible.builtin.wait_for_connection:
        timeout: 10
    - ansible.builtin.setup:
    - ...tareas reales...
```

### 3.4 Multi-cuenta / multi-cloud

Usar múltiples `aws_ec2.yml` apuntando a cuentas distintas (via `profile` o `assume_role_arn`) y un **constructed inventory** que los una:

```yaml
# inventory/constructed.yml
plugin: ansible.builtin.constructed
strict: false
compose:
  env: tags.Environment | default('unknown')
keyed_groups:
  - key: env
    prefix: env
```

Combinación: `-i inventory/aws_ec2_prod.yml -i inventory/aws_ec2_staging.yml -i inventory/constructed.yml`.

## 4. Cuándo el inventory dinámico ya no basta

Más allá de ~10 000 hosts con alta variabilidad, los síntomas se acumulan: cache stale, API throttle, lentitud en CI, hosts fantasma frecuentes. Opciones:

1. **CMDB central** (NetBox) como fuente única; Ansible consume via `netbox.netbox.nb_inventory`. Separa descubrimiento de ejecución.
2. **Partición por team/región**: cada equipo opera su slice; nadie corre un playbook contra "todo el fleet".
3. **Pasar a immutable**: si el fleet es tan grande, probablemente la configuración debería vivir en AMIs horneadas por Packer, no en runs de Ansible por SSH. Ansible queda solo para Day-2 ocasional.

## 5. Qué llevarse

> El inventory dinámico es una de las piezas más potentes de Ansible, pero su límite llega antes de lo que la gente cree. A partir de cierta escala, el patrón correcto es **CMDB intermedio** + **immutable para el fleet grande** + **Ansible para Day-2 selectivo**.
