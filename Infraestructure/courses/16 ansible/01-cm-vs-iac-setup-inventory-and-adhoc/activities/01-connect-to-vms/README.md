# Actividad 01 — Conectar a managed nodes locales

## 1. Identificación

- **ID:** `ans-01-01-connect-to-vms`
- **Tecnología:** `ansible`
- **Módulo:** `ans-01-cm-vs-iac-setup-inventory-and-adhoc`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** guided-lab

## 2. Contexto

Antes de escribir cualquier playbook, un operador tiene que demostrar algo mínimo: **"puedo hablar con mis hosts, los tengo agrupados y respondo a `ping`"**. Esta actividad te lleva por ese ritual con una flota 100 % local.

Dos modos de ejecución soportados:

- **Modo A — solo localhost** (sin Docker): un único host, `ansible_connection: local`. Suficiente para validar el flujo.
- **Modo B — localhost + 2 contenedores `ubuntu:22.04`** con `sshd`: más realista (SSH real, dos targets), pero requiere `docker` disponible.

El validador acepta **ambos** modos siempre que el inventory tenga al menos un host en el grupo `managed` y los ad-hoc hayan generado los artefactos esperados.

## 3. Objetivos

Al terminar deberías poder, **sin volver a la lección**:

- Explicar qué hace `ansible-inventory --list` y por qué su JSON incluye `_meta.hostvars`.
- Escribir un inventory YAML con `all → children → managed` y variables de conexión.
- Correr `ansible <grupo> -m ping` y `ansible <grupo> -m shell -a "uptime"`.
- Diferenciar `ansible_connection: local` de `ansible_connection: ssh`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (secciones 2, 4 y 6).
- Recorridos los ejemplos `01-first-ping-with-ssh` y `02-inventory-yaml-vs-ini`.
- Herramientas: `bash`, `python3`, `pipx` (recomendado), `ansible-core` ≥ 2.14.
- Opcional para Modo B: `docker` o `podman`.

Si `ansible` no está instalado:

```bash
pipx install --include-deps ansible
# o: pip install --user ansible
```

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-01-01
cd /tmp/ans-01-01
```

Si usas otra ruta, pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribir `inventory.yml`

El fichero debe:

- Vivir en `/tmp/ans-01-01/inventory.yml`.
- Declarar un grupo `managed` dentro de `all.children`.
- Incluir **al menos un host** en `managed` (Modo A: `localhost`; Modo B: `node-1`, `node-2`).
- Fijar `ansible_python_interpreter` para evitar warnings.

Ejemplo mínimo (Modo A):

```yaml
all:
  children:
    managed:
      hosts:
        localhost:
          ansible_connection: local
      vars:
        ansible_python_interpreter: /usr/bin/python3
```

Para Modo B, mira la plantilla sugerida en `starter/README.md`.

### 5.3 Verificar la estructura

```bash
ansible-inventory -i inventory.yml --list   > inventory-list.json
ansible-inventory -i inventory.yml --graph  > inventory-graph.txt
```

Los dos ficheros son **entregables**: el validador los busca y comprueba que mencionan el grupo `managed`.

### 5.4 Ad-hoc ping

```bash
ansible -i inventory.yml all -m ping | tee ping-output.txt
```

El validador exige que `ping-output.txt` contenga la cadena `pong` y que no haya `UNREACHABLE`.

### 5.5 Ad-hoc shell

```bash
ansible -i inventory.yml managed -m shell -a "uptime" | tee adhoc-output.txt
```

El validador exige que `adhoc-output.txt` contenga `load average` (output típico de `uptime`).

### 5.6 (Opcional) Modo B con Docker

Si tienes Docker y quieres practicar con SSH real, el starter trae un `docker-compose.yml` que levanta dos contenedores `ubuntu:22.04` con `openssh-server` y la clave pública del host autorizada:

```bash
cp -r <ruta-repo>/courses/ansible/01-cm-vs-iac-setup-inventory-and-adhoc/activities/01-connect-to-vms/starter/* /tmp/ans-01-01/
cd /tmp/ans-01-01
docker compose up -d
```

Y usas la plantilla de inventario Modo B del starter.

### 5.7 Entregables

Dentro de `/tmp/ans-01-01/`:

- `inventory.yml`
- `inventory-list.json`
- `inventory-graph.txt`
- `ping-output.txt`
- `adhoc-output.txt`

## 6. Resultado esperado

- Los 5 ficheros existen y el validador los acepta.
- Si Ansible no está instalado, el validador imprime `SKIP` razonado y sale con 0 (no es castigo por entorno; para avanzar sí deberás instalarlo).

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: `inventory.yml` tiene estructura `all → children → managed`, sin incrustar la clave privada en el fichero.
- **Reproducibilidad**: borrar `/tmp/ans-01-01` y rehacer todo con los comandos de este README reproduce el resultado.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-01-01
```

## 9. Preguntas de reflexión

1. ¿Qué cambia en el inventory si pasas de Modo A a Modo B? ¿Qué variables de conexión cobran sentido?
2. `ping` dio OK, pero `shell -a "uptime"` falla. Lista tres causas plausibles.
3. ¿Por qué `ansible-inventory --list` incluye `_meta.hostvars` y no sólo los grupos?
4. En Modo B, si matas uno de los dos contenedores entre el `ping` y el `shell`, ¿qué pasa? ¿Cómo lo reportaría Ansible?
5. Para una flota real de 50 hosts, ¿qué dejarías en el inventory y qué moverías a `group_vars/`?

## 10. Extensiones

- Añade un segundo grupo (`web`) con un host y usa el patrón `managed:!web` para excluirlo en un ad-hoc.
- Añade `group_vars/managed.yml` con `ansible_user: ubuntu` y verifica que `ansible-inventory --list` lo refleja.
- Mide la diferencia de tiempo entre `--forks 1` y `--forks 10` con `time ansible all -m ping`.

## 11. Limpieza

```bash
# Modo B:
docker compose -f /tmp/ans-01-01/docker-compose.yml down -v 2>/dev/null || true

rm -rf /tmp/ans-01-01
```
