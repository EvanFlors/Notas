# Actividad 02 — Fix: convertir un playbook no idempotente

## 1. Identificación

- **ID:** `ans-02-02-fix-non-idempotent-task`
- **Tecnología:** `ansible`
- **Módulo:** `ans-02-playbooks-plays-tasks-modules-handlers`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** debug

## 2. Contexto

Un compañero escribió el playbook `starter/playbook.yml` para "preparar un host" (crear un usuario, asegurar un directorio, añadir una línea a `/etc/environment`, descargar un binario y marcar un timestamp). **Funciona** la primera vez, pero cada ejecución posterior reporta `changed=5` incluso cuando el host ya está en el estado deseado. Esto rompe la propiedad fundamental de Ansible y hace que los handlers reaccionen de más (reinicios innecesarios en producción).

Tu misión: dejarlo idempotente. Después de tu fix, la **segunda ejecución** debe reportar `changed=0`.

## 3. Objetivos

Al terminar deberías poder:

- Identificar al menos 4 patrones de no-idempotencia en el playbook roto.
- Elegir entre: (a) reemplazar por módulo nativo, (b) acotar con `creates:`/`removes:`, (c) usar `changed_when:` cuando aplica.
- Argumentar por qué `changed_when: false` nunca sustituye a un verdadero chequeo de estado.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§3 y §4).
- Herramientas: `bash`, `ansible-core` (opcional para el test dinámico). `python3` suele venir con el sistema.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Copia el starter

```bash
cp -r starter/ /tmp/ans-02-02/
cd /tmp/ans-02-02/
```

### 5.2 Diagnostica

Ejecuta el playbook roto dos veces y observa que `changed` no baja:

```bash
ansible-playbook -i inventory.ini playbook.yml
ansible-playbook -i inventory.ini playbook.yml
# Esperas ok=N changed=0; obtienes ok=N changed=5 (o parecido).
```

Si no tienes Ansible instalado puedes razonar leyendo el playbook — cada task tiene un comentario `# PROBLEMA: ...` que te orienta.

### 5.3 Repara

Reglas:

1. **No** reemplaces tareas por `changed_when: false` cuando exista un módulo nativo idóneo.
2. **Prohibido** `ignore_errors: true` como solución.
3. Para la task que descarga el binario: usar `get_url` con `creates:` o `checksum:`.
4. Para la task que añade una línea a `/etc/environment`: usar `lineinfile`.
5. Para la task del timestamp (`date >> file`): usar `creates:` sobre el archivo, o convertirla en `copy:` del contenido fijo.
6. Para la task del usuario: usar `user:` nativo con `state: present`.
7. Para la task del directorio: usar `file: state: directory`.

Cada cambio debe venir acompañado de un comentario `# FIX: ...` que explique **por qué** ahora es idempotente.

### 5.4 Valida

```bash
bash tests/validate.sh
```

El validador comprueba estructuralmente que:

- No queda ningún `shell:` ni `command:` sin acotar (`creates:`, `removes:` o `changed_when:` explícito).
- Aparecen los módulos nativos esperados (`user`, `file`, `lineinfile`, `get_url` o `copy`).
- Hay al menos **4 comentarios `# FIX:`** justificando los cambios.
- Si `ansible-playbook` está disponible, pasa `--syntax-check`.

## 6. Entregables

- `playbook.yml` reparado y comentado.
- `bash tests/validate.sh` → `0 issue(s)`.

## 7. Autoevaluación

Compara tu `playbook.yml` con `solution/playbook.yml`. La solución es **una** forma correcta; hay varias equivalentes. Lo que importa es:

- Toda task que modifica el host declara estado deseado, no acción.
- Toda task que necesariamente usa `shell`/`command` lo acota con `creates:`/`removes:` o un `changed_when:` que **mira la realidad**, no uno plano `false`.

## 8. Pistas

- **PROBLEMA 1 — usuario**: `shell: adduser deploy` falla la segunda vez por ya existir (y marca `changed`). Usa `user: name=deploy state=present`.
- **PROBLEMA 2 — directorio**: `shell: mkdir -p /opt/app` marca `changed` por el output de mkdir. Usa `file: path=/opt/app state=directory`.
- **PROBLEMA 3 — línea env**: `shell: echo "FOO=bar" >> /etc/environment` **duplica** la línea en cada vuelta. Usa `lineinfile`.
- **PROBLEMA 4 — download**: `shell: curl -o /usr/local/bin/mytool https://...` descarga siempre. Usa `get_url` con `creates:` o con `checksum:`.
- **PROBLEMA 5 — timestamp**: `shell: date > /opt/app/last-run.txt` cambia el contenido siempre. Usa `copy:` con contenido fijo, o `shell:` con `creates:` sobre el archivo (preserva el contenido original — más idempotente de lo que suena si solo se necesita "existe").
