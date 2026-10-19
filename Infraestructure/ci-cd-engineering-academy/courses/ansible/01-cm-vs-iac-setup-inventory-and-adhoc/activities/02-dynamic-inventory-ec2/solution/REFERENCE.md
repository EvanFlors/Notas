# REFERENCE — ans-01-02-dynamic-inventory-ec2

> Referencia razonada; cualquier variante que cumpla el contrato es válida.

## 1. `prod.aws_ec2.yml`

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
  - eu-central-1
filters:
  instance-state-name: running
  tag:Env: prod
  tag:ManagedBy: ansible
hostnames:
  - tag:Name
  - private-ip-address
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.availability_zone
    prefix: az
  - key: instance_type
    prefix: type
compose:
  ansible_host: private_ip_address
cache: true
cache_plugin: jsonfile
cache_timeout: 300
```

Decisiones:

- Dos regiones europeas (compliance GDPR).
- Filtros por `Env=prod` y `ManagedBy=ansible` para evitar incluir instancias "huérfanas".
- `hostnames` con fallback: `tag:Name` si existe, si no la IP privada (nunca pública).
- `keyed_groups` genera agrupaciones automáticas por `Role`, `AZ`, tipo.
- `cache` activo para evitar martillar DescribeInstances en runs encadenados.

## 2. `dynamic-inventory.py`

Ver `./dynamic-inventory.py`. Puntos finos:

- Shebang `#!/usr/bin/env python3`.
- Imprime SIEMPRE JSON válido en stdout; nada por stderr salvo errores.
- `_meta.hostvars` evita la llamada `--host` por host (optimización clásica).
- Soporta `--list` y `--host` como marca el contrato.

## 3. Recomendación por escenario (contenido de `NOTES.md`)

| Escenario | Elegir | Por qué |
|-----------|--------|---------|
| **S1** — 3 VMs staging Terraform, poco cambiantes | **Estático** (`hosts.yml` versionado en el repo, con las IPs/DNS que outputea TF). | Baja volatilidad; estático = diff claro en PR, lectura trivial. Un dinámico aquí es sobre-ingeniería. |
| **S2** — ASG prod con instancias efímeras y tag `Env=prod` | **Plugin oficial** `amazon.aws.aws_ec2`. | Fuente de verdad = AWS; filtrar por tag; `keyed_groups` para agrupar por rol/AZ sin mantenerlo a mano. |
| **S3** — Switches Cisco por API interna propietaria | **Script dinámico** (o plugin custom moderno). | No hay plugin oficial; el script traduce la API privada al contrato Ansible; es el escape previsto por el framework. |

## 4. Trampas evitables

- Olvidar `chmod +x` al script → Ansible dice "permission denied" y confunde con un bug en el código.
- Mezclar prints de debug con el JSON → el parser rompe. Debug a stderr o a un fichero, nunca a stdout.
- Nombrar el fichero `prod.yaml` en vez de `prod.aws_ec2.yml` → el plugin **no** se activa automáticamente; tendrías que forzarlo con `-i prod.yaml` y `[inventory] enable_plugins = aws_ec2` en `ansible.cfg`.
- Credenciales AWS incrustadas en el YAML → **nunca**. Usa SSO / instance profile / variables de entorno / `AWS_PROFILE`.
