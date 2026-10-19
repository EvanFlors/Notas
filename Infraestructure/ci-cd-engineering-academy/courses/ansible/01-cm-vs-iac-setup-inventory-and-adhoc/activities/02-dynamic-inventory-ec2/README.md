# Actividad 02 — Dynamic inventory EC2 (sin AWS real)

## 1. Identificación

- **ID:** `ans-01-02-dynamic-inventory-ec2`
- **Tecnología:** `ansible`
- **Módulo:** `ans-01-cm-vs-iac-setup-inventory-and-adhoc`
- **Dificultad:** intermediate
- **Duración estimada:** 65–85 min
- **Tipo:** independent

## 2. Contexto

Una vez el inventario estático empieza a quedarse corto (flotas efímeras, autoscaling, instancias que aparecen y desaparecen), hay que entender las dos vías modernas de **inventario dinámico**:

1. **Plugin oficial** (`amazon.aws.aws_ec2`, `google.cloud.gcp_compute`, …): un fichero YAML declarativo que el plugin interpreta.
2. **Script dinámico**: cualquier ejecutable que respete el contrato JSON `--list` / `--host`. Sigue siendo útil para fuentes custom (CMDB interna, API privada, mezcla rara).

Esta actividad pide que redactes **las dos cosas** aunque no tengas (ni necesites) una cuenta AWS activa. Lo que validamos es *la forma*: el YAML del plugin con las claves correctas, y el script con el JSON correcto. Si en Fase 4 te das con credenciales AWS reales, el YAML servirá tal cual; el script se refactoriza a plugin cuando toque.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Explicar por qué el fichero del plugin EC2 debe terminar en `.aws_ec2.yml`.
- Nombrar al menos 3 claves soportadas por el plugin (`plugin`, `regions`, `filters`, `keyed_groups`, `hostnames`, `compose`, `cache`).
- Describir el contrato JSON de un script dinámico (`--list` y `--host`).
- Argumentar cuándo prefieres plugin vs script vs estático.

## 4. Prerrequisitos

- `ans-01-01` completado.
- Haber leído `../../theory/lesson.md` §5.
- Haber revisado `examples/03-ec2-dynamic-inventory/`.
- Herramientas: `python3`, `bash`, (opcional) `ansible-core` para re-validar en vivo.

**Costos**: ninguno. No se contacta a AWS en ningún paso.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/ans-01-02
cd /tmp/ans-01-02
```

### 5.2 Redactar `prod.aws_ec2.yml`

Debe contener, como mínimo:

- `plugin: amazon.aws.aws_ec2`
- `regions:` con al menos una región `eu-*`.
- `filters:` con al menos un filtro (`instance-state-name: running` y/o `tag:Env: prod`).
- `keyed_groups:` con al menos un derivado (por tag o por atributo).
- `hostnames:` con al menos una entrada.

Nombre del fichero: **exactamente** `prod.aws_ec2.yml` (el validador lo busca así).

### 5.3 Escribir `dynamic-inventory.py`

Script Python ejecutable (`chmod +x`) que:

- Con `--list` imprime un JSON con **al menos dos grupos** (p. ej. `web`, `db`), cada grupo con `hosts: [...]` y, opcionalmente, `vars: {...}`.
- Con `--host <hostname>` imprime un JSON (puede ser `{}` si usas `_meta.hostvars`).
- Incluye el bloque `_meta.hostvars` con al menos una variable por host (p. ej. `ansible_host`).
- Imprime JSON válido en stdout; nada por stderr (salvo errores reales).

El script es un **mock**: puede devolver hosts inventados (`10.0.0.1`, `10.0.0.2`); no hace falta llamar a ningún API externo.

### 5.4 Redactar `NOTES.md`

Documento corto (unas 20–40 líneas) que compare las tres opciones (plugin, script, estático) y recomiende una para cada uno de estos tres escenarios:

1. **S1**: 3 VMs de staging creadas con Terraform y poco cambiantes.
2. **S2**: Autoscaling group en producción con instancias efímeras y tag `Env=prod`.
3. **S3**: Una lista de switches Cisco que llega por una API interna propietaria.

Secciones mínimas (el validador las busca):

- `## Escenario 1` (y `## Escenario 2`, `## Escenario 3`).
- Mención explícita de **"plugin"**, **"script"** y **"estático"** en el documento.

### 5.5 Entregables

Dentro de `/tmp/ans-01-02/`:

- `prod.aws_ec2.yml`
- `dynamic-inventory.py` (ejecutable, +x)
- `NOTES.md`

## 6. Resultado esperado

- El plugin YAML parsea como YAML válido y declara todas las claves obligatorias.
- El script, invocado como `./dynamic-inventory.py --list`, imprime JSON válido con `_meta.hostvars` y ≥ 2 grupos.
- Si `ansible-inventory` está instalado, el validador también comprueba que puede *consumir* el script sin errores de contrato.
- `NOTES.md` tiene los 3 escenarios y menciona las 3 estrategias.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: `NOTES.md` justifica cada recomendación (no sólo "yo elegiría plugin"), apoyándose en volatilidad de la flota y origen de los datos.
- **Reproducibilidad**: desde cero (sólo con los 3 ficheros) se puede ejecutar `./dynamic-inventory.py --list | python3 -m json.tool` y leer el JSON.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-01-02
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si tu `prod.aws_ec2.yml` no termina en `.aws_ec2.yml` (por ejemplo `prod.yml`)? ¿Cómo lo ejecutarías igualmente?
2. ¿Por qué el bloque `_meta.hostvars` existe? ¿Qué pasa si no lo pones y Ansible invoca `--host <nombre>` por cada host?
3. Si mañana AWS cambia un nombre de atributo (p. ej. `private-ip-address` → `private_ip`), ¿cuál de las dos opciones (plugin vs script) te protege mejor y por qué?
4. ¿Dónde pondrías las credenciales AWS en producción (no en el fichero)? Enumera al menos 3 opciones.
5. ¿Cómo verificas, antes de un `apply` grande, que el inventario dinámico está devolviendo lo que esperas?

## 10. Extensiones

- Añade `cache: true` + `cache_plugin: jsonfile` a `prod.aws_ec2.yml` y comenta su efecto.
- Convierte tu `dynamic-inventory.py` en un plugin de inventario modern-style (clase `InventoryModule`) — es un buen puente a `ansible-core`.
- Dibuja en `NOTES.md` el flujo de datos (TF outputs → tags EC2 → plugin → playbook) para S2.

## 11. Limpieza

```bash
rm -rf /tmp/ans-01-02
```
