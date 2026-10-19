# Actividad 02 — Rolling restart con `serial`, `delegate_to` y `run_once`

## 1. Identificación

- **ID:** `ans-07-02-rolling-restart-with-serial`
- **Tecnología:** `ansible`
- **Módulo:** `ans-07-idempotency-deep-and-advanced-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** scenario (independent — sin dependencia de la actividad 01)

## 2. Contexto

Diriges la plataforma. Tienes **3 instancias** `web-a`, `web-b`, `web-c` detrás de un balanceador `lb-primary`. Un ingeniero propone un deploy "clásico Ansible": `ansible-playbook deploy.yml -i inventory` sin más — reiniciando los 3 en paralelo. **No.** Si el nuevo build está roto, caen las tres a la vez.

Tu encargo: diseñar un **rolling restart** que:

1. Procese los hosts **uno a uno** (`serial: 1`).
2. **Avise al balanceador** que un host va a quedar fuera **antes** de reiniciarlo (una llamada por host, delegada al `lb-primary`).
3. **Reinicie** el servicio en el host actual.
4. **Verifique salud** tras el restart. Si falla, aborta el play (no toca `web-b` ni `web-c`).
5. **Reponga** el host en el pool del LB.
6. **Notifique una sola vez** al terminar todo el play (`run_once: true` + `delegate_to: lb-primary`).
7. Toda la secuencia por host va en `block/rescue/always`: `rescue:` marca el host como "deploy failed"; `always:` registra en un log que el host se procesó.

Todo corre en `localhost` — los "hosts" del inventario usan `ansible_connection=local`. Esto te permite ver `serial` en acción sin montar red.

## 3. Objetivos

Al terminar deberías poder:

- Elegir valores razonables de `serial` y `max_fail_percentage` para un workload dado.
- Explicar por qué `delegate_to` + `run_once` es la combinación clásica para "efectos globales".
- Garantizar que un fallo en el host #1 **detiene** el play antes de tocar el #2.

## 4. Prerrequisitos

- Lección `../../theory/lesson.md` (§6–§8).
- `ansible-core` instalado.
- `bash`, `grep`, `python3`.

**Costos**: 0.

## 5. Instrucciones

### 5.1 Preparar

```bash
mkdir -p /tmp/ans-07-02
cp <ruta-repo>/courses/ansible/07-idempotency-deep-and-advanced-patterns/activities/02-rolling-restart-with-serial/starter/* /tmp/ans-07-02/
cd /tmp/ans-07-02
```

El starter trae:

- `inventory.ini` con 4 hosts locales (`web-a`, `web-b`, `web-c`, `lb-primary`).
- `rolling.yml` con la **estructura** del play pero con huecos marcados `# TODO`.

### 5.2 Reescribe `rolling.yml`

Debe cumplir (el validador lo exige):

- Nivel de play (keys obligatorias):
  - `hosts: web`
  - `serial: 1`
  - `max_fail_percentage: 0`
- Dentro de `tasks:`:
  - Una task que **notifique al LB** `lb-primary` para **drain** el host actual, con `delegate_to: lb-primary`.
  - Un `block:` que envuelva: restart (simulado con `debug:` o `command: true`), health check (otro `debug:`/`command: true`), undrain (delegado al LB).
  - Un `rescue:` que registre el host como fallido (puede ser `copy:` o `lineinfile:` escribiendo a `/tmp/ans-07-02.failed.log`).
  - Un `always:` que appendée el host procesado a `/tmp/ans-07-02.processed.log`.
  - Una task final con `run_once: true` y `delegate_to: lb-primary` que escriba `/tmp/ans-07-02.done` (notificación global de deploy terminado).

### 5.3 Correr

```bash
ansible-playbook -i inventory.ini rolling.yml
```

Observa:

- Las tasks se agrupan **por host**: `web-a` entero, luego `web-b` entero, luego `web-c`.
- La task final aparece **una sola vez**, en `lb-primary`.
- `/tmp/ans-07-02.processed.log` contiene los 3 hostnames en orden.
- `/tmp/ans-07-02.done` existe.

### 5.4 Entregable

- `/tmp/ans-07-02/inventory.ini`
- `/tmp/ans-07-02/rolling.yml`

## 6. Resultado esperado

- Play termina sin error.
- 3 hosts procesados en orden `web-a`, `web-b`, `web-c`.
- Flag global de "deploy terminado" creado una sola vez por `lb-primary`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Correctitud operacional**: `serial: 1` + `max_fail_percentage: 0`; health check real por host.
- **Diseño**: `delegate_to` y `run_once` en los sitios correctos.
- **Mantenibilidad**: nombres de task claros; `block/rescue/always` legibles.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-07-02
```

El validador:

1. Comprueba que `rolling.yml` existe, es YAML y contiene `serial`, `max_fail_percentage`, `delegate_to`, `run_once`, `block`, `rescue`, `always`.
2. Comprueba `inventory.ini` con grupo `[web]` y host `lb-primary`.
3. Ejecuta el playbook y verifica que los 3 hosts aparecen en el log de "procesados" **en orden**.
4. Verifica que `/tmp/ans-07-02.done` existe (se creó una sola vez).

## 9. Preguntas de reflexión

1. ¿Qué pasa si cambias `serial: 1` → `serial: "100%"`? ¿Sigue siendo rolling?
2. Si pones `max_fail_percentage: 50`, ¿puede quedar media flota rota antes de abortar?
3. ¿Por qué el `run_once` tiene que ir **fuera** del `block:` del host (y por qué va al final)?
4. En producción real, el "health check" sería un `uri:` con `retries` y `delay`. ¿Qué pasa si el servicio tarda 30 s en estar listo y tú esperas 1 s?

## 10. Extensiones

- Cambia `serial: 1` por `serial: [1, 2]` (canario de 1, luego 2 a la vez). Observa cómo cambia el recap.
- Añade una variable `drain_wait: 5` y usa `wait_for:` o `pause:` para esperar que el drain surta efecto.
- Convierte las notificaciones al LB en un **role** `lb-coordinator` reutilizable.

## 11. Limpieza

```bash
rm -rf /tmp/ans-07-02 /tmp/ans-07-02.*
```
