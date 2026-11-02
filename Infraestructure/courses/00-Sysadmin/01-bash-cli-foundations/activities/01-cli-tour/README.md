# Actividad 01 — CLI tour: navegación, archivos e historial

## 1. Identificación

- **ID:** `sys-01-01-cli-tour`
- **Tecnología:** `00-Sysadmin`
- **Módulo:** `sys-01-bash-cli-foundations`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Convertir el modelo mental en reflejo motor: moverte por el filesystem con `cd`/`pushd`/`popd`, listar con los flags útiles de `ls`, crear/copiar/mover/eliminar con cuidado, inspeccionar metadata con `stat`, y dejar un historial útil con `HISTCONTROL` + timestamps.

## 3. Objetivos

Al terminar deberías poder:

- Navegar con `pushd`/`popd` y volver con `cd -`.
- Listar con `ls -lAh` y entender cada columna.
- Crear jerarquía con `mkdir -p`, archivos vacíos con `touch`, timestamps con `touch -d`.
- Distinguir hardlink de symlink y mostrarlo con `stat`.
- Configurar `HISTCONTROL`, `HISTSIZE` y `HISTTIMEFORMAT`.
- Instalar un `PS1` propio en `~/.bashrc`.

## 4. Prerrequisitos

- Shell Bash ≥ 4.
- Permisos de escritura en `/tmp` y en `~/.bashrc`.
- Ninguna dependencia externa.

**Costos:** ninguno.

## 5. Instrucciones

### 5.1 Preparar workspace

```bash
cd /tmp
rm -rf cli-tour
mkdir -p cli-tour && cd cli-tour
pwd
```

### 5.2 Navegación con pila

```bash
mkdir -p proyectos/{alpha,beta,gamma}/{src,tests,docs}
pushd proyectos/alpha/src
pushd ../../beta/tests
pushd ../../gamma/docs
dirs -v           # ver la pila
popd              # vuelve a beta/tests
popd              # vuelve a alpha/src
cd -              # OLDPWD
```

Preguntas mentales: ¿cuál es la diferencia entre `cd -` y `popd`? ¿Qué muestra `dirs -v` que no muestra `pwd`?

### 5.3 Listar con intención

```bash
ls                        # básico
ls -l                     # largo
ls -lh                    # tamaños humanos
ls -lAh                   # incluye ocultos (sin . y ..)
ls -lt                    # orden por mtime
ls -li                    # muestra inodos
ls -R proyectos | head    # recursivo
```

Lee cada columna de `ls -l`: tipo+permisos, nlink, owner, group, size, mtime, name.

### 5.4 Crear y modificar

```bash
cd /tmp/cli-tour
echo "contenido inicial" > notas.txt
touch nuevo-vacio.txt
touch -d '2020-01-15 10:00:00' viejo.txt
ls -lh notas.txt nuevo-vacio.txt viejo.txt
stat notas.txt
```

### 5.5 Copiar, mover, borrar — con cuidado

```bash
cp notas.txt notas.bak
cp -a proyectos/alpha proyectos/alpha-copia      # preserva todo
mv notas.bak notas-respaldo.txt
mkdir papelera
mv viejo.txt nuevo-vacio.txt papelera/
rm -I papelera/*                                 # -I: pregunta UNA vez
rmdir papelera                                   # solo si está vacío
```

**No ejecutes nunca** `rm -rf $VAR/` en un script sin `set -u` + ruta absoluta explícita.

### 5.6 Enlaces

```bash
cd /tmp/cli-tour
ln notas.txt notas-hard         # hardlink: mismo inodo
ln -s notas.txt notas-sym       # symlink: archivo que apunta
ls -li notas*
stat notas-hard
stat notas-sym

# Prueba qué pasa al borrar el original
rm notas.txt
cat notas-hard   # sigue funcionando: hardlink mantiene el inodo
cat notas-sym    # error: broken symlink
```

### 5.7 Historial útil (añade a tu `~/.bashrc`)

Edita `~/.bashrc` y añade al final:

```bash
# --- Historial ---
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '
shopt -s histappend
```

Aplica sin cerrar la terminal:

```bash
source ~/.bashrc
history 10
```

### 5.8 Prompt propio

Añade a `~/.bashrc`:

```bash
_prompt_status() {
  local ec=$?
  [ $ec -ne 0 ] && printf '\001\e[31m\002(exit=%d)\001\e[0m\002 ' "$ec"
}
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\] $(_prompt_status)\$ '
```

Aplica y verifica el prompt. Fuerza un error (`false`) y comprueba que aparece `(exit=1)` en rojo.

### 5.9 Dejar artefactos para el validator

El validator espera encontrar `/tmp/cli-tour/` con:

- `proyectos/alpha/`, `proyectos/beta/`, `proyectos/gamma/` existentes.
- `proyectos/alpha-copia/` como copia.
- `notas-hard` (regular file) y `notas-sym` (symlink, broken OK).
- `notas-respaldo.txt` presente.

Y en tu `~/.bashrc`: líneas conteniendo `HISTCONTROL`, `HISTSIZE` y una definición de `PS1`.

### 5.10 Validar

```bash
bash /ruta/al/módulo/activities/01-cli-tour/tests/validate.sh
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `/tmp/cli-tour/` con la jerarquía descrita.
- `~/.bashrc` con historial configurado y un `PS1` propio.
- `stat notas-hard` muestra el mismo inodo que `stat notas-sym -L` *tras* borrar el original (fallará para el sym por diseño; forma parte de la lección).

## 7. Criterios de aceptación

- [ ] Funcionalidad: jerarquía y enlaces creados correctamente.
- [ ] Calidad: `~/.bashrc` no está roto (`bash -n ~/.bashrc` pasa).
- [ ] Reproducibilidad: `tests/validate.sh` termina en `OK`.
- [ ] Comprensión: puedes responder las preguntas de reflexión sin consultar.

## 8. Validación

```bash
bash tests/validate.sh
```

Chequea: directorio existe, jerarquía creada, copia de alpha, hardlink y symlink presentes, `~/.bashrc` contiene `HISTCONTROL`, `HISTSIZE` y `PS1`.

## 9. Preguntas de reflexión

1. ¿Por qué `cd -` y `popd` **no son equivalentes** aunque ambos "vuelvan atrás"?
2. ¿Qué pasó al hacer `rm notas.txt` con el hardlink y con el symlink? ¿Por qué?
3. ¿Cuál es la diferencia práctica entre `ls -la` y `ls -lA`?
4. Si pones `HISTCONTROL=ignorespace`, ¿qué comportamiento ganas y en qué escenario es útil?
5. ¿Por qué `source ~/.bashrc` es distinto de ejecutar `bash ~/.bashrc`?

## 10. Extensiones (opcional)

- **E1** — Prueba `ls --color=auto` y define `LS_COLORS` propio.
- **E2** — Añade a tu prompt un segmento con la hora (`\t`) o el número de jobs en background (`\j`).
- **E3** — Investiga `shopt -s autocd` y `shopt -s cdspell`. ¿Las activas?
- **E4** — Crea un symlink absoluto y uno relativo al mismo target; muévelos a otro directorio y observa cuál se rompe.

## 11. Limpieza

```bash
rm -rf /tmp/cli-tour
# El ~/.bashrc modificado NO se limpia: era el objetivo.
```
