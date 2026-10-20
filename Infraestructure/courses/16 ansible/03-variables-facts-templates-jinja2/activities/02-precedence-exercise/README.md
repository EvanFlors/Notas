# Actividad 02 — Precedence de variables en 4 niveles

## 1. Identificación

- **ID:** `ans-03-02-precedence-exercise`
- **Tecnología:** `ansible`
- **Módulo:** `ans-03-variables-facts-templates-jinja2`
- **Dificultad:** beginner
- **Duración estimada:** 60–75 min
- **Tipo:** independent

## 2. Contexto

Vas a montar un pequeño inventario con **3 hosts** (todos apuntando a localhost para no requerir infraestructura), **2 grupos**, y definirás la misma variable (`app_port`) en **4 niveles**:

1. `group_vars/all.yml` → `app_port: 8000`
2. `group_vars/web.yml` → `app_port: 8080`
3. `host_vars/web2.yml` → `app_port: 9090`
4. `vars:` en el playbook → `app_port: 7000`

Antes de ejecutar, **predices** qué valor gana para cada host. Después corres el playbook y una plantilla Jinja2 genera `precedence-report.txt` con el valor final por host. Comparas tu predicción con el resultado. Finalmente repites con `-e app_port=9999` y confirmas que extra vars gana a todo.

## 3. Objetivos

Al terminar deberías:

- Saber que `vars:` en la play (nivel 11) gana a `host_vars/` del inventory (nivel 8) y a `group_vars/` (niveles 6-7).
- Saber que `extra vars` (nivel 21) gana a todos los anteriores.
- Haber visto en la práctica cuál es el "nivel" ganador en cada host.

## 4. Prerrequisitos

- `ans-02` completado.
- `ansible-core` instalado (ver nota en la actividad 01).
- Herramientas: `bash`, `grep`, `ansible-playbook`.

> **Si no tienes Ansible instalado**, el validador reporta `SKIP` (exit 0). Instálalo para completar realmente el ejercicio.

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/ans-03-prec/{group_vars,host_vars,templates}
cd /tmp/ans-03-prec
```

### 5.2 Archivos a crear (nombres exactos)

```
/tmp/ans-03-prec/
├── inventory.yml
├── playbook.yml
├── group_vars/
│   ├── all.yml
│   └── web.yml
├── host_vars/
│   └── web2.yml
└── templates/
    └── precedence-report.txt.j2
```

#### `inventory.yml`

Define tres hosts (`web1`, `web2`, `db1`), dos grupos (`web` y `db`). Todos con `ansible_connection=local` y `ansible_host: 127.0.0.1`. (Ver `../../examples/02-group-vars-and-overrides/inventory.yml` como guía.)

#### `group_vars/all.yml`

```yaml
---
app_port: 8000
```

#### `group_vars/web.yml`

```yaml
---
app_port: 8080
```

#### `host_vars/web2.yml`

```yaml
---
app_port: 9090
```

#### `playbook.yml`

Debe:

- Correr contra `hosts: all`.
- Tener `gather_facts: false`.
- Declarar `vars:` con `app_port: 7000` (este bloque es parte del ejercicio).
- Usar `ansible.builtin.template` para renderizar `templates/precedence-report.txt.j2` en `/tmp/ans-03-prec/output/precedence-report.txt`.

> La task debe usar `run_once: true` **y** `delegate_to: localhost` para que el template se genere **una sola vez** con la lista completa de hosts. Si lo renderizas por cada host, obtendrás 3 archivos sobrescribiéndose. (Pista: dentro del template puedes iterar `groups['all']` y leer `hostvars[h].app_port` para cada host.)

#### `templates/precedence-report.txt.j2`

Debe producir, para cada host, una línea con **exactamente** este formato (el validador la busca):

```
<host>: app_port=<valor>
```

Un ejemplo del contenido final renderizado (sin `-e`):

```
web1: app_port=7000
web2: app_port=7000
db1: app_port=7000
```

Espera — ¿por qué el mismo valor para los tres si `web2` tiene override en `host_vars/`? Porque `vars:` en la play **gana** a `host_vars/` del inventory. Ese es el *gotcha* del ejercicio.

Si luego ejecutas con `-e app_port=9999`:

```
web1: app_port=9999
web2: app_port=9999
db1: app_port=9999
```

### 5.3 Ejecutar

```bash
cd /tmp/ans-03-prec
ansible-playbook -i inventory.yml playbook.yml
cat output/precedence-report.txt
```

### 5.4 Predicción (hazla antes de ejecutar)

En un archivo `/tmp/ans-03-prec/PREDICTION.md` escribe qué esperas ver y por qué, para los dos casos (con y sin `-e app_port=9999`). Compara con el output real. Esto no lo valida el script, pero es la parte formativa del ejercicio.

### 5.5 Entregables

```
/tmp/ans-03-prec/
├── inventory.yml
├── playbook.yml
├── group_vars/all.yml
├── group_vars/web.yml
├── host_vars/web2.yml
├── templates/precedence-report.txt.j2
└── output/precedence-report.txt
```

## 6. Resultado esperado

El validador comprueba:

- Existen los archivos requeridos.
- `output/precedence-report.txt` existe tras correr el playbook.
- Contiene **3 líneas** con el formato `<host>: app_port=<valor>`.
- Los **3 valores son iguales** (demostración de que `vars:` de la play aplana `group_vars`/`host_vars`).
- Hay una segunda ejecución con `-e app_port=9999` que produce exactamente `9999` para los 3 hosts.

## 7. Criterios de aceptación

- Validador en verde (o `SKIP` claro si no hay Ansible).
- `host_vars/web2.yml` existe con `app_port: 9090` (aunque ese valor no gane).
- Entiendes **por qué** no gana (`vars:` de la play > `host_vars/` del inventory).

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-03-prec
```

## 9. Preguntas de reflexión

1. Si quitas el bloque `vars:` del playbook, ¿qué valores ganan para `web1`, `web2`, `db1`? Pruébalo.
2. Si pones `app_port: 1111` en `vars/main.yml` de un role (y usas el role en la play), ¿gana a `-e`? ¿Por qué?
3. Si defines `app_port` en `group_vars/all.yml` **y** en `group_vars/web.yml`, ¿cuál gana para un host del grupo `web`?
4. ¿Qué ventaja tiene usar `host_vars/` en lugar de `vars:` en la play para configurar un host "especial"?
5. ¿Por qué `extra vars` es "lo más alto que puedes empujar" y por qué eso lo hace peligroso como mecanismo de configuración habitual?

## 10. Extensiones

- Añade un segundo nivel más: `include_vars` dentro de una task. Comprueba que gana a `vars:` de la play.
- Añade un `set_fact: app_port: 6000` como primera task y mira qué pasa.
- Define `app_port` también en `inventory.yml` inline (en el host): `web1: { app_port: 1234 }`. ¿Cómo cambia la jerarquía?

## 11. Limpieza

```bash
rm -rf /tmp/ans-03-prec
```
