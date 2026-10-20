# Actividad 01 — Convertir un playbook en idempotente

## 1. Identificación

- **ID:** `ans-07-01-make-playbook-idempotent`
- **Tecnología:** `ansible`
- **Módulo:** `ans-07-idempotency-deep-and-advanced-patterns`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** guided-lab (independent — sin dependencia de la actividad 02)

## 2. Contexto

Heredas un playbook "ganado a pulso" que un developer escribió como *bash disfrazado de YAML*. Converge **la primera vez**, pero cada corrida siguiente reporta `changed=changed=changed`, el equipo ya no sabe cuándo hubo cambio real y cuándo es ruido, y el `--check` de la pipeline está roto porque las tasks `shell:` se saltan en silencio.

Tu encargo: reescribir ese playbook para que:

1. La **segunda corrida** reporte `changed=0` en el recap (idempotencia real).
2. Las tasks read-only no mientan sobre `changed`.
3. Las queries que necesitas en check mode se marquen con `check_mode: false`.
4. La parte "riesgosa" del playbook (migración + reinicio) vaya envuelta en `block/rescue/always` con rollback y limpieza del flag de mantenimiento.
5. Las tareas se puedan correr con `--check --diff` sin que el playbook explote.

Todo corre contra `localhost`. No necesitas infraestructura.

## 3. Objetivos

Al terminar deberías poder, sin consultar la lección:

- Explicar por qué `shell:` siempre reporta `changed` y qué tres palancas (`creates:`, `changed_when:`, `failed_when:`) lo arreglan.
- Decidir cuándo poner `changed_when: false` y cuándo poner `check_mode: false`.
- Escribir un `block/rescue/always` donde `rescue:` hace rollback y `always:` limpia estado compartido.

## 4. Prerrequisitos

- Lección `../../theory/lesson.md` (§2–§5).
- `ansible-core` instalado: `pipx install ansible` (recomendado) o `pip install --user ansible-core`.
- `bash`, `grep`, `python3` en PATH.

**Costos:** 0 (todo en `localhost`).

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/ans-07-01
cd /tmp/ans-07-01
cp <ruta-repo>/courses/ansible/07-idempotency-deep-and-advanced-patterns/activities/01-make-playbook-idempotent/starter/site.yml site.yml
```

Puedes usar otro directorio; páselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Lee `site.yml` del starter y detecta los problemas

El starter contiene un playbook con **5 tasks sintomáticas**:

1. `Fetch marker` — `shell:` que crea un archivo, pero sin `creates:` → corre siempre.
2. `Query hostname` — `command:` sin `changed_when:` → reporta `changed=true` por nada.
3. `Check if deploy ran` — `command:` cuya salida puede ser `rc=1` esperado, pero no tiene `failed_when:`.
4. `Risky migration` — un comando que podría fallar, sin red (sin `block/rescue`).
5. `Restart service` — un `systemd:` que sí es idempotente, pero no hay flag de mantenimiento alrededor.

### 5.3 Reescribe `site.yml`

Produce un `site.yml` que cumpla **todos** los puntos siguientes (el validador los exige, salvo donde se marca "opcional"):

- Usa `creates:` **o** una condición `when:` basada en un `stat` registrado para evitar reejecutar la task #1.
- Marca al menos **una** task con `changed_when: false` (típicamente las read-only).
- Marca al menos **una** task con `failed_when:` explícito.
- Marca al menos **una** task con `check_mode: false` (para que corra en `--check`).
- Envuelve la "risky migration" y el restart en un `block:` con:
  - Un `rescue:` que haga rollback (puede ser crear un flag `/tmp/ans-07-01.rollback`).
  - Un `always:` que elimine el flag de mantenimiento (`/tmp/ans-07-01.maintenance`).
- La segunda corrida con `ansible-playbook site.yml` debe reportar `changed=0` en el recap.

### 5.4 Verifica a mano

```bash
# Primera corrida: cambios esperados.
ansible-playbook site.yml

# Segunda corrida: idealmente changed=0.
ansible-playbook site.yml

# Dry-run con diff: no debe explotar.
ansible-playbook site.yml --check --diff
```

### 5.5 Entregable

Un archivo `/tmp/ans-07-01/site.yml` idempotente con todos los constructos listados.

## 6. Resultado esperado

- `site.yml` existe, es YAML válido y corre sin error en `localhost`.
- Segunda corrida: recap con `changed=0`.
- `--check --diff` termina en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Idempotencia**: segunda corrida con 0 cambios.
- **Calidad**: cada palanca (`creates`, `changed_when`, `failed_when`, `check_mode`, `block/rescue/always`) se usa donde tiene sentido, no solo "para pasar el test".
- **Mantenibilidad**: nombres de task claros, YAML válido, sin comandos duplicados.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-07-01
```

El validador:

1. Comprueba que `site.yml` existe y es YAML parseable.
2. Verifica presencia de `creates:`, `changed_when:`, `failed_when:`, `check_mode:`, `block:`, `rescue:`, `always:`.
3. Ejecuta el playbook **dos veces** y comprueba que la segunda ejecución reporta `changed=0`.
4. Ejecuta `--check --diff` para asegurar que no explota.

## 9. Preguntas de reflexión

1. ¿Por qué `changed_when: false` no es lo mismo que `check_mode: false`? ¿Cuándo usarías cada uno?
2. Si tu `rescue:` también falla, ¿se ejecuta `always:`? ¿Y en qué estado queda el host en el recap?
3. ¿Qué pasa si el "riesgoso" es un `shell:` y lo corres con `--check`? ¿Entra en `rescue:`?
4. ¿Podrías escribir el playbook sin un solo `shell:` o `command:`? ¿Qué módulos nativos lo evitarían?

## 10. Extensiones

- Añade un `handler` que reinicie el servicio solo si cambió la config, y comprueba que la segunda corrida ni siquiera notifica el handler.
- Añade un `tags:` por task y verifica que `--tags migrate` ejecuta solo el bloque arriesgado.
- Convierte el playbook en un **role** y mueve el flag de mantenimiento a `defaults/`.

## 11. Limpieza

```bash
rm -rf /tmp/ans-07-01 /tmp/ans-07-01.*
```
