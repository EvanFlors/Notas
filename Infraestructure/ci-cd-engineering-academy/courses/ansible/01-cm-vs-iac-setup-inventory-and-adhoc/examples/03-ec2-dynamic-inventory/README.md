# Ejemplo 03 — EC2 Dynamic Inventory

> Lectura. Objetivo: entender la **forma** de un `aws_ec2.yml` del plugin oficial `amazon.aws.aws_ec2`. No se ejecuta — no hace falta cuenta AWS.

## 1. El plugin

`amazon.aws.aws_ec2` es el reemplazo moderno del viejo script `ec2.py`. Es parte de la collection `amazon.aws` (se instala con `ansible-galaxy collection install amazon.aws`). Lee EC2 con las credenciales de tu entorno (perfil AWS, `AWS_PROFILE`, variables `AWS_ACCESS_KEY_ID`, etc.) y produce un inventario en memoria.

## 2. Fichero anotado

```yaml
# prod.aws_ec2.yml
#
# Nombre del fichero: DEBE terminar en .aws_ec2.yml para que Ansible active
# el plugin automáticamente al pasarle -i prod.aws_ec2.yml.

plugin: amazon.aws.aws_ec2            # obliga a usar este plugin

# Regiones a consultar (una llamada DescribeInstances por región).
regions:
  - eu-west-1
  - eu-central-1

# Filtros DEL LADO AWS (los aplica el API; menos tráfico que filtrar luego).
filters:
  instance-state-name: running
  tag:Env: prod
  tag:ManagedBy: ansible

# Qué atributo usar como "nombre" del host en Ansible.
hostnames:
  - tag:Name               # 1) usa el tag Name si existe
  - private-ip-address     # 2) fallback a la IP privada

# Grupos derivados automáticamente de tags/atributos.
keyed_groups:
  - key: tags.Role         # Role=web -> grupo "role_web"
    prefix: role
  - key: placement.availability_zone
    prefix: az             # az_eu-west-1a, az_eu-west-1b
  - key: instance_type
    prefix: type

# Variables inyectadas en cada host (compute en el momento del inventario).
compose:
  ansible_host: private_ip_address
  ansible_user: '"ec2-user"'    # literal: comillas dentro de comillas
```

## 3. Cómo se usa

```bash
# Instalar la collection:
ansible-galaxy collection install amazon.aws

# Credenciales AWS en el entorno:
export AWS_PROFILE=my-prod

# Listar lo que ve el plugin:
ansible-inventory -i prod.aws_ec2.yml --list

# Correr ad-hoc contra todos los web prod:
ansible -i prod.aws_ec2.yml role_web -m ping
```

## 4. Puntos finos

- **Ni passwords ni keys en el fichero**: la autenticación va por el chain de credenciales de AWS (SSO/profile/env/instance-profile).
- **Nombres de grupo**: Ansible convierte caracteres inválidos (`-`, `.`) en `_`. Un `tag:App=my-app` genera grupo `app_my_app`.
- **Caching**: puedes activar cache de inventario con `cache: true` + `cache_plugin: jsonfile` para evitar martillar la API en loops.
- **Múltiples inventarios**: puedes combinar `-i prod.aws_ec2.yml -i staging.aws_ec2.yml`; Ansible fusiona los grupos.
- **No hay magic**: si tu instancia no tiene el tag correcto, no aparece. Debuguea con `ansible-inventory ... --graph` y con `--list` para ver qué devolvió AWS.

## 5. Alternativas

- `azure.azcollection.azure_rm` — mismo patrón para Azure.
- `google.cloud.gcp_compute` — mismo patrón para GCP.
- `kubernetes.core.k8s` — nodos y pods como inventario.
- **Script dinámico** (contrato JSON `--list` / `--host`) — para fuentes custom (CMDB interna, API privada). Lo verás en la actividad 02.
