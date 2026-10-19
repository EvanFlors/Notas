# Ejemplo 02 — Inventory YAML vs INI

> Mismo inventario expresado en los dos formatos nativos. Lee los dos, elige el que te resulte más legible — pero conoce ambos porque te los vas a encontrar en código ajeno.

## 1. Escenario

Una flota pequeña: dos webs, una base de datos, un entorno `prod` que agrupa a los tres y aplica variables comunes.

## 2. Versión YAML

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
          ansible_port: 2222
      vars:
        ansible_user: dba
    prod:
      children:
        web:
        db:
      vars:
        env: production
        ansible_python_interpreter: /usr/bin/python3
```

Lo que entrega:

- Grupo `web` con 2 hosts.
- Grupo `db` con 1 host; `db-01` sobreescribe `ansible_port` a 2222; todo `db` usa `ansible_user: dba`.
- Grupo `prod` por `children`: contiene `web` y `db`; define `env=production` y fija el intérprete Python.

## 3. Versión INI equivalente

```ini
# hosts.ini
[web]
web-01.example.com
web-02.example.com

[db]
db-01.example.com ansible_port=2222

[db:vars]
ansible_user=dba

[prod:children]
web
db

[prod:vars]
env=production
ansible_python_interpreter=/usr/bin/python3
```

## 4. Comprobar la equivalencia

```bash
ansible-inventory -i hosts.yml  --graph
ansible-inventory -i hosts.ini --graph
# Las dos salidas deben ser idénticas (modulo el orden alfabético de los hosts).
```

Y el `--list`:

```bash
ansible-inventory -i hosts.yml --list | jq '.prod'
```

## 5. Cuándo cada uno

| Prefiero YAML si... | Prefiero INI si... |
|---------------------|---------------------|
| Tengo nested groups anidados profundo | Flota minúscula (<10 hosts, 2–3 grupos) |
| Necesito vars anidadas (listas, mapas) | Quiero cero sintaxis que recordar |
| Edito con un IDE que valida YAML | Prefiero copiar/pegar rápido |
| Mi equipo ya usa YAML en todo (K8s, playbooks) | Legacy repo que arrancó así |

**En este curso usaremos YAML por defecto**. Es consistente con los playbooks y evita el salto mental entre dos sintaxis.

## 6. Trampa habitual

Si en YAML escribes:

```yaml
all:
  hosts:
    web-01.example.com   # <-- FALTA el ':' final
```

Ansible te lo cargará como *null*, o peor, lo ignorará silenciosamente. **Siempre** termina con `:` incluso sin vars.
