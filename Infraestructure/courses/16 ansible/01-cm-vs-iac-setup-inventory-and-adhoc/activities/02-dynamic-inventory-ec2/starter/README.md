# Starter — ans-01-02-dynamic-inventory-ec2

Esta actividad es **independiente**: no hay código que ejecutar aquí. Tu entregable son 3 ficheros.

## Pasos

1. Lee `../README.md` completo y revisa `examples/03-ec2-dynamic-inventory/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/ans-01-02
   cd /tmp/ans-01-02
   ```
3. Redacta `prod.aws_ec2.yml` (ver sección 5.2 del README).
4. Redacta `dynamic-inventory.py` (ver 5.3) y hazlo ejecutable:
   ```bash
   chmod +x dynamic-inventory.py
   ```
   Verifica manualmente:
   ```bash
   ./dynamic-inventory.py --list | python3 -m json.tool
   ./dynamic-inventory.py --host 10.0.0.1
   ```
5. Redacta `NOTES.md` con los 3 escenarios (ver 5.4).
6. Valida:
   ```bash
   bash <ruta-repo>/courses/ansible/01-cm-vs-iac-setup-inventory-and-adhoc/activities/02-dynamic-inventory-ec2/tests/validate.sh /tmp/ans-01-02
   ```

## Plantilla sugerida — `prod.aws_ec2.yml`

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - eu-west-1
filters:
  instance-state-name: running
  tag:Env: prod
hostnames:
  - tag:Name
  - private-ip-address
keyed_groups:
  - key: tags.Role
    prefix: role
compose:
  ansible_host: private_ip_address
```

## Plantilla sugerida — `dynamic-inventory.py`

Esqueleto; completa el `inventory` con tus hosts "inventados":

```python
#!/usr/bin/env python3
import json, sys

inventory = {
    "web": {"hosts": ["10.0.0.1", "10.0.0.2"], "vars": {"env": "prod"}},
    "db":  {"hosts": ["10.0.0.10"]},
    "_meta": {
        "hostvars": {
            "10.0.0.1":  {"ansible_host": "10.0.0.1"},
            "10.0.0.2":  {"ansible_host": "10.0.0.2"},
            "10.0.0.10": {"ansible_host": "10.0.0.10"},
        }
    },
}

if "--list" in sys.argv:
    print(json.dumps(inventory))
elif "--host" in sys.argv:
    print("{}")
else:
    sys.exit("usage: --list | --host <name>")
```

## Limpieza

```bash
rm -rf /tmp/ans-01-02
```
